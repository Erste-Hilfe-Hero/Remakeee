class_name Opening
extends RefCounted
## The opening of a new journey (Chimora 1.3.2, Ali's final order): no text before the first
## step. After the boot card the Wayfarer stands in the ferns of Fernstair and walks at once.
## The first step into the ferns meets the three Spirlings of the storm: one is picked and
## bonded with Mine!, which is the bonding tutorial (only the small hint on the button). Aldo
## saw it, walks over and hands over the map book (lighthouse/aldo), the game saves, and the
## Wayfarer walks south to Brindlewick. There the story goes on: the storm night (scene
## "prologue"), look and name (the default name until then), the first goal and the menu tip.
## Old saves never have ON_FLAG, so nothing changes for them. Every story flag stays.

## Set at New Game: this journey starts with the opening.
const ON_FLAG: String = "opening"
## Set once the story went on in the village.
const VILLAGE_FLAG: String = "village_story"
const MAP: String = "fernstair"
## Ferns on three sides and a cliff behind: any first step is a step into the ferns.
const CELL: Vector2i = Vector2i(6, 17)
const FACING: String = "down"
const VILLAGE_MAP: String = "brindlewick"
## The storm Spirlings show up at the latest on this step, ferns or not.
const MEET_STEPS: int = 3
const MEET_LINE: String = "Three small lights peek out of the ferns: Spirlings from the storm!"
const ALDO_LINE: String = "Aldo: I saw that from the path! That one chose you."
## Aldo comes up the path from the village and goes back down it.
const ALDO_ID: String = "opening_aldo"
const ALDO_SPRITE: String = "elder"
const ALDO_FROM_Y: int = 21

## True while the opening runs: from New Game until the story went on in the village.
static func active(flags: Dictionary) -> bool:
	return bool(flags.get(ON_FLAG, false)) and not bool(flags.get(VILLAGE_FLAG, false))

## True until the storm Spirlings were met and one bonded.
static func meet_due(flags: Dictionary) -> bool:
	return active(flags) and not bool(flags.get("got_starter", false))

## True when this step meets the storm Spirlings: a step into the ferns, or step MEET_STEPS.
static func meet_now(flags: Dictionary, wild_tile: bool, steps: int) -> bool:
	return meet_due(flags) and (wild_tile or steps >= MEET_STEPS)

## True on the way to the village after the bond: no wild Spirlings, no Wayfarer battles, no
## goal line and no tips, so the walk stays a walk.
static func quiet(flags: Dictionary) -> bool:
	return active(flags)

## True when arriving on [param map_id] lets the story go on.
static func village_due(flags: Dictionary, map_id: String) -> bool:
	return active(flags) and bool(flags.get("got_starter", false)) and map_id == VILLAGE_MAP

## Starts the opening for a fresh journey (GameState.new_game without a partner).
static func begin() -> void:
	GameState.set_flag(ON_FLAG)
	GameState.current_map = MAP
	GameState.player_cell = CELL
	GameState.facing = FACING
