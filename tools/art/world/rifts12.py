"""The three Rifts added by the owner decision of 2026-11-10 (twelve Rifts instead of six; the
three of Solenne follow later): the Mist Rift in Veydal, the Root Rift in Corvane and the Shade
Rift in Ashmere. Each one has the same shape (docs/STORY.md "Rifts and Wardens"):

  entrance (bottom)  ->  a Rift acolyte and two Wayfarers  ->  a puzzle that opens the way
  ->  a spring to rest at  ->  the Warden at the tear  ->  a shortcut down the east side that
  opens once the Rift is mended.

How the way in opens:
  crowcrest -> mist_rift            always (east end of the lower path)
  woadfen -> root_rift              rift_mirror_sealed (gate on the moor), then a tag battle
                                    with Kestra at the mouth (kestra_root_tag)
  saltglass -> shade_rift           veit_plate_done (the silent lighthouse door), then Veit's
                                    last duel (beat_veit_3)
Edit here, then run tools/art/build_world.py.
"""
from common import check_rows, lines, npc, team, tr, warp

GROUP = ["mist_rift", "root_rift", "shade_rift"]

# Cells shared by all three maps.
WARDEN = (5, 2)
HEART = (8, 2)
SPRING = (3, 4)
PIECES = [(2, 8), (6, 9), (8, 10)]
HINT = (1, 11)
SHORTCUT_GATE = (10, 18)
PUZZLE_GATE = [(4, 7), (5, 7), (6, 7), (7, 7)]


def base_rows(ground):
    """22 x 12 Rift hollow; `ground` is the wild tile (":" scree, "," fern)."""
    g = ground
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^.........^",
            "^.gg....g^_^",
            "^..o.....^_^",
            "^.......S^_^",
            "^^^^....^^_^",
            "^^^^....^^_^",
            "^........^_^",
            "^.gg.....^_^",
            "^.gg.....^_^",
            "^........^_^",
            "^^^^..^^^^_^",
            "^.gg....g^_^",
            "^........^_^",
            "^^^..^^^^^_^",
            "^.gg....g^_^",
            "^........^_^",
            "^^^^..^^^^.^",
            "^..........^",
            "^.gg....gg.^",
            "^^^^^..^^^^^"]
    return [r.replace("g", g) for r in rows]


def put(rows, x, y, ch):
    rows[y] = rows[y][:x] + ch + rows[y][x + 1:]


def gate(x, y, flag, closed="@"):
    return {"x": x, "y": y, "open_flag": flag, "closed": closed}


def wayfarer(world, mid, id_, x, y, facing, title, crew, talk, intro, defeat, money, sprite="villager"):
    world.add_text(mid, {id_: lines(*talk), id_ + "_intro": lines(*intro), id_ + "_defeat": lines(*defeat)})
    return npc(id_, x, y, facing, "%s/%s" % (mid, id_), sprite, trainer=title,
               intro="%s/%s_intro" % (mid, id_), defeat="%s/%s_defeat" % (mid, id_), money=money, team=crew)


def warden(world, mid, rift, name, crew, rule, gift, money, before, intro, defeat, mended, finale):
    """A Warden in the shape of item 1605: a line before waking (base), after the duel (defeat),
    after the mend and after the finale (after_flag)."""
    key = name.lower()
    world.add_text(mid, {
        key: {"lines": lines(*before), "after_flag": [
            {"flag": "rift_%s_sealed" % rift, "lines": lines(*mended)},
            {"flag": "story_complete", "lines": lines(*finale)}]},
        key + "_intro": lines(*intro),
        key + "_defeat": lines(*defeat),
    })
    x, y = WARDEN
    return npc("warden_" + key, x, y, "down", "%s/%s" % (mid, key), "warden", trainer="Warden " + name,
               warden=rift, team=crew, intro="%s/%s_intro" % (mid, key), defeat="%s/%s_defeat" % (mid, key),
               ai=2, money=money, rule=rule, mend_items=[gift], rematch_after="story_complete")


