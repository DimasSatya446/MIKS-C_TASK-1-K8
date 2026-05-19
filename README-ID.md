# Wazuh Docker Final Lab — DDoS + Malware Detection PoC

## 1. Deskripsi Singkat

Lab ini digunakan untuk menguji kemampuan SIEM Wazuh dalam mendeteksi:

- DDoS / traffic anomaly
- Web DDoS terhadap Nginx local target
- Logging density dan distribusi event
- Malware detection validation menggunakan EICAR/YARA test
- Alert generation di Wazuh Manager dan Wazuh Dashboard

Lab ini berjalan secara lokal menggunakan Docker Desktop di Windows.

Tidak ada serangan ke website publik. Semua simulasi dilakukan di lingkungan lokal Docker.

---

## 2. Arsitektur

```text
Windows Host
└── Docker Desktop
    ├── Wazuh Manager
    ├── Wazuh Indexer
    ├── Wazuh Dashboard
    ├── Wazuh Agent 1 - Web
    ├── Wazuh Agent 2 - Traffic
    ├── Wazuh Agent 3 - Malware
    ├── Web Target Nginx
    └── Attacker Simulator
```

Alur deteksi:

```text
Attacker Simulator
        ↓
Web Target Nginx
        ↓
Log / Event
        ↓
Wazuh Agent
        ↓
Wazuh Manager
        ↓
Rule Matching
        ↓
Alert
        ↓
Wazuh Dashboard
```

---

## 3. Requirement

Pastikan sudah tersedia:

- Windows 10/11
- Docker Desktop
- WSL2 backend aktif
- PowerShell
- Browser
- Minimal RAM disarankan: 16 GB
- Free storage disarankan: 30 GB

Cek Docker:

```powershell
docker info
```

Pastikan ada:

```text
OSType: linux
```

---

## 4. File yang Digunakan

Gunakan hanya paket final:

```text
wazuh-docker-final-lab.zip
```

Tidak perlu menggunakan paket lama:

```text
wazuh-windows-docker-lab.zip
wazuh-web-target-ddos-addon.zip
wazuh-defensive-lab.zip
wazuh-azure-ddos-malware-lab.zip
```

---

Pastikan isi folder dengan:

```powershell
dir
```

Harus ada:

```text
scripts
manager
agents
web
docker-compose.lab.yml
README-ID.md
```

---

## 6. Izinkan Script PowerShell

Jalankan:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Fungsi:

```text
Mengizinkan file .ps1 berjalan hanya untuk sesi terminal saat ini.
```

---

## 7. Setup Wazuh Manager, Indexer, Dashboard

Jalankan:

```powershell
.\scripts\01-setup-manager.ps1
```

Fungsi:

```text
Menjalankan Wazuh Manager, Wazuh Indexer, dan Wazuh Dashboard.
```

Cek container:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Harus ada:

```text
wazuhlab-wazuh.manager-1
wazuhlab-wazuh.dashboard-1
wazuhlab-wazuh.indexer-1
```

Cek status manager:

```powershell
docker exec wazuhlab-wazuh.manager-1 /var/ossec/bin/wazuh-control status
```

Minimal harus running:

```text
wazuh-logcollector
wazuh-remoted
wazuh-analysisd
wazuh-db
wazuh-authd
wazuh-apid
```

Catatan:

```text
wazuh-clusterd, wazuh-maild, wazuh-agentlessd, wazuh-integratord, wazuh-dbd, dan wazuh-csyslogd boleh not running untuk lab ini.
```

---

## 8. Apply Custom Rules dan Decoder

Jalankan:

```powershell
.\scripts\02-apply-rules.ps1
```

Fungsi:

```text
Meng-copy custom rule dan decoder ke Wazuh Manager.
Rule ini digunakan untuk DDoS, web DDoS, density report, dan malware test.
```

Cek ulang manager:

```powershell
docker exec wazuhlab-wazuh.manager-1 /var/ossec/bin/wazuh-control status
```

---

## 9. Start 3 Agent, Web Target, dan Attacker

Jalankan:

```powershell
.\scripts\03-start-lab.ps1
```

Fungsi:

```text
Menjalankan 3 Wazuh Agent, web target Nginx, dan attacker simulator.
```

Cek container:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Harus ada:

```text
wazuh-agent-1
wazuh-agent-2
wazuh-agent-3
web-target
attacker-simulator
wazuhlab-wazuh.manager-1
wazuhlab-wazuh.dashboard-1
wazuhlab-wazuh.indexer-1
```

---

## 10. Cek Agent Aktif

Jalankan:

