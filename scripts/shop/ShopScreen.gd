class_name ShopScreen
extends Control
## The full-screen shop (pay-to-win shop rebuild, Ali 27.11.2026): a Featured home page with a big
## banner offer, icon tabs for Advantages, Packs, Pass, Looks, Riftglass and More, offer cards
## with the full name, what is inside, tags and the price, and a detail page with every content
## line and the buy buttons. The Riftglass balance stays at the top with a "+" to the Riftglass
## tab. Buying goes through ShopMenu.buy (Billing), so every rule of the old list still holds.
## ShopMenu.run opens it after the connection, age and kids checks.

signal closed

const TABS: Array[String] = ["featured", "advantages", "packs", "pass", "looks", "riftglass", "more"]
const TAB_TITLES: Dictionary[String, String] = {"featured": "Featured", "advantages": "Advantages", "packs": "Packs",
	"pass": "Pass", "looks": "Looks", "riftglass": "Riftglass", "more": "More"}
const BADGES: Dictionary[String, String] = {"bestseller": "Bestseller", "best_value": "Best value", "hot": "Popular",
	"new": "New", "limited": "Limited"}
## Fallback when no offer is marked "featured" yet: these, in this order, then the best Riftglass tier.
const FEATURED_FALLBACK: Array[String] = ["rg_starter", "rg_pass"]
## Smallest touch target in viewport pixels (EraMenus.TOUCH_MIN_ROW, about 44 pt on a phone).
const TOUCH: int = 22
const TAB_H: int = 22
const MARGIN: int = 3
const GAP: int = 3
## The pass screen of the pass track (W4); used when the class exists. Its class name is the
## file name.
const PASS_PATH: String = "res://scripts/shop/PassScreen.gd"
## The Starter Pack note after the tutorial act (once per journey, adults only, never in a battle).
const CATALOG_SCRIPT: String = "res://scripts/shop/ShopCatalog.gd"
const STARTER_ID: String = "rg_starter"
const STARTER_SEEN_FLAG: String = "shop_starter_note_seen"
const STARTER_OPEN: String = "starter_offer"
## Under 18 no shop note opens by itself (docs/MONETIZATION.md rule 5, UWG annex no. 28).
const STARTER_POPUP_MIN_BAND: int = 18

var menu: MenuHost
var tab: String = "featured"
var detail: Dictionary = {}
var _busy: bool = false
var _list: VBoxContainer
var _scroll: ScrollContainer
var _buy_bar: VBoxContainer
var _page_title: Label
var _page_hint: Label
var _balance_btn: Button
var _tab_buttons: Dictionary[String, Button] = {}
var _tabs_row: HBoxContainer

# --- Opening -----------------------------------------------------------------------------------

## Opens the shop on [param host] and returns when it closes. [param offer_id] opens straight on
## that offer's detail page (the Starter Pack note).
static func open(host: MenuHost, offer_id: String = "", start_tab: String = "featured") -> void:
	var s := ShopScreen.new()
	s.menu = host
	s.tab = start_tab
	host.add_child(s)
	if not offer_id.is_empty() and not ShopCatalog.offer(offer_id).is_empty():
		s.show_detail(ShopCatalog.offer(offer_id))
	await s.closed
	s.queue_free()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UITheme.flat_style(UITheme.BG, UITheme.BG))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = MARGIN
	root.offset_top = MARGIN
	root.offset_right = -MARGIN
	root.offset_bottom = -MARGIN
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	SafeArea.apply(root, MARGIN)
	root.add_child(_top_bar())
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 1)
	for t: String in TABS:
		var b := Button.new()
		b.icon = ShopArt.icon(ShopArt.TAB_ICONS[t])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.custom_minimum_size = Vector2(16, TAB_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Loc.t(TAB_TITLES[t])
		b.set("accessibility_name", Loc.t(TAB_TITLES[t]))
		b.pressed.connect(func() -> void: select_tab(t))
		for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(k, Color.WHITE)
		_tab_buttons[t] = b
		_tabs_row.add_child(b)
	root.add_child(_tabs_row)
	var title_row := HBoxContainer.new()
	_page_title = _label("", UITheme.INK)
	_page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_page_title)
	_page_hint = _label("", UITheme.MID)
	_page_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_page_hint)
	root.add_child(title_row)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.scroll_deadzone = 6
	root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", GAP)
	_scroll.add_child(_list)
	_buy_bar = VBoxContainer.new()
	_buy_bar.add_theme_constant_override("separation", 2)
	_buy_bar.visible = false
	root.add_child(_buy_bar)
	if detail.is_empty():
		select_tab(tab)

