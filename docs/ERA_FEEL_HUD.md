# Era feel: battle HUD

Data: `data/era_battle_hud.json`, code: `scripts/battle/presenter/EraBattleHud.gd` (pure helpers),
`BattleHud.gd` (layout), `InfoStrip.gd` / `MiniStrip.gd` (plates), `CommandMenu.gd` (menu and
art picker), `TeamRow.gd`, `LevelPanel.gd`, `BondMinigame.gd`. Tests:
`tests/unit/test_era_battle_hud.gd`. Shots: `tools/era_hud_shots.gd -- out_dir [era]`.

| Era | Plates | Vigor / Growth | Menu | Team row | Ring rise |
|-----|--------|----------------|------|----------|-----------|
| I   | plain ink boxes | ink bar, Growth jumps | text list, 2x2 commands | ink squares | stat list |
| II  | soft tab, bonded and Gleam marks | green/yellow/red bar, Growth bar | boxed rows, command row | fit/hurt colour | gain in colour |
| III | slanted plate with name band | Growth fills | element-coloured art rows | diamonds with status colour | bars |
| IV  | panel with shadow, large font | thicker bars | large touch rows: element, Energy, matchup word for known foes; last-item shortcut | larger marks | numbers count up |
| V   | gloss plates that follow the camera | rolling Vigor numbers | rows stagger in, rich long-press card; formation ranks staggered for triples | marks pop | as IV |

Rules: the table only grows (a later era never loses a feature, `problems()`), nothing on the
HUD overlaps on any era's phone screen, paper and ink come from UITheme (era skin of
`data/era_feel.json` and high contrast win), the text box frame comes from the shared skin.
Reduced motion: Growth jumps, numbers stop rolling, plates stay put, rows come in at once.

## Auto tab (plan Chimora 100, items 15-24, Ali 2026-11-21 "im Kampf Auto Knopf seitlich")

- Its own rect `auto` in `EraBattleHud.single_layout` / `formation_layout`: a tall tab flush with
  the right screen edge, standing on the text box. Size `auto_w` x `auto_h` per era (30x17 Era I/II,
  34x22 Era III, 52x30 Era IV/V; at least 46 dp on a 440 pt phone), +6 px each way with Big buttons.
  "Auto" over "On"/"Off", the era accent colour while on.
- Formation battles whose own rank reaches that corner (four Spirlings on the 144 px screens)
  keep Auto as a small button in the top band (`auto_band`).
- Which battles offer it: `BattleComfort.auto_kind`. Wild and story battles only; League, live
  duels, raids, tourneys, Halls and Trials ("friendly") and the record runs (Tower, Boss Hall,
  Weekly Giant, Master tour, Masters, Random Rift, weekly echoes, bounties) stay off, so no best
  floor or best time can be set by Auto (the simplest safe choice; nothing to mark or filter).
- Wardens, Rift bosses and story duels (rivals) start off and ask once per battle; Auto then plays
  AI tier 2 (tier 1 on Story difficulty). Auto picks the replacement after a faint, and hands the
  battle back once when a wild kind not yet bonded in the Spirlog stands.