```powershell
docker exec wazuhlab-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

Agent final yang harus aktif:

```text
wazuh-agent-1-web
wazuh-agent-2-traffic
wazuh-agent-3-malware
```

Contoh output valid:

```text
ID: 004, Name: wazuh-agent-3-malware, Active
ID: 005, Name: wazuh-agent-2-traffic, Active
ID: 006, Name: wazuh-agent-1-web, Active
```

Jika ada agent lama seperti ini:

```text
wazuh-agent-1 Disconnected
wazuh-agent-2 Never connected
wazuh-agent-3 Disconnected
```

Itu sisa registrasi lama dan bisa diabaikan selama 3 agent final aktif.

---

## 11. Akses Web Target

Buka browser:

```text
http://localhost:8080
```

Jika halaman Nginx/lab muncul, berarti web target berhasil berjalan.

---

## 12. Jalankan Simulasi DDoS

Jalankan:

```powershell
.\scripts\04-run-ddos.ps1 -WebRequests 1500 -SyntheticEventsPerAgent 500
```

Fungsi:

```text
Mengirim request ke web target lokal.
Membuat telemetry DDoS dari agent.
Membuat laporan logging density/distribution.
```

Cek log web target:

```powershell
docker logs web-target --since 2m --tail 50
```

Output yang diharapkan:

```text
GET / HTTP/1.1
```

Contoh:

```text
172.20.0.9 - - [19/May/2026:12:53:53 +0000] "GET / HTTP/1.1" 200 617 "-" "curl/8.14.1" "-"
```

Artinya web target menerima banyak request dari attacker simulator.

---

## 13. Generate Web DDoS Event untuk Alert 100301/100302

Jalankan:

```powershell
$events = 1..80 | ForEach-Object {
  '{"lab_type":"web_ddos","agent":"wazuh-agent-1-web","srcip":"172.20.0.9","dstip":"web-target","method":"GET","path":"/","status":200,"user_agent":"curl","event_no":' + $_ + ',"scenario":"nginx_http_flood"}'
}

$events | docker exec -i wazuh-agent-1 sh -c "cat >> /var/log/wazuh-lab/ddos.log"
```

Fungsi:

```text
Membuat event web_ddos terstruktur agar Wazuh Manager memunculkan alert web DDoS.
```

Cek format event:

```powershell
docker exec wazuh-agent-1 tail -n 5 /var/log/wazuh-lab/ddos.log
```

Format yang benar:

```json
{"lab_type":"web_ddos","agent":"wazuh-agent-1-web","srcip":"172.20.0.9","dstip":"web-target","method":"GET","path":"/","status":200,"user_agent":"curl","event_no":60,"scenario":"nginx_http_flood"}
```

Cek alert web DDoS:

```powershell
docker exec wazuhlab-wazuh.manager-1 sh -c "grep -E '100301|100302' /var/ossec/logs/alerts/alerts.json | tail -n 10 || echo BELUM_ADA_ALERT_WEB_DDOS"
```

Jika muncul `100301` atau `100302`, berarti alert web DDoS berhasil.

---

## 14. Jalankan Malware Test

Jalankan:

```powershell
.\scripts\05-run-malware.ps1
```

Fungsi:

```text
Menjalankan simulasi malware aman menggunakan EICAR/YARA test.
Ini bukan malware asli.
```

Tunggu 20–30 detik.

Cek alert malware:

```powershell
docker exec wazuhlab-wazuh.manager-1 sh -c "grep -E '100200|100201' /var/ossec/logs/alerts/alerts.json | tail -n 10 || echo BELUM_ADA_ALERT_MALWARE"
```

Alert malware:

```text
100200 = YARA/EICAR malware detected, level 12
100201 = Malware artifact/test file created, level 8
```

Jika hanya muncul `100201`, itu tetap valid sebagai operational validation bahwa artifact malware test tercatat. Untuk critical malware signature, targetnya adalah `100200`.

---

## 15. Cek Semua Alert

Jalankan:

```powershell
.\scripts\06-check-alerts.ps1
```

Fungsi:

```text
Menampilkan container aktif, agent aktif, sample log web, alert DDoS, alert web DDoS, dan alert malware.
```

Rule ID penting:

```text
100100 = DDoS telemetry event received
100101 = High DDoS telemetry burst
100102 = Distributed high-volume DDoS pattern
100103 = Logging density/distribution report
100301 = Web target DDoS event detected
100302 = Critical high web DDoS burst
100200 = YARA/EICAR malware signature detected
100201 = Malware artifact created
```

---

## 16. Akses Wazuh Dashboard

Buka browser:

```text
https://localhost
```

Jika muncul warning:

```text
Your connection is not private
NET::ERR_CERT_AUTHORITY_INVALID
```

Klik:

```text
Advanced
Proceed to localhost
```

Jika tombol Proceed tidak muncul, klik halaman kosong lalu ketik:

```text
thisisunsafe
```

Login default:

```text
Username: admin
Password: SecretPassword
```

---

## 17. Buka Halaman Alert di Dashboard

Setelah login, masuk ke:

```text
Menu kiri
Wazuh
Threat Hunting
Events
```

atau:

```text
Wazuh
Security events
```

Set time range:

```text
Last 15 minutes
```

Jika tidak ada search/query bar, gunakan fitur:

```text
Add filter
```

Filter yang bisa digunakan:

```text
rule.id = 100100
rule.id = 100103
rule.id = 100301
rule.id = 100302
rule.id = 100200
rule.id = 100201
```

Atau search keyword:

```text
wazuh_lab
web_ddos
malware
EICAR
ddos
```

---

## 18. Screenshot yang Perlu Diambil untuk Laporan

Ambil screenshot berikut:

### 1. Container Running

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Bukti:

```text
Manager, Dashboard, Indexer, 3 Agent, Web Target, dan Attacker berjalan.
```

### 2. Agent Active

```powershell
docker exec wazuhlab-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

