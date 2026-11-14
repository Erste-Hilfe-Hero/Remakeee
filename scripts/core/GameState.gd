extends Node
## Global player state. Saving and loading go through SaveManager (M4).

## Difficulty, picked at new game. Rift-Born adds the Master AI (tier 3).
enum Difficulty { STORY, TAMER, VETERAN, RIFT_BORN }
## Level cap per Rift sealed (Veteran + Rift-Born only).
const LEVEL_CAPS: Array[int] = [12, 15, 18, 23, 28, 32, 36, 40, 44, 50, 54, 57, 60]
const AI_LEVELS: Array[int] = [0, 1, 2, 3]
## Plan area 2, items 726-728: Wayfarer Spark in every stat, ring shift of a shared team, and the
## share of damage foes deal, per difficulty (Story, Tamer, Veteran, Rift-Born).
const FOE_SPARK: Array[int] = [0, 3, 6, 10]
const FOE_LEVEL_SHIFT: Array[int] = [-1, 0, 1, 2]
const FOE_DAMAGE: Array[float] = [0.9, 1.0, 1.0, 1.0]
## Factor on a Rift boss's "hp_per_ally" per difficulty (item 729).
const BOSS_HP_SCALE: Array[float] = [0.8, 1.0, 1.0, 1.0]
## A shifted foe never stands more than this many rings above the player's ring cap.
const FOE_OVER_CAP: int = 2
const MAX_PARTY: int = 5

## Team size now: MAX_PARTY, one more with the shop's sixth team slot (plan area 10, unlock
## team_slot_6) and one more with the seventh (pay-to-win step 6, unlock team_slot_7); the server
## allows the same in saves.
func party_max() -> int:
	return MAX_PARTY + ShopEffects.extra_team_places()
enum TextSpeed { SLOW, NORMAL, FAST }
const TEXT_CPS: Array[float] = [30.0, 60.0, 140.0]

## Wayfarer customisation (placeholder until real sprites exist).
var tamer_name: String = "Juno"
var tamer_color: int = 0
## Boy or girl, picked first at new game. Index into TAMER_SPRITES / DEFAULT_NAMES.
var tamer_look: int = 0
## Shop jacket worn (unlock key such as "jacket_moss", item 4277); "" for the free colour.
var jacket: String = ""
## Shop battle backdrop shown (unlock key such as "backdrop_moon_lake", item 4281); "" for none.
var backdrop_look: String = ""
## Shop text frame on the dialogue box (unlock key such as "frame_vine", item 4282); "" for none.
var text_frame: String = ""
## Shop hat worn by the Wayfarer (unlock key such as "hat_tricorn", item 4283); "" for none.
var hat_look: String = ""
## Shop profile frame on the friend list (unlock key such as "card_frame_star", item 4284).
var card_frame: String = ""
## Shop greeting card motif put on gifts to friends (unlock key such as "gift_card_moth", item 4285).
var gift_card: String = ""
const TAMER_SPRITES: Array[String] = ["tamer", "tamer_f"]
const DEFAULT_NAMES: Array[String] = ["Corin", "Liora"]
## Coat colours on the title screen: teal, rust, ochre, plum (boy = teal, girl = rust by default).
const TAMER_COLORS: Array[Color] = [Color("2f7f7a"), Color("a2502e"), Color("b08a2e"), Color("6a3f6e")]
## Wayfarer look picked at new game (Ali, 7 Nov): skin tone and hair colour, indexes below.
var skin_tone: int = 0
var hair_color: int = 0
const SKIN_TONES: Array[Color] = [Color("f2e3c2"), Color("e8c9a0"), Color("c99a6b"), Color("9a6a43"), Color("6b4429")]
const SKIN_NAMES: Array[String] = ["Light", "Fair", "Tan", "Brown", "Deep"]
const HAIR_COLORS: Array[Color] = [Color("6a4256"), Color("2a2a33"), Color("6e4a2a"), Color("a2502e"), Color("d8b45a"), Color("b8b8c4")]
const HAIR_NAMES: Array[String] = ["Plum", "Black", "Brown", "Auburn", "Blond", "Silver"]
const COAT_NAMES: Array[String] = ["Teal", "Rust", "Ochre", "Plum"]
const TAMER_SHADER: String = "res://shaders/tamer_palette.gdshader"
## Seconds played (shown on the save card).
var play_time: float = 0.0
## True while a game is running (the title screen sets it); saving on pause needs it.
var in_game: bool = false

var party: Array[Spirling] = []
## The own team while a weekly loan team is out (plan 3192); saves always keep this one.
var party_on_loan: Array[Spirling] = []
## Storage box for Spirlings beyond the party of 6.
var storage: Array[Spirling] = []
## Named storage boxes [{"name", "color"}] (plan area 1, item 375). Spirling.box points here.
var storage_boxes: Array[Dictionary] = []
## Extra boxes beyond STORAGE_BOXES_START (the shop's "+1 box" fills this, area 10).
var storage_box_bonus: int = 0
## Running shop boosts (Growth Crystal, Coin Gleam): {"growth": {"mult": 2.0, "left": 20}, ...}.
## Counted down after every battle by ShopEffects.battle_done().
var shop_boosts: Dictionary = {}
## Saved teams [{"name", "uids": [uid...]}], at most TEAM_PRESETS (item 378).
var team_presets: Array[Dictionary] = []
## Gleam chain (GleamRules.next_chain): the kind met last in the wild and how often in a row.
var gleam_chain: Dictionary = {"species": "", "count": 0}
## Echo Cores from singing together (Nachhall, plan area 1, items 183-185):
## [{"kind", "parents": [species, species], "rests", "wins"}].
var echo_cores: Array[Dictionary] = []
## Iron Oath (item 15, opt-in at new game): Spirlings that faint retire to the Sanctuary.
var iron_oath: bool = false
var sanctuary: Array[Spirling] = []
## Spirlog: species name -> entry (see new_spirlog_entry()).
var spirlog: Dictionary = {}
var region: String = "veydal"
var rifts_sealed: Array[String] = []
## Species name of the partner picked at the start (the rival counter-picks against it).
var starter: String = ""
var difficulty: Difficulty = Difficulty.TAMER
## Item id -> count.
var inventory: Dictionary = {}
## Things gained since the satchel last had them in focus: id -> true (item 1918).
var new_items: Dictionary = {}
## What the player last saw behind a start menu row (MenuDots, item 1872): label -> value.
var menu_seen: Dictionary = {}
var money: int = 0
## Waymarks (plan area 8): earned only by playing, never bought or traded. Change through Waymarks.earn().
var waymarks: int = 0
## Today's daily tasks and their progress (see DailyTasks.gd): {"day", "tasks": [{"id", "n"}], "bonus"}.
var daily_tasks: Dictionary = {}
## Festival ribbons per festival (see Festival.gd): "<id>_<year>" -> {"ribbons", "earned", "stages", "task"}.
var festival_ribbons: Dictionary = {}
## Short reward notes waiting to be shown by the overworld (not saved).
var notices: Array[String] = []

## Overworld position.
var current_map: String = "lighthouse"
var player_cell: Vector2i = Vector2i(4, 4)
var facing: String = "down"
## Where the team wakes up after a loss (last Rest Spring used).
var heal_map: String = "lighthouse"
var heal_cell: Vector2i = Vector2i(4, 4)
## Set while a battle runs (item 630): a save made then and loaded later means the app closed mid-battle.
var battle_open: bool = false
## True after a load settled such a battle as a loss, until the overworld shows its note (not saved).
var left_battle: bool = false
## Story and world flags, e.g. "got_starter", "rift_1_sealed".
var flags: Dictionary = {}
## Rest spots the player has used: map id -> [x, y] (fast travel between them).
var visited_rests: Dictionary = {}
## Outdoor maps entered: map id -> [x, y] of the last entry. The shop's Signpost (plan items 4836,
## 4837) lets fast travel reach all of them, not only rest spots.
var visited_maps: Dictionary = {}
## Survey (area 3 item 1245): map id -> PackedByteArray, one bit per cell seen (Survey.gd).
var map_cells: Dictionary = {}
## Own world map marks (item 1273): [{"map", "x", "y", "icon"}], at most Survey.MAX_MARKS.
var map_marks: Array = []
## Personal bests, e.g. "gauntlet_best".
var records: Dictionary = {}
## Story numbers such as kestra_trust (dialogue actions set_var / add_var, plan item 1339).
var story_vars: Dictionary = {}
## Story decisions: choice id -> picked answer id (plan item 1680). "_v" is the format version.
var story_choices: Dictionary = {}
const STORY_CHOICES_VERSION: int = 1
## Puzzle progress: puzzle id -> number of switches pressed in the right order so far.
var switch_progress: Dictionary = {}
## World changes that must survive saving, per map id (area 3 item 905): pushed boulders,
## broken floor, laid planks, hung ladders. See PuzzleRoom.
var world_state: Dictionary = {}
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
## Bench lessons: healthy team members that did not fight get BENCH_XP_SHARE of a fighter's XP.
var bench_xp: bool = true
## Wild Ward (shop, pay-to-win step 6, plan point 37): while on and bought, no wild Spirling steps out.
var wild_ward: bool = false
const BENCH_XP_SHARE: float = 0.5
## Damage preview: the move list shows the expected share of the foe's HP once its matchup is known.
var damage_preview: bool = true
## Big buttons in the battle menu (KAMPF_PLAN items 623, 896), in the battle's More list and Settings, Game.
var big_buttons: bool = false
## Simple battle text (KAMPF_PLAN_1000 902): battle lines in short, plain words (BattleEvent.easy).
var easy_battle_text: bool = false:
	set(v):
		easy_battle_text = v
		BattleEvent.easy = v
