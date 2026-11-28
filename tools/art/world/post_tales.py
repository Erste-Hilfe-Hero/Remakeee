#!/usr/bin/env python3
"""The four post-game region tales (owner Ali, 1.3.2): one small storyline each for Vellmarch,
Quillmarch, Halcyra and Quivermoor, beside the region's chapters. Figures, places and lore are in
docs/STORY.md ("Region tales"). Each tale has 5-6 main goals with named figures, a small mystery
and a closing moment; Quivermoor's has six lantern walker duels and a final duel.

Run: python3 tools/art/world/post_tales.py   (idempotent)
Writes data/dialogue/<region>_tale.json, tools/i18n/de_post_tales.py and patches data/quests.json
("post", the tale goals), data/story_npcs.json (the figures, ids "tale_*") and
data/story_battles.json (ids "tale_*"). Other languages: tools/i18n/locales_post_tales.py.
Figures stand on free cells near "near" that keep every walkable cell of the map reachable.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "i18n"))

GERMAN = {}
DIALOGUE = {}
SOLID = set("~THRFS#CWo^|L@wBvY")


def tr(en, de):
    if GERMAN.get(en, de) != de:
        raise SystemExit("two German texts for %r" % en)
    if len(en) > 62 and "{name}" not in en:
        raise SystemExit("longer than two lines: %r" % en)
    GERMAN[en] = de
    return en


def L(*pairs):
    return [tr(en, de) for en, de in pairs]


def entry(region, key, value):
    DIALOGUE.setdefault(region, {})[key] = value
    return "%s_tale/%s" % (region, key)


def gated(region, key, cond, lines, action, other):
    """An entry that plays [lines] and runs [action] while [cond] holds, else [other]."""
    return entry(region, key, {"if": cond, "else": other, "lines": lines, "action": action})


def until(region, key, flag, lines, other):
    """Plain lines until [flag] is set, then the entry [other]."""
    return entry(region, key, {"if": {"not_flag": flag}, "else": other, "lines": lines})


# --- Tales: goals per region ----------------------------------------------------------------
TALES = []


def tale(region, title, opens, goals):
    for gid, text, where, done in goals:
        TALES.append({"id": gid, "region": region, "act": title, "opens": opens,
                      "text": text, "where": where, "done": done})


FIGURES = {}   # map id -> list of npc dicts (with "near")
BATTLES = {}


def figure(map_id, fid, near, sprite, color, dialogue, show, hide=None, facing="down"):
    d = {"id": "tale_" + fid, "near": near, "facing": facing, "dialogue": dialogue, "sprite": sprite,
         "color": color, "show_flag": show}
    if hide:
        d["hide_flag"] = hide
    FIGURES.setdefault(map_id, []).append(d)


def duel(bid, name, team, money, defeat, lose, win_flag, ai=2):
    BATTLES["tale_" + bid] = {"trainer": name, "team": [{"species": s, "level": l} for s, l in team],
                              "ai": ai, "money": money, "defeat": defeat, "lose": lose, "win_flags": [win_flag]}
    return "battle tale_" + bid


# === Vellmarch (Era II): The Drowned Quarter ===================================================
R = "vellmarch"
tale(R, tr("Vellmarch: The Drowned Quarter", "Vellmarch: Das ertrunkene Viertel"), "story_complete", [
    ("v2t_roses", tr("Find out who chalks roses on the Hookwick locks.", "Finde heraus, wer Rosen auf die Schleusen von Hookwick malt."),
     "Hookwick", ["v2t_nico"]),
    ("v2t_ada", tr("Ask Ada Quarle in the Tallowmarket about the roses.", "Frag Ada Quarle auf dem Tallowmarket nach den Rosen."),
     "Tallowmarket", ["v2t_ada"]),
    ("v2t_book", tr("Win Ada's survey book back at the Larkspur opera.", "Gewinn Adas Vermessungsbuch in der Oper von Larkspur zurück."),
     "Larkspur Heights", ["v2t_book"]),
    ("v2t_drawn", tr("Bring the survey book to Ada in the Tallowmarket.", "Bring Ada das Vermessungsbuch auf den Tallowmarket."),
     "Tallowmarket", ["v2t_drawn"]),
    ("v2t_lamp", tr("Mend the vault, then meet Ada at the Lastlamp lamp.", "Flick den Tresor, dann triff Ada an der Lampe von Lastlamp."),
     "Lastlamp", ["v2t_done"]),
])
nico_after = entry(R, "nico_after", L(("Nico: Gran's at the Tallowmarket. Mind her temper.", "Nico: Oma ist auf dem Tallowmarket. Pass auf, sie ist launisch.")))
figure("hookwick", "nico", (6, 10), "villager", "5a7a9a", gated(R, "nico", {"not_flag": "v2t_nico"}, L(
    ("Nico: Every morning there's a chalk rose on the lock gate.", "Nico: Jeden Morgen ist eine Kreiderose am Schleusentor."),
    ("Nico: A compass rose. Like on the old guild maps.", "Nico: Eine Kompassrose. Wie auf den alten Gildenkarten."),
    ("Nico: Gran says it's nothing. Gran lies badly.", "Nico: Oma sagt, das ist nichts. Oma lügt schlecht."),
    ("Nico: Ada Quarle. Tallowmarket. Ask her, not me.", "Nico: Ada Quarle. Tallowmarket. Frag sie, nicht mich.")),
    "set_flag v2t_nico", nico_after), "story_complete")
ada_wait = entry(R, "ada_wait", L(("Ada: The opera on Larkspur Heights. Ask the prompter.", "Ada: Die Oper auf Larkspur Heights. Frag den Souffleur.")))
ada_book = gated(R, "ada_book", {"flag": "v2t_book", "not_flag": "v2t_drawn"}, L(
    ("Ada: My book. Look: the water stairs, the old bakery.", "Ada: Mein Buch. Sieh nur: die Wassertreppe, die alte Bäckerei."),
    ("Ada: With this I can draw it all again. Every street.", "Ada: Damit kann ich alles neu zeichnen. Jede Straße."),
    ("Ada: The last line belongs at the great lamp of Lastlamp.", "Ada: Die letzte Linie gehört an die große Lampe von Lastlamp."),
    ("Ada: Once the vault under it is mended. Not before.", "Ada: Sobald der Tresor darunter geflickt ist. Nicht vorher.")),
    "set_flag v2t_drawn", ada_wait)
figure("tallowmarket", "ada", (6, 10), "elder", "7a5a4a", gated(R, "ada", {"flag": "v2t_nico", "not_flag": "v2t_ada"}, L(
    ("Ada: Roses? Fine. Forty years ago they drowned my quarter.", "Ada: Rosen? Schön. Vor vierzig Jahren ertränkten sie mein Viertel."),
    ("Ada: A reservoir for the Houses. Nobody redrew the streets.", "Ada: Ein Stausee für die Häuser. Keiner zeichnete die Straßen neu."),
    ("Ada: Water nobody maps grows thin. Then it tears.", "Ada: Wasser, das keiner kartiert, wird dünn. Dann reißt es."),
    ("Ada: The Lock Rift opened that winter. Under my street.", "Ada: Der Schleusenriss ging in dem Winter auf. Unter meiner Straße."),
    ("Ada: The families moved away. Their Spirlings stayed.", "Ada: Die Familien zogen weg. Ihre Spirlinge blieben."),
    ("Ada: Hear that dull ring under the water? That's them.", "Ada: Hörst du das dumpfe Klingen unterm Wasser? Das sind sie."),
    ("Ada: We call it the Tarnish. It is only calling.", "Ada: Wir nennen es die Trübung. Es ruft nur."),
    ("Ada: So I chalk the streets back. One rose a night.", "Ada: Also male ich die Straßen zurück. Eine Rose pro Nacht."),
    ("Ada: But my survey book was sold. It's at the opera now.", "Ada: Aber mein Vermessungsbuch wurde verkauft. Es ist in der Oper.")),
    "set_flag v2t_ada", ada_book), "v2t_nico", "v2t_drawn")
merrit_after = entry(R, "merrit_after", L(("Merrit: Tell Ada the masks are back in their box.", "Merrit: Sag Ada, die Masken sind wieder in ihrer Kiste.")))
merrit_wait = until(R, "merrit_wait", "v2t_book", L(
    ("Merrit: Rehearsal. Come back once the locks are quiet.", "Merrit: Probe. Komm wieder, wenn die Schleusen still sind.")), merrit_after)
figure("larkspur_heights", "merrit", (6, 10), "ranger", "6a3a6a", gated(R, "merrit", {"flag": ["v2t_ada", "v2_rift_lock_sealed"], "not_flag": "v2t_book"}, L(
    ("Merrit: A survey book? Ah. My cue book.", "Merrit: Ein Vermessungsbuch? Ah. Mein Soufflierbuch."),
    ("Merrit: I cut masks from its pages. Streets make fine eyes.", "Merrit: Ich schneide Masken aus den Seiten. Straßen sind gute Augen."),
    ("Merrit: I didn't know they were anyone's streets.", "Merrit: Ich wusste nicht, dass es jemandes Straßen waren."),
    ("Merrit: Still, a prompter gives nothing without a scene.", "Merrit: Trotzdem, ein Souffleur gibt nichts ohne Szene her."),
    ("Merrit: Win, and the book goes home.", "Merrit: Gewinn, und das Buch geht nach Hause.")),
    duel("merrit", "Prompter Merrit", [("Lanternel", 56), ("Veilmote", 56), ("Smogpup", 57), ("Guisdame", 57)], 3600,
         entry(R, "merrit_defeat", L(("Merrit: Bravo. Take it. Most pages are still there.", "Merrit: Bravo. Nimm es. Die meisten Seiten sind noch da."),
                                     ("Merrit: Tell Ada I'm sorry. I'll come and say it myself.", "Merrit: Sag Ada, es tut mir leid. Ich sag's ihr selbst."))),
         entry(R, "merrit_lose", L(("Merrit: Curtain. Try again after the interval.", "Merrit: Vorhang. Versuch es nach der Pause noch mal."))),
         "v2t_book"), merrit_wait), "v2t_ada")
lamp_after = entry(R, "lamp_after", L(("Ada: Nico chalks the roses now. His are crooked.", "Ada: Jetzt malt Nico die Rosen. Seine sind schief.")))
lamp_wait = until(R, "lamp_wait", "v2t_done", L(("Ada: The vault first. Then we draw the last line.", "Ada: Erst der Tresor. Dann ziehen wir die letzte Linie.")), lamp_after)
figure("lastlamp", "ada_lamp", (6, 10), "elder", "7a5a4a", gated(R, "lamp", {"flag": "vellmarch_done", "not_flag": "v2t_done"}, L(
    ("Ada: The vault is mended. Now, the last street.", "Ada: Der Tresor ist geflickt. Jetzt die letzte Straße."),
    ("Ada draws one thin line: the water stair, up to the lamp.", "Ada zieht eine dünne Linie: die Wassertreppe, hoch zur Lampe."),
    ("Under the canal the dull ringing stops. It listens.", "Unter dem Kanal hört das dumpfe Klingen auf. Es lauscht."),
    ("Ada: Hum the Echo melody, {name}. They still know it.", "Ada: Summ die Echo-Melodie, {name}. Sie kennen sie noch."),
    ("One by one the left-behind calls go soft. Then still.", "Einer nach dem anderen werden die Rufe leise. Dann still."),
    ("Ada: Not gone. Heard. That was all they wanted.", "Ada: Nicht weg. Gehört. Mehr wollten sie nie."),
    ("Ada: The Old Quarter is on the map again. Thank you.", "Ada: Das alte Viertel ist wieder auf der Karte. Danke.")),
    "set_flag v2t_done", lamp_wait), "v2t_drawn")

# === Quillmarch (Era III): The Blank Street ====================================================
R = "quillmarch"
tale(R, tr("Quillmarch: The Blank Street", "Quillmarch: Die leere Gasse"), "era2_finale_done", [
    ("v3t_elva", tr("Ask in Platewick why one street always prints blank.", "Frag in Platewick, warum eine Gasse immer leer gedruckt wird."),
     "Platewick", ["v3t_elva"]),
    ("v3t_pennick", tr("Find old Pennick, who set that street, in Rimeholt.", "Finde den alten Pennick in Rimeholt, der die Gasse gesetzt hat."),
     "Rimeholt", ["v3t_pennick"]),
    ("v3t_linnet", tr("Find the girl who feeds the ink eater in Ledgerholm.", "Finde das Mädchen in Ledgerholm, das den Tintenfresser füttert."),
     "Ledgerholm", ["v3t_linnet"]),
    ("v3t_anchor", tr("Meet Linnet in Lampblack Lane, Platewick.", "Triff Linnet in der Rußgasse in Platewick."),
     "Platewick", ["v3t_anchor"]),
    ("v3t_print", tr("Mend the great press, then see the print in Proofgate.", "Flick die große Presse, dann sieh den Druck in Proofgate."),
     "Proofgate", ["v3t_done"]),
])
elva_after = entry(R, "elva_after", L(("Elva: Pennick's in Rimeholt. Bring him a scarf.", "Elva: Pennick ist in Rimeholt. Bring ihm einen Schal mit.")))
figure("platewick", "elva", (6, 10), "villager", "3a4a6a", gated(R, "elva", {"not_flag": "v3t_elva"}, L(
    ("Elva: Every map we print has one blank street.", "Elva: Jede Karte, die wir drucken, hat eine leere Gasse."),
    ("Elva: Lampblack Lane. Same plate, same ink. Always white.", "Elva: Die Rußgasse. Gleiche Platte, gleiche Tinte. Immer weiß."),
    ("Elva: The press is fine. I took it apart twice.", "Elva: Die Presse ist in Ordnung. Ich hab sie zweimal zerlegt."),
    ("Elva: Old Pennick set that lane by hand. He's in Rimeholt.", "Elva: Der alte Pennick hat die Gasse von Hand gesetzt. In Rimeholt.")),
    "set_flag v3t_elva", elva_after), "era2_finale_done")
pennick_after = entry(R, "pennick_after", L(("Pennick: Linnet's in Ledgerholm. She bites. Nicely.", "Pennick: Linnet ist in Ledgerholm. Sie beißt. Freundlich.")))
pennick_wait = until(R, "pennick_wait", "v3t_pennick", L(
    ("Pennick: Too cold to talk. The bath fumes get in my bones.", "Pennick: Zu kalt zum Reden. Die Säuredämpfe gehen mir in die Knochen.")), pennick_after)
figure("rimeholt", "pennick", (6, 10), "elder", "5a5a5a", gated(R, "pennick", {"flag": ["v3t_elva", "rift_v3_bath_sealed"], "not_flag": "v3t_pennick"}, L(
    ("Pennick: Lampblack Lane? I set it fifty years back.", "Pennick: Die Rußgasse? Die hab ich vor fünfzig Jahren gesetzt."),
    ("Pennick: The ink isn't fading. Something licks it off.", "Pennick: Die Tinte verblasst nicht. Etwas leckt sie ab."),
    ("Pennick: A small Nibbet. No home side. Came through a Rift.", "Pennick: Ein kleiner Nibbet. Ohne Heimatseite. Kam durch einen Riss."),
    ("Pennick: It eats the lane so the thin place stays open.", "Pennick: Es frisst die Gasse, damit die dünne Stelle offen bleibt."),
    ("Pennick: It wants to go back. It can't. It just smudges.", "Pennick: Es will zurück. Es kann nicht. Es verschmiert nur."),
    ("Pennick: Here we call that the Blot. It spreads from there.", "Pennick: Hier heißt das der Klecks. Von dort breitet er sich aus."),
    ("Pennick: Young Linnet feeds it. Ledgerholm. Go gently.", "Pennick: Die junge Linnet füttert es. Ledgerholm. Sei sanft.")),
    "set_flag v3t_pennick", pennick_wait), "v3t_elva")
linnet_after = entry(R, "linnet_after", L(("Linnet: Lampblack Lane. Come when the town is quiet.", "Linnet: Rußgasse. Komm, wenn die Stadt still ist.")))
linnet_wait = until(R, "linnet_wait", "v3t_linnet", L(
    ("Linnet: Go away. I'm busy. Not hiding anything.", "Linnet: Geh weg. Ich hab zu tun. Ich verstecke nichts.")), linnet_after)
figure("ledgerholm", "linnet", (6, 10), "villager", "8a4a3a", gated(R, "linnet", {"flag": ["v3t_pennick", "rift_v3_rime_sealed"], "not_flag": "v3t_linnet"}, L(
    ("Linnet: You've come to seal Dab out. Like a Rift.", "Linnet: Du willst Dab aussperren. Wie einen Riss."),
    ("Linnet: Dab hides in the lane. It has no one but me.", "Linnet: Dab versteckt sich in der Gasse. Es hat nur mich."),
    ("Linnet: Mavet would bottle it. The Guild would bill it.", "Linnet: Mavet würde es abfüllen. Die Gilde würde es abrechnen."),
    ("Linnet: Beat me first. Then maybe I'll listen.", "Linnet: Schlag mich erst. Dann hör ich vielleicht zu.")),
    duel("linnet", "Apprentice Linnet", [("Nibravure", 80), ("Filigravure", 81), ("Siltaroth", 81), ("Glacilisk", 82)], 4800,
         entry(R, "linnet_defeat", L(("Linnet: Fine. You fight like you mean well.", "Linnet: Schon gut. Du kämpfst, als meintest du es gut."),
                                     ("Linnet: Pennick says Dab needs a person, not a door.", "Linnet: Pennick sagt, Dab braucht einen Menschen, keine Tür."))),
         entry(R, "linnet_lose", L(("Linnet: Dab stays hidden. Go away.", "Linnet: Dab bleibt versteckt. Geh weg."))),
         "v3t_linnet"), linnet_wait), "v3t_pennick", "v3t_linnet")
lane_after = entry(R, "lane_after", L(("Linnet: Dab doesn't eat streets now. Only my lunch.", "Linnet: Dab frisst keine Gassen mehr. Nur mein Pausenbrot.")))
lane_wait = until(R, "lane_wait", "v3t_anchor", L(
    ("Linnet: Dab won't come out. The ledgers are too loud.", "Linnet: Dab kommt nicht raus. Die Bücher sind zu laut.")), lane_after)
figure("platewick", "linnet_lane", (4, 14), "villager", "8a4a3a", gated(R, "lane", {"flag": ["v3t_linnet", "rift_v3_ledger_sealed"], "not_flag": "v3t_anchor"}, L(
    ("Linnet: This is it. Lampblack Lane. Dab? It's all right.", "Linnet: Das ist sie. Die Rußgasse. Dab? Alles gut."),
    ("A small Nibbet peers out of a gutter. Its mouth is all ink.", "Ein kleiner Nibbet lugt aus der Rinne. Sein Maul ist voll Tinte."),
    ("Its call is thin and smeared, like the Blot all over town.", "Sein Ruf ist dünn und verschmiert, wie der Klecks in der Stadt."),
    ("Rift-born ones need an anchor bond. One person. Not a door.", "Rissgeborene brauchen eine Ankerbindung. Einen Menschen. Keine Tür."),
    ("Linnet: Then I'll be its person. Dab? Will you have me?", "Linnet: Dann bin ich sein Mensch. Dab? Nimmst du mich?"),
    ("Dab licks Linnet's thumb instead of the street.", "Dab leckt an Linnets Daumen statt an der Straße."),
    ("Behind them, the lane's cobbles turn dark with fresh ink.", "Hinter ihnen werden die Pflastersteine dunkel von frischer Tinte.")),
    "set_flag v3t_anchor", lane_wait), "v3t_linnet", facing="right")
print_after = entry(R, "print_after", L(("Elva: Lampblack Lane, every print. I check every one.", "Elva: Die Rußgasse, auf jedem Druck. Ich prüfe jeden.")))
print_wait = until(R, "print_wait", "v3t_done", L(
    ("Elva: Not until the great press is mended. Then we print.", "Elva: Erst wenn die große Presse geflickt ist. Dann drucken wir.")), print_after)
figure("proofgate", "elva_print", (6, 10), "villager", "3a4a6a", gated(R, "print", {"flag": "quillmarch_done", "not_flag": "v3t_done"}, L(
    ("Elva: First full print in years. Lampblack Lane. Black.", "Elva: Der erste volle Druck seit Jahren. Die Rußgasse. Schwarz."),
    ("Linnet brought Dab. It sits on the plate, good as gold.", "Linnet hat Dab mitgebracht. Es sitzt brav auf der Platte."),
    ("Pennick: Fifty years. My lane's on the map again.", "Pennick: Fünfzig Jahre. Meine Gasse ist wieder auf der Karte."),
    ("Under the press the Blot goes quiet. Nothing smudges.", "Unter der Presse wird der Klecks still. Nichts verschmiert."),
    ("Elva: Take this copy. Your name's in the corner, {name}.", "Elva: Nimm diesen Abzug. Dein Name steht in der Ecke, {name}.")),
    "set_flag v3t_done", print_wait), "v3t_anchor")

# === Halcyra (Era IV): The Stringless Kite =====================================================
R = "halcyra"
tale(R, tr("Halcyra: The Stringless Kite", "Halcyra: Der Drachen ohne Schnur"), "era3_finale_done", [
    ("v4t_rhosyn", tr("Ask about the kite with no string in Brightledge.", "Frag in Brightledge nach dem Drachen ohne Schnur."),
     "Brightledge", ["v4t_rhosyn"]),
    ("v4t_selma", tr("Ask the salt widows of Paleshore about the kite.", "Frag die Salzwitwen von Paleshore nach dem Drachen."),
     "Paleshore", ["v4t_selma"]),
    ("v4t_wilf", tr("Stop Racer Wilf from netting the kite at Whitecairn.", "Halt Läufer Wilf in Whitecairn davon ab, den Drachen zu fangen."),
     "Whitecairn", ["v4t_wilf"]),
    ("v4t_reel", tr("Meet Rhosyn at Whitecairn once the Gilt Span is mended.", "Triff Rhosyn in Whitecairn, sobald die Goldbrücke geflickt ist."),
     "Whitecairn", ["v4t_reel"]),
    ("v4t_feast", tr("Call the kite down at the summer feast in Gildcrest.", "Ruf den Drachen beim Sommerfest in Gildcrest herunter."),
     "Gildcrest", ["v4t_done"]),
])
rhosyn_after = entry(R, "rhosyn_after", L(("Rhosyn: Paleshore. The widows watch the sky for a living.", "Rhosyn: Paleshore. Die Witwen schauen beruflich in den Himmel.")))
figure("brightledge", "rhosyn", (6, 10), "villager", "a06a3a", gated(R, "rhosyn", {"not_flag": "v4t_rhosyn"}, L(
    ("Rhosyn: See it? Over the cliffs. No string at all.", "Rhosyn: Siehst du ihn? Über den Klippen. Ganz ohne Schnur."),
    ("Rhosyn: Every dusk it comes. It never lands.", "Rhosyn: Jeden Abend kommt er. Er landet nie."),
    ("Rhosyn: My brother Edrin flew a Kitelet called Wisp.", "Rhosyn: Mein Bruder Edrin hatte einen Kitelet namens Wisp."),
    ("Rhosyn: Edrin fell from the Gilt Span. Wisp flew off.", "Rhosyn: Edrin stürzte von der Goldbrücke. Wisp flog davon."),
    ("Rhosyn: Nine years ago. Kites don't last nine years.", "Rhosyn: Vor neun Jahren. Drachen halten keine neun Jahre."),
    ("Rhosyn: Ask the salt widows at Paleshore. They see far.", "Rhosyn: Frag die Salzwitwen in Paleshore. Die sehen weit.")),
    "set_flag v4t_rhosyn", rhosyn_after), "era3_finale_done", "v4t_wilf")
selma_after = entry(R, "selma_after", L(("Selma: Wilf's at Whitecairn with a net. Hurry.", "Selma: Wilf ist mit einem Netz in Whitecairn. Beeil dich.")))
selma_wait = until(R, "selma_wait", "v4t_selma", L(
    ("Selma: The flats lie while the Orrery's broken. Later.", "Selma: Die Ebene lügt, solange das Orrery kaputt ist. Später.")), selma_after)
figure("paleshore", "selma", (6, 10), "elder", "8a8a7a", gated(R, "selma", {"flag": ["v4t_rhosyn", "rift_v4_orrery_sealed"], "not_flag": "v4t_selma"}, L(
    ("Selma: That's no kite, love. It's a Kitelet. Gone grey.", "Selma: Das ist kein Drachen, Kind. Das ist ein Kitelet. Ergraut."),
    ("Selma: It follows the old salt road to the Span. Daily.", "Selma: Er folgt der alten Salzstraße zur Brücke. Jeden Tag."),
    ("Selma: Up here we call it the Thin Air. Calls that fade.", "Selma: Hier oben heißt das die Dünne Luft. Rufe, die verwehen."),
    ("Selma: A Spirling that lost its person calls and calls.", "Selma: Ein Spirling, der seinen Menschen verlor, ruft und ruft."),
    ("Selma: Every lost call goes somewhere. To the Echo.", "Selma: Jeder verlorene Ruf geht irgendwohin. Zum Echo."),
    ("Selma: A choir of them. Grieving. Not angry. Just sad.", "Selma: Ein Chor davon. Trauernd. Nicht zornig. Nur traurig."),
    ("Selma: Racer Wilf wants to net it. For the cliff prize.", "Selma: Läufer Wilf will ihn fangen. Für den Klippenpreis.")),
    "set_flag v4t_selma", selma_wait), "v4t_rhosyn")
wilf_after = entry(R, "wilf_after", L(("Wilf: The grey one flies to the Span's middle. Every night.", "Wilf: Der Graue fliegt jede Nacht zur Mitte der Brücke.")))
wilf_wait = until(R, "wilf_wait", "v4t_wilf", L(
    ("Wilf: Wind's wrong. Come back once the salt flats calm.", "Wilf: Falscher Wind. Komm wieder, wenn die Salzebene ruhig ist.")), wilf_after)
figure("whitecairn", "wilf", (5, 9), "ranger", "4a6a3a", gated(R, "wilf", {"flag": ["v4t_selma", "rift_v4_salt_sealed"], "not_flag": "v4t_wilf"}, L(
    ("Wilf: The grey kite? Five hundred coins, the cliff prize.", "Wilf: Der graue Drachen? Fünfhundert Münzen, der Klippenpreis."),
    ("Wilf: Mum's roof leaks. Nets are cheap. Roofs aren't.", "Wilf: Mamas Dach ist undicht. Netze sind billig. Dächer nicht."),
    ("Wilf: You want it left alone? Then earn it.", "Wilf: Du willst, dass ich ihn lasse? Dann verdien es dir.")),
    duel("wilf", "Racer Wilf", [("Kitewhip", 88), ("Gildwing", 89), ("Siroclaw", 89), ("Zenwhirl", 90)], 5400,
         entry(R, "wilf_defeat", L(("Wilf: All right. No net. I'll fix the roof another way.", "Wilf: Na gut. Kein Netz. Das Dach flick ich anders."),
                                   ("Wilf: Tell the kite-maker I'm sorry. I didn't know.", "Wilf: Sag der Drachenbauerin, es tut mir leid. Ich wusste es nicht."))),
         entry(R, "wilf_lose", L(("Wilf: My net's ready. Come back if you're sure.", "Wilf: Mein Netz ist bereit. Komm wieder, wenn du sicher bist."))),
         "v4t_wilf"), wilf_wait), "v4t_selma")
reel_after = entry(R, "reel_after", L(("Rhosyn: Gildcrest, at the feast. Wisp circles there.", "Rhosyn: Gildcrest, beim Fest. Dort kreist Wisp.")))
reel_wait = until(R, "reel_wait", "v4t_reel", L(
    ("Rhosyn: The Span's still torn. Wisp won't come lower.", "Rhosyn: Die Brücke ist noch zerrissen. Wisp kommt nicht tiefer.")), reel_after)
figure("whitecairn", "rhosyn_span", (7, 9), "villager", "a06a3a", gated(R, "reel", {"flag": ["v4t_wilf", "rift_v4_span_sealed"], "not_flag": "v4t_reel"}, L(
    ("Rhosyn: Wilf told me. You stopped him. Thank you.", "Rhosyn: Wilf hat es mir erzählt. Du hast ihn aufgehalten. Danke."),
    ("Rhosyn: The Span is mended. Edrin would have liked that.", "Rhosyn: Die Brücke ist geflickt. Das hätte Edrin gefallen."),
    ("Rhosyn: I brought his old reel. The string's still on it.", "Rhosyn: Ich hab seine alte Spule dabei. Die Schnur ist noch dran."),
    ("Rhosyn: Come to the feast in Gildcrest. Wisp circles there.", "Rhosyn: Komm zum Fest in Gildcrest. Dort kreist Wisp.")),
    "set_flag v4t_reel", reel_wait), "v4t_wilf", "v4t_reel")
feast_after = entry(R, "feast_after", L(("Rhosyn: Wisp pulls left. Edrin's kites always did.", "Rhosyn: Wisp zieht nach links. Edrins Drachen taten das immer.")))
feast_wait = until(R, "feast_wait", "v4t_done", L(
    ("Rhosyn: After the feast. When the Gilt Rift is mended.", "Rhosyn: Nach dem Fest. Wenn der Goldriss geflickt ist.")), feast_after)
figure("gildcrest", "rhosyn_feast", (6, 10), "villager", "a06a3a", gated(R, "feast", {"flag": "halcyra_done", "not_flag": "v4t_done"}, L(
    ("Rhosyn: There. Over the golden roofs. Wisp.", "Rhosyn: Da. Über den goldenen Dächern. Wisp."),
    ("Rhosyn lifts Edrin's reel. The grey Kitelet circles lower.", "Rhosyn hebt Edrins Spule. Der graue Kitelet kreist tiefer."),
    ("Its call is so thin. Hum the Echo melody, {name}.", "Sein Ruf ist so dünn. Summ die Echo-Melodie, {name}."),
    ("Wisp drops onto the reel. Then onto Rhosyn's arm.", "Wisp landet auf der Spule. Dann auf Rhosyns Arm."),
    ("Rhosyn: Hello, you. I'm his sister. I'm your person now.", "Rhosyn: Hallo, du. Ich bin seine Schwester. Jetzt bin ich dein Mensch."),
    ("The Thin Air over Gildcrest fills with ordinary wind.", "Die Dünne Luft über Gildcrest füllt sich mit gewöhnlichem Wind.")),
    "set_flag v4t_done", feast_wait), "v4t_reel")

# === Quivermoor (Era V): The Lantern Walk ======================================================
R = "quivermoor"
tale(R, tr("Quivermoor: The Lantern Walk", "Quivermoor: Der Laternengang"), "era4_finale_done", [
    ("v5t_alvhild", tr("Walk with lantern walker Alvhild in Mossgate.", "Geh mit der Laternengängerin Alvhild in Mossgate."),
     "Mossgate", ["v5t_alvhild"]),
    ("v5t_pair", tr("Walk with the lanterns of Tallowmere and Rootchapel.", "Geh mit den Laternen von Tallowmere und Rootchapel."),
     "Tallowmere", ["v5t_gisle", "v5t_hjordis"]),
    ("v5t_pair2", tr("Walk with the lanterns of Driftwick and the Fields.", "Geh mit den Laternen von Driftwick und den Feldern."),
     "Driftwick", ["v5t_ingrun", "v5t_ketil"]),
    ("v5t_oddny", tr("Beat the last walker, Oddny, on the Gloamwater.", "Schlag die letzte Gängerin, Oddny, am Dämmerwasser."),
     "Gloamwater", ["v5t_oddny"]),
    ("v5t_aslak", tr("Find who leaves the lanterns. Ask in Lastbloom.", "Finde heraus, wer die Laternen bringt. Frag in Lastbloom."),
     "Lastbloom", ["v5t_aslak"]),
    ("v5t_mile", tr("Mend the bloom, then walk the last mile with Aslak.", "Flick die Blüte, dann geh die letzte Meile mit Aslak."),
     "Lastbloom", ["v5t_done"]),
])


def walker(map_id, fid, near, color, show, cond, flag, intro, name, team, money, defeat, lose, after, wait):
    after_ref = entry(R, fid + "_after", L(*after))
    other = until(R, fid + "_wait", flag, L(*wait), after_ref) if wait else after_ref
    figure(map_id, fid, near, "ranger", color, gated(R, fid, cond, L(*intro), duel(
        fid, name, team, money, entry(R, fid + "_defeat", L(*defeat)), entry(R, fid + "_lose", L(*lose)), flag), other), show)


walker("mossgate", "alvhild", (6, 10), "8a6a2a", "era4_finale_done", {"not_flag": "v5t_alvhild"}, "v5t_alvhild", [
    ("Alvhild: A lantern was on my step this morning. Again.", "Alvhild: Heute Morgen stand wieder eine Laterne vor meiner Tür."),
    ("Alvhild: A name is scratched in the tin. A Spirling's name.", "Alvhild: Ein Name ist ins Blech geritzt. Der Name eines Spirlings."),
    ("Alvhild: Six of us walkers got one. We walk them. Custom.", "Alvhild: Sechs von uns Gängern bekamen eine. Wir tragen sie. Brauch."),
    ("Alvhild: Walk with us? Custom says: beat the walker first.", "Alvhild: Gehst du mit? Der Brauch sagt: Erst den Gänger schlagen.")],
    "Lantern Walker Alvhild", [("Gloomgillith", 92), ("Rushstalker", 93), ("Glimmoth", 93)], 5200,
    [("Alvhild: Good. Carry my lantern to Lastbloom.", "Alvhild: Gut. Trag meine Laterne nach Lastbloom."),
     ("Alvhild: Gisle's in Tallowmere. Hjordis in Rootchapel.", "Alvhild: Gisle ist in Tallowmere. Hjordis in Rootchapel.")],
    [("Alvhild: The bog keeps those who hurry. Rest, then again.", "Alvhild: Das Moor behält, wer sich beeilt. Ruh dich aus, dann noch mal.")],
    [("Alvhild: Who leaves them? Nobody sees. The tin smells of peat.", "Alvhild: Wer sie bringt? Keiner sieht es. Das Blech riecht nach Torf.")], None)
walker("tallowmere", "gisle", (6, 10), "6a4a2a", "v5t_alvhild", {"flag": ["v5t_alvhild", "v5_ch1_done"], "not_flag": "v5t_gisle"}, "v5t_gisle", [
    ("Gisle: My lantern says 'Plink'. A Puddock, I'd guess.", "Gisle: Auf meiner Laterne steht 'Plink'. Ein Puddock, schätze ich."),
    ("Gisle: The choir lights candles for people. Not Spirlings.", "Gisle: Der Chor zündet Kerzen für Menschen an. Nicht für Spirlinge."),
    ("Gisle: Somebody out here remembers them. Prove you do too.", "Gisle: Jemand hier draußen denkt an sie. Zeig, dass du es auch tust.")],
    "Lantern Walker Gisle", [("Weirmarshal", 93), ("Dipmonarch", 93), ("Ardenthal", 94)], 5300,
    [("Gisle: Take it. Plink's name should see Lastbloom.", "Gisle: Nimm sie. Plinks Name soll Lastbloom sehen.")],
    [("Gisle: Not yet. Plink waited this long. It can wait more.", "Gisle: Noch nicht. Plink hat so lange gewartet. Es wartet noch.")],
    [("Gisle: Peat on the tin. Only old cutters burn peat now.", "Gisle: Torf am Blech. Torf brennen nur noch alte Stecher.")],
    [("Gisle: The rope's still swinging. Talk to the pier first.", "Gisle: Das Seil schwingt noch. Sprich erst am Steg vor.")])
walker("rootchapel", "hjordis", (6, 10), "4a6a4a", "v5t_alvhild", {"flag": ["v5t_alvhild", "v5_ch1_done"], "not_flag": "v5t_hjordis"}, "v5t_hjordis", [
    ("Hjordis: Mine says 'Mire'. Scratched very carefully.", "Hjordis: Auf meiner steht 'Mire'. Sehr sorgfältig geritzt."),
    ("Hjordis: The roots go quiet when I hold it. Odd, that.", "Hjordis: Die Wurzeln werden still, wenn ich sie halte. Seltsam."),
    ("Hjordis: Custom first. Then the lantern.", "Hjordis: Erst der Brauch. Dann die Laterne.")],
    "Lantern Walker Hjordis", [("Woadcastle", 93), ("Fenwarden", 94), ("Rookwarden", 94)], 5300,
    [("Hjordis: Fair. Mire is yours to carry now.", "Hjordis: Fair. Mire trägst jetzt du.")],
    [("Hjordis: The roots liked that. I didn't.", "Hjordis: Den Wurzeln hat das gefallen. Mir nicht.")],
    [("Hjordis: Ossian says feed the moor. I say listen to it.", "Hjordis: Ossian sagt, füttert das Moor. Ich sage, hört ihm zu.")],
    [("Hjordis: The rope's still swinging. Talk to the pier first.", "Hjordis: Das Seil schwingt noch. Sprich erst am Steg vor.")])
walker("driftwick", "ingrun", (6, 10), "3a5a7a", "v5t_alvhild", {"flag": ["v5t_gisle", "v5t_hjordis", "rift_v5_wick_sealed"], "not_flag": "v5t_ingrun"}, "v5t_ingrun", [
    ("Ingrun: Driftwick moves each night. The lanterns find us.", "Ingrun: Driftwick zieht jede Nacht weiter. Die Laternen finden uns."),
    ("Ingrun: Whoever brings them walks the boards in the dark.", "Ingrun: Wer sie bringt, geht im Dunkeln über die Bohlen."),
    ("Ingrun: I've seen a lamp out there. An old man's lamp.", "Ingrun: Ich hab da draußen eine Lampe gesehen. Die eines alten Mannes."),
    ("Ingrun: Beat me and I'll tell you whose. Custom.", "Ingrun: Schlag mich, dann sag ich dir, wessen. Brauch.")],
    "Lantern Walker Ingrun", [("Ripjoltane", 94), ("Dusktern", 95), ("Peatmonarch", 95), ("Silthop", 95)], 5600,
    [("Ingrun: Aslak Marr's lamp. He lost a Spirling to the bog.", "Ingrun: Die Lampe von Aslak Marr. Er verlor einen Spirling ans Moor."),
     ("Ingrun: Fifty years ago. He lives in Lastbloom now.", "Ingrun: Vor fünfzig Jahren. Er lebt jetzt in Lastbloom.")],
    [("Ingrun: Driftwick won't wait for you. I will. Once.", "Ingrun: Driftwick wartet nicht auf dich. Ich schon. Einmal.")],
    [("Ingrun: Don't rush Aslak. Finish the walk first.", "Ingrun: Dräng Aslak nicht. Beende erst den Gang.")],
    [("Ingrun: Wick Rift first. Its light drowns the lanterns.", "Ingrun: Erst der Dochtriss. Sein Licht übertönt die Laternen.")])
walker("heaving_fields", "ketil", (6, 12), "6a5a3a", "v5t_alvhild", {"flag": ["v5t_gisle", "v5t_hjordis", "rift_v5_wick_sealed"], "not_flag": "v5t_ketil"}, "v5t_ketil", [
    ("Ketil: The fields heave when the moor breathes out.", "Ketil: Die Felder wogen, wenn das Moor ausatmet."),
    ("Ketil: Every breath is full of calls. Lost ones. Hear them?", "Ketil: Jeder Atemzug ist voller Rufe. Verlorene. Hörst du sie?"),
    ("Ketil: The Long Breath, we say. My lantern hums with it.", "Ketil: Der Lange Atem, sagen wir. Meine Laterne summt mit."),
    ("Ketil: Show me you can stand in it. Then walk on.", "Ketil: Zeig mir, dass du darin stehen kannst. Dann geh weiter.")],
    "Lantern Walker Ketil", [("Fumeregent", 95), ("Nimbub", 95), ("Glazeldrake", 96), ("Rushprowl", 96)], 5700,
    [("Ketil: Take it. It hums louder near Lastbloom. Mind that.", "Ketil: Nimm sie. Bei Lastbloom summt sie lauter. Denk dran.")],
    [("Ketil: The ground threw you. It does that. Up you get.", "Ketil: Der Boden hat dich abgeworfen. Das tut er. Steh auf.")],
    [("Ketil: One walker left. Oddny, on the Gloamwater.", "Ketil: Eine Gängerin fehlt noch. Oddny, am Dämmerwasser.")],
    [("Ketil: The fields are too loud yet. Mend the Wick first.", "Ketil: Die Felder sind noch zu laut. Flick erst den Docht.")])
walker("gloamwater", "oddny", (6, 12), "4a3a5a", "v5t_alvhild", {"flag": ["v5t_ingrun", "v5t_ketil", "rift_v5_taproot_sealed"], "not_flag": "v5t_oddny"}, "v5t_oddny", [
    ("Oddny: Last lantern, last walker. Hardest custom.", "Oddny: Letzte Laterne, letzte Gängerin. Härtester Brauch."),
    ("Oddny: Mine has no name yet. Just a scratch, half done.", "Oddny: Meine hat noch keinen Namen. Nur ein halber Kratzer."),
    ("Oddny: Whoever writes them stopped mid-name. That worries me.", "Oddny: Wer sie schreibt, hörte mitten im Namen auf. Das sorgt mich."),
    ("Oddny: Win, and you carry it to him yourself.", "Oddny: Gewinn, dann trägst du sie selbst zu ihm.")],
    "Lantern Walker Oddny", [("Sablarch", 96), ("Duskmirrah", 96), ("Gloomgillith", 97), ("Sootharrow", 97)], 6000,
    [("Oddny: Six lanterns now. Take them to Aslak in Lastbloom.", "Oddny: Sechs Laternen jetzt. Bring sie zu Aslak nach Lastbloom.")],
    [("Oddny: The water's dark. Come back with a steadier hand.", "Oddny: Das Wasser ist dunkel. Komm mit ruhigerer Hand wieder.")],
    [("Oddny: Aslak writes them. I'm sure of it now. Go.", "Oddny: Aslak schreibt sie. Da bin ich mir jetzt sicher. Geh.")],
    [("Oddny: The roots still hold the chapel. Mend them first.", "Oddny: Die Wurzeln halten die Kapelle noch. Flick sie erst.")])
aslak_after = entry(R, "aslak_after", L(("Aslak: I still listen at night. Now the walkers do too.", "Aslak: Ich lausche nachts noch immer. Jetzt lauschen die Gänger mit.")))
aslak_bloom = until(R, "aslak_bloom", "v5t_done", L(
    ("Aslak: Mend the bloom. Then the last mile.", "Aslak: Flick die Blüte. Dann die letzte Meile.")), aslak_after)
aslak_mile = gated(R, "aslak_mile", {"flag": ["v5t_aslak", "quivermoor_done"], "not_flag": "v5t_done"}, L(
    ("Aslak: The bloom is mended. The last mile, then.", "Aslak: Die Blüte ist geflickt. Also die letzte Meile."),
    ("Aslak: Custom says the elder walks last. And fights last.", "Aslak: Der Brauch sagt: Der Älteste geht zuletzt. Und kämpft zuletzt.")),
    duel("aslak", "Lantern Elder Aslak", [("Peatmonarch", 97), ("Woadcastle", 98), ("Weirmarshal", 98), ("Rookwarden", 99), ("Fenwarden", 99)], 9000,
         entry(R, "aslak_defeat", L(
             ("Aslak: Well walked. Light them, all seven. Mine too.", "Aslak: Gut gegangen. Zünde sie an, alle sieben. Meine auch."),
             ("Seven lanterns drift out on the black water of Lastbloom.", "Sieben Laternen treiben hinaus aufs schwarze Wasser von Lastbloom."),
             ("The moor breathes out. This time the calls are soft.", "Das Moor atmet aus. Diesmal sind die Rufe sanft."),
             ("Far off, the Echo goes still. A choir, listening.", "Weit weg wird das Echo still. Ein Chor, der lauscht."),
             ("Aslak scratches the last name: Tussock. His hand is steady.", "Aslak ritzt den letzten Namen: Tussock. Seine Hand ist ruhig."),
             ("Aslak: Fifty years I listened. Tonight they heard me.", "Aslak: Fünfzig Jahre hab ich gelauscht. Heute haben sie mich gehört."))),
         entry(R, "aslak_lose", L(("Aslak: Rest. The water waits. So do I.", "Aslak: Ruh dich aus. Das Wasser wartet. Ich auch."))),
         "v5t_done", ai=3), aslak_bloom)
aslak_wait = until(R, "aslak_wait", "v5t_aslak", L(
    ("Aslak: Not now, Wayfarer. The moor is still too loud.", "Aslak: Nicht jetzt, Wanderer. Das Moor ist noch zu laut.")), aslak_mile)
figure("lastbloom", "aslak", (6, 10), "elder", "5a4a3a", gated(R, "aslak", {"flag": ["v5t_oddny", "rift_v5_raft_sealed"], "not_flag": "v5t_aslak"}, L(
    ("Aslak: Six lanterns. So the walkers caught me.", "Aslak: Sechs Laternen. Die Gänger haben mich also erwischt."),
    ("Aslak: At night the moor breathes out. I listen.", "Aslak: Nachts atmet das Moor aus. Ich lausche."),
    ("Aslak: Every breath carries a name. A lost Spirling's.", "Aslak: Jeder Atemzug trägt einen Namen. Den eines verlorenen Spirlings."),
    ("Aslak: Their calls all go into the Echo. A grieving choir.", "Aslak: Ihre Rufe gehen alle ins Echo. Ein trauernder Chor."),
    ("Aslak: I scratch each name in tin, so someone carries it.", "Aslak: Ich ritze jeden Namen in Blech, damit ihn jemand trägt."),
    ("Aslak: Oddny's is my Tussock's. I could never finish it.", "Aslak: Oddnys ist die von meinem Tussock. Ich konnte sie nie fertig machen."),
    ("Aslak: When the bloom is mended, walk the last mile with me.", "Aslak: Wenn die Blüte geflickt ist, geh die letzte Meile mit mir.")),
    "set_flag v5t_aslak", aslak_wait), "v5t_oddny")


# --- Writing --------------------------------------------------------------------------------
def load(rel):
    return json.load(open(os.path.join(ROOT, rel), encoding="utf-8"))


def save(rel, data):
    with open(os.path.join(ROOT, rel), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")


def save_quests(q):
    """data/quests.json in its own layout: two-space indent, one goal per line."""
    out = []
    for k, v in q.items():
        if isinstance(v, list):
            items = ",\n".join("    " + json.dumps(g, ensure_ascii=False) for g in v)
            out.append("  %s: [\n%s\n  ]" % (json.dumps(k), items))
        else:
            out.append("  %s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
    with open(os.path.join(ROOT, "data", "quests.json"), "w", encoding="utf-8") as fh:
        fh.write("{\n" + ",\n".join(out) + "\n}\n")


def free_cell(map_id, near, taken):
    """The '.' or '_' cell closest to [near] that is free and keeps the map connected."""
    m = load("data/maps/%s.json" % map_id)
    rows = m["rows"]
    busy = set(taken)
    for k in ("npcs", "signs", "secrets", "warps"):
        for e in m.get(k, []):
            busy.add((int(e["x"]), int(e["y"])))
            # Day plans move people onto other cells (dusk); those must stay clear too.
            for st in e.get("schedule", []):
                if "x" in st:
                    busy.add((int(st["x"]), int(st["y"])))
    walk = {(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch not in SOLID and (x, y) not in busy}
    doors = {(x, y + 1) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == "D"}

    def parts(cells):
        seen, n = set(), 0
        for c in cells:
            if c in seen:
                continue
            n += 1
            stack = [c]
            seen.add(c)
            while stack:
                x, y = stack.pop()
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nb = (x + d[0], y + d[1])
                    if nb in cells and nb not in seen:
                        seen.add(nb)
                        stack.append(nb)
        return n

    base = parts(walk)
    for c in sorted(walk, key=lambda c: (abs(c[0] - near[0]) + abs(c[1] - near[1]), c[1], c[0])):
        if rows[c[1]][c[0]] not in "._" or c in doors:
            continue
        if parts(walk - {c}) == base:
            return c
    raise SystemExit("no free cell on " + map_id)


def main():
    for region, d in DIALOGUE.items():
        save("data/dialogue/%s_tale.json" % region, dict(sorted(d.items())))
    q = load("data/quests.json")
    note = (" 'post' holds the region tales after the story (tools/art/world/post_tales.py): each goal names its"
            " 'region', the tale title in 'act' and the flag that 'opens' the region; one tale at a time shows in Goals.")
    if note not in q["_comment"]:
        q["_comment"] += note
    q["post"] = TALES
    save_quests(q)
    sb = load("data/story_battles.json")
    for k in [k for k in sb if k.startswith("tale_")]:
        del sb[k]
    sb.update(BATTLES)
    save("data/story_battles.json", sb)
    sn = load("data/story_npcs.json")
    for mid, figs in FIGURES.items():
        place = sn.setdefault(mid, {})
        npcs = [n for n in place.get("npcs", []) if not str(n.get("id", "")).startswith("tale_")]
        taken = [(int(n["x"]), int(n["y"])) for n in npcs if "x" in n]
        for f in figs:
            f = dict(f)
            x, y = free_cell(mid, f.pop("near"), taken)
            taken.append((x, y))
            npcs.append(dict({"id": f["id"], "x": x, "y": y}, **{k: v for k, v in f.items() if k != "id"}))
        place["npcs"] = npcs
    save("data/story_npcs.json", sn)
    with open(os.path.join(ROOT, "tools", "i18n", "de_post_tales.py"), "w", encoding="utf-8") as fh:
        fh.write("# German texts of the region tales. Written by tools/art/world/post_tales.py:\n"
                 "# edit the tr()/L() pairs there, not this file.\nKEEP = []\nT = {\n")
        for en in sorted(GERMAN):
            fh.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(GERMAN[en], ensure_ascii=False)))
        fh.write("}\n")
    print("tales: %d goals, %d figures, %d duels, %d texts" % (
        len(TALES), sum(len(v) for v in FIGURES.values()), len(BATTLES), len(GERMAN)))


if __name__ == "__main__":
    main()
