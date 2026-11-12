"""Corvane, Act II maps (docs/STORY.md "Places with fixed map ids"): Madderby and its guild
house, the Woadfen moor with the Rain Rift, Stillwater with the Mirror Rift, the Greyreach and
the edge of the Wide Rift. Built by corvane.py (group "corvane"); edit here, then run
tools/art/build_world.py.

Area 4 places the story figures through data/story_npcs.json on the named "spots" of each map.
The way opens in story order with blocks:
  corvane_quay -> madderby          madderby_road_open (scene corvane_arrival)
  madderby -> woadfen, stillwater   guild_joined (Ysolde)
  stillwater -> greyreach           beat_story_kestra_2 (Kestra's doubt, chapter 8)
  greyreach -> wide_rift_edge       beat_veit_1 (Veit's duel, chapter 9)
  woadfen -> root_rift              rift_mirror_sealed (east edge of the moor, tools/art/world/rifts12.py)
"""
from common import check_rows, lines, npc, secret, team, tr, warp

GROUP = ["madderby", "madderby_guild", "woadfen", "rain_rift", "stillwater", "mirror_rift",
         "greyreach", "wide_rift_edge"]


def gate(x, y, flag):
    return {"x": x, "y": y, "open_flag": flag, "closed": "#"}


def wayfarer(world, mid, id_, x, y, facing, title, crew, talk, intro, defeat, money, sprite="villager"):
    world.add_text(mid, {id_: lines(*talk), id_ + "_intro": lines(*intro), id_ + "_defeat": lines(*defeat)})
    return npc(id_, x, y, facing, "%s/%s" % (mid, id_), sprite, trainer=title,
               intro="%s/%s_intro" % (mid, id_), defeat="%s/%s_defeat" % (mid, id_), money=money, team=crew)


def finish(world, mid, m):
    check_rows(mid, m["rows"])
    m.setdefault("region", "corvane")
    world.add_map(mid, m)


def build(world):
    madderby(world)
    madderby_guild(world)
    woadfen(world)
    rain_rift(world)
    stillwater(world)
    mirror_rift(world)
    greyreach(world)
    wide_rift_edge(world)


# --- Madderby: the dyers' town north of the quay, rest at Weda's dye spring --------------------
def madderby(world):
    mid = "madderby"
    rows = ["@TTTT__@TTT@",
            "T,,..__..*,T",
            "T*RRR__....T",
            "T.HDH._.*S.T",
            "T.._______.T",
            "T*.*._..._*T",
            "T...*_.o._.T",
            "T.*.._..._.T",
            "@RRR._..._.@",
            "THDH._.*._.T",
            "T...._______",
            "@.%S%*_...._",
            "T.%%%._RRR.T",
            "T*.*.._HDH.T",
            "T*..*.___..T",
            "T,,..__.*..T",
            "T,,,._....*T",
            "T...*_..S..T",
            "T.*.._.*...T",
            "@**..__...*@",
            "T....__*..*T",
            "TTT@@__TTTTT"]
    world.add_text(mid, {
        "sign": lines(("MADDERBY", "MADDERBY"), ("Madderby, 140 folk.", "Madderby, 140 Leute."), ("Dyers' town of Corvane. Home of the cartographers' guild.", "Färberstadt von Corvane. Sitz der Kartografengilde."),
                      ("East: Woadfen   North: Stillwater", "Osten: Waidmoor   Norden: Stillwater")),
        "road": lines(("MADDERBY ROAD", "STRASSE NACH MADDERBY"), ("South: Corvane Quay", "Süden: Corvane-Kai")),
        "guard": lines(("Gatekeeper Ansel: The moor and the pond paths are guild business since the storm.", "Torwächter Ansel: Moor und Teichweg sind seit dem Sturm Sache der Gilde."),
                       ("Gatekeeper Ansel: Show Ysolde at the guild house what you can do, then I'll let you through.", "Torwächter Ansel: Zeig Ysolde im Gildenhaus, was du kannst, dann lasse ich dich durch.")),
        "vats": lines(("Dye vats, cold and grey. Nobody has stirred them since the colour went out.", "Färbebottiche, kalt und grau. Seit die Farbe verschwunden ist, hat sie niemand mehr umgerührt.")),
        "trader": {"lines": lines(("Trader Lorna: Brews and bandages. The colour may be gone, but bruises are still blue.", "Händlerin Lorna: Tränke und Verbände. Die Farbe mag weg sein, aber blaue Flecken gibt es noch.")),
                   "action": "shop tonic strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"},
    })
    m = {"name": tr("Madderby", "Madderby"), "biome": "town", "backdrop": "field", "outdoor": True,
         "heal_point": [8, 7], "rows": rows,
         "warps": [warp(5, 21, "corvane_quay", 5, 2, "down"), warp(6, 21, "corvane_quay", 6, 2, "down"),
                   warp(3, 3, "madderby_guild", 4, 7, "up"),
                   warp(11, 10, "woadfen", 1, 24, "right"), warp(11, 11, "woadfen", 1, 25, "right"),
                   warp(5, 0, "stillwater", 5, 24, "up"), warp(6, 0, "stillwater", 6, 24, "up")],
         "npcs": [npc("guard", 10, 12, "up", mid + "/guard", "villager"),
                  npc("trader", 6, 13, "right", mid + "/trader", "villager")],
         "signs": [{"x": 9, "y": 3, "dialogue": mid + "/sign"}, {"x": 8, "y": 17, "dialogue": mid + "/road"},
                   {"x": 3, "y": 11, "dialogue": mid + "/vats"}],
         "blocks": [gate(10, 10, "guild_joined"), gate(10, 11, "guild_joined"),
                    gate(5, 1, "guild_joined"), gate(6, 1, "guild_joined")],
         "secrets": [secret(0, 14, "tonic", "find_madder_west", 2), secret(11, 15, "remedy", "find_madder_east"),
                     secret(0, 5, "revival_leaf", "find_madder_north")],
         "spots": {"kestra": [10, 4], "weda": [8, 6], "dyer_1": [1, 10], "dyer_2": [2, 10], "dyer_3": [3, 10],
                   "letter_c2": [10, 14]}}
    finish(world, mid, m)


