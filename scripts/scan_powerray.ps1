# Port scan for PowerRay submarine
# Connect to PRA_Station_400314 WiFi first

$targets = @(
    @{ip='192.168.1.11'; label='Base station (HLK-RM08K)'},
    @{ip='192.168.1.12'; label='FCU (flight controller)'},
    @{ip='192.168.1.100'; label='Camera module (Ambarella A12)'},
    @{ip='192.168.1.103'; label='RC PRASC10'}
)

$ports = @(23, 80, 111, 554, 7700, 7878, 7979, 8080, 8081, 8787, 9888, 20002)

Write-Host "=== PowerRay Network Scan ===" -ForegroundColor Magenta
Write-Host "Make sure you are connected to PRA_Station_400314 WiFi`n"

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
