# Balance notes

How to run: `godot --headless --path . -s res://tools/balance_sim.gd -- --level 36 --rounds 10 --mode duel`
(switches: `--level`, `--rounds`, `--seed`, `--mode duel|team`, `--ai`, `--out report.md`,
`--json report.json`; the old positional form `<level> <rounds> [out.md]` still works).

- **duel**: every species fights every other species of the same evolution stage 1-on-1, both
  sides on the greedy AI (tier 1), no items. Forms that can't exist yet at that level are skipped,
  and so are forms a player would already have evolved.
- **team**: random valid teams of 3 and 5 (no species twice), both sides on AI tier 2, one
  Spirling on the field at a time; the report adds picks per element and the share of rests.
- **ladder**: the same random teams of 3, AI tier n against n-1 for n = 1 to 3, sides swapping
  every battle (targets: 1 vs 0 at least 75 %, 2 vs 1 at least 60 %, 3 vs 2 at least 55 %).
- **mono**: teams of one element (3 species where it has them) against another element, target
  band 42 to 58 % per element.
- **goals**: every bonus goal with its reference team from `tools/balance/goal_teams.json` on
  Tamer, each at least 20 % (also checked by `test_goal_sim.gd`).
- `--field <id>` and `--variant <id,id>` put every duel, team, ladder and mono battle on one field
  and under rule variants, so each can be measured on its own.
- `--difficulty story|tamer|veteran|rift_born` tunes the foe side of duel, team, ladder and mono
  battles like a Wayfarer: Spark, ring shift, AI tier (not in ladder), damage and start Energy.
- The team report also shows the rest share against its band (10 to 25 %), the hit share of every
  status art, how many turns each status holds, and reactions per 100 battles.
- **keepsakes**: every holdable item, held by the lead of one side, against the same battle
  without (at most +6 points). **fields**: teams of a field's boosted element on the field against
  the same battle without (+8 to +15 points).
- `--seeds N` (duel, team): the same run on N seeds; the report adds mean and spread per species
  and marks a spread over 10 points as uncertain. **mirror**: every species against itself
  (400 duels each), the player side must land between 45 and 55 %. The sim counts a double KO
  (both sides out at once) as a draw; the game hands it to the player, which alone gave the
  player side up to 76 % in mirror duels (Lumenewt, two Omen Bells landing together).
- The team report lists the new arts a team at that ring carries that got less than 1 % of their
  element's picks.
- **puzzle**: every puzzle of `data/puzzles.json` searched to the end, with the number of winning
  lines, the fewest turns and whether the lantern target (`best_turns`) can be reached.
- `--compare [path]` (team mode): flags every species and art whose win rate moved more than 8
  points from `tools/balance/baseline_lv36.json` (arts: share of uses by the winning side, at
  least 30 uses). The baseline is `--mode team --level 36 --rounds 3000 --json <path>` at the
  default seed; compare with the same rounds and seed, since another seed alone moves a few
  arts by up to about 15 points.

Both modes run on the real `BattleModel` (all effects, fields and rules), never a separate damage
path. `--json` writes every number for tests and comparisons.

