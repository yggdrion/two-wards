"""Exports a release build with the pinned Godot version and export templates.

Usage: python tools/export.py <linux|windows> [output dir, default build/<platform>]
"""

import subprocess
import sys
from pathlib import Path

import install
from _common import GAME, ROOT, fail, godot, godot_import, run

PRESETS = {"linux": ("Linux", "two-wards.x86_64"), "windows": ("Windows Desktop", "two-wards.exe")}

if len(sys.argv) not in (2, 3) or sys.argv[1] not in PRESETS:
    fail("Usage: python tools/export.py <linux|windows> [output dir]")
preset, file = PRESETS[sys.argv[1]]
out = Path(sys.argv[2] if len(sys.argv) == 3 else ROOT / "build" / sys.argv[1]).resolve()

godot_bin = godot()
install.templates()
out.mkdir(parents=True, exist_ok=True)
godot_import(godot_bin)
# The commit goes into the pck so co-op can refuse a partner on another build
# (NetSession.build_id); runs from source have no file and count as "dev".
git = subprocess.run(
    ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, cwd=ROOT, check=False
)
build_id = GAME / "build_id.txt"
build_id.write_text(git.stdout.strip() if git.returncode == 0 else "dev")
try:
    run(godot_bin, "--headless", "--export-release", preset, out / file, cwd=GAME)
finally:
    build_id.unlink()
# Godot can exit 0 after a failed export, so check the result.
if not (out / file).exists() or (out / file).stat().st_size == 0:
    fail(f"Export of {preset} produced no {out / file}")
print(f"Exported {preset} to {out / file}")
