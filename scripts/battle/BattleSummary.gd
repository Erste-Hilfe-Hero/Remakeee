class_name BattleSummary
extends RefCounted
## The end-of-battle report (KAMPF_PLAN items 20, 23, 76): damage dealt and taken, who knocked
## out how many foes, the most valuable Spirling of the player's side, the Energy both sides spent
## and the battle seed. It only listens to the model's events, so it never changes the battle.

var _model: WeakRef
## Damage dealt by each Spirling (by arts only; conditions and the field belong to nobody).
var dealt: Dictionary = {}
## Foes each Spirling knocked out.
var downs: Dictionary = {}
## Damage each side took from arts, [player, foe].
var taken: Array[int] = [0, 0]
## Energy each side spent, [player, foe].
var energy_spent: Array[int] = [0, 0]
## Last Energy seen per Spirling, to turn ENERGY_CHANGED (which only carries the new value) into spending.
var _energy: Dictionary = {}
## The Spirling whose art is landing right now (null between arts).
var _hitter: Spirling = null
var _hitter_side: int = -1
## The Spirling that landed the last art hit on each Spirling this turn, for the knock-out.
var _last_hit: Dictionary = {}

func _init(m: BattleModel) -> void:
	_model = weakref(m)
	m.event_emitted.connect(_on_event)
	_read_energy(m)

func _read_energy(m: BattleModel) -> void:
	for team: Array in m.parties:
		for s: Spirling in team:
			_energy[s] = s.energy

func _spirling(side: int, index: int) -> Spirling:
	var m: BattleModel = _model.get_ref()
	if m == null or side < 0 or side > 1 or index < 0 or index >= m.parties[side].size():
		return null
	return m.parties[side][index]

func _on_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", -1))
	var who: Spirling = _spirling(side, int(e.data.get("index", -1)))
	match e.type:
		BattleEvent.Type.BATTLE_START:
			var m: BattleModel = _model.get_ref()
			if m != null:
				_read_energy(m)
		BattleEvent.Type.MOVE_USED:
			_hitter = who
			_hitter_side = side
		BattleEvent.Type.REST, BattleEvent.Type.SWAP_OUT, BattleEvent.Type.ITEM_USED, BattleEvent.Type.STATUS_TICK:
			_hitter = null
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			if who != null:
				_energy[who] = who.energy
		BattleEvent.Type.DAMAGE:
			# Recoil and other self-harm is nobody's credit.
			if who == null or _hitter == null or not e.data.has("move") or side < 0 or side == _hitter_side:
				return
			var amount: int = int(e.data.get("amount", 0))
			dealt[_hitter] = int(dealt.get(_hitter, 0)) + amount
			taken[side] += amount
			_last_hit[who] = _hitter
		BattleEvent.Type.FAINTED:
			var by: Variant = _last_hit.get(who)
			if by != null:
				downs[by] = int(downs.get(by, 0)) + 1
		BattleEvent.Type.ENERGY_CHANGED:
			if who == null:
				return
			var now: int = int(e.data.get("energy", who.energy))
			var before: int = int(_energy.get(who, now))
			if now < before and side >= 0:
				energy_spent[side] += before - now
			_energy[who] = now

## The player's most valuable Spirling: most foes knocked out, then most damage. Null if none hit.
func mvp() -> Spirling:
	var m: BattleModel = _model.get_ref()
	if m == null:
		return null
	var best: Spirling = null
	for s: Spirling in m.parties[BattleModel.Side.PLAYER]:
		if int(dealt.get(s, 0)) <= 0:
			continue
		if best == null or int(downs.get(s, 0)) > int(downs.get(best, 0)) \
				or (int(downs.get(s, 0)) == int(downs.get(best, 0)) and int(dealt.get(s, 0)) > int(dealt.get(best, 0))):
			best = s
	return best

## The report as short lines for the text box and the log.
func lines() -> Array[String]:
	var out: Array[String] = []
	var best: Spirling = mvp()
	if best != null:
		out.append(Loc.t("%s was the best: %d damage, %d down") % [best.display_name(), int(dealt.get(best, 0)), int(downs.get(best, 0))])
	out.append(Loc.t("Damage dealt %d, taken %d") % [taken[BattleModel.Side.FOE], taken[BattleModel.Side.PLAYER]])
	out.append(Loc.t("Energy spent %d, by the foe %d") % [energy_spent[BattleModel.Side.PLAYER], energy_spent[BattleModel.Side.FOE]])
	var m: BattleModel = _model.get_ref()
	if m != null:
		out.append(seed_line(m))
	return out

## "Battle seed 0001e240", for replays and bug reports (item 23).
static func seed_line(m: BattleModel) -> String:
	return Loc.t("Battle seed %s") % ("%08x" % (m.battle_seed & 0xFFFFFFFF))
