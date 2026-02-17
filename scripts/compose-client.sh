#!/usr/bin/env bash
set -euo pipefail

TOKEN="${VNT_TOKEN:-integration}"
SERVER_ADDR="${VNT_SERVER_ADDR:-vnts:29872}"
CLIENT_ID="${VNT_CLIENT_ID:-itest-1}"
CLIENT_NAME="${VNT_CLIENT_NAME:-client1}"
CLIENT_NIC="${VNT_CLIENT_NIC:-vnt-tun}"

exec /workspace/bin/vnt-cli -k "$TOKEN" -d "$CLIENT_ID" -n "$CLIENT_NAME" -s "$SERVER_ADDR" --relay --disable-stats --allow-wg --nic "$CLIENT_NIC"