Slow tests (item 865): the band tests and the baseline compare live in `tests/slow`
(`test_slow_*`) and run in the nightly workflow `.github/workflows/nightly-sim.yml` or by hand:
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/slow/.gutconfig.json`.
The normal test run skips them; its balance tests take about 80 seconds.

## Zielbänder (target bands)

| Measure | Target | Checked by |
| --- | --- | --- |
| Duel win rate per species at Lv36 | 25% to 75% | `test_balance.gd`, `test_no_species_dominates_its_stage` |
| Team win rate per species at Lv36 | 30% to 70% | `test_balance.gd`, `test_team_mode_keeps_every_species_in_band` |
| Team battles that stall (120 turns) | none | `test_balance.gd`, same test |
| Battles with only the new arts that hit 60 turns | none | `test_move_curve.gd`, `test_fuzz_new_arts_only` |
| Turns to KO in a Lv36 duel | 2.5 to 4.0 on average | `test_slow_sim_bands.gd` (item 851) |
| First-mover advantage (faster Spirling wins) | at most 62% | `test_slow_sim_bands.gd` (item 850) |
| Damage art curve: power x accuracy / (energy + 1) x effect factor | 9 to 18 | `test_move_curve.gd` |
| Accuracy of any art | at least 75% | `test_move_curve.gd` |
| Status chance of a damage art | at most 30% | `test_move_curve.gd` |
| Cooldown arts | power 110+, energy 7+ | `test_move_curve.gd` |
| Arts per element | 14+, of them 3+ status arts and 1+ for 1-2 Energy | `test_move_curve.gd` |
| Learnset size | at most 14 arts | `test_move_curve.gd` |

Measured on 6 Nov 2026 (plan area 2, after the new arts): Lv36 duel turns to KO 2.5, first-mover
advantage 52%; Lv36 teams (200 battles, seed 7) 0 draws, every species between 39% and 66%.
Glimmerax sits lowest in duels (26%, it loses to 7 of 8 same-stage species on base stats).

Long fights: from turn `BattleRules.WEARY_TURN` (40) nobody heals any more, so two Spirlings that
mend faster than they hurt each other can't stall forever.

## Type balance (Nov 2026)

`python3 tools/balance/type_sim.py` (runs in CI, job ip-check, about 10 seconds) checks the
element chart in `data/type_chart.json` and plays 20000 seeded team battles per unfold stage at
ring 36: teams of 3 distinct kinds of the same stage (2 in the final stage, which has 4 kinds),
every battle played twice with the sides swapped. Kinds that never unfold and come from nothing
(Glasstarn, Lanternel) count as second stage; legendaries (ancient) are left out. It fails if the
chart breaks a rule or the chart sim (below) leaves its band. With `--strict` (the CI gate since
Nov 2026) it also fails when a kind or an element leaves 40 to 60 %, so no Spirling dominates on its
base stats; retune outliers by scaling all five stats of the kind together, which keeps its shape
and its line's shape. `--md <path>` writes the report.

Chart sim (gate, since Nov 2026): one Spirling per element with equal stats and a single art of its
own element, so only the chart decides. Every element meets every element 1 on 1 (40 seeded duels
per pair) and every team of 3 distinct elements meets every team it shares no element with (4 lead
orders, sides swapped). It runs for the Era I elements alone and for all
sixteen, so Rust, Mask, Acid, Frost, Gilt and Zenith are measured although they sit on no Spirling yet. An element has to stay
in 40 to 60 % (1 on 1 and in teams), a team of 3 in 30 to 70 %.

It is a Python mirror of the battle core: stat curve, damage curve, STAB, keen hits, roll,
accuracy, Energy (start 10, +1 a turn, rest +2), priority and Pace order, greedy art choice.
Status arts, traits, Keepsakes and fields are left out on purpose, so it measures the chart and
base stats only; the full model stays in `tools/balance_sim.gd`. The report below is today's stats.

Chart rules: every element has at least 2 real strengths and 2 real weaknesses (Lumen and Umbra
beat each other, which stays neutral both ways and counts as neither), as many real strengths as
weaknesses (for Era I alone and for all eras), and no element strictly dominates another. The Era I
chart is unchanged. Ink and Echo are prepared for Era II and sit on legendaries only. Each Era I
element beats one of them and loses to the other, which also gives Lumen and Umbra their second
real strength and weakness.

Rust and Mask (Vellmarch, #352) follow the same pattern: every element except Volt beats one of
them and loses to the other, and Rust beats Mask. Ember, Tide, Lumen, Ink and Echo beat Rust and
lose to Mask; Bloom, Stone, Gale and Umbra beat Mask and lose to Rust. Retune from the #352 chart
(chart sim, all eras): Rust had 3 strengths and 2 weaknesses and pushed Volt and Stone to 3 and 4,
Ink and Echo had 4 and 5, Lumen 2 and 3, Ember, Tide, Gale and Umbra one strength ahead. Volt left
the Rust/Mask pair because a Volt that beats Mask makes Gale/Ink/Mask (all three weak to Volt and
Umbra) fall to 28 % as a team. Now every element is 4 and 4 or 5 and 5 (Lumen and Umbra 3 and 3,
Volt 3 and 3), all between 48.9 and 51.5 %, every team of 3 between 36.8 and 64.1 %.

Acid and Frost (Era III, the post-game region Quillmarch, `data/region3.json`) are in the chart the
same way and enter the Elements enum with their own Spirlings; Quillmarch's first 15 kinds
(tools/art/lines/quillmarch.py) use Era I elements. Acid beats Stone, Rust, Ink and Ember and loses
to Tide, Bloom, Gale and Frost; Frost beats Bloom, Gale, Tide and Acid and loses to Ember, Stone,
Ink and Rust. Each element that gains one of them as a strength also gains the other as a weakness,
so every count stays even (Acid and Frost 4 and 4). Chart sim with all 14: Acid 51.2 %, Frost
49.8 %, every team of 3 between 33.3 and 65.0 %.

With the 15 Quillmarch kinds in the ring-36 pool, Sluicewarden (Corvane, Stone/Bloom) won 81 of
115 team battles (70.4 %, test_balance team mode, seed 7). Scaling the five Quillmarch kinds of
that ring by 0.85 to 1.15 moved it by at most two battles, so the cause is Sluicewarden itself:
its stats are scaled by 0.95 by hand in `data/spirlings.json` (total 455 to 432), measured on the
full model at 74 of 115 (64.3 %), every other kind at or under 67.6 % (Fulgorath). A rebuild of
the Corvane lines re-tunes it and has to measure this again.

Gilt and Zenith (Halcyra, Era IV, data/region4.json) are the next pair and wait in the chart for
Halcyra's Spirlings. They mirror each other and are neutral to each other: Gilt beats Stone and Ink
and loses to Ember and Tide; Zenith beats Ember and Tide and loses to Stone and Ink. So each of
those four gains one strength and one weakness and every era stays even (the chart rules are now
checked up to every era that adds elements: I, II, III and IV). Gilt and Zenith are 2 and 2. Chart sim,
all sixteen at the time of Halcyra (before Acid and Frost): Gilt 52.1 % 1 on 1 and 49.8 % in teams, Zenith 49.4 % and 49.4 %, every team of 3
between 37.8 and 64.5 %; Era I is unchanged.

Stats are not tuned yet. The full battle model (`tools/balance_sim.gd`, GUT and nightly tests) is
the real gate, so in CI this tool only reports the 40 to 60 % band; chart rule breaks still fail.
`--strict` fails on the band too. Tuning the stats below on this sim alone broke the full-model
duel and team bands (Calderox 4 %, Verdantusk 95 %), three puzzles, a goal, a raid test and the
pre_orrin Warden bands, so any tuning has to be measured on the full model and come together with
those.

Proposal (not applied): the 37 stat sets that bring every kind into 42 to 59 % in this sim. Also
proposed: Calderox learns Root Grip at ring 36 and Cairnhold at ring 1, a Bloom answer to Leviarch,
which hits both Ember/Stone finals four times (Leviarch 86 %, Calderox 24 % here today).

| Kind | Now (HP/ATK/FOC/SPD/DEF) | Proposed | Total |
| --- | --- | --- | --- |
| Smoldrake | 74/88/92/94/70 | 83/99/103/105/78 | 418 -> 468 |
| Calderox | 92/112/108/92/96 | 100/118/96/104/100 | 500 -> 518 |
| Riptail | 86/72/84/76/82 | 88/74/86/78/84 | 400 -> 410 |
| Leviarch | 108/90/112/86/104 | 97/81/101/77/94 | 500 -> 450 |
| Verdantusk | 92/88/88/86/94 | 97/92/92/90/99 | 448 -> 470 |
| Zephlet | 54/62/66/88/50 | 50/57/61/81/46 | 320 -> 295 |
| Tempestrel | 76/94/92/118/70 | 69/86/84/108/64 | 450 -> 411 |
| Wickit | 52/50/64/66/52 | 56/53/68/71/56 | 284 -> 304 |
| Mirkmole | 62/78/48/68/66 | 60/76/47/66/64 | 322 -> 313 |
| Duskdigger | 90/110/58/74/96 | 93/113/60/76/99 | 428 -> 441 |
| Blotling | 58/44/80/72/56 | 49/37/68/61/48 | 310 -> 263 |
| Scrivane | 74/58/112/104/72 | 66/52/99/92/64 | 420 -> 373 |
| Paddlewisp | 52/72/54/88/46 | 48/66/49/81/42 | 312 -> 286 |
| Ferrowyn | 72/100/76/118/64 | 65/90/68/106/57 | 430 -> 386 |
| Talusk | 60/66/36/60/82 | 64/71/39/64/88 | 304 -> 326 |
| Talusgard | 84/90/60/88/112 | 89/96/64/94/119 | 434 -> 462 |
| Fluting | 54/46/84/76/54 | 50/42/77/70/50 | 314 -> 289 |
| Glasstarn | 82/52/100/110/86 | 78/49/95/104/81 | 430 -> 407 |
| Millvane | 80/95/72/111/74 | 78/93/70/108/72 | 432 -> 421 |
| Rainmantle | 82/62/113/91/77 | 80/60/110/89/75 | 425 -> 414 |
| Cogmite | 72/57/51/49/80 | 74/58/52/50/82 | 309 -> 316 |
| Delthorn | 106/79/70/65/115 | 103/77/68/63/112 | 435 -> 423 |
| Siltgrove | 81/92/72/112/75 | 83/95/74/115/77 | 432 -> 444 |
| Cindle | 58/81/50/69/52 | 65/90/56/77/58 | 310 -> 346 |
| Glassfell | 80/117/71/97/66 | 83/121/73/100/68 | 431 -> 445 |
| Burinox | 83/62/118/90/78 | 80/60/114/87/76 | 431 -> 417 |
| Ashcrest | 84/97/68/113/76 | 82/94/66/110/74 | 438 -> 426 |
| Bogwick | 62/56/77/53/62 | 60/54/74/51/60 | 310 -> 299 |
| Cullet | 74/56/52/48/83 | 82/62/57/53/92 | 313 -> 346 |
| Cullhorn | 105/74/70/65/112 | 116/82/77/72/124 | 426 -> 471 |
| Smeltpup | 56/87/52/66/51 | 59/92/55/70/54 | 312 -> 330 |
| Smeltmaw | 77/118/76/97/69 | 80/122/79/100/71 | 437 -> 452 |
| Solkit | 60/69/51/78/50 | 67/77/57/87/56 | 308 -> 344 |
| Duneshrew | 75/53/51/46/84 | 77/54/52/47/86 | 309 -> 316 |
| Dunebastion | 103/80/70/64/111 | 106/82/72/66/114 | 428 -> 440 |
| Mirassil | 79/115/73/96/68 | 77/112/71/93/66 | 431 -> 419 |
| Zenithare | 83/96/66/110/76 | 78/90/62/103/71 | 431 -> 404 |

<!-- type_sim report, rewrite with: python3 tools/balance/type_sim.py --md <path> -->
Ring 36, 20000 team battles per stage (teams of 3, 2 in a stage of fewer than 6, sides swapped), seed 20261111, band 40 to 60 %.

| Element | Era | Strong vs | Weak vs | Win rate |
| --- | --- | --- | --- | --- |
| Ember | I | Bloom, Umbra, Echo, Rust, Gilt, Frost | Tide, Stone, Ink, Mask, Acid, Zenith | 49.3 % |
| Tide | I | Ember, Stone, Echo, Rust, Gilt, Acid | Bloom, Volt, Ink, Mask, Frost, Zenith | 51.0 % |
| Bloom | I | Tide, Stone, Echo, Mask, Acid | Ember, Gale, Ink, Rust, Frost | 51.1 % |
| Volt | I | Tide, Gale, Ink | Stone, Lumen, Echo | 50.9 % |
| Stone | I | Ember, Volt, Ink, Mask, Zenith, Frost | Tide, Bloom, Echo, Rust, Acid, Gilt | 49.3 % |
| Gale | I | Bloom, Lumen, Echo, Mask, Acid | Volt, Umbra, Ink, Rust, Frost | 51.3 % |
| Lumen | I | Volt, Ink, Rust | Gale, Echo, Mask | 50.1 % |
| Umbra | I | Gale, Ink, Mask | Ember, Echo, Rust | 50.7 % |
| Ink | II | Ember, Tide, Bloom, Gale, Rust, Zenith, Frost | Volt, Stone, Lumen, Umbra, Mask, Acid, Gilt | 51.3 % |
| Echo | II | Volt, Stone, Lumen, Umbra, Rust | Ember, Tide, Bloom, Gale, Mask | 45.7 % |
| Rust | II | Stone, Gale, Umbra, Bloom, Mask, Frost | Ember, Tide, Lumen, Ink, Echo, Acid | legendaries only |
| Mask | II | Lumen, Echo, Ink, Ember, Tide | Bloom, Stone, Gale, Umbra, Rust | legendaries only |
| Acid | III | Stone, Rust, Ink, Ember | Tide, Bloom, Gale, Frost | 48.6 % |
| Frost | III | Bloom, Gale, Tide, Acid | Ember, Stone, Ink, Rust | 53.7 % |
| Gilt | IV | Stone, Ink | Ember, Tide | legendaries only |
| Zenith | IV | Ember, Tide | Stone, Ink | legendaries only |

Species: 350 measured, lowest 41.2 %, highest 58.4 %.

| Species | Stage | Win rate | Games |
| --- | --- | --- | --- |
| Paddlewisp | 1 | 58.4 % | 1730 |
| Fumelet | 1 | 57.7 % | 1780 |
| Blotling | 1 | 57.6 % | 1832 |
| Clasplet | 1 | 55.8 % | 1822 |
| Zephlet | 1 | 55.7 % | 1824 |
| Highhare | 1 | 55.2 % | 1950 |
| Puffbellow | 1 | 55.0 % | 1876 |
| Palmop | 1 | 54.9 % | 1778 |
| Diplit | 1 | 54.9 % | 1792 |
| Glacilet | 1 | 54.9 % | 1772 |
| Drypup | 1 | 54.8 % | 1888 |
| Nibbet | 1 | 54.7 % | 1784 |
| Hoarling | 1 | 54.6 % | 1894 |
| Ripjolt | 1 | 54.6 % | 1854 |
| Drizzlet | 1 | 54.6 % | 1828 |
| Cindrik | 1 | 54.6 % | 1752 |
| Lichub | 1 | 54.4 % | 1796 |
| Bogwick | 1 | 54.2 % | 1914 |
| Vesk | 1 | 54.2 % | 1734 |
| Haboblet | 1 | 54.2 % | 1760 |
| Charsprout | 1 | 54.2 % | 1822 |
| Smudgel | 1 | 54.1 % | 1840 |
| Rubrit | 1 | 54.0 % | 1802 |
| Skimmit | 1 | 53.9 % | 1850 |
| Canalurk | 1 | 53.9 % | 1788 |
| Spinnub | 1 | 53.8 % | 1784 |
| Fizzlet | 1 | 53.7 % | 1818 |
| Brookhop | 1 | 53.7 % | 1848 |
| Blotkin | 1 | 53.6 % | 1864 |
| Mortarant | 1 | 53.6 % | 1936 |
| Sleetowl | 1 | 53.5 % | 1876 |
| Siltby | 1 | 53.4 % | 1904 |
| Forgefly | 1 | 53.3 % | 1798 |
| Fulgrit | 1 | 53.3 % | 1748 |
| Rimekit | 1 | 53.3 % | 1870 |
| Vaporel | 1 | 53.3 % | 1826 |
| Gelidfin | 1 | 53.2 % | 1794 |
| Filigrin | 1 | 53.2 % | 1902 |
| Platewig | 1 | 53.1 % | 1874 |
| Canalet | 1 | 53.0 % | 1854 |
| Glazel | 1 | 53.0 % | 1922 |
| Woadlet | 1 | 53.0 % | 1872 |
| Verdigrub | 1 | 53.0 % | 1808 |
| Corrodent | 1 | 53.0 % | 1826 |
| Mirkmole | 1 | 52.8 % | 1778 |
| Fluting | 1 | 52.7 % | 1800 |
| Fiddlit | 1 | 52.5 % | 1820 |
| Gloamhog | 1 | 52.4 % | 1846 |
| Weirkit | 1 | 52.4 % | 1838 |
| Seamlet | 1 | 52.1 % | 1714 |
| Quilmoth | 1 | 52.0 % | 1774 |
| Vanepip | 1 | 51.8 % | 1856 |
| Inkpip | 1 | 51.7 % | 1858 |
| Gleamgrub | 1 | 51.6 % | 1804 |
| Peatlet | 1 | 51.6 % | 1928 |
| Ardlet | 1 | 51.5 % | 1850 |
| Flicklet | 1 | 51.4 % | 1826 |
| Pinchkin | 1 | 51.3 % | 1874 |
| Skerrit | 1 | 51.1 % | 1876 |
| Chirrik | 1 | 51.1 % | 1768 |
| Covepup | 1 | 51.1 % | 1788 |
| Hushkin | 1 | 50.9 % | 1836 |
| Rookit | 1 | 50.9 % | 1834 |
| Sirocub | 1 | 50.7 % | 1828 |
| Nimbub | 1 | 50.6 % | 1812 |
| Prismist | 1 | 50.3 % | 1808 |
| Lampick | 1 | 50.2 % | 1820 |
| Vatrat | 1 | 50.2 % | 1848 |
| Stylet | 1 | 50.1 % | 1800 |
| Gloomgill | 1 | 50.0 % | 1844 |
| Hazejel | 1 | 50.0 % | 1840 |
| Brinelet | 1 | 49.6 % | 1872 |
| Rushkit | 1 | 49.3 % | 1842 |
| Corocub | 1 | 49.3 % | 1776 |
| Orrlet | 1 | 49.2 % | 1798 |
| Ingotlet | 1 | 49.1 % | 1758 |
| Quenchet | 1 | 49.1 % | 1818 |
| Puddock | 1 | 48.9 % | 1786 |
| Scaldasp | 1 | 48.9 % | 1676 |
| Noonpip | 1 | 48.9 % | 1844 |
| Wadlet | 1 | 48.6 % | 1818 |
| Glimmoth | 1 | 48.5 % | 1778 |
| Morelit | 1 | 48.4 % | 1804 |
| Millwhit | 1 | 48.1 % | 1764 |
| Mordling | 1 | 48.1 % | 1758 |
| Mossling | 1 | 48.0 % | 1882 |
| Glimshell | 1 | 47.9 % | 1656 |
| Sablet | 1 | 47.9 % | 1792 |
| Grindlet | 1 | 47.8 % | 1836 |
| Ergfin | 1 | 47.7 % | 1770 |
| Sootpaw | 1 | 47.7 % | 1850 |
| Shalebat | 1 | 47.7 % | 1796 |
| Ashwren | 1 | 47.7 % | 1834 |
| Coalkid | 1 | 47.5 % | 1824 |
| Reedquill | 1 | 47.4 % | 1824 |
| Sluicekit | 1 | 47.4 % | 1676 |
| Thrashkin | 1 | 47.4 % | 1790 |
| Puddlet | 1 | 47.3 % | 1786 |
| Solkit | 1 | 47.3 % | 1722 |
| Padlet | 1 | 47.3 % | 1898 |
| Pressbug | 1 | 47.1 % | 1804 |
| Silthop | 1 | 47.1 % | 1874 |
| Stampet | 1 | 47.0 % | 1832 |
| Rollib | 1 | 46.7 % | 1726 |
| Flourie | 1 | 46.7 % | 1800 |
| Glowflit | 1 | 46.5 % | 1782 |
| Bakedil | 1 | 46.3 % | 1808 |
| Copperling | 1 | 46.3 % | 1826 |
| Velvit | 1 | 46.3 % | 1884 |
| Carabun | 1 | 46.3 % | 1776 |
| Shimmerlet | 1 | 46.2 % | 1752 |
| Saltsprig | 1 | 46.2 % | 1834 |
| Burrin | 1 | 45.9 % | 1756 |
| Brickit | 1 | 45.7 % | 1830 |
| Clinklet | 1 | 45.6 % | 1790 |
| Chimelet | 1 | 44.8 % | 1936 |
| Kindlop | 1 | 44.8 % | 1806 |
| Zippit | 1 | 44.4 % | 1930 |
| Etchling | 1 | 44.2 % | 1834 |
| Duneshrew | 1 | 43.7 % | 1756 |
| Vitrill | 1 | 43.5 % | 1874 |
| Obelit | 1 | 43.0 % | 1788 |
| Stiltwade | 1 | 43.0 % | 1868 |
| Cullet | 1 | 42.8 % | 1786 |
| Smeltpup | 1 | 42.7 % | 1786 |
| Cogmite | 1 | 42.5 % | 1748 |
| Wickit | 1 | 42.3 % | 1734 |
| Cindle | 1 | 42.1 % | 1806 |
| Croziel | 1 | 41.9 % | 1950 |
| Kelpup | 1 | 41.9 % | 1850 |
| Lodekit | 1 | 41.8 % | 1904 |
| Talusk | 1 | 41.7 % | 1688 |
| Glasstarn | 2 | 58.3 % | 1692 |
| Charsylvan | 2 | 58.2 % | 1642 |
| Ferrowyn | 2 | 58.1 % | 1588 |
| Diparrow | 2 | 57.6 % | 1520 |
| Tempestrel | 2 | 57.6 % | 1602 |
| Scrivane | 2 | 57.3 % | 1710 |
| Burinox | 2 | 57.0 % | 1548 |
| Ashcrest | 2 | 57.0 % | 1538 |
| Zenithare | 2 | 56.9 % | 1618 |
| Glimmerax | 2 | 56.8 % | 1592 |
| Covewarden | 2 | 56.2 % | 1636 |
| Millvane | 2 | 56.0 % | 1484 |
| Quenchcoil | 2 | 55.9 % | 1620 |
| Rainmantle | 2 | 55.7 % | 1750 |
| Brinewhorl | 2 | 55.0 % | 1590 |
| Lichenbear | 2 | 55.0 % | 1594 |
| Duskmirrah | 2 | 54.7 % | 1530 |
| Bellowroc | 2 | 54.6 % | 1628 |
| Smudgeworm | 2 | 54.5 % | 1676 |
| Delthorn | 2 | 54.5 % | 1660 |
| Saltcrown | 2 | 54.4 % | 1576 |
| Glacilisk | 2 | 54.4 % | 1684 |
| Peatbloom | 2 | 54.4 % | 1550 |
| Quilmothra | 2 | 54.3 % | 1538 |
| Hoarstag | 2 | 54.1 % | 1640 |
| Fumewraith | 2 | 54.1 % | 1596 |
| Puffglass | 2 | 53.9 % | 1588 |
| Hazejellith | 2 | 53.8 % | 1638 |
| Nibquill | 2 | 53.8 % | 1544 |
| Frostfoil | 2 | 53.7 % | 1598 |
| Dunebastion | 2 | 53.6 % | 1488 |
| Threshox | 2 | 53.6 % | 1478 |
| Gelidray | 2 | 53.5 % | 1608 |
| Mortarmarch | 2 | 53.4 % | 1574 |
| Silentra | 2 | 53.4 % | 1572 |
| Filigrace | 2 | 53.4 % | 1522 |
| Coronarch | 2 | 53.2 % | 1636 |
| Brookbaron | 2 | 53.2 % | 1680 |
| Pinchward | 2 | 52.9 % | 1604 |
| Gleamworm | 2 | 52.7 % | 1608 |
| Canalurker | 2 | 52.6 % | 1672 |
| Blotgrimm | 2 | 52.5 % | 1536 |
| Rimelynx | 2 | 52.5 % | 1510 |
| Skerrigale | 2 | 52.4 % | 1556 |
| Nimbuck | 2 | 52.3 % | 1626 |
| Dryhound | 2 | 52.2 % | 1650 |
| Siltarra | 2 | 52.1 % | 1678 |
| Weirrunner | 2 | 51.9 % | 1560 |
| Sleetcowl | 2 | 51.8 % | 1540 |
| Dusktern | 2 | 51.7 % | 1664 |
| Rookwarden | 2 | 51.5 % | 1618 |
| Pressbeetle | 2 | 51.5 % | 1682 |
| Woadwhorl | 2 | 51.3 % | 1556 |
| Glimbastion | 2 | 51.2 % | 1538 |
| Gloamquill | 2 | 51.2 % | 1632 |
| Verdigrand | 2 | 51.2 % | 1506 |
| Solmantle | 2 | 51.1 % | 1658 |
| Fizzgrove | 2 | 51.1 % | 1584 |
| Cindrel | 2 | 51.0 % | 1524 |
| Prismistral | 2 | 51.0 % | 1636 |
| Stylox | 2 | 51.0 % | 1610 |
| Obsidroth | 2 | 50.9 % | 1604 |
| Lampickard | 2 | 50.9 % | 1616 |
| Reedwarden | 2 | 50.8 % | 1582 |
| Skimmarch | 2 | 50.7 % | 1642 |
| Vatreeve | 2 | 50.7 % | 1528 |
| Clinkshell | 2 | 50.6 % | 1582 |
| Noonwhist | 2 | 50.6 % | 1610 |
| Sluicer | 2 | 50.6 % | 1484 |
| Inkspool | 2 | 50.5 % | 1620 |
| Chirrikade | 2 | 50.4 % | 1624 |
| Mirassil | 2 | 50.3 % | 1640 |
| Morelamp | 2 | 50.1 % | 1546 |
| Flueling | 2 | 49.9 % | 1666 |
| Rubricorn | 2 | 49.9 % | 1698 |
| Cartocoil | 2 | 49.9 % | 1660 |
| Gloomgillar | 2 | 49.9 % | 1616 |
| Haboborn | 2 | 49.8 % | 1642 |
| Kelphound | 2 | 49.8 % | 1492 |
| Heliodrop | 2 | 49.7 % | 1586 |
| Rushprowl | 2 | 49.6 % | 1610 |
| Spinnarow | 2 | 49.6 % | 1508 |
| Shadeback | 2 | 49.5 % | 1688 |
| Vaporelle | 2 | 49.5 % | 1680 |
| Vanecrow | 2 | 49.5 % | 1606 |
| Sablowl | 2 | 49.5 % | 1688 |
| Orrerine | 2 | 49.4 % | 1610 |
| Scaldcoil | 2 | 49.1 % | 1622 |
| Padlotus | 2 | 49.1 % | 1706 |
| Kilnstork | 2 | 49.1 % | 1686 |
| Canalord | 2 | 49.0 % | 1534 |
| Stiltregent | 2 | 48.9 % | 1630 |
| Glowflitter | 2 | 48.7 % | 1750 |
| Sirocat | 2 | 48.6 % | 1600 |
| Glazelisk | 2 | 48.5 % | 1582 |
| Marshfife | 2 | 48.5 % | 1632 |
| Velvessa | 2 | 48.5 % | 1518 |
| Stamphorn | 2 | 48.4 % | 1534 |
| Saltspire | 2 | 48.3 % | 1564 |
| Ardlume | 2 | 48.3 % | 1646 |
| Wickmoth | 2 | 48.3 % | 1576 |
| Lanternel | 2 | 48.2 % | 1570 |
| Lumenewt | 2 | 48.2 % | 1558 |
| Veskara | 2 | 48.1 % | 1576 |
| Lodebrock | 2 | 47.7 % | 1666 |
| Sootlurk | 2 | 47.7 % | 1604 |
| Ergskim | 2 | 47.7 % | 1684 |
| Floursprite | 2 | 47.7 % | 1592 |
| Flickscale | 2 | 47.4 % | 1620 |
| Coalbuck | 2 | 47.4 % | 1560 |
| Ripjolter | 2 | 47.3 % | 1522 |
| Obelith | 2 | 47.3 % | 1506 |
| Hearthmote | 2 | 47.1 % | 1610 |
| Grindwheel | 2 | 47.1 % | 1566 |
| Bakedillon | 2 | 47.0 % | 1566 |
| Fernwhisk | 2 | 46.9 % | 1502 |
| Forgeflare | 2 | 46.9 % | 1558 |
| Fiddlehorn | 2 | 46.8 % | 1590 |
| Platewing | 2 | 46.5 % | 1706 |
| Palmonarch | 2 | 46.5 % | 1608 |
| Burrowgraver | 2 | 46.4 % | 1578 |
| Corrodile | 2 | 46.3 % | 1622 |
| Mendlace | 2 | 46.2 % | 1620 |
| Copperclad | 2 | 45.9 % | 1594 |
| Vitriolus | 2 | 45.7 % | 1672 |
| Ingotusk | 2 | 45.5 % | 1646 |
| Peallith | 2 | 45.5 % | 1640 |
| Cogwright | 2 | 45.5 % | 1564 |
| Rollibex | 2 | 45.2 % | 1620 |
| Mordantoad | 2 | 45.2 % | 1618 |
| Wadishell | 2 | 45.2 % | 1594 |
| Fenwarden | 2 | 45.1 % | 1666 |
| Fulgorin | 2 | 45.1 % | 1566 |
| Vitrillon | 2 | 44.9 % | 1644 |
| Brickwarden | 2 | 44.8 % | 1594 |
| Belfrit | 2 | 44.7 % | 1564 |
| Claspirant | 2 | 44.6 % | 1612 |
| Smeltmaw | 2 | 44.5 % | 1522 |
| Chimewell | 2 | 44.4 % | 1634 |
| Siltgrove | 2 | 44.0 % | 1590 |
| Caravant | 2 | 43.9 % | 1638 |
| Glassfell | 2 | 43.6 % | 1596 |
| Frondmere | 2 | 43.5 % | 1578 |
| Cullhorn | 2 | 42.4 % | 1548 |
| Gyrevult | 2 | 42.3 % | 1634 |
| Talusgard | 2 | 42.2 % | 1654 |
| Thornback | 2 | 42.0 % | 1558 |
| Smoldrake | 2 | 41.8 % | 1494 |
| Duskdigger | 2 | 41.8 % | 1518 |
| Riptail | 2 | 41.6 % | 1574 |
| Leviarch | 3 | 57.8 % | 3476 |
| Vanecrest | 3 | 57.1 % | 3630 |
| Ripjoltane | 3 | 55.2 % | 3678 |
| Rubriclad | 3 | 55.1 % | 3480 |
| Sleetsage | 3 | 55.1 % | 3640 |
| Vatbaron | 3 | 54.9 % | 3648 |
| Siltaroth | 3 | 54.8 % | 3532 |
| Glazeldrake | 3 | 54.7 % | 3562 |
| Hoarmonarch | 3 | 54.7 % | 3550 |
| Filigravure | 3 | 54.6 % | 3462 |
| Smudgewyrm | 3 | 54.4 % | 3394 |
| Nibravure | 3 | 54.0 % | 3580 |
| Pinchcastle | 3 | 53.7 % | 3552 |
| Cindravax | 3 | 53.7 % | 3446 |
| Fumeregent | 3 | 53.4 % | 3454 |
| Rimesovereign | 3 | 53.3 % | 3544 |
| Quilmothane | 3 | 53.3 % | 3478 |
| Woadcastle | 3 | 53.1 % | 3658 |
| Gelidmonarch | 3 | 52.9 % | 3450 |
| Lodemarshal | 3 | 52.7 % | 3652 |
| Nimbarch | 3 | 52.7 % | 3584 |
| Inkregent | 3 | 52.3 % | 3344 |
| Rushstalker | 3 | 52.3 % | 3598 |
| Fulgorath | 3 | 52.1 % | 3664 |
| Veskarion | 3 | 51.8 % | 3614 |
| Grindmonolith | 3 | 51.4 % | 3520 |
| Stampcolossus | 3 | 51.3 % | 3502 |
| Fiddlestag | 3 | 51.3 % | 3586 |
| Sootharrow | 3 | 51.3 % | 3424 |
| Glowflare | 3 | 51.2 % | 3718 |
| Siroclaw | 3 | 51.2 % | 3448 |
| Dipmonarch | 3 | 50.9 % | 3562 |
| Weirmarshal | 3 | 50.9 % | 3494 |
| Gleamwyrm | 3 | 50.2 % | 3532 |
| Ardenthal | 3 | 50.0 % | 3446 |
| Morelord | 3 | 49.7 % | 3546 |
| Noonsoral | 3 | 49.4 % | 3566 |
| Scaldrahn | 3 | 49.4 % | 3598 |
| Habobrax | 3 | 49.3 % | 3452 |
| Corrodrake | 3 | 49.0 % | 3322 |
| Clinkerdome | 3 | 49.0 % | 3548 |
| Caravault | 3 | 48.9 % | 3380 |
| Skerrimast | 3 | 48.9 % | 3518 |
| Platemarshal | 3 | 48.7 % | 3508 |
| Wadibastion | 3 | 48.6 % | 3424 |
| Spinnacle | 3 | 48.4 % | 3378 |
| Quenchwyrm | 3 | 48.2 % | 3522 |
| Stylaxon | 3 | 48.1 % | 3522 |
| Helirollax | 3 | 47.9 % | 3548 |
| Peatmonarch | 3 | 47.7 % | 3540 |
| Obelordan | 3 | 47.5 % | 3514 |
| Chimeward | 3 | 47.4 % | 3466 |
| Sluicewarden | 3 | 47.4 % | 3512 |
| Copperpatriarch | 3 | 47.3 % | 3470 |
| Mordantyrant | 3 | 46.2 % | 3670 |
| Velverain | 3 | 46.0 % | 3564 |
| Verdantusk | 3 | 46.0 % | 3660 |
| Gloomgillith | 3 | 45.9 % | 3620 |
| Brickolossus | 3 | 45.8 % | 3516 |
| Claspreign | 3 | 45.2 % | 3486 |
| Coalpatriarch | 3 | 45.0 % | 3598 |
| Cairnhold | 3 | 44.3 % | 3504 |
| Ergrava | 3 | 43.4 % | 3618 |
| Flickwyrm | 3 | 43.1 % | 3546 |
| Vitrillaxe | 3 | 43.1 % | 3428 |
| Calderox | 3 | 42.1 % | 3538 |
| Sablarch | 3 | 42.1 % | 3538 |
| Burringrand | 3 | 41.2 % | 3478 |

Chart problems: none
Outside the band: none

Chart sim (equal stats, one art of the own element, seed 352): 40 duels per pair, every team of 3 against every team it shares no element with, 4 lead orders, sides swapped. Element band 40 to 60 %, team band 30 to 70 %.

| Element | Era I 1 on 1 | Era I teams | All eras 1 on 1 | All eras teams |
| --- | --- | --- | --- | --- |
| Ember | 50.2 % | 51.3 % | 49.5 % | 49.7 % |
| Tide | 47.5 % | 50.5 % | 51.1 % | 50.4 % |
| Bloom | 49.5 % | 51.3 % | 49.5 % | 50.4 % |
| Volt | 50.6 % | 50.3 % | 52.5 % | 49.9 % |
| Stone | 50.0 % | 50.7 % | 49.4 % | 50.0 % |
| Gale | 49.1 % | 49.1 % | 49.1 % | 49.7 % |
| Lumen | 50.5 % | 49.9 % | 50.9 % | 49.5 % |
| Umbra | 52.7 % | 46.9 % | 49.7 % | 49.8 % |
| Ink | - | - | 50.1 % | 50.7 % |
| Echo | - | - | 49.4 % | 49.5 % |
| Rust | - | - | 50.7 % | 50.3 % |
| Mask | - | - | 47.8 % | 50.6 % |
| Acid | - | - | 50.5 % | 50.6 % |
| Frost | - | - | 50.5 % | 50.0 % |
| Gilt | - | - | 48.7 % | 49.7 % |
| Zenith | - | - | 50.7 % | 49.3 % |

Era I: 56 teams, lowest Ember/Volt/Lumen 33.8 %, highest Ember/Volt/Stone 68.8 %.
All eras: 560 teams, lowest Bloom/Gale/Frost 37.4 %, highest Ink/Echo/Mask 62.4 %.

Chart sim outside the band: none
<!-- /type_sim report -->

## Known gaps

Bands that `tests/slow/test_slow_sim_bands.gd` measures but the game misses today (plan area 2,
items 854 to 856). The test lists them in `KNOWN_GAPS`, prints them and fails on every other
miss; take a key out of both places once it is fixed.

| Key | Measured (ring 36, seed 1234) | Target | Why it stays open |
| --- | --- | --- | --- |
| `ladder:2` | AI tier 2 beats tier 1 in 56 % | at least 60 % | needs a better tier 2 lookahead, an AI task of its own |
| `ladder:3` | tier 3 beats tier 2 in about 55 %, just under | at least 55 % | same |
| `mono:Volt` | 24 % | 42 to 58 % | only 3 Volt species stand at ring 36; a roster question (area 1) |
| `mono:Gale` | 60 % | 42 to 58 % | 11 species, wide pool |
| `mono:Umbra` | 60 % | 42 to 58 % | just over the band |
| `field:static_veil` | +16.5 | +8 to +15 | see below |
| `field:deep_murk` | +7.5 | +8 to +15 | see below |
| `field:dawn_glow` | +6.5 | +8 to +15 | see below |
| `field:ash_storm` | +5.5 | +8 to +15 | see below |

Fields (item 854): a per-field boost puts all six in the band at ring 36 (tried 7 Nov 2026:
Ash Storm 1.65, High Tide 1.4, Deep Murk and Dawn Glow 1.45, Static Veil 1.1 with weaken 0.9:
every field +9 to +14). But Wardens, the Trials and the bonus goals are tuned on today's fields:
that change dropped Orrin on Veteran from the 45 to 80 % band to 22 %, Maelis on Tamer to 47 %,
the drowned_heart goal to 10 % and left current_trial_2 without a solution. A field retune has
to come together with those, so the fields stay at 1.2 / 0.85 for now.

## Changes from the first run (Nov 2026)

| What | Before | After | Why |
| --- | --- | --- | --- |
| Verdantusk elements | Bloom/Stone | Bloom/Umbra | Stone made it neutral to Ember, so the starter triangle broke: Verdantusk won 96–100% of final-stage fights, Calderox 0–4%. |
| Verdantusk Lv48 move | Cairn Crash | Dusk Gnaw | Matches the new Umbra half. |
| Kindlop | HP 58, DEF 48, FOC 70, SPD 58 | HP 62, DEF 54, FOC 72, SPD 70 | Won 27–32% at every level; two of five base-form rivals hit it ×2. |
| Smoldrake | DEF 64, SPD 82 | DEF 70, SPD 94 | 29–43% within stage 2. |
| Glimmerax | FOC 104, SPD 130 | FOC 100, SPD 120 | 69% at Lv20, outsped everything. |

Result: every species sits between 35% and 65% at Lv8/20/28/36/50; Zephlet is at 33% at Lv14 (borderline, left as is).

## Six new Spirlings (content block)

Wickit/Lumenewt (Lumen, Lumen/Tide), Mirkmole/Duskdigger (Umbra, Umbra/Stone) and
Kelpup/Kelphound (Tide/Bloom) joined the pool. First runs had Mirkmole at 31% (Lv20) and
Duskdigger at 34% (Lv36), so both got more HP, ATK and SPD before merging.
With the larger stage-2 pool at Lv36, Thornback (74%) and Smoldrake (26%) moved toward the
edges of the guard band. Both normally evolve at Lv34, so this is a pool of forms the player
rarely still has at Lv36. Revisit if a later change pushes either past the band.

## Battle depth (traits, stat stages, Overcharge)

Traits, stat moves and Overcharge shifted the numbers. The sim now also skips forms that would
already have evolved, which removed the odd "Smoldrake at Lv36" comparisons. Wickit lost a little
FOC/SPD and Kelpup gained HP/SPD. The Lv36 guard band holds; at single levels in between
(Lv10–28) a few forms still swing between 25% and 75% because learnsets unlock at different
levels. That is expected noise with 10 rounds per pair and worth a look when learnsets grow.

## Element rules (KAMPF_PLAN_1000)

- No hit ever does nothing: there is no x0 matchup. The floor is x0.25 (both elements of a dual
  defender resist). `test_kampf_techniques.gd` checks every element against every pair.
- The element chart is Chimora's own and is never copied from another game; new elements follow
  the era rule in `data/type_chart.json` (one strength and one weakness per touched element).
- Battle-side element rules live in `scripts/battle/TechniqueRules.gd`: Resonance (x1.05 while an
  ally on the field shares an element), echo (+1 Energy when an ally used the same element earlier
  in the turn; Energy, not damage, so same-element teams still leave room for combos), the Ward Shell keepsake, the gifts Prism Skin and Countercurrent, Ward Circle and
  Dye Bath. The 19 arts of the plan's "Techniken" area are taught by Echo Crystals that Hesper
  sells in the lighthouse.
- Coiled Strike (charge, power 50 to stay on the art curve) does nothing on its first use and hits x2 on the next, so per turn it is
  a plain art of its power with a visible tell. Night Prowl and Noon Glare hit x1.5 at their own
  time of day outdoors and are plain arts indoors.
- Art balance check (item 155): every art Hesper teaches goes into the first slot of a lead of its
  element, and the same battles are played with and without it. Band -10 to +8 points. Rerun with
  `godot --headless --path . -s res://tools/balance_sim.gd -- --mode arts --level 36 --rounds 120`
  (time-of-day arts fight at their own time). Run of the current set, ring 36, 120 battle pairs:

