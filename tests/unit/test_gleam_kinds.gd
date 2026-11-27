extends GutTest
## Gleam kinds (1.3.2, data/gleam.json "kinds"): odds per kind with the chain bonus, one
## deterministic draw, the shop never selling a kind, palettes for every species and kind, save
## and trade back-compat, the server's kind list, and how each kind shows (sprite, plate,
## summary, party, trade, Spirlog).

const SEED: int = 7177
const DRAWS: int = 4000
const FIXTURES: String = "res://tests/fixtures/saves/"
const MIGRATION: String = "res://supabase/migrations/20261127160000_gleam_kinds.sql"
const RARE: Array[String] = ["rime", "inkwash", "duskgold", "opaline"]

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)

func _cfg() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GleamRules.CONFIG_PATH))

# --- Odds -----------------------------------------------------------------------------------

func test_kinds_come_from_data_classic_first() -> void:
	var ids: Array[String] = GleamRules.kind_ids()
	var want: Array[String] = [GleamRules.CLASSIC]
	for k: Dictionary in _cfg().kinds:
		if str(k.id) != GleamRules.CLASSIC:
			want.append(str(k.id))
	assert_eq(ids, want)
	assert_gte(ids.size(), 5, "classic plus four rarer kinds")
	for id: String in RARE:
		assert_true(GleamRules.is_kind(id), id)
	assert_false(GleamRules.is_kind("nonsense"))

func test_classic_odds_stay_one_in_1024() -> void:
	assert_eq(GleamRules.kind_one_in(GleamRules.CLASSIC), 1024)
	for chain: int in [0, 1, 5, GleamRules.chain_max() + 3]:
		assert_almost_eq(GleamRules.kind_chance(GleamRules.CLASSIC, chain), GleamRules.chance(chain), 1e-12)

func test_rarer_kinds_take_their_odds_from_data_and_are_rarer() -> void:
	for k: Dictionary in _cfg().kinds:
		var id: String = str(k.id)
		if id == GleamRules.CLASSIC:
			continue
		assert_eq(GleamRules.kind_one_in(id), int(k.one_in), id)
		assert_almost_eq(GleamRules.kind_chance(id, 0), 1.0 / float(k.one_in), 1e-12, id)
		assert_lt(GleamRules.kind_chance(id, 0), GleamRules.kind_chance(GleamRules.CLASSIC, 0), id + " is rarer than the classic kind")
	assert_eq(GleamRules.kind_one_in("opaline"), 65536, "the shimmering kind is the rarest")
	for id: String in RARE:
		assert_lte(GleamRules.kind_one_in(id), GleamRules.kind_one_in("opaline"))

func test_chain_bonus_applies_to_every_kind_up_to_its_cap() -> void:
	var step: float = float(GleamRules.config().chain_step)
	for id: String in GleamRules.kind_ids():
		var base: float = GleamRules.kind_chance(id, 0)
		assert_almost_eq(GleamRules.kind_chance(id, 2), base * (1.0 + 2.0 * step), 1e-12, id)
		assert_eq(GleamRules.kind_chance(id, GleamRules.chain_max() + 9), GleamRules.kind_chance(id, GleamRules.chain_max()), id + " capped")

func test_shop_scent_only_scales_the_classic_kind() -> void:
	assert_almost_eq(GleamRules.kind_chance(GleamRules.CLASSIC, 0, 1.0, 10.0), 10.0 / 1024.0, 1e-12)
	for id: String in RARE:
		assert_eq(GleamRules.kind_chance(id, 0, 1.0, 10.0), GleamRules.kind_chance(id, 0), id + ": no paid odds")
	# A free boost (Rustle Spots) counts for every kind.
	for id: String in RARE:
		assert_almost_eq(GleamRules.kind_chance(id, 0, 4.0), 4.0 * GleamRules.kind_chance(id, 0), 1e-12, id)

func test_total_is_the_sum_of_the_kinds() -> void:
	var sum: float = 0.0
	for id: String in GleamRules.kind_ids():
		sum += GleamRules.kind_chance(id, 3)
	assert_almost_eq(GleamRules.total_chance(3), sum, 1e-12)

