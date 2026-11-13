#!/usr/bin/env python3
"""Vellmarch, the post-game Era II region, built from its sheet data/region2.json: five towns,
six roads and the four Rifts with their Wardens. Region "vellmarch" (drawn in Era II).

Run on its own: python3 tools/art/world/vellmarch.py
It writes data/maps/<id>.json for the 15 maps, data/dialogue/vellmarch.json, the German table
tools/i18n/de_vellmarch.py, and patches (idempotent) data/encounters.json, data/world_layout.json
and data/story_npcs.json (the bargeman on the Brindlewick quay). Names, rings, encounter slots
and Warden teams come from the sheet, so edit region2.json and run this again; Vellmarch's own
Spirlings replace the stand-ins in the same way once a slot gets a species.

How the way opens:
  brindlewick <-> cindergate_quay   the Night Barge (line vellmarch_night_barge), after story_complete
  hookwick -> lock_rift             v2_ch1_done (Wren Marlow on the quay)
  tallowmarket -> foundry_rift      v2_rift_lock_sealed
  larkspur_heights -> masque_rift   v2_rift_foundry_sealed
  lastlamp -> vault_rift            v2_rift_masque_sealed
Beating a Warden seals its Rift (GameState.seal_rift with "warden": lock / foundry / masque /
vault) and sets the sheet's flag and chapter flag; the last one sets vellmarch_done, which opens
the Warden rematches (WardenRematch.region_entries()).
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from common import _ordered, check_rows, npc, secret, warp  # noqa: E402
from townsfolk import at, away  # noqa: E402

REGION = "vellmarch"
DIA = "vellmarch"
SHEET = json.load(open(os.path.join(ROOT, "data", "region2.json")))
SHEET_DE = {}
exec(open(os.path.join(ROOT, "tools", "i18n", "de_region2.py"), encoding="utf-8").read(), SHEET_DE)
GERMAN = {}
TEXT = {}
MAPS = {}
INTERIORS = {}


def tr(en, de):
    """A new text with its German; texts from the sheet are already in de_region2.py."""
    if en in SHEET_DE["T"] or en in SHEET_DE["KEEP"]:
        if en in SHEET_DE["T"] and SHEET_DE["T"][en] != de:
            raise SystemExit("German for %r differs from de_region2.py" % en)
        return en
    if GERMAN.get(en, de) != de:
        raise SystemExit("two German texts for %r" % en)
    GERMAN[en] = de
    return en


def sheet(en):
    """A text straight from the sheet (must already have German)."""
    if en not in SHEET_DE["T"] and en not in SHEET_DE["KEEP"]:
        raise SystemExit("sheet text without German: %r" % en)
    return en


def lines(*pairs):
    return [tr(en, de) for en, de in pairs]


def text(key, entry):
    TEXT[key] = entry
    return "%s/%s" % (DIA, key)


def by_id(kind):
    return {e["id"]: e for e in SHEET[kind]}


TOWNS = by_id("towns")
ROUTES = by_id("routes")
RIFTS = by_id("rifts")
WARDENS = {w["rift"]: w for w in SHEET["wardens"]}
CHAPTER = {c.get("rift", ""): c for c in SHEET["story"]}
# The road between the quay and Tallowmarket, by its links so a rename on the sheet carries over.
QUAY_ROAD = next(r for r, e in ROUTES.items() if set(e["links"]) == {"cindergate_quay", "tallowmarket"})
GROUND = {"fern": (",", "fern"), "reed": ("%", "reeds"), "scree": (":", "scree")}

# --- How the places join: every town side is a two-cell gate --------------------------------
# side: (gate cells, arrival cells, facing on arrival)
SIDES = {"left": ([(0, 8), (0, 9)], [(1, 8), (1, 9)], "right"),
         "right": ([(11, 8), (11, 9)], [(10, 8), (10, 9)], "left"),
         "top": ([(5, 0), (6, 0)], [(5, 1), (6, 1)], "down"),
         "bottom": ([(5, 19), (6, 19)], [(5, 18), (6, 18)], "up")}
# town -> {side: (place, open flag or None)}
GATES = {
    "cindergate_quay": {"right": (QUAY_ROAD, None), "bottom": ("bellrope_marsh", None)},
    "tallowmarket": {"left": (QUAY_ROAD, None), "top": ("rookery_cut", None), "right": ("smelters_drift", None),
                     "bottom": ("foundry_rift", "v2_rift_lock_sealed")},
    "hookwick": {"bottom": ("rookery_cut", None), "right": ("weeping_locks", None), "left": ("lock_rift", "v2_ch1_done")},
    "larkspur_heights": {"left": ("weeping_locks", None), "bottom": ("smelters_drift", None), "right": ("tithe_road", None),
                         "top": ("masque_rift", "v2_rift_foundry_sealed")},
    "lastlamp": {"top": ("tithe_road", None), "left": ("bellrope_marsh", None), "right": ("vault_rift", "v2_rift_masque_sealed")},
}
LAYOUT_POS = {"hookwick": [2, 0], "lock_rift": [1, 0], "masque_rift": [4, 0], "vault_rift": [5, 5], "foundry_rift": [2, 4]}
ROUTE_H = 26
RIFT_H = 22


def side_of(town, place):
    for s, (p, _) in GATES[town].items():
        if p == place:
            return s
    raise SystemExit("%s has no gate to %s" % (town, place))


def town_arrival(town, place):
    _, cells, facing = SIDES[side_of(town, place)]
    return cells, facing


# --- Towns: every town has its own layout and its own landmark ---------------------------------
# rows: the map (gates on the fixed SIDES cells, a closed side is frame). doors: the four house
# doors in the order of HOUSES. folk: (home cell, facing, dusk cell by the square, facing).
# "@" under "landmark" carries the town's landmark (data/landmarks.json, vellmarch set).
TOWN_LAYOUT = {
    # A harbour: the west half is water, the Night Barge ties up at the long pier.
    "cindergate_quay": {
        "rows": ["TTTTTTTTTTTT",
                 "T~~~~..RRR.T",
                 "T~~~~..HDH.T",
                 "T~~+++____.T",
                 "T~~~~._....T",
                 "T~~~~@_.RR.T",
                 "T+++++_.HD.T",
                 "T~~~~.__._.T",
                 "T~~~~.o_____",
                 "T~~~~.._____",
                 "T~~~..__...T",
                 "T.RRR._....T",
                 "T.HDH._RRR.T",
                 "T.._.._HDH.T",
                 "T..____._..T",
                 "T.S.._____.T",
                 "T....__....T",
                 "T.#..__.#*.T",
                 "T....__...LT",
                 "TTTTT__TTTTT"],
        "doors": [(8, 2), (9, 6), (3, 12), (8, 13)], "keeper": (5, 8), "trader": (2, 14), "sign": (2, 15),
        "heal": (6, 9), "square": (6, 8), "landmark": (5, 5),
        "folk": [((10, 2), "left", (5, 9), "right"), ((2, 16), "right", (7, 9), "left"), ((9, 16), "left", (7, 7), "left")],
        "finds": [(0, 13), (11, 16), (11, 4)]},
    # A market: one paved square with stalls, the houses in its four corners.
    "tallowmarket": {
        "rows": ["TTTTT__TTTTT",
                 "T.RR.__.RR.T",
                 "T.HD.__.DH.T",
                 "T.._.__._..T",
                 "T..______..T",
                 "T.________.T",
                 "T.__#__#__.T",
                 "T.________.T",
                 "_____o@_____",
                 "____________",
                 "T.________.T",
                 "T.__#__#__.T",
                 "T.________.T",
                 "T..______..T",
                 "T.RR.__.RR.T",
                 "T.HD.__.DH.T",
                 "T.._.__._..T",
                 "T..______..T",
                 "T*.S.__...LT",
                 "TTTTT__TTTTT"],
        "doors": [(3, 2), (8, 2), (3, 15), (8, 15)], "keeper": (5, 7), "trader": (7, 7), "sign": (3, 18),
        "heal": (5, 9), "square": (5, 8), "landmark": (6, 8),
        "folk": [((1, 3), "right", (4, 7), "right"), ((10, 13), "left", (4, 9), "right"), ((1, 17), "right", (6, 9), "left")],
        "finds": [(0, 13), (11, 16), (11, 4)]},
    # A canal town: the canal cuts it in two, a road bridge and a footbridge cross it.
    "hookwick": {
        "rows": ["TTTTTTTTTTTT",
                 "T.RRR...RR.T",
                 "T.HDH...HD.T",
                 "T.._....._.T",
                 "T.._..L.._.T",
                 "T.._______.T",
                 "T....__..S.T",
                 "T...o__....T",
                 "____________",
                 "____________",
                 "T*...__@._.T",
                 "T~~~~++~~+~T",
                 "T~~~~++~~+~T",
                 "T....__.._.T",
                 "T...._____.T",
                 "T.RR.__.RR.T",
                 "T.DH.__.DH.T",
                 "T._..__._..T",
                 "T.________.T",
                 "TTTTT__TTTTT"],
        "doors": [(3, 2), (9, 2), (2, 16), (8, 16)], "keeper": (3, 7), "trader": (7, 7), "sign": (9, 6),
        "heal": (4, 8), "square": (4, 7), "landmark": (7, 10),
        "folk": [((1, 4), "right", (4, 6), "down"), ((10, 6), "left", (5, 8), "left"), ((7, 13), "left", (3, 8), "right")],
        "finds": [(0, 13), (11, 16), (11, 4)]},
    # Terraces: two mansions on the top step, the square in the middle, a formal garden below.
    "larkspur_heights": {
        "rows": ["TTTTT__TTTTT",
                 "T.RRR__RRR.T",
                 "T.RRR__RRR.T",
                 "T.HDH__HDH.T",
                 "T*._.__._.*T",
                 "T..______..T",
                 "T^^^^==^^^^T",
                 "T.L..__..S.T",
                 "____________",
                 "____________",
                 "T.__.o..__.T",
                 "T^==^^^^==^T",
                 "T.__....__.T",
                 "T.__*@*.__.T",
                 "T.________.T",
                 "T.RR.__.RR.T",
                 "T.DH.__.HD.T",
                 "T._..__.._.T",
                 "T.________.T",
                 "TTTTT__TTTTT"],
        "doors": [(3, 3), (8, 3), (2, 16), (9, 16)], "keeper": (4, 10), "trader": (7, 7), "sign": (9, 7),
        "heal": (5, 9), "square": (5, 10), "landmark": (5, 13),
        "folk": [((1, 5), "right", (7, 10), "left"), ((10, 12), "left", (4, 9), "down"), ((4, 17), "right", (6, 9), "down")],
        "finds": [(0, 13), (11, 16), (11, 4)]},
    # One lamp-lit street that winds down to the marsh; the last lamp stands out in the water.
    "lastlamp": {
        "rows": ["TTTTT__TTTTT",
                 "T.RR.__..L.T",
                 "T.HD.__....T",
                 "T..____....T",
                 "T.L.__..RR.T",
                 "T...__..HD.T",
                 "T...______.T",
                 "T....o__.L.T",
                 "____________",
                 "____________",
                 "T.L..__..L.T",
                 "T....__....T",
                 "T.RR.__.~~~T",
                 "T.DH.__~~@~T",
                 "T______++.~T",
                 "T_RRR.~~~~~T",
                 "T_HDH..+++~T",
                 "T___.S.*~~~T",
                 "T....*.~~~~T",
                 "TTTTTTTTTTTT"],
        "doors": [(3, 2), (9, 5), (2, 13), (3, 16)], "keeper": (4, 7), "trader": (7, 11), "sign": (5, 17),
        "heal": (5, 8), "square": (5, 7), "landmark": (9, 13),
        "folk": [((1, 5), "right", (5, 6), "down"), ((8, 11), "left", (6, 8), "left"), ((4, 18), "right", (4, 8), "right")],
        "finds": [(0, 12), (11, 11), (11, 4)]},
}
BARGE_QUAY = (3, 6)
BARGE_BRINDLEWICK = (7, 18)
WREN = (7, 4)
SHOP = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew pith_mend pith_clear pruning_shears grounding_rod smelling_salts"
# The port town also sells the charms of the region's own elements (#478).
CHARMS = {"cindergate_quay": " rust_charm mask_charm"}
FINDS = ["max_tonic", "revival_leaf", "strong_tonic", "remedy", "wake_bell"]

TOWN_TEXT = {
    "cindergate_quay": {
        "motto": ("Cindergate Quay. Tolls payable on arrival, departure and complaint.", "Cindergate Quay. Zoll fällig bei Ankunft, Abfahrt und Beschwerde."),
        "keeper": ("Dock Nurse Ottilie: Sit. Your Spirlings look seasick. I charge the House, not you. For now.", "Docksanitäterin Ottilie: Setz dich. Deine Spirlings sehen seekrank aus. Ich rechne mit dem Haus ab, nicht mit dir. Noch."),
        "trader": ("Chandler Brisk: Rope, tonics, alibis. Two of those are on the shelf.", "Krämer Brisk: Seile, Tränke, Alibis. Zwei davon stehen im Regal."),
        "folk": [("Docker Haldis: I load crates for the House by day. At night I unload them for the Syndicate. Same crates.", "Schauerfrau Haldis: Tagsüber lade ich Kisten fürs Haus. Nachts lade ich sie fürs Syndikat wieder aus. Dieselben Kisten."),
                 ("Tollman Rusk: Looking at the toll booth is a copper. Asking about it is two.", "Zöllner Rusk: Das Zollhäuschen anschauen kostet einen Kupfer. Danach fragen zwei."),
                 ("Net Widow Oona: My husband fell in the harbour. The House sent flowers. The Syndicate sent the bill for the flowers.", "Netzwitwe Oona: Mein Mann ist ins Hafenbecken gefallen. Das Haus hat Blumen geschickt. Das Syndikat die Rechnung für die Blumen.")]},
    "tallowmarket": {
        "motto": ("Tallowmarket. Candles by day. Do not ask what is sold by night.", "Tallowmarket. Kerzen am Tag. Frag nicht, was nachts verkauft wird."),
        "keeper": ("Chandler Mags: Rest by the wax vats. Warm, quiet, and only slightly flammable.", "Kerzenzieherin Mags: Ruh dich an den Wachsbottichen aus. Warm, still und nur ein bisschen entflammbar."),
        "trader": ("Rumour Broker Fenn: Tonics on the left, gossip on the right. The gossip costs more and works better.", "Gerüchtehändler Fenn: Tränke links, Klatsch rechts. Der Klatsch kostet mehr und wirkt besser."),
        "folk": [("Wick Boy Tam: I sell candles to the vigil for the foundry workers. Same customers every year. Fewer each time.", "Dochtjunge Tam: Ich verkaufe Kerzen für die Totenwache der Gießereiarbeiter. Jedes Jahr dieselben Kunden. Jedes Mal weniger."),
                 ("Weigher Odo: Rumours are sold by weight. Yours is light. Nobody's lied about you yet.", "Wäger Odo: Gerüchte werden nach Gewicht verkauft. Deins ist leicht. Über dich hat noch keiner gelogen."),
                 ("Syndicate Runner Pell: I don't work for the Syndicate. Write that down. Then burn it.", "Syndikatsläufer Pell: Ich arbeite nicht fürs Syndikat. Schreib das auf. Dann verbrenn es.")]},
    "hookwick": {
        "motto": ("Hookwick. Every boat has two owners. Ask either; both are lying.", "Hookwick. Jedes Boot hat zwei Besitzer. Frag einen von beiden; beide lügen."),
        "keeper": ("Harbour Aunt Bel: Sit down before you fall in. Everyone falls in eventually. Some get pushed.", "Hafentante Bel: Setz dich, bevor du reinfällst. Irgendwann fällt jeder rein. Manche werden geschubst."),
        "folk": [("Lockkeeper's Boy Wim: Odile pays me to say she's out. She's always out. Even when she's in.", "Schleusenjunge Wim: Odile bezahlt mich, damit ich sage, sie ist nicht da. Sie ist nie da. Auch wenn sie da ist."),
                 ("Eel Seller Grete: The canal water rose to my door. The eels came in to look at the rent.", "Aalverkäuferin Grete: Das Kanalwasser stand bis an meine Tür. Die Aale kamen rein, um sich die Miete anzusehen."),
                 ("Boatwright Jory: I build every boat twice. Once for the man who pays, once for the man who steals it.", "Bootsbauer Jory: Ich baue jedes Boot zweimal. Einmal für den, der zahlt, einmal für den, der es klaut.")]},
    "larkspur_heights": {
        "motto": ("Larkspur Heights. Clean streets. High walls. Short memories.", "Larkspur Heights. Saubere Straßen. Hohe Mauern. Kurzes Gedächtnis."),
        "keeper": ("House Physician Aurel: Rest here. Discretion is included in the price. The price is also discreet.", "Hausarzt Aurel: Ruh dich hier aus. Diskretion ist im Preis enthalten. Der Preis ist ebenfalls diskret."),
        "trader": ("Glove Merchant Ysette: Our tonics are imported. So is our conscience. Neither has arrived.", "Handschuhhändlerin Ysette: Unsere Tränke sind importiert. Unser Gewissen auch. Beides ist noch nicht angekommen."),
        "folk": [("Opera Usher Lenz: Tonight's opera ends with a duel. Last week's ended with a funeral. Same tenor.", "Opernplatzanweiser Lenz: Die Oper heute endet mit einem Duell. Die letzte Woche mit einer Beerdigung. Derselbe Tenor."),
                 ("Maid Ilka: I polish the masks for the ball. Some of them are still warm.", "Zofe Ilka: Ich poliere die Masken für den Ball. Manche sind noch warm."),
                 ("Retired Duelist Corvo: I lost one eye in an honest duel. The other in a dishonest one. Guess which taught me more.", "Duellant a. D. Corvo: Ein Auge verlor ich in einem ehrlichen Duell. Das andere in einem unehrlichen. Rate, welches mich mehr gelehrt hat.")]},
    "lastlamp": {
        "motto": ("Lastlamp. The last lit street before the marsh. Keep to the light.", "Lastlamp. Die letzte beleuchtete Straße vor dem Moor. Bleib im Licht."),
        "keeper": ("Lamplighter Nan: Sit under the lamp. Out there, nobody comes back to sit anywhere.", "Laternenanzünderin Nan: Setz dich unter die Lampe. Da draußen kommt keiner zurück, um sich irgendwo hinzusetzen."),
        "folk": [("Bell Ringer Ash: I ring the marsh bell when someone goes missing. My arms are very strong.", "Glöckner Ash: Ich läute die Moorglocke, wenn jemand verschwindet. Meine Arme sind sehr kräftig."),
                 ("Pawnbroker Wex: Corin's men pawn their medals here. I sell them back to Corin. Everyone wins but the medals.", "Pfandleiher Wex: Corins Leute versetzen hier ihre Orden. Ich verkaufe sie Corin zurück. Alle gewinnen außer den Orden."),
                 ("Gravekeeper Ivo: The marsh keeps the bodies. I just keep the names. Fewer complaints.", "Totengräber Ivo: Das Moor behält die Leichen. Ich behalte nur die Namen. Weniger Beschwerden.")]},
}
# Every town house has a door and a small room (tools/maps/audit_maps.py: no outdoor building
# without a door). door cell in the town -> (room id suffix, room name, resident, line).
HOUSE_DOORS = [(3, 3), (9, 3), (2, 13), (8, 13)]
HOUSE_ROWS = ["WWWWWWWW",
              "WCCffCCW",
              "WffffffW",
              "WffffffW",
              "WffffffW",
              "WWWDWWWW"]
HOUSES = {
    "cindergate_quay": [
        ("tollhouse", ("Cindergate Tollhouse", "Zollhaus von Cindergate"), "clerk",
         ("Toll Clerk Mabry: Entry is a copper. Leaving is two. Staying is a matter for the House.", "Zollschreiber Mabry: Rein kostet einen Kupfer. Raus zwei. Bleiben ist Sache des Hauses.")),
        ("net_loft", ("Net Loft", "Netzboden"), "mender",
         ("Net Mender Saffi: I mend the nets the Syndicate cuts. They pay me to mend them, too.", "Netzflickerin Saffi: Ich flicke die Netze, die das Syndikat zerschneidet. Fürs Flicken zahlt es mich auch.")),
        ("bunkhouse", ("Dockers' Bunkhouse", "Schauerleute-Schlafhaus"), "docker",
         ("Docker Bram: Six bunks, nine dockers. Nobody asks where the other three sleep.", "Schauermann Bram: Sechs Kojen, neun Schauerleute. Keiner fragt, wo die anderen drei schlafen.")),
        ("customs_store", ("Customs Store", "Zolllager"), "keeper",
         ("Storeman Tibb: Seized goods. Some were seized twice. Once by us, once from us.", "Lagerverwalter Tibb: Beschlagnahmte Ware. Manches zweimal. Einmal von uns, einmal bei uns.")),
    ],
    "tallowmarket": [
        ("wax_hall", ("Wax Hall", "Wachshalle"), "chandler",
         ("Chandler Ruth: Every candle here burns for someone. Pick a short one. They're cheaper.", "Kerzenmacherin Ruth: Jede Kerze hier brennt für jemanden. Nimm eine kurze. Die sind billiger.")),
        ("weigh_house", ("Weigh House", "Waaghaus"), "weigher",
         ("Weigher Ansel: The scales are honest. The weights are a family heirloom. Different family.", "Wäger Ansel: Die Waage ist ehrlich. Die Gewichte sind ein Erbstück. Von einer anderen Familie.")),
        ("rumour_room", ("Rumour Room", "Gerüchtestube"), "broker",
         ("Whisperer Nell: I heard you were coming. I sold that before you arrived.", "Flüsterin Nell: Ich hab gehört, dass du kommst. Das hab ich verkauft, bevor du da warst.")),
        ("vigil_house", ("Vigil House", "Wachhaus der Kerzen"), "widow",
         ("Vigil Keeper Dorn: One candle for each foundry worker. We ran out of shelves last winter.", "Totenwächter Dorn: Eine Kerze für jeden Gießereiarbeiter. Letzten Winter gingen uns die Regale aus.")),
    ],
    "hookwick": [
        ("boatshed", ("Boatshed", "Bootsschuppen"), "boatwright",
         ("Shipwright Kaja: This hull has two names painted on it. Both owners swear it's theirs.", "Bootsbauerin Kaja: Auf diesem Rumpf stehen zwei Namen. Beide Besitzer schwören, er gehört ihnen.")),
        ("eel_smokery", ("Eel Smokery", "Aalräucherei"), "smoker",
         ("Smoker Hennig: The eels don't mind the smoke. They stopped minding anything a while ago.", "Räucherer Hennig: Den Aalen macht der Rauch nichts. Ihnen macht schon länger nichts mehr was aus.")),
        ("lock_office", ("Lock Office", "Schleusenamt"), "clerk",
         ("Lock Clerk Pim: Odile is out. She is always out. Leave a bribe after the tone.", "Schleusenschreiber Pim: Odile ist nicht da. Sie ist nie da. Hinterlass nach dem Ton ein Bestechungsgeld.")),
        ("tackle_shop", ("Tackle Room", "Angelstube"), "angler",
         ("Old Angler Fritha: I caught a boot today. It still had a foot in it. Not a good foot.", "Alte Anglerin Fritha: Heute hab ich einen Stiefel gefangen. Da war noch ein Fuß drin. Kein guter Fuß.")),
    ],
    "larkspur_heights": [
        ("mask_atelier", ("Mask Atelier", "Maskenatelier"), "maskmaker",
         ("Maskmaker Orla: Each mask fits one face. I keep a list of whose.", "Maskenmacherin Orla: Jede Maske passt auf ein Gesicht. Ich führe Buch, auf wessen.")),
        ("counting_house", ("Counting House", "Kontor"), "banker",
         ("Banker Quillon: Your money is perfectly safe with us. Your name is another matter.", "Bankier Quillon: Dein Geld ist bei uns vollkommen sicher. Dein Name ist eine andere Sache.")),
        ("servants_hall", ("Servants' Hall", "Gesindestube"), "maid",
         ("Footman Erich: We hear everything upstairs. We are paid to forget it. We are paid badly.", "Diener Erich: Wir hören alles von oben. Wir werden fürs Vergessen bezahlt. Schlecht bezahlt.")),
        ("salon", ("Quiet Salon", "Stiller Salon"), "noble",
         ("Lady Vespera: Duels are so vulgar. I have mine fought for me.", "Dame Vespera: Duelle sind so gewöhnlich. Ich lasse meine für mich ausfechten.")),
    ],
    "lastlamp": [
        ("lamp_store", ("Lamp Store", "Lampenlager"), "lamplighter",
         ("Wick Keeper Sten: We have oil for one more year. After that, the marsh gets the street.", "Dochtwart Sten: Öl für ein Jahr haben wir noch. Danach holt sich das Moor die Straße.")),
        ("pawnshop", ("Pawnshop", "Pfandhaus"), "pawnbroker",
         ("Pawn Clerk Lisbet: Medals, rings, a wooden leg. All pawned, none collected.", "Pfandschreiberin Lisbet: Orden, Ringe, ein Holzbein. Alles versetzt, nichts abgeholt.")),
        ("bell_house", ("Bell House", "Glockenhaus"), "ringer",
         ("Rope Boy Ned: I count the bell rings in a ledger. The ledger is getting heavy.", "Seiljunge Ned: Ich zähle die Glockenschläge in einem Buch. Das Buch wird schwer.")),
        ("name_room", ("Room of Names", "Namensstube"), "keeper",
         ("Scribe Ulla: Names of the lost, one per line. I leave a blank line at the end. Just in case.", "Schreiberin Ulla: Namen der Verschollenen, einer pro Zeile. Am Ende lasse ich eine Zeile frei. Nur für alle Fälle.")),
    ],
}
SPRITE = {"widow": "elder", "keeper": "elder", "noble": "villager"}


def houses(mid, rows):
    """Writes the room behind each town house door; returns the town's warps to the rooms."""
    out = []
    for (dx, dy), (key, name, who, line) in zip(TOWN_LAYOUT[mid]["doors"], HOUSES[mid]):
        if rows[dy][dx] != "D" or rows[dy - 1][dx] not in "RH" or rows[dy + 1][dx] not in "._":
            raise SystemExit("%s: no house door above open ground at %d,%d" % (mid, dx, dy))
        rid = "%s_%s" % (mid, key)
        out.append(warp(dx, dy, rid, 3, 4, "up"))
        room = {"name": tr(*name), "biome": "town", "backdrop": "field", "rows": list(HOUSE_ROWS),
                "warps": [warp(3, 5, mid, dx, dy + 1, "down")],
                "npcs": [npc(who, 4, 2, "down", text(rid + "_" + who, lines(line)), SPRITE.get(who, "villager"))],
                "signs": []}
        add(rid, room)
        INTERIORS[rid] = mid
    return out


