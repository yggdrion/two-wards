---
name: balance-sim
description: Simulate many Two Wards runs headless (decks × wizards × difficulty tiers × seeds, solo and co-op, plus a booster/meta sim) to judge difficulty and balance without playing. Use when Rapha asks whether the game is too easy or hard, wants balance numbers, or before and after changing enemy HP, waves, tiers, cards, upgrades, gold or booster numbers.
---

# Balance sim

`python tools/balance_sim.py` runs `game/tools/balance_sim.gd` in four parallel headless Godot processes and prints the tables. The player is `ScenarioBot` (`game/tools/scenario_bot.gd`, the same bot that records scenarios). Every half second it plays the first affordable card, builds towers on the free grid spot closest to the path, casts spells on the leading enemy, and takes the first upgrade of every offer.

## Run it

    python tools/balance_sim.py --quick              # ~4 min: 3 decks, 2 co-op pairs, 2 seeds, Frost
    python tools/balance_sim.py --csv build/balance.csv   # ~10 min: 6 decks, both wizards, 4 seeds, 4 pairs

Run it in the background (it takes minutes). Decks and co-op pairs are the `DECKS` / `PAIRS` constants at the top of `balance_sim.gd`; add a deck there to test a new card.

## Read it

- **Deck × tier tables** show wins/runs and the average waves cleared. Below them: crystal HP left (all runs, losses count as 0) and gold per run.
- **Healthy shape (Rapha's target, 2026-10-25):** Tier 1 almost always won, but with crystal damage taken. Each tier clearly harder. Tier 5 lost most of the time. No deck winning everything, no deck losing Tier 1.
- **Meta:** the net gold a new profile needs for the full collection (2 copies of every card) and for its first epic. Divide it by the gold per run to get the number of runs.
- The bot plays worse than a person. Compare decks, tiers and before/after; don't read win rates as what a player will see.
- The bot never cycles cards and rarely affords 6–7 cost cards. If a card looks useless or dominant, count its plays before blaming it (one-off: print the actions `ScenarioBot.play(on_action)` reports).

## Tune with it

1. Run `--quick` on main as the baseline and keep the output.
2. Change one knob:
   - `Sim` constants: `WAVE_HP`, `TIER_HP`, `PLAYER_HP`, `TIER_INTERVAL`, gold.
   - The waves in `game/resources/waves/`.
   - Card and tower `.tres` files and the upgrades.
3. Run `--quick` again and compare. To try several values at once, copy `game/` into the scratchpad once per value and run `balance_sim.gd` against each copy with `--path` (never edit the same `sim.gd` from parallel runs).
4. Confirm the final values with a full run.
5. Re-record the scenarios with `record_scenario.gd`, run `python tools/check.py`, and put the full-run table in the PR.
6. Update the numbers in the `docs/HANDOFF.md` decision entry and the formulas in `docs/PLAN.md`.

## Last full result (2026-10-25, PR 51)

Solo wins by tier: 43, 39, 30, 19, 16 of 48 (crystal HP left 17 → 4). Co-op: 16, 13, 12, 12, 12 of 16. Outliers: the all-tower deck won 40/40; two starter decks in co-op lose from Tier 2. Meta: about 520 gold fills the collection.
