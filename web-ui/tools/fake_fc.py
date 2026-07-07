#!/usr/bin/env python3
"""Standalone MAVLink flight-controller simulator for the PowerRay web UI."""
from __future__ import annotations

import argparse
import math
import os
import sys
import time
from dataclasses import dataclass, field

from pymavlink import mavutil

# Keep the simulator aligned with the real PowerRay FCU link.
os.environ.setdefault("MAVLINK20", "0")

MAV_TYPE_QUADROTOR = mavutil.mavlink.MAV_TYPE_QUADROTOR
MAV_AUTOPILOT_ARDUPILOTMEGA = mavutil.mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA
MAV_STATE_ACTIVE = mavutil.mavlink.MAV_STATE_ACTIVE
MAV_RESULT_ACCEPTED = mavutil.mavlink.MAV_RESULT_ACCEPTED
MAV_CMD_COMPONENT_ARM_DISARM = mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM
MAV_PARAM_TYPE_REAL32 = mavutil.mavlink.MAV_PARAM_TYPE_REAL32

MODE_NAMES = {
    0: "STABILIZE", 1: "ACRO", 2: "ALT_HOLD", 3: "AUTO", 4: "GUIDED",
    7: "CIRCLE", 9: "SURFACE", 16: "POSHOLD", 19: "MANUAL",
}

PARAMS = [
    ("PV_INTOWATER", 1.0),
    ("BAT_V_EMPTY", 3.4),
    ("BAT_V_FULL", 4.2),
    ("FS_GCS_ENABLE", 0.0),
    ("SURFACE_MODE", 9.0),
]


@dataclass
class SimState:
    armed: bool = False
    mode: int = 19
    roll: float = 0.0
    pitch: float = 0.0
    yaw: float = 0.0
    heading: int = 0
    depth: float = 0.0
    x: float = 0.0
    y: float = 0.0
    vx: float = 0.0
    vy: float = 0.0
    vz: float = 0.0
    battery_remaining: int = 78
    voltage_mv: int = 15800
    current_ca: int = 1200
    manual_x: int = 0
    manual_y: int = 0
    manual_z: int = 500
    manual_r: int = 0
    boot_time: float = field(default_factory=time.monotonic)
    last_update: float = field(default_factory=time.monotonic)

    def update(self) -> None:
        now = time.monotonic()
        dt = max(0.0, min(now - self.last_update, 0.25))
        self.last_update = now
        t = now - self.boot_time

        yaw_rate = 0.08 + (self.manual_r / 1000.0) * 0.55
        self.yaw = (self.yaw + yaw_rate * dt) % (2 * math.pi)
        self.heading = int(math.degrees(self.yaw)) % 360

        self.roll = math.radians(3.0) * math.sin(t * 0.8) + (self.manual_y / 1000.0) * math.radians(5.0)
        self.pitch = math.radians(2.0) * math.cos(t * 0.6) + (self.manual_x / 1000.0) * math.radians(4.0)

        forward = (self.manual_x / 1000.0) * 0.8
        strafe = (self.manual_y / 1000.0) * 0.25
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        self.vx = forward * cy - strafe * sy
        self.vy = forward * sy + strafe * cy
        self.x += self.vx * dt
        self.y += self.vy * dt

        # z is NED, so positive vertical velocity increases depth.
        climb_cmd = (self.manual_z - 500) / 500.0
        self.vz = max(-0.25, min(0.25, climb_cmd * 0.18))
        self.depth = max(0.0, min(30.0, self.depth + self.vz * dt))

    @property
    def time_boot_ms(self) -> int:
        return int((time.monotonic() - self.boot_time) * 1000) & 0xFFFFFFFF

    @property
    def groundspeed(self) -> float:
        return math.hypot(self.vx, self.vy)


def send_telemetry(conn: mavutil.mavfile, state: SimState) -> None:
    base_mode = 0x80 if state.armed else 0
    conn.mav.heartbeat_send(
        MAV_TYPE_QUADROTOR,
        MAV_AUTOPILOT_ARDUPILOTMEGA,
        base_mode,
        state.mode,
        MAV_STATE_ACTIVE,
    )
    conn.mav.attitude_send(
        state.time_boot_ms,
        state.roll,
        state.pitch,
        state.yaw,
        0.0,
        0.0,
        0.08 + (state.manual_r / 1000.0) * 0.55,
    )
    conn.mav.sys_status_send(
        0, 0, 0, 500,
        state.voltage_mv,
        state.current_ca,
        state.battery_remaining,
        0, 0, 0, 0, 0, 0,
    )
    conn.mav.local_position_ned_send(
        state.time_boot_ms,
        state.x,
        state.y,
        -state.depth,
        state.vx,
        state.vy,
        -state.vz,
    )
    conn.mav.vfr_hud_send(
        state.groundspeed,
        state.groundspeed,
        state.heading,
        int(max(0, min(100, state.manual_z / 10))),
        -state.depth,
        -state.vz,
    )