| Art | With | Without | Gain | Flag |
| --- | --- | --- | --- | --- |
| Hold Fast | 42% | 43% | -1.7 |  |
| Shove Off | 42% | 41% | +0.8 |  |
| Grudge Return | 51% | 50% | +0.8 |  |
| Kindred Balm | 43% | 46% | -2.5 |  |
| Rank and File | 39% | 40% | -0.8 |  |
| Shake Loose | 48% | 47% | +0.4 |  |
| Rolling Drum | 33% | 31% | +1.7 |  |
| Late Reply | 51% | 53% | -1.7 |  |
| Opening Gambit | 48% | 46% | +1.7 |  |
| Pebble Hail | 41% | 40% | +0.8 |  |
| Rift Hush | 48% | 43% | +5.8 |  |
| Bright Lure | 51% | 53% | -2.5 |  |
| Close Ranks | 49% | 46% | +3.3 |  |
| Ember Afterglow | 47% | 44% | +3.3 |  |
| Borrowed Stance | 51% | 52% | -0.8 |  |
| Still Point | 48% | 48% | +0.0 |  |
| Ground Burst | 41% | 38% | +2.5 |  |
| Dye Bath | 49% | 49% | +0.0 |  |
| Ward Circle | 47% | 46% | +0.8 |  |
| Magma Rush | 51% | 50% | +0.8 |  |
| Tidal Gust | 50% | 50% | +0.0 |  |
| Clean Slate | 46% | 46% | +0.0 |  |
| Coiled Strike | 41% | 43% | -1.7 |  |
| Night Prowl | 43% | 41% | +2.5 |  |
| Noon Glare | 48% | 49% | -0.8 |  |

