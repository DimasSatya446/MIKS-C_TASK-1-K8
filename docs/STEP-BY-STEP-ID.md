# Panduan Step-by-Step Wazuh Docker Final Lab

## Tujuan

Deploy arsitektur lengkap:

- Wazuh Manager + Indexer + Dashboard.
- 3 Wazuh Agent.
- Web target sederhana berbasis Nginx.
- Attacker simulator lokal.
- Simulasi DDoS aman.
- Simulasi malware aman EICAR/YARA.
- Validasi alert SIEM di Wazuh Dashboard.

Semua berjalan lokal di Docker Desktop Windows. Tidak memakai Azure, tidak menyerang website publik.

## Prasyarat

- Windows 10/11.
- Docker Desktop dengan Linux containers.
- WSL2 backend aktif.
- PowerShell.
- Storage kosong disarankan minimal 30 GB.
- RAM disarankan 16 GB.

## Alur Run

Buka PowerShell sebagai Administrator, masuk ke folder lab:

```powershell
cd "C:\path\ke\wazuh-docker-final-lab"
Set-ExecutionPolicy -Scope Process Bypass -Force
```

### 1. Setup Wazuh Manager

```powershell
.\scripts\01-setup-manager.ps1
```

Fungsi: download official Wazuh Docker deployment, generate certificate, lalu start Wazuh Manager/Indexer/Dashboard.

### 2. Apply rule dan decoder

```powershell
.\scripts\02-apply-rules.ps1
```

Fungsi: memasang `manager/local_rules.xml` dan `manager/local_decoder.xml` ke manager.

### 3. Start 3 agent + web target + attacker

```powershell
.\scripts\03-start-lab.ps1
```

Fungsi: menjalankan 3 Wazuh agent, Nginx web target, dan attacker simulator.

Tunggu 1-2 menit, lalu cek:

```powershell
docker ps
```

Harus ada:

- `wazuh-agent-1`
- `wazuh-agent-2`
- `wazuh-agent-3`
- `web-target`
- `attacker-simulator`
- `wazuhlab-wazuh.manager-1`
- `wazuhlab-wazuh.dashboard-1`
- `wazuhlab-wazuh.indexer-1`

### 4. Jalankan DDoS scenario

```powershell
.\scripts\04-run-ddos.ps1 -WebRequests 1000 -SyntheticEventsPerAgent 350
```

Fungsi:

- Attacker simulator mengirim HTTP request ke `web-target` lokal.
- Semua agent membuat telemetry DDoS JSON.
- Agent 1 juga membaca Nginx access log dari web target.

### 5. Jalankan malware scenario

```powershell
.\scripts\05-run-malware.ps1
```

Fungsi: membuat file EICAR test string dan menjalankan YARA. Ini bukan malware asli.

### 6. Cek alert

```powershell
.\scripts\06-check-alerts.ps1
```

Rule ID penting:

- `100100`: telemetry DDoS diterima.
- `100101`: burst dari source IP sama.
- `100102`: distributed high-volume traffic.
- `100103`: logging density report.
- `100301`: HTTP request ke web target terdeteksi.
- `100302`: critical web DDoS burst.
- `100200`: YARA mendeteksi EICAR.
- `100201`: artifact malware test dibuat.

### 7. Buka Dashboard

Buka browser:

```text
https://localhost
```

Cari di Wazuh Security Events:

```text
rule.id:(100100 or 100101 or 100102 or 100103 or 100301 or 100302 or 100200 or 100201)
```

Set time range ke `Last 1 hour`.

## Validasi untuk laporan

Screenshot yang disarankan:

1. `docker ps` menampilkan manager, dashboard, indexer, 3 agent, web target, attacker.
2. `docker logs web-target --tail 50` menampilkan banyak `GET / HTTP/1.1`.
3. Output `agent_control -l` menampilkan agent Active.
4. Wazuh Dashboard menampilkan alert rule ID di atas.
5. Output `06-check-alerts.ps1`.

## Stop Lab

```powershell
.\scripts\07-stop-lab.ps1
```

Jika ingin membersihkan storage Docker setelah tugas selesai:

```powershell
docker system prune -a
```

Jika ingin hapus volume data juga:

```powershell
docker system prune -a --volumes
```

Jangan hapus volume kalau masih butuh screenshot/data alert.
