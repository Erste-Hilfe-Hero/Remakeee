# Era feel: the battle screen

The owner's request: the game should feel like it starts on the first handheld monster-taming
game and gets more modern in-game, up to the fifth generation. This page covers the battle screen.
Menus, the overworld and the era-change sequence belong to the erafeel-ui slice. Gameplay
unlocked per era belongs to the erafeel-func slice. Nothing here changes a battle rule or damage
maths.

Config: `data/era_battle_feel.json`, read by `scripts/battle/presenter/EraBattleFeel.gd`
(`EraManager.battle_feel(key)` gives the active era's value). Tests:
`tests/unit/test_era_battle_feel.gd`. Screens: `tools/era_battle_shots.gd`.

## How battle presentation changed across the five handheld generations

Described in general terms. Chimora copies none of these, only the jump in technology.

| Area | Gen 1 | Gen 2 | Gen 3 | Gen 4 | Gen 5 |
|---|---|---|---|---|---|
| Screen | 4 shades | limited colour, few colours per sprite | 16-bit rich palette | two screens, bigger sprites | same, higher detail |
| Intro wipe | screen flashes, then bands or a spiral | same family, more patterns | flashes, then bars or shards | swirls, circles, 3D-feeling wipes | the camera swoops into the field |
| Sprites | static, front and a small back sprite | static, entrance cry | static, some first-frame entrance motion, flash when hit | 2-frame entrance animation, bigger back sprites | animated all the time, bigger back sprites |
| Send-out | sprite grows from a puff | same, coloured | burst of light, silhouette fades into colour | burst, particles, sprite lands | burst, sprite animates in, camera follows |
| Background | none or plain | plain | art per terrain with platforms | 2.5D field with platforms and depth | 3D-feeling field with depth and lighting |
| HP bar | drains at a fixed pixel pace, plain bar | colour states (green, yellow, red) | framed, gradient | slanted, styled | styled, smooth |
| EXP bar | none on the battle screen in the first game | added | styled | styled | styled |
| Move animations | a few generic flashes, screen inversions | more per-move animations | per-move effects, more colour | particles and layered effects | particles, camera moves and zooms |
| Screen shake | some moves | some moves | more | more | constant camera motion |
| Shadows | none | none | under sprites | on the field | on the field |
| Faint | sprite drops out of sight | same | sinks and fades | sinks with effect | animated collapse |
| Catch / level-up / evolve | text, simple wobble | text and small effects | sparkles, glow | particles, light rays | full sequences, camera |
| Camera | fixed | fixed | fixed | slight pans in some moves | dynamic zoom and pan |
| Music | square-wave chip | richer chip | sampled 16-bit | fuller instruments | orchestral feel |

## Chimora per era: what exists and what is missing

Era I = story acts 1-4. II = Vellmarch, III = Quillmarch, IV = Halcyra, V = Quivermoor. A Spirling's
art always stays in its origin era (`EraManager.sprite_path`). How the battle moves follows the
battle's own era.

| Feature | I Ink | II Wash | III Etched | IV Panorama | V Living | Status |
|---|---|---|---|---|---|---|
| Screen palette | 4 inks (filter) | colour | colour, 180x320 | 270x480 | 270x480 | existed |
| Battle music | era theme | era theme | era theme | era theme | era theme | existed (#398, #408) |
| HP bar look | patterns | traffic colours, blink | frame, gradient | slant | soft trail | existed (#367) |
| HP drain | **fixed pace (step)** | **fixed pace** | **eased** | eased | eased | **new** |
| Intro wipe | **blinds + 2 pulses** | **spiral + 2 pulses** | **shutter + 1 pulse** | **iris + 1 pulse** | **diagonal swoop + camera pull-back** | **new** (`BattleIntro.gd`) |
| Entrance | **pop-in in 3 growth steps** | **slide + bounce** | **slide + silhouette fades to colour** | **slide + land squash + dust** | **land + live strip** | **new** (slide + motion profile existed) |
| Idle | **still** (was a 1 px bob) | **still** | **still** | breath frame, **or squash breathing** | constant strip loop | **changed / new** |
| Hit reaction | blink | blink | **white silhouette flash** | **white silhouette flash** | hit strip | **new** for III/IV |
| Backdrop | ink terrain art | **flat colours per terrain** | **banded sky gradient, richer colours, bank highlight** | 2.5D stage, **tinted per terrain** | stage + terrain tint | **new** for II, III, IV/V terrain |
| Sprite shadow | none | none | **flat dithered shadow** | **shadow** | **shadow** | **new** |
| Art animation | element shapes in inks | **element colours** | **+ art style shape at impact** (11 styles) | **+ field tint, ground shadow on projectiles, quake shake** | **+ afterimage trail, camera** | **new** (element effects existed) |
| Screen shake | **x0.6** | **x0.75** | x1 | x1 | **x1.2** | **new** |
| Camera | fixed | fixed | fixed | **mild pan (zoom 1.06)** | dynamic (zoom 1.18) | IV **new**, V existed |
| Faint | **drops in 4 hard steps** | **drops** | sinks and fades | **sinks + dust** | **folds flat + dust** | **new** |
| Bond success | **blinks out** | hop | **hop + glints** | hop + 6 glints | hop + 8 glints | **new** |
| Level-up | **text only** | ring | **ring + glints** | ring + 6 glints | ring + 8 glints | **new** |

Every art (all 190) gets an animation in every era: element look + kind + one of 11 styles (slash,
bite, beam, wave, burst, quake, volley, spiral, strike, orb, aura). The style comes from a word in
the art's name, else from its kind (`move_style_words`, `kind_default_style`). An entry in
`move_style_overrides` can set a style by hand.

Accessibility: under reduced motion the intro only fades and never pulses. Entrances slide plainly,
faints sink, glints, dust, field tints and the camera stay off, and a hit is a soft dim. Intro
pulses run at most 3 a second at half strength. The field tint stays at 22 % or less. The
colour-blind HP patterns are unchanged.

## Slice 2 (follow-up PR)

- The later-era elements have their own drawings now: Ink blot and splat, Echo rings, Rust
  flakes, Mask face and grin, Acid bubbles and puddle, Frost crystal and spikes, Gilt coins, Zenith
  light pillar. Before, they borrowed an Era I element.
- Banks per terrain from Era II: lake stepping stones with water at the foot, ridge cut stone,
  ember basalt with glowing cracks, voice motes, field grass (thicker from Era III). The Era IV/V
  stage slabs take terrain colours.
- Unfurl (evolution) per era: ink on parchment (I), colour wash (II), banded light (III), turning
  rays (IV), rays with rising motes (V). White glowing silhouettes from Era II, the sprite grows to
  the era's battle size, and from Era III a ring rises at the reveal.
- Status tag from Era II: a coloured badge (Era I keeps plain ink letters).
- Era V: every Spirling moves, whatever its origin era (tested on one Spirling from each era that
  has art).

## Slice 3 (follow-up PR)

- Weather in battle (era function `sky_battles`, #465): when the region's sky lays the field, rain,
  fog or a storm shows over the field (`BattleWeather.gd`). Era I has a few ink dots, and each era
  after that adds more, longer, slanted coloured streaks. From Era IV there are splashes at the
  ground and a rare distant flash in a storm (22 % at most, once every 4 s). Fog is drifting
  bands. Under reduced motion the drops stand still and nothing flashes. Rift fields show nothing
  extra.
- Own effect art for Era III (10 px: outline, body tone, light edge) and Era IV (18 px: doubled,
  rounded, shaded, soft glow) from `tools/art/gen_fx_era34.py`. Era V uses the Era IV set. Shapes
  are centred by their size.
- Formation battles per era (`BattleScene.formation_slots`): Era I/II use 28 px sprites in a flat
  rank, Era III 32 px, Era IV 40 px and Era V 44 px. From Era IV every second Spirling stands a
  step back, so an Era V triple bows its middle back. On the stage the slabs widen to hold the
  whole rank.

## Slice 4 (follow-up PR)

- Formation shots fixed: `tools/era_battle_shots.gd` now waits until the command menu is open, so
  every Spirling has stepped out, and renders 1v1, 2v2 and 3v3 in all five eras
  (`-- out_dir formation`). Looking at them showed two faults, both fixed and tested
  (`tests/unit/test_era_battle_feel4.gd`): on the short Era I/II field with the menu open the foe
  and player ranks of a triple ran into each other (`BattleScene.formation_fit` now shrinks both
  ranks just enough and lifts the foe rank under the strip), and on the Era IV/V stage the foe rank
  hung in the sky above the horizon (`BattleScene.drop_to_floor` stands it on the foe slab). Tags
  of shrunken sprites no longer overlap (`formation_step`).
- Wind in battle: a windy sky still lays no field and changes no rule (#465), but the overworld
  marks the battle (`BattleWeather.SKY_META`) and `BattleWeather` draws drifting wind lines: 5
  short ink dashes moving in 2 px steps in Era I, leaves from Era II, wavy lines from Era III,
  bigger leaves and rolling dust from Era IV and gusts in Era V ("wind_*" keys). Under reduced
  motion the wind stands still but stays visible.
- Move polish per era (`EraMoveFx.gd`, "move_fx" and per-era keys in `data/era_battle_feel.json`):

| Feature | I Ink | II Wash | III Etched | IV Panorama | V Living |
|---|---|---|---|---|---|
| Send-out | ink puff, 3 steps | colour puff, 4 steps | light burst | burst + sparks | burst + sparks + ring |
| Hit mark | ink cross | star | star + ring | star + ring + sparks | star + ring + shards |
| Lunge | there and back in 2 hard steps | 2 hard steps | eased | stretch 10 % | stretch 14 % |
| Stat change | text only | 2 arrows | 3 arrows | 4 arrows | 6 arrows |
| Faint motes | none | none | 3 | 5 | 8 |

  Under reduced motion send-out, hit marks and motes are off; stat arrows stay but stand still
  (they carry information). Era I/II effects play in hard steps, later eras move smoothly.

## Slice 5: Era IV and V redone (owner: "Era 4 und 5 gefallen mir nicht")

Before, Era IV and V stood on a pale plain with a perspective grid and beige slabs, the
Spirlings were small on the wide screen and the two eras looked the same in a still. Now
(`data/era45_stage.json`, `scripts/battle/presenter/Era45Look.gd`, `Era4Stage.gd`, tests
`tests/unit/test_era45_look.gd`, shots `tools/era_battle_shots.gd -- out_dir scenes`):

| Feature | IV Panorama | V Living |
|---|---|---|
| Backdrop | painted scene in layers: sky in bands, distant and far ranges with a lit rim, a mid row (trees, roofs, pines, rocks, reeds), a textured floor; no grid lines | the same scene at golden hour: every colour washed warm, a glowing horizon, a low sun |
| Scene | from the map's biome and the battle terrain: meadow, cave, water, town, snow (ridges), ember, voice | same |
| Slabs | flat-topped turf, rock, stone, paving, snow or basalt blocks with cut corners, a side wall with strata and a ragged foot, tufts hanging over the lip and a soft shadow (never oval, LEGAL.md) | the same with a warm rim on the sun side and a long shadow away from the sun |
| Spirling size | whole multiples of the art: player aims at 160 px, foe at 104 px, at most 192 (56 px art: 168 / 112, 64 px: 192 / 128, 96 px: 192 / 96); the foe stands back right, the player low left with its slab in front | same |
| Motion | none (still clouds and grass) | drifting clouds, swaying grass, shimmering water, rising embers, twinkling snow; slow sun rays |
| Light | daylight from the upper left | warm wash, sun rays and soft edges over the whole field, sprites included |
| Camera | mild pan on arts (existing) | arts zoom (existing) and a 1.08 lean-in when a Spirling steps out |
| HUD font | bold large font (doubled strokes, `PixelFont.get_bold_font`) | same |

The player's plate keeps at least 46 % of the field width beside the big back sprite. The HP
bars stay 5 px (1.7x Era III): a thicker bar would push the formation ledger into the foes' rank.
Old Spirlings keep their origin-era art, only drawn bigger. Under reduced motion the stage
stands still, there is no send-out camera, and the light holds still.

## Slice 6: Era IV and V round 2 (owner 13 Nov: "era 4 und 5 sind irgendwie größer als davor")

- Size (owner 13 Nov: "kleiner, etwa wie Era III"): the Spirlings take about the share of the
  screen they had in Era III (64 of 180 px = 96 of 270), as the nearest whole multiple of their
  art, both sides alike (`data/era45_stage.json` sprite: 96 / 96, max 112): 56 px art 112,
  64 px art 64, 96 px art 96. The slabs shrank with them; the era upgrade is the painted scene,
  light and effects, not size. Art rows are 28 px (the smallest Era IV touch row).
- Command column: the commands and the item shortcut stand in a column beside the arts
  (`data/era_battle_hud.json` commands "column"), so the arts stay one column but the panel is
  about 50 px lower and the painted field about 300 px tall instead of 250.
- Vigor bar: 8 px on the two plates of a one-on-one battle (`bar_h_single`); the formation
  ledger keeps `bar_h` (5 px), so the foes' rank does not move.
- Tests: `tests/unit/test_era45_round2.gd`, `test_era45_look.gd` (size between Era III and slice 5).

## Still missing (follow-ups)

- Battle text box frame per era: shared with menus, so it belongs to the erafeel-ui slice.
- Hand-drawn Era IV/V art for the Spirlings that have none yet (they show the placeholder, so they
  get no Era V strip). Era V art for 70 Quivermoor Spirlings exists but has no species data yet.
