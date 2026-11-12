#!/usr/bin/env python3
"""Quivermoor, the post-game Era V region, built from its sheet data/region5.json: five towns, six
roads over the breathing bog and the four Rifts with their Wardens. Region "quivermoor" (Era V).

Run on its own: python3 tools/art/world/quivermoor.py
It writes data/maps/<id>.json for the 15 places and their 20 house rooms, data/dialogue/quivermoor.json,
the German table tools/i18n/de_quivermoor.py, and patches (idempotent) data/encounters.json,
data/world_layout.json and data/story_npcs.json (the winch man who lowers you in); the side goals
(tools/art/world/quivermoor_side.py) go into data/quests.json. Names, rings,
encounter slots and Warden teams come from the sheet, so edit region5.json and run this again.

Its own look, unlike every other region: boardwalks ("+") over black bog water, reed beds and moss
(the encounter ground), one Rift per town gate. Towns sit on four pier arms around a spring.

How the way opens:
  whitecairn (Halcyra) <-> mossgate  the Rope Basket (line quivermoor_rope), after era4_finale_done;
                                     until Halcyra's maps exist the basket hangs at the Greyreach.
  tallowmere -> wick_rift            v5_ch1_done (Nell Tallis on the Mossgate pier)
  rootchapel -> taproot_rift         rift_v5_wick_sealed
  driftwick  -> raft_rift            rift_v5_taproot_sealed
  lastbloom  -> bloom_rift           rift_v5_raft_sealed
Beating a Warden seals its Rift (GameState.seal_rift with "warden": v5_wick / v5_taproot / v5_raft /
v5_bloom sets rift_v5_<rift>_sealed) and the chapter flag; the last one sets quivermoor_done.
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

REGION = "quivermoor"
DIA = "quivermoor"
SHEET = json.load(open(os.path.join(ROOT, "data", "region5.json")))
SHEET_DE = {}
exec(open(os.path.join(ROOT, "tools", "i18n", "de_region5.py"), encoding="utf-8").read(), SHEET_DE)
GERMAN = {}
TEXT = {}
MAPS = {}
INTERIORS = {}
ENCOUNTERS = {}


def tr(en, de):
    """A new text with its German; texts from the sheet are already in de_region5.py."""
    if en in SHEET_DE["T"] or en in SHEET_DE["KEEP"]:
        if en in SHEET_DE["T"] and SHEET_DE["T"][en] != de:
            raise SystemExit("German for %r differs from de_region5.py" % en)
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
FIRST = SHEET["story"][0]
# Encounter ground on the map and in the table, per sheet ground.
GROUND = {"bog": (",", "fern"), "moss": (",", "fern"), "reed": ("%", "reeds")}
LINE = SHEET["arrival"]["line"]

# --- How the places join: every town side is a two-cell gate --------------------------------
SIDES = {"left": ([(0, 8), (0, 9)], [(1, 8), (1, 9)], "right"),
         "right": ([(11, 8), (11, 9)], [(10, 8), (10, 9)], "left"),
         "top": ([(5, 0), (6, 0)], [(5, 1), (6, 1)], "down"),
         "bottom": ([(5, 19), (6, 19)], [(5, 18), (6, 18)], "up")}
# town -> {side: (place, open flag or None)}
GATES = {
    "mossgate": {"top": ("breathing_bog", None), "bottom": ("wandering_wood", None)},
    "tallowmere": {"left": ("breathing_bog", None), "right": ("candle_causeway", None),
                   "bottom": ("wick_rift", FIRST["sets"])},
    "rootchapel": {"top": ("wandering_wood", None), "right": ("hymnmarsh", None), "left": ("gloamwater", None),
                   "bottom": ("taproot_rift", RIFTS["wick_rift"]["flag"])},
    "driftwick": {"left": ("candle_causeway", None), "bottom": ("hymnmarsh", None), "right": ("heaving_fields", None),
                  "top": ("raft_rift", RIFTS["taproot_rift"]["flag"])},
    "lastbloom": {"top": ("heaving_fields", None), "bottom": ("gloamwater", None),
                  "right": ("bloom_rift", RIFTS["raft_rift"]["flag"])},
}
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


# --- Towns: four pier arms over the bog around a spring ----------------------------------------
TOWN_ROWS = ["TTTTT__TTTTT",
             "T%%..__..%%T",
             "T.RRR__RRR.T",
             "T.HHH__HHH.T",
             "T....__....T",
             "T~~+.__.L~~T",
             "T~~+____+~~T",
             "T~~+....+~~T",
             "_+++.o..+++_",
             "_++......++_",
             "T~~+....+~~T",
             "T~~+.__.+~~T",
             "T%.RR__RR.%T",
             "T..HH__HH..T",
             "T....__....T",
             "T.%.S__..%.T",
             "T....__....T",
             "T*%..__.L%.T",
             "T%...__...%T",
             "TTTTT__TTTTT"]
# Driftwick floats: its lower streets are rafts.
RAFT_ROWS = {15: "T~+.S__.+~~T", 16: "T~+..__..++T", 17: "T~+++__+++~T", 18: "T~~..__..~~T"}
WINCH = (3, 9)            # the winch man on the Mossgate pier
ROPE_MOSSGATE = (2, 9)    # where the basket sets you down
ROPE_GREYREACH = (7, 7)   # until Halcyra's Whitecairn exists
ROPE_WHITECAIRN = (6, 12)
SHOP = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"
FINDS = ["max_tonic", "revival_leaf", "strong_tonic", "remedy", "wake_bell"]

TOWN_TEXT = {
    "mossgate": {
        "motto": ("Mossgate. Mind the moss. It minds you back.", "Mossgate. Achte auf das Moos. Es achtet auch auf dich."),
        "keeper": ("Bog Nurse Hedda: Lie down on the moss. It is warm because something under it is breathing.", "Moorpflegerin Hedda: Leg dich aufs Moos. Es ist warm, weil darunter etwas atmet."),
        "trader": ("Chandler Pim: Candles, tonics, rope. The rope is new. The last batch let someone down.", "Krämer Pim: Kerzen, Tränke, Seile. Das Seil ist neu. Die letzte Lieferung hat jemanden hängen lassen."),
        "folk": [("Peat Cutter Arn: I cut the peat at dawn. By dusk it has grown back. So has my debt.", "Torfstecher Arn: Morgens steche ich Torf. Abends ist er nachgewachsen. Meine Schulden auch."),
                 ("Mossgate Widow Lise: My husband went out to see if the bog was breathing. It was. He isn't.", "Mossgater Witwe Lise: Mein Mann wollte nachsehen, ob das Moor atmet. Es atmet. Er nicht mehr."),
                 ("Old Reeve's Clerk Oswin: Reeve Ashby keeps a book of bets. Your name is in it. The odds are not kind.", "Alter Vogtschreiber Oswin: Vogt Ashby führt ein Wettbuch. Dein Name steht drin. Die Quoten sind nicht freundlich.")]},
    "tallowmere": {
        "motto": ("Tallowmere. One candle per soul. Bring your own wick.", "Tallowmere. Eine Kerze pro Seele. Docht bitte selbst mitbringen."),
        "keeper": ("Choir Sister Brede: Rest under the candles. If one goes out, do not look at whose name it is.", "Chorschwester Brede: Ruh dich unter den Kerzen aus. Wenn eine ausgeht, schau nicht, wessen Name draufsteht."),
        "trader": ("Wax Seller Tobin: Tonics on the shelf, candles by the name. Yours is on special.", "Wachshändler Tobin: Tränke im Regal, Kerzen nach Namen. Deine ist im Angebot."),
        "folk": [("Wick Girl Ama: I trim the wicks so they burn slower. Maudrey says I am bad for business.", "Dochtmädchen Ama: Ich kürze die Dochte, damit sie langsamer brennen. Maudrey sagt, ich bin schlecht fürs Geschäft."),
                 ("Mourner Kell: I come every day to watch my brother's candle. It is very short now. So is my patience.", "Trauernder Kell: Ich komme jeden Tag und schaue nach der Kerze meines Bruders. Sie ist sehr kurz. Meine Geduld auch."),
                 ("Tallow Boiler Gunda: The best tallow comes from the bog. Do not ask from what in the bog.", "Talgsiederin Gunda: Der beste Talg kommt aus dem Moor. Frag nicht, aus was im Moor.")]},
    "rootchapel": {
        "motto": ("Rootchapel. Services daily. The roots attend every one.", "Rootchapel. Andacht täglich. Die Wurzeln kommen zu jeder."),
        "keeper": ("Sexton Wilm: Sit in the pew. If a root wraps your ankle, that means it likes you.", "Küster Wilm: Setz dich in die Bank. Wenn sich eine Wurzel um deinen Knöchel legt, mag sie dich."),
        "folk": [("Choirboy Fen: We used to sing hymns. Now we hum, so the roots cannot learn the words.", "Chorknabe Fen: Früher haben wir Hymnen gesungen. Jetzt summen wir, damit die Wurzeln den Text nicht lernen."),
                 ("Pilgrim Hesta: I walked three weeks to pray here. The chapel ate my shoes on the first night.", "Pilgerin Hesta: Drei Wochen bin ich gelaufen, um hier zu beten. In der ersten Nacht hat die Kapelle meine Schuhe gefressen."),
                 ("Gravedigger Ulf: I dig the graves. The roots fill them. We have an understanding.", "Totengräber Ulf: Ich grabe die Gräber. Die Wurzeln füllen sie. Wir verstehen uns.")]},
    "driftwick": {
        "motto": ("Driftwick. Address changes nightly. Post is not delivered.", "Driftwick. Adresse ändert sich jede Nacht. Post wird nicht zugestellt."),
        "keeper": ("Raft Medic Sorrel: Hold still. The town moves enough for both of us.", "Floßsanitäterin Sorrel: Halt still. Die Stadt bewegt sich genug für uns beide."),
        "trader": ("Raft Trader Mott: Buy now. By noon my stall is in another town and so is your change.", "Floßhändler Mott: Kauf jetzt. Bis Mittag ist mein Stand in einer anderen Stadt und dein Wechselgeld auch."),
        "folk": [("Pole Man Rudd: I push the town with a long pole. Nobody tells me where. I just push.", "Stakmann Rudd: Ich schiebe die Stadt mit einer langen Stange. Keiner sagt mir, wohin. Ich schiebe einfach."),
                 ("Fishwife Marit: My raft drifted off with my husband on it. I waved. He waved. It was the best day of our marriage.", "Fischfrau Marit: Mein Floß ist mit meinem Mann drauf abgetrieben. Ich hab gewinkt. Er hat gewinkt. Bester Tag unserer Ehe."),
                 ("Anchor Smith Dag: I forge anchors. Corran buys them, then sells where we won't be.", "Ankerschmied Dag: Ich schmiede Anker. Corran kauft sie und verkauft dann, wo wir nicht sein werden.")]},
    "lastbloom": {
        "motto": ("Lastbloom. Flowers for sale. No refunds, no questions, no roots.", "Lastbloom. Blumen zu verkaufen. Keine Rückgabe, keine Fragen, keine Wurzeln."),
        "keeper": ("Florist Ysolde: Rest among the blooms. They smell sweet. Try not to wonder why.", "Floristin Ysolde: Ruh dich zwischen den Blüten aus. Sie duften süß. Versuch nicht, dich zu fragen, warum."),
        "folk": [("Flower Picker Joss: I pick the blooms with gloves. The last picker did not. He is a bloom now.", "Blumenpflücker Joss: Ich pflücke die Blüten mit Handschuhen. Der letzte Pflücker nicht. Er ist jetzt eine Blüte."),
                 ("Bouquet Binder Edel: Every bouquet gets a ribbon and a name tag. Not the buyer's name.", "Straußbinderin Edel: Jeder Strauß bekommt ein Band und ein Namensschild. Nicht den Namen des Käufers."),
                 ("Old Lamplighter Brun: Nell Tallis used to bring me oil. Now she brings me news. The news is worse.", "Alter Laternenmann Brun: Nell Tallis hat mir früher Öl gebracht. Jetzt bringt sie Neuigkeiten. Die sind schlimmer.")]},
}
# Every town house has a door and a small room. door cell -> (room key, name, resident, line).
HOUSE_DOORS = [(3, 3), (8, 3), (3, 13), (8, 13)]
HOUSE_ROWS = ["WWWWWWWW",
              "WCffffCW",
              "WffffffW",
              "WffCCffW",
              "WffffffW",
              "WWWDWWWW"]
HOUSES = {
    "mossgate": [
        ("reeve_hall", ("Reeve's Hall", "Vogtshalle"), "clerk",
         ("Reeve's Clerk Tibbet: The reeve is out. He is always out when someone owes him a candle.", "Vogtschreiber Tibbet: Der Vogt ist nicht da. Er ist nie da, wenn ihm jemand eine Kerze schuldet.")),
        ("peat_shed", ("Peat Shed", "Torfschuppen"), "cutter",
         ("Peat Stacker Nils: Dry peat burns. Wet peat breathes. Keep them apart.", "Torfstapler Nils: Trockener Torf brennt. Nasser Torf atmet. Halt sie auseinander.")),
        ("rope_loft", ("Rope Loft", "Seilboden"), "roper",
         ("Ropemaker Agna: The winch man buys my rope by the metre and cuts it by the half metre.", "Seilerin Agna: Der Mann an der Winde kauft mein Seil meterweise und kappt es halbmeterweise.")),
        ("moss_inn", ("Moss Inn", "Mooswirtshaus"), "innkeeper",
         ("Innkeeper Bertil: Room's free. The moss in the bed charges by the hour.", "Wirt Bertil: Das Zimmer ist frei. Das Moos im Bett rechnet stundenweise ab.")),
    ],
    "tallowmere": [
        ("chandlery", ("Chandlery", "Kerzengießerei"), "chandler",
         ("Chandler Osk: Short candles for the old, long candles for the young. Medium for the ones Maudrey dislikes.", "Kerzengießer Osk: Kurze Kerzen für die Alten, lange für die Jungen. Mittlere für die, die Maudrey nicht mag.")),
        ("name_hall", ("Hall of Names", "Halle der Namen"), "scribe",
         ("Wax Scribe Rhoda: I carve the names into the wax. Spelling mistakes burn just the same.", "Wachsschreiberin Rhoda: Ich ritze die Namen ins Wachs. Rechtschreibfehler brennen genauso.")),
        ("tallow_kitchen", ("Tallow Kitchen", "Talgküche"), "boiler",
         ("Tallow Cook Harl: Stir slowly. Fast stirring brings things up from the bottom of the pot.", "Talgkoch Harl: Langsam rühren. Schnelles Rühren holt Dinge vom Topfboden hoch.")),
        ("choir_dorm", ("Choir Dormitory", "Chorschlafsaal"), "singer",
         ("Choir Singer Wenzel: We sing for the candles at night. The candles never clap.", "Chorsänger Wenzel: Nachts singen wir für die Kerzen. Die Kerzen klatschen nie.")),
    ],
    "rootchapel": [
        ("vestry", ("Vestry", "Sakristei"), "priest",
         ("Curate Anselm: Ossian took the pulpit. The roots took Ossian. I took the collection box.", "Kaplan Anselm: Ossian hat die Kanzel übernommen. Die Wurzeln haben Ossian übernommen. Ich hab den Opferstock übernommen.")),
        ("bell_cellar", ("Bell Cellar", "Glockenkeller"), "ringer",
         ("Bell Ringer Grit: The bell rang by itself last night. The roots are learning.", "Glöcknerin Grit: Die Glocke hat letzte Nacht von selbst geläutet. Die Wurzeln lernen dazu.")),
        ("almshouse", ("Almshouse", "Armenhaus"), "elder",
         ("Almsman Teodor: We get bread on Sundays. The roots get the rest of us on Mondays.", "Armenhäusler Teodor: Sonntags gibt es Brot. Montags kriegen die Wurzeln den Rest von uns.")),
        ("herb_room", ("Herb Room", "Kräuterstube"), "herbalist",
         ("Herbalist Minna: Root tea calms the nerves. It also roots the drinker. Small print.", "Kräuterfrau Minna: Wurzeltee beruhigt die Nerven. Er verwurzelt auch den Trinker. Kleingedrucktes.")),
    ],
    "driftwick": [
        ("pole_house", ("Pole House", "Stakenhaus"), "poleman",
         ("Pole Master Ebbe: We steer the town by vote. The vote is whoever holds the longest pole.", "Stakmeister Ebbe: Wir steuern die Stadt per Abstimmung. Abstimmen darf, wer die längste Stange hält.")),
        ("net_shed", ("Net Shed", "Netzschuppen"), "netter",
         ("Net Mender Yrsa: I catch fish by day and neighbours by night. The neighbours fall off more.", "Netzflickerin Yrsa: Tagsüber fange ich Fische, nachts Nachbarn. Die Nachbarn fallen öfter runter.")),
        ("chart_room", ("Chart Room", "Kartenstube"), "cartographer",
         ("Chart Keeper Lorne: This map shows where Driftwick was last Tuesday. It sells best to the ones who want to miss it.", "Kartenwart Lorne: Diese Karte zeigt, wo Driftwick letzten Dienstag war. Am besten verkauft sie sich an die, die es verfehlen wollen.")),
        ("bunk_raft", ("Bunk Raft", "Schlaffloß"), "sleeper",
         ("Bunk Keeper Sanna: Sleep tight. Tie your bunk to the floor. Tie the floor to something.", "Kojenwartin Sanna: Schlaf gut. Bind deine Koje am Boden fest. Bind den Boden an irgendwas.")),
    ],
    "lastbloom": [
        ("flower_house", ("Flower House", "Blumenhaus"), "florist",
         ("Flower Seller Gesine: The roses this year are very red. Last year was a bad year for wanderers.", "Blumenhändlerin Gesine: Die Rosen sind dieses Jahr sehr rot. Letztes Jahr war ein schlechtes Jahr für Wanderer.")),
        ("seed_store", ("Seed Store", "Samenlager"), "seedkeeper",
         ("Seed Keeper Hale: Every seed has a name tag. I am not allowed to read them out.", "Samenwart Hale: Jeder Samen hat ein Namensschild. Vorlesen darf ich sie nicht.")),
        ("lamp_room", ("Lamp Room", "Lampenstube"), "lamplighter",
         ("Lamp Boy Ivo: Nell borrowed our best lamp. She said she would bring it back lit.", "Lampenjunge Ivo: Nell hat unsere beste Lampe geliehen. Sie hat gesagt, sie bringt sie brennend zurück.")),
        ("press_room", ("Press Room", "Pressstube"), "presser",
         ("Flower Presser Dorle: I press the blooms flat in old books. Sometimes the books are diaries.", "Blumenpresserin Dorle: Ich presse die Blüten in alten Büchern. Manchmal sind die Bücher Tagebücher.")),
    ],
}
SPRITE = {"elder": "elder", "priest": "elder", "scribe": "elder"}


def houses(mid, rows):
    """Puts a door on each town house and writes its room; returns the town's warps to the rooms."""
    out = []
    for (dx, dy), (key, name, who, line) in zip(HOUSE_DOORS, HOUSES[mid]):
        if rows[dy][dx] != "H" or rows[dy + 1][dx] not in "._":
            raise SystemExit("%s: no house wall above open ground at %d,%d" % (mid, dx, dy))
        rows[dy] = rows[dy][:dx] + "D" + rows[dy][dx + 1:]
        rid = "%s_%s" % (mid, key)
        out.append(warp(dx, dy, rid, 3, 4, "up"))
        room = {"name": tr(*name), "biome": "town", "backdrop": "field", "rows": list(HOUSE_ROWS),
                "warps": [warp(3, 5, mid, dx, dy + 1, "down")],
                "npcs": [npc(who, 4, 2, "down", text(rid + "_" + who, lines(line)), SPRITE.get(who, "villager"))],
                "signs": []}
        add(rid, room)
        INTERIORS[rid] = mid
    return out


