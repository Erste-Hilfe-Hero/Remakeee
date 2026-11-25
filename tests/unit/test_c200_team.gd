extends GutTest
## Chimora 200 list items 83 (Spirlog progress in percent per era), 103 (held keepsake icon on
## the team picture) and 137 (event Spirlings with their own badge in the Spirlog).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _first_kind_of_era(era: int) -> SpirlingData:
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if sd.era == era:
			return sd
	return null

func test_held_mark_only_for_a_held_keepsake() -> void:
	assert_null(KeepsakeIcons.held_mark(""))
	var icons: Dictionary = KeepsakeKit.data().get("icons", {})
	var with_icon: String = str(icons.keys()[0])
	assert_eq(KeepsakeIcons.held_mark(with_icon), KeepsakeIcons.for_era(with_icon))
	assert_false(icons.has("tonic"))
	assert_not_null(KeepsakeIcons.held_mark("tonic"), "a keepsake without its own icon gets the charm shape")
