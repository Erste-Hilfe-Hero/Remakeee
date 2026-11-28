"""Vellmarch side goals: twelve errands between the House and the Syndicate, each one ending in a
betrayal. Called by tools/art/world/vellmarch.py (run that, not this file). It adds three places
under the roads (Smugglers' Culvert, Slag Tunnels, Bell Crypt) with their Wayfarers and finds, one
more Wayfarer on every road, puts the goals' figures on the region's maps, writes their texts into
data/dialogue/vellmarch.json, the goals into data/quests.json (ids q2_*) and the story duels into
data/story_battles.json (ids q2_*).

Every goal runs the same way, with its own flags q2_<id>_<step>:
  giver      asked    sets the goal going
  step 1     s1       shows once asked
  step 2     s2       shows once s1 is set; a step with a "duel" is a story duel that sets it
  giver      reveal   back at the giver: the truth comes out; some givers ask whether you
                      believe them (flags trust / doubt), which changes what they pay
  betrayer   done     shows once reveal is set; beating them sets done (win_flags)
  reward     paid     the giver pays, or, when the giver was the betrayer, you take it off them
Progress counts s1, s2, reveal and done; the stages follow with "quest_stage".

Nobody here has a fixed cell: free_cell() picks a free, open cell of the map as it is built, so a
new town layout or a new figure in vellmarch.py moves these figures instead of breaking them.
Teams come from the road a figure belongs to: kinds of that road within three elements, rings
from the road's own range (Wayfarers lo..hi, betrayers hi -1, hi, hi +1).
"""
import itertools
import json
import os
import zlib

# --- The three places under the roads -------------------------------------------------------
# id -> (road, name, backdrop, rows, sign). Stairs "=" lead back up to the road.
PLACES = {
    "smugglers_culvert": ("weeping_locks", ("Smugglers' Culvert", "Schmugglerkanal"), "lake",
                          ["^^^^^^^^^^^^",
                           "^....^^....^",
                           "^.|..^^..|.^",
                           "^..........^",
                           "^^^^..^^^^.^",
                           "^~~^..^~~^.^",
                           "^~~^..^~~^.^",
                           "^..........^",
                           "^.^^^^^^^^.^",
                           "^..........^",
                           "^.|......|.^",
                           "^^^^..^^^^^^",
                           "^..........^",
                           "^..~~~~~~..^",
                           "^..........^",
                           "^^^^^..^^^^^",
                           "^....=...S.^",
                           "^^^^^^^^^^^^"],
                          ("A brick drain under the locks. Everything the canal loses turns up here, with a price tag.",
                           "Ein gemauerter Abfluss unter den Schleusen. Alles, was der Kanal verliert, taucht hier auf, mit Preisschild.")),
    "slag_tunnels": ("smelters_drift", ("Slag Tunnels", "Schlackenstollen"), "ember",
                     ["^^^^^^^^^^^^",
                      "^..^^^^^^..^",
                      "^..........^",
                      "^..^^^^^^..^",
                      "^..^....^..^",
                      "^.........^^",
                      "^^^^.||.^^^^",
                      "^..........^",
                      "^.^^....^^.^",
                      "^.^^....^^.^",
                      "^..........^",
                      "^^^..^^^^..^",
                      "^....^^....^",
                      "^.|......|.^",
                      "^..........^",
                      "^^^^^..^^^^^",
                      "^....=...S.^",
                      "^^^^^^^^^^^^"],
                     ("Cart tunnels under the drift. The foundry sends down what it does not want counted.",
                      "Karrenstollen unter der Halde. Die Gießerei schickt hinunter, was nicht gezählt werden soll.")),
    "bell_crypt": ("bellrope_marsh", ("Bell Crypt", "Glockengruft"), "ridge",
                   ["^^^^^^^^^^^^",
                    "^....||....^",
                    "^..........^",
                    "^.^^....^^.^",
                    "^.^^....^^.^",
                    "^..........^",
                    "^^^^^..^^^^^",
                    "^~~......~~^",
                    "^~~.^^^^.~~^",
                    "^...^^^^...^",
                    "^..........^",
                    "^.|..^^..|.^",
                    "^....^^....^",
                    "^..........^",
                    "^.^^^..^^^.^",
                    "^^^^^..^^^^^",
                    "^....=...S.^",
                    "^^^^^^^^^^^^"],
                   ("The marsh took the chapel and kept the cellar. The bell ropes still hang down through the roof.",
                    "Das Moor hat die Kapelle genommen und den Keller behalten. Die Glockenseile hängen noch durchs Dach.")),
}
ROAD_STAIRS = (1, 4)       # the cell on the road that becomes the stairs down
ROAD_LANDING = (2, 4)
PLACE_STAIRS = (5, 16)
PLACE_LANDING = (5, 15)
PLACE_SIGN = (9, 16)
# Finds sit in the wall beside an open cell, like the finds in the road hedges.
PLACE_FINDS = {"smugglers_culvert": [(0, 2, "strong_tonic"), (11, 7, "remedy"), (0, 10, "revival_leaf"), (11, 13, "max_tonic")],
               "slag_tunnels": [(0, 4, "strong_tonic"), (11, 7, "remedy"), (0, 10, "revival_leaf"), (11, 13, "max_tonic")],
               "bell_crypt": [(0, 2, "strong_tonic"), (11, 5, "remedy"), (0, 13, "revival_leaf"), (11, 10, "max_tonic")]}

# Wayfarers down there: (place, x, y, facing, sprite, id, title, talk, intro, defeat).
PLACE_WAYFARERS = [
    ("smugglers_culvert", 2, 3, "right", "villager", "bilge_boy", ("Bilge Boy Arne", "Bilgenjunge Arne"),
     ("Arne: I bail the culvert. It fills again. It's the steadiest job in Vellmarch.", "Arne: Ich schöpfe den Kanal leer. Er läuft wieder voll. Die sicherste Arbeit in Vellmarch."),
     ("Arne: You're dry. Nobody down here is dry. Suspicious.", "Arne: Du bist trocken. Hier unten ist keiner trocken. Verdächtig."),
     ("Arne: Soaked again. At least that's honest work.", "Arne: Wieder nass. Wenigstens ehrliche Arbeit.")),
    ("smugglers_culvert", 9, 9, "left", "ranger", "crate_runner", ("Crate Runner Isolde", "Kistenläuferin Isolde"),
     ("Isolde: These crates are empty. Write that down. The heavy ones are extra empty.", "Isolde: Diese Kisten sind leer. Schreib das auf. Die schweren sind besonders leer."),
     ("Isolde: You saw the crates. Now you carry one or you carry bruises.", "Isolde: Du hast die Kisten gesehen. Jetzt trägst du eine oder blaue Flecken."),
     ("Isolde: Fine. You saw nothing. I'll even pay you to have seen it.", "Isolde: Schön. Du hast nichts gesehen. Ich zahl dir sogar dafür, dass du es gesehen hast.")),
    ("smugglers_culvert", 2, 12, "right", "elder", "tide_clerk", ("Tide Clerk Bodo", "Flutschreiber Bodo"),
     ("Bodo: I keep the Syndicate's books down here. Damp books. The numbers run.", "Bodo: Ich führe hier unten die Bücher des Syndikats. Feuchte Bücher. Die Zahlen verlaufen."),
     ("Bodo: An audit? Down here we settle audits by hand.", "Bodo: Eine Prüfung? Hier unten regeln wir Prüfungen von Hand."),
     ("Bodo: Balanced. I'll enter you under 'losses'.", "Bodo: Ausgeglichen. Ich trag dich unter 'Verluste' ein.")),
    ("slag_tunnels", 1, 2, "right", "villager", "cart_pusher", ("Cart Pusher Grim", "Karrenschieber Grim"),
     ("Grim: I push the cart down full and pull it up empty. Nobody asks what was in it. Good job, that.", "Grim: Ich schiebe den Karren voll runter und zieh ihn leer rauf. Keiner fragt, was drin war. Gute Arbeit."),
     ("Grim: Mind the cart. It doesn't mind you.", "Grim: Pass auf den Karren auf. Er passt nicht auf dich auf."),
     ("Grim: Tipped over. Like the last foreman.", "Grim: Umgekippt. Wie der letzte Vorarbeiter.")),
    ("slag_tunnels", 9, 7, "left", "elder", "ash_sifter", ("Ash Sifter Malve", "Aschesieberin Malve"),
     ("Malve: I sift the ash for buttons. A button means a man. I have a jar of men.", "Malve: Ich siebe die Asche nach Knöpfen. Ein Knopf heißt ein Mann. Ich hab ein Glas voller Männer."),
     ("Malve: Nice buttons on that coat. Let's see how they sift.", "Malve: Schöne Knöpfe an dem Mantel. Mal sehen, wie sie sich sieben."),
     ("Malve: Keep your buttons. For now. Everyone comes through the sieve.", "Malve: Behalt deine Knöpfe. Vorerst. Durchs Sieb kommt jeder.")),
    ("slag_tunnels", 2, 12, "right", "warden", "furnace_guard", ("Furnace Guard Detlef", "Ofenwache Detlef"),
     ("Detlef: Brannoc pays me to guard the tunnel. The Syndicate pays me to look the other way. I squint.", "Detlef: Brannoc bezahlt mich, damit ich den Stollen bewache. Das Syndikat, damit ich wegschaue. Ich schiele."),
     ("Detlef: Halt. One of my employers wants you stopped. I forget which.", "Detlef: Halt. Einer meiner Auftraggeber will, dass ich dich aufhalte. Ich weiß nicht mehr, welcher."),
     ("Detlef: I'll report I stopped you. Twice. That's two wages.", "Detlef: Ich melde, dass ich dich aufgehalten hab. Zweimal. Das sind zwei Löhne.")),
    ("bell_crypt", 2, 2, "right", "elder", "rope_warden", ("Rope Warden Hilde", "Seilwartin Hilde"),
     ("Hilde: Forty ropes hang down here. I know every one by its pull. Three of them pull back.", "Hilde: Vierzig Seile hängen hier herunter. Ich kenne jedes am Zug. Drei ziehen zurück."),
     ("Hilde: Don't touch the ropes. Touch me instead, see what happens.", "Hilde: Fass die Seile nicht an. Fass lieber mich an und schau, was passiert."),
     ("Hilde: Rung like a bell. I'll be humming for a week.", "Hilde: Geläutet wie eine Glocke. Ich summe noch eine Woche.")),
    ("bell_crypt", 9, 5, "left", "villager", "candle_thief", ("Candle Thief Jost", "Kerzendieb Jost"),
     ("Jost: I take the grave candles back to Tallowmarket. They sell them again. Very thrifty, the dead.", "Jost: Ich bring die Grabkerzen zurück nach Tallowmarket. Die verkaufen sie nochmal. Sehr sparsam, die Toten."),
     ("Jost: You didn't see me. I'll make sure of it.", "Jost: Du hast mich nicht gesehen. Dafür sorg ich jetzt."),
     ("Jost: Caught. Take a candle. It's only slightly used.", "Jost: Erwischt. Nimm eine Kerze. Sie ist nur ein bisschen gebraucht.")),
    ("bell_crypt", 2, 13, "right", "ranger", "marsh_guide", ("Marsh Guide Runhild", "Moorführerin Runhild"),
     ("Runhild: I guide people through the marsh. Half fare in advance. I've never had to collect the second half.", "Runhild: Ich führe Leute durchs Moor. Die Hälfte im Voraus. Die zweite Hälfte musste ich noch nie kassieren."),
     ("Runhild: Lost? Good. Lost people pay best.", "Runhild: Verirrt? Gut. Verirrte zahlen am besten."),
     ("Runhild: The way out is up the stairs. That advice is free. My first.", "Runhild: Raus geht es die Treppe hoch. Der Rat ist umsonst. Mein erster.")),
]

