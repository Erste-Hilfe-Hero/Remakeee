extends GutTest
## KAMPF_PLAN_1000, areas "Elemente und Matchups" (items 85, 86, 87, 97, 101, 103, 104, 115, 116)
## and "Techniken" (items 123-128, 131-136, 147-152): TechniqueRules, its arts and keepsakes.

const T := BattleEvent.Type
const ARTS: Array[String] = ["Hold Fast", "Shove Off", "Grudge Return", "Kindred Balm", "Rank and File",
	"Shake Loose", "Rolling Drum", "Late Reply", "Opening Gambit", "Pebble Hail", "Rift Hush", "Bright Lure",
	"Close Ranks", "Ember Afterglow", "Borrowed Stance", "Still Point", "Ground Burst", "Dye Bath", "Ward Circle"]

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	Loc.set_language("en")

func _duel(mine: Array[Spirling], theirs: Array[Spirling], wild: bool = false, seed_value: int = 11) -> BattleModel:
	var m := BattleModel.new(mine, theirs, wild, seed_value, 0)
	m.items_allowed = false
	m.start()
	return m

func _doubles(mine: Array[Spirling], theirs: Array[Spirling], seed_value: int = 5) -> BattleModel:
	var m := BattleModel.new(mine, theirs, false, seed_value, 0)
	m.front_size = [2, 2]
	m.items_allowed = false
	m.start()
	return m

func _ctx(m: BattleModel, mv: MoveData, user_slot: int = 0, target_slot: int = 0) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.model = m
	ctx.user_side = 0
	ctx.target_side = 1
	ctx.user_slot = user_slot
	ctx.target_slot = target_slot
	ctx.user = m.active_spirling(0, user_slot)
	ctx.target = m.active_spirling(1, target_slot)
	ctx.move = mv
	return ctx

func _apply(m: BattleModel, art: String, user_slot: int = 0, damage: int = 0) -> EffectContext:
	var mv: MoveData = Database.move(art)
	var ctx: EffectContext = _ctx(m, mv, user_slot)
	ctx.damage_dealt = damage
	for fx: Dictionary in mv.effects:
		EffectRegistry.get_effect(StringName(fx.id)).apply(ctx, fx)
	return ctx

func _lines(m: BattleModel) -> Array[String]:
	var out: Array[String] = []
	for e: BattleEvent in m._events:
		if e.type == T.TECHNIQUE:
			out.append(e.describe())
	return out

func _mon(species: String, art: String = "Bowl Over", level: int = 30) -> Spirling:
	var s: Spirling = BattleFixtures.make(species, level, [art])
	s.energy = Spirling.MAX_ENERGY
	return s

# --- data: every art is real, sold, and explains itself in both languages --------------------

func test_every_art_is_taught_by_a_crystal_hesper_sells() -> void:
	var shop: String = str(Dialogue.get_entry("lighthouse/hesper").get("action", ""))
	assert_true(shop.begins_with("shop "), shop)
	for art: String in ARTS:
		assert_not_null(Database.move(art), art)
		var crystal: String = ""
		for id: String in Database.items:
			if str(Database.items[id].get("teaches", "")) == art:
				crystal = id
		assert_false(crystal.is_empty(), "a crystal teaches " + art)
		assert_true((" " + shop + " ").contains(" " + crystal + " "), "Hesper sells " + crystal)
	assert_true(shop.contains(" ward_shell"), "and the Ward Shell")

func test_info_card_has_a_line_per_effect_in_english_and_german() -> void:
	for art: String in ARTS:
		var mv: MoveData = Database.move(art)
		Loc.set_language("en")
		var en: PackedStringArray = CommandMenu.move_info(mv).split("\n")
		var flags: int = int(mv.priority > 0) + int(mv.is_area()) + int(mv.overcharge) \
			+ int(mv.cooldown > 0) + int(mv.ignore_daze) + int(mv.ignore_stages)
		assert_eq(en.size(), 4 + flags + mv.effects.size(), art + ":\n" + "\n".join(en))
		Loc.set_language("de")
		var de: PackedStringArray = CommandMenu.move_info(mv).split("\n")
		assert_eq(de.size(), en.size(), art)
		var last: String = de[de.size() - 2]
		assert_ne(last, en[en.size() - 2], art + " effect line is German")
		assert_false(last.contains("%d") or last.contains("%s") or last.contains("%%"), art + ": " + last)

