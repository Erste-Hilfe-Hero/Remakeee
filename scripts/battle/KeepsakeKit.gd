class_name KeepsakeKit
extends RefCounted
## Keepsakes in and around battle (docs/KAMPF_PLAN_1000.md, "Gehaltene Gegenstände"), values in
## data/keepsake_kit.json:
## - 281: the held keepsake shows as its icon on the info strip (your own always, a foe's once it
##   has shown itself).
## - 298: putting a keepsake from the bag on the acting Spirling in battle is an Item action and
##   costs its turn; the old one goes back into the bag. Only with the real team (never in echo
##   duels, which fight with copies) and where items are allowed.
## - 307: every Spirling remembers a few keepsake sets; a set can be put on again, for one
##   Spirling or the whole team.
## - 318, 319: when a keepsake works, its icon pops up over the holder (KeepsakePop) and its sound
##   plays.

## The keepsake sounds of data/keepsake_kit.json "sounds", named here so the sound check
## (tests/unit/test_sfx_names.gd) finds every file in code.
const SOUNDS: Array[String] = ["keepsake_stir", "keepsake_guard", "keepsake_fruit", "keepsake_endure"]
## Meta on a foe Spirling whose keepsake has shown itself (its strip shows the icon from then on).
const SEEN_META: String = "keepsake_seen"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/keepsake_kit.json"))
		_data = d if d is Dictionary else {}
	return _data

# --- 298: a keepsake swap in battle ------------------------------------------------------

## True when [param a] puts a keepsake on (an Item action with a holdable, non-battle item).
static func is_swap(a: BattleAction) -> bool:
	return a.kind == BattleAction.Kind.ITEM and BattleRules.is_holdable(a.item_id) and not bool(Database.item(a.item_id).get("battle", false))

## Keepsakes from the bag the Spirling in [param slot] could put on now, in bag order.
static func swap_ids(model: BattleModel, slot: int = 0) -> Array[String]:
	var out: Array[String] = []
	var own: int = model.active_index(BattleModel.Side.PLAYER, slot)
	if own < 0:
		return out
	for id: Variant in model.inventory:
		var a := BattleAction.make_item(BattleModel.Side.PLAYER, str(id), own, slot)
		if is_swap(a) and swap_legal(model, a):
			out.append(str(id))
	return out

static func swap_legal(model: BattleModel, a: BattleAction) -> bool:
	if not model.held_swap or a.side != BattleModel.Side.PLAYER or not model._items_allowed_for(a.side, a.slot):
		return false
	if int(model.inventory.get(a.item_id, 0)) <= 0 or a.item_target != model.active_index(a.side, a.slot):
		return false
	var s: Spirling = model.active_spirling(a.side, a.slot)
	return s != null and s.held != a.item_id

## Puts the keepsake on: one leaves the bag, the old one goes back in.
static func do_swap(model: BattleModel, a: BattleAction) -> void:
	var s: Spirling = model.parties[a.side][a.item_target]
	var old: String = s.held
	var inv: Dictionary = model.inventory
	inv[a.item_id] = int(inv[a.item_id]) - 1
	if int(inv[a.item_id]) <= 0:
		inv.erase(a.item_id)
	if not old.is_empty():
		inv[old] = int(inv.get(old, 0)) + 1
	s.held = a.item_id
	# A keepsake that raised max Vigor (Core Glass) must not leave too much Vigor behind.
	s.hp = mini(s.hp, s.max_hp())
	var d: Dictionary = model._who(a.side, a.slot)
	d.merge({"item": a.item_id, "item_name": str(Database.item(a.item_id).get("name", a.item_id)), "kind": "swap",
		"old": old, "old_name": str(Database.item(old).get("name", old)) if not old.is_empty() else ""})
	model.emit_event(BattleEvent.Type.HELD_ITEM, d)

## The battle line of a swap.
static func swap_line(d: Dictionary) -> String:
	if str(d.get("old", "")).is_empty():
		return "%s takes up the %s. That was its whole turn." % [d.get("name", ""), d.get("item_name", "")]
	return "%s drops its %s for the %s. That was its whole turn." % [d.get("name", ""), d.get("old_name", ""), d.get("item_name", "")]

