class_name LiveDuel
extends RefCounted
## Live duels between friends (Online 100, area 1): rules shared by the game and LocalBackend.
## The server does the same in 20261111000040_live_duel.sql from server_config.live_duel.

const CONFIG_PATH: String = "res://data/live_duel.json"
## Set emotes, by number (the server only stores the number, never text).
const EMOTES: Array[String] = ["Hello!", "Good luck!", "Well played!", "Nice move!", "Oops!", "Thanks!",
	"Wow!", "Not bad.", "Is that all?", "Watch this.", "Close one!", "Good game!"]

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## The pick as distinct whole indexes into the shown team, exactly [param need] of them, or null.
static func check_pick(pick: Variant, shown: int, need: int) -> Variant:
	if not pick is Array or (pick as Array).size() != need:
		return null
	var out: Array = []
	for p: Variant in pick:
		if not (p is int or p is float) or float(p) != floorf(float(p)):
			return null
		var i: int = int(p)
		if i < 0 or i >= shown or out.has(i):
			return null
		out.append(i)
	return out

## Seconds left on the turn clock (never below 0).
static func seconds_left(deadline: int, now: int) -> int:
	return maxi(0, deadline - now)

static func emote_text(n: int) -> String:
	return Loc.t(EMOTES[n]) if n >= 0 and n < EMOTES.size() else ""

## Battle summary (point 10): one line per Spirling with the damage it took.
static func summary(names: Array, start_hp: Array, end_hp: Array) -> Array[String]:
	var out: Array[String] = []
	for i: int in names.size():
		var taken: int = maxi(0, int(start_hp[i]) - int(end_hp[i]))
		out.append(Loc.t("%s took %d damage") % [str(names[i]), taken])
	return out

## What the result screen says, from the duel's side, winner and reason.
static func result_text(side: int, winner: int, reason: String) -> String:
	if reason == "disputed":
		return Loc.t("The referee could not play this duel again. It does not count.")
	if winner < 0:
		return Loc.t("Draw") if reason == "played" else Loc.t("The duel ended without a winner.")
	var won: bool = winner == side
	match reason:
		"forfeit": return Loc.t("Your friend gave up. You win!") if won else Loc.t("You gave up.")
		"timeout": return Loc.t("Your friend did not come back in time. You win!") if won else Loc.t("You were away too long. You lose.")
	return Loc.t("You win!") if won else Loc.t("You lose.")
