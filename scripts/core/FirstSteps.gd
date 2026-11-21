class_name FirstSteps
extends RefCounted
## "First steps" for new players (plan item 1995): five things a new Wayfarer does once.
## Each step ticks itself off by a world flag; the row leaves Goals when all are done or once
## the player is no longer a newcomer.

## [flag, text] in the order a new player meets them. "menu_opened" is VirtualPad.MENU_SEEN_FLAG.
const STEPS: Array[Array] = [
	["menu_opened", "Open the menu"],
	["fs_saved", "Save your journey"],
	["fs_team", "Look at your team"],
	["fs_rest", "Rest at a rest spot"],
	["fs_spirlog", "Open the Spirlog"],
]
const SAVED: String = "fs_saved"
const TEAM: String = "fs_team"
const REST: String = "fs_rest"
const SPIRLOG: String = "fs_spirlog"
## Queued as a notice when the last step is ticked.
const DONE_LINE: String = "First steps done. The valley stops holding your hand now."

static func done_count(flags: Dictionary) -> int:
	var n: int = 0
	for s: Array in STEPS:
		if bool(flags.get(s[0], false)):
			n += 1
	return n

static func all_done(flags: Dictionary) -> bool:
	return done_count(flags) == STEPS.size()

## True while Goals should list the steps.
static func shows(flags: Dictionary, newcomer: bool) -> bool:
	return newcomer and not all_done(flags)

## The first step not yet done, or "".
static func next_step(flags: Dictionary) -> String:
	for s: Array in STEPS:
		if not bool(flags.get(s[0], false)):
			return str(s[1])
	return ""

## The Goals row: progress in the text, the next step as hint, the checklist as detail.
static func row(flags: Dictionary) -> Dictionary:
	var lines: PackedStringArray = [Loc.t("First steps")]
	for s: Array in STEPS:
		lines.append(("[x] " if bool(flags.get(s[0], false)) else "[ ] ") + Loc.t(str(s[1])))
	return {"text": "First steps %d/%d" % [done_count(flags), STEPS.size()],
		"hint": Loc.t(next_step(flags)), "detail": "\n".join(lines)}

## Ticks [param flag] off. Returns true (and queues DONE_LINE) when this finished the list.
static func tick(flag: String) -> bool:
	var before: bool = all_done(GameState.flags)
	GameState.set_flag(flag)
	if before or not all_done(GameState.flags):
		return false
	GameState.notices.append(DONE_LINE)
	return true
