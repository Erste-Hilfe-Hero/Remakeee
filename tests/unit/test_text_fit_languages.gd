extends GutTest
## Plan Chimora 100, item 65: every text of the measured screens is laid out in all 14 languages
## and checked against its own box, so the bugs of the UI audit of 2026-11-21 are caught before
## a player sees them:
##   - a one-line text (label or row) wider than its box with no ellipsis (cut off),
##   - a wrapping text that breaks inside a word, inside a Korean word, or leaves a number alone
##     on its own line ("Rangi" / "48"),
##   - a text box that leaves the screen sideways,
##   - six-dot ellipses and untranslated marked battle arts ("^Cinder Dash"),
##   - the title list needing a scroll to reach Settings at 9:16.
## Screens (first version): the title list, the start (pause) menu, the team list, every summary
## page, the settings list and the battle art rows, in Era I (144x256) and Era IV (270x480).
## Problems another plan item owns are listed in tests/unit/text_fit_known.txt with that item:
## they show as pending here and must be removed from the file when fixed (a listed problem
## that no longer happens fails, so the file never goes stale).

const KNOWN_PATH: String = "res://tests/unit/text_fit_known.txt"
const ERAS: Array[int] = [1, 4]
const MAX_FRAMES: int = 200
## A wrapped line that is only a number: "48", "2", "56 (-18)".
const LONE_NUMBER: String = "^[0-9][0-9/%().,+\\-\\s ]*$"

var _keep: Dictionary = {}
var _lone: RegEx = RegEx.create_from_string(LONE_NUMBER)

func before_all() -> void:
	_keep = {"unlocked": EraManager.unlocked_era, "retro": EraManager.retro_filter, "flags": GameState.flags.duplicate(),
		"reduce": GameState.reduce_motion, "settings": SaveManager.settings_path, "billing": Billing.state.duplicate()}
	SaveManager.settings_path = "user://test_text_fit_settings.json"

func after_all() -> void:
	EraManager.unlocked_era = _keep.unlocked
	EraManager.set_retro_filter(_keep.retro)
	GameState.flags = _keep.flags
	GameState.reduce_motion = _keep.reduce
	SaveManager.settings_path = _keep.settings
	Billing.state = _keep.billing
	GameState.in_game = false
	Loc.set_language("en")

## Known problems: "problem text" -> "owner note", from KNOWN_PATH (# starts a comment line,
## a TAB separates the problem from the note).
static func known() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(KNOWN_PATH):
		return out
	for line: String in FileAccess.get_file_as_string(KNOWN_PATH).split("\n"):
		if line.strip_edges().is_empty() or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.split("\t")
		out[parts[0].strip_edges()] = parts[1].strip_edges() if parts.size() > 1 else ""
	return out

# --- The measuring ----------------------------------------------------------------

## The text [param c] shows (translated as the engine translates it).
static func shown_text(c: Control) -> String:
	var t: String = str(c.get("text"))
	return c.atr(t) if c.can_auto_translate() else t

static func _cjk(ch: String) -> bool:
	var u: int = ch.unicode_at(0)
	return (u >= 0x3040 and u <= 0x9FFF) or (u >= 0xAC00 and u <= 0xD7A3) or (u >= 0xFF00 and u <= 0xFFEF)

static func _hangul(ch: String) -> bool:
	var u: int = ch.unicode_at(0)
	return u >= 0xAC00 and u <= 0xD7A3

