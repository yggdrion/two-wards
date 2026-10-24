"""Runs the same checks as CI locally, in CI order, and stops at the first failure:
  1. gdlint + gdformat --check     2. asset validator + its unittest suite
  3. gdUnit4 tests (pinned Godot)  4. headless network test (host + client over ENet and WebRTC)
  5. generated assets are up to date

Usage: python tools/check.py [--quick] [--export]
  --quick   only steps 1 and 2 (no Godot), a few seconds
  --export  also export the Linux and Windows builds to build/<platform>/
Needs: python tools/setup.py once (Python packages, Godot, gdUnit4, hooks). setup.py also
installs it as a git pre-push hook (skip once with: git push --no-verify).
"""

import importlib.util
import subprocess
import sys

from _common import ROOT, fail, run

args = set(sys.argv[1:])
if not args <= {"--quick", "--export"}:
    fail("Usage: python tools/check.py [--quick] [--export]")
py = sys.executable
dirs = ["game/scripts", "game/tests", "game/tools"]


def step(name):
    print(f"\n== {name}", flush=True)


def tool(name, *tool_args):
    run(py, f"tools/{name}.py", *tool_args, cwd=ROOT)


def snapshot():
    # Content diff plus untracked files, not git status: with core.autocrlf, Godot rewriting a
    # CRLF checkout as LF shows up as modified in git status although the content is the same.
    def git(*a):
        return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, check=True).stdout

    return git("diff", "game/") + git("ls-files", "--others", "--exclude-standard", "game/")


step("Lint and format")
# Through python -m, so a user-site pip install works without its Scripts dir on PATH.
if not importlib.util.find_spec("gdtoolkit"):
    fail("gdtoolkit not installed: run python tools/setup.py")
run(py, "-m", "gdtoolkit.linter", *dirs, cwd=ROOT)
run(py, "-m", "gdtoolkit.formatter", "--check", *dirs, cwd=ROOT)

step("Asset validator")
run(py, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py", cwd=ROOT)
tool("validate_assets")

if "--quick" in args:
    print("\nQuick checks passed (Godot tests skipped).")
    sys.exit(0)

step("gdUnit4 tests")
tool("run_tests")

step("Network test")
tool("run_network_test")

step("Generated assets up to date")
# Compare before and after, so local uncommitted work does not count as drift.
before = snapshot()
run(py, "tools/build_assets.py", cwd=ROOT, stdout=subprocess.DEVNULL)
if snapshot() != before:
    subprocess.run(["git", "--no-pager", "diff", "--stat", "game/"], cwd=ROOT, check=False)
    subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "game/"], cwd=ROOT, check=False)
    diff = subprocess.run(["git", "--no-pager", "diff", "game/"], cwd=ROOT, capture_output=True, text=True, check=False)
    print("\n".join(diff.stdout.splitlines()[:80]))
    fail("build_assets changed files under game/: commit the regenerated .tres and .import files.")

if "--export" in args:
    step("Export")
    tool("export", "linux")
    tool("export", "windows")

print("\nAll checks passed.")
