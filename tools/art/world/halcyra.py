"""Halcyra, the post-game Era IV region (data/region4.json): five towns, six routes, four Rifts
and the Great Orrery, all from the region sheet. Region "halcyra", drawn with the Era IV atlas
art/era4/tiles/overworld_halcyra.png (white stone, golden roofs, terraces). Edit here, then run
tools/art/build_world.py halcyra.

How the way opens (flags from data/region4.json):
  greyreach <-> brightledge       Gilt Funicular, line "halcyra_funicular", open_flag era3_finale_done
                                  (Era III's last town can add itself as a stop of the line)
  brightledge, Fixer Oriel        sets v4_ch1_done (chapter 1)
  starwell -> orrery_rift         v4_ch1_done
  paleshore -> salt_rift          rift_v4_orrery_sealed
  whitecairn -> span_rift         rift_v4_salt_sealed
  gildcrest -> gilt_rift          rift_v4_span_sealed
  gildcrest, feast host           shows after rift_v4_gilt_sealed, sets halcyra_done (Era IV finale)

Wardens carry the warden key v4_<rift>, so GameState.seal_rift sets rift_v4_<rift>_sealed, the
flag the sheet names. Every town has its own layout (TOWN_LAYOUT) with a spring as the square,
the keeper beside it and three locals there at dusk, and a shop, a rest house and two homes
with rooms (ROOMS).
Exits: top (5, 0), bottom (5, last), left (0, 8), right (11, 8), two cells each.
"""
import json
import os

from common import ROOT, check_rows, lines, npc, secret, team, tr, warp
from rifts12 import base_rows, gate, wayfarer
from townsfolk import at, away

SHEET = json.load(open(os.path.join(ROOT, "data", "region4.json"), encoding="utf-8"))
TOWNS = [t["id"] for t in SHEET["towns"]]
ROUTES = [r["id"] for r in SHEET["routes"]]
RIFTS = [r["id"] for r in SHEET["rifts"]]
LANDMARKS = [l["id"] for l in SHEET["landmarks"]]
GROUP = TOWNS + ROUTES + RIFTS + LANDMARKS + ["%s_%s" % (t, k) for t in TOWNS for k in ("shop", "spring", "home_1", "home_2")]

TOWN_H = 20
ROUTE_H = 24
RIFT_H = 22
# Arrival cells for each exit side of a town, a route (top/bottom) and a Rift (bottom).
TOWN_IN = {"top": ((5, 1), (6, 1)), "bottom": ((5, TOWN_H - 2), (6, TOWN_H - 2)),
           "left": ((1, 8), (1, 9)), "right": ((10, 8), (10, 9))}
ROUTE_IN = {"top": ((5, 1), (6, 1)), "bottom": ((5, ROUTE_H - 2), (6, ROUTE_H - 2))}
RIFT_IN = {"bottom": ((5, RIFT_H - 2), (6, RIFT_H - 2))}
# Which side of which map leads where: (map, side) -> (other map, other side).
LINKS = {}


def link(a, side_a, b, side_b):
    LINKS[(a, side_a)] = (b, side_b)
    LINKS[(b, side_b)] = (a, side_a)


for _r in SHEET["routes"]:
    # A route's top leads to links[1], its bottom to links[0] (the way up the plateau).
    pass
link("long_stair", "bottom", "brightledge", "top")
link("long_stair", "top", "gildcrest", "bottom")
link("mirror_flats", "top", "brightledge", "right")
link("mirror_flats", "bottom", "paleshore", "left")
link("cloudshadow_meadow", "bottom", "gildcrest", "right")
link("cloudshadow_meadow", "top", "starwell", "bottom")
link("sunfall_terraces", "top", "gildcrest", "left")
link("sunfall_terraces", "bottom", "paleshore", "top")
link("orrery_ridge", "top", "starwell", "right")
link("orrery_ridge", "bottom", "whitecairn", "top")
link("lantern_span", "top", "paleshore", "right")
link("lantern_span", "bottom", "whitecairn", "bottom")
link("orrery_rift", "bottom", "starwell", "top")
link("salt_rift", "bottom", "paleshore", "bottom")
link("span_rift", "bottom", "whitecairn", "right")
link("gilt_rift", "bottom", "gildcrest", "top")

# Gates on the town side of each Rift: (town, side) -> flag.
RIFT_GATES = {("starwell", "top"): "v4_ch1_done", ("paleshore", "bottom"): "rift_v4_orrery_sealed",
              ("whitecairn", "right"): "rift_v4_salt_sealed", ("gildcrest", "top"): "rift_v4_span_sealed"}

FUNICULAR_STOP = (8, 18)


def arrivals(mid):
    if mid in TOWNS:
        return TOWN_IN
    if mid in ROUTES:
        return ROUTE_IN
    return RIFT_IN


def exit_cells(mid, side, height):
    if side == "top":
        return [(5, 0), (6, 0)]
    if side == "bottom":
        return [(5, height - 1), (6, height - 1)]
    if side == "left":
        return [(0, 8), (0, 9)]
    return [(11, 8), (11, 9)]


FACING = {"top": "up", "bottom": "down", "left": "left", "right": "right"}


def exits(mid, height):
    """Warps for every side of `mid` in LINKS: each exit cell lands on the matching arrival cell."""
    out = []
    for (a, side), (b, side_b) in sorted(LINKS.items()):
        if a != mid:
            continue
        land = arrivals(b)[side_b]
        for (x, y), (tx, ty) in zip(exit_cells(mid, side, height), land):
            out.append(warp(x, y, b, tx, ty, FACING[side]))
    return out


def sheet_entry(kind, mid):
    for e in SHEET[kind]:
        if e["id"] == mid:
            return e
    raise SystemExit("%s %s is not on data/region4.json" % (kind, mid))


def finish(world, mid, m):
    check_rows(mid, m["rows"])
    m["region"] = "halcyra"
    world.add_map(mid, m)


def build(world):
    for t in TOWNS:
        town(world, t)
    for r in ROUTES:
        route(world, r)
    for r in RIFTS:
        rift(world, r)
    great_orrery(world)
    white_stair(world)
    gilt_span(world)


