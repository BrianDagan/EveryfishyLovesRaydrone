# erebus-io-powerray

A Python + PowerShell toolkit for controlling the **PowerVision PowerRay** underwater drone without the official Vision+ Android app.

This is personal reverse engineering / maker work. We own the submarine, we documented what it speaks, we built a web UI to talk to it. Nothing fancy, just curiosity and a soldering iron mindset applied to TCP packets.

> **Disclaimer**: Not affiliated with or endorsed by PowerVision. PowerVision® and PowerRay® are trademarks of PowerVision Technology Group. Use at your own risk.

---

## What's working

| Feature | Status |
|---------|--------|
| MAVLink telemetry (50 Hz) | ✅ Fully working |
| Navigation control (ARM / SET_MODE / joystick) | ✅ Fully working |
| 358 PX4 parameter read + write | ✅ Fully working |
| Ambarella camera JSON API | ✅ Fully working (token/session) |
| RTSP live video in browser | ✅ Working (requires camera session open) |
| Sonar binary protocol | 📖 Documented, port currently closed |
| PSE fishfinder sonar | 🔧 Partially — TCP banner, UDP not captured yet |
| RC PRASC10 remote control | ❓ Unknown UDP protocol |

---

## Network map

The PowerRay creates a WiFi AP. The SSID varies by unit/firmware — stock is
`PRA_Station_xxxxxx`; **this unit is `PRA_Station_488057`** (a stock PRA unit, so
its base station should sit at the usual `192.168.1.11` — but run
`scripts\interrogate_base_station.ps1` first to auto-detect the gateway). Once
connected:

| IP | Role | Key ports |
|----|------|-----------|
| 192.168.1.11 | Base station (HLK-RM08K WiFi module) | 8080 (MAVLink broadcast), 80 (HTTP) |
| 192.168.1.12 | Flight controller (PX4 custom) | **20002 TCP** — MAVLink v1 |
| 192.168.1.100 | Camera module (Ambarella A12) | **7878** JSON API, **554** RTSP, **80** HTTP, **23** Telnet |
| 192.168.1.103 | RC controller PRASC10 | UDP (unknown) |

---

## Running it (future-you field guide)

> Written so that a year from now you can get the sub driving again in ~5 minutes
> without re-reverse-engineering anything.

### 0. One-time setup (needs internet)

```bash
pip install -r web-ui/requirements.txt
# or: pip install flask flask-socketio pymavlink opencv-python
```

Everything the browser needs (including the Socket.IO client) is vendored in this
repo, so after this step the whole thing runs **fully offline**.

### 1. Power on & join the drone's WiFi

Turn on the PowerRay + its base station, then connect this PC's WiFi to the base
station AP — **`PRA_Station_488057`** (stock PowerRay APs are `PRA_Station_xxxxxx`).

> ⚠️ This AP has **no internet**. You *will* lose connectivity while connected —
> that's expected. The control UI is built to work with zero internet.

### 2. Sanity-check the network (optional but recommended)

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\interrogate_base_station.ps1
```

You're looking for **`:20002 OPEN`** on `192.168.1.12` — that's the flight
controller, and its presence means the sub is driveable. The gateway it prints
(usually `192.168.1.11`) is the base station.

### 3. Free the camera (only if you want video)

Close the PowerVision **Vision+** app on the tablet/phone. The camera (Ambarella)
only allows **one** client at a time, so the app and this UI fight over it.

### 4. Start the server & open the UI

```bash
cd web-ui
python -u server.py
```

Open **http://localhost:5000**, then **hard-refresh once (Ctrl+F5)** to be sure
you're on the latest page. Watch the terminal for `[MAV] Connecte sysid=…` — that
confirms the flight-controller link is up. The status pill should read **`FCU OK`**
and ARM / mode / joystick will respond.

---

### 🛟 Gotcha: UI says "Disconnected" (buttons dead) but video works fine

This is the one failure mode worth remembering. It means the browser's realtime
channel (**Socket.IO**) didn't connect, so telemetry never arrives and the control
buttons (ARM / mode / joystick — they send over the socket) do nothing, *while* the
video keeps working because it's a plain MJPEG `<img>` that needs no JavaScript.

**Cause:** something made the Socket.IO **client script** fail to load. The classic
trigger is loading it from a CDN, which is unreachable on the drone's offline AP.

**Fix / prevention:**

- The client is vendored at **`web-ui/static/socket.io.min.js`** and loaded via
  `/static/…` in `index.html` — **never** re-point it at `cdn.socket.io` or any CDN.
- If it happens anyway: **hard-refresh (Ctrl+F5)** to drop a cached page, and
  confirm `web-ui/static/socket.io.min.js` still exists.
- If the terminal shows `[MAV] Connecte sysid=…`, the drone link is fine and the
  problem is 100% browser-side.

**Golden rule:** everything the browser loads must be local. No CDNs, ever — the
lake has no WiFi.

---

## Web UI features

- **Attitude indicator** — animated artificial horizon (roll/pitch)
- **Compass** — rotating, driven by live MAVLink yaw
- **Battery** — voltage, current, percentage with color bar
- **Navigation control** — ARM/DISARM, mode selector, dual joystick (mouse + Gamepad API)
- **Camera** — connect, photo, record, viewfinder toggle
- **Live video** — RTSP → OpenCV → MJPEG relay in the browser
- **Parameters** — search + live SET for all 358 PX4 params
- **Sonar UI** — at `/sonar_ui`, with waterfall canvas and demo mode

---

## PowerShell scripts

Quick scripts for testing without the full UI:

| Script | What it does |
|--------|-------------|
| `interrogate_base_station.ps1` | **Start here** — auto-detects the AP/gateway (the base station), scans it + all known device IPs, and grabs banners |
| `powerray_telemetry.ps1` | Decode and print MAVLink stream |
| `powerray_cam.ps1` | Test camera JSON API (7878) |
| `powerray_connect.ps1` | Basic TCP connection test |
| `ray_ctrl.ps1` | MAVLink control sequence test |
| `scan_powerray.ps1` | Quick fixed-IP port scan of the submarine |

---

## Protocol docs

See [`docs/`](docs/) for detailed protocol documentation:

- [`mavlink-protocol.md`](docs/mavlink-protocol.md) — MAVLink messages, control sequence, modes
- [`camera-json-api.md`](docs/camera-json-api.md) — Ambarella JSON commands (msg_id table)
- [`sonar-protocol.md`](docs/sonar-protocol.md) — Binary sonar frame format
- [`hardware.md`](docs/hardware.md) — Hardware internals, process list, filesystem
- [`network-map.md`](docs/network-map.md) — Full network map with port status

---

## Legal

See [LEGAL_CHECK.md](LEGAL_CHECK.md) for the full legal analysis.

Short version: all code in this repo is original. Protocol documentation is factual/functional (not copyrightable). Reverse engineering for interoperability is explicitly permitted under EU Directive 2009/24/EC Article 6, implemented in France as Article L122-6-1 CPI.

---

## License

MIT — see [LICENSE](LICENSE).
