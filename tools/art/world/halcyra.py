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
flag the sheet names. Town layout: the crossroads of every town is the same (spring at 6, 8 as
the square, the keeper beside it, three locals there at dusk); the outside differs per town.
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
GROUP = TOWNS + ROUTES + RIFTS + LANDMARKS

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
# The shared crossroads (rows 4 to 11); rows 1-3 and 12-18 are each town's own.
CORE = ["^....__....^",
        "^.L..__..S.^",
        "^....__....^",
        "^...____...^",
        "_____.o.____",
        "_____...____",
        "^...____...^",
        "^....__....^"]

TOWN_TOP = {
    "brightledge": ["^::..__..::^", "^.TTT__TTT.^", "^.***__***.^"],
    "gildcrest": ["^T...__...T^", "^.###__###.^", "^.*T*__*T*.^"],
    "starwell": ["^.L..__..L.^", "^.|..__..|.^", "^.|..__..|.^"],
    "paleshore": ["^::..__..%%^", "^.~~.__.~~.^", "^.~~.__.~~.^"],
    "whitecairn": ["^@@..__..@@^", "^.@@.__.@@.^", "^.@..__..@.^"],
}
TOWN_BOTTOM = {
    "brightledge": ["^.TT.__.TT.^", "^.**.__.**.^", "^....__....^", "^.##.__.##.^", "^....__....^",
                    "^::..__++L.^", "^....__+++.^"],
    "gildcrest": ["^.TT.__.TT.^", "^.**.__.**.^", "^....__....^", "^T##.__.##T^", "^....__....^",
                  "^**..__..L.^", "^....__....^"],
    "starwell": ["^.TT.__.RR.^", "^.**.__.HD.^", "^....__....^", "^.##.__.##.^", "^....__....^",
                 "^::..__..L.^", "^....__....^"],
    "paleshore": ["^.~~.__.~~.^", "^....__....^", "^....__....^", "^~~~.__.~~~^", "^%%..__..%%^",
                  "^::..__..L.^", "^....__....^"],
    "whitecairn": ["^.@@.__.@@.^", "^....__....^", "^....__....^", "^@.@.__.@.@^", "^....__....^",
                   "^@@..__..L.^", "^....__....^"],
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
        # A closed side keeps no road arm running into the cliff (tools/maps/audit_maps.py look pass).
        if "left" not in sides:
            r = r[:1] + "..." + r[4:]
        if "right" not in sides:
            r = r[:8] + "..." + r[11:]
        rows[y] = r
    return rows


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
        "finds": [((0, 5), "revival_leaf"), ((11, 14), "max_tonic"), ((0, 16), "focus_brew")],
    },
    "paleshore": {
        "sign": [("PALESHORE", "PALESHORE"), ("Salt town on a dried lake. Do not walk past the white line. The line moves.", "Salzstadt an einem ausgetrockneten See. Geh nicht über die weiße Linie. Die Linie wandert."),
                 ("West: Mirror Flats. North: the Sunfall Terraces. East: the Lantern Span. South: the Salt Rift.", "Westen: die Spiegelebene. Norden: die Sonnenfall-Terrassen. Osten: der Laternenbogen. Süden: der Salzriss.")],
        "keeper": ("Brine Healer Odo: A salt bath cures everything. Except debt. That needs the other kind of bath.", "Solheiler Odo: Ein Salzbad heilt alles. Außer Schulden. Dafür braucht es die andere Art Bad."),
        "shop": ("Salt Merchant Imke: Tonics, salt and silence. The silence costs the most.", "Salzhändlerin Imke: Tränke, Salz und Schweigen. Das Schweigen kostet am meisten."),
        "folk": [("bertil", "villager", ("Salt Raker Bertil: I rake salt from dawn to dusk. Sometimes the rake finds a boot. Sometimes the boot is still full.", "Salzrechen Bertil: Ich reche Salz von früh bis spät. Manchmal findet der Rechen einen Stiefel. Manchmal ist der Stiefel noch voll.")),
                 ("maren", "villager", ("Widow Maren: My husband walked on the mirror and never came back. Halloran sent a bill for the salt he displaced.", "Witwe Maren: Mein Mann ist auf den Spiegel gelaufen und nie zurückgekommen. Halloran hat eine Rechnung für das verdrängte Salz geschickt.")),
                 ("ivo", "elder", ("Ferryman Ivo: There's been no water to ferry for twenty years. I still charge. Habit.", "Fährmann Ivo: Seit zwanzig Jahren gibt es kein Wasser mehr zum Übersetzen. Ich kassiere trotzdem. Gewohnheit."))],
        "finds": [((0, 5), "strong_tonic", 2), ((11, 13), "remedy"), ((0, 13), "wake_bell")],
    },
    "whitecairn": {
        "sign": [("WHITECAIRN", "WHITECAIRN"), ("The last town before the edge. Each cairn is a person who said no to the Gilt House.", "Die letzte Stadt vor der Kante. Jeder Steinhaufen ist jemand, der Nein zum Haus Gilt gesagt hat."),
                 ("North: Orrery Ridge. South: the Lantern Span. East: the Span Rift.", "Norden: der Planetariumsgrat. Süden: der Laternenbogen. Osten: der Bogenriss.")],
        "keeper": ("Cairn Warden Tamsa: Rest here. The dead don't mind company, as long as it's quiet.", "Steinhüterin Tamsa: Ruh dich hier aus. Die Toten haben nichts gegen Gesellschaft, solange sie leise ist."),
        "shop": None,
        "folk": [("mathis", "villager", ("Stonestacker Mathis: I build the cairns. Business is steady. Too steady.", "Steinstapler Mathis: Ich baue die Steinhaufen. Das Geschäft läuft stetig. Zu stetig.")),
                 ("ilse", "villager", ("Lantern Girl Ilse: I light the Span every night. Veronne says every lantern is a debt. I say every lantern is a name.", "Laternenmädchen Ilse: Ich zünde jeden Abend den Bogen an. Veronne sagt, jede Laterne ist eine Schuld. Ich sage, jede Laterne ist ein Name.")),
                 ("barnaby", "elder", ("Old Barnaby: I said no to the Gilt House once. They built me a cairn anyway. I'm saving it for later.", "Der alte Barnaby: Ich habe einmal Nein zum Haus Gilt gesagt. Sie haben mir trotzdem einen Steinhaufen gebaut. Ich hebe ihn mir für später auf."))],
        "finds": [((0, 5), "max_tonic"), ((11, 14), "revival_leaf"), ((0, 14), "guard_brew")],
    },
}
SHOP_ITEMS = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew focus_brew pith_mend pith_clear"
# Locals: (home x, y, facing) by day, (x, y, facing) at the square at dusk, away at night.
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
    warps = exits(mid, TOWN_H)
    for (town_id, side), flag in RIFT_GATES.items():
        if town_id == mid:
            for x, y in exit_cells(mid, side, TOWN_H):
                blocks.append(gate(x, y, flag, "#"))
    m = {"name": tr(sheet["name"], sheet["name"]), "biome": "town", "backdrop": "field", "outdoor": True,
         "heal_point": [6, 9], "rows": rows, "warps": warps, "npcs": people,
         "signs": [{"x": 9, "y": 5, "dialogue": mid + "/sign"}],
         "secrets": [secret(f[0][0], f[0][1], f[1], "find_%s_%d" % (mid, i + 1), f[2] if len(f) > 2 else 1) for i, f in enumerate(t["finds"])],
         "square": [6, 8]}
    if blocks:
        m["blocks"] = blocks
    EXTRA[mid](world, m)
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
    m["rows"][1] = "^.S..__..::^"
    # The road bends onto the funicular platform instead of running into the cliff.
    m["rows"][17] = "^::..._++L.^"
    m["rows"][18] = "^......+++.^"


