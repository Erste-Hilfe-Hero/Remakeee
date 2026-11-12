extends GutTest
## Text look of the later eras (data/era_text.json, EraText, EraFont, SpeakerPortrait, EraWarp,
## docs/ERA_FEEL_TEXT.md): the own 10 px and 12 px fonts and who gets them, speaker portraits
## per era and speaker, the spiral door warp, and that Eras I and II stay as they were.

const EN_DE: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?:;'\"-+=/\\()[]<>%&#*_^~@$|`{}ÄÖÜäöüß€≈ "
const KNOWN: String = "Kestra"
const UNKNOWN: String = "Fishwife Marga"
const BOX_SIZE: Vector2 = Vector2(260, 40)

var _unlocked: int
var _retro: int
var _lang: String
var _large: bool
var _reduce: bool

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_lang = Loc.language()
	_large = UITheme.large_text
	_reduce = GameState.reduce_motion

func after_each() -> void:
	GameState.reduce_motion = _reduce
	UITheme.set_large_text(_large)
	Loc.set_language(_lang)
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)

func _era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

func _box(in_layout: bool = false) -> TextBox:
	var box := TextBox.new()
	if in_layout:
		var col := VBoxContainer.new()
		add_child_autofree(col)
		col.add_child(box)
	else:
		add_child_autofree(box)
		box.position = Vector2(4, 200)
		box.size = BOX_SIZE
	return box

# --- The table ---

func test_table_is_sound() -> void:
	assert_eq(EraText.problems(), [] as Array[String])

func test_every_era_defines_every_key() -> void:
	for e: int in range(1, 6):
		for k: String in EraText.KEYS:
			assert_true(EraText.of(e).has(k), "era %d has %s" % [e, k])

func test_eras_one_and_two_stay_as_they_were() -> void:
	for e: int in [1, 2]:
		assert_eq(EraText.font_id(e, "en"), "", "era %d keeps the pixel font" % e)
		assert_eq(EraText.portrait_mode(e), "none", "era %d has no portrait" % e)
		assert_eq(EraText.warp(e, "door"), "door", "era %d keeps the door warp" % e)

func test_each_later_era_adds_its_step() -> void:
	assert_eq(EraText.font_id(3, "en"), "etch10", "III: 10 px font")
	assert_eq(EraText.warp(3, "door"), "spiral", "III: spiral warp")
	assert_eq(EraText.font_id(4, "en"), "pano12", "IV: 12 px font")
	assert_eq(EraText.portrait_mode(4), "icon", "IV: head on the name plate")
	assert_eq(EraText.font_id(5, "en"), "pano12", "V: 12 px font")
	assert_eq(EraText.portrait_mode(5), "bust", "V: portrait")

func test_out_of_range_eras_clamp() -> void:
	assert_eq(EraText.of(0), EraText.of(1))
	assert_eq(EraText.of(9), EraText.of(5))

# --- Fonts ---

func test_fonts_draw_english_and_german() -> void:
	for id: String in EraFont.ids():
		for i: int in EN_DE.length():
			assert_true(EraFont.has_glyph(id, EN_DE[i]), "%s draws '%s'" % [id, EN_DE[i]])

func test_fonts_draw_every_plain_glyph_of_the_pixel_font() -> void:
	# Whatever the pixel font draws for English and German, the era fonts draw too; only the
	# button marks (private use) stay with the pixel font.
	for ch: String in PixelFont.GLYPHS:
		if ch.unicode_at(0) >= 0xE000:
			continue
		for id: String in EraFont.ids():
			assert_true(EraFont.has_glyph(id, ch), "%s draws '%s'" % [id, ch])

func test_glyphs_fit_their_cell() -> void:
	for id: String in EraFont.ids():
		var def: Dictionary = EraFontGlyphs.FONTS[id]
		for ch: String in def.glyphs:
			var rows: Array = def.glyphs[ch]
			assert_eq(rows.size(), int(def.cell_h), "%s '%s' rows" % [id, ch])
			for r: Variant in rows:
				assert_eq(str(r).length(), str(rows[0]).length(), "%s '%s' row width" % [id, ch])
			assert_lte(str(rows[0]).length(), int(def.cell_w), "%s '%s' width" % [id, ch])

func test_font_sizes_grow_with_the_eras() -> void:
	assert_eq(EraFont.cell_height("etch10"), 10)
	assert_eq(EraFont.cell_height("pano12"), 12)
	assert_gt(EraFont.cell_height("etch10"), PixelFont.CELL_H, "Era III writes larger than the pixel font")
	assert_eq(EraFont.cell_height("pano12"), PixelFont.LARGE_H, "Eras IV and V keep the line height they had")

