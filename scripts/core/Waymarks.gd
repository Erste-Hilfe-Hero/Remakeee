class_name Waymarks
extends RefCounted
## Waymarks (plan area 8): the endgame currency that is only earned by playing.
## Every credit goes through earn(), which caps the pouch at CAP and keeps a short log in
## GameState.records["waymark_log"]. Waymarks can never be bought, traded or sent to friends:
## there is no shop price, no gift kind and no trade path for them (see docs/MONETIZATION.md).

const CAP: int = 9999
const LOG_MAX: int = 200
## Waymarks are never sold, traded or gifted. Code that moves value between players or sells
## anything must check this and refuse Waymarks (tests/unit/test_waymarks.gd keeps it false).
const TRANSFERABLE: bool = false
## Valid sources for earn(). New reward paths add their id here.
const SOURCES: Array[String] = [
	"daily_task", "daily_bonus", "weekly", "tower", "achievement", "collection",
	"festival", "season_path", "master", "echo_path", "expedition", "album",
]
## Shown in text next to the number: a small waystone glyph in PixelFont.
const GLYPH: String = ""

static func balance() -> int:
	return GameState.waymarks

## Credits [param amount] Waymarks from [param source] (one of SOURCES).
## Returns {"gained": int, "lost": int}; "lost" is what did not fit under CAP.
static func earn(amount: int, source: String) -> Dictionary:
	var out: Dictionary = {"gained": 0, "lost": 0}
	if amount <= 0:
		return out
	if not source in SOURCES:
		push_warning("Waymarks: unknown source '%s'" % source)
		return out
	var room: int = maxi(0, CAP - GameState.waymarks)
	out.gained = mini(amount, room)
	out.lost = amount - int(out.gained)
	GameState.waymarks += int(out.gained)
	var entries: Array = GameState.records.get("waymark_log", [])
	entries.append({"src": source, "n": int(out.gained), "lost": int(out.lost), "date": Time.get_date_string_from_unix_time(Online.unix_now())})
	while entries.size() > LOG_MAX:
		entries.pop_front()
	GameState.records["waymark_log"] = entries
	GameState.records["waymarks_total"] = int(GameState.records.get("waymarks_total", 0)) + int(out.gained)
	return out

## Spends [param amount] Waymarks (the exchange stand). Returns false if there are not enough.
static func spend(amount: int) -> bool:
	if amount < 0 or GameState.waymarks < amount:
		return false
	GameState.waymarks -= amount
	return true

## "+10 Waymarks" (translated), for reward messages.
static func gain_text(n: int) -> String:
	return Loc.t("+%d Waymarks") % n if n != 1 else Loc.t("+1 Waymark")

## Reward lines for an earn() result: the gain, plus a note if the pouch overflowed.
static func reward_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if int(result.get("gained", 0)) > 0:
		lines.append(gain_text(int(result.gained)))
	if int(result.get("lost", 0)) > 0:
		lines.append(Loc.t("Your waymark pouch is full (%d). %d Waymarks were lost.") % [CAP, int(result.lost)])
	return lines

## Short label for the menu title: glyph and amount.
static func label() -> String:
	return "%s%d" % [GLYPH, GameState.waymarks]
