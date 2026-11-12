class_name SafetyMenu
extends RefCounted
## Safety and fairness (Online 100, area 9): the parent switches under Settings, Account, For
## parents (points 85, 86) and the report straight after a league battle or a live duel (83).
## Server side: 20261113000010_safety.sql.

const REPORT_REASONS: Array[String] = ["Name not okay", "Unkind greetings", "Cheating", "Something else"]

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

static func _err(r: Dictionary) -> String:
	return Online.error_text(str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", "")))

## "Live duels: On" for one parent switch.
static func switch_line(key: String, off: Array) -> String:
	return Loc.t("%s: %s") % [Loc.t(SafetyRules.key_text(key)), Loc.t("Off") if off.has(key) else Loc.t("On")]

## The parent switches; under 16 the open league, bunds and suggestions start switched off.
static func run_parents(menu: MenuHost) -> void:
	var st: Dictionary = await Online.call_fn("parent_get")
	if not _ok(st):
		await menu.info(_err(st))
		return
	if not await menu.confirm("These switches are for parents. Continue?"):
		return
	var off: Array = (st.data.get("off", []) as Array).duplicate()
	var keys: Array = st.data.get("keys", [])
	while true:
		var labels: Array[String] = []
		for k: Variant in keys:
			labels.append(switch_line(str(k), off))
		var head: String = Loc.t("For parents: switch off what your child should not use. Friends and saves stay.")
		if bool(st.data.get("young", false)) and not bool(st.data.get("custom", false)):
			head += "\n" + Loc.t("Under 16: open league, bunds and suggestions start switched off.")
		var idx: int = await menu.pick_strings(head, labels)
		if idx < 0:
			return
		var key: String = str(keys[idx])
		var next: Array = off.duplicate()
		if next.has(key):
			next.erase(key)
		else:
			next.append(key)
		var r: Dictionary = await Online.call_fn("parent_set", {"p_off": next, "p_version": Online.CLIENT_VERSION})
		if _ok(r):
			off = (r.data.get("off", []) as Array).duplicate()
			st.data["custom"] = true
			if r.data.get("flags") is Array:
				Online.flags.assign(r.data.flags)
		else:
			await menu.info(_err(r))

## Offers a report of the rival right after a battle ([param kind] "league" or "duel").
static func after_battle(menu: MenuHost, kind: String, ref: int) -> void:
	var idx: int = await menu.pick_strings("Battle over", ["Continue", "Report the rival..."] as Array[String])
	if idx == 1:
		await report(menu, kind, ref)

static func report(menu: MenuHost, kind: String, ref: int) -> void:
	var reason: int = await menu.pick_strings("Why do you report the rival?", REPORT_REASONS)
	if reason < 0:
		return
	var r: Dictionary = await Online.call_fn("report_battle", {"p_kind": kind, "p_ref": str(ref), "p_reason": reason})
	if _ok(r):
		await menu.info(Loc.t("Thank you. Your report has number %d. We will look at it and tell you the result under Account, Messages from the team.") % int(r.data.get("report_id", 0)))
	elif r.ok and r.data is Dictionary and str(r.data.get("error", "")) == "no_such_battle":
		await menu.info("This battle was against your own echo, so there is nobody to report.")
	else:
		await menu.info(_err(r))
