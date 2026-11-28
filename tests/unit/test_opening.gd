extends GutTest
## Chimora 1.3.2, the opening (Ali's final order): New Game puts the Wayfarer in the ferns with
## control at once; the first step meets the storm Spirlings, bonded with Mine!; Aldo walks
## over; in Brindlewick the storm night, look and name, goals and the menu tip follow. Every old
## story flag of the start is still set. The funnel notes each first step once, in the save.

const TEST_SLOT: String = "user://test_opening_slot.json"
## Steps from the first fern to the Brindlewick warp (8 on the 1.3.2 map).
const VILLAGE_STEPS: int = 10

var _flags: Dictionary
var _records: Dictionary
var _slot: String
var _motion: bool
var _tips_on: bool
var _style: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_records = GameState.records.duplicate(true)
	_slot = SaveManager.slot_path
	_motion = GameState.reduce_motion
	_tips_on = GameState.tips_enabled
	_style = GameState.bond_style
	SaveManager.slot_path = TEST_SLOT
	GameState.reduce_motion = true
	GameState.tips_enabled = true

func after_each() -> void:
	GameState.flags = _flags
	GameState.records = _records
	SaveManager.slot_path = _slot
	GameState.reduce_motion = _motion
	GameState.tips_enabled = _tips_on
	GameState.bond_style = _style
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SLOT))

# --- Rules ----------------------------------------------------------------------------------

func test_new_game_starts_in_the_ferns() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "", 0, "")
	assert_eq(GameState.current_map, Opening.MAP)
	assert_eq(GameState.player_cell, Opening.CELL)
	assert_true(Opening.active(GameState.flags))
	assert_true(Opening.meet_due(GameState.flags))
	assert_eq(GameState.tamer_name, GameState.DEFAULT_NAMES[0], "the default name until the village")
	assert_eq(Funnel.at(GameState.records, "new_game"), 0)

func test_a_journey_with_a_partner_has_no_opening() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	assert_false(Opening.active(GameState.flags))
	assert_false(Opening.quiet(GameState.flags))
	assert_eq(GameState.current_map, "lighthouse")

func test_opening_rules() -> void:
	var f: Dictionary = {Opening.ON_FLAG: true}
	assert_true(Opening.meet_now(f, true, 1), "a fern step meets them")
	assert_false(Opening.meet_now(f, false, 1))
	assert_true(Opening.meet_now(f, false, Opening.MEET_STEPS), "at the latest on step MEET_STEPS")
	assert_false(Opening.village_due(f, Opening.VILLAGE_MAP), "not before the bond")
	f["got_starter"] = true
	assert_false(Opening.meet_due(f))
	assert_true(Opening.quiet(f), "the walk to the village stays quiet")
	assert_true(Opening.village_due(f, Opening.VILLAGE_MAP))
	assert_false(Opening.village_due(f, Opening.MAP))
	assert_eq(QuestLog.hud_text(f), "", "goals open in the village")
	assert_true(QuestLog.goal_maps(f).is_empty())
	assert_false(FirstCatch.due(f), "no guaranteed wild battle during the opening")
	f[Opening.VILLAGE_FLAG] = true
	assert_false(Opening.active(f))
	assert_false(Opening.village_due(f, Opening.VILLAGE_MAP))
	assert_ne(QuestLog.hud_text(f), "")
	assert_true(FirstCatch.due(f), "then the first wild battle is the easy one")
	assert_false(Opening.active({"got_starter": true}), "old saves never had the opening")

# --- Steps ----------------------------------------------------------------------------------

func test_every_first_step_is_into_the_ferns() -> void:
	var m: MapData = MapData.load_map(Opening.MAP)
	assert_false(m.encounter_table.is_empty())
	var open: int = 0
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c: Vector2i = Opening.CELL + d
		if not m.is_walkable(c):
			continue
		open += 1
		assert_true(m.kind_at(c) in TilesetFactory.ENCOUNTER_KINDS, "step to %s meets the storm Spirlings" % c)
	assert_gt(open, 0)
	assert_lte(Opening.MEET_STEPS, 3)

func test_the_village_is_a_short_walk() -> void:
	var m: MapData = MapData.load_map(Opening.MAP)
	var best: int = 999
	for w: Dictionary in m.warps:
		if str(w.to) != Opening.VILLAGE_MAP:
			continue
		var path: Array[Vector2i] = PathFinder.find(Opening.CELL, Vector2i(int(w.x), int(w.y)), func(c: Vector2i) -> bool: return m.is_walkable(c))
		if not path.is_empty():
			best = mini(best, path.size() - 1 if path[0] == Opening.CELL else path.size())
	gut.p("steps from the ferns to Brindlewick: %d" % best)
	assert_lte(best, VILLAGE_STEPS)

# --- Funnel ---------------------------------------------------------------------------------

