"""Quivermoor side goals: eight errands on the bog, each one ending in a betrayal. Called by
tools/art/world/quivermoor.py (run that, not this file); it puts the figures on the region's maps,
writes their texts into data/dialogue/quivermoor.json and the goals into data/quests.json (ids q5_*).

Every goal runs the same way, with its own flags q5_<id>_<step>:
  giver      asked    sets the goal going
  step 1     s1       shows once asked
  step 2     s2       shows once s1 is set
  giver      reveal   back at the giver: the truth comes out
  betrayer   done     shows once reveal is set; beating them sets done (win_flags)
  reward     paid     the giver pays, or, when the giver was the betrayer, you take it off them
Progress counts s1, s2, reveal and done; the stages follow with "quest_stage".
Betrayer teams come from the road they belong to: three of its kinds at ring top -1, top, top +1.
"""
import itertools
import json
import os

# (map, x, y, facing). Free cells checked against the town, road, room and Rift rows in quivermoor.py.
GOALS = [
    {"id": "short_candle", "turns": True, "road": "candle_causeway", "reward": ("max_tonic", 3),
     "giver": ("tallowmere", 7, 16, "left", "elder", "aud"),
     "intro": [("Widow Aud: My boy's candle in the Hall of Names burns half as long as the others. Somebody trimmed it.", "Witwe Aud: Die Kerze meines Jungen in der Halle der Namen brennt halb so lang wie die anderen. Jemand hat sie gekürzt."),
               ("Widow Aud: A short candle is a short life. Find out who did it. Please. I have already bought the black dress.", "Witwe Aud: Kurze Kerze, kurzes Leben. Finde heraus, wer das war. Bitte. Das schwarze Kleid hab ich schon gekauft.")],
     "wait": ("Widow Aud: The wick trimmers work out on the Candle Causeway. Ask them who signs the orders.", "Witwe Aud: Die Dochtschneider arbeiten draußen auf dem Kerzendamm. Frag sie, wer die Aufträge unterschreibt."),
     "reveal": [("Widow Aud: The order is in my hand? Well. It is a very neat hand.", "Witwe Aud: Der Auftrag ist in meiner Schrift? Na ja. Es ist eine sehr ordentliche Schrift."),
                ("Widow Aud: Short candle, short funeral, short bill. He was going to leave anyway. I just wanted to pick the date.", "Witwe Aud: Kurze Kerze, kurze Beerdigung, kurze Rechnung. Er wäre sowieso gegangen. Ich wollte nur den Tag aussuchen."),
                ("Widow Aud: And you know now. I have a second candle in my pocket. Unlit. It has your name on it.", "Witwe Aud: Und jetzt weißt du es. Ich hab noch eine Kerze in der Tasche. Nicht angezündet. Sie trägt deinen Namen.")],
     "steps": [("candle_causeway", 10, 3, "left", "villager", "pell",
                [("Wick Trimmer Pell: Trim orders? They come in sealed. I cut where the wax tells me.", "Dochtschneider Pell: Kürzungsaufträge? Die kommen versiegelt. Ich schneide, wo das Wachs es sagt."),
                 ("Wick Trimmer Pell: The ledger boy in the Hall of Names files them. He reads everything. Nobody tells him to stop.", "Dochtschneider Pell: Der Bücherjunge in der Halle der Namen legt sie ab. Er liest alles. Keiner sagt ihm, er soll aufhören.")],
                ("Wick Trimmer Pell: Snip. Another year gone. Not mine, so I don't mind.", "Dochtschneider Pell: Schnipp. Wieder ein Jahr weg. Nicht meins, also stört es mich nicht.")),
               ("tallowmere_name_hall", 6, 2, "down", "villager", "fenn",
                [("Ledger Boy Fenn: The order for the short candle? Here. Signed and paid in advance.", "Bücherjunge Fenn: Der Auftrag für die kurze Kerze? Hier. Unterschrieben und im Voraus bezahlt."),
                 ("Ledger Boy Fenn: Signed 'Aud, loving mother'. She paid extra for the loving.", "Bücherjunge Fenn: Unterschrieben mit 'Aud, liebende Mutter'. Für das Liebende hat sie extra bezahlt.")],
                ("Ledger Boy Fenn: I have the orders for half the town. Including yours. Don't ask. It's very short.", "Bücherjunge Fenn: Ich hab die Aufträge für die halbe Stadt. Auch deinen. Frag nicht. Er ist sehr kurz."))],
     "betrayer": ("tallowmere", 4, 11, "right", "elder", "aud_lit", ("Widow Aud", "Witwe Aud"),
                  [("Widow Aud: Hold still. Candles burn straighter when the person does.", "Witwe Aud: Halt still. Kerzen brennen gerader, wenn der Mensch es tut.")],
                  [("Widow Aud: Out. Blown out. That never happens to me.", "Witwe Aud: Aus. Ausgeblasen. Das passiert mir sonst nie."),
                   ("Widow Aud: Fine. Take the candle. Take the dress, too. It's very slimming.", "Witwe Aud: Gut. Nimm die Kerze. Nimm auch das Kleid. Es macht sehr schlank.")],
                  [("You take Aud's purse. Inside: three tonics and the receipt for a coffin, one size too small.", "Du nimmst Auds Beutel. Darin: drei Tonika und die Quittung für einen Sarg, eine Nummer zu klein.")],
                  ("Widow Aud: My boy left on the first raft. Alive. I will never forgive him.", "Witwe Aud: Mein Junge ist mit dem ersten Floß weg. Lebendig. Das verzeih ich ihm nie.")),
     "stages": [("Widow Aud's son has a trimmed candle in the Hall of Names. Find out who cut it.", "Tallowmere"),
                ("The trim orders are filed in the Hall of Names. Ask the ledger boy.", "Tallowmere"),
                ("The order is signed by Aud herself. Ask her why.", "Tallowmere"),
                ("Aud lit a candle with your name on it. Blow her out.", "Tallowmere"),
                ("Her boy got away. You got the receipt.", "Tallowmere")]},

    {"id": "rope_fund", "turns": False, "road": "breathing_bog", "reward": ("revival_leaf", 2),
     "giver": ("mossgate", 4, 11, "right", "villager", "hesk"),
     "intro": [("Collector Hesk: Coin for the Rope Fund? The basket rope frays. People fall. We want a new one.", "Sammler Hesk: Eine Münze für den Seilfonds? Das Korbseil franst aus. Leute fallen. Wir wollen ein neues."),
               ("Collector Hesk: Odd thing: the fund is full and the rope is still old. Can you find out where the money goes? I only collect.", "Sammler Hesk: Seltsam: Der Fonds ist voll und das Seil ist immer noch alt. Findest du heraus, wohin das Geld geht? Ich sammle nur.")],
     "wait": ("Collector Hesk: Ask Agna in the Rope Loft. And the divers on the Breathing Bog see everything that falls.", "Sammler Hesk: Frag Agna auf dem Seilboden. Und die Taucher im Atmenden Moor sehen alles, was runterfällt."),
     "reveal": [("Collector Hesk: Purses from the bottom of the bog, with the Reeve's mark? Oh no. Oh, the Reeve.", "Sammler Hesk: Beutel vom Grund des Moors, mit dem Zeichen des Vogts? Oh nein. Oh, der Vogt."),
                ("Collector Hesk: He pays the winch man to cut the rope short, then salvages the fallen. Rich people fall too. They fall with purses.", "Sammler Hesk: Er bezahlt den Mann an der Winde, damit er das Seil zu kurz kappt, und birgt dann die Gestürzten. Reiche fallen auch. Sie fallen mit Beuteln."),
                ("Collector Hesk: His salvage man waits on the bog tonight. Stop him. I'll keep the fund safe. Safe with me.", "Sammler Hesk: Sein Bergungsmann wartet heute Nacht im Moor. Halt ihn auf. Ich halte den Fonds sicher. Sicher bei mir.")],
     "go": ("Collector Hesk: The salvage man is on the Breathing Bog. Go. I'll count while you're gone.", "Sammler Hesk: Der Bergungsmann ist im Atmenden Moor. Geh. Ich zähle, solange du weg bist."),
     "reward_lines": [("Collector Hesk: You beat him? Good. The fund thanks you. Here's your share. A small share. Funds are expensive.", "Sammler Hesk: Du hast ihn geschlagen? Gut. Der Fonds dankt dir. Hier ist dein Anteil. Ein kleiner Anteil. Fonds sind teuer.")],
     "after": ("Collector Hesk: New rope next year. Or the year after. Ropes take time. So do I, with the money.", "Sammler Hesk: Nächstes Jahr ein neues Seil. Oder übernächstes. Seile brauchen Zeit. Ich auch, mit dem Geld."),
     "steps": [("mossgate_rope_loft", 6, 2, "down", "villager", "agna_girl",
                [("Rope Girl Lisbet: A new basket rope? Nobody ordered one. Not this year, not last year.", "Seilmädchen Lisbet: Ein neues Korbseil? Keiner hat eins bestellt. Nicht dieses Jahr, nicht letztes Jahr."),
                 ("Rope Girl Lisbet: The Reeve buys short lengths, though. Always short. Ask the divers what lands in the bog.", "Seilmädchen Lisbet: Der Vogt kauft aber kurze Stücke. Immer kurze. Frag die Taucher, was im Moor landet.")],
                ("Rope Girl Lisbet: Agna says a rope is only as strong as the man who pays for it.", "Seilmädchen Lisbet: Agna sagt, ein Seil ist nur so stark wie der Mann, der es bezahlt.")),
               ("breathing_bog", 2, 17, "right", "ranger", "ulla",
                [("Bog Diver Ulla: I bring up what falls from the basket. Boots, mostly. Then purses. Then the rest.", "Moortaucherin Ulla: Ich hol rauf, was aus dem Korb fällt. Meistens Stiefel. Dann Beutel. Dann den Rest."),
                 ("Bog Diver Ulla: Every purse has the Reeve's mark burned in, before the fall. Take one. Show your collector.", "Moortaucherin Ulla: In jeden Beutel ist das Zeichen des Vogts gebrannt, schon vor dem Sturz. Nimm einen. Zeig ihn deinem Sammler.")],
                ("Bog Diver Ulla: The bog breathes in, the bog breathes out. Sometimes it coughs up a dentist.", "Moortaucherin Ulla: Das Moor atmet ein, das Moor atmet aus. Manchmal hustet es einen Zahnarzt hoch."))],
     "betrayer": ("breathing_bog", 10, 3, "left", "villager", "salvager", ("Salvage Man Grubb", "Bergungsmann Grubb"),
                  [("Salvage Man Grubb: Hesk sent you? Hesk sends me too. Hesk sends everyone. Hesk is the Reeve's nephew.", "Bergungsmann Grubb: Hesk schickt dich? Hesk schickt mich auch. Hesk schickt alle. Hesk ist der Neffe des Vogts.")],
                  [("Salvage Man Grubb: Fine. You win. Ask Hesk where the fund sleeps. Under his bed, with him.", "Bergungsmann Grubb: Schön. Du gewinnst. Frag Hesk, wo der Fonds schläft. Unter seinem Bett, mit ihm."),
                   ("Salvage Man Grubb: Nobody fixes the rope, friend. A broken rope is the best job on the moor.", "Bergungsmann Grubb: Keiner repariert das Seil, Freund. Ein kaputtes Seil ist der beste Job im Moor.")],
                  None,
                  ("Salvage Man Grubb: I'm off duty. Fall somewhere else.", "Bergungsmann Grubb: Ich hab frei. Fall woanders hin.")),
     "stages": [("Collector Hesk's Rope Fund is full, but the basket rope is still old. Find out where the money goes.", "Mossgate"),
                ("Nobody ordered a rope. Ask the bog divers what falls from the basket.", "Breathing Bog"),
                ("The fallen carried purses with the Reeve's mark. Tell Hesk.", "Mossgate"),
                ("Beat the Reeve's salvage man on the Breathing Bog.", "Breathing Bog"),
                ("The salvage man works for Hesk. The rope stays old. The fund stays full.", "Mossgate")]},

    {"id": "root_tithe", "turns": False, "road": "wandering_wood", "reward": ("strong_tonic", 3),
     "giver": ("rootchapel", 7, 16, "left", "elder", "wilm"),
     "intro": [("Sexton Wilm: I dig the graves at Rootchapel. Lately I dig them twice: once to fill, once to find them empty.", "Totengräber Wilm: Ich grab die Gräber in Rootchapel. In letzter Zeit grab ich sie zweimal: einmal zum Füllen, einmal, um sie leer zu finden."),
               ("Sexton Wilm: Somebody is taking our dead. Find out who. The dead can't complain, so I complain for them.", "Totengräber Wilm: Jemand holt unsere Toten. Finde heraus, wer. Die Toten können sich nicht beschweren, also beschwer ich mich für sie.")],
     "wait": ("Sexton Wilm: Ada digs on the Wandering Wood. And the choirboy sleeps in the bell cellar. He hears the night.", "Totengräber Wilm: Ada gräbt im Wandernden Wald. Und der Chorjunge schläft im Glockenkeller. Er hört die Nacht."),
     "reveal": [("Sexton Wilm: The curate? Our curate? He blessed my mother.", "Totengräber Wilm: Der Kaplan? Unser Kaplan? Er hat meine Mutter gesegnet."),
                ("Sexton Wilm: And then he sold her to the roots for a quieter congregation. The roots don't cough during sermons.", "Totengräber Wilm: Und dann hat er sie an die Wurzeln verkauft, für eine ruhigere Gemeinde. Wurzeln husten nicht in der Predigt.")],
     "go": ("Sexton Wilm: Anselm is in the vestry, counting. Go and make him lose count.", "Totengräber Wilm: Anselm ist in der Sakristei und zählt. Geh und bring ihn durcheinander."),
     "reward_lines": [("Sexton Wilm: The roots gave back my mother. Most of her. I'll take most. Here, for your trouble.", "Totengräber Wilm: Die Wurzeln haben meine Mutter zurückgegeben. Das meiste von ihr. Ich nehm das meiste. Hier, für deine Mühe.")],
     "after": ("Sexton Wilm: I bury them deeper now. And I bury the shovel with them.", "Totengräber Wilm: Ich vergrabe sie jetzt tiefer. Und die Schaufel gleich mit."),
     "steps": [("wandering_wood", 10, 3, "left", "villager", "ada",
                [("Grave Digger Ada: The roots walk at night. They drag things. Long things. Wrapped things.", "Totengräberin Ada: Die Wurzeln wandern nachts. Sie schleifen Dinge. Lange Dinge. Eingewickelte Dinge."),
                 ("Grave Digger Ada: The tracks all go back to the chapel. Ask the choirboy what he heard.", "Totengräberin Ada: Alle Spuren führen zurück zur Kapelle. Frag den Chorjungen, was er gehört hat.")],
                ("Grave Digger Ada: I sleep with my boots on. Easier to run. Easier to be found.", "Totengräberin Ada: Ich schlaf mit Stiefeln. Leichter zum Weglaufen. Leichter zum Gefundenwerden.")),
               ("rootchapel_bell_cellar", 6, 2, "down", "villager", "oskar",
                [("Choirboy Oskar: At night the curate opens the floor and sings to the roots. They sing back.", "Chorjunge Oskar: Nachts öffnet der Kaplan den Boden und singt für die Wurzeln. Sie singen zurück."),
                 ("Choirboy Oskar: He feeds them the dead. Then he takes a coin from the box for each one. I counted.", "Chorjunge Oskar: Er füttert sie mit den Toten. Dann nimmt er für jeden eine Münze aus dem Opferstock. Ich hab mitgezählt.")],
                ("Choirboy Oskar: Don't tell him I told. He told me the roots like boys best.", "Chorjunge Oskar: Sag ihm nicht, dass ich's verraten hab. Er hat gesagt, die Wurzeln mögen Jungen am liebsten."))],
     "betrayer": ("rootchapel_vestry", 1, 4, "right", "elder", "anselm_roots", ("Curate Anselm", "Kaplan Anselm"),
                  [("Curate Anselm: Wilm sent you. Wilm is next on the list. Don't spoil the order of service.", "Kaplan Anselm: Wilm hat dich geschickt. Wilm ist der Nächste auf der Liste. Bring die Gottesdienstordnung nicht durcheinander.")],
                  [("Curate Anselm: The roots will be hungry. They'll want a sermon. Fine. You give it.", "Kaplan Anselm: Die Wurzeln werden hungrig sein. Sie wollen eine Predigt. Bitte. Halt du sie."),
                   ("Curate Anselm: I kept the collection box. Some things are sacred.", "Kaplan Anselm: Den Opferstock behalte ich. Manche Dinge sind heilig.")],
                  None,
                  ("Curate Anselm: Amen. Now get out of my vestry.", "Kaplan Anselm: Amen. Und jetzt raus aus meiner Sakristei.")),
     "stages": [("Graves in Rootchapel are found empty. Sexton Wilm wants to know who takes the dead.", "Rootchapel"),
                ("The root tracks lead back to the chapel. Ask the choirboy in the bell cellar.", "Rootchapel"),
                ("The curate feeds the dead to the roots. Tell Wilm.", "Rootchapel"),
                ("Beat Curate Anselm in the vestry.", "Rootchapel"),
                ("The roots gave most of them back.", "Rootchapel")]},

    {"id": "lost_pole", "turns": True, "road": "heaving_fields", "reward": ("wake_bell", 2),
     "giver": ("driftwick", 4, 11, "right", "villager", "kari"),
     "intro": [("Kari: My father was Pole Master before Ebbe. He went out on his raft one night and the town drifted on without him.", "Kari: Mein Vater war Stakmeister vor Ebbe. Eines Nachts fuhr er auf seinem Floß hinaus, und die Stadt trieb ohne ihn weiter."),
               ("Kari: Find out what happened to him. I just want to know. Really. Just to know.", "Kari: Finde heraus, was mit ihm passiert ist. Ich will es nur wissen. Wirklich. Nur wissen.")],
     "wait": ("Kari: Old Sten fishes on the Heaving Fields. And Pim in the Chart Room keeps the drift charts. Ask them.", "Kari: Der alte Sten fischt auf den Wogenden Feldern. Und Pim in der Kartenstube führt die Driftkarten. Frag sie."),
     "reveal": [("Kari: The rope was cut, not torn. Yes. I know. I had the knife.", "Kari: Das Seil war geschnitten, nicht gerissen. Ja. Ich weiß. Ich hatte das Messer."),
                ("Kari: The longest pole steers the town. His was longer than mine. Now it's mine and it's the longest.", "Kari: Die längste Stange steuert die Stadt. Seine war länger als meine. Jetzt ist es meine, und sie ist die längste."),
                ("Kari: Ebbe is only keeping the seat warm. And you know too much for a passenger.", "Kari: Ebbe hält den Platz nur warm. Und du weißt zu viel für einen Fahrgast.")],
     "steps": [("heaving_fields", 10, 3, "left", "elder", "sten",
                [("Old Sten: The Pole Master's raft? It came by here empty. The rope was cut clean. Clean as a vote.", "Der alte Sten: Das Floß des Stakmeisters? Kam hier leer vorbei. Das Seil sauber geschnitten. Sauber wie eine Abstimmung."),
                 ("Old Sten: Pim marks every drift in the Chart Room. Ask where the town was that night.", "Der alte Sten: Pim trägt jede Drift in der Kartenstube ein. Frag, wo die Stadt in der Nacht war.")],
                ("Old Sten: The fields heave. The fish don't mind. Fish never vote.", "Der alte Sten: Die Felder wogen. Den Fischen ist das egal. Fische stimmen nie ab.")),
               ("driftwick_chart_room", 6, 2, "down", "villager", "pim",
                [("Chart Boy Pim: That night the town turned hard toward the Raft Rift. Somebody steered.", "Kartenjunge Pim: In der Nacht drehte die Stadt scharf zum Floßriss. Jemand hat gesteuert."),
                 ("Chart Boy Pim: The log says who held the pole. It says 'Kari'. In her own writing. With a little heart.", "Kartenjunge Pim: Im Logbuch steht, wer die Stange hielt. Da steht 'Kari'. In ihrer eigenen Schrift. Mit einem kleinen Herz.")],
                ("Chart Boy Pim: Every chart in here shows a place where somebody wanted something gone.", "Kartenjunge Pim: Jede Karte hier zeigt einen Ort, an dem jemand etwas loswerden wollte."))],
     "betrayer": ("driftwick", 10, 13, "left", "villager", "kari_pole", ("Pole Heir Kari", "Stakerbin Kari"),
                  [("Kari: Passengers who ask questions get off early. Here. In the water.", "Kari: Fahrgäste, die Fragen stellen, steigen früher aus. Hier. Ins Wasser.")],
                  [("Kari: You can keep your raft. I'll keep the pole. Ebbe won't keep his seat long.", "Kari: Dein Floß kannst du behalten. Ich behalte die Stange. Ebbe behält seinen Platz nicht lange."),
                   ("Kari: Father always said I'd go far. We both did.", "Kari: Vater hat immer gesagt, ich komme weit. Wir beide sind weit gekommen.")],
                  [("Kari throws you her father's bells to be rid of you. 'Ring them at the Rift. He never answers.'", "Kari wirft dir die Glocken ihres Vaters hin, um dich loszuwerden. 'Läute sie am Riss. Er antwortet nie.'")],
                  ("Kari: I vote for me. It's unanimous.", "Kari: Ich stimme für mich. Einstimmig.")),
     "stages": [("Kari's father, the old Pole Master, vanished on his raft. Find out what happened.", "Driftwick"),
                ("His rope was cut clean. Ask Pim in the Chart Room where the town was that night.", "Driftwick"),
                ("The log says Kari held the pole. Ask her.", "Driftwick"),
                ("Kari cut her father loose for the pole. Beat her.", "Driftwick"),
                ("Driftwick drifts on. So does Kari.", "Driftwick")]},

    {"id": "pressed_diary", "turns": False, "road": "gloamwater", "reward": ("remedy", 4),
     "giver": ("lastbloom", 7, 16, "left", "elder", "edda"),
     "intro": [("Mourner Edda: My husband Arvid drowned in the Gloamwater. All I have left is his diary, and the presser used the pages for flowers.", "Trauernde Edda: Mein Mann Arvid ist im Dämmerwasser ertrunken. Mir bleibt nur sein Tagebuch, und die Presserin hat die Seiten für Blumen benutzt."),
               ("Mourner Edda: Find the last pages. I want to read his final words about me. They must be lovely.", "Trauernde Edda: Finde die letzten Seiten. Ich will seine letzten Worte über mich lesen. Sie müssen schön sein.")],
     "wait": ("Mourner Edda: The flower children sell pressed blooms on the Gloamwater. And Jory in the Seed Store buys the paper.", "Trauernde Edda: Die Blumenkinder verkaufen gepresste Blüten am Dämmerwasser. Und Jory im Samenlager kauft das Papier."),
     "reveal": [("Mourner Edda: 'Day 1 of freedom. Faked the drowning. The bog keeps secrets, Edda doesn't.'", "Trauernde Edda: 'Tag 1 der Freiheit. Ertrinken vorgetäuscht. Das Moor behält Geheimnisse, Edda nicht.'"),
                ("Mourner Edda: Alive. He is alive and he wrote it down. I wore black for a year. Black does not suit me.", "Trauernde Edda: Lebendig. Er lebt und hat es aufgeschrieben. Ich hab ein Jahr lang Schwarz getragen. Schwarz steht mir nicht."),
                ("Mourner Edda: The last page says where he hides. Bring him to me. Bring him wet.", "Trauernde Edda: Auf der letzten Seite steht, wo er sich versteckt. Bring ihn mir. Bring ihn nass.")],
     "go": ("Mourner Edda: He hides on the Gloamwater, under the name of a dead man. His own.", "Trauernde Edda: Er versteckt sich am Dämmerwasser, unter dem Namen eines Toten. Seinem eigenen."),
     "reward_lines": [("Mourner Edda: He ran again? Of course. He's very fast for a corpse. Take these. I bought them for the wake.", "Trauernde Edda: Er ist wieder weggelaufen? Natürlich. Für eine Leiche ist er sehr schnell. Nimm die. Die hab ich für die Totenwache gekauft.")],
     "after": ("Mourner Edda: I've had the headstone changed. It now says 'Not yet'.", "Trauernde Edda: Ich hab den Grabstein ändern lassen. Jetzt steht da 'Noch nicht'."),
     "steps": [("gloamwater", 10, 3, "left", "villager", "mo",
                [("Flower Child Mo: Pressed blooms, one coin. The paper has writing on it. Writing makes them sell better.", "Blumenkind Mo: Gepresste Blüten, eine Münze. Auf dem Papier steht was. Mit Schrift verkaufen sie sich besser."),
                 ("Flower Child Mo: The last pages went to Jory at the Seed Store. He wraps seeds in them. Very dead seeds.", "Blumenkind Mo: Die letzten Seiten gingen an Jory im Samenlager. Er wickelt Samen darin ein. Sehr tote Samen.")],
                ("Flower Child Mo: This one says 'help'. That's the expensive one.", "Blumenkind Mo: Auf der hier steht 'Hilfe'. Das ist die teure.")),
               ("lastbloom_seed_store", 6, 2, "down", "villager", "jory",
                [("Seed Boy Jory: These pages? The man who sold them was very wet and very cheerful. Odd for a drowned man.", "Samenjunge Jory: Diese Seiten? Der Mann, der sie verkauft hat, war sehr nass und sehr fröhlich. Komisch für einen Ertrunkenen."),
                 ("Seed Boy Jory: Here. Take them to the widow. I'd like to see her face. From very far away.", "Samenjunge Jory: Hier. Bring sie der Witwe. Ich würde gern ihr Gesicht sehen. Von sehr weit weg.")],
                ("Seed Boy Jory: Every seed here has a name. Some of the names are still walking around.", "Samenjunge Jory: Jeder Samen hier hat einen Namen. Manche der Namen laufen noch herum."))],
     "betrayer": ("gloamwater", 2, 17, "right", "villager", "arvid", ("Not-Drowned Arvid", "Nichtertrunkener Arvid"),
                  [("Arvid: Edda sent you? Then you understand why I drowned.", "Arvid: Edda schickt dich? Dann verstehst du, warum ich ertrunken bin.")],
                  [("Arvid: Fine. Tell her you found me. Tell her I wept. I'll be gone by the time she gets here.", "Arvid: Schön. Sag ihr, du hast mich gefunden. Sag ihr, ich hab geweint. Ich bin weg, bevor sie hier ist."),
                   ("Arvid: Next time I drown properly. It's the only way to be sure.", "Arvid: Nächstes Mal ertrinke ich richtig. Nur so ist man sicher.")],
                  None,
                  ("Arvid: Shh. I'm dead. The dead are very quiet.", "Arvid: Pst. Ich bin tot. Tote sind sehr leise.")),
     "stages": [("Mourner Edda wants the last pages of her drowned husband's diary. They were pressed into flowers.", "Lastbloom"),
                ("The last pages went to the Seed Store. Ask Jory.", "Lastbloom"),
                ("Read Edda the last pages.", "Lastbloom"),
                ("Arvid faked his drowning. Find him on the Gloamwater.", "Gloamwater"),
                ("Arvid ran again. The headstone says 'Not yet'.", "Lastbloom")]},

    {"id": "choir_bell", "turns": True, "road": "hymnmarsh", "reward": ("dash_brew", 3),
     "giver": ("tallowmere_choir_dorm", 6, 2, "down", "villager", "liesl"),
     "intro": [("Cantor Liesl: Our silver bell is gone. The choir can't start without it. Well, they can. They just start badly.", "Kantorin Liesl: Unsere Silberglocke ist weg. Ohne sie kann der Chor nicht anfangen. Na ja, er kann. Er fängt nur schlecht an."),
               ("Cantor Liesl: Find it, please. Someone said they heard it ringing out on the Hymnmarsh.", "Kantorin Liesl: Finde sie, bitte. Jemand hat gesagt, er hat sie draußen im Hymnenmoor läuten hören.")],
     "wait": ("Cantor Liesl: The reed cutters on the Hymnmarsh hear everything. And bell buyers sit in Rootchapel.", "Kantorin Liesl: Die Schilfschneider im Hymnenmoor hören alles. Und die Glockenkäufer sitzen in Rootchapel."),
     "reveal": [("Cantor Liesl: The bell buyer in Rootchapel says I sold it? Me? Well. He has a very good memory for a fence.", "Kantorin Liesl: Der Glockenkäufer in Rootchapel sagt, ich hab sie verkauft? Ich? Na ja. Für einen Hehler hat er ein sehr gutes Gedächtnis."),
                ("Cantor Liesl: The choir never gives me a solo. Silver buys solos. Now I sing alone. On the marsh. To the reeds.", "Kantorin Liesl: Der Chor gibt mir nie ein Solo. Silber kauft Soli. Jetzt singe ich allein. Im Moor. Für das Schilf."),
                ("Cantor Liesl: Come and hear it. You won't hear anything after.", "Kantorin Liesl: Komm und hör zu. Danach hörst du nichts mehr.")],
     "steps": [("hymnmarsh", 10, 3, "left", "villager", "bo",
                [("Reed Cutter Bo: A silver bell? It rings out here at dusk. Always the same three notes. Badly.", "Schilfschneider Bo: Eine Silberglocke? Die läutet hier in der Dämmerung. Immer dieselben drei Töne. Schlecht."),
                 ("Reed Cutter Bo: Gunne in Rootchapel buys anything that rings. Ask him who sold it.", "Schilfschneider Bo: Gunne in Rootchapel kauft alles, was klingt. Frag ihn, wer sie verkauft hat.")],
                ("Reed Cutter Bo: The reeds hum the hymns back. They're better at it than the choir.", "Schilfschneider Bo: Das Schilf summt die Hymnen nach. Es kann das besser als der Chor.")),
               ("rootchapel", 4, 11, "right", "villager", "gunne",
                [("Bell Buyer Gunne: The silver one? A lady sold it. Choir robe, nice voice, terrible haggler.", "Glockenkäufer Gunne: Die silberne? Eine Dame hat sie verkauft. Chorgewand, schöne Stimme, miserable Feilscherin."),
                 ("Bell Buyer Gunne: She bought it back the next day. For twice as much. Then she rang it on the marsh.", "Glockenkäufer Gunne: Am nächsten Tag hat sie sie zurückgekauft. Für das Doppelte. Dann hat sie sie im Moor geläutet.")],
                ("Bell Buyer Gunne: I sell bells to people who need to be found. And to people who don't want to be.", "Glockenkäufer Gunne: Ich verkaufe Glocken an Leute, die gefunden werden müssen. Und an Leute, die das nicht wollen."))],
     "betrayer": ("hymnmarsh", 2, 17, "right", "villager", "liesl_solo", ("Cantor Liesl", "Kantorin Liesl"),
                  [("Liesl: At last, an audience. Stand very still. This is the high part.", "Liesl: Endlich ein Publikum. Steh ganz still. Jetzt kommt die hohe Stelle.")],
                  [("Liesl: You interrupted my solo. Nobody interrupts my solo. Nobody ever stays for it, either.", "Liesl: Du hast mein Solo unterbrochen. Keiner unterbricht mein Solo. Es bleibt aber auch nie jemand bis zum Ende."),
                   ("Liesl: Take the bell. The choir can have it back. They won't sound any better.", "Liesl: Nimm die Glocke. Der Chor kann sie zurückhaben. Besser klingen wird er trotzdem nicht.")],
                  [("You take the silver bell, and the three brews Liesl kept for her voice. Her voice won't miss them.", "Du nimmst die Silberglocke und die drei Tränke, die Liesl für ihre Stimme aufgehoben hat. Ihre Stimme wird sie nicht vermissen.")],
                  ("Liesl: La. La. Laaa. Still better than the altos.", "Liesl: La. La. Laaa. Immer noch besser als die Altstimmen.")),
     "stages": [("The Tallowmere choir's silver bell is gone. Someone heard it on the Hymnmarsh.", "Tallowmere / Hymnmarsh"),
                ("Gunne in Rootchapel buys anything that rings. Ask who sold the bell.", "Rootchapel"),
                ("A lady in a choir robe sold it. Ask Liesl.", "Tallowmere"),
                ("Liesl sings her stolen solo on the Hymnmarsh. Stop her.", "Hymnmarsh"),
                ("The bell is back. The choir still sings badly.", "Tallowmere")]},

    {"id": "nell_letters", "turns": False, "road": "candle_causeway", "reward": ("guard_brew", 3),
     "giver": ("mossgate", 7, 16, "left", "villager", "tam"),
     "intro": [("Tam Tallis: I'm Nell's brother. She left letters for me before she went pilot. I never got them.", "Tam Tallis: Ich bin Nells Bruder. Sie hat Briefe für mich hinterlassen, bevor sie Lotsin wurde. Ich hab sie nie bekommen."),
               ("Tam Tallis: Find them? I want to understand her. Family is all we have down here. That and bog.", "Tam Tallis: Findest du sie? Ich will sie verstehen. Familie ist alles, was wir hier unten haben. Das und Moor.")],
     "wait": ("Tam Tallis: Runa at the Moss Inn kept Nell's room. And a burned pilot in the Wick Rift knew her.", "Tam Tallis: Runa im Mooswirtshaus hat Nells Zimmer aufbewahrt. Und ein verbrannter Lotse im Dochtriss kannte sie."),
     "reveal": [("Tam Tallis: Thank you. Every letter. Every place she hides, every friend, every name.", "Tam Tallis: Danke. Jeder Brief. Jedes Versteck, jeder Freund, jeder Name."),
                ("Tam Tallis: The Wardens pay well for pilots who know the moving paths. They pay better for their families.", "Tam Tallis: Die Wardens zahlen gut für Lotsen, die die wandernden Wege kennen. Für ihre Familien zahlen sie besser."),
                ("Tam Tallis: Don't look like that. She sold you first. I'm only catching up.", "Tam Tallis: Schau nicht so. Sie hat dich zuerst verkauft. Ich hole nur auf.")],
     "go": ("Tam Tallis: My buyer waits on the Candle Causeway. Wave if you pass. Or don't.", "Tam Tallis: Mein Käufer wartet auf dem Kerzendamm. Wink, wenn du vorbeikommst. Oder lass es."),
     "reward_lines": [("Tam Tallis: You beat my buyer? Now I have letters and no customer. Here. Keep the change. Keep the letters too.", "Tam Tallis: Du hast meinen Käufer geschlagen? Jetzt hab ich Briefe und keinen Kunden. Hier. Behalt das Wechselgeld. Behalt die Briefe auch.")],
     "after": ("Tam Tallis: Nell and I write again. Short letters. Mostly threats.", "Tam Tallis: Nell und ich schreiben uns wieder. Kurze Briefe. Meistens Drohungen."),
     "steps": [("mossgate_moss_inn", 6, 2, "down", "villager", "runa",
                [("Runa: Nell's room? I kept it. She never paid, so it's still technically hers.", "Runa: Nells Zimmer? Hab ich behalten. Sie hat nie bezahlt, also gehört es technisch noch ihr."),
                 ("Runa: Here are the letters she left under the moss. The rest she gave to a pilot who went into the Wick Rift.", "Runa: Hier sind die Briefe, die sie unter dem Moos gelassen hat. Den Rest hat sie einem Lotsen gegeben, der in den Dochtriss ging.")],
                ("Runa: The moss in her bed grew into the shape of her. Then it walked out without paying, too.", "Runa: Das Moos in ihrem Bett ist in ihre Form gewachsen. Dann ist es auch ohne Bezahlen gegangen.")),
               ("wick_rift", 2, 13, "right", "elder", "ivar",
                [("Burned Pilot Ivar: Nell's letters? I kept them dry. Fire is drier than water, mostly.", "Verbrannter Lotse Ivar: Nells Briefe? Ich hab sie trocken gehalten. Feuer ist meistens trockener als Wasser."),
                 ("Burned Pilot Ivar: Give them to Tam? Tam. Hm. Well. He's family. Family always wants to know where you sleep.", "Verbrannter Lotse Ivar: Sie Tam geben? Tam. Hm. Na gut. Er ist Familie. Familie will immer wissen, wo man schläft.")],
                ("Burned Pilot Ivar: Maudrey lit me once. I went out on purpose. She never forgave that.", "Verbrannter Lotse Ivar: Maudrey hat mich einmal angezündet. Ich bin mit Absicht ausgegangen. Das hat sie mir nie verziehen."))],
     "betrayer": ("candle_causeway", 2, 17, "right", "warden", "warden_buyer", ("Warden Buyer Selk", "Wardenkäufer Selk"),
                  [("Selk: The letters are paid for. You're not. Let's settle that.", "Selk: Die Briefe sind bezahlt. Du nicht. Regeln wir das.")],
                  [("Selk: The Wardens will be cross. I'll tell them Tam sold me a fake. He'll love that.", "Selk: Die Wardens werden sauer sein. Ich sag ihnen, Tam hat mir eine Fälschung verkauft. Das wird ihm gefallen."),
                   ("Selk: Everyone on this moor sells someone. You just haven't been offered enough.", "Selk: Jeder in diesem Moor verkauft jemanden. Dir hat man nur noch nicht genug geboten.")],
                  None,
                  ("Selk: I buy and sell. Mostly sell. Mostly people.", "Selk: Ich kaufe und verkaufe. Meistens verkaufe ich. Meistens Leute.")),
     "stages": [("Tam Tallis wants the letters his sister Nell left behind.", "Mossgate"),
                ("Runa gave the rest of the letters to a pilot in the Wick Rift. Find him.", "Wick Rift"),
                ("Bring Nell's letters to Tam.", "Mossgate"),
                ("Tam sold the letters to the Wardens. Beat his buyer on the Candle Causeway.", "Candle Causeway"),
                ("Nell and Tam write again. Mostly threats.", "Mossgate")]},

    {"id": "named_seed", "turns": True, "road": "heaving_fields", "reward": ("revival_leaf", 3),
     "giver": ("lastbloom", 4, 11, "right", "elder", "fenja"),
     "intro": [("Gardener Fenja: Every seed in Lastbloom has a name tag. My daughter Wynn's seed is missing. Hale won't say where it went.", "Gärtnerin Fenja: Jeder Samen in Lastbloom hat ein Namensschild. Der Samen meiner Tochter Wynn fehlt. Hale sagt nicht, wohin er ist."),
               ("Gardener Fenja: Find her seed. Find out who planted it. A mother has a right to know who to thank.", "Gärtnerin Fenja: Finde ihren Samen. Finde heraus, wer ihn gepflanzt hat. Eine Mutter hat ein Recht zu wissen, wem sie danken muss.")],
     "wait": ("Gardener Fenja: The net mender's boy in Driftwick trades in seeds. And the pickers work deep in the Bloom Rift.", "Gärtnerin Fenja: Der Junge der Netzflickerin in Driftwick handelt mit Samen. Und die Pflücker arbeiten tief im Blütenriss."),
     "reveal": [("Gardener Fenja: The picker says the tag was in my writing? Of course it was. I write all the tags.", "Gärtnerin Fenja: Der Pflücker sagt, das Schild war in meiner Schrift? Natürlich. Ich schreibe alle Schilder."),
                ("Gardener Fenja: A planted child pays the bloom in years. Her years. My garden. The best roses in Quivermoor.", "Gärtnerin Fenja: Ein gepflanztes Kind bezahlt die Blüte in Jahren. Ihre Jahre. Mein Garten. Die besten Rosen in Quivermoor."),
                ("Gardener Fenja: I asked you to find who to thank. Thank you. Now hold still. You have lovely years.", "Gärtnerin Fenja: Ich hab dich gebeten herauszufinden, wem ich danken muss. Danke. Jetzt halt still. Du hast schöne Jahre.")],
     "steps": [("driftwick_net_shed", 6, 2, "down", "villager", "kell",
                [("Kell: Named seeds? I net the ones that float off the Bloom Rift. This one says 'Wynn'. It's warm.", "Kell: Samen mit Namen? Ich fang die mit dem Netz, die aus dem Blütenriss treiben. Auf dem hier steht 'Wynn'. Er ist warm."),
                 ("Kell: It sprouted already, then got pulled up. The pickers in the Rift know who planted it.", "Kell: Er ist schon gekeimt und wurde dann rausgerissen. Die Pflücker im Riss wissen, wer ihn gepflanzt hat.")],
                ("Kell: Mum says don't net anything that whispers. I net it anyway. It pays.", "Kell: Mama sagt, ich soll nichts fangen, was flüstert. Ich fang es trotzdem. Es bringt Geld.")),
               ("bloom_rift", 2, 13, "right", "elder", "sol",
                [("Withered Picker Sol: Wynn's bloom? I picked it. White, with a girl's laugh inside. Sabeline wanted it.", "Welker Pflücker Sol: Wynns Blüte? Hab ich gepflückt. Weiß, mit einem Mädchenlachen darin. Sabeline wollte sie."),
                 ("Withered Picker Sol: The planting tag was in the gardener's hand. Same hand as all the tags. Mothers plant deepest.", "Welker Pflücker Sol: Das Pflanzschild war in der Schrift der Gärtnerin. Dieselbe Schrift wie auf allen Schildern. Mütter pflanzen am tiefsten.")],
                ("Withered Picker Sol: I was twenty last spring. The bloom took the rest on credit.", "Welker Pflücker Sol: Letzten Frühling war ich zwanzig. Den Rest hat die Blüte auf Pump genommen."))],
     "betrayer": ("bloom_rift", 7, 8, "left", "elder", "fenja_bloom", ("Gardener Fenja", "Gärtnerin Fenja"),
                  [("Fenja: The bloom is hungry and you are standing in my bed.", "Fenja: Die Blüte hat Hunger, und du stehst in meinem Beet.")],
                  [("Fenja: Uprooted. By a stranger. Wynn would have laughed. She always laughed.", "Fenja: Ausgerissen. Von einer Fremden. Wynn hätte gelacht. Sie hat immer gelacht."),
                   ("Fenja: Take her tag. Keep it watered. It's all that's left to water.", "Fenja: Nimm ihr Schild. Gieß es. Es ist das Einzige, was zu gießen bleibt.")],
                  [("You take Wynn's tag from Fenja's apron, and the revival leaves she grew in her daughter's year.", "Du nimmst Wynns Schild aus Fenjas Schürze und die Lebensblätter, die sie in den Jahren ihrer Tochter gezogen hat.")],
                  ("Fenja: The roses are very red this year. I wonder why.", "Fenja: Die Rosen sind dieses Jahr sehr rot. Ich frag mich, warum.")),
     "stages": [("Gardener Fenja's daughter has a named seed that has gone missing. Find out who planted it.", "Lastbloom"),
                ("The seed sprouted in the Bloom Rift. Ask the pickers there.", "Bloom Rift"),
                ("The planting tag was in Fenja's hand. Ask her.", "Lastbloom"),
                ("Fenja planted her own daughter for the bloom. Find her in the Bloom Rift.", "Bloom Rift"),
                ("Wynn's tag is all that is left to water.", "Lastbloom")]},
]


