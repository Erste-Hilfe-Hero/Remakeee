class_name TraitKit
extends RefCounted
## Extra gifts and keepsakes of the Kampf plan (areas Traits 241-280 and Keepsakes 281-320),
## data in data/kampf_kit.json and data/items.json. BattleModel calls the hooks below; nothing
## here rolls the battle RNG unless a Spirling in front carries the gift or keepsake in question,
## so seeds of battles without them play out exactly as before.
##
## Gift keys (data "traits", merged into ShopEffects.gift_table next to the species' gift):
##   cost_cut / cost_from: arts costing cost_from Energy or more cost cost_cut less
##   super_taken / resist_taken: factor on very effective / resisted hits taken
##   swap_cure: its condition is gone when it steps back
##   contact_scorch: chance to Scorch a physical attacker that hits it
##   multi_mult / solo_mult: damage factor in multi battles / in 1v1
##   first_act: on its first turn in front its art goes before every other art
##   field_double: the field's boost or drawback counts twice for its arts
##   field_extra: turns added to a Resonance field it lays (also a keepsake key)
##   status_half: conditions on it last half as long
##   enter_team_stage: stages for it and every ally in front when it steps in
##   drowse_heal_div: heals max Vigor / div each turn while Drowsed
##   no_recoil: no recoil from its own arts
##   free_swap: stepping back costs no Energy and no condition blocks it (also a keepsake key)
## Keepsake keys (items.json "held"): energy_cap, super_guard (once per battle), enter_stage,
## overcharge_bonus, bond_bonus, rest_energy, field_mult_in {"field", "mult"}.

const PATH: String = "res://data/kampf_kit.json"
## Meta key a Rift boss carries its boss gift under (battle only).
const BOSS_META: String = "kit_boss_trait"
## Priority added to an art of a Sentinel on its first turn in front.
const FIRST_ACT_PRIORITY: int = 10

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func traits() -> Dictionary:
	return data().get("traits", {})

## Effect table of a gift of this kit, or {}.
static func info(id: String) -> Dictionary:
	return traits().get(id, {})

static func keepsakes() -> Array:
	return data().get("keepsakes", [])

# --- Who carries which extra gift -------------------------------------------------------------

## Gift ids working on [param s] next to its own (boss gift, Prism gift, learned bonus gift).
static func extra_ids(s: Spirling) -> Array[String]:
	var out: Array[String] = []
	if s == null:
		return out
	if s.has_meta(BOSS_META):
		out.append(str(s.get_meta(BOSS_META)))
	var p: String = prism_trait_id(s)
	if not p.is_empty() and not p in out:
		out.append(p)
	if not s.bonus_trait.is_empty() and traits().has(s.bonus_trait) and not s.bonus_trait in out:
		out.append(s.bonus_trait)
	return out

## The hidden Prism gift (item 244): every "share"-th Prism Spirling (by its uid) carries it.
static func prism_trait_id(s: Spirling) -> String:
	if s == null or not s.prism or s.uid.is_empty():
		return ""
	var p: Dictionary = data().get("prism_trait", {})
	var share: int = maxi(1, int(p.get("share", 1)))
	return str(p.get("id", "")) if absi(s.uid.hash()) % share == 0 else ""

## The boss gift of Rift boss [param boss_id] (items 267, 268), or "".
static func boss_trait(boss_id: String) -> String:
	return str(data().get("boss_traits", {}).get(boss_id, ""))

## The bonus gifts [param s] may learn (items 243, 274): only an unfolded Spirling whose kinship
## reached "min_kinship", from the list of its first element (or "_any").
static func bonus_options(s: Spirling) -> Array[String]:
	var out: Array[String] = []
	if s == null or s.data == null or not unfolded(s) or s.kinship < int(data().get("min_kinship", 0)):
		return out
	var lists: Dictionary = data().get("bonus_traits", {})
	var key: String = str(Elements.E.find_key(s.elements()[0])) if not s.elements().is_empty() else "_any"
	for id: Variant in lists.get(key, lists.get("_any", [])):
		if traits().has(str(id)):
			out.append(str(id))
	return out

static func unfolded(s: Spirling) -> bool:
	return Database.earlier_form(s.data) != null

