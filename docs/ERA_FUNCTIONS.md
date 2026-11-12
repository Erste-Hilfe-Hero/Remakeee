# Era functions

Owner wish (2026-11-12): moving from era to era should feel like starting with the genre's first
handheld game and getting more modern up to the fifth generation, in looks, animation and
functions. This page covers the functions. Looks and the era change sequence are in the era art
work (EraManager, RegionLook, BattleAnim); battle visuals belong to the battle presenter.

Chimora has five eras. Era I is the whole story (acts 1 to 4: Veydal, Corvane, Ashmere, Solenne).
Era II is Vellmarch, Era III Quillmarch, Era IV Halcyra, Era V Quivermoor.

## How it works

- `data/era_functions.json` lists every function with the era that opens it (`era`), the
  generation step that brought it to the genre (`step`, 1 to 5) and its `kind`:
  - `base`: there from the start of Era I. Gating these would break the Era I story balance or
    take something away from old saves, so they stay open.
  - `new`: opens with its era.
  - `upgrade`: an older function gets a deeper version in that era.
- `EraFeatures.is_unlocked(id)` answers from the save's unlocked era (it only ever rises). An
  unknown id is never open.
- `EraFeatures.new_in(era)` and `EraFeatures.new_in_lines(era)` list what an era brings. The era
  change calls `new_in_lines` after the era line (Overworld `_era_line_after_load`), and the
  Records menu has a page "Era functions" with one page per open era.
- English text lives in the data file, German in `tools/i18n/de_era_functions.py`.
- Tests: `tests/unit/test_era_features.gd`.

## Step 1 (Era I base)

| Function | Exists | Missing | Decision |
| --- | --- | --- | --- |
| Catching (Bonding) | `BondCalc`, BattleModel `_do_bond` | - | base |
| Gyms and badges (Wardens, Rifts) | Rift maps, `Badges`, `StoryBattles` | - | base |
| Dex (Spirlog) | `SpirlogBook`, `SpirlogPage` | - | base |
| Trading | `Exchange`, `TradeMenu`, online trades | - | base |

## Step 2 (shown as Era II)

| Function | Exists | Missing | Decision |
| --- | --- | --- | --- |
| Held items | Keepsakes (`items.json` "held", `BattleRules.held_info`) | - | base, the story already uses them |
| Day and night, time-based encounters | `DayCycle` (phase boosts in `EncounterTable.roll`), `NpcSchedule` | - | base |
| Time-of-day evolution | unfurl rule "time" (`Spirling.unfurl_targets`) | - | base |
| Breeding, eggs | `Breeding` (Echo Cores), `data/breeding.json` | - | base |
| Shiny variants | Gleam (`GleamRules`, `data/gleam.json`) | - | base |
| Special stat split | Focus stat (`Spirling.foc`) | separate special defence | base; one Focus stat is our own design |
| Two new elements | Rust, Mask (`data/region2.json` elements) | - | new in Era II |
| Phone rematches | `WardenRematch`, region rematches | phone itself | new in Era II; Lantern Mail covers messages |
| Berries | - | one-use held fruit | built: `pith_fruit`, new in Era II |
| Friendship | - | affection value and friendship evolution | later: needs new unfurl data for many lines |
| Custom capture balls | - | - | not fitting: Bonding has no balls |

## Step 3 (shown as Era III)

| Function | Exists | Missing | Decision |
| --- | --- | --- | --- |
| Passive abilities | Traits (`BattleRules.TRAITS`, 363 kinds carry one) | - | base |
| Natures | Temperament (`Spirling.TEMPERAMENTS`) | - | base |
| Double battles | `front` in trainers and story battles, `BattleModel` slots | - | base, the story uses them |
| Weather in battle | Rift fields (`BattleRules.FIELDS`) only from maps and moves | overworld weather changing battles | built: `sky_battles`, new in Era III |
| Running | `GridWalker` run step, Always run setting | - | base |
| Effort training | Fine training (`FineTraining`), Spark | - | base |
| Secret bases | The Burrow (`Burrow`) | - | base |
| Two new elements | Acid, Frost (`data/region3.json`) | - | new in Era III |
| Contests | - | beauty or show contests | later: a side activity, not core to battles |
| Berry blending | - | - | not fitting without berries planted in soil |

