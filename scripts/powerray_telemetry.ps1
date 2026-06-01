# PowerRay MAVLink telemetry client — 192.168.1.12:20002

$ip = '192.168.1.12'
$port = 20002

$MAVLINK_MSGS = @{
    0   = 'HEARTBEAT'
    1   = 'SYS_STATUS'
    30  = 'ATTITUDE'
    32  = 'LOCAL_POSITION_NED'
    33  = 'GLOBAL_POSITION_INT'
    74  = 'VFR_HUD'
    105 = 'HIGHRES_IMU'
    140 = 'ACTUATOR_CONTROL_TARGET'
    147 = 'BATTERY_STATUS'
    251 = 'NAMED_VALUE_FLOAT'
    253 = 'STATUSTEXT'
}

function Parse-MAVLink([byte[]]$buf, [int]$start) {
    if ($buf.Length - $start -lt 8) { return $null }
    $len    = $buf[$start+1]
    $seq    = $buf[$start+2]
    $sysid  = $buf[$start+3]
    $compid = $buf[$start+4]
    $msgid  = $buf[$start+5]
    $total  = 6 + $len + 2
    if ($buf.Length - $start -lt $total) { return $null }

    $payload = $buf[($start+6)..($start+5+$len)]
    $msgname = if ($MAVLINK_MSGS.ContainsKey($msgid)) { $MAVLINK_MSGS[$msgid] } else { "MSG_$msgid" }

    $decoded = switch ($msgid) {
        30 {  # ATTITUDE (roll pitch yaw in radians)
            if ($payload.Length -ge 16) {
                $roll  = [BitConverter]::ToSingle($payload, 4) * 57.2958
                $pitch = [BitConverter]::ToSingle($payload, 8) * 57.2958
                $yaw   = [BitConverter]::ToSingle($payload, 12) * 57.2958
                "roll={0:F1}deg pitch={1:F1}deg yaw={2:F1}deg" -f $roll, $pitch, $yaw
            }
        }
        32 {  # LOCAL_POSITION_NED
            if ($payload.Length -ge 24) {
                $x = [BitConverter]::ToSingle($payload, 4)
                $y = [BitConverter]::ToSingle($payload, 8)
                $z = [BitConverter]::ToSingle($payload, 12)
                "x={0:F2}m y={1:F2}m z={2:F2}m depth={3:F2}m" -f $x, $y, $z, (-$z)
            }
        }
        33 {  # GLOBAL_POSITION_INT
            if ($payload.Length -ge 18) {
                $lat = [BitConverter]::ToInt32($payload, 4) / 1e7
                $lon = [BitConverter]::ToInt32($payload, 8) / 1e7
                $alt = [BitConverter]::ToInt32($payload, 12) / 1000.0
                "lat={0:F6} lon={1:F6} alt={2:F1}m" -f $lat, $lon, $alt
            }
        }
        74 {  # VFR_HUD
            if ($payload.Length -ge 20) {
                $airspeed    = [BitConverter]::ToSingle($payload, 0)
                $groundspeed = [BitConverter]::ToSingle($payload, 4)
                $heading     = [BitConverter]::ToInt16($payload, 8)
                $throttle    = [BitConverter]::ToUInt16($payload, 10)
                $alt         = [BitConverter]::ToSingle($payload, 12)
                "speed={0:F1}m/s heading={1}deg throttle={2}% alt={3:F1}m" -f $airspeed, $heading, $throttle, $alt
            }
        }
        105 {  # HIGHRES_IMU
            if ($payload.Length -ge 32) {
                $xacc = [BitConverter]::ToSingle($payload, 8)
                $yacc = [BitConverter]::ToSingle($payload, 12)
                $zacc = [BitConverter]::ToSingle($payload, 16)
                "acc=({0:F2},{1:F2},{2:F2})m/s2" -f $xacc, $yacc, $zacc
            }
        }
        251 { # NAMED_VALUE_FLOAT
            if ($payload.Length -ge 8) {
                $val  = [BitConverter]::ToSingle($payload, 4)
                $name = [System.Text.Encoding]::ASCII.GetString($payload, 8, [Math]::Min(10, $payload.Length-8)).TrimEnd([char]0)
                "$name = $val"
            }
        }
        253 { # STATUSTEXT
            if ($payload.Length -ge 1) {
                $sev  = $payload[0]
                $text = [System.Text.Encoding]::ASCII.GetString($payload, 1, [Math]::Min(50,$payload.Length-1)).TrimEnd([char]0)
                "SEV=$sev : $text"
            }
        }
        default { ($payload | ForEach-Object { "{0:X2}" -f $_ }) -join ' ' | Select-Object -First 1 }
    }

    return [PSCustomObject]@{
        Seq     = $seq
        SysID   = $sysid
        MsgName = $msgname
        Decoded = $decoded
        Total   = $total
    }
}

Write-Host "=== PowerRay MAVLink Telemetry ===" -ForegroundColor Magenta
Write-Host "Connecting to ${ip}:${port}..." -ForegroundColor Yellow

$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect($ip, $port)
    Write-Host "[OK] Connected" -ForegroundColor Green

    $stream = $client.GetStream()
    $stream.ReadTimeout = 100
    $buf = New-Object byte[] 65536
    $acc = [System.Collections.Generic.List[byte]]::new()
    $deadline = (Get-Date).AddSeconds(30)
    $count = 0

    while ((Get-Date) -lt $deadline) {
        try {
            if ($stream.DataAvailable) {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -gt 0) { for ($i=0; $i -lt $n; $i++) { $acc.Add($buf[$i]) } }
            }
        } catch {}

        $i = 0
        while ($i -lt $acc.Count) {
            if ($acc[$i] -eq 0xFE) {
                $arr = $acc.ToArray()
                $msg = Parse-MAVLink $arr $i
                if ($msg) {
                    $color = switch ($msg.MsgName) {
                        'ATTITUDE'          { 'Cyan' }
                        'NAMED_VALUE_FLOAT' { 'Yellow' }
                        'HIGHRES_IMU'       { 'Green' }
                        'STATUSTEXT'        { 'Red' }
                        default             { 'White' }
                    }
                    Write-Host "[$($msg.Seq)] $($msg.MsgName): $($msg.Decoded)" -ForegroundColor $color
                    $acc.RemoveRange($i, $msg.Total)
                    $count++
                    continue
                }
            }
            $i++
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host "`n[DONE] $count MAVLink messages received" -ForegroundColor Green
} catch {
    Write-Host "[ERR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    $client.Close()
}
