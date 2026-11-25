class_name SaveHistoryMenu
extends RefCounted
## Settings > Account > Earlier saves (plan area 7, item 3009): the server keeps the last 5
## versions of each slot. Each shows its date, place and play time and can be brought back; the
## version it replaces stays in the list, so bringing one back can be undone.

static func date_text(unix: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix + Time.get_time_zone_from_system().get("bias", 0) * 60)
	return "%02d.%02d. %02d:%02d" % [int(d.day), int(d.month), int(d.hour), int(d.minute)]

static func entry_line(h: Dictionary) -> String:
	return "%s  %s" % [date_text(int(h.saved_at)), str(h.summary)]

## Size of the place picture in each row (200 list item 17).
const PICTURE: Vector2i = Vector2i(20, 14)

static var _place_ids: Dictionary = {}
static var _pictures: Dictionary = {}

## The map id of the place a save summary line starts with ("" when no map has that name).
## Marks in front of the place (the Iron Oath chain, the full journey star) are skipped.
static func place_id(summary: String) -> String:
	if _place_ids.is_empty():
		var dir: String = MapData.DIR
		var files: PackedStringArray = DirAccess.get_files_at(dir)
		files.sort()
		for f: String in files:
			if not f.ends_with(".json"):
				continue
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
			var nm: String = str((raw as Dictionary).get("name", "")) if raw is Dictionary else ""
			if not nm.is_empty() and not _place_ids.has(nm):
				_place_ids[nm] = f.get_basename()
	var best: String = ""
	var best_len: int = 0
	for nm: String in _place_ids:
		var at: int = summary.find(nm + "  ")
		if at >= 0 and at <= 4 and nm.length() > best_len:
			best = _place_ids[nm]
			best_len = nm.length()
	return best

## A small picture of map [param map_id] (the whole map shrunk, in the minimap's colours:
## ground paper, solid grey, water mid), or null for an unknown map.
static func place_picture(map_id: String) -> Texture2D:
	if map_id.is_empty() or not MapData.exists(map_id):
		return null
	if _pictures.has(map_id):
		return _pictures[map_id]
	var m: MapData = MapData.load_map(map_id)
	if m == null or m.width <= 0 or m.height <= 0:
		return null
	var img: Image = Image.create(PICTURE.x, PICTURE.y, false, Image.FORMAT_RGBA8)
	img.fill(UITheme.INK)
	for y: int in range(1, PICTURE.y - 1):
		for x: int in range(1, PICTURE.x - 1):
			var c := Vector2i((x - 1) * m.width / (PICTURE.x - 2), (y - 1) * m.height / (PICTURE.y - 2))
			var col: Color = UITheme.DISABLED
			if m.kind_at(c) == TilesetFactory.Kind.WATER:
				col = UITheme.MID
			elif m.is_walkable(c):
				col = UITheme.BG
			img.set_pixel(x, y, col)
	_pictures[map_id] = ImageTexture.create_from_image(img)
	return _pictures[map_id]

## The rows of the list: date, place and play time, with the place's picture.
static func entry_rows(saves: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in saves:
		var row: Dictionary = {"text": entry_line(h)}
		var pic: Texture2D = place_picture(place_id(str(h.summary)))
		if pic != null:
			row["icon"] = pic
		out.append(row)
	return out

## Returns true when the game went back to the title (the running journey was replaced).
static func run(menu: MenuHost) -> bool:
	var slots: Array[String] = []
	for n: int in [1, 2, 3]:
		slots.append(Loc.t("Slot %d") % n + "  " + SaveManager.slot_summary(n))
	var si: int = await menu.pick_strings("Earlier saves of which slot?", slots)
	if si < 0:
		return false
	var slot: int = si + 1
	var r: Dictionary = await Online.call_fn("save_history_list", {"p_slot": slot})
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
		await menu.info(Online.error_text(str(r.get("error", ""))))
		return false
	var saves: Array = r.data.get("saves", [])
	if saves.is_empty():
		await menu.info("There are no earlier saves of this slot yet.")
		return false
	var hi: int = await menu.pick("Earlier saves (the server keeps the last 5)", entry_rows(saves))
	if hi < 0:
		return false
	if not await menu.confirm(Loc.t("Bring back the save from %s? The current one stays in this list.") % date_text(int(saves[hi].saved_at))):
		return false
	var playing: bool = GameState.in_game and SaveManager.slot == slot
	if playing:
		SaveManager.save_game()
		await Online.push(slot)
	var res: Dictionary = await Online.call_fn("save_restore", {"p_slot": slot, "p_id": int(saves[hi].id)})
	if not res.ok or not res.data is Dictionary or not bool(res.data.get("ok", false)):
		await menu.info(Online.error_text(str(res.get("error", ""))))
		return false
	Online.dirty.erase(slot)
	await Online.pull(slot)
	if playing:
		await menu.info("The earlier save is back. The game returns to the title, then continue from there.")
		GameState.in_game = false
		menu.get_tree().change_scene_to_file(AccountMenu.TITLE_SCENE)
		return true
	await menu.info("The earlier save is back.")
	return false
