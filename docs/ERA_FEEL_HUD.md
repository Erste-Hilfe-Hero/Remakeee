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