# One more Wayfarer per road: road -> (sprite, id, title, talk, intro, defeat).
ROAD_WAYFARERS = {
    "tollchain_causeway": ("ranger", "chain_inspector", ("Chain Inspector Lorenz", "Ketteninspektor Lorenz"),
                           ("Lorenz: I inspect the toll chain. Every link is a family that couldn't pay. It's a long chain.", "Lorenz: Ich prüfe die Zollkette. Jedes Glied ist eine Familie, die nicht zahlen konnte. Eine lange Kette."),
                           ("Lorenz: Your papers. No papers? Then your Spirlings will do.", "Lorenz: Deine Papiere. Keine Papiere? Dann tun es auch deine Spirlings."),
                           ("Lorenz: In order. I'll stamp your forehead. No? Suit yourself.", "Lorenz: In Ordnung. Ich stemple deine Stirn. Nein? Wie du willst.")),
    "rookery_cut": ("villager", "letter_thief", ("Letter Thief Agathe", "Briefdiebin Agathe"),
                    ("Agathe: I steal letters from the crows. Then I sell them to whoever they're about. Everyone buys.", "Agathe: Ich klaue den Krähen die Briefe. Dann verkauf ich sie an den, um den es geht. Jeder kauft."),
                    ("Agathe: There's a letter about you. Win and you can read it.", "Agathe: Es gibt einen Brief über dich. Gewinn, dann darfst du ihn lesen."),
                    ("Agathe: Here. It says you'd win. I should read them first.", "Agathe: Hier. Da steht, dass du gewinnst. Ich sollte sie vorher lesen.")),
    "weeping_locks": ("elder", "lock_gambler", ("Lock Gambler Ewald", "Schleusenspieler Ewald"),
                      ("Ewald: I bet on which lock floods next. I lost the house. Then I bet on the house.", "Ewald: Ich wette, welche Schleuse als Nächste überläuft. Ich hab das Haus verloren. Dann hab ich aufs Haus gewettet."),
                      ("Ewald: Double or nothing. You're the nothing.", "Ewald: Doppelt oder nichts. Du bist das Nichts."),
                      ("Ewald: Nothing it is. I'm used to it.", "Ewald: Also nichts. Bin ich gewohnt.")),
    "smelters_drift": ("warden", "strike_breaker", ("Strike Breaker Kuno", "Streikbrecher Kuno"),
                       ("Kuno: The foundry men wanted shorter days. I gave three of them very short ones.", "Kuno: Die Gießer wollten kürzere Tage. Dreien hab ich sehr kurze verschafft."),
                       ("Kuno: You look like a complaint. I deal with complaints.", "Kuno: Du siehst aus wie eine Beschwerde. Um Beschwerden kümmere ich mich."),
                       ("Kuno: Complaint upheld. First time for everything.", "Kuno: Beschwerde stattgegeben. Es gibt für alles ein erstes Mal.")),
    "tithe_road": ("villager", "alms_seller", ("Alms Seller Trude", "Almosenhändlerin Trude"),
                   ("Trude: I sell alms. You pay me, I feel sorry for you. It's cheaper than the House.", "Trude: Ich verkaufe Almosen. Du zahlst, ich hab Mitleid mit dir. Billiger als das Haus."),
                   ("Trude: No coin? Then I'll take pity out of your team.", "Trude: Keine Münze? Dann hol ich mir das Mitleid aus deinem Team."),
                   ("Trude: Poor me. Finally the pity goes the right way.", "Trude: Ich Arme. Endlich fließt das Mitleid in die richtige Richtung.")),
    "bellrope_marsh": ("ranger", "peat_poacher", ("Peat Poacher Ragna", "Torfwilderin Ragna"),
                       ("Ragna: I dig peat where the House says not to. The things I find there, the House says not to mention.", "Ragna: Ich steche Torf, wo das Haus es verbietet. Was ich da finde, soll ich laut Haus nicht erwähnen."),
                       ("Ragna: You saw my spade. That's a shame for one of us.", "Ragna: Du hast meinen Spaten gesehen. Schade für einen von uns."),
                       ("Ragna: Fine, it's a shame for me. Mind the soft ground. It's occupied.", "Ragna: Gut, schade für mich. Pass auf den weichen Boden auf. Der ist besetzt.")),
}