## Open observations

- 1-on-1 fights last 2–3 turns (about 2–3 hits to faint). That is brisk but fine for mobile;
  if fights should feel longer, lower `DamageCalc.SCALE_DIV` slightly rather than touching HP.
- At Lv36, a dozen moves are never picked by the greedy AI; most are status moves or late
  learnset moves. Worth a look when the move list grows.

## Neue Technik hinzufügen (adding a new art)

1. Data: add the art to `data/moves.json`. Every new key also goes into `DataValidator.MOVE_KEYS`.
   Then run `godot --headless --path . -s res://tools/validate_data.gd`.
2. Curve: `test_move_curve.gd` checks power x accuracy / (energy + 1) x effect factor (9 to 18),
   accuracy (at least 75 %), status chance and the cooldown rule. If the art is new to plan area 2,
   add it to `BalanceSim.NEW_ARTS`.
3. Learnset: at most 14 arts per species, and the art must fit the species' role. Check that a
   default kit (the newest four) still carries two hits.
4. Simulator: run `--mode team --level 36 --compare`. The art should not move any species by more
   than 8 points, and the team report must not list it as rarely chosen (under 1 % of its element).
   Run `--mode mirror` if it changes turn order or end-of-turn effects.
5. Baseline: if the shift is intended, write a new baseline in the same commit
   (`--mode team --level 36 --rounds 3000 --json tools/balance/baseline_lv36.json`); the nightly
   `test_slow_baseline.gd` fails until you do.
