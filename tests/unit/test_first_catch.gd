extends GutTest
## Chimora 1.3.2, the first five minutes (Ali): from the first free step a new Wayfarer reaches a
## wild Spirling within FirstCatch.STEPS steps and its bond within FirstCatch.TEXT_BOXES text
## boxes; the first wild Spirling always steps out and can be bonded; the first bond gives a gift,
## then the First Catch Pack note (adults only, once, never in battle); a great bond may ask for
## a store rating under every old rule.

const LANGS: Array[String] = ["en", "de", "ru", "ja"]
## The route a new Wayfarer walks: [map, from, to]. "to" is a warp cell, or the cell next to
## Kestra, or (on the last map) the first fern cell.
## Since 1.3.2 the route starts where the opening walk arrives in Brindlewick (Opening): the
## storm Spirlings and Aldo come before it, in the ferns.
const ROUTE: Array[Array] = [
	["brindlewick", Vector2i(5, 1), Vector2i(2, 4)],
	["map_house", Vector2i(4, 6), Vector2i(5, 4)],
	["map_house", Vector2i(5, 4), Vector2i(4, 7)],
	["brindlewick", Vector2i(2, 5), Vector2i(5, 0)],
]
const WILD_MAP: String = "fernstair"
const WILD_FROM: Vector2i = Vector2i(5, 24)

var _flags: Dictionary
var _records: Dictionary
var _tips_on: bool
var _state: Dictionary
var _inv: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_records = GameState.records.duplicate(true)
	_tips_on = GameState.tips_enabled
	_state = Billing.state.duplicate(true)
	_inv = GameState.inventory.duplicate()
	GameState.flags.clear()
	GameState.tips_enabled = true

func after_each() -> void:
	GameState.flags = _flags
	GameState.records = _records
	GameState.tips_enabled = _tips_on
	GameState.inventory = _inv
	Billing.state = _state
	Loc.set_language("en")

# --- Steps ----------------------------------------------------------------------------------

## True when an NPC of [param m] stands on [param cell] for a new journey with [param flags].
func _npc_on(m: MapData, cell: Vector2i, flags: Dictionary) -> bool:
	var all: Array = m.npcs.duplicate()
	var extra: Variant = StoryPlacements.for_map(m.id).get("npcs", [])
	if extra is Array:
		all.append_array(extra)
	for n: Variant in all:
		var d: Dictionary = n
		if d.has("show_flag") and not bool(flags.get(str(d.show_flag), false)):
			continue
		if d.has("hide_flag") and bool(flags.get(str(d.hide_flag), false)):
			continue
		if Vector2i(int(d.x), int(d.y)) == cell:
			return true
	return false

func _passable(m: MapData, flags: Dictionary) -> Callable:
	return func(c: Vector2i) -> bool:
		return m.in_bounds(c) and not TilesetFactory.is_solid(m.kind_at(c)) and not _npc_on(m, c, flags)

## Steps of the shortest walk on [param map_id] from [param a] to [param b].
func _walk(map_id: String, a: Vector2i, b: Vector2i, flags: Dictionary) -> int:
	var m: MapData = MapData.load_map(map_id)
	var path: Array[Vector2i] = PathFinder.find(a, b, _passable(m, flags))
	assert_false(path.is_empty(), "%s: a way from %s to %s" % [map_id, a, b])
	return path.size() - 1 if not path.is_empty() and path[0] == a else path.size()

## Steps from the fernstair entrance to the nearest cell wild Spirlings hide in.
func _steps_to_wild(flags: Dictionary) -> int:
	var m: MapData = MapData.load_map(WILD_MAP)
	assert_false(m.encounter_table.is_empty())
	var best: int = 999
	for y: int in m.height:
		for x: int in m.width:
			var c := Vector2i(x, y)
			if m.kind_at(c) in TilesetFactory.ENCOUNTER_KINDS and not TilesetFactory.is_solid(m.kind_at(c)) and not _npc_on(m, c, flags):
				var path: Array[Vector2i] = PathFinder.find(WILD_FROM, c, _passable(m, flags))
				if not path.is_empty():
					best = mini(best, path.size() - 1 if path[0] == WILD_FROM else path.size())
	return best