func test_roll_kind_is_deterministic_and_one_draw() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = SEED
	b.seed = SEED
	for i: int in DRAWS:
		assert_eq(GleamRules.roll_kind(a, i % 12, 50.0), GleamRules.roll_kind(b, i % 12, 50.0))
	var probe := RandomNumberGenerator.new()
	probe.seed = SEED
	for i: int in DRAWS:
		probe.randf()
	assert_eq(a.randi(), probe.randi(), "exactly one draw per roll keeps replays in step")

func test_roll_kind_follows_the_slices() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = SEED
	var probe := RandomNumberGenerator.new()
	probe.seed = SEED
	var mult: float = 120.0
	for i: int in DRAWS:
		var x: float = probe.randf()
		var want: String = ""
		var edge: float = 0.0
		for id: String in GleamRules.kind_ids():
			edge += GleamRules.kind_chance(id, 0, mult)
			if x < edge:
				want = id
				break
		assert_eq(GleamRules.roll_kind(r, 0, mult), want)

func test_classic_kind_exactly_when_the_old_roll_hits() -> void:
	var r := RandomNumberGenerator.new()
	var old := RandomNumberGenerator.new()
	r.seed = SEED
	old.seed = SEED
	for i: int in DRAWS:
		var kind: String = GleamRules.roll_kind(r, i % 12, 30.0)
		assert_eq(kind == GleamRules.CLASSIC, GleamRules.roll(old, i % 12, 30.0), "same draw, same classic Gleams as before")

func test_every_kind_turns_up_in_proportion() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = SEED
	var mult: float = 200.0
	var n: int = 40000
	var got: Dictionary = {}
	for i: int in n:
		var k: String = GleamRules.roll_kind(r, 0, mult)
		got[k] = int(got.get(k, 0)) + 1
	for id: String in GleamRules.kind_ids():
		var want: float = GleamRules.kind_chance(id, 0, mult) * n
		assert_gt(int(got.get(id, 0)), 0, id + " turns up")
		assert_almost_eq(float(got.get(id, 0)), want, maxf(want * 0.35, 6.0), id)

func test_wild_encounters_roll_kinds_deterministically() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = SEED
	b.seed = SEED
	for i: int in 200:
		var x: Spirling = EncounterTable.roll("fernstair", a, [], "", {"species": "", "count": 0})
		var y: Spirling = EncounterTable.roll("fernstair", b, [], "", {"species": "", "count": 0})
		assert_eq(x.gleam_kind, y.gleam_kind)
		assert_eq(x.gleam, x.gleam_kind != "", "kind set exactly on a Gleam")

# --- No paid random content -----------------------------------------------------------------

func test_shop_sells_no_gleam_kind() -> void:
	var shop: String = FileAccess.get_file_as_string("res://data/shop.json")
	assert_false(shop.contains("gleam_kind"))
	for id: String in RARE:
		assert_false(shop.contains("\"%s\"" % id), id + " is not sold")
		assert_false(shop.contains(GleamRules.kind_name(id)), GleamRules.kind_name(id) + " is not sold")

func test_gleam_prism_gives_the_classic_kind_and_keeps_a_wild_kind() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 5)
	GameState.add_item("rg_gleam_prism")
	assert_true(GameState.use_gleam_prism(s))
	assert_eq(GleamRules.kind_of(s), GleamRules.CLASSIC)
	var w := Spirling.new(Database.species("Zippit"), 5)
	GleamRules.apply(w, "opaline")
	GameState.add_item("rg_gleam_prism")
	assert_true(GameState.use_gleam_prism(w))
	assert_eq(w.gleam_kind, "opaline")

# --- Save format ----------------------------------------------------------------------------

func test_old_gleam_without_kind_loads_as_classic() -> void:
	var s: Spirling = Spirling.from_dict({"species": "Kindlop", "level": 5, "gleam": true})
	assert_eq(s.gleam_kind, GleamRules.CLASSIC)
	assert_eq(GleamRules.kind_of(s), GleamRules.CLASSIC)
	assert_eq(GleamRules.mark(s), GleamRules.STAR + " ", "an old Gleam keeps its star")

