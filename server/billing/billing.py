"""Chimora billing service (plan area 10, items 4101-4140).

Checks Apple and Google purchases and credits them on the database, then the app finishes the
purchase in the store (Billing.gd: "server first, store second"). Behind Caddy at /billing/v1/:

  POST /verify          the app, with its sign-in token: {"p_store", "p_receipt", "p_choice"}
  POST /apple/notify    App Store Server Notifications V2 ({"signedPayload"})
  POST /google/notify   Play Real-time developer notifications (Pub/Sub push, ?token=...)
  GET  /health

It talks to the database as chimora_billing, which may only run the _billing_* functions
(supabase/migrations/20261110000022_billing.sql). It keeps no data of its own and logs no
account ids. Stdlib plus the cryptography package.
"""
import base64
import hashlib
import hmac
import json
import logging
import os
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apple  # noqa: E402
import google  # noqa: E402

log = logging.getLogger("billing")
MAX_BODY = 64 * 1024


def _b64url(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def user_from_jwt(token, secret, now=None):
    """The account id (sub) of a valid sign-in token from the auth service (HS256), or None."""
    try:
        head_b64, body_b64, sig_b64 = token.split(".")
        head = json.loads(_b64url(head_b64))
        if head.get("alg") != "HS256":
            return None
        want = hmac.new(secret.encode(), (head_b64 + "." + body_b64).encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(want, _b64url(sig_b64)):
            return None
        claims = json.loads(_b64url(body_b64))
    except Exception:
        return None
    if claims.get("role") != "authenticated" or int(claims.get("exp", 0)) < int(now or time.time()):
        return None
    sub = str(claims.get("sub", ""))
    return sub if len(sub) == 36 else None


class Db:
    """Calls the _billing_* functions through psql (PGHOST, PGUSER, PGPASSWORD from the environment)."""

    def call(self, fn, args):
        # psql quotes every :'name' value itself, so receipt data never becomes SQL.
        names = ", ".join(":'%s'%s" % (k, cast) if v is not None else "null" for k, v, cast in args)
        cmd = ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1"]
        for k, v, _ in args:
            if v is not None:
                cmd += ["-v", "%s=%s" % (k, v)]
        sql = "select public.%s(%s)::text;\n" % (fn, names)
        r = subprocess.run(cmd, input=sql, capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            raise RuntimeError("database: " + r.stderr.strip()[:200])
        out = r.stdout.strip()
        return json.loads(out) if out.startswith("{") else (out or None)

    def credit(self, uid, store, txn, product, choice=None):
        return self.call("_billing_credit", [("uid", uid, "::uuid"), ("store", store, ""), ("txn", txn, ""),
                                             ("product", product, ""), ("choice", choice, "")])

    def refund(self, store, txn, note=""):
        return self.call("_billing_refund", [("store", store, ""), ("txn", txn, ""), ("note", note, "")])

    def sub_set(self, uid, store, original, product, expires, status, auto_renew):
        return self.call("_billing_sub_set", [("uid", uid, "::uuid"), ("store", store, ""), ("orig", original, ""),
                                              ("product", product, ""), ("expires", expires, "::timestamptz"),
                                              ("status", status, ""), ("auto", "true" if auto_renew else "false", "::boolean")])

    def sub_user(self, store, original):
        return self.call("_billing_sub_user", [("store", store, ""), ("orig", original, "")])


def is_subscription(product_id):
    return product_id.endswith(".pass") or ".sub." in product_id


class Billing:
    # Item 4148: at most 20 receipt checks per account and hour (kept in memory, one process).
    CHECKS_PER_HOUR = 20

    def __init__(self, db, play, cfg, clock=time.time):
        self.db = db
        self.play = play
        self.cfg = cfg
        self.clock = clock
        self._checks = {}

    def _too_many_checks(self, uid):
        now = self.clock()
        recent = [t for t in self._checks.get(uid, []) if t > now - 3600]
        if len(recent) >= self.CHECKS_PER_HOUR:
            self._checks[uid] = recent
            return True
        recent.append(now)
        self._checks[uid] = recent
        return False

    # --- The app ---------------------------------------------------------------------------------

    def verify(self, uid, body):
        receipt = body.get("p_receipt") if isinstance(body.get("p_receipt"), dict) else {}
        choice = body.get("p_choice")
        choice = str(choice) if choice not in (None, "") else None
        store = str(receipt.get("store", body.get("p_store", "")))
        if self._too_many_checks(uid):
            return {"ok": False, "error": "slow_down"}
        try:
            if store == "apple":
                return self._verify_apple(uid, receipt, choice)
            if store == "google":
                return self._verify_google(uid, receipt, choice)
        except (apple.AppleError, google.GoogleError) as e:
            return {"ok": False, "error": str(e)}
        return {"ok": False, "error": "bad_receipt"}

    def _verify_apple(self, uid, receipt, choice):
        tx = apple.verify_jws(str(receipt.get("jws", "")), self.cfg["apple_root"])
        info = apple.check_transaction(tx, self.cfg["bundle_id"], uid, receipt.get("product_id"))
        r = self.db.credit(uid, "apple", info["txn"], info["product_id"], choice)
        if r.get("ok") and info["subscription"] and info["expires"]:
            self.db.sub_set(uid, "apple", info["original_txn"], info["product_id"], info["expires"].isoformat(),
                            "active", True)
        return r

    def _verify_google(self, uid, receipt, choice):
        token = str(receipt.get("token", ""))
        product = str(receipt.get("product_id", ""))
        if not token or not product:
            return {"ok": False, "error": "bad_receipt"}
        account = hashlib.sha256(uid.encode()).hexdigest()
        if is_subscription(product):
            s = google.sub_info(self.play.subscription(token))
            if s["pending"]:
                return {"ok": False, "error": "pending"}
            if s["account"] != account:
                return {"ok": False, "error": "wrong_account"}
            r = self.db.credit(uid, "google", token, product, choice)
            if r.get("ok"):
                self.db.sub_set(uid, "google", token, product, s["expires"], s["status"], s["auto_renew"])
                if not s["acknowledged"]:
                    self.play.acknowledge_subscription(product, token)
            return r
        p = self.play.product(product, token)
        problem = google.check_product(p, account)
        if problem:
            return {"ok": False, "error": problem}
        r = self.db.credit(uid, "google", token, product, choice)
        # Consumables are consumed by the app (that also acknowledges); unlocks stay, so the
        # server acknowledges them, or Google refunds them after 3 days.
        if r.get("ok") and ".unlock." in product and int(p.get("acknowledgementState", 0)) == 0:
            self.play.acknowledge_product(product, token)
        return r

    # --- Store messages --------------------------------------------------------------------------

    def apple_notify(self, body):
        root = self.cfg["apple_root"]
        note = apple.verify_jws(str(body.get("signedPayload", "")), root)
        kind = note.get("notificationType", "")
        data = note.get("data") or {}
        if data.get("bundleId") != self.cfg["bundle_id"] or not data.get("signedTransactionInfo"):
            return "ignored"
        tx = apple.verify_jws(data["signedTransactionInfo"], root)
        info = apple.tx_info(tx)
        if kind in apple.REFUND_TYPES:
            self.db.refund("apple", info["txn"], kind.lower())
            return "refund"
        if kind in apple.SUB_TYPES and info["subscription"] and info["expires"]:
            uid = info["account"] or self.db.sub_user("apple", info["original_txn"])
            if not uid:
                return "unknown_account"
            auto = True
            if data.get("signedRenewalInfo"):
                auto = int(apple.verify_jws(data["signedRenewalInfo"], root).get("autoRenewStatus", 1)) == 1
            self.db.sub_set(uid, "apple", info["original_txn"], info["product_id"], info["expires"].isoformat(),
                            apple.sub_status(kind, note.get("subtype", "")), auto)
            return "pass"
        return "ignored"

    def google_notify(self, body):
        msg = body.get("message") or {}
        try:
            n = json.loads(base64.b64decode(msg.get("data", "")))
        except Exception:
            return "ignored"
        if n.get("packageName") != self.cfg["package"]:
            return "ignored"
        if n.get("voidedPurchaseNotification"):
            self.db.refund("google", str(n["voidedPurchaseNotification"].get("purchaseToken", "")), "voided")
            return "refund"
        sub = n.get("subscriptionNotification")
        if sub:
            token = str(sub.get("purchaseToken", ""))
            uid = self.db.sub_user("google", token)
            if not uid:
                # Not verified yet: the app sends it on its next start (Billing.resume_pending).
                return "unknown_account"
            s = google.sub_info(self.play.subscription(token))
            self.db.sub_set(uid, "google", token, s["product_id"], s["expires"], s["status"], s["auto_renew"])
            return "pass"
        return "ignored"

    def sweep_voided(self, days=3):
        """Refunds Google reports without a notification (item 4136): runs every hour."""
        n = 0
        for v in self.play.voided(int((time.time() - days * 86400) * 1000)):
            r = self.db.refund("google", str(v.get("purchaseToken", "")), "voided")
            if isinstance(r, dict) and r.get("ok") and not r.get("duplicate"):
                n += 1
        return n


def make_handler(app, cfg):
    class Handler(BaseHTTPRequestHandler):
        server_version = "chimora-billing"
        sys_version = ""

        def log_message(self, fmt, *args):
            log.info("%s %s", self.command, urllib.parse.urlsplit(self.path).path)

        def _send(self, code, obj=None):
            raw = json.dumps(obj if obj is not None else {}).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self):
            if urllib.parse.urlsplit(self.path).path == "/health":
                return self._send(200, {"ok": True})
            self._send(404)

        def do_POST(self):
            url = urllib.parse.urlsplit(self.path)
            n = int(self.headers.get("Content-Length") or 0)
            if n > MAX_BODY:
                return self._send(413)
            try:
                body = json.loads(self.rfile.read(n) or b"{}")
                if not isinstance(body, dict):
                    raise ValueError
            except ValueError:
                return self._send(400, {"ok": False, "error": "bad_json"})
            try:
                if url.path == "/verify":
                    auth = self.headers.get("Authorization", "")
                    uid = user_from_jwt(auth[7:], cfg["jwt_secret"]) if auth.startswith("Bearer ") else None
                    if not uid:
                        return self._send(401, {"ok": False, "error": "not_signed_in"})
                    return self._send(200, app.verify(uid, body))
                if url.path == "/apple/notify":
                    return self._send(200, {"result": app.apple_notify(body)})
                if url.path == "/google/notify":
                    token = urllib.parse.parse_qs(url.query).get("token", [""])[0]
                    if not cfg["push_token"] or not hmac.compare_digest(token, cfg["push_token"]):
                        return self._send(403)
                    return self._send(200, {"result": app.google_notify(body)})
            except apple.AppleError as e:
                return self._send(400, {"ok": False, "error": str(e)})
            except Exception as e:  # database or Google down: the store sends it again later
                log.warning("failed: %s", e)
                return self._send(503, {"ok": False, "error": "try_later"})
            self._send(404)

    return Handler


def config_from_env(env=os.environ):
    sa = None
    path = env.get("GOOGLE_SA_FILE", "/run/secrets/google_sa.json")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        with open(path, encoding="utf-8") as f:
            sa = json.load(f)
    return {"jwt_secret": env.get("JWT_SECRET", ""), "bundle_id": env.get("APPLE_BUNDLE_ID", "de.chimora.game"),
            "package": env.get("GOOGLE_PACKAGE", "de.chimora.game"), "push_token": env.get("GOOGLE_PUSH_TOKEN", ""),
            "apple_root": env.get("APPLE_ROOT_SHA256", apple.APPLE_ROOT_G3_SHA256), "google_sa": sa}


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    cfg = config_from_env()
    if not cfg["jwt_secret"]:
        sys.exit("JWT_SECRET is missing")
    play = google.Play(cfg["google_sa"], cfg["package"])
    app = Billing(Db(), play, cfg)

    def sweeper():
        while True:
            time.sleep(3600)
            if cfg["google_sa"]:
                try:
                    log.info("voided purchases taken back: %d", app.sweep_voided())
                except Exception as e:
                    log.warning("voided sweep failed: %s", e)

    threading.Thread(target=sweeper, daemon=True).start()
    if not cfg["google_sa"]:
        log.warning("no Google service account: Play purchases stay open until it is set")
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), make_handler(app, cfg)).serve_forever()


if __name__ == "__main__":
    main()
