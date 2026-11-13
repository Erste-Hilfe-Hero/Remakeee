extends GutTest
## Sprite tiers (data/sprite_tiers.json, tools/art/gen_tiers.py, docs/ERA_SPRITE_TIERS.md): every
## Spirling kind that a wild table, a region sheet or a Tamer team names has, in the look of its
## origin era, a front sprite, a back sprite, the menu icons and a pose sheet. Numbers per era:
## python3 tools/art/tier_coverage.py.

const SAMPLE_PER_TIER: int = 6

var _keep: Array = []
var _settings: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func _collect(node: Variant, into: Dictionary) -> void:
	if node is Dictionary:
		for key: Variant in node:
			var v: Variant = node[key]
			if (key == "species" or key == "stand_in") and v is String and v != "":
				into[v] = true
			_collect(v, into)
	elif node is Array:
		for v: Variant in node:
			_collect(v, into)

## Kinds named by a wild table, region sheet or Tamer team anywhere in data/.
func _used() -> Array:
	var out: Dictionary = {}
	for dir: String in ["res://data/", "res://data/maps/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir + f)), out)
	var names: Array = out.keys()
	names.sort()
	return names

func _image(path: String) -> Image:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _colours(img: Image) -> Dictionary:
	var out: Dictionary = {}
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0:
				out[c.to_html(false)] = true
	return out

## What [param kind] lacks of front, back, icon strip and pose sheet ("" when complete).
func _lacks(kind: String) -> String:
	var out: PackedStringArray = []
	var front: String = EraManager.sprite_path(kind, "front")
	if front.is_empty():
		return "front"
	if EraManager.sprite_path(kind, "back").is_empty():
		out.append("back")
	var era: int = SpriteTiers.tier_of_path(front)
	var canvas: int = int(SpriteTiers.tier(era).get("canvas", 0))
	var icons: String = SpriteTiers.icon_path(front)
	if icons.is_empty():
		out.append("icon")
	else:
		var sizes: Array = SpriteTiers.icon_sizes()
		var tex: Texture2D = load(icons)
		if tex.get_width() != sizes.reduce(func(a: int, b: Variant) -> int: return a + int(b), 0) or tex.get_height() != int(sizes.max()):
			out.append("icon size")
	var sheet: String = SpriteTiers.sheet_path(front)
	if sheet.is_empty():
		out.append("anim")
	else:
		var st: Texture2D = load(sheet)
		var poses: int = (SpriteTiers.tier(era).get("poses", []) as Array).size()
		if st.get_width() != canvas * poses or st.get_height() != canvas * 2:
			out.append("anim size")
	return ", ".join(out)

## Up to SAMPLE_PER_TIER known kinds per tier, spread over the dex.
func _samples() -> Dictionary:
	var by: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		var t: int = SpriteTiers.tier_of_path(EraManager.sprite_path(sd.species_name))
		if t > 0:
			if not by.has(t):
				by[t] = []
			(by[t] as Array).append(sd.species_name)
	for t: Variant in by:
		var all: Array = by[t]
		all.sort()
		var step: int = maxi(all.size() / SAMPLE_PER_TIER, 1)
		var pick: Array = []
		for i: int in range(0, all.size(), step):
			if pick.size() < SAMPLE_PER_TIER:
				pick.append(all[i])
		by[t] = pick
	return by

func test_five_tiers_follow_the_era_canvas() -> void:
	for e: int in range(1, EraManager.NEWEST + 1):
		var t: Dictionary = SpriteTiers.tier(e)
		assert_false(t.is_empty(), "tier %d" % e)
		assert_eq(int(t.canvas), EraManager.BATTLE_SPRITE_SIZE[e], "tier %d canvas is the era's battle sprite size" % e)
		assert_eq(str((t.poses as Array)[0].name), "rest", "tier %d: pose 0 is the base sprite" % e)
		for k: Variant in SpriteTiers.kinds():
			assert_true((t.anim as Dictionary).has(k), "tier %d has %s" % [e, k])

func test_each_tier_moves_at_least_as_much_as_the_one_before() -> void:
	for e: int in range(2, EraManager.NEWEST + 1):
		assert_gte((SpriteTiers.tier(e).poses as Array).size(), (SpriteTiers.tier(e - 1).poses as Array).size(), "poses, tier %d" % e)
		assert_gte(int(SpriteTiers.tier(e).canvas), int(SpriteTiers.tier(e - 1).canvas), "canvas, tier %d" % e)
		assert_gte(int(SpriteTiers.tier(e).max_colours), int(SpriteTiers.tier(e - 1).max_colours), "colours, tier %d" % e)
		for k: Variant in SpriteTiers.kinds():
			assert_gte(SpriteTiers.frame_count(e, k), SpriteTiers.frame_count(e - 1, k), "%s frames, tier %d" % [k, e])

func test_owner_rules_per_tier() -> void:
	assert_eq(int(SpriteTiers.tier(1).max_colours), 4, "Era I: four inks")
	assert_eq((SpriteTiers.tier(1).poses as Array).size(), 2, "Era I: a two-frame hop")
	assert_eq(SpriteTiers.frame_count(1, "idle"), 2)
	assert_gte(SpriteTiers.pose_index(4, "breath"), 0, "Era IV: idle and breath")
	assert_gte(SpriteTiers.frame_count(5, "idle"), 4, "Era V: idle loop of four frames or more")
	assert_true(SpriteTiers.animates(5))
	assert_false(SpriteTiers.animates(4))

func test_timelines_are_sound() -> void:
	for e: int in range(1, EraManager.NEWEST + 1):
		var poses: int = (SpriteTiers.tier(e).poses as Array).size()
		for k: Variant in SpriteTiers.kinds():
			var tl: Dictionary = SpriteTiers.timeline(e, k)
			var n: int = SpriteTiers.frame_count(e, k)
			assert_gt(float(tl.fps), 0.0)
			for f: int in n:
				var c: int = SpriteTiers.cell(e, k, f)
				assert_true(c < poses and c >= SpriteTiers.FLASH, "tier %d %s frame %d" % [e, k, f])
			for key: String in ["dx", "dy"]:
				if tl.has(key):
					assert_eq((tl[key] as Array).size(), n, "tier %d %s %s" % [e, k, key])
			# A one-shot strip ends on the rest pose at home, so the idle loop takes over cleanly.
			assert_eq(SpriteTiers.cell(e, k, n - 1 if k != "idle" else 0), 0, "tier %d %s rests" % [e, k])
			if k != "idle":
				assert_lt(absf(SpriteTiers.offset(e, k, n - 1).x), 2.0, "tier %d %s ends near home" % [e, k])
		assert_true(bool(SpriteTiers.timeline(e, "idle").loop))
		assert_eq(SpriteTiers.frame_at(e, "idle", SpriteTiers.duration(e, "idle")), 0, "idle loops")
		assert_eq(SpriteTiers.frame_at(e, "attack", 99.0), SpriteTiers.frame_count(e, "attack") - 1, "attack holds")

func test_paths() -> void:
	var p: String = "res://art/era3/spirlings/blotgrimm_back.png"
	assert_eq(SpriteTiers.tier_of_path(p), 3)
	assert_eq(SpriteTiers.id_of_path(p), "blotgrimm")
	assert_eq(SpriteTiers.tier_of_path("res://icon.png"), 0)
	assert_eq(SpriteTiers.sheet_path("res://icon.png"), "")
	assert_eq(SpriteTiers.forward("front"), -1.0)
	assert_eq(SpriteTiers.forward("back"), 1.0)

func test_every_kind_in_a_table_or_team_has_all_tier_sprites() -> void:
	var used: Array = _used()
	assert_gt(used.size(), 300, "the walk finds the kinds of the wild tables and teams")
	var bad: PackedStringArray = []
	for kind: Variant in used:
		if Database.species(str(kind)) == null:
			continue
		var lacks: String = _lacks(str(kind))
		if lacks != "":
			bad.append("%s: no %s" % [kind, lacks])
	assert_eq(bad.size(), 0, "run python3 tools/art/gen_tiers.py; kinds without tier sprites:\n" + "\n".join(bad))

func test_every_kind_in_the_data_has_all_tier_sprites() -> void:
	var bad: PackedStringArray = []
	for sd: SpirlingData in Database.spirlings.values():
		var lacks: String = _lacks(sd.species_name)
		if lacks != "":
			bad.append("%s: no %s" % [sd.species_name, lacks])
	assert_eq(bad.size(), 0, "run python3 tools/art/gen_tiers.py; kinds without tier sprites:\n" + "\n".join(bad))

func test_art_stays_in_its_origin_era() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var t: int = SpriteTiers.tier_of_path(EraManager.sprite_path(sd.species_name))
		if t != sd.era:
			assert_eq(t, sd.era, "%s is drawn in its origin era" % sd.species_name)
			return
	pass_test("every kind is drawn in its origin era")

func test_derived_frames_only_use_the_colours_of_their_base() -> void:
	var samples: Dictionary = _samples()
	assert_gte(samples.size(), 2, "at least two origin eras have art")
	for t: Variant in samples:
		for kind: Variant in samples[t]:
			var front: String = EraManager.sprite_path(str(kind), "front")
			var base: Dictionary = _colours(_image(front))
			base.merge(_colours(_image(EraManager.sprite_path(str(kind), "back"))))
			assert_lte(base.size(), int(SpriteTiers.tier(int(t)).max_colours), "%s keeps the tier's colour count" % kind)
			for path: String in [SpriteTiers.sheet_path(front), SpriteTiers.icon_path(front)]:
				var extra: Array = _colours(_image(path)).keys().filter(func(c: Variant) -> bool: return not base.has(c))
				assert_eq(extra.size(), 0, "%s: %s has colours its sprite lacks" % [kind, path.get_file()])

func test_rest_pose_is_the_base_sprite() -> void:
	var samples: Dictionary = _samples()
	for t: Variant in samples:
		var kind: String = str((samples[t] as Array)[0])
		for row: int in SpriteTiers.FACINGS.size():
			var path: String = EraManager.sprite_path(kind, SpriteTiers.FACINGS[row])
			var base: Image = _image(path)
			var sheet: Image = _image(SpriteTiers.sheet_path(path))
			var s: int = base.get_width()
			var cell: Image = sheet.get_region(Rect2i(0, row * s, s, s))
			var diff: int = 0
			for y: int in s:
				for x: int in s:
					var a: Color = base.get_pixel(x, y)
					var b: Color = cell.get_pixel(x, y)
					if a.a != b.a or (a.a > 0.0 and not a.is_equal_approx(b)):
						diff += 1
			assert_eq(diff, 0, "%s %s" % [kind, SpriteTiers.FACINGS[row]])

func test_poses_differ_from_rest() -> void:
	var samples: Dictionary = _samples()
	for t: Variant in samples:
		var kind: String = str((samples[t] as Array)[0])
		var path: String = EraManager.sprite_path(kind, "front")
		var sheet: Image = _image(SpriteTiers.sheet_path(path))
		var s: int = sheet.get_height() / 2
		for pose: int in range(1, (SpriteTiers.tier(int(t)).poses as Array).size()):
			var same: bool = true
			for y: int in s:
				for x: int in s:
					if sheet.get_pixel(x, y) != sheet.get_pixel(pose * s + x, y):
						same = false
			assert_false(same, "%s pose %d moves" % [kind, pose])

func test_stages_of_a_line_share_their_colours() -> void:
	var lines: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.era >= 2 and not sd.line_id.is_empty():
			if not lines.has(sd.line_id):
				lines[sd.line_id] = []
			(lines[sd.line_id] as Array).append(sd.species_name)
	var checked: int = 0
	for line: Variant in lines:
		var kinds: Array = lines[line]
		if kinds.size() < 2 or checked >= 12:
			continue
		checked += 1
		var a: Dictionary = _colours(_image(SpriteTiers.icon_path(EraManager.sprite_path(str(kinds[0])))))
		var b: Dictionary = _colours(_image(SpriteTiers.icon_path(EraManager.sprite_path(str(kinds[1])))))
		var shared: int = a.keys().filter(func(c: Variant) -> bool: return b.has(c)).size()
		assert_gte(shared * 2, maxi(a.size(), b.size()), "line %s: icons share at least half their colours" % line)
	assert_gt(checked, 0)

func test_menu_icons_come_from_the_icon_strip() -> void:
	var samples: Dictionary = _samples()
	for t: Variant in samples:
		var kind: String = str((samples[t] as Array)[0])
		for size: Variant in SpriteTiers.icon_sizes():
			var tex: Texture2D = MiniSprite.of(kind, int(size))
			assert_true(tex is AtlasTexture, "%s %d px is a generated icon" % [kind, int(size)])
			assert_eq(tex.get_size(), Vector2(int(size), int(size)))
			assert_gt(_colours(tex.get_image()).size(), 1, "%s %d px is drawn" % [kind, int(size)])
		assert_eq(MiniSprite.of(kind, 48).get_size(), Vector2(48, 48), "other sizes still scale the battle sprite")

func _sprite(kind: String, facing: String) -> SpirlingSprite:
	var sp := SpirlingSprite.new()
	sp.size = Vector2(96, 96)
	add_child_autofree(sp)
	sp.setup(Spirling.new(Database.species(kind), 10), facing)
	return sp

func test_era_five_plays_each_kind_in_its_own_tier() -> void:
	_era(5)
	var samples: Dictionary = _samples()
	for t: Variant in samples:
		var sp: SpirlingSprite = _sprite(str((samples[t] as Array)[0]), "front")
		assert_eq(sp._tier, int(t), "origin era %d plays tier %d" % [int(t), int(t)])
		assert_eq(sp._strips.size(), SpriteTiers.kinds().size())
		sp._anim_time = SpriteTiers.duration(int(t), "idle") * 0.99
		assert_eq(sp._frame(), SpriteTiers.frame_count(int(t), "idle") - 1)

func test_older_eras_do_not_play_the_sheets() -> void:
	var samples: Dictionary = _samples()
	for e: int in [1, 2, 3, 4]:
		_era(e)
		for t: Variant in samples:
			assert_eq(_sprite(str((samples[t] as Array)[0]), "front")._tier, 0, "era %d" % e)

func test_reduced_motion_keeps_the_rest_pose() -> void:
	_era(5)
	GameState.reduce_motion = true
	var samples: Dictionary = _samples()
	var sp: SpirlingSprite = _sprite(str((samples[samples.keys()[0]] as Array)[0]), "front")
	sp.anim_kind = "hit"
	sp._process(1.0)
	assert_eq(sp._anim_time, 0.0, "the strip clock stands still")
	assert_true(Juice.reduced())

func test_forward_follows_facing_and_mirror() -> void:
	_era(5)
	var samples: Dictionary = _samples()
	var kind: String = str((samples[samples.keys()[0]] as Array)[0])
	var foe: SpirlingSprite = _sprite(kind, "front")
	foe.mirrored = true
	var own: SpirlingSprite = _sprite(kind, "back")
	own.mirrored = true
	assert_eq(foe.facing_sign(), 1.0, "the foe (upper left) strikes to the right")
	assert_eq(own.facing_sign(), -1.0, "the player's Spirling (lower right) strikes to the left")

func test_gleam_recolours_every_tier() -> void:
	var samples: Dictionary = _samples()
	for t: Variant in samples:
		var kind: String = str((samples[t] as Array)[0])
		var mat: ShaderMaterial = GleamRules.material(kind)
		assert_not_null(mat, kind)
		if int(t) == 1:
			assert_eq(mat.shader.resource_path, "res://shaders/gleam_palette.gdshader", "%s: ink palette swap" % kind)
		else:
			assert_eq(mat.shader.resource_path, SpriteTiers.HUE_SHADER_PATH, "%s: hue turn" % kind)
			var shift: float = float(mat.get_shader_parameter("shift"))
			assert_between(shift, 0.25, 0.75, "%s: a clear hue change" % kind)

func test_stages_of_a_line_gleam_alike() -> void:
	var lines: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if SpriteTiers.tier_of_path(EraManager.sprite_path(sd.species_name)) > 1 and not sd.line_id.is_empty():
			if not lines.has(sd.line_id):
				lines[sd.line_id] = []
			(lines[sd.line_id] as Array).append(sd.species_name)
	var checked: int = 0
	for line: Variant in lines:
		var kinds: Array = lines[line]
		if kinds.size() < 2:
			continue
		checked += 1
		var a: ShaderMaterial = GleamRules.material(str(kinds[0]))
		var b: ShaderMaterial = GleamRules.material(str(kinds[1]))
		if a == null or b == null:
			continue
		assert_eq(float(a.get_shader_parameter("shift")), float(b.get_shader_parameter("shift")), "line %s gleams alike" % line)
	assert_gt(checked, 0, "lines of tier II and up exist")
