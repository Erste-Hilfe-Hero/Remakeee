class_name EraDexViews
extends RefCounted
## Spirlog views that came with the eras (docs/ERA_FEEL_MENUS.md): the small preview beside
## the number list (Era I), the area map (Era II), the size compare and the cry button
## (Era III). Earlier eras say the same in words on the Spirlog page.

## Places (world map cells) where [param sd] was seen.
static func places_of(sd: SpirlingData, spirlog: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in SpirlogBook.found_on(sd, spirlog):
		var p: String = WorldAtlas.place_of(str(f.map))
		if not p.is_empty() and not p in out:
			out.append(p)
	return out

## The world map in small: every place the player knows as a cell, the places where the kind
## was seen filled in. Unknown places stay off the map.
class AreaMap extends Control:
	var marked: Array[String] = []
	var known: Dictionary = {}
	var cell: int = 4

	func _ready() -> void:
		name = "area_map"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		known = WorldAtlas.known(GameState.current_map)
		if custom_minimum_size == Vector2.ZERO:
			var g: Vector2i = known_bounds(known).size
			custom_minimum_size = Vector2(g.x * cell + 2, g.y * cell + 2)

	## Cell size that fits the whole grid into [param area].
	static func fit_cell(area: Vector2, grid: Vector2i) -> int:
		if grid.x <= 0 or grid.y <= 0:
			return 1
		return maxi(1, int(minf((area.x - 2.0) / grid.x, (area.y - 2.0) / grid.y)))

	## The grid cells that hold a place the player knows: {"from": Vector2i, "size": Vector2i}.
	## The whole world is five regions wide; the map shows only the part the player has seen.
	static func known_bounds(known_places: Dictionary) -> Dictionary:
		var lo := Vector2i(999, 999)
		var hi := Vector2i(-999, -999)
		for id: String in WorldAtlas.places():
			if int(known_places.get(id, 0)) == WorldAtlas.Known.UNKNOWN:
				continue
			var gc: Vector2i = WorldAtlas.grid_cell(id)
			lo = Vector2i(mini(lo.x, gc.x), mini(lo.y, gc.y))
			hi = Vector2i(maxi(hi.x, gc.x), maxi(hi.y, gc.y))
		if hi.x < lo.x:
			return {"from": Vector2i.ZERO, "size": Vector2i.ONE}
		return {"from": lo, "size": hi - lo + Vector2i.ONE}

	func _draw() -> void:
		var bounds: Dictionary = known_bounds(known)
		var from: Vector2i = bounds.from
		var g: Vector2i = bounds.size
		var c: int = mini(fit_cell(size, g), 16)
		var origin: Vector2 = ((size - Vector2(g.x * c, g.y * c)) / 2.0).floor()
		draw_rect(Rect2(origin - Vector2.ONE, Vector2(g.x * c + 2, g.y * c + 2)), UITheme.ACCENT.lerp(UITheme.BG, 0.5))
		for id: String in WorldAtlas.places():
			if int(known.get(id, 0)) == WorldAtlas.Known.UNKNOWN:
				continue
			var gc: Vector2i = WorldAtlas.grid_cell(id) - from
			var r := Rect2(origin + Vector2(gc.x * c, gc.y * c), Vector2(c, c)).grow(-0.5 if c > 2 else 0.0)
			if id in marked:
				draw_rect(r, UITheme.INK)
			else:
				draw_rect(r, UITheme.MID, false, 1.0)

## You and the kind side by side on one ground line, drawn to scale.
class SizeCompare extends Control:
	var sd: SpirlingData
	var you_m: float = 1.6

	func _ready() -> void:
		name = "size_compare"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 104)

	## Pixel heights [you, kind] so the taller one fills [param room].
	static func heights(you_m: float, kind_m: float, room: float) -> Vector2:
		var top: float = maxf(maxf(you_m, kind_m), 0.01)
		return Vector2(roundf(room * you_m / top), maxf(2.0, roundf(room * kind_m / top)))

	func _draw() -> void:
		var room: float = minf(size.y - 6.0, 96.0)
		var h: Vector2 = heights(you_m, EraMenus.height_m(sd.height) if sd != null else 0.0, room)
		var ground: float = size.y - 3.0
		draw_line(Vector2(2, ground), Vector2(size.x - 2, ground), UITheme.MID, 1.0)
		# The Wayfarer as a plain figure: head, coat, two legs.
		var x: float = floorf(size.x * 0.28)
		var w: float = maxf(4.0, roundf(h.x * 0.3))
		var head: float = maxf(2.0, roundf(h.x * 0.18))
		draw_rect(Rect2(x - head / 2.0, ground - h.x, head, head), UITheme.INK)
		draw_rect(Rect2(x - w / 2.0, ground - h.x + head + 1, w, roundf(h.x * 0.45)), UITheme.INK)
		var leg_top: float = ground - h.x + head + 1 + roundf(h.x * 0.45)
		draw_rect(Rect2(x - w / 2.0, leg_top, maxf(1.0, floorf(w / 2.0) - 1), ground - leg_top), UITheme.INK)
		draw_rect(Rect2(x + 1, leg_top, maxf(1.0, floorf(w / 2.0) - 1), ground - leg_top), UITheme.INK)
		if sd == null:
			return
		var tex: Texture2D = MiniSprite.of(sd.species_name, 64)
		var kx: float = floorf(size.x * 0.68)
		if tex != null:
			draw_texture_rect(tex, Rect2(kx - h.y / 2.0, ground - h.y, h.y, h.y), false)
		else:
			draw_rect(Rect2(kx - h.y / 2.0, ground - h.y, h.y, h.y), UITheme.MID)

