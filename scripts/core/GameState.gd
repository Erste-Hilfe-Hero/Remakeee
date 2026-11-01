extends Node
## Global player state. Saving and loading go through SaveManager (M4).

## Unbound-style difficulty, picked at new game.
enum Difficulty { STORY, TAMER, VETERAN, RIFT_BORN }
## Level cap per Rift sealed (Veteran + Rift-Born only).
const LEVEL_CAPS: Array[int] = [12, 18, 23, 28, 32, 36, 40, 44, 50]
const AI_LEVELS: Array[int] = [0, 1, 2, 2]
const MAX_PARTY: int = 5
enum TextSpeed { SLOW, NORMAL, FAST }
const TEXT_CPS: Array[float] = [30.0, 60.0, 140.0]

## Tamer customisation (placeholder until real sprites exist).
var tamer_name: String = "Juno"
var tamer_color: int = 0
## Coat colours on the title screen: teal, rust, ochre, plum (TitleScreen.COAT_NAMES).
const TAMER_COLORS: Array[Color] = [Color("2f7f7a"), Color("a2502e"), Color("b08a2e"), Color("6a3f6e")]
## Seconds played (shown on the save card).
var play_time: float = 0.0
## True while a game is running (the title screen sets it); saving on pause needs it.
var in_game: bool = false

var party: Array[Spirling] = []
## Storage box for Spirlings beyond the party of 6.
var storage: Array[Spirling] = []
## Iron Oath (item 15, opt-in at new game): Spirlings that faint retire to the Sanctuary.
var iron_oath: bool = false
var sanctuary: Array[Spirling] = []
## Spirlog: species name -> {"seen": bool, "bonded": bool}.
var spirlog: Dictionary = {}
var region: String = "veydal"
var rifts_sealed: Array[String] = []
## Species name of the partner picked at the start (the rival counter-picks against it).
var starter: String = ""
var difficulty: Difficulty = Difficulty.TAMER
## Item id -> count.
var inventory: Dictionary = {}
var money: int = 0

## Overworld position.
var current_map: String = "lighthouse"
var player_cell: Vector2i = Vector2i(4, 4)
var facing: String = "down"
## Where the team wakes up after a loss (last Rest Spring used).
var heal_map: String = "lighthouse"
var heal_cell: Vector2i = Vector2i(4, 4)
## Story and world flags, e.g. "got_starter", "rift_1_sealed".
var flags: Dictionary = {}
## Rest spots the player has used: map id -> [x, y] (fast travel between them).
var visited_rests: Dictionary = {}
## Personal bests, e.g. "gauntlet_best".
var records: Dictionary = {}
## Puzzle progress: puzzle id -> number of switches pressed in the right order so far.
var switch_progress: Dictionary = {}
enum SwitchResult { WRONG, STEP, SOLVED }
## Seeded RNG for overworld rolls (encounters); battles get their own seed from it.
var rng := RandomNumberGenerator.new()

## Settings (also saved).
var text_speed: TextSpeed = TextSpeed.NORMAL
## Battle playback speed: index into BATTLE_SPEEDS (1x / 2x / 4x).
var battle_speed: int = 0
const BATTLE_SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## Wild battles pick moves on their own (greedy AI) until the player turns it off.
var auto_battle: bool = false
var volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
## Touch controls: pad size and opacity (index into PAD_SIZES / PAD_ALPHAS), left-handed layout, tap-to-move.
var pad_size: int = 1
var pad_opacity: int = 1
var left_handed: bool = false
var tap_to_move: bool = true
## One-hand layout (item 79): D-pad and buttons stacked on one side of the screen.
var one_hand: bool = false
## Gamepad rumble on hits (item 63).
var rumble: bool = true
## First-time tips (see Tips.gd).
var tips_enabled: bool = true
## Display and accessibility (items 59, 76, 78).
var battery_saver: bool = false
var reduce_motion: bool = false
var high_contrast: bool = false
## Day and night tint and encounters on outdoor maps (item 43).
var day_night: bool = true
## Game language (item 62): a Loc.LANGUAGES code, or "" for the device language.
var language: String = ""
const FPS_NORMAL: int = 60
const FPS_BATTERY: int = 30
const PAD_SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]
const PAD_ALPHAS: Array[float] = [0.3, 0.55, 0.85]

