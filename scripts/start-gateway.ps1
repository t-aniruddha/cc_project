# PowerShell: Start Gateway + Frontend on Machine 1
# Usage: .\start-gateway.ps1

$REPLICA1_HOST = "replica1.local"  # or use IP: 192.168.1.101
$REPLICA2_HOST = "replica2.local"  # or use IP: 192.168.1.102
$REPLICA3_HOST = "replica3.local"  # or use IP: 192.168.1.103
$GATEWAY_PORT = 4000

$REPLICA_URLS = "http://${REPLICA1_HOST}:5001,http://${REPLICA2_HOST}:5001,http://${REPLICA3_HOST}:5001"

Write-Host "🚀 Starting MiniRaft Gateway on port $GATEWAY_PORT" -ForegroundColor Green
Write-Host "📍 Replicas: $REPLICA_URLS"
Write-Host ""

# Set environment variables
$env:PORT = $GATEWAY_PORT
$env:REPLICA_URLS = $REPLICA_URLS

# Start Gateway
Write-Host "Starting Gateway..." -ForegroundColor Yellow
Set-Location (Split-Path $PSCommandPath)
& node gateway\index.js

Write-Host ""
Write-Host "Frontend available at:" -ForegroundColor Green
Write-Host "  http://localhost:3000?gatewayUrl=ws://localhost:4000" -ForegroundColor Cyan
Write-Host "  http://machine1.local:3000?gatewayUrl=ws://machine1.local:4000" -ForegroundColor Cyan
