class_name HallRunner
extends RefCounted
## The battle halls menu and runs on Examiner Hollis's board (BattleHalls.gd holds the rules).
## Kept out of Overworld.gd: the board only calls [method open].

static func _menu(ow: Overworld) -> MenuHost:
	var m := MenuHost.new()
	ow._ui.add_child(m)
	return m

static func _info(ow: Overworld, text: String) -> void:
	var m: MenuHost = _menu(ow)
	await m.info(text)
	m.queue_free()

static func _pick(ow: Overworld, title: String, items: Array[String]) -> int:
	var m: MenuHost = _menu(ow)
	var i: int = await m.pick_strings(title, items)
	m.queue_free()
	return i

static func _species(team: Array[Spirling]) -> Array[String]:
	var out: Array[String] = []
	for s: Spirling in team:
		out.append(s.data.species_name)
	return out

## The halls menu: every open hall, codes, statistics, Hall of Fame and hall stories.
static func open(ow: Overworld) -> void:
	var week: String = WeeklyChallenge.this_week()
	var fest: Dictionary = Season.current()
	while true:
		var halls: Array[Dictionary] = BattleHalls.open_halls(fest)
		var items: Array[String] = []
		for h: Dictionary in halls:
			items.append(Loc.t("%s (best %d of %d)") % [BattleHalls.label(h), int(BattleHalls.stats(str(h.id)).best), BattleHalls.rounds(h)])
		var extra: Array[String] = [Loc.t("Enter a run code"), Loc.t("Fight a team code"), Loc.t("Show my team code"),
			Loc.t("Hall statistics"), Loc.t("Hall of Fame"), Loc.t("Hall stories"), Loc.t("Title on my card"),
			Loc.t("Copy the last hall battle as a replay code")]
		items.append_array(extra)
		var head: String = "%s\n%s" % [Loc.t("This week's rule: %s") % BattleRules.variant_names(BattleHalls.variants_for(week)),
			BattleHalls.week_goal_line(week)]
		var pick: int = await _pick(ow, head, items)
		if pick < 0:
			return
		if pick < halls.size():
			await play(ow, halls[pick], BattleHalls.week_seed(str(halls[pick].id), week), week, fest)
			continue
		match pick - halls.size():
			0:
				await _enter_run_code(ow, week, fest)
			1:
				await _fight_team_code(ow, week)
			2:
				var code: String = BattleHalls.team_code(_species(BattleHalls.scaled(GameState.party, 3)))
				await _info(ow, Loc.t("Your team code: %s") % NameKeyboard.pretty(code) if not code.is_empty() else Loc.t("You need three Spirlings for a team code."))
			3:
				var lines: Array[String] = BattleHalls.stats_lines()
				await _info(ow, "\n".join(lines) if not lines.is_empty() else Loc.t("No hall runs yet."))
			4:
				var fame: Array[String] = BattleHalls.fame_lines()
				await _info(ow, "\n".join(fame) if not fame.is_empty() else Loc.t("The Hall of Fame is empty. It is waiting for you, and it is not patient."))
			5:
				var lore: Array[String] = BattleHalls.lore_lines()
				var m: MenuHost = _menu(ow)
				if lore.is_empty():
					await m.info(Loc.t("Clear a hall to hear its story."))
				else:
					await m.info_pages(lore)
				m.queue_free()
			6:
				await _pick_title(ow)
			7:
				var code: String = BattleHalls.replay_code()
				if code.is_empty():
					await _info(ow, Loc.t("No hall battle to share yet."))
				else:
					DisplayServer.clipboard_set(code)
					await _info(ow, Loc.t("The code is on the clipboard. Anyone can watch it under Records, Online replays."))

static func _enter_run_code(ow: Overworld, week: String, fest: Dictionary) -> void:
	var c: Dictionary = BattleHalls.parse_run_code(await CodePrompt.ask(ow._ui, Loc.t("Run code"), BattleHalls.CODE_LEN))
	var h: Dictionary = BattleHalls.by_id(str(c.get("hall", "")))
	if c.is_empty() or h.is_empty():
		await _info(ow, Loc.t("That code does not open any hall."))
		return
	if not BattleHalls.is_open(h, fest):
		await _info(ow, Loc.t("That hall is closed right now."))
		return
	await play(ow, h, int(c.seed), week, fest)

## A friend's team code: one battle at the hall ring, nothing counts but the fun.
static func _fight_team_code(ow: Overworld, week: String) -> void:
	var names: Array[String] = BattleHalls.parse_team_code(await CodePrompt.ask(ow._ui, Loc.t("Team code"), BattleHalls.CODE_LEN))
	if names.is_empty():
		await _info(ow, Loc.t("That team code is broken or from another version."))
		return
	var foes: Array[Spirling] = BattleHalls.code_team(names, GameState.rng.randi())
	var mine: Array[Spirling] = BattleHalls.scaled(GameState.party, 3)
	var info: Dictionary = {"name": Loc.t("Team code echo"), "ai": int(BattleHalls.data().get("ai", 3)), "money": 0,
		"friendly": true, "player_team": mine, "variants": BattleHalls.variants_for(week)}
	ow.busy = false
	var outcome: BattleModel.Outcome = await ow.start_battle(foes, false, info)
	ow.busy = true
	ow.player.frozen = true
	await ow.say([Loc.t("You beat the team code echo.") if outcome == BattleModel.Outcome.WIN else Loc.t("The team code echo won. Send it back with a rude note.")] as Array[String])