func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	var back := Button.new()
	back.text = "<"
	back.custom_minimum_size = Vector2(TOUCH, TOUCH)
	back.set("accessibility_name", Loc.t("Back"))
	back.pressed.connect(go_back)
	bar.add_child(back)
	var title := _label(Loc.t("Shop"), UITheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	_balance_btn = Button.new()
	_balance_btn.icon = ShopArt.icon("gem")
	_balance_btn.custom_minimum_size = Vector2(0, TOUCH)
	_balance_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		_balance_btn.add_theme_color_override(k, Color.WHITE)
	_balance_btn.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_balance_btn.pressed.connect(func() -> void: select_tab("riftglass"))
	bar.add_child(_balance_btn)
	_refresh_balance()
	return bar

## "120 +": the balance, and "+" leads to the Riftglass tab.
static func balance_short() -> String:
	if not Billing.state.has("balance"):
		return "- +"
	return "%d +" % Billing.balance()

func _refresh_balance() -> void:
	if _balance_btn != null:
		_balance_btn.text = balance_short()
		_balance_btn.set("accessibility_name", ShopMenu.balance_text(1000.0))

# --- Pages -------------------------------------------------------------------------------------

func select_tab(t: String) -> void:
	tab = t
	detail = {}
	_buy_bar.visible = false
	_tabs_row.visible = true
	for k: String in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var on: bool = k == t
		var sb: StyleBoxFlat = UITheme.flat_style(UITheme.ACCENT if on else UITheme.BG, UITheme.INK if on else UITheme.MID)
		# The open tab has a double-thick ink edge, so it shows in every era palette.
		sb.set_border_width_all(2 if on else 1)
		b.add_theme_stylebox_override("normal", sb)
	_page_title.text = Loc.t(TAB_TITLES[t])
	_page_hint.text = "(" + ShopCatalog.euro_hint(Billing.balance()) + ")" if t == "riftglass" and Billing.state.has("balance") else ""
	_clear()
	match t:
		"featured": _fill_featured()
		"more": _fill_more()
		"pass": _fill_pass()
		_: _fill_tab(t)
	_scroll.scroll_vertical = 0

func _clear() -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

func _fill_featured() -> void:
	var list: Array[Dictionary] = featured_offers()
	if list.is_empty():
		_list.add_child(_note(Loc.t("Nothing here yet. New offers come with updates.")))
		return
	_list.add_child(banner_card(list[0]))
	for i: int in range(1, list.size()):
		_list.add_child(offer_card(list[i]))
	_list.add_child(_link_button(Loc.t("All advantages"), func() -> void: select_tab("advantages")))

func _fill_tab(t: String) -> void:
	if t == "advantages":
		var power: String = ShopEffects.next_power_line()
		if not power.is_empty():
			_list.add_child(_note(Loc.t(power)))
	var list: Array[Dictionary] = shown_offers(t)
	if list.is_empty():
		_list.add_child(_note(Loc.t("Nothing here yet. New offers come with updates.")))
	for o: Dictionary in list:
		_list.add_child(offer_card(o))
	if t == "riftglass":
		_list.add_child(_note(Loc.t(ShopMenu.RG_NO_VALUE)))

func _fill_pass() -> void:
	var box := _panel(UITheme.ACCENT, UITheme.INK)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	head.add_child(_icon_rect(ShopArt.icon("scroll", 2)))
	var name_l := _label(Loc.t(str(ShopCatalog.offer("rg_pass").get("name", "Wayfarer Pass"))), UITheme.INK, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	v.add_child(head)
	v.add_child(_label(ShopMenu.pass_status_text(), UITheme.INK, true))
	v.add_child(_action_button(Loc.t("Show the pass"), _open_pass))
	_list.add_child(box)
	for o: Dictionary in shown_offers("pass"):
		_list.add_child(offer_card(o))

func _fill_more() -> void:
	for label: String in more_entries():
		var l: String = label
		_list.add_child(_link_button(Loc.t(l), func() -> void: _run_more(l)))
	_list.add_child(_note(Loc.t(ShopMenu.RG_NO_VALUE)))

## The rows of the More tab: the old shop list's pages, all still here.
static func more_entries() -> Array[String]:
	var out: Array[String] = ["My purchases", "Spending limit", "About purchases", "Help with purchases"]
	if not ShopMenu.owned_looks().is_empty():
		out.append("Wardrobe")
	# Apple guideline 3.1.1: bought unlocks and the pass can be restored (only with a store).
	if Billing.available():
		out.append("Restore purchases")
	return out

func _run_more(label: String) -> void:
	await _dialog(func() -> void: await ShopMenu.run_more_entry(menu, label))

func _open_pass() -> void:
	await _dialog(func() -> void: await open_pass(menu))

## The pass screen of the pass track when it is built, else the pass page as text.
static func open_pass(host: MenuHost) -> void:
	var path: String = pass_screen_path()
	if not path.is_empty():
		var script: Script = load(path)
		if script != null and script.has_method("run"):
			await script.call("run", host)
			return
	await host.info(ShopMenu.pass_text(ShopCatalog.offer("rg_pass")))

## Where the PassScreen class lives ("" while it does not exist).
static func pass_screen_path() -> String:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == PASS_PATH.get_file().get_basename():
			return str(c.get("path", ""))
	return PASS_PATH if ResourceLoader.exists(PASS_PATH) else ""

# --- Detail ------------------------------------------------------------------------------------

func show_detail(o: Dictionary) -> void:
	detail = o
	_tabs_row.visible = false
	_page_title.text = Loc.t(TAB_TITLES.get(str(o.get("tab", "")), "Shop"))
	_page_hint.text = ""
	_clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var big := _icon_rect(ShopArt.offer_icon(o, 2))
	big.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(big)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(_label(Loc.t(str(o.name)), UITheme.INK, true, "offer_name"))
	var tags: HFlowContainer = _tags_row(o)
	if tags != null:
		hv.add_child(tags)
	head.add_child(hv)
	_list.add_child(head)
	var pic: Texture2D = await ShopPreview.picture(o, self)
	if pic != null and detail == o:
		var pr := _icon_rect(pic)
		pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(pr)
	if detail != o:
		return
	var body: String = ShopMenu.detail_text(o) + ShopPreview.preview_text(o)
	# The name is in the head already.
	body = body.substr(body.find("\n") + 1).strip_edges()
	# "(≈ 1,98 €)" never breaks before the euro sign.
	body = body.replace(" €", Loc.NO_BREAK + "€")
	_list.add_child(_label(body, UITheme.INK, true, "detail_body"))
	var why: String = state_text(o)
	if not why.is_empty():
		_list.add_child(_note(why))
	_fill_buy_bar(o)
	_scroll.scroll_vertical = 0

func _fill_buy_bar(o: Dictionary) -> void:
	for c: Node in _buy_bar.get_children():
		c.queue_free()
	_buy_bar.visible = true
	var key: String = ShopMenu.look_key(o)
	if (not key.is_empty() and Billing.unlocked(key) > 0) or (str(o.get("slot", "")) == "gift_card" and Billing.unlocked("gift_card_" + FriendsMenu.GIFT_CARDS.keys()[0]) > 0):
		_buy_bar.add_child(_action_button(Loc.t("Use it"), func() -> void: _dialog(func() -> void: await ShopMenu.run_owned(menu, o))))
		return
	for line: Array in buy_options(o):
		var b: Button = _action_button(str(line[0]), func() -> void: _buy(o, bool(line[1])), true)
		b.name = "buy_rg" if bool(line[1]) else "buy_store"
		b.disabled = not str(line[2]).is_empty()
		_buy_bar.add_child(b)
	if _buy_bar.get_child_count() == 0:
		_buy_bar.add_child(_note(Loc.t(StoreNames.pick(StoreNames.NO_STORE))))

## The buy buttons of [param o]: [text, with Riftglass, why it cannot be bought ("" = it can)].
static func buy_options(o: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	if int(o.get("rg_price", 0)) > 0:
		var why: String = Billing.block_reason(o, true)
		out.append([Loc.t("Pay %d Riftglass") % int(o.rg_price) + "\n(" + ShopCatalog.euro_hint(int(o.rg_price)) + ")", true,
			why if why in ["offer_limit", "not_yet", "tier_order", "not_available"] else ""])
	var p: String = Billing.price_text(o)
	if not p.is_empty():
		var why2: String = Billing.block_reason(o, false)
		out.append([Loc.t("Pay in the store: %s") % p, false, why2 if why2 in ["offer_limit", "not_yet", "tier_order", "not_available"] else ""])
	return out

func _buy(o: Dictionary, with_rg: bool) -> void:
	await _dialog(func() -> void: await ShopMenu.buy(menu, o, with_rg))

## Runs [param job] (a dialog of the menu host) with the shop hidden, then shows the shop again
## with the new balance and states.
func _dialog(job: Callable) -> void:
	if _busy:
		return
	_busy = true
	visible = false
	await job.call()
	if not is_inside_tree():
		return
	visible = true
	_busy = false
	_refresh_balance()
	if not detail.is_empty():
		show_detail(detail)
	else:
		select_tab(tab)

func go_back() -> void:
	if _busy:
		return
	if not detail.is_empty():
		select_tab(tab)
		return
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _busy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()

# --- Cards -------------------------------------------------------------------------------------

## One offer card: tags, icon, the full name (wrapped, never cut), what is inside and the price.
## A tap anywhere on it opens the detail page.
func offer_card(o: Dictionary) -> Control:
	var card := _panel(UITheme.BG, UITheme.INK if o.has("badge") else UITheme.MID)
	card.name = "card_" + str(o.get("id", ""))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)
	var tags: HFlowContainer = _tags_row(o)
	if tags != null:
		v.add_child(tags)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var tile := _panel(UITheme.ACCENT, UITheme.INK)
	tile.add_child(_icon_rect(ShopArt.offer_icon(o)))
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tile)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label((ShopMenu.ADVANTAGE_MARK if ShopCatalog.is_advantage(o) else "") + Loc.t(str(o.name)), UITheme.INK, true, "offer_name"))
	var inside: String = short_contents(o)
	if not inside.is_empty():
		text.add_child(_label(inside, UITheme.MID, true, "contents"))
	row.add_child(text)
	v.add_child(row)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 2)
	# "Owned" stands on the price block already.
	var state := _label(state_text(o) if offer_state(o) != "owned" else "", UITheme.MID, true, "state")
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(state)
	bottom.add_child(price_box(o, false))
	v.add_child(bottom)
	card.add_child(_tap_cover(o, Loc.t(str(o.name)) + ", " + card_price(o)))
	return card

