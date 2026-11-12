#!/usr/bin/env python3
"""Cross-file data integrity check over the whole game data (plain Python, runs without Godot).

The GDScript validators (tools/validate_data.gd) check each system on its own; this one checks
the references between files that many parallel content PRs touch at once:

  json       no duplicate keys in any data JSON object (the last one silently wins)
  warps      every warp / ladder / drop / warp action / transit stop targets an existing map
             and a walkable cell inside it
  reach      every map in data/world_layout.json is reachable from the start (lighthouse)
  dialogue   every dialogue reference ("file/key") used by maps, story figures, scenes, clans,
             story battles, ... exists, and its lines have a German translation
  names      every NPC trainer name / display name has a German translation
  flags      every flag that is checked somewhere is set somewhere (errors); flags that are
             set but never checked are listed as notes (they are often plain records)
  species    every encounter table, Wayfarer / story / event team and gift names an existing
             Spirling; every level is 1..Spirling.MAX_LEVEL
  items      every item id referenced in maps, dialogue actions, conditions, scenes and clans
             exists in data/items.json
  ids        no duplicate ids inside clans.json sections, story battles, quests, items; no
             figure id used by an NPC who is a different figure (e.g. "pell" vs "old_pell")

Usage: python3 tools/data_integrity.py [--notes]   (exit 1 on any error)
"""
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
START_MAP = "lighthouse"

# Tile characters the player cannot stand on (TilesetFactory.SOLID; unknown characters are grass).
SOLID = set("~THR#SCWo^|L@wBvY")

errors = []
notes = []

# Known and accepted for now; printed on every run so they are not forgotten.
KNOWN = {
    # Era III's region (not merged yet) adds eras.json finale_flags["era3_finale_done"].
    "flag 'era3_finale_done' is checked": "set by the Era III region once it lands (eras.json _doc)",
}


def err(kind, msg):
    for k, why in KNOWN.items():
        if k in msg:
            notes.append(("known", "%s -- %s" % (msg, why)))
            return
    errors.append((kind, msg))


def note(kind, msg):
    notes.append((kind, msg))


def _no_dupes(pairs, path):
    seen = {}
    for k, v in pairs:
        if k in seen:
            err("json", "%s: duplicate key '%s'" % (path, k))
        seen[k] = v
    return seen


def load(path):
    full = os.path.join(ROOT, path)
    with open(full, encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=lambda p: _no_dupes(p, path))


def walk(v, fn, path=()):
    """Calls fn(dict, path) for every dict inside v."""
    if isinstance(v, dict):
        fn(v, path)
        for k, x in v.items():
            walk(x, fn, path + (k,))
    elif isinstance(v, list):
        for x in v:
            walk(x, fn, path)


def as_list(v):
    return v if isinstance(v, list) else [v]


# ---------------------------------------------------------------- loading

def gd_const(path, name):
    m = re.search(r"const %s\s*:\s*\w+\s*=\s*(\d+)" % name, open(os.path.join(ROOT, path)).read())
    return int(m.group(1))


MAX_LEVEL = gd_const("scripts/battle/Spirling.gd", "MAX_LEVEL")
# Post-game regions past Era III grow past 60 (data/eras.json ring_caps); Halcyra's maps, tables
# and sheet are checked against the hard clamp Spirling.ERA_MAX_LEVEL instead.
ERA_MAX_LEVEL = gd_const("scripts/battle/Spirling.gd", "ERA_MAX_LEVEL")
ERA_REGIONS = {"halcyra"}

