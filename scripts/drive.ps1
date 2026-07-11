<#
  drive.ps1  -  One-command live launch for the PowerRay cockpit

  Run this AFTER connecting your PC to the drone's WiFi AP (PRA_Station_488057).
  It does a quick preflight, then starts the web UI and opens your browser:

    1. Clears any FCU_IP / FCU_PORT override left over from simulator testing,
       so the server talks to the REAL drone (192.168.1.12:20002) by default.
    2. Checks you're on the drone's network (gateway 192.168.1.11) and that the
       flight controller answers on :20002 - purely informational, it won't stop
       you (telemetry will connect on its own once the sub is powered up).
    3. Starts  python -u server.py  and opens http://localhost:5000.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\drive.ps1
    optional:  -NoBrowser        (don't auto-open the browser)
               -SkipChecks       (skip the preflight, just launch)
#>
[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [switch]$SkipChecks
)

$ExpectedSsid = 'PRA_Station_488057'
$FcuIp        = '192.168.1.12'
$FcuPort      = 20002
$BaseStation  = '192.168.1.11'
$UiUrl        = 'http://localhost:5000'

# Resolve paths relative to this script so it works from any working directory.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$WebUi    = Join-Path $RepoRoot 'web-ui'
$Server   = Join-Path $WebUi 'server.py'

function Test-Port {
    param([string]$IPAddress, [int]$Port, [int]$TimeoutMs = 700)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect($IPAddress, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
            $tcp.EndConnect($iar); return $true
        }
        return $false
    } catch { return $false } finally { $tcp.Close() }
}

Write-Host ""
Write-Host "==== PowerRay Cockpit - Live Launch ====" -ForegroundColor Magenta

# 1. Never talk to the simulator by accident.
if ($env:FCU_IP -or $env:FCU_PORT) {
    Write-Host ("Clearing simulator override (FCU_IP={0} FCU_PORT={1})" -f $env:FCU_IP, $env:FCU_PORT) -ForegroundColor DarkYellow
}
Remove-Item Env:FCU_IP   -ErrorAction SilentlyContinue
Remove-Item Env:FCU_PORT -ErrorAction SilentlyContinue

if (-not (Test-Path $Server)) {
    Write-Host "Cannot find $Server - are you running this from the repo?" -ForegroundColor Red
    exit 1
}

# 2. Preflight (informational only).
if (-not $SkipChecks) {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1
    $gw = if ($cfg) { $cfg.IPv4DefaultGateway.NextHop | Select-Object -First 1 } else { $null }

    if ($gw -eq $BaseStation) {
        Write-Host "[OK]   On the drone network (gateway $gw)." -ForegroundColor Green
    } elseif ($gw) {
        Write-Host "[WARN] Gateway is $gw, expected $BaseStation." -ForegroundColor Yellow
        Write-Host "       Connect your WiFi to '$ExpectedSsid' first if you want live control." -ForegroundColor Yellow
    } else {
        Write-Host "[WARN] No active network - connect to WiFi '$ExpectedSsid'." -ForegroundColor Yellow
    }

    Write-Host ("       Checking flight controller {0}:{1} ..." -f $FcuIp, $FcuPort) -NoNewline
    if (Test-Port -IPAddress $FcuIp -Port $FcuPort) {
        Write-Host " reachable." -ForegroundColor Green
    } else {
        Write-Host " no answer (that's fine if the sub isn't powered up yet)." -ForegroundColor Yellow
    }
}

# 3. Launch.
Write-Host ""
Write-Host "Starting cockpit -> $UiUrl" -ForegroundColor Cyan
Write-Host "Tip: close the PowerVision Vision+ app on the tablet before connecting the camera." -ForegroundColor DarkGray
Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    Start-Job -ScriptBlock {
        param($u)
        Start-Sleep -Seconds 3
        Start-Process $u
    } -ArgumentList $UiUrl | Out-Null
}

Push-Location $WebUi
try {
    python -u server.py
} finally {
    Pop-Location
}