# --- item 101: no element pair makes a hit vanish ---------------------------------------------

func test_no_matchup_is_ever_zero_and_the_floor_is_a_quarter() -> void:
	for atk: int in Elements.E.values():
		for d1: int in Elements.E.values():
			for d2: int in Elements.E.values():
				var mult: float = Elements.multiplier(atk, [d1] if d1 == d2 else [d1, d2])
				assert_gte(mult, 0.25, "%s into %s/%s" % [atk, d1, d2])

# --- item 97: Ember on a Rooted foe ------------------------------------------------------------

func test_ember_burns_the_roots_off_and_sets_the_foe_alight() -> void:
	var me: Spirling = _mon("Kindlop", "Cinder Nip", 20)
	var foe: Spirling = _mon("Talusk", "Bowl Over", 40)
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling], true)
	foe.status = "root"
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var r: BattleEvent = BattleFixtures.first_of(ev, T.REACTION)
	assert_not_null(r, "the reaction fires")
	assert_eq(foe.status, "scorch", "the roots are gone, the fire stays")

# --- items 85, 116: Resonance and echo -------------------------------------------------------

func test_resonance_needs_an_ally_of_a_shared_element() -> void:
	var a: Spirling = _mon("Kindlop")
	var b: Spirling = _mon("Calderox")
	var c: Spirling = _mon("Puddlet")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Mossling"), _mon("Zippit")] as Array[Spirling])
	assert_almost_eq(TechniqueRules.resonance_mult(m, 0, a), TechniqueRules.RESONANCE_MULT, 0.0001)
	var m2: BattleModel = _doubles([a, c] as Array[Spirling], [_mon("Mossling"), _mon("Zippit")] as Array[Spirling])
	assert_eq(TechniqueRules.resonance_mult(m2, 0, a), 1.0, "Ember and Tide share nothing")
	var m3: BattleModel = _duel([a] as Array[Spirling], [_mon("Mossling")] as Array[Spirling])
	assert_eq(TechniqueRules.resonance_mult(m3, 0, a), 1.0, "no ally in a duel")

func test_echo_gives_the_second_ally_energy_for_the_same_element() -> void:
	var a: Spirling = _mon("Kindlop", "Cinder Nip")
	var b: Spirling = _mon("Puddlet", "Cinder Nip")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Mossling"), _mon("Zippit")] as Array[Spirling])
	var mv: MoveData = Database.move("Cinder Nip")
	assert_false(TechniqueRules.echoes(m, 0, b, mv), "nobody used Ember yet")
	TechniqueRules.note_move(m, 0, a, mv, 0)
	assert_true(TechniqueRules.echoes(m, 0, b, mv))
	assert_false(TechniqueRules.echoes(m, 0, a, mv), "not for its own art")
	assert_false(TechniqueRules.echoes(m, 1, m.active_spirling(1), mv), "not for the other side")
	b.energy = 3
	TechniqueRules.note_move(m, 0, b, mv, 1)
	assert_eq(b.energy, 3 + TechniqueRules.ECHO_ENERGY, "the echo pays Energy back")
	m.turn += 1
	assert_false(TechniqueRules.echoes(m, 0, b, mv), "only within the same turn")

# --- items 87, 103, 104, 115: softer strong hits -----------------------------------------------

func _hit(m: BattleModel, art: String) -> float:
	return TechniqueRules.hit_mult(m, 0, 0, m.active_spirling(0), 1, 0, m.active_spirling(1), Database.move(art))

func test_ward_shell_halves_one_strong_hit_then_cracks() -> void:
	var foe: Spirling = _mon("Mossling")
	foe.held = "ward_shell"
	var m: BattleModel = _duel([_mon("Kindlop", "Cinder Nip")] as Array[Spirling], [foe] as Array[Spirling])
	assert_eq(DamageCalc.effectiveness(foe, Database.move("Cinder Nip")), 2.0)
	assert_almost_eq(_hit(m, "Cinder Nip"), TechniqueRules.GUARD_ITEM_MULT, 0.0001)
	assert_eq(foe.held, "", "the shell is spent")
	assert_eq(_lines(m).size(), 1)
	assert_almost_eq(_hit(m, "Cinder Nip"), 1.0, 0.0001, "only once")

