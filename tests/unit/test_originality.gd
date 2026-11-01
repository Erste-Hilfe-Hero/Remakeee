extends GutTest
## Guards the originality pass (docs/legal/IP_PATENT_AUDIT.md, item 15): the numbers and shapes
## that would make Chimora read as a copy of the genre's best-known series stay changed.

func test_team_level_and_spark_limits_are_our_own() -> void:
	assert_eq(GameState.MAX_PARTY, 5)
	assert_eq(BattleModel.MAX_PARTY, GameState.MAX_PARTY)
	assert_eq(Spirling.MAX_LEVEL, 60)
	assert_ne(Spirling.SPARK_MAX, 15)

func test_keen_hits_and_statuses_use_our_own_numbers() -> void:
	assert_ne(DamageCalc.CRIT_CHANCE, 1.0 / 16.0)
	assert_ne(DamageCalc.CRIT_MULT, 1.5)
	assert_ne(StatusRules.tick_div("scorch"), 16)
	assert_ne(StatusRules.skip_chance("jolt"), 0.25)

func test_starters_are_not_an_element_ring() -> void:
	var els: Array[int] = []
	for sp: String in Database.STARTERS:
		els.append(Database.species(sp).elements[0])
	assert_eq(els.size(), 3)
	# In a ring each starter beats the next one; ours must not close that loop.
	var ring: bool = true
	for i: int in 3:
		if not els[(i + 1) % 3] in Elements.STRONG[els[i]]:
			ring = false
	var reverse: bool = true
	for i: int in 3:
		if not els[i] in Elements.STRONG[els[(i + 1) % 3]]:
			reverse = false
	assert_false(ring or reverse, "starter elements form a rock-paper-scissors ring")

func test_starters_do_not_evolve_at_the_classic_levels() -> void:
	for sp: String in Database.STARTERS:
		var d: SpirlingData = Database.species(sp)
		while d != null:
			assert_false(d.evolve_level in [16, 32, 34, 36], "%s evolves at a classic level" % d.species_name)
			d = d.evolves_to

func test_era_one_palette_is_not_green() -> void:
	for c: Color in EraManager.INK_PALETTE:
		assert_false(c.g > c.r and c.g > c.b, "Era I tone %s is green-dominant" % c.to_html(false))

func test_hp_bar_has_no_traffic_light() -> void:
	assert_false("HP_MID" in (load("res://scripts/battle/presenter/InfoStrip.gd") as GDScript).get_script_constant_map())
