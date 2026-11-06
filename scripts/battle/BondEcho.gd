class_name BondEcho
extends RefCounted
## Pure rules for the bond minigame "Echo call" (tested without the scene).
## The wild Spirling calls a short sequence on three marks; the player echoes it back.
## Only the order counts, not split-second timing, and nothing shrinks toward a target.
## The score 0..1 feeds BondCalc as the bond's skill factor; it is shown only afterwards.

## Number of marks the Spirling can call on (diamond, square, triangle).
const MARKS: int = 3
const SEQUENCE_LENGTH: int = 4
## Seconds each mark lights while the Spirling calls, and the pause between marks.
const SHOW_TIME: float = 0.45
const GAP_TIME: float = 0.2
## Seconds the player has to echo the whole call.
const ECHO_TIME: float = 6.0

## Call length by rarity (item 285). Ancient kinds also call a second phase.
const CALL_LENGTH: Dictionary[String, int] = {"common": 4, "uncommon": 4, "shy": 5, "ancient": 5}
const SECOND_PHASE: Array[String] = ["ancient"]
## Near an unmended Rift the call is muted: only three marks, paler lights (item 280).
const MUTED_LENGTH: int = 3
## At a mended Rift the call is full again, at least four marks and a glowing frame (item 281).
const MENDED_MIN_LENGTH: int = 4
## Chance that a flawless echo is answered by a fifth "afterglow" mark (item 284).
const AFTERGLOW_CHANCE: float = 0.35
## Score when the afterglow is missed after a flawless echo (it never drops below "hesitates").
const AFTERGLOW_MISS: float = 0.9
## The result is shown only in words, never as a number (item 282, LEGAL.md).
const WORD_LISTENS: String = "It listens to you."
const WORD_HESITATES: String = "It hesitates."
const WORD_TURNS_AWAY: String = "It turns away."

## A fresh call. No mark repeats twice in a row, so every step is visible.
## [param motif] (the kind's "cry_motif") gives the first marks, so a kind always opens the same way.
static func make_sequence(rng: RandomNumberGenerator, length: int = SEQUENCE_LENGTH, motif: Array[int] = []) -> Array[int]:
	var out: Array[int] = []
	var last: int = -1
	for i: int in length:
		if i < motif.size() and motif[i] >= 0 and motif[i] < MARKS and motif[i] != last:
			out.append(motif[i])
			last = motif[i]
			continue
		var m: int = rng.randi_range(0, MARKS - 2)
		if m >= last and last >= 0:
			m += 1
		out.append(m)
		last = m
	return out

## Seconds the whole call takes to play.
static func call_duration(length: int = SEQUENCE_LENGTH) -> float:
	return length * SHOW_TIME + maxi(length - 1, 0) * GAP_TIME

## Index of the mark lit [param t] seconds into the call, or -1 during a gap or after it.
static func mark_at(sequence: Array[int], t: float) -> int:
	if t < 0.0:
		return -1
	var step: float = SHOW_TIME + GAP_TIME
	var i: int = int(floor(t / step))
	if i >= sequence.size() or t - i * step >= SHOW_TIME:
		return -1
	return sequence[i]

## True while the echo is still correct after the player's taps so far.
static func is_on_track(sequence: Array[int], taps: Array[int]) -> bool:
	if taps.size() > sequence.size():
		return false
	for i: int in taps.size():
		if taps[i] != sequence[i]:
			return false
	return true

## Score 0..1: the share of the call echoed correctly before the first mistake.
static func score(sequence: Array[int], taps: Array[int]) -> float:
	if sequence.is_empty():
		return 0.0
	var good: int = 0
	for i: int in mini(taps.size(), sequence.size()):
		if taps[i] != sequence[i]:
			break
		good += 1
	return float(good) / float(sequence.size())

## "none", "muted" (next to a Rift that is still open) or "mended" for a map.
static func rift_state(map_id: String, mended: Array) -> String:
	var rift: String = map_id.trim_suffix("_rift") if map_id.ends_with("_rift") else str(Spirling.ORIGIN_RIFTS.get(map_id, ""))
	if rift.is_empty():
		return "none"
	return "mended" if mended.has(rift) else "muted"

## Marks drawn as moon, star and spark instead of diamond, square and triangle (item 286).
## Only the look changes, never the rules.
static func uses_sky_marks(elements: Array) -> bool:
	return not elements.is_empty() and int(elements[0]) in [Elements.E.LUMEN, Elements.E.UMBRA]

## Number of marks in one phase of the call.
static func call_length(rarity: String, state: String = "none") -> int:
	var n: int = int(CALL_LENGTH.get(rarity, SEQUENCE_LENGTH))
	if state == "muted":
		return MUTED_LENGTH
	if state == "mended":
		return maxi(n, MENDED_MIN_LENGTH)
	return n

## The whole call for one Spirling: {"phases": [[marks]...], "afterglow": mark or -1,
## "state": rift state, "sky": bool, "element": int}. A second bond try in the same battle
## reuses the same plan, so learning the call pays off (item 283).
static func make_plan(rng: RandomNumberGenerator, sd: SpirlingData, state: String = "none") -> Dictionary:
	var rarity: String = sd.rarity if sd != null else "common"
	var motif: Array[int] = sd.cry_motif if sd != null else ([] as Array[int])
	var n: int = call_length(rarity, state)
	var phases: Array = [make_sequence(rng, n, motif)]
	if rarity in SECOND_PHASE:
		phases.append(make_sequence(rng, n))
	var afterglow: int = -1
	if rng.randf() < AFTERGLOW_CHANCE:
		var last: int = (phases[-1] as Array[int])[-1]
		afterglow = (last + 1 + rng.randi_range(0, MARKS - 2)) % MARKS
	var els: Array = sd.elements if sd != null else []
	return {"phases": phases, "afterglow": afterglow, "state": state,
		"sky": uses_sky_marks(els), "element": int(els[0]) if not els.is_empty() else 0}

## Score 0..1 for a whole plan. Each phase counts the same; a later phase is only reached
## after a flawless earlier one. A flawless echo stays at 1.0 when the afterglow is echoed too.
static func plan_score(plan: Dictionary, taps: Array, afterglow_tap: int = -1) -> float:
	var phases: Array = plan.get("phases", [])
	if phases.is_empty():
		return 0.0
	var total: float = 0.0
	for i: int in phases.size():
		var seq: Array[int] = []
		seq.assign(phases[i])
		var t: Array[int] = []
		if i < taps.size():
			t.assign(taps[i])
		total += score(seq, t)
	var out: float = total / phases.size()
	if out >= 1.0 and int(plan.get("afterglow", -1)) >= 0 and afterglow_tap != int(plan.afterglow):
		return AFTERGLOW_MISS
	return out

## The result in words (item 282): never a number or a chance.
static func result_words(value: float) -> String:
	if value >= AFTERGLOW_MISS:
		return WORD_LISTENS
	if value >= 0.5:
		return WORD_HESITATES
	return WORD_TURNS_AWAY