## The preview beside the Spirlog list: the focused kind's sprite and, from Era II, the area
## map with the places where it was seen. Unseen kinds show an empty frame.
class Preview extends HBoxContainer:
	var px: int = 24
	var with_map: bool = false
	var _sprite: TextureRect
	var _label: Label
	var map: AreaMap

	func _ready() -> void:
		name = "dex_preview"
		add_theme_constant_override("separation", 4)
		_sprite = TextureRect.new()
		_sprite.custom_minimum_size = Vector2(px, px)
		_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		_label = Label.new()
		_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(1, px)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_color", UITheme.MID)
		add_child(_label)
		if with_map:
			map = AreaMap.new()
			map.cell = 2
			map.custom_minimum_size = Vector2(px + 12, px)
			add_child(map)

	## Shows [param sd] (null: nothing focused that is a kind).
	func show_kind(sd: SpirlingData) -> void:
		if _sprite == null:
			return
		var seen: bool = sd != null and SpirlogBook.is_seen(GameState.spirlog, sd.species_name)
		_sprite.texture = MiniSprite.of(sd.species_name, px) if seen else null
		if sd == null:
			_label.text = ""
		elif not seen:
			_label.text = "No.%03d\n???" % sd.dex_id
		else:
			var els: PackedStringArray = []
			for e: int in sd.elements:
				els.append(Loc.t(Elements.element_name(e)))
			_label.text = "No.%03d %s\n%s" % [sd.dex_id, Loc.t(sd.species_name), "/".join(els)]
		if map != null:
			var marks: Array[String] = []
			if seen:
				marks = EraDexViews.places_of(sd, GameState.spirlog)
			map.marked = marks
			map.queue_redraw()

## The size compare of [param sd] as a card over [param parent].
static func show_size(parent: Node, sd: SpirlingData) -> void:
	var view := SizeCompare.new()
	view.sd = sd
	view.you_m = EraMenus.wayfarer_height()
	await EraMenuKit.show_card(parent, view, "%s\n%s" % [Loc.t(sd.species_name), EraMenus.size_line(sd)])

## The area map of [param sd] as a card over [param parent], with the place names under it.
static func show_area(parent: Node, sd: SpirlingData) -> void:
	var view := AreaMap.new()
	view.marked = places_of(sd, GameState.spirlog)
	view.custom_minimum_size = Vector2(120, 104)
	var found: String = SpirlogBook.found_line(sd, GameState.spirlog)
	await EraMenuKit.show_card(parent, view, Loc.t("Found on: %s" % (found if not found.is_empty() else "unknown")))
