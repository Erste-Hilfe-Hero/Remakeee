class_name StoryValidator
extends RefCounted
## Checks dialogue (data/dialogue), cut-scenes (data/scenes) and story duels
## (data/story_battles.json) for dead references (plan item 1342): every "next" / "else",
## every scene id, every item in "give_item", every species in "has_species", every
## condition name, every story duel. Used by tools/validate_data.gd and the GUT suite.

## Dialogue actions the overworld knows, read from its action table so new actions from
## other areas count without editing this list.
static func known_actions() -> PackedStringArray:
	var out: PackedStringArray = []
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var re := RegEx.create_from_string("\"([a-z_]+)\": _action_")
	for m: RegExMatch in re.search_all(src):
		out.append(m.get_string(1))
	return out

static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	Database.load_all()
	for f: String in DirAccess.get_files_at(Dialogue.DIR):
		if not f.ends_with(".json"):
			continue
		var file: String = f.get_basename()
		var data: Dictionary = Dialogue.file_data(file)
		for key: Variant in data:
			if str(key).begins_with("_"):
				continue
			_check_entry("%s/%s" % [file, key], Dialogue.normalize(data[key]), errors)
	if DirAccess.dir_exists_absolute(ScenePlayer.DIR):
		for f: String in DirAccess.get_files_at(ScenePlayer.DIR):
			if f.ends_with(".json"):
				_check_scene(f.get_basename(), errors)
	_check_placements(errors)
	for id: Variant in StoryBattles.data():
		if str(id).begins_with("_"):
			continue
		var def: Dictionary = StoryBattles.get_def(str(id))
		var where: String = "story_battles/%s" % id
		if TrainerData.team_entries(def, "").is_empty():
			errors.append("%s: no team" % where)
		for e: Variant in TrainerData.team_entries(def, ""):
			if Database.species(str((e as Dictionary).get("species", ""))) == null:
				errors.append("%s: unknown species '%s'" % [where, (e as Dictionary).get("species", "")])
		for k: String in ["defeat", "lose"]:
			if def.has(k) and not Dialogue.exists(str(def[k])):
				errors.append("%s: %s dialogue '%s' does not exist" % [where, k, def[k]])
	return errors

static func _check_entry(ref: String, e: Dictionary, errors: PackedStringArray) -> void:
	for k: String in ["next", "else"]:
		if e.has(k) and not Dialogue.exists(Dialogue.resolve_ref(ref, str(e[k]))):
			errors.append("%s: %s '%s' does not exist" % [ref, k, e[k]])
	if e.has("if"):
		_check_cond(ref, e.get("if"), errors)
	if e.has("action"):
		_check_action(ref, str(e.action), errors)
	for v: Variant in Dialogue.variants(e):
		if v is Dictionary and (v as Dictionary).has("if"):
			_check_cond(ref, v.get("if"), errors)
	var choices: Variant = e.get("choices", [])
	if not choices is Array:
		errors.append("%s: choices must be a list" % ref)
		return
	if not (choices as Array).is_empty() and ((choices as Array).size() < 2 or (choices as Array).size() > 3):
		errors.append("%s: a choice needs 2 or 3 answers" % ref)
	for c: Variant in choices:
		if not c is Dictionary or str((c as Dictionary).get("text", "")).is_empty():
			errors.append("%s: every answer needs a text" % ref)
			continue
		var cd: Dictionary = c
		if cd.has("next") and not Dialogue.exists(Dialogue.resolve_ref(ref, str(cd.next))):
			errors.append("%s: answer next '%s' does not exist" % [ref, cd.next])
		if cd.has("action"):
			_check_action(ref, str(cd.action), errors)
		if cd.has("if"):
			_check_cond(ref, cd.get("if"), errors)

static func _check_cond(ref: String, cond: Variant, errors: PackedStringArray) -> void:
	if not cond is Dictionary:
		errors.append("%s: 'if' must be an object" % ref)
		return
	for k: Variant in cond:
		if not str(k) in Dialogue.CONDITIONS:
			errors.append("%s: unknown condition '%s'" % [ref, k])
	for sp: Variant in Dialogue._as_list(cond.get("has_species", [])):
		if Database.species(str(sp)) == null:
			errors.append("%s: has_species '%s' is no Spirling" % [ref, sp])
	for it: Variant in Dialogue._as_list(cond.get("has_item", [])):
		if Database.item(str(it)).is_empty():
			errors.append("%s: has_item '%s' is no item" % [ref, it])
	for el: Variant in Dialogue._as_list(cond.get("has_element", [])):
		if not Elements.E.has(str(el).to_upper()):
			errors.append("%s: has_element '%s' is no element" % [ref, el])

