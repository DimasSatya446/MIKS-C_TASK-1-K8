import json
from datetime import datetime

def execute(alert: dict, redis_client) -> dict:
    syscheck = alert.get("syscheck", {})
    data = alert.get("data", {})
    
    file_path = "unknown_file"
    if isinstance(syscheck, dict):
        file_path = syscheck.get("path") or file_path
    if file_path == "unknown_file" and isinstance(data, dict):
        file_path = data.get("file") or data.get("path") or file_path
        
    agent = alert.get("agent", {})
    agent_name = "unknown"
    if isinstance(agent, dict):
        agent_name = agent.get("name", "unknown")
        
    timestamp = datetime.utcnow().isoformat()
    q_info = {
        "file": file_path,
        "agent": agent_name,
        "timestamp": timestamp
    }
    
    if redis_client:
        redis_client.hset("quarantined_files", f"{agent_name}:{file_path}", json.dumps(q_info))
        
    print(f"[QUARANTINE] File {file_path} pada agen {agent_name} dikarantina (simulasi)")
    return {"action": "quarantine_file", "target": file_path, "status": "success"}
