use prometheus_client::metrics::family::Family;
use prometheus_client::metrics::gauge::Gauge;
use prometheus_client::registry::Registry;
use prometheus_client::{encoding::EncodeLabelSet, metrics::counter::Counter};

use once_cell::sync::Lazy;

use anyhow::Context;
use axum::{Router, response::IntoResponse, routing::get};
use prometheus_client::encoding::text::encode;
use std::{
    net::SocketAddr,
    sync::{Arc, Mutex},
};

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
pub struct ConnectionLabels {
    pub addr: String,
}

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
    pub active_subscribed_tracks: Gauge<i64>,
    pub objects_sent_total: Counter<u64>,
    pub bytes_received_from_publisher_total: Counter<u64>,
    pub bytes_sent_to_subscriber_total: Counter<u64>,
    pub active_publishers: Gauge<i64>,
    pub quic_rtt_milliseconds: Family<ConnectionLabels, Gauge<i64>>,
}

// pl. log! enum:
// quic impl-ből lekérni a belső számlálót (package loss / quic kapcsolat (label valamivel))

// TODO: macro!

impl MoqMetrics {
    pub fn new(registry: &mut Registry) -> Self {
        let announced_tracks_total = Counter::default();
        let announced_tracks_current = Gauge::default();
        let active_subscribed_tracks = Gauge::default();
        let objects_sent_total = Counter::default();
        let bytes_received_from_publisher_total = Counter::default();
        let bytes_sent_to_subscriber_total = Counter::default();
        let active_publishers = Gauge::default();
        let quic_rtt_milliseconds = Family::default();

        // let mut sub_registry = registry.sub_registry_with_prefix("moq_relay");

        registry.register(
            "moq_relay_announced_tracks_total",
            "Total number of tracks ever announced to or via this relay",
            announced_tracks_total.clone(),
        );
        registry.register(
            "moq_relay_announced_tracks_current",
            "Current number of active, announced tracks being tracked by the relay",
            announced_tracks_current.clone(),
        );
        registry.register(
            "moq_relay_active_subscribed_tracks",
            "Current number of active subscribed tracks in a relay",
            active_subscribed_tracks.clone(),
        );
        registry.register(
            "moq_relay_objects_sent_total",
            "Total number of objects sent from the relay",
            objects_sent_total.clone(),
        );
        registry.register(
            "moq_relay_bytes_received_from_publisher_total",
            "Total number of bytes received by the relay from publishers",
            bytes_received_from_publisher_total.clone(),
        );
        registry.register(
            "moq_relay_bytes_sent_to_subscriber_total",
            "Total number of bytes sent by the relay to subscribers",
            bytes_sent_to_subscriber_total.clone(),
        );
        registry.register(
            "moq_relay_active_publishers",
            "Current number of actibe publishers",
            active_publishers.clone(),
        );
        registry.register(
            "moq_relay_quic_rtt_milliseconds",
            "Estimated RTT of an active QUIC connection in milliseconds",
            quic_rtt_milliseconds.clone(),
        );

        MoqMetrics {
            announced_tracks_total,
            announced_tracks_current,
            active_subscribed_tracks,
            objects_sent_total,
            bytes_received_from_publisher_total,
            bytes_sent_to_subscriber_total,
            active_publishers,
            quic_rtt_milliseconds
        }
    }
}

pub fn increment_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks_total.inc();
    state.metrics.announced_tracks_current.inc();
}

pub fn decrement_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks_current.dec();
}

pub fn increment_active_subscribed_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_subscribed_tracks.inc();
}

pub fn decrement_active_subscribed_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_subscribed_tracks.dec();
}

pub fn add_objects_sent(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.objects_sent_total.inc_by(count);
}

pub fn add_bytes_received(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.bytes_received_from_publisher_total.inc_by(count);
}

pub fn add_bytes_sent(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.bytes_sent_to_subscriber_total.inc_by(count);
}

pub fn increment_active_publishers() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_publishers.inc();
}

pub fn decrement_active_publishers() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.active_publishers.dec();
}

pub fn update_quic_rtt(addr: String, rtt_ms: i64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .quic_rtt_milliseconds
        .get_or_create(&ConnectionLabels { addr })
        .set(rtt_ms);
}

pub fn remove_quic_rtt(addr: String) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .quic_rtt_milliseconds
        .remove(&ConnectionLabels { addr });
}

async fn metrics_handler() -> impl IntoResponse {
    let mut buffer = String::new();
    let state = GLOBAL_METRICS.lock().unwrap();
    encode(&mut buffer, &state.registry).unwrap();
    buffer
}

pub fn metrics_router() -> Router {
    Router::new().route("/metrics", get(metrics_handler))
}

pub fn run_server(
    bind_addr: SocketAddr,
) -> anyhow::Result<tokio::task::JoinHandle<anyhow::Result<()>>> {
    let task = tokio::spawn(async move {
        log::info!("serving metrics: bind={}", bind_addr);

        let app = metrics_router();

        let listener = tokio::net::TcpListener::bind(bind_addr)
            .await
            .with_context(|| format!("Failed to bind metrics address: {}", bind_addr))?;

        axum::serve(listener, app.into_make_service())
            .await
            .context("Metrics server failed")
    });

    Ok(task)
}
