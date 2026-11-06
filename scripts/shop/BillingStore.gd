class_name BillingStore
extends RefCounted
## One app store behind the Billing autoload: Google Play Billing, Apple StoreKit 2, or the local
## test store. Every call is a coroutine.
##
## A receipt is a Dictionary the billing service can check:
##   {"store": "google" | "apple" | "local", "product_id", "txn", "token" (Google purchaseToken) or
##    "jws" (Apple signed transaction), "account" (the account hash the purchase was made for)}

func store_name() -> String:
	return ""

## True once the store connection is up and purchases can start.
func is_ready() -> bool:
	return false

## Store prices for [param product_ids]: {product_id: "2,99 €"}. Only these texts are shown as
## prices (item 4095), never prices from data/shop.json.
func query(_product_ids: Array[String]) -> Dictionary:
	return {}

## Starts the store's purchase sheet. Returns {"ok": true, "receipt": {...}} or
## {"ok": false, "cancelled": bool, "error": String}.
func purchase(_product_id: String, _account_token: String, _account_hash: String) -> Dictionary:
	return {"ok": false, "cancelled": false, "error": "no_store"}

## Tells the store the purchase is done (Google acknowledge/consume, Apple transaction.finish()).
## Only called after the server credited it (item 4097).
func finish(_receipt: Dictionary, _consumable: bool) -> void:
	pass

## Purchases the store has not been told are done (item 4098): an array of receipts.
func unfinished() -> Array[Dictionary]:
	return []

## Restore purchases: unlocks and the pass come back (Apple guideline 3.1.1).
func restore() -> Array[Dictionary]:
	return []
