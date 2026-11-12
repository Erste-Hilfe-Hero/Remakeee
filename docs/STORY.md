# Chimora story bible

The fixed base for every story thread (plan area 4, `docs/plan5000/04_story.md`). Act I is
described in `docs/WORLD.md`; this file adds the lore, the style rule, the named figures, the
places of Act II and Act III with fixed map ids, the story numbers and the endings. Check new
story text against this file before writing it, and add new figures and places here first.

## Style rule (item 1766)

- Short sentences. At most **2 lines per text box** (about 60 characters at 144 px).
- The pixel font has no typographic quotes: use `'` for quotes, never curly quotes.
- Answers in a choice are at most **18 characters** so they fit on one line.
- Player words follow `AGENTS.md`: Spirling, Wayfarer, Ring (not level), bond / Echo call,
  unfurl, Rift, Warden, mend, the Hush. Never the franchise words that `tools/ip_check.sh` bans.
- `{name}` is the player's name. A figure speaks as `Name: text` or with a `speaker` field.
- The Echo (the Hush's source) is **never a monster**. It is a grieving choir. Write it with
  sorrow, not menace (item 1716).
- No villain team. People who stand against the player have a reason and a way back.
- Every new English line also goes into `tools/i18n/de_story.py` (the CI fails otherwise).

## Lore (item 1705)

Fixed truths. Later text may reveal them slowly, but never contradict them.

1. **Spirlings come from the Undrawn**, the land beyond the edge of every map. It is not
   broken, only unfinished: paths exist where someone draws them.
2. **Rifts open where the drawn world grows thin**: places nobody has mapped for a long time,
   or places where a map was burned or lost. Storms tear the thin places open.
3. **The Hush is the echo of lost bonds.** Every Spirling that ever lost its Wayfarer leaves a
   call that nobody answers. In the Undrawn those calls gather into one voice, **the Echo**.
   Where a Rift is open, the Echo leaks out and drowns the voices of Spirlings nearby.
4. **Wardens** are people whose bond is strong enough to hold a Rift. When their bond falls
   silent, the Rift widens. A battle wakes the bond, and a Warden and a Wayfarer together
   **mend** the Rift: they draw its edge to the end.
5. **The Echo melody** is the song Mirela heard in the Undrawn. She brought it home as a
   lullaby; the guild of cartographers has taught it since. It answers the Echo instead of
   fighting it.
6. **Unfurling** happens when a bond is deep enough, like a part of a map being drawn to its
   edge. **Rings** are marks on a Spirling's skin, like tree rings; Ring 60 is what Mirela
   called "the edge of drawing".
7. Each region names the Hush in its own way: Veydal "the Hush", Corvane "the Fading" (it
   drains colour), Ashmere "the Stilling" (it freezes movement).
8. **Rift-born** Spirlings came through a Rift and have no home side. They need an **anchor
   bond** with one person to stay well; an open Rift is not what they need.

### Glossary (item 1707)

Our own terms. They avoid any closeness to existing origin myths; check new ones here.

| Term | Meaning |
| --- | --- |
| the Undrawn | the unfinished land behind the Rifts, where Spirlings come from |
| Rift | a tear where the drawn world is thin |
| the Hush / the Fading / the Stilling | the Echo leaking out, named per region |
| the Echo | the grieving choir of every lost bond (finale) |
| Echo melody | the song that answers the Echo; also the bond minigame |
| Warden | a keeper whose bond holds a Rift |
| mend | drawing a Rift's edge to the end, together with its Warden |
| anchor bond | the bond a Rift-born Spirling needs instead of an open Rift |
| Rift heart | the knot of Hush at the bottom of a mended Rift (optional battle) |
| gate | a Rift kept open on purpose, with a keeper on the far side |
| plate | a map engraved in copper by the gravers of Ashmere; it holds a place still |
| guild seal | proof of guild membership; opens the way into the Undrawn |

## Story numbers and choices

Saved in `GameState.story_vars` and `GameState.story_choices` (online save included).

### kestra_trust (0 to 6, item 1556)

Raised by 1 at six fixed moments, depending on the player's answer:

| # | Act | Moment | Raises trust when |
| --- | --- | --- | --- |
| 1 | I | `brindlewick/kestra_dock` | the player answers "I'll come along." |
| 2 | II | Madderby duel aftermath | the player says Kestra's view matters |
| 3 | II | scene `kestra_tatter_hush` | the player comforts Tatter with the Echo melody |
| 4 | II | Stillwater tag battle | the player and Kestra win together |
| 5 | III | Cinderfold, Veit's offer | the player turns Veit down |
| 6 | III | Kestra's farewell duel | the player asks her to come into the Undrawn |

Under 2: Kestra holds the way back in the finale instead of fighting beside the player. From 4:
her pre-battle line in the finale is the warmest variant. From 5: she gives her old compass.

### veit_respect (0 to 3, item 1608)

| # | Act | Moment |
| --- | --- | --- |
| 1 | II | side quest `veit_workshop`: all three hints about Ash found |
| 2 | III | Cinderfold: the player listens to Veit's plan to the end |
| 3 | III | Veit's plate: the player lets Veit break it himself |

From 2 Veit appears in the finale. At 3 (and all 14 pages) the ending "Two keepers" opens.

### Choices (`story_choices`)

`kestra_dock`, `ferry_row` (row yourself / let Aldo row), `veit_offer`, `veit_plate`,
`mirela_aldo` (what the player says about Aldo), `ending` (`home`, `gate`, `two_keepers`).

## The three endings (items 1681-1684)

The final choice is confirmed with "Draw it so?" because it cannot be undone.

- **Bring her home** (always): Mirela comes home and the Wide Rift closes. Rift-born
  Spirlings need an anchor bond from now on (story text, no new rules).
- **Leave a gate** (always): the Wide Rift becomes a gate. Mirela stays in the Undrawn as its
  keeper and writes to Aldo. Kestra is glad.
- **Two keepers** (veit_respect 3 and all 14 pages): Veit stays in the Undrawn with Ash as
  keeper, and Mirela comes home.

In every version Aldo and Mirela meet again on the Brindlewick dock (item 1588).

## Acts and chapters

| Act | Chapters | Name | Ends with flag |
| --- | --- | --- | --- |
| Prologue and Act I | 0-5 | The Hush of Veydal | `ferry_corvane_open` |
| Act II | 6-11 | The Colours of Corvane | `act2_end` |
| Act III | 12-17 | The Plates of Ashmere | `undrawn_reached` |
| Finale | - | Where the Map Ends | `story_complete` |
| Epilogue | 3 parts | The Open Map | `postgame_done` |

Act I ends when Aldo opens the ferry himself (`ferry_corvane_open`, the flag area 3's ferry to
`corvane_quay` waits for). The two Rift hearts are not needed for that (item 1411).

## Places with fixed map ids

Area 3 builds the maps; area 4 only places figures, signs and triggers on them (through
`data/story_npcs.json`, so figures appear as soon as a map exists).

### Act II: Corvane (items 1435)

| Map id | Place | Role |
| --- | --- | --- |
| `corvane_quay` | Corvane Landing (the quay) | arrival by ferry, scene `corvane_arrival` (area 3 calls it corvane_quay) |
| `madderby` | Madderby, the dyers' town | Kestra's second duel, colour_back quest |
| `madderby_guild` | the guild house of cartographers | Ysolde, Pim, the wall map |
| `woadfen` | Woadfen moor | way to the Rain Rift, hushed walkers |
| `rain_rift` | the Rain Rift | Warden Senna |
| `root_rift` | the Root Rift under the Woadfen moor | Warden Darrow, tag battle with Kestra at the mouth (after the Mirror Rift, before the Greyreach) |
| `stillwater` | Stillwater pond | way to the Mirror Rift, tag battle with Kestra |
| `mirror_rift` | the Mirror Rift | Warden Joral |
| `greyreach` | Greyreach, grey uplands | Veit's duel, old cartographer Moss |
| `wide_rift_edge` | the edge of the Wide Rift | scene `wide_rift_reveal` |

### Act III: Ashmere (item 1480)

| Map id | Place | Role |
| --- | --- | --- |
| `ashmere_station` | Ashmere station (mountain railway) | arrival |
| `cinderfold` | Cinderfold, the gravers' town | Veit's offer, rest spring under basalt |
| `gravers_hall` | the gravers' hall | Halvard, Veit's plate |
| `kiln_rift` | the Kiln Rift | Warden Tovan |
| `saltglass` | Saltglass flats | the silent lighthouse |
| `glass_rift` | the Glass Rift | Warden Ilse |
| `shade_rift` | the Shade Rift inside the silent lighthouse of the Saltglass flats | Warden Odalys, Veit's last duel (after Veit's plate, before the Undrawn) |
| `wide_rift_far` | the far end of the Wide Rift | Kestra's farewell duel |
| `undrawn_1` to `undrawn_3` | the Undrawn | three short parts without finished edges; the finale at the end of `undrawn_3` |