func test_unknown_or_stray_kinds_are_cleaned() -> void:
	assert_eq(Spirling.from_dict({"species": "Kindlop", "gleam": true, "gleam_kind": "gilded_ticket"}).gleam_kind, GleamRules.CLASSIC)
	assert_eq(Spirling.from_dict({"species": "Kindlop", "gleam": true, "gleam_kind": 4}).gleam_kind, GleamRules.CLASSIC)
	assert_eq(Spirling.from_dict({"species": "Kindlop", "gleam": false, "gleam_kind": "opaline"}).gleam_kind, "")
	assert_eq(Spirling.from_dict({"species": "Kindlop"}).gleam_kind, "")

func test_every_kind_round_trips_a_save() -> void:
	for id: String in GleamRules.kind_ids():
		var s := Spirling.new(Database.species("Mossling"), 12)
		GleamRules.apply(s, id)
		var back: Spirling = Spirling.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		assert_true(back.gleam, id)
		assert_eq(back.gleam_kind, id)
		assert_false(back.gleam_boost, id + ": a colour form only")

func test_kind_survives_a_whole_save_and_sanitize() -> void:
	var s := Spirling.new(Database.species("Zippit"), 8)
	GleamRules.apply(s, "duskgold")
	GameState.party.append(s)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	d = SaveManager.sanitize(d)
	GameState.from_dict(d)
	var found: Spirling = null
	for p: Spirling in GameState.party:
		if p.uid == s.uid:
			found = p
	assert_not_null(found)
	if found != null:
		assert_eq(found.gleam_kind, "duskgold")

func test_old_save_fixtures_load_without_kinds() -> void:
	for f: String in DirAccess.get_files_at(FIXTURES):
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + f))
		if not raw is Dictionary or not SaveManager.migrate(raw) is Dictionary:
			continue
		SaveManager.apply_save(SaveManager.migrate(raw))
		for s: Spirling in GameState.party + GameState.storage:
			assert_eq(s.gleam_kind, GleamRules.kind_of(s), f)
			assert_eq(GleamRules.kind_of(s) != "", s.gleam, f)

func test_kind_survives_unfurling_and_furling_back() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 30)
	GleamRules.apply(s, "rime")
	s.evolve()
	assert_eq(s.gleam_kind, "rime")
	s.furl_back()
	assert_eq(s.gleam_kind, "rime")

func test_old_spirlog_entries_count_as_classic() -> void:
	var e: Dictionary = GameState.upgrade_spirlog_entry({"seen": true, "gleam_seen": true, "gleam_bonded": true})
	assert_eq(e.gleam_kinds_bonded, [GleamRules.CLASSIC])
	assert_eq(e.gleam_kinds_seen, [GleamRules.CLASSIC])
	var plain: Dictionary = GameState.upgrade_spirlog_entry({"seen": true})
	assert_eq(plain.gleam_kinds_seen, [])
	var junk: Dictionary = GameState.upgrade_spirlog_entry({"gleam_kinds_seen": ["rime", "bogus", "rime", 3], "gleam_kinds_bonded": "x"})
	assert_eq(junk.gleam_kinds_seen, ["rime"])
	assert_eq(junk.gleam_kinds_bonded, [])

func test_spirlog_tracks_kinds_seen_and_bonded() -> void:
	GameState.spirlog = {}
	var a := Spirling.new(Database.species("Zippit"), 5)
	GleamRules.apply(a, "inkwash")
	GameState.note_spirlog(a)
	var b := Spirling.new(Database.species("Zippit"), 5)
	GleamRules.apply(b, "opaline")
	GameState.note_spirlog(b)
	GameState.note_gleam_bonded(b)
	GameState.from_dict(GameState.to_dict())
	var e: Dictionary = SpirlogBook.entry(GameState.spirlog, "Zippit")
	assert_eq(e.gleam_kinds_seen, ["inkwash", "opaline"])
	assert_eq(e.gleam_kinds_bonded, ["opaline"])
	var counts: Array[Dictionary] = SpirlogBook.gleam_kind_counts(GameState.spirlog)
	for row: Dictionary in counts:
		assert_eq(int(row.seen), 1 if row.id in ["inkwash", "opaline"] else 0, str(row.id))
		assert_eq(int(row.bonded), 1 if row.id == "opaline" else 0, str(row.id))
	assert_eq(SpirlogBook.gleam_kind_lines(GameState.spirlog).size(), GleamRules.kind_ids().size())
	assert_string_contains(SpirlogBook.list_line(Database.species("Zippit"), GameState.spirlog), GleamRules.glyph("opaline"))
	var page: String = SpirlogBook.page_text(Database.species("Zippit"), GameState.spirlog)
	assert_string_contains(page, GleamRules.label("inkwash"))
	assert_string_contains(page, "Gleams bonded: " + GleamRules.label("opaline"))

