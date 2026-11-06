class_name BundMenu
extends RefCounted
## The bund menu (plan area 7, items 2817-2821, 2842): found a bund from two words, invite,
## ask to join, roles, leave at any time, dissolve. Opened from Friends when the "bund" flag is on.

const ROLES: Dictionary = {"leader": "Leader", "helper": "Helper", "member": "Member"}
const ERRORS: Dictionary = {
	"feature_off": "Bunds are closed right now.",
	"in_bund": "That Wayfarer is already in a bund.",
	"full": "That bund is full (30 Wayfarers).",
	"not_allowed": "Only the leader or a helper can do that.",
	"no_such_bund": "No bund found with that code.",
	"no_such_invite": "That invitation is gone.",
	"no_such_request": "That request is gone.",
	"no_such_member": "That Wayfarer is no longer in the bund.",
	"bad_name": "Pick two words for the name.",
}

static func role_text(role: String) -> String:
	return str(ROLES.get(role, "Member"))

static func member_line(m: Dictionary) -> String:
	var line: String = "%s  %s" % [str(m.get("name", "?")), Loc.t(role_text(str(m.get("role", ""))))]
	if bool(m.get("me", false)):
		line += "  " + Loc.t("(you)")
	elif bool(m.get("online", false)):
		line += "  " + Loc.t("online")
	return line

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

