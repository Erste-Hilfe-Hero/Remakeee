class_name Trust
extends RefCounted
## The clan intrigue (docs/STORY.md "Clans and trust"): every figure in data/clans.json has a
## hidden trust value and a hidden use value. A figure betrays the player when its use is
## higher than its trust. Values are the start value from the data plus a change kept in
## GameState.story_vars ("trust_<id>", "use_<id>"), so saves only hold what changed.
## Favors (lend a Spirling, lend coins, believe a tip) and scripted betrayals are resolved
## here; the overworld only applies the effects. The Ledger page lists the entries whose
## flag "ledger_<id>" is set.

const PATH: String = "res://data/clans.json"
const MIN_VALUE: int = 0
const MAX_VALUE: int = 100
const KINDS: Array[String] = ["lend_spirling", "lend_coins", "believe_tip"]
const RESULTS: Array[String] = ["betray", "reward", "kept"]
const EFFECT_KEYS: Array[String] = ["coins", "item", "take_keepsake", "battle", "ledger", "flags",
	"trust", "use", "say"]

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func figure(id: String) -> Dictionary:
	var f: Variant = data().get("figures", {}).get(id)
	return f if f is Dictionary else {}

static func favor(id: String) -> Dictionary:
	var f: Variant = data().get("favors", {}).get(id)
	return f if f is Dictionary else {}

static func betrayal(id: String) -> Dictionary:
	var b: Variant = data().get("betrayals", {}).get(id)
	return b if b is Dictionary else {}

static func trust_key(id: String) -> String:
	return "trust_" + id

static func use_key(id: String) -> String:
	return "use_" + id

static func ledger_flag(id: String) -> String:
	return "ledger_" + id

## Start value plus change, kept inside 0..100.
static func value(start: int, change: int) -> int:
	return clampi(start + change, MIN_VALUE, MAX_VALUE)

## The current hidden trust of figure [param id], read from [param vars] (story_vars).
static func trust_in(id: String, vars: Dictionary) -> int:
	return value(int(figure(id).get("trust", 0)), int(vars.get(trust_key(id), 0)))

static func use_in(id: String, vars: Dictionary) -> int:
	return value(int(figure(id).get("use", 0)), int(vars.get(use_key(id), 0)))

static func trust(id: String) -> int:
	return trust_in(id, GameState.story_vars)

static func use(id: String) -> int:
	return use_in(id, GameState.story_vars)

## The core rule: a figure betrays when the player is worth more to sell than to keep.
static func betrays(trust_value: int, use_value: int) -> bool:
	return use_value > trust_value

## "betray", "reward" or "kept" for a favor. [param roll] (0..1) decides whether a loyal
## figure also pays something back; tests pass it in.
static func resolve(def: Dictionary, trust_value: int, use_value: int, roll: float) -> String:
	if betrays(trust_value, use_value):
		return "betray"
	if roll < float(def.get("reward_chance", 0.0)):
		return "reward"
	return "kept"

## The effects of [param result] for a favor ({} when the data gives none).
static func effects(def: Dictionary, result: String) -> Dictionary:
	var e: Variant = def.get(result)
	return e if e is Dictionary else {}

## A scripted betrayal always happens; only whether the player saw it coming changes.
## Rule "warned": caught when any flag in "warned_by" is set. Rule "trust": caught when the
## figure's trust is at least "min". Returns "caught" or "struck".
static func betrayal_result(def: Dictionary, flags: Dictionary, vars: Dictionary) -> String:
	match str(def.get("rule", "warned")):
		"trust":
			return "caught" if trust_in(str(def.get("npc", "")), vars) >= int(def.get("min", 0)) else "struck"
		_:
			for f: Variant in def.get("warned_by", []):
				if bool(flags.get(str(f), false)):
					return "caught"
			return "struck"

## Coins left after a "coins" effect: a negative amount is a loss (a betrayal's bill) and
## never takes the purse below zero.
static func money_after(money: int, coins: int) -> int:
	return maxi(0, money + coins)