# --- The cartographers' guild house: Ysolde, Pim, the wall map and Veit's old corner ----------
def madderby_guild(world):
    mid = "madderby_guild"
    rows = ["WWWWWWWWWW",
            "WCCCffCCCW",
            "WffffffffW",
            "WfCCffCCfW",
            "WffffffffW",
            "WffffffffW",
            "WCffffffCW",
            "WffffffffW",
            "WWWWDWWWWW"]
    m = {"name": tr("Guild House", "Gildenhaus"), "biome": "town", "backdrop": "field", "rows": rows,
         "warps": [warp(4, 8, "madderby", 3, 4, "down")],
         "npcs": [],
         "spots": {"ysolde": [4, 2], "pim": [6, 5], "wall_map": [4, 0], "veit_desk": [1, 6],
                   "veit_shelf": [1, 1], "veit_stove": [8, 6]}}
    finish(world, mid, m)


# --- Woadfen: the grey moor east of Madderby, way to the Rain Rift (ring 18-21) ---------------
def woadfen(world):
    mid = "woadfen"
    rows = ["@TTTT__@TTT@",
            "T,,,.__.,,,T",
            "T,%%.__.%%,T",
            "T,%%*._.%%,T",
            "T,,,.._..,,T",
            "TT,,,._,,,TT",
            "T~~~,._,~~~T",
            "T~~~,._,~~~T",
            "T,,,,._,,,,@",
            "T,%%,._*.S,T",
            "T,%%,._,,,,T",
            "@T,,,*_,,TT@",
            "T,,,__,,,,,T",
            "T,,,_,,%%%,T",
            "T~~~_~~%%%,T",
            "T~~~_~~,,,,_",
            "T,,,_,,,,,,T",
            "T,%%____,,,T",
            "T,%%,,,_,,,T",
            "@T,,,,,_,,T@",
            "T,,,,,,_,,,T",
            "T...,,,_,%%T",
            "@....,,_,%%@",
            "T,,,,,,_,,,T",
            "______.._,,T",
            "______..*_.T",
            "T,S.,,,,,,,T",
            "T@TTTT@TTTTT"]
    world.add_text(mid, {
        "sign": lines(("WOADFEN", "WAIDMOOR"), ("Moor, rings 18 to 21.", "Moor, Ring 18 bis 21."),
                      ("West: Madderby   North: the Rain Rift", "Westen: Madderby   Norden: der Regenriss")),
        "sign_top": lines(("The rain falls here without a sound.", "Der Regen fällt hier ohne ein Geräusch."),
                          ("North: the Rain Rift. Walkers, keep to the path.", "Norden: der Regenriss. Wanderer, bleibt auf dem Weg.")),
    })
    m = {"name": tr("Woadfen", "Waidmoor"), "biome": "marsh", "backdrop": "lake", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(0, 24, "madderby", 8, 10, "left"), warp(0, 25, "madderby", 8, 11, "left"),
                   warp(5, 0, "rain_rift", 5, 11, "up"), warp(6, 0, "rain_rift", 6, 11, "up"),
                   warp(11, 15, "root_rift", 5, 20, "up")],
         "npcs": [
             wayfarer(world, mid, "orla", 3, 12, "right", "Peat Cutter Orla", team(("Puddlet", 18), ("Paddlewisp", 19)),
                      [("Orla: The peat is grey all the way down now. It used to be the colour of strong tea.", "Orla: Der Torf ist jetzt durch und durch grau. Früher hatte er die Farbe von starkem Tee.")],
                      [("Orla: A stranger on my moor? Let's see if you sink.", "Orla: Jemand Fremdes auf meinem Moor? Mal sehen, ob du einsinkst.")],
                      [("Orla: You keep your feet. Good.", "Orla: Du bleibst auf den Beinen. Gut.")], 900),
             wayfarer(world, mid, "fenn", 9, 15, "left", "Reed Cutter Fenn", team(("Fluting", 19), ("Puddlet", 19), ("Paddlewisp", 20)),
                      [("Fenn: The reeds still whisper. The people out here don't.", "Fenn: Das Schilf flüstert noch. Die Leute hier draußen nicht.")],
                      [("Fenn: You talk loudly for a moor. Duel me and be quiet after.", "Fenn: Du redest laut fürs Moor. Kämpf gegen mich und sei danach still.")],
                      [("Fenn: Fine. Talk all you like.", "Fenn: Schon gut. Rede, so viel du willst.")], 950),
             wayfarer(world, mid, "lusa", 2, 4, "right", "Wanderer Lusa", team(("Hushkin", 20), ("Paddlewisp", 20), ("Blotling", 20)),
                      [("Lusa: Past here the rain falls upward, if you look long enough.", "Lusa: Hinter dieser Stelle fällt der Regen nach oben, wenn man lange genug hinsieht.")],
                      [("Lusa: Before the Rift, one last test.", "Lusa: Vor dem Riss noch eine letzte Prüfung.")],
                      [("Lusa: Go on, then. Senna is waiting, even if she can't hear you.", "Lusa: Dann geh. Senna wartet, auch wenn sie dich nicht hört.")], 1000),
         ],
         "signs": [{"x": 2, "y": 26, "dialogue": mid + "/sign"}, {"x": 9, "y": 9, "dialogue": mid + "/sign_top"}],
         "blocks": [gate(11, 15, "rift_mirror_sealed")],
         "secrets": [secret(0, 8, "tonic", "find_woad_west", 2), secret(11, 20, "remedy", "find_woad_east"),
                     secret(0, 16, "strong_tonic", "find_woad_pool"), secret(11, 2, "revival_leaf", "find_woad_north")],
         "spots": {"wanderer_a": [4, 4], "wanderer_b": [8, 9], "letter_c3": [1, 22], "page_9": [1, 1]}}
    finish(world, mid, m)


