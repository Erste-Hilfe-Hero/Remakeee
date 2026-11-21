"""Google Play checks (plan area 10, items 4111-4120) through the Play Developer API.

The app sends the purchaseToken; we ask Google about it with the Play service account. One-time
products: purchases.products.get. The pass: purchases.subscriptionsv2.get. Refunds come from
voidedpurchases.list and from Real-time developer notifications (Pub/Sub push).
"""
import base64
import json
import time
import urllib.error
import urllib.parse
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


class GoogleError(Exception):
    pass


def _q(s):
    """Quotes one path part; purchase tokens may hold "/" and other signs."""
    return urllib.parse.quote(str(s), safe="")


def _b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def http_json(method, url, body=None, headers=None, form=False):
    """Small HTTP helper; tests replace it."""
    data = None
    h = dict(headers or {})
    if body is not None:
        data = urllib.parse.urlencode(body).encode() if form else json.dumps(body).encode()
        h["Content-Type"] = "application/x-www-form-urlencoded" if form else "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw) if raw else {}
        except ValueError:
            return e.code, {}


class Play:
    def __init__(self, service_account, package, http=http_json, clock=time.time):
        self.sa = service_account
        self.package = package
        self.http = http
        self.clock = clock
        self._token = None
        self._token_until = 0

    def _access_token(self):
        now = int(self.clock())
        if self._token and now < self._token_until - 60:
            return self._token
        if not self.sa:
            raise GoogleError("no_service_account")
        head = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
        claims = _b64url(json.dumps({"iss": self.sa["client_email"], "scope": SCOPE,
                                     "aud": self.sa.get("token_uri", "https://oauth2.googleapis.com/token"),
                                     "iat": now, "exp": now + 3600}).encode())
        key = serialization.load_pem_private_key(self.sa["private_key"].encode(), password=None)
        sig = key.sign((head + "." + claims).encode(), padding.PKCS1v15(), hashes.SHA256())
        status, r = self.http("POST", self.sa.get("token_uri", "https://oauth2.googleapis.com/token"),
                              {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                               "assertion": head + "." + claims + "." + _b64url(sig)}, form=True)
        if status != 200 or "access_token" not in r:
            raise GoogleError("token_failed")
        self._token = r["access_token"]
        self._token_until = now + int(r.get("expires_in", 3600))
        return self._token

    def _call(self, method, path, body=None):
        status, r = self.http(method, API + _q(self.package) + path, body,
                              {"Authorization": "Bearer " + self._access_token()})
        if status == 404 or status == 410:
            raise GoogleError("unknown_purchase")
        if status >= 300:
            raise GoogleError("google_%d" % status)
        return r

    def product(self, product_id, token):
        q = _q
        return self._call("GET", "/purchases/products/%s/tokens/%s" % (q(product_id), q(token)))

    def subscription(self, token):
        return self._call("GET", "/purchases/subscriptionsv2/tokens/%s" % _q(token))

    def acknowledge_subscription(self, product_id, token):
        q = _q
        self._call("POST", "/purchases/subscriptions/%s/tokens/%s:acknowledge" % (q(product_id), q(token)), {})

    def acknowledge_product(self, product_id, token):
        q = _q
        self._call("POST", "/purchases/products/%s/tokens/%s:acknowledge" % (q(product_id), q(token)), {})

    def voided(self, since_ms):
        """Refunded or charged-back purchases since [since_ms], products and passes (type=1)."""
        out, page = [], None
        while True:
            path = "/purchases/voidedpurchases?type=1&maxResults=1000&startTime=%d" % since_ms
            if page:
                path += "&token=" + _q(page)
            r = self._call("GET", path)
            out.extend(r.get("voidedPurchases", []))
            page = (r.get("tokenPagination") or {}).get("nextPageToken")
            if not page:
                return out


def check_product(p, account_hash):
    """purchases.products resource -> problem or None. purchaseState 0 = bought."""
    if int(p.get("purchaseState", -1)) != 0:
        return "not_paid"
    # Billing.gd buys with obfuscatedAccountId = sha256(account id).
    if p.get("obfuscatedExternalAccountId", "") != account_hash:
        return "wrong_account"
    return None


SUB_STATES = {"SUBSCRIPTION_STATE_ACTIVE": "active", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace",
              "SUBSCRIPTION_STATE_ON_HOLD": "billing_retry", "SUBSCRIPTION_STATE_PAUSED": "expired",
              "SUBSCRIPTION_STATE_CANCELED": "active", "SUBSCRIPTION_STATE_EXPIRED": "expired",
              "SUBSCRIPTION_STATE_PENDING": "billing_retry"}


def sub_info(s):
    """purchases.subscriptionsv2 resource -> what the server needs."""
    items = s.get("lineItems") or [{}]
    item = items[0]
    expiry = item.get("expiryTime", "")
    auto = bool((item.get("autoRenewingPlan") or {}).get("autoRenewEnabled", False))
    state = s.get("subscriptionState", "")
    status = SUB_STATES.get(state, "expired")
    if state == "SUBSCRIPTION_STATE_CANCELED":
        auto = False
    return {"product_id": item.get("productId", ""), "expires": expiry, "status": status, "auto_renew": auto,
            "account": (s.get("externalAccountIdentifiers") or {}).get("obfuscatedExternalAccountId", ""),
            "acknowledged": s.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
            "pending": state == "SUBSCRIPTION_STATE_PENDING"}
