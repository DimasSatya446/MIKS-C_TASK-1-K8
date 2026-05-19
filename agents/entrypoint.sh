#!/usr/bin/env bash
set -euo pipefail

: "${WAZUH_MANAGER:=wazuh.manager}"
: "${AGENT_NAME:=$(hostname)}"

mkdir -p /var/log/wazuh-lab /var/log/nginx
: > /var/log/wazuh-lab/ddos.log
: > /var/log/wazuh-lab/yara.log
touch /var/log/nginx/access.log /var/log/nginx/error.log || true

# Configure manager address.
sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" /var/ossec/etc/ossec.conf || true

# Add lab localfile monitoring once.
if ! grep -q "/var/log/wazuh-lab/ddos.log" /var/ossec/etc/ossec.conf; then
  sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/wazuh-lab/ddos.log</location>\
  </localfile>\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/wazuh-lab/yara.log</location>\
  </localfile>\
  <localfile>\
    <log_format>syslog</log_format>\
    <location>/var/log/nginx/access.log</location>\
  </localfile>\
  <localfile>\
    <log_format>syslog</log_format>\
    <location>/var/log/nginx/error.log</location>\
  </localfile>' /var/ossec/etc/ossec.conf
fi

until nc -z "${WAZUH_MANAGER}" 1515; do
  echo "Waiting for Wazuh enrollment service at ${WAZUH_MANAGER}:1515..."
  sleep 5
done

if [ ! -s /var/ossec/etc/client.keys ]; then
  /var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" -A "${AGENT_NAME}" || true
fi

/var/ossec/bin/wazuh-control start || true

echo "Agent ${AGENT_NAME} started. Monitoring /var/log/wazuh-lab/*.log and /var/log/nginx/*.log"
tail -F /var/ossec/logs/ossec.log /var/log/wazuh-lab/ddos.log /var/log/wazuh-lab/yara.log /var/log/nginx/access.log
