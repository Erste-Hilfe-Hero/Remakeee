class_name FirstVoices
extends RefCounted
## The First Voices (plan area 1, items 152-155): six ancient Spirlings whose song once held
## the land together; their silence let the Hush fall. Each is met once at a fixed place.
## A meeting that ends without a bond is never lost: the Voice rests and returns after the
## player's next rest (flag "first_voice_<id>_away" cleared by after_rest()).

## Voice -> where it waits. Only Velahra is in the game so far (Veydal); the others belong to
## regions that are not playable yet and are named in docs/WORLD.md.
const VOICES: Dictionary[String, Dictionary] = {
	"Velahra": {"region": "veydal", "map": "brindlewick", "ring": 40, "after": "mirela_lamp"},
}

static func away_flag(species: String) -> String:
	return "first_voice_%s_away" % species.to_lower()

static func bonded_flag(species: String) -> String:
	return "first_voice_%s_bonded" % species.to_lower()

## True if the player has a Spirling of this kind (team, storage or sanctuary).
static func is_bonded(species: String) -> bool:
	for s: Spirling in GameState.party + GameState.storage + GameState.sanctuary:
		if s.data != null and s.data.species_name == species:
			return true
	return false

## After a rest, every Voice that is not bonded waits at its place again.
static func after_rest() -> void:
	for v: String in VOICES:
		if not GameState.has_flag(bonded_flag(v)):
			GameState.set_flag(away_flag(v), false)

## True while the Voice can be met right now (after its story step, not away, not bonded).
static func waiting(species: String) -> bool:
	var v: Dictionary = VOICES.get(species, {})
	if v.is_empty():
		return false
	return GameState.has_flag(str(v.after)) and not GameState.has_flag(away_flag(species)) \
		and not GameState.has_flag(bonded_flag(species))
