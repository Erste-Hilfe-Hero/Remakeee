class_name WardenCard
extends RefCounted
## The card before a Warden battle (plan area 2, item 687): the rule(s), how many Spirlings come and
## their elements as symbols, so the player can still change their team before the fight.

## Pixels between two Spirlings' symbol groups on the picture.
const GAP: int = 4
## KAMPF_PLAN_1000 item 111: each Rift's Warden has one theme element (data/warden_themes.json).
const THEMES_PATH: String = "res://data/warden_themes.json"
static var _themes: Dictionary = {}

## Warden id -> element name ("EMBER"), from THEMES_PATH.
static func themes() -> Dictionary:
	if _themes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(THEMES_PATH))
		if d is Dictionary and (d as Dictionary).get("themes") is Dictionary:
			_themes = d.themes
	return _themes

## The theme element of the Warden of [param def] (its "warden" id), or -1.
static func theme(def: Dictionary) -> int:
	var key: String = str(themes().get(str(def.get("warden", "")), ""))
	return Elements.E.keys().find(key)

## The card text for [param def] (already a Second Trial def if it is one). A [param cap] below
## the top ring (Veteran and up, item 736) adds the ring cap beside the Warden's highest ring.
static func text(def: Dictionary, team: Array[Spirling], difficulty: int, cap: int = 0) -> String:
	var lines: Array[String] = [str(def.get("trainer", def.get("id", "")))]
	var rules: Array[String] = BattleRules.split_rules(TrainerData.rule_for(def, difficulty))
	if rules.is_empty():
		lines.append(Loc.t("No rule."))
	for r: String in rules:
		lines.append(Loc.t("Rule, %s: %s") % [Loc.t(str(BattleRules.RULES[r].label)), Loc.t(str(BattleRules.RULES[r].text))])
	var th: int = theme(def)
	if th >= 0:
		lines.append(Loc.t("Rift theme: %s") % Elements.element_name(th))
	lines.append(Loc.t("Spirlings: %d") % team.size())
	if cap > 0 and cap < Spirling.STORY_RING and not team.is_empty():
		var top: int = 0
		for sp: Spirling in team:
			top = maxi(top, sp.level)
		lines.append(Loc.t("Ring cap: R%d. The Warden's highest: R%d.") % [cap, top])
	var names: Array[String] = []
	for e: int in elements(team):
		names.append(Elements.element_name(e))
	if not names.is_empty():
		lines.append(Loc.t("Elements: %s") % ", ".join(names))
	return "\n".join(lines)

## Warden Lore (shop item 4883): every Spirling with its Ring, techniques and held item, and the
## items the Warden brings into the battle.
static func lore(def: Dictionary, team: Array[Spirling]) -> String:
	var lines: Array[String] = [Loc.t("Warden Lore:")]
	for s: Spirling in team:
		var moves: Array[String] = []
		for mv: MoveData in s.moves:
			moves.append(Loc.t(mv.move_name))
		var line: String = "%s R%d: %s" % [s.display_name(), s.level, ", ".join(moves)]
		if not s.held.is_empty():
			line += " " + Loc.t("(holds %s)") % Loc.t(str(Database.item(s.held).get("name", s.held)))
		lines.append(line)
	var gifts: Array[String] = []
	var items: Variant = def.get("items", {})
	if items is Dictionary:
		for id: Variant in items:
			gifts.append("%s x%d" % [Loc.t(str(Database.item(str(id)).get("name", id))), int(items[id])])
	lines.append(Loc.t("Items: %s") % ", ".join(gifts) if not gifts.is_empty() else Loc.t("Items: none"))
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
