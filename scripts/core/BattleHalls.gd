class_name BattleHalls
extends RefCounted
## Battle halls on Examiner Hollis's board (KAMPF_PLAN_1000, area "Endgame-Kampfmodi"): lottery
## team, draft, survival without healing, the twin, swarm and heart stairs, a weekly prism heart and
## a festival cup. Values in data/battle_halls.json. Everyone fights with copies at the hall ring,
## so nothing is lost, the real team never changes and nothing bought counts (the battle runs as
## an echo battle: no seals, amulets or pass Energy). A run is the same for the same hall and seed;
## the seed comes from the week, or from a friend's run code. The field turns every round, the rule
## variant every week. State lives in GameState.records:
##   halls      {id: {"runs", "wins", "clears", "best", "paid_week"}}   statistics and weekly pay
##   hall_fame  [{"hall", "date", "team"}]                              first clears, newest first
##   hall_week  {"week", "wins", "paid"}                                weekly goal
##   hall_lore  [hall id]                                               lore lines earned

const PATH: String = "res://data/battle_halls.json"
const KEY: String = "halls"
const FAME_KEY: String = "hall_fame"
const WEEK_KEY: String = "hall_week"
const LORE_KEY: String = "hall_lore"
const CODE_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
## Run codes and team codes are this long: what CodePrompt asks for.
const CODE_LEN: int = 8
const SEED_MOD: int = 60466176  # 36^5: a run seed fits in five code letters

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
	return _data

static func ring() -> int:
	return clampi(int(data().get("ring", 50)), 1, Spirling.STORY_RING)

static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Variant in data().get("halls", []):
		if h is Dictionary:
			out.append(h)
	return out

static func by_id(id: String) -> Dictionary:
	for h: Dictionary in all():
		if str(h.id) == id:
			return h
	return {}

## The festival cup only opens while a festival runs; every other hall is always open.
static func is_open(h: Dictionary, festival: Dictionary) -> bool:
	return not bool(h.get("festival", false)) or not festival.is_empty()

static func open_halls(festival: Dictionary) -> Array[Dictionary]:
	return all().filter(func(h: Dictionary) -> bool: return is_open(h, festival))

static func label(h: Dictionary) -> String:
	return Loc.t(str(h.get("label", h.get("id", ""))))

## Rounds (floors) of a hall; the heart stair has one floor per Rift heart.
static func rounds(h: Dictionary) -> int:
	if str(h.get("kind", "")) == "boss":
		return BattleRules.BOSSES.size()
	if str(h.get("kind", "")) == "prism":
		return 1
	return maxi(1, int(h.get("rounds", 1)))

static func team_size(h: Dictionary) -> int:
	return clampi(int(h.get("team", data().get("team", 3))), 1, GameState.MAX_PARTY)

static func heals_between(h: Dictionary) -> bool:
	return not str(h.get("kind", "")) in ["survival", "boss"]

# --- Seeds, fields and rules ------------------------------------------------------------------

## The run seed of [param hall_id] in [param week]: the same for everyone that week.
static func week_seed(hall_id: String, week: String) -> int:
	return absi(hash(["chimora-hall", hall_id, week])) % SEED_MOD

static func _rng(seed_value: int, salt: Variant) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["chimora-hall-run", seed_value, salt])
	return r

## The field of round [param round_i] (0-based): turns through data "fields" from a seeded start.
static func field_for(seed_value: int, round_i: int) -> String:
	var fields: Array = data().get("fields", [])
	if fields.is_empty():
		return ""
	return str(fields[(seed_value + round_i) % fields.size()])

## The rule variant of [param week], the same in every hall.
static func variants_for(week: String) -> Array[String]:
	return BattleRules.draw_variants(absi(hash(["chimora-hall-rule", week])), 1)

## The Rift heart of floor [param round_i] in the heart stair, or of the week's prism heart.
static func boss_for(h: Dictionary, seed_value: int, round_i: int) -> String:
	var ids: Array = BattleRules.BOSSES.keys()
	ids.sort()
	if str(h.get("kind", "")) == "prism":
		return str(ids[seed_value % ids.size()])
	return str(ids[round_i % ids.size()])

# --- Teams -----------------------------------------------------------------------------------

## Species a hall may field at [param level]: fully grown for that ring (as on the lighthouse
## stair), only of [param elements] when given (festival cup).
static func pool(level: int, elements: Array = []) -> Array[String]:
	var out: Array[String] = []
	for sd: SpirlingData in Gauntlet.new(0, level)._pool(level):
		if elements.is_empty() or sd.elements.any(func(e: int) -> bool: return e in elements):
			out.append(sd.species_name)
	return out

