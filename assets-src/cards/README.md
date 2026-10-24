# Card art sources

Ability cards: raw `create-image-pixflux` output in `<id>/pixellab/`, 128×96, view `side`, with background, single color black outline, medium shading, medium detail, seed 1337. `color_image` = the arrow tower sprite plus 4–5 Endesga swatches for the card's accent. Prompt: the subject, then ", card illustration, dark fantasy storybook pixel art, evening meadow background with dusk sky, centered subject, no text". Snapped to Endesga 32 (nearest color, alpha 0/255) for `game/assets/cards/`.

Tower cards are not generated: `compose_tower_cards.py` puts the tower sprite on a dusk meadow. Re-run it after changing a tower sprite.

Tower sprites (`assets-src/towers/<id>/pixellab/`) use the same settings at 48×72, view `high top-down`, no background.