## Damage numbers over a hit Spirling (KAMPF_PLAN_1000 671), off by default.
var damage_numbers: bool = false
## Bonus goals of Wayfarers and Wardens (plan area 2, item 765); off hides them and their rewards.
var bonus_goals: bool = true
var volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
## Own levels for the text voice and cries, and for ambience loops (item 2556).
var voice_volume: float = 0.9
var ambience_volume: float = 0.9
## Mixes everything to mono for one-sided hearing (item 2555).
var mono_audio: bool = false
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
## Sub-buses of SFX (item 2547): menu sounds, cries and text voice, ambience loops.
const BUS_UI: StringName = &"UI"
const BUS_VOICE: StringName = &"Voice"
const BUS_AMBIENCE: StringName = &"Ambience"
## Ceiling of the Master limiter (item 2548).
const LIMITER_CEILING_DB: float = -1.0
## Touch controls: pad size and opacity (index into PAD_SIZES / PAD_ALPHAS), left-handed layout, tap-to-move.
var pad_size: int = 1
var pad_opacity: int = 2
var left_handed: bool = false
var tap_to_move: bool = true
## Walking is running; holding B walks slowly instead (item 1810).
var always_run: bool = false
## How a bond is made: "mine" taps one big button fast (owner, 9 Nov), "echo" repeats the call.
var bond_style: String = "mine"
## "calm" is the echo without a time limit (Kampf-Plan, Barrierefreiheit).
const BOND_STYLES: Array[String] = ["mine", "echo", "calm"]
## Tap guard step for menus (BattleCalm.INPUT_DELAYS_MS, KAMPF_PLAN_1000 item 908).
var input_delay: int = 0
## "No rush" (item 632): battle text waits for a tap at any speed, bonding is the calm echo.
var no_rush: bool = false
## A and B change places (item 2111), apart for the touch pad and for gamepads.
var swap_ab_touch: bool = false
var swap_ab_pad: bool = false
## A 15 ms buzz on every tapped choice in menus, off by default (item 1791).
var tap_vibration: bool = false
## One-hand layout (item 79): D-pad and buttons stacked on one side of the screen.
var one_hand: bool = false
## Satchel order (item 1917): 0 newest first, 1 by name, 2 by kind. Kept with the settings.
var bag_sort: int = 0
## Vibration on phones and gamepads (items 63, 2590): 0 Off, 1 Weak, 2 Full.
var vibration: int = 2
## Screen shake in battle and the world (item 2259): 0 Off, 1 Weak, 2 Full.
var screen_shake: int = 2
## Short captions for important sounds at the top edge (item 2653).
var sound_captions: bool = false
## Text voice blips while dialogue types (items 2503, 2504).
var text_voice: bool = true
## World talk moves on by itself after a short read (item 2015).
var auto_text: bool = false
## First-time tips (see Tips.gd).
var tips_enabled: bool = true
## Break reminder after PlayReminder.MINUTES of play (plan 3503).
var play_reminder: bool = true
## Display and accessibility (items 59, 76, 78).
var battery_saver: bool = false
var reduce_motion: bool = false
var high_contrast: bool = false
## Colour-blind mode (design items 178, 274, 479): battle bars and matchups use shapes, not colour alone.
var color_blind: bool = false
## Large text with the 7x12 glyph set (item 2042).
var large_text: bool = false
## Day and night tint and encounters on outdoor maps (item 43).
var day_night: bool = true
## Weather in the world (area 3 item 1145); off means always clear.
var weather: bool = true
## Minimap (area 3 item 1272): "on", "off" or "outdoor" (only outside).
var minimap: String = "on"
## Game language (item 62): a Loc.LANGUAGES code, or "" for the device language.
var language: String = ""
const FPS_NORMAL: int = 60
const FPS_BATTERY: int = 30
## A fourth size "Very large" (item 1816) and five opacity steps (item 1817).
const PAD_SIZE_NAMES: Array[String] = ["Small", "Medium", "Large", "Very large"]
const PAD_ALPHAS: Array[float] = [0.15, 0.3, 0.55, 0.7, 0.85]
## Settings saved before item 1817 had three steps (30, 55, 85 %): their index in the new list.
const OLD_PAD_ALPHA_STEPS: Array[int] = [1, 2, 4]

## What the Wayfarer has learned about matchups: "element:species" -> multiplier seen on a hit.
## Story difficulty shows every matchup from the start.
var known_matchups: Dictionary = {}

## Mended Rifts needed before the storage box opens from the menu (end of Act I).
const RIFTS_FOR_STORAGE: int = 2
## Every story Rift in story order (owner decision 2026-11-10: twelve Rifts, the last three in
## Solenne, Act IV). The Undrawn opens once all of them and every Rift heart are mended.
const STORY_RIFTS: Array[String] = ["cinder", "mist", "tide", "rain", "mirror", "root", "kiln", "glass", "shade", "tower", "oasis", "sun"]
## The Rifts of Veydal: once all are mended, Kestra waits at the dock (flag VEYDAL_RIFTS_FLAG).
const VEYDAL_RIFTS: Array[String] = ["cinder", "mist", "tide"]
const VEYDAL_RIFTS_FLAG: String = "veydal_rifts_mended"
## Rifts with a heart battle after the mend ("<id>_heart_mended").
const RIFT_HEARTS: Array[String] = ["cinder", "mist", "tide"]

## Flags the way into the Undrawn waits for: every story Rift mended and every Rift heart.
static func finale_flags() -> Array[String]:
	var out: Array[String] = []
	for r: String in STORY_RIFTS:
		out.append("rift_%s_sealed" % r)
	for r: String in RIFT_HEARTS:
		out.append(r + "_heart_mended")
	return out
## Story flag at the end of Act I ("Waiting for the Ferry" starts).
const ACT1_END_FLAG: String = "aldo_dock_told"

## Ring a Spirling can grow to now. No top ring (owner decision 2026-11-12): on Tamer and below,
## and on every difficulty after Act I, Spirlings grow without limit (Spirling.LEVEL_SANITY is only
## a guard against broken data). Veteran and Rift-Born keep their Act I Warden caps (LEVEL_CAPS).
func level_cap() -> int:
	if not has_ring_limit():
		return Spirling.LEVEL_SANITY
	return mini(progress_cap() + ShopEffects.ring_cap_bonus(), Spirling.LEVEL_SANITY)

## True while a difficulty ring limit holds (Veteran and up, before the end of Act I).
func has_ring_limit() -> bool:
	return difficulty >= Difficulty.VETERAN and not has_flag(ACT1_END_FLAG)

## Marks a Rift as sealed (raises the level cap on Veteran and up). Returns false if it already was.
func seal_rift(rift_id: String) -> bool:
	if rift_id in rifts_sealed:
		return false
	rifts_sealed.append(rift_id)
	set_flag("rift_%s_sealed" % rift_id)
	if VEYDAL_RIFTS.all(func(r: String) -> bool: return r in rifts_sealed):
		set_flag(VEYDAL_RIFTS_FLAG)
	# Rifts can be mended in any order; the second one opens storage from the menu.
	if rifts_sealed.size() >= RIFTS_FOR_STORAGE:
		set_flag("storage_remote")
		# Achievement "Small Band": both Rifts mended with three Spirlings or fewer.
		if party.size() + storage.size() <= 3:
			records["small_band"] = 1
	return true

## Ring cap by story progress for every difficulty (the Veteran caps). Endgame echoes (weekly
## challenge, lighthouse climb) use it, so raising one Spirling high does not change them.
## After Act I (ACT1_END_FLAG) it is Spirling.STORY_RING (plan 3287), so Master Wayfarers and
## the endgame use the whole story ring range; the player's own Spirlings are not capped by it.
func progress_cap() -> int:
	if has_flag(ACT1_END_FLAG):
		return Spirling.STORY_RING
	return LEVEL_CAPS[mini(rifts_sealed.size(), LEVEL_CAPS.size() - 1)]

func items_allowed_in_battle() -> bool:
	return difficulty != Difficulty.RIFT_BORN

## Trainer AI tier for the current difficulty: 0 random, 1 greedy, 2 lookahead, 3 master.
## Changes the difficulty in a running game (item 746). It holds from the next battle on (the
## menu cannot open mid-battle); a step down marks records["difficulty_lowered"] for good.
func set_difficulty(d: int) -> void:
	d = clampi(d, 0, Difficulty.size() - 1)
	ChallengeRules.note_difficulty(d)
	if d < int(difficulty):
		records["difficulty_lowered"] = true
	difficulty = d as Difficulty

func difficulty_lowered() -> bool:
	return bool(records.get("difficulty_lowered", false))

func ai_level() -> int:
	return AI_LEVELS[difficulty]

## Share of damage the foe side deals (Story softens every hit, item 728).
func foe_damage_mult() -> float:
	return FOE_DAMAGE[difficulty]

func text_cps() -> float:
	return TEXT_CPS[text_speed]

func battle_speed_scale() -> float:
	return BATTLE_SPEEDS[clampi(battle_speed, 0, BATTLE_SPEEDS.size() - 1)]

## XP share for the bench in battles (0 when Bench lessons is off).
func bench_share() -> float:
	# The shop's Team Growth Band (plan item 4343): every healthy member gets the fighters' full share.
	if Billing.unlocked("share_band") > 0:
		return 1.0
	return BENCH_XP_SHARE if bench_xp and ShopEffects.owns_setting("bench_lessons") else 0.0

