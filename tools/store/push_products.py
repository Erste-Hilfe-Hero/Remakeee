#!/usr/bin/env python3
"""Puts the shop products from store/products.json into the Play Console (plan items 4066, 4067, 4081).

    python3 tools/store/push_products.py              # dry run: prints what it would send
    python3 tools/store/push_products.py --apply      # sends it (needs PLAY_SERVICE_ACCOUNT_JSON)
    python3 tools/store/push_products.py --check      # only checks the list (CI)

Only products with "ready": true are sent; the others wait until their offer works in the game.
- One-time products (Riftglass packs, items, unlocks, looks) go through inappproducts with a fixed
  euro price; Google derives the other countries' prices (autoConvertMissingPrices).
- The Wayfarer Pass goes through monetization.subscriptions with the base plan "monthly": the
  euro price is fixed in every euro country, the other countries get Google's converted prices
  (pricing:convertRegionPrices), and the base plan is activated.
Products that already exist are updated in place, so running it twice changes nothing.
Apple (App Store Connect, item 4068) follows with --apple.
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "server", "billing"))

PRODUCTS = os.path.join(ROOT, "store", "products.json")
PACKAGE = "de.chimora.game"
# Prices both stores accept as a euro price point: x.99 from 0,99 to 99,99 (the stricter step list of
# item 4078 is checked by tools/release_check.py once the catalog follows it).
PRICE_STEPS = {"%d.99" % n for n in range(0, 100)}
# Play listing limits.
TITLE_MAX = 55
DESC_MAX = 200
BASE_PLAN = "monthly"
# Longest grace period Play offers that fits the 16 days of item 4654.
GRACE = "P14D"
REGIONS_VERSION = "2022/02"
# Euro countries: the price stays exactly the euro price there (item 4081).
EURO_REGIONS = ["AT", "BE", "CY", "DE", "EE", "ES", "FI", "FR", "GR", "HR", "IE", "IT", "LT", "LU",
                "LV", "MT", "NL", "PT", "SI", "SK"]
LANGS = {"en-US": ("name_en", "desc_en"), "de-DE": ("name_de", "desc_de")}


def load(path=PRODUCTS):
    with open(path, encoding="utf-8") as f:
        return json.load(f)["products"]


def problems(products):
    """Everything that would make the Play Console refuse a product (empty = fine)."""
    out = []
    seen = set()
    for p in products:
        pid = p.get("product_id", "")
        if not pid.startswith(PACKAGE + "."):
            out.append("%s: product id must start with %s." % (pid, PACKAGE))
        if pid in seen:
            out.append("%s: listed twice" % pid)
        seen.add(pid)
        if p.get("google_type") not in ("onetime", "subscription"):
            out.append("%s: google_type must be onetime or subscription" % pid)
        if p.get("eur") not in PRICE_STEPS:
            out.append("%s: price %s is not one of the fixed steps" % (pid, p.get("eur")))
        for name_key, desc_key in LANGS.values():
            if not p.get(name_key) or len(p[name_key]) > TITLE_MAX:
                out.append("%s: %s empty or longer than %d" % (pid, name_key, TITLE_MAX))
            if not p.get(desc_key) or len(p[desc_key]) > DESC_MAX:
                out.append("%s: %s empty or longer than %d" % (pid, desc_key, DESC_MAX))
    return out


def micros(eur):
    whole, cents = eur.split(".")
    return str(int(whole) * 1000000 + int(cents.ljust(2, "0")) * 10000)


def money(eur):
    """Play's Money for a euro text ("4.99")."""
    whole, cents = eur.split(".")
    return {"currencyCode": "EUR", "units": whole, "nanos": int(cents.ljust(2, "0")) * 10000000}


def inapp_body(p):
    return {
        "packageName": PACKAGE,
        "sku": p["product_id"],
        "status": "active",
        "purchaseType": "managedUser",
        "defaultLanguage": "en-US",
        "defaultPrice": {"priceMicros": micros(p["eur"]), "currency": "EUR"},
        "listings": {lang: {"title": p[n], "description": p[d]} for lang, (n, d) in LANGS.items()},
    }


