# Multi-Device Deployment Guide

This guide explains how to deploy miniraft across multiple physical machines on a network instead of using Docker Compose on a single machine.

---

## Network Architecture

```
┌─────────────────────────────────────────────────┐
│  Machine 1 (Gateway Host)                       │
│  ┌──────────────────────────────────────────┐   │
│  │ Gateway (Express:4000)                   │   │
│  │ - Receives WebSocket connections         │   │
│  │ - Discovers leader via HTTP              │   │
│  │ - Forwards strokes to leader             │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │ Frontend (Nginx:3000)                    │   │
│  │ - Static HTML with dynamic gateway URL   │   │
│  │ - Query param: ?gatewayUrl=ws://M1:4000  │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         ↕ HTTP(5001)  ↕ HTTP(5001)  ↕ HTTP(5001)
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Machine 2      │  │  Machine 3      │  │  Machine 4      │
│  Replica 1      │  │  Replica 2      │  │  Replica 3      │
│  (Express:5001) │  │  (Express:5001) │  │  (Express:5001) │
│  - Raft Leader  │  │  - Raft Voter   │  │  - Raft Voter   │
│  - Stores logs  │  │  - Stores logs  │  │  - Stores logs  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## Prerequisites

- **Node.js 14+** installed on each machine
- **Network connectivity**: All machines on same LAN with known hostnames or IP addresses
- **Hostnames/DNS** (choose one):
  - Option A: Static hostnames (e.g., `machine1.local`, `machine2.local`) configured in router DNS
  - Option B: Fixed IP addresses (e.g., `192.168.1.100`, `192.168.1.101`)
  - Option C: Edit `/etc/hosts` (Linux/Mac) or `%WINDIR%\System32\drivers\etc\hosts` (Windows) on each machine

---

## Setup: Option A – Using Hostnames (Recommended)

### 1. Configure Hostnames

**On each machine**, add entries to your hosts file or configure DNS:

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):
```
192.168.1.100  machine1 gateway.local
192.168.1.101  machine2 replica1.local
192.168.1.102  machine3 replica2.local
192.168.1.103  machine4 replica3.local
```

**Linux/Mac** (`/etc/hosts`):
```
192.168.1.100  machine1 gateway.local
192.168.1.101  machine2 replica1.local
192.168.1.102  machine3 replica2.local
192.168.1.103  machine4 replica3.local
```

### 2. Machine 1: Gateway + Frontend

Clone miniraft and navigate to the miniraft directory:

```bash
git clone <repo> miniraft
cd miniraft/miniraft
```

**Install dependencies:**
```bash
npm install
```

**Start Gateway** (Terminal 1):
```bash
# No env vars needed—defaults to Docker service names fallback
# Or explicitly set for clarity:
export PORT=4000
export REPLICA_URLS="http://replica1.local:5001,http://replica2.local:5001,http://replica3.local:5001"
node gateway/index.js
```

**Start Frontend** (Terminal 2):
```bash
cd frontend
python -m http.server 3000
# Or if using a different static server:
# npm install -g http-server
# http-server -p 3000
```

Access frontend: **http://machine1:3000?gatewayUrl=ws://gateway.local:4000**

### 3. Machine 2: Replica 1

```bash
cd miniraft/miniraft
npm install

export REPLICA_ID=replica1
export PORT=5001
export GATEWAY_URL="http://gateway.local:4000"
export ALL_REPLICAS_URLS="http://replica1.local:5001,http://replica2.local:5001,http://replica3.local:5001"
node replica1/index.js
```

### 4. Machine 3: Replica 2

```bash
cd miniraft/miniraft
npm install

export REPLICA_ID=replica2
export PORT=5001
export GATEWAY_URL="http://gateway.local:4000"
export ALL_REPLICAS_URLS="http://replica1.local:5001,http://replica2.local:5001,http://replica3.local:5001"
node replica2/index.js
```

### 5. Machine 4: Replica 3

```bash
cd miniraft/miniraft
npm install