# folk: (home cell, facing, dusk cell by the spring, facing)
FOLK_PLACES = [((1, 4), "right", (4, 9), "right"), ((10, 14), "left", (6, 9), "left"), ((2, 16), "right", (7, 8), "left")]


def gate_block(x, y, flag):
    return {"x": x, "y": y, "open_flag": flag, "closed": "#"}


def town(mid):
    t = TOWNS[mid]
    rows = list(TOWN_ROWS)
    if mid == "driftwick":
        for y, r in RAFT_ROWS.items():
            rows[y] = r
    gates = GATES[mid]
    for side, (cells, _, _) in SIDES.items():
        if side not in gates:
            for x, y in cells:
                rows[y] = rows[y][:x] + "T" + rows[y][x + 1:]
    tt = TOWN_TEXT[mid]
    sign = text(mid + "_sign", lines((t["name"], t["name"]), tt["motto"]))
    npcs = [npc("keeper", 6, 7, "down", text(mid + "_keeper", {"lines": lines(tt["keeper"]), "action": "heal"}), "elder")]
    if t.get("shop"):
        npcs.append(npc("trader", 2, 14, "down", text(mid + "_trader", {"lines": lines(tt["trader"]), "action": SHOP}), "villager"))
    for i, (line, ((hx, hy), hf, (dx, dy), df)) in enumerate(zip(tt["folk"], FOLK_PLACES)):
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
    if mid == "mossgate":
        npcs.append(npc("winchman", WINCH[0], WINCH[1], "left", winch_text(), "elder"))
        npcs.append(npc("nell", 9, 4, "down", nell_text(), "ranger", color="5a6a3a"))
    m = {"name": t["name"], "biome": "town", "backdrop": "lake", "outdoor": True, "heal_point": [5, 9], "rows": rows,
         "warps": warps, "npcs": npcs, "signs": [{"x": 4, "y": 15, "dialogue": sign}], "blocks": blocks,
         "secrets": [secret(0, 13, FINDS[0], "find_%s_1" % mid), secret(11, 16, FINDS[1], "find_%s_2" % mid),
                     secret(11, 4, FINDS[2], "find_%s_3" % mid, 2)],
         "square": [5, 8]}
    add(mid, m)


