import subprocess
import json
import os

MANAGER_CONTAINER = os.environ.get("WAZUH_MANAGER_CONTAINER", "wazuhlab-wazuh.manager-1")
ALERTS_FILE = "/var/ossec/logs/alerts/alerts.json"

def get_new_alerts(last_seen_timestamp: str) -> list[dict]:
    """
    Eksekusi tail log alert di wazuh manager melalui docker exec.
    Menyaring dan mengembalikan alert yang memiliki timestamp lebih baru.
    """
    try:
        result = subprocess.run(
            ["docker", "exec", MANAGER_CONTAINER, "tail", "-n", "200", ALERTS_FILE],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return []
            
        alerts = []
        for line in result.stdout.strip().splitlines():
            if not line.strip():
                continue
            try:
                alert = json.loads(line)
                timestamp = alert.get("timestamp", "")
                if last_seen_timestamp and timestamp <= last_seen_timestamp:
                    continue
                alerts.append(alert)
            except json.JSONDecodeError:
                continue
        return alerts
    except Exception as e:
        print(f"[WAZUH_CLIENT] Gagal membaca alert: {e}")
        return []