def gildcrest_extra(world, m):
    mid = "gildcrest"
    c5 = [c for c in SHEET["story"] if c["id"] == "v4_ch5"][0]
    world.add_text(mid, {
        "host": {"lines": lines((c5["text"], DE[c5["text"]]),
                                ("Steward Corvel: The family thanks you. The family is also, regrettably, poisoned. Please stay for dessert.", "Haushofmeister Corvel: Die Familie dankt dir. Die Familie ist leider auch vergiftet. Bitte bleib zum Nachtisch."),
                                (c5["betrayal"]["text"], DE[c5["betrayal"]["text"]])),
                 "action": "set_flag halcyra_done"},
    })
    m["npcs"].append(npc("host", 8, 14, "left", mid + "/host", "elder", show_flag="rift_v4_gilt_sealed"))


def starwell_extra(world, m):
    # The brass door of the Great Orrery (row 13, x 9) leads inside.
    m["warps"].append(warp(9, 13, "great_orrery", 5, 8, "up"))


def paleshore_extra(world, m):
    # The Dig site (era function dig_site, Era IV, docs/ERA_FUNCTIONS.md).
    world.add_text("paleshore", {"digger": {"lines": lines(
        ("Old Digger Hesper: Under the salt there is more salt. Under that, things people dropped while running. One dig a day, love. The ground sulks.",
         "Alte Gräberin Hesper: Unter dem Salz ist noch mehr Salz. Darunter Dinge, die Leute auf der Flucht verloren haben. Eine Grabung am Tag, Schätzchen. Der Boden schmollt.")),
        "action": "dig"}})
    m["npcs"].append(npc("digger", 2, 10, "right", "paleshore/digger", "elder"))


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
from halcyra_side import hook; GROUP, build = hook(GROUP, build)  # noqa: E402  side goals, places, wild homes (tools/art/world/halcyra_side.py)
