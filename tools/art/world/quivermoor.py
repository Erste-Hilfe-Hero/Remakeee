"""Quivermoor, the post-game Era V region (data/region5.json): five towns, six routes, four Rifts
and three landmarks (the Choir Loft, the Walking Oaks, the Raft Market), all from the region
sheet. Region "quivermoor", drawn with the Era V atlas art/era5/tiles/overworld_quivermoor.png
(bog water, peat, moss, candle posts, raft decks). Edit here, then run
tools/art/build_world.py quivermoor.

How the way opens (flags from data/region5.json):
  whitecairn <-> mossgate         the rope basket, line "quivermoor_rope", open_flag era4_finale_done
                                  (the winch man in Whitecairn is built by halcyra.py)
  mossgate, Reeve Ashby           sets v5_ch1_done (chapter 1)
  tallowmere -> wick_rift         v5_ch1_done
  rootchapel -> chapel_rift       rift_v5_wick_sealed
  driftwick -> raft_rift          rift_v5_chapel_sealed
  lastbloom -> bloom_rift         rift_v5_raft_sealed
  lastbloom, Nell Tallis          shows after rift_v5_bloom_sealed, sets quivermoor_done (Era V finale)

Wardens carry the warden key v5_<rift>, so GameState.seal_rift sets rift_v5_<rift>_sealed, the
flag the sheet names. Towns share Halcyra's crossroads (spring at 6, 8 as the square, the keeper
beside it, three locals there at dusk). Exits: top (5, 0), bottom (5, last), left (0, 8),
right (11, 8), two cells each.
"""
import importlib.util as _u
import json
import os

from common import ROOT, check_rows, lines, npc, secret, team, tr, warp
from rifts12 import base_rows, gate, wayfarer
from townsfolk import at, away

SHEET = json.load(open(os.path.join(ROOT, "data", "region5.json"), encoding="utf-8"))
TOWNS = [t["id"] for t in SHEET["towns"]]
ROUTES = [r["id"] for r in SHEET["routes"]]
RIFTS = [r["id"] for r in SHEET["rifts"]]
LANDMARKS = [l["id"] for l in SHEET["landmarks"]]
GROUP = TOWNS + ROUTES + RIFTS + LANDMARKS

# German for the sheet's own texts (names, story, landmarks), from tools/i18n/de_region5.py.
_spec = _u.spec_from_file_location("de_region5", os.path.join(ROOT, "tools", "i18n", "de_region5.py"))
_mod = _u.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
DE = dict(_mod.T)
for _k in _mod.KEEP:
    DE.setdefault(_k, _k)

TOWN_H = 20
ROUTE_H = 24
RIFT_H = 22
TOWN_IN = {"top": ((5, 1), (6, 1)), "bottom": ((5, TOWN_H - 2), (6, TOWN_H - 2)),
           "left": ((1, 8), (1, 9)), "right": ((10, 8), (10, 9))}
ROUTE_IN = {"top": ((5, 1), (6, 1)), "bottom": ((5, ROUTE_H - 2), (6, ROUTE_H - 2))}
RIFT_IN = {"bottom": ((5, RIFT_H - 2), (6, RIFT_H - 2))}
LINKS = {}


def link(a, side_a, b, side_b):
    LINKS[(a, side_a)] = (b, side_b)
    LINKS[(b, side_b)] = (a, side_a)


link("breathing_bog", "bottom", "mossgate", "top")
link("breathing_bog", "top", "tallowmere", "left")
link("wandering_wood", "top", "mossgate", "bottom")
link("wandering_wood", "bottom", "rootchapel", "top")
link("candle_causeway", "bottom", "tallowmere", "right")
link("candle_causeway", "top", "driftwick", "top")
link("hymnmarsh", "bottom", "rootchapel", "right")
link("hymnmarsh", "top", "driftwick", "left")
link("heaving_fields", "bottom", "driftwick", "right")
link("heaving_fields", "top", "lastbloom", "top")
link("gloamwater", "top", "rootchapel", "bottom")
link("gloamwater", "bottom", "lastbloom", "bottom")
link("wick_rift", "bottom", "tallowmere", "top")
link("chapel_rift", "bottom", "rootchapel", "left")
link("raft_rift", "bottom", "driftwick", "bottom")
link("bloom_rift", "bottom", "lastbloom", "right")

# Gates on the town side of each Rift: (town, side) -> flag (the chapter before it).
RIFT_GATES = {("tallowmere", "top"): "v5_ch1_done", ("rootchapel", "left"): "rift_v5_wick_sealed",
              ("driftwick", "bottom"): "rift_v5_chapel_sealed", ("lastbloom", "right"): "rift_v5_raft_sealed"}

ROPE_STOP = (8, 18)
FACING = {"top": "up", "bottom": "down", "left": "left", "right": "right"}


def arrivals(mid):
    if mid in TOWNS:
        return TOWN_IN
    if mid in ROUTES:
        return ROUTE_IN
    return RIFT_IN


def exit_cells(side, height):
    if side == "top":
        return [(5, 0), (6, 0)]
    if side == "bottom":
        return [(5, height - 1), (6, height - 1)]
    if side == "left":
        return [(0, 8), (0, 9)]
    return [(11, 8), (11, 9)]


def exits(mid, height):
    out = []
    for (a, side), (b, side_b) in sorted(LINKS.items()):
        if a != mid:
            continue
        for (x, y), (tx, ty) in zip(exit_cells(side, height), arrivals(b)[side_b]):
            out.append(warp(x, y, b, tx, ty, FACING[side]))
    return out


def sheet_entry(kind, mid):
    for e in SHEET[kind]:
        if e["id"] == mid:
            return e
    raise SystemExit("%s %s is not on data/region5.json" % (kind, mid))


def finish(world, mid, m):
    check_rows(mid, m["rows"])
    m["region"] = "quivermoor"
    world.add_map(mid, m)


def build(world):
    for t in TOWNS:
        town(world, t)
    for r in ROUTES:
        route(world, r)
    for r in RIFTS:
        rift(world, r)
    choir_loft(world)
    walking_oaks(world)
    raft_market(world)


# --- Towns ---------------------------------------------------------------------------------
CORE = ["^....__....^",
        "^.L..__..S.^",
        "^....__....^",
        "^...____...^",
        "_____.o.____",
        "_____...____",
        "^...____...^",
        "^....__....^"]

