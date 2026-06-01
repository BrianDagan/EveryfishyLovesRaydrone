# PowerRay MAVLink control test — 192.168.1.12:20002
# Tests: listen -> heartbeat -> manual_control -> set_mode

$ip   = '192.168.1.12'
$port = 20002

function Mav-CRC([byte[]]$data, [byte]$crc_extra) {
    $crc = [uint16]0xFFFF
    foreach ($b in $data) {
        $tmp = [byte]($b -bxor ($crc -band 0xFF))
        $tmp = [byte]($tmp -bxor (($tmp -band 0x0F) -shl 4))
        $crc = [uint16](($crc -shr 8) -bxor ([uint16]$tmp -shl 8) -bxor ([uint16]$tmp -shl 3) -bxor ([uint16]($tmp -shr 4)))
    }
    $tmp2 = [byte]($crc_extra -bxor ($crc -band 0xFF))
    $tmp2 = [byte]($tmp2 -bxor (($tmp2 -band 0x0F) -shl 4))
    $crc  = [uint16](($crc -shr 8) -bxor ([uint16]$tmp2 -shl 8) -bxor ([uint16]$tmp2 -shl 3) -bxor ([uint16]($tmp2 -shr 4)))
    return $crc
}

function Make-Mav1([byte]$seq, [byte]$sysid, [byte]$compid, [byte]$msgid, [byte[]]$payload, [byte]$crc_extra) {
    $len  = [byte]$payload.Length
    $head = @($len, $seq, $sysid, $compid, $msgid) + $payload
    $crc  = Mav-CRC ([byte[]]$head) $crc_extra
    return [byte[]](@([byte]0xFE) + [byte[]]$head + [byte[]]@([byte]($crc -band 0xFF), [byte](($crc -shr 8) -band 0xFF)))
}