## Figures (item 1606)

| Name | Place | Role | Team (Ring) | Flags | Arc |
| --- | --- | --- | --- | --- | --- |
| {name} | Brindlewick lighthouse | the player, apprentice cartographer | partner from the prologue | `got_starter` | maps the valley, finds Mirela |
| Aldo | lighthouse | grandfather, old ferryman | - | `aldo_gift`, `aldo_dock_told`, `ferry_corvane_open` | keeps the lamp lit; rows one last crossing |
| Mirela | the Undrawn | grandmother, first cartographer | Glim (Wickit, very old) | `page_1`..`page_14`, `mirela_met` | see below |
| Kestra | map house, then everywhere | fellow cartographer | Act I 3, Act II 4, Act III 5 Spirlings; Tatter (Zephlet, later Tempestrel) | `met_kestra`, `kestra_spar`, `kestra_dock_talk` | see below |
| Tamsin | Murk Hollow | lamp keeper | - | `got_lantern` | travels to Ashmere in Act III |
| Lio | Crowcrest | wanderer | Zephlet 7, Zippit 8 | | becomes a guild helper in Act II |
| Bram | Crowcrest | ridgewalker | Shalebat 7, Shalebat 8 | | |
| Neve | Saltmarsh | diver | Puddlet 12, Zephlet 13 | | |
| Orrin | Cinder Rift | Warden (Act I) | Shalebat 10, Kindlop 11, Smoldrake 12 | `rift_cinder_sealed` | guest in Madderby in Act II |
| Maelis | Tidewater Rift | Warden (Act I) | Zephlet 15, Zippit 15, Riptail 17 | `rift_tide_sealed` | guest in Madderby in Act II |
| Pell, Suri | Cinder Rift | Rift acolytes | | | Warden apprentices after the finale |
| Ilka | Tidewater Rift | Rift mystic | | | |
| Ines, Wynn | Brindlewick | echo gauntlet, weekly echoes | | | a new line per act |
| Ysolde Rennick | Madderby guild house | guild master | | `guild_joined` | did not hold Mirela back 40 years ago and wants to make it right |
| Pim | Madderby guild house | young archivist, voice for lore questions | | `letters` side quest | |
| Brisa | Mist Rift | Warden (Act I), lost in her own fog | Zephlet 12, Millwhit 12, Tempestrel 13 | `rift_mist_sealed` | finds the way again; walks the ridge every morning |
| Senna | Rain Rift | Warden (Act II), hears only rain | Riptail 20, Tempestrel 21, Kelphound 22 | `rift_rain_sealed` | |
| Joral | Mirror Rift | Warden (Act II), sees only himself | Lumenewt 22, Glimmerax 23, Verdantusk 23 | `rift_mirror_sealed` | once saw an old woman with a compass in the mirror |
| Darrow | Root Rift | Warden (Act II), wants nothing to grow | Thornback 25, Frondmere 26, Reedwarden 25, Marshfife 26 | `rift_root_sealed` | plants a garden by the moor |
| Weda | Madderby | keeper of the dye spring (rest spot) | | | sister of the Veydal spring keeper |
| Moss | Greyreach | old cartographer who knew Mirela | | | thinks she is dead until the finale |
| Veit Harrow | Madderby, Greyreach, Ashmere | former guild cartographer | Shalebat 24, Duskdigger 25, Obsidroth 27 (Act II); last duel at the Shade Rift: Shalebat 35, Duskdigger 35, Obsidroth 36, Calderox 36 | `veit_respect`, `beat_veit_3` | see below |
| Brann | with Veit | Veit's helper | | | leaves Veit; works in the gravers' hall |
| Juna | everywhere | courier between the regions | | | a new line per act |
| Halvard | gravers' hall | master graver | | `mirela_plate` | from lasting maps to open maps |
| Nella | Cinderfold | graver apprentice | | | |
| Oswin | Cinderfold | keeper of the warm spring | | | |
| Tovan | Kiln Rift | Warden (Act III) | Calderox 32, Obsidroth 33, Smoldrake 31, Duskdigger 32 | `rift_kiln_sealed` | his father Harl held the Rift before him |
| Ilse | Glass Rift | Warden (Act III), fully silent | Leviarch 34, Lumenewt 33, Glimmerax 34, Tempestrel 33 | `rift_glass_sealed` | sings again and teaches a new verse |
| Odalys | Shade Rift | Warden (Act III), put out her own light | Silentra 35, Fenwarden 36, Burinox 35, Mendlace 35, Scrivane 36 | `rift_shade_sealed` | keeps the lamp lit for whoever is out there |
| the Echo | the Undrawn | the grieving choir of lost bonds | waves of 2, 3 and 4 hushed Spirlings | `story_complete` | listens at last |

