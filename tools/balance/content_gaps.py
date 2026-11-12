#!/usr/bin/env python3
"""Counts the battle content in data/ (arts, learnsets, items, gifts, statuses) for
docs/CONTENT_GAPS.md. Prints observations only, never a verdict.
Usage: python3 tools/balance/content_gaps.py [--md FILE]"""
import argparse, collections, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ELEMENTS = ["EMBER", "TIDE", "BLOOM", "VOLT", "STONE", "GALE", "LUMEN", "UMBRA",
            "INK", "ECHO", "RUST", "MASK", "ACID", "FROST", "GILT", "ZENITH"]
STATUSES = ["scorch", "soak", "root", "jolt", "daze", "drowse"]


def load(name):
    with open(os.path.join(ROOT, "data", name), encoding="utf-8") as f:
        return json.load(f)


def damaging(m):
    return m["kind"] != "STATUS" and m["power"] > 0


def band(p):
    return "weak" if p <= 50 else ("mid" if p <= 80 else "strong")


def tags(m):
    t = set()
    if m.get("priority", 0) > 0:
        t.add("priority +1")
    if m.get("priority", 0) < 0:
        t.add("priority -1")
    eff = m.get("effect", "")
    if eff == "recoil" or eff == "self_cost":
        t.add("recoil / HP cost")
    if eff in ("drain", "energy_drain"):
        t.add("drain")
    if eff in ("heal_self",) or m.get("mend") or eff == "cure_team":
        t.add("healing / cure")
    up = False
    if m.get("stat") and m.get("self", True) and m.get("stages", 1) > 0:
        up = True
    if isinstance(m.get("stats"), dict) and m.get("self", True) and any(v > 0 for v in m["stats"].values()):
        up = True
    if up:
        t.add("setup (own stages up)" if not damaging(m) else "stage up on hit")
    down = (m.get("stat") and not m.get("self", True)) or (isinstance(m.get("stats"), dict) and not m.get("self", True))
    if down:
        t.add("foe stages down")
    if m.get("field") or m.get("field_element"):
        t.add("field")
    if m.get("snare"):
        t.add("hazard (snare)")
    if m.get("clear_snares") or eff == "stage_reset":
        t.add("hazard / stage clear")
    if m.get("status"):
        t.add("inflicts status")
    if m.get("target") == "foes":
        t.add("hits all foes")
    if m.get("cooldown"):
        t.add("cooldown big hit")
    if m.get("overcharge"):
        t.add("overcharge")
    if eff in ("energy_burn", "energy_tax", "energy_gain") or eff == "energy_drain":
        t.add("energy play")
    if m.get("vs_status"):
        t.add("bonus vs status")
    if m.get("delay"):
        t.add("delayed hit")
    if m.get("hits"):
        t.add("multi-hit")
    if m.get("switch"):
        t.add("switching")
    return t


def known_by(s, level):
    out = []
    for lvl in sorted(s["learnset"], key=int):
        if int(lvl) > level:
            continue
        v = s["learnset"][lvl]
        for n in (v if isinstance(v, list) else [v]):
            if n not in out:
                out.append(n)
    return out


def good_count(names, moves):
    """Damage arts of power 40+ and accuracy 0.8+, plus at most two status arts."""
    hits = sum(1 for n in names if damaging(moves[n]) and moves[n]["power"] >= 40 and moves[n]["accuracy"] >= 0.8)
    status = sum(1 for n in names if not damaging(moves[n]))
    return hits + min(status, 2)


def teach_ok(item, sp, moves):
    mv = moves.get(item.get("teaches", ""))
    if mv is None:
        return False
    if item.get("any_element"):
        return True
    allowed = set(item.get("for_elements", [])) | {mv["element"]}
    return bool(allowed & set(sp["elements"]))


