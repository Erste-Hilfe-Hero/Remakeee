class_name BattleIntro
extends Control
## Battle opening per era (data/era_battle_feel.json "intro"): the screen starts covered and is
## uncovered in the era's own pattern, in whole cells so it stays crisp.
##   blinds  (I)   bands pull aside left and right in turn
##   spiral  (II)  blocks clear from the rim inward
##   shutter (III) a slanted seam opens from the middle
##   iris    (IV)  a circle opens from the centre
##   swoop   (V)   a diagonal sweep while the field zooms out (BattleScene)
## Before the wipe the screen may pulse a few times (at most 3 a second, half strength).
## Under reduced motion the cover only fades and nothing pulses.

const STYLES: Array[String] = ["blinds", "spiral", "shutter", "iris", "swoop"]
## Cell size in screen pixels: chunky in the old eras, finer later.
const CELL_OLD: int = 8
const CELL_NEW: int = 4
## One pulse lasts this long (on, then off): 3 a second at most (photosensitivity rule).
const FLASH_PERIOD: float = 0.36
const REDUCED_TIME: float = 0.15

var style: String = "blinds"
## 0 = fully covered, 1 = fully clear.
var progress: float = 0.0
var cell: int = CELL_OLD
var cover_color: Color = Color("1a1420")
var flash_alpha: float = 0.0
var flash_color: Color = Color.WHITE

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Plays the opening of [param era]. Awaitable; frees itself when done. [param share] below 1
## (a rematch, BattleShow.intro_share) skips the flashes and clears the cover in that share of
## the time.
func play(era: int, share: float = 1.0) -> void:
	style = EraBattleFeel.text(era, "intro", "blinds")
	cell = CELL_OLD if era <= 2 else CELL_NEW
	cover_color = UITheme.INK
	flash_color = UITheme.BG
	progress = 0.0
	queue_redraw()
	if Juice.reduced():
		var tw0: Tween = create_tween()
		tw0.tween_property(self, "modulate:a", 0.0, REDUCED_TIME).set_trans(Tween.TRANS_SINE)
		await tw0.finished
		queue_free()
		return
	var flashes: int = int(EraBattleFeel.num(era, "intro_flashes", 0)) if share >= 1.0 else 0
	var peak: float = float(EraBattleFeel.cfg().get("intro_flash_alpha", 0.5))
	for i: int in flashes:
		flash_alpha = peak
		queue_redraw()
		await get_tree().create_timer(FLASH_PERIOD / 2.0 / Juice.speed()).timeout
		flash_alpha = 0.0
		queue_redraw()
		await get_tree().create_timer(FLASH_PERIOD / 2.0 / Juice.speed()).timeout
	var tw: Tween = create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, EraBattleFeel.num(era, "intro_time", 0.6) * clampf(share, 0.05, 1.0) / Juice.speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	queue_free()

func _set_progress(p: float) -> void:
	progress = p
	queue_redraw()

## Is cell ([param cx], [param cy]) of a [param cols] x [param rows] grid still covered at
## progress [param p] for [param s]? Every style is fully covered at 0 and clear at 1.
static func covered(s: String, p: float, cx: int, cy: int, cols: int, rows: int) -> bool:
	if p <= 0.0:
		return true
	if p >= 1.0:
		return false
	match s:
		"blinds":
			var share: float = clampf(p * 1.3 - (cy % 4) * 0.1, 0.0, 1.0)
			var left: int = int(ceil(cols * (1.0 - share)))
			return cx < left if cy % 2 == 0 else cx >= cols - left
		"spiral":
			return spiral_index(cx, cy, cols, rows) >= int(p * cols * rows)
		"shutter":
			var seam: float = rows / 2.0 + (cx - cols / 2.0) * 0.35
			return absf(cy + 0.5 - seam) > p * (rows * 0.75)
		"iris":
			var c: Vector2 = Vector2(cols, rows) / 2.0
			var far: float = c.length()
			return Vector2(cx + 0.5, cy + 0.5).distance_to(c) > p * far
		_:
			var d: float = (float(cx) / maxf(cols, 1) + float(cy) / maxf(rows, 1)) / 2.0
			return d > p * 1.2 - 0.1

## Order in which a rim-first spiral clears cell ([param cx], [param cy]): 0 is the top-left
## corner, the centre comes last.
static func spiral_index(cx: int, cy: int, cols: int, rows: int) -> int:
	var r: int = mini(mini(cx, cy), mini(cols - 1 - cx, rows - 1 - cy))
	var before: int = cols * rows - maxi(cols - 2 * r, 0) * maxi(rows - 2 * r, 0)
	var w: int = cols - 2 * r
	var h: int = rows - 2 * r
	var x: int = cx - r
	var y: int = cy - r
	var along: int = 0
	if y == 0:
		along = x
	elif x == w - 1:
		along = w - 1 + y
	elif y == h - 1:
		along = (w - 1) + (h - 1) + (w - 1 - x)
	else:
		along = 2 * (w - 1) + (h - 1) + (h - 1 - y)
	return before + along

func _draw() -> void:
	var cols: int = int(ceil(size.x / cell))
	var rows: int = int(ceil(size.y / cell))
	if modulate.a < 1.0 or style.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), cover_color)
		return
	for cy: int in rows:
		var start: int = -1
		for cx: int in cols + 1:
			var on: bool = cx < cols and covered(style, progress, cx, cy, cols, rows)
			if on and start < 0:
				start = cx
			elif not on and start >= 0:
				draw_rect(Rect2(start * cell, cy * cell, (cx - start) * cell, cell), cover_color)
				start = -1
	if flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(flash_color, flash_alpha))
