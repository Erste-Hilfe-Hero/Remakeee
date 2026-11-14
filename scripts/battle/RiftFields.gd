class_name RiftFields
extends RefCounted
## Rift field extras (docs/KAMPF_PLAN_1000.md, "Rift-Felder und Umgebung"): the look, sound and
## places of the fields in BattleRules.FIELDS. Data in data/rift_fields.json; the rules of each
## field (boost, weaken, blocks, regen, energy, bond) stay in BattleRules.FIELDS.

const PATH: String = "res://data/rift_fields.json"
## Lexicon entry ids: one per field, plus the entry with the shared numbers.
const LEXICON_PREFIX: String = "field_"
const LEXICON_RULES: String = "field_rules"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {"_empty": true}
	return _data

## Extra Energy [param s] gains at the end of a turn on [param field] (Static Veil, item 329).
static func energy_bonus(field: String, s: Spirling) -> int:
	var f: Dictionary = BattleRules.FIELDS.get(field, {})
	if s == null or not f.has("energy_element"):
		return 0
	return int(f.get("energy_gain", 1)) if Elements.E.get(str(f.energy_element), -1) in s.elements() else 0

## Extra turns a Resonance [param field] holds when it is laid at its own time of day
## ([param phase] a DayCycle.Phase, -1 for none; item 333).
static func daytime_turns(field: String, phase: int) -> int:
	if phase < 0:
		return 0
	var d: Dictionary = data().get("daytime", {}).get(field, {})
	return int(d.get("turns", 0)) if DayCycle.phase_name(phase) in d.get("phases", []) else 0

## Colour laid over the backdrop for [param field] in [param era] (items 331, 353); clear without a field.
static func tint(field: String, era: int) -> Color:
	var hex: String = str(data().get("tint", {}).get(field, ""))
	if hex.is_empty():
		return Color(0, 0, 0, 0)
	var ink: String = str(data().get("era_ink", {}).get(str(era), ""))
	var c: Color = Color.html(ink if not ink.is_empty() else hex)
	c.a = float(data().get("tint_alpha", {}).get(str(clampi(era, 1, 5)), 0.15))
	return c

## Pitch of the battle song while [param field] lasts (item 332); 1.0 without a field.
static func music_pitch(field: String) -> float:
	return float(data().get("music_pitch", {}).get(field, 1.0))

## The field a lighthouse stair floor stands in, or "" (item 354). The same run seed and floor
## always give the same field, so a saved climb picks up the same floors.
static func tower_field(run_seed: int, floor_no: int) -> String:
	var t: Dictionary = data().get("tower", {})
	if floor_no < int(t.get("from_floor", 1)):
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor_no, "rift_field"])
	if rng.randf() >= float(t.get("share", 0.0)):
		return ""
	var ids: Array = BattleRules.FIELDS.keys()
	ids.sort()
	return str(ids[rng.randi_range(0, ids.size() - 1)])

## Elements met more often in the wild on a map whose own field is [param field] (item 347).
static func spawn_boost(field: String) -> Array[int]:
	var out: Array[int] = []
	var f: Dictionary = BattleRules.FIELDS.get(field, {})
	if bool(data().get("spawn", false)) and f.has("boost"):
		out.append(int(Elements.E.get(str(f.boost), -1)))
	return out

## The field the wild battles of Rift map [param file] stand in when the map sets no "field" of
## its own (item 94): data/rift_fields.json "rift_maps". "" for any other map.
static func home_field(file: String) -> String:
	var f: String = str((data().get("rift_maps", {}) as Dictionary).get(file, ""))
	return f if BattleRules.FIELDS.has(f) else ""

## The field a battle starts in: [param own] (the trainer's or the map's), or for a wild battle on
## a field-less Rift the Rift's home field (item 94). Wardens and Tamers keep the place as it is.
static func battle_field(own: String, file: String, wild: bool) -> String:
	return own if not own.is_empty() or not wild else home_field(file)

static func lexicon_id(field: String) -> String:
	return LEXICON_PREFIX + field

## Writes the lexicon entry of [param field] (and the shared rules entry) into [param records]
## the first time the player stands in it (item 336). True if something new was written.
static func note_seen(records: Dictionary, field: String) -> bool:
	if not BattleRules.FIELDS.has(field):
		return false
	var a: bool = Lexicon.add(records, LEXICON_RULES)
	var b: bool = Lexicon.add(records, lexicon_id(field))
	return a or b

## Short badge text: the field's name and the turns left ("Ash Storm 3"); only the name when
## the field holds for the whole battle.
static func badge_text(field: String, turns: int) -> String:
	if not BattleRules.FIELDS.has(field):
		return ""
	var label: String = Loc.t(str(BattleRules.FIELDS[field].label))
	return "%s %d" % [label, turns] if turns > 0 else label

## The badge read out by a screen reader (item 350).
static func spoken(field: String, turns: int) -> String:
	if not BattleRules.FIELDS.has(field):
		return Loc.t("No Rift field.")
	var label: String = Loc.t(str(BattleRules.FIELDS[field].label))
	if turns > 0:
		return Loc.t("Rift field %s, %d turns left.") % [label, turns]
	return Loc.t("Rift field %s, for the whole battle.") % label