func test_ward_shell_ignores_neutral_hits() -> void:
	var foe: Spirling = _mon("Zippit")
	foe.held = "ward_shell"
	var m: BattleModel = _duel([_mon("Kindlop", "Cinder Nip")] as Array[Spirling], [foe] as Array[Spirling])
	assert_almost_eq(_hit(m, "Cinder Nip"), 1.0, 0.0001)
	assert_eq(foe.held, "ward_shell")

func test_prism_skin_turns_a_double_hit_into_one_and_a_half() -> void:
	var cullet: SpirlingData = null
	for sd: SpirlingData in Database.spirlings.values():
		if sd.line_id == "cullet":
			cullet = sd
			break
	assert_not_null(cullet)
	assert_eq(HiddenGifts.gift_id(cullet), "prism_skin")
	var foe := Spirling.new(cullet, 30)
	foe.hidden_gift = true
	var me: Spirling = _mon("Puddlet")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var mv := MoveData.new()
	mv.move_name = "Test Art"
	mv.power = 40
	for e: int in Elements.E.values():
		mv.element = e
		var eff: float = DamageCalc.effectiveness(foe, mv)
		var got: float = TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, mv)
		assert_almost_eq(got, TechniqueRules.PRISM_SKIN_MULT if eff >= 2.0 else 1.0, 0.0001, Elements.element_name(e))

func test_countercurrent_resists_the_element_that_hit_it_last() -> void:
	var foe := Spirling.new(Database.species("Paddlewisp"), 30)
	foe.hidden_gift = true
	assert_eq(foe.gift_id(), "countercurrent")
	var me: Spirling = _mon("Kindlop", "Cinder Nip")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var ember: MoveData = Database.move("Cinder Nip")
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, ember), 1.0, 0.0001, "first Ember hit")
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, ember), TechniqueRules.COUNTERCURRENT_MULT, 0.0001, "second Ember hit")

func test_ward_circle_softens_strong_hits_on_the_whole_side_for_three_turns() -> void:
	var m: BattleModel = _duel([_mon("Wickit")] as Array[Spirling], [_mon("Kindlop", "Cinder Nip")] as Array[Spirling])
	var st: Dictionary = TechniqueRules.state(m)
	(st.ward as Array)[1] = m.turn + TechniqueRules.WARD_TURNS
	var foe_hit: MoveData = Database.move("Cinder Nip")
	var me: Spirling = m.active_spirling(0)
	var target := _mon("Mossling")
	var mult: float = TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, target, foe_hit)
	assert_almost_eq(mult, TechniqueRules.WARD_MULT, 0.0001)
	m.turn += TechniqueRules.WARD_TURNS
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, target, foe_hit), 1.0, 0.0001, "gone after 3 turns")

func test_ward_circle_art_sets_the_ward_on_its_own_side() -> void:
	var m: BattleModel = _duel([_mon("Wickit")] as Array[Spirling], [_mon("Mossling")] as Array[Spirling])
	_apply(m, "Ward Circle")
	assert_eq(int((TechniqueRules.state(m).ward as Array)[0]), m.turn + TechniqueRules.WARD_TURNS)

# --- item 86: Dye Bath --------------------------------------------------------------------------

func test_dye_bath_shifts_the_element_for_three_turns() -> void:
	var foe: Spirling = _mon("Kindlop")
	var m: BattleModel = _duel([_mon("Puddlet")] as Array[Spirling], [foe] as Array[Spirling])
	_apply(m, "Dye Bath")
	assert_eq(foe.elements(), [Elements.E.TIDE] as Array[int])
	# The end of the turn it was used in counts one down, then 3 full turns.
	for i: int in TechniqueRules.SHIFT_TURNS + 1:
		assert_eq(foe.elements(), [Elements.E.TIDE] as Array[int], "turn %d" % i)
		foe.tick_timers()
	assert_eq(foe.elements(), foe.data.elements, "back to Ember")
	foe.element_shift = Elements.E.TIDE
	foe.end_battle()
	assert_eq(foe.element_shift, -1, "never leaves the battle")

