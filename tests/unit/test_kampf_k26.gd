extends GutTest
## KAMPF_PLAN_1000 items 107 (matchup notes by Lantern Mail), 108 (bigger element symbols in high
## contrast), 111 (one theme element per Rift Warden), 113 (element symbols hop on a very effective
## hit) and 117 (element seals under landmarks).

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	UITheme.high_contrast = false

# --- 107 ---------------------------------------------------------------------------------------

func _backend() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})

func _as(who: String, fn: String, args: Dictionary = {}) -> Variant:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func test_notes_pick_teaches_strong_and_weak_first() -> void:
	var known: Dictionary = {"0:Mossling": 2.0, "1:Kindlop": 1.0, "4:Zippit": 0.5, "x:Bad": 2.0, "2:Puddlet": 9.0}
	var notes: Dictionary = MatchupNotes.pick(known, 2)
	assert_eq(notes, {"0:Mossling": 2.0, "4:Zippit": 0.5}, "neutral matchups come last, broken notes never")
	assert_eq(MatchupNotes.pick(known, 10).size(), 3)
	assert_true(MatchupNotes.pick({}, 10).is_empty())

func test_notes_learn_keeps_own_knowledge() -> void:
	var mine: Dictionary = {"0:Mossling": 2.0}
	var n: int = MatchupNotes.learn(mine, {"0:Mossling": 0.5, "1:Kindlop": 2.0, "99:Ghost": 2.0, "2:Puddlet": 0.0})
	assert_eq(n, 1, "only the new, valid note counts")
	assert_eq(mine, {"0:Mossling": 2.0, "1:Kindlop": 2.0}, "a matchup seen with own eyes is never overwritten")

func test_notes_by_lantern_mail_on_the_local_server() -> void:
	_backend()
	var notes: Dictionary = {"0:Mossling": 2.0, "1:Kindlop": 2.0, "4:Zippit": 0.5}
	assert_eq(_as("ann", "notes_send", {"p_code": codes.cid, "p_notes": notes}).error, "not_friends")
	assert_eq(_as("ann", "notes_send", {"p_code": codes.ben, "p_notes": {}}).error, "bad_notes")
	assert_eq(_as("ann", "notes_send", {"p_code": codes.ben, "p_notes": {"0:Mossling": 9.0}}).error, "bad_notes")
	var too_many: Dictionary = {}
	for i: int in MatchupNotes.cfg("max_notes") + 1:
		too_many["0:Kind%d" % i] = 2.0
	assert_eq(_as("ann", "notes_send", {"p_code": codes.ben, "p_notes": too_many}).error, "bad_notes")
	assert_true(bool(_as("ann", "notes_send", {"p_code": codes.ben, "p_notes": notes}).ok))
	assert_eq(_as("ann", "notes_send", {"p_code": codes.ben, "p_notes": notes}).error, "already_today")
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	assert_gte(int(f.points), MatchupNotes.cfg("points"), "the Lantern Mail bonus")
	var mail: Array = _as("ben", "mail_list")
	var notes_mail: Array = mail.filter(func(m: Dictionary) -> bool: return str(m.kind) == "notes")
	assert_eq(notes_mail.size(), 1)
	assert_eq(FriendsMenu.mail_line(notes_mail[0]).begins_with("! "), true, "unread")
	assert_eq(_as("cid", "notes_open", {"p_id": notes_mail[0].id}).error, "no_such_mail", "only the recipient")
	var opened: Dictionary = _as("ben", "notes_open", {"p_id": notes_mail[0].id})
	assert_eq(opened.notes, notes)

# --- 108 ---------------------------------------------------------------------------------------

func test_high_contrast_draws_bigger_symbols() -> void:
	UITheme.high_contrast = false
	assert_eq(ElementIcons.size(), ElementIcons.SIZE)
	assert_eq(EraMenuArt.badge_h(), EraMenuArt.BADGE_H)
	var small: float = EraMenuArt.badge_width("colour")
	UITheme.high_contrast = true
	assert_eq(ElementIcons.size(), ElementIcons.SIZE * ElementIcons.HC_SCALE)
	assert_gt(EraMenuArt.badge_width("colour"), small)
	assert_gt(EraMenuArt.badge_h(), EraMenuArt.BADGE_H)
	assert_lte(EraMenuArt.badge_h(), ListPicker.ROW_HEIGHT, "still fits a menu row")
	var tex: ImageTexture = ElementIcons.texture(Elements.E.EMBER, UITheme.INK, ElementIcons.scale())
	assert_eq(tex.get_size(), Vector2(14, 14))
	# Every pixel is doubled, so the symbol keeps its shape.
	var img: Image = tex.get_image()
	var base: Image = ElementIcons.texture(Elements.E.EMBER, UITheme.INK).get_image()
	for y: int in ElementIcons.SIZE:
		for x: int in ElementIcons.SIZE:
			assert_eq(img.get_pixel(x * 2 + 1, y * 2 + 1).a, base.get_pixel(x, y).a)

