#!/usr/bin/env python3
"""Gift (trait) balance report (Kampf plan item 259): how many species carry each species gift,
per element and in total, plus the Kampf plan's extra gifts and where they can come from.
Prints observations only. Run: python3 tools/balance/trait_report.py"""
import collections, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
spirlings = json.load(open(os.path.join(ROOT, "data/spirlings.json"), encoding="utf-8"))
kit = json.load(open(os.path.join(ROOT, "data/kampf_kit.json"), encoding="utf-8"))

total = collections.Counter()
by_elem = collections.defaultdict(collections.Counter)
for s in spirlings:
    t = s.get("trait", "")
    total[t] += 1
    for e in s.get("elements", [])[:1]:
        by_elem[e][t] += 1

print("Species gifts (%d species):" % len(spirlings))
for t, n in total.most_common():
    print("  %-14s %4d  %5.1f %%" % (t or "-", n, 100.0 * n / len(spirlings)))
print("\nPer first element:")
for e in sorted(by_elem):
    row = ", ".join("%s %d" % (t, n) for t, n in by_elem[e].most_common())
    print("  %-7s %s" % (e, row))

sources = collections.defaultdict(list)
for elem, ids in kit.get("bonus_traits", {}).items():
    for i in ids:
        sources[i].append("bonus " + elem)
for boss, i in kit.get("boss_traits", {}).items():
    sources[i].append("boss " + boss)
p = kit.get("prism_trait", {})
if p:
    sources[p["id"]].append("prism 1/%d" % p.get("share", 1))
print("\nKampf plan gifts (%d):" % len(kit["traits"]))
for i in sorted(kit["traits"]):
    print("  %-16s %s" % (i, "; ".join(sources[i]) or "no source yet"))
