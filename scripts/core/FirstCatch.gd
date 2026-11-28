class_name FirstCatch
extends RefCounted
## The first five minutes (Chimora 1.3.2, Ali): a new Wayfarer bonds soon. The first step into
## ferns, reeds or scree on a map with wild Spirlings always meets one, picked so the partner
## can wear it down without knocking it out at once; that battle opens with the bonding tip.
## The first wild bond gives a small gift with a toast and lets the First Catch Pack note open
## once back in the world (ShopScreen.first_catch_popup_now). The bond chance is not touched.

## Set once the guaranteed first wild Spirling stepped out.
const MET_FLAG: String = "first_wild_met"
## Set at the first wild bond of the journey.
const BOND_FLAG: String = "first_bond_done"
## Battle model meta of the guaranteed first wild battle (BattleScene shows the bonding tip).
const META: String = "first_wild"
## Only the commonest kinds step out first: they bond most easily.
const RARITY: String = "common"
## The gift after the first bond: item id -> count.
const GIFT: Dictionary[String, int] = {"kin_charm": 5, "tonic": 2}
const GIFT_LINE: String = "First bond! A gift for the road: %s."
## Limits from the first free step (tests/unit/test_first_catch.gd measures the real route and
## texts in en, de, ru and ja). Steps: lighthouse, Brindlewick, Kestra in the Map House, north to
## the first fern of Fernstair; 34 in 1.3.2, plus 2 for a villager who wanders onto the shortest
## way (about 10 s of walking). Text boxes: the most of the four languages in 1.3.2 (German),
## 18 before the first wild battle and 29 until the bond is tried (before 1.3.2: 36 and a random
## encounter). With the 10 boxes before the first step (Overworld.START_TEXT_BOXES) and one short
## battle the first bond lands inside the first five minutes.
const STEPS: int = 36
const WILD_TEXT_BOXES: int = 18
const TEXT_BOXES: int = 29

## True when this step should meet the guaranteed first wild Spirling.
static func due(flags: Dictionary) -> bool:
	return not bool(flags.get(MET_FLAG, false)) and not bool(flags.get(BOND_FLAG, false))

## Weakest multiplier between [param a] and [param b] both ways: 1.0 means neither hits the
## other extra hard.
static func matchup(a: Array[int], b: Array[int]) -> float:
	var worst: float = 0.0
	for e: int in a:
		worst = maxf(worst, Elements.multiplier(e, b))
	for e: int in b:
		worst = maxf(worst, Elements.multiplier(e, a))
	return worst

## The species that steps out first on table [param id] and [param ground] against
## [param lead_elements]: a common kind with no strong matchup either way and the best bond
## rate; without one, the common kind with the mildest matchup. "" when the table has none.
static func pick_species(id: String, ground: String, lead_elements: Array[int]) -> String:
	var best: String = ""
	var best_key: Array = []
	for s: Dictionary in EncounterTable.spawns_on(id, ground):
		var sd: SpirlingData = Database.species(str(s.species))
		if sd == null or sd.rarity != RARITY:
			continue
		var key: Array = [-matchup(lead_elements, sd.elements), sd.bond_rate]
		if best.is_empty() or key > best_key:
			best = sd.species_name
			best_key = key
	return best

## The guaranteed first wild Spirling at the table's lowest Ring, or null.
static func make_wild(id: String, ground: String, lead: Spirling, rng: RandomNumberGenerator) -> Spirling:
	var own: Array[int] = []
	if lead != null:
		own = lead.elements()
	var sp: String = pick_species(id, ground, own)
	if sp.is_empty():
		return null
	var ring: int = 99
	for s: Dictionary in EncounterTable.spawns_on(id, ground):
		if str(s.species) == sp:
			ring = mini(ring, int(s.get("min", 2)))
	return Spirling.new(Database.species(sp), ring, rng)

## True when [param bonded] is the journey's first wild bond: no flag yet and nothing but the
## partner in [param owned] (team, storage, sanctuary before the new one joins).
static func is_first_bond(flags: Dictionary, owned: Array, starter: String) -> bool:
	if bool(flags.get(BOND_FLAG, false)):
		return false
	for s: Spirling in owned:
		if s.data != null and s.data.species_name != starter:
			return false
	return true

## The gift's toast line, in the player's language.
static func gift_line() -> String:
	var parts: PackedStringArray = []
	for id: String in GIFT:
		parts.append("%s x%d" % [Loc.t(str(Database.item(id).get("name", id))), GIFT[id]])
	return Loc.t(GIFT_LINE) % ", ".join(parts)

## Marks the first bond, adds the gift and returns its toast line ("" when it was not the first).
static func on_bond() -> String:
	if GameState.has_flag(BOND_FLAG):
		return ""
	GameState.set_flag(BOND_FLAG)
	GameState.set_flag(MET_FLAG)
	for id: String in GIFT:
		GameState.add_item(id, GIFT[id])
	return gift_line()
