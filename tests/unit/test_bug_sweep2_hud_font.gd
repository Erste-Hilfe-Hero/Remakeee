extends GutTest
## Bug sweep 2: in Era III the battle HUD draws with the era's own 10 px font (EraText, ascent 8)
## but laid its name plate rows out for the pixel font (ascent 7). In the era HUD shots (EN and
## DE) the status badge touched the ring number and the stat marks ran into the Vigor numbers.

var _unlocked: int
var _retro: int
var _lang: String
var _large: bool

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_lang = Loc.language()
	_large = UITheme.large_text

func after_each() -> void:
	UITheme.set_large_text(_large)
	Loc.set_language(_lang)
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)

func test_plate_rows_match_the_font_the_hud_draws_with() -> void:
	UITheme.set_large_text(false)
	for lang: String in ["en", "de", "fr"]:
		Loc.set_language(lang)
		for era: int in range(1, 4):
			EraManager.unlocked_era = era
			EraManager.set_retro_filter(0)
			var f: Font = EraBattleHud.theme(era).default_font
			var drawn: int = roundi(f.get_ascent(PixelFont.BASE_SIZE))
			assert_eq(EraBattleHud.ascent(era), drawn, "era %d %s: rows laid out for the font drawn" % [era, lang])
			assert_eq(int(EraBattleHud.plate_rows(era).asc), drawn)
			assert_gte(EraBattleHud.line_h(era), roundi(f.get_height(PixelFont.BASE_SIZE)), "era %d %s: a line holds the font" % [era, lang])
