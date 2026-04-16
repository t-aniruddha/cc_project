#!/bin/bash
# Start Gateway + Frontend on Machine 1
# Usage: bash start-gateway.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration - Edit these values for your network
REPLICA1_HOST="replica1.local"  # or use IP: 192.168.1.101
REPLICA2_HOST="replica2.local"  # or use IP: 192.168.1.102
REPLICA3_HOST="replica3.local"  # or use IP: 192.168.1.103
GATEWAY_PORT="${PORT:-4000}"

# Build replica URLs
REPLICA_URLS="${REPLICA1_HOST}:5001,${REPLICA2_HOST}:5001,${REPLICA3_HOST}:5001"

echo "🚀 Starting MiniRaft Gateway on port $GATEWAY_PORT"
echo "📍 Replicas: $REPLICA_URLS"

# Start Gateway
export PORT=$GATEWAY_PORT
export REPLICA_URLS="http://$REPLICA_URLS"
node gateway/index.js &
GATEWAY_PID=$!

echo "✅ Gateway started (PID: $GATEWAY_PID)"
echo ""
echo "🎨 Frontend will be available at:"
echo "   http://localhost:3000?gatewayUrl=ws://localhost:4000 (from this machine)"
echo "   http://machine1.local:3000?gatewayUrl=ws://machine1.local:4000 (from other machines)"
echo ""
echo "Press Ctrl+C to stop"

wait
