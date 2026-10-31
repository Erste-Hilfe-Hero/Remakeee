class_name BondTiming
extends RefCounted
## Pure scoring for the bond rhythm minigame (tested without the scene).
## Each pulse ring shrinks toward the target ring; a tap scores by how close the ring is.

const DURATION: float = 5.0
const FIRST_PULSE: float = 0.3
const PULSE_INTERVAL: float = 0.8
const START_RADIUS: float = 48.0
const TARGET_RADIUS: float = 10.0
## Seconds a ring takes to reach the target radius.
const SHRINK_TIME: float = 0.9
## Radius error at which a tap scores 0.
const TOLERANCE: float = 12.0

## Spawn times of all pulses inside the window.
static func pulse_times() -> Array[float]:
	var out: Array[float] = []
	var t: float = FIRST_PULSE
	while t + SHRINK_TIME <= DURATION:
		out.append(t)
		t += PULSE_INTERVAL
	return out

## Ring radius [param age] seconds after it spawned (keeps shrinking past the target).
static func radius_at(age: float) -> float:
	var speed: float = (START_RADIUS - TARGET_RADIUS) / SHRINK_TIME
	return START_RADIUS - speed * age

## Score 0..1 for one tap at ring radius [param radius].
static func tap_score(radius: float) -> float:
	return clampf(1.0 - absf(radius - TARGET_RADIUS) / TOLERANCE, 0.0, 1.0)

## Final timing score: hit scores summed over (pulses + stray taps), so mashing does not pay.
static func final_score(hit_scores: Array[float], pulse_count: int, stray_taps: int) -> float:
	var total: float = 0.0
	for s: float in hit_scores:
		total += s
	var denom: int = maxi(pulse_count + stray_taps, 1)
	return clampf(total / float(denom), 0.0, 1.0)