## The big card at the top of Featured: larger icon and name, every content line, what it is
## worth one by one and a wide price button.
## [param room] is the screen width (the viewport's when it is left out).
func banner_card(o: Dictionary, room: float = -1.0) -> Control:
	var w: float = room if room > 0.0 else get_viewport_rect().size.x
	var card := _panel(UITheme.ACCENT, UITheme.INK, 2)
	card.name = "banner_" + str(o.get("id", ""))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var tags: HFlowContainer = _tags_row(o)
	if tags != null:
		v.add_child(tags)
	var name_l := _label(Loc.t(str(o.name)), UITheme.INK, true, "offer_name")
	# The large font only when every word of the name fits the card in it.
	if UITheme.font() == PixelFont.get_font() and longest_word(Loc.t(str(o.name)), PixelFont.get_large_font()) <= w - 30.0:
		name_l.add_theme_font_override("font", PixelFont.get_large_font())
	v.add_child(name_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var tile := _panel(UITheme.BG, UITheme.INK)
	tile.add_child(_icon_rect(ShopArt.offer_icon(o, 2)))
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tile)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	var rule: String = ShopMenu.limit_line(o)
	if not rule.is_empty():
		hv.add_child(_label(rule, UITheme.MID, true, "rule"))
	row.add_child(hv)
	v.add_child(row)
	for line: String in ShopCatalog.grant_lines(o):
		v.add_child(_label("- " + line, UITheme.INK, true, "line"))
	var worth: int = ShopCatalog.single_value(o)
	if str(o.get("tab", "")) == "packs" and worth > 0:
		v.add_child(_label(Loc.t("Worth one by one: %s") % ShopCatalog.rg_text(worth), UITheme.MID, true, "worth"))
	var price := price_box(o, true)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(price)
	card.add_child(_tap_cover(o, Loc.t(str(o.name)) + ", " + card_price(o)))
	return card

