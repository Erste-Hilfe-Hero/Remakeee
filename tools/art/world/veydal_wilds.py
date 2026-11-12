"""Veydal wilds: the new routes and settlements of area 3 (items 914 to 920, 950 to 954, 1078,
1082, 1108). Maps here are generated: edit this file, then run tools/art/build_world.py.

Every route has three Wayfarers who only duel when you talk to them (sight 0), 3 to 5 hidden finds, one
secret passage behind a suspiciously smooth rock (A opens it) and a shortcut that needs gear or
a lever. Every settlement has its own kind of rest spot and a trader with a fixed range.
"""
import townsfolk
from common import check_rows, lines, npc, secret, team, tr, warp

GROUP = ["gloamwood", "quillbrook", "wrenhollow", "brackwater_fen", "reedhaven", "lantern_steps", "copperfold"]


def wayfarer(world, mid, id_, x, y, facing, title, crew, talk, intro, defeat, money, sprite="villager"):
    world.add_text(mid, {id_: lines(*talk), id_ + "_intro": lines(*intro), id_ + "_defeat": lines(*defeat)})
    return npc(id_, x, y, facing, "%s/%s" % (mid, id_), sprite, trainer=title,
               intro="%s/%s_intro" % (mid, id_), defeat="%s/%s_defeat" % (mid, id_), money=money, team=crew)


def passage(x, y, flag):
    """A suspiciously smooth rock (item 1082): facing it and pressing A slides it aside."""
    return {"x": x, "y": y, "flag": flag}


def finish(world, mid, m):
    rows = m["rows"]
    for p in m.get("passages", []):
        # The rock is drawn by the closed block; the map row holds the ground behind it.
        x, y = p["x"], p["y"]
        if rows[y][x] == "@":
            rows[y] = rows[y][:x] + "." + rows[y][x + 1:]
    check_rows(mid, rows)
    m.setdefault("region", "veydal")
    world.add_map(mid, m)


def build(world):
    gloamwood(world)
    quillbrook(world)
    wrenhollow(world)
    brackwater_fen(world)
    reedhaven(world)
    lantern_steps(world)
    copperfold(world)
    connect_act1(world)
    for mid in ("wrenhollow", "reedhaven", "copperfold"):
        townsfolk.apply(world, mid)


