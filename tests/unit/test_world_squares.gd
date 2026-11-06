extends GutTest
## Area 3 item 966: every town has a meeting place where people stand together at dusk.

const TOWNS: Array[String] = ["brindlewick", "thornridge", "copperfold", "wrenhollow", "reedhaven",
	"madderby", "corvane_quay", "cinderfold", "ashmere_station"]

func before_all() -> void:
	Database.load_all()

func test_every_town_gathers_at_its_square_at_dusk() -> void:
	for id: String in TOWNS:
		var m: MapData = MapData.load_map(id)
		assert_true(m.in_bounds(m.square), "%s has a square" % id)
		var dusk: Array[String] = WorldValidator.square_folk(m, DayCycle.Phase.DUSK)
		assert_gte(dusk.size(), WorldValidator.SQUARE_FOLK, "%s at dusk: %s" % [id, dusk])
		assert_lt(WorldValidator.square_folk(m, DayCycle.Phase.DAY).size(), dusk.size(),
			"%s: the square is fuller at dusk than by day" % id)

func test_the_square_is_a_landmark() -> void:
	var marks: Array = [TilesetFactory.Kind.SPRING, TilesetFactory.Kind.LAMP, TilesetFactory.Kind.SIGN]
	for id: String in TOWNS:
		var m: MapData = MapData.load_map(id)
		assert_has(marks, m.kind_at(m.square), id)

func test_validator_has_no_square_errors() -> void:
	var errors := PackedStringArray()
	WorldValidator.check_squares(errors, MapData.all_ids(), WorldValidator.load_layout())
	assert_eq(errors, PackedStringArray())
