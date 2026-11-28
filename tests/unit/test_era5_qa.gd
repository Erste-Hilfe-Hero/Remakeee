extends GutTest
## Era V (Quivermoor) QA pass for 1.3.2: the finale card pages its lines instead of cutting off
## "The End" on a 16:9 phone, and Japanese talk (no spaces) pages in the text box.

const LANGS: Array[String] = ["en", "de", "fr", "ru", "ja", "it", "pl"]

var _era: int
var _filter: int
var _reduce: bool

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_era = EraManager.unlocked_era
	_filter = EraManager.retro_filter
	_reduce = GameState.reduce_motion
	GameState.reduce_motion = false

func after_each() -> void:
	Loc.set_language("en")
	EraManager.unlocked_era = _era
	EraManager.set_retro_filter(_filter)
	GameState.reduce_motion = _reduce

func _set_era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

# --- finale card -------------------------------------------------------------------------

func test_pages_group_lines_that_fit() -> void:
	assert_eq(EraFinaleCard.page_ranges([10.0, 10.0, 10.0] as Array[float], 25.0, 3.0), [Vector2i(0, 2), Vector2i(2, 3)])
	assert_eq(EraFinaleCard.page_ranges([10.0, 10.0] as Array[float], 100.0, 3.0), [Vector2i(0, 2)], "one page when all fit")
	assert_eq(EraFinaleCard.page_ranges([50.0, 10.0] as Array[float], 20.0, 3.0), [Vector2i(0, 1), Vector2i(1, 2)], "a tall line still gets a page")

## Phone screens: 1080x1920 (16:9) gives Era V a 270x480 view, 1080x2400 gives 270x600, and
## 720x1280 at Era I/II gives 144x256 (ScreenFit).
func test_every_finale_line_shows_on_a_phone() -> void:
	for setup: Array in [[5, Vector2(270, 480)], [5, Vector2(270, 600)], [4, Vector2(270, 480)], [1, Vector2(144, 256)]]:
		var e: int = int(setup[0])
		var sz: Vector2 = setup[1]
		_set_era(e)
		for lang: String in LANGS:
			Loc.set_language(lang)
			var c := EraFinaleCard.new()
			c.era = e
			c.manual = true
			add_child_autofree(c)
			c.stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.stage.size = sz
			c._layout()
			var where: String = "era %d %s %s" % [e, lang, sz]
			var k: int = EraFinaleCard.ui_scale(sz.x)
			var pr: Rect2 = c.panel_rect()
			var font: Font = c.stage.get_theme_default_font()
			var all: Array[String] = EraFinaleCard.lines(e)
			var next: int = 0
			for r: Vector2i in c.pages:
				assert_eq(r.x, next, "%s: pages follow each other" % where)
				next = r.y
				var y: float = 0.0
				for i: int in range(r.x, r.y):
					y += font.get_multiline_string_size(all[i], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x - 12.0 * k, PixelFont.BASE_SIZE * k).y
					assert_lte(y, pr.size.y - 8.0 * k, "%s: '%s' fits its page" % [where, all[i]])
					y += EraFinaleCard.LINE_SPACE * k
			assert_eq(next, all.size(), "%s: every line is on a page" % where)
			c.page = c.pages.size() - 1
			assert_eq(c.page_lines()[-1], all[-1], "%s: the closing word is on the last page" % where)

func test_era_five_card_turns_the_page_before_it_closes() -> void:
	_set_era(5)
	Loc.set_language("de")
	var c := EraFinaleCard.new()
	c.era = 5
	c.manual = true
	add_child_autofree(c)
	c.stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.stage.size = Vector2(270, 480)
	c._layout()
	watch_signals(c)
	assert_gt(c.pages.size(), 1, "German needs two pages at 270x480")
	c.press()
	assert_eq(c.page, 0)
	assert_gte(c.t, c.page_time(), "the first press shows the whole page")
	c.press()
	assert_eq(c.page, 1, "the next press turns the page")
	assert_eq(c.t, 0.0, "the new page brings its lines in")
	assert_false(c.is_closed())
	while not c.is_closed():
		c.press()
	assert_eq(c.page, c.pages.size() - 1, "closes only from the last page")
	assert_signal_emit_count(c, "finished", 1)

