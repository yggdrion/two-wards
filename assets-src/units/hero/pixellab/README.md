# Hero: raw PixelLab output

The hero anchor's raw PixelLab generations, kept so the cleanup has a starting point and the settings can be repeated. They follow `docs/STYLE_GUIDE.md`, section 9.

| File | Endpoint | Settings |
| --- | --- | --- |
| `hero_down_pixflux_seed1337.png` | `create-image-pixflux` | 64×64, `high top-down`, `south`, single color black outline, medium shading, medium detail, no background, seed 1337, `color_image` = the 13-color hero palette |
| `hero_up_rotate_raw.png` | `rotate` | From the down frame, `high top-down`, south → north, seed 1337 |
| `hero_side_rotate_raw_seed1337.png` | `rotate` | South → east, seed 1337 |
| `hero_side_rotate_raw_seed7.png` | `rotate` | South → east, seed 7, image guidance 5 |

Prompt: "young wizard hero in deep blue and teal hooded robe with pointed hat, holding a wooden staff topped with a glowing cyan crystal, dark fantasy, full body, small chibi game sprite, centered, feet at bottom with space below".

The down output was already on the hero palette. The rotate outputs were snapped to the palette (nearest color) before use, because rotate ignores `color_image`. Both east rotations face away from the camera (back-right 3/4), not a right-facing profile, so `unit_hero_idle_side.png` is still a placeholder. The side frame has to be drawn by hand in Aseprite from the down and up frames.
