extends GutTest
## Shop clarity (Ali, 12 Nov 2026: "mach die shop items etwas klarer was der inhalt ist"): every
## offer says exactly what is inside, built from its grants, in English and German.

var _state: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)
	Billing.state = {}

func after_each() -> void:
	Billing.state = _state
	Loc.set_language("en")

## Amounts straight from the raw grants, counted without ShopCatalog.contents().
func _raw_amounts(o: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for g: Dictionary in o.grants:
		var key: String = str(g.t) + ":" + str(g.get("id", g.get("species", "")))
		var n: int = int(g.get("days", 0)) if str(g.t) == "pass" else (1 if str(g.t) in ["unlock", "spirling"] else int(g.get("n", 1)))
		out[key] = int(out.get(key, 0)) + n
	return out

func test_every_offer_has_contents_in_english_and_german() -> void:
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for o: Dictionary in ShopCatalog.offers():
			var line: String = ShopCatalog.contents_line(o)
			assert_false(line.strip_edges().is_empty(), "%s %s: contents line" % [lang, o.id])
			assert_false("rg_" in line or "gift_card_" in line, "%s %s: every name resolves: %s" % [lang, o.id, line])
			assert_false(ShopCatalog.repeat_line(o).is_empty(), "%s %s: says if it can be bought again" % [lang, o.id])
			var d: String = ShopMenu.detail_text(o)
			assert_string_contains(d, Loc.t("Contents:"), "%s %s" % [lang, o.id])
			for l: String in ShopCatalog.grant_lines(o):
				assert_string_contains(d, l, "%s %s: detail view lists every part" % [lang, o.id])
			if str(o.store_type) != "subscription":
				assert_true(d.contains(Loc.t("Duration: %s").get_slice("%s", 0)), "%s %s: duration" % [lang, o.id])
				assert_string_contains(d, ShopCatalog.repeat_line(o), "%s %s" % [lang, o.id])

func test_german_contents_are_translated() -> void:
	Loc.set_language("de")
	var d: String = ShopMenu.detail_text(ShopCatalog.offer("rg_starter"))
	for part: String in ["Inhalt:", "300 Rissglas", "5x Ring-Trank", "Dauer:", "Einmal pro Konto."]:
		assert_string_contains(d, part)
	assert_false("Duration" in d or "Contents" in d, d)

func test_listed_amounts_match_the_grants() -> void:
	for o: Dictionary in ShopCatalog.offers():
		var raw: Dictionary = _raw_amounts(o)
		var got: Dictionary = {}
		for e: Dictionary in ShopCatalog.contents(o):
			var key: String = str(e.t) + ":" + (str(e.species) if str(e.t) == "spirling" else str(e.id))
			got[key] = int(got.get(key, 0)) + int(e.n)
			var line: String = ShopCatalog.entry_line(e)
			match str(e.t):
				"rg":
					assert_eq(line, "%d Riftglass" % int(e.n), str(o.id))
				"coins":
					assert_eq(line, "%d coins" % int(e.n), str(o.id))
				_:
					assert_true(line.begins_with("%dx " % ShopCatalog.entry_amount(e)), "%s: %s" % [o.id, line])
		assert_eq(got, raw, "%s: contents add up to the grants" % o.id)

func test_bundles_list_every_part_with_amounts() -> void:
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_battle_supply")),
		["5x Rift Breath", "5x Overcharge Core", "5x Glass Spark"] as Array[String])
	assert_eq(ShopCatalog.contents_line(ShopCatalog.offer("rg_starter")),
		"300 Riftglass, 5x Ring Tonic, 1x Growth Crystal, and 2 more")
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_warden_bundle")),
		["1x Warden Lore", "3x Warden Weakener", "5x Rift Anchor"] as Array[String])
	# 7 + 7 + 5 seal unlocks are the top tier of each seal, not "Seal Set" 19 times.
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_seal_set")),
		["1x Power Seal VII", "1x Guard Seal VII", "1x Pace Seal V"] as Array[String])
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_gift_cards")).size(), 8)
	assert_string_contains(ShopCatalog.grant_lines(ShopCatalog.offer("rg_gift_cards"))[0], "Lantern")
	# A pack of 10 is 10 of the item, not "10x Battle Skip x10".
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_skip_battle")), ["10x Battle Skip"] as Array[String])
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_coins_5000")), ["5000 coins"] as Array[String])

