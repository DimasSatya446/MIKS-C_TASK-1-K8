from actions import block_ip, isolate_agent, quarantine_file

PLAYBOOK_MAP = {
    "100301": ["block_ip", "notify"],
    "100302": ["block_ip", "isolate_agent", "notify"],
    "100101": ["notify"],
    "100102": ["isolate_agent", "notify"],
    "100200": ["quarantine_file", "notify"],
    "100201": ["notify"],
}

def execute_notify(alert: dict) -> dict:
    rule_id = alert.get("rule", {}).get("id", "")
    description = alert.get("rule", {}).get("description", "")
    print(f"[NOTIFY] Notifikasi dikirimkan: Rule {rule_id} - {description}")
    return {"action": "notify", "status": "success", "target": "dashboard"}

def run_playbook(alert: dict, redis_client) -> dict:
    """
    Dispatcher aksi untuk mitigasi berdasarkan Rule ID.
    Jika salah satu mitigasi gagal, mitigasi lain tetap berlanjut.
    """
    rule = alert.get("rule", {})
    rule_id = str(rule.get("id", ""))
    
    actions_to_run = PLAYBOOK_MAP.get(rule_id, [])
    action_results = []
    
    for action_name in actions_to_run:
        try:
            if action_name == "block_ip":
                res = block_ip.execute(alert, redis_client)
            elif action_name == "isolate_agent":
                res = isolate_agent.execute(alert, redis_client)
            elif action_name == "quarantine_file":
                res = quarantine_file.execute(alert, redis_client)
            elif action_name == "notify":
                res = execute_notify(alert)
            else:
                continue
            action_results.append(res)
        except Exception as e:
            action_results.append({
                "action": action_name,
                "status": "failed",
                "error": str(e)
            })
            
    return {
        "actions_taken": action_results
    }
