# Port scan for PowerRay submarine
# Connect to the drone's WiFi AP first (this unit: PRA_Station_488057; PowerRay stock: PRA_Station_xxxxxx)
# Tip: run scripts\interrogate_base_station.ps1 for gateway auto-detect + banner grab.

$targets = @(
    @{ip='192.168.1.11'; label='Base station (HLK-RM08K)'},
    @{ip='192.168.1.12'; label='FCU (flight controller)'},
    @{ip='192.168.1.100'; label='Camera module (Ambarella A12)'},
    @{ip='192.168.1.103'; label='RC PRASC10'}
)

$ports = @(23, 80, 111, 554, 7700, 7878, 7979, 8080, 8081, 8787, 9888, 20002)

Write-Host "=== PowerRay Network Scan ===" -ForegroundColor Magenta
Write-Host "Make sure you are connected to the drone's WiFi (PRA_Station_488057)`n"

foreach ($target in $targets) {
    Write-Host "$($target.ip) — $($target.label)" -ForegroundColor Cyan
    foreach ($port in $ports) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect($target.ip, $port, $null, $null)
            $ok = $async.AsyncWaitHandle.WaitOne(300, $true)
            if ($ok -and $tcp.Connected) {
                Write-Host "  :$port OPEN" -ForegroundColor Green
            }
            $tcp.Close()
        } catch {}
    }
    Write-Host ""
}

Write-Host "[DONE]" -ForegroundColor Green
