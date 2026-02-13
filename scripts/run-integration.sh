#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VNT_DIR="${VNT_DIR:-}"
VNTS_DIR="${VNTS_DIR:-}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/_artifacts}"

PORT="${VNT_PORT:-29872}"
TOKEN="${VNT_TOKEN:-integration}"
SERVER_ADDR="${VNT_SERVER_ADDR:-127.0.0.1:${PORT}}"
CLIENT1_NAME="${VNT_CLIENT1_NAME:-client1}"
CLIENT2_NAME="${VNT_CLIENT2_NAME:-client2}"
CLIENT1_ID="${VNT_CLIENT1_ID:-itest-1}"
CLIENT2_ID="${VNT_CLIENT2_ID:-itest-2}"
CLIENT1_NIC="${VNT_CLIENT1_NIC:-vnt-tun1}"
CLIENT2_NIC="${VNT_CLIENT2_NIC:-vnt-tun2}"
VNT_SUBNET="${VNT_SUBNET:-10.26.0.0/24}"
POLICY_TABLE1="${VNT_POLICY_TABLE1:-100}"
POLICY_TABLE2="${VNT_POLICY_TABLE2:-101}"
LIST_RETRIES="${VNT_LIST_RETRIES:-30}"
LIST_SLEEP="${VNT_LIST_SLEEP:-1}"
PING_COUNT="${VNT_PING_COUNT:-3}"

mkdir -p "$ARTIFACTS_DIR"

CLIENT1_PID=""
CLIENT2_PID=""
VNTS_PID=""
CLIENT1_IP=""
CLIENT2_IP=""

resolve_repo_dirs() {
  if [ -z "$VNT_DIR" ]; then
    if [ -d "$ROOT_DIR/vnt" ]; then
      VNT_DIR="$ROOT_DIR/vnt"
    elif [ -d "$ROOT_DIR/../vnt" ]; then
      VNT_DIR="$ROOT_DIR/../vnt"
    else
      echo "vnt directory not found; set VNT_DIR." >&2
      exit 1
    fi
  fi

  if [ -z "$VNTS_DIR" ]; then
    if [ -d "$ROOT_DIR/vnts" ]; then
      VNTS_DIR="$ROOT_DIR/vnts"
    elif [ -d "$ROOT_DIR/../vnts" ]; then
      VNTS_DIR="$ROOT_DIR/../vnts"
    else
      echo "vnts directory not found; set VNTS_DIR." >&2
      exit 1
    fi
  fi
}

ensure_ping() {
  if ! command -v ping >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ]; then
      echo "ping not found; please install iputils-ping or run as root." >&2
      exit 1
    fi
    apt-get update -y
    apt-get install -y iputils-ping
  fi
}

ensure_iproute() {
  if ! command -v ip >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ]; then
      echo "ip command not found; please install iproute2 or run as root." >&2
      exit 1
    fi
    apt-get update -y
    apt-get install -y iproute2
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
    output="$("${ROOT_PREFIX[@]}" "$bin" --list 2>/dev/null || true)"
    ip=$(printf '%s\n' "$output" | strip_ansi | awk -v name="$peer_name" 'NR>1 && $1==name {print $2; exit}')
    if [ -n "$ip" ]; then
      echo "$ip"
      return 0
    fi
    sleep "$LIST_SLEEP"
  done
  return 1
}

setup_policy_routing() {
  local ip="$1"
  local nic="$2"
  local table="$3"

  "${ROOT_PREFIX[@]}" ip rule add pref "$table" from "$ip" table "$table" 2>/dev/null || true
  "${ROOT_PREFIX[@]}" ip route add "$ip/32" dev "$nic" table "$table" 2>/dev/null || true
  "${ROOT_PREFIX[@]}" ip route add "$VNT_SUBNET" dev "$nic" table "$table" 2>/dev/null || true
}

cleanup_policy_routing() {
  local ip="$1"
  local table="$2"

  if [ -z "$ip" ]; then
    return 0
  fi
  "${ROOT_PREFIX[@]}" ip rule del pref "$table" from "$ip" table "$table" 2>/dev/null || true
  "${ROOT_PREFIX[@]}" ip route flush table "$table" 2>/dev/null || true
}

ROOT_PREFIX=()
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    ROOT_PREFIX=(sudo -E)
  else
    echo "vnt-cli requires root; please run as root or install sudo." >&2
    exit 1
  fi
fi

resolve_repo_dirs
ensure_ping
ensure_iproute

echo "Building vnts..."
cargo build --manifest-path "$VNTS_DIR/Cargo.toml"
echo "Building vnt-cli..."
cargo build --manifest-path "$VNT_DIR/Cargo.toml" -p vnt-cli

