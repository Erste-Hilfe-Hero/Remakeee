#!/usr/bin/env python3
"""Adds one act's Spirling lines to the game data (owner rule: every story act has 70 own Spirlings).

Reads tools/art/lines/<region>.py (the same specs tools/art/gen_lines.py draws from) and
  - writes the species into data/spirlings.json (stats in the rarity band, learnset, bond rate,
    unfold, lore, era 1). Kinds of these lines that are already there are replaced, new ones get
    the next free Spirlog numbers, so it can be run again after a rebase,
  - rewrites the act's wild tables in data/encounters.json from ENCOUNTERS (levels kept),
  - writes the German texts to tools/i18n/de_lines_<region>.py (then run tools/i18n/build.py),
  - adds the sprites to docs/ASSET_LOG.md.
Run: python3 tools/build_lines.py <region>
A spec may set ERA, RINGS, ACT and ART_TOOL (the Era III post-game region Quillmarch does).
"""
import hashlib
import importlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "art", "lines"))

STAT_ORDER = ["hp", "atk", "foc", "spd", "def"]
ROLE_WEIGHTS = {
    "vanguard": {"hp": 1.0, "atk": 1.25, "foc": 0.8, "spd": 1.15, "def": 0.85},
    "bulwark": {"hp": 1.2, "atk": 0.95, "foc": 0.8, "spd": 0.7, "def": 1.35},
    "weaver": {"hp": 1.0, "atk": 0.7, "foc": 1.35, "spd": 0.95, "def": 1.0},
    "striker": {"hp": 0.85, "atk": 1.2, "foc": 0.85, "spd": 1.35, "def": 0.75},
    "kindler": {"hp": 1.0, "atk": 0.85, "foc": 1.2, "spd": 1.1, "def": 0.85},
}
# Stat totals per stage, by line length (rarity bands in SpirlingData.STAT_TOTAL_BANDS).
TOTALS = {1: [425], 2: [320, 430], 3: [310, 405, 500]}
RARITY = {1: ["uncommon"], 2: ["common", "shy"], 3: ["common", "uncommon", "shy"]}
BOND = {"common": (0.45, 0.55), "uncommon": (0.25, 0.35), "shy": (0.08, 0.15)}
TRAITS = {
    "vanguard": ["surge", "last_stand", "steady"], "bulwark": ["thick_hide", "steady", "deep_roots"],
    "weaver": ["light_sleeper", "steady", "slick"], "striker": ["slick", "surge", "last_stand"],
    "kindler": ["kindling", "light_sleeper", "surge"],
}
KEEPSAKE = {"EMBER": "spark_coil", "VOLT": "spark_coil", "STONE": "iron_burr", "GALE": "swift_feather",
            "BLOOM": "bark_wrap", "TIDE": "keen_lens", "LUMEN": "keen_lens", "UMBRA": "keen_lens",
            "INK": "keen_lens", "ECHO": "swift_feather", "RUST": "iron_burr", "MASK": "keen_lens",
            "ACID": "iron_burr", "FROST": "swift_feather", "GILT": "keen_lens", "ZENITH": "swift_feather"}
HEIGHT = {"quad": 0.5, "biped": 0.6, "bird": 0.4, "serpent": 0.9, "fish": 0.5, "bug": 0.3, "shell": 0.4,
          "spirit": 0.4, "plant": 0.5}
# Unfold rings per act: (3-stage first, 3-stage second, 2-stage), near the act's wild rings.
RINGS = {"veydal": (14, 30, 22), "corvane": (18, 34, 26), "ashmere": (20, 36, 28), "solenne": (18, 34, 28)}
GROWTH = {1: [1.6], 2: [1.0, 2.2], 3: [1.0, 1.9, 3.2]}


def h(*parts) -> int:
    return int(hashlib.sha1("|".join(str(p) for p in parts).encode()).hexdigest(), 16)


