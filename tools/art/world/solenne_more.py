"""Solenne side content, part two (Act IV toward 20 h): the Glasswind Flats west of Ochrewell
(a desert route), the Glasswind Caravanserai on it (the Wayfarer ladder, the bell mender, the
naturalist, a lost twin) and the Mirage Kiln at its south end (a three-floor dungeon of the
Sandglass Crew, a glass-smuggling gang under Glassmaster Venn). No debts and no IOUs here: the
Sandglass Crew lives on lies about the way (false bells, false signals, false guides).

Side goals (data/quests.json): s4_ladder (eight rungs, then Sabine's purse), s4_bells (nine caravan
bells), s4_bell_line (where the bells really lead), s4_twin (a twin who never was), s4_census
(eight kinds for Ilse), s4_poacher (whom Ilse sold her list to), s4_mirrors (Oren's
heliographs), s4_kiln (who runs the crew), s4_varro (a guide's shortcut).
Betrayals (data/clans.json): sabine_purse, tamsin_twin, venn_chains; favor varro_shortcut.

How the way opens:
  ochrewell -> glasswind_flats   rift_tower_sealed (west gate of the bazaar)
  flats -> caravanserai          always
  flats -> mirage_kiln           always; floors 2 and 3 behind the lens rows
Edit here, then run python3 tools/art/world/solenne_more.py (writes only these maps, their
dialogue and tools/i18n/de_solenne_more.py) and python3 tools/i18n/build.py.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from common import check_rows, lines, npc, secret, team, tr, warp  # noqa: E402
from rifts12 import gate, put, wayfarer  # noqa: E402

GROUP = ["glasswind_flats", "caravanserai", "mirage_kiln"]
FLATS = "glasswind_flats"
INN = "caravanserai"
KILN = "mirage_kiln"
SIDE = "glasswind_side"

# Census kinds for Ilse: four from the flats, four from the kiln.
CENSUS = ["Rollibex", "Sirocat", "Noonwhist", "Velvessa", "Caravant", "Obelith", "Fulgorin", "Wadishell"]

# Caravan bells: 1-5 on the flats, 6-9 in the kiln. (map, floor, x, y, text)
BELLS = [
    (FLATS, 0, 10, 8, ("A caravan bell half under the sand. Its clapper is tied to a camel's tooth. Lucky charm. Was.", "Eine Karawanenglocke, halb im Sand. Ihr Klöppel ist an einen Kamelzahn gebunden. Glücksbringer. War einer.")),
    (FLATS, 0, 1, 13, ("A caravan bell on a stake, polished by the wind. Someone carved 'turn back' into it, then 'just kidding'.", "Eine Karawanenglocke auf einem Pfahl, vom Wind poliert. Jemand hat 'kehr um' hineingeritzt, dann 'nur Spaß'.")),
    (FLATS, 0, 10, 18, ("A caravan bell in a dry bush. It rings when nobody touches it. You decide not to think about that.", "Eine Karawanenglocke in einem trockenen Busch. Sie läutet, wenn niemand sie berührt. Du beschließt, nicht darüber nachzudenken.")),
    (FLATS, 0, 1, 24, ("A caravan bell with a name tag: 'Gulnar, lead camel, very opinionated.'", "Eine Karawanenglocke mit Namensschild: 'Gulnar, Leitkamel, sehr meinungsstark.'")),
    (FLATS, 0, 10, 31, ("A caravan bell on a broken pole. The pole points at the kiln. Poles don't lie. People do.", "Eine Karawanenglocke an einem abgebrochenen Pfahl. Der Pfahl zeigt zur Brennerei. Pfähle lügen nicht. Leute schon.")),
    (KILN, 0, 10, 8, ("A caravan bell in a crate marked GLASS. It is not glass. Nothing in this crate is glass.", "Eine Karawanenglocke in einer Kiste mit der Aufschrift GLAS. Sie ist nicht aus Glas. Nichts in dieser Kiste ist aus Glas.")),
    (KILN, 0, 1, 7, ("A caravan bell melted halfway into a glass bottle. Art, says the label. Evidence, says your gut.", "Eine Karawanenglocke, halb in eine Glasflasche geschmolzen. Kunst, sagt das Etikett. Beweis, sagt dein Bauch.")),
    (KILN, 1, 10, 7, ("A caravan bell hung over a furnace door. It rings when the door opens. Crew alarm, very homely.", "Eine Karawanenglocke über einer Ofentür. Sie läutet, wenn die Tür aufgeht. Alarm der Bande, sehr gemütlich.")),
    (KILN, 2, 1, 1, ("A caravan bell on Venn's desk, used as a paperweight on a stack of maps. Every map is wrong.", "Eine Karawanenglocke auf Venns Tisch, als Briefbeschwerer auf einem Stapel Karten. Jede Karte ist falsch.")),
]

# Oren's three heliographs on the flats: (x, y, text).
HELIOS = [
    (4, 4, ("A heliograph mirror on a post, tilted at the sky. It flashes at nobody in particular.", "Ein Signalspiegel auf einem Pfahl, schräg zum Himmel. Er blitzt niemanden Bestimmten an.")),
    (9, 15, ("A heliograph mirror, cracked down the middle. It sends every message twice, slightly wrong.", "Ein Signalspiegel, in der Mitte gesprungen. Er sendet jede Nachricht zweimal, leicht falsch.")),
    (2, 29, ("A heliograph mirror pointed at the kiln. Its shutter is oiled. Someone uses this one a lot.", "Ein Signalspiegel, auf die Brennerei gerichtet. Seine Klappe ist geölt. Diesen hier benutzt jemand oft.")),
]

# Lens rows in the kiln: cells per floor, the order they are turned in, the flag, the hint.
LENSES = [
    {"cells": [(2, 1), (5, 2), (9, 1)], "order": [2, 0, 1], "flag": "kiln_lens_1", "wall": (1, 4),
     "names": [("A lens marked DAWN.", "Eine Linse mit der Aufschrift MORGEN."),
               ("A lens marked NOON.", "Eine Linse mit der Aufschrift MITTAG."),
               ("A lens marked DUSK.", "Eine Linse mit der Aufschrift ABEND.")],
     "hint": ("Scratched on the kiln wall: The crew works backwards. Start at the end of the day.", "In die Ofenwand geritzt: Die Bande arbeitet rückwärts. Fang am Ende des Tages an.")},
    {"cells": [(2, 1), (9, 1), (2, 3), (9, 3)], "order": [1, 3, 0, 2], "flag": "kiln_lens_2", "wall": (1, 6),
     "names": [("A lens marked NORTH.", "Eine Linse mit der Aufschrift NORDEN."),
               ("A lens marked EAST.", "Eine Linse mit der Aufschrift OSTEN."),
               ("A lens marked SOUTH.", "Eine Linse mit der Aufschrift SÜDEN."),
               ("A lens marked WEST.", "Eine Linse mit der Aufschrift WESTEN.")],
     "hint": ("A crew note: Never the way the caravan wants. East, west, north, south. Then laugh.", "Eine Notiz der Bande: Nie die Richtung, die die Karawane will. Osten, Westen, Norden, Süden. Dann lachen.")},
]


def build(world):
    side_texts(world)
    flats(world)
    caravanserai(world)
    kiln(world)


def bell_entry(n, text):
    return {"if": {"not_flag": "bell_%d" % n}, "else": "bell_empty",
            "lines": lines(text, ("You take the bell. It keeps quiet, for now.", "Du nimmst die Glocke. Sie schweigt, vorerst.")),
            "action": "set_flag bell_%d" % n}


def stage(goal, lo, hi=None):
    return {"var_min": {"q_%s_stage" % goal: lo}, "var_max": {"q_%s_stage" % goal: lo if hi is None else hi}}


# --- Texts of the caravanserai people and the betrayals (glasswind_side) ------------------------
def side_texts(world):
    t = {}
    # Sabine, the Ladder Master: eight rungs, then the purse (scripted betrayal sabine_purse).
    t["sabine"] = {"if": {"not_flag": "s4_ladder_asked"}, "else": "sabine_climb",
                   "lines": lines(("Ladder Master Sabine: Welcome to the Glasswind Ladder. Eight Wayfarers, one rung each, no skipping, no crying on the rungs.", "Leitermeisterin Sabine: Willkommen auf der Glaswind-Leiter. Acht Wayfarer, je eine Sprosse, kein Überspringen, kein Weinen auf den Sprossen."),
                                  ("Ladder Master Sabine: Six rungs stand out on the flats. Seven and eight wait in here. Climb all eight and the purse is yours.", "Leitermeisterin Sabine: Sechs Sprossen stehen draußen auf der Ebene. Sieben und acht warten hier drin. Erklimm alle acht, und der Geldbeutel gehört dir."),
                                  ("Ladder Master Sabine: Three thousand coins. Nobody has ever collected. That's not a warning, that's a statistic.", "Leitermeisterin Sabine: Dreitausend Münzen. Abgeholt hat sie noch keiner. Das ist keine Warnung, das ist Statistik.")),
                   "action": "set_flag s4_ladder_asked"}
    t["sabine_climb"] = {"if": {"not_flag": "ladder_rung_8"}, "else": "sabine_purse",
                         "lines": lines(("Ladder Master Sabine: Still climbing? Good. Falling is free, climbing is the part with dignity.", "Leitermeisterin Sabine: Noch am Klettern? Gut. Fallen ist gratis, Klettern ist der Teil mit Würde."),)}
    t["sabine_purse"] = {"if": {"not_flag": "betrayal_sabine_purse"}, "else": "sabine_after",
                         "lines": lines(("Ladder Master Sabine: You beat Dario. My own son. I'm so proud I could cry. On the purse, mostly.", "Leitermeisterin Sabine: Du hast Dario besiegt. Meinen eigenen Sohn. Ich bin so stolz, ich könnte weinen. Vor allem auf den Geldbeutel."),
                                        ("Ladder Master Sabine: Here it is. Do read rule nine on the back, dear. Everybody skips rule nine.", "Leitermeisterin Sabine: Hier ist er. Lies ruhig Regel neun auf der Rückseite, Liebes. Alle überspringen Regel neun.")),
                         "action": "betrayal sabine_purse"}
    t["sabine_after"] = lines(("Ladder Master Sabine: The ladder's open again. Same rules. Fewer, after you.", "Leitermeisterin Sabine: Die Leiter ist wieder offen. Dieselben Regeln. Weniger, nach dir."))
    t["purse_caught"] = lines(("You hold up the promise Old Pell made her write on the ladder board. In chalk, signed, witnessed by a goat.", "Du hältst das Versprechen hoch, das Old Pell sie auf die Leitertafel schreiben ließ. In Kreide, unterschrieben, von einer Ziege bezeugt."),
                              ("Sabine: Rule nine says the purse goes to the house. Rule ten, apparently, says the goat outranks me. Fine. Take it.", "Sabine: Regel neun sagt, der Beutel geht ans Haus. Regel zehn sagt offenbar, die Ziege steht über mir. Schön. Nimm ihn."))
    t["purse_struck"] = lines(("Rule nine, in very small letters: 'The purse remains property of the house. The winner may keep the feeling.'", "Regel neun, in sehr kleiner Schrift: 'Der Beutel bleibt Eigentum des Hauses. Der Sieger darf das Gefühl behalten.'"),
                              ("Sabine: And the bouncers would like a word about your attitude. Several words. With Spirlings.", "Sabine: Und die Türsteher hätten gern ein Wort über deine Haltung. Mehrere Worte. Mit Spirlings."))
    t["bouncers_defeat"] = lines(("Bouncer: We'll put you down as 'left voluntarily'. Here's the consolation purse. It's mostly buttons.", "Türsteher: Wir schreiben 'freiwillig gegangen'. Hier ist der Trostbeutel. Größtenteils Knöpfe."))
    t["bouncers_lose"] = lines(("The bouncers walk you to the door, then a bit further. The desert is very big when you're carried.", "Die Türsteher bringen dich zur Tür und dann noch ein Stück weiter. Die Wüste ist sehr groß, wenn man getragen wird."))
    t["ledger_purse"] = lines(("The ladder purse", "Der Leiterbeutel"),
                              ("Sabine promised three thousand coins to whoever climbed her ladder, then pointed at rule nine on the back of the purse.", "Sabine versprach dreitausend Münzen für die ganze Leiter und zeigte dann auf Regel neun hinten auf dem Beutel."))
    # The ladder board on the wall.
    t["board"] = {"lines": lines(("THE GLASSWIND LADDER - eight rungs, one purse. Rule one: no biting. Rules two to eight: see rule one.", "DIE GLASWIND-LEITER - acht Sprossen, ein Beutel. Regel eins: kein Beißen. Regeln zwei bis acht: siehe Regel eins."),),
                  "after_flag": {"flag": "c4_pell_warned", "lines": lines(("THE GLASSWIND LADDER. Under it, in fresh chalk: 'The purse goes to the winner. S.' And a hoof print.", "DIE GLASWIND-LEITER. Darunter, in frischer Kreide: 'Der Beutel geht an den Sieger. S.' Und ein Hufabdruck."),)}}
    # Hesper, the bell mender: nine bells, then the Bell Line (stages).
    t["hesper"] = {"if": {"not_flag": "s4_bells_asked"}, "else": "hesper_count",
                   "lines": lines(("Bell-Mender Hesper: Caravans used to follow the Bell Line across the flats. One bell per post, one post per mile, nobody lost.", "Glockenflickerin Hesper: Früher folgten die Karawanen der Glockenlinie über die Ebene. Eine Glocke pro Pfahl, ein Pfahl pro Meile, keiner verirrt."),
                                  ("Bell-Mender Hesper: Then the bells went missing. Nine of them. Bring them back and I'll hang them again. Safe roads for everyone.", "Glockenflickerin Hesper: Dann verschwanden die Glocken. Neun Stück. Bring sie zurück, dann hänge ich sie wieder auf. Sichere Wege für alle.")),
                   "action": "set_flag s4_bells_asked"}
    t["hesper_count"] = {"if": {"not_flag": "s4_bells_done"}, "else": "hesper_line",
                         "lines": lines(("Bell-Mender Hesper: Any bells? Five lie out on the flats. The rest, they say, went into the Mirage Kiln. Bells don't walk, so somebody carried them.", "Glockenflickerin Hesper: Glocken dabei? Fünf liegen draußen auf der Ebene. Der Rest soll in der Spiegelbrennerei sein. Glocken laufen nicht, also hat sie jemand getragen."),),
                         "next": "hesper_all"}
    t["hesper_all"] = {"if": {"flag": ["bell_%d" % n for n in range(1, 10)]},
                       "lines": lines(("Bell-Mender Hesper: All nine! Listen to them. Like nine little liars clearing their throats. I mean choirboys. Choirboys.", "Glockenflickerin Hesper: Alle neun! Hör sie dir an. Wie neun kleine Lügner, die sich räuspern. Ich meine Chorknaben. Chorknaben."),
                                      ("Bell-Mender Hesper: I'll hang them on the posts tonight. Take this for your trouble.", "Glockenflickerin Hesper: Ich hänge sie heute Nacht an die Pfähle. Nimm das für deine Mühe.")),
                       "action": "set_flag s4_bells_done; give_item swift_feather 1"}
    t["hesper_line"] = {"if": stage("s4_bell_line", 0, 1), "else": "hesper_confront",
                        "lines": lines(("Bell-Mender Hesper: Hear that? The Bell Line rings again. Driver Ott will tell you how much the caravans love it.", "Glockenflickerin Hesper: Hörst du? Die Glockenlinie läutet wieder. Fuhrmann Ott sagt dir, wie sehr die Karawanen sie lieben."),)}
    t["hesper_confront"] = {"if": stage("s4_bell_line", 2), "else": "hesper_after",
                            "lines": lines(("Bell-Mender Hesper: You read my ledger. Rude. I only moved the posts a little. A mile here, a mile there, into the kiln.", "Glockenflickerin Hesper: Du hast mein Buch gelesen. Unhöflich. Ich habe die Pfähle nur ein bisschen versetzt. Eine Meile hier, eine Meile da, in die Brennerei."),
                                           ("Bell-Mender Hesper: Venn pays per caravan. Safe roads were never the business. Lost ones are.", "Glockenflickerin Hesper: Venn zahlt pro Karawane. Sichere Wege waren nie das Geschäft. Verlorene schon.")),
                            "action": "battle hesper_line"}
    t["hesper_defeat"] = lines(("Bell-Mender Hesper: Fine. I'll move the posts back. Do you know how heavy a post is? Neither do I, I always had the crew carry them.", "Glockenflickerin Hesper: Schön. Ich setze die Pfähle zurück. Weißt du, wie schwer so ein Pfahl ist? Ich auch nicht, das hat immer die Bande gemacht."),)
    t["hesper_lose"] = lines(("Bell-Mender Hesper: Ring, ring. That's the sound of you going the wrong way.", "Glockenflickerin Hesper: Kling, kling. So klingt es, wenn du in die falsche Richtung gehst."))
    t["hesper_after"] = {"lines": lines(("Bell-Mender Hesper: The bells ring true now. Terrible for business. Mine, I mean.", "Glockenflickerin Hesper: Die Glocken läuten jetzt richtig. Schrecklich fürs Geschäft. Für meins, meine ich."),),
                         "action": "quest_stage s4_bell_line 3"}
    # Ott the caravan driver: the bells lead into the kiln, and no child travels alone.
    t["ott"] = {"if": stage("s4_bell_line", 0), "else": "ott_twin",
                "lines": lines(("Driver Ott: Twenty years on the flats. Lost four camels, two wives and one very good hat.", "Fuhrmann Ott: Zwanzig Jahre auf der Ebene. Vier Kamele verloren, zwei Ehefrauen und einen sehr guten Hut."),),
                "next": "ott_bells"}
    t["ott_bells"] = {"if": {"flag": "s4_bells_done"}, "else": "ott_twin",
                      "lines": lines(("Driver Ott: The new bells? They ring at the wrong posts. Follow them and you end up at the Mirage Kiln, every time.", "Fuhrmann Ott: Die neuen Glocken? Die läuten an den falschen Pfählen. Folg ihnen, und du landest jedes Mal an der Spiegelbrennerei."),
                                     ("Driver Ott: Nobody follows a bell into a kiln by accident twice. Go see what's in there.", "Fuhrmann Ott: Niemand folgt einer Glocke zweimal aus Versehen in eine Brennerei. Sieh nach, was da drin ist.")),
                      "action": "quest_stage s4_bell_line 1", "next": "ott_twin"}
    t["ott_twin"] = {"if": {"flag": "s4_twin_asked"}, "else": "ott_plain",
                     "lines": lines(("Driver Ott: That little girl with the twin? Funny. No child crosses the flats alone. Not with a clean dress and all her teeth.", "Fuhrmann Ott: Das kleine Mädchen mit dem Zwilling? Komisch. Kein Kind kommt allein über die Ebene. Nicht mit sauberem Kleid und allen Zähnen."),),
                     "action": "set_flag c4_ott_warned"}
    t["ott_plain"] = lines(("Driver Ott: Water, shade, and never trust a shortcut. That's the whole desert, kid.", "Fuhrmann Ott: Wasser, Schatten, und trau nie einer Abkürzung. Das ist die ganze Wüste, Kind."))
    # Tamsin, the girl with a twin brother in the kiln (scripted betrayal tamsin_twin).
    t["tamsin"] = {"if": stage("s4_twin", 0), "else": "tamsin_scarf",
                   "lines": lines(("Tamsin: My twin brother Tavi walked into the Mirage Kiln to look at the shiny glass. He didn't come out.", "Tamsin: Mein Zwillingsbruder Tavi ist in die Spiegelbrennerei gegangen, um das glänzende Glas anzusehen. Er ist nicht rausgekommen."),
                                  ("Tamsin: Could you find him? He's easy to spot. He looks exactly like me, but worse.", "Tamsin: Kannst du ihn finden? Er ist leicht zu erkennen. Er sieht genau aus wie ich, nur schlechter.")),
                   "action": "set_flag s4_twin_asked"}
    t["tamsin_scarf"] = {"if": stage("s4_twin", 1), "else": "tamsin_wait",
                         "lines": lines(("Tamsin: His scarf! So he's alive. Probably. Mostly. Let me take you to him myself, I know the way.", "Tamsin: Sein Schal! Dann lebt er. Wahrscheinlich. Größtenteils. Lass mich dich selbst zu ihm bringen, ich kenne den Weg."),
                                        ("Tamsin: Meet me at the kiln door. Come alone. Tavi's shy.", "Tamsin: Triff mich am Tor der Brennerei. Komm allein. Tavi ist schüchtern.")),
                         "action": "quest_stage s4_twin 2; set_flag s4_twin_meet"}
    t["tamsin_wait"] = lines(("Tamsin: Tavi's somewhere in the kiln. Look for something with a bad knot in it. He never learned knots.", "Tamsin: Tavi ist irgendwo in der Brennerei. Such etwas mit einem schlechten Knoten. Knoten hat er nie gelernt."))
    t["tamsin_door"] = {"if": {"not_flag": "betrayal_tamsin_twin"}, "else": "tamsin_after",
                        "lines": lines(("Tamsin: You came! And alone. That's the important part. Tavi's just round the back. Close your eyes, it's a surprise.", "Tamsin: Du bist gekommen! Und allein. Das ist der wichtige Teil. Tavi ist gleich hinten rum. Augen zu, es ist eine Überraschung."),),
                        "action": "betrayal tamsin_twin; quest_stage s4_twin 3"}
    t["tamsin_after"] = lines(("Tamsin: Dad says lookouts get a tenth. I get a tenth of nothing now. Thanks a lot.", "Tamsin: Papa sagt, Späher kriegen ein Zehntel. Ich krieg jetzt ein Zehntel von nichts. Vielen Dank auch."))
    t["twin_caught"] = lines(("You keep your eyes open. Round the back: three Sandglass Crew with a net and no twin.", "Du lässt die Augen offen. Hinten rum: drei Leute der Sandglas-Bande mit einem Netz und kein Zwilling."),
                             ("Tamsin: ...Ott told you, didn't he. Fine. There's no Tavi. The scarf's from the crew's lost and found. Here, have my cut. It's small.", "Tamsin: ...Ott hat's dir gesagt, oder. Schön. Es gibt keinen Tavi. Der Schal ist aus der Fundkiste der Bande. Hier, nimm meinen Anteil. Er ist klein."))
    t["twin_struck"] = lines(("You close your eyes. A net drops. Tamsin's voice: 'Sorry! There's no Tavi. There's a finder's fee.'", "Du machst die Augen zu. Ein Netz fällt. Tamsins Stimme: 'Tut mir leid! Es gibt keinen Tavi. Es gibt eine Finderprämie.'"),)
    t["crew_defeat"] = lines(("Crew Uncle Brask: Out-fought by the mark. Venn will dock us. Tamsin, you're grounded.", "Bandenonkel Brask: Vom Opfer verprügelt. Venn kürzt uns den Lohn. Tamsin, du hast Hausarrest."),)
    t["crew_lose"] = lines(("The crew empties your pockets and leaves you a receipt shaped like a glass bead.", "Die Bande leert deine Taschen und lässt dir eine Quittung da, die aussieht wie eine Glasperle."))
    t["ledger_twin"] = lines(("The twin who never was", "Der Zwilling, den es nie gab"),
                             ("Little Tamsin sent you into the kiln for a twin brother, then led you round the back to the Sandglass Crew's net.", "Die kleine Tamsin schickte dich in die Brennerei nach einem Zwillingsbruder und führte dich dann hinten herum ins Netz der Sandglas-Bande."))
    # Ilse the naturalist: eight kinds of Spirling, then the list she sold.
    t["ilse"] = {"if": {"not_flag": "s4_census_asked"}, "else": "ilse_done",
                 "lines": lines(("Naturalist Ilse: I'm writing the first honest field guide of the Glasswind. Where every kind lives, to the rock.", "Naturforscherin Ilse: Ich schreibe den ersten ehrlichen Feldführer des Glaswinds. Wo jede Art lebt, auf den Stein genau."),
                                ("Naturalist Ilse: Bring me eight kinds in your team so I can sketch them. They don't have to smile. Most don't.", "Naturforscherin Ilse: Bring mir acht Arten in deinem Team, damit ich sie zeichnen kann. Lächeln müssen sie nicht. Die meisten tun es nicht.")),
                 "flag": "s4_census_asked"}
    t["ilse_done"] = {"if": {"flag": "s4_census_done"}, "else": "ilse_c0",
                      "lines": lines(("Naturalist Ilse: The guide sold out before it was printed. One buyer. Paid in advance. Very keen on the maps.", "Naturforscherin Ilse: Der Führer war ausverkauft, bevor er gedruckt war. Ein Käufer. Hat im Voraus bezahlt. Sehr scharf auf die Karten."),),
                      "after_flag": [{"flag": "kiln_rusk_beaten", "lines": lines(("Naturalist Ilse: You took my notes off a poacher? I sold them to a 'collector'. Same thing, it turns out, with fewer cages.", "Naturforscherin Ilse: Du hast meine Notizen einem Wilderer abgenommen? Ich hab sie an einen 'Sammler' verkauft. Dasselbe, wie sich zeigt, nur mit weniger Käfigen."),
                                                                                   ("Naturalist Ilse: I'll write a second edition. With the wrong rocks in it.", "Naturforscherin Ilse: Ich schreibe eine zweite Auflage. Mit den falschen Steinen darin."))}]}
    for i, sp in enumerate(CENSUS):
        nxt = "ilse_c%d" % (i + 1) if i + 1 < len(CENSUS) else "ilse_end"
        t["ilse_c%d" % i] = {"if": {"has_species": sp, "not_flag": "census4_" + sp.lower()},
                             "lines": [tr("Naturalist Ilse: A %s! Hold still. No, the other still." % sp, "Naturforscherin Ilse: Ein %s! Stillhalten. Nein, das andere Stillhalten." % sp)],
                             "flag": "census4_" + sp.lower(), "next": nxt, "else": nxt}
    t["ilse_end"] = {"if": {"flag": ["census4_" + sp.lower() for sp in CENSUS]},
                     "lines": lines(("Naturalist Ilse: Eight! The guide is done. Every kind, every den, every rock. Here, a lens for your trouble.", "Naturforscherin Ilse: Acht! Der Führer ist fertig. Jede Art, jeder Bau, jeder Stein. Hier, eine Linse für deine Mühe."),),
                     "action": "set_flag s4_census_done; give_item keen_lens 1", "once": True, "else": "ilse_more"}
    t["ilse_more"] = lines(("Naturalist Ilse: Still missing some. Four live out on the flats, four in the kiln. The kiln ones bite more.", "Naturforscherin Ilse: Mir fehlen noch welche. Vier leben draußen auf der Ebene, vier in der Brennerei. Die aus der Brennerei beißen mehr."))
    # The inn: keeper and shop.
    t["keeper"] = {"lines": lines(("Innkeeper Zohra: Beds, water, shade. The shade is free. The rest is also free, if you don't look at the bill.", "Wirtin Zohra: Betten, Wasser, Schatten. Der Schatten ist gratis. Der Rest auch, solange du nicht auf die Rechnung schaust."),
                                  ("Innkeeper Zohra: Your Spirlings look baked. Let them rest.", "Wirtin Zohra: Deine Spirlings sehen gebacken aus. Lass sie ausruhen.")),
                   "action": "heal"}
    t["trader"] = {"lines": lines(("Supplier Kasim: Tonics, brews, sand out of your boots for free. Everything else, list price.", "Händler Kasim: Tränke, Gebräue, Sand aus den Stiefeln gratis. Alles andere zum Listenpreis."),),
                   "action": "shop strong_tonic max_tonic remedy revival_leaf dash_brew guard_brew power_brew focus_brew"}
    # Varro, the guide with a shortcut (favor varro_shortcut).
    t["varro"] = {"if": {"not_flag": "varro_done"}, "else": "varro_after",
                  "lines": lines(("Guide Varro: Varro. Best guide on the Glasswind. Ask anyone. Well, ask anyone who came back.", "Führer Varro: Varro. Bester Führer im Glaswind. Frag jeden. Na ja, jeden, der zurückgekommen ist."),
                                 ("Guide Varro: I know a shortcut through the mirage, straight to the kiln. Half the walk. Trust me?", "Führer Varro: Ich kenne eine Abkürzung durch die Luftspiegelung, direkt zur Brennerei. Halber Weg. Vertraust du mir?")),
                  "action": "set_flag varro_met",
                  "choices": [{"text": tr("Show me the way", "Zeig mir den Weg"), "action": "favor varro_shortcut", "flag": "varro_done"},
                              {"text": tr("I'll walk, thanks", "Ich laufe, danke")}]}
    t["varro_after"] = lines(("Guide Varro: No hard feelings. The desert does what it wants. I just help it along.", "Führer Varro: Nichts für ungut. Die Wüste macht, was sie will. Ich helfe ihr nur ein bisschen."))
    t["varro_betray"] = lines(("Varro's shortcut ends in a dune bowl. Three Sand Bandits wait at the bottom with a picnic and a price list.", "Varros Abkürzung endet in einer Dünenmulde. Unten warten drei Sandbanditen mit Picknick und Preisliste."),
                              ("Guide Varro: Half the walk, I said. I never said which half.", "Führer Varro: Halber Weg, hab ich gesagt. Nie gesagt, welche Hälfte."))
    t["varro_reward"] = lines(("The shortcut is real. Halfway down it Varro digs up a crate of old crew loot and splits it with you. Mostly fairly.", "Die Abkürzung gibt es wirklich. Auf halbem Weg gräbt Varro eine Kiste mit altem Bandengut aus und teilt mit dir. Größtenteils gerecht."))
    t["varro_kept"] = lines(("The shortcut is a long cut. Varro swears the dunes moved. They may have.", "Die Abkürzung ist ein Umweg. Varro schwört, die Dünen hätten sich bewegt. Kann sein."))
    t["bandits_defeat"] = lines(("Sand Bandit: We'll tell Varro you were a bad investment. He'll understand. He's one too.", "Sandbandit: Wir sagen Varro, du warst eine schlechte Investition. Er wird's verstehen. Er ist auch eine."),)
    t["bandits_lose"] = lines(("The bandits take your snacks and leave you the map. The map is of somewhere else.", "Die Banditen nehmen deine Vorräte und lassen dir die Karte. Die Karte zeigt einen anderen Ort."))
    # Oren the signalman: the three heliographs, then the signal they really send.
    t["oren"] = {"if": {"not_flag": "s4_mirrors_asked"}, "else": "oren_count",
                 "lines": lines(("Signalman Oren: Three heliographs warn the caravans of sandstorms. Flash, flash, run. Simple.", "Signalmann Oren: Drei Signalspiegel warnen die Karawanen vor Sandstürmen. Blitz, Blitz, lauf. Einfach."),
                                ("Signalman Oren: But they've drifted. Turn each one to face the sun again, would you? My knees don't do posts anymore.", "Signalmann Oren: Aber sie haben sich verdreht. Dreh jeden wieder zur Sonne, ja? Meine Knie machen keine Pfähle mehr.")),
                 "action": "set_flag s4_mirrors_asked"}
    t["oren_count"] = {"if": {"flag": ["helio_1", "helio_2", "helio_3"], "not_flag": "oren_signal_beaten"}, "else": "oren_wait",
                       "lines": lines(("Signalman Oren: All three! Flash, flash, flash. That's not 'storm', by the way. That's 'fat caravan, two guards, come now'.", "Signalmann Oren: Alle drei! Blitz, Blitz, Blitz. Das heißt übrigens nicht 'Sturm'. Das heißt 'dicke Karawane, zwei Wachen, kommt jetzt'."),
                                      ("Signalman Oren: Venn thanks you. I'd thank you too, but you'd only try to stop me. So let's skip to that.", "Signalmann Oren: Venn dankt dir. Ich würde dir auch danken, aber du würdest mich nur aufhalten wollen. Also gleich dazu.")),
                       "action": "battle oren_signal"}
    t["oren_wait"] = {"if": {"not_flag": "oren_signal_beaten"}, "else": "oren_after",
                      "lines": lines(("Signalman Oren: Two more posts to go. Mind the sun, it's out to get you. Like everyone.", "Signalmann Oren: Noch zwei Pfähle. Pass auf die Sonne auf, die will dir an den Kragen. Wie alle."),)}
    t["oren_defeat"] = lines(("Signalman Oren: Fine. I'll flash 'storm' for real. Caravans will hide, the crew will starve. Everyone's unhappy. Balance.", "Signalmann Oren: Schön. Dann blitze ich wirklich 'Sturm'. Die Karawanen verstecken sich, die Bande hungert. Alle sind unglücklich. Gleichgewicht."),)
    t["oren_lose"] = lines(("Signalman Oren: Flash, flash. That one means 'idiot'.", "Signalmann Oren: Blitz, Blitz. Der heißt 'Dummkopf'."))
    t["oren_after"] = lines(("Signalman Oren: Storm warnings only now. I even mean some of them.", "Signalmann Oren: Jetzt nur noch Sturmwarnungen. Ein paar davon meine ich sogar ernst."))
    # Venn in the gallery (scripted betrayal venn_chains, then the boss duel).
    t["venn"] = {"if": {"not_flag": "betrayal_venn_chains"}, "else": "venn_duel",
                 "lines": lines(("A man in glass-dust chains: 'Thank the sun. I'm Venn, the glassmaster. The crew keeps me here to make their fakes.'", "Ein Mann in Ketten voller Glasstaub: 'Der Sonne sei Dank. Ich bin Venn, der Glasmeister. Die Bande hält mich hier, damit ich ihre Fälschungen mache.'"),
                                ("Glassmaster Venn: The key hangs by the door. Unlock me, quick, before they come back.", "Glasmeister Venn: Der Schlüssel hängt an der Tür. Schließ mich auf, schnell, bevor sie zurückkommen.")),
                 "action": "betrayal venn_chains"}
    t["venn_duel"] = {"if": {"not_flag": "kiln_venn_beaten"}, "else": "venn_after",
                      "lines": lines(("Glassmaster Venn: Well. The chains were glass too. Everything in here is. Shall we see what you're made of?", "Glasmeister Venn: Tja. Die Ketten waren auch aus Glas. Alles hier drin ist es. Wollen wir sehen, woraus du gemacht bist?"),),
                      "action": "battle kiln_venn"}
    t["venn_defeat"] = lines(("Glassmaster Venn: Cracked. All of it. The bells, the mirrors, the girl, the guide. Do you know how long it takes to build a good lie in this heat?", "Glasmeister Venn: Gesprungen. Alles. Die Glocken, die Spiegel, das Mädchen, der Führer. Weißt du, wie lange man bei der Hitze an einer guten Lüge baut?"),
                             ("Glassmaster Venn: Take the gallery key. Sell the glass. Everyone else did.", "Glasmeister Venn: Nimm den Schlüssel der Galerie. Verkauf das Glas. Alle anderen haben's auch getan."))
    t["venn_lose"] = lines(("Glassmaster Venn: Shattered. Sweep yourself up on the way out.", "Glasmeister Venn: Zersplittert. Kehr dich auf dem Weg nach draußen zusammen."))
    t["venn_after"] = lines(("Glassmaster Venn: I'm going into honest glass. Windows. Nobody ever lied through a window. Well. Rarely.", "Glasmeister Venn: Ich mache jetzt ehrliches Glas. Fenster. Durch ein Fenster hat noch keiner gelogen. Na ja. Selten."))
    t["chains_caught"] = lines(("You remember Hesper's ledger: 'V. takes half.' You leave the key where it is.", "Du erinnerst dich an Hespers Buch: 'V. nimmt die Hälfte.' Du lässt den Schlüssel hängen."),
                               ("Glassmaster Venn shrugs out of the chains himself. 'Worth a try. Most people are kinder than you.'", "Glasmeister Venn schlüpft selbst aus den Ketten. 'Einen Versuch war's wert. Die meisten sind netter als du.'"))
    t["chains_struck"] = lines(("The key turns. The chains fall away, and so does the gallery door behind you, locked from outside.", "Der Schlüssel dreht sich. Die Ketten fallen ab, und die Galerietür hinter dir fällt ins Schloss, von außen verriegelt."),
                               ("Glassmaster Venn: Thank you! Crew, the kind one's in. Bill them for the rescue.", "Glasmeister Venn: Danke! Bande, die Nette ist drin. Stellt ihr die Rettung in Rechnung."))
    t["trap_defeat"] = lines(("Crew Muscle: That's three of us down for one rescuer. Venn's maths never adds up.", "Bandenschläger: Drei von uns erledigt für einen Retter. Venns Rechnung geht nie auf."),)
    t["trap_lose"] = lines(("The crew carries you out and leaves you by the bell posts. Ring if you need anything.", "Die Bande trägt dich raus und legt dich bei den Glockenpfählen ab. Läute, wenn du was brauchst."))
    t["ledger_chains"] = lines(("The glassmaster's chains", "Die Ketten des Glasmeisters"),
                               ("Venn played the crew's prisoner in his own gallery and asked you to unlock chains he could slip any time.", "Venn spielte in seiner eigenen Galerie den Gefangenen der Bande und bat dich, Ketten zu öffnen, aus denen er jederzeit schlüpfen konnte."))
    world.add_text(SIDE, t)


# --- The Glasswind Flats: a desert route west of Ochrewell ------------------------------------
def flats(world):
    rows = ["^^^^^^^^^^^^",
            "^::...,,,..^",
            "^::...______",
            "^,,...._.,,^",
            "^,,.:.._.,,^",
            "^...____.::^",
            "^::._....,:^",
            "^::.__..,,.^",
            "^.@..___...^",
            "^,,,...__,,^",
            "^,,,....__,^",
            "^..RRRR..__^",
            "^..HHDH.._,^",
            "^...._____.^",
            "^.L.__..,,,^",
            "^,,,_...,,,^",
            "^,,,_..:..:^",
            "^:..__.@..:^",
            "^:...__....^",
            "^..,,,__,,.^",
            "^..,,,._,,.^",
            "^@....__...^",
            "^::.___..::^",
            "^::._....,,^",
            "^...__...,,^",
            "^,,,.__....^",
            "^,,,..__.@.^",
            "^..:...__..^",
            "^.:::...__.^",
            "^..,,,..._.^",
            "^..,,,..__.^",
            "^...@.___..^",
            "^....__....^",
            "^^^^^__^^^^^"]
    text = {}
    signs = []
    for i, (mid, f, x, y, line) in enumerate(BELLS):
        if mid != FLATS:
            continue
        put(rows, x, y, "S")
        text["bell_%d" % (i + 1)] = bell_entry(i + 1, line)
        signs.append({"x": x, "y": y, "dialogue": "%s/bell_%d" % (FLATS, i + 1)})
    text["bell_empty"] = lines(("An empty stake. The wind whistles where the bell used to ring.", "Ein leerer Pfahl. Der Wind pfeift, wo früher die Glocke läutete."))
    for i, (x, y, line) in enumerate(HELIOS):
        put(rows, x, y, "S")
        key = "helio_%d" % (i + 1)
        text[key] = {"if": {"flag": "s4_mirrors_asked", "not_flag": key}, "else": key + "_plain",
                     "lines": lines(line, ("You turn the mirror back toward the sun. It flashes, very pleased with itself.", "Du drehst den Spiegel zurück zur Sonne. Er blitzt, sehr zufrieden mit sich.")),
                     "action": "set_flag " + key}
        text[key + "_plain"] = lines(line)
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (FLATS, key)})
    put(rows, 10, 3, "S")
    text["sign"] = lines(("GLASSWIND FLATS", "GLASWINDEBENE"),
                         ("East: Ochrewell. South: the Mirage Kiln. Everywhere else: sand, and opinions about sand.", "Osten: Ochrewell. Süden: die Spiegelbrennerei. Überall sonst: Sand, und Meinungen über Sand."))
    signs.append({"x": 10, "y": 3, "dialogue": FLATS + "/sign"})
    put(rows, 7, 32, "S")
    text["kiln_sign"] = lines(("MIRAGE KILN - GLASS SOLD, NOT TOLD.", "SPIEGELBRENNEREI - GLAS WIRD VERKAUFT, NICHT VERRATEN."),
                              ("Under it, in smaller paint: 'Lost caravans, please use the back door.'", "Darunter, in kleinerer Farbe: 'Verirrte Karawanen bitte den Hintereingang benutzen.'"))
    signs.append({"x": 7, "y": 32, "dialogue": FLATS + "/kiln_sign"})
    world.add_text(FLATS, text)

    def rung(n, id_, x, y, facing, title, crew, talk, intro, defeat, money, extra=None):
        w = wayfarer(world, FLATS, id_, x, y, facing, title, crew, talk, intro, defeat, money)
        w["beaten_flag"] = "ladder_rung_%d" % n
        if n > 1:
            w["show_flag"] = "ladder_rung_%d" % (n - 1)
        if extra:
            world.add_text(FLATS, extra)
        return w

    crew = [
        rung(1, "kesh", 8, 4, "left", tr("Dune Runner Kesh", "Dünenläuferin Kesh"), team(("Sirocat", 42), ("Highhare", 42)),
             [("Kesh: Rung one. I'm the welcome mat of the ladder. Everybody wipes their feet on me.", "Kesh: Sprosse eins. Ich bin die Fußmatte der Leiter. Jeder tritt sich an mir die Füße ab.")],
             [("Kesh: Ladder rules: you lose, you buy the water. Water is expensive out here.", "Kesh: Leiterregel: Wer verliert, zahlt das Wasser. Wasser ist teuer hier draußen.")],
             [("Kesh: Wiped. Go on, rung two's past the rocks.", "Kesh: Abgetreten. Weiter, Sprosse zwei ist hinter den Felsen.")], 2150),
        rung(2, "mabli", 9, 9, "left", tr("Salt Trader Mabli", "Salzhändlerin Mabli"), team(("Saltsprig", 42), ("Wadishell", 43)),
             [("Mabli: I trade salt for water and water for salt. Some days I come out ahead. Never both days.", "Mabli: Ich tausche Salz gegen Wasser und Wasser gegen Salz. Manchmal mache ich Gewinn. Nie an beiden Tagen.")],
             [("Mabli: Rung two. Salt in the wound, as we say.", "Mabli: Sprosse zwei. Salz in die Wunde, wie wir sagen.")],
             [("Mabli: Rinse and repeat. With what water, though.", "Mabli: Ausspülen und wiederholen. Nur mit welchem Wasser.")], 2200),
        rung(3, "fennel", 2, 16, "right", tr("Kiln Boy Fennel", "Ofenjunge Fennel"), team(("Scaldcoil", 43), ("Ardlume", 43), ("Bakedil", 43)),
             [("Fennel: I used to stoke the Mirage Kiln. Then I learned what they were baking. Now I stoke this ladder.", "Fennel: Früher hab ich die Spiegelbrennerei geheizt. Dann hab ich gelernt, was die da backen. Jetzt heize ich dieser Leiter ein.")],
             [("Fennel: Rung three's hot. Mind your fingers.", "Fennel: Sprosse drei ist heiß. Pass auf deine Finger auf.")],
             [("Fennel: Burned out. Story of my life.", "Fennel: Ausgebrannt. Die Geschichte meines Lebens.")], 2250),
        rung(4, "pell", 8, 21, "left", tr("Old Pell", "Old Pell"), team(("Obelith", 44), ("Rollibex", 44)),
             [("Old Pell: I've climbed this ladder forty times. Never got paid. Never learned. Very consistent.", "Old Pell: Ich bin diese Leiter vierzigmal hochgeklettert. Nie bezahlt worden. Nie was gelernt. Sehr beständig.")],
             [("Old Pell: Rung four. Halfway. That's where most people start counting their money. Don't.", "Old Pell: Sprosse vier. Halbzeit. Da fangen die meisten an, ihr Geld zu zählen. Lass das.")],
             [("Old Pell: Good. Now listen: when you win, make Sabine write the promise on the ladder board. In chalk. With a witness.", "Old Pell: Gut. Jetzt hör zu: Wenn du gewinnst, lass Sabine das Versprechen auf die Leitertafel schreiben. In Kreide. Mit Zeugen."),
              ("Old Pell: My goat will witness. She's very reliable. More than Sabine, anyway.", "Old Pell: Meine Ziege bezeugt das. Sie ist sehr zuverlässig. Jedenfalls mehr als Sabine.")], 2300),
        rung(5, "yusra", 3, 25, "right", tr("Mirage Dancer Yusra", "Spiegeltänzerin Yusra"), team(("Velvessa", 44), ("Orrlet", 44), ("Hazejel", 45)),
             [("Yusra: I dance in the heat shimmer. From far away I look like an oasis. Up close, I look like a bill.", "Yusra: Ich tanze im Hitzeflimmern. Von Weitem sehe ich aus wie eine Oase. Aus der Nähe wie eine Rechnung.")],
             [("Yusra: Rung five. Try not to fall for me. Everyone does, then they fall off.", "Yusra: Sprosse fünf. Versuch, nicht auf mich reinzufallen. Alle tun es, dann fallen sie runter.")],
             [("Yusra: Real after all. How disappointing for both of us.", "Yusra: Also doch echt. Wie enttäuschend für uns beide.")], 2350),
        rung(6, "brannt", 8, 28, "left", tr("Caravan Guard Brannt", "Karawanenwache Brannt"), team(("Caravant", 45), ("Duneshrew", 45), ("Wadishell", 45)),
             [("Brannt: I guard caravans. Fewer every year. I'm starting to think it's the bells.", "Brannt: Ich bewache Karawanen. Jedes Jahr weniger. Ich glaube langsam, es liegt an den Glocken.")],
             [("Brannt: Rung six. Last one outside. After me, it's Sabine's house, Sabine's rules.", "Brannt: Sprosse sechs. Die letzte draußen. Nach mir ist es Sabines Haus und Sabines Regeln.")],
             [("Brannt: Go on in. Count your fingers after you shake her hand.", "Brannt: Geh rein. Zähl deine Finger, nachdem du ihr die Hand gegeben hast.")], 2400),
    ]
    # Old Pell's defeat line is the warning about the purse. His NPC id is "old_pell" (the clan
    # figure is "pell"); his dialogue keys stay glasswind_flats/pell*.
    crew[3]["win_flags"] = ["c4_pell_warned"]
    crew[3]["id"] = "old_pell"
    people = [
        npc("varro", 9, 1, "down", SIDE + "/varro", "ranger", color="8a6a3a"),
        npc("oren", 3, 5, "right", SIDE + "/oren", "elder"),
        npc("tamsin_door", 8, 31, "left", SIDE + "/tamsin_door", "villager", color="c08a5a", show_flag="s4_twin_meet"),
    ]
    for n, rows_ in [(FLATS, rows)]:
        check_rows(n, rows_)
    m = {"name": tr("Glasswind Flats", "Glaswindebene"), "region": "solenne", "biome": "route", "backdrop": "ember", "outdoor": True,
         "encounters": FLATS, "rows": rows,
         "warps": [warp(11, 2, "ochrewell", 1, 11, "right"),
                   warp(5, 12, INN, 5, 8, "up"),
                   warp(5, 33, KILN, 5, 8, "up"), warp(6, 33, KILN, 6, 8, "up")],
         "npcs": crew + people, "signs": signs,
         "secrets": [secret(0, 9, "max_tonic", "find_glasswind_west", 2), secret(11, 14, "revival_leaf", "find_glasswind_east"),
                     secret(2, 8, "power_brew", "find_glasswind_rock"), secret(0, 22, "strong_tonic", "find_glasswind_scree", 3),
                     secret(9, 26, "spark_drop", "find_glasswind_boulder")]}
    world.add_map(FLATS, m)


# --- The Glasswind Caravanserai: the ladder's top rungs and the people of the flats ------------
def caravanserai(world):
    rows = ["WWWWWWWWWWWW",
            "WCCCffffCCCW",
            "WffffffffffW",
            "WffCCffCCffW",
            "WffffffffffW",
            "WffffffffffW",
            "WCffffffffCW",
            "WffffffffffW",
            "WffffffffffW",
            "WWWWWDWWWWWW"]
    put(rows, 10, 4, "S")
    imre = wayfarer(world, INN, "imre", 3, 5, "right", tr("Ladder Second Imre", "Leiterzweiter Imre"), team(("Fulgorin", 46), ("Duneshrew", 46), ("Claspirant", 47)),
                    [("Imre: Rung seven. Second best on the ladder for nine years. I've made peace with it. Mostly with drink.", "Imre: Sprosse sieben. Seit neun Jahren Zweitbester auf der Leiter. Ich habe meinen Frieden damit gemacht. Hauptsächlich mit Schnaps.")],
                    [("Imre: Beat me and you meet Dario. Lose and you meet the floor. I recommend the floor.", "Imre: Schlag mich, dann triffst du Dario. Verlier, dann triffst du den Boden. Ich empfehle den Boden.")],
                    [("Imre: Third best, then. A new low. Refreshing.", "Imre: Dann eben Drittbester. Ein neuer Tiefpunkt. Erfrischend.")], 2450)
    imre["beaten_flag"] = "ladder_rung_7"
    imre["show_flag"] = "ladder_rung_6"
    dario = wayfarer(world, INN, "dario", 8, 5, "left", tr("Ladder Champion Dario", "Leiterchampion Dario"), team(("Zenithare", 47), ("Habobrax", 47), ("Noonsoral", 48)),
                     [("Dario: Champion. Mother's idea. I wanted to be a baker. Bread doesn't throw sand in your eyes.", "Dario: Champion. Mutters Idee. Ich wollte Bäcker werden. Brot wirft einem keinen Sand in die Augen.")],
                     [("Dario: Rung eight. Nobody's ever beaten me. Mother made sure of that. I'd like to know how it feels.", "Dario: Sprosse acht. Mich hat noch keiner geschlagen. Dafür hat Mutter gesorgt. Ich würde gern wissen, wie sich das anfühlt.")],
                     [("Dario: So that's losing. Lighter than I thought. Go get your purse. Read the back first.", "Dario: Das ist also Verlieren. Leichter als gedacht. Hol dir deinen Beutel. Lies vorher die Rückseite.")], 2600)
    dario["beaten_flag"] = "ladder_rung_8"
    dario["show_flag"] = "ladder_rung_7"
    people = [
        npc("keeper", 2, 2, "down", SIDE + "/keeper", "elder"),
        npc("trader", 9, 2, "down", SIDE + "/trader", "villager"),
        npc("sabine", 5, 2, "down", SIDE + "/sabine", "elder", color="9a5a7a"),
        npc("hesper", 1, 7, "right", SIDE + "/hesper", "elder", color="7a8a9a"),
        npc("ott", 10, 7, "left", SIDE + "/ott", "villager"),
        npc("ilse", 6, 4, "down", SIDE + "/ilse", "ranger", color="5a8a5a"),
        npc("tamsin", 3, 7, "right", SIDE + "/tamsin", "villager", color="c08a5a", hide_flag="s4_twin_meet"),
    ]
    check_rows(INN, rows)
    m = {"name": tr("Glasswind Caravanserai", "Glaswind-Karawanserei"), "region": "solenne", "biome": "town", "backdrop": "ember",
         "rows": rows, "warps": [warp(5, 9, FLATS, 5, 13, "down")],
         "npcs": [imre, dario] + people,
         "signs": [{"x": 10, "y": 4, "dialogue": SIDE + "/board"}],
         "secrets": [secret(11, 5, "max_tonic", "find_caravanserai_cellar")]}
    world.add_map(INN, m)


# --- The Mirage Kiln: a glassworks swallowed by the sand, three floors -------------------------
def kiln(world):
    rows0 = ["@@@@@==@@@@@",
             "@..........@",
             "@.:......:.@",
             "@..........@",
             "@::..@@..::@",
             "@::..@@..::@",
             "@..........@",
             "@.:......:.@",
             "@..........@",
             "@@@@@__@@@@@"]
    rows1 = ["@@@@@==@@@@@",
             "@..........@",
             "@.::....::.@",
             "@..........@",
             "@...@..@...@",
             "@::......::@",
             "@..........@",
             "@..........@",
             "@..........@",
             "@@@@@==@@@@@"]
    rows2 = ["@@@@@@@@@@@@",
             "@..........@",
             "@:..CCCC..:@",
             "@..........@",
             "@..........@",
             "@::......::@",
             "@..........@",
             "@@@@@==@@@@@"]
    floors = [rows0, rows1, rows2]
    text = {}
    signs = [[], [], []]
    for n, v in enumerate(LENSES):
        rows = floors[n]
        for i, (x, y) in enumerate(v["cells"]):
            put(rows, x, y, "S")
            key = "lens_%d_%d" % (n + 1, i + 1)
            text[key] = {"lines": lines(v["names"][i]), "action": "bell %s %d %d lens" % (v["flag"], v["order"].index(i) + 1, len(v["cells"]))}
            signs[n].append({"x": x, "y": y, "dialogue": "%s/%s" % (KILN, key)})
        wx, wy = v["wall"]
        put(rows, wx, wy, "S")
        text["hint_%d" % (n + 1)] = lines(v["hint"])
        signs[n].append({"x": wx, "y": wy, "dialogue": "%s/hint_%d" % (KILN, n + 1)})
    for i, (mid, f, x, y, line) in enumerate(BELLS):
        if mid != KILN:
            continue
        put(floors[f], x, y, "S")
        text["bell_%d" % (i + 1)] = bell_entry(i + 1, line)
        signs[f].append({"x": x, "y": y, "dialogue": "%s/bell_%d" % (KILN, i + 1)})
    text["bell_empty"] = lines(("Nothing left here but a ring in the dust.", "Hier ist nichts mehr außer einem Ring im Staub."))
    # Floor 2: Tamsin's 'twin' scarf and Hesper's ledger.
    put(rows1, 1, 8, "S")
    text["scarf"] = {"if": dict(stage("s4_twin", 0), flag="s4_twin_asked"), "else": "scarf_plain",
                     "lines": lines(("A child's scarf on a nail, tied with a terrible knot. Stitched in the corner: a sand-glass, the crew's mark.", "Ein Kinderschal an einem Nagel, mit einem furchtbaren Knoten. In die Ecke gestickt: eine Sanduhr, das Zeichen der Bande."),
                                    ("You take it to show Tamsin.", "Du nimmst ihn mit, um ihn Tamsin zu zeigen.")),
                     "action": "quest_stage s4_twin 1"}
    text["scarf_plain"] = lines(("A row of nails with crew coats on them. One coat is child-sized.", "Eine Reihe Nägel mit Bandenmänteln. Ein Mantel hat Kindergröße."))
    signs[1].append({"x": 1, "y": 8, "dialogue": KILN + "/scarf"})
    put(rows1, 10, 8, "S")
    text["ledger_book"] = {"if": stage("s4_bell_line", 1), "else": "ledger_book_plain",
                           "lines": lines(("A ledger in neat handwriting: 'Bell Line, new posts. Caravans led in: 14. Paid by V.: half. H.'", "Ein Buch in ordentlicher Handschrift: 'Glockenlinie, neue Pfähle. Karawanen hereingeführt: 14. Bezahlt von V.: die Hälfte. H.'"),
                                          ("H. for Hesper. V. takes half. Someone should tell Hesper you know.", "H. wie Hesper. V. nimmt die Hälfte. Jemand sollte Hesper sagen, dass du es weißt.")),
                           "action": "quest_stage s4_bell_line 2; set_flag c4_ledger_read"}
    text["ledger_book_plain"] = {"lines": lines(("A ledger of caravans 'found' on the flats. At the bottom: 'V. takes half.' Underlined twice.", "Ein Buch über Karawanen, die auf der Ebene 'gefunden' wurden. Ganz unten: 'V. nimmt die Hälfte.' Zweimal unterstrichen."),),
                                 "action": "set_flag c4_ledger_read"}
    signs[1].append({"x": 10, "y": 8, "dialogue": KILN + "/ledger_book"})
    put(rows0, 10, 1, "S")
    text["sign"] = lines(("MIRAGE KILN - STAFF ONLY. Staff: everyone who doesn't leave.", "SPIEGELBRENNEREI - NUR PERSONAL. Personal: alle, die nicht gehen."),)
    signs[0].append({"x": 10, "y": 1, "dialogue": KILN + "/sign"})
    world.add_text(KILN, text)

    crew0 = [
        wayfarer(world, KILN, "aske", 3, 3, "right", tr("Glass Cutter Aske", "Glasschneiderin Aske"), team(("Obelith", 44), ("Solkit", 45)),
                 [("Aske: I cut glass into gems. Sell them as gems. Buyers cut themselves on the truth.", "Aske: Ich schleife Glas zu Edelsteinen. Verkaufe sie als Edelsteine. Die Käufer schneiden sich an der Wahrheit.")],
                 [("Aske: A visitor. Sharp. Let's see if you shatter.", "Aske: Besuch. Scharf. Mal sehen, ob du zersplitterst.")],
                 [("Aske: Chipped. Don't tell the buyers.", "Aske: Angeschlagen. Sag's nicht den Käufern.")], 2250),
        wayfarer(world, KILN, "bree", 8, 6, "left", tr("Crew Lookout Bree", "Bandenspäherin Bree"), team(("Velvessa", 45), ("Claspirant", 45)),
                 [("Bree: I watch the door. Nobody's come in who wasn't supposed to. You're the first. Congratulations.", "Bree: Ich bewache die Tür. Hier kam noch nie jemand rein, der nicht sollte. Du bist die Erste. Glückwunsch.")],
                 [("Bree: Lookouts don't lose. We just see it coming.", "Bree: Späher verlieren nicht. Wir sehen es nur kommen.")],
                 [("Bree: Saw that coming. Didn't help.", "Bree: Hab's kommen sehen. Hat nicht geholfen.")], 2300),
        wayfarer(world, KILN, "hob", 3, 7, "right", tr("Kiln Stoker Hob", "Ofenheizer Hob"), team(("Scaldcoil", 45), ("Ardlume", 45), ("Fulgorin", 46)),
                 [("Hob: Hot work. Pays in glass beads. Glass beads don't buy water. I've checked.", "Hob: Heiße Arbeit. Bezahlt wird in Glasperlen. Für Glasperlen gibt's kein Wasser. Hab's probiert.")],
                 [("Hob: You're letting the heat out. That's a fight.", "Hob: Du lässt die Hitze raus. Das gibt Ärger.")],
                 [("Hob: Cooled off. First time in years.", "Hob: Abgekühlt. Zum ersten Mal seit Jahren.")], 2350),
    ]
    crew1 = [
        wayfarer(world, KILN, "lark", 3, 6, "right", tr("Crew Fence Lark", "Bandenhehler Lark"), team(("Caravant", 46), ("Wadishell", 46), ("Saltsprig", 46)),
                 [("Lark: I sell what caravans lose. Caravans lose a lot round here. Funny, that.", "Lark: Ich verkaufe, was Karawanen verlieren. Karawanen verlieren hier eine Menge. Komisch, oder.")],
                 [("Lark: Everything's for sale. Your Spirlings first.", "Lark: Alles ist zu verkaufen. Deine Spirlings zuerst.")],
                 [("Lark: No sale. Hate that.", "Lark: Kein Geschäft. Hasse das.")], 2400),
        wayfarer(world, KILN, "odo", 8, 3, "left", tr("Glassblower Odo", "Glasbläser Odo"), team(("Obelith", 47), ("Rollibex", 46)),
                 [("Odo: I blow the bottles for the fake oasis water. Same water, fancier bottle, triple price.", "Odo: Ich blase die Flaschen für das falsche Oasenwasser. Dasselbe Wasser, schickere Flasche, dreifacher Preis.")],
                 [("Odo: Hold your breath. I always do.", "Odo: Halt die Luft an. Mach ich immer.")],
                 [("Odo: Out of breath. Occupational hazard.", "Odo: Außer Atem. Berufsrisiko.")], 2450),
    ]
    rusk = wayfarer(world, KILN, "rusk", 6, 6, "down", tr("Poacher Rusk", "Wilderer Rusk"), team(("Spinnarow", 47), ("Palmop", 47), ("Spinnub", 46)),
                    [("Rusk: Lovely field guide, this. Every den, every rock. The naturalist sold it to me herself. Very proud of her work.", "Rusk: Schöner Feldführer. Jeder Bau, jeder Stein. Die Naturforscherin hat ihn mir selbst verkauft. Sehr stolz auf ihre Arbeit.")],
                    [("Rusk: You're in the book too. Under 'nuisance'.", "Rusk: Du stehst auch im Buch. Unter 'Plage'.")],
                    [("Rusk: Take the guide. I've memorised the good pages anyway. Joking. Mostly.", "Rusk: Nimm den Führer. Die guten Seiten kann ich sowieso auswendig. Spaß. Größtenteils.")], 2500)
    rusk["show_flag"] = "s4_census_done"
    rusk["beaten_flag"] = "kiln_rusk_beaten"
    crew2 = [
        wayfarer(world, KILN, "garr", 9, 4, "left", tr("Crew Muscle Garr", "Bandenschläger Garr"), team(("Dunebastion", 47), ("Bakedillon", 47)),
                 [("Garr: I stand by the door and look big. Some days I also am big.", "Garr: Ich stehe an der Tür und sehe groß aus. An manchen Tagen bin ich auch groß.")],
                 [("Garr: Boss is busy. Being chained up. Don't ask.", "Garr: Der Chef ist beschäftigt. Mit Angekettet-Sein. Frag nicht.")],
                 [("Garr: Smaller than I looked. Noted.", "Garr: Kleiner, als ich aussah. Notiert.")], 2550),
    ]
    venn = {"id": "venn", "x": 6, "y": 3, "facing": "down", "dialogue": SIDE + "/venn", "sprite": "elder", "color": "7aa0b0"}
    for n, rows in enumerate(floors):
        check_rows("%s floor %d" % (KILN, n), rows)
    f0 = {"name": tr("Mirage Kiln", "Spiegelbrennerei"), "region": "solenne", "biome": "dungeon", "backdrop": "ember", "encounters": KILN,
          "rows": rows0,
          "warps": [warp(5, 9, FLATS, 5, 32, "down"), warp(6, 9, FLATS, 6, 32, "down"),
                    warp(5, 0, KILN + "@1", 5, 8, "up"), warp(6, 0, KILN + "@1", 6, 8, "up")],
          "npcs": crew0, "signs": signs[0],
          "blocks": [gate(5, 0, "kiln_lens_1"), gate(6, 0, "kiln_lens_1")],
          "secrets": [secret(11, 3, "max_tonic", "find_kiln_crate", 2), secret(0, 6, "revival_leaf", "find_kiln_ash")]}
    f1 = {"name": tr("Mirage Kiln, furnace hall", "Spiegelbrennerei, Ofenhalle"), "rows": rows1,
          "warps": [warp(5, 9, KILN, 5, 1, "down"), warp(6, 9, KILN, 6, 1, "down"),
                    warp(5, 0, KILN + "@2", 5, 6, "up"), warp(6, 0, KILN + "@2", 6, 6, "up")],
          "npcs": crew1 + [rusk], "signs": signs[1],
          "blocks": [gate(5, 0, "kiln_lens_2"), gate(6, 0, "kiln_lens_2")],
          "secrets": [secret(4, 4, "power_brew", "find_kiln_furnace"), secret(11, 5, "spark_drop", "find_kiln_vent")]}
    f2 = {"name": tr("Mirage Kiln, glass gallery", "Spiegelbrennerei, Glasgalerie"), "rows": rows2,
          "warps": [warp(5, 7, KILN + "@1", 5, 1, "down"), warp(6, 7, KILN + "@1", 6, 1, "down")],
          "npcs": crew2 + [venn], "signs": signs[2],
          "secrets": [secret(10, 1, "max_tonic", "find_kiln_gallery", 2)]}
    f0["floors"] = [f1, f2]
    world.add_map(KILN, f0)


def main():
    world = common.World()
    build(world)
    german = dict(common.GERMAN)
    common.GERMAN.clear()
    world.write()
    path = os.path.join(common.ROOT, "tools", "i18n", "de_solenne_more.py")
    with open(path, "w") as f:
        f.write("# German texts for the Glasswind Flats, the Caravanserai and the Mirage Kiln (Act IV).\n")
        f.write("# Written by tools/art/world/solenne_more.py from its tr()/lines() pairs; EXTRA below is kept by hand there.\n")
        f.write("T = {\n")
        for en in sorted(set(german) | set(EXTRA)):
            de = german.get(en, EXTRA.get(en))
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(de, ensure_ascii=False)))
        f.write("}\n")
    print("solenne_more: %d German texts" % len(set(german) | set(EXTRA)))


# German texts that are not in a map or dialogue file: side goals, story duels, the lens puzzle.
EXTRA = {
    # Lens puzzle (Overworld.SWITCH_LINES "lens")
    "The lenses send the light up the stair. It stays lit.": "Die Linsen schicken das Licht die Treppe hinauf. Es bleibt hell.",
    "The lens cracks the light into rainbows, and every lens swings back. Start over.": "Die Linse bricht das Licht in Regenbögen, und alle Linsen schwenken zurück. Fang von vorn an.",
    "The lens turns. A spot of sun crawls up the wall.": "Die Linse dreht sich. Ein Sonnenfleck kriecht die Wand hinauf.",
    "The last lens turns, the light hits the stair, and the glass door melts aside!": "Die letzte Linse dreht sich, das Licht trifft die Treppe, und die Glastür schmilzt beiseite!",
    # Side goals (data/quests.json)
    "Ladder Master Sabine's Glasswind Ladder: eight Wayfarers, one rung each. Climb it and claim the purse.": "Leitermeisterin Sabines Glaswind-Leiter: acht Wayfarer, je eine Sprosse. Erklimm sie und hol dir den Beutel.",
    "Bell-Mender Hesper wants the nine caravan bells lost on the Glasswind Flats and in the Mirage Kiln.": "Glockenflickerin Hesper will die neun Karawanenglocken, die auf der Glaswindebene und in der Spiegelbrennerei verloren gingen.",
    "Hesper hung your bells on the Bell Line. Ask Driver Ott how the caravans like it.": "Hesper hat deine Glocken an die Glockenlinie gehängt. Frag Fuhrmann Ott, wie es den Karawanen gefällt.",
    "Ott says the bells ring at the wrong posts. Find out where they lead in the Mirage Kiln.": "Ott sagt, die Glocken läuten an den falschen Pfählen. Finde in der Spiegelbrennerei heraus, wohin sie führen.",
    "Hesper's ledger: every caravan her bells led astray, paid for by the crew. Confront her.": "Hespers Buch: Jede Karawane, die ihre Glocken in die Irre führten, bezahlt von der Bande. Stell sie zur Rede.",
    "Hesper is beaten. The bells ring true again.": "Hesper ist besiegt. Die Glocken läuten wieder richtig.",
    "Tamsin's twin brother walked into the Mirage Kiln. Find him.": "Tamsins Zwillingsbruder ist in die Spiegelbrennerei gegangen. Finde ihn.",
    "You found a scarf with the crew's mark on it. Show it to Tamsin.": "Du hast einen Schal mit dem Zeichen der Bande gefunden. Zeig ihn Tamsin.",
    "Tamsin wants to take you to her brother herself. Meet her at the kiln door.": "Tamsin will dich selbst zu ihrem Bruder bringen. Triff sie am Tor der Brennerei.",
    "There never was a twin.": "Es gab nie einen Zwilling.",
    "Naturalist Ilse wants to sketch eight kinds of Spirling from the Glasswind. Bring each one in your team.": "Naturforscherin Ilse will acht Arten von Spirlings aus dem Glaswind zeichnen. Bring jede in deinem Team mit.",
    "Ilse sold her field guide to one keen buyer. Find out who in the Mirage Kiln.": "Ilse hat ihren Feldführer an einen eifrigen Käufer verkauft. Finde in der Spiegelbrennerei heraus, an wen.",
    "Signalman Oren wants his three heliographs on the flats turned back to the sun.": "Signalmann Oren will, dass seine drei Signalspiegel auf der Ebene wieder zur Sonne gedreht werden.",
    "The Sandglass Crew works out of the Mirage Kiln. Find out who gives the orders.": "Die Sandglas-Bande arbeitet aus der Spiegelbrennerei. Finde heraus, wer die Befehle gibt.",
    "Guide Varro knows a shortcut through the mirage. Probably.": "Führer Varro kennt eine Abkürzung durch die Luftspiegelung. Wahrscheinlich.",
    "Glasswind Flats and the Mirage Kiln": "Glaswindebene und die Spiegelbrennerei",
    # Story duels (data/story_battles.json)
    "Ladder Bouncers": "Leitertürsteher",
    "Sand Bandits": "Sandbanditen",
    "Bell-Mender Hesper": "Glockenflickerin Hesper",
    "Sandglass Crew": "Sandglas-Bande",
    "Signalman Oren": "Signalmann Oren",
    "Glassmaster Venn": "Glasmeister Venn",
}


if __name__ == "__main__":
    main()
