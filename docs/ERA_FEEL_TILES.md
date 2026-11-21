# Era feel: overworld terrain

Owner wish (2026-11-12): each era's maps look one handheld generation newer. `docs/ERA_FEEL_UI.md` (PR #467) covers menus, text, warps, the place banner, the Wayfarer's own reflection and footprints, leaves from tall grass, the screen tilt, the season tint and the camera look-ahead. The tint of the hour, weather looks, cloud shadows, lamp glow and the people's own shadows belong to the light slice (`data/era_light.json`). This page covers the ground itself: how tiles are drawn, shaded, layered and animated.

Data: `data/era_overworld_look.json`. Code: `scripts/overworld/EraTerrainLook.gd` (one node above the ground tiles plus a canopy layer above the people). Art: `tools/art/gen_era_raised.py` writes `art/era<N>/tiles/raised_<region>.png` (trees, lamps, towers, signs, fences and rocks cut out of their grass, every pixel from the region's own atlas).

A map takes the tier of its region's era, capped by the era on screen (Retro filter). The four story acts stay Era I maps for good; Vellmarch is II, Quillmarch III, Halcyra IV, Quivermoor V.

| Tier | Region | What the terrain does |
| --- | --- | --- |
| I Ink | Veydal, Corvane, Ashmere, Solenne | 4 inks, flat tiles. Open water and flowers swap between 2 frames (the tile mirrored), every 0.8 s. Nothing else moves. |
| II Wash | Vellmarch | Era II colour atlas. 2 frames, a little faster: open water and wading water swap, flowers and tall grass nod by one pixel. |
| III Etching | Quillmarch | 4 frames. Water drifts out and back, tall grass, flowers and reeds swing both ways. Ragged tufts of grass reach onto paths, scree and stairs; water gets a bank line with moving foam; trees, towers, lamps, rocks, signs and fences are mirrored in the water below them, fading with depth; ground next to anything tall gets a contact shade. |
| IV Panorama | Halcyra | Everything of III. Trees, buildings, towers, lamps, cliffs, signs, fences and rocks cast one merged drop shadow whose direction and strength follow the time of day (west in the morning, east in the evening, faint at night). Tree crowns, roof ridges and cliff lips are drawn over the people, so walking behind them hides your feet. |
| V Living | Quivermoor | Everything of IV. 8 frames with a wave that travels across the map: plain grass and tree crowns sway too. Pennants fly from free tower tops and from the ridge over every house door (healer and shop in their own colours). Tall things lean a few pixels away from the view centre as you walk (depth), bridges throw a shadow on the water that shifts the same way, and the view eases in from a little wider when you walk into a town. |

Rules the data keeps (`EraTerrainLook.problems()`, `tests/unit/test_era_overworld_look.gd`): every era is configured; a switch never goes off again in a later era, a number never goes down, an animated kind never stops; Era I has at most 2 frames and animates only water and flowers.

Reduced motion: every tile stays on frame 0, the lean is zero and the town zoom is off. Shadows, layering, edges and reflections stay, since they do not move. With the day cycle switched off (Display) the shadows stay at their midday angle.

Screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_tiles_shots.gd -- out_dir` renders maps of each era's region without and with the look.

Still missing: drawn animation frames per atlas (the frames are made from the one drawn tile), building walls taller than one tile, shadows on the people themselves.