GOALS = [
    {"id": "toll_twice", "turns": False, "road": "tollchain_causeway", "reward": ("strong_tonic", 2), "reward_doubt": ("max_tonic", 3),
     "giver": ("cindergate_quay", "elder", "marga"),
     "intro": [("Fishwife Marga: I pay the toll on the causeway. Then, at the far end, I pay it again. Same stamp, different hand.", "Fischfrau Marga: Ich zahle den Zoll auf dem Damm. Am anderen Ende zahle ich ihn nochmal. Derselbe Stempel, eine andere Hand."),
               ("Fishwife Marga: Find out who takes the second toll. I'm a widow. I can't afford to be robbed twice a day.", "Fischfrau Marga: Finde heraus, wer den zweiten Zoll kassiert. Ich bin Witwe. Ich kann es mir nicht leisten, zweimal am Tag beraubt zu werden.")],
     "wait": ("Fishwife Marga: The chain boys on the Tollchain Causeway see who comes at night. And the stamps are kept in the Tollhouse.", "Fischfrau Marga: Die Kettenjungen auf dem Zollkettendamm sehen, wer nachts kommt. Und die Stempel liegen im Zollhaus."),
     "reveal": [("Fishwife Marga: The lost stamp was my Garrick's? My Garrick drowned. I buried the stamp with him.", "Fischfrau Marga: Der verlorene Stempel war der von meinem Garrick? Mein Garrick ist ertrunken. Ich hab den Stempel mit ihm begraben."),
                ("Fishwife Marga: Well. I buried a stamp. And a coffin. It was a light coffin, now that I think of it.", "Fischfrau Marga: Na ja. Ich hab einen Stempel begraben. Und einen Sarg. Der Sarg war leicht, wenn ich so darüber nachdenke."),
                ("Fishwife Marga: You do believe I didn't know?", "Fischfrau Marga: Du glaubst mir doch, dass ich nichts wusste?")],
     "choice": (("I believe you.", "Ich glaube dir."), ("A widow counts her coffins.", "Eine Witwe zählt ihre Särge."),
                ("Fishwife Marga: Bless you. Nobody has believed me since the wedding.", "Fischfrau Marga: Gott segne dich. Seit der Hochzeit hat mir keiner mehr geglaubt."),
                ("Fishwife Marga: Careful. Clever people pay a third toll in this town.", "Fischfrau Marga: Vorsicht. Schlaue Leute zahlen in dieser Stadt einen dritten Zoll.")),
     "go": ("Fishwife Marga: He collects on the causeway after dark. Go and collect him.", "Fischfrau Marga: Er kassiert nach Einbruch der Dunkelheit auf dem Damm. Geh und kassier ihn."),
     "reward_lines": [("Fishwife Marga: You beat him? Good. Here, for a friend. The second booth is mine now. It's what he would have wanted. He isn't asked.", "Fischfrau Marga: Du hast ihn geschlagen? Gut. Hier, für einen Freund. Das zweite Häuschen gehört jetzt mir. Er hätte es so gewollt. Gefragt wird er nicht.")],
     "reward_doubt_lines": [("Fishwife Marga: You beat him. And you think half the second toll was mine all along. Here. That's a lot of tonic for a quiet person.", "Fischfrau Marga: Du hast ihn geschlagen. Und du denkst, der halbe zweite Zoll war schon immer meiner. Hier. Das ist viel Trank für einen stillen Menschen.")],
     "after": ("Fishwife Marga: The causeway has three tolls now. Progress.", "Fischfrau Marga: Der Damm hat jetzt drei Zölle. Fortschritt."),
     "steps": [("tollchain_causeway", "villager", "ruk",
                [("Chain Boy Ruk: The second booth? It's only there at night. A man in a wet coat. He never comes from the town side.", "Kettenjunge Ruk: Das zweite Häuschen? Das steht nur nachts da. Ein Mann im nassen Mantel. Er kommt nie von der Stadtseite."),
                 ("Chain Boy Ruk: His receipts have the House stamp. The real one. Ask in the Tollhouse who's missing a stamp.", "Kettenjunge Ruk: Seine Quittungen haben den Stempel des Hauses. Den echten. Frag im Zollhaus, wem ein Stempel fehlt.")],
                ("Chain Boy Ruk: I pull the chain up, I let the chain down. The chain earns more than I do.", "Kettenjunge Ruk: Ich zieh die Kette hoch, ich lass die Kette runter. Die Kette verdient mehr als ich."), None),
               ("cindergate_quay_tollhouse", "villager", "ines",
                [("Stamp Girl Ines: One stamp is missing. Tollman Garrick's. Lost with him in the harbour two winters ago.", "Stempelmädchen Ines: Ein Stempel fehlt. Der von Zöllner Garrick. Mit ihm im Hafen verloren, vor zwei Wintern."),
                 ("Stamp Girl Ines: Funny. His widow still brings his lunch to the causeway. Every evening.", "Stempelmädchen Ines: Komisch. Seine Witwe bringt immer noch sein Mittagessen zum Damm. Jeden Abend.")],
                ("Stamp Girl Ines: I stamp what I'm given. It's the only way to keep all ten fingers.", "Stempelmädchen Ines: Ich stemple, was man mir gibt. Nur so behält man alle zehn Finger."), None)],
     "betrayer": ("tollchain_causeway", "elder", "garrick", ("Late Tollman Garrick", "Seliger Zöllner Garrick"),
                  [("Garrick: Marga sent you? She sends my lunch, too. Today you're the second course.", "Garrick: Marga schickt dich? Sie schickt auch mein Mittagessen. Heute bist du der zweite Gang.")],
                  [("Garrick: Beaten. And dead. A man can only take so much in one lifetime.", "Garrick: Geschlagen. Und tot. Ein Mann hält in einem Leben nur so viel aus."),
                   ("Garrick: Ask Marga who sewed the wet coat. Go on. Ask.", "Garrick: Frag Marga, wer den nassen Mantel genäht hat. Los. Frag.")],
                  None,
                  ("Garrick: I'm dead. The dead pay no toll. It's the whole point.", "Garrick: Ich bin tot. Tote zahlen keinen Zoll. Das ist der ganze Witz.")),
     "stages": [("Fishwife Marga pays the causeway toll twice a day. Find out who takes the second one.", "Fischfrau Marga zahlt den Dammzoll zweimal am Tag. Finde heraus, wer den zweiten kassiert.", "Cindergate Quay"),
                ("The night receipts carry a real House stamp. Ask in the Cindergate Tollhouse whose is missing.", "Die Nachtquittungen tragen einen echten Stempel des Hauses. Frag im Zollhaus von Cindergate, wessen fehlt.", "Cindergate Tollhouse"),
                ("The stamp belonged to Marga's drowned husband. Tell her.", "Der Stempel gehörte Margas ertrunkenem Mann. Sag es ihr.", "Cindergate Quay"),
                ("Garrick is not as drowned as he should be. Beat him on the Tollchain Causeway.", "Garrick ist nicht so ertrunken, wie er sein sollte. Schlag ihn auf dem Zollkettendamm.", "Tollchain Causeway"),
                ("The second booth belongs to Marga now. It always did.", "Das zweite Häuschen gehört jetzt Marga. Das tat es schon immer.", "Cindergate Quay")]},

    {"id": "wax_names", "turns": True, "road": "rookery_cut", "reward": ("revival_leaf", 3),
     "giver": ("tallowmarket", "villager", "sanne"),
     "intro": [("Vigil Girl Sanne: The candles in the Vigil House have names on them. Foundry men. Three of those men walked past me this morning.", "Wachmädchen Sanne: Die Kerzen im Wachhaus tragen Namen. Gießer. Drei von den Männern sind heute Morgen an mir vorbeigegangen."),
               ("Vigil Girl Sanne: Somebody orders the candles before the accidents. Find out who. I only light them.", "Wachmädchen Sanne: Jemand bestellt die Kerzen vor den Unfällen. Finde heraus, wer. Ich zünde sie nur an.")],
     "wait": ("Vigil Girl Sanne: The orders come to the Wax Hall. And the crows on the Rookery Cut carry the lists.", "Wachmädchen Sanne: Die Bestellungen gehen in die Wachshalle. Und die Krähen in der Krähenschneise tragen die Listen."),
     "reveal": [("Vigil Girl Sanne: A girl's hand, round letters, a little flower on every i? Yes. That's mine.", "Wachmädchen Sanne: Mädchenschrift, runde Buchstaben, ein Blümchen auf jedem i? Ja. Das ist meine."),
                ("Vigil Girl Sanne: The Syndicate says the names. I write them neatly. Neat handwriting is rare here. It pays by the name.", "Wachmädchen Sanne: Das Syndikat sagt die Namen. Ich schreibe sie ordentlich. Ordentliche Schrift ist hier selten. Bezahlt wird pro Name."),
                ("Vigil Girl Sanne: I asked you because the last three knew my writing. Now you do too. How do you spell your name?", "Wachmädchen Sanne: Ich hab dich gefragt, weil die letzten drei meine Schrift kannten. Jetzt kennst du sie auch. Wie schreibt man deinen Namen?")],
     "steps": [("tallowmarket_wax_hall", "villager", "bette",
                [("Wax Girl Bette: Name candles? Paid a week ahead, always. We pour them before the man is even late for supper.", "Wachsmädchen Bette: Namenskerzen? Immer eine Woche im Voraus bezahlt. Wir gießen sie, bevor der Mann auch nur zu spät zum Abendessen kommt."),
                 ("Wax Girl Bette: The list comes by crow from the Rookery Cut. Ask the crow boy who writes it.", "Wachsmädchen Bette: Die Liste kommt per Krähe aus der Krähenschneise. Frag den Krähenjungen, wer sie schreibt.")],
                ("Wax Girl Bette: We never get an order wrong. That's the frightening part.", "Wachsmädchen Bette: Wir machen nie eine Bestellung falsch. Das ist das Unheimliche daran."), None),
               ("rookery_cut", "villager", "wido",
                [("Crow Boy Wido: The candle lists? I can't read. The crows can. They say it's a girl's hand. Round. Flowers on the i.", "Krähenjunge Wido: Die Kerzenlisten? Ich kann nicht lesen. Die Krähen schon. Sie sagen, Mädchenschrift. Rund. Blümchen auf dem i."),
                 ("Crow Boy Wido: She hands them over herself, at the Vigil House door. Lights a candle after. Nice girl.", "Krähenjunge Wido: Sie gibt sie selbst ab, an der Tür vom Wachhaus. Zündet danach eine Kerze an. Nettes Mädchen.")],
                ("Crow Boy Wido: The crows know everything. They just won't tell me the good parts.", "Krähenjunge Wido: Die Krähen wissen alles. Die guten Stellen verraten sie mir bloß nicht."), None)],
     "betrayer": ("tallowmarket", "villager", "sanne_list", ("List Writer Sanne", "Listenschreiberin Sanne"),
                  [("Sanne: Hold still. I want to get the spelling right.", "Sanne: Halt still. Ich will die Schreibweise richtig hinbekommen.")],
                  [("Sanne: Smudged. I never smudge. You've ruined a whole page.", "Sanne: Verschmiert. Ich verschmiere nie. Du hast eine ganze Seite ruiniert."),
                   ("Sanne: Take the list. Three names are still dry. Tell them to stay home from work.", "Sanne: Nimm die Liste. Drei Namen sind noch trocken. Sag ihnen, sie sollen der Arbeit fernbleiben.")],
                  [("You take Sanne's list and the revival leaves she kept for after work. Your name is on the list. She spelled it right.", "Du nimmst Sannes Liste und die Lebensblätter, die sie für nach Feierabend aufgehoben hat. Dein Name steht auf der Liste. Richtig geschrieben.")],
                  ("Sanne: I've taken up drawing. Portraits. Very lifelike, for now.", "Sanne: Ich hab mit dem Zeichnen angefangen. Porträts. Sehr lebensecht, vorerst.")),
     "stages": [("Candles in the Vigil House carry the names of foundry men who are still alive. Find out who orders them.", "Kerzen im Wachhaus tragen die Namen von Gießern, die noch leben. Finde heraus, wer sie bestellt.", "Tallowmarket"),
                ("The lists come by crow. Ask the crow boy on the Rookery Cut who writes them.", "Die Listen kommen per Krähe. Frag den Krähenjungen in der Krähenschneise, wer sie schreibt.", "Rookery Cut"),
                ("The lists are in a girl's round hand. Ask Sanne.", "Die Listen sind in runder Mädchenschrift. Frag Sanne.", "Tallowmarket"),
                ("Sanne writes the Syndicate's lists, and she is writing your name. Stop her in Tallowmarket.", "Sanne schreibt die Listen des Syndikats, und sie schreibt gerade deinen Namen. Halt sie in Tallowmarket auf.", "Tallowmarket"),
                ("Three names stayed dry. Yours was spelled right.", "Drei Namen blieben trocken. Deiner war richtig geschrieben.", "Tallowmarket")]},

    {"id": "two_owners", "turns": False, "road": "weeping_locks", "reward": ("dash_brew", 2), "reward_doubt": ("dash_brew", 4),
     "giver": ("hookwick", "villager", "hald"),
     "intro": [("Skipper Hald: My boat, the Patience. Somebody sold her while I was asleep in her. I woke up a passenger.", "Schiffer Hald: Mein Boot, die Geduld. Jemand hat sie verkauft, während ich drin geschlafen hab. Ich bin als Fahrgast aufgewacht."),
               ("Skipper Hald: Find out who sold my boat. A man has a right to know who robbed him. In detail.", "Schiffer Hald: Finde heraus, wer mein Boot verkauft hat. Ein Mann hat ein Recht zu wissen, wer ihn beraubt hat. Im Einzelnen.")],
     "wait": ("Skipper Hald: The painter's boy in the Boatshed paints over the names. And stolen hulls go through the Smugglers' Culvert under the Weeping Locks.", "Schiffer Hald: Der Malerjunge im Bootsschuppen übermalt die Namen. Und gestohlene Rümpfe gehen durch den Schmugglerkanal unter den Weinenden Schleusen."),
     "reveal": [("Skipper Hald: The bill of sale has my mark on it? Twice? Well. I do sign a lot of things.", "Schiffer Hald: Auf dem Kaufvertrag ist mein Zeichen? Zweimal? Na ja. Ich unterschreibe eben viel."),
                ("Skipper Hald: All right. I sold her. To two buyers. A boat with two owners is the custom here, I only kept the custom.", "Schiffer Hald: Na gut. Ich hab sie verkauft. An zwei Käufer. Ein Boot mit zwei Besitzern ist hier Brauch, ich hab nur den Brauch gepflegt."),
                ("Skipper Hald: One of them found out. Get her off my back and I'll cut you in on the third sale. You trust me?", "Schiffer Hald: Eine von beiden hat es gemerkt. Schaff sie mir vom Hals, und du bist beim dritten Verkauf dabei. Vertraust du mir?")],
     "choice": (("A third sale. I'm in.", "Ein dritter Verkauf. Ich bin dabei."), ("I want my share up front.", "Ich will meinen Anteil im Voraus."),
                ("Skipper Hald: Partner! I've never had one of those last a week.", "Schiffer Hald: Partner! So einen hatte ich noch nie länger als eine Woche."),
                ("Skipper Hald: Up front? You've been in Hookwick too long already.", "Schiffer Hald: Im Voraus? Du bist schon zu lange in Hookwick.")),
     "go": ("Skipper Hald: Dame Rikke waits at the Weeping Locks with a lawyer's face. Go and argue my case.", "Schiffer Hald: Dame Rikke wartet an den Weinenden Schleusen mit einem Anwaltsgesicht. Geh und vertritt meinen Fall."),
     "reward_lines": [("Skipper Hald: You beat her? Partner! Here's your cut of the third sale. The buyer paid in brew. And in a boat he doesn't have yet.", "Schiffer Hald: Du hast sie geschlagen? Partner! Hier ist dein Anteil am dritten Verkauf. Der Käufer hat in Gebräu bezahlt. Und in einem Boot, das er noch nicht hat.")],
     "reward_doubt_lines": [("Skipper Hald: You beat her, and you counted your share before I could. Here. All of it. I feel robbed. In detail.", "Schiffer Hald: Du hast sie geschlagen und deinen Anteil gezählt, bevor ich es konnte. Hier. Alles. Ich fühle mich beraubt. Im Einzelnen.")],
     "after": ("Skipper Hald: The Patience has four owners now. She's never been so popular.", "Schiffer Hald: Die Geduld hat jetzt vier Besitzer. So beliebt war sie noch nie."),
     "steps": [("hookwick_boatshed", "villager", "malte",
                [("Paint Boy Malte: The Patience? I painted 'Prudence' over her on Monday and 'Providence' on Tuesday. Same skipper paid both times.", "Malerjunge Malte: Die Geduld? Am Montag hab ich 'Vorsicht' drübergemalt und am Dienstag 'Vorsehung'. Derselbe Schiffer hat beide Male bezahlt."),
                 ("Paint Boy Malte: The papers went down the Smugglers' Culvert, under the Weeping Locks. The rats there keep the bills of sale.", "Malerjunge Malte: Die Papiere gingen in den Schmugglerkanal, unter den Weinenden Schleusen. Die Ratten da verwahren die Kaufverträge.")],
                ("Paint Boy Malte: I only paint names. What the names do afterwards is not my brush.", "Malerjunge Malte: Ich male nur Namen. Was die Namen danach treiben, ist nicht mein Pinsel."), None),
               ("smugglers_culvert", "ranger", "rats",
                [("Culvert Rat Smilla: Bills of sale? We keep them dry and we keep them ours. You want to read one, you get past us.", "Kanalratte Smilla: Kaufverträge? Die halten wir trocken und die bleiben unsere. Willst du einen lesen, musst du an uns vorbei.")],
                ("Culvert Rat Smilla: Two sales, one mark, same hand. Hald's. He tips well. That's how we knew something was wrong.", "Kanalratte Smilla: Zwei Verkäufe, ein Zeichen, dieselbe Hand. Halds. Er gibt gut Trinkgeld. Daran haben wir gemerkt, dass was nicht stimmt."),
                (("Culvert Rats", "Kanalratten"),
                 [("Culvert Rat Smilla: All right, all right. Here. Two bills of sale for one boat. Both signed by the skipper himself.", "Kanalratte Smilla: Schon gut, schon gut. Hier. Zwei Kaufverträge für ein Boot. Beide vom Schiffer selbst unterschrieben.")]))],
     "betrayer": ("weeping_locks", "villager", "rikke", ("Second Owner Dame Rikke", "Zweitbesitzerin Dame Rikke"),
                  [("Dame Rikke: Hald sent you instead of my boat. Then I'll take you instead of my money.", "Dame Rikke: Hald schickt dich statt meines Boots. Dann nehme ich dich statt meines Geldes.")],
                  [("Dame Rikke: Outbid. By a stranger. In my own lawsuit.", "Dame Rikke: Überboten. Von einer Fremden. In meinem eigenen Prozess."),
                   ("Dame Rikke: Keep an eye on your partner. I was his partner on Monday.", "Dame Rikke: Behalt deinen Partner im Auge. Am Montag war ich seine Partnerin.")],
                  None,
                  ("Dame Rikke: I've bought a horse. Nobody sells a horse twice. It bites.", "Dame Rikke: Ich hab ein Pferd gekauft. Ein Pferd verkauft keiner zweimal. Es beißt.")),
     "stages": [("Skipper Hald's boat was sold while he slept in it. Find out who sold it.", "Schiffer Halds Boot wurde verkauft, während er darin schlief. Finde heraus, wer es verkauft hat.", "Hookwick"),
                ("The bills of sale are in the Smugglers' Culvert. Get them from the rats.", "Die Kaufverträge liegen im Schmugglerkanal. Hol sie dir von den Ratten.", "Smugglers' Culvert"),
                ("Both bills carry Hald's own mark. Ask him.", "Beide Verträge tragen Halds eigenes Zeichen. Frag ihn.", "Hookwick"),
                ("Hald sold his boat twice. Deal with the second owner at the Weeping Locks.", "Hald hat sein Boot zweimal verkauft. Kümmere dich an den Weinenden Schleusen um die Zweitbesitzerin.", "Weeping Locks"),
                ("The Patience has four owners now.", "Die Geduld hat jetzt vier Besitzer.", "Hookwick")]},

    {"id": "second_face", "turns": True, "road": "tithe_road", "reward": ("guard_brew", 3),
     "giver": ("larkspur_heights_servants_hall", "villager", "petra"),
     "intro": [("Maid Petra: At the ball somebody wore my mistress's mask. Her face, her walk, her signature. My mistress was in bed with a headache.", "Zofe Petra: Auf dem Ball hat jemand die Maske meiner Herrin getragen. Ihr Gesicht, ihr Gang, ihre Unterschrift. Meine Herrin lag mit Kopfweh im Bett."),
               ("Maid Petra: Find the second face. Madam cries so, and I'm the one who has to iron the handkerchiefs.", "Zofe Petra: Finde das zweite Gesicht. Die Gnädige weint so, und die Taschentücher muss ich bügeln.")],
     "wait": ("Maid Petra: Masks are made in the Mask Atelier. And the coachmen on the Tithe Road know who rode where that night.", "Zofe Petra: Masken macht das Maskenatelier. Und die Kutscher auf der Zehntstraße wissen, wer in der Nacht wohin gefahren ist."),
     "reveal": [("Maid Petra: The lady signed with her left hand? How odd. Madam is right-handed. I'm left-handed. What a coincidence.", "Zofe Petra: Die Dame hat mit links unterschrieben? Wie seltsam. Die Gnädige ist Rechtshänderin. Ich bin Linkshänderin. So ein Zufall."),
                ("Maid Petra: Fifteen years I've carried her face to the cleaner. I know it better than she does. It fits me better, too.", "Zofe Petra: Fünfzehn Jahre hab ich ihr Gesicht zum Putzen getragen. Ich kenne es besser als sie. Mir steht es auch besser."),
                ("Maid Petra: The account is empty and the headache was in the tea. You were meant to find a stranger. Pity. Now I need a third face.", "Zofe Petra: Das Konto ist leer, und das Kopfweh war im Tee. Du solltest eine Fremde finden. Schade. Jetzt brauche ich ein drittes Gesicht.")],
     "steps": [("larkspur_heights_mask_atelier", "villager", "tilo",
                [("Mask Boy Tilo: Lady Vespera's mask? We made it twice. The second one was ordered through the servants' door, paid in small coin.", "Maskenjunge Tilo: Die Maske von Dame Vespera? Die haben wir zweimal gemacht. Die zweite wurde über die Dienstbotentür bestellt, bezahlt in Kleingeld."),
                 ("Mask Boy Tilo: Fifteen years of small coin, I'd say. Ask the coachmen on the Tithe Road where the second face went.", "Maskenjunge Tilo: Fünfzehn Jahre Kleingeld, würde ich sagen. Frag die Kutscher auf der Zehntstraße, wohin das zweite Gesicht gefahren ist.")],
                ("Mask Boy Tilo: A good mask shows who you are. A very good one shows who you'd rather rob.", "Maskenjunge Tilo: Eine gute Maske zeigt, wer du bist. Eine sehr gute, wen du lieber ausrauben würdest."), None),
               ("tithe_road", "elder", "henner",
                [("Coachman Henner: The lady? I drove her from the ball to the Counting House at midnight. She tipped. That's how I knew it wasn't her.", "Kutscher Henner: Die Dame? Ich hab sie um Mitternacht vom Ball zum Kontor gefahren. Sie hat Trinkgeld gegeben. Daran hab ich gemerkt, dass sie es nicht war."),
                 ("Coachman Henner: Signed for the whole account with her left hand. And she smelled of starch.", "Kutscher Henner: Hat fürs ganze Konto mit links unterschrieben. Und sie roch nach Wäschestärke.")],
                ("Coachman Henner: I drive, I don't look. Looking costs extra and I've never been offered it.", "Kutscher Henner: Ich fahre, ich schaue nicht hin. Hinschauen kostet extra, und das hat mir noch keiner geboten."), None)],
     "betrayer": ("larkspur_heights", "villager", "petra_lady", ("Lady Petra", "Dame Petra"),
                  [("Petra: You may address me as Madam. Briefly.", "Petra: Du darfst mich Gnädige nennen. Kurz.")],
                  [("Petra: Unmasked. In the street. How terribly middle class.", "Petra: Entlarvt. Auf offener Straße. Wie furchtbar bürgerlich."),
                   ("Petra: Take the brews. They were for the journey. The money stays where it is. In me.", "Petra: Nimm das Gebräu. Es war für die Reise. Das Geld bleibt, wo es ist. Bei mir.")],
                  [("You take the brews from Petra's travelling bag. Under them lie three more masks. One of them is yours.", "Du nimmst das Gebräu aus Petras Reisetasche. Darunter liegen drei weitere Masken. Eine davon ist deine.")],
                  ("Petra: Madam irons her own handkerchiefs now. She's dreadful at it.", "Petra: Die Gnädige bügelt ihre Taschentücher jetzt selbst. Sie kann es furchtbar schlecht.")),
     "stages": [("Somebody wore the face of Maid Petra's mistress at the ball. Find the second face.", "Jemand trug auf dem Ball das Gesicht von Zofe Petras Herrin. Finde das zweite Gesicht.", "Larkspur Heights"),
                ("The mask was made twice. Ask the coachmen on the Tithe Road where the second one went.", "Die Maske wurde zweimal gemacht. Frag die Kutscher auf der Zehntstraße, wohin die zweite fuhr.", "Tithe Road"),
                ("The lady signed left-handed and smelled of starch. Ask Petra in the Servants' Hall.", "Die Dame unterschrieb mit links und roch nach Stärke. Frag Petra in der Gesindestube.", "Servants' Hall"),
                ("Petra emptied the account in her mistress's face. Stop her in Larkspur Heights.", "Petra hat mit dem Gesicht ihrer Herrin das Konto geleert. Halt sie in Larkspur Heights auf.", "Larkspur Heights"),
                ("Madam irons her own handkerchiefs now.", "Die Gnädige bügelt ihre Taschentücher jetzt selbst.", "Larkspur Heights")]},

    {"id": "marsh_bell", "turns": False, "road": "bellrope_marsh", "reward": ("wake_bell", 2), "reward_doubt": ("wake_bell", 4),
     "giver": ("lastlamp", "elder", "gesa"),
     "intro": [("Mother Gesa: A bell rings out in the marsh every night. My Tobin went missing a week ago. The ringer says nobody rings it.", "Mutter Gesa: Jede Nacht läutet draußen im Moor eine Glocke. Mein Tobin ist vor einer Woche verschwunden. Der Glöckner sagt, es läutet keiner."),
               ("Mother Gesa: Find the bell. The Lamp Guild has been very kind. They've already offered to buy his room.", "Mutter Gesa: Finde die Glocke. Die Lampengilde war sehr freundlich. Sie hat schon angeboten, sein Zimmer zu kaufen.")],
     "wait": ("Mother Gesa: The reed cutters on the Bellrope Marsh follow the ropes. Follow them.", "Mutter Gesa: Die Schilfschneider im Glockenseilmoor folgen den Seilen. Folg ihnen."),
     "reveal": [("Mother Gesa: Alive. In the crypt. Put there by the Guild, so the street has one lamp less to pay for.", "Mutter Gesa: Lebendig. In der Gruft. Von der Gilde dort hingebracht, damit die Straße eine Lampe weniger bezahlen muss."),
                ("Mother Gesa: And they sell the rooms of the lost. Mine was next, I suppose. Two for one.", "Mutter Gesa: Und sie verkaufen die Zimmer der Verschollenen. Meins wäre wohl das nächste gewesen. Zwei zum Preis von einem."),
                ("Mother Gesa: The Guild's collector comes tonight for my answer. I could sign. Tobin eats a great deal. What would you do?", "Mutter Gesa: Der Eintreiber der Gilde kommt heute Nacht wegen meiner Antwort. Ich könnte unterschreiben. Tobin isst sehr viel. Was würdest du tun?")],
     "choice": (("You'd never sign. I'll stop him.", "Du würdest nie unterschreiben. Ich halte ihn auf."), ("I'll stop him before you can sign.", "Ich halte ihn auf, bevor du unterschreiben kannst."),
                ("Mother Gesa: Never. Well. Hardly ever. Thank you for thinking so.", "Mutter Gesa: Nie. Na ja. Fast nie. Danke, dass du das denkst."),
                ("Mother Gesa: You've met mothers before, I see.", "Mutter Gesa: Du hast schon Mütter kennengelernt, wie ich sehe.")),
     "go": ("Mother Gesa: The collector waits in the Bell Crypt, by the ropes. Bring my boy up. And the collector's purse.", "Mutter Gesa: Der Eintreiber wartet in der Glockengruft, bei den Seilen. Bring meinen Jungen rauf. Und die Börse des Eintreibers."),
     "reward_lines": [("Mother Gesa: Tobin is home. He's eaten everything. Here are his bells, he's not to touch a rope again. I did keep the Guild's offer. To frame.", "Mutter Gesa: Tobin ist zu Hause. Er hat alles aufgegessen. Hier sind seine Glocken, er fasst kein Seil mehr an. Das Angebot der Gilde hab ich behalten. Zum Einrahmen.")],
     "reward_doubt_lines": [("Mother Gesa: Tobin is home. You looked at me the whole way as if I'd sign. Here, all the bells in the house. Now stop looking.", "Mutter Gesa: Tobin ist zu Hause. Du hast mich den ganzen Weg angeschaut, als würde ich unterschreiben. Hier, alle Glocken im Haus. Und jetzt schau woandershin.")],
     "after": ("Mother Gesa: Tobin rents out his own room now. To the Guild. At a criminal price. I'm so proud.", "Mutter Gesa: Tobin vermietet sein Zimmer jetzt selbst. An die Gilde. Zu einem kriminellen Preis. Ich bin so stolz."),
     "steps": [("bellrope_marsh", "villager", "keld",
                [("Reed Cutter Keld: The night bell? One rope goes down, not up. Into the old chapel cellar. There are stairs in the reeds.", "Schilfschneider Keld: Die Nachtglocke? Ein Seil geht nach unten, nicht nach oben. In den alten Kapellenkeller. Im Schilf ist eine Treppe."),
                 ("Reed Cutter Keld: I cut round it. A bell that rings from below is asking for someone else.", "Schilfschneider Keld: Ich schneide drum herum. Eine Glocke, die von unten läutet, meint jemand anderen.")],
                ("Reed Cutter Keld: The reeds grow back. That's more than you can say for most things here.", "Schilfschneider Keld: Das Schilf wächst nach. Das kann man hier von den meisten Dingen nicht sagen."), None),
               ("bell_crypt", "villager", "tobin",
                [("Tobin: You heard me! A week I've been ringing. The Lamp Guild walked me down here. 'Fewer mouths, fewer lamps,' they said.", "Tobin: Du hast mich gehört! Eine Woche läute ich schon. Die Lampengilde hat mich hier runtergebracht. 'Weniger Mäuler, weniger Lampen', haben sie gesagt."),
                 ("Tobin: Tell my mother. And tell her not to sign anything. She likes signing things.", "Tobin: Sag es meiner Mutter. Und sag ihr, sie soll nichts unterschreiben. Sie unterschreibt gern.")],
                ("Tobin: I'll keep ringing till the collector is gone. It annoys him. It's all I've got.", "Tobin: Ich läute weiter, bis der Eintreiber weg ist. Es ärgert ihn. Mehr hab ich nicht."), None)],
     "betrayer": ("bell_crypt", "warden", "collector", ("Guild Collector Asmus", "Gildeneintreiber Asmus"),
                  [("Asmus: The mother sent you with her answer? I'd hoped for a signature. A fight is so much paperwork.", "Asmus: Die Mutter schickt dich mit ihrer Antwort? Ich hatte auf eine Unterschrift gehofft. Ein Kampf ist so viel Papierkram.")],
                  [("Asmus: Lights out. That's our line, usually.", "Asmus: Licht aus. Das ist sonst unser Spruch."),
                   ("Asmus: Take the boy. The Guild will find another saving. The street is full of mouths.", "Asmus: Nimm den Jungen. Die Gilde findet eine andere Einsparung. Die Straße ist voller Mäuler.")],
                  None,
                  ("Asmus: I've been moved to accounts. There are no ropes in accounts. Only ledgers. They hang you slower.", "Asmus: Ich wurde in die Buchhaltung versetzt. Da gibt es keine Seile. Nur Bücher. Die hängen einen langsamer.")),
     "stages": [("A bell rings in the marsh every night, and Mother Gesa's son is missing. Find the bell.", "Jede Nacht läutet im Moor eine Glocke, und der Sohn von Mutter Gesa wird vermisst. Finde die Glocke.", "Lastlamp"),
                ("One bell rope leads down into the Bell Crypt under the Bellrope Marsh. Follow it.", "Ein Glockenseil führt hinunter in die Glockengruft unter dem Glockenseilmoor. Folg ihm.", "Bell Crypt"),
                ("Tobin is alive in the crypt. The Lamp Guild put him there. Tell his mother.", "Tobin lebt, in der Gruft. Die Lampengilde hat ihn dort hingebracht. Sag es seiner Mutter.", "Lastlamp"),
                ("Beat the Guild's collector in the Bell Crypt.", "Schlag den Eintreiber der Gilde in der Glockengruft.", "Bell Crypt"),
                ("Tobin is home and rents his room to the Guild.", "Tobin ist zu Hause und vermietet sein Zimmer an die Gilde.", "Lastlamp")]},

    {"id": "ghost_wages", "turns": False, "road": "smelters_drift", "reward": ("max_tonic", 3),
     "giver": ("tallowmarket", "elder", "hette"),
     "intro": [("Widow Hette: My Ludo died at the foundry. His last wages never came. The paymaster says they were paid. To whom?", "Witwe Hette: Mein Ludo ist in der Gießerei gestorben. Sein letzter Lohn kam nie. Der Zahlmeister sagt, er wurde ausgezahlt. An wen?"),
               ("Widow Hette: Find Ludo's wages. It's not the money. It is the money. But it's also the principle of the money.", "Witwe Hette: Finde Ludos Lohn. Es geht nicht ums Geld. Doch, es geht ums Geld. Aber auch ums Prinzip des Geldes.")],
     "wait": ("Widow Hette: The slag carters on Smelter's Drift haul more than slag. And the pay cart goes down into the Slag Tunnels.", "Witwe Hette: Die Schlackenkarrer auf der Schmelzerhalde fahren mehr als Schlacke. Und der Lohnkarren fährt in die Schlackenstollen."),
     "reveal": [("Widow Hette: Forty dead men on the payroll, still drawing wages. And the paymaster signs with a little hook on the L. Like Ludo did.", "Witwe Hette: Vierzig Tote auf der Lohnliste, die immer noch Lohn bekommen. Und der Zahlmeister unterschreibt mit einem Häkchen am L. Wie Ludo."),
                ("Widow Hette: He isn't dead. He's the paymaster. He pays himself my widow's wage and I wore black for it.", "Witwe Hette: Er ist nicht tot. Er ist der Zahlmeister. Er zahlt sich meinen Witwenlohn selbst aus, und ich hab dafür Schwarz getragen.")],
     "go": ("Widow Hette: He counts in the Slag Tunnels. Go and make me a widow properly. In the financial sense.", "Witwe Hette: Er zählt in den Schlackenstollen. Geh und mach mich richtig zur Witwe. Im finanziellen Sinn."),
     "reward_lines": [("Widow Hette: You beat him? Good. He pays me forty-one wages now. His own and the forty. Here. A widow can be generous.", "Witwe Hette: Du hast ihn geschlagen? Gut. Er zahlt mir jetzt einundvierzig Löhne. Seinen und die vierzig. Hier. Eine Witwe kann großzügig sein.")],
     "after": ("Widow Hette: Ludo stays dead on paper. It's the best he's ever looked.", "Witwe Hette: Ludo bleibt auf dem Papier tot. So gut hat er noch nie ausgesehen."),
     "steps": [("smelters_drift", "villager", "bero",
                [("Slag Carter Bero: The pay cart? Goes down the Slag Tunnels every week, full. Comes up empty. No workers down there. Not live ones.", "Schlackenkarrer Bero: Der Lohnkarren? Fährt jede Woche voll in die Schlackenstollen. Kommt leer rauf. Da unten sind keine Arbeiter. Keine lebenden."),
                 ("Slag Carter Bero: There are stairs off the drift. The bruisers at the bottom don't like questions. Or answers.", "Schlackenkarrer Bero: Von der Halde geht eine Treppe ab. Die Schläger unten mögen keine Fragen. Antworten auch nicht.")],
                ("Slag Carter Bero: I cart slag. Slag never asked for a raise.", "Schlackenkarrer Bero: Ich karre Schlacke. Schlacke hat noch nie mehr Lohn verlangt."), None),
               ("slag_tunnels", "warden", "bruisers",
                [("Tunnel Bruiser Ortwin: The payroll is private. So is this tunnel. So is your face, in a minute.", "Stollenschläger Ortwin: Die Lohnliste ist privat. Der Stollen auch. Dein Gesicht gleich ebenfalls.")],
                ("Tunnel Bruiser Ortwin: Forty names, all dead, all paid. Signed with a hook on the L. I don't read. I was told about the hook.", "Stollenschläger Ortwin: Vierzig Namen, alle tot, alle bezahlt. Unterschrieben mit Häkchen am L. Ich lese nicht. Das mit dem Häkchen hat man mir gesagt."),
                (("Tunnel Bruisers", "Stollenschläger"),
                 [("Tunnel Bruiser Ortwin: Enough. Take the payroll. Forty dead men on it, and one very lively signature.", "Stollenschläger Ortwin: Genug. Nimm die Lohnliste. Vierzig Tote stehen drauf und eine sehr lebendige Unterschrift.")]))],
     "betrayer": ("slag_tunnels", "elder", "ludo", ("Paymaster Ludo", "Zahlmeister Ludo"),
                  [("Ludo: Hette sent you. She always did send other people. Stand there, you're in my light.", "Ludo: Hette schickt dich. Sie hat schon immer andere geschickt. Geh da weg, du stehst mir im Licht.")],
                  [("Ludo: Short. The till is short. That has never happened to a dead man before.", "Ludo: Fehlbetrag. Die Kasse stimmt nicht. Das ist einem Toten noch nie passiert."),
                   ("Ludo: Tell her I died well. Tell her I died twice, if it helps.", "Ludo: Sag ihr, ich bin gut gestorben. Sag ihr, ich bin zweimal gestorben, wenn es hilft.")],
                  None,
                  ("Ludo: Forty-one wages. She always was better with money than I was.", "Ludo: Einundvierzig Löhne. Sie konnte schon immer besser mit Geld umgehen als ich.")),
     "stages": [("Widow Hette's husband died at the foundry, and his last wages never came. Find them.", "Der Mann von Witwe Hette starb in der Gießerei, und sein letzter Lohn kam nie. Finde ihn.", "Tallowmarket"),
                ("The pay cart goes down into the Slag Tunnels under Smelter's Drift. Get the payroll.", "Der Lohnkarren fährt in die Schlackenstollen unter der Schmelzerhalde. Hol die Lohnliste.", "Slag Tunnels"),
                ("Forty dead men draw wages, and the paymaster signs like Ludo. Tell Hette.", "Vierzig Tote bekommen Lohn, und der Zahlmeister unterschreibt wie Ludo. Sag es Hette.", "Tallowmarket"),
                ("Ludo is alive and pays himself. Beat him in the Slag Tunnels.", "Ludo lebt und zahlt sich selbst aus. Schlag ihn in den Schlackenstollen.", "Slag Tunnels"),
                ("Ludo stays dead on paper and pays forty-one wages.", "Ludo bleibt auf dem Papier tot und zahlt einundvierzig Löhne.", "Tallowmarket")]},

    {"id": "pawned_medal", "turns": True, "road": "tithe_road", "reward": ("strong_tonic", 4),
     "giver": ("lastlamp", "elder", "varn"),
     "intro": [("Old Varn: My medal. For the stand at the Tithe Bridge. Some thief pawned it while I slept. A hero's medal, in a pawnshop.", "Der alte Varn: Mein Orden. Für die Verteidigung der Zehntbrücke. Ein Dieb hat ihn versetzt, während ich schlief. Ein Heldenorden, im Pfandhaus."),
               ("Old Varn: Find out who pawned it. I'd go myself, but my leg. And my other leg.", "Der alte Varn: Finde heraus, wer ihn versetzt hat. Ich würde selbst gehen, aber mein Bein. Und mein anderes Bein.")],
     "wait": ("Old Varn: The Pawnshop keeps every ticket. And the Counting House in Larkspur pays the bridge pensions.", "Der alte Varn: Das Pfandhaus hebt jeden Schein auf. Und das Kontor in Larkspur zahlt die Brückenrenten."),
     "reveal": [("Old Varn: The ticket is in my name, and the pension is in Captain Reik's. Yes. Both are in my pocket.", "Der alte Varn: Der Schein läuft auf meinen Namen und die Rente auf Hauptmann Reik. Ja. Beides steckt in meiner Tasche."),
                ("Old Varn: Reik held the bridge. I held Reik's coat. When he fell, I was right behind him. Very close behind.", "Der alte Varn: Reik hielt die Brücke. Ich hielt Reiks Mantel. Als er fiel, stand ich direkt hinter ihm. Sehr dicht."),
                ("Old Varn: I pawn the medal each month and send someone to ask who did it. They bring it back for free. You were meant to stop at the pawnshop.", "Der alte Varn: Ich versetze den Orden jeden Monat und schicke jemanden los, der fragt, wer es war. Die bringen ihn umsonst zurück. Du solltest im Pfandhaus aufhören.")],
     "steps": [("lastlamp_pawnshop", "villager", "kord",
                [("Pawn Boy Kord: The bridge medal? Pawned on the first of every month. Same shaky hand. The ticket says 'Varn'.", "Pfandjunge Kord: Der Brückenorden? Wird an jedem Monatsersten versetzt. Dieselbe zittrige Hand. Auf dem Schein steht 'Varn'."),
                 ("Pawn Boy Kord: The name on the medal isn't Varn, though. It says 'Reik'. The Counting House in Larkspur pays a Reik every month.", "Pfandjunge Kord: Auf dem Orden steht aber nicht Varn. Da steht 'Reik'. Das Kontor in Larkspur zahlt jeden Monat an einen Reik.")],
                ("Pawn Boy Kord: Everything in here is somebody's proudest day. Marked down.", "Pfandjunge Kord: Alles hier drin ist der stolzeste Tag von irgendwem. Reduziert."), None),
               ("larkspur_heights_counting_house", "villager", "sidonie",
                [("Clerk Sidonie: Captain Reik's pension? Collected every month, in person. Remarkable, for a man who fell off the Tithe Bridge.", "Schreiberin Sidonie: Die Rente von Hauptmann Reik? Jeden Monat persönlich abgeholt. Beachtlich für einen Mann, der von der Zehntbrücke gefallen ist."),
                 ("Clerk Sidonie: An old man with two bad legs signs for it. He runs down our stairs afterwards.", "Schreiberin Sidonie: Ein alter Mann mit zwei schlimmen Beinen unterschreibt dafür. Danach rennt er unsere Treppe hinunter.")],
                ("Clerk Sidonie: We never ask if a client is alive. It would halve the business.", "Schreiberin Sidonie: Wir fragen nie, ob ein Kunde noch lebt. Das würde das Geschäft halbieren."), None)],
     "betrayer": ("lastlamp", "elder", "varn_reik", ("Hero Varn", "Held Varn"),
                  [("Varn: I pushed a captain off a bridge, child. Guess what I do to errand runners.", "Varn: Ich hab einen Hauptmann von einer Brücke gestoßen, Kind. Rate, was ich mit Laufburschen mache.")],
                  [("Varn: Beaten. From the front. Nobody has ever done that to me. I never let them.", "Varn: Geschlagen. Von vorn. Das hat noch keiner geschafft. Ich hab es nie zugelassen."),
                   ("Varn: Take the tonics. They're on Reik. Everything is on Reik.", "Varn: Nimm die Tränke. Die gehen auf Reik. Alles geht auf Reik.")],
                  [("You take Varn's tonics and the medal. On the back somebody scratched: 'Watch the one holding your coat.'", "Du nimmst Varns Tränke und den Orden. Auf der Rückseite hat jemand eingeritzt: 'Pass auf den auf, der deinen Mantel hält.'")],
                  ("Varn: My legs are much worse now. Honestly, this time.", "Varn: Meine Beine sind jetzt viel schlimmer. Diesmal ehrlich.")),
     "stages": [("Old Varn's medal from the Tithe Bridge was pawned in Lastlamp. Find out who pawned it.", "Der Orden des alten Varn von der Zehntbrücke wurde in Lastlamp versetzt. Finde heraus, wer es war.", "Lastlamp"),
                ("The medal carries Captain Reik's name. Ask in the Counting House who collects his pension.", "Auf dem Orden steht der Name von Hauptmann Reik. Frag im Kontor, wer seine Rente abholt.", "Counting House"),
                ("An old man with two bad legs collects a dead captain's pension. Ask Varn.", "Ein alter Mann mit zwei schlimmen Beinen holt die Rente eines toten Hauptmanns ab. Frag Varn.", "Lastlamp"),
                ("Varn pushed the hero off the bridge and kept his medal. Beat him in Lastlamp.", "Varn hat den Helden von der Brücke gestoßen und seinen Orden behalten. Schlag ihn in Lastlamp.", "Lastlamp"),
                ("The medal says: watch the one holding your coat.", "Auf dem Orden steht: Pass auf den auf, der deinen Mantel hält.", "Lastlamp")]},

    {"id": "heavy_rumour", "turns": False, "road": "tollchain_causeway", "reward": ("remedy", 2), "reward_doubt": ("remedy", 4),
     "giver": ("tallowmarket", "villager", "joss"),
     "intro": [("Baker Joss: Somebody bought a rumour about my bread. 'Joss bakes with foundry ash.' A heavy one. My shop is empty.", "Bäcker Joss: Jemand hat ein Gerücht über mein Brot gekauft. 'Joss backt mit Gießereiasche.' Ein schweres. Mein Laden ist leer."),
               ("Baker Joss: Find the buyer. I've never done anything to anyone. Not that anyone could weigh.", "Bäcker Joss: Finde den Käufer. Ich hab nie jemandem was getan. Nichts, was man wiegen könnte.")],
     "wait": ("Baker Joss: Rumours are sold in the Rumour Room and weighed in the Weigh House. Somebody signed for mine.", "Bäcker Joss: Gerüchte werden in der Gerüchtestube verkauft und im Waaghaus gewogen. Für meins hat jemand unterschrieben."),
     "reveal": [("Baker Joss: My sister. Jutta. With the bakery by the quay. My own sister bought four pounds of lies about me.", "Bäcker Joss: Meine Schwester. Jutta. Mit der Bäckerei am Kai. Meine eigene Schwester hat vier Pfund Lügen über mich gekauft."),
                ("Baker Joss: She comes up the causeway with her cart every evening to take my customers home. Stop her.", "Bäcker Joss: Sie kommt jeden Abend mit ihrem Karren den Damm herauf und nimmt meine Kunden mit. Halt sie auf."),
                ("Baker Joss: I never started this. You do believe I never started this?", "Bäcker Joss: Ich hab damit nicht angefangen. Du glaubst mir doch, dass ich nicht angefangen hab?")],
     "choice": (("You're the victim here.", "Du bist hier das Opfer."), ("How heavy was your first one?", "Wie schwer war dein erstes?"),
                ("Baker Joss: Thank you. It's a relief to hear it from someone I'm not paying.", "Bäcker Joss: Danke. Es tut gut, das von jemandem zu hören, den ich nicht bezahle."),
                ("Baker Joss: Two pounds. 'Jutta's raisins have legs.' It was a light rumour. A joke, really.", "Bäcker Joss: Zwei Pfund. 'Juttas Rosinen haben Beine.' Ein leichtes Gerücht. Eigentlich ein Witz.")),
     "go": ("Baker Joss: Jutta is on the Tollchain Causeway with her cart. Tell her the truth hurts. Then show her.", "Bäcker Joss: Jutta ist mit ihrem Karren auf dem Zollkettendamm. Sag ihr, die Wahrheit tut weh. Dann zeig es ihr."),
     "reward_lines": [("Baker Joss: You beat her? Bless you. Here, from the shop. Jutta says I bought the first rumour. A rumour, that. I sold it on already.", "Bäcker Joss: Du hast sie geschlagen? Gott segne dich. Hier, aus dem Laden. Jutta sagt, ich hab das erste Gerücht gekauft. Auch nur ein Gerücht. Hab ich schon weiterverkauft.")],
     "reward_doubt_lines": [("Baker Joss: You beat her, and you know about the raisins. Here. Double. Remedies. For whatever you might be tempted to say.", "Bäcker Joss: Du hast sie geschlagen, und du weißt von den Rosinen. Hier. Das Doppelte. Heilmittel. Gegen alles, was du vielleicht sagen möchtest.")],
     "after": ("Baker Joss: Jutta and I share a stall now. We split the customers and the rumours. Mine are heavier.", "Bäcker Joss: Jutta und ich teilen uns jetzt einen Stand. Wir teilen die Kunden und die Gerüchte. Meine sind schwerer."),
     "steps": [("tallowmarket_rumour_room", "villager", "ebba",
                [("Rumour Girl Ebba: The ash bread? Four pounds, paid in flour. We don't get paid in flour often. It gets in the gossip.", "Gerüchtemädchen Ebba: Das Aschebrot? Vier Pfund, bezahlt in Mehl. In Mehl werden wir selten bezahlt. Das staubt in den Klatsch."),
                 ("Rumour Girl Ebba: The buyer's mark is in the Weigh House book. Everything heavy is.", "Gerüchtemädchen Ebba: Das Zeichen des Käufers steht im Buch vom Waaghaus. Wie alles Schwere.")],
                ("Rumour Girl Ebba: A good rumour keeps a week. A true one goes off by supper.", "Gerüchtemädchen Ebba: Ein gutes Gerücht hält eine Woche. Ein wahres ist bis zum Abendessen verdorben."), None),
               ("tallowmarket_weigh_house", "villager", "gundel",
                [("Scale Girl Gundel: Four pounds, ash bread. Signed with a pretzel. That's the bakery by the quay. Jutta's.", "Waagmädchen Gundel: Vier Pfund, Aschebrot. Unterschrieben mit einer Brezel. Das ist die Bäckerei am Kai. Juttas."),
                 ("Scale Girl Gundel: Line above it: two pounds, 'raisins with legs', signed with a loaf. I'm sure that's nothing.", "Waagmädchen Gundel: Die Zeile darüber: zwei Pfund, 'Rosinen mit Beinen', unterschrieben mit einem Brotlaib. Das hat sicher nichts zu bedeuten.")],
                ("Scale Girl Gundel: I only weigh. If I started judging, there'd be a queue.", "Waagmädchen Gundel: Ich wiege nur. Wenn ich anfangen würde zu urteilen, gäbe es eine Schlange."), None)],
     "betrayer": ("tollchain_causeway", "villager", "jutta", ("Baker Jutta", "Bäckerin Jutta"),
                  [("Jutta: Joss sent you? Did he tell you about my raisins? No. He wouldn't.", "Jutta: Joss schickt dich? Hat er dir von meinen Rosinen erzählt? Nein. Natürlich nicht.")],
                  [("Jutta: Flat. Like his sourdough.", "Jutta: Platt. Wie sein Sauerteig."),
                   ("Jutta: Ask him who bought the first rumour. Ask him what he signs with.", "Jutta: Frag ihn, wer das erste Gerücht gekauft hat. Frag ihn, womit er unterschreibt.")],
                  None,
                  ("Jutta: We share a stall. I count the till. He counts me counting.", "Jutta: Wir teilen uns einen Stand. Ich zähle die Kasse. Er zählt mit, wie ich zähle.")),
     "stages": [("Somebody bought a heavy rumour about Baker Joss's bread. Find the buyer.", "Jemand hat ein schweres Gerücht über das Brot von Bäcker Joss gekauft. Finde den Käufer.", "Tallowmarket"),
                ("The buyer's mark is in the Weigh House book. Read it.", "Das Zeichen des Käufers steht im Buch vom Waaghaus. Lies es.", "Weigh House"),
                ("The rumour was signed with a pretzel: his sister Jutta. Tell Joss.", "Das Gerücht wurde mit einer Brezel unterschrieben: seine Schwester Jutta. Sag es Joss.", "Tallowmarket"),
                ("Beat Baker Jutta on the Tollchain Causeway.", "Schlag Bäckerin Jutta auf dem Zollkettendamm.", "Tollchain Causeway"),
                ("Joss bought the first rumour. They share a stall now.", "Joss hat das erste Gerücht gekauft. Jetzt teilen sie sich einen Stand.", "Tallowmarket")]},

    {"id": "eel_rent", "turns": True, "road": "rookery_cut", "reward": ("cooling_gel", 4),
     "giver": ("hookwick", "elder", "odd"),
     "intro": [("Rent Man Odd: My tenants vanish the night before rent day. Six this year. I worry about them. I worry about the rent more, but still.", "Mietmann Odd: Meine Mieter verschwinden in der Nacht vor dem Zahltag. Sechs dieses Jahr. Ich mache mir Sorgen um sie. Um die Miete mehr, aber trotzdem."),
               ("Rent Man Odd: Find out where they go. I only want to help them. With the arrears.", "Mietmann Odd: Finde heraus, wohin sie gehen. Ich will ihnen nur helfen. Bei den Rückständen.")],
     "wait": ("Rent Man Odd: The Eel Smokery looks out on the night boats. And runaways go inland by the Rookery Cut.", "Mietmann Odd: Die Aalräucherei schaut auf die Nachtboote. Und Ausreißer gehen über die Krähenschneise ins Land."),
     "reveal": [("Rent Man Odd: She told you I sell the passage myself. Well. A landlord provides. Shelter, then transport.", "Mietmann Odd: Sie hat dir gesagt, dass ich die Überfahrt selbst verkaufe. Na ja. Ein Vermieter sorgt für seine Leute. Erst Obdach, dann Beförderung."),
                ("Rent Man Odd: The boat goes to the foundry. Brannoc pays per head. The tenants work off the rent. Some pay in years. Rent is rent.", "Mietmann Odd: Das Boot fährt zur Gießerei. Brannoc zahlt pro Kopf. Die Mieter arbeiten die Miete ab. Manche zahlen in Jahren. Miete ist Miete."),
                ("Rent Man Odd: I sent you to find the one who got away. You found her. Thank you. You've a strong back yourself, I notice.", "Mietmann Odd: Ich hab dich geschickt, um die eine zu finden, die entkommen ist. Du hast sie gefunden. Danke. Du hast selbst einen kräftigen Rücken, wie ich sehe.")],
     "steps": [("hookwick_eel_smokery", "villager", "lueder",
                [("Smoke Boy Lüder: The tenants? They leave by boat, the night before rent day. Somebody pays their passage. They look so grateful.", "Räucherjunge Lüder: Die Mieter? Die fahren mit dem Boot weg, in der Nacht vor dem Zahltag. Jemand zahlt ihre Überfahrt. Sie schauen so dankbar."),
                 ("Smoke Boy Lüder: One jumped off at the bend and ran up the Rookery Cut. She wasn't grateful any more.", "Räucherjunge Lüder: Eine ist an der Biegung abgesprungen und die Krähenschneise hochgerannt. Die war nicht mehr dankbar.")],
                ("Smoke Boy Lüder: The eels all go the same way too. Nobody asks them either.", "Räucherjunge Lüder: Die Aale nehmen auch alle denselben Weg. Die fragt auch keiner."), None),
               ("rookery_cut", "villager", "frauke",
                [("Runaway Frauke: Odd sold me the passage himself. 'A fresh start, no rent.' The boat turned for the foundry before the first bridge.", "Ausreißerin Frauke: Odd hat mir die Überfahrt selbst verkauft. 'Ein Neuanfang, keine Miete.' Vor der ersten Brücke drehte das Boot zur Gießerei ab."),
                 ("Runaway Frauke: Don't tell him where I am. He'll say he's worried. He always says he's worried.", "Ausreißerin Frauke: Sag ihm nicht, wo ich bin. Er wird sagen, er macht sich Sorgen. Das sagt er immer.")],
                ("Runaway Frauke: I sleep in the hedge. The hedge has never raised the rent.", "Ausreißerin Frauke: Ich schlafe in der Hecke. Die Hecke hat noch nie die Miete erhöht."), None)],
     "betrayer": ("hookwick", "elder", "odd_boat", ("Landlord Odd", "Vermieter Odd"),
                  [("Odd: The night boat has one seat free. I'd hate to waste it.", "Odd: Im Nachtboot ist noch ein Platz frei. Den würde ich ungern verschwenden.")],
                  [("Odd: Evicted. Me. From my own quay.", "Odd: Rausgeworfen. Ich. Von meinem eigenen Kai."),
                   ("Odd: Take the gel. It's for the foundry burns. The tenants won't be needing it. They've stopped coming back.", "Odd: Nimm das Gel. Es ist gegen Brandwunden aus der Gießerei. Die Mieter brauchen es nicht mehr. Sie kommen nicht mehr zurück.")],
                  [("You take Odd's cooling gel and his passenger list. Six names are crossed out. The seventh is Frauke. The eighth is yours.", "Du nimmst Odds Kühlgel und seine Passagierliste. Sechs Namen sind durchgestrichen. Der siebte ist Frauke. Der achte ist deiner.")],
                  ("Odd: I've lowered the rent. Nobody believes me. That's the worst of it.", "Odd: Ich hab die Miete gesenkt. Keiner glaubt mir. Das ist das Schlimmste.")),
     "stages": [("Rent Man Odd's tenants vanish the night before rent day. Find out where they go.", "Die Mieter von Mietmann Odd verschwinden in der Nacht vor dem Zahltag. Finde heraus, wohin.", "Hookwick"),
                ("One tenant jumped off the night boat and ran up the Rookery Cut. Find her.", "Eine Mieterin ist vom Nachtboot gesprungen und die Krähenschneise hochgerannt. Finde sie.", "Rookery Cut"),
                ("Odd sold the passage himself. Ask him where the boat goes.", "Odd hat die Überfahrt selbst verkauft. Frag ihn, wohin das Boot fährt.", "Hookwick"),
                ("Odd sells his tenants to the foundry, and the boat has a seat free. Beat him in Hookwick.", "Odd verkauft seine Mieter an die Gießerei, und im Boot ist ein Platz frei. Schlag ihn in Hookwick.", "Hookwick"),
                ("Odd lowered the rent. Nobody believes him.", "Odd hat die Miete gesenkt. Keiner glaubt ihm.", "Hookwick")]},

    {"id": "bought_boos", "turns": False, "road": "smelters_drift", "reward": ("guard_brew", 2), "reward_doubt": ("guard_brew", 4),
     "giver": ("larkspur_heights", "villager", "alban"),
     "intro": [("Tenor Alban: They boo me. Every night, third act, the same six voices. Somebody is paying for it. Nobody boos that well for free.", "Tenor Alban: Sie buhen mich aus. Jeden Abend, dritter Akt, dieselben sechs Stimmen. Jemand bezahlt dafür. So gut buht keiner umsonst."),
               ("Tenor Alban: Find out who. I am an artist. I have no enemies. Only colleagues.", "Tenor Alban: Finde heraus, wer. Ich bin Künstler. Ich habe keine Feinde. Nur Kollegen.")],
     "wait": ("Tenor Alban: The ladies in the Quiet Salon know who pays for what. And the claque drinks on Smelter's Drift, where nobody hears them practise.", "Tenor Alban: Die Damen im Stillen Salon wissen, wer wofür zahlt. Und die Claque trinkt auf der Schmelzerhalde, wo keiner sie üben hört."),
     "reveal": [("Tenor Alban: Fitz. My understudy. Little Fitz, who carries my scarf. He pays six men to boo me so he can sing the fourth act.", "Tenor Alban: Fitz. Meine Zweitbesetzung. Der kleine Fitz, der meinen Schal trägt. Er bezahlt sechs Männer fürs Buhen, damit er den vierten Akt singen darf."),
                ("Tenor Alban: He waits on the drift tonight to pay them again. Go. Silence him. Artistically.", "Tenor Alban: Er wartet heute Nacht auf der Halde, um sie wieder zu bezahlen. Geh. Bring ihn zum Schweigen. Künstlerisch."),
                ("Tenor Alban: I have never paid a claque in my life. You believe that, of course.", "Tenor Alban: Ich habe in meinem Leben keine Claque bezahlt. Das glaubst du natürlich.")],
     "choice": (("Of course, maestro.", "Natürlich, Maestro."), ("Who booed Fitz in spring?", "Wer hat Fitz im Frühling ausgebuht?"),
                ("Tenor Alban: 'Maestro.' Say it again. Slower.", "Tenor Alban: 'Maestro.' Sag es nochmal. Langsamer."),
                ("Tenor Alban: That was criticism. Paid criticism is still criticism.", "Tenor Alban: Das war Kritik. Bezahlte Kritik ist immer noch Kritik.")),
     "go": ("Tenor Alban: Fitz is on Smelter's Drift. Don't touch his throat. I want him to hear himself lose.", "Tenor Alban: Fitz ist auf der Schmelzerhalde. Fass seine Kehle nicht an. Er soll sich verlieren hören."),
     "reward_lines": [("Tenor Alban: You beat him? Bravo! Here, from my dressing room. The claque works for me again. They always did, on weekdays.", "Tenor Alban: Du hast ihn geschlagen? Bravo! Hier, aus meiner Garderobe. Die Claque arbeitet wieder für mich. Unter der Woche tat sie das schon immer.")],
     "reward_doubt_lines": [("Tenor Alban: You beat him. And you know about spring. Here. Twice the brew. An artist pays for silence. It's the only review that counts.", "Tenor Alban: Du hast ihn geschlagen. Und du weißt vom Frühling. Hier. Doppelt so viel Gebräu. Ein Künstler zahlt für Schweigen. Die einzige Kritik, die zählt.")],
     "after": ("Tenor Alban: Fitz carries my scarf again. I check it for pins.", "Tenor Alban: Fitz trägt wieder meinen Schal. Ich suche ihn nach Nadeln ab."),
     "steps": [("larkspur_heights_salon", "villager", "amalia",
                [("Lady Amalia: The boos? Bought at the Counting House, dear. Account 'A Friend of Music'. So is the applause. Different account.", "Dame Amalia: Die Buhrufe? Im Kontor gekauft, meine Liebe. Konto 'Ein Freund der Musik'. Der Applaus auch. Anderes Konto."),
                 ("Lady Amalia: The claque itself drinks out on Smelter's Drift. Ask them who the friend is. Bring something to hit them with.", "Dame Amalia: Die Claque selbst trinkt draußen auf der Schmelzerhalde. Frag sie, wer der Freund ist. Bring etwas zum Zuschlagen mit.")],
                ("Lady Amalia: I never boo. I simply leave, loudly.", "Dame Amalia: Ich buhe nie. Ich gehe einfach, und zwar laut."), None),
               ("smelters_drift", "villager", "claque",
                [("Claque Leader Bruno: Who pays for the boos? That's trade knowledge. You want it, you audition.", "Claqueführer Bruno: Wer für die Buhrufe zahlt? Betriebsgeheimnis. Wenn du es willst, sing erst mal vor.")],
                ("Claque Leader Bruno: The understudy pays for boos. The tenor pays for bravos. We do both in one evening. It's honest work, if you hum.", "Claqueführer Bruno: Die Zweitbesetzung zahlt für Buhs. Der Tenor zahlt für Bravos. Wir machen beides an einem Abend. Ehrliche Arbeit, wenn man dabei summt."),
                (("The Claque", "Die Claque"),
                 [("Claque Leader Bruno: Bravo. Fine. It's Fitz, the understudy. He pays Tuesdays. And in spring the tenor paid us to boo Fitz. We're very fair.", "Claqueführer Bruno: Bravo. Gut. Es ist Fitz, die Zweitbesetzung. Er zahlt dienstags. Und im Frühling hat uns der Tenor bezahlt, damit wir Fitz ausbuhen. Wir sind sehr gerecht.")]))],
     "betrayer": ("smelters_drift", "villager", "fitz", ("Understudy Fitz", "Zweitbesetzung Fitz"),
                  [("Fitz: Alban sent you. He sends everyone. He once sent me for his scarf during my own solo.", "Fitz: Alban schickt dich. Er schickt jeden. Einmal hat er mich während meines eigenen Solos seinen Schal holen lassen.")],
                  [("Fitz: Off key. Me. On the one night someone was listening.", "Fitz: Falsch gesungen. Ich. Am einzigen Abend, an dem jemand zugehört hat."),
                   ("Fitz: Tell him the fourth act is his. I'll have the fifth. There's a death in the fifth.", "Fitz: Sag ihm, der vierte Akt gehört ihm. Ich nehme den fünften. Im fünften stirbt einer.")],
                  None,
                  ("Fitz: I carry the scarf. I've had it lengthened. No reason.", "Fitz: Ich trage den Schal. Ich hab ihn verlängern lassen. Ohne Grund.")),
     "stages": [("Six voices boo Tenor Alban every night. Find out who pays them.", "Sechs Stimmen buhen Tenor Alban jeden Abend aus. Finde heraus, wer sie bezahlt.", "Larkspur Heights"),
                ("The claque drinks on Smelter's Drift. Make them say who pays.", "Die Claque trinkt auf der Schmelzerhalde. Bring sie dazu zu sagen, wer zahlt.", "Smelter's Drift"),
                ("The understudy Fitz pays for the boos. Tell Alban.", "Die Zweitbesetzung Fitz zahlt für die Buhrufe. Sag es Alban.", "Larkspur Heights"),
                ("Beat Understudy Fitz on Smelter's Drift.", "Schlag Zweitbesetzung Fitz auf der Schmelzerhalde.", "Smelter's Drift"),
                ("Alban paid the claque first. Fitz carries the scarf again.", "Alban hat die Claque zuerst bezahlt. Fitz trägt wieder den Schal.", "Larkspur Heights")]},

    {"id": "seven_keys", "turns": False, "road": "weeping_locks", "reward": ("revival_leaf", 2),
     "giver": ("hookwick_lock_office", "villager", "mina"),
     "intro": [("Mina: My father was lock clerk before Pim. He sits in the cells for copying Odile's key. He can't even copy a signature.", "Mina: Mein Vater war Schleusenschreiber vor Pim. Er sitzt in der Zelle, weil er Odiles Schlüssel kopiert haben soll. Er kann nicht mal eine Unterschrift kopieren."),
               ("Mina: Find out who really cut the copies. Please. He's all I have. He and the house, and the house is in his name.", "Mina: Finde heraus, wer die Kopien wirklich gefeilt hat. Bitte. Er ist alles, was ich habe. Er und das Haus, und das Haus läuft auf seinen Namen.")],
     "wait": ("Mina: Old Fritha in the Tackle Room fishes things out of the canal. And key cutters hide in the Smugglers' Culvert.", "Mina: Die alte Fritha in der Angelstube fischt Dinge aus dem Kanal. Und Schlüsselfeiler verstecken sich im Schmugglerkanal."),
     "reveal": [("Mina: Seven copies, ordered by a Syndicate runner. So it wasn't Father. Thank you. Oh, thank you.", "Mina: Sieben Kopien, bestellt von einem Syndikatsläufer. Also war es nicht Vater. Danke. Oh, danke."),
                ("Mina: The runner still has the order slip. With the slip Father walks free. Get it from him. He hides in the culvert.", "Mina: Der Läufer hat noch den Bestellzettel. Mit dem Zettel kommt Vater frei. Hol ihn dir. Er versteckt sich im Kanal.")],
     "go": ("Mina: The runner is in the Smugglers' Culvert. Bring me the slip. Only the slip. Don't read it.", "Mina: Der Läufer ist im Schmugglerkanal. Bring mir den Zettel. Nur den Zettel. Lies ihn nicht."),
     "reward_lines": [("Mina: The slip! Signed by me, yes. I told you not to read it. Father stays where he is. The house needed a clear name on it. Here. For not telling.", "Mina: Der Zettel! Von mir unterschrieben, ja. Ich hab gesagt, lies ihn nicht. Vater bleibt, wo er ist. Das Haus brauchte einen klaren Namen. Hier. Fürs Nichtweitersagen.")],
     "after": ("Mina: I visit Father on Sundays. He's proud of me. He doesn't know why yet.", "Mina: Sonntags besuche ich Vater. Er ist stolz auf mich. Er weiß noch nicht, warum."),
     "steps": [("hookwick_tackle_shop", "villager", "enno",
                [("Bait Boy Enno: Fritha hooked a lump of wax last week. A key pressed in it. Big key. Lock-gate big.", "Köderjunge Enno: Fritha hat letzte Woche einen Klumpen Wachs am Haken gehabt. Ein Schlüssel reingedrückt. Großer Schlüssel. Schleusentorgroß."),
                 ("Bait Boy Enno: It floated out of the Smugglers' Culvert, under the Weeping Locks. There's a cutter down there called Hask.", "Köderjunge Enno: Es kam aus dem Schmugglerkanal getrieben, unter den Weinenden Schleusen. Da unten sitzt ein Feiler namens Hask.")],
                ("Bait Boy Enno: Worms don't lie. That's why nobody here keeps them long.", "Köderjunge Enno: Würmer lügen nicht. Darum behält sie hier keiner lange."), None),
               ("smugglers_culvert", "elder", "hask",
                [("Key Cutter Hask: Odile's key? Seven copies. Best work I ever did. A Syndicate runner brought the wax and the coin.", "Schlüsselfeiler Hask: Odiles Schlüssel? Sieben Kopien. Meine beste Arbeit. Ein Syndikatsläufer brachte das Wachs und die Münzen."),
                 ("Key Cutter Hask: The old clerk? Never saw him. A girl collected the keys. Polite. Counted them twice.", "Schlüsselfeiler Hask: Der alte Schreiber? Nie gesehen. Ein Mädchen hat die Schlüssel abgeholt. Höflich. Hat zweimal nachgezählt.")],
                ("Key Cutter Hask: I kept an eighth. A man needs a pension.", "Schlüsselfeiler Hask: Einen achten hab ich behalten. Ein Mann braucht eine Rente."), None)],
     "betrayer": ("smugglers_culvert", "ranger", "runner", ("Syndicate Runner Veit", "Syndikatsläufer Veit"),
                  [("Veit: The girl sent you for the slip? She sent me for the wax. She sends well, that one.", "Veit: Das Mädchen schickt dich wegen des Zettels? Mich hat sie wegen des Wachses geschickt. Die kann schicken.")],
                  [("Veit: Take the slip. Read the name at the bottom before you hand it over. Just for your education.", "Veit: Nimm den Zettel. Lies den Namen ganz unten, bevor du ihn abgibst. Nur zu deiner Bildung."),
                   ("Veit: The father confessed to protect her. She let him. That's what I call a family business.", "Veit: Der Vater hat gestanden, um sie zu schützen. Sie hat ihn gelassen. Das nenne ich einen Familienbetrieb.")],
                  None,
                  ("Veit: I run for whoever pays. Lately it's a girl with a house.", "Veit: Ich laufe für jeden, der zahlt. Neuerdings für ein Mädchen mit Haus.")),
     "stages": [("Mina's father is in the cells for copying the Lock Rift key. Find out who really cut the copies.", "Minas Vater sitzt in der Zelle, weil er den Schlüssel zum Schleusenriss kopiert haben soll. Finde heraus, wer die Kopien wirklich gefeilt hat.", "Lock Office"),
                ("The wax floated out of the Smugglers' Culvert. Find the key cutter Hask.", "Das Wachs kam aus dem Schmugglerkanal getrieben. Finde den Schlüsselfeiler Hask.", "Smugglers' Culvert"),
                ("A Syndicate runner ordered seven copies. Tell Mina in the Lock Office.", "Ein Syndikatsläufer hat sieben Kopien bestellt. Sag es Mina im Schleusenamt.", "Lock Office"),
                ("Get the order slip from the runner in the Smugglers' Culvert.", "Hol dir den Bestellzettel vom Läufer im Schmugglerkanal.", "Smugglers' Culvert"),
                ("Mina signed the order herself. Her father stays in the cells.", "Mina hat die Bestellung selbst unterschrieben. Ihr Vater bleibt in der Zelle.", "Lock Office")]},

    {"id": "dark_lamps", "turns": True, "road": "bellrope_marsh", "reward": ("max_tonic", 4),
     "giver": ("lastlamp", "villager", "nils"),
     "intro": [("Lamp Boy Nils: The lamps on the marsh edge go out, one a night. Somebody steals the oil. Then people stray off the path.", "Lampenjunge Nils: Die Lampen am Moorrand gehen aus, jede Nacht eine. Jemand klaut das Öl. Dann kommen Leute vom Weg ab."),
               ("Lamp Boy Nils: Find the oil thief. I'm only a boy. I just find the purses in the morning. To hand in.", "Lampenjunge Nils: Finde den Öldieb. Ich bin nur ein Junge. Ich finde morgens bloß die Börsen. Zum Abgeben.")],
     "wait": ("Lamp Boy Nils: The oil is counted in the Lamp Store. And the reed folk on the Bellrope Marsh see who walks the edge at night.", "Lampenjunge Nils: Das Öl wird im Lampenlager gezählt. Und die Schilfleute im Glockenseilmoor sehen, wer nachts am Rand entlanggeht."),
     "reveal": [("Lamp Boy Nils: A small one with a can, pouring it into the marsh? Small. Well. I haven't grown much this year.", "Lampenjunge Nils: Ein Kleiner mit einer Kanne, der es ins Moor gießt? Klein. Na ja. Ich bin dieses Jahr kaum gewachsen."),
                ("Lamp Boy Nils: No lamp, no path. No path, they stray. They stray, they drop things. I find the things. I'm good at finding.", "Lampenjunge Nils: Keine Lampe, kein Weg. Kein Weg, sie verirren sich. Sie verirren sich, sie verlieren Sachen. Ich finde die Sachen. Finden kann ich gut."),
                ("Lamp Boy Nils: I asked you so there'd be a thief to blame. You'll do. Strangers always do.", "Lampenjunge Nils: Ich hab dich gefragt, damit es einen Dieb gibt, dem man die Schuld geben kann. Du reichst. Fremde reichen immer.")],
     "steps": [("lastlamp_lamp_store", "villager", "gerd",
                [("Oil Boy Gerd: Every can is counted. One goes out each night for 'the night round'. Signed with an N.", "Öljunge Gerd: Jede Kanne wird gezählt. Jede Nacht geht eine raus für 'die Nachtrunde'. Unterschrieben mit einem N."),
                 ("Oil Boy Gerd: There is no night round. Ask the reed folk on the Bellrope Marsh where the can goes.", "Öljunge Gerd: Es gibt keine Nachtrunde. Frag die Schilfleute im Glockenseilmoor, wohin die Kanne geht.")],
                ("Oil Boy Gerd: Oil for one more year, Sten says. Less, the way it's going.", "Öljunge Gerd: Öl für ein Jahr noch, sagt Sten. Weniger, so wie es läuft."), None),
               ("bellrope_marsh", "elder", "alma",
                [("Reed Woman Alma: The oil thief? A small one, with a can. Pours the oil in the marsh, puts the lamp out, sits down and waits.", "Schilffrau Alma: Der Öldieb? Ein Kleiner, mit einer Kanne. Gießt das Öl ins Moor, löscht die Lampe, setzt sich hin und wartet."),
                 ("Reed Woman Alma: In the morning he walks the edge with a sack. Whistling. A child's tune.", "Schilffrau Alma: Am Morgen geht er mit einem Sack den Rand ab. Pfeifend. Ein Kinderlied.")],
                ("Reed Woman Alma: I keep to the dark. Nobody robs you in the dark here. They wait for you to leave it.", "Schilffrau Alma: Ich bleibe im Dunkeln. Im Dunkeln raubt dich hier keiner aus. Sie warten, bis du rauskommst."), None)],
     "betrayer": ("lastlamp", "villager", "nils_sack", ("Lamp Boy Nils", "Lampenjunge Nils"),
                  [("Nils: Help! Thief! Oil thief! That's my line, anyway. Nobody's awake to hear it.", "Nils: Hilfe! Dieb! Öldieb! Das ist jedenfalls mein Text. Es ist nur keiner wach, der ihn hört.")],
                  [("Nils: Not fair. You're bigger. Everybody's bigger.", "Nils: Nicht gerecht. Du bist größer. Alle sind größer."),
                   ("Nils: Take the sack. It's only tonics. The purses I already handed in. To me.", "Nils: Nimm den Sack. Sind nur Tränke. Die Börsen hab ich schon abgegeben. Bei mir.")],
                  [("You take Nils's sack: four tonics, eleven left boots and a lamp key. The lamps on the edge burn again that night.", "Du nimmst Nils' Sack: vier Tränke, elf linke Stiefel und einen Lampenschlüssel. In der Nacht brennen die Lampen am Rand wieder.")],
                  ("Nils: I light the lamps now. All of them. Nan watches me do it. Every one.", "Nils: Ich zünde jetzt die Lampen an. Alle. Nan schaut mir dabei zu. Bei jeder.")),
     "stages": [("The lamps on the marsh edge go out one a night. Lamp Boy Nils wants the oil thief found.", "Die Lampen am Moorrand gehen aus, jede Nacht eine. Lampenjunge Nils will, dass der Öldieb gefunden wird.", "Lastlamp"),
                ("A can goes out each night for a round that does not exist. Ask the reed folk on the Bellrope Marsh.", "Jede Nacht geht eine Kanne raus für eine Runde, die es nicht gibt. Frag die Schilfleute im Glockenseilmoor.", "Bellrope Marsh"),
                ("The thief is small and whistles a child's tune. Ask Nils.", "Der Dieb ist klein und pfeift ein Kinderlied. Frag Nils.", "Lastlamp"),
                ("Nils puts the lamps out and picks up what the lost drop. Stop him in Lastlamp.", "Nils löscht die Lampen und sammelt ein, was die Verirrten verlieren. Halt ihn in Lastlamp auf.", "Lastlamp"),
                ("The lamps on the edge burn again.", "Die Lampen am Rand brennen wieder.", "Lastlamp")]},
]

