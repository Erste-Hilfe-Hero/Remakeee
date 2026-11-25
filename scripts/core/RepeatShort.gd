class_name RepeatShort
extends RefCounted
## Long animations play shorter from the second time they are seen in a session (200 list item
## 55): the same art's effect, the unfurl moment. Kept in memory only, so every new session shows
## each animation once at full length.

## Speed factor for an animation already seen this session.
const REPEAT_SPEED: float = 1.6

static var _seen: Dictionary[String, bool] = {}

## Speed factor for the animation [param key]: 1.0 the first time this session, REPEAT_SPEED after.
## Marks it as seen.
static func speed(key: String) -> float:
	if _seen.has(key):
		return REPEAT_SPEED
	_seen[key] = true
	return 1.0

## Forgets every seen animation (tests).
static func reset() -> void:
	_seen.clear()
