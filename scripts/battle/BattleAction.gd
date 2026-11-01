class_name BattleAction
extends RefCounted
## One combatant's choice for a turn. In battles with several Spirlings per side, [member slot]
## says which field slot acts and [member target_slot] which foe slot a single-target move aims at.

enum Kind { MOVE, SWAP, ITEM, BOND, RUN, REST }

## Turn-order class: lower acts first (swap/item/bond/run before moves).
const CLASS_ORDER: Dictionary[Kind, int] = {
	Kind.RUN: 0, Kind.SWAP: 1, Kind.ITEM: 1, Kind.BOND: 1, Kind.MOVE: 2, Kind.REST: 2,
}

var kind: Kind = Kind.REST
var side: int = 0
var move_index: int = -1
var swap_index: int = -1
var item_id: String = ""
var item_target: int = -1
## Bond minigame score 0..1 (BOND only).
var timing_score: float = 0.0
## Set by the model when queued: the Spirling that chose this action.
var actor: Spirling = null
## True for the bonus action a wild Spirling gets after a failed bond.
var is_free: bool = false
## Field slot of the acting Spirling (0 in 1v1).
var slot: int = 0
## Foe slot a single-target move or a bond aims at; -1 = the first foe still standing.
var target_slot: int = -1
## True for a Rift boss's extra action; it always goes after every normal action.
var is_bonus: bool = false

static func make_move(p_side: int, index: int, p_slot: int = 0, p_target: int = -1) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.MOVE
	a.side = p_side
	a.move_index = index
	a.slot = p_slot
	a.target_slot = p_target
	return a

static func make_swap(p_side: int, index: int, p_slot: int = 0) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.SWAP
	a.side = p_side
	a.swap_index = index
	a.slot = p_slot
	return a

static func make_item(p_side: int, id: String, target: int, p_slot: int = 0) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.ITEM
	a.side = p_side
	a.item_id = id
	a.item_target = target
	a.slot = p_slot
	return a

## [param charm_id] optionally consumes a charm item that adds a bond bonus.
## [param p_target] picks the wild foe slot in a horde (-1 = the first one standing).
static func make_bond(p_side: int, score: float, charm_id: String = "", p_slot: int = 0, p_target: int = -1) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.BOND
	a.side = p_side
	a.timing_score = score
	a.item_id = charm_id
	a.slot = p_slot
	a.target_slot = p_target
	return a

static func make_run(p_side: int, p_slot: int = 0) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.RUN
	a.side = p_side
	a.slot = p_slot
	return a

static func make_rest(p_side: int, p_slot: int = 0) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.REST
	a.side = p_side
	a.slot = p_slot
	return a

## Turn-order class; a boss's bonus action sorts after every normal action.
func order_class() -> int:
	return 3 if is_bonus else CLASS_ORDER[kind]
