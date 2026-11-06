# Legal rules for Chimora (read before adding content)

Not legal advice — get a games lawyer to review before store launch.

## Patent-safe (Nintendo sued Palworld over these, Sept 2024)
- NO throw-to-capture. Bonding = turn-based "Echo call" minigame in the battle menu.
  No shrinking rings, timing circles or "tap when it's smallest" mechanics.
- NO live capture-odds meter while aiming. Show bond result only afterwards.
- Echo bonding (plan area 1): cry motifs, element scales, muted calls near open Rifts, the
  glowing frame at mended Rifts, the afterglow mark, longer calls for rarer kinds and the
  moon/star/spark marks only change the call itself. Bonding still has no throw, no aiming,
  no shrinking circles and no chance display, also for First Voices and peaceful meetings.
  The result is shown only afterwards and only in words ("It listens to you", "It hesitates",
  "It turns away"), never as a number. Tested in tests/unit/test_bond_echo.gd.
- NO riding, flying, gliding or surfing on a creature. Use Wayfarer Gear on foot (grapple, climbing pick, lantern).
  No gliding or flying while exploring at all, not even with gear (patent risk zone).
- NO calling a creature into the overworld/field where it fights on its own (US 12,403,397).
  Spirlings fight only on the separate turn-based battle screen.
- NO thrown capsule/ball to summon. Spirlings step out beside the Wayfarer.

## Copyright / trademark
- 100% original creatures, names, moves, maps, music, fonts, sprites.
- Never use: Pokémon, Poké-, "-mon" names, red/white ball shapes, Gym, Pokédex,
  Poké Center, HM/TM — not in code, assets, store keywords or ads.
- Don't copy Pokémon battle-screen layouts (HP box placement, menu shapes).
  Battles with several Spirlings per side use our formation layout: one ledger strip at the top
  for the Spirling in focus, two straight ranks of half-size sprites, a small tag under each
  sprite and a map pin for targeting. Never one HP box per Spirling in the screen corners.
- Public wording: "monster-taming RPG", never "Pokémon remake". No other games' names or comparisons
  in store text, keywords, screenshots or ads (Apple guideline 2.3.7, German UWG).
- Battle text in our own words; `tools/ip_check.sh` blocks known borrowed battle phrases.
- Compare every new Spirling design against the official dex before merging.