func cycle_battle_speed() -> void:
	battle_speed = (battle_speed + 1) % BATTLE_SPEEDS.size()

static func _matchup_key(element: int, species: String) -> String:
	return "%d:%s" % [element, species]

## Remembers how well [param element] hit [param species] (called after a hit lands).
func learn_matchup(element: int, species: String, mult: float) -> void:
	known_matchups[_matchup_key(element, species)] = mult

## The multiplier the Wayfarer knows for [param element] into [param foe], or -1.0 if unknown.
func known_multiplier(element: int, foe: Spirling) -> float:
	if difficulty == Difficulty.STORY:
		return Elements.multiplier(element, foe.elements())
	return float(known_matchups.get(_matchup_key(element, foe.data.species_name), -1.0))

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	if count > 0:
		new_items[id] = true
	if count > 0 and BattleRules.is_holdable(id):
		Achievements.note_keepsake(id)

## Takes one [param id] out of the bag; an empty entry goes away. Returns false if there was none.
## Temper Shift (shop item 4743): sets [param s]'s temperament to [param temper_id] and uses
## the item up. False when nothing would change.
func shift_temper(s: Spirling, temper_id: String, item_id: String = "rg_temper_shift") -> bool:
	if item_count(item_id) <= 0 or Spirling.temper_info(temper_id).id != temper_id or s.temperament().id == temper_id:
		return false
	s.temper = temper_id
	return take_item(item_id)

## Gleam Prism (shop item 4791): the chosen Spirling takes its Gleam form for good.
func use_gleam_prism(s: Spirling, item_id: String = "rg_gleam_prism") -> bool:
	if item_count(item_id) <= 0 or s.gleam_boost:
		return false
	s.gleam = true
	s.gleam_boost = true
	note_gleam_bonded(s)
	return take_item(item_id)

## Power Core (shop item 4750): doubles the lean of a temperament that leans toward a stat.
func use_power_core(s: Spirling, item_id: String = "rg_temper_amp") -> bool:
	if item_count(item_id) <= 0 or s.temper_core or str(s.temperament().stat).is_empty():
		return false
	s.temper_core = true
	return take_item(item_id)

func take_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	inventory[id] = item_count(id) - 1
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	return true

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
		take_item(id)
		if s in party:
			Vows.broke("no_keepsake")
	# Some keepsakes raise max Vigor (Core Glass); taking one off must not leave too much Vigor.
	s.hp = mini(s.hp, s.max_hp())
	return true

## Wayfarer Gear (grapple_line, climbing_pick, storm_lantern) is a key item in the bag.
func has_gear(id: String) -> bool:
	return item_count(id) > 0

## Saved world changes for [param map_id] (PuzzleRoom state), or {}.
func world_of(map_id: String) -> Dictionary:
	return world_state.get(map_id, {})

func set_world_of(map_id: String, state: Dictionary) -> void:
	if state.is_empty():
		world_state.erase(map_id)
	else:
		world_state[map_id] = state

## Gear item ids the player owns (for PuzzleRoom.passable).
func owned_gear() -> Array:
	var out: Array = []
	for k: int in TilesetFactory.GEAR_KINDS:
		if has_gear(TilesetFactory.GEAR_KINDS[k]):
			out.append(TilesetFactory.GEAR_KINDS[k])
	return out

const MENU_ACTION: StringName = &"menu"

func _ready() -> void:
	rng.randomize()
	_register_actions()
	apply_pad_swap(swap_ab_pad)

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
## Keyboard (item 2110, web build): arrows or W A S D walk, Enter or Space confirm (built in),
## Escape or Backspace go back, M opens the menu. Escape also opens the menu while walking.
const KEY_BINDINGS: Dictionary[StringName, Array] = {
	&"ui_up": [KEY_W],
	&"ui_down": [KEY_S],
	&"ui_left": [KEY_A],
	&"ui_right": [KEY_D],
	&"ui_cancel": [KEY_BACKSPACE],
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

## Puts gamepad A and B on confirm and back, or the other way round (item 2111).
static func apply_pad_swap(swap: bool) -> void:
	var pairs: Array = [[&"ui_accept", JOY_BUTTON_A, JOY_BUTTON_B], [&"ui_cancel", JOY_BUTTON_B, JOY_BUTTON_A]]
	for p: Array in pairs:
		var action: StringName = p[0]
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
				InputMap.action_erase_event(action, e)
		var pad := InputEventJoypadButton.new()
		pad.button_index = (int(p[2]) if swap else int(p[1])) as JoyButton
		InputMap.action_add_event(action, pad)

static func _has_pad_button(action: StringName, button: int) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false

## A short rumble on every connected gamepad, if rumble is on.
func rumble_pads(strength: float, seconds: float) -> void:
	if vibration <= 0 or reduce_motion:
		return
	strength *= 0.5 if vibration == 1 else 1.0
	for d: int in Input.get_connected_joypads():
		Input.start_joy_vibration(d, strength * 0.5, strength, seconds)

## Clears everything for a new game.
func reset() -> void:
	party.clear()
	party_on_loan = []
	storage.clear()
	storage_boxes = default_boxes()
	storage_box_bonus = 0
	shop_boosts = {}
	jacket = ""
	backdrop_look = ""
	text_frame = ""
	hat_look = ""
	card_frame = ""
	gift_card = ""
	team_presets.clear()
	gleam_chain = {"species": "", "count": 0}
	echo_cores.clear()
	iron_oath = false
	sanctuary.clear()
	spirlog.clear()
	region = "veydal"
	rifts_sealed.clear()
	starter = ""
	difficulty = Difficulty.TAMER
	inventory = {}
	new_items = {}
	menu_seen = {}
	money = 0
	waymarks = 0
	daily_tasks = {}
	festival_ribbons = {}
	notices.clear()
	current_map = "lighthouse"
	player_cell = Vector2i(4, 4)
	facing = "down"
	heal_map = "lighthouse"
	heal_cell = Vector2i(4, 4)
	battle_open = false
	left_battle = false
	flags = {}
	visited_rests = {}
	visited_maps = {}
	map_cells = {}
	map_marks = []
	records = endgame_defaults({})
	story_vars = {}
	story_choices = {}
	switch_progress = {}
	world_state = {}
	known_matchups = {}
	play_time = 0.0

## Starts a new game with the choices from the new-game flow. With an empty [param p_starter]
## the partner is picked later, in the prologue at the lighthouse (see choose_starter).
## The Wayfarer's jacket colour: a worn shop jacket while it is owned, else the free colour.
func body_color() -> Color:
	var c: String = ShopCatalog.jacket_color(jacket)
	if not c.is_empty() and Billing.unlocked(jacket) > 0:
		return Color(c)
	return TAMER_COLORS[clampi(tamer_color, 0, TAMER_COLORS.size() - 1)]

## Material that paints the Wayfarer sheet in the picked skin, hair and coat colours.
func tamer_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TAMER_SHADER)
	m.set_shader_parameter("skin", SKIN_TONES[clampi(skin_tone, 0, SKIN_TONES.size() - 1)])
	m.set_shader_parameter("hair", HAIR_COLORS[clampi(hair_color, 0, HAIR_COLORS.size() - 1)])
	m.set_shader_parameter("coat", body_color())
	return m

## The worn hat kind (HatArt.KINDS) while the unlock is owned, else "".
func worn_hat() -> String:
	if hat_look.begins_with("hat_") and Billing.unlocked(hat_look) > 0:
		return hat_look.trim_prefix("hat_")
	return ""

## The worn profile frame kind (FriendsMenu.CARD_FRAMES) while the unlock is owned, else "".
func profile_frame() -> String:
	if card_frame.begins_with("card_frame_") and Billing.unlocked(card_frame) > 0:
		return card_frame.trim_prefix("card_frame_")
	return ""

## The greeting card motif (FriendsMenu.GIFT_CARDS) while the unlock is owned, else "".
func gift_motif() -> String:
	if gift_card.begins_with("gift_card_") and Billing.unlocked(gift_card) > 0:
		return gift_card.trim_prefix("gift_card_")
	return ""

## The dialogue frame kind: the worn shop frame while owned, else "" (the plain box).
func dialogue_frame() -> String:
	if text_frame.begins_with("frame_") and Billing.unlocked(text_frame) > 0:
		return text_frame.trim_prefix("frame_")
	return ""

## The backdrop kind for normal battles: the worn shop backdrop while owned, else "".
func battle_backdrop() -> String:
	if backdrop_look.begins_with("backdrop_") and Billing.unlocked(backdrop_look) > 0:
		return backdrop_look.trim_prefix("backdrop_")
	return ""

## Kin Charms every new game starts with (Ali, 7 Nov: 20 free bond items).
const START_KIN_CHARMS: int = 20
## Below this many Spirlings (team and storage) the player counts as new: a failed bond gives
## the wild Spirling no free hit.
const NEWCOMER_SPIRLINGS: int = 6

## True while the player has fewer than NEWCOMER_SPIRLINGS Spirlings in team and storage.
func is_newcomer() -> bool:
	return party.size() + storage.size() < NEWCOMER_SPIRLINGS

