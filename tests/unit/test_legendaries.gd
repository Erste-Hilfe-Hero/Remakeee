extends GutTest
## The six legendary Spirlings (Hallowmur, Scriptorax, Lumivane, Zephyrel, Monolurk, Vorlucent):
## data, sprites, Era II elements in battle, and their one fixed meeting each.

const LEGENDS: Dictionary[String, String] = {
	"Hallowmur": "ECHO", "Scriptorax": "INK", "Lumivane": "LUMEN",
	"Zephyrel": "GALE", "Monolurk": "STONE", "Vorlucent": "UMBRA",
}

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func test_each_legend_is_an_ancient_kind_in_the_band() -> void:
	for n: String in LEGENDS:
		var sd: SpirlingData = Database.species(n)
		assert_not_null(sd, n)
		if sd == null:
			continue
		assert_eq(sd.rarity, "ancient", n)
		assert_eq(sd.era, 1, n)
		assert_eq(sd.elements, [Elements.E[LEGENDS[n]]] as Array[int], n)
		var band: Vector2 = SpirlingData.BOND_RATE_BANDS["ancient"]
		assert_between(sd.bond_rate, band.x, band.y, n)
		var total: int = sd.base_hp + sd.base_atk + sd.base_def + sd.base_foc + sd.base_spd
		var st: Vector2i = SpirlingData.STAT_TOTAL_BANDS["ancient"]
		assert_between(total, st.x, st.y, n)
		var stab: bool = false
		for mv: MoveData in sd.learnset_moves:
			stab = stab or mv.element in sd.elements
		assert_true(stab, "%s learns an art of its own element" % n)

func test_sprites_fit_the_battle_slot() -> void:
	for n: String in LEGENDS:
		for facing: String in ["front", "back"]:
			var path: String = EraManager.sprite_path(n, facing)
			assert_false(path.is_empty(), "%s %s" % [n, facing])
			if path.is_empty():
				continue
			var tex: Texture2D = load(path)
			assert_eq(tex.get_width(), EraManager.battle_sprite_size(n), path)
			assert_eq(tex.get_height(), EraManager.battle_sprite_size(n), path)
		assert_not_null(MiniSprite.of(n, 14), n)

func test_ink_and_echo_work_in_battle() -> void:
	var E := Elements.E
	assert_eq(Elements.single(E.INK, E.EMBER), 2.0)
	assert_eq(Elements.single(E.EMBER, E.INK), 0.5)
	assert_eq(Elements.single(E.ECHO, E.UMBRA), 2.0)
	assert_eq(Elements.single(E.EMBER, E.ECHO), 2.0)
	assert_eq(Elements.single(E.INK, E.ECHO), 1.0)
	for e: int in [E.INK, E.ECHO]:
		assert_false(ElementIcons.GLYPHS.get(e, []).is_empty(), Elements.E.keys()[e])
		assert_true(ResourceLoader.exists("res://audio/sfx/%s.wav" % Sound.element_hit_name(e)))
		assert_true(ResourceLoader.exists("res://audio/sfx/%s.wav" % BattleScene.travel_sound(e)))
	var ink: Spirling = BattleFixtures.make("Scriptorax", 55)
	var echo: Spirling = BattleFixtures.make("Hallowmur", 55)
	var lash: MoveData = Database.moves["Margin Lash"]
	assert_eq(DamageCalc.stab_for(ink, lash), DamageCalc.STAB)
	assert_gt(DamageCalc.raw(ink, echo, lash, 1.0, false), 0.0)
	var m: BattleModel = BattleFixtures.model([ink] as Array[Spirling], [echo] as Array[Spirling])
	assert_not_null(m)

func test_element_names_have_german_text() -> void:
	var de: String = ""
	for f: String in DirAccess.get_files_at("res://data/i18n/de"):
		if f.ends_with(".json"):
			de += FileAccess.get_file_as_string("res://data/i18n/de/" + f)
	assert_string_contains(de, "\"Ink\": \"Tinte\"")
	assert_string_contains(de, "\"Echo\": \"Echo\"")
	assert_string_contains(de, "Hallowmur")

func test_each_legend_is_met_once_at_a_fixed_place() -> void:
	var enc: Dictionary = _json("res://data/encounters.json")
	for area: String in enc:
		for s: Dictionary in enc[area].get("spawns", []):
			assert_false(LEGENDS.has(str(s.species)), "never in a wild table (%s)" % area)
	var maps: Dictionary = {}
	for n: String in LEGENDS:
		var v: Dictionary = FirstVoices.LEGENDS.get(n, {})
		assert_false(v.is_empty(), n)
		if v.is_empty():
			continue
		var map_id: String = str(v.map)
		maps[map_id] = true
		var key: String = n.to_lower()
		var npc: Dictionary = {}
		for d: Dictionary in (_json("res://data/maps/%s.json" % map_id) as Dictionary).get("npcs", []):
			if d.id == key:
				npc = d
		assert_eq(npc.get("show_flag"), str(v.after), n)
		assert_eq(npc.get("hide_flag"), FirstVoices.away_flag(n), n)
		var dlg: Dictionary = _json("res://data/dialogue/%s.json" % map_id)
		assert_eq(str(dlg[key].action), "legend %s %d" % [n, int(v.ring)], n)
	assert_eq(maps.size(), 6, "one place each")

func test_a_missed_legend_returns_after_a_rest() -> void:
	assert_false(FirstVoices.waiting("Monolurk"), "not before the Kiln Rift is sealed")
	GameState.set_flag("rift_kiln_sealed")
	assert_true(FirstVoices.waiting("Monolurk"))
	GameState.set_flag(FirstVoices.away_flag("Monolurk"))
	assert_false(FirstVoices.waiting("Monolurk"))
	FirstVoices.after_rest()
	assert_true(FirstVoices.waiting("Monolurk"))
	assert_false(FirstVoices.waiting("Hallowmur"), "post-game only")
	GameState.set_flag("story_complete")
	assert_true(FirstVoices.waiting("Hallowmur"))
