extends GutTest
## Vellmarch's own 70 Spirlings (tools/art/lines/vellmarch.py, drawn in Era II by
## tools/art/gen_era2.py): data, art, wild slots, Warden aces and the Rust and Mask arts.

var _kinds: Array[SpirlingData] = []

func before_all() -> void:
	Database.load_all()
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "vellmarch":
			_kinds.append(sd)

func test_seventy_era_two_kinds_with_their_own_art() -> void:
	assert_eq(_kinds.size(), 70, "every era region has 70 own Spirlings")
	for sd: SpirlingData in _kinds:
		assert_eq(sd.era, 2, sd.species_name)
		assert_eq(EraManager.sprite_path(sd.species_name), "res://art/era2/spirlings/%s_front.png" % sd.species_name.to_lower())
		assert_eq(EraManager.sprite_path(sd.species_name, "back"), "res://art/era2/spirlings/%s_back.png" % sd.species_name.to_lower())
		assert_eq(EraManager.battle_sprite_size(sd.species_name), 56)
		assert_false(sd.lore.is_empty(), sd.species_name)

func test_lines_keep_their_elements() -> void:
	for sd: SpirlingData in _kinds:
		for u: Dictionary in sd.unfold:
			var to: SpirlingData = u.to
			assert_not_null(to, sd.species_name)
			if to != null:
				assert_eq(to.line_id, sd.line_id, "%s grows into its own line" % sd.species_name)
				assert_eq(to.elements, sd.elements, "%s keeps its elements" % sd.species_name)
				assert_eq(to.region, "vellmarch")

func test_region_elements_rust_and_mask_are_on_its_kinds() -> void:
	var count: Dictionary = {}
	for sd: SpirlingData in _kinds:
		for e: int in sd.elements:
			count[e] = int(count.get(e, 0)) + 1
	for e: String in Region2.data().elements:
		assert_gte(int(count.get(Elements.E[e], 0)), 6, "%s on Vellmarch kinds" % e)

func test_rust_and_mask_have_their_own_arts() -> void:
	for e: String in ["RUST", "MASK"]:
		var all: int = 0
		var status: int = 0
		var cheap: int = 0
		var big: int = 0
		for mv: MoveData in Database.moves.values():
			if mv.element != Elements.E[e]:
				continue
			all += 1
			status += 1 if mv.kind == MoveData.Kind.STATUS else 0
			cheap += 1 if mv.energy_cost <= 2 and mv.kind != MoveData.Kind.STATUS else 0
			big += 1 if mv.cooldown > 0 else 0
		assert_gte(all, 8, "%s arts" % e)
		assert_gte(status, 2, "%s status arts" % e)
		assert_gte(cheap, 1, "%s cheap hit" % e)
		assert_gte(big, 1, "%s finisher" % e)

func test_every_kind_can_be_met_in_vellmarch() -> void:
	var wild: Dictionary = {}
	for r: Dictionary in Region2.data().routes:
		for s: String in EncounterTable.species_on(str(r.id)):
			wild[s] = true
	var reach: Dictionary = wild.duplicate()
	var grew: bool = true
	while grew:
		grew = false
		for sd: SpirlingData in _kinds:
			if not reach.has(sd.species_name):
				continue
			for u: Dictionary in sd.unfold:
				var to: SpirlingData = u.to
				if not reach.has(to.species_name):
					reach[to.species_name] = true
					grew = true
	for sd: SpirlingData in _kinds:
		assert_true(reach.has(sd.species_name), "%s wild or unfolded from a wild kind" % sd.species_name)

func test_slots_and_warden_aces_hold_own_kinds() -> void:
	for r: Dictionary in Region2.data().routes:
		for s: Dictionary in r.slots:
			assert_eq(Database.species(Region2.slot_species(s)).region, "vellmarch", str(s.slot))
	for w: Dictionary in Region2.wardens():
		for t: Dictionary in w.team:
			if t.has("slot"):
				var sd: SpirlingData = Database.species(Region2.slot_species(t))
				assert_eq(sd.region, "vellmarch", str(t.slot))
				assert_true(sd.unfold.is_empty(), "%s: a Warden's ace is a final form" % w.id)

func test_spirlog_chapter_opens_after_the_story() -> void:
	assert_true(SpirlingData.REGIONS.has("vellmarch"))
	assert_false(SpirlogBook.region_open("vellmarch", {}))
	assert_true(SpirlogBook.region_open("vellmarch", {"story_complete": true}))

func test_lore_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for sd: SpirlingData in _kinds:
		assert_ne(str(de.get(sd.lore, "")), "", "%s lore in German" % sd.species_name)
		assert_ne(str(de.get(sd.habitat, "")), "", "%s habitat in German" % sd.species_name)
