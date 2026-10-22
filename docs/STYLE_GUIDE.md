# Asset style guide

This guide extends the style guide table in `docs/PLAN.md`. The table sets the basics: sizes, palette, naming, directions. This file adds the rules the first hero frames (v1, 2026-10-22, made at the old 32×32 size) showed were missing. All sizes here are for the 640×360 base resolution. It covers how a sprite sits in its frame, how many colors it uses, outlines, camera, light, and what each direction must show. Rules marked **(validator)** are enforced by `tools/validate_assets.py`. Everything else is checked by eye at review time.

## 1. Palette and color count

- Endesga 32 only, alpha 0 or 255 only. **(validator)**
- **At most 16 colors per unit sprite**, counting the outline but not transparency. 12 or fewer is better. A sprite with more colors reads as noise and drifts from its siblings.
- Each material gets a **ramp of 2 to 4 colors** (dark, base, light) and uses only that ramp. No stray single pixels in another hue: the red, pink and green specks on the hero v1 robe are exactly what to remove.
- Character and enemy palettes are fixed per unit and shared by all its animations and directions. Write them down below when an anchor is approved.

Hero palette (target for the cleanup of v1):

| Material | Dark | Base | Light |
| --- | --- | --- | --- |
| Outline | `181425` | | |
| Robe, hat | `262b44` | `124e89` | `0099db` |
| Robe trim, cloth | `3a4466` | `5a6988` | `8b9bb4` |
| Skin | `c28569` | `e8b796` | |
| Staff | `3e2731` | `733e39` | |
| Crystal | `0099db` | `2ce8f5` | `ffffff` |

That is 13 distinct colors (`0099db` is shared by robe and crystal). Blue and teal is the player color code; enemies must not use the robe ramp as their main color.

Goblin palette: green ramp `265c42` `3e8948` `63c74d`, accents `e43b44` or `f77622` for eyes and weapons only. Set the full list when the goblin anchor is made.

## 2. Placement in the frame

Units use a 64×64 frame. The game anchors each frame at its **bottom center**, so every frame of every unit must agree on where the feet are.

| Rule | Value |
| --- | --- |
| Feet baseline | The lowest body pixel sits on **row 59** (0-indexed). Rows 60 to 63 stay empty. |
| Body height | Humanoid hero: **48 to 52 px** from feet to top of the head or hat. Small goblin (runner): 32 to 40 px. Brute: up to 56 px. |
| Top margin | At least **4 empty rows** at the top (rows 0 to 3). A held item such as the staff may reach row 4 but not higher. |
| Side margin | At least **4 empty columns** left and right. |
| Horizontal center | The body's center column is **column 31 or 32**, in every direction. Held items may extend sideways. Don't shift the body to make room for them. |
| Proportions | Chibi: the head (with hat brim) is about 1/3 of body height. |

Shadows are **not** drawn into the sprite. The game draws one shared shadow under every unit: a flat `181425` ellipse, 24×8 px for the hero and goblins, centered under the feet. A baked shadow would flip with `flip_h` and could not change with the terrain.

Why: hero v1 (32×32) filled rows 1 to 31 and touched the bottom edge, so it had no room under it and stood taller than any enemy will.

## 3. Outline

- **1 px outline in `181425`** around the whole outer silhouette, held items included. Stay at 1 px at 64×64; a 2 px outline makes units look like stickers.
- **Closed**: every outline pixel touches the next one by an edge or a corner, with no gaps. Hero v1 had gaps at the hat brim and along the staff.
- **No doubled outline**: never two outline pixels deep, except at a single-pixel corner where the line changes direction.
- **Interior lines** (between arm and robe, or hat and face) use the darkest color of the local ramp, never `181425`. That keeps the silhouette readable against dark terrain.
- Terrain and tiles have **no outline**.

## 4. Camera

- **Top-down 3/4, at about 45 degrees.** You see the front of the body and the top of the head or hat at once. The camera does not rotate between directions; only the unit turns.
- In the down view, the top of the hat or head takes about 4 to 6 rows. The face sits in the upper middle of the head, not at its center, and shoulders show a 2 px top plane.
- Feet are short (4 to 6 rows) and drawn as two blobs side by side, not one in front of the other.
- Hero v1 read closer to a straight front view. Show more hat top and less face height.

In PixelLab terms this is `view: "high top-down"`.

## 5. Light