static func build(names: Array, level: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: Variant in names:
		if Database.spirlings.has(str(n)):
			var s := Spirling.new(Database.spirlings[str(n)], clampi(level, 1, Spirling.STORY_RING), rng)
			s.restore()
			out.append(s)
	return out

static func _draw(from: Array[String], n: int, rng: RandomNumberGenerator) -> Array[String]:
	var left: Array[String] = from.duplicate()
	var out: Array[String] = []
	while out.size() < n and not left.is_empty():
		out.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return out

## The foe team of round [param round_i].
static func foe_team(h: Dictionary, seed_value: int, round_i: int, elements: Array = []) -> Array[Spirling]:
	var r: RandomNumberGenerator = _rng(seed_value, ["foe", str(h.id), round_i])
	var kind: String = str(h.get("kind", ""))
	if kind == "boss" or kind == "prism":
		var heart: Array[String] = _draw(pool(ring()), 1, r)
		var out: Array[Spirling] = build(heart, ring(), r)
		if kind == "prism" and not out.is_empty():
			out[0].prism = true
		return out
	var lvl: int = ring() - int(h.get("foe_ring_cut", 0))
	var n: int = int(h.get("foe_team", data().get("team", 3)))
	return build(_draw(pool(lvl, elements), n, r), lvl, r)

## The lottery team: three random Spirlings at the hall ring, the same for the same seed.
static func lottery_team(seed_value: int) -> Array[Spirling]:
	var r: RandomNumberGenerator = _rng(seed_value, "lottery")
	return build(_draw(pool(ring()), int(data().get("team", 3)), r), ring(), r)

## The draft table: data "pool" species for this seed.
static func draft_pool(h: Dictionary, seed_value: int) -> Array[String]:
	return _draw(pool(ring()), int(h.get("pool", 8)), _rng(seed_value, "draft"))

## Base stat total, what the echo looks at when it picks.
static func _power(name: String) -> int:
	var sd: SpirlingData = Database.spirlings.get(name)
	return sd.base_hp + sd.base_atk + sd.base_def + sd.base_foc + sd.base_spd if sd != null else 0

## The echo's pick from what is left: the strongest, ties by name.
static func echo_pick(left: Array[String]) -> String:
	var best: String = ""
	for n: String in left:
		if best.is_empty() or _power(n) > _power(best) or (_power(n) == _power(best) and n < best):
			best = n
	return best

## Plays the draft: [param mine] are the player's picks in order; the echo picks after each one.
## Returns {"mine": [...], "theirs": [...]}; picks not on the table are skipped.
static func draft(table: Array[String], mine: Array[String], size: int) -> Dictionary:
	var left: Array[String] = table.duplicate()
	var me: Array[String] = []
	var them: Array[String] = []
	for p: String in mine:
		if me.size() >= size or not p in left:
			continue
		left.erase(p)
		me.append(p)
		if them.size() < size and not left.is_empty():
			var e: String = echo_pick(left)
			left.erase(e)
			them.append(e)
	return {"mine": me, "theirs": them}

## Copies of the first [param n] Spirlings of [param party] at the hall ring (level scaling).
static func scaled(party: Array[Spirling], n: int) -> Array[Spirling]:
	var take: Array[Spirling] = []
	for s: Spirling in party:
		if take.size() < n:
			take.append(s)
	return EchoTeam.duel_copy(take, ring())

## The battle info for Overworld.start_battle: an echo battle with copies, AI master tier.
static func battle_info(h: Dictionary, seed_value: int, round_i: int, week: String, mine: Array[Spirling]) -> Dictionary:
	var info: Dictionary = {"name": Loc.t("%s, round %d") % [label(h), round_i + 1], "ai": int(data().get("ai", 3)),
		"money": 0, "friendly": true, "player_team": mine, "field": field_for(seed_value, round_i),
		"variants": variants_for(week)}
	if h.has("front"):
		info["front"] = (h.front as Array).duplicate()
	var kind: String = str(h.get("kind", ""))
	if kind == "boss" or kind == "prism":
		info["boss"] = boss_for(h, seed_value, round_i)
		info["warden"] = true
	return info

# --- Codes: share a run, share a team ----------------------------------------------------------

static func _b36(n: int, width: int) -> String:
	var out: String = ""
	for i: int in width:
		out = CODE_CHARS[n % 36] + out
		n /= 36
	return out

static func _from_b36(s: String) -> int:
	var n: int = 0
	for c: String in s:
		var v: int = CODE_CHARS.find(c)
		if v < 0:
			return -1
		n = n * 36 + v
	return n

static func _check(s: String) -> String:
	return _b36(absi(hash("chimora-code-" + s)) % 1296, 2)

## An eight-letter code for a run: hall, seed and a check. A friend who enters it meets the
## same rounds (seed sharing).
static func run_code(hall_id: String, seed_value: int) -> String:
	var i: int = all().map(func(h: Dictionary) -> String: return str(h.id)).find(hall_id)
	if i < 0:
		return ""
	var body: String = CODE_CHARS[i] + _b36(seed_value % SEED_MOD, 5)
	return body + _check(body)

## {"hall", "seed"} from a run code, or {} when it is broken.
static func parse_run_code(code: String) -> Dictionary:
	var c: String = NameKeyboard.raw_code(code.to_upper())
	if c.length() != CODE_LEN or _check(c.left(6)) != c.right(2):
		return {}
	var i: int = CODE_CHARS.find(c[0])
	var seed_value: int = _from_b36(c.substr(1, 5))
	if i < 0 or i >= all().size() or seed_value < 0:
		return {}
	return {"hall": str(all()[i].id), "seed": seed_value}

static func _species_list() -> Array:
	var names: Array = Database.spirlings.keys()
	names.sort()
	return names

## An eight-letter code for three species (team codes): two letters each plus a check over
## the names, so a code from an older build with other species fails instead of lying.
static func team_code(names: Array[String]) -> String:
	var all_names: Array = _species_list()
	if names.size() != 3:
		return ""
	var body: String = ""
	for n: String in names:
		var i: int = all_names.find(n)
		if i < 0 or i >= 1296:
			return ""
		body += _b36(i, 2)
	return body + _check(",".join(names))

## The three species in a team code, or [] when it is broken.
static func parse_team_code(code: String) -> Array[String]:
	var c: String = NameKeyboard.raw_code(code.to_upper())
	var out: Array[String] = []
	if c.length() != CODE_LEN:
		return out
	var all_names: Array = _species_list()
	for k: int in 3:
		var i: int = _from_b36(c.substr(k * 2, 2))
		if i < 0 or i >= all_names.size():
			return [] as Array[String]
		out.append(str(all_names[i]))
	return out if _check(",".join(out)) == c.right(2) else [] as Array[String]

## The team behind a team code at the hall ring with the moves it knows there.
static func code_team(names: Array[String], seed_value: int) -> Array[Spirling]:
	return build(names, ring(), _rng(seed_value, "code"))

# --- Results, statistics, rewards ---------------------------------------------------------------

static func stats(id: String) -> Dictionary:
	var all_stats: Dictionary = GameState.as_dict(GameState.records.get(KEY, {}))
	var s: Dictionary = GameState.as_dict(all_stats.get(id, {}))
	for k: String in ["runs", "wins", "clears", "best"]:
		s[k] = int(s.get(k, 0))
	return s

static func _put(id: String, s: Dictionary) -> void:
	var all_stats: Dictionary = GameState.as_dict(GameState.records.get(KEY, {})).duplicate()
	all_stats[id] = s
	GameState.records[KEY] = all_stats

## Total hall clears, for the badges.
static func total_clears() -> int:
	var n: int = 0
	for h: Dictionary in all():
		n += int(stats(str(h.id)).clears)
	return n

## Weekly goal state for [param week] (reset when the week changed).
static func week_state(week: String) -> Dictionary:
	var w: Dictionary = GameState.as_dict(GameState.records.get(WEEK_KEY, {}))
	if str(w.get("week", "")) != week:
		w = {"week": week, "wins": 0, "paid": false}
	return w

static func week_goal_line(week: String) -> String:
	var g: Dictionary = GameState.as_dict(data().get("week_goal", {}))
	var w: Dictionary = week_state(week)
	if bool(w.paid):
		return Loc.t("Weekly goal: done. The halls are bored of you until Monday.")
	return Loc.t("Weekly goal: win %d hall battles (%d so far).") % [int(g.get("wins", 0)), mini(int(w.wins), int(g.get("wins", 0)))]

## Books one won hall battle for the weekly goal. Returns reward lines when it is reached.
static func note_win(week: String) -> Array[String]:
	var g: Dictionary = GameState.as_dict(data().get("week_goal", {}))
	var w: Dictionary = week_state(week)
	w.wins = int(w.wins) + 1
	var out: Array[String] = []
	if not bool(w.paid) and int(w.wins) >= int(g.get("wins", 1)):
		w.paid = true
		out.append(Loc.t("Weekly goal reached!"))
		out.append_array(Waymarks.reward_lines(Waymarks.earn(int(g.get("waymarks", 0)), "tower")))
	GameState.records[WEEK_KEY] = w
	return out

## Books a finished run of [param h]: [param won] rounds, the team that fought (species names).
## Pays Waymarks for a clear once per hall and week; the first clear ever adds a title, a lore
## line and a Hall of Fame row. Returns the lines to show.
static func finish(h: Dictionary, won: int, team: Array[String], week: String, date: String) -> Array[String]:
	var id: String = str(h.id)
	var s: Dictionary = stats(id)
	s.runs = int(s.runs) + 1
	s.wins = int(s.wins) + won
	s.best = maxi(int(s.best), won)
	var out: Array[String] = [Loc.t("%s: %d of %d rounds.") % [label(h), won, rounds(h)]]
	if won >= rounds(h):
		s.clears = int(s.clears) + 1
		GameState.records["hall_clears"] = int(GameState.records.get("hall_clears", 0)) + 1
		if str(s.get("paid_week", "")) != week:
			s["paid_week"] = week
			out.append_array(Waymarks.reward_lines(Waymarks.earn(int(h.get("waymarks", 0)), "tower")))
		if int(s.clears) == 1:
			out.append_array(_first_clear(h, team, date))
	_put(id, s)
	return out

static func _first_clear(h: Dictionary, team: Array[String], date: String) -> Array[String]:
	var out: Array[String] = []
	var title: String = str(h.get("title", ""))
	if not title.is_empty():
		var t: Array = (GameState.records.get("titles", []) as Array).duplicate()
		if not t.has(title):
			t.append(title)
			GameState.records["titles"] = t
			out.append(Loc.t("New title: %s") % Loc.t(title))
	var lore: Array = (GameState.records.get(LORE_KEY, []) as Array).duplicate()
	if not lore.has(str(h.id)) and not str(h.get("lore", "")).is_empty():
		lore.append(str(h.id))
		GameState.records[LORE_KEY] = lore
		out.append(Loc.t("A new page for the hall stories."))
	var fame: Array = (GameState.records.get(FAME_KEY, []) as Array).duplicate()
	fame.push_front({"hall": str(h.id), "date": date, "team": team.duplicate()})
	while fame.size() > int(data().get("fame_max", 30)):
		fame.pop_back()
	GameState.records[FAME_KEY] = fame
	out.append(Loc.t("Your team goes up on the Hall of Fame."))
	return out

## One line per hall with runs: "Draft Hall: 4 runs, 9 won, 1 clear, best 3".
static func stats_lines() -> Array[String]:
	var out: Array[String] = []
	for h: Dictionary in all():
		var s: Dictionary = stats(str(h.id))
		if int(s.runs) > 0:
			out.append(Loc.t("%s: %d runs, %d won, %d clears, best %d") % [label(h), int(s.runs), int(s.wins), int(s.clears), int(s.best)])
	return out

## The Hall of Fame: one line per first clear, newest first.
static func fame_lines() -> Array[String]:
	var out: Array[String] = []
	for e: Variant in GameState.records.get(FAME_KEY, []):
		var d: Dictionary = GameState.as_dict(e)
		var h: Dictionary = by_id(str(d.get("hall", "")))
		if h.is_empty():
			continue
		var names: Array[String] = []
		for n: Variant in d.get("team", []):
			names.append(str(n))
		out.append("%s  %s  %s" % [str(d.get("date", "")), label(h), ", ".join(names)])
	return out

## Lore lines earned by first clears, in hall order.
static func lore_lines() -> Array[String]:
	var got: Array = GameState.records.get(LORE_KEY, [])
	var out: Array[String] = []
	for h: Dictionary in all():
		if got.has(str(h.id)):
			out.append(Loc.t(str(h.get("lore", ""))))
	return out

# --- Title on the Wanderer card --------------------------------------------------------------------

const WORN_KEY: String = "card_title"

## Every title that can be worn on the card (the server keeps only these, never free text).
static func card_titles() -> Array[String]:
	var out: Array[String] = []
	for t: Variant in data().get("card_titles", []):
		out.append(str(t))
	return out

## Earned titles that may go on the card.
static func wearable() -> Array[String]:
	var known: Array[String] = card_titles()
	return Collection.titles().filter(func(t: String) -> bool: return t in known)

## The title shown on the card, "" for none (also when it is no longer earned).
static func worn_title() -> String:
	var t: String = str(GameState.records.get(WORN_KEY, ""))
	return t if t in wearable() else ""

static func wear(title: String) -> void:
	if title.is_empty() or title in wearable():
		GameState.records[WORN_KEY] = title
