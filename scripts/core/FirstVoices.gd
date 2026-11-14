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
## Legendary Spirlings (not First Voices) met once at a fixed place, late in the story or after
## it. Same rules as the Voices: a missed meeting comes back after the next rest.
## "opens" starts the legend's lore quest (LegendQuests); the legend waits once the quest's
## betrayal is over ("after" = "lq_<legend>_ready").
const LEGENDS: Dictionary[String, Dictionary] = {
	"Hallowmur": {"region": "veydal", "map": "bellstone_ruins", "ring": 55, "opens": "story_complete", "after": "lq_hallowmur_ready"},
	"Scriptorax": {"region": "veydal", "map": "wren_library", "ring": 55, "opens": "story_complete", "after": "lq_scriptorax_ready"},
	"Zephyrel": {"region": "corvane", "map": "wide_rift_edge", "ring": 55, "opens": "story_complete", "after": "lq_zephyrel_ready"},
	"Monolurk": {"region": "ashmere", "map": "kiln_rift", "ring": 45, "opens": "rift_kiln_sealed", "after": "lq_monolurk_ready"},
	"Vorlucent": {"region": "ashmere", "map": "shade_rift", "ring": 48, "opens": "rift_shade_sealed", "after": "lq_vorlucent_ready"},
	"Lumivane": {"region": "solenne", "map": "sun_rift", "ring": 50, "opens": "rift_sun_sealed", "after": "lq_lumivane_ready"},
}

## Voice or legend entry for [param species], or {}.
static func entry(species: String) -> Dictionary:
	return VOICES.get(species, LEGENDS.get(species, {}))

static func away_flag(species: String) -> String:
	return "first_voice_%s_away" % species.to_lower()

static func bonded_flag(species: String) -> String:
	return "first_voice_%s_bonded" % species.to_lower()

## True if the player has a Spirling of this kind (team, storage or sanctuary). A copy bought
## in the shop does not count: the one met on the journey is still waiting to be bonded.
static func is_bonded(species: String) -> bool:
	for s: Spirling in GameState.party + GameState.storage + GameState.sanctuary:
		if s.data != null and s.data.species_name == species and not s.shop_bought:
			return true
	return false

## After a rest, every Voice that is not bonded waits at its place again.
static func after_rest() -> void:
	for v: String in VOICES.keys() + LEGENDS.keys():
		if not GameState.has_flag(bonded_flag(v)):
			GameState.set_flag(away_flag(v), false)

## True while the Voice can be met right now (after its story step, not away, not bonded).
static func waiting(species: String) -> bool:
	var v: Dictionary = entry(species)
	if v.is_empty():
		return false
	return GameState.has_flag(str(v.after)) and not GameState.has_flag(away_flag(species)) \
		and not GameState.has_flag(bonded_flag(species))
