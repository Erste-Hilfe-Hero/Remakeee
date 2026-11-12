class_name BattleUiStyle
extends RefCounted
## Battle UI colours per era (design items 135, 137, 236, 178): coloured type badges, colour-coded
## command buttons and matchup feedback from Era II on. Colour-blind mode adds shapes on top.

static func colour_on(era: int) -> bool:
	return era >= int(HpBarStyle.cfg().get("colour_from_era", 2))

## Era I keeps ink badges; later eras draw each element in its own colour.
static func badge_color(era: int, element: int) -> Color:
	return Elements.color(element) if colour_on(era) else UITheme.INK

## Stripe colour for a command ("move", "swap", "item", "bond", "run"); transparent in Era I.
static func command_color(era: int, command: String) -> Color:
	if not colour_on(era):
		return Color.TRANSPARENT
	return Color(String(HpBarStyle.cfg().get("command_colors", {}).get(command, "6a4256")))

## "strong", "weak", "none" (no effect) or "" (neutral or unknown) for a multiplier.
static func matchup(mult: float) -> String:
	if mult < 0.0 or is_equal_approx(mult, 1.0):
		return ""
	if is_zero_approx(mult):
		return "none"
	return "strong" if mult > 1.0 else "weak"

static func matchup_color(era: int, mult: float) -> Color:
	var m: String = matchup(mult)
	if m.is_empty() or not colour_on(era):
		return UITheme.INK
	return Color(String(HpBarStyle.cfg().get("matchup_colors", {}).get(m, "2a1e2c")))

## Shape mark shown before the move line in colour-blind mode, so the matchup never rests on colour.
static func matchup_mark(mult: float, color_blind: bool) -> String:
	var m: String = matchup(mult)
	if m.is_empty() or not color_blind:
		return ""
	return String(HpBarStyle.cfg().get("matchup_marks", {}).get(m, ""))

## Colour-blind mode forces the Era I fill patterns on the HP bar in every era.
static func hp_pattern(era: int, color_blind: bool) -> bool:
	return color_blind or bool(HpBarStyle.for_era(era).get("pattern", false))
