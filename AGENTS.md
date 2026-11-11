# AGENTS.md — Chimora

Instructions for coding agents (Codex, Claude, etc.) working in this repo. Read this whole file before changing anything. Also read `LEGAL.md`; its rules override everything else.

## What we're building

**Chimora** is a retro pixel-art, turn-based monster-taming RPG for **iOS and Android**, built in **Godot 4.7.2 (GDScript)**. It has the feel of 2000s handheld monster RPGs. It aims for deep, replayable systems (difficulty modes with level caps, smart AI, post-game challenges). It uses **zero Nintendo / Game Freak / The Pokémon Company IP**.

- The player is a Wayfarer in the region **Veydal**, who bonds with original creatures called **Spirlings** and seals **Rifts** (Rifts replace gyms).
- **Every region upgrades the art style** (Era I → IV). See "Era system" below.
- The full design doc (GDD) is the source of truth for design questions. Ali owns it; ask him for the link if you need it.

## Hard rules (never break these)

1. **No Pokémon IP, anywhere.** That covers code, comments, asset names, strings, commit messages and store text. Banned: Pokémon, Poké-, "-mon" creature names, Pokédex, Poké Ball, Gym, Poké Center, HM, TM, red/white split-sphere shapes, and copies of Pokémon battle-screen layouts or fonts.
2. **Patent-safe mechanics** (Nintendo sued Palworld over these):
   - NO throwing or aiming an item to capture. Bonding is a **menu-triggered echo minigame** inside the battle (repeat the Spirling's call; no shrinking rings or timing circles, see `docs/legal/IP_PATENT_AUDIT.md`).
   - NO live capture-probability gauge. Show the result only after the minigame.
   - NO riding a creature to fly or glide. Traversal uses **Wayfarer Gear** items on foot (grapple, climbing pick, lantern). No gliders, wings or any gliding/flying traversal (patent risk zone).
   - NO throwing out a creature to summon it, and no flick-to-throw on the touchscreen. Spirlings step out beside the Wayfarer.
   - Battles start from overworld encounters and **cut to a separate battle screen**. No real-time shared-field fights.
3. **Original assets only.** Never add ripped sprites, tiles, music or fonts. Use colored placeholder rectangles until real art exists.
4. Don't add analytics, ads or network SDKs without Ali's explicit OK (they affect privacy forms and 16 KB compliance).
5. Never commit secrets (keystores, .p12 files, passwords). CI reads them from GitHub secrets.

## Tech stack and settings

| Item | Value |
| --- | --- |
| Engine | Godot **4.7.2-stable**. Don't use the 4.8 beta. |
| Language | GDScript with static typing everywhere (`var x: int`, typed arrays and dictionaries) |
| Renderer | `gl_compatibility` |
| Internal resolution | 144×256 portrait (Era I/II). Later eras raise it via `EraManager`. |
| Stretch | mode `viewport`, aspect `expand`, scale_mode `integer` |
| Pixel snapping | `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, default texture filter Nearest |
| Maps | Tiled 1.12 + YATI importer → **TileMapLayer** nodes (never the deprecated `TileMap`) |
| Android | target SDK 36, arm64-v8a, AAB via Gradle build, Play App Signing |
| iOS | Xcode 26 / iOS 26 SDK; build on a macOS runner |
| Tests | GUT (Godot Unit Test) for the pure battle model |

Commit the `.uid` sidecar files that Godot generates.

## Architecture

```
data/            JSON = editable source of truth (spirlings.json, moves.json, later: elements.json, trainers/, maps/)
scripts/core/    Elements, Database (JSON → typed Resources), GameState, EraManager, SaveManager
scripts/battle/  Pure battle MODEL (no Nodes): Spirling instance, DamageCalc, BondCalc, BattleModel, AI
scripts/battle/presenter/  BattleScene nodes that play back battle events (sprites, text box, HP bars)
scripts/overworld/ Player grid movement, NPCs, encounters, warps
scripts/ui/      Menus, party, Spirlog, virtual D-pad
scenes/          .tscn files mirroring scripts/
art/era1..era4/  One sprite set per era
tests/           GUT tests
```

**Key principles**

- **JSON is authored; Resources are used at runtime.** `Database.gd` loads the JSON into `SpirlingData` and `MoveData`. Never mutate species data at runtime. Runtime creatures are `Spirling` (RefCounted) instances.
- **The battle model is separate from the presenter.** `BattleModel` is pure GDScript. Each turn it takes actions and returns a list of **battle events** (`MoveUsed`, `Damage`, `StatusApplied`, `Fainted`, `BondResult`, …). The presenter animates them in order. This keeps the model unit-testable and replayable.
- **Battle flow is a state machine:** Intro → ChooseActions → ResolveOrder → ExecuteAction (loop) → EndOfTurn → FaintCheck/SwitchIn → VictoryCheck → (next turn | Rewards/Bond → Exit).
- **Turn order sort keys:** action class (swap/item before moves) → move priority → effective SPD → seeded RNG tiebreak. Re-check validity when each action runs.
- **One seeded `RandomNumberGenerator` per battle**, so bugs are reproducible.
- **Move effects are data-driven.** `effect_id` maps to an effect script with `apply(ctx)`. No giant `match` statement.
- **Input:** gameplay reads only input actions (`ui_up`, `ui_accept`, …). The virtual D-pad sits on its own `CanvasLayer` and calls `Input.action_press`.
- **Camera:** grid movement tweened in `_process`, camera position rounded to integers, no `position_smoothing`.
- **Saves:** a versioned JSON Dictionary (`save_version`) in `user://`. Write to a temp file and rename it, keep a backup, and save on `NOTIFICATION_APPLICATION_PAUSED`. Never load `.tres` files as player saves.

## Game rules (implement exactly)

**Elements (8 in Era I, 2 more prepared for Era II).** The chart lives in `data/type_chart.json` and `scripts/core/Elements.gd` reads it. Attacker strong → ×2; reverse direction → ×0.5; otherwise ×1. Dual elements multiply. Every element has at least 2 strengths and 2 weaknesses, no pair beats each other and no element strictly dominates another (`tools/balance/type_sim.py`, `tests/unit/test_type_chart.gd`). Ink and Echo (Era II) are in the chart only and sit on no Spirling yet.

| Element | Strong vs (Era I) | Strong vs (Era II) |
| --- | --- | --- |
| Ember | Bloom, Umbra | Echo |
| Tide | Ember, Stone | Echo |
| Bloom | Tide, Lumen | Echo |
| Volt | Tide, Gale | Ink |
| Stone | Ember, Volt | Ink |
| Gale | Bloom, Lumen | Echo |
| Lumen | Umbra, Volt | Ink |
| Umbra | Gale, Stone | Ink |
| Ink | Ember, Tide, Bloom, Gale | |
| Echo | Volt, Stone, Lumen, Umbra | |

**Stats:** HP, ATK, DEF, FOC (element/special), SPD. Each Spirling has hidden **Spark** values (0–12 per stat). Team of **5**, level cap **60**, up to 4 moves shown as a one-column list (never a 2x2 grid).

**Player-facing words:** code keeps its internal names (`level`, `hp`, `atk`, `trait_id`, `held`, `evolve`), but every text the player sees uses Chimora's own words: Ring (not level), Growth (not XP), Vigor (not HP), Might/Guard/Focus/Pace, Gift (not trait), Keepsake (not held item), Wayfarer (not trainer), art (not move), Unfurling (not evolution). German: Ring, Wachstum, Kraft, Wucht/Schutz/Fokus/Tempo, Gabe, Andenken, Wanderer, Technik, Entfalten. Full table in `docs/IP_HYGIENE.md`.

**Unfurling:** form changes are never automatic. When a Spirling is ready (ring, item or place), the overworld hints once and the Team menu offers "Unfurl"; an unfurled Spirling can "Furl back" to its earlier form at any time and keeps rings, arts and Spark.

**Energy instead of PP:** 10 Energy at battle start, +1 per turn. Each move has an energy cost.

**Statuses:** Scorch (−1/12 HP per turn, ATK ×0.75), Soak (SPD ×0.5, 3 turns), Root (can't swap, −1/12 HP per turn), Jolt (20% chance to skip the turn), Daze (accuracy ×0.7, 3 turns), Drowse (sleeps 2 turns).

**Damage:** `DamageCalc.gd` uses Chimora's own curve (replaced the classic-style formula in M1):
`dmg = (P × (A / D)^0.8 × (L / 5 + 3) / 12 + 1) × STAB(1.25) × E × Crit(1.4, 1/12) × R(0.9–1.0)`.
A same-level, neutral, 40-power move takes 15–25% of a balanced foe's HP; `tests/unit/test_damage.gd` pins this.

**Bonding:** chance = bond_rate × max(1 − HP%, 0.1) × timing_score × (1.5 if statused) + charm bonus, capped at 0.95. The score comes from the "Echo call" minigame (`BondEcho.gd`): the wild Spirling calls 4 marks, the player repeats them; score = correct prefix / length. A failed bond gives the wild Spirling one free action.

**Multi-Spirling battles (story set pieces):** a Wayfarer in map JSON may set `"front": [player, foe]` (up to 4 each), `"partner"` (an ally Wayfarer, e.g. Kestra, steered by AI), `"boss"` (a Rift boss from `BattleRules.BOSSES` whose HP and actions grow with the player's field) or `"wild": true` (a horde). Single-target moves are aimed; moves with `"target": "foes"` sweep every foe for 75% damage each. The Echo call (Bond) only works on wild foes. Random encounters and ordinary Wayfarers stay 1v1. See `BattleModel` (slots) and `tests/unit/test_multi_battle.gd`.

**Difficulty:** Story / Wayfarer / Veteran / Rift-Born. Veteran and Rift-Born use level caps; Rift-Born bans items in battle. AI levels are 0 / 1 / 2 / 2. See `GameState.gd`.

**AI tiers:** 0 = random legal move (wild); 1 = greedy (expected damage × accuracy × effectiveness, plus KO and status bonus); 2 = 1-ply lookahead plus switching on bad matchups plus items under HP thresholds.

## Era system (region design updates)

Each region is a visual generation jump. `EraManager` (autoload) owns the active era. It swaps the palette shader, sprite set (`art/eraN/`), UI theme and internal resolution, and stores the player's **Retro filter** choice (keep any unlocked older era).

| Era | Region | Resolution | Battle sprite | Palette |
| --- | --- | --- | --- | --- |
| I Ink | Veydal | 144×256 | 56×56 | 4 fixed inks on parchment (never handheld green) |
| II Wash | Corvane | 144×256 | 56×56 | 4 per sprite, day/night |
| III Etched | Ashmere | 180×320 | 64×64 | 16 per sprite |
| IV Panorama | Solenne | 270×480 | 96×96, 6-frame idle | 32 per sprite, 2.5D via SubViewport |

Until Era II+ art exists, sprite lookups must fall back to `art/era1/`.

## Task list (do these in order; one PR per milestone)

Each milestone must run headless (`godot --headless --quit` with no errors) and pass the GUT tests before you move on.

### M0 — Upgrade and clean up
- [x] Move `project.godot` to 4.7 (`config/features` "4.7", "GL Compatibility"). Add `stretch/aspect="expand"` and `snap_2d_transforms_to_pixel=true`. (Done; verify it opens cleanly in 4.7.2.)
- [x] Update `.github/workflows/export.yml` to `barichello/godot-ci:4.7.2` and templates `4.7.2.stable`. The Android job exports an AAB with `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars from base64 secrets (set no debug keystore vars) and adds a `zipalign -c -P 16` check. Add a separate `macos` job stub for iOS.
- [x] Add GUT under `addons/gut` and a `tests/` folder. Add a CI job that runs the tests headless.
- [x] Add a headless data-validation script: every move and evolution ID in the JSON resolves, and every element name is valid.

### M1 — Battle model (no visuals)
- [x] `BattleModel.gd`: state machine, action queue and ordering, Energy, the 6 statuses, faint and swap, victory. It emits battle events.
- [x] Replace the damage formula (see Game rules) and add tests: effectiveness table, STAB, crit, a determinism test with a fixed seed.
- [x] AI tiers 0–2.
- [x] Learnsets: add `learnset` (level → move name) to `spirlings.json` for all 15 Spirlings, using only moves in `moves.json`. Add moves until every element has at least 3.

### M2 — Battle presenter
- [x] `scenes/battle/Battle.tscn`: player Spirling bottom-left, foe top-right, HP bars, Energy pips, a text box, and a 4-move menu plus Swap / Item / Bond / Run. Use an **original layout** (Rule 1).
- [x] Play back the event list with short tweens; tap to advance text; a fast-forward toggle.
- [x] Bond minigame scene "Echo call": the Spirling calls a sequence on three marks, the player repeats it; it returns a score from 0 to 1.

### M3 — Overworld slice
- [x] Player grid movement (16 px tiles), 4-direction facing, hold-to-run, integer-rounded camera.
- [x] Virtual D-pad plus A/B on a CanvasLayer, respecting `DisplayServer.get_display_safe_area()`. Hide it when a gamepad is connected.
- [x] Start town + Route 1 built with TileMapLayer (placeholder tiles), tall-grass encounters using a per-route spawn table (`data/encounters.json`), and warps.
- [x] NPCs with dialogue from `data/dialogue/*.json`.

### M4 — Meta systems
- [x] Party (max 6), storage box, a Spirlog that tracks seen/bonded and route spawns (Spirlog Tracker).
- [x] SaveManager: versioned, atomic, saves on pause.
- [x] New-game flow: difficulty pick → Wayfarer customization (placeholder) → starter pick (Kindlop / Zippit / Wickit; no element triangle).
- [x] Settings: text speed, Retro filter (Era I only for now), volume.

### M5 — Vertical slice content
- [x] 2 Rifts with Wardens, 1 rival fight (Kestra), unlimited bag, PC access from the menu after Rift 2.
- [ ] Android internal-testing build, plus an iOS TestFlight build once the macOS signing secrets exist. (CI jobs `android-internal` and `ios` are ready; they wait for the signing secrets, see docs/RELEASE.md.)

## Conventions

- GDScript style: `snake_case` for variables and functions, `PascalCase` for classes and nodes, typed everything, `##` doc comments on public functions.
- No magic numbers in the battle code. Put them in `const` values or JSON.
- Keep PRs small. Commit message format: `area: what changed` (e.g. `battle: add status ticks`).
- If a task conflicts with LEGAL.md, stop and leave a note in the PR instead of guessing.
- If something is underspecified, pick the simplest option that fits this file and note the assumption in the PR description.
- New tweens go through `Juice.tween(node, prop, value, "curve")` (see docs/JUICE.md), so durations and feel can be tuned in one place. A plain `create_tween()` is only for steady bars that must run linearly, and for loops Juice does not cover yet.
