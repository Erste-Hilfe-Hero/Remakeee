extends RefCounted
## Battle setups for the developer battle editor (KAMPF_PLAN_1000 item 993) and for data packs
## (BattlePacks "battles"). A setup is plain data:
##   {"name": "...", "player": [["Kindlop", 12]], "foe": [["Mossling", 10]], "field": "", "rule": "",
##    "boss": "", "seed": 1, "ai": 1, "front": [1, 1], "wild": false}
## build() turns it into a BattleModel, play() runs it with the player AI and returns the log.
## Developer tool: English only, never shown to players.

const MAX_TURNS: int = 200
const MAX_TEAM: int = 6

## "Kindlop 12, Mossling 10" -> [["Kindlop", 12], ["Mossling", 10]]. A name without a level gets
## [param level].
static func parse_team(text: String, level: int = 10) -> Array:
	var out: Array = []
	for part: String in text.split(",", false):
		var words: PackedStringArray = part.strip_edges().split(" ", false)
		if words.is_empty():
			continue
		var lvl: int = level
		if words.size() > 1 and words[-1].is_valid_int():
			lvl = int(words[-1])
			words.remove_at(words.size() - 1)
		out.append([" ".join(words), lvl])
	return out

static func team_text(team: Array) -> String:
	var parts: PackedStringArray = []
	for e: Variant in team:
		parts.append("%s %d" % [e[0], int(e[1])])
	return ", ".join(parts)

## Problems of [param setup], one line each.
static func errors(setup: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for side: String in ["player", "foe"]:
		var team: Variant = setup.get(side, [])
		if not team is Array or (team as Array).is_empty() or (team as Array).size() > MAX_TEAM:
			out.append("%s: 1 to %d Spirlings" % [side, MAX_TEAM])
			continue
		for e: Variant in team:
			if not e is Array or (e as Array).size() != 2:
				out.append("%s: every entry is [species, level]" % side)
			elif Database.species(str(e[0])) == null:
				out.append("%s: unknown species '%s'" % [side, e[0]])
			elif int(e[1]) < 1 or int(e[1]) > Spirling.LEVEL_SANITY:
				out.append("%s: level %s out of range" % [side, e[1]])
	var field: String = str(setup.get("field", ""))
	if not field.is_empty() and not BattleRules.FIELDS.has(field):
		out.append("unknown field '%s'" % field)
	var rule: String = str(setup.get("rule", ""))
	for id: String in rule.split("+", false):
		if not BattleRules.RULES.has(id):
			out.append("unknown rule '%s'" % id)
	var boss: String = str(setup.get("boss", ""))
	if not boss.is_empty() and not BattleRules.BOSSES.has(boss):
		out.append("unknown boss '%s'" % boss)
	var front: Variant = setup.get("front", [1, 1])
	if not front is Array or (front as Array).size() != 2:
		out.append("front is [player, foe]")
	else:
		for n: Variant in front:
			if int(n) < 1 or int(n) > BattleRules.MAX_FRONT:
				out.append("front sizes lie between 1 and %d" % BattleRules.MAX_FRONT)
	if int(setup.get("ai", 1)) < 0 or int(setup.get("ai", 1)) > 3:
		out.append("ai lies between 0 and 3")
	return out

static func _team(team: Array, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for e: Variant in team:
		out.append(Spirling.new(Database.species(str(e[0])), int(e[1]), rng))
	return out

## A fresh model for a setup without errors, before start().
static func build(setup: Dictionary) -> BattleModel:
	var seed_value: int = int(setup.get("seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Array[Spirling] = _team(setup.get("player", []), rng)
	var theirs: Array[Spirling] = _team(setup.get("foe", []), rng)
	var m := BattleModel.new(mine, theirs, bool(setup.get("wild", false)), seed_value, int(setup.get("ai", 1)))
	if not m.is_wild:
		m.trainer_name = "Tester"
	m.field = str(setup.get("field", ""))
	m.foe_rule = str(setup.get("rule", ""))
	m.foe_boss = str(setup.get("boss", ""))
	if not m.foe_boss.is_empty():
		m.round_limit = BattleModel.BOSS_ROUND_LIMIT
	var front: Array = setup.get("front", [1, 1])
	m.front_size = [int(front[0]), int(front[1])]
	return m

## Plays [param setup] with the same AI on the player side: {"outcome", "turns", "log", "errors"}.
static func play(setup: Dictionary) -> Dictionary:
	var errs: PackedStringArray = errors(setup)
	if not errs.is_empty():
		return {"outcome": "", "turns": 0, "log": PackedStringArray(), "errors": errs}
	var m: BattleModel = build(setup)
	var brain := BattleAI.new(int(setup.get("ai", 1)))
	var log_lines: PackedStringArray = []
	_add(log_lines, m.start())
	var turns: int = 0
	while not m.is_finished() and turns < MAX_TURNS:
		if m.needs_player_switch():
			_add(log_lines, m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot())))
			continue
		if m.is_multi():
			var acts: Array[BattleAction] = []
			for slot: int in m.player_slots():
				acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
			_add(log_lines, m.submit_actions(acts))
		else:
			_add(log_lines, m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER)))
		turns += 1
	return {"outcome": BattleModel.Outcome.keys()[m.outcome], "turns": m.turn, "log": log_lines, "errors": errs}

static func _add(lines: PackedStringArray, events: Array[BattleEvent]) -> void:
	for e: BattleEvent in events:
		var line: String = e.describe()
		if not line.is_empty():
			lines.append(line)
