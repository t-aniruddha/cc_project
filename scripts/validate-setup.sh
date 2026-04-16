#!/bin/bash
# Validation Script for Multi-Device MiniRaft Deployment
# Tests connectivity between gateway and replicas
# Usage: bash validate-setup.sh [gateway_host] [replica1_host] [replica2_host] [replica3_host]

set -e

# Configuration
GATEWAY_HOST="${1:-gateway.local}"
REPLICA1_HOST="${2:-replica1.local}"
REPLICA2_HOST="${3:-replica2.local}"
REPLICA3_HOST="${4:-replica3.local}"

GATEWAY_PORT=4000
REPLICA_PORT=5001

echo "==================================="
echo "MiniRaft Multi-Device Validation"
echo "==================================="
echo ""

# Helper function to test connectivity
test_host() {
  local host=$1
  local port=$2
  local service=$3
  
  echo -n "Testing $service ($host:$port)... "
  
  if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo "✅ Reachable"
    return 0
  else
    echo "❌ NOT reachable"
    return 1
  fi
}

# Helper function to check replica status
check_replica_status() {
  local host=$1
  local replica_id=$2
  
  echo -n "Checking $replica_id status... "
  
  response=$(curl -s -m 2 "http://$host:$REPLICA_PORT/status" 2>/dev/null || echo "")
  
  if [ -z "$response" ]; then
    echo "❌ No response"
    return 1
  fi
  
  state=$(echo "$response" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  term=$(echo "$response" | grep -o '"term":[0-9]*' | cut -d':' -f2 || echo "?")
  
  echo "✅ State: $state, Term: $term"
  return 0
}

# Test 1: Hostname Resolution
echo "1️⃣  Testing Hostname Resolution"
echo "───────────────────────────────"

for host in $GATEWAY_HOST $REPLICA1_HOST $REPLICA2_HOST $REPLICA3_HOST; do
  echo -n "Resolving $host... "
  if ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}'); then
    echo "✅ $ip"
  else
    echo "❌ Failed (check /etc/hosts or DNS)"
  fi
done
echo ""

# Test 2: Network Connectivity
echo "2️⃣  Testing Network Connectivity"
echo "────────────────────────────────"

test_host "$GATEWAY_HOST" "$GATEWAY_PORT" "Gateway"
test_replica1=$(test_host "$REPLICA1_HOST" "$REPLICA_PORT" "Replica 1"; echo $?)
test_replica2=$(test_host "$REPLICA2_HOST" "$REPLICA_PORT" "Replica 2"; echo $?)
test_replica3=$(test_host "$REPLICA3_HOST" "$REPLICA_PORT" "Replica 3"; echo $?)

echo ""

# Test 3: Service Status (if running)
if [ $test_replica1 -eq 0 ]; then
  echo "3️⃣  Checking Replica Status"
  echo "───────────────────────────"
  check_replica_status "$REPLICA1_HOST" "Replica 1"
  check_replica_status "$REPLICA2_HOST" "Replica 2"
  check_replica_status "$REPLICA3_HOST" "Replica 3"
  echo ""
else
  echo "⚠️  Skipping service status check (replicas not reachable)"
  echo ""
fi

# Test 4: Gateway Health
echo "4️⃣  Testing Gateway Health"
echo "──────────────────────────"
echo -n "Gateway health check... "
response=$(curl -s -m 2 "http://$GATEWAY_HOST:$GATEWAY_PORT/health" 2>/dev/null || echo "")

if [ -z "$response" ]; then
  echo "❌ No response"
else
  leader=$(echo "$response" | grep -o '"leader":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  echo "✅ Leader: $leader"
fi
echo ""

# Summary
echo "==================================="
echo "✅ Validation Complete"
echo "==================================="
echo ""
echo "To start services:"
echo "  Machine 1: bash start-gateway.sh"
echo "  Machine 2: bash start-replica.sh replica1 $GATEWAY_HOST $REPLICA1_HOST $REPLICA2_HOST $REPLICA3_HOST"
echo "  Machine 3: bash start-replica.sh replica2 $GATEWAY_HOST $REPLICA1_HOST $REPLICA2_HOST $REPLICA3_HOST"
echo "  Machine 4: bash start-replica.sh replica3 $GATEWAY_HOST $REPLICA1_HOST $REPLICA2_HOST $REPLICA3_HOST"
echo ""
echo "Access frontend at: http://$GATEWAY_HOST:3000?gatewayUrl=ws://$GATEWAY_HOST:4000"
