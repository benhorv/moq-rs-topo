#import "@preview/diagraph:0.3.0": *

// MoQ Architecture Diagram
#let moq_arch_diagram() = {
  raw-render(
    ```dot
    digraph {
      rankdir=LR;
      node [shape=rect, style="filled", fillcolor="#f0f0f0", fontname="Times New Roman"];
      edge [fontname="Times New Roman", fontsize=10];

      subgraph cluster_publishers {
        label = "Publishers";
        style = dashed;
        color = gray;
        Pub1 [label="Publisher 1\n(stream: bbb)"];
        Pub2 [label="Publisher 2\n(stream: ccc)"];
      }

      Relay [label="MoQ Relay", fillcolor="#e0e0ff", style="filled,bold"];

      subgraph cluster_subscribers {
        label = "Subscribers";
        style = dashed;
        color = gray;
        Sub1 [label="Subscriber 1\n(watch: bbb)"];
        Sub2 [label="Subscriber 2\n(watch: bbb)"];
        Sub3 [label="Subscriber 3\n(watch: ccc)"];
      }

      Pub1 -> Relay [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Pub2 -> Relay [label="ccc", color="green", fontcolor="green", penwidth=2];

      Relay -> Sub1 [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Relay -> Sub2 [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Relay -> Sub3 [label="ccc", color="green", fontcolor="green", penwidth=2];
    }
    ```,
    labels: (:),
    width: 100%, // Let parent container control size
  )
}

// Prometheus vs OpenTelemetry Table
#let prom_vs_otel_table() = {
  table(
    columns: (auto, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    [*Tulajdonság*], [*Prometheus*], [*OpenTelemetry*],
    [Modell], [Pull (alapértelmezett)], [Push (OTLP)],
    [Adattípusok], [Metrika], [Trace, Log, Metrika],
    [Integráció komplexitása], [Alacsony], [Magas],
    [Rust támogatás], [Stabil], [Fejlesztés alatt],
  )
}

// Component Diagram
#let component_diagram() = {
  raw-render(
    ```dot
    digraph {
      rankdir=TB;
      node [shape=rect, style="filled", fillcolor="#f0f0f0", fontname="Times New Roman"];
      edge [fontname="Times New Roman", fontsize=10];

      subgraph cluster_app {
        label = "Application";
        style = dashed;
        color = gray;

        Transport [label="moq-transport"];
        Relay [label="moq-relay"];
        Pub [label="moq-pub"];
        Sub [label="moq-sub"];
      }

      Metrics [label="moq-metrics", fillcolor="#e0e0ff", style="filled,bold"];
      Prometheus [label="Prometheus\n(Scraper)", shape=ellipse, fillcolor="#ffe0e0"];

      Transport -> Metrics [label="uses"];
      Relay -> Metrics [label="uses"];
      Pub -> Metrics [label="uses"];
      Sub -> Metrics [label="uses"];

      Prometheus -> Metrics [label="HTTP GET /metrics", style=dashed];
    }
    ```,
    labels: (:),
  )
}

// MoQ Components Diagram (Crate structure)
#let moq_modules_diagram() = {
  raw-render(
    ```dot
    digraph {
      rankdir=BT;
      node [shape=rect, style="filled", fillcolor="#f0f0f0", fontname="Times New Roman", fontsize=12];
      edge [fontname="Times New Roman", fontsize=10];

      Transport [label="moq-transport", fillcolor="#e0e0ff", style="filled,bold"];

      Relay [label="moq-relay"];
      Pub [label="moq-pub"];
      Sub [label="moq-sub"];

      Relay -> Transport;
      Pub -> Transport;
      Sub -> Transport;
    }
    ```,
    labels: (:),
    width: 100%,
  )
}

// MoQ Architecture with Metrics
#let moq_metrics_arch_diagram() = {
  raw-render(
    ```dot
    digraph {
      rankdir=LR;
      node [shape=rect, style="filled", fillcolor="#f0f0f0", fontname="Times New Roman"];
      edge [fontname="Times New Roman", fontsize=10];

      // Prometheus Node
      Prometheus [label="Prometheus\n(Scraper)", shape=ellipse, fillcolor="#ffe0e0", style="filled"];

      // Publisher Cluster
      subgraph cluster_pub {
        label = "Publisher";
        style = dashed;
        color = gray;
        PubCore [label="Pub", fillcolor="white"];
        PubMetrics [label="moq-metrics", shape=component, fillcolor="#D0D0FF", fontsize=10];
        PubCore -> PubMetrics [style=dotted, arrowhead=none];
      }

      // Relay Cluster
      subgraph cluster_relay {
         label = "MoQ Relay";
         style = filled;
         fillcolor = "#e0e0ff";
         RelayCore [label="Relay", fillcolor="white"];
         RelayMetrics [label="metrics", shape=component, fillcolor="#D0D0FF", fontsize=10];
         RelayCore -> RelayMetrics [style=dotted, arrowhead=none];
      }

      // Subscriber Cluster
      subgraph cluster_sub {
        label = "Subscriber";
        style = dashed;
        color = gray;
        SubCore [label="Sub", fillcolor="white"];
        SubMetrics [label="metrics", shape=component, fillcolor="#D0D0FF", fontsize=10];
        SubCore -> SubMetrics [style=dotted, arrowhead=none];
      }

      // Media Flow
      PubCore -> RelayCore [label="media", color="black", weight=2];
      RelayCore -> SubCore [label="media", color="black", weight=2];

      // Scraping Edges
      edge [color=red, style=dashed, fontcolor=red, fontsize=9];
      Prometheus -> PubMetrics [label="GET /metrics"];
      Prometheus -> RelayMetrics [label="GET /metrics"];
      Prometheus -> SubMetrics [label="GET /metrics"];
    }
    ```,
    labels: (:),
    width: 100%,
  )
}
