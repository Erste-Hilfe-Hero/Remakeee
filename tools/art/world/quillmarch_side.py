"""Quillmarch side content: eight side goals that each end in a betrayal, three landmark halls on the
roads, three story duels, one more Wayfarer per road and more hidden finds. Called by
tools/art/world/quillmarch.py (run that, not this file); it puts the figures on the region's maps,
writes their texts into data/dialogue/quillmarch.json, the goals into data/quests.json (ids q3_*)
and the duels into data/story_battles.json (ids q3_*).

Every goal runs the same way, with its own flags q3_<id>_<step>:
  giver      asked    sets the goal going
  step 1     s1       shows once asked
  step 2     s2       shows once s1 is set
  giver      reveal   back at the giver: the truth comes out
  betrayer   done     shows once reveal is set; beating them sets done (win_flags)
  reward     paid     the giver pays, or, when the giver was the betrayer ("turns"), you take it off them
Three goals end in a trust choice at the giver instead of a plain reward: "trusted" or "kept" is set
with paid, the reward differs and a witness turns up for the answer given.
Progress counts s1, s2, reveal and done; the stages follow with "quest_stage".
Teams come from the road they belong to (sheet slots and WILD), always within three elements:
betrayers at ring top -1, top, top +1, the extra Wayfarers spread over the road's ring, the hall
duellists at top, top, top +1.
"""
import itertools
import json
import os

# --- Landmark halls: a house on a road (door at 2,13 in place of the rock at 1-3,12-13) ---------
HALL_DOOR = (2, 13)
HALLS = [
    {"id": "dead_letter_office", "road": "drypoint_lane", "name": ("Dead Letter Office", "Amt für tote Briefe"),
     "rows": ["WWWWWWWWWWWW",
              "WCCCffffCCCW",
              "WffffffffffW",
              "WCCffffffCCW",
              "WSffffffffSW",
              "WffffCCffffW",
              "WCffffffffCW",
              "WffffffffffW",
              "WffffffffffW",
              "WWWWWDWWWWWW"],
     "signs": [("Shelf label: 'Returned to sender. Sender returned to sender.'", "Regalschild: 'Zurück an den Absender. Absender zurück an den Absender.'"),
               ("Pigeonholes up to the ceiling. Every one holds a letter nobody collected. Several are addressed to you.", "Brieffächer bis unter die Decke. In jedem liegt ein Brief, den keiner abgeholt hat. Mehrere sind an dich adressiert.")],
     "finds": ["wake_bell", "max_tonic"],
     "duel": {"title": ("Dead Letter Clerk Osvald", "Totbrief-Schreiber Osvald"), "sprite": "elder", "reward": ("max_tonic", 2),
              "talk": [("Osvald: There's a letter here for you. Posted eleven years ago.", "Osvald: Hier liegt ein Brief für dich. Vor elf Jahren aufgegeben."),
                       ("Osvald: Unclaimed mail is released by duel. It's an old rule. I wrote it last week.", "Osvald: Nicht abgeholte Post wird per Duell herausgegeben. Eine alte Regel. Ich habe sie letzte Woche geschrieben.")],
              "yes": ("Duel for the letter", "Duell um den Brief"), "no": ("Leave it unread", "Lass ihn ungelesen"),
              "fight": ("Osvald: Sign here. In case you lose, it says where to forward you.", "Osvald: Unterschreib hier. Falls du verlierst, steht da, wohin wir dich nachsenden."),
              "later": ("Osvald: It'll keep. It has kept eleven years. The ink is getting impatient, though.", "Osvald: Der hält sich. Er hält sich seit elf Jahren. Nur die Tinte wird ungeduldig."),
              "defeat": ("Osvald: Delivered. Finally. That ruins my record.", "Osvald: Zugestellt. Endlich. Das ruiniert meine Bilanz."),
              "lose": ("Osvald: Return to sender.", "Osvald: Zurück an den Absender."),
              "pay": [("Osvald: Your letter. It says: 'Do not go to Quillmarch.' Unsigned. There was a parcel with it.", "Osvald: Dein Brief. Darin steht: 'Geh nicht nach Quillmarch.' Ohne Unterschrift. Es lag ein Päckchen dabei.")],
              "done": ("Osvald: No more mail for you. I checked twice. I was hoping.", "Osvald: Keine Post mehr für dich. Ich habe zweimal nachgesehen. Ich hatte gehofft.")}},
    {"id": "errata_chapel", "road": "gravers_causeway", "name": ("Errata Chapel", "Errata-Kapelle"),
     "rows": ["WWWWWWWWWWWW",
              "WffCCCCCCffW",
              "WffffffffffW",
              "WffffffffffW",
              "WSffffffffSW",
              "WffCffffCffW",
              "WffffffffffW",
              "WffCffffCffW",
              "WffffffffffW",
              "WWWWWDWWWWWW"],
     "signs": [("Plaque: 'Here we correct the dead. The living may queue.'", "Tafel: 'Hier berichtigen wir die Toten. Die Lebenden dürfen sich anstellen.'"),
               ("A wall of trial prints. 'Loving husband' is struck out on most of them.", "Eine Wand voller Probedrucke. 'Liebender Ehemann' ist auf den meisten durchgestrichen.")],
     "finds": ["revival_leaf", "remedy"],
     "duel": {"title": ("Epitaph Cutter Runhild", "Grabschriftmeißlerin Runhild"), "sprite": "villager", "reward": ("revival_leaf", 2),
              "talk": [("Runhild: I cut one line for every visitor. Beat me and you choose the words.", "Runhild: Ich meißle für jeden Besucher eine Zeile. Schlag mich, und du wählst die Worte."),
                       ("Runhild: Lose and I choose. I'm in a mood today.", "Runhild: Verlierst du, wähle ich. Ich habe heute so eine Laune.")],
              "yes": ("Duel for the wording", "Duell um den Wortlaut"), "no": ("Stay unwritten", "Bleib ungeschrieben"),
              "fight": ("Runhild: The chisel is sharp. Hold your name steady.", "Runhild: Der Meißel ist scharf. Halt deinen Namen ruhig."),
              "later": ("Runhild: Everyone gets a line in the end. I can wait. I mostly do.", "Runhild: Am Ende kriegt jeder eine Zeile. Ich kann warten. Meistens tue ich das."),
              "defeat": ("Runhild: Your words, then. Short ones, please. Granite charges by the letter.", "Runhild: Dann eben deine Worte. Kurze, bitte. Granit rechnet nach Buchstaben ab."),
              "lose": ("Runhild: 'Tried.' That's the whole line.", "Runhild: 'Hat es versucht.' Das ist die ganze Zeile."),
              "pay": [("Runhild: You chose 'Not yet'. Good line. Here, the chapel gives these to people it can't use yet.", "Runhild: Du hast 'Noch nicht' gewählt. Gute Zeile. Hier, das gibt die Kapelle Leuten, die sie noch nicht brauchen kann.")],
              "done": ("Runhild: 'Not yet.' I had to cut it on a very small stone. Optimism doesn't sell.", "Runhild: 'Noch nicht.' Ich musste es auf einen sehr kleinen Stein meißeln. Zuversicht verkauft sich nicht.")}},
    {"id": "debtors_icehouse", "road": "rimeglass_pass", "name": ("Debtors' Icehouse", "Schuldner-Eishaus"),
     "rows": ["WWWWWWWWWWWW",
              "WCCfffffCCCW",
              "WffffffffffW",
              "WCCfCCfCCfCW",
              "WSffffffffSW",
              "WffffffffffW",
              "WCCfCCfCffCW",
              "WffffffffffW",
              "WffffffffffW",
              "WWWWWDWWWWWW"],
     "signs": [("Notice: 'Pledges are kept at four below. Complaints are kept next to them.'", "Aushang: 'Pfänder lagern bei vier Grad unter null. Beschwerden lagern daneben.'"),
               ("Rows of ice blocks, each with a tag. Some of the tags are waving. No. That is the draught.", "Reihen von Eisblöcken, jeder mit einem Zettel. Manche Zettel winken. Nein. Das ist der Luftzug.")],
     "finds": ["strong_tonic", "cooling_gel"],
     "duel": {"title": ("Icehouse Bailiff Stig", "Eishausbüttel Stig"), "sprite": "villager", "reward": ("strong_tonic", 3),
              "talk": [("Stig: Everything in here is pawned. Boots, fathers, a brass band.", "Stig: Alles hier drin ist verpfändet. Stiefel, Väter, eine Blaskapelle."),
                       ("Stig: Beat me and pick one thing from the unclaimed shelf.", "Stig: Schlag mich, und du suchst dir etwas vom Regal der nicht Abgeholten aus.")],
              "yes": ("Duel for the shelf", "Duell um das Regal"), "no": ("Touch nothing", "Fass nichts an"),
              "fight": ("Stig: Mind the floor. That is also somebody.", "Stig: Pass auf den Boden auf. Das ist auch jemand."),
              "later": ("Stig: Wise. Half of them in here touched something.", "Stig: Klug. Die Hälfte hier drin hat etwas angefasst."),
              "defeat": ("Stig: Unclaimed shelf, left side. Not the tuba. The tuba is reserved.", "Stig: Regal der nicht Abgeholten, linke Seite. Nicht die Tuba. Die Tuba ist vergeben."),
              "lose": ("Stig: Row five has space. Just saying.", "Stig: In Reihe fünf ist Platz. Ich sag ja nur."),
              "pay": [("Stig: You picked the crate of tonics. Everyone does. One day somebody takes the tuba and I can sleep.", "Stig: Du hast die Kiste mit den Tonika genommen. Das machen alle. Eines Tages nimmt jemand die Tuba, und ich kann schlafen.")],
              "done": ("Stig: The tuba plays at night. Nobody is in it. I have looked.", "Stig: Die Tuba spielt nachts. Es steckt keiner drin. Ich habe nachgesehen.")}},
]
HALL_NAME = {h["id"]: h["name"][0] for h in HALLS}

