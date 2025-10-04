#!/bin/bash

set -euo pipefail

# --- Port Definitions ---
PORT_REDIS=6379
PORT_MOQ_API=8080
PORT_RELAY1=4451
PORT_RELAY2=4452
PORT_RELAY3=4453
TOPO_FILE_PATH='../topo.dot'

echo "Building moq-api and relays first..."
cargo build --manifest-path moq-api/Cargo.toml --bin moq-api
cargo build --manifest-path moq-relay-ietf/Cargo.toml --bin moq-relay-ietf

echo "Starting point: $(pwd)"
echo "Make sure 'xterm' and 'nc' are installed."
echo ""

SLEEP_DURATION=0.5

wait_for_port() {
    local port=$1
    echo "Waiting for port $port..."
    until nc -z localhost $port 2>/dev/null; do
        sleep 0.5
    done
    echo "Port $port is ready."
}

# Store PIDs of launched xterms
pids=()

launch_xterm() {
    title=$1
    cmd=$2
    xterm -T "$title" -e "bash -c \"$cmd\"" &
    pid=$!
    pids+=($pid)
    sleep $SLEEP_DURATION
}

# --- Cleanup handler ---
cleanup() {
    echo "Cleaning up..."
    kill "${pids[@]}" 2>/dev/null || true
    pkill -f "redis-server" 2>/dev/null || true
}
trap cleanup EXIT

# --- Launch processes in xterm ---

launch_xterm "Redis Server" \
    "exec redis-server --daemonize no"
wait_for_port $PORT_REDIS

launch_xterm "moq-api (P:$PORT_MOQ_API)" \
    "cd moq-api && \
     exec cargo run --bin moq-api -- \
       --bind '[::]:$PORT_MOQ_API' \
       --redis 'redis://localhost:$PORT_REDIS/' \
       --topo '$TOPO_FILE_PATH'"
wait_for_port $PORT_MOQ_API

launch_xterm "Relay 1 (P:$PORT_RELAY1)" \
    "cd moq-relay-ietf && \
     exec cargo run --bin moq-relay-ietf -- \
       --bind '[::]:$PORT_RELAY1' \
       --tls-cert ../dev/localhost.crt \
       --tls-key ../dev/localhost.key \
       --tls-disable-verify \
       --api http://localhost:$PORT_MOQ_API \
       --node https://localhost:$PORT_RELAY1 \
       --dev"
wait_for_port $PORT_RELAY1

launch_xterm "Relay 2 (P:$PORT_RELAY2)" \
    "cd moq-relay-ietf && \
     exec cargo run --bin moq-relay-ietf -- \
       --bind '[::]:$PORT_RELAY2' \
       --tls-cert ../dev/localhost.crt \
       --tls-key ../dev/localhost.key \
       --tls-disable-verify \
       --api http://localhost:$PORT_MOQ_API \
       --node https://localhost:$PORT_RELAY2 \
       --dev"
wait_for_port $PORT_RELAY2

launch_xterm "Relay 3 (P:$PORT_RELAY3)" \
    "cd moq-relay-ietf && \
     exec cargo run --bin moq-relay-ietf -- \
       --bind '[::]:$PORT_RELAY3' \
       --tls-cert ../dev/localhost.crt \
       --tls-key ../dev/localhost.key \
       --tls-disable-verify \
       --api http://localhost:$PORT_MOQ_API \
       --node https://localhost:$PORT_RELAY3 \
       --dev"
wait_for_port $PORT_RELAY3

launch_xterm "Publisher (to P:$PORT_RELAY1)" \
    "PORT=$PORT_RELAY1 exec ./dev/pub"

launch_xterm "Subscriber (from P:$PORT_RELAY3)" \
    "PORT=$PORT_RELAY3 exec ./dev/sub"

echo ""
echo "All processes launched. Closing ANY window will shut down everything."

# --- Supervision loop ---
while true; do
    for pid in "${pids[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "Process $pid has exited. Killing all..."
            cleanup
            exit 1
        fi
    done
    sleep 1
done
