"""Solenne, Act IV (owner decision 2026-11-10: twelve Rifts, the last three in Solenne): the
sun-desert town of Ochrewell with its well, bazaar and clay domes, and three Rifts around it:
the Tower Rift in the wind towers (Warden Aurelio), the Oasis Rift (Warden Kaia, who sold the
oasis to the Brass Veil) and the Sun Rift under the sun palace (Warden Emrys).
Region "solenne". Edit here, then run tools/art/build_world.py.

Each Rift keeps the shape of docs/STORY.md "Rifts and Wardens" (entrance, an acolyte and two
Wayfarers, a puzzle, a spring, the Warden, a shortcut that opens on the mend), but each one has
its own layout and its own puzzle:
  tower_rift   four wind shutters opened in the order chalked on the wall ("bell ... shutter")
  oasis_rift   three sluice wheels; the lower gate drowns above water mark 1, the upper gate
               only runs dry enough to pass at mark 2 or more (open one wheel below, then the
               one above)
  sun_rift     two sun-weights (boulders) on the two dial plates hold the palace door open

How the way opens:
  saltglass -> ochrewell     rift_shade_sealed (tools/art/world/ashmere.py)
  ochrewell -> tower_rift    always
  ochrewell -> oasis_rift    rift_tower_sealed
  ochrewell -> sun_rift      rift_oasis_sealed
"""
from common import check_rows, lines, npc, secret, team, tr, warp
from rifts12 import gate, put, warden, wayfarer
from townsfolk import at, away

GROUP = ["ochrewell", "tower_rift", "oasis_rift", "sun_rift"]


def build(world):
    ochrewell(world)
    tower_rift(world)
    oasis_rift(world)
    sun_rift(world)


def finish(world, mid, m):
    check_rows(mid, m["rows"])
    m["region"] = "solenne"
    world.add_map(mid, m)


def rift_fields(mid, name, field, backdrop, rows, heal, back_to):
    """Fields every Solenne Rift shares: the way back to Ochrewell at the bottom (two arrival
    cells in `back_to`) and the shortcut down the east side, open once the Rift is mended."""
    (ax, ay), (bx, by), facing = back_to
    m = {"name": name, "biome": "rift", "backdrop": backdrop, "field": field, "encounters": mid, "heal_point": list(heal),
         "rows": rows,
         "warps": [warp(5, 21, "ochrewell", ax, ay, facing), warp(6, 21, "ochrewell", bx, by, facing)],
         "blocks": [gate(10, 18, "rift_%s_sealed" % mid[:-5])]}
    return m


def spring_and_sign(world, mid, spring, sign, title, motto):
    world.add_text(mid, {
        "spring": {"lines": lines(("Warm water seeps up through the sand. It tastes of copper and old promises.", "Warmes Wasser sickert durch den Sand. Es schmeckt nach Kupfer und alten Versprechen."),
                                  ("Your Spirlings drink and rest.", "Deine Spirlings trinken und ruhen sich aus.")),
                   "action": "heal"},
        "sign": lines(title, motto),
    })
    return [{"x": spring[0], "y": spring[1], "dialogue": mid + "/spring"}, {"x": sign[0], "y": sign[1], "dialogue": mid + "/sign"}]