def report():
    moves_l = load("moves.json")
    moves = {m["name"]: m for m in moves_l}
    species = load("spirlings.json")
    items = load("items.json")
    out = []
    out.append("Arts: %d. Spirlings: %d. Items: %d." % (len(moves_l), len(species), len(items)))
    kinds = collections.Counter(m["kind"] for m in moves_l)
    out.append("By kind: physical %d, focus (special) %d, status %d." % (kinds["PHYSICAL"], kinds["FOCUS"], kinds["STATUS"]))
    eras = collections.Counter(int(m.get("era", 0)) for m in moves_l)
    out.append("By era tag: " + ", ".join("%s %d" % ("none" if e == 0 else "era %d" % e, n) for e, n in sorted(eras.items())) + ".")
    bands = collections.Counter()
    for m in moves_l:
        if damaging(m):
            p = m["power"]
            bands["1-40" if p <= 40 else "45-60" if p <= 60 else "65-80" if p <= 80 else "85-100" if p <= 100 else "105+"] += 1
    out.append("Damage arts by power: " + ", ".join("%s %d" % (k, bands[k]) for k in ["1-40", "45-60", "65-80", "85-100", "105+"]) + ".")
    out += ["", "| Element | All | Phys weak/mid/strong | Focus weak/mid/strong | Status |", "| --- | --- | --- | --- | --- |"]
    for e in ELEMENTS:
        c = collections.Counter()
        for m in moves_l:
            if m["element"] != e:
                continue
            c["all"] += 1
            if damaging(m):
                c[m["kind"][0] + band(m["power"])] += 1
            else:
                c["st"] += 1
        out.append("| %s | %d | %d/%d/%d | %d/%d/%d | %d |" % (e.capitalize(), c["all"], c["Pweak"], c["Pmid"], c["Pstrong"],
                                                       c["Fweak"], c["Fmid"], c["Fstrong"], c["st"]))
    tc = collections.Counter()
    for m in moves_l:
        for t in tags(m):
            tc[t] += 1
    out += ["", "| Art role | Count |", "| --- | --- |"]
    for t in ["priority +1", "priority -1", "multi-hit", "recoil / HP cost", "drain", "setup (own stages up)", "stage up on hit",
              "foe stages down", "field", "hazard (snare)", "hazard / stage clear", "switching", "healing / cure", "inflicts status",
              "hits all foes", "cooldown big hit", "overcharge", "energy play", "bonus vs status", "delayed hit"]:
        out.append("| %s | %d |" % (t, tc[t]))
    sc = collections.Counter(m.get("status") for m in moves_l if m.get("status"))
    out.append("")
    out.append("Status arts per condition: " + ", ".join("%s %d" % (s, sc[s]) for s in STATUSES) + ".")
    effects = collections.Counter(m.get("effect") for m in moves_l if m.get("effect"))
    out.append("Effect ids in use: " + ", ".join("%s %d" % kv for kv in sorted(effects.items())) + ".")
    learn = collections.Counter()
    for s in species:
        for n in known_by(s, 999):
            learn[n] += 1
    teach = {}
    for it in items:
        if it.get("teaches"):
            teach[it["teaches"]] = teach.get(it["teaches"], 0) + sum(1 for s in species if teach_ok(it, s, moves))
    nobody = [m["name"] for m in moves_l if learn[m["name"]] == 0 and teach.get(m["name"], 0) == 0]
    only_taught = [m["name"] for m in moves_l if learn[m["name"]] == 0 and teach.get(m["name"], 0) > 0]
    out += ["", "Arts in no learnset and taught by no item: %d%s" % (len(nobody), (" (" + ", ".join(nobody) + ")") if nobody else ""),
            "Arts only taught by an item: %d." % len(only_taught)]
    out += ["", "| Ring | Spirlings with fewer than 4 good arts | Fewer than 4 arts at all |", "| --- | --- | --- |"]
    for lv in (20, 30, 40, 60):
        few_good = sum(1 for s in species if good_count(known_by(s, lv), moves) < 4)
        few = [s["name"] for s in species if len(known_by(s, lv)) < 4]
        out.append("| %d | %d | %d |" % (lv, few_good, len(few)))
    late = sum(1 for s in species if max(int(l) for l in s["learnset"]) < 45)
    out.append("")
    out.append("Spirlings that learn nothing new after Ring 44: %d of %d." % (late, len(species)))
    sizes = collections.Counter(len(known_by(s, 999)) for s in species)
    out.append("Learnset sizes: " + ", ".join("%d arts x%d" % kv for kv in sorted(sizes.items())) + ".")
    kinds_i = collections.Counter()
    for it in items:
        if it.get("teaches"):
            k = "teaching (Echo Crystal / Script)"
        elif it.get("held"):
            k = "keepsake (held)"
        elif it.get("gear"):
            k = "gear (field tool)"
        elif it.get("cure") and not it.get("heal") and not it.get("heal_frac"):
            k = "status cure"
        elif it.get("heal") or it.get("heal_frac") or it.get("revive") or it.get("battle_revive") or it.get("energy") or it.get("energy_surge"):
            k = "healing / revive / energy"
        elif it.get("stage"):
            k = "battle brew (stage up)"
        elif it.get("boost") or it.get("rings") or it.get("rings_to") or it.get("crystal") or it.get("spark") or it.get("spark_all"):
            k = "boost / growth"
        elif str(it.get("id", "")).startswith("rg_"):
            k = "shop other"
        else:
            k = "other"
        kinds_i[k] += 1
    out += ["", "| Item kind | Count |", "| --- | --- |"] + ["| %s | %d |" % kv for kv in sorted(kinds_i.items())]
    cures = {str(it["cure"]) for it in items if isinstance(it.get("cure"), str)}
    out.append("")
    out.append("Single-status cures: %s. Missing: %s." % (", ".join(sorted(cures)) or "none",
                                                      ", ".join(s for s in STATUSES if s not in cures) or "none"))
    prism = sorted({it["held"]["elem"] for it in items if isinstance(it.get("held"), dict) and it["held"].get("elem")})
    coin_prism = sorted({it["held"]["elem"] for it in items if isinstance(it.get("held"), dict) and it["held"].get("elem") and it.get("price")})
    out.append("Element keepsakes: %d elements (%d bought with coins)." % (len(prism), len(coin_prism)))
    rules = open(os.path.join(ROOT, "scripts/battle/BattleRules.gd"), encoding="utf-8").read()
    block = rules.split("const TRAITS", 1)[1].split("\n}\n", 1)[0]
    traits = re.findall(r'^\t"([a-z_]+)": \{', block, re.M)
    used = collections.Counter(s.get("trait") for s in species)
    hidden = len(load("hidden_gifts.json").get("gifts", {}))
    out.append("Gifts (passive abilities): %d traits in BattleRules.TRAITS (%d in use on Spirlings) and %d hidden gifts (data/hidden_gifts.json)." % (
        len(traits), len([t for t in used if t]), hidden))
    return "\n".join(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--md")
    a = ap.parse_args()
    text = report()
    print(text)
    if a.md:
        with open(a.md, "w", encoding="utf-8") as f:
            f.write(text + "\n")
