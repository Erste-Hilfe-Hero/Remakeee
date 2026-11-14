extends GutTest
## Owner rule (Nov 2026): every act and era region is hard. The act simulator (ActSim) plays the
## route of tools/balance/act_route.json for every starter on Tamer and measures each Warden, rival
## and boss on arrival and after a moderate grind. These tests pin the bands of the route file, so
## new content cannot make an act easy again (or put up a wall). The CI run uses few battles per
## measure, so the bands get a margin.

const TRIALS: int = 16
const MARGIN: float = 0.08

static var _sum: Dictionary = {}
static var _cfg: Dictionary = {}
static var _runs: Array = []

func before_all() -> void:
	Database.load_all()
	if _sum.is_empty():
		_cfg = ActSim.route()
		_runs.clear()
		for st: Variant in _cfg.starters:
			_runs.append(ActSim.run(str(st), TRIALS, 1234))
		_sum = ActSim.summary(_runs)

func test_every_route_step_resolves() -> void:
	for act: Dictionary in _cfg.acts:
		for step: Dictionary in act.steps:
			if step.has("wild"):
				assert_false(ActSim.wild_table(str(step.wild)).is_empty(), "%s: wild %s" % [act.id, step.wild])
			for k: String in ["fight", "boss"]:
				if step.has(k):
					var foe: Dictionary = ActSim.resolve(str(step[k]))
					assert_false(foe.is_empty(), "%s: %s %s" % [act.id, k, step[k]])
					if not foe.is_empty():
						assert_false(TrainerData.team_entries(foe.def, "", 1).is_empty(), str(step[k]))

func test_every_act_and_era_is_measured() -> void:
	assert_eq(_sum.acts.size(), (_cfg.acts as Array).size())
	for a: Dictionary in _sum.acts:
		assert_gte((a.fights as Array).size(), 4, "%s measures its Wardens, rivals and bosses" % a.id)

func test_arrival_is_hard_in_every_act() -> void:
	var band: Array = _cfg.bands.win_arrival
	for a: Dictionary in _sum.acts:
		assert_between(float(a.win_arrival), float(band[0]) - MARGIN, float(band[1]) + MARGIN,
			"%s: %d%% won on arrival" % [a.id, roundi(a.win_arrival * 100.0)])

func test_no_measured_fight_is_a_pushover() -> void:
	var top: float = float(_cfg.bands.fight_arrival_max)
	for a: Dictionary in _sum.acts:
		for f: Dictionary in a.fights:
			if f.kind == ActSim.HEART:
				continue
			assert_lte(float(f.win_arrival), top + 2.0 * MARGIN, "%s %s: %d%% on arrival" % [a.id, f.name, roundi(f.win_arrival * 100.0)])

func test_training_wins_and_there_are_no_walls() -> void:
	var need: float = float(_cfg.bands.win_moderate_min)
	for a: Dictionary in _sum.acts:
		assert_gte(float(a.win_moderate), need - MARGIN, "%s: %d%% after the moderate grind" % [a.id, roundi(a.win_moderate * 100.0)])
		assert_eq(int(a.walls), 0, "%s: a fight not won at 70 %% after %d grind battles" % [a.id, int(_cfg.grind_max)])

## Item 942: the targets per act. The grind a fight needs to reach grind_target stays within the
## act's own budget (moderate_grind) on the mean; one grind step of margin for the few CI battles.
func test_mean_grind_stays_within_each_act_budget() -> void:
	var acts: Dictionary = {}
	for a: Dictionary in _cfg.acts:
		acts[a.id] = a
	for a: Dictionary in _sum.acts:
		var budget: int = int(acts[a.id].get("moderate_grind", _cfg.moderate_grind))
		assert_lte(float(a.grind_needed), float(budget + int(_cfg.grind_step)),
			"%s: %.0f grind battles to %d %% on the mean, budget %d" % [a.id, a.grind_needed, roundi(float(_cfg.grind_target) * 100.0), budget])

## Item 943: the starters are equally strong where it counts most. In the acts of
## bands.starters_even every starter alone wins after the act's budget and needs no more grind.
func test_every_starter_clears_the_even_acts_alone() -> void:
	var even: Array = _cfg.bands.get("starters_even", [])
	assert_false(even.is_empty(), "act_route.json bands.starters_even names at least Act I")
	var need: float = float(_cfg.bands.win_moderate_min)
	for r: Dictionary in _runs:
		var one: Dictionary = ActSim.summary([r])
		for a: Dictionary in one.acts:
			if not str(a.id) in even:
				continue
			var budget: int = 0
			for act: Dictionary in _cfg.acts:
				if act.id == a.id:
					budget = int(act.get("moderate_grind", _cfg.moderate_grind))
			assert_gte(float(a.win_moderate), need - MARGIN, "%s %s: %d%% after the budget" % [r.starter, a.id, roundi(a.win_moderate * 100.0)])
			assert_lte(float(a.grind_needed), float(budget + int(_cfg.grind_step)), "%s %s: %.0f grind battles, budget %d" % [r.starter, a.id, a.grind_needed, budget])

## docs/BALANCE.md carries the targets of every act (test_balance_doc checks the text matches).
func test_targets_are_written_down_per_act() -> void:
	var table: String = BalanceDoc.act_targets_table()
	for a: Dictionary in _cfg.acts:
		assert_string_contains(table, "| %s | %d |" % [a.name, int(a.moderate_grind)])
	assert_string_contains(FileAccess.get_file_as_string(BalanceDoc.DOC_PATH), "<!-- gen:act_targets -->")

func test_each_act_is_steeper_than_the_one_before() -> void:
	var last: Dictionary = {}
	for a: Dictionary in _sum.acts:
		if not last.is_empty():
			assert_lte(float(a.win_arrival), float(last.win_arrival) + float(_cfg.bands.steeper_margin) + MARGIN,
				"%s (%d%%) after %s (%d%%)" % [a.id, roundi(a.win_arrival * 100.0), last.id, roundi(last.win_arrival * 100.0)])
		last = a

## The first half hour stays a tutorial: the newcomer fights of the route keep their own small teams
## with no harder Tamer block.
func test_newcomer_fights_stay_easy() -> void:
	for ref: Variant in _cfg.bands.newcomer:
		var foe: Dictionary = ActSim.resolve(str(ref))
		assert_false(foe.is_empty(), str(ref))
		if foe.is_empty():
			continue
		assert_false(TrainerData.has_block(foe.def, 1), "%s has no Tamer block" % ref)
		for e: Dictionary in TrainerData.team_entries(foe.def, "", 1):
			assert_lte(int(e.get("level", 5)), int(_cfg.bands.newcomer_ring_max), "%s %s" % [ref, e.species])

func test_same_seed_same_route() -> void:
	var a: Dictionary = ActSim.run("Kindlop", 2, 77, ["act1"] as Array[String])
	var b: Dictionary = ActSim.run("Kindlop", 2, 77, ["act1"] as Array[String])
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_string_contains(ActSim.report(ActSim.summary([a]), ["Kindlop"], 2), "| Act I: Veydal |")