func new_game(p_difficulty: Difficulty, p_name: String, p_color: int, p_starter: String, p_look: int = 0, p_skin: int = 0, p_hair: int = 0) -> void:
	reset()
	difficulty = p_difficulty
	skin_tone = clampi(p_skin, 0, SKIN_TONES.size() - 1)
	hair_color = clampi(p_hair, 0, HAIR_COLORS.size() - 1)
	tamer_look = clampi(p_look, 0, TAMER_SPRITES.size() - 1)
	tamer_name = p_name.strip_edges() if not p_name.strip_edges().is_empty() else DEFAULT_NAMES[tamer_look]
	tamer_color = clampi(p_color, 0, TAMER_COLORS.size() - 1)
	money = 500
	# Easier start (Ali, 7 Nov): 20 free Kin Charms for the first bonds.
	add_item("kin_charm", START_KIN_CHARMS)
	in_game = true
	if not p_starter.is_empty():
		choose_starter(p_starter)

## The partner Spirling joins at level 5 (prologue, or straight from new_game in tests).
func choose_starter(species: String) -> void:
	starter = species
	var s := Spirling.new(Database.species(species), 5, rng)
	receive_spirling(s)
	set_flag("got_starter")

## Overworld sprite sheet for the player.
func tamer_sprite() -> String:
	return TAMER_SPRITES[clampi(tamer_look, 0, TAMER_SPRITES.size() - 1)]

## Save data (see SaveManager for versioning and atomic writes).
## Endgame records (plan area 8, item 3540) and their empty defaults. A loaded save keeps each
## one only if it has the right type, so a damaged entry starts fresh instead of breaking a screen.
const ENDGAME_RECORDS: Dictionary = {
	"album": {}, "album_stickers": [], "echo_path": {}, "expeditions": [], "world_events": {},
	"masters": {}, "season_path": {}, "exchange": {}, "weekly": {}, "memorial": [],
	"waymark_log": [], "achievements": {}, "achievements_paid": {}, "collection": {},
}

## Fills the endgame records with their defaults where missing or of the wrong type.
static func endgame_defaults(rec: Dictionary) -> Dictionary:
	for k: String in ENDGAME_RECORDS:
		var def: Variant = ENDGAME_RECORDS[k]
		var have: Variant = rec.get(k)
		if have == null or typeof(have) != typeof(def):
			rec[k] = def.duplicate()
	return rec

func to_dict() -> Dictionary:
	var party_d: Array = []
	for s: Spirling in (party_on_loan if not party_on_loan.is_empty() else party):
		party_d.append(s.to_dict())
	var storage_d: Array = []
	for s: Spirling in storage:
		storage_d.append(s.to_dict())
	return {
		"tamer": {"name": tamer_name, "color": tamer_color, "look": tamer_look, "skin": skin_tone, "hair": hair_color, "jacket": jacket, "backdrop": backdrop_look, "frame": text_frame, "hat": hat_look, "card_frame": card_frame, "gift_card": gift_card},
		"starter": starter,
		"difficulty": difficulty,
		"region": region,
		"rifts": rifts_sealed.duplicate(),
		"party": party_d,
		"storage": storage_d,
		"storage_boxes": storage_boxes.duplicate(true),
		"storage_box_bonus": storage_box_bonus,
		"shop_boosts": shop_boosts.duplicate(true),
		"team_presets": team_presets.duplicate(true),
		"gleam_chain": gleam_chain.duplicate(),
		"echo_cores": echo_cores.duplicate(true),
		"spirlog": spirlog.duplicate(true),
		"inventory": _bag_counts(),
		"menu_seen": menu_seen.duplicate(),
		"new_items": new_items.keys().filter(func(k: Variant) -> bool: return int(inventory.get(k, 0)) > 0),
		"money": money,
		"waymarks": waymarks,
		"daily_tasks": daily_tasks.duplicate(true),
		"festival_ribbons": festival_ribbons.duplicate(true),
		"map": current_map,
		"cell": [player_cell.x, player_cell.y],
		"facing": facing,
		"heal_map": heal_map,
		"heal_cell": [heal_cell.x, heal_cell.y],
		"battle_open": battle_open,
		"flags": flags.duplicate(),
		"matchups": known_matchups.duplicate(),
		"play_time": play_time,
		"rests": visited_rests.duplicate(true),
		"maps_entered": visited_maps.duplicate(true),
		"map_cells": Survey.cells_to_save(map_cells),
		"map_marks": map_marks.duplicate(true),
		"records": records.duplicate(true),
		"story_vars": story_vars.duplicate(),
		"story_choices": story_choices.duplicate(),
		"switches": switch_progress.duplicate(),
		"world": world_state.duplicate(true),
		"iron_oath": iron_oath,
		"sanctuary": sanctuary.map(func(s: Spirling) -> Dictionary: return s.to_dict()),
	}

## The bag for the save: items used up in battle or handed to a Spirling leave no empty rows.
func _bag_counts() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in inventory:
		if int(inventory[k]) > 0:
			out[k] = inventory[k]
	return out

## Highest boost a save may carry: the Mighty Growth Crystal's x5 (it used to load as x3, bug plan 1357).
const MAX_BOOST_MULT: float = 5.0

func from_dict(d: Dictionary) -> void:
	reset()
	var wayfarer: Dictionary = d.get("tamer", {})
	tamer_name = str(wayfarer.get("name", "Juno"))
	tamer_color = as_int(wayfarer.get("color", 0))
	tamer_look = clampi(as_int(wayfarer.get("look", 0)), 0, TAMER_SPRITES.size() - 1)
	skin_tone = clampi(as_int(wayfarer.get("skin", 0)), 0, SKIN_TONES.size() - 1)
	hair_color = clampi(as_int(wayfarer.get("hair", 0)), 0, HAIR_COLORS.size() - 1)
	jacket = str(wayfarer.get("jacket", "")) if wayfarer.get("jacket") is String else ""
	backdrop_look = str(wayfarer.get("backdrop", "")) if wayfarer.get("backdrop") is String else ""
	text_frame = str(wayfarer.get("frame", "")) if wayfarer.get("frame") is String else ""
	hat_look = str(wayfarer.get("hat", "")) if wayfarer.get("hat") is String else ""
	card_frame = str(wayfarer.get("card_frame", "")) if wayfarer.get("card_frame") is String else ""
	gift_card = str(wayfarer.get("gift_card", "")) if wayfarer.get("gift_card") is String else ""
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
	_load_boxes(d)
	shop_boosts = {}
	if d.get("shop_boosts") is Dictionary:
		for k: Variant in d.shop_boosts:
			var b: Variant = d.shop_boosts[k]
			# Every boost the shop sells survives a reload, not only Growth and Coins (bug plan 1357).
			if str(k) in ShopEffects.BOOST_NAMES and b is Dictionary and int(b.get("left", 0)) > 0:
				shop_boosts[str(k)] = {"mult": clampf(float(b.get("mult", 1.0)), 1.0, MAX_BOOST_MULT), "left": mini(int(b.left), 200)}
	_load_echo_cores(d.get("echo_cores", []))
	var gc: Dictionary = _as_dict(d.get("gleam_chain", {}))
	gleam_chain = {"species": str(gc.get("species", "")), "count": clampi(as_int(gc.get("count", 0)), 0, GleamRules.chain_max())}
	for k: Variant in _as_dict(d.get("spirlog", {})):
		spirlog[str(k)] = upgrade_spirlog_entry((d.spirlog[k] as Variant))
	# Only real counts: an empty or negative entry would swallow the next item of that kind
	# (bug plan 1380).
	for k: Variant in _as_dict(d.get("inventory", {})):
		var n: int = as_int(d.inventory[k])
		if n > 0:
			inventory[str(k)] = n
	new_items = {}
	menu_seen = {}
	var seen_rows: Variant = d.get("menu_seen", {})
	if seen_rows is Dictionary:
		for k: Variant in seen_rows:
			menu_seen[str(k)] = as_int(seen_rows[k])
	var fresh: Variant = d.get("new_items", [])
	for k: Variant in (fresh as Array if fresh is Array else []):
		if inventory.has(str(k)):
			new_items[str(k)] = true
	money = int(d.get("money", 0))
	# Saves from before plan area 8 start with no Waymarks; old achievements pay out once
	# through the achievement reward, never here.
	waymarks = clampi(as_int(d.get("waymarks", 0)), 0, Waymarks.CAP)
	var dt: Variant = d.get("daily_tasks", {})
	daily_tasks = (dt as Dictionary).duplicate(true) if dt is Dictionary else {}
	festival_ribbons = {}
	for k: Variant in as_dict(d.get("festival_ribbons", {})):
		var st: Dictionary = as_dict(d.festival_ribbons[k])
		festival_ribbons[str(k)] = {"ribbons": maxi(0, as_int(st.get("ribbons", 0))), "earned": maxi(0, as_int(st.get("earned", 0))),
			"stages": clampi(as_int(st.get("stages", 0)), 0, Festival.STAGES.size()), "task": as_dict(st.get("task", {})).duplicate(true)}
	current_map = str(d.get("map", "lighthouse"))
	var c: Array = d.get("cell", [4, 4])
	player_cell = Vector2i(int(c[0]), int(c[1]))
	facing = str(d.get("facing", "down"))
	heal_map = str(d.get("heal_map", "lighthouse"))
	var hc: Array = d.get("heal_cell", [4, 4])
	heal_cell = Vector2i(int(hc[0]), int(hc[1]))
	flags = _as_dict(d.get("flags", {}))
	var mu: Dictionary = _as_dict(d.get("matchups", {}))
	for k: Variant in mu:
		if mu[k] is float or mu[k] is int:
			known_matchups[str(k)] = float(mu[k])
	play_time = float(d.get("play_time", 0.0))
	visited_rests = _as_dict(d.get("rests", {}))
	visited_maps = _as_dict(d.get("maps_entered", {}))
	map_cells = Survey.cells_from_save(d.get("map_cells", {}))
	map_marks = Survey.marks_from_save(d.get("map_marks", []))
	# Saves from before fast travel: the last rest spot used still counts as visited.
	if visited_rests.is_empty() and heal_map != "lighthouse":
		visit_rest(heal_map, heal_cell)
	records = endgame_defaults(_as_dict(d.get("records", {})))
	var sv: Dictionary = _as_dict(d.get("story_vars", {}))
	for k: Variant in sv:
		if sv[k] is int or sv[k] is float:
			story_vars[str(k)] = int(sv[k])
	story_choices = _as_dict(d.get("story_choices", {}))
	story_fixups()
	switch_progress = _as_dict(d.get("switches", {}))
	world_state = _as_dict(d.get("world", {}))
	iron_oath = bool(d.get("iron_oath", false))
	for sd: Variant in d.get("sanctuary", []):
		var s: Spirling = Spirling.from_dict(sd)
		if s != null:
			sanctuary.append(s)
	battle_open = bool(d.get("battle_open", false))
	settle_open_battle()
	in_game = true

