class_name DeepLink
extends RefCounted
## Deep links (chimora://): App Store In-App Events and later share links open the game.
## chimora://event/<id> opens the Goals screen, chimora://friend/<code> the invite of that friend code
## (Online 100 point 55); any other chimora:// link just opens the game.
## Android hands the link over as the activity's intent data (intent filter from
## addons/chimora_deeplink), iOS through the ChimoraStoreKit extension (take_url, URL type in
## export_presets.cfg). The overworld polls on start and on resume and opens the screen once the
## player is free (Overworld._process).

const SCHEME: String = "chimora"
const ID_MAX: int = 64
const ID_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."

## The screen waiting for the overworld: "" (none), "event" or "friend".
static var route: String = ""
## The event id of the last chimora://event/<id> link.
static var event_id: String = ""
## The friend code of the last chimora://friend/<code> link.
static var friend_code: String = ""
## Android: intent hash and data of the link handled last, so a resume does not open it again.
static var _last_android: String = ""

## {"route": "event", "id": id} for chimora://event/<id>, {"route": "open"} for any other
## chimora:// link, {} for a link of another scheme.
static func parse(url: String) -> Dictionary:
	var u: String = url.strip_edges()
	var colon: int = u.find(":")
	if colon <= 0 or u.substr(0, colon).to_lower() != SCHEME:
		return {}
	var rest: String = u.substr(colon + 1)
	for cut: String in ["?", "#"]:
		var at: int = rest.find(cut)
		if at >= 0:
			rest = rest.substr(0, at)
	var parts: PackedStringArray = rest.split("/", false)
	if parts.size() == 2 and parts[0].to_lower() == "event":
		var id: String = parts[1].uri_decode()
		if valid_id(id):
			return {"route": "event", "id": id}
	if parts.size() == 2 and parts[0].to_lower() == "friend":
		var code: String = parts[1].uri_decode().strip_edges().to_upper().replace("-", "")
		if code.length() == 8 and valid_id(code):
			return {"route": "friend", "code": code}
	return {"route": "open"}

static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > ID_MAX:
		return false
	for c: String in id:
		if not ID_CHARS.contains(c):
			return false
	return true

## Remembers what [param url] asks for; true when it was a chimora:// link.
static func handle(url: String) -> bool:
	var r: Dictionary = parse(url)
	if r.is_empty():
		return false
	print("DeepLink: %s -> %s" % [url, r.route])
	if r.route == "event":
		route = "event"
		event_id = str(r.id)
	elif r.route == "friend":
		route = "friend"
		friend_code = str(r.code)
	return true

## Takes the waiting screen ("" when none).
static func take() -> String:
	var r: String = route
	route = ""
	return r

## Reads a link the platform handed over since the last poll.
static func poll() -> void:
	var url: String = _platform_url()
	if not url.is_empty():
		handle(url)

static func _platform_url() -> String:
	if Engine.has_singleton("ChimoraStoreKit"):
		var kit: Object = Engine.get_singleton("ChimoraStoreKit")
		return str(kit.call("take_url")) if kit.has_method("take_url") else ""
	if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime"):
		return android_url(Engine.get_singleton("AndroidRuntime"))
	return ""

## The data of the activity's current intent (a new link replaces it, GodotActivity.onNewIntent),
## or "" when it has none or was handled already.
static func android_url(runtime: Object) -> String:
	var activity: Variant = runtime.call("getActivity")
	if not activity is Object:
		return ""
	var intent: Variant = (activity as Object).call("getIntent")
	if not intent is Object:
		return ""
	var data: Variant = (intent as Object).call("getDataString")
	if data == null or str(data).is_empty():
		return ""
	var key: String = "%s|%s" % [str((intent as Object).call("hashCode")), str(data)]
	if key == _last_android:
		return ""
	_last_android = key
	return str(data)
