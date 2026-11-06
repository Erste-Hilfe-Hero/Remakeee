"""Veydal puzzle dungeons (area 3 items 1008 to 1011): Bellstone Ruins, Brackwater Sluice,
Lanternwell and Shatterfloor Mine. Each dungeon is one map file with one floor per room.
Maps here are generated: edit this file, then run tools/art/build_world.py.
"""
from common import check_rows, lines, secret, tr, warp

GROUP = ["bellstone_ruins", "brackwater_sluice", "lanternwell", "shatterfloor_mine"]


def set_char(m, x, y, ch):
    r = m["rows"][y]
    m["rows"][y] = r[:x] + ch + r[x + 1:]


def put_warp(m, w):
    m["warps"] = [o for o in m.get("warps", []) if (o["x"], o["y"]) != (w["x"], w["y"])] + [w]


def fid(mid, n):
    return mid if n == 0 else "%s@%d" % (mid, n)


def build(world):
    bellstone_ruins(world)
    brackwater_sluice(world)
    lanternwell(world)
    shatterfloor_mine(world)


def rooms(world, mid, name, rooms_, base):
    """Turns a list of room dicts into one map with floors."""
    first = dict(rooms_[0])
    first.update(base)
    first["name"] = name
    if len(rooms_) > 1:
        first["floors"] = rooms_[1:]
    world.add_map(mid, first)


def stair_warps(mid, n, count, back_to, top=(5, 0), bottom=(5, 6), arrive_up=(5, 5), arrive_down=(5, 1)):
    """Stairs up to the next room (top) and back down (bottom) of room [n]."""
    out = []
    bx, by = bottom
    for dx in (0, 1):
        if n == 0:
            out.append(warp(bx + dx, by, back_to[0], back_to[1], back_to[2], "down"))
        else:
            out.append(warp(bx + dx, by, fid(mid, n - 1), arrive_down[0] + dx, arrive_down[1], "down"))
        if n < count - 1:
            out.append(warp(top[0] + dx, top[1], fid(mid, n + 1), arrive_up[0] + dx, arrive_up[1], "up"))
    return out


# --- Bellstone Ruins: ring the bells in the order scratched on the wall (item 1008) ---------
BELLS = [("small", "klein"), ("deep", "tief"), ("cracked", "gesprungen"), ("green", "grün"), ("starred", "mit Stern")]
BELL_CELLS = [(2, 2), (5, 2), (8, 2), (4, 4), (7, 4)]
# Per room: which bell (index into BELLS) is rung 1st, 2nd, ...
BELL_ORDERS = [[1, 0, 2], [2, 1, 0], [0, 3, 1, 2], [3, 2, 0, 1], [4, 1, 3, 0, 2]]


def bellstone_ruins(world):
    mid = "bellstone_ruins"
    count = len(BELL_ORDERS)
    text = {}
    out = []
    for n, order in enumerate(BELL_ORDERS):
        rows = ["@@@@@==@@@@@" if n < count - 1 else "@@@@@@@@@@@@",
                "@..........@",
                "@..........@",
                "@..........@",
                "@..........@",
                "@:........:@",
                "@@@@@__@@@@@"]
        flag = "bell_room_%d" % (n + 1)
        signs = []
        bells = sorted(order)
        for b in bells:
            x, y = BELL_CELLS[b]
            rows[y] = rows[y][:x] + "S" + rows[y][x + 1:]
            key = "r%d_bell_%d" % (n + 1, b)
            en, de = BELLS[b]
            text[key] = {"lines": lines(("A %s bell hangs from a beam." % en, "Eine Glocke (%s) hängt an einem Balken." % de)),
                         "action": "bell %s %d %d" % (flag, order.index(b) + 1, len(order))}
            signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, key)})
        rows[4] = rows[4][:1] + "S" + rows[4][2:]
        wall_en = ", then ".join("the %s bell" % BELLS[b][0] for b in order)
        wall_de = ", dann ".join("die Glocke (%s)" % BELLS[b][1] for b in order)
        text["r%d_wall" % (n + 1)] = lines(("Scratched into the wall: " + wall_en + ".",
                                            "In die Wand geritzt: " + wall_de + "."))
        signs.append({"x": 1, "y": 4, "dialogue": "%s/r%d_wall" % (mid, n + 1)})
        check_rows(fid(mid, n), rows)
        room = {"rows": rows, "signs": signs, "warps": stair_warps(mid, n, count, ("gloamwood", 4, 1))}
        if n < count - 1:
            room["goal"] = tr("Goal: ring the bells in the order scratched into the wall.", "Ziel: Läute die Glocken in der Reihenfolge, die in die Wand geritzt ist.")
            room["blocks"] = [{"x": 5, "y": 0, "open_flag": flag}, {"x": 6, "y": 0, "open_flag": flag}]
        else:
            room["secrets"] = [secret(5, 1, "max_tonic", "find_bell_top", 2), secret(10, 1, "kin_charm", "find_bell_corner")]
        if n > 0:
            room["name"] = tr("Bellstone Ruins, hall %d" % (n + 1), "Glockenstein-Ruine, Halle %d" % (n + 1))
        out.append(room)
    world.add_text(mid, text)
    rooms(world, mid, tr("Bellstone Ruins", "Glockenstein-Ruine"), out,
          {"region": "veydal", "biome": "dungeon", "backdrop": "ridge", "field": "deep_murk", "encounters": mid})
    g = world.load_map("gloamwood")
    set_char(g, 4, 0, "_")
    put_warp(g, warp(4, 0, mid, 5, 5, "up"))