static func _call(menu: MenuHost, fn: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = await Online.call_fn(fn, args)
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		return r.data
	await menu.info(error_text(r))
	return {}

static func run(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("bund_info")
		if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
			await menu.info(error_text(r))
			return
		var done: bool
		if r.data.get("bund") is Dictionary:
			done = await _run_bund(menu, r.data.bund)
		else:
			done = await _run_none(menu, r.data.get("invites", []))
		if done:
			return

static func _run_none(menu: MenuHost, invites: Array) -> bool:
	var labels: Array[String] = []
	for i: Dictionary in invites:
		labels.append(Loc.t("Invitation: %s (%d) from %s") % [BundWords.name_of(int(i.name[0]), int(i.name[1])), int(i.size), str(i.by)])
	labels.append_array(["Found a bund...", "Ask to join a bund..."] as Array[String])
	var idx: int = await menu.pick_strings("You are not in a bund yet.", labels)
	if idx < 0:
		return true
	if idx < invites.size():
		var i: Dictionary = invites[idx]
		var yes: int = await menu.pick_strings(Loc.t("Join %s?") % BundWords.name_of(int(i.name[0]), int(i.name[1])),
			["Join", "Say no"] as Array[String])
		if yes >= 0:
			var got: Dictionary = await _call(menu, "bund_answer", {"p_bund": int(i.bund), "p_accept": yes == 0})
			if bool(got.get("joined", false)):
				Sound.sfx("confirm")
		return false
	if idx == invites.size():
		await found(menu)
		return false
	var code: String = await CodePrompt.ask(menu, "Friend code of someone in the bund", 8)
	if code.is_empty():
		return false
	var got: Dictionary = await _call(menu, "bund_request", {"p_code": code})
	if not got.is_empty():
		await menu.info("You joined the bund." if bool(got.get("joined", false)) else "Request sent. A leader or helper decides.")
	return false

## Two words make the name: roll until one fits, or choose each word.
static func found(menu: MenuHost) -> void:
	var a: int = randi() % BundWords.FIRST.size()
	var b: int = randi() % BundWords.SECOND.size()
	while true:
		var idx: int = await menu.pick_strings(Loc.t("Name of the bund: %s") % BundWords.name_of(a, b),
			["Found it", "Roll again", "Choose the first word...", "Choose the second word..."] as Array[String])
		match idx:
			-1:
				return
			0:
				var got: Dictionary = await _call(menu, "bund_create", {"p_a": a, "p_b": b})
				if not got.is_empty():
					Sound.sfx("confirm")
					await menu.info(Loc.t("%s is founded. Invite Wayfarers with their friend code.") % BundWords.name_of(a, b))
				return
			1:
				a = randi() % BundWords.FIRST.size()
				b = randi() % BundWords.SECOND.size()
			2:
				var opts: Array[String] = []
				for i: int in BundWords.FIRST.size():
					opts.append(BundWords.name_of(i, b))
				var p: int = await menu.pick_strings("First word", opts)
				a = p if p >= 0 else a
			3:
				var opts: Array[String] = []
				for i: int in BundWords.SECOND.size():
					opts.append(BundWords.name_of(a, i))
				var p: int = await menu.pick_strings("Second word", opts)
				b = p if p >= 0 else b

static func _run_bund(menu: MenuHost, bund: Dictionary) -> bool:
	var role: String = str(bund.role)
	var members: Array = bund.get("members", [])
	var pending: Array = bund.get("pending", [])
	var staff: bool = role in ["leader", "helper"]
	var labels: Array[String] = []
	for m: Dictionary in members:
		labels.append(member_line(m))
	var actions: Array[String] = []
	if staff:
		actions.append("Invite a Wayfarer...")
		if not pending.is_empty():
			actions.append(Loc.t("Requests (%d)") % pending.size())
	if role == "leader" and bund.get("dissolve_at") != null:
		actions.append_array(["Confirm dissolving", "Keep the bund"] as Array[String])
	elif role == "leader":
		actions.append("Dissolve the bund...")
	actions.append("Leave the bund...")
	labels.append_array(actions)
	var title: String = "%s  %d/30" % [BundWords.name_of(int(bund.name[0]), int(bund.name[1])), members.size()]
	var idx: int = await menu.pick_strings(title, labels)
	if idx < 0:
		return true
	if idx < members.size():
		await _run_member(menu, role, members[idx])
		return false
	match actions[idx - members.size()]:
		"Invite a Wayfarer...":
			var code: String = await CodePrompt.ask(menu, "Friend code of the Wayfarer", 8)
			if not code.is_empty():
				var got: Dictionary = await _call(menu, "bund_invite", {"p_code": code})
				if not got.is_empty():
					await menu.info("They joined the bund." if bool(got.get("joined", false)) else "Invitation sent.")
		"Dissolve the bund...", "Confirm dissolving":
			if await menu.confirm_danger("Dissolve the bund for everyone?"):
				var got: Dictionary = await _call(menu, "bund_dissolve")
				if bool(got.get("dissolved", false)):
					await menu.info("The bund is dissolved.")
				elif not got.is_empty():
					await menu.info(Loc.t("With 3 or more Wayfarers you confirm again after 24 hours, from %s.")
						% Time.get_datetime_string_from_unix_time(int(got.confirm_from), true))
		"Keep the bund":
			await _call(menu, "bund_keep")
		"Leave the bund...":
			if await menu.confirm("Leave the bund? You can join a bund again at any time."):
				await _call(menu, "bund_leave")
		_:
			await _run_requests(menu, pending)
	return false

static func _run_member(menu: MenuHost, role: String, m: Dictionary) -> void:
	if bool(m.get("me", false)):
		await menu.info(member_line(m))
		return
	var theirs: String = str(m.role)
	var opts: Array[String] = []
	if role == "leader":
		opts.append("Make member" if theirs == "helper" else "Make helper")
		opts.append("Hand over leadership")
	if role == "leader" or (role == "helper" and theirs == "member"):
		opts.append("Remove from the bund")
	if opts.is_empty():
		await menu.info(member_line(m))
		return
	var idx: int = await menu.pick_strings(member_line(m), opts)
	if idx < 0:
		return
	match opts[idx]:
		"Make helper": await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "helper"})
		"Make member": await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "member"})
		"Hand over leadership":
			if await menu.confirm(Loc.t("Make %s the leader? You become a helper.") % str(m.name)):
				await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "leader"})
		"Remove from the bund":
			if await menu.confirm(Loc.t("Remove %s from the bund?") % str(m.name)):
				await _call(menu, "bund_kick", {"p_code": str(m.code)})

static func _run_requests(menu: MenuHost, pending: Array) -> void:
	var asks: Array = pending.filter(func(p: Dictionary) -> bool: return p.kind == "request")
	var labels: Array[String] = []
	for p: Dictionary in pending:
		labels.append((Loc.t("%s asks to join") if p.kind == "request" else Loc.t("%s is invited")) % str(p.name))
	var idx: int = await menu.pick_strings("Requests", labels)
	if idx < 0 or pending[idx].kind != "request" or asks.is_empty():
		return
	var yes: int = await menu.pick_strings(labels[idx], ["Let them in", "Say no"] as Array[String])
	if yes >= 0:
		await _call(menu, "bund_admit", {"p_code": str(pending[idx].code), "p_accept": yes == 0})
