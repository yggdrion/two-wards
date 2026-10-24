"""Headless network test.

For every scenario in game/tests/scenarios, starts a host and a client Godot over ENet on
localhost (game/tools/net_test.gd), plays the scenario as co-op and fails on any per-wave state
hash mismatch, failed host command on the client, or timeout. Then plays one co-op scenario
over WebRTC through a local lobby (lobby/, needs bun; skipped without bun except in CI).

Usage: python tools/run_network_test.py [scenario.json ...]   (names inside game/tests/scenarios)
Set GODOT_BIN to use your own binary; it must match .godot-version.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

from _common import GAME, ROOT, fail, godot, godot_import

WEBRTC_SCENARIO = "coop_two_wizards_pass_cards.json"
LOBBY_PORT = 18900

godot_bin = godot()
godot_import(godot_bin)
scenarios = sys.argv[1:] or sorted(p.name for p in (GAME / "tests" / "scenarios").glob("*.json"))
logs = Path(tempfile.mkdtemp(prefix="two-wards-net-"))
host_log, client_log = logs / "host.log", logs / "client.log"
runs = failed = 0


def start(log, *args):
    with open(log, "wb") as out:
        return subprocess.Popen(
            [godot_bin, "--headless", "--path", ".", "--script", "res://tools/net_test.gd", "--", *args],
            cwd=GAME,
            stdout=out,
            stderr=subprocess.STDOUT,
        )


def lines(*paths):
    return [line for p in paths for line in p.read_text(errors="replace").splitlines()]


def play(label, *args, host_ready=None):
    """Runs one host + client pair and prints the outcome. host_ready(log) returns extra
    client args once the host is up."""
    global runs, failed
    runs += 1
    host = start(host_log, "--role=host", *args)
    extra = host_ready() if host_ready else []
    client_code = start(client_log, "--role=client", *args, *extra).wait()
    host_code = host.wait()
    for line in lines(host_log, client_log):
        if re.match(r"\[(host|client) ", line) and not re.search(" (skipped|refused) ", line):
            print(line)
    if host_code or client_code:
        print(f"FAILED {label} (host exit {host_code}, client exit {client_code})")
        print("\n".join([x for x in lines(host_log, client_log) if re.search("ERROR|desync", x)][:20]))
        failed += 1
    else:
        print(f"ok {label}")
    sys.stdout.flush()


def room_code():
    for _ in range(100):
        found = re.search(r"room ([A-Z]{4})", host_log.read_text(errors="replace"))
        if found:
            return [f"--code={found.group(1)}"]
        time.sleep(0.2)
    return ["--code="]


try:
    for port, name in enumerate(scenarios, start=17778):
        play(name, f"--port={port}", f"--scenario=res://tests/scenarios/{name}")

    bun = shutil.which("bun")
    if not bun:
        if os.environ.get("CI"):
            fail("bun is required for the WebRTC network test")
        print("skipped WebRTC: install bun (https://bun.sh) to run it")
    else:
        with open(logs / "lobby.log", "wb") as out:
            lobby = subprocess.Popen(
                [bun, str(ROOT / "lobby" / "src" / "server.ts")],
                env={**os.environ, "PORT": str(LOBBY_PORT)},
                stdout=out,
                stderr=subprocess.STDOUT,
            )
        try:
            for _ in range(50):
                try:
                    urllib.request.urlopen(f"http://127.0.0.1:{LOBBY_PORT}/healthz", timeout=1)
                    break
                except OSError:
                    time.sleep(0.2)
            play(
                f"{WEBRTC_SCENARIO} (WebRTC)",
                f"--lobby=ws://127.0.0.1:{LOBBY_PORT}/ws",
                f"--scenario=res://tests/scenarios/{WEBRTC_SCENARIO}",
                host_ready=room_code,
            )
        finally:
            lobby.kill()
            lobby.wait()
finally:
    shutil.rmtree(logs, ignore_errors=True)

if failed:
    fail(f"{failed} of {runs} network run(s) failed")
print(f"All {runs} network runs in sync.")
