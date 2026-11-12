#!/usr/bin/env python3
"""Rough first-play hours per act and per post-game era region from data (owner rule: at least
20 h per act and per era region). Coefficients live in data/playtime.json.
Usage: python3 tools/act_hours.py [act or region id ...]   (no argument: every act and region)"""
import glob, json, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def load(p):
    return json.load(open(os.path.join(ROOT, p), encoding="utf-8"))


def act_hours(act):
    """Hours of story act `act` (1-4) or of the era region with id `act` ("vellmarch", ...)."""
    cfg = load("data/playtime.json")
    k = cfg["minutes"]
    key = str(act)
    a = cfg["acts"][key] if key in cfg["acts"] else cfg["regions"][key]
    layout = load("data/world_layout.json")["maps"]
    maps = {}
    for path in glob.glob(os.path.join(ROOT, "data", "maps", "*.json")):
        mid = os.path.basename(path)[:-5]
        m = json.load(open(path, encoding="utf-8"))
        place = layout.get(mid, {})
        region = m.get("region") or layout.get(place.get("inside", ""), {}).get("region", "veydal")
        if region == a["region"]:
            maps[mid] = m
    names = set(a.get("places", [])) | {m.get("name", "") for m in maps.values()}
    parts = {}
    parts["maps"] = 0.0
    parts["wayfarers"] = parts["secrets"] = parts["wild"] = 0.0
    tables = set()
    for m in maps.values():
        for lv in [m] + m.get("floors", []):
            rows = lv.get("rows", [])
            parts["maps"] += k["map"] + sum(len(r) for r in rows) / k["map_tiles_per_minute"]
            parts["wayfarers"] += k["wayfarer"] * sum(1 for n in lv.get("npcs", []) if "trainer" in n)
            parts["secrets"] += k["secret"] * len(lv.get("secrets", []))
            if m.get("encounters") or lv.get("encounters"):
                parts["wild"] += k["wild_cell"] * sum(1 for r in rows for ch in r if ch in ",%:w")
                tables.add(lv.get("encounters") or m.get("encounters"))
    enc = load("data/encounters.json")
    species = {s["species"] for t in tables for s in enc.get(t, {}).get("spawns", [])}
    parts["species"] = k["encounter_species"] * len(species)
    lines = 0
    battles = 0
    files = set(maps)
    for m in maps.values():
        for lv in [m] + m.get("floors", []):
            for n in lv.get("npcs", []) + lv.get("signs", []) + lv.get("secrets", []):
                if "/" in str(n.get("dialogue", "")):
                    files.add(str(n["dialogue"]).split("/")[0])
    for fid in sorted(files):
        f = os.path.join(ROOT, "data", "dialogue", fid + ".json")
        if os.path.exists(f):
            for v in json.load(open(f, encoding="utf-8")).values():
                if isinstance(v, dict):
                    battles += sum(1 for a in str(v.get("action", "")).split(";") if a.split()[:1] == ["battle"])
                if isinstance(v, list):
                    lines += len(v)
                elif isinstance(v, dict):
                    lines += len(v.get("lines", []) or [])
                    alt = v.get("after_flag")
                    for x in alt if isinstance(alt, list) else [alt]:
                        if isinstance(x, dict):
                            lines += len(x.get("lines", []))
    parts["dialogue"] = k["dialogue_line"] * lines
    parts["duels"] = k["story_duel"] * battles
    q = load("data/quests.json")
    if key in cfg["acts"]:
        main = sum(1 for g in q["main"] if str(g.get("act", "")).startswith("Act %s:" % roman(act)))
    else:
        # An era region's story chapters live in its sheet (data/region<N>.json "story").
        sheet = a.get("sheet", "")
        main = len(load(sheet).get("story", [])) if sheet and os.path.exists(os.path.join(ROOT, sheet)) else 0
    parts["main"] = k["main_goal"] * main
    side = 0.0
    for g in q["side"]:
        where = str(g.get("where", ""))
        if any(n and n in where for n in names):
            side += k["side_goal"] + k["side_progress_step"] * len(g.get("progress", [])) + k["side_stage"] * len(g.get("stages", []))
    parts["side"] = side
    return sum(parts.values()) / 60.0, parts


def roman(n):
    return ["", "I", "II", "III", "IV", "V"][int(n)]


if __name__ == "__main__":
    cfg = load("data/playtime.json")
    ids = sys.argv[1:] or sorted(cfg["acts"]) + list(cfg.get("regions", {}))
    for act in ids:
        h, parts = act_hours(act)
        label = "Act %s" % act if str(act) in cfg["acts"] else "%s (Era %s)" % (cfg["regions"][act].get("name", act), cfg["regions"][act].get("era", "?"))
        print("%s: %.1f h  (%s)" % (label, h, ", ".join("%s %.0f min" % (p, v) for p, v in sorted(parts.items()))))
