class_name WardenCard
extends RefCounted
## The card before a Warden battle (plan area 2, item 687): the rule(s), how many Spirlings come and
## their elements as symbols, so the player can still change their team before the fight.

## Pixels between two Spirlings' symbol groups on the picture.
const GAP: int = 4

## The card text for [param def] (already a Second Trial def if it is one).
static func text(def: Dictionary, team: Array[Spirling], difficulty: int) -> String:
	var lines: Array[String] = [str(def.get("trainer", def.get("id", "")))]
	var rules: Array[String] = BattleRules.split_rules(TrainerData.rule_for(def, difficulty))
	if rules.is_empty():
		lines.append(Loc.t("No rule."))
	for r: String in rules:
		lines.append(Loc.t("Rule, %s: %s") % [Loc.t(str(BattleRules.RULES[r].label)), Loc.t(str(BattleRules.RULES[r].text))])
	lines.append(Loc.t("Spirlings: %d") % team.size())
	var names: Array[String] = []
	for e: int in elements(team):
		names.append(Elements.element_name(e))
	if not names.is_empty():
		lines.append(Loc.t("Elements: %s") % ", ".join(names))
	return "\n".join(lines)

## Every element in [param team], in team order, each once.
static func elements(team: Array[Spirling]) -> Array[int]:
	var out: Array[int] = []
	for s: Spirling in team:
		for e: int in s.elements():
			if not e in out:
				out.append(e)
	return out

## A strip with each Spirling's element symbols, groups apart by GAP pixels (null for no team).
static func picture(team: Array[Spirling]) -> ImageTexture:
	if team.is_empty():
		return null
	var w: int = 0
	for s: Spirling in team:
		w += s.elements().size() * (ElementIcons.SIZE + 1) + GAP
	var img := Image.create(maxi(1, w - GAP), ElementIcons.SIZE, false, Image.FORMAT_RGBA8)
	var x: int = 0
	for s: Spirling in team:
		for e: int in s.elements():
			ElementIcons._paint(img, e, UITheme.INK, Vector2i(x, 0))
			x += ElementIcons.SIZE + 1
		x += GAP
	return ImageTexture.create_from_image(img)
