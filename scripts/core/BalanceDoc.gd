class_name BalanceDoc
extends RefCounted
## Generated parts of docs/BALANCE.md (plan area 2, items 875, 876, 878, 879, 880, 881). Each
## section stands between "<!-- gen:NAME -->" and "<!-- /gen:NAME -->" and is rewritten by
## tools/balance/run_all.sh from the data and the simulator, never edited by hand.
## test_balance_doc.gd checks that the data sections match the data.

const DOC_PATH: String = "res://docs/BALANCE.md"
## Sections built from data only (fast, checked by the test).
const DATA_SECTIONS: Array[String] = ["difficulty", "profiles", "variants", "ref_teams"]
## Sections that need simulator runs (rewritten by run_all.sh only).
const SIM_SECTIONS: Array[String] = ["changes", "report_lv36"]

const DIFFICULTY_NAMES: Array[String] = ["Story", "Tamer", "Veteran", "Rift-Born"]

## Changes to existing arts (plan area 2, "Bestehende Techniken nachjustieren", items 581-608):
## [art, before, after, why, KO per use at ring 36 before (-1 if not measured)].
const CHANGES: Array = [
	["Lichen Lash", "Power 40", "Power 35", "Too many KOs for 2 Energy", 0.94],
	["Crackle Bite", "Jolt 10 %", "Jolt 5 %", "Too many KOs per use", 0.80],
	["Overcharge", "No cap, 0.15 per Energy", "At most +5 Energy, 0.12 per Energy", "Ended every duel it was used in", 1.00],
	["Storm Gnash", "Power 75, accuracy 90 %", "Power 80, accuracy 95 %", "Hardly ever won a fight", 0.07],
	["Gale Scythe", "Power 80, Energy 5", "Power 85, Energy 4", "Hardly ever won a fight", 0.08],
	["Arc Bolt", "Jolt 20 %", "Jolt 30 %", "Hardly ever won a fight", 0.04],
	["All-In Crash", "Base power 30", "Base power 40", "A real Stone pick next to Overcharge", 0.05],
	["Cairn Crash", "Power 100, accuracy 80 %", "Power 105, accuracy 85 %", "Never picked at ring 36", -1.0],
	["Furnace Spiral", "Accuracy 85 %", "Accuracy 90 %", "Never picked at ring 36", -1.0],
	["Hush", "Accuracy 75 %, Energy 4", "Accuracy 80 %, Energy 3", "Only picked under the rest rule", -1.0],
	["Bloom Burst", "Power 90", "Power 95", "Never picked at ring 36", -1.0],
	["Breaker Plunge", "Accuracy 85 %, recoil 25 %", "Accuracy 90 %, recoil 20 %", "Too costly for its user", -1.0],
	["Radiant Lance", "Power 85", "Power 90", "Behind Prism Ray at the same cost", -1.0],
	["Kiln Strike", "Accuracy 90 %", "Accuracy 95 %", "Missed too often for its cost", -1.0],
	["Salt Snap", "Soak 10 %", "Soak 20 %", "Never picked at ring 36", -1.0],
	["Pebble Toss", "Accuracy 95 %", "Accuracy 100 %", "Cheapest Stone hit, should be sure", -1.0],
	["Bowl Over", "Power 35", "Power 30", "Stays the cheapest Stone hit at 1 Energy", -1.0],
	["Tunnel Strike", "No side effect", "20 % own guard +1", "A reason to pick it", -1.0],
	["Night Siphon", "Power 50", "Power 60", "Drain too small to matter", -1.0],
	["Dusk Rake", "No side effect", "20 % foe power -1", "A reason to pick it", -1.0],
	["Thorn Volley", "Power 65, Energy 4", "Power 75, Energy 5", "A sweep worth taking next to Sap Draw", -1.0],
	["Charged Mist", "Accuracy 85 %", "Accuracy 80 %", "Jolt on every foe was too sure in group battles", -1.0],
	["Candle Ward", "Energy 3", "Energy 2", "Never picked at ring 36", -1.0],
	["Dawn Mend", "Energy 5", "Energy 6", "Fitted every second turn", -1.0],
	["Heat Haze, Murk Veil, Silt Cloud", "Mixed accuracy and cost", "Accuracy 90 %, Energy 3", "Same Daze arts, same price", -1.0],
	["Kindle Up, Hunker Down, Drift Step, Still Thought", "1 stage", "2 stages at full Vigor", "Setup arts were never worth a turn", -1.0],
	["Cower Shade", "Accuracy 95 %", "Accuracy 100 %", "A status art should land", -1.0],
	["Chill Mist", "One foe, Energy 2", "Every foe, Energy 3", "A sweep for Tide support", -1.0],
]