# (map, x, y, facing, ...). Every cell is checked by free() against the rows and what stands there.
GOALS = [
    {"id": "widow_post", "turns": True, "road": "drypoint_lane", "reward": ("max_tonic", 3),
     "giver": ("burin_landing", 9, 16, "left", "elder", "maren"),
     "intro": [("Widow Maren: My Jost drowned three winters ago. He still writes every week. The handwriting is getting better.", "Witwe Maren: Mein Jost ist vor drei Wintern ertrunken. Er schreibt noch jede Woche. Die Handschrift wird immer besser."),
               ("Widow Maren: Find out who sends the letters. I'd like to thank them. Or bury them. I haven't decided.", "Witwe Maren: Finde heraus, wer die Briefe schickt. Ich möchte mich bedanken. Oder ihn begraben. Ich habe mich noch nicht entschieden.")],
     "wait": ("Widow Maren: Unclaimed mail goes to the Dead Letter Office on Drypoint Lane. Start there.", "Witwe Maren: Nicht abgeholte Post geht ins Amt für tote Briefe an der Drypoint Lane. Fang dort an."),
     "reveal": [("Widow Maren: So you read the order book. Yes. I write them myself. A widow with weekly letters gets visitors. And a pension.", "Witwe Maren: Du hast also das Auftragsbuch gelesen. Ja. Ich schreibe sie selbst. Eine Witwe mit wöchentlichen Briefen bekommt Besuch. Und eine Rente."),
                ("Widow Maren: Jost left on the mail boat with the baker's wife. The Guild pays for drowned husbands. It does not pay for stupid ones.", "Witwe Maren: Jost ist mit der Bäckersfrau auf dem Postschiff davon. Die Gilde zahlt für ertrunkene Ehemänner. Für dumme zahlt sie nicht."),
                ("Widow Maren: Nobody else knows. I'd like to keep it that way. You may write to me afterwards.", "Witwe Maren: Sonst weiß es keiner. Das soll so bleiben. Du darfst mir danach gern schreiben.")],
     "steps": [("dead_letter_office", 2, 5, "right", "villager", "edda",
                [("Sorter Edda: Letters from the drowned? Those aren't dead letters. Those are a subscription.", "Sortiererin Edda: Briefe von Ertrunkenen? Das sind keine toten Briefe. Das ist ein Abonnement."),
                 ("Sorter Edda: One a week, paid a year ahead. The Customs Shed in Burin Landing keeps the order book.", "Sortiererin Edda: Einer pro Woche, ein Jahr im Voraus bezahlt. Das Auftragsbuch liegt im Zollschuppen in Burin Landing.")],
                ("Sorter Edda: We file love letters under 'fiction'. It saves time.", "Sortiererin Edda: Liebesbriefe legen wir unter 'Erfundenes' ab. Das spart Zeit.")),
               ("burin_landing_customs", 6, 2, "down", "villager", "timo",
                [("Order Boy Timo: Weekly letter, 'from Jost, with longing'. Ordered by Maren. Paid by Maren. Dictated by Maren.", "Auftragsjunge Timo: Wöchentlicher Brief, 'von Jost, in Sehnsucht'. Bestellt von Maren. Bezahlt von Maren. Diktiert von Maren."),
                 ("Order Boy Timo: Jost isn't on the drowned list either. He's on the passenger list. One way.", "Auftragsjunge Timo: Jost steht auch nicht auf der Liste der Ertrunkenen. Er steht auf der Passagierliste. Einfache Fahrt.")],
                ("Order Boy Timo: I'm not supposed to read the order book. I'm not supposed to do most of what I do.", "Auftragsjunge Timo: Ich soll das Auftragsbuch nicht lesen. Das meiste, was ich tue, soll ich nicht tun."))],
     "betrayer": ("burin_landing", 3, 6, "right", "elder", "maren_ink", ("Widow Maren", "Witwe Maren"),
                  [("Widow Maren: Dearest stranger. It is with great sorrow that I write of your accident.", "Witwe Maren: Liebste Fremde. Mit großer Trauer schreibe ich von deinem Unfall.")],
                  [("Widow Maren: Oh, put it in a letter.", "Witwe Maren: Ach, schreib es in einen Brief."),
                   ("Widow Maren: Take the pension purse. I'll say Jost needed it. He is very generous, for a dead man.", "Witwe Maren: Nimm den Rentenbeutel. Ich sage, Jost hat ihn gebraucht. Er ist sehr großzügig, für einen Toten.")],
                  [("You take Maren's purse. Inside: three tonics and a finished letter of condolence, with your name already filled in.", "Du nimmst Marens Beutel. Darin: drei Tonika und ein fertiger Beileidsbrief, dein Name ist schon eingetragen.")],
                  ("Widow Maren: Jost wrote again this morning. He misses me terribly. I was quite moved.", "Witwe Maren: Jost hat heute Morgen wieder geschrieben. Er vermisst mich furchtbar. Ich war richtig gerührt.")),
     "stages": [(("Widow Maren's drowned husband still writes every week. Find out who sends the letters.", "Der ertrunkene Mann von Witwe Maren schreibt noch jede Woche. Finde heraus, wer die Briefe schickt."), "Dead Letter Office"),
                (("The letters are ordered a year ahead. Check the order book in the Customs Shed.", "Die Briefe sind ein Jahr im Voraus bestellt. Sieh im Auftragsbuch im Zollschuppen nach."), "Burin Landing"),
                (("Maren ordered the letters herself. Ask her why.", "Maren hat die Briefe selbst bestellt. Frag sie, warum."), "Burin Landing"),
                (("Maren has already written your letter of condolence. Stop her.", "Maren hat deinen Beileidsbrief schon geschrieben. Halt sie auf."), "Burin Landing"),
                (("Jost is alive, far away and writes weekly. In Maren's hand.", "Jost lebt, ist weit weg und schreibt jede Woche. In Marens Schrift."), "Burin Landing")]},

    {"id": "wanted_face", "turns": False, "road": "gravers_causeway", "reward": ("strong_tonic", 2),
     "giver": ("platewick", 9, 16, "left", "villager", "jorund"),
     "intro": [("Baker Jorund: That's my face on the wanted poster. 'Arson, fraud, loud singing.' I only did the singing.", "Bäcker Jorund: Das auf dem Steckbrief ist mein Gesicht. 'Brandstiftung, Betrug, lautes Singen.' Ich habe nur gesungen."),
               ("Baker Jorund: Somebody engraved me. Find the plate, and whoever cut it. I can't sell a bun without being arrested a little.", "Bäcker Jorund: Jemand hat mich gestochen. Finde die Platte und den, der sie geschnitten hat. Ich kann kein Brötchen verkaufen, ohne ein bisschen verhaftet zu werden.")],
     "wait": ("Baker Jorund: Every plate in town sleeps in the Plate Store. Ask who ordered mine.", "Bäcker Jorund: Jede Platte der Stadt schläft im Plattenlager. Frag, wer meine bestellt hat."),
     "reveal": [("Baker Jorund: My face is coming off the poster? Wonderful! And whose goes... oh. Oh, that's awkward.", "Bäcker Jorund: Mein Gesicht kommt vom Steckbrief runter? Herrlich! Und wessen kommt... oh. Oh, das ist unangenehm."),
                ("Baker Jorund: Listen. I ordered the poster myself. The reward is big, my wife turns me in, we share it. Then it got out of hand.", "Bäcker Jorund: Hör zu. Ich habe den Steckbrief selbst bestellt. Das Kopfgeld ist hoch, meine Frau liefert mich aus, wir teilen. Dann ist es mir entglitten."),
                ("Baker Jorund: Somebody has to be on it. The cutter is still on the Causeway. Stop him before your nose dries.", "Bäcker Jorund: Irgendwer muss drauf sein. Der Stecher ist noch auf dem Damm. Halt ihn auf, bevor deine Nase trocken ist.")],
     "go": ("Baker Jorund: The cutter works on the Gravers' Causeway. Hurry. He is fast with noses.", "Bäcker Jorund: Der Stecher arbeitet auf dem Graveursdamm. Beeil dich. Mit Nasen ist er schnell."),
     "reward_lines": [("Baker Jorund: You have the plate? Half me, half you. We're practically family.", "Bäcker Jorund: Du hast die Platte? Halb ich, halb du. Wir sind praktisch Familie."),
                      ("Baker Jorund: Give it to me. I'll melt it down, I swear on my oven. Or keep it, if you don't trust a baker.", "Bäcker Jorund: Gib sie mir. Ich schmelze sie ein, ich schwöre bei meinem Ofen. Oder behalt sie, wenn du einem Bäcker nicht traust.")],
     "choice": {"trust": (("Hand him the plate", "Gib ihm die Platte"), ("strong_tonic", 2),
                          [("Baker Jorund: Thank you! Here, tonics. And a bun. Don't eat the bun.", "Bäcker Jorund: Danke! Hier, Tonika. Und ein Brötchen. Iss das Brötchen nicht.")],
                          ("Baker Jorund: The plate? Melted. Mostly. The Guild paid well for the half with your face. Buns are on the house, forever.", "Bäcker Jorund: Die Platte? Eingeschmolzen. Größtenteils. Für die Hälfte mit deinem Gesicht hat die Gilde gut gezahlt. Brötchen gehen aufs Haus, für immer.")),
                "keep": (("Keep the plate", "Behalte die Platte"), ("max_tonic", 3),
                         [("Baker Jorund: You don't trust me. Clever. Then take these as hush money. Mine or yours, I've lost track.", "Bäcker Jorund: Du traust mir nicht. Klug. Dann nimm das als Schweigegeld. Meins oder deins, ich habe den Überblick verloren.")],
                         ("Baker Jorund: My wife turned me in anyway. For the singing. I'm out on bail, paid in bread.", "Bäcker Jorund: Meine Frau hat mich trotzdem ausgeliefert. Wegen des Singens. Ich bin auf Kaution frei, bezahlt in Brot.")),
                "witness": [("platewick", 4, 16, "right", "villager", "gry", "trusted",
                             [("Poster Reader Gry: New poster this morning. 'Wanted: a stranger. Arson, fraud, loud singing.'", "Steckbriefleserin Gry: Neuer Steckbrief heute Morgen. 'Gesucht: eine Fremde. Brandstiftung, Betrug, lautes Singen.'"),
                              ("Poster Reader Gry: The nose is very good. Do I know you from somewhere?", "Steckbriefleserin Gry: Die Nase ist sehr gut getroffen. Kenne ich dich irgendwoher?")]),
                            ("platewick", 5, 16, "right", "villager", "gry_bread", "kept",
                             [("Poster Reader Gry: The baker's poster is still up. Somebody drew a moustache on it. It helps.", "Steckbriefleserin Gry: Der Steckbrief vom Bäcker hängt noch. Jemand hat ihm einen Schnurrbart gemalt. Es hilft.")])]},
     "after": None,
     "steps": [("platewick_plate_store", 6, 2, "down", "villager", "kalle",
                [("Drawer Boy Kalle: Jorund's plate? Drawer nine hundred and four. It's out on loan, to the cutter on the Gravers' Causeway.", "Schubladenjunge Kalle: Jorunds Platte? Schublade neunhundertvier. Sie ist ausgeliehen, an den Stecher auf dem Graveursdamm."),
                 ("Drawer Boy Kalle: Funny order. Paid in bread.", "Schubladenjunge Kalle: Komischer Auftrag. In Brot bezahlt.")],
                ("Drawer Boy Kalle: Your drawer is still empty. I check every morning. It's exciting.", "Schubladenjunge Kalle: Deine Schublade ist noch leer. Ich sehe jeden Morgen nach. Es ist aufregend.")),
               ("gravers_causeway", 10, 3, "left", "ranger", "mette",
                [("Plate Runner Mette: The baker's plate? I carried it out myself. The cutter is changing the face. Nose first.", "Plattenläuferin Mette: Die Platte vom Bäcker? Die habe ich selbst rausgetragen. Der Stecher ändert das Gesicht. Die Nase zuerst."),
                 ("Plate Runner Mette: Same crimes, new head. I saw the sketch. Nice likeness of you, by the way.", "Plattenläuferin Mette: Gleiche Verbrechen, neuer Kopf. Ich habe die Skizze gesehen. Übrigens gut getroffen, du.")],
                ("Plate Runner Mette: I never look at the plates I carry. Except always.", "Plattenläuferin Mette: Ich sehe mir die Platten nie an, die ich trage. Außer immer."))],
     "betrayer": ("gravers_causeway", 7, 21, "left", "villager", "sture", ("Bounty Cutter Sture", "Kopfgeldstecher Sture"),
                  [("Sture: Hold that expression. Guilty. Perfect.", "Sture: Halt den Ausdruck. Schuldig. Perfekt.")],
                  [("Sture: Fine, take the plate. It's half you, half baker. Hang it up and see who they arrest.", "Sture: Schön, nimm die Platte. Halb du, halb Bäcker. Häng sie auf und sieh, wen sie verhaften."),
                   ("Sture: The baker paid me twice, you know. Once to cut him. Once to cut you.", "Sture: Der Bäcker hat mich zweimal bezahlt, weißt du. Einmal, um ihn zu stechen. Einmal, um dich zu stechen.")],
                  None,
                  ("Sture: No hard feelings. I do hard lines, not feelings.", "Sture: Nichts für ungut. Ich mache harte Linien, keine Gefühle.")),
     "stages": [(("Baker Jorund's face is on a wanted poster. Find the plate and who cut it.", "Das Gesicht von Bäcker Jorund ist auf einem Steckbrief. Finde die Platte und den, der sie geschnitten hat."), "Platewick"),
                (("The plate is out on loan to a cutter on the Gravers' Causeway. Ask the plate runner.", "Die Platte ist an einen Stecher auf dem Graveursdamm ausgeliehen. Frag die Plattenläuferin."), "Gravers' Causeway"),
                (("The cutter is changing the face on the plate to yours. Tell Jorund.", "Der Stecher ändert das Gesicht auf der Platte in deins. Sag es Jorund."), "Platewick"),
                (("Beat the bounty cutter on the Gravers' Causeway, then take the plate to Jorund.", "Schlag den Kopfgeldstecher auf dem Graveursdamm und bring die Platte zu Jorund."), "Gravers' Causeway"),
                (("The plate was half you, half baker. Somebody will hang for the singing.", "Die Platte war halb du, halb Bäcker. Irgendwer wird für das Singen hängen."), "Platewick")]},

    {"id": "cure_proof", "turns": True, "road": "mordant_steps", "reward": ("strong_tonic", 3),
     "giver": ("mordant_row", 9, 16, "left", "villager", "ida"),
     "intro": [("Bottle Washer Ida: Everyone who takes Mavet's cure comes back for more. Sicker. I wash the bottles. I've started counting.", "Flaschenspülerin Ida: Jeder, der Mavets Heilmittel nimmt, kommt wieder und will mehr. Kränker. Ich spüle die Flaschen. Ich habe angefangen zu zählen."),
               ("Bottle Washer Ida: Find out what goes into the cure. Quietly. I'd ask myself, but I like my eyebrows.", "Flaschenspülerin Ida: Finde heraus, was in dem Heilmittel ist. Leise. Ich würde selbst fragen, aber ich mag meine Augenbrauen.")],
     "wait": ("Bottle Washer Ida: The fillers on the Mordant Steps bottle it. Then ask in the Well House what they bottle.", "Flaschenspülerin Ida: Die Abfüller auf den Mordant-Stufen füllen es ab. Dann frag im Brunnenhaus, was sie da abfüllen."),
     "reveal": [("Bottle Washer Ida: Pipe forty-one. Bath to well to bottle. That's the whole recipe? That's all of it?", "Flaschenspülerin Ida: Rohr einundvierzig. Vom Bad in den Brunnen in die Flasche. Das ist das ganze Rezept? Mehr nicht?"),
                ("Bottle Washer Ida: Good. I've rented a cellar and bought two hundred bottles. Ida's Cure, half the price, same pipe.", "Flaschenspülerin Ida: Gut. Ich habe einen Keller gemietet und zweihundert Flaschen gekauft. Idas Heilmittel, halber Preis, gleiches Rohr."),
                ("Bottle Washer Ida: Only one person knows the recipe besides me and Mavet. And Mavet is a Warden.", "Flaschenspülerin Ida: Außer mir und Mavet kennt nur eine Person das Rezept. Und Mavet ist eine Wächterin.")],
     "steps": [("mordant_steps", 10, 3, "left", "villager", "aki",
                [("Filler Boy Aki: The cure? Three parts bath water, one part well water, one part label. The label is the expensive part.", "Abfülljunge Aki: Das Heilmittel? Drei Teile Badewasser, ein Teil Brunnenwasser, ein Teil Etikett. Das Etikett ist das Teure."),
                 ("Filler Boy Aki: The well water comes from the Well House. They say don't drink it. So we sell it.", "Abfülljunge Aki: Das Brunnenwasser kommt aus dem Brunnenhaus. Sie sagen, man soll es nicht trinken. Also verkaufen wir es.")],
                ("Filler Boy Aki: I drink beer. Nobody has cured beer yet.", "Abfülljunge Aki: Ich trinke Bier. Bier hat noch keiner geheilt.")),
               ("mordant_row_well_house", 6, 2, "down", "villager", "vera",
                [("Pipe Fitter Vera: This pipe runs from the big bath into the town well. I fitted it. Mavet drew the plan and paid in cure.", "Rohrlegerin Vera: Dieses Rohr läuft vom großen Bad in den Stadtbrunnen. Ich habe es verlegt. Mavet hat den Plan gezeichnet und in Heilmittel bezahlt."),
                 ("Pipe Fitter Vera: The well makes them ill, and the cure is the well. Write the pipe number down if you want proof. Forty-one.", "Rohrlegerin Vera: Der Brunnen macht sie krank, und das Heilmittel ist der Brunnen. Schreib dir die Rohrnummer auf, wenn du einen Beweis willst. Einundvierzig.")],
                ("Pipe Fitter Vera: I bring my own water. From Rimeholt. In a locked flask.", "Rohrlegerin Vera: Ich bringe mein eigenes Wasser mit. Aus Rimeholt. In einer abgeschlossenen Flasche."))],
     "betrayer": ("mordant_row", 3, 6, "right", "villager", "ida_cure", ("Bottle Washer Ida", "Flaschenspülerin Ida"),
                  [("Ida: Open wide. The first dose is free. So is the last.", "Ida: Mund auf. Die erste Dosis ist gratis. Die letzte auch.")],
                  [("Ida: Spilled. Two hundred bottles of it.", "Ida: Verschüttet. Zweihundert Flaschen davon."),
                   ("Ida: Take the tonics. They are real ones. I keep them for myself, which tells you everything.", "Ida: Nimm die Tonika. Die sind echt. Ich hebe sie für mich selbst auf, das sagt dir alles.")],
                  [("You take Ida's crate. Inside: three real tonics and two hundred labels reading 'Ida's Cure. Now with less Mavet.'", "Du nimmst Idas Kiste. Darin: drei echte Tonika und zweihundert Etiketten mit 'Idas Heilmittel. Jetzt mit weniger Mavet.'")],
                  ("Ida: I wash bottles again. Mavet raised my pay. She said she admires initiative, and moved the pipe.", "Ida: Ich spüle wieder Flaschen. Mavet hat meinen Lohn erhöht. Sie sagt, sie bewundert Eigeninitiative, und hat das Rohr verlegt.")),
     "stages": [(("Mavet's cure makes people sicker. Find out what goes into it.", "Mavets Heilmittel macht die Leute kränker. Finde heraus, was drin ist."), "Mordant Steps"),
                (("The cure is mostly well water. Ask in the Well House in Mordant Row.", "Das Heilmittel ist größtenteils Brunnenwasser. Frag im Brunnenhaus in Mordant Row."), "Mordant Row"),
                (("A pipe feeds the bath into the well. Tell Ida.", "Ein Rohr leitet das Bad in den Brunnen. Sag es Ida."), "Mordant Row"),
                (("Ida wants the recipe for herself and one witness fewer. Stop her.", "Ida will das Rezept für sich und einen Zeugen weniger. Halt sie auf."), "Mordant Row"),
                (("The pipe was moved. The cure still sells.", "Das Rohr wurde verlegt. Das Heilmittel verkauft sich weiter."), "Mordant Row")]},

    {"id": "frozen_deed", "turns": False, "road": "rimeglass_pass", "reward": ("revival_leaf", 3),
     "giver": ("rimeholt", 9, 16, "left", "villager", "kari"),
     "intro": [("Debtor's Daughter Kari: The Guild froze our house for a debt my father paid. He went to fetch the receipt and never came back.", "Schuldnerstochter Kari: Die Gilde hat unser Haus eingefroren, wegen einer Schuld, die mein Vater bezahlt hat. Er wollte die Quittung holen und kam nie zurück."),
               ("Debtor's Daughter Kari: Find the receipt. With it the house thaws. Without it I sleep in the Hearth Hall, in the far row.", "Schuldnerstochter Kari: Finde die Quittung. Mit ihr taut das Haus auf. Ohne sie schlafe ich in der Herdhalle, in der hintersten Reihe.")],
     "wait": ("Debtor's Daughter Kari: He took the sledge road over the Hoarfrost Moor. Ask the people who work it.", "Schuldnerstochter Kari: Er nahm den Schlittenweg über das Hoarfrost-Moor. Frag die Leute, die dort arbeiten."),
     "reveal": [("Debtor's Daughter Kari: You saw him? Then you know. I pawned my father. He was the only thing in the house the Guild would take.", "Schuldnerstochter Kari: Du hast ihn gesehen? Dann weißt du es. Ich habe meinen Vater verpfändet. Er war das Einzige im Haus, das die Gilde nehmen wollte."),
                ("Debtor's Daughter Kari: The receipt in his hand clears the debt. I need the receipt out and him... I hadn't planned that far.", "Schuldnerstochter Kari: Die Quittung in seiner Hand tilgt die Schuld. Ich brauche die Quittung heraus und ihn... so weit hatte ich nicht geplant."),
                ("Debtor's Daughter Kari: The Guild's bailiff is on his way to break the block and burn the paper. Stop him on the pass. Please.", "Schuldnerstochter Kari: Der Büttel der Gilde ist unterwegs, um den Block zu zerschlagen und das Papier zu verbrennen. Halt ihn am Pass auf. Bitte.")],
     "go": ("Debtor's Daughter Kari: The bailiff is on Rimeglass Pass. He carries a hammer and a candle. Go.", "Schuldnerstochter Kari: Der Büttel ist am Rimeglass-Pass. Er hat einen Hammer und eine Kerze dabei. Geh."),
     "reward_lines": [("Debtor's Daughter Kari: The block is safe? Then there are two ways to do this.", "Schuldnerstochter Kari: Der Block ist sicher? Dann gibt es zwei Wege."),
                      ("Debtor's Daughter Kari: Leave him to me. I'll have the receipt cut out neatly and thaw him in spring. Or pay the thaw stamp yourself, now, and he walks home with it.", "Schuldnerstochter Kari: Überlass ihn mir. Ich lasse die Quittung sauber herausschneiden und taue ihn im Frühling auf. Oder du zahlst den Taustempel selbst, jetzt, und er geht damit nach Hause.")],
     "choice": {"trust": (("Leave it to Kari", "Überlass es Kari"), ("revival_leaf", 3),
                          [("Debtor's Daughter Kari: Thank you. Spring. I promise. Springs are short here, but I promise.", "Schuldnerstochter Kari: Danke. Im Frühling. Versprochen. Der Frühling ist hier kurz, aber versprochen.")],
                          ("Debtor's Daughter Kari: The house is thawed. Father is still in row four. Spring is late this year. It was late last year too.", "Schuldnerstochter Kari: Das Haus ist aufgetaut. Vater steht noch in Reihe vier. Der Frühling kommt dieses Jahr spät. Letztes Jahr kam er auch spät.")),
                "keep": (("Thaw him now", "Tau ihn jetzt auf"), ("revival_leaf", 1),
                         [("Debtor's Daughter Kari: You paid the stamp? Oh. Then he'll be home tonight. I had better hide the pawn ticket.", "Schuldnerstochter Kari: Du hast den Stempel bezahlt? Oh. Dann ist er heute Abend zu Hause. Ich verstecke besser den Pfandschein.")],
                         ("Debtor's Daughter Kari: Father is home. He keeps the receipt in one hand and the pawn ticket in the other. We don't talk much.", "Schuldnerstochter Kari: Vater ist zu Hause. In einer Hand hält er die Quittung, in der anderen den Pfandschein. Wir reden nicht viel.")),
                "witness": [("rimeholt", 4, 16, "right", "elder", "halfdan", "kept",
                             [("Old Halfdan: Cold? No. I was cold for a year. Now I'm only disappointed.", "Alter Halfdan: Kalt? Nein. Kalt war mir ein Jahr lang. Jetzt bin ich nur enttäuscht."),
                              ("Old Halfdan: She pawned me for the house. I'd have done the same to her mother. Still.", "Alter Halfdan: Sie hat mich für das Haus verpfändet. Ich hätte dasselbe mit ihrer Mutter gemacht. Trotzdem.")]),
                            ("debtors_icehouse", 9, 7, "left", "villager", "tagger", "trusted",
                             [("Tag Writer Inga: Row four, block nine? Renewed for another year this morning. By the daughter. She paid in firewood.", "Zettelschreiberin Inga: Reihe vier, Block neun? Heute Morgen um ein Jahr verlängert. Von der Tochter. Bezahlt in Brennholz.")])]},
     "after": None,
     "steps": [("hoarfrost_moor", 10, 3, "left", "villager", "odd",
                [("Sledge Boy Odd: The old man with the receipt? I drove him. Not to the Debt Office. To the Debtors' Icehouse, up on Rimeglass Pass.", "Schlittenjunge Odd: Der alte Mann mit der Quittung? Den habe ich gefahren. Nicht zum Schuldenamt. Zum Schuldner-Eishaus, oben am Rimeglass-Pass."),
                 ("Sledge Boy Odd: His daughter paid the fare. One way.", "Schlittenjunge Odd: Seine Tochter hat die Fahrt bezahlt. Einfache Strecke.")],
                ("Sledge Boy Odd: I don't ask where people go. I ask if they need the sledge back.", "Schlittenjunge Odd: Ich frage nicht, wohin die Leute wollen. Ich frage, ob sie den Schlitten zurück brauchen.")),
               ("debtors_icehouse", 2, 5, "right", "elder", "torsten",
                [("Ice Keeper Torsten: Row four, block nine. An old man, standing, holding a receipt. Very good condition.", "Eiswart Torsten: Reihe vier, Block neun. Ein alter Mann, stehend, mit einer Quittung in der Hand. Sehr guter Zustand."),
                 ("Ice Keeper Torsten: Pledged by his daughter against the house debt. The receipt is real. It's just inside the ice, with him.", "Eiswart Torsten: Von seiner Tochter verpfändet, gegen die Hausschuld. Die Quittung ist echt. Sie steckt nur im Eis, mit ihm.")],
                ("Ice Keeper Torsten: We don't thaw without a stamp. We don't stamp without a fee. It keeps things calm.", "Eiswart Torsten: Ohne Stempel tauen wir nicht auf. Ohne Gebühr stempeln wir nicht. Das hält alles ruhig."))],
     "betrayer": ("rimeglass_pass", 7, 21, "left", "villager", "ragnvald", ("Thaw Bailiff Ragnvald", "Taubüttel Ragnvald"),
                  [("Ragnvald: Receipts melt. People melt. The debt stays. Step aside.", "Ragnvald: Quittungen schmelzen. Menschen schmelzen. Die Schuld bleibt. Geh zur Seite.")],
                  [("Ragnvald: Keep the block, then. He holds the paper so hard we'd have to break the fingers anyway.", "Ragnvald: Dann behalt den Block. Er hält das Papier so fest, wir müssten ohnehin die Finger brechen."),
                   ("Ragnvald: The daughter told us you were coming, by the way. She wanted someone to blame if the ice cracked.", "Ragnvald: Die Tochter hat uns übrigens gesagt, dass du kommst. Sie wollte jemanden, der schuld ist, falls das Eis reißt.")],
                  None,
                  ("Ragnvald: I only collect. The cold does the rest.", "Ragnvald: Ich treibe nur ein. Den Rest macht die Kälte.")),
     "stages": [(("The Guild froze Kari's house over a paid debt. Find her father's receipt.", "Die Gilde hat Karis Haus wegen einer bezahlten Schuld eingefroren. Finde die Quittung ihres Vaters."), "Hoarfrost Moor"),
                (("Kari's father was driven to the Debtors' Icehouse on Rimeglass Pass. Look for him there.", "Karis Vater wurde zum Schuldner-Eishaus am Rimeglass-Pass gefahren. Such ihn dort."), "Debtors' Icehouse"),
                (("Kari pawned her father, receipt in hand. Ask her why.", "Kari hat ihren Vater verpfändet, mit der Quittung in der Hand. Frag sie, warum."), "Rimeholt"),
                (("Beat the Guild's bailiff on Rimeglass Pass before he breaks the block, then see Kari.", "Schlag den Büttel der Gilde am Rimeglass-Pass, bevor er den Block zerschlägt, und geh dann zu Kari."), "Rimeglass Pass"),
                (("The receipt cleared the debt. What it cost stays in the family.", "Die Quittung hat die Schuld getilgt. Was sie gekostet hat, bleibt in der Familie."), "Rimeholt")]},

    {"id": "short_till", "turns": True, "road": "stamp_road", "reward": ("max_tonic", 3),
     "giver": ("ledgerholm", 9, 16, "left", "villager", "nils"),
     "intro": [("Teller Nils: My till is one coin short every night. One. If the count is wrong a third time, the bank hangs the teller. It's in the rules, under 'staff benefits'.", "Kassierer Nils: In meiner Kasse fehlt jede Nacht eine Münze. Eine. Stimmt die Zählung ein drittes Mal nicht, hängt die Bank den Kassierer. Steht in den Regeln, unter 'Leistungen für Mitarbeiter'."),
               ("Teller Nils: Find the thief. Ask loudly. I want people to see someone asking.", "Kassierer Nils: Finde den Dieb. Frag laut. Die Leute sollen sehen, dass jemand fragt.")],
     "wait": ("Teller Nils: The choir practises above the bank and sees the counter. Ask in the Choir Loft.", "Kassierer Nils: Der Chor probt über der Bank und sieht den Schalter. Frag auf der Chorempore."),
     "reveal": [("Teller Nils: You asked the choir. You asked the carter. Everyone saw you asking. Excellent.", "Kassierer Nils: Du hast den Chor gefragt. Du hast die Fuhrfrau gefragt. Alle haben dich fragen sehen. Ausgezeichnet."),
                ("Teller Nils: Tonight's ledger reads: 'Shortfall explained. Stranger observed at till on three occasions.' I wrote it this morning.", "Kassierer Nils: Im Buch von heute Abend steht: 'Fehlbetrag geklärt. Fremde dreimal an der Kasse beobachtet.' Ich habe es heute Morgen geschrieben."),
                ("Teller Nils: Two ledgers, one thief, and it isn't the one who can do sums. The guards come at six. I'd rather settle before.", "Kassierer Nils: Zwei Bücher, ein Dieb, und es ist nicht der, der rechnen kann. Die Wachen kommen um sechs. Ich rechne lieber vorher ab.")],
     "steps": [("ledgerholm_choir_loft", 6, 2, "down", "villager", "jens",
                [("Choir Boy Jens: I sing treble and watch the tills. Nobody goes near Nils's till. Only Nils. And lately you.", "Chorknabe Jens: Ich singe Sopran und beobachte die Kassen. An Nils' Kasse geht keiner. Nur Nils. Und neuerdings du."),
                 ("Choir Boy Jens: The missing coins turn up in the carts on Stamp Road, restamped. Ask the carter.", "Chorknabe Jens: Die fehlenden Münzen tauchen in den Karren auf der Stempelstraße auf, neu geprägt. Frag die Fuhrfrau.")],
                ("Choir Boy Jens: Bankers sing flat. They say the note is correct and the choir is in arrears.", "Chorknabe Jens: Bankiers singen zu tief. Sie sagen, der Ton stimmt und der Chor ist im Rückstand.")),
               ("stamp_road", 10, 3, "left", "ranger", "brynja",
                [("Coin Carter Brynja: One coin a night, yes. Teller Nils brings it himself. I restamp it lighter and send it back as two.", "Münzfuhrfrau Brynja: Eine Münze pro Nacht, ja. Kassierer Nils bringt sie selbst. Ich präge sie leichter und schicke sie als zwei zurück."),
                 ("Coin Carter Brynja: Last week he asked me to remember a stranger instead. Asking questions, near the till. He described you rather well.", "Münzfuhrfrau Brynja: Letzte Woche bat er mich, mich stattdessen an eine Fremde zu erinnern. Stellt Fragen, nah an der Kasse. Er hat dich recht gut beschrieben.")],
                ("Coin Carter Brynja: Money doesn't disappear. It just changes whose fault it is.", "Münzfuhrfrau Brynja: Geld verschwindet nicht. Es wechselt nur, wer schuld ist."))],
     "betrayer": ("ledgerholm", 3, 6, "right", "villager", "nils_till", ("Teller Nils", "Kassierer Nils"),
                  [("Nils: Hold still. I need you found near the till, and you look heavy to drag.", "Nils: Halt still. Man muss dich bei der Kasse finden, und du siehst schwer zu schleppen aus.")],
                  [("Nils: That doesn't add up. I checked it twice.", "Nils: Das geht nicht auf. Ich habe zweimal nachgerechnet."),
                   ("Nils: Take the coins. All the light ones. Tell the bank they were always like that.", "Nils: Nimm die Münzen. Alle leichten. Sag der Bank, die waren schon immer so.")],
                  [("You take Nils's till bag. Inside: three tonics, forty light coins and a ledger page with your description. The height is flattering.", "Du nimmst Nils' Kassenbeutel. Darin: drei Tonika, vierzig leichte Münzen und eine Buchseite mit deiner Beschreibung. Die Größe ist geschmeichelt.")],
                  ("Nils: I was promoted. The bank said a man who can frame a stranger can run the loans desk.", "Nils: Ich wurde befördert. Die Bank sagt, wer einer Fremden etwas anhängen kann, kann auch den Kreditschalter führen.")),
     "stages": [(("Teller Nils's till is one coin short every night. Find the thief.", "In der Kasse von Kassierer Nils fehlt jede Nacht eine Münze. Finde den Dieb."), "Ledgerholm"),
                (("The missing coins turn up restamped on Stamp Road. Ask the coin carter.", "Die fehlenden Münzen tauchen neu geprägt auf der Stempelstraße auf. Frag die Münzfuhrfrau."), "Stamp Road"),
                (("Nils takes the coin himself, and the carter was told to remember you. Confront Nils.", "Nils nimmt die Münze selbst, und die Fuhrfrau soll sich an dich erinnern. Stell Nils zur Rede."), "Ledgerholm"),
                (("Nils wrote you into the ledger as the thief. Settle it before six.", "Nils hat dich als Dieb ins Buch geschrieben. Rechne vor sechs mit ihm ab."), "Ledgerholm"),
                (("The till adds up. Nils runs the loans desk now.", "Die Kasse stimmt. Nils führt jetzt den Kreditschalter."), "Ledgerholm")]},

    {"id": "erased_village", "turns": False, "road": "smudge_marsh", "reward": ("max_tonic", 4),
     "giver": ("proofgate", 9, 16, "left", "villager", "ansa"),
     "intro": [("Map Apprentice Ansa: Hollow Em is gone from the new map. A whole village. Forty people who can't get a stamp because they aren't anywhere.", "Kartenlehrling Ansa: Hollow Em ist von der neuen Karte verschwunden. Ein ganzes Dorf. Vierzig Leute, die keinen Stempel kriegen, weil es sie nirgends gibt."),
               ("Map Apprentice Ansa: Find out who scraped it off the plate. And where it really lies. For the map. Only for the map.", "Kartenlehrling Ansa: Finde heraus, wer es von der Platte gekratzt hat. Und wo es wirklich liegt. Für die Karte. Nur für die Karte.")],
     "wait": ("Map Apprentice Ansa: The old plates lie in the Map Vault. Look at the scrape marks.", "Kartenlehrling Ansa: Die alten Platten liegen im Kartengewölbe. Sieh dir die Kratzspuren an."),
     "reveal": [("Map Apprentice Ansa: You found it? Wonderful. I mean, for the map.", "Kartenlehrling Ansa: Du hast es gefunden? Wunderbar. Ich meine, für die Karte."),
                ("Map Apprentice Ansa: Fine. I get a tenth of every back tax I find. Six years, forty people. That's a house. With a door.", "Kartenlehrling Ansa: Na gut. Ich kriege ein Zehntel von jeder Steuerschuld, die ich finde. Sechs Jahre, vierzig Leute. Das ist ein Haus. Mit Tür."),
                ("Map Apprentice Ansa: A tax rider is out on the marsh following your tracks. He takes a third if he finds it first. Stop him, then tell me where it is.", "Kartenlehrling Ansa: Ein Steuerreiter ist draußen im Sumpf und folgt deinen Spuren. Findet er es zuerst, nimmt er ein Drittel. Halt ihn auf, dann sag mir, wo es liegt.")],
     "go": ("Map Apprentice Ansa: The tax rider is on the Smudge Marsh. He follows your boot prints. Yours are the clean ones.", "Kartenlehrling Ansa: Der Steuerreiter ist im Smudge-Sumpf. Er folgt deinen Stiefelspuren. Deine sind die sauberen."),
     "reward_lines": [("Map Apprentice Ansa: The rider is gone? Then it's just us. Where is Hollow Em?", "Kartenlehrling Ansa: Der Reiter ist weg? Dann sind es nur wir. Wo liegt Hollow Em?"),
                      ("Map Apprentice Ansa: Tell me and you get your share. Or tell me something else, and I'll never know. Probably.", "Kartenlehrling Ansa: Sag es mir, und du kriegst deinen Anteil. Oder sag mir etwas anderes, und ich erfahre es nie. Wahrscheinlich.")],
     "choice": {"trust": (("Tell her the truth", "Sag ihr die Wahrheit"), ("max_tonic", 4),
                          [("Map Apprentice Ansa: Third dead alder, sunk cart. Thank you. Here is your share. Don't look at it like that, it's legal.", "Kartenlehrling Ansa: Dritte tote Erle, versunkener Karren. Danke. Hier ist dein Anteil. Schau ihn nicht so an, er ist legal.")],
                          ("Map Apprentice Ansa: Hollow Em is back on the map. In red. I have a house now. The door sticks.", "Kartenlehrling Ansa: Hollow Em ist wieder auf der Karte. In Rot. Ich habe jetzt ein Haus. Die Tür klemmt.")),
                "keep": (("Send her the wrong way", "Schick sie in die falsche Richtung"), ("strong_tonic", 2),
                         [("Map Apprentice Ansa: Past the mill, left at the gallows? Odd. Fine. Here, an advance. If it's wrong, I want it back with interest.", "Kartenlehrling Ansa: An der Mühle vorbei, am Galgen links? Seltsam. Na gut. Hier, ein Vorschuss. Wenn es falsch ist, will ich ihn mit Zinsen zurück.")],
                         ("Map Apprentice Ansa: Six weeks in the marsh and no village. I found three boots and a tax rider. I'm still looking. I count things.", "Kartenlehrling Ansa: Sechs Wochen im Sumpf und kein Dorf. Ich habe drei Stiefel und einen Steuerreiter gefunden. Ich suche weiter. Ich zähle Dinge.")),
                "witness": [("smudge_marsh", 2, 17, "right", "villager", "ulf", "kept",
                             [("Eel Fisher's Boy Ulf: Gran says thank you, and that you were never here. Have an eel.", "Aalfischerjunge Ulf: Oma sagt danke, und dass du nie hier warst. Nimm einen Aal.")]),
                            ("smudge_marsh", 4, 9, "right", "elder", "hakon", "trusted",
                             [("Evicted Eeler Hakon: Six years of back tax. They took the boats, the nets and the eels. They left us the map.", "Vertriebener Aalfischer Hakon: Sechs Jahre Steuerschuld. Sie haben die Boote genommen, die Netze und die Aale. Die Karte haben sie uns gelassen."),
                              ("Evicted Eeler Hakon: We're on it in red. Somebody told. I hope they got a good price.", "Vertriebener Aalfischer Hakon: Wir stehen in Rot darauf. Jemand hat geredet. Ich hoffe, der Preis war gut.")])]},
     "after": None,
     "steps": [("proofgate_map_vault", 6, 2, "down", "villager", "sten",
                [("Vault Boy Sten: Hollow Em? Scraped off by order. Here's the slip: 'At the request of the village. Paid in eels.'", "Gewölbejunge Sten: Hollow Em? Auf Anordnung abgekratzt. Hier ist der Zettel: 'Auf Wunsch des Dorfes. Bezahlt in Aalen.'"),
                 ("Vault Boy Sten: They asked to vanish. One of them still fishes on the Smudge Marsh. Follow the smell.", "Gewölbejunge Sten: Sie wollten verschwinden. Eine von ihnen fischt noch im Smudge-Sumpf. Folg dem Geruch.")],
                ("Vault Boy Sten: I scraped my school off once. It was still there on Monday.", "Gewölbejunge Sten: Ich habe mal meine Schule abgekratzt. Am Montag war sie noch da.")),
               ("smudge_marsh", 10, 3, "left", "elder", "gudrun",
                [("Eel Fisher Gudrun: Hush. Yes, I'm from Hollow Em. No map, no tax. We haven't paid in six years. Best six years we ever had.", "Aalfischerin Gudrun: Pst. Ja, ich bin aus Hollow Em. Keine Karte, keine Steuer. Wir haben seit sechs Jahren nichts gezahlt. Die besten sechs Jahre, die wir je hatten."),
                 ("Eel Fisher Gudrun: It lies behind the third dead alder, past the sunk cart. Don't tell the girl from Proofgate. She counts things.", "Aalfischerin Gudrun: Es liegt hinter der dritten toten Erle, am versunkenen Karren vorbei. Sag es nicht dem Mädchen aus Proofgate. Die zählt Dinge.")],
                ("Eel Fisher Gudrun: If anyone asks, I'm a rumour.", "Aalfischerin Gudrun: Wenn jemand fragt, bin ich ein Gerücht."))],
     "betrayer": ("smudge_marsh", 7, 21, "left", "ranger", "folke", ("Tax Rider Folke", "Steuerreiter Folke"),
                  [("Folke: You walk like someone who knows where forty taxpayers are hiding.", "Folke: Du gehst wie jemand, der weiß, wo sich vierzig Steuerzahler verstecken.")],
                  [("Folke: All right. I found nothing. I'll put it on the form: 'nothing, with violence'.", "Folke: Schon gut. Ich habe nichts gefunden. Ich trage es ins Formular ein: 'nichts, mit Gewalt'."),
                   ("Folke: The apprentice sold me your route for a fifth. She sells everything by the fraction.", "Folke: Der Lehrling hat mir deine Route für ein Fünftel verkauft. Die verkauft alles in Bruchteilen.")],
                  None,
                  ("Folke: Marsh, mud, eels. I'm putting in for the desk job.", "Folke: Sumpf, Schlamm, Aale. Ich bewerbe mich auf den Schreibtischposten.")),
     "stages": [(("The village Hollow Em has vanished from the new map. Find out who scraped it off.", "Das Dorf Hollow Em ist von der neuen Karte verschwunden. Finde heraus, wer es abgekratzt hat."), "Proofgate"),
                (("The village asked to be erased. One of its people fishes on the Smudge Marsh.", "Das Dorf wollte gelöscht werden. Eine von dort fischt im Smudge-Sumpf."), "Smudge Marsh"),
                (("You know where Hollow Em hides. Ansa is waiting in Proofgate.", "Du weißt, wo sich Hollow Em versteckt. Ansa wartet in Proofgate."), "Proofgate"),
                (("A tax rider follows your tracks across the Smudge Marsh. Stop him, then see Ansa.", "Ein Steuerreiter folgt deinen Spuren durch den Smudge-Sumpf. Halt ihn auf und geh dann zu Ansa."), "Smudge Marsh"),
                (("Hollow Em is a rumour or a tax roll. You chose which.", "Hollow Em ist ein Gerücht oder eine Steuerliste. Du hast gewählt, was."), "Proofgate")]},

    {"id": "early_epitaph", "turns": True, "road": "gravers_causeway", "reward": ("revival_leaf", 3),
     "giver": ("errata_chapel", 8, 2, "down", "elder", "brand"),
     "intro": [("Corrector Brand: Welcome to the Errata Chapel. We print corrected epitaphs. 'Beloved' becomes 'tolerated'. Families pay well for accuracy.", "Korrektor Brand: Willkommen in der Errata-Kapelle. Wir drucken berichtigte Grabschriften. Aus 'geliebt' wird 'geduldet'. Familien zahlen gut für Genauigkeit."),
               ("Corrector Brand: Trouble is, epitaphs are being corrected before the people die. Someone is ahead of me. Find out who gets the lists.", "Korrektor Brand: Nur werden Grabschriften berichtigt, bevor die Leute sterben. Jemand ist mir voraus. Finde heraus, wer die Listen bekommt.")],
     "wait": ("Corrector Brand: Names and dates come out of the Ledger Archive in Ledgerholm. Start with the archive runner.", "Korrektor Brand: Namen und Daten kommen aus dem Bucharchiv in Ledgerholm. Fang beim Archivläufer an."),
     "reveal": [("Corrector Brand: You went to the Print Shop. So you know who is ahead of me. I am. I'm very punctual.", "Korrektor Brand: Du warst in der Druckerei. Dann weißt du, wer mir voraus ist. Ich. Ich bin sehr pünktlich."),
                ("Corrector Brand: A plot sold early is a plot sold twice. And a stranger who dies on the Causeway needs no family discount.", "Korrektor Brand: Ein früh verkauftes Grab ist ein zweimal verkauftes Grab. Und eine Fremde, die auf dem Damm stirbt, braucht keinen Familienrabatt."),
                ("Corrector Brand: Your stone is already cut. It would be a shame to correct it.", "Korrektor Brand: Dein Stein ist schon gemeißelt. Es wäre schade, ihn berichtigen zu müssen.")],
     "steps": [("ledgerholm_archive", 6, 2, "down", "villager", "pim",
                [("Archive Runner Pim: The death lists? They aren't death lists. They are loans falling due. Same people, mostly. Same week.", "Archivläufer Pim: Die Totenlisten? Das sind keine Totenlisten. Das sind fällige Kredite. Meistens dieselben Leute. Dieselbe Woche."),
                 ("Archive Runner Pim: A copy goes to the Print Shop in Platewick every month. Somebody there sets the stones in advance.", "Archivläufer Pim: Jeden Monat geht eine Abschrift an die Druckerei in Platewick. Dort setzt jemand die Steine im Voraus.")],
                ("Archive Runner Pim: I'm on a list myself. Small loan. Small stone.", "Archivläufer Pim: Ich stehe selbst auf einer Liste. Kleiner Kredit. Kleiner Stein.")),
               ("platewick_print_shop", 6, 2, "down", "villager", "hanne",
                [("Typesetter Hanne: Advance epitaphs, yes. Forty a month. Ordered and paid by Corrector Brand. He gets a discount for bulk.", "Setzerin Hanne: Grabschriften im Voraus, ja. Vierzig im Monat. Bestellt und bezahlt von Korrektor Brand. Er kriegt Mengenrabatt."),
                 ("Typesetter Hanne: He sells the plots before the debt falls due. There is one on the bench now. No name yet. Just 'a stranger, asked too many questions'.", "Setzerin Hanne: Er verkauft die Gräber, bevor die Schuld fällig wird. Einer liegt gerade auf der Bank. Noch ohne Namen. Nur 'eine Fremde, stellte zu viele Fragen'.")],
                ("Typesetter Hanne: I set my own stone once, for practice. Brand sent me a bill.", "Setzerin Hanne: Ich habe mal meinen eigenen Stein gesetzt, zur Übung. Brand hat mir eine Rechnung geschickt."))],
     "betrayer": ("gravers_causeway", 2, 17, "right", "elder", "brand_stone", ("Corrector Brand", "Korrektor Brand"),
                  [("Brand: Here lies a stranger. Asked too many questions. Please lie down, the wording is final.", "Brand: Hier ruht eine Fremde. Stellte zu viele Fragen. Bitte leg dich hin, der Wortlaut steht fest.")],
                  [("Brand: An erratum. In my own chapel.", "Brand: Ein Erratum. In meiner eigenen Kapelle."),
                   ("Brand: Take the stone money. And the stone. It is good granite. You'll want it one day.", "Brand: Nimm das Steingeld. Und den Stein. Es ist guter Granit. Eines Tages willst du ihn haben.")],
                  [("You take Brand's cash box. Inside: three revival leaves and a receipt for your plot. Paid in full, with a view of the canal.", "Du nimmst Brands Kasse. Darin: drei Lebensblätter und eine Quittung für dein Grab. Voll bezahlt, mit Blick auf den Kanal.")],
                  ("Brand: I corrected your stone. It now reads 'still alive, regrettably'. No charge.", "Brand: Ich habe deinen Stein berichtigt. Jetzt steht da 'lebt noch, bedauerlicherweise'. Kostet nichts.")),
     "stages": [(("Epitaphs in the Errata Chapel are corrected before people die. Find out who gets the lists.", "In der Errata-Kapelle werden Grabschriften berichtigt, bevor die Leute sterben. Finde heraus, wer die Listen bekommt."), "Ledgerholm"),
                (("The lists are loans falling due. Ask in the Print Shop in Platewick who sets the stones.", "Die Listen sind fällige Kredite. Frag in der Druckerei in Platewick, wer die Steine setzt."), "Platewick"),
                (("Corrector Brand orders the early epitaphs himself. Ask him.", "Korrektor Brand bestellt die frühen Grabschriften selbst. Frag ihn."), "Errata Chapel"),
                (("Brand has cut your stone already. Beat him on the Gravers' Causeway.", "Brand hat deinen Stein schon gemeißelt. Schlag ihn auf dem Graveursdamm."), "Gravers' Causeway"),
                (("Your plot is paid in full. You are not using it yet.", "Dein Grab ist voll bezahlt. Du benutzt es noch nicht."), "Errata Chapel")]},

    {"id": "dead_stamp", "turns": True, "road": "stamp_road", "reward": ("revival_leaf", 2),
     "giver": ("stamp_road", 2, 17, "right", "villager", "pia"),
     "intro": [("Pia: Look at my papers. 'Deceased.' One wrong stamp, and I can't buy bread, rent a bed or be arrested. I tried.", "Pia: Sieh dir meine Papiere an. 'Verstorben.' Ein falscher Stempel, und ich kann kein Brot kaufen, kein Bett mieten und nicht verhaftet werden. Ich habe es versucht."),
               ("Pia: Get it corrected for me. They won't talk to me in the Stamp Hall. Company policy on the dead.", "Pia: Lass es für mich berichtigen. In der Stempelhalle reden sie nicht mit mir. Hausregel für Tote.")],
     "wait": ("Pia: The Stamp Hall is in Proofgate. Ask for the chief stamper's girl. She does the real work.", "Pia: Die Stempelhalle ist in Proofgate. Frag nach dem Mädchen des Oberstemplers. Sie macht die eigentliche Arbeit."),
     "reveal": [("Pia: You checked your satchel. Yes. I stamped myself dead two years ago. Debts die with you. It's the one honest rule in Quillmarch.", "Pia: Du hast in deine Tasche gesehen. Ja. Ich habe mich vor zwei Jahren selbst tot gestempelt. Schulden sterben mit dir. Das ist die eine ehrliche Regel in Quillmarch."),
                ("Pia: But the dead can't leave through Proofgate. The living can. So I needed a living set, and someone too busy to notice.", "Pia: Aber Tote kommen nicht durch Proofgate hinaus. Lebende schon. Also brauchte ich lebende Papiere und jemanden, der zu beschäftigt ist, es zu merken."),
                ("Pia: You are deceased, I am you, and the gate shuts at dusk. Nothing personal. That is rather the point.", "Pia: Du bist verstorben, ich bin du, und das Tor schließt bei Dämmerung. Nichts Persönliches. Genau darum geht es ja.")],
     "steps": [("proofgate_stamp_hall", 6, 2, "down", "villager", "tove",
                [("Stamp Girl Tove: 'Deceased' can't be undone. Policy. But papers can be swapped, if somebody living signs theirs over.", "Stempelmädchen Tove: 'Verstorben' lässt sich nicht zurücknehmen. Vorschrift. Aber Papiere kann man tauschen, wenn ein Lebender seine überschreibt."),
                 ("Stamp Girl Tove: Unclaimed papers of the living end up in the Dead Letter Office on Drypoint Lane. Ask there. Don't say I said.", "Stempelmädchen Tove: Nicht abgeholte Papiere von Lebenden landen im Amt für tote Briefe an der Drypoint Lane. Frag dort. Sag nicht, dass ich es gesagt habe.")],
                ("Stamp Girl Tove: Approved, denied, deceased. I dream in three colours.", "Stempelmädchen Tove: Genehmigt, abgelehnt, verstorben. Ich träume in drei Farben.")),
               ("dead_letter_office", 9, 7, "left", "elder", "asmund",
                [("Paper Clerk Asmund: Swap papers for a dead girl? Already done, this morning. She came in herself. Very lively for her condition.", "Papierschreiber Asmund: Papiere tauschen für ein totes Mädchen? Schon erledigt, heute Morgen. Sie kam selbst vorbei. Sehr lebhaft für ihren Zustand."),
                 ("Paper Clerk Asmund: She signed for a traveller's papers and left her old ones in their place. I'd check your satchel, if I were you. Which, on paper, she now is.", "Papierschreiber Asmund: Sie hat für die Papiere einer Reisenden unterschrieben und ihre alten an deren Stelle gelegt. Ich würde in deine Tasche sehen, wenn ich du wäre. Was sie, auf dem Papier, jetzt ist.")],
                ("Paper Clerk Asmund: Identity is nine tenths paperwork. The other tenth we lose.", "Papierschreiber Asmund: Identität ist zu neun Zehnteln Papierkram. Das letzte Zehntel verlieren wir."))],
     "betrayer": ("stamp_road", 7, 21, "left", "villager", "pia_you", ("Pia, On Paper You", "Pia, auf dem Papier du"),
                  [("Pia: Don't make a scene. Dead people don't.", "Pia: Mach keine Szene. Tote machen keine.")],
                  [("Pia: Fine. Have yourself back.", "Pia: Schön. Hier hast du dich zurück."),
                   ("Pia: Keep my old papers too. Being dead is restful. No one writes.", "Pia: Behalt meine alten Papiere auch. Tot sein ist erholsam. Keiner schreibt.")],
                  [("You take your papers back from Pia, and her satchel. Inside: two revival leaves, of all things.", "Du nimmst Pia deine Papiere wieder ab, und ihre Tasche. Darin: ausgerechnet zwei Lebensblätter.")],
                  ("Pia: I'm deceased again. They gave me a job in the Stamp Hall. I know the form from both sides.", "Pia: Ich bin wieder verstorben. Sie haben mir eine Stelle in der Stempelhalle gegeben. Ich kenne das Formular von beiden Seiten.")),
     "stages": [(("Pia's papers are stamped 'deceased' by mistake. Get the stamp corrected in Proofgate.", "Pias Papiere tragen aus Versehen den Stempel 'verstorben'. Lass den Stempel in Proofgate berichtigen."), "Proofgate"),
                (("Papers can be swapped. Ask in the Dead Letter Office on Drypoint Lane.", "Papiere kann man tauschen. Frag im Amt für tote Briefe an der Drypoint Lane."), "Dead Letter Office"),
                (("Pia swapped her papers for yours. On paper you are dead. Find her on Stamp Road.", "Pia hat ihre Papiere gegen deine getauscht. Auf dem Papier bist du tot. Such sie auf der Stempelstraße."), "Stamp Road"),
                (("Pia is leaving as you. Stop her on Stamp Road.", "Pia reist als du ab. Halt sie auf der Stempelstraße auf."), "Stamp Road"),
                (("You are alive again, on paper. Pia is not, and prefers it.", "Du lebst wieder, auf dem Papier. Pia nicht, und so ist es ihr lieber."), "Stamp Road")]},
]

