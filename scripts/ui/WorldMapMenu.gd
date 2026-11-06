class_name WorldMapMenu
extends RefCounted
## "Map" in the pause menu (area 3 items 1242-1248, 1273): the world map picture on top, a list
## below. The list zooms (1x / 2x), jumps back to the player's place ("Here"), manages the
## player's own marks and lists every place the player knows with its survey share. Tapping a
## place on the picture picks its row; a place opens its detail page.

const VIEW_H: float = 104.0
const ICON_NAMES: Dictionary = {"star": "Star", "cross": "Cross", "question": "Question",
	"heart": "Heart", "arrow": "Arrow", "hammer": "Hammer"}

## Places for the list: visited first (with share), then sighted ones, each by grid order.
static func place_rows(known: Dictionary) -> Array[Dictionary]:
	var visited: Array[String] = []
	var sighted: Array[String] = []
	for id: String in known:
		match int(known[id]):
			WorldAtlas.Known.VISITED:
				visited.append(id)
			WorldAtlas.Known.SIGHTED:
				sighted.append(id)
	visited.sort()
	sighted.sort()
	var out: Array[Dictionary] = []
	for id: String in visited:
		out.append({"text": "%s  %d%%" % [_name(id), WorldAtlas.percent(id)], "place": id})
	for id: String in sighted:
		out.append({"text": Loc.t("%s (not yet visited)") % _name(id), "place": id, "sighted": true})
	return out

static func _name(id: String) -> String:
	return Loc.t(MapData.load_map(id).display_name) if MapData.exists(id) else id

static func run(host: MenuHost, here: String) -> void:
	var view := WorldMapView.new()
	view.current = here
	view.set_anchors_preset(Control.PRESET_TOP_WIDE)
	view.offset_left = MenuHost.PANEL_MARGIN
	view.offset_right = -MenuHost.PANEL_MARGIN
	view.offset_top = MenuHost.PANEL_MARGIN
	view.offset_bottom = MenuHost.PANEL_MARGIN + VIEW_H
	host.add_child(view)
	var picker: Control = host.picker
	var had_meta: bool = picker.has_meta("top")
	var old_top: Variant = picker.get_meta("top") if had_meta else picker.offset_top
	picker.set_meta("top", MenuHost.PANEL_MARGIN * 2 + VIEW_H)
	var rows_now: Array[Dictionary] = []
	var on_tap: Callable = func(id: String) -> void:
		for i: int in rows_now.size():
			if str(rows_now[i].get("place", "")) == id:
				host.picker.picked.emit(i)
				return
	view.place_tapped.connect(on_tap)
	await host.get_tree().process_frame
	view.center_on_here()
	while true:
		view.refresh(here)
		rows_now = [{"text": Loc.t("Zoom: %dx") % view.zoom}, {"text": "Here"},
			{"text": Loc.t("Marks (%d/%d)") % [GameState.map_marks.size(), Survey.MAX_MARKS]}]
		rows_now.append_array(place_rows(view.known))
		var idx: int = await host.pick("World map", rows_now)
		if idx < 0:
			break
		match idx:
			0:
				view.toggle_zoom()
			1:
				view.center_on_here()
			2:
				await run_marks(host, here)
			_:
				var id: String = str(rows_now[idx].place)
				if bool(rows_now[idx].get("sighted", false)):
					await host.info(Loc.t("%s: seen from afar. Walk there to map it.") % _name(id))
				else:
					await host.info(WorldAtlas.detail_text(id))
	view.queue_free()
	if had_meta:
		picker.set_meta("top", old_top)
	else:
		picker.remove_meta("top")
		picker.offset_top = float(old_top)

## The player's marks: add one where they stand, or pick one to remove it (item 1273).
static func run_marks(host: MenuHost, here: String) -> void:
	while true:
		var rows: Array[Dictionary] = [{"text": "Add a mark here", "disabled": GameState.map_marks.size() >= Survey.MAX_MARKS}]
		for mk: Dictionary in GameState.map_marks:
			rows.append({"text": "%s: %s %d,%d" % [Loc.t(ICON_NAMES[mk.icon]), _name(str(mk.map)), int(mk.x), int(mk.y)]})
		var idx: int = await host.pick("Marks", rows)
		if idx < 0:
			return
		if idx == 0:
			var icons: Array[String] = []
			for k: String in Survey.MARK_ICONS:
				icons.append(ICON_NAMES[k])
			var pick: int = await host.pick_strings("Which symbol?", icons)
			if pick >= 0 and Survey.add_mark(here, GameState.player_cell, Survey.MARK_ICONS[pick]):
				host.toast("Mark set.")
		elif await host.confirm("Remove this mark?", "Remove", "Keep"):
			Survey.remove_mark(idx - 1)
