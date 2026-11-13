class_name CharCounter
extends Label
## Item 1966: how many characters are left in a name box, as "4/10" in MID ink.
## Follows [member target] every frame, since the own letter keys change the text in code.

var target: LineEdit
var max_len: int = 10

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