def gate_block(x, y, flag):
    return {"x": x, "y": y, "open_flag": flag, "closed": "#"}


def town(mid):
    t = TOWNS[mid]
    lay = TOWN_LAYOUT[mid]
    rows = list(lay["rows"])
    gates = GATES[mid]
    for side, (cells, inside, _) in SIDES.items():
        for x, y in cells:
            if (rows[y][x] == "_") != (side in gates):
                raise SystemExit("%s: side %s does not match its gate" % (mid, side))
        if side in gates and any(rows[y][x] not in "._" for x, y in inside):
            raise SystemExit("%s: no open ground inside the %s gate" % (mid, side))
    if sum(r.count("D") for r in rows) != len(lay["doors"]):
        raise SystemExit("%s: a door that is no house door" % mid)
    lx, ly = lay["landmark"]
    if rows[ly][lx] != "@":
        raise SystemExit("%s: the landmark does not stand on its rock" % mid)
    tt = TOWN_TEXT[mid]
    sign = text(mid + "_sign", lines((t["name"], t["name"]), tt["motto"]))
    kx, ky = lay["keeper"]
    npcs = [npc("keeper", kx, ky, "down", text(mid + "_keeper", {"lines": lines(tt["keeper"]), "action": "heal"}), "elder")]
    if t.get("shop"):
        tx, ty = lay["trader"]
        npcs.append(npc("trader", tx, ty, "down", text(mid + "_trader", {"lines": lines(tt["trader"]), "action": SHOP + CHARMS.get(mid, "")}), "villager"))
    for i, (line, ((hx, hy), hf, (dx, dy), df)) in enumerate(zip(tt["folk"], lay["folk"])):
        npcs.append(npc("folk_%d" % (i + 1), hx, hy, hf, text("%s_folk_%d" % (mid, i + 1), lines(line)),
                        "elder" if i == 2 else "villager", schedule=[at("dusk", dx, dy, df), away("night")]))
    warps = houses(mid, rows)
    blocks = []
    for side, (place, flag) in gates.items():
        cells, _, _ = SIDES[side]
        for i, (x, y) in enumerate(cells):
            (tx, ty), facing = place_arrival(place, mid, i)
            warps.append(warp(x, y, place, tx, ty, facing))
            if flag:
                blocks.append(gate_block(x, y, flag))
    if mid == "cindergate_quay":
        bx, by = BARGE_QUAY
        npcs.append(npc("bargeman", bx - 2, by, "right", barge_text(), "elder"))
        npcs.append(npc("wren", WREN[0], WREN[1], "down", wren_text(), "ranger", color="8a3a5a"))
    for who in npcs:
        if rows[who["y"]][who["x"]] not in "._+" or (who["x"], who["y"] - 1) in lay["doors"]:
            raise SystemExit("%s: %s stands in a wall or in front of a door" % (mid, who["id"]))
    sx, sy = lay["sign"]
    f = lay["finds"]
    m = {"name": t["name"], "biome": "town", "backdrop": "field", "outdoor": True, "heal_point": list(lay["heal"]), "rows": rows,
         "warps": warps, "npcs": npcs, "signs": [{"x": sx, "y": sy, "dialogue": sign}], "blocks": blocks,
         "secrets": [secret(f[0][0], f[0][1], FINDS[0], "find_%s_1" % mid), secret(f[1][0], f[1][1], FINDS[1], "find_%s_2" % mid),
                     secret(f[2][0], f[2][1], FINDS[2], "find_%s_3" % mid, 2)],
         "square": list(lay["square"])}
    add(mid, m)