SOLID = set("~THR#SCWo^|L@wBvY")


def flag(g, step):
    return "q2_%s_%s" % (g["id"], step)


def road_of(q, mid):
    """The road whose kinds and rings a figure on [mid] uses."""
    if mid in q.ROUTES:
        return mid
    if mid in PLACES:
        return PLACES[mid][0]
    raise SystemExit("%s is not on a road" % mid)


def road_team(q, road, offset, levels):
    """len(levels) kinds of [road] (sheet slots and fill-ins), turned by [offset], within three elements."""
    r = q.ROUTES[road]
    kinds = [q.slot_species(s) for s in r["slots"]] + [sp for sp, _ in q.FILL[road]]
    kinds = kinds[offset % len(kinds):] + kinds[:offset % len(kinds)]
    for pick in itertools.combinations(kinds, len(levels)):
        els = set()
        for sp in pick:
            els.update(q.SPECIES[sp]["elements"])
        if len(els) <= 3:
            return q.check_team(road, [{"species": sp, "level": lv} for sp, lv in zip(pick, levels)])
    raise SystemExit("%s: no %d kinds within three elements" % (road, len(levels)))


# --- Free cells -----------------------------------------------------------------------------
def _taken(q, mid):
    """Cells of [mid] that are in use, and the cells that have to stay clear around them."""
    m = q.MAPS[mid]
    used, near = set(), set()
    for n in m.get("npcs", []):
        used.add((n["x"], n["y"]))
        for s in n.get("schedule", []):
            if "x" in s:
                used.add((s["x"], s["y"]))
    for n in STORY_NPCS.get(mid, []):
        used.add((n["x"], n["y"]))
    for stops in TRANSIT_STOPS:
        if mid in stops:
            used.add((stops[mid][0], stops[mid][1]))
    for key in ("warps", "signs", "secrets", "blocks"):
        for e in m.get(key, []):
            near.add((e["x"], e["y"]))
    for key in ("heal_point", "square"):
        if key in m:
            near.add(tuple(m[key]))
    for y, row in enumerate(m["rows"]):
        for x, ch in enumerate(row):
            if ch in "DSo=X":
                near.add((x, y))
    return used, near