# --- Ochrewell: domed clay houses round a well, the bazaar in the south -----------------------
def ochrewell(world):
    mid = "ochrewell"
    rows = ["^^^^^__^^^^^",
            "^::..__..::^",
            "^.RRR__RRR.^",
            "^.HHH__HHH.^",
            "^....__....^",
            "^.L..__..S.^",
            "^....__....^",
            "^...____...^",
            "_____.o.____",
            "_____...____",
            "^...____...^",
            "^....__....^",
            "^.RR.__.RR.^",
            "^.HH.__.HH.^",
            "^....__....^",
            "^.##.__.##.^",
            "^....__....^",
            "^::..__..L.^",
            "^....__....^",
            "^^^^^__^^^^^"]
    world.add_text(mid, {
        "sign": lines(("OCHREWELL", "OCHREWELL"), ("Ochrewell, 140 folk. 141 if you stay. Most do, one way or another.", "Ochrewell, 140 Leute. 141, wenn du bleibst. Die meisten bleiben, so oder so."),
                      ("West: the wind towers. East: the oasis. South: the sun palace. North: the way out, rarely used.", "Westen: die Windtürme. Osten: die Oase. Süden: der Sonnenpalast. Norden: der Weg hinaus, selten benutzt.")),
        "keeper": {"lines": lines(("Well Keeper Sefa: The well is free. The bucket costs extra. The rope is a matter for the Brass Veil.", "Brunnenhüterin Sefa: Der Brunnen ist frei. Der Eimer kostet extra. Das Seil ist Sache des Messingschleiers."),
                                  ("Well Keeper Sefa: Drink. Your Spirlings look like raisins.", "Brunnenhüterin Sefa: Trink. Deine Spirlings sehen aus wie Rosinen.")),
                   "action": "heal"},
        "trader": {"lines": lines(("Bazaar Trader Oskin: Everything here is genuine. Especially the fakes.", "Basarhändler Oskin: Alles hier ist echt. Besonders die Fälschungen.")),
                   "action": "shop strong_tonic max_tonic remedy cooling_gel wake_bell revival_leaf dash_brew guard_brew"},
        "factor": {"if": {"not_flag": "veil_factor_beaten"}, "else": "factor_after",
                   "lines": lines(("Factor Lusk: Ah, the one who ruined a perfectly good investment. Kaia sends her regards. Well, she sent an invoice.", "Faktor Lusk: Ah, die Person, die eine einwandfreie Investition ruiniert hat. Kaia lässt grüßen. Nun, sie hat eine Rechnung geschickt."),
                                  ("Factor Lusk: The Brass Veil does not hold grudges. We hold contracts. Yours just expired.", "Faktor Lusk: Der Messingschleier ist nicht nachtragend. Wir sind vertragstreu. Dein Vertrag ist gerade abgelaufen.")),
                   "action": "battle veil_factor"},
        "factor_after": lines(("Factor Lusk: Consider this a receipt. The Veil keeps copies of everything. Especially of people.", "Faktor Lusk: Betrachte das als Quittung. Der Schleier bewahrt von allem Kopien auf. Besonders von Menschen.")),
        "factor_defeat": lines(("Factor Lusk: Hm. Expensive. I'll put you down as a loss. Not mine, naturally.", "Faktor Lusk: Hm. Teuer. Ich verbuche dich als Verlust. Nicht als meinen, versteht sich."),
                               ("Factor Lusk: Kaia was our best buyer in years. Sold her own oasis for the price of a nicer grave.", "Faktor Lusk: Kaia war seit Jahren unsere beste Käuferin. Hat ihre eigene Oase für den Preis eines schöneren Grabes verkauft."),
                               ("Factor Lusk: Ask Emrys at the palace who signed as witness. Then ask why he never mentioned it.", "Faktor Lusk: Frag Emrys im Palast, wer als Zeuge unterschrieben hat. Und dann frag, warum er es nie erwähnt hat.")),
        "factor_lose": lines(("Factor Lusk: Come back when you can afford to lose properly.", "Faktor Lusk: Komm wieder, wenn du es dir leisten kannst, ordentlich zu verlieren.")),
        "hadi": {"lines": lines(("Potter Hadi: I make domes by day and urns by night. Business is steady in both.", "Töpfer Hadi: Tagsüber mache ich Kuppeln, nachts Urnen. Beides läuft stetig."))},
        "ranya": {"lines": lines(("Spice Seller Ranya: At dusk we all meet at the well and pretend we don't owe the Veil money.", "Gewürzhändlerin Ranya: In der Dämmerung treffen sich alle am Brunnen und tun so, als schuldeten sie dem Schleier kein Geld."))},
        "tobs": {"lines": lines(("Gravedigger Tobs: Sand's easy to dig. Harder to keep shut. The wind tells on everybody.", "Totengräber Tobs: Sand gräbt sich leicht. Zu bleibt er schwer. Der Wind verpetzt jeden."))},
    })
    folk = [("hadi", "villager", 2, 6, "right", [at("dusk", 5, 9, "right"), away("night")]),
            ("ranya", "villager", 9, 11, "left", [at("dusk", 7, 9, "left"), away("night")]),
            ("tobs", "elder", 2, 18, "right", [at("dusk", 4, 7, "right"), away("night")])]
    m = {"name": tr("Ochrewell", "Ochrewell"), "biome": "town", "backdrop": "ember", "outdoor": True,
         "heal_point": [6, 9], "rows": rows,
         "warps": [warp(5, 0, "saltglass", 5, 24, "up"), warp(6, 0, "saltglass", 6, 24, "up"),
                   warp(0, 8, "tower_rift", 5, 20, "up"), warp(0, 9, "tower_rift", 6, 20, "up"),
                   warp(11, 8, "oasis_rift", 5, 20, "up"), warp(11, 9, "oasis_rift", 6, 20, "up"),
                   warp(5, 19, "sun_rift", 5, 20, "up"), warp(6, 19, "sun_rift", 6, 20, "up")],
         "npcs": [npc("keeper", 7, 7, "down", mid + "/keeper", "elder"),
                  npc("trader", 3, 14, "down", mid + "/trader", "villager"),
                  npc("factor", 8, 16, "left", mid + "/factor", "villager", color="b08a3a", show_flag="rift_oasis_sealed", hide_flag="veil_factor_beaten")]
                 + [npc(pid, x, y, f, "%s/%s" % (mid, pid), sp, schedule=plan) for pid, sp, x, y, f, plan in folk],
         "signs": [{"x": 9, "y": 5, "dialogue": mid + "/sign"}],
         "blocks": [gate(11, 8, "rift_tower_sealed", "#"), gate(11, 9, "rift_tower_sealed", "#"),
                    gate(5, 19, "rift_oasis_sealed", "#"), gate(6, 19, "rift_oasis_sealed", "#")],
         "secrets": [secret(0, 13, "max_tonic", "find_ochrewell_west"), secret(11, 16, "revival_leaf", "find_ochrewell_bazaar"),
                     secret(11, 4, "strong_tonic", "find_ochrewell_domes", 2)],
         "square": [6, 8]}
    finish(world, mid, m)


