class_name SaveBirthday
extends RefCounted
## Journey birthday (200 list item 147): each full year since the journey started
## (GameState.start_day) a gift waits in Goals (red dot, "Collect all"), like the welcome-back
## gift (Comeback). One gift per birthday; a birthday missed while away is not paid twice.

const YEAR_DAYS: int = 365
const GIFT_ITEM: String = "growth_charm"
const GIFT_COUNT: int = 1
const GIFT_COINS: int = 1000
const LINE_FIRST: String = "Your journey is one year old today! A birthday gift: a Growth Charm and %d coins."
const LINE_MORE: String = "Your journey is %d years old today! A birthday gift: a Growth Charm and %d coins."

## Full years since the journey started, on [param day] (GameState.today when -1).
static func years(day: int = -1) -> int:
	var d: int = GameState.today() if day < 0 else day
	if GameState.start_day <= 0 or d <= GameState.start_day:
		return 0
	return (d - GameState.start_day) / YEAR_DAYS

static func pending(day: int = -1) -> int:
	return 1 if years(day) > GameState.birthdays_paid else 0

## Pays the gift if a birthday waits; the lines for the Goals message.
static func claim(day: int = -1) -> Array[String]:
	var y: int = years(day)
	if y <= GameState.birthdays_paid:
		return []
	GameState.birthdays_paid = y
	GameState.add_item(GIFT_ITEM, GIFT_COUNT)
	GameState.money += GIFT_COINS
	if y == 1:
		return [Loc.t(LINE_FIRST) % GIFT_COINS]
	return [Loc.t(LINE_MORE) % [y, GIFT_COINS]]