def winch_text():
    return text("winchman", {"lines": [sheet(SHEET["arrival"]["text"])], "action": "transit " + LINE})


def nell_text():
    text("nell_after", [sheet(FIRST["betrayal"]["text"])] + lines(
        ("Nell: Don't look at me like that. The winch man cuts every rope short. I only steer.", "Nell: Schau mich nicht so an. Der Mann an der Winde kappt jedes Seil zu kurz. Ich steuere nur.")))
    return text("nell", {"if": {"not_flag": FIRST["sets"]}, "else": "nell_after",
                         "lines": [sheet(FIRST["text"])] + lines(
                             ("Nell Tallis: I pilot rafts and I know every path before it moves. First job: the Wick Rift under Tallowmere, south gate.", "Nell Tallis: Ich steuere Flöße und kenne jeden Weg, bevor er wandert. Erster Auftrag: der Dochtriss unter Tallowmere, Südtor."),
                             ("Nell Tallis: Trust me. Everyone here does, at least once.", "Nell Tallis: Vertrau mir. Das tun hier alle, mindestens einmal.")),
                         "action": "set_flag " + FIRST["sets"]})


def place_arrival(place, from_town, i):
    """Arrival cell on [place] when coming from [from_town] through gate cell i, and the facing."""
    if place in ROUTES:
        top = ROUTES[place]["links"][0] == from_town
        return ((5 + i, 1), "down") if top else ((5 + i, ROUTE_H - 2), "up")
    return (5 + i, RIFT_H - 2), "up"