func settings_to_dict() -> Dictionary:
	return {"text_speed": text_speed, "battle_speed": battle_speed, "auto_battle": auto_battle,
		"bench_xp": bench_xp, "wild_ward": wild_ward, "damage_preview": damage_preview, "big_buttons": big_buttons, "easy_battle_text": easy_battle_text, "damage_numbers": damage_numbers, "bonus_goals": bonus_goals, "volume": volume,
		"music_volume": music_volume, "sfx_volume": sfx_volume,
		"voice_volume": voice_volume, "ambience_volume": ambience_volume, "mono_audio": mono_audio,
		"pad_size": pad_size, "pad_opacity": pad_opacity, "pad_opacity_steps": PAD_ALPHAS.size(), "left_handed": left_handed, "tap_to_move": tap_to_move,
		"always_run": always_run, "bond_style": bond_style, "input_delay": input_delay, "no_rush": no_rush, "swap_ab_touch": swap_ab_touch, "swap_ab_pad": swap_ab_pad, "tap_vibration": tap_vibration,
		"one_hand": one_hand, "bag_sort": bag_sort, "vibration": vibration, "screen_shake": screen_shake,
		"sound_captions": sound_captions, "text_voice": text_voice, "auto_text": auto_text,
		"tips": tips_enabled, "play_reminder": play_reminder, "battery_saver": battery_saver, "reduce_motion": reduce_motion,
		"high_contrast": high_contrast, "color_blind": color_blind, "large_text": large_text, "day_night": day_night, "weather": weather, "minimap": minimap, "language": language}

func settings_from_dict(d: Dictionary) -> void:
	text_speed = clampi(int(d.get("text_speed", TextSpeed.NORMAL)), 0, TextSpeed.size() - 1) as TextSpeed
	# Older settings files only had an on/off fast-forward; map "on" to 2x.
	var legacy: int = 1 if bool(d.get("fast_forward", false)) else 0
	battle_speed = clampi(int(d.get("battle_speed", legacy)), 0, BATTLE_SPEEDS.size() - 1)
	auto_battle = bool(d.get("auto_battle", false))
	bench_xp = bool(d.get("bench_xp", true))
	wild_ward = bool(d.get("wild_ward", false))
	damage_preview = bool(d.get("damage_preview", true))
	big_buttons = bool(d.get("big_buttons", false))
	easy_battle_text = bool(d.get("easy_battle_text", false))
	damage_numbers = bool(d.get("damage_numbers", false))
	bonus_goals = bool(d.get("bonus_goals", true))
	pad_size = clampi(int(d.get("pad_size", 1)), 0, PAD_SIZE_NAMES.size() - 1)
	if d.has("pad_opacity") and not d.has("pad_opacity_steps"):
		pad_opacity = OLD_PAD_ALPHA_STEPS[clampi(int(d.pad_opacity), 0, OLD_PAD_ALPHA_STEPS.size() - 1)]
	else:
		pad_opacity = clampi(int(d.get("pad_opacity", 2)), 0, PAD_ALPHAS.size() - 1)
	left_handed = bool(d.get("left_handed", false))
	tap_to_move = bool(d.get("tap_to_move", true))
	always_run = bool(d.get("always_run", false))
	bond_style = str(d.get("bond_style", "mine")) if str(d.get("bond_style", "mine")) in BOND_STYLES else "mine"
	input_delay = clampi(int(d.get("input_delay", 0)), 0, BattleCalm.INPUT_DELAYS_MS.size() - 1)
	no_rush = bool(d.get("no_rush", false))
	swap_ab_touch = bool(d.get("swap_ab_touch", false))
	swap_ab_pad = bool(d.get("swap_ab_pad", false))
	tap_vibration = bool(d.get("tap_vibration", false))
	apply_pad_swap(swap_ab_pad)
	one_hand = bool(d.get("one_hand", false))
	bag_sort = clampi(int(d.get("bag_sort", 0)), 0, 2)
	# Older settings had an on/off "rumble"; on maps to Full vibration.
	var legacy_rumble: int = 2 if bool(d.get("rumble", true)) else 0
	vibration = clampi(int(d.get("vibration", legacy_rumble)), 0, 2)
	screen_shake = clampi(int(d.get("screen_shake", 2)), 0, 2)
	sound_captions = bool(d.get("sound_captions", false))
	text_voice = bool(d.get("text_voice", true))
	auto_text = bool(d.get("auto_text", false))
	tips_enabled = bool(d.get("tips", true))
	play_reminder = bool(d.get("play_reminder", true))
	battery_saver = bool(d.get("battery_saver", false))
	reduce_motion = bool(d.get("reduce_motion", false))
	high_contrast = bool(d.get("high_contrast", false))
	color_blind = bool(d.get("color_blind", false))
	large_text = bool(d.get("large_text", false))
	day_night = bool(d.get("day_night", true))
	weather = bool(d.get("weather", true))
	minimap = str(d.get("minimap", "on")) if str(d.get("minimap", "on")) in Survey.MINIMAP_MODES else "on"
	language = str(d.get("language", ""))
	apply_display()
	volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", 0.7)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", 0.8)), 0.0, 1.0)
	voice_volume = clampf(float(d.get("voice_volume", 0.9)), 0.0, 1.0)
	ambience_volume = clampf(float(d.get("ambience_volume", 0.9)), 0.0, 1.0)
	mono_audio = bool(d.get("mono_audio", false))
	apply_volume()

## Frame cap (battery saver), UI palette (high contrast) and language.
func apply_display() -> void:
	Loc.set_language(language if language != "" else Loc.default_language())
	Engine.max_fps = FPS_BATTERY if battery_saver else FPS_NORMAL
	if UITheme.high_contrast != high_contrast:
		UITheme.set_high_contrast(high_contrast)
	UITheme.set_large_text(large_text)

## Extra Master gain (not saved): Sound fades it to 0 while the app is in the background.
var master_fade: float = 1.0

func apply_volume() -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume * master_fade, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_VOICE), linear_to_db(maxf(voice_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMBIENCE), linear_to_db(maxf(ambience_volume, 0.0001)))
	var mono: int = mono_effect_index()
	if mono >= 0:
		AudioServer.set_bus_effect_enabled(0, mono, mono_audio)

## Index of the mono mix on Master: a stereo enhance with no pan pull-out folds left and right
## into the middle (item 2555). -1 before ensure_buses adds it.
static func mono_effect_index() -> int:
	for i: int in AudioServer.get_bus_effect_count(0):
		var fx: AudioEffect = AudioServer.get_bus_effect(0, i)
		if fx is AudioEffectStereoEnhance and is_zero_approx((fx as AudioEffectStereoEnhance).pan_pullout):
			return i
	return -1

## Adds the Music and SFX buses (both feed Master), the UI, Voice and Ambience buses under SFX,
## and a hard limiter on Master, where the project does not have them yet.
static func ensure_buses() -> void:
	for pair: Array in [[BUS_MUSIC, &"Master"], [BUS_SFX, &"Master"], [BUS_UI, BUS_SFX], [BUS_VOICE, BUS_SFX], [BUS_AMBIENCE, BUS_SFX]]:
		if AudioServer.get_bus_index(pair[0]) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, pair[0])
			AudioServer.set_bus_send(idx, pair[1])
	if mono_effect_index() < 0:
		var mono := AudioEffectStereoEnhance.new()
		mono.pan_pullout = 0.0
		AudioServer.add_bus_effect(0, mono, 0)
		AudioServer.set_bus_effect_enabled(0, 0, false)
	for i: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(0, lim)

## Keeps older saves on the story path: saves that lit the lamp room before Act I got its
## ending already have the ferry open (plan item 1405).
func story_fixups() -> void:
	if has_flag("mirela_lamp") and not has_flag("ferry_corvane_open"):
		set_flag("ferry_corvane_open")
		set_flag("scene_act1_finale_seen")
	# Area 3's road from Corvane Quay to Madderby opens with the arrival scene.
	if has_flag("corvane_arrived") and not has_flag("madderby_road_open"):
		set_flag("madderby_road_open")

## A story number (0 if never set).
func story_var(name: String) -> int:
	return int(story_vars.get(name, 0))

func set_story_var(name: String, value: int) -> void:
	story_vars[name] = value