## Width of the widest word of [param text] in [param f] at the theme size.
static func longest_word(text: String, f: Font) -> float:
	var w: float = 0.0
	for word: String in text.split(" ", false):
		w = maxf(w, f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x)
	return w

## The price block: Riftglass amount with the gem and its euro value, or the store's price text.
## [param wide] fills the card (banner).
func price_box(o: Dictionary, wide: bool) -> Control:
	var st: String = offer_state(o)
	var box := _panel(UITheme.DISABLED if st != "" else UITheme.INK, UITheme.INK)
	box.name = "price"
	box.custom_minimum_size = Vector2(0, TOUCH if wide else 18)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	box.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 1)
	if int(o.get("rg_price", 0)) > 0 and st == "":
		h.add_child(_icon_rect(ShopArt.icon("gem")))
	var l := _label(card_price(o), UITheme.BG)
	l.name = "price_text"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	v.add_child(h)
	if int(o.get("rg_price", 0)) > 0 and st == "":
		var e := _label("(" + ShopCatalog.euro_hint(int(o.rg_price)) + ")", UITheme.ACCENT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(e)
	return box

## A transparent button over a whole card: tap or accept opens the detail page.
func _tap_cover(o: Dictionary, say: String) -> Button:
	var b := Button.new()
	b.name = "open"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for s: String in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UITheme.INK
	focus.set_border_width_all(1)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	b.add_theme_stylebox_override("focus", focus)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(UITheme.INK, 0.15)
	b.add_theme_stylebox_override("pressed", pressed)
	b.set("accessibility_name", say)
	b.pressed.connect(func() -> void: show_detail(o))
	return b

func _tags_row(o: Dictionary) -> HFlowContainer:
	var list: Array[Array] = tags(o, int(Time.get_unix_time_from_system()))
	if list.is_empty():
		return null
	var flow := HFlowContainer.new()
	flow.name = "tags"
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 1)
	for t: Array in list:
		flow.add_child(ShopArt.tag(str(t[0]), str(t[1])))
	return flow

