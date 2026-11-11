#!/usr/bin/env python3
"""Live content patches (docs/LIVE_CONTENT.md).

  python3 tools/live/publish.py check live/content.json [more.json ...]   # rules only (CI)
  python3 tools/live/publish.py sign live/content.json --out signed.json  # needs the private key
  python3 tools/live/publish.py verify signed.json                        # against the game's key
  python3 tools/live/publish.py sql signed.json                           # SQL for the server

The private key comes from the LIVE_CONTENT_KEY environment variable (PEM text) or --key FILE.
It is never in the repository. The public key is read from scripts/online/LiveContent.gd, so
'verify' checks exactly what the game checks. Signature: RSA PKCS#1 v1.5 over SHA-256 of the
body bytes (Godot's Crypto.verify). Uses the openssl command line tool."""
import argparse, base64, json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLIENT = os.path.join(ROOT, "scripts/online/LiveContent.gd")
ALLOWED = {"version", "requires", "min_client", "latest", "shop", "balance", "type_chart", "events", "texts", "news"}
# Same list as LiveContent.CODE_MARKERS: patches carry data, never code (store rules).
MARKERS = [".gd", ".gdc", ".gde", ".pck", ".zip", ".so", ".dylib", ".dll", ".dex", ".jar", ".tscn", ".scn",
           ".tres", ".res", "res://", "user://", "extends ", "func "]
VERSION_RE = re.compile(r"^\d+(\.\d+){0,2}$")
MAX_BYTES = 256 * 1024


def has_code(v):
    if isinstance(v, dict):
        return any(has_code(k) or has_code(x) for k, x in v.items())
    if isinstance(v, list):
        return any(has_code(x) for x in v)
    if isinstance(v, str):
        s = v.lower()
        if s.startswith("https://") and " " not in s:
            return False
        return any(m in s for m in MARKERS)
    return False


def problems(d):
    out = []
    if not isinstance(d, dict):
        return ["top level must be an object"]
    for k in d:
        if k not in ALLOWED:
            out.append("unknown key %r (allowed: %s)" % (k, ", ".join(sorted(ALLOWED))))
    if not isinstance(d.get("version"), int) or d["version"] < 1:
        out.append("version must be a whole number >= 1")
    for field in ("min_client", "latest"):
        f = d.get(field)
        if f is None:
            continue
        if not isinstance(f, dict) or set(f) - {"ios", "android"}:
            out.append("%s must be {\"ios\": \"x.y.z\", \"android\": \"x.y.z\"} (separate per platform)" % field)
            continue
        for plat, v in f.items():
            if not isinstance(v, str) or not VERSION_RE.match(v):
                out.append("%s.%s must look like 1.2.3 (\"0\" = no minimum), got %r" % (field, plat, v))
    if "requires" in d and not (isinstance(d["requires"], str) and VERSION_RE.match(d["requires"])):
        out.append("requires must look like 1.2.3")
    for i, n in enumerate(d.get("news", []) or []):
        if not isinstance(n, dict) or not n.get("title"):
            out.append("news[%d] needs a title" % i)
        elif n.get("url") and not str(n["url"]).startswith("https://"):
            out.append("news[%d].url must start with https://" % i)
        elif isinstance(n.get("title"), dict) and "en" not in n["title"]:
            out.append("news[%d].title needs an English text" % i)
    if has_code(d):
        out.append("contains something that looks like code or a code path (refused, data only)")
    return out


def body_of(d):
    return json.dumps(d, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def public_pem():
    m = re.search(r'-----BEGIN PUBLIC KEY-----.*?-----END PUBLIC KEY-----', open(CLIENT, encoding="utf-8").read(), re.S)
    if not m:
        sys.exit("public key not found in " + CLIENT)
    return m.group(0) + "\n"


def openssl(args, data):
    r = subprocess.run(["openssl"] + args, input=data, capture_output=True)
    return r


def load(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except ValueError as e:
        sys.exit("%s: not valid JSON: %s" % (path, e))


def cmd_check(a):
    bad = False
    for p in a.files:
        errs = problems(load(p))
        if len(body_of(load(p)).encode()) > MAX_BYTES:
            errs.append("larger than %d bytes" % MAX_BYTES)
        for e in errs:
            print("%s: %s" % (p, e))
        bad = bad or bool(errs)
        if not errs:
            print("%s: OK (version %s)" % (p, load(p)["version"]))
    sys.exit(1 if bad else 0)


def cmd_sign(a):
    d = load(a.file)
    errs = problems(d)
    if errs:
        sys.exit("\n".join(errs))
    pem = open(a.key, encoding="utf-8").read() if a.key else os.environ.get("LIVE_CONTENT_KEY", "")
    if "PRIVATE KEY" not in pem:
        sys.exit("no private key: set LIVE_CONTENT_KEY or pass --key (docs/LIVE_CONTENT.md)")
    body = body_of(d)
    with tempfile.NamedTemporaryFile("w", delete=False) as kf:
        kf.write(pem)
    try:
        r = openssl(["dgst", "-sha256", "-sign", kf.name], body.encode())
    finally:
        os.unlink(kf.name)
    if r.returncode != 0:
        sys.exit("openssl: " + r.stderr.decode())
    out = {"version": d["version"], "body": body, "signature": base64.b64encode(r.stdout).decode()}
    if not verify(out):
        sys.exit("the signature does not match the game's public key (wrong private key?)")
    text = json.dumps(out, ensure_ascii=False) + "\n"
    if a.out:
        open(a.out, "w", encoding="utf-8").write(text)
        print("signed version %d -> %s" % (d["version"], a.out))
    else:
        sys.stdout.write(text)


def verify(signed):
    with tempfile.NamedTemporaryFile("w", delete=False) as pf, tempfile.NamedTemporaryFile("wb", delete=False) as sf:
        pf.write(public_pem())
        sf.write(base64.b64decode(signed["signature"]))
    try:
        r = openssl(["dgst", "-sha256", "-verify", pf.name, "-signature", sf.name], signed["body"].encode())
    finally:
        os.unlink(pf.name)
        os.unlink(sf.name)
    return r.returncode == 0


def cmd_verify(a):
    s = load(a.file)
    if not verify(s):
        sys.exit("signature INVALID")
    errs = problems(json.loads(s["body"]))
    if errs:
        sys.exit("\n".join(errs))
    print("signature OK, version %d" % s["version"])


def lit(s):
    return "'" + str(s).replace("'", "''") + "'"


def cmd_sql(a):
    s = load(a.file)
    print("select public.live_content_publish(%d, %s, %s);" % (int(s["version"]), lit(s["body"]), lit(s["signature"])))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("check"); p.add_argument("files", nargs="+"); p.set_defaults(fn=cmd_check)
    p = sub.add_parser("sign"); p.add_argument("file"); p.add_argument("--key"); p.add_argument("--out"); p.set_defaults(fn=cmd_sign)
    p = sub.add_parser("verify"); p.add_argument("file"); p.set_defaults(fn=cmd_verify)
    p = sub.add_parser("sql"); p.add_argument("file"); p.set_defaults(fn=cmd_sql)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