func add_story_var(name: String, amount: int) -> void:
	story_vars[name] = story_var(name) + amount

## Remembers a story decision (plan item 1680).
func record_choice(id: String, answer: String) -> void:
	story_choices[id] = answer
	story_choices["_v"] = STORY_CHOICES_VERSION

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value

## Rolls every Spark of [param s] anew (0..SPARK_MAX), as a freshly met Spirling gets them.
static func reroll_sparks(s: Spirling, r: RandomNumberGenerator) -> void:
	var frac: float = s.hp_fraction()
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = r.randi_range(0, Spirling.SPARK_MAX)
	s.hp = 0 if s.is_fainted() else maxi(1, roundi(frac * s.max_hp()))

## Fully restores the party (Rest Springs, after a loss).
## Item 630: on Rift-Born a battle left by closing the app counts as a loss, so it is no
## way out. Fainted Spirlings retire under the Iron Oath, the team rests, and the Wayfarer
## wakes at the last spring. Other difficulties just drop the flag. True when it applied.
func settle_open_battle() -> bool:
	var open: bool = battle_open
	battle_open = false
	left_battle = false
	if not open or difficulty != Difficulty.RIFT_BORN:
		return false
	retire_fainted()
	heal_party()
	ChallengeRules.after_rest(party)
	current_map = heal_map
	player_cell = heal_cell
	facing = "down"
	left_battle = true
	notices.append(Loc.t("The battle was left open. On Rift-Born that counts as a loss, and your team wakes at the last spring."))
	return true

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
			# Memorial book (plan 3397): name, ring, place and date of every retirement.
			var book: Array = records.get("memorial", []) if records.get("memorial", []) is Array else []
			book.append({"name": s.display_name(), "species": s.data.species_name, "level": s.level,
				"map": current_map, "date": Time.get_date_string_from_unix_time(Online.unix_now())})
			records["memorial"] = book
	return names

## Fills an empty party from storage. Returns how many joined.
func fill_party_from_storage() -> int:
	var n: int = 0
	for s: Spirling in storage.duplicate():
		if party.size() >= party_max():
			break
		if Expeditions.is_away(s.uid):
			continue
		storage.erase(s)
		party.append(s)
		n += 1
	return n

## Ends the Iron Oath when no Spirling is left: everyone comes back from the Sanctuary.
func break_oath() -> void:
	iron_oath = false
	for s: Spirling in sanctuary:
		s.restore()
		if party.size() < party_max():
			party.append(s)
		else:
			_store(s, true)
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
	if s.origin_map.is_empty():
		s.origin_map = current_map
		# Looked up by path: a direct EraManager reference would tie the two autoload scripts together.
		var era: Node = get_node_or_null("/root/EraManager")
		s.origin_era = int(era.get("unlocked_era")) if era != null else 1
		s.met_ring = s.level
		s.met_day = today()
	mark_seen(s.data.species_name, true)
	note_spirlog(s)
	note_gleam_bonded(s)
	s.restore()
	if party.size() < party_max():
		party.append(s)
		return true
	_store(s, true)
	return false

## A Spirlog entry: seen and bonded, where and on which day it was first seen, and the
## regional imprints, Prism colours and temperaments met so far (plan area 1, item 7).
static func new_spirlog_entry() -> Dictionary:
	return {"seen": false, "bonded": false, "first_map": "", "first_day": 0,
		"variants": [], "prism_seen": false, "gleam_seen": false, "gleam_bonded": false, "tempers": [], "maps": [], "battles": 0}

## Fills missing fields of an older Spirlog entry ({"seen", "bonded"} only) with defaults.
static func upgrade_spirlog_entry(e: Variant) -> Dictionary:
	var out: Dictionary = new_spirlog_entry()
	if e is Dictionary:
		var src: Dictionary = (e as Dictionary).duplicate(true)
		for k: Variant in src:
			out[str(k)] = src[k]
	out["seen"] = out.seen is bool and out.seen or out.bonded is bool and out.bonded
	out["bonded"] = out.bonded is bool and out.bonded
	out["first_day"] = int(out.first_day) if out.first_day is int or out.first_day is float else 0
	out["battles"] = int(out.battles) if out.battles is int or out.battles is float else 0
	out["first_map"] = out.first_map if out.first_map is String else ""
	out["prism_seen"] = out.prism_seen is bool and out.prism_seen
	out["gleam_bonded"] = out.gleam_bonded is bool and out.gleam_bonded
	out["gleam_seen"] = out.gleam_seen is bool and out.gleam_seen or out.gleam_bonded
	for k: String in ["variants", "tempers", "maps"]:
		if not out[k] is Array:
			out[k] = []
	return out

## A copy of v if it is a Dictionary, else {} (saves can be damaged or edited).
static func _as_dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}

## Damaged-save guards: a number (or bool) as int, anything else -> [param fallback].
static func as_int(v: Variant, fallback: int = 0) -> int:
	if v is int or v is bool:
		return int(v)
	if v is float:
		return int(clampf(v, -1e15, 1e15))
	return fallback

static func as_bool(v: Variant) -> bool:
	return bool(v) if v is bool or v is int or v is float else false

## True when the clock went back before [param stored] (a day, week, month or season key that
## sorts by time, e.g. "2026-11-06", "2026-W45", "2026-11", "2026-Q4"). Timed content keeps its
## stored state then, so setting a clock back never resets and pays the same goal twice
## (plan 3497).
static func time_went_back(stored: String, now: String) -> bool:
	return stored != "" and now < stored

static func as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

## Pays [param coins] from townsfolk [param who] once per day (story var "tip_<who>" holds the
## last day). Returns the coins paid, 0 when [param who] already paid today. The day comes from
## the server clock, and a day before the stored one pays nothing (plan 1379: turning the phone
## clock back and forth gives no extra tips).
func pay_tip(who: String, coins: int, day: int = -1) -> int:
	if day < 0:
		day = int(Online.unix_now() / 86400.0)
	var key: String = "tip_" + who
	if coins <= 0 or day <= int(story_vars.get(key, -1)):
		return 0
	story_vars[key] = day
	money += coins
	return coins

## Days since 1970 (local device date), for "met on day N".
static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func mark_seen(species: String, bonded: bool = false) -> void:
	var e: Dictionary = upgrade_spirlog_entry(spirlog.get(species, {}))
	if not bool(e.seen):
		e["first_map"] = current_map
		e["first_day"] = today()
	e["seen"] = true
	if bonded:
		e["bonded"] = true
	if not current_map.is_empty() and not (e.maps as Array).has(current_map):
		(e.maps as Array).append(current_map)
	spirlog[species] = e

## After a battle: each kind in the team counts one more battle travelled together
## (its third Spirlog lore sentence opens after SpirlogBook.LORE_BATTLES).
func note_battle_end() -> void:
	var done: Dictionary = {}
	for s: Spirling in party:
		var sp: String = s.data.species_name
		if done.has(sp):
			continue
		done[sp] = true
		var e: Dictionary = upgrade_spirlog_entry(spirlog.get(sp, {}))
		e["battles"] = int(e.battles) + 1
		spirlog[sp] = e

## An Echo call ended with [param score]: a fully right call adds one to every team member's
## streak, a miss starts them over (unfold rule "echo_streak", Hushkin to Silentra).
func note_echo(score: float) -> void:
	for s: Spirling in party:
		s.echo_streak = s.echo_streak + 1 if score >= 1.0 else 0

## A Gleam joined (bond, trade, gift): its kind's Spirlog entry counts a Gleam bonded.
func note_gleam_bonded(s: Spirling) -> void:
	if not s.gleam:
		return
	var e: Dictionary = upgrade_spirlog_entry(spirlog.get(s.data.species_name, {}))
	e["gleam_seen"] = true
	e["gleam_bonded"] = true
	spirlog[s.data.species_name] = e

## Records what [param s] shows the Spirlog: its Prism colour, imprint and temperament.
func note_spirlog(s: Spirling, show_temper: bool = true) -> void:
	var e: Dictionary = upgrade_spirlog_entry(spirlog.get(s.data.species_name, {}))
	if s.prism:
		e["prism_seen"] = true
	if s.gleam:
		e["gleam_seen"] = true
	if not s.variant.is_empty() and not (e.variants as Array).has(s.variant):
		(e.variants as Array).append(s.variant)
	var t: String = str(s.temperament().id)
	if show_temper and not (e.tempers as Array).has(t):
		(e.tempers as Array).append(t)
	spirlog[s.data.species_name] = e

## Furls [param s] back into its earlier form. A form that needed an item to unfurl (Tide
## Pearl) gives the item back, so "you can unfurl it again later" stays true.
func furl_back(s: Spirling) -> void:
	var prev: SpirlingData = s.earlier_form()
	if prev == null:
		return
	s.furl_back()
	if not prev.evolve_item.is_empty():
		add_item(prev.evolve_item)

