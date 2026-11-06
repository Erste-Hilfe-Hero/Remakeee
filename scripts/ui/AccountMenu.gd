class_name AccountMenu
extends RefCounted
## Settings > Account: friend code, moving to a new phone with a transfer code (no email),
## the online rules, the privacy note and deleting the account (items 2, 4, 11, 20, 156).

const TITLE_SCENE: String = "res://scenes/ui/Title.tscn"
const TRANSFER_CODE_LENGTH: int = 12

const PRIVACY_NOTE: String = "Chimora is online only. Your journeys are stored on our server in Germany, so they are safe if your phone breaks. We store your Wayfarer name, friend code, saves, friends, Lantern Mail and league standings, nothing else. No ads, no tracking. You can download or delete everything under Settings, Account."
const ONLINE_RULES: String = "Online rules:\n- Be kind. Greetings use set phrases, there is no free chat.\n- Never share your real name, address or passwords.\n- Spirlings stay with the Wayfarer who bonded them. They cannot be traded or gifted.\n- Report names that are not okay. Blocking works at once.\n- Cheating gets the account reset."

static func run(menu: MenuHost) -> void:
	while true:
		var title: String = Loc.t("Account  Code %s") % Online.pretty_code(Online.friend_code())
		if Online.is_local():
			title += "\n" + Loc.t("(test server on this phone)")
		var entries: Array[String] = ["Get a transfer code", "Enter a code...", "Online rules", "Privacy", "Delete account...",
			"Friends and greetings: %s" % ("On" if Online.social_on() else "Off"), "Download my data", "Messages from the team"]
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
			6:
				await _export(menu)
			7:
				await NoticesMenu.run(menu)

## Everything the server keeps about this account as one JSON file (plan area 7, item 2972;
## GDPR Art. 15 and 20). The browser version downloads it, phones save it to the documents folder.
static func _export(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("data_export")
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
		await menu.info(Online.error_text(str(r.data.get("error", "")) if r.get("data") is Dictionary else str(r.get("error", ""))))
		return
	var text: String = JSON.stringify(r.data, "\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), EXPORT_FILE, "application/json")
		await menu.info("Your data is downloading as %s." % EXPORT_FILE)
		return
	var path: String = write_export(text)
	if path.is_empty():
		await menu.info("The file could not be saved. Write to our support and we send your data by email.")
		return
	await menu.info(Loc.t("Your data was saved as:") + "\n" + path)

const EXPORT_FILE: String = "chimora-my-data.json"

## Writes the export to the documents folder, or the game's own folder when that is not allowed.
## Returns the path, or "" when nothing could be written.
static func write_export(text: String) -> String:
	for dir: String in [OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), OS.get_user_data_dir()]:
		if dir.is_empty():
			continue
		var path: String = dir.path_join(EXPORT_FILE)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
			return path
	return ""

static func _show_transfer(menu: MenuHost) -> void:
	var r: Dictionary = await Online.transfer_create()
	if not r.ok or not r.data is Dictionary:
		await menu.info(Online.error_text(r.error))
		return
	var c: String = str(r.data.code)
	await menu.info("Your transfer code:\n\n%s-%s-%s\n\nOn the new phone open Settings, Account, Enter a code. It works once and for 7 days. Keep it secret: anyone with it gets your journeys." % [c.left(4), c.substr(4, 4), c.substr(8)])

static func _claim_transfer(menu: MenuHost) -> bool:
	return await claim_code(menu, true)

## Enters a transfer code. [param warn]: ask first, because journeys on this phone are
## replaced (not needed on a fresh phone).
static func claim_code(menu: MenuHost, warn: bool) -> bool:
	if GameState.in_game:
		await menu.info("Enter the code on the title screen.")
		return false
	if warn and not await menu.confirm_danger("This phone will get the journeys of the other phone. Journeys saved on this phone are replaced. Continue?"):
		return false
	var code: String = await CodePrompt.ask(menu, "Transfer code", TRANSFER_CODE_LENGTH)
	if code.is_empty():
		return false
	var r: Dictionary = await Online.transfer_claim(code)
	if r.ok:
		await menu.info("Welcome back! Your journeys are here.")
		return true
	if r.error == "too_many_tries":
		await menu.info("Too many tries. Please wait an hour.")
	elif r.net:
		await menu.info(Online.error_text(r.error))
	else:
		await menu.info("That code does not work. Codes work once and for 7 days.")
	return false

## For parents (item 147): switches friends, mail and greetings off. Saves stay online.
static func _toggle_social(menu: MenuHost) -> void:
	var on: bool = not Online.social_on()
	if not on and not await menu.confirm("Switch off friends, greetings and gifts? Nobody can send you anything, and you cannot add friends. Your journeys stay online."):
		return
	if not await Online.set_social(on):
		await menu.info(Online.error_text())

static func _delete(menu: MenuHost) -> bool:
	if not await menu.confirm_danger("Delete your account? All journeys and friends are removed for good."):
		return false
	if not await menu.confirm_danger("Really delete? This cannot be undone.", "Delete", "Keep"):
		return false
	var r: Dictionary = await Online.delete_account()
	if not r.ok:
		await menu.info(Online.error_text(r.error) + "\n\n" + Loc.t("Nothing was deleted."))
		return false
	await menu.info("Your account was deleted.")
	GameState.in_game = false
	menu.get_tree().change_scene_to_file(TITLE_SCENE)
	return true
