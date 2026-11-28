extends GutTest
## Bond unfurling (1.3.2, TradeBond): chosen lines unfurl when they bond with a new Wayfarer, in a
## finished trade (server data, here the LocalBackend stand-in) or in a town Wayfarer's one-time
## trade. The same cases as tools/online/sql_test/test_trade_bond.sql.

const MIGRATION: String = "res://supabase/migrations/20261128060000_trade_bond.sql"
## The chosen steps: form -> [next form, Keepsake it must hold during the trade or ""].
const LINES: Dictionary = {
	"Paddlewisp": ["Ferrowyn", ""], "Talusgard": ["Cairnhold", ""], "Vanecrow": ["Vanecrest", "swift_feather"],
	"Morelamp": ["Morelord", ""], "Quenchcoil": ["Quenchwyrm", "keen_lens"], "Carabun": ["Caravant", ""],
	"Quilmothra": ["Quilmothane", ""], "Brassjack": ["Brassgrand", "spark_coil"], "Guisvix": ["Guisdame", ""],
	"Snagwhisk": ["Snaggrave", "iron_burr"], "Lumothra": ["Lumothane", ""],
}
const TOWNS: Array[String] = ["brindlewick", "corvane_quay", "cinderfold", "hookwick"]

var s: LocalBackend
var codes: Dictionary = {}
var tid: int = 0

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	for who: String in ["ann", "ben"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	for f: String in ["trade", "trade_spirling"]:
		s.db.flags[f] = {"enabled": true, "min_version": 1}
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _set_save(who: String, party: Array, storage: Array) -> void:
	s.switch_user(who)
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}, "party": party, "storage": storage}}

func _mon(species: String, uid: String, held: String = "") -> Dictionary:
	var sp := Spirling.new(Database.species(species), 30)
	sp.uid = uid
	sp.held = held
	return sp.to_dict()

func _find(list: Array, uid: String) -> Dictionary:
	for m: Dictionary in list:
		if str(m.uid) == uid:
			return m
	return {}

## A trade where ann gives [param mons] and ben gives one Kindlop; returns what ben collected.
func _trade(mons: Array) -> Dictionary:
	var uids: Array = mons.map(func(m: Dictionary) -> String: return str(m.uid))
	_set_save("ann", [_mon("Kindlop", "a0")], mons)
	_set_save("ben", [_mon("Zippit", "b0")], [_mon("Kindlop", "b1")])
	tid = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)
	assert_true(bool(_as("ann", "trade_put_spirlings", {"p_trade": tid, "p_slot": 1, "p_rev": 1, "p_uids": uids}).ok))
	assert_true(bool(_as("ben", "trade_put_spirlings", {"p_trade": tid, "p_slot": 1, "p_rev": 1, "p_uids": ["b1"]}).ok))
	_as("ann", "trade_confirm", {"p_trade": tid, "p_theirs": {}, "p_their_mons": ["b1"]})
	assert_true(bool(_as("ben", "trade_confirm", {"p_trade": tid, "p_theirs": {}, "p_their_mons": uids}).done))
	return _as("ben", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2})

func test_the_chosen_lines_have_a_bond_path_and_keep_their_ring_path() -> void:
	assert_eq(LINES.size(), 11)
	var items: int = 0
	for from: String in LINES:
		var sd: SpirlingData = Database.species(from)
		var p: Dictionary = TradeBond.path_of(sd)
		assert_false(p.is_empty(), from)
		assert_eq((p.to as SpirlingData).species_name, str(LINES[from][0]), from)
		assert_eq(TradeBond.key_item(sd), str(LINES[from][1]), from)
		assert_eq(str(sd.unfold[0].rule), "ring", "%s keeps its Ring path first, nobody is locked out" % from)
		items += 1 if not str(LINES[from][1]).is_empty() else 0
	assert_between(items, 3, 4, "3-4 lines need a Keepsake")
	var bond_kinds: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		bond_kinds += 0 if TradeBond.path_of(sd).is_empty() else 1
	assert_eq(bond_kinds, LINES.size(), "no other kind has a bond path")