## Uses a bag item on [param s] outside battle. Returns the message to show, or "" if it had no effect.
func use_item_outside_battle(id: String, s: Spirling) -> String:
	if item_count(id) <= 0:
		return ""
	var it: Dictionary = Database.item(id)
	var msg: String = ""
	if bool(it.get("evolves", false)):
		# The shop's Riftglass Tide Shell (pay-to-win step 6) unfurls like the item it names.
		if not s.can_evolve_with(str(it.get("unfurls_as", id))):
			return ""
		var old_name: String = s.display_name()
		s.evolve()
		mark_seen(s.data.species_name, true)
		msg = "%s unfurls into %s!" % [old_name, s.data.species_name]
	elif bool(it.get("unfurl_any", false)):
		# The shop's Unfurl Spark (pay-to-win step 5, plan point 32): the next form without its
		# Ring or other conditions, never a form that needs an item (furling back would hand one out).
		var to: SpirlingData = ShopEffects.unfurl_spark_target(s)
		if to == null:
			return ""
		var old_name: String = s.display_name()
		s.evolve(to)
		mark_seen(s.data.species_name, true)
		msg = "%s unfurls into %s!" % [old_name, s.data.species_name]
	elif bool(it.get("gift_slot", false)):
		# The shop's Second Gift Slot (pay-to-win step 6, plan point 12): the line's hidden gift works too.
		if not ShopEffects.can_open_gift_slot(s):
			return ""
		s.gift_slot = true
		msg = "%s now carries two gifts: %s and %s." % [s.display_name(), Loc.t(str(BattleRules.trait_info(s.gift_id()).get("label", ""))),
			Loc.t(str(BattleRules.trait_info(ShopEffects.second_gift_id(s)).get("label", "")))]
	elif it.has("teaches"):
		# Echo Crystals are never used up; learning is handled by the menu (it may need a slot).
		return ""
	elif int(it.get("rings", 0)) > 0 or int(it.get("rings_to", 0)) > 0:
		# Ring Tonics and the Ring Crown from the shop: never above the Ring cap (plan item 4341)
		# nor above the story ring, so bought rings stop at 60; past it Spirlings grow by battling.
		var goal: int = int(it.rings_to) if int(it.get("rings_to", 0)) > 0 else s.level + int(it.rings)
		var target: int = mini(goal, mini(level_cap(), Spirling.STORY_RING))
		if s.level >= target:
			return ""
		var from: int = s.level
		while s.level < target:
			s.level_up()
		s.xp = Spirling.xp_for_level(s.level)
		msg = "%s grew from Ring %d to Ring %d!" % [s.display_name(), from, s.level]
	elif bool(it.get("spark_reset", false)):
		# Spark Flux (KAMPF_PLAN_1000 item 230): every Spark is rolled anew.
		reroll_sparks(s, rng)
		msg = "%s's sparks flicker and settle anew." % s.display_name()
	elif bool(it.get("spark_all", false)):
		var raised: bool = false
		for key: String in Spirling.STAT_KEYS:
			raised = train_spark(s, key, Spirling.SPARK_MAX) or raised
		if not raised:
			return ""
		msg = "All of %s's sparks shine at the top." % s.display_name()
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
		msg = "%s recovered %d Vigor." % [s.display_name(), healed]
	else:
		return ""
	inventory[id] = item_count(id) - 1
	if inventory[id] <= 0:
		inventory.erase(id)
	return msg

func visit_rest(map_id: String, cell: Vector2i) -> void:
	visited_rests[map_id] = [cell.x, cell.y]

## Remembers where the player came into outdoor map [param map_id] (Signpost targets).
func enter_map(map_id: String, cell: Vector2i) -> void:
	visited_maps[map_id] = [cell.x, cell.y]

## Where fast travel to [param map_id] lands: its rest spot, else (with the Signpost) the last
## entry. Empty when it is no target.
func travel_cell(map_id: String) -> Array:
	if visited_rests.has(map_id):
		return visited_rests[map_id]
	if Billing.unlocked("fast_travel") > 0 and visited_maps.has(map_id):
		return visited_maps[map_id]
	return []