# --- Small parts -------------------------------------------------------------------------------

func _label(text: String, color: Color, wrap: bool = false, node_name: String = "") -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(1, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not node_name.is_empty():
		l.name = node_name
	return l

func _note(text: String) -> Control:
	var p := _panel(UITheme.BG, UITheme.DISABLED)
	p.add_child(_label(text, UITheme.MID, true, "note"))
	return p

func _panel(bg: Color, border: Color, width: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 2 + width
	sb.content_margin_right = 2 + width
	sb.content_margin_top = 1 + width
	sb.content_margin_bottom = 1 + width
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

func _icon_rect(t: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = t.get_size() if t != null else Vector2.ZERO
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A wide button; [param primary] is ink with paper text (buy).
func _action_button(text: String, on_press: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(1, TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.INK if primary else UITheme.ACCENT, UITheme.INK))
	if primary:
		b.add_theme_color_override("font_color", UITheme.BG)
	b.pressed.connect(on_press)
	return b

func _link_button(text: String, on_press: Callable) -> Button:
	var b := _action_button(text, on_press)
	b.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.BG, UITheme.MID))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

# --- Rules (pure, tested) ----------------------------------------------------------------------

## Unix time an offer ends (0 = no end): its "ends_at", or the end of today's deal.
static func end_time(o: Dictionary, now: int = -1) -> int:
	var s: String = str(o.get("ends_at", ""))
	if not s.is_empty():
		return int(Time.get_unix_time_from_datetime_string(s))
	if o.has("rotation") and _catalog_has("deal_ends_at"):
		return int((load(CATALOG_SCRIPT) as Script).call("deal_ends_at", o, now if now >= 0 else int(Time.get_unix_time_from_system())))
	return 0

## True when ShopCatalog has the static function [param fn] (the deals came with the offer
## rebuild; this screen works without them).
static func _catalog_has(fn: String) -> bool:
	for m: Dictionary in (load(CATALOG_SCRIPT) as Script).get_script_method_list():
		if str(m.get("name", "")) == fn:
			return true
	return false

## False for a rotating deal that is not on today (ShopCatalog.deal_active).
static func deal_on(o: Dictionary, now: int) -> bool:
	if not o.has("rotation") or not _catalog_has("deal_active"):
		return true
	return bool((load(CATALOG_SCRIPT) as Script).call("deal_active", o, now))

## True once an offer's "ends_at" has passed.
static func expired(o: Dictionary, now: int) -> bool:
	var e: int = end_time(o)
	return e > 0 and now >= e

## The offers shown in [param t]: ready and not ended.
static func shown_offers(t: String, now: int = -1) -> Array[Dictionary]:
	var at: int = now if now >= 0 else int(Time.get_unix_time_from_system())
	var out: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.in_tab(t):
		if not expired(o, at) and deal_on(o, at):
			out.append(o)
	return out

## "owned" when it is bought as often as it is sold, "later" when it comes later in the journey or
## after another tier, "" when it can be bought.
static func offer_state(o: Dictionary) -> String:
	var key: String = ShopMenu.look_key(o)
	if not key.is_empty() and Billing.unlocked(key) > 0:
		return "owned"
	var why: String = Billing.block_reason(o, int(o.get("rg_price", 0)) > 0)
	if why == "offer_limit":
		return "owned"
	if why in ["not_yet", "tier_order", "not_now"]:
		return "later"
	return ""

## The line under a card for its state ("" when it can be bought).
static func state_text(o: Dictionary) -> String:
	match offer_state(o):
		"owned":
			return Loc.t("Yours")
		"later":
			var why: String = Billing.block_reason(o, int(o.get("rg_price", 0)) > 0)
			return Loc.t("After the tier before it") if why == "tier_order" else Loc.t("Later in the journey")
	return ""

## The price on a card: "500" (with the gem drawn beside it), the store's price text, or "Show"
## while the store has sent no price (prices only ever come from the store, item 4095).
static func card_price(o: Dictionary) -> String:
	match offer_state(o):
		"owned":
			return Loc.t("Owned")
		"later":
			return Loc.t("Later")
	if int(o.get("rg_price", 0)) > 0:
		return str(int(o.rg_price))
	var p: String = Billing.price_text(o)
	return p if not p.is_empty() else Loc.t("Show")

## What is inside, short, for a card; "" when the name says it already (a Riftglass tier).
## A single thing of the offer's own name says what it does instead (first sentence of its text).
static func short_contents(o: Dictionary) -> String:
	var line: String = ShopCatalog.contents_line(o)
	var name: String = Loc.t(str(o.get("name", "")))
	if line == name:
		return ""
	if line == "1x " + name or line == "%dx %s" % [1, name]:
		return first_sentence(Loc.t(str(o.get("desc", ""))))
	return line

## The first sentence of [param text] ("" stays "").
static func first_sentence(text: String) -> String:
	var at: int = text.find(". ")
	return text if at < 0 else text.left(at + 1)

## Tags of an offer as [text, kind]: badge, discount, Riftglass bonus, first purchase doubled and
## the end (a plain date and time, never a running countdown: docs/MONETIZATION.md rule 5).
static func tags(o: Dictionary, now: int) -> Array[Array]:
	var out: Array[Array] = []
	var badge: String = str(o.get("badge", ""))
	if BADGES.has(badge):
		out.append([Loc.t(BADGES[badge]), badge])
	if int(o.get("discount_pct", 0)) > 0:
		out.append([Loc.t("-%d %%") % int(o.discount_pct), "discount"])
	if int(o.get("bonus_pct", 0)) > 0:
		out.append([Loc.t("+%d %% bonus") % int(o.bonus_pct), "bonus"])
	if bool(o.get("first_buy_double", false)) and int((Billing.state.get("bought", {}) as Dictionary).get(str(o.get("id", "")), 0)) == 0:
		out.append([Loc.t("First buy x2"), "double"])
	var e: int = end_time(o, now)
	if e > now:
		out.append([time_text(e), "time"])
	return out

## "Until 30. 11." or "Until 30. 11., 18:00" in the player's time zone.
static func time_text(at: int) -> String:
	var local: int = at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(local)
	var day: String = "%d. %d." % [int(d.day), int(d.month)]
	if int(d.hour) != 0 or int(d.minute) != 0:
		day += ", %02d:%02d" % [int(d.hour), int(d.minute)]
	return Loc.t("Until %s") % day

## The Riftglass tier the home page shows when none is marked: the biggest bonus, else the one
## closest to 9,99 EUR.
static func best_rg_tier() -> Dictionary:
	var best: Dictionary = {}
	for o: Dictionary in ShopCatalog.in_tab("riftglass"):
		if best.is_empty() or _tier_score(o) > _tier_score(best):
			best = o
	return best

static func _tier_score(o: Dictionary) -> int:
	return int(o.get("bonus_pct", 0)) * 100000 - absi(int(o.get("eur_cents", 0)) - 999)

## The Featured page: offers marked "featured" (the first is the banner), or the Starter Pack,
## the pass and the best Riftglass tier while none is marked. Offers that are owned, come later
## or have ended are left out.
static func featured_offers(now: int = -1) -> Array[Dictionary]:
	var at: int = now if now >= 0 else int(Time.get_unix_time_from_system())
	var out: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.offers():
		if bool(o.get("featured", false)) and bool(o.get("ready", false)) and not expired(o, at) and deal_on(o, at) and offer_state(o).is_empty():
			out.append(o)
	if not out.is_empty():
		return out
	for id: String in FEATURED_FALLBACK:
		var o: Dictionary = ShopCatalog.offer(id)
		if not o.is_empty() and bool(o.get("ready", false)) and not expired(o, at) and offer_state(o).is_empty():
			out.append(o)
	var tier: Dictionary = best_rg_tier()
	if not tier.is_empty():
		out.append(tier)
	return out

# --- Starter Pack note ---------------------------------------------------------------------------

## True when the Starter Pack note should open now: the tutorial act is over
## (GameState.ACT1_END_FLAG), it never opened before, the player is an adult by the server's age
## band (so never for kids_locked accounts), not in a battle, and the pack can be bought
## ([param reason] is Billing.block_reason of the pack, "" = buyable).
static func starter_popup_due(flags: Dictionary, band: Variant, reason: String, in_battle: bool) -> bool:
	if in_battle or not bool(flags.get(GameState.ACT1_END_FLAG, false)) or bool(flags.get(STARTER_SEEN_FLAG, false)):
		return false
	if band == null or int(band) < STARTER_POPUP_MIN_BAND:
		return false
	return reason.is_empty()

## The check for the world, with the live state (cheap checks first, it runs every frame).
static func starter_popup_now() -> bool:
	if not GameState.has_flag(GameState.ACT1_END_FLAG) or GameState.has_flag(STARTER_SEEN_FLAG) or Billing.state.is_empty():
		return false
	var o: Dictionary = ShopCatalog.offer(STARTER_ID)
	if o.is_empty():
		return false
	return starter_popup_due(GameState.flags, Billing.state.get("band"), Billing.block_reason(o, false), false)

## The Starter Pack note: the banner card with "Show offer" and "Not now". Marks itself seen at
## once, so it never comes twice. "Show offer" opens the shop on the pack.
static func run_starter_popup(host: MenuHost) -> void:
	GameState.set_flag(STARTER_SEEN_FLAG)
	var o: Dictionary = ShopCatalog.offer(STARTER_ID)
	if o.is_empty() or Billing.kids_locked():
		return
	var pop := StarterPopup.new()
	pop.offer = o
	host.add_child(pop)
	var want: bool = await pop.chosen
	pop.queue_free()
	if want:
		await ShopMenu.run(host, STARTER_ID)

## The note itself: a dimmed screen with the banner card and two buttons.
class StarterPopup extends Control:
	signal chosen(want: bool)
	var offer: Dictionary = {}

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(UITheme.INK, 0.6)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.offset_left = ShopScreen.MARGIN + 2
		center.offset_right = -ShopScreen.MARGIN - 2
		add_child(center)
		var maker := ShopScreen.new()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.custom_minimum_size = Vector2(get_viewport_rect().size.x - 2 * (ShopScreen.MARGIN + 2) - 4, 0)
		center.add_child(v)
		var head: Label = maker._label(Loc.t("A one-time pack for your journey"), UITheme.BG, true, "head")
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(head)
		var card: Control = maker.banner_card(offer, get_viewport_rect().size.x - 10.0)
		for c: Node in card.get_children():
			if c is Button:
				card.remove_child(c)
				c.queue_free()
		v.add_child(card)
		var see: Button = maker._action_button(Loc.t("Show offer"), func() -> void: chosen.emit(true))
		see.name = "show"
		v.add_child(see)
		var later: Button = maker._link_button(Loc.t("Not now"), func() -> void: chosen.emit(false))
		later.name = "later"
		later.alignment = HORIZONTAL_ALIGNMENT_CENTER
		later.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.BG, UITheme.INK))
		v.add_child(later)
		maker.free()
		later.grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			chosen.emit(false)

