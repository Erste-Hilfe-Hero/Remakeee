extends GutTest
## First Voices and Velahra (plan area 1, items 152-155).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func test_velahra_is_an_ancient_lumen_tide_voice_met_only_once() -> void:
	var sd: SpirlingData = Database.species("Velahra")
	assert_not_null(sd)
	assert_eq(sd.rarity, "ancient")
	assert_eq(sd.elements, [Elements.E.LUMEN, Elements.E.TIDE] as Array[int])
	assert_eq(sd.region, "veydal")
	var enc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for area: String in enc:
		for s: Dictionary in enc[area].spawns:
			assert_ne(str(s.species), "Velahra", "never in a wild table (%s)" % area)
	assert_true(ResourceLoader.exists("res://art/era1/spirlings/velahra_front.png"))

func test_lore_names_the_first_voices_and_mirela() -> void:
	var world: String = FileAccess.get_file_as_string("res://docs/WORLD.md")
	assert_string_contains(world, "First Voices")
	assert_string_contains(world, "six ancient Spirlings")
	assert_string_contains(Database.species("Velahra").lore, "Mirela")

func test_velahra_waits_on_the_shore_after_the_lamp_room() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/brindlewick.json"))
	var npc: Dictionary = {}
	for n: Dictionary in map.npcs:
		if n.id == "velahra":
			npc = n
	assert_eq(npc.get("show_flag"), "mirela_lamp")
	assert_eq(npc.get("hide_flag"), FirstVoices.away_flag("Velahra"))
	var dlg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/brindlewick.json"))
	assert_eq(dlg.velahra.action, "first_voice Velahra 40")
	assert_true(ResourceLoader.exists("res://art/era1/chars/first_voice.png"))
	assert_true("voice" in BattleBackdrop.KINDS)

func test_a_missed_voice_returns_after_the_next_rest() -> void:
	assert_false(FirstVoices.waiting("Velahra"), "not before the finale")
	GameState.set_flag("mirela_lamp")
	assert_true(FirstVoices.waiting("Velahra"))
	GameState.set_flag(FirstVoices.away_flag("Velahra"))
	assert_false(FirstVoices.waiting("Velahra"), "it rests after a meeting")
	FirstVoices.after_rest()
	assert_true(FirstVoices.waiting("Velahra"), "back after the next rest")

func test_a_bonded_voice_stays_with_the_player() -> void:
	GameState.set_flag("mirela_lamp")
	GameState.receive_spirling(Spirling.new(Database.species("Velahra"), 40))
	assert_true(FirstVoices.is_bonded("Velahra"))
	GameState.set_flag(FirstVoices.away_flag("Velahra"))
	GameState.set_flag(FirstVoices.bonded_flag("Velahra"))
	FirstVoices.after_rest()
	assert_false(FirstVoices.waiting("Velahra"))

func test_bonding_a_voice_uses_the_long_echo_call() -> void:
	var plan: Dictionary = BondEcho.make_plan(RandomNumberGenerator.new(), Database.species("Velahra"))
	assert_eq((plan.phases as Array).size(), 2)
	assert_eq((plan.phases[0] as Array).size(), 5)
	assert_true(plan.sky, "Lumen marks")
