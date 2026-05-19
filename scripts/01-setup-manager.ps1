param(
  [string]$WazuhVersion = "v4.14.5"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Runtime = Join-Path $Root "runtime"
$RepoDir = Join-Path $Runtime "wazuh-docker"
$SingleNode = Join-Path $RepoDir "single-node"

Write-Host "[1/5] Cek Docker..."
docker version | Out-Null

New-Item -ItemType Directory -Force -Path $Runtime | Out-Null

if (!(Test-Path $RepoDir)) {
  Write-Host "[2/5] Download official Wazuh Docker deployment $WazuhVersion..."
  $zip = Join-Path $Runtime "wazuh-docker.zip"
  $url = "https://github.com/wazuh/wazuh-docker/archive/refs/tags/$WazuhVersion.zip"
  try {
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Force -Path $zip -DestinationPath $Runtime
    $expanded = Get-ChildItem $Runtime -Directory | Where-Object { $_.Name -like "wazuh-docker-*" } | Select-Object -First 1
    Move-Item $expanded.FullName $RepoDir
  } catch {
    Write-Host "Tag gagal, coba branch $WazuhVersion..."
    $url = "https://github.com/wazuh/wazuh-docker/archive/refs/heads/$WazuhVersion.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Force -Path $zip -DestinationPath $Runtime
    $expanded = Get-ChildItem $Runtime -Directory | Where-Object { $_.Name -like "wazuh-docker-*" } | Select-Object -First 1
    Move-Item $expanded.FullName $RepoDir
  }
} else {
  Write-Host "[2/5] runtime/wazuh-docker sudah ada. Skip download."
}

if (!(Test-Path $SingleNode)) { throw "Folder single-node tidak ditemukan di runtime Wazuh Docker." }

Write-Host "[3/5] Generate certificate indexer jika tersedia..."
Push-Location $SingleNode
if (Test-Path "generate-indexer-certs.yml") {
  docker compose -f generate-indexer-certs.yml run --rm generator
} else {
  Write-Host "Generator cert tidak ditemukan; lanjut."
}

Write-Host "[4/5] Start Wazuh Manager, Indexer, Dashboard..."
docker compose -p wazuhlab up -d
Pop-Location

Write-Host "[5/5] Tunggu startup awal 30 detik..."
Start-Sleep -Seconds 30
Write-Host "Selesai. Lanjut: .\scripts\02-apply-rules.ps1"
