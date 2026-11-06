class_name NameKeyboard
extends GridContainer
## On-screen letter keys for the name at new game. Phones (and the browser build on iPhone)
## don't always open their own keyboard for a LineEdit, so the name can always be typed here,
## by touch, D-pad or gamepad. The first letter is upper case, the rest lower case.
##
## A second page has Ä, Ö, Ü, ß, a hyphen and a space (plan item 1960). In CODE mode the keys
## are capital letters and digits, grouped by four with a dash, with a key that pastes from the
## clipboard: for transfer and friend codes (items 1963, 2172).

signal confirmed
signal cancelled

enum Mode { NAME, CODE }

const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const EXTRA: Array[String] = ["Ä", "Ö", "Ü", "ß", "-", SPACE]
const DIGITS: String = "0123456789"
const DELETE: String = "<"
const OK: String = "OK"
const SPACE: String = "_"
const PAGE_EXTRA: String = "ÄÖ"
const PAGE_LETTERS: String = "AB"
const PASTE: String = "Paste"
const BACK: String = "Back"
const KEY_SIZE := Vector2(18, 15)
## Characters per group in CODE mode.
const GROUP: int = 4

## The field the keys type into.
var target: LineEdit
## True while the field still shows the suggested name: the first key replaces it.
var fresh: bool = false
var mode: Mode = Mode.NAME
## Builds a row with Back (and Paste in CODE mode) for the owner to place under the keys;
## wide labels would stretch the key grid (item 1962).
func make_extra_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var labels: Array[String] = [BACK]
	if mode == Mode.CODE:
		labels.push_front(PASTE)
	for l: String in labels:
		var b := Button.new()
		b.text = l
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, KEY_SIZE.y)
		b.pressed.connect(press.bind(l))
		row.add_child(b)
	return row
## Code length without dashes in CODE mode (0 = no limit).
var code_length: int = 0
var _extra_page: bool = false

func _ready() -> void:
	columns = 7
	add_theme_constant_override("h_separation", 1)
	add_theme_constant_override("v_separation", 1)
	_build()

func _build() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	var keys: Array[String] = []
	if mode == Mode.CODE:
		for i: int in LETTERS.length():
			keys.append(LETTERS[i])
		for i: int in DIGITS.length():
			keys.append(DIGITS[i])
	elif _extra_page:
		keys.append_array(EXTRA)
		keys.append(PAGE_LETTERS)
	else:
		for i: int in LETTERS.length():
			keys.append(LETTERS[i])
		keys.append(PAGE_EXTRA)
	keys.append(DELETE)
	keys.append(OK)
	for k: String in keys:
		_add_key(k)

func _add_key(label: String) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = KEY_SIZE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.accessibility_name = Loc.t("Space") if label == SPACE else b.text
	b.pressed.connect(press.bind(label))
	add_child(b)

## Switches between letters and codes (rebuilds the keys).
func set_mode(m: Mode) -> void:
	mode = m
	_extra_page = false
	if is_inside_tree():
		_build()

## What a key does (also used by the tests).
func press(label: String) -> void:
	if target == null:
		return
	if label == PAGE_EXTRA or label == PAGE_LETTERS:
		_extra_page = label == PAGE_EXTRA
		_build()
		focus_first()
		return
	if label == BACK:
		cancelled.emit()
		return
	if fresh and label != OK:
		fresh = false
		target.text = ""
		if label == DELETE:
			return
	match label:
		DELETE:
			target.text = target.text.left(-1) if not target.text.is_empty() else ""
			if mode == Mode.CODE and target.text.ends_with("-"):
				target.text = target.text.left(-1)
		OK:
			confirmed.emit()
		PASTE:
			paste(DisplayServer.clipboard_get())
		_:
			if mode == Mode.CODE:
				_type_code(label)
			else:
				_type_name(SPACE_CHAR if label == SPACE else label)
	target.caret_column = target.text.length()

const SPACE_CHAR: String = " "

func _type_name(ch: String) -> void:
	if target.max_length > 0 and target.text.length() >= target.max_length:
		return
	if ch == SPACE_CHAR and (target.text.is_empty() or target.text.ends_with(SPACE_CHAR)):
		return
	# Capital at the start and after a space or hyphen ("Anna-Lena"), lower case elsewhere.
	var start: bool = target.text.is_empty() or target.text.ends_with(SPACE_CHAR) or target.text.ends_with("-")
	target.text += ch if start or ch == "ß" else ch.to_lower()

func _type_code(ch: String) -> void:
	var raw: String = raw_code(target.text)
	if code_length > 0 and raw.length() >= code_length:
		return
	target.text = pretty(raw + ch)

## Puts a pasted code in, keeping only letters and digits (item 2172).
func paste(text: String) -> void:
	var raw: String = raw_code(text.to_upper())
	if code_length > 0:
		raw = raw.left(code_length)
	fresh = false
	target.text = pretty(raw)
	target.caret_column = target.text.length()

## Letters and digits of a code, without dashes or spaces.
static func raw_code(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: String = text[i]
		if LETTERS.contains(c) or DIGITS.contains(c):
			out += c
	return out

## "ABCD-EFGH-1234".
static func pretty(raw: String) -> String:
	var parts: PackedStringArray = []
	var i: int = 0
	while i < raw.length():
		parts.append(raw.substr(i, GROUP))
		i += GROUP
	return "-".join(parts)

## A name the game accepts: not empty, not only spaces (item 1961).
static func valid_name(text: String) -> bool:
	return not text.strip_edges().is_empty()

## Focus on the first key so a D-pad or gamepad can type right away.
func focus_first() -> void:
	_focus_first_now.call_deferred()

func _focus_first_now() -> void:
	if is_inside_tree() and get_child_count() > 0:
		var c: Control = get_child(0) as Control
		if c.is_inside_tree() and not c.is_queued_for_deletion():
			c.grab_focus()