# --- Gloamwood: a dense forest on two levels west of Fernstair (item 914) -------------------
def gloamwood(world):
    mid = "gloamwood"
    rows = ["TTTTTTTTTTTT",
            "T,,T.,,..,,T",
            "T,,,.,,_____",
            "TT,,..,_,,TT",
            "TT,,T,._.,,T",
            "T...,,._.S,T",
            "TT^^T.._..,T",
            "T...T,,_,,,T",
            "T,,,,,,_,TTT",
            "TT,,_____,,T",
            "T,,,_,,,,,,T",
            "T,,T_TT,,T,T",
            "T,,,_,,,,,,T",
            "T.._____..,T",
            "T=^^^^^^^^vT",
            "T_,,,,,,,,.T",
            "T_,,T,,TT,.T",
            "T_____,,,,.T",
            "T,,,,_,,,,.T",
            "TT,,,_,TT,.T",
            "T,,T,_,,,,.T",
            "T,,,,____,.T",
            "T*..,,,,_,.T",
            "To.T,,,,_..T",
            "T.S.,,,,____",
            "T..,,,TT,,,T",
            "T,,,,,,,,,,T",
            "TT,,,TT,,,TT",
            "T,,,,,,,,,,T",
            "TTTTTTTTTTTT"]
    world.add_text(mid, {
        "sign": lines(("GLOAMWOOD", "DÄMMERWALD"), ("Forest, rings 4 to 7.", "Wald, Ring 4 bis 7."),
                      ("East: Fernstair   Up the old stair: Crowcrest", "Osten: Fernstair   Die alte Stiege hinauf: Crowcrest")),
        "sign_top": lines(("The trees grow so close that noon looks like dusk.", "Die Bäume stehen so dicht, dass Mittag wie Abend aussieht."),
                          ("North-east: the high path to Crowcrest.", "Nordosten: der hohe Pfad nach Crowcrest.")),
        "forester": {"lines": lines(("Forester Haldis: Half the footbridges in this valley rotted in the storm.", "Försterin Haldis: Die Hälfte der Stege im Tal ist im Sturm verrottet."),
                                    ("Forester Haldis: Here, a bundle of planks. Lay one over any gap with a chalk mark.", "Försterin Haldis: Hier, ein Bündel Bretter. Leg eins über jede Lücke mit Kreidezeichen.")),
                     "action": "give_item plank_bundle 1", "flag": "got_planks", "once": True,
                     "after_flag": {"flag": "got_planks", "lines": lines(("Forester Haldis: Chalk marks mean someone measured. Trust them.", "Försterin Haldis: Kreidezeichen heißen, dass jemand nachgemessen hat. Verlass dich drauf."))}},
        "smooth": lines(("The rock here is oddly smooth, as if many hands had pushed it.", "Der Fels ist hier seltsam glatt, als hätten ihn viele Hände geschoben.")),
        # Item 921: a clearing with a spring halfway through the long forest.
        "spring": {"lines": lines(("A clear spring in a small clearing. The water is cold and tastes of moss.", "Eine klare Quelle auf einer kleinen Lichtung. Das Wasser ist kalt und schmeckt nach Moos.")),
                   "action": "heal"},
    })
    m = {"name": tr("Gloamwood", "Dämmerwald"), "biome": "forest", "backdrop": "field", "outdoor": True, "encounters": mid,
         "heal_point": [1, 22], "rows": rows,
         "warps": [warp(11, 24, "fernstair", 1, 12, "right"), warp(11, 2, "crowcrest", 1, 4, "right")],
         "npcs": [
             npc("forester", 2, 22, "right", mid + "/forester", "ranger"),
             wayfarer(world, mid, "wren", 3, 18, "right", "Wanderer Wren", team(("Mossling", 5), ("Zippit", 6)),
                      [("Wren: I come here to listen. The forest is never fully quiet, Hush or not.", "Wren: Ich komme zum Zuhören her. Der Wald ist nie ganz still, Stille hin oder her.")],
                      [("Wren: You walk loud for a cartographer. Let's see how you fight.", "Wren: Für jemanden mit Zeichenstift läufst du ganz schön laut. Mal sehen, wie du kämpfst.")],
                      [("Wren: Fair. I'll go back to listening.", "Wren: Fair. Ich höre wieder zu.")], 160),
             wayfarer(world, mid, "olek", 3, 9, "right", "Mushroom Picker Olek", team(("Mirkmole", 6), ("Wickit", 6)),
                      [("Olek: The glowing caps only show at night. Don't eat them.", "Olek: Die leuchtenden Hüte zeigen sich nur nachts. Nicht essen.")],
                      [("Olek: You stepped on my patch! A duel, then.", "Olek: Du bist auf meine Stelle getreten! Dann eben ein Duell.")],
                      [("Olek: Fine, fine. Watch your feet next time.", "Olek: Schon gut. Pass nächstes Mal auf deine Füße auf.")], 180),
             wayfarer(world, mid, "sorrel", 9, 7, "left", "Wanderer Sorrel", team(("Zephlet", 7), ("Mossling", 6), ("Kindlop", 6)),
                      [("Sorrel: Up here the path splits. Crowcrest east, the old ruins north.", "Sorrel: Hier oben teilt sich der Weg. Crowcrest im Osten, die alten Ruinen im Norden.")],
                      [("Sorrel: Made it up the stair? Then you've earned a real duel.", "Sorrel: Die Stiege geschafft? Dann hast du dir ein echtes Duell verdient.")],
                      [("Sorrel: Ha! The forest picked a good one.", "Sorrel: Ha! Der Wald hat sich jemand Gutes ausgesucht.")], 220),
         ],
         "signs": [{"x": 2, "y": 24, "dialogue": mid + "/sign"}, {"x": 9, "y": 5, "dialogue": mid + "/sign_top"},
                   {"x": 2, "y": 6, "dialogue": mid + "/smooth"}, {"x": 1, "y": 23, "dialogue": mid + "/spring"}],
         "blocks": [{"x": 1, "y": 5, "open_flag": "pass_gloamwood"}],
         "passages": [passage(1, 5, "pass_gloamwood")],
         "secrets": [secret(0, 10, "tonic", "find_gloam_west", 2), secret(11, 18, "kin_charm", "find_gloam_east"),
                     secret(5, 27, "remedy", "find_gloam_south"), secret(9, 8, "spark_drop", "find_gloam_north"),
                     secret(1, 4, "max_tonic", "find_gloam_pocket")]}
    finish(world, mid, m)