# --- 113 ---------------------------------------------------------------------------------------

func test_glyphs_hop_on_a_very_effective_hit() -> void:
	assert_true(InfoStrip.glyph_kicked(Elements.E.TIDE, Elements.E.EMBER), "Tide hits Ember hard")
	assert_false(InfoStrip.glyph_kicked(Elements.E.EMBER, Elements.E.TIDE))
	assert_false(InfoStrip.glyph_kicked(-1, Elements.E.EMBER), "no art, no hop")
	assert_eq(InfoStrip.glyph_hop(0.75, false), -InfoStrip.GLYPH_HOP_PX, "top of a hop")
	assert_eq(InfoStrip.glyph_hop(0.5, false), 0, "back on the line between the hops")
	assert_eq(InfoStrip.glyph_hop(1.0, false), 0)
	assert_eq(InfoStrip.glyph_hop(0.0, false), 0)
	assert_eq(InfoStrip.glyph_hop(0.75, true), 0, "reduced motion: no hop")
	for i: int in 21:
		var y: int = InfoStrip.glyph_hop(i / 20.0, false)
		assert_true(y <= 0 and y >= -InfoStrip.GLYPH_HOP_PX)

# --- 111 ---------------------------------------------------------------------------------------

func _wardens() -> Dictionary:
	var out: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with("_rift.json"):
			continue
		var m: MapData = MapData.load_map(f.get_basename())
		if m == null:
			continue
		for n: Dictionary in m.npcs:
			if n.has("warden") and n.get("team") is Array:
				out[str(n.warden)] = n
	return out

func test_every_rift_warden_has_a_theme_from_its_team() -> void:
	var wardens: Dictionary = _wardens()
	assert_gte(wardens.size(), 24)
	for w: String in wardens:
		var th: int = WardenCard.theme(wardens[w])
		assert_true(th >= 0, "Warden %s has a theme element" % w)
		var count: Dictionary = {}
		for t: Variant in wardens[w].team:
			for e: int in Database.species(str(t.species)).elements:
				count[e] = int(count.get(e, 0)) + 1
		var top: int = 0
		for e: Variant in count:
			top = maxi(top, int(count[e]))
		assert_eq(int(count.get(th, 0)), top, "%s: %s is one of the team's most common elements" % [w, Elements.element_name(th)])
	for key: Variant in WardenCard.themes():
		assert_true(wardens.has(key), "no theme without a Warden: %s" % key)

func test_warden_card_names_the_theme() -> void:
	var def: Dictionary = {"trainer": "Warden Orrin", "warden": "cinder"}
	var team: Array[Spirling] = []
	assert_true(WardenCard.text(def, team, 1).contains("Rift theme: Ember"))
	assert_false(WardenCard.text({"trainer": "Someone"}, team, 1).contains("Rift theme"))

# --- 117 ---------------------------------------------------------------------------------------

func test_every_seal_sits_on_a_landmark_and_can_be_broken() -> void:
	assert_gte(ElementSeals.all().size(), 6)
	for map_id: Variant in ElementSeals.all():
		var seal: Dictionary = ElementSeals.seal_for(str(map_id))
		assert_false(Landmarks.for_map(str(map_id)).is_empty(), "%s has a landmark" % map_id)
		assert_false(ElementSeals.elements(seal).is_empty())
		assert_false(Database.item(str(seal.item)).is_empty(), "reward %s exists" % seal.item)
		var right: int = 0
		for e: int in ElementSeals.CHOICES:
			if ElementSeals.breaks(seal, e):
				right += 1
		assert_between(right, 1, ElementSeals.CHOICES - 1, "%s: some answers break it, some do not" % map_id)

func test_a_seal_breaks_once_for_the_right_element() -> void:
	var flag: String = ElementSeals.flag("stillwater")
	var had: bool = GameState.has_flag(flag)
	var before: int = GameState.item_count("power_brew")
	GameState.set_flag(flag, false)
	assert_false(bool(ElementSeals.answer("stillwater", Elements.E.VOLT).ok), "Volt into Tide + Stone is only x1")
	assert_false(GameState.has_flag(flag), "a wrong answer costs nothing")
	assert_true(bool(ElementSeals.answer("stillwater", Elements.E.BLOOM).ok), "Bloom into Tide + Stone is x4")
	assert_true(GameState.has_flag(flag))
	assert_eq(GameState.item_count("power_brew"), before + 1)
	assert_false(bool(ElementSeals.answer("stillwater", Elements.E.BLOOM).ok), "once only")
	assert_eq(GameState.item_count("power_brew"), before + 1)
	assert_eq(ElementSeals.seal_name(ElementSeals.seal_for("stillwater")), "Tide + Stone")
	GameState.take_item("power_brew")
	GameState.set_flag(flag, had)
