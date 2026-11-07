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

const PHASE_NAMES: Array[String] = ["dawn", "day", "dusk", "night"]

## Signal holder: "phase_changed" fires when the time of day moves on (area 3 item 1167).
class Events extends RefCounted:
	signal phase_changed(phase: int)

static var events: Events = Events.new()
static var _last_phase: int = -1

static func phase_name(p: int) -> String:
	return PHASE_NAMES[clampi(p, 0, PHASE_NAMES.size() - 1)]

## Checks the clock (or [param now]); emits phase_changed and returns true when the phase moved.
static func poll(now: int = -1) -> bool:
	var p: int = current() if now < 0 else now
	if p == _last_phase:
		return false
	var first: bool = _last_phase < 0
	_last_phase = p
	if not first:
		events.phase_changed.emit(p)
	return not first

## True if [param def] (an NPC, sign or block) has no "phase_only" or lists [param phase].
static func shows_at(def: Dictionary, phase: int) -> bool:
	if not def.has("phase_only"):
		return true
	var only: Variant = def.phase_only
	var name: String = phase_name(phase)
	return name in only if only is Array else str(only) == name

## Weekday by the device clock plus the bench shift: 0 Sunday .. 6 Saturday (area 3 item 959).
static func weekday(unix: int = -1) -> int:
	# Without [param unix], the device's local time (time zone bias in minutes).
	var t: int = unix if unix >= 0 else int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	t += shift() * 3600
	return int(Time.get_datetime_dict_from_unix_time(t).weekday)

## True if [param def] has no "weekdays" list or lists [param wd] (0 Sunday .. 6 Saturday).
static func on_weekday(def: Dictionary, wd: int) -> bool:
	if not def.has("weekdays"):
		return true
	for d: Variant in def.weekdays:
		if int(d) == wd:
			return true
	return false

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
	return phase_for_hour(int(Time.get_time_dict_from_system().hour) + shift())

## Hours the game clock runs ahead of the device clock (0-23). Sitting on a bench moves it on
## to the next time of day (area 3 item 935); it is kept in the save under records.
static func shift() -> int:
	return posmod(int(GameState.records.get("clock_shift", 0)), 24)

## Whole hours from [param hour] until the next phase starts (1-24).
static func hours_to_next(hour: int) -> int:
	var now: Phase = phase_for_hour(hour)
	for d: int in range(1, 25):
		if phase_for_hour(hour + d) != now:
			return d
	return 24

## Moves the game clock on to the start of the next phase and returns that phase.
## [param device_hour] defaults to the device clock; tests pass it in.
static func skip_to_next(device_hour: int = -1) -> Phase:
	var h: int = (device_hour if device_hour >= 0 else int(Time.get_time_dict_from_system().hour)) + shift()
	GameState.records["clock_shift"] = posmod(shift() + hours_to_next(h), 24)
	return phase_for_hour(h + hours_to_next(h))

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
