extends GutTest
## The start of the game (owner, 28 Nov 2026): the boot card's studio line stays on screen in
## every language on real phone sizes, one tap skips the whole card, the card is short, no Godot
## logo shows before it, and Continue goes straight into the world.

## View sizes ScreenFit gives real screens (window px / whole pixel scale): the Era I base,
## iPhone 13/14/15 (1170 x 2532 at scale 8), iPhone SE 2/3 (750 x 1334 at 5), iPhone 15 Pro
## (1179 x 2556 at 8), Android 1080 x 2400 at 7, and the Era III and IV bases.
const SIZES: Array[Vector2] = [Vector2(144, 256), Vector2(146, 317), Vector2(150, 267),
	Vector2(147, 320), Vector2(154, 343), Vector2(180, 320), Vector2(270, 480)]

var _font: Font

func before_all() -> void:
	var c := Control.new()
	c.theme = UITheme.get_theme()
	add_child_autofree(c)
	_font = c.get_theme_default_font()

func after_each() -> void:
	Loc.set_language("en")
	GameState.reduce_motion = false

func test_iphone_view_sizes_match_screen_fit() -> void:
	assert_eq(ScreenFit.content_size(Vector2(1170, 2532), Vector2i(144, 256)), Vector2i(146, 317))
	assert_eq(ScreenFit.content_size(Vector2(750, 1334), Vector2i(144, 256)), Vector2i(150, 267))

func test_german_line_was_wider_than_an_iphone() -> void:
	Loc.set_language("de")
	var w: float = _font.get_string_size(EraMoments.text("studio"), HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE).x
	assert_gt(w, 146.0, "the cause: one row of German does not fit a 390 pt iPhone")
	var lay: Dictionary = EraBoot.line_layout(_font, EraMoments.text("studio"), Vector2(146, 317))
	assert_eq((lay.lines as PackedStringArray).size(), 2, "so it breaks into two rows")
	assert_eq(lay.lines[0], "Gezeichnet vom")
	assert_eq(lay.lines[1], "Chimora-Team")

func test_studio_line_fits_every_language_and_screen() -> void:
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var line: String = EraMoments.text("studio")
		for size: Vector2 in SIZES:
			var lay: Dictionary = EraBoot.line_layout(_font, line, size)
			var card: Rect2 = lay.card
			var tag: String = "%s at %s" % [lang, size]
			assert_gte(card.position.x, 0.0, tag + ": card inside the left edge")
			assert_lte(card.end.x, size.x, tag + ": card inside the right edge")
			assert_lte(card.end.y, size.y, tag + ": card above the bottom")
			assert_gte(int(lay.fs), PixelFont.BASE_SIZE, tag + ": never below the plain font size")
			for l: String in lay.lines:
				var w: float = _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, lay.fs).x
				assert_lte(w, card.size.x - 10.0 * int(lay.k), tag + ": \"%s\" inside the card" % l)
			# One row whenever one row fits: only a too-wide line is broken.
			var one: float = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE).x
			if one + EraBoot.LINE_MARGIN <= size.x:
				assert_eq((lay.lines as PackedStringArray).size(), 1, tag + ": fits on one row")

func test_split_line_breaks_at_the_middle_space() -> void:
	assert_eq(EraBoot.split_line("Gezeichnet vom Chimora-Team"), "Gezeichnet vom\nChimora-Team")
	assert_eq(EraBoot.split_line("Dibujado por el equipo de Chimora"), "Dibujado por el\nequipo de Chimora")
	assert_eq(EraBoot.split_line("NoSpace"), "NoSpace")