# --- Towns ---------------------------------------------------------------------------------
# Every town has its own layout (tools/maps/audit_maps.py town_twin) and real houses: a shop, a
# rest house and homes, each with a door and a room (ROOMS below). rows: the map, gates on the
# fixed exit cells. doors: room key -> door cell. folk: (home x, y, facing), (dusk x, y, facing).
TOWN_LAYOUT = {
    # The funicular's top station on a ledge: houses along the west lane, the platform bottom right.
    "brightledge": {
        "rows": ["^^^^^__^^^^^",
                 "^.S..__....^",
                 "^.RRR__.RR.^",
                 "^.HDH__.HD.^",
                 "^.._.__.._.^",
                 "^..____.._.^",
                 "^.L..__S._.^",
                 "^....__.._.^",
                 "^...o_______",
                 "^...._______",
                 "^.*..__..*.^",
                 "^.RRR__.RR.^",
                 "^.HDH__.HD.^",
                 "^.._.__.._.^",
                 "^..____.._.^",
                 "^.##.__.._.^",
                 "^....__.._L^",
                 "^::..._+++.^",
                 "^......+++.^",
                 "^^^^^^^^^^^^"],
        "doors": {"spring": (3, 3), "home_1": (9, 3), "shop": (3, 12), "home_2": (9, 12)},
        "keeper": (3, 8), "trader": (7, 14), "sign": (7, 6), "heal": (5, 9), "square": (4, 8),
        "folk": [((1, 6, "right"), (4, 7, "down")), ((10, 10, "left"), (6, 9, "left")), ((2, 16, "right"), (3, 9, "right"))]},
    # The seat of the Gilt House: two gold-roofed halls wall to wall, a ring road round the fountain.
    "gildcrest": {
        "rows": ["^^^^^__^^^^^",
                 "^RRRR__RRRR^",
                 "^RRRR__RRRR^",
                 "^HDHH__HHDH^",
                 "^._..__.._.^",
                 "^.________.^",
                 "^.L.*__*.S.^",
                 "^..______..^",
                 "____.o._____",
                 "____..._____",
                 "^..______..^",
                 "^....__....^",
                 "^.RRR__RRR.^",
                 "^.HDH__HDH.^",
                 "^.._.__._..^",
                 "^T.______.T^",
                 "^.##.__.##.^",
                 "^**..__..L.^",
                 "^....__....^",
                 "^^^^^__^^^^^"],
        "doors": {"shop": (2, 3), "spring": (9, 3), "home_1": (3, 13), "home_2": (8, 13)},
        "keeper": (4, 8), "trader": (7, 11), "sign": (9, 6), "heal": (5, 9), "square": (5, 8),
        "folk": [((1, 6, "right"), (4, 9, "right")), ((10, 11, "left"), (6, 9, "left")), ((2, 18, "right"), (6, 8, "left"))]},
    # The observatory town: the road bends round the hill, the Great Orrery stands against the cliff.
    "starwell": {
        "rows": ["^^^^^__^^^^^",
                 "^.L..__.RR.^",
                 "^.|..__.HD.^",
                 "^.|____.._.^",
                 "^.._______.^",
                 "^..__.RR...^",
                 "^..__.HD.L.^",
                 "^..__.._...^",
                 "^..__o______",
                 "^.._________",
                 "^..__.S....^",
                 "^RR__...RRR^",
                 "^HD__...RRR^",
                 "^..__...HDH^",
                 "^.._______.^",
                 "^RR..__....^",
                 "^HD..__.L..^",
                 "^._..__.|..^",
                 "^._____.|..^",
                 "^^^^^__^^^^^"],
        "doors": {"home_1": (9, 2), "spring": (7, 6), "home_2": (2, 12), "shop": (2, 16)},
        "keeper": (5, 7), "trader": (7, 10), "sign": (6, 10), "heal": (5, 9), "square": (5, 8),
        "folk": [((2, 6, "right"), (6, 8, "left")), ((10, 7, "left"), (6, 9, "left")), ((10, 5, "left"), (4, 9, "right"))]},
    # The salt town: brine pans in a chequer, the houses on the dry squares between them.
    "paleshore": {
        "rows": ["^^^^^__^^^^^",
                 "^~~~.__.RR.^",
                 "^~~~.__.HD.^",
                 "^~~~._____.^",
                 "^....__....^",
                 "^.RRR__~~~.^",
                 "^.HDH__~~~.^",
                 "^.._.__o.S.^",
                 "____________",
                 "____________",
                 "^...L__....^",
                 "^~~~.__RRR.^",
                 "^~~~.__HDH.^",
                 "^~~~.____..^",
                 "^....__....^",
                 "^.RR.__~~~.^",
                 "^.HD.__~~~.^",
                 "^.._.__~~~.^",
                 "^..____...L^",
                 "^^^^^__^^^^^"],
        "doors": {"home_1": (9, 2), "spring": (3, 6), "shop": (8, 12), "home_2": (3, 16)},
        "keeper": (8, 7), "trader": (8, 10), "sign": (9, 7), "heal": (7, 8), "square": (7, 7),
        "folk": [((4, 4, "right"), (6, 7, "right")), ((10, 14, "left"), (7, 9, "up")), ((2, 14, "right"), (8, 9, "left"))]},
    # The last town before the edge: a field of cairns to the west, the houses in a row to the east.
    "whitecairn": {
        "rows": ["^^^^^__^^^^^",
                 "^@.@.__.RR.^",
                 "^....__.HD.^",
                 "^.@.._____.^",
                 "^...@__....^",
                 "^@...__RRR.^",
                 "^..@.__HDH.^",
                 "^....____..^",
                 "^@..o_______",
                 "^..@._______",
                 "^....__....^",
                 "^@.@.__.L..^",
                 "^....__.RR.^",
                 "^.@..__.HD.^",
                 "^...._____.^",
                 "^.RR.__....^",
                 "^.DH.__.@.@^",
                 "^._..__....^",
                 "^._____..S.^",
                 "^^^^^__^^^^^"],
        "doors": {"home_1": (9, 2), "spring": (8, 6), "shop": (9, 13), "home_2": (2, 16)},
        "keeper": (3, 8), "trader": (7, 10), "sign": (9, 18), "heal": (4, 9), "square": (4, 8),
        "folk": [((2, 5, "right"), (4, 7, "down")), ((10, 10, "left"), (5, 9, "left")), ((9, 17, "left"), (5, 7, "left"))]},
}
# Rooms in the Era IV look, one template per kind (the rest house has its own spring).
ROOM_ROWS = {
    "spring": ["WWWWWWWWWW", "WfffoofffW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WWWWDWWWWW"],
    "shop": ["WWWWWWWWWW", "WCCCffCCCW", "WffffffffW", "WffCCCCffW", "WffffffffW", "WffffffffW", "WffffffffW", "WWWWDWWWWW"],
    "home": ["WWWWWWWWWW", "WCCffffCCW", "WffffffffW", "WffffffffW", "WCffffffCW", "WffffffffW", "WffffffffW", "WWWWDWWWWW"],
}
# town -> room key -> ((name EN, DE), person id, sprite, (line EN, DE) ...). "spring" heals, "shop" sells.
ROOMS = {
    "brightledge": {
        "shop": (("Station Store", "Stationsladen"), "odalys", "villager",
                 ("Clerk Odalys: Souvenirs on the left, tonics on the right. The souvenirs outlive most of the buyers.", "Verkäuferin Odalys: Andenken links, Tränke rechts. Die Andenken überleben die meisten Käufer.")),
        "spring": (("Porters' Rest", "Trägerrast"), "elke", "elder",
                   ("Matron Elke: Lie down. The Gilt House pays for the bed. It also counts the hours you spend in it.", "Hausmutter Elke: Leg dich hin. Das Haus Gilt bezahlt das Bett. Es zählt auch die Stunden, die du darin verbringst.")),
        "home_1": (("Brakeman's House", "Haus des Bremsers"), "tilde", "villager",
                   ("Tilde: Fidel checks the cable every morning. Then he comes home and checks his will.", "Tilde: Fidel prüft jeden Morgen das Seil. Dann kommt er heim und prüft sein Testament."),
                   ("Tilde: I am in it twice. Once as his wife, once as a witness.", "Tilde: Ich stehe zweimal drin. Einmal als seine Frau, einmal als Zeugin.")),
        "home_2": (("Painter's Loft", "Malerboden"), "jorin", "villager",
                   ("Apprentice Jorin: Cosima paints the sunset, the House burns it, and I sweep up the ash. It is the only steady job in the arts.", "Lehrling Jorin: Cosima malt den Sonnenuntergang, das Haus verbrennt ihn, und ich fege die Asche auf. Es ist die einzige feste Stelle in der Kunst.")),
    },
    "gildcrest": {
        "shop": (("Gilt Commissary", "Gilt-Magazin"), "ottmar", "villager",
                 ("Commissary Clerk Ottmar: Everything here is gilded. The prices too. Scratch them and you find more prices.", "Magazinschreiber Ottmar: Hier ist alles vergoldet. Auch die Preise. Kratz daran, und darunter sind noch mehr Preise.")),
        "spring": (("House Infirmary", "Hauslazarett"), "calla", "elder",
                   ("Infirmary Sister Calla: Rest. In this house people recover quickly. The slow ones are replaced.", "Lazarettschwester Calla: Ruh dich aus. In diesem Haus erholt man sich schnell. Die Langsamen werden ersetzt.")),
        "home_1": (("Servants' Wing", "Gesindeflügel"), "bertrand", "villager",
                   ("Cook Bertrand: Five children, five tasters. I am on my third set of tasters.", "Koch Bertrand: Fünf Kinder, fünf Vorkoster. Ich bin beim dritten Satz Vorkoster."),
                   ("Cook Bertrand: The soup is fine. Probably. Tobiah went first.", "Koch Bertrand: Die Suppe ist in Ordnung. Wahrscheinlich. Tobiah hat zuerst probiert.")),
        "home_2": (("Tutor's Rooms", "Zimmer des Hauslehrers"), "emeric", "elder",
                   ("Tutor Emeric: I teach the Gilt children arithmetic. They only ever ask about subtraction.", "Hauslehrer Emeric: Ich bringe den Gilt-Kindern Rechnen bei. Sie fragen immer nur nach dem Abziehen.")),
    },
    "starwell": {
        "shop": (("Lens Shop", "Linsenladen"), "ines", "villager",
                 ("Lens Seller Ines: Tonics, charts and lenses. Buy a lens and you will see your future. Buy a tonic and you will have one.", "Linsenhändlerin Ines: Tränke, Karten und Linsen. Kauf eine Linse, und du siehst deine Zukunft. Kauf einen Trank, und du hast eine.")),
        "spring": (("Stargazers' Rest", "Sternguckerrast"), "wilhelmina", "elder",
                   ("Night Nurse Wilhelmina: Sleep. The stars will still be lying when you wake up.", "Nachtschwester Wilhelmina: Schlaf. Die Sterne lügen auch noch, wenn du aufwachst.")),
        "home_1": (("Horoscope Parlour", "Horoskopstube"), "mirabel", "villager",
                   ("Seer Mirabel: I read futures for the Gilt House. I leave out the endings. They pay better that way.", "Seherin Mirabel: Ich lese dem Haus Gilt die Zukunft. Das Ende lasse ich weg. So zahlen sie besser."),
                   ("Seer Mirabel: Yours is short. I mean the reading.", "Seherin Mirabel: Deine ist kurz. Die Lesung, meine ich.")),
        "home_2": (("Copyists' Room", "Kopistenstube"), "lorenz", "villager",
                   ("Copyist Lorenz: We copy the sky by hand. When a star goes missing we are told it was never there. We erase it very neatly.", "Kopist Lorenz: Wir schreiben den Himmel von Hand ab. Fehlt ein Stern, heißt es, er war nie da. Wir radieren ihn sehr sauber aus.")),
    },
    "paleshore": {
        "shop": (("Salt Exchange", "Salzbörse"), "runa", "villager",
                 ("Exchange Clerk Runa: We trade in salt and tonics. Salt keeps things from going bad. It has not worked on Halloran.", "Börsenschreiberin Runa: Wir handeln mit Salz und Tränken. Salz bewahrt vor dem Verderben. Bei Halloran hat es nicht gewirkt.")),
        "spring": (("Brine Bath House", "Solebadehaus"), "jost", "elder",
                   ("Bath Attendant Jost: Soak as long as you like. The brine takes the ache out. It took my brother out entirely.", "Bademeister Jost: Bleib drin, so lange du willst. Die Sole zieht den Schmerz heraus. Meinen Bruder hat sie ganz herausgezogen.")),
        "home_1": (("Raker's Hut", "Rechenhütte"), "solveig", "villager",
                   ("Solveig: Father says the white line moved again last night. He says it like the line is coming for dinner.", "Solveig: Vater sagt, die weiße Linie ist heute Nacht wieder gewandert. Er sagt es, als käme sie zum Abendessen.")),
        "home_2": (("Ledger House", "Schuldbuchhaus"), "almut", "elder",
                   ("Debt Scribe Almut: Every grain of salt is owed to somebody. I keep the book.", "Schuldschreiberin Almut: Jedes Salzkorn ist irgendwem geschuldet. Ich führe das Buch."),
                   ("Debt Scribe Almut: The book is thicker than the lake was deep.", "Schuldschreiberin Almut: Das Buch ist dicker, als der See tief war.")),
    },
    "whitecairn": {
        "shop": (("Lantern Chandlery", "Laternenlager"), "wenzel", "villager",
                 ("Chandler Wenzel: Oil, wicks, tonics. Veronne buys the lanterns. The families buy them a second time.", "Krämer Wenzel: Öl, Dochte, Tränke. Veronne kauft die Laternen. Die Familien kaufen sie ein zweites Mal.")),
        "spring": (("Mourners' Rest", "Trauerrast"), "hanne", "elder",
                   ("Vigil Keeper Hanne: Rest here. The beds are for the living. We check every morning, to be sure.", "Wachfrau Hanne: Ruh dich hier aus. Die Betten sind für die Lebenden. Wir sehen jeden Morgen nach, zur Sicherheit.")),
        "home_1": (("Stonecutter's House", "Steinmetzhaus"), "gerwin", "elder",
                   ("Stonecutter Gerwin: I carve the names before they are needed. The Gilt House sends me a list. It is rarely wrong.", "Steinmetz Gerwin: Ich meißle die Namen, bevor sie gebraucht werden. Das Haus Gilt schickt mir eine Liste. Sie irrt sich selten.")),
        "home_2": (("Rope Keeper's House", "Haus der Seilwartin"), "thea", "villager",
                   ("Rope Keeper Thea: The basket goes down to the moor and comes back up. I only count the ropes.", "Seilwartin Thea: Der Korb fährt ins Moor hinunter und kommt wieder herauf. Ich zähle nur die Seile."),
                   ("Rope Keeper Thea: Counting the people was making me sad.", "Seilwartin Thea: Die Leute zu zählen hat mich traurig gemacht.")),
    },
}


