class_name MenuDots
extends RefCounted
## Item 1872: start menu rows with something new carry a dot. Friends when Lantern Mail
## came in, Records after a new badge, Goals when the story names a new goal, the Spirlog
## after a new kind was seen. Opening the row takes its dot away.
## GameState.menu_seen keeps, per row, what the player last saw there.

const LABELS: Array[String] = ["Goals", "Friends", "Records", "Spirlog"]

## Unopened Lantern Mail as last asked from the server (refresh_mail).
static var mail_unread: int = 0

## What a row stands for now: a count for most, the story step's hash for Goals.
static func value(label: String) -> int:
	match label:
		"Goals":
			return str(QuestLog.summary(GameState.flags)).hash()
		"Friends":
			return mail_unread
		"Records":
			return Achievements.unlocked().size()
		"Spirlog":
			var n: int = 0
			for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
				if SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
					n += 1
			return n
	return 0

## True if [param label] has something the player hasn't looked at yet.
static func has_new(label: String) -> bool:
	if not label in LABELS or not GameState.menu_seen.has(label):
		return false
	var seen: int = int(GameState.menu_seen[label])
	var now: int = value(label)
	return now != seen if label == "Goals" else now > seen

## Rows without a record yet start from what is there now, so an old save shows no dots.
static func baseline() -> void:
	for l: String in LABELS:
		if not GameState.menu_seen.has(l):
			GameState.menu_seen[l] = value(l)

static func mark_seen(label: String) -> void:
	if label in LABELS:
		GameState.menu_seen[label] = value(label)

## The rows of [param labels] that get a dot.
static func dotted(labels: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for l: String in labels:
		if has_new(l):
			out.append(l)
	return out

## Asks the server how much Lantern Mail is unopened, without waiting for it: the dot
## shows the next time the menu opens.
static func refresh_mail() -> void:
	if not Online.is_online():
		return
	var r: Dictionary = await Online.call_fn("mail_list")
	if bool(r.get("ok", false)) and r.get("data") is Array:
		var n: int = 0
		for m: Variant in r.data:
			if m is Dictionary and not bool((m as Dictionary).get("opened", false)):
				n += 1
		mail_unread = n
