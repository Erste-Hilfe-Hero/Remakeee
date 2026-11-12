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

## Still missing (follow-ups)

- Battle text box frame per era: shared with menus, so it belongs to the erafeel-ui slice.
- Weather visuals in battle: wait for erafeel-func's weather rules.
- Unfurl (evolution) sequence variants per era (`scripts/ui/UnfurlSequence.gd`).
- Status icons per era on the info strip (all eras use the same icon set now).
- Per-move hand-made effects for the Era II-V elements (Ink, Echo, Rust, Mask, Acid, Frost, Gilt,
  Zenith still borrow the nearest Era I element drawing, now in their own colour).
- Era III/IV fx art sheets (Era III+ load the Era II 8x8 shapes).
- Formation (multi) battles use the same sprite feel but no per-era layout change.