# --- The Tower Rift: Warden Aurelio in the wind towers, four shutters ------------------------
# Shutters (x, y, name) and the order they open in, as indices into SHUTTERS.
SHUTTERS = [(1, 7, ("A shutter high on the west wall. It rattles like a cough.", "Ein Fensterladen hoch an der Westwand. Er klappert wie ein Husten.")),
            (8, 9, ("A shutter on the east wall, scoured smooth by sand.", "Ein Fensterladen an der Ostwand, vom Sand glatt geschliffen.")),
            (1, 10, ("A low shutter on the west wall. Someone scratched 'not me' into it.", "Ein niedriger Fensterladen an der Westwand. Jemand hat 'ich nicht' hineingeritzt.")),
            (5, 15, ("A shutter by the stairs, where the sand comes in first.", "Ein Fensterladen an der Treppe, wo der Sand zuerst hereinkommt."))]
SHUTTER_ORDER = [3, 1, 0, 2]


def tower_rift(world):
    mid = "tower_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^.........^",
            "^.::.....^_^",
            "^.o......^_^",
            "^......S.^_^",
            "^^^^^..^^^_^",
            "^........^_^",
            "^..:::...^_^",
            "^..:::...^_^",
            "^........^_^",
            "^...S....^_^",
            "^^^^^^..^^_^",
            "^::.....:^_^",
            "^::......^_^",
            "^........^_^",
            "^.::...::^_^",
            "^........^_^",
            "^^^^..^^^^.^",
            "^..........^",
            "^.::....::.^",
            "^^^^^..^^^^^"]
    signs = spring_and_sign(world, mid, (2, 4), (7, 5), ("THE TOWER RIFT", "DER TURMRISS"),
                            ("The wind towers breathe for the whole town. Someone stopped their breath.", "Die Windtürme atmen für die ganze Stadt. Jemand hat ihnen den Atem genommen."))
    for i, (x, y, text) in enumerate(SHUTTERS):
        put(rows, x, y, "|")
        key = "shutter_%d" % (i + 1)
        world.add_text(mid, {key: {"lines": lines(text), "action": "bell tower_rift_open %d %d shutter" % (SHUTTER_ORDER.index(i) + 1, len(SHUTTERS))}})
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, key)})
    world.add_text(mid, {"hint": lines(("Chalked on the wall: Start where the sand comes in. Then east. Then high west, then low west. Then pray.", "An die Wand gekreidet: Fang an, wo der Sand hereinkommt. Dann Osten. Dann hoch West, dann tief West. Dann beten."))})
    signs.append({"x": 4, "y": 11, "dialogue": mid + "/hint"})
    m = rift_fields(mid, tr("Tower Rift", "Turmriss"), "ash_storm", "ridge", rows, (2, 5), ((1, 8), (1, 9), "left"))
    m["blocks"] += [gate(5, 6, "tower_rift_open"), gate(6, 6, "tower_rift_open")]
    m["npcs"] = [
        wayfarer(world, mid, "pell", 7, 17, "left", tr("Rift Acolyte Pell", "Riss-Akolyth Pell"), team(("Zephlet", 35), ("Talusk", 35), ("Lanternel", 35)),
                 [("Pell: Aurelio says the towers stopped out of grief. The towers say nothing. They're towers.", "Pell: Aurelio sagt, die Türme haben aus Trauer aufgehört. Die Türme sagen nichts. Es sind Türme.")],
                 [("Pell: Nobody climbs to Aurelio without a duel. He insists. He also insists on applause.", "Pell: Niemand steigt ohne Duell zu Aurelio hinauf. Er besteht darauf. Er besteht auch auf Applaus.")],
                 [("Pell: Go on up. Clap at the end, or he'll make you do it again.", "Pell: Geh hoch. Klatsch am Ende, sonst lässt er dich alles noch einmal machen.")], 1750, sprite="warden"),
        wayfarer(world, mid, "yara", 2, 14, "right", tr("Sand Courier Yara", "Sandkurierin Yara"), team(("Shalebat", 35), ("Duskdigger", 36), ("Talusgard", 35)),
                 [("Yara: I deliver letters across the dunes. Half of them are wills. The other half are why.", "Yara: Ich trage Briefe über die Dünen. Die Hälfte sind Testamente. Die andere Hälfte ist der Grund dafür.")],
                 [("Yara: Sign here. And here. And here, that's the one where you lose.", "Yara: Unterschreib hier. Und hier. Und hier, das ist die Stelle, an der du verlierst.")],
                 [("Yara: Delivered. Return to sender.", "Yara: Zugestellt. Zurück an den Absender.")], 1780),
        wayfarer(world, mid, "gideon", 7, 10, "left", tr("Shutterman Gideon", "Ladenmann Gideon"), team(("Tempestrel", 36), ("Zephlet", 36), ("Lanternel", 36)),
                 [("Gideon: Open the shutters in the wrong order and the wind sulks. Like my wife. Rest her.", "Gideon: Öffne die Läden in der falschen Reihenfolge, und der Wind schmollt. Wie meine Frau. Sie ruhe in Frieden.")],
                 [("Gideon: I oiled these hinges for forty years. Let's see if you squeak.", "Gideon: Ich habe diese Angeln vierzig Jahre lang geölt. Mal sehen, ob du quietschst.")],
                 [("Gideon: Not a squeak. Annoying.", "Gideon: Kein Quietschen. Ärgerlich.")], 1800),
        warden(world, mid, "tower", "Aurelio", team(("Tempestrel", 36), ("Zenithare", 37), ("Mirassil", 36), ("Dunebastion", 37), ("Orrerine", 37)), "sandstorm", "echo_squall", 1900,
               [("Aurelio: Silence, please. I am grieving for the wind. It has been gone a week. I've been gone longer.", "Aurelio: Ruhe, bitte. Ich trauere um den Wind. Er ist seit einer Woche fort. Ich schon länger.")],
               [("Aurelio: A visitor. How tragic for you. The towers stopped breathing, and so, artistically speaking, did I.", "Aurelio: Ein Besuch. Wie tragisch für dich. Die Türme haben aufgehört zu atmen, und ich, künstlerisch gesehen, auch."),
                ("Aurelio: Someone in this town paid the wind to leave. I intend to find out who. After my nap. After this duel.", "Aurelio: Jemand in dieser Stadt hat den Wind bezahlt, damit er geht. Ich werde herausfinden, wer. Nach meinem Nickerchen. Nach diesem Duell.")],
               [("Aurelio: ...Ah. A draught. My Tempestrel is laughing. It hasn't laughed since my last poem.", "Aurelio: ...Ah. Ein Luftzug. Mein Tempestrel lacht. Das hat es seit meinem letzten Gedicht nicht getan."),
                ("Aurelio: Very well, mend it with me. But I'm telling everyone it was my idea.", "Aurelio: Also gut, flick ihn mit mir. Aber ich erzähle allen, es war meine Idee.")],
               [("Aurelio: The towers breathe. Ochrewell will cool down, and so will its tempers. Some of them.", "Aurelio: Die Türme atmen. Ochrewell wird abkühlen, und seine Gemüter auch. Einige davon."),
                ("Aurelio: Take this crystal, Squall. And a tip: Kaia at the oasis smiles too much for someone with that little water.", "Aurelio: Nimm diesen Kristall, Squall. Und einen Rat: Kaia an der Oase lächelt zu viel für jemanden mit so wenig Wasser.")],
               [("Aurelio: I wrote an elegy for the Undrawn. It's nine hours long. You're in it, briefly.", "Aurelio: Ich habe eine Elegie auf das Ungezeichnete geschrieben. Sie dauert neun Stunden. Du kommst darin vor, kurz.")]),
    ]
    m["signs"] = signs
    finish(world, mid, m)


