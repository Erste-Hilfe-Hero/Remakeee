extends GutTest
## Keepsakes in battle (KAMPF_PLAN_1000 281, 298, 304, 307, 318, 319): scripts/battle/KeepsakeKit.gd,
## scripts/ui/KeepsakeIcons.gd, scripts/battle/presenter/KeepsakePop.gd.

var _inv_was: Dictionary
var _party_was: Array[Spirling]
var _reduce_was: bool

func before_each() -> void:
	_inv_was = GameState.inventory.duplicate()
	_party_was = GameState.party.duplicate()
	_reduce_was = GameState.reduce_motion

func after_each() -> void:
	GameState.inventory = _inv_was
	GameState.party = _party_was
	GameState.reduce_motion = _reduce_was

func _mon(held: String = "", species: String = "Mossling") -> Spirling:
	var s := Spirling.new(Database.species(species), 20)
	s.held = held
	return s

func _model(me: Spirling, inv: Dictionary, swap: bool = true) -> BattleModel:
	var m := BattleModel.new([me] as Array[Spirling], [_mon()] as Array[Spirling], true, 7)
	m.inventory = inv
	m.held_swap = swap
	m.start()
	return m

# --- 304 -------------------------------------------------------------------------------------

func test_every_keepsake_has_its_own_icon() -> void:
	var n: int = 0
	Database.load_all()
	for key: Variant in Database.items:
		var id: String = str(key)
		if not BattleRules.is_holdable(id):
			continue
		n += 1
		assert_false(KeepsakeIcons.form(id).is_empty(), "icon for " + id)
		assert_not_null(KeepsakeIcons.texture(id), id)
	assert_gt(n, 40)

func test_icon_shapes_are_7x7_and_all_differ() -> void:
	var seen: Dictionary = {}
	var forms: Dictionary = KeepsakeKit.data().get("forms", {})
	assert_gt(forms.size(), 15)
	for f: String in forms:
		var rows: Array = KeepsakeIcons.rows(f)
		assert_eq(rows.size(), KeepsakeIcons.SIZE, f)
		for r: Variant in rows:
			assert_eq(str(r).length(), KeepsakeIcons.SIZE, f)
		var key: String = "".join(PackedStringArray(rows))
		assert_false(seen.has(key), "%s looks like %s" % [f, seen.get(key, "")])
		seen[key] = f
		# No shape copies an element symbol.
		for el: int in ElementIcons.GLYPHS:
			assert_ne(key, "".join(PackedStringArray(ElementIcons.GLYPHS[el])), f)

func test_icon_colour_follows_the_era() -> void:
	assert_eq(KeepsakeIcons.colour("rg_prism_ember", 1), UITheme.INK)
	assert_eq(KeepsakeIcons.colour("rg_prism_ember", 3), Elements.color(Elements.E.EMBER))
	assert_eq(KeepsakeIcons.colour("kit_cinder_stone", 3), Color("c8502a"))
	assert_null(KeepsakeIcons.texture("tonic"))

# --- 298 -------------------------------------------------------------------------------------

func test_putting_a_keepsake_on_costs_the_turn() -> void:
	var me := _mon("ember_charm")
	var m := _model(me, {"rg_hold_stone": 1})
	var a := BattleAction.make_item(0, "rg_hold_stone", 0)
	assert_true(KeepsakeKit.is_swap(a))
	assert_true(m.is_legal(a))
	assert_eq(KeepsakeKit.swap_ids(m), ["rg_hold_stone"] as Array[String])
	var events: Array[BattleEvent] = m.submit_turn(a, BattleAction.make_rest(1))
	assert_eq(me.held, "rg_hold_stone")
	assert_eq(int(m.inventory.get("ember_charm", 0)), 1, "the old keepsake goes back into the bag")
	assert_false(m.inventory.has("rg_hold_stone"))
	var swapped: bool = false
	for e: BattleEvent in events:
		assert_false(e.type == BattleEvent.Type.MOVE_USED and int(e.data.get("side", -1)) == 0, "no art after the swap")
		if e.type == BattleEvent.Type.HELD_ITEM and str(e.data.get("kind", "")) == "swap":
			swapped = true
			assert_string_contains(e.describe(), "drops its Ember Charm for the Hold Stone")
	assert_true(swapped)