## Teaches [param s] the bonus gift [param id] ("" forgets it). False when it may not learn it.
static func learn_bonus(s: Spirling, id: String) -> bool:
	if id.is_empty():
		s.bonus_trait = ""
		return true
	if not id in bonus_options(s):
		return false
	s.bonus_trait = id
	return true

# --- Lookups over gift and keepsake -------------------------------------------------------------

static func gift(s: Spirling) -> Dictionary:
	return ShopEffects.gift_table(s)

static func held(s: Spirling) -> Dictionary:
	return BattleRules.held_info(s.held) if s != null else {}

static func has_key(s: Spirling, key: String) -> bool:
	return s != null and (gift(s).has(key) or held(s).has(key))

## Energy [param s] can store above the cap, and starts a battle with on top (item 283).
static func energy_cap(s: Spirling) -> int:
	return int(BattleRules.add_key(s, "energy_cap")) if s != null else 0

## Energy an art costs [param s] less (Spare Flame, item 246).
static func cost_cut(s: Spirling, mv: MoveData) -> int:
	var g: Dictionary = gift(s)
	if not g.has("cost_cut") or mv.energy_cost < int(g.get("cost_from", 0)):
		return 0
	return mini(int(g.cost_cut), mv.energy_cost)

static func free_swap(s: Spirling) -> bool:
	return has_key(s, "free_swap")

static func no_recoil(s: Spirling) -> bool:
	return has_key(s, "no_recoil")

## Turns a Resonance field laid by [param s] holds (Echo Soul, Lantern Glass; items 255, 290).
static func field_turns(s: Spirling) -> int:
	return BattleRules.RESONANCE_TURNS + int(BattleRules.add_key(s, "field_extra"))

## Condition turns on [param s] after Hush Core (item 268) halves them (0 stays 0).
static func status_turns(s: Spirling, turns: int) -> int:
	if turns <= 0 or not gift(s).has("status_half"):
		return turns
	return maxi(1, ceili(turns / 2.0))

## Extra Energy a rest gives [param s] (Rest Candle, item 309).
static func rest_energy(s: Spirling) -> int:
	return int(BattleRules.add_key(s, "rest_energy"))

## Overcharge force per Energy added by [param s]'s keepsake (Rift Splinter, item 291).
static func overcharge_bonus(s: Spirling) -> float:
	return BattleRules.add_key(s, "overcharge_bonus")

## Bond chance added by the keepsakes of the player's Spirlings in front (Echo Shell, item 308).
static func bond_bonus(model: BattleModel) -> float:
	var out: float = 0.0
	for slot: int in model.standing_slots(BattleModel.Side.PLAYER):
		out += float(held(model.active_spirling(BattleModel.Side.PLAYER, slot)).get("bond_bonus", 0.0))
	return out

## Damage factor that needs no battle state, so the damage preview shows it too (items 276, 313):
## Prism Skin, Counter Current, Field Runner and the field stones.
static func static_mult(user: Spirling, target: Spirling, mv: MoveData, field: String) -> float:
	var m: float = 1.0
	if target != null:
		var eff: float = DamageCalc.effectiveness(target, mv)
		if eff > 1.0:
			m *= BattleRules.mult_key(target, "super_taken")
		elif eff > 0.0 and eff < 1.0:
			m *= BattleRules.mult_key(target, "resist_taken")
	if not field.is_empty():
		if gift(user).has("field_double"):
			m *= BattleRules.field_mult(field, mv.element)
		var fm: Variant = held(user).get("field_mult_in", {})
		if fm is Dictionary and str((fm as Dictionary).get("field", "")) == field:
			m *= float((fm as Dictionary).get("mult", 1.0))
	return m

# --- Battle hooks (BattleModel) -----------------------------------------------------------------

## Shows a gift of this kit the first time it works in a battle (TRAIT).
static func show(model: BattleModel, side: int, slot: int, id: String) -> void:
	var s: Spirling = model.active_spirling(side, slot)
	var t: Dictionary = info(id)
	if s == null or t.is_empty():
		return
	var shown: Dictionary = model.kit.get_or_add("shown", {})
	var key: String = "%d:%s" % [s.get_instance_id(), id]
	if shown.has(key):
		return
	shown[key] = true
	var d: Dictionary = model._who(side, slot)
	d.merge({"trait": id, "label": str(t.label), "text": str(t.text)})
	model.emit_event(BattleEvent.Type.TRAIT, d)

