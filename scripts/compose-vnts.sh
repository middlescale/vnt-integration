#!/usr/bin/env bash
set -euo pipefail

PORT="${VNT_PORT:-29872}"
ARTIFACTS_DIR="/workspace/integration/_artifacts"

mkdir -p "$ARTIFACTS_DIR"

cargo build --manifest-path /workspace/vnts/Cargo.toml

exec /workspace/vnts/target/debug/vnts --port "$PORT" --log-path "$ARTIFACTS_DIR/vnts-log"
