# IP hygiene

Draft working rules that keep Chimora clear of third-party intellectual property. AGENTS.md and LEGAL.md
hold the binding rules; this file explains how the project follows them day to day. It is not legal advice.
Have a lawyer review the game, the store listings and this document before the first public release.

## 1. Names and words

- The banned franchise terms are listed in AGENTS.md (rule 1). They must not appear in code, comments,
  asset names, file names, UI strings, commit messages, PR text, store text or marketing.
- `tools/ip_check.sh` runs in CI on every push and PR and fails the build if a banned term shows up in a
  tracked file. AGENTS.md and LEGAL.md are skipped because they define the list.
- Our own vocabulary, used everywhere: **Spirling** (creature), **Tamer** (player and NPC trainers),
  **Spirlog** (creature log), **Rift** and **Warden** (progression challenges), **Bonding** (recruiting),
  **rest spring** (healing spot), **storage box** (party overflow), **Energy** (move resource).
- New creature, move and place names: check that the name is not a creature, move or place name in any
  well-known monster-taming game and is not a registered trademark in games (search EUIPO and USPTO
  TESS/TSDR in class 9 and 41). Avoid the "-mon" suffix and puns that point at a specific franchise.

## 2. Mechanics (design-around)

These follow AGENTS.md rule 2 and are enforced in code review:

| Avoid | Chimora instead |
| --- | --- |
| Throwing or aiming an item to capture | Bonding is a menu action that starts a rhythm minigame inside the battle |
| A live capture-probability gauge | The result is shown only after the minigame ends |
| Riding a creature to fly, surf or glide | Traversal uses Tamer Gear items on foot (grapple, climbing pick, lantern); no gliding or flying at all |
| Throwing out a creature to summon it, flick-to-throw on touch | Spirlings step out beside the Tamer |
| Seamless overworld battles | Battles start from overworld encounters and cut to a separate battle screen |

Our own numbers: the damage curve, stat curve, XP curve, element chart (Ember, Tide, Bloom, Volt, Stone,
Gale, Lumen, Umbra), Energy system and status table are original and live in `scripts/battle/` and
`data/*.json`. Do not copy formulas, type charts or stat tables from other games.

## 3. Look and sound

- Original assets only (AGENTS.md rule 3). No ripped, traced or "edited from" sprites, tiles, music,
  sound effects or fonts, and no AI output prompted with another game's name or characters.
- Until real art exists the game uses coloured placeholder rectangles and the in-house `PixelFont`
  (`scripts/ui/PixelFont.gd`), drawn from scratch for this project.
- Battle screen: our own layout (foe strip at the top, foe on the right, player on the lower left, command
  panel with Energy costs). Do not imitate another game's battle-box shapes, HP bar styling or menus.
- No red/white split-sphere shapes anywhere, including icons, UI and store art.
- The Retro filter uses our own four-colour palette (`EraManager.MONO_PALETTE`), not a palette sampled
  from a specific handheld game.

## 4. Asset provenance

Every file added under `art/` or `audio/` must have a line in `docs/ASSET_LOG.md`: path, author, how it
was made, licence or contract, date. `tools/ip_check.sh` fails CI when a file is missing from the log.
For commissioned work, keep the signed contract (copyright assignment or exclusive licence, including
the right to modify) outside the repo.

## 5. Store and marketing

- Store titles, descriptions, keywords and screenshots must not name or compare to other franchises
  ("like X", "X-style"). Describe Chimora on its own terms.
- Do not use other games' names as search keywords or ad targeting.

## 6. Before each release

1. CI green, including `tools/ip_check.sh`.
2. Skim new strings in `data/` and the store text for borrowed names.
3. Check `docs/ASSET_LOG.md` covers every new asset.
4. Ali's own items stay open until done: lawyer review, trademark search for "Chimora", Impressum,
   DSA trader details, age ratings (IARC and Apple).
