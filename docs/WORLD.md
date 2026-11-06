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
  `tools/art/world/` (veydal_core, veydal_wilds, veydal_caves, corvane). Act I maps are edited
  in JSON and only patched by `veydal_core`; new maps are generated, so edit their Python.
- **Overview:** `python3 tools/art/preview_map.py --region veydal` draws every map of a region
  on one sheet (`build/previews/veydal.png`).
- **Checks:** `tools/validate_data.gd` and `tests/unit/test_world_data.gd` check tiles,
  encounter tables (no map without a table, no unused table), hidden finds (reachable, unique
  flag, real item) and the layout.
