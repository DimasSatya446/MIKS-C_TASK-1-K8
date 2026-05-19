$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $Root
$network = docker network ls --format "{{.Name}}" | Where-Object { $_ -match "wazuhlab" } | Select-Object -First 1
if ($network) { $env:WAZUH_NETWORK = $network }
docker compose -f docker-compose.lab.yml -p wazuhfinallab down
Pop-Location

$SingleNode = Join-Path $Root "runtime\wazuh-docker\single-node"
if (Test-Path $SingleNode) {
  Push-Location $SingleNode
  docker compose -p wazuhlab down
  Pop-Location
}
Write-Host "Lab Docker dihentikan. Untuk hapus storage image/cache: docker system prune -a"
