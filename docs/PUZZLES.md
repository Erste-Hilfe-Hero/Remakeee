# Puzzles and riddles

Riddle stones and puzzle boards added in 1.3.2. Data: `data/puzzle_spots.json` (one entry per
puzzle, placed by map id and cell, so no map file changes). Logic: `scripts/overworld/PuzzleSpots.gd`;
board and prompts: `scripts/ui/PuzzleBoard.gd`; tablets: `scripts/overworld/PuzzleTablet.gd`.
Texts: `tools/i18n/de_puzzle_spots.py` (German) and `tools/i18n/locales_puzzle_spots.py` (12 more
languages). Tests: `tests/unit/test_puzzle_spots.gd`.

## Rules

- Each puzzle is solved once. Solving sets flag `pz_<id>` and grants the reward once.
- Wrong tries are counted in `GameState.records.puzzle_tries`. Hint 1 shows after 2 wrong tries,
  hint 2 after 4. A typed riddle offers its answers as a pick list after 5 wrong tries.
- Typed answers accept the player's language, English, the shown answer of the pick list and the
  common spellings listed in `answers`. Case, accents, articles, spaces and punctuation are ignored;
  full-width letters and katakana are folded.
- Chains: the parts give a clue line when solved. The last stone stays blank until every part is
  solved, then asks what the clues describe.
- Rewards are items, coins, lantern flames (Storm Lantern looks) and rare visitors: after the
  stone, about 1 in 10 wild encounters on the named map is that Spirling. Never Riftglass.
- Coordinates are map cells (x, y). Lamp grids count (x, y) from the top left. Slide solutions
  move the gap.

## Chains

- **Keeper's Stones** (Veydal): Quillbrook, Fernstair, Reedhaven, then the answer stone in Crowcrest. Answer: lighthouse.
- **Glassblower** (Ashmere): Gravers' Hall (push blocks), Saltglass Flats (riddle), then the will in Clinker Heath. Answer: glass.
- **Ledger Stones** (Quillmarch and Vellmarch): Ledgerholm, Platewick, Tallowmarket, then the answer in the Room of Names. Answer: book.

## Veydal

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| Keeper's Stone I `vey_keeper_1` | Quillbrook (2, 8) | Riddle (pick), chain keeper | A clock | 300 coins |
| Keeper's Stone II `vey_keeper_2` | Fernstair (4, 7) | Sound order, chain keeper | gold, green, blue, red | Tonic x3 |
| Keeper's Stone III `vey_keeper_3` | Reedhaven (3, 7) | Lamp grid, chain keeper | tap (x,y) (0,0) (2,2) (1,1), from the top left | Spark Drop x2 |
| The Keeper's Answer `vey_keeper_final` | Crowcrest (10, 18) | Riddle (type), needs vey_keeper_1 + vey_keeper_2 + vey_keeper_3 | "lighthouse" (or Leuchtturm, Leuchtturme in German) | lantern flame Keeper White, rare visitor Lanternel (ring 9) on Crowcrest, Kin Charm x1 |
| Tracks in the Mud `vey_tracks` | Gloamwood (3, 5) | Footprints | right right down down right down right right right down down down right down | rare visitor Hushkin (ring 8) on Gloamwood, 200 coins |
| The Four Lanterns `vey_lanterns` | Lantern Steps (5, 9) | Colour order | gold, blue, green, red | 250 coins, Remedy x2 |

## Ashmere

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| The Glassblower's Floor `ash_glass_1` | Gravers' Hall (3, 6) | Push blocks, chain glass | right down down right down left right right up (start 1,1) | Strong Tonic x2 |
| The Glassblower's Riddle `ash_glass_2` | Saltglass Flats (10, 21) | Riddle (type), chain glass | "ash" (or Asche in German) | 500 coins |
| The Glassblower's Will `ash_glass_final` | Clinker Heath (4, 11) | Riddle (type), needs ash_glass_1 + ash_glass_2 | "glass" (or Glas in German) | lantern flame Glassblower Green, rare visitor Puffglass (ring 36) on Clinker Heath, Echo Shell x1 |
| The Kiln Vents `ash_kiln` | Cinderfold (10, 7) | Lamp grid | tap (x,y) (0,0) (3,1) (1,2) (2,3) (3,3), from the top left | Cinder Stone x1, 300 coins |
| The Stationmaster's Riddle `ash_station` | Ashmere Station (5, 8) riddler | Riddle (pick) | A map | 400 coins, Remedy x2 |

