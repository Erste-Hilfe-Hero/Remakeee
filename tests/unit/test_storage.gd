extends GutTest
## Storage boxes, favourites, multi-move, release, team presets and keepsakes
## (plan area 1, items 314-315, 355-357, 375-382).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _mk(species: String = "Kindlop", lvl: int = 5) -> Spirling:
	var s := Spirling.new(Database.species(species), lvl)
	s.origin_map = "fernstair"
	s.met_ring = lvl
	s.met_day = 20400
	return s

func _fill_storage(n: int) -> void:
	for i: int in n:
		GameState._store(_mk("Wickit"), true)

func test_eight_named_boxes_of_thirty_and_room_for_shop_boxes() -> void:
	assert_eq(GameState.storage_boxes.size(), 8)
	assert_eq(GameState.storage_capacity(), 240)
	assert_eq(GameState.storage_boxes[0].name, "Box 1")
	GameState.storage_box_bonus = 2
	GameState.ensure_boxes()
	assert_eq(GameState.storage_boxes.size(), 10)
	assert_eq(GameState.storage_capacity(), 300)

func test_boxes_fill_in_order_and_rename_and_recolor() -> void:
	_fill_storage(31)
	assert_eq(GameState.box_fill()[0], 30)
	assert_eq(GameState.box_fill()[1], 1)
	GameState.rename_box(1, "  Ember friends with a very long name  ")
	assert_eq(GameState.storage_boxes[1].name, "Ember friends wi")
	GameState.rename_box(1, "   ")
	assert_eq(GameState.storage_boxes[1].name, "Ember friends wi", "a blank name keeps the old one")
	var before: String = GameState.storage_boxes[1].color
	assert_ne(GameState.recolor_box(1), before)

func test_old_flat_storage_is_spread_over_boxes_on_load() -> void:
	_fill_storage(35)
	var d: Dictionary = GameState.to_dict()
	d.erase("storage_boxes")
	for sd: Dictionary in d.storage:
		sd.erase("box")
	GameState.from_dict(d)
	assert_eq(GameState.storage_boxes.size(), 8)
	assert_eq(GameState.box_fill()[0], 30)
	assert_eq(GameState.box_fill()[1], 5)

func test_boxes_names_presets_and_favourites_survive_a_save() -> void:
	GameState.party.append(_mk())
	_fill_storage(2)
	GameState.rename_box(0, "Cozy")
	GameState.storage[1].favorite = true
	GameState.save_preset(0, "Main")
	GameState.storage_box_bonus = 1
	GameState.from_dict(GameState.to_dict())
	assert_eq(GameState.storage_boxes[0].name, "Cozy")
	assert_eq(GameState.storage_boxes.size(), 9)
	assert_true(GameState.storage[1].favorite)
	assert_eq(GameState.team_presets[0].name, "Main")

func test_damaged_box_data_loads_safely() -> void:
	var d: Dictionary = GameState.to_dict()
	d["storage_boxes"] = [3, {"name": 7, "color": "neon"}, "x"]
	d["storage_box_bonus"] = "lots"
	d["team_presets"] = [{"uids": "nope"}, 5, {"name": "A", "uids": [1, 2, 3, 4, 5, 6, 7]}]
	GameState.from_dict(d)
	assert_eq(GameState.storage_boxes.size(), 8)
	assert_eq(GameState.storage_boxes[0].color, "ink", "unknown colour falls back")
	assert_eq(GameState.storage_box_bonus, 0)
	assert_eq(GameState.team_presets.size(), 1)
	assert_eq((GameState.team_presets[0].uids as Array).size(), GameState.MAX_PARTY + 1, "room for the sixth team slot")

func test_multi_move_takes_at_most_ten_and_skips_favourites() -> void:
	_fill_storage(14)
	GameState.storage[0].favorite = true
	var all: Array[int] = []
	for i: int in 14:
		all.append(i)
	assert_eq(GameState.move_to_box(all, 3), GameState.MULTI_MOVE_MAX)
	assert_eq(GameState.storage[0].box, 0, "the favourite stayed")
	assert_eq(GameState.box_fill()[3], 10)
	assert_eq(GameState.move_to_box([0] as Array[int], 3, true), 1, "one by one a favourite can move")
	assert_eq(GameState.move_to_box([1] as Array[int], 99), 0)

func test_multi_move_never_overfills_a_box() -> void:
	_fill_storage(35)
	var idx: Array[int] = []
	for i: int in range(30, 35):
		idx.append(i)
	assert_eq(GameState.move_to_box(idx, 0), 0, "box 1 is full")

func test_release_sends_it_home_and_never_a_favourite() -> void:
	_fill_storage(2)
	GameState.storage[0].favorite = true
	GameState.storage[1].held = "bark_wrap"
	assert_eq(GameState.release(0), "", "favourites are never released")
	assert_eq(GameState.storage.size(), 2)
	var line: String = GameState.release(1)
	assert_string_contains(line, Spirling.place_name("fernstair"))
	assert_eq(GameState.storage.size(), 1)
	assert_eq(GameState.item_count("bark_wrap"), 1, "its keepsake comes back to the satchel")
	assert_eq(GameState.release(5), "")

