extends GutTest
## The art set (docs/CONTENT_GAPS.md): every art has English and German text, a valid element,
## kind, era and effect, and someone who can learn it; every Spirling has 4 arts by Ring 30; the
## four effects added with the set (energy_gain, stage_reset, cure_team, self_cost) and the
## for_elements rule of later-era Echo Crystals.

const MIN_ARTS: int = 400

func before_all() -> void:
	Database.reload_data()

func _raw_moves() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(Database.MOVES_PATH))

func _learners_by_level() -> Dictionary:
	var out: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		for mv: MoveData in sd.learnset_moves:
			out[mv.move_name] = true
	return out

## Echo Crystals and Scripts: the art -> true when at least one kind may be taught it.
func _teachable() -> Dictionary:
	var out: Dictionary = {}
	for it: Dictionary in Database.items.values():
		var mv: MoveData = Database.move(str(it.get("teaches", "")))
		if mv == null:
			continue
		var allowed: Array[int] = [mv.element]
		for e: Variant in it.get("for_elements", []):
			allowed.append(Elements.E[str(e)])
		for sd: SpirlingData in Database.spirlings.values():
			if bool(it.get("any_element", false)) or sd.elements.any(func(e: int) -> bool: return e in allowed):
				out[mv.move_name] = true
				break
	return out

func test_at_least_400_arts() -> void:
	assert_gte(Database.moves.size(), MIN_ARTS)

func test_every_art_has_english_and_german_text() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for m: Dictionary in _raw_moves():
		var n: String = str(m.get("name", ""))
		var d: String = str(m.get("desc", ""))
		assert_false(d.is_empty(), "%s has an English line" % n)
		assert_false(str(de.get(n, "")).is_empty(), "%s has a German name" % n)
		assert_false(str(de.get(d, "")).is_empty(), "%s has a German line" % n)

func test_every_art_has_valid_element_kind_era_and_effect() -> void:
	for m: Dictionary in _raw_moves():
		var n: String = str(m.name)
		assert_true(Elements.E.has(str(m.element)), "%s element" % n)
		assert_true(str(m.kind) in DataValidator.VALID_KINDS, "%s kind" % n)
		assert_between(int(m.get("era", 0)), 1, 5, "%s era" % n)
		if m.has("effect"):
			assert_true(EffectRegistry.has_effect(StringName(m.effect)), "%s effect %s" % [n, m.effect])
		var mv: MoveData = Database.move(n)
		for fx: Dictionary in mv.effects:
			assert_true(EffectRegistry.has_effect(StringName(fx.id)), "%s carries %s" % [n, fx.id])
		if str(m.kind) == "STATUS":
			assert_eq(int(m.power), 0, "%s: a status art deals no damage" % n)
		else:
			assert_gt(int(m.power), 0, "%s: a damage art has power" % n)

func test_every_art_is_learnable_by_at_least_one_spirling() -> void:
	var learn: Dictionary = _learners_by_level()
	var teach: Dictionary = _teachable()
	for n: String in Database.moves:
		assert_true(learn.has(n) or teach.has(n), "%s: no learnset and no teacher" % n)

func test_every_spirling_knows_4_arts_by_ring_30() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var seen: Dictionary = {}
		for i: int in sd.learnset_levels.size():
			if sd.learnset_levels[i] <= 30:
				seen[sd.learnset_moves[i].move_name] = true
		assert_gte(seen.size(), 4, sd.species_name)

func test_later_era_arts_only_on_later_era_spirlings() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		for mv: MoveData in sd.learnset_moves:
			assert_lte(mv.era, maxi(sd.era, 1), "%s (era %d) learns %s (era %d)" % [sd.species_name, sd.era, mv.move_name, mv.era])

func test_every_element_has_a_full_ladder() -> void:
	for e: int in Elements.E.values():
		var ladder: Dictionary = {}
		var status: int = 0
		for mv: MoveData in Database.moves.values():
			if mv.element != e:
				continue
			if not mv.is_damaging():
				status += 1
				continue
			var band: String = "weak" if mv.power <= 50 else ("mid" if mv.power <= 80 else "strong")
			ladder["%d_%s" % [mv.kind, band]] = true
		var n: String = Elements.E.keys()[e]
		for k: int in [MoveData.Kind.PHYSICAL, MoveData.Kind.FOCUS]:
			for band: String in ["weak", "mid", "strong"]:
				assert_true(ladder.has("%d_%s" % [k, band]), "%s has a %s %s art" % [n, band, MoveData.Kind.keys()[k]])
		assert_gte(status, 4, "%s has 4 status arts" % n)

func test_new_cures_cover_every_status() -> void:
	var cured: Dictionary = {}
	for it: Dictionary in Database.items.values():
		if it.get("cure") is String:
			cured[str(it.cure)] = true
	for st: String in StatusRules.RULES:
		assert_true(cured.has(st), "a single cure for %s" % st)