# --- The Rain Rift: Warden Senna, who hears only rain (ring 20-23) ------------------------------
def rain_rift(world):
    mid = "rain_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^...%%...^^",
            "^.%%....%%.^",
            "^.%%.~~.%%.^",
            "^^^^.~~.^^^^",
            "^.%%....%%.^",
            "^.%%.~~.%%.^",
            "^.........S^",
            "^..^^..^^..^",
            "^.%%....%%.^",
            "^..........^",
            "^^^^^..^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE RAIN RIFT", "DER REGENRISS"), ("Rain that does not touch the ground.", "Regen, der den Boden nicht berührt.")),
    })
    m = {"name": tr("Rain Rift", "Regenriss"), "biome": "rift", "backdrop": "lake", "field": "high_tide", "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 12, "woadfen", 5, 1, "down"), warp(6, 12, "woadfen", 6, 1, "down")],
         "npcs": [],
         "signs": [{"x": 10, "y": 8, "dialogue": mid + "/sign"}],
         "spots": {"senna": [5, 2]}}
    finish(world, mid, m)


# --- Stillwater: a pond below rice-step terraces north of Madderby (ring 20-23) ---------------
def stillwater(world):
    mid = "stillwater"
    rows = ["@TTTT__@TTT@",
            "T,,,.__.,,,T",
            "T,,,.__.,,,T",
            "T^^^^==^^^^T",
            "T,,,,..,,,,T",
            "T^^^^==^^^^T",
            "T...*__....T",
            "T.~~~~~~~..T",
            "@*~~~~~~~..S",
            "T.~~~++~~..T",
            "T.~~~++~~..T",
            "@....__..S.@",
            "T,,.._.....T",
            "T,,,._...___",
            "T,,,*______.",
            "T%%%.._.,,,T",
            "T%%%.._.,,,T",
            "T~~~*._.,,,T",
            "T~~~._.*%%.T",
            "@,,,._..%%.@",
            "T,,,._.*..*T",
            "T*..._..**.T",
            "@....__....T",
            "T.S..__....T",
            "T*.*.__....T",
            "T@TTT__TTTTT"]
    world.add_text(mid, {
        "sign": lines(("STILLWATER", "STILLWATER"), ("Pond and terraces, rings 20 to 23.", "Teich und Terrassen, Ring 20 bis 23."),
                      ("South: Madderby   North: the Mirror Rift", "Süden: Madderby   Norden: der Spiegelriss")),
        "pond": lines(("The pond is so still that the sky looks deeper than the water.", "Der Teich ist so still, dass der Himmel tiefer aussieht als das Wasser."),
                      ("East: the Greyreach, closed by the guild for now.", "Osten: die Greyreach, von der Gilde vorerst gesperrt.")),
    })
    m = {"name": tr("Stillwater", "Stillwater"), "biome": "route", "backdrop": "lake", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 25, "madderby", 5, 2, "down"), warp(6, 25, "madderby", 6, 2, "down"),
                   warp(5, 0, "mirror_rift", 5, 11, "up"), warp(6, 0, "mirror_rift", 6, 11, "up"),
                   warp(11, 13, "greyreach", 1, 26, "right"), warp(11, 14, "greyreach", 1, 27, "right")],
         "npcs": [
             wayfarer(world, mid, "teo", 2, 12, "right", "Angler Teo", team(("Puddlet", 20), ("Fluting", 21)),
                      [("Teo: Nothing bites since the colour went. I keep coming anyway.", "Teo: Seit die Farbe weg ist, beißt nichts mehr an. Ich komme trotzdem."),],
                      [("Teo: You scared the fish. Not that there were any.", "Teo: Du hast die Fische verscheucht. Nicht dass es welche gegeben hätte.")],
                      [("Teo: Ha. That was more fun than fishing.", "Teo: Ha. Das hat mehr Spaß gemacht als Angeln.")], 1000),
             wayfarer(world, mid, "runa", 9, 16, "left", "Terrace Farmer Runa", team(("Croziel", 21), ("Mossling", 21), ("Puddlet", 22)),
                      [("Runa: We grow rice on the steps. Grey rice this year.", "Runa: Wir bauen Reis auf den Stufen an. Grauen Reis dieses Jahr.")],
                      [("Runa: Mind the dykes! And mind my team.", "Runa: Pass auf die Dämme auf! Und auf mein Team.")],
                      [("Runa: You're steadier than the dykes.", "Runa: Du stehst fester als die Dämme.")], 1050),
             wayfarer(world, mid, "ivo", 8, 2, "left", "Wanderer Ivo", team(("Wickit", 22), ("Lanternel", 22), ("Croziel", 22)),
                      [("Ivo: Up there you see yourself. Only yourself. Hold on to something real.", "Ivo: Da oben siehst du dich selbst. Nur dich selbst. Halt dich an etwas Echtem fest.")],
                      [("Ivo: Let's see if you look away first.", "Ivo: Mal sehen, wer zuerst wegschaut.")],
                      [("Ivo: Good. You'll do up there.", "Ivo: Gut. Da oben kommst du zurecht.")], 1100),
         ],
         "signs": [{"x": 2, "y": 23, "dialogue": mid + "/sign"}, {"x": 9, "y": 11, "dialogue": mid + "/pond"}],
         "blocks": [gate(10, 13, "beat_story_kestra_2"), gate(10, 14, "beat_story_kestra_2")],
         "secrets": [secret(0, 20, "tonic", "find_still_west", 2), secret(11, 22, "remedy", "find_still_east"),
                     secret(0, 4, "strong_tonic", "find_still_terrace")],
         "spots": {"kestra": [7, 4], "page_8": [10, 9]}}
    finish(world, mid, m)


