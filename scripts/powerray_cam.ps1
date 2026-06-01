# PowerRay camera JSON client — Ambarella port 7878
# Close Vision+ on the tablet before running this script

$ip   = '192.168.1.100'
$port = 7878

Write-Host "=== PowerRay Camera JSON Client ===" -ForegroundColor Magenta
Write-Host "Connecting ${ip}:${port}..." -ForegroundColor Yellow
Write-Host "IMPORTANT: Close Vision+ app on tablet first!" -ForegroundColor Yellow

$client = New-Object System.Net.Sockets.TcpClient
$client.ReceiveTimeout = 5000
$client.SendTimeout    = 3000

function Send-Recv([System.Net.Sockets.NetworkStream]$stream, [string]$json) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    Write-Host "[TX] $json" -ForegroundColor DarkCyan

    $buf = New-Object byte[] 65536
    $resp = ''
    $deadline = (Get-Date).AddMilliseconds(8000)  # 8s — RTOS takes ~1-2s to respond
    while ((Get-Date) -lt $deadline) {
        try {
            if ($stream.DataAvailable) {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -gt 0) {
                    $resp += [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
                    try {
                        $null = ConvertFrom-Json $resp -ErrorAction Stop
                        break
                    } catch {}
                }
            }
        } catch {}
        Start-Sleep -Milliseconds 50
    }
    if ($resp) {
        Write-Host "[RX] $resp" -ForegroundColor Green
    } else {
        Write-Host "[RX] <timeout — RTOS did not respond>" -ForegroundColor Red
    }
    return $resp
}

try {
    $client.Connect($ip, $port)
    Write-Host "[OK] Connected" -ForegroundColor Green
    $stream = $client.GetStream()

    Write-Host "`n--- Start Session (msg_id=257) ---" -ForegroundColor Cyan
    $resp = Send-Recv $stream '{"token":0,"msg_id":257}'
    $token = 0
    if ($resp) {
        try {
            $j = ConvertFrom-Json $resp
            if ($j.rval -eq 0 -and $j.param) {
                if ($j.param -match '\d+') {
                    $token = [int]$matches[0]
                    Write-Host "[TOKEN] $token" -ForegroundColor Yellow
                }
            }
        } catch { Write-Host "[!] Parse error: $_" }
    }

    Start-Sleep -Milliseconds 200

    Write-Host "`n--- Device Info (msg_id=11) ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":11}"

    Start-Sleep -Milliseconds 200

    Write-Host "`n--- Battery Level (msg_id=13) ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":13}"

    Start-Sleep -Milliseconds 200

    Write-Host "`n--- All Settings (msg_id=3) ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":3}"

    Start-Sleep -Milliseconds 200

    Write-Host "`n--- Free Space (msg_id=5) ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":5,`"type`":`"free`"}"

    Start-Sleep -Milliseconds 200

    Write-Host "`n--- Activate Viewfinder (msg_id=259) — enables RTSP ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":259,`"param`":`"none_force`"}"

    Write-Host "`nViewfinder active — RTSP stream at: rtsp://192.168.1.100/live" -ForegroundColor Green
    Start-Sleep -Milliseconds 500

    Write-Host "`n--- Stop Session (msg_id=258) ---" -ForegroundColor Cyan
    $null = Send-Recv $stream "{`"token`":$token,`"msg_id`":258}"

} catch {
    Write-Host "[ERR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    $client.Close()
    Write-Host "`n[DONE]" -ForegroundColor Green
}
