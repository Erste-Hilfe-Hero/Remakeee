class_name PlayReminder
extends RefCounted
## Break reminder (plan area 8, item 3503): after MINUTES of play in one session the overworld
## shows one gentle note. It can be switched off in the settings (GameState.play_reminder).
## It never stops the game and never ties a reward to playing longer.

const MINUTES: int = 90

static var session_secs: float = 0.0
static var shown: bool = false

## Counts play time; returns the note once the session reaches MINUTES, else "".
static func tick(delta: float) -> String:
	if shown or not GameState.play_reminder:
		return ""
	session_secs += maxf(0.0, delta)
	if session_secs < MINUTES * 60.0:
		return ""
	shown = true
	return Loc.t("You have played for %d minutes. Maybe time for a short break?") % MINUTES

static func reset() -> void:
	session_secs = 0.0
	shown = false
