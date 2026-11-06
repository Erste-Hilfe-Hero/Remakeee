class_name LeagueMenu
extends RefCounted
## Menu > Leagues (plan area 7, items 2730, 2753, 2691): the fair league first, the open league
## right below it. Joining sends only species names; the server builds the league team. "Find a
## battle" asks the server for an opponent, and the battle the server set up is left in
## [member PauseMenu.league_match] for the overworld to play.

const FAIR_TEXT: String = "Only your skill counts here. Bought advantages do not work here."
const OPEN_TEXT: String = "Open league: all advantages allowed, also bought ones"
## Seconds between two searches, and how long the game keeps searching.
const SEARCH_EVERY: float = 3.0
const SEARCH_FOR: float = 60.0

const ERRORS: Dictionary = {
	"feature_off": "This league is closed right now.",
	"season_paused": "The season is paused. Please come back later.",
	"empty_team": "Your team is empty.",
	"not_in_team": "Save your journey first, then try again.",
	"not_joined": "Join the league first.",
	"bad_team": "A league team has at most 5 Spirlings.",
}

static func run(menu: PauseMenu) -> void:
	if not Online.is_online():
		await menu.info(Online.error_text())
		return
	while true:
		var leagues: Array[String] = shown_leagues()
		var labels: Array[String] = []
		for l: String in leagues:
			labels.append("Fair league" if l == LeagueRules.FAIR else OPEN_TEXT)
		var idx: int = await menu.pick_strings("Leagues", labels)
		if idx < 0:
			return
		if await run_league(menu, leagues[idx]):
			return

## The fair league first, the open league right below it; a league that is switched off is hidden.
static func shown_leagues() -> Array[String]:
	var out: Array[String] = []
	for l: String in [LeagueRules.FAIR, LeagueRules.OPEN]:
		if Online.flag_on("league_" + l):
			out.append(l)
	return out

## One league. Returns true when the menu should close (a battle was found).
static func run_league(menu: PauseMenu, league: String) -> bool:
	while true:
		var r: Dictionary = await Online.call_fn("league_info", {"p_league": league})
		if not r.ok or not r.data is Dictionary or r.data.has("error"):
			await menu.info(error_text(r))
			return false
		var info: Dictionary = r.data
		var entries: Array[String] = ["Find a battle", "Join with my team"] if bool(info.joined) else ["Join with my team"]
		var idx: int = await menu.pick_strings(status_text(league, info), entries)
		if idx < 0:
			return false
		match entries[idx]:
			"Join with my team":
				await join(menu, league)
			"Find a battle":
				var found: Dictionary = await search(menu, league)
				if not found.is_empty():
					found["league"] = league
					menu.league_match = found
					return true
	return false

## What the league screen says: the rule, the tier, games and the season state.
static func status_text(league: String, info: Dictionary) -> String:
	var lines: Array[String] = [FAIR_TEXT if league == LeagueRules.FAIR else OPEN_TEXT]
	lines.append("Everyone fights at Ring %d." % int(info.get("ring", LeagueRules.FAIR_RING))
		if league == LeagueRules.FAIR else "Your real team and Ring.")
	if bool(info.get("joined", false)) and info.get("tier") != null:
		lines.append("Tier: %s" % LeagueRules.tier_name(int(info.tier)))
		lines.append("Battles: %d   Wins: %d" % [int(info.get("games", 0)), int(info.get("wins", 0))])
	else:
		lines.append("Not joined this season yet.")
	match str(info.get("state", "")):
		"closing": lines.append("The season ends soon. Battles now do not count.")
		"paused": lines.append("The season is paused.")
	return "\n".join(lines)

static func error_text(r: Dictionary) -> String:
	var code: String = str(r.data.get("error", "")) if r.get("data") is Dictionary else str(r.get("error", ""))
	return ERRORS.get(code, Online.error_text(code))

## The species to send: the current team, at most five, each kind once.
static func pick_of(party: Array[Spirling]) -> Array:
	var pick: Array = []
	for s: Spirling in party:
		var sp: String = s.data.species_name
		if pick.size() < LeagueRules.TEAM_MAX and not pick.any(func(p: Dictionary) -> bool: return p.species == sp):
			pick.append({"species": sp, "moves": s.moves.map(func(m: MoveData) -> String: return m.move_name)})
	return pick

static func join(menu: PauseMenu, league: String) -> void:
	# The server builds the league team from the team it has, so send the current one first.
	await Online.push_team()
	var r: Dictionary = await Online.call_fn("league_join", {"p_league": league, "p_pick": pick_of(GameState.party)})
	if not r.ok or not r.data is Dictionary or r.data.has("error"):
		await menu.info(error_text(r))
		return
	var names: Array[String] = []
	for row: Dictionary in r.data.team:
		names.append("%s Ring %d" % [str(row.species), int(row.level)])
	await menu.info(Loc.t("Your league team:") + "\n" + "\n".join(names))

## Asks the server for an opponent until one is found, the player goes back, or a minute passes.
## Returns the battle the server set up, or {}.
static func search(menu: PauseMenu, league: String) -> Dictionary:
	var cancelled: Array[bool] = [false]
	var on_pick := func(_i: int) -> void: cancelled[0] = true
	menu.picker.picked.connect(on_pick, CONNECT_ONE_SHOT)
	menu.picker.pick("Searching for an opponent...", [{"text": "Searching...", "disabled": true}] as Array[Dictionary])
	var started: int = Time.get_ticks_msec()
	var found: Dictionary = {}
	var failed: Dictionary = {}
	while not cancelled[0] and menu.is_inside_tree():
		var waited: int = (Time.get_ticks_msec() - started) / 1000
		var r: Dictionary = await Online.call_fn("league_find", {"p_league": league, "p_waited": waited})
		if not r.ok or not r.data is Dictionary or r.data.has("error"):
			failed = r
			break
		if bool(r.data.get("found", false)):
			found = r.data
			break
		if waited >= SEARCH_FOR:
			break
		await menu.get_tree().create_timer(SEARCH_EVERY).timeout
	if not cancelled[0]:
		menu.picker.picked.disconnect(on_pick)
		if menu.picker.visible:
			menu.picker.picked.emit(-1)
	if not failed.is_empty():
		await menu.info(error_text(failed))
	elif found.is_empty() and not cancelled[0]:
		await menu.info("No opponent right now. Try again in a little while.")
	return found
