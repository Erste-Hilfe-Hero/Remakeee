#!/usr/bin/env python3
"""Merges the German text tables in tools/i18n/de_*.py into data/i18n/de.json.
Run after editing a table: python3 tools/i18n/build.py"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import de_world, de_data, de_ui, de_online, de_story, de_ux, de_shop

strings = {}
for mod in (de_world, de_data, de_ui, de_online, de_story, de_ux, de_shop):
    for k, v in mod.T.items():
        if k in strings and strings[k] != v:
            sys.exit("conflicting German text for %r" % k)
        strings[k] = v
out = {"_comment": "German texts. Keys are the English text; keys with %s or %d are patterns. Built by tools/i18n/build.py.",
       "keep": sorted(set(de_ui.KEEP + de_online.KEEP + de_story.KEEP + de_ux.KEEP)), "strings": dict(sorted(strings.items()))}
path = os.path.join(os.path.dirname(os.path.dirname(HERE)), "data/i18n/de.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("%d strings -> %s" % (len(strings), path))