func test_umlauts_differ_from_their_base_letters() -> void:
	for id: String in EraFont.ids():
		for pair: Array in [["Ä", "A"], ["Ö", "O"], ["Ü", "U"], ["ä", "a"], ["ö", "o"], ["ü", "u"], ["ß", "B"]]:
			assert_ne(EraFont.glyph(id, pair[0]), EraFont.glyph(id, pair[1]), "%s %s" % [id, pair[0]])

func test_font_file_metrics() -> void:
	for id: String in EraFont.ids():
		var f: FontFile = EraFont.get_font(id)
		var size: int = UITheme.FONT_SIZE
		assert_eq(int(f.get_height(size)), EraFont.cell_height(id), id + " line height")
		for text: String in ["Kestra", "Zwölf Boxkämpfer", "über den großen Deich", "R12 100%"]:
			assert_eq(int(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x), EraFont.text_width(id, text), "%s width of '%s'" % [id, text])
		assert_same(EraFont.get_font(id), f, "built once")

func test_other_characters_fall_back_to_the_pixel_font() -> void:
	assert_same(EraFont.get_font("etch10").fallbacks[0], PixelFont.get_font())
	assert_same(EraFont.get_font("pano12").fallbacks[0], PixelFont.get_large_font())
	assert_false(EraFont.has_glyph("etch10", "é"))
	assert_true(PixelFont.has_glyph("é"), "the pixel font behind it draws it")
	assert_null(EraFont.get_font("nope"))

func test_only_english_and_german_get_the_era_fonts() -> void:
	for lang: String in Loc.LANGUAGES:
		var want: String = "etch10" if lang in ["en", "de"] else ""
		assert_eq(EraText.font_id(3, lang), want, lang)
		assert_eq(EraText.font_id(5, lang), "pano12" if lang in ["en", "de"] else "", lang)

func test_large_text_wins_over_the_ten_pixel_font() -> void:
	assert_eq(EraText.font_id(3, "en", true), "", "Large text is larger than the 10 px font")
	assert_eq(EraText.font_id(4, "en", true), "pano12")

func test_theme_font_follows_the_era() -> void:
	Loc.set_language("en")
	UITheme.set_large_text(false)
	var want: Dictionary = {1: PixelFont.get_font(), 2: PixelFont.get_font(), 3: EraFont.get_font("etch10"),
		4: EraFont.get_font("pano12"), 5: EraFont.get_font("pano12")}
	for e: int in range(1, 6):
		_era(e)
		assert_same(UITheme.font(), want[e], "era %d font" % e)
		assert_same(UITheme.get_theme().default_font, want[e], "era %d theme" % e)

func test_retro_filter_brings_the_old_font_back() -> void:
	Loc.set_language("en")
	UITheme.set_large_text(false)
	_era(5)
	EraManager.set_retro_filter(1)
	assert_same(UITheme.font(), PixelFont.get_font())
	EraManager.set_retro_filter(3)
	assert_same(UITheme.font(), EraFont.get_font("etch10"))

func test_theme_font_follows_the_language() -> void:
	UITheme.set_large_text(false)
	_era(3)
	Loc.set_language("de")
	assert_same(UITheme.get_theme().default_font, EraFont.get_font("etch10"))
	Loc.set_language("fr")
	assert_same(UITheme.get_theme().default_font, PixelFont.get_font(), "French keeps the pixel font")
	_era(5)
	Loc.set_language("ja")
	assert_same(UITheme.get_theme().default_font, PixelFont.get_large_font(), "Japanese keeps the large pixel font")

func test_dialogue_box_wraps_with_the_era_font() -> void:
	Loc.set_language("de")
	UITheme.set_large_text(false)
	_era(3)
	var f: Font = UITheme.font()
	var pages: Array[String] = TextBox.split_lines("Zwölf Boxkämpfer jagen Viktor quer über den großen Sylter Deich.", 120.0, f, UITheme.FONT_SIZE, TextBox.MAX_LINES)
	for page: String in pages:
		for line: String in page.split("\n"):
			assert_lte(f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x, 120.0, line)

# --- Speakers ---

func test_speaker_ids() -> void:
	assert_eq(EraText.speaker_id("Kestra"), "kestra")
	assert_eq(EraText.speaker_id("kestra"), "kestra", "case does not matter")
	assert_eq(EraText.speaker_id("Warden Senna"), "senna")
	assert_eq(EraText.speaker_id("Mother Grell"), "grell")
	assert_eq(EraText.speaker_id("Veit Harrow"), "veit")
	assert_eq(EraText.speaker_id(" Aldo "), "aldo")
	assert_eq(EraText.speaker_id(UNKNOWN), "")
	assert_eq(EraText.speaker_id(""), "")