def subscription_body(p, converted):
    """The pass with its monthly base plan. [converted] is pricing:convertRegionPrices' answer."""
    regional = []
    for code, r in sorted(converted.get("convertedRegionPrices", {}).items()):
        price = money(p["eur"]) if code in EURO_REGIONS else r["price"]
        regional.append({"regionCode": code, "newSubscriberAvailability": True, "price": price})
    other = converted.get("convertedOtherRegionsPrice", {})
    plan = {
        "basePlanId": BASE_PLAN,
        "autoRenewingBasePlanType": {"billingPeriodDuration": "P1M", "gracePeriodDuration": GRACE,
                                     "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE"},
        "regionalConfigs": regional,
    }
    if other:
        plan["otherRegionsConfig"] = {"usdPrice": other.get("usdPrice"), "eurPrice": other.get("eurPrice"),
                                      "newSubscriberAvailability": True}
    return {
        "packageName": PACKAGE,
        "productId": p["product_id"],
        "listings": [{"languageCode": lang, "title": p[n], "description": p[d]} for lang, (n, d) in LANGS.items()],
        "basePlans": [plan],
    }


class Pusher:
    """Sends the products. [call] is (method, path, body) -> response; dry runs only record."""

    def __init__(self, call=None, log=print):
        self.call = call
        self.log = log
        self.sent = []

    def _send(self, method, path, body=None):
        self.sent.append((method, path))
        if self.call is None:
            self.log("DRY %s %s" % (method, path))
            return {}
        return self.call(method, path, body)

    def push(self, products):
        n = 0
        for p in products:
            if not p.get("ready"):
                continue
            if p["google_type"] == "onetime":
                self._send("PUT", "/inappproducts/%s?allowMissing=true&autoConvertMissingPrices=true" % p["product_id"],
                           inapp_body(p))
            else:
                self._push_subscription(p)
            n += 1
        self.log("%d products %s." % (n, "sent" if self.call else "would be sent"))
        return n

    def _push_subscription(self, p):
        converted = self._send("POST", "/pricing:convertRegionPrices", {"price": money(p["eur"])}) or {}
        body = subscription_body(p, converted)
        pid = p["product_id"]
        q = "regionsVersion.version=%s" % REGIONS_VERSION
        if self._exists(pid):
            self._send("PATCH", "/subscriptions/%s?updateMask=listings,basePlans&%s" % (pid, q), body)
        else:
            self._send("POST", "/subscriptions?productId=%s&%s" % (pid, q), body)
        self._send("POST", "/subscriptions/%s/basePlans/%s:activate" % (pid, BASE_PLAN),
                   {"packageName": PACKAGE, "productId": pid, "basePlanId": BASE_PLAN})

    def _exists(self, pid):
        if self.call is None:
            return False
        try:
            self.call("GET", "/subscriptions/%s" % pid, None)
            return True
        except Exception as e:  # GoogleError("unknown_purchase") on 404
            if "unknown" in str(e):
                return False
            raise


def play_call():
    import google  # server/billing/google.py
    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if not raw:
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON is not set.")
    play = google.Play(json.loads(raw), PACKAGE)
    return lambda method, path, body: play._call(method, path, body)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apply", action="store_true", help="send to the Play Console")
    ap.add_argument("--check", action="store_true", help="only check store/products.json")
    ap.add_argument("--apple", action="store_true", help="App Store Connect (not built yet)")
    a = ap.parse_args(argv)
    products = load()
    errs = problems(products)
    for e in errs:
        print("ERROR: " + e)
    if errs:
        return 1
    if a.check:
        print("store products OK (%d, %d ready)" % (len(products), sum(1 for p in products if p.get("ready"))))
        return 0
    if a.apple:
        print("App Store Connect is not supported yet (plan item 4068).")
        return 1
    Pusher(play_call() if a.apply else None).push(products)
    return 0


if __name__ == "__main__":
    sys.exit(main())
