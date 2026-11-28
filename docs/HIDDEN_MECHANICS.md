# Hidden mechanics (1.3.2)

Team page, never shown in game. Owner request: "Füge auch versteckte Mechaniken hinzu", later
"voll viele versteckte Sachen". Everything is data in `data/hidden_mechanics.json`; logic in
`scripts/core/HiddenMechanics.gd` (world) and `scripts/battle/HiddenBattle.gd` (battle). Tests:
`tests/unit/test_hidden_mechanics.gd`.

Rules every entry follows:

- Found by playing, never listed, never sold, never rolled for money. No shop or Gleam file is touched.
- Moon, weekday and date use the Berlin calendar day (`HiddenMechanics.berlin_day`), so all players
  share them. Sky is `WeatherCycle` (same for everyone in a region), time of day is `DayCycle`.
- Offline and online behave the same: all state is in `GameState.records` / `flags`, which the cloud
  save already carries. No server function is needed.
- Save compatible: no new save field, no save version bump. Records used: `hidden_found` (ids),
  `hidden_found_n` (count for the badge), `hidden_taps` (presses per spot), `hm_date_<id>` (year
  of the last dated note). Flags: `hm_<spot id>` or the spot's own `flag`.
- Battle touches only work when `BattleModel.hidden_rules` is on: world battles (story, Wayfarers,
  wild). League (fair and open), live duels, raids, tournaments, echo duels and Warden battles
  (they go to the weekly Rift board and the server referee) keep it off, like hidden gifts in the
  Fair League. The flag travels in the replay as `"hidden": true` (only when on, so old
  replays are unchanged) and the referee plays the battle exactly again. The touches change only
  damage factors and the crit chance; the number of RNG draws stays the same.
- Texts: `tools/i18n/de_hidden.py` (German) and `tools/i18n/locales_hidden.py` (12 more languages).
  `tools/i18n_extract.py` reads `data/hidden_mechanics.json`, so a new line without German fails CI.
  The code words LANTERN and TALLOW stay untranslated: players type them.

## 1. Secret unfold paths (7)

Extra paths into a form the line already reaches, so Furl back keeps working. Never hinted in the
Team menu; the "can unfurl" mark simply appears. Read by `Spirling.unfurl_targets` via
`HiddenMechanics.unfold_targets`.

| id | Region | Line | Trigger |
| --- | --- | --- | --- |
| u_kindlop_night | Veydal | Kindlop -> Smoldrake | Ring 10+ (normally 14), holding Bark Wrap, at night |
| u_drizzlet_rain | Corvane | Drizzlet -> Rainmantle | While it rains on the current map (normally night) |
| u_ashwren_pulse | Ashmere | Ashwren -> Ashcrest | Knows Brazier Pulse, standing in Cinderfold (normally dawn) |
| u_solkit_moon | Solenne | Solkit -> Solmantle | Full moon night (normally day): the sun kit under the moon |
| u_glimmoth_candles | Quivermoor | Glimmoth -> Wickmoth | Kinship 40+ on Candle Causeway (normally dusk) |
| u_vesk_storm | Quillmarch | Vesk -> Veskara | Ring 18+ (normally 22) in a storm |
| u_tollpip_lock | Vellmarch | Tollpip -> Tollgull | Ring 18+ (normally 23), holding Iron Burr, in Hookwick |

## 2. Rare spawns (8)

Checked in the encounter code (`Overworld`, after the daily visitor and the pass rare, before the
normal table) by `HiddenMechanics.maybe_spawn`. The RNG is drawn only when the conditions hold, so
normal encounters roll exactly as before. Rings follow the map's table unless min/max are set.
`data/encounters.json` and `data/spirlings.json` are not changed.

| id | Region / map | Species | Trigger | Chance per encounter |
| --- | --- | --- | --- | --- |
| s_moon_hush | Veydal / Fernstair | Hushkin (Ring 6-9) | Night and full moon | 30 % |
| s_rain_prism | Corvane / Stillwater | Prismist | Rain | 20 % |
| s_fog_wraith | Ashmere / Saltglass | Fumewraith | Fog at dusk | 25 % |
| s_chain_gull | Vellmarch / Weeping Locks | Tollgull | Gleam chain of 5+ (any kind) | 20 % |
| s_night_orrlet | Halcyra / Orrery Ridge | Orrlet | Night | 25 % |
| s_moon_moth | Quivermoor / Hymnmarsh | Glimmoth | Night and full moon | 30 % |
| s_sunday_owl | Quillmarch / Hoarfrost Moor | Sleetowl | Sunday at dawn (Berlin weekday) | 30 % |
| s_wind_hare | Solenne / Glasswind Flats | Highhare | Wind | 25 % |