# --- Roads: boardwalks over black water, moss and reed beds -----------------------------------
ROUTE_ROWS = ["TTTTT__TTTTT",
              "T~~..__.AAAT",
              "T~~...__AAAT",
              "T.....__...T",
              "TBB~~~~+~~.T",
              "TBB~~~~+~~.T",
              "T....++++..T",
              "T~~~.+..CCCT",
              "T~~~.+..CCCT",
              "T....+.....T",
              "TAA..+~~~~~T",
              "TAA..++++..T",
              "T~~~....+..T",
              "T~~~.BB.+..T",
              "T....BB.++.T",
              "TCCC.....+.T",
              "TCCC~~~~.+.T",
              "T...~~~~.+.T",
              "T..++++++..T",
              "T..+..AAA..T",
              "T~~+..AAA~~T",
              "T~~+.....~~T",
              "T..++__....T",
              "T....__.BB.T",
              "T.....__BB.T",
              "TTTTT__TTTTT"]
# Fill-ins beside the three sheet slots: (species, slot index for the ground), uncommon kinds.
FILL = {"breathing_bog": [("Peatbloom", 0), ("Gloomgillar", 2)], "wandering_wood": [("Morelamp", 0), ("Woadwhorl", 2)],
        "candle_causeway": [("Sootlurk", 0), ("Glowflitter", 2)], "hymnmarsh": [("Skimmit", 0), ("Prismist", 2)],
        "heaving_fields": [("Thrashkin", 0), ("Nimbuck", 2)], "gloamwater": [("Sablowl", 0), ("Fumewraith", 2)]}
