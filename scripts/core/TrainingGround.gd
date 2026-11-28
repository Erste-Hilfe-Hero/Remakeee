class_name TrainingGround
extends RefCounted
## The training ring in the lighthouse (docs/KAMPF_PLAN_1000.md, area "Fortschritt, XP und
## Training"): bouts against carved dummies without risk, training goals with rewards and a
## training record. Tuning in data/training.json; progress in GameState.records["training"].

const PATH: String = "res://data/training.json"
const RECORD: String = "training"
const MIN_RING: int = 2

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

static func dummies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(data().get("dummies", []))
	return out

static func goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(data().get("goals", []))
	return out

## The ring of a dummy against a team whose highest ring is [param top].
static func ring_for(dummy: Dictionary, top: int) -> int:
	return maxi(MIN_RING, top + int(dummy.get("ring_offset", 0)))

## A dummy as a Spirling: the kind's body under the dummy's wooden name.
static func make(dummy: Dictionary, top: int, rng: RandomNumberGenerator) -> Spirling:
	var sd: SpirlingData = Database.species(str(dummy.get("species", "")))
	if sd == null:
		return null
	var s := Spirling.new(sd, ring_for(dummy, top), rng)
	s.nickname = Loc.t(str(dummy.get("name", "Dummy")))
	return s

## The trainer block for Overworld.start_battle: a friendly bout, no coins, AI tier 0.
static func bout_info(dummy: Dictionary) -> Dictionary:
	return {"name": Loc.t(str(dummy.get("name", "Dummy"))), "friendly": true, "practice": true, "ai": 0, "money": 0}

static func state(records: Dictionary) -> Dictionary:
	return records.get(RECORD, {})

## Books a bout. Returns the goals it met, each {"id", "text", "reward"}; their rewards are
## the caller's to hand out.
static func after_bout(records: Dictionary, dummy_id: String, won: bool, growth: int) -> Array[Dictionary]:
	var st: Dictionary = state(records).duplicate(true)
	st["bouts"] = int(st.get("bouts", 0)) + 1
	st["growth"] = int(st.get("growth", 0)) + maxi(0, growth)
	if won:
		st["wins"] = int(st.get("wins", 0)) + 1
		var by: Dictionary = st.get("by_dummy", {})
		by[dummy_id] = int(by.get(dummy_id, 0)) + 1
		st["by_dummy"] = by
	var met: Array = st.get("goals", [])
	var out: Array[Dictionary] = []
	for g: Dictionary in goals():
		if str(g.id) in met or not is_met(st, g):
			continue
		met.append(str(g.id))
		out.append(g)
	st["goals"] = met
	records[RECORD] = st
	return out

static func is_met(st: Dictionary, g: Dictionary) -> bool:
	var need: int = int(g.get("wins", 1))
	if g.has("dummy"):
		return int((st.get("by_dummy", {}) as Dictionary).get(str(g.dummy), 0)) >= need
	return int(st.get("wins", 0)) >= need

## The goal list with marks for met ones.
static func goal_lines(records: Dictionary) -> Array[String]:
	var met: Array = state(records).get("goals", [])
	var out: Array[String] = []
	for g: Dictionary in goals():
		var item: String = Loc.t(str(Database.item(str(g.get("reward", ""))).get("name", g.get("reward", ""))))
		out.append("%s %s (%s)" % ["[x]" if str(g.id) in met else "[ ]", Loc.t(str(g.text)), item])
	return out

## The training record: bouts, wins, growth, wins per dummy.
static func stat_lines(records: Dictionary) -> Array[String]:
	var st: Dictionary = state(records)
	var out: Array[String] = [Loc.t("Bouts: %d") % int(st.get("bouts", 0)), Loc.t("Wins: %d") % int(st.get("wins", 0)),
		Loc.t("Growth from training: %d") % int(st.get("growth", 0))]
	var by: Dictionary = st.get("by_dummy", {})
	for d: Dictionary in dummies():
		out.append("  %s: %d" % [Loc.t(str(d.name)), int(by.get(str(d.id), 0))])
	return out