## Applies the value changes of an effect to [param vars] ({"trust": {id: delta}, "use": ...}).
static func apply_values(eff: Dictionary, vars: Dictionary) -> void:
	for kind: String in ["trust", "use"]:
		var changes: Variant = eff.get(kind, {})
		if not changes is Dictionary:
			continue
		for id: Variant in changes:
			var key: String = trust_key(str(id)) if kind == "trust" else use_key(str(id))
			vars[key] = int(vars.get(key, 0)) + int(changes[id])

## Ledger rows the player has collected, in data order: {"id", "act", "ref"}.
static func ledger_rows(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in data().get("ledger", []):
		if e is Dictionary and bool(flags.get(ledger_flag(str(e.get("id", ""))), false)):
			out.append(e)
	return out

## Title (first line) and body (the rest) of a ledger entry's dialogue.
static func ledger_text(ref: String) -> Array[String]:
	return Dialogue.lines_for(Dialogue.get_entry(ref), {})

## Errors in data/clans.json (dead dialogue refs, unknown figures, kinds, effect keys).
static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var figs: Dictionary = data().get("figures", {})
	for id: Variant in figs:
		var f: Dictionary = figs[id]
		if not str(f.get("clan", "")) in data().get("clans", {}).keys() + ["strangers", "none"]:
			errors.append("clans/figures/%s: unknown clan '%s'" % [id, f.get("clan", "")])
	for id: Variant in data().get("favors", {}):
		var d: Dictionary = favor(str(id))
		if not figs.has(str(d.get("npc", ""))):
			errors.append("clans/favors/%s: unknown figure '%s'" % [id, d.get("npc", "")])
		if not str(d.get("kind", "")) in KINDS:
			errors.append("clans/favors/%s: unknown kind '%s'" % [id, d.get("kind", "")])
		for r: String in RESULTS:
			_check_effects("clans/favors/%s/%s" % [id, r], effects(d, r), figs, errors)
	for id: Variant in data().get("betrayals", {}):
		var b: Dictionary = betrayal(str(id))
		if not figs.has(str(b.get("npc", ""))):
			errors.append("clans/betrayals/%s: unknown figure '%s'" % [id, b.get("npc", "")])
		for r: String in ["caught", "struck"]:
			_check_effects("clans/betrayals/%s/%s" % [id, r], effects(b, r), figs, errors)
	var ids: Array[String] = []
	for e: Variant in data().get("ledger", []):
		var id: String = str((e as Dictionary).get("id", ""))
		ids.append(id)
		if not Dialogue.exists(str((e as Dictionary).get("ref", ""))):
			errors.append("clans/ledger/%s: dialogue '%s' does not exist" % [id, (e as Dictionary).get("ref", "")])
	for id: Variant in data().get("favors", {}).keys() + data().get("betrayals", {}).keys():
		var d: Dictionary = favor(str(id)) if not favor(str(id)).is_empty() else betrayal(str(id))
		for r: String in RESULTS + ["caught", "struck"]:
			var l: Variant = effects(d, r).get("ledger")
			if l != null and not str(l) in ids:
				errors.append("clans/%s/%s: unknown ledger entry '%s'" % [id, r, l])
	return errors

static func _check_effects(where: String, eff: Dictionary, figs: Dictionary, errors: PackedStringArray) -> void:
	for k: Variant in eff:
		if not str(k) in EFFECT_KEYS:
			errors.append("%s: unknown effect '%s'" % [where, k])
	if eff.has("say") and not Dialogue.exists(str(eff.say)):
		errors.append("%s: dialogue '%s' does not exist" % [where, eff.say])
	if eff.has("battle") and not StoryBattles.has(str(eff.battle)):
		errors.append("%s: story battle '%s' does not exist" % [where, eff.battle])
	if eff.has("item") and Database.item(str(eff.item)).is_empty():
		errors.append("%s: item '%s' does not exist" % [where, eff.item])
	for kind: String in ["trust", "use"]:
		for id: Variant in (eff.get(kind, {}) as Dictionary):
			if not figs.has(str(id)):
				errors.append("%s: %s of unknown figure '%s'" % [where, kind, id])