def load(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return json.load(f)


def move_pools(species, moves):
    used = set()
    for s in species:
        for v in s["learnset"].values():
            used.update(v if isinstance(v, list) else [v])
    pools = {}
    for m in moves:
        if m["name"] not in used or "glass" in m["name"].lower():
            continue
        pools.setdefault(m["element"], []).append(m)
    # A new era's element has no kind using its arts yet: all of its arts form the pool.
    fresh = {m["element"] for m in moves} - {m["element"] for m in moves if m["name"] in used}
    for m in moves:
        if m["element"] in fresh:
            pools.setdefault(m["element"], []).append(m)
    return pools


def pick(cands, seed):
    cands = sorted(cands, key=lambda m: m["name"])
    return cands[seed % len(cands)]["name"] if cands else None


def learnset(line, stage, n_stages, pools, salt):
    els = line["elements"]
    e1 = els[0]
    e2 = els[1] if len(els) > 1 else line.get("cover", "STONE")
    p1, p2 = pools[e1], pools[e2]
    kind = "PHYSICAL" if line["role"] in ("vanguard", "striker", "bulwark") else "FOCUS"

    def win(p, lo, hi, energy=99):
        # Damage arts in a power window, the role's kind (Might or Focus) first, then any kind.
        out = [m for m in p if m["kind"] != "STATUS" and not m.get("cooldown") and "snare" not in m
               and lo <= m["power"] <= hi and m["energy"] <= energy]
        own = [m for m in out if m["kind"] == kind]
        return own if own else out

    def stat(p):
        return [m for m in p if m["kind"] == "STATUS" and "snare" not in m and not m.get("cooldown")]

    seed = h(line["id"], salt)
    plan = [
        (1, pick(win(p1, 1, 45, 2), seed)),
        (1, pick(stat(p1), seed >> 3)),
        (6, pick(win(p2, 1, 55, 3), seed >> 5)),
        (10, pick(win(p1, 50, 65), seed >> 7)),
        (15, pick(stat(p2) or stat(p1), seed >> 9)),
        (20, pick(win(p1, 65, 80), seed >> 11)),
        (26, pick(win(p2, 60, 85), seed >> 13)),
        (32, pick(win(p1, 80, 105), seed >> 15)),
    ]
    last = stage == n_stages
    if n_stages > 1 and stage >= 2 or n_stages == 1:
        plan.append((38, pick(win(p2, 85, 200), seed >> 17)))
    if last and n_stages > 1:
        plan.append((44, pick([m for m in p1 if m.get("cooldown")] or win(p1, 95, 200), seed >> 19)))
    out = {}
    seen = set()
    for lvl, name in plan:
        if not name or name in seen:
            continue
        seen.add(name)
        out.setdefault(str(lvl), []).append(name)
    return out


def stats(role, total, seed):
    w = dict(ROLE_WEIGHTS[role])
    for i, k in enumerate(STAT_ORDER):
        w[k] *= 1.0 + (((seed >> (4 * i)) % 9) - 4) / 50.0
    s = sum(w.values())
    out = {k: max(20, round(total * w[k] / s)) for k in STAT_ORDER}
    out["hp"] += total - sum(out.values())
    return out


def build_species(region, line, pools):
    mod_texts = line["_texts"]
    names = line["names"]
    n = len(names)
    out = []
    for i, name in enumerate(names):
        stage = i + 1
        rarity = RARITY[n][i]
        if n == 2 and i == 0 and len(line["elements"]) == 2:
            rarity = "uncommon"
        lo, hi = BOND[rarity]
        seed = h(name)
        lore, origin = mod_texts[name][0], mod_texts[name][1]
        sp = {
            "name": name,
            "elements": list(line["elements"]),
            "rarity": rarity,
            "region": region,
            "role": line["role"],
            "line_id": line["id"],
            "era": line["_era"],
            "base": stats(line["role"], round((TOTALS[n][i] + (seed % 11) - 5) * line.get("power", 1.0)), seed),
            "trait": line["_trait"],
            "learnset": learnset(line, stage, n, pools, name),
            "bond_rate": round(lo + (hi - lo) * ((seed >> 8) % 5) / 4, 2),
            "height": "%.1f m" % (HEIGHT[line["art"]["plan"]] * GROWTH[n][i]),
            "habitat": line["_habitat"][0],
            "lore": lore,
            "origin": origin,
            "cry_motif": [seed % 3, (seed % 3 + 1 + (seed >> 4) % 2) % 3],
            "keepsake_hint": KEEPSAKE[line["elements"][(seed >> 6) % len(line["elements"])]],
        }
        if stage < n:
            r1, r2, r_two = line["_rings"]
            ring = (r1 if stage == 1 else r2) if n == 3 else r_two
            sp["unfold"] = [{"to": names[i + 1], "rule": "ring", "value": ring + (seed % 5) - 2}]
        out.append(sp)
    return out


def pick_traits(region, lines, species):
    """One trait per line; the least used trait in the region first (test_content: at most 6 lines
    of a region share a trait), the role's own traits breaking ties."""
    count = {}
    for t in ["kindling", "thick_hide", "deep_roots", "light_sleeper", "slick", "steady", "surge", "last_stand"]:
        count[t] = set()
    for s in species:
        if s.get("region") == region:
            count.setdefault(s["trait"], set()).add(s.get("line_id", s["name"]))
    for line in lines:
        # A line may name its trait (KAMPF_PLAN_1000 items 194, 195: glimmer_skin, unruffled).
        if line.get("trait"):
            line["_trait"] = line["trait"]
            count.setdefault(line["trait"], set()).add(line["id"])
            continue
        pref = TRAITS[line["role"]]
        best = min(count, key=lambda t: (len(count[t]), 0 if t in pref else 1, (pref.index(t) if t in pref else 9), t))
        line["_trait"] = best
        count[best].add(line["id"])


def tune(region, kept, new_names, rounds=14):
    """Nudges the stat totals of the new kinds until the type simulation (tools/balance/type_sim.py,
    a Python mirror of the battle core) puts each between 40 and 60 % against its own stage."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "balance"))
    ts = importlib.import_module("type_sim")
    chart = load("data/type_chart.json")
    moves = {m["name"]: m for m in load("data/moves.json")}
    by = {s["name"]: s for s in kept}
    bands = {"common": (270, 465), "uncommon": (270, 515), "shy": (270, 515)}
    for r in range(rounds):
        _, mult = ts.chart_problems(chart, kept)
        sp, _ = ts.simulate(kept, moves, mult)
        moved = 0
        for n in new_names:
            rate = sp.get(n, (0.5,))[0]
            if 0.45 <= rate <= 0.55:
                continue
            s = by[n]
            total = sum(s["base"].values())
            step = 0.04 if abs(rate - 0.5) > 0.15 else 0.02
            want = round(total * (1 - step if rate > 0.5 else 1 + step))
            lo, hi = bands[s["rarity"]]
            want = max(lo, min(hi, want))
            if want != total:
                s["base"] = stats(s["role"], want, h(n))
                moved += 1
        print("tune round %d: %d kinds moved" % (r + 1, moved))
        if not moved:
            break


def sync_slots(mod, enc):
    """A region sheet with route slots (data/region4.json) mirrors the tables: one slot per spawn,
    every spawn on the route's whole ring span, Warden aces from ACES. Text edits keep its layout."""
    path = os.path.join(ROOT, mod.SLOTS)
    text = open(path, encoding="utf-8").read()
    sheet = json.loads(text)
    for r in sheet["routes"]:
        if r["id"] not in mod.ENCOUNTERS:
            continue
        spawns = enc[r["id"]]["spawns"]
        for s in spawns:
            s["min"], s["max"] = r["ring"]
        prefix = r["slots"][0]["slot"].rsplit("_", 1)[0]
        rows = ['   {"slot": "%s_%s", "ground": "%s", "weight": %d, "species": "%s"}'
                % (prefix, "abcdefghij"[i], s["ground"], s["weight"], s["species"]) for i, s in enumerate(spawns)]
        pat = re.compile(r'(\{"id": "%s",[^\n]*\n   "slots": \[\n).*?(\]\})' % re.escape(r["id"]), re.S)
        text = pat.sub(lambda m: m.group(1) + ",\n".join(rows) + m.group(2), text, count=1)
    for slot, name in getattr(mod, "ACES", {}).items():
        pat = r'\{"slot": "%s", "species": (null|"[^"]*")(, "stand_in": "[^"]*")?' % re.escape(slot)
        text = re.sub(pat, '{"slot": "%s", "species": "%s"' % (slot, name), text, count=1)
    json.loads(text)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    region = sys.argv[1]
    mod = importlib.import_module(region)
    species = load("data/spirlings.json")
    moves = load("data/moves.json")
    names = {n for line in mod.LINES for n in line["names"]}
    ids = {line["id"] for line in mod.LINES}
    taken = {s["name"].lower() for s in species if s["name"] not in names}
    for n in names:
        if n.lower() in taken:
            sys.exit("name %s is already used" % n)
    kept = [s for s in species if s["name"] not in names and not (s.get("line_id") in ids and s.get("region") == region)]
    kept.sort(key=lambda s: s["dex_id"])
    for i, s in enumerate(kept):
        s["dex_id"] = i + 1
    pools = move_pools(kept, moves)
    pick_traits(region, mod.LINES, kept)
    nxt = len(kept) + 1
    for line in mod.LINES:
        line["_texts"] = mod.TEXTS
        line["_habitat"] = mod.HABITAT[line["id"]]
        # Post-game era regions set their own era, rings and art tool (tools/art/lines/quillmarch.py).
        line["_era"] = getattr(mod, "ERA", 1)
        line["_rings"] = getattr(mod, "RINGS", None) or RINGS[region]
        for sp in build_species(region, line, pools):
            kept.append(dict({"dex_id": nxt}, **sp))
            nxt += 1
    if "--no-tune" not in sys.argv:
        # Lines with a hand-set "power" were placed by the full Godot sim and keep their totals.
        tune(region, kept, [n for line in mod.LINES if "power" not in line for n in line["names"]])
    with open(os.path.join(ROOT, "data/spirlings.json"), "w", encoding="utf-8") as f:
        json.dump(kept, f, ensure_ascii=False, indent=1)
        f.write("\n")

    rarity = {s["name"]: s["rarity"] for s in kept}
    enc = load("data/encounters.json")
    weights = {"common": [40, 34, 30, 26], "uncommon": [22, 18, 14, 12, 10], "shy": [6, 5, 4, 3]}
    def spawn(name, ground, k, lo, hi, used):
        r = rarity[name]
        w = weights[r][used[r] % len(weights[r])]
        used[r] += 1
        mn = lo + (k % 2) if r != "shy" else hi - 1
        row = {"species": name, "min": min(mn, hi), "max": hi if r == "shy" else max(min(mn + 2, hi), lo), "weight": w}
        if ground:
            row["ground"] = ground
        return row

    for table, rows in getattr(mod, "ENCOUNTERS", {}).items():
        old = enc[table]["spawns"]
        lo = min(int(s["min"]) for s in old)
        hi = max(int(s["max"]) for s in old)
        used = {"common": 0, "uncommon": 0, "shy": 0}
        enc[table]["spawns"] = [spawn(n, g, k, lo, hi, used) for k, (n, g) in enumerate(rows)]
    for table, rows in getattr(mod, "ENCOUNTERS_ADD", {}).items():
        old = [s for s in enc[table]["spawns"] if s["species"] not in names]
        lo = min(int(s["min"]) for s in old)
        hi = max(int(s["max"]) for s in old)
        used = {"common": 1, "uncommon": 1, "shy": 1}
        enc[table]["spawns"] = old + [spawn(n, g, k, lo, hi, used) for k, (n, g) in enumerate(rows)]
    if getattr(mod, "SLOTS", None):
        sync_slots(mod, enc)
    with open(os.path.join(ROOT, "data/encounters.json"), "w", encoding="utf-8") as f:
        json.dump(enc, f, ensure_ascii=False, indent=1)
        f.write("\n")

    T = {}
    for line in mod.LINES:
        en, de = mod.HABITAT[line["id"]]
        T[en] = de
        for n in line["names"]:
            le, oe, ld, od = mod.TEXTS[n]
            T[le], T[oe] = ld, od
    with open(os.path.join(ROOT, "tools/i18n/de_lines_%s.py" % region), "w", encoding="utf-8") as f:
        f.write("# German texts for the %s lines (tools/art/lines/%s.py). Written by tools/build_lines.py.\n"
                % (region.capitalize(), region))
        f.write("T = {\n")
        for k, v in T.items():
            f.write("%s: %s,\n" % (json.dumps(k, ensure_ascii=False), json.dumps(v, ensure_ascii=False)))
        f.write("}\n")

    log_path = os.path.join(ROOT, "docs/ASSET_LOG.md")
    log = open(log_path, encoding="utf-8").read()
    add = []
    era = getattr(mod, "ERA", 1)
    tool = getattr(mod, "ART_TOOL", "tools/art/gen_lines.py")
    for n in sorted(names):
        # Era IV sprites have a breath frame "_b" beside each side (tools/art/gen_era4.py).
        for side in ("back", "front") if era < 4 else ("back", "back_b", "front", "front_b"):
            p = "art/era%d/spirlings/%s_%s.png" % (era, n.lower(), side)
            if p not in log:
                add.append("| %s | Claude (AI) for Ali | Generated by %s (original Spirling line, %s) "
                           "| Owned by the project, no third-party input | 2026-11-12 |" % (p, tool, region.capitalize()))
    if add:
        with open(log_path, "a", encoding="utf-8") as f:
            if not log.endswith("\n"):
                f.write("\n")
            f.write("\n".join(add) + "\n")
    doc_path = os.path.join(ROOT, "docs/SPIRLINGS.md")
    doc = open(doc_path, encoding="utf-8").read()
    acts = {"veydal": "Act I", "corvane": "Act II", "ashmere": "Act III", "solenne": "Act IV"}
    rows = ["<!-- lines:%s -->" % region,
            "## %s lines (%s, tools/art/lines/%s.py)" % (region.capitalize(), getattr(mod, "ACT", None) or acts[region], region), "",
            "Owner rule: every story act has 70 own Spirlings. Drawn by %s from one base form "
            "per line, data by tools/build_lines.py." % tool, "",
            "| No. | Name | Elements | Rarity | Role | Trait | Stat total | Unfolds into |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for sp in kept:
        if sp["name"] in names:
            u = sp.get("unfold", [])
            rows.append("| %d | %s | %s | %s | %s | %s | %d | %s |" % (
                sp["dex_id"], sp["name"], "/".join(e.capitalize() for e in sp["elements"]), sp["rarity"], sp["role"],
                sp["trait"], sum(sp["base"].values()), "%s (ring %d)" % (u[0]["to"], u[0]["value"]) if u else "-"))
    rows.append("<!-- /lines:%s -->" % region)
    block = "\n".join(rows) + "\n"
    start, end = "<!-- lines:%s -->" % region, "<!-- /lines:%s -->\n" % region
    if start in doc:
        doc = doc[:doc.index(start)] + block + doc[doc.index(end) + len(end):]
    else:
        anchor = "## Regional imprints"
        doc = doc.replace(anchor, block + "\n" + anchor, 1)
    with open(doc_path, "w", encoding="utf-8") as f:
        f.write(doc)
    print("%s: %d kinds, %d total, %d log rows" % (region, len(names), len(kept), len(add)))


if __name__ == "__main__":
    main()
