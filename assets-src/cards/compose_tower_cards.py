"""Composes card_art_<tower>.png: the tower sprite at 1x on a dusk meadow with its light pool.

Run after changing a tower sprite: python assets-src/cards/compose_tower_cards.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

repo = Path(__file__).resolve().parents[2]
LIGHT = {"arrow_tower": "#2ce8f5", "ballista": "#f77622", "frost_totem": "#c0cbdc", "storm_spire": "#b55088"}
for tid, light in LIGHT.items():
    art = Image.new("RGBA", (128, 96), "#262b44")
    d = ImageDraw.Draw(art)
    for y, c in ((30, "#3a4466"), (48, "#68386c"), (60, "#b55088")):  # dusk bands
        d.rectangle((0, y, 127, 95), fill=c)
    d.rectangle((0, 68, 127, 95), fill="#193c3e")  # meadow
    d.rectangle((0, 74, 127, 95), fill="#265c42")
    for x in range(3, 128, 9):  # grass tufts
        d.point([(x, 73), (x + 4, 76), (x + 2, 82), (x + 6, 88)], fill="#3e8948")
    d.ellipse((34, 74, 93, 94), fill=light)  # light pool
    d.ellipse((40, 77, 87, 91), fill="#3e8948")
    sprite = Image.open(f"{repo}/game/assets/towers/tower_{tid}.png").convert("RGBA")
    # Top at y 14: the hand shows only rows 16-72, and the top is what tells towers apart.
    art.alpha_composite(sprite, (40, 14))
    art.save(f"{repo}/game/assets/cards/card_art_{tid}.png", optimize=True)