func _route_steps() -> int:
	var flags: Dictionary = {"got_starter": true, "first_walk": true, "aldo_gift": true, Opening.ON_FLAG: true, Opening.VILLAGE_FLAG: true}
	var n: int = 0
	for leg: Array in ROUTE:
		if leg[0] == "map_house" and leg[1] == Vector2i(5, 4):
			flags["met_kestra"] = true
		n += _walk(str(leg[0]), leg[1], leg[2], flags)
	n += _steps_to_wild(flags)
	return n

func test_route_legs_match_the_maps() -> void:
	assert_eq(str(MapData.load_map(Opening.MAP).warp_at(Vector2i(5, 25)).get("to", "")), "brindlewick")
	assert_eq(Vector2i(int(MapData.load_map(Opening.MAP).warp_at(Vector2i(5, 25)).tx), int(MapData.load_map(Opening.MAP).warp_at(Vector2i(5, 25)).ty)), ROUTE[0][1])
	assert_eq(str(MapData.load_map("brindlewick").warp_at(Vector2i(2, 4)).get("to", "")), "map_house")
	assert_eq(str(MapData.load_map("map_house").warp_at(Vector2i(4, 7)).get("to", "")), "brindlewick")
	assert_eq(str(MapData.load_map("brindlewick").warp_at(Vector2i(5, 0)).get("to", "")), WILD_MAP)

func test_steps_to_the_first_wild_spirling() -> void:
	var n: int = _route_steps()
	gut.p("steps from Brindlewick to the first fern: %d" % n)
	assert_lte(n, FirstCatch.STEPS)

# --- Text boxes -----------------------------------------------------------------------------

func _pages(box: TextBox, line: String) -> int:
	var shown: String = Loc.t(line).replace("{name}", "Liora")
	var parts: PackedStringArray = Dialogue.split_speaker(shown)
	if not parts[0].is_empty():
		shown = parts[1]
	var lab: Label = box._label
	return TextBox.split_lines(shown, box._text_width(), lab.get_theme_font("font"), lab.get_theme_font_size("font_size"), TextBox.MAX_LINES).size()

## Every line the player taps through from the arrival in Brindlewick until the first wild
## battle: the storm night and the first goal there (Overworld.village_story), then Kestra.
func _lines_before_wild() -> Array[String]:
	var out: Array[String] = []
	for step: Variant in ScenePlayer.load_scene("prologue").get("steps", []):
		if step is Dictionary and (step as Dictionary).has("say"):
			for l: Variant in step.say:
				out.append(str(l))
	out.append("New goal: " + QuestLog.goal_text(QuestLog.main_goals()[1], {}))
	# The menu tip after the walk hint, the save and goals tips on the next map changes.
	for id: String in ["menu", "save", "goals"]:
		out.append_array(Tips.lines_of(id, true))
	out.append_array(Dialogue.lines_for(Dialogue.get_entry("map_house/kestra"), {}))
	out.append("A page from Mirela's map book! (%d/%d)" % [1, Overworld.PAGE_COUNT])
	out.append_array(Dialogue.lines_for(Dialogue.get_entry("story/page_1"), {}))
	out.append_array(Tips.lines_of("map_page", true))
	out.append("New goal: " + QuestLog.goal_text(QuestLog.main_goals()[2], {}))
	# Fernstair: the wild-area tip waits until after the first wild battle.
	if not FirstCatch.due({}):
		out.append_array(Tips.lines_of("wild_area", true))
	return out

## The lines of the first wild battle until the bond: the bonding tip at the start (FirstCatch
## puts it first), the Mine! steps when Bond is picked.
func _lines_in_first_battle() -> Array[String]:
	var out: Array[String] = []
	out.append_array(Tips.lines_of(Tips.battle_start_tip(true, false, true), true))
	out.append_array(Tips.lines_of(Tips.bond_how_id("mine"), true))
	return out

func _count(ow: Overworld, lines: Array[String]) -> int:
	var n: int = 0
	for line: String in lines:
		n += _pages(ow.text_box(), line)
	return n

## Before 1.3.2: 10 boxes before control, then 36 in German and 27 in English to the bond plus
## the wild-area tip, and the wild Spirling came at random (12% a fern step). Since the opening
## this battle is the second bond and the count starts in Brindlewick (FirstCatch.TEXT_BOXES).
func test_text_boxes_to_the_first_bond() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	GameState.set_flag("got_starter")
	add_child_autofree(ow)
	await wait_frames(2)
	for lang: String in LANGS:
		Loc.set_language(lang)
		var before: int = _count(ow, _lines_before_wild())
		var total: int = before + _count(ow, _lines_in_first_battle())
		gut.p("%s: %d text boxes before the first wild battle, %d to the bond" % [lang, before, total])
		assert_lte(before, FirstCatch.WILD_TEXT_BOXES, lang)
		assert_lte(total, FirstCatch.TEXT_BOXES, lang)

