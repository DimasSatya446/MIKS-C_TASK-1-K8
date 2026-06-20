import subprocess
import os

WEB_TARGET = os.environ.get("WEB_TARGET_CONTAINER", "web-target")

def execute(alert: dict, redis_client=None) -> dict:
    srcip = None
    data = alert.get("data", {})
    if isinstance(data, dict):
        srcip = data.get("srcip") or data.get("src_ip")
        
    if not srcip:
        agent = alert.get("agent", {})
        if isinstance(agent, dict):
            srcip = agent.get("ip")
            
    if not srcip or srcip == "127.0.0.1" or srcip == "any":
        return {"action": "block_ip", "status": "skipped", "reason": "IP penyerang tidak valid"}
    
    if redis_client:
        redis_client.sadd("blocked_ips", srcip)
        
    try:
        # Periksa apakah iptables tersedia di dalam web-target
        check_bin = ["docker", "exec", WEB_TARGET, "which", "iptables"]
        res_bin = subprocess.run(check_bin, capture_output=True, text=True, timeout=5)
        
        if res_bin.returncode != 0:
            print(f"[BLOCK_IP] iptables tidak terpasang di {WEB_TARGET}. Menjalankan mode simulasi.")
            return {"action": "block_ip", "target": srcip, "status": "success", "simulated": True, "warning": "iptables tidak terdeteksi"}
            
        # Eksekusi blokir IP di kontainer target
        cmd = ["docker", "exec", WEB_TARGET, "iptables", "-A", "INPUT", "-s", srcip, "-j", "DROP"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            print(f"[BLOCK_IP] IP {srcip} berhasil diblokir via iptables di {WEB_TARGET}.")
            return {"action": "block_ip", "target": srcip, "status": "success", "simulated": False}
        else:
            return {"action": "block_ip", "target": srcip, "status": "failed", "error": result.stderr.strip()}
    except Exception as e:
        print(f"[BLOCK_IP] Error mitigasi: {e}")
        return {"action": "block_ip", "target": srcip, "status": "failed", "error": str(e)}
