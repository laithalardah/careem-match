# One command to run Careem Match for you and your friends.
#   powershell -ExecutionPolicy Bypass -File .\start_demo.ps1
#
# What it does:
#   1. starts the Careem sandbox MCP (if it is not already running)
#   2. finds this computer's Wi-Fi/LAN address
#   3. builds the Flutter web app pointing at that address (skipped if nothing changed)
#   4. starts the backend, which also serves the app, on http://<address>:8000
# Then everyone on the same Wi-Fi opens that address (or scans the QR code in the lobby).
#
#   -Port 8000      change the port
#   -Ip 192.168.1.5 use this address instead of the detected one (e.g. a hotspot)
#   -SkipBuild      do not rebuild the app
#   -NoDemo         turn demo friends off
param([int]$Port = 8000, [string]$Ip = '', [switch]$SkipBuild, [switch]$NoDemo)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Test-Path "$root\.env")) { throw ".env is missing. Run .\refresh_env.ps1 and paste your AWS export lines first." }

# 1. sandbox MCP
function Test-Port($p) { [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) }
if (-not (Test-Port 8787)) {
    Write-Host 'Starting the Careem sandbox MCP ...'
    Start-Process npm.cmd -ArgumentList 'start' -WorkingDirectory "$root\sandbox\server" -WindowStyle Hidden
    for ($i = 0; $i -lt 30 -and -not (Test-Port 8787); $i++) { Start-Sleep 1 }
    if (-not (Test-Port 8787)) { throw 'The sandbox did not start. Try: cd sandbox\server; npm install; npm start' }
}

# 2. address
if (-not $Ip) {
    $Ip = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        ForEach-Object { $_.IPv4Address.IPAddress } | Select-Object -First 1
}
if (-not $Ip) { throw 'Could not find your Wi-Fi address. Connect to a network, or pass -Ip x.x.x.x' }
$base = "http://${Ip}:$Port"

# 3. app build (the address is baked in, so rebuild when it changes)
$marker = "$root\app\build\.demo_api_base"
$built = (Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $base) -and (Test-Path "$root\app\build\web\index.html")
if (-not $SkipBuild -and -not $built) {
    Write-Host "Building the app for $base (about 30 s) ..."
    Push-Location "$root\app"
    flutter build web --release --dart-define=API_BASE=$base
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'flutter build failed' }
    Pop-Location
    Set-Content $marker $base -Encoding ascii
}

# 4. backend + app
$env:PUBLIC_APP_URL = $base
$env:DEMO = if ($NoDemo) { '0' } else { '1' }
Write-Host ''
Write-Host "  Open on this computer:   $base" -ForegroundColor Green
Write-Host "  Friends on the same Wi-Fi open the same address (or scan the QR in the lobby)." -ForegroundColor Green
Write-Host "  If a friend cannot connect, allow Python through the Windows firewall (Private networks)." -ForegroundColor Yellow
Write-Host '  Stop with Ctrl+C.'
Write-Host ''
Set-Location "$root\backend"
& ".\.venv\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port $Port
