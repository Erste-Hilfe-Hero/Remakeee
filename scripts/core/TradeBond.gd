class_name TradeBond
extends RefCounted
## Unfurling through a bond with a new Wayfarer (1.3.2, Ali's wish). Some Spirling lines carry an
## unfold path with rule "bond" in data/spirlings.json: the form unfurls once it was received in a
## finished trade with a friend (online) or in the one-time trade of a town Wayfarer (offline, see
## Overworld "bond_trade"). Some paths also name a Keepsake (rule value) that it must hold during
## that trade; only that Keepsake may stay on a Spirling while it is traded.
## The server stamps a Spirling it hands over in a finished trade with "bond_form" (its species at
## that moment) and "bond_item" (the Keepsake it held), see public._trade_mon_bond in
## supabase/migrations/20261128060000_trade_bond.sql; LocalBackend does the same with stamp().
## The bond path stays ready while the Spirling is in that form, so it can furl back and unfurl
## again. Its Ring path stays too, so no player is ever locked out.

const RULE: String = "bond"
const HINT: String = "Unfurls when it bonds with a new Wayfarer."
const HINT_ITEM: String = "Unfurls when it bonds with a new Wayfarer while holding %s."

## The bond path of [param sd] ({"to", "rule", "value", "map"}), or {} when it has none.
static func path_of(sd: SpirlingData) -> Dictionary:
	if sd == null:
		return {}
	for p: Dictionary in sd.unfold:
		if str(p.get("rule", "")) == RULE:
			return p
	return {}

## The Keepsake [param sd] must hold during the trade, or "" (none, or no bond path).
static func key_item(sd: SpirlingData) -> String:
	var v: Variant = path_of(sd).get("value", "")
	return str(v) if v is String else ""

## Species name -> Keepsake for every bond path that needs one (the server's "trade_bond_keys").
static func keys() -> Dictionary:
	var out: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if not key_item(sd).is_empty():
			out[sd.species_name] = key_item(sd)
	return out

## True if Spirling [param m] (a save dictionary) may keep its Keepsake on in a trade: it is the
## one its own bond path asks for.
static func may_hold(m: Dictionary) -> bool:
	var held: String = str(m.get("held", ""))
	return not held.is_empty() and key_item(Database.species(str(m.get("species", "")))) == held

## Like public._trade_mon_bond: a Spirling handed over in a finished trade remembers the form it
## bonded in and the Keepsake it held.
static func stamp(m: Dictionary) -> Dictionary:
	var out: Dictionary = m.duplicate(true)
	out.erase("bond_item")
	out["bond_form"] = str(m.get("species", ""))
	if not str(m.get("held", "")).is_empty():
		out["bond_item"] = str(m.held)
	return out

## Forms [param s] can unfurl into through its bond right now.
static func ready_targets(s: Spirling) -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for p: Dictionary in s.data.unfold:
		if str(p.get("rule", "")) == RULE and s.unfold_ready(p, {}) and not out.has(p.to):
			out.append(p.to)
	return out

## Spirlog line for [param sd], or "" when it has no bond path.
static func spirlog_line(sd: SpirlingData) -> String:
	if path_of(sd).is_empty():
		return ""
	var item: String = key_item(sd)
	if item.is_empty():
		return Loc.t(HINT)
	return Loc.t(HINT_ITEM) % Loc.t(str(Database.item(item).get("name", item)))

## Flag of the one-time trade of the town Wayfarer [param town] (dialogue trade_bond/<town>).
static func npc_flag(town: String) -> String:
	return "bond_trade_" + town

## True once the town Wayfarer [param town] has traded with the player.
static func npc_done(town: String, flags: Dictionary) -> bool:
	return bool(flags.get(npc_flag(town), false))

## Team and storage Spirlings whose form has a bond path (candidates for a town trade).
static func npc_candidates(party: Array[Spirling], storage: Array[Spirling]) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for list: Array[Spirling] in [party, storage]:
		for s: Spirling in list:
			if not path_of(s.data).is_empty():
				out.append(s)
	return out

## Why [param s] gains nothing from a town trade now, or "".
static func npc_why(s: Spirling) -> String:
	var item: String = key_item(s.data)
	if not item.is_empty() and s.held != item:
		return Loc.t("It has to hold %s during the trade.") % Loc.t(str(Database.item(item).get("name", item)))
	return ""

## The one-time trade with the town Wayfarer [param town]: they take [param s] and trade it back,
## so it bonded with a new Wayfarer. Sets the town's flag in [param flags]. False if that
## Wayfarer already traded.
static func npc_trade(s: Spirling, town: String, flags: Dictionary) -> bool:
	if npc_done(town, flags) or town.is_empty():
		return false
	s.bond_form = s.data.species_name
	s.bond_item = s.held
	flags[npc_flag(town)] = true
	return true

## After a trade: offers each Spirling in [param list] that can unfurl through its bond, and
## plays the unfurl moment for each one the player says yes to. Never automatic.
static func offer_unfurl(menu: MenuHost, list: Array[Spirling]) -> void:
	for s: Spirling in list:
		var ready: Array[SpirlingData] = ready_targets(s)
		if ready.is_empty():
			continue
		var old_name: String = s.display_name()
		var q: String = Loc.t("%s feels the bond with its new Wayfarer. Unfurl it into %s now? You can furl it back later.") % [old_name, Loc.t(ready[0].species_name)]
		if not await menu.confirm(q):
			continue
		var old_data: SpirlingData = s.data
		s.evolve(ready[0])
		GameState.mark_seen(s.data.species_name, true)
		var seq := UnfurlSequence.new()
		menu.add_child(seq)
		await seq.play(old_data, s.data)
		seq.queue_free()
		await menu.info(Loc.t("%s unfurls into %s!") % [old_name, Loc.t(s.data.species_name)])
