class_name EchoTeam
extends RefCounted
## A friend's team as an echo (items 46-48, 61, 76, 121-124). Echoes are copies run by the AI:
## the friend does not need to be online and nothing happens to their real Spirlings.
## Only species, level and move names go online, never nicknames.

## Fallback Ring for echo duels: both sides fight at the same Ring (item 124). The server
## sends the real one with the friend's team (server_config.duel_ring, plan item 2671).
const DUEL_LEVEL: int = 50
## AI tier of a friend's echo beside you.
const PARTNER_AI: int = 1
## AI tier of a friend's echo in a duel: the master tier (KAMPF_PLAN_1000, online echoes).
const DUEL_AI: int = 3

## The team that goes online: species, level, move names.
static func snapshot(party: Array[Spirling]) -> Array:
	var out: Array = []
	for s: Spirling in party:
		var moves: Array = []
		for mv: MoveData in s.moves:
			moves.append(mv.move_name)
		var row: Dictionary = {"species": s.data.species_name, "level": s.level, "moves": moves}
		# A held keepsake goes along (KAMPF_PLAN_1000); shop keepsakes never do.
		if s.held in Achievements.keepsakes():
			row["held"] = s.held
		out.append(row)
	return out

## Builds Spirlings from a friend's snapshot. Levels are clamped to [param max_level] (item 76).
## [param fixed_level] > 0 puts every Spirling on that level (duels). Unknown species are skipped.
static func build(rows: Array, max_level: int, fixed_level: int = 0) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for r: Variant in rows:
		if not r is Dictionary:
			continue
		var lvl: int = fixed_level if fixed_level > 0 else mini(int(r.get("level", 1)), max_level)
		var s: Spirling = Spirling.from_dict({"species": str(r.get("species", "")), "level": clampi(lvl, 1, Spirling.STORY_RING),
			"moves": r.get("moves", []) if fixed_level <= 0 else []})
		if s == null:
			continue
		if fixed_level > 0:
			s.moves = s.data.default_moves(s.level, Spirling.MAX_MOVES)
		var held: Variant = r.get("held", "")
		if held is String and held in Achievements.keepsakes():
			s.held = held
		s.restore()
		out.append(s)
		if out.size() >= GameState.MAX_PARTY:
			break
	return out

## Copies of the player's own team on the duel level, so a duel never changes the real team.
static func duel_copy(party: Array[Spirling], ring: int = DUEL_LEVEL) -> Array[Spirling]:
	return build(snapshot(party), Spirling.STORY_RING, ring)

## The duel Ring the server sent with a friend's team, kept inside the game's limits.
static func duel_ring(d: Dictionary) -> int:
	var v: Variant = d.get("duel_ring", DUEL_LEVEL)
	return clampi(int(v) if (v is int or v is float) else DUEL_LEVEL, 1, Spirling.STORY_RING)

## Rounds won * 100 + team health left in percent: the weekly board score (0-400).
static func weekly_score(wins: int, party: Array[Spirling]) -> int:
	var hp: float = 0.0
	for s: Spirling in party:
		hp += s.hp_fraction()
	var pct: int = int(round(100.0 * hp / maxf(1.0, float(party.size())))) if wins >= WeeklyChallenge.ROUNDS else 0
	return clampi(wins * WeeklyChallenge.POINTS_PER_ROUND + pct, 0, 400)

## Counts echo duels for the online badges (records "echo_duels", "echo_duel_wins").
static func note_duel(records: Dictionary, won: bool) -> void:
	records["echo_duels"] = int(records.get("echo_duels", 0)) + 1
	if won:
		records["echo_duel_wins"] = int(records.get("echo_duel_wins", 0)) + 1
