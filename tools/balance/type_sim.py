#!/usr/bin/env python3
"""Type chart checks and a seeded team-battle simulation (docs/BALANCE.md, "Type balance").

A Python mirror of the battle core so thousands of battles run in seconds without Godot:
stat curve (Spirling.gd), damage curve, STAB, crit and roll (DamageCalc.gd), the element
chart (data/type_chart.json, read by Elements.gd), Energy (start 10, +1 a turn, rest +2),
accuracy, priority and speed order. Status arts, traits, items and fields are left out on
purpose: this run measures the chart and base stats only. The full model stays in
tools/balance_sim.gd.

Teams of 3 distinct species of the same unfold stage fight at the same ring; every battle is
played twice with the sides swapped. Fails (exit 1) if the chart breaks its rules; the species 40-60 %
band is reported, and fails only with --strict (the full model is the real gate).

Chart sim (always a gate): one equal-stat Spirling per element with a single art of its own element,
so only the chart decides. Every element meets every element 1 on 1, and every team of 3 distinct
elements meets every team it shares no element with, in several lead orders, sides swapped. Run for
the Era I elements alone and for all eras (Rust and Mask included, which sit on no Spirling yet).
Fails if an element leaves 40-60 % (1 on 1 or in teams) or a team of 3 leaves 30-70 %.

  python3 tools/balance/type_sim.py                  check, print the table
  python3 tools/balance/type_sim.py --md out.md      also write the report as Markdown
"""
import argparse
import itertools
import json
import os
import random
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LEVEL = 36
BATTLES = 20000
SEED = 20261111
TEAM = 3
BAND = (0.40, 0.60)
MAX_TURNS = 100
CHART_DUELS = 40
CHART_ORDERS = 4
CHART_SEED = 352
TEAM_BAND = (0.30, 0.70)

STAB = 1.25
CRIT_MULT = 1.4
CRIT_CHANCE = 1.0 / 12.0
ROLL_MIN, ROLL_MAX = 0.90, 1.00
START_ENERGY, MAX_ENERGY, ENERGY_PER_TURN, REST_ENERGY = 10, 10, 1, 2


def load(name):
    with open(os.path.join(ROOT, "data", name), encoding="utf-8") as f:
        return json.load(f)


def chart_problems(chart, species):
    types = chart["types"]
    strong = {t: set(v["strong"]) for t, v in types.items()}
    out = []

    def mult(a, d):
        if d in strong[a] and a not in strong[d]:
            return chart["strong_mult"]
        if a in strong[d] and d not in strong[a]:
            return chart["weak_mult"]
        return 1.0

    for t, s in strong.items():
        for o in s:
            if o not in types:
                out.append("%s beats unknown %s" % (t, o))
        # A mutual pair is neutral both ways, so only real strengths and weaknesses count.
        if sum(mult(t, o) > 1 for o in types) < 2:
            out.append("%s has fewer than 2 real strengths" % t)
        if sum(mult(o, t) > 1 for o in types) < 2:
            out.append("%s has fewer than 2 real weaknesses" % t)
        # Even count, so no element is ahead on the chart alone; checked for Era I by itself too.
        for era_max in (1, max(v.get("era", 1) for v in types.values())):
            if types[t].get("era", 1) > era_max:
                continue
            pool = [o for o in types if types[o].get("era", 1) <= era_max]
            ns, nw = sum(mult(t, o) > 1 for o in pool), sum(mult(o, t) > 1 for o in pool)
            if ns != nw:
                out.append("%s has %d strengths and %d weaknesses up to Era %d" % (t, ns, nw, era_max))

    for a in types:
        for b in types:
            if a == b:
                continue
            # a dominates b: hits every element at least as hard and takes at most as much, once strictly better.
            off = [mult(a, x) - mult(b, x) for x in types]
            dfn = [mult(x, b) - mult(x, a) for x in types]
            if min(off + dfn) >= 0 and max(off + dfn) > 0:
                out.append("%s strictly dominates %s" % (a, b))
    used = {e for s in species for e in s["elements"]}
    # Era II elements may sit on legendary (ancient) kinds only; those stay out of the sim.
    common = {e for s in species if s.get("rarity") != "ancient" for e in s["elements"]}
    for t, v in types.items():
        if v.get("era", 1) > 1 and t in common:
            out.append("Era %d element %s is on a non-legendary Spirling" % (v["era"], t))
    for e in used:
        if e not in types:
            out.append("Spirling element %s is not in the chart" % e)
    return out, mult


