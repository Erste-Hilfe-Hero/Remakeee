# Veydal, Act I: "The Hush of Veydal"

Story and map rules for Chimora's first region (approved by Ali on 2026-11-01). The goal is a
world that does not follow the classic monster-RPG template. Check new content against the
"Avoid" list before adding it.

## Story

- The player is an apprentice **valley cartographer** who lives with their grandfather **Aldo**,
  the old ferryman, in the **Brindlewick lighthouse**. There is no parent at home, no professor and no lab.
- On the first night a storm tears open a Rift over the lake. Three frightened Spirlings that
  live by light (Kindlop, Zippit, Wickit) follow the lighthouse lamp out of the storm; one of
  them stays with the player. They are deliberately not a fire/water/grass triangle.
- Open Rifts spread **the Hush**: nearby Spirlings fall silent and lose their bond with people.
  Wild Spirlings near a Rift are "hushed".
- **Wardens** are keepers of the Rift hollows whose own bond has broken. Battling them wakes
  their Spirlings and their bond; afterwards the Warden helps the player **mend** the Rift.
  There are no badges; progress is the redrawn map and mended Rifts.
- **Kestra** is a fellow cartographer who believes the Rifts should stay open because new
  Spirlings come through them. She is a counterpart with her own fixed team, not a rival who
  counter-picks the player's starter. She duels the player once in Act I (Crowcrest) and meets
  them at the ferry dock after both Rifts are mended.
- There is no villain team. The antagonist is the Hush itself.
- A third Rift, the **Mist Rift** (Warden Brisa), opens east of Crowcrest. Kestra waits at the
  ferry dock once all three Rifts of Veydal are mended (flag `veydal_rifts_mended`).
- End of Act I: the three Rifts mended, a larger Rift lies north, the ferry to Corvane (Era II) waits.

## The First Voices (plan area 1, items 152-155)

- Long before the Rifts, six ancient Spirlings sang together, and their song held the land
  together: rivers kept their beds, hills kept their shape, and Spirlings and people understood
  each other. They are the **First Voices**.
- One by one the Voices fell silent. Nobody knows why yet. Their silence is where **the Hush**
  began: the Rifts open where a Voice used to sing, and the Hush spreads from there.
- Each region has its Voice. **Velahra** (Lumen/Tide) is the Voice of Veydal. It sleeps as a
  light under the lake in front of the Brindlewick lighthouse and was the last one to see
  **Mirela**, the cartographer whose map book the player follows. The Voices of Corvane, Ashmere
  and Solenne (Act IV, town Ochrewell) wait in their regions; two more are not named in the map book at all.
- A First Voice is met once, at a fixed place, never in the wild tables (DataValidator checks
  that ancient kinds only appear in a fixed meeting). Bonding is the same Echo call as always,
  with a longer call and a second phase, and no throw, aim or chance display (LEGAL.md).
- A meeting that ends without a bond is never lost: the Voice sinks back and rises again at
  the same place after the player's next rest (`FirstVoices.after_rest()`).
- Velahra appears on the Brindlewick lake shore after the finale in the lamp room
  (flag `mirela_lamp`), at Ring 40, with its own battle backdrop ("voice": the lake at night
  with columns of light).

## Map design rules

- **No numbered routes.** Every path has a name and a shape: Fernstair (switchback terraces),
  Crowcrest (scree ridge with a tarn), Saltmarsh (boardwalks over reeds).
- **Portrait first.** Maps are tall and narrow (about 12 tiles wide) and use terraces: cliffs
  (`^`), stairs (`=`), piers (`+`). No wide rectangles with one road down the middle.
