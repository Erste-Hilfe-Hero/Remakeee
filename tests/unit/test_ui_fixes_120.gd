extends GutTest
## Battle and shop texts from the 1.2.0 store shots, in all 14 languages: the four battle
## commands fit their row (Era II/III), an art's name stays clear of its cost (Era IV/V), the
## elements and the Growth bar speak the language, the Starter Pack says "Once per account."
## once and fits its box, and every euro amount of a language is written one way.

const SCREENS: Dictionary = {1: Vector2(144, 256), 2: Vector2(144, 256), 3: Vector2(180, 320), 4: Vector2(270, 480), 5: Vector2(270, 480)}
## Info box of the Era IV menus (270x480, as in the store shots): text width and height.
const INFO_W: float = 248.0
const INFO_H: float = 458.0
## Longest label in front of the Growth bar (the English word is 35 px).
const XP_LABEL_MAX: float = 40.0

var _keep: Array = []

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter, Billing.prices.duplicate()]

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.set_retro_filter(_keep[1])
	Billing.prices = _keep[2]
	Loc.set_language("en")

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func _width(text: String) -> float:
	return PixelFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

func _model() -> BattleModel:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 14)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.start()
	return m

func test_battle_commands_fit_their_buttons_in_every_language() -> void:
	var m: BattleModel = _model()
	for era: int in [1, 2, 3, 4, 5]:
		_era(era)
		for lang: String in Loc.LANGUAGES:
			Loc.set_language(lang)
			for words: Array in [["Bond", "Leave"], ["Oath", "Leave"], ["Bond", "Restart"], ["Oath", "Restart"], ["Oath", "Give up"]]:
				var menu := CommandMenu.new()
				menu.theme = EraBattleHud.theme(era)
				add_child_autofree(menu)
				menu.size = Vector2((SCREENS[era] as Vector2).x, 0)
				menu.refresh(m, 0)
				menu._bond.text = CommandMenu.command_label(words[0])
				menu._fit_command(menu._bond)
				menu._run.text = CommandMenu.command_label(words[1])
				menu._fit_command(menu._run)
				await wait_process_frames(2)
				for b: Button in [menu._swap, menu._item, menu._bond, menu._run]:
					var sb: StyleBox = b.get_theme_stylebox("normal")
					var room: float = b.size.x - sb.content_margin_left - sb.content_margin_right
					var w: float = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
					assert_lte(w, room, "era %d %s: \"%s\" fits its button (%d of %d px)" % [era, lang, b.text, int(w), int(room)])
				menu.queue_free()

func test_battle_command_words_are_the_short_battle_words() -> void:
	Loc.set_language("fr")
	assert_eq(CommandMenu.command_label("Swap"), "Relais")
	assert_eq(Loc.t("Swap"), "Changer", "the other menus keep the general word")
	Loc.set_language("en")
	for w: String in ["Swap", "Item", "Bond", "Oath", "Leave", "Restart"]:
		assert_eq(CommandMenu.command_label(w), w, "English uses the word itself")

func test_art_names_stay_clear_of_the_cost_in_era_four_and_five() -> void:
	var m: BattleModel = _model()
	for era: int in [2, 4, 5]:
		_era(era)
		for lang: String in ["fr", "it", "pt_BR", "pl", "de", "en"]:
			Loc.set_language(lang)
			var menu := CommandMenu.new()
			menu.theme = EraBattleHud.theme(era)
			add_child_autofree(menu)
			menu.size = Vector2((SCREENS[era] as Vector2).x, 0)
			menu.refresh(m, 0)
			await wait_process_frames(2)
			for i: int in m.active_spirling(BattleModel.Side.PLAYER, 0).moves.size():
				var b: Button = menu._move_buttons[i]
				var cost: Label = menu._move_costs[i]
				var cw: float = cost.get_theme_font("font").get_string_size(cost.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost.get_theme_font_size("font_size")).x
				var sb: StyleBox = b.get_theme_stylebox("normal")
				assert_gte(sb.content_margin_right, cw + 3.0, "era %d %s: the name of %s stops before \"%s\"" % [era, lang, b.text, cost.text])
				assert_true(b.clip_text)
				assert_eq(b.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "a name too long ends in ...")
			menu.queue_free()