# --- Quillbrook: a brook valley with fords south-west of Brindlewick (item 915) -------------
def quillbrook(world):
    mid = "quillbrook"
    rows = ["TTTTTTTTTTTT",
            "T,,T..~~.___",
            "T,,,..~~..ST",
            "T,,...ww...T",
            "TT,,..~~.,,T",
            "T,,,S+~~,,,T",
            "T..T..~~,,TT",
            "T,,,,.~~..,T",
            "T^^^^.~~^^^T",
            "T,,,..~~.,,T",
            "T,,,.,~~,,,T",
            "T.@..,~~,,,T",
            "TTT,..~~.,,T",
            "T,,,..ww..,T",
            "T,,,,.~~.,TT",
            "T,,T..~~,,,T",
            "T^^^^.~~^^^T",
            "T,,,..~~.,,T",
            "T,,..,~~.T,T",
            "T..,,.~~,,,T",
            "T,,,..~~...T",
            "T,,,..ww..,T",
            "T,T,..~~.,,T",
            "T,,,..~~..,T",
            "T,,,..~~.D,T",
            "T,,,..~~..,T",
            "T__,,.~~,,,T",
            "T_,,,.~~,,,T",
            "T_..,.~~..,T",
            "T_TTTT~~TTTT"]
    world.add_text(mid, {
        "sign": lines(("QUILLBROOK", "FEDERBACH"), ("Brook valley, rings 8 to 11.", "Bachtal, Ring 8 bis 11."),
                      ("Ford the brook to reach Wrenhollow.", "Durch die Furt geht es nach Wrenhollow.")),
        "fisher": {"lines": lines(("Fisher Tamm: The brook's low enough to wade, if your feet can stand the cold.", "Fischer Tamm: Der Bach ist flach genug zum Waten, wenn deine Füße die Kälte aushalten."),
                                  ("Fisher Tamm: Take my spare boots. I've two pairs and one pair of feet.", "Fischer Tamm: Nimm meine Ersatzstiefel. Ich hab zwei Paar und nur ein Paar Füße.")),
                   "action": "give_item wading_boots 1", "flag": "got_boots", "once": True,
                   "after_flag": {"flag": "got_boots", "lines": lines(("Fisher Tamm: Pale water is shallow. Dark water, keep out.", "Fischer Tamm: Helles Wasser ist flach. Vom dunklen halt dich fern."))}},
        "culvert": {"lines": lines(("An old culvert, its grate rusted shut. It runs back up the valley.", "Ein alter Durchlass, das Gitter festgerostet. Er führt das Tal hinauf zurück.")),
                    "action": "lever quill_culvert pry_bar"},
        "smooth": lines(("This stone is too smooth to be natural.", "Dieser Stein ist zu glatt, um natürlich zu sein.")),
        # Item 935: a bench on the fishing pier moves the clock on to the next time of day.
        "bench": {"lines": lines(("A worn bench at the end of a little fishing pier. Sit for a while?", "Eine abgewetzte Bank am Ende eines kleinen Fischerstegs. Eine Weile sitzen?")),
                  "choices": [{"text": tr("Sit and wait", "Sitzen und warten"), "action": "bench"},
                              {"text": tr("Not now", "Jetzt nicht")}]},
        "boatman": {"lines": lines(("Boatman Osk: Lake Line landing. The brook runs out to the lake from here, and so do I.", "Bootsmann Osk: Anleger der Seelinie. Von hier fließt der Bach in den See, und ich fahre mit.")),
                    "action": "transit lake_line"},
    })
    m = {"name": tr("Quillbrook", "Federbach"), "biome": "fern", "backdrop": "lake", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(11, 1, "brindlewick", 1, 12, "right"), warp(1, 29, "wrenhollow", 5, 1, "down"),
                   warp(9, 24, mid, 9, 2, "down"), warp(9, 1, mid, 9, 25, "down")],
         "npcs": [
             npc("fisher", 8, 3, "left", mid + "/fisher", "villager"),
             # Lake Line (item 1187): Osk waits by his boat on the brook.
             npc("boatman", 5, 27, "right", mid + "/boatman", "villager"),
             wayfarer(world, mid, "brisa", 10, 10, "left", "Angler Brisa", team(("Puddlet", 9), ("Kelpup", 9)),
                      [("Brisa: Kelpups chase the trout upstream every morning.", "Brisa: Kelpups jagen jeden Morgen die Forellen bachaufwärts.")],
                      [("Brisa: Scaring my fish? That's a duel!", "Brisa: Du verscheuchst meine Fische? Das gibt ein Duell!")],
                      [("Brisa: Hooked and landed. By you.", "Brisa: Am Haken und an Land gezogen. Von dir.")], 260),
             wayfarer(world, mid, "corin", 2, 14, "right", "Wanderer Corin", team(("Mossling", 9), ("Zephlet", 10)),
                      [("Corin: Every ford here has a name. This one is 'Wet Socks'.", "Corin: Jede Furt hier hat einen Namen. Diese heißt 'Nasse Socken'.")],
                      [("Corin: Across already? Then you can handle this.", "Corin: Schon drüben? Dann schaffst du das hier auch.")],
                      [("Corin: Soaked and beaten. Typical Tuesday.", "Corin: Nass und geschlagen. Ein ganz normaler Dienstag.")], 280),
             wayfarer(world, mid, "pim", 9, 20, "left", "Miller's Kid Pim", team(("Zippit", 10), ("Puddlet", 10), ("Wickit", 9)),
                      [("Pim: The mill wheel stopped when the Rift opened. Dad says it's sulking.", "Pim: Das Mühlrad blieb stehen, als der Riss aufging. Papa sagt, es schmollt.")],
                      [("Pim: I've practised all week! Battle me!", "Pim: Ich hab die ganze Woche geübt! Kämpf gegen mich!")],
                      [("Pim: I'll practise two weeks next time.", "Pim: Nächstes Mal übe ich zwei Wochen.")], 300),
         ],
         "signs": [{"x": 10, "y": 2, "dialogue": mid + "/sign"}, {"x": 8, "y": 24, "dialogue": mid + "/culvert"},
                   {"x": 4, "y": 5, "dialogue": mid + "/bench"},
                   {"x": 2, "y": 12, "dialogue": mid + "/smooth"}],
         # Shortcut (item 919): the culvert at the bottom opens with the Pry Bar and runs back to
         # the top of the valley; both doors stay shut until then.
         "blocks": [{"x": 9, "y": 24, "open_flag": "quill_culvert"}, {"x": 9, "y": 1, "open_flag": "quill_culvert"},
                    {"x": 2, "y": 11, "open_flag": "pass_quillbrook"}],
         "passages": [passage(2, 11, "pass_quillbrook")],
         "secrets": [secret(0, 5, "tonic", "find_quill_west", 2), secret(11, 15, "remedy", "find_quill_east"),
                     secret(3, 22, "dry_towel", "find_quill_reeds"), secret(1, 11, "max_tonic", "find_quill_pocket")]}
    finish(world, mid, m)


