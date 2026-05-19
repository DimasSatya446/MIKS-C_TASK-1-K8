param(
  [int]$WebRequests = 1000,
  [int]$SyntheticEventsPerAgent = 350
)
$ErrorActionPreference = "Stop"

Write-Host "[1/3] Simulasi web DDoS lokal ke http://web-target/ sebanyak $WebRequests request..."
docker exec attacker-simulator sh -c "apk add --no-cache curl >/dev/null 2>&1 || true; i=1; while [ `$i -le $WebRequests ]; do curl -s http://web-target/ >/dev/null & i=`$((i+1)); done; wait"

Write-Host "[2/3] Simulasi telemetry DDoS JSON di 3 agent sebanyak $SyntheticEventsPerAgent event/agent..."
docker exec wazuh-agent-1 bash -lc "EVENTS=$SyntheticEventsPerAgent SLEEP_MS=1 /opt/wazuh-lab/simulate-ddos.sh"
docker exec wazuh-agent-2 bash -lc "EVENTS=$SyntheticEventsPerAgent SLEEP_MS=1 /opt/wazuh-lab/simulate-ddos.sh"
docker exec wazuh-agent-3 bash -lc "EVENTS=$SyntheticEventsPerAgent SLEEP_MS=1 /opt/wazuh-lab/simulate-ddos.sh"

Write-Host "[3/3] Selesai. Tunggu 30-60 detik lalu jalankan .\scripts\06-check-alerts.ps1"