FILL_WEIGHTS = [14, 12]
MARSH = {"hymnmarsh", "gloamwater"}
# Two Wayfarers per road: (key, title, team slot picks or fill picks, cell, facing, talk, intro, defeat)
ROUTE_TEXT = {
    "breathing_bog": [
        ("peatcutter", ("Peat Cutter Ragna", "Torfstecherin Ragna"), ("s", 0, "f", 0), (10, 9), "left",
         ("Ragna: Feel that? The ground just breathed in. Don't be standing here when it breathes out.", "Ragna: Spürst du das? Der Boden hat eingeatmet. Steh nicht hier, wenn er ausatmet."),
         ("Ragna: I cut peat. Today I cut corners.", "Ragna: Ich steche Torf. Heute steche ich dich."),
         ("Ragna: Fine. The bog will have you later. It's patient.", "Ragna: Schön. Das Moor holt dich später. Es ist geduldig.")),
        ("bogwalker", ("Bog Walker Kjell", "Moorgänger Kjell"), ("s", 1, "s", 2), (2, 19), "right",
         ("Kjell: I walk the bog on stilts. My brother walked it without. Only one of us still walks.", "Kjell: Ich gehe auf Stelzen übers Moor. Mein Bruder ging ohne. Nur einer von uns geht noch."),
         ("Kjell: Stand still. It's easier for both of us.", "Kjell: Halt still. Ist für uns beide einfacher."),
         ("Kjell: You float. Annoying.", "Kjell: Du gehst nicht unter. Ärgerlich.")),
    ],
    "wandering_wood": [
        ("oakwatcher", ("Oak Watcher Tilde", "Eichenwächterin Tilde"), ("s", 0, "f", 0), (10, 9), "left",
         ("Tilde: I count the oaks every night. One more step each. Last week one stepped on a tent.", "Tilde: Ich zähle die Eichen jede Nacht. Jede einen Schritt weiter. Letzte Woche ist eine auf ein Zelt getreten."),
         ("Tilde: The oaks are watching. Let's give them a show.", "Tilde: Die Eichen schauen zu. Bieten wir ihnen was."),
         ("Tilde: The oaks liked that. They moved closer to you.", "Tilde: Das hat den Eichen gefallen. Sie sind näher an dich ran.")),
        ("mapseller", ("Map Seller Bodo", "Kartenhändler Bodo"), ("s", 1, "f", 1), (2, 19), "right",
         ("Bodo: Fresh maps! Accurate until sunset. After that, accurate for somewhere else.", "Bodo: Frische Karten! Genau bis Sonnenuntergang. Danach genau für woanders."),
         ("Bodo: You didn't buy a map. Now you're lost and I'm offended.", "Bodo: Du hast keine Karte gekauft. Jetzt bist du verloren und ich bin beleidigt."),
         ("Bodo: Here, a free map. It's wrong. Consider it a lesson.", "Bodo: Hier, eine Gratiskarte. Sie ist falsch. Betrachte sie als Lektion.")),
    ],
    "candle_causeway": [
        ("candlebearer", ("Candle Bearer Ylva", "Kerzenträgerin Ylva"), ("s", 0, "f", 0), (10, 9), "left",
         ("Ylva: I carry candles to the Choir. If one goes out on the way, the person it's for gets a bad week.", "Ylva: Ich trage Kerzen zum Chor. Wenn unterwegs eine ausgeht, hat der Mensch dazu eine schlechte Woche."),
         ("Ylva: Hold this candle while we fight. It's yours.", "Ylva: Halt die Kerze, während wir kämpfen. Es ist deine."),
         ("Ylva: Still lit. Maudrey won't like that.", "Ylva: Brennt noch. Das wird Maudrey nicht gefallen.")),
        ("tollwick", ("Wick Toll Keeper Oda", "Dochtzöllnerin Oda"), ("s", 1, "f", 1), (2, 19), "right",
         ("Oda: Toll is one candle stub per crossing. Or one wick. Or one finger, I'm flexible.", "Oda: Zoll ist ein Kerzenstummel pro Überquerung. Oder ein Docht. Oder ein Finger, ich bin flexibel."),
         ("Oda: No stub? Then we settle it the old way.", "Oda: Kein Stummel? Dann regeln wir das auf die alte Art."),
         ("Oda: Toll waived. I'll charge the next one double.", "Oda: Zoll erlassen. Der Nächste zahlt doppelt.")),
    ],
    "hymnmarsh": [
        ("hummer", ("Marsh Hummer Ilse", "Sumpfsummerin Ilse"), ("s", 0, "s", 2), (10, 9), "left",
         ("Ilse: We hum instead of singing. The marsh learns the words and then it sings back. Badly.", "Ilse: Wir summen statt zu singen. Der Sumpf lernt den Text und singt zurück. Schlecht."),
         ("Ilse: Hum along. Or scream. The marsh likes both.", "Ilse: Summ mit. Oder schrei. Der Sumpf mag beides."),
         ("Ilse: Off key. Like everyone who wins here.", "Ilse: Schief. Wie alle, die hier gewinnen.")),
        ("rootpicker", ("Root Picker Arvid", "Wurzelsammler Arvid"), ("s", 1, "f", 1), (2, 19), "right",
         ("Arvid: I pick roots for Ossian's tea. Some roots pick back.", "Arvid: Ich sammle Wurzeln für Ossians Tee. Manche Wurzeln sammeln zurück."),
         ("Arvid: Ossian said to slow you down. He didn't say how.", "Arvid: Ossian hat gesagt, ich soll dich aufhalten. Er hat nicht gesagt, wie."),
         ("Arvid: Don't tell Ossian. He'll feed me to the chapel.", "Arvid: Sag's nicht Ossian. Der verfüttert mich an die Kapelle.")),
    ],
    "heaving_fields": [
        ("heaver", ("Field Heaver Gorm", "Feldheber Gorm"), ("s", 0, "f", 0), (10, 9), "left",
         ("Gorm: The fields heave at noon. Farmers here plant at dawn and harvest wherever the crop lands.", "Gorm: Mittags wogen die Felder. Die Bauern pflanzen im Morgengrauen und ernten, wo die Ernte landet."),
         ("Gorm: Brace yourself. The ground does the first punch.", "Gorm: Halt dich fest. Den ersten Schlag macht der Boden."),
         ("Gorm: You kept your feet. Rare. The ground will be cross.", "Gorm: Du bist stehen geblieben. Selten. Der Boden wird sauer sein.")),
        ("betbroker", ("Bet Runner Sigge", "Wettläufer Sigge"), ("s", 1, "f", 1), (2, 19), "right",
         ("Sigge: I run bets for Reeve Ashby. You're at nine to one. Against.", "Sigge: Ich laufe Wetten für Vogt Ashby. Du stehst neun zu eins. Dagegen."),
         ("Sigge: If I beat you, the odds get better. For me.", "Sigge: Wenn ich dich schlage, werden die Quoten besser. Für mich."),
         ("Sigge: Eight to one now. Still against. Ashby hates surprises.", "Sigge: Jetzt acht zu eins. Immer noch dagegen. Ashby hasst Überraschungen.")),
    ],
    "gloamwater": [
        ("gloamferry", ("Gloam Ferrywoman Una", "Dämmerfährfrau Una"), ("s", 0, "s", 2), (10, 9), "left",
         ("Una: I ferry the dead across the gloam. The living cost extra, they keep asking questions.", "Una: Ich setze die Toten übers Dämmerwasser. Lebende kosten extra, die stellen ständig Fragen."),
         ("Una: Pay the ferry in battle. Coins sink.", "Una: Zahl die Fähre im Kampf. Münzen gehen unter."),
         ("Una: Paid. Sit at the front. The back is for the other passengers.", "Una: Bezahlt. Setz dich nach vorn. Hinten sitzen die anderen Fahrgäste.")),
        ("bloomthief", ("Bloom Thief Rasmus", "Blütendieb Rasmus"), ("s", 1, "s", 2), (2, 19), "right",
         ("Rasmus: I steal blooms from Lastbloom and sell them back to Lastbloom. Sabeline takes a cut. Of me.", "Rasmus: Ich klaue Blüten in Lastbloom und verkaufe sie an Lastbloom zurück. Sabeline kriegt einen Anteil. Von mir."),
         ("Rasmus: You saw nothing. Let me help you forget.", "Rasmus: Du hast nichts gesehen. Ich helf dir beim Vergessen."),
         ("Rasmus: Fine. Take a bloom. Don't ask whose it was.", "Rasmus: Schön. Nimm eine Blüte. Frag nicht, wem sie gehörte.")),
    ],
}


