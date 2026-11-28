class_name GoalLine
extends Button
## The current goal in one line at the top of the overworld while the story is in Act I (plan
## Chimora 100, item 37): the goal flag, then the short "hud" text of data/quests.json. It
## hides while a text box, the place banner, a menu or a scene is up, so it never covers talk or
## the touch pad, and a tap opens the Goals page. Settings > Game > "Goal line" switches it off
## together with the goal door marks (GoalMarks, the minimap ring). After "Where next?" in the
## Quest Book it names that quest's place in any act, like the world map ring (QuestLog.tracked).

## Seconds between two looks at the story flags (goals change in talk, never mid-step).
const POLL: float = 0.25
const HEIGHT: int = 15

## The overworld that owns this line (busy, scene_running, the text box and the banner).
var ow: Node
var _clock: float = 0.0
var _goal_key: String = "-"

func _ready() -> void:
	name = "goal_line"
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	icon = PauseMenu.goal_mark()
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 4
	offset_right = -4
	offset_top = 2
	offset_bottom = 2 + HEIGHT
	_dress()
	visible = false
	pressed.connect(_on_pressed)
	Loc.events.language_changed.connect(func(_c: String) -> void: _goal_key = "-")

## The era's panel frame, slim enough for one line.
func _dress() -> void:
	var sb: StyleBox = UITheme.panel_style()
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, UITheme.INK)
	add_theme_constant_override("h_separation", 2)

## True when the line may show: on in Settings, a goal line exists and nothing else is up.
static func wanted(text_now: String, quiet: bool) -> bool:
	return GameState.goal_line and not text_now.is_empty() and quiet

func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = POLL
		var key: String = "%s|%s|%s|%s" % [QuestLog.current_index(GameState.flags), QuestLog.goal_maps(GameState.flags),
			QuestLog.hud_text(GameState.flags), GameState.goal_line]
		if key != _goal_key:
			_goal_key = key
			text = QuestLog.hud_text(GameState.flags)
			_dress()
			if ow != null and ow.has_method("refresh_goal_marks"):
				ow.refresh_goal_marks()
	visible = wanted(text, _quiet())

func _quiet() -> bool:
	if ow == null:
		return true
	return not ow.busy and not ow.scene_running and ow.get("_photo") == null \
		and not (ow.get("_text") as Control).visible and not (ow.get("_banner") as Control).visible

func _on_pressed() -> void:
	if ow != null and _quiet():
		ow.open_menu("Goals")
