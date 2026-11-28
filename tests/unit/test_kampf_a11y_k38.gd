extends GutTest
## Battle plan (docs/KAMPF_PLAN_1000.md), section "Barrierefreiheit", items 896-900 and 902:
## button sizes, Vigor bar contrast, readable status tags, field and boss phase banners that can
## be read, and Simple battle text.

const LIGHT := Color("f8f4ec")
var _settings: Dictionary
var _keep: Array

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	Loc.set_language("en")

func after_each() -> void:
	GameState.settings_from_dict(_settings)
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	UITheme.set_high_contrast(false)
	UITheme.set_large_text(false)
	Loc.set_language("en")

## The paper of every era's skin and of high contrast.
func _papers() -> Array[Color]:
	var out: Array[Color] = []
	for era: int in range(1, 6):
		out.append(EraFeel.palette(era)[0])
	out.append(UITheme.HIGH_CONTRAST_PALETTE[0])
	return out

# --- 896 Button sizes ---------------------------------------------------------------------------

func test_big_buttons_reach_the_least_height_in_every_era() -> void:
	assert_gt(BattleComfort.big_min("art"), 0)
	assert_gt(BattleComfort.big_min("command"), 0)
	for era: int in range(1, 6):
		assert_eq(BattleComfort.art_h(era, false), int(EraBattleHud.num(era, "art_h")), "off keeps the era's look")
		assert_eq(BattleComfort.command_h(era, false), int(EraBattleHud.num(era, "command_h")))
		assert_gte(BattleComfort.art_h(era, true), BattleComfort.big_min("art"), "era %d" % era)
		assert_gte(BattleComfort.command_h(era, true), BattleComfort.big_min("command"), "era %d" % era)
		assert_gte(BattleComfort.art_h(era, true), BattleComfort.art_h(era, false) + BattleComfort.BIG_EXTRA)
		assert_gt(BattleComfort.menu_height(era, true), BattleComfort.menu_height(era, false), "era %d: the panel makes room" % era)

func test_command_menu_rows_follow_big_buttons() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 9)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.start()
	GameState.big_buttons = true
	for era: int in [1, 4]:
		EraManager.unlocked_era = EraManager.NEWEST
		EraManager.retro_filter = era
		var menu := CommandMenu.new()
		add_child_autofree(menu)
		menu.refresh(m, 0)
		await get_tree().process_frame
		assert_eq(menu.custom_minimum_size.y, float(BattleComfort.menu_height(era, true)))
		assert_eq(menu._move_buttons[0].custom_minimum_size.y, float(BattleComfort.art_h(era, true)))
		assert_eq(menu._swap.custom_minimum_size.y, float(BattleComfort.command_h(era, true)))

func test_big_buttons_and_simple_text_sit_in_the_game_settings() -> void:
	var keys: Array[String] = []
	for r: Array in MenuHost.settings_rows("game"):
		keys.append(str(r[0]))
	assert_true("big_buttons" in keys)
	assert_true("easy_battle_text" in keys)
	assert_ne(str(MenuHost.SETTING_HINTS.get("big_buttons", "")), "")
	assert_ne(str(MenuHost.SETTING_HINTS.get("easy_battle_text", "")), "")

# --- 897 Vigor bar contrast ---------------------------------------------------------------------

func test_every_vigor_fill_stands_out_from_the_paper() -> void:
	for era: int in range(1, 6):
		for frac: float in [1.0, 0.4, 0.1]:
			var fill: Color = HpBarStyle.color(era, frac)
			for paper: Color in _papers():
				assert_gte(UITheme.contrast(fill, paper), 3.0, "era %d, %.1f full, on %s" % [era, frac, paper.to_html(false)])

# --- 898 Status tags ----------------------------------------------------------------------------

func test_status_tags_are_short_and_unique_in_every_language() -> void:
	for code: String in Loc.LANGUAGES:
		Loc.set_language(code)
		var seen: Dictionary = {}
		for st: String in StatusRules.RULES:
			var tag: String = StatusRules.tag(st)
			assert_false(tag.is_empty(), "%s %s" % [code, st])
			assert_lte(tag.length(), 3, "%s %s: %s" % [code, st, tag])
			assert_false(seen.has(tag), "%s: %s used twice" % [code, tag])
			seen[tag] = st
	Loc.set_language("de")
	assert_eq(StatusRules.tag("scorch"), "BRA", "German tags follow the German names")
	Loc.set_language("en")
	assert_eq(StatusRules.tag("scorch"), "SCO")

