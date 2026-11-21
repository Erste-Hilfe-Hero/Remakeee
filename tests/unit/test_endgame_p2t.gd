extends GutTest
## Plan area 8, P2 batch: endgame data checks (3517, 3518), IP check of all endgame texts (3549)
## and a 30-day pause that loses nothing (3505). 3544 and 3545 are covered by test_waymarks.gd.

const DATA: Array[String] = ["res://data/endgame.json", "res://data/events.json", "res://data/achievements.json"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_endgame_data_is_clean() -> void:
	var errors: PackedStringArray = EndgameValidator.validate()
	assert_eq(errors.size(), 0, "\n".join(errors))

func test_validator_finds_broken_data() -> void:
	var errors: PackedStringArray = []
	var items: Dictionary = {"tonic": true}
	EndgameValidator._walk({"list": [{"id": "a", "item": "tonic", "waymarks": 5}, {"id": "a", "item": "ghost", "coins": 0}],
		"gifts": ["tonic", "nope"]}, "t", items, errors)
	var text: String = "\n".join(errors)
	assert_string_contains(text, "id 'a' twice")
	assert_string_contains(text, "unknown item 'ghost'")
	assert_string_contains(text, "unknown item 'nope'")
	assert_string_contains(text, "amount 0 is not above 0")
	assert_eq(errors.size(), 4)

## The same banned patterns as tools/ip_check.sh, read from it (they are base64 there).
func _ip_patterns() -> Array[RegEx]:
	var out: Array[RegEx] = []
	var sh: String = FileAccess.get_file_as_string("res://tools/ip_check.sh")
	var find := RegEx.create_from_string("printf '%s' '([A-Za-z0-9+/=]+)' \\| base64 -d")
	for m: RegExMatch in find.search_all(sh).slice(0, 2):
		var rx := RegEx.new()
		assert_eq(rx.compile("(?i)" + Marshalls.base64_to_utf8(m.get_string(1))), OK)
		out.append(rx)
	return out

func _strings(v: Variant, out: Array[String]) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k: Variant in v:
			out.append(str(k))
			_strings((v as Dictionary)[k], out)
	elif v is Array:
		for x: Variant in v:
			_strings(x, out)

func test_every_endgame_text_passes_the_ip_check() -> void:
	var rx: Array[RegEx] = _ip_patterns()
	assert_eq(rx.size(), 2, "term list and phrase list")
	var texts: Array[String] = []
	for path: String in DATA:
		_strings(JSON.parse_string(FileAccess.get_file_as_string(path)), texts)
	assert_gt(texts.size(), 100)
	for t: String in texts:
		for r: RegEx in rx:
			assert_null(r.search(t), t)

func test_thirty_days_away_loses_nothing() -> void:
	GameState.set_flag(GameState.ACT1_END_FLAG)
	GameState.rifts_sealed.append("cinder")
	Waymarks.earn(120, "daily_task")
	var arts: Array[String] = Collection.learnable_arts()
	for i: int in 20:
		Collection.note_art(arts[i])
	var today: Dictionary = DailyTasks.today()
	var day: String = str(today.day)
	var held: int = GameState.waymarks
	var log_size: int = (GameState.records.get("waymark_log", []) as Array).size()
	Online.clock_offset = 30 * 86400
	assert_ne(DailyTasks.day_key(), day, "a new day")
	var later: Dictionary = DailyTasks.today()
	assert_eq((later.tasks as Array).size(), (today.tasks as Array).size(), "a fresh set of tasks, all doable")
	for t: Variant in later.tasks:
		assert_true(DailyTasks.doable(DailyTasks.def(str((t as Dictionary).id)), DailyTasks.reached_maps(),
			DailyTasks.reachable_elements(DailyTasks.reached_maps()), DailyTasks.day_key()))
	assert_eq(GameState.waymarks, held, "no Waymarks lost")
	assert_eq((GameState.records.get("waymark_log", []) as Array).size(), log_size)
	assert_true(Exchange.is_open())
	assert_gt(Exchange.offers().size(), 0, "the stand still sells")
	var before: int = GameState.waymarks
	Collection.claim()
	assert_true((GameState.records.get("collection", {}) as Dictionary).has("arts_20"), "an old goal still pays")
	assert_gt(GameState.waymarks, before)
