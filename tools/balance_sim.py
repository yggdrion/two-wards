"""Headless balance sweep with the scenario bot (game/tools/balance_sim.gd).

Plays runs over decks, wizards, all difficulty tiers and seeds, solo and co-op, with card
upgrades on, plus a booster sim for the meta loop, and prints win tables. The bot plays every
card as soon as it can and builds anywhere near the path: compare decks and tiers with it, not
absolute win rates (a real player does better).

Usage: python tools/balance_sim.py [--quick] [--csv FILE]
  --quick   3 decks, 2 co-op pairs, 2 seeds, Frost only (~4 min instead of ~10)
  --csv     also write every run as CSV
Set GODOT_BIN to use your own binary; it must match .godot-version.
"""

import argparse
import statistics
import subprocess

from _common import GAME, fail, godot, godot_import

FIELDS = ["mode", "deck", "wizards", "tier", "seed", "result", "waves", "crystal", "gold"]
TIERS = 5

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("--quick", action="store_true")
parser.add_argument("--csv")
args = parser.parse_args()

godot_bin = godot()
godot_import(godot_bin)
parts = ["solo:frost", "coop", "meta"] + ([] if args.quick else ["solo:ember"])
procs = [
    subprocess.Popen(
        [godot_bin, "--headless", "--path", ".", "--script", "res://tools/balance_sim.gd", "--",
         f"--part={part}", *(["--quick"] if args.quick else [])],
        cwd=GAME,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    for part in parts
]
runs, meta = [], []
for part, proc in zip(parts, procs):
    out, _ = proc.communicate()
    lines = out.splitlines()
    if proc.returncode != 0 or not any(line.startswith(("RUN ", "META ")) for line in lines):
        fail(f"balance_sim.gd --part={part} printed no results (exit {proc.returncode})")
    for line in lines:
        if line.startswith("RUN "):
            row = dict(zip(FIELDS, line[4:].strip().split(",")))
            for key in ("tier", "seed", "waves", "crystal", "gold"):
                row[key] = int(row[key])
            runs.append(row)
        elif line.startswith("META "):
            meta.append(line[5:].strip())


def cell(rows):
    wins = sum(r["result"] == "won" for r in rows)
    return f"{wins}/{len(rows)} ({statistics.mean(r['waves'] for r in rows):.1f})"


def table(mode):
    rows = [r for r in runs if r["mode"] == mode]
    if not rows:
        return
    print(f"\n{mode}: wins/runs (avg waves cleared)")
    print("deck".ljust(20) + "".join(f"T{t + 1}".rjust(13) for t in range(TIERS)))
    for deck in sorted({r["deck"] for r in rows}) + ["ALL"]:
        line = deck.ljust(20)
        for t in range(TIERS):
            sel = [r for r in rows if r["tier"] == t and deck in ("ALL", r["deck"])]
            line += cell(sel).rjust(13)
        print(line)
    hp = [statistics.mean(r["crystal"] for r in rows if r["tier"] == t) for t in range(TIERS)]
    print("crystal HP left".ljust(20) + "".join(f"{h:.1f}".rjust(13) for h in hp))
    gold = [statistics.mean(r["gold"] for r in rows if r["tier"] == t) for t in range(TIERS)]
    print("gold per run".ljust(20) + "".join(f"{g:.0f}".rjust(13) for g in gold))


table("solo")
table("coop")
wizards = sorted({r["wizards"] for r in runs if r["mode"] == "solo"})
if len(wizards) > 1:
    print("\nsolo by wizard: " + ", ".join(
        f"{w} {cell([r for r in runs if r['mode'] == 'solo' and r['wizards'] == w])}" for w in wizards))
print("\nmeta (500 new profiles opening boosters):")
for line in meta:
    print("  " + line)
if args.csv:
    with open(args.csv, "w", encoding="utf-8") as out:
        out.write(",".join(FIELDS) + "\n")
        for r in runs:
            out.write(",".join(str(r[k]) for k in FIELDS) + "\n")
    print(f"\n{len(runs)} runs written to {args.csv}")