def barge_text():
    return text("bargeman", {"lines": [sheet(SHEET["arrival"]["text"])], "action": "transit " + SHEET["arrival"]["line"]})


def wren_text():
    ch1 = CHAPTER[""]
    text("wren_after", [sheet(ch1["betrayal"]["text"])])
    return text("wren", {"if": {"not_flag": ch1["sets"]}, "else": "wren_after",
                         "lines": [sheet(ch1["text"])] + lines(("Wren: First job: the Lock Rift past Hookwick, west gate. Odile has the key. Ask nicely, then don't.", "Wren: Erster Auftrag: der Schleusenriss hinter Hookwick, Westtor. Odile hat den Schlüssel. Frag nett, dann nicht mehr.")),
                         "action": "set_flag " + ch1["sets"]})


def place_arrival(place, from_town, i):
    """Arrival cell on [place] when coming from [from_town] through gate cell i, and the facing."""
    if place in ROUTES:
        top = ROUTES[place]["links"][0] == from_town
        return ((5 + i, 1), "down") if top else ((5 + i, ROUTE_H - 2), "up")
    return (5 + i, RIFT_H - 2), "up"


# --- Roads ----------------------------------------------------------------------------------
ROUTE_ROWS = ["TTTTT__TTTTT",
              "T...._..AAAT",
              "TAA.._...AAT",
              "TAA..__....T",
              "T.....__...T",
              "T..CC..__..T",
              "T..CC...__.T",
              "T........_.T",
              "TBBB....__.T",
              "TBBB...__..T",
              "T.....__...T",
              "T....__..AAT",
              "T...__...AAT",
              "T..__.....AT",
              "T.__..CC...T",
              "T._...CC...T",
              "T.__.......T",
              "T..__..BBB.T",
              "T...__.BBB.T",
              "T....__....T",
              "T.....__...T",
              "TAA....__..T",
              "TAA.....__.T",
              "T......__..T",
              "T.....__...T",
              "TTTTT__TTTTT"]
