#!/usr/bin/env python3
"""Smoke test the PowerRay web UI against the fake MAVLink controller."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB_UI = ROOT / "web-ui"
FAKE_FC = WEB_UI / "tools" / "fake_fc.py"
SERVER = WEB_UI / "server.py"
HOST = "127.0.0.1"
FCU_PORT = 20002
BASE_URL = "http://localhost:5000"


class SmokeFailure(AssertionError):
    pass


def fail(message: str) -> None:
    raise SmokeFailure(message)


def request(method: str, path: str, payload: dict | None = None, timeout: float = 3.0):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
        ctype = resp.headers.get("Content-Type", "")
        if resp.status != 200:
            fail(f"{method} {path} returned HTTP {resp.status}: {body[:200]!r}")
        if "application/json" in ctype:
            return json.loads(body.decode("utf-8"))
        return body.decode("utf-8", errors="replace")


def wait_for_http(timeout: float = 15.0) -> None:
    deadline = time.time() + timeout
    last_error = None
    while time.time() < deadline:
        try:
            request("GET", "/")
            return
        except Exception as exc:  # server may not be listening yet
            last_error = exc
            time.sleep(0.25)
    fail(f"GET / did not become ready within {timeout}s: {last_error}")


def wait_for_state(predicate, description: str, timeout: float = 15.0) -> dict:
    deadline = time.time() + timeout
    last_state = None
    last_error = None
    while time.time() < deadline:
        try:
            last_state = request("GET", "/state")
            if predicate(last_state):
                return last_state
        except Exception as exc:
            last_error = exc
        time.sleep(0.25)
    fail(f"Timed out waiting for {description}; last_state={last_state!r}; last_error={last_error}")


def terminate(proc: subprocess.Popen, name: str) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)
    print(f"[TEST] stopped {name}")


def start_processes() -> tuple[subprocess.Popen, subprocess.Popen]:
    py = sys.executable
    fake = subprocess.Popen(
        [py, str(FAKE_FC), "--host", HOST, "--port", str(FCU_PORT)],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    time.sleep(0.75)
    if fake.poll() is not None:
        out = fake.stdout.read() if fake.stdout else ""
        fail(f"fake_fc.py exited early with {fake.returncode}:\n{out}")

    env = os.environ.copy()
    env.update({"FCU_IP": HOST, "FCU_PORT": str(FCU_PORT), "PYTHONUNBUFFERED": "1"})
    server = subprocess.Popen(
        [py, str(SERVER)],
        cwd=str(WEB_UI),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    return fake, server


def main() -> int:
    fake = server = None
    try:
        fake, server = start_processes()
        print("[TEST] waiting for Flask server")
        wait_for_http()
        print("[TEST] waiting for MAVLink connection")
        state = wait_for_state(lambda s: s.get("mav_connected") is True, "mav_connected true")
        print(f"[TEST] connected: mode={state.get('mode')} armed={state.get('armed')}")

        first = wait_for_state(
            lambda s: isinstance(s.get("heading"), int) and s.get("battery_pct") not in (None, 0),
            "heading and battery telemetry",
        )
        second = wait_for_state(lambda s: s.get("heading") != first.get("heading"), "changing heading", timeout=8.0)
        if second.get("battery_pct") is None:
            fail(f"battery_pct missing from /state: {second!r}")

        html = request("GET", "/")
        if "/static/socket.io.min.js" not in html:
            fail("GET / HTML does not reference /static/socket.io.min.js")
        if "cdn." in html.lower():
            fail("GET / HTML contains 'cdn.'; offline Socket.IO check failed")

        request("POST", "/arm", {"arm": True})
        wait_for_state(lambda s: s.get("armed") is True, "armed true")
        request("POST", "/arm", {"arm": False})
        wait_for_state(lambda s: s.get("armed") is False, "armed false")

        request("POST", "/mode", {"mode": "ALT_HOLD"})
        wait_for_state(lambda s: s.get("mode") == "ALT_HOLD", "mode ALT_HOLD")

        request("POST", "/surface", {})
        surf = wait_for_state(
            lambda s: s.get("mode") == "SURFACE" and s.get("armed") is True,
            "surface mode and armed true",
        )
        print(f"[TEST] surface state: mode={surf.get('mode')} armed={surf.get('armed')}")

        request("POST", "/control", {"x": 300, "y": 0, "z": 500, "r": 0})

        print("ALL TESTS PASSED")
        return 0
    except SmokeFailure as exc:
        print(f"TEST FAILED: {exc}", file=sys.stderr)
        return 1
    except urllib.error.HTTPError as exc:
        print(f"TEST FAILED: HTTP {exc.code} {exc.reason}: {exc.read()[:500]!r}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"TEST FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    finally:
        if server is not None:
            terminate(server, "server.py")
        if fake is not None:
            terminate(fake, "fake_fc.py")


if __name__ == "__main__":
    raise SystemExit(main())