# --- items 123-128 -----------------------------------------------------------------------------

func test_hold_fast_blocks_the_foe_and_fails_twice_in_a_row() -> void:
	var me: Spirling = _mon("Talusk", "Hold Fast")
	var foe: Spirling = _mon("Kindlop", "Cinder Nip")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var full: int = me.hp
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
	assert_eq(me.hp, full, "the hit glanced off")
	assert_true(_lines(m).has("%s braces and the art glances off!" % me.display_name()), str(_lines(m)))
	me.energy = Spirling.MAX_ENERGY
	foe.energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
	assert_lt(me.hp, full, "the second brace in a row fails")
	assert_true(_lines(m).has("%s can't brace twice in a row!" % me.display_name()))
	assert_gt(ev.size(), 0)

func test_hold_fast_lets_the_users_own_buffs_through() -> void:
	var mv: MoveData = Database.move("Hold Fast")
	assert_false(TechniqueRules.reaches_foe(mv))
	assert_true(TechniqueRules.reaches_foe(Database.move("Cinder Nip")))
	assert_true(TechniqueRules.reaches_foe(Database.move("Dye Bath")))

func test_shove_off_sends_the_target_to_its_bench_in_wayfarer_duels_only() -> void:
	var foe: Spirling = _mon("Mossling")
	var bench: Spirling = _mon("Zippit")
	var m: BattleModel = _duel([_mon("Zephlet", "Shove Off")] as Array[Spirling], [foe, bench] as Array[Spirling])
	_apply(m, "Shove Off", 0, 10)
	assert_eq(m.active_spirling(1), bench, "the bench Spirling steps in")
	var wild: BattleModel = _duel([_mon("Zephlet", "Shove Off")] as Array[Spirling], [_mon("Mossling"), _mon("Zippit")] as Array[Spirling], true)
	var first: Spirling = wild.active_spirling(1)
	_apply(wild, "Shove Off", 0, 10)
	assert_eq(wild.active_spirling(1), first, "never in wild battles")

func test_shove_off_does_not_move_a_rooted_target() -> void:
	var foe: Spirling = _mon("Mossling")
	foe.status = "root"
	var m: BattleModel = _duel([_mon("Zephlet", "Shove Off")] as Array[Spirling], [foe, _mon("Zippit")] as Array[Spirling])
	_apply(m, "Shove Off", 0, 10)
	assert_eq(m.active_spirling(1), foe)

func test_grudge_return_pays_back_physical_damage() -> void:
	var me: Spirling = _mon("Mirkmole", "Grudge Return", 40)
	var foe: Spirling = _mon("Talusk", "Bowl Over", 40)
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var foe_full: int = foe.hp
	var my_full: int = me.hp
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
	var taken: int = my_full - me.hp
	assert_gt(taken, 0, "Bowl Over landed first")
	assert_eq(foe_full - foe.hp, int(taken * TechniqueRules.COUNTER_MULT), "x1.5 back")

