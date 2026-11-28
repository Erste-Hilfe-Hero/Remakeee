class_name AppUpdate
extends RefCounted
## Which update path a build takes (docs/LIVE_CONTENT.md, "In-game updates"). Pure decisions, no
## nodes; AppUpdater.gd runs them and UpdatePanel.gd shows them.
##
## - Android from Google Play: Play's in-app update. Immediate (Google's full-screen update) when
##   Play has a newer version code and allows it, otherwise flexible (download in the background,
##   then "Restart"). Without the Play API: the store-link dialog.
## - Android itch.io build (feature "itch", not installed by Play): download the APK from
##   live content latest.android_apk with a progress bar, then the system installer.
## - iOS: the App Store page (itms-apps://). Never a binary download (App Review Guideline 2.5.2).

const PLAY_STORE: String = "com.android.vending"

## Paths.
const NONE: String = "none"
const PLAY_IMMEDIATE: String = "play_immediate"
const PLAY_FLEXIBLE: String = "play_flexible"
const PLAY_RESTART: String = "play_restart"
const APK_DOWNLOAD: String = "apk_download"
const APP_STORE: String = "app_store"
const STORE_LINK: String = "store_link"

## Play's InstallStatus values the game reacts to (com.google.android.play.core.install.model).
const STATUS_DOWNLOADING: int = 2
const STATUS_DOWNLOADED: int = 11
const STATUS_FAILED: int = 5
const STATUS_CANCELED: int = 6
## Activity results of Google's update screen.
const RESULT_OK: int = -1
const RESULT_CANCELED: int = 0

## True when Google Play installed this copy (the Play API answers only for those).
static func from_play(installer: String) -> bool:
	return installer == PLAY_STORE

## True for the itch.io build that may install an APK itself: built with the "itch" feature
## (only that preset has REQUEST_INSTALL_PACKAGES) and not installed by Google Play.
static func can_sideload(itch_build: bool, installer: String) -> bool:
	return itch_build and not from_play(installer)

## The APK link from live content (latest.android_apk), "" if none or not an https .apk link.
static func apk_url(content: Dictionary) -> String:
	var latest: Variant = content.get("latest")
	if not latest is Dictionary:
		return ""
	var u: String = str((latest as Dictionary).get("android_apk", "")).strip_edges()
	if u.begins_with("https://") and not u.contains(" ") and u.to_lower().ends_with(".apk"):
		return u
	return ""

## The update path. [param ctx] keys:
## platform ("android", "ios" or ""), state ("required", "optional" or "none", from live content
## and the server), installer (package name), itch (bool), play (the plugin's last "info" answer,
## {} if there is no Play API), apk (APK link, itch only).
static func choose(ctx: Dictionary) -> String:
	var plat: String = str(ctx.get("platform", ""))
	var state: String = str(ctx.get("state", "none"))
	var wanted: bool = state == "required" or state == "optional"
	if plat == "ios":
		return APP_STORE if wanted else NONE
	if plat != "android":
		return NONE
	var installer: String = str(ctx.get("installer", ""))
	if can_sideload(bool(ctx.get("itch", false)), installer):
		if not wanted:
			return NONE
		return APK_DOWNLOAD if not str(ctx.get("apk", "")).is_empty() else STORE_LINK
	var play: Dictionary = ctx.get("play", {}) if ctx.get("play") is Dictionary else {}
	if bool(play.get("ok", false)):
		var path: String = play_path(play)
		if path != NONE:
			return path
		# Play has nothing newer for this device yet (staged rollout): only a required update
		# still needs the store page.
		return STORE_LINK if state == "required" else NONE
	return STORE_LINK if wanted else NONE

## The Play path for an "info" answer: an update already downloaded wants a restart, one that
## Google's screen started earlier goes on, otherwise immediate before flexible.
static func play_path(play: Dictionary) -> String:
	if bool(play.get("downloaded", false)):
		return PLAY_RESTART
	if bool(play.get("in_progress", false)):
		return PLAY_IMMEDIATE
	if not bool(play.get("available", false)):
		return NONE
	if bool(play.get("immediate", false)):
		return PLAY_IMMEDIATE
	if bool(play.get("flexible", false)):
		return PLAY_FLEXIBLE
	return NONE

## The App Store page that opens straight in the App Store app.
static func app_store_url(app_id: String) -> String:
	return "itms-apps://apps.apple.com/app/id" + app_id

## 0.0 to 1.0, or -1.0 while the size is unknown.
static func progress(bytes: int, total: int) -> float:
	if total <= 0:
		return -1.0
	return clampf(float(bytes) / float(total), 0.0, 1.0)

## "12.3 / 80.0 MB" for the progress line.
static func size_text(bytes: int, total: int) -> String:
	var mb: float = 1024.0 * 1024.0
	if total <= 0:
		return "%.1f MB" % (bytes / mb)
	return "%.1f / %.1f MB" % [bytes / mb, total / mb]

## The file name of the downloaded APK for [param url] (its last path part, safe characters only).
static func apk_file_name(url: String) -> String:
	var last: String = url.get_slice("?", 0).get_file()
	var safe: String = ""
	for ch: String in last:
		safe += ch if (ch.is_valid_identifier() or ch in "-." or ch.is_valid_int()) else "_"
	return safe if safe.to_lower().ends_with(".apk") and safe.length() > 4 else "chimora-update.apk"