# --- Brackwater Sluice: three wheels set the water level for all six rooms (item 1009) ------
SLUICES = ["sluice_a", "sluice_b", "sluice_c"]
# Per room: the sluice wheel found here (or None) and the clock flag the walkway needs.
SLUICE_ROOMS = [("sluice_a", "_water_ge_1"), (None, "_water_le_1"), ("sluice_b", "_water_ge_2"),
                (None, "_water_le_2"), ("sluice_c", "_water_ge_3"), (None, "_water_ge_0")]


def brackwater_sluice(world):
    mid = "brackwater_sluice"
    count = len(SLUICE_ROOMS)
    text = {}
    out = []
    for n, (wheel, need) in enumerate(SLUICE_ROOMS):
        rows = ["@@@@@==@@@@@" if n < count - 1 else "@@@@@@@@@@@@",
                "@~~~~++~~~~@",
                "@~~~~++~~~~@",
                "@~~~~++~~~~@",
                "@..........@",
                "@:........:@",
                "@@@@@__@@@@@"]
        room = {"rows": rows, "sluices": SLUICES, "warps": stair_warps(mid, n, count, ("brackwater_fen", 1, 13)),
                "goal": tr("Goal: set the water level with the sluice wheels so the walkway is clear.", "Ziel: Stell mit den Schleusenrädern den Wasserstand so ein, dass der Steg frei wird.")}
        # The middle of the walkway is a pontoon or a low pier, open only at the right level.
        closed = "~"
        room["blocks"] = [{"x": 5, "y": 2, "open_flag": need, "closed": closed},
                          {"x": 6, "y": 2, "open_flag": need, "closed": closed}]
        if wheel:
            rows[4] = rows[4][:3] + "S" + rows[4][4:]
            text[wheel] = {"lines": lines(("A great iron wheel works a sluice gate.", "Ein großes Eisenrad bewegt ein Schleusentor.")),
                           "action": "toggle " + wheel}
            room["signs"] = [{"x": 3, "y": 4, "dialogue": "%s/%s" % (mid, wheel)}]
        if n == count - 1:
            room["secrets"] = [secret(1, 4, "max_tonic", "find_sluice_end", 2), secret(10, 5, "spark_drop", "find_sluice_corner")]
        if n > 0:
            room["name"] = tr("Brackwater Sluice, basin %d" % (n + 1), "Brackschleuse, Becken %d" % (n + 1))
        check_rows(fid(mid, n), rows)
        out.append(room)
    world.add_text(mid, text)
    rooms(world, mid, tr("Brackwater Sluice", "Brackschleuse"), out,
          {"region": "veydal", "biome": "dungeon", "backdrop": "lake", "field": "deep_murk", "encounters": mid})
    f = world.load_map("brackwater_fen")
    set_char(f, 0, 13, "D")
    put_warp(f, warp(0, 13, mid, 5, 5, "up"))


# --- Lanternwell: mirrors steer a beam onto a crystal (item 1010) ---------------------------
DIRS = {"right": (1, 0), "left": (-1, 0), "up": (0, -1), "down": (0, 1)}


def way(d, e):
    """The mirror ("/" or "\\") that turns direction d into e."""
    return "/" if (-d[1], -d[0]) == e else "\\"


# Per room: beam source on the west wall (y), corners of the path, target, decoy mirrors.
BEAMS = [
    {"y": 2, "path": [(8, 2)], "target": (8, 5), "decoys": [(3, 4)]},
    {"y": 2, "path": [(3, 2), (3, 5)], "target": (10, 5), "decoys": [(7, 3)]},
    {"y": 1, "path": [(9, 1), (9, 4), (4, 4)], "target": (4, 2), "decoys": [(6, 2), (2, 5)]},
    {"y": 5, "path": [(2, 5), (2, 2), (6, 2), (6, 4)], "target": (10, 4), "decoys": [(9, 2)]},
    {"y": 3, "path": [(2, 3), (2, 1), (9, 1), (9, 4), (5, 4)], "target": (5, 2), "decoys": [(10, 3), (1, 5)]},
]