# One more Wayfarer per road at (10, 15), looking at the path: (key, title, talk, intro, defeat).
EXTRA_CELL = (10, 15)
EXTRA = {
    "drypoint_lane": ("puller", ("Proof Puller Embla", "Andruckerin Embla"),
                      ("Embla: I pull the first print of every plate. If it's a wanted poster, I get a head start.", "Embla: Ich ziehe den ersten Abzug von jeder Platte. Ist es ein Steckbrief, habe ich einen Vorsprung."),
                      ("Embla: Let's see how you look in reverse.", "Embla: Mal sehen, wie du spiegelverkehrt aussiehst."),
                      ("Embla: Smudged. My fault. Write that down, it's rare.", "Embla: Verschmiert. Meine Schuld. Schreib das auf, das ist selten.")),
    "mordant_steps": ("carrier", ("Acid Carrier Bodil", "Säureträgerin Bodil"),
                      ("Bodil: Two buckets up, two buckets down. I have one good shoulder and one very clean one.", "Bodil: Zwei Eimer rauf, zwei Eimer runter. Ich habe eine gute Schulter und eine sehr saubere."),
                      ("Bodil: Careful. If I spill, we both get shorter.", "Bodil: Vorsicht. Wenn ich was verschütte, werden wir beide kürzer."),
                      ("Bodil: Not a drop spilled. Losing is easy when you're careful.", "Bodil: Kein Tropfen verschüttet. Verlieren ist leicht, wenn man vorsichtig ist.")),
    "hoarfrost_moor": ("reader", ("Frost Reader Yrsa", "Frostleserin Yrsa"),
                       ("Yrsa: The frost wrote 'run' on my sledge this morning. I assumed it meant you.", "Yrsa: Der Frost hat heute Morgen 'lauf' auf meinen Schlitten geschrieben. Ich nahm an, er meint dich."),
                       ("Yrsa: Hold still. There is something written on your back.", "Yrsa: Halt still. Auf deinem Rücken steht etwas."),
                       ("Yrsa: It said 'loser'. It meant me. The frost is rude.", "Yrsa: Da stand 'Verliererin'. Gemeint war ich. Der Frost ist unhöflich.")),
    "gravers_causeway": ("toller", ("Toll Graver Sixten", "Zollgraveur Sixten"),
                         ("Sixten: The Causeway toll is one coin or one portrait. I keep the portraits. They are useful later.", "Sixten: Der Dammzoll ist eine Münze oder ein Porträt. Die Porträts behalte ich. Die sind später nützlich."),
                         ("Sixten: Coin, portrait or a beating. I have engraved all three.", "Sixten: Münze, Porträt oder Prügel. Ich habe alle drei schon gestochen."),
                         ("Sixten: Go on through. I'll draw you from memory. Unkindly.", "Sixten: Geh durch. Ich zeichne dich aus dem Gedächtnis. Unfreundlich.")),
    "rimeglass_pass": ("cutter", ("Ice Cutter Halla", "Eisschneiderin Halla"),
                       ("Halla: I cut blocks for the Icehouse. Big ones. They never say what for, and I never measure anyone.", "Halla: Ich schneide Blöcke für das Eishaus. Große. Sie sagen nie, wofür, und ich messe nie jemanden aus."),
                       ("Halla: You're about a block and a half. Let me check.", "Halla: Du bist etwa anderthalb Blöcke. Lass mich nachmessen."),
                       ("Halla: Too lively to store. Shame.", "Halla: Zu lebhaft zum Einlagern. Schade.")),
    "stamp_road": ("inspector", ("Stamp Inspector Gorm", "Stempelprüfer Gorm"),
                   ("Gorm: Papers. No, don't show me. I prefer to be surprised.", "Gorm: Papiere. Nein, zeig sie nicht. Ich lasse mich lieber überraschen."),
                   ("Gorm: Unstamped traveller. That's a fine or a fight, and I've lost the fine book.", "Gorm: Ungestempelte Reisende. Das gibt eine Strafe oder einen Kampf, und das Strafbuch habe ich verloren."),
                   ("Gorm: Approved. Under protest. Mine.", "Gorm: Genehmigt. Unter Protest. Meinem.")),
    "smudge_marsh": ("eeler", ("Eel Smuggler Disa", "Aalschmugglerin Disa"),
                     ("Disa: Eels don't pay tax if nobody counts them. I help them stay uncounted.", "Disa: Aale zahlen keine Steuer, wenn keiner sie zählt. Ich helfe ihnen, ungezählt zu bleiben."),
                     ("Disa: You've seen my eels. That makes you a witness or a customer.", "Disa: Du hast meine Aale gesehen. Damit bist du Zeugin oder Kundin."),
                     ("Disa: Customer, then. The first eel is free. It bites.", "Disa: Dann eben Kundin. Der erste Aal ist gratis. Er beißt.")),
}
# More hidden finds: one per road (an outdoor map hides five at most) and two per Rift (cells in the frame, next to open ground).
ROAD_FINDS = [(0, 3, "dash_brew")]
RIFT_FINDS = [(0, 10, "max_tonic"), (11, 14, "revival_leaf")]
HALL_FINDS = [(11, 5), (0, 7)]
WALK = "._:,%f+"