json_files = []
for dp, _, fs in os.walk(DATA):
    if "/i18n" in dp.replace(os.sep, "/"):
        continue
    for f in sorted(fs):
        if f.endswith(".json"):
            json_files.append(os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/"))
json_files.sort()
J = {}
for p in json_files:
    try:
        J[p] = load(p)
    except ValueError as e:
        err("json", "%s: %s" % (p, e))

species = {s["name"] for s in J["data/spirlings.json"] if isinstance(s, dict) and "name" in s}
items_raw = J["data/items.json"]
item_ids = [it.get("id") for it in items_raw if isinstance(it, dict)]
items = set(item_ids)
dialogue = {p[len("data/dialogue/"):-5]: d for p, d in J.items() if p.startswith("data/dialogue/")}
scenes = {p[len("data/scenes/"):-5]: d for p, d in J.items() if p.startswith("data/scenes/")}
map_files = {p[len("data/maps/"):-5]: d for p, d in J.items() if p.startswith("data/maps/")}
layout = J["data/world_layout.json"]
story_npcs = J["data/story_npcs.json"]
clans = J["data/clans.json"]
story_battles = J["data/story_battles.json"]

# Map id -> level dict (floors "file@n" inherit nothing we need except rows/warps of their own).
maps = {}
for mid, raw in map_files.items():
    maps[mid] = raw
    for i, fl in enumerate(raw.get("floors", []) or []):
        if isinstance(fl, dict):
            maps["%s@%d" % (mid, i + 1)] = fl


def map_npcs(mid):
    """NPCs of a map level plus the story figures placed on it (story_npcs.json)."""
    out = list(maps[mid].get("npcs", []) or [])
    if "@" not in mid:
        out += (story_npcs.get(mid) or {}).get("npcs", []) if isinstance(story_npcs.get(mid), dict) else []
    return out


def map_signs(mid):
    out = list(maps[mid].get("signs", []) or [])
    if "@" not in mid and isinstance(story_npcs.get(mid), dict):
        out += story_npcs[mid].get("signs", []) or []
    return out


def walkable(mid, x, y):
    m = maps.get(mid)
    if m is None:
        return "no such map"
    rows = m.get("rows")
    if not rows:
        return None  # generated rooms (Echo Path "slot") have no rows in the file
    if not (0 <= y < len(rows) and 0 <= x < len(rows[y])):
        return "outside the map"
    ch = rows[y][x]
    if ch in SOLID:
        return "blocked tile '%s'" % ch
    return None


# ---------------------------------------------------------------- warps and reachability

links = defaultdict(set)


def check_target(where, to, x, y):
    if to not in maps:
        err("warps", "%s: target map '%s' does not exist" % (where, to))
        return False
    if x is None or y is None:
        return True
    why = walkable(to, int(x), int(y))
    if why:
        err("warps", "%s: target %s,%s on '%s' is not walkable (%s)" % (where, x, y, to, why))
    return True


for mid, m in maps.items():
    for w in m.get("warps", []) or []:
        to = str(w.get("to", ""))
        if check_target("map '%s' warp at %s,%s" % (mid, w.get("x"), w.get("y")), to, w.get("tx"), w.get("ty")):
            links[mid].add(to)
    for ld in m.get("ladders", []) or []:
        to = str(ld.get("to", ""))
        at = ld.get("at") or [ld.get("x"), ld.get("y")]
        if to and check_target("map '%s' ladder at %s" % (mid, at), to, None, None):
            links[mid].add(to)
    if "slot" in m:
        # Echo Path rooms are built at run time with stairs up and down (EchoPath.build_room).
        base, n = mid.split("@")
        n = int(n)
        links[mid].add("%s@%d" % (base, n + 1))
        links[mid].add(base if n == 1 else "%s@%d" % (base, n - 1))
    if m.get("drop_to"):
        if check_target("map '%s' drop_to" % mid, str(m["drop_to"]), None, None):
            links[mid].add(str(m["drop_to"]))

for lid, line in (layout.get("lines") or {}).items():
    stops = line.get("stops", {})
    for sid, cell in stops.items():
        if check_target("line '%s' stop" % lid, sid, cell[0], cell[1]):
            for other in stops:
                if other != sid:
                    links[sid].add(other)

# Dialogue refs used on each map, so a "warp" action in them links that map onward.
REF_KEYS = ("dialogue", "intro", "defeat", "lose", "win", "say", "ref", "at", "talk", "after", "before",
            "on_win", "on_lose", "offer", "done_dialogue", "wait")
ref_maps = defaultdict(set)
for mid in maps:
    for n in map_npcs(mid) + map_signs(mid) + (maps[mid].get("secrets", []) or []):
        for k in ("dialogue", "intro", "defeat"):
            if isinstance(n.get(k), str):
                ref_maps[n[k]].add(mid)


def actions_of(entry):
    out = []
    if isinstance(entry, dict):
        if isinstance(entry.get("action"), str):
            out += [a.strip() for a in entry["action"].split(";") if a.strip()]
        for c in entry.get("choices", []) or []:
            if isinstance(c, dict) and isinstance(c.get("action"), str):
                out += [a.strip() for a in c["action"].split(";") if a.strip()]
    return out


def resolve(file, target):
    return target if "/" in target else "%s/%s" % (file, target)


# Follow "next"/"else"/choice next so a warp deep in a talk still counts for the map.
def reachable_refs(ref, seen=None):
    seen = seen if seen is not None else set()
    if ref in seen or "/" not in ref:
        return seen
    seen.add(ref)
    f, k = ref.split("/", 1)
    e = dialogue.get(f, {}).get(k)
    if isinstance(e, dict):
        for t in [e.get("next"), e.get("else")] + [c.get("next") for c in e.get("choices", []) or [] if isinstance(c, dict)]:
            if isinstance(t, str) and t:
                reachable_refs(resolve(f, t), seen)
    return seen


for ref, mids in list(ref_maps.items()):
    for r in reachable_refs(ref):
        f, k = r.split("/", 1)
        for a in actions_of(dialogue.get(f, {}).get(k)):
            p = a.split()
            if p[0] == "warp" and len(p) >= 2:
                for mid in mids:
                    links[mid].add(p[1])

for f, d in dialogue.items():
    for k, e in d.items():
        for a in actions_of(e):
            p = a.split()
            if p[0] == "warp":
                if len(p) < 4:
                    err("warps", "dialogue %s/%s: '%s' needs map x y" % (f, k, a))
                else:
                    check_target("dialogue %s/%s warp" % (f, k), p[1], p[2], p[3])

seen = {START_MAP}
queue = [START_MAP]
while queue:
    cur = queue.pop()
    for to in links.get(cur, ()):
        if to not in seen:
            seen.add(to)
            queue.append(to)
for mid in sorted((layout.get("maps") or {}).keys()):
    if mid not in maps:
        err("reach", "world_layout: '%s' has no map file" % mid)
    elif mid not in seen:
        err("reach", "map '%s' (world_layout) cannot be reached from '%s'" % (mid, START_MAP))
for mid in sorted(maps):
    if mid in seen or mid in (layout.get("maps") or {}) or "slot" in maps[mid]:
        continue  # Echo Path rooms ("slot") are built from this week's template at run time
    err("reach", "map '%s' cannot be reached from '%s'" % (mid, START_MAP))

# ---------------------------------------------------------------- dialogue references and German

def ref_ok(where, ref):
    if not isinstance(ref, str) or "/" not in ref:
        return
    f, k = ref.split("/", 1)
    if f not in dialogue:
        err("dialogue", "%s: dialogue file '%s' does not exist (ref '%s')" % (where, f, ref))
    elif k not in dialogue[f]:
        err("dialogue", "%s: dialogue key '%s' does not exist" % (where, ref))


used_refs = set()
for mid in maps:
    for n in map_npcs(mid) + map_signs(mid) + (maps[mid].get("secrets", []) or []) + (maps[mid].get("passages", []) or []):
        for k in ("dialogue", "intro", "defeat", "lose_dialogue", "win_dialogue"):
            if isinstance(n.get(k), str) and "/" in n[k]:
                ref_ok("map '%s' %s '%s'" % (mid, k, n.get("id", "")), n[k])
                used_refs.add(n[k])
for f, d in dialogue.items():
    for k, e in d.items():
        if not isinstance(e, dict):
            continue
        for t in [e.get("next"), e.get("else")] + [c.get("next") for c in e.get("choices", []) or [] if isinstance(c, dict)]:
            if isinstance(t, str) and t:
                ref_ok("dialogue %s/%s next/else" % (f, k), resolve(f, t))
for sid, sc in scenes.items():
    for st in sc.get("steps", []) or []:
        if isinstance(st, dict) and isinstance(st.get("dialogue"), str):
            ref_ok("scene '%s'" % sid, st["dialogue"])
            used_refs.add(st["dialogue"])


def clan_refs(d, path):
    for k in ("say", "ref", "at"):
        if isinstance(d.get(k), str) and "/" in d[k]:
            ref_ok("clans.json %s" % "/".join(path), d[k])
            used_refs.add(d[k])


walk(clans, clan_refs)

# Any other "file/key" string in the data that names a dialogue file must name a key in it too.
REF_RE = re.compile(r"^([a-z0-9_]+)/([a-z0-9_]+)$")


def any_refs(v, where):
    if isinstance(v, str):
        m = REF_RE.match(v)
        if m and m.group(1) in dialogue:
            ref_ok(where, v)
            used_refs.add(v)
    elif isinstance(v, list):
        for x in v:
            any_refs(x, where)
    elif isinstance(v, dict):
        for k, x in v.items():
            any_refs(x, where)


for p, d in J.items():
    if not p.startswith(("data/dialogue/", "data/i18n/")):
        any_refs(d, p[5:])
for bid, b in story_battles.items():
    if isinstance(b, dict):
        for k in ("intro", "defeat", "lose", "win"):
            if isinstance(b.get(k), str) and "/" in b[k]:
                ref_ok("story battle '%s' %s" % (bid, k), b[k])
                used_refs.add(b[k])

# German table (tools/i18n_extract.py rules: plain strings, keep list, %s / %d patterns).
de_table, de_keep = {}, set()
ddir = os.path.join(DATA, "i18n", "de")
for f in sorted(os.listdir(ddir)):
    if f.endswith(".json"):
        part = json.load(open(os.path.join(ddir, f), encoding="utf-8"))
        de_table.update(part.get("strings", {}))
        de_keep.update(part.get("keep", []))
de_pats = [re.compile("^" + re.escape(k).replace("%%", "%").replace("%s", "(.+?)").replace("%d", r"(-?\d+)") + "$")
           for k in de_table if "%s" in k or "%d" in k]


def de_known(s):
    if s in de_table or s in de_keep or any(p.match(s) for p in de_pats):
        return True
    return "\n" in s and all(not x.strip() or de_known(x) for x in s.split("\n"))


def entry_texts(e):
    if isinstance(e, list):
        return [x for x in e if isinstance(x, str)]
    if not isinstance(e, dict):
        return []
    out = list(e.get("lines", []) or []) + list(e.get("night_lines", []) or [])
    for day in e.get("daily", []) or []:
        out += day if isinstance(day, list) else []
    for alt in as_list(e.get("after_flag")):
        if isinstance(alt, dict):
            out += alt.get("lines", []) or []
    for c in e.get("choices", []) or []:
        if isinstance(c, dict) and isinstance(c.get("text"), str):
            out.append(c["text"])
    return [x for x in out if isinstance(x, str)]


for ref in sorted(used_refs):
    f, k = ref.split("/", 1)
    e = dialogue.get(f, {}).get(k)
    for s in entry_texts(e):
        if s and not de_known(s):
            err("dialogue", "%s: no German text for %r" % (ref, s[:70]))
            break

for mid in maps:
    for n in map_npcs(mid):
        for k in ("trainer", "name"):
            s = n.get(k)
            if isinstance(s, str) and s and not de_known(s):
                err("names", "map '%s' npc '%s': %s %r has no German text" % (mid, n.get("id", ""), k, s))

# ---------------------------------------------------------------- items

def item_ok(where, iid):
    if isinstance(iid, str) and iid and iid not in items:
        err("items", "%s: unknown item '%s'" % (where, iid))


for mid in maps:
    m = maps[mid]
    for sc in m.get("secrets", []) or []:
        item_ok("map '%s' hidden find %s,%s" % (mid, sc.get("x"), sc.get("y")), sc.get("item"))
    for g in m.get("gear_spots", []) or []:
        for gid in as_list(g.get("gear")):
            item_ok("map '%s' gear spot" % mid, gid)
    for n in map_npcs(mid):
        item_ok("map '%s' npc '%s' held" % (mid, n.get("id", "")), n.get("held"))
        for t in as_list(n.get("team", [])) if isinstance(n.get("team"), list) else []:
            if isinstance(t, dict):
                item_ok("map '%s' npc '%s' team held" % (mid, n.get("id", "")), t.get("held"))

COND_ITEM = ("has_item",)
for f, d in dialogue.items():
    for k, e in d.items():
        for a in actions_of(e):
            p = a.split()
            if p[0] in ("give_item", "take_item") and len(p) > 1:
                item_ok("dialogue %s/%s %s" % (f, k, p[0]), p[1])
            if p[0] == "quest_show" and len(p) > 3:
                item_ok("dialogue %s/%s quest_show" % (f, k), p[3])

        def conds(dd, path, f=f, k=k):
            if "has_item" in dd and path and path[-1] == "if":
                for it in as_list(dd["has_item"]):
                    item_ok("dialogue %s/%s has_item" % (f, k), it)
        walk(e, conds)
for sid, sc in scenes.items():
    for st in sc.get("steps", []) or []:
        if isinstance(st, dict):
            item_ok("scene '%s' give_item" % sid, st.get("give_item"))


def clan_items(d, path):
    if "item" in d and isinstance(d["item"], str):
        item_ok("clans.json %s" % "/".join(path), d["item"])


walk(clans, clan_items)
for p in ("data/endgame.json", "data/events.json", "data/warden_rematch.json", "data/region2.json",
          "data/league_ranks.json", "data/burrow.json", "data/legend_quests.json", "data/story_battles.json"):
    if p not in J:
        continue

    def generic_items(d, path, p=p):
        for k in ("item", "held", "keepsake", "reward_item"):
            if isinstance(d.get(k), str):
                item_ok("%s %s" % (p[5:], "/".join(str(x) for x in path)), d[k])
    walk(J[p], generic_items)

# ---------------------------------------------------------------- species and levels

def level_ok(where, lv, era=False):
    if isinstance(lv, bool) or not isinstance(lv, (int, float)):
        return
    top = ERA_MAX_LEVEL if era else MAX_LEVEL
    if not 1 <= lv <= top:
        err("species", "%s: level %s outside 1..%d (Spirling.%s)" % (where, lv, top, "ERA_MAX_LEVEL" if era else "MAX_LEVEL"))


def era_file(p):
    d = J.get(p)
    return p == "data/region4.json" or (p.startswith("data/maps/") and isinstance(d, dict) and d.get("region") in ERA_REGIONS)


def species_ok(where, sp):
    if isinstance(sp, str) and sp not in species:
        err("species", "%s: unknown species '%s'" % (where, sp))


for tid, t in J["data/encounters.json"].items():
    if not isinstance(t, dict):
        continue
    for s in t.get("spawns", []) or []:
        w = "encounter table '%s' %s" % (tid, s.get("species"))
        species_ok(w, s.get("species"))
        era = era_file("data/maps/%s.json" % tid)
        level_ok(w + " min", s.get("min"), era)
        level_ok(w + " max", s.get("max"), era)
        if isinstance(s.get("min"), int) and isinstance(s.get("max"), int) and s["min"] > s["max"]:
            err("species", "%s: min %d > max %d" % (w, s["min"], s["max"]))

# Any {"species": X, "level": L} anywhere outside the species and encounter files, plus string
# teams ("team": ["Name", ...]).
SKIP_SPECIES_FILES = {"data/spirlings.json", "data/encounters.json", "data/gleam_palettes.json",
                      "data/spirling_motion.json", "data/spirlog_lore.json"}
for p, d in J.items():
    if p in SKIP_SPECIES_FILES or p.startswith("data/dialogue/"):
        continue

    def team_fn(dd, path, p=p):
        where = "%s %s" % (p[5:], "/".join(str(x) for x in path[-3:]))
        if "species" in dd and isinstance(dd["species"], str):
            species_ok(where, dd["species"])
            level_ok(where + " '%s'" % dd["species"], dd.get("level"), era_file(p))
        for k in ("team", "giants"):
            if isinstance(dd.get(k), list):
                for x in dd[k]:
                    if isinstance(x, str):
                        species_ok(where + "/" + k, x)
        if "stand_in" in dd and isinstance(dd["stand_in"], str):
            species_ok(where + " stand_in", dd["stand_in"])
    walk(d, team_fn)

for f, d in dialogue.items():
    for k, e in d.items():
        for a in actions_of(e):
            p = a.split()
            if p[0] in ("gift_spirling", "first_voice", "legend") and len(p) > 1:
                species_ok("dialogue %s/%s %s" % (f, k, p[0]), p[1])
                if len(p) > 2 and p[2].isdigit():
                    level_ok("dialogue %s/%s %s" % (f, k, p[0]), int(p[2]))
            if p[0] == "quest_show" and len(p) > 2:
                species_ok("dialogue %s/%s quest_show" % (f, k), p[2])

# ---------------------------------------------------------------- flags

set_flags = defaultdict(set)     # flag -> where
check_flags = defaultdict(set)
set_patterns = []                # compiled regexes of flags code builds at run time


def story_beaten(bid):
    """StoryBattles.beaten_flag()."""
    b = story_battles.get(bid)
    return str(b.get("beaten_flag", "beat_story_%s" % bid)) if isinstance(b, dict) else "beat_story_%s" % bid


def S(flag, where):
    for f in as_list(flag):
        if isinstance(f, str) and f:
            set_flags[f].add(where)


def C(flag, where):
    for f in as_list(flag):
        if isinstance(f, str) and f:
            check_flags[f].add(where)


def conds_fn(where):
    def fn(d, path):
        if path and path[-1] == "if":
            C(d.get("flag"), where)
            C(d.get("not_flag"), where)
    return fn


def entry_flags(where, e):
    if not isinstance(e, dict):
        return
    S(e.get("flag"), where)
    if e.get("once"):
        C(e.get("flag"), where)
    for c in e.get("choices", []) or []:
        if isinstance(c, dict):
            S(c.get("flag"), where)
    for alt in as_list(e.get("after_flag")):
        if isinstance(alt, dict):
            C(alt.get("flag"), where)
    walk(e, conds_fn(where))
    for a in actions_of(e):
        action_flags(where, a)


def action_flags(where, a):
    p = a.split()
    verb, args = p[0], p[1:]
    if verb == "set_flag":
        S(args, where)
    elif verb in ("switch", "bell", "toggle", "lever", "echo_song") and args:
        S(args[0], where)
        C(args[0], where)
    elif verb == "page" and args:
        S(["page_%s" % args[0], "page_%s_read" % args[0], "pages_all", "pages_complete"], where)
    elif verb == "quest_show" and args:
        S(["q_%s_asked" % args[0], "q_%s_done" % args[0]], where)
    elif verb == "favor" and args:
        S("favor_" + args[0], where)
    elif verb == "betrayal" and args:
        S("betrayal_" + args[0], where)
    elif verb == "ledger" and args:
        S("ledger_" + args[0], where)
    elif verb == "battle" and args:
        S(story_beaten(args[0]), where)
    elif verb == "choose_starter":
        S("got_starter", where)
    elif verb == "scene" and args:
        S("scene_%s_seen" % args[0], where)


for f, d in dialogue.items():
    for k, e in d.items():
        entry_flags("dialogue %s/%s" % (f, k), e)
for sid, sc in scenes.items():
    S("scene_%s_seen" % sid, "scene " + sid)
    for st in sc.get("steps", []) or []:
        if isinstance(st, dict):
            S(st.get("flag"), "scene " + sid)
            if isinstance(st.get("action"), str):
                for a in st["action"].split(";"):
                    if a.strip():
                        action_flags("scene " + sid, a.strip())
            if isinstance(st.get("battle"), str):
                S(story_beaten(st["battle"]), "scene " + sid)


def npc_flags(where, n, mid):
    C(n.get("show_flag"), where)
    C(n.get("hide_flag"), where)
    S(n.get("win_flags"), where)
    if n.get("team") or n.get("teams_by_difficulty") or n.get("team_by_starter") or n.get("trainer"):
        S(n.get("beaten_flag") or "beat_%s_%s" % (mid, n.get("id", "tamer")), where)
    if n.get("warden"):
        S("rift_%s_sealed" % n["warden"], where)
    st = n.get("second_trial")
    if isinstance(st, dict):
        C(st.get("needs_flags"), where)
    walk(n, conds_fn(where))


for mid, m in maps.items():
    w = "map " + mid
    for n in map_npcs(mid):
        npc_flags(w + " npc " + str(n.get("id", "")), n, mid)
    for sg in map_signs(mid):
        C(sg.get("show_flag"), w)
        C(sg.get("hide_flag"), w)
    for sc in m.get("secrets", []) or []:
        S(sc.get("flag"), w)
        C(sc.get("flag"), w)
    for b in m.get("blocks", []) or []:
        if not str(b.get("open_flag", "")).startswith("_"):
            C(b.get("open_flag"), w)
    for key in ("puzzles", "passages"):
        for pz in m.get(key, []) or []:
            S(pz.get("flag"), w)
            C(pz.get("flag"), w)
    if isinstance(m.get("beam"), dict):
        S(m["beam"].get("flag"), w)
        C(m["beam"].get("flag"), w)  # WorldAtlas.banner counts solved rooms
for mid, pl in story_npcs.items():
    if isinstance(pl, dict):
        oe = pl.get("on_enter")
        for e in as_list(oe):
            if isinstance(e, dict):
                walk(e, conds_fn("story_npcs " + mid))
                if isinstance(e.get("scene"), str):
                    S("scene_%s_seen" % e["scene"], "story_npcs " + mid)
for bid, b in story_battles.items():
    if isinstance(b, dict):
        S(story_beaten(bid), "story battle " + bid)
        S(b.get("win_flags"), "story battle " + bid)


def clan_flags(d, path):
    S(d.get("flags"), "clans " + "/".join(path))
    C(d.get("warned_by"), "clans " + "/".join(path))
    for k in ("ledger",):
        if isinstance(d.get(k), str) and path and path[-1] in ("caught", "struck", "betray", "kept", "reward"):
            S("ledger_" + d[k], "clans " + "/".join(path))


walk(clans, clan_flags)
for fid in (clans.get("favors") or {}):
    S("favor_" + fid, "clans favors")
for bid in (clans.get("betrayals") or {}):
    S("betrayal_" + bid, "clans betrayals")
for e in clans.get("ledger", []) or []:
    if isinstance(e, dict):
        C("ledger_" + str(e.get("id")), "clans ledger")

q = J["data/quests.json"]
for g in q.get("main", []):
    C(g.get("done"), "quest main " + str(g.get("id")))
for g in q.get("side", []):
    C([g.get("show"), g.get("done")] + list(g.get("progress", []) or []), "quest side " + str(g.get("id")))

for p in ("data/region2.json", "data/region4.json"):
    r = J.get(p)
    if not isinstance(r, dict):
        continue
    C(r.get("unlock_flag"), p)
    S(r.get("finale_flag"), p)
    for c in r.get("story", []) or []:
        C(c.get("needs"), p)
        S(c.get("sets"), p)
    for rf in r.get("rifts", []) or []:
        S(rf.get("flag"), p)
eras = J.get("data/eras.json", {})
for era, fl in (eras.get("unlock_flags") or {}).items():
    C(fl, "eras unlock " + era)
for era_flag, content_flag in (eras.get("finale_flags") or {}).items():
    S(era_flag, "eras finale")
    C(content_flag, "eras finale " + era_flag)
wr = J.get("data/warden_rematch.json", {})
if isinstance(wr, dict):
    C(wr.get("needs_flag"), "warden_rematch")
for t in (J.get("data/endgame.json", {}).get("rift_towers") or []):
    if isinstance(t, dict):
        C(t.get("open_flag"), "endgame rift_towers")
for lid, line in (layout.get("lines") or {}).items():
    C(line.get("open_flag"), "line " + lid)
for t in (J.get("data/burrow.json", {}).get("trophies") or []):
    if isinstance(t, dict):
        C(t.get("flag"), "burrow trophies")

# Code: literal set_flag / has_flag, FLAG constants, and flag-building helpers.
SET_LIT = re.compile(r'set_flag\(\s*"([A-Za-z0-9_]+)"')
HAS_LIT = re.compile(r'has_flag\(\s*"([A-Za-z0-9_]+)"')
SET_FMT = re.compile(r'set_flag\(\s*"([A-Za-z0-9_%]*%[sd][A-Za-z0-9_%]*)"')
SET_CAT = re.compile(r'set_flag\(\s*"([A-Za-z0-9_]+)"\s*\+')
CONST_FLAG = re.compile(r'const\s+\w*FLAG\w*\s*(?::\s*String\s*)?=\s*"([A-Za-z0-9_]+)"')
FLAG_FUNC = re.compile(r'func\s+\w*flag\w*\s*\([^)]*\)[^:]*:\s*\n?\s*return\s+(?:str\()?"([A-Za-z0-9_%]+)"')
FLAG_FUNC_CAT = re.compile(r'func\s+\w*flag\w*\s*\([^)]*\)[^:]*:\s*\n?\s*return\s+"([A-Za-z0-9_]+)"\s*\+')
for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
    for fn in fs:
        if not fn.endswith(".gd") or "Validator" in fn:
            continue
        src = open(os.path.join(dp, fn), encoding="utf-8").read()
        w = "scripts/" + fn
        for m in SET_LIT.finditer(src):
            S(m.group(1), w)
        for m in CONST_FLAG.finditer(src):
            S(m.group(1), w + " const")
        for m in HAS_LIT.finditer(src):
            C(m.group(1), w)
        for m in list(SET_FMT.finditer(src)) + list(FLAG_FUNC.finditer(src)):
            if "%" in m.group(1):
                set_patterns.append(re.compile("^" + re.escape(m.group(1)).replace("%s", ".+").replace("%d", r"\d+") + "$"))
        for m in list(SET_CAT.finditer(src)) + list(FLAG_FUNC_CAT.finditer(src)):
            set_patterns.append(re.compile("^" + re.escape(m.group(1)) + ".+$"))


def is_set(f):
    return f in set_flags or any(p.match(f) for p in set_patterns)


# Flags built from a name: the name must exist (FirstVoices, DungeonHints).
species_lower = {x.lower() for x in species}
for f in sorted(check_flags):
    m = re.match(r"^first_voice_(.+)_(away|bonded)$", f)
    if m and m.group(1) not in species_lower:
        err("flags", "flag '%s' (%s) names no Spirling" % (f, ", ".join(sorted(check_flags[f])[:2])))
    m = re.match(r"^hint_(.+)$", f)
    if m and m.group(1) not in map_files:
        err("flags", "flag '%s' (%s) names no map file" % (f, ", ".join(sorted(check_flags[f])[:2])))


for f in sorted(check_flags):
    if not is_set(f):
        err("flags", "flag '%s' is checked (%s) but never set" % (f, ", ".join(sorted(check_flags[f])[:3])))
code_checks = set()
for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
    for fn in fs:
        if fn.endswith(".gd"):
            code_checks.update(re.findall(r'"([a-z][a-z0-9_]+)"', open(os.path.join(dp, fn), encoding="utf-8").read()))
for f in sorted(set_flags):
    if f not in check_flags and f not in code_checks:
        note("flags", "flag '%s' is set (%s) but nothing checks it" % (f, ", ".join(sorted(set_flags[f])[:2])))

# ---------------------------------------------------------------- ids

def dupes(where, ids):
    seen = set()
    for i in ids:
        if i in seen:
            err("ids", "%s: duplicate id '%s'" % (where, i))
        seen.add(i)


dupes("items.json", item_ids)
dupes("quests.json main", [g.get("id") for g in q.get("main", [])])
dupes("quests.json side", [g.get("id") for g in q.get("side", [])])
dupes("clans.json ledger", [e.get("id") for e in clans.get("ledger", []) if isinstance(e, dict)])
dupes("clans.json favors+betrayals", list((clans.get("favors") or {}).keys()) + list((clans.get("betrayals") or {}).keys()))
dupes("spirlings.json", [s.get("name") for s in J["data/spirlings.json"] if isinstance(s, dict)])
for mid in maps:
    dupes("map '%s' npcs" % mid, [n.get("id") for n in map_npcs(mid) if n.get("id") and not n.get("show_flag") and not n.get("hide_flag")])

figures = clans.get("figures") or {}
for k in ("favors", "betrayals"):
    for xid, x in (clans.get(k) or {}).items():
        if isinstance(x, dict) and x.get("npc") not in figures:
            err("ids", "clans.json %s/%s: unknown figure '%s'" % (k, xid, x.get("npc")))


def trust_ids(d, path):
    for k in ("trust", "use"):
        if isinstance(d.get(k), dict):
            for fid in d[k]:
                if fid not in figures:
                    err("ids", "clans.json %s %s: unknown figure '%s'" % ("/".join(path), k, fid))


walk({k: v for k, v in clans.items() if k in ("favors", "betrayals", "trust_choices")}, trust_ids)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


# An NPC whose id is one figure but whose shown name is another figure ("pell" named "Old Pell"
# while "old_pell" is its own figure) mixes two people up.
for mid in maps:
    for n in map_npcs(mid):
        nid = str(n.get("id", ""))
        for k in ("trainer", "name"):
            s = n.get(k)
            if not isinstance(s, str):
                continue
            sl = slug(s)
            if nid in figures and sl in figures and sl != nid:
                err("ids", "map '%s' npc '%s' is shown as %r, which is figure '%s', not '%s'" % (mid, nid, s, sl, nid))

for f, d in dialogue.items():
    for k, e in d.items():
        def trust_cond(dd, path, f=f, k=k):
            if path and path[-1] == "if":
                for c in ("trust_min", "trust_max"):
                    for fid in (dd.get(c) or {}):
                        if fid not in figures:
                            err("ids", "dialogue %s/%s %s: unknown figure '%s'" % (f, k, c, fid))
        walk(e, trust_cond)
        for a in actions_of(e):
            p = a.split()
            if p[0] == "trust" and len(p) > 1 and p[1] not in figures:
                err("ids", "dialogue %s/%s trust: unknown figure '%s'" % (f, k, p[1]))
            if p[0] == "favor" and len(p) > 1 and p[1] not in (clans.get("favors") or {}):
                err("ids", "dialogue %s/%s favor: unknown favor '%s'" % (f, k, p[1]))
            if p[0] == "betrayal" and len(p) > 1 and p[1] not in (clans.get("betrayals") or {}):
                err("ids", "dialogue %s/%s betrayal: unknown betrayal '%s'" % (f, k, p[1]))
            if p[0] == "ledger" and len(p) > 1 and p[1] not in {e2.get("id") for e2 in clans.get("ledger", []) if isinstance(e2, dict)}:
                err("ids", "dialogue %s/%s ledger: unknown ledger entry '%s'" % (f, k, p[1]))
            if p[0] in ("battle",) and len(p) > 1 and p[1] not in story_battles:
                err("ids", "dialogue %s/%s battle: unknown story battle '%s'" % (f, k, p[1]))
            if p[0] == "scene" and len(p) > 1 and p[1] not in scenes:
                err("ids", "dialogue %s/%s scene: unknown scene '%s'" % (f, k, p[1]))

# ---------------------------------------------------------------- report

kinds = ["json", "warps", "reach", "dialogue", "names", "flags", "species", "items", "ids"]
by = defaultdict(list)
for k, m in errors:
    by[k].append(m)
for k in kinds:
    for m in by[k]:
        print("INTEGRITY ERROR [%s] %s" % (k, m))
for k, m in notes:
    if k == "known":
        print("known: %s" % m)
if "--notes" in sys.argv:
    for k, m in notes:
        if k == "known":
            continue
        print("note [%s] %s" % (k, m))
print("data integrity: %d errors (%s), %d notes (--notes lists them); %d maps, %d dialogue files, %d flags checked, %d flags set"
      % (len(errors), ", ".join("%s %d" % (k, len(by[k])) for k in kinds if by[k]) or "none", len(notes),
         len(maps), len(dialogue), len(check_flags), len(set_flags)))
sys.exit(1 if errors else 0)
