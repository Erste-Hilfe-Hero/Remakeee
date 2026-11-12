# Era look: Spirling sprite tiers

Owner rules: a Spirling keeps the look of its origin era forever. In an Era V battle every
Spirling moves, each in its own old style. Stages of a line look alike. Back sprites, menu icons
and Gleam forms exist for every tier.

A kind's tier is the era folder its art lives in (`art/eraN/spirlings/`). The front and back
sprites are drawn by the era generators (`gen_spirlings.py`, `gen_lines.py`, `gen_era2.py` ...
`gen_era5.py`). Everything else is built from those two files by one script, so no frame is drawn
by hand:

    python3 tools/art/gen_tiers.py              build icons and pose sheets for every kind
    python3 tools/art/gen_tiers.py --check      CI: fails when a file is missing or stale
    python3 tools/art/gen_tiers.py --sheet DIR  contact sheet and GIF per era
    python3 tools/art/tier_coverage.py          coverage table per era

After adding or changing a front/back sprite, run `gen_tiers.py` and commit the new files.

## The tiers

Rules live in `data/sprite_tiers.json`, read by `scripts/battle/presenter/SpriteTiers.gd`.

| Tier | Canvas | Colours | Poses in the sheet | Era V battle: idle / attack / hit |
|---|---|---|---|---|
| I Ink | 56 | 4 inks | rest, hop | 2-frame hop / hop forward (3 frames) / blink (4) |
| II Wash | 56 | up to 8 | rest, hop | 2-frame hop / wind back, hop forward (4) / blink with a step back (4) |
| III Etched | 64 | up to 15, coloured outline | rest, hop, lean | 2-frame hop / lean in (5) / white flash (4) |
| IV Panorama | 96 | up to 24 | rest, breath, lunge, recoil | idle + breath / recoil, lunge (6) / flash and recoil (5) |
| V Living | 96 | up to 32 | rest, breath 1, breath 2, crouch, lean, lunge, recoil, sag | 6-frame breathing loop / crouch, lunge (7) / flash, recoil, sag (7) |

Each tier has at least as many poses and frames as the one before
(`tests/unit/test_sprite_tiers.gd`).

## Files per kind

- `art/eraN/spirlings/<id>_front.png`, `<id>_back.png`: the drawn sprites (not made here).
- `art/eraN/spirling_icons/<id>.png`: menu icons of 14, 16 and 32 px side by side. Each icon pixel
  takes the most common colour of its block; a block that is mostly outline stays outline.
  `MiniSprite.of()` uses them for these sizes (party rows, the Inkshadow, the summary page).
- `art/eraN/spirling_anim/<id>.png`: the pose sheet. Row 0 front, row 1 back, one cell per pose.
  A pose is a nearest-pixel remap of the sprite (stretch about the feet, lean forward, squash), so
  it only holds colours of its sprite: an Era I kind stays in four inks. An Era IV breath frame
  from `gen_era4.py` (`<id>_front_b.png`) is used as the breath pose when it exists.

Timelines (which pose, how many pixels forward or up, per frame) are data, not pixels: the sheet
of an Era I kind is 112 x 112 and about 0.9 KB.

## In the game

- Era V battles (`anim_from_era`): `SpirlingSprite` plays the pose sheet of the kind's own tier.
  Kinds without a sheet keep the runtime strips of `BattleAnim`.
- Forward follows the sprite: the foe strikes to the right, the player's Spirling to the left.
- Era IV battles: kinds of tier IV and V without a drawn breath frame breathe with the sheet's
  breath pose.
- Reduced motion: the rest pose only, no blink, no flash, no offset.
- Gleam: the shader sits on the sprite node, so every pose is recoloured like the base. Era I
  kinds swap the four inks (`gleam_palette.gdshader`). Later tiers are not drawn in inks, so the
  swap did nothing for them; they now turn their hues (`gleam_hue.gdshader`, about half a turn,
  spread a little per line). The turn is keyed by the line id and stages share base colours, so
  every stage of a line gleams in the same colours.
- Lines: derived files only reuse the colours of their sprite, so a line that looks alike in its
  sprites looks alike in icons and poses (tested on the icons).

## Coverage

Before this slice no kind had an icon or a pose sheet (0 / 0).

COVERAGE_TABLE

## Left open

- Era IV (Halcyra) and Era V (Quivermoor) kinds are not in `data/spirlings.json` yet. Their
  icons and sheets are built from the art of their own PRs; run `gen_tiers.py` again when that
  art changes.
- Menu icons do not show the Gleam colours and do not bounce.
- Under the Era I retro filter a hue-turned Gleam of a later tier differs less than an ink Gleam.
