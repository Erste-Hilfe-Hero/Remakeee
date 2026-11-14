class_name ChallengeRules
extends RefCounted
## Selectable challenge rules (plan item 1112 and KAMPF_PLAN_1000 items 485-520), kept in
## GameState.records["challenges"]. The four first rules live in data/ideas200.json
## "challenges", the newer modes in data/challenge_modes.json. Any set of them combines; they are
## taken at a new game or before the first mended Rift and can be dropped at any time. The checks
## are pure so the party, bag, shop, battle and Warden code can ask them. No rule is ever sold.

const KEY: String = "challenges"
const MODES_PATH: String = "res://data/challenge_modes.json"
## The run seed behind Shuffled Wilds and Shuffled Arts (items 490, 491, 508, 509).
const SEED_KEY: String = "challenge_seed"
## Wins and losses while at least one rule is on (item 504).
const STATS_KEY: String = "challenge_stats"
## Places where a bond formed / a wild battle was already fought (items 486, 487).
const BONDS_KEY: String = "challenge_bonds"
const MET_KEY: String = "challenge_met"
## Set once a rule is dropped mid-run; the stats then say so.
const DROPPED_KEY: String = "challenges_dropped"
## Lowest difficulty this run was ever set to (item 494).
const FLOOR_KEY: String = "difficulty_floor"
## Letters of a shareable seed code (no 0/O or 1/I, so it reads well aloud).
const CODE_LETTERS: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const CODE_LENGTH: int = 7
## Story difficulty (item 497): foes land critical hits half as often, battles give 20% more Growth.
const FOE_CRIT: Array[float] = [0.5, 1.0, 1.0, 1.0]
const GROWTH: Array[float] = [1.2, 1.0, 1.0, 1.0]
## Foe scaling (item 496, an option per journey): Wayfarer Spirlings stand at least this many
## rings below the party's strongest, never above the ring cap plus GameState.FOE_OVER_CAP.
const SCALING_KEY: String = "foe_scaling"
const SCALING_GAP: int = 2
## Rift-Born foes (item 500) know arts up to this many rings ahead to fill all four slots.
const RIFT_BORN_ART_REACH: int = 10

static var _list: Array = []
static var _wild_pool: Dictionary = {}
static var _art_pool: Array[MoveData] = []
## Lowest ring at which some Spirling learns each art in _art_pool.
static var _art_ring: Dictionary = {}

static func list() -> Array:
	if _list.is_empty():
		_list = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas200.json"))).get("challenges", []).duplicate()
		_list.append_array(GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(MODES_PATH))).get("modes", []))
	return _list

static func ids() -> Array[String]:
	var out: Array[String] = []
	for c: Variant in list():
		out.append(str((c as Dictionary).id))
	return out

static func find(id: String) -> Dictionary:
	for c: Variant in list():
		if str((c as Dictionary).id) == id:
			return c
	return {}

static func active(id: String) -> bool:
	return id in GameState.records.get(KEY, [])

## The rules that are on, in list order.
static func active_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		if active(id):
			out.append(id)
	return out

static func any_active() -> bool:
	return not active_ids().is_empty()

static func toggle(id: String) -> void:
	if not id in ids():
		return
	var cur: Array = (GameState.records.get(KEY, []) as Array).duplicate()
	if id in cur:
		cur.erase(id)
	else:
		cur.append(id)
	GameState.records[KEY] = cur

## Rules can be taken before the first Rift is mended (like the Iron Oath).
static func can_take() -> bool:
	return GameState.rifts_sealed.is_empty()

## Takes [param id] when allowed. Returns false if it is unknown, on, or too late.
static func take(id: String) -> bool:
	if not id in ids() or active(id) or not can_take():
		return false
	toggle(id)
	ensure_seed()
	return true

## Drops [param id] at any time; the run's stats remember that a rule was dropped.
static func drop(id: String) -> bool:
	if not active(id):
		return false
	toggle(id)
	GameState.records[DROPPED_KEY] = true
	return true

## Short names of the rules that are on ("One per Place, Night Bonds"), translated.
static func names() -> String:
	var out: PackedStringArray = []
	for id: String in active_ids():
		out.append(Loc.t(str(find(id).get("name", id))))
	return ", ".join(out)

# --- Seed -----------------------------------------------------------------------------------

## The run seed, made once from the game's RNG.
static func ensure_seed() -> int:
	if not GameState.records.has(SEED_KEY):
		GameState.records[SEED_KEY] = GameState.rng.randi() % code_space()
	return run_seed()

static func run_seed() -> int:
	return int(GameState.records.get(SEED_KEY, 0))

