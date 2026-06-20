# scripts/00-setup-env.ps1
# Mendapatkan root path repositori
$repoRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $repoRoot

Write-Host "=== Memulai Setup Environment & Certificates ===" -ForegroundColor Cyan

# 1. Menulis file .env
$envContent = @"
INDEXER_USERNAME=admin
INDEXER_PASSWORD=SecretPassword
WAZUH_API_USER=wazuh-wui
WAZUH_API_PASSWORD=MyS3cr37P450r.*-
WAZUH_MANAGER_PASSWORD=SecretPassword
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=SecretPassword
"@

$envPath = Join-Path $repoRoot ".env"
if (Test-Path $envPath) {
    Write-Host "[INFO] File .env sudah ada. Menimpa dengan konfigurasi default..." -ForegroundColor Yellow
}
$envContent | Out-File -Encoding UTF8 -NoNewline -FilePath $envPath
Write-Host "[OK] File .env berhasil dibuat." -ForegroundColor Green

# 2. Membuat direktori certs di host terlebih dahulu
$certsPath = Join-Path $repoRoot "certs"
if (!(Test-Path $certsPath)) {
    New-Item -ItemType Directory -Path $certsPath | Out-Null
    Write-Host "[OK] Folder certs berhasil dibuat." -ForegroundColor Green
}

# 3. Generate certs via Alpine/OpenSSL kontainer
$certScript = @'
#!/bin/sh
mkdir -p /certs/root /certs/manager /certs/indexer /certs/dashboard /certs/agent
# Root CA
openssl req -x509 -newkey rsa:4096 -keyout /certs/root/root-ca-key.pem \
  -out /certs/root/root-ca.pem -days 3650 -nodes \
  -subj "/C=ID/ST=EastJava/L=Surabaya/O=WazuhLab/CN=WazuhRoot"
# Indexer cert
openssl req -newkey rsa:4096 -keyout /certs/indexer/indexer-key.pem \
  -out /certs/indexer/indexer.csr -nodes -subj "/CN=wazuh.indexer"
openssl x509 -req -in /certs/indexer/indexer.csr \
  -CA /certs/root/root-ca.pem -CAkey /certs/root/root-ca-key.pem \
  -CAcreateserial -out /certs/indexer/indexer.pem -days 3650
# Manager cert
openssl req -newkey rsa:4096 -keyout /certs/manager/manager-key.pem \
  -out /certs/manager/manager.csr -nodes -subj "/CN=wazuh.manager"
openssl x509 -req -in /certs/manager/manager.csr \
  -CA /certs/root/root-ca.pem -CAkey /certs/root/root-ca-key.pem \
  -CAcreateserial -out /certs/manager/manager.pem -days 3650
# Dashboard cert
openssl req -newkey rsa:4096 -keyout /certs/dashboard/dashboard-key.pem \
  -out /certs/dashboard/dashboard.csr -nodes -subj "/CN=wazuh.dashboard"
openssl x509 -req -in /certs/dashboard/dashboard.csr \
  -CA /certs/root/root-ca.pem -CAkey /certs/root/root-ca-key.pem \
  -CAcreateserial -out /certs/dashboard/dashboard.pem -days 3650
# Set permissions
chmod 600 /certs/root/*.pem /certs/manager/*.pem /certs/indexer/*.pem /certs/dashboard/*.pem
'@

$tempScriptPath = Join-Path $repoRoot "temp_cert.sh"
$certScript | Out-File -Encoding UTF8 -NoNewline -FilePath $tempScriptPath

Write-Host "[INFO] Menjalankan generator sertifikat di kontainer Alpine..." -ForegroundColor Yellow

# Normalisasi path windows agar kompatibel dengan volume mount Docker Desktop
$normalizedPwd = $repoRoot.Path.Replace('\', '/')
if ($normalizedPwd -match '^[A-Za-z]:') {
    $drive = $normalizedPwd.Substring(0,1).ToLower()
    $rest = $normalizedPwd.Substring(2)
    $dockerVolumePath = "/$drive$rest"
} else {
    $dockerVolumePath = $normalizedPwd
}

docker run --rm `
  -v "${dockerVolumePath}:/work" `
  -v "${dockerVolumePath}/certs:/certs" `
  alpine:3.19 sh -c "apk add --no-cache openssl && tr -d '\r' < /work/temp_cert.sh | sh"

if (Test-Path $tempScriptPath) {
    Remove-Item $tempScriptPath -Force
}

# 4. Validasi output sertifikat
$requiredCerts = @(
    "certs/root/root-ca.pem",
    "certs/indexer/indexer.pem",
    "certs/indexer/indexer-key.pem",
    "certs/manager/manager.pem",
    "certs/manager/manager-key.pem",
    "certs/dashboard/dashboard.pem",
    "certs/dashboard/dashboard-key.pem"
)

$allExist = $true
foreach ($cert in $requiredCerts) {
    $fullPath = Join-Path $repoRoot $cert
    if (!(Test-Path $fullPath)) {
        Write-Host "[ERR] File sertifikat tidak ditemukan: $cert" -ForegroundColor Red
        $allExist = $false
    }
}

if ($allExist) {
    Write-Host "=== Setup Selesai dengan Sukses! ===" -ForegroundColor Green
} else {
    Write-Host "=== Setup Gagal. Beberapa sertifikat tidak terbentuk. ===" -ForegroundColor Red
    Exit 1
}
