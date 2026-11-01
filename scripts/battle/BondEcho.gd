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

## A fresh call. No mark repeats twice in a row, so every step is visible.
static func make_sequence(rng: RandomNumberGenerator, length: int = SEQUENCE_LENGTH) -> Array[int]:
	var out: Array[int] = []
	var last: int = -1
	for i: int in length:
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
