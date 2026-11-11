"""Ashmere, Act III (docs/STORY.md "Places with fixed map ids"): the station of the mountain
railway, Cinderfold with the gravers' hall, the Kiln Rift, the Saltglass flats with the silent
lighthouse, the Glass Rift, the far end of the Wide Rift and the three parts of the Undrawn.
Region "ashmere". Edit here, then run tools/art/build_world.py.

Area 4 places the story figures through data/story_npcs.json on the named "spots".
How the way opens:
  greyreach <-> ashmere_station     mountain railway, line "mountain_rail", open_flag act2_end
  saltglass -> wide_rift_far        veit_plate_done (chapter 15)
  saltglass -> shade_rift           veit_plate_done (the silent lighthouse door, tools/art/world/rifts12.py)
  saltglass -> ochrewell            rift_shade_sealed (the sand road south to Solenne, tools/art/world/solenne.py)
  wide_rift_far -> undrawn_1        undrawn_reached (scene undrawn_enter, guild seal)
"""
from common import check_rows, lines, npc, secret, team, tr, warp

GROUP = ["ashmere_station", "cinderfold", "gravers_hall", "kiln_rift", "saltglass", "glass_rift",
         "wide_rift_far", "undrawn_1", "undrawn_2", "undrawn_3"]


def gate(x, y, flag):
    return {"x": x, "y": y, "open_flag": flag, "closed": "#"}


def wayfarer(world, mid, id_, x, y, facing, title, crew, talk, intro, defeat, money, sprite="villager"):
    world.add_text(mid, {id_: lines(*talk), id_ + "_intro": lines(*intro), id_ + "_defeat": lines(*defeat)})
    return npc(id_, x, y, facing, "%s/%s" % (mid, id_), sprite, trainer=title,
               intro="%s/%s_intro" % (mid, id_), defeat="%s/%s_defeat" % (mid, id_), money=money, team=crew)


def finish(world, mid, m):
    check_rows(mid, m["rows"])
    m.setdefault("region", "ashmere")
    world.add_map(mid, m)


def build(world):
    ashmere_station(world)
    cinderfold(world)
    gravers_hall(world)
    kiln_rift(world)
    saltglass(world)
    glass_rift(world)
    wide_rift_far(world)
    undrawn_1(world)
    undrawn_2(world)
    undrawn_3(world)


def conductor_text(world, mid, name_en, name_de):
    world.add_text(mid, {
        "conductor": {"lines": lines(("%s: Mountain railway. Mind the gap, mind the clouds." % name_en,
                                      "%s: Bergbahn. Achte auf die Lücke und auf die Wolken." % name_de)),
                      "action": "transit mountain_rail"},
    })


# --- Ashmere station: the mountain railway ends on the platform at (6, 20) -------------------
def ashmere_station(world):
    mid = "ashmere_station"
    rows = ["^^^^^__^^^^^",
            "^::..__..::^",
            "^::..__..::^",
            "^^^^.__.^^^^",
            "^....__....^",
            "^.RRRRRR...^",
            "^.HHHDHH.S.^",
            "^....__....^",
            "^...______._",
            "^..._....___",
            "^..._......^",
            "__.._..::..^",
            "____...::..^",
            "^....._....^",
            "^.L..._..L.^",
            "^....._....^",
            "^....._....^",
            "^....._....^",
            "^.S..._....^",
            "^++++++++++^",
            "^++++++++++^",
            "############"]
    conductor_text(world, mid, "Conductor Rhea", "Schaffnerin Rhea")
    world.add_text(mid, {
        "sign": lines(("ASHMERE STATION", "BAHNHOF ASHMERE"), ("Ashmere Station, 9 folk.", "Bahnhof Ashmere, 9 Leute."), ("Land of the gravers. Every stone here has been drawn twice.", "Land der Graveure. Jeder Stein hier wurde zweimal gezeichnet.")),
    })
    m = {"name": tr("Ashmere Station", "Bahnhof Ashmere"), "biome": "town", "backdrop": "ridge", "outdoor": True,
         "rows": rows,
         "warps": [warp(5, 0, "kiln_rift", 5, 11, "up"), warp(6, 0, "kiln_rift", 6, 11, "up"),
                   warp(11, 8, "saltglass", 1, 22, "right"), warp(11, 9, "saltglass", 1, 23, "right"),
                   warp(0, 11, "cinderfold", 10, 2, "left"), warp(0, 12, "cinderfold", 10, 3, "left")],
         "npcs": [npc("conductor", 8, 19, "left", mid + "/conductor", "villager")],
         "signs": [{"x": 9, "y": 6, "dialogue": mid + "/sign"}],
         "secrets": [secret(0, 15, "strong_tonic", "find_station_west", 2), secret(11, 13, "remedy", "find_station_east"),
                     secret(0, 4, "revival_leaf", "find_station_ridge")],
         "spots": {"tamsin": [4, 17], "page_11": [10, 2], "rail_sign": [2, 18]}}
    finish(world, mid, m)