# --- Wrenhollow: a village in a hollow on three levels, joined by ladders (item 950) ---------
def wrenhollow(world):
    mid = "wrenhollow"
    rows = ["TTTT_TTTTTTT",
            "T*.._....*.T",
            "TRRR_..RRR.T",
            "THDH_..HDH.T",
            "T.._____...T",
            "T^^^^^^=^^^T",
            "T...__.__..T",
            "T.o.__..._.T",
            "T...__.#._.T",
            "T.S.__.#._.T",
            "T^^=^^^^^^^T",
            "T.._____...T",
            "T.RRR...*..T",
            "T.HDH.##...T",
            "T..___.##..T",
            "T*.....,,,.T",
            "TTTTTTTTTTTT"]
    world.add_text(mid, {
        "sign": lines(("WRENHOLLOW", "ZAUNKÖNIGSGRUND"), ("Wrenhollow, 34 folk.", "Zaunkönigsgrund, 34 Leute."),
                      ("Three terraces, one well, too many ladders.", "Drei Terrassen, ein Brunnen, zu viele Leitern.")),
        "willow": {"lines": lines(("Keeper Ysolde: Sit under the willow and drink from the pool. It mends tired Spirlings.", "Hüterin Ysolde: Setz dich unter die Weide und trink aus dem Teich. Das heilt müde Spirlings.")),
                   "action": "heal"},
        "trader": {"lines": lines(("Trader Ebbe: Brook-cooled tonics, fresh every day.", "Händler Ebbe: Bachgekühlte Tränke, jeden Tag frisch.")),
                   "action": "shop tonic strong_tonic remedy dry_towel cooling_gel kin_charm revival_leaf"},
        "ropemaker": {"lines": lines(("Ropemaker Nell: The old wells hereabouts go deep. You'll want a ladder you can leave behind.", "Seilerin Nell: Die alten Brunnen hier gehen tief. Du brauchst eine Leiter, die du dalassen kannst."),
                                     ("Ropemaker Nell: Tie it where you see a chalk mark. It holds.", "Seilerin Nell: Knote sie dort fest, wo du ein Kreidezeichen siehst. Sie hält.")),
                      "action": "give_item rope_ladder 1", "flag": "got_ladder", "once": True,
                      "after_flag": {"flag": "got_ladder", "lines": lines(("Ropemaker Nell: Every knot I tie has a name. That one was 'Patience'.", "Seilerin Nell: Jeder Knoten, den ich binde, hat einen Namen. Der hieß 'Geduld'."))}},
        # Items 1052, 1053: the Survey Glass shows hidden finds ahead on the minimap.
        "surveyor": {"lines": lines(("Surveyor Ilka: A map is only as good as what you've looked at. Here, look further.", "Vermesserin Ilka: Eine Karte ist nur so gut wie das, was man angesehen hat. Hier, schau weiter."),
                                    ("Surveyor Ilka: Face where you want to look and press A on open ground. Give the glass a breath between looks.", "Vermesserin Ilka: Schau in die Richtung, drück A auf freiem Boden. Gönn dem Glas zwischen zwei Blicken eine Atempause.")),
                     "action": "give_item survey_glass 1", "flag": "got_survey_glass", "once": True,
                     "after_flag": {"flag": "got_survey_glass", "lines": lines(("Surveyor Ilka: Six steps out, no further. Past that, even glass gets lazy.", "Vermesserin Ilka: Sechs Schritte weit, nicht mehr. Dahinter wird selbst Glas faul."))}},
        "elder": lines(("Old Bertil: We heard the Rift from down here. Like a bell cracking.", "Der alte Bertil: Wir haben den Riss bis hier unten gehört. Wie eine Glocke, die springt.")),
        "kid": lines(("Wren-kid: I counted the ladder rungs. All of them. Two hundred and six!", "Kind: Ich hab alle Leitersprossen gezählt. Zweihundertsechs!")),
        "coach": {"lines": lines(("Driver Fenna: Valley Coach, Wrenhollow stop. Climb in, the seats are dry.", "Kutscherin Fenna: Talkutsche, Halt Zaunkönigsgrund. Steig ein, die Sitze sind trocken.")),
                  "action": "transit valley_coach"},
    })
    m = {"name": tr("Wrenhollow", "Zaunkönigsgrund"), "biome": "town", "backdrop": "field", "outdoor": True,
         "heal_point": [2, 8], "rows": rows,
         "warps": [warp(4, 0, "quillbrook", 1, 28, "up")],
         "npcs": [npc("willow", 1, 7, "right", mid + "/willow", "elder"),
                  npc("trader", 9, 7, "left", mid + "/trader", "villager"),
                  npc("ropemaker", 8, 11, "left", mid + "/ropemaker", "villager"),
                  npc("surveyor", 10, 9, "left", mid + "/surveyor", "villager"),
                  npc("elder", 9, 14, "left", mid + "/elder", "elder"),
                  npc("kid", 6, 1, "down", mid + "/kid", "villager"),
                  npc("coach", 10, 6, "left", mid + "/coach", "villager")],
         "signs": [{"x": 2, "y": 9, "dialogue": mid + "/sign"}],
         "secrets": [secret(11, 15, "kin_charm", "find_wren_corner"), secret(0, 12, "tonic", "find_wren_west", 2),
                     secret(11, 4, "spark_drop", "find_wren_roof")]}
    finish(world, mid, m)


