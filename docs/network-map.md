# Network Map — PowerVision PowerRay

WiFi SSID: `PRA_Station_400314`  
Our PC IP when connected: `192.168.1.14`

## Devices

| IP | Device | Role |
|----|--------|------|
| 192.168.1.11 | HLK-RM08K | WiFi access point / base station |
| 192.168.1.12 | Pixhawk-style FCU | Flight controller (PX4 custom) |
| 192.168.1.100 | Ambarella A12 | Camera + processing module |
| 192.168.1.103 | PRASC10 | RC remote controller |

## Port map (confirmed by scan)

### 192.168.1.11 — Base station
| Port | Protocol | Status | Notes |
|------|----------|--------|-------|
| 80 | HTTP | 401 Basic auth | Admin interface, password unknown |
| 8080 | MAVLink TCP | Open | Base station heartbeat broadcast |
| 8081 | Unknown binary | Open | Protocol unknown |

### 192.168.1.12 — FCU (flight controller)
| Port | Protocol | Status | Notes |
|------|----------|--------|-------|
| **20002** | MAVLink v1 TCP | ✅ Open, no auth | Main telemetry + control channel |

### 192.168.1.100 — Camera module (Ambarella A12)
| Port | Protocol | Status | Notes |
|------|----------|--------|-------|
| 23 | Telnet | ✅ Open, root/no password | Full Linux root shell |
| 80 | HTTP Cherokee | ✅ Open | /DCIM, /live, /mjpeg, /pref, /shutter |
| 111 | rpcbind | Open | — |
| 554 | RTSP | ✅ Open | `rtsp://192.168.1.100/live` (requires viewfinder active) |
| **7878** | JSON TCP | ✅ Open | Ambarella remoteapi_cmd_daemon |
| 8787 | TCP | ✅ Open | Ambarella remoteapi_data_daemon |
| 9888 | TCP | Open | AmbaEventNotifyDaemon |
| 7700 | Binary TCP | Closed | Sonar (opens when module connected) |

### 192.168.1.103 — RC PRASC10
| Port | Protocol | Status | Notes |
|------|----------|--------|-------|
| — | UDP | Unknown | Protocol not yet reversed |

## Sonar PSE — separate WiFi
SSID: `PSE_230252`  
Gateway/sonar: `192.168.1.1`  
Our IP on PSE network: `192.168.1.100`

| Port | Protocol | Status | Notes |
|------|----------|--------|-------|
| 80 | HTTP | 401 Basic auth | realm="PSE", credentials unknown |
| 5000 | TCP | Sends banner `Server "PSE"\r\n` | Then silent — real data is UDP |
| UDP | Unknown port | Hardcoded in `libfishfinder.so` | Not yet captured |