## What the Tamer has learned about matchups: "element:species" -> multiplier seen on a hit.
## Story difficulty shows every matchup from the start.
var known_matchups: Dictionary = {}

## Mended Rifts needed before the storage box opens from the menu (end of Act I).
const RIFTS_FOR_STORAGE: int = 2

func level_cap() -> int:
	if difficulty < Difficulty.VETERAN:
		return Spirling.MAX_LEVEL
	return LEVEL_CAPS[mini(rifts_sealed.size(), LEVEL_CAPS.size() - 1)]

## Marks a Rift as sealed (raises the level cap on Veteran and up). Returns false if it already was.
func seal_rift(rift_id: String) -> bool:
	if rift_id in rifts_sealed:
		return false
	rifts_sealed.append(rift_id)
	set_flag("rift_%s_sealed" % rift_id)
	# Rifts can be mended in any order; the second one opens storage from the menu.
	if rifts_sealed.size() >= RIFTS_FOR_STORAGE:
		set_flag("storage_remote")
	return true

func items_allowed_in_battle() -> bool:
	return difficulty != Difficulty.RIFT_BORN

## Trainer AI tier for the current difficulty: 0 random, 1 greedy, 2 lookahead.
func ai_level() -> int:
	return AI_LEVELS[difficulty]

func text_cps() -> float:
	return TEXT_CPS[text_speed]

func battle_speed_scale() -> float:
	return BATTLE_SPEEDS[clampi(battle_speed, 0, BATTLE_SPEEDS.size() - 1)]

func cycle_battle_speed() -> void:
	battle_speed = (battle_speed + 1) % BATTLE_SPEEDS.size()

static func _matchup_key(element: int, species: String) -> String:
	return "%d:%s" % [element, species]

## Remembers how well [param element] hit [param species] (called after a hit lands).
func learn_matchup(element: int, species: String, mult: float) -> void:
	known_matchups[_matchup_key(element, species)] = mult

## The multiplier the Tamer knows for [param element] into [param foe], or -1.0 if unknown.
func known_multiplier(element: int, foe: Spirling) -> float:
	if difficulty == Difficulty.STORY:
		return Elements.multiplier(element, foe.elements())
	return float(known_matchups.get(_matchup_key(element, foe.data.species_name), -1.0))

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

## Gives [param s] a held item from the bag (the old one goes back into the bag). "" takes it off.
## Returns false if the item isn't holdable or not in the bag.
func set_held(s: Spirling, id: String) -> bool:
	if not id.is_empty() and (not BattleRules.is_holdable(id) or item_count(id) <= 0):
		return false
	if not s.held.is_empty():
		add_item(s.held)
	s.held = id
	if not id.is_empty():
		inventory[id] = item_count(id) - 1
	return true

## Tamer Gear (grapple_line, climbing_pick, storm_lantern) is a key item in the bag.
func has_gear(id: String) -> bool:
	return item_count(id) > 0

const MENU_ACTION: StringName = &"menu"

func _ready() -> void:
	rng.randomize()
	_register_actions()

func _exit_tree() -> void:
	Loc.uninstall()

func _process(delta: float) -> void:
	if in_game:
		play_time += delta

## Gamepad and keyboard bindings (item 63) added next to Godot's built-in ui_* actions:
## A/B confirm and cancel (the built-in ui_accept/ui_cancel have no pad buttons), Start or
## Select opens the menu, RB cycles battle speed and Y toggles auto battle.
const SPEED_ACTION: StringName = &"battle_speed"
const AUTO_ACTION: StringName = &"battle_auto"
const PAD_BINDINGS: Dictionary[StringName, Array] = {
	&"ui_accept": [JOY_BUTTON_A],
	&"ui_cancel": [JOY_BUTTON_B],
	MENU_ACTION: [JOY_BUTTON_START, JOY_BUTTON_BACK],
	SPEED_ACTION: [JOY_BUTTON_RIGHT_SHOULDER],
	AUTO_ACTION: [JOY_BUTTON_Y],
}
const KEY_BINDINGS: Dictionary[StringName, Array] = {
	MENU_ACTION: [KEY_ESCAPE, KEY_TAB, KEY_M],
	SPEED_ACTION: [KEY_F],
	AUTO_ACTION: [KEY_R],
}

