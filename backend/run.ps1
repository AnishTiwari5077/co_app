# SahakariMS Backend - Quick Start Script
# Usage: Right-click -> Run with PowerShell  OR  just run: .\run.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   SahakariMS Backend Startup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check PostgreSQL
$pg = Get-Service -Name "postgresql-16" -ErrorAction SilentlyContinue
if ($pg.Status -ne "Running") {
    Write-Host "[!] PostgreSQL is not running. Starting..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Start-Service postgresql-16; exit" -Wait
} else {
    Write-Host "[OK] PostgreSQL is running" -ForegroundColor Green
}

# Check Redis
$redis = Get-Service -Name "Redis" -ErrorAction SilentlyContinue
if ($redis.Status -ne "Running") {
    Write-Host "[!] Redis is not running. Starting..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Start-Service Redis; exit" -Wait
} else {
    Write-Host "[OK] Redis is running" -ForegroundColor Green
}

# Kill any process already using port 5111
$existing = Get-NetTCPConnection -LocalPort 5111 -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[!] Port 5111 in use. Freeing it..." -ForegroundColor Yellow
    $existing | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "[>>] Starting API..." -ForegroundColor Cyan
Write-Host "     Swagger  -> http://localhost:5111/swagger" -ForegroundColor White
Write-Host "     Hangfire -> http://localhost:5111/hangfire" -ForegroundColor White
Write-Host ""
Write-Host "     Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run the API
dotnet run --project src/SahakariMS.Api/SahakariMS.Api.csproj
