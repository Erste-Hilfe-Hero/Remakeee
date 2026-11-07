extends GutTest
## Area 3 items 907 and 934: outdoor maps fit the screen, routes have two ways out.

func before_all() -> void:
	Database.load_all()

func test_outdoor_maps_fit_and_routes_lead_both_ways() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_shapes(errors, MapData.all_ids(), WorldValidator.load_layout())
	assert_eq(errors.size(), 0, "\n".join(errors))
	assert_eq(WorldValidator.MAX_OUTDOOR_W, 12)
	assert_eq(WorldValidator.MAX_OUTDOOR_H, 40)

func test_a_dead_end_route_is_reported() -> void:
	var layout: Dictionary = WorldValidator.load_layout().duplicate(true)
	# Reedhaven has one road out; as a route it would be a dead end.
	(layout.maps.reedhaven as Dictionary).kind = "route"
	var errors: PackedStringArray = []
	WorldValidator.check_shapes(errors, PackedStringArray(["reedhaven"]), layout)
	assert_eq(errors.size(), 0, "the Lake Line counts as a second way")
	# Kindle Vents is a cave with one way in; as a route it is reported.
	(layout.maps.kindle_vents as Dictionary).kind = "route"
	WorldValidator.check_shapes(errors, PackedStringArray(["kindle_vents"]), layout)
	assert_eq(errors.size(), 1, "a route with one way out")

func test_town_signs_count_their_folk() -> void:
	# Item 962.
	for id: String in ["brindlewick", "thornridge", "wrenhollow", "reedhaven", "copperfold", "corvane_quay",
			"madderby", "cinderfold", "ashmere_station"]:
		var e: Dictionary = Dialogue.get_entry("%s/sign" % id)
		var text: String = " ".join(Dialogue.lines_for(e, {}))
		assert_true(text.contains(" folk."), "%s sign: %s" % [id, text])
