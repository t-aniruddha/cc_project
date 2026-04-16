# PowerShell: Start Replica on separate machine
# Usage: .\start-replica.ps1 -replicaId replica1 -gatewayHost gateway.local -replica1Host replica1.local -replica2Host replica2.local -replica3Host replica3.local

param(
    [string]$replicaId = "replica1",
    [string]$gatewayHost = "gateway.local",
    [string]$replica1Host = "replica1.local",
    [string]$replica2Host = "replica2.local",
    [string]$replica3Host = "replica3.local"
)

# Validate replicaId
if ($replicaId -notmatch '^replica[1-3]$') {
    Write-Host "❌ Error: replicaId must be replica1, replica2, or replica3" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Starting MiniRaft $replicaId" -ForegroundColor Green
Write-Host "🔗 Gateway: http://$gatewayHost`:4000"
Write-Host "🤝 Peers: $replica1Host`:5001, $replica2Host`:5001, $replica3Host`:5001"
Write-Host ""

# Set environment variables
$env:REPLICA_ID = $replicaId
$env:PORT = 5001
$env:GATEWAY_URL = "http://$gatewayHost`:4000"
$env:ALL_REPLICAS_URLS = "http://$replica1Host`:5001,http://$replica2Host`:5001,http://$replica3Host`:5001"

# Start Replica
Set-Location (Split-Path $PSCommandPath)
Set-Location ..
& node "$replicaId\index.js"
