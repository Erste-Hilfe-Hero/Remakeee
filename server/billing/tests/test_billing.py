"""Tests for the billing service: python3 -m unittest discover -s server/billing/tests"""
import base64
import datetime
import hashlib
import hmac
import json
import os
import sys
import threading
import time
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import apple  # noqa: E402
import billing  # noqa: E402
import google  # noqa: E402
from cryptography import x509  # noqa: E402
from cryptography.hazmat.primitives import hashes, serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import ec, rsa  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature  # noqa: E402
from cryptography.x509.oid import NameOID  # noqa: E402

UID = "20000000-0000-0000-0000-0000000000b1"
BUNDLE = "de.chimora.game"
NOW = datetime.datetime.now(datetime.timezone.utc)


def b64u(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _cert(name, key, issuer_name, issuer_key, ca, oid=None):
    b = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)]))
         .issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, issuer_name)]))
         .public_key(key.public_key()).serial_number(x509.random_serial_number())
         .not_valid_before(NOW - datetime.timedelta(days=1)).not_valid_after(NOW + datetime.timedelta(days=30))
         .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True))
    if oid:
        b = b.add_extension(x509.UnrecognizedExtension(x509.ObjectIdentifier(oid), b"\x05\x00"), critical=False)
    return b.sign(issuer_key, hashes.SHA256())


