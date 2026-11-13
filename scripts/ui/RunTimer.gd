class_name RunTimer
extends Label
## Run timer for speed runs (KAMPF_PLAN_1000 item 507): the journey's play time as H:MM:SS in
## the top left corner of the overworld. Off by default; switched per journey on the challenge
## page (GameState.records["run_timer"]).

const KEY: String = "run_timer"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(2, 2)
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", UITheme.BG)
	add_theme_color_override("font_outline_color", UITheme.INK)
	add_theme_constant_override("outline_size", 2)

static func is_on() -> bool:
	return bool(GameState.records.get(KEY, false))

static func toggle() -> void:
	GameState.records[KEY] = not is_on()

## "1:02:05" for [param seconds].
static func format(seconds: float) -> String:
	var s: int = int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

func _process(_delta: float) -> void:
	visible = GameState.in_game and is_on()
	if visible:
		text = format(GameState.play_time)