func test_the_lines_are_spread_and_never_legends_or_shop_kinds() -> void:
	var shop: String = FileAccess.get_file_as_string("res://data/shop.json")
	var elements: Dictionary = {}
	var regions: Dictionary = {}
	for from: String in LINES:
		for n: String in [from, str(LINES[from][0])]:
			var sd: SpirlingData = Database.species(n)
			assert_ne(sd.rarity, "ancient", n)
			assert_true(FirstVoices.entry(n).is_empty(), n)
			assert_false(shop.contains("\"%s\"" % n), "%s is never sold" % n)
			for el: int in sd.elements:
				elements[el] = true
		regions[Database.species(from).region] = true
	assert_gte(elements.size(), 8, "spread over the elements")
	assert_gte(regions.size(), 6, "spread over the regions and eras")

func test_each_line_unfurls_on_a_recorded_trade() -> void:
	for from: String in LINES:
		var item: String = str(LINES[from][1])
		var got: Dictionary = TradeBond.stamp(LocalBackend.trade_mon_clean(_mon(from, "x", item)))
		var sp: Spirling = Spirling.from_dict(got)
		var ready: Array[SpirlingData] = TradeBond.ready_targets(sp)
		assert_eq(ready.size(), 1, from)
		assert_true(sp.unfurl_targets().has(ready[0]), "%s offers Unfurl in the Team menu" % from)
		sp.evolve(ready[0])
		assert_eq(sp.data.species_name, str(LINES[from][0]), from)

func test_a_keepsake_line_needs_its_keepsake_during_the_trade() -> void:
	for from: String in LINES:
		if str(LINES[from][1]).is_empty():
			continue
		var bare: Spirling = Spirling.from_dict(TradeBond.stamp(_mon(from, "x")))
		assert_true(TradeBond.ready_targets(bare).is_empty(), "%s without its Keepsake" % from)
		bare.held = str(LINES[from][1])
		assert_true(TradeBond.ready_targets(bare).is_empty(), "%s: putting it on later does not count" % from)
		var wrong: String = "keen_lens" if str(LINES[from][1]) != "keen_lens" else "iron_burr"
		assert_true(TradeBond.ready_targets(Spirling.from_dict(TradeBond.stamp(_mon(from, "y", wrong)))).is_empty(), from)

func test_no_bond_without_a_trade_or_from_an_earlier_form() -> void:
	var sp := Spirling.new(Database.species("Paddlewisp"), 60)
	assert_eq(sp.unfurl_targets().size(), 1, "only the Ring path")
	assert_true(TradeBond.ready_targets(sp).is_empty())
	sp = Spirling.from_dict(TradeBond.stamp(_mon("Talusk", "t")))
	sp.evolve(Database.species("Talusgard"))
	assert_true(TradeBond.ready_targets(sp).is_empty(), "bonded as Talusk, not as Talusgard")

func test_a_full_trade_stamps_the_receiver_side_from_server_data() -> void:
	var r: Dictionary = _trade([_mon("Paddlewisp", "a1"), _mon("Vanecrow", "a2", "swift_feather")])
	assert_eq(str(r.mons[0].bond_form), "Paddlewisp", "the answer carries the stamp")
	s.switch_user("ben")
	var plain: Dictionary = _find(s._saves()["1"].data.storage, "a1")
	var keyed: Dictionary = _find(s._saves()["1"].data.storage, "a2")
	assert_eq(str(plain.bond_form), "Paddlewisp")
	assert_false(plain.has("bond_item"))
	assert_eq(str(keyed.bond_item), "swift_feather")
	assert_eq(str(keyed.held), "swift_feather", "the Keepsake went with it")
	assert_eq(TradeBond.ready_targets(Spirling.from_dict(keyed))[0].species_name, "Vanecrest")
	assert_true(bool(_as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2}).ok))
	assert_eq(str(_find(s._saves()["1"].data.storage, "b1").get("bond_form", "")), "Kindlop", "the other side bonded too")

