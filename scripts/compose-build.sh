#!/usr/bin/env bash
set -euo pipefail

VNT_DIR="${VNT_DIR:-/workspace/vnt}"
VNTS_DIR="${VNTS_DIR:-/workspace/vnts}"
BIN_DIR="${BIN_DIR:-/workspace/bin}"

echo "Building vnts..."
cargo build --manifest-path "$VNTS_DIR/Cargo.toml"
echo "Building vnt-cli..."
cargo build --manifest-path "$VNT_DIR/Cargo.toml" -p vnt-cli

mkdir -p "$BIN_DIR"
cp "$VNTS_DIR/target/debug/vnts" "$BIN_DIR/vnts"
cp "$VNT_DIR/target/debug/vnt-cli" "$BIN_DIR/vnt-cli"
chmod +x "$BIN_DIR/vnts" "$BIN_DIR/vnt-cli"
