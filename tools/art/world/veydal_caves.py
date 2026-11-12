"""Veydal caves (area 3 items 978 to 983): Murk Hollow with its lower level Echo Gallery,
Mossmere Grotto under Gloamwood, the sea cave Sablecove off Brackwater Fen and Kindle Vents at
the foot of Cinder Rift. Each cave has a campfire that saves but does not heal (item 992). Maps here are generated: edit this file, then run build_world.py.

Every cave entrance has a sign that shows the gear needed inside (item 982). Caves with more
than one level have a rope back from the deepest point to the entrance that is let down from
inside with a lever (item 983). Sablecove's inner chamber is only open at low tide (blocks on
the clock flag "_low_tide"), Kindle Vents' vents block the way on a 4 second beat
("_vents_calm"), see WorldMechanics.
"""
from common import check_rows, lines, secret, tr, warp

GROUP = ["murk_hollow", "mossmere_grotto", "sablecove", "kindle_vents"]

# Item 1081: Murk Hollow's two find signs become hidden finds (flags and texts kept).
OLD_FINDS = [("murk_hollow", "gallery_find", "spark_coil", 1), ("murk_hollow", "nook_find", "echo_umbra", 1)]


def set_char(m, x, y, ch):
    r = m["rows"][y]
    m["rows"][y] = r[:x] + ch + r[x + 1:]


def put_warp(m, w):
    m["warps"] = [o for o in m.get("warps", []) if (o["x"], o["y"]) != (w["x"], w["y"])] + [w]


def put_sign(m, x, y, ref, gear):
    m["signs"] = [s for s in m.get("signs", []) if (s["x"], s["y"]) != (x, y)]
    m["signs"].append({"x": x, "y": y, "dialogue": ref, "gear": gear})
    set_char(m, x, y, "S")


def entrance(world, outside, door, sign_cell, cave, arrive, facing, text, gear):
    """A door into [cave] on [outside] and a sign next to it with the gear icons (item 982)."""
    m = world.load_map(outside)
    set_char(m, door[0], door[1], "D")
    put_warp(m, warp(door[0], door[1], cave, arrive[0], arrive[1], facing))
    world.add_text(outside, {cave + "_sign": lines(*text)})
    put_sign(m, sign_cell[0], sign_cell[1], "%s/%s_sign" % (outside, cave), gear)


def rope_back(world, mid, key, flag):
    """The lever that lets the rope down to the entrance (item 983); it works from inside only."""
    world.add_text(mid, {key: {"lines": lines(("A coiled rope hangs on a hook by a lever.", "Ein aufgerolltes Seil hängt an einem Haken neben einem Hebel.")),
                               "action": "lever " + flag}})


# Item 992: every cave has a rest place with a campfire ("L") that saves but does not heal.
CAMPS = {"murk_hollow": (10, 10), "mossmere_grotto": (10, 9), "sablecove": (1, 5), "kindle_vents": (10, 8)}


def campfire(world, mid, x, y):
    m = world.load_map(mid)
    m["signs"] = [s for s in m.get("signs", []) if (s["x"], s["y"]) != (x, y)]
    m["signs"].append({"x": x, "y": y, "dialogue": mid + "/campfire"})
    set_char(m, x, y, "L")
    m["camp"] = [x, y]
    world.add_text(mid, {"campfire": {"lines": lines(("A ring of stones with a small fire. Someone keeps it going for travellers.", "Ein Steinring mit einem kleinen Feuer. Jemand hält es für Reisende am Brennen.")),
                                      "action": "camp"}})


def build(world):
    murk_hollow(world)
    mossmere_grotto(world)
    sablecove(world)
    kindle_vents(world)
    for mid, (x, y) in CAMPS.items():
        campfire(world, mid, x, y)


