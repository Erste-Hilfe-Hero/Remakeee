# Era feel: figures on the map

The owner's request: the game should feel like it starts on the genre's first handheld and gets
more modern era by era, up to the fifth generation. This page covers the figures on the map: the
Wayfarer, villagers, Tamers, and the Spirling that walks behind. Menus, text boxes, banners and
map extras (water shimmer, footprints, reflections, tilt, camera) belong to `docs/ERA_FEEL_UI.md`;
battles to `docs/ERA_FEEL_BATTLE.md`; sound to `docs/ERA_FEEL_AUDIO.md`.

Config: `data/era_actor_look.json`, read by `scripts/overworld/EraActorLook.gd` (table, poses,
drawing) and `scripts/overworld/EraActors.gd` (the live node in the overworld). Art:
`tools/art/gen_era_chars.py` writes `art/era3..5/actors/<figure>.png`, the bubbles
`art/era2..5/actors/emotes.png` and `data/era_actor_zones.json`. Tests:
`tests/unit/test_era_actor_look.gd`. Screens: `tools/era_chars_shots.gd`.

## How map figures changed across the five handheld generations

Described in general terms. Chimora copies none of these, only the jump in technology.

| | Gen 1 | Gen 2 | Gen 3 | Gen 4 | Gen 5 |
|---|---|---|---|---|---|
| Sprite | 16 px, 4 shades | 16 px, a few colours | more colours, shading | taller figures, more detail | same, animated |
| Walk | 2 frames, slides tile by tile | 2 frames | left and right foot, running | smoother steps | steps blend into turns |
| Standing | still | still | still | heads follow the hero | breathing, blinking |
| Reaction | "!" over a trainer | more bubbles | bubbles with a tail | bubbles with depth | animated bubbles, by the moment |
| Ground | none | none | reflection in water | drop shadow | drop shadow |
| Companion | none | none | none | walks behind | walks behind |
| Water | none | none | own riding sprite | same | same |
| Clothes | fixed | fixed | fixed | fixed | change with the season |

## Chimora per era

| Feature | I Ink | II Wash | III Etched | IV Panorama | V Living |
|---|---|---|---|---|---|
| Sheet | 16x16, four inks (existed) | 16x16, four colours per figure (existed) | **16x16, zone colours, 3 tones per zone** | **16x24, coloured outlines** | **16x24, rim light** |
| Walk frames | 2 (existed) | 2 | **3: left and right foot** | **4: half and full step per foot** | 4 |
| Movement | **slides in 2 px jumps** | **2 px jumps** | every pixel | every pixel | every pixel |
| Running | hold the cancel key (existed), walk frames | same | **own running poses, head forward, arm swing** | same, taller | same |
| Crossing water (wading boots) | hop (existed) | hop | **on a reed float, no hop** | float | float |
| Shadow | none | none | none (reflection: `ERA_FEEL_UI.md`) | **drop shadow** | drop shadow |
| Bubbles | ink "!" box, ink label in scenes (existed) | **flat colour bubbles: ! ? ... heart note** | **bubble with tail and shade, pops in** | **bubble with drop shadow and gloss** | **two-frame bubbles, plus sleep and rain drop** |
| What shows a bubble | Tamer sight | **+ talk (note), beaten Tamer (...)** | same | **+ turning to your Spirling (heart)** | **+ a villager notices you: by night, rain or mood** |
| Villagers | glance around (existed) | same | same | **turn only the head to the Wayfarer within 2 tiles** | within 3 tiles |
| Spirling behind | ink shadow, jumps a tile (existed) | same | same | **own colours, walks the tile with a hop, drop shadow, faces its way** | **+ slow breathing** |
| Idle | still | still | still | still | **breathing and blinking, each figure on its own beat** |
| Turning | at once | at once | at once | at once | **a quarter turn leads with the head (one blend frame)** |
| Outfits | fixed | fixed | fixed | fixed | **spring, summer (short sleeves), autumn, winter (scarf) by the month** |
| Wayfarer's own look | skin, hair and coat as ink tones (existed) | not shown (the four-colour sheet has no slot for it) | **skin tone, hair and coat colour painted into the sheet** | same | same |

Nothing is taken from an era: `EraActorLook.problems()` (and the test) fail when a later era
switches a feature off, shrinks a number, loses a bubble, a trigger or a pose.

Running is not held back to Era II. Era I has had it since the first build, and four acts of story
are walked in Era I, so taking it away there would cost the player more than the era flavour gains.
What changes with the eras is how running looks.

The movement model is four directions on a grid, so there are no diagonal steps. Era V gets the
eight-direction look from the head: on a quarter turn the body is drawn in the old direction with
the head already in the new one for 70 ms.

## How it works

- `data/era_actor_look.json`: one row per era, keys in `EraActorLook.KEYS`. `rows` names the sheet
  row of every pose; `step_seq` lists the poses of one tile step.
- `GridWalker._draw()` asks `EraActorLook.draw_actor()` first. In Eras I and II it answers no and
  the walker draws its 64x32 sheet as before. From Era III it draws the pose from
  `art/eraN/actors`. A figure without a sheet there falls back to the old drawing.
- `EraActors` is one node in the overworld, after the figures in the tree. Each frame it picks the
  pose of every figure and redraws it when the pose changes, applies the era's pixel jump, turns
  heads, keeps the bubbles and moves the Spirling behind. `NPC.alert`, a talk and the scene step
  `{"emote": who, "icon": ...}` all end in a bubble of the era.
- The sheets are built from the Era I sheets: every ink of a figure belongs to a zone by where it
  sits (hat or hair, band, skin, top, trim, trousers, shoes), each zone has its own colour, and the
  light comes from the top left. The 16x24 figures get new legs and a longer body. So a figure
  added to `art/era1/chars` needs one palette line in the generator to exist in every era.
- The Wayfarer's look: the generator writes which sheet colours are skin, hair and coat
  (`data/era_actor_zones.json`), and `EraActorLook.player_sheet()` repaints them once per look.
  The coat is the player's own in every season; scarf, sleeves, trim and trousers still change.
- Reduced motion: no breathing or blinking, no blend frame, bubbles neither pop nor bob, the
  Spirling behind does not hop or breathe. The walk cycle, head turns and bubbles stay.

## Not done

- Diagonal movement (the grid is four-way), region outfits (seasons were chosen), drawn water
  reflections of the taller figures (tiles slice).
- The map sprite "hush" has no sheet in any era and is drawn as the old coloured box.
- The Spirling behind is the battle sprite scaled to 16 px, not an own walking sheet per kind.
