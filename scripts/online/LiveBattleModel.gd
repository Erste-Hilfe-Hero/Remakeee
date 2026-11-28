class_name LiveBattleModel
extends BattleModel
## The battle of a live duel for the animated battle screen (Online 100, points 1 and 73). The
## screen plays it like a replay; this model feeds it one round at a time, as the server hands the
## rounds out. Side 0 (the inviter) is the lower side for both players and every watcher, because
## all of them and the referee must play the very same battle (LiveDuelSim).

## The screen asked for the next round and none is there yet.
signal idle

## Rounds not played yet: [input of side 0, input of side 1].
var rounds: Array = []
## Give this to BattleScene.replay_inputs. It never runs empty while the duel is open, so the
## screen keeps asking instead of ending.
var feed: Array = [{}]
## Rounds played so far.
var played: int = 0
var waiting: bool = false
var _closed: bool = false

## The battle of duel state [param d] (live_state or live_watch) before its first round; null
## when the teams are not there or cannot be built.
static func build(d: Dictionary) -> LiveBattleModel:
	var teams: Variant = d.get("teams", [])
	if not teams is Array or (teams as Array).size() != 2:
		return null
	var plain: BattleModel = BattleReplay.build_model(LiveDuelSim.snap_of(d))
	if plain == null:
		return null
	var m := LiveBattleModel.new(plain.parties[0], plain.parties[1], plain.is_wild, plain.battle_seed, plain.ai.level)
	# Everything BattleReplay set up, whatever the battle rules add later.
	for p: Dictionary in plain.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and str(p.name) != "_handlers":
			m.set(str(p.name), plain.get(str(p.name)))
	return m

## For someone who comes in late: [param done] rounds are played without showing them, and the
## screen starts with the two Spirlings that stand now.
func enter(done: Array) -> void:
	if done.is_empty():
		return
	start()
	for r: Variant in done:
		if is_finished():
			break
		_round(r)
	set_meta("intro", [BattleEvent.new(BattleEvent.Type.SEND_OUT, _who(Side.FOE)),
		BattleEvent.new(BattleEvent.Type.SEND_OUT, _who(Side.PLAYER))])

## Called by the battle screen for every replay step. The actions it passes are not used: both
## sides' choices come from [member rounds].
func submit_turn(_player_action: BattleAction, _foe_action: BattleAction = null) -> Array[BattleEvent]:
	var none: Array[BattleEvent] = []
	if _closed or is_finished():
		return none
	feed.append({})
	if rounds.is_empty():
		waiting = true
		idle.emit()
		return none
	waiting = false
	return _round(rounds.pop_front())

func _round(r: Variant) -> Array[BattleEvent]:
	var in0: Dictionary = r[0] if r is Array and (r as Array).size() == 2 and r[0] is Dictionary else {}
	var in1: Dictionary = r[1] if r is Array and (r as Array).size() == 2 and r[1] is Dictionary else {}
	var events: Array[BattleEvent] = super.submit_turn(LiveDuelSim.action_of(self, Side.PLAYER, in0), LiveDuelSim.action_of(self, Side.FOE, in1))
	# Like LiveDuelSim: a dropped Spirling of side 0 is followed by the next one standing.
	while needs_player_switch():
		events.append_array(submit_switch(swap_candidates(Side.PLAYER, switch_slot())[0]))
	played += 1
	return events

## 0 or 1 for the side that still stands, -1 while it runs or when nobody stands.
func winner() -> int:
	if not is_finished():
		return -1
	var a: int = alive_count(Side.PLAYER)
	var b: int = alive_count(Side.FOE)
	return 0 if a > 0 and b == 0 else (1 if b > 0 and a == 0 else -1)

## The duel is over on the server (given up, time ran out): the screen stops at its next step.
func close() -> void:
	_closed = true
	feed.clear()
