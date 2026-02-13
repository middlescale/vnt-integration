#!/usr/bin/env bash
set -euo pipefail

ROLE="${VNT_ROLE:-client}"
NAME="${VNT_NAME:-client}"
DEVICE_ID="${VNT_ID:-itest}"
TOKEN="${VNT_TOKEN:-integration}"
SERVER_ADDR="${VNT_SERVER_ADDR:-vnts:29872}"
NIC="${VNT_NIC:-vnt-tun}"
PEER_NAME="${VNT_PEER_NAME:-client2}"
LIST_RETRIES="${VNT_LIST_RETRIES:-30}"
LIST_SLEEP="${VNT_LIST_SLEEP:-1}"
CONNECT_RETRIES="${VNT_CONNECT_RETRIES:-180}"
CONNECT_SLEEP="${VNT_CONNECT_SLEEP:-1}"
PING_COUNT="${VNT_PING_COUNT:-3}"
ARTIFACTS_DIR="/workspace/integration/_artifacts"

mkdir -p "$ARTIFACTS_DIR"

ensure_ping() {
  if ! command -v ping >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y iputils-ping
  fi
}

strip_ansi() {
  sed -r 's/\x1b\[[0-9;]*m//g'
}

wait_for_peer_ip() {
  local bin="$1"
  local peer_name="$2"
  local attempt output ip

  for attempt in $(seq 1 "$LIST_RETRIES"); do
    output="$("$bin" --list 2>/dev/null || true)"
    ip=$(printf '%s\n' "$output" | strip_ansi | awk -v name="$peer_name" 'NR>1 && $1==name {print $2; exit}')
    if [ -n "$ip" ]; then
      echo "$ip"
      return 0
    fi
    sleep "$LIST_SLEEP"
  done
  return 1
}

wait_for_log() {
  local log_file="$1"
  local pattern="$2"
  local attempt

  for attempt in $(seq 1 "$CONNECT_RETRIES"); do
    if [ -f "$log_file" ] && grep -q "$pattern" "$log_file"; then
      return 0
    fi
    sleep "$CONNECT_SLEEP"
  done
  return 1
}

ensure_ping

if [ ! -x /workspace/vnt/target/debug/vnt-cli ]; then
  cargo build --manifest-path /workspace/vnt/Cargo.toml -p vnt-cli
fi

BIN="/tmp/vnt-cli"
cp /workspace/vnt/target/debug/vnt-cli "$BIN"
chmod +x "$BIN"

LOG="$ARTIFACTS_DIR/vnt-cli-${NAME}.log"
ARGS=(-k "$TOKEN" -d "$DEVICE_ID" -n "$NAME" -s "$SERVER_ADDR" --relay --disable-stats --allow-wg --nic "$NIC")

if [ "$ROLE" = "tester" ]; then
  "$BIN" "${ARGS[@]}" >"$LOG" 2>&1 &
  PID=$!

  PEER_LOG="$ARTIFACTS_DIR/vnt-cli-${PEER_NAME}.log"
  if ! wait_for_log "$LOG" "Connect Successfully"; then
    echo "Client did not connect successfully." >&2
    tail -n 50 "$LOG" >&2 || true
    exit 1
  fi
  if ! wait_for_log "$PEER_LOG" "Connect Successfully"; then
    echo "Peer did not connect successfully." >&2
    tail -n 50 "$PEER_LOG" >&2 || true
    exit 1
  fi

  PEER_IP="$(wait_for_peer_ip "$BIN" "$PEER_NAME" || true)"
  if [ -z "$PEER_IP" ]; then
    echo "Failed to resolve peer IP via --list." >&2
    "$BIN" --list >&2 || true
    tail -n 50 "$LOG" "$PEER_LOG" >&2 || true
    exit 1
  fi

  echo "peer ip: $PEER_IP"
  ping -I "$NIC" -c "$PING_COUNT" "$PEER_IP"

  "$BIN" --stop >/dev/null 2>&1 || true
  wait "$PID" || true
  exit 0
fi

exec "$BIN" "${ARGS[@]}" >"$LOG" 2>&1