func test_only_the_bond_keepsake_may_stay_on_and_a_stamp_never_travels() -> void:
	assert_eq(LocalBackend.trade_mon_why(_mon("Vanecrow", "x", "keen_lens")), "holds_item")
	assert_eq(LocalBackend.trade_mon_why(_mon("Paddlewisp", "x", "swift_feather")), "holds_item")
	assert_eq(LocalBackend.trade_mon_why(_mon("Vanecrow", "x", "swift_feather")), "")
	assert_eq(TradeMenu.mon_why(Spirling.from_dict(_mon("Vanecrow", "x", "swift_feather"))), "")
	assert_eq(TradeMenu.mon_why(Spirling.from_dict(_mon("Vanecrow", "x", "keen_lens"))), "holds_item")
	var forged: Dictionary = _mon("Guisvix", "x")
	forged["bond_form"] = "Guisvix"
	forged["bond_item"] = "iron_burr"
	var c: Dictionary = LocalBackend.trade_mon_clean(forged)
	assert_false(c.has("bond_form") or c.has("bond_item"), "an earlier bond does not travel")
	var held: Dictionary = _mon("Snagwhisk", "x")
	held["bond_item"] = "iron_burr"
	assert_false(TradeBond.stamp(held).has("bond_item"), "the stamp names only what it really held")

func test_an_ended_trade_gives_no_bond() -> void:
	_set_save("ann", [_mon("Kindlop", "a0")], [_mon("Guisvix", "a1")])
	tid = int(_as("ann", "trade_open", {"p_code": codes.ben}).trade)
	_as("ann", "trade_put_spirlings", {"p_trade": tid, "p_slot": 1, "p_rev": 1, "p_uids": ["a1"]})
	_as("ann", "trade_cancel", {"p_trade": tid})
	var r: Dictionary = _as("ann", "trade_collect", {"p_trade": tid, "p_slot": 1, "p_rev": 2})
	assert_eq(str(r.mons[0].uid), "a1")
	assert_false((r.mons[0] as Dictionary).has("bond_form"))
	assert_true(TradeBond.ready_targets(Spirling.from_dict(r.mons[0])).is_empty())

func test_a_town_wayfarer_trades_only_once() -> void:
	var flags: Dictionary = {}
	var sp: Spirling = Spirling.from_dict(_mon("Carabun", "c"))
	assert_true(TradeBond.npc_trade(sp, "hookwick", flags))
	assert_true(TradeBond.npc_done("hookwick", flags))
	assert_eq(TradeBond.ready_targets(sp)[0].species_name, "Caravant")
	var other: Spirling = Spirling.from_dict(_mon("Morelamp", "m"))
	assert_false(TradeBond.npc_trade(other, "hookwick", flags), "once only")
	assert_true(TradeBond.ready_targets(other).is_empty())
	assert_true(TradeBond.npc_trade(other, "cinderfold", flags), "another town trades on its own")
	var keyed: Spirling = Spirling.from_dict(_mon("Quenchcoil", "q"))
	assert_ne(TradeBond.npc_why(keyed), "", "it has to hold its Keepsake")
	keyed.held = "keen_lens"
	assert_eq(TradeBond.npc_why(keyed), "")
	TradeBond.npc_trade(keyed, "brindlewick", flags)
	assert_eq(TradeBond.ready_targets(keyed)[0].species_name, "Quenchwyrm")