TOWN_TOP = {
    "mossgate": ["^TT..__..TT^", "^,,..__..,,^", "^.T..__..T.^"],
    "tallowmere": ["^L.L.__.L.L^", "^.,,.__.,,.^", "^....__....^"],
    "rootchapel": ["^T,,.__.,,T^", "^.TT.__.TT.^", "^....__....^"],
    "driftwick": ["^~~..__..~~^", "^~+..__..+~^", "^.+..__..+.^"],
    "lastbloom": ["^**..__..**^", "^.**.__.**.^", "^.*..__..*.^"],
}
TOWN_BOTTOM = {
    "mossgate": ["^.TT.__.TT.^", "^.,,.__.,,.^", "^....__....^", "^.##.__.##.^", "^....__....^",
                 "^%%..__++L.^", "^....__+++.^"],
    "tallowmere": ["^.LL.__.RR.^", "^....__.HD.^", "^....__....^", "^L##.__.##L^", "^....__....^",
                   "^%%..__..L.^", "^....__....^"],
    "rootchapel": ["^.TT.__.TT.^", "^.,,.__.,,.^", "^....__....^", "^T##.__.##T^", "^....__....^",
                   "^**..__..L.^", "^....__....^"],
    "driftwick": ["^.~~.__.RR.^", "^.~~.__.HD.^", "^....__....^", "^~~~.__.~~~^", "^++..__..++^",
                  "^~~..__..L.^", "^....__....^"],
    "lastbloom": ["^.**.__.**.^", "^....__....^", "^....__....^", "^*.*.__.*.*^", "^....__....^",
                  "^**..__..L.^", "^....__....^"],
}


def town_rows(mid):
    rows = ["^^^^^__^^^^^"] + TOWN_TOP[mid] + CORE + TOWN_BOTTOM[mid] + ["^^^^^__^^^^^"]
    sides = {s for (a, s) in LINKS if a == mid}
    if "top" not in sides:
        rows[0] = "^" * 12
    if "bottom" not in sides:
        rows[-1] = "^" * 12
    for y in (8, 9):
        r = rows[y]
        if "left" not in sides:
            r = "^" + r[1:]
        if "right" not in sides:
            r = r[:-1] + "^"
        rows[y] = r
    return rows