# --- Trades and the server ------------------------------------------------------------------

func test_trade_keeps_the_kind_and_cleans_bad_ones() -> void:
	var m: Dictionary = {"uid": "a", "species": "Kindlop", "gleam": true, "gleam_boost": false, "gleam_kind": "duskgold"}
	assert_eq(LocalBackend.trade_mon_why(m), "", "a wild Gleam of any kind trades")
	assert_eq(Spirling.from_dict(LocalBackend.trade_mon_clean(m)).gleam_kind, "duskgold")
	assert_eq(str(LocalBackend.trade_mon_clean({"uid": "a", "gleam": true, "gleam_kind": "fake"}).gleam_kind), GleamRules.CLASSIC)
	assert_eq(str(LocalBackend.trade_mon_clean({"uid": "a", "gleam": true}).gleam_kind), GleamRules.CLASSIC)
	assert_false(LocalBackend.trade_mon_clean({"uid": "a", "gleam": false, "gleam_kind": "rime"}).has("gleam_kind"))

func test_server_knows_the_same_kinds() -> void:
	var sql: String = FileAccess.get_file_as_string(MIGRATION)
	var re := RegEx.create_from_string("array\\[([^\\]]*)\\]::text\\[\\]")
	var m: RegExMatch = re.search(sql)
	assert_not_null(m, "kind list in the migration")
	if m == null:
		return
	var ids: Array[String] = []
	for part: String in m.get_string(1).split(","):
		ids.append(part.strip_edges().trim_prefix("'").trim_suffix("'"))
	assert_eq(ids, GleamRules.kind_ids())
	assert_true(sql.contains("from public, anon, authenticated"), "no client may call the helpers")

# --- Palettes and looks ---------------------------------------------------------------------

func test_every_species_has_a_palette_of_every_kind() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Database.SPIRLINGS_PATH))
	var pal_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GleamRules.PALETTE_PATH))
	assert_eq((pal_file.kinds as Dictionary).keys().size(), RARE.size())
	for sp: Dictionary in raw:
		var name: String = str(sp.name)
		var classic: Array[Color] = GleamRules.palette(name)
		for id: String in RARE:
			var pal: Array[Color] = GleamRules.palette(name, id)
			assert_eq(pal.size(), 4, "%s %s" % [name, id])
			if pal.size() != 4:
				continue
			var distinct: Dictionary = {}
			for c: Color in pal:
				distinct[c.to_html(false)] = true
			assert_eq(distinct.size(), 4, "%s %s: four tones" % [name, id])
			for i: int in range(1, 4):
				assert_lt(pal[0].get_luminance(), pal[i].get_luminance(), "%s %s: outline darkest" % [name, id])
			assert_ne(pal, classic, "%s %s: not the classic palette" % [name, id])
			assert_ne(pal.slice(1), EraManager.INK_PALETTE.slice(1), "%s %s: not the plain inks" % [name, id])
	for id: String in RARE:
		assert_eq((pal_file.kinds[id] as Dictionary).size(), (raw as Array).size(), id + ": no palette for a removed kind")

func test_materials_per_kind() -> void:
	for name: String in ["Kindlop", "Puddlet", "Mossling", "Zippit"]:
		var classic: ShaderMaterial = GleamRules.material(name)
		assert_eq(GleamRules.material(name, GleamRules.CLASSIC), classic, name + ": the classic look is unchanged")
		for id: String in RARE:
			var mat: ShaderMaterial = GleamRules.material(name, id)
			assert_not_null(mat, "%s %s" % [name, id])
			assert_ne(mat, classic)
			var want_cycle: float = float(GleamRules.kind(id).get("cycle", 0.0))
			assert_almost_eq(float(mat.get_shader_parameter("cycle")), want_cycle, 1e-6, "%s %s cycle" % [name, id])
	assert_gt(float(GleamRules.kind("opaline").get("cycle", 0.0)), 0.0, "the prismatic kind shimmers")