6. Name: our own words, no name from another game, nothing thrown, flying, gliding or ridden.
   `tools/ip_check.sh` and `test_rule_checks.gd` check the banned terms.
7. Run `tools/balance/run_all.sh` so the generated parts of this file are up to date.

## Schwierigkeitsstufen (difficulty levels)

Generated from `GameState`, `BattleRules` and `TrainerData` (item 875).

<!-- gen:difficulty -->
| Difficulty | Foe ring | Foe Spark | AI Wayfarer / Warden | Keepsakes | Foe start Energy | Foe damage | Warden rules | Boss actions | Rift-Born extra |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Story | -1 | 0 | 0 / 1 | dropped | 8 | x0.90 | up to 1 | at most 1 | - |
| Tamer | +0 | 3 | 1 / 2 | dropped | 10 | x1.00 | up to 1 | as the boss data says | - |
| Veteran | +1 | 6 | 2 / 2 | kept | 10 | x1.00 | up to 2 | as the boss data says | - |
| Rift-Born | +2 | 10 | 3 / 3 | kept | 10 (+1 after turn 1) | x1.00 | up to 2 | as the boss data says, +1 in phase 2 | +1 copy of the lowest entry (team of up to 5) |

Foe ring: the shift of a shared Wayfarer team (teams with their own block for the difficulty keep their rings), never more than 2 above the ring cap.
<!-- /gen:difficulty -->

## Wachstum (growth curve)

Generated from `Spirling.xp_for_level`, `BattleModel` and `data/growth_rules.json`
(docs/KAMPF_PLAN_1000.md, "XP-Kurve dokumentieren"). `test_kampf_growth_wild.gd` checks the
balance goal: between two Warden ring caps no Spirling needs more than `no_grind_battles` even
wild battles.

<!-- gen:growth -->
| Ring | Growth to reach it | To the next ring | Even wild battles to the next ring (normal) | Story |
| --- | --- | --- | --- | --- |
| 5 | 78 | 48 | 3 | 2 |
| 10 | 477 | 135 | 4 | 3 |
| 15 | 1370 | 251 | 5 | 4 |
| 20 | 2896 | 392 | 5 | 4 |
| 30 | 8311 | 740 | 7 | 5 |
| 40 | 17560 | 1164 | 8 | 6 |
| 50 | 31369 | 1657 | 9 | 7 |
| 60 | 50393 | 2213 | 10 | 8 |
| 80 | 106467 | 3494 | 11 | 9 |
| 100 | 190187 | 4984 | 13 | 10 |

