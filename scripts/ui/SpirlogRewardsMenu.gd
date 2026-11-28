class_name SpirlogRewardsMenu
extends RefCounted
## Spirlog > Book rewards (Chimora 1.3.2): the book in percent (seen, bonded, Gleam) and the
## reward steps of SpirlogRewards; a reached step is taken here once.

## Rows above the steps: seen, bonded and Gleam in percent of the whole book, with a bar each.
const SHARE_ROWS: int = 3

## The share rows, then one row per step: what it is, what it gives, and taken / ready / how far.
static func rows(spirlog: Dictionary, records: Dictionary) -> Array[Dictionary]:
	var c: Dictionary = SpirlogRewards.counts(spirlog)
	var out: Array[Dictionary] = []
	var lines: Array[String] = SpirlogRewards.percent_lines(spirlog)
	var short: Array[String] = [Loc.t("Seen: %d%%"), Loc.t("Bonded: %d%%"), GleamRules.STAR + " " + Loc.t("Gleam: %d%%")]
	for i: int in SHARE_ROWS:
		var n: int = int(c[["seen", "bonded", "gleam"][i]])
		var share: float = float(n) / maxf(1.0, float(c.total))
		# One short line each, so the bar never runs through a wrapped second line.
		out.append({"text": short[i] % SpirlogBook.percent(n, int(c.total)), "hint": lines[i] + " " + Loc.t("Of every kind in the game."),
			"decorate": func(b: Button) -> void: PauseMenu._draw_progress(b, share)})
	for s: Dictionary in SpirlogRewards.steps():
		var p: Dictionary = SpirlogRewards.progress(s, c)
		var have: int = mini(int(p.have), int(p.need))
		var status: String
		if SpirlogRewards.is_claimed(records, str(s.id)):
			status = Loc.t("taken")
		elif SpirlogRewards.reached(s, c):
			status = Loc.t("ready!")
		else:
			status = "%d/%d" % [have, int(p.need)]
		out.append({"text": "%s: %s" % [SpirlogRewards.step_name(s), status],
			"hint": SpirlogRewards.reward_text(s)})
	return out

static func title() -> String:
	return Loc.t("Spirlog book")

static func run(menu: MenuHost) -> void:
	var focus: int = SHARE_ROWS
	while true:
		var idx: int = await menu.pick_screen("dex", title(), rows(GameState.spirlog, GameState.records),
			{"focus": focus, "panel_text": "Take a reward once its step is reached."})
		if idx < 0:
			return
		focus = idx
		if idx < SHARE_ROWS:
			continue
		var s: Dictionary = SpirlogRewards.steps()[idx - SHARE_ROWS]
		var lines: Array[String] = SpirlogRewards.claim(str(s.id), GameState.spirlog, GameState.records)
		if lines.is_empty():
			var what: String = Loc.t("Already taken.") if SpirlogRewards.is_claimed(GameState.records, str(s.id)) \
				else Loc.t("Not reached yet.")
			await menu.info(what + "\n" + SpirlogRewards.reward_text(s))
			continue
		Sound.sfx("coin")
		# Saved at once, so the reward is kept (and goes online with the save).
		SaveManager.save_game()
		await menu.info("\n".join(lines))
