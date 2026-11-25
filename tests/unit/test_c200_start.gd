extends GutTest
## Chimora 200 list items 2 (team lead on the Continue row), 5 (which partner suits you),
## 11 (the first battle's arrow at the first art) and 17 (place pictures in Earlier saves).

const ROW_TEXT_WIDTH: int = 115

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	Loc.set_language("en")

func _width(text: String) -> float:
	return PixelFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

# --- Item 2 -------------------------------------------------------------------------------

func test_lead_species_is_the_first_team_member() -> void:
	assert_eq(EraSaveCard.lead_species({"party": [{"species": "Zippit"}, {"species": "Kindlop"}]}), "Zippit")
	assert_eq(EraSaveCard.lead_species({"party": []}), "")
	assert_eq(EraSaveCard.lead_species({}), "")

func test_continue_icon_shows_badge_and_lead() -> void:
	var with_lead: Texture2D = EraSaveCard.continue_icon(1, "Kindlop")
	assert_eq(with_lead.get_width(), EraSaveCard.badge(1).get_width() + 2 + EraSaveCard.LEAD_SIZE)
	assert_eq(with_lead.get_height(), EraSaveCard.LEAD_SIZE)
	assert_eq(EraSaveCard.continue_icon(1, ""), EraSaveCard.badge(1), "no team: only the badge")
	assert_eq(EraSaveCard.continue_icon(1, "NoSuchKind"), EraSaveCard.badge(1))

func test_title_uses_the_continue_icon() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_string_contains(src, "EraSaveCard.continue_icon(")

