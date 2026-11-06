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
- End of Act I: both Rifts mended, a larger third Rift lies north, the ferry to Corvane (Era II) waits.

## The First Voices (plan area 1, items 152-155)

- Long before the Rifts, six ancient Spirlings sang together, and their song held the land
  together: rivers kept their beds, hills kept their shape, and Spirlings and people understood
  each other. They are the **First Voices**.
- One by one the Voices fell silent. Nobody knows why yet. Their silence is where **the Hush**
  began: the Rifts open where a Voice used to sing, and the Hush spreads from there.
- Each region has its Voice. **Velahra** (Lumen/Tide) is the Voice of Veydal. It sleeps as a
  light under the lake in front of the Brindlewick lighthouse and was the last one to see
  **Mirela**, the cartographer whose map book the player follows. The Voices of Corvane, Ashmere
  and Solenne wait in their regions; two more are not named in the map book at all.
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
  both leave from it, and the two Rifts can be mended in either order.
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
  corvane group also builds `corvane_act2.py` and the Ashmere maps in `ashmere.py`). Act I maps
  are edited in JSON and only patched by `veydal_core`; new maps are generated, so edit their
  Python. New maps start from `tools/art/world/template.py` (12 wide, rock frame, exits top and bottom).
- **Shapes:** outdoor maps are at most 12 x 40 tiles; routes and marshes need at least two
  ways out (by foot or by line). `WorldValidator.check_shapes` checks both.
- **Statistics:** `python3 tools/world_stats.py` writes the table below (`--check` tells if it is stale).
- **Overview:** `python3 tools/art/preview_map.py --region veydal` draws every map of a region
  on one sheet (`build/previews/veydal.png`).
- **Checks:** `tools/validate_data.gd` and `tests/unit/test_world_data.gd` check tiles,
  encounter tables (no map without a table, no unused table), hidden finds (reachable, unique
  flag, real item) and the layout.

## World statistics (item 903)

Written by `python3 tools/world_stats.py`.

<!-- world-stats:start -->
| Region | Map | Kind | Size | Finds | Wayfarers | Wild cells |
| --- | --- | --- | --- | --- | --- | --- |
| veydal | `bellstone_ruins` | dungeon | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 2 | 0 | 10 |
| veydal | `brackwater_fen` | marsh | 12x24 | 5 | 3 | 86 |
| veydal | `brackwater_sluice` | dungeon | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 2 | 0 | 12 |
| veydal | `brindlewick` | town | 12x20 | 4 | 0 | 0 |
| veydal | `cinder_rift` | rift | 12x13 | 0 | 4 | 20 |
| veydal | `copperfold` | town | 12x19 | 3 | 0 | 0 |
| veydal | `crowcrest` | route | 12x24 | 4 | 3 | 42 |
| veydal | `echo_path` | inside | 10x8 + 10x8 | 0 | 0 | 0 |
| veydal | `fernstair` | route | 12x26 | 4 | 2 | 63 |
| veydal | `gloamwood` | route | 12x30 | 5 | 3 | 152 |
| veydal | `kindle_vents` | cave | 12x10 | 2 | 0 | 12 |
| veydal | `lantern_steps` | route | 12x19 | 4 | 3 | 9 |
| veydal | `lanternwell` | inside | 12x7 + 12x7 + 12x7 + 12x7 + 12x7 | 1 | 0 | 8 |
| veydal | `lighthouse` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `map_house` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `mossmere_grotto` | cave | 12x11 + 12x8 | 3 | 0 | 25 |
| veydal | `murk_hollow` | cave | 12x13 + 12x9 | 4 | 3 | 20 |
| veydal | `quillbrook` | route | 12x30 | 4 | 3 | 114 |
| veydal | `reedhaven` | town | 12x10 | 3 | 0 | 0 |
| veydal | `rest_spring` | inside | 10x8 | 0 | 0 | 0 |
| veydal | `sablecove` | cave | 12x9 | 2 | 0 | 10 |
| veydal | `saltmarsh` | marsh | 12x15 | 4 | 3 | 47 |
| veydal | `shatterfloor_mine` | inside | 12x8 + 12x8 | 2 | 0 | 10 |
| veydal | `thornridge` | town | 12x20 | 4 | 0 | 6 |
| veydal | `tide_rift` | rift | 12x13 | 0 | 3 | 16 |
| veydal | `wrenhollow` | town | 12x17 | 3 | 0 | 0 |
| corvane | `corvane_quay` | town | 12x24 | 3 | 0 | 0 |
| corvane | `greyreach` | route | 12x29 | 4 | 3 | 44 |
| corvane | `madderby` | town | 12x22 | 3 | 0 | 0 |
| corvane | `madderby_guild` | inside | 10x9 | 0 | 0 | 0 |
| corvane | `mirror_rift` | rift | 12x13 | 0 | 0 | 20 |
| corvane | `rain_rift` | rift | 12x13 | 0 | 0 | 22 |
| corvane | `stillwater` | route | 12x26 | 3 | 3 | 53 |
| corvane | `wide_rift_edge` | rift | 12x16 | 0 | 0 | 0 |
| corvane | `woadfen` | marsh | 12x28 | 4 | 3 | 154 |
| ashmere | `ashmere_station` | town | 12x22 | 3 | 0 | 0 |
| ashmere | `cinderfold` | town | 12x16 | 3 | 0 | 0 |
| ashmere | `glass_rift` | rift | 12x13 | 0 | 0 | 20 |
| ashmere | `gravers_hall` | inside | 10x9 | 0 | 0 | 0 |
| ashmere | `kiln_rift` | rift | 12x13 | 0 | 0 | 20 |
| ashmere | `saltglass` | route | 12x26 | 4 | 3 | 56 |
| ashmere | `undrawn_1` | rift | 12x22 | 0 | 0 | 0 |
| ashmere | `undrawn_2` | rift | 12x16 | 0 | 0 | 0 |
| ashmere | `undrawn_3` | rift | 12x16 | 0 | 0 | 0 |
| ashmere | `wide_rift_far` | rift | 12x15 | 0 | 0 | 16 |
| | **45 maps** | | | **92** | **42** | **1067** |
<!-- world-stats:end -->