## The lines [param text] wraps into at [param width] px.
static func wrap_lines(text: String, font: Font, fs: int, width: float) -> PackedStringArray:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var out: PackedStringArray = []
	for para: String in text.split("\n"):
		var rid: RID = ts.create_shaped_text()
		ts.shaped_text_add_string(rid, para, font.get_rids(), fs, {}, TranslationServer.get_locale())
		var br: PackedInt32Array = ts.shaped_text_get_line_breaks(rid, maxf(width, 1.0), 0,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		ts.free_rid(rid)
		if br.is_empty():
			out.append(para)
		for i: int in range(0, br.size(), 2):
			out.append(para.substr(br[i], br[i + 1] - br[i]))
	return out

## What does not fit among the visible texts under [param root], on a screen [param screen].
func problems(root: Node, screen: Rect2, tag: String) -> Array[String]:
	var out: Array[String] = []
	_walk(root, screen, tag, out)
	return out

func _walk(n: Node, screen: Rect2, tag: String, out: Array[String]) -> void:
	for c: Node in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Label or c is Button:
			_check(c as Control, screen, tag, out)
		_walk(c, screen, tag, out)

func _check(c: Control, screen: Rect2, tag: String, out: Array[String]) -> void:
	var text: String = shown_text(c)
	if text.strip_edges().is_empty() or c.size.x <= 0.0 or not c.is_visible_in_tree():
		return
	var shown: String = text.replace(Loc.WORD_JOINER, "")
	var r: Rect2 = c.get_global_rect()
	if r.position.x < screen.position.x - 0.5 or r.end.x > screen.end.x + 0.5:
		out.append("%s: box leaves the screen: %s" % [tag, shown])
	if text.contains("……") or text.contains("......"):
		out.append("%s: six-dot ellipsis: %s" % [tag, shown])
	var font: Font = c.get_theme_font("font")
	var fs: int = c.get_theme_font_size("font_size")
	var sb: StyleBox = c.get_theme_stylebox("normal")
	var room: float = c.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
	if c is Button and (c as Button).icon != null:
		room -= (c as Button).icon.get_width() + c.get_theme_constant("h_separation")
	var wrap: int = int(c.get("autowrap_mode"))
	var overrun: int = int(c.get("text_overrun_behavior"))
	if wrap == TextServer.AUTOWRAP_OFF:
		if overrun != TextServer.OVERRUN_NO_TRIMMING:
			return
		for line: String in text.split("\n"):
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
				out.append("%s: cut off: %s" % [tag, shown])
				return
		return
	var lines: PackedStringArray = wrap_lines(text, font, fs, room)
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if i > 0 and _lone.search(line.replace(Loc.WORD_JOINER, "")) != null and not lines[i - 1].strip_edges().is_empty():
			out.append("%s: number alone on a line (%s): %s" % [tag, line, shown.replace("\n", " / ")])
			return
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
			out.append("%s: wider than its box: %s" % [tag, shown.replace("\n", " / ")])
			return
	# A break inside a word: the line ends in a letter and the next starts with one, with no
	# space between them in the text (CJK other than Korean may break anywhere).
	for para: String in text.split("\n"):
		var at: int = 0
		var plines: PackedStringArray = wrap_lines(para, font, fs, room)
		for i: int in plines.size() - 1:
			at += plines[i].length()
			if at <= 0 or at >= para.length():
				continue
			# A word joiner on either side still means the break fell inside a word.
			var a: String = para[at - 2] if para[at - 1] == Loc.WORD_JOINER and at >= 2 else para[at - 1]
			var b: String = para[at + 1] if para[at] == Loc.WORD_JOINER and at + 1 < para.length() else para[at]
			if a in [" ", "-", Loc.NO_BREAK] or b == " ":
				continue
			if (_hangul(a) and _hangul(b)) or (not _cjk(a) and not _cjk(b) and a.to_upper() != a.to_lower() and b.to_upper() != b.to_lower()):
				out.append("%s: word broken across lines: %s" % [tag, shown.replace("\n", " / ")])
				return

# --- Screens ------------------------------------------------------------------------

func _setup() -> void:
	load("res://tools/era_menu_shots_runner.gd").setup_state()

## A start menu on a screen of exactly the era's phone size (the test window may be larger).
func _menu(era: int) -> PauseMenu:
	var vp := SubViewport.new()
	vp.size = EraManager.RESOLUTION[era]
	add_child_autofree(vp)
	var menu := PauseMenu.new()
	menu.current_map = "fernstair"
	menu.encounter_table = "fernstair"
	vp.add_child(menu)
	return menu

## Runs [param start] on [param menu], measures every list, text page and summary tab it shows
## (all pages of a paged text), then backs out of everything.
func _measure(menu: PauseMenu, start: Callable, tag: String, out: Array[String]) -> void:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await start.call()
		state.done = true
	var seen: int = menu.picks
	runner.call()
	var frames: int = 0
	var pages: int = 0
	var screen: Rect2 = menu.get_viewport_rect()
	while not state.done and frames < MAX_FRAMES:
		await wait_process_frames(1)
		frames += 1
		var summary: EraSummary = menu.get_node_or_null("era_summary") as EraSummary
		var card: Node = menu.get_node_or_null("era_card")
		if summary != null:
			for t: int in summary._tab_row.get_child_count():
				summary.show_tab(t, false)
				await wait_process_frames(3)
				out.append_array(problems(summary, screen, "%s tab %d" % [tag, t]))
			out.append_array(EraMenuKit.fit_problems(menu))
			summary.emit_signal("closed")
		elif card != null:
			card.emit_signal("closed")
		elif menu._info_wait:
			await wait_process_frames(3)
			out.append_array(problems(menu, screen, "%s page %d" % [tag, pages]))
			pages += 1
			menu._page_turn = 1 if pages < 6 else -2
			menu._close_info()
		elif menu.picks > seen and menu.picker.visible:
			await wait_process_frames(3)
			out.append_array(problems(menu, screen, tag))
			for p: String in EraMenuKit.fit_problems(menu, false):
				out.append("%s: %s" % [tag, p])
			seen = menu.picks
			menu.picker.picked.emit(-1)
	if not state.done:
		out.append("%s: did not close" % tag)

func _title(era: int, height: float, tag: String, out: Array[String]) -> void:
	var base: Vector2 = Vector2(EraManager.RESOLUTION[era])
	var stage := Control.new()
	stage.size = Vector2(base.x, height)
	add_child_autofree(stage)
	var host := MenuHost.new()
	stage.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Where TitleScreen puts its list: under the title art (item 66: sized to the screen).
	host.offset_top = EraTitleArt.title_height(base, height, EraMenus.layout(era)) + 4
	await wait_process_frames(1)
	var rows: Array[Dictionary] = []
	for r: String in ["Continue", "New Game", "What's new", "Join our Discord", "Settings"]:
		rows.append({"text": r})
	var run := func() -> void: await host.pick("", rows, false)
	run.call()
	await wait_process_frames(4)
	out.append_array(problems(host, Rect2(stage.global_position, stage.size), tag))
	for b: Button in host.picker.buttons():
		if not host.picker.row_fully_shown(b):
			out.append("%s: title row needs a scroll: %s" % [tag, shown_text(b)])
	host.picker.picked.emit(-1)
	await wait_process_frames(1)
	stage.queue_free()

## The art rows of the battle menu name each art in the player's language, marks and all.
func _arts(tag: String, out: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var me := Spirling.new(Database.species("Kindlop"), 12, rng)
	var foe := Spirling.new(Database.species("Smoldrake"), 12, rng)
	var marked: Array[MoveData] = []
	for id: Variant in Database.moves:
		var mv: MoveData = Database.move(str(id))
		if mv != null and not CommandMenu.art_marks(mv).is_empty() and marked.size() < 4:
			marked.append(mv)
	me.moves.assign(marked)
	var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], true, 1, 1)
	m.start()
	var cm := CommandMenu.new()
	add_child_autofree(cm)
	cm.refresh(m)
	for i: int in marked.size():
		var want: String = CommandMenu.art_marks(marked[i]) + Loc.t(marked[i].move_name)
		var b: Button = cm._move_buttons[i]
		if not b.text.ends_with(want):
			out.append("%s: art row not translated: %s (want %s)" % [tag, b.text, want])
	cm.queue_free()

