class_name OnlineErrors
extends RefCounted
## One short sentence and the next step for each kind of online problem (plan item 2146), so
## menus stop saying "No connection right now." for everything.

const NO_INTERNET: String = "Your phone has no internet. Switch on Wi-Fi or mobile data, then try again."
const UNREACHABLE: String = "The Chimora server cannot be reached. Try again in a few minutes."
const MAINTENANCE: String = "The server is being looked after. Please try again a little later."
const TIMEOUT: String = "The server took too long to answer. Try again."
const SIGNED_OUT: String = "Your sign-in ran out. Go back to the title to sign in again."
const TOO_MANY: String = "That was a lot at once. Please wait a little, then try again."
const GENERIC: String = "No connection right now. Check your internet and try again."
## This account was opened on another device (plan item 3010).
const OTHER_DEVICE: String = "Signed in on another device. Your journey is saved there."

## Every sentence error_text can return (tests check each has a German text).
const ALL: Array[String] = [NO_INTERNET, UNREACHABLE, MAINTENANCE, TIMEOUT, SIGNED_OUT, TOO_MANY, GENERIC, OTHER_DEVICE]

## Kind of problem for an error code from OnlineBackend.
static func kind(code: String) -> String:
	match code:
		"no_internet":
			return "no_internet"
		"unreachable", "no_host":
			return "unreachable"
		"server_503", "maintenance":
			return "maintenance"
		"timeout":
			return "timeout"
		"401", "not_signed_in", "session_expired":
			return "signed_out"
		"slow_down", "too_many_tries", "server_429", "429":
			return "too_many"
		"other_device":
			return "other_device"
	if code.begins_with("server_"):
		return "unreachable"
	return "generic"

static func text(code: String) -> String:
	match kind(code):
		"no_internet": return NO_INTERNET
		"unreachable": return UNREACHABLE
		"maintenance": return MAINTENANCE
		"timeout": return TIMEOUT
		"signed_out": return SIGNED_OUT
		"too_many": return TOO_MANY
		"other_device": return OTHER_DEVICE
	return GENERIC

## Error code for a failed HTTPRequest result (SupabaseBackend).
static func code_for_result(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "no_internet"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "unreachable"
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
	return "network"
