$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Manager = & (Join-Path $Root "scripts\Get-LabManagerName.ps1")

Write-Host "=== Container aktif ==="
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

Write-Host "`n=== Agent Wazuh ==="
docker exec $Manager /var/ossec/bin/agent_control -l

Write-Host "`n=== Web target log sample ==="
docker logs web-target --tail 20

Write-Host "`n=== Alert DDoS JSON / density ==="
docker exec $Manager sh -c "grep -E '100100|100101|100102|100103' /var/ossec/logs/alerts/alerts.json | tail -n 10 || echo BELUM_ADA_ALERT_DDOS_JSON"

Write-Host "`n=== Alert Web DDoS Nginx ==="
docker exec $Manager sh -c "grep -E '100301|100302' /var/ossec/logs/alerts/alerts.json | tail -n 10 || echo BELUM_ADA_ALERT_WEB_DDOS"

Write-Host "`n=== Alert Malware EICAR/YARA ==="
docker exec $Manager sh -c "grep -E '100200|100201' /var/ossec/logs/alerts/alerts.json | tail -n 10 || echo BELUM_ADA_ALERT_MALWARE"
