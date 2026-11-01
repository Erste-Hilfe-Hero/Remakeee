class_name OnlineBackend
extends RefCounted
## The server Chimora talks to. Two implementations:
## - SupabaseBackend: the real server (our server in server/, or Supabase Cloud), used when data/online.json has a URL.
## - LocalBackend: an in-memory stand-in with the same rules, used in tests and in builds
##   without a server address (debug APKs before the server exists).
## Every call is a coroutine and returns {"ok": bool, "data": Variant, "error": String,
## "net": bool}. "net" is true when the server could not be reached at all.

## {"access_token", "refresh_token", "expires_at" (unix), "user_id"}
var session: Dictionary = {}

func is_local() -> bool:
	return false

func signed_in() -> bool:
	return not str(session.get("refresh_token", "")).is_empty()

## Creates a fresh account without email (item 2). Chimora never asks for an email: moving to
## a new phone works with a one-time transfer code (server function transfer_create/claim).
func sign_in_anonymous() -> Dictionary:
	return fail("not_implemented")

## Gets a new access token with the stored refresh token.
func refresh() -> Dictionary:
	return fail("not_implemented")

func sign_out() -> void:
	session = {}

## Calls a server function (supabase/migrations) with named arguments.
func call_fn(_name: String, _args: Dictionary = {}) -> Dictionary:
	return fail("not_implemented")

static func ok(data: Variant = null) -> Dictionary:
	return {"ok": true, "data": data, "error": "", "net": false}

static func fail(error: String, net: bool = false) -> Dictionary:
	return {"ok": false, "data": null, "error": error, "net": net}