def town_rows(mid):
    rows = list(TOWN_LAYOUT[mid]["rows"])
    sides = {s for (a, s) in LINKS if a == mid}
    for side in ("top", "bottom", "left", "right"):
        for (x, y), (ix, iy) in zip(exit_cells(mid, side, TOWN_H), TOWN_IN[side]):
            if (rows[y][x] == "_") != (side in sides):
                raise SystemExit("%s: side %s does not match its exits" % (mid, side))
            if side in sides and rows[iy][ix] not in "._":
                raise SystemExit("%s: no open ground inside the %s exit" % (mid, side))
    return rows


def rooms(world, mid, m):
    """The room behind every house door of town `mid`; adds the door warps to the town map `m`."""
    lay = TOWN_LAYOUT[mid]
    text = {}
    for key, (dx, dy) in lay["doors"].items():
        (name, who, sprite), talk = ROOMS[mid][key][:3], ROOMS[mid][key][3:]
        if m["rows"][dy][dx] != "D" or m["rows"][dy - 1][dx] not in "RH" or m["rows"][dy + 1][dx] not in "._":
            raise SystemExit("%s: no house door above open ground at %d,%d" % (mid, dx, dy))
        kind = key if key in ROOM_ROWS else "home"
        rid = "%s_%s" % (mid, key)
        rows = list(ROOM_ROWS[kind])
        rx = rows[-1].index("D")
        entry = {"lines": lines(*talk)}
        if kind == "spring":
            entry["action"] = "heal"
        elif kind == "shop":
            entry["action"] = SHOP_ITEMS
        text[who] = entry
        room = {"name": tr(*name), "biome": "town", "backdrop": "field", "rows": rows,
                "warps": [warp(rx, len(rows) - 1, mid, dx, dy + 1, "down")],
                "npcs": [npc(who, 4 if kind != "home" else 2, 2, "down", "%s/%s" % (mid, who), sprite)], "signs": []}
        if kind == "spring":
            room["heal_point"] = [rx, len(rows) - 3]
        finish(world, rid, room)
        m["warps"].append(warp(dx, dy, rid, rx, len(rows) - 2, "up"))
    if sum(r.count("D") for r in m["rows"]) != len(lay["doors"]) + (1 if mid == "starwell" else 0):
        raise SystemExit("%s: a door that is no house door" % mid)
    world.add_text(mid, text)