# --- Brackwater Fen: a moor of boardwalks and reed islands east of Saltmarsh (item 916) ------
def brackwater_fen(world):
    mid = "brackwater_fen"
    rows = ["~~~~~~~~~~~~",
            "~%%~~++~~%%~",
            "~%%%.++.%%%~",
            "~~%..++..%~~",
            "~~~.++++.~~~",
            "~%%%+~~+%%%~",
            "~%~~+~~+~~%~",
            "~%%~+ww+~%%~",
            "~%~~+~~+~~%~",
            "~~%%++++%%~~",
            "~~~%%++%%~~~",
            "~%%~~++~~%%~",
            "~%.%~++~%.%~",
            "~%..%++%..%~",
            "~~@~%++%~~~~",
            "~~~~%++%%%%~",
            "~%%%%++%%%%~",
            "~%~~~++~~~%~",
            "+++++++~~~%~",
            "~~%%~++~%%%~",
            "~%%%~++~~%%~",
            "~%.%%++%%.%~",
            "~%%%~++~~%%~",
            "~~~~~++~~~~~"]
    world.add_text(mid, {
        "sign": lines(("BRACKWATER FEN", "BRACKFENN"), ("Moor, rings 12 to 15.", "Moor, Ring 12 bis 15."),
                      ("Stay on the boardwalks. The pale water is shallow, the dark is not.", "Bleib auf den Stegen. Das helle Wasser ist flach, das dunkle nicht.")),
        "smooth": lines(("A boulder sits in the reeds, smoothed by hands, not water.", "Im Schilf liegt ein Felsbrocken, glatt geschliffen von Händen, nicht von Wasser.")),
        # Item 1063: the Tide Chart shows the next low and high tide by the device clock.
        "tidewatcher": {"lines": lines(("Tidewatcher Oda: Sablecove only lets you in when the water's low. I've charted it for forty years.", "Gezeitenwächterin Oda: Die Zobelbucht lässt dich nur bei niedrigem Wasser hinein. Ich zeichne das seit vierzig Jahren auf."),
                                       ("Tidewatcher Oda: Take a copy of my chart. Look at it in your satchel before you set out.", "Gezeitenwächterin Oda: Nimm eine Abschrift meiner Tafel. Schau in deiner Tasche nach, bevor du losgehst.")),
                        "action": "give_item tide_chart 1", "flag": "got_tide_chart", "once": True,
                        "after_flag": {"flag": "got_tide_chart", "lines": lines(("Tidewatcher Oda: Low water twice a day, as sure as breakfast and supper.", "Gezeitenwächterin Oda: Zweimal am Tag Niedrigwasser, so sicher wie Frühstück und Abendbrot."))}},
    })
    m = {"name": tr("Brackwater Fen", "Brackfenn"), "biome": "marsh", "backdrop": "lake", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(0, 18, "saltmarsh", 10, 7, "left"), warp(5, 23, "reedhaven", 5, 1, "down"),
                   warp(6, 23, "reedhaven", 6, 1, "down")],
         "npcs": [
             npc("tidewatcher", 9, 15, "down", mid + "/tidewatcher", "elder"),
             wayfarer(world, mid, "marit", 4, 4, "right", "Reed Cutter Marit", team(("Kelpup", 13), ("Mossling", 13)),
                      [("Marit: The reeds grow back twice as fast since the storm. Good for my trade.", "Marit: Das Schilf wächst seit dem Sturm doppelt so schnell nach. Gut fürs Geschäft.")],
                      [("Marit: Mind the boardwalk! Now, a duel.", "Marit: Pass auf den Steg auf! Und jetzt ein Duell.")],
                      [("Marit: Cut down to size.", "Marit: Zurechtgestutzt.")], 380),
             wayfarer(world, mid, "jory", 9, 13, "left", "Wanderer Jory", team(("Puddlet", 14), ("Wickit", 13)),
                      [("Jory: On a misty day you can't see your own boots out here.", "Jory: An nebligen Tagen siehst du hier draußen deine eigenen Stiefel nicht.")],
                      [("Jory: Lost? No? Then let's battle.", "Jory: Verlaufen? Nein? Dann lass uns kämpfen.")],
                      [("Jory: I'm the one who's lost now.", "Jory: Jetzt bin ich der, der sich verlaufen hat.")], 400),
             wayfarer(world, mid, "hesk", 3, 20, "down", "Bog Walker Hesk", team(("Kelpup", 14), ("Zephlet", 14), ("Riptail", 15)),
                      [("Hesk: Reedhaven's down the boardwalk. Houses on stilts. Mind the gaps.", "Hesk: Den Steg runter liegt Reedhaven. Häuser auf Pfählen. Pass auf die Lücken auf.")],
                      [("Hesk: Out this far? You must be good.", "Hesk: So weit draußen? Dann bist du gut.")],
                      [("Hesk: You are good.", "Hesk: Du bist gut.")], 450),
         ],
         "signs": [{"x": 1, "y": 17, "dialogue": mid + "/sign"}, {"x": 3, "y": 14, "dialogue": mid + "/smooth"}],
         "blocks": [{"x": 2, "y": 14, "open_flag": "pass_brackwater"}],
         "passages": [passage(2, 14, "pass_brackwater")],
         "secrets": [secret(1, 12, "remedy", "find_fen_islet"), secret(10, 12, "tonic", "find_fen_east", 2),
                     secret(9, 21, "spark_drop", "find_fen_south"), secret(2, 21, "dry_towel", "find_fen_reeds"),
                     secret(2, 13, "max_tonic", "find_fen_pocket")]}
    # Shortcut (item 919): wade straight across the pond in the middle (Wading Boots) instead
    # of going round on the boardwalk.
    finish(world, mid, m)


