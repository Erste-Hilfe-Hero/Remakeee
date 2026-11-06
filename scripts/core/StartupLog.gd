class_name StartupLog
## Startup time (plan item 2128): milliseconds from app start to each stage, written once per
## stage to the log, e.g. "Startup: title menu ready after 1840 ms (goal 3000 ms)". The goal
## is under 3 s to a usable title menu on a mid-range Android phone. No analytics: the line
## only goes to the device log (adb logcat, browser console).

const GOAL_MS: int = 3000

static var _seen: Dictionary = {}

## Logs [param stage] the first time it is reached; returns the line ("" when already logged).
static func mark(stage: String, now_ms: int = -1) -> String:
	if _seen.has(stage):
		return ""
	var ms: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	_seen[stage] = ms
	var line: String = line_for(stage, ms)
	print(line)
	return line

static func line_for(stage: String, ms: int) -> String:
	var note: String = "" if ms <= GOAL_MS else ", slower than the goal"
	return "Startup: %s after %d ms (goal %d ms%s)" % [stage, ms, GOAL_MS, note]

## Milliseconds when [param stage] was logged, or -1 (tests).
static func at(stage: String) -> int:
	return int(_seen.get(stage, -1))

## Forgets all stages (tests).
static func reset() -> void:
	_seen.clear()