func test_wordmark_stroke_fits_every_screen() -> void:
	for size: Vector2 in SIZES:
		var band: Rect2 = EraBoot.band_rect(_font, size.x, (size / 2.0).floor())
		# The dry tips reach 2 px past the stroke on each side.
		assert_gte(band.position.x - 2.0, 0.0, "stroke inside the left edge at %s" % size)
		assert_lte(band.end.x + 2.0, size.x, "stroke inside the right edge at %s" % size)
		var lw: float = _font.get_string_size(TitleArt.LOGO, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE * EraBoot.logo_scale(_font, size.x)).x
		assert_lt(lw, band.size.x, "the wordmark sits inside its stroke at %s" % size)

func test_ink_drop_runs_in_order() -> void:
	assert_lt(EraBoot.LAND_AT, EraBoot.BAND_AT)
	assert_lt(EraBoot.BAND_AT, EraBoot.LETTERS_AT)
	assert_eq(EraBoot.band_part(EraBoot.BAND_AT - 0.01), 0.0)
	assert_gt(EraBoot.band_part(EraBoot.BAND_AT), 0.0)
	assert_eq(EraBoot.band_part(EraBoot.LETTERS_AT), 1.0, "the stroke is full before the first letter")
	var n: int = TitleArt.LOGO.length()
	assert_true(EraBoot.letter_shown(n / 2, n, EraBoot.LETTERS_AT), "the middle letter comes first")
	assert_false(EraBoot.letter_shown(0, n, EraBoot.LETTERS_AT), "the outer letters come later")
	for i: int in n:
		assert_true(EraBoot.letter_shown(i, n, EraBoot.TEXT_AT), "every letter is stamped before the line")
	assert_lt(EraBoot.TEXT_AT + 0.4, float(EraMoments.boot(1).time) - EraBoot.FADE_TIME + 0.1, "the line stays a moment before the clear")

func test_every_boot_card_is_short() -> void:
	for e: int in EraMoments.ERAS:
		assert_lte(float(EraMoments.boot(e).time), 2.0, "the boot card of era %d lasts at most 2 s" % e)

func test_one_tap_closes_the_card_at_any_second() -> void:
	for e: int in EraMoments.ERAS:
		for at: float in [0.0, 0.3, 1.1]:
			var b := EraBoot.new()
			b.era = e
			b.manual = true
			add_child_autofree(b)
			b.advance(at)
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = true
			b._input(tap)
			assert_true(b.is_closed(), "one tap at %.1f s closes the boot card of era %d" % [at, e])

func test_no_godot_logo_before_the_boot_card() -> void:
	var paper: Color = EraMoments.col(1, "paper")
	assert_false(bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)), "no engine logo")
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	assert_true(bg.is_equal_approx(paper), "the splash is the parchment of the first boot frame")
	var path: String = str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	assert_eq(path, "res://art/icon/boot_splash.png", "exporters that still read an image get parchment")
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(img)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(img.get_width() / 2, img.get_height() / 2), Vector2i(img.get_width() - 1, img.get_height() - 1)]:
		assert_true(img.get_pixelv(p).is_equal_approx(paper), "the splash image is plain parchment")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	for sec: String in cfg.get_sections():
		if str(cfg.get_value(sec, "platform", "")) != "iOS":
			continue
		var opts: String = sec + ".options"
		assert_true(bool(cfg.get_value(opts, "storyboard/use_custom_bg_color", false)), "iOS launch screen has its own colour")
		assert_true((cfg.get_value(opts, "storyboard/custom_bg_color", Color.BLACK) as Color).is_equal_approx(paper), "iOS launch screen is parchment")
		assert_eq(str(cfg.get_value(opts, "storyboard/custom_image@2x", "")), path)
		assert_eq(str(cfg.get_value(opts, "storyboard/custom_image@3x", "")), path)

func test_continue_goes_straight_into_the_world() -> void:
	var keep: String = GameState.tamer_name
	GameState.tamer_name = "Tess"
	assert_eq(TitleScreen.welcome_line(), "Welcome back, Tess!")
	GameState.tamer_name = keep
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_false(src.contains("await _menu.info(welcome_text("), "no Welcome back card to tap away after Continue")