def slot_species(s):
    return s["species"] or s["stand_in"]


def species_table():
    data = json.load(open(os.path.join(ROOT, "data", "spirlings.json")))
    data = data if isinstance(data, list) else data.get("spirlings", data)
    return {x["name"]: x for x in data}


SPECIES = species_table()


def check_team(who, crew):
    els = set()
    for e in crew:
        if e["species"] not in SPECIES:
            raise SystemExit("%s: unknown species %s" % (who, e["species"]))
        els.update(SPECIES[e["species"]]["elements"])
    if len(els) > 3:
        raise SystemExit("%s covers %d elements" % (who, len(els)))
    if len({(e["species"], e["level"]) for e in crew}) < len(crew):
        raise SystemExit("%s repeats a Spirling" % who)
    return crew


def route(mid):
    r = ROUTES[mid]
    rows = list(ROUTE_ROWS)
    for letter, slot in zip("ABC", r["slots"]):
        rows = [row.replace(letter, GROUND[slot["ground"]][0]) for row in rows]
    lo, hi = r["ring"]
    spawns = []
    for slot in r["slots"]:
        spawns.append({"species": slot_species(slot), "min": lo, "max": hi, "weight": slot["weight"], "ground": GROUND[slot["ground"]][1]})
    fills = []
    for (sp, gi), w in zip(FILL[mid], FILL_WEIGHTS):
        if sp not in SPECIES or SPECIES[sp].get("rarity") != "uncommon":
            raise SystemExit("%s: fill-in %s must be an uncommon kind" % (mid, sp))
        fills.append(sp)
        spawns.append({"species": sp, "min": lo, "max": hi - 1, "weight": w, "ground": GROUND[r["slots"][gi]["ground"]][1]})
    ENCOUNTERS[mid] = {"rate": 0.10 if mid in MARSH else 0.12, "spawns": spawns}
    a, b = r["links"]
    warps = []
    for i in range(2):
        (tx, ty), facing = arrival_in_town(a, mid, i)
        warps.append(warp(5 + i, 0, a, tx, ty, facing))
        (tx, ty), facing = arrival_in_town(b, mid, i)
        warps.append(warp(5 + i, ROUTE_H - 1, b, tx, ty, facing))
    npcs = []
    for n, (key, title, picks, (x, y), facing, talk, intro, defeat) in enumerate(ROUTE_TEXT[mid]):
        names = []
        for kind, idx in zip(picks[::2], picks[1::2]):
            names.append(slot_species(r["slots"][idx]) if kind == "s" else fills[idx])
        crew = check_team(mid + " " + key, [{"species": s, "level": hi - (1 if n == 0 and i == 0 else 0)} for i, s in enumerate(names)])
        npcs.append(npc(key, x, y, facing, text("%s_%s" % (mid, key), lines(talk)), "villager" if n else "ranger",
                        trainer=tr(*title), intro=text("%s_%s_intro" % (mid, key), lines(intro)),
                        defeat=text("%s_%s_defeat" % (mid, key), lines(defeat)), money=hi * 45, team=crew))
    m = {"name": r["name"], "biome": "marsh" if mid in MARSH else "route", "backdrop": "lake", "outdoor": True,
         "encounters": mid, "rows": rows, "warps": warps, "npcs": npcs, "signs": [],
         "secrets": [secret(0, 9, FINDS[3], "find_%s_1" % mid), secret(11, 11, FINDS[4], "find_%s_2" % mid),
                     secret(0, 18, FINDS[0], "find_%s_3" % mid), secret(11, 23, FINDS[2], "find_%s_4" % mid)]}
    add(mid, m)


