extends GutTest
## Chimora 1.3.2 QA pass of Era III (Quillmarch, Etched) and Act III (Ashmere): regressions of the
## bugs it found.
##
## 1. Japanese talk never paged: TextBox.split_lines broke only at spaces, so a Japanese sentence
##    (no spaces) was one word, the label wrapped it to 4-8 lines in one page and the talk box grew
##    over the map (305 pages of Ashmere and Quillmarch talk in Era I, 39 in Era III).

## Width of the map talk label in Era I (144 px screen) and Era III.
const WIDTHS: Array[float] = [124.0, 196.0]
## Characters a line may not start with (Japanese line-start rule, kinsoku).
const NO_START: String = "。、！？」』）】〕〉》・ー…：；,.!?)"

var _lang: String = "en"

func before_all() -> void:
	_lang = Loc.language()

func after_all() -> void:
	Loc.set_language(_lang)

## Every talk line of the Ashmere and Quillmarch dialogue files.
func _region_lines() -> Array[String]:
	var out: Array[String] = []
	for f: String in ["ashmere", "ashmere_more", "ashmere_side", "ash_assize", "quillmarch", "saltglass", "soot_vaults"]:
		_collect(Dialogue.file_data(f), out)
	return out

func _collect(v: Variant, out: Array[String]) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if k != "action":
				_collect(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_collect(x, out)
	elif v is String and (v as String).contains(" ") and not (v as String).contains("/"):
		out.append(v)

func _check_pages(text: String, width: float, font: Font, size: int) -> void:
	var pages: Array[String] = TextBox.split_lines(text, width, font, size, TextBox.MAX_LINES)
	var joined: String = ""
	for page: String in pages:
		var lines: PackedStringArray = page.split("\n")
		assert_lte(lines.size(), TextBox.MAX_LINES, page)
		for line: String in lines:
			assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, width, line)
			if not line.is_empty() and not text.begins_with(line) and not text.contains("\n" + line):
				assert_false(NO_START.contains(line[0]), "a line starts with '%s': %s" % [line[0], line])
			joined += line
	assert_eq(joined.replace(" ", ""), text.replace(" ", "").replace("\n", ""), "no character is lost")

func test_japanese_talk_pages_into_three_line_windows() -> void:
	Loc.set_language("ja")
	var font: Font = UITheme.font()
	var n: int = 0
	for src: String in _region_lines():
		var shown: String = Loc.t(src)
		var parts: PackedStringArray = Dialogue.split_speaker(shown)
		if not parts[0].is_empty():
			shown = parts[1]
		for w: float in WIDTHS:
			_check_pages(shown, w, font, UITheme.FONT_SIZE)
		n += 1
	assert_gt(n, 300, "the Ashmere and Quillmarch talk is measured")

func test_the_long_assize_line_takes_two_pages() -> void:
	Loc.set_language("ja")
	var shown: String = Dialogue.split_speaker(Loc.t("Magistrate Greaves: You want a verdict on the Ruskweber wage plates? Then you need the jury. Five jurors, out walking the heath. Win each one over."))[1]
	assert_ne(shown, "", "the line is translated")
	var pages: Array[String] = TextBox.split_lines(shown, WIDTHS[0], UITheme.font(), UITheme.FONT_SIZE, TextBox.MAX_LINES)
	assert_gt(pages.size(), 1, "the line goes on in a second window instead of growing the box")

func test_spaced_text_still_breaks_at_spaces() -> void:
	Loc.set_language("en")
	var font: Font = UITheme.font()
	var pages: Array[String] = TextBox.split_lines("Your account is closed. Congratulations, I suppose.", WIDTHS[0], font, UITheme.FONT_SIZE, TextBox.MAX_LINES)
	for page: String in pages:
		for line: String in page.split("\n"):
			assert_false(line.begins_with(" ") or line.ends_with(" "), line)
			for word: String in line.split(" ", false):
				assert_true(word in ["Your", "account", "is", "closed.", "Congratulations,", "I", "suppose."], "words stay whole: " + word)
