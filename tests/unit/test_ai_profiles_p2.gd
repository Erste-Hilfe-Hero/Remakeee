extends GutTest
## Plan area 2 (docs/plan5000/02_kampf.md, items 616-619, 621-624, 626, 628): the P2
## personalities, their mottos and battle lines, the Wayfarer assignments and the tag partner.

func before_all() -> void:
	Database.load_all()

func _duel(foe_moves: Array[String], ai: int = 2, player: String = "Mossling") -> BattleModel:
	var me: Spirling = BattleFixtures.make(player, 20, ["Bowl Over"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Shalebat", 20, foe_moves)
	return BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, ai)

func test_p2_profiles_have_their_numbers() -> void:
	var all: Dictionary = BattleAI.profiles()
	assert_eq(float(all.field_keeper.field_w), 2.0)
	assert_eq(float(all.tactician.swap_below), 0.7)
	assert_eq(int(all.tactician.focus_fire), 1)
	assert_eq(float(all.apprentice.second_best), 0.3)
	assert_eq(float(all.enduring.heal_below), 0.6)
	assert_eq(int(all.enduring.rest_below), 4)
	assert_eq(DataValidator.validate().size(), 0)

func test_field_keeper_renews_its_field_at_one_turn_left() -> void:
	var m: BattleModel = _duel(["Spark Call", "Arc Bolt"] as Array[String])
	m.set_field("static_veil")
	m.field_turns = 1
	assert_eq(m.ai.score_move(m, 1, 0), 0.0, "balanced sees no use in the field it has")
	m.ai.set_profile("field_keeper")
	assert_gt(m.ai.score_move(m, 1, 0), 0.0, "the field keeper lays it again")
	m.field_turns = 3
	assert_eq(m.ai.score_move(m, 1, 0), 0.0, "not while turns are left")

func test_tactician_rests_for_the_big_art() -> void:
	var m: BattleModel = _duel(["Draft Needle", "Cairn Crash"] as Array[String], 2, "Kindlop")
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 5
	assert_eq(m.ai.choose(m, 1).kind, BattleAction.Kind.MOVE, "balanced takes the small hit")
	m.ai.set_profile("tactician")
	assert_eq(m.ai.choose(m, 1).kind, BattleAction.Kind.REST, "the tactician saves up")
	foe.energy = 7
	var a: BattleAction = m.ai.choose(m, 1)
	assert_eq(a.kind, BattleAction.Kind.MOVE)
	assert_eq(a.move_index, 1)

func _second_picks(level: int) -> int:
	var m: BattleModel = _duel(["Draft Needle", "Pebble Toss", "Grit Jab"] as Array[String], level)
	m.ai.set_profile("apprentice")
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 10
	var balanced := BattleAI.new(level)
	var best: int = balanced.choose(m, 1).move_index
	var off: int = 0
	for i: int in 200:
		if m.ai.choose(m, 1).move_index != best:
			off += 1
	return off

func test_apprentice_slips_about_a_third_of_the_time() -> void:
	var off: int = _second_picks(2)
	assert_between(off, 40, 80, "about 30% of 200 picks")

func test_rift_born_apprentice_never_slips() -> void:
	assert_eq(_second_picks(3), 0)

func test_enduring_weighs_draining_arts() -> void:
	var m: BattleModel = _duel(["Night Siphon"] as Array[String])
	var plain: float = m.ai.score_move(m, 1, 0)
	m.ai.set_profile("enduring")
	assert_gt(m.ai.score_move(m, 1, 0), plain)

func test_every_profile_but_balanced_has_short_lines() -> void:
	for id: String in BattleAI.profiles():
		var ai := BattleAI.new(1, id)
		for kind: String in ["motto", "own_fall", "foe_fall", "last"]:
			var text: String = ai.line(kind)
			if id == "balanced":
				assert_eq(text, "", "balanced stays quiet")
				continue
			assert_ne(text, "", "%s has a %s line" % [id, kind])
			assert_lte(text.length(), 40, "%s %s" % [id, kind])

func test_motto_at_start_and_fall_lines_once() -> void:
	var me: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String])
	var a: Spirling = BattleFixtures.make("Zippit", 3, ["Crackle Bite"] as Array[String])
	var b: Spirling = BattleFixtures.make("Zippit", 3, ["Crackle Bite"] as Array[String])
	var c: Spirling = BattleFixtures.make("Zippit", 3, ["Crackle Bite"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [a, b, c] as Array[Spirling], false, 7, 1)
	m.trainer_name = "Wanderer Lio"
	m.ai.set_profile("hothead")
	var ev: Array[BattleEvent] = m.start()
	var motto: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.BATTLE_LINE)
	assert_not_null(motto)
	assert_eq(motto.describe(), "Wanderer Lio: Never backs down, never swaps.")
	var kinds: Array[String] = []
	m.event_emitted.connect(func(e: BattleEvent) -> void:
		if e.type == BattleEvent.Type.BATTLE_LINE:
			kinds.append(str(e.data.kind)))
	var turns: int = 0
	while not m.is_finished() and turns < 30:
		me.energy = Spirling.MAX_ENERGY
		m.submit_turn(BattleAction.make_move(0, 0), null)
		turns += 1
	assert_eq(kinds, ["own_fall", "last"] as Array[String], "each line once, the last one for the last Spirling")

func test_wayfarers_have_their_profiles() -> void:
	var want: Dictionary = {"crowcrest/lio": "hothead", "crowcrest/bram": "wall", "murk_hollow/delve": "spoiler",
		"saltmarsh/neve": "field_keeper", "tide_rift/mystic": "tactician", "cinder_rift/acolyte_b": "apprentice",
		"cinder_rift/acolyte_a": "hothead", "saltmarsh/kestra_tag": "enduring", "crowcrest/kestra": "tactician"}
	for key: String in want:
		var parts: PackedStringArray = key.split("/")
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % parts[0]))
		var found: bool = false
		for n: Dictionary in (d as Dictionary).npcs:
			if str(n.get("id", "")) == parts[1]:
				found = true
				assert_eq(str(n.get("profile", "")), str(want[key]), key)
				if parts[1] == "kestra_tag":
					assert_eq(str(n.partner.get("profile", "")), "tactician", "Kestra fights beside you as the tactician")
		assert_true(found, key)

func test_tag_partner_goes_for_the_players_target() -> void:
	var me: Spirling = BattleFixtures.make("Calderox", 30, ["Cinder Nip"] as Array[String])
	var ally: Spirling = BattleFixtures.make("Zippit", 30, ["Crackle Bite"] as Array[String])
	var f1: Spirling = BattleFixtures.make("Mossling", 30, ["Bowl Over"] as Array[String])
	var f2: Spirling = BattleFixtures.make("Mossling", 30, ["Bowl Over"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [f1, f2] as Array[Spirling], false, 7, 1)
	m.front_size = [1, 2]
	m.set_partner("Cartographer Kestra", [ally] as Array[Spirling], 1, 1, "tactician")
	m.start()
	assert_eq(m.partner_ai.profile_id, "tactician")
	for aim: int in [0, 1]:
		var acts: Array[BattleAction] = [BattleAction.make_move(0, 0, 0, aim)]
		assert_eq(m._player_aim(acts), aim)
		m.partner_ai.ally_target = aim
		var pick: BattleAction = m.partner_ai.choose(m, 0, 1)
		assert_eq(pick.target_slot, aim, "the partner hits the same foe")