Every Warden has the same shape (item 1605): a line before waking, a line after the duel, a line
after the mend and a later line after the finale.

### Rifts and Wardens (owner decision 2026-11-10: twelve Rifts)

Nine Rifts stand in the first three regions, the last three in Solenne (Act IV, `tools/art/world/solenne.py`). `GameState.STORY_RIFTS`
holds them in story order. A Rift built after 2026-11 has a fixed shape (`tools/art/world/rifts12.py`):
a Rift acolyte and two Wayfarers on the way, a puzzle that opens the way up, a spring to rest at,
the Warden at the tear, and a shortcut down the east side that opens with the mend. Its Warden
gives an Echo Crystal after the mend and fights rematches only after the finale. The Undrawn opens
only when every story Rift and every Rift heart is mended (`GameState.finale_flags()`); saves from
1.0 see the new Rifts as open side goals.

| # | Rift | Map id | Warden | Element | Team (Ring) | Puzzle | Battle rule | Gift |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Cinder Rift | `cinder_rift` | Orrin | Ember | 10 to 11 | - | Ember Pulse | Rift heart |
| 2 | Mist Rift | `mist_rift` | Brisa | Gale | 12 to 13 | turn the wind vanes in order | Fog Bank: every art on both sides is less accurate | Rift heart, Tailwind |
| 3 | Tidewater Rift | `tide_rift` | Maelis | Tide | 15 to 17 | - | Undertow | Rift heart |
| 4 | Rain Rift | `rain_rift` | Senna | Tide | 20 to 22 | - | - | - |
| 5 | Mirror Rift | `mirror_rift` | Joral | Lumen | 22 to 23 | - | - | - |
| 6 | Root Rift | `root_rift` | Darrow | Bloom | 25 to 26 | colour the roots red, yellow, green | Vine Tangle: the vines mend the weakest Spirling each round | Root Grip |
| 7 | Kiln Rift | `kiln_rift` | Tovan | Ember | 31 to 33 | - | - | - |
| 8 | Glass Rift | `glass_rift` | Ilse | Lumen | 33 to 34 | - | - | - |
| 9 | Shade Rift | `shade_rift` | Odalys | Umbra | 35 to 36 | turn the mirrors until the beacon burns | Night Dark: Pace no longer sets the turn order | Night Veil |
| 10 | Tower Rift | `tower_rift` | Aurelio | Gale | 36 to 37 | open four wind shutters in the chalked order | Sandstorm: every Spirling in front that is not Stone loses 1/16 Vigor each round | Squall |
| 11 | Oasis Rift | `oasis_rift` | Kaia | Tide | 37 to 38 | three sluice wheels: one below, then one above | Dry Well: every heal on both sides is halved | Dawn Mend |
| 12 | Sun Rift | `sun_rift` | Emrys | Lumen | 37 to 38 | push two sun-weights onto the dial plates | High Noon: Lumen arts on both sides hit 30% harder | Radiant Lance |

