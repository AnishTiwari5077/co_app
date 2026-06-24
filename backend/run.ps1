# SahakariMS Backend - Quick Start Script
# Usage: Right-click -> Run with PowerShell  OR  just run: .\run.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   SahakariMS Backend Startup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Load .env file ────────────────────────────────────────────────────────────
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Write-Host "[ENV] Loading secrets from .env..." -ForegroundColor DarkGray
    Get-Content $envFile | ForEach-Object {
        # Skip comments and blank lines
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
        # Parse KEY=VALUE
        if ($_ -match '^([^=]+)=(.*)$') {
            $key   = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "[OK] .env loaded" -ForegroundColor Green
} else {
    Write-Host "[!] No .env file found - using appsettings.json values" -ForegroundColor Yellow
}

# ── Set ASP.NET Core environment variables from .env ─────────────────────────
# These override appsettings.json automatically (ASP.NET Core config priority)
if ($env:LOCAL_DB_HOST) {
    $connStr = "Host=$($env:LOCAL_DB_HOST);Port=$($env:LOCAL_DB_PORT);Database=$($env:LOCAL_DB_NAME);Username=$($env:LOCAL_DB_USER);Password=$($env:LOCAL_DB_PASSWORD);"
    [System.Environment]::SetEnvironmentVariable("ConnectionStrings__DefaultConnection", $connStr, "Process")
    Write-Host "[ENV] DB connection set from .env (user: $($env:LOCAL_DB_USER))" -ForegroundColor DarkGray
}

if ($env:LOCAL_JWT_SECRET) {
    [System.Environment]::SetEnvironmentVariable("JwtSettings__SecretKey", $env:LOCAL_JWT_SECRET, "Process")
    Write-Host "[ENV] JWT secret set from .env" -ForegroundColor DarkGray
}

Write-Host ""

# ── Check PostgreSQL ──────────────────────────────────────────────────────────
$pg = Get-Service -Name "postgresql-16" -ErrorAction SilentlyContinue
if ($pg.Status -ne "Running") {
    Write-Host "[!] PostgreSQL is not running. Starting..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Start-Service postgresql-16; exit" -Wait
} else {
    Write-Host "[OK] PostgreSQL is running" -ForegroundColor Green
}

# ── Check Redis ───────────────────────────────────────────────────────────────
$redis = Get-Service -Name "Redis" -ErrorAction SilentlyContinue
if ($redis.Status -ne "Running") {
    Write-Host "[!] Redis is not running. Starting..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Start-Service Redis; exit" -Wait
} else {
    Write-Host "[OK] Redis is running" -ForegroundColor Green
}

# ── Kill any process already using port 5111 ──────────────────────────────────
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

# ── Run the API ───────────────────────────────────────────────────────────────
dotnet run --project src/SahakariMS.Api/SahakariMS.Api.csproj