## Rest spots other than the one on [param here] (fast travel targets), sorted by map id.
func travel_targets(here: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in visited_rests:
		if str(k) != here:
			out.append(str(k))
	if Billing.unlocked("fast_travel") > 0:
		for k: Variant in visited_maps:
			if str(k) != here and not out.has(str(k)):
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

## [param s] learns the move of Echo Crystal or Rift Script [param item_id], in place of move
## [param forget] when it already knows 4. Rift Scripts from the shop are used up by this (plan
## item 4452); Echo Crystals stay. Returns false when nothing was learned.
func learn_from_item(s: Spirling, item_id: String, forget: int = -1) -> bool:
	if not can_learn_echo(s, item_id) or item_count(item_id) <= 0:
		return false
	var mv: MoveData = Database.move(str(Database.item(item_id).teaches))
	if s.moves.size() < Spirling.MAX_MOVES:
		s.moves.append(mv)
	elif forget >= 0 and forget < s.moves.size():
		s.moves[forget] = mv
	else:
		return false
	if bool(Database.item(item_id).get("used_up", false)):
		take_item(item_id)
	return true

## Move Memory (shop item 4457): arts [param s] could know at its Ring but does not.
static func relearnable(s: Spirling) -> Array[String]:
	var out: Array[String] = []
	for name: String in LeagueRules.learnable(s.data, s.level):
		if not s.moves.any(func(m: MoveData) -> bool: return m.move_name == name):
			out.append(name)
	return out

## Relearns [param move_name] with the Move Memory unlock, in place of [param forget] when full.
func relearn(s: Spirling, move_name: String, forget: int = -1) -> bool:
	if Billing.unlocked("move_memory") <= 0 or not move_name in relearnable(s):
		return false
	var mv: MoveData = Database.move(move_name)
	if mv == null:
		return false
	if s.moves.size() < Spirling.MAX_MOVES:
		s.moves.append(mv)
	elif forget >= 0 and forget < s.moves.size():
		s.moves[forget] = mv
	else:
		return false
	return true

## True if [param s] can learn the move an Echo Crystal holds (same element, not known yet).
## Crystals with "any_element" teach every Spirling (item 574: Scatter Gale, Graft).
static func can_learn_echo(s: Spirling, item_id: String) -> bool:
	var it: Dictionary = Database.item(item_id)
	var mv: MoveData = Database.move(str(it.get("teaches", "")))
	if mv == null or s.moves.has(mv):
		return false
	if bool(it.get("any_element", false)) or mv.element in s.elements():
		return true
	# "for_elements": a teacher of a later era also takes Spirlings of these elements.
	for e: Variant in it.get("for_elements", []):
		if Elements.E.has(str(e)) and Elements.E[str(e)] in s.elements():
			return true
	return false

## Moves party member [param index] into storage. Keeps at least one healthy Spirling.
## With [param keep_keepsake] its keepsake goes back into the satchel (item 356).
func deposit(index: int, keep_keepsake: bool = false) -> bool:
	if index < 0 or index >= party.size() or party.size() <= 1 or storage.size() >= storage_capacity():
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
	if keep_keepsake and not s.held.is_empty():
		add_item(s.held)
		s.held = ""
	_store(s, true)
	Vows.check_team()
	return true

func withdraw(index: int) -> bool:
	if index < 0 or index >= storage.size() or party.size() >= party_max():
		return false
	# Spirlings on a roaming trip stay away until they are home (plan 3448).
	if Expeditions.is_away(storage[index].uid):
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

const STORAGE_SORTS: Array[String] = ["Caught", "Ring", "Name", "Spirlog no."]

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

# --- Storage boxes, favourites, release and team presets (plan area 1, items 375-382) ----

const BOX_SIZE: int = 30
const STORAGE_BOXES_START: int = 8
## Most Spirlings one multi-select moves at once (item 376).
const MULTI_MOVE_MAX: int = 10
const TEAM_PRESETS: int = 6
## Box colours the player can pick (UITheme tints by name).
const BOX_COLORS: Array[String] = ["ink", "moss", "tide", "ember", "sun", "dusk", "stone", "rose"]

static func default_boxes(count: int = STORAGE_BOXES_START) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in count:
		out.append({"name": "Box %d" % (i + 1), "color": BOX_COLORS[i % BOX_COLORS.size()]})
	return out

func storage_box_count() -> int:
	return STORAGE_BOXES_START + maxi(storage_box_bonus, 0)

func storage_capacity() -> int:
	return storage_box_count() * BOX_SIZE

## Brings storage_boxes up to storage_box_count() (new shop boxes, old saves).
func ensure_boxes() -> void:
	while storage_boxes.size() < storage_box_count():
		var i: int = storage_boxes.size()
		storage_boxes.append({"name": "Box %d" % (i + 1), "color": BOX_COLORS[i % BOX_COLORS.size()]})

func _load_boxes(d: Dictionary) -> void:
	storage_box_bonus = maxi(0, int(d.storage_box_bonus)) if d.get("storage_box_bonus") is int or d.get("storage_box_bonus") is float else 0
	storage_boxes.clear()
	var raw: Variant = d.get("storage_boxes", [])
	for b: Variant in (raw if raw is Array else []):
		if b is Dictionary:
			var color: String = str((b as Dictionary).get("color", "ink"))
			storage_boxes.append({"name": str((b as Dictionary).get("name", "Box %d" % (storage_boxes.size() + 1))).left(BOX_NAME_MAX),
				"color": color if color in BOX_COLORS else "ink"})
	ensure_boxes()
	team_presets.clear()
	var pr: Variant = d.get("team_presets", [])
	for p: Variant in (pr if pr is Array else []):
		if p is Dictionary and (p as Dictionary).get("uids") is Array and team_presets.size() < TEAM_PRESETS:
			var uids: Array = ((p as Dictionary).uids as Array).map(func(x: Variant) -> String: return str(x))
			team_presets.append({"name": str((p as Dictionary).get("name", "")), "uids": uids.slice(0, MAX_PARTY + 2)})
	# Old saves had one flat list: spread it over the boxes in order.
	var fill: Array[int] = []
	fill.resize(storage_boxes.size())
	for s: Spirling in storage:
		if s.box >= storage_boxes.size() or fill[s.box] >= BOX_SIZE:
			s.box = _free_box(fill)
		fill[s.box] += 1

## First box index with room, given the current fill per box (last box if all are full).
func _free_box(fill: Array[int]) -> int:
	for i: int in fill.size():
		if fill[i] < BOX_SIZE:
			return i
	return maxi(fill.size() - 1, 0)

const BOX_NAME_MAX: int = 16

func box_fill() -> Array[int]:
	var fill: Array[int] = []
	fill.resize(maxi(storage_boxes.size(), 1))
	for s: Spirling in storage:
		if s.box < fill.size():
			fill[s.box] += 1
	return fill

## Storage indices of the Spirlings in box [param box].
func box_members(box: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in storage.size():
		if storage[i].box == box:
			out.append(i)
	return out

func rename_box(box: int, new_name: String) -> void:
	if box >= 0 and box < storage_boxes.size() and not new_name.strip_edges().is_empty():
		storage_boxes[box]["name"] = new_name.strip_edges().left(BOX_NAME_MAX)

func recolor_box(box: int) -> String:
	if box < 0 or box >= storage_boxes.size():
		return ""
	var i: int = BOX_COLORS.find(str(storage_boxes[box].color))
	storage_boxes[box]["color"] = BOX_COLORS[(i + 1) % BOX_COLORS.size()]
	return str(storage_boxes[box].color)

## Puts a Spirling into storage, in the first box with room. False when storage is full.
func _store(s: Spirling, force: bool = false) -> bool:
	ensure_boxes()
	if storage.size() >= storage_capacity() and not force:
		return false
	s.box = _free_box(box_fill())
	storage.append(s)
	return true

## Moves up to MULTI_MOVE_MAX storage Spirlings into [param box] (item 376). Favourites only
## move when [param include_favorites] is set (one at a time, after asking). Returns how many moved.
func move_to_box(indices: Array[int], box: int, include_favorites: bool = false) -> int:
	if box < 0 or box >= storage_boxes.size():
		return 0
	var room: int = BOX_SIZE - box_fill()[box]
	var moved: int = 0
	for i: int in indices:
		if moved >= MULTI_MOVE_MAX or room <= 0:
			break
		if i < 0 or i >= storage.size() or storage[i].box == box:
			continue
		if storage[i].favorite and not include_favorites:
			continue
		storage[i].box = box
		moved += 1
		room -= 1
	return moved

func toggle_favorite(s: Spirling) -> bool:
	s.favorite = not s.favorite
	return s.favorite

## Releases storage Spirling [param index] back to where it was found (item 379).
## Never a favourite; only from storage, so the team always keeps its healthy members.
## Returns the goodbye line, or "" when it cannot be released.
func release(index: int) -> String:
	if index < 0 or index >= storage.size() or storage[index].favorite:
		return ""
	var s: Spirling = storage[index]
	storage.remove_at(index)
	Released.remember(s)
	if not s.held.is_empty():
		add_item(s.held)
		s.held = ""
	var home: String = Spirling.place_name(s.origin_map) if not s.origin_map.is_empty() else ""
	if home.is_empty():
		return "%s looks back once, then runs off into the grass." % s.display_name()
	return "%s looks back once, then heads home to %s." % [s.display_name(), home]

## Saves the current team as preset [param slot] (item 378).
func save_preset(slot: int, preset_name: String = "") -> bool:
	if slot < 0 or slot >= TEAM_PRESETS or party.is_empty():
		return false
	var uids: Array = []
	for s: Spirling in party:
		uids.append(s.uid)
	var entry: Dictionary = {"name": preset_name if not preset_name.is_empty() else "Team %d" % (slot + 1), "uids": uids}
	while team_presets.size() <= slot:
		team_presets.append({"name": "", "uids": []})
	team_presets[slot] = entry
	return true

## The team preset [param slot] would give, from party and storage, or [] if it cannot load.
func preset_team(slot: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	if slot < 0 or slot >= team_presets.size():
		return out
	for u: Variant in team_presets[slot].get("uids", []):
		var s: Spirling = _find_uid(str(u))
		if s != null and not out.has(s):
			out.append(s)
	return out

func _find_uid(u: String) -> Spirling:
	if u.is_empty():
		return null
	for s: Spirling in party + storage:
		if s.uid == u:
			return s
	return null

## Loads preset [param slot] with one tap at a spring: members come out of storage, the rest
## rests. Never leaves the team without a healthy member and never overfills storage.
func load_preset(slot: int) -> bool:
	var team: Array[Spirling] = preset_team(slot).slice(0, party_max())
	if team.is_empty():
		return false
	var healthy: bool = false
	for s: Spirling in team:
		if not s.is_fainted() or storage.has(s):
			healthy = true
	if not healthy:
		return false
	var leaving: Array[Spirling] = []
	for s: Spirling in party:
		if not team.has(s):
			leaving.append(s)
	var arriving: int = 0
	for s: Spirling in team:
		if storage.has(s):
			arriving += 1
	if storage.size() - arriving + leaving.size() > storage_capacity():
		return false
	for s: Spirling in team:
		if storage.has(s):
			storage.erase(s)
	for s: Spirling in leaving:
		s.restore()
		_store(s, true)
	party.assign(team)
	return true

# --- Nachhall: singing together at an Echo spring (plan area 1, items 183-185) ------------

## Cores wake from won battles or rests only, never from walking (legal review, item 186).
const ECHO_CORE_RESTS: int = 5
const ECHO_CORE_WINS: int = 30
const MAX_ECHO_CORES: int = 3

func _load_echo_cores(raw: Variant) -> void:
	echo_cores.clear()
	for c: Variant in (raw if raw is Array else []):
		if not c is Dictionary or echo_cores.size() >= MAX_ECHO_CORES:
			continue
		var kind: String = str((c as Dictionary).get("kind", ""))
		if Database.species(kind) == null:
			continue
		var parents: Variant = (c as Dictionary).get("parents", [])
		echo_cores.append({"kind": kind,
			"parents": (parents as Array).map(func(x: Variant) -> String: return str(x)).slice(0, 2) if parents is Array else [],
			"rests": maxi(0, int((c as Dictionary).rests)) if (c as Dictionary).get("rests") is int or (c as Dictionary).get("rests") is float else 0,
			"wins": maxi(0, int((c as Dictionary).wins)) if (c as Dictionary).get("wins") is int or (c as Dictionary).get("wins") is float else 0,
			"heir": (c as Dictionary).get("heir", {}) if (c as Dictionary).get("heir", {}) is Dictionary else {},
			"contract": bool((c as Dictionary).get("contract", false))})

## Every heal spring is an Echo spring once the second Rift is mended (item 184).
func echo_spring_open() -> bool:
	return has_flag("storage_remote")

## The first form of [param sd]'s line.
static func first_form(sd: SpirlingData) -> SpirlingData:
	var cur: SpirlingData = sd
	for i: int in 8:
		var prev: SpirlingData = Database.earlier_form(cur)
		if prev == null:
			break
		cur = prev
	return cur

## Why [param a] and [param b] can't sing together, or "" when they can.
func sing_problem(a: Spirling, b: Spirling) -> String:
	if a == null or b == null or a == b:
		return "Pick two different Spirlings."
	if not (party + storage).has(a) or not (party + storage).has(b):
		return "Only Spirlings with you or in storage can sing."
	if a.data.rarity == "ancient" or b.data.rarity == "ancient":
		return "A First Voice sings alone."
	if echo_cores.size() >= MAX_ECHO_CORES:
		return "You already carry as many Echo Cores as you can."
	return ""

## Two bonded Spirlings sing together and their shared call forms a floating Echo Core.
## The Hallkind that wakes from it is the first form of one of the two lines.
func sing_together(a: Spirling, b: Spirling, p_rng: RandomNumberGenerator = null) -> Dictionary:
	if not sing_problem(a, b).is_empty():
		return {}
	var r: RandomNumberGenerator = p_rng if p_rng != null else rng
	var from: Spirling = a if r.randi_range(0, 1) == 0 else b
	var core: Dictionary = {"kind": first_form(from.data).species_name,
		"parents": [a.data.species_name, b.data.species_name], "rests": 0, "wins": 0,
		"heir": Breeding.snapshot(a, b), "contract": false}
	echo_cores.append(core)
	return core

func note_core_rest() -> void:
	for c: Dictionary in echo_cores:
		c["rests"] = int(c.rests) + 1

func note_core_win() -> void:
	for c: Dictionary in echo_cores:
		c["wins"] = int(c.wins) + 1

static func core_ready(c: Dictionary) -> bool:
	return int(c.get("rests", 0)) >= ECHO_CORE_RESTS or int(c.get("wins", 0)) >= ECHO_CORE_WINS

## Wakes every ready Echo Core: a Hallkind at Ring 1 joins (team or storage). Returns them.
func awaken_cores() -> Array[Spirling]:
	var out: Array[Spirling] = []
	for c: Dictionary in echo_cores.duplicate():
		if not core_ready(c):
			continue
		echo_cores.erase(c)
		var kid := Spirling.new(Database.species(str(c.kind)), 1, rng)
		kid.lineage.assign(c.parents)
		kid.set_meta("inheritance", Breeding.inherit(kid, c, rng))
		receive_spirling(kid)
		out.append(kid)
	return out

## Swaps two party slots (reordering; slot 0 leads in battle).
func swap_party(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return
	var tmp: Spirling = party[a]
	party[a] = party[b]
	party[b] = tmp
