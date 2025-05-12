use std::{collections::HashMap, net, path::PathBuf};

use axum::{
    extract::{Extension, Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};

use clap::Parser;

use redis::{aio::ConnectionManager, AsyncCommands};

use moq_api::{ApiError, Origin};

/// Runs a HTTP API to create/get origins for broadcasts.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct ServerConfig {
    /// Listen for HTTP requests on the given address
    #[arg(long, default_value = "[::]:80")]
    pub bind: net::SocketAddr,

    /// Connect to the given redis instance
    #[arg(long)]
    pub redis: url::Url,

    /// Parse topology file
    #[arg(long, required = false)]
    pub topo: Option<PathBuf>,
}

pub struct Server {
    config: ServerConfig,
}

impl Server {
    pub fn new(config: ServerConfig) -> Self {
        Self { config }
    }

    pub async fn run(self) -> Result<(), ApiError> {
        log::info!("connecting to redis: url={}", self.config.redis);

        // Create the redis client.
        let redis = redis::Client::open(self.config.redis)?;
        let redis = redis.get_connection_manager().await?;

        // Load topology
        let map = if let Some(topo) = &self.config.topo {
            log::info!("loading topology: path={}", topo.display());
            match std::fs::read_to_string(topo) {
                Ok(topo) => parse_topology(&topo).unwrap(),
                Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
                    log::warn!("topology file not found: path={}", topo.display());
                    HashMap::new()
                }
                Err(err) => return Err(err.into()),
            }
        } else {
            HashMap::new()
        };

        let app = Router::new()
            .route(
                "/origin/*namespace",
                get(get_origin)
                    .post(set_origin)
                    .delete(delete_origin)
                    .patch(patch_origin),
            )
            .with_state(redis)
            .layer(Extension(map));

        log::info!("serving requests: bind={}", self.config.bind);

        let listener = tokio::net::TcpListener::bind(&self.config.bind).await?;
        axum::serve(listener, app.into_make_service()).await?;

        Ok(())
    }
}

async fn get_origin(
    Extension(map): Extension<HashMap<String, String>>,
    Path(namespace): Path<String>,
    Query(params): Query<HashMap<String, String>>,
    State(mut redis): State<ConnectionManager>,
) -> Result<Json<Origin>, AppError> {
    if let Some(requester) = params.get("requester").cloned() {
        let key = format!("{{{}}}{}", namespace, requester);
        let source = map.get(&key).ok_or(AppError::NotFound)?.clone();
        let (_, o) = source.split_once('}').expect("error parsing source, check label format");
        let origin = Origin {
            url: url::Url::parse(&o).unwrap(),
        };
        Ok(Json(origin))
    } else {
        let key = origin_key(&namespace);

        let payload: Option<String> = redis.get(&key).await?;
        let payload = payload.ok_or(AppError::NotFound)?;
        let origin: Origin = serde_json::from_str(&payload)?;
        Ok(Json(origin))
    }
}

async fn set_origin(
    State(mut redis): State<ConnectionManager>,
    Path(namespace): Path<String>,
    Json(origin): Json<Origin>,
) -> Result<(), AppError> {
    // TODO validate origin

    let key = origin_key(&namespace);

    // Convert the input back to JSON after validating it add adding any fields (TODO)
    let payload = serde_json::to_string(&origin)?;

    // Attempt to get the current value for the key
    let current: Option<String> = redis::cmd("GET").arg(&key).query_async(&mut redis).await?;

    if let Some(current) = &current {
        if current.eq(&payload) {
            // The value is the same, so we're done.
            return Ok(());
        } else {
            return Err(AppError::Duplicate);
        }
    }

    let res: Option<String> = redis::cmd("SET")
        .arg(key)
        .arg(payload)
        .arg("NX")
        .arg("EX")
        .arg(600) // Set the key to expire in 10 minutes; the origin needs to keep refreshing it.
        .query_async(&mut redis)
        .await?;

    if res.is_none() {
        return Err(AppError::Duplicate);
    }

    Ok(())
}

async fn delete_origin(
    Path(namespace): Path<String>,
    State(mut redis): State<ConnectionManager>,
) -> Result<(), AppError> {
    let key = origin_key(&namespace);
    match redis.del(key).await? {
        0 => Err(AppError::NotFound),
        _ => Ok(()),
    }
}

// Update the expiration deadline.
async fn patch_origin(
    Path(namespace): Path<String>,
    State(mut redis): State<ConnectionManager>,
    Json(origin): Json<Origin>,
) -> Result<(), AppError> {
    let key = origin_key(&namespace);

    // Make sure the contents haven't changed
    // TODO make a LUA script to do this all in one operation.
    let payload: Option<String> = redis.get(&key).await?;
    let payload = payload.ok_or(AppError::NotFound)?;
    let expected: Origin = serde_json::from_str(&payload)?;

    if expected != origin {
        return Err(AppError::Duplicate);
    }

    // Reset the timeout to 10 minutes.
    match redis.expire(key, 600).await? {
        0 => Err(AppError::NotFound),
        _ => Ok(()),
    }
}

fn origin_key(namespace: &str) -> String {
    format!("origin.{namespace}")
}

fn parse_topology(content: &str) -> Result<HashMap<String, String>, AppError> {
    let node_map = read_graph(content);
    return Ok(node_map);
}

fn read_graph(content: &str) -> HashMap<String, String> {
    // TODO: import file dynamically, currently not possible with this petgraph version
    let graph: petgraph::graph::Graph<_, _> = petgraph::dot::dot_parser::graph_from_file!(
        "./target/debug/topo.dot"
    );

    let mut map: HashMap<String, String> = HashMap::new();

    for node_index in graph.node_indices() {
        let mut source_url: String = String::new();

        for (key, value) in graph[node_index].clone().attr.elems {
            if key == "label" {
                source_url = value.trim_matches('"').to_string();
            }
        }
        let mut neighbors = graph.neighbors_directed(node_index, petgraph::Direction::Outgoing);
        let next_neighbor_index = neighbors.next();

        match next_neighbor_index {
            Some(next_neighbor_index) => {
                for (key, value) in graph[next_neighbor_index].clone().attr.elems {
                    if key == "label" {
                        let url = value.trim_matches('"');
                        map.insert(source_url.clone(), url.to_string());
                    }
                }
            }
            None => {
                log::info!("No more neighbors found");
            }
        }
    }

    return map;
}

#[derive(thiserror::Error, Debug)]
enum AppError {
    #[error("redis error")]
    Redis(#[from] redis::RedisError),

    #[error("json error")]
    Json(#[from] serde_json::Error),

    #[error("not found")]
    NotFound,

    #[error("duplicate ID")]
    Duplicate,
}

// Tell axum how to convert `AppError` into a response.
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match self {
            AppError::Redis(e) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("redis error: {e}"),
            )
                .into_response(),
            AppError::Json(e) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("json error: {e}"),
            )
                .into_response(),
            AppError::NotFound => StatusCode::NOT_FOUND.into_response(),
            AppError::Duplicate => StatusCode::CONFLICT.into_response(),
        }
    }
}