Growth to reach ring L = floor(1.2 x L ^ 2.6). There is no top ring. One battle gives yield x foe ring / 20 (x1.5 against a Wayfarer), shared by the Spirlings that fought; the bench gets 50 % with Bench lessons. Table for a kind of yield 80.
Factors: Story x1.25, rematch x1.2, kinship 80+ x1.1, Growth Charm x1.5, world goal x1.25 for 20 battles. No penalty for a higher ring than the foe (only Era V scales by ring).
<!-- /gen:growth -->

## KI-Profile (AI profiles)

Generated from `data/ai_profiles.json`, the mottos in `data/dialogue/battle_lines.json` and the
`profile` keys in `data/maps` (item 876). The weights scale parts of `BattleAI.score_move`. The
other keys are explained in the `_doc` of the profile file.

<!-- gen:profiles -->
| Profile | damage_w | status_w | setup_w | field_w | swap_below | heal_below | rest_below | focus_fire | status_first | setup_stats | field_renew | plan_energy | second_best | drain_w | Motto | Used by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| balanced | 1 | 1 | 1 | 1 | default | 0.3 | -1 | 0 | 0 |  |  |  |  |  |  | - |
| hothead | 1.4 | 0.4 | 0.3 | 1 | never | 0.3 | 1 | 0 | 0 |  |  |  |  |  | Never backs down, never swaps. | cinder_rift:acolyte_a, cinder_rift:warden_orrin, crowcrest:lio |
| wall | 0.8 | 1 | 1.5 | 1 | 0.5 | 0.45 | -1 | 0 | 0 | def, foc |  |  |  |  | Builds up guard and waits. | crowcrest:bram, fernstair:joss |
| spoiler | 1 | 1.6 | 1 | 1 | default | 0.3 | -1 | 0 | 1 |  |  |  |  |  | Spoils your plans before striking. | murk_hollow:delve, saltmarsh:aud |
| field_keeper | 1 | 1 | 1 | 2 | default | 0.3 | -1 | 0 | 0 |  | 1 |  |  |  | Shapes the Rift field first. | murk_hollow:fenn, saltmarsh:neve |
| tactician | 1 | 1 | 1 | 1 | 0.7 | 0.3 | -1 | 1 | 0 |  |  | 1 |  |  | Plans every turn ahead. | crowcrest:kestra, saltmarsh:Cartographer Kestra, tide_rift:mystic, tide_rift:warden_maelis |
| apprentice | 1 | 1 | 1 | 1 | default | 0.3 | -1 | 0 | 0 |  |  |  | 0.3 |  | Still learning, sometimes guesses. | cinder_rift:acolyte_b, fernstair:imme |
| enduring | 1 | 1 | 1 | 1 | default | 0.6 | 4 | 0 | 0 |  |  |  |  | 1.5 | Rests, mends and outlasts you. | saltmarsh:kestra_tag |
<!-- /gen:profiles -->

## Wächter-Rätsel schreiben (writing Warden Trials)

Trials live in `data/puzzles.json` and are played by `BattlePuzzle` (item 877).

- **Format:** `id`, `warden`, `name`, `text`, `player` and `foe` (Spirlings with `species`,
  `level` and four `moves`), and optionally `partner` and `front`. Then `field`, `rule` (a Warden
  rule), `seed` and `ai` (the foe tier, fixed on every difficulty), and finally `goal`,
  `max_turns`, `best_turns`, `hint_1` and `hint_2`. A fixed seed and a fixed AI make every line
  of play end the same way.
- **Goals:** one `{"type", "value"}` or a list of up to `BattlePuzzle.MAX_GOALS`. Each goal
  also needs the win. The types are `win_within N`, `no_faint`, `exact_rests N`,
  `keep_status S`, `use_reaction E` and `last_hit_with A`.
- **Solver test:** `test_puzzles.gd` searches every line with `BattlePuzzle.search`. A Trial
  must be solvable, but at most 20 % of the lines may win, so it can't be won by chance. It must
  not fall to resting only or to always using the first affordable art. `best_turns` must be
  the fewest turns the solver finds.
- **Hints:** `hint_1` shows after 2 misses, `hint_2` after 4. The first names the idea, the
  second the line. Both are our own wording and go into the German texts.
- **Lanterns:** 0 for a loss, 1 for a win, 2 when the goal is met, 3 when it is met within
  `best_turns`. The first 3-lantern clear pays the reward once.

## Regelvarianten (rule variants)

Generated from `data/rule_variants.json` (item 878).

<!-- gen:variants -->
| Variant | Label | Numbers | Can't go with | Seal | Text |
| --- | --- | --- | --- | --- | --- |
| `damp_sparks` | Damp Sparks | soak_drain 2 (normal 0) | - | drop | A Soaked Spirling loses 2 Energy at the end of each turn. |
| `field_swirl` | Field Swirl | field_swirl_every 3 (normal 0) | - | swirl | Every 3 turns a random field takes over, announced a turn early. |
| `full_charge` | Full Charge | energy_per_turn 0 (normal 1), rest_energy 3 (normal 2), start_energy 10 (normal 10) | no_rest, spark_poor | full | Everyone starts full, gains no Energy per turn, and resting gives 3. |
| `glass_blades` | Glass Blades | hp_mult 0.5 (normal 1) | tough_round | glass | Every Spirling has half its Vigor. |
| `late_end` | Late End | chip_from_turn 15 (normal 0) | - | hourglass | From turn 15, every Spirling in front loses 1/8 of its Vigor each turn. |
| `no_home_edge` | No Home Edge | stab 1 (normal 1.25) | - | ring | Arts of a Spirling's own element get no bonus. |
| `no_rest` | No Rest | energy_per_turn 3 (normal 1), rest_energy 0 (normal 2), rest_only_as_pass 1 (normal 0) | full_charge | wedge | Resting is gone while an art can be paid; instead everyone gains 3 Energy each turn. |
| `short_breath` | Short Breath | status_max_turns 2 (normal 0) | - | bars | Every status ends after 2 turns at most. |
| `spark_poor` | Spark Poor | max_energy 6 (normal 10), start_energy 6 (normal 10) | full_charge | spark | Energy tops out at 6, and everyone starts with 6. |
| `stage_still` | Stage Still | stages_locked 1 (normal 0) | - | line | No stage changes at all; arts that only change stages are locked. |
| `strong_reactions` | Strong Reactions | reaction_scale 2 (normal 1) | - | cross | Element reactions hit twice as hard beyond the normal. |
| `swap_toll` | Swap Toll | swap_energy_cost 2 (normal 0) | - | toll | Every chosen swap costs the incoming Spirling 2 Energy. |
| `tough_round` | Tough Round | hp_mult 1.5 (normal 1) | glass_blades | block | Every Spirling has one and a half times its Vigor. |

At most 3 variants at once; a Rift Tower floor draws 1 from floor 6 and 2 in the third section.
<!-- /gen:variants -->

## Änderungsprotokoll (change log of existing arts)

The retuned older arts of plan area 2 (items 581-608), with KO per use in the ring 36 duel run
before the change and now (item 879).

<!-- gen:changes -->
| What | Before | After | Why | KO per use before | KO per use now |
| --- | --- | --- | --- | --- | --- |
| Lichen Lash | Power 40 | Power 35 | Too many KOs for 2 Energy | 0.94 | 0.79 |
| Crackle Bite | Jolt 10 % | Jolt 5 % | Too many KOs per use | 0.80 | 0.33 |
| Overcharge | No cap, 0.15 per Energy | At most +5 Energy, 0.12 per Energy | Ended every duel it was used in | 1.00 | - |
| Storm Gnash | Power 75, accuracy 90 % | Power 80, accuracy 95 % | Hardly ever won a fight | 0.07 | 0.38 |
| Gale Scythe | Power 80, Energy 5 | Power 85, Energy 4 | Hardly ever won a fight | 0.08 | 0.23 |
| Arc Bolt | Jolt 20 % | Jolt 30 % | Hardly ever won a fight | 0.04 | 0.36 |
| All-In Crash | Base power 30 | Base power 40 | A real Stone pick next to Overcharge | 0.05 | 0.17 |
| Cairn Crash | Power 100, accuracy 80 % | Power 105, accuracy 85 % | Never picked at ring 36 | - | 0.63 |
| Furnace Spiral | Accuracy 85 % | Accuracy 90 % | Never picked at ring 36 | - | - |
| Hush | Accuracy 75 %, Energy 4 | Accuracy 80 %, Energy 3 | Only picked under the rest rule | - | - |
| Bloom Burst | Power 90 | Power 95 | Never picked at ring 36 | - | 0.46 |
| Breaker Plunge | Accuracy 85 %, recoil 25 % | Accuracy 90 %, recoil 20 % | Too costly for its user | - | 0.14 |
| Radiant Lance | Power 85 | Power 90 | Behind Prism Ray at the same cost | - | 0.32 |
| Kiln Strike | Accuracy 90 % | Accuracy 95 % | Missed too often for its cost | - | 0.14 |
| Salt Snap | Soak 10 % | Soak 20 % | Never picked at ring 36 | - | 0.26 |
| Pebble Toss | Accuracy 95 % | Accuracy 100 % | Cheapest Stone hit, should be sure | - | 0.73 |
| Bowl Over | Power 35 | Power 30 | Stays the cheapest Stone hit at 1 Energy | - | - |
| Tunnel Strike | No side effect | 20 % own guard +1 | A reason to pick it | - | 0.15 |
| Night Siphon | Power 50 | Power 60 | Drain too small to matter | - | 0.45 |
| Dusk Rake | No side effect | 20 % foe power -1 | A reason to pick it | - | - |
| Thorn Volley | Power 65, Energy 4 | Power 75, Energy 5 | A sweep worth taking next to Sap Draw | - | 0.10 |
| Charged Mist | Accuracy 85 % | Accuracy 80 % | Jolt on every foe was too sure in group battles | - | 0.00 |
| Candle Ward | Energy 3 | Energy 2 | Never picked at ring 36 | - | 0.04 |
| Dawn Mend | Energy 5 | Energy 6 | Fitted every second turn | - | 0.00 |
| Heat Haze, Murk Veil, Silt Cloud | Mixed accuracy and cost | Accuracy 90 %, Energy 3 | Same Daze arts, same price | - | - |
| Kindle Up, Hunker Down, Drift Step, Still Thought | 1 stage | 2 stages at full Vigor | Setup arts were never worth a turn | - | - |
| Cower Shade | Accuracy 95 % | Accuracy 100 % | A status art should land | - | - |
| Chill Mist | One foe, Energy 2 | Every foe, Energy 3 | A sweep for Tide support | - | - |

