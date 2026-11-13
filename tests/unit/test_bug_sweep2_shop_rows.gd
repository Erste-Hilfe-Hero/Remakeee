extends GutTest
## Bug sweep 2: in Eras I and II a shop row was "name  price" in one clipped line, so long
## offers lost their price at the right edge ("10000 Riftglass  99,9", "Macht-Siegel III  1").
## The name now gives way: it is cut with ".." before the price, which is always whole.

var _lang: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_lang = Loc.language()

func after_each() -> void:
	Loc.set_language(_lang)

## A menu on the Era I phone screen (144 x 256).
func _host() -> MenuHost:
	var screen := Control.new()
	screen.size = Vector2(EraManager.RESOLUTION[1])
	add_child_autofree(screen)
	var host := MenuHost.new()
	screen.add_child(host)
	await wait_process_frames(1)
	return host

func _check_tab(lang: String, tab: String) -> void:
	Loc.set_language(lang)
	var host: MenuHost = await _host()
	var lay: Dictionary = EraMenus.layout(1, "shop")
	var entries: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.in_tab(tab):
		entries.append(ShopMenu.offer_row(o, lay))
	host.picker.pick("Shop", entries, true, 0, 0)
	await wait_process_frames(3)
	var bs: Array[Button] = host.picker.buttons()
	var cut: int = 0
	for i: int in entries.size():
		var b: Button = bs[i]
		var price: String = str(entries[i].right)
		assert_eq(price, ShopMenu.row_price(ShopCatalog.in_tab(tab)[i]), "the row keeps its price")
		var font: Font = b.get_theme_font("font")
		var fs: int = b.get_theme_font_size("font_size")
		var box: StyleBox = b.get_theme_stylebox("normal")
		var used: float = box.get_margin(SIDE_LEFT) + font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
			+ 3.0 + font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3.0
		assert_lte(used, b.size.x, "%s %s: '%s' ends before '%s'" % [lang, tab, b.text, price])
		assert_true(b.text == str(entries[i].text) or b.text.ends_with(".."), "%s: whole name or cut with .." % b.text)
		if b.text.ends_with(".."):
			cut += 1
	assert_lt(b_width(bs), 150.0, "laid out on the Era I screen")
	if tab == "advantages":
		assert_gt(cut, 0, "%s: the long names are the ones that give way" % lang)
	host.picker.picked.emit(-1)

func test_era1_rows_keep_name_and_price_apart() -> void:
	for lang: String in ["en", "de"]:
		for tab: String in ["advantages", "riftglass"]:
			await _check_tab(lang, tab)

func test_short_name_is_not_cut() -> void:
	var host: MenuHost = await _host()
	host.picker.pick("Shop", [{"text": "Tonic", "right": "5"}] as Array[Dictionary], true, 0, 0)
	await wait_process_frames(2)
	assert_eq(host.picker.buttons()[0].text, "Tonic")
	host.picker.picked.emit(-1)

func b_width(bs: Array[Button]) -> float:
	return bs[0].size.x