# --- Reedhaven: stilt houses in the fen, reached only over boardwalks (item 954) -------------
def reedhaven(world):
    mid = "reedhaven"
    rows = ["~~~~~++~~~~~",
            "~~~+.++.+~~~",
            "~RRR++++RRR~",
            "~HDH+~~+HDH~",
            "~+++++++++o~",
            "~+++L~~++~~~",
            "~RRR+~~+~~%~",
            "~HDH+~~+S%%~",
            "~++++++++%%~",
            "~~~~~~~~~~~~"]
    world.add_text(mid, {
        "sign": lines(("REEDHAVEN", "SCHILFHAFEN"), ("Reedhaven, 19 folk.", "Schilfhafen, 19 Leute."),
                      ("Houses on stilts. Please don't jump on the walkways.", "Häuser auf Pfählen. Bitte nicht auf den Stegen springen.")),
        "tender": {"lines": lines(("Tender Agna: The tide brings fresh water in at the stilt-spring. Let your team drink.", "Pflegerin Agna: Die Flut bringt am Pfahlbrunnen frisches Wasser. Lass dein Team trinken.")),
                   "action": "heal"},
        "trader": {"lines": lines(("Trader Lusk: Dry towels and remedies. The fen gets into everything.", "Händler Lusk: Trockentücher und Heilmittel. Der Fenn kriecht in alles.")),
                   "action": "shop tonic strong_tonic max_tonic remedy dry_towel wake_bell revival_leaf kin_charm"},
        "boatman": {"lines": lines(("Boatman Rurik: The Lake Line runs again. Brindlewick, Quillbrook, wherever you've set foot.", "Bootsmann Rurik: Die Seelinie fährt wieder. Brindlewick, Federbach, überall, wo du schon warst.")),
                    "action": "transit lake_line"},
    })
    m = {"name": tr("Reedhaven", "Schilfhafen"), "biome": "town", "backdrop": "lake", "outdoor": True,
         "heal_point": [9, 4], "rows": rows,
         "warps": [warp(5, 0, "brackwater_fen", 5, 22, "up"), warp(6, 0, "brackwater_fen", 6, 22, "up")],
         "npcs": [npc("tender", 8, 5, "up", mid + "/tender", "elder"),
                  npc("trader", 4, 7, "right", mid + "/trader", "villager"),
                  npc("boatman", 3, 8, "right", mid + "/boatman", "villager")],
         "signs": [{"x": 8, "y": 7, "dialogue": mid + "/sign"}],
         "secrets": [secret(11, 8, "tonic", "find_reed_end", 2), secret(10, 7, "remedy", "find_reed_reeds"),
                     secret(0, 4, "kin_charm", "find_reed_west")]}
    finish(world, mid, m)