"Now" is the duel run at ring 36 (10 duels per pair, seed 1234); "-" means the art was not picked there.
<!-- /gen:changes -->

## Referenzteams (reference teams)

`tools/balance/ref_teams.json` holds three teams per story section, one per starter (Kindlop,
Zippit or Wickit in the lead) (item 880). Each team is built from the wild kinds of the maps a
player walks before that Warden, and its rings sit at the cap or 1 to 2 below it, as with a player
who catches what they meet and doesn't grind. `post_rifts` fights the rematch teams after both
Rifts. The Warden simulator (`--mode warden`) measures every Warden on every difficulty against
these teams and checks the bands in `tools/balance/targets.json`.

<!-- gen:ref_teams -->
| Section | Ring cap | Against | Team | Spirlings (ring) |
| --- | --- | --- | --- | --- |
| pre_orrin | 12 | warden_orrin | ember_start | Kindlop 12, Shalebat 11, Puddlet 11, Mirkmole 10 |
| pre_orrin | 12 | warden_orrin | spark_start | Zippit 12, Puddlet 11, Shalebat 11, Zephlet 10 |
| pre_orrin | 12 | warden_orrin | wick_start | Wickit 12, Puddlet 11, Talusk 11, Zephlet 10 |
| pre_maelis | 18 | warden_maelis | ember_start | Smoldrake 16, Shalebat 15, Puddlet 15, Mossling 14 |
| pre_maelis | 18 | warden_maelis | spark_start | Zippit 16, Kelpup 15, Zephlet 15, Mirkmole 15 |
| pre_maelis | 18 | warden_maelis | wick_start | Wickit 16, Mossling 15, Shalebat 15, Zephlet 15 |
| post_rifts | 23 | warden_orrin (rematch), warden_maelis (rematch) | ember_start | Smoldrake 21, Riptail 20, Thornback 20, Shalebat 20 |
| post_rifts | 23 | warden_orrin (rematch), warden_maelis (rematch) | spark_start | Zippit 21, Talusgard 20, Riptail 20, Zephlet 20 |
| post_rifts | 23 | warden_orrin (rematch), warden_maelis (rematch) | wick_start | Wickit 21, Riptail 20, Talusgard 20, Mirkmole 20 |
<!-- /gen:ref_teams -->

## Full report at Lv36

Rewritten by `tools/balance/run_all.sh` after every balance change, never by hand (item 881).

<!-- gen:report_lv36 -->
Level 36, 12660 battles (1-on-1 within the same evolution stage, both sides AI tier 1, no items), 0 draws, 3.0 turns on average.
Generated by `tools/balance_sim.gd`; numbers are reproducible for the same seed.
Double KOs (both sides out at once, counted as draws for the species): 26.

Turns to KO: 3.0.
First-mover advantage (the faster Spirling wins): 53%.

### Species

| Species | Stage | Win rate | W | L | D | Flag |
| --- | --- | --- | --- | --- | --- | --- |
| Scrivane | 2 | 73% | 508 | 192 | 0 | too strong |
| Burinox | 2 | 67% | 466 | 234 | 0 | too strong |
| Fenwarden | 2 | 66% | 462 | 236 | 2 | too strong |
| Rainmantle | 2 | 65% | 454 | 246 | 0 |  |
| Ferrowyn | 2 | 62% | 434 | 266 | 0 |  |
| Obsidroth | 2 | 59% | 416 | 283 | 1 |  |
| Zenithare | 2 | 59% | 412 | 288 | 0 |  |
| Silentra | 2 | 58% | 408 | 292 | 0 |  |
| Frondmere | 2 | 57% | 397 | 303 | 0 |  |
| Saltcrown | 2 | 56% | 391 | 309 | 0 |  |
| Mirassil | 2 | 55% | 388 | 312 | 0 |  |
| Millvane | 2 | 55% | 385 | 315 | 0 |  |
| Kelphound | 2 | 54% | 381 | 316 | 3 |  |
| Reedwarden | 2 | 53% | 373 | 327 | 0 |  |
| Delthorn | 2 | 52% | 367 | 330 | 3 |  |
| Mendlace | 2 | 52% | 364 | 334 | 2 |  |
| Ashcrest | 2 | 52% | 363 | 336 | 1 |  |
| Glasstarn | 2 | 51% | 358 | 329 | 13 |  |
| Tempestrel | 2 | 51% | 357 | 343 | 0 |  |
| Solmantle | 2 | 51% | 354 | 346 | 0 |  |
| Floursprite | 2 | 50% | 348 | 352 | 0 |  |
| Lanternel | 2 | 49% | 343 | 357 | 0 |  |
| Dunebastion | 2 | 48% | 335 | 364 | 1 |  |
| Orrerine | 2 | 48% | 334 | 366 | 0 |  |
| Wickmoth | 2 | 45% | 318 | 382 | 0 |  |
| Marshfife | 2 | 45% | 313 | 383 | 4 |  |
| Glimmerax | 2 | 42% | 294 | 406 | 0 |  |
| Saltspire | 2 | 41% | 290 | 410 | 0 |  |
| Siltgrove | 2 | 40% | 277 | 423 | 0 |  |
| Duskdigger | 2 | 38% | 267 | 433 | 0 |  |
| Lumenewt | 2 | 37% | 259 | 420 | 21 |  |
| Talusgard | 2 | 36% | 255 | 445 | 0 |  |
| Cullhorn | 2 | 34% | 238 | 462 | 0 | too weak |
| Cogwright | 2 | 33% | 234 | 465 | 1 | too weak |
| Smeltmaw | 2 | 32% | 222 | 478 | 0 | too weak |
| Glassfell | 2 | 30% | 209 | 491 | 0 | too weak |
| Calderox | 3 | 50% | 20 | 20 | 0 |  |
| Leviarch | 3 | 50% | 20 | 20 | 0 |  |
| Verdantusk | 3 | 50% | 20 | 20 | 0 |  |

### Moves

| Move | Used | KOs | KO per use |
| --- | --- | --- | --- |
| Gale Scythe | 5241 | 1191 | 0.23 |
| Spindrift Shot | 4829 | 1148 | 0.24 |
| Prism Ray | 3951 | 569 | 0.14 |
| Tunnel Strike | 3926 | 607 | 0.15 |
| Gloom Ripple | 3695 | 653 | 0.18 |
| Tremor Thud | 2532 | 127 | 0.05 |
| Breeze Slice | 2185 | 687 | 0.31 |
| Wick Flicker | 1868 | 398 | 0.21 |
| Night Siphon | 1751 | 795 | 0.45 |
| Thorn Volley | 1697 | 171 | 0.10 |
| Undertow | 1439 | 354 | 0.25 |
| Cinder Nip | 1402 | 400 | 0.29 |
| Crackle Bite | 1384 | 453 | 0.33 |
| Salt Snap | 1291 | 339 | 0.26 |
| Sap Draw | 1290 | 451 | 0.35 |
| Omen Bell | 1185 | 152 | 0.13 |
| Kiln Strike | 1058 | 153 | 0.14 |
| Squall Line | 1038 | 234 | 0.23 |
| Spark Call | 889 | 0 | 0.00 |
| Candle Ward | 838 | 32 | 0.04 |
| Hunker Down | 837 | 0 | 0.00 |
| Murmur Bite | 832 | 241 | 0.29 |
| Shade Pounce | 812 | 141 | 0.17 |
| Dusk Gnaw | 795 | 260 | 0.33 |
| Mirk Nip | 767 | 125 | 0.16 |
| Murk Call | 746 | 0 | 0.00 |
| Squall | 745 | 128 | 0.17 |
| Drift Step | 665 | 0 | 0.00 |
| Prism Burst | 589 | 157 | 0.27 |
| Breaker Plunge | 580 | 80 | 0.14 |
| Murk Veil | 573 | 0 | 0.00 |
| Kelp Lash | 564 | 309 | 0.55 |
| Pebble Toss | 527 | 383 | 0.73 |
| Fizz Pop | 519 | 172 | 0.33 |
| Monolith Drop | 510 | 6 | 0.01 |
| Bloom Burst | 505 | 234 | 0.46 |
| Puffcap Haze | 494 | 27 | 0.05 |
| Glint | 455 | 194 | 0.43 |
| Grit Jab | 448 | 74 | 0.17 |
| Fault Line | 402 | 129 | 0.32 |
| Bloom Call | 398 | 10 | 0.03 |
| Dawn Mend | 395 | 0 | 0.00 |
| Landslip | 388 | 54 | 0.14 |
| Sunwell Sip | 386 | 72 | 0.19 |
| Cinder Breath | 370 | 123 | 0.33 |
| Drench | 363 | 0 | 0.00 |
| Heat Haze | 362 | 0 | 0.00 |
| Short Circuit | 346 | 137 | 0.40 |
| Updraft | 308 | 194 | 0.63 |
| Tide Call | 298 | 0 | 0.00 |
| Lichen Lash | 279 | 220 | 0.79 |
| All-In Crash | 273 | 47 | 0.17 |
| Arc Bolt | 234 | 85 | 0.36 |
| Storm Gnash | 221 | 85 | 0.38 |
| Charged Mist | 196 | 0 | 0.00 |
| Dawn Call | 159 | 0 | 0.00 |
| Cairn Crash | 97 | 61 | 0.63 |
| Radiant Lance | 76 | 24 | 0.32 |
| Still Thought | 56 | 0 | 0.00 |
| Root Mend | 41 | 0 | 0.00 |
| Quarry Wall | 20 | 0 | 0.00 |