def murk_hollow(world):
    m = world.load_map("murk_hollow")
    m["biome"] = "cave"
    for mid, key, item, count in OLD_FINDS:
        mm = world.load_map(mid)
        ref = "%s/%s" % (mid, key)
        old = [s for s in mm.get("signs", []) if s.get("dialogue") == ref]
        if old:
            s = old[0]
            mm["signs"].remove(s)
            entry = world.dialogue(mid)[key]
            find = secret(s["x"], s["y"], item, entry["flag"], count)
            find["dialogue"] = ref
            mm.setdefault("secrets", []).append(find)
    # Item 980: stairs down to the Echo Gallery behind the lamp door.
    set_char(m, 8, 1, "=")
    put_warp(m, warp(8, 1, "murk_hollow@1", 3, 1, "right"))
    rows = ["@@@@@@@@@@@@",
            "@.=.......:@",
            "@.@@@@@@@@.@",
            "@.@::....@.@",
            "@.@.@@@@.@.@",
            "@.@.@=S@.@.@",
            "@.@.@..@.@.@",
            "@...@..v...@",
            "@@@@@@@@@@@@"]
    check_rows("murk_hollow@1", rows)
    rope_back(world, "murk_hollow", "echo_rope", "echo_rope")
    m["floors"] = [{
        "name": tr("Echo Gallery", "Echogalerie"), "encounters": "echo_gallery", "rows": rows,
        "warps": [warp(2, 1, "murk_hollow", 8, 2, "down"), warp(5, 5, "murk_hollow", 5, 11, "up")],
        "signs": [{"x": 6, "y": 5, "dialogue": "murk_hollow/echo_rope"}],
        "blocks": [{"x": 5, "y": 5, "open_flag": "echo_rope"}],
        "secrets": [secret(3, 3, "max_tonic", "find_echo_corner"), secret(10, 1, "remedy", "find_echo_far")],
    }]
    entrance(world, "crowcrest", (9, 14), (10, 15), "murk_hollow", (5, 11), "up",
             [("MURK HOLLOW", "MURKSENKE"), ("Inside: Storm Lantern, Climbing Pick.", "Drinnen: Sturmlaterne, Kletterhaken.")],
             ["storm_lantern", "climbing_pick"])


def mossmere_grotto(world):
    mid = "mossmere_grotto"
    top = ["@@@@@@@@@@@@",
           "@.,,..@@.=.@",
           "@.,,,.@@...@",
           "@..,..@@,,.@",
           "@.....ww...@",
           "@.,,..@@,..@",
           "@.....@@...@",
           "@...__..@@@@",
           "@:..__..::.@",
           "@...__.....@",
           "@@@@@__@@@@@"]
    low = ["@@@@@@@@@@@@",
           "@..,,.@..=.@",
           "@.,,,.@....@",
           "@..,..Y....@",
           "@.,...@.,,.@",
           "@=....@....@",
           "@.S...@@@@@@",
           "@@@@@@@@@@@@"]
    check_rows(mid, top)
    check_rows(mid + "@1", low)
    rope_back(world, mid, "rope", "mossmere_rope")
    m = {"name": tr("Mossmere Grotto", "Moosseegrotte"), "region": "veydal", "biome": "cave", "backdrop": "ridge",
         "field": "deep_murk", "encounters": mid, "rows": top,
         "warps": [warp(5, 10, "gloamwood", 3, 7, "down"), warp(6, 10, "gloamwood", 3, 7, "down"),
                   warp(9, 1, mid + "@1", 9, 2, "down")],
         "secrets": [secret(1, 1, "tonic", "find_moss_nook", 2), secret(10, 6, "kin_charm", "find_moss_pool")],
         "floors": [{
             "name": tr("Mossmere Grotto, lower pool", "Moosseegrotte, unterer Teich"), "rows": low,
             "warps": [warp(9, 1, mid, 9, 2, "down"), warp(1, 5, mid, 5, 9, "up")],
             "signs": [{"x": 2, "y": 6, "dialogue": mid + "/rope"}],
             "blocks": [{"x": 1, "y": 5, "open_flag": "mossmere_rope"}],
             "secrets": [secret(1, 1, "max_tonic", "find_moss_deep")],
         }]}
    world.add_map(mid, m)
    entrance(world, "gloamwood", (3, 6), (2, 7), mid, (5, 9), "up",
             [("MOSSMERE GROTTO", "MOOSSEEGROTTE"), ("Inside: Wading Boots, Plank Bundle.", "Drinnen: Watstiefel, Plankenbündel.")],
             ["wading_boots", "plank_bundle"])