def rest_and_signs(world, mid, title, motto):
    world.add_text(mid, {
        "spring": {"lines": lines(("A cold spring bubbles up between the stones.", "Eine kalte Quelle sprudelt zwischen den Steinen."),
                                  ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")),
                   "action": "heal"},
        "sign": lines(title, motto),
    })
    sx, sy = SPRING
    return [{"x": sx, "y": sy, "dialogue": mid + "/spring"}, {"x": 8, "y": 5, "dialogue": mid + "/sign"}]


def switch_pieces(world, mid, rows, flag, kind, tile, names, order, hint):
    """Three puzzle pieces rung in `order` (indices into PIECES), with a hint on the wall."""
    signs = []
    for i, (x, y) in enumerate(PIECES):
        put(rows, x, y, tile)
        en, de = names[i]
        key = "%s_%d" % (kind, i + 1)
        world.add_text(mid, {key: {"lines": lines((en, de)), "action": "bell %s %d %d %s" % (flag, order.index(i) + 1, len(PIECES), kind)}})
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, key)})
    hx, hy = HINT
    put(rows, hx, hy, "S")
    world.add_text(mid, {"hint": lines(hint)})
    signs.append({"x": hx, "y": hy, "dialogue": mid + "/hint"})
    return signs


def finish(world, mid, m, region):
    check_rows(mid, m["rows"])
    m["region"] = region
    world.add_map(mid, m)


def build(world):
    mist_rift(world)
    root_rift(world)
    shade_rift(world)


def common_fields(mid, name, field, backdrop, rows, back_to):
    to, tx, ty, facing = back_to
    m = {"name": name, "biome": "rift", "backdrop": backdrop, "encounters": mid, "heal_point": [SPRING[0], SPRING[1] + 1],
         "rows": rows,
         "warps": [warp(5, 21, to, tx, ty, facing), warp(6, 21, to, tx, ty, facing)],
         "blocks": [gate(x, y, "%s_open" % mid) for x, y in PUZZLE_GATE] + [gate(SHORTCUT_GATE[0], SHORTCUT_GATE[1], "rift_%s_sealed" % mid[:-5])]}
    if field:
        m["field"] = field
    return m


