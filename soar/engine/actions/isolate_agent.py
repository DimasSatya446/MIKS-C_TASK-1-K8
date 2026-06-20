def execute(alert: dict, redis_client) -> dict:
    agent = alert.get("agent", {})
    agent_name = "unknown"
    if isinstance(agent, dict):
        agent_name = agent.get("name", "unknown")
        
    if redis_client:
        redis_client.sadd("isolated_agents", agent_name)
        
    print(f"[ISOLATE] Agen {agent_name} telah diisolasi (simulasi)")
    return {"action": "isolate_agent", "target": agent_name, "status": "success"}
