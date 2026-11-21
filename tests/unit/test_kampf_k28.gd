extends GutTest
## KAMPF_PLAN_1000 items 241, 260, 261, 263, 279: gift marks on the plate once a gift worked, the
## Turncoat Seed, an AI that only reads shown gifts, and the Storm Lantern gift.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _events(m: BattleModel) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	m.event_emitted.connect(func(ev: BattleEvent) -> void: out.append(ev))
	return out

func _unfolded(lvl: int = 30) -> Spirling:
	for sd: SpirlingData in Database.spirlings.values():
		if Database.earlier_form(sd) != null:
			var s := Spirling.new(sd, lvl)
			s.kinship = int(TraitKit.data().min_kinship)
			return s
	return null

# --- 241, 263: the plate shows a gift once it worked ---------------------------------------------

func test_plate_shows_gift_marks_only_after_they_worked() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 20)
	s.bonus_trait = "sentinel"
	var st := InfoStrip.new()
	add_child_autofree(st)
	st.set_spirling(s)
	assert_true(st.gifts.is_empty(), "nothing shown before it worked")
	assert_false(st.screen_reader_text().contains("Sentinel"))
	TraitKit.mark_seen(s, "sentinel")
	TraitKit.mark_seen(s, "sentinel")
	assert_eq(TraitKit.seen_ids(s), ["sentinel"] as Array[String], "each gift once")
	st.set_spirling(s)
	assert_eq(st.gifts, ["sentinel"] as Array[String], "a swap back in keeps the mark")
	assert_true(st.screen_reader_text().contains("Sentinel"))
	assert_true(st.tooltip_text.contains("Sentinel"))
	TraitKit.forget_seen(s)
	assert_true(TraitKit.seen_ids(s).is_empty(), "a new battle starts unknown")

func test_gift_icons_follow_the_gift_keys() -> void:
	assert_eq(TraitKit.icon_of("sentinel"), "swift")
	assert_eq(TraitKit.icon_of("prism_skin"), "guard")
	assert_eq(TraitKit.icon_of("storm_lantern"), "aim")
	assert_eq(TraitKit.icon_of("no_such_gift"), "default")
	for icon: String in ["guard", "mend", "swift", "spark", "strike", "aim", "default"]:
		var rows: Array = TraitKit.icon_rows(icon)
		assert_eq(rows.size(), InfoStrip.GIFT_ICON, icon)
		for r: Variant in rows:
			assert_eq(str(r).length(), InfoStrip.GIFT_ICON, icon)
	assert_eq(InfoStrip.gift_marks_width(0), 0.0)
	assert_eq(InfoStrip.gift_marks_width(2), float(2 * (InfoStrip.GIFT_ICON + 1) + 1))

# --- 261: the AI reads only gifts that showed themselves -----------------------------------------

func test_known_ids_and_immunity_need_a_reveal() -> void:
	var me: Spirling = BattleFixtures.make("Mirkmole", 15)
	var foe: Spirling = BattleFixtures.make("Wickit", 15)
	foe.bonus_trait = "sentinel"
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling], false)
	assert_true(BattleRules.is_immune(foe, "drowse"), "Wickit sleeps lightly")
	assert_false(TraitKit.known_immune(m, foe, "drowse"), "hidden until it worked")
	assert_true(TraitKit.known_ids(m, foe).is_empty())
	TraitKit.show(m, BattleModel.Side.FOE, 0, "sentinel")
	assert_eq(TraitKit.known_ids(m, foe), ["sentinel"] as Array[String])
	m.reveal_trait(BattleModel.Side.FOE, 0)
	assert_true(foe.gift_id() in TraitKit.known_ids(m, foe))
	assert_true(TraitKit.known_immune(m, foe, "drowse"))
	assert_false(TraitKit.known_immune(m, foe, "daze"), "known, but not immune to that")

# --- 260: Turncoat Seed ---------------------------------------------------------------------------

