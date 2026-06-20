import os
import json
import redis
from flask import Flask, render_template, jsonify, redirect, url_for, send_file, request
from datetime import datetime
import csv
from io import StringIO, BytesIO

app = Flask(__name__)

REDIS_URL = os.environ.get("REDIS_URL", "redis://soar-redis:6379")

def get_redis_client():
    return redis.from_url(REDIS_URL, decode_responses=True)

@app.route('/')
def index():
    r = get_redis_client()
    keys = r.zrevrange("incidents:index", 0, 49)
    incidents = []
    for k in keys:
        inc = r.hgetall(k)
        if inc:
            inc["uuid"] = k.split(":")[-1]
            incidents.append(inc)
            
    blocked_ips = list(r.smembers("blocked_ips"))
    isolated_agents = list(r.smembers("isolated_agents"))
    
    quarantine_raw = r.hgetall("quarantined_files")
    quarantined_files = []
    for q_key, q_val in quarantine_raw.items():
        try:
            quarantined_files.append(json.loads(q_val))
        except Exception:
            pass
            
    stats = {
        "total": len(r.zrange("incidents:index", 0, -1)),
        "responded": 0,
        "detected": 0,
        "failed": 0,
    }
    
    all_keys = r.zrange("incidents:index", 0, -1)
    for k in all_keys:
        status = r.hget(k, "status")
        if status in stats:
            stats[status] += 1
            
    return render_template(
        "index.html", 
        incidents=incidents, 
        stats=stats, 
        blocked_ips=blocked_ips, 
        isolated_agents=isolated_agents,
        quarantined_files=quarantined_files
    )

@app.route('/incident/<id>')
def incident_detail(id):
    r = get_redis_client()
    incident_key = f"incident:{id}"
    incident = r.hgetall(incident_key)
    if not incident:
        return "Incident not found", 404
        
    incident["uuid"] = id
    
    try:
        incident["actions_taken_parsed"] = json.loads(incident.get("actions_taken", "[]"))
    except Exception:
        incident["actions_taken_parsed"] = []
        
    try:
        incident["raw_alert_parsed"] = json.loads(incident.get("raw_alert", "{}"))
        incident["raw_alert_pretty"] = json.dumps(incident["raw_alert_parsed"], indent=4)
    except Exception:
        incident["raw_alert_pretty"] = incident.get("raw_alert", "")
        
    return render_template("incident_detail.html", incident=incident)

@app.route('/trigger/<id>', methods=['POST'])
def trigger_playbook(id):
    r = get_redis_client()
    incident_key = f"incident:{id}"
    if r.exists(incident_key):
        r.rpush("soar:retrigger", id)
        r.hset(incident_key, "status", "detected")
    return redirect(url_for('incident_detail', id=id))

@app.route('/api/incidents')
def api_incidents():
    r = get_redis_client()
    keys = r.zrevrange("incidents:index", 0, 49)
    incidents = []
    for k in keys:
        inc = r.hgetall(k)
        if inc:
            inc["uuid"] = k.split(":")[-1]
            try:
                inc["actions_taken_parsed"] = json.loads(inc.get("actions_taken", "[]"))
            except Exception:
                inc["actions_taken_parsed"] = []
            inc_clean = {
                "uuid": inc["uuid"],
                "timestamp": inc.get("timestamp", ""),
                "rule_id": inc.get("rule_id", ""),
                "rule_description": inc.get("rule_description", ""),
                "severity": inc.get("severity", ""),
                "srcip": inc.get("srcip", ""),
                "agent": inc.get("agent", ""),
                "status": inc.get("status", ""),
                "actions": inc["actions_taken_parsed"]
            }
            incidents.append(inc_clean)
    return jsonify(incidents)

@app.route('/api/stats')
def api_stats():
    r = get_redis_client()
    stats = {"total": 0, "responded": 0, "detected": 0, "failed": 0}
    all_keys = r.zrange("incidents:index", 0, -1)
    stats["total"] = len(all_keys)
    for k in all_keys:
        status = r.hget(k, "status")
        if status in stats:
            stats[status] += 1
    return jsonify(stats)

@app.route('/api/blocked-ips')
def api_blocked_ips():
    r = get_redis_client()
    return jsonify(list(r.smembers("blocked_ips")))

@app.route('/export/pdf')
def export_pdf():
    from reportlab.lib.pagesizes import letter
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors

    r = get_redis_client()
    keys = r.zrevrange("incidents:index", 0, -1)
    incidents = []
    for k in keys:
        inc = r.hgetall(k)
        if inc:
            incidents.append(inc)

    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=30, leftMargin=30, topMargin=30, bottomMargin=30)
    story = []
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'TitleStyle', parent=styles['Heading1'], fontSize=20, leading=24,
        textColor=colors.HexColor('#1a252f'), alignment=1, spaceAfter=15
    )
    normal_style = styles['Normal']
    
    story.append(Paragraph("MINI SOAR INCIDENT SUMMARY REPORT", title_style))
    story.append(Paragraph(f"<b>Tanggal Ekspor:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", normal_style))
    story.append(Paragraph(f"<b>Total Insiden Terdeteksi:</b> {len(incidents)}", normal_style))
    story.append(Spacer(1, 15))
    
    data = [["Timestamp", "Rule ID", "Severity", "Source IP", "Agent", "Status"]]
    for inc in incidents:
        ts = inc.get("timestamp", "").split("+")[0].split(".")[0]
        data.append([
            ts,
            inc.get("rule_id", ""),
            str(inc.get("severity", "")),
            inc.get("srcip", "N/A") or "N/A",
            inc.get("agent", "unknown"),
            inc.get("status", "").upper()
        ])
        
    t = Table(data, colWidths=[110, 50, 50, 95, 110, 85])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#2c3e50')),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('BOTTOMPADDING', (0,0), (-1,0), 6),
        ('TOPPADDING', (0,0), (-1,0), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#f8f9fa')]),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,0), 9),
        ('FONTSIZE', (0,1), (-1,-1), 8),
    ]))
    
    story.append(t)
    doc.build(story)
    buffer.seek(0)
    
    return send_file(
        buffer, mimetype='application/pdf', as_attachment=True,
        download_name=f"soar_report_{datetime.now().strftime('%Y%m%d%H%M%S')}.pdf"
    )

@app.route('/export/csv')
def export_csv():
    r = get_redis_client()
    keys = r.zrevrange("incidents:index", 0, -1)
    
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["Incident UUID", "Timestamp", "Rule ID", "Rule Description", "Severity", "Source IP", "Agent Name", "SOAR Status", "Actions Taken"])
    
    for k in keys:
        inc = r.hgetall(k)
        if inc:
            uuid_str = k.split(":")[-1]
            writer.writerow([
                uuid_str,
                inc.get("timestamp", ""),
                inc.get("rule_id", ""),
                inc.get("rule_description", ""),
                inc.get("severity", ""),
                inc.get("srcip", ""),
                inc.get("agent", ""),
                inc.get("status", ""),
                inc.get("actions_taken", "")
            ])
            
    response = app.make_response(output.getvalue())
    response.headers["Content-Disposition"] = f"attachment; filename=soar_report_{datetime.now().strftime('%Y%m%d%H%M%S')}.csv"
    response.headers["Content-type"] = "text/csv"
    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050, debug=True)