func test_status_tag_letters_reach_4_5_to_1_on_their_badge() -> void:
	for hc: bool in [false, true]:
		UITheme.set_high_contrast(hc)
		for era: int in range(2, 6):
			for st: String in StatusRules.RULES:
				var badge: Color = EraBattleFeel.status_badge(era, st)
				var ink: Color = InfoStrip.badge_text(badge)
				assert_gte(UITheme.contrast(ink, badge), 4.5, "era %d %s (high contrast %s)" % [era, st, hc])

# --- 899 Field banner, 900 Boss phase banner -----------------------------------------------------

func test_banners_stay_long_enough_to_read_at_any_speed() -> void:
	var t: String = "Ashen Heart awakens"
	for speed: float in [1.0, 2.0, 4.0]:
		assert_gte(BattleShow.banner_seconds(t, speed), 0.9 + 0.035 * t.length() - 0.001)
	assert_gt(BattleShow.banner_seconds("A much longer field name here", 4.0), BattleShow.banner_seconds("Fog", 4.0), "longer text, longer time")

func test_a_long_banner_wraps_and_grows_instead_of_cutting_off() -> void:
	var b := RuleBanner.new()
	add_child_autofree(b)
	b.show_rule("Fog", false, 144.0, 40.0)
	assert_eq(b.size.y, RuleBanner.HEIGHT)
	b.show_rule("The Ashen Heart of the Hollow Rift wakes up and lies open", true, 144.0, 40.0)
	assert_gt(b._label.get_line_count(), 1)
	assert_gt(b.size.y, RuleBanner.HEIGHT, "the strip grows with the lines")
	assert_true(b.turning)

func test_the_field_badge_grows_with_large_text() -> void:
	UITheme.set_large_text(true)
	var host := Control.new()
	host.theme = UITheme.get_theme()
	add_child_autofree(host)
	var badge := FieldBadge.new()
	host.add_child(badge)
	autofree(badge.tint_rect)
	badge.show_field("high_tide", 3)
	assert_gte(badge.size.y, badge._label.get_minimum_size().y, "no letter cut off")
	assert_gte(badge.size.y, FieldBadge.HEIGHT)

func test_boss_phase_banners_say_what_happened() -> void:
	var phase := BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"name": "Ashen Heart"})
	var weak := BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"name": "Ashen Heart", "weak": true})
	var rage := BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"name": "Ashen Heart", "rage": true})
	assert_eq(BattleShow.banner_title(phase), "Ashen Heart awakens")
	assert_eq(BattleShow.banner_title(weak), "Ashen Heart lies open")
	assert_eq(BattleShow.banner_title(rage), "Ashen Heart rages")
	Loc.set_language("de")
	var gloam := BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"name": "Kindlop", "weak": true})
	assert_eq(Loc.t(BattleShow.banner_title(gloam)), "Kindlop liegt offen")
	gloam.data = {"name": "Kindlop", "rage": true}
	assert_eq(Loc.t(BattleShow.banner_title(gloam)), "Kindlop tobt")

# --- 902 Simple battle text ----------------------------------------------------------------------

func test_simple_battle_text_swaps_the_common_lines() -> void:
	var hit := BattleEvent.new(BattleEvent.Type.DAMAGE, {"name": "Kindlop", "amount": 12, "eff": 2.0, "crit": true})
	var st := BattleEvent.new(BattleEvent.Type.STATUS_APPLIED, {"name": "Kindlop", "status": "scorch"})
	var up := BattleEvent.new(BattleEvent.Type.STAT_CHANGED, {"name": "Kindlop", "stat": "atk", "delta": 2})
	var start := BattleEvent.new(BattleEvent.Type.SEND_OUT, {"name": "Kindlop"})
	GameState.easy_battle_text = false
	assert_eq(hit.describe(), "Kindlop took 12 damage. A keen hit! It's overwhelming!")
	GameState.easy_battle_text = true
	assert_true(BattleEvent.easy)
	assert_eq(hit.describe(), "Kindlop loses 12 Vigor. Lucky hit! Very strong hit!")
	assert_eq(st.describe(), "Kindlop now has Scorch.")
	assert_eq(up.describe(), "Kindlop: Might far up.")
	assert_eq(start.describe(), "Kindlop steps out!", "lines without a plain form stay")
	Loc.set_language("de")
	assert_eq(Loc.t(hit.describe()), "Kindlop verliert 12 Kraft. Glücks-Treffer! Sehr starker Treffer!")
	assert_eq(Loc.t(st.describe()), "Kindlop hat jetzt Brand.")

func test_simple_battle_text_is_saved() -> void:
	GameState.easy_battle_text = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.easy_battle_text = false
	assert_false(BattleEvent.easy)
	GameState.settings_from_dict(d)
	assert_true(GameState.easy_battle_text)
	assert_true(BattleEvent.easy)
