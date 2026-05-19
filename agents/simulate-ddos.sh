#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="${AGENT_NAME:-$(hostname)}"
LOG="/var/log/wazuh-lab/ddos.log"
EVENTS="${EVENTS:-350}"
SLEEP_MS="${SLEEP_MS:-5}"
TARGET="${TARGET:-10.10.10.10}"

mkdir -p "$(dirname "$LOG")"

# TEST-NET ranges from RFC 5737: safe, non-routable example addresses.
SRC_POOL=("192.0.2.10" "192.0.2.11" "192.0.2.12" "198.51.100.21" "198.51.100.22" "203.0.113.30" "203.0.113.31")
PATHS=("/login" "/api/search" "/api/payments" "/checkout" "/static/app.js")
METHODS=("GET" "POST")

start_ts=$(date +%s)
for i in $(seq 1 "$EVENTS"); do
  src="${SRC_POOL[$((RANDOM % ${#SRC_POOL[@]}))]}"
  path="${PATHS[$((RANDOM % ${#PATHS[@]}))]}"
  method="${METHODS[$((RANDOM % ${#METHODS[@]}))]}"
  status=$([ $((RANDOM % 10)) -lt 8 ] && echo 200 || echo 503)
  bytes=$((RANDOM % 2048 + 128))
  printf '{"lab_type":"ddos","agent":"%s","srcip":"%s","dstip":"%s","method":"%s","path":"%s","status":%s,"bytes":%s,"event_no":%s,"scenario":"distributed_http_flood"}\n' \
    "$AGENT_NAME" "$src" "$TARGET" "$method" "$path" "$status" "$bytes" "$i" >> "$LOG"
  sleep "0.$(printf '%03d' "$SLEEP_MS")"
done

elapsed=$(( $(date +%s) - start_ts ))
[ "$elapsed" -le 0 ] && elapsed=1
eps=$(( EVENTS / elapsed ))
level="normal"
if [ "$eps" -ge 30 ]; then level="critical"; elif [ "$eps" -ge 10 ]; then level="high"; fi
printf '{"lab_type":"density","agent":"%s","events":%s,"seconds":%s,"eps":%s,"density_level":"%s","scenario":"distributed_http_flood"}\n' \
  "$AGENT_NAME" "$EVENTS" "$elapsed" "$eps" "$level" >> "$LOG"

echo "Generated ${EVENTS} DDoS telemetry events on ${AGENT_NAME}; EPS=${eps}; density=${level}"