## The id of the kit gift on [param s] that carries [param key], or "".
static func trait_with(s: Spirling, key: String) -> String:
	for id: String in extra_ids(s):
		if info(id).has(key):
			return id
	return ""

static func _held_event(model: BattleModel, side: int, slot: int, kind: String) -> void:
	var s: Spirling = model.active_spirling(side, slot)
	var d: Dictionary = model._who(side, slot)
	d.merge({"item": s.held, "item_name": str(Database.item(s.held).get("name", s.held)), "kind": kind})
	model.emit_event(BattleEvent.Type.HELD_ITEM, d)

## Start of battle: Rift bosses take their boss gift, every lead steps in.
static func on_start(model: BattleModel) -> void:
	if not model.foe_boss.is_empty():
		var id: String = boss_trait(model.foe_boss)
		var boss: Spirling = model.active_spirling(BattleModel.Side.FOE)
		if boss != null and traits().has(id):
			boss.set_meta(BOSS_META, id)
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		for slot: int in model.standing_slots(side):
			on_enter(model, side, slot)

## A Spirling steps in: Pace Feather (item 288), Lantern Light (item 269), Sentinel's first turn.
static func on_enter(model: BattleModel, side: int, slot: int) -> void:
	var s: Spirling = model.active_spirling(side, slot)
	if not model.is_standing(s):
		return
	# Mid-turn (a swap or the wheel) it first acts next turn; after the turn moved on, this turn.
	var late: bool = model.phase == BattleModel.Phase.EXECUTE_ACTION or model.phase == BattleModel.Phase.END_OF_TURN
	var first: Dictionary = model.kit.get_or_add("first_turn", {})
	first[s] = model.turn + (1 if late else 0)
	var st: Variant = held(s).get("enter_stage", {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		_held_event(model, side, slot, "enter")
		for stat: String in st:
			model.change_stage(side, stat, int(st[stat]), slot)
	var team: Variant = gift(s).get("enter_team_stage", {})
	if team is Dictionary and not (team as Dictionary).is_empty():
		show(model, side, slot, trait_with(s, "enter_team_stage"))
		for ally: int in model.standing_slots(side):
			for stat: String in team:
				model.change_stage(side, stat, int(team[stat]), ally)

## A Spirling steps back to the bench: Quiet Heart (item 249) washes its condition away.
static func on_leave(model: BattleModel, side: int, slot: int) -> void:
	var s: Spirling = model.active_spirling(side, slot)
	if s == null or s.status.is_empty() or not gift(s).has("swap_cure"):
		return
	show(model, side, slot, trait_with(s, "swap_cure"))
	model.cure(side, slot)

## Priority bonus for the turn order (Sentinel, item 253).
static func priority_bonus(model: BattleModel, a: BattleAction) -> int:
	if a.kind != BattleAction.Kind.MOVE or a.actor == null or not gift(a.actor).has("first_act"):
		return 0
	var first: Dictionary = model.kit.get("first_turn", {})
	return FIRST_ACT_PRIORITY if int(first.get(a.actor, -1)) == model.turn else 0

## Damage factor that needs the battle (Pack Sense, Loner, Ward Talisman; items 251, 252, 284).
static func hit_mult(model: BattleModel, side: int, slot: int, target_side: int, t_slot: int, mv: MoveData) -> float:
	var me: Spirling = model.active_spirling(side, slot)
	var target: Spirling = model.active_spirling(target_side, t_slot)
	var m: float = 1.0
	var g: Dictionary = gift(me)
	var key: String = "multi_mult" if model.is_multi() else "solo_mult"
	if g.has(key):
		m *= float(g[key])
		show(model, side, slot, trait_with(me, key))
	for k: String in ["super_taken", "resist_taken"]:
		var tid: String = trait_with(target, k)
		if not tid.is_empty() and static_mult(me, target, mv, "") != 1.0:
			show(model, target_side, t_slot, tid)
	if g.has("field_double") and BattleRules.field_mult(model.field, mv.element) != 1.0:
		show(model, side, slot, trait_with(me, "field_double"))
	var guard: float = float(held(target).get("super_guard", 0.0))
	if guard > 0.0 and DamageCalc.effectiveness(target, mv) > 1.0:
		var used: Dictionary = model.kit.get_or_add("talisman", {})
		if not used.has(target):
			used[target] = true
			m *= guard
			_held_event(model, target_side, t_slot, "guard")
	return m

## After a hit landed: Glow Hide (item 250) may Scorch a physical attacker.
static func after_hit(model: BattleModel, side: int, slot: int, target_side: int, t_slot: int, mv: MoveData, dealt: int) -> void:
	if dealt <= 0 or mv.kind != MoveData.Kind.PHYSICAL:
		return
	var me: Spirling = model.active_spirling(side, slot)
	var target: Spirling = model.active_spirling(target_side, t_slot)
	if not model.is_standing(me) or target == null:
		return
	var chance: float = float(gift(target).get("contact_scorch", 0.0))
	if chance <= 0.0 or not me.status.is_empty():
		return
	if model.rng.randf() < chance:
		show(model, target_side, t_slot, trait_with(target, "contact_scorch"))
		model.apply_status(side, "scorch", slot, target_side)

## End of a turn for the Spirling in front: Cold Sleep (item 270).
static func end_of_turn(model: BattleModel, side: int, slot: int) -> void:
	var s: Spirling = model.active_spirling(side, slot)
	if not model.is_standing(s) or not StatusRules.sleeps(s.status):
		return
	var div: int = int(gift(s).get("drowse_heal_div", 0))
	if div > 0 and s.hp < s.max_hp():
		show(model, side, slot, trait_with(s, "drowse_heal_div"))
		model.heal(side, maxi(1, s.max_hp() / div), slot)

# --- Rules and texts ------------------------------------------------------------------------

## Keepsakes a tournament rule "no_power_keepsakes" locks (item 293).
static func tourney_bans() -> Array:
	return data().get("tourney_bans", [])

## True when [param team] holds no keepsake twice (the keepsake clause of tournaments, item 315).
static func keepsakes_unique(team: Array) -> bool:
	var seen: Dictionary = {}
	for s: Variant in team:
		var h: String = (s as Spirling).held if s is Spirling else ""
		if h.is_empty():
			continue
		if seen.has(h):
			return false
		seen[h] = true
	return true

## The top floor of a Rift tower hands out its keepsake once (item 301). Returns the lines.
static func tower_reward(tower_id: String) -> Array[String]:
	var id: String = str(data().get("tower_rewards", {}).get(tower_id, ""))
	if id.is_empty() or Database.item(id).is_empty():
		return []
	GameState.add_item(id)
	return [Loc.t("Atop the tower lies a keepsake: %s.") % Loc.t(str(Database.item(id).name))]

## The rarity word of a keepsake (item 302), "" for items without one.
static func rarity(item_id: String) -> String:
	return str(Database.item(item_id).get("rarity", ""))

## "\nRarity: Rare" for the keepsake hint (item 302), "" without a rarity.
static func rarity_line(item_id: String) -> String:
	var r: String = rarity(item_id)
	return "" if r.is_empty() else "\n" + Loc.t("Rarity: %s") % Loc.t(r.capitalize())

## One line per gift for the lexicon and the Spirlog (items 245, 256, 257): the species gifts,
## the hidden gifts and this kit's gifts, sorted by label.
static func all_gift_lines() -> Array[String]:
	var rows: Dictionary = {}
	for id: String in BattleRules.TRAITS:
		rows[str(BattleRules.TRAITS[id].label)] = str(BattleRules.TRAITS[id].text)
	var hidden: Dictionary = HiddenGifts.data().get("gifts", {})
	for id: String in hidden:
		rows[str(hidden[id].get("label", id))] = str(hidden[id].get("text", ""))
	for id: String in traits():
		rows[str(traits()[id].label)] = str(traits()[id].text)
	var labels: Array = rows.keys()
	labels.sort()
	var out: Array[String] = []
	for l: Variant in labels:
		out.append("%s: %s" % [Loc.t(str(l)), Loc.t(str(rows[l]))])
	return out

## One line per keepsake a Spirling can hold (item 295), sorted by name.
static func all_keepsake_lines() -> Array[String]:
	var rows: Array[String] = []
	Database.load_all()
	for it: Dictionary in Database.items.values():
		if it.has("held"):
			rows.append("%s: %s" % [Loc.t(str(it.name)), Loc.t(str(it.get("description", "")))])
	rows.sort()
	return rows
