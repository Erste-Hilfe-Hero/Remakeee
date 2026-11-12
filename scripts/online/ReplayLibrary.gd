class_name ReplayLibrary
extends RefCounted
## Online 100 plan, area 8: every online battle (league, raid, echo duel, Rift board) is kept as a
## replay, the newest [code]keep[/code] in GameState.records["online_replays"] (point 71). A replay
## can be shared as a code and watched from a code (point 72), in any era look because watching
## uses the current look (point 75). The library also gives the Spirlings seen most in the
## season's online battles (point 78) and the own win rate per Spirling (point 79).
## Values in data/replay_library.json.

const KEY: String = "online_replays"
const PATH: String = "res://data/replay_library.json"

static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_cfg = d if d is Dictionary else {"keep": 20, "code_prefix": "CHR1-", "top_species": 5, "maintenance_warn_hours": 24}
	return _cfg

static func entries(records: Dictionary) -> Array:
	var v: Variant = records.get(KEY, [])
	return v if v is Array else []

## Keeps one online battle: [param snap] is the BattleReplay snapshot, [param claim] the
## BattleReferee claim. Newest first; older ones beyond the limit are dropped.
static func add(records: Dictionary, kind: String, snap: Dictionary, claim: Dictionary, season: String = "") -> void:
	if snap.is_empty():
		return
	var list: Array = entries(records).duplicate()
	list.push_front({"kind": kind, "won": str(claim.get("winner", "")) == "player", "rounds": int(claim.get("rounds", 0)),
		"season": season, "snap": snap.duplicate(true)})
	list.resize(mini(list.size(), int(cfg().keep)))
	records[KEY] = list

static func label(e: Dictionary) -> String:
	var res: String = Loc.t("Won") if bool(e.get("won", false)) else Loc.t("Lost")
	return "%s: %s (%s)" % [Loc.t(_kind_name(str(e.get("kind", "")))), BattleReplay.label(e.get("snap", {})), res]

static func _kind_name(kind: String) -> String:
	match kind:
		"league_fair": return "Fair league"
		"league_open": return "Open league"
		"raid": return "Raid"
		"echo_duel": return "Echo duel"
		"rift": return "Rift board"
	return "Online battle"

## A text code for [param snap] that a friend can paste to watch the same battle.
static func share_code(snap: Dictionary) -> String:
	var raw: PackedByteArray = JSON.stringify(snap).to_utf8_buffer()
	return str(cfg().code_prefix) + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))

## The snapshot inside [param code], or {} when the code is broken.
static func from_code(code: String) -> Dictionary:
	var c: String = code.strip_edges()
	var prefix: String = str(cfg().code_prefix)
	if not c.begins_with(prefix):
		return {}
	var body: String = c.substr(prefix.length())
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or re.search(body) == null:
		return {}
	var packed: PackedByteArray = Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return {}
	var raw: PackedByteArray = packed.decompress_dynamic(1 << 22, FileAccess.COMPRESSION_GZIP)
	var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not d is Dictionary or not d.has("seed") or not d.get("teams") is Array or not d.get("inputs") is Array:
		return {}
	# JSON turns every number into a float; the replay needs whole numbers back.
	return _ints(d)

static func _ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		var out_a: Array = []
		for x: Variant in v:
			out_a.append(_ints(x))
		return out_a
	return v

static func _species(team: Variant) -> Array[String]:
	var out: Array[String] = []
	if team is Array:
		for s: Variant in team:
			if s is Dictionary and s.has("species"):
				out.append(str(s.species))
	return out

## Point 79: {species: [wins, battles]} for the player's own Spirlings over the kept replays.
static func win_rates(records: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in entries(records):
		var teams: Array = (e.get("snap", {}) as Dictionary).get("teams", [[], []])
		var seen: Dictionary = {}
		for sp: String in _species(teams[0] if teams.size() > 0 else []):
			if seen.has(sp):
				continue
			seen[sp] = true
			var row: Array = out.get(sp, [0, 0])
			out[sp] = [int(row[0]) + (1 if bool(e.get("won", false)) else 0), int(row[1]) + 1]
	return out

static func win_rate_lines(records: Dictionary) -> Array[String]:
	var rates: Dictionary = win_rates(records)
	var names: Array = rates.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return rates[a][1] > rates[b][1] or (rates[a][1] == rates[b][1] and a < b))
	var out: Array[String] = []
	for sp: String in names:
		var w: int = rates[sp][0]
		var n: int = rates[sp][1]
		out.append(Loc.t("%s: %d%% won (%d of %d)") % [sp, roundi(100.0 * w / n), w, n])
	return out

## Point 78: the opposing Spirlings met most often, optionally only in [param season].
static func usage(records: Dictionary, season: String = "") -> Array:
	var counts: Dictionary = {}
	for e: Dictionary in entries(records):
		if not season.is_empty() and str(e.get("season", "")) != season:
			continue
		var teams: Array = (e.get("snap", {}) as Dictionary).get("teams", [[], []])
		for sp: String in _species(teams[1] if teams.size() > 1 else []):
			counts[sp] = int(counts.get(sp, 0)) + 1
	var rows: Array = []
	for sp: String in counts:
		rows.append([sp, counts[sp]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	rows.resize(mini(rows.size(), int(cfg().top_species)))
	return rows

static func usage_lines(records: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r: Array in usage(records):
		out.append(Loc.t("%s: met %d times") % [r[0], r[1]])
	return out

## Point 95: the title-screen warning before a planned maintenance at unix time [param at], or "".
static func maintenance_text(now: int, at: int) -> String:
	if at <= now or at - now > int(cfg().maintenance_warn_hours) * 3600:
		return ""
	var hours: int = int(ceil((at - now) / 3600.0))
	return Loc.t("Planned maintenance in %d h. The game is offline for a short while then.") % hours
