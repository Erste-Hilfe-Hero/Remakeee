"""Ashmere side content, part two (Act III toward 20 h of real content): Clinker Heath south of
Cinderfold (a slag-heath route), the Ash Assize on it (a court that sells verdicts, and the heath's
only roof) and the Bellows Deep at its south end (a three-floor coal deep the Ruskweber clan
declared closed eleven years ago and never stopped billing). Tone: a court where the jury is
"advisory", a mourner who buries people before they die, a shift nobody told the mine was shut.

Side goals (data/quests.json): ah_assize (five jurors, then the verdict), ah_briony (an alibi),
ah_mourner (funerals for the living), ah_tags (eight tally tags), ah_last_shift (where the last
shift went), ah_portraits (eight kinds for Corwin), ah_deeds (what the portraits are for),
ah_deep (who still runs the Deep), ah_juno (Juno's partnership).
Betrayals (data/clans.json): greaves_verdict, juno_split; favor briony_alibi.

How the way opens:
  cinderfold -> clinker_heath   halvard_met (the south cut behind the spring, tools/art/world/ashmere.py)
  heath -> ash_assize           always
  heath -> bellows_deep         always; floors 2 and 3 behind the bellows rows
Edit here, then run python3 tools/art/world/ashmere_more.py (writes only these maps, their
dialogue and tools/i18n/de_ashmere_more.py), python3 tools/art/build_world.py and
python3 tools/i18n/build.py.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from common import check_rows, lines, npc, secret, team, tr, warp  # noqa: E402
from rifts12 import gate, put, wayfarer  # noqa: E402

GROUP = ["clinker_heath", "ash_assize", "bellows_deep"]
HEATH = "clinker_heath"
HALL = "ash_assize"
DEEP = "bellows_deep"
SIDE = "ashmere_more"

# Kinds Corwin paints: four from the heath, four from the Deep.
PORTRAITS = ["Brickwarden", "Peatbloom", "Bellowroc", "Charsylvan", "Fumeregent", "Lodemarshal", "Vitrillaxe", "Clinkerdome"]

# Tally tags of the last shift: 1-4 on the heath, 5-8 in the Deep. (map, floor, x, y, text)
TAGS = [
    (HEATH, 0, 9, 3, ("A brass tally tag on a nail in a dead snag. Stamped: 'GAGE, No. 3'. A tag on the board means you came up. This one is not on the board.", "Eine Messingmarke an einem Nagel in einem toten Baum. Gestempelt: 'GAGE, Nr. 3'. Eine Marke am Brett heißt, du bist hochgekommen. Diese hängt nicht am Brett.")),
    (HEATH, 0, 1, 13, ("A tally tag in the ferns, polished by years of rain. 'MOLLY, No. 9'. Someone scratched a smile on the back.", "Eine Marke im Farn, von Jahren Regen poliert. 'MOLLY, Nr. 9'. Jemand hat ein Lächeln in die Rückseite geritzt.")),
    (HEATH, 0, 10, 19, ("A tally tag tied to a rabbit snare. 'HAMM, No. 1, SHIFT BOSS'. The snare is empty. The rabbit won.", "Eine Marke an einer Hasenschlinge. 'HAMM, Nr. 1, SCHICHTFÜHRER'. Die Schlinge ist leer. Der Hase hat gewonnen.")),
    (HEATH, 0, 1, 27, ("A tally tag in a slag heap. 'PENN, No. 12'. Under it, older and smaller: 'PENN, No. 12, APPRENTICE'.", "Eine Marke in einer Schlackenhalde. 'PENN, Nr. 12'. Darunter, älter und kleiner: 'PENN, Nr. 12, LEHRLING'.")),
    (DEEP, 0, 10, 1, ("A tally tag hung on a pit prop like a medal. 'TUCK, No. 5'. The prop is holding up the roof. Mostly out of habit.", "Eine Marke an einem Grubenstempel, wie ein Orden. 'TUCK, Nr. 5'. Der Stempel hält die Decke. Hauptsächlich aus Gewohnheit.")),
    (DEEP, 0, 1, 9, ("A tally tag in a lunch tin. The lunch is eleven years old and has developed opinions. 'ROSA, No. 7'.", "Eine Marke in einer Brotdose. Das Brot ist elf Jahre alt und hat eigene Ansichten entwickelt. 'ROSA, Nr. 7'.")),
    (DEEP, 1, 10, 9, ("A tally tag nailed over a list of wages, as if to hide the sum. 'BERT, No. 4'.", "Eine Marke über eine Lohnliste genagelt, als sollte sie die Summe verdecken. 'BERT, Nr. 4'.")),
    (DEEP, 2, 1, 1, ("A tally tag on Overman Slagg's desk, used to stir his tea. 'ODO, No. 2'. The tea is mostly brass by now.", "Eine Marke auf Obersteiger Slaggs Tisch, zum Teeumrühren benutzt. 'ODO, Nr. 2'. Der Tee ist inzwischen größtenteils Messing.")),
]

# Mercer's three funeral notice boards on the heath: (x, y, text).
NOTICES = [
    (3, 6, ("A notice board, empty but for nails. A good spot for bad news.", "Ein Anschlagbrett, leer bis auf Nägel. Ein guter Platz für schlechte Nachrichten.")),
    (8, 16, ("A notice board leaning on a slag heap. Someone has carved 'WHO NEXT?' into it, then 'NOT ME'.", "Ein Anschlagbrett an einer Schlackenhalde. Jemand hat 'WER ALS NÄCHSTES?' hineingeschnitzt, dann 'NICHT ICH'.")),
    (2, 24, ("A notice board by the path. The old notices are funeral notices too. Mercer has been busy for years.", "Ein Anschlagbrett am Weg. Die alten Zettel sind auch Trauerzettel. Mercer ist seit Jahren fleißig.")),
]

# Bellows rows in the Deep: cells per floor, the order they are worked in, the flag, the hint.
BELLOWS = [
    {"cells": [(2, 1), (5, 4), (9, 2)], "order": [1, 2, 0], "flag": "ah_bellows_1", "wall": (1, 4),
     "names": [("A bellows marked COAL.", "Ein Blasebalg mit der Aufschrift KOHLE."),
               ("A bellows marked AIR.", "Ein Blasebalg mit der Aufschrift LUFT."),
               ("A bellows marked FIRE.", "Ein Blasebalg mit der Aufschrift FEUER.")],
     "hint": ("Chalked on the wall: Air first, or the fire eats you. Then the fire, then the coal. Then the bill.", "An die Wand gekreidet: Erst Luft, sonst frisst dich das Feuer. Dann Feuer, dann Kohle. Dann die Rechnung.")},
    {"cells": [(2, 2), (9, 2), (2, 8), (9, 8)], "order": [3, 0, 2, 1], "flag": "ah_bellows_2", "wall": (1, 5),
     "names": [("A bellows marked MONDAY.", "Ein Blasebalg mit der Aufschrift MONTAG."),
               ("A bellows marked TUESDAY.", "Ein Blasebalg mit der Aufschrift DIENSTAG."),
               ("A bellows marked WEDNESDAY.", "Ein Blasebalg mit der Aufschrift MITTWOCH."),
               ("A bellows marked PAYDAY.", "Ein Blasebalg mit der Aufschrift ZAHLTAG.")],
     "hint": ("A shift rhyme scratched into the coal: Tuesday's for sweat and Payday's a lie, Wednesday's for coughing and Monday we die. Sung backwards, apparently.", "Ein Schichtreim, in die Kohle geritzt: Dienstag wird geschwitzt und Zahltag gelogen, Mittwoch gehustet, am Montag betrogen. Rückwärts gesungen, offenbar.")},
]


def build(world):
    side_texts(world)
    heath(world)
    assize(world)
    deep(world)


def stage(goal, lo, hi=None):
    return {"var_min": {"q_%s_stage" % goal: lo}, "var_max": {"q_%s_stage" % goal: lo if hi is None else hi}}


def tag_entry(n, text):
    return {"if": {"not_flag": "ah_tag_%d" % n}, "else": "tag_empty",
            "lines": lines(text, ("You pocket the tag. It is lighter than it should be.", "Du steckst die Marke ein. Sie ist leichter, als sie sein sollte.")),
            "action": "set_flag ah_tag_%d" % n}


# --- Texts of the heath people, the court and the betrayals (ashmere_more) ---------------------
def side_texts(world):
    t = {}
    jurors = ["ah_juror_%d" % n for n in range(1, 6)]
    # Magistrate Greaves: five votes, then the verdict (scripted betrayal greaves_verdict).
    t["greaves"] = {"if": {"not_flag": "ah_assize_asked"}, "else": "greaves_votes",
                    "lines": lines(("Magistrate Greaves: Order. Order! Thank you. The Ash Assize is in session. It is always in session. Sessions are billed by the hour.", "Richter Greaves: Ruhe. Ruhe! Danke. Das Aschegericht tagt. Es tagt immer. Sitzungen werden stundenweise abgerechnet."),
                                   ("Magistrate Greaves: You want a verdict on the Ruskweber wage plates? Then you need the jury. Five jurors, out walking the heath. Win each one over.", "Richter Greaves: Du willst ein Urteil über die Lohnplatten der Ruskwebers? Dann brauchst du die Geschworenen. Fünf, draußen auf der Heide unterwegs. Überzeug jeden einzeln."),
                                   ("Magistrate Greaves: By 'win over' I mean beat in a duel. This is Ashmere. Persuasion is a contact sport.", "Richter Greaves: Mit 'überzeugen' meine ich im Duell schlagen. Das hier ist Ashmere. Überzeugungsarbeit ist ein Kampfsport.")),
                    "action": "set_flag ah_assize_asked"}
    t["greaves_votes"] = {"if": {"flag": jurors, "not_flag": "betrayal_greaves_verdict"}, "else": "greaves_more",
                          "lines": lines(("Magistrate Greaves: Five votes for you. Unanimous! The court is moved. Deeply. Financially, even.", "Richter Greaves: Fünf Stimmen für dich. Einstimmig! Das Gericht ist gerührt. Zutiefst. Sogar finanziell."),
                                         ("Magistrate Greaves: And now the verdict, which I wrote last Tuesday.", "Richter Greaves: Und nun das Urteil, das ich letzten Dienstag geschrieben habe.")),
                          "action": "betrayal greaves_verdict"}
    t["greaves_more"] = {"if": {"not_flag": "betrayal_greaves_verdict"}, "else": "greaves_after",
                         "lines": lines(("Magistrate Greaves: Not all five votes yet? The jury walks the heath. Like the dead, but with lunch breaks.", "Richter Greaves: Noch nicht alle fünf Stimmen? Die Geschworenen laufen auf der Heide herum. Wie die Toten, nur mit Mittagspause."),)}
    t["greaves_after"] = lines(("Magistrate Greaves: Court is adjourned. Court is always adjourned for you now. Permanently. Mind the step.", "Richter Greaves: Die Sitzung ist vertagt. Für dich ist sie ab jetzt immer vertagt. Dauerhaft. Achtung, Stufe."))
    t["verdict_caught"] = lines(("You lay Clerk Tansy's docket on the bench: 'Verdict: for the clan (prepaid). Jury: advisory.' Dated last Tuesday.", "Du legst Gerichtsschreiberin Tansys Akte auf die Richterbank: 'Urteil: für den Clan (vorab bezahlt). Geschworene: beratend.' Datiert auf letzten Dienstag."),
                                ("Magistrate Greaves: ...Advisory means they advise and I ignore. It's a very old tradition. Fine. Take the clan's bribe, then. Somebody should enjoy it.", "Richter Greaves: ...Beratend heißt, sie beraten und ich ignoriere. Eine sehr alte Tradition. Schön. Nimm halt das Bestechungsgeld des Clans. Irgendwer sollte Freude daran haben."))
    t["verdict_struck"] = lines(("Magistrate Greaves: Guilty! Of wasting the court's time. And of trespass, loitering, and having the wrong friends. Bailiffs?", "Richter Greaves: Schuldig! Der Verschwendung richterlicher Zeit. Und des Hausfriedensbruchs, Herumlungerns und falscher Freunde. Gerichtsdiener?"),
                                ("Magistrate Greaves: The jury? Advisory, dear. They advise. I decide. Read the docket next time. Nobody reads the docket.", "Richter Greaves: Die Geschworenen? Beratend, Liebes. Sie beraten. Ich entscheide. Lies nächstes Mal die Akte. Keiner liest die Akte."))
    t["bailiffs_defeat"] = lines(("Bailiff: Sentence served, I suppose. Here, court costs. Refunded. Don't tell the magistrate.", "Gerichtsdiener: Strafe abgesessen, nehme ich an. Hier, Gerichtskosten. Zurückerstattet. Sag's nicht dem Richter."),)
    t["bailiffs_lose"] = lines(("The bailiffs throw you out onto the heath. The heath does not catch you.", "Die Gerichtsdiener werfen dich auf die Heide hinaus. Die Heide fängt dich nicht auf."))
    t["ledger_verdict"] = lines(("The advisory jury", "Die beratenden Geschworenen"),
                                ("Greaves let you win all five jurors of the Ash Assize, then read out a verdict the clan had paid for the week before.", "Greaves ließ dich alle fünf Geschworenen des Aschegerichts gewinnen und verlas dann ein Urteil, das der Clan eine Woche vorher bezahlt hatte."))
    # Clerk Tansy and the docket.
    t["tansy"] = {"if": {"flag": "ah_assize_asked", "not_flag": "ah_docket_read"}, "else": "tansy_plain",
                  "lines": lines(("Clerk Tansy: The docket is on my desk. Page two. I'm not telling you to read it. I'm telling you where it is. Those are different crimes.", "Gerichtsschreiberin Tansy: Die Akte liegt auf meinem Pult. Seite zwei. Ich sage dir nicht, dass du sie lesen sollst. Ich sage dir, wo sie liegt. Das sind verschiedene Vergehen."),)}
    t["tansy_plain"] = {"lines": lines(("Clerk Tansy: I write down what the court says. Sometimes before it says it. Saves ink.", "Gerichtsschreiberin Tansy: Ich schreibe auf, was das Gericht sagt. Manchmal, bevor es das sagt. Spart Tinte."),),
                        "after_flag": {"flag": "betrayal_greaves_verdict", "lines": lines(("Clerk Tansy: I've started a second docket. The true one. It's very short and very rude.", "Gerichtsschreiberin Tansy: Ich habe eine zweite Akte angefangen. Die wahre. Sie ist sehr kurz und sehr unhöflich."),)}}
    # Briony Cask in the dock (favor briony_alibi).
    t["briony"] = {"if": {"not_flag": "ah_briony_done"}, "else": "briony_after",
                   "lines": lines(("Briony Cask: They say I stole a wage plate from the gravers' hall. Me! I can't even lift a wage plate. I've tried. Often.", "Briony Cask: Sie sagen, ich hätte eine Lohnplatte aus der Gravurhalle gestohlen. Ich! Ich kann nicht mal eine Lohnplatte heben. Ich hab's versucht. Oft."),
                                  ("Briony Cask: Tell the magistrate I was with you on the heath that night. One little oath. Friends swear for friends. We're friends now. Aren't we?", "Briony Cask: Sag dem Richter, ich war in der Nacht mit dir auf der Heide. Ein kleiner Eid. Freunde schwören für Freunde. Wir sind jetzt Freunde. Oder?")),
                   "action": "set_flag ah_briony_met",
                   "choices": [{"text": tr("Swear for her", "Für sie schwören"), "action": "favor briony_alibi", "flag": "ah_briony_done"},
                               {"text": tr("I wasn't there", "Ich war nicht dort")}]}
    t["briony_after"] = lines(("Briony Cask: No hard feelings. Feelings are for people who own things. I own a lot of things now. Some of them were yours.", "Briony Cask: Nichts für ungut. Gefühle sind was für Leute, die etwas besitzen. Ich besitze jetzt eine Menge. Einiges davon gehörte dir."))
    t["briony_betray"] = lines(("Your oath gets Briony off. Outside, she hands the wage plate to two Ruskweber fences, then points at you.", "Dein Eid bringt Briony frei. Draußen gibt sie die Lohnplatte zwei Hehlern der Ruskwebers und zeigt dann auf dich."),
                               ("Briony Cask: That one swore in court they were with me. Under oath. Which makes them my accomplice. Get them.", "Briony Cask: Die da hat vor Gericht geschworen, dass sie bei mir war. Unter Eid. Damit ist sie meine Komplizin. Schnappt sie."))
    t["briony_reward"] = lines(("Briony walks free and keeps her word, which surprises both of you. She slips you a tonic from the evidence locker.", "Briony kommt frei und hält Wort, was euch beide überrascht. Sie steckt dir einen Trank aus der Asservatenkammer zu."))
    t["briony_kept"] = lines(("Your oath is not needed. The magistrate loses the file. Briony thanks you anyway, and counts her fingers after the handshake. Yours too.", "Dein Eid wird nicht gebraucht. Der Richter verlegt die Akte. Briony dankt dir trotzdem und zählt nach dem Handschlag ihre Finger. Deine auch."))
    t["fence_defeat"] = lines(("Ruskweber Fence: Accomplice, she said. Accomplice my foot. You're a witness, and witnesses get paid to forget.", "Hehler der Ruskwebers: Komplizin, hat sie gesagt. Von wegen. Du bist eine Zeugin, und Zeugen werden fürs Vergessen bezahlt."),)
    t["fence_lose"] = lines(("The fences take your coins as 'evidence'. Evidence is never returned.", "Die Hehler nehmen deine Münzen als 'Beweismittel'. Beweismittel kommen nie zurück."))
    t["ledger_alibi"] = lines(("The alibi", "Das Alibi"),
                              ("Briony Cask asked you to swear she was with you on the heath, then used the oath to call you her accomplice.", "Briony Cask bat dich zu schwören, dass sie mit dir auf der Heide war, und machte dich mit dem Eid zu ihrer Komplizin."))
    # Mourner Mercer: funerals for the living (stages of ah_mourner).
    t["mercer"] = {"if": {"not_flag": "ah_mourner_asked"}, "else": "mercer_pins",
                   "lines": lines(("Mourner Mercer: Professional grief. Weeping by the hour, wailing by arrangement, fainting on request. I do a lovely faint.", "Trauerredner Mercer: Professionelle Trauer. Weinen nach Stunden, Wehklagen nach Absprache, Ohnmacht auf Wunsch. Meine Ohnmacht ist wunderschön."),
                                  ("Mourner Mercer: Business is booming. Three funerals tomorrow. Pin these notices on the three boards of the heath, would you? My knees are in mourning.", "Trauerredner Mercer: Das Geschäft blüht. Drei Beerdigungen morgen. Häng diese Zettel an die drei Bretter der Heide, ja? Meine Knie trauern.")),
                   "action": "set_flag ah_mourner_asked"}
    t["mercer_pins"] = {"if": dict(stage("ah_mourner", 0), flag=["ah_notice_1", "ah_notice_2", "ah_notice_3"]), "else": "mercer_wait",
                        "lines": lines(("Mourner Mercer: All three pinned. Wonderful. Old Abner Tull, the widow Grice and young Pell the slag-picker. Tragic. Sudden. Tomorrow.", "Trauerredner Mercer: Alle drei hängen. Wunderbar. Der alte Abner Tull, die Witwe Grice und der junge Pell, der Schlackenklauber. Tragisch. Plötzlich. Morgen."),
                                       ("Mourner Mercer: Don't visit the departed, by the way. It upsets them.", "Trauerredner Mercer: Besuch die Verstorbenen übrigens nicht. Das regt sie auf.")),
                        "action": "quest_stage ah_mourner 1"}
    t["mercer_wait"] = {"if": stage("ah_mourner", 0), "else": "mercer_mid",
                        "lines": lines(("Mourner Mercer: Three boards, three notices. Pin them straight. Nobody trusts a crooked funeral.", "Trauerredner Mercer: Drei Bretter, drei Zettel. Gerade anpinnen. Niemand traut einer schiefen Beerdigung."),)}
    t["mercer_mid"] = {"if": stage("ah_mourner", 1, 2), "else": "mercer_confront",
                       "lines": lines(("Mourner Mercer: I'm rehearsing. Sob, sob, wail. Sob, wail, faint. The faint goes last. Always leave them wanting more.", "Trauerredner Mercer: Ich probe. Schluchz, schluchz, klag. Schluchz, klag, Ohnmacht. Die Ohnmacht kommt zuletzt. Immer Lust auf mehr machen."),)}
    t["mercer_confront"] = {"if": dict(stage("ah_mourner", 3), not_flag="ah_mourner_done"), "else": "mercer_after",
                            "lines": lines(("Mourner Mercer: You found the auction book. Rude. Yes, I bury them first and sell the house after. The families get a lovely service. And the bill.", "Trauerredner Mercer: Du hast das Auktionsbuch gefunden. Unhöflich. Ja, ich beerdige sie zuerst und verkaufe danach das Haus. Die Familien kriegen eine schöne Feier. Und die Rechnung."),
                                           ("Mourner Mercer: Old Tull would have died eventually. I just got the paperwork in early. Now, shall I mourn you? I'll give you the family rate.", "Trauerredner Mercer: Der alte Tull wäre irgendwann sowieso gestorben. Ich hab den Papierkram nur früher erledigt. Soll ich dich betrauern? Du kriegst den Familientarif.")),
                            "action": "battle mercer_wake"}
    t["mercer_defeat"] = lines(("Mourner Mercer: Beaten by the guest of honour. Fine. I'll cancel the funerals. Do you know what a refund does to a mourner's soul?", "Trauerredner Mercer: Vom Ehrengast geschlagen. Schön. Ich sage die Beerdigungen ab. Weißt du, was eine Rückerstattung mit der Seele eines Trauerredners macht?"),)
    t["mercer_lose"] = lines(("Mourner Mercer: There, there. Sob. That one was free.", "Trauerredner Mercer: Na, na. Schluchz. Der war gratis."))
    t["mercer_after"] = lines(("Mourner Mercer: I do weddings now. Same tears, better cake, and the bride only wishes she were dead.", "Trauerredner Mercer: Ich mache jetzt Hochzeiten. Dieselben Tränen, besserer Kuchen, und die Braut wünscht sich nur, sie wäre tot."))
    # Old Abner Tull, the departed.
    t["tull"] = {"if": stage("ah_mourner", 1), "else": "tull_plain",
                 "lines": lines(("Old Abner Tull: My funeral? Tomorrow? I've not even finished my soup.", "Der alte Abner Tull: Meine Beerdigung? Morgen? Ich hab noch nicht mal meine Suppe aufgegessen."),
                                ("Old Abner Tull: Mercer did the widow Grice last spring. She was out picking berries. Came home to a buyer measuring her curtains.", "Der alte Abner Tull: Mercer hat letztes Frühjahr die Witwe Grice gemacht. Die war Beeren pflücken. Kam heim, und ein Käufer hat ihre Vorhänge ausgemessen."),
                                ("Old Abner Tull: He keeps an auction book in the Bellows Deep, where nobody looks. Go and look.", "Der alte Abner Tull: Er hat ein Auktionsbuch im Blasebalgschacht, wo keiner nachsieht. Geh nachsehen.")),
                 "action": "quest_stage ah_mourner 2"}
    t["tull_plain"] = {"lines": lines(("Old Abner Tull: I walk the heath every day to show the clan I'm still breathing. It's the only exercise that pays.", "Der alte Abner Tull: Ich laufe jeden Tag über die Heide, um dem Clan zu zeigen, dass ich noch atme. Der einzige Sport, der sich lohnt."),),
                       "after_flag": {"flag": "ah_mourner_done", "lines": lines(("Old Abner Tull: Still alive! I've ordered a cake to celebrate. Mercer's baking it. I'm having it tasted first.", "Der alte Abner Tull: Noch am Leben! Ich hab zur Feier einen Kuchen bestellt. Mercer backt ihn. Ich lass ihn vorkosten."),)}}
    # Tally Keeper Orla: eight tags, then the last shift.
    t["orla"] = {"if": {"not_flag": "ah_tags_asked"}, "else": "orla_count",
                 "lines": lines(("Tally Keeper Orla: I kept the tag board of the Bellows Deep. You hang your tag when you go down, you take it back when you come up.", "Markenwartin Orla: Ich hab das Markenbrett des Blasebalgschachts geführt. Du hängst deine Marke auf, wenn du einfährst, und nimmst sie mit, wenn du hochkommst."),
                                ("Tally Keeper Orla: The clan shut the Deep eleven years ago. Eight tags never came back to my board. Find them for me. A board with holes in it looks careless.", "Markenwartin Orla: Der Clan hat den Schacht vor elf Jahren geschlossen. Acht Marken kamen nie an mein Brett zurück. Finde sie für mich. Ein Brett mit Löchern sieht nachlässig aus.")),
                 "action": "set_flag ah_tags_asked"}
    t["orla_count"] = {"if": {"not_flag": "ah_tags_done"}, "else": "orla_shift",
                       "lines": lines(("Tally Keeper Orla: Four tags lie out on the heath, they say. The other four went down with the shift.", "Markenwartin Orla: Vier Marken sollen draußen auf der Heide liegen. Die anderen vier sind mit der Schicht eingefahren."),),
                       "next": "orla_all"}
    t["orla_all"] = {"if": {"flag": ["ah_tag_%d" % n for n in range(1, 9)]},
                     "lines": lines(("Tally Keeper Orla: All eight. Hamm, Odo, Gage, Bert, Tuck, Rosa, Molly, Penn. That's the whole last shift.", "Markenwartin Orla: Alle acht. Hamm, Odo, Gage, Bert, Tuck, Rosa, Molly, Penn. Das ist die ganze letzte Schicht."),
                                    ("Tally Keeper Orla: Strange. The tags from the Deep are new brass. Somebody has been stamping fresh ones. You don't stamp tags for the dead. Take these, I don't need leaves.", "Markenwartin Orla: Seltsam. Die Marken aus dem Schacht sind neues Messing. Jemand stanzt frische. Für Tote stanzt man keine Marken. Nimm die, ich brauch keine Blätter.")),
                     "action": "set_flag ah_tags_done; give_item revival_leaf 2"}
    t["orla_shift"] = {"if": stage("ah_last_shift", 0), "else": "orla_told",
                       "lines": lines(("Tally Keeper Orla: Fresh tags means a live shift. Go down to the bottom gallery of the Deep. If I'm wrong, bring back nothing. Nothing is easy to carry.", "Markenwartin Orla: Frische Marken heißt eine lebende Schicht. Geh runter in die unterste Strecke des Schachts. Wenn ich mich irre, bring nichts zurück. Nichts trägt sich leicht."),)}
    t["orla_told"] = {"if": stage("ah_last_shift", 1), "else": "orla_after",
                      "lines": lines(("Tally Keeper Orla: Alive? Digging? For eleven years? And Slagg signs for their wages every month?", "Markenwartin Orla: Am Leben? Am Graben? Seit elf Jahren? Und Slagg quittiert jeden Monat ihren Lohn?"),
                                     ("Tally Keeper Orla: I stamped those tags myself, you know. I'll stamp one for Slagg too. For when he goes down and doesn't come up.", "Markenwartin Orla: Die Marken hab ich selbst gestanzt, weißt du. Ich stanz auch eine für Slagg. Für wenn er einfährt und nicht mehr hochkommt.")),
                      "action": "quest_stage ah_last_shift 2"}
    t["orla_after"] = {"lines": lines(("Tally Keeper Orla: Slagg's at the bottom of his Deep. Fitting. Go and give him the news.", "Markenwartin Orla: Slagg sitzt ganz unten in seinem Schacht. Passend. Geh und überbring ihm die Neuigkeit."),),
                       "after_flag": {"flag": "ah_slagg_beaten", "lines": lines(("Tally Keeper Orla: Eight tags on the board. Eight. First time in eleven years my board's been full. I cried. Don't tell the clan, they'd charge for it.", "Markenwartin Orla: Acht Marken am Brett. Acht. Zum ersten Mal seit elf Jahren ist mein Brett voll. Ich hab geweint. Sag's nicht dem Clan, die würden's berechnen."),)}}
    # Painter Corwin: eight portraits, then what they are for (ah_deeds).
    t["corwin"] = {"if": {"not_flag": "ah_portraits_asked"}, "else": "corwin_done",
                   "lines": lines(("Painter Corwin: I paint the wild Spirlings of the heath. Portraits. Very lifelike. Some of them have complained.", "Maler Corwin: Ich male die wilden Spirlings der Heide. Porträts. Sehr lebensecht. Manche haben sich beschwert."),
                                  ("Painter Corwin: Bring me eight kinds in your team to sit for me. Four from the heath, four from the Deep. A wealthy patron has ordered the whole set.", "Maler Corwin: Bring mir acht Arten in deinem Team, die mir Modell sitzen. Vier von der Heide, vier aus dem Schacht. Ein reicher Gönner hat die ganze Reihe bestellt.")),
                   "flag": "ah_portraits_asked"}
    t["corwin_done"] = {"if": {"flag": "ah_portraits_done"}, "else": "corwin_c0",
                        "lines": lines(("Painter Corwin: The set is sold! To Magistrate Greaves, for the court archive. Art in a courthouse. Isn't that hopeful?", "Maler Corwin: Die Reihe ist verkauft! An Richter Greaves, fürs Gerichtsarchiv. Kunst in einem Gericht. Ist das nicht hoffnungsvoll?"),),
                        "next": "corwin_deeds"}
    for i, sp in enumerate(PORTRAITS):
        nxt = "corwin_c%d" % (i + 1) if i + 1 < len(PORTRAITS) else "corwin_end"
        t["corwin_c%d" % i] = {"if": {"has_species": sp, "not_flag": "ah_sketch_" + sp.lower()},
                               "lines": [tr("Painter Corwin: A %s! Chin up. No, its other chin." % sp, "Maler Corwin: Ein %s! Kinn hoch. Nein, das andere Kinn." % sp)],
                               "flag": "ah_sketch_" + sp.lower(), "next": nxt, "else": nxt}
    t["corwin_end"] = {"if": {"flag": ["ah_sketch_" + sp.lower() for sp in PORTRAITS]},
                       "lines": lines(("Painter Corwin: Eight! The set is done. Every kind, every scale, and where it nests, down to the stone. My patron insisted on the stones. Here, for your trouble.", "Maler Corwin: Acht! Die Reihe ist fertig. Jede Art, jede Schuppe, und wo sie nistet, auf den Stein genau. Mein Gönner bestand auf den Steinen. Hier, für deine Mühe."),),
                       "action": "set_flag ah_portraits_done; give_item swift_feather 1", "once": True, "else": "corwin_more"}
    t["corwin_more"] = lines(("Painter Corwin: Still missing some. The heath kinds are shy, the Deep kinds are shy and bite. Art is suffering. Mostly yours.", "Maler Corwin: Mir fehlen noch welche. Die Heidearten sind scheu, die Schachtarten sind scheu und beißen. Kunst ist Leiden. Hauptsächlich deins."))
    t["corwin_deeds"] = {"if": stage("ah_deeds", 1), "else": "corwin_after",
                         "lines": lines(("Painter Corwin: Deeds? My portraits are deeds? Greaves stamps each one and the clan owns the kind? And catching one is theft?", "Maler Corwin: Urkunden? Meine Porträts sind Urkunden? Greaves stempelt jedes, und dem Clan gehört die Art? Und wer eine fängt, stiehlt?"),
                                        ("Painter Corwin: ...I may have known. A little. Here are my sketches, the originals. Without them the court can't prove a thing. What do we do with them?", "Maler Corwin: ...Vielleicht hab ich's gewusst. Ein bisschen. Hier sind meine Skizzen, die Originale. Ohne die kann das Gericht nichts beweisen. Was machen wir damit?")),
                         "choices": [{"text": tr("Burn them", "Verbrennen"), "action": "quest_stage ah_deeds 2; set_flag ah_deeds_burned; give_item kin_charm 1", "flag": "ah_deeds_done", "next": "deeds_burned"},
                                     {"text": tr("Sell them to Greaves", "An Greaves verkaufen"), "action": "quest_stage ah_deeds 2; set_flag ah_deeds_sold; give_item tide_pearl 1; battle deed_hunters", "flag": "ah_deeds_done", "next": "deeds_sold"}]}
    t["deeds_burned"] = lines(("The sketches curl up in the spring fire. Corwin watches his best work go up and paints you instead, badly, as thanks.", "Die Skizzen rollen sich im Quellfeuer ein. Corwin sieht seinem besten Werk beim Verbrennen zu und malt dich stattdessen, schlecht, als Dank."))
    t["deeds_sold"] = lines(("Greaves pays in a confiscated pearl and stamps the deeds on the spot. Your own Spirlings are now Ruskweber property, and the catch tax collectors were waiting outside.", "Greaves zahlt mit einer beschlagnahmten Perle und stempelt die Urkunden sofort. Deine eigenen Spirlings sind jetzt Eigentum der Ruskwebers, und die Fangsteuereintreiber warteten schon draußen."))
    t["corwin_after"] = {"lines": lines(("Painter Corwin: I've gone back to landscapes. Nobody can own a landscape. Well. The clan owns this one. But it doesn't know.", "Maler Corwin: Ich male wieder Landschaften. Eine Landschaft kann keiner besitzen. Na ja. Diese hier gehört dem Clan. Aber sie weiß es nicht."),),
                         "after_flag": {"flag": "ah_deeds_sold", "lines": lines(("Painter Corwin: My portrait of you sells well. Under WANTED. I'm sorry. I'm also very well paid.", "Maler Corwin: Mein Porträt von dir verkauft sich gut. Unter GESUCHT. Tut mir leid. Ich werde auch sehr gut bezahlt."),)}}
    t["hunters_defeat"] = lines(("Catch Tax Collector: Tax paid in full. In bruises. We'll accept that, this once.", "Fangsteuereintreiber: Steuer vollständig bezahlt. In blauen Flecken. Wir akzeptieren das, ausnahmsweise."),)
    t["hunters_lose"] = lines(("The collectors stamp your hand with the Ruskweber mark. It washes off. The shame doesn't.", "Die Eintreiber stempeln dir das Ruskweber-Zeichen auf die Hand. Es wäscht sich ab. Die Scham nicht."))
    # The court's rest corner: keeper and supplier.
    t["keeper"] = {"lines": lines(("Usher Pim: The court keeps a bench for witnesses to rest on. Witnesses rest a lot here. Some of them permanently.", "Gerichtsdiener Pim: Das Gericht hält eine Bank bereit, auf der Zeugen ausruhen. Zeugen ruhen hier viel aus. Manche für immer."),
                                  ("Usher Pim: Your Spirlings look tired. Let them rest. No charge. The charge comes later.", "Gerichtsdiener Pim: Deine Spirlings sehen müde aus. Lass sie ausruhen. Kostet nichts. Die Anklage kommt später.")),
                   "action": "heal"}
    t["trader"] = {"lines": lines(("Supplier Rook-Hale: Tonics and brews, sold at the court's fixed prices. Fixed as in arranged.", "Händlerin Rook-Hale: Tränke und Gebräue zu den festen Preisen des Gerichts. Fest wie in abgesprochen."),),
                   "action": "shop strong_tonic max_tonic remedy revival_leaf cooling_gel dash_brew guard_brew power_brew"}
    # Juno Sallow in the Deep: the partnership (scripted betrayal juno_split), then a fourth duel.
    t["juno_offer"] = {"if": {"not_flag": "betrayal_juno_split"},
                       "lines": lines(("Juno: Rookie! Fancy meeting you down here. Slagg's payroll chest is at the bottom. Big enough for two.", "Juno: Grünschnabel! Was für ein Zufall, dich hier unten zu treffen. Slaggs Lohnkiste steht ganz unten. Groß genug für zwei."),
                                      ("Juno: Partners. I take the left gallery, you take the right. Meet at the chest. Trust me, I've changed. Rivals are so last act.", "Juno: Partner. Ich nehm die linke Strecke, du die rechte. Treffpunkt an der Kiste. Vertrau mir, ich hab mich geändert. Rivalen sind so letzter Akt.")),
                       "action": "betrayal juno_split"}
    t["split_caught"] = lines(("You remember the note from the first gallery: 'J. - right gallery, bring the net. S.' You take the left gallery.", "Du erinnerst dich an den Zettel aus der ersten Strecke: 'J. - rechte Strecke, Netz mitbringen. S.' Du nimmst die linke."),
                              ("Juno: ...You read my mail? That's low. That's beautiful. Fine. No net, no partners. Just you and me, the old way.", "Juno: ...Du liest meine Post? Das ist mies. Das ist wunderschön. Schön. Kein Netz, keine Partner. Nur du und ich, wie früher."))
    t["split_struck"] = lines(("The right gallery ends in a net and three of Slagg's pit hands. Juno's voice drifts down from the left: 'Sorry, rookie! Slagg pays per head!'", "Die rechte Strecke endet in einem Netz und drei Grubenarbeitern von Slagg. Juno ruft von links herunter: 'Tut mir leid, Grünschnabel! Slagg zahlt pro Kopf!'"),)
    t["net_defeat"] = lines(("Pit Hand: Out of the net? Juno said you'd be easy. Juno says a lot of things. Juno owes us money.", "Grubenarbeiter: Raus aus dem Netz? Juno meinte, du wärst leicht. Juno sagt viel. Juno schuldet uns Geld."),)
    t["net_lose"] = lines(("The pit hands haul you up in the net and dump you on the heath. Juno waves from a safe distance.", "Die Grubenarbeiter ziehen dich im Netz hoch und kippen dich auf die Heide. Juno winkt aus sicherer Entfernung."))
    t["ledger_split"] = lines(("The partnership", "Die Partnerschaft"),
                              ("Juno Sallow offered to split Slagg's payroll with you in the Bellows Deep and sent you down the gallery where his net was waiting.", "Juno Sallow bot dir an, Slaggs Lohnkasse im Blasebalgschacht zu teilen, und schickte dich in die Strecke, wo sein Netz wartete."))
    # Overman Slagg at the bottom of the Deep, and the last shift.
    t["slagg"] = {"if": {"not_flag": "ah_slagg_beaten"}, "else": "slagg_after",
                  "lines": lines(("Overman Slagg: Visitors! In a closed mine! Officially, you're not here. Officially, nobody is. Officially, I'm a widower with a small pension.", "Obersteiger Slagg: Besuch! In einer geschlossenen Grube! Offiziell bist du nicht hier. Offiziell ist keiner hier. Offiziell bin ich ein Witwer mit kleiner Rente."),
                                 ("Overman Slagg: The shift digs, the clan pays their wages, I collect the wages. Everyone gets something. The shift gets exercise.", "Obersteiger Slagg: Die Schicht gräbt, der Clan zahlt den Lohn, ich kassiere den Lohn. Jeder kriegt was. Die Schicht kriegt Bewegung.")),
                  "action": "battle deep_slagg"}
    t["slagg_defeat"] = lines(("Overman Slagg: All right, all right! I'll tell them the mine closed. I'll even say sorry. In writing. Unsigned.", "Obersteiger Slagg: Schon gut, schon gut! Ich sag ihnen, dass die Grube zu ist. Ich entschuldige mich sogar. Schriftlich. Ohne Unterschrift."),
                              ("Overman Slagg: Take the payroll key. Eleven years of wages. Some of it is even still there.", "Obersteiger Slagg: Nimm den Lohnschlüssel. Elf Jahre Lohn. Ein Teil davon ist sogar noch da."))
    t["slagg_lose"] = lines(("Overman Slagg: Clocked out. Come back when you've learned to dig.", "Obersteiger Slagg: Ausgestempelt. Komm wieder, wenn du graben gelernt hast."))
    t["slagg_after"] = lines(("Overman Slagg: I'm digging now. Eleven years of my shift to make up. The shift says I'm doing it wrong. The shift is enjoying this.", "Obersteiger Slagg: Ich grabe jetzt. Elf Jahre Schicht nachzuholen. Die Schicht sagt, ich mach's falsch. Die Schicht hat Spaß daran."))
    t["hamm"] = {"if": dict(stage("ah_last_shift", 0), flag="ah_tags_done"), "else": "hamm_plain",
                 "lines": lines(("Shift Boss Hamm: Closed? The Deep? Nobody told us. We've been digging for eleven years.", "Schichtführer Hamm: Geschlossen? Der Schacht? Uns hat keiner was gesagt. Wir graben seit elf Jahren."),
                                ("Shift Boss Hamm: Slagg brings bread on Sundays and takes our wage slips on Mondays. Says the clan pays in arrears. Very long arrears.", "Schichtführer Hamm: Slagg bringt sonntags Brot und montags nimmt er unsere Lohnzettel. Sagt, der Clan zahlt nachträglich. Sehr nachträglich."),
                                ("Shift Boss Hamm: Tell Orla we're alive. She'll want her tags back. She was always strict about tags.", "Schichtführer Hamm: Sag Orla, dass wir leben. Sie will ihre Marken zurück. Bei Marken war sie immer streng.")),
                 "action": "quest_stage ah_last_shift 1; set_flag ah_shift_found"}
    t["hamm_plain"] = {"lines": lines(("Shift Boss Hamm: Mind the props. They're older than you and less forgiving.", "Schichtführer Hamm: Pass auf die Stempel auf. Die sind älter als du und weniger nachsichtig."),),
                       "after_flag": {"flag": "ah_slagg_beaten", "lines": lines(("Shift Boss Hamm: Eleven years of back pay! We're going up tomorrow. First thing I'll do is look at the sky. Second thing, sue.", "Schichtführer Hamm: Elf Jahre Lohn nachgezahlt! Morgen fahren wir aus. Als Erstes schau ich mir den Himmel an. Als Zweites verklag ich wen."),)}}
    world.add_text(SIDE, t)


# --- Clinker Heath: a slag heath south of Cinderfold -------------------------------------------
def heath(world):
    rows = ["^^^^^__^^^^^",
            "^::..__..,,^",
            "^::..._..,,^",
            "^.*..._.*..^",
            "^,,,.__....^",
            "^,,,._..::.^",
            "^...._..::.^",
            "^.@..__....^",
            "^::...__.,,^",
            "^::....__,,^",
            "^..RRRRR_..^",
            "^..HHDHH_..^",
            "^....____..^",
            "^,,.._...,,^",
            "^,,.__...,,^",
            "^...._.....^",
            "^.T.._..::.^",
            "^:..__..::.^",
            "^:.._.....@^",
            "^,,._..,,,.^",
            "^,,.__.,,,.^",
            "^....__....^",
            "^.::..__.*.^",
            "^.::...__..^",
            "^..T....__.^",
            "^,,,....._.^",
            "^,,,..____.^",
            "^....__.:..^",
            "^.*.._.::..^",
            "^...._.....^",
            "^....__.@..^",
            "^^^^^__^^^^^"]
    text = {}
    signs = []
    for i, (mid, f, x, y, line) in enumerate(TAGS):
        if mid != HEATH:
            continue
        put(rows, x, y, "S")
        text["tag_%d" % (i + 1)] = tag_entry(i + 1, line)
        signs.append({"x": x, "y": y, "dialogue": "%s/tag_%d" % (HEATH, i + 1)})
    text["tag_empty"] = lines(("Only a nail where a tag hung.", "Nur ein Nagel, wo eine Marke hing."))
    for i, (x, y, line) in enumerate(NOTICES):
        put(rows, x, y, "S")
        key = "notice_%d" % (i + 1)
        text[key] = {"if": {"flag": "ah_mourner_asked", "not_flag": "ah_" + key}, "else": key + "_plain",
                     "lines": lines(line, ("You pin up one of Mercer's notices. 'Departed, suddenly, tomorrow.' The ink is still wet.", "Du pinnst einen von Mercers Zetteln an. 'Verstorben, plötzlich, morgen.' Die Tinte ist noch nass.")),
                     "action": "set_flag ah_" + key}
        text[key + "_plain"] = lines(line)
        signs.append({"x": x, "y": y, "dialogue": "%s/%s" % (HEATH, key)})
    put(rows, 9, 1, "S")
    text["sign"] = lines(("CLINKER HEATH", "SCHLACKENHEIDE"),
                         ("North: Cinderfold. South: the Bellows Deep, closed. In between: the Ash Assize, open, unfortunately.", "Norden: Cinderfold. Süden: der Blasebalgschacht, geschlossen. Dazwischen: das Aschegericht, geöffnet, leider."))
    signs.append({"x": 9, "y": 1, "dialogue": HEATH + "/sign"})
    put(rows, 7, 30, "S")
    text["deep_sign"] = lines(("BELLOWS DEEP - CLOSED BY ORDER OF THE RUSKWEBER CLAN.", "BLASEBALGSCHACHT - GESCHLOSSEN AUF ANORDNUNG DES RUSKWEBER-CLANS."),
                              ("Under it, newer: 'Wages still payable at the office below.'", "Darunter, neuer: 'Löhne weiterhin im Büro unten zahlbar.'"))
    signs.append({"x": 7, "y": 30, "dialogue": HEATH + "/deep_sign"})
    world.add_text(HEATH, text)

    def juror(n, id_, x, y, facing, title, crew, talk, intro, defeat, money):
        w = wayfarer(world, HEATH, id_, x, y, facing, title, crew, talk, intro, defeat, money)
        w["beaten_flag"] = "ah_juror_%d" % n
        return w

    jury = [
        juror(1, "clem", 8, 5, "left", tr("Juror Clem", "Geschworener Clem"), team(("Brickwarden", 33), ("Sootlurk", 33)),
              [("Clem: Juror number one. I was picked because I own a chair. Most of the heath doesn't.", "Clem: Geschworener Nummer eins. Ich wurde gewählt, weil ich einen Stuhl besitze. Der Großteil der Heide hat keinen.")],
              [("Clem: My vote's for sale. The price is one duel. Inflation, you know.", "Clem: Meine Stimme ist käuflich. Der Preis ist ein Duell. Inflation, du weißt schon.")],
              [("Clem: Sold. Tell Greaves I said guilty. Of whatever. He'll know.", "Clem: Verkauft. Sag Greaves, ich hab schuldig gesagt. Von was auch immer. Er weiß Bescheid.")], 1700),
        juror(2, "mattie", 2, 9, "right", tr("Juror Mattie", "Geschworene Mattie"), team(("Peatbloom", 33), ("Vaporel", 33), ("Bogwick", 34)),
              [("Mattie: I've sat on forty juries. The verdict was always the same. I find that comforting.", "Mattie: Ich saß in vierzig Geschworenenbänken. Das Urteil war immer dasselbe. Ich finde das beruhigend.")],
              [("Mattie: Win my vote and I'll vote. It won't count, but I'll do it beautifully.", "Mattie: Gewinn meine Stimme, und ich stimme ab. Sie zählt nicht, aber ich mach's wunderschön.")],
              [("Mattie: My vote is yours. Keep the receipt.", "Mattie: Meine Stimme gehört dir. Heb die Quittung auf.")], 1750),
        juror(3, "dunstan", 9, 14, "left", tr("Juror Dunstan", "Geschworener Dunstan"), team(("Ingotlet", 34), ("Mortarant", 34), ("Brickwarden", 34)),
              [("Dunstan: I'm on the jury because the clan owes me money. They pay me in verdicts.", "Dunstan: Ich bin Geschworener, weil der Clan mir Geld schuldet. Sie zahlen mich in Urteilen.")],
              [("Dunstan: Three votes down, two to go. Or three to go, if you lose to me. Do the maths.", "Dunstan: Drei Stimmen weg, zwei übrig. Oder drei übrig, wenn du gegen mich verlierst. Rechne nach.")],
              [("Dunstan: Fine. Vote cast. Into a very deep well, probably.", "Dunstan: Schön. Stimme abgegeben. In einen sehr tiefen Brunnen, vermutlich.")], 1800),
        juror(4, "wick", 2, 20, "right", tr("Juror Wick", "Geschworene Wick"), team(("Puffbellow", 34), ("Charsprout", 34), ("Sablowl", 35)),
              [("Wick: I fell asleep during my last trial. I voted in my sleep. The defendant was hanged in effigy. The effigy was furious.", "Wick: Bei meinem letzten Prozess bin ich eingeschlafen. Ich hab im Schlaf abgestimmt. Der Angeklagte wurde in Abwesenheit gehängt. Als Strohpuppe. Die Puppe war außer sich.")],
              [("Wick: Wake me up, then. If you can.", "Wick: Dann weck mich. Wenn du kannst.")],
              [("Wick: I'm up. I'm up. My vote's yours. What were we voting on?", "Wick: Ich bin wach. Ich bin wach. Meine Stimme gehört dir. Worüber stimmen wir ab?")], 1850),
        juror(5, "ansa", 10, 26, "left", tr("Foreman of the Jury Ansa", "Obfrau Ansa"), team(("Smeltmaw", 35), ("Lampick", 34), ("Brickwarden", 35)),
              [("Ansa: Foreman of the jury. I read the verdict out loud. Greaves writes it, I read it. It's a very good job. Low thinking.", "Ansa: Obfrau der Geschworenen. Ich lese das Urteil vor. Greaves schreibt es, ich lese es. Ein sehr guter Job. Wenig Denken.")],
              [("Ansa: Last vote. Make it count. It won't, but make it.", "Ansa: Letzte Stimme. Lass sie zählen. Sie wird nicht zählen, aber lass sie.")],
              [("Ansa: Unanimous, then. Go and hear your verdict. Read the docket first. I'm not allowed to say that.", "Ansa: Dann einstimmig. Geh und hör dir dein Urteil an. Lies vorher die Akte. Das darf ich nicht sagen.")], 1900),
    ]
    people = [
        npc("tull", 9, 7, "left", SIDE + "/tull", "elder"),
        npc("corwin", 3, 15, "right", SIDE + "/corwin", "villager", color="8a5a7a"),
        npc("mercer", 7, 3, "left", SIDE + "/mercer", "elder", color="3a3a4a"),
    ]
    check_rows(HEATH, rows)
    m = {"name": tr("Clinker Heath", "Schlackenheide"), "region": "ashmere", "biome": "route", "backdrop": "ember", "outdoor": True,
         "encounters": HEATH, "rows": rows,
         "warps": [warp(5, 0, "cinderfold", 5, 14, "up"), warp(6, 0, "cinderfold", 6, 14, "up"),
                   warp(5, 11, HALL, 5, 8, "up"),
                   warp(5, 31, DEEP, 5, 10, "up"), warp(6, 31, DEEP, 6, 10, "up")],
         "npcs": jury + people, "signs": signs,
         "secrets": [secret(0, 5, "max_tonic", "find_clinker_west", 2), secret(11, 9, "revival_leaf", "find_clinker_east"),
                     secret(2, 7, "power_brew", "find_clinker_slag"), secret(0, 22, "strong_tonic", "find_clinker_scree", 3),
                     secret(11, 28, "spark_drop", "find_clinker_snag")]}
    world.add_map(HEATH, m)


# --- The Ash Assize: the court, the dock, the archive and the heath's rest corner --------------
def assize(world):
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
    put(rows, 1, 4, "S")
    world.add_text(HALL, {
        "docket": {"if": {"flag": "ah_assize_asked"}, "else": "docket_plain",
                   "lines": lines(("The court docket, page two: 'Wage plates, the Ruskweber clan against everyone. Verdict: for the clan (prepaid). Jury: advisory.'", "Die Gerichtsakte, Seite zwei: 'Lohnplatten, der Ruskweber-Clan gegen alle. Urteil: für den Clan (vorab bezahlt). Geschworene: beratend.'"),
                                  ("Dated last Tuesday. In the margin, in Tansy's hand: 'Advisory means ignored.'", "Datiert auf letzten Dienstag. Am Rand, in Tansys Schrift: 'Beratend heißt ignoriert.'")),
                   "flag": "ah_docket_read"},
        "docket_plain": lines(("A thick court docket. The first page is a list of fees for reading the docket.", "Eine dicke Gerichtsakte. Die erste Seite ist eine Gebührenliste fürs Lesen der Akte."),),
        "archive": {"if": dict(stage("ah_deeds", 0), flag="ah_portraits_done"), "else": "archive_plain",
                    "lines": lines(("The court archive. Corwin's eight portraits hang framed on the wall, each one stamped: 'DEED. This kind and its nests are property of the Ruskweber clan.'", "Das Gerichtsarchiv. Corwins acht Porträts hängen gerahmt an der Wand, jedes gestempelt: 'URKUNDE. Diese Art und ihre Nester sind Eigentum des Ruskweber-Clans.'"),
                                   ("Under them, a new rule: 'Catching a deeded kind is theft. Fine: one Spirling.' Corwin should hear about this.", "Darunter eine neue Regel: 'Wer eine verbriefte Art fängt, stiehlt. Strafe: ein Spirling.' Corwin sollte davon erfahren.")),
                    "action": "quest_stage ah_deeds 1"},
        "archive_plain": lines(("The court archive. Verdicts, sorted by price.", "Das Gerichtsarchiv. Urteile, nach Preis sortiert."),),
    })
    people = [
        npc("greaves", 5, 2, "down", SIDE + "/greaves", "elder", color="5a3a3a"),
        npc("tansy", 8, 2, "down", SIDE + "/tansy", "villager", color="7a7a9a"),
        npc("briony", 3, 5, "right", SIDE + "/briony", "villager", color="9a6a3a"),
        npc("orla", 9, 7, "left", SIDE + "/orla", "elder", color="8a8a5a"),
        npc("keeper", 2, 2, "down", SIDE + "/keeper", "elder"),
        npc("trader", 2, 7, "right", SIDE + "/trader", "villager"),
    ]
    check_rows(HALL, rows)
    m = {"name": tr("Ash Assize", "Aschegericht"), "region": "ashmere", "biome": "town", "backdrop": "ember",
         "rows": rows, "warps": [warp(5, 9, HEATH, 5, 12, "down")],
         "npcs": people,
         "signs": [{"x": 10, "y": 4, "dialogue": HALL + "/docket"}, {"x": 1, "y": 4, "dialogue": HALL + "/archive"}],
         "secrets": [secret(11, 5, "max_tonic", "find_assize_evidence")]}
    world.add_map(HALL, m)


# --- The Bellows Deep: a shut coal deep, three floors ------------------------------------------
def deep(world):
    rows0 = ["@@@@@==@@@@@",
             "@..........@",
             "@.::....::.@",
             "@.::.@@.::.@",
             "@.....@....@",
             "@@.@@..@@.@@",
             "@:........:@",
             "@:.@@..@@.:@",
             "@..........@",
             "@...::::...@",
             "@..........@",
             "@@@@@__@@@@@"]
    rows1 = ["@@@@@==@@@@@",
             "@..........@",
             "@..::..::..@",
             "@..........@",
             "@:.@@..@@.:@",
             "@:........:@",
             "@@.@@..@@.@@",
             "@..........@",
             "@.::....::.@",
             "@..........@",
             "@..........@",
             "@@@@@==@@@@@"]
    rows2 = ["@@@@@@@@@@@@",
             "@..........@",
             "@:..CCCC..:@",
             "@..........@",
             "@::......::@",
             "@..........@",
             "@:...@@...:@",
             "@..........@",
             "@@@@@==@@@@@"]
    floors = [rows0, rows1, rows2]
    text = {}
    signs = [[], [], []]
    for n, v in enumerate(BELLOWS):
        rows = floors[n]
        for i, (x, y) in enumerate(v["cells"]):
            put(rows, x, y, "S")
            key = "bellows_%d_%d" % (n + 1, i + 1)
            text[key] = {"lines": lines(v["names"][i]), "action": "bell %s %d %d bellows" % (v["flag"], v["order"].index(i) + 1, len(v["cells"]))}
            signs[n].append({"x": x, "y": y, "dialogue": "%s/%s" % (DEEP, key)})
        wx, wy = v["wall"]
        put(rows, wx, wy, "S")
        text["hint_%d" % (n + 1)] = lines(v["hint"])
        signs[n].append({"x": wx, "y": wy, "dialogue": "%s/hint_%d" % (DEEP, n + 1)})
    for i, (mid, f, x, y, line) in enumerate(TAGS):
        if mid != DEEP:
            continue
        put(floors[f], x, y, "S")
        text["tag_%d" % (i + 1)] = tag_entry(i + 1, line)
        signs[f].append({"x": x, "y": y, "dialogue": "%s/tag_%d" % (DEEP, i + 1)})
    text["tag_empty"] = lines(("A clean square in the coal dust where a tag lay.", "Ein sauberes Viereck im Kohlenstaub, wo eine Marke lag."))
    # Floor 1: Juno's note to Slagg.
    put(rows0, 10, 10, "S")
    text["note"] = {"lines": lines(("A note pinned to a prop, in a hand you know from three races: 'S. - I'll send the rookie down the right gallery. Bring the net. Per head, as agreed. J.'", "Ein Zettel an einem Stempel, in einer Schrift, die du von drei Rennen kennst: 'S. - Ich schick den Grünschnabel in die rechte Strecke. Netz mitbringen. Pro Kopf, wie besprochen. J.'"),),
                    "flag": "ah_juno_note"}
    signs[0].append({"x": 10, "y": 10, "dialogue": DEEP + "/note"})
    # Floor 2: Mercer's auction book.
    put(rows1, 1, 9, "S")
    text["auction"] = {"if": stage("ah_mourner", 2), "else": "auction_plain",
                       "lines": lines(("An auction book: 'Tull, cottage, sale the day after the service. Grice, cottage and curtains, SOLD. Pell, one barrow, no bids.' Signed: M.", "Ein Auktionsbuch: 'Tull, Häuschen, Verkauf am Tag nach der Feier. Grice, Häuschen und Vorhänge, VERKAUFT. Pell, eine Schubkarre, keine Gebote.' Gezeichnet: M."),
                                      ("Every name in the book is on one of Mercer's notices. Every one of them is alive.", "Jeder Name im Buch steht auf einem von Mercers Zetteln. Jeder davon lebt.")),
                       "action": "quest_stage ah_mourner 3"}
    text["auction_plain"] = lines(("A ledger of cottages sold after funerals. The funerals were all very well attended. By buyers.", "Ein Buch über Häuschen, die nach Beerdigungen verkauft wurden. Die Beerdigungen waren alle sehr gut besucht. Von Käufern."),)
    signs[1].append({"x": 1, "y": 9, "dialogue": DEEP + "/auction"})
    put(rows0, 1, 1, "S")
    text["sign"] = lines(("BELLOWS DEEP - LAST SHIFT DOWN: ELEVEN YEARS AGO. LAST SHIFT UP: PENDING.", "BLASEBALGSCHACHT - LETZTE SCHICHT EINGEFAHREN: VOR ELF JAHREN. LETZTE SCHICHT AUSGEFAHREN: AUSSTEHEND."),)
    signs[0].append({"x": 1, "y": 1, "dialogue": DEEP + "/sign"})
    world.add_text(DEEP, text)

    crew0 = [
        wayfarer(world, DEEP, "brodie", 3, 4, "right", tr("Pit Hand Brodie", "Grubenarbeiter Brodie"), team(("Clinkshell", 35), ("Coalbuck", 35)),
                 [("Brodie: I work for Slagg. Officially I work for nobody. The pay is the same either way.", "Brodie: Ich arbeite für Slagg. Offiziell arbeite ich für niemanden. Die Bezahlung ist so oder so dieselbe.")],
                 [("Brodie: This mine is closed. So close your eyes and go away.", "Brodie: Diese Grube ist geschlossen. Also mach die Augen zu und geh.")],
                 [("Brodie: Shut down. Like the mine. Allegedly.", "Brodie: Stillgelegt. Wie die Grube. Angeblich.")], 2000),
        wayfarer(world, DEEP, "fuse", 8, 8, "left", tr("Fuse Girl Senna", "Zündmädchen Senna"), team(("Glowflit", 35), ("Cindle", 35), ("Sootlurk", 36)),
                 [("Senna: I light the fuses. Short ones for rocks, long ones for questions.", "Senna: Ich zünde die Lunten. Kurze für Felsen, lange für Fragen.")],
                 [("Senna: You've got a short fuse. Let's find out.", "Senna: Du hast eine kurze Lunte. Finden wir's raus.")],
                 [("Senna: Fizzled. Happens to the best fuses.", "Senna: Verpufft. Passiert den besten Lunten.")], 2050),
        wayfarer(world, DEEP, "weighman", 2, 9, "right", tr("Weighman Tolliver", "Wiegemeister Tolliver"), team(("Coalbuck", 36), ("Lodebrock", 36)),
                 [("Tolliver: I weigh the coal. The scale is honest. The weights are not.", "Tolliver: Ich wiege die Kohle. Die Waage ist ehrlich. Die Gewichte nicht.")],
                 [("Tolliver: Let's see how much you weigh. Before and after.", "Tolliver: Mal sehen, was du wiegst. Vorher und nachher.")],
                 [("Tolliver: Lighter than you looked. Like everyone's wages.", "Tolliver: Leichter, als du aussahst. Wie jeder Lohn.")], 2100),
    ]
    crew1 = [
        wayfarer(world, DEEP, "crabbe", 3, 3, "right", tr("Foreman Crabbe", "Vorarbeiter Crabbe"), team(("Fumewraith", 36), ("Stylox", 36), ("Clinkshell", 37)),
                 [("Crabbe: I'm the foreman of a shift that doesn't exist, in a mine that's closed, for a clan that denies me. Very relaxing job.", "Crabbe: Ich bin Vorarbeiter einer Schicht, die es nicht gibt, in einer Grube, die zu ist, für einen Clan, der mich verleugnet. Sehr entspannter Job.")],
                 [("Crabbe: Nobody gets to the bottom gallery. Slagg's orders. Slagg doesn't exist either.", "Crabbe: Keiner kommt in die unterste Strecke. Slaggs Befehl. Slagg gibt es auch nicht.")],
                 [("Crabbe: Go on down, then. Tell nobody I let you. Nobody will believe you anyway.", "Crabbe: Dann geh halt runter. Sag keinem, dass ich dich gelassen hab. Glaubt dir sowieso keiner.")], 2200),
        wayfarer(world, DEEP, "dorcas", 8, 7, "left", tr("Lamp Keeper Dorcas", "Lampenwartin Dorcas"), team(("Glazelisk", 36), ("Lampick", 37)),
                 [("Dorcas: I keep the lamps lit so the shift can see. Slagg keeps the shift so I can be paid. It's a circle. A grubby little circle.", "Dorcas: Ich halte die Lampen an, damit die Schicht was sieht. Slagg hält die Schicht, damit ich bezahlt werde. Ein Kreis. Ein schmutziger kleiner Kreis.")],
                 [("Dorcas: Lights out, visitor.", "Dorcas: Licht aus, Besuch.")],
                 [("Dorcas: Lights on, then. You win. Mind the dark bits.", "Dorcas: Dann Licht an. Du gewinnst. Pass auf die dunklen Stellen auf.")], 2250),
    ]
    juno = wayfarer(world, DEEP, "juno_4", 6, 7, "down", tr("Juno Sallow", "Juno Sallow"), team(("Ashcrest", 37), ("Smeltmaw", 37), ("Glassfell", 38), ("Tempestrel", 38)),
                    [("Juno: Fourth time. I'm keeping count. You're keeping score. Nobody's keeping friends.", "Juno: Das vierte Mal. Ich zähle mit. Du zählst Punkte. Freunde zählt keiner.")],
                    [("Juno: No more partners. Just rivals. It's more honest. I hate it.", "Juno: Keine Partner mehr. Nur Rivalen. Das ist ehrlicher. Ich hasse es.")],
                    [("Juno: Four to nothing. Fine. Next act, I'm bringing a lawyer. Not Greaves. A real one.", "Juno: Vier zu null. Schön. Nächsten Akt bring ich einen Anwalt mit. Nicht Greaves. Einen echten.")], 2600)
    juno["show_flag"] = "betrayal_juno_split"
    juno["sprite"] = "ranger"
    juno["ai"] = 3
    juno["beaten_flag"] = "beat_juno_4"
    offer = npc("juno_offer", 6, 7, "down", SIDE + "/juno_offer", "ranger", show_flag="beat_juno_3", hide_flag="betrayal_juno_split")
    slagg = {"id": "slagg", "x": 6, "y": 3, "facing": "down", "dialogue": SIDE + "/slagg", "sprite": "elder", "color": "4a4a3a"}
    hamm = npc("hamm", 2, 5, "right", SIDE + "/hamm", "villager", color="6a5a4a")
    for n, rows in enumerate(floors):
        check_rows("%s floor %d" % (DEEP, n), rows)
    f0 = {"name": tr("Bellows Deep", "Blasebalgschacht"), "region": "ashmere", "biome": "dungeon", "backdrop": "ember", "encounters": DEEP,
          "rows": rows0,
          "warps": [warp(5, 11, HEATH, 5, 30, "down"), warp(6, 11, HEATH, 6, 30, "down"),
                    warp(5, 0, DEEP + "@1", 5, 10, "up"), warp(6, 0, DEEP + "@1", 6, 10, "up")],
          "npcs": crew0, "signs": signs[0],
          "blocks": [gate(5, 0, "ah_bellows_1"), gate(6, 0, "ah_bellows_1")],
          "secrets": [secret(11, 6, "max_tonic", "find_bellows_prop", 2), secret(0, 8, "revival_leaf", "find_bellows_tin")]}
    f1 = {"name": tr("Bellows Deep, haulage gallery", "Blasebalgschacht, Förderstrecke"), "rows": rows1,
          "warps": [warp(5, 11, DEEP, 5, 1, "down"), warp(6, 11, DEEP, 6, 1, "down"),
                    warp(5, 0, DEEP + "@2", 5, 7, "up"), warp(6, 0, DEEP + "@2", 6, 7, "up")],
          "npcs": crew1 + [offer, juno], "signs": signs[1],
          "blocks": [gate(5, 0, "ah_bellows_2"), gate(6, 0, "ah_bellows_2")],
          "secrets": [secret(0, 7, "power_brew", "find_bellows_cart"), secret(11, 3, "spark_drop", "find_bellows_seam")]}
    f2 = {"name": tr("Bellows Deep, bottom gallery", "Blasebalgschacht, unterste Strecke"), "rows": rows2,
          "warps": [warp(5, 8, DEEP + "@1", 5, 1, "down"), warp(6, 8, DEEP + "@1", 6, 1, "down")],
          "npcs": [slagg, hamm], "signs": signs[2],
          "secrets": [secret(11, 5, "max_tonic", "find_bellows_payroll", 2)]}
    f0["floors"] = [f1, f2]
    world.add_map(DEEP, f0)


def main():
    world = common.World()
    build(world)
    german = dict(common.GERMAN)
    common.GERMAN.clear()
    world.write()
    path = os.path.join(common.ROOT, "tools", "i18n", "de_ashmere_more.py")
    with open(path, "w") as f:
        f.write("# German texts for Clinker Heath, the Ash Assize and the Bellows Deep (Act III).\n")
        f.write("# Written by tools/art/world/ashmere_more.py from its tr()/lines() pairs; EXTRA below is kept by hand there.\n")
        f.write("T = {\n")
        for en in sorted(set(german) | set(EXTRA)):
            de = german.get(en, EXTRA.get(en))
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(de, ensure_ascii=False)))
        f.write("}\n")
    print("ashmere_more: %d German texts" % len(set(german) | set(EXTRA)))


# German texts that are not in a map or dialogue file: side goals, story duels, the bellows puzzle.
EXTRA = {
    # Bellows puzzle (Overworld.SWITCH_LINES "bellows")
    "The bellows breathe on their own now. The stair stays clear.": "Die Blasebälge atmen jetzt von selbst. Die Treppe bleibt frei.",
    "The bellows wheeze, cough, and every one sags flat again. Start over.": "Die Blasebälge keuchen, husten, und alle sacken wieder platt zusammen. Fang von vorn an.",
    "The bellows heave. Somewhere below, a fire wakes up grumpy.": "Der Blasebalg pumpt. Irgendwo unten wacht ein Feuer schlecht gelaunt auf.",
    "The last bellows heaves, the smoke clears off the stair, and the way down is open!": "Der letzte Blasebalg pumpt, der Rauch zieht von der Treppe ab, und der Weg nach unten ist frei!",
    # Side goals (data/quests.json)
    "The Ash Assize sells verdicts by the vote. Five jurors walk Clinker Heath. Beat each one and the vote is yours.": "Das Aschegericht verkauft Urteile nach Stimmen. Fünf Geschworene laufen über die Schlackenheide. Schlag jeden, dann gehört dir seine Stimme.",
    "Briony Cask is on trial in the Ash Assize and wants you to swear she was with you.": "Briony Cask steht vor dem Aschegericht und will, dass du schwörst, sie sei bei dir gewesen.",
    "Mourner Mercer wants three funeral notices pinned on the boards of Clinker Heath.": "Trauerredner Mercer will drei Trauerzettel an die Bretter der Schlackenheide gepinnt haben.",
    "The funerals are tomorrow. One of the departed, Old Abner Tull, walks the heath every day.": "Die Beerdigungen sind morgen. Einer der Verstorbenen, der alte Abner Tull, läuft jeden Tag über die Heide.",
    "Tull says Mercer keeps an auction book in the Bellows Deep. Find it.": "Tull sagt, Mercer hat ein Auktionsbuch im Blasebalgschacht. Finde es.",
    "Every name in Mercer's book is alive. Confront the mourner on Clinker Heath.": "Jeder Name in Mercers Buch lebt. Stell den Trauerredner auf der Schlackenheide zur Rede.",
    "Tally Keeper Orla wants the eight tally tags of the last shift of the Bellows Deep.": "Markenwartin Orla will die acht Marken der letzten Schicht des Blasebalgschachts.",
    "The Deep's tags are new brass. Look for the last shift in the bottom gallery of the Bellows Deep.": "Die Marken aus dem Schacht sind neues Messing. Such die letzte Schicht in der untersten Strecke des Blasebalgschachts.",
    "The last shift is alive and still digging. Tell Orla in the Ash Assize.": "Die letzte Schicht lebt und gräbt noch. Sag es Orla im Aschegericht.",
    "Overman Slagg collects the shift's wages. Beat him at the bottom of the Bellows Deep.": "Obersteiger Slagg kassiert den Lohn der Schicht. Schlag ihn ganz unten im Blasebalgschacht.",
    "Painter Corwin wants to paint eight kinds of Spirling from Clinker Heath and the Bellows Deep. Bring each one in your team.": "Maler Corwin will acht Arten von Spirlings von der Schlackenheide und aus dem Blasebalgschacht malen. Bring jede in deinem Team mit.",
    "Corwin's portraits went to Magistrate Greaves. Find out why in the archive of the Ash Assize.": "Corwins Porträts gingen an Richter Greaves. Finde im Archiv des Aschegerichts heraus, wozu.",
    "Each portrait is a deed: the clan owns every kind painted. Tell Corwin on Clinker Heath.": "Jedes Porträt ist eine Urkunde: Dem Clan gehört jede gemalte Art. Sag es Corwin auf der Schlackenheide.",
    "The deeds are settled, one way or another.": "Die Urkunden sind erledigt, so oder so.",
    "Someone still runs the Bellows Deep, closed for eleven years. Find out who.": "Jemand betreibt noch den Blasebalgschacht, der seit elf Jahren geschlossen ist. Finde heraus, wer.",
    "Juno Sallow is in the Bellows Deep and wants to be partners.": "Juno Sallow ist im Blasebalgschacht und will Partnerin sein.",
    "Clinker Heath and the Ash Assize": "Schlackenheide und das Aschegericht",
    "Clinker Heath and the Bellows Deep": "Schlackenheide und der Blasebalgschacht",
    # Story duels (data/story_battles.json)
    "Assize Bailiffs": "Gerichtsdiener",
    "Ruskweber Fences": "Hehler der Ruskwebers",
    "Mourner Mercer": "Trauerredner Mercer",
    "Catch Tax Collectors": "Fangsteuereintreiber",
    "Slagg's Pit Hands": "Slaggs Grubenarbeiter",
    "Overman Slagg": "Obersteiger Slagg",
}


if __name__ == "__main__":
    main()
