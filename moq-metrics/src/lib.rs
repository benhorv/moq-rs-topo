use prometheus_client::metrics::family::Family;
use prometheus_client::metrics::gauge::Gauge;
use prometheus_client::registry::Registry;
use prometheus_client::{encoding::EncodeLabelSet, metrics::counter::Counter};

use once_cell::sync::Lazy;

use anyhow::Context;
use axum::{Router, response::IntoResponse, routing::get};
use prometheus_client::encoding::text::encode;
use std::time::Duration;
use std::{net::SocketAddr, sync::Mutex};
use sysinfo::{ProcessesToUpdate, System};

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
pub struct ConnectionLabels {
    pub addr: String,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, EncodeLabelSet)]
pub struct StreamLabels {
    pub namespace: String,
}

type ScrapeCallback = std::sync::Arc<dyn Fn() -> bool + Send + Sync>;

pub struct MetricsState {
    pub registry: Mutex<Registry>,
    pub metrics: MoqMetrics,
    callbacks: Mutex<Vec<ScrapeCallback>>,
}

static GLOBAL_METRICS: Lazy<MetricsState> = Lazy::new(|| {
    let mut registry = Registry::default();
    let metrics = MoqMetrics::new(&mut registry);

    MetricsState {
        registry: Mutex::new(registry),
        metrics,
        callbacks: Mutex::new(Vec::new()),
    }
});

macro_rules! define_metrics {
    (
        $($field:ident: $type:ty, $name:literal, $help:literal),* $(,)?
    ) => {
        #[derive(Clone)]
        pub struct MoqMetrics {
            $(pub $field: $type,)*
        }

        impl MoqMetrics {
            pub fn new(registry: &mut Registry) -> Self {
                $(
                    let $field = <$type>::default();
                    registry.register($name, $help, $field.clone());
                )*
                Self { $($field,)* }
            }
        }
    };
}

define_metrics! {
    announced_tracks: Counter<u64>, "moq_relay_announced_tracks", "Total tracks ever announced",
    announced_tracks_current: Gauge<i64>, "moq_relay_announced_tracks_current", "Current active announced tracks",
    active_subscribed_tracks: Family<StreamLabels, Gauge<i64>>, "moq_relay_active_subscribed_tracks", "Active subscribed tracks by namespace",

    objects_sent: Counter<u64>, "moq_relay_objects_sent", "Total objects sent",
    bytes_received_from_publisher: Counter<u64>, "moq_relay_bytes_received_from_publisher", "Total bytes received from publishers",
    bytes_sent_to_subscriber: Counter<u64>, "moq_relay_bytes_sent_to_subscriber", "Total bytes sent to subscribers",

    active_publishers: Gauge<i64>, "moq_relay_active_publishers", "Current active publishers",

    quic_rtt_milliseconds: Family<ConnectionLabels, Gauge<i64>>, "moq_relay_quic_rtt_milliseconds", "QUIC RTT in ms",
    quic_connections_active: Gauge<i64>, "moq_relay_quic_connections_active", "Current active QUIC connections",
    quic_lost_packets: Family<ConnectionLabels, Gauge<i64>>, "moq_relay_quic_lost_packets", "Total QUIC lost packets (Cumulative)",
    quic_sent_packets: Family<ConnectionLabels, Gauge<i64>>, "moq_relay_quic_sent_packets", "Total QUIC sent packets (Cumulative)",

    process_cpu_usage_percent: Gauge<i64>, "process_cpu_usage_percent", "Relay process CPU usage",
    process_memory_bytes: Gauge<i64>, "process_memory_bytes", "Relay process memory usage",

    system_cpu_usage_percent: Gauge<i64>, "system_cpu_usage_percent", "System CPU usage",
    system_memory_bytes: Gauge<i64>, "system_memory_bytes", "System resident memory usage",
    system_memory_available_bytes: Gauge<i64>, "system_memory_available_bytes", "System available memory",

    subscriber_objects_received: Counter<u64>, "subscriber_objects_received", "Objects received by subscriber",
    subscriber_bytes_received: Counter<u64>, "subscriber_bytes_received", "Bytes received by subscriber",
    subscriber_active_tracks: Gauge<i64>, "subscriber_active_tracks", "Active tracks in subscriber",

    publisher_objects_sent: Counter<u64>, "publisher_objects_sent", "Objects sent by publisher",
    publisher_bytes_sent: Counter<u64>, "publisher_bytes_sent", "Bytes sent by publisher",
    publisher_active_tracks: Gauge<i64>, "publisher_active_tracks", "Active tracks in publisher"
}

pub fn increment_publisher_active_tracks() {
    GLOBAL_METRICS.metrics.publisher_active_tracks.inc();
}

pub fn decrement_publisher_active_tracks() {
    GLOBAL_METRICS.metrics.publisher_active_tracks.dec();
}

pub fn increment_announced_tracks() {
    GLOBAL_METRICS.metrics.announced_tracks.inc();
    GLOBAL_METRICS.metrics.announced_tracks_current.inc();
}

pub fn decrement_announced_tracks() {
    GLOBAL_METRICS.metrics.announced_tracks_current.dec();
}

pub fn increment_active_subscribed_tracks(namespace: String) {
    GLOBAL_METRICS
        .metrics
        .active_subscribed_tracks
        .get_or_create(&StreamLabels { namespace })
        .inc();
}

