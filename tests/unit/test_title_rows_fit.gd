extends GutTest
## Every row of the title menu reads in full on one line in all 14 languages and every era's screen (1.2.0
## store shots: "Join our Discord" was cut off in fr and ru). The list stands under the title art
## as on the title screen, so it scrolls and its scrollbar takes room from the rows.

## The title menu's rows (TitleScreen), "Continue" without its save summary.
const ROWS: Array[String] = ["Continue", "New Game", "Load...", "What's new", "Join our Discord", "Settings"]

var _keep: Array = []

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.set_retro_filter(_keep[1])
	Loc.set_language("en")

func test_title_rows_fit_in_every_language_and_era() -> void:
	var entries: Array[Dictionary] = []
	for r: String in ROWS:
		entries.append({"text": r})
	for era: int in [1, 2, 3, 4, 5]:
		EraManager.unlocked_era = EraManager.NEWEST
		EraManager.retro_filter = era
		for code: String in Loc.LANGUAGES:
			Loc.set_language(code)
			var stage := Control.new()
			var screen: Vector2 = Vector2(EraManager.RESOLUTION[era])
			stage.size = screen
			add_child_autofree(stage)
			var host := MenuHost.new()
			stage.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			# Where TitleScreen puts its menu: under the title art.
			host.offset_top = EraTitleArt.art_height(int(screen.x)) + 4
			await wait_process_frames(1)
			var run := func() -> void: await host.pick("", entries, false)
			run.call()
			await wait_process_frames(3)
			var rows: Array[Button] = host.picker._buttons
			assert_eq(rows.size(), ROWS.size(), code)
			for b: Button in rows:
				var sb: StyleBox = b.get_theme_stylebox("normal")
				var room: float = b.size.x - sb.content_margin_left - sb.content_margin_right
				var shown: String = Loc.t(b.text)
				var tw: float = b.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
				assert_lte(tw, room, "era %d %s: title row \"%s\" fits (%d of %d px)" % [era, code, shown, int(tw), int(room)])
			host.picker.picked.emit(-1)
			await wait_process_frames(1)
			stage.queue_free()