# Fill-ins beside the three slots so the table reaches the weight the validator wants:
# (species, ground slot index) per road, uncommon kinds of the region's elements.
FILL = {QUAY_ROAD: [("Anchorrot", 2), ("Groatfin", 2)], "rookery_cut": [("Hushbeak", 0), ("Waxwhisk", 2)],
        "weeping_locks": [("Snagwhisk", 0), ("Fauxscript", 2)], "smelters_drift": [("Latchet", 0), ("Knellgrim", 2)],
        "tithe_road": [("Shivlet", 0), ("Tithshell", 2)], "bellrope_marsh": [("Moldcap", 2), ("Mirefane", 2)]}
SLOT_WEIGHTS = [9, 7, 5]
FILL_WEIGHTS = [16, 14]
ROUTE_TEXT = {
    QUAY_ROAD: ("tollkeeper", ("Causeway Toll Keeper Vos", "Dammzöllner Vos"), (0, 2),
                        ("Vos: The causeway is free. Crossing it isn't.", "Vos: Der Damm ist frei. Ihn zu überqueren nicht."),
                        ("Vos: Pay the toll in coin or in bruises. I take both.", "Vos: Zahl den Zoll in Münzen oder in blauen Flecken. Ich nehme beides."),
                        ("Vos: Fine. Pass. I'll bill the House for my pride.", "Vos: Schön. Geh durch. Meinen Stolz stelle ich dem Haus in Rechnung.")),
    "rookery_cut": ("crowmonger", ("Crowmonger Sibbe", "Krähenhändlerin Sibbe"), (0, 2),
                    ("Sibbe: My crows carry letters for the Syndicate. They read them first. So do I.", "Sibbe: Meine Krähen tragen Briefe fürs Syndikat. Sie lesen sie zuerst. Ich auch."),
                    ("Sibbe: You've got a letter on you. Let's see who it's addressed to.", "Sibbe: Du hast einen Brief bei dir. Mal sehen, an wen er geht."),
                    ("Sibbe: Return to sender. Sender's dead, but still.", "Sibbe: Zurück an den Absender. Der Absender ist tot, aber trotzdem.")),
    "weeping_locks": ("sluicer", ("Sluice Hand Morwen", "Schleusenhelferin Morwen"), (0, 1),
                      ("Morwen: The locks weep because Odile pays them to. The rest of us weep for free.", "Morwen: Die Schleusen weinen, weil Odile sie dafür bezahlt. Wir anderen weinen umsonst."),
                      ("Morwen: Nobody passes the locks dry. Let's get you wet.", "Morwen: Niemand kommt trocken an den Schleusen vorbei. Machen wir dich nass."),
                      ("Morwen: Soaked and beaten. By you. That's new.", "Morwen: Durchnässt und geschlagen. Von dir. Das ist neu.")),
    "smelters_drift": ("slagman", ("Slag Carter Hobb", "Schlackenkarrer Hobb"), (0, 2),
                       ("Hobb: I cart slag from the foundry. Some of it used to be workers. Don't look in the cart.", "Hobb: Ich karre Schlacke aus der Gießerei. Manches davon waren mal Arbeiter. Schau nicht in den Karren."),
                       ("Hobb: Hot day. Hot temper. Hot Spirlings.", "Hobb: Heißer Tag. Heißes Gemüt. Heiße Spirlings."),
                       ("Hobb: Cooled off. Like everyone at the foundry, eventually.", "Hobb: Abgekühlt. Wie alle in der Gießerei, irgendwann.")),
    "tithe_road": ("tithecollector", ("Tithe Collector Prue", "Zehnteintreiberin Prue"), (0, 1),
                   ("Prue: The House takes a tenth. The Syndicate takes a tenth. I take what's left, for safekeeping.", "Prue: Das Haus nimmt ein Zehntel. Das Syndikat nimmt ein Zehntel. Ich nehme den Rest, zur Verwahrung."),
                   ("Prue: Your tithe is overdue. I accept payment in battle.", "Prue: Dein Zehnt ist überfällig. Ich nehme Zahlung im Kampf an."),
                   ("Prue: Paid in full. I'll forge you a receipt.", "Prue: Vollständig bezahlt. Ich fälsche dir eine Quittung.")),
    "bellrope_marsh": ("bellwalker", ("Bell Walker Edda", "Glockengängerin Edda"), (0, 2),
                       ("Edda: Every bell rope in this marsh leads to someone who rang for help. None of them were answered.", "Edda: Jedes Glockenseil in diesem Moor führt zu jemandem, der um Hilfe geläutet hat. Keiner wurde gehört."),
                       ("Edda: Ring if you need help. I'll pretend I didn't hear.", "Edda: Läute, wenn du Hilfe brauchst. Ich tu so, als hätte ich nichts gehört."),
                       ("Edda: The marsh will have me one day. Not today, it seems.", "Edda: Das Moor holt mich eines Tages. Heute wohl nicht.")),
}