def flag(g, step):
    return "q3_%s_%s" % (g["id"], step)


def kinds_of(q, road):
    r = q.ROUTES[road]
    return [q.slot_species(s) for s in r["slots"]] + [sp for sp, _ in q.WILD[road]]


def road_team(q, who, road, offset, levels):
    """len(levels) kinds of [road]'s table within three elements, turned by [offset] so teams differ."""
    kinds = kinds_of(q, road)
    kinds = kinds[offset % len(kinds):] + kinds[:offset % len(kinds)]
    for pick in itertools.combinations(kinds, len(levels)):
        els = set()
        for sp in pick:
            els.update(q.SPECIES[sp]["elements"])
        if len(els) <= 3:
            return q.check_team(who, [{"species": sp, "level": lv} for sp, lv in zip(pick, levels)])
    raise SystemExit("%s: no %d kinds within three elements" % (road, len(levels)))


def free(q, mid, x, y):
    """Stops the build when [x, y] of [mid] is no open ground or something stands or happens there."""
    m = q.MAPS[mid]
    rows = m["rows"]
    if rows[y][x] not in WALK:
        raise SystemExit("%s %d,%d is %r, not open ground" % (mid, x, y, rows[y][x]))
    taken = [(n["x"], n["y"]) for n in m["npcs"]] + [(s["x"], s["y"]) for s in m.get("signs", [])]
    taken += [(w["x"], w["y"]) for w in m["warps"]] + [(w["tx"], w["ty"]) for o in q.MAPS.values() for w in o["warps"] if w["to"] == mid]
    for n in m["npcs"]:
        taken += [(s["x"], s["y"]) for s in n.get("schedule", []) if "x" in s]
    taken += [tuple(m[k]) for k in ("heal_point", "square") if k in m]
    if mid == "burin_landing":
        taken.append(q.BOAT_LANDING)
    if (x, y) in taken or rows[y - 1][x] == "D":
        raise SystemExit("%s %d,%d is taken" % (mid, x, y))


