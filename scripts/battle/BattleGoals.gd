class_name BattleGoals
extends RefCounted
## Optional bonus goals per Wayfarer and Warden (plan area 2, items 755 to 757). data/battle_goals.json
## maps "map_id/npc_id" to {"type", "value", "reward"}. A goal never changes the battle itself, the
## win, the money or growth (item 764). Rewards are only game content without a battle edge: Echo
## Crystal shards (5 make a crystal), titles and lexicon entries. A goal pays out once (item 763).

const PATH: String = "res://data/battle_goals.json"
const TYPES: Array[String] = ["win_within", "no_faint", "no_rest", "only_kind", "max_fielded", "min_hp_end", "reaction_count"]
const REWARD_KINDS: Array[String] = ["shards", "title", "lore"]
## Shards that join into one Echo Crystal.
const SHARDS_PER_CRYSTAL: int = 5

static var _cache: Dictionary = {}

static func all() -> Dictionary:
	if _cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Dictionary:
			_cache = raw
			_cache.erase("_doc")
	return _cache

static func key(map_id: String, npc_id: String) -> String:
	return "%s/%s" % [map_id, npc_id]

static func goal_for(map_id: String, npc_id: String) -> Dictionary:
	var g: Variant = all().get(key(map_id, npc_id), {})
	return g if g is Dictionary else {}

## The line on the battle start card, e.g. "Bonus goal: win within 4 turns."
static func describe(goal: Dictionary) -> String:
	var v: Variant = goal.get("value", 0)
	var text: String = ""
	match str(goal.get("type", "")):
		"win_within": text = Loc.t("win within %d turns") % int(v)
		"no_faint": text = Loc.t("win without anyone on your side fainting")
		"no_rest": text = Loc.t("win without resting")
		"only_kind": text = Loc.t("win using only %s arts") % Loc.t(str(v).capitalize())
		"max_fielded": text = Loc.t("win sending out at most %d Spirlings") % int(v)
		"min_hp_end": text = Loc.t("win with at least %d%% Vigor left in your team") % roundi(float(v) * 100.0)
		"reaction_count": text = Loc.t("win setting off at least %d reactions") % int(v)
		_: return ""
	return Loc.t("Bonus goal: %s.") % text

## Watches one battle for its goal. Attach before the battle starts.
class Tracker:
	var goal: Dictionary
	var model: BattleModel
	var faints: int = 0
	var rests: int = 0
	var wrong_kind: int = 0
	var reactions: int = 0
	var fielded: Dictionary = {}
	var _first_turn: int = 0

	func _init(m: BattleModel, g: Dictionary) -> void:
		model = m
		goal = g
		_first_turn = m.turn
		m.event_emitted.connect(_on_event)

	func _on_event(e: BattleEvent) -> void:
		var side: int = int(e.data.get("side", -1))
		match e.type:
			BattleEvent.Type.BATTLE_START:
				_first_turn = model.turn
			BattleEvent.Type.FAINTED:
				if side == BattleModel.Side.PLAYER:
					faints += 1
			BattleEvent.Type.REST:
				if side == BattleModel.Side.PLAYER:
					rests += 1
			BattleEvent.Type.MOVE_USED:
				if side == BattleModel.Side.PLAYER and not _kind_ok(int(e.data.get("kind", -1))):
					wrong_kind += 1
			BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
				if side == BattleModel.Side.PLAYER:
					fielded[int(e.data.get("index", -1))] = true
			BattleEvent.Type.REACTION:
				if side == BattleModel.Side.FOE:
					reactions += 1

	func _kind_ok(kind: int) -> bool:
		if str(goal.get("type", "")) != "only_kind":
			return true
		return kind == int(MoveData.Kind.get(str(goal.get("value", "")).to_upper(), -1))

	func turns() -> int:
		return model.turn - _first_turn

	## Share of Vigor left over the player's own Spirlings.
	func hp_share() -> float:
		var hp: int = 0
		var top: int = 0
		var own: int = model.partner_start if model.partner_start >= 0 else model.party(BattleModel.Side.PLAYER).size()
		for i: int in own:
			var s: Spirling = model.party(BattleModel.Side.PLAYER)[i]
			hp += maxi(s.hp, 0)
			top += s.max_hp()
		return float(hp) / float(maxi(top, 1))

	## For the mark beside the turn count (item 762): 1 once the goal is surely met, -1 once it is
	## surely missed, 0 while it is still open. Only a won battle pays out in the end.
	func status() -> int:
		if model.outcome == BattleModel.Outcome.LOSS or model.outcome == BattleModel.Outcome.FLED:
			return -1
		if model.outcome == BattleModel.Outcome.WIN:
			return 1 if met() else -1
		var v: Variant = goal.get("value", 0)
		match str(goal.get("type", "")):
			"win_within": return -1 if turns() > int(v) else 0
			"no_faint": return -1 if faints > 0 else 0
			"no_rest": return -1 if rests > 0 else 0
			"only_kind": return -1 if wrong_kind > 0 else 0
			"max_fielded": return -1 if fielded.size() > int(v) else 0
			"reaction_count": return 1 if reactions >= int(v) else 0
		return 0

	## True once the battle is won and the goal holds.
	func met() -> bool:
		if model.outcome != BattleModel.Outcome.WIN:
			return false
		var v: Variant = goal.get("value", 0)
		match str(goal.get("type", "")):
			"win_within": return turns() <= int(v)
			"no_faint": return faints == 0
			"no_rest": return rests == 0
			"only_kind": return wrong_kind == 0
			"max_fielded": return fielded.size() <= int(v)
			"min_hp_end": return hp_share() >= float(v)
			"reaction_count": return reactions >= int(v)
		return false

## Pays out [param goal] for [param goal_key] into [param records] once. Returns the lines to show,
## or [] when it was already paid (item 763).
static func grant(goal_key: String, goal: Dictionary, records: Dictionary) -> Array[String]:
	var done: Dictionary = (records.get("goals_done", {}) as Dictionary).duplicate()
	if bool(done.get(goal_key, false)):
		return []
	done[goal_key] = true
	records["goals_done"] = done
	var lines: Array[String] = [Loc.t("Bonus goal met!")]
	var r: Dictionary = goal.get("reward", {})
	if int(r.get("shards", 0)) > 0:
		var shards: int = int(records.get("echo_shards", 0)) + int(r.shards)
		var crystals: int = shards / SHARDS_PER_CRYSTAL
		records["echo_shards"] = shards % SHARDS_PER_CRYSTAL
		lines.append(Loc.t("You get %d Echo Crystal shard(s).") % int(r.shards))
		if crystals > 0:
			records["echo_crystals"] = int(records.get("echo_crystals", 0)) + crystals
			lines.append(Loc.t("%d shards join into an Echo Crystal!") % SHARDS_PER_CRYSTAL)
	if not str(r.get("title", "")).is_empty():
		var t: Array = (records.get("titles", []) as Array).duplicate()
		if not t.has(str(r.title)):
			t.append(str(r.title))
		records["titles"] = t
		lines.append(Loc.t("New title: %s") % Loc.t(str(r.title)))
	if not str(r.get("lore", "")).is_empty():
		var l: Array = (records.get("lexicon", []) as Array).duplicate()
		if not l.has(str(r.lore)):
			l.append(str(r.lore))
		records["lexicon"] = l
		lines.append(Loc.t("A new lexicon entry is written down."))
	return lines
