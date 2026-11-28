extends GutTest
## Era IV QA pass (1.3.2): bugs found while walking Halcyra and Solenne in every language, each
## pinned here.

const MAID: String = "Maid Lisette: I polish the roofs at dawn. The gold comes off on my hands. So does everything else in this house."
const WARDEN: String = "Warden Isaura"

var _era: int = 1

func before_all() -> void:
	_era = EraManager.unlocked_era

func after_each() -> void:
	Loc.set_language("en")
	EraManager.unlocked_era = _era

## Japanese and Chinese write "名前：" with the full-width colon, so their name tag (and the
## Era IV head, Era V bust) never showed: the English line decides whether someone speaks.
func test_full_width_colon_names_the_speaker() -> void:
	Loc.set_language("zh_CN")
	var shown: String = Loc.t(MAID)
	assert_ne(shown, MAID, "the line is translated")
	var parts: PackedStringArray = Dialogue.split_translated(MAID, shown)
	assert_eq(parts[0], shown.substr(0, shown.find("：")))
	assert_false(parts[1].begins_with("："), "the colon goes with the name")
	assert_eq(parts[2], "Maid Lisette", "the portrait is looked up by the English name")

func test_narration_with_a_colon_keeps_its_text() -> void:
	var en: String = "A shelf of burned maps. One survived: Greyreach, with a small Mirkmoth in the margin."
	assert_eq(Dialogue.split_translated(en, "一整架烧毁的地图。只有一张幸存：Greyreach。")[0], "")
	assert_eq(Dialogue.split_translated("You are in %s.", "지금 위치: %s")[0], "", "a Korean ': ' is no speaker when the English has none")

func test_english_lines_split_as_before() -> void:
	assert_eq(Dialogue.split_translated(MAID, MAID), Dialogue.split_speaker(MAID) + PackedStringArray(["Maid Lisette"]))
	assert_eq(Dialogue.split_translated("FERRY TO CORVANE", "FERRY TO CORVANE")[0], "")

func test_long_french_names_get_the_tag() -> void:
	var parts: PackedStringArray = Dialogue.split_translated(MAID, "Lisette la femme de chambre: Je polis les toits.")
	assert_eq(parts[0], "Lisette la femme de chambre")
	assert_eq(parts[1], "Je polis les toits.")

## Every named line of the Era IV dialogue gets its name tag in every language.
func test_every_era4_speaker_line_has_a_tag_in_every_language() -> void:
	var lines: Array[String] = []
	for f: String in ["brightledge", "gildcrest", "starwell", "paleshore", "whitecairn", "ochrewell", "glasswind_flats"]:
		_collect(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % f)), lines)
	assert_gt(lines.size(), 20)
	for code: String in Loc.LANGUAGES:
		Loc.set_language(code)
		for en: String in lines:
			assert_ne(Dialogue.split_translated(en, Loc.t(en))[0], "", "%s: %s" % [code, Loc.t(en)])

func _collect(v: Variant, out: Array[String]) -> void:
	if v is String and not Dialogue.split_speaker(v)[0].is_empty():
		out.append(v)
	elif v is Array:
		for x: Variant in v:
			_collect(x, out)
	elif v is Dictionary:
		for k: Variant in v:
			if str(k) != "action":
				_collect(v[k], out)

## The Era IV box shows the speaker's head for Chinese lines: "Kaia：..." names Kaia, and a Warden
## passed in by name is looked up by the English name (Chinese glues title and name together).
func test_era4_box_shows_the_head_for_a_translated_line() -> void:
	EraManager.unlocked_era = 4
	EraManager.set_retro_filter(0)
	Loc.set_language("zh_CN")
	var box := TextBox.new()
	add_child_autofree(box)
	box.position = Vector2(4, 300)
	box.size = Vector2(262, 60)
	await wait_process_frames(2)
	box.apply_era_frame()
	var kaia: String = "Kaia: Crystals. Fresh off a caravan that won't be missing them. Probably."
	assert_true(Loc.t(kaia).begins_with("Kaia："), "the Chinese line uses the full-width colon")
	box.show_prompt(kaia)
	await wait_process_frames(2)
	assert_eq(box.speaker(), "Kaia")
	assert_eq(box._portrait.speaker_id(), "kaia")
	box.show_prompt("I read your stars this morning.", WARDEN)
	await wait_process_frames(2)
	assert_eq(box.speaker(), WARDEN, "show_prompt shows the name it is given")
	assert_eq(box._portrait.speaker_id(), "isaura")
	box.set_speaker(Loc.t(WARDEN), WARDEN)
	await wait_process_frames(2)
	assert_eq(box._portrait.speaker_id(), "isaura", "the head follows the English name")

## Signs went through the speaker split: "North: the Orrery Rift. East: ..." showed a "North" name
## tag and lost the word, "A notice: ..." showed "A notice" as a person.
func test_signs_and_labels_are_no_speakers() -> void:
	for line: String in ["North: the Orrery Rift. East: Orrery Ridge.", "Up: Gildcrest. Down: Brightledge.",
			"North-east: the high path to Crowcrest.", "A notice: PLANET RETRIEVAL - CONTACT THE GILT HOUSE.",
			"A crew note: Never the way the caravan wants.", "Palace notice: The great dial door opens.",
			"On the counter: a bill for your last three alibis."]:
		assert_eq(Dialogue.split_speaker(line)[0], "", line)
	assert_eq(Dialogue.split_speaker("Warden Isaura: I read your stars.")[0], "Warden Isaura")
	assert_eq(Dialogue.split_speaker("Customs man: Routine search.")[0], "Customs man")

## The Era IV frame font pages Japanese and Chinese inside the three-line box (the character
## wrapping of TextBox.split_lines, checked in Era I by test_era_text): no line wider than the box.
func test_cjk_lines_page_inside_the_box() -> void:
	EraManager.unlocked_era = 4
	EraManager.set_retro_filter(0)
	var box := TextBox.new()
	add_child_autofree(box)
	box.size = Vector2(270, 60)
	await wait_process_frames(2)
	for code: String in ["ja", "zh_CN", "zh_TW"]:
		Loc.set_language(code)
		box.apply_era_frame()
		await wait_process_frames(1)
		var font: Font = box._label.get_theme_font("font")
		var fs: int = box._label.get_theme_font_size("font_size")
		var w: float = box._text_width()
		var shown: String = Loc.t(MAID)
		assert_ne(shown, MAID, code)
		var pages: Array[String] = TextBox.split_lines(shown + shown + shown, w, font, fs, TextBox.MAX_LINES)
		assert_gt(pages.size(), 1, code + ": a long line pages")
		for page: String in pages:
			assert_lte(page.split("\n").size(), TextBox.MAX_LINES, code)
			for l: String in page.split("\n"):
				assert_lte(font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, w, code + ": " + l)
				assert_false(l.length() > 1 and TextBox.NO_LINE_START.contains(l[0]), code + " starts with punctuation: " + l)
		assert_eq("".join(pages).replace("\n", "").replace(" ", ""), (shown + shown + shown).replace(" ", ""), code + ": no character lost")