# --- Fit check ---------------------------------------------------------------------------------

## What does not fit on [param s] as plain sentences (empty = sound): a text cut off or a word
## broken inside, a part that leaves the screen sideways, a text smaller than the theme font, a
## button smaller than a finger. Used by the GUT tests and tools/p2w_shop_shots.gd.
static func fit_problems(s: Control) -> Array[String]:
	var out: Array[String] = []
	var vp: Rect2 = s.get_viewport_rect()
	_fit_walk(s, vp, out)
	return out

static func _fit_walk(c: Node, vp: Rect2, out: Array[String]) -> void:
	for n: Node in c.get_children():
		var ctl: Control = n as Control
		if ctl == null or not ctl.is_visible_in_tree():
			continue
		var r: Rect2 = ctl.get_global_rect()
		if r.size.x > 0.0 and (r.position.x < vp.position.x - 0.5 or r.end.x > vp.end.x + 0.5):
			out.append("leaves the screen: %s %s" % [ctl.name, _text_of(ctl)])
		if ctl is Label:
			_fit_label(ctl as Label, out)
		elif ctl is Button:
			var b: Button = ctl as Button
			if r.size.y < TAB_H - 0.5 and not b.flat:
				out.append("button below finger size: %s" % _text_of(b))
			if not b.text.is_empty() and b.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var f: Font = b.get_theme_font("font")
				var fs: int = b.get_theme_font_size("font_size")
				var sb: StyleBox = b.get_theme_stylebox("normal")
				var room: float = r.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT) - (b.icon.get_width() + 2 if b.icon != null else 0)
				if f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
					out.append("button text cut off: %s" % b.text)
		_fit_walk(ctl, vp, out)

static func _fit_label(l: Label, out: Array[String]) -> void:
	if l.text.is_empty():
		return
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	if fs < UITheme.FONT_SIZE:
		out.append("text below the readable size: %s" % l.text)
	var sb: StyleBox = l.get_theme_stylebox("normal")
	var room: float = l.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		for line: String in l.text.split("\n"):
			if f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
				out.append("text cut off: %s" % line)
		return
	# Lines break after a hyphen too ("Ring-" / "Obergrenze").
	for word: String in l.text.replace("\n", " ").replace("-", "- ").split(" ", false):
		if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
			out.append("word broken: %s in %s" % [word, l.text.left(40)])
			return
	if l.get_line_count() > 0 and l.get_visible_line_count() < l.get_line_count() and l.max_lines_visible < 0:
		out.append("lines hidden: %s" % l.text.left(40))

static func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text.left(30)
	if c is Button:
		return (c as Button).text.left(30)
	return ""
