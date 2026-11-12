#!/usr/bin/env python3
"""Rooms behind the town doors that led nowhere (map audit: dead doors, healer and shop emblem
doors with no warp). One room per door, built from one template per room kind and act, so every
act's rooms look alike and match its other interiors (Act I: 10x8 like the Rest Spring, Acts II
and III: 10x9 like the Guild House and Gravers' Hall; huts 8x6).

Writes data/maps/<room>.json, data/dialogue/rooms.json, tools/i18n/de_rooms.py, the "inside"
places in data/world_layout.json, and the door warp on the town map (replaced in place, so the
script is safe to run again). Room ids keep the door emblems: "spring" rooms heal, "shop" rooms
sell (MapData.door_roles reads the warp target).
Usage: python3 tools/art/gen_rooms.py && python3 tools/i18n/build.py
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

TEMPLATES = {
    ("spring", 8): ["WWWWWWWWWW", "WfffoofffW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WWWWDWWWWW"],
    ("shop", 8): ["WWWWWWWWWW", "WCCCffCCCW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WffffffffW", "WffffffffW", "WWWWDWWWWW"],
    ("house", 8): ["WWWWWWWWWW", "WCCffffCCW", "WffffffffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WffffffffW", "WWWWDWWWWW"],
    ("spring", 9): ["WWWWWWWWWW", "WfffoofffW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WWWWDWWWWW"],
    ("shop", 9): ["WWWWWWWWWW", "WCCCffCCCW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WWWWDWWWWW"],
    ("house", 9): ["WWWWWWWWWW", "WCCffffCCW", "WffffffffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WffffffffW", "WffffffffW", "WWWWDWWWWW"],
    ("hut", 6): ["WWWWWWWW", "WCCffCCW", "WffffffW", "WffffffW", "WffffffW", "WWWDWWWW"],
}
# Act I rooms are 8 rows, later acts 9 (their existing interiors are 10x9).
ROWS = {"veydal": 8, "corvane": 9, "ashmere": 9}
BACKDROP = {"veydal": "field", "corvane": "field", "ashmere": "ember"}

SHOP_COPPER = "shop tonic strong_tonic max_tonic remedy cooling_gel wake_bell spark_drop revival_leaf dash_brew guard_brew"
SHOP_REED = "shop tonic strong_tonic max_tonic remedy dry_towel wake_bell revival_leaf kin_charm"
SHOP_WREN = "shop tonic strong_tonic remedy dry_towel cooling_gel kin_charm revival_leaf"
SHOP_CORVANE = "shop tonic strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"

# room id: town, door cell, kind, (English name, German name), person (id, sprite, lines as
# (English, German) pairs, action or "").
ROOMS = {
    "copperfold_spring": ("copperfold", (3, 4), "spring", ("Copperfold Spring House", "Quellhaus Kupferfalt"),
        ("hedda", "elder", [("Seam Nurse Hedda: Warm water from the deep seams. Let your team soak.",
                             "Flöznärrin Hedda: Warmes Wasser aus den tiefen Flözen. Lass dein Team baden."),
                            ("Seam Nurse Hedda: Miners come in grey and leave pink. The ones who come in at all.",
                             "Flöznärrin Hedda: Die Kumpel kommen grau rein und gehen rosa raus. Die, die überhaupt reinkommen.")], "heal")),
    "copperfold_shop": ("copperfold", (9, 4), "shop", ("Copperfold Store", "Laden Kupferfalt"),
        ("benno", "villager", [("Clerk Benno: Wilma sells outside, I sell inside. Same prices, but I have a roof.",
                                "Verkäufer Benno: Wilma verkauft draußen, ich drinnen. Gleiche Preise, aber ich hab ein Dach.")], SHOP_COPPER)),
    "copperfold_house": ("copperfold", (3, 12), "house", ("Fenwick's House", "Fenwicks Haus"),
        ("fenwick", "elder", [("Old Fenwick: My boy went down the Shatterfloor for copper. The mine kept him and sent back his boots.",
                               "Der alte Fenwick: Mein Junge ging für Kupfer in den Splitterboden. Die Mine behielt ihn und schickte die Stiefel zurück."),
                              ("Old Fenwick: Good boots. Wipe your feet on the way out.",
                               "Der alte Fenwick: Gute Stiefel. Tritt dir beim Rausgehen die Füße ab.")], "")),
    "reedhaven_spring": ("reedhaven", (9, 3), "spring", ("Reedhaven Spring House", "Quellhaus Schilfhafen"),
        ("bea", "elder", [("Tender Bea: Fen water, boiled twice. Once for the mud, once for the leeches.",
                           "Pflegerin Bea: Moorwasser, zweimal gekocht. Einmal für den Schlamm, einmal für die Egel."),
                          ("Tender Bea: Sit. Your team can drink their fill.",
                           "Pflegerin Bea: Setz dich. Dein Team kann trinken, so viel es will.")], "heal")),
    "reedhaven_shop": ("reedhaven", (2, 3), "shop", ("Reedhaven Store", "Laden Schilfhafen"),
        ("dirk", "villager", [("Clerk Dirk: Towels, tonics, tide tables. The tables are free. They are also wrong.",
                               "Verkäufer Dirk: Handtücher, Tonika, Gezeitentafeln. Die Tafeln sind gratis. Sie stimmen auch nicht.")], SHOP_REED)),
    "reedhaven_house": ("reedhaven", (2, 7), "house", ("Grete's House", "Gretes Haus"),
        ("grete", "villager", [("Grete: The stilts creak every night. My husband says it is the wind.",
                                "Grete: Die Stelzen knarren jede Nacht. Mein Mann sagt, das ist der Wind."),
                               ("Grete: He also said the stilts were new.",
                                "Grete: Er hat auch gesagt, die Stelzen wären neu.")], "")),
    "wrenhollow_spring": ("wrenhollow", (2, 3), "spring", ("Wrenhollow Spring House", "Quellhaus Zaunkönigsgrund"),
        ("ilka", "elder", [("Keeper Ilka: Brook water through a willow root. It tastes of bark and patience.",
                            "Hüterin Ilka: Bachwasser durch eine Weidenwurzel. Es schmeckt nach Rinde und Geduld.")], "heal")),
    "wrenhollow_shop": ("wrenhollow", (8, 3), "shop", ("Wrenhollow Store", "Laden Zaunkönigsgrund"),
        ("maren", "villager", [("Clerk Maren: Ebbe keeps the cold stock outside. In here it is the same stock, only warmer.",
                                "Verkäuferin Maren: Ebbe hat die kalte Ware draußen. Hier drin ist es dieselbe Ware, nur wärmer.")], SHOP_WREN)),
    "corvane_quay_spring": ("corvane_quay", (2, 4), "spring", ("Quay Spring House", "Quellhaus am Kai"),
        ("liesl", "elder", [("Harbour Nurse Liesl: Salt spring, piped in from the quay. Sit. The gulls cannot get in here.",
                             "Hafenschwester Liesl: Salzquelle, vom Kai hereingeleitet. Setz dich. Die Möwen kommen hier nicht rein.")], "heal")),
    "corvane_quay_shop": ("corvane_quay", (9, 4), "shop", ("Quay Store", "Laden am Kai"),
        ("anselm", "villager", [("Clerk Anselm: Everything off the ferry, priced for people who have no way back.",
                                 "Verkäufer Anselm: Alles von der Fähre, bepreist für Leute ohne Rückweg.")], SHOP_CORVANE)),
    "corvane_quay_house": ("corvane_quay", (2, 12), "house", ("Marit's House", "Marits Haus"),
        ("marit", "elder", [("Widow Marit: My husband rowed the ferry for thirty years. One day the ferry came back and he did not.",
                             "Witwe Marit: Mein Mann ruderte dreißig Jahre die Fähre. Eines Tages kam die Fähre zurück und er nicht."),
                            ("Widow Marit: The company sent flowers. And the bill for the oar.",
                             "Witwe Marit: Die Gesellschaft schickte Blumen. Und die Rechnung für das Ruder.")], "")),
    "madderby_spring": ("madderby", (8, 13), "spring", ("Madderby Spring House", "Quellhaus Madderby"),
        ("trudi", "elder", [("Nurse Trudi: The dye works took the colour from the river. The spring kept a little. Rest.",
                             "Schwester Trudi: Die Färberei nahm dem Fluss die Farbe. Die Quelle hat ein wenig behalten. Ruh dich aus.")], "heal")),
    "madderby_house": ("madderby", (2, 9), "house", ("Konrad's House", "Konrads Haus"),
        ("konrad", "elder", [("Dyer Konrad: Forty years I dyed cloth blue. Now my hands are blue and the cloth is grey.",
                              "Färber Konrad: Vierzig Jahre färbte ich Tuch blau. Jetzt sind meine Hände blau und das Tuch grau."),
                             ("Dyer Konrad: Fair trade, says the guild.",
                              "Färber Konrad: Ein fairer Tausch, sagt die Gilde.")], "")),
    "greyreach_hut": ("greyreach", (3, 6), "hut", ("Shepherd's Hut", "Schäferhütte"),
        ("olm", "elder", [("Shepherd Olm: The fog takes a sheep a week. I stopped naming them.",
                           "Schäfer Olm: Der Nebel holt jede Woche ein Schaf. Ich habe aufgehört, ihnen Namen zu geben."),
                          ("Shepherd Olm: Then I stopped counting them. Now I sleep fine.",
                           "Schäfer Olm: Dann habe ich aufgehört, sie zu zählen. Jetzt schlafe ich gut.")], "")),
    "edge_watch_hut": ("wide_rift_edge", (3, 6), "hut", ("Watcher's Hut", "Hütte der Wächterin"),
        ("ida", "ranger", [("Rift Watcher Ida: I watch the edge so you don't have to. Nobody pays me.",
                            "Risswächterin Ida: Ich bewache den Rand, damit du es nicht musst. Niemand bezahlt mich."),
                           ("Rift Watcher Ida: Nobody needs to. The edge is very convincing.",
                            "Risswächterin Ida: Muss auch keiner. Der Rand ist sehr überzeugend.")], "")),
}


def load(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return json.load(f)


def save(path, data):
    with open(os.path.join(ROOT, path), "w", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")


def build_room(room_id, town_map, spec):
    town, door, kind, (name, _), person = spec
    region = town_map["region"]
    rows = TEMPLATES[(kind, 6 if kind == "hut" else ROWS[region])]
    h, w = len(rows), len(rows[0])
    dx = rows[-1].index("D")
    pid, sprite, _, action = person
    # The person stands behind the counter (spring, shop) or by the back wall (house, hut).
    spot = (4, 2) if kind in ("spring", "shop") else (2, 2)
    m = {"name": name, "region": region, "biome": "town", "backdrop": BACKDROP[region]}
    if kind == "spring":
        m["heal_point"] = [dx, h - 3]
    m["rows"] = rows
    m["warps"] = [{"x": dx, "y": h - 1, "to": town, "tx": door[0], "ty": door[1] + 1, "facing": "down"}]
    m["npcs"] = [{"id": pid, "x": spot[0], "y": spot[1], "facing": "down", "dialogue": "rooms/%s_%s" % (room_id, pid),
                  "sprite": sprite}]
    m["signs"] = []
    return m, (dx, h - 2)


def main():
    with open(os.path.join(ROOT, "data", "world_layout.json"), encoding="utf-8") as f:
        layout_text = f.read()
    layout = json.loads(layout_text)
    new_places = []
    dialogue, german = {}, {}
    towns = {}
    for room_id, spec in ROOMS.items():
        town, door, kind, (name, name_de), person = spec
        if town not in towns:
            towns[town] = load("data/maps/%s.json" % town)
        tm = towns[town]
        assert tm["rows"][door[1]][door[0]] == "D", (room_id, door)
        room, arrive = build_room(room_id, tm, spec)
        save("data/maps/%s.json" % room_id, room)
        pid, _, pairs, action = person
        entry = {"lines": [en for en, _ in pairs]}
        if action:
            entry["action"] = action
        dialogue["%s_%s" % (room_id, pid)] = entry
        german[name] = name_de
        german.update(dict(pairs))
        warp = {"x": door[0], "y": door[1], "to": room_id, "tx": arrive[0], "ty": arrive[1], "facing": "up"}
        tm["warps"] = [w for w in tm["warps"] if (int(w["x"]), int(w["y"])) != door] + [warp]
        place = {"inside": town}
        if tm["region"] != "veydal":
            place["region"] = tm["region"]
        if room_id not in layout["maps"]:
            new_places.append('  "%s": %s' % (room_id, json.dumps(place, ensure_ascii=False)))
    for town, tm in towns.items():
        save("data/maps/%s.json" % town, tm)
    save("data/dialogue/rooms.json", dialogue)
    if new_places:
        # The layout file is laid out by hand (one place per line): append the new lines.
        end = layout_text.rstrip()
        for _ in range(2):
            assert end.endswith("}"), "unexpected end of data/world_layout.json"
            end = end[:-1].rstrip()
        layout_text = end + ",\n" + ",\n".join(new_places) + "\n }\n}\n"
        with open(os.path.join(ROOT, "data", "world_layout.json"), "w", encoding="utf-8") as f:
            f.write(layout_text)
    with open(os.path.join(ROOT, "tools", "i18n", "de_rooms.py"), "w", encoding="utf-8") as f:
        f.write("# German texts for the town rooms. Written by tools/art/gen_rooms.py: edit the pairs there.\nT = {\n")
        for en, de in sorted(german.items()):
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(de, ensure_ascii=False)))
        f.write("}\n")
    print("rooms:", len(ROOMS))


if __name__ == "__main__":
    main()
