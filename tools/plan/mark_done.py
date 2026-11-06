#!/usr/bin/env python3
"""Marks plan items as done: python3 tools/plan/mark_done.py docs/plan5000/06_grafik_audio.md 2225 2226 ...
Turns "2225. [P1] ..." into "2225. [x] [P1] ..." (already marked items stay as they are)."""
import re, sys

path, nums = sys.argv[1], set(sys.argv[2:])
lines = open(path, encoding="utf-8").read().split("\n")
hit = set()
for i, l in enumerate(lines):
    m = re.match(r"^(\d+)\. (?!\[x\])", l)
    if m and m.group(1) in nums:
        lines[i] = l.replace(m.group(0), m.group(1) + ". [x] ", 1)
        hit.add(m.group(1))
    elif re.match(r"^(\d+)\. \[x\]", l) and l.split(".")[0] in nums:
        hit.add(l.split(".")[0])
open(path, "w", encoding="utf-8").write("\n".join(lines))
missing = nums - hit
if missing:
    sys.exit("not found: " + " ".join(sorted(missing)))
print("marked", len(hit))
