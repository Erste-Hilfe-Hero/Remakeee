class_name SupabaseBackend
extends OnlineBackend
## Talks to Supabase over HTTPS: GoTrue for accounts (/auth/v1) and PostgREST for the game
## functions (/rest/v1/rpc/<name>). The anon key is public by design; every rule lives in the
## database functions (supabase/migrations), which check the signed-in user themselves.

const TIMEOUT: float = 12.0

var url: String
var anon_key: String
## HTTPRequest nodes need a parent in the scene tree.
var host: Node

func _init(p_url: String, p_anon_key: String, p_host: Node) -> void:
	url = p_url.trim_suffix("/")
	anon_key = p_anon_key
	host = p_host

func sign_in_anonymous() -> Dictionary:
	return _take_session(await _http(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}}, false))

func refresh() -> Dictionary:
	if not signed_in():
		return fail("not_signed_in")
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": session.refresh_token}, false)
	if not r.ok and not r.net:
		session = {}
	return _take_session(r)

func sign_out() -> void:
	if signed_in():
		await _http(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)
	session = {}

func call_fn(name: String, args: Dictionary = {}) -> Dictionary:
	return await _authed(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + name, args)

## Refreshes the token when it is about to expire, and once more after a 401.
func _authed(method: int, path: String, body: Dictionary) -> Dictionary:
	if not signed_in():
		return fail("not_signed_in")
	if int(session.get("expires_at", 0)) - 60 < int(Time.get_unix_time_from_system()):
		var rr: Dictionary = await refresh()
		if not rr.ok:
			return rr
	var r: Dictionary = await _http(method, path, body, true)
	if not r.ok and r.error == "401":
		var rr2: Dictionary = await refresh()
		if not rr2.ok:
			return rr2
		r = await _http(method, path, body, true)
	return r

func _take_session(r: Dictionary) -> Dictionary:
	if not r.ok or not r.data is Dictionary:
		return r
	var d: Dictionary = r.data
	var user: Dictionary = d.get("user", {}) if d.get("user") is Dictionary else {}
	session = {
		"access_token": str(d.get("access_token", "")),
		"refresh_token": str(d.get("refresh_token", "")),
		"expires_at": int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600)),
		"user_id": str(user.get("id", session.get("user_id", ""))),
	}
	return ok(session)

func _http(method: int, path: String, body: Dictionary, with_token: bool) -> Dictionary:
	if host == null or not host.is_inside_tree():
		return fail("no_host", true)
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	# On the web the browser already unpacks gzip; Godot unpacking again fails (stream_peer_gzip).
	req.accept_gzip = false
	host.add_child(req)
	var token: String = str(session.get("access_token", "")) if with_token else anon_key
	var headers: PackedStringArray = [
		"apikey: " + anon_key,
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
		"Accept: application/json",
	]
	var err: Error = req.request(url + path, headers, method, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return fail("request_failed", true)
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return fail("network", true)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if code >= 200 and code < 300:
		return ok(parsed)
	if code == 401:
		return fail("401")
	if code >= 500 or code == 0:
		return fail("server_%d" % code, true)
	var msg: String = str(code)
	if parsed is Dictionary:
		msg = str(parsed.get("message", parsed.get("msg", parsed.get("error_description", code))))
	return fail(msg)
