# Era look: the big moments

Owner wish (2026-11-12): the game should feel like starting on the genre's first handheld and getting more modern era by era, up to the fifth generation. This page covers the moments that sell the change: title screen, boot card, the era-change scene, the finale card and the save card. Menus, text and the overworld are in `docs/ERA_FEEL_UI.md`, battles in `docs/ERA_FEEL_BATTLE.md`, functions in `docs/ERA_FUNCTIONS.md`, sound in `docs/ERA_FEEL_AUDIO.md`.

The logo artwork is not changed (owner decision 2026-11-10: keep the current logo). It is the same wordmark in every era, scaled to the era's screen; only what happens around it changes.

## What each generation could do, and what Chimora does

Described generically, from general knowledge of the genre's history; no product names. All pictures are drawn in code by `EraBackdrop` from the colours in `data/era_moments.json`; there are no new image files.

| Era | Hardware step | Title | Boot card | Finale card |
| --- | --- | --- | --- | --- |
| I Ink | 4 shades, nothing scrolls | the ink title held still, a 2-frame blink (beam, stars, glints) | power on: a drop of ink falls in 4 px steps, lands with a chime, spreads into a blot in 3 frames; clears in 4 hard steps | lines typed letter by letter, 2-frame cursor |
| II Wash | limited colour, one scrolling layer | flat colour dawn, clouds and far shore scroll in whole pixels, the beam has two positions | colour stripes slide in 3 px a step, 2-frame twinkle | the block scrolls up in whole pixels |
| III Etching | rich palette, gradients | banded sky, shaded hills, a light runs over the logo, a silhouette flies past | bevelled plate on the scene, a light runs over the line | line after line fades in |
| IV Panorama | two screens, bigger sprites, 2.5D | four parallax layers under a low sun, lake in perspective, big figures with shadows, swaying grass | two shutters, one per half screen, open on the scene | the frame slides in from the side |
| V Living | everything animated, moving camera | drifting camera, aurora, waves, motes, breathing figures and the era's legend standing behind the hills | the living scene behind a glossy card that eases in | lines rise and fade in over the moving scene |

## The era-change scene

After an era finale the overworld shows, in this order: the finale card of the era that ended (`EraFinaleCard`), the staged change (`EraChangeScene`), then the era line and the long "New in Era N" texts in the text box as before. The scene shows the new era's lake picture the way the old hardware would draw it and upgrades it in five steps:

| Step | I to II | II to III | III to IV | IV to V |
| --- | --- | --- | --- | --- |
| palette | ink runs into colour from three drops | a scan line climbs down | the picture unrolls from the middle | light sweeps across |
| detail | tile by tile gets its own colours (same resolution) | 144 lines step up to 180 | 180 step up to 270, big figures | the figures start to breathe, the view moves |
| frames | redrawn as a colour-wash frame | as a bevelled plate | as a rounded panel | in gloss |
| music | the old era's bus effects give way to the new ones and the era's title song starts (`Sound.apply_era_fx`, `Sound.music`), shown as voice bars 4 to 5 | 5 to 8 | 8 to 12 | 12 to 16 |
| list | "New in this era": `EraFeatures.new_in(era)`, one row at a time | | | |

A press jumps to the finished list, the next one closes. With reduced motion the four staged steps are one plain fade, then the list. The flags `era_card_N_seen` and `era_change_N_seen` keep each from showing twice. The Era V finale has no change after it; its card shows once on the next map load.

`EraUpgrade` (docs/ERA_FEEL_UI.md) sweeps the live map when the era switches; this scene comes after it and is the explained, step-by-step version.

## Save card

The title wears the newest era any save has reached (`EraMoments.title_era`). The Continue row and every used slot row carry a 10 px badge of the save's era. `EraSaveCard` shows the save's frame style, a small picture of its era and "Era II: Wash" with place and play time: between the picture and the list on tall screens, over the picture's lower edge while a slot list is open on 16:9 screens (no room there).

## Files

- `data/era_moments.json`: everything per era and per change. `EraMoments.problems()` and `tests/unit/test_era_moments.gd` check it.
- `scripts/core/EraMoments.gd`: lookups, the step timeline, the era of a save file.
- `scripts/ui/EraBackdrop.gd` (scene painter, frames), `EraTitleArt.gd`, `EraBoot.gd`, `EraChangeScene.gd`, `EraFinaleCard.gd`, `EraSaveCard.gd`, `EraMomentLayer.gd` (clock, press to skip), `shaders/era_moment.gdshader`.
- German: `tools/i18n/de_era_moments.py`.
- Frame strips: `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_title_shots.gd -- out_dir [lang]`.

## Still missing

- Era V uses Quivermoor's own art (#488): Moorbreath as the legend shape, Driftadmiral and Lichenthrone as the figures. Era IV still shows Quillmarch figures; swap the names in the data file when Halcyra's own front art is in art/era4.
- No own jingle per boot card or change step; they use the era's existing sounds.
- The finale card is not reachable from a menu after it was shown.
