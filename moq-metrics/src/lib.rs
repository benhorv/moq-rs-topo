use prometheus_client::metrics::family::Family;
use prometheus_client::metrics::gauge::Gauge;
use prometheus_client::registry::Registry;
use prometheus_client::{encoding::EncodeLabelSet, metrics::counter::Counter};

use once_cell::sync::Lazy;

use anyhow::Context;
use axum::{Router, response::IntoResponse, routing::get};
use prometheus_client::encoding::text::encode;
use std::time::Duration;
use std::{
    net::SocketAddr,
    sync::{Arc, Mutex},
};
use sysinfo::{ProcessesToUpdate, System};

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
pub struct ConnectionLabels {
    pub addr: String,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
pub struct StreamLabels {
    pub namespace: String,
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
    pub announced_tracks: Counter<u64>,
    pub announced_tracks_current: Gauge<i64>,
    pub active_subscribed_tracks: Family<StreamLabels, Gauge<i64>>,
    pub objects_sent: Counter<u64>,
    pub bytes_received_from_publisher: Counter<u64>,
    pub bytes_sent_to_subscriber: Counter<u64>,
    pub active_publishers: Gauge<i64>,
    pub quic_rtt_milliseconds: Family<ConnectionLabels, Gauge<i64>>,
    pub quic_lost_packets: Family<ConnectionLabels, Counter<u64>>,
    pub process_cpu_usage_percent: Gauge<i64>,
    pub process_memory_bytes: Gauge<i64>,
    pub system_cpu_usage_percent: Gauge<i64>,
    pub system_memory_bytes: Gauge<i64>,
    pub system_memory_available_bytes: Gauge<i64>,
    pub subscriber_objects_received: Counter<u64>,
    pub subscriber_bytes_received: Counter<u64>,
    pub subscriber_active_tracks: Gauge<i64>,
    pub quic_connections_active: Gauge<i64>,
    pub quic_sent_packets: Family<ConnectionLabels, Counter<u64>>,
}

// pl. log! enum:
// quic impl-ből lekérni a belső számlálót (package loss / quic kapcsolat (label valamivel))

// TODO: macro!

// különböző komponensekhez namespace
// cpu, memory stb...
impl MoqMetrics {
    pub fn new(registry: &mut Registry) -> Self {
        let announced_tracks = Counter::default();
        let announced_tracks_current = Gauge::default();
        let active_subscribed_tracks = Family::default();
        let objects_sent = Counter::default();
        let bytes_received_from_publisher = Counter::default();
        let bytes_sent_to_subscriber = Counter::default();
        let active_publishers = Gauge::default();
        let quic_rtt_milliseconds = Family::default();
        let quic_lost_packets: Family<ConnectionLabels, Counter<u64>> = Family::default();
        let process_cpu_usage_percent = Gauge::default();
        let process_memory_bytes = Gauge::default();
        let system_cpu_usage_percent = Gauge::default();
        let system_memory_bytes = Gauge::default();
        let system_memory_available_bytes = Gauge::default();
        let subscriber_objects_received = Counter::default();
        let subscriber_bytes_received = Counter::default();
        let subscriber_active_tracks = Gauge::default();
        let quic_connections_active = Gauge::default();
        let quic_sent_packets: Family<ConnectionLabels, Counter<u64>> = Family::default();

        // let mut sub_registry = registry.sub_registry_with_prefix("moq_relay");

        registry.register(
            "moq_relay_announced_tracks",
            "Total number of tracks ever announced to or via this relay",
            announced_tracks.clone(),
        );
        registry.register(
            "moq_relay_announced_tracks_current",
            "Current number of active, announced tracks being tracked by the relay",
            announced_tracks_current.clone(),
        );
        registry.register( // nem egyértelmű
            "moq_relay_active_subscribed_tracks",
            "Current number of subscribed tracks in the relay by namespace.",
            active_subscribed_tracks.clone(),
        );
        registry.register(
            "moq_relay_objects_sent",
            "Total number of objects sent from the relay",
            objects_sent.clone(),
        );
        registry.register(
            "moq_relay_bytes_received_from_publisher",
            "Total number of bytes received by the relay from publishers",
            bytes_received_from_publisher.clone(),
        );
        registry.register(
            "moq_relay_bytes_sent_to_subscriber",
            "Total number of bytes sent by the relay to subscribers",
            bytes_sent_to_subscriber.clone(),
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
        registry.register(
            "moq_relay_quic_lost_packets",
            "Total number of QUIC packets detected as lost for a connection",
            quic_lost_packets.clone(),
        );
        registry.register(
            "process_cpu_usage_percent",
            "Current CPU usage of the relay process",
            process_cpu_usage_percent.clone(),
        );
        registry.register(
            "process_memory_bytes",
            "Current resident memory usage of the relay process",
            process_memory_bytes.clone(),
        );
        registry.register(
            "system_memory_available_bytes",
            "Amount of available bytes in system memory",
            system_memory_available_bytes.clone(),
        );
        registry.register(
            "system_cpu_usage_percent",
            "Current CPU usage of the system",
            system_cpu_usage_percent.clone(),
        );
        registry.register(
            "system_memory_bytes",
            "Current resident memory usage of the system",
            system_memory_bytes.clone(),
        );
        registry.register(
            "subscriber_objects_received",
            "Total number of objects received by subscriber",
            subscriber_objects_received.clone(),
        );
        registry.register(
            "subscriber_bytes_received",
            "Total number of bytes received by subscriber",
            subscriber_bytes_received.clone(),
        );
        registry.register(
            "subscriber_active_tracks",
            "Number of currently active tracks in subscriber",
            subscriber_active_tracks.clone(),
        );
        registry.register(
            "moq_relay_quic_connections_active",
            "Current number of active QUIC connections",
            quic_connections_active.clone(),
        );
        registry.register(
            "moq_relay_quic_sent_packets",
            "Total number of QUIC packets sent for a connection",
            quic_sent_packets.clone(),
        );

        MoqMetrics {
            announced_tracks,
            announced_tracks_current,
            active_subscribed_tracks,
            objects_sent,
            bytes_received_from_publisher,
            bytes_sent_to_subscriber,
            active_publishers,
            quic_rtt_milliseconds,
            quic_lost_packets,
            process_cpu_usage_percent,
            process_memory_bytes,
            system_cpu_usage_percent,
            system_memory_available_bytes,
            system_memory_bytes,
            subscriber_objects_received,
            subscriber_bytes_received,
            subscriber_active_tracks,
            quic_connections_active,
            quic_sent_packets,
        }
    }
}

pub fn increment_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks.inc();
    state.metrics.announced_tracks_current.inc();
}

pub fn decrement_announced_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.announced_tracks_current.dec();
}