def sablecove(world):
    mid = "sablecove"
    rows = ["@@@@@@@@@@@@",
            "@..%%.@.,,.@",
            "@.%%..@....@",
            "@..ww......@",
            "@.%%..@....@",
            "@.....@@@@@@",
            "@~~...~~~..@",
            "@~~S....~..@",
            "@@@@@__@@@@@"]
    check_rows(mid, rows)
    world.add_text(mid, {"tide": lines(("Sea water stands in the gap. At low tide it runs out.",
                                        "Im Spalt steht Meerwasser. Bei Ebbe läuft es ab.")),
                         # Item 985: the tide stone at the entrance shows the next low tide.
                         "tide_stone": {"lines": lines(("A tide stone. Lines and hours are scratched into it by many hands.",
                                                        "Ein Gezeitenstein. Viele Hände haben Striche und Stunden hineingeritzt.")),
                                        "action": "tide_stone"}})
    m = {"name": tr("Sablecove", "Zobelbucht"), "region": "veydal", "biome": "cave", "backdrop": "lake",
         "field": "deep_murk", "encounters": mid, "rows": rows,
         "warps": [warp(5, 8, "brackwater_fen", 10, 16, "left"), warp(6, 8, "brackwater_fen", 10, 16, "left")],
         # Item 979: the inner chamber (right) opens at low tide only. Closed, the gap is water.
         "blocks": [{"x": 6, "y": 3, "open_flag": "_low_tide", "closed": "~"}],
         "signs": [{"x": 3, "y": 7, "dialogue": mid + "/tide_stone"}],
         # Item 995: shell beds on the sand give a find at low tide; at high tide they are under water.
         "secrets": [secret(10, 1, "max_tonic", "find_sable_inner"), secret(1, 1, "spark_drop", "find_sable_shelf"),
                     dict(secret(4, 6, "remedy", "find_sable_shells_a"), when="_low_tide"),
                     dict(secret(7, 7, "tonic", "find_sable_shells_b", 2), when="_low_tide")]}
    world.add_map(mid, m)
    entrance(world, "brackwater_fen", (11, 16), (10, 15), mid, (5, 7), "up",
             [("SABLECOVE", "ZOBELBUCHT"), ("Inside: Wading Boots. The inner chamber opens at low tide.",
                                            "Drinnen: Watstiefel. Die innere Kammer öffnet sich bei Ebbe.")],
             ["wading_boots"])


def kindle_vents(world):
    mid = "kindle_vents"
    rows = ["@@@@@@@@@@@@",
            "@::.....::.@",
            "@:..@@@@...@",
            "@...@::@.:.@",
            "@@@@@..@@Y@@",
            "@..:....:..@",
            "@.:......:.@",
            "@@@@@__@@@@@",
            "@....__....@",
            "@@@@@__@@@@@"]
    check_rows(mid, rows)
    m = {"name": tr("Kindle Vents", "Glutschlote"), "region": "veydal", "biome": "cave", "backdrop": "ridge",
         "field": "deep_murk", "encounters": mid, "rows": rows,
         "warps": [warp(5, 9, "cinder_rift", 1, 8, "right"), warp(6, 9, "cinder_rift", 1, 8, "right")],
         # Item 981: two hot vents block the only way up every other two seconds.
         "blocks": [{"x": 5, "y": 7, "open_flag": "_vents_calm"}, {"x": 6, "y": 7, "open_flag": "_vents_calm"}],
         "secrets": [secret(5, 3, "spark_drop", "find_kindle_pocket"), secret(10, 1, "max_tonic", "find_kindle_ledge")]}
    world.add_map(mid, m)
    entrance(world, "cinder_rift", (0, 8), (1, 7), mid, (5, 8), "up",
             [("KINDLE VENTS", "GLUTSCHLOTE"), ("Inside: Plank Bundle. Hot vents blow every few seconds: wait for the calm.",
                                               "Drinnen: Plankenbündel. Heiße Schlote blasen alle paar Sekunden: warte auf die Ruhe.")],
             ["plank_bundle"])