func test_every_speaker_has_both_pictures() -> void:
	assert_gte(EraText.speaker_ids().size(), 24)
	for id: String in EraText.speaker_ids():
		for mode: String in ["icon", "bust"]:
			assert_ne(EraText.art_path(id, mode), "", "%s %s" % [id, mode])

func test_picture_sizes() -> void:
	var s: int = int(EraText.portrait_value("size", 0.0))
	var frames: int = int(EraText.portrait_value("frames", 0.0))
	var icon: int = int(EraText.portrait_value("icon_size", 0.0))
	for id: String in EraText.speaker_ids():
		var bust: Texture2D = load(EraText.art_path(id, "bust"))
		assert_eq(Vector2i(bust.get_size()), Vector2i(s * frames, s), id + " bust sheet")
		var head: Texture2D = load(EraText.art_path(id, "icon"))
		assert_eq(Vector2i(head.get_size()), Vector2i(icon, icon), id + " head")

func test_art_path_falls_back_to_nothing() -> void:
	assert_eq(EraText.art_path("", "bust"), "")
	assert_eq(EraText.art_path("nobody", "bust"), "")
	assert_eq(EraText.art_path("kestra", "none"), "")

func test_layout_boxes_show_the_small_head() -> void:
	assert_eq(SpeakerPortrait.mode_for("bust", false), "bust")
	assert_eq(SpeakerPortrait.mode_for("bust", true), "icon", "no room for a bust in the battle layout")
	assert_eq(SpeakerPortrait.mode_for("icon", true), "icon")
	assert_eq(SpeakerPortrait.mode_for("none", false), "none")
	assert_eq(SpeakerPortrait.mode_for("???", false), "none")

func test_box_shows_the_speaker_by_era() -> void:
	var box: TextBox = _box()
	await wait_process_frames(2)
	var want: Dictionary = {1: "none", 2: "none", 3: "none", 4: "icon", 5: "bust"}
	for e: int in range(1, 6):
		_era(e)
		box.apply_era_frame()
		box.set_speaker(KNOWN)
		await wait_process_frames(2)
		assert_eq(box._portrait.mode(), want[e], "era %d" % e)
		assert_eq(box._portrait.visible, want[e] != "none", "era %d shown" % e)
		assert_eq(box.speaker(), KNOWN, "era %d keeps the name tag" % e)

func test_unknown_speaker_keeps_the_plain_tag() -> void:
	_era(5)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.set_speaker(UNKNOWN)
	await wait_process_frames(2)
	assert_eq(box._portrait.mode(), "none")
	assert_false(box._portrait.visible)
	assert_eq(box.speaker(), UNKNOWN)
	box.set_speaker("")
	assert_false(box._portrait.visible)

func test_name_plate_makes_room_for_the_head() -> void:
	_era(4)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.apply_era_frame()
	box.set_speaker(UNKNOWN)
	await wait_process_frames(2)
	var plain: float = box._tag.get_theme_stylebox("normal").content_margin_left
	box.set_speaker(KNOWN)
	await wait_process_frames(2)
	var icon: float = EraText.portrait_value("icon_size", 0.0)
	assert_eq(box._tag.get_theme_stylebox("normal").content_margin_left, plain + icon + SpeakerPortrait.ICON_GAP)
	var tag_rect := Rect2(box._tag.global_position, box._tag.size)
	assert_true(tag_rect.encloses(Rect2(box._portrait.global_position, box._portrait.size)), "the head sits on the plate")
	# Calling it again does not push the name further right, and a speaker without art gets the plain plate back.
	box.set_speaker(KNOWN)
	assert_eq(box._tag.get_theme_stylebox("normal").content_margin_left, plain + icon + SpeakerPortrait.ICON_GAP)
	box.set_speaker(UNKNOWN)
	assert_eq(box._tag.get_theme_stylebox("normal").content_margin_left, plain)

func test_bust_sits_on_the_box_and_clear_of_the_name() -> void:
	_era(5)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.apply_era_frame()
	box.set_speaker(KNOWN)
	await wait_process_frames(3)
	var p: SpeakerPortrait = box._portrait
	var rect := Rect2(p.global_position, p.size)
	assert_eq(rect.end.y, box.global_position.y + SpeakerPortrait.BUST_OVERLAP)
	assert_lte(rect.end.x, box.global_position.x + box.size.x)
	assert_false(rect.intersects(Rect2(box._tag.global_position, box._tag.size)), "portrait and name tag do not overlap")

func test_bust_goes_under_a_box_at_the_top() -> void:
	var own := Vector2(38, 38)
	var pos: Vector2 = SpeakerPortrait.bust_position(Rect2(4, 10, 260, 40), own)
	assert_eq(pos.y, 50.0 - SpeakerPortrait.BUST_OVERLAP)
	assert_eq(SpeakerPortrait.bust_position(Rect2(4, 200, 260, 40), own).y, 200.0 - own.y + SpeakerPortrait.BUST_OVERLAP)