func test_opaline_stands_still_under_reduced_motion() -> void:
	var was: bool = GameState.reduce_motion
	GameState.reduce_motion = true
	for name: String in ["Kindlop", "Zippit"]:
		var still: ShaderMaterial = GleamRules.material(name, "opaline")
		assert_eq(float(still.get_shader_parameter("cycle")), 0.0, name + ": no hue cycle")
		assert_almost_eq(float(still.get_shader_parameter("phase")), float(GleamRules.kind("opaline").still_phase), 1e-6, name + ": fixed mid phase")
		assert_almost_eq(float(GleamRules.kind("opaline").still_phase), 0.5, 1e-6)
		# Kinds that never cycle look the same either way.
		assert_eq(float(GleamRules.material(name, "rime").get_shader_parameter("phase")), 0.0)
	GameState.reduce_motion = false
	var moving: ShaderMaterial = GleamRules.material("Kindlop", "opaline")
	assert_gt(float(moving.get_shader_parameter("cycle")), 0.0, "cycles again with motion on")
	assert_eq(float(moving.get_shader_parameter("phase")), 0.0)
	GameState.reduce_motion = was

## The classic material keeps its old shader settings (same look as before the kinds); the
## rarer kinds draw their own colours, not tinted by the old ink (true_colours).
func test_rarer_kinds_draw_true_colours_and_classic_is_unchanged() -> void:
	for name: String in ["Kindlop", "Blotkin"]:
		var classic: ShaderMaterial = GleamRules.material(name)
		assert_ne(classic.get_shader_parameter("true_colours"), true, name + ": classic as before")
		assert_null(classic.get_shader_parameter("phase"), name + ": classic sets no new parameter")
		for id: String in RARE:
			assert_eq(GleamRules.material(name, id).get_shader_parameter("true_colours"), true, "%s %s" % [name, id])
	var tier: ShaderMaterial = GleamRules.material("Blotkin", "inkwash")
	assert_eq(tier.shader.resource_path, SpriteTiers.HUE_SHADER_PATH, "Era III art takes the ramp path")
	assert_gt(float(tier.get_shader_parameter("ramp_mix")), 0.5)
	assert_lt(float(tier.get_shader_parameter("accent_from")), 1.0, "Inkwash keeps one bright accent")

func test_each_kind_has_its_own_hue_family() -> void:
	# Mid tone (ink 2) of every species: Rime cyan, Inkwash bright accent, Duskgold orange,
	# Opaline a light pastel; ink 1 of Inkwash stays near black.
	for sd: SpirlingData in Database.spirlings.values():
		var n: String = sd.species_name
		var rime: Array[Color] = GleamRules.palette(n, "rime")
		assert_gt(rime[3].get_luminance(), 0.85, n + ": Rime light is near white")
		assert_true(rime[2].b > rime[2].r, n + ": Rime is blue")
		var ink: Array[Color] = GleamRules.palette(n, "inkwash")
		assert_lt(ink[1].get_luminance(), 0.1, n + ": Inkwash shadow is ink-black")
		assert_lt(ink[3].get_luminance(), 0.2, n + ": Inkwash light stays dark")
		assert_gt(ink[2].get_luminance(), 0.5, n + ": one bright accent")
		var gold: Array[Color] = GleamRules.palette(n, "duskgold")
		assert_true(gold[2].r > gold[2].b and gold[3].r > gold[3].b, n + ": Duskgold is warm")
		var opal: Array[Color] = GleamRules.palette(n, "opaline")
		assert_gt(opal[1].get_luminance(), 0.55, n + ": Opaline is pastel")

func test_sparkle_settings_per_kind() -> void:
	var base: Dictionary = GleamRules.sparkle(GleamRules.CLASSIC)
	assert_eq(int(base.sparkles), int(GleamRules.config().sparkles), "classic sparkle unchanged")
	assert_false(base.has("sparkle_color"))
	for id: String in RARE:
		var sp: Dictionary = GleamRules.sparkle(id)
		assert_gt(int(sp.sparkles), 0, id)
		assert_gt(float(sp.sparkle_time), 0.0, id)
		assert_true(sp.has("sparkle_color"), id)
		assert_true(FileAccess.file_exists(Sound.SFX_DIR % str(sp.sfx)), id + " sound")

