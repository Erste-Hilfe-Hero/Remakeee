class_name MatchupQuiz
extends RefCounted
## Matchup quiz in the lighthouse training ring (KAMPF_PLAN_1000 item 99): a round of questions
## "this element into that element?", answered strong, plain or weak. Only the elements of the
## eras the Wayfarer has opened are asked. The best round is kept in the records; the first round
## with every answer right pays an item once. Numbers in data/matchup_quiz.json.

const PATH: String = "res://data/matchup_quiz.json"

static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"questions": 5, "answers": [2.0, 1.0, 0.5]}
	return _cfg

static func answers() -> Array[float]:
	var out: Array[float] = []
	for a: Variant in cfg().get("answers", [2.0, 1.0, 0.5]):
		out.append(float(a))
	return out

## The answer buttons, in the order of answers().
static func answer_labels() -> Array[String]:
	var out: Array[String] = []
	for a: float in answers():
		var word: String = "Strong" if a > 1.0 else ("Weak" if a < 1.0 else "Plain")
		out.append(Loc.t("%s, x%s") % [Loc.t(word), str(a).trim_suffix(".0")])
	return out

## Elements opened up to [param era] (type_chart.json "era").
static func elements_for(era: int) -> Array[int]:
	var out: Array[int] = []
	var types: Dictionary = Elements.chart().get("types", {})
	for e: int in Elements.E.values():
		if int((types.get(Elements.E.keys()[e], {}) as Dictionary).get("era", 1)) <= maxi(era, 1):
			out.append(e)
	return out

## One round of questions for [param era]: {"atk": int, "def": int, "answer": int (index into
## answers())}. The right answer is drawn evenly first, then a pair that has it; no pair repeats.
static func make_round(rng: RandomNumberGenerator, era: int) -> Array[Dictionary]:
	var els: Array[int] = elements_for(era)
	var facs: Array[float] = answers()
	var out: Array[Dictionary] = []
	var used: Dictionary = {}
	for i: int in int(cfg().get("questions", 5)):
		var want: int = rng.randi_range(0, facs.size() - 1)
		var pairs: Array[Vector2i] = []
		for a: int in els:
			for d: int in els:
				if not used.has(Vector2i(a, d)) and is_equal_approx(Elements.single(a, d), facs[want]):
					pairs.append(Vector2i(a, d))
		if pairs.is_empty():
			continue
		var p: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
		used[p] = true
		out.append({"atk": p.x, "def": p.y, "answer": want})
	return out

static func prompt(q: Dictionary, no: int, total: int) -> String:
	return Loc.t("Question %d of %d: %s into %s?") % [no, total,
		Loc.t(Elements.element_name(int(q.atk))), Loc.t(Elements.element_name(int(q.def)))]

## Notes a finished round with [param right] answers in [param records]. Returns {"best": int,
## "new_best": bool, "reward": String} (the item id on the first perfect round, else "").
static func finish(records: Dictionary, right: int, total: int) -> Dictionary:
	var key: String = str(cfg().get("best", "matchup_quiz_best"))
	var best: int = int(records.get(key, 0))
	var out: Dictionary = {"best": maxi(best, right), "new_best": right > best, "reward": ""}
	records[key] = out.best
	var paid: String = str(cfg().get("rewarded", "matchup_quiz_paid"))
	if total > 0 and right >= total and not bool(records.get(paid, false)):
		records[paid] = true
		out.reward = str(cfg().get("reward", ""))
	return out

## Plays one round in [param menu]. Returns the reward item id, "" for none (or when the player
## walks away mid-round).
static func play(menu: MenuHost, records: Dictionary, rng: RandomNumberGenerator, era: int) -> String:
	var qs: Array[Dictionary] = make_round(rng, era)
	var labels: Array[String] = answer_labels()
	var right: int = 0
	await menu.info(Loc.t("The keeper: Name the matchup. Out there a wrong answer costs a Spirling, in here only your pride."))
	for i: int in qs.size():
		var q: Dictionary = qs[i]
		var pick: int = await menu.pick_strings(prompt(q, i + 1, qs.size()), labels)
		if pick < 0:
			return ""
		if pick == int(q.answer):
			right += 1
			await menu.info(Loc.t("Right."))
		else:
			await menu.info(Loc.t("Wrong. It is %s.") % labels[int(q.answer)])
	var r: Dictionary = finish(records, right, qs.size())
	var lines: Array[String] = [Loc.t("%d of %d right. Best round: %d.") % [right, qs.size(), int(r.best)]]
	if not str(r.reward).is_empty():
		lines.append(Loc.t("The keeper: Every one. Take this before I change my mind: %s.") % Loc.t(str(Database.item(str(r.reward)).get("name", r.reward))))
	elif right < qs.size():
		lines.append(Loc.t("The keeper: The Hush will not be this patient with you."))
	await menu.info("\n".join(lines))
	return str(r.reward)