# --- The Mirror Rift: Warden Joral, who sees only himself (ring 21-24) ------------------------
def mirror_rift(world):
    mid = "mirror_rift"
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
        "sign": lines(("THE MIRROR RIFT", "DER SPIEGELRISS"), ("Every stone here shows a face. Most of them are yours.", "Jeder Stein hier zeigt ein Gesicht. Die meisten davon sind deins.")),
    })
    m = {"name": tr("Mirror Rift", "Spiegelriss"), "biome": "rift", "backdrop": "voice", "field": "dawn_glow", "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 12, "stillwater", 5, 1, "down"), warp(6, 12, "stillwater", 6, 1, "down")],
         "npcs": [],
         "signs": [{"x": 10, "y": 8, "dialogue": mid + "/sign"}],
         "spots": {"joral": [5, 2]}}
    finish(world, mid, m)


# --- The Greyreach: grey uplands, Veit's duel, old Moss (ring 22-25) -------------------------
def greyreach(world):
    mid = "greyreach"
    rows = ["^^^^^__^^^^^",
            "^::*.__..::^",
            "^::..__..::^",
            "^^^^*__.^^^^",
            "^.*..__*...@",
            "^.RRR__.::*^",
            "^.HDH__.::.^",
            "^....__....^",
            "^::..__..S.^",
            "^::..__^^^^^",
            "^::..__.*..^",
            "^^^^^__.::.^",
            "^....__.::.^",
            "^*::.__...._",
            "^.::*____..^",
            "^.......=..^",
            "^^^^^^^=^^^^",
            "^::.*.*__..^",
            "^::...__...^",
            "^**...__.::^",
            "@.::..__.::^",
            "^.::..__*..^",
            "S....*__...^",
            "^::..*__..:^",
            "^::...__..:^",
            "^...*.__*..^",
            "_______....^",
            "_______..S*^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE GREYREACH", "DIE GREYREACH"), ("Uplands, rings 22 to 25.", "Hochland, Ring 22 bis 25."),
                      ("West: Stillwater   North: the Wide Rift", "Westen: Stillwater   Norden: der Weite Riss")),
        "sign_top": {"lines": lines(("MOUNTAIN RAILWAY", "BERGBAHN"), ("Halt Greyreach. No trains since the storm.", "Halt Greyreach. Seit dem Sturm fahren keine Züge.")),
                     "after_flag": {"flag": "act2_end", "lines": lines(("MOUNTAIN RAILWAY", "BERGBAHN"), ("Halt Greyreach. Trains to Ashmere again.", "Halt Greyreach. Wieder Züge nach Ashmere."))}},
        "conductor": {"lines": lines(("Conductor Tilde: Mountain railway to Ashmere. Mind the gap, mind the clouds.", "Schaffnerin Tilde: Bergbahn nach Ashmere. Achte auf die Lücke und auf die Wolken.")),
                      "action": "transit mountain_rail"},
        "porter": {"lines": lines(("Porter Joska: The gilt funicular climbs to Halcyra. Up there they polish the rails and lie about the view.", "Träger Joska: Die vergoldete Standseilbahn fährt hinauf nach Halcyra. Oben polieren sie die Schienen und lügen über die Aussicht.")),
                   "action": "transit halcyra_funicular"},
        "hut": lines(("A survey hut. Old charts of the uplands hang on the wall, every one of them grey.", "Eine Vermessungshütte. An der Wand hängen alte Karten des Hochlands, jede einzelne grau.")),
    })
    m = {"name": tr("Greyreach", "Greyreach"), "biome": "route", "backdrop": "ridge", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(0, 26, "stillwater", 9, 13, "left"), warp(0, 27, "stillwater", 9, 14, "left"),
                   warp(5, 0, "wide_rift_edge", 5, 14, "up"), warp(6, 0, "wide_rift_edge", 6, 14, "up")],
         "npcs": [
             npc("conductor", 10, 8, "left", mid + "/conductor", "villager"),
             npc("porter", 4, 7, "down", mid + "/porter", "villager", show_flag="era3_finale_done"),
             wayfarer(world, mid, "brann", 2, 22, "right", "Ridgewalker Brann", team(("Mirkmole", 22), ("Talusk", 23)),
                      [("Brann: The scree up here slides if you look at it wrong.", "Brann: Das Geröll hier oben rutscht, wenn man es falsch ansieht.")],
                      [("Brann: Steady feet? Prove it.", "Brann: Sicher auf den Beinen? Beweis es.")],
                      [("Brann: Steady enough.", "Brann: Sicher genug.")], 1150),
             wayfarer(world, mid, "kaja", 9, 12, "left", "Surveyor Kaja", team(("Brinelet", 23), ("Mirkmole", 23), ("Shalebat", 24)),
                      [("Kaja: I measure the Greyreach every year. This year it measured me.", "Kaja: Ich vermesse die Greyreach jedes Jahr. Dieses Jahr hat sie mich vermessen.")],
                      [("Kaja: Hold still, I need a reference point. Ha, a duel will do.", "Kaja: Halt still, ich brauche einen Bezugspunkt. Ha, ein Duell tut es auch.")],
                      [("Kaja: Noted. You are a fixed point.", "Kaja: Notiert. Du bist ein Fixpunkt.")], 1200),
             wayfarer(world, mid, "edrik", 2, 4, "right", "Wanderer Edrik", team(("Talusk", 24), ("Wickit", 24), ("Mirkmole", 25)),
                      [("Edrik: North of here the ground just stops. Like someone forgot to draw it.", "Edrik: Nördlich von hier hört der Boden einfach auf. Als hätte jemand vergessen, ihn zu zeichnen.")],
                      [("Edrik: Last stop before nothing. Duel?", "Edrik: Letzter Halt vor dem Nichts. Duell?")],
                      [("Edrik: Go and look, then. Don't step too close.", "Edrik: Dann geh und sieh hin. Tritt nicht zu nah heran.")], 1250),
         ],
         "signs": [{"x": 9, "y": 27, "dialogue": mid + "/sign"}, {"x": 9, "y": 8, "dialogue": mid + "/sign_top"},
                   {"x": 2, "y": 6, "dialogue": mid + "/hut"}],
         "blocks": [gate(5, 1, "beat_veit_1"), gate(6, 1, "beat_veit_1")],
         "secrets": [secret(11, 10, "tonic", "find_grey_east", 2), secret(0, 19, "remedy", "find_grey_west"),
                     secret(0, 7, "strong_tonic", "find_grey_hut"), secret(11, 25, "revival_leaf", "find_grey_south")],
         "spots": {"veit": [5, 3], "moss": [8, 7], "page_10": [10, 1]}}
    finish(world, mid, m)