# --- The Oasis Rift: Warden Kaia, three sluice wheels and a drowned gate ----------------------
def oasis_rift(world):
    mid = "oasis_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^.........^",
            "^~~,,....^_^",
            "^~~...o..^_^",
            "^,,....S.^_^",
            "^^^^..^^^^_^",
            "^~~......^_^",
            "^~~.,,,..^_^",
            "^...,,,.S^_^",
            "^.S......^_^",
            "^~~......^_^",
            "^^^^..^^^^_^",
            "^,,......^_^",
            "^,,...~~.^_^",
            "^S....~~.^_^",
            "^.......S^_^",
            "^........^_^",
            "^^^^..^^^^.^",
            "^..........^",
            "^.,,....,,.^",
            "^^^^^..^^^^^"]
    signs = spring_and_sign(world, mid, (6, 4), (7, 5), ("THE OASIS RIFT", "DER OASENRISS"),
                            ("Once the greenest place in Solenne. Now under new management.", "Einst der grünste Ort Solennes. Jetzt unter neuer Leitung."))
    wheels = [("oasis_sluice_a", (1, 15)), ("oasis_sluice_b", (8, 9)), ("oasis_sluice_c", (8, 16))]
    for flag, (x, y) in wheels:
        world.add_text(mid, {flag: {"lines": lines(("A bronze sluice wheel. A brass plate on it reads: PROPERTY OF THE BRASS VEIL.", "Ein bronzenes Schleusenrad. Ein Messingschild darauf: EIGENTUM DES MESSINGSCHLEIERS.")),
                                    "action": "toggle " + flag}})
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (mid, flag)})
    world.add_text(mid, {"hint": lines(("Carved by the old well-diggers: Below, open one, never two, or the low gate drowns. Above, the high gate wants two.", "Von den alten Brunnengräbern eingeritzt: Unten öffne eines, nie zwei, sonst ersäuft das untere Tor. Oben will das hohe Tor zwei."))})
    signs.append({"x": 2, "y": 10, "dialogue": mid + "/hint"})
    m = rift_fields(mid, tr("Oasis Rift", "Oasenriss"), "high_tide", "field", rows, (6, 5), ((10, 8), (10, 9), "right"))
    m["sluices"] = [flag for flag, _ in wheels]
    m["blocks"] += [gate(4, 6, "_water_ge_2", "~"), gate(5, 6, "_water_ge_2", "~"),
                    gate(4, 12, "_water_le_1", "~"), gate(5, 12, "_water_le_1", "~")]
    m["npcs"] = [
        wayfarer(world, mid, "noor", 7, 17, "left", tr("Rift Acolyte Noor", "Riss-Akolythin Noor"), team(("Kelpup", 36), ("Lumenewt", 36), ("Kelphound", 36)),
                 [("Noor: Kaia says the water left on its own. Water doesn't sign receipts, though.", "Noor: Kaia sagt, das Wasser sei von selbst gegangen. Wasser unterschreibt allerdings keine Quittungen.")],
                 [("Noor: You want Kaia? She's busy being adored. Duel first.", "Noor: Du willst zu Kaia? Sie ist damit beschäftigt, angebetet zu werden. Erst ein Duell.")],
                 [("Noor: Fine. Ask her where the water went. Watch her smile.", "Noor: Schön. Frag sie, wohin das Wasser ist. Achte auf ihr Lächeln.")], 1850, sprite="warden"),
        wayfarer(world, mid, "hollis", 2, 13, "right", tr("Water Clerk Hollis", "Wasserschreiber Hollis"), team(("Brinelet", 36), ("Saltspire", 37), ("Kelphound", 36)),
                 [("Hollis: I count every drop that leaves the oasis. Lately I count the people who ask about it.", "Hollis: Ich zähle jeden Tropfen, der die Oase verlässt. In letzter Zeit zähle ich die Leute, die danach fragen.")],
                 [("Hollis: Your name isn't on my list. Let's fix that.", "Hollis: Dein Name steht nicht auf meiner Liste. Ändern wir das.")],
                 [("Hollis: Struck off. In ink, sadly.", "Hollis: Gestrichen. Mit Tinte, leider.")], 1880),
        wayfarer(world, mid, "suni", 7, 7, "left", tr("Date Picker Suni", "Dattelpflückerin Suni"), team(("Kelphound", 37), ("Frondmere", 37), ("Ferrowyn", 37)),
                 [("Suni: The palms are thirsty. So am I. Only one of us gets paid for it.", "Suni: Die Palmen haben Durst. Ich auch. Nur eine von uns wird dafür bezahlt.")],
                 [("Suni: I pick dates. Today I'm picking a fight.", "Suni: Ich pflücke Datteln. Heute pflücke ich einen Streit.")],
                 [("Suni: Bitter harvest. Go on, Kaia's waiting. She's always waiting for someone.", "Suni: Bittere Ernte. Geh nur, Kaia wartet. Sie wartet immer auf jemanden.")], 1900),
        warden(world, mid, "oasis", "Kaia", team(("Saltcrown", 37), ("Leviarch", 38), ("Ferrowyn", 37), ("Glasstarn", 37), ("Saltspire", 38)), "dry_well", "echo_dawn_mend", 2000,
               [("Kaia: Welcome to the oasis! Mind the cracks. They used to be the lake.", "Kaia: Willkommen in der Oase! Pass auf die Risse auf. Das war früher der See.")],
               [("Kaia: The Rift drank the water. Terrible. Tragic. Nothing anyone could have done, least of all me.", "Kaia: Der Riss hat das Wasser getrunken. Schrecklich. Tragisch. Niemand hätte etwas tun können, am allerwenigsten ich."),
                ("Kaia: Still, a Warden must guard her Rift. Even from people who ask too many questions.", "Kaia: Trotzdem muss eine Warden ihren Riss bewachen. Selbst vor Leuten, die zu viele Fragen stellen.")],
               [("Kaia: ...Oh, fine. You'd find the contract anyway. Everyone does, eventually.", "Kaia: ...Ach, schön. Du würdest den Vertrag sowieso finden. Das tun alle, irgendwann."),
                ("Kaia: I sold the water rights to the Brass Veil. The Rift opened the night they started pumping. Bad timing. Good price.", "Kaia: Ich habe die Wasserrechte an den Messingschleier verkauft. Der Riss ging in der Nacht auf, als sie zu pumpen anfingen. Schlechtes Timing. Guter Preis."),
                ("Kaia: I've worked for the Veil for six years. Ochrewell paid me in thanks. The Veil paid me in gold. Guess which buys bread.", "Kaia: Ich arbeite seit sechs Jahren für den Schleier. Ochrewell hat mich mit Dank bezahlt. Der Schleier mit Gold. Rate, wovon man Brot kauft."),
                ("Kaia: Mend it, then. The contract has a clause for acts of heroism. You'll find it tedious.", "Kaia: Dann flick ihn eben. Der Vertrag hat eine Klausel für Heldentaten. Du wirst sie ermüdend finden.")],
               [("Kaia: The water's back. The Veil will want it back too. I'd leave town before they send their regards.", "Kaia: Das Wasser ist zurück. Der Schleier wird es auch zurückwollen. Ich würde die Stadt verlassen, bevor er Grüße schickt."),
                ("Kaia: Here, Dawn Mend. A healing art, from me. Yes, I see the irony. I charge extra for it.", "Kaia: Hier, Dawn Mend. Eine Heilkunst, von mir. Ja, ich sehe die Ironie. Die kostet extra.")],
               [("Kaia: The Veil fired me. Then the town hired me back. Turns out they needed someone who knows how thieves think.", "Kaia: Der Schleier hat mich entlassen. Dann hat die Stadt mich wieder eingestellt. Offenbar brauchte sie jemanden, der weiß, wie Diebe denken.")]),
    ]
    m["signs"] = signs
    finish(world, mid, m)