func test_release_only_from_storage_so_the_team_keeps_its_healthy_member() -> void:
	var lead: Spirling = _mk()
	GameState.party.append(lead)
	assert_eq(GameState.release(0), "", "nothing in storage, nothing to release")
	assert_eq(GameState.party.size(), 1)

func test_deposit_never_removes_the_last_healthy_member_and_respects_capacity() -> void:
	var a: Spirling = _mk()
	var b: Spirling = _mk("Wickit")
	b.hp = 0
	GameState.party.append_array([a, b])
	assert_false(GameState.deposit(0), "b is fainted, a is the last healthy one")
	assert_true(GameState.deposit(1))
	GameState.party.append(_mk("Wickit"))
	_fill_storage(GameState.storage_capacity() - GameState.storage.size())
	assert_false(GameState.deposit(1), "storage is full")

func test_deposit_can_keep_the_keepsake() -> void:
	GameState.party.append_array([_mk(), _mk("Wickit")])
	GameState.party[1].held = "iron_burr"
	assert_true(GameState.deposit(1, true))
	assert_eq(GameState.storage[0].held, "")
	assert_eq(GameState.item_count("iron_burr"), 1)
	GameState.party.append(_mk("Wickit"))
	GameState.party[1].held = "spark_coil"
	assert_true(GameState.deposit(1, false))
	assert_eq(GameState.storage[1].held, "spark_coil")

func test_presets_save_and_load_with_one_tap() -> void:
	var a: Spirling = _mk()
	var b: Spirling = _mk("Wickit")
	var c: Spirling = _mk("Zippit")
	GameState.party.append_array([a, b])
	GameState._store(c)
	assert_true(GameState.save_preset(0))
	GameState.party.assign([c])
	GameState.storage.clear()
	GameState._store(a)
	GameState._store(b)
	assert_true(GameState.load_preset(0))
	assert_eq(GameState.party, [a, b] as Array[Spirling])
	assert_true(GameState.storage.has(c))
	assert_false(GameState.storage.has(a))

func test_preset_never_leaves_the_team_without_a_healthy_member() -> void:
	var a: Spirling = _mk()
	var b: Spirling = _mk("Wickit")
	GameState.party.append_array([a, b])
	GameState.save_preset(1)
	GameState.party.assign([b])
	GameState._store(a)
	a.hp = 0
	b.hp = 0
	# a rests in storage and comes out restored, so the team is fine.
	assert_true(GameState.load_preset(1))
	GameState.party.assign([a, b])
	GameState.storage.clear()
	for s: Spirling in GameState.party:
		s.hp = 0
	assert_false(GameState.load_preset(1), "a team of fainted Spirlings does not travel")
	assert_false(GameState.load_preset(4), "empty preset")
	assert_eq(GameState.party.size(), 2)

func test_released_members_drop_out_of_presets() -> void:
	var a: Spirling = _mk()
	var b: Spirling = _mk("Wickit")
	GameState.party.append_array([a, b])
	GameState.save_preset(0)
	GameState.deposit(1)
	GameState.release(0)
	assert_eq(GameState.preset_team(0), [a] as Array[Spirling])

func test_every_kind_has_a_keepsake_hint_that_can_be_held() -> void:
	for sname: String in Database.spirlings:
		var sd: SpirlingData = Database.spirlings[sname]
		assert_true(Database.item(sd.keepsake_hint).has("held"), sname)

func test_storage_card_shows_ring_temperament_keepsake_origin_and_sparks() -> void:
	var s: Spirling = _mk("Kindlop", 9)
	s.held = ""
	var card: String = MenuHost.storage_card(s)
	assert_string_contains(card, "Ring 9")
	assert_string_contains(card, "Temperament: %s. %s" % [s.temperament().label, s.temperament().text])
	assert_string_contains(card, "Keepsake: none")
	assert_string_contains(card, "Suits it: %s" % Database.item(s.data.keepsake_hint).name)
	assert_string_contains(card, "Met in %s at Ring 9" % Spirling.place_name("fernstair"))
	assert_string_contains(card, "Sparks: HP ")
	s.held = s.data.keepsake_hint
	assert_eq(MenuHost.keepsake_suggestion(s), "", "no suggestion when it already holds it")
	assert_string_contains(MenuHost.storage_line(s), "+")
	s.favorite = true
	assert_true(MenuHost.storage_line(s).begins_with("* "))

func test_team_summary_shows_the_temperament_sentence() -> void:
	var s: Spirling = _mk()
	assert_string_contains(MenuHost.summary(s), s.temperament().text)

## Bug plan (Lager, item 1338): a six-member preset saved with the sixth team slot lost its
## sixth member on the next load, and without the slot a preset must not overfill the team.
func test_six_member_preset_survives_a_save_and_respects_the_slot() -> void:
	var billing_before: Dictionary = Billing.state
	Billing.state = {"unlocks": {"team_slot_6": 1}}
	for i: int in 6:
		GameState.party.append(_mk())
	assert_true(GameState.save_preset(0, "Six"))
	GameState.from_dict(GameState.to_dict())
	assert_eq((GameState.team_presets[0].uids as Array).size(), 6)
	assert_true(GameState.load_preset(0))
	assert_eq(GameState.party.size(), 6)
	Billing.state = {}
	assert_true(GameState.load_preset(0))
	assert_eq(GameState.party.size(), GameState.MAX_PARTY, "without the slot the sixth stays out")
	Billing.state = billing_before