func test_texts_fit_their_boxes_in_every_language() -> void:
	_setup()
	var found: Array[String] = []
	for era: int in ERAS:
		EraManager.unlocked_era = era
		EraManager.set_retro_filter(0)
		await wait_process_frames(2)
		for code: String in Loc.LANGUAGES:
			GameState.language = code
			Loc.set_language(code)
			var tag: String = "era %d %s" % [era, code]
			var base: Vector2 = Vector2(EraManager.RESOLUTION[era])
			await _title(era, base.y, tag + " title 9:16", found)
			await _title(era, roundf(base.x * 19.5 / 9.0), tag + " title 19.5:9", found)
			var menu := _menu(era)
			await wait_process_frames(1)
			await _measure(menu, menu.run, tag + " pause", found)
			await _measure(menu, menu.run_team, tag + " team", found)
			await _measure(menu, func() -> void: await menu.run_summary(GameState.party[0], true), tag + " summary", found)
			await _measure(menu, menu.run_settings, tag + " settings", found)
			menu.get_parent().queue_free()
			await wait_process_frames(1)
			if era == 1:
				_arts(tag + " arts", found)
	Loc.set_language("en")
	var expected: Dictionary = known()
	var fresh: Array[String] = []
	var seen: Dictionary = {}
	for p: String in found:
		seen[p] = true
		if not expected.has(p) and not p in fresh:
			fresh.append(p)
	for p: String in expected:
		if seen.has(p):
			gut.p("known, owned elsewhere: %s (%s)" % [p, expected[p]])
		else:
			fail_test("listed in %s but no longer happens, remove it: %s" % [KNOWN_PATH, p])
	assert_eq(fresh, [] as Array[String], "texts that do not fit:\n" + "\n".join(fresh))
	if not expected.is_empty():
		pending("%d known problems owned by other plan items (%s)" % [expected.size(), KNOWN_PATH])