class FakeApple:
    """A test root, intermediate and leaf shaped like Apple's."""

    def __init__(self):
        self.root_key = ec.generate_private_key(ec.SECP256R1())
        self.mid_key = ec.generate_private_key(ec.SECP256R1())
        self.leaf_key = ec.generate_private_key(ec.SECP256R1())
        self.root = _cert("Test Root G3", self.root_key, "Test Root G3", self.root_key, True)
        self.mid = _cert("Test WWDR", self.mid_key, "Test Root G3", self.root_key, True, "1.2.840.113635.100.6.2.1")
        self.leaf = _cert("Test Leaf", self.leaf_key, "Test WWDR", self.mid_key, False, "1.2.840.113635.100.6.11.1")
        self.root_sha = hashlib.sha256(self.root.public_bytes(serialization.Encoding.DER)).hexdigest()

    def sign(self, payload, key=None):
        x5c = [base64.b64encode(c.public_bytes(serialization.Encoding.DER)).decode() for c in (self.leaf, self.mid, self.root)]
        head = b64u(json.dumps({"alg": "ES256", "x5c": x5c}).encode())
        body = b64u(json.dumps(payload).encode())
        der = (key or self.leaf_key).sign((head + "." + body).encode(), ec.ECDSA(hashes.SHA256()))
        r, s = decode_dss_signature(der)
        return head + "." + body + "." + b64u(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


def apple_tx(**kw):
    tx = {"bundleId": BUNDLE, "appAccountToken": UID, "productId": "de.chimora.game.glass.500",
          "transactionId": "2000001", "originalTransactionId": "2000001", "type": "Consumable",
          "environment": "Sandbox"}
    tx.update(kw)
    return tx


class FakeDb:
    def __init__(self):
        self.calls = []
        self.subs = {}

    def credit(self, uid, store, txn, product, choice=None):
        self.calls.append(("credit", uid, store, txn, product, choice))
        return {"ok": True, "purchase": len(self.calls), "balance": 500}

    def refund(self, store, txn, note=""):
        self.calls.append(("refund", store, txn, note))
        return {"ok": True}

    def sub_set(self, uid, store, original, product, expires, status, auto_renew):
        self.calls.append(("sub_set", uid, store, original, product, status, auto_renew))
        self.subs[(store, original)] = uid
        return {"ok": True}

    def sub_user(self, store, original):
        return self.subs.get((store, original))


class FakePlay:
    def __init__(self):
        self.products = {}
        self.subs = {}
        self.acks = []
        self.void = []

    def product(self, product_id, token):
        if token not in self.products:
            raise google.GoogleError("unknown_purchase")
        return self.products[token]

    def subscription(self, token):
        return self.subs[token]

    def acknowledge_product(self, product_id, token):
        self.acks.append(token)

    def acknowledge_subscription(self, product_id, token):
        self.acks.append(token)

    def voided(self, since_ms):
        return self.void


class AppleTest(unittest.TestCase):
    def setUp(self):
        self.ca = FakeApple()

    def test_good_jws(self):
        tx = apple.verify_jws(self.ca.sign(apple_tx()), self.ca.root_sha)
        self.assertEqual(apple.check_transaction(tx, BUNDLE, UID)["txn"], "2000001")

    def test_other_root_is_refused(self):
        with self.assertRaises(apple.AppleError) as e:
            apple.verify_jws(self.ca.sign(apple_tx()))
        self.assertEqual(str(e.exception), "not_apple_root")

    def test_forged_signature_is_refused(self):
        jws = self.ca.sign(apple_tx(), key=ec.generate_private_key(ec.SECP256R1()))
        with self.assertRaises(apple.AppleError):
            apple.verify_jws(jws, self.ca.root_sha)
        head, body, sig = self.ca.sign(apple_tx()).split(".")
        other = b64u(json.dumps(apple_tx(productId="de.chimora.game.glass.10000")).encode())
        with self.assertRaises(apple.AppleError):
            apple.verify_jws(head + "." + other + "." + sig, self.ca.root_sha)

    def test_wrong_account_app_product(self):
        for tx, err in ((apple_tx(appAccountToken="20000000-0000-0000-0000-0000000000ff"), "wrong_account"),
                        (apple_tx(bundleId="com.other"), "wrong_app"),
                        (apple_tx(revocationDate=1), "revoked")):
            with self.assertRaises(apple.AppleError) as e:
                apple.check_transaction(tx, BUNDLE, UID)
            self.assertEqual(str(e.exception), err)
        with self.assertRaises(apple.AppleError):
            apple.check_transaction(apple_tx(), BUNDLE, UID, "de.chimora.game.glass.10000")

    def test_pass_uses_original_transaction(self):
        exp = int((time.time() + 86400 * 30) * 1000)
        info = apple.tx_info(apple_tx(type="Auto-Renewable Subscription", transactionId="2000009",
                                      originalTransactionId="2000001", expiresDate=exp))
        self.assertEqual(info["txn"], "2000001")
        self.assertTrue(info["subscription"])


class FlowTest(unittest.TestCase):
    def setUp(self):
        self.ca = FakeApple()
        self.db = FakeDb()
        self.play = FakePlay()
        self.cfg = {"bundle_id": BUNDLE, "package": BUNDLE, "apple_root": self.ca.root_sha, "jwt_secret": "s3",
                    "push_token": "push"}
        self.app = billing.Billing(self.db, self.play, self.cfg)
        self.hash = hashlib.sha256(UID.encode()).hexdigest()

    def test_apple_credit(self):
        r = self.app.verify(UID, {"p_receipt": {"store": "apple", "jws": self.ca.sign(apple_tx()),
                                                "product_id": "de.chimora.game.glass.500"}})
        self.assertTrue(r["ok"])
        self.assertEqual(self.db.calls[0], ("credit", UID, "apple", "2000001", "de.chimora.game.glass.500", None))

    def test_apple_someone_elses_receipt(self):
        r = self.app.verify("20000000-0000-0000-0000-0000000000ff",
                            {"p_receipt": {"store": "apple", "jws": self.ca.sign(apple_tx())}})
        self.assertEqual(r, {"ok": False, "error": "wrong_account"})
        self.assertEqual(self.db.calls, [])

    def test_google_product(self):
        self.play.products["tok1"] = {"purchaseState": 0, "obfuscatedExternalAccountId": self.hash, "acknowledgementState": 0}
        r = self.app.verify(UID, {"p_receipt": {"store": "google", "token": "tok1", "product_id": "de.chimora.game.unlock.storage_box"},
                                  "p_choice": ""})
        self.assertTrue(r["ok"])
        self.assertEqual(self.db.calls[0][3], "tok1")
        self.assertEqual(self.play.acks, ["tok1"], "unlocks are acknowledged by the server")
        self.play.products["tok2"] = {"purchaseState": 0, "obfuscatedExternalAccountId": self.hash}
        self.app.verify(UID, {"p_receipt": {"store": "google", "token": "tok2", "product_id": "de.chimora.game.glass.500"}})
        self.assertEqual(self.play.acks, ["tok1"], "consumables are consumed by the app")

    def test_google_refused(self):
        self.play.products["t"] = {"purchaseState": 1, "obfuscatedExternalAccountId": self.hash}
        self.assertEqual(self.app.verify(UID, {"p_receipt": {"store": "google", "token": "t", "product_id": "x"}})["error"], "not_paid")
        self.play.products["t"] = {"purchaseState": 0, "obfuscatedExternalAccountId": "other"}
        self.assertEqual(self.app.verify(UID, {"p_receipt": {"store": "google", "token": "t", "product_id": "x"}})["error"], "wrong_account")
        self.assertEqual(self.app.verify(UID, {"p_receipt": {"store": "google", "token": "nope", "product_id": "x"}})["error"], "unknown_purchase")
        self.assertEqual(self.app.verify(UID, {"p_receipt": {"store": "local", "txn": "1"}})["error"], "bad_receipt")
        self.assertEqual(self.db.calls, [])

    def test_google_pass_and_renewal(self):
        sub = {"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE", "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
               "externalAccountIdentifiers": {"obfuscatedExternalAccountId": self.hash},
               "lineItems": [{"productId": "de.chimora.game.pass", "expiryTime": "2026-12-06T10:00:00Z",
                              "autoRenewingPlan": {"autoRenewEnabled": True}}]}
        self.play.subs["ptok"] = sub
        self.assertTrue(self.app.verify(UID, {"p_receipt": {"store": "google", "token": "ptok", "product_id": "de.chimora.game.pass"}})["ok"])
        self.assertIn(("sub_set", UID, "google", "ptok", "de.chimora.game.pass", "active", True), self.db.calls)
        self.assertEqual(self.play.acks, ["ptok"])
        sub["subscriptionState"] = "SUBSCRIPTION_STATE_EXPIRED"
        msg = {"packageName": BUNDLE, "subscriptionNotification": {"purchaseToken": "ptok", "notificationType": 13}}
        r = self.app.google_notify({"message": {"data": base64.b64encode(json.dumps(msg).encode()).decode()}})
        self.assertEqual(r, "pass")
        self.assertEqual(self.db.calls[-1][5], "expired")

    def test_google_voided(self):
        msg = {"packageName": BUNDLE, "voidedPurchaseNotification": {"purchaseToken": "tok9", "productType": 2}}
        self.assertEqual(self.app.google_notify({"message": {"data": base64.b64encode(json.dumps(msg).encode()).decode()}}), "refund")
        self.assertEqual(self.db.calls[-1], ("refund", "google", "tok9", "voided"))
        self.play.void = [{"purchaseToken": "a"}, {"purchaseToken": "b"}]
        self.assertEqual(self.app.sweep_voided(), 2)

    def test_apple_refund_and_renewal(self):
        note = {"notificationType": "REFUND", "data": {"bundleId": BUNDLE, "signedTransactionInfo": self.ca.sign(apple_tx())}}
        self.assertEqual(self.app.apple_notify({"signedPayload": self.ca.sign(note)}), "refund")
        self.assertEqual(self.db.calls[-1], ("refund", "apple", "2000001", "refund"))
        exp = int((time.time() + 86400 * 30) * 1000)
        tx = apple_tx(type="Auto-Renewable Subscription", productId="de.chimora.game.pass", expiresDate=exp)
        note = {"notificationType": "DID_RENEW", "data": {"bundleId": BUNDLE, "signedTransactionInfo": self.ca.sign(tx),
                                                          "signedRenewalInfo": self.ca.sign({"autoRenewStatus": 0})}}
        self.assertEqual(self.app.apple_notify({"signedPayload": self.ca.sign(note)}), "pass")
        self.assertEqual(self.db.calls[-1][5:], ("active", False))
        note["data"]["bundleId"] = "com.other"
        self.assertEqual(self.app.apple_notify({"signedPayload": self.ca.sign(note)}), "ignored")


def jwt(secret, **claims):
    head = b64u(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    body = b64u(json.dumps(claims).encode())
    sig = b64u(hmac.new(secret.encode(), (head + "." + body).encode(), hashlib.sha256).digest())
    return head + "." + body + "." + sig


class JwtTest(unittest.TestCase):
    def test_tokens(self):
        exp = int(time.time()) + 600
        self.assertEqual(billing.user_from_jwt(jwt("k", sub=UID, role="authenticated", exp=exp), "k"), UID)
        self.assertIsNone(billing.user_from_jwt(jwt("other", sub=UID, role="authenticated", exp=exp), "k"))
        self.assertIsNone(billing.user_from_jwt(jwt("k", sub=UID, role="anon", exp=exp), "k"))
        self.assertIsNone(billing.user_from_jwt(jwt("k", sub=UID, role="authenticated", exp=1), "k"))
        self.assertIsNone(billing.user_from_jwt("garbage", "k"))


class HttpTest(unittest.TestCase):
    def setUp(self):
        self.db = FakeDb()
        self.play = FakePlay()
        self.cfg = {"bundle_id": BUNDLE, "package": BUNDLE, "apple_root": "00", "jwt_secret": "k", "push_token": "push"}
        app = billing.Billing(self.db, self.play, self.cfg)
        self.srv = billing.ThreadingHTTPServer(("127.0.0.1", 0), billing.make_handler(app, self.cfg))
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        self.base = "http://127.0.0.1:%d" % self.srv.server_address[1]

    def tearDown(self):
        self.srv.shutdown()
        self.srv.server_close()

    def post(self, path, body, token=None):
        h = {"Content-Type": "application/json"}
        if token:
            h["Authorization"] = "Bearer " + token
        req = urllib.request.Request(self.base + path, data=json.dumps(body).encode(), headers=h, method="POST")
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")

    def test_routes(self):
        self.assertEqual(self.post("/verify", {})[0], 401, "needs a sign-in token")
        tok = jwt("k", sub=UID, role="authenticated", exp=int(time.time()) + 600)
        code, r = self.post("/verify", {"p_receipt": {"store": "google", "token": "none", "product_id": "x"}}, tok)
        self.assertEqual((code, r["error"]), (200, "unknown_purchase"))
        self.assertEqual(self.post("/google/notify?token=wrong", {})[0], 403)
        self.assertEqual(self.post("/google/notify?token=push", {"message": {}})[1], {"result": "ignored"})
        self.assertEqual(self.post("/apple/notify", {"signedPayload": "x.y.z"})[0], 400)
        with urllib.request.urlopen(self.base + "/health") as r:
            self.assertEqual(json.loads(r.read()), {"ok": True})


class GoogleTokenTest(unittest.TestCase):
    def test_service_account_token_and_calls(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption()).decode()
        seen = []

        def http(method, url, body=None, headers=None, form=False):
            seen.append((method, url, headers))
            if url.endswith("/token"):
                head, claims, sig = body["assertion"].split(".")
                key.public_key().verify(base64.urlsafe_b64decode(sig + "=="), (head + "." + claims).encode(),
                                        __import__("cryptography.hazmat.primitives.asymmetric.padding", fromlist=["x"]).PKCS1v15(),
                                        hashes.SHA256())
                return 200, {"access_token": "at", "expires_in": 3600}
            return 200, {"purchaseState": 0}

        play = google.Play({"client_email": "sa@x", "private_key": pem, "token_uri": "https://oauth2.googleapis.com/token"},
                           BUNDLE, http=http)
        self.assertEqual(play.product("de.chimora.game.glass.500", "t/1")["purchaseState"], 0)
        play.product("de.chimora.game.glass.500", "t2")
        self.assertEqual(sum(1 for s in seen if s[1].endswith("/token")), 1, "token is reused")
        self.assertIn("/applications/de.chimora.game/purchases/products/de.chimora.game.glass.500/tokens/t%2F1", seen[1][1])
        self.assertEqual(seen[1][2]["Authorization"], "Bearer at")


if __name__ == "__main__":
    unittest.main()