static func _register_actions() -> void:
	for action: StringName in PAD_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b: Variant in PAD_BINDINGS[action]:
			if not _has_pad_button(action, int(b)):
				var pad := InputEventJoypadButton.new()
				pad.button_index = int(b) as JoyButton
				InputMap.action_add_event(action, pad)
	for action: StringName in KEY_BINDINGS:
		for k: Variant in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k) as Key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

static func _has_pad_button(action: StringName, button: int) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false

## A short rumble on every connected gamepad, if rumble is on.
func rumble_pads(strength: float, seconds: float) -> void:
	if not rumble or reduce_motion:
		return
	for d: int in Input.get_connected_joypads():
		Input.start_joy_vibration(d, strength * 0.5, strength, seconds)

## Clears everything for a new game.
func reset() -> void:
	party.clear()
	storage.clear()
	iron_oath = false
	sanctuary.clear()
	spirlog.clear()
	region = "veydal"
	rifts_sealed.clear()
	starter = ""
	difficulty = Difficulty.TAMER
	inventory = {}
	money = 0
	current_map = "lighthouse"
	player_cell = Vector2i(4, 4)
	facing = "down"
	heal_map = "lighthouse"
	heal_cell = Vector2i(4, 4)
	flags = {}
	visited_rests = {}
	records = {}
	switch_progress = {}
	known_matchups = {}
	play_time = 0.0

## Starts a new game with the choices from the new-game flow.
func new_game(p_difficulty: Difficulty, p_name: String, p_color: int, p_starter: String) -> void:
	reset()
	difficulty = p_difficulty
	tamer_name = p_name if not p_name.strip_edges().is_empty() else "Juno"
	tamer_color = clampi(p_color, 0, TAMER_COLORS.size() - 1)
	starter = p_starter
	var s := Spirling.new(Database.species(p_starter), 5, rng)
	receive_spirling(s)
	money = 500
	set_flag("got_starter")
	in_game = true

## Save data (see SaveManager for versioning and atomic writes).
func to_dict() -> Dictionary:
	var party_d: Array = []
	for s: Spirling in party:
		party_d.append(s.to_dict())
	var storage_d: Array = []
	for s: Spirling in storage:
		storage_d.append(s.to_dict())
	return {
		"tamer": {"name": tamer_name, "color": tamer_color},
		"starter": starter,
		"difficulty": difficulty,
		"region": region,
		"rifts": rifts_sealed.duplicate(),
		"party": party_d,
		"storage": storage_d,
		"spirlog": spirlog.duplicate(true),
		"inventory": inventory.duplicate(),
		"money": money,
		"map": current_map,
		"cell": [player_cell.x, player_cell.y],
		"facing": facing,
		"heal_map": heal_map,
		"heal_cell": [heal_cell.x, heal_cell.y],
		"flags": flags.duplicate(),
		"matchups": known_matchups.duplicate(),
		"play_time": play_time,
		"rests": visited_rests.duplicate(true),
		"records": records.duplicate(),
		"switches": switch_progress.duplicate(),
		"iron_oath": iron_oath,
		"sanctuary": sanctuary.map(func(s: Spirling) -> Dictionary: return s.to_dict()),
	}

