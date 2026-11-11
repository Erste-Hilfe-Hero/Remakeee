extends GutTest
## Clan intrigue and the hidden trust system (Trust.gd, data/clans.json, docs/STORY.md).

const STRANGERS: Array[String] = ["aldra", "amir", "elma", "farida", "heider", "kenan", "leith",
	"lejla", "lipka", "mirza", "nail"]

func before_each() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)

func test_values_are_start_plus_change_and_clamped() -> void:
	assert_eq(Trust.value(60, -15), 45)
	assert_eq(Trust.value(10, -50), 0)
	assert_eq(Trust.value(90, 50), 100)
	var start: int = int(Trust.figure("marlo").trust)
	assert_eq(Trust.trust_in("marlo", {}), start)
	assert_eq(Trust.trust_in("marlo", {"trust_marlo": -15}), start - 15)

func test_betrayal_happens_when_use_beats_trust() -> void:
	assert_true(Trust.betrays(20, 21))
	assert_false(Trust.betrays(20, 20), "a tie keeps the figure loyal")
	assert_false(Trust.betrays(50, 10))

func test_favor_resolution_is_deterministic() -> void:
	var def: Dictionary = {"reward_chance": 0.5}
	assert_eq(Trust.resolve(def, 10, 40, 0.0), "betray", "betrayal ignores the roll")
	assert_eq(Trust.resolve(def, 40, 10, 0.49), "reward")
	assert_eq(Trust.resolve(def, 40, 10, 0.5), "kept")
	assert_eq(Trust.resolve({}, 40, 10, 0.0), "kept", "no reward chance, no reward")

func test_scripted_betrayal_rules() -> void:
	var warned: Dictionary = {"rule": "warned", "warned_by": ["a", "b"]}
	assert_eq(Trust.betrayal_result(warned, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(warned, {"b": true}, {}), "caught")
	var marlo: Dictionary = Trust.betrayal("marlo_fate")
	assert_eq(Trust.betrayal_result(marlo, {}, {}), "caught", "an honest friend survives")
	assert_eq(Trust.betrayal_result(marlo, {}, {"trust_marlo": -15}), "caught", "one alibi is forgiven")
	assert_eq(Trust.betrayal_result(marlo, {}, {"trust_marlo": -30}), "struck", "two alibis cost Marlo")

func test_apply_values_adds_changes() -> void:
	var vars: Dictionary = {"trust_pip": 5}
	Trust.apply_values({"trust": {"pip": 10, "marlo": -15}, "use": {"pip": 3}}, vars)
	assert_eq_deep(vars, {"trust_pip": 15, "trust_marlo": -15, "use_pip": 3})

func test_choices_shift_who_betrays() -> void:
	# Lipka is loyal until the cover-up makes the player worth selling.
	var lipka: Dictionary = Trust.favor("lipka_tip")
	var vars: Dictionary = {}
	assert_ne(Trust.resolve(lipka, Trust.trust_in("lipka", vars), Trust.use_in("lipka", vars), 0.9), "betray")
	Trust.apply_values({"use": {"lipka": 10}}, vars)
	assert_eq(Trust.resolve(lipka, Trust.trust_in("lipka", vars), Trust.use_in("lipka", vars), 0.9), "betray")

func test_trust_condition_in_dialogue() -> void:
	assert_true(Dialogue.check({"trust_min": {"marlo": 40}}, GameState.flags))
	GameState.add_story_var("trust_marlo", -30)
	assert_false(Dialogue.check({"trust_min": {"marlo": 40}}, GameState.flags))
	assert_true(Dialogue.check({"trust_max": {"marlo": 40}}, GameState.flags))

func test_ledger_rows_follow_flags_in_data_order() -> void:
	assert_true(Trust.ledger_rows({}).is_empty())
	var rows: Array[Dictionary] = Trust.ledger_rows({"ledger_war": true, "ledger_ash": true})
	assert_eq(rows.size(), 2)
	assert_eq(str(rows[0].id), "ash")
	assert_eq(str(rows[1].id), "war")
	for e: Variant in Trust.data().ledger:
		assert_gte(Trust.ledger_text(str(e.ref)).size(), 2, "title and text: %s" % e.id)

func test_ledger_menu_only_with_entries() -> void:
	assert_false("Ledger" in PauseMenu.menu_labels(false, false, false, false, true))
	var labels: Array[String] = PauseMenu.menu_labels(false, false, false, false, true, true)
	assert_eq(labels.find("Ledger"), labels.find("Map book") + 1)

func test_eleven_strangers_with_allies_and_traitors() -> void:
	var allies: int = 0
	for id: String in STRANGERS:
		var f: Dictionary = Trust.figure(id)
		assert_eq(str(f.get("clan", "")), "strangers", id)
		allies += 1 if bool(f.get("ally", false)) else 0
		assert_true(Dialogue.exists("clans/" + id), "%s has a dialogue" % id)
	assert_between(allies, 3, 8, "some allies, some traitors")

func test_two_betrayals_per_act() -> void:
	var set_by: Dictionary = {}
	for group: String in ["favors", "betrayals"]:
		for id: Variant in Trust.data()[group]:
			var d: Dictionary = Trust.data()[group][id]
			for r: String in ["betray", "reward", "kept", "caught", "struck"]:
				for f: Variant in Trust.effects(d, r).get("flags", []):
					set_by[str(f)] = true
	for n: int in range(1, 9):
		assert_true(set_by.has("clan_b%d" % n), "betrayal %d is set by some outcome" % n)

func test_clan_data_and_dialogue_are_valid() -> void:
	assert_eq(Trust.validate(), PackedStringArray())
	var story: PackedStringArray = []
	for e: String in StoryValidator.validate():
		if e.contains("clans") or e.contains("ambush"):
			story.append(e)
	assert_eq(story, PackedStringArray())