# --- The Sun Rift: Warden Emrys under the sun palace, two sun-weights on the dial ------------
def sun_rift(world):
    mid = "sun_rift"
    rows = ["^^^^^^^^^^^^",
            "^^^^.XX.^^^^",
            "^^.........^",
            "^.L.....L^_^",
            "^......o.^_^",
            "^.S......^_^",
            "^^^^^..^^^_^",
            "^.P....P.^_^",
            "^........^_^",
            "^...B..B.^_^",
            "^........^_^",
            "^.S......^_^",
            "^^^^^^==^^_^",
            "^::.....:^_^",
            "^::......^_^",
            "^...LL...^_^",
            "^.::...::^_^",
            "^........^_^",
            "^^^^..^^^^.^",
            "^..........^",
            "^.::....::.^",
            "^^^^^..^^^^^"]
    signs = spring_and_sign(world, mid, (7, 4), (2, 5), ("THE SUN RIFT", "DER SONNENRISS"),
                            ("Under the sun palace. The sundial has stopped. Nobody dares tell the sun.", "Unter dem Sonnenpalast. Die Sonnenuhr steht still. Niemand traut sich, es der Sonne zu sagen."))
    world.add_text(mid, {"hint": lines(("Palace notice: The great dial door opens while both sun-weights rest on both marks. Do not sit on the marks. This means you, Steward.", "Palastaushang: Das große Zifferblatt-Tor öffnet sich, solange beide Sonnengewichte auf beiden Marken liegen. Nicht auf die Marken setzen. Das gilt auch für dich, Verwalter."))})
    signs.append({"x": 2, "y": 11, "dialogue": mid + "/hint"})
    m = rift_fields(mid, tr("Sun Rift", "Sonnenriss"), "dawn_glow", "ember", rows, (7, 5), ((5, 18), (6, 18), "down"))
    m["boulder_ground"] = "."
    m["puzzles"] = [{"id": "sun_dial", "flag": "sun_rift_open", "plates": [[2, 7], [7, 7]]}]
    m["blocks"] += [gate(5, 6, "sun_rift_open"), gate(6, 6, "sun_rift_open")]
    m["npcs"] = [
        wayfarer(world, mid, "corwen", 7, 17, "left", tr("Rift Acolyte Corwen", "Riss-Akolyth Corwen"), team(("Wickit", 36), ("Kindlop", 36), ("Glimmerax", 37)),
                 [("Corwen: Emrys has served four rulers. He buried two and advised the other two. Hard to say which was worse.", "Corwen: Emrys hat vier Herrschern gedient. Zwei hat er begraben, zwei beraten. Schwer zu sagen, was schlimmer war.")],
                 [("Corwen: The palace is closed to visitors. Also to residents. Duel?", "Corwen: Der Palast ist für Besucher geschlossen. Für Bewohner auch. Duell?")],
                 [("Corwen: Go on. Emrys likes people who win. He outlives them anyway.", "Corwen: Geh. Emrys mag Leute, die gewinnen. Er überlebt sie sowieso.")], 1950, sprite="warden"),
        wayfarer(world, mid, "ettie", 2, 14, "right", tr("Sundial Scholar Ettie", "Sonnenuhrgelehrte Ettie"), team(("Lanternel", 36), ("Silentra", 37), ("Wickit", 37)),
                 [("Ettie: The dial says it's noon. It's said that for nine days. I've stopped eating lunch on principle.", "Ettie: Die Uhr sagt, es ist Mittag. Das sagt sie seit neun Tagen. Ich esse aus Prinzip kein Mittagessen mehr.")],
                 [("Ettie: Let's settle this before the sun moves. So, never.", "Ettie: Klären wir das, bevor die Sonne weiterzieht. Also nie.")],
                 [("Ettie: Time well wasted.", "Ettie: Gut verschwendete Zeit.")], 1980),
        wayfarer(world, mid, "abel", 8, 8, "left", tr("Palace Steward Abel", "Palastverwalter Abel"), team(("Calderox", 37), ("Cairnhold", 37), ("Smoldrake", 37)),
                 [("Abel: I sat on one of the marks once. For a week. The door stayed open and so did my position, until it didn't.", "Abel: Ich habe mal auf einer der Marken gesessen. Eine Woche lang. Das Tor blieb offen und meine Stelle auch, bis sie es nicht mehr war.")],
                 [("Abel: The palace thanks you for your visit. Now leave or lose.", "Abel: Der Palast dankt für Ihren Besuch. Nun gehen Sie oder verlieren Sie.")],
                 [("Abel: The palace regrets any inconvenience. Mostly its own.", "Abel: Der Palast bedauert etwaige Unannehmlichkeiten. Vor allem seine eigenen.")], 2000),
        warden(world, mid, "sun", "Emrys", team(("Solmantle", 37), ("Orrerine", 38), ("Glimmerax", 37), ("Cairnhold", 38), ("Zenithare", 38)), "high_noon", "echo_radiant_lance", 2100,
               [("Emrys: The sun stopped. I've waited eighty years for it to need me. Now it does, and I'm too tired to stand up.", "Emrys: Die Sonne ist stehen geblieben. Achtzig Jahre habe ich darauf gewartet, dass sie mich braucht. Jetzt tut sie es, und ich bin zu müde zum Aufstehen.")],
               [("Emrys: So Kaia is unmasked. Yes, I signed as her witness. Someone had to read the small print. Nobody else ever does.", "Emrys: Kaia ist also enttarnt. Ja, ich habe als ihr Zeuge unterschrieben. Irgendwer musste das Kleingedruckte lesen. Sonst tut es ja nie jemand."),
                ("Emrys: Everyone in Solenne works for someone. I work for the sun. It doesn't pay either. Shall we?", "Emrys: In Solenne arbeitet jeder für jemanden. Ich arbeite für die Sonne. Die zahlt auch nicht. Wollen wir?")],
               [("Emrys: ...There. The dial moved. One minute past noon. I'd forgotten how good that feels.", "Emrys: ...Da. Die Uhr hat sich bewegt. Eine Minute nach Mittag. Ich hatte vergessen, wie gut sich das anfühlt."),
                ("Emrys: I kept the Veil's contract, you know. The clause about heroes ends their claim. Now it has a hero. Let's mend this.", "Emrys: Ich habe den Vertrag des Schleiers aufbewahrt, weißt du. Die Klausel über Helden beendet ihren Anspruch. Jetzt gibt es einen Helden. Flicken wir das.")],
               [("Emrys: The sun moves again. So does the Veil, I expect. Let them. The sun outlived every clan in this desert.", "Emrys: Die Sonne zieht wieder. Der Schleier auch, nehme ich an. Lass ihn. Die Sonne hat jeden Clan in dieser Wüste überlebt."),
                ("Emrys: Take Radiant Lance. Twelve Rifts, twelve seals. The far end of the Wide Rift will open for you now.", "Emrys: Nimm Radiant Lance. Zwölf Risse, zwölf Siegel. Das ferne Ende des Weiten Risses wird sich dir jetzt öffnen.")],
               [("Emrys: I've started a sundial for the Undrawn. Nobody knows what time it is there. Ideal working conditions.", "Emrys: Ich habe eine Sonnenuhr für das Ungezeichnete angefangen. Dort weiß niemand, wie spät es ist. Ideale Arbeitsbedingungen.")]),
    ]
    m["signs"] = signs
    finish(world, mid, m)