## Checks a ";"-separated action string.
static func _check_action(ref: String, action: String, errors: PackedStringArray) -> void:
	var known: PackedStringArray = known_actions()
	for one: String in action.split(";", false):
		var parts: PackedStringArray = one.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		if not parts[0] in known:
			errors.append("%s: unknown action '%s'" % [ref, parts[0]])
			continue
		match parts[0]:
			"give_item":
				if parts.size() < 2 or Database.item(parts[1]).is_empty():
					errors.append("%s: give_item '%s' is no item" % [ref, parts[1] if parts.size() > 1 else ""])
			"scene":
				if parts.size() < 2 or not ScenePlayer.exists(parts[1]):
					errors.append("%s: scene '%s' does not exist" % [ref, parts[1] if parts.size() > 1 else ""])
			"battle":
				if parts.size() < 2 or not StoryBattles.has(parts[1]):
					errors.append("%s: story battle '%s' does not exist" % [ref, parts[1] if parts.size() > 1 else ""])
			"quest_show":
				if parts.size() >= 4 and Database.item(parts[3]).is_empty():
					errors.append("%s: quest_show reward '%s' is no item" % [ref, parts[3]])
				if parts.size() >= 3 and Database.species(parts[2]) == null:
					errors.append("%s: quest_show species '%s' is no Spirling" % [ref, parts[2]])

static func _check_scene(id: String, errors: PackedStringArray) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ScenePlayer.DIR + id + ".json"))
	if not raw is Dictionary or not (raw as Dictionary).get("steps") is Array:
		errors.append("scenes/%s: needs a 'steps' list" % id)
		return
	var where: String = "scenes/%s" % id
	for s: Variant in raw.steps:
		if not s is Dictionary:
			errors.append("%s: step is not an object" % where)
			continue
		var step: Dictionary = s
		var kind: String = ScenePlayer.step_kind(step)
		match kind:
			"":
				errors.append("%s: unknown step %s" % [where, JSON.stringify(step)])
			"dialogue":
				if not Dialogue.exists(str(step.dialogue)):
					errors.append("%s: dialogue '%s' does not exist" % [where, step.dialogue])
			"give_item":
				if Database.item(str(step.give_item)).is_empty():
					errors.append("%s: give_item '%s' is no item" % [where, step.give_item])
			"battle":
				if not StoryBattles.has(str(step.battle)):
					errors.append("%s: story battle '%s' does not exist" % [where, step.battle])
			"action":
				_check_action(where, str(step.action), errors)
			"move":
				if not step.has("path") and not step.has("to"):
					errors.append("%s: move needs 'path' or 'to'" % where)

## data/story_npcs.json: dialogue refs exist, and on maps that exist the cells are inside
## the map and no figure stands on a warp.
static func _check_placements(errors: PackedStringArray) -> void:
	for map_id: Variant in StoryPlacements.data():
		if str(map_id).begins_with("_"):
			continue
		var extra: Dictionary = StoryPlacements.for_map(str(map_id))
		var m: MapData = MapData.load_map(str(map_id)) if MapData.exists(str(map_id)) else null
		for kind: String in ["npcs", "signs"]:
			for e: Variant in extra.get(kind, []):
				var d: Dictionary = e
				var where: String = "story_npcs/%s" % map_id
				if d.has("dialogue") and not Dialogue.exists(str(d.dialogue)):
					errors.append("%s: dialogue '%s' does not exist" % [where, d.dialogue])
				if m == null:
					continue
				var c := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
				if not m.in_bounds(c):
					errors.append("%s: %s at %s is outside the map" % [where, kind, c])
				elif kind == "npcs" and not m.warp_at(c).is_empty():
					errors.append("%s: figure at %s stands on a warp" % [where, c])