pub fn decrement_active_subscribed_tracks(namespace: String) {
    GLOBAL_METRICS
        .metrics
        .active_subscribed_tracks
        .get_or_create(&StreamLabels { namespace })
        .dec();
}

pub fn add_objects_sent(count: u64) {
    GLOBAL_METRICS.metrics.objects_sent.inc_by(count);
}

pub fn add_bytes_received(count: u64) {
    GLOBAL_METRICS
        .metrics
        .bytes_received_from_publisher
        .inc_by(count);
}

pub fn add_bytes_sent(count: u64) {
    GLOBAL_METRICS
        .metrics
        .bytes_sent_to_subscriber
        .inc_by(count);
}

pub fn increment_active_publishers() {
    GLOBAL_METRICS.metrics.active_publishers.inc();
}

pub fn decrement_active_publishers() {
    GLOBAL_METRICS.metrics.active_publishers.dec();
}

pub fn update_quic_rtt(addr: String, rtt_ms: i64) {
    GLOBAL_METRICS
        .metrics
        .quic_rtt_milliseconds
        .get_or_create(&ConnectionLabels { addr })
        .set(rtt_ms);
}

pub fn remove_quic_rtt(addr: String) {
    GLOBAL_METRICS
        .metrics
        .quic_rtt_milliseconds
        .remove(&ConnectionLabels { addr });
}

pub fn update_lost_packets(addr: String, count: u64) {
    GLOBAL_METRICS
        .metrics
        .quic_lost_packets
        .get_or_create(&ConnectionLabels { addr })
        .set(count as i64);
}

pub fn update_sent_packets(addr: String, count: u64) {
    GLOBAL_METRICS
        .metrics
        .quic_sent_packets
        .get_or_create(&ConnectionLabels { addr })
        .set(count as i64);
}

pub fn update_process_cpu(percent: i64) {
    GLOBAL_METRICS
        .metrics
        .process_cpu_usage_percent
        .set(percent);
}

pub fn update_process_memory(bytes: i64) {
    GLOBAL_METRICS.metrics.process_memory_bytes.set(bytes);
}

pub fn update_system_cpu(percent: i64) {
    GLOBAL_METRICS.metrics.system_cpu_usage_percent.set(percent);
}

pub fn update_system_memory(available: i64, total: i64) {
    GLOBAL_METRICS
        .metrics
        .system_memory_available_bytes
        .set(available);
    GLOBAL_METRICS.metrics.system_memory_bytes.set(total);
}

pub fn add_subscriber_objects_received(count: u64) {
    GLOBAL_METRICS
        .metrics
        .subscriber_objects_received
        .inc_by(count);
}

pub fn add_subscriber_bytes_received(count: u64) {
    GLOBAL_METRICS
        .metrics
        .subscriber_bytes_received
        .inc_by(count);
}

pub fn increment_subscriber_active_tracks() {
    GLOBAL_METRICS.metrics.subscriber_active_tracks.inc();
}

pub fn decrement_subscriber_active_tracks() {
    GLOBAL_METRICS.metrics.subscriber_active_tracks.dec();
}

pub fn add_publisher_objects_sent(count: u64) {
    GLOBAL_METRICS.metrics.publisher_objects_sent.inc_by(count);
}

pub fn add_publisher_bytes_sent(count: u64) {
    GLOBAL_METRICS.metrics.publisher_bytes_sent.inc_by(count);
}

pub fn get_publisher_bytes_sent() -> u64 {
    GLOBAL_METRICS.metrics.publisher_bytes_sent.get()
}

pub fn increment_active_connections() {
    GLOBAL_METRICS.metrics.quic_connections_active.inc();
}

pub fn decrement_active_connections() {
    GLOBAL_METRICS.metrics.quic_connections_active.dec();
}

pub fn add_scrape_callback<F>(callback: F)
where
    F: Fn() -> bool + Send + Sync + 'static,
{
    GLOBAL_METRICS
        .callbacks
        .lock()
        .unwrap()
        .push(std::sync::Arc::new(callback));
}

async fn metrics_handler() -> impl IntoResponse {
    let callbacks_to_run: Vec<ScrapeCallback> = {
        let callbacks = GLOBAL_METRICS.callbacks.lock().unwrap();
        callbacks.clone()
    };

    for callback in callbacks_to_run {
        callback();
    }

    let mut buffer = String::new();
    let registry: std::sync::MutexGuard<'_, Registry> = GLOBAL_METRICS.registry.lock().unwrap();
    encode(&mut buffer, &registry).unwrap();
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
            sys.refresh_processes(ProcessesToUpdate::Some(&[pid]), true);

            let cpu_usage_manual: f32 =
                sys.cpus().iter().map(|cpu| cpu.cpu_usage()).sum::<f32>() / sys.cpus().len() as f32;

            let available_mem = sys.available_memory();
            let total_mem = sys.total_memory();

            update_system_cpu(cpu_usage_manual.round() as i64);
            update_system_memory(available_mem as i64, total_mem as i64);

            if let Some(process) = sys.process(pid) {
                let num_cores = sys.cpus().len() as f32;
                let process_cpu = (process.cpu_usage() / num_cores).round() as i64;

                let process_mem = process.memory();

                update_process_cpu(process_cpu);
                update_process_memory(process_mem as i64);
            }
        }
    });

    Ok(task)
}