def place(q, mid, n, shared=False):
    if not shared:
        free(q, mid, n["x"], n["y"])
    q.MAPS[mid]["npcs"].append(n)


def find(q, mid, x, y, item, key):
    rows = q.MAPS[mid]["rows"]
    near = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < len(rows[0]) and 0 <= y + dy < len(rows)]
    if rows[y][x] in WALK or not any(rows[b][a] in WALK for a, b in near):
        raise SystemExit("%s %d,%d: a find sits in the frame next to open ground" % (mid, x, y))
    q.MAPS[mid].setdefault("secrets", []).append(q.secret(x, y, item, "find_%s_%s" % (mid, key)))


def halls(q):
    """The three landmark halls and their story duels; returns the duels for data/story_battles.json."""
    duels = {}
    dx, dy = HALL_DOOR
    for n, h in enumerate(HALLS):
        hid, road = h["id"], h["road"]
        rows = q.MAPS[road]["rows"]
        if any(rows[y][x] != "@" for y in (dy - 1, dy) for x in (dx - 1, dx, dx + 1)) or rows[dy + 1][dx] not in WALK:
            raise SystemExit("%s: no rock to build %s into" % (road, hid))
        rows[dy - 1] = rows[dy - 1][:dx - 1] + "RRR" + rows[dy - 1][dx + 2:]
        rows[dy] = rows[dy][:dx - 1] + "HDH" + rows[dy][dx + 2:]
        q.MAPS[road]["warps"].append(q.warp(dx, dy, hid, 5, 8, "up"))
        signs = [{"x": x, "y": 4, "dialogue": q.text("%s_sign_%d" % (hid, i + 1), q.lines(s))} for i, (x, s) in enumerate(zip((1, 10), h["signs"]))]
        q.add(hid, {"name": q.tr(*h["name"]), "biome": "town", "backdrop": "field", "rows": list(h["rows"]),
                    "warps": [q.warp(5, 9, road, dx, dy + 1, "down")], "npcs": [], "signs": signs, "secrets": []})
        q.INTERIORS[hid] = road
        for i, ((x, y), item) in enumerate(zip(HALL_FINDS, h["finds"])):
            find(q, hid, x, y, item, str(i + 1))
        # The duellist: asks, fights (story duel q3_<hall>), pays once.
        d = h["duel"]
        k = "q3_" + hid
        won, paid = k + "_won", k + "_paid"
        hi = q.ROUTES[road]["ring"][1]
        duels[k] = {"trainer": q.tr(*d["title"]), "team": road_team(q, hid, road, 5 + 2 * n, [hi, hi, hi + 1]), "ai": 2, "money": hi * 60,
                    "defeat": q.text(k + "_defeat", q.lines(d["defeat"])), "lose": q.text(k + "_lose", q.lines(d["lose"])),
                    "win_flags": [won]}
        q.text(k + "_fight", {"lines": q.lines(d["fight"]), "action": "battle " + k})
        q.text(k + "_later", q.lines(d["later"]))
        q.text(k + "_done", q.lines(d["done"]))
        q.text(k + "_pay", {"if": {"not_flag": paid}, "else": k + "_done", "lines": q.lines(*d["pay"]),
                            "action": "set_flag %s; give_item %s %d" % (paid, d["reward"][0], d["reward"][1])})
        talk = q.text(k, {"if": {"not_flag": won}, "else": k + "_pay", "lines": q.lines(*d["talk"]),
                          "choices": [{"text": q.tr(*d["yes"]), "next": k + "_fight"}, {"text": q.tr(*d["no"]), "next": k + "_later"}]})
        place(q, hid, q.npc(k, 5, 2, "down", talk, d["sprite"]))
    return duels


