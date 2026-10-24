"""Installs the pinned tools; re-running is a no-op once installed.

Usage: python tools/install.py [godot|gdunit4|webrtc|templates]   (default: godot)

  godot      Godot from .godot-version into .tools/godot/<version>/ (gitignored), checked
             against tools/godot-<version>.sha512, plus webrtc. Prints the binary path.
  gdunit4    gdUnit4 into game/addons/gdUnit4 (gitignored).
  webrtc     the webrtc-native GDExtension into game/addons/webrtc_native (gitignored).
  templates  the Linux, Windows and macOS release export templates into the directory Godot
             reads them from; only the ones we ship are extracted from the ~1.3 GB .tpz. Prints it.

Logs go to stderr.
"""

import os
import platform
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

from _common import RELEASES, ROOT, VERSION, download, expected_sum, fail, log

GDUNIT4_VERSION = os.environ.get("GDUNIT4_VERSION", "v6.2.2")
WEBRTC_VERSION = "1.2.2-stable"
WEBRTC_SHA256 = "98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5"
TEMPLATES = ["version.txt", "linux_release.x86_64", "windows_release_x86_64.exe", "macos.zip"]


def godot():
    system, machine = platform.system(), platform.machine().lower()
    if system == "Windows":
        asset, binary = "win64.exe", f"Godot_v{VERSION}-stable_win64_console.exe"
    elif system == "Darwin":
        asset, binary = "macos.universal", "Godot.app/Contents/MacOS/Godot"
    elif system == "Linux" and machine in ("x86_64", "amd64"):
        asset, binary = "linux.x86_64", f"Godot_v{VERSION}-stable_linux.x86_64"
    elif system == "Linux" and machine in ("aarch64", "arm64"):
        asset, binary = "linux.arm64", f"Godot_v{VERSION}-stable_linux.arm64"
    else:
        fail(f"Unsupported platform: {system} {machine}")

    dest = ROOT / ".tools" / "godot" / VERSION
    path = dest / binary
    if path.exists():
        return path
    name = f"Godot_v{VERSION}-stable_{asset}.zip"
    expected = expected_sum(name)
    with tempfile.TemporaryDirectory() as tmp:
        log(f"Downloading Godot {VERSION} ({asset})...")
        archive = Path(tmp) / name
        download(f"{RELEASES}/{name}", archive, "sha512", expected)
        dest.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            z.extractall(dest)
    # zipfile drops the exec bit.
    path.chmod(0o755)
    log(f"Installed Godot {VERSION} to {dest}")
    return path


def gdunit4():
    dest = ROOT / "game" / "addons" / "gdUnit4"
    cfg = dest / "plugin.cfg"
    if cfg.exists() and f'version="{GDUNIT4_VERSION.lstrip("v")}"' in cfg.read_text():
        log(f"gdUnit4 {GDUNIT4_VERSION} already installed")
        return
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(
            ["git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1",
             "--branch", GDUNIT4_VERSION, "https://github.com/godot-gdunit-labs/gdUnit4.git",
             f"{tmp}/gdunit4"],
            check=True,
        )
        shutil.rmtree(dest, ignore_errors=True)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(f"{tmp}/gdunit4/addons/gdUnit4", dest)
    # The addon ships its own test suite; we don't run it.
    shutil.rmtree(dest / "test", ignore_errors=True)
    log(f"gdUnit4 {GDUNIT4_VERSION} installed to {dest}")


def webrtc():
    dest = ROOT / "game" / "addons" / "webrtc_native"
    marker = dest / ".version"
    if marker.exists() and marker.read_text().strip() == WEBRTC_VERSION:
        return
    with tempfile.TemporaryDirectory() as tmp:
        log(f"Downloading webrtc-native {WEBRTC_VERSION}...")
        archive = Path(tmp) / "webrtc.zip"
        url = (f"https://github.com/godotengine/webrtc-native/releases/download/"
               f"{WEBRTC_VERSION}/godot-extension-webrtc_native.zip")
        download(url, archive, "sha256", WEBRTC_SHA256)
        with zipfile.ZipFile(archive) as z:
            z.extractall(f"{tmp}/x")
        shutil.rmtree(dest, ignore_errors=True)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(f"{tmp}/x/addons/webrtc_native", dest)
    marker.write_text(WEBRTC_VERSION + "\n")
    log(f"webrtc-native {WEBRTC_VERSION} installed to {dest}")


def templates():
    system = platform.system()
    if system == "Windows":
        data = Path(os.environ["APPDATA"]) / "Godot"
    elif system == "Darwin":
        data = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "godot"
    dest = data / "export_templates" / f"{VERSION}.stable"
    if all((dest / f).exists() for f in TEMPLATES):
        return dest
    name = f"Godot_v{VERSION}-stable_export_templates.tpz"
    expected = expected_sum(name)
    with tempfile.TemporaryDirectory() as tmp:
        log(f"Downloading Godot {VERSION} export templates (~1.3 GB)...")
        archive = Path(tmp) / name
        download(f"{RELEASES}/{name}", archive, "sha512", expected)
        dest.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for f in TEMPLATES:
                (dest / f).write_bytes(z.read(f"templates/{f}"))
    (dest / "linux_release.x86_64").chmod(0o755)
    log(f"Installed Godot {VERSION} export templates to {dest}")
    return dest


if __name__ == "__main__":
    tools = {"godot": godot, "gdunit4": gdunit4, "webrtc": webrtc, "templates": templates}
    which = sys.argv[1] if len(sys.argv) > 1 else "godot"
    if which not in tools or len(sys.argv) > 2:
        fail(f"Usage: python tools/install.py [{'|'.join(tools)}]")
    if which == "godot":
        webrtc()
    result = tools[which]()
    if result:
        print(result)