func from_dict(d: Dictionary) -> void:
	reset()
	var tamer: Dictionary = d.get("tamer", {})
	tamer_name = str(tamer.get("name", "Juno"))
	tamer_color = int(tamer.get("color", 0))
	difficulty = clampi(int(d.get("difficulty", Difficulty.TAMER)), 0, Difficulty.size() - 1) as Difficulty
	region = str(d.get("region", "veydal"))
	rifts_sealed.assign(d.get("rifts", []))
	starter = str(d.get("starter", ""))
	for sd: Variant in d.get("party", []):
		var s: Spirling = Spirling.from_dict(sd)
		if s != null:
			party.append(s)
	for sd: Variant in d.get("storage", []):
		var s: Spirling = Spirling.from_dict(sd)
		if s != null:
			storage.append(s)
	spirlog = (d.get("spirlog", {}) as Dictionary).duplicate(true)
	for k: Variant in (d.get("inventory", {}) as Dictionary):
		inventory[str(k)] = int(d.inventory[k])
	money = int(d.get("money", 0))
	current_map = str(d.get("map", "lighthouse"))
	var c: Array = d.get("cell", [4, 4])
	player_cell = Vector2i(int(c[0]), int(c[1]))
	facing = str(d.get("facing", "down"))
	heal_map = str(d.get("heal_map", "lighthouse"))
	var hc: Array = d.get("heal_cell", [4, 4])
	heal_cell = Vector2i(int(hc[0]), int(hc[1]))
	flags = (d.get("flags", {}) as Dictionary).duplicate()
	for k: Variant in (d.get("matchups", {}) as Dictionary):
		known_matchups[str(k)] = float(d.matchups[k])
	play_time = float(d.get("play_time", 0.0))
	visited_rests = (d.get("rests", {}) as Dictionary).duplicate(true)
	# Saves from before fast travel: the last rest spot used still counts as visited.
	if visited_rests.is_empty() and heal_map != "lighthouse":
		visit_rest(heal_map, heal_cell)
	records = (d.get("records", {}) as Dictionary).duplicate()
	switch_progress = (d.get("switches", {}) as Dictionary).duplicate()
	iron_oath = bool(d.get("iron_oath", false))
	for sd: Variant in d.get("sanctuary", []):
		var s: Spirling = Spirling.from_dict(sd)
		if s != null:
			sanctuary.append(s)
	in_game = true

func settings_to_dict() -> Dictionary:
	return {"text_speed": text_speed, "battle_speed": battle_speed, "auto_battle": auto_battle, "volume": volume,
		"music_volume": music_volume, "sfx_volume": sfx_volume,
		"pad_size": pad_size, "pad_opacity": pad_opacity, "left_handed": left_handed, "tap_to_move": tap_to_move,
		"one_hand": one_hand, "rumble": rumble,
		"tips": tips_enabled, "battery_saver": battery_saver, "reduce_motion": reduce_motion,
		"high_contrast": high_contrast, "day_night": day_night, "language": language}

func settings_from_dict(d: Dictionary) -> void:
	text_speed = clampi(int(d.get("text_speed", TextSpeed.NORMAL)), 0, TextSpeed.size() - 1) as TextSpeed
	# Older settings files only had an on/off fast-forward; map "on" to 2x.
	var legacy: int = 1 if bool(d.get("fast_forward", false)) else 0
	battle_speed = clampi(int(d.get("battle_speed", legacy)), 0, BATTLE_SPEEDS.size() - 1)
	auto_battle = bool(d.get("auto_battle", false))
	pad_size = clampi(int(d.get("pad_size", 1)), 0, PAD_SIZE_NAMES.size() - 1)
	pad_opacity = clampi(int(d.get("pad_opacity", 1)), 0, PAD_ALPHAS.size() - 1)
	left_handed = bool(d.get("left_handed", false))
	tap_to_move = bool(d.get("tap_to_move", true))
	one_hand = bool(d.get("one_hand", false))
	rumble = bool(d.get("rumble", true))
	tips_enabled = bool(d.get("tips", true))
	battery_saver = bool(d.get("battery_saver", false))
	reduce_motion = bool(d.get("reduce_motion", false))
	high_contrast = bool(d.get("high_contrast", false))
	day_night = bool(d.get("day_night", true))
	language = str(d.get("language", ""))
	apply_display()
	volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", 0.7)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", 0.8)), 0.0, 1.0)
	apply_volume()

## Frame cap (battery saver), UI palette (high contrast) and language.
func apply_display() -> void:
	Loc.set_language(language if language != "" else Loc.default_language())
	Engine.max_fps = FPS_BATTERY if battery_saver else FPS_NORMAL
	if UITheme.high_contrast != high_contrast:
		UITheme.set_high_contrast(high_contrast)

