#!/usr/bin/env python3
"""Writes the German text tables in tools/i18n/de_*.py to data/i18n/de/<table>.json, one file
per table, so threads that add texts in different tables never touch the same generated file.
Run after editing a table: python3 tools/i18n/build.py
--check: fails if a generated file is missing, stale or left over (CI runs this)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glob, importlib
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "data/i18n/de")
# Every tools/i18n/de_*.py table is written, so new areas only add a file (no edit here).
names = [os.path.basename(p)[3:-3] for p in sorted(glob.glob(os.path.join(HERE, "de_*.py")))]
MODS = {n: importlib.import_module("de_" + n) for n in names}

seen = {}
files = {}
for n, mod in MODS.items():
    for k, v in mod.T.items():
        if k in seen and seen[k][1] != v:
            sys.exit("conflicting German text for %r (de_%s.py and de_%s.py)" % (k, seen[k][0], n))
        seen[k] = (n, v)
    data = {"_comment": "German texts from tools/i18n/de_%s.py. Keys are the English text; keys with %%s or %%d are "
            "patterns. Built by tools/i18n/build.py; Loc.gd merges every file in this folder." % n,
            "keep": sorted(set(getattr(mod, "KEEP", []))), "strings": dict(sorted(mod.T.items()))}
    files[n + ".json"] = json.dumps(data, ensure_ascii=False, indent=1) + "\n"

old = set(f for f in os.listdir(OUT) if f.endswith(".json")) if os.path.isdir(OUT) else set()
if "--check" in sys.argv:
    bad = [f for f, text in files.items()
           if not os.path.exists(os.path.join(OUT, f)) or open(os.path.join(OUT, f), encoding="utf-8").read() != text]
    bad += sorted(old - set(files))
    if os.path.exists(os.path.join(ROOT, "data/i18n/de.json")):
        bad.append("../de.json (replaced by this folder, delete it)")
    if bad:
        sys.exit("data/i18n/de/ is out of date, run python3 tools/i18n/build.py: " + ", ".join(bad))
    print("i18n tables up to date (%d files, %d strings)" % (len(files), len(seen)))
    sys.exit(0)
os.makedirs(OUT, exist_ok=True)
for f in old - set(files):
    os.remove(os.path.join(OUT, f))
for f, text in files.items():
    with open(os.path.join(OUT, f), "w", encoding="utf-8") as fh:
        fh.write(text)
legacy = os.path.join(ROOT, "data/i18n/de.json")
if os.path.exists(legacy):
    os.remove(legacy)
print("%d strings -> %s (%d files)" % (len(seen), OUT, len(files)))
