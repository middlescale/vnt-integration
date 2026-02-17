#!/usr/bin/env bash
set -euo pipefail

LIST_RETRIES="${VNT_LIST_RETRIES:-40}"
LIST_SLEEP="${VNT_LIST_SLEEP:-2}"
PING_COUNT="${VNT_PING_COUNT:-3}"

strip_ansi() {
  sed -r 's/\x1b\[[0-9;]*m//g'
}

wait_for_peer_field() {
  local service="$1"
  local peer="$2"
  local field="$3"
  local attempt output value

  for attempt in $(seq 1 "$LIST_RETRIES"); do
    output="$(docker compose exec -T "$service" /workspace/bin/vnt-cli --list 2>/dev/null | strip_ansi || true)"
    value="$(printf '%s\n' "$output" | awk -v name="$peer" -v idx="$field" 'NR>1 && $1==name {print $idx; exit}')"
    if [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
    sleep "$LIST_SLEEP"
  done
  return 1
}

wait_for_peer_status() {
  local service="$1"
  local peer="$2"
  local expected="$3"
  local attempt status

  for attempt in $(seq 1 "$LIST_RETRIES"); do
    status="$(docker compose exec -T "$service" /workspace/bin/vnt-cli --list 2>/dev/null | strip_ansi | awk -v name="$peer" 'NR>1 && $1==name {print $3; exit}' || true)"
    if [ "$status" = "$expected" ]; then
      return 0
    fi
    sleep "$LIST_SLEEP"
  done
  echo "Expected $peer on $service to be $expected but got '${status:-<empty>}'" >&2
  return 1
}

client2_ip="$(wait_for_peer_field client1 client2 2)"
client1_ip="$(wait_for_peer_field client2 client1 2)"

wait_for_peer_status client1 client2 Online
wait_for_peer_status client2 client1 Online

docker compose exec -T client1 ping -c "$PING_COUNT" "$client2_ip"
docker compose exec -T client2 ping -c "$PING_COUNT" "$client1_ip"

docker compose stop client2
wait_for_peer_status client1 client2 Offline

echo "compose integration checks passed (online -> offline)."
