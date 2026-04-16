#!/bin/bash
# Start Replica on separate machine
# Usage: bash start-replica.sh <replica_id> [gateway_host] [replica1_host] [replica2_host] [replica3_host]
# Example: bash start-replica.sh replica1 gateway.local replica1.local replica2.local replica3.local

set -e

# Parse arguments
REPLICA_ID="${1:-replica1}"
GATEWAY_HOST="${2:-gateway.local}"
REPLICA1_HOST="${3:-replica1.local}"
REPLICA2_HOST="${4:-replica2.local}"
REPLICA3_HOST="${5:-replica3.local}"

# Validate REPLICA_ID
if [[ ! "$REPLICA_ID" =~ ^replica[1-3]$ ]]; then
  echo "❌ Error: REPLICA_ID must be replica1, replica2, or replica3"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🚀 Starting MiniRaft $REPLICA_ID"
echo "🔗 Gateway: http://$GATEWAY_HOST:4000"
echo "🤝 Peers: $REPLICA1_HOST:5001, $REPLICA2_HOST:5001, $REPLICA3_HOST:5001"
echo ""

# Start Replica
export REPLICA_ID="$REPLICA_ID"
export PORT=5001
export GATEWAY_URL="http://$GATEWAY_HOST:4000"
export ALL_REPLICAS_URLS="http://$REPLICA1_HOST:5001,http://$REPLICA2_HOST:5001,http://$REPLICA3_HOST:5001"

node "$REPLICA_ID/index.js"
