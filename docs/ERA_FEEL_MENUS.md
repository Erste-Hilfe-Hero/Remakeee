# Era feel: menu screen layouts

The skin of the menus (colours, frames, font, text voice) is `data/era_feel.json` (docs/ERA_FEEL_UI.md).
This slice is the structure: how each menu screen is built in each era. One table,
`data/era_menus.json`, read by `scripts/core/EraMenus.gd`; the shared pieces are in
`scripts/ui/EraMenuKit.gd`, `EraMenuArt.gd` (own 9x9 symbols), `EraSummary.gd` (tabbed summary),
`EraDexViews.gd` (preview, area map, size compare) and `EraPartyDrag.gd` (drag to reorder).

Screens: start menu (`pause`), team (`party`), Spirling summary, satchel (`bag`), Spirlog (`dex`),
save screen, settings (`options`), shop list, world map.

| Era | Style | What changes |
|---|---|---|
| I | Plain list | One column, arrow cursor, no symbols. Summary on 2 text pages. Satchel one list in pocket order. Spirlog a number list with a small sprite. Clock as a line on the save card. |
| II | Icon list | Symbol per entry, satchel pockets as tabs, small bobbing team sprites, clock strip on the start menu and save screen, Spirlog area map, summary on 3 pages. |
| III | Tabbed pages | Tabbed summary (Info, Values, Arts, Merits) with a fixed card, coloured element badges, pocket pictures, Spirlog page tools: Cry, Size compare, Area. Shop prices as badges. |
| IV | Touch panels | Finger-sized rows (24 px and more), a 2-column grid of big buttons in the start menu, a persistent info panel at the bottom of every list, drag to reorder the team, Spirlog search on top and named forms, the map picture takes the top of the phone with a button bar. |
| V | Living menus | Rows slide in, drifting backdrop, glowing cursor, breathing summary sprite, animated team on the save card, region and season tabs in the Spirlog, pinned shortcuts as a bar on top of the start menu, pulsing "you are here". |

Rules (checked by `EraMenus.problems()` and `tests/unit/test_era_menus.gd`):

- Every function of a screen (`functions` in the table) is presented in every era; only the way changes.
  Example: "reorder" is a "Move to slot" row in Era I to III and drag in IV and V (the row stays for keys,
  gamepads and screen readers); "shortcuts" is a menu entry in every era and a bar in V.
- A later era never takes back symbols, the info panel, row height or columns.
- Reduced motion stops every animation (slide, backdrop, bob, breathe, pulse, glow).

Review: `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_menu_shots.gd -- out_dir`
renders every screen in every era in English and German at each era's phone resolution and prints what
does not fit (`EraMenuKit.fit_problems`).
