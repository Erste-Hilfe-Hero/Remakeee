class_name WardenRematch
extends RefCounted
## Warden rematches after the finale (data/warden_rematch.json): each of the twelve Wardens fights
## once more with a stronger team of its own, its own lines and a reward. Won once per Warden.

const PATH: String = "res://data/warden_rematch.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func entries() -> Array:
	return data().get("wardens", [])

## The rematch entry for a Warden NPC on a map, or {} if it has none.
static func entry_for(map_id: String, npc_id: String) -> Dictionary:
	for e: Variant in entries():
		if e is Dictionary and str(e.get("map", "")) == map_id and str(e.get("npc", "")) == npc_id:
			return e
	return {}

static func won_flag(entry: Dictionary) -> String:
	return "warden_rematch_" + str(entry.get("warden", ""))

## Open once the finale flag is set and the Warden was beaten, until the rematch is won.
static func can_challenge(base: Dictionary, map_id: String, flags: Dictionary) -> bool:
	var entry: Dictionary = entry_for(map_id, str(base.get("id", "")))
	if entry.is_empty() or not TrainerData.is_beaten(base, map_id, flags):
		return false
	if not bool(flags.get(str(data().get("needs_flag", "story_complete")), false)):
		return false
	return not bool(flags.get(won_flag(entry), false))

## The rematch as a Wayfarer definition: the Warden's identity, the entry's team, money and profile.
static func rematch_def(base: Dictionary, entry: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: String in ["team", "team_by_starter", "teams_by_difficulty", "money", "intro", "defeat", "win_flags",
			"second_trial", "lexicon", "mend_items"]:
		out.erase(k)
	out["team"] = entry.get("team", [])
	out["money"] = int(entry.get("money", 0))
	out["profile"] = str(entry.get("profile", base.get("profile", "balanced")))
	out["beaten_flag"] = won_flag(entry)
	return out

static func lines(entry: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in entry.get(key, []):
		out.append(Loc.t(str(s)))
	return out
