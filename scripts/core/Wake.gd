class_name Wake
extends RefCounted
## The Wake: a funeral show in Gravers' Hall, held once a day. One Spirling performs one art
## before three mourners from data/wake.json; each scores the elements of the art and the
## performer (likes add, hates take away), plus the art's power and a few tears. Beat both
## rival entrants to win the prize. The Heir takes a bribe for extra points, but sometimes reads
## it out loud and the whole score drops to zero. Wins are counted in records["wake_wins"].

const DATA_PATH: String = "res://data/wake.json"
const DAY: String = "wake_day"
const WINS: String = "wake_wins"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

static func held_today(day: String) -> bool:
	return str(GameState.records.get(DAY, "")) == day

static func wins() -> int:
	return int(GameState.records.get(WINS, 0))

## The person being mourned on [param day] (the same for everyone that day).
static func deceased(day: String) -> String:
	var list: Array = data().get("deceased", [])
	return Loc.t(str(list[absi(day.hash()) % list.size()])) if not list.is_empty() else ""

## Element names the mourners see: the art's element and the performer's own elements.
static func shown_elements(s: Spirling, art: MoveData) -> Array[String]:
	var out: Array[String] = [Elements.element_name(art.element)]
	for e: int in s.data.elements:
		var n: String = Elements.element_name(e)
		if not n in out:
			out.append(n)
	return out

## One mourner's score for [param shown] elements; never below 0.
static func mourner_score(mourner: Dictionary, shown: Array[String]) -> int:
	var d: Dictionary = data()
	var score: int = int(d.get("base", 1))
	for n: String in shown:
		if n in mourner.get("likes", []):
			score += int(d.get("like_bonus", 3))
		if n in mourner.get("hates", []):
			score -= int(d.get("hate_malus", 2))
	return maxi(0, score)

## Performs [param art] with [param s]. [param bribe] means the Heir was paid.
## Returns {"score", "lines": Array[String], "betrayed": bool, "won": bool, "prize": int}.
static func perform(s: Spirling, art: MoveData, bribe: bool, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data()
	var shown: Array[String] = shown_elements(s, art)
	var lines: Array[String] = []
	var score: int = 0
	for m: Dictionary in d.get("mourners", []):
		var part: int = mourner_score(m, shown)
		score += part
		var liked: bool = false
		var hated: bool = false
		for n: String in shown:
			liked = liked or n in m.get("likes", [])
			hated = hated or n in m.get("hates", [])
		if hated:
			lines.append(Loc.t(str(m.hate_line)))
		elif liked:
			lines.append(Loc.t(str(m.like_line)))
	score += art.power / maxi(1, int(d.get("power_step", 30)))
	score += rng.randi_range(0, int(d.get("tears_max", 2)))
	var betrayed: bool = false
	if bribe:
		if rng.randf() < float(d.get("betray_chance", 0.0)):
			betrayed = true
			score = 0
			lines.append(Loc.t("The Heir stands up: \"This Wayfarer paid me. How touching.\" The hall goes silent."))
		else:
			score += int(d.get("bribe_bonus", 0))
			lines.append(Loc.t("The Heir winks and sniffs loudly. Very moving."))
	var won: bool = true
	for r: Dictionary in d.get("rivals", []):
		if score <= int(r.get("score", 0)):
			won = false
	return {"score": score, "lines": lines, "betrayed": betrayed, "won": won, "prize": int(d.get("prize_coins", 0)) if won else 0}

## Books the result of [param day]: one wake a day, prize paid, a win counted.
static func finish(result: Dictionary, day: String) -> void:
	GameState.records[DAY] = day
	GameState.money += int(result.get("prize", 0))
	if bool(result.get("won", false)):
		GameState.records[WINS] = wins() + 1