def flag(g, step):
    return "q5_%s_%s" % (g["id"], step)


def betrayer_team(q, road, offset):
    """Three kinds of [road] (sheet slots and fill-ins) at ring top -1, top, top +1, within three elements."""
    r = q.ROUTES[road]
    hi = r["ring"][1]
    kinds = [q.slot_species(s) for s in r["slots"]] + [sp for sp, _ in q.FILL[road]]
    kinds = kinds[offset % len(kinds):] + kinds[:offset % len(kinds)]
    for pick in itertools.combinations(kinds, 3):
        els = set()
        for sp in pick:
            els.update(q.SPECIES[sp]["elements"])
        if len(els) <= 3:
            return q.check_team(road, [{"species": sp, "level": hi - 1 + i} for i, sp in enumerate(pick)]), hi + 1
    raise SystemExit("%s: no three kinds within three elements" % road)


def place(q, mid, n):
    q.MAPS[mid]["npcs"].append(n)


def build(q):
    goals = []
    for i, g in enumerate(GOALS):
        gid = g["id"]
        asked, s1, s2, reveal, done, paid = (flag(g, s) for s in ("asked", "s1", "s2", "reveal", "done", "paid"))
        k = "q5_" + gid
        reward = "set_flag %s; give_item %s %d; quest_stage %s 4" % (paid, g["reward"][0], g["reward"][1], k)
        # Giver: a chain of "if"s, last state first.
        gm, gx, gy, gf, gs, gname = g["giver"]
        q.text(k + "_wait", q.lines(g["wait"]))
        q.text(k + "_reveal", {"if": {"flag": s2}, "else": k + "_wait", "lines": q.lines(*g["reveal"]),
                               "action": "set_flag %s; quest_stage %s 3" % (reveal, k)})
        nxt = k + "_reveal"
        if not g["turns"]:
            q.text(k + "_go", {"if": {"flag": reveal}, "else": nxt, "lines": q.lines(g["go"])})
            q.text(k + "_reward", {"if": {"flag": done}, "else": k + "_go", "lines": q.lines(*g["reward_lines"]), "action": reward})
            q.text(k + "_after", {"if": {"flag": paid}, "else": k + "_reward", "lines": q.lines(g["after"])})
            nxt = k + "_after"
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
        crew, ring = betrayer_team(q, g["road"], i)
        if g["turns"]:
            q.text("%s_%s_after" % (k, bid), q.lines(after))
            talk = q.text("%s_%s" % (k, bid), {"if": {"not_flag": paid}, "else": "%s_%s_after" % (k, bid), "lines": q.lines(*loot), "action": reward})
        else:
            talk = q.text("%s_%s" % (k, bid), q.lines(after))
        place(q, bm, q.npc("%s_%s" % (k, bid), bx, by, bf, talk, bs, trainer=q.tr(*title), show_flag=reveal,
                           intro=q.text("%s_%s_intro" % (k, bid), q.lines(*intro)),
                           defeat=q.text("%s_%s_defeat" % (k, bid), q.lines(*defeat)),
                           money=ring * 50, team=crew, win_flags=[done], no_rematch=True))
        stages = [{"text": q.tr(*t) if isinstance(t, tuple) else t, "where": w} for t, w in
                  ((STAGE_DE[gid][j], w) for j, (_, w) in enumerate(g["stages"]))]
        for st in stages:
            if "/" in st["where"]:
                q.tr(st["where"], WHERE_DE[st["where"]])
        goals.append({"id": k, "text": stages[0]["text"], "where": g["stages"][0][1], "show": asked, "done": done,
                      "progress": [s1, s2, reveal, done], "stages": stages})
    patch_quests(q.ROOT, goals)
    return goals


