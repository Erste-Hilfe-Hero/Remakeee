"""Solenne side content (Act IV): the Brass Veil's cistern under Ochrewell (a three-floor
dungeon), the Veil's rival heir Corin, the eight brass seals, the five IOUs and the three
prepaid graves. The town figures stand in data/story_npcs.json ("ochrewell"); their texts and
the clan texts for the Brass Veil (data/clans.json) live in data/dialogue/solenne_side.json,
written here. Edit here, then run tools/art/build_world.py.

How the way opens:
  ochrewell -> veil_cistern     the Veil counting house door, open once Factor Lusk is beaten
  floor 1 -> 2 -> 3             the valve rows (cistern_valve_1, cistern_valve_2)
  Lusk in the strongroom        after the Sun Rift (rift_sun_sealed)
"""
from common import check_rows, lines, secret, team, tr, warp
from rifts12 import gate, put, wayfarer

GROUP = ["veil_cistern"]
MID = "veil_cistern"
SIDE = "solenne_side"

# Valve rows: cells and the order (indices) they are turned in, per floor.
VALVES = [
    {"cells": [(2, 2), (5, 2), (8, 2)], "order": [1, 2, 0], "flag": "cistern_valve_1", "wall": (1, 6),
     "names": [("A valve marked DEBT.", "Ein Ventil mit der Aufschrift SCHULD."),
               ("A valve marked INTEREST.", "Ein Ventil mit der Aufschrift ZINSEN."),
               ("A valve marked FEES.", "Ein Ventil mit der Aufschrift GEBÜHREN.")],
     "hint": ("Scratched under the pipes: Interest first. Then fees. Debt last. Debt is always last.", "Unter die Rohre geritzt: Zuerst Zinsen. Dann Gebühren. Schuld zuletzt. Schuld kommt immer zuletzt.")},
    {"cells": [(2, 1), (9, 1), (2, 3), (9, 3)], "order": [3, 0, 2, 1], "flag": "cistern_valve_2", "wall": (1, 6),
     "names": [("A valve marked WIDOWS.", "Ein Ventil mit der Aufschrift WITWEN."),
               ("A valve marked ORPHANS.", "Ein Ventil mit der Aufschrift WAISEN."),
               ("A valve marked WELLS.", "Ein Ventil mit der Aufschrift BRUNNEN."),
               ("A valve marked MISC.", "Ein Ventil mit der Aufschrift SONSTIGES.")],
     "hint": ("A clerk's note: Misc, widows, wells, orphans. Alphabetical was too honest.", "Notiz eines Schreibers: Sonstiges, Witwen, Brunnen, Waisen. Alphabetisch war zu ehrlich.")},
]

# Brass seals: 1-3 in Ochrewell (story_npcs.json), 4-8 down here: (floor, x, y).
SEALS = [(0, 10, 7), (1, 10, 6), (1, 8, 8), (2, 9, 1), (2, 10, 4)]
SEAL_TEXT = [
    ("A brass seal nailed to a pipe: 'Property of the Veil. So is this pipe. So are you, if you stand here long.'", "Ein Messingsiegel an einem Rohr: 'Eigentum des Schleiers. Dieses Rohr auch. Du auch, wenn du hier lange stehst.'"),
    ("A brass seal on a bucket. The bucket has a contract. The contract has a bucket.", "Ein Messingsiegel auf einem Eimer. Der Eimer hat einen Vertrag. Der Vertrag hat einen Eimer."),
    ("A brass seal stamped on a tiny chair. Someone small worked off a debt here.", "Ein Messingsiegel auf einem winzigen Stuhl. Jemand Kleines hat hier eine Schuld abgearbeitet."),
    ("A brass seal on the strongroom bell: 'Ring for service. Pay for silence.'", "Ein Messingsiegel an der Tresorglocke: 'Für Bedienung läuten. Für Ruhe zahlen.'"),
    ("A brass seal on a ledger cabinet. It's warm. Ledgers here are kept by the fire, in case.", "Ein Messingsiegel an einem Schrank voller Bücher. Er ist warm. Bücher werden hier am Feuer gelagert, für alle Fälle."),
]
TOWN_SEALS = [
    ("A brass seal on a dome door: 'This house belongs to the Veil. The family is on loan.'", "Ein Messingsiegel an einer Kuppeltür: 'Dieses Haus gehört dem Schleier. Die Familie ist geliehen.'"),
    ("A brass seal on a gravestone. Even the dead pay ground rent here.", "Ein Messingsiegel auf einem Grabstein. Selbst die Toten zahlen hier Bodenpacht."),
    ("A brass seal on the well rope. Of course it is.", "Ein Messingsiegel am Brunnenseil. Natürlich."),
]
# IOUs: 1-2 in Ochrewell (story_npcs.json), 3-5 down here: (floor, x, y).
IOUS = [(0, 9, 3), (1, 3, 8), (2, 1, 1)]
IOU_TEXT = [
    ("An IOU: 'Hadi the potter owes the Veil one kiln, two domes and his good thumb.'", "Ein Schuldschein: 'Töpfer Hadi schuldet dem Schleier einen Brennofen, zwei Kuppeln und seinen guten Daumen.'"),
    ("An IOU: 'Ranya owes forty sacks of pepper. Interest payable in sneezes.'", "Ein Schuldschein: 'Ranya schuldet vierzig Sack Pfeffer. Zinsen zahlbar in Niesern.'"),
    ("An IOU: 'Sefa owes the well. The whole well. Signed under protest, then signed again.'", "Ein Schuldschein: 'Sefa schuldet den Brunnen. Den ganzen Brunnen. Unter Protest unterschrieben, dann noch einmal.'"),
]
TOWN_IOUS = [
    ("An IOU stuck in a crack: 'Tobs owes for one shovel. The shovel owes Tobs for forty years.'", "Ein Schuldschein in einem Spalt: 'Tobs schuldet eine Schaufel. Die Schaufel schuldet Tobs vierzig Jahre.'"),
    ("An IOU tied to a lamp: 'Oskin owes for fakes. Fake fakes. The Veil wants real money.'", "Ein Schuldschein an einer Lampe: 'Oskin schuldet für Fälschungen. Falsche Fälschungen. Der Schleier will echtes Geld.'"),
]