func test_swap_needs_the_real_team_and_the_own_slot() -> void:
	var me := _mon()
	var m := _model(me, {"rg_hold_stone": 1}, false)
	assert_false(m.is_legal(BattleAction.make_item(0, "rg_hold_stone", 0)), "echo copies never swap")
	assert_true(KeepsakeKit.swap_ids(m).is_empty())
	m.held_swap = true
	m.items_allowed = false
	assert_false(m.is_legal(BattleAction.make_item(0, "rg_hold_stone", 0)), "no items, no keepsakes")
	m.items_allowed = true
	assert_true(m.is_legal(BattleAction.make_item(0, "rg_hold_stone", 0)))
	me.held = "rg_hold_stone"
	assert_false(m.is_legal(BattleAction.make_item(0, "rg_hold_stone", 0)), "already holds it")

func test_swap_is_never_in_the_ai_list() -> void:
	var m := _model(_mon(), {"rg_hold_stone": 1})
	for a: BattleAction in m.legal_actions(0):
		assert_false(KeepsakeKit.is_swap(a))

# --- 307 -------------------------------------------------------------------------------------

func test_sets_save_and_survive_a_save_file() -> void:
	var s := _mon("ember_charm")
	KeepsakeKit.save_set(s, 1)
	assert_eq(KeepsakeKit.saved(s, 0), "")
	assert_eq(KeepsakeKit.saved(s, 1), "ember_charm")
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(KeepsakeKit.saved(back, 1), "ember_charm")
	s.held = ""
	KeepsakeKit.save_set(s, 1)
	assert_true(s.held_sets.is_empty(), "an empty last set is dropped")
	assert_false(s.to_dict().has("held_sets"))

func test_team_set_moves_keepsakes_between_spirlings() -> void:
	var a := _mon("ember_charm")
	var b := _mon("rg_hold_stone")
	KeepsakeKit.save_set(a, 0)
	KeepsakeKit.save_set(b, 0)
	# Set 1: the two trade their keepsakes.
	a.held_sets.append("rg_hold_stone")
	b.held_sets.append("ember_charm")
	GameState.party = [a, b] as Array[Spirling]
	GameState.inventory = {}
	assert_eq(KeepsakeKit.wear_team_set(GameState.party, 1), [] as Array[String])
	assert_eq(a.held, "rg_hold_stone")
	assert_eq(b.held, "ember_charm")
	KeepsakeKit.wear_team_set(GameState.party, 0)
	assert_eq(a.held, "ember_charm")
	assert_eq(b.held, "rg_hold_stone")

func test_team_set_says_what_the_bag_lacks() -> void:
	var a := _mon()
	a.held_sets.assign(["kit_pace_feather"])
	GameState.party = [a] as Array[Spirling]
	GameState.inventory = {}
	var lines: Array[String] = KeepsakeKit.wear_team_set([a], 0)
	assert_eq(lines.size(), 1)
	assert_eq(a.held, "")
	GameState.inventory = {"kit_pace_feather": 1}
	assert_true(KeepsakeKit.wear_team_set([a], 0).is_empty())
	assert_eq(a.held, "kit_pace_feather")

# --- 318, 319 --------------------------------------------------------------------------------

