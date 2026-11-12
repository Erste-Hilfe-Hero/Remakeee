class_name RegionStats
extends RefCounted
## "Finds" and "Secrets" per region for the records (area 3 item 1096).
## Finds are the hidden finds on every map and floor ("secrets" in map data); secrets are the
## smooth-rock passages and the cartographer's stones (marker_stone signs). Item 1300: each region
## also has its own stone count and survey share ("mapped": seen over walkable cells).

## {region id: {"finds", "secrets", "stones", "mapped": Vector2i(done, total)}}
static func totals(flags: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		if not out.has(m.region):
			out[m.region] = {"finds": Vector2i.ZERO, "secrets": Vector2i.ZERO, "stones": Vector2i.ZERO, "mapped": Vector2i.ZERO}
		var r: Dictionary = out[m.region]
		r.finds += m.secrets_found(flags)
		r.mapped += Survey.cells(m)
		for p: Dictionary in m.passages:
			r.secrets += Vector2i(1 if bool(flags.get(str(p.get("flag", "")), false)) else 0, 1)
		for s: Dictionary in m.signs:
			var sf: String = stone_flag(str(s.get("dialogue", "")))
			if not sf.is_empty():
				var one := Vector2i(1 if bool(flags.get(sf, false)) else 0, 1)
				r.secrets += one
				r.stones += one
	return out

## The flag a sign's dialogue counts ("marker_stone 7" or "marker_stone 7 corvane"), or "".
static func stone_flag(ref: String) -> String:
	if ref.is_empty() or not Dialogue.exists(ref):
		return ""
	for a: String in str(Dialogue.get_entry(ref).get("action", "")).split(";", false):
		var parts: PackedStringArray = a.strip_edges().split(" ", false)
		if parts.size() >= 2 and parts[0] == "marker_stone":
			return MarkerStones.flag(int(parts[1]), parts[2] if parts.size() > 2 else "veydal")
	return ""

## Survey share of a region in percent, from a totals() entry.
static func mapped_percent(entry: Dictionary) -> int:
	var c: Vector2i = entry.get("mapped", Vector2i.ZERO)
	return 0 if c.y == 0 else c.x * 100 / c.y

## Lines for the records screen, in the order of data/world_layout.json.
static func lines(flags: Dictionary) -> Array[String]:
	var t: Dictionary = totals(flags)
	var order: Array = ["veydal", "corvane", "ashmere", "solenne"]
	for r: Variant in t:
		if not r in order:
			order.append(r)
	var out: Array[String] = []
	for r: Variant in order:
		if not t.has(r):
			continue
		var f: Vector2i = t[r].finds
		var s: Vector2i = t[r].secrets
		out.append(Loc.t(str(r).capitalize()))
		out.append("  " + Loc.t("Mapped: %d%%") % mapped_percent(t[r]))
		out.append("  " + Loc.t("Finds: %d/%d") % [f.x, f.y])
		var st: Vector2i = t[r].stones
		if st.y > 0:
			out.append("  " + Loc.t("Cartographer's stones: %d/%d") % [st.x, st.y])
		if s.y > 0:
			out.append("  " + Loc.t("Secrets: %d/%d") % [s.x, s.y])
	return out