func test_turncoat_seed_swaps_the_gift_at_any_ring() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 5)
	var own: String = s.gift_id()
	var hidden: String = HiddenGifts.gift_id(s.data)
	assert_ne(own, hidden)
	assert_false(HiddenGifts.can_wake(s), "too low and no tip: the informant would say no")
	GameState.add_item("turncoat_seed", 2)
	var msg: String = GameState.use_item_outside_battle("turncoat_seed", s)
	assert_false(msg.is_empty())
	assert_eq(s.gift_id(), hidden)
	assert_true(HiddenGifts.revealed(s.data.line_id), "the line's gift is known now")
	assert_eq(GameState.item_count("turncoat_seed"), 1, "used up")
	GameState.use_item_outside_battle("turncoat_seed", s)
	assert_eq(s.gift_id(), own, "and back again")
	assert_eq(GameState.item_count("turncoat_seed"), 0)

func test_turncoat_seed_does_nothing_with_two_gift_slots() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 5)
	s.gift_slot = true
	GameState.add_item("turncoat_seed")
	assert_eq(GameState.use_item_outside_battle("turncoat_seed", s), "")
	assert_eq(GameState.item_count("turncoat_seed"), 1, "kept")

func test_turncoat_seed_is_sold_and_translated() -> void:
	var it: Dictionary = Database.item("turncoat_seed")
	assert_true(bool(it.get("gift_swap", false)))
	assert_gt(int(it.get("price", 0)), 0)
	assert_true(FileAccess.get_file_as_string("res://data/dialogue/thornridge.json").contains("turncoat_seed"), "Thornridge sells it")
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	assert_true(de.has(str(it.name)))
	assert_true(de.has(str(it.description)))
	assert_true(de.has("%s turns its coat: its gift is now %s."))

# --- 279: Storm Lantern -----------------------------------------------------------------------------

func test_storm_lantern_gift_needs_the_lantern() -> void:
	var s: Spirling = _unfolded()
	assert_false("storm_lantern" in TraitKit.bonus_options(s))
	GameState.add_item("storm_lantern")
	assert_true("storm_lantern" in TraitKit.bonus_options(s), "the carrier of the Storm Lantern may teach it")
	assert_true(TraitKit.learn_bonus(s, "storm_lantern"))
	assert_true(TraitKit.steady_aim(s))
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	assert_true(de.has(str(TraitKit.info("storm_lantern").text)))

func test_storm_lantern_keeps_aim_in_fog_and_daze() -> void:
	var plain: Spirling = BattleFixtures.make("Mossling", 20)
	var lit: Spirling = BattleFixtures.make("Mossling", 20)
	lit.bonus_trait = "storm_lantern"
	var mv: MoveData = BattleFixtures.move(Elements.E.BLOOM, 40)
	mv.accuracy = 0.9
	var m: BattleModel = BattleFixtures.model([lit] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], true)
	m.sight_mult = 0.8
	plain.status = "daze"
	lit.status = "daze"
	assert_almost_eq(m.hit_chance(plain, mv), 0.9 * StatusRules.acc_mult("daze") * 0.8, 0.0001)
	assert_almost_eq(m.hit_chance(lit, mv), 0.9, 0.0001)
	var ev: Array[BattleEvent] = _events(m)
	TraitKit.on_aim(m, BattleModel.Side.PLAYER, 0, lit, mv)
	var shown: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.TRAIT)
	assert_not_null(shown, "the lantern shows itself when it mattered")
	assert_eq(str(shown.data.get("trait", "")), "storm_lantern")

func test_storm_lantern_stays_quiet_in_clear_air() -> void:
	var lit: Spirling = BattleFixtures.make("Mossling", 20)
	lit.bonus_trait = "storm_lantern"
	var mv: MoveData = BattleFixtures.move(Elements.E.BLOOM, 40)
	var m: BattleModel = BattleFixtures.model([lit] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], true)
	m.sight_mult = 1.0
	var ev: Array[BattleEvent] = _events(m)
	TraitKit.on_aim(m, BattleModel.Side.PLAYER, 0, lit, mv)
	assert_null(BattleFixtures.first_of(ev, BattleEvent.Type.TRAIT))