export REPLICA_ID=replica3
export PORT=5001
export GATEWAY_URL="http://gateway.local:4000"
export ALL_REPLICAS_URLS="http://replica1.local:5001,http://replica2.local:5001,http://replica3.local:5001"
node replica3/index.js
```

---

## Setup: Option B – Using IP Addresses

If you prefer static IPs instead of hostnames, use the actual IP addresses:

**Machine 1 (Gateway):**
```bash
export PORT=4000
export REPLICA_URLS="http://192.168.1.101:5001,http://192.168.1.102:5001,http://192.168.1.103:5001"
node gateway/index.js
```

**Machine 2 (Replica 1):**
```bash
export REPLICA_ID=replica1
export PORT=5001
export GATEWAY_URL="http://192.168.1.100:4000"
export ALL_REPLICAS_URLS="http://192.168.1.101:5001,http://192.168.1.102:5001,http://192.168.1.103:5001"
node replica1/index.js
```

*(Similar for Replica 2 & 3)*

Frontend URL: **http://192.168.1.100:3000?gatewayUrl=ws://192.168.1.100:4000**

---

## Setup: Option C – Multi-Host Docker Compose (Docker Swarm)

If you have Docker installed on multiple machines, use Docker Swarm for orchestration:

### Initialize Docker Swarm

**On Machine 1:**
```bash
docker swarm init --advertise-addr 192.168.1.100
# Returns a token like: SWMTKN-1-xxx
```

**On Machines 2-4:**
```bash
docker swarm join --token SWMTKN-1-xxx 192.168.1.100:2377
```

### Deploy Stack

Create `docker-compose-multihost.yml`:

```yaml
version: '3.9'

services:
  gateway:
    image: node:16-alpine
    command: sh -c "npm install && node gateway/index.js"
    working_dir: /app
    volumes:
      - ./gateway:/app/gateway
      - ./shared:/app/shared
    ports:
      - "4000:4000"
    environment:
      - PORT=4000
      - REPLICA_URLS=http://replica1:5001,http://replica2:5001,http://replica3:5001
    networks:
      - raft-net
    constraints:
      - node.hostname == machine1

  frontend:
    image: nginx:alpine
    volumes:
      - ./frontend:/usr/share/nginx/html
    ports:
      - "3000:80"
    networks:
      - raft-net
    constraints:
      - node.hostname == machine1

  replica1:
    image: node:16-alpine
    command: sh -c "npm install && node replica1/index.js"
    working_dir: /app
    volumes:
      - ./replica1:/app/replica1
      - ./shared:/app/shared
    ports:
      - "5001:5001"
    environment:
      - REPLICA_ID=replica1
      - PORT=5001
      - GATEWAY_URL=http://gateway:4000
      - ALL_REPLICAS_URLS=http://replica1:5001,http://replica2:5001,http://replica3:5001
    networks:
      - raft-net
    constraints:
      - node.hostname == machine2

  replica2:
    image: node:16-alpine
    command: sh -c "npm install && node replica2/index.js"
    working_dir: /app
    volumes:
      - ./replica2:/app/replica2
      - ./shared:/app/shared
    ports:
      - "5001:5001"
    environment:
      - REPLICA_ID=replica2
      - PORT=5001
      - GATEWAY_URL=http://gateway:4000
      - ALL_REPLICAS_URLS=http://replica1:5001,http://replica2:5001,http://replica3:5001
    networks:
      - raft-net
    constraints:
      - node.hostname == machine3

  replica3:
    image: node:16-alpine
    command: sh -c "npm install && node replica3/index.js"
    working_dir: /app
    volumes:
      - ./replica3:/app/replica3
      - ./shared:/app/shared
    ports:
      - "5001:5001"
    environment:
      - REPLICA_ID=replica3
      - PORT=5001
      - GATEWAY_URL=http://gateway:4000
      - ALL_REPLICAS_URLS=http://replica1:5001,http://replica2:5001,http://replica3:5001
    networks:
      - raft-net
    constraints:
      - node.hostname == machine4

networks:
  raft-net:
    driver: overlay
    driver_opts:
      com.docker.network.driver.overlay.vxlan_list: "4789"
```

**Deploy:**
```bash
docker stack deploy -c docker-compose-multihost.yml miniraft
```

**Monitor:**
```bash
docker stack ps miniraft
```

---

## Environment Variables Reference

### Gateway (`gateway/index.js`)

| Variable | Default | Example |
|----------|---------|---------|
| `PORT` | `4000` | `4000` |
| `REPLICA_URLS` | `http://replica1:5001,http://replica2:5002,http://replica3:5003` | `http://192.168.1.101:5001,http://192.168.1.102:5001,http://192.168.1.103:5001` |

### Replicas (`replica*/index.js`)

| Variable | Default | Example |
|----------|---------|---------|
| `REPLICA_ID` | `replica1` | `replica1`, `replica2`, or `replica3` |
| `PORT` | `5001` | `5001` |
| `GATEWAY_URL` | `http://gateway:4000` | `http://gateway.local:4000` or `http://192.168.1.100:4000` |
| `ALL_REPLICAS_URLS` | `http://replica1:5001,http://replica2:5002,http://replica3:5003` | `http://replica1.local:5001,http://replica2.local:5001,http://replica3.local:5001` |

### Frontend

Access via: `http://{GATEWAY_HOST}:3000?gatewayUrl=ws://{GATEWAY_HOST}:4000`