func test_a_long_art_name_in_era_four_takes_the_plain_large_font() -> void:
	_era(4)
	Loc.set_language("fr")
	var m: BattleModel = _model()
	var menu := CommandMenu.new()
	menu.theme = EraBattleHud.theme(4)
	add_child_autofree(menu)
	menu.size = Vector2(270, 0)
	menu.refresh(m, 0)
	await wait_process_frames(2)
	var b: Button = menu._move_buttons[0]
	b.text = "Souffle de Cendres de la Grande Faille\n" + Loc.t("Ember")
	menu._fit_art_name(0)
	assert_eq(b.get_theme_font("font"), PixelFont.get_large_font())

func test_element_names_are_translated_wherever_german_translates_them() -> void:
	Loc.set_language("de")
	var named: Array[String] = []
	for e: int in Elements.E.values():
		var n: String = Elements.element_name(e)
		if Loc.t(n) != n:
			named.append(n)
	assert_true("Ember" in named)
	for lang: String in Loc.LANGUAGES:
		if lang == "en":
			continue
		Loc.set_language(lang)
		for n: String in named:
			assert_ne(Loc.t(n), n, "%s: the element %s is translated" % [lang, n])
	for pair: Array in [["it", "Brace"], ["ko", "불씨"], ["zh_TW", "餘燼"]]:
		Loc.set_language(pair[0])
		assert_eq(Loc.t("Ember"), pair[1])

func test_growth_bar_label_is_the_games_own_word_and_fits() -> void:
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var label: String = InfoStrip.xp_label()
		assert_ne(label, "EXP", lang)
		assert_true(Loc.t("Growth").begins_with(label.trim_suffix(".")), "%s: \"%s\" is the word for Growth (%s) or its short form" % [lang, label, Loc.t("Growth")])
		assert_lte(_width(label), XP_LABEL_MAX, "%s: \"%s\" leaves room for the bar" % [lang, label])
		if lang != "en":
			assert_ne(label, "Growth", "%s: translated" % lang)

func test_once_per_account_is_said_once_and_the_starter_pack_fits() -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.set_retro_filter(4)
	var o: Dictionary = ShopCatalog.offer("rg_starter")
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		Billing.prices[str(o.product_id)] = ShopCatalog.format_eur(int(o.eur_cents))
		var d: String = ShopMenu.detail_text(o)
		var rule: String = Loc.t("Once per account.")
		assert_eq(d.count(rule), 1, "%s: \"%s\" once:\n%s" % [lang, rule, d])
		var l := Label.new()
		l.theme = UITheme.get_theme()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", 3)
		l.size = Vector2(INFO_W, 0)
		l.text = Loc.t(d) + "\n\n" + Loc.t(MenuHost.continue_hint())
		add_child_autofree(l)
		await wait_process_frames(1)
		var h: float = l.get_line_count() * (l.get_line_height() + 3)
		assert_lte(h, INFO_H + 3.0, "%s: the Starter Pack fits the info box (%d lines)" % [lang, l.get_line_count()])
	for id: String in ["rg_spirling_velahra", "rg_seal_set"]:
		Loc.set_language("en")
		assert_eq(ShopMenu.detail_text(ShopCatalog.offer(id)).count("Once per account."), 1, id)

func test_a_language_writes_every_euro_amount_one_way() -> void:
	var want: Dictionary = {"en": "€0.99", "de": "0,99 €", "fr": "0,99 €", "es": "0,99 €", "it": "0,99 €", "pt_BR": "€ 0,99",
		"nl": "€ 0,99", "pl": "0,99 €", "tr": "€0,99", "ru": "0,99 €", "ja": "€0.99", "ko": "€0.99", "zh_CN": "€0.99", "zh_TW": "€0.99"}
	var o: Dictionary = ShopCatalog.offer("rg_bond_lure_1")
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		assert_eq(ShopCatalog.format_eur(99), want[lang], lang)
		assert_eq(ShopCatalog.format_eur(1881), str(want[lang]).replace("0,99", "18,81").replace("0.99", "18.81"), lang)
		# As the store writes it on a phone in that language.
		Billing.prices[str(o.product_id)] = want[lang]
		var d: String = ShopMenu.detail_text(o)
		var comma: bool = str(want[lang]).contains(",")
		var other := RegEx.create_from_string("\\d\\.\\d\\d" if comma else "\\d,\\d\\d")
		assert_null(other.search(d), "%s: one price format in the shop line:\n%s" % [lang, d])
		assert_string_contains(d, ShopCatalog.euro_hint(100), lang)