# --- The edge of the Wide Rift: Veit's abandoned hut and the burned words ---------------------
def wide_rift_edge(world):
    mid = "wide_rift_edge"
    rows = ["XXXXXXXXXXXX",
            "XXXXXXXXXXXX",
            "^XXX....XXX^",
            "^^........^^",
            "^..........^",
            "^.RRR......^",
            "^.HDH...::.^",
            "^.......::.^",
            "^::........^",
            "^::....@...^",
            "^..........^",
            "^^^^.....S.^",
            "^....__....^",
            "^....__....^",
            "^....__....^",
            "^^^^^__^^^^^"]
    world.add_text(mid, {
        "sign": lines(("THE WIDE RIFT", "DER WEITE RISS"), ("Beyond this point the map is blank.", "Hinter dieser Stelle ist die Karte leer.")),
    })
    m = {"name": tr("Edge of the Wide Rift", "Rand des Weiten Risses"), "biome": "rift", "backdrop": "voice",
         "rows": rows,
         "warps": [warp(5, 15, "greyreach", 5, 2, "down"), warp(6, 15, "greyreach", 6, 2, "down")],
         "npcs": [],
         "signs": [{"x": 9, "y": 11, "dialogue": mid + "/sign"}],
         "spots": {"burned_words": [7, 9], "letter_c1": [1, 10], "veit_diary": [3, 6]}}
    finish(world, mid, m)
