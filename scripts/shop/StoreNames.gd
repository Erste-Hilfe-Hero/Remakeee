class_name StoreNames
extends RefCounted
## Store names in player text: each build names only its own store (App Store guideline 2.3.10,
## Play policy). iOS says App Store, Android says Google Play, the browser and desktop builds name
## no store. Returns the English key; callers translate it as before (Loc.t or the menu).

const IOS: String = "ios"
const ANDROID: String = "android"
const OTHER: String = "other"

const CANCEL: Dictionary = {
	IOS: "Cancel any time in the App Store.",
	ANDROID: "Cancel any time in Google Play.",
	OTHER: "Cancel any time in the store you bought it in.",
}
const BUY_AGAIN: Dictionary = {
	IOS: "With Riftglass you can buy it again; in the App Store only once.",
	ANDROID: "With Riftglass you can buy it again; in Google Play only once.",
	OTHER: "With Riftglass you can buy it again; in the store only once.",
}
const NO_STORE: Dictionary = {
	IOS: "Purchases are only possible in the app from the App Store.",
	ANDROID: "Purchases are only possible in the app from Google Play.",
	OTHER: "Purchases are only possible in the phone app.",
}
const DELETE_NOTE: Dictionary = {
	IOS: "Remaining Riftglass and everything bought in the shop are lost for good. Deleting does not cancel a Wayfarer Pass: cancel it first in the App Store (Subscriptions).",
	ANDROID: "Remaining Riftglass and everything bought in the shop are lost for good. Deleting does not cancel a Wayfarer Pass: cancel it first in Google Play (Subscriptions).",
	OTHER: "Remaining Riftglass and everything bought in the shop are lost for good. Deleting does not cancel a Wayfarer Pass: cancel it first in the store you bought it in (Subscriptions).",
}
const ALL: Array[Dictionary] = [CANCEL, BUY_AGAIN, NO_STORE, DELETE_NOTE]

## The platform of this build: IOS, ANDROID or OTHER.
static func platform() -> String:
	match OS.get_name():
		"iOS":
			return IOS
		"Android":
			return ANDROID
	return OTHER

## The text of [param texts] (one of the tables above) for [param p], or for this build when empty.
static func pick(texts: Dictionary, p: String = "") -> String:
	return str(texts.get(p if not p.is_empty() else platform(), texts[OTHER]))