def extras(q):
    for i, (road, (key, title, talk, intro, defeat)) in enumerate(EXTRA.items()):
        lo, hi = q.ROUTES[road]["ring"]
        crew = road_team(q, road + " " + key, road, 3 + i, [lo + 1, (lo + hi + 1) // 2, hi])
        x, y = EXTRA_CELL
        place(q, road, q.npc("q3_" + key, x, y, "left", q.text("q3_%s_%s" % (road, key), q.lines(talk)), "ranger" if i % 2 else "villager",
                             trainer=q.tr(*title), intro=q.text("q3_%s_%s_intro" % (road, key), q.lines(intro)),
                             defeat=q.text("q3_%s_%s_defeat" % (road, key), q.lines(defeat)), money=hi * 40, team=crew))
        for x, y, item in ROAD_FINDS:
            find(q, road, x, y, item, "q3_%d_%d" % (x, y))
    for mid in q.RIFTS:
        for x, y, item in RIFT_FINDS:
            find(q, mid, x, y, item, "q3_%d_%d" % (x, y))


def goal(q, i, g):
    gid = g["id"]
    asked, s1, s2, reveal, done, paid = (flag(g, s) for s in ("asked", "s1", "s2", "reveal", "done", "paid"))
    k = "q3_" + gid
    pay = "set_flag %s; give_item %%s %%d; quest_stage %s 4" % (paid, k)
    # Giver: a chain of "if"s, last state first.
    gm, gx, gy, gf, gs, gname = g["giver"]
    q.text(k + "_wait", q.lines(g["wait"]))
    q.text(k + "_reveal", {"if": {"flag": s2}, "else": k + "_wait", "lines": q.lines(*g["reveal"]),
                           "action": "set_flag %s; quest_stage %s 3" % (reveal, k)})
    nxt = k + "_reveal"
    if not g["turns"]:
        q.text(k + "_go", {"if": {"flag": reveal}, "else": nxt, "lines": q.lines(g["go"])})
        c = g["choice"]
        answers = []
        last = k + "_reward"
        for way in ("trust", "keep"):
            label, (item, count), said, after = c[way]
            chose = flag(g, "trusted" if way == "trust" else "kept")
            q.text("%s_%s" % (k, way), q.lines(*said))
            answers.append({"text": q.tr(*label), "flag": chose, "action": pay % (item, count), "next": "%s_%s" % (k, way)})
            q.text("%s_after_%s" % (k, way), {"if": {"flag": chose}, "else": last, "lines": q.lines(after)})
            last = "%s_after_%s" % (k, way)
        q.text(k + "_reward", {"if": {"flag": done}, "else": k + "_go", "lines": q.lines(*g["reward_lines"]), "choices": answers})
        nxt = last
        for wm, wx, wy, wf, ws, wid, way, said in c["witness"]:
            twin = any(n["x"] == wx and n["y"] == wy and str(n["id"]).startswith(k + "_") for n in q.MAPS[wm]["npcs"])
            place(q, wm, q.npc("%s_%s" % (k, wid), wx, wy, wf, q.text("%s_%s" % (k, wid), q.lines(*said)), ws, show_flag=flag(g, way)), shared=twin)
    giver = q.text(k, {"if": {"not_flag": asked}, "else": nxt, "lines": q.lines(*g["intro"]), "action": "set_flag " + asked})
    extra = {"hide_flag": reveal} if g["turns"] else {}
    place(q, gm, q.npc(k + "_" + gname, gx, gy, gf, giver, gs, **extra))
    # Steps.
    for n, ((sm, sx, sy, sf, ss, sid, talk, after), (shown, sets)) in enumerate(zip(g["steps"], [(asked, s1), (s1, s2)])):
        q.text("%s_%s_after" % (k, sid), q.lines(after))
        d = q.text("%s_%s" % (k, sid), {"if": {"not_flag": sets}, "else": "%s_%s_after" % (k, sid), "lines": q.lines(*talk),
                                        "action": "set_flag %s; quest_stage %s %d" % (sets, k, n + 1)})
        place(q, sm, q.npc("%s_%s" % (k, sid), sx, sy, sf, d, ss, show_flag=shown))
    # Betrayer.
    bm, bx, by, bf, bs, bid, title, intro, defeat, loot, after = g["betrayer"]
    hi = q.ROUTES[g["road"]]["ring"][1]
    crew = road_team(q, k, g["road"], i, [hi - 1, hi, hi + 1])
    if g["turns"]:
        q.text("%s_%s_after" % (k, bid), q.lines(after))
        talk = q.text("%s_%s" % (k, bid), {"if": {"not_flag": paid}, "else": "%s_%s_after" % (k, bid), "lines": q.lines(*loot),
                                           "action": pay % g["reward"]})
    else:
        talk = q.text("%s_%s" % (k, bid), q.lines(after))
    place(q, bm, q.npc("%s_%s" % (k, bid), bx, by, bf, talk, bs, trainer=q.tr(*title), show_flag=reveal,
                       intro=q.text("%s_%s_intro" % (k, bid), q.lines(*intro)),
                       defeat=q.text("%s_%s_defeat" % (k, bid), q.lines(*defeat)),
                       money=(hi + 1) * 50, team=crew, win_flags=[done], no_rematch=True))
    for _, where in g["stages"]:
        if where not in HALL_NAME.values() and not any(m["name"] == where for m in q.MAPS.values()):
            raise SystemExit("%s: stage place %r is no Quillmarch map" % (k, where))
    stages = [{"text": q.tr(*t), "where": w} for t, w in g["stages"]]
    return {"id": k, "text": stages[0]["text"], "where": stages[0]["where"], "show": asked, "done": done,
            "progress": [s1, s2, reveal, done], "stages": stages}


def build(q):
    duels = halls(q)
    extras(q)
    goals = [goal(q, i, g) for i, g in enumerate(GOALS)]
    patch_quests(q.ROOT, goals)
    patch_duels(q.ROOT, duels)
    return goals


def patch_quests(root, goals):
    """Replaces the q3_* side goals in data/quests.json (one goal per line, like the rest)."""
    path = os.path.join(root, "data", "quests.json")
    rows = open(path, encoding="utf-8").read().split("\n")
    rows = [r for r in rows if '{"id": "q3_' not in r]
    start = rows.index('  "side": [')
    end = next(i for i in range(start + 1, len(rows)) if rows[i].startswith("  ]"))
    body = [r.rstrip(",") for r in rows[start + 1:end]]
    body += ["    " + json.dumps(g, ensure_ascii=False) for g in goals]
    body = [r + "," for r in body[:-1]] + body[-1:]
    rows[start + 1:end] = body
    text = "\n".join(rows)
    json.loads(text)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def patch_duels(root, duels):
    """Replaces the q3_* story duels in data/story_battles.json."""
    path = os.path.join(root, "data", "story_battles.json")
    d = {k: v for k, v in json.load(open(path, encoding="utf-8")).items() if not k.startswith("q3_")}
    d.update(duels)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
        f.write("\n")