# --- Lantern Steps: a stair of five terraces above Thornridge, a lantern on each (item 917) --
def lantern_steps(world):
    mid = "lantern_steps"
    rows = ["@@@@@__@@@@@",
            "@:...__...:@",
            "@.L..__..L.@",
            "@^^^^^=^^^v@",
            "@:..._____.@",
            "@.L.:_..L..@",
            "@^^=^^^^^^v@",
            "@..__.....:@",
            "@.L.___.L..@",
            "@^^^^^^=^^v@",
            "@::...___..@",
            "@.L..__..L.@",
            "@^^=^^^^^^v@",
            "@...__..:..@",
            "@.L.:____L.@",
            "@^^^^^^^=^^@",
            "@.@..___...@",
            "@..S.__....@",
            "@@@@@__@@@@@"]
    world.add_text(mid, {
        "sign": lines(("LANTERN STEPS", "LATERNENSTUFEN"), ("Rock stair, rings 10 to 13.", "Felsstiege, Ring 10 bis 13."),
                      ("Five terraces up to Copperfold. A lantern burns on every one.", "Fünf Terrassen hinauf nach Copperfold. Auf jeder brennt eine Laterne.")),
        "smooth": lines(("Chisel marks run all over this stone. Someone hid something here.", "Über diesen Stein laufen Meißelspuren. Hier hat jemand etwas versteckt.")),
    })
    m = {"name": tr("Lantern Steps", "Laternenstufen"), "biome": "scree", "backdrop": "ridge", "outdoor": True, "encounters": mid,
         "rows": rows,
         "warps": [warp(5, 18, "thornridge", 9, 2, "down"), warp(6, 18, "thornridge", 9, 2, "down"),
                   warp(5, 0, "copperfold", 5, 18, "up"), warp(6, 0, "copperfold", 6, 18, "up")],
         "npcs": [
             wayfarer(world, mid, "tova", 9, 16, "left", "Lamplighter Tova", team(("Wickit", 11), ("Kindlop", 11)),
                      [("Tova: I light all five lanterns every evening. My knees know every step.", "Tova: Ich zünde jeden Abend alle fünf Laternen an. Meine Knie kennen jede Stufe.")],
                      [("Tova: Climbing my stair? Show me your spark first.", "Tova: Du steigst meine Stiege hinauf? Zeig mir erst deinen Funken.")],
                      [("Tova: Bright enough. Go on up.", "Tova: Hell genug. Geh nur hinauf.")], 330),
             wayfarer(world, mid, "garr", 2, 10, "right", "Miner Garr", team(("Shalebat", 12), ("Mirkmole", 12)),
                      [("Garr: Copperfold's at the top. Best hot pies in the valley.", "Garr: Oben liegt Copperfold. Die besten heißen Pasteten im Tal.")],
                      [("Garr: Off shift and bored. Battle?", "Garr: Feierabend und Langeweile. Kampf?")],
                      [("Garr: Back to the pies, then.", "Garr: Dann zurück zu den Pasteten.")], 350),
             wayfarer(world, mid, "isa", 8, 4, "left", "Wanderer Isa", team(("Zephlet", 13), ("Zephlet", 12), ("Shalebat", 13)),
                      [("Isa: From up here you can see three Rifts on a clear night.", "Isa: Von hier oben siehst du in klaren Nächten drei Risse.")],
                      [("Isa: The last terrace is mine. Earn it.", "Isa: Die letzte Terrasse gehört mir. Verdien sie dir.")],
                      [("Isa: It's yours.", "Isa: Sie gehört dir.")], 380),
         ],
         "signs": [{"x": 3, "y": 17, "dialogue": mid + "/sign"}, {"x": 1, "y": 15, "dialogue": mid + "/smooth"}],
         "blocks": [{"x": 2, "y": 16, "open_flag": "pass_lantern"}],
         "passages": [passage(2, 16, "pass_lantern")],
         "secrets": [secret(11, 13, "tonic", "find_steps_east", 2), secret(0, 7, "remedy", "find_steps_west"),
                     secret(11, 1, "spark_drop", "find_steps_top"), secret(1, 16, "max_tonic", "find_steps_pocket")]}
    # Shortcut (item 919): the vine column on the east side climbs all five terraces at once
    # with the Climbing Pick.
    finish(world, mid, m)


