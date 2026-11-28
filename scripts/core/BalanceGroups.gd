class_name BalanceGroups
extends RefCounted
## Simulator reports grouped by trait and by element (Kampf-Plan 1000, "Balance-Werkzeuge und
## Tests"). They read the species rows of a duel or team run (BalanceSim.run / run_team), so they
## add no battles of their own: a trait's win rate is the pooled record of every kind that has it.
##   godot --headless --path . -s res://tools/balance_sim.gd -- --mode team --level 36

## Pooled win rate above or below which a trait is flagged.
const TRAIT_BAND: Vector2 = Vector2(0.38, 0.62)

## {trait id ("" for kinds without one): {"wins", "losses", "draws", "kinds": [names]}}.
static func by_trait(result: Dictionary) -> Dictionary:
	return _group(result, func(sd: SpirlingData) -> Array: return [sd.trait_id])

## {element name: {...}}; a dual-element kind counts for both elements.
static func by_element(result: Dictionary) -> Dictionary:
	return _group(result, func(sd: SpirlingData) -> Array:
		var out: Array = []
		for e: int in sd.elements:
			out.append(Elements.element_name(e))
		return out)

static func _group(result: Dictionary, keys_of: Callable) -> Dictionary:
	var out: Dictionary = {}
	var sp: Dictionary = result.get("species", {})
	for n: String in sp:
		var sd: SpirlingData = Database.species(n)
		if sd == null:
			continue
		var row: Dictionary = sp[n]
		for k: Variant in keys_of.call(sd):
			var g: Dictionary = out.get(str(k), {"wins": 0, "losses": 0, "draws": 0, "kinds": []})
			g.wins = int(g.wins) + int(row.get("wins", 0))
			g.losses = int(g.losses) + int(row.get("losses", 0))
			g.draws = int(g.draws) + int(row.get("draws", 0))
			(g.kinds as Array).append(n)
			out[str(k)] = g
	return out

static func rate(g: Dictionary) -> float:
	var games: int = int(g.wins) + int(g.losses) + int(g.draws)
	return float(g.wins) / maxf(games, 1)

## Markdown table of [param groups], strongest first; flags rows outside TRAIT_BAND.
static func table(title: String, column: String, groups: Dictionary) -> String:
	var lines: PackedStringArray = ["", "## " + title, "", "| %s | Kinds | Win rate | W | L | D | Flag |" % column,
		"| --- | --- | --- | --- | --- | --- | --- |"]
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(rate(groups[a]), rate(groups[b])):
			return rate(groups[a]) > rate(groups[b])
		return a < b)
	for k: String in keys:
		var g: Dictionary = groups[k]
		var r: float = rate(g)
		var flag: String = "too strong" if r > TRAIT_BAND.y else ("too weak" if r < TRAIT_BAND.x else "")
		lines.append("| %s | %d | %d%% | %d | %d | %d | %s |" % [k if not k.is_empty() else "(none)", (g.kinds as Array).size(),
			roundi(r * 100.0), g.wins, g.losses, g.draws, flag])
	return "\n".join(lines) + "\n"

## Both tables for a duel or team result.
static func report(result: Dictionary) -> String:
	return table("Traits", "Trait", by_trait(result)) + table("Elements (pooled)", "Element", by_element(result))