func test_the_tightened_lines_keep_the_story() -> void:
	var k: String = "\n".join(Dialogue.lines_for(Dialogue.get_entry("map_house/kestra"), {}))
	for word: String in ["Aldo's apprentice", "Rifts", "Thornridge", "Saltmarsh", "not so sure", "start north in Fernstair", "Mirela"]:
		assert_string_contains(k, word)
	assert_eq(str(Dialogue.get_entry("map_house/kestra").get("action", "")), "page 1", "the first page still comes from Kestra")

# --- The guaranteed first wild Spirling -----------------------------------------------------

func test_first_wild_is_common_fair_and_on_the_ground() -> void:
	for starter: String in Database.STARTERS:
		var lead := Spirling.new(Database.species(starter), 5, GameState.rng)
		var sp: String = FirstCatch.pick_species("fernstair", "fern", lead.elements())
		assert_false(sp.is_empty(), starter)
		var sd: SpirlingData = Database.species(sp)
		assert_eq(sd.rarity, FirstCatch.RARITY, sp)
		assert_true(sp in EncounterTable.species_on("fernstair"))
		assert_true(EncounterTable.grounds_for("fernstair", sp).is_empty() or "fern" in EncounterTable.grounds_for("fernstair", sp))
		assert_eq(FirstCatch.matchup(lead.elements(), sd.elements), 1.0, "%s meets %s on even terms" % [starter, sp])
		var wild: Spirling = FirstCatch.make_wild("fernstair", "fern", lead, GameState.rng)
		assert_eq(wild.data.species_name, sp)
		assert_lt(wild.level, lead.level, "weaker than the partner")
		assert_gt(sd.bond_rate, 0.4, "%s bonds easily" % sp)

func test_first_wild_only_once() -> void:
	assert_true(FirstCatch.due({}))
	assert_false(FirstCatch.due({FirstCatch.MET_FLAG: true}))
	assert_false(FirstCatch.due({FirstCatch.BOND_FLAG: true}))
	assert_eq(FirstCatch.make_wild("no_such_table", "fern", null, GameState.rng), null)

