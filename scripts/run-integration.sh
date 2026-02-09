#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VNT_DIR="${VNT_DIR:-$ROOT_DIR/vnt}"
VNTS_DIR="${VNTS_DIR:-$ROOT_DIR/vnts}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/_artifacts}"
VNT_REPO="${VNT_REPO:-middlescale/vnt}"
VNTS_REPO="${VNTS_REPO:-middlescale/vnts}"
VNT_REF="${VNT_REF:-}"
VNTS_REF="${VNTS_REF:-master}"

PORT="${VNT_PORT:-29872}"
TOKEN="${VNT_TOKEN:-integration}"
DEVICE_ID="${VNT_DEVICE_ID:-itest-1}"
DEVICE_NAME="${VNT_DEVICE_NAME:-itest-1}"
SERVER_ADDR="${VNT_SERVER_ADDR:-vnts:${PORT}}"
RUN_SECONDS="${VNT_RUN_SECONDS:-10}"

mkdir -p "$ARTIFACTS_DIR"

ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y git ca-certificates
  fi
}

clone_repo() {
  local name="$1"
  local repo="$2"
  local ref="$3"
  local dir="$4"

  if [ -f "$dir/Cargo.toml" ]; then
    return 0
  fi

  ensure_git
  if [ -n "$ref" ]; then
    echo "Cloning ${name} from ${repo} (${ref})..."
    if ! git clone --depth 1 --branch "$ref" "https://github.com/${repo}.git" "$dir" 2>/dev/null; then
      git clone "https://github.com/${repo}.git" "$dir"
      git -C "$dir" checkout "$ref"
    fi
  else
    echo "Cloning ${name} from ${repo} (default branch)..."
    git clone --depth 1 "https://github.com/${repo}.git" "$dir"
  fi
}

clone_repo "vnts" "$VNTS_REPO" "$VNTS_REF" "$VNTS_DIR"
clone_repo "vnt" "$VNT_REPO" "$VNT_REF" "$VNT_DIR"

echo "Building vnts..."
cargo build --manifest-path "$VNTS_DIR/Cargo.toml"
echo "Building vnt-cli..."
cargo build --manifest-path "$VNT_DIR/Cargo.toml" -p vnt-cli

VNTS_BIN="$VNTS_DIR/target/debug/vnts"
VNT_BIN="$VNT_DIR/target/debug/vnt-cli"

echo "Starting vnts..."
"$VNTS_BIN" --port "$PORT" --log-path "$ARTIFACTS_DIR/vnts-log" >"$ARTIFACTS_DIR/vnts.log" 2>&1 &
VNTS_PID=$!

cleanup() {
  kill "$VNTS_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for vnts TCP port..."
for i in $(seq 1 20); do
  if (echo >"/dev/tcp/127.0.0.1/$PORT") >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

RUN_CMD=("$VNT_BIN" -k "$TOKEN" -d "$DEVICE_ID" -n "$DEVICE_NAME" -s "$SERVER_ADDR" --relay --disable-stats --allow-wg)
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    RUN_CMD=(sudo -E "${RUN_CMD[@]}")
  else
    echo "vnt-cli requires root; please run as root or install sudo." >&2
    exit 1
  fi
fi

echo "Running vnt-cli smoke test for ${RUN_SECONDS}s..."
set +e
timeout "${RUN_SECONDS}s" "${RUN_CMD[@]}"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ] && [ "$STATUS" -ne 124 ]; then
  echo "vnt-cli exited with status $STATUS" >&2
  exit "$STATUS"
fi

echo "Integration smoke test completed."