func test_grudge_return_with_nothing_taken_does_nothing() -> void:
	var m: BattleModel = _duel([_mon("Mirkmole", "Grudge Return")] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	var foe: Spirling = m.active_spirling(1)
	var full: int = foe.hp
	_apply(m, "Grudge Return")
	assert_eq(foe.hp, full)

func test_kindred_balm_heals_the_most_hurt_ally() -> void:
	var a: Spirling = _mon("Mossling", "Kindred Balm")
	var b: Spirling = _mon("Kindlop")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Zippit"), _mon("Talusk")] as Array[Spirling])
	a.hp = a.max_hp() / 2
	b.hp = b.max_hp() / 4
	_apply(m, "Kindred Balm")
	assert_eq(b.hp, b.max_hp() / 4 + roundi(b.max_hp() * 0.33), "the ally, not the user")
	assert_eq(a.hp, a.max_hp() / 2)

func test_rank_and_file_raises_guard_on_both_slots() -> void:
	var a: Spirling = _mon("Talusk", "Rank and File")
	var b: Spirling = _mon("Kindlop")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Zippit"), _mon("Mossling")] as Array[Spirling])
	_apply(m, "Rank and File")
	assert_eq(a.stage("def"), 1)
	assert_eq(b.stage("def"), 1)
	assert_eq(m.active_spirling(1).stage("def"), 0, "not the foe")

# --- items 131-136 -----------------------------------------------------------------------------

func test_shake_loose_clears_only_drops() -> void:
	var m: BattleModel = _duel([_mon("Zephlet", "Shake Loose")] as Array[Spirling], [_mon("Mossling")] as Array[Spirling])
	var me: Spirling = m.active_spirling(0)
	me.stages["atk"] = -2
	me.stages["spd"] = 2
	_apply(m, "Shake Loose")
	assert_eq(me.stage("atk"), 0)
	assert_eq(me.stage("spd"), 2, "raised stats stay")

func test_rolling_drum_builds_up_on_each_use_in_a_row() -> void:
	var me: Spirling = _mon("Zippit", "Rolling Drum")
	var m: BattleModel = _duel([me] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	var mv: MoveData = Database.move("Rolling Drum")
	var seen: Array[int] = []
	for i: int in 5:
		TechniqueRules.note_move(m, 0, me, mv)
		seen.append(TechniqueRules.streak(m, me, mv))
		m.turn += 1
	assert_eq(seen, [0, 1, 2, 3, 3] as Array[int])
	m.turn += 1
	TechniqueRules.note_move(m, 0, me, mv)
	assert_eq(TechniqueRules.streak(m, me, mv), 0, "a skipped turn breaks the roll")

func test_late_reply_and_opening_gambit_read_who_acted_first() -> void:
	var me: Spirling = _mon("Mirkmole", "Late Reply")
	var foe: Spirling = _mon("Talusk")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var late: MoveData = Database.move("Late Reply")
	var gambit: MoveData = Database.move("Opening Gambit")
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, late), 1.0, 0.0001)
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, gambit), TechniqueRules.FIRST_STRIKE_MULT, 0.0001)
	var a := BattleAction.make_rest(1)
	a.actor = foe
	TechniqueRules.note_acted(m, a)
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, late), TechniqueRules.PAYBACK_MULT, 0.0001)
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, gambit), 1.0, 0.0001)

func test_pebble_hail_strikes_two_to_four_times_and_says_so() -> void:
	var counts: Dictionary = {}
	for seed_value: int in 40:
		var me: Spirling = _mon("Talusk", "Pebble Hail")
		var foe: Spirling = _mon("Zippit", "Bowl Over", 50)
		var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling], true, seed_value)
		var mult: float = TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, Database.move("Pebble Hail"))
		var hits: int = TechniqueRules.hits_of(m, me)
		assert_between(hits, TechniqueRules.HITS_MIN, TechniqueRules.HITS_MAX)
		assert_almost_eq(mult, float(hits) / TechniqueRules.HITS_MEAN, 0.0001)
		counts[hits] = true
	assert_eq(counts.size(), 3, "2, 3 and 4 hits all happen")

func test_rift_hush_ends_the_field_but_not_a_locked_one() -> void:
	var m: BattleModel = _duel([_mon("Wickit", "Rift Hush")] as Array[Spirling], [_mon("Mossling")] as Array[Spirling])
	m.set_field("ash_storm", 5)
	_apply(m, "Rift Hush")
	assert_eq(m.field, "")
	m.set_field("ash_storm", 5)
	m.field_lock = 2
	_apply(m, "Rift Hush")
	assert_eq(m.field, "ash_storm", "a locked field holds")

# --- items 147-152 -----------------------------------------------------------------------------

func test_bright_lure_draws_single_target_arts_for_three_turns() -> void:
	var a: Spirling = _mon("Wickit", "Bright Lure")
	var b: Spirling = _mon("Kindlop")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Zippit", "Cinder Nip"), _mon("Mossling")] as Array[Spirling])
	var hit: MoveData = Database.move("Cinder Nip")
	assert_eq(m.move_targets(1, hit, 1), [1] as Array[int])
	_apply(m, "Bright Lure")
	assert_eq(m.move_targets(1, hit, 1), [0] as Array[int], "drawn to the lure")
	assert_eq(m.move_targets(0, hit, 1), [1] as Array[int], "its own side aims freely")
	m.turn += TechniqueRules.LURE_TURNS
	assert_eq(m.move_targets(1, hit, 1), [1] as Array[int], "over after 3 turns")

