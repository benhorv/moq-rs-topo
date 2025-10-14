use prometheus_client::metrics::counter::Counter;
use prometheus_client::metrics::gauge::Gauge;
use prometheus_client::registry::Registry;

use once_cell::sync::Lazy;

use prometheus_client::encoding::text::encode;
use axum::{
    routing::get,
    Router,
    response::IntoResponse,
};
use std::{net::SocketAddr, sync::{Arc, Mutex}};
use anyhow::Context;

// TODO: Label

struct MetricsState {
    registry: Registry,
    metrics: MoqMetrics,
}

static GLOBAL_METRICS: Lazy<Arc<Mutex<MetricsState>>> = Lazy::new(|| {
    let mut registry = Registry::default();
    let metrics = MoqMetrics::new(&mut registry);

    Arc::new(Mutex::new(MetricsState { registry, metrics }))
});

#[derive(Clone)]
pub struct MoqMetrics {
    pub announced_tracks_total: Counter<u64>,
    pub announced_tracks_current: Gauge<i64>,
    pub active_subscribers: Gauge<i64>,
    pub objects_sent_total: Counter<u64>,
}

// singleton
// main-ben egyet példányosítani
// pl. log! enum:
// quic impl-ből lekérni a belső számlálót (package loss / quic kapcsolat (label valamivel))

impl MoqMetrics {
    pub fn new(registry: &mut Registry) -> Self {
        let announced_tracks_total = Counter::default();
        let announced_tracks_current = Gauge::default();
        let active_subscribers = Gauge::default();
        let objects_sent_total = Counter::default();

        // let mut sub_registry = registry.sub_registry_with_prefix("moq_relay");

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
        registry.register(
            "active_subscribers",
            "Current number of active subscribers connected to the relay.",
            active_subscribers.clone(),
        );
        registry.register(
            "objects_sent_total",
            "Total number of objects sent from the relay.",
            objects_sent_total.clone(),
        );

        MoqMetrics {
            announced_tracks_total,
            announced_tracks_current,
            active_subscribers,
            objects_sent_total
        }
    }
}

// --- Public API for interacting with metrics ---

pub fn increment_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks_total.inc();
    state.metrics.announced_tracks_current.inc();
}

pub fn decrement_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks_current.dec();
}

pub fn increment_active_subscribers() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_subscribers.inc();
}

pub fn decrement_active_subscribers() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_subscribers.dec();
}

pub fn add_objects_sent(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.objects_sent_total.inc_by(count);
}


// --- Axum HTTP Server Logic ---

async fn metrics_handler() -> impl IntoResponse {
    let mut buffer = String::new();
    let state = GLOBAL_METRICS.lock().unwrap();
    encode(&mut buffer, &state.registry).unwrap();
    buffer
}

/// Returns an Axum Router that serves the /metrics endpoint.
pub fn metrics_router() -> Router {
    // We don't need to pass the registry anymore; the handler can access the global.
    Router::new().route("/metrics", get(metrics_handler))
}

pub fn run_server(bind_addr: SocketAddr) -> anyhow::Result<tokio::task::JoinHandle<anyhow::Result<()>>> {
    let task = tokio::spawn(async move {
        log::info!("serving metrics: bind={}", bind_addr);

        let app = metrics_router();

        let listener = tokio::net::TcpListener::bind(bind_addr).await
            .with_context(|| format!("Failed to bind metrics address: {}", bind_addr))?;

        axum::serve(listener, app.into_make_service()).await
            .context("Metrics server failed")
    });

    Ok(task)
}
