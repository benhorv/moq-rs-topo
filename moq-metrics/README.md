# Commands needed to run the demo

## Relay

```bash
RUST_LOG=debug cargo run --bin moq-relay-ietf -- --bind "[::]:4451" \
    --tls-cert ../dev/localhost.crt \
    --tls-key ../dev/localhost.key \
    --tls-disable-verify \
    --node https://127.0.0.1:4451 \
    --metrics-bind "[::]:9091" \
    --dev
```

## Publishers and Subscribers

```bash
PORT=4451 NAME="bbb" ./dev/pub --metrics-bind "[::]:9096"
PORT=4451 NAME="ccc" ./dev/pub --metrics-bind "[::]:9097"
PORT=4451 NAME="bbb" ./dev/sub --metrics-bind "[::]:9094"
PORT=4451 NAME="ccc" ./dev/sub --metrics-bind "[::]:9095"
PORT=4451 NAME="bbb" ./dev/sub --metrics-bind "[::]:9098"
PORT=4451 NAME="ccc" ./dev/sub --metrics-bind "[::]:9099"
```

## Prometheus and Grafana

```bash
prometheus --config.file=prometheus.yml --storage.tsdb.path=./data

sudo systemctl start grafana-server
```