func test_battle_box_shows_the_head_in_era_five() -> void:
	_era(5)
	var box: TextBox = _box(true)
	await wait_process_frames(2)
	box.set_speaker(KNOWN)
	await wait_process_frames(2)
	assert_eq(box._portrait.mode(), "icon")

func test_bust_frames() -> void:
	var every: float = EraText.portrait_value("blink_every", 0.0)
	var talk: float = EraText.portrait_value("talk_time", 0.0)
	assert_eq(EraText.bust_frame(0.0, false, false), 0, "resting")
	assert_eq(EraText.bust_frame(every - 0.01, false, false), 1, "blink")
	assert_eq(EraText.bust_frame(every - 0.01, true, false), 1, "the blink wins over the mouth")
	assert_eq(EraText.bust_frame(talk * 1.5, true, false), 2, "speaking")
	assert_eq(EraText.bust_frame(talk * 1.5, false, false), 0, "mouth shut once the line stands")
	assert_eq(EraText.bust_frame(talk * 2.5, true, false), 0, "the mouth opens and shuts")

func test_reduced_motion_keeps_the_bust_still() -> void:
	var every: float = EraText.portrait_value("blink_every", 0.0)
	var talk: float = EraText.portrait_value("talk_time", 0.0)
	for t: float in [0.0, talk * 1.5, every - 0.01, every * 3.0 - 0.01]:
		assert_eq(EraText.bust_frame(t, true, true), 0)
	GameState.reduce_motion = true
	_era(5)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.set_speaker(KNOWN)
	box._typing = true
	await wait_seconds(0.3)
	assert_eq(box._portrait.frame(), 0)
	assert_eq(box._portrait.modulate.a, 1.0, "no fade in")
	box._typing = false

func test_bust_speaks_while_the_line_types() -> void:
	GameState.reduce_motion = false
	_era(5)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.set_speaker(KNOWN)
	# A long line, so the box keeps typing while the portrait is watched.
	box._label.text = "a ".repeat(400)
	box._visible_chars = 0.0
	box._typing = true
	var seen: Dictionary[int, bool] = {}
	# Real time, not frames: headless frames can be far shorter than one talk step.
	for i: int in 30:
		await wait_seconds(0.03)
		seen[box._portrait.frame()] = true
	box._typing = false
	assert_true(seen.has(2), "the mouth moved")
	assert_true(seen.has(0))

func test_portrait_label_is_translated() -> void:
	Loc.set_language("de")
	assert_eq(Loc.t(EraText.PORTRAIT_LABEL) % KNOWN, "Porträt von Kestra")
	_era(5)
	var box: TextBox = _box()
	await wait_process_frames(2)
	box.set_speaker(KNOWN)
	assert_eq(box._portrait.accessibility_name, "Porträt von Kestra")

# --- Spiral warp ---

func test_warp_by_era() -> void:
	for e: int in range(1, 6):
		var base: String = str(EraFeel.value(e, "warp"))
		assert_eq(EraText.warp(e, base), "spiral" if e == 3 else base, "era %d" % e)

func test_reduced_motion_gets_the_plain_fade() -> void:
	for e: int in range(1, 6):
		assert_eq(EraText.warp(e, str(EraFeel.value(e, "warp")), true), "fade", "era %d" % e)

func test_spiral_closes_and_cleans_up() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var rect: ColorRect = EraWarp.spiral_rect(layer, Vector2(90, 160), Color.BLACK)
	var mat: ShaderMaterial = rect.material
	assert_eq(float(mat.get_shader_parameter("progress")), 0.0, "starts clear")
	assert_eq(float(mat.get_shader_parameter("arms")), EraText.spiral_value("arms", 0.0))
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	rect.free()
	await EraWarp.spiral_close(layer, Vector2(90, 160), Color.BLACK, 0.05)
	await wait_process_frames(2)
	assert_eq(layer.get_child_count(), 0, "the spiral is gone once it closed")

func test_overworld_door_warp_in_era_three() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.reduce_motion = false
	_era(3)
	GameState.flags[EraFeel.SEEN_FLAG % 3] = true
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	await ow._warp_out(false)
	assert_eq(ow._fade.color.a, 1.0, "the spiral ends black")
	GameState.reduce_motion = true
	ow._fade.color.a = 0.0
	await ow._warp_out(false)
	assert_eq(ow._fade.color.a, 1.0, "reduced motion fades")
	await wait_seconds(0.3)
	remove_child(ow)
	MusicDirector.update_world(true, false, 0.0)