func test_the_checker_finds_a_cut_text_and_a_lone_number() -> void:
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)
	Loc.set_language("en")
	var stage := Control.new()
	stage.size = Vector2(144, 256)
	stage.theme = UITheme.get_theme()
	add_child_autofree(stage)
	var cut := Label.new()
	cut.text = "A label much too long for forty pixels"
	cut.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cut.clip_text = true
	cut.size = Vector2(40, 12)
	stage.add_child(cut)
	var lone := Label.new()
	lone.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lone.text = "Wzrost do nast. Rangi 48"
	lone.position = Vector2(0, 20)
	# Room for everything but the number.
	var w: float = UITheme.font().get_string_size("Wzrost do nast. Rangi", HORIZONTAL_ALIGNMENT_LEFT, -1, PixelFont.BASE_SIZE).x + 5
	lone.size = Vector2(w, 30)
	stage.add_child(lone)
	var glued := Label.new()
	glued.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	glued.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glued.text = Loc.glue_last("Wzrost do nast. Rangi 48")
	glued.position = Vector2(0, 60)
	glued.size = Vector2(w, 30)
	stage.add_child(glued)
	await wait_process_frames(1)
	var p: Array[String] = problems(stage, Rect2(Vector2.ZERO, stage.size), "t")
	assert_true(p.any(func(s: String) -> bool: return s.begins_with("t: cut off: A label")), str(p))
	assert_true(p.any(func(s: String) -> bool: return s.begins_with("t: number alone")), str(p) + " " + str(wrap_lines(lone.text, lone.get_theme_font("font"), lone.get_theme_font_size("font_size"), lone.size.x)))
	assert_eq(p.size(), 2, "the glued label wraps whole: " + str(p))

func test_korean_words_stay_whole() -> void:
	Loc.set_language("ko")
	var t: String = Loc.t("Save and to title")
	assert_true(t.contains(Loc.WORD_JOINER), "Korean syllables carry word joiners: " + t)
	var words: PackedStringArray = t.replace(Loc.WORD_JOINER, "").split(" ", false)
	var text: String = " ".join([t, t, t])
	for l: String in wrap_lines(text, UITheme.font(), PixelFont.BASE_SIZE, 60):
		for w: String in l.replace(Loc.WORD_JOINER, "").split(" ", false):
			assert_has(words, w, "line \"%s\" holds whole words only" % l)
	Loc.set_language("en")