## Step 4 (shown as Era IV)

| Function | Exists | Missing | Decision |
| --- | --- | --- | --- |
| Physical or special per move | `MoveData.Kind` PHYSICAL, FOCUS, STATUS | - | base |
| Online trade and battle hub | `Online`, league, live duels, trades, raids | - | base |
| Touch menus | tap input everywhere (mobile game) | - | base |
| Forms | Regional imprints (`SpirlingData.variants`) | - | base |
| Partner battles | `BattleModel.set_partner` | - | base |
| Two new elements | Gilt, Zenith (`data/region4.json`) | - | new in Era IV |
| Wider battle stage | 2.5D stage (`EraManager.uses_stage_25d`) | - | upgrade in Era IV |
| Underground and minigames | - | digging minigame | later |
| New evolutions of old kinds | - | extra unfurl stages for old lines | later, art heavy |

## Step 5 (shown as Era V)

| Function | Exists | Missing | Decision |
| --- | --- | --- | --- |
| Reusable teaching items | Echo Crystals (`items.json` "teaches", never used up) | - | base |
| Seasons | `Season`, festivals | - | base |
| Hidden abilities | Hidden gifts (`HiddenGifts`) | - | base |
| Animated battle sprites, dynamic camera | `BattleAnim`, `data/era5_anim.json` | - | upgrade in Era V |
| EXP scaling by level difference | - | growth by ring difference | built: `ring_scaled_growth`, new in Era V |
| Shaking grass, rare spots | daily rare visitor (`DailyFind`) | visible daily spot | built: `rustling_spots`, new in Era V |
| Triple battles | `BattleModel` supports up to 4 per side, one Era I fight (Tide Rift mystic) | regular use | built: `triple_battles`, upgrade in Era V |
| Rotation battles | - | rotating front | later |
| Dream or side world | - | - | not fitting now: Echo duels and Rifts already fill that role |

## Built functions

- `sky_battles` (Era III): on an outdoor map with no Rift field of its own, the sky of the
  region (`WeatherCycle.current`) lays a field for the whole battle: rain lays High Tide, fog
  Deep Murk, a storm Static Veil (`data/weather.json` "battle", own opening lines). Wind and a
  clear sky change nothing. Echo duels stay even.
- `ring_scaled_growth` (Era V): Growth per earner times
  `((2 * foe + 10) / (foe + own + 10)) ^ 2.5`, kept within 0.25 to 4 (`BattleModel.growth_scale`).
  An even fight is unchanged.
- `pith_fruit` (Era II): Mending Pith (eaten at half Vigor or less, heals a quarter) and
  Clearing Pith (eaten when a condition lands, washes it off), `items.json` "held" keys
  `pith_heal` and `pith_cure`, `BattleModel.eat_pith`. Gone for good once eaten. Sold by the
  traders of Vellmarch, Halcyra and Quivermoor, not in Era I shops. The ace of every Vellmarch
  and Quivermoor Warden holds a Mending Pith (keepsakes count from Veteran on).
- `rustling_spots` (Era V): `RustleSpots`, one shaking patch of encounter ground per outdoor map
  and day (same for everyone), drawn as swaying blades. Stepping in fights the rarest kind of
  the map, 3 rings above its top ring, Gleam four times as likely. Used up per map and day
  (records "rustle_done").
- `triple_battles` (Era V): the second Wayfarer on each of the six Quivermoor roads sends three
  Spirlings at once (`front` [3, 3], `tools/art/world/quivermoor.py`). Era I has one triple
  fight already; Era V makes them a regular part of the roads.

## Numbers

35 functions in the table: 30 existed already (24 base, 6 era content), 5 built or extended here
(`sky_battles`, `ring_scaled_growth`, `pith_fruit`, `rustling_spots`, `triple_battles`).
Still missing and decided "later": friendship, contests, underground minigame, new stages for
old lines, rotation battles. Not fitting: custom capture balls, berry blending, dream world.