Never picked at this level: Ash Call, Bark Burst, Beacon Ping, Bellows Blast, Boltglass Bite, Bore Wave, Bowl Over, Bramble Bed, Brazier Pulse, Capacitor Crash, Chaff Feint, Char Mark, Chill Mist, Cinder Dash, Cloudbreak, Coal Seed, Cower Shade, Crosswind, Dawn Needle, Daybreak Strike, Deepwell Draught, Downburst, Draft Needle, Dusk Rake, Dusk Snare, Duskglass Grip, Eclipse Crush, Fathom Crush, Floodglass Wave, Furnace Heart, Furnace Spiral, Gale Mantle, Gloam Pact, Gloom Handoff, Glow Knuckle, Glow Trap, Glowglass Slash, Graft, Gravel Hum, Grid Lock, Hush, Husk Shed, Kindle Up, Kite Cut, Lightglass Beam, Lull Breaker, Night Toll, Overcharge, Overdraw, Pollen Prick, Pumice Pelt, Pylon Snap, Rip Current, Rockglass Ram, Salt Spray, Scatter Gale, Seed Spit, Shard Bed, Shoal Trap, Siphon Spark, Slow Quake, Spout Jab, Starlit Lash, Static Tag, Stormglass Cut, Thornwake, Veil Step, Vineglass Sting, Wildgrowth Crash, Wire Trap.
<!-- /gen:report_lv36 -->

## Temperament, Iron Oath and rematches

- Every Spirling has a temperament (`Spirling.TEMPERAMENTS`) read from its uid, so it costs no RNG roll and old saves keep theirs. Five of the six give +5% to one stat (HP, ATK, DEF, FOC or SPD) with no penalty; "Even" gives nothing. It is a small lean, not a build choice, and it is shown in the team summary.
- The Iron Oath is an opt-in challenge picked at new game. A Spirling that faints moves to the Sanctuary after the battle. If the party empties, storage steps in; if storage is empty too, the oath ends and everyone comes back, so the game can never lock.
- Rematches: a beaten Wayfarer fights again once per calendar day. The team keeps its shape and is raised so its best Spirling matches the party's best level, never above the level cap and never below the first fight. Prize money is the level-based default.

## Waymarks (plan area 8)

Waymarks are the endgame currency. They are only earned by playing (`Waymarks.earn`, sources in
`Waymarks.SOURCES`), never bought, traded or gifted. The pouch holds at most 9999; what does not fit
is lost with a short note. A loss in battle never takes Waymarks away.

Target for an active player: **about 60 Waymarks a day and 500 a week** once the endgame is open;
a player who does everything every day (all four daily tasks, trips, every weekly source) gets about 780.

| Source | Amount | How often | Status |
| --- | --- | --- | --- |
| Daily task | 10 | 3 a day | built |
| Fourth, harder daily task (after Act I) | 25 | once a day | `DailyTasks.HARD_REWARD` |
| All daily tasks of the day | 10 extra | once a day | built |
| Weekly echo, first win of the week | 60 (30 of it from round 3 on) | once a week, in the first 3 tries | built |
| Weekly echo clear under the week's target score | 20 | once a week | `WeeklyChallenge.finish_run` |
| Lighthouse stair, new floor / every 10th floor | 5 / 50 | once per floor | built |
| Endless stretch above floor 30, every floor past the week's best | 2, at most 100 a week | weekly | `Gauntlet.pay_endless` (not in the 90-day plan) |
| Rift towers (Cinder Stair, Tide Shaft), first clear of each floor; top floor | 5 per floor, 50 for the top (once each) | once | `RiftTower.finish` (not in the 90-day plan) |
| Master Wayfarer | 80 first win, then 5 | once a week each (8 masters) | `Masters.win` |
| Master round in the lighthouse, all eight in a row | 100, first full clear only | once | `Masters.finish_round` |
| Vows kept to the end of Act I (No Shopping, No Keepsakes, Old Friend Stays) | 100 each | once per run | `Vows.settle` |
| Achievements (88) | 10 / 25 / 50 / 100 | once each | built |
| Festival goal (5 stages: 10/25/50/100/200 ribbons) | 30 each | per festival | built |
| Festival ribbons left at the end | 1 per ribbon | per festival | built |
| Season path steps 5/15/25 and 10/20/30 | 30 / 50 | per season | built |
| Season path, every step after 30 | 20 | per step, at most 10 a season | `SeasonPath.add` |
| Spirlog goals: bonded 3/5/8/11/all | 20 / 30 / 40 / 60 / 200 | once | built |
| Spirlog goals: seen 5/10/15/all | 10 / 20 / 30 / 60 | once | built |
| Roaming trip 4 / 8 / 12 h (also 60 / 120 / 180 coins, +50% for an element of the map's wild kinds, a common find of the map or a Tonic / Remedy / Strong Tonic, and a quarter of a wild battle's growth per hour up to the ring cap) | 1 / 1 / 2 | up to 3 trips at once | `Expeditions.collect` |
| Echo Path chest (all 8 rooms cleared) | 40 | once a week | `EchoPath.open_chest` |
| Monthly album, all 12 fields | 100 | once a month | `Album.record` |
| Iron Oath | +25% on every source above | while sworn | `Waymarks.earn` |

Daily tasks alone give 40 a day (280 a week), 65 a day after Act I with the hard fourth task; the
weekly sources fill the rest. Trips are an idle bonus: three 8-hour trips twice a day add 6 a day.
Once a day one task that is not started yet can be swapped for another one, free of charge.

### Endgame coins

| Source | Coins | How often |
| --- | --- | --- |
| Weekly echo | 400 (100 / 150 after 3 / 4 wins) | once a week |
| Lighthouse stair floor n | 100 + 20 per floor | once per floor |
| Roaming trip 4 / 8 / 12 h | 60 / 120 / 180 | up to 3 at once |
| Season path steps | 250 to 1650 | per season |
| Wayfarer rematches, wild battles | as in the story | any time |

### 90-day run (plan 3513)

`godot --headless --path . -s res://tools/balance_sim.gd -- endgame` works out 90 days with a
fixed plan (`EndgameSim.gd`: all daily tasks, two rounds of 8-hour trips a day, weekly echo,
all 8 masters, the Echo Path and 3 stair floors a week, the full album every month, one
festival; then buy at Marla's stand cheapest first). Nov 2026 run:

| Source | Waymarks in 90 days |
| --- | --- |
| Daily tasks (3 + the hard one) + bonus | 4950 + 900 |
| Master Wayfarers (640 in week 1, then 40 a week) | 1080 |
| Roaming trips | 540 |
| Weekly echo (with the target bonus) | 960 |
| Echo Path | 480 |
| Album | 300 |
| Lighthouse stair | 285 |
| Season path | 440 |
| Festival | 150 |
| **Total** | **10085 (112 a day, 784 a week; about 735 a week after the first)** |

Marla's stand took 9524 (398 goods, with the weekly crates), so the pouch ends at about 600: nothing is lost over the
cap, and the full weekly stock (about 900) is more than a week brings, so buying stays a choice.
The first run showed trips (48 a day) and weekly master rematches (160 a week) far above the
target; they were cut to 1/2/3 per trip and 5 per rematch. The fourth daily task (plan 3170) added 175 a
week, so trips were cut again to 1/1/2.

World events and the wandering merchant (`WorldEvents.gd`) pay no Waymarks: the event gives one
small item on the first visit of the day to its place, and the merchant sells three common goods
for coins at their normal price. Both are drawn from the date alone, so all players share them.

Rhythm rules: no event asks for a streak, and a missed day, week or month costs nothing: the
next one starts fresh. All timed content runs on server time (`Online.unix_now`/`date_now`). If
the clock goes back, stored progress is kept and nothing that was paid pays again
(`GameState.time_went_back`).

Festival ribbons: 3 per won battle against Spirlings of the festival's elements, 5 for the crier's
festival task of the day. They buy festival goods from Tilda in Brindlewick.

Season path: 30 steps per quarter, 100 points per step. Points: daily task 15, all daily tasks 15,
weekly echo win 40, festival goal stage 20. Four play days a week (3 tasks and the bonus) plus one
weekly win bring 280 a week, so step 30 is reached in 11 of the 13 weeks (plan 3242). Steps past 30
pay 20 Waymarks each, at most 10 a season. Steps pay the moment they are reached, so nothing waits
to be claimed when the season ends. This is the free path; a paid lane is area 10's decision. The rewards repeat every season, so nothing is missed for good.

### Journey complete and the Iron Oath

- "Journey complete: x%" (`Completion.gd`, records screen) weighs story 20, side goals 10,
  Spirlog (bonded kinds) 25, achievements 20, towers (lighthouse stair and both Rift towers,
  counted alike) 15 and exploring (maps visited) 10 percent. Each part counts its own share
  from 0 to 1. Badges only reachable during festivals or in the weekly echo do not count.
- At 50, 75 and 100 percent the journey pays 50, 100 and 300 Waymarks (`Completion.claim`),
  each once. A step stays paid when an update adds goals and the percent drops.
- Under the Iron Oath every Waymark reward pays 25% more (rounded down: 10 -> 12, 20 -> 25,
  80 -> 100). It makes up for Spirlings lost to the Sanctuary, not for coins or items.

### Ring cap after Act I and the Master Wayfarers

- `GameState.progress_cap()` follows the Veteran caps (12 ... 50) until Act I ends (flag
  `aldo_dock_told`), then opens to the full ring 60. Veteran and Rift-born use it as their
  level cap, so the endgame (weekly echo, lighthouse stair, masters) can use the whole range.
- Eight Master Wayfarers (data/endgame.json "masters") appear once both Rifts are mended. Each
  fields four Spirlings of one element, final forms for the ring, at master ring - 2 up to the
  master ring (45, 46, 48, 49, 50, 52, 53, 55). Eight first wins pay 640 Waymarks once; after
  that the masters add up to 160 a week.

### Shop techniques (Rift Scripts, plan area 10)

- Eight Rift Scripts (`rg_script_<element>`, 500 Riftglass or 4,99 € each) each teach one shop
  technique to one Spirling of that element and are used up. All have power 95, accuracy 100
  and 4 energy, more than the Echo Crystal techniques (power 55 to 80, 4 to 5 energy).
- Side effects: Glowglass Slash 20% scorch, Floodglass Wave 20% soak, Vineglass Sting heals 25%
  of the damage, Boltglass Bite 30% Pace -1 on the foe, Rockglass Ram 30% own Guard +1,
  Stormglass Cut priority +1, Lightglass Beam cures the user's condition, Duskglass Grip 30%
  Focus -1 on the foe.
- They are in no learnset: Wayfarer and Warden AI never field them, and the Fair League only
  allows learnable moves, so they are dropped there.
