# Samsung TV (Tizen) build

1. Export the web build: `godot --headless --path . --export-release "Web" build/web/index.html`
2. Wrap it: `python3 tools/tv/build_tv.py build/web build/tv <version>` -> `build/tv/` + `build/chimora-tv-unsigned.wgt`
3. Sign on the PC with the Samsung certificate (Tizen Studio):
   `tizen package -t wgt -s <profile> -- build/tv` -> `Chimora.wgt` for Seller Office.

The TV page sets `window.CHIMORA_TV`; `scripts/core/TvRemote.gd` then maps the remote's Back key
to the Android back handling, quits through Tizen, opens links in the TV browser, hides purchases
(the shop shows a note) and reports platform "app" so TV accounts keep the app retention.
Godot 4.7 web needs WebAssembly exception handling (Chrome 95+): Samsung TVs from 2024 (Tizen 8).
