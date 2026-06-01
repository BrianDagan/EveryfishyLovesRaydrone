# LEGAL CHECK — erebus-powerray

**Date**: 2026-06-01  
**Verdict**: ✅ CLEAN — safe to publish under MIT license

---

## 1. Code included in this repo

| File | Origin | Contains proprietary code? |
|------|--------|---------------------------|
| `web-ui/server.py` | Written from scratch | No |
| `web-ui/templates/index.html` | Written from scratch | No |
| `web-ui/templates/sonar.html` | Written from scratch | No |
| `scripts/powerray_telemetry.ps1` | Written from scratch | No |
| `scripts/powerray_cam.ps1` | Written from scratch | No |
| `scripts/powerray_connect.ps1` | Written from scratch | No |
| `scripts/*.ps1` (all) | Written from scratch | No |
| `docs/*.md` | Our own protocol documentation | No |

**Not included** (never will be):
- `vision_1.6.6.apk` — PowerVision proprietary binary
- JADX decompiled Java source code — PowerVision copyrighted code
- Device firmware, certificates, or cryptographic keys

---

## 2. Reverse engineering — EU Directive 2009/24/EC

EU Software Directive 2009/24/EC, Article 6 explicitly authorises reverse engineering for interoperability:

> "The authorisation of the rightholder shall not be required where reproduction of the code and translation of its form are indispensable to obtain the information necessary to achieve the interoperability of an independently created computer program."

Conditions required — all satisfied here:

| Condition | Status |
|-----------|--------|
| Lawfully entitled to use the program | ✅ We own the device |
| Information not previously available | ✅ PowerVision publishes no API docs |
| Confined to parts necessary for interoperability | ✅ Only network protocol parameters documented |
| Not used to create a substantially similar product | ✅ We built a GCS tool, not a competing submarine |

**France implementation**: Article L122-6-1 du Code de la Propriété Intellectuelle (CPI) — same conditions apply.

### What was reverse engineered

| Protocol | Method | Legal basis |
|----------|--------|-------------|
| MAVLink on TCP:20002 | Network observation | MAVLink is a public open-source standard (BSD-3) |
| Ambarella JSON API (7878) | APK analysis + network observation | Interoperability (2009/24/EC Art.6) |
| Sonar binary format (AA55) | APK analysis | Interoperability (2009/24/EC Art.6) |
| Telnet root shell | Port scan on own device | Access to own hardware, no security bypass |

---

## 3. Protocol facts are not copyrightable

Protocol interfaces — message IDs, JSON keys, binary frame formats — are **functional facts**, not creative expression. EU copyright law (Infopaq, FAPL, Football Dataco line of cases) consistently holds that facts and functional elements are outside copyright scope.

The JSON `{"token":0,"msg_id":257}` format is a fact discovered by observation, not a creative work.

---

## 4. Root shell access

The Ambarella A12 module runs `telnetd` with root login and no password. This is a manufacturer design choice on a device we own. Accessing our own hardware via an unprotected service is not "unauthorised access" (France: Article 323-1 CP requires "fraudulent" access — accessing a service with no authentication on your own device does not qualify).

---

## 5. Trademark / branding

- We use "PowerVision" and "PowerRay" as factual product names only (referential use)
- Project name "erebus" is not derived from PowerVision trademarks
- No logo, trade dress, or proprietary branding reproduced
- Disclaimer included in README: not affiliated with PowerVision

---

## 6. Third-party dependencies (our code)

| Dependency | License | Concern? |
|------------|---------|----------|
| Flask | BSD-3 | No |
| Flask-SocketIO | MIT | No |
| pymavlink | LGPL-3 / Apache | No (dynamic link, compatible) |
| OpenCV (cv2) | Apache-2 | No |
| socket.io.js (CDN) | MIT | No |
| MAVLink protocol | MIT/BSD | No |

---

## 7. Verdict

**CLEAN to publish.**

Recommended disclaimer in README (already included):
> This project is not affiliated with or endorsed by PowerVision. PowerVision® and PowerRay® are trademarks of PowerVision Technology Group. Use at your own risk.

**MIT license** is appropriate for all original code in this repository.