## The markdown of one data section.
static func section(name: String) -> String:
	match name:
		"difficulty":
			return difficulty_table()
		"profiles":
			return profiles_table()
		"variants":
			return variants_table()
		"ref_teams":
			return ref_teams_table()
	return ""

## Item 875: what each difficulty does to a foe.
static func difficulty_table() -> String:
	var lines: PackedStringArray = ["| Difficulty | Foe ring | Foe Spark | AI Wayfarer / Warden | Keepsakes | Foe start Energy | Foe damage | Warden rules | Boss actions | Rift-Born extra |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
	for d: int in DIFFICULTY_NAMES.size():
		var energy: String = str(Spirling.MAX_ENERGY - BattleRules.foe_start_cut(d))
		if BattleRules.foe_turn1_energy(d) > 0:
			energy += " (+%d after turn 1)" % BattleRules.foe_turn1_energy(d)
		var cap: int = BattleRules.BOSS_ACTION_CAP[d]
		var boss: String = ("at most %d" % cap) if cap > 0 else "as the boss data says"
		if BattleRules.BOSS_PHASE_BONUS[d] > 0:
			boss += ", +%d in phase 2" % BattleRules.BOSS_PHASE_BONUS[d]
		lines.append("| %s | %+d | %d | %d / %d | %s | %s | x%.2f | up to %d | %s | %s |" % [DIFFICULTY_NAMES[d], GameState.FOE_LEVEL_SHIFT[d],
			GameState.FOE_SPARK[d], TrainerData.ai_tier({}, GameState.AI_LEVELS[d], d), TrainerData.ai_tier({"warden": true}, GameState.AI_LEVELS[d], d),
			"kept" if TrainerData.keeps_keepsakes(d) else "dropped", energy, GameState.FOE_DAMAGE[d], BattleRules.rule_stack(d), boss,
			"+1 copy of the lowest entry (team of up to %d)" % TrainerData.RIFT_BORN_MAX_TEAM if d == GameState.Difficulty.RIFT_BORN else "-"])
	lines.append("")
	lines.append("Foe ring: the shift of a shared Wayfarer team (teams with their own block for the difficulty keep their rings), never more than %d above the ring cap." % GameState.FOE_OVER_CAP)
	return "\n".join(lines)

## Item 876: every AI profile with its weights, its motto and who uses it.
static func profiles_table() -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_profiles.json"))
	var lines_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/battle_lines.json"))
	var profiles: Dictionary = raw if raw is Dictionary else {}
	var bl: Dictionary = lines_raw if lines_raw is Dictionary else {}
	var users: Dictionary = profile_users()
	var keys: Array[String] = []
	for id: String in profiles:
		if id.begins_with("_"):
			continue
		for k: String in profiles[id]:
			if not k in keys:
				keys.append(k)
	var head: PackedStringArray = ["Profile"]
	head.append_array(PackedStringArray(keys))
	head.append_array(PackedStringArray(["Motto", "Used by"]))
	var out: PackedStringArray = ["| " + " | ".join(head) + " |", "|" + " --- |".repeat(head.size())]
	for id: String in profiles:
		if id.begins_with("_"):
			continue
		var row: PackedStringArray = [id]
		for k: String in keys:
			var v: Variant = profiles[id].get(k, "")
			row.append("never" if k == "swap_below" and v is float and float(v) < 0.0 else ("default" if v == null else _num(v)))
		var motto: Variant = bl.get(id + "_motto", [])
		row.append(str((motto as Array)[0]) if motto is Array and not (motto as Array).is_empty() else "")
		var who: Array = users.get(id, [])
		row.append(", ".join(PackedStringArray(who)) if not who.is_empty() else "-")
		out.append("| " + " | ".join(row) + " |")
	return "\n".join(out)

## A JSON number without a needless ".0"; lists as "a, b".
static func _num(v: Variant) -> String:
	if v is float and is_equal_approx(float(v), roundf(float(v))):
		return str(int(v))
	if v is Array:
		return ", ".join(PackedStringArray((v as Array).map(func(x: Variant) -> String: return str(x))))
	return str(v)

## Profile id -> ["map:npc id", ...] from every map's NPCs, sorted.
static func profile_users() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return out
	var files: Array[String] = []
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f: String in files:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		_walk_profiles(raw, f.get_basename(), out)
	for k: String in out:
		(out[k] as Array).sort()
	return out

static func _walk_profiles(v: Variant, map_id: String, out: Dictionary) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("profile") and d.get("profile") is String:
			var who: String = "%s:%s" % [map_id, str(d.get("id", d.get("name", "?")))]
			if not out.has(d.profile):
				out[d.profile] = []
			if not who in out[d.profile]:
				(out[d.profile] as Array).append(who)
		for k: Variant in d:
			_walk_profiles(d[k], map_id, out)
	elif v is Array:
		for x: Variant in v:
			_walk_profiles(x, map_id, out)

## Item 878: every rule variant, its numbers and the pairs it can't go with.
static func variants_table() -> String:
	var all: Dictionary = BattleRules.variants()
	var ids: Array = all.keys()
	ids.sort()
	var out: PackedStringArray = ["| Variant | Label | Numbers | Can't go with | Seal | Text |", "| --- | --- | --- | --- | --- | --- |"]
	for id: String in ids:
		var v: Dictionary = all[id]
		var nums: PackedStringArray = []
		var keys: Dictionary = v.get("keys", {})
		var knames: Array = keys.keys()
		knames.sort()
		for k: String in knames:
			nums.append("%s %s (normal %s)" % [k, _num(keys[k]), _num(BattleRules.VARIANT_KEYS.get(k, ""))])
		var ex: Array = (v.get("excludes", []) as Array).duplicate()
		ex.sort()
		out.append("| `%s` | %s | %s | %s | %s | %s |" % [id, v.get("label", ""), ", ".join(nums), ", ".join(PackedStringArray(ex)) if not ex.is_empty() else "-",
			v.get("symbol", ""), v.get("text", "")])
	out.append("")
	out.append("At most %d variants at once; a Rift Tower floor draws 1 from floor 6 and 2 in the third section." % BattleRules.MAX_VARIANTS)
	return "\n".join(out)

## Item 880: the reference teams of the Warden simulator.
static func ref_teams_table() -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BalanceSim.REF_TEAMS_PATH))
	var secs: Dictionary = (raw as Dictionary).get("sections", {}) if raw is Dictionary else {}
	var out: PackedStringArray = ["| Section | Ring cap | Against | Team | Spirlings (ring) |", "| --- | --- | --- | --- | --- |"]
	for sec: String in secs:
		var s: Dictionary = secs[sec]
		var against: PackedStringArray = []
		for w: Variant in s.get("wardens", []):
			against.append(str((w as Array)[1]) + (" (rematch)" if bool(s.get("rematch", false)) else ""))
		for team: String in s.get("teams", {}):
			var mons: PackedStringArray = []
			for e: Dictionary in s.teams[team]:
				mons.append("%s %d" % [e.species, int(e.level)])
			out.append("| %s | %d | %s | %s | %s |" % [sec, int(s.get("cap", 0)), ", ".join(against), team, ", ".join(mons)])
	return "\n".join(out)