func test_bundle_detail_says_what_each_part_does_and_how_long() -> void:
	var d: String = ShopMenu.detail_text(ShopCatalog.offer("rg_starter"))
	assert_string_contains(d, Database.item("rg_growth_x2").description)
	assert_string_contains(d, "Duration: 20 battles from the moment you use it")
	assert_string_contains(d, "Duration: yours until you spend it")
	assert_string_contains(d, "Once per account.")
	var prism: String = ShopMenu.detail_text(ShopCatalog.offer("rg_rift_pack_1"))
	assert_string_contains(prism, "1x Element Prism of your choice")
	assert_string_contains(prism, "Choose one: Ember Prism")

func test_duration_and_repeat_lines() -> void:
	assert_eq(ShopCatalog.duration_line(ShopCatalog.offer("rg_riftheart")), "Duration: permanent")
	assert_eq(ShopCatalog.duration_line(ShopCatalog.offer("rg_ring_tonic")), "Duration: used up when used")
	assert_eq(ShopCatalog.duration_line(ShopCatalog.offer("rg_lure_scent_1")), "Duration: 100 steps from the moment you use it")
	assert_eq(ShopCatalog.duration_line(ShopCatalog.offer("rg_glass_500")), "Duration: yours until you spend it")
	assert_eq(ShopCatalog.repeat_line(ShopCatalog.offer("rg_ring_tonic")), "Can be bought again any time.")
	assert_eq(ShopCatalog.repeat_line(ShopCatalog.offer("rg_share_band")), "Buy once: it stays unlocked for good.")
	assert_eq(ShopCatalog.repeat_line(ShopCatalog.offer("rg_storage_box")), "Up to 12 times per account.")
	assert_eq(ShopCatalog.repeat_line(ShopCatalog.offer("rg_coins_5000")), "Up to 3 times a week per account.")
	assert_eq(ShopCatalog.repeat_line(ShopCatalog.offer("rg_pass")), "Renews every month until you cancel.")
	assert_string_contains(ShopCatalog.repeat_line(ShopCatalog.offer("rg_riftheart")), "only once")

func test_newest_offers_are_clear_too() -> void:
	for id: String in ["rg_lure_scent_1", "rg_lure_scent_2", "rg_lure_scent_3", "rg_shimmer_scent", "rg_bond_edge_1",
			"rg_bond_edge_2", "rg_bond_edge_3", "rg_bond_retry", "rg_unfurl_spark", "rg_grand_tonic"]:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		var hint: String = ShopCatalog.row_hint(o)
		assert_true(hint.begins_with("1x "), "%s: %s" % [id, hint])
		assert_string_contains(hint, "Duration: ", id)
	assert_eq(ShopCatalog.grant_lines(ShopCatalog.offer("rg_bond_edge_3")), ["1x Bond Head Start III"] as Array[String])

func test_row_shows_short_contents() -> void:
	var hint: String = ShopCatalog.row_hint(ShopCatalog.offer("rg_battle_supply"))
	assert_true(hint.begins_with("5x Rift Breath, 5x Overcharge Core, 5x Glass Spark\n"), hint)
	assert_string_contains(hint, "Can be bought again any time.")

## Coordinator finding: the Bond Seal bonds ancient and one-of-a-kind Spirlings for sure
## (test_legend_quests), so its text no longer says it does not.
func test_bond_seal_text_matches_what_it_does() -> void:
	for text: String in [str(ShopCatalog.offer("rg_bond_seal").desc), str(Database.item("rg_bond_seal").description)]:
		assert_false("Not with" in text, text)
		assert_string_contains(text, "one-of-a-kind")
	Loc.set_language("de")
	assert_string_contains(Loc.t(str(ShopCatalog.offer("rg_bond_seal").desc)), "auch bei uralten und einmaligen")

func test_merchant_card_says_what_you_buy() -> void:
	var card: String = ShopCatalog.merchant_card("tonic", 150)
	for part: String in ["Tonic", "1x Tonic", "Restores 25 Vigor.", "Duration: used up when used", "Can be bought again any time.", "Price: 150 coins"]:
		assert_string_contains(card, part)
	Loc.set_language("de")
	assert_string_contains(ShopCatalog.merchant_card("tonic", 150), "Preis: 150 Münzen")
