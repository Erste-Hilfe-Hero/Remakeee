class_name AiNotes
extends RefCounted
## Why the foe AI did what it did (docs/KAMPF_PLAN_1000.md items 451, 467). With
## BattleModel.explain_ai on, every foe decision adds an AI_NOTE event before the turn plays:
##   REASON (watching a replay): one line, the pick and its score against the best other art
##   TABLE (developer view, start the game with "-- --ai-debug"): also every art it scored
## The notes only read the model and BattleAI.explain, which draws no random numbers, so a
## replay with notes plays out exactly as the battle did.

const OFF: int = 0
const REASON: int = 1
const TABLE: int = 2
## Command-line switch for the developer view (after "--" so Godot passes it on).
const DEBUG_ARG: String = "--ai-debug"
## Most scored arts the developer table lists.
const TABLE_ROWS: int = 6

## The level BattleScene gives a battle: TABLE with the developer switch, else [param fallback].
static func level_for(fallback: int) -> int:
	return TABLE if OS.get_cmdline_user_args().has(DEBUG_ARG) else fallback

## Scores shown as whole numbers (x100), so a line reads "Cinder Nip (83)".
static func points(score: float) -> int:
	return roundi(score * 100.0)

## The AI_NOTE event for [param a], the action [param ai] just chose in [param model].
static func note(model: BattleModel, ai: BattleAI, a: BattleAction, level: int) -> BattleEvent:
	var me: Spirling = model.active_spirling(a.side, a.slot)
	var d: Dictionary = {"side": a.side, "slot": a.slot, "name": me.display_name() if me != null else "?",
		"tier": ai.level, "profile": ai.profile_id, "phase": BossRules.ai_phase(model, a.side, a.slot)}
	var rows: Array[Dictionary] = ai.explain(model, a.side, a.slot) if me != null else ([] as Array[Dictionary])
	match a.kind:
		BattleAction.Kind.MOVE:
			var pick: String = me.moves[a.move_index].move_name
			d["kind"] = "random" if ai.level <= 0 else "move"
			d["pick"] = pick
			for r: Dictionary in rows:
				if str(r.move) == pick and (int(r.aim) == a.target_slot or int(r.aim) < 0 or a.target_slot < 0):
					d["score"] = points(float(r.score))
					break
			for r: Dictionary in rows:
				if str(r.move) != pick:
					d["alt"] = str(r.move)
					d["alt_score"] = points(float(r.score))
					break
		BattleAction.Kind.SWAP:
			d["kind"] = "swap"
			d["pick"] = model.party(a.side)[a.swap_index].display_name()
		BattleAction.Kind.ITEM:
			d["kind"] = "item"
			d["pick"] = str(Database.item(a.item_id).get("name", a.item_id))
		_:
			d["kind"] = "rest"
	if level >= TABLE:
		var table: Array[String] = []
		for r: Dictionary in rows.slice(0, TABLE_ROWS):
			table.append("%s > %s: %d" % [str(r.move), str(r.aim), points(float(r.score))])
		d["table"] = table
	return BattleEvent.new(BattleEvent.Type.AI_NOTE, d)

## The log line of an AI_NOTE event's [param d].
static func describe(d: Dictionary) -> String:
	var who: String = str(d.get("name", ""))
	var pick: String = str(d.get("pick", ""))
	var line: String = ""
	match str(d.get("kind", "")):
		"random":
			line = "%s picks %s at random, as wild ones do." % [who, pick]
		"move":
			if d.has("alt"):
				line = "%s picks %s (%d) over %s (%d)." % [who, pick, int(d.get("score", 0)), str(d.alt), int(d.alt_score)]
			else:
				line = "%s picks %s (%d): nothing else is in reach." % [who, pick, int(d.get("score", 0))]
		"swap":
			line = "%s swaps to %s: it doesn't like its odds." % [who, pick]
		"item":
			line = "%s uses %s: it is running low." % [who, pick]
		_:
			line = "%s rests: nothing it can pay is worth it now." % who
	match str(d.get("phase", "")):
		"held":
			line += " " + "It wants that field gone, so it can wake."
		"open":
			line += " " + "It lies open and stops building up."
		"final":
			line += " " + "Last phase: it holds nothing back."
	var table: Array = d.get("table", [])
	if not table.is_empty():
		line += "\n" + "AI tier %d, %s" % [int(d.get("tier", 0)), str(d.get("profile", ""))] + "\n" + "\n".join(table)
	return line