def send_params(conn: mavutil.mavfile) -> None:
    count = len(PARAMS)
    for idx, (name, value) in enumerate(PARAMS):
        conn.mav.param_value_send(
            name.encode("ascii"),
            float(value),
            MAV_PARAM_TYPE_REAL32,
            count,
            idx,
        )
        time.sleep(0.02)


def handle_message(conn: mavutil.mavfile, state: SimState, msg) -> None:
    mtype = msg.get_type()
    if mtype == "BAD_DATA":
        return

    if mtype == "COMMAND_LONG" and int(msg.command) == MAV_CMD_COMPONENT_ARM_DISARM:
        state.armed = float(msg.param1) == 1.0
        print(f"[FC] {'ARMED' if state.armed else 'DISARMED'}", flush=True)
        conn.mav.command_ack_send(MAV_CMD_COMPONENT_ARM_DISARM, MAV_RESULT_ACCEPTED)

    elif mtype == "SET_MODE":
        state.mode = int(msg.custom_mode)
        print(f"[FC] MODE {MODE_NAMES.get(state.mode, state.mode)} ({state.mode})", flush=True)

    elif mtype == "MANUAL_CONTROL":
        state.manual_x = int(msg.x)
        state.manual_y = int(msg.y)
        state.manual_z = int(msg.z)
        state.manual_r = int(msg.r)
        print(
            f"[FC] MANUAL x={state.manual_x} y={state.manual_y} "
            f"z={state.manual_z} r={state.manual_r}",
            flush=True,
        )

    elif mtype == "PARAM_REQUEST_LIST":
        print("[FC] PARAM_REQUEST_LIST", flush=True)
        send_params(conn)

    elif mtype == "PARAM_SET":
        param_id = getattr(msg, "param_id", b"")
        if isinstance(param_id, bytes):
            param_name = param_id.decode("ascii", errors="ignore").rstrip("\x00")
        else:
            param_name = str(param_id).rstrip("\x00")
        value = float(msg.param_value)
        print(f"[FC] PARAM_SET {param_name}={value:g}", flush=True)
        conn.mav.param_value_send(
            param_name.encode("ascii")[:16],
            value,
            int(getattr(msg, "param_type", MAV_PARAM_TYPE_REAL32)),
            len(PARAMS),
            -1,
        )


def run_server(host: str, port: int) -> None:
    endpoint = f"tcpin:{host}:{port}"
    print(f"[FC] Listening on {host}:{port}", flush=True)
    while True:
        conn = None
        try:
            # tcpin: blocks here until the GCS connects.
            conn = mavutil.mavlink_connection(
                endpoint,
                source_system=2,
                source_component=1,
                dialect="ardupilotmega",
                autoreconnect=False,
            )
            state = SimState()
            print("[FC] GCS connected", flush=True)
            next_telem = 0.0
            next_status = time.monotonic() + 5.0

            while True:
                now = time.monotonic()
                state.update()

                msg = conn.recv_match(blocking=False)
                while msg is not None:
                    handle_message(conn, state, msg)
                    msg = conn.recv_match(blocking=False)

                if now >= next_telem:
                    send_telemetry(conn, state)
                    next_telem = now + 0.1

                if now >= next_status:
                    print(
                        f"[FC] telem mode={MODE_NAMES.get(state.mode, state.mode)} "
                        f"armed={state.armed} hdg={state.heading} depth={state.depth:.1f}m",
                        flush=True,
                    )
                    next_status = now + 5.0

                time.sleep(0.01)

        except KeyboardInterrupt:
            print("[FC] Stopped", flush=True)
            return
        except Exception as exc:
            print(f"[FC] Connection closed: {exc}", flush=True)
            time.sleep(1.0)
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass
            print("[FC] Waiting for GCS...", flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fake PowerRay MAVLink flight controller")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=20002)
    args = parser.parse_args(argv)
    run_server(args.host, args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