# Per town: sign lines, keeper line, (shop line or None), three locals, finds, extra people.
TOWN_TEXT = {
    "brightledge": {
        "sign": [("BRIGHTLEDGE", "BRIGHTLEDGE"), ("Top station of the Gilt Funicular. The Gilt House welcomes you. The Gilt House is watching you.", "Bergstation der Gilt-Standseilbahn. Das Haus Gilt heißt dich willkommen. Das Haus Gilt beobachtet dich."),
                 ("North: the White Stair to Gildcrest. East: the Mirror Flats.", "Norden: die Weiße Treppe nach Gildcrest. Osten: die Spiegelebene.")],
        "keeper": ("Station Nurse Ambre: Rest up. The air is thin up here, and so is the patience of the people who own it.", "Stationsschwester Ambre: Ruh dich aus. Die Luft ist dünn hier oben, und die Geduld der Leute, denen sie gehört, auch."),
        "shop": ("Kiosk Keeper Lumen Doss: Water, tonics, postcards of the view. The view itself is not for sale. Yet.", "Kioskwirt Lumen Doss: Wasser, Tränke, Postkarten von der Aussicht. Die Aussicht selbst ist nicht zu verkaufen. Noch nicht."),
        "folk": [("anselm", "villager", ("Porter Anselm: I carry trunks up from the station. Nobody tips. They just say the view is payment.", "Gepäckträger Anselm: Ich trage Koffer von der Station hoch. Keiner gibt Trinkgeld. Alle sagen, die Aussicht sei Bezahlung genug.")),
                 ("cosima", "villager", ("Painter Cosima: I paint the horizon every evening. The Gilt House buys every one, then burns them. They like to own the sunset.", "Malerin Cosima: Jeden Abend male ich den Horizont. Das Haus Gilt kauft jedes Bild und verbrennt es dann. Es besitzt gern den Sonnenuntergang.")),
                 ("hesper", "elder", ("Old Hesper: Eighty years on this ledge. I've seen three funiculars and four Gilt patriarchs fall. Only the funiculars were accidents.", "Die alte Hesper: Achtzig Jahre auf diesem Sims. Ich habe drei Standseilbahnen und vier Gilt-Patriarchen stürzen sehen. Nur die Bahnen waren Unfälle."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "revival_leaf"), ((0, 16), "strong_tonic", 2)],
    },
    "gildcrest": {
        "sign": [("GILDCREST", "GILDCREST"), ("Seat of the Gilt House. Every roof is gold. Every wall has ears.", "Sitz des Hauses Gilt. Jedes Dach ist aus Gold. Jede Wand hat Ohren."),
                 ("South: the White Stair. East: Cloudshadow Meadow. West: the Sunfall Terraces.", "Süden: die Weiße Treppe. Osten: die Wolkenschattenwiese. Westen: die Sonnenfall-Terrassen.")],
        "keeper": ("House Physician Velka: The Gilt House pays for your rest. The Gilt House will remember that.", "Hausärztin Velka: Das Haus Gilt bezahlt deine Ruhe. Das Haus Gilt wird sich daran erinnern."),
        "shop": ("Gilt Quartermaster Rennick: Fine goods at family prices. Not your family. Ours.", "Gilt-Quartiermeister Rennick: Feine Waren zu Familienpreisen. Nicht deiner Familie. Unserer."),
        "folk": [("lisette", "villager", ("Maid Lisette: I polish the roofs at dawn. The gold comes off on my hands. So does everything else in this house.", "Zofe Lisette: Morgens poliere ich die Dächer. Das Gold färbt auf meine Hände ab. Wie alles andere in diesem Haus.")),
                 ("tobiah", "villager", ("Footman Tobiah: Lord Aurek has five children and one chair. Dinner here is a sport.", "Diener Tobiah: Herr Aurek hat fünf Kinder und einen Stuhl. Abendessen ist hier ein Sport.")),
                 ("griselda", "elder", ("Nanny Griselda: I raised all five Gilt children. I taught them manners. Somebody else taught them knives.", "Kinderfrau Griselda: Ich habe alle fünf Gilt-Kinder großgezogen. Ich habe ihnen Manieren beigebracht. Jemand anderes hat ihnen Messer beigebracht."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "spark_drop"), ((0, 17), "remedy", 2)],
    },
    "starwell": {
        "sign": [("STARWELL", "STARWELL"), ("Observatory town. Horoscopes read while you wait. Futures sold separately.", "Sternwartenstadt. Horoskope sofort zum Mitnehmen. Zukunft separat erhältlich."),
                 ("North: the Orrery Rift. East: Orrery Ridge. South: Cloudshadow Meadow. The Great Orrery: the brass door.", "Norden: der Planetariumsriss. Osten: der Planetariumsgrat. Süden: die Wolkenschattenwiese. Das Große Planetarium: die Messingtür.")],
        "keeper": ("Star Nurse Pell: Lie back and look up. Healing works better when you're counting stars instead of debts.", "Sternenpflegerin Pell: Leg dich hin und schau nach oben. Heilung wirkt besser, wenn du Sterne zählst statt Schulden."),
        "shop": None,
        "folk": [("orla", "villager", ("Lens Grinder Orla: I grind lenses all day. At dusk I look through them and see the same lies, only bigger.", "Linsenschleiferin Orla: Den ganzen Tag schleife ich Linsen. Abends schaue ich hindurch und sehe dieselben Lügen, nur größer.")),
                 ("quill", "villager", ("Chart Boy Quill: I copy star charts for the Gilt House. I add one fake star to each. Nobody's noticed.", "Kartenjunge Quill: Ich kopiere Sternkarten für das Haus Gilt. In jede male ich einen falschen Stern. Keinem ist es aufgefallen.")),
                 ("serafin", "elder", ("Retired Astronomer Serafin: I discovered a comet once. The Gilt House renamed it after a cousin. The cousin later fell off a balcony.", "Astronom im Ruhestand Serafin: Ich habe mal einen Kometen entdeckt. Das Haus Gilt hat ihn nach einem Cousin benannt. Der Cousin fiel später von einem Balkon."))],
        "finds": [((0, 5), "revival_leaf"), ((11, 14), "max_tonic"), ((0, 13), "focus_brew")],
    },
    "paleshore": {
        "sign": [("PALESHORE", "PALESHORE"), ("Salt town on a dried lake. Do not walk past the white line. The line moves.", "Salzstadt an einem ausgetrockneten See. Geh nicht über die weiße Linie. Die Linie wandert."),
                 ("West: Mirror Flats. North: the Sunfall Terraces. East: the Lantern Span. South: the Salt Rift.", "Westen: die Spiegelebene. Norden: die Sonnenfall-Terrassen. Osten: der Laternenbogen. Süden: der Salzriss.")],
        "keeper": ("Brine Healer Odo: A salt bath cures everything. Except debt. That needs the other kind of bath.", "Solheiler Odo: Ein Salzbad heilt alles. Außer Schulden. Dafür braucht es die andere Art Bad."),
        "shop": ("Salt Merchant Imke: Tonics, salt and silence. The silence costs the most.", "Salzhändlerin Imke: Tränke, Salz und Schweigen. Das Schweigen kostet am meisten."),
        "folk": [("bertil", "villager", ("Salt Raker Bertil: I rake salt from dawn to dusk. Sometimes the rake finds a boot. Sometimes the boot is still full.", "Salzrechen Bertil: Ich reche Salz von früh bis spät. Manchmal findet der Rechen einen Stiefel. Manchmal ist der Stiefel noch voll.")),
                 ("maren", "villager", ("Widow Maren: My husband walked on the mirror and never came back. Halloran sent a bill for the salt he displaced.", "Witwe Maren: Mein Mann ist auf den Spiegel gelaufen und nie zurückgekommen. Halloran hat eine Rechnung für das verdrängte Salz geschickt.")),
                 ("ivo", "elder", ("Ferryman Ivo: There's been no water to ferry for twenty years. I still charge. Habit.", "Fährmann Ivo: Seit zwanzig Jahren gibt es kein Wasser mehr zum Übersetzen. Ich kassiere trotzdem. Gewohnheit."))],
        "finds": [((0, 4), "strong_tonic", 2), ((11, 13), "remedy"), ((0, 14), "wake_bell")],
    },
    "whitecairn": {
        "sign": [("WHITECAIRN", "WHITECAIRN"), ("The last town before the edge. Each cairn is a person who said no to the Gilt House.", "Die letzte Stadt vor der Kante. Jeder Steinhaufen ist jemand, der Nein zum Haus Gilt gesagt hat."),
                 ("North: Orrery Ridge. South: the Lantern Span. East: the Span Rift.", "Norden: der Planetariumsgrat. Süden: der Laternenbogen. Osten: der Bogenriss.")],
        "keeper": ("Cairn Warden Tamsa: Rest here. The dead don't mind company, as long as it's quiet.", "Steinhüterin Tamsa: Ruh dich hier aus. Die Toten haben nichts gegen Gesellschaft, solange sie leise ist."),
        "shop": None,
        "folk": [("mathis", "villager", ("Stonestacker Mathis: I build the cairns. Business is steady. Too steady.", "Steinstapler Mathis: Ich baue die Steinhaufen. Das Geschäft läuft stetig. Zu stetig.")),
                 ("ilse", "villager", ("Lantern Girl Ilse: I light the Span every night. Veronne says every lantern is a debt. I say every lantern is a name.", "Laternenmädchen Ilse: Ich zünde jeden Abend den Bogen an. Veronne sagt, jede Laterne ist eine Schuld. Ich sage, jede Laterne ist ein Name.")),
                 ("barnaby", "elder", ("Old Barnaby: I said no to the Gilt House once. They built me a cairn anyway. I'm saving it for later.", "Der alte Barnaby: Ich habe einmal Nein zum Haus Gilt gesagt. Sie haben mir trotzdem einen Steinhaufen gebaut. Ich hebe ihn mir für später auf."))],
        "finds": [((0, 4), "max_tonic"), ((11, 14), "revival_leaf"), ((0, 14), "guard_brew")],
    },
}
SHOP_ITEMS = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew focus_brew pith_mend pith_clear"


def town(world, mid):
    t = TOWN_TEXT[mid]
    lay = TOWN_LAYOUT[mid]
    sheet = sheet_entry("towns", mid)
    rows = town_rows(mid)
    text = {"sign": lines(*t["sign"]),
            "keeper": {"lines": lines(t["keeper"]), "action": "heal"}}
    people = [npc("keeper", lay["keeper"][0], lay["keeper"][1], "down", mid + "/keeper", "elder")]
    if t["shop"]:
        text["trader"] = {"lines": lines(t["shop"]), "action": SHOP_ITEMS}
        people.append(npc("trader", lay["trader"][0], lay["trader"][1], "down", mid + "/trader", "villager"))
    for (pid, sprite, talk), ((hx, hy, hf), (dx, dy, df)) in zip(t["folk"], lay["folk"]):
        text[pid] = {"lines": lines(talk)}
        people.append(npc(pid, hx, hy, hf, "%s/%s" % (mid, pid), sprite, schedule=[at("dusk", dx, dy, df), away("night")]))
    world.add_text(mid, text)
    blocks = []
    warps = exits(mid, TOWN_H)
    for (town_id, side), flag in RIFT_GATES.items():
        if town_id == mid:
            for x, y in exit_cells(mid, side, TOWN_H):
                blocks.append(gate(x, y, flag, "#"))
    m = {"name": tr(sheet["name"], sheet["name"]), "biome": "town", "backdrop": "field", "outdoor": True,
         "heal_point": list(lay["heal"]), "rows": rows, "warps": warps, "npcs": people,
         "signs": [{"x": lay["sign"][0], "y": lay["sign"][1], "dialogue": mid + "/sign"}],
         "secrets": [secret(f[0][0], f[0][1], f[1], "find_%s_%d" % (mid, i + 1), f[2] if len(f) > 2 else 1) for i, f in enumerate(t["finds"])],
         "square": list(lay["square"])}
    if blocks:
        m["blocks"] = blocks
    EXTRA[mid](world, m)
    rooms(world, mid, m)
    for who in m["npcs"]:
        if rows[who["y"]][who["x"]] not in "._+" or (who["x"], who["y"] - 1) in lay["doors"].values():
            raise SystemExit("%s: %s stands in a wall or in front of a door" % (mid, who["id"]))
    finish(world, mid, m)


def brightledge_extra(world, m):
    mid = "brightledge"
    ch = {c["id"]: c for c in SHEET["story"]}
    c1, c2, c3, c4 = ch["v4_ch1"], ch["v4_ch2"], ch["v4_ch3"], ch["v4_ch4"]
    world.add_text(mid, {
        "oriel": {"lines": lines((c1["text"], DE[c1["text"]]),
                                 ("Oriel Vane: Four Rifts, one summer feast, one very generous family. Sign here, here and here. The last one is in case you die.", "Oriel Vane: Vier Risse, ein Sommerfest, eine sehr großzügige Familie. Unterschreib hier, hier und hier. Das letzte ist für den Fall, dass du stirbst.")),
                  "action": "set_flag v4_ch1_done",
                  "after_flag": [
                      {"flag": "v4_ch1_done", "lines": lines(("Oriel Vane: Starwell first. The Orrery Rift is north of town. Drink your tea, it's going cold.", "Oriel Vane: Zuerst Starwell. Der Planetariumsriss liegt nördlich der Stadt. Trink deinen Tee, er wird kalt."),
                                                             (c1["betrayal"]["text"], DE[c1["betrayal"]["text"]]))},
                      {"flag": "rift_v4_orrery_sealed", "lines": lines((c2["betrayal"]["text"], DE[c2["betrayal"]["text"]]),
                                                                       ("Oriel Vane: Paleshore next. The Salt Rift. Mind the mirror, it lies better than I do.", "Oriel Vane: Als Nächstes Paleshore. Der Salzriss. Pass auf den Spiegel auf, er lügt besser als ich."))},
                      {"flag": "rift_v4_salt_sealed", "lines": lines((c3["betrayal"]["text"], DE[c3["betrayal"]["text"]]),
                                                                     ("Oriel Vane: ...Yes. That was me. Halloran paid better than tea. Go to Whitecairn. I'll be there. Probably.", "Oriel Vane: ...Ja. Das war ich. Halloran hat besser bezahlt als Tee. Geh nach Whitecairn. Ich bin dann da. Wahrscheinlich."))},
                      {"flag": "rift_v4_span_sealed", "lines": lines((c4["betrayal"]["text"], DE[c4["betrayal"]["text"]]),
                                                                     ("Oriel Vane: Gildcrest. The feast. Aurek is waiting. So is everyone who wants him dead. Bring a spare fork.", "Oriel Vane: Gildcrest. Das Fest. Aurek wartet. Und alle, die ihn tot sehen wollen, auch. Bring eine Ersatzgabel mit."))}]},
        "brakeman": {"lines": lines(("Brakeman Fidel: The Gilt Funicular, down to the Greyreach and back. The brakes are new. The cable is a family heirloom.", "Bremser Fidel: Die Gilt-Standseilbahn, runter zur Greyreach und zurück. Die Bremsen sind neu. Das Seil ist ein Familienerbstück.")),
                     "action": "transit halcyra_funicular"},
        "white_stair": lines(("THE WHITE STAIR", "DIE WEISSE TREPPE"), ("Nine hundred steps of white stone, straight up to Gildcrest. Counted every morning.", "Neunhundert Stufen aus weißem Stein, direkt hinauf nach Gildcrest. Jeden Morgen gezählt.")),
    })
    m["npcs"] += [npc("oriel", 4, 13, "right", mid + "/oriel", "tamer_f"),
                  npc("brakeman", 8, 17, "down", mid + "/brakeman", "villager")]
    m["signs"].append({"x": 2, "y": 1, "dialogue": mid + "/white_stair"})


def gildcrest_extra(world, m):
    mid = "gildcrest"
    c5 = [c for c in SHEET["story"] if c["id"] == "v4_ch5"][0]
    world.add_text(mid, {
        "host": {"lines": lines((c5["text"], DE[c5["text"]]),
                                ("Steward Corvel: The family thanks you. The family is also, regrettably, poisoned. Please stay for dessert.", "Haushofmeister Corvel: Die Familie dankt dir. Die Familie ist leider auch vergiftet. Bitte bleib zum Nachtisch."),
                                (c5["betrayal"]["text"], DE[c5["betrayal"]["text"]])),
                 "action": "set_flag halcyra_done"},
    })
    m["npcs"].append(npc("host", 7, 17, "left", mid + "/host", "elder", show_flag="rift_v4_gilt_sealed"))


def starwell_extra(world, m):
    # The brass door of the Great Orrery (row 13, x 9, against the east cliff) leads inside.
    m["warps"].append(warp(9, 13, "great_orrery", 5, 8, "up"))


def paleshore_extra(world, m):
    pass


def whitecairn_extra(world, m):
    pass


EXTRA = {"brightledge": brightledge_extra, "gildcrest": gildcrest_extra, "starwell": starwell_extra,
         "paleshore": paleshore_extra, "whitecairn": whitecairn_extra}

# German for the sheet's own texts (story, landmarks), from tools/i18n/de_region4.py.
import importlib.util as _u  # noqa: E402

_spec = _u.spec_from_file_location("de_region4", os.path.join(ROOT, "tools", "i18n", "de_region4.py"))
_mod = _u.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
DE = dict(_mod.T)
for _k in _mod.KEEP:
    DE.setdefault(_k, _k)


# --- Routes --------------------------------------------------------------------------------
ROUTE_ROWS = {
    # The White Stair: a stair column between tower pillars, ferns and scree in the side pockets.
    "long_stair": ["^^^^^__^^^^^",
                   "^,,..__..::^",
                   "^,,..==..::^",
                   "^^^^.==.^^^^",
                   "^,,^.==.^..^",
                   "^,,..==....^",
                   "^^^^.==.^^^^",
                   "^..^.==.^::^",
                   "_____==..::^",
                   "^,,^.==.^..^",
                   "^,,..==....^",
                   "^^^^.==.^^^^",
                   "^::^.==.^,,^",
                   "^::..==..,,^",
                   "^^^^.==.^^^^",
                   "^,,^.==....^",
                   "^,,..==..S.^",
                   "^^^^.==.^^^^",
                   "^..^.==.^::^",
                   "^....==..::^",
                   "^,,..==....^",
                   "^,,..__..,,^",
                   "^.S..__....^",
                   "^^^^^__^^^^^"],
    # Terraces of fern, one stair down each ledge, cloud shadows overhead.
    "cloudshadow_meadow": ["^^^^^__^^^^^",
                           "^,,,.__.,,,^",
                           "^,,,.__.,,,^",
                           "^*...__...*^",
                           "^^^^^==^^^^^",
                           "^,,,,..,,,,^",
                           "^,,,,..,,,,^",
                           "^T.......T.^",
                           "^^^==^^^^^^^",
                           "^...,,,,...^",
                           "^.,,,,,,,,.^",
                           "^.,,T..T,,.^",
                           "^^^^^^^==^^^",
                           "^,,,....,,,^",
                           "^,,,.S..,,,^",
                           "^*........*^",
                           "^^^==^^^^^^^",
                           "^.,,,,,,,..^",
                           "^.,,,,,,,..^",
                           "^....T.....^",
                           "^^^^^^==^^^^",
                           "^,,....__,,^",
                           "^,,...__.,,^",
                           "^^^^^__^^^^^"],
    # The dried lake: salt (scree), reeds and the last pools.
    "mirror_flats": ["^^^^^__^^^^^",
                     "^::..__..::^",
                     "^::.....%%%^",
                     "^~~~....%%%^",
                     "^~~~~...::.^",
                     "^%%~~...::.^",
                     "^%%.....~~~^",
                     "^:::....~~~^",
                     "^:::.S..%%.^",
                     "^~~.....%%.^",
                     "^~~~...~~~~^",
                     "^%%~...~~~~^",
                     "^%%....:::.^",
                     "^......:::.^",
                     "^~~~~..~~~.^",
                     "^~~~~..~~~.^",
                     "^%%....%%%.^",
                     "^%%..*.%%%.^",
                     "^::.....::.^",
                     "^::~~~..::.^",
                     "^...~~...L.^",
                     "^.....__...^",
                     "^.....__...^",
                     "^^^^^__^^^^^"],
    # Cliffs and scree, the path zigzags between ledges past a fallen orrery arm.
    "orrery_ridge": ["^^^^^__^^^^^",
                     "^::..__.::.^",
                     "^::..__.::.^",
                     "^^^^^..^^^^^",
                     "^::......,,^",
                     "^::..^...,,^",
                     "^..........^",
                     "^^^^^^^^..^^",
                     "^::.....:.:^",
                     "^::..@..:::^",
                     "^........::^",
                     "^..^^^^^^^^^",
                     "^.........:^",
                     "^,,..^....:^",
                     "^,,.......:^",
                     "^^^^^^^^..^^",
                     "^::......::^",
                     "^::.S....::^",
                     "^.........,^",
                     "^..^^^^^^^^^",
                     "^...::.....^",
                     "^...::__...^",
                     "^.....__.L.^",
                     "^^^^^__^^^^^"],
    # Golden terraces with cypresses, stairs from ledge to ledge.
    "sunfall_terraces": ["^^^^^__^^^^^",
                         "^,,..__..,,^",
                         "^,,..==..,,^",
                         "^^^^^==^^^^^",
                         "^T,,,..,,,T^",
                         "^.,,,..,,,.^",
                         "^.........*^",
                         "^^==^^^^^^^^",
                         "^.::......T^",
                         "^.::,,,,,..^",
                         "^...,,,,,..^",
                         "^^^^^^^^==^^",
                         "^T.......,,^",
                         "^.:::....,,^",
                         "^.:::.S....^",
                         "^^^==^^^^^^^",
                         "^,,,.....,,^",
                         "^,,,..T..,,^",
                         "^..........^",
                         "^^^^^^^==^^^",
                         "^*...::....^",
                         "^....::__..^",
                         "^.....__...^",
                         "^^^^^__^^^^^"],
    # The Gilt Span: a lantern bridge (piers) over the drop, one island halfway.
    "lantern_span": ["^^^^^__^^^^^",
                     "^::..__..::^",
                     "^::..__..,,^",
                     "^,,..__..,,^",
                     "~~~~L++L~~~~",
                     "~~~~|++|~~~~",
                     "~~~~L++L~~~~",
                     "~~~~|++|~~~~",
                     "~~~~L++L~~~~",
                     "~~~~|++|~~~~",
                     "~~~~L++L~~~~",
                     "^:::.++.%%%^",
                     "^:::._______",
                     "^,,..S...%%^",
                     "^,,......%%^",
                     "~~~~L++L~~~~",
                     "~~~~|++|~~~~",
                     "~~~~L++L~~~~",
                     "~~~~|++|~~~~",
                     "~~~~L++L~~~~",
                     "^::..++..,,^",
                     "^::..__..,,^",
                     "^.....__...^",
                     "^^^^^__^^^^^"],
}
# Route signs: (x, y) of the "S" tiles and their text; finds on the cliff edge next to the way.
ROUTE_SIGNS = {
    "long_stair": [((9, 16), ("THE LONG STAIR", "DIE LANGE TREPPE"), ("Up: Gildcrest. Down: Brightledge. Sideways: not advised.", "Hinauf: Gildcrest. Hinunter: Brightledge. Seitwärts: nicht zu empfehlen.")),
                   ((2, 22), ("THE WHITE STAIR", "DIE WEISSE TREPPE"), ("Nine hundred steps of white stone. The Gilt House counts them every morning, in case one went missing.", "Neunhundert Stufen aus weißem Stein. Das Haus Gilt zählt sie jeden Morgen, falls eine verschwunden ist."))],
    "cloudshadow_meadow": [((5, 14), ("CLOUDSHADOW MEADOW", "WOLKENSCHATTENWIESE"), ("The shadows of the clouds graze here. So does everything that hunts in them.", "Hier grasen die Schatten der Wolken. Und alles, was darin jagt."))],
    "mirror_flats": [((5, 8), ("MIRROR FLATS", "SPIEGELEBENE"), ("The salt reflects the sky. Look down and you will see the sky. Look down too long and you will join it.", "Das Salz spiegelt den Himmel. Schau nach unten, und du siehst den Himmel. Schau zu lange, und du gehörst dazu."))],
    "orrery_ridge": [((4, 17), ("ORRERY RIDGE", "PLANETARIUMSGRAT"), ("A brass arm of the Great Orrery fell here. The planet it held is still missing.", "Hier ist ein Messingarm des Großen Planetariums heruntergefallen. Der Planet, den er hielt, fehlt noch immer."))],
    "sunfall_terraces": [((6, 14), ("SUNFALL TERRACES", "SONNENFALL-TERRASSEN"), ("The Gilt vineyards. The wine is golden. So are the bribes.", "Die Weinberge der Gilt. Der Wein ist golden. Die Bestechungsgelder auch."))],
    "lantern_span": [((5, 13), ("THE GILT SPAN", "DER GILT-BOGEN"), ("A bridge over nothing at all, lit by lanterns paid for by the families of those who fell.", "Eine Brücke über gar nichts, beleuchtet von Laternen, die die Familien der Abgestürzten bezahlt haben."))],
}
ROUTE_FINDS = {
    "long_stair": [((11, 5), "max_tonic"), ((0, 13), "revival_leaf"), ((11, 19), "strong_tonic", 2)],
    "cloudshadow_meadow": [((0, 6), "remedy"), ((11, 10), "max_tonic"), ((0, 18), "dash_brew")],
    "mirror_flats": [((11, 4), "revival_leaf"), ((0, 13), "max_tonic"), ((11, 18), "wake_bell")],
    "orrery_ridge": [((11, 6), "spark_drop"), ((0, 10), "max_tonic"), ((11, 18), "revival_leaf")],
    "sunfall_terraces": [((11, 6), "power_brew"), ((0, 10), "max_tonic"), ((11, 18), "strong_tonic", 2)],
    "lantern_span": [((0, 12), "revival_leaf"), ((11, 14), "max_tonic"), ((0, 21), "guard_brew")],
}
# Wayfarers on each route: (id, x, y, facing, title EN/DE, team, talk, intro, defeat).
ROUTE_FOLK = {
    "long_stair": [("step_counter", 6, 15, "left", ("Step Counter Wendel", "Stufenzähler Wendel"), [("Highhare", 79), ("Noonwhist", 80)],
                    ("Wendel: Four hundred and twelve. Don't talk to me, I'll lose count. Then they'll count me.", "Wendel: Vierhundertzwölf. Sprich mich nicht an, sonst verzähle ich mich. Dann zählen sie mich."),
                    ("Wendel: You made me lose count. Now we fight, and then I start again.", "Wendel: Du hast mich aus dem Takt gebracht. Jetzt kämpfen wir, und dann fange ich von vorn an."),
                    ("Wendel: One. Two. Three...", "Wendel: Eins. Zwei. Drei..."))],
    "cloudshadow_meadow": [("goatherd", 6, 9, "left", ("Goatherd Sabina", "Ziegenhirtin Sabina"), [("Chirrik", 81), ("Palmop", 81), ("Hazejel", 82)],
                            ("Sabina: My goats eat the shadows of the clouds. Don't ask what they eat when it's sunny.", "Sabina: Meine Ziegen fressen die Schatten der Wolken. Frag nicht, was sie fressen, wenn die Sonne scheint."),
                            ("Sabina: You're standing in my best shadow. Move or fight.", "Sabina: Du stehst in meinem besten Schatten. Weg da, oder wir kämpfen."),
                            ("Sabina: Fine. Graze where you like.", "Sabina: Schön. Grase, wo du willst."))],
    "mirror_flats": [("salt_scout", 6, 13, "left", ("Salt Scout Hendrik", "Salzspäher Hendrik"), [("Saltsprig", 83), ("Stiltwade", 83), ("Wadishell", 84)],
                      ("Hendrik: I mark where the salt is thin. Then I sell the map to the people who want someone to fall through.", "Hendrik: Ich markiere, wo das Salz dünn ist. Dann verkaufe ich die Karte an die Leute, die wollen, dass jemand einbricht."),
                      ("Hendrik: You've got a thin look about you. Let's test it.", "Hendrik: Du siehst dünn aus. Testen wir das."),
                      ("Hendrik: Solid. Annoying.", "Hendrik: Fest. Ärgerlich."))],
    "orrery_ridge": [("climber", 6, 12, "left", ("Ridge Climber Agathe", "Gratkletterin Agathe"), [("Orrerine", 86), ("Obelith", 86), ("Highhare", 87)],
                      ("Agathe: I'm looking for the missing planet. Whoever finds it gets paid by three families. Whoever keeps it gets buried by four.", "Agathe: Ich suche den fehlenden Planeten. Wer ihn findet, wird von drei Familien bezahlt. Wer ihn behält, wird von vier begraben."),
                      ("Agathe: You're after the planet too. Don't lie, everyone is.", "Agathe: Du bist auch hinter dem Planeten her. Lüg nicht, alle sind es."),
                      ("Agathe: Keep looking. Up, not down.", "Agathe: Such weiter. Nach oben, nicht nach unten."))],
    "sunfall_terraces": [("vintner", 6, 10, "left", ("Vintner Ottavio", "Winzer Ottavio"), [("Corocub", 88), ("Obelith", 89), ("Bakedil", 89)],
                          ("Ottavio: The Gilt wine is aged in oak, in the dark, with a secret ingredient. The ingredient talked too much.", "Ottavio: Der Gilt-Wein reift in Eiche, im Dunkeln, mit einer geheimen Zutat. Die Zutat hat zu viel geredet."),
                          ("Ottavio: A taste? No. A fight. The wine is for family.", "Ottavio: Eine Kostprobe? Nein. Ein Kampf. Der Wein ist für die Familie."),
                          ("Ottavio: Fine vintage, that fight. Bitter finish.", "Ottavio: Feiner Jahrgang, dieser Kampf. Bitterer Abgang."))],
    "lantern_span": [("toll_boy", 4, 12, "right", ("Toll Boy Kasimir", "Zolljunge Kasimir"), [("Gyrevult", 91), ("Velvessa", 91), ("Ergskim", 91)],
                      ("Kasimir: Half the toll now, half when you reach the other side. If you don't, Veronne keeps the first half.", "Kasimir: Den halben Zoll jetzt, die andere Hälfte drüben. Wenn du nicht ankommst, behält Veronne die erste Hälfte."),
                      ("Kasimir: No coins? Then I'll take it in battle. Veronne's rules.", "Kasimir: Keine Münzen? Dann nehme ich es im Kampf. Veronnes Regeln."),
                      ("Kasimir: Paid in full. Don't look down.", "Kasimir: Vollständig bezahlt. Schau nicht nach unten."))],
}
ROUTE_LOOK = {"long_stair": "ridge", "cloudshadow_meadow": "field", "mirror_flats": "lake",
              "orrery_ridge": "ridge", "sunfall_terraces": "field", "lantern_span": "lake"}


# Side doors from a route to the landmark that stands on it.
LANDMARK_DOORS = {"long_stair": [warp(0, 8, "white_stair", 1, 8, "right")],
                  "lantern_span": [warp(11, 12, "gilt_span", 1, 10, "right")]}


def route(world, mid):
    sheet = sheet_entry("routes", mid)
    rows = list(ROUTE_ROWS[mid])
    signs = []
    text = {}
    for i, ((x, y), title, body) in enumerate(ROUTE_SIGNS[mid]):
        key = "sign" if i == 0 else "sign_%d" % (i + 1)
        if rows[y][x] != "S":
            raise SystemExit("%s: sign %s,%s is not on an S tile" % (mid, x, y))
        text[key] = lines(title, body)
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, key)})
    world.add_text(mid, text)
    people = []
    money = 3000 + 200 * ROUTES.index(mid)
    for pid, x, y, f, (title_en, title_de), crew, talk, intro, defeat in ROUTE_FOLK[mid]:
        people.append(wayfarer(world, mid, pid, x, y, f, tr(title_en, title_de), team(*crew), [talk], [intro], [defeat], money))
    m = {"name": tr(sheet["name"], DE.get(sheet["name"], sheet["name"])), "biome": "route", "backdrop": ROUTE_LOOK[mid],
         "outdoor": True, "encounters": mid, "rows": rows, "warps": exits(mid, ROUTE_H) + LANDMARK_DOORS.get(mid, []),
         "npcs": people, "signs": signs,
         "secrets": [secret(f[0][0], f[0][1], f[1], "find_%s_%d" % (mid, i + 1), f[2] if len(f) > 2 else 1)
                     for i, f in enumerate(ROUTE_FINDS[mid])]}
    finish(world, mid, m)