- **Hub, not a chain.** Brindlewick sits on the lake. Fernstair (north) and Saltmarsh (east)
  both leave from it, and the Rifts can be mended in any order (the Mist Rift lies off the
  east end of Crowcrest's lower path).
- **Wild Spirlings live in several grounds:** ferns (`,`), reeds (`%`) and scree (`:`).
- **Places have their own shape:** a lighthouse village on piers, a gorge village on two levels,
  Rift hollows as open-air craters with a visible tear (`X`). Healing is at springs and pools.
- **Wayfarers do not ambush.** Duels start when the player talks to a Wayfarer (`sight` is 0).

## Avoid

Starting house with a parent, a professor handing out starters, a rival who picks the
counter-starter, numbered routes, a fixed badge/leader sequence, a villain organisation,
identical healing buildings in every town, line-of-sight trainer ambushes, oval battle platforms,
a fire/water/grass starter triangle, losing half your money when your team is worn out.

## Day and night

Maps with `"outdoor": true` follow the device clock through `DayCycle`: dawn 5:00, day 7:00, dusk 18:00 and night 20:00. Outdoors the world gets a soft tint, and Umbra and Lumen Spirlings are met more often at night (Lumen at dusk, Gale at dawn), using the same weighting as festivals. Rooms, Murk Hollow and the Rifts never change. Players can switch it off under Display and access.

## World data and tools (5000-point plan, area 3)

- **New tiles:** `w` shallow water (Wading Boots), `B` boulder to push, `P` pressure plate,
  `k` cracked floor, `v` vine wall (Climbing Pick), `Y` plank gap (Plank Bundle). Legend and
  rules: header of `scripts/overworld/MapData.gd`. Gear moves the player on foot only.
- **Hidden finds** go in a map's `secrets` list (`x`, `y`, `item`, `count`, `flag`), not in signs.
- **Floors:** a cave or dungeon keeps all its levels in one file under `floors`; level n of
  `cave.json` is the map id `cave@n`.
- **World layout:** `data/world_layout.json` gives every place a grid cell per region and its
  neighbours. Houses lie `inside` their town. Every warp between two places must be an edge.
- **Map builders:** `python3 tools/art/build_world.py [group]` runs the modules in
  `tools/art/world/` (veydal_core, veydal_wilds, veydal_caves, veydal_dungeons, corvane; the
  corvane group also builds `corvane_act2.py` and the Ashmere maps in `ashmere.py`; `rifts12`
  builds the Mist, Root and Shade Rifts). Act I maps
  are edited in JSON and only patched by `veydal_core`; new maps are generated, so edit their
  Python. New maps start from `tools/art/world/template.py` (12 wide, rock frame, exits top and bottom).
- **Shapes:** outdoor maps are at most 12 x 40 tiles; routes and marshes need at least two
  ways out (by foot or by line). `WorldValidator.check_shapes` checks both.
- **Statistics:** `python3 tools/world_stats.py` writes the table below (`--check` tells if it is stale).
- **Act I look:** Veydal maps use their own atlas `art/era1/tiles/overworld_veydal.png` (heath, bracken, firs, peat tarns, slate cliffs, dry-stone walls, waystones, cairns), made by `tools/art/gen_tiles_veydal.py`. TilesetFactory picks `tiles/overworld_<region>.png` when the map region has one; buildings and the lighthouse keep the shared tiles.
- **Act III look:** Ashmere maps use `art/era1/tiles/overworld_ashmere.png` (ash ground, charred brush, dead snags, brine pools, salt spikes, cinder scree, slag heaps, braziers, basalt cliffs), made by `tools/art/gen_tiles_ashmere.py`, and switch the Era I filter to their own four inks from `data/region_looks.json` (RegionLook, EraManager.set_region).
- **Era III look (Quillmarch):** the post-game Era III region (`data/region3.json`, Region3.gd) uses `art/era3/tiles/overworld_quillmarch.png`, made by `tools/art/gen_tiles_quillmarch.py` from the 16-colour palette in `data/region_looks.json` ("era": 3): moss grass lit from the top left, ferns in two heights, soft path edges, canal water with a stone bank, etched oaks with ground shadows, frost flowers, copper blooms, cracked mossy scree and hatched cliffs. TilesetFactory takes a region's own atlas when it is from the shared atlas' era or newer, so in Era III it beats the Era II shared atlas. Era III has no screen filter, so `EraManager.inks_for` keeps the base inks for it.
- **Landmarks (map design item 509):** every outdoor place of Acts I-III has one tall thing you
  know it by, listed in `data/landmarks.json` (kind, solid cell, name, line; German in
  `tools/i18n/de_landmarks.py`). Each act draws its own set and no kind is shared: Veydal
  standing stones, cairns, beacons and tide posts; Corvane heron posts, drying racks, sluice
  wheels and dye mills; Ashmere smelter stacks, bell frames and salt needles. Art:
  `tools/art/gen_landmarks.py` (16x32, the top half covers the cell above). Talking to it shows
  name and line. `WorldValidator.check_landmarks` keeps them off warps, signs, people, finds,
  gates and story spots.
- **Winding roads (map design item 508):** Madderby, Corvane Quay, Stillwater and Saltglass no
  longer run one straight road through the middle; the roads jog around houses, squares and
  slag (only `_` and `.` swapped, so nothing about where you can walk changed). The generated
  Corvane and Ashmere maps have been patched by hand since they were built, so edit their JSON,
  not `corvane_act2.py` / `ashmere.py`, until the builders are brought back in line.
- **Overview:** `python3 tools/art/preview_map.py --region veydal` draws every map of a region
  on one sheet (`build/previews/veydal.png`).
- **Checks:** `tools/validate_data.gd` and `tests/unit/test_world_data.gd` check tiles,
  encounter tables (no map without a table, no unused table), hidden finds (reachable, unique
  flag, real item) and the layout.

- **Map audit:** `python3 tools/maps/render_all.py <dir> [prefix] [--era2] [--marks]` draws every
  map and floor (one PNG each plus a sheet per region; `--marks` outlines flagged cells in red).
  `python3 tools/maps/audit_maps.py` lists what makes a map look unclean (doors that lead
  nowhere, cut-off or doorless buildings, stray lighthouse pieces, people in front of doors,
  unreachable pockets, blank atlas cells, bad warps and more; the kinds are in its header).
  CI runs `--check`: a finding that is not in `tools/maps/audit_baseline.json` fails, and so does a
  baseline line that is already fixed. After a fix run `--write-baseline`.

## World statistics (item 903)

Written by `python3 tools/world_stats.py`.

<!-- world-stats:start -->
| Region | Map | Kind | Size | Finds | Wayfarers | Wild cells |
| --- | --- | --- | --- | --- | --- | --- |
| veydal | `bellstone_ruins` | dungeon | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 2 | 0 | 9 |
| veydal | `brackwater_fen` | marsh | 12x24 | 5 | 3 | 86 |
| veydal | `brackwater_sluice` | dungeon | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 2 | 0 | 11 |
| veydal | `brindlewick` | town | 12x20 | 4 | 0 | 0 |
| veydal | `cinder_rift` | rift | 12x13 | 0 | 4 | 20 |
| veydal | `copperfold` | town | 12x19 | 3 | 0 | 0 |
| veydal | `copperfold_house` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `copperfold_shop` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `copperfold_spring` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `crowcrest` | route | 12x24 | 5 | 3 | 42 |
| veydal | `echo_path` | inside | 10x8 + 10x8 | 0 | 0 | 0 |
| veydal | `fernstair` | route | 12x26 | 5 | 2 | 63 |
| veydal | `gloamwood` | route | 12x30 | 5 | 3 | 152 |
| veydal | `kindle_vents` | cave | 12x10 | 3 | 0 | 12 |
| veydal | `lantern_steps` | route | 12x19 | 5 | 3 | 9 |
| veydal | `lanternwell` | inside | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 1 | 0 | 7 |
| veydal | `lighthouse` | inside | 10x8 | 1 | 0 | 0 |
| veydal | `map_house` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `mist_rift` | rift | 12x22 | 0 | 5 | 17 |
| veydal | `mossmere_grotto` | cave | 12x11 + 12x8 | 4 | 0 | 25 |
| veydal | `murk_hollow` | cave | 12x13 + 12x9 | 5 | 3 | 20 |
| veydal | `pawn_vault` | inside | 12x9 + 12x9 + 12x9 | 5 | 6 | 0 |
| veydal | `quillbrook` | route | 12x30 | 5 | 3 | 111 |
| veydal | `reedhaven` | town | 12x10 | 3 | 0 | 0 |
| veydal | `reedhaven_house` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `reedhaven_shop` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `reedhaven_spring` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `rest_spring` | inside | 10x8 | 1 | 0 | 0 |
| veydal | `sablecove` | cave | 12x9 | 5 | 0 | 10 |
| veydal | `saltmarsh` | marsh | 12x15 | 5 | 3 | 47 |
| veydal | `shatterfloor_mine` | inside | 12x8 + 12x8 | 2 | 0 | 9 |
| veydal | `thornridge` | town | 12x20 | 5 | 0 | 6 |
| veydal | `thornridge_house` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `tide_rift` | rift | 12x13 | 0 | 3 | 16 |
| veydal | `wren_library` | inside | 10x8 | 1 | 0 | 0 |
| veydal | `wrenhollow` | town | 12x17 | 3 | 0 | 0 |
| veydal | `wrenhollow_shop` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `wrenhollow_spring` | inside | 10x8 | 0 | 0 | 0 |
| corvane | `corvane_quay` | town | 12x24 | 3 | 0 | 0 |
| corvane | `corvane_quay_house` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `corvane_quay_shop` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `corvane_quay_spring` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `edge_watch_hut` | inside | 8x6 | 0 | 0 | 0 |
| corvane | `greyreach` | route | 12x29 | 5 | 3 | 44 |
| corvane | `greyreach_hut` | inside | 8x6 | 0 | 0 | 0 |
| corvane | `madderby` | town | 12x22 | 3 | 0 | 0 |
| corvane | `madderby_guild` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `madderby_house` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `madderby_spring` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `mirror_rift` | rift | 12x13 | 0 | 0 | 20 |
| corvane | `rain_rift` | rift | 12x13 | 0 | 0 | 22 |
| corvane | `rook_vault` | inside | 12x9 + 12x9 + 12x9 + 12x9 | 5 | 3 | 16 |
| corvane | `root_rift` | rift | 12x22 | 0 | 4 | 17 |
| corvane | `stillwater` | route | 12x26 | 4 | 3 | 53 |
| corvane | `wide_rift_edge` | rift | 12x16 | 0 | 0 | 0 |
| corvane | `woadfen` | marsh | 12x28 | 5 | 3 | 154 |
| ashmere | `ashmere_station` | town | 12x22 | 5 | 1 | 0 |
| ashmere | `cinderfold` | town | 12x16 | 4 | 0 | 0 |
| ashmere | `glass_rift` | rift | 12x13 | 0 | 0 | 20 |
| ashmere | `gravers_hall` | inside | 10x9 | 0 | 0 | 0 |
| ashmere | `kiln_rift` | rift | 12x13 | 0 | 0 | 20 |
| ashmere | `saltglass` | route | 12x26 | 5 | 4 | 55 |
| ashmere | `shade_rift` | rift | 12x22 | 0 | 5 | 16 |
| ashmere | `soot_vaults` | dungeon | 12x20 + 12x20 + 12x20 + 12x20 + 12x20 + 12x20 | 21 | 17 | 174 |
| ashmere | `undrawn_1` | rift | 12x22 | 0 | 0 | 0 |
| ashmere | `undrawn_2` | rift | 12x16 | 0 | 0 | 0 |
| ashmere | `undrawn_3` | rift | 12x16 | 0 | 0 | 0 |
| ashmere | `wide_rift_far` | rift | 12x15 | 0 | 0 | 16 |
| vellmarch | `bellrope_marsh` | marsh | 12x26 | 4 | 1 | 38 |
| halcyra | `brightledge` | town | 12x20 | 3 | 0 | 0 |
| solenne | `caravanserai` | inside | 12x10 | 1 | 2 | 0 |
| vellmarch | `cindergate_quay` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `cindergate_quay_bunkhouse` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `cindergate_quay_customs_store` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `cindergate_quay_net_loft` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `cindergate_quay_tollhouse` | inside | 8x6 | 0 | 0 | 0 |
| halcyra | `cloudshadow_meadow` | route | 12x24 | 3 | 1 | 78 |
| vellmarch | `foundry_rift` | rift | 12x22 | 0 | 2 | 0 |
| halcyra | `gildcrest` | town | 12x20 | 3 | 0 | 0 |
| halcyra | `gilt_rift` | rift | 12x22 | 0 | 2 | 0 |
| halcyra | `gilt_span` | inside | 12x12 | 3 | 0 | 0 |
| solenne | `glasswind_flats` | route | 12x34 | 5 | 6 | 86 |
| halcyra | `great_orrery` | inside | 12x10 | 0 | 0 | 0 |
| vellmarch | `hookwick` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `hookwick_boatshed` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `hookwick_eel_smokery` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `hookwick_lock_office` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `hookwick_tackle_shop` | inside | 8x6 | 0 | 0 | 0 |
| halcyra | `lantern_span` | route | 12x24 | 3 | 1 | 37 |
| vellmarch | `larkspur_heights` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `larkspur_heights_counting_house` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `larkspur_heights_mask_atelier` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `larkspur_heights_salon` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `larkspur_heights_servants_hall` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `lastlamp` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `lastlamp_bell_house` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `lastlamp_lamp_store` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `lastlamp_name_room` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `lastlamp_pawnshop` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `lock_rift` | rift | 12x22 | 0 | 2 | 0 |
| halcyra | `long_stair` | route | 12x24 | 3 | 1 | 42 |
| vellmarch | `masque_rift` | rift | 12x22 | 0 | 2 | 0 |
| solenne | `mirage_kiln` | dungeon | 12x10 + 12x10 + 12x8 | 5 | 7 | 25 |
| halcyra | `mirror_flats` | route | 12x24 | 3 | 1 | 58 |
| solenne | `oasis_rift` | rift | 12x22 | 0 | 4 | 18 |
| solenne | `ochrewell` | town | 12x20 | 3 | 0 | 0 |
| solenne | `ochrewell_dome` | inside | 10x8 | 0 | 0 | 0 |
| solenne | `ochrewell_pottery` | inside | 10x8 | 0 | 0 | 0 |
| solenne | `ochrewell_store` | inside | 10x8 | 0 | 0 | 0 |
| halcyra | `orrery_ridge` | route | 12x24 | 3 | 1 | 47 |
| halcyra | `orrery_rift` | rift | 12x22 | 0 | 2 | 0 |
| halcyra | `paleshore` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `rookery_cut` | route | 12x26 | 4 | 1 | 38 |
| halcyra | `salt_rift` | rift | 12x22 | 0 | 2 | 0 |
| vellmarch | `smelters_drift` | route | 12x26 | 4 | 1 | 38 |
| halcyra | `span_rift` | rift | 12x22 | 0 | 2 | 0 |
| halcyra | `starwell` | town | 12x20 | 3 | 0 | 0 |
| solenne | `sun_rift` | rift | 12x22 | 0 | 4 | 13 |
| halcyra | `sunfall_terraces` | route | 12x24 | 3 | 1 | 58 |
| vellmarch | `tallowmarket` | town | 12x20 | 3 | 0 | 0 |
| vellmarch | `tallowmarket_rumour_room` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `tallowmarket_vigil_house` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `tallowmarket_wax_hall` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `tallowmarket_weigh_house` | inside | 8x6 | 0 | 0 | 0 |
| vellmarch | `tithe_road` | route | 12x26 | 4 | 1 | 38 |
| vellmarch | `tollchain_causeway` | route | 12x26 | 4 | 1 | 38 |
| solenne | `tower_rift` | rift | 12x22 | 0 | 4 | 21 |
| vellmarch | `vault_rift` | rift | 12x22 | 0 | 2 | 0 |
| solenne | `veil_cistern` | inside | 12x10 + 12x10 + 12x8 | 3 | 5 | 24 |
| vellmarch | `weeping_locks` | route | 12x26 | 4 | 1 | 38 |
| halcyra | `white_stair` | inside | 12x12 | 3 | 0 | 0 |
| halcyra | `whitecairn` | town | 12x20 | 3 | 0 | 0 |
| | **132 maps** | | | **240** | **144** | **2034** |
<!-- world-stats:end -->

## Wayfarer Gear and where it is given (item 1062)

Written by `python3 tools/world_stats.py`.

<!-- gear-givers:start -->
| Gear | Name | Map | Region | Given by | Flag |
| --- | --- | --- | --- | --- | --- |
| `climbing_pick` | Climbing Pick | `crowcrest` | veydal | kestra (7, 17) | `got_pick` |
| `grapple_line` | Grapple Line | `saltmarsh` | veydal | neve (3, 4) | `got_grapple` |
| `plank_bundle` | Plank Bundle | `gloamwood` | veydal | forester (2, 22) | `got_planks` |
| `pry_bar` | Pry Bar | `copperfold` | veydal | smith (1, 5) | `got_pry_bar` |
| `rope_ladder` | Rope Ladder | `wrenhollow` | veydal | ropemaker (8, 11) | `got_ladder` |
| `rubbing_charcoal` | Rubbing Charcoal | `gloamwood` | veydal | charcoaler (8, 1) | `got_rubbing_charcoal` |
| `storm_lantern` | Storm Lantern | `murk_hollow` | veydal | tamsin (3, 10) | `got_lantern` |
| `survey_glass` | Survey Glass | `wrenhollow` | veydal | surveyor (10, 9) | `got_survey_glass` |
| `tide_chart` | Tide Chart | `brackwater_fen` | veydal | tidewatcher (9, 15) | `got_tide_chart` |
| `wading_boots` | Wading Boots | `quillbrook` | veydal | fisher (8, 3) | `got_boots` |
<!-- gear-givers:end -->
