class_name DayCycle
extends RefCounted
## Day and night (item 43) from the device clock. Outdoor maps get a soft tint, and some
## Spirlings come out more at night or in the half-light. Rooms, caves and Rifts stay as they are.
## Players can switch it off under Display and access.

enum Phase { DAWN, DAY, DUSK, NIGHT }
## Start hour of each phase (local time).
const STARTS: Dictionary[int, int] = {Phase.DAWN: 5, Phase.DAY: 7, Phase.DUSK: 18, Phase.NIGHT: 20}
const TINTS: Dictionary[int, Color] = {
	Phase.DAWN: Color(1.0, 0.93, 0.86),
	Phase.DAY: Color(1, 1, 1),
	Phase.DUSK: Color(1.0, 0.86, 0.76),
	Phase.NIGHT: Color(0.62, 0.68, 0.88),
}
## Elements that are met more often in each phase (same weighting as festivals).
const BOOSTS: Dictionary[int, Array] = {
	Phase.DAWN: [Elements.E.GALE],
	Phase.DAY: [],
	Phase.DUSK: [Elements.E.LUMEN],
	Phase.NIGHT: [Elements.E.UMBRA, Elements.E.LUMEN],
}

static func phase_for_hour(hour: int) -> Phase:
	var h: int = posmod(hour, 24)
	if h >= STARTS[Phase.NIGHT] or h < STARTS[Phase.DAWN]:
		return Phase.NIGHT
	if h >= STARTS[Phase.DUSK]:
		return Phase.DUSK
	if h >= STARTS[Phase.DAY]:
		return Phase.DAY
	return Phase.DAWN

static func current() -> Phase:
	return phase_for_hour(int(Time.get_time_dict_from_system().hour))

## The tint for a map: white indoors or when the option is off.
static func tint(outdoor: bool, phase: Phase, enabled: bool) -> Color:
	return TINTS[phase] if outdoor and enabled else Color(1, 1, 1)

## Encounter boost for a map: the festival's elements plus the phase's (outdoors only).
static func encounter_boost(festival: Array[int], outdoor: bool, phase: Phase, enabled: bool) -> Array[int]:
	var out: Array[int] = festival.duplicate()
	if outdoor and enabled:
		for e: Variant in BOOSTS[phase]:
			if not int(e) in out:
				out.append(int(e))
	return out