# --- Cinderfold: the gravers' town, rest spring under the basalt ------------------------------
def cinderfold(world):
    mid = "cinderfold"
    rows = ["^^^^^^^^^^^^",
            "^^.o.^^^^^^^",
            "^.......____",
            "^...._______",
            "^.RRRRR_...^",
            "^.HHDHH_.S.^",
            "^......_...^",
            "^.RRR.._.RR^",
            "^.HDH.._.HD^",
            "^....___...^",
            "^.:..._..:.^",
            "^.:.._____.^",
            "^...._.L...^",
            "^L..._.....^",
            "^....___...^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "sign": lines(("CINDERFOLD", "CINDERFOLD"), ("Cinderfold, 88 folk.", "Cinderfold, 88 Leute."), ("Town of the gravers. The hall is open to guild folk.", "Stadt der Graveure. Die Halle steht Gildenleuten offen.")),
        "keeper": {"lines": lines(("Spring Keeper Oda: The water comes up warm under the basalt. It eases tired Spirlings.", "Quellhüterin Oda: Das Wasser kommt warm unter dem Basalt hervor. Es tut müden Spirlings gut.")),
                   "action": "heal"},
        "trader": {"lines": lines(("Trader Bastian: Engraved tins, strong brews. Ashmere prices, Ashmere quality.", "Händler Bastian: Gravierte Dosen, starke Tränke. Ashmere-Preise, Ashmere-Qualität.")),
                   "action": "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"},
    })
    m = {"name": tr("Cinderfold", "Cinderfold"), "biome": "town", "backdrop": "ember", "outdoor": True,
         "heal_point": [3, 2], "rows": rows,
         "warps": [warp(11, 2, "ashmere_station", 1, 11, "right"), warp(11, 3, "ashmere_station", 1, 12, "right"),
                   warp(4, 5, "gravers_hall", 4, 7, "up")],
         "npcs": [npc("keeper", 2, 2, "right", mid + "/keeper", "elder"),
                  npc("trader", 9, 12, "left", mid + "/trader", "villager")],
         "signs": [{"x": 9, "y": 5, "dialogue": mid + "/sign"}],
         "secrets": [secret(0, 10, "strong_tonic", "find_cinderfold_west", 2), secret(11, 12, "remedy", "find_cinderfold_east"),
                     secret(11, 6, "revival_leaf", "find_cinderfold_hall")],
         "spots": {"veit": [8, 6], "nella": [2, 6], "oswin": [9, 10], "kestra": [2, 12], "letter_a1": [10, 13]}}
    finish(world, mid, m)


# --- The gravers' hall: Halvard, Veit's plate ------------------------------------------------
def gravers_hall(world):
    mid = "gravers_hall"
    rows = ["WWWWWWWWWW",
            "WCCCffCCCW",
            "WffffffffW",
            "WfCCffCCfW",
            "WffffffffW",
            "WffffffffW",
            "WCffffffCW",
            "WffffffffW",
            "WWWWDWWWWW"]
    m = {"name": tr("Gravers' Hall", "Halle der Graveure"), "biome": "town", "backdrop": "ember", "rows": rows,
         "warps": [warp(4, 8, "cinderfold", 4, 6, "down")],
         "npcs": [],
         "spots": {"halvard": [4, 2], "veit_plate": [7, 3], "page_14": [1, 6], "letter_a2": [8, 6]}}
    finish(world, mid, m)