pub fn increment_active_subscribed_tracks(namespace: String) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .active_subscribed_tracks
        .get_or_create(&StreamLabels { namespace })
        .inc();
}

pub fn decrement_active_subscribed_tracks(namespace: String) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .active_subscribed_tracks
        .get_or_create(&StreamLabels { namespace })
        .dec();
}

pub fn add_objects_sent(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.objects_sent.inc_by(count);
}

pub fn add_bytes_received(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .bytes_received_from_publisher
        .inc_by(count);
}

pub fn add_bytes_sent(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.bytes_sent_to_subscriber.inc_by(count);
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

pub fn increment_lost_packets_by(addr: String, count: u64) {
    if count == 0 {
        return;
    }
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .quic_lost_packets
        .get_or_create(&ConnectionLabels { addr })
        .inc_by(count);
}

pub fn update_process_cpu(percent: i64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.process_cpu_usage_percent.set(percent);
}

pub fn update_process_memory(bytes: i64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.process_memory_bytes.set(bytes);
}

pub fn update_system_cpu(percent: i64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.system_cpu_usage_percent.set(percent);
}

pub fn update_system_memory(available: i64, total: i64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.system_memory_available_bytes.set(available);
    state.metrics.system_memory_bytes.set(total);
}

pub fn add_subscriber_objects_received(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.subscriber_objects_received.inc_by(count);
}

pub fn add_subscriber_bytes_received(count: u64) {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.subscriber_bytes_received.inc_by(count);
}

pub fn increment_subscriber_active_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.subscriber_active_tracks.inc();
}

pub fn decrement_subscriber_active_tracks() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.subscriber_active_tracks.dec();
}

pub fn increment_active_connections() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.quic_connections_active.inc();
}

pub fn decrement_active_connections() {
    let state = GLOBAL_METRICS.lock().unwrap();
    state.metrics.quic_connections_active.dec();
}

pub fn increment_sent_packets_by(addr: String, count: u64) {
    if count == 0 {
        return;
    }
    let state = GLOBAL_METRICS.lock().unwrap();
    state
        .metrics
        .quic_sent_packets
        .get_or_create(&ConnectionLabels { addr })
        .inc_by(count);
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

pub fn poll_system() -> anyhow::Result<tokio::task::JoinHandle<anyhow::Result<()>>> {
    let task = tokio::spawn(async {
        let mut sys = System::new_all();
        let pid = sysinfo::get_current_pid().expect("Failed to get current PID");
        let mut interval = tokio::time::interval(Duration::from_secs(5));

        sys.refresh_cpu_all();
        tokio::time::sleep(Duration::from_millis(500)).await;

        loop {
            interval.tick().await;

            sys.refresh_cpu_all();
            sys.refresh_memory();
            sys.refresh_processes(ProcessesToUpdate::All, true);

            let cpu_usage: f32 =
                sys.cpus().iter().map(|cpu| cpu.cpu_usage()).sum::<f32>() / sys.cpus().len() as f32;
            let available_mem = sys.available_memory();
            let total_mem = sys.total_memory();

            update_system_cpu(cpu_usage.round() as i64);
            update_system_memory(available_mem as i64, total_mem as i64);

            if let Some(process) = sys.process(pid) {
                let process_cpu = (process.cpu_usage() / sys.cpus().len() as f32).round() as i64;
                let process_mem = process.memory();

                update_process_cpu(process_cpu);
                update_process_memory(process_mem as i64);
            }
        }
    });

    Ok(task)
}
