class_name AccountMenu
extends RefCounted
## Settings > Account: friend code, moving to a new phone with a transfer code (no email),
## the online rules, the privacy note and deleting the account (items 2, 4, 11, 20, 156).

const TITLE_SCENE: String = "res://scenes/ui/Title.tscn"

const PRIVACY_NOTE: String = "Chimora is online only. Your journeys are stored on our server in Germany, so they are safe if your phone breaks. We store your Tamer name, friend code and saves, nothing else. No ads, no tracking. You can delete everything under Settings, Account."
const ONLINE_RULES: String = "Online rules:\n- Be kind. Greetings use set phrases, there is no free chat.\n- Never share your real name, address or passwords.\n- Spirlings stay with the Tamer who bonded them. They cannot be traded or gifted.\n- Report names that are not okay. Blocking works at once.\n- Cheating gets the account reset."

static func run(menu: MenuHost) -> void:
	while true:
		var title: String = Loc.t("Account  Code %s") % Online.pretty_code(Online.friend_code())
		if Online.is_local():
			title += "\n" + Loc.t("(test server on this phone)")
		var entries: Array[String] = ["Get a transfer code", "Enter a code...", "Online rules", "Privacy", "Delete account...",
			"Friends and greetings: %s" % ("On" if Online.social_on() else "Off")]
		var idx: int = await menu.pick_strings(title, entries)
		match idx:
			-1:
				return
			0:
				await _show_transfer(menu)
			1:
				if await _claim_transfer(menu):
					return
			2:
				await menu.info(ONLINE_RULES)
			3:
				await menu.info(PRIVACY_NOTE)
			4:
				if await _delete(menu):
					return
			5:
				await _toggle_social(menu)

static func _show_transfer(menu: MenuHost) -> void:
	var r: Dictionary = await Online.transfer_create()
	if not r.ok or not r.data is Dictionary:
		await menu.info("No connection right now. Try again in a moment.")
		return
	var c: String = str(r.data.code)
	await menu.info("Your transfer code:\n\n%s-%s-%s\n\nOn the new phone open Settings, Account, Enter a code. It works once and for 7 days. Keep it secret: anyone with it gets your journeys." % [c.left(4), c.substr(4, 4), c.substr(8)])

static func _claim_transfer(menu: MenuHost) -> bool:
	if GameState.in_game:
		await menu.info("Enter the code on the title screen.")
		return false
	if not await menu.confirm("This phone will get the journeys of the other phone. Journeys saved on this phone are replaced. Continue?"):
		return false
	var code: String = await TextPrompt.ask(menu, "Transfer code", false, 16)
	if code.is_empty():
		return false
	var r: Dictionary = await Online.transfer_claim(code)
	if r.ok:
		await menu.info("Welcome back! Your journeys are here.")
		return true
	if r.error == "too_many_tries":
		await menu.info("Too many tries. Please wait an hour.")
	elif r.net:
		await menu.info("No connection right now. Try again in a moment.")
	else:
		await menu.info("That code does not work. Codes work once and for 7 days.")
	return false

## For parents (item 147): switches friends, mail and greetings off. Saves stay online.
static func _toggle_social(menu: MenuHost) -> void:
	var on: bool = not Online.social_on()
	if not on and not await menu.confirm("Switch off friends, greetings and gifts? Nobody can send you anything, and you cannot add friends. Your journeys stay online."):
		return
	if not await Online.set_social(on):
		await menu.info("No connection right now. Try again in a moment.")

static func _delete(menu: MenuHost) -> bool:
	if not await menu.confirm("Delete your account? All journeys and friends are removed for good."):
		return false
	if not await menu.confirm("Really delete? This cannot be undone."):
		return false
	var r: Dictionary = await Online.delete_account()
	if not r.ok:
		await menu.info("No connection right now. Nothing was deleted.")
		return false
	await menu.info("Your account was deleted.")
	GameState.in_game = false
	menu.get_tree().change_scene_to_file(TITLE_SCENE)
	return true
