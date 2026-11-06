#!/usr/bin/env python3
"""Merges the German text tables in tools/i18n/de_*.py into data/i18n/de.json.
Run after editing a table: python3 tools/i18n/build.py"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib, glob
# Every tools/i18n/de_*.py table is merged, so a new area can add its own file without
# touching this list (the parallel plan threads each keep their own table).
MODS = [importlib.import_module(os.path.basename(p)[:-3]) for p in sorted(glob.glob(os.path.join(HERE, "de_*.py")))]

strings = {}
for mod in MODS:
    for k, v in mod.T.items():
        if k in strings and strings[k] != v:
            sys.exit("conflicting German text for %r" % k)
        strings[k] = v
out = {"_comment": "German texts. Keys are the English text; keys with %s or %d are patterns. Built by tools/i18n/build.py.",
       "keep": sorted(set(k for mod in MODS for k in getattr(mod, "KEEP", []))), "strings": dict(sorted(strings.items()))}
path = os.path.join(os.path.dirname(os.path.dirname(HERE)), "data/i18n/de.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("%d strings -> %s" % (len(strings), path))