- One light from the **top-left**. Shadows fall to the **bottom-right**.
- Highlights (the light color of a ramp) go on the **top and left edges** of forms: the hat's top-left plane, the left shoulder, the left side of the staff.
- Core shadows (the dark color of a ramp) go on the **bottom and right**: under the hat brim, the right side of the robe, under the arms.
- **The light does not turn with the unit.** In the up view the light still comes from screen top-left, so the robe's back is lit on its left. In the side view the light sits on the unit's back or front, whichever is at screen left. Mirrored `side` frames break this slightly; that is accepted to keep one strip per direction.
- Emissive things (the staff crystal, goblin eyes) ignore the light and use their brightest color in the middle.

Hero v1 shading was nearly flat: the left highlights and right shadows on the robe and hat were missing.

## 6. Directions

Three strips per animation: `down`, `up`, `side` (facing right). Left is `side` with `flip_h`. **(validator: file naming and strips)**

| Direction | Must show |
| --- | --- |
| `down` | The front of the unit, face toward the viewer, both feet. The hero holds the staff in their left hand, which is screen right (as in the 64×64 anchor). |
| `up` | The back, with no face visible. The hood or hat covers the head. The staff is still in the left hand, which is now screen left. |
| `side` | A **true profile facing right**: one eye, the nose or hat brim pointing right, the body about half as wide as in `down`. Feet one behind the other. The staff hand is in front of the body. |

Asymmetry rules, because `side` is mirrored for left:

- No text, emblems or one-sided details that would look wrong when flipped.
- The held item may swap hands when mirrored. That is accepted.

Hero v1 `side` only turned about a quarter (front-right 3/4, both eyes visible). If a generated `side` does that again, redraw it into a profile in Aseprite, using the `up` and `down` frames for colors.

## 7. Animation

- Frame count, fps and loop come from `game/assets/manifest.json`. **(validator)**
- Each strip keeps the feet baseline on row 59 in every frame, except for jumps or attacks that lift on purpose.
- The idle animation moves at most 2 px (breathing, the crystal flickering). Walk cycles bob 1 or 2 px on contact frames.
- Frame 0 of each `idle` strip is the "still" pose used for previews and the anchor.

## 8. Review checklist

Before marking a manifest entry `done`, check it at 1× and 3× (1080p) next to the hero anchor:

1. The validator passes.
2. 16 colors or fewer, and no stray single-pixel hues.
3. Feet on row 59, top and side margins kept, body centered.
4. Outline closed, 1 px, `181425`. No outline on terrain.
5. Light from the top-left in every direction.
6. `side` is a real profile, and nothing breaks when flipped.
7. The silhouette reads at 1× against the path and ground tiles.

## 9. PixelLab settings

The API is called with no key in the request: the cloud environment's proxy adds it. The trial runs 1 job at a time, and a second call gets HTTP 429. A generation can take about 30 s, so use a long timeout. A call that fails with 502 may still be charged.

New unit, first direction (`POST /v2/create-image-pixflux`):

| Field | Value |
| --- | --- |
| `image_size` | 64×64 |
| `view` | `high top-down` |
| `direction` | `south` |
| `outline` | `single color black outline` |
| `shading` | `basic shading` |
| `detail` | `medium detail` (v1 at 32×32 had 23 colors with it; at 64×64 the palette swatch is what caps colors) |
| `no_background` | `true` |
| `color_image` | A swatch of the unit's palette from section 1, not all 32 colors. This is how the color limit is reached. |
| `description` | Name the subject, the palette words (deep blue, teal), "full body, small chibi game sprite, centered, feet at bottom with space below". Section 2 can't be enforced by the prompt; fix placement after. |

Other directions (`POST /v2/rotate`), from the cleaned-up `down` frame:

| Field | Value |
| --- | --- |
| `from_view`, `to_view` | `high top-down` |
| `from_direction` | `south` |
| `to_direction` | `north` for `up`, `east` for `side` |

Known issues with rotate: it ignores `color_image`, so snap the result to the palette afterwards. `east` comes back as a 3/4 view, not a profile, so plan to redraw `side` by hand. Rotating from a cleaned-up frame should work better than rotating the raw output.

After any generation, before the validator:

1. Snap to the unit's palette (nearest color) and set alpha to 0 or 255.
2. Fix placement (section 2), outline (section 3) and light (section 5) in Aseprite. Save the `.aseprite` source under `assets-src/`.
3. Export the strip and run the validator and `build_assets`.

Record the seed and settings of every kept generation in the PR that adds it.
