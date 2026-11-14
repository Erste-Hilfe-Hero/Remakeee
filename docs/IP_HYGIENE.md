# IP hygiene

Draft working rules that keep Chimora clear of third-party intellectual property. AGENTS.md and LEGAL.md
hold the binding rules; this file explains how the project follows them day to day. It is not legal advice.
There is no lawyer review (Ali's decision); residual risks are listed in `docs/legal/CHECKLISTE_ALI.md`.

## 1. Names and words

- The banned franchise terms are listed in AGENTS.md (rule 1). They must not appear in code, comments,
  asset names, file names, UI strings, commit messages, PR text, store text or marketing.
- `tools/ip_check.sh` runs in CI on every push and PR and fails the build if a banned term shows up in a
  tracked file. AGENTS.md and LEGAL.md are skipped because they define the list.
- Our own vocabulary, used everywhere: **Spirling** (creature), **Wayfarer** (player and NPC trainers),
  **Spirlog** (creature log), **Rift** and **Warden** (progression challenges), **Bonding** (recruiting),
  **rest spring** (healing spot), **storage box** (party overflow), **Energy** (move resource).
- New creature, move and place names: check that the name is not a creature, move or place name in any
  well-known monster-taming game and is not a registered trademark in games (search EUIPO and USPTO
  TESS/TSDR in class 9 and 41). Avoid the "-mon" suffix and puns that point at a specific franchise.
  Art names are checked automatically against a block list of the inspiration's move names
  (`tools/ip_move_check.py`, run by `tools/ip_check.sh`): an exact match after folding case, spaces
  and hyphens fails, a name one letter away is printed as a note to look at.

## 1b. Overall impression

Many small similarities add up even when each is harmless. Keep these as they are (pinned by
`tests/unit/test_originality.gd`): team of 5, level cap 60, Spark 0–12, keen hits 1/12 at x1.4,
status ticks of 1/12, no element-triangle starters, no evolution at levels 16/32/34/36, moves as a
one-column list, a one-colour HP bar, the Era I ink palette, no coin loss after a wipe. German text
uses "Technik" for moves and avoids the franchise's German battle words (checked by `tools/ip_check.sh`).

### Our own words

The game uses its own names for the genre's usual terms. Use these in all new text:

| Instead of | English | German |
| --- | --- | --- |
| Level, Lv | Ring (R12, "ring limit") | Ring (R12, "Ringgrenze") |
| XP, experience | Growth | Wachstum |
| HP | Vigor | Kraft |
| ATK / DEF / SPD | Might / Guard / Pace (MGT, GRD, PCE); Focus stays | Wucht / Schutz / Tempo (WUC, SCH, TMP); Fokus |
| Ability, trait | Gift | Gabe |
| Held item | Keepsake | Andenken |
| Trainer, tamer | Wayfarer | Wanderer |
| Move, attack | Art | Technik |
| Evolution | Unfurling | Entfalten |

Unfurling is our own mechanic, not a renamed one: a Spirling never changes form on its own.
Once it is ready (ring, item or place), the Team menu offers "Unfurl", and an unfurled Spirling
can "Furl back" into its earlier form at any time, keeping its rings, arts and Spark.

## 2. Mechanics (design-around)

These follow AGENTS.md rule 2 and are enforced in code review:

| Avoid | Chimora instead |
| --- | --- |
| Throwing or aiming an item to capture | Bonding is a menu action that starts the "Echo call" minigame (repeat a sequence; no shrinking rings or timing circles) |
| A live capture-probability gauge | The result is shown only after the minigame ends |
| Riding a creature to fly, surf or glide | Traversal uses Wayfarer Gear items on foot (grapple, climbing pick, lantern); no gliding or flying at all |
| Throwing out a creature to summon it, flick-to-throw on touch | Spirlings step out beside the Wayfarer |
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
- The Retro filter uses our own four-colour palette (`EraManager.INK_PALETTE`), not a palette sampled
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
4. Ali's own items stay open until done: trademark search and filing for "Chimora", Impressum,
   DSA trader details, age ratings (IARC and Apple). See `docs/legal/CHECKLISTE_ALI.md`.

## 7. Legal drafts

`docs/legal/` holds the IP and patent audit, draft privacy policy (DE/EN), terms, Impressum template and
store-compliance answers. Written by an AI without lawyer review; only Ali's personal details are left as placeholders.

## 8. New Spirlings (plan area 1, item 436)

Every new kind is checked before it goes into `data/spirlings.json`: the name against the banned list
(`tools/ip_check.sh` runs over all data), the name against a web search for existing creature brands,
the outline against our own sheet (no two kinds share a silhouette), and the cry, which `Cry.gd` builds
from the name hash and elements (no recorded or borrowed sounds). Names are English compound words
or Latin-ish coinages of our own.

| Kinds | Outline | Check |
| --- | --- | --- |
| Blotling / Scrivane | ink blot, then a quill-necked heron of ink | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Hushkin / Silentra | mouthless shadow cub, then a veiled figure with light signs | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Paddlewisp / Ferrowyn | water whirl with a paddle tail, then a spray otter with fin sails | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Talusk / Talusgard / Cairnhold | scree heap with one eye, then a walking cairn with a beacon fire | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Fluting / Marshfife | hollow reed with finger holes, then a heron of bound reeds | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Glasstarn | a flat disc of lake water with a face under the surface | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Lanternel | lamp-bellied creature with a cap and one wing | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Seamlet / Mendlace | spark with a needle tail, then a shadow tailor inside a thread loop | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Croziel / Frondmere | fiddlehead fern on root feet, then a deer whose antlers are fern fronds | banned list OK, own design, cry from Cry.gd (2026-11-06) |
| Brinelet / Saltspire | salt crystal cluster, then a walking salt pillar with a crown | banned list OK, own design, cry from Cry.gd (2026-11-06) |

The 40 kinds of Corvane, Ashmere and Solenne (items 61-63) follow the same check. Their names are built from plain words of their places (mill, reed, cog, glass, etch, salt, orrery, dune) and were run through `tools/ip_check.sh`. Their sprites are generated placeholders (round body, head, ears, crest or wings) until real designs are drawn. Regional imprints (items 218-219) are our own idea: a regional form keeps the Spirlog number and only changes elements, palette and lore, it is not a separate kind and no foreign terms are used for it.

## 9. Nachhall (plan area 1, items 183-186)

Nachhall is our own way for new Spirlings to appear. It is built on the game's song theme, not on breeding:

- Two bonded Spirlings (team or storage) sing together at a heal spring. Springs become Echo springs once the second Rift is mended. Their shared call forms a floating **Echo Core** (German "Hallkern").
- After 30 won battles or 5 rests at a heal spring, whichever comes first, a **Hallkind** wakes from the core. It is the first form of one of the two lines, at Ring 1, and remembers both singers as its lineage.
- There are no genders, no pairing rules, no egg item, no day care, no incubator, no hatching by walking, no inherited moves or stats, and no compatibility screen. Both singers stay with the player. A First Voice (ancient) never sings with others, and at most 3 cores are carried at once.
- Echo Cores live only in the player's own save. They are no bag item and no shop product, and they can't be traded, gifted or sold. The same holds for every Spirling and Hallkind (tests/unit/test_online.gd, item 438).
- The words used are Echo spring, Sing together, Echo Core and Hallkind. All of them passed `tools/ip_check.sh`.

- Walking never counts: there is no step counter for cores, because hatching by walking with a step counter is the best-known single trait of the model (legal review, 2026-11-06). The plan's first draft (item 185, "600 steps") was changed for this reason.
- A core never takes a team slot and never shows up like an egg in the team menu. Cores have their own lines in Records with their progress (wins and rests). Waking is shown as a song that grows dense and clear, never as a shell breaking open.

The legal thread (area 9) reviewed this on 2026-11-06: fine in principle. Its two changes (no steps, and cores kept out of the team) are built in.