# --- Copperfold: a mining settlement at the top of the Lantern Steps (item 951) --------------
def copperfold(world):
    mid = "copperfold"
    rows = ["@@@@@@@@@@@@",
            "@..|..:..|.@",
            "@..|.....|.@",
            "@RRRR.._RRR@",
            "@HHDH.._HDH@",
            "@..._____..@",
            "@.:.._..._.@",
            "@.o.._..##.@",
            "@....____..@",
            "@^^^^^^=^^^@",
            "@.:..___...@",
            "@.RRR._.:..@",
            "@.HDH._..S.@",
            "@..__._....@",
            "@:.._.__.:.@",
            "@....._....@",
            "@:...___..:@",
            "@....___...@",
            "@@@@@__@@@@@"]
    world.add_text(mid, {
        "sign": lines(("COPPERFOLD", "KUPFERFALT"), ("Copperfold, 52 folk.", "Kupferfalt, 52 Leute."),
                      ("Mind the carts. The winding tower rings at every shift.", "Achtung Loren. Der Förderturm läutet zu jedem Schichtwechsel.")),
        "pitkeeper": {"lines": lines(("Pit Keeper Dorn: The warm spring comes straight up from the deep seams. Rest here.", "Grubenwart Dorn: Die warme Quelle kommt direkt aus den tiefen Flözen. Ruh dich hier aus.")),
                      "action": "heal"},
        "trader": {"lines": lines(("Trader Wilma: Gear for the deep and brews for the brave.", "Händlerin Wilma: Ausrüstung für die Tiefe und Tränke für die Mutigen.")),
                   "action": "shop tonic strong_tonic max_tonic remedy cooling_gel wake_bell spark_drop revival_leaf dash_brew guard_brew"},
        "smith": {"lines": lines(("Smith Holt: You came up the Steps without a pry bar? Brave or daft.", "Schmied Holt: Du bist ohne Hebelstange die Stufen hoch? Mutig oder verrückt."),
                              ("Smith Holt: Take this one. Sluice wheels, stuck carts, rusty grates: lean on it and they give.", "Schmied Holt: Nimm die hier. Schleusenräder, festsitzende Loren, rostige Gitter: stemm dich dagegen und sie geben nach.")),
                  "action": "give_item pry_bar 1", "flag": "got_pry_bar", "once": True,
                  "after_flag": {"flag": "got_pry_bar", "lines": lines(("Smith Holt: Bring me ore some day and I'll make that bar sing.", "Schmied Holt: Bring mir irgendwann Erz, dann bringe ich die Stange zum Singen."))}},
        "coach": {"lines": lines(("Driver Bram: Valley Coach, Copperfold stop. Mind your head, the roof is low.", "Kutscher Bram: Talkutsche, Halt Kupferfalt. Pass auf deinen Kopf auf, das Dach ist niedrig.")),
                  "action": "transit valley_coach"},
        "shift": lines(("Miner Pell-Anne: The lower seams cracked in the storm. Nobody goes below the second level now.", "Bergfrau Pell-Anne: Die unteren Flöze sind im Sturm gerissen. Unter die zweite Sohle geht jetzt niemand mehr.")),
    })
    m = {"name": tr("Copperfold", "Kupferfalt"), "biome": "town", "backdrop": "ridge", "outdoor": True,
         "heal_point": [3, 7], "rows": rows,
         "warps": [warp(5, 18, "lantern_steps", 5, 1, "down"), warp(6, 18, "lantern_steps", 6, 1, "down")],
         "npcs": [npc("pitkeeper", 3, 6, "down", mid + "/pitkeeper", "elder"),
                  npc("trader", 9, 10, "left", mid + "/trader", "villager"),
                  npc("smith", 1, 5, "right", mid + "/smith", "villager"),
                  npc("shift", 10, 13, "left", mid + "/shift", "villager"),
                  npc("coach", 10, 17, "left", mid + "/coach", "villager")],
         "signs": [{"x": 9, "y": 12, "dialogue": mid + "/sign"}],
         "secrets": [secret(11, 15, "tonic", "find_copper_east", 2), secret(0, 10, "spark_drop", "find_copper_west"),
                     secret(4, 1, "remedy", "find_copper_tower")]}
    finish(world, mid, m)


# --- Links from the Act I maps (patched, see veydal_core) ------------------------------------
def connect_act1(world):
    def link(mid, x, y, ch, w):
        m = world.load_map(mid)
        r = m["rows"][y]
        m["rows"][y] = r[:x] + ch + r[x + 1:]
        if not any(int(o["x"]) == x and int(o["y"]) == y for o in m["warps"]):
            m["warps"].append(w)

    link("fernstair", 0, 12, "_", warp(0, 12, "gloamwood", 10, 24, "left"))
    link("crowcrest", 0, 4, "_", warp(0, 4, "gloamwood", 10, 2, "left"))
    link("brindlewick", 0, 12, "_", warp(0, 12, "quillbrook", 10, 1, "left"))
    link("saltmarsh", 11, 7, "+", warp(11, 7, "brackwater_fen", 1, 18, "right"))
    link("thornridge", 9, 1, "=", warp(9, 1, "lantern_steps", 5, 17, "up"))
