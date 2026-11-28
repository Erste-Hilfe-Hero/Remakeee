class_name Funnel
extends RefCounted
## The first minutes of a journey for the dashboard (Chimora 1.3.2, Ali): each step once, as
## whole seconds of play since New Game, in the save under records.funnel. It goes to the server
## only inside the save, so it waits offline with the save and syncs with it, and it holds
## nothing but these numbers. The server only ever turns it into counts and medians per sign-up
## day (public.admin_funnel_start, the same path and privacy note as public.admin_funnel); no
## analytics SDK, no device id, no extra call.

const RECORD: String = "funnel"
## In the order a new Wayfarer reaches them.
const STEPS: Array[String] = ["new_game", "first_control", "first_wild", "first_catch", "story_start", "first_save"]

## Starts the record of a new journey at 0 s ([param records] is the fresh journey's records).
static func start(records: Dictionary) -> void:
	records[RECORD] = {"new_game": 0}

## Notes [param step] at [param seconds] of play, once. Journeys started before 1.3.2 have no
## record and get none, so their late "first" steps never count.
static func note(records: Dictionary, step: String, seconds: float) -> void:
	var f: Variant = records.get(RECORD)
	if not f is Dictionary or not step in STEPS or (f as Dictionary).has(step):
		return
	(f as Dictionary)[step] = maxi(int(seconds), 0)

## Notes [param step] for the journey being played.
static func mark(step: String) -> void:
	note(GameState.records, step, GameState.play_time)

## Seconds of [param step], or -1 while it is not reached.
static func at(records: Dictionary, step: String) -> int:
	var f: Variant = records.get(RECORD)
	return int((f as Dictionary).get(step, -1)) if f is Dictionary else -1