- **`gatewayUrl`** (query param): WebSocket + HTTP gateway address
  - Format: `ws://host:4000` (WebSocket) or just `host:4000` (auto-formatted)
  - Default: `ws://localhost:4000`
  - Example: `?gatewayUrl=ws://gateway.local:4000`

---

## Testing Multi-Device Setup

### 1. Verify Connectivity

**From Gateway machine**, test replica connectivity:
```bash
curl http://replica1.local:5001/status
curl http://replica2.local:5001/status
curl http://replica3.local:5001/status
```

Expected response:
```json
{ "state": "follower", "term": 0, "commitIndex": -1, "leader": false }
```

### 2. Verify Leader Election

Wait ~5 seconds for Raft election. Check logs on any replica:
```
[replica1][LEADER][term=1] Becoming LEADER
```

### 3. Draw on Frontend

1. Open **http://machine1:3000?gatewayUrl=ws://gateway.local:4000**
2. Draw a stroke on the canvas
3. Check Gateway logs: Should see `[Gateway] Leader discovered: replica1`
4. Check Replica logs: Should see stroke replicated across all replicas
5. Open frontend on another machine (same URL) and verify the stroke appears

### 4. Test Failover

1. Stop the leader replica (Ctrl+C on its terminal)
2. Wait ~5 seconds for new election
3. Observe new leader logs in remaining replicas
4. Draw new stroke—should still work
5. Restart failed replica—it should rejoin cluster

---

## Networking Troubleshooting

### ❌ "Cannot reach replica" / Connection Timeout

**Check:**
1. **Firewall**: Ensure ports 4000, 5001, 3000 are open on Windows Firewall or ufw
   ```bash
   # Linux: Allow traffic
   sudo ufw allow 5001
   sudo ufw allow 4000
   
   # Windows: Disable Firewall for testing (not recommended for prod)
   # Or configure Windows Firewall to allow specific ports
   ```

2. **Hostname Resolution**: Test DNS from Gateway machine
   ```bash
   ping replica1.local
   nslookup replica2.local
   ```
   If fails, update `/etc/hosts` on all machines again

3. **IP Address**: Verify you're using correct IP addresses
   ```bash
   ipconfig  # Windows
   ifconfig  # Linux/Mac
   ```

### ❌ Frontend Connects but Strokes Don't Replicate

**Causes:**
1. Replicas not connected to each other—check `ALL_REPLICAS_URLS` env var matches on all replicas
2. Replica IP/hostname misconfigured—should match what Gateway uses in `REPLICA_URLS`
3. Raft election not complete—wait 5+ seconds after startup

**Fix:**
- Check logs on each replica for errors
- Verify `ALL_REPLICAS_URLS` is identical on all three replicas
- Ensure `REPLICA_ID` is unique on each machine

### ❌ Frontend on Remote Machine Shows "Not Connected"

**Cause**: Query parameter not passed to gateway

**Fix**: Use the full URL with query param:
```
http://machine1:3000?gatewayUrl=ws://machine1:4000
```

Not:
```
http://machine1:3000
```

---

## Production Considerations

1. **Systemd Services** (Linux):
   Create `/etc/systemd/system/miniraft-replica1.service`:
   ```ini
   [Unit]
   Description=MiniRaft Replica 1
   After=network.target

   [Service]
   Type=simple
   User=miniraft
   WorkingDirectory=/opt/miniraft
   Environment="REPLICA_ID=replica1"
   Environment="PORT=5001"
   Environment="ALL_REPLICAS_URLS=http://replica1.local:5001,..."
   ExecStart=/usr/bin/node /opt/miniraft/replica1/index.js
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

2. **Reverse Proxy** (Nginx):
   For more complex setups, use Nginx as a gateway Load Balancer

3. **SSL/TLS**: Replace `http://` with `https://` and `ws://` with `wss://` in env vars

4. **Monitoring**: Add Prometheus metrics to replica state endpoints

---

## Quick Start Checklist

- [ ] Configure hostnames or IP addresses on all machines
- [ ] Clone miniraft repository on each machine
- [ ] Run `npm install` on each machine in `miniraft/` directory
- [ ] Start Gateway on Machine 1 with `REPLICA_URLS` env var
- [ ] Start Replicas 1-3 with `ALL_REPLICAS_URLS` and `GATEWAY_URL` env vars
- [ ] Access frontend at `http://machine1:3000?gatewayUrl=ws://gateway.local:4000`
- [ ] Draw stroke and verify it replicates across all machines
- [ ] Test failover by stopping a replica and drawing new strokes

---

## Support

For issues with multi-device deployment:
1. Check network connectivity with `ping` and `curl`
2. Review environment variables on each machine
3. Check logs for hostname resolution errors
4. Ensure all machines are on the same network (can ping each other)
