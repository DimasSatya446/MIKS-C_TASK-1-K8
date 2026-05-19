FROM ubuntu:22.04

ARG WAZUH_VERSION=4.14.5-1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y curl gnupg lsb-release procps netcat-openbsd yara ca-certificates \
    && curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list \
    && apt-get update \
    && apt-get install -y wazuh-agent=${WAZUH_VERSION} \
    && apt-mark hold wazuh-agent \
    && mkdir -p /var/log/wazuh-lab /var/log/nginx /opt/wazuh-lab /opt/wazuh-lab/yara-rules /opt/wazuh-lab/malware-samples \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY simulate-ddos.sh /opt/wazuh-lab/simulate-ddos.sh
COPY simulate-malware-yara.sh /opt/wazuh-lab/simulate-malware-yara.sh
COPY eicar.yar /opt/wazuh-lab/yara-rules/eicar.yar

RUN chmod +x /entrypoint.sh /opt/wazuh-lab/*.sh

ENTRYPOINT ["/entrypoint.sh"]
