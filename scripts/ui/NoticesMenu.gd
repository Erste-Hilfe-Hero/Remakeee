class_name NoticesMenu
extends RefCounted
## Messages from the team (plan area 7, items 2896-2898): the statement of reasons for every
## decision against the account (DSA Art. 17), the outcome of own reports, and objections to a
## decision (DSA Art. 20). Every text is fixed, nothing a person typed reaches the player.

const ACTIONS: Dictionary = {
	"name_reset": "Your Wayfarer name was reset.",
	"warning": "You got a warning. Nothing else changes.",
	"league_block": "You cannot play in leagues for now.",
}
const REASONS: Array[String] = ["The name is not okay.", "Greetings were unkind.", "Cheating.", "Another breach of the online rules."]
const PLACES: Dictionary = {
	"friends": "friend list", "card": "Wayfarer card", "duel": "duel", "trade": "trade", "bund": "bund",
	"raid": "raid", "board": "leaderboard", "league": "league",
}
const APPEAL_REASONS: Array[String] = ["I did not break the rule", "Someone else used my phone", "Something else"]

static func run(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("notices_list")
		if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
			await menu.info(FriendsMenu.error_text(r))
			return
		var notices: Array = r.data.get("notices", [])
		if notices.is_empty():
			await menu.info("No messages from the team.")
			return
		var entries: Array[String] = []
		for n: Dictionary in notices:
			entries.append(("" if bool(n.get("read", false)) else "* ") + Loc.t(title_of(n)) % int(n.get("report_id", 0)))
		var idx: int = await menu.pick_strings("Messages from the team", entries)
		if idx < 0:
			return
		await show(menu, notices[idx])

static func title_of(n: Dictionary) -> String:
	match str(n.get("kind", "")):
		"decision": return "Decision on report %d"
		"report_result": return "Your report %d"
	return "Your objection, report %d"

## The full text of one message, already translated.
static func text_of(n: Dictionary) -> String:
	var b: Dictionary = n.get("body", {}) if n.get("body") is Dictionary else {}
	var id: int = int(n.get("report_id", 0))
	match str(n.get("kind", "")):
		"decision":
			var lines: Array[String] = [
				Loc.t("Decision on report %d") % id,
				Loc.t("What we did:") + " " + Loc.t(str(ACTIONS.get(str(b.get("action", "")), "You got a warning. Nothing else changes."))),
				Loc.t("Why:") + " " + Loc.t(REASONS[clampi(int(b.get("reason", 3)), 0, 3)]) + " " + Loc.t("Section %s of the terms of use.") % str(b.get("rule", "4")),
				Loc.t("Where:") + " " + Loc.t(str(PLACES.get(str(b.get("context", "")), "friend list"))),
				Loc.t("A person from our team decided this, not a machine."),
				Loc.t("You can object until %s.") % Time.get_date_string_from_unix_time(int(b.get("appeal_until", 0))),
			]
			return "\n".join(lines)
		"report_result":
			if bool(b.get("upheld", false)):
				return Loc.t("Your report %d: we took action. Thank you.") % id
			return Loc.t("Your report %d: we found no breach of the rules.") % id
	if bool(b.get("changed", false)):
		return Loc.t("Your objection to report %d: we changed the decision.") % id
	return Loc.t("Your objection to report %d: we kept the decision.") % id

static func show(menu: MenuHost, n: Dictionary) -> void:
	if not bool(n.get("read", false)):
		await Online.call_fn("notice_read", {"p_id": int(n.id)})
	if str(n.get("kind", "")) != "decision":
		await menu.info(text_of(n))
		return
	if n.get("appeal") != null:
		await menu.info(text_of(n) + "\n" + Loc.t(appeal_state(str(n.appeal))))
		return
	var idx: int = await menu.pick_strings(text_of(n), ["Object to it", "Back"])
	if idx == 0:
		await appeal(menu, int(n.id))

static func appeal_state(status: String) -> String:
	match status:
		"changed": return "You objected. We changed the decision."
		"kept": return "You objected. We kept the decision."
	return "You objected. We will answer here."

static func appeal(menu: MenuHost, notice_id: int) -> void:
	var reason: int = await menu.pick_strings("Why do you object?", APPEAL_REASONS)
	if reason < 0:
		return
	var r: Dictionary = await Online.call_fn("appeal", {"p_notice": notice_id, "p_reason": reason})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("confirm")
		await menu.info("Thank you. A person from our team looks at it again and answers here.")
		return
	match str(r.data.get("error", "")) if r.get("data") is Dictionary else "":
		"too_late": await menu.info("The time to object has passed.")
		"appealed": await menu.info("You already objected to this.")
		_: await menu.info(FriendsMenu.error_text(r))
