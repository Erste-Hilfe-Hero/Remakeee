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

Maps with `"outdoor": true` (set in `tools/art/build_world.py`) follow the device clock through `DayCycle`: dawn 5:00, day 7:00, dusk 18:00 and night 20:00. Outdoors the world gets a soft tint, and Umbra and Lumen Spirlings are met more often at night (Lumen at dusk, Gale at dawn), using the same weighting as festivals. Rooms, Murk Hollow and the Rifts never change. Players can switch it off under Display and access.