def _reach(m, blocked):
    rows = m["rows"]
    todo = [(w["x"], w["y"]) for w in m.get("warps", [])]
    seen = set(todo)
    while todo:
        x, y = todo.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= ny < len(rows) and 0 <= nx < len(rows[ny]) and (nx, ny) not in seen and (nx, ny) not in blocked \
                    and rows[ny][nx] not in SOLID:
                seen.add((nx, ny))
                todo.append((nx, ny))
    return seen


def free_cell(q, mid, key):
    """A free, open cell of [mid] for the figure [key]: on grass or floor, not beside another figure, a
    door, a sign, a find or a way out, and no cell that anyone could walk to before is cut off by it."""
    m = q.MAPS[mid]
    rows = m["rows"]
    used, near = _taken(q, mid)
    before = _reach(m, used)
    cells = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in ".f" or (x, y) not in before:
                continue
            if any(abs(x - ux) <= 1 and abs(y - uy) <= 1 for ux, uy in used):
                continue
            if any(abs(x - nx) + abs(y - ny) <= 1 for nx, ny in near):
                continue
            open_sides = sum((nx, ny) in before for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            if open_sides < 3:
                continue
            # Cells open on all four sides first; a cell against a wall only when a small room has no other.
            cells.append((4 - open_sides, zlib.crc32(("%s:%d,%d" % (key, x, y)).encode()), x, y))
    for _, _, x, y in sorted(cells):
        if _reach(m, used | {(x, y)}) == before - {(x, y)}:
            return x, y
    raise SystemExit("%s: no free cell for %s" % (mid, key))


def place(q, mid, id_, dialogue, sprite, **kw):
    x, y = free_cell(q, mid, id_)
    q.MAPS[mid]["npcs"].append(q.npc(id_, x, y, "down", dialogue, sprite, **kw))


STORY_NPCS = {}
TRANSIT_STOPS = []


def _load_shared(q):
    d = json.load(open(os.path.join(q.ROOT, "data", "story_npcs.json"), encoding="utf-8"))
    STORY_NPCS.update({mid: e.get("npcs", []) for mid, e in d.items() if isinstance(e, dict)})
    lay = json.load(open(os.path.join(q.ROOT, "data", "world_layout.json"), encoding="utf-8"))
    TRANSIT_STOPS[:] = [ln.get("stops", {}) for ln in lay.get("lines", {}).values()]


# --- Build ----------------------------------------------------------------------------------
def wayfarer(q, mid, x, y, facing, sprite, wid, title, talk, intro, defeat, offset):
    road = road_of(q, mid)
    lo, hi = q.ROUTES[road]["ring"]
    crew = road_team(q, road, offset, [lo + 1, hi] if mid in q.ROUTES else [hi - 1, hi, hi])
    k = "%s_%s" % (mid, wid)
    n = q.npc(wid, x, y, facing, q.text(k, q.lines(talk)), sprite, trainer=q.tr(*title),
              intro=q.text(k + "_intro", q.lines(intro)), defeat=q.text(k + "_defeat", q.lines(defeat)),
              money=max(e["level"] for e in crew) * 40, team=crew)
    q.MAPS[mid]["npcs"].append(n)


def places(q):
    for i, (mid, (road, name, backdrop, rows, sign)) in enumerate(PLACES.items()):
        sx, sy = ROAD_STAIRS
        rr = q.MAPS[road]["rows"]
        if rr[sy][sx] != "." or rr[ROAD_LANDING[1]][ROAD_LANDING[0]] != ".":
            raise SystemExit("%s: no open ground for the stairs at %d,%d" % (road, sx, sy))
        rr[sy] = rr[sy][:sx] + "=" + rr[sy][sx + 1:]
        q.MAPS[road]["warps"].append(q.warp(sx, sy, mid, PLACE_LANDING[0], PLACE_LANDING[1], "up"))
        q.text(mid + "_sign", [q.tr(*name), q.tr(*sign)])
        q.add(mid, {"name": q.tr(*name), "biome": "dungeon", "backdrop": backdrop, "rows": list(rows),
                    "warps": [q.warp(PLACE_STAIRS[0], PLACE_STAIRS[1], road, ROAD_LANDING[0], ROAD_LANDING[1], "right")],
                    "npcs": [], "signs": [{"x": PLACE_SIGN[0], "y": PLACE_SIGN[1], "dialogue": "%s/%s_sign" % (q.DIA, mid)}],
                    "secrets": [q.secret(x, y, item, "find_%s_%d" % (mid, j + 1)) for j, (x, y, item) in enumerate(PLACE_FINDS[mid])]})
        q.INTERIORS[mid] = road
    for i, (mid, x, y, facing, sprite, wid, title, talk, intro, defeat) in enumerate(PLACE_WAYFARERS):
        wayfarer(q, mid, x, y, facing, sprite, wid, title, talk, intro, defeat, i)
    for i, (road, (sprite, wid, title, talk, intro, defeat)) in enumerate(ROAD_WAYFARERS.items()):
        x, y = free_cell(q, road, wid)
        wayfarer(q, road, x, y, "down", sprite, wid, title, talk, intro, defeat, i + 2)


def build(q):
    _load_shared(q)
    places(q)
    goals, duels = [], {}
    for i, g in enumerate(GOALS):
        gid = g["id"]
        asked, s1, s2, reveal, done, paid, trust, doubt = (flag(g, s) for s in ("asked", "s1", "s2", "reveal", "done", "paid", "trust", "doubt"))
        k = "q2_" + gid
        hi = q.ROUTES[g["road"]]["ring"][1]

        def pay(item):
            return "set_flag %s; give_item %s %d; quest_stage %s 4" % (paid, item[0], item[1], k)

        # Giver: a chain of "if"s, last state first.
        gm, gs, gname = g["giver"]
        q.text(k + "_wait", q.lines(g["wait"]))
        rev = {"if": {"flag": s2}, "else": k + "_wait", "lines": q.lines(*g["reveal"]),
               "action": "set_flag %s; quest_stage %s 3" % (reveal, k)}
        if "choice" in g:
            yes, no, yes_reply, no_reply = g["choice"]
            q.text(k + "_trust", q.lines(yes_reply))
            q.text(k + "_doubt", q.lines(no_reply))
            rev["choices"] = [{"text": q.tr(*yes), "flag": trust, "next": k + "_trust"},
                              {"text": q.tr(*no), "flag": doubt, "next": k + "_doubt"}]
        q.text(k + "_reveal", rev)
        nxt = k + "_reveal"
        if not g["turns"]:
            q.text(k + "_go", {"if": {"flag": reveal}, "else": nxt, "lines": q.lines(g["go"])})
            q.text(k + "_reward", {"if": {"flag": done}, "else": k + "_go", "lines": q.lines(*g["reward_lines"]), "action": pay(g["reward"])})
            nxt = k + "_reward"
            if "choice" in g:
                # Doubting them pays better: they buy your silence.
                q.text(k + "_reward_doubt", {"if": {"flag": [done, doubt]}, "else": k + "_reward", "lines": q.lines(*g["reward_doubt_lines"]),
                                             "action": pay(g["reward_doubt"])})
                nxt = k + "_reward_doubt"
            q.text(k + "_after", {"if": {"flag": paid}, "else": nxt, "lines": q.lines(g["after"])})
            nxt = k + "_after"
        giver = q.text(k, {"if": {"not_flag": asked}, "else": nxt, "lines": q.lines(*g["intro"]), "action": "set_flag " + asked})
        extra = {"hide_flag": reveal} if g["turns"] else {}
        place(q, gm, k + "_" + gname, giver, gs, **extra)
        # Steps.
        for n, ((sm, ss, sid, talk, after, duel), (shown, sets)) in enumerate(zip(g["steps"], [(asked, s1), (s1, s2)])):
            sk = "%s_%s" % (k, sid)
            q.text(sk + "_after", q.lines(after))
            stage = "quest_stage %s %d" % (k, n + 1)
            if duel:
                title, won = duel
                road = road_of(q, sm)
                top = q.ROUTES[road]["ring"][1]
                duels[sk] = {"trainer": q.tr(*title), "team": road_team(q, road, i + 1, [top - 1, top - 1, top]), "ai": 2,
                             "money": top * 45, "defeat": q.text(sk + "_won", {"lines": q.lines(*won), "action": stage}),
                             "win_flags": [sets]}
                d = q.text(sk, {"if": {"not_flag": sets}, "else": sk + "_after", "lines": q.lines(*talk), "action": "battle " + sk})
            else:
                d = q.text(sk, {"if": {"not_flag": sets}, "else": sk + "_after", "lines": q.lines(*talk),
                                "action": "set_flag %s; %s" % (sets, stage)})
            place(q, sm, sk, d, ss, show_flag=shown)
        # Betrayer.
        bm, bs, bid, title, intro, defeat, loot, after = g["betrayer"]
        bk = "%s_%s" % (k, bid)
        crew = road_team(q, g["road"], i, [hi - 1, hi, hi + 1])
        if g["turns"]:
            q.text(bk + "_after", q.lines(after))
            talk = q.text(bk, {"if": {"not_flag": paid}, "else": bk + "_after", "lines": q.lines(*loot), "action": pay(g["reward"])})
        else:
            talk = q.text(bk, q.lines(after))
        place(q, bm, bk, talk, bs, trainer=q.tr(*title), show_flag=reveal,
              intro=q.text(bk + "_intro", q.lines(*intro)), defeat=q.text(bk + "_defeat", q.lines(*defeat)),
              money=(hi + 1) * 50, team=crew, win_flags=[done], no_rematch=True)
        stages = [{"text": q.tr(en, de), "where": w} for en, de, w in g["stages"]]
        goals.append({"id": k, "text": stages[0]["text"], "where": stages[0]["where"], "show": asked, "done": done,
                      "progress": [s1, s2, reveal, done], "stages": stages})
    patch_quests(q.ROOT, goals)
    patch_duels(q.ROOT, duels)
    return goals


def patch_quests(root, goals):
    """Replaces the q2_* side goals in data/quests.json (one goal per line, like the rest)."""
    path = os.path.join(root, "data", "quests.json")
    rows = open(path, encoding="utf-8").read().split("\n")
    rows = [r for r in rows if '{"id": "q2_' not in r]
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
    """Replaces the q2_* story duels in data/story_battles.json."""
    path = os.path.join(root, "data", "story_battles.json")
    d = json.load(open(path, encoding="utf-8"))
    d = {k: v for k, v in d.items() if not k.startswith("q2_")}
    d.update(duels)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
        f.write("\n")
