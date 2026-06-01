# Sonar Protocol

## Integrated sonar — FCU port 7700

Source: `SonarDataHeadDefault.java`, `SonarDataDecoder.java` (from APK analysis)

**Host**: `192.168.1.100:7700` TCP  
**Status**: Port is closed unless a compatible sonar module is physically connected.

### Frame format

```
AA 55 00 00 00 00 00 00 [CMD] [LEN_H] [LEN_L] [DATA...]
```

- Magic: `AA 55`
- 6 zero padding bytes
- CMD: 1 byte command code
- LEN: 2-byte big-endian data length
- DATA: variable length payload

### TX commands (PC → Sonar)

| CMD | Hex | Name |
|-----|-----|------|
| open | 0x10 | Start sonar acquisition |
| close | 0x11 | Stop sonar acquisition |
| get_temp | 0xB0 | Request temperature |
| get_battery | 0xB2 | Request battery level |
| get_version | 0xC2 | Request firmware version |

### RX responses (Sonar → PC)

| CMD | Hex | Name | Payload |
|-----|-----|------|---------|
| temp | 0xB1 | Temperature | 2 bytes: `(b[0]<<8 | b[1]) / 10` = degrees C |
| battery | 0xB3 | Battery | 2 bytes: `(b[0]<<8 | b[1]) / 10` = % |
| image_sonar | 0xB4 | Sonar column | N bytes, each 0-255 = echo intensity |
| version | 0xC3 | Firmware version | 12-byte ASCII string |
| confirm | 0xFF | ACK | 1 byte: ACK'd command code |

### Quick test (Python)

```python
import socket

s = socket.create_connection(('192.168.1.100', 7700), timeout=5)

def send_cmd(s, cmd, data=b''):
    pkt = bytes([0xAA, 0x55, 0, 0, 0, 0, 0, 0,
                 cmd, (len(data)>>8)&0xFF, len(data)&0xFF]) + data
    s.sendall(pkt)
    return s.recv(4096)

resp = send_cmd(s, 0xC2)   # get_version
resp = send_cmd(s, 0x10)   # open
# now sonar streams 0xB4 image frames
```

---

## PSE fishfinder sonar — separate WiFi

SSID: `PSE_230252`  
MAC: `dc:56:e6:05:c1:96` (Bococom Technology)  
Gateway: `192.168.1.1`

This is a **separate device** from the submarine. Connect to the PSE WiFi network (not the PowerRay network).

### Known services

| Port | Protocol | Notes |
|------|----------|-------|
| 80 | HTTP | 401 Basic auth, realm="PSE" — credentials unknown |
| 5000 | TCP | Sends `Server "PSE"\r\n` banner, then silent |
| (unknown) | UDP | Actual sonar data — port hardcoded in `libfishfinder.so` |

### Library interface (`libfishfinder.so`, Denesoft FF788)

The sonar is driven by a native library accessed via JNI:
```
NDKSetMacAddress(mac)      // set sonar MAC address
NDKSetIPAddress(ip)        // set sonar IP (192.168.1.1)
NDKServerStart()           // start listener
NDKLoad(mode)              // load acquisition mode
NDKWifiIsValid()           // check connection
FF788Server_SetMasterDevice(mac)  // claim master (only one master allowed)
```

### One-master constraint

Only one device can be master at a time. If the tablet holds master, you get:
`"Another Device own the master of SonarPhone"`

### TODO: capture real protocol

To capture the UDP protocol:
1. Connect tablet to PSE WiFi
2. Run Wireshark on the PSE WiFi interface while the fishfinder app is active
3. Filter `udp` and note source/destination ports

Alternative: install ADB driver for MediaTek (VID_0E8D, PID_201D) and capture logcat from the sonar app.