func apply_volume() -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), linear_to_db(maxf(sfx_volume, 0.0001)))

## Adds the Music and SFX buses (both feed Master) if the project has none yet.
static func ensure_buses() -> void:
	for bus: StringName in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value

## Fully restores the party (Rest Springs, after a loss).
func heal_party() -> void:
	for s: Spirling in party:
		s.restore()

## Iron Oath: moves every fainted party member to the Sanctuary. Returns their names.
func retire_fainted() -> Array[String]:
	var names: Array[String] = []
	if not iron_oath:
		return names
	for s: Spirling in party.duplicate():
		if s.is_fainted():
			party.erase(s)
			s.restore()
			sanctuary.append(s)
			names.append(s.display_name())
	return names

## Fills an empty party from storage. Returns how many joined.
func fill_party_from_storage() -> int:
	var n: int = 0
	while party.size() < MAX_PARTY and not storage.is_empty():
		party.append(storage.pop_front())
		n += 1
	return n

## Ends the Iron Oath when no Spirling is left: everyone comes back from the Sanctuary.
func break_oath() -> void:
	iron_oath = false
	for s: Spirling in sanctuary:
		s.restore()
		if party.size() < MAX_PARTY:
			party.append(s)
		else:
			storage.append(s)
	sanctuary.clear()
	set_flag("oath_broken")

func first_healthy_index() -> int:
	for i: int in party.size():
		if not party[i].is_fainted():
			return i
	return -1

## Adds a newly bonded Spirling to the party, or to storage if the party is full.
## Returns true if it joined the party.
func receive_spirling(s: Spirling) -> bool:
	mark_seen(s.data.species_name, true)
	s.restore()
	if party.size() < MAX_PARTY:
		party.append(s)
		return true
	storage.append(s)
	return false

func mark_seen(species: String, bonded: bool = false) -> void:
	var e: Dictionary = spirlog.get(species, {"seen": false, "bonded": false})
	e["seen"] = true
	if bonded:
		e["bonded"] = true
	spirlog[species] = e

## Uses a bag item on [param s] outside battle. Returns the message to show, or "" if it had no effect.
func use_item_outside_battle(id: String, s: Spirling) -> String:
	if item_count(id) <= 0:
		return ""
	var it: Dictionary = Database.item(id)
	var msg: String = ""
	if bool(it.get("evolves", false)):
		if not s.can_evolve_with(id):
			return ""
		var old_name: String = s.display_name()
		s.evolve()
		mark_seen(s.data.species_name, true)
		msg = "%s glows with Rift light... and grew into %s!" % [old_name, s.data.species_name]
	elif it.has("teaches"):
		# Echo Crystals are never used up; learning is handled by the menu (it may need a slot).
		return ""
	elif float(it.get("revive", 0.0)) > 0.0:
		if not s.is_fainted():
			return ""
		s.hp = maxi(1, int(s.max_hp() * float(it.revive)))
		msg = "%s is back on its feet!" % s.display_name()
	elif int(it.get("heal", 0)) > 0:
		if s.is_fainted() or s.hp >= s.max_hp():
			return ""
		var healed: int = mini(int(it.heal), s.max_hp() - s.hp)
		s.hp += healed
		msg = "%s recovered %d HP." % [s.display_name(), healed]
	else:
		return ""
	inventory[id] = item_count(id) - 1
	if inventory[id] <= 0:
		inventory.erase(id)
	return msg

func visit_rest(map_id: String, cell: Vector2i) -> void:
	visited_rests[map_id] = [cell.x, cell.y]