## Item 879: the change log with KO per use at ring 36 before and now (now from [param duel],
## a BalanceSim.run result at ring 36).
static func changes_table(duel: Dictionary) -> String:
	var mv: Dictionary = duel.get("moves", {})
	var out: PackedStringArray = ["| What | Before | After | Why | KO per use before | KO per use now |", "| --- | --- | --- | --- | --- | --- |"]
	for c: Array in CHANGES:
		var now: String = "-"
		if mv.has(c[0]) and int(mv[c[0]].used) > 0:
			now = "%.2f" % (float(mv[c[0]].kos) / float(mv[c[0]].used))
		out.append("| %s | %s | %s | %s | %s | %s |" % [c[0], c[1], c[2], c[3], "%.2f" % float(c[4]) if float(c[4]) >= 0.0 else "-", now])
	out.append("")
	out.append("\"Now\" is the duel run at ring 36 (10 duels per pair, seed 1234); \"-\" means the art was not picked there.")
	return "\n".join(out)

## [param doc] with the section [param name] replaced by [param body]; unchanged if the markers
## are missing.
static func replace_section(doc: String, name: String, body: String) -> String:
	var open: String = "<!-- gen:%s -->" % name
	var close: String = "<!-- /gen:%s -->" % name
	var i: int = doc.find(open)
	var j: int = doc.find(close)
	if i < 0 or j < i:
		return doc
	return doc.substr(0, i + open.length()) + "\n" + body.strip_edges() + "\n" + doc.substr(j)

## The text between the markers of [param name], stripped ("" if missing).
static func current_section(doc: String, name: String) -> String:
	var open: String = "<!-- gen:%s -->" % name
	var close: String = "<!-- /gen:%s -->" % name
	var i: int = doc.find(open)
	var j: int = doc.find(close)
	if i < 0 or j < i:
		return ""
	return doc.substr(i + open.length(), j - i - open.length()).strip_edges()