func test_close_ranks_halves_the_hit_on_the_most_hurt_ally() -> void:
	var a: Spirling = _mon("Talusk", "Close Ranks")
	var b: Spirling = _mon("Kindlop")
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Zippit", "Cinder Nip"), _mon("Mossling")] as Array[Spirling])
	b.hp = b.max_hp() / 2
	_apply(m, "Close Ranks")
	var foe: Spirling = m.active_spirling(1)
	var mv: MoveData = Database.move("Bowl Over")
	assert_almost_eq(TechniqueRules.hit_mult(m, 1, 0, foe, 0, 1, b, mv) / TechniqueRules.resonance_mult(m, 1, foe), TechniqueRules.SHOULDER_MULT, 0.0001)
	assert_almost_eq(TechniqueRules.hit_mult(m, 1, 0, foe, 0, 0, a, mv) / TechniqueRules.resonance_mult(m, 1, foe), 1.0, 0.0001, "the user is not covered")

func test_ember_afterglow_burns_for_three_more_turns() -> void:
	var foe: Spirling = _mon("Talusk", "Bowl Over", 50)
	var m: BattleModel = _duel([_mon("Kindlop", "Ember Afterglow")] as Array[Spirling], [foe] as Array[Spirling])
	_apply(m, "Ember Afterglow", 0, 5)
	assert_eq(m.delayed_hits.size(), TechniqueRules.AFTERGLOW_TURNS)
	var full: int = foe.hp
	for i: int in TechniqueRules.AFTERGLOW_TURNS:
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(full - foe.hp, 3 * (foe.max_hp() / TechniqueRules.AFTERGLOW_DIV) - _regen(m, foe, 3))
	assert_eq(m.delayed_hits.size(), 0)

func _regen(_m: BattleModel, s: Spirling, turns: int) -> int:
	var div: float = BattleRules.add_key(s, "regen_div")
	return 0 if div <= 0.0 else turns * maxi(1, int(s.max_hp() / div))

func test_ember_afterglow_needs_a_hit() -> void:
	var m: BattleModel = _duel([_mon("Kindlop", "Ember Afterglow")] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	_apply(m, "Ember Afterglow", 0, 0)
	assert_eq(m.delayed_hits.size(), 0)

func test_borrowed_stance_copies_the_foes_last_stage_change() -> void:
	var m: BattleModel = _duel([_mon("Hushkin", "Borrowed Stance")] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	_apply(m, "Borrowed Stance")
	assert_eq(_lines(m).size(), 1, "nothing to mirror yet")
	m.change_stage(1, "atk", 2)
	_apply(m, "Borrowed Stance")
	assert_eq(m.active_spirling(0).stage("atk"), 2)

func test_still_point_heals_half_then_dozes_one_turn() -> void:
	var me: Spirling = _mon("Puddlet", "Still Point")
	var m: BattleModel = _duel([me] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	me.hp = 1
	_apply(m, "Still Point")
	assert_eq(me.hp, 1 + int(me.max_hp() * 0.5))
	assert_eq(me.status, "drowse")
	assert_eq(me.status_turns, 1)

func test_ground_burst_hits_the_ally_too() -> void:
	var a: Spirling = _mon("Talusk", "Ground Burst", 40)
	a.moves[0] = a.moves[0].duplicate()
	a.moves[0].accuracy = 1.0
	var b: Spirling = _mon("Kindlop", "Bowl Over", 40)
	var m: BattleModel = _doubles([a, b] as Array[Spirling], [_mon("Zippit"), _mon("Mossling")] as Array[Spirling])
	var full: int = b.hp
	var ev: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(0, 0, 0, 0), BattleAction.make_rest(0, 1),
		BattleAction.make_rest(1, 0), BattleAction.make_rest(1, 1)] as Array[BattleAction])
	assert_lt(b.hp, full, "the ally is hit")
	var damaged: int = 0
	for e: BattleEvent in ev:
		if e.type == T.DAMAGE and str(e.data.get("move", "")) == "Ground Burst":
			damaged += 1
	assert_eq(damaged, 3, "two foes and one ally, the ally once")