## 3. Hidden spots on maps (12)

`HiddenMechanics.spot_at` / `tap`; `Overworld.hidden_spot`. "tile" spots answer only on a solid
cell nothing else answers (no sign, NPC, landmark or existing hidden find), so no map layout
changed. "landmark" and "sign" spots answer after the normal text. The test checks every cell
against the current map data.

| id | Region / map, cell | Trigger | Effect |
| --- | --- | --- | --- |
| p_lone_oak | Veydal / Gloamwood (4,4), tree | Knock 3 times | Kin Charm |
| p_cairn_back | Veydal / Crowcrest (3,8), between the Crowcrest Cairn and the cliff | Look behind it | Spark Drop |
| p_beacon_blink | Veydal / Brindlewick (1,11), Old Lake Beacon | At night | Blink pattern and the keeper's note: the clue LANTERN |
| p_quay_word | Corvane / Corvane Quay (10,13), sign | Write LANTERN in the boxes | Spark Charm |
| p_heron_back | Corvane / Corvane Quay (11,7), behind the Quay Heron | Look behind it | Keen Lens |
| p_needle_fog | Ashmere / Saltglass (10,21), the Salt Needle | Only in fog | Swift Feather |
| p_founder_mask | Vellmarch / Larkspur Heights (5,13), Masked Founder | Press 3 times | The clue TALLOW |
| p_last_word | Vellmarch / Lastlamp (5,17), sign | Write TALLOW | Rest Candle x3 |
| p_star_well | Halcyra / Starwell (5,8), the well | Any time | Reads each team member's knack (see 5) |
| p_echo_well | Solenne / Ochrewell (6,8), the well | Call 7 times | The well calls the player's name back (badge "Someone Answered") |
| p_chapel_lamp | Quivermoor / Rootchapel (8,17), lamp | At night, 3 presses | Revival Leaf |
| p_frost_fence | Quillmarch / Proofgate (2,5), fence | Lead Spirling is Frost | Frost Charm |

The two code chains cross regions on purpose (Veydal beacon -> Corvane quay; Vellmarch statue ->
Vellmarch lamp), so players have something to tell each other.

## 4. Hidden battle touches (6)

`HiddenBattle.hit_mult` / `crit_mult`, called from `BattleModel._do_move` next to the other hit
factors. Combos and sky synergies say one line when they happen; keen rules stay silent.

| id | Trigger | Effect |
| --- | --- | --- |
| b_kindled_breath | Same Spirling: Kindle Up, then Cinder Breath on its next action | x1.3 damage |
| b_misted_shot | Same Spirling: Chill Mist, then Spindrift Shot | x1.25 damage |
| b_rainbow | Lumen art on the High Tide field (rain from Era III on) | x1.2 damage |
| b_fog_cutter | Gale art on the Deep Murk field (fog) | x1.15 damage |
| b_last_spark | Attacker at 1/4 Vigor or less | Crit chance x2 |
| b_underdog | Attacker 10+ rings below its target | Crit chance x2 |

## 5. Knack: the favourite sky (1)

Each Spirling has a hidden favourite sky (clear, rain, fog, wind, storm), worked out from its uid
(`HiddenMechanics.knack`), so nothing new is saved. Winning a world battle under that sky gives each
Spirling that fought and loves it +1 Kinship (`HiddenMechanics.after_battle`). The Star Well in
Starwell (Halcyra) describes it in vague words, nothing else shows it.

## 6. Easter eggs and badges (4)

| id | Trigger | Effect |
| --- | --- | --- |
| d_long_night | 21 December (Berlin), first start that day | A quiet line about every lamp in Veydal, once a year |
| d_first_thaw | 20 March (Berlin) | A line about the ferns of Fernstair, once a year |
| hidden_keeper (badge, secret) | 10 hidden things found (`record:hidden_found_n`) | 50 Waymarks |
| hidden_echo (badge, secret) | The Ochrewell well calls back (`flag:hm_echo_name`) | 10 Waymarks |

Total: 7 + 8 + 12 + 6 + 1 + 4 = 38 entries over all eight regions.

## Adding one

1. Add the entry to `data/hidden_mechanics.json` (keys are listed in its `_comment`).
2. Add its texts to `tools/i18n/de_hidden.py` and `tools/i18n/locales_hidden.py`, run both and
   `python3 tools/i18n/build.py`.
3. Add a row here and run `tests/unit/test_hidden_mechanics.gd`.
