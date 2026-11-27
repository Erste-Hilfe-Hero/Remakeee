class_name CharCounter
extends Label
## Item 1966: how many characters are left in a name box, as "4/10" in MID ink.
## Follows [member target] every frame, since the own letter keys change the text in code.

var target: LineEdit
var max_len: int = 10
## The question above the box: it asks for another name while the typed one would not be shown
## online (200 list item 7, same rules as the server: LocalBackend.clean_name).
var ask_label: Label
var ask_text: String = ""
const ASK_AGAIN: String = "Please pick another name."

static func make(edit: LineEdit, limit: int) -> CharCounter:
	var c := CharCounter.new()
	c.name = "char_counter"
	c.target = edit
	c.max_len = limit
	c.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_theme_color_override("font_color", UITheme.MID)
	c.text = text_for("", limit)
	return c

## "4/10": characters left of [param limit].
static func text_for(t: String, limit: int) -> String:
	return "%d/%d" % [maxi(0, limit - t.length()), limit]

func _process(_delta: float) -> void:
	if is_instance_valid(target) and is_visible_in_tree():
		var t: String = text_for(target.text, max_len)
		if t != text:
			text = t
			if ask_label != null:
				ask_label.text = ASK_AGAIN if name_refused(target.text) else ask_text

## True when the server would replace [param n] by a stand-in name (bad word, web address,
## phone number). An empty box is not refused yet.
static func name_refused(n: String) -> bool:
	return not n.strip_edges().is_empty() and LocalBackend.clean_name(n, "0000") != " ".join(n.strip_edges().split(" ", false))
