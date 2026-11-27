class_name PassScreen
extends RefCounted
## The Wayfarer Pass track screen (Chimora pay2win rebuild): a drawn header with the step, the
## progress bar and both reward rows around the current step (free on top, premium below with a lock
## while the pass is missing), then one row per step in the shop's list layout (EraMenus "shop").
## A step opens its page with both rewards and the buttons to take them. Opened from the shop's Pass
## tab with PassScreen.run(host).

const ERRORS: Dictionary = {
	"not_reached": "Not reached yet.",
	"claimed": "Already taken.",
	"no_pass": "The premium row needs the Wayfarer Pass.",
	"bad_tier": "That reward does not exist.",
	"bad_lane": "That reward does not exist.",
	"offline": "No connection right now. Try again in a moment.",
}
const TITLE: String = "Pass track"
const PANEL_TEXT: String = "Top row: free for everyone. Bottom row: with the Wayfarer Pass. Pass points come from battles won (%d), bonds (%d) and daily tasks (%d), up to %d a day."
const PREMIUM_ROW: String = "Premium row: Wayfarer Pass"
const TAKE_ALL: String = "Take all rewards (%d)"

static func error_text(e: String) -> String:
	return Loc.t(str(ERRORS.get(e, "Something went wrong. Try again in a moment.")))

## "Pass track  Step 7 of 30" over "40 of 100 pass points" over "Until 30. 11." (the season end
## as a fixed date, never a running "ends in": docs/MONETIZATION.md rule 5). [param short] 1 leaves
## the date out, 2 also the "Pass track" name, for narrow screens (titles()).
static func title(st: Dictionary, short: int = 0) -> String:
	var pts: int = int(st.get("points", 0))
	var prog: Array[int] = PassTrack.progress(pts)
	var head: String = Loc.t("Step %d of %d") % [PassTrack.tier_for(pts), PassTrack.tier_count()]
	if short < 2:
		head = Loc.t(TITLE) + "  " + head
	var line: String = Loc.t("%d of %d pass points") % [prog[0], prog[1]]
	var ends: int = int(st.get("ends", 0))
	if ends > 0 and short < 1:
		line += "\n" + ShopScreen.time_text(ends)
	return head + "\n" + line

## The title candidates, fullest first, for MenuHost.fit_title.
static func titles(st: Dictionary) -> Array[String]:
	return [title(st), title(st, 1), title(st, 2)]

static func panel_text() -> String:
	return Loc.t(PANEL_TEXT) % [PassTrack.points_for("win"), PassTrack.points_for("bond"), PassTrack.points_for("daily_task"), PassTrack.day_cap()]

## The page of one step: both rewards with their state.
static func step_text(st: Dictionary, tier: int) -> String:
	var lines: Array[String] = [Loc.t("Step %d of %d") % [tier, PassTrack.tier_count()], ""]
	for lane: String in PassTrack.LANES:
		var label: String = Loc.t("Free:") if lane == "free" else Loc.t("Premium (Wayfarer Pass):")
		lines.append(label)
		lines.append("- " + PassTrack.reward_text(PassTrack.reward(tier, lane)))
		lines.append("  " + state_word(st, tier, lane))
	return "\n".join(lines)

static func state_word(st: Dictionary, tier: int, lane: String) -> String:
	match PassTrack.block_reason(st, tier, lane):
		"":
			return Loc.t("Ready to take.")
		"claimed":
			return Loc.t("Taken.")
		"no_pass":
			return Loc.t("Locked: needs the Wayfarer Pass.")
	return Loc.t("Reached at %d pass points.") % (tier * PassTrack.per_tier())