def slot_species(s):
    return s["species"] or s["stand_in"]


def species_elements():
    data = json.load(open(os.path.join(ROOT, "data", "spirlings.json")))
    data = data if isinstance(data, list) else data.get("spirlings", data)
    return {x["name"]: x for x in data}


SPECIES = species_elements()


def check_team(who, crew):
    els = set()
    for e in crew:
        if e["species"] not in SPECIES:
            raise SystemExit("%s: unknown species %s" % (who, e["species"]))
        els.update(SPECIES[e["species"]]["elements"])
    if len(els) > 3:
        raise SystemExit("%s covers %d elements" % (who, len(els)))
    return crew


def route(mid):
    r = ROUTES[mid]
    marsh = mid == "bellrope_marsh"
    rows = list(ROUTE_ROWS)
    if marsh:
        rows[10] = "T~~...__...T"
        rows[19] = "T~~..__..~~T"
    for letter, slot in zip("ABC", r["slots"]):
        rows = [row.replace(letter, GROUND[slot["ground"]][0]) for row in rows]
    lo, hi = r["ring"]
    spawns = []
    for slot, w in zip(r["slots"], SLOT_WEIGHTS):
        if slot["species"]:
            w = slot["weight"]  # an own common kind rolls at the sheet's share (common band 25-45)
        spawns.append({"species": slot_species(slot), "min": lo, "max": hi, "weight": w, "ground": GROUND[slot["ground"]][1]})
    for (sp, gi), w in zip(FILL[mid], FILL_WEIGHTS):
        if sp not in SPECIES or SPECIES[sp].get("rarity") != "uncommon":
            raise SystemExit("%s: fill-in %s must be an uncommon kind" % (mid, sp))
        spawns.append({"species": sp, "min": lo, "max": hi - 1, "weight": w, "ground": GROUND[r["slots"][gi]["ground"]][1]})
    ENCOUNTERS[mid] = {"rate": 0.10 if marsh else 0.12, "spawns": spawns}
    a, b = r["links"]
    warps = []
    for i in range(2):
        (tx, ty), facing = arrival_in_town(a, mid, i)
        warps.append(warp(5 + i, 0, a, tx, ty, facing))
        (tx, ty), facing = arrival_in_town(b, mid, i)
        warps.append(warp(5 + i, ROUTE_H - 1, b, tx, ty, facing))
    key, title, picks, talk, intro, defeat = ROUTE_TEXT[mid]
    crew = check_team(mid, [{"species": slot_species(r["slots"][i]), "level": hi} for i in picks])
    wf = npc(key, 9, 15, "left", text("%s_%s" % (mid, key), lines(talk)), "villager", trainer=tr(*title),
             intro=text("%s_%s_intro" % (mid, key), lines(intro)), defeat=text("%s_%s_defeat" % (mid, key), lines(defeat)),
             money=hi * 40, team=crew)
    m = {"name": r["name"], "biome": "marsh" if marsh else "route", "backdrop": "lake" if marsh else "field", "outdoor": True,
         "encounters": mid, "rows": rows, "warps": warps, "npcs": [wf], "signs": [],
         "secrets": [secret(0, 6, FINDS[3], "find_%s_1" % mid), secret(11, 10, FINDS[4], "find_%s_2" % mid),
                     secret(0, 17, FINDS[0], "find_%s_3" % mid), secret(11, 21, FINDS[2], "find_%s_4" % mid)]}
    add(mid, m)


