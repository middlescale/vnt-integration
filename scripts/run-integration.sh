#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -z "${VNT_DIR:-}" ]; then
  if [ -d "./vnt" ]; then
    export VNT_DIR="./vnt"
  elif [ -d "../vnt" ]; then
    export VNT_DIR="../vnt"
  fi
else
  export VNT_DIR
fi

if [ -z "${VNTS_DIR:-}" ]; then
  if [ -d "./vnts" ]; then
    export VNTS_DIR="./vnts"
  elif [ -d "../vnts" ]; then
    export VNTS_DIR="../vnts"
  fi
else
  export VNTS_DIR
fi

cleanup() {
  docker compose down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker compose up --abort-on-container-exit --exit-code-from vnt1