function Hex-Dump([byte[]]$b, [int]$n) {
    ($b[0..($n-1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
}

function Decode-All([byte[]]$buf, [int]$total) {
    $i = 0
    while ($i -lt $total) {
        if ($buf[$i] -eq 0xFE -and ($total - $i) -ge 8) {
            $plen  = $buf[$i+1]
            if (($total - $i) -lt (6 + $plen + 2)) { break }
            $seq   = $buf[$i+2]
            $sysid = $buf[$i+3]
            $msgid = $buf[$i+5]
            $msg   = switch ($msgid) {
                0   { 'HEARTBEAT' }
                1   { 'SYS_STATUS' }
                30  { 'ATTITUDE' }
                32  { 'LOCAL_POSITION_NED' }
                74  { 'VFR_HUD' }
                76  { 'COMMAND_LONG' }
                77  { 'COMMAND_ACK' }
                105 { 'HIGHRES_IMU' }
                147 { 'BATTERY_STATUS' }
                253 { 'STATUSTEXT' }
                default { "MSG_$msgid" }
            }
            $info = ''
            $base = $i + 6
            if ($msgid -eq 0 -and $plen -ge 9) {
                $type = $buf[$base+6]; $bm = $buf[$base+8]
                $info = " type=$type base_mode=0x{0:X2}" -f $bm
            }
            elseif ($msgid -eq 30 -and $plen -ge 28) {
                $roll  = [BitConverter]::ToSingle($buf, $base+0)
                $pitch = [BitConverter]::ToSingle($buf, $base+4)
                $yaw   = [BitConverter]::ToSingle($buf, $base+8)
                $info  = " roll={0:F1}deg pitch={1:F1}deg yaw={2:F1}deg" -f ($roll*57.3), ($pitch*57.3), ($yaw*57.3)
            }
            elseif ($msgid -eq 77) {
                $cmd = [BitConverter]::ToUInt16($buf,$base+8)
                $res = $buf[$base+10]
                $info = " cmd=$cmd result=$res"
            }
            elseif ($msgid -eq 147 -and $plen -ge 36) {
                $bat = [int]([System.Convert]::ToSByte($buf[$base+35]))
                $info = " bat=${bat}%"
            }
            Write-Host "  [sys=$sysid seq=$seq] $msg$info" -ForegroundColor Green
            $i += 6 + $plen + 2
        } else { $i++ }
    }
}

function Make-Heartbeat([byte]$seq) {
    [byte[]]$pl = @(0,0,0,0, 6, 8, 0x00, 4, 3)  # GCS
    Make-Mav1 $seq 255 190 0 $pl 50
}

function Make-ManCtrl([byte]$seq, [int]$x, [int]$y, [int]$z, [int]$r) {
    [byte[]]$pl = New-Object byte[] 11
    $bx=[BitConverter]::GetBytes([int16]$x); $pl[0]=$bx[0]; $pl[1]=$bx[1]
    $by=[BitConverter]::GetBytes([int16]$y); $pl[2]=$by[0]; $pl[3]=$by[1]
    $bz=[BitConverter]::GetBytes([int16]$z); $pl[4]=$bz[0]; $pl[5]=$bz[1]
    $br=[BitConverter]::GetBytes([int16]$r); $pl[6]=$br[0]; $pl[7]=$br[1]
    $pl[8]=0; $pl[9]=0; $pl[10]=1
    Make-Mav1 $seq 255 190 69 $pl 243
}

Write-Host "=== PowerRay MAVLink Control Test ===" -ForegroundColor Magenta
$c = New-Object System.Net.Sockets.TcpClient
$c.NoDelay=$true; $c.ReceiveTimeout=300

try {
    $c.Connect($ip,$port)
    Write-Host "[OK] Connected" -ForegroundColor Green
    $s = $c.GetStream()
    $buf = New-Object byte[] 8192
    $seq = [byte]0

    Write-Host "`n[1] Listening 4s (FCU broadcast)..." -ForegroundColor Cyan
    $t0 = (Get-Date).AddSeconds(4)
    while ((Get-Date) -lt $t0) {
        if ($s.DataAvailable) {
            $n = $s.Read($buf,0,$buf.Length)
            if ($n -gt 0) { Decode-All $buf $n }
        }
        Start-Sleep -Milliseconds 50
    }

    Write-Host "`n[2] Sending HEARTBEAT (3x)..." -ForegroundColor Cyan
    for ($i=0; $i -lt 3; $i++) {
        $pkt = Make-Heartbeat $seq; $seq=[byte](($seq+1)%256)
        $s.Write($pkt,0,$pkt.Length); $s.Flush()
        Write-Host "  [TX HB] $(Hex-Dump $pkt $pkt.Length)" -ForegroundColor DarkCyan
        $t1=(Get-Date).AddSeconds(1.5)
        while ((Get-Date) -lt $t1) {
            if ($s.DataAvailable) {
                $n=$s.Read($buf,0,$buf.Length)
                if ($n -gt 0) { Decode-All $buf $n }
            }
            Start-Sleep -Milliseconds 50
        }
    }

    Write-Host "`n[3] MANUAL_CONTROL neutral (x=0 y=0 z=500 r=0)..." -ForegroundColor Cyan
    $pkt2 = Make-ManCtrl $seq 0 0 500 0; $seq=[byte](($seq+1)%256)
    $s.Write($pkt2,0,$pkt2.Length); $s.Flush()
    Write-Host "  [TX MC] $(Hex-Dump $pkt2 $pkt2.Length)" -ForegroundColor DarkCyan
    $t2=(Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $t2) {
        if ($s.DataAvailable) {
            $n=$s.Read($buf,0,$buf.Length)
            if ($n -gt 0) { Decode-All $buf $n }
        }
        Start-Sleep -Milliseconds 50
    }

    Write-Host "`n[4] SET_MODE MANUAL (custom_mode=19)..." -ForegroundColor Cyan
    [byte[]]$sm = New-Object byte[] 6
    $bc=[BitConverter]::GetBytes([uint32]19); [Array]::Copy($bc,0,$sm,0,4)
    $sm[4]=1; $sm[5]=0x59
    $pkt3 = Make-Mav1 $seq 255 190 11 $sm 89; $seq=[byte](($seq+1)%256)
    $s.Write($pkt3,0,$pkt3.Length); $s.Flush()
    Write-Host "  [TX SET_MODE] $(Hex-Dump $pkt3 $pkt3.Length)" -ForegroundColor DarkCyan
    $t3=(Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $t3) {
        if ($s.DataAvailable) {
            $n=$s.Read($buf,0,$buf.Length)
            if ($n -gt 0) { Decode-All $buf $n }
        }
        Start-Sleep -Milliseconds 50
    }

} catch {
    Write-Host "[ERR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    $c.Close()
    Write-Host "`n[DONE]" -ForegroundColor DarkGray
}
