# scripts/08-start-soar.ps1
$repoRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $repoRoot

Write-Host "=== Memulai SOAR Engine & Dashboard ===" -ForegroundColor Cyan

# 1. Cek status Wazuh Manager
$managerStatus = docker inspect --format='{{.State.Running}}' wazuhlab-wazuh.manager-1 2>$null

if ($managerStatus -ne "true") {
    Write-Host "[ERR] Kontainer 'wazuhlab-wazuh.manager-1' belum berjalan." -ForegroundColor Red
    Write-Host "[INFO] Silakan jalankan lab Wazuh terlebih dahulu menggunakan script:" -ForegroundColor Yellow
    Write-Host "  .\scripts\01-setup-manager.ps1" -ForegroundColor Yellow
    Write-Host "  .\scripts\03-start-lab.ps1" -ForegroundColor Yellow
    Exit 1
}

Write-Host "[OK] Wazuh Manager aktif dan siap menerima query." -ForegroundColor Green

# 2. Deploy SOAR Stack
Write-Host "[INFO] Membangun kontainer SOAR (Redis, Engine, Dashboard)..." -ForegroundColor Yellow
docker compose -f docker-compose.soar.yml up -d --build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERR] Proses deployment compose SOAR gagal." -ForegroundColor Red
    Exit 1
}

# 3. Validasi Health Check
Write-Host "[INFO] Memverifikasi status kesiapan SOAR Dashboard..." -ForegroundColor Yellow
$maxRetries = 20
$retryCount = 0
$healthy = $false

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5050" -Method Get -TimeoutSec 2 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    }
    catch {
        # Silent ignore connection failures during startup
    }
    $retryCount++
    Start-Sleep -Seconds 3
    Write-Host "." -NoNewline
}

Write-Host ""

if ($healthy) {
    Write-Host "[OK] SOAR Dashboard berjalan di: http://localhost:5050" -ForegroundColor Green
    Write-Host "[OK] SOAR Engine memonitor log secara otomatis." -ForegroundColor Green
    Write-Host "[INFO] Gunakan perintah ini untuk memantau aktivitas respons:" -ForegroundColor Yellow
    Write-Host "  docker logs -f soar-engine" -ForegroundColor Cyan
} else {
    Write-Host "[WARN] Dashboard SOAR terindikasi lambat merespons. Periksa status kontainer Anda dengan 'docker ps'." -ForegroundColor Yellow
}