**Solenne (Act IV).** The sand road south from the Saltglass flats opens once the Shade Rift is
mended and leads to Ochrewell (well, bazaar, clay domes). The Tower Rift is open at once, the
Oasis Rift after the Tower, the Sun Rift after the Oasis. Kaia has worked for the Brass Veil, a
rival clan of water merchants, for six years and sold them the oasis; she admits it only after
her duel. Then Factor Lusk of the Veil waits in Ochrewell (story battle `veil_factor`) and tells
you that Emrys signed the contract as witness, which Emrys confirms before his own duel.

**Solenne side content (Act IV, `tools/art/world/solenne_side.py`).** Once Lusk is beaten in town,
the Brass Veil (third clan in `data/clans.json`: Kaia, Factor Lusk, his nephew Corin) opens up.
The Veil Cistern under the counting house is a three-floor dungeon (two valve rows, five Veil
crew, Corin's second duel, Lusk in the strongroom after the Sun Rift). Side goals `s4_veil`,
`s4_rival` (Corin three times, Ring 40 to 50), `s4_seals` (eight brass seals for Old Mags),
`s4_ious` (five IOUs for Qadir) and `s4_graves` (three graves the Veil prepaid, one for you).
Act IV betrayals: Kaia's well deed (`kaia_deed`, caught when Dunya warned you) and Lusk's
strongroom truce (`lusk_vault`, caught when Qadir warned you); favors with Qadir, Saffi and Corin.

The ring caps on Veteran and Rift-Born rise with every mended Rift (`GameState.LEVEL_CAPS`: 12, 15,
18, 23, ... 50, then 54, 57 and 60 for Solenne); after Act I they open fully. The story battles keep a curve that never drops (checked
by `tests/unit/test_rifts12.gd`): Kestra's tag battle at the Root Rift (Ring 23 to 24) sits between
Joral and Darrow, Veit's last duel at the Shade Rift (Ring 35 to 36) between his plate and Odalys.

### Kestra (item 1555)

Kestra grew up on Crowcrest, the scree ridge above Brindlewick. Twelve years ago a small Rift
opened over the tarn for one night, and a Zephlet came through it. She called it **Tatter**
because of its frayed wing and never told anyone where it came from. Since then she has wanted
to *understand* Rifts, not close them: if Tatter came through one, what else is on the other side?

Her stance changes visibly (item 1561):

- **Act I, open:** "Every Rift you mend is a door we never open."
- **Act II, unsure:** after the Rain Rift is mended, Tatter falls silent. She blames the mending,
  until the guild files show that Rift-born Spirlings need an anchor bond, not an open Rift.
- **Act III, a third way:** she wants neither Veit's erasing nor a sealed world. A gate with a
  keeper is her idea of a good end.

Kestra's team grows by one member per act. Duels: Crowcrest (Act I), Madderby (Act II:
Tempestrel 22, Glimmerax 21, Shalebat 21, Kelpup 20), the far end of the Wide Rift (Act III,
5 Spirlings, Ring 34 to 36, a farewell duel, not an obstacle).