## Draft at the table: the player picks, the echo answers, until both have a team.
static func _draft(ow: Overworld, h: Dictionary, seed_value: int) -> Dictionary:
	var left: Array[String] = BattleHalls.draft_pool(h, seed_value)
	var mine: Array[String] = []
	var size: int = BattleHalls.team_size(h)
	while mine.size() < size and not left.is_empty():
		var i: int = await _pick(ow, Loc.t("Pick %d of %d") % [mine.size() + 1, size], left)
		if i < 0:
			return {}
		mine.append(left[i])
		var res: Dictionary = BattleHalls.draft(BattleHalls.draft_pool(h, seed_value), mine, size)
		left = []
		for n: String in BattleHalls.draft_pool(h, seed_value):
			if not n in res.mine and not n in res.theirs:
				left.append(n)
		if res.theirs.size() == mine.size():
			await ow.say([Loc.t("The echo takes %s.") % str(res.theirs.back())] as Array[String])
	return BattleHalls.draft(BattleHalls.draft_pool(h, seed_value), mine, size)

## One run of [param h] with [param seed_value].
static func play(ow: Overworld, h: Dictionary, seed_value: int, week: String, fest: Dictionary) -> void:
	var kind: String = str(h.get("kind", ""))
	var m: MenuHost = _menu(ow)
	var go: bool = await m.confirm("%s\n%s" % [Loc.t(str(h.get("intro", ""))), Loc.t("Run code: %s") % NameKeyboard.pretty(BattleHalls.run_code(str(h.id), seed_value))])
	m.queue_free()
	if not go:
		return
	var mine: Array[Spirling] = []
	var drafted: Array[Spirling] = []
	if kind == "draft":
		var d: Dictionary = await _draft(ow, h, seed_value)
		if d.is_empty():
			return
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		mine = BattleHalls.build(d.mine, BattleHalls.ring(), r)
		drafted = BattleHalls.build(d.theirs, BattleHalls.ring(), r)
	elif kind == "random" and not bool(h.get("own_team", false)):
		mine = BattleHalls.lottery_team(seed_value)
		await ow.say([Loc.t("Your lottery team: %s.") % ", ".join(_species(mine))] as Array[String])
	else:
		mine = BattleHalls.scaled(GameState.party, BattleHalls.team_size(h))
	if mine.is_empty():
		return
	var elements: Array = (fest.get("elements", []) as Array) if bool(h.get("festival", false)) else []
	var won: int = 0
	var lines: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	for r: int in BattleHalls.rounds(h):
		if BattleHalls.heals_between(h):
			for s: Spirling in mine:
				s.restore()
		if mine.all(func(s: Spirling) -> bool: return s.is_fainted()):
			break
		var foes: Array[Spirling] = drafted if r == 0 and not drafted.is_empty() else BattleHalls.foe_team(h, seed_value, r, elements)
		ow.busy = false
		var outcome: BattleModel.Outcome = await ow.start_battle(foes, false, BattleHalls.battle_info(h, seed_value, r, week, mine))
		ow.busy = true
		ow.player.frozen = true
		BattleHalls.keep_replay(GameState.records.get("last_battle", {}))
		if outcome != BattleModel.Outcome.WIN:
			break
		won += 1
		lines.append_array(BattleHalls.note_win(week))
	lines.append_array(BattleHalls.finish(h, won, _species(mine), week, Time.get_date_string_from_unix_time(Online.unix_now())))
	if won >= BattleHalls.rounds(h) and HallTimes.submit("hall_" + str(h.id), maxi(1, (Time.get_ticks_msec() - t0) / 1000)):
		lines.append(Loc.t("New best time: %s") % HallTimes.fmt(HallTimes.best("hall_" + str(h.id))))
	await ow.say(lines)
	SaveManager.save_game()

## Picks the title shown on the Wanderer card (or none) and sends the card again.
static func _pick_title(ow: Overworld) -> void:
	var titles: Array[String] = BattleHalls.wearable()
	if titles.is_empty():
		await _info(ow, Loc.t("No title yet. Clear a hall or a Spirlog goal first."))
		return
	var items: Array[String] = [Loc.t("No title")]
	for t: String in titles:
		items.append(("> " if t == BattleHalls.worn_title() else "") + Loc.t(t))
	var i: int = await _pick(ow, Loc.t("Title on my card"), items)
	if i < 0:
		return
	BattleHalls.wear("" if i == 0 else titles[i - 1])
	Online.push_profile()