# --- The Kiln Rift: Warden Tovan, up the ridge (ring 28-31) ------------------------------------
def kiln_rift(world):
    mid = "kiln_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^........^^",
            "^.::....::.^",
            "^.::.@@.::.^",
            "^^^^....^^^^",
            "^.::....::.^",
            "^.::.@@.::.^",
            "^.........S^",
            "^..^^..^^..^",
            "^.::....::.^",
            "^..........^",
            "^^^^^..^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE KILN RIFT", "DER OFENRISS"), ("The stones are warm. Something behind them is still burning.", "Die Steine sind warm. Dahinter brennt noch etwas.")),
    })
    m = {"name": tr("Kiln Rift", "Ofenriss"), "biome": "rift", "backdrop": "ember", "field": "ash_storm", "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 12, "ashmere_station", 5, 1, "down"), warp(6, 12, "ashmere_station", 6, 1, "down")],
         "npcs": [],
         "signs": [{"x": 10, "y": 8, "dialogue": mid + "/sign"}],
         "spots": {"tovan": [5, 2], "page_12": [10, 3]}}
    finish(world, mid, m)


# --- The Saltglass flats: the silent lighthouse (ring 26-29) ----------------------------------
def saltglass(world):
    mid = "saltglass"
    rows = ["^^^^^__^^^^^",
            "^::..__..::^",
            "^::..__..::^",
            "^....__....^",
            "^.::.__.|..^",
            "^.::.__.|..^",
            "^....__.D..^",
            "^,,,.__.,,,^",
            "^,,,.__.,,,^",
            "^....______.",
            "^::........_",
            "^::..__..,,^",
            "^....__..,,^",
            "^,,,.__....^",
            "^,,,.__.::.^",
            "^....__.::.^",
            "^::..__....^",
            "^::..__.,,,^",
            "^....__.,,,^",
            "^.S..__....^",
            "^....__..::^",
            "^....__..::^",
            "_______....^",
            "_______....^",
            "^.........S^",
            "^^^^^__^^^^^"]
    world.add_text(mid, {
        "sign": lines(("SALTGLASS FLATS", "SALZGLASEBENE"), ("Salt flats, rings 26 to 29.", "Salzebene, Ring 26 bis 29."), ("The ground cracks like a window.", "Der Boden springt wie eine Fensterscheibe.")),
        "sign_east": lines(("Road to the far end of the Wide Rift.", "Weg zum fernen Ende des Weiten Risses."),
                           ("Closed by order of the gravers' hall.", "Auf Anordnung der Halle der Graveure gesperrt.")),
    })
    m = {"name": tr("Saltglass Flats", "Salzglasebene"), "biome": "route", "backdrop": "ridge", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(0, 22, "ashmere_station", 10, 8, "left"), warp(0, 23, "ashmere_station", 10, 9, "left"),
                   warp(5, 0, "glass_rift", 5, 11, "up"), warp(6, 0, "glass_rift", 6, 11, "up"),
                   warp(11, 9, "wide_rift_far", 1, 11, "right"), warp(11, 10, "wide_rift_far", 1, 12, "right"),
                   warp(8, 6, "shade_rift", 5, 20, "up"),
                   warp(5, 25, "ochrewell", 5, 1, "down"), warp(6, 25, "ochrewell", 6, 1, "down")],
         "npcs": [
             wayfarer(world, mid, "nils", 2, 12, "right", "Salt Raker Nils", team(("Brinelet", 27), ("Talusk", 27)),
                      [("Nils: Rake the salt and it sings. Not since the lighthouse went dark, though.", "Nils: Wenn man das Salz recht, singt es. Seit der Leuchtturm dunkel ist, aber nicht mehr.")],
                      [("Nils: Careful, the flats are sharp. So is my team.", "Nils: Vorsicht, die Ebene ist scharf. Mein Team auch.")],
                      [("Nils: Ha, you walk the glass like a local.", "Nils: Ha, du gehst übers Glas wie jemand von hier.")], 1400),
             wayfarer(world, mid, "ines", 9, 17, "left", "Glassblower Ines", team(("Lanternel", 28), ("Zephlet", 28), ("Wickit", 28)),
                      [("Ines: I blow lenses from the salt glass. The lighthouse lens was mine.", "Ines: Ich blase Linsen aus dem Salzglas. Die Linse des Leuchtturms war meine.")],
                      [("Ines: Show me how bright you burn.", "Ines: Zeig mir, wie hell du brennst.")],
                      [("Ines: Bright enough to light a lamp.", "Ines: Hell genug, um eine Lampe anzuzünden.")], 1450),
             wayfarer(world, mid, "odila", 2, 3, "right", "Wanderer Odila", team(("Saltspire", 29), ("Brinelet", 29), ("Paddlewisp", 29)),
                      [("Odila: North of here the glass turns to mirrors. Don't stare.", "Odila: Nördlich von hier wird das Glas zu Spiegeln. Starr nicht hinein.")],
                      [("Odila: One more duel before the Rift?", "Odila: Noch ein Duell vor dem Riss?")],
                      [("Odila: Go. Ilse hasn't said a word in a year. Maybe you'll hear her.", "Odila: Geh. Ilse hat seit einem Jahr nicht gesprochen. Vielleicht hörst du sie.")], 1500),
         ],
         "signs": [{"x": 2, "y": 19, "dialogue": mid + "/sign"}, {"x": 10, "y": 24, "dialogue": mid + "/sign_east"}],
         "blocks": [gate(10, 9, "veit_plate_done"), gate(10, 10, "veit_plate_done"), gate(8, 6, "veit_plate_done"),
                    gate(5, 25, "rift_shade_sealed"), gate(6, 25, "rift_shade_sealed")],
         "secrets": [secret(0, 6, "strong_tonic", "find_saltglass_west", 2), secret(11, 15, "remedy", "find_saltglass_east"),
                     secret(0, 18, "max_tonic", "find_saltglass_south"), secret(11, 3, "revival_leaf", "find_saltglass_tower")],
         "spots": {"keeper_lamp": [8, 4], "page_13": [10, 1], "letter_a3": [1, 15]}}
    finish(world, mid, m)


