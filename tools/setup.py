"""One-time setup of a dev machine; safe to re-run. Installs the pinned Python packages
(gdtoolkit, pillow, pre-commit), the pinned Godot and gdUnit4, the pre-commit and pre-push
hooks, then runs the quick check.

Needs: Python 3.12+ and git on PATH.
Not installed here: export templates (export.py fetches them on first use).
"""

import shutil
import subprocess
import sys

import install
from _common import ROOT, run

py = sys.executable

print("== Python packages", flush=True)
run(py, "-m", "pip", "install", "--disable-pip-version-check", "-r", "tools/requirements.txt", cwd=ROOT)
print("\n== Godot", flush=True)
install.webrtc()
install.godot()
print("\n== gdUnit4", flush=True)
install.gdunit4()
print("\n== Bun (lobby and the WebRTC network test)", flush=True)
if shutil.which("bun"):
    subprocess.run(["bun", "--version"], check=False)
else:
    print("bun not found: install it from https://bun.sh, or the WebRTC network test is skipped")
print("\n== Git hooks", flush=True)
# -f replaces an old hook (such as the tools/pre-push copy) instead of chaining it.
run(py, "-m", "pre_commit", "install", "-f", "--hook-type", "pre-commit", "--hook-type", "pre-push", cwd=ROOT)
run(py, "tools/check.py", "--quick", cwd=ROOT)
print("\nSetup done. Run python tools/check.py for the full check.")
