#!/usr/bin/env python3
"""Quillmarch, the post-game Era III region, built from its sheet data/region3.json: six towns,
seven roads through the print country and the four Rifts with their Wardens. Region "quillmarch"
(drawn in Era III, art/era3/tiles/overworld_quillmarch.png).

Run on its own: python3 tools/art/world/quillmarch.py
It writes data/maps/<id>.json for the 17 places and their 24 house rooms, data/dialogue/quillmarch.json,
the German table tools/i18n/de_quillmarch.py, and patches (idempotent) data/encounters.json,
data/world_layout.json and data/story_npcs.json (the mail boatman on the Lastlamp square); the side
goals, landmark halls and story duels come from tools/art/world/quillmarch_side.py. Names,
rings, sheet slots and Warden teams come from the sheet; WILD below adds the rest of Quillmarch's
70 own kinds to the road tables, so every one of them can be met in the wild.

How the way opens:
  lastlamp (Vellmarch) <-> burin_landing   the Mail Boat (line quillmarch_mail_boat), after era2_finale_done
  burin_landing, Wren Marlow               sets v3_ch1_done
  mordant_row -> bath_rift                 v3_ch1_done
  rimeholt -> rime_rift                    v3_ch2_done (set with rift_v3_bath_sealed)
  ledgerholm -> ledger_rift                v3_ch3_done (set with rift_v3_rime_sealed)
  proofgate -> press_rift                  v3_ch4_done (set with rift_v3_ledger_sealed)
Beating a Warden seals its Rift (GameState.seal_rift with "warden": v3_bath / v3_rime / v3_ledger /
v3_press) and sets the sheet's Rift flag and chapter flag (win_flags); Grisel's win sets
quillmarch_done, which data/eras.json turns into era3_finale_done (Halcyra's funicular).
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

REGION = "quillmarch"
DIA = "quillmarch"
SHEET = json.load(open(os.path.join(ROOT, "data", "region3.json")))
SHEET_DE = {}
exec(open(os.path.join(ROOT, "tools", "i18n", "de_region3.py"), encoding="utf-8").read(), SHEET_DE)
GERMAN = {}
TEXT = {}
MAPS = {}
INTERIORS = {}
ENCOUNTERS = {}


def tr(en, de):
    """A new text with its German; texts from the sheet are already in de_region3.py."""
    if en in SHEET_DE["T"] or en in SHEET_DE["KEEP"]:
        if en in SHEET_DE["T"] and SHEET_DE["T"][en] != de:
            raise SystemExit("German for %r differs from de_region3.py" % en)
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
# Map tile and table ground per sheet ground.
GROUND = {"fern": (",", "fern"), "scree": (":", "scree"), "reed": ("%", "reeds")}
LINE = SHEET["arrival"]["line"]

# --- How the places join: every town side is a two-cell gate --------------------------------
SIDES = {"left": ([(0, 8), (0, 9)], [(1, 8), (1, 9)], "right"),
         "right": ([(11, 8), (11, 9)], [(10, 8), (10, 9)], "left"),
         "top": ([(5, 0), (6, 0)], [(5, 1), (6, 1)], "down"),
         "bottom": ([(5, 19), (6, 19)], [(5, 18), (6, 18)], "up")}
# town -> {side: (place, open flag or None)}
GATES = {
    "burin_landing": {"right": ("drypoint_lane", None), "bottom": ("smudge_marsh", None)},
    "platewick": {"left": ("drypoint_lane", None), "top": ("mordant_steps", None), "right": ("gravers_causeway", None)},
    "mordant_row": {"bottom": ("mordant_steps", None), "right": ("hoarfrost_moor", None),
                    "top": ("bath_rift", CHAPTER["bath_rift"]["needs"])},
    "rimeholt": {"left": ("hoarfrost_moor", None), "bottom": ("rimeglass_pass", None),
                 "right": ("rime_rift", CHAPTER["rime_rift"]["needs"])},
    "ledgerholm": {"left": ("gravers_causeway", None), "top": ("rimeglass_pass", None), "bottom": ("stamp_road", None),
                   "right": ("ledger_rift", CHAPTER["ledger_rift"]["needs"])},
    "proofgate": {"right": ("stamp_road", None), "top": ("smudge_marsh", None),
                  "bottom": ("press_rift", CHAPTER["press_rift"]["needs"])},
}
# Grid cells of the Rifts in world_layout.json region quillmarch (towns and roads carry theirs in the sheet).
RIFT_POS = {"bath_rift": [1, 0], "rime_rift": [5, 1], "ledger_rift": [5, 3], "press_rift": [2, 5]}
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


# --- Towns: print-house streets round a pump, scree yards and fenced presses -------------------
TOWN_ROWS = ["TTTTT__TTTTT",
             "T::..__..::T",
             "T.RRR__RRR.T",
             "T.HHH__HHH.T",
             "T....__....T",
             "T##..__.L##T",
             "T....____..T",
             "T.:......:.T",
             "_____o._____",
             "_____.._____",
             "T.:......:.T",
             "T##..__..##T",
             "T:.RR__RR.:T",
             "T..HH__HH..T",
             "T....__....T",
             "T.:.S__..:.T",
             "T....__....T",
             "T*:..__.L:.T",
             "T:...__...:T",
             "TTTTT__TTTTT"]
# Road cells between the pump square and each side's gate.
CLOSED_STUB = {"top": [(x, y) for y in range(1, 6) for x in (5, 6)],
               "bottom": [(x, y) for y in range(11, 19) for x in (5, 6)],
               "left": [(x, y) for y in (8, 9) for x in range(1, 5)],
               "right": [(x, y) for y in (8, 9) for x in range(7, 11)]}
# What sets each town apart from the shared street plan: (x, y, tiles) written over it. Burin Landing
# has its harbour and pier, Platewick copper rock and lamps, Mordant Row its open baths, Rimeholt scree
# and ice rock, Ledgerholm fenced bank yards and flower beds, Proofgate the wood closing in. Houses
# grow or shrink by a column (the doors stay).
TOWN_LOOK = {
    "burin_landing": [(1, 5, "~~"), (1, 6, "~"), (1, 7, "~~"), (1, 8, "++++"), (1, 9, "++++"), (1, 10, "~~"), (1, 11, "~~")],
    "platewick": [(1, 1, "@@"), (9, 1, "@@"), (1, 18, "@"), (10, 18, "@"), (2, 7, "L"), (9, 10, "L"), (1, 17, ".:"),
                  (2, 12, "R"), (2, 13, "H")],
    "mordant_row": [(1, 15, "~~"), (1, 17, "~~"), (9, 17, "~~"), (1, 1, ".."), (9, 1, "..")],
    "rimeholt": [(1, 4, "::"), (9, 4, "::"), (1, 7, "@"), (10, 10, "@"), (1, 17, ":"), (1, 14, "::"), (9, 14, "::"),
                 (9, 2, "."), (9, 3, ".")],
    "ledgerholm": [(1, 7, "##"), (9, 10, "##"), (1, 1, "**"), (9, 1, "**"), (1, 18, "*"), (10, 18, "*"), (3, 10, "L"), (8, 7, "L"),
                   (9, 12, "R"), (9, 13, "H")],
    "proofgate": [(1, 1, "TT"), (9, 1, "TT"), (1, 18, "T"), (10, 18, "T"), (1, 10, "T"), (10, 7, "T"), (1, 17, ".."), (8, 17, "."),
                  (2, 2, "."), (2, 3, ".")],
}
BOATMAN = (3, 9)            # the mail boatman on the Burin Landing pier
BOAT_LANDING = (2, 9)       # where the mail boat sets you down
BOAT_LASTLAMP = (8, 16)     # the stop on the Lastlamp square (Vellmarch's last town)
SHOP = "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"
FINDS = ["max_tonic", "revival_leaf", "strong_tonic", "remedy", "wake_bell"]

TOWN_TEXT = {
    "burin_landing": {
        "motto": ("Burin Landing. All arrivals are recorded. Some are corrected.", "Burin Landing. Alle Ankünfte werden erfasst. Manche werden berichtigt."),
        "keeper": ("Dock Nurse Agathe: Lie down. The planks are old plates, so don't read them. Some of the confessions are catching.", "Hafenpflegerin Agathe: Leg dich hin. Die Planken sind alte Druckplatten, also lies sie nicht. Manche Geständnisse sind ansteckend."),
        "trader": ("Pier Clerk Hollis: Tonics, ink and stamps. The stamps are real. The ink is mostly real.", "Pierschreiber Hollis: Tränke, Tinte und Stempel. Die Stempel sind echt. Die Tinte ist größtenteils echt."),
        "folk": [("Plank Reader Ebbe: I read the pier backwards every morning. Yesterday I found my father's name. He swore he never confessed.", "Plankenleser Ebbe: Jeden Morgen lese ich den Pier rückwärts. Gestern fand ich den Namen meines Vaters. Er schwor, er habe nie gestanden."),
                 ("Crate Girl Mina: I unload the mail boat. Half the letters are love letters. The other half are the replies, forged.", "Kistenmädchen Mina: Ich lade das Postschiff aus. Die Hälfte der Briefe sind Liebesbriefe. Die andere Hälfte die Antworten, gefälscht."),
                 ("Old Harbourmaster Fenn: Wren Marlow came through here with a new face. Tipped me with the old one's money.", "Alter Hafenmeister Fenn: Wren Marlow kam hier durch, mit neuem Gesicht. Hat mir Trinkgeld mit dem Geld vom alten gegeben.")]},
    "platewick": {
        "motto": ("Platewick. Portraits while you wait. Wanted posters while you run.", "Platewick. Porträts zum Mitnehmen. Steckbriefe zum Weglaufen."),
        "keeper": ("Engraver's Nurse Ilka: Sit still. I patch people the way I patch plates: nobody notices the scratch until it prints.", "Graveurpflegerin Ilka: Sitz still. Ich flicke Leute, wie ich Platten flicke: Keiner sieht den Kratzer, bis er gedruckt ist."),
        "trader": ("Burin Seller Pell: Tonics and tools. A sharp burin opens many doors. Some of them are locked for good reason.", "Stichelhändler Pell: Tränke und Werkzeug. Ein scharfer Stichel öffnet viele Türen. Manche sind aus gutem Grund verschlossen."),
        "folk": [("Apprentice Tovi: I engraved my master's portrait. The Guild printed it on a wanted poster. Now I'm the master.", "Lehrling Tovi: Ich habe das Porträt meines Meisters gestochen. Die Gilde hat es auf einen Steckbrief gedruckt. Jetzt bin ich der Meister."),
                 ("Model Sanne: I sit for portraits. I've been hanged in effigy six times. Pays better than modelling.", "Modell Sanne: Ich sitze für Porträts. Ich wurde sechsmal in effigie gehängt. Zahlt besser als Modellstehen."),
                 ("Old Engraver Brom: Every face I ever cut is still in a drawer upstairs. Some of them still owe me.", "Alter Graveur Brom: Jedes Gesicht, das ich je gestochen habe, liegt oben in einer Schublade. Manche schulden mir noch was.")]},
    "mordant_row": {
        "motto": ("Mordant Row. Breathe through cloth. Bring your own cloth.", "Mordant Row. Atme durch ein Tuch. Tuch bitte selbst mitbringen."),
        "keeper": ("Bath Nurse Doro: Rest here. The fumes don't reach this bench. Mostly.", "Bäderpflegerin Doro: Ruh dich hier aus. Die Dämpfe reichen nicht bis zu dieser Bank. Meistens."),
        "folk": [("Vat Stirrer Klaas: Lost my eyebrows the first day, my sense of smell the second. Lost my wife on the third, but that was the cards.", "Bottichrührer Klaas: Am ersten Tag die Augenbrauen verloren, am zweiten den Geruchssinn. Am dritten meine Frau, aber das waren die Karten."),
                 ("Cure Seller Ottla: Mavet's cure works wonders. You only need it because of Mavet. Don't say that loudly.", "Heilmittelverkäuferin Ottla: Mavets Heilmittel wirkt Wunder. Man braucht es nur wegen Mavet. Sag das nicht laut."),
                 ("Widow Grete: My husband fell in the big bath. They etched his name on the rim. Took four seconds.", "Witwe Grete: Mein Mann ist ins große Bad gefallen. Sie haben seinen Namen in den Rand geätzt. Hat vier Sekunden gedauert.")]},
    "rimeholt": {
        "motto": ("Rimeholt. The frost writes on every window. Read at your own risk.", "Rimeholt. Der Frost schreibt an jedes Fenster. Lesen auf eigene Gefahr."),
        "keeper": ("Hearth Nurse Signy: Warm your hands. The Guild owns the firewood, so don't warm them too long.", "Herdpflegerin Signy: Wärm dir die Hände. Das Brennholz gehört der Gilde, also nicht zu lange."),
        "trader": ("Fur Trader Joris: Tonics, mittens, debts. The mittens are cheap. The debts come free with them.", "Pelzhändler Joris: Tränke, Fäustlinge, Schulden. Die Fäustlinge sind billig. Die Schulden gibt's gratis dazu."),
        "folk": [("Window Scraper Lene: I scrape the warnings off the windows before anyone reads them. The Guild pays per window.", "Fensterkratzerin Lene: Ich kratze die Warnungen von den Fenstern, bevor sie jemand liest. Die Gilde zahlt pro Fenster."),
                 ("Debtor Aksel: My house is frozen and my loan is not. Funny how cold works.", "Schuldner Aksel: Mein Haus ist eingefroren und mein Kredit nicht. Komisch, wie Kälte funktioniert."),
                 ("Grandmother Ingrid: The frost wrote my name on my window last winter. I'm still here. The frost is patient.", "Großmutter Ingrid: Letzten Winter schrieb der Frost meinen Namen an mein Fenster. Ich bin noch da. Der Frost ist geduldig.")]},
    "ledgerholm": {
        "motto": ("Ledgerholm. Two banks, one street, no witnesses.", "Ledgerholm. Zwei Banken, eine Straße, keine Zeugen."),
        "keeper": ("Bank Nurse Rasmine: Rest, then sign here. And here. The second one says you rested.", "Bankpflegerin Rasmine: Ruh dich aus, dann unterschreib hier. Und hier. Das zweite bestätigt, dass du geruht hast."),
        "trader": ("Counting Clerk Mads: Tonics at today's rate. Tomorrow's rate is better, but you might not be here.", "Zählschreiber Mads: Tränke zum heutigen Kurs. Der morgige ist besser, aber vielleicht bist du dann nicht mehr hier."),
        "folk": [("Forger Ulla: I copy banknotes on weekdays and sing in the choir on Sundays. The bankers sing bass.", "Fälscherin Ulla: Werktags kopiere ich Banknoten, sonntags singe ich im Chor. Die Bankiers singen Bass."),
                 ("Junior Banker Kaspar: My job is to tell the two ledgers apart. I was hired because I can't.", "Junger Bankier Kaspar: Mein Job ist, die zwei Bücher auseinanderzuhalten. Eingestellt wurde ich, weil ich es nicht kann."),
                 ("Old Auditor Hedvig: I audited Ottoline once. She audited me back. Now I live here, on a pension I didn't earn.", "Alte Prüferin Hedvig: Ich habe Ottoline einmal geprüft. Sie hat zurückgeprüft. Jetzt lebe ich hier, von einer Rente, die ich nicht verdient habe.")]},
    "proofgate": {
        "motto": ("Proofgate. Nothing leaves unstamped. Nothing.", "Proofgate. Nichts geht ohne Stempel hinaus. Gar nichts."),
        "keeper": ("Press Nurse Valda: Rest. If you wake up stamped, that's routine. If you wake up printed, complain.", "Pressenpflegerin Valda: Ruh dich aus. Wenn du gestempelt aufwachst, ist das Routine. Wenn du gedruckt aufwachst, beschwer dich."),
        "folk": [("Stamp Boy Egil: I stamp everything that leaves. Letters, crates, coffins. The coffins get two stamps.", "Stempeljunge Egil: Ich stempel alles, was hinausgeht. Briefe, Kisten, Särge. Särge kriegen zwei Stempel."),
                 ("Proofreader Malin: I read every map before it prints. Grisel moves the Rifts after I sign off.", "Korrektorin Malin: Ich lese jede Karte, bevor sie gedruckt wird. Grisel verschiebt die Risse, nachdem ich abgezeichnet habe."),
                 ("Old Pressman Torvald: The edge of the map is just past the last press. I went to look once. They printed me coming back.", "Alter Drucker Torvald: Der Kartenrand liegt gleich hinter der letzten Presse. Ich wollte einmal nachsehen. Sie haben mich auf dem Rückweg gedruckt.")]},
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
    "burin_landing": [
        ("post_office", ("Post Office", "Postamt"), "postmaster",
         ("Postmaster Arvo: Your letter? Opened, read, resealed. Standard service.", "Postmeister Arvo: Dein Brief? Geöffnet, gelesen, wieder versiegelt. Normaler Service.")),
        ("customs", ("Customs Shed", "Zollschuppen"), "customs",
         ("Customs Clerk Britt: Declare your goods. Declare your name. We'll decide which one is real.", "Zollschreiberin Britt: Waren angeben. Namen angeben. Wir entscheiden, was davon echt ist.")),
        ("net_loft", ("Net Loft", "Netzboden"), "netter",
         ("Net Mender Joa: I fish the old plates out of the harbour. They make good planks and bad evidence.", "Netzflicker Joa: Ich fische die alten Platten aus dem Hafen. Sie geben gute Planken und schlechte Beweise ab.")),
        ("tavern", ("Plate Tavern", "Plattenschenke"), "innkeeper",
         ("Innkeeper Rune: Sailors drink here and sign their names on the wall. Wren signed it three times, three names.", "Wirt Rune: Seeleute trinken hier und schreiben ihre Namen an die Wand. Wren hat dreimal unterschrieben, drei Namen.")),
    ],
    "platewick": [
        ("studio", ("Portrait Studio", "Porträtatelier"), "artist",
         ("Portraitist Lisbet: Hold still. Smile. Don't smile, the Guild prefers the wanted posters grim.", "Porträtistin Lisbet: Halt still. Lächeln. Nicht lächeln, die Gilde mag die Steckbriefe finster.")),
        ("plate_store", ("Plate Store", "Plattenlager"), "keeper",
         ("Plate Keeper Ove: Ten thousand copper faces. One of them is yours already. Don't ask who ordered it.", "Plattenwart Ove: Zehntausend Kupfergesichter. Eins davon ist schon deins. Frag nicht, wer es bestellt hat.")),
        ("guild_hall", ("Gravers' Guild Hall", "Gildenhaus der Graveure"), "elder",
         ("Guild Warden Henrike: The Guild protects its members. From each other, mostly.", "Gildenwartin Henrike: Die Gilde schützt ihre Mitglieder. Meistens voreinander.")),
        ("print_shop", ("Print Shop", "Druckerei"), "printer",
         ("Printer Lasse: We print news in the morning and corrections at night. The corrections sell better.", "Drucker Lasse: Morgens drucken wir Nachrichten, abends Berichtigungen. Die Berichtigungen verkaufen sich besser.")),
    ],
    "mordant_row": [
        ("bath_house", ("Bath House", "Badehaus"), "attendant",
         ("Bath Attendant Wilma: Towel? It's acid-proof. You aren't.", "Badewärterin Wilma: Handtuch? Es ist säurefest. Du nicht.")),
        ("apothecary", ("Apothecary", "Apotheke"), "elder",
         ("Apothecary Gerold: Mavet's cure, three coins a bottle. The bottle is worth two of them.", "Apotheker Gerold: Mavets Heilmittel, drei Münzen die Flasche. Die Flasche ist zwei davon wert.")),
        ("well_house", ("Well House", "Brunnenhaus"), "keeper",
         ("Well Keeper Tamm: Don't drink from the well. Don't ask why. Definitely don't ask Mavet why.", "Brunnenwart Tamm: Trink nicht aus dem Brunnen. Frag nicht, warum. Und frag auf keinen Fall Mavet, warum.")),
        ("vat_store", ("Vat Store", "Bottichlager"), "stirrer",
         ("Vat Keeper Ronja: Empty vats in the back, full vats in front. The middle ones are complicated.", "Bottichwartin Ronja: Leere Bottiche hinten, volle vorne. Die mittleren sind kompliziert.")),
    ],
    "rimeholt": [
        ("debt_office", ("Debt Office", "Schuldenamt"), "clerk",
         ("Debt Clerk Gunnar: Every house in town is in this drawer. Yours too, if you stay the night.", "Schuldschreiber Gunnar: Jedes Haus der Stadt liegt in dieser Schublade. Deins auch, wenn du über Nacht bleibst.")),
        ("woodshed", ("Woodshed", "Holzschuppen"), "woodcutter",
         ("Woodcutter Siv: The Guild owns the trees, the axes and the cold. I own the blisters.", "Holzfällerin Siv: Der Gilde gehören die Bäume, die Äxte und die Kälte. Mir gehören die Blasen.")),
        ("glass_room", ("Window Room", "Fensterstube"), "glazier",
         ("Glazier Ivar: I sell new windows. The frost writes on them anyway. Faster, if you ask me.", "Glaser Ivar: Ich verkaufe neue Fenster. Der Frost schreibt trotzdem drauf. Schneller, wenn du mich fragst.")),
        ("hearth_hall", ("Hearth Hall", "Herdhalle"), "elder",
         ("Hearth Keeper Asta: One fire for the whole town. The Guild decides who sits nearest.", "Herdhüterin Asta: Ein Feuer für die ganze Stadt. Die Gilde entscheidet, wer am nächsten sitzt.")),
    ],
    "ledgerholm": [
        ("bank", ("First Bank", "Erste Bank"), "banker",
         ("Banker Leopold: We keep the true ledger. The other bank keeps the other true ledger.", "Bankier Leopold: Wir führen das wahre Buch. Die andere Bank führt das andere wahre Buch.")),
        ("forgery", ("Back Room", "Hinterzimmer"), "forger",
         ("Forger Agnete: I don't forge. I restore documents to what they should have said.", "Fälscherin Agnete: Ich fälsche nicht. Ich stelle Dokumente wieder her, wie sie hätten lauten sollen.")),
        ("choir_loft", ("Choir Loft", "Chorempore"), "singer",
         ("Choirmaster Edvin: Bankers and forgers sing together on Sundays. The harmony is suspicious.", "Chorleiter Edvin: Sonntags singen Bankiers und Fälscher zusammen. Die Harmonie ist verdächtig.")),
        ("archive", ("Ledger Archive", "Bucharchiv"), "elder",
         ("Archivist Solveig: Every book in here has a twin. Nobody knows which twin is the liar.", "Archivarin Solveig: Jedes Buch hier hat einen Zwilling. Keiner weiß, welcher Zwilling lügt.")),
    ],
    "proofgate": [
        ("stamp_hall", ("Stamp Hall", "Stempelhalle"), "stamper",
         ("Chief Stamper Birger: Approved, denied, deceased. Three stamps. I use the third one most.", "Oberstempler Birger: Genehmigt, abgelehnt, verstorben. Drei Stempel. Den dritten benutze ich am meisten.")),
        ("proof_room", ("Proof Room", "Korrekturstube"), "reader",
         ("Proof Reader Elin: I mark the errors in red. Grisel prints them anyway and calls them features.", "Korrektorin Elin: Ich markiere die Fehler rot. Grisel druckt sie trotzdem und nennt sie Besonderheiten.")),
        ("map_vault", ("Map Vault", "Kartengewölbe"), "keeper",
         ("Map Keeper Halvard: Every map of Quillmarch, printed here. Every Rift on them, put there by hand.", "Kartenwart Halvard: Jede Karte von Quillmarch, hier gedruckt. Jeder Riss darauf, von Hand eingesetzt.")),
        ("last_inn", ("Last Inn", "Letzte Herberge"), "innkeeper",
         ("Innkeeper Dagny: Last bed before the edge of the map. Pay in advance. Nobody pays on the way back.", "Wirtin Dagny: Letztes Bett vor dem Kartenrand. Zahl im Voraus. Auf dem Rückweg zahlt keiner.")),
    ],
}
SPRITE = {"elder": "elder", "postmaster": "elder", "banker": "elder"}


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


# folk: (home cell, facing, dusk cell by the pump, facing)
FOLK_PLACES = [((1, 4), "right", (4, 9), "right"), ((10, 14), "left", (6, 9), "left"), ((2, 16), "right", (7, 8), "left")]


def gate_block(x, y, flag):
    return {"x": x, "y": y, "open_flag": flag, "closed": "#"}


def town(mid):
    t = TOWNS[mid]
    rows = list(TOWN_ROWS)
    gates = GATES[mid]
    for side, (cells, _, _) in SIDES.items():
        if side not in gates:
            for x, y in cells:
                rows[y] = rows[y][:x] + "T" + rows[y][x + 1:]
            # No road runs up to a closed side: its stub becomes a yard.
            for x, y in CLOSED_STUB[side]:
                rows[y] = rows[y][:x] + "." + rows[y][x + 1:]
    for x, y, tiles in TOWN_LOOK[mid]:
        rows[y] = rows[y][:x] + tiles + rows[y][x + len(tiles):]
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
    if mid == "ledgerholm":
        # The Showcase (era function showcase, Era III, docs/ERA_FUNCTIONS.md).
        npcs.append(npc("showcase_host", 8, 10, "down", text(mid + "_showcase_host", {"lines": lines(
            ("Stagewright Pell: The Showcase! No blood, no Rifts, just arts and applause. The judges are honest. Mostly. One owes me money.",
             "Bühnenmeister Pell: Die Schau! Kein Blut, keine Risse, nur Techniken und Applaus. Die Jury ist ehrlich. Meistens. Einer schuldet mir Geld.")),
            "action": "showcase"}), "villager"))
    if mid == "burin_landing":
        npcs.append(npc("boatman", BOATMAN[0], BOATMAN[1], "left", boat_text(), "elder"))
        npcs.append(npc("wren", 9, 4, "down", wren_text(), "tamer_f"))
    m = {"name": t["name"], "biome": "town", "backdrop": "field", "outdoor": True, "heal_point": [5, 9], "rows": rows,
         "warps": warps, "npcs": npcs, "signs": [{"x": 4, "y": 15, "dialogue": sign}], "blocks": blocks,
         "secrets": [secret(0, 13, FINDS[0], "find_%s_1" % mid), secret(11, 16, FINDS[1], "find_%s_2" % mid),
                     secret(11, 4, FINDS[2], "find_%s_3" % mid, 2)],
         "square": [5, 8]}
    add(mid, m)


def boat_text():
    return text("boatman", {"lines": [sheet(SHEET["arrival"]["text"])], "action": "transit " + LINE})


def wren_text():
    text("wren_after", [sheet(FIRST["betrayal"]["text"])] + lines(
        ("Wren: Don't sulk. The Guild would have known anyway. I just made sure they paid me for it.", "Wren: Schmoll nicht. Die Gilde hätte es sowieso erfahren. Ich habe nur dafür gesorgt, dass sie mich dafür bezahlt.")))
    return text("wren", {"if": {"not_flag": FIRST["sets"]}, "else": "wren_after",
                         "lines": [sheet(FIRST["text"])] + lines(
                             ("Wren Marlow: First job: the Bath Rift above Mordant Row. North through Platewick, up the Mordant Steps.", "Wren Marlow: Erster Auftrag: der Badriss oberhalb von Mordant Row. Nach Norden durch Platewick, die Mordant-Stufen hinauf."),
                             ("Wren Marlow: Same deal as Vellmarch. You work, I talk, we split it. Unevenly.", "Wren Marlow: Derselbe Handel wie in Vellmarch. Du arbeitest, ich rede, wir teilen. Ungleich.")),
                         "action": "set_flag " + FIRST["sets"]})


def place_arrival(place, from_town, i):
    """Arrival cell on [place] when coming from [from_town] through gate cell i, and the facing."""
    if place in ROUTES:
        top = ROUTES[place]["links"][0] == from_town
        return ((5 + i, 1), "down") if top else ((5 + i, ROUTE_H - 2), "up")
    return (5 + i, RIFT_H - 2), "up"


# --- Roads: lanes between stone walls, scree yards, fern verges; the marsh keeps its water -----
ROUTE_ROWS = ["TTTTT__TTTTT",
              "T@@..__.AAAT",
              "T@@...__AAAT",
              "T.....__...T",
              "TBB@@@@_@@.T",
              "TBB@@@@_@@.T",
              "T....____..T",
              "T@@@._..CCCT",
              "T@@@._..CCCT",
              "T...._.....T",
              "TAA.._@@@@@T",
              "TAA..____..T",
              "T@@@...._..T",
              "T@@@.BB._..T",
              "T....BB.__.T",
              "TCCC....._.T",
              "TCCC@@@@._.T",
              "T...@@@@._.T",
              "T..______..T",
              "T.._..AAA..T",
              "T@@_..AAA@@T",
              "T@@_.....@@T",
              "T..__......T",
              "T....__.BB.T",
              "T.....__BB.T",
              "TTTTT__TTTTT"]
MARSH = {"smudge_marsh"}
# The rest of Quillmarch's own kinds in the road tables: (species, sheet slot index for the ground).
# Weights follow the rarity band (SpirlingData.WEIGHT_BANDS).
WILD = {
    "drypoint_lane": [("Platewig", 1), ("Burrin", 1), ("Drypup", 1), ("Veskarion", 0), ("Dryhound", 1), ("Platemarshal", 1)],
    "mordant_steps": [("Corrodent", 0), ("Mordantoad", 0), ("Vatreeve", 1), ("Fizzlet", 2), ("Corrodile", 0), ("Vitriolus", 1),
                      ("Mordantyrant", 0), ("Vatbaron", 1), ("Corrodrake", 2)],
    "hoarfrost_moor": [("Hoarling", 0), ("Rimelynx", 1), ("Hoarstag", 2), ("Rimesovereign", 1), ("Hoarmonarch", 0)],
    "gravers_causeway": [("Copperling", 1), ("Copperclad", 1), ("Burrowgraver", 1), ("Canalurk", 0), ("Siltaroth", 0),
                         ("Burringrand", 1), ("Copperpatriarch", 1), ("Nibravure", 2), ("Cindravax", 2)],
    "rimeglass_pass": [("Sleetowl", 0), ("Gelidfin", 1), ("Sleetcowl", 2), ("Gelidray", 1), ("Sleetsage", 0), ("Glacilisk", 1),
                       ("Gelidmonarch", 1), ("Filigravure", 2)],
    "stamp_road": [("Stampet", 1), ("Quilmoth", 2), ("Stamphorn", 1), ("Pressbug", 2), ("Platewing", 1), ("Blotkin", 0),
                   ("Quilmothra", 2), ("Stampcolossus", 1), ("Pressbeetle", 2), ("Blotgrimm", 0), ("Quilmothane", 1), ("Fizzgrove", 0)],
    "smudge_marsh": [("Smudgel", 0), ("Smudgeworm", 1), ("Forgefly", 2), ("Frostfoil", 2), ("Smudgewyrm", 0), ("Canalurker", 1),
                     ("Forgeflare", 2)],
}
WILD_WEIGHT = {"common": 25, "uncommon": 12, "shy": 4}
# Two Wayfarers per road: (key, title, team, cell, facing, talk, intro, defeat); team names come from the road's table.
ROUTE_TEXT = {
    "drypoint_lane": [
        ("scratcher", ("Plate Scratcher Arne", "Plattenkratzer Arne"), ["Vesk", "Drypup"], (10, 9), "left",
         ("Arne: I scratch plates by hand, no acid. Slower, cleaner, and nobody can prove which hand.", "Arne: Ich ritze Platten von Hand, ohne Säure. Langsamer, sauberer, und keiner kann beweisen, welche Hand."),
         ("Arne: Your face would make a good plate. Let me rough it up first.", "Arne: Dein Gesicht gäbe eine gute Platte. Lass mich es erst aufrauen."),
         ("Arne: Clean lines. Annoying.", "Arne: Saubere Linien. Ärgerlich.")),
        ("courier", ("Courier Liv", "Kurierin Liv"), ["Platewig", "Drypup", "Platemarshal"], (2, 19), "right",
         ("Liv: I carry the Guild's letters. I read them first. It's in my contract, the part they didn't read.", "Liv: Ich trage die Briefe der Gilde. Ich lese sie vorher. Steht in meinem Vertrag, in dem Teil, den sie nicht gelesen haben."),
         ("Liv: One of the letters is about you. Want to fight for it?", "Liv: Einer der Briefe handelt von dir. Willst du darum kämpfen?"),
         ("Liv: Fine. It says you're late. You are.", "Liv: Schön. Da steht, dass du zu spät bist. Bist du.")),
    ],
    "mordant_steps": [
        ("fumer", ("Fume Bottler Tilla", "Dampfabfüllerin Tilla"), ["Cindrik", "Corrodent"], (10, 9), "left",
         ("Tilla: I bottle the fumes for Mavet's cure. Then I take the cure. It's a closed loop.", "Tilla: Ich fülle die Dämpfe für Mavets Heilmittel ab. Dann nehme ich das Heilmittel. Ein geschlossener Kreislauf."),
         ("Tilla: Take a deep breath. Go on.", "Tilla: Atme tief ein. Na los."),
         ("Tilla: You held your breath. Cheat.", "Tilla: Du hast die Luft angehalten. Betrüger.")),
        ("stepcounter", ("Step Etcher Gisli", "Stufenätzer Gisli"), ["Mordling", "Mordantoad", "Vatreeve"], (2, 19), "right",
         ("Gisli: Every step is etched with the name of someone who slipped. I'm running out of steps.", "Gisli: In jede Stufe ist der Name von jemandem geätzt, der ausgerutscht ist. Mir gehen die Stufen aus."),
         ("Gisli: There's a blank step just here. Shall we fill it?", "Gisli: Genau hier ist eine leere Stufe. Sollen wir sie füllen?"),
         ("Gisli: Still blank. Pity.", "Gisli: Immer noch leer. Schade.")),
    ],
    "hoarfrost_moor": [
        ("sledger", ("Sledger Runa", "Schlittenführerin Runa"), ["Rimekit", "Hoarling"], (10, 9), "left",
         ("Runa: I haul the frozen out of the moor every spring. Some of them owe the Guild money. They still do.", "Runa: Jeden Frühling ziehe ich die Erfrorenen aus dem Moor. Manche schulden der Gilde Geld. Immer noch."),
         ("Runa: My sledge has room for one more.", "Runa: Auf meinem Schlitten ist noch Platz für einen."),
         ("Runa: Not today. The sledge is disappointed.", "Runa: Heute nicht. Der Schlitten ist enttäuscht.")),
        ("hoarwatch", ("Moor Watcher Eskil", "Moorwächter Eskil"), ["Vesk", "Rimelynx", "Filigrin"], (2, 19), "right",
         ("Eskil: The frost writes on the stones out here too. Mostly it writes: turn back.", "Eskil: Auch hier draußen schreibt der Frost auf die Steine. Meistens schreibt er: Kehr um."),
         ("Eskil: You didn't turn back. Now you get me.", "Eskil: Du bist nicht umgekehrt. Jetzt kriegst du mich."),
         ("Eskil: Go on, then. The stones will remember you.", "Eskil: Dann geh. Die Steine werden sich an dich erinnern.")),
    ],
    "gravers_causeway": [
        ("graver", ("Guild Graver Osk", "Gildengraveur Osk"), ["Copperling", "Burrowgraver"], (10, 9), "left",
         ("Osk: The Guild sends me to check who walks the causeway. Then it sends someone else to check me.", "Osk: Die Gilde schickt mich, um zu sehen, wer den Damm entlanggeht. Dann schickt sie jemand anderen, um mich zu prüfen."),
         ("Osk: You're not on my list. Let's fix that.", "Osk: Du stehst nicht auf meiner Liste. Ändern wir das."),
         ("Osk: You're on it now. Top line.", "Osk: Jetzt stehst du drauf. Oberste Zeile.")),
        ("canalman", ("Canal Dredger Bo", "Kanalbaggerer Bo"), ["Siltby", "Canalurk", "Siltaroth"], (2, 19), "right",
         ("Bo: I dredge the canal for lost plates. I find more lost people. They pay worse.", "Bo: Ich baggere den Kanal nach verlorenen Platten aus. Ich finde mehr verlorene Leute. Die zahlen schlechter."),
         ("Bo: You'd sink nicely. Let's test it.", "Bo: Du würdest schön sinken. Testen wir das."),
         ("Bo: Floats. Huh.", "Bo: Schwimmt. Hm.")),
    ],
    "rimeglass_pass": [
        ("iceguide", ("Ice Guide Tyra", "Eisführerin Tyra"), ["Veskara", "Sleetowl"], (10, 9), "left",
         ("Tyra: The pass is glass. I charge by the slip.", "Tyra: Der Pass ist Glas. Ich rechne pro Ausrutscher ab."),
         ("Tyra: You haven't slipped yet. Let me help.", "Tyra: Du bist noch nicht ausgerutscht. Ich helf dir."),
         ("Tyra: Steady feet. Bad for business.", "Tyra: Sichere Füße. Schlecht fürs Geschäft.")),
        ("collector", ("Debt Collector Holm", "Schuldeneintreiber Holm"), ["Glacilet", "Gelidfin", "Gelidray"], (2, 19), "right",
         ("Holm: I collect for the Guild up here. Frozen people can't run, which is the whole business plan.", "Holm: Hier oben treibe ich für die Gilde ein. Erfrorene können nicht weglaufen, das ist der ganze Geschäftsplan."),
         ("Holm: You owe the Guild for the air you breathe up here.", "Holm: Du schuldest der Gilde die Luft, die du hier oben atmest."),
         ("Holm: Paid in full. I'll invent something else.", "Holm: Voll bezahlt. Ich erfinde etwas anderes.")),
    ],
    "stamp_road": [
        ("stamper", ("Road Stamper Vigdis", "Straßenstemplerin Vigdis"), ["Quilmoth", "Blotkin"], (10, 9), "left",
         ("Vigdis: Everyone on this road gets a stamp. Arrival, departure, or disappearance.", "Vigdis: Jeder auf dieser Straße kriegt einen Stempel. Ankunft, Abreise oder Verschwinden."),
         ("Vigdis: Hold out your hand. Which stamp do you want?", "Vigdis: Halt die Hand hin. Welchen Stempel willst du?"),
         ("Vigdis: Departure, then. For now.", "Vigdis: Abreise also. Fürs Erste.")),
        ("pressrunner", ("Press Runner Ole", "Pressenläufer Ole"), ["Vatrat", "Stampet", "Stamphorn"], (2, 19), "right",
         ("Ole: I run fresh prints to Proofgate before the ink dries. Grisel likes them smudged where it matters.", "Ole: Ich bringe frische Drucke nach Proofgate, bevor die Tinte trocknet. Grisel mag sie verschmiert, wo es zählt."),
         ("Ole: You're in today's print. Wrong side of the page.", "Ole: Du bist im heutigen Druck. Auf der falschen Seite."),
         ("Ole: I'll run a correction.", "Ole: Ich bringe eine Berichtigung.")),
    ],
    "smudge_marsh": [
        ("blotter", ("Ink Blotter Sigrun", "Tintenlöscherin Sigrun"), ["Siltby", "Smudgel"], (10, 9), "left",
         ("Sigrun: The presses dump their spoiled ink here. The marsh drinks it and remembers every word.", "Sigrun: Die Pressen kippen ihre verdorbene Tinte hier ab. Der Sumpf trinkt sie und merkt sich jedes Wort."),
         ("Sigrun: The marsh just whispered your name. Let's find out why.", "Sigrun: Der Sumpf hat gerade deinen Namen geflüstert. Finden wir heraus, warum."),
         ("Sigrun: It whispers louder now.", "Sigrun: Jetzt flüstert er lauter.")),
        ("smuggler", ("Smuggler Kettil", "Schmuggler Kettil"), ["Smudgeworm", "Siltby", "Canalurker"], (2, 19), "right",
         ("Kettil: I take unstamped goods round Proofgate through the marsh. Unstamped people too, at a premium.", "Kettil: Ich bringe ungestempelte Ware durch den Sumpf um Proofgate herum. Ungestempelte Leute auch, gegen Aufpreis."),
         ("Kettil: You saw my route. Now you pay the toll.", "Kettil: Du hast meine Route gesehen. Jetzt zahlst du den Zoll."),
         ("Kettil: Keep quiet and I'll keep you off the map.", "Kettil: Halt den Mund, und ich halte dich von der Karte.")),
    ],
}


def slot_species(s):
    return s.get("species") or s["stand_in"]


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
    return crew


def route(mid):
    r = ROUTES[mid]
    rows = list(ROUTE_ROWS)
    if mid in MARSH:
        rows = [row.replace("@", "~") for row in rows]
    for letter, slot in zip("ABC", r["slots"]):
        rows = [row.replace(letter, GROUND[slot["ground"]][0]) for row in rows]
    lo, hi = r["ring"]
    spawns = []
    for slot in r["slots"]:
        spawns.append({"species": slot_species(slot), "min": lo, "max": hi, "weight": slot["weight"], "ground": GROUND[slot["ground"]][1]})
    for sp, gi in WILD[mid]:
        if sp not in SPECIES or SPECIES[sp].get("region") != REGION or SPECIES[sp].get("rarity") not in WILD_WEIGHT:
            raise SystemExit("%s: %s is not a wild Quillmarch kind" % (mid, sp))
        spawns.append({"species": sp, "min": lo, "max": hi, "weight": WILD_WEIGHT[SPECIES[sp]["rarity"]],
                       "ground": GROUND[r["slots"][gi]["ground"]][1]})
    ENCOUNTERS[mid] = {"rate": 0.10 if mid in MARSH else 0.12, "spawns": spawns}
    table = {s["species"] for s in spawns}
    a, b = r["links"]
    warps = []
    for i in range(2):
        (tx, ty), facing = arrival_in_town(a, mid, i)
        warps.append(warp(5 + i, 0, a, tx, ty, facing))
        (tx, ty), facing = arrival_in_town(b, mid, i)
        warps.append(warp(5 + i, ROUTE_H - 1, b, tx, ty, facing))
    npcs = []
    for n, (key, title, names, (x, y), facing, talk, intro, defeat) in enumerate(ROUTE_TEXT[mid]):
        for s in names:
            if s not in table:
                raise SystemExit("%s %s: %s is not in the road's table" % (mid, key, s))
        crew = check_team(mid + " " + key, [{"species": s, "level": hi - (1 if i == 0 else 0)} for i, s in enumerate(names)])
        npcs.append(npc(key, x, y, facing, text("%s_%s" % (mid, key), lines(talk)), "villager" if n else "ranger",
                        trainer=tr(*title), intro=text("%s_%s_intro" % (mid, key), lines(intro)),
                        defeat=text("%s_%s_defeat" % (mid, key), lines(defeat)), money=hi * 40, team=crew))
    m = {"name": r["name"], "biome": "marsh" if mid in MARSH else "route", "backdrop": "lake" if mid in MARSH else "ridge",
         "outdoor": True, "encounters": mid, "rows": rows, "warps": warps, "npcs": npcs, "signs": [],
         "secrets": [secret(0, 9, FINDS[3], "find_%s_1" % mid), secret(11, 11, FINDS[4], "find_%s_2" % mid),
                     secret(0, 18, FINDS[0], "find_%s_3" % mid), secret(11, 23, FINDS[2], "find_%s_4" % mid)]}
    add(mid, m)


def arrival_in_town(town_id, place, i):
    cells, facing = town_arrival(town_id, place)
    return cells[i], facing


# --- Rifts: etched hollows under the towns ----------------------------------------------------
RIFT_ROWS = ["TTTTTTTTTTTT",
             "TT::.XX.::TT",
             "T::.......:T",
             "T:......T_.T",
             "T..o.....T_T",
             "T.......ST_T",
             "T@@@....TT_T",
             "T@@@....:T_T",
             "T........T_T",
             "T.X......T_T",
             "T....@@..T_T",
             "T....@@..T_T",
             "TTTT..TTTT_T",
             "T........T_T",
             "T..::....T_T",
             "TTT..TTTTT_T",
             "T........T_T",
             "T........T_T",
             "TTTT..TTTT.T",
             "T..........T",
             "T.X......X.T",
             "TTTTT..TTTTT"]
RULES = {"bath_rift": "ember_pulse", "rime_rift": "undertow", "ledger_rift": "night_dark", "press_rift": "ember_pulse"}
RIFT_TEXT = {
    "bath_rift": (("The acid has eaten the floor down to an older floor, and that one down to bone.", "Die Säure hat den Boden bis auf einen älteren Boden zerfressen, und den bis auf die Knochen."),
                  (("Bath Acolyte Hjalmar", "Bad-Akolyth Hjalmar"), ("Hjalmar: Mavet pays me in cure. I've been cured eleven times this week.", "Hjalmar: Mavet zahlt mich in Heilmittel. Diese Woche wurde ich elfmal geheilt."),
                   ("Hjalmar: Breathe in. The first lungful is free.", "Hjalmar: Einatmen. Der erste Atemzug ist gratis."),
                   ("Hjalmar: Mavet's at the bottom. She's bottling the view.", "Hjalmar: Mavet ist ganz unten. Sie füllt die Aussicht ab."))),
    "rime_rift": (("Frost covers every wall with warnings. Every one of them has your name in it.", "Frost bedeckt jede Wand mit Warnungen. In jeder steht dein Name."),
                  (("Rime Acolyte Solrun", "Reif-Akolythin Solrun"), ("Solrun: Quenby reads the frost for the Guild. I read it for Quenby. Nobody reads it for me.", "Solrun: Quenby liest den Frost für die Gilde. Ich lese ihn für Quenby. Für mich liest ihn keiner."),
                   ("Solrun: Your warning says: stop here. I'm the stop.", "Solrun: Deine Warnung sagt: Halt hier. Ich bin der Halt."),
                   ("Solrun: The warning was wrong. That never happens.", "Solrun: Die Warnung war falsch. Das passiert nie."))),
    "ledger_rift": (("Pages drift in the dark like snow. Each one is a debt, and each debt has two totals.", "Seiten treiben im Dunkeln wie Schnee. Jede ist eine Schuld, und jede Schuld hat zwei Summen."),
                    (("Ledger Acolyte Bertram", "Buch-Akolyth Bertram"), ("Bertram: I keep Ottoline's third ledger. The one for the other two.", "Bertram: Ich führe Ottolines drittes Buch. Das für die anderen beiden."),
                     ("Bertram: Let's settle your account.", "Bertram: Begleichen wir dein Konto."),
                     ("Bertram: Balanced. I'll unbalance it later.", "Bertram: Ausgeglichen. Ich bringe es später wieder durcheinander."))),
    "press_rift": (("A press the size of a church prints the map of Quillmarch, one Rift at a time.", "Eine Presse so groß wie eine Kirche druckt die Karte von Quillmarch, einen Riss nach dem anderen."),
                   (("Press Acolyte Ylva", "Pressen-Akolythin Ylva"), ("Ylva: Grisel prints the Rifts and then sends people to seal them. Steady work for everyone.", "Ylva: Grisel druckt die Risse und schickt dann Leute, die sie versiegeln. Feste Arbeit für alle."),
                    ("Ylva: You're the last job on the run. Let's see if you print clean.", "Ylva: Du bist der letzte Auftrag im Lauf. Mal sehen, ob du sauber druckst."),
                    ("Ylva: Clean print. Grisel will hate it.", "Ylva: Sauberer Druck. Grisel wird es hassen."))),
}


def rift(mid):
    rf = RIFTS[mid]
    w = WARDENS[mid]
    key = "v3_" + mid[:-5]
    town_id = rf["near"]
    motto, (aname, talk, intro, defeat) = RIFT_TEXT[mid]
    text(mid + "_spring", {"lines": lines(("Clear water drips from an etched spout. It tastes faintly of copper.", "Klares Wasser tropft aus einer geätzten Tülle. Es schmeckt leicht nach Kupfer."),
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
    pair = next((x, y) for i, x in enumerate(crew) for y in crew[i + 1:]
                if len(set(SPECIES[x["species"]]["elements"]) | set(SPECIES[y["species"]]["elements"])) <= 3)
    acolyte_crew = check_team(mid, [dict(pair[0], level=w["ring"] - 1), dict(pair[1], level=w["ring"] - 1)])
    acolyte = npc("acolyte", 7, 17, "left", text(mid + "_acolyte", lines(talk)), "warden", trainer=tr(*aname),
                  intro=text(mid + "_acolyte_intro", lines(intro)), defeat=text(mid + "_acolyte_defeat", lines(defeat)),
                  money=(w["ring"] - 1) * 40, team=acolyte_crew)
    back, facing = town_arrival(town_id, mid)
    m = {"name": rf["name"], "biome": "rift", "backdrop": "voice", "heal_point": [3, 5], "rows": list(RIFT_ROWS),
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


def pos_of(mid):
    if mid in RIFTS:
        return RIFT_POS[mid]
    return (TOWNS.get(mid) or ROUTES.get(mid))["pos"]


def layout_lines():
    out = []
    for mid in list(TOWNS) + list(ROUTES) + list(RIFTS):
        pos = pos_of(mid)
        kind = "town" if mid in TOWNS else "rift" if mid in RIFTS else "marsh" if mid in MARSH else "route"
        out.append('  "%s": {"region": "%s", "pos": [%d, %d], "kind": "%s", "neighbours": %s}'
                   % (mid, REGION, pos[0], pos[1], kind, json.dumps(neighbours(mid))))
    for rid, mid in INTERIORS.items():
        out.append('  "%s": {"inside": "%s", "region": "%s"}' % (rid, mid, REGION))
    return out


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

    append(' "regions": {', ['  "%s": {"name": "Quillmarch", "origin": [45, 0], "size": [6, 6]}' % REGION])
    append(' "lines": {', ['  "%s": {"name": "Mail Boat", "kind": "ferry", "open_flag": "%s", "stops": {"%s": [%d, %d, "right"], "%s": [%d, %d, "right"]}}'
                           % (LINE, SHEET["unlock_flag"], SHEET["arrival"]["from"], BOAT_LASTLAMP[0], BOAT_LASTLAMP[1],
                              SHEET["arrival"]["to"], BOAT_LANDING[0], BOAT_LANDING[1])])
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
    """The mail boatman on the Lastlamp square, there once Vellmarch's finale is done."""
    path = os.path.join(ROOT, "data", "story_npcs.json")
    d = json.load(open(path, encoding="utf-8"))
    top = SHEET["arrival"]["from"]
    if top in d:
        d[top]["npcs"] = [n for n in d[top].get("npcs", []) if n.get("id") != "mail_boatman"]
    d.setdefault(top, {}).setdefault("npcs", []).append(
        {"id": "mail_boatman", "x": BOAT_LASTLAMP[0] + 1, "y": BOAT_LASTLAMP[1], "facing": "left", "dialogue": "%s/boatman_top" % DIA,
         "sprite": "elder", "show_flag": SHEET["unlock_flag"]})
    text("boatman_top", {"lines": lines(("Mail Boatman: Quillmarch? Letters, crates and passengers. Passengers go under the crates.", "Postschiffer: Quillmarch? Briefe, Kisten und Fahrgäste. Fahrgäste kommen unter die Kisten.")),
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
    import quillmarch_side  # noqa: E402  side goals, landmark halls, more Wayfarers and finds (q3_*)
    quillmarch_side.build(sys.modules[__name__])
    patch_story_npcs()
    tr("Mail Boat", "Postschiff")
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
    with open(os.path.join(ROOT, "tools", "i18n", "de_quillmarch.py"), "w", encoding="utf-8") as f:
        f.write("# German texts for Quillmarch's maps. Written by tools/art/world/quillmarch.py:\n")
        f.write("# edit the tr()/lines() pairs there, not this file.\n")
        f.write("KEEP = []\nT = {\n")
        for en in sorted(GERMAN):
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(GERMAN[en], ensure_ascii=False)))
        f.write("}\n")
    print("wrote %d maps, %d dialogue entries, %d German texts" % (len(MAPS), len(TEXT), len(GERMAN)))


if __name__ == "__main__":
    main()