# --- The Glass Rift: Warden Ilse, fully silent (ring 30-33) ------------------------------------
def glass_rift(world):
    mid = "glass_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^........^^",
            "^.::.||.::.^",
            "^.::....::.^",
            "^^^^....^^^^",
            "^.::.||.::.^",
            "^.::....::.^",
            "^.........S^",
            "^..^^..^^..^",
            "^.::....::.^",
            "^..........^",
            "^^^^^..^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE GLASS RIFT", "DER GLASRISS"), ("Not a sound. Not even your own steps.", "Kein Laut. Nicht einmal deine eigenen Schritte.")),
    })
    m = {"name": tr("Glass Rift", "Glasriss"), "biome": "rift", "backdrop": "voice", "field": "dawn_glow", "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 12, "saltglass", 5, 1, "down"), warp(6, 12, "saltglass", 6, 1, "down")],
         "npcs": [],
         "signs": [{"x": 10, "y": 8, "dialogue": mid + "/sign"}],
         "spots": {"ilse": [5, 2]}}
    finish(world, mid, m)


# --- The far end of the Wide Rift: Kestra's farewell duel, the gate into the Undrawn ----------
def wide_rift_far(world):
    mid = "wide_rift_far"
    rows = ["XXXXX__XXXXX",
            "XXXXX__XXXXX",
            "^XX......XX^",
            "^^........^^",
            "^..........^",
            "^.::....::.^",
            "^.::....::.^",
            "^..........^",
            "^..^^..^^..^",
            "^..........^",
            "^.::....::.^",
            "_..........^",
            "_..........^",
            "^.::....::.^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE FAR END OF THE WIDE RIFT", "DAS FERNE ENDE DES WEITEN RISSES"), ("Here the map stops being a map.", "Hier hört die Karte auf, eine Karte zu sein.")),
    })
    m = {"name": tr("Far End of the Wide Rift", "Fernes Ende des Weiten Risses"), "biome": "rift", "backdrop": "voice", "encounters": mid,
         "rows": rows,
         "warps": [warp(0, 11, "saltglass", 9, 9, "left"), warp(0, 12, "saltglass", 9, 10, "left"),
                   warp(5, 0, "undrawn_1", 5, 20, "up"), warp(6, 0, "undrawn_1", 6, 20, "up")],
         "npcs": [],
         "signs": [{"x": 10, "y": 7, "dialogue": mid + "/sign"}],
         "blocks": [gate(5, 1, "undrawn_reached"), gate(6, 1, "undrawn_reached")],
         "spots": {"kestra": [6, 4], "gate": [7, 2]}}
    m["rows"][7] = "^.........S^"
    finish(world, mid, m)