def stages(species):
    by_name = {s["name"]: s for s in species}
    parent = {}
    for s in species:
        for u in s.get("unfold", []):
            parent.setdefault(u["to"], s["name"])
    out = {}
    for s in species:
        n, d = s["name"], 0
        while n in parent:
            n, d = parent[n], d + 1
        # A kind that never unfolds and comes from nothing is fully grown: it meets the second stage.
        if d == 0 and not s.get("unfold"):
            d = 1
        out[s["name"]] = d
    return out, by_name


def default_moves(s, moves, level):
    known = []
    for lvl in sorted(s["learnset"], key=int):
        if int(lvl) > level:
            continue
        lst = s["learnset"][lvl]
        for m in (lst if isinstance(lst, list) else [lst]):
            if m not in known:
                known.append(m)
    kept = known[-4:]
    hits = [m for m in kept if moves[m]["power"] > 0]
    for m in reversed(known[:-4]):
        if len(hits) >= 2:
            break
        if moves[m]["power"] > 0:
            for i, k in enumerate(kept):
                if moves[k]["power"] <= 0:
                    kept[i] = m
                    hits.append(m)
                    break
    return [moves[m] for m in kept if moves[m]["power"] > 0 and moves[m]["kind"] != "STATUS"]


class Mon:
    def __init__(self, s, moves, level):
        b = s["base"]
        self.name = s["name"]
        self.elements = s["elements"]
        self.level = level
        self.hp = self.max_hp = max(1, (b["hp"] * (level + 18)) // 20)
        st = {k: (b[k] * (level + 12)) // 28 + 4 for k in ("atk", "def", "foc", "spd")}
        self.atk, self.df, self.foc, self.spd = st["atk"], st["def"], st["foc"], st["spd"]
        self.moves = default_moves(s, moves, level)
        self.energy = START_ENERGY


def raw(u, t, mv, mult, roll, crit):
    a, d = (u.atk, t.df) if mv["kind"] == "PHYSICAL" else (u.foc, t.foc)
    base = mv["power"] * (a / max(d, 1)) ** 0.8 * (u.level / 5.0 + 3.0) / 12.0 + 1.0
    eff = 1.0
    for e in t.elements:
        eff *= mult(mv["element"], e)
    return base * (STAB if mv["element"] in u.elements else 1.0) * eff * (CRIT_MULT if crit else 1.0) * roll


def choose(u, t, mult):
    best, score = None, 0.0
    for mv in u.moves:
        if mv["energy"] > u.energy:
            continue
        sc = raw(u, t, mv, mult, 0.95, False) * mv["accuracy"]
        if sc > score:
            best, score = mv, sc
    return best


def battle(a_team, b_team, mult, rng):
    teams = [a_team, b_team]
    size = len(a_team)
    idx = [0, 0]
    for _ in range(MAX_TURNS):
        act = [teams[i][idx[i]] for i in (0, 1)]
        picks = [choose(act[i], act[1 - i], mult) for i in (0, 1)]
        order = sorted((0, 1), key=lambda i: (-(picks[i] or {}).get("priority", 0), -act[i].spd, rng.random()))
        for i in order:
            u, t = teams[i][idx[i]], teams[1 - i][idx[1 - i]]
            if u is not act[i] or u.hp <= 0:
                continue
            mv = picks[i]
            if mv is None:
                u.energy = min(MAX_ENERGY, u.energy + REST_ENERGY)
                continue
            u.energy -= mv["energy"]
            if rng.random() >= mv["accuracy"]:
                continue
            crit = rng.random() < CRIT_CHANCE
            t.hp -= max(1, int(raw(u, t, mv, mult, rng.uniform(ROLL_MIN, ROLL_MAX), crit)))
            if t.hp <= 0:
                idx[1 - i] += 1
                if idx[1 - i] >= size:
                    return i
        for i in (0, 1):
            m = teams[i][idx[i]]
            m.energy = min(MAX_ENERGY, m.energy + ENERGY_PER_TURN)
    return -1


def simulate(species, moves, mult, level=LEVEL, battles=BATTLES, seed=SEED):
    stage_of, by_name = stages(species)
    pools = {}
    for s in species:
        if s["rarity"] != "ancient":
            pools.setdefault(stage_of[s["name"]], []).append(s["name"])
    rng = random.Random(seed)
    wins, games = {}, {}
    type_w, type_g = {}, {}
    for stage in sorted(pools):
        pool = pools[stage]
        size = min(TEAM, len(pool) // 2)
        if size < 1:
            continue
        for _ in range(battles):
            names = rng.sample(pool, size * 2)
            sides = [names[:size], names[size:]]
            seed_b = rng.random()
            score = [0.0, 0.0]
            for flip in (0, 1):
                br = random.Random(seed_b)
                a, b = sides[flip], sides[1 - flip]
                w = battle([Mon(by_name[n], moves, level) for n in a], [Mon(by_name[n], moves, level) for n in b], mult, br)
                if w == -1:
                    score[0] += 0.5
                    score[1] += 0.5
                else:
                    score[flip if w == 0 else 1 - flip] += 1.0
            for side in (0, 1):
                els = set()
                for n in sides[side]:
                    wins[n] = wins.get(n, 0.0) + score[side]
                    games[n] = games.get(n, 0) + 2
                    els.update(by_name[n]["elements"])
                for e in els:
                    type_w[e] = type_w.get(e, 0.0) + score[side]
                    type_g[e] = type_g.get(e, 0) + 2
    sp = {n: (wins[n] / games[n], games[n], stage_of[n]) for n in games}
    ty = {e: (type_w[e] / type_g[e], type_g[e]) for e in type_g}
    return sp, ty


def chart_mon(e, level=LEVEL):
    s = {"name": e, "elements": [e], "base": {k: 80 for k in ("hp", "atk", "def", "foc", "spd")}, "learnset": {}}
    m = Mon(s, {}, level)
    m.moves = [{"name": e, "element": e, "kind": "SPECIAL", "power": 70, "accuracy": 1.0, "energy": 0, "priority": 0}]
    return m


def chart_sim(pool, mult, seed=CHART_SEED):
    """Element 1-on-1 and team-of-3 win rates where only the chart differs. Returns (duel, team_el, comps)."""
    rng = random.Random(seed)
    dw = {t: 0.0 for t in pool}
    dg = {t: 0 for t in pool}
    for a in pool:
        for b in pool:
            for _ in range(CHART_DUELS):
                w = battle([chart_mon(a)], [chart_mon(b)], mult, random.Random(rng.random()))
                dw[a] += 0.5 if w == -1 else float(w == 0)
                dw[b] += 0.5 if w == -1 else float(w == 1)
                dg[a] += 1
                dg[b] += 1
    comps = list(itertools.combinations(pool, TEAM))
    cw = {c: 0.0 for c in comps}
    cg = {c: 0 for c in comps}
    for i, a in enumerate(comps):
        for b in comps[i + 1:]:
            if set(a) & set(b):
                continue
            for _ in range(CHART_ORDERS):
                la, lb, sd = rng.sample(a, TEAM), rng.sample(b, TEAM), rng.random()
                for flip in (0, 1):
                    x, y = (la, lb) if flip == 0 else (lb, la)
                    w = battle([chart_mon(e) for e in x], [chart_mon(e) for e in y], mult, random.Random(sd))
                    a_won = 0.5 if w == -1 else float((w == 0) == (flip == 0))
                    cw[a] += a_won
                    cw[b] += 1.0 - a_won
                    cg[a] += 1
                    cg[b] += 1
    comp_rate = {c: cw[c] / cg[c] for c in comps if cg[c]}
    team_el = {}
    for t in pool:
        rs = [r for c, r in comp_rate.items() if t in c]
        team_el[t] = sum(rs) / len(rs)
    return {t: dw[t] / dg[t] for t in pool}, team_el, comp_rate


def chart_report(chart, mult):
    """Runs the chart sim for Era I and for all eras. Returns (markdown lines, band misses)."""
    types = chart["types"]
    pools = [("Era I", [t for t, v in types.items() if v.get("era", 1) == 1]), ("All eras", list(types))]
    lines = ["Chart sim (equal stats, one art of the own element, seed %d): %d duels per pair, every team of %d "
             "against every team it shares no element with, %d lead orders, sides swapped. Element band %d to %d %%, "
             "team band %d to %d %%." % (CHART_SEED, CHART_DUELS, TEAM, CHART_ORDERS, BAND[0] * 100, BAND[1] * 100,
                                         TEAM_BAND[0] * 100, TEAM_BAND[1] * 100), "",
             "| Element | %s 1 on 1 | %s teams | %s 1 on 1 | %s teams |" % (pools[0][0], pools[0][0], pools[1][0], pools[1][0]),
             "| --- | --- | --- | --- | --- |"]
    misses, res = [], []
    for label, pool in pools:
        duel, team_el, comps = chart_sim(pool, mult)
        res.append((duel, team_el))
        for t in pool:
            for kind, r in (("1 on 1", duel[t]), ("teams", team_el[t])):
                if not BAND[0] <= r <= BAND[1]:
                    misses.append("%s element %s %s at %.1f %%" % (label, t, kind, r * 100))
        for c, r in comps.items():
            if not TEAM_BAND[0] <= r <= TEAM_BAND[1]:
                misses.append("%s team %s at %.1f %%" % (label, "/".join(c), r * 100))
        lo, hi = min(comps, key=comps.get), max(comps, key=comps.get)
        res[-1] += ("%s: %d teams, lowest %s %.1f %%, highest %s %.1f %%." % (
            label, len(comps), "/".join(x.capitalize() for x in lo), comps[lo] * 100,
            "/".join(x.capitalize() for x in hi), comps[hi] * 100),)
    for t in types:
        cells = []
        for (label, pool), (duel, team_el, _) in zip(pools, res):
            cells += ["%.1f %%" % (duel[t] * 100), "%.1f %%" % (team_el[t] * 100)] if t in pool else ["-", "-"]
        lines.append("| %s | %s |" % (t.capitalize(), " | ".join(cells)))
    lines += [""] + [r[2] for r in res]
    lines += ["", "Chart sim outside the band: %s" % ("none" if not misses else "; ".join(misses))]
    return lines, misses


def report(chart, sp, ty, problems):
    lo, hi = BAND
    lines = ["Ring %d, %d team battles per stage (teams of %d, 2 in a stage of fewer than 6, sides swapped), seed %d, band %d to %d %%." % (
        LEVEL, BATTLES, TEAM, SEED, lo * 100, hi * 100), "", "| Element | Era | Strong vs | Weak vs | Win rate |",
        "| --- | --- | --- | --- | --- |"]
    types = chart["types"]
    for t, v in types.items():
        weak = [o for o in types if t in types[o]["strong"] and o not in types[t]["strong"]]
        wr = "%.1f %%" % (ty[t][0] * 100) if t in ty else "legendaries only"
        lines.append("| %s | %s | %s | %s | %s |" % (t.capitalize(), "I" if v.get("era", 1) == 1 else "II",
            ", ".join(x.capitalize() for x in v["strong"] if t not in types[x]["strong"]), ", ".join(x.capitalize() for x in weak), wr))
    rates = [r for r, _, _ in sp.values()]
    lines += ["", "Species: %d measured, lowest %.1f %%, highest %.1f %%." % (len(sp), min(rates) * 100, max(rates) * 100), "",
        "| Species | Stage | Win rate | Games |", "| --- | --- | --- | --- |"]
    for n, (r, g, st) in sorted(sp.items(), key=lambda kv: (kv[1][2], -kv[1][0])):
        lines.append("| %s | %d | %.1f %% | %d |" % (n, st + 1, r * 100, g))
    lines += ["", "Chart problems: %s" % ("none" if not problems else "; ".join(problems))]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md")
    ap.add_argument("--strict", action="store_true", help="fail on the win-rate band too")
    args = ap.parse_args()
    chart, species = load("type_chart.json"), load("spirlings.json")
    moves = {m["name"]: m for m in load("moves.json")}
    problems, mult = chart_problems(chart, species)
    sp, ty = simulate(species, moves, mult)
    lo, hi = BAND
    band = []
    for n, (r, _, _) in sp.items():
        if not lo <= r <= hi:
            band.append("species %s at %.1f %%" % (n, r * 100))
    for e, (r, _) in ty.items():
        if not lo <= r <= hi:
            band.append("element %s at %.1f %%" % (e, r * 100))
    chart_lines, chart_misses = chart_report(chart, mult)
    problems += chart_misses
    text = report(chart, sp, ty, problems) + "\nOutside the band: %s" % ("none" if not band else "; ".join(band))
    text += "\n\n" + "\n".join(chart_lines)
    print(text)
    if args.md:
        with open(args.md, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    if args.strict:
        problems += band
    if problems:
        print("FAIL: %d problem(s)" % len(problems), file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