def build(world):
    side_texts(world)
    cistern(world)


def side_texts(world):
    t = {}
    for i, text in enumerate(TOWN_SEALS):
        t["seal_%d" % (i + 1)] = seal_entry(i + 1, text)
    for i, text in enumerate(TOWN_IOUS):
        t["iou_%d" % (i + 1)] = iou_entry(i + 1, text)
    t["seal_empty"] = lines(("Just a nail hole now. The seal is in your bag, being property.", "Nur noch ein Nagelloch. Das Siegel ist in deiner Tasche und ist Eigentum."))
    t["iou_empty"] = lines(("Nothing left here but a smell of ink and regret.", "Hier ist nichts mehr außer einem Geruch nach Tinte und Reue."))
    # Old Mags the pawnbroker: the brass seals.
    t["mags"] = {"if": {"not_flag": "s4_seals_done"}, "else": "mags_after",
                 "lines": lines(("Old Mags: Pawnbroker. Fence. Grandmother of nine, landlady of none, thanks to the Veil.", "Alte Mags: Pfandleiherin. Hehlerin. Großmutter von neun, Vermieterin von keinem, dank dem Schleier."),
                                ("Old Mags: Every brass seal in this town is a family the Veil owns. Eight of them. Pry them off and bring them to me.", "Alte Mags: Jedes Messingsiegel in dieser Stadt ist eine Familie, die dem Schleier gehört. Acht Stück. Hebel sie ab und bring sie mir."),
                                ("Old Mags: I melt them down into spoons. Very satisfying. Spoons can't foreclose.", "Alte Mags: Ich schmelze sie zu Löffeln ein. Sehr befriedigend. Löffel können nicht pfänden.")),
                 "action": "set_flag s4_seals_asked",
                 "next": "mags_count"}
    t["mags_count"] = {"if": {"flag": ["veil_seal_%d" % n for n in range(1, 9)]},
                       "lines": lines(("Old Mags: All eight! Look at that. Eight families, and not one of them will ever thank you. Typical.", "Alte Mags: Alle acht! Sieh mal an. Acht Familien, und keine wird sich je bedanken. Typisch."),
                                      ("Old Mags: Here, a Bond Seal of my own. Honest brass. Well. Mostly honest.", "Alte Mags: Hier, ein Bandsiegel von mir. Ehrliches Messing. Na ja. Größtenteils ehrlich.")),
                       "action": "set_flag s4_seals_done; give_item rg_bond_seal; trust mags 10"}
    t["mags_after"] = lines(("Old Mags: Spoon? I have three hundred. Each one a little revenge.", "Alte Mags: Löffel? Ich habe dreihundert. Jeder eine kleine Rache."))
    # Qadir the water thief: the IOUs, a favor and a warning about the strongroom.
    t["qadir"] = {"if": {"not_flag": "favor_qadir_dig"}, "else": "qadir_iou",
                  "lines": lines(("Qadir: Qadir. I steal water. From the Veil, so it's more of a refund.", "Qadir: Qadir. Ich klaue Wasser. Vom Schleier, also eher eine Rückerstattung."),
                                 ("Qadir: I'm digging a free well behind the domes. Lend me a Spirling with strong claws for a night?", "Qadir: Ich grabe hinter den Kuppeln einen freien Brunnen. Leihst du mir für eine Nacht einen Spirling mit starken Klauen?")),
                  "choices": [{"text": tr("Lend a Spirling", "Einen Spirling leihen"), "action": "favor qadir_dig"}, {"text": tr("Not tonight", "Heute nicht")}]}
    t["qadir_iou"] = {"if": {"not_flag": "s4_ious_done"}, "else": "qadir_after",
                      "lines": lines(("Qadir: The Veil keeps the town's IOUs in the cistern. Five of them hurt the most.", "Qadir: Der Schleier hält die Schuldscheine der Stadt in der Zisterne. Fünf davon tun am meisten weh."),
                                     ("Qadir: Bring me those five and we'll have a little bonfire. Bring marshmallows. Kidding. Bring more IOUs.", "Qadir: Bring mir diese fünf, dann machen wir ein kleines Lagerfeuer. Bring Marshmallows mit. Spaß. Bring mehr Schuldscheine.")),
                      "action": "set_flag s4_ious_asked", "next": "qadir_count"}
    t["qadir_count"] = {"if": {"flag": ["veil_iou_%d" % n for n in range(1, 6)]},
                        "lines": lines(("Qadir: Five! Watch them curl. Best smell in Solenne, burning debt.", "Qadir: Fünf! Sieh, wie sie sich kräuseln. Der beste Geruch in Solenne, brennende Schulden."),
                                       ("Qadir: And a word, friend: Lusk's strongroom locks from the outside. Wedge the door before you sign anything.", "Qadir: Und ein Wort, Freund: Lusks Tresorraum schließt von außen. Verkeil die Tür, bevor du irgendwas unterschreibst.")),
                        "action": "set_flag s4_ious_done; set_flag c4_qadir_warned; give_item max_tonic 3; trust qadir 10"}
    t["qadir_after"] = lines(("Qadir: The town's still poor. But now it's poor on its own account. That's progress.", "Qadir: Die Stadt ist immer noch arm. Aber jetzt auf eigene Rechnung. Das ist Fortschritt."))
    t["qadir_betray"] = lines(("Qadir brings your Spirling back at dawn. Its keepsake is gone. 'The well needed a down payment,' he says. 'Sorry. Mostly.'", "Qadir bringt deinen Spirling im Morgengrauen zurück. Sein Andenken fehlt. 'Der Brunnen brauchte eine Anzahlung', sagt er. 'Tut mir leid. Größtenteils.'"))
    t["qadir_reward"] = lines(("Qadir: The well runs! Free water, first in six years. The Veil will be livid. Take this, from the whole street.", "Qadir: Der Brunnen läuft! Freies Wasser, das erste seit sechs Jahren. Der Schleier wird toben. Nimm das, von der ganzen Straße."))
    t["qadir_kept"] = lines(("Qadir: Hit rock. Your Spirling's fine, my back isn't. Next time.", "Qadir: Auf Fels gestoßen. Deinem Spirling geht's gut, meinem Rücken nicht. Nächstes Mal."))
    # Saffi, the Veil clerk who leaks: a tip that is a trap.
    t["saffi"] = {"if": {"not_flag": "favor_saffi_code"}, "else": "saffi_after",
                  "lines": lines(("Saffi: Veil clerk, third grade. I file things. Sometimes I file them in other people's ears.", "Saffi: Schleier-Schreiberin, dritte Klasse. Ich lege Dinge ab. Manchmal in fremden Ohren."),
                                 ("Saffi: The cistern's back door is open at the west pipe tonight. Free tip. Believe me?", "Saffi: Die Hintertür der Zisterne steht heute Nacht am Westrohr offen. Gratistipp. Glaubst du mir?")),
                  "choices": [{"text": tr("I believe you", "Ich glaube dir"), "action": "favor saffi_code"}, {"text": tr("Nice try", "Netter Versuch")}]}
    t["saffi_after"] = {"lines": lines(("Saffi: Don't look at me like that. I have quotas.", "Saffi: Schau mich nicht so an. Ich habe Quoten.")),
                        "after_flag": {"flag": "ledger_deed", "lines": lines(("Saffi: I sold Kaia's deed to Sefa's cousin. And to Sefa. And to Kaia. Business is business.", "Saffi: Ich habe Kaias Urkunde an Sefas Cousin verkauft. Und an Sefa. Und an Kaia. Geschäft ist Geschäft."))}}
    t["saffi_betray"] = lines(("At the west pipe the door is open. So are the arms of three Veil guards.", "Am Westrohr steht die Tür offen. Die Arme dreier Schleierwachen auch."),
                              ("'Saffi says hi,' says one. 'And bills you for the overtime.'", "'Saffi lässt grüßen', sagt einer. 'Und berechnet dir die Überstunden.'"))
    t["saffi_reward"] = lines(("At the west pipe a crate waits, Veil-stamped and unlocked. Even traitors have off days.", "Am Westrohr wartet eine Kiste, mit Schleierstempel und offen. Selbst Verräter haben schlechte Tage."))
    t["saffi_kept"] = lines(("At the west pipe: a locked door and a cat. The cat looks unimpressed.", "Am Westrohr: eine verschlossene Tür und eine Katze. Die Katze wirkt unbeeindruckt."))
    # Dunya the cart widow: warns about Kaia's deed.
    t["dunya"] = {"lines": lines(("Dunya: My husband drove carts for the Veil. Now he drives nothing. They kept the cart.", "Dunya: Mein Mann fuhr Karren für den Schleier. Jetzt fährt er gar nichts. Den Karren haben sie behalten."),
                                 ("Dunya: If Kaia gives you a gift for the town, read it first. She wraps knives in ribbon.", "Dunya: Wenn Kaia dir ein Geschenk für die Stadt gibt, lies es vorher. Sie wickelt Messer in Schleifen.")),
                  "action": "set_flag c4_dunya_warned"}
    # Kaia after her Rift: the deed (scripted betrayal kaia_deed).
    t["kaia_town"] = {"if": {"not_flag": "betrayal_kaia_deed"}, "else": "kaia_town_after",
                      "lines": lines(("Kaia: Oh, it's you. My favourite ruin. No hard feelings, I bill them separately.", "Kaia: Ach, du. Meine Lieblingsruine. Nichts für ungut, das stelle ich separat in Rechnung."),
                                     ("Kaia: I want to make amends. Take this deed to Sefa at the well. A gift to the town, from me.", "Kaia: Ich will etwas gutmachen. Bring diese Urkunde zu Sefa am Brunnen. Ein Geschenk an die Stadt, von mir.")),
                      "choices": [{"text": tr("Read it first", "Erst lesen"), "if": {"flag": "c4_dunya_warned"}, "action": "betrayal kaia_deed"},
                                  {"text": tr("Deliver it", "Zustellen"), "action": "betrayal kaia_deed"}]}
    t["kaia_town_after"] = {"lines": lines(("Kaia: Trust is a currency. I just prefer the other kind.", "Kaia: Vertrauen ist eine Währung. Ich bevorzuge nur die andere Sorte.")),
                            "after_flag": {"flag": "veil_vault_beaten", "lines": lines(("Kaia: Lusk is ruined? Shame. I'll send flowers. Then the invoice for the flowers.", "Kaia: Lusk ist ruiniert? Schade. Ich schicke Blumen. Und dann die Rechnung für die Blumen."))}}
    t["deed_caught"] = lines(("You read the deed. It sells the town well to one K. Oasis-Holder, for one coin, signed by Sefa (forged).", "Du liest die Urkunde. Sie verkauft den Stadtbrunnen an eine gewisse K. Oasenhalterin, für eine Münze, unterschrieben von Sefa (gefälscht)."),
                             ("Sefa burns it in the lamp. 'She wanted the well for herself. Not for the Veil. For herself.'", "Sefa verbrennt sie in der Lampe. 'Sie wollte den Brunnen für sich. Nicht für den Schleier. Für sich selbst.'"))
    t["deed_struck"] = lines(("Sefa signs it with a smile, then stops smiling. The well now belongs to one K. Oasis-Holder.", "Sefa unterschreibt lächelnd und hört dann auf zu lächeln. Der Brunnen gehört jetzt einer gewissen K. Oasenhalterin."),
                             ("A turnstile goes up by noon. The first ticket has your name on it, as a thank-you.", "Bis Mittag steht ein Drehkreuz da. Das erste Ticket trägt deinen Namen, als Dankeschön."))
    t["ledger_deed"] = lines(("The well deed", "Die Brunnenurkunde"),
                             ("Kaia handed you a 'gift' for the town: the deed that sold Ochrewell's well to herself.", "Kaia gab dir ein 'Geschenk' für die Stadt: die Urkunde, die den Brunnen von Ochrewell an sie selbst verkaufte."))
    # Corin, the Veil heir: three rival duels.
    t["corin_1"] = {"if": {"not_flag": "veil_corin_1_beaten"}, "else": "corin_1_after", "lines": lines(("Corin: Corin Lusk. Nephew. Heir. Future owner of your shoes, probably.", "Corin: Corin Lusk. Neffe. Erbe. Wahrscheinlich künftiger Besitzer deiner Schuhe."),
                                   ("Corin: Uncle says you're an asset. I say let's see the books. Duel me.", "Corin: Onkel sagt, du bist ein Wert. Ich sag, zeig mal die Bücher. Duellier dich mit mir.")),
                    "action": "battle veil_corin_1"}
    t["corin_1_defeat"] = {"lines": lines(("Corin: Down a whole team. Uncle will dock my allowance. Again.", "Corin: Ein ganzes Team weg. Onkel kürzt mir das Taschengeld. Schon wieder."),
                                          ("Corin: Meet me in the cistern. I'll have better Spirlings. Bought, obviously.", "Corin: Wir sehen uns in der Zisterne. Mit besseren Spirlings. Gekauft, natürlich.")),
                           "action": "trust corin 10"}
    t["corin_1_after"] = lines(("Corin: Cistern. Bring coins. I'm told losing is cheaper in bulk.", "Corin: Zisterne. Bring Münzen mit. Verlieren ist angeblich im Großpack billiger."))
    t["corin_2"] = {"lines": lines(("Corin: Told you. New team, fresh off the auction block. Smells like money.", "Corin: Hab ich doch gesagt. Neues Team, frisch von der Auktion. Riecht nach Geld."),),
                    "action": "battle veil_corin_2"}
    t["corin_2_defeat"] = {"lines": lines(("Corin: Hm. Money doesn't fight. Noted. In red.", "Corin: Hm. Geld kämpft nicht. Notiert. In Rot."),
                                          ("Corin: Uncle's waiting in the strongroom once the sun moves. Don't sign anything he hands you. Or do. I'd inherit sooner.", "Corin: Onkel wartet im Tresorraum, sobald die Sonne wandert. Unterschreib nichts, was er dir gibt. Oder doch. Dann erbe ich schneller.")),
                           "action": "trust corin 10"}
    t["corin_lose"] = lines(("Corin: Put it on your tab. Interest starts yesterday.", "Corin: Schreib's auf deine Rechnung. Die Zinsen laufen seit gestern."))
    t["corin_3"] = {"if": {"not_flag": "veil_corin_3_beaten"}, "else": "corin_after",
                    "lines": lines(("Corin: The Veil's mine now. Uncle's in the books as a write-off. Thanks for that.", "Corin: Der Schleier gehört jetzt mir. Onkel steht als Abschreibung in den Büchern. Danke dafür."),
                                   ("Corin: One last duel. Winner keeps the town's goodwill. Loser keeps the Veil.", "Corin: Ein letztes Duell. Wer gewinnt, behält das Wohlwollen der Stadt. Wer verliert, behält den Schleier.")),
                    "action": "battle veil_corin_3"}
    t["corin_3_defeat"] = {"lines": lines(("Corin: Fine. I'll sell the Veil to the town for one coin. Kaia taught me that one.", "Corin: Schön. Ich verkaufe den Schleier für eine Münze an die Stadt. Den Trick hab ich von Kaia."),
                                          ("Corin: Here's Uncle's private ledger. Every name he ever bought. Burn it or blackmail with it, I don't judge.", "Corin: Hier ist Onkels privates Buch. Jeder Name, den er je gekauft hat. Verbrenn es oder erpress damit Leute, ich urteile nicht.")),
                           "action": "ledger nephew; trust corin 15"}
    t["corin_after"] = {"lines": lines(("Corin: I'm in water reform now. Same water, nicer brochures.", "Corin: Ich mache jetzt in Wasserreform. Dasselbe Wasser, schönere Prospekte.")),
                        "if": {"trust_min": {"corin": 40}}, "else": "corin_after_cold"}
    t["corin_after_cold"] = lines(("Corin: Don't. I'm still deciding if you're a friend or a cost.", "Corin: Lass. Ich entscheide noch, ob du ein Freund bist oder ein Kostenfaktor."))
    t["ledger_nephew"] = lines(("The nephew's ledger", "Das Buch des Neffen"),
                               ("Corin Lusk sold his uncle's private ledger to you after losing to you. Family is the oldest market.", "Corin Lusk gab dir das private Buch seines Onkels, nachdem er gegen dich verlor. Familie ist der älteste Markt."))
    t["corin_bet"] = {"if": {"flag": "veil_vault_beaten"}, "else": "corin_wait", "next": "corin_bet_ask",
                      "lines": lines(("Corin: Well, well. The person who bankrupted my uncle. I should send you a fruit basket.", "Corin: Sieh an. Die Person, die meinen Onkel in den Bankrott getrieben hat. Ich sollte dir einen Obstkorb schicken."))}
    t["corin_wait"] = lines(("Corin: Uncle's still solvent. Ruin him first, then we'll talk about my future.", "Corin: Onkel ist noch zahlungsfähig. Ruinier ihn erst, dann reden wir über meine Zukunft."))
    t["corin_bet_ask"] = {"if": {"not_flag": "favor_corin_bet"}, "else": "corin_3",
                      "lines": lines(("Corin: Before our last duel, a side bet. Stake 500 coins on the town's new water board? Guaranteed returns.", "Corin: Vor unserem letzten Duell eine Nebenwette. Setzt du 500 Münzen auf die neue Wasserbehörde der Stadt? Garantierte Rendite."),),
                      "choices": [{"text": tr("Stake 500 coins", "500 Münzen setzen"), "action": "favor corin_bet"}, {"text": tr("Just duel", "Nur kämpfen"), "next": "corin_3"}]}
    t["corin_bet_betray"] = lines(("Corin: The water board? Dissolved. Your coins? Dissolved with it. Guaranteed, I said. I never said for whom.", "Corin: Die Wasserbehörde? Aufgelöst. Deine Münzen? Mit aufgelöst. Garantiert, hab ich gesagt. Nie gesagt, für wen."))
    t["corin_bet_reward"] = lines(("Corin: The board paid out. Here's your share, and mine. Don't tell Uncle I'm capable of decency.", "Corin: Die Behörde hat ausgezahlt. Hier dein Anteil und meiner. Erzähl Onkel nicht, dass ich zu Anstand fähig bin."))
    t["corin_bet_kept"] = lines(("Corin: Broke even. Your stake, back. That's the most honest thing a Lusk has ever done.", "Corin: Plusminus null. Dein Einsatz, zurück. Das Ehrlichste, was ein Lusk je getan hat."))
    # Bex the undertaker: three graves the Veil paid for in advance.
    t["bex"] = {"lines": lines(("Undertaker Bex: The Veil prepaid three graves. No names. Lovely tips, though.", "Bestatterin Bex: Der Schleier hat drei Gräber vorausbezahlt. Ohne Namen. Aber schönes Trinkgeld."),
                               ("Undertaker Bex: Find out who they're for? I hate digging for strangers. I like to know who to haunt.", "Bestatterin Bex: Findest du raus, für wen sie sind? Ich grabe ungern für Fremde. Ich will wissen, wen ich heimsuchen soll.")),
                "if": {"var_max": {"q_s4_graves_stage": 0}}, "else": "bex_1",
                "action": "set_flag s4_graves_asked; quest_stage s4_graves 1"}
    t["bex_1"] = {"if": {"var_max": {"q_s4_graves_stage": 1}}, "else": "bex_2",
                  "lines": lines(("Undertaker Bex: Any names yet? The Veil keeps its orders in the cistern's lowest room.", "Bestatterin Bex: Schon Namen? Der Schleier bewahrt seine Aufträge im untersten Raum der Zisterne auf."),)}
    t["bex_2"] = {"if": {"var_max": {"q_s4_graves_stage": 2}}, "else": "bex_3",
                  "lines": lines(("Undertaker Bex: Kaia, Qadir and... you? Ha! I'll put you in the shady one. You're welcome.", "Bestatterin Bex: Kaia, Qadir und... du? Ha! Dich leg ich ins schattige. Gern geschehen."),
                                 ("Undertaker Bex: Tell you what. Beat Lusk, and we fill all three with sand and a rude headstone each.", "Bestatterin Bex: Weißt du was. Schlag Lusk, dann füllen wir alle drei mit Sand und je einem frechen Grabstein.")),
                  "action": "quest_stage s4_graves 3"}
    t["bex_3"] = {"if": {"flag": "veil_vault_beaten"}, "else": "bex_wait",
                  "lines": lines(("Undertaker Bex: Three rude headstones. 'Here lies nobody. Paid in full.' My best work.", "Bestatterin Bex: Drei freche Grabsteine. 'Hier liegt niemand. Voll bezahlt.' Meine beste Arbeit."),
                                 ("Undertaker Bex: Have the Veil's tip money. It's cursed, but it spends.", "Bestatterin Bex: Nimm das Trinkgeld vom Schleier. Es ist verflucht, aber man kann's ausgeben.")),
                  "action": "set_flag s4_graves_done; give_item spark_drop 2; quest_stage s4_graves 4", "once": True}
    t["bex_wait"] = lines(("Undertaker Bex: Lusk first. Then headstones. I've got the chisel warming.", "Bestatterin Bex: Erst Lusk. Dann Grabsteine. Der Meißel wärmt schon vor."))
    world.add_text(SIDE, t)


