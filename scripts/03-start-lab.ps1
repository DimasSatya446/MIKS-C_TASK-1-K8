$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$network = docker network ls --format "{{.Name}}" | Where-Object { $_ -match "wazuhlab" } | Select-Object -First 1
if (-not $network) { throw "Network Wazuh tidak ditemukan. Jalankan 01-setup-manager.ps1 dulu." }

Write-Host "Menggunakan network Wazuh: $network"
$env:WAZUH_NETWORK = $network
Push-Location $Root
docker compose -f docker-compose.lab.yml -p wazuhfinallab up -d --build
Pop-Location

Write-Host "Lab services start: 3 agent + web-target + attacker-simulator. Tunggu 1-2 menit agar agent enrollment selesai."
