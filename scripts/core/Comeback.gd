class_name Comeback
extends RefCounted
## Welcome back (200 list item 139): after AWAY_DAYS or more days away a small gift waits in
## Goals (red dot, "Collect all"). Nothing is lost by staying away; there is no streak and no
## notification. One gift per return.

const AWAY_DAYS: int = 3
const GIFT_ITEM: String = "tonic"
const GIFT_COUNT: int = 3
const GIFT_COINS: int = 200
const LINE: String = "Welcome back! A small gift: %d Tonics and %d coins."

## Called when the journey opens on [param day]: notes the day and readies the gift after a break.
static func note_day(day: int) -> void:
	if GameState.last_play_day > 0 and day - GameState.last_play_day >= AWAY_DAYS:
		GameState.comeback_ready = true
	GameState.last_play_day = maxi(GameState.last_play_day, day)

static func pending() -> int:
	return 1 if GameState.comeback_ready else 0

## Pays the gift if one waits; the lines for the Goals message.
static func claim() -> Array[String]:
	if not GameState.comeback_ready:
		return []
	GameState.comeback_ready = false
	GameState.add_item(GIFT_ITEM, GIFT_COUNT)
	GameState.money += GIFT_COINS
	return [Loc.t(LINE) % [GIFT_COUNT, GIFT_COINS]]