func test_cue_picks_the_sound_per_keepsake_event() -> void:
	var me := _mon("rg_hold_stone")
	var m := _model(me, {})
	var guard := BattleEvent.new(BattleEvent.Type.HELD_ITEM, {"side": 0, "slot": 0, "item": "ward_shell", "kind": "guard"})
	assert_eq(KeepsakeKit.cue(guard, m).sound, "keepsake_guard")
	var stir := BattleEvent.new(BattleEvent.Type.HELD_ITEM, {"side": 1, "slot": 0, "item": "kit_pace_feather"})
	assert_eq(KeepsakeKit.cue(stir, m).sound, "keepsake_stir")
	assert_eq(int(KeepsakeKit.cue(stir, m).side), 1)
	assert_eq(KeepsakeKit.cue(BattleEvent.new(BattleEvent.Type.HELD_FRUIT, {"item": "pith_mend"}), m).sound, "keepsake_fruit")
	var endure: Dictionary = KeepsakeKit.cue(BattleEvent.new(BattleEvent.Type.HELD_ENDURE, {"side": 0, "slot": 0}), m)
	assert_eq(endure.sound, "keepsake_endure")
	assert_eq(endure.item, "rg_hold_stone")
	assert_true(KeepsakeKit.cue(BattleEvent.new(BattleEvent.Type.HEAL, {}), m).is_empty())
	for snd: String in KeepsakeKit.SOUNDS:
		assert_true(FileAccess.file_exists(Sound.SFX_DIR % snd), snd)
	for snd: Variant in (KeepsakeKit.data().sounds as Dictionary).values():
		assert_true(str(snd) in KeepsakeKit.SOUNDS, str(snd))

func test_eaten_fruit_names_its_item() -> void:
	var me := _mon("pith_clear")
	var m := _model(me, {})
	me.status = "scorch"
	var seen: Array[String] = []
	m.event_emitted.connect(func(ev: BattleEvent) -> void:
		if ev.type == BattleEvent.Type.HELD_FRUIT:
			seen.append(str(ev.data.get("item", ""))))
	assert_true(m.eat_pith(0))
	assert_eq(seen, ["pith_clear"] as Array[String])

func test_pop_holds_still_under_reduced_motion() -> void:
	var calm: Dictionary = KeepsakeKit.pop_motion(true)
	assert_eq(float(calm.rise), 0.0)
	assert_eq(float(calm.grow), 1.0)
	var lively: Dictionary = KeepsakeKit.pop_motion(false)
	assert_gt(float(lively.rise), 0.0)
	assert_gt(float(lively.grow), 1.0)

func test_pop_spawns_and_cleans_up() -> void:
	GameState.reduce_motion = true
	var root := Control.new()
	add_child_autofree(root)
	var p: KeepsakePop = KeepsakePop.spawn(root, KeepsakeIcons.texture("rg_hold_stone"), Vector2(40, 40))
	assert_not_null(p)
	assert_eq(p.size, Vector2(14, 14))
	assert_eq(p.scale, Vector2.ONE, "no grow under reduced motion")
	assert_null(KeepsakePop.spawn(root, null, Vector2.ZERO))

# --- 281 -------------------------------------------------------------------------------------

func test_strip_shows_own_keepsake_and_a_foe_one_once_seen() -> void:
	var s := _mon("ember_charm")
	assert_eq(KeepsakeKit.strip_item(s, true), "ember_charm")
	assert_eq(KeepsakeKit.strip_item(s, false), "")
	s.set_meta(KeepsakeKit.SEEN_META, true)
	assert_eq(KeepsakeKit.strip_item(s, false), "ember_charm")
	assert_eq(KeepsakeKit.strip_item(_mon(), true), "")

func test_info_strip_draws_and_reads_the_keepsake() -> void:
	var strip := InfoStrip.new()
	strip.show_xp = true
	strip.size = Vector2(120, 30)
	add_child_autofree(strip)
	strip.set_spirling(_mon("ember_charm"))
	assert_eq(strip.held, "ember_charm")
	assert_string_contains(strip.screen_reader_text(), "holds Ember Charm")
	strip.set_held("")
	assert_false(strip.screen_reader_text().contains("holds"))

func test_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for k: String in ["%s takes up the %s. That was its whole turn.", "%s drops its %s for the %s. That was its whole turn.",
			"holds %s", "Keepsake sets", "Set %d: %s", "No %s left in the bag for %s.", "Keepsake: putting it on takes the whole turn."]:
		assert_true(de.has(k), k)
