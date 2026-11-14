extends GutTest
## The Era IV/V item shortcut fits its place in the command column in all 14 languages: the
## empty "Again: -" and the longest battle item with a two-digit count, whose count always shows.

var _keep: Array = []

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter, EraBattleHud.last_item]

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.set_retro_filter(_keep[1])
	EraBattleHud.last_item = _keep[2]
	Loc.set_language("en")

func _model() -> BattleModel:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 14)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.start()
	return m

## The battle item with the widest name in the current language.
func _longest_item(f: Font, fs: int) -> String:
	var best: String = ""
	var bw: float = -1.0
	for id: String in Database.items.keys():
		if not bool(Database.item(id).get("battle", false)):
			continue
		var w: float = f.get_string_size(Loc.t(str(Database.item(id).get("name", id))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > bw:
			bw = w
			best = id
	return best

func _check(menu: CommandMenu, what: String) -> void:
	var b: Button = menu._shortcut
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var room: float = b.size.x - sb.content_margin_left - sb.content_margin_right
	var w: float = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	assert_gt(room, 40.0, "%s: the shortcut has its place" % what)
	assert_lte(w, room, "%s: \"%s\" fits the shortcut (%d of %d px)" % [what, b.text, int(w), int(room)])

func test_the_shortcut_fits_in_every_language() -> void:
	for era: int in [4, 5]:
		EraManager.unlocked_era = EraManager.NEWEST
		EraManager.retro_filter = era
		for lang: String in Loc.LANGUAGES:
			Loc.set_language(lang)
			var m: BattleModel = _model()
			EraBattleHud.last_item = ""
			var menu := CommandMenu.new()
			menu.theme = EraBattleHud.theme(era)
			add_child_autofree(menu)
			menu.size = Vector2(270, 0)
			menu.refresh(m, 0)
			await wait_process_frames(2)
			_check(menu, "era %d %s empty" % [era, lang])
			var id: String = _longest_item(EraBattleHud.font(era), UITheme.FONT_SIZE)
			m.inventory[id] = 99
			EraBattleHud.last_item = id
			menu.refresh(m, 0)
			await wait_process_frames(2)
			_check(menu, "era %d %s %s" % [era, lang, id])
			assert_true(menu._shortcut.text.ends_with(" x99"), "era %d %s: the count always shows (\"%s\")" % [era, lang, menu._shortcut.text])
			assert_eq(menu._shortcut.tooltip_text, Loc.t(str(Database.item(id).get("name", id))), "the whole name stays on the button")
			menu.queue_free()

func test_fit_name_keeps_short_names_and_the_count() -> void:
	var f: Font = PixelFont.get_font()
	var fs: int = UITheme.FONT_SIZE
	assert_eq(CommandMenu.fit_name("Tonic", " x2", f, fs, 200.0), "Tonic x2")
	var t: String = CommandMenu.fit_name("Respiro di Squarcio Profondo", " x99", f, fs, 70.0)
	assert_true(t.ends_with("... x99"), t)
	assert_lte(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 70.0)
	assert_eq(CommandMenu.fit_name("", "Again: -", f, fs, 10.0), "Again: -", "no name: the text stays as it is")

func test_short_word_for_the_empty_shortcut() -> void:
	Loc.set_language("de")
	assert_eq(CommandMenu.command_label("Again: -"), "Erneut: -")
	assert_eq(Loc.t("Again: -"), "Nochmal: -", "the general text stays")