func test_town_wayfarers_stand_in_their_towns_with_a_once_only_offer() -> void:
	for town: String in TOWNS:
		var m: MapData = MapData.load_map(town)
		var found: Dictionary = {}
		for n: Dictionary in m.npcs:
			if str(n.get("dialogue", "")) == "trade_bond/" + town:
				found = n
		assert_false(found.is_empty(), town)
		assert_true(m.is_walkable(Vector2i(int(found.x), int(found.y))), town)
		var entry: Dictionary = Dialogue.get_entry("trade_bond/" + town)
		var open: Array[Dictionary] = Dialogue.choices_for(entry, {})
		assert_eq(str(open[0].action), "bond_trade " + town)
		assert_true(Dialogue.choices_for(entry, {TradeBond.npc_flag(town): true}).is_empty(), "%s: no second offer" % town)

func test_furl_back_still_works_and_it_can_unfurl_again() -> void:
	var sp: Spirling = Spirling.from_dict(TradeBond.stamp(_mon("Snagwhisk", "s", "iron_burr")))
	var level: int = sp.level
	sp.evolve(TradeBond.ready_targets(sp)[0])
	assert_eq(sp.data.species_name, "Snaggrave")
	sp = Spirling.from_dict(sp.to_dict())
	sp.furl_back()
	assert_eq(sp.data.species_name, "Snagwhisk")
	assert_eq(sp.level, level, "keeps its Ring")
	assert_eq(TradeBond.ready_targets(sp)[0].species_name, "Snaggrave", "the bond stays")

func test_gleam_and_kind_are_kept() -> void:
	var d: Dictionary = _mon("Lumothra", "g")
	d["gleam"] = true
	d["gleam_boost"] = false
	d["gleam_kind"] = "opaline"
	assert_eq(LocalBackend.trade_mon_why(d), "", "a wild Gleam trades")
	var sp: Spirling = Spirling.from_dict(TradeBond.stamp(LocalBackend.trade_mon_clean(d)))
	sp.evolve(TradeBond.ready_targets(sp)[0])
	assert_eq(sp.data.species_name, "Lumothane")
	assert_true(sp.gleam)
	assert_eq(sp.gleam_kind, "opaline")
	sp.furl_back()
	assert_eq(GleamRules.kind_of(sp), "opaline")

func test_bond_survives_a_save_and_bad_values_are_dropped() -> void:
	var sp: Spirling = Spirling.from_dict(TradeBond.stamp(_mon("Brassjack", "b", "spark_coil")))
	var back: Spirling = Spirling.from_dict(sp.to_dict())
	assert_eq(back.bond_form, "Brassjack")
	assert_eq(back.bond_item, "spark_coil")
	assert_false(Spirling.new(Database.species("Kindlop"), 5).to_dict().has("bond_form"), "only saved when set")
	assert_eq(Spirling.from_dict({"species": "Kindlop", "bond_form": "Nothing", "bond_item": "x"}).bond_item, "")

func test_spirlog_and_team_hints() -> void:
	assert_eq(TradeBond.spirlog_line(Database.species("Guisvix")), "Unfurls when it bonds with a new Wayfarer.")
	assert_string_contains(TradeBond.spirlog_line(Database.species("Vanecrow")), "Wind Anklet")
	assert_eq(TradeBond.spirlog_line(Database.species("Kindlop")), "")
	assert_string_contains(SpirlogBook.page_text(Database.species("Guisvix"), {}), TradeBond.HINT)
	var hints: Array[String] = Spirling.new(Database.species("Snagwhisk"), 5).unfold_hints()
	assert_string_contains(hints[1], "Iron Burr")

func test_server_knows_the_same_keepsakes() -> void:
	var sql: String = FileAccess.get_file_as_string(MIGRATION)
	var re := RegEx.create_from_string("\\('trade_bond_keys', '(\\{[^']*\\})'\\)")
	var m: RegExMatch = re.search(sql)
	assert_not_null(m, "keepsake list in the migration")
	assert_eq(JSON.parse_string(m.get_string(1)), TradeBond.keys())
	var tradeable: Array = s.trade_items()
	for item: String in TradeBond.keys().values():
		assert_true(tradeable.has(item), "%s is a tradeable item, nothing bought changes hands" % item)
	assert_true(sql.contains("from public, anon, authenticated, chimora_referee"), "no client may call the helpers")
