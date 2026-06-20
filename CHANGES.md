# Project Changes Documentation

**Date:** June 4, 2026  
**Objective:** Fix critical setup and deployment issues in Wazuh Lab + SOAR Mini Simulation system

---

## Summary of Issues Fixed

This document outlines all bug fixes applied to the MIKS-C_TASK-1-K8 project. The issues prevented scripts from executing successfully and blocked the deployment pipeline at steps 00, 01, 02, and 03.

---

## 1. Certificate Generation Failure (scripts/00-setup-env.ps1)

### Problem
Script execution failed with errors:
```
/work/temp_cert.sh: line 1: #!/bin/sh: not found
/work/temp_cert.sh: line 4: openssl: not found
```

### Root Causes
1. **Alpine 3.19 minimal image does not include OpenSSL by default** - Alpine includes only basic utilities
2. **PowerShell line ending mismatch** - PowerShell writes files with CRLF (`\r\n`) line endings, but Alpine/Linux expects LF (`\n`). The carriage returns prevented the shebang and commands from being parsed correctly

### Solution Applied
Modified the Docker execution command to:
1. Install OpenSSL package via Alpine Package Kit (apk)
2. Strip carriage returns using `tr -d '\r'` before execution
3. Pipe cleaned script directly to shell

**Changed line:**
```powershell
# Before:
docker run --rm ... alpine:3.19 sh /work/temp_cert.sh

# After:
docker run --rm ... alpine:3.19 sh -c "apk add --no-cache openssl && tr -d '\r' < /work/temp_cert.sh | sh"
```

### Files Modified
- `scripts/00-setup-env.ps1` (lines ~60-65)

### Impact
- ✅ Certificates now generate successfully in `certs/` subdirectories
- ✅ All required PEM files created for indexer, manager, dashboard, and agents

---

## 2. Docker Compose Agent Image Does Not Exist (docker-compose.lab.yml)

### Problem
Script 03 execution failed with:
```
Error response from daemon: failed to resolve reference "docker.io/wazuh/wazuh-agent:4.7.2": 
docker.io/wazuh/wazuh-agent:4.7.2: not found
```

### Root Cause
**No official Wazuh agent Docker image exists** in the Docker registry. Wazuh agents are designed to be installed on systems, not pulled as pre-built container images. The original compose file attempted to use a non-existent image.

### Solution Applied
Replaced agent service definitions to use Ubuntu 22.04 base images with dynamic Wazuh agent installation:

**Changed from:**
```yaml
wazuh-agent-1:
  image: wazuh/wazuh-agent:4.7.2  # Does not exist
  environment:
    - WAZUH_MANAGER=wazuh.manager
```

**Changed to:**
```yaml
wazuh-agent-1:
  image: ubuntu:22.04
  command: |
    bash -c "
      apt-get update && apt-get install -y curl gnupg lsb-release netcat
      curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
      echo 'deb https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list
      apt-get update && apt-get install -y wazuh-agent
      sed -i 's/<hostname>PLACEHOLDER<\/hostname>/<hostname>wazuh-agent-1-web<\/hostname>/g' /var/ossec/etc/ossec.conf
      sed -i 's/<manager_ip>PLACEHOLDER<\/manager_ip>/<manager_ip>wazuh.manager<\/manager_ip>/g' /var/ossec/etc/ossec.conf
      /var/ossec/bin/wazuh-control start
      tail -f /var/ossec/logs/ossec.log
    "
```

### Files Modified
- `docker-compose.lab.yml` (wazuh-agent-1, wazuh-agent-2, wazuh-agent-3 services)

### Impact
- ✅ Agents now build from standard Ubuntu image with Wazuh installation at runtime
- ✅ Agents properly configure hostname and manager connection details
- ✅ All three agent containers start successfully

---

## 3. Service Duplication and Version Mismatch (docker-compose.lab.yml)

### Problem
docker-compose.lab.yml attempted to deploy separate instances of Wazuh manager, indexer, and dashboard—but these were already deployed by script 01 with different versions:
- Script 01 deployed: Wazuh v4.14.5
- Lab compose specified: v4.7.2

This created architectural confusion and resource conflicts.

### Solution Applied
**Removed duplicate services** from docker-compose.lab.yml:
- `wazuh.indexer:4.7.2`
- `wazuh.manager:4.7.2`
- `wazuh.dashboard:4.7.2`
- Removed associated volumes: `indexer_data`, `manager_data`

**Rationale:** docker-compose.lab.yml now serves as a **standalone agent/lab environment composition** that connects to the centrally managed Wazuh stack (already running from script 01) via the shared network `wazuhlab_default`.

### Files Modified
- `docker-compose.lab.yml` (removed ~60 lines of duplicate service definitions)

### Impact
- ✅ No duplicate deployments
- ✅ Single source of truth for Wazuh infrastructure (from script 01)
- ✅ Lab agents connect to existing manager

---

## 4. Undefined Service Reference Error (docker-compose.lab.yml)

### Problem
Script 03 execution failed with:
```
service "wazuh-agent-1" depends on undefined service "wazuh.manager": invalid compose project
```

