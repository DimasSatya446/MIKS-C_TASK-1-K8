## 🚀 Panduan Memulai Cepat (Quick Start untuk Anggota Kelompok)

Sistem Simulasi Mini SOAR ini dapat dijalankan pada laptop berspesifikasi minimal RAM 8 GB (mode SOAR minimal) atau RAM 16 GB (mode penuh dengan Wazuh Dashboards).

### Langkah-Langkah Menjalankan Simulasi

1. **Clone Repositori & Masuk Direktori**
   ```powershell
   git clone <URL_REPO_ANDA>
   cd MIKS-C_TASK-1-K8
   ```

2. **Bypass Kebijakan Eksekusi PowerShell (Jika Diperlukan)**
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   ```

3. **Inisialisasi Environment & Sertifikat**
   Langkah ini akan men-generate file `.env` dan sertifikat SSL yang unik untuk host Anda.
   ```powershell
   .\scripts\00-setup-env.ps1
   ```

4. **Inisialisasi Wazuh Manager & Aturan Deteksi**
   ```powershell
   .\scripts\01-setup-manager.ps1
   .\scripts\02-apply-rules.ps1
   ```

5. **Nyalakan Layanan Wazuh Lab**
   ```powershell
   .\scripts\03-start-lab.ps1
   ```

6. **Nyalakan Layanan SOAR**
   ```powershell
   .\scripts\08-start-soar.ps1
   ```

7. **Akses Dashboard**
   * **SOAR Dashboard:** [http://localhost:5050](http://localhost:5050)
   * **Wazuh Dashboard:** [https://localhost](https://localhost) (User: `admin` | Pass: `SecretPassword`)

---

## 🧪 Skenario Simulasi Pengujian

### Skenario A: Mitigasi Serangan Web DDoS (Pemberhentian IP Otomatis)
Eksekusi simulasi DDoS melalui log agen:
```powershell
.\scripts\04-run-ddos.ps1 -WebRequests 1500 -SyntheticEventsPerAgent 500
```
* **Hasil:** Insiden dengan rule `100301`/`100302` akan tercatat di Dasbor SOAR. Status insiden berubah menjadi `Responded` dan alamat IP penyerang otomatis diblokir di biner `iptables` kontainer `web-target`.
* **Verifikasi:** Jalankan `docker exec web-target iptables -L INPUT` untuk mematikan aturan pemblokiran aktif di sisi web target.

### Skenario B: Deteksi Malware (Karantina File)
Jalankan simulator pengujian deteksi malware:
```powershell
.\scripts\05-run-malware.ps1
```
* **Hasil:** Aturan penanganan malware `100200` terpicu. SOAR Engine langsung melakukan simulasi karantina file dan mengisolasi agen yang bersangkutan. Status isolasi dan file karantina dapat langsung dimonitor melalui Dasbor SOAR.