## Rest spots other than the one on [param here] (fast travel targets), sorted by map id.
func travel_targets(here: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in visited_rests:
		if str(k) != here:
			out.append(str(k))
	out.sort()
	return out

## Presses switch [param n] (1-based) of a puzzle that needs 1..[param total] in order.
func press_switch(puzzle: String, n: int, total: int) -> SwitchResult:
	var done: int = int(switch_progress.get(puzzle, 0))
	if n != done + 1:
		switch_progress[puzzle] = 0
		return SwitchResult.WRONG
	done += 1
	if done >= total:
		switch_progress.erase(puzzle)
		set_flag(puzzle)
		return SwitchResult.SOLVED
	switch_progress[puzzle] = done
	return SwitchResult.STEP

## Spark values in words, for the Sparkseer: "Kindlop: HP strong, ATK faint, ...".
const SPARK_WORDS: Array[String] = ["faint", "fair", "strong", "brilliant"]

static func spark_word(v: int) -> String:
	return SPARK_WORDS[clampi(v * SPARK_WORDS.size() / (Spirling.SPARK_MAX + 1), 0, SPARK_WORDS.size() - 1)]

func spark_reading(s: Spirling) -> String:
	var parts: PackedStringArray = []
	for key: String in Spirling.STAT_KEYS:
		parts.append("%s %s" % [key.to_upper(), spark_word(int(s.spark.get(key, 0)))])
	return "%s: %s." % [s.display_name(), ", ".join(parts)]

## Raises one Spark value (Spark Charm). Returns false if it's already at the top.
func train_spark(s: Spirling, key: String, amount: int) -> bool:
	var v: int = int(s.spark.get(key, 0))
	if v >= Spirling.SPARK_MAX:
		return false
	var old_max: int = s.max_hp()
	s.spark[key] = mini(Spirling.SPARK_MAX, v + amount)
	if key == "hp":
		s.hp = mini(s.max_hp(), s.hp + s.max_hp() - old_max)
	return true

## True if [param s] can learn the move an Echo Crystal holds (same element, not known yet).
static func can_learn_echo(s: Spirling, item_id: String) -> bool:
	var mv: MoveData = Database.move(str(Database.item(item_id).get("teaches", "")))
	if mv == null:
		return false
	return mv.element in s.elements() and not s.moves.has(mv)

## Moves party member [param index] into storage. Keeps at least one healthy Spirling.
func deposit(index: int) -> bool:
	if index < 0 or index >= party.size() or party.size() <= 1:
		return false
	var s: Spirling = party[index]
	var healthy_left: int = 0
	for i: int in party.size():
		if i != index and not party[i].is_fainted():
			healthy_left += 1
	if healthy_left == 0:
		return false
	party.remove_at(index)
	s.restore()
	storage.append(s)
	return true

func withdraw(index: int) -> bool:
	if index < 0 or index >= storage.size() or party.size() >= MAX_PARTY:
		return false
	party.append(storage[index])
	storage.remove_at(index)
	return true

## Moves party member [param from] to slot [param to], shifting the others (item 56).
func move_party(from: int, to: int) -> void:
	if from < 0 or to < 0 or from >= party.size() or to >= party.size() or from == to:
		return
	var s: Spirling = party[from]
	party.remove_at(from)
	party.insert(to, s)

const STORAGE_SORTS: Array[String] = ["Caught", "Level", "Name", "Spirlog no."]

## Storage indices in display order (item 57): sorted by [param sort] (STORAGE_SORTS index) and
## filtered to [param element] (-1 = all) and a name fragment [param search] (case-insensitive).
func storage_view(sort: int, element: int = -1, search: String = "") -> Array[int]:
	var idx: Array[int] = []
	for i: int in storage.size():
		var s: Spirling = storage[i]
		if element >= 0 and not element in s.elements():
			continue
		if not search.is_empty() and s.display_name().to_lower().find(search.to_lower()) < 0 \
				and s.data.species_name.to_lower().find(search.to_lower()) < 0:
			continue
		idx.append(i)
	match sort:
		1: idx.sort_custom(func(a: int, b: int) -> bool: return storage[a].level > storage[b].level)
		2: idx.sort_custom(func(a: int, b: int) -> bool: return storage[a].display_name() < storage[b].display_name())
		3: idx.sort_custom(func(a: int, b: int) -> bool: return storage[a].data.dex_id < storage[b].data.dex_id)
	return idx

## Swaps two party slots (reordering; slot 0 leads in battle).
func swap_party(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return
	var tmp: Spirling = party[a]
	party[a] = party[b]
	party[b] = tmp
