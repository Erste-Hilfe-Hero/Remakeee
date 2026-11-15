class_name PromoMenu
extends RefCounted
## Settings > Account > "Redeem a promo code...": the player types a code the team handed out
## (Discord, posts, events) and gets its items in the bag of the open journey. The server checks
## the code (supabase/migrations/20261115100000_promo_codes.sql).

const CODE_LENGTH: int = 8

const ERRORS: Dictionary = {
	"no_such_code": "That code does not exist. Check the letters and try again.",
	"code_used": "You already redeemed this code.",
	"code_used_up": "This code has been used up.",
	"code_expired": "This code has expired.",
	"slow_down": "Too many tries. Wait an hour, then try again.",
	"feature_off": "Promo codes are closed right now.",
	"no_save": "Save your journey first, then try again.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else TradeMenu.error_text(r)

static func run(menu: MenuHost) -> void:
	if not Online.is_online():
		await menu.info(Online.error_text())
		return
	var code: String = await CodePrompt.ask(menu, Loc.t("Promo code"), CODE_LENGTH)
	if code.is_empty():
		return
	await redeem(menu, code)

static func redeem(menu: MenuHost, code: String) -> void:
	var r: Dictionary = await TradeMenu.bag_call("promo_redeem", {"p_code": code})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("coin")
		await menu.info(Loc.t("Code redeemed! You got: %s") % TradeMenu.offer_text(r.data.get("bag", {})))
	else:
		await menu.info(error_text(r))