def arrival_in_town(town_id, place, i):
    cells, facing = town_arrival(town_id, place)
    return cells[i], facing


# --- Rifts: sunken groves of black water and old oaks ------------------------------------------
RIFT_ROWS = ["TTTTTTTTTTTT",
             "TT~~.XX.~~TT",
             "T~~.......~T",
             "T~......T_.T",
             "T..o.....T_T",
             "T.......ST_T",
             "T~~~....TT_T",
             "T~~~....~T_T",
             "T........T_T",
             "T.X......T_T",
             "T....~~..T_T",
             "T....~~..T_T",
             "TTTT..TTTT_T",
             "T........T_T",
             "T..~~....T_T",
             "TTT..TTTTT_T",
             "T........T_T",
             "T........T_T",
             "TTTT..TTTT.T",
             "T..........T",
             "T.X......X.T",
             "TTTTT..TTTTT"]
RULES = {"wick_rift": "ember_pulse", "taproot_rift": "vine_tangle", "raft_rift": "undertow", "bloom_rift": "night_dark"}
RIFT_TEXT = {
    "wick_rift": (("Ten thousand wicks stand in black water. Each one waits for a name.", "Zehntausend Dochte stehen in schwarzem Wasser. Jeder wartet auf einen Namen."),
                  (("Wick Acolyte Brenna", "Docht-Akolythin Brenna"), ("Brenna: Maudrey lit a candle for me when I joined. It is very short. I try not to think about it.", "Brenna: Maudrey hat mir zum Eintritt eine Kerze angezündet. Sie ist sehr kurz. Ich versuche, nicht daran zu denken."),
                   ("Brenna: Your candle is burning. Let's see how fast.", "Brenna: Deine Kerze brennt. Mal sehen, wie schnell."),
                   ("Brenna: Go on. Maudrey has a fresh wick ready for you.", "Brenna: Geh. Maudrey hat schon einen frischen Docht für dich."))),
    "taproot_rift": (("Roots as thick as pews grow through the floor. They hum the hymns nobody sings any more.", "Wurzeln so dick wie Kirchenbänke wachsen durch den Boden. Sie summen die Hymnen, die keiner mehr singt."),
                  (("Root Acolyte Malte", "Wurzel-Akolyth Malte"), ("Malte: Ossian says the moor must eat. I volunteered to help. Not to be eaten. To help.", "Malte: Ossian sagt, das Moor muss essen. Ich hab mich zum Helfen gemeldet. Nicht zum Gegessenwerden. Zum Helfen."),
                   ("Malte: Dinner is served. You're the dinner.", "Malte: Das Essen ist angerichtet. Du bist das Essen."),
                   ("Malte: Ossian is just past the roots. He's been saying grace for an hour.", "Malte: Ossian ist gleich hinter den Wurzeln. Er spricht seit einer Stunde das Tischgebet."))),
    "raft_rift": (("Loose rafts drift in a circle over water with no bottom. The Rift pulls the town here every night.", "Lose Flöße treiben im Kreis über Wasser ohne Grund. Der Riss zieht die Stadt jede Nacht hierher."),
                  (("Raft Acolyte Joran", "Floß-Akolyth Joran"), ("Joran: Corran pays me to tell the town where it will be. I am wrong on purpose. He pays more for that.", "Joran: Corran bezahlt mich, damit ich der Stadt sage, wo sie sein wird. Ich liege absichtlich falsch. Dafür zahlt er mehr."),
                   ("Joran: You're standing on the wrong raft. All of them are wrong.", "Joran: Du stehst auf dem falschen Floß. Alle sind falsch."),
                   ("Joran: Corran is on the last raft. Don't step where he points.", "Joran: Corran ist auf dem letzten Floß. Tritt nicht dahin, wo er hinzeigt."))),
    "bloom_rift": (("A field of pale flowers under a sky that never finishes getting dark. Every flower turns to watch you.", "Ein Feld bleicher Blumen unter einem Himmel, der nie ganz dunkel wird. Jede Blume dreht sich nach dir um."),
                   (("Bloom Acolyte Signe", "Blüten-Akolythin Signe"), ("Signe: Sabeline tells me which flower was whose. I wish she would stop.", "Signe: Sabeline sagt mir, welche Blume wem gehörte. Ich wünschte, sie würde aufhören."),
                    ("Signe: Lie down in the bloom. Just for a moment. Everyone does, eventually.", "Signe: Leg dich in die Blüte. Nur kurz. Irgendwann tun es alle."),
                    ("Signe: Still standing. The flowers are disappointed.", "Signe: Stehst immer noch. Die Blumen sind enttäuscht."))),
}


