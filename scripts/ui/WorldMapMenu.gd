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
		# Only the name, without the "14%" of visited places: "(not yet visited)" was cut off at
		# 144 px (plan Chimora 100, item 40). The hint line under the list says it in full.
		out.append({"text": _name(id), "place": id, "sighted": true, "hint": "Not yet visited."})
	return out

static func _name(id: String) -> String:
	return Loc.t(MapData.load_map(id).display_name) if MapData.exists(id) else id

static func run(host: MenuHost, here: String) -> void:
	# The map in the era's layout (EraMenus): the picture over a list in Era I to III, a
	# picture that takes the upper part of the phone with Zoom, Here and Marks as a button bar
	# and an info panel for the focused place in Era IV, a pulsing "you are here" in Era V.
	# The picture is the list's header (plan Chimora 100, items 40 and 55): the title and the
	# back button stay on top and every row starts below the picture. The header is rebuilt for
	# each list, so zoom and pan are carried over.
	var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "map")
	var view_h: float = float(lay.get("view_h", VIEW_H))
	var bar: bool = str(lay.get("actions", "row")) == "bar"
	var panel: bool = str(lay.get("panel", "none")) != "none"
	var rows_now: Array[Dictionary] = []
	var keep: Dictionary = {}
	while true:
		var view := WorldMapView.new()
		view.current = here
		view.pulse = bool(lay.get("pulse", false))
		view.custom_minimum_size = Vector2(0, view_h)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.restore(keep)
		view.place_tapped.connect(func(id: String) -> void:
			for i: int in rows_now.size():
				if str(rows_now[i].get("place", "")) == id:
					host.picker.picked.emit(i)
					return)
		view.refresh(here)
		var acts: Array[String] = [Loc.t("Zoom: %dx") % view.zoom, Loc.t("Here"),
			Loc.t("Marks") if bar else Loc.t("Marks (%d/%d)") % [GameState.map_marks.size(), Survey.MAX_MARKS]]
		rows_now = []
		if not bar:
			for a: String in acts:
				rows_now.append({"text": a})
		var first_place: int = rows_now.size()
		for r: Dictionary in place_rows(view.known):
			var pic: Texture2D = EraMenuKit.icon_for("dot" if bool(r.get("sighted", false)) else "place", lay)
			if pic != null:
				r["icon"] = pic
			if panel and not bool(r.get("sighted", false)):
				r["hint"] = WorldAtlas.detail_text(str(r.place)).get_slice("\n", 1)
			rows_now.append(r)
		var idx: int = await host.pick_screen("map", "World map", rows_now, {"tabs": acts if bar else ([] as Array[String]), "tab": -1,
			"tab_icons": [null, null, EraMenuKit.icon_for("Shortcuts", lay)], "header": view,
			"panel_text": "Tap a place on the map or in the list."})
		keep = view.state() if is_instance_valid(view) else keep
		var act: int = ListPicker.tab_of(idx) if bar else (idx if idx >= 0 and idx < first_place else -1)
		if idx < 0 and act < 0:
			break
		match act:
			0:
				keep["zoom"] = 2 if int(keep.get("zoom", 1)) == 1 else 1
				keep["here"] = true
			1:
				keep["here"] = true
			2:
				await run_marks(host, here)
			_:
				var id: String = str(rows_now[idx].place)
				if bool(rows_now[idx].get("sighted", false)):
					await host.info(Loc.t("%s: seen from afar. Walk there to map it.") % _name(id))
				else:
					await host.info(WorldAtlas.detail_text(id))

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
