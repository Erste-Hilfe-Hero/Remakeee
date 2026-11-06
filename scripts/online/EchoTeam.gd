class_name EchoTeam
extends RefCounted
## A friend's team as an echo (items 46-48, 61, 76, 121-124). Echoes are copies run by the AI:
## the friend does not need to be online and nothing happens to their real Spirlings.
## Only species, level and move names go online, never nicknames.

## Level for echo duels: both sides fight at the same level (item 124).
const DUEL_LEVEL: int = 30
## AI tier of a friend's echo beside you.
const PARTNER_AI: int = 1
## AI tier of a friend's echo in a duel.
const DUEL_AI: int = 2

## The team that goes online: species, level, move names.
static func snapshot(party: Array[Spirling]) -> Array:
	var out: Array = []
	for s: Spirling in party:
		var moves: Array = []
		for mv: MoveData in s.moves:
			moves.append(mv.move_name)
		out.append({"species": s.data.species_name, "level": s.level, "moves": moves})
	return out

## Builds Spirlings from a friend's snapshot. Levels are clamped to [param max_level] (item 76).
## [param fixed_level] > 0 puts every Spirling on that level (duels). Unknown species are skipped.
static func build(rows: Array, max_level: int, fixed_level: int = 0) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for r: Variant in rows:
		if not r is Dictionary:
			continue
		var lvl: int = fixed_level if fixed_level > 0 else mini(int(r.get("level", 1)), max_level)
		var s: Spirling = Spirling.from_dict({"species": str(r.get("species", "")), "level": clampi(lvl, 1, Spirling.MAX_LEVEL),
			"moves": r.get("moves", []) if fixed_level <= 0 else []})
		if s == null:
			continue
		if fixed_level > 0:
			s.moves = s.data.default_moves(s.level, Spirling.MAX_MOVES)
		s.restore()
		out.append(s)
		if out.size() >= GameState.MAX_PARTY:
			break
	return out

## Copies of the player's own team on the duel level, so a duel never changes the real team.
static func duel_copy(party: Array[Spirling]) -> Array[Spirling]:
	return build(snapshot(party), Spirling.MAX_LEVEL, DUEL_LEVEL)

## Rounds won * 100 + team health left in percent: the weekly board score (0-400).
static func weekly_score(wins: int, party: Array[Spirling]) -> int:
	var hp: float = 0.0
	for s: Spirling in party:
		hp += s.hp_fraction()
	var pct: int = int(round(100.0 * hp / maxf(1.0, float(party.size())))) if wins >= WeeklyChallenge.ROUNDS else 0
	return clampi(wins * WeeklyChallenge.POINTS_PER_ROUND + pct, 0, 400)
