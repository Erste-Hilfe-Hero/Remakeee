# Era feel: text, speakers, spiral warp

Part of the era look (see `docs/ERA_FEEL_UI.md`). The handheld generations did not only add colour: the letters grew finer and larger, later games showed who was speaking, and map changes got their own wipes. This page covers those three steps. Everything is data in `data/era_text.json`, read by `scripts/core/EraText.gd`; Eras I and II are left exactly as they were.

| Era | Font | Speaker in the dialogue box | Door warp |
| --- | --- | --- | --- |
| I Ink | Chimora Pixel, 8 px (5x9 cell) | name tag | door rectangle |
| II Wash | Chimora Pixel, 8 px | name tag | door rectangle |
| III Etching | **Chimora Etch, 10 px** (6x10 cell) | name tag | **spiral of ink** |
| IV Panorama | **Chimora Panorama, 12 px** (7x12 cell) | **12 px head on the name plate** | iris |
| V Living | Chimora Panorama, 12 px | **32 px portrait that blinks and speaks** | iris |

The era on screen decides (the newest open era, or the older one picked with the Retro filter), the same as for the rest of the UI skin: with the Retro filter on Era I the pixel font, the plain name tag and the door rectangle are back.

## Fonts

- Both fonts are our own, drawn glyph by glyph in `tools/fonts/src/etch10.txt` and `pano12.txt` (one line per glyph, rows of `#` and `.`). `python3 tools/fonts/build_era_fonts.py` checks the sheets and writes `scripts/ui/EraFontGlyphs.gd` plus a specimen picture of each font in `art/fonts/`. `--check` fails when the generated file is stale.
- `EraFont` builds a bitmap `FontFile` from a table at runtime, like `PixelFont`. The fonts answer to the same font size (8), so no screen needs new sizes; Era III already has a 180x320 screen and Eras IV and V 270x480, so the larger letters fit the same layouts.
- They draw English and German: A-Z, a-z, digits, punctuation, Ä Ö Ü ä ö ü ß (104 glyphs each). Every other character falls back to the pixel font behind them (small behind the 10 px font, large behind the 12 px font) and from there to the CJK fonts. A language other than English and German keeps the pixel font for the whole text (`"languages"` in the data file), so accented and Cyrillic words are never set in two fonts.
- The Large text option beats the 10 px font (the large pixel font is 12 px); in Eras IV and V it changes nothing, the era font is already that size.
- Wiring: `EraManager._apply()` calls `EraText.set_era()`, `UITheme.font()` asks `EraText.font()` first. The theme's default font carries it to the dialogue box, the menus and the battle text; `UITheme.get_theme()` rebuilds when the font changes (era or language).

## Speakers

- `"speakers"` lists 30 speaker ids with the names they are shown under ("Mother Grell", "Warden Senna", "Veit Harrow"): the Wayfarer's circle (Kestra, Aldo, Mirela, Corin, Veit, Ysolde), the ten story wardens, the six clan heads and the wardens of Halcyra and Quivermoor. `EraText.speaker_id()` matches the whole name first, then single words.
- Art: `python3 tools/art/gen_portraits.py` draws every speaker from a recipe (skin, hair or headwear, brows, eyes, mouth, coat, extras such as a scar, glasses, a beard): `art/era5/portraits/<id>.png` is a 96x32 sheet of three busts (resting, eyes shut, mouth open), `art/era4/portraits/<id>.png` the 12 px head. The script stops when the speakers in the data file and its recipes differ.
- `SpeakerPortrait` is a child of every `TextBox`. Era IV: the head sits on the name plate and the name moves right. Era V: the portrait stands on the right end of the box in the era's frame (under the box when the box is at the top of the screen), blinks every few seconds and moves its mouth while the line types. A box inside a layout (the battle screen) has no room above it and shows the small head in Era V too.
- A speaker without an entry, an unnamed line and every speaker in Eras I to III get the plain name tag.
- Reduced motion: the portrait neither blinks nor speaks nor fades in.

## Spiral warp

Era III door warps wind two arms of ink in around the Wayfarer until the screen is covered (`shaders/era_spiral.gdshader`, `EraWarp.spiral_close`). Arms, turns and duration are in `"spiral"`. With reduced motion `Overworld._warp_out` keeps its plain fade (`EraText.warp(era, base, reduced)` says "fade"). Eras IV and V keep the iris, Eras I and II the door rectangle.

## Shots

`tools/era_text_shots.gd` renders the dialogue box and the place banner on a patch of meadow:

- `-- compare` checks Eras II to V in English and German against `tests/golden/era_text/` (the UI golden workflow runs it and warns on a difference), `-- update` rewrites the goldens.
- `-- shots DIR` writes 2x review pictures of all five eras and the spiral half closed.

## Tests

`tests/unit/test_era_text.gd`: the table, glyph coverage and metrics, which language and era gets which font, speaker lookup, the head and the portrait per era and box, frames and reduced motion, the spiral.