### Root Cause
Each agent had `depends_on: - wazuh.manager`, but since `wazuh.manager` was removed from the lab compose file (fix #3), Docker Compose could not resolve the dependency. Additionally, docker-compose.lab.yml is a **separate project** from the manager (deployed by script 01) and cannot directly reference services from another project.

### Solution Applied
1. **Removed all `depends_on` clauses** from agent services
2. **Added built-in readiness check** using netcat to verify manager availability before agent startup

**Implementation:**
```bash
for i in {1..60}; do
  nc -z -w 5 wazuh.manager 1514 && break
  echo "Attempt $$i/60: Manager not ready, retrying..."
  sleep 2
done
```

This approach:
- Respects architectural separation (standalone lab composition)
- Allows agents to wait for manager readiness (up to 2 minutes)
- Uses network-level connectivity checking, not Docker compose dependencies
- Provides retry logic and status messages

### Files Modified
- `docker-compose.lab.yml` (wazuh-agent-1, wazuh-agent-2, wazuh-agent-3 services)

### Impact
- ✅ No Docker Compose dependency errors
- ✅ Agents gracefully handle manager startup delays
- ✅ Agents automatically connect once manager port 1514 becomes available

---

## 5. Bash Variable Escaping in Docker Compose (docker-compose.lab.yml)

### Problem
Docker Compose warnings during execution:
```
The "i" variable is not set. Defaulting to a blank string.
```

### Root Cause
In the agent command blocks, the bash loop variable `$i` was being interpreted as a Docker Compose template variable instead of a bash variable. Docker Compose processes variables before passing to the shell.

### Solution Applied
Changed all bash variable references from `$i` to `$$i` to escape them for Docker Compose:

**Before:**
```bash
for i in {1..60}; do
  echo "Attempt $i/60: Manager not ready, retrying..."
done
```

**After:**
```bash
for i in {1..60}; do
  echo "Attempt $$i/60: Manager not ready, retrying..."
done
```

### Files Modified
- `docker-compose.lab.yml` (all three agent command blocks)

### Impact
- ✅ No Docker Compose variable substitution warnings
- ✅ Bash variables work correctly inside containers
- ✅ Loop counter displays properly in retry messages

---

## 6. Network Configuration Errors (docker-compose.lab.yml)

### Problem
Docker Compose warnings and errors:
```
The "wazuhlab_default" network exists but was not created for project "wazuhfinallab"
Set `external: true` to use an existing network
network wazuhlab_default was found but has incorrect label com.docker.compose.network set to "default"
```

### Root Cause
docker-compose.lab.yml declared network `wazuhlab_net` with `driver: bridge`, but the network already existed (created by script 01). Docker Compose expected either:
1. The network to be created by this project, OR
2. The network to be marked as `external: true` to use an existing one

### Solution Applied
Changed network configuration to reference the existing external network:

**Before:**
```yaml
networks:
  wazuhlab_net:
    name: wazuhlab_default
    driver: bridge
```

**After:**
```yaml
networks:
  wazuhlab_net:
    name: wazuhlab_default
    external: true
```

### Files Modified
- `docker-compose.lab.yml` (networks section, line ~115)

### Impact
- ✅ No network creation conflicts
- ✅ Lab agents connect to the same network as the Wazuh manager
- ✅ Clean Docker Compose execution

---

## 7. YAML Syntax Error (docker-compose.lab.yml)

### Problem
Script 03 execution failed with:
```
yaml: line 28: did not find expected key
```

### Root Cause
During previous edits, the line `services:` and the first service `wazuh-agent-1:` were merged on the same line without proper formatting:
```yaml
services:wazuh-agent-1:
```

This is invalid YAML syntax.

### Solution Applied
Separated them on different lines with proper indentation:
```yaml
services:

  wazuh-agent-1:
```

### Files Modified
- `docker-compose.lab.yml` (line 3-4)

### Impact
- ✅ YAML parses correctly
- ✅ Docker Compose processes file without syntax errors

---

## Affected Scripts and Files

| File | Type | Changes |
|------|------|---------|
| `scripts/00-setup-env.ps1` | PowerShell | Added OpenSSL installation + line ending conversion |
| `docker-compose.lab.yml` | Docker Compose | Major refactoring: removed duplicates, fixed agents, added readiness checks, network fixes |

---

## Testing Recommendations

1. **Verify certificate generation:**
   ```powershell
   .\scripts\00-setup-env.ps1
   dir certs/ -Recurse  # Should show all .pem files
   ```

2. **Verify manager deployment:**
   ```powershell
   .\scripts\01-setup-manager.ps1
   docker ps | grep wazuh  # Should show manager, indexer, dashboard
   ```

3. **Verify agent deployment and enrollment:**
   ```powershell
   .\scripts\03-start-lab.ps1
   docker logs -f wazuh-agent-1  # Should show successful enrollment
   ```

4. **Verify network connectivity:**
   ```bash
   docker exec wazuh-agent-1 nc -z -w 5 wazuh.manager 1514 && echo "Connected"
   ```

---

## Notes for Future Development

- **Architecture:** Lab composition is now explicitly standalone. Manager/indexer/dashboard are in a separate Docker Compose project created by script 01.
- **Network Design:** Both projects share the `wazuhlab_default` network (external reference). This allows clean separation of concerns.
- **Agent Installation:** Agents now use standard package installation, not pre-built images. This makes them more maintainable and upgradeable.
- **Readiness Checks:** Built-in netcat-based checks replace Docker Compose `depends_on`, making the architecture more flexible.
- **Line Endings:** All scripts that interact with Linux containers should ensure LF line endings when generated from Windows-based tools.

---

## Version Information

- **Project:** MIKS-C_TASK-1-K8 (Wazuh Lab + Mini SOAR)
- **Wazuh Version:** 4.14.5 (from script 01)
- **Docker Compose Version:** 3.8
- **Base Images:** Ubuntu 22.04 (agents), Alpine 3.19 (cert generation), nginx:alpine (web-target)
- **Last Modified:** June 4, 2026
