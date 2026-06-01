# MAVLink Protocol — PowerRay FCU

## Connection

- **Target**: `192.168.1.12:20002` TCP
- **MAVLink version**: v1 (STX = 0xFE)
- **FCU sysid**: 2
- **Autopilot type**: 0x0C (ArduPilot)
- **Vehicle type**: 0x02 (QUADROTOR — used even for submarine)
- **GCS identity**: sysid=255, compid=190
- **Authentication**: none

## Broadcast messages (~50 Hz, no auth required)

| msg_id | Name | Content |
|--------|------|---------|
| 0 | HEARTBEAT | base_mode, custom_mode, system_status |
| 1 | SYS_STATUS | voltage_battery (mV), current_battery (cA), battery_remaining (%) |
| 30 | ATTITUDE | roll, pitch, yaw (radians) |
| 32 | LOCAL_POSITION_NED | x, y, z, vx, vy, vz (meters, NED frame) |
| 69 | MANUAL_CONTROL | echo of last received control inputs |
| 74 | VFR_HUD | airspeed, groundspeed, heading, throttle, alt |
| 105 | HIGHRES_IMU | accel, gyro, mag (m/s², rad/s, gauss) |
| 140 | ACTUATOR_CONTROL_TARGET | actuator outputs |
| 141 | ALTITUDE | various altitude references |
| 147 | BATTERY_STATUS | detailed battery info |
| 150 | SENSOR_OFFSETS | — |
| 155 | MEMINFO | — |
| 251 | NAMED_VALUE_FLOAT | named float values (PV_* namespace) |

## Depth calculation

Depth = `-LOCAL_POSITION_NED.z` (NED z is negative downward, submarine is underwater)

## Flight modes (custom_mode values)

| custom_mode | Name |
|-------------|------|
| 0 | STABILIZE |
| 1 | ACRO |
| 2 | ALT_HOLD |
| 3 | AUTO |
| 4 | GUIDED |
| 7 | CIRCLE |
| 9 | SURFACE |
| 16 | POSHOLD |
| 19 | MANUAL |

`base_mode & 0x80` = armed flag

## Control sequence

```python
import socket, time
from pymavlink import mavutil

m = mavutil.mavlink_connection('tcp:192.168.1.12:20002', source_system=255)
m.wait_heartbeat()

# 1. Send periodic GCS heartbeat (required to maintain control authority)
m.mav.heartbeat_send(
    mavutil.mavlink.MAV_TYPE_GCS,
    mavutil.mavlink.MAV_AUTOPILOT_INVALID, 0, 0, 0)

# 2. Set mode
m.mav.set_mode_send(m.target_system, 1, 19)  # 19=MANUAL

# 3. ARM
m.mav.command_long_send(
    m.target_system, m.target_component,
    mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
    0, 1.0, 0, 0, 0, 0, 0, 0)

# 4. Manual control (x/y/z/r all in range -1000..1000)
# x=pitch, y=roll, z=throttle (500=neutral), r=yaw
m.mav.manual_control_send(m.target_system, 0, 0, 500, 0, 0)
```

## MAVLink CRC extras (v1)

| msg_id | crc_extra |
|--------|-----------|
| 0 (HEARTBEAT) | 50 |
| 11 (SET_MODE) | 89 |
| 69 (MANUAL_CONTROL) | 243 |
| 76 (COMMAND_LONG) | 152 |

## PX4 parameters

358 parameters retrieved via PARAM_REQUEST_LIST. Notable ones:
- `PV_V_FISHING` — fishing mode flag
- `PV_INTOWATER` = 1 — indicates submarine is deployed
- `PV_SD_SIZE` = 7.35GB — SD card size
- `BAT_V_EMPTY` = 3.4V — cell empty voltage
- `PV_*` namespace — PowerVision custom parameters

Retrieve all with: `GET /params` (web UI) or `mav.mav.param_request_list_send(...)`