static func set_seed(value: int) -> void:
	GameState.records[SEED_KEY] = posmod(value, code_space())

static func code_space() -> int:
	return int(pow(CODE_LETTERS.length(), CODE_LENGTH))

## The seed as a short code friends can type or paste ("K7Q2MZA").
static func seed_code(value: int) -> String:
	var v: int = posmod(value, code_space())
	var out: String = ""
	for i: int in CODE_LENGTH:
		out = CODE_LETTERS[v % CODE_LETTERS.length()] + out
		v /= CODE_LETTERS.length()
	return out

## The seed in [param code], or -1 when it is not a valid code (spaces and case do not matter).
static func parse_code(code: String) -> int:
	var c: String = code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if c.length() != CODE_LENGTH:
		return -1
	var v: int = 0
	for ch: String in c:
		var d: int = CODE_LETTERS.find(ch)
		if d < 0:
			return -1
		v = v * CODE_LETTERS.length() + d
	return v

## True while a rule that uses the seed is on.
static func uses_seed() -> bool:
	return active("wild_shuffle") or active("art_shuffle")

# --- Bonds and wilds ------------------------------------------------------------------------

## One Colour: may [param sd] join, given the starter's species data [param starter]?
static func may_join(sd: SpirlingData, starter: SpirlingData) -> bool:
	if not active("one_element") or starter == null:
		return true
	for e: int in sd.elements:
		if e in starter.elements:
			return true
	return false

## Why no bond can form in this wild battle on [param map_id] with [param foes] ("" when it can).
## Call before note_wild_battle, which books the meeting.
static func bond_block(map_id: String, foes: Array, night: bool) -> String:
	if active("one_per_place") and map_id in (GameState.records.get(BONDS_KEY, []) as Array):
		return "One per Place: a Spirling from here already walks with you."
	if active("first_meeting") and map_id in (GameState.records.get(MET_KEY, []) as Array):
		return "First Meeting: only the first wild battle here could end in a bond."
	if active("night_bonds") and not night:
		return "Night Bonds: no bond forms before dark."
	if active("one_element"):
		var starter: SpirlingData = Database.species(GameState.starter)
		for f: Variant in foes:
			if f is Spirling and not may_join((f as Spirling).data, starter):
				return "One Colour: this Spirling shares no element with your partner."
	return ""

static func _book(key: String, map_id: String) -> void:
	var l: Array = (GameState.records.get(key, []) as Array).duplicate()
	if not map_id.is_empty() and not map_id in l:
		l.append(map_id)
		GameState.records[key] = l

static func note_wild_battle(map_id: String) -> void:
	if active("first_meeting"):
		_book(MET_KEY, map_id)

## A wild Spirling just bonded on [param map_id]: books the place and draws its arts.
static func note_bonded(s: Spirling, map_id: String) -> void:
	if active("one_per_place"):
		_book(BONDS_KEY, map_id)
	shuffle_arts(s)

## Shuffled Wilds: the species that stands in for [param species] on [param table_id]. The same
## seed, place and species always give the same stand-in, drawn from first forms of its region.
static func wild_species(species: String, table_id: String) -> String:
	if not active("wild_shuffle"):
		return species
	var sd: SpirlingData = Database.species(species)
	var pool: Array = _pool_for(sd.region if sd != null else "")
	if pool.is_empty():
		return species
	return str(pool[posmod(("%d|%s|%s" % [run_seed(), table_id, species]).hash(), pool.size())])

static func _pool_for(region: String) -> Array:
	if _wild_pool.is_empty():
		Database.load_all()
		var later: Dictionary = {}
		for sd: SpirlingData in Database.spirlings.values():
			for path: Dictionary in sd.unfold:
				if path.get("to") is SpirlingData:
					later[(path.to as SpirlingData).species_name] = true
		for sd: SpirlingData in Database.spirlings.values():
			if sd.rarity == "ancient" or later.has(sd.species_name):
				continue
			if not _wild_pool.has(sd.region):
				_wild_pool[sd.region] = []
			(_wild_pool[sd.region] as Array).append(sd.species_name)
		for r: Variant in _wild_pool:
			(_wild_pool[r] as Array).sort()
	return _wild_pool.get(region, [])

## Shuffled Wilds: [param wild] as its stand-in on [param table_id] (same ring, Prism and Gleam).
static func reroll_wild(wild: Spirling, table_id: String, rng: RandomNumberGenerator) -> Spirling:
	if wild == null or not active("wild_shuffle"):
		return wild
	var name: String = wild_species(wild.data.species_name, table_id)
	if name == wild.data.species_name:
		return wild
	var out := Spirling.new(Database.species(name), wild.level, rng)
	out.prism = wild.prism
	out.gleam = wild.gleam
	return out