TOWN_TEXT = {
    "mossgate": {
        "sign": [("MOSSGATE", "MOSSGATE"), ("Bottom of the rope. Welcome to Quivermoor. The ground is breathing. Do not hold your breath with it.", "Unten am Seil. Willkommen in Quivermoor. Der Boden atmet. Halt nicht mit ihm die Luft an."),
                 ("North: the Breathing Bog to Tallowmere. South: the Wandering Wood to Rootchapel.", "Norden: das Atmende Moor nach Tallowmere. Süden: der Wandernde Wald nach Rootchapel.")],
        "keeper": ("Moss Nurse Hedda: Lie down. The moss is soft and warm. That is how it gets you, but not tonight.", "Moospflegerin Hedda: Leg dich hin. Das Moos ist weich und warm. So kriegt es einen, aber nicht heute Nacht."),
        "shop": ("Peddler Osric Fane: Tonics, rope, candles. The candles are cheap. Having one lit for you costs more.", "Hausierer Osric Fane: Tränke, Seil, Kerzen. Die Kerzen sind billig. Eine für dich anzünden zu lassen kostet mehr."),
        "folk": [("wilmot", "villager", ("Bog Cutter Wilmot: I cut peat for the fires. Last week the peat had a ring in it. Still on the finger.", "Torfstecher Wilmot: Ich steche Torf für die Feuer. Letzte Woche war ein Ring im Torf. Noch am Finger.")),
                 ("prue", "villager", ("Moss Girl Prue: The gate has no wall because the moss ate it. It's still hungry. I feed it gossip.", "Moosmädchen Prue: Das Tor hat keine Mauer, weil das Moos sie gefressen hat. Es hat noch Hunger. Ich füttere es mit Klatsch.")),
                 ("old_cobb", "elder", ("Old Cobb: I came down that rope forty years ago. I'm still waiting for my change.", "Der alte Cobb: Ich bin vor vierzig Jahren an dem Seil heruntergekommen. Ich warte immer noch auf mein Wechselgeld."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "revival_leaf"), ((0, 16), "strong_tonic", 2)],
    },
    "tallowmere": {
        "sign": [("TALLOWMERE", "TALLOWMERE"), ("Seat of the Tallow Choir. A candle for every soul the moor takes. Prices on request.", "Sitz des Talgchors. Eine Kerze für jede Seele, die das Moor nimmt. Preise auf Anfrage."),
                 ("West: the Breathing Bog. East: Candle Causeway. North: the Wick Rift. The Choir Loft: the waxed door.", "Westen: das Atmende Moor. Osten: der Kerzendamm. Norden: der Dochtriss. Die Chorempore: die gewachste Tür.")],
        "keeper": ("Chandler Nurse Ysolde: Rest by the wax. It keeps you warm, and it keeps count.", "Kerzenpflegerin Ysolde: Ruh dich am Wachs aus. Es hält dich warm, und es zählt mit."),
        "shop": ("Choir Clerk Tibb: Tonics and tapers. A taper with your name on it is half price if you buy it before you need it.", "Chorschreiber Tibb: Tränke und Kerzen. Eine Kerze mit deinem Namen kostet die Hälfte, wenn du sie kaufst, bevor du sie brauchst."),
        "folk": [("aldous", "villager", ("Wick Trimmer Aldous: I trim the wicks so the candles last. The Choir docks my pay for every one that lasts too long.", "Dochtschneider Aldous: Ich schneide die Dochte, damit die Kerzen halten. Der Chor zieht mir für jede ab, die zu lange hält.")),
                 ("marisol", "villager", ("Chorister Marisol: We sing one verse per candle. Some nights we are hoarse by supper.", "Chorsängerin Marisol: Wir singen eine Strophe pro Kerze. An manchen Abenden sind wir zum Essen heiser.")),
                 ("grandam_ivy", "elder", ("Grandam Ivy: My candle has been burning for sixty years. Maudrey keeps asking when I'm going to be polite and finish.", "Großmutter Ivy: Meine Kerze brennt seit sechzig Jahren. Maudrey fragt ständig, wann ich so höflich bin und fertig werde."))],
        "finds": [((0, 5), "revival_leaf"), ((11, 14), "max_tonic"), ((0, 16), "focus_brew")],
    },
    "rootchapel": {
        "sign": [("ROOTCHAPEL", "ROOTCHAPEL"), ("A chapel the roots grew around. Services daily. The roots attend every one.", "Eine Kapelle, um die die Wurzeln gewachsen sind. Täglich Gottesdienst. Die Wurzeln sind bei jedem dabei."),
                 ("North: the Wandering Wood. East: Hymnmarsh. South: Gloamwater. West: the Chapel Rift.", "Norden: der Wandernde Wald. Osten: der Hymnensumpf. Süden: das Dämmerwasser. Westen: der Kapellenriss.")],
        "keeper": ("Sexton Aubrey: Sleep in the pews. If a root curls round your ankle, do not kick. It only wants to know you.", "Küster Aubrey: Schlaf in den Bänken. Wenn sich eine Wurzel um deinen Knöchel legt, tritt nicht. Sie will dich nur kennenlernen."),
        "shop": None,
        "folk": [("thane", "villager", ("Gravedigger Thane: Nobody gets buried here any more. The roots come up and fetch them first.", "Totengräber Thane: Hier wird keiner mehr begraben. Die Wurzeln kommen hoch und holen sie vorher.")),
                 ("bess", "villager", ("Altar Girl Bess: Ossian says the moor must be fed. He never says who's on the menu, only that it's not him.", "Altarmädchen Bess: Ossian sagt, das Moor muss gefüttert werden. Er sagt nie, wer auf der Karte steht, nur, dass er es nicht ist.")),
                 ("father_lorne", "elder", ("Father Lorne: I preached against the roots for thirty years. Now I water them. A man learns which side the pews are on.", "Pater Lorne: Dreißig Jahre habe ich gegen die Wurzeln gepredigt. Jetzt gieße ich sie. Man lernt, auf welcher Seite die Bänke stehen."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "spark_drop"), ((0, 16), "remedy", 2)],
    },
    "driftwick": {
        "sign": [("DRIFTWICK", "DRIFTWICK"), ("A town on rafts. Where it stands tomorrow depends on the bog and on who paid Corran.", "Eine Stadt auf Flößen. Wo sie morgen liegt, hängt vom Moor ab und davon, wer Corran bezahlt hat."),
                 ("North: Candle Causeway. West: Hymnmarsh. East: the Heaving Fields. South: the Raft Rift. The Raft Market: the tarred door.", "Norden: der Kerzendamm. Westen: der Hymnensumpf. Osten: die Wogenden Felder. Süden: der Floßriss. Der Floßmarkt: die geteerte Tür.")],
        "keeper": ("Raft Nurse Odile: Sleep on deck. If you wake up somewhere new, that's normal. If you wake up in the water, that's Corran.", "Floßpflegerin Odile: Schlaf an Deck. Wenn du woanders aufwachst, ist das normal. Wenn du im Wasser aufwachst, war das Corran."),
        "shop": ("Ropewright Jory: Tonics, tar and rope. Buy rope. Everyone here ends up needing rope or being tied with it.", "Seilmacher Jory: Tränke, Teer und Seil. Kauf Seil. Jeder hier braucht irgendwann Seil oder wird damit gefesselt."),
        "folk": [("kit", "villager", ("Pole Boy Kit: I push the rafts apart at dawn so the neighbours don't fight. Then I sell them each other's addresses.", "Stakjunge Kit: Morgens stoße ich die Flöße auseinander, damit die Nachbarn nicht streiten. Dann verkaufe ich ihnen gegenseitig die Adressen.")),
                 ("rowena", "villager", ("Widow Rowena: My husband sold the morning position to two buyers. Driftwick split in half that night. So did he.", "Witwe Rowena: Mein Mann hat die Morgenposition an zwei Käufer verkauft. Driftwick ist in der Nacht in zwei Hälften gerissen. Er auch.")),
                 ("skipper_hale", "elder", ("Skipper Hale: Sixty years afloat and I've never seen the same sunrise twice. Some of them I've seen from underneath.", "Schiffer Hale: Sechzig Jahre auf dem Wasser, und ich habe nie zweimal denselben Sonnenaufgang gesehen. Manche davon von unten."))],
        "finds": [((0, 5), "strong_tonic", 2), ((11, 14), "remedy"), ((0, 16), "wake_bell")],
    },
    "lastbloom": {
        "sign": [("LASTBLOOM", "LASTBLOOM"), ("Flowers for every occasion. Every occasion is a funeral.", "Blumen für jeden Anlass. Jeder Anlass ist eine Beerdigung."),
                 ("North: the Heaving Fields. South: Gloamwater. East: the Bloom Rift.", "Norden: die Wogenden Felder. Süden: das Dämmerwasser. Osten: der Blütenriss.")],
        "keeper": ("Florist Nurse Sabra: Rest among the blooms. Breathe deep. Don't ask what the scent is made of.", "Floristenpflegerin Sabra: Ruh dich zwischen den Blüten aus. Atme tief. Frag nicht, woraus der Duft gemacht ist."),
        "shop": None,
        "folk": [("linnet", "villager", ("Flower Seller Linnet: Red ones grow where soldiers sank, white ones where children did. The white ones sell better.", "Blumenverkäuferin Linnet: Rote wachsen, wo Soldaten versanken, weiße, wo Kinder versanken. Die weißen verkaufen sich besser.")),
                 ("garth", "villager", ("Gardener Garth: I don't plant anything. I just wait and pick. The moor does the planting.", "Gärtner Garth: Ich pflanze gar nichts. Ich warte nur und pflücke. Das Pflanzen macht das Moor.")),
                 ("mother_wren", "elder", ("Mother Wren: Every spring I look for my son's flower. Every spring I buy one that looks like him.", "Mutter Wren: Jeden Frühling suche ich die Blume meines Sohnes. Jeden Frühling kaufe ich eine, die ihm ähnlich sieht."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "revival_leaf"), ((0, 16), "guard_brew")],
    },
}
SHOP_ITEMS = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew focus_brew"
FOLK_PLACES = [((2, 6, "right"), (5, 9, "right")), ((9, 11, "left"), (7, 9, "left")), ((2, 18, "right"), (4, 7, "right"))]


def town(world, mid):
    t = TOWN_TEXT[mid]
    sheet = sheet_entry("towns", mid)
    rows = town_rows(mid)
    text = {"sign": lines(*t["sign"]),
            "keeper": {"lines": lines(t["keeper"]), "action": "heal"}}
    people = [npc("keeper", 7, 7, "down", mid + "/keeper", "elder")]
    if t["shop"]:
        text["trader"] = {"lines": lines(t["shop"]), "action": SHOP_ITEMS}
        people.append(npc("trader", 3, 14, "down", mid + "/trader", "villager"))
    for (pid, sprite, talk), ((hx, hy, hf), (dx, dy, df)) in zip(t["folk"], FOLK_PLACES):
        text[pid] = {"lines": lines(talk)}
        people.append(npc(pid, hx, hy, hf, "%s/%s" % (mid, pid), sprite, schedule=[at("dusk", dx, dy, df), away("night")]))
    world.add_text(mid, text)
    blocks = []
    for (town_id, side), flag in RIFT_GATES.items():
        if town_id == mid:
            for x, y in exit_cells(side, TOWN_H):
                blocks.append(gate(x, y, flag, "#"))
    m = {"name": tr(sheet["name"], sheet["name"]), "biome": "town", "backdrop": "field", "outdoor": True,
         "heal_point": [6, 9], "rows": rows, "warps": exits(mid, TOWN_H), "npcs": people,
         "signs": [{"x": 9, "y": 5, "dialogue": mid + "/sign"}],
         "secrets": [secret(f[0][0], f[0][1], f[1], "find_%s_%d" % (mid, i + 1), f[2] if len(f) > 2 else 1) for i, f in enumerate(t["finds"])],
         "square": [6, 8]}
    if blocks:
        m["blocks"] = blocks
    EXTRA.get(mid, lambda w, m: None)(world, m)
    finish(world, mid, m)


def chapter(cid):
    return [c for c in SHEET["story"] if c["id"] == cid][0]


def de(en):
    return (en, DE[en])


def mossgate_extra(world, m):
    mid = "mossgate"
    c1, c2, c3, c4 = chapter("v5_ch1"), chapter("v5_ch2"), chapter("v5_ch3"), chapter("v5_ch4")
    world.add_text(mid, {
        "ashby": {"lines": lines(de(c1["text"]),
                                 ("Reeve Ashby: Four Rifts, four Wardens, one candle a day as wages. Sign the book. Everyone who comes down the rope signs the book.", "Vogt Ashby: Vier Risse, vier Wächter, eine Kerze am Tag als Lohn. Trag dich ins Buch ein. Jeder, der am Seil herunterkommt, trägt sich ins Buch ein.")),
                  "action": "set_flag v5_ch1_done",
                  "after_flag": [
                      {"flag": "v5_ch1_done", "lines": lines(("Reeve Ashby: Tallowmere first, up through the bog. The Wick Rift is behind the Choir. Mind the candles, one of them is yours.", "Vogt Ashby: Zuerst Tallowmere, durchs Moor hinauf. Der Dochtriss liegt hinter dem Chor. Pass auf die Kerzen auf, eine davon gehört dir."),
                                                             de(c1["betrayal"]["text"]))},
                      {"flag": "rift_v5_wick_sealed", "lines": lines(de(c2["betrayal"]["text"]),
                                                                     ("Reeve Ashby: A book on how long you would last? Business. You're doing well in it. Rootchapel next, Nell will pole you there.", "Vogt Ashby: Ein Buch darauf, wie lange du durchhältst? Geschäft. Du machst dich gut darin. Als Nächstes Rootchapel, Nell stakt dich hin."))},
                      {"flag": "rift_v5_chapel_sealed", "lines": lines(de(c3["betrayal"]["text"]),
                                                                       ("Reeve Ashby: Nell? Shocking. Driftwick next. I'll come along. I have money riding on the trip.", "Vogt Ashby: Nell? Schockierend. Als Nächstes Driftwick. Ich komme mit. Ich habe Geld auf die Fahrt gesetzt."))},
                      {"flag": "rift_v5_raft_sealed", "lines": lines(de(c4["betrayal"]["text"]),
                                                                     ("Reeve Ashby: You're still alive. That cost me a fortune. Go to Lastbloom and lose there, I'm owed.", "Vogt Ashby: Du lebst noch. Das hat mich ein Vermögen gekostet. Geh nach Lastbloom und verlier dort, man schuldet mir was."))}]},
        "winch": {"lines": lines(("Winch Hand Gorm: The rope goes up to Whitecairn. Up costs double. Gravity is on my side going down, not going up.", "Windenknecht Gorm: Das Seil führt hinauf nach Whitecairn. Hinauf kostet das Doppelte. Hinunter ist die Schwerkraft auf meiner Seite, hinauf nicht.")),
                  "action": "transit quivermoor_rope"},
        "rope_sign": lines(("THE ROPE", "DAS SEIL"), ("Baskets to Whitecairn. Mended weekly. Paid for occasionally.", "Körbe nach Whitecairn. Wöchentlich geflickt. Gelegentlich bezahlt.")),
    })
    m["npcs"] += [npc("ashby", 4, 13, "right", mid + "/ashby", "elder"),
                  npc("winch", 8, 17, "down", mid + "/winch", "villager")]
    m["rows"][1] = "^TS..__..TT^"
    m["signs"].append({"x": 2, "y": 1, "dialogue": mid + "/rope_sign"})


def tallowmere_extra(world, m):
    m["warps"].append(warp(9, 13, "choir_loft", 5, 8, "up"))


def driftwick_extra(world, m):
    m["warps"].append(warp(9, 13, "raft_market", 1, 10, "right"))


def lastbloom_extra(world, m):
    mid = "lastbloom"
    c5 = chapter("v5_ch5")
    world.add_text(mid, {
        "nell": {"lines": lines(de(c5["text"]),
                                ("Nell Tallis: The bloom's over. The moor's asleep. Here's your lamp back. Don't look at what's left in the book, it's all crossed out.", "Nell Tallis: Die Blüte ist vorbei. Das Moor schläft. Hier ist deine Lampe zurück. Schau nicht, was noch im Buch steht, es ist alles durchgestrichen."),
                                de(c5["betrayal"]["text"])),
                 "action": "set_flag " + SHEET["finale_flag"]},
    })
    m["npcs"].append(npc("nell", 8, 14, "left", mid + "/nell", "tamer_f", show_flag="rift_v5_bloom_sealed"))


EXTRA = {"mossgate": mossgate_extra, "tallowmere": tallowmere_extra, "driftwick": driftwick_extra,
         "lastbloom": lastbloom_extra}


# --- Routes --------------------------------------------------------------------------------
ROUTE_ROWS = {
    # Bog pools that rise and fall, reed beds and moss between them.
    "breathing_bog": ["^^^^^__^^^^^",
                      "^%%..__..%%^",
                      "^%%..__..%%^",
                      "^~~~....~~~^",
                      "^~~%%..%%~~^",
                      "^,,%%..%%,,^",
                      "^,,......,,^",
                      "^~~~..~~~~~^",
                      "^%%%..%%%..^",
                      "^%%%..%%%..^",
                      "^.....S....^",
                      "^~~~~~..~~~^",
                      "^,,....,,,.^",
                      "^,,....,,,.^",
                      "^%%~~..~~%%^",
                      "^%%~~..~~%%^",
                      "^..........^",
                      "^~~..~~~~~~^",
                      "^%%..%%%%..^",
                      "^%%..%%%%..^",
                      "^.......L..^",
                      "^,,...__.,,^",
                      "^.....__...^",
                      "^^^^^__^^^^^"],
    # Oaks that walk a step a night, moss and root rubble between them.
    "wandering_wood": ["^^^^^__^^^^^",
                       "^TT..__..TT^",
                       "^,,..__..,,^",
                       "^,,T....T,,^",
                       "^TTT.,,.TTT^",
                       "^::..,,..::^",
                       "^::......::^",
                       "^TTTT..TTTT^",
                       "_.....,,,,.^",
                       "^,,..,,,,..^",
                       "^TT.S....TT^",
                       "^TT..TTTTTT^",
                       "^::..,,,,::^",
                       "^::..,,,,::^",
                       "^TTTTTT..TT^",
                       "^,,,....,,,^",
                       "^,,,.T..,,,^",
                       "^TT.....TTT^",
                       "^::..TT..::^",
                       "^::..TT..::^",
                       "^.........T^",
                       "^,,...__.,,^",
                       "^.....__...^",
                       "^^^^^__^^^^^"],
    # A stone causeway over the bog, a candle post every few steps.
    "candle_causeway": ["^^^^^__^^^^^",
                        "^%%..__..%%^",
                        "^~~%.__.%~~^",
                        "^~~~L__L~~~^",
                        "^~~%:__:%~~^",
                        "^~%%:..:%%~^",
                        "^~~~L..L~~~^",
                        "^%%::..::%%^",
                        "^%%::..::%%^",
                        "^~~~L..L~~~^",
                        "^~~%...S%~~^",
                        "^~~~L..L~~~^",
                        "^::%%..%%::^",
                        "^::%%..%%::^",
                        "^~~~L..L~~~^",
                        "^~~~:..:~~~^",
                        "^%%%:..:%%%^",
                        "^~~~L..L~~~^",
                        "^~~%%..%%~~^",
                        "^~~%%..%%..^",
                        "^.........L^",
                        "^.....__.%%^",
                        "^.....__...^",
                        "^^^^^__^^^^^"],
    # A sunken marsh that hums; the stones of an old chapel stick out of it.
    "hymnmarsh": ["^^^^^__^^^^^",
                  "^%%..__..,,^",
                  "^%%%.__.,,,^",
                  "^~~%....,~~^",
                  "^~~%%..,,~~^",
                  "^,,%%..,,%%^",
                  "^,,.....%%%^",
                  "^~~~~..~~~~^",
                  "^%%%%..,,,,^",
                  "^%%%...S,,,^",
                  "^~~......~~^",
                  "^~~~~..~~~~^",
                  "^,,,,..%%%%^",
                  "^,,,....%%%^",
                  "^~~~...~~~~^",
                  "^@@%%..%%@@^",
                  "^@.%%..%%.@^",
                  "^~~~~..~~~~^",
                  "^,,,....%%.^",
                  "^,,,....%%.^",
                  "^~~......L.^",
                  "^.....__.%%^",
                  "^.....__...^",
                  "^^^^^__^^^^^"],
    # Moss fields that heave like a chest; hummocks rise and sink between the reeds.
    "heaving_fields": ["^^^^^__^^^^^",
                       "^,,..__..,,^",
                       "^,,,.__.,,,^",
                       "^@@,....,@@^",
                       "^,,,,..,,,,^",
                       "^,,@....@,,^",
                       "^.........,^",
                       "^@@@@..@@@@^",
                       "^%%,,..,,%%^",
                       "^%%,,..S,%%^",
                       "^.........,^",
                       "^@@@..@@@@@^",
                       "^,,,..,,,,,^",
                       "^,,,..,,@,,^",
                       "^@@@@..@@@@^",
                       "^%%,....,%%^",
                       "^%%,....,%%^",
                       "^@@,..,,@@@^",
                       "^,,,..,,,,,^",
                       "^,,@..@,,,.^",
                       "^.......L..^",
                       "^,,...__.,,^",
                       "^.....__...^",
                       "^^^^^__^^^^^"],
    # Black water at dusk, the reeds lean in to listen.
    "gloamwater": ["^^^^^__^^^^^",
                   "^~~..__..~~^",
                   "^~%%.__.%%~^",
                   "^~%%....%%~^",
                   "^~~~,..,~~~^",
                   "^,,,,..,,,,^",
                   "^,,........^",
                   "^~~~~..~~~~^",
                   "^%%%%..%%%%^",
                   "^%%%...S%%%^",
                   "^~~......~~^",
                   "^~~~,..,~~~^",
                   "^,,,,..,,,,^",
                   "^,,......,,^",
                   "^~~~~..~~~~^",
                   "^%%%....%%%^",
                   "^%%%....%%%^",
                   "^~~~,..,~~~^",
                   "^,,,,..,,,.^",
                   "^,,,....,,.^",
                   "^~~.......L^",
                   "^.....__.%%^",
                   "^.....__...^",
                   "^^^^^__^^^^^"],
}
ROUTE_SIGNS = {
    "breathing_bog": [((6, 10), ("THE BREATHING BOG", "DAS ATMENDE MOOR"), ("Step when it breathes out. When it breathes in, it takes whatever is standing on it.", "Tritt auf, wenn es ausatmet. Wenn es einatmet, nimmt es alles, was darauf steht."))],
    "wandering_wood": [((4, 10), ("WANDERING WOOD", "WANDERNDER WALD"), ("This sign was at the other end of the wood yesterday. So was the wood.", "Dieses Schild stand gestern am anderen Ende des Waldes. Der Wald auch."))],
    "candle_causeway": [((7, 10), ("CANDLE CAUSEWAY", "KERZENDAMM"), ("Every post holds a candle for someone who walked off the edge. Keep to the light. The light is not keen on company.", "Jeder Pfahl trägt eine Kerze für jemanden, der von der Kante gegangen ist. Bleib im Licht. Das Licht mag keine Gesellschaft."))],
    "hymnmarsh": [((7, 9), ("HYMNMARSH", "HYMNENSUMPF"), ("The old chapel sank here with the choir inside. On still nights they are still on the second verse.", "Hier ist die alte Kapelle mit dem Chor darin versunken. In stillen Nächten sind sie immer noch bei der zweiten Strophe."))],
    "heaving_fields": [((7, 9), ("THE HEAVING FIELDS", "DIE WOGENDEN FELDER"), ("The fields rise and fall like a sleeper's chest. Do not wake it. Do not ask what it dreams.", "Die Felder heben und senken sich wie die Brust eines Schläfers. Weck es nicht. Frag nicht, was es träumt."))],
    "gloamwater": [((7, 9), ("GLOAMWATER", "DÄMMERWASSER"), ("No bottom has been found. Three surveyors went looking. The water kept their notes.", "Einen Grund hat man nie gefunden. Drei Vermesser haben gesucht. Das Wasser hat ihre Notizen behalten."))],
}
ROUTE_FINDS = {
    "breathing_bog": [((0, 6), "max_tonic"), ((11, 9), "revival_leaf"), ((11, 16), "strong_tonic", 2)],
    "wandering_wood": [((11, 6), "remedy"), ((0, 13), "max_tonic"), ((0, 20), "dash_brew")],
    "candle_causeway": [((0, 7), "revival_leaf"), ((11, 13), "max_tonic"), ((11, 19), "wake_bell")],
    "hymnmarsh": [((0, 6), "spark_drop"), ((11, 13), "max_tonic"), ((11, 19), "revival_leaf")],
    "heaving_fields": [((0, 6), "power_brew"), ((11, 12), "max_tonic"), ((11, 19), "strong_tonic", 2)],
    "gloamwater": [((0, 5), "revival_leaf"), ((11, 13), "max_tonic"), ((11, 19), "guard_brew")],
}
ROUTE_FOLK = {
    "breathing_bog": [("peat_cutter", 6, 13, "left", ("Peat Cutter Brannagh", "Torfstecherin Brannagh"), [("Peatlet", 90), ("Gloomgill", 90), ("Bogwick", 91)],
                       ("Brannagh: The bog breathes out, I cut. It breathes in, I run. Lost two brothers learning the rhythm.", "Brannagh: Das Moor atmet aus, ich steche. Es atmet ein, ich renne. Zwei Brüder habe ich beim Lernen des Takts verloren."),
                       ("Brannagh: You're standing on my cut. Off, or under.", "Brannagh: Du stehst auf meinem Stich. Runter, oder drunter."),
                       ("Brannagh: Fine. Keep breathing. It's catching.", "Brannagh: Schön. Atme weiter. Das ist ansteckend."))],
    "wandering_wood": [("oak_guide", 6, 15, "left", ("Oak Guide Fenwick", "Eichenführer Fenwick"), [("Morelit", 91), ("Rushkit", 91), ("Rookit", 92)],
                        ("Fenwick: I sell maps of the wood. Fresh every morning. Yesterday's will walk you into a pond.", "Fenwick: Ich verkaufe Karten vom Wald. Jeden Morgen frisch. Die von gestern führen dich in einen Teich."),
                        ("Fenwick: No map? Then you're lost. Lost people fight. That's the rule here.", "Fenwick: Keine Karte? Dann bist du verirrt. Verirrte kämpfen. So ist das hier."),
                        ("Fenwick: Take a map. On the house. It's from last week.", "Fenwick: Nimm eine Karte. Geht aufs Haus. Sie ist von letzter Woche."))],
    "candle_causeway": [("lamplighter", 6, 13, "left", ("Post Keeper Agnes", "Pfahlwärterin Agnes"), [("Velvit", 92), ("Puddock", 92), ("Glimmoth", 93)],
                         ("Agnes: I light the posts at dusk. One of them is new every week. I don't ask. The Choir sends the name.", "Agnes: Bei Dämmerung zünde ich die Pfähle an. Jede Woche ist einer neu. Ich frage nicht. Der Chor schickt den Namen."),
                         ("Agnes: There's a fresh post at the end with no name yet. Let's see if it's yours.", "Agnes: Am Ende steht ein frischer Pfahl, noch ohne Namen. Mal sehen, ob es deiner ist."),
                         ("Agnes: Not yours. Not today. I'll keep it dry.", "Agnes: Nicht deiner. Nicht heute. Ich halte ihn trocken."))],
    "hymnmarsh": [("drowned_cantor", 6, 13, "left", ("Cantor Wystan", "Kantor Wystan"), [("Woadlet", 93), ("Drizzlet", 93), ("Padlet", 94)],
                   ("Wystan: My choir sank with the chapel. I stayed up here to conduct. They're flat on the high notes, but they never stop.", "Wystan: Mein Chor ist mit der Kapelle versunken. Ich bin oben geblieben, um zu dirigieren. In den hohen Tönen sind sie zu tief, aber sie hören nie auf."),
                   ("Wystan: You're off the beat. Let me correct you.", "Wystan: Du bist aus dem Takt. Lass mich das korrigieren."),
                   ("Wystan: Better. You can join them when you're ready.", "Wystan: Besser. Du kannst dich ihnen anschließen, wenn du so weit bist."))],
    "heaving_fields": [("hummock_herd", 6, 15, "left", ("Hummock Herder Isolde", "Hügelhirtin Isolde"), [("Silthop", 94), ("Nimbub", 94), ("Rushprowl", 95)],
                        ("Isolde: The hummocks wander off at night. I herd them back. One of them used to be my husband's barn.", "Isolde: Die Hügel wandern nachts davon. Ich treibe sie zurück. Einer davon war mal die Scheune meines Mannes."),
                        ("Isolde: You've been walking on a hummock that's mine. Pay or fight.", "Isolde: Du bist auf einem Hügel gelaufen, der mir gehört. Zahl oder kämpf."),
                        ("Isolde: Paid in bruises. I'll take it.", "Isolde: In blauen Flecken bezahlt. Ich nehme es."))],
    "gloamwater": [("surveyor", 6, 16, "left", ("Surveyor Mordaunt", "Vermesser Mordaunt"), [("Sablet", 94), ("Diplit", 94), ("Dusktern", 95)],
                    ("Mordaunt: Fourth surveyor sent to find the bottom. The first three left me their rope. It was short.", "Mordaunt: Der vierte Vermesser, der den Grund finden soll. Die ersten drei haben mir ihr Seil hinterlassen. Es war zu kurz."),
                    ("Mordaunt: You look heavy enough to sound the depth. Hold still.", "Mordaunt: Du siehst schwer genug aus, um die Tiefe zu loten. Halt still."),
                    ("Mordaunt: Fine. I'll write 'deep' and go home.", "Mordaunt: Schön. Ich schreibe 'tief' und gehe nach Hause."))],
}
ROUTE_LOOK = {"breathing_bog": "lake", "wandering_wood": "field", "candle_causeway": "lake",
              "hymnmarsh": "lake", "heaving_fields": "field", "gloamwater": "lake"}
LANDMARK_DOORS = {"wandering_wood": [warp(0, 8, "walking_oaks", 1, 8, "right")]}


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
    money = 4200 + 200 * ROUTES.index(mid)
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
    "wick_rift": {"motto": ("Under the Choir the wax runs down into the dark. Something down there is counting the drips.", "Unter dem Chor läuft das Wachs hinab ins Dunkel. Etwas dort unten zählt die Tropfen."),
                  "acolyte": ("taper_clerk", ("Taper Clerk Odette", "Kerzenschreiberin Odette"), [("Sootharrow", 92), ("Glazeldrake", 92)],
                              ("Odette: Maudrey keeps the ledger of candles. I keep the ledger of Maudrey. Mine is shorter and much more interesting.", "Odette: Maudrey führt das Kerzenbuch. Ich führe das Maudrey-Buch. Meins ist kürzer und viel spannender."),
                              ("Odette: Your candle is on page nine. Let's see if we can turn the page.", "Odette: Deine Kerze steht auf Seite neun. Mal sehen, ob wir umblättern können."),
                              ("Odette: Still lit. I'll note it in pencil.", "Odette: Brennt noch. Ich notiere es mit Bleistift.")),
                  "mended": ("Maudrey: The wax has stopped running. The Choir will have to sing for real now, not for the dead. They'll hate it.", "Maudrey: Das Wachs läuft nicht mehr. Der Chor muss jetzt wirklich singen, nicht für die Toten. Das wird ihm nicht gefallen."),
                  "after": ("Maudrey: Your candle? Ashby bought its burn time. Ask him how long he thinks you've got. He's betting.", "Maudrey: Deine Kerze? Ashby hat ihre Brenndauer gekauft. Frag ihn, wie lange du seiner Meinung nach noch hast. Er wettet.")},
    "chapel_rift": {"motto": ("Under the chapel the roots drink from a Rift. Ossian calls it communion.", "Unter der Kapelle trinken die Wurzeln aus einem Riss. Ossian nennt es Abendmahl."),
                    "acolyte": ("root_deacon", ("Root Deacon Hollis", "Wurzeldiakon Hollis"), [("Peatmonarch", 93), ("Fenwarden", 93)],
                                ("Hollis: The roots eat on Tuesdays. Today is Tuesday. I checked twice.", "Hollis: Die Wurzeln essen dienstags. Heute ist Dienstag. Ich habe zweimal nachgesehen."),
                                ("Hollis: Kneel. It's easier for the roots if you're already low.", "Hollis: Knie nieder. Den Wurzeln fällt es leichter, wenn du schon unten bist."),
                                ("Hollis: The roots will wait. They always wait.", "Hollis: Die Wurzeln warten. Sie warten immer.")),
                    "mended": ("Ossian: The roots have let go of the altar. They'll grow hungry. I'll grow thin. You've ruined a good sermon.", "Ossian: Die Wurzeln haben den Altar losgelassen. Sie werden hungrig. Ich werde dünn. Du hast eine gute Predigt ruiniert."),
                    "after": ("Ossian: Nell brought you here. I paid her in candles. She said it wasn't personal. Nothing on the moor is personal. It's just dinner.", "Ossian: Nell hat dich hergebracht. Ich habe sie in Kerzen bezahlt. Sie sagte, es sei nicht persönlich. Nichts im Moor ist persönlich. Es ist nur Abendessen.")},
    "raft_rift": {"motto": ("Under Driftwick the bog spins slowly. The rafts follow it. So does everything that falls off them.", "Unter Driftwick dreht sich das Moor langsam. Die Flöße folgen ihm. Und alles, was von ihnen fällt, auch."),
                  "acolyte": ("position_broker", ("Position Broker Lucan", "Lagemakler Lucan"), [("Gloomgillith", 94), ("Dipmonarch", 94)],
                              ("Lucan: I sell tomorrow's position of every raft. Corran sells me tomorrow's position of the town. Everyone profits except the people on it.", "Lucan: Ich verkaufe die morgige Lage jedes Floßes. Corran verkauft mir die morgige Lage der Stadt. Alle verdienen, außer denen, die drauf wohnen."),
                              ("Lucan: Your position tomorrow: horizontal. Let me show you.", "Lucan: Deine Lage morgen: waagerecht. Ich zeig's dir."),
                              ("Lucan: I'll adjust the forecast.", "Lucan: Ich passe die Vorhersage an.")),
                  "mended": ("Corran: The bog has stopped spinning. Driftwick will stay put. Do you know what a town that stays put is worth? Nothing.", "Corran: Das Moor dreht sich nicht mehr. Driftwick bleibt, wo es ist. Weißt du, was eine Stadt wert ist, die bleibt, wo sie ist? Nichts."),
                  "after": ("Corran: Ashby cut your anchor and bet against you. I took the other side of the bet. You're welcome.", "Corran: Ashby hat deinen Anker gekappt und gegen dich gewettet. Ich habe dagegengehalten. Gern geschehen.")},
    "bloom_rift": {"motto": ("Under Lastbloom the moor flowers into a Rift. Every petal is a name the bog remembers.", "Unter Lastbloom blüht das Moor in einen Riss hinein. Jedes Blütenblatt ist ein Name, an den sich das Moor erinnert."),
                   "acolyte": ("petal_keeper", ("Petal Keeper Rosamund", "Blütenhüterin Rosamund"), [("Sablarch", 95), ("Fumeregent", 95)],
                               ("Rosamund: Sabeline has Ashby's book. Every page is a bet on someone's death. Half the bets are on her.", "Rosamund: Sabeline hat Ashbys Buch. Jede Seite ist eine Wette auf jemandes Tod. Die Hälfte der Wetten läuft auf sie."),
                               ("Rosamund: Your petal is still closed. Let's open it.", "Rosamund: Deine Blüte ist noch geschlossen. Öffnen wir sie."),
                               ("Rosamund: Still closed. Stubborn bud.", "Rosamund: Immer noch geschlossen. Störrische Knospe.")),
                   "mended": ("Sabeline: The bloom is closing. The book is yours. Burn it or bet with it, both are traditions here.", "Sabeline: Die Blüte schließt sich. Das Buch gehört dir. Verbrenn es oder wette damit, beides ist hier Tradition."),
                   "after": ("Sabeline: Nell is waiting in town with a lamp. Walk beside her, not behind her.", "Sabeline: Nell wartet in der Stadt mit einer Lampe. Geh neben ihr, nicht hinter ihr.")},
}
RIFT_LOOK = {"wick_rift": "ember", "chapel_rift": "voice", "raft_rift": "lake", "bloom_rift": "field"}


def rift(world, mid):
    sheet = sheet_entry("rifts", mid)
    w = sheet_entry("wardens", sheet["warden"])
    key = mid[:-5]
    t = RIFT_TEXT[mid]
    world.add_text(mid, {
        "spring": {"lines": lines(("Black water wells up through the peat. It is warm, like something breathed into it.", "Schwarzes Wasser quillt durch den Torf. Es ist warm, als hätte etwas hineingeatmet."),
                                  ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")),
                   "action": "heal"},
        "sign": lines((sheet["name"].upper(), DE[sheet["name"]].upper()), t["motto"]),
    })
    pid, (title_en, title_de), crew, talk, intro, defeat = t["acolyte"]
    acolyte = wayfarer(world, mid, pid, 7, 17, "left", tr(title_en, title_de), team(*crew), [talk], [intro], [defeat], int(w["money"]) // 2, sprite="warden")
    wid = w["id"]
    world.add_text(mid, {
        wid: {"lines": lines(de(w["intro"])), "after_flag": [{"flag": sheet["flag"], "lines": lines(t["mended"], t["after"])}]},
        wid + "_intro": lines(de(w["intro"])),
        wid + "_defeat": lines(de(w["defeat"])),
    })
    crew = [{"species": e.get("species") or e["stand_in"], "level": e["level"]} for e in w["team"]]
    warden = npc("warden_" + wid, 5, 2, "down", "%s/%s" % (mid, wid), "warden", trainer=tr(w["name"], w["name"]),
                 warden="v5_" + key, team=crew, intro="%s/%s_intro" % (mid, wid), defeat="%s/%s_defeat" % (mid, wid),
                 ai=2, money=int(w["money"]))
    m = {"name": tr(sheet["name"], DE[sheet["name"]]), "biome": "rift", "backdrop": RIFT_LOOK[mid],
         "heal_point": [3, 5], "rows": base_rows("."), "warps": exits(mid, RIFT_H),
         "npcs": [acolyte, warden],
         "signs": [{"x": 3, "y": 4, "dialogue": mid + "/spring"}, {"x": 8, "y": 5, "dialogue": mid + "/sign"}],
         "blocks": [gate(10, 18, sheet["flag"])]}
    finish(world, mid, m)


# --- Landmarks -----------------------------------------------------------------------------
def landmark_texts(lid):
    lm = sheet_entry("landmarks", lid)
    return lm, lines((lm["name"].upper(), DE[lm["name"]].upper()), de(lm["text"]))


def choir_loft(world):
    """Inside Tallowmere: the wall of ten thousand candles and the vat at the bottom."""
    mid = "choir_loft"
    lm, plaque = landmark_texts(mid)
    rows = ["WWWWWWWWWWWW",
            "WLLLLLLLLLLW",
            "WffffffffffW",
            "WfLffSffLffW",
            "WffffffffffW",
            "WfSLffffLSfW",
            "WffffffffffW",
            "WfLffffffLfW",
            "WffffffffffW",
            "WWWWWDWWWWWW"]
    world.add_text(mid, {
        "plaque": plaque,
        "vat": lines(("The wax vat. A ladle hangs on its rim, and a price list: by the pound, by the name, by the family.", "Der Wachsbottich. An seinem Rand hängt eine Kelle und eine Preisliste: nach Pfund, nach Name, nach Familie.")),
        "your_candle": lines(("A fresh candle near the door, lit. The tag says your name. The tag below it says: odds 3 to 1.", "Eine frische Kerze bei der Tür, angezündet. Auf dem Schild steht dein Name. Auf dem Schild darunter steht: Quote 3 zu 1.")),
        "precentor": lines(("Precentor Anselma: We sing one verse per flame. Ten thousand flames. We are never done and we are never paid.", "Vorsängerin Anselma: Wir singen eine Strophe pro Flamme. Zehntausend Flammen. Wir werden nie fertig und nie bezahlt."),
                           ("Anselma: Maudrey says the Choir is a calling. The Choir says Maudrey is a landlord.", "Anselma: Maudrey sagt, der Chor sei eine Berufung. Der Chor sagt, Maudrey sei eine Vermieterin.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "voice", "rows": rows,
         "warps": [warp(5, 9, "tallowmere", 9, 14, "down")],
         "npcs": [npc("precentor", 6, 6, "down", mid + "/precentor", "elder")],
         "signs": [{"x": 5, "y": 3, "dialogue": mid + "/plaque"}, {"x": 2, "y": 5, "dialogue": mid + "/vat"},
                   {"x": 9, "y": 5, "dialogue": mid + "/your_candle"}]}
    finish(world, mid, m)


def walking_oaks(world):
    """Beside the Wandering Wood: the clearing where the old oaks stand when they rest."""
    mid = "walking_oaks"
    lm, plaque = landmark_texts(mid)
    rows = ["^^^^^^^^^^^^",
            "^T..T..T..T^",
            "^...TS.T...^",
            "^..........^",
            "^.TT....TT.^",
            "^.,,....,,.^",
            "^..........^",
            "^.S......T.^",
            "_..........^",
            "^....TT....^",
            "^T........T^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "plaque": plaque,
        "tracks": lines(("Deep furrows in the moss, a stride apart. They lead to a stump with boots still standing beside it.", "Tiefe Furchen im Moos, einen Schritt voneinander entfernt. Sie führen zu einem Stumpf, neben dem noch Stiefel stehen.")),
        "guide": lines(("Guide Tamsin: The oaks walk one step a night. Never stand in front of one at dusk. Never stand behind one at dawn.", "Führerin Tamsin: Die Eichen gehen jede Nacht einen Schritt. Steh in der Dämmerung nie vor einer. Steh im Morgengrauen nie hinter einer."),
                       ("Tamsin: My last client wanted to see one move. He did. Briefly.", "Tamsin: Mein letzter Kunde wollte eine gehen sehen. Hat er. Kurz.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "field", "outdoor": True, "rows": rows,
         "warps": [warp(0, 8, "wandering_wood", 1, 8, "right")],
         "npcs": [npc("guide", 6, 3, "down", mid + "/guide", "villager")],
         "signs": [{"x": 5, "y": 2, "dialogue": mid + "/plaque"}, {"x": 2, "y": 7, "dialogue": mid + "/tracks"}],
         "secrets": [secret(11, 3, "max_tonic", "find_walking_oaks_1"), secret(0, 6, "focus_brew", "find_walking_oaks_2"),
                     secret(6, 11, "revival_leaf", "find_walking_oaks_3")]}
    finish(world, mid, m)


def raft_market(world):
    """Through the tarred door of Driftwick: stalls lashed together on rafts over the bog."""
    mid = "raft_market"
    lm, plaque = landmark_texts(mid)
    rows = ["^^^^^^^^^^^^",
            "^++++~~++++^",
            "^+..+~~+..+^",
            "^+S.+~~+.S+^",
            "^++++++++++^",
            "^~~~~++~~~~^",
            "^++++++++++^",
            "^+..+~~+..+^",
            "^++++++++++^",
            "^~~~~++~~~~^",
            "_+++++++++.^",
            "^^^^^^^^^^^^"]
    world.add_text(mid, {
        "plaque": plaque,
        "scales": lines(("A stall with a set of scales and no seller. The sign says: honesty box. The box is nailed down and empty.", "Ein Stand mit einer Waage und ohne Verkäufer. Auf dem Schild steht: Vertrauenskasse. Die Kasse ist festgenagelt und leer.")),
        "hawker": lines(("Hawker Cleo: Buy now! In an hour my raft is in Lastbloom and you'll never find me again. That's not a threat, it's a guarantee.", "Händlerin Cleo: Jetzt kaufen! In einer Stunde ist mein Floß in Lastbloom, und du findest mich nie wieder. Das ist keine Drohung, das ist eine Garantie."),
                        ("Cleo: Returns? Sure. Find me first.", "Cleo: Umtausch? Klar. Find mich erst.")),
    })
    m = {"name": tr(lm["name"], DE[lm["name"]]), "biome": "town", "backdrop": "lake", "outdoor": True, "rows": rows,
         "warps": [warp(0, 10, "driftwick", 9, 14, "down")],
         "npcs": [npc("hawker", 6, 6, "down", mid + "/hawker", "villager")],
         "signs": [{"x": 2, "y": 3, "dialogue": mid + "/plaque"}, {"x": 9, "y": 3, "dialogue": mid + "/scales"}],
         "secrets": [secret(11, 2, "max_tonic", "find_raft_market_1"), secret(0, 7, "guard_brew", "find_raft_market_2"),
                     secret(11, 7, "remedy", "find_raft_market_3")]}
    finish(world, mid, m)