def rift(mid):
    rf = RIFTS[mid]
    w = WARDENS[mid]
    key = "v5_" + mid[:-5]
    town_id = rf["near"]
    rows = list(RIFT_ROWS)
    motto, (aname, talk, intro, defeat) = RIFT_TEXT[mid]
    text(mid + "_spring", {"lines": lines(("Black water wells up between the roots. It is warm, like breath.", "Schwarzes Wasser quillt zwischen den Wurzeln hervor. Es ist warm, wie Atem."),
                                          ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")), "action": "heal"})
    text(mid + "_sign", [sheet(rf["name"]), tr(*motto)])
    crew = [{"species": slot_species(t), "level": t["level"]} for t in w["team"]]
    ch = CHAPTER[mid]
    text("warden_" + w["id"], {"lines": [sheet(ch["text"])],
                               "after_flag": [{"flag": rf["flag"], "lines": [sheet(ch["betrayal"]["text"])]}]})
    text("warden_%s_intro" % w["id"], [sheet(w["intro"])])
    text("warden_%s_defeat" % w["id"], [sheet(w["defeat"])])
    flags = [rf["flag"]] + ([ch["sets"]] if ch["sets"] != rf["flag"] else [])
    warden = npc("warden_" + w["id"], 5, 2, "down", "%s/warden_%s" % (DIA, w["id"]), "warden", trainer=sheet(w["name"]),
                 warden=key, team=crew, intro="%s/warden_%s_intro" % (DIA, w["id"]), defeat="%s/warden_%s_defeat" % (DIA, w["id"]),
                 ai=3, money=w["money"], rule=RULES[mid], win_flags=flags)
    acolyte_crew = check_team(mid, [dict(crew[0], level=w["ring"] - 1), dict(crew[1], level=w["ring"] - 1)])
    acolyte = npc("acolyte", 7, 17, "left", text(mid + "_acolyte", lines(talk)), "warden", trainer=tr(*aname),
                  intro=text(mid + "_acolyte_intro", lines(intro)), defeat=text(mid + "_acolyte_defeat", lines(defeat)),
                  money=(w["ring"] - 1) * 45, team=acolyte_crew)
    back, facing = town_arrival(town_id, mid)
    m = {"name": rf["name"], "biome": "rift", "backdrop": "lake", "heal_point": [3, 5], "rows": rows,
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
def neighbours(mid):
    out = []
    for w in MAPS[mid]["warps"]:
        if w["to"] not in out and w["to"] not in INTERIORS:
            out.append(w["to"])
    return out


def layout_lines():
    out = []
    for mid in list(TOWNS) + list(ROUTES) + list(RIFTS):
        pos = (TOWNS.get(mid) or ROUTES.get(mid) or RIFTS.get(mid))["pos"]
        kind = "town" if mid in TOWNS else "rift" if mid in RIFTS else "marsh" if mid in MARSH else "route"
        out.append('  "%s": {"region": "%s", "pos": [%d, %d], "kind": "%s", "neighbours": %s}'
                   % (mid, REGION, pos[0], pos[1], kind, json.dumps(neighbours(mid))))
    for rid, mid in INTERIORS.items():
        out.append('  "%s": {"inside": "%s", "region": "%s"}' % (rid, mid, REGION))
    return out


def has_whitecairn():
    return os.path.exists(os.path.join(ROOT, "data", "maps", "whitecairn.json"))


def patch_layout():
    path = os.path.join(ROOT, "data", "world_layout.json")
    rows = [ln for ln in open(path, encoding="utf-8").read().rstrip("\n").split("\n")
            if '"region": "%s"' % REGION not in ln and '"%s"' % LINE not in ln and not ln.startswith('  "%s": {"name"' % REGION)]

    def end_of(block):
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

    append(' "regions": {', ['  "%s": {"name": "Quivermoor", "origin": [37, 0], "size": [7, 6]}' % REGION])
    top = ("whitecairn", ROPE_WHITECAIRN) if has_whitecairn() else ("greyreach", ROPE_GREYREACH)
    append(' "lines": {', ['  "%s": {"name": "Rope Basket", "kind": "ferry", "open_flag": "%s", "stops": {"%s": [%d, %d, "right"], "mossgate": [%d, %d, "right"]}}'
                           % (LINE, SHEET["unlock_flag"], top[0], top[1][0], top[1][1], ROPE_MOSSGATE[0], ROPE_MOSSGATE[1])])
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
    """The winch man at the top of the rope: on Whitecairn once Halcyra's maps exist, else the Greyreach."""
    path = os.path.join(ROOT, "data", "story_npcs.json")
    d = json.load(open(path, encoding="utf-8"))
    for mid in ("greyreach", "whitecairn"):
        if mid in d:
            d[mid]["npcs"] = [n for n in d[mid].get("npcs", []) if n.get("id") != "rope_winchman"]
    top, (x, y) = ("whitecairn", ROPE_WHITECAIRN) if has_whitecairn() else ("greyreach", ROPE_GREYREACH)
    d.setdefault(top, {}).setdefault("npcs", []).append(
        {"id": "rope_winchman", "x": x + 1, "y": y, "facing": "left", "dialogue": "%s/winchman_top" % DIA,
         "sprite": "elder", "show_flag": SHEET["unlock_flag"]})
    text("winchman_top", {"lines": lines(("Winch Man: Quivermoor? Down the rope. Paid by the metre. Your heirs get the bill for the rest.", "Mann an der Winde: Quivermoor? Am Seil runter. Bezahlt wird pro Meter. Den Rest kriegen deine Erben in Rechnung.")),
                          "action": "transit " + LINE})
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
    import quivermoor_side  # noqa: E402  the eight side goals (data/quests.json q5_*)
    quivermoor_side.build(sys.modules[__name__])
    patch_story_npcs()
    tr("Rope Basket", "Seilkorb")
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
    # Loc.lookup reads only "strings": names kept as they are still need an entry.
    for m in MAPS.values():
        if m["name"] in SHEET_DE["KEEP"] and m["name"] not in SHEET_DE["T"]:
            GERMAN[m["name"]] = m["name"]
    with open(os.path.join(ROOT, "tools", "i18n", "de_quivermoor.py"), "w", encoding="utf-8") as f:
        f.write("# German texts for Quivermoor's maps. Written by tools/art/world/quivermoor.py:\n")
        f.write("# edit the tr()/lines() pairs there, not this file.\n")
        f.write("KEEP = []\nT = {\n")
        for en in sorted(GERMAN):
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(GERMAN[en], ensure_ascii=False)))
        f.write("}\n")
    print("wrote %d maps, %d dialogue entries, %d German texts" % (len(MAPS), len(TEXT), len(GERMAN)))


if __name__ == "__main__":
    main()