## Shuffled Arts: [param s] forgets its arts and knows up to four drawn by the seed from every
## art some Spirling learns by its ring, so a fresh bond is never stronger than its ring allows.
static func shuffle_arts(s: Spirling) -> void:
	if s == null or not active("art_shuffle"):
		return
	if _art_pool.is_empty():
		Database.load_all()
		var seen: Dictionary = {}
		for sd: SpirlingData in Database.spirlings.values():
			for i: int in sd.learnset_levels.size():
				var mv: MoveData = sd.learnset_moves[i]
				if mv != null and not seen.has(mv.move_name):
					seen[mv.move_name] = sd.learnset_levels[i]
				elif mv != null:
					seen[mv.move_name] = mini(int(seen[mv.move_name]), sd.learnset_levels[i])
		var names: Array = seen.keys()
		names.sort()
		for n: Variant in names:
			var mv: MoveData = Database.move(str(n))
			if mv != null:
				_art_ring[mv.move_name] = int(seen[n])
				_art_pool.append(mv)
	var fits: Array[MoveData] = []
	for mv: MoveData in _art_pool:
		if int(_art_ring.get(mv.move_name, 1)) <= s.level:
			fits.append(mv)
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|%s|%s|%d" % [run_seed(), s.uid, s.data.species_name, s.level]).hash()
	var picked: Array[MoveData] = []
	var hits: int = 0
	while picked.size() < Spirling.MAX_MOVES and not fits.is_empty():
		var mv: MoveData = fits.pop_at(r.randi_range(0, fits.size() - 1))
		# At least one damaging art, so no shuffled Spirling is left without a way to hit.
		if picked.size() == Spirling.MAX_MOVES - 1 and hits == 0 and not mv.is_damaging():
			continue
		picked.append(mv)
		hits += 1 if mv.is_damaging() else 0
	if not picked.is_empty():
		s.moves = picked

# --- Items, shop, rest ----------------------------------------------------------------------

static func items_allowed() -> bool:
	return not active("no_items")

static func shop_open() -> bool:
	return not active("no_shop")

## True for an item that mends Vigor or brings a fallen Spirling back.
static func is_healing(it: Dictionary) -> bool:
	return int(it.get("heal", 0)) > 0 or float(it.get("heal_frac", 0.0)) > 0.0 \
		or float(it.get("revive", 0.0)) > 0.0 or float(it.get("battle_revive", 0.0)) > 0.0

## May [param id] be used now (battle or bag)?
static func item_allowed(id: String) -> bool:
	if active("spring_water") and is_healing(Database.item(id)):
		return false
	return true

