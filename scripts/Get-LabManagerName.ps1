$manager = docker ps --format '{{.Names}}' | Where-Object { $_ -match 'wazuh.*manager' } | Select-Object -First 1
if (-not $manager) { throw 'Wazuh Manager container tidak ditemukan. Jalankan scripts\01-setup-manager.ps1 dulu.' }
$manager