# --- Display --------------------------------------------------------------------------------

func test_each_kind_has_its_own_glyph_colour_and_name() -> void:
	var glyphs: Dictionary = {}
	for id: String in GleamRules.kind_ids():
		var g: String = GleamRules.glyph(id)
		assert_true(PixelFont.GLYPHS.has(g), id + ": glyph is in the pixel font")
		glyphs[g] = true
		assert_false(GleamRules.kind_name(id).is_empty())
		assert_gte(UITheme.contrast(GleamRules.text_color(id, UITheme.BG), UITheme.BG), GleamRules.TEXT_CONTRAST - 0.01, id + ": label reads")
	assert_eq(glyphs.size(), GleamRules.kind_ids().size(), "one glyph per kind")
	assert_eq(GleamRules.glyph(GleamRules.CLASSIC), GleamRules.STAR)

func test_party_storage_and_trade_show_the_kind() -> void:
	var s := Spirling.new(Database.species("Puddlet"), 9)
	GleamRules.apply(s, "rime")
	assert_true(MenuHost.party_line(s).begins_with(GleamRules.glyph("rime") + " "))
	assert_string_contains(MenuHost.storage_line(s), GleamRules.glyph("rime"))
	assert_string_contains(TradeMenu.mons_text([s.to_dict()]), GleamRules.label("rime"))
	assert_string_contains(EraMenus.summary_section(s, "info"), GleamRules.label("rime"))
	assert_string_contains(MenuHost.summary_pages(s)[0], GleamRules.label("rime"))
	var plain := Spirling.new(Database.species("Puddlet"), 9)
	assert_false(TradeMenu.mons_text([plain.to_dict()]).contains(GleamRules.STAR))

func test_summary_card_shows_the_kind_in_its_colour() -> void:
	var s := Spirling.new(Database.species("Mossling"), 14)
	GleamRules.apply(s, "duskgold")
	var view := EraSummary.new()
	view.spirling = s
	view.lay = EraMenus.layout(3, "summary")
	add_child_autofree(view)
	view.build()
	var lbl: Label = view.find_child("gleam_kind", true, false) as Label
	assert_not_null(lbl)
	if lbl != null:
		assert_eq(lbl.text, GleamRules.label("duskgold"))
		assert_eq(lbl.get_theme_color("font_color"), GleamRules.text_color("duskgold", UITheme.BG))

func test_battle_plate_glint_takes_the_kind_colour() -> void:
	var s := Spirling.new(Database.species("Zippit"), 10)
	var strip := InfoStrip.new()
	GleamRules.apply(s, "inkwash")
	strip.set_spirling(s)
	assert_true(strip.spark)
	assert_eq(strip.spark_tint, GleamRules.color("inkwash"))
	GleamRules.apply(s, GleamRules.CLASSIC)
	strip.set_spirling(s)
	assert_null(strip.spark_tint, "classic glint unchanged")
	strip.free()

func test_battle_sprite_uses_the_kind_material() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 10)
	GleamRules.apply(s, "opaline")
	var sprite := SpirlingSprite.new()
	add_child_autofree(sprite)
	sprite.setup(s, "front")
	assert_eq(sprite.material, GleamRules.material("Kindlop", "opaline"))

func test_battle_opening_names_the_kind() -> void:
	for id: String in RARE:
		var e := BattleEvent.new(BattleEvent.Type.BATTLE_START, {"wild": true, "foe_name": "Kindlop", "gleam": true, "gleam_kind": id})
		assert_string_contains(e.describe(), GleamRules.kind_name(id))
	var classic := BattleEvent.new(BattleEvent.Type.BATTLE_START, {"wild": true, "foe_name": "Kindlop", "gleam": true})
	assert_string_contains(classic.describe(), "It gleams in colours of its own!")

func test_kind_texts_are_translated() -> void:
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/gleam_kinds.json")).strings
	for k: Dictionary in GleamRules.kinds():
		if str(k.id) == GleamRules.CLASSIC:
			continue
		assert_true(de.has(str(k.name)), str(k.name))
		assert_true(de.has(str(k.line)), str(k.line))
	for lang: String in ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]:
		var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/%s/gleam_kinds.json" % lang)).strings
		assert_eq(t.keys().size(), de.keys().size(), lang)
