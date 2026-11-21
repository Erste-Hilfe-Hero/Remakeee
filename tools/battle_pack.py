#!/usr/bin/env python3
"""Battle data packs (KAMPF_PLAN_1000 items 991, 992): make a key, sign a pack, check a pack.

A pack is <name>.kpack.json (data only, see scripts/core/BattlePacks.gd) and <name>.kpack.json.sig.
The game trusts only the public keys in data/battle_pack_keys.json. Keep private keys out of the
repository; the owner holds the release key.

  python3 tools/battle_pack.py keygen ~/keys/battle_release.pem      # prints the public key
  python3 tools/battle_pack.py sign my.kpack.json --key ~/keys/battle_release.pem --id release-1
  python3 tools/battle_pack.py check my.kpack.json
"""
import argparse, base64, json, subprocess, sys

TOP_KEYS = {"format", "id", "name", "author", "fields", "bosses", "battles"}
CODE_ENDINGS = (".gd", ".gdc", ".cs", ".tscn", ".scn", ".tres", ".res", ".so", ".dll", ".dylib", ".pck", ".zip")


def problems(pack):
    out = []
    if pack.get("format") != 1:
        out.append("format must be 1")
    if not pack.get("id"):
        out.append("needs an id")
    out += ["unknown key '%s' (only data tables, no code)" % k for k in pack if k not in TOP_KEYS]

    def walk(v, where):
        if isinstance(v, str):
            s = v.lower()
            if "://" in s or s.startswith(("/", "res:", "user:")) or s.endswith(CODE_ENDINGS):
                out.append("%s: no paths, links or code in a data pack" % where)
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(k, where + "/" + k)
                walk(x, where + "/" + k)
        elif isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, "%s[%d]" % (where, i))
    walk(pack, "")
    return out


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    k = sub.add_parser("keygen")
    k.add_argument("private_key")
    s = sub.add_parser("sign")
    s.add_argument("pack")
    s.add_argument("--key", required=True)
    s.add_argument("--id", required=True)
    c = sub.add_parser("check")
    c.add_argument("pack")
    a = ap.parse_args()
    if a.cmd == "keygen":
        subprocess.run(["openssl", "genrsa", "-out", a.private_key, "3072"], check=True, capture_output=True)
        print(subprocess.run(["openssl", "rsa", "-in", a.private_key, "-pubout"], check=True, capture_output=True, text=True).stdout, end="")
        return 0
    with open(a.pack, encoding="utf-8") as f:
        errs = problems(json.load(f))
    if errs:
        print("\n".join(errs))
        return 1
    if a.cmd == "sign":
        sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", a.key, a.pack], check=True, capture_output=True).stdout
        with open(a.pack + ".sig", "w", encoding="utf-8") as f:
            json.dump({"key": a.id, "sig": base64.b64encode(sig).decode()}, f)
            f.write("\n")
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
