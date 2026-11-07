class_name FishTrap
extends RefCounted
## Fish traps on the Reedhaven jetty (area 3 item 964). Each trap can be emptied once a day
## (by the device date); it holds a remedy or a few coins. The day each trap was last emptied
## is kept in GameState.records["fish_traps"].

const COINS := 200
const ITEM := "remedy"

## What trap [param id] holds on [param day] ("YYYY-MM-DD"): {"item": id} or {"money": n},
## or {} when it was already emptied that day.
static func catch(id: String, day: String) -> Dictionary:
	var done: Dictionary = GameState.as_dict(GameState.records.get("fish_traps", {}))
	if str(done.get(id, "")) == day:
		return {}
	return {"item": ITEM} if (id + day).hash() % 2 == 0 else {"money": COINS}

## Marks trap [param id] as emptied on [param day].
static func empty(id: String, day: String) -> void:
	var done: Dictionary = GameState.as_dict(GameState.records.get("fish_traps", {})).duplicate()
	done[id] = day
	GameState.records["fish_traps"] = done