# --- Rifts ---------------------------------------------------------------------------------
RIFT_TEXT = {
    "orrery_rift": {"motto": ("Under the Great Orrery the stars come loose. Someone is catching them and selling them.", "Unter dem Großen Planetarium lösen sich die Sterne. Jemand fängt sie auf und verkauft sie."),
                    "acolyte": ("star_clerk", ("Star Clerk Benedikt", "Sternschreiber Benedikt"), [("Solmantle", 82), ("Orrerine", 82), ("Noonwhist", 83)],
                                ("Benedikt: Isaura reads the stars. I read Isaura. She's lying about at least two of them.", "Benedikt: Isaura liest die Sterne. Ich lese Isaura. Bei mindestens zwei davon lügt sie."),
                                ("Benedikt: Your horoscope says: a battle. Today. Now.", "Benedikt: Dein Horoskop sagt: ein Kampf. Heute. Jetzt."),
                                ("Benedikt: Your horoscope also said you'd lose. Refunds are not available.", "Benedikt: Dein Horoskop sagte auch, dass du verlierst. Rückerstattungen gibt es nicht.")),
                    "mended": ("Isaura: The stars sit still again. I'll have to make up the future myself now. Like always.", "Isaura: Die Sterne stehen wieder still. Jetzt muss ich mir die Zukunft wieder selbst ausdenken. Wie immer."),
                    "after": ("Isaura: The Gilt House paid me for your horoscope. You might want a new one. I'm offering a discount.", "Isaura: Das Haus Gilt hat mich für dein Horoskop bezahlt. Vielleicht willst du ein neues. Ich gebe Rabatt.")},
    "salt_rift": {"motto": ("Under the salt the old lake still remembers its water. And everyone it swallowed.", "Unter dem Salz erinnert sich der alte See noch an sein Wasser. Und an jeden, den er verschluckt hat."),
                  "acolyte": ("raker", ("Salt Foreman Gunda", "Salzvorarbeiterin Gunda"), [("Saltcrown", 86), ("Stiltregent", 86), ("Wadishell", 87)],
                              ("Gunda: Halloran pays by the barrel. The barrels don't ask what's in them.", "Gunda: Halloran zahlt pro Fass. Die Fässer fragen nicht, was drin ist."),
                              ("Gunda: You're on company salt. That's trespass. Trespass is a fight.", "Gunda: Du stehst auf Firmensalz. Das ist Hausfriedensbruch. Hausfriedensbruch ist ein Kampf."),
                              ("Gunda: Go on, then. He's below. He's always below.", "Gunda: Dann geh. Er ist unten. Er ist immer unten.")),
                  "mended": ("Halloran: The water's coming back. My salt is going to be worth nothing. You've ruined me. I'll send you a bill.", "Halloran: Das Wasser kommt zurück. Mein Salz wird nichts mehr wert sein. Du hast mich ruiniert. Ich schicke dir eine Rechnung."),
                  "after": ("Halloran: Oriel? She worked for me. Then I sold her. Business. She'd have done the same.", "Halloran: Oriel? Sie hat für mich gearbeitet. Dann habe ich sie verkauft. Geschäft. Sie hätte dasselbe getan.")},
    "span_rift": {"motto": ("Below the Gilt Span the air tears. Nobody who looked down has said what they saw.", "Unter dem Gilt-Bogen reißt die Luft. Keiner, der hinuntergeschaut hat, hat gesagt, was er gesehen hat."),
                  "acolyte": ("toll_clerk", ("Toll Clerk Emerich", "Zollschreiber Emerich"), [("Velverain", 90), ("Siroclaw", 90), ("Gyrevult", 91)],
                              ("Emerich: Veronne keeps a ledger of every crossing. The red column is for people who didn't make it.", "Emerich: Veronne führt Buch über jede Überquerung. Die rote Spalte ist für die, die es nicht geschafft haben."),
                              ("Emerich: Your name isn't in the ledger yet. Let me fix that.", "Emerich: Dein Name steht noch nicht im Buch. Das ändere ich."),
                              ("Emerich: Black column. For now.", "Emerich: Schwarze Spalte. Fürs Erste.")),
                  "mended": ("Veronne: The Span holds. My toll doesn't. Fine. I'll find another bridge. There's always another bridge.", "Veronne: Der Bogen hält. Mein Zoll nicht. Schön. Ich finde eine andere Brücke. Es gibt immer eine andere Brücke."),
                  "after": ("Veronne: Aurek's feast is tonight. I'm not going. I know who's cooking.", "Veronne: Aureks Fest ist heute Abend. Ich gehe nicht hin. Ich weiß, wer kocht.")},
    "gilt_rift": {"motto": ("Under the Gilt House the gold runs like water. The Rift drinks it. So does the family.", "Unter dem Haus Gilt fließt das Gold wie Wasser. Der Riss trinkt es. Die Familie auch."),
                  "acolyte": ("heir", ("Gilt Heir Leopold", "Gilt-Erbe Leopold"), [("Obelith", 94), ("Coronarch", 95), ("Rollibex", 95)],
                              ("Leopold: Father says the Rift is family business. Everything is family business. Even you.", "Leopold: Vater sagt, der Riss ist Familiensache. Alles ist Familiensache. Sogar du."),
                              ("Leopold: I'm the third heir. I need a win. Any win.", "Leopold: Ich bin der dritte Erbe. Ich brauche einen Sieg. Irgendeinen."),
                              ("Leopold: Don't tell Father. Actually, do. He'll be pleased someone beat me.", "Leopold: Sag es nicht Vater. Doch, sag es ihm. Er freut sich, dass mich jemand geschlagen hat.")),
                  "mended": ("Aurek: Mended. Good. Come to the feast tonight. Sit next to me. Taste everything first.", "Aurek: Geflickt. Gut. Komm heute Abend zum Fest. Setz dich neben mich. Probier alles zuerst."),
                  "after": ("Aurek: My children send their love. And a food taster's bill.", "Aurek: Meine Kinder lassen grüßen. Und schicken die Rechnung des Vorkosters.")},
}
RIFT_LOOK = {"orrery_rift": "voice", "salt_rift": "lake", "span_rift": "ridge", "gilt_rift": "ember"}