# --- the four new effects ------------------------------------------------------

func _mv(extra: Dictionary) -> MoveData:
	var m: Dictionary = {"name": "Test Art", "element": "STONE", "kind": "STATUS", "power": 0, "accuracy": 1.0, "energy": 0}
	m.merge(extra, true)
	return Database.parse_move(m)

func _ctx(m: BattleModel, mv: MoveData) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.model = m
	ctx.user_side = 0
	ctx.target_side = 1
	ctx.user = m.active_spirling(0)
	ctx.target = m.active_spirling(1)
	ctx.move = mv
	return ctx

func _model() -> BattleModel:
	var a: Spirling = BattleFixtures.make("Shalebat", 30, ["Bowl Over"])
	var b: Spirling = BattleFixtures.make("Mossling", 30, ["Bowl Over"])
	var c: Spirling = BattleFixtures.make("Kindlop", 30, ["Bowl Over"])
	return BattleFixtures.model([a, c] as Array[Spirling], [b] as Array[Spirling], false, 11)

func _apply(m: BattleModel, mv: MoveData) -> void:
	for fx: Dictionary in mv.effects:
		EffectRegistry.get_effect(StringName(fx.id)).apply(_ctx(m, mv), fx)

func test_energy_gain_fills_up_to_the_cap() -> void:
	var m: BattleModel = _model()
	var me: Spirling = m.active_spirling(0)
	me.energy = 2
	_apply(m, _mv({"effect": "energy_gain", "effect_amount": 3}))
	assert_eq(me.energy, 5)
	me.energy = m.max_energy_of(0) - 1
	_apply(m, _mv({"effect": "energy_gain", "effect_amount": 3}))
	assert_eq(me.energy, m.max_energy_of(0), "never above the cap")

func test_stage_reset_clears_both_sides() -> void:
	var m: BattleModel = _model()
	m.active_spirling(0).stages["atk"] = -2
	m.active_spirling(1).stages["def"] = 3
	m.active_spirling(1).stages["spd"] = -1
	_apply(m, _mv({"effect": "stage_reset"}))
	for stat: String in BattleRules.STAGE_STATS:
		assert_eq(m.active_spirling(0).stage(stat), 0, stat)
		assert_eq(m.active_spirling(1).stage(stat), 0, stat)

func test_cure_team_cures_the_field_and_the_bench_but_not_the_foe() -> void:
	var m: BattleModel = _model()
	m.party(0)[0].status = "scorch"
	m.party(0)[1].status = "root"
	m.active_spirling(1).status = "soak"
	_apply(m, _mv({"effect": "cure_team"}))
	assert_eq(m.party(0)[0].status, "")
	assert_eq(m.party(0)[1].status, "", "the bench is cured too")
	assert_eq(m.active_spirling(1).status, "soak", "the foe keeps its status")

func test_self_cost_pays_vigor_but_never_the_last_point() -> void:
	var m: BattleModel = _model()
	var me: Spirling = m.active_spirling(0)
	var full: int = me.max_hp()
	var mv: MoveData = _mv({"effect": "self_cost", "effect_amount": 0.25, "stats": {"atk": 2}, "self": true})
	_apply(m, mv)
	assert_eq(me.hp, full - int(full * 0.25))
	assert_eq(me.stage("atk"), 2)
	me.hp = 2
	_apply(m, mv)
	assert_eq(me.hp, 1, "the cost stops at 1 Vigor")
	_apply(m, mv)
	assert_eq(me.hp, 1, "at 1 Vigor nothing is paid")
	assert_false(me.is_fainted())

func test_new_effects_in_a_real_battle_turn() -> void:
	var a: Spirling = BattleFixtures.make("Shalebat", 30, ["Bowl Over"])
	a.moves = [Database.move("Second Wind")] as Array[MoveData]
	var b: Spirling = BattleFixtures.make("Mossling", 30, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, 5)
	a.energy = 3
	m.submit_turn(BattleAction.make_move(0, 0))
	assert_gte(a.energy, 6, "3 from Second Wind plus the turn's own gain")

func test_for_elements_lets_a_later_teacher_take_other_elements() -> void:
	var id: String = ""
	for k: String in Database.items:
		var it: Dictionary = Database.items[k]
		if (it.get("for_elements", []) as Array).has("LUMEN") and Database.move(str(it.get("teaches", ""))).element == Elements.E.GILT:
			id = k
			break
	assert_false(id.is_empty(), "a Gilt crystal teaches Lumen kinds")
	var lumen: Spirling = BattleFixtures.make("Lumivane", 50, ["Glint"])
	var ember_only: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])
	assert_true(GameState.can_learn_echo(lumen, id))
	var ok: bool = GameState.can_learn_echo(ember_only, id)
	var allowed: Array = Database.item(id).get("for_elements", [])
	assert_eq(ok, allowed.has("EMBER"), "Ember only when the crystal names Ember")
