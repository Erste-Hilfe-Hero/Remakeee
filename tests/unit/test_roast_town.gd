extends GutTest
## Rude townsfolk (Ali, 7 Nov): neighbours roast each other, four teased figures pay coins
## once a day to make it stop.

const TARGETS: Dictionary[String, String] = {"wrenhollow/orrin": "orrin", "brindlewick/wim": "wim",
	"reedhaven/aart": "aart", "thornridge/ivo": "ivo"}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_tip_pays_once_a_day() -> void:
	var before: int = GameState.money
	assert_eq(GameState.pay_tip("orrin", 60, 100), 60)
	assert_eq(GameState.money, before + 60)
	assert_eq(GameState.pay_tip("orrin", 60, 100), 0, "only once a day")
	assert_eq(GameState.pay_tip("wim", 80, 100), 80, "each figure pays on its own")
	assert_eq(GameState.pay_tip("orrin", 60, 101), 60, "again the next day")
	assert_eq(GameState.pay_tip("orrin", 0, 102), 0)

func test_teased_figures_offer_the_paying_choice() -> void:
	for ref: String in TARGETS:
		var e: Dictionary = Dialogue.get_entry(ref)
		var choices: Array[Dictionary] = Dialogue.choices_for(e, {})
		assert_eq(choices.size(), 2, ref)
		var pay: Dictionary = Dialogue.get_entry(ref.get_slice("/", 0) + "/" + str(choices[0].next))
		assert_string_contains(str(pay.get("action", "")), "tip ", ref)
		assert_string_contains(str(pay.get("action", "")), TARGETS[ref], ref)

func test_tip_is_a_known_action() -> void:
	assert_true("tip" in StoryValidator.known_actions())