## Corvane

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| The Dyers' Rhyme `cor_dye` | Madderby (3, 9) | Colour order | yellow, blue, red, black | lantern flame Woad Teal, 300 coins |
| The Pond Stone `cor_rain` | Stillwater (3, 5) | Riddle (type) | "rain" (or Regen, Regentropfen in German) | Dry Towel x3, 300 coins |
| The Rooks' Call `cor_rooks` | Greyreach (4, 6) | Sound order | grey, white, black, blue, grey | rare visitor Belfrit (ring 25) on Greyreach, Smelling Salts x2 |
| The Harbour Picture `cor_quay` | Corvane Quay (6, 15) | Sliding tiles | move the gap down right up left up left down down right up right down | Tide Charm x1 |
| The Woad Barrels `cor_barrels` | Woadfen (9, 11) | Push blocks | down down down down right right right up up up right up right down left left left left up left down down (start 1,1) | Tide Stone x1, 200 coins |

## Solenne

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| The Sun Tablet `sol_shadow` | Ochrewell (3, 13) | Riddle (pick) | A shadow | Focus Brew x2, 400 coins |
| Tracks in the Sand `sol_tracks` | Glasswind Flats (7, 17) | Footprints | right up up up right right right right down down right right up up up | rare visitor Highhare (ring 45) on Glasswind Flats, 400 coins |
| The Dome Mirrors `sol_mirrors` | Ama's Dome (2, 3) | Lamp grid | tap (x,y) (1,0) (0,2) (2,1), from the top left | lantern flame Dune Amber, Lumen Charm x1 |
| The Caravan Master's Riddle `sol_caravan` | Glasswind Caravanserai (6, 6) riddler | Riddle (type) | "water" (or Wasser in German) | Spring Flask x1, 300 coins |

## Quillmarch

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| Ledger Stone I `quill_ledger_1` | Ledgerholm (4, 13) | Riddle (pick), chain ledger | On the ninth day | 600 coins |
| Ledger Stone II `quill_ledger_2` | Platewick (10, 1) | Sliding tiles, chain ledger | move the gap up up left down down right up left left up right down left down right right | Spark Wash x1 |
| The Icicle Chimes `quill_icicles` | Rimeholt (1, 7) | Sound order | white, violet, blue, grey, violet | rare visitor Glacilet (ring 70) on Hoarfrost Moor, Pace Feather x1 |
| The Press Bed `quill_press` | Proofgate (7, 13) | Push blocks | right right up right up left left left left down left down right right right down right right up up left down right down left left (start 3,3) | Ward Talisman x1, 400 coins |
| The Postmaster's Riddle `quill_post` | Burin Landing (8, 10) riddler | Riddle (type) | "stamp" (or Briefmarke, Marke in German) | 500 coins, Wake Bell x2 |

## Vellmarch

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| Ledger Stone III `vell_ledger_3` | Tallowmarket (2, 15) | Lamp grid, chain ledger | tap (x,y) (0,1) (2,0) (1,2) (2,2), from the top left | Quiet Wick x1 |
| The Ledger's Answer `vell_ledger_final` | Room of Names (6, 3) | Riddle (type), needs quill_ledger_1 + quill_ledger_2 + vell_ledger_3 | "book" (or Buch, Bücher in German) | lantern flame Ledger Ink, rare visitor Fauxscript (ring 59) on Tithe Road, Growth Charm x1 |
| The Lock Gates `vell_locks` | Weeping Locks (9, 4) | Colour order | green, grey, red, white | Murk Stone x1, 500 coins |
| The Mask Maker's Riddle `vell_masks` | Larkspur Heights (3, 12) riddler | Riddle (pick) | A mask | Mask Charm x1 |
| Tracks in the Reeds `vell_tracks` | Bellrope Marsh (8, 6) | Footprints | down down down right right down down right right up up up up right right down down right | rare visitor Hushbeak (ring 60) on Bellrope Marsh, 500 coins |

## Halcyra

| Puzzle | Where | Kind | Solution | Reward |
|---|---|---|---|---|
| The Ridge Orrery `hal_orrery` | Orrery Ridge (5, 9) | Colour order | red, gold, blue, white | lantern flame Star Silver, Zenith Charm x1 |
| The Starwell Tablet `hal_star` | Starwell (6, 6) | Riddle (type) | "star" (or Stern, Sterne in German) | Lantern Glass x1, 600 coins |
| The Flat Mirrors `hal_mirrors` | Mirror Flats (5, 10) | Lamp grid | tap (x,y) (1,0) (2,1) (0,2) (3,2) (1,3) (2,3), from the top left | Gilt Charm x1, 500 coins |
| The Wind Chimes `hal_chimes` | Cloudshadow Meadow (7, 11) | Sound order | green, gold, white, violet, blue, gold | rare visitor Eavekit (ring 83) on Cloudshadow Meadow, 500 coins |
| The Gilt Tiles `hal_tiles` | Gildcrest (2, 13) | Sliding tiles | move the gap up up left down left down right right up left down left up right up right down down | 800 coins |
