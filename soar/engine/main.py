import os
import time
import uuid
import json
import redis
from datetime import datetime
import wazuh_client
import playbook_runner

REDIS_URL = os.environ.get("REDIS_URL", "redis://soar-redis:6379")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "5"))

def get_redis_client():
    retries = 10
    while retries > 0:
        try:
            r = redis.from_url(REDIS_URL, decode_responses=True)
            r.ping()
            return r
        except Exception as e:
            print(f"[ENGINE] Menghubungi Redis... ({retries} percobaan tersisa). Error: {e}")
            time.sleep(3)
            retries -= 1
    raise Exception("Koneksi Redis gagal!")

def process_incident(alert: dict, r, incident_uuid=None):
    alert_id = alert.get("id")
    if not alert_id:
        alert_id = f"{alert.get('timestamp')}_{alert.get('rule', {}).get('id', 'unknown')}"
        
    if not incident_uuid:
        incident_uuid = str(uuid.uuid4())
        
    incident_key = f"incident:{incident_uuid}"
    rule = alert.get("rule", {})
    rule_id = str(rule.get("id", ""))
    rule_desc = rule.get("description", "")
    severity = int(rule.get("level", 0))
    
    srcip = alert.get("data", {}).get("srcip") or alert.get("data", {}).get("src_ip") or ""
    if not srcip:
        srcip = alert.get("agent", {}).get("ip", "")
    if srcip == "127.0.0.1" or srcip == "any" or not srcip:
        srcip = "N/A"
        
    agent_name = alert.get("agent", {}).get("name", "unknown")
    timestamp = alert.get("timestamp", datetime.utcnow().isoformat())
    
    incident_data = {
        "alert_id": alert_id,
        "rule_id": rule_id,
        "rule_description": rule_desc,
        "severity": severity,
        "srcip": srcip,
        "agent": agent_name,
        "timestamp": timestamp,
        "raw_alert": json.dumps(alert),
        "status": "detected",
        "actions_taken": json.dumps([])
    }
    
    r.hset(incident_key, mapping=incident_data)
    r.set(f"alert_to_incident:{alert_id}", incident_uuid)
    
    try:
        clean_ts = timestamp.split("+")[0].split(".")[0]
        dt = datetime.strptime(clean_ts, "%Y-%m-%dT%H:%M:%S")
        score = int(dt.timestamp())
    except Exception:
        score = int(time.time())
        
    r.zadd("incidents:index", {incident_key: score})
    
    # Eksekusi playbook mitigasi
    playbook_res = playbook_runner.run_playbook(alert, r)
    
    actions = playbook_res.get("actions_taken", [])
    failed_actions = [a for a in actions if a.get("status") == "failed"]
    
    if not actions:
        final_status = "responded"
    elif len(failed_actions) == len(actions):
        final_status = "failed"
    else:
        final_status = "responded"
        
    r.hset(incident_key, "status", final_status)
    r.hset(incident_key, "actions_taken", json.dumps(actions))
    print(f"[ENGINE] Insiden {incident_uuid} diproses. Status: {final_status}")

def main():
    print("=== SOAR Engine Mulai Berjalan ===")
    r = get_redis_client()
    
    last_timestamp = r.get("soar_last_seen_timestamp") or ""
    if not last_timestamp:
        last_timestamp = datetime.utcnow().isoformat()
        r.set("soar_last_seen_timestamp", last_timestamp)
        print(f"[ENGINE] Set threshold waktu awal: {last_timestamp}")
    else:
        print(f"[ENGINE] Melanjutkan monitoring dari waktu: {last_timestamp}")

    while True:
        try:
            # 1. Cek manual trigger dari Dashboard
            while r.llen("soar:retrigger") > 0:
                incident_id = r.lpop("soar:retrigger")
                if not incident_id:
                    break
                incident_key = f"incident:{incident_id}"
                if r.exists(incident_key):
                    print(f"[ENGINE] Retrigger playbook secara manual untuk insiden: {incident_id}")
                    inc_data = r.hgetall(incident_key)
                    raw_alert = json.loads(inc_data.get("raw_alert", "{}"))
                    process_incident(raw_alert, r, incident_uuid=incident_id)

            # 2. Ambil alert baru dari Wazuh Manager
            alerts = wazuh_client.get_new_alerts(last_timestamp)
            for alert in alerts:
                alert_id = alert.get("id") or f"{alert.get('timestamp')}_{alert.get('rule', {}).get('id', 'unknown')}"
                if r.get(f"alert_to_incident:{alert_id}"):
                    continue  # Lewati jika sudah diproses sebelumnya
                    
                process_incident(alert, r)
                
                timestamp = alert.get("timestamp", "")
                if timestamp > last_timestamp:
                    last_timestamp = timestamp
                    r.set("soar_last_seen_timestamp", last_timestamp)
                    
        except Exception as e:
            print(f"[ENGINE] Error pada loop utama: {e}")
            time.sleep(3)
            
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
