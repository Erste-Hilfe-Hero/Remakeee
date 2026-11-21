class_name DifficultyTable
extends RefCounted
## The six lines shown for each difficulty on the difficulty page (plan area 2, item 745): foe
## rings, foe Spark, AI tier, keepsakes, items in battle and the ring cap. Ali (4 Nov) keeps the
## difficulty in the settings, so the page is the settings picker, not a new-game step.

## The lines for [param d] (a GameState.Difficulty value), translated.
static func lines(d: int) -> Array[String]:
	d = clampi(d, 0, GameState.AI_LEVELS.size() - 1)
	var out: Array[String] = []
	var shift: int = GameState.FOE_LEVEL_SHIFT[d]
	out.append(Loc.t("Foe rings: %s") % ("%+d" % shift if shift != 0 else Loc.t("as listed")))
	out.append(Loc.t("Foe Spark: %d in every stat") % GameState.FOE_SPARK[d])
	var ai: int = TrainerData.TAMER_AI if d == GameState.Difficulty.TAMER else GameState.AI_LEVELS[d]
	var warden_ai: int = TrainerData.ai_tier({"warden": "x"}, GameState.AI_LEVELS[d], d)
	out.append(Loc.t("AI tier: %d, Wardens %d") % [ai, warden_ai])
	var keep: String = Loc.t("no keepsakes")
	if d == GameState.Difficulty.RIFT_BORN:
		keep = Loc.t("on every Warden Spirling")
	elif TrainerData.keeps_keepsakes(d):
		keep = Loc.t("some foes")
	out.append(Loc.t("Keepsakes: %s") % keep)
	out.append(Loc.t("Items in battle: %s") % (Loc.t("no") if d == GameState.Difficulty.RIFT_BORN else Loc.t("yes")))
	out.append(Loc.t("Ring cap: %s") % (Loc.t("rises with each sealed Rift (R%d to R%d)") % [GameState.LEVEL_CAPS[0], GameState.LEVEL_CAPS[-1]]
		if d >= GameState.Difficulty.VETERAN else Loc.t("no cap")))
	return out

## The hint under a difficulty row: its short line, then the six lines.
static func hint(d: int, short: String) -> String:
	return Loc.t(short) + "\n" + "\n".join(lines(d))
