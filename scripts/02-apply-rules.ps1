$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SingleNode = Join-Path $Root "runtime\wazuh-docker\single-node"
$Rules = Join-Path $Root "manager\local_rules.xml"
$Decoders = Join-Path $Root "manager\local_decoder.xml"

if (!(Test-Path $SingleNode)) { throw "Folder official Wazuh single-node tidak ditemukan. Jalankan 01-setup-manager.ps1 dulu." }

Push-Location $SingleNode
Write-Host "Copy custom rules dan decoder ke Wazuh Manager..."
docker compose -p wazuhlab cp $Rules wazuh.manager:/var/ossec/etc/rules/local_rules.xml
docker compose -p wazuhlab cp $Decoders wazuh.manager:/var/ossec/etc/decoders/local_decoder.xml

Write-Host "Restart Wazuh Manager supaya rule/decoder dibaca..."
docker compose -p wazuhlab restart wazuh.manager
Pop-Location

Start-Sleep -Seconds 45
$Manager = & (Join-Path $Root "scripts\Get-LabManagerName.ps1")
Write-Host "Cek status manager: $Manager"
docker exec $Manager /var/ossec/bin/wazuh-control status
Write-Host "Selesai. Lanjut: .\scripts\03-start-lab.ps1"