def arrival_in_town(town_id, place, i):
    cells, facing = town_arrival(town_id, place)
    return cells[i], facing


# --- Rifts ----------------------------------------------------------------------------------
RIFT_ROWS = ["^^^^^^^^^^^^",
             "^^^^.XX.^^^^",
             "^^.........^",
             "^.......|^_^",
             "^..o.....^_^",
             "^.......S^_^",
             "^^^^....^^_^",
             "^^^^....^^_^",
             "^........^_^",
             "^.|......^_^",
             "^........^_^",
             "^........^_^",
             "^^^^..^^^^_^",
             "^........^_^",
             "^........^_^",
             "^^^..^^^^^_^",
             "^........^_^",
             "^........^_^",
             "^^^^..^^^^.^",
             "^..........^",
             "^.|......|.^",
             "^^^^^..^^^^^"]
RULES = {"lock_rift": "undertow", "foundry_rift": "ember_pulse", "masque_rift": "night_dark", "vault_rift": "vine_tangle"}
BACKDROP = {"lock_rift": "lake", "foundry_rift": "ember", "masque_rift": "ridge", "vault_rift": "ridge"}
RIFT_TEXT = {
    "lock_rift": (("Rusted lock gates hold back water that isn't there. Odile keeps the only key.", "Verrostete Schleusentore halten Wasser zurück, das nicht da ist. Odile hat den einzigen Schlüssel."),
                  (("Lock Acolyte Senn", "Schleusen-Akolyth Senn"), ("Senn: Odile sold the lock to the Syndicate. Then sold the Syndicate a second lock. She's very good.", "Senn: Odile hat die Schleuse ans Syndikat verkauft. Dann hat sie dem Syndikat eine zweite Schleuse verkauft. Sie ist sehr gut."),
                   ("Senn: Nobody reaches Odile dry.", "Senn: Niemand erreicht Odile trocken."),
                   ("Senn: Go on. Mind the key. It's already been copied.", "Senn: Geh. Pass auf den Schlüssel auf. Er wurde schon kopiert."))),
    "foundry_rift": (("The cold furnaces of the foundry. Rust grows here like moss, and faster.", "Die kalten Öfen der Gießerei. Rost wächst hier wie Moos, nur schneller."),
                     (("Furnace Acolyte Gert", "Ofen-Akolyth Gert"), ("Gert: Brannoc says the Syndicate rusted the furnace. The Syndicate says Brannoc did. The furnace says nothing.", "Gert: Brannoc sagt, das Syndikat hat den Ofen rosten lassen. Das Syndikat sagt, Brannoc war es. Der Ofen sagt nichts."),
                      ("Gert: You want the foundry? Sweat for it.", "Gert: Du willst die Gießerei? Schwitz dafür."),
                      ("Gert: Hot work. Brannoc's hotter. Good luck.", "Gert: Heiße Arbeit. Brannoc ist heißer. Viel Glück."))),
    "masque_rift": (("Under the opera house the masks are stacked to the ceiling. None of them have eyes.", "Unter dem Opernhaus stapeln sich die Masken bis zur Decke. Keine hat Augen."),
                    (("Masque Acolyte Liesl", "Masken-Akolythin Liesl"), ("Liesl: Sable gave me a mask on my first day. I haven't seen my own face since. I don't miss it.", "Liesl: Sable hat mir am ersten Tag eine Maske gegeben. Mein eigenes Gesicht habe ich seitdem nicht gesehen. Ich vermisse es nicht."),
                     ("Liesl: Masks off. Oh, you don't have one. Then this will hurt more.", "Liesl: Masken ab. Oh, du hast keine. Dann tut das mehr weh."),
                     ("Liesl: Bravo. Sable will want to meet you. She'll want to be you, too.", "Liesl: Bravo. Sable wird dich kennenlernen wollen. Und du sein wollen, auch."))),
    "vault_rift": (("The vault under Lastlamp. The walls are lined with coins that hum like bees.", "Der Tresor unter Lastlamp. Die Wände sind mit Münzen ausgekleidet, die summen wie Bienen."),
                   (("Vault Acolyte Barra", "Tresor-Akolythin Barra"), ("Barra: Corin counts every coin twice. The second time he counts you.", "Barra: Corin zählt jede Münze zweimal. Beim zweiten Mal zählt er dich."),
                    ("Barra: Your purse or your pride. Corin takes both, I just take the first.", "Barra: Deine Börse oder dein Stolz. Corin nimmt beides, ich nehme nur das Erste."),
                    ("Barra: Fine. He's expecting you. He paid for the barge, remember.", "Barra: Schön. Er erwartet dich. Er hat den Kahn bezahlt, schon vergessen?"))),
}