# --- text box ----------------------------------------------------------------------------

func _strings(v: Variant, out: Array[String]) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x: Variant in v:
			_strings(x, out)
	elif v is Dictionary:
		for key: Variant in v:
			if str(key) in ["lines", "text", "after_flag", "variants", "choices", "label"] or v[key] is Array:
				_strings(v[key], out)

## Lines the label really draws for [param page] (its word-smart wrap).
func _drawn_lines(page: String, width: float, font: Font, size: int) -> int:
	var p := TextParagraph.new()
	p.add_string(page, font, size)
	p.width = width
	p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return p.get_line_count()

func test_long_japanese_line_breaks_without_spaces() -> void:
	var font: Font = UITheme.font()
	var line: String = "いかだが夫を乗せたまま流れていったの。あたしは手をふった。あの人も手をふった。結婚していちばんいい日だった。"
	var pages: Array[String] = TextBox.split_lines(line, 120.0, font, 16, TextBox.MAX_LINES)
	assert_gt(pages.size(), 1, "pages even without a space")
	assert_eq("".join(pages).replace("\n", ""), line, "no letter lost")
	for page: String in pages:
		for l: String in page.split("\n"):
			assert_lte(font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, 120.0, l)

func test_quivermoor_talk_fits_the_box_in_every_checked_language() -> void:
	_set_era(5)
	var box := TextBox.new()
	box.size = Vector2(270, 60)
	add_child_autofree(box)
	await wait_frames(2)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/quivermoor.json"))
	var lines: Array[String] = []
	_strings(raw, lines)
	assert_gt(lines.size(), 100)
	for lang: String in ["en", "de", "fr", "ru", "ja"]:
		Loc.set_language(lang)
		var lab: Label = box._label
		var font: Font = lab.get_theme_font("font")
		var fs: int = lab.get_theme_font_size("font_size")
		var w: float = box._text_width()
		var over: Array[String] = []
		for line: String in lines:
			var parts: PackedStringArray = Dialogue.split_speaker(Loc.t(line))
			for page: String in TextBox.split_lines(parts[1], w, font, fs, TextBox.MAX_LINES):
				if _drawn_lines(page, w, font, fs) > TextBox.MAX_LINES:
					over.append(page.left(40))
		assert_eq(over, [] as Array[String], "%s: pages longer than %d lines" % [lang, TextBox.MAX_LINES])

# --- the finale card after a warp --------------------------------------------------------

func _host() -> Node:
	var g := GDScript.new()
	g.source_code = "extends Node\nvar busy: bool = false\n"
	g.reload()
	var n: Node = g.new()
	add_child_autofree(n)
	return n

func _card_of(host: Node) -> EraFinaleCard:
	for c: Node in host.get_children():
		if c is EraFinaleCard:
			return c
	return null

## Leaving the Bloom Rift after the last Warden: the warp holds busy while the map fades in and
## the card is owed. Before 1.3.2 the card kept that busy and gave it back after the warp had
## ended, so the Wayfarer could not move again.
func test_card_after_a_warp_gives_the_wayfarer_back() -> void:
	var saved: Dictionary = GameState.flags.duplicate()
	GameState.flags.erase(EraMoments.CARD_FLAG % 5)
	GameState.set_flag(EraMoments.finale_flag(5))
	var host: Node = _host()
	host.set("busy", true)
	EraFinaleCard.play_if_owed(host)
	await wait_frames(2)
	assert_null(_card_of(host), "the card waits for the warp")
	host.set("busy", false)
	var card: EraFinaleCard = null
	for i: int in 30:
		await wait_frames(1)
		card = _card_of(host)
		if card != null:
			break
	assert_not_null(card, "the card shows once the warp is over")
	assert_true(bool(host.get("busy")), "the card holds the map while it shows")
	while card != null and not card.is_closed():
		card.press()
	await wait_frames(2)
	assert_false(bool(host.get("busy")), "the Wayfarer walks again after the card")
	assert_true(GameState.has_flag(EraMoments.CARD_FLAG % 5), "shown once")
	GameState.flags = saved
