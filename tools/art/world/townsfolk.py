"""Townsfolk with day plans (area 3 items 1212-1215): four locals per Veydal town and one
commuter each, who spends dusk in the next town of the ring Brindlewick, Thornridge,
Copperfold, Wrenhollow, Reedhaven, Brindlewick. So every town has six people with a plan, two of
them commuting. Plans: see scripts/core/NpcSchedule.gd. After the nearby Rift is sealed (area 4
flags rift_tide_sealed and rift_cinder_sealed) everyone says a different line.

`apply(world, mid)` is called by the group that owns the town (veydal_core, veydal_wilds)."""
from common import lines, npc

RIFT = {"brindlewick": "rift_tide_sealed", "reedhaven": "rift_tide_sealed",
        "thornridge": "rift_cinder_sealed", "copperfold": "rift_cinder_sealed", "wrenhollow": "rift_cinder_sealed"}


def at(phase, x, y, facing="down", walk=None, map_id=None):
    e = {"phase": phase, "x": x, "y": y, "facing": facing}
    if walk:
        e["walk"] = [list(c) for c in walk]
    if map_id:
        e["map"] = map_id
    return e


def away(*phases):
    return {"phase": list(phases), "away": True}


# (id, sprite, home x, y, facing, home walk, schedule, (line EN, DE), (rift line EN, DE))
PEOPLE = {
    "brindlewick": [
        ("brin", "villager", 3, 1, "right", [(3, 1), (4, 1)], [at("dusk", 8, 10, "left"), away("night")],
         ("Netmender Brin: Mornings I mend nets by the north road. Evenings I tell lies about fish.", "Netzflickerin Brin: Morgens flicke ich Netze an der Nordstraße. Abends erzähle ich Lügen über Fische."),
         ("Netmender Brin: The lake sings again since the Rift went quiet. The nets feel it too.", "Netzflickerin Brin: Seit der Riss still ist, singt der See wieder. Die Netze spüren das auch.")),
        ("lotte", "villager", 8, 7, "down", [(8, 7), (8, 8)], [at("dawn", 1, 6, "right"), at("dusk", 2, 10, "right"), away("night")],
         ("Baker Lotte: First loaves at dawn, last crumbs at dusk. In between, I walk off the flour.", "Bäckerin Lotte: Die ersten Brote im Morgengrauen, die letzten Krümel in der Dämmerung. Dazwischen laufe ich das Mehl ab."),
         ("Baker Lotte: My dough rises properly again. The Rift must have been sitting on it.", "Bäckerin Lotte: Mein Teig geht wieder richtig auf. Der Riss muss darauf gesessen haben.")),
        ("tilda", "villager", 10, 10, "left", [(10, 10), (10, 11)], [at("dusk", 7, 9, "down"), away("night")],
         ("Rower Tilda: I row the shallows at noon and sit by the lamp at dusk. Simple life.", "Ruderin Tilda: Mittags rudere ich durchs Flache, in der Dämmerung sitze ich an der Laterne. Ein einfaches Leben."),
         ("Rower Tilda: The water's clear down to the stones again. You did that, didn't you?", "Ruderin Tilda: Das Wasser ist wieder klar bis auf die Steine. Das warst du, oder?")),
        ("joss", "elder", 4, 9, "left", [], [away("day"), at("night", 4, 10, "down")],
         ("Lamplighter Joss: Dawn and dusk I trim the wick. At night I keep it company.", "Laternenwärter Joss: Morgens und abends schneide ich den Docht. Nachts leiste ich ihm Gesellschaft."),
         ("Lamplighter Joss: The lamp burns steady now. No more flicker from the east.", "Laternenwärter Joss: Die Laterne brennt jetzt ruhig. Kein Flackern mehr aus dem Osten.")),
        ("wim", "villager", 8, 5, "down", [], [at("dusk", 10, 9, "left", map_id="thornridge"), away("night")],
         ("Carter Wim: Days here, evenings up in Thornridge. My cart knows the way better than I do.", "Fuhrmann Wim: Tagsüber hier, abends oben in Thornridge. Mein Karren kennt den Weg besser als ich."),
         ("Carter Wim: The road feels lighter since the Rift was sealed. Even the cart squeaks less.", "Fuhrmann Wim: Die Straße fühlt sich leichter an, seit der Riss versiegelt ist. Sogar der Karren quietscht weniger.")),
    ],
    "thornridge": [
        ("ula", "villager", 3, 15, "right", [(3, 15), (3, 16)], [at("dusk", 2, 4, "right"), away("night")],
         ("Shepherd Ula: The flock grazes the scree by day. At dusk I count them twice, up top.", "Schäferin Ula: Tagsüber grast die Herde im Geröll. In der Dämmerung zähle ich sie oben zweimal."),
         ("Shepherd Ula: My flock sleeps through the night again. No more ash on the wind.", "Schäferin Ula: Meine Herde schläft wieder durch. Keine Asche mehr im Wind.")),
        ("marek", "villager", 10, 4, "left", [(10, 4), (10, 5)], [at("dusk", 8, 15, "down"), away("night")],
         ("Stonecutter Marek: Up on the terrace I split stone. Down by the crystals I split hairs.", "Steinmetz Marek: Oben auf der Terrasse spalte ich Steine. Unten bei den Kristallen spalte ich Haare."),
         ("Stonecutter Marek: The stone rings clean again. The Rift made it sound cracked.", "Steinmetz Marek: Der Stein klingt wieder rein. Der Riss ließ ihn gesprungen klingen.")),
        ("rue", "elder", 1, 2, "right", [], [at("dusk", 4, 13, "right"), away("night")],
         ("Herbalist Rue: I pick herbs by the old door at sunrise. Dew makes them honest.", "Kräuterfrau Rue: Bei Sonnenaufgang pflücke ich Kräuter an der alten Tür. Der Tau macht sie ehrlich."),
         ("Herbalist Rue: The herbs grow sweet again. Bitter only where they should be.", "Kräuterfrau Rue: Die Kräuter wachsen wieder süß. Bitter nur, wo sie es sein sollen.")),
        ("ivo", "villager", 4, 15, "up", [], [away("dawn", "day"), at("night", 7, 13, "down")],
         ("Night Watch Ivo: I start my round at dusk and finish when the birds complain.", "Nachtwache Ivo: Meine Runde beginnt in der Dämmerung und endet, wenn die Vögel schimpfen."),
         ("Night Watch Ivo: Quiet nights since the Rift closed. I almost miss the trouble. Almost.", "Nachtwache Ivo: Ruhige Nächte, seit der Riss zu ist. Fast vermisse ich den Ärger. Fast.")),
        ("kip", "villager", 4, 2, "down", [], [at("dusk", 8, 6, "down", map_id="copperfold"), away("night")],
         ("Apprentice Kip: I learn smithing in Copperfold every evening. Days, I sweep the elder's porch.", "Lehrling Kip: Jeden Abend lerne ich in Kupferfalt schmieden. Tagsüber kehre ich die Veranda der Ältesten."),
         ("Apprentice Kip: The forge fire burns blue in Copperfold now. Smith Holt says that's luck.", "Lehrling Kip: Das Schmiedefeuer in Kupferfalt brennt jetzt blau. Schmied Holt sagt, das bringt Glück.")),
    ],
    "copperfold": [
        ("edda", "villager", 2, 15, "right", [(2, 15), (3, 15), (4, 15)], [at("dusk", 8, 13, "down"), away("night")],
         ("Cart Pusher Edda: Back and forth, back and forth. The carts don't push themselves.", "Lorenschieberin Edda: Hin und her, hin und her. Die Loren schieben sich nicht von selbst."),
         ("Cart Pusher Edda: The rails stopped humming since the Rift was sealed. Good riddance.", "Lorenschieberin Edda: Seit der Riss versiegelt ist, summen die Schienen nicht mehr. Gut so.")),
        ("sorrel", "villager", 4, 8, "up", [], [away("dawn", "day"), at("night", 4, 6, "down")],
         ("Lamp Girl Sorrel: I light the pit lamps when the day shift comes up. Then I count stars.", "Lampenmädchen Sorrel: Ich zünde die Grubenlampen an, wenn die Tagschicht hochkommt. Dann zähle ich Sterne."),
         ("Lamp Girl Sorrel: The stars look closer now. Mum says that's just clean air.", "Lampenmädchen Sorrel: Die Sterne sehen jetzt näher aus. Mama sagt, das ist nur saubere Luft.")),
        ("cobb", "elder", 5, 2, "down", [], [at("dawn", 8, 2, "down"), at("dusk", 10, 8, "left"), away("night")],
         ("Foreman Cobb: Dawn at the tower, noon at the tower, dusk at the tower. Some say I live there.", "Vorarbeiter Cobb: Morgens am Turm, mittags am Turm, abends am Turm. Manche sagen, ich wohne dort."),
         ("Foreman Cobb: The deep seams stopped shaking. We'll open the lower levels again, slowly.", "Vorarbeiter Cobb: Die tiefen Flöze beben nicht mehr. Wir öffnen die unteren Sohlen wieder, langsam.")),
        ("hask", "elder", 8, 15, "left", [], [at("dusk", 3, 10, "right"), away("night")],
         ("Old Miner Hask: Forty years below. Now I watch the young ones go down and come up.", "Alter Bergmann Hask: Vierzig Jahre unter Tage. Jetzt sehe ich den Jungen beim Ein- und Ausfahren zu."),
         ("Old Miner Hask: The mountain breathes easy again. I can hear it, you know.", "Alter Bergmann Hask: Der Berg atmet wieder ruhig. Ich kann ihn hören, weißt du.")),
        ("maud", "villager", 10, 6, "left", [], [at("dusk", 10, 9, "left", map_id="wrenhollow"), away("night")],
         ("Pedlar Maud: Copperfold nails by day, Wrenhollow rope by evening. Everyone needs both.", "Händlerin Maud: Tagsüber Nägel aus Kupferfalt, abends Seile in Zaunkönigsgrund. Jeder braucht beides."),
         ("Pedlar Maud: Business is up since the Rift closed. People buy things when they're not scared.", "Händlerin Maud: Seit der Riss zu ist, laufen die Geschäfte. Wer keine Angst hat, kauft ein.")),
    ],
    "wrenhollow": [
        ("tamsa", "villager", 10, 2, "down", [(10, 2), (10, 3)], [at("dusk", 1, 11, "right"), away("night")],
         ("Weaver Tamsa: I weave on the top terrace while the light lasts, then I go down to gossip.", "Weberin Tamsa: Ich webe auf der oberen Terrasse, solange es hell ist, dann gehe ich zum Tratschen runter."),
         ("Weaver Tamsa: My threads stopped tangling by themselves. Strange how a Rift reaches so far.", "Weberin Tamsa: Meine Fäden verheddern sich nicht mehr von selbst. Seltsam, wie weit ein Riss reicht.")),
        ("orrin", "elder", 6, 8, "left", [], [at("dusk", 1, 4, "right"), away("night")],
         ("Well-Keeper Orrin: I check the well rope at noon and the gate at dusk. Nothing ever happens.", "Brunnenwart Orrin: Mittags prüfe ich das Brunnenseil und abends das Tor. Nie passiert etwas."),
         ("Well-Keeper Orrin: The well water tastes of nothing again. That's how it should taste.", "Brunnenwart Orrin: Das Brunnenwasser schmeckt wieder nach nichts. So soll es schmecken.")),
        ("lise", "villager", 5, 15, "left", [(5, 15), (4, 15), (3, 15)], [at("dusk", 10, 12, "left"), away("night")],
         ("Goatherd Lise: The goats walk the bottom terrace and I walk behind them. Who leads whom?", "Ziegenhirtin Lise: Die Ziegen laufen die untere Terrasse ab und ich hinterher. Wer führt hier wen?"),
         ("Goatherd Lise: The goats climb up to the rim again. They hated the Rift more than I did.", "Ziegenhirtin Lise: Die Ziegen klettern wieder bis zum Rand. Sie hassten den Riss mehr als ich.")),
        ("brann", "villager", 8, 1, "down", [], [away("dawn", "day"), at("night", 6, 12, "down")],
         ("Fiddler Brann: I tune at dusk on the top terrace and play for the lamps at night.", "Fiedler Brann: In der Dämmerung stimme ich oben auf der Terrasse, nachts spiele ich für die Laternen."),
         ("Fiddler Brann: My fiddle stays in tune all night now. A small miracle, but mine.", "Fiedler Brann: Meine Fiedel bleibt jetzt die ganze Nacht gestimmt. Ein kleines Wunder, aber meins.")),
        ("ilse", "villager", 1, 4, "right", [], [at("dusk", 8, 1, "left", map_id="reedhaven"), away("night")],
         ("Basket-Maker Ilse: I weave here by day and sell in Reedhaven at dusk. Reeds for baskets, baskets for reeds.", "Korbflechterin Ilse: Tagsüber flechte ich hier, abends verkaufe ich in Schilfhafen. Schilf für Körbe, Körbe für Schilf."),
         ("Basket-Maker Ilse: The reeds by the fen stand straight again. Better baskets for everyone.", "Korbflechterin Ilse: Das Schilf am Fenn steht wieder gerade. Bessere Körbe für alle.")),
    ],
    "reedhaven": [
        ("gunn", "villager", 2, 5, "up", [], [at("dusk", 3, 5, "up"), away("night")],
         ("Eel-Catcher Gunn: West end by day, east end by evening. The eels move, so do I.", "Aalfänger Gunn: Tagsüber am Westende, abends am Ostende. Die Aale ziehen, ich auch."),
         ("Eel-Catcher Gunn: The eels came back to the stilts. They know when the water's right.", "Aalfänger Gunn: Die Aale sind zu den Pfählen zurück. Sie wissen, wann das Wasser stimmt.")),
        ("aart", "elder", 3, 1, "right", [], [at("dusk", 2, 5, "up"), away("night")],
         ("Stilt-Builder Aart: I check the stilts by the gate each morning. One wobble and I know.", "Pfahlbauer Aart: Jeden Morgen prüfe ich die Pfähle am Tor. Ein Wackeln und ich weiß es."),
         ("Stilt-Builder Aart: No wobble in weeks. The Rift shook more than the storm ever did.", "Pfahlbauer Aart: Seit Wochen kein Wackeln. Der Riss hat mehr gerüttelt als je ein Sturm.")),
        ("wenna", "villager", 8, 1, "left", [], [away("dusk", "night")],
         ("Reed-Cutter Wenna: I cut reeds from dawn to noon and sleep through the evening. Don't tell.", "Schilfschneiderin Wenna: Ich schneide Schilf vom Morgen bis Mittag und verschlafe den Abend. Nicht weitersagen."),
         ("Reed-Cutter Wenna: The reeds grow so fast now I can't keep up. A nice problem.", "Schilfschneiderin Wenna: Das Schilf wächst jetzt so schnell, dass ich nicht hinterherkomme. Ein schönes Problem.")),
        ("pip", "villager", 3, 1, "right", [], [away("dawn", "day")],
         ("Lantern Boy Pip: I'm allowed up at night to watch the lanterns on the water. It's my job!", "Laternenjunge Pip: Ich darf nachts aufbleiben und auf die Laternen im Wasser aufpassen. Das ist meine Arbeit!"),
         ("Lantern Boy Pip: The lanterns don't flicker blue anymore. I kind of liked the blue.", "Laternenjunge Pip: Die Laternen flackern nicht mehr blau. Das Blau mochte ich irgendwie.")),
        ("hanne", "villager", 6, 4, "down", [], [at("dusk", 9, 10, "left", map_id="brindlewick"), away("night")],
         ("Fishwife Hanne: Morning catch here, evening market in Brindlewick. My feet know every plank.", "Fischhändlerin Hanne: Morgens der Fang hier, abends der Markt in Brindlewick. Meine Füße kennen jede Planke."),
         ("Fishwife Hanne: Folk buy fish again without sniffing it twice. The Rift scared them off the lake.", "Fischhändlerin Hanne: Die Leute kaufen wieder Fisch, ohne zweimal zu schnuppern. Der Riss hat sie vom See vertrieben.")),
    ],
}


def apply(world, mid):
    m = world.load_map(mid)
    keep = [n for n in m.get("npcs", []) if n["id"] not in {p[0] for p in PEOPLE[mid]}]
    added = []
    entries = {}
    for pid, sprite, x, y, facing, walk, schedule, line, rift_line in PEOPLE[mid]:
        n = npc(pid, x, y, facing, "%s/%s" % (mid, pid), sprite, schedule=schedule)
        if walk:
            n["walk"] = [list(c) for c in walk]
        added.append(n)
        entries[pid] = {"lines": lines(line), "after_flag": {"flag": RIFT[mid], "lines": lines(rift_line)}}
    m["npcs"] = keep + added
    world.add_text(mid, entries)