# --- The Mist Rift: Warden Brisa, lost in her own fog (ring 12-14), between Rift 1 and 2 -------
def mist_rift(world):
    mid = "mist_rift"
    rows = base_rows(":")
    signs = rest_and_signs(world, mid, ("THE MIST RIFT", "DER NEBELRISS"), ("The fog moves the paths while you walk them.", "Der Nebel verschiebt die Wege, während du gehst."))
    signs += switch_pieces(world, mid, rows, "mist_rift_open", "vane", "|",
                           [("An old wind vane, rusted stiff. West.", "Eine alte Windfahne, steif vor Rost. West."),
                            ("An old wind vane, rusted stiff. Middle.", "Eine alte Windfahne, steif vor Rost. Mitte."),
                            ("An old wind vane, rusted stiff. East.", "Eine alte Windfahne, steif vor Rost. Ost.")],
                           [1, 0, 2],
                           ("Scratched into the rock: middle vane, west vane, east vane.", "In den Fels geritzt: mittlere Fahne, westliche Fahne, östliche Fahne."))
    m = common_fields(mid, tr("Mist Rift", "Nebelriss"), "", "ridge", rows, ("crowcrest", 10, 17, "left"))
    world.add_text(mid, {
        "heart": lines(("The fog curls into a tight grey knot here.", "Der Nebel rollt sich hier zu einem festen grauen Knoten.")),
        "heart_intro": lines(("The fog draws together into one heavy heart.", "Der Nebel zieht sich zu einem schweren Herz zusammen."),
                             ("Brisa: That's what kept me lost. Bring everyone you have!", "Brisa: Das hat mich verirren lassen. Bring alle mit, die du hast!")),
        "heart_defeat": lines(("The Mist Heart frays into thin morning air.", "Das Nebelherz zerfasert zu dünner Morgenluft."),
                              ("Brisa: Clear as a bell. Now the Rift is truly quiet.", "Brisa: Klar wie eine Glocke. Jetzt ist der Riss wirklich still.")),
    })
    m["npcs"] = [
        wayfarer(world, mid, "rhee", 7, 17, "left", tr("Rift Acolyte Rhee", "Riss-Akolythin Rhee"), team(("Zephlet", 12), ("Shalebat", 12)),
                 [("Rhee: We tie ropes from post to post. The fog unties them.", "Rhee: Wir spannen Seile von Pfahl zu Pfahl. Der Nebel knotet sie auf.")],
                 [("Rhee: Stop! Brisa walks in circles up there. Prove you won't.", "Rhee: Halt! Brisa läuft da oben im Kreis. Beweis, dass du es nicht tust.")],
                 [("Rhee: You keep your bearings. Good. Go on.", "Rhee: Du behältst die Richtung. Gut. Geh weiter.")], 520, sprite="warden"),
        wayfarer(world, mid, "hask", 2, 14, "right", tr("Ridgewalker Hask", "Gratläufer Hask"), team(("Millwhit", 12), ("Puddlet", 13)),
                 [("Hask: I came up for the view. There is no view.", "Hask: Ich bin wegen der Aussicht hochgekommen. Es gibt keine Aussicht.")],
                 [("Hask: Can't see a thing. Let's duel by ear!", "Hask: Man sieht nichts. Kämpfen wir nach Gehör!")],
                 [("Hask: Heard that one coming. Too late.", "Hask: Den habe ich kommen hören. Zu spät.")], 540),
        wayfarer(world, mid, "ilda", 7, 11, "left", tr("Fog Walker Ilda", "Nebelgängerin Ilda"), team(("Zephlet", 12), ("Puddlet", 12), ("Zippit", 12)),
                 [("Ilda: Turn the vanes and the wind comes back. My gran told me so.", "Ilda: Dreh die Fahnen, dann kommt der Wind zurück. Hat meine Oma gesagt.")],
                 [("Ilda: One more duel before the vanes. Ready?", "Ilda: Noch ein Duell vor den Fahnen. Bereit?")],
                 [("Ilda: Go. Brisa needs the wind more than I do.", "Ilda: Geh. Brisa braucht den Wind dringender als ich.")], 560),
        warden(world, mid, "mist", "Brisa", team(("Zephlet", 12), ("Millwhit", 12), ("Tempestrel", 13)), "fog_bank", "echo_tailwind", 950,
               [("Brisa: Which way was out? The fog keeps moving the paths.", "Brisa: Welcher Weg führte hinaus? Der Nebel verschiebt die Wege.")],
               [("Brisa: Who's there? Everything sounds far away in here.", "Brisa: Wer ist da? Hier drin klingt alles so fern."),
                ("Brisa: My Zephlet used to find the way. Now it only circles.", "Brisa: Mein Zephlet hat früher den Weg gefunden. Jetzt kreist es nur.")],
               [("Brisa: ...A gust! My Zephlet is tugging at my sleeve.", "Brisa: ...Eine Bö! Mein Zephlet zupft an meinem Ärmel."),
                ("Brisa: I know the way again. Help me draw the Rift's edge.", "Brisa: Ich kenne den Weg wieder. Hilf mir, den Rand des Risses zu zeichnen.")],
               [("Brisa: The fog lifted. I can see Crowcrest from here!", "Brisa: Der Nebel hat sich gehoben. Von hier sehe ich Crowcrest!"),
                ("Brisa: Let the wind carry you, not lose you.", "Brisa: Lass dich vom Wind tragen, nicht verlieren.")],
               [("Brisa: I walk the ridge every morning now. No fog, only wind.", "Brisa: Ich gehe jetzt jeden Morgen über den Grat. Kein Nebel, nur Wind.")]),
        npc("mist_heart", HEART[0], HEART[1], "down", mid + "/heart", "hush", color="9aa4ae", trainer=tr("Mist Heart", "Nebelherz"),
            boss="mist_heart", front=[4, 1], money=700, show_flag="rift_mist_sealed", hide_flag="mist_heart_mended",
            intro=mid + "/heart_intro", defeat=mid + "/heart_defeat", team=team(("Millwhit", 15)),
            win_flags=["mist_heart_mended"], leaves=True),
    ]
    m["signs"] = signs
    finish(world, mid, m, "veydal")


