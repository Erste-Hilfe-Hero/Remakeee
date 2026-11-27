class_name WeatherIcon
extends Control
## A tiny weather symbol next to the time-of-day symbol (the place banner, the clock strip of the
## start menu): a cloud with drops for rain, with a bolt for a storm, with flakes for snow,
## bars for fog, curls for wind, specks for sand and ash. Nothing under a clear sky.
## Drawn in [member ink] (the text colour of whatever it sits on) with a UITheme accent bolt.

## A weather kind or look ("rain", "storm", "fog", "wind", "snow", "sandstorm", "ash", "clear").
var kind: String = "clear"
## Colour of the symbol: the text colour of the banner or strip it sits on.
var ink: Color = UITheme.INK

func _ready() -> void:
	name = "weather_icon"
	custom_minimum_size = Vector2(9, 7)
	size = Vector2(9, 7)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Shows [param k]; hidden under a clear sky.
func show_kind(k: String) -> void:
	kind = k
	visible = k != "clear" and not k.is_empty()
	queue_redraw()

## The symbol for the sky over [param m] now (clear indoors, in caves and with weather off).
func show_for(m: MapData) -> void:
	show_kind(EraLight.look_for(m, WeatherCycle.current(m)) if m != null else "clear")

func _cloud() -> void:
	draw_rect(Rect2(1, 1, 7, 1), ink)
	draw_rect(Rect2(2, 0, 3, 1), ink)
	draw_rect(Rect2(0, 2, 9, 2), ink)

func _draw() -> void:
	match kind:
		"rain":
			_cloud()
			for x: int in [1, 4, 7]:
				draw_rect(Rect2(x, 5, 1, 2), ink)
		"storm":
			_cloud()
			draw_rect(Rect2(5, 4, 1, 1), UITheme.ACCENT)
			draw_rect(Rect2(4, 5, 2, 1), UITheme.ACCENT)
			draw_rect(Rect2(4, 6, 1, 1), UITheme.ACCENT)
			draw_rect(Rect2(1, 5, 1, 2), ink)
			draw_rect(Rect2(7, 5, 1, 2), ink)
		"snow":
			_cloud()
			for p: Vector2 in [Vector2(1, 5), Vector2(4, 6), Vector2(7, 5)]:
				draw_rect(Rect2(p, Vector2(1, 1)), ink)
		"fog":
			draw_rect(Rect2(0, 1, 7, 1), ink)
			draw_rect(Rect2(2, 3, 7, 1), ink)
			draw_rect(Rect2(0, 5, 6, 1), ink)
		"wind":
			draw_rect(Rect2(0, 2, 6, 1), ink)
			draw_rect(Rect2(6, 1, 1, 1), ink)
			draw_rect(Rect2(5, 0, 1, 1), ink)
			draw_rect(Rect2(1, 4, 7, 1), ink)
			draw_rect(Rect2(8, 5, 1, 1), ink)
			draw_rect(Rect2(7, 6, 1, 1), ink)
		"clear", "":
			pass
		_:
			# Sand and ash: specks on the wind.
			for p: Vector2 in [Vector2(0, 1), Vector2(3, 0), Vector2(6, 2), Vector2(2, 3), Vector2(5, 4), Vector2(8, 5), Vector2(1, 6), Vector2(4, 6)]:
				draw_rect(Rect2(p, Vector2(1, 1)), ink)
