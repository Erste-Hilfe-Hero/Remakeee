extends Node
## Global player state. Saving and loading go through SaveManager (M4).

## Unbound-style difficulty, picked at new game.
enum Difficulty { STORY, TAMER, VETERAN, RIFT_BORN }
## Level cap per Rift sealed (Veteran + Rift-Born only).
const LEVEL_CAPS: Array[int] = [12, 18, 23, 28, 32, 36, 40, 44, 50]
const AI_LEVELS: Array[int] = [0, 1, 2, 2]
const MAX_PARTY: int = 6
enum TextSpeed { SLOW, NORMAL, FAST }
const TEXT_CPS: Array[float] = [30.0, 60.0, 140.0]

## Tamer customisation (placeholder until real sprites exist).
var tamer_name: String = "Rowan"
var tamer_color: int = 0
const TAMER_COLORS: Array[Color] = [Color("3a5a9a"), Color("9a3a4a"), Color("3a8a5a"), Color("8a6a2a")]
## Seconds played (shown on the save card).
var play_time: float = 0.0
## True while a game is running (the title screen sets it); saving on pause needs it.
var in_game: bool = false

var party: Array[Spirling] = []
## Storage box for Spirlings beyond the party of 6.
var storage: Array[Spirling] = []
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
## First-time tips (see Tips.gd).
var tips_enabled: bool = true
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
		set_flag("pc_unlocked")
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

## Tamer Gear (grapple_line, climbing_pick, storm_lantern) is a key item in the bag.
func has_gear(id: String) -> bool:
	return item_count(id) > 0

const MENU_ACTION: StringName = &"menu"

func _ready() -> void:
	rng.randomize()
	_register_actions()

func _process(delta: float) -> void:
	if in_game:
		play_time += delta

## Adds the "menu" action (Esc / Tab / gamepad Start) next to the built-in ui_* actions.
func _register_actions() -> void:
	if InputMap.has_action(MENU_ACTION):
		return
	InputMap.add_action(MENU_ACTION)
	for key: Key in [KEY_ESCAPE, KEY_TAB, KEY_M]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(MENU_ACTION, ev)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	InputMap.action_add_event(MENU_ACTION, pad)

## Clears everything for a new game.
func reset() -> void:
	party.clear()
	storage.clear()
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
	known_matchups = {}
	play_time = 0.0

## Starts a new game with the choices from the new-game flow.
func new_game(p_difficulty: Difficulty, p_name: String, p_color: int, p_starter: String) -> void:
	reset()
	difficulty = p_difficulty
	tamer_name = p_name if not p_name.strip_edges().is_empty() else "Rowan"
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
	}

func from_dict(d: Dictionary) -> void:
	reset()
	var tamer: Dictionary = d.get("tamer", {})
	tamer_name = str(tamer.get("name", "Rowan"))
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
	in_game = true

func settings_to_dict() -> Dictionary:
	return {"text_speed": text_speed, "battle_speed": battle_speed, "auto_battle": auto_battle, "volume": volume,
		"music_volume": music_volume, "sfx_volume": sfx_volume,
		"pad_size": pad_size, "pad_opacity": pad_opacity, "left_handed": left_handed, "tap_to_move": tap_to_move,
		"tips": tips_enabled}

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
	tips_enabled = bool(d.get("tips", true))
	volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", 0.7)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", 0.8)), 0.0, 1.0)
	apply_volume()

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
	if float(it.get("revive", 0.0)) > 0.0:
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

## Swaps two party slots (reordering; slot 0 leads in battle).
func swap_party(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return
	var tmp: Spirling = party[a]
	party[a] = party[b]
	party[b] = tmp