def lanternwell(world):
    mid = "lanternwell"
    count = len(BEAMS)
    text = {"crystal": lines(("A clear crystal, dull and cold. It waits for light.", "Ein klarer Kristall, matt und kalt. Er wartet auf Licht."))}
    out = []
    for n, b in enumerate(BEAMS):
        rows = ["@@@@@==@@@@@" if n < count - 1 else "@@@@@@@@@@@@",
                "@..........@", "@..........@", "@..........@", "@..........@", "@:........:@",
                "@@@@@__@@@@@"]
        flag = "beam_room_%d" % (n + 1)
        d = (1, 0)
        cur = (0, b["y"])
        mirrors = []
        signs = []
        corners = b["path"] + [b["target"]]
        for i, c in enumerate(b["path"]):
            nxt = corners[i + 1]
            e = ((nxt[0] > c[0]) - (nxt[0] < c[0]), (nxt[1] > c[1]) - (nxt[1] < c[1]))
            good = way(d, e)
            # Every other mirror starts the wrong way round.
            start = good if i % 2 else ("/" if good == "\\" else "\\")
            mirrors.append([c[0], c[1], start])
            d = e
        for c in b["decoys"]:
            mirrors.append([c[0], c[1], "/"])
        for mx, my, _w in mirrors:
            rows[my] = rows[my][:mx] + "S" + rows[my][mx + 1:]
            signs.append({"x": mx, "y": my, "dialogue": "%s/mirror_%d_%d_%d" % (mid, n, mx, my)})
            text["mirror_%d_%d_%d" % (n, mx, my)] = {"lines": lines(("A tall mirror on a turning stand.", "Ein hoher Spiegel auf einem Drehgestell.")),
                                                     "action": "mirror %d %d" % (mx, my)}
        tx, ty = b["target"]
        rows[ty] = rows[ty][:tx] + "S" + rows[ty][tx + 1:]
        signs.append({"x": tx, "y": ty, "dialogue": mid + "/crystal"})
        check_rows(fid(mid, n), rows)
        room = {"rows": rows, "signs": signs, "warps": stair_warps(mid, n, count, ("lighthouse", 2, 6)),
                "beam": {"x": 0, "y": b["y"], "dir": "right", "mirrors": mirrors, "target": [tx, ty], "flag": flag},
                "goal": tr("Goal: turn the mirrors so the light reaches the crystal.", "Ziel: Dreh die Spiegel so, dass das Licht den Kristall erreicht.")}
        if n < count - 1:
            room["blocks"] = [{"x": 5, "y": 0, "open_flag": flag}, {"x": 6, "y": 0, "open_flag": flag}]
        else:
            room["secrets"] = [secret(1, 1, "max_tonic", "find_well_top", 2)]
        if n > 0:
            room["name"] = tr("Lanternwell, chamber %d" % (n + 1), "Laternenbrunnen, Kammer %d" % (n + 1))
        out.append(room)
    world.add_text(mid, text)
    rooms(world, mid, tr("Lanternwell", "Laternenbrunnen"), out,
          {"region": "veydal", "biome": "dungeon", "backdrop": "lake", "field": "deep_murk", "encounters": mid})
    lh = world.load_map("lighthouse")
    set_char(lh, 1, 6, "=")
    put_warp(lh, warp(1, 6, mid, 5, 5, "up"))


# --- Shatterfloor Mine: cracked floor gives way to the floor below (item 1011) -------------
def shatterfloor_mine(world):
    mid = "shatterfloor_mine"
    top = ["@@@@@@@@@@@@",
           "@.....kkk..@",
           "@.kkk.k.k..@",
           "@.k.kkk.k..@",
           "@.k.....kk.@",
           "@.kkkkk..k.@",
           "@:....k..k:@",
           "@@@@@__@@@@@"]
    low = ["@@@@@@@@@@@@",
           "@::........@",
           "@..::......@",
           "@......::..@",
           "@...::.....@",
           "@..........@",
           "@=.........@",
           "@@@@@@@@@@@@"]
    check_rows(mid, top)
    check_rows(mid + "@1", low)
    world.add_text(mid, {"ladder": lines(("A ladder leads back up to the mine entrance.", "Eine Leiter führt zurück hinauf zum Mineneingang."))})
    m = {"name": tr("Shatterfloor Mine", "Splitterboden-Mine"), "region": "veydal", "biome": "dungeon", "backdrop": "ridge",
         "field": "deep_murk", "encounters": mid, "rows": top, "drop_to": mid + "@1",
         "goal": tr("Goal: cross the cracked floor without breaking through.", "Ziel: Überquere den rissigen Boden, ohne durchzubrechen."),
         "warps": [warp(5, 7, "copperfold", 6, 1, "down"), warp(6, 7, "copperfold", 6, 1, "down")],
         "secrets": [secret(10, 1, "max_tonic", "find_shatter_far", 2)],
         "floors": [{"name": tr("Shatterfloor Mine, lower gallery", "Splitterboden-Mine, untere Strecke"), "rows": low,
                     "warps": [warp(1, 6, mid, 5, 6, "up")],
                     "secrets": [secret(10, 6, "spark_drop", "find_shatter_low")]}]}
    world.add_map(mid, m)
    c = world.load_map("copperfold")
    set_char(c, 6, 0, "_")
    put_warp(c, warp(6, 0, mid, 5, 6, "up"))
