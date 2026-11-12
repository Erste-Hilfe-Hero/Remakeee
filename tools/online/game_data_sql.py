#!/usr/bin/env python3
"""Prints SQL that fills public.game_species from data/spirlings.json (plan area 7, leagues) and
public.known_ids (species, moves and items from the same folder, anti-cheat item 2922).

The server needs the species list and learnsets to rebuild fair league teams. It is filled at
every deploy (server/setup.sh) and before the SQL tests (tools/online/test_sql.sh), so new
Spirlings and moves from other areas reach the server without a new migration.
Usage: tools/online/game_data_sql.py [path/to/spirlings.json] | psql ...
"""
import json
import os
import sys


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else "data/spirlings.json"
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    earlier = {}
    # Like Database.earlier_form: the first species (in file order) that unfolds into it.
    for s in raw:
        paths = s.get("unfold") if isinstance(s.get("unfold"), list) else (
            [{"to": s["evolves_to"]}] if s.get("evolves_to") else [])
        for p in paths:
            if isinstance(p, dict) and p.get("to"):
                earlier.setdefault(p["to"], s["name"])
    rows = []
    for s in raw:
        learn = []
        for lvl in sorted(s.get("learnset", {}), key=int):
            entry = s["learnset"][lvl]
            for mv in entry if isinstance(entry, list) else [entry]:
                learn.append([int(lvl), mv])
        rows.append({"name": s["name"], "learn": learn, "earlier": earlier.get(s["name"])})
    data = json.dumps(rows).replace("$game$", "")
    print("begin;")
    print("insert into public.game_species (name, learn, earlier)")
    print("select x->>'name', x->'learn', x->>'earlier' from jsonb_array_elements($game$" + data + "$game$::jsonb) x")
    print("on conflict (name) do update set learn = excluded.learn, earlier = excluded.earlier;")
    print("delete from public.game_species where name not in (select x->>'name' from jsonb_array_elements($game$"
          + data + "$game$::jsonb) x);")
    folder = os.path.dirname(os.path.abspath(path))
    known = [{"kind": "species", "id": s["name"]} for s in raw]
    for kind, name, key in (("move", "moves.json", "name"), ("item", "items.json", "id")):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                known += [{"kind": kind, "id": str(x[key])} for x in json.load(f) if isinstance(x, dict) and key in x]
    # Rift ids for the weekly Rift board (online step 1): every "warden" in the maps and data files.
    rifts = set()

    def wardens(x):
        if isinstance(x, dict):
            for k, v in x.items():
                if k == "warden" and isinstance(v, str) and v:
                    rifts.add(v)
                else:
                    wardens(v)
        elif isinstance(x, list):
            for v in x:
                wardens(v)
    for root, _dirs, files in os.walk(folder):
        if os.sep + "i18n" in root:
            continue
        for name in files:
            if name.endswith(".json"):
                with open(os.path.join(root, name), encoding="utf-8") as f:
                    try:
                        wardens(json.load(f))
                    except ValueError:
                        pass
    known += [{"kind": "rift", "id": r} for r in sorted(rifts)]
    ids = json.dumps(known).replace("$game$", "")
    print("delete from public.known_ids;")
    print("insert into public.known_ids (kind, id) select x->>'kind', x->>'id' from jsonb_array_elements($game$"
          + ids + "$game$::jsonb) x on conflict do nothing;")
    # Trading (plan area 7, item 2792): only items with "tradeable": true in data/items.json.
    items_path = os.path.join(folder, "items.json")
    if os.path.exists(items_path):
        with open(items_path, encoding="utf-8") as f:
            trade = [str(x["id"]) for x in json.load(f) if isinstance(x, dict) and x.get("tradeable") is True]
        print("insert into public.server_config (key, value) values ('trade_items', $game$"
              + json.dumps(trade).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # League ranks (Online 100, points 12-13, 16-20): data/league_ranks.json as server_config.league_ranks.
    ranks_path = os.path.join(folder, "league_ranks.json")
    if os.path.exists(ranks_path):
        with open(ranks_path, encoding="utf-8") as f:
            ranks = json.load(f)
        ranks.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('league_ranks', $game$"
              + json.dumps(ranks).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # Bund extras (Online 100, area 4): data/bund_rules.json as server_config.bund_rules.
    br_path = os.path.join(folder, "bund_rules.json")
    if os.path.exists(br_path):
        with open(br_path, encoding="utf-8") as f:
            br = json.load(f)
        br.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('bund_rules', $game$"
              + json.dumps(br).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # Raid extras (Online 100, area 3): data/raid_rules.json as server_config.raid_rules.
    rr_path = os.path.join(folder, "raid_rules.json")
    if os.path.exists(rr_path):
        with open(rr_path, encoding="utf-8") as f:
            rr = json.load(f)
        rr.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('raid_rules', $game$"
              + json.dumps(rr).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # Live duels (Online 100, area 1): data/live_duel.json as server_config.live_duel.
    live_path = os.path.join(folder, "live_duel.json")
    if os.path.exists(live_path):
        with open(live_path, encoding="utf-8") as f:
            live = json.load(f)
        live.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('live_duel', $game$"
              + json.dumps(live).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # Trading and gifting (Online 100, area 5): data/trade_gifts.json as server_config.trade_gifts.
    tg_path = os.path.join(folder, "trade_gifts.json")
    if os.path.exists(tg_path):
        with open(tg_path, encoding="utf-8") as f:
            tg = json.load(f)
        tg.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('trade_gifts', $game$"
              + json.dumps(tg).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    # Online events (Online 100, area 7): data/online_events.json as server_config.online_events,
    # each fixed event as a row of public.online_events (its shared total stays). Rules become the
    # list of species that fit them (like OnlineEvents.allowed in the game).
    events_path = os.path.join(folder, "online_events.json")
    if os.path.exists(events_path):
        with open(events_path, encoding="utf-8") as f:
            ev = json.load(f)
        ev.pop("_comment", None)
        fixed = ev.pop("events", [])
        for t in ev.get("weekly", []) + fixed:
            if isinstance(t.get("rules"), dict):
                t["allowed"] = allowed_species(raw, earlier, t["rules"])
        print("insert into public.server_config (key, value) values ('online_events', $game$"
              + json.dumps(ev).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
        for x in fixed:
            body = {k: v for k, v in x.items() if k not in ("id", "kind", "starts", "ends")}
            print("insert into public.online_events (id, kind, starts_at, ends_at, data) values ("
                  + ", ".join("$game$" + str(v).replace("$game$", "") + "$game$" for v in (x["id"], x["kind"], x["starts"], x["ends"]))
                  + ", $game$" + json.dumps(body).replace("$game$", "") + "$game$::jsonb)"
                  " on conflict (id) do update set kind = excluded.kind, starts_at = excluded.starts_at,"
                  " ends_at = excluded.ends_at, data = excluded.data;")
    # Friends and the shared world (Online 100, area 6): data/friends_more.json as server_config.friends_more.
    fm_path = os.path.join(folder, "friends_more.json")
    if os.path.exists(fm_path):
        with open(fm_path, encoding="utf-8") as f:
            fm = json.load(f)
        fm.pop("_comment", None)
        print("insert into public.server_config (key, value) values ('friends_more', $game$"
              + json.dumps(fm).replace("$game$", "") + "$game$::jsonb)"
              " on conflict (key) do update set value = excluded.value;")
    print("commit;")


def allowed_species(raw, earlier, rules):
    """Species names that fit event rules: any of "elements" (when given) and at most "max_stage"
    (1 = a first form) steps along its unfold line."""
    def stage(name):
        n = 1
        while earlier.get(name) and n < 10:
            name = earlier[name]
            n += 1
        return n
    out = []
    for s in raw:
        els = rules.get("elements")
        if els and not any(e in els for e in s.get("elements", [])):
            continue
        if rules.get("max_stage") and stage(s["name"]) > int(rules["max_stage"]):
            continue
        out.append(s["name"])
    return out


if __name__ == "__main__":
    main()