def rift(mid):
    rf = RIFTS[mid]
    w = WARDENS[mid]
    short = mid[:-5]
    town_id = rf["near"]
    rows = list(RIFT_ROWS)
    motto, (aname, talk, intro, defeat) = RIFT_TEXT[mid]
    text(mid + "_spring", {"lines": lines(("Cold water seeps between the stones. It tastes of iron and old debts.", "Kaltes Wasser sickert zwischen den Steinen. Es schmeckt nach Eisen und alten Schulden."),
                                          ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")), "action": "heal"})
    text(mid + "_sign", [sheet(rf["name"]), tr(*motto)])
    crew = [{"species": slot_species(t), "level": t["level"]} for t in w["team"]]
    # Pith Fruit (era function pith_fruit, Era II on): the ace eats a Mending Pith in a pinch
    # (keepsakes count from Veteran on, TrainerData.keeps_keepsakes).
    crew[-1]["held"] = "pith_mend"
    ch = CHAPTER[mid]
    text("warden_" + w["id"], {"lines": [sheet(ch["text"])],
                               "after_flag": [{"flag": rf["flag"], "lines": [sheet(ch["betrayal"]["text"])]}]})
    text("warden_%s_intro" % w["id"], [sheet(w["intro"])])
    text("warden_%s_defeat" % w["id"], [sheet(w["defeat"])])
    warden = npc("warden_" + w["id"], 5, 2, "down", "%s/warden_%s" % (DIA, w["id"]), "warden", trainer=sheet(w["name"]),
                 warden=short, team=crew, intro="%s/warden_%s_intro" % (DIA, w["id"]), defeat="%s/warden_%s_defeat" % (DIA, w["id"]),
                 ai=3, money=w["money"], rule=RULES[mid], mend_items=[w["reward"]["item"]], rematch_after="vellmarch_done",
                 win_flags=[rf["flag"], ch["sets"]])
    acolyte_crew = check_team(mid, [dict(crew[0], level=w["ring"] - 1), dict(crew[1], level=w["ring"] - 1)])
    acolyte = npc("acolyte", 7, 17, "left", text(mid + "_acolyte", lines(talk)), "warden", trainer=tr(*aname),
                  intro=text(mid + "_acolyte_intro", lines(intro)), defeat=text(mid + "_acolyte_defeat", lines(defeat)),
                  money=(w["ring"] - 1) * 40, team=acolyte_crew)
    back, facing = town_arrival(town_id, mid)
    m = {"name": rf["name"], "biome": "rift", "backdrop": BACKDROP[mid], "heal_point": [3, 5], "rows": rows,
         "warps": [warp(5, RIFT_H - 1, town_id, back[0][0], back[0][1], facing), warp(6, RIFT_H - 1, town_id, back[1][0], back[1][1], facing)],
         "npcs": [acolyte, warden],
         "signs": [{"x": 3, "y": 4, "dialogue": "%s/%s_spring" % (DIA, mid)}, {"x": 8, "y": 5, "dialogue": "%s/%s_sign" % (DIA, mid)}],
         "blocks": [{"x": 10, "y": 18, "open_flag": rf["flag"], "closed": "@"}]}
    add(mid, m)


def add(mid, m):
    check_rows(mid, m["rows"])
    m["region"] = REGION
    MAPS[mid] = m


# --- Patches of shared files ----------------------------------------------------------------
ENCOUNTERS = {}


def neighbours(mid):
    out = []
    for w in MAPS[mid]["warps"]:
        if w["to"] not in out and w["to"] not in INTERIORS:
            out.append(w["to"])
    return out


def layout_lines():
    out = []
    for mid in list(TOWNS) + list(ROUTES) + list(RIFTS):
        pos = (TOWNS.get(mid) or ROUTES.get(mid) or {}).get("pos") or LAYOUT_POS[mid]
        if mid in LAYOUT_POS:
            pos = LAYOUT_POS[mid]
        kind = "town" if mid in TOWNS else "rift" if mid in RIFTS else "marsh" if mid == "bellrope_marsh" else "route"
        out.append('  "%s": {"region": "%s", "pos": [%d, %d], "kind": "%s", "neighbours": %s}'
                   % (mid, REGION, pos[0], pos[1], kind, json.dumps(neighbours(mid))))
    for rid, mid in INTERIORS.items():
        out.append('  "%s": {"inside": "%s", "region": "%s"}' % (rid, mid, REGION))
    return out


def patch_layout():
    path = os.path.join(ROOT, "data", "world_layout.json")
    rows = [ln for ln in open(path, encoding="utf-8").read().rstrip("\n").split("\n")
            if '"region": "%s"' % REGION not in ln and '"%s"' % SHEET["arrival"]["line"] not in ln and not ln.startswith('  "vellmarch": {"name"')]

    def end_of(block):
        """Index of the last entry line of the top-level block that starts with [block]."""
        i = rows.index(block)
        j = i + 1
        while rows[j] not in (" },", " }"):
            j += 1
        return j - 1

    def append(block, new):
        j = end_of(block)
        rows[j] = rows[j].rstrip(",") + ","
        for k, ln in enumerate(new):
            rows.insert(j + 1 + k, ln + ("," if k < len(new) - 1 else ""))

    append(' "regions": {', ['  "vellmarch": {"name": "Vellmarch", "origin": [22, 0], "size": [6, 7]}'])
    bx, by = BARGE_BRINDLEWICK
    qx, qy = BARGE_QUAY
    append(' "lines": {', ['  "%s": {"name": "Night Barge", "kind": "ferry", "open_flag": "story_complete", "stops": {"brindlewick": [%d, %d, "down"], "cindergate_quay": [%d, %d, "right"]}}'
                           % (SHEET["arrival"]["line"], bx, by, qx, qy)])
    append(' "maps": {', layout_lines())
    out = "\n".join(rows) + "\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)


def patch_encounters(stale):
    path = os.path.join(ROOT, "data", "encounters.json")
    d = json.load(open(path, encoding="utf-8"))
    for mid in stale:
        d.pop(mid, None)
    d.update(ENCOUNTERS)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
        f.write("\n")


def patch_story_npcs():
    path = os.path.join(ROOT, "data", "story_npcs.json")
    d = json.load(open(path, encoding="utf-8"))
    b = d.setdefault("brindlewick", {}).setdefault("npcs", [])
    b[:] = [n for n in b if n.get("id") != "night_bargeman"]
    b.append({"id": "night_bargeman", "x": 4, "y": 13, "facing": "down", "dialogue": "%s/bargeman_brindlewick" % DIA,
              "sprite": "elder", "show_flag": "story_complete"})
    text("bargeman_brindlewick", {"lines": lines(("Bargeman: Vellmarch? Night barge. No fare. The House already paid for you.", "Kahnführer: Vellmarch? Nachtkahn. Kein Fahrgeld. Das Haus hat schon für dich bezahlt.")),
                                  "action": "transit " + SHEET["arrival"]["line"]})
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
        f.write("\n")


def check_items():
    items = {i["id"]: i for i in json.load(open(os.path.join(ROOT, "data", "items.json")))}
    for it in FINDS + SHOP.split()[1:]:
        if it not in items or items[it].get("premium") or items[it].get("shop_only"):
            raise SystemExit("bad item %s" % it)


def main():
    check_items()
    for mid in TOWNS:
        town(mid)
    for mid in ROUTES:
        route(mid)
    for mid in RIFTS:
        rift(mid)
    patch_story_npcs()
    tr("Night Barge", "Nachtkahn")
    __import__("vellmarch_side").build(sys.modules[__name__])  # twelve side goals, three places under the roads
    # Places renamed or dropped on the sheet: their old map files and tables go.
    stale = []
    for path in glob.glob(os.path.join(ROOT, "data", "maps", "*.json")):
        mid = os.path.splitext(os.path.basename(path))[0]
        if mid not in MAPS and json.load(open(path, encoding="utf-8")).get("region") == REGION:
            stale.append(mid)
            os.remove(path)
    for mid, m in MAPS.items():
        with open(os.path.join(ROOT, "data", "maps", mid + ".json"), "w", encoding="utf-8") as f:
            json.dump(_ordered(m), f, indent=1, ensure_ascii=False)
            f.write("\n")
    with open(os.path.join(ROOT, "data", "dialogue", DIA + ".json"), "w", encoding="utf-8") as f:
        json.dump(dict(sorted(TEXT.items())), f, indent=1, ensure_ascii=False)
        f.write("\n")
    patch_encounters(stale)
    patch_layout()
    with open(os.path.join(ROOT, "tools", "i18n", "de_vellmarch.py"), "w", encoding="utf-8") as f:
        f.write("# German texts for Vellmarch's maps. Written by tools/art/world/vellmarch.py:\n")
        f.write("# edit the tr()/lines() pairs there, not this file.\n")
        f.write("KEEP = []\nT = {\n")
        for en in sorted(GERMAN):
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(GERMAN[en], ensure_ascii=False)))
        f.write("}\n")
    print("wrote %d maps, %d dialogue entries, %d German texts" % (len(MAPS), len(TEXT), len(GERMAN)))


if __name__ == "__main__":
    main()