# --- The Undrawn: three short parts without finished edges -------------------------------------
def undrawn_1(world):
    mid = "undrawn_1"
    rows = ["XXXXX__XXXXX",
            "XX...__...XX",
            "X....__....X",
            "X.,,.__.,,.X",
            "X.,,.__.,,.X",
            "X....__....X",
            "XX...__...XX",
            "X.....__...X",
            "X......__..X",
            "X.......__.X",
            "X......__..X",
            "X.....__...X",
            "X....__....X",
            "XX..__....XX",
            "X...__.....X",
            "X....__....X",
            "X.,,.__.,,.X",
            "X.,,.__.,,.X",
            "X....__....X",
            "XX...__...XX",
            "X....__....X",
            "XXXXX__XXXXX"]
    m = {"name": tr("The Undrawn", "Das Ungezeichnete"), "biome": "rift", "backdrop": "voice",
         "rows": rows,
         "warps": [warp(5, 21, "wide_rift_far", 5, 2, "down"), warp(6, 21, "wide_rift_far", 6, 2, "down"),
                   warp(5, 0, "undrawn_2", 5, 14, "up"), warp(6, 0, "undrawn_2", 6, 14, "up")],
         "npcs": [],
         "spots": {"echo_a": [3, 9]}}
    finish(world, mid, m)


def undrawn_2(world):
    mid = "undrawn_2"
    rows = ["XXXXX__XXXXX",
            "XX...__...XX",
            "X....__....X",
            "X..X.__.X..X",
            "X....__....X",
            "XX...__...XX",
            "X..,,__,,..X",
            "X..,,__,,..X",
            "X....__....X",
            "XX...__...XX",
            "X....__....X",
            "X.X..__..X.X",
            "X....__....X",
            "XX...__...XX",
            "X....__....X",
            "XXXXX__XXXXX"]
    m = {"name": tr("The Undrawn", "Das Ungezeichnete"), "biome": "rift", "backdrop": "voice",
         "rows": rows,
         "warps": [warp(5, 15, "undrawn_1", 5, 1, "down"), warp(6, 15, "undrawn_1", 6, 1, "down"),
                   warp(5, 0, "undrawn_3", 5, 14, "up"), warp(6, 0, "undrawn_3", 6, 14, "up")],
         "npcs": [],
         "spots": {"ash": [8, 4], "echo_b": [2, 10]}}
    finish(world, mid, m)


def undrawn_3(world):
    mid = "undrawn_3"
    rows = ["XXXXXXXXXXXX",
            "XXXX....XXXX",
            "XX........XX",
            "X..........X",
            "X...,,,,...X",
            "X...,..,...X",
            "X...,,,,...X",
            "X..........X",
            "XX...__...XX",
            "X....__....X",
            "X....__....X",
            "XX...__...XX",
            "X....__....X",
            "X....__....X",
            "X....__....X",
            "XXXXX__XXXXX"]
    m = {"name": tr("The Undrawn", "Das Ungezeichnete"), "biome": "rift", "backdrop": "voice",
         "rows": rows,
         "warps": [warp(5, 15, "undrawn_2", 5, 1, "down"), warp(6, 15, "undrawn_2", 6, 1, "down")],
         "npcs": [],
         "spots": {"mirela": [6, 2], "echo_c": [2, 9]}}
    finish(world, mid, m)