## Battle items Spring Water Only takes out of the bag for the battle.
static func blocked_items(inventory: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in inventory:
		if not item_allowed(str(id)):
			out.append(str(id))
	return out

## Half Rested: after a rest every Spirling keeps at most half its Vigor (rounded up).
static func after_rest(party: Array[Spirling]) -> void:
	if not active("half_rested"):
		return
	for s: Spirling in party:
		s.hp = mini(s.hp, ceili(s.max_hp() / 2.0))

## The lines a rest spring adds: the ring cap while one holds (item 503).
static func rest_lines() -> Array[String]:
	var out: Array[String] = []
	if GameState.has_ring_limit():
		out.append(Loc.t("Ring cap now: R%d. Each mended Rift raises it.") % GameState.level_cap())
		Lexicon.add(GameState.records, "ring_caps")
	if active("half_rested"):
		out.append(Loc.t("Half Rested: the spring mends only half."))
	# Lantern post (item 529): beaten Wayfarers who would battle again today.
	if not WayfarerBook.invitations(DailyFind.today_key()).is_empty():
		out.append(WayfarerBook.lantern_line(DailyFind.today_key()))
	return out

## Trust No One: the party index that walks off after a Warden, -1 when the rule is off or one is left.
static func walkout(party_size: int, rng: RandomNumberGenerator) -> int:
	if not active("trust_no_one") or party_size <= 1:
		return -1
	return rng.randi_range(0, party_size - 1)

# --- Battles --------------------------------------------------------------------------------

## Ace Up Front: [param foes] with the highest ring first (a tie keeps the old order).
static func order_foes(foes: Array) -> void:
	if not active("ace_first") or foes.size() < 2:
		return
	var top: int = 0
	for i: int in foes.size():
		if (foes[i] as Spirling).level > (foes[top] as Spirling).level:
			top = i
	if top > 0:
		foes.push_front(foes.pop_at(top))

## Rift-Born (item 500): a foe with fewer than four arts learns the next ones of its line.
static func fill_arts(s: Spirling) -> void:
	if s.moves.size() >= Spirling.MAX_MOVES:
		return
	for i: int in s.data.learnset_levels.size():
		var mv: MoveData = s.data.learnset_moves[i]
		if s.moves.size() < Spirling.MAX_MOVES and mv != null and not s.moves.has(mv) and s.data.learnset_levels[i] <= s.level + RIFT_BORN_ART_REACH:
			s.moves.append(mv)

static func scaling_on() -> bool:
	return bool(GameState.records.get(SCALING_KEY, false))

static func toggle_scaling() -> void:
	GameState.records[SCALING_KEY] = not scaling_on()

## Foe scaling: lifts every foe below (party top - SCALING_GAP) up to it, within the cap.
static func scale_foes(foes: Array, party: Array[Spirling]) -> void:
	if not scaling_on() or party.is_empty():
		return
	var top: int = 1
	for s: Spirling in party:
		top = maxi(top, s.level)
	var to: int = mini(top - SCALING_GAP, mini(Spirling.STORY_RING, GameState.progress_cap() + GameState.FOE_OVER_CAP))
	for f: Variant in foes:
		var s: Spirling = f
		if s.level < to:
			s.level = to
			s.hp = s.max_hp()

## "Veteran. Rules: Night Bonds" - the line a battle shows at its start (item 495).
static func battle_line(difficulty: int) -> String:
	var line: String = Loc.t("Difficulty: %s") % RunChronicle.difficulty_name(difficulty)
	if any_active():
		line += "\n" + Loc.t("Challenges: %s") % names()
	return line

## Sets the challenge rules and difficulty touches on a world battle. Echo duels (a fixed
## [code]player_team[/code]) stay even and are left alone.
static func apply_to_model(model: BattleModel, trainer: Dictionary, map_id: String) -> void:
	var own: Variant = trainer.get("player_team")
	if own is Array and not (own as Array).is_empty():
		return
	var d: int = clampi(int(GameState.difficulty), 0, FOE_CRIT.size() - 1)
	model.foe_crit_mult = FOE_CRIT[d]
	model.xp_mult *= GROWTH[d]
	if not items_allowed():
		model.items_allowed = false
	model.blocked_items = blocked_items(model.inventory)
	model.swap_locked = active("stand_ground")
	if model.is_wild:
		model.bond_block = bond_block(map_id, model.parties[1], DayCycle.current() == DayCycle.Phase.NIGHT)
		note_wild_battle(map_id)
		return
	if str(trainer.get("boss", "")).is_empty():
		order_foes(model.parties[1])
		scale_foes(model.parties[1], model.parties[0])
	if d == GameState.Difficulty.RIFT_BORN:
		for s: Variant in model.parties[1]:
			fill_arts(s)
	# Warden battles name the difficulty when it is not the normal one; rules always show.
	if any_active() or (bool(trainer.get("warden", false)) and d != GameState.Difficulty.TAMER):
		model.set_meta("challenge_line", battle_line(d))

## Books a finished world battle in the challenge stats (only while a rule is on).
static func note_result(won: bool, warden: bool) -> void:
	if not any_active():
		return
	var st: Dictionary = GameState.as_dict(GameState.records.get(STATS_KEY, {})).duplicate()
	var key: String = "wins" if won else "losses"
	st[key] = int(st.get(key, 0)) + 1
	if won and warden:
		st["wardens"] = int(st.get("wardens", 0)) + 1
	GameState.records[STATS_KEY] = st

## The stats lines for the challenge page (item 504).
static func stats_lines() -> Array[String]:
	var st: Dictionary = GameState.as_dict(GameState.records.get(STATS_KEY, {}))
	var out: Array[String] = [Loc.t("Battles won: %d, lost: %d") % [int(st.get("wins", 0)), int(st.get("losses", 0))],
		Loc.t("Wardens beaten under the rules: %d") % int(st.get("wardens", 0))]
	if bool(GameState.records.get(DROPPED_KEY, false)):
		out.append(Loc.t("A rule was dropped on the way."))
	return out

## Difficulty for boards and the run chronicle (item 494): lowering counts for good, raising
## again never lifts a run above the lowest difficulty it was played on.
static func ranked_difficulty() -> int:
	return mini(int(GameState.difficulty), int(GameState.records.get(FLOOR_KEY, GameState.difficulty)))

## Called before the difficulty changes to [param d].
static func note_difficulty(d: int) -> void:
	if d < int(GameState.difficulty):
		GameState.records[FLOOR_KEY] = mini(d, ranked_difficulty())
