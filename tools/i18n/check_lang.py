#!/usr/bin/env python3
"""Checks the translated tables in data/i18n/<code>/ for every language besides German.

German is the reference: its tables (built from tools/i18n/de_*.py) list every English key the game
translates. The other languages are kept by hand as data/i18n/<code>/<table>.json in the same format
({"_comment", "strings"}), one file per German table.

Checked (errors):
- every file parses and has a "strings" object of text -> text,
- placeholders survive: %s, %d and %% in the same number (or {0}, {1}... for each value when the
  order changes), {name} as often as in the English key,
- no empty translation.
Reported (no error, because other threads add German texts every day): keys that still lack a
translation, and keys whose English text is gone.

Usage: python3 tools/i18n/check_lang.py [code ...] [--missing] [--json] [--strict]
  --strict   missing keys are errors too (CI uses this)
  --missing  lists the missing keys per table (with the German text as a hint)
  --json     prints the missing keys as {table: {english: german}} for a translator
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
I18N = os.path.join(ROOT, "data/i18n")
# Same list as Loc.LANGUAGES without English and German.
LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]

def german():
    tables = {}
    d = os.path.join(I18N, "de")
    for f in sorted(os.listdir(d)):
        if f.endswith(".json"):
            tables[f[:-5]] = json.load(open(os.path.join(d, f), encoding="utf-8"))["strings"]
    return tables

def values(key):
    return re.findall(r"%[sd]", key)

def problems(key, out):
    errs = []
    if not isinstance(out, str) or not out.strip():
        return ["empty translation"]
    n = len(values(key))
    if "{0}" in out:
        for i in range(n):
            if "{%d}" % i not in out:
                errs.append("{%d} missing" % i)
        if re.search(r"%[sd]", out):
            errs.append("mixes {0} with %s/%d")
    else:
        for ph in ("%s", "%d"):
            if out.count(ph) != key.count(ph):
                errs.append("%s count %d, English has %d" % (ph, out.count(ph), key.count(ph)))
        if n and out.count("%%") != key.count("%%"):
            errs.append("%%%% count %d, English has %d" % (out.count("%%"), key.count("%%")))
    if out.count("{name}") != key.count("{name}"):
        errs.append("{name} count %d, English has %d" % (out.count("{name}"), key.count("{name}")))
    return errs

def check(code, de, show_missing=False):
    d = os.path.join(I18N, code)
    errors, missing, stale, have = [], {}, 0, 0
    tables = {}
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        if not f.endswith(".json"):
            continue
        try:
            data = json.load(open(os.path.join(d, f), encoding="utf-8"))
        except ValueError as e:
            errors.append("%s/%s: %s" % (code, f, e))
            continue
        if not isinstance(data.get("strings"), dict):
            errors.append("%s/%s: no \"strings\" object" % (code, f))
            continue
        tables[f[:-5]] = data["strings"]
        for k, v in data["strings"].items():
            for e in problems(k, v):
                errors.append("%s/%s: %r: %s" % (code, f, k, e))
    known = {}
    for t in tables.values():
        known.update(t)
    all_de = {}
    for t, strings in de.items():
        all_de.update(strings)
        miss = {k: v for k, v in strings.items() if k not in known}
        if miss:
            missing[t] = miss
    stale = sum(1 for k in known if k not in all_de)
    have = sum(1 for k in all_de if k in known)
    return errors, missing, stale, have, len(all_de)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    codes = args or LANGS
    de = german()
    failed = False
    report = {}
    for code in codes:
        errors, missing, stale, have, total = check(code, de)
        failed |= bool(errors)
        if "--strict" in sys.argv and total - have:
            failed = True
            print("ERROR %s: %d keys missing (run with --missing to list them)" % (code, total - have))
        for e in errors:
            print("ERROR " + e)
        report[code] = missing
        if "--json" not in sys.argv:
            print("%-6s %4d/%d translated (%.1f%%), %d missing, %d no longer used" % (
                code, have, total, 100.0 * have / max(1, total), total - have, stale))
            if "--missing" in sys.argv:
                for t, m in missing.items():
                    for k, v in m.items():
                        print("  [%s] %s  =>  %s" % (t, k, v))
    if "--json" in sys.argv:
        print(json.dumps(report if len(codes) > 1 else report[codes[0]], ensure_ascii=False, indent=1))
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()
