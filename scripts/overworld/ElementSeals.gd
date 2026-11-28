class_name ElementSeals
extends RefCounted
## KAMPF_PLAN_1000 item 117: element seals under some landmarks (data/element_seals.json). The
## landmark shows its seal's element(s); naming an Era I element that hits them very effectively
## (Elements.multiplier x2 or more) breaks the seal once (flag "element_seal_<map>") and gives the
## item behind it. A wrong answer costs nothing, so battle knowledge is the only key.

const PATH: String = "res://data/element_seals.json"
## The answers offered: the eight Era I elements.
const CHOICES: int = 8

static var _seals: Dictionary = {}

static func all() -> Dictionary:
	if _seals.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary and (d as Dictionary).get("seals") is Dictionary:
			_seals = d.seals
	return _seals

static func flag(map_id: String) -> String:
	return "element_seal_" + map_id

## The seal under the landmark of [param map_id], or {}.
static func seal_for(map_id: String) -> Dictionary:
	return all().get(map_id, {})

## The seal's elements as ids.
static func elements(seal: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for n: Variant in seal.get("elements", []):
		var e: int = Elements.E.keys().find(str(n))
		if e >= 0:
			out.append(e)
	return out

## True when [param element] breaks [param seal].
static func breaks(seal: Dictionary, element: int) -> bool:
	var els: Array[int] = elements(seal)
	return not els.is_empty() and Elements.multiplier(element, els) >= 2.0

## Tries [param element] on the seal of [param map_id]: {"ok": true, "item": id} once it breaks,
## {"ok": false} for a wrong answer or a seal that is gone.
static func answer(map_id: String, element: int) -> Dictionary:
	var seal: Dictionary = seal_for(map_id)
	if seal.is_empty() or GameState.has_flag(flag(map_id)) or not breaks(seal, element):
		return {"ok": false}
	GameState.set_flag(flag(map_id))
	var item: String = str(seal.get("item", ""))
	if not item.is_empty():
		GameState.add_item(item)
	return {"ok": true, "item": item}

## The seal's elements as names joined by " + " ("Tide + Stone").
static func seal_name(seal: Dictionary) -> String:
	var names: Array[String] = []
	for e: int in elements(seal):
		names.append(Elements.element_name(e))
	return " + ".join(names)

## After the landmark's line: offers the seal of [param map_id] in a menu on [param parent].
static func run(parent: Node, map_id: String) -> void:
	var seal: Dictionary = seal_for(map_id)
	if seal.is_empty() or GameState.has_flag(flag(map_id)):
		return
	var menu := MenuHost.new()
	parent.add_child(menu)
	var names: Array[String] = []
	for e: int in CHOICES:
		names.append(Elements.element_name(e))
	var pick: int = await menu.pick_strings(Loc.t("A seal is cut into the base: %s. Which element breaks it?") % seal_name(seal), names)
	if pick >= 0:
		var r: Dictionary = answer(map_id, pick)
		if bool(r.ok):
			Sound.sfx("confirm")
			await menu.info(Loc.t("The seal cracks. Someone hid %s behind it and never came back for it.") % Loc.t(str(Database.item(str(r.item)).get("name", r.item))))
		else:
			await menu.info("The seal hums, smug and whole. It has met your kind before.")
	menu.queue_free()