# --- The Root Rift: Warden Darrow, who wants nothing to grow (ring 23-26) ---------------------
def root_rift(world):
    mid = "root_rift"
    rows = base_rows(",")
    for y in (9, 10):
        rows[y] = rows[y][:2] + "%%" + rows[y][4:]
    signs = rest_and_signs(world, mid, ("THE ROOT RIFT", "DER WURZELRISS"), ("Grey roots, thick as arms. Nothing grows on them.", "Graue Wurzeln, dick wie Arme. Nichts wächst auf ihnen."))
    signs += switch_pieces(world, mid, rows, "root_rift_open", "root", "@",
                           [("A grey root knot. Rub it, and it could turn green.", "Ein grauer Wurzelknoten. Reib ihn, und er könnte grün werden."),
                            ("A grey root knot. Rub it, and it could turn red.", "Ein grauer Wurzelknoten. Reib ihn, und er könnte rot werden."),
                            ("A grey root knot. Rub it, and it could turn yellow.", "Ein grauer Wurzelknoten. Reib ihn, und er könnte gelb werden.")],
                           [1, 2, 0],
                           ("Painted by a dyer: madder red, then weld yellow, then woad green.", "Von einer Färberin gemalt: Krapprot, dann Waugelb, dann Waidgrün."))
    m = common_fields(mid, tr("Root Rift", "Wurzelriss"), "pollen_drift", "field", rows, ("woadfen", 10, 15, "left"))
    # Kestra waits at the mouth: the way in opens after the tag battle with her.
    m["blocks"] += [gate(4, 18, "kestra_root_tag"), gate(5, 18, "kestra_root_tag")]
    world.add_text(mid, {
        "kestra": {"if": {"not_flag": "kestra_root_tag"}, "else": "kestra_after",
                   "lines": lines(("Kestra: There you are. Tatter wouldn't stop pulling me here.", "Kestra: Da bist du ja. Tatter hat mich die ganze Zeit hierher gezerrt."),
                                  ("Kestra: Hushed Wanderers block the roots. Two of us, two of them?", "Kestra: Verstummte Wanderer versperren die Wurzeln. Wir zwei gegen sie?")),
                   "action": "battle kestra_root_tag"},
        "kestra_after": lines(("Kestra: Go on in. I'll keep the mouth clear behind you.", "Kestra: Geh nur rein. Ich halte dir den Eingang frei.")),
        "kestra_tag_defeat": lines(("The Wanderers shake the grey dust from their coats.", "Die Wanderer schütteln den grauen Staub von ihren Mänteln."),
                                   ("Kestra: Side by side again. I could get used to this.", "Kestra: Wieder Seite an Seite. Daran könnte ich mich gewöhnen.")),
        "kestra_tag_lose": lines(("Kestra: The roots won this round. Rest, then we try again.", "Kestra: Die Wurzeln haben diese Runde gewonnen. Ruh dich aus, dann noch mal.")),
    })
    m["npcs"] = [
        npc("kestra_r", 3, 19, "right", mid + "/kestra", "ranger"),
        wayfarer(world, mid, "wen", 7, 17, "left", tr("Rift Acolyte Wen", "Riss-Akolyth Wen"), team(("Thornback", 24), ("Mossling", 23)),
                 [("Wen: Darrow pulls up every sprout. Says it only fades anyway.", "Wen: Darrow reißt jeden Keim aus. Sagt, er verblasst ja doch."),],
                 [("Wen: You want to reach him? Through my roots first.", "Wen: Du willst zu ihm? Erst durch meine Wurzeln.")],
                 [("Wen: Maybe you can make him look at a leaf again.", "Wen: Vielleicht bringst du ihn dazu, wieder ein Blatt anzusehen.")], 1150, sprite="warden"),
        wayfarer(world, mid, "corm", 2, 14, "right", tr("Moor Digger Corm", "Moorgräber Corm"), team(("Croziel", 24), ("Hushkin", 24)),
                 [("Corm: I dig peat. Down here the peat digs back.", "Corm: Ich steche Torf. Hier unten sticht der Torf zurück.")],
                 [("Corm: Watch your step. And your Spirlings.", "Corm: Pass auf, wo du hintrittst. Und auf deine Spirlings.")],
                 [("Corm: Deep roots, that one. Like you.", "Corm: Tiefe Wurzeln, das. Wie du.")], 1180),
        wayfarer(world, mid, "tilde", 7, 11, "left", tr("Herbalist Tilde", "Kräuterkundige Tilde"), team(("Reedquill", 24), ("Fluting", 25), ("Kelpup", 24)),
                 [("Tilde: The roots remember their colours. You only have to remind them.", "Tilde: Die Wurzeln erinnern sich an ihre Farben. Du musst sie nur daran erinnern.")],
                 [("Tilde: Let's see what grows in you.", "Tilde: Mal sehen, was in dir wächst.")],
                 [("Tilde: A lot, it seems. Go to Darrow.", "Tilde: Eine Menge, wie es scheint. Geh zu Darrow.")], 1200),
        warden(world, mid, "root", "Darrow", team(("Thornback", 25), ("Frondmere", 26), ("Reedwarden", 25), ("Marshfife", 26)), "vine_tangle", "echo_root_grip", 1400,
               [("Darrow: Nothing grows here. Nothing should. It all fades.", "Darrow: Hier wächst nichts. Hier soll nichts wachsen. Alles verblasst.")],
               [("Darrow: Every leaf in Corvane went grey. Why grow new ones?", "Darrow: Jedes Blatt in Corvane wurde grau. Warum neue wachsen lassen?"),
                ("Darrow: Turn back. Or let my roots hold you here.", "Darrow: Kehr um. Oder lass dich von meinen Wurzeln festhalten.")],
               [("Darrow: ...My Thornback is flowering. In the middle of the Fading.", "Darrow: ...Mein Thornback blüht. Mitten im Verblassen."),
                ("Darrow: Maybe things should grow after all. Help me close it.", "Darrow: Vielleicht soll doch etwas wachsen. Hilf mir, ihn zu schließen.")],
               [("Darrow: Green, under the grey. I'd forgotten green was a colour.", "Darrow: Grün, unter dem Grau. Ich hatte vergessen, dass Grün eine Farbe ist."),
                ("Darrow: This crystal holds a root's grip. Hold on to what grows.", "Darrow: Dieser Kristall hält den Griff einer Wurzel. Halt fest, was wächst.")],
               [("Darrow: I planted a garden by the moor. Weeds and all.", "Darrow: Ich habe am Moor einen Garten angelegt. Mit Unkraut und allem.")]),
    ]
    m["signs"] = signs
    finish(world, mid, m, "corvane")


