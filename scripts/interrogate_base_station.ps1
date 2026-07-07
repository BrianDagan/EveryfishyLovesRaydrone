<#
  interrogate_base_station.ps1  -  PowerRay / PSE base-station recon

  Run this AFTER connecting your PC to the drone's WiFi access point
  (e.g. PRA_Station_488057). It:

    1. Reports your PC's IPv4 + the default gateway. On these drones the WiFi
       AP *is* the base station, so the gateway is the base station's address -
       even if this unit does not use the usual 192.168.1.11.
    2. Scans the gateway PLUS every known PowerRay/PSE device IP for open ports.
    3. Grabs a short banner / HTTP response from each open port so you can see
       what the base station actually exposes (MAVLink, HTTP admin + auth realm,
       PSE fishfinder banner, camera JSON API, telnet, RTSP, ...).

  Nothing here writes to the drone - it is a read-only reconnaissance sweep, so
  it is safe to run before you ever try to arm/drive.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\interrogate_base_station.ps1
    optional:  -TimeoutMs 600   -Extra 192.168.1.50,10.0.0.1
#>
[CmdletBinding()]
param(
    [int]$TimeoutMs = 400,
    [int[]]$Ports = @(21,22,23,80,111,443,554,1883,5000,7700,7878,7979,8080,8081,8443,8787,9888,20002),
    [string[]]$Extra = @()
)

$ExpectedSsid = 'PRA_Station_488057'   # your unit's AP; PowerRay stock is PRA_Station_xxxxxx

# Roles for the IPs we know about across PowerRay / PSE variants.
$KnownRoles = @{
    '192.168.1.1'   = 'Gateway / PSE fishfinder base'
    '192.168.1.11'  = 'Base station (HLK-RM08K WiFi module)'
    '192.168.1.12'  = 'Flight controller (PX4 custom) - MAVLink 20002'
    '192.168.1.100' = 'Camera module (Ambarella A12)'
    '192.168.1.103' = 'RC controller (PRASC10)'
}
$Httpish = @(80,443,5000,7878,8080,8081,8443)

function Get-DroneNet {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1
    if (-not $cfg) { return $null }
    [pscustomobject]@{
        Adapter = $cfg.InterfaceAlias
        IPv4    = ($cfg.IPv4Address.IPAddress | Select-Object -First 1)
        Gateway = ($cfg.IPv4DefaultGateway.NextHop | Select-Object -First 1)
    }
}

function Test-Port {
    param([string]$IPAddress, [int]$Port, [int]$TimeoutMs)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect($IPAddress, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
            $tcp.EndConnect($iar); return $true
        }
        return $false
    } catch { return $false } finally { $tcp.Close() }
}

function Get-Banner {
    param([string]$IPAddress, [int]$Port, [int]$TimeoutMs)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect($IPAddress, $Port, $null, $null)
        if (-not ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected)) { return $null }
        $tcp.EndConnect($iar)
        $tcp.ReceiveTimeout = [Math]::Max($TimeoutMs, 700)
        $ns = $tcp.GetStream()
        if ($Httpish -contains $Port) {
            $req = "GET / HTTP/1.0`r`nHost: $IPAddress`r`nUser-Agent: raydrone-recon`r`n`r`n"
            $b = [Text.Encoding]::ASCII.GetBytes($req)
            $ns.Write($b, 0, $b.Length); $ns.Flush()
        }
        Start-Sleep -Milliseconds 300
        $buf = New-Object 'byte[]' 600
        $read = 0
        try { $read = $ns.Read($buf, 0, $buf.Length) } catch {}
        if ($read -le 0) { return $null }
        $txt = [Text.Encoding]::ASCII.GetString($buf, 0, $read)
        $txt = ($txt -replace '[^\x20-\x7e\r\n\t]', '.').Trim()
        $lines = $txt -split "`r?`n" | Where-Object { $_ -ne '' } | Select-Object -First 6
        return ($lines -join ' | ')
    } catch { return $null } finally { $tcp.Close() }
}

Write-Host ""
Write-Host "==== PowerRay / PSE Base-Station Interrogation ====" -ForegroundColor Magenta
Write-Host "Expected AP for this unit: $ExpectedSsid" -ForegroundColor DarkGray

$net = Get-DroneNet
if ($net) {
    Write-Host ("PC adapter : {0}" -f $net.Adapter)
    Write-Host ("PC IPv4    : {0}" -f $net.IPv4)
    Write-Host ("Gateway    : {0}   <-- this is the base station AP" -f $net.Gateway) -ForegroundColor Yellow
} else {
    Write-Host "No active IPv4 gateway found - are you connected to the drone's WiFi?" -ForegroundColor Red
}
Write-Host ""

# Build de-duplicated target list: gateway first, then knowns, then extras.
$targets = New-Object System.Collections.Generic.List[string]
if ($net -and $net.Gateway) { [void]$targets.Add($net.Gateway) }
foreach ($ip in $KnownRoles.Keys) { if (-not $targets.Contains($ip)) { [void]$targets.Add($ip) } }
foreach ($ip in $Extra)          { if ($ip -and -not $targets.Contains($ip)) { [void]$targets.Add($ip) } }

$anyOpen = $false
foreach ($ip in $targets) {
    if ($net -and $ip -eq $net.Gateway) {
        if ($KnownRoles.ContainsKey($ip)) { $role = 'AP / gateway - ' + $KnownRoles[$ip] }
        else                              { $role = 'AP / gateway (base station)' }
    } elseif ($KnownRoles.ContainsKey($ip)) {
        $role = $KnownRoles[$ip]
    } else {
        $role = 'extra target'
    }

    Write-Host ("{0}  -  {1}" -f $ip, $role) -ForegroundColor Cyan
    $openHere = $false
    foreach ($p in $Ports) {
        if (Test-Port -IPAddress $ip -Port $p -TimeoutMs $TimeoutMs) {
            $anyOpen = $true; $openHere = $true
            $banner = Get-Banner -IPAddress $ip -Port $p -TimeoutMs $TimeoutMs
            if ($banner) {
                Write-Host ("  :{0,-5} OPEN  {1}" -f $p, $banner) -ForegroundColor Green
            } else {
                Write-Host ("  :{0,-5} OPEN" -f $p) -ForegroundColor Green
            }
        }
    }
    if (-not $openHere) { Write-Host "  (no open ports in list)" -ForegroundColor DarkGray }
    Write-Host ""
}

if (-not $anyOpen) {
    Write-Host "Nothing open. Confirm you are on the $ExpectedSsid WiFi, then re-run." -ForegroundColor Red
} else {
    Write-Host "[DONE] Look for :20002 (MAVLink FCU = driveable) and :80 (base-station admin)." -ForegroundColor Green
}
