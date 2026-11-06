class_name NameKeyboard
extends GridContainer
## On-screen letter keys for the name at new game. Phones (and the browser build on iPhone)
## don't always open their own keyboard for a LineEdit, so the name can always be typed here,
## by touch, D-pad or gamepad. The first letter is upper case, the rest lower case.

signal confirmed

const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DELETE: String = "<"
const OK: String = "OK"
const KEY_SIZE := Vector2(18, 15)

## The field the keys type into.
var target: LineEdit
## True while the field still shows the suggested name: the first key replaces it.
var fresh: bool = false

func _ready() -> void:
	columns = 7
	add_theme_constant_override("h_separation", 1)
	add_theme_constant_override("v_separation", 1)
	for i: int in LETTERS.length():
		_add_key(LETTERS[i])
	_add_key(DELETE)
	_add_key(OK)

func _add_key(label: String) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = KEY_SIZE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.pressed.connect(press.bind(label))
	Juice.press_feedback(b)
	add_child(b)

## What a key does (also used by the tests).
func press(label: String) -> void:
	if target == null:
		return
	if fresh and label != OK:
		fresh = false
		target.text = ""
		if label == DELETE:
			return
	match label:
		DELETE:
			target.text = target.text.left(-1) if not target.text.is_empty() else ""
		OK:
			confirmed.emit()
		_:
			if target.max_length > 0 and target.text.length() >= target.max_length:
				return
			target.text += label if target.text.is_empty() else label.to_lower()
	target.caret_column = target.text.length()

## Focus on the first key so a D-pad or gamepad can type right away.
func focus_first() -> void:
	if get_child_count() > 0:
		(get_child(0) as Control).grab_focus()
