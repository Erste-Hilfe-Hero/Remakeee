class_name ChallengeMenu
extends RefCounted
## The challenge page (KAMPF plan items 492, 504, 508, 509): every challenge rule with On/Off,
## the run seed (copy it for friends, or take one from the clipboard), and the record so far.
## Opened at a new game and from Settings > Game during a journey.

## Rows: one per rule, then the seed, the clipboard seed (only while rules can be taken), the
## record, the run timer (item 507) and foe scaling (item 496).
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ChallengeRules.ids():
		var c: Dictionary = ChallengeRules.find(id)
		var state: String = Loc.t("On") if ChallengeRules.active(id) else Loc.t("Off")
		out.append({"text": "%s: %s" % [Loc.t(str(c.get("name", id))), state], "hint": Loc.t(str(c.get("text", "")))})
	out.append({"text": Loc.t("Run seed: %s") % ChallengeRules.seed_code(ChallengeRules.ensure_seed()),
		"hint": Loc.t("Copies the seed. A friend who uses it gets the same shuffled wilds and arts.")})
	if ChallengeRules.can_take():
		out.append({"text": Loc.t("Use the seed on the clipboard"), "hint": Loc.t("Takes a seed a friend shared with you.")})
	out.append({"text": Loc.t("Challenge record"), "hint": "\n".join(ChallengeRules.stats_lines())})
	out.append({"text": "%s: %s" % [Loc.t("Run timer"), Loc.t("On") if RunTimer.is_on() else Loc.t("Off")],
		"hint": Loc.t("Shows the journey's play time in the corner, for speed runs.")})
	out.append({"text": "%s: %s" % [Loc.t("Foe scaling"), Loc.t("On") if ChallengeRules.scaling_on() else Loc.t("Off")],
		"hint": Loc.t("Wayfarers' Spirlings stay close to your strongest one, within the ring cap.")})
	return out

static func run(menu: MenuHost) -> void:
	Lexicon.add(GameState.records, "challenges")
	var focus: int = 0
	while menu.is_inside_tree():
		var rows: Array[Dictionary] = entries()
		var idx: int = await menu.pick("Challenges", rows, true, focus)
		if idx < 0:
			return
		focus = idx
		var n: int = ChallengeRules.ids().size()
		if idx < n:
			await _toggle(menu, ChallengeRules.ids()[idx])
		elif idx == n:
			var code: String = ChallengeRules.seed_code(ChallengeRules.run_seed())
			DisplayServer.clipboard_set(code)
			menu.toast(Loc.t("Seed copied: %s") % code)
		elif idx == rows.size() - 2:
			RunTimer.toggle()
		elif idx == rows.size() - 1:
			ChallengeRules.toggle_scaling()
		elif idx == n + 1 and ChallengeRules.can_take():
			var v: int = ChallengeRules.parse_code(DisplayServer.clipboard_get())
			if v < 0:
				await menu.info("There is no seed code on the clipboard.")
			else:
				ChallengeRules.set_seed(v)
				menu.toast(Loc.t("Seed set: %s") % ChallengeRules.seed_code(v))
		else:
			await menu.info("\n".join(ChallengeRules.stats_lines()))

static func _toggle(menu: MenuHost, id: String) -> void:
	var c: Dictionary = ChallengeRules.find(id)
	if ChallengeRules.active(id):
		if await menu.confirm(Loc.t("Drop %s? Your record will remember it.") % Loc.t(str(c.get("name", id))), "Drop it", "Keep it"):
			ChallengeRules.drop(id)
	elif not ChallengeRules.can_take():
		await menu.info("New rules can only be taken before you mend your first Rift.")
	else:
		ChallengeRules.take(id)