VNTS_BIN="$VNTS_DIR/target/debug/vnts"
VNT_BIN="$VNT_DIR/target/debug/vnt-cli"

CLIENT1_DIR="$ARTIFACTS_DIR/client1"
CLIENT2_DIR="$ARTIFACTS_DIR/client2"
mkdir -p "$CLIENT1_DIR" "$CLIENT2_DIR"
CLIENT1_BIN="$CLIENT1_DIR/vnt-cli"
CLIENT2_BIN="$CLIENT2_DIR/vnt-cli"
cp "$VNT_BIN" "$CLIENT1_BIN"
cp "$VNT_BIN" "$CLIENT2_BIN"
chmod +x "$CLIENT1_BIN" "$CLIENT2_BIN"

cleanup() {
  cleanup_policy_routing "$CLIENT1_IP" "$POLICY_TABLE1"
  cleanup_policy_routing "$CLIENT2_IP" "$POLICY_TABLE2"
  kill "$CLIENT1_PID" "$CLIENT2_PID" "$VNTS_PID" 2>/dev/null || true
  wait "$CLIENT1_PID" "$CLIENT2_PID" "$VNTS_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting vnts..."
"$VNTS_BIN" --port "$PORT" --log-path "$ARTIFACTS_DIR/vnts-log" >"$ARTIFACTS_DIR/vnts.log" 2>&1 &
VNTS_PID=$!

echo "Waiting for vnts TCP port..."
for i in $(seq 1 40); do
  if (echo >"/dev/tcp/127.0.0.1/$PORT") >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

CLIENT1_LOG="$ARTIFACTS_DIR/vnt-cli-1.log"
CLIENT2_LOG="$ARTIFACTS_DIR/vnt-cli-2.log"

echo "Starting client1..."
"${ROOT_PREFIX[@]}" "$CLIENT1_BIN" -k "$TOKEN" -d "$CLIENT1_ID" -n "$CLIENT1_NAME" -s "$SERVER_ADDR" --relay --disable-stats --allow-wg --nic "$CLIENT1_NIC" >"$CLIENT1_LOG" 2>&1 &
CLIENT1_PID=$!

echo "Starting client2..."
"${ROOT_PREFIX[@]}" "$CLIENT2_BIN" -k "$TOKEN" -d "$CLIENT2_ID" -n "$CLIENT2_NAME" -s "$SERVER_ADDR" --relay --disable-stats --allow-wg --nic "$CLIENT2_NIC" >"$CLIENT2_LOG" 2>&1 &
CLIENT2_PID=$!

if ! kill -0 "$CLIENT1_PID" 2>/dev/null || ! kill -0 "$CLIENT2_PID" 2>/dev/null; then
  echo "One of the vnt-cli processes exited early." >&2
  tail -n 50 "$CLIENT1_LOG" "$CLIENT2_LOG" >&2 || true
  exit 1
fi

echo "Waiting for clients to appear in --list..."
CLIENT2_IP="$(wait_for_peer_ip "$CLIENT1_BIN" "$CLIENT2_NAME" || true)"
CLIENT1_IP="$(wait_for_peer_ip "$CLIENT2_BIN" "$CLIENT1_NAME" || true)"

if [ -z "$CLIENT1_IP" ] || [ -z "$CLIENT2_IP" ]; then
  echo "Failed to resolve client IPs via --list." >&2
  echo "client1 list:" >&2
  "${ROOT_PREFIX[@]}" "$CLIENT1_BIN" --list >&2 || true
  echo "client2 list:" >&2
  "${ROOT_PREFIX[@]}" "$CLIENT2_BIN" --list >&2 || true
  tail -n 50 "$CLIENT1_LOG" "$CLIENT2_LOG" >&2 || true
  exit 1
fi

echo "client1 ip: $CLIENT1_IP"
echo "client2 ip: $CLIENT2_IP"

setup_policy_routing "$CLIENT1_IP" "$CLIENT1_NIC" "$POLICY_TABLE1"
setup_policy_routing "$CLIENT2_IP" "$CLIENT2_NIC" "$POLICY_TABLE2"

echo "Ping client2 from client1..."
"${ROOT_PREFIX[@]}" ping -I "$CLIENT1_IP" -c "$PING_COUNT" "$CLIENT2_IP"
echo "Ping client1 from client2..."
"${ROOT_PREFIX[@]}" ping -I "$CLIENT2_IP" -c "$PING_COUNT" "$CLIENT1_IP"

"${ROOT_PREFIX[@]}" "$CLIENT1_BIN" --stop >/dev/null 2>&1 || true
"${ROOT_PREFIX[@]}" "$CLIENT2_BIN" --stop >/dev/null 2>&1 || true

echo "Integration smoke test completed."
