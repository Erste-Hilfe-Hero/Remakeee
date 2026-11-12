# Era feel outside battle

Owner wish (2026-11-12): the game should feel like starting with the first handheld monster-taming game and getting more modern, generation by generation, up to the fifth. Battles are covered elsewhere (battle scene, move animations, battle camera); this page covers everything outside battle: UI, overworld and the moment the era changes.

Chimora's eras and where they live: Era I Ink (story acts 1-4), Era II Wash (Vellmarch), Era III Etching (Quillmarch), Era IV Panorama (Halcyra), Era V Living (Quivermoor). The newest unlocked era is the look of the whole world (the Retro filter picks an older one). Old Spirlings keep the look of the era they come from (`EraManager.sprite_path`).

## What the handheld generations changed outside battle

Described generically, from general knowledge of the genre's history; no product names.

| Generation | Screen and palette | Text and menus | Overworld | Sound |
| --- | --- | --- | --- | --- |
| 1 | 4 shades of one colour, 160x144, chunky 8x8 tiles | plain box with a 1-2 px border, blocky font, slow typing, flat list menus, bars as plain lines | 2-frame walk, almost no tile animation, hard cuts or stepped fades between maps, no place-name popup | 4-channel sound chip, square-wave blips |
| 2 | limited colour (a few colours per tile), same resolution | selectable box frames, colour in menus, clock icon | clock with day and night tint, animated water and flowers, place name shown on entry | same chip, richer arrangements |
| 3 | wider screen, many colours per sprite, smooth shading | textured frames, finer font, bag pockets with pictures, coloured bars with shading | 3-frame walk (left and right foot), running, reflections in water, footprints in sand, grass rustle, overworld weather, signboard place popup | richer chip with sampled-like drums |
| 4 | two screens, higher detail | touch menus, rounded panels, larger smooth font | towns drawn with a tilted 2.5D look, iris and spiral map transitions, ribbon place banner, bigger buildings | soft synth tones, reverb |
| 5 | same two screens, everything animated | glossy menus, animated backgrounds | moving camera in towns, seasons that recolour the world, figures idle-animate | richer synth, echoes |

## Exists / added / still missing

"Exists" = in the game before this page. "Added" = this change (`data/era_feel.json`, read through `EraManager.feel()`). Era I is the game as it was: nothing is taken away from it, and each later era keeps everything of the one before (`tests/unit/test_era_feel.gd`).

### Era I - Ink

| Feature | Exists | Added | Missing |
| --- | --- | --- | --- |
| 4-ink screen filter, 144x256 | yes (EraManager palette filter, region inks) | | |
| Text box frame | notched double-rule ink frame, shop frames | frame kind "ink" in the table | |
| Font and typing | 8 px pixel font, typing blips | blip "blip", speed x1.0 | |
| Menus, Vigor bar | ink theme, ink line bar | bar style "ink" | |
| Warp | door rectangle, edge slide | warp "door" | stepped 4-shade fade |
| Place banner | plain panel | style "plain" | |
| Overworld | dust, inkshadow, weather dots, day tint | | |

### Era II - Wash (Vellmarch)

| Feature | Exists | Added | Missing |
| --- | --- | --- | --- |
| Colour tiles and chars | era2 atlas and char sheets | | |
| Menu skin | | indigo-on-paper palette, rounded colour-wash frame | 4 selectable frames |
| Text voice | | square blip "blip_e2" | |
| Vigor bar in menus | | green / yellow / red bar | |
| Place banner | | framed sign drops in | |
| Water and flowers | | shimmering water, swaying flowers | drawn animated tiles |
| Era change | white sweep | colour spreads from the screen centre over the 4-ink look, redraw line, jingle "era_up_2", caption EN+DE | spread from the Wayfarer's exact spot |

### Era III - Etching (Quillmarch)

| Feature | Exists | Added | Missing |
| --- | --- | --- | --- |
| 180x320, Quillmarch atlas | yes | | 10 px font |
| Menu skin | | sepia palette, bevel frame with dotted gold rule, raised buttons | paper texture |
| Text | | blip "blip_e3", typing x1.15 | |
| Vigor bar | | shaded colour bar | |
| Place banner | | wooden board drops in | |
| Walk | 2 frames | left and right foot (step frame mirrored every other step) | drawn 3-row sheets |
| Overworld | | leaves from tall grass, reflection in water below, footprints on paths and scree | weather overlays drawn as art |
| Era change | white sweep | lines sharpen from the old resolution and colour levels, view eases out, jingle, caption | |

### Era IV - Panorama (Halcyra)

| Feature | Exists | Added | Missing |
| --- | --- | --- | --- |
| 270x480, Halcyra atlas | yes | | |
| Menu skin | | cool sky palette, rounded panel, rounded buttons, large font | selectable menu backgrounds |
| Text | | soft triangle blip "blip_e4", typing x1.3 | |
| Vigor bar | | bevelled bar | |
| Warp | | iris closes on the Wayfarer | spiral variant |
| Place banner | | full-width ribbon slides in | |
| Camera | | tilted 2.5D view (shader, off with reduced motion) | real 3D-looking buildings |
| Era change | white sweep | map unrolls from the middle, jingle, caption | |

### Era V - Living (Quivermoor)

| Feature | Exists | Added | Missing |
| --- | --- | --- | --- |
| Quivermoor atlas | yes | | |
| Menu skin | | mint palette, glossy rounded frame, large font | animated menu backgrounds |
| Text | | near-sine blip "blip_e5" with a glide, typing x1.4 | speaker portraits |
| Vigor bar | | glossy bar | |
| Place banner | | ribbon with a light sweep | |
| Overworld | | season tint by month, camera looks ahead while walking, idle breathing of all figures, stronger tilt | server-set season |
| Era change | white sweep | breathing wave runs down the screen, jingle, caption | |

## How it works

- `data/era_feel.json`: one row per era; the keys are listed in `EraFeel.KEYS`. `EraFeel.problems()` (and the GUT test) fail on a missing key, an unknown style, an extra that switches off again or a number that goes down.
- `EraManager._apply()` hands the era's palette, frame and font to `UITheme.set_era_skin()` (high contrast still wins), the walk cycle to `GridWalker`, and refreshes open menus.
- `EraFeelLayer` (overworld, between ground and people) draws the extras; `TownPopup` styles the place banner; the iris warp is `shaders/era_iris.gdshader`, the tilt `shaders/era_tilt.gdshader`.
- The era-change sequence (`EraUpgrade`, `shaders/era_upgrade.gdshader`) runs when an era opens, or, for an era opened by an older save, on the first visit to that era's region (`EraFeel.upgrade_due`, flag `era_seen_N`). The screen is already in the new era; the overlay shows the old era's resolution and colour levels (or the 4 inks) and gives way in the era's style, then the caption frame is redrawn in the new style. Reduced motion keeps the plain light fade. Settings > Display > "Replay era change" shows it again (only past Era I).
- Sounds: `tools/audio/sfx.py era_feel_sfx()`.