# --- The Shade Rift: Warden Odalys, who put out her own light, inside the silent lighthouse ----
# The beam comes in at the west wall of row 8; two mirrors steer it onto the beacon.
SHADE_MIRRORS = [(6, 8, "/"), (6, 10, "\\"), (3, 10, "/")]
BEACON = (8, 10)


def shade_rift(world):
    mid = "shade_rift"
    rows = base_rows(":")
    signs = rest_and_signs(world, mid, ("THE SHADE RIFT", "DER SCHATTENRISS"), ("Inside the silent lighthouse. The lamp has not burned for a year.", "Im stillen Leuchtturm. Die Lampe hat seit einem Jahr nicht gebrannt."))
    world.add_text(mid, {"beacon": lines(("The old beacon lens, cold and dark. It waits for light.", "Die alte Leuchtfeuerlinse, kalt und dunkel. Sie wartet auf Licht."))})
    mirrors = []
    for x, y, way in SHADE_MIRRORS:
        put(rows, x, y, "S")
        key = "mirror_%d_%d" % (x, y)
        world.add_text(mid, {key: {"lines": lines(("A tall lighthouse mirror on a turning stand.", "Ein hoher Leuchtturmspiegel auf einem Drehgestell.")),
                                   "action": "mirror %d %d" % (x, y)}})
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, key)})
        mirrors.append([x, y, way])
    put(rows, BEACON[0], BEACON[1], "S")
    signs.append({"x": BEACON[0], "y": BEACON[1], "dialogue": mid + "/beacon"})
    m = common_fields(mid, tr("Shade Rift", "Schattenriss"), "deep_murk", "voice", rows, ("saltglass", 8, 7, "down"))
    m["beam"] = {"x": 0, "y": 8, "dir": "right", "mirrors": mirrors, "target": list(BEACON), "flag": "shade_rift_open"}
    # Veit stands at the foot of the stairs: his last duel opens the way up.
    m["blocks"] += [gate(4, 18, "beat_veit_3"), gate(5, 18, "beat_veit_3")]
    world.add_text(mid, {
        "veit": lines(("Veit: Go on. I'll wait down here for the light.", "Veit: Geh nur. Ich warte hier unten auf das Licht.")),
        "veit_intro": lines(("Veit: You again. Of course it's you.", "Veit: Du schon wieder. Natürlich bist du es."),
                            ("Veit: One last duel. Then I stop standing in your way.", "Veit: Ein letztes Duell. Dann stelle ich mich dir nicht mehr in den Weg.")),
        "veit_defeat": lines(("Veit: That was the last time. I mean it.", "Veit: Das war das letzte Mal. Ehrlich."),
                             ("Veit: Odalys is up there in the dark. She listens better than I did.", "Veit: Odalys ist da oben im Dunkeln. Sie hört besser zu als ich.")),
    })
    m["npcs"] = [
        npc("veit_s", 3, 19, "right", mid + "/veit", "ranger", color="5a4a3a", trainer="Veit Harrow",
            team=team(("Shalebat", 35), ("Duskdigger", 35), ("Obsidroth", 36), ("Calderox", 36)),
            intro=mid + "/veit_intro", defeat=mid + "/veit_defeat", beaten_flag="beat_veit_3", leaves=True, hide_flag="beat_veit_3",
            ai=3, money=1700),
        wayfarer(world, mid, "sabe", 7, 17, "left", tr("Rift Acolyte Sabe", "Riss-Akolyth Sabe"), team(("Mendlace", 34), ("Silentra", 34)),
                 [("Sabe: Odalys climbed up and blew the lamp out. Then she stayed.", "Sabe: Odalys ist hochgestiegen und hat die Lampe ausgeblasen. Dann ist sie geblieben.")],
                 [("Sabe: Nobody goes up in the dark. Not without a duel.", "Sabe: Im Dunkeln geht keiner hoch. Nicht ohne Duell.")],
                 [("Sabe: Then take the light up with you.", "Sabe: Dann nimm das Licht mit nach oben.")], 1550, sprite="warden"),
        wayfarer(world, mid, "fenna", 2, 14, "right", tr("Lamp Tender Fenna", "Lampenwärterin Fenna"), team(("Wickit", 33), ("Lanternel", 34)),
                 [("Fenna: I trimmed this lamp for thirty years. Now I trim the dark.", "Fenna: Dreißig Jahre habe ich diese Lampe geputzt. Jetzt putze ich die Dunkelheit.")],
                 [("Fenna: Let's see if you burn steady.", "Fenna: Mal sehen, ob du ruhig brennst.")],
                 [("Fenna: Steady as a beacon. Go on up.", "Fenna: Ruhig wie ein Leuchtfeuer. Geh hoch.")], 1580),
        wayfarer(world, mid, "oren", 7, 11, "left", tr("Salt Diver Oren", "Salztaucher Oren"), team(("Brinelet", 34), ("Blotling", 34), ("Hushkin", 35)),
                 [("Oren: Turn the mirrors right and the beacon catches. Wrong, and it stays black.", "Oren: Dreh die Spiegel richtig, und das Leuchtfeuer fängt Licht. Falsch, und es bleibt schwarz.")],
                 [("Oren: In the dark you can't tell who strikes first. Ready?", "Oren: Im Dunkeln weiß man nicht, wer zuerst zuschlägt. Bereit?")],
                 [("Oren: You struck first, it seems. Go.", "Oren: Du hast wohl zuerst zugeschlagen. Geh.")], 1600),
        warden(world, mid, "shade", "Odalys", team(("Silentra", 35), ("Fenwarden", 36), ("Burinox", 35), ("Mendlace", 35), ("Scrivane", 36)), "night_dark", "echo_night_veil", 1700,
               [("Odalys: Leave the lamp dark. Light only shows what's gone.", "Odalys: Lass die Lampe dunkel. Licht zeigt nur, was fehlt.")],
               [("Odalys: I put the beacon out myself. The dark hides the empty flats.", "Odalys: Ich habe das Leuchtfeuer selbst gelöscht. Das Dunkel verbirgt die leere Ebene."),
                ("Odalys: You lit it again. Then face what the dark keeps.", "Odalys: Du hast es wieder entzündet. Dann stell dich dem, was das Dunkel verwahrt.")],
               [("Odalys: ...My Silentra is glowing. It never glowed for me before.", "Odalys: ...Mein Silentra leuchtet. Für mich hat es noch nie geleuchtet."),
                ("Odalys: All right. Let the light back in. Help me mend this.", "Odalys: Also gut. Lass das Licht wieder herein. Hilf mir, das zu flicken.")],
               [("Odalys: The beacon burns. Ships could find this coast again.", "Odalys: Das Leuchtfeuer brennt. Schiffe könnten diese Küste wiederfinden."),
                ("Odalys: Take this. Night Veil, for the dark you still have to cross.", "Odalys: Nimm das. Nachtschleier, für das Dunkel, das du noch durchqueren musst.")],
               [("Odalys: I keep the lamp lit now. Every night, for whoever is out there.", "Odalys: Ich halte die Lampe jetzt brennend. Jede Nacht, für alle da draußen.")]),
    ]
    m["signs"] = signs
    finish(world, mid, m, "ashmere")