func test_overworld_wiring() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "FirstCatch.due(GameState.flags) and GameState.first_healthy_index() >= 0")
	assert_string_contains(src, "start_battle([first] as Array[Spirling], true, {FirstCatch.META: true})")
	assert_string_contains(src, "Tips.pending(\"wild_area\") and not FirstCatch.due(GameState.flags)")
	assert_string_contains(src, "ShopScreen.first_catch_popup_now()")
	assert_true(FirstCatch.META in BattleCheckpoint.RESUMABLE_KEYS, "a closed app picks the battle up again")
	assert_true(FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd").contains("ShopScreen.run_first_catch_popup(self)"))
	assert_true(FileAccess.get_file_as_string("res://scripts/battle/presenter/BattleScene.gd").contains("model.has_meta(FirstCatch.META)"))

func test_first_wild_battle_opens_with_the_bond_tip() -> void:
	assert_eq(Tips.battle_start_tip(true, false, true), "bond")
	Tips.take("bond")
	assert_eq(Tips.battle_start_tip(true, false, true), "battle", "then the Energy tip")
	GameState.flags.clear()
	assert_eq(Tips.battle_start_tip(true, false), "battle", "other battles keep the Energy tip first")

# --- The first bond -------------------------------------------------------------------------

func test_first_bond_gift_once() -> void:
	var starter := Spirling.new(Database.species("Kindlop"), 5, GameState.rng)
	var other := Spirling.new(Database.species("Zephlet"), 3, GameState.rng)
	assert_true(FirstCatch.is_first_bond({}, [starter] as Array[Spirling], "Kindlop"))
	var team: Array[Spirling] = [starter]
	var none: Array[Spirling] = []
	assert_true(FirstCatch.is_first_bond({}, team + none + none, "Kindlop"), "team + storage + sanctuary as the world passes it")
	assert_false(FirstCatch.is_first_bond({}, [starter, other] as Array[Spirling], "Kindlop"), "an old save with bonds gets no gift")
	assert_false(FirstCatch.is_first_bond({FirstCatch.BOND_FLAG: true}, [starter] as Array[Spirling], "Kindlop"))
	GameState.inventory = {}
	var line: String = FirstCatch.on_bond()
	assert_string_contains(line, "First bond!")
	for id: String in FirstCatch.GIFT:
		assert_eq(GameState.item_count(id), FirstCatch.GIFT[id], id)
	assert_eq(FirstCatch.on_bond(), "", "only once")
	assert_eq(GameState.item_count("kin_charm"), FirstCatch.GIFT["kin_charm"])
	assert_false(FirstCatch.due(GameState.flags))

# --- First Catch Pack -----------------------------------------------------------------------

func test_first_catch_note_rules() -> void:
	var f: Dictionary = {ShopScreen.FIRST_CATCH_DUE_FLAG: true}
	assert_true(ShopScreen.first_catch_popup_due(f, 18, "", false))
	assert_false(ShopScreen.first_catch_popup_due({}, 18, "", false), "only after the first bond")
	assert_false(ShopScreen.first_catch_popup_due(f, 10, "", false), "never for a kids_locked account")
	assert_false(ShopScreen.first_catch_popup_due(f, 16, "", false), "never under 18")
	assert_false(ShopScreen.first_catch_popup_due(f, null, "", false), "not before the age is known")
	assert_false(ShopScreen.first_catch_popup_due(f, 18, "", true), "never in a battle")
	assert_false(ShopScreen.first_catch_popup_due(f, 18, "offer_limit", false), "not once bought (once per account)")
	var late: Dictionary = f.duplicate()
	late[GameState.ACT1_END_FLAG] = true
	assert_false(ShopScreen.first_catch_popup_due(late, 18, "", false), "after Act 1 the Starter Pack note has the stage")
	f[ShopScreen.FIRST_CATCH_SEEN_FLAG] = true
	assert_false(ShopScreen.first_catch_popup_due(f, 18, "", false), "only once")

func test_first_catch_note_live_check() -> void:
	GameState.set_flag(ShopScreen.FIRST_CATCH_DUE_FLAG)
	Billing.state = {}
	assert_false(ShopScreen.first_catch_popup_now(), "offline: the note waits")
	Billing.state = {"band": 10, "open": true, "cap_cents": 10000}
	assert_false(ShopScreen.first_catch_popup_now(), "kids_locked never")
	Billing.state = {"band": 18, "open": true, "cap_cents": 10000, "bought": {ShopScreen.FIRST_CATCH_ID: 1}}
	assert_false(ShopScreen.first_catch_popup_now(), "bought on this account")

func test_first_catch_offer() -> void:
	var o: Dictionary = ShopCatalog.offer(ShopScreen.FIRST_CATCH_ID)
	assert_false(o.is_empty())
	assert_eq(int(o.eur_cents), 99)
	assert_eq(str(o.store_type), "consumable")
	assert_eq(str(o.product_id), "de.chimora.game.consumable.firstcatch")
	assert_eq(str(o.limit.per), "account")
	assert_eq(int(o.limit.n), 1)
	assert_eq(int(o.rg_price), 0, "real money only, like the Starter Pack")
	var got: Array[String] = []
	for g: Dictionary in o.grants:
		got.append("%s %s %d" % [g.t, g.get("id", ""), int(g.n)])
	assert_eq(got, ["rg  80", "item rg_echo_scent 2", "item rg_rift_breath 1"] as Array[String])
	assert_false(o.has("badge"), "no Limited badge, no pressure")
	assert_eq(ShopValidator.check([o] as Array[Dictionary]), [] as Array[String])
	assert_eq(ShopCatalog.validate(), [] as Array[String])
	assert_eq(int(ShopCatalog.data().catalog_version), 43, "v42 is the bond-charm catalog")
	assert_eq(ShopCatalog.save_days(o), 7, "shown in the first days of a journey only, like the Starter Pack")
	var starter: Dictionary = ShopCatalog.offer(ShopScreen.STARTER_ID)
	assert_eq(int(starter.eur_cents), 299, "the Starter Pack stays")
	for lang: String in ["de", "ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]:
		Loc.set_language(lang)
		for key: String in [str(o.name), str(o.desc), ShopScreen.FIRST_CATCH_HEAD, FirstCatch.GIFT_LINE]:
			assert_ne(Loc.t(key), key, "%s: %s" % [lang, key])

# --- Review ask after a great bond ----------------------------------------------------------

func test_great_bond_kinds() -> void:
	var common := Spirling.new(Database.species("Zephlet"), 3, GameState.rng)
	assert_eq(ReviewAsk.great_bond_kind(common), "")
	var gleam := Spirling.new(Database.species("Zephlet"), 3, GameState.rng)
	gleam.gleam = true
	assert_eq(ReviewAsk.great_bond_kind(gleam), "gleam")
	var legend := Spirling.new(Database.species("Velahra"), 40, GameState.rng)
	assert_eq(ReviewAsk.great_bond_kind(legend), "legend")
	var ancient: SpirlingData = null
	for sd: SpirlingData in Database.spirlings.values():
		if sd.rarity == ReviewAsk.RAREST and FirstVoices.entry(sd.species_name).is_empty():
			ancient = sd
			break
	if ancient != null:
		assert_eq(ReviewAsk.great_bond_kind(Spirling.new(ancient, 30, GameState.rng)), "ancient")

func test_only_the_first_great_bond_of_a_kind_counts() -> void:
	var rec: Dictionary = {}
	var gleam := Spirling.new(Database.species("Zephlet"), 3, GameState.rng)
	gleam.gleam = true
	assert_true(ReviewAsk.note_great_bond(gleam, rec))
	assert_false(ReviewAsk.note_great_bond(gleam, rec), "the second Gleam is no highlight")
	assert_true(ReviewAsk.note_great_bond(Spirling.new(Database.species("Velahra"), 40, GameState.rng), rec))
	assert_false(ReviewAsk.note_great_bond(Spirling.new(Database.species("Zephlet"), 3, GameState.rng), rec))

func test_great_bond_keeps_every_review_guard() -> void:
	var now: int = 1_800_000_000
	var st: Dictionary = {}
	ReviewAsk.note_session(st, now)
	assert_false(ReviewAsk.may_ask(st, now + 60, "1.3.2", false), "not in the first 10 minutes")
	assert_false(ReviewAsk.may_ask(st, now + 700, "1.3.2", true), "never in battle")
	assert_true(ReviewAsk.may_ask(st, now + 700, "1.3.2", false))
	ReviewAsk.note_asked(st, now + 700, "1.3.2")
	assert_false(ReviewAsk.may_ask(st, now + 800, "1.3.2", false), "once per version")
	assert_false(ReviewAsk.after_win(false), "no highlight, no ask")
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "ReviewAsk.after_win(great)")
	assert_false(FileAccess.get_file_as_string("res://scripts/online/ReviewAsk.gd").contains("give_item"), "nothing given for a rating")

# --- Played in the world --------------------------------------------------------------------

func test_first_fern_step_opens_the_guaranteed_battle() -> void:
	var party: Array[Spirling] = GameState.party.duplicate()
	var map_id: String = GameState.current_map
	var cell: Vector2i = GameState.player_cell
	GameState.party.clear()
	GameState.party.append(Spirling.new(Database.species("Kindlop"), 5, GameState.rng))
	GameState.starter = "Kindlop"
	for f: String in ["got_starter", "first_walk", "aldo_gift", "met_kestra", "tip_wild_area"]:
		GameState.set_flag(f)
	GameState.current_map = WILD_MAP
	GameState.player_cell = Vector2i(5, 22)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(4)
	EncounterTable._guard = 0
	var fern := Vector2i(6, 22)
	assert_true(ow.map.kind_at(fern) in TilesetFactory.ENCOUNTER_KINDS, "a fern by the entrance")
	ow._on_player_stepped(fern)
	var scene: BattleScene = null
	for i: int in 240:
		for c: Node in ow._battle_layer.get_children():
			if c is BattleScene:
				scene = c
		if scene != null:
			break
		await wait_frames(1)
	assert_not_null(scene, "the first fern step always meets a wild Spirling")
	if scene != null:
		assert_true(scene.model.is_wild)
		assert_true(scene.model.has_meta(FirstCatch.META))
		var lead: Array[int] = GameState.party[0].elements()
		assert_eq(scene.model.parties[1][0].data.species_name, FirstCatch.pick_species(WILD_MAP, "fern", lead))
	assert_true(GameState.has_flag(FirstCatch.MET_FLAG))
	GameState.party = party
	GameState.current_map = map_id
	GameState.player_cell = cell