func test_funnel_notes_each_step_once() -> void:
	var r: Dictionary = {}
	Funnel.note(r, "first_control", 3.0)
	assert_false(r.has(Funnel.RECORD), "journeys before 1.3.2 get no record")
	Funnel.start(r)
	Funnel.note(r, "first_control", 1.7)
	Funnel.note(r, "first_control", 9.0)
	Funnel.note(r, "first_wild", 4.2)
	Funnel.note(r, "not_a_step", 5.0)
	assert_eq(r[Funnel.RECORD], {"new_game": 0, "first_control": 1, "first_wild": 4})
	assert_eq(Funnel.at(r, "first_catch"), -1)
	assert_eq(Funnel.STEPS, ["new_game", "first_control", "first_wild", "first_catch", "story_start", "first_save"] as Array[String])

func test_funnel_goes_up_in_the_save_only() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "", 0, "")
	Funnel.mark("first_control")
	var d: Dictionary = GameState.to_dict()
	assert_true((d.records as Dictionary).has(Funnel.RECORD))
	assert_eq((d.records[Funnel.RECORD] as Dictionary).keys(), ["new_game", "first_control"], "only step names and seconds")
	GameState.from_dict(d)
	assert_eq(Funnel.at(GameState.records, "first_control"), 0)
	var src: String = FileAccess.get_file_as_string("res://scripts/core/Funnel.gd")
	for word: String in ["HTTPRequest", "OS.get_unique_id", "Online."]:
		assert_false(src.contains(word), "no own network call or device id: " + word)

# --- The whole opening, played ---------------------------------------------------------------

## Answers whatever the opening asks: partner list, Mine!, look screen, name box; Skip on scenes.
func _drive(ow: Overworld) -> void:
	ow.text_box().auto_advance = true
	for n: Node in ow.get_children():
		if n is CanvasLayer:
			for c: Node in n.get_children():
				if c is BondMinigame and (c as BondMinigame).visible:
					(c as BondMinigame).mine_tap()
	for n: Node in ow._ui.get_children():
		if n is MenuHost and (n as MenuHost).picker.visible and (n as MenuHost).picker._buttons.size() > 0:
			var host := n as MenuHost
			host.picker.picked.emit(TitleScreen.LOOK_DONE if host.last_title == TitleScreen.LOOK_TITLE else 0)
		elif n is MenuHost:
			for c: Node in n.get_children():
				if c is NameBox:
					(c as NameBox)._done.emit("Mara")
	for n: Node in ow.get_children():
		if n is ScenePlayer and (n as ScenePlayer).skip_button() != null and (n as ScenePlayer).skip_button().visible:
			(n as ScenePlayer).skip()

func _until(ow: Overworld, cond: Callable, frames: int = 3000) -> bool:
	for i: int in frames:
		if cond.call():
			return true
		_drive(ow)
		await wait_process_frames(1)
	return cond.call()

func test_the_opening_plays_through_and_keeps_every_story_flag() -> void:
	GameState.bond_style = "mine"
	GameState.new_game(GameState.Difficulty.TAMER, "", 0, "")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(3)
	ow.text_box().auto_advance = true
	assert_false(ow.busy, "control at once")
	# The first step: into the ferns.
	ow.player.cell = Opening.CELL + Vector2i.DOWN
	ow._on_player_stepped(ow.player.cell)
	assert_true(await _until(ow, func() -> bool: return GameState.has_flag("aldo_gift") and not ow.busy), "partner, Mine! and Aldo")
	for f: String in ["got_starter", "first_walk", "aldo_gift", ScenePlayer.seen_flag(Opening.ALDO_ID)]:
		assert_true(GameState.has_flag(f), f)
	assert_eq(GameState.party.size(), 1)
	assert_true(GameState.starter in Database.STARTERS)
	assert_eq(GameState.item_count("tonic"), 2, "Aldo's two Tonics")
	assert_true(FileAccess.file_exists(TEST_SLOT), "saved after the bond")
	for step: String in ["new_game", "first_control", "first_wild", "first_catch", "first_save"]:
		assert_gte(Funnel.at(GameState.records, step), 0, step)
	assert_lte(Funnel.at(GameState.records, "first_wild") - Funnel.at(GameState.records, "first_control"), 1, "the first step meets them")
	assert_true(Opening.quiet(GameState.flags))
	# On to Brindlewick: the story goes on.
	ow.load_map(Opening.VILLAGE_MAP, Vector2i(5, 1), "down")
	assert_true(await _until(ow, func() -> bool: return GameState.has_flag(Opening.VILLAGE_FLAG) and not ow.busy), "the village story")
	for f: String in ["scene_prologue_seen", Opening.VILLAGE_FLAG]:
		assert_true(GameState.has_flag(f), f)
	assert_eq(GameState.tamer_name, "Mara", "the name is asked in the village")
	assert_gte(Funnel.at(GameState.records, "story_start"), 0)
	assert_false(Opening.active(GameState.flags))
	assert_eq(QuestLog.current(GameState.flags).get("id"), "maps", "the first goal: Kestra's Map House")
	assert_ne(QuestLog.hud_text(GameState.flags), "")