def seal_entry(n, text):
    return {"if": {"not_flag": "veil_seal_%d" % n}, "else": "seal_empty", "lines": lines(text,
            ("You pry the seal off.", "Du hebelst das Siegel ab.")), "action": "set_flag veil_seal_%d" % n}


def iou_entry(n, text):
    return {"if": {"not_flag": "veil_iou_%d" % n}, "else": "iou_empty", "lines": lines(text,
            ("You pocket the IOU.", "Du steckst den Schuldschein ein.")), "action": "set_flag veil_iou_%d" % n}


def cistern(world):
    rows0 = ["@@@@@==@@@@@",
             "@.........:@",
             "@.........:@",
             "@.........:@",
             "@::......::@",
             "@::........@",
             "@..........@",
             "@..........@",
             "@..........@",
             "@@@@@__@@@@@"]
    rows1 = ["@@@@@==@@@@@",
             "@..........@",
             "@..::..::..@",
             "@....@@....@",
             "@....@@....@",
             "@::......::@",
             "@..........@",
             "@..........@",
             "@..........@",
             "@@@@@==@@@@@"]
    rows2 = ["@@@@@@@@@@@@",
             "@.........:@",
             "@:...CC...:@",
             "@..........@",
             "@..........@",
             "@::......::@",
             "@..........@",
             "@@@@@==@@@@@"]
    floors = [rows0, rows1, rows2]
    text = {}
    signs = [[], [], []]
    for n, v in enumerate(VALVES):
        rows = floors[n]
        for i, (x, y) in enumerate(v["cells"]):
            put(rows, x, y, "S")
            key = "valve_%d_%d" % (n + 1, i + 1)
            text[key] = {"lines": lines(v["names"][i]), "action": "bell %s %d %d valve" % (v["flag"], v["order"].index(i) + 1, len(v["cells"]))}
            signs[n].append({"x": x, "y": y, "dialogue": "%s/%s" % (MID, key)})
        wx, wy = v["wall"]
        put(rows, wx, wy, "S")
        text["hint_%d" % (n + 1)] = lines(v["hint"])
        signs[n].append({"x": wx, "y": wy, "dialogue": "%s/hint_%d" % (MID, n + 1)})
    for i, (f, x, y) in enumerate(SEALS):
        put(floors[f], x, y, "S")
        key = "seal_%d" % (i + 4)
        text[key] = seal_entry(i + 4, SEAL_TEXT[i])
        signs[f].append({"x": x, "y": y, "dialogue": "%s/%s" % (MID, key)})
    for i, (f, x, y) in enumerate(IOUS):
        put(floors[f], x, y, "S")
        key = "iou_%d" % (i + 3)
        text[key] = iou_entry(i + 3, IOU_TEXT[i])
        signs[f].append({"x": x, "y": y, "dialogue": "%s/%s" % (MID, key)})
    text["seal_empty"] = lines(("Just a nail hole now.", "Nur noch ein Nagelloch."))
    text["iou_empty"] = lines(("Nothing left here but a smell of ink and regret.", "Hier ist nichts mehr außer einem Geruch nach Tinte und Reue."))
    # The strongroom: the order book (graves quest) and Lusk's note before the Sun Rift.
    put(rows2, 1, 4, "S")
    text["orders"] = {"lines": lines(("The Veil's order book. 'Three graves, prepaid: K. (retired), Q. (thief), and the map kid (pending).'", "Das Auftragsbuch des Schleiers. 'Drei Gräber, vorausbezahlt: K. (im Ruhestand), Q. (Dieb) und das Kartenkind (ausstehend).'"),
                                  ("Pending. How flattering.", "Ausstehend. Wie schmeichelhaft.")),
                      "if": {"var_min": {"q_s4_graves_stage": 1}, "var_max": {"q_s4_graves_stage": 1}}, "else": "orders_read",
                      "action": "quest_stage s4_graves 2"}
    text["orders_read"] = lines(("The Veil's order book. Most entries end in 'collected'.", "Das Auftragsbuch des Schleiers. Die meisten Einträge enden mit 'eingetrieben'."))
    signs[2].append({"x": 1, "y": 4, "dialogue": MID + "/orders"})
    text["note"] = {"if": {"not_flag": "rift_sun_sealed"}, "else": "note_gone",
                    "lines": lines(("A note on the counter: 'Out collecting. Back when the sun moves again. Touch nothing. Everything is counted. L.'", "Ein Zettel auf der Theke: 'Bin eintreiben. Zurück, wenn die Sonne wieder wandert. Nichts anfassen. Alles ist gezählt. L.'"),)}
    text["note_gone"] = lines(("The note is gone. Someone is back.", "Der Zettel ist weg. Jemand ist zurück."))
    signs[2].append({"x": 6, "y": 2, "dialogue": MID + "/note"})
    # Lusk: the scripted betrayal (the truce he offers locks you in), then the boss duel.
    text["lusk"] = {"if": {"not_flag": "betrayal_lusk_vault"}, "else": "lusk_duel",
                    "lines": lines(("Factor Lusk: You again. Let's not fight. Sign this truce and your debts vanish. Have a seat. I'll get the door.", "Faktor Lusk: Schon wieder du. Lass uns nicht kämpfen. Unterschreib diesen Waffenstillstand, und deine Schulden verschwinden. Setz dich. Ich hol die Tür."),),
                    "action": "betrayal lusk_vault"}
    text["lusk_duel"] = {"if": {"not_flag": "veil_vault_beaten"}, "else": "lusk_after",
                         "lines": lines(("Factor Lusk: Fine. We'll do it the expensive way. I'll invoice your next of kin.", "Faktor Lusk: Schön. Dann eben auf die teure Art. Ich schicke die Rechnung an deine Angehörigen."),),
                         "action": "battle veil_vault"}
    text["lusk_after"] = lines(("Factor Lusk: Bankrupt. Do you know what that's like? No. You never had anything to lose.", "Faktor Lusk: Bankrott. Weißt du, wie sich das anfühlt? Nein. Du hattest nie etwas zu verlieren."))
    text["vault_caught"] = lines(("You wedge the door with a ledger before it can shut. Lusk sighs. 'Qadir. Of course. I should have bought him.'", "Du verkeilst die Tür mit einem Buch, bevor sie zufällt. Lusk seufzt. 'Qadir. Natürlich. Ich hätte ihn kaufen sollen.'"))
    text["vault_struck"] = lines(("The door clicks shut behind you. From the other side, Lusk's guards. 'Signature or shovel. Your choice.'", "Die Tür fällt hinter dir ins Schloss. Auf der anderen Seite Lusks Wachen. 'Unterschrift oder Schaufel. Du hast die Wahl.'"))
    text["vault_defeat"] = lines(("Factor Lusk: ...My Spirlings, my brass, my strongroom. All written off.", "Faktor Lusk: ...Meine Spirlings, mein Messing, mein Tresorraum. Alles abgeschrieben."),
                                 ("Factor Lusk: Take the vault key. Corin will want it. He always wanted everything of mine, the vulture. So proud.", "Faktor Lusk: Nimm den Tresorschlüssel. Corin wird ihn wollen. Er wollte immer alles von mir, der Geier. So stolz."))
    text["vault_lose"] = lines(("Factor Lusk: Collected. Come back when you're solvent.", "Faktor Lusk: Eingetrieben. Komm wieder, wenn du zahlungsfähig bist."))
    text["ledger_vault"] = lines(("The strongroom truce", "Der Waffenstillstand im Tresorraum"),
                                 ("Factor Lusk offered you a truce in his strongroom and locked the door behind you while you read it.", "Faktor Lusk bot dir in seinem Tresorraum einen Waffenstillstand an und schloss hinter dir ab, während du ihn last."))
    text["guards_lose"] = lines(("The Veil guards take a fee for your release. They give you a receipt. It's very nicely printed.", "Die Schleierwachen nehmen eine Gebühr für deine Freilassung. Du bekommst eine Quittung. Sehr schön gedruckt."))
    text["sign"] = lines(("THE BRASS VEIL - CISTERN AND COUNTING HOUSE", "DER MESSINGSCHLEIER - ZISTERNE UND ZÄHLHAUS"),
                         ("Water sold by the cup. Souls by arrangement.", "Wasser wird pro Becher verkauft. Seelen nach Vereinbarung."))
    put(rows0, 10, 8, "S")
    signs[0].append({"x": 10, "y": 8, "dialogue": MID + "/sign"})
    world.add_text(MID, text)

    crew0 = [
        wayfarer(world, MID, "clerk_ivo", 8, 5, "left", tr("Veil Clerk Ivo", "Schleierschreiber Ivo"), team(("Scrivane", 40), ("Saltspire", 40), ("Duneshrew", 41)),
                 [("Ivo: I count buckets. Some days the buckets count me.", "Ivo: Ich zähle Eimer. An manchen Tagen zählen die Eimer mich.")],
                 [("Ivo: Unauthorised visitor. That's a fine. Fight me and it's two fines.", "Ivo: Unbefugter Besuch. Das ist eine Strafe. Kämpf gegen mich, dann sind es zwei.")],
                 [("Ivo: Write it down as... no, don't write it down.", "Ivo: Schreib das auf als... nein, schreib das nicht auf.")], 2100),
        wayfarer(world, MID, "guard_pell", 3, 7, "right", tr("Veil Guard Orla", "Schleierwache Orla"), team(("Obsidroth", 41), ("Burinox", 41)),
                 [("Orla: I guard water. Tried drinking on shift once. They docked a week.", "Orla: Ich bewache Wasser. Einmal im Dienst getrunken. Eine Woche Lohn weg.")],
                 [("Orla: Nobody gets past. Nobody's paid me to let them.", "Orla: Keiner kommt vorbei. Mich hat keiner dafür bezahlt.")],
                 [("Orla: Fine, go. I'll tell them you bribed me. Did you? No? Pity.", "Orla: Schön, geh. Ich sag, du hast mich bestochen. Hast du? Nein? Schade.")], 2150),
        wayfarer(world, MID, "clerk_mott", 7, 4, "left", tr("Debt Runner Quill", "Schuldenläufer Quill"), team(("Shimmerlet", 41), ("Highhare", 41), ("Lanternel", 42)),
                 [("Quill: I run debts across town. Fastest legs in Solenne. Need them.", "Quill: Ich trage Schulden durch die Stadt. Schnellste Beine in Solenne. Brauch ich auch.")],
                 [("Quill: You owe me a duel. Everybody owes me something.", "Quill: Du schuldest mir ein Duell. Jeder schuldet mir was.")],
                 [("Quill: Ran out of Spirlings. Running out of town next.", "Quill: Keine Spirlings mehr. Als Nächstes keine Stadt mehr.")], 2200),
    ]
    crew1 = [
        wayfarer(world, MID, "auditor_nell", 3, 5, "right", tr("Veil Auditor Nell", "Schleierprüferin Nell"), team(("Mendlace", 43), ("Glasstarn", 43), ("Orrlet", 42)),
                 [("Nell: I audit the auditors. Somebody has to distrust the distrustful.", "Nell: Ich prüfe die Prüfer. Irgendwer muss den Misstrauischen misstrauen.")],
                 [("Nell: Your numbers don't add up. Let me subtract some.", "Nell: Deine Zahlen gehen nicht auf. Lass mich ein paar abziehen.")],
                 [("Nell: Rounding error. Mine. Don't tell anyone.", "Nell: Rundungsfehler. Meiner. Sag's keinem.")], 2300),
        wayfarer(world, MID, "guard_brack", 8, 4, "left", tr("Veil Guard Brack", "Schleierwache Brack"), team(("Dunebastion", 43), ("Talusgard", 43), ("Calderox", 43)),
                 [("Brack: My last job was breaking legs. This one's breaking spirits. Better hours.", "Brack: Mein letzter Job war Beine brechen. Der hier ist Mut brechen. Bessere Arbeitszeiten.")],
                 [("Brack: Valves don't turn themselves. Neither do I.", "Brack: Ventile drehen sich nicht von allein. Ich auch nicht.")],
                 [("Brack: Broken. Me, I mean. Spirit's fine.", "Brack: Gebrochen. Ich, mein ich. Der Mut ist okay.")], 2350),
    ]
    corin2 = {"id": "corin_2", "x": 6, "y": 6, "facing": "down", "dialogue": SIDE + "/corin_2", "sprite": "ranger", "color": "b08a3a",
              "show_flag": "veil_corin_1_beaten", "hide_flag": "veil_corin_2_beaten"}
    lusk = {"id": "lusk", "x": 5, "y": 3, "facing": "down", "dialogue": MID + "/lusk", "sprite": "villager", "color": "b08a3a",
            "show_flag": "rift_sun_sealed"}
    for n, rows in enumerate(floors):
        check_rows("%s floor %d" % (MID, n), rows)
    f0 = {"name": tr("Veil Cistern", "Schleierzisterne"), "region": "solenne", "biome": "dungeon", "backdrop": "ember", "encounters": MID,
          "rows": rows0,
          "warps": [warp(5, 9, "ochrewell", 9, 14, "down"), warp(6, 9, "ochrewell", 9, 14, "down"),
                    warp(5, 0, MID + "@1", 5, 8, "up"), warp(6, 0, MID + "@1", 6, 8, "up")],
          "npcs": crew0, "signs": signs[0],
          "blocks": [gate(5, 0, "cistern_valve_1"), gate(6, 0, "cistern_valve_1")],
          "secrets": [secret(1, 1, "max_tonic", "find_cistern_corner", 2)]}
    f1 = {"name": tr("Veil Cistern, dry vault", "Schleierzisterne, trockenes Gewölbe"), "rows": rows1,
          "warps": [warp(5, 9, MID, 5, 1, "down"), warp(6, 9, MID, 6, 1, "down"),
                    warp(5, 0, MID + "@2", 5, 6, "up"), warp(6, 0, MID + "@2", 6, 6, "up")],
          "npcs": crew1 + [corin2], "signs": signs[1],
          "blocks": [gate(5, 0, "cistern_valve_2"), gate(6, 0, "cistern_valve_2")],
          "secrets": [secret(10, 8, "power_brew", "find_cistern_vault")]}
    f2 = {"name": tr("Veil Cistern, strongroom", "Schleierzisterne, Tresorraum"), "rows": rows2,
          "warps": [warp(5, 7, MID + "@1", 5, 1, "down"), warp(6, 7, MID + "@1", 6, 1, "down")],
          "npcs": [lusk], "signs": signs[2],
          "secrets": [secret(1, 6, "revival_leaf", "find_cistern_strongroom", 2)]}
    f0["floors"] = [f1, f2]
    world.add_map(MID, f0)
