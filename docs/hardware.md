# Hardware Internals

## Camera module — Ambarella A12

### Architecture

The camera module has two processors:
- **Linux ARM Cortex-A9**: runs all network daemons, filesystem, telnet shell
- **RTOS ARM Cortex-M4**: ISP, video encoding, real-time camera pipeline
- Communication between them via `ipcbind` daemon and `ambafs` shared memory

### Root shell access

```
telnet 192.168.1.100
login: root
password: (empty — just press Enter)
```

No authentication. Manufacturer oversight.

### Processes running on the module

| Process | Port | Role |
|---------|------|------|
| telnetd | 23 | Root login shell |
| cherokee-worker | 80 | HTTP file server (/DCIM, /live, /mjpeg) |
| AmbaRTSPServer | 554 | RTSP video stream |
| remoteapi_cmd_daemon | 7878 | JSON command channel |
| remoteapi_data_daemon | 8787 | Data/video channel |
| remoteapi_disc_daemon | — | Network discovery |
| remoteapi_syssvc_daemon | — | System services |
| AmbaEventNotifyDaemon | 9888 | Event notifications |
| ipcbind | — | Linux↔RTOS IPC bridge |
| util_svc | — | Utility services |

### Useful shell commands

```sh
# Process list
ps

# Open ports
netstat -tlnp

# RTOS commands
SendToRTOS boot_done        # tell RTOS Linux is ready
SendToRTOS net_ready 0      # network ready (AP mode)
SendToRTOS photo            # trigger photo via RTOS
SendToRTOS record           # trigger record via RTOS

# SD card contents
ls /tmp/SD0/AMBA/

# WiFi config
cat /pref/wifi.conf

# Camera preferences
ls /pref/
```

### Filesystem

- SD card mounted at: `/tmp/SD0/AMBA/`
- Preferences: `/pref/`
- RTOS binary: `/lib/firmware/` (approximate)

## Flight controller — 192.168.1.12

- Firmware: PX4 custom (PowerVision build, **not** ArduSub)
- `autopilot` field in MAVLink HEARTBEAT = 0x0C (ArduPilot) — misleading, actual firmware is PX4-based
- SYS_ID: 2
- 358 parameters in `PV_*` custom namespace

## Base station — 192.168.1.11

- Hardware: HLK-RM08K WiFi module
- Generates WiFi AP `PRA_Station_400314`
- Broadcasts MAVLink on port 8080 (same stream as FCU 20002)
- Admin HTTP on port 80 (password unknown — default was changed)

## RC controller — PRASC10 (192.168.1.103)

- Connects to the PowerRay WiFi
- Communicates via UDP (protocol not yet reversed)
- No TCP ports observed open
