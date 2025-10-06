use prometheus_client::metrics::counter::Counter;
use prometheus_client::metrics::gauge::Gauge;
use prometheus_client::registry::Registry;

use prometheus_client::encoding::text::encode;
use axum::{
    routing::get,
    extract::Extension,
    Router,
    response::IntoResponse,
};
use std::sync::Arc;

// TODO: Label

async fn metrics_handler(Extension(registry): Extension<Arc<Registry>>) -> impl IntoResponse {
    let mut buffer = String::new();
    encode(&mut buffer, &registry).unwrap();
    buffer
}

pub fn metrics_router(registry: Arc<Registry>) -> Router {
    Router::new()
        .route("/metrics", get(metrics_handler))
        .layer(Extension(registry))
}



#[derive(Clone)]
pub struct RelayMetrics {
    pub announced_tracks_total: Counter<u64>,
    pub announced_tracks_current: Gauge<i64>,
}

impl RelayMetrics {
    pub fn new(registry: &mut Registry) -> Self {
        let announced_tracks_total = Counter::default();
        let announced_tracks_current = Gauge::default();

        registry.register(
            "moq_relay_announced_tracks_total",
            "Total number of tracks ever announced to or via this relay.",
            announced_tracks_total.clone(),
        );
        registry.register(
            "moq_relay_announced_tracks_current",
            "Current number of active, announced tracks being tracked by the relay.",
            announced_tracks_current.clone(),
        );

        RelayMetrics {
            announced_tracks_total,
            announced_tracks_current,
        }
    }
}
