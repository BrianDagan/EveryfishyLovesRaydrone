# PowerRay Field Guide 🐟

*The manual past-you wrote so future-you can put the sub in the water, drive it,
and — most importantly — **get it back** — without re-learning anything.*

Read section 1 once. Skim the checklists (2 & 3) every time you go out. Everything
else is here for when something goes sideways.

> **The single most important idea:** this drone has **no GPS**. The map does not
> know where the sub *really* is — it *estimates* position by adding up movement
> from a **Home** point you set at launch. That estimate **drifts**. So the map and
> Return-to-Home are *aids for you, the pilot* — not an autopilot. Your real
> safety net is the **floating base-station buoy and its tether**. Keep runs
> conservative and you'll always get it home.

---

## Table of contents

1. [How "knowing where you are" actually works (read this)](#1-how-knowing-where-you-are-actually-works)
2. [Before you leave home — checklist (needs internet)](#2-before-you-leave-home--checklist-needs-internet)
3. [At the water — step by step](#3-at-the-water--step-by-step)
4. [Driving controls](#4-driving-controls)
5. [Getting home (the main event)](#5-getting-home-the-main-event)
6. [Emergencies](#6-emergencies)
7. [Troubleshooting](#7-troubleshooting)
8. [Testing on the bench (no drone needed)](#8-testing-on-the-bench-no-drone-needed)
9. [Quick reference card](#9-quick-reference-card)

---

## 1. How "knowing where you are" actually works

The PowerRay has **no GPS** (radio doesn't travel through water anyway). Here's the
chain that puts a dot on the map:

- The flight controller reports **local motion** in metres — `LOCAL_POSITION_NED`
  (north/east/down from where it powered on) plus a **heading** (`VFR_HUD`/yaw).
- When you click **Set Home Here**, the cockpit records *"the drone's current
  metres = this spot on the map."*
- After that, every position update is drawn as **Home + how far it has moved**.
  The **arrow** shows which way it's pointing; a fading **track line** shows where
  it's been.

**Why this matters — drift:** dead reckoning accumulates error. Currents, yaw
wobble, and the lack of any absolute fix mean the map dot slowly wanders from
reality — the longer and farther you drive, the more it lies. Treat distances as
*approximate* and always keep the physical buoy in sight.

**Your three ways home, in order of trust:**

1. 👀 **Eyeball the buoy.** The base station floats on the surface roughly above the
   sub and is joined to it by the **tether**. That tether is your ultimate recovery
   line — you can literally reel the drone in. Note which way it pays out.
2. 🧭 **Return-to-Home guidance** (section 5) — bearing + distance back to Home to
   steer by.
3. 🆘 **Emergency Surface** (section 6) — pop to the top, then find the buoy.

---

## 2. Before you leave home — checklist (needs internet)

Do these **while you still have Wi-Fi**. The map tiles in particular **cannot** be
downloaded at the water.

- [ ] **Dependencies installed** (one-time): from the repo root,
      `pip install -r web-ui/requirements.txt`
- [ ] **Pre-cache the satellite map for your launch spot** (see below). Without
      this the map is blank grey at the lake.
- [ ] **Battery charged** on the drone + the base-station buoy.
- [ ] **Know your launch point** — a landmark or coordinates. (In Google Maps,
      right-click your spot → click the `lat, lon` numbers to copy them.)

### Pre-caching the map — two ways

**A. Precise, from a coordinate (recommended).** From the `web-ui` folder, with
internet:

```powershell
cd web-ui
python -c "import tile_cache; print(tile_cache.cache_area(42.6001, -77.0001, 3))"
#                                              ^lat      ^lon   ^radius (miles)
```

It prints something like `{'cached': 812, 'skipped': 0, 'failed': 0, 'total': 812}`
and writes JPEGs into `web-ui/tiles/`. Re-running only fetches what's missing.

**B. Visual, from the UI.** Start the cockpit (`scripts\drive.ps1` or
`python web-ui\server.py`), open <http://localhost:5000>, pan/zoom the **map** to
your spot, then click **Cache Area** (caches ~3 mi around the map centre). Watch the
log for `Cache complete`.

> **Verify it worked:** `web-ui/tiles/` should now contain numbered folders. Those
> tiles are what you'll see offline at the water. (The folder is git-ignored — it's
> your local cache, not part of the repo.)

---

## 3. At the water — step by step

1. **Power up** the drone and the base-station buoy; set the buoy in the water.
2. **Connect your laptop's Wi-Fi** to **`PRA_Station_488057`**.
   *(Expect “no internet” — that's normal. Everything runs offline.)*
3. **Launch the cockpit** — from the repo root:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\drive.ps1
   ```

   This clears any leftover simulator setting, runs a quick network/flight-controller
   preflight, starts the server, and opens the browser for you.
4. **Confirm the link:** the status pill reads **`FCU OK`** (terminal shows
   `[MAV] Connecte sysid=2`). If it says *Disconnected*, see
   [Troubleshooting](#7-troubleshooting).
5. **Camera (optional):** close the **Vision+** app on the tablet first (the camera
   allows only one client), then click **Connect camera**.
6. **① SET HOME — do this before you drive away.** On the map, click
   **Set Home Here**, then click your exact launch point. A `⌂` marker drops and the
   drone arrow appears on it. *This is the anchor everything else measures from — if
   you skip it, the map and RTH can't help you.*
7. **Drive** (section 4). Keep an eye on **depth**, **battery**, and the **track
   line** trailing the arrow.
8. **Come home** (section 5) with room to spare on the battery.
9. **Surface, retrieve the buoy, power down.**

---

## 4. Driving controls

**Arm first.** Click **ARM** (button turns to **DISARM**; badge shows **ARMED**).
Motors are live only when armed.

### Keyboard piloting (WASD)

Turn on **Keyboard Control** (top of the panel). Requires the drone to be **ARMED**
and your cursor **not** in a text box.

| Key | Action | | Key | Action |
|-----|--------|-|-----|--------|
| **W / S** | forward / reverse | | **R / F** | ascend / descend |
| **A / D** | yaw (turn) left / right | | **Shift** (hold) | boost — full throttle |
| **Q / E** | strafe left / right | | **Space** | all-stop (neutral) |

Keys stop sending the instant you release them, and if the window loses focus —
a built-in failsafe so a stuck key can't run the drone away.

### Other ways to drive

- **On-screen joysticks + throttle slider** (mouse/touch) — left = pitch/roll,
  right = yaw.
- **Gamepad** — plug in an Xbox-style controller; sticks map to pitch/roll/yaw and a
  trigger to throttle.
- All three coexist; **last input wins**.

### Modes

Pick from the mode selector. Handy ones:

- **MANUAL** — direct control (default for driving).
- **ALT_HOLD** — *Depth Hold*; the sub holds its current depth. There's a
  **Depth Hold** shortcut button too.
- **SURFACE** — commands the sub to rise (this is what Emergency Surface uses).

---

## 5. Getting home (the main event)

You set **Home** at launch (step 6 above). To come back:

1. Click **RTH Guidance** (it lights up). On the map a dashed line connects the
   drone to Home, and a readout appears:

   > **STEER 214° · 38.6 m to HOME**  ·  *relative turn +72°*

2. **Read it like this:**
   - **STEER 214°** — the compass bearing from the sub back to Home.
   - **38.6 m** — approximate straight-line distance (remember: *approximate*).
   - **relative turn +72°** — how far to turn *from where you're currently
     pointing*. Positive = turn right, negative = turn left. The little arrow points
     the same way.
3. **Turn** (A/D) until the relative turn is near **0°** / the arrow points straight
   up, then drive **forward** (W). Watch the distance count **down** and the track
   line retrace toward Home.
4. As you get close, **surface and look for the buoy** — trust your eyes over the
   last few metres, because that's where drift hurts most.

> **Conservative pilots always get their drone back.** Turn around at **half
> battery**. If the numbers stop making sense, don't chase them — hit **Emergency
> Surface** and go find the buoy. The tether is always there.

---

## 6. Emergencies

| Situation | Do this |
|-----------|---------|
| **Disoriented / lost track of the sub** | Hit **Emergency Surface** (big red button — commands SURFACE + arms if needed). Then find the floating buoy visually. |
| **Runaway / won't stop** | **Space** = all-stop. Still wrong? Click **DISARM** to cut the motors. |
| **Battery getting low** | Head home now (section 5) or **Emergency Surface**; don't wait for empty. |
| **Video froze / control feels laggy** | Video and control are independent — a frozen image doesn't mean you've lost control. Check the **`FCU OK`** pill; reload video with **↻ Video**. |
| **Totally lost the link** | Walk toward the buoy, reel in the **tether**. The drone can't go farther than the tether allows. |

**Emergency Surface** is also on the network as `POST /surface` if you ever script it.

---

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| UI says **Disconnected**, buttons dead, **but video works** | The realtime channel (Socket.IO) didn't load — classically a CDN script that can't load offline | **Hard-refresh (Ctrl+F5).** Confirm `web-ui/static/socket.io.min.js` exists. **Never** point any `<script>` at a CDN — the lake has no internet. |
| **`FCU Off` / no telemetry at all** | Wrong Wi-Fi, sub not powered, or a stale `FCU_IP` from bench testing | Join **`PRA_Station_488057`**; power the sub; **use `scripts\drive.ps1`** (it clears `FCU_IP`). Or run `scripts\interrogate_base_station.ps1` and look for `:20002 OPEN`. |
| **Map is blank grey** | Tiles for this area were never cached | Pre-cache **at home with internet** (section 2). Offline, only cached areas show. |
| **Camera won't connect** ("feed unavailable") | The **Vision+** app is still holding the camera (one client only) | Close Vision+ on the tablet, then **Connect camera**. |
| **Drone dot drifts / ends up on land** | Normal dead-reckoning drift (no GPS) | Re-**Set Home** after surfacing; keep runs shorter; trust the buoy over the dot. |
| **Set Home / RTH do nothing** | Home not set, or no position yet from the sub | Confirm **`FCU OK`**, then **Set Home Here** → click the map. |
| **Browser won't open / port busy** | Another server already running on :5000 | Close the old terminal, or find the process: `Get-NetTCPConnection -LocalPort 5000`. |

---

## 8. Testing on the bench (no drone needed)

You can exercise the entire cockpit at your desk with a simulated flight controller.

```powershell
# Terminal 1 — the fake PowerRay flight controller:
python web-ui\tools\fake_fc.py

# Terminal 2 — point the server at the simulator (fresh terminal):
$env:FCU_IP='127.0.0.1'; python web-ui\server.py
# then open http://localhost:5000
```

One-shot automated check (starts both, asserts the whole contract, cleans up):

```powershell
python web-ui\tools\test_webui.py      # prints ALL TESTS PASSED
```

> Because `drive.ps1` **clears** `FCU_IP`, always use a **fresh terminal** (or
> `drive.ps1`) when you switch back from the simulator to the real drone — otherwise
> a leftover `FCU_IP=127.0.0.1` will send you to the sim.

---

## 9. Quick reference card

**Network**

| Thing | Value |
|-------|-------|
| Wi-Fi AP (SSID) | `PRA_Station_488057` |
| Base-station buoy | `192.168.1.11` |
| Flight controller | `192.168.1.12:20002` (MAVLink) — *driveable when this is open* |
| Camera | `192.168.1.100` (`7878` API, `554` RTSP) |
| Cockpit URL | <http://localhost:5000> |

**Commands** (from the repo root)

| Command | What it does |
|---------|--------------|
| `powershell -ExecutionPolicy Bypass -File .\scripts\drive.ps1` | Preflight + launch + open browser (**the easy button**) |
| `powershell -ExecutionPolicy Bypass -File .\scripts\interrogate_base_station.ps1` | Recon: find the gateway, scan devices, grab banners |
| `cd web-ui; python -u server.py` | Start the cockpit manually |
| `python -c "import tile_cache; tile_cache.cache_area(LAT, LON, 3)"` | Pre-cache the map (run inside `web-ui`, online) |

**Pre-launch, every time:** ✅ map pre-cached · ✅ batteries charged · ✅ on
`PRA_Station_488057` · ✅ `FCU OK` · ✅ **Set Home** · ✅ turn back at half battery.

**Keymap:** `W/S` fwd·rev · `A/D` yaw · `Q/E` strafe · `R/F` up·down ·
`Shift` boost · `Space` all-stop.

---

*Fair winds and following seas, future me. Go get 'em.* 🐟
