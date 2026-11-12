class_name RegionStats
extends RefCounted
## "Finds" and "Secrets" per region for the records (area 3 item 1096).
## Finds are the hidden finds on every map and floor ("secrets" in map data); secrets are the
## smooth-rock passages and the cartographer's stones (marker_stone signs).

## {region id: {"finds": Vector2i(taken, total), "secrets": Vector2i(found, total)}}
static func totals(flags: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		if not out.has(m.region):
			out[m.region] = {"finds": Vector2i.ZERO, "secrets": Vector2i.ZERO}
		var r: Dictionary = out[m.region]
		r.finds += m.secrets_found(flags)
		for p: Dictionary in m.passages:
			r.secrets += Vector2i(1 if bool(flags.get(str(p.get("flag", "")), false)) else 0, 1)
		for s: Dictionary in m.signs:
			var sf: String = stone_flag(str(s.get("dialogue", "")))
			if not sf.is_empty():
				r.secrets += Vector2i(1 if bool(flags.get(sf, false)) else 0, 1)
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
		out.append("  " + Loc.t("Finds: %d/%d") % [f.x, f.y])
		if s.y > 0:
			out.append("  " + Loc.t("Secrets: %d/%d") % [s.x, s.y])
	return out
