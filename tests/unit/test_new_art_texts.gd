extends GutTest
## Items 576 and 866: every new art reads in German and has a name of its own.
## Art names stay the same in every language (docs/I18N.md), so "German name" means the
## info card around the name is German; the name itself must not clash with anything else.

func after_each() -> void:
	Loc.set_language("en")

func test_every_new_art_exists() -> void:
	for art: String in BalanceSim.NEW_ARTS:
		assert_not_null(Database.move(art), art)

func test_every_effect_gets_a_line_on_the_info_card() -> void:
	Loc.set_language("en")
	for art: String in BalanceSim.NEW_ARTS:
		var mv: MoveData = Database.move(art)
		var text: String = CommandMenu.move_info(mv)
		var flags: int = int(mv.priority > 0) + int(mv.is_area()) + int(mv.overcharge) \
			+ int(mv.cooldown > 0) + int(mv.ignore_daze) + int(mv.ignore_stages)
		# name, element/kind, accuracy/Energy, flags, one line per effect, "(tap to close)"
		assert_eq(text.split("\n").size(), 4 + flags + mv.effects.size(), art + ":\n" + text)

func test_info_card_is_german_apart_from_names() -> void:
	for art: String in BalanceSim.NEW_ARTS:
		var mv: MoveData = Database.move(art)
		Loc.set_language("en")
		var en: PackedStringArray = CommandMenu.move_info(mv).split("\n")
		Loc.set_language("de")
		var de: PackedStringArray = CommandMenu.move_info(mv).split("\n")
		assert_eq(de.size(), en.size(), art)
		assert_eq(de[0], art, "the name stays as it is")
		for i: int in range(1, mini(en.size(), de.size())):
			assert_false(de[i].contains("%d") or de[i].contains("%s") or de[i].contains("%%"), "%s line %d not filled in: %s" % [art, i, de[i]])
			if i == 1 and not mv.is_damaging():
				continue  # "Tide, Status" is the same in German
			assert_ne(de[i], en[i], "%s line %d untranslated: %s" % [art, i, en[i]])

func test_format_keys_keep_double_percent() -> void:
	Loc.set_language("de")
	var line: String = Loc.t("Accuracy %d%%, %d Energy") % [90, 3]
	assert_eq(line, "Genauigkeit 90%, 3 Energie")

func test_names_clash_with_nothing() -> void:
	var taken: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		taken[sd.species_name.to_lower()] = "Spirling"
	for it: Dictionary in Database.items.values():
		taken[str(it.get("name", "")).to_lower()] = "item"
	var art_names: Dictionary = {}
	for mv: MoveData in Database.moves.values():
		var key: String = mv.move_name.to_lower()
		assert_false(art_names.has(key), "two arts named " + mv.move_name)
		art_names[key] = true
	for art: String in BalanceSim.NEW_ARTS:
		var key: String = art.to_lower()
		assert_false(taken.has(key), "%s is also a %s" % [art, taken.get(key, "")])
		for e: int in Elements.COLORS:
			assert_ne(key, Elements.element_name(e).to_lower(), art + " is an element name")
