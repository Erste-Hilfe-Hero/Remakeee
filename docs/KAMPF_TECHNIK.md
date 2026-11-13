# Kampfsystem: Technik, Zugänglichkeit und Leitplanken

For new contributors to the battle code. The backlog is `docs/KAMPF_PLAN_1000.md` (German, made by
`tools/plan/plan_1000.py`; CI fails when the md and the tool differ, so ticks are only set in the
tool). Read `AGENTS.md` and `LEGAL.md` first; their rules win over this page.

## 1. Architecture

| Part | Where | Rule |
| --- | --- | --- |
| Model | `scripts/battle/` (`BattleModel`, `Spirling`, `DamageCalc`, `BattleRules`, `StatusRules`, `BattleAI`) | Pure GDScript, no Nodes, no `get_tree()`, no `print()`. `test_kampf_a11y_tech.gd` fails otherwise. `BattleTest.gd` is the one headless dev scene. |
| Effects | `scripts/battle/effects/` | Every art effect is a `MoveEffect` registered in `EffectRegistry` by `effect_id`. No big `match`. |
| Events | `BattleEvent` | The model returns a list of events per turn; the presenter only plays them back. |
| Presenter | `scripts/battle/presenter/` (`BattleScene`, `CommandMenu`, `InfoStrip`, `BondMinigame`) | Reads events, never changes the model. |
| Data | `data/moves.json`, `data/spirlings.json`, `data/type_chart.json`, `data/rule_variants.json`, `data/ai_profiles.json` | JSON is the source. Tables that still live in code (`BattleRules.FIELDS`, `BattleRules.BOSSES`) are checked by `KampfChecks` inside `DataValidator`. |

### Model API (the calls the presenter, the AI, the simulators and the server referee use)

```
var m := BattleModel.new(player_team, foe_team, is_wild, seed, ai_level)
m.start()                          -> Array[BattleEvent]
m.legal_actions(side, slot)        -> Array[BattleAction]
m.submit_turn(action)              -> Array[BattleEvent]   # 1 vs 1
m.submit_actions(actions)          -> Array[BattleAction] per player slot -> events
m.needs_player_switch() / m.switch_slot() / m.submit_switch(index)
m.is_finished() / m.outcome
```

One seeded `RandomNumberGenerator` per battle: the same seed, teams and inputs give the same
battle (`test_balance.gd`, `test_move_curve.gd`, `test_p3_extras.gd`, `test_fuzz_battle_turns.gd`).

### Replays

`BattleReplay.snapshot(model, music, backdrop)` before `start()`, then the inputs. The snapshot is
the serialised battle state: seed, both teams with status and Energy, field, rules, variants.

- `"format"`: `BattleReplay.FORMAT`. Snapshots without it are format 1. A replay from a newer
  format is refused with a message instead of playing out wrong. Raise `FORMAT` when a new field
  changes how an old replay plays.
- `BattleReplay.shareable(snap)` drops the player's own words and habits (`PRIVATE_KEYS`:
  nickname, box, favourite mark, day met). Share codes and every `battle_submit` to the own server
  use it; the outcome stays the same.
- The seed is in every replay and in its label (`seed 1a2b3c4d`), so a bug report with a share
  code reproduces the battle.

## 2. Adding things

- **New art:** `docs/BALANCE.md`, section "Neue Technik hinzufügen".
- **New field:** add it to `BattleRules.FIELDS` (label, intro, boost/weaken element, optional
  blocks, regen_element with regen_div). `KampfChecks.field_errors()` checks every key.
- **New boss:** add it to `BattleRules.BOSSES` with a `phase` (`at` between 0 and 1, stage changes
  on atk/def/foc/spd within the stage limit, an existing field, a text). Maps name it by id;
  `KampfChecks.boss_errors()` checks both.
- **Texts:** English in code, German in an own `tools/i18n/de_*.py` table, then
  `python3 tools/i18n/build.py`. Dev-only scripts go into `SKIP_SCRIPTS` of `tools/i18n_extract.py`.

## 3. Tools and tests

| Need | Command or file |
| --- | --- |
| Win rates per species, art, trait, element | `godot --headless --path . -s res://tools/balance_sim.gd -- --mode team --level 36` (duel and team reports end with the trait and pooled element tables of `BalanceGroups`) |
| Master AI | `--ai 3` |
| Per field, per keepsake, per difficulty | `--mode fields`, `--mode keepsakes`, `--difficulty story/tamer/veteran/rift_born`, `--mode warden` |
| All reports and the docs | `tools/balance/run_all.sh` |
| Element chart gate | `python3 tools/balance/type_sim.py --strict` (CI) |
| Fuzz | `tests/fuzz/test_fuzz_battle_turns.gd` (10,000 random turns, hostile echo rows), `test_battle_fields.gd` (fields, bosses, multi) |
| Bands | `docs/BALANCE.md`, "Zielbänder"; slow checks in `tests/slow/` |

GUT runs every file in `tests/unit` and `tests/fuzz` on every PR (`tools/gut_strict.sh`); a test
file that does not load fails the job. No battle change is merged with a red check.

## 4. Accessibility in battle

| Setting or rule | Where |
| --- | --- |
| Screen reader names for strips, sprites and arts; the art buttons carry the whole info card as their description | `InfoStrip`, `MiniStrip`, `SpirlingSprite`, `CommandMenu.refresh` |
| Battle text read out as it appears (live region) | `TextBox` |
| High contrast, large text, colour-blind shapes, reduced motion, screen shake, vibration levels | Settings, Display and access |
| Distinct sounds and vibrations for strong and weak hits | `BattleScene._hit_sound`, `Haptics` |
| Captions for sounds and for every cry | `Sound.caption`, `Sound.cry_caption` |
| Bonding without speed or rhythm: style "Calm", the echo waits as long as it takes | Settings, Controls, Bonding |
| Art info without a long press: I or F1 on a keyboard, the top face button on a gamepad | `CommandMenu.is_info_key` |
| Mono sound and a level per channel | Settings, Sound |
| No time limit in offline battles: turns wait for the player, and with Calm bonding the bond waits too | `BattleScene`, `BondMinigame.calm` |
| No flashes over three per second | `tools/fx_flash_check.gd` (UI golden job) |

## 5. Guardrails (LEGAL.md)

- No names, texts, type charts, arts or formulas from other games. `tools/ip_check.sh` and
  `test_originality.gd` run in CI; `docs/IP_HYGIENE.md` has the glossary.
- No throwing, no thrown capture item, no visible bond odds, no swipe to bond, no riding or gliding.
- The command panel is a one-column list with a row of four buttons, not a 2x2 grid.
- Battle data goes only to the own server (`docs/ONLINE.md`), never to third parties; no analytics.
- Godot stays on 4.7.2 (`project.godot` features "4.7", checked by a test).
