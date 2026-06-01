# Camera JSON API — Ambarella A12

## Connection

- **Host**: `192.168.1.100:7878` TCP
- **Protocol**: raw JSON over TCP, no delimiter, no length prefix
- **Authentication**: session token (obtained at connect)
- **Daemon**: `remoteapi_cmd_daemon` (Linux ARM process)

## Critical: keep the connection open

The daemon passes JSON to the RTOS (Cortex-M4) via IPC and waits for a response before replying. The RTOS takes ~1-2 seconds. If you close the TCP connection before the RTOS responds, you get silence — no error, no response.

**Always** use `settimeout(15)` and keep the socket open for the lifetime of the session.

## Session sequence

```python
import socket, json, time

s = socket.create_connection(('192.168.1.100', 7878))
s.settimeout(15)

# 1. Start session — get token
s.sendall(b'{"token":0,"msg_id":257}')
resp = json.loads(s.recv(4096))
# resp = {"rval": 0, "msg_id": 257, "param": 8}
token = resp['param']

# 2. Activate viewfinder — starts RTSP pipeline
s.sendall(json.dumps({"token": token, "msg_id": 259, "param": "none_force"}).encode())
resp = json.loads(s.recv(4096))
# resp = {"rval": 0, "msg_id": 259}

time.sleep(1.5)  # let RTOS start the pipeline

# 3. RTSP is now active: rtsp://192.168.1.100/live
# DO NOT close the socket — closing it kills the session

# At the end:
s.sendall(json.dumps({"token": token, "msg_id": 258}).encode())  # stop_session
s.close()
```

## Command table

| msg_id | Command | Request JSON | Notes |
|--------|---------|-------------|-------|
| 257 | start_session | `{"token":0,"msg_id":257}` | Returns token in `param` |
| 258 | stop_session | `{"token":T,"msg_id":258}` | Ends session, kills RTSP |
| 259 | reset_viewfinder | `{"token":T,"msg_id":259,"param":"none_force"}` | Starts RTSP pipeline |
| 260 | stop_viewfinder | `{"token":T,"msg_id":260}` | Stops RTSP |
| 3 | get_all_settings | `{"token":T,"msg_id":3}` | Camera config |
| 11 | get_dev_info | `{"token":T,"msg_id":11}` | Hardware/firmware info |
| 13 | get_battery | `{"token":T,"msg_id":13}` | Camera module battery |
| 5 | get_space | `{"token":T,"msg_id":5,"type":"free"}` | SD card free space |
| 6 | get_num_files | `{"token":T,"msg_id":6,"type":"total"}` | File count |
| 769 | take_photo | `{"token":T,"msg_id":769}` | Capture still |
| 513 | start_record | `{"token":T,"msg_id":513}` | Start video recording |
| 514 | stop_record | `{"token":T,"msg_id":514}` | Stop video recording |
| 1282 | list_dir | `{"token":T,"msg_id":1282,"param":"/DCIM -D -S"}` | List SD card files |
| 1539 | get_wifi_settings | `{"token":T,"msg_id":1539}` | WiFi config |

## Error codes (rval)

| rval | Meaning |
|------|---------|
| 0 | OK |
| -1 | UNKNOWN |
| -3 | SESSION_START_FAIL |
| -4 | INVALID_TOKEN |
| -14 | INVALID_OPERATION |
| -17 | NO_MORE_SPACE |

## Device info (msg_id=11)

```json
{
  "brand": "ambarella",
  "model": "ambarella",
  "chip": "A12",
  "app_type": "Connected",
  "fw_ver": "local",
  "api_ver": "4.1.0",
  "media_folder": "/tmp/SD0/AMBA"
}
```

## Camera settings (msg_id=3, selected fields)

- `video_resolution`: 3840x2160 25P 16:9 (4K)
- `video_quality`: sfine
- `capture_mode`: burst quality cont.
- `photo_size`: 12M
- `wb`: auto
- `meter`: center
- `antiflicker`: AUTO

## RTSP stream

URL: `rtsp://192.168.1.100/live`  
Resolution: 1280×720 (viewfinder), 4K in recording mode

**Condition**: viewfinder (msg_id=259) must be active AND TCP socket on 7878 must remain open.

```python
import cv2
cap = cv2.VideoCapture('rtsp://192.168.1.100/live')
ret, frame = cap.read()   # frame.shape = (720, 1280, 3)
```

## One-client limit

The daemon accepts only one session at a time. If the Vision+ app on the tablet has an active session, the daemon will accept your TCP connection but never respond to the JSON. Close the app first.

Confirmed via strace on the device:
```
accept(4, {sin_addr="192.168.1.14"}) = 8   ← connection accepted (no IP filter!)
read(8, '{"token":0,"msg_id":257}', 1024)  ← our JSON is read
send(6, ..., 1140)                          ← forwarded to RTOS via IPC
read(8, ...) = -1 ECONNRESET               ← our connection closed too early!
```

## Data channel (8787)

Port 8787 is the data channel. It streams raw MJPEG frames (JPEG markers: `FF D8 ... FF D9`). Can be read independently without a JSON session, but content may be empty without an active viewfinder.
