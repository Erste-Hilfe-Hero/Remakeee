"""Apple StoreKit 2 checks (plan area 10, items 4101-4110).

The app sends the signed transaction (JWS) that StoreKit 2 gives it. We check it here without
calling Apple: the JWS carries its certificate chain (x5c), which must end in Apple Root CA - G3,
and the leaf certificate signs the payload with ES256. Apple's server notifications V2 use the same
format. See https://developer.apple.com/documentation/appstoreserverapi/jwstransaction
"""
import base64
import datetime
import hashlib
import json

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature
from cryptography.hazmat.primitives.serialization import Encoding

# SHA-256 of Apple Root CA - G3 (https://www.apple.com/certificateauthority/). Can be replaced
# with APPLE_ROOT_SHA256 in the environment (tests use their own root).
APPLE_ROOT_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"
# Marker extensions Apple puts in the leaf (Mac App Store receipt signing) and in the WWDR G6
# intermediate certificate.
OID_LEAF = x509.ObjectIdentifier("1.2.840.113635.100.6.11.1")
OID_INTERMEDIATE = x509.ObjectIdentifier("1.2.840.113635.100.6.2.1")


class AppleError(Exception):
    pass


def _b64url(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def _has_ext(cert, oid):
    try:
        cert.extensions.get_extension_for_oid(oid)
        return True
    except x509.ExtensionNotFound:
        return False


def _check_signed_by(cert, issuer):
    if cert.issuer != issuer.subject:
        raise AppleError("chain_order")
    key = issuer.public_key()
    if not isinstance(key, ec.EllipticCurvePublicKey):
        raise AppleError("chain_key")
    try:
        key.verify(cert.signature, cert.tbs_certificate_bytes, ec.ECDSA(cert.signature_hash_algorithm))
    except InvalidSignature:
        raise AppleError("chain_signature")


def verify_jws(jws, root_sha256=APPLE_ROOT_G3_SHA256, now=None, check_oids=True):
    """Returns the payload of an Apple-signed JWS, or raises AppleError."""
    try:
        head_b64, body_b64, sig_b64 = jws.split(".")
        head = json.loads(_b64url(head_b64))
        chain = [x509.load_der_x509_certificate(base64.b64decode(c)) for c in head.get("x5c", [])]
    except Exception:
        raise AppleError("bad_jws")
    if head.get("alg") != "ES256" or len(chain) != 3:
        raise AppleError("bad_jws")
    leaf, mid, root = chain
    if hashlib.sha256(root.public_bytes(Encoding.DER)).hexdigest() != root_sha256.lower():
        raise AppleError("not_apple_root")
    _check_signed_by(root, root)
    _check_signed_by(mid, root)
    _check_signed_by(leaf, mid)
    if check_oids and not (_has_ext(leaf, OID_LEAF) and _has_ext(mid, OID_INTERMEDIATE)):
        raise AppleError("not_apple_leaf")
    when = now or datetime.datetime.now(datetime.timezone.utc)
    for c in chain:
        if not (c.not_valid_before_utc <= when <= c.not_valid_after_utc):
            raise AppleError("cert_expired")
    sig = _b64url(sig_b64)
    if len(sig) != 64:
        raise AppleError("bad_signature")
    der = encode_dss_signature(int.from_bytes(sig[:32], "big"), int.from_bytes(sig[32:], "big"))
    try:
        leaf.public_key().verify(der, (head_b64 + "." + body_b64).encode(), ec.ECDSA(hashes.SHA256()))
    except InvalidSignature:
        raise AppleError("bad_signature")
    try:
        return json.loads(_b64url(body_b64))
    except Exception:
        raise AppleError("bad_jws")


def check_transaction(tx, bundle_id, uid, product_id=None):
    """Checks a decoded JWSTransaction for this app and account. Returns what the server needs."""
    if tx.get("bundleId") != bundle_id:
        raise AppleError("wrong_app")
    # Billing.gd buys with appAccountToken = the player's account id (a UUID).
    if str(tx.get("appAccountToken", "")).lower() != str(uid).lower():
        raise AppleError("wrong_account")
    if product_id is not None and tx.get("productId") != product_id:
        raise AppleError("wrong_product")
    if tx.get("revocationDate"):
        raise AppleError("revoked")
    return tx_info(tx)


def tx_info(tx):
    sub = tx.get("type") == "Auto-Renewable Subscription"
    # A pass is one purchase for its whole life: renewals only move the end date.
    txn = str(tx.get("originalTransactionId") if sub else tx.get("transactionId", ""))
    expires = tx.get("expiresDate")
    return {"txn": txn, "product_id": tx.get("productId", ""), "subscription": sub,
            "original_txn": str(tx.get("originalTransactionId", "")),
            "expires": datetime.datetime.fromtimestamp(expires / 1000, datetime.timezone.utc) if expires else None,
            "account": str(tx.get("appAccountToken", "")), "environment": tx.get("environment", "")}


# Notification types that take a purchase back, and those that change a pass.
REFUND_TYPES = {"REFUND", "REVOKE"}
SUB_TYPES = {"SUBSCRIBED", "DID_RENEW", "DID_CHANGE_RENEWAL_STATUS", "DID_FAIL_TO_RENEW", "EXPIRED",
             "GRACE_PERIOD_EXPIRED", "RENEWAL_EXTENDED"}


def sub_status(notification_type, subtype):
    if notification_type in ("EXPIRED", "GRACE_PERIOD_EXPIRED"):
        return "expired"
    if notification_type == "DID_FAIL_TO_RENEW":
        return "grace" if subtype == "GRACE_PERIOD" else "billing_retry"
    return "active"