### Mirela (item 1586)

- **Life:** born in Brindlewick, the first cartographer of the valley guild. Married Aldo, the
  ferryman. When the sky split over the lake 40 years ago she went into the Rift to map it,
  with her old Wickit Glim. Her daughter was small then; the player is that daughter's child.
- **Drawing style:** thin ink lines, a compass rose in the corner of every page, notes in the
  margin that talk to Aldo. She never draws an edge she has not walked.
- **Why she stayed 40 years:** behind the Rift she found the Undrawn and the Echo at its heart.
  The Wide Rift kept tearing wider; only someone drawing its edge from the inside could hold
  it. She became its Warden from the far side. "Still drawing. Still here. M."
- Her map book has 14 pages: pages 1 to 6 in Veydal (Act I), 7 to 10 in Corvane, 11 to 14 in
  Ashmere. Pages 7 to 14 tell her time in the Undrawn and reveal the lore step by step.

### Veit Harrow (item 1607)

Twenty years ago Veit, then a guild cartographer, lost his Mirkmole **Ash** to the Hush near
Greyreach: Ash went silent and walked into a Rift. Veit blames the Rifts themselves. In Act II
he burns the maps of Rifts to "erase" them; in Act III he engraves a plate in the gravers' hall
that would wipe out the Wide Rift and everything behind it, Mirela included. He doubts when he
meets the echo of Ash in the Undrawn. Depending on the player's choices he makes peace
(veit_respect high) or leaves (low). He is never a villain, only someone grieving.

## Clans and trust (owner study 2026-11-10, part 3)

Two clans fight over the valley behind the Rift story. Data: `data/clans.json`, text:
`data/dialogue/clans.json`, logic: `scripts/core/Trust.gd`, German: `tools/i18n/de_clans.py`.
The theme is "trust no one": dry humour, polite threats, violence off screen and sudden.

- **Haus Marrovel** (seat Veydal, Corvane): old nobility, keeps the Rift pacts, rules by etiquette
  and debt. Ottilie Kael (clan mother, hidden power), Fenrick Kael (loud patriarch), Brannoc Kael
  (broken heir, former Rift gladiator), Pip Kael (the spark).
- **The Ruskwebers** (seat Ashmere, Solenne): smugglers and miners, rule by fear and wages.
  Mother Grell (vengeful rival), Sable Ruskweber (charming opportunist).