## The list rows: take-all, the premium row offer (never for children), then every step.
static func rows(st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open: int = PassTrack.open_claims(st).size()
	if open > 0:
		out.append({"text": Loc.t(TAKE_ALL) % open, "act": "all"})
	if not bool(st.get("premium", false)) and not Billing.kids_locked():
		var locked: int = PassTrack.locked_premium(st)
		out.append({"text": Loc.t(PREMIUM_ROW), "act": "premium",
			"hint": Loc.t("%d premium rewards reached and waiting.") % locked if locked > 0 else Loc.t("Opens the premium row of every step.")})
	for t: int in range(1, PassTrack.tier_count() + 1):
		var tier: int = t
		out.append({"text": Loc.t("Step %d") % t, "act": "step", "tier": t,
			"hint": Loc.t("Free: %s") % PassTrack.reward_text(PassTrack.reward(t, "free")) + "\n" + Loc.t("Premium: %s") % PassTrack.reward_text(PassTrack.reward(t, "premium")),
			"right": "  ", "right_pad": 24.0,
			"decorate": func(b: Button) -> void: draw_marks(b, st, tier)})
	return out

## The focus row: the first reward that waits, else the current step.
static func focus_row(list: Array[Dictionary], st: Dictionary) -> int:
	var want: int = mini(PassTrack.tier_for(int(st.get("points", 0))) + 1, PassTrack.tier_count())
	var open: Array[Array] = PassTrack.open_claims(st)
	if not open.is_empty():
		want = int(open[0][0])
	for i: int in list.size():
		if int(list[i].get("tier", 0)) == want:
			return i
	return 0

static func run(menu: MenuHost) -> void:
	# The track in finger and reading size (ShopZoom).
	var h: MenuHost = ShopZoom.enter(menu)
	await _run(h)
	ShopZoom.leave(h)

static func _run(host: MenuHost) -> void:
	var r: Dictionary = await PassTrack.refresh()
	if not r.ok or PassTrack.state.is_empty():
		await host.info(error_text("offline"))
		return
	while true:
		var st: Dictionary = PassTrack.state
		var list: Array[Dictionary] = rows(st)
		var view := PassTrackView.new()
		view.st = st.duplicate()
		view.custom_minimum_size = Vector2(0, PassTrackView.HEIGHT)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The status title never pops up as a page before the list (MenuHost.fit_title).
		var idx: int = await host.pick_screen("shop", host.fit_title(titles(st)), list, {"header": view, "panel_text": panel_text(),
			"focus": focus_row(list, st)})
		if idx < 0:
			return
		match str(list[idx].act):
			"all":
				await _take_all(host)
			"premium":
				await _open_pass_offer(host)
			"step":
				await _run_step(host, int(list[idx].tier))
		await PassTrack.refresh()

static func _take_all(host: MenuHost) -> void:
	var got: Array[String] = []
	for c: Array in PassTrack.open_claims(PassTrack.state):
		var d: Dictionary = await PassTrack.claim(int(c[0]), str(c[1]))
		if not bool(d.get("ok", false)):
			got.append(error_text(str(d.get("error", ""))))
			break
		got.append(Loc.t("Step %d: %s") % [int(c[0]), PassTrack.reward_text(d.get("grants", []))])
	if not got.is_empty():
		Sound.sfx("coin")
		await host.info(Loc.t("You got:") + "\n" + "\n".join(got))

static func _run_step(host: MenuHost, tier: int) -> void:
	while true:
		var st: Dictionary = PassTrack.state
		var opts: Array[String] = []
		var acts: Array[String] = []
		for lane: String in PassTrack.LANES:
			if PassTrack.block_reason(st, tier, lane).is_empty():
				opts.append("Take the free reward" if lane == "free" else "Take the premium reward")
				acts.append(lane)
		if PassTrack.block_reason(st, tier, "premium") == "no_pass" and not Billing.kids_locked():
			opts.append(PREMIUM_ROW)
			acts.append("premium")
		if opts.is_empty():
			await host.info(step_text(st, tier))
			return
		var i: int = await host.pick_strings(step_text(st, tier), opts)
		if i < 0:
			return
		if acts[i] == "premium":
			await _open_pass_offer(host)
			await PassTrack.refresh()
			continue
		var d: Dictionary = await PassTrack.claim(tier, acts[i])
		if bool(d.get("ok", false)):
			Sound.sfx("coin")
			await host.info(Loc.t("You got: %s") % PassTrack.reward_text(d.get("grants", [])))
		else:
			await host.info(error_text(str(d.get("error", ""))))

## The Wayfarer Pass on the shop screen's detail page (price, contents, buy buttons); Back
## comes back to the track.
static func _open_pass_offer(host: MenuHost) -> void:
	var o: Dictionary = ShopCatalog.offer(PassTrack.PASS_OFFER)
	if o.is_empty():
		return
	await ShopScreen.open(host, PassTrack.PASS_OFFER, "pass", true)

## The two state marks at the right end of a step row: free left, premium right.
static func draw_marks(b: Button, st: Dictionary, tier: int) -> void:
	var y: float = floorf((b.size.y - PassTrackView.MARK) / 2.0)
	PassTrackView.draw_mark(b, Rect2(b.size.x - 22.0, y, PassTrackView.MARK, PassTrackView.MARK), st, tier, "free")
	PassTrackView.draw_mark(b, Rect2(b.size.x - 11.0, y, PassTrackView.MARK, PassTrackView.MARK), st, tier, "premium")

## The drawn header: step and progress bar, then five steps around the current one with their free
## (top) and premium (bottom) reward boxes. UITheme colours only, pixel rectangles, no art files.
class PassTrackView extends Control:
	const HEIGHT: float = 52.0
	const COLUMNS: int = 5
	const MARK: float = 8.0
	var st: Dictionary = {}

	func _ready() -> void:
		name = "pass_track"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## First step shown: the current one second from the left, never past the end.
	static func first_column(tier: int) -> int:
		return clampi(tier, 1, maxi(1, PassTrack.tier_count() - COLUMNS + 1))

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var fs: int = UITheme.FONT_SIZE
		var pts: int = int(st.get("points", 0))
		var tier: int = PassTrack.tier_for(pts)
		var prog: Array[int] = PassTrack.progress(pts)
		# Progress bar of the step being filled.
		var bar := Rect2(2, 2, size.x - 4, 6)
		draw_rect(bar, UITheme.BG)
		draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(prog[0]) / float(maxi(prog[1], 1))), bar.size.y)), UITheme.ACCENT)
		draw_rect(bar, UITheme.INK, false, 1.0)
		# Lane symbols: a dot for the free row, a star for the premium row.
		var top: float = 12.0 + font.get_height(fs)
		var box_h: float = 12.0
		draw_rect(Rect2(3, top + 4, 3, 3), UITheme.INK)
		_star(Vector2(4, top + box_h + 8), UITheme.INK)
		var x0: float = 10.0
		var cw: float = floorf((size.x - x0 - 2.0) / float(COLUMNS))
		var first: int = first_column(tier)
		for c: int in COLUMNS:
			var t: int = first + c
			if t > PassTrack.tier_count():
				break
			var x: float = x0 + c * cw
			var label: String = str(t)
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var ink: Color = UITheme.INK if t <= tier else UITheme.DISABLED
			draw_string(font, Vector2(x + floorf((cw - w) / 2.0), 10.0 + font.get_ascent(fs)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			if t == tier + 1:
				# The next step: an arrow under its number.
				draw_rect(Rect2(x + floorf(cw / 2.0) - 1.0, top - 2.0, 3, 1), UITheme.INK)
			for lane_i: int in 2:
				var lane: String = PassTrack.LANES[lane_i]
				var r := Rect2(x + 2.0, top + lane_i * (box_h + 2.0), cw - 4.0, box_h)
				draw_rect(r, UITheme.BG)
				var mark := Rect2(r.position + Vector2(floorf((r.size.x - MARK) / 2.0), floorf((r.size.y - MARK) / 2.0)), Vector2(MARK, MARK))
				draw_mark(self, mark, st, t, lane)
				draw_rect(r, UITheme.INK if t <= tier else UITheme.DISABLED, false, 1.0)

	func _star(c: Vector2, col: Color) -> void:
		draw_rect(Rect2(c.x - 1, c.y - 2, 1, 5), col)
		draw_rect(Rect2(c.x - 3, c.y, 5, 1), col)
		draw_rect(Rect2(c.x - 2, c.y - 1, 3, 3), col)

	## One reward state in [param r]: a check when taken, a filled box when it waits, a lock on a
	## premium reward without the pass, an empty box when not reached.
	static func draw_mark(ci: CanvasItem, r: Rect2, s: Dictionary, tier: int, lane: String) -> void:
		var p: Vector2 = r.position
		match PassTrack.block_reason(s, tier, lane):
			"claimed":
				for i: int in 3:
					ci.draw_rect(Rect2(p.x + 1 + i, p.y + 4 + i, 1, 1), UITheme.INK)
				for i: int in 4:
					ci.draw_rect(Rect2(p.x + 4 + i, p.y + 5 - i, 1, 1), UITheme.INK)
			"":
				ci.draw_rect(Rect2(p, r.size), UITheme.ACCENT)
				ci.draw_rect(Rect2(p, r.size), UITheme.INK, false, 1.0)
				ci.draw_rect(Rect2(p.x + 3, p.y + 2, 2, 4), UITheme.INK)
			"no_pass":
				# Lock: shackle over a body with a keyhole.
				ci.draw_rect(Rect2(p.x + 2, p.y, 4, 4), UITheme.INK, false, 1.0)
				ci.draw_rect(Rect2(p.x + 1, p.y + 3, 6, 5), UITheme.INK)
				ci.draw_rect(Rect2(p.x + 4, p.y + 5, 1, 2), UITheme.BG)
			_:
				ci.draw_rect(Rect2(p.x + 2, p.y + 2, 4, 4), UITheme.DISABLED, false, 1.0)