def rift(world, mid):
    sheet = sheet_entry("rifts", mid)
    w = sheet_entry("wardens", sheet["warden"])
    key = mid[:-5]
    t = RIFT_TEXT[mid]
    rows = base_rows(".")
    world.add_text(mid, {
        "spring": {"lines": lines(("Clear water wells up through white stone. It tastes of nothing at all, which up here is a luxury.", "Klares Wasser quillt durch weißen Stein. Es schmeckt nach gar nichts, und das ist hier oben ein Luxus."),
                                  ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")),
                   "action": "heal"},
        "sign": lines((sheet["name"].upper(), DE[sheet["name"]].upper()), t["motto"]),
    })
    pid, (title_en, title_de), crew, talk, intro, defeat = t["acolyte"]
    acolyte = wayfarer(world, mid, pid, 7, 17, "left", tr(title_en, title_de), team(*crew), [talk], [intro], [defeat], int(w["money"]) // 2, sprite="warden")
    wid = w["id"]
    world.add_text(mid, {
        wid: {"lines": lines((w["intro"], DE[w["intro"]])), "after_flag": [{"flag": sheet["flag"], "lines": lines(t["mended"], t["after"])}]},
        wid + "_intro": lines((w["intro"], DE[w["intro"]])),
        wid + "_defeat": lines((w["defeat"], DE[w["defeat"]])),
    })
    crew = [{"species": e["species"] or e["stand_in"], "level": e["level"]} for e in w["team"]]
    warden = npc("warden_" + wid, 5, 2, "down", "%s/%s" % (mid, wid), "warden", trainer=tr(w["name"], w["name"]),
                 warden="v4_" + key, team=crew, intro="%s/%s_intro" % (mid, wid), defeat="%s/%s_defeat" % (mid, wid),
                 ai=2, money=int(w["money"]))
    m = {"name": tr(sheet["name"], DE[sheet["name"]]), "biome": "rift", "backdrop": RIFT_LOOK[mid],
         "heal_point": [3, 5], "rows": rows, "warps": exits(mid, RIFT_H),
         "npcs": [acolyte, warden],
         "signs": [{"x": 3, "y": 4, "dialogue": mid + "/spring"}, {"x": 8, "y": 5, "dialogue": mid + "/sign"}],
         "blocks": [gate(10, 18, sheet["flag"])]}
    finish(world, mid, m)


# --- The Great Orrery (inside Starwell): brass planets the size of houses ----------------------
def great_orrery(world):
    mid = "great_orrery"
    lm = [l for l in SHEET["landmarks"] if l["id"] == "great_orrery"][0]
    rows = ["WWWWWWWWWWWW",
            "Wf|ff||ff|fW",
            "WffffffffffW",
            "Wf|ffSff|ffW",
            "WffffffffffW",
            "WfS|ffff|SfW",
            "WffffffffffW",
            "Wf|ffffff|fW",
            "WffffffffffW",
            "WWWWWDWWWWWW"]
    world.add_text(mid, {
        "plaque": lines((lm["name"].upper(), DE[lm["name"]].upper()), (lm["text"], DE[lm["text"]])),
        "gap": lines(("An empty brass arm turns slowly over your head. It held a planet once. A label on it reads: RETURN TO THE GILT HOUSE. NO QUESTIONS ASKED. SOME QUESTIONS ASKED.", "Ein leerer Messingarm dreht sich langsam über deinem Kopf. Er hielt einmal einen Planeten. Ein Schild daran: AN DAS HAUS GILT ZURÜCKGEBEN. KEINE FRAGEN. EINIGE FRAGEN.")),
        "ledger": lines(("A visitors' ledger. Every name is crossed out except the last one. The last one is yours. It is written in someone else's hand.", "Ein Besucherbuch. Jeder Name ist durchgestrichen außer dem letzten. Der letzte ist deiner. Er ist in einer fremden Handschrift geschrieben.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "voice", "rows": rows,
         "warps": [warp(5, 9, "starwell", 9, 14, "down")],
         "npcs": [],
         "signs": [{"x": 5, "y": 3, "dialogue": mid + "/plaque"}, {"x": 2, "y": 5, "dialogue": mid + "/gap"},
                   {"x": 9, "y": 5, "dialogue": mid + "/ledger"}]}
    finish(world, mid, m)


def landmark_texts(lid):
    lm = [l for l in SHEET["landmarks"] if l["id"] == lid][0]
    return lm, lines((lm["name"].upper(), DE[lm["name"]].upper()), (lm["text"], DE[lm["text"]]))


# --- The White Stair (beside the Long Stair): the landing where the Gilt House counts the steps --
def white_stair(world):
    mid = "white_stair"
    lm, plaque = landmark_texts(mid)
    rows = ["^^^^^^^^^^^^",
            "^T..T..T..T^",
            "^...TS.T...^",
            "^..........^",
            "^.TT....TT.^",
            "^.**....**.^",
            "^..........^",
            "^.S......*.^",
            "_____......^",
            "^..........^",
            "^T........T^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "plaque": plaque,
        "tally": lines(("A slate of tally marks, nine hundred to a row. One row ends at eight hundred and ninety-nine. Someone has scratched beside it: FOUND HIM.", "Eine Schiefertafel voller Striche, neunhundert pro Reihe. Eine Reihe endet bei achthundertneunundneunzig. Daneben hat jemand eingeritzt: IHN GEFUNDEN.")),
        "counter": lines(("Head Counter Ilsabe: Nine hundred steps. Every morning. If the number is wrong, we count again. If it's still wrong, we count the counters.", "Oberzählerin Ilsabe: Neunhundert Stufen. Jeden Morgen. Stimmt die Zahl nicht, zählen wir noch einmal. Stimmt sie dann noch nicht, zählen wir die Zähler."),
                         ("Ilsabe: Last spring we were one counter short. The stairs were fine.", "Ilsabe: Letzten Frühling fehlte uns ein Zähler. Die Treppe war in Ordnung.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "ridge", "outdoor": True, "rows": rows,
         "warps": [warp(0, 8, "long_stair", 1, 8, "right")],
         "npcs": [npc("counter", 6, 3, "down", mid + "/counter", "elder")],
         "signs": [{"x": 5, "y": 2, "dialogue": mid + "/plaque"}, {"x": 2, "y": 7, "dialogue": mid + "/tally"}],
         "secrets": [secret(11, 3, "max_tonic", "find_white_stair_1"), secret(0, 6, "focus_brew", "find_white_stair_2"),
                     secret(6, 11, "revival_leaf", "find_white_stair_3")]}
    finish(world, mid, m)


# --- The Gilt Span (off the Lantern Span): the gallery of lanterns, one for each fall ------------
def gilt_span(world):
    mid = "gilt_span"
    lm, plaque = landmark_texts(mid)
    rows = ["^^^^^^^^^^^^",
            "^L.L.L.L.L.^",
            "^..........^",
            "^.S......S.^",
            "^..........^",
            "^L........L^",
            "^..T....T..^",
            "^..........^",
            "^..........^",
            "^.L......L.^",
            "____.......^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "plaque": plaque,
        "names": lines(("Names are etched under each lantern. The newest plate is blank, polished and already paid for.", "Unter jeder Laterne sind Namen eingraviert. Die neueste Platte ist leer, poliert und schon bezahlt.")),
        "lamplighter": lines(("Lamplighter Mireille: I light one lantern for every fall. Business has never been better.", "Laternenanzünderin Mireille: Ich zünde für jeden Absturz eine Laterne an. Das Geschäft lief nie besser."),
                             ("Mireille: The families pay. Veronne collects. I just hold the match.", "Mireille: Die Familien zahlen. Veronne kassiert. Ich halte nur das Streichholz.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "lake", "outdoor": True, "rows": rows,
         "warps": [warp(0, 10, "lantern_span", 10, 12, "left")],
         "npcs": [npc("lamplighter", 6, 7, "down", mid + "/lamplighter", "villager")],
         "signs": [{"x": 2, "y": 3, "dialogue": mid + "/plaque"}, {"x": 9, "y": 3, "dialogue": mid + "/names"}],
         "secrets": [secret(11, 4, "max_tonic", "find_gilt_span_1"), secret(0, 7, "guard_brew", "find_gilt_span_2"),
                     secret(5, 11, "remedy", "find_gilt_span_3")]}
    finish(world, mid, m)