WHERE_DE = {"Tallowmere / Hymnmarsh": "Tallowmere / Hymnenmoor"}

# German for the stage texts, by goal (same order as "stages").
STAGE_DE = {}


def _stage_pairs():
    de = {
        "short_candle": ["Der Sohn von Witwe Aud hat eine gekürzte Kerze in der Halle der Namen. Finde heraus, wer sie geschnitten hat.",
                         "Die Kürzungsaufträge liegen in der Halle der Namen. Frag den Bücherjungen.",
                         "Der Auftrag ist von Aud selbst unterschrieben. Frag sie, warum.",
                         "Aud hat eine Kerze mit deinem Namen angezündet. Blas sie aus.",
                         "Ihr Junge ist entkommen. Du hast die Quittung."],
        "rope_fund": ["Sammler Hesks Seilfonds ist voll, aber das Korbseil ist immer noch alt. Finde heraus, wohin das Geld geht.",
                      "Keiner hat ein Seil bestellt. Frag die Moortaucher, was aus dem Korb fällt.",
                      "Die Gestürzten trugen Beutel mit dem Zeichen des Vogts. Sag es Hesk.",
                      "Schlag den Bergungsmann des Vogts im Atmenden Moor.",
                      "Der Bergungsmann arbeitet für Hesk. Das Seil bleibt alt. Der Fonds bleibt voll."],
        "root_tithe": ["In Rootchapel werden Gräber leer gefunden. Totengräber Wilm will wissen, wer die Toten holt.",
                       "Die Wurzelspuren führen zurück zur Kapelle. Frag den Chorjungen im Glockenkeller.",
                       "Der Kaplan verfüttert die Toten an die Wurzeln. Sag es Wilm.",
                       "Schlag Kaplan Anselm in der Sakristei.",
                       "Die Wurzeln haben die meisten zurückgegeben."],
        "lost_pole": ["Karis Vater, der alte Stakmeister, ist auf seinem Floß verschwunden. Finde heraus, was passiert ist.",
                      "Sein Seil war sauber geschnitten. Frag Pim in der Kartenstube, wo die Stadt in der Nacht war.",
                      "Im Logbuch steht, dass Kari die Stange hielt. Frag sie.",
                      "Kari hat ihren Vater für die Stange losgeschnitten. Schlag sie.",
                      "Driftwick treibt weiter. Kari auch."],
        "pressed_diary": ["Die trauernde Edda will die letzten Seiten aus dem Tagebuch ihres ertrunkenen Mannes. Sie wurden zu Blumen gepresst.",
                          "Die letzten Seiten gingen ins Samenlager. Frag Jory.",
                          "Lies Edda die letzten Seiten vor.",
                          "Arvid hat sein Ertrinken vorgetäuscht. Finde ihn am Dämmerwasser.",
                          "Arvid ist wieder weggelaufen. Auf dem Grabstein steht 'Noch nicht'."],
        "choir_bell": ["Die Silberglocke des Chors von Tallowmere ist weg. Jemand hat sie im Hymnenmoor gehört.",
                       "Gunne in Rootchapel kauft alles, was klingt. Frag, wer die Glocke verkauft hat.",
                       "Eine Dame im Chorgewand hat sie verkauft. Frag Liesl.",
                       "Liesl singt ihr gestohlenes Solo im Hymnenmoor. Halt sie auf.",
                       "Die Glocke ist zurück. Der Chor singt immer noch schlecht."],
        "nell_letters": ["Tam Tallis will die Briefe, die seine Schwester Nell zurückgelassen hat.",
                         "Runa hat den Rest der Briefe einem Lotsen im Dochtriss gegeben. Finde ihn.",
                         "Bring Nells Briefe zu Tam.",
                         "Tam hat die Briefe an die Wardens verkauft. Schlag seinen Käufer auf dem Kerzendamm.",
                         "Nell und Tam schreiben sich wieder. Meistens Drohungen."],
        "named_seed": ["Der Samen mit dem Namen der Tochter von Gärtnerin Fenja ist verschwunden. Finde heraus, wer ihn gepflanzt hat.",
                       "Der Samen ist im Blütenriss gekeimt. Frag die Pflücker dort.",
                       "Das Pflanzschild war in Fenjas Schrift. Frag sie.",
                       "Fenja hat ihre eigene Tochter für die Blüte gepflanzt. Finde sie im Blütenriss.",
                       "Wynns Schild ist das Einzige, was zu gießen bleibt."],
    }
    for g in GOALS:
        STAGE_DE[g["id"]] = [(en, d) for (en, _), d in zip(g["stages"], de[g["id"]])]


_stage_pairs()


def patch_quests(root, goals):
    """Replaces the q5_* side goals in data/quests.json (one goal per line, like the rest)."""
    path = os.path.join(root, "data", "quests.json")
    rows = open(path, encoding="utf-8").read().split("\n")
    rows = [r for r in rows if '{"id": "q5_' not in r]
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