- **Between them:** Warden Ilo Vash (sells results to both sides, Chief Warden from Act II),
  Warden Captain Dace Morrow (two tills), Marlo (Spirling doctor, the conscience), Wren (runs the
  Crooked Kettle guest house in Brindlewick; leverage for both clans).
- **The strangers from the map's edge** came through the Wide Rift. The clans hire them because
  nobody owes them anything. Allies: Aldra, Lipka, Nail (Act I), Amir, Elma (Act II), Lejla, Mirza
  (Act III). Traitors: Kenan (Act I), Farida, Heider (Act II), Leith (Act III). Lipka and Leith can
  turn either way with the hidden values.

### Hidden trust

Every figure has a hidden **trust** and **use** value (0-100, start values in the data, changes
in `story_vars` as `trust_<id>` / `use_<id>`). A figure betrays when use is higher than trust. The
player never sees the numbers. Dialogue can test them with `"trust_min"` / `"trust_max"`.
Actions: `trust <id> <change> [use change]`, `favor <id>`, `betrayal <id>`, `ledger <id>`.

- **Favors**: lend your lead Spirling (betrayal: its keepsake is stolen), lend coins (betrayal:
  the coins are gone), believe a tip (betrayal: an ambush battle). A loyal figure keeps its word
  and sometimes pays back more (`reward_chance`).
- **Scripted betrayals** always happen. A warning picked up earlier (flags in `warned_by`) turns
  them from "struck" (ambush, loss) into "caught". Marlo's fate uses his trust instead: every time
  he is used as an alibi his trust drops by 15; under 40 he is gone in Act III.
- **The Ledger** (Schuldbuch, pause menu, shown once it has an entry) lists every secret the
  player shares. Each entry is leverage and a risk.

| Act | Betrayal 1 | Betrayal 2 | Twists used |
| --- | --- | --- | --- |
| I Veydal (`rift_cinder_sealed`) | Vash sells the blank battle record (`clan_b1`) | Fenrick's sealed letter names the player (`clan_b2`) | ash in the brooding oven |
| II Corvane (`corvane_arrived`) | Brannoc sells the Woadfen routes (`clan_b3`) | Ottilie sacrifices Morrow; the war was ordered (`clan_b4`) | the last feast, the mercy post, the spy in the guest book, the gift of honour, the rising referee |
| III Ashmere (`act2_end`) | Sable sells the player at the card hall (`clan_b5`) | Marlo lives or is gone by his trust (`clan_b6`) | also: Liss reports to Sable (`clan_b7`, `liss_spy`), Fenrick's fading seal turns his Spirling on you, Marlo sedates it if his trust is 50+ (`clan_b8`, `fenrick_seal`); the seal in the breeding register, the breeder who lived, the fading seal |
| IV Solenne (`rift_shade_sealed`) | Vash drains the palace basin and finds the Act I ash (`clan_b9`, `basin`; caught if Tobs moved the urn) | Ottilie's and Fenrick's throne offers carry the same sleepwort (`clan_b10`, `clan_b11`; caught if you heard the other offer or let Marlo check the wax) | the fixer's choice (Wren), the forgotten son (Kerr Haldane), two thrones one poison, the reckoning in the Sun Palace |

**Trust choices with consequences (Acts III and IV).** Grell's breeder: keep the secret (Grell warns
you about Kerr in Act IV) or sell it to the Marrovels. Liss: welcome her or watch her first. Wren:
side with the clan (Wren leaves) or with her (Ottilie turns). Kerr Haldane hunts Pip: hand her over,
fight him (`kerr_haldane`), or, with the breeding register, point him at Ottilie. Tobs moves the
ash urn for 500 coins and stays loyal only if you asked him nicely first. Sable's dune tip in Act IV
is a believe-tip favour that usually ends in an ambush.

**The reckoning** (`data/scenes/solenne_reckoning.json`, started by Ottilie once the Sun Rift is
mended): both throne betrayals are cashed in, Grell arrives with Brannoc (and Kerr if turned), Marlo
or his empty chair, and the player decides what happens to the pact deeds: burn them, give them to
the Warden guild, or keep them and betray both clans (`c4_end_burn`, `c4_end_guild`, `c4_end_keep`).
`clans/finale_coda` closes that thread in `finale_5` before the credits.

## Spoiler flags (for store texts and screenshots)

Store material must not show anything behind these flags: `act2_end`, `mirela_plate`,
`undrawn_reached`, `mirela_met`, `story_complete`.
