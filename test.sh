#!/bin/bash

# --- Port Definitions ---
PORT_REDIS=6379
PORT_MOQ_DIR=4444
PORT_MOQ_API=8080
PORT_RELAY1=4451
PORT_RELAY2=4452
PORT_RELAY3=4453
# Publisher will use PORT_RELAY1
# Subscriber will use PORT_RELAY3

# --- File Path Definitions ---
# This path is relative to the 'moq-api' working directory
TOPO_FILE_PATH='../topo.dot'

echo "Starting point: $(pwd)"
echo "Attention: You will need to manually arrange the xterm windows for optimal visibility."
echo "Make sure 'xterm' is installed."
echo ""

# Short delay between opening windows (optional)
SLEEP_DURATION=0.5

# 1. Redis Server (Uses default port, not typically overridden by client apps here)
xterm -T "Redis Server" -e "bash -c \"echo 'Working directory: \$(pwd)'; echo 'Starting: redis-server'; redis-server; exec bash\"" &
sleep $SLEEP_DURATION

# 2. moq-dir
xterm -T "moq-dir (P:$PORT_MOQ_DIR)" -e "bash -c \"cd moq-dir && echo 'Working directory: \$(pwd)'; echo 'Starting: moq-dir on port $PORT_MOQ_DIR'; RUST_LOG=debug cargo run --bin moq-dir -- --bind '[::]:$PORT_MOQ_DIR' --tls-cert ../dev/localhost.crt --tls-key ../dev/localhost.key; exec bash\"" &
sleep $SLEEP_DURATION

# 3. moq-api
xterm -T "moq-api (P:$PORT_MOQ_API)" -e "bash -c \"cd moq-api && echo 'Working directory: \$(pwd)'; echo 'Starting: moq-api on port $PORT_MOQ_API (Redis: $PORT_REDIS, Topo: $TOPO_FILE_PATH)'; RUST_LOG=debug cargo run --bin moq-api -- --bind '[::]:$PORT_MOQ_API' --redis 'redis://localhost:$PORT_REDIS/' --topo '$TOPO_FILE_PATH'; exec bash\"" &
sleep $SLEEP_DURATION

# 4. Relay 1
xterm -T "Relay 1 (P:$PORT_RELAY1)" -e "bash -c \"cd moq-relay-ietf && echo 'Working directory: \$(pwd)'; echo 'Starting: Relay 1 on port $PORT_RELAY1'; RUST_LOG=debug cargo run --bin moq-relay-ietf -- --bind '[::]:$PORT_RELAY1' --tls-cert ../dev/localhost.crt --tls-key ../dev/localhost.key --tls-disable-verify --api http://localhost:$PORT_MOQ_API --node https://localhost:$PORT_RELAY1 --dev --announce https://localhost:$PORT_MOQ_DIR/udp; exec bash\"" &
sleep $SLEEP_DURATION

# 5. Relay 2
xterm -T "Relay 2 (P:$PORT_RELAY2)" -e "bash -c \"cd moq-relay-ietf && echo 'Working directory: \$(pwd)'; echo 'Starting: Relay 2 on port $PORT_RELAY2'; RUST_LOG=debug cargo run --bin moq-relay-ietf -- --bind '[::]:$PORT_RELAY2' --tls-cert ../dev/localhost.crt --tls-key ../dev/localhost.key --tls-disable-verify --api http://localhost:$PORT_MOQ_API --node https://localhost:$PORT_RELAY2 --dev --announce https://localhost:$PORT_MOQ_DIR/udp; exec bash\"" &
sleep $SLEEP_DURATION

# 6. Relay 3
xterm -T "Relay 3 (P:$PORT_RELAY3)" -e "bash -c \"cd moq-relay-ietf && echo 'Working directory: \$(pwd)'; echo 'Starting: Relay 3 on port $PORT_RELAY3'; RUST_LOG=debug cargo run --bin moq-relay-ietf -- --bind '[::]:$PORT_RELAY3' --tls-cert ../dev/localhost.crt --tls-key ../dev/localhost.key --tls-disable-verify --api http://localhost:$PORT_MOQ_API --node https://localhost:$PORT_RELAY3 --dev --announce https://localhost:$PORT_MOQ_DIR/udp; exec bash\"" &
sleep $SLEEP_DURATION

# 7. Publisher
xterm -T "Publisher (to P:$PORT_RELAY1)" -e "bash -c \"echo 'Working directory: \$(pwd)'; echo 'Starting: Publisher (PORT $PORT_RELAY1)'; PORT=$PORT_RELAY1 ./dev/pub; exec bash\"" &
sleep $SLEEP_DURATION

# 8. Subscriber
xterm -T "Subscriber (from P:$PORT_RELAY3)" -e "bash -c \"echo 'Working directory: \$(pwd)'; echo 'Starting: Subscriber (PORT $PORT_RELAY3)'; PORT=$PORT_RELAY3 ./dev/sub; exec bash\"" &

echo ""
echo "All commands launched in separate xterm windows."
echo "Please arrange the windows on your screen as desired."
