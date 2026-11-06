#!/usr/bin/env python3
"""Lists every player-facing English string that data/i18n/<lang>.json must translate.

Sources: dialogue and map JSON, quests, items, plus string literals in the UI and battle scripts
that look like text (a capital letter or a space). Prints missing keys as JSON so they can be
pasted into the language file. Usage: python3 tools/i18n_extract.py [lang] [--all | --check]
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_DIRS = ["scripts/ui", "scripts/overworld", "scripts/battle", "scripts/core", "scripts/online"]
SKIP_SCRIPTS = {"BalanceSim.gd", "BattleTest.gd", "DataValidator.gd", "StoryValidator.gd", "WorldValidator.gd", "PixelFont.gd", "Loc.gd", "PatternTranslation.gd"}
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')

def looks_like_text(s):
    if len(s) < 2 or not re.search(r"[A-Za-z]{2}", s):
        return False
    if re.match(r"(map|encounter table) '", s):
        return False
    if re.search(r"res://|user://|^ui_|^[a-z0-9_]+$|^[A-Z_0-9]+$|\.(gd|json|png|ogg|wav|tscn)$|^#|^%[0-9.]*[a-z]$", s):
        return False
    return s[0].isupper() or " " in s or s.startswith("%")

def walk_json(v, out):
    if isinstance(v, str):
        out.append(v)
    elif isinstance(v, list):
        for x in v:
            walk_json(x, out)
    elif isinstance(v, dict):
        for k, x in v.items():
            if k in ("lines", "after_flag") or isinstance(x, (list, dict)):
                walk_json(x, out) if k not in ("flag", "action") else None
            elif k in ("text",):
                walk_json(x, out)

def strings():
    found = []
    d = os.path.join(ROOT, "data/dialogue")
    for f in sorted(os.listdir(d)):
        data = json.load(open(os.path.join(d, f)))
        for key, v in data.items():
            if isinstance(v, list):
                found += v
            elif isinstance(v, dict):
                found += v.get("lines", [])
                af = v.get("after_flag")
                for alt in (af if isinstance(af, list) else [af]):
                    if isinstance(alt, dict):
                        found += alt.get("lines", [])
                for c in v.get("choices", []) or []:
                    if isinstance(c, dict) and isinstance(c.get("text"), str):
                        found.append(c["text"])
                if isinstance(v.get("speaker"), str) and "{" not in v["speaker"]:
                    found.append(v["speaker"])
                for k2 in ("text", "lose_lines", "win_lines", "before_lines", "after_lines"):
                    x = v.get(k2)
                    if isinstance(x, list):
                        found += x
                    elif isinstance(x, str):
                        found.append(x)
    sd = os.path.join(ROOT, "data/scenes")
    for f in sorted(os.listdir(sd)) if os.path.isdir(sd) else []:
        if not f.endswith(".json"):
            continue
        for step in json.load(open(os.path.join(sd, f))).get("steps", []):
            for k in ("say", "letter"):
                x = step.get(k)
                found += x if isinstance(x, list) else ([x] if isinstance(x, str) else [])
            for k in ("speaker", "card", "title"):
                if isinstance(step.get(k), str) and "{" not in step[k]:
                    found.append(step[k])
    quests = json.load(open(os.path.join(ROOT, "data/quests.json")))
    for group in quests.values():
        for q in group if isinstance(group, list) else []:
            for k in ("title", "act", "chapter", "text", "where", "hint"):
                if isinstance(q.get(k), str):
                    found.append(q[k])
    items = json.load(open(os.path.join(ROOT, "data/items.json")))
    for it in (items.values() if isinstance(items, dict) else items):
        for k in ("name", "desc", "description"):
            if isinstance(it.get(k), str):
                found.append(it[k])
    for f in sorted(os.listdir(os.path.join(ROOT, "data/maps"))):
        name = json.load(open(os.path.join(ROOT, "data/maps", f))).get("name")
        if isinstance(name, str):
            found.append(name)
    for sp in json.load(open(os.path.join(ROOT, "data/spirlings.json"))):
        for k in ("habitat", "lore", "origin"):
            if isinstance(sp.get(k), str) and sp[k]:
                found.append(sp[k])
    lore = os.path.join(ROOT, "data/spirlog_lore.json")
    if os.path.exists(lore):
        for k, v in json.load(open(lore)).items():
            if not k.startswith("_") and isinstance(v, str):
                found.append(v)
    ev = os.path.join(ROOT, "data/events.json")
    if os.path.exists(ev):
        for group in json.load(open(ev)).values():
            for t in group if isinstance(group, list) else []:
                for k in ("text", "name", "desc"):
                    if isinstance(t.get(k), str):
                        found.append(t[k])
    for sd in SCRIPT_DIRS:
        for dp, _, fs in os.walk(os.path.join(ROOT, sd)):
            for f in sorted(fs):
                if not f.endswith(".gd") or f in SKIP_SCRIPTS:
                    continue
                for line in open(os.path.join(dp, f)):
                    code = line.split("##")[0]
                    if code.strip().startswith("#") or "push_error" in code or "push_warning" in code or "print(" in code:
                        continue
                    for m in LIT.finditer(code):
                        s = m.group(1).encode().decode("unicode_escape") if "\\" in m.group(1) else m.group(1)
                        if looks_like_text(s):
                            found.append(s)
    seen, out = set(), []
    for s in found:
        if s and s not in seen:
            seen.add(s); out.append(s)
    return out

if __name__ == "__main__":
    lang = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "de"
    path = os.path.join(ROOT, "data/i18n/%s.json" % lang)
    have = json.load(open(path)) if os.path.exists(path) else {}
    keep = set(have.get("keep", []))
    table = have.get("strings", {})
    pats = [re.compile("^" + re.escape(k).replace("%%", "%").replace("%s", "(.+?)").replace("%d", r"(-?\d+)") + "$")
            for k in table if "%s" in k or "%d" in k]
    def known(s):
        if s in table or s in keep or any(p.match(s) for p in pats):
            return True
        return "\n" in s and all(not x.strip() or known(x) for x in s.split("\n"))
    todo = [s for s in strings() if "--all" in sys.argv or not known(s)]
    if "--check" in sys.argv:
        if todo:
            sys.exit("Untranslated (%s): %s" % (lang, json.dumps(todo, ensure_ascii=False)))
        print("i18n %s OK" % lang)
    else:
        print(json.dumps({s: "" for s in todo}, ensure_ascii=False, indent=1))