# --- 307: keepsake sets -------------------------------------------------------------------

static func set_count() -> int:
	return maxi(int(data().get("sets", 3)), 1)

## The keepsake saved in set [param n] of [param s], "" for none.
static func saved(s: Spirling, n: int) -> String:
	return s.held_sets[n] if n >= 0 and n < s.held_sets.size() else ""

## Saves what [param s] holds now as its set [param n] (nothing held clears the set).
static func save_set(s: Spirling, n: int) -> void:
	if n < 0 or n >= set_count():
		return
	while s.held_sets.size() <= n:
		s.held_sets.append("")
	s.held_sets[n] = s.held
	while not s.held_sets.is_empty() and s.held_sets[-1].is_empty():
		s.held_sets.pop_back()

## True when any of [param team] has a set saved.
static func any_set(team: Array) -> bool:
	for s: Variant in team:
		if s is Spirling and not (s as Spirling).held_sets.is_empty():
			return true
	return false

## "Set 1: Ember Charm" or "Set 1: empty" for the menu.
static func set_row(s: Spirling, n: int) -> String:
	var id: String = saved(s, n)
	return Loc.t("Set %d: %s") % [n + 1, Loc.t(str(Database.item(id).get("name", id))) if not id.is_empty() else Loc.t("empty")]

## Puts set [param n] on every Spirling of [param team] that has one saved there (a Spirling with
## an empty set keeps what it holds). Every keepsake that has to move goes into the bag first, so
## keepsakes can change hands. Returns a line per keepsake the bag could not give.
static func wear_team_set(team: Array, n: int) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in team:
		var want: String = saved(s, n)
		if not want.is_empty() and (s as Spirling).held != want and not (s as Spirling).held.is_empty():
			GameState.set_held(s, "")
	for s: Variant in team:
		var want: String = saved(s, n)
		if want.is_empty() or (s as Spirling).held == want:
			continue
		if not GameState.set_held(s, want):
			out.append(Loc.t("No %s left in the bag for %s.") % [Loc.t(str(Database.item(want).get("name", want))), (s as Spirling).display_name()])
	return out

# --- 318, 319: the keepsake cue -----------------------------------------------------------

## What to show for [param e]: {"item", "sound", "side", "slot"}, or {} for an event that is
## not a keepsake at work.
static func cue(e: BattleEvent, model: BattleModel) -> Dictionary:
	var kind: String = ""
	var item: String = str(e.data.get("item", ""))
	match e.type:
		BattleEvent.Type.HELD_ITEM:
			kind = str(e.data.get("kind", "stir"))
			if not kind in ["guard", "swap"]:
				kind = "stir"
		BattleEvent.Type.HELD_FRUIT:
			kind = "fruit"
		BattleEvent.Type.HELD_ENDURE:
			kind = "endure"
			var s: Spirling = model.active_spirling(int(e.data.get("side", 0)), int(e.data.get("slot", 0))) if model != null else null
			if s != null:
				item = s.held
		_:
			return {}
	return {"item": item, "sound": str((data().get("sounds", {}) as Dictionary).get(kind, "")), "kind": kind,
		"side": int(e.data.get("side", 0)), "slot": int(e.data.get("slot", 0))}

## The pop over the holder: {"scale", "rise", "grow", "time", "hold"}. Under reduced motion it
## neither rises nor grows; it only shows for a moment and fades.
static func pop_motion(reduced: bool) -> Dictionary:
	var p: Dictionary = (data().get("pop", {}) as Dictionary).duplicate()
	var out: Dictionary = {"scale": int(p.get("scale", 2)), "rise": float(p.get("rise", 10.0)), "grow": float(p.get("grow", 1.5)),
		"time": float(p.get("time", 0.7)), "hold": float(p.get("hold", 0.35))}
	if reduced:
		out.rise = 0.0
		out.grow = 1.0
	return out

## The keepsake the strip of [param s] shows (281): your own always, a foe's once it worked.
static func strip_item(s: Spirling, own_side: bool) -> String:
	if s == null or s.held.is_empty():
		return ""
	return s.held if own_side or s.has_meta(SEEN_META) else ""