Bukti:

```text
wazuh-agent-1-web Active
wazuh-agent-2-traffic Active
wazuh-agent-3-malware Active
```

### 3. Web Target Diserang

```powershell
docker logs web-target --since 2m --tail 50
```

Bukti:

```text
Banyak request GET / HTTP/1.1 masuk ke Nginx.
```

### 4. Alert DDoS

```powershell
docker exec wazuhlab-wazuh.manager-1 sh -c "grep -E '100100|100103' /var/ossec/logs/alerts/alerts.json | tail -n 10"
```

Bukti:

```text
DDoS telemetry dan density/distribution alert muncul.
```

### 5. Alert Web DDoS

```powershell
docker exec wazuhlab-wazuh.manager-1 sh -c "grep -E '100301|100302' /var/ossec/logs/alerts/alerts.json | tail -n 10"
```

Bukti:

```text
Alert web DDoS muncul.
```

### 6. Alert Malware

```powershell
docker exec wazuhlab-wazuh.manager-1 sh -c "grep -E '100200|100201' /var/ossec/logs/alerts/alerts.json | tail -n 10"
```

Bukti:

```text
Malware validation alert muncul.
```

### 7. Dashboard Wazuh

```text
https://localhost
```

Bukti:

```text
Security events / Threat Hunting menampilkan alert SIEM.
```

---

## 19. Penjelasan Sederhana Cara Kerja Alert

```text
Agent = anak buah yang mengawasi server.
Manager = pusat SIEM yang menerima laporan.
Event = kejadian yang ditulis ke log.
Rule = aturan yang menentukan event mana yang bahaya.
Alert = alarm yang muncul kalau event cocok dengan rule.
```

Alur:

```text
Kejadian terjadi
↓
Agent membaca log
↓
Agent mengirim event ke Manager
↓
Manager mencocokkan event dengan rule
↓
Jika cocok, alert dibuat
↓
Alert tampil di Dashboard
```

Contoh web DDoS:

```text
Attacker mengirim banyak request ke web
↓
Web target mencatat request
↓
Event web_ddos dikirim ke agent
↓
Manager membaca "lab_type":"web_ddos"
↓
Rule 100301 match
↓
Alert muncul
```

---

## 20. Stop Lab Setelah Selesai

Jalankan:

```powershell
.\scripts\07-stop-lab.ps1
```

Fungsi:

```text
Menghentikan container lab final.
```

Jika ingin stop manual:

```powershell
docker stop attacker-simulator wazuh-agent-1 wazuh-agent-2 wazuh-agent-3 web-target wazuhlab-wazuh.dashboard-1 wazuhlab-wazuh.manager-1 wazuhlab-wazuh.indexer-1
```

Jika ingin hapus container yang sudah berhenti:

```powershell
docker container prune
```

Jika ingin bersihkan image/cache Docker setelah benar-benar selesai:

```powershell
docker system prune -a
```

Jika ingin hapus semua termasuk volume data:

```powershell
docker system prune -a --volumes
```

Catatan:

```text
Jangan gunakan --volumes jika masih butuh data alert/log untuk laporan.
```

---

## 21. Catatan Keamanan

Lab ini hanya untuk defensive security testing.

Yang aman dilakukan:

```text
Menyerang web-target lokal Docker.
Menggunakan EICAR/YARA test.
Melihat alert di Wazuh.
Mengambil screenshot untuk laporan.
```

Yang tidak boleh dilakukan:

```text
Menyerang website publik.
Menyerang IP kampus.
Menyerang IP teman tanpa izin.
Menggunakan malware asli.
Mengubah target DDoS ke domain luar.
```

---

## 22. Ringkasan Command Utama

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

.\scripts\01-setup-manager.ps1
.\scripts\02-apply-rules.ps1
.\scripts\03-start-lab.ps1

docker exec wazuhlab-wazuh.manager-1 /var/ossec/bin/agent_control -l

.\scripts\04-run-ddos.ps1 -WebRequests 1500 -SyntheticEventsPerAgent 500

$events = 1..80 | ForEach-Object {
  '{"lab_type":"web_ddos","agent":"wazuh-agent-1-web","srcip":"172.20.0.9","dstip":"web-target","method":"GET","path":"/","status":200,"user_agent":"curl","event_no":' + $_ + ',"scenario":"nginx_http_flood"}'
}

$events | docker exec -i wazuh-agent-1 sh -c "cat >> /var/log/wazuh-lab/ddos.log"

.\scripts\05-run-malware.ps1
.\scripts\06-check-alerts.ps1
```

Dashboard:

```text
https://localhost
```

Web target:

```text
http://localhost:8080
```
