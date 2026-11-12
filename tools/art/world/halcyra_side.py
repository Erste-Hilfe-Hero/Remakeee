"""Halcyra side content (Era IV, owner rule: every era region 20 h+ of real content). Hooked into
tools/art/world/halcyra.py by one line at its end; the towns stay as halcyra.py draws them.

Adds:
  maps      the Fallen Planet (off Orrery Ridge, west), the Brine Catacombs (off the Mirror Flats,
            east, two levels) and the Gilt Cellars (off the Sunfall Terraces, east, two levels)
  goals     twelve side goals q4_* in data/quests.json, each ending in a betrayal
  trust     three favors and four scripted betrayals (data/clans.json, clan "gilt"), ledger rows
  duels     story duels hs_* in data/story_battles.json
  folk      twelve more Wayfarers; their rings come from the ring range of the road they stand on
  wild      encounter tables of the Fallen Planet and the Brine Catacombs: homes for the Halcyra
            kinds that have no wild home in Halcyra yet

Every goal runs the same way, with flags q4_<id>_<step> (as tools/art/world/quivermoor_side.py):
  giver -> asked, step 1 -> s1, step 2 -> s2, giver -> reveal, betrayer beaten -> done, reward -> paid.
A "duel" betrayer starts a story duel ("battle hs_<id>") instead of being a map Wayfarer. A "twist"
fires a scripted betrayal at the reward (caught when the goal's witness was heard first), a "favor"
is a choice on step 1 whose outcome rides on the hidden trust the answer before it set.

Edit here, then run python3 tools/art/world/halcyra_side.py: it writes data/quests.json,
data/encounters.json, data/clans.json, data/story_battles.json and tools/i18n/de_halcyra_side.py,
then runs tools/art/build_world.py for the maps and dialogue. Then python3 tools/i18n/build.py.
"""
import itertools
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from common import ROOT, check_rows, npc, secret, warp  # noqa: E402

SIDE = "halcyra_side"
GROUP = ["fallen_planet", "brine_catacombs", "gilt_cellars"]
SHEET = json.load(open(os.path.join(ROOT, "data", "region4.json"), encoding="utf-8"))
ROUTE = {r["id"]: r for r in SHEET["routes"]}
# Ring ranges of the new places, one step above the road they open from.
NEW = {"fallen_planet": [86, 89], "brine_catacombs": [84, 87], "gilt_cellars": [88, 91]}
WILD = ["fallen_planet", "brine_catacombs"]
# The Gilt Cellars have no wild table: their Wayfarers field the terrace kinds and the family's own.
CELLAR_KINDS = ["Coronarch", "Rollibex", "Obelith"]

# German of every text this module writes (tools/i18n/de_halcyra_side.py).
MINE = {}


def t(en, de):
    MINE[en] = de
    return common.tr(en, de)


def ls(*pairs):
    return [t(en, de) for en, de in pairs]


# --- Goals ---------------------------------------------------------------------------------------
# giver/step/clue: (map, x, y, facing, sprite, id); a map id "x@1" is the second level of x.
GOALS = [
    {"id": "antidote", "turns": True, "road": "long_stair", "reward": ("max_tonic", 3),
     "giver": ("long_stair", 9, 10, "left", "villager", "benno"),
     "intro": [("Food Taster Benno: I taste for Lord Aurek. Three thousand meals, eleven poisons, not one funeral. Mine, I mean.", "Vorkoster Benno: Ich koste für Herrn Aurek. Dreitausend Mahlzeiten, elf Gifte, keine einzige Beerdigung. Meine, meine ich."),
               ("Food Taster Benno: Someone keeps slipping antidote into my soup. Nobody in this family keeps anyone alive for free. Find out who.", "Vorkoster Benno: Jemand mischt mir ständig Gegengift in die Suppe. In dieser Familie hält niemand einen anderen umsonst am Leben. Finde heraus, wer.")],
     "wait": ("Benno: The herbalist on the White Stair mixes antidotes. And the cellar clerk under the Sunfall Terraces signs for every bottle.", "Benno: Die Kräuterfrau auf der Weißen Treppe mischt Gegengifte. Und der Kellerschreiber unter den Sonnenfall-Terrassen quittiert jede Flasche."),
     "reveal": [("Benno: The order is in my name? Well. I did say nobody keeps me alive for free. I pay myself.", "Benno: Die Bestellung läuft auf meinen Namen? Tja. Ich sagte ja, niemand hält mich umsonst am Leben. Ich bezahle mich selbst."),
                ("Benno: I taste, I live, I add the seasoning afterwards. Lady Seraphine pays per guest. Lord Aurek is the main course.", "Benno: Ich koste, ich lebe, danach würze ich nach. Lady Seraphine zahlt pro Gast. Herr Aurek ist der Hauptgang."),
                ("Benno: And now you know the recipe. Recipes are family secrets. You are not family.", "Benno: Und jetzt kennst du das Rezept. Rezepte sind Familiengeheimnisse. Du gehörst nicht zur Familie.")],
     "steps": [("white_stair", 9, 9, "left", "villager", "wenna",
                [("Herbalist Wenna: Antidote, a flask a week, for the Gilt kitchen. Paid in advance, which is how you know it's for someone important.", "Kräuterfrau Wenna: Gegengift, eine Flasche pro Woche, für die Gilt-Küche. Im Voraus bezahlt, daran erkennt man, dass es für jemand Wichtigen ist."),
                 ("Herbalist Wenna: The bottles go down to the Gilt Cellars. Ask the clerk whose name is on the order.", "Kräuterfrau Wenna: Die Flaschen gehen runter in die Gilt-Keller. Frag den Schreiber, wessen Name auf der Bestellung steht.")],
                ("Herbalist Wenna: I sell poison too. Same shelf. I just turn the labels round.", "Kräuterfrau Wenna: Gift verkaufe ich auch. Selbes Regal. Ich drehe nur die Etiketten um.")),
               ("gilt_cellars", 3, 8, "right", "villager", "tobin",
                [("Cellar Clerk Tobin: The antidote? Ordered by the taster himself. Weekly. He drinks it before every meal he tests.", "Kellerschreiber Tobin: Das Gegengift? Bestellt vom Vorkoster selbst. Wöchentlich. Er trinkt es vor jeder Mahlzeit, die er prüft."),
                 ("Cellar Clerk Tobin: Odd habit for a man paid to fall over. Nine guests have died after he said 'delicious'.", "Kellerschreiber Tobin: Seltsame Angewohnheit für einen Mann, der dafür bezahlt wird umzufallen. Neun Gäste sind gestorben, nachdem er 'köstlich' gesagt hat.")],
                ("Cellar Clerk Tobin: I count bottles. Bottles never lie. People empty them and then lie.", "Kellerschreiber Tobin: Ich zähle Flaschen. Flaschen lügen nie. Leute leeren sie und lügen dann."))],
     "betrayer": ("long_stair", 2, 19, "right", "villager", "benno_fork", ("Food Taster Benno", "Vorkoster Benno"),
                  [("Benno: Say 'delicious'. Everyone says it before they fall over.", "Benno: Sag 'köstlich'. Alle sagen das, bevor sie umfallen.")],
                  [("Benno: Bitter. Very bitter. I'd send it back.", "Benno: Bitter. Sehr bitter. Das würde ich zurückgehen lassen."),
                   ("Benno: Fine. Tell Aurek. He'll hire a taster for his taster.", "Benno: Schön. Sag es Aurek. Er stellt einen Vorkoster für seinen Vorkoster ein.")],
                  [("You take Benno's tasting kit: three tonics and a little spoon engraved 'NOT MINE'.", "Du nimmst Bennos Kostbesteck: drei Tränke und einen kleinen Löffel mit der Gravur 'NICHT MEINER'.")],
                  ("Benno: I've retired. Now I only taste my own cooking. It's the only meal I trust.", "Benno: Ich bin im Ruhestand. Jetzt koste ich nur noch meine eigene Küche. Die einzige Mahlzeit, der ich traue.")),
     "stages": [("Food Taster Benno is being kept alive with antidote. Find out who pays for it.", "Vorkoster Benno wird mit Gegengift am Leben gehalten. Finde heraus, wer es bezahlt.", "The Long Stair"),
                ("The antidote goes to the Gilt Cellars. Ask the cellar clerk whose name is on the order.", "Das Gegengift geht in die Gilt-Keller. Frag den Kellerschreiber, wessen Name auf der Bestellung steht.", "The Gilt Cellars"),
                ("Benno ordered the antidote himself. Ask him why.", "Benno hat das Gegengift selbst bestellt. Frag ihn, warum.", "The Long Stair"),
                ("Benno seasons the meals he tastes. Stop him on the Long Stair.", "Benno würzt die Mahlzeiten nach, die er kostet. Halt ihn auf der Langen Treppe auf.", "The Long Stair"),
                ("The taster has retired. The family still eats carefully.", "Der Vorkoster ist im Ruhestand. Die Familie isst trotzdem vorsichtig.", "The Long Stair")]},

    {"id": "brass_planet", "turns": False, "duel": True, "road": "fallen_planet", "reward": ("revival_leaf", 2),
     "giver": ("great_orrery", 3, 6, "right", "villager", "lio"),
     "intro": [("Apprentice Lio: The missing planet of the Great Orrery! It fell off the ridge in a storm. I'm the only one who knows where.", "Lehrling Lio: Der fehlende Planet des Großen Planetariums! Er ist bei einem Sturm vom Grat gefallen. Nur ich weiß, wo."),
               ("Apprentice Lio: Fetch proof that it's still lying there, and I'll sell it back to the Gilt House. Fifty-fifty. I'm told I have an honest face.", "Lehrling Lio: Bring mir einen Beweis, dass er noch dort liegt, dann verkaufe ich ihn dem Haus Gilt zurück. Halbe-halbe. Man sagt, ich hätte ein ehrliches Gesicht.")],
     "wait": ("Lio: It lies past Orrery Ridge, in a crater. Nan picks scrap there. And Notary Fenwick on the White Stair keeps the deeds.", "Lio: Er liegt hinter dem Planetariumsgrat, in einem Krater. Nan sammelt dort Schrott. Und Notar Fenwick auf der Weißen Treppe verwahrt die Urkunden."),
     "reveal": [("Lio: Three deeds? Ah. Yes. A planet is very big. It seemed a shame to sell it only once.", "Lio: Drei Urkunden? Ah. Ja. Ein Planet ist sehr groß. Es schien schade, ihn nur einmal zu verkaufen."),
                ("Lio: Collector Ambrose of the Gilt House is in the crater now, to take it. Beat him, and the other two families get nothing. Then we split.", "Lio: Sammler Ambrose vom Haus Gilt ist jetzt im Krater, um ihn zu holen. Schlag ihn, dann gehen die anderen zwei Familien leer aus. Dann teilen wir.")],
     "go": ("Lio: The crater, past Orrery Ridge. Go on. I'll keep your half warm.", "Lio: Der Krater, hinter dem Planetariumsgrat. Geh nur. Ich halte deine Hälfte warm."),
     "reward_lines": [("Lio: You beat Ambrose? Wonderful. Here is your half. Half of the advance. Half of the advance minus expenses.", "Lio: Du hast Ambrose geschlagen? Wunderbar. Hier ist deine Hälfte. Die Hälfte des Vorschusses. Die Hälfte des Vorschusses abzüglich Spesen.")],
     "after": ("Lio: I'm selling the crater next. It has a lovely view of the planet.", "Lio: Als Nächstes verkaufe ich den Krater. Er hat einen schönen Blick auf den Planeten."),
     "steps": [("fallen_planet", 3, 4, "right", "elder", "nan",
                [("Scrap Picker Nan: The planet? Big brass ball, dented, smells of money. It's in the crater. Three families have already come to look at it.", "Schrottsammlerin Nan: Der Planet? Große Messingkugel, verbeult, riecht nach Geld. Er liegt im Krater. Drei Familien waren schon da, um ihn anzusehen."),
                 ("Scrap Picker Nan: Each one had a deed for it. Ask the notary how a ball gets three owners.", "Schrottsammlerin Nan: Jede hatte eine Urkunde dafür. Frag den Notar, wie eine Kugel drei Besitzer bekommt.")],
                ("Nan: I sell the dents separately. Very popular with the Gilt cousins.", "Nan: Die Dellen verkaufe ich einzeln. Sehr beliebt bei den Gilt-Vettern.")),
               ("white_stair", 3, 9, "right", "elder", "fenwick",
                [("Notary Fenwick: Three deeds for one planet, all sold by the same seller. Lovely handwriting. Very honest face.", "Notar Fenwick: Drei Urkunden für einen Planeten, alle vom selben Verkäufer. Schöne Handschrift. Sehr ehrliches Gesicht."),
                 ("Notary Fenwick: The seller signed as 'Lio, apprentice'. I stamped all three. I am paid by the stamp, not by the truth.", "Notar Fenwick: Der Verkäufer hat mit 'Lio, Lehrling' unterschrieben. Ich habe alle drei gestempelt. Ich werde pro Stempel bezahlt, nicht pro Wahrheit.")],
                ("Fenwick: Every deed on this stair is legal. Some are even true.", "Fenwick: Jede Urkunde auf dieser Treppe ist rechtsgültig. Manche sind sogar wahr."))],
     "betrayer": ("fallen_planet", 10, 15, "left", "warden", "ambrose", ("Gilt Collector Ambrose", "Gilt-Sammler Ambrose"),
                  [("Ambrose: This planet belongs to the Gilt House. So does the crater. And, as of now, your afternoon.", "Ambrose: Dieser Planet gehört dem Haus Gilt. Der Krater auch. Und ab jetzt dein Nachmittag.")],
                  [("Ambrose: Keep it, then. Lio sold it to me with your name as the courier. The other two families have your name as well.", "Ambrose: Dann behalt ihn. Lio hat ihn mir verkauft, mit deinem Namen als Kurier. Die anderen zwei Familien haben deinen Namen auch."),
                   ("Ambrose: In this family, the one who carries the parcel pays for it.", "Ambrose: In dieser Familie bezahlt, wer das Paket trägt.")],
                  None,
                  ("Ambrose: I collect. You are on a list now. It's a short list. It gets shorter.", "Ambrose: Ich sammle. Du stehst jetzt auf einer Liste. Es ist eine kurze Liste. Sie wird kürzer."),
                  ("Ambrose: The crater keeps what falls into it. Come back when you've grown a little.", "Ambrose: Der Krater behält, was hineinfällt. Komm wieder, wenn du ein bisschen gewachsen bist.")),
     "twist": {"npc": "hs_lio", "role": "orrery apprentice who sells one planet three times", "trust": 20, "use": 70, "road": "fallen_planet",
               "clue": ("great_orrery", 8, 8, "left", "villager", "dita",
                        [("Sweeper Dita: I sweep under the brass arms. Last week I swept up three deed copies with Lio's name. And yours, as courier. Each time.", "Kehrerin Dita: Ich kehre unter den Messingarmen. Letzte Woche habe ich drei Urkundenabschriften mit Lios Namen aufgefegt. Und deinem, als Kurier. Jedes Mal."),
                         ("Sweeper Dita: Keep the copies. I only keep the dust.", "Kehrerin Dita: Behalt die Abschriften. Ich behalte nur den Staub.")],
                        ("Dita: Dust is honest. It settles on everyone.", "Dita: Staub ist ehrlich. Er legt sich auf jeden.")),
               "caught": [("You show Lio the sweeper's copies: three deeds, three families, your name as courier on each.", "Du zeigst Lio die Abschriften der Kehrerin: drei Urkunden, drei Familien, auf jeder dein Name als Kurier."),
                          ("Lio: ...You read the small print. Nobody reads the small print. Fine. Here is the real half. Don't tell the other half of me.", "Lio: ...Du hast das Kleingedruckte gelesen. Niemand liest das Kleingedruckte. Schön. Hier ist die echte Hälfte. Sag es nicht der anderen Hälfte von mir.")],
               "caught_fx": {"coins": 2500, "trust": {"hs_lio": -10}},
               "struck": [("Lio: Oh, and the other two families are outside. I told them you have the planet. You do, technically. You beat the man holding it.", "Lio: Ach, und die anderen zwei Familien warten draußen. Ich habe ihnen gesagt, dass du den Planeten hast. Technisch stimmt das. Du hast den Mann geschlagen, der ihn hielt.")],
               "struck_fx": {"coins": -500},
               "battle": ("planet_buyers", ("Planet Buyers", "Planetenkäufer"),
                          ("Planet Buyer: Keep your planet. We'll buy the next one. There is always a next one.", "Planetenkäufer: Behalt deinen Planeten. Wir kaufen den nächsten. Es gibt immer einen nächsten."),
                          ("The buyers take your coins as a deposit on the planet you don't own.", "Die Käufer nehmen deine Münzen als Anzahlung auf den Planeten, der dir nicht gehört.")),
               "ledger": (("The planet sold three times", "Der dreimal verkaufte Planet"),
                          ("Apprentice Lio sold the Great Orrery's missing planet to three families, each time with your name as the courier.", "Lehrling Lio verkaufte den fehlenden Planeten des Großen Planetariums an drei Familien, jedes Mal mit deinem Namen als Kurier."))},
     "stages": [("Apprentice Lio knows where the Great Orrery's missing planet lies. Find proof.", "Lehrling Lio weiß, wo der fehlende Planet des Großen Planetariums liegt. Finde einen Beweis.", "The Great Orrery"),
                ("Three families have deeds for the planet. Ask Notary Fenwick on the White Stair.", "Drei Familien haben Urkunden für den Planeten. Frag Notar Fenwick auf der Weißen Treppe.", "The White Stair"),
                ("Lio sold the planet three times. Ask him.", "Lio hat den Planeten dreimal verkauft. Frag ihn.", "The Great Orrery"),
                ("Beat Gilt Collector Ambrose in the crater of the Fallen Planet.", "Schlag Gilt-Sammler Ambrose im Krater des Gefallenen Planeten.", "The Fallen Planet"),
                ("The planet stays in the crater. Lio sells the view.", "Der Planet bleibt im Krater. Lio verkauft die Aussicht.", "The Great Orrery")]},

    {"id": "salt_skim", "turns": True, "road": "mirror_flats", "reward": ("strong_tonic", 3),
     "giver": ("mirror_flats", 4, 16, "right", "elder", "imre"),
     "intro": [("Bookkeeper Imre: I keep Halloran's salt books. The barrels leave full and arrive light. Somebody skims.", "Buchhalter Imre: Ich führe Hallorans Salzbücher. Die Fässer gehen voll los und kommen leicht an. Jemand zweigt ab."),
               ("Imre: I suspect my apprentice, Jost. Find proof. Halloran deducts the losses from my wages, and my wages are mostly losses already.", "Imre: Ich verdächtige meinen Lehrling Jost. Finde Beweise. Halloran zieht die Verluste von meinem Lohn ab, und mein Lohn besteht schon fast nur aus Verlusten.")],
     "wait": ("Imre: Jost rolls barrels in the Brine Catacombs, east of the flats. And Hanne dives in the drowned chapel below.", "Imre: Jost rollt Fässer in den Solekatakomben, östlich der Ebene. Und Hanne taucht unten in der ertrunkenen Kapelle."),
     "reveal": [("Imre: A neat hand? Well. Mine is the neatest on the flats. It's my one vanity.", "Imre: Eine ordentliche Hand? Nun. Meine ist die ordentlichste auf der Ebene. Meine einzige Eitelkeit."),
                ("Imre: Halloran pays me in salt and docks me in coin. So I water his salt and blame the boy. Everyone wins except Jost.", "Imre: Halloran bezahlt mich in Salz und zieht mir Münzen ab. Also wässere ich sein Salz und gebe dem Jungen die Schuld. Alle gewinnen, außer Jost."),
                ("Imre: You were supposed to find Jost guilty. Now I have to write you off. I'm very good at writing things off.", "Imre: Du solltest Jost schuldig finden. Jetzt muss ich dich abschreiben. Im Abschreiben bin ich sehr gut.")],
     "steps": [("brine_catacombs", 3, 10, "right", "villager", "jost",
                [("Barrel Boy Jost: Skimming? Me? I can't even count to a barrel. I roll them, I don't open them.", "Fassjunge Jost: Abzweigen? Ich? Ich kann nicht mal bis zu einem Fass zählen. Ich rolle sie, ich mache sie nicht auf."),
                 ("Jost: The light barrels go down to the chapel before they're weighed. Ask Hanne. And don't tell Imre I talked.", "Jost: Die leichten Fässer gehen runter in die Kapelle, bevor sie gewogen werden. Frag Hanne. Und sag Imre nicht, dass ich geredet habe.")],
                ("Jost: Roll, roll, roll. The salt doesn't care who owns it.", "Jost: Rollen, rollen, rollen. Dem Salz ist egal, wem es gehört.")),
               ("brine_catacombs@1", 3, 5, "right", "ranger", "hanne",
                [("Salt Diver Hanne: The light barrels? They come down here half full and go back up with water from the chapel font. Salt water weighs like salt.", "Salztaucherin Hanne: Die leichten Fässer? Die kommen halb voll hier runter und gehen mit Wasser aus dem Kapellenbecken wieder rauf. Salzwasser wiegt wie Salz."),
                 ("Hanne: The man who brings them signs the book with a very neat hand. Bookkeepers have very neat hands.", "Hanne: Der Mann, der sie bringt, unterschreibt das Buch mit sehr ordentlicher Hand. Buchhalter haben sehr ordentliche Hände.")],
                ("Hanne: I dive for what the lake forgot. It forgot a lot. It had help.", "Hanne: Ich tauche nach dem, was der See vergessen hat. Er hat viel vergessen. Man hat ihm geholfen."))],
     "betrayer": ("mirror_flats", 3, 21, "right", "elder", "imre_ink", ("Bookkeeper Imre", "Buchhalter Imre"),
                  [("Imre: Debit: one testimony. Credit: nothing. The books will balance.", "Imre: Soll: eine Zeugenaussage. Haben: nichts. Die Bücher werden aufgehen.")],
                  [("Imre: Overdrawn. Me. I've never been overdrawn.", "Imre: Überzogen. Ich. Ich war noch nie überzogen."),
                   ("Imre: Take the books to Halloran. He'll fire me, then hire me back cheaper. That's how he hired me the first time.", "Imre: Bring die Bücher zu Halloran. Er feuert mich und stellt mich billiger wieder ein. So hat er mich auch das erste Mal eingestellt.")],
                  [("You take Imre's cash box. Inside: three tonics and a second set of books, much more honest than the first.", "Du nimmst Imres Geldkassette. Darin: drei Tränke und ein zweites Paar Bücher, viel ehrlicher als das erste.")],
                  ("Imre: Jost has my job now. He can't count. Halloran says it's an improvement.", "Imre: Jost hat jetzt meine Stelle. Er kann nicht zählen. Halloran sagt, das sei eine Verbesserung.")),
     "favor": {"npc": "hs_jost", "role": "barrel boy in the Brine Catacombs", "trust": 40, "use": 50, "kind": "believe_tip", "road": "brine_catacombs",
               "kind_answer": ("Not a word.", "Kein Wort."), "cold_answer": ("Depends who pays.", "Kommt drauf an, wer zahlt."),
               "ask": ("Jost: A tip, for the road: behind the third cask down here, Halloran keeps a dry stash. Nobody guards it at night. Probably.", "Jost: Ein Tipp für unterwegs: Hinter dem dritten Fass hier unten hat Halloran ein trockenes Lager. Nachts bewacht es keiner. Wahrscheinlich."),
               "yes": ("Believe him", "Ihm glauben"), "no": ("Not tonight", "Heute nicht"),
               "betray": [("Behind the third cask wait two of Halloran's salt guards, and Jost, collecting a finder's fee. For you.", "Hinter dem dritten Fass warten zwei Salzwächter Hallorans und Jost, der eine Finderprämie kassiert. Für dich.")],
               "reward": [("Behind the third cask: a dry stash, unguarded, as promised. Jost tips his cap. A revival leaf was going spare.", "Hinter dem dritten Fass: ein trockenes Lager, unbewacht, wie versprochen. Jost tippt an die Mütze. Ein Lebensblatt war übrig.")],
               "reward_fx": {"item": "revival_leaf"},
               "kept": [("Behind the third cask: salt. Only salt. Jost shrugs. 'I said probably.'", "Hinter dem dritten Fass: Salz. Nur Salz. Jost zuckt die Schultern. 'Ich sagte wahrscheinlich.'")],
               "battle": ("jost_guards", ("Salt Guards", "Salzwächter"),
                          ("Salt Guard: The boy said you'd be easy. The boy lies. We'll take it out of his barrels.", "Salzwächter: Der Junge sagte, du wärst leicht. Der Junge lügt. Wir ziehen es von seinen Fässern ab."),
                          ("The guards fine you for trespass on company salt.", "Die Wächter verhängen eine Strafe wegen Betretens von Firmensalz.")),
               "ledger": (("The third cask", "Das dritte Fass"),
                          ("Barrel Boy Jost sold you a tip about Halloran's stash, then sold you to the guards who were waiting there.", "Fassjunge Jost verkaufte dir einen Tipp über Hallorans Lager und dann dich an die Wächter, die dort warteten."))},
     "stages": [("Bookkeeper Imre says the salt barrels arrive light. He suspects his apprentice Jost.", "Buchhalter Imre sagt, die Salzfässer kommen leicht an. Er verdächtigt seinen Lehrling Jost.", "Mirror Flats"),
                ("The light barrels go down to the drowned chapel. Ask the salt diver in the Brine Catacombs.", "Die leichten Fässer gehen in die ertrunkene Kapelle. Frag die Salztaucherin in den Solekatakomben.", "The Brine Catacombs"),
                ("Whoever waters the salt has a very neat hand. Tell Imre.", "Wer das Salz wässert, hat eine sehr ordentliche Hand. Sag es Imre.", "Mirror Flats"),
                ("Imre skims the salt and blames the boy. Stop him on the Mirror Flats.", "Imre zweigt das Salz ab und beschuldigt den Jungen. Halt ihn auf der Spiegelebene auf.", "Mirror Flats"),
                ("Jost has Imre's job. He still can't count.", "Jost hat Imres Stelle. Zählen kann er immer noch nicht.", "Mirror Flats")]},

    {"id": "two_lanterns", "turns": False, "road": "lantern_span", "reward": ("guard_brew", 3),
     "giver": ("gilt_span", 4, 8, "right", "villager", "sabeth"),
     "intro": [("Engraver Sabeth: I engrave the plates under the lanterns. Today an order came in for a new plate. The name on it is mine.", "Graveurin Sabeth: Ich graviere die Platten unter den Laternen. Heute kam eine Bestellung für eine neue Platte. Der Name darauf ist meiner."),
               ("Sabeth: Prepaid. Somebody has booked my fall. Find out who. I'd like to cancel.", "Sabeth: Im Voraus bezahlt. Jemand hat meinen Sturz gebucht. Finde heraus, wer. Ich würde gern stornieren.")],
     "wait": ("Sabeth: Ledger girl Pia keeps Veronne's book on the Lantern Span. My sister Rosamund guides at the Great Orrery. She hears every rumour first.", "Sabeth: Das Buchmädchen Pia führt Veronnes Buch auf dem Laternenbogen. Meine Schwester Rosamund führt durch das Große Planetarium. Sie hört jedes Gerücht zuerst."),
     "reveal": [("Sabeth: Konrad. Of course. He always said he'd never let me go. I thought it was romantic.", "Sabeth: Konrad. Natürlich. Er hat immer gesagt, er lässt mich nie gehen. Ich dachte, das sei romantisch."),
                ("Sabeth: He waits on the Span tonight. Beat him before he walks me to the railing.", "Sabeth: Er wartet heute Abend auf dem Bogen. Schlag ihn, bevor er mich zum Geländer bringt.")],
     "go": ("Sabeth: The Lantern Span, the island in the middle. Mind the railing. It's mostly decorative.", "Sabeth: Der Laternenbogen, die Insel in der Mitte. Pass auf das Geländer auf. Es ist hauptsächlich Dekoration."),
     "reward_lines": [("Sabeth: He's beaten? Then my plate can wait. Take these, for your trouble. And for your discretion.", "Sabeth: Er ist geschlagen? Dann kann meine Platte warten. Nimm die, für deine Mühe. Und für deine Verschwiegenheit.")],
     "after": ("Sabeth: I've engraved a plate for Konrad anyway. Just in case. I'm an optimist.", "Sabeth: Ich habe trotzdem eine Platte für Konrad graviert. Nur für den Fall. Ich bin Optimistin."),
     "steps": [("lantern_span", 7, 14, "left", "villager", "pia",
                [("Ledger Girl Pia: Sabeth's plate? Red column, prepaid, signed by 'a loving husband'. Loving husbands are our best customers.", "Buchmädchen Pia: Sabeths Platte? Rote Spalte, im Voraus bezahlt, unterschrieben von 'einem liebenden Ehemann'. Liebende Ehemänner sind unsere besten Kunden."),
                 ("Pia: Ask her sister. Sisters always know whose husband is loving whom.", "Pia: Frag ihre Schwester. Schwestern wissen immer, wessen Ehemann wen liebt.")],
                ("Pia: Black ink for the living, red for the rest. I go through a lot of red.", "Pia: Schwarze Tinte für die Lebenden, rote für den Rest. Ich verbrauche viel Rot.")),
               ("great_orrery", 6, 2, "down", "tamer_f", "rosamund",
                [("Star Guide Rosamund: Konrad? Sabeth's husband? He's been asking which lanterns burn longest. For sentimental reasons, he said.", "Sternführerin Rosamund: Konrad? Sabeths Mann? Er fragt herum, welche Laternen am längsten brennen. Aus sentimentalen Gründen, sagt er."),
                 ("Rosamund: He waits on the Lantern Span every evening, counting the drop. Tell my sister. Gently. Or not. She never was gentle with me.", "Rosamund: Er wartet jeden Abend auf dem Laternenbogen und zählt die Tiefe. Sag es meiner Schwester. Schonend. Oder nicht. Sie war zu mir auch nie schonend.")],
                ("Rosamund: The stars don't fall. People do. That's why I work indoors.", "Rosamund: Die Sterne fallen nicht. Menschen schon. Deshalb arbeite ich drinnen."))],
     "betrayer": ("lantern_span", 3, 14, "right", "villager", "konrad", ("Husband Konrad", "Ehemann Konrad"),
                  [("Konrad: You've come from Sabeth. Then you're the other name.", "Konrad: Du kommst von Sabeth. Dann bist du der andere Name.")],
                  [("Konrad: The other name, I said. The order had two plates. Mine and the courier's. Sabeth wrote it. I only paid.", "Konrad: Der andere Name, sagte ich. Die Bestellung war für zwei Platten. Meine und die des Boten. Sabeth hat sie geschrieben. Ich habe nur bezahlt."),
                   ("Konrad: She wanted me over the railing and you as the one who pushed. One lantern each. Very tidy, my wife.", "Konrad: Sie wollte mich über dem Geländer und dich als den, der geschubst hat. Eine Laterne für jeden. Sehr ordentlich, meine Frau.")],
                  None,
                  ("Konrad: I'm moving out. Downstairs. Well away from any stairs.", "Konrad: Ich ziehe aus. Nach unten. Weit weg von jeder Treppe.")),
     "twist": {"npc": "hs_sabeth", "role": "lantern engraver who books two falls at once", "trust": 25, "use": 65, "road": "lantern_span",
               "clue": ("gilt_span", 8, 2, "down", "elder", "yorick",
                        [("Plate Polisher Yorick: Two blank plates came in last week, paid together. One for a husband. One for 'the courier'. The order slip is in the engraver's own hand.", "Plattenpolierer Yorick: Letzte Woche kamen zwei leere Platten rein, zusammen bezahlt. Eine für einen Ehemann. Eine für 'den Boten'. Der Bestellzettel ist in der Handschrift der Graveurin."),
                         ("Yorick: I polish. I don't read. Except slips. Slips are short.", "Yorick: Ich poliere. Ich lese nicht. Außer Zettel. Zettel sind kurz.")],
                        ("Yorick: Shiny plates, short lives. Business is steady.", "Yorick: Glänzende Platten, kurze Leben. Das Geschäft läuft stetig.")),
               "caught": [("You lay Yorick's slip on Sabeth's bench: two plates, one for Konrad, one for 'the courier', in her hand.", "Du legst Yoricks Zettel auf Sabeths Werkbank: zwei Platten, eine für Konrad, eine für 'den Boten', in ihrer Handschrift."),
                          ("Sabeth: ...Polishers. They read everything. Fine. Here is the courier's fee. It was meant for your lantern. Spend it on something cheerful.", "Sabeth: ...Polierer. Die lesen alles. Schön. Hier ist das Botenhonorar. Es war für deine Laterne gedacht. Gib es für etwas Fröhliches aus.")],
               "caught_fx": {"coins": 2000, "trust": {"hs_sabeth": -10}},
               "struck": [("Sabeth: One more thing. The pushers I hired for Konrad are still paid up. Waste not.", "Sabeth: Noch etwas. Die Schubser, die ich für Konrad angeheuert habe, sind noch bezahlt. Nichts verschwenden.")],
               "struck_fx": {"coins": -400},
               "battle": ("plate_pushers", ("Hired Pushers", "Angeheuerte Schubser"),
                          ("Pusher: Paid for one fall, got none. Sabeth wants a refund. We want a new line of work.", "Schubser: Für einen Sturz bezahlt, keinen bekommen. Sabeth will ihr Geld zurück. Wir wollen einen neuen Beruf."),
                          ("The pushers walk you to the railing and stop. They charge extra for the last step.", "Die Schubser führen dich bis ans Geländer und halten an. Der letzte Schritt kostet extra.")),
               "ledger": (("Two plates", "Zwei Platten"),
                          ("Engraver Sabeth ordered two lantern plates: one for her husband, one for the courier she sent to stop him.", "Graveurin Sabeth bestellte zwei Laternenplatten: eine für ihren Mann, eine für den Boten, den sie schickte, um ihn aufzuhalten."))},
     "stages": [("Engraver Sabeth has a prepaid lantern plate with her own name. Find out who ordered it.", "Graveurin Sabeth hat eine vorausbezahlte Laternenplatte mit ihrem eigenen Namen. Finde heraus, wer sie bestellt hat.", "The Gilt Span"),
                ("The plate was paid by 'a loving husband'. Ask Sabeth's sister at the Great Orrery.", "Die Platte bezahlte 'ein liebender Ehemann'. Frag Sabeths Schwester im Großen Planetarium.", "The Great Orrery"),
                ("Konrad asks which lanterns burn longest. Tell Sabeth.", "Konrad fragt, welche Laternen am längsten brennen. Sag es Sabeth.", "The Gilt Span"),
                ("Beat Konrad on the island of the Lantern Span.", "Schlag Konrad auf der Insel des Laternenbogens.", "Lantern Span"),
                ("Konrad lives downstairs now. Sabeth keeps his plate polished.", "Konrad wohnt jetzt unten. Sabeth hält seine Platte poliert.", "The Gilt Span")]},

    {"id": "forged_will", "turns": True, "duel": True, "road": "gilt_cellars", "reward": ("focus_brew", 3),
     "giver": ("sunfall_terraces", 8, 8, "left", "tamer_f", "philippa"),
     "intro": [("Gilt Heir Philippa: I'm the fourth child. Fourth children inherit the cutlery and the blame. But Father wrote a new will. In my favour.", "Gilt-Erbin Philippa: Ich bin das vierte Kind. Vierte Kinder erben das Besteck und die Schuld. Aber Vater hat ein neues Testament geschrieben. Zu meinen Gunsten."),
               ("Philippa: Have it sealed by the archivist in the Gilt Cellars before my siblings eat it. One of them ate the last one. With mustard.", "Philippa: Lass es vom Archivar in den Gilt-Kellern versiegeln, bevor meine Geschwister es essen. Eins hat das letzte gegessen. Mit Senf.")],
     "wait": ("Philippa: The archivist sits in the strongroom of the Gilt Cellars. If he dawdles, the ink seller on Cloudshadow Meadow can vouch for the paper.", "Philippa: Der Archivar sitzt im Tresorraum der Gilt-Keller. Wenn er trödelt, kann die Tintenhändlerin auf der Wolkenschattenwiese für das Papier bürgen."),
     "reveal": [("Philippa: Practice makes perfect. Father always said so. He'll be proud. When he reads it. If.", "Philippa: Übung macht den Meister. Das hat Vater immer gesagt. Er wird stolz sein. Wenn er es liest. Falls."),
                ("Philippa: You're the witness on page three, by the way. Witnesses to Gilt wills have a short shelf life.", "Philippa: Du bist übrigens die Zeugenunterschrift auf Seite drei. Zeugen von Gilt-Testamenten haben eine kurze Haltbarkeit."),
                ("Philippa: Meet me in the strongroom. We'll settle the estate.", "Philippa: Triff mich im Tresorraum. Wir regeln den Nachlass.")],
     "steps": [("gilt_cellars@1", 3, 5, "right", "elder", "hollis",
                [("Archivist Hollis: A new will from Lord Aurek? Hm. The wax is still warm. Lord Aurek has not left his room in a week. His wax is cold.", "Archivar Hollis: Ein neues Testament von Herrn Aurek? Hm. Das Wachs ist noch warm. Herr Aurek hat sein Zimmer seit einer Woche nicht verlassen. Sein Wachs ist kalt."),
                 ("Hollis: And the ink is meadow violet. Ask the ink seller on Cloudshadow Meadow who bought it.", "Hollis: Und die Tinte ist Wiesenveilchen. Frag die Tintenhändlerin auf der Wolkenschattenwiese, wer sie gekauft hat.")],
                ("Hollis: I have five wills here from five children. Each leaves everything to the author. Literature.", "Hollis: Ich habe hier fünf Testamente von fünf Kindern. Jedes vermacht alles dem Verfasser. Literatur.")),
               ("cloudshadow_meadow", 5, 13, "down", "villager", "marla",
                [("Ink Seller Marla: Meadow violet? One bottle, last week, to a young lady with a Gilt brooch and a very steady hand.", "Tintenhändlerin Marla: Wiesenveilchen? Eine Flasche, letzte Woche, an eine junge Dame mit Gilt-Brosche und sehr ruhiger Hand."),
                 ("Marla: She also bought a practice pad. Lord Aurek's signature, forty times. The last ten were perfect.", "Marla: Sie hat auch einen Übungsblock gekauft. Herrn Aureks Unterschrift, vierzigmal. Die letzten zehn waren perfekt.")],
                ("Marla: Ink is cheap. Signatures are expensive. I sell the cheap part.", "Marla: Tinte ist billig. Unterschriften sind teuer. Ich verkaufe den billigen Teil."))],
     "betrayer": ("gilt_cellars@1", 8, 7, "left", "tamer_f", "philippa_will", ("Gilt Heir Philippa", "Gilt-Erbin Philippa"),
                  [("Philippa: Page three, line two: 'The witness predeceased the testator.' Let's make it true.", "Philippa: Seite drei, Zeile zwei: 'Der Zeuge verstarb vor dem Erblasser.' Machen wir es wahr.")],
                  [("Philippa: Contested. My will. By a witness. The cheek.", "Philippa: Angefochten. Mein Testament. Von einem Zeugen. Die Frechheit."),
                   ("Philippa: Take it. Burn it. I'll write another. I've got thirty perfect signatures left.", "Philippa: Nimm es. Verbrenn es. Ich schreibe ein neues. Ich habe noch dreißig perfekte Unterschriften.")],
                  [("You take the forged will and Philippa's travel case: three brews and a fork with somebody else's crest.", "Du nimmst das gefälschte Testament und Philippas Reisekoffer: drei Tränke und eine Gabel mit fremdem Wappen.")],
                  ("Philippa: Father read my will. He laughed so hard he added me to his. Under 'cutlery'.", "Philippa: Vater hat mein Testament gelesen. Er hat so gelacht, dass er mich in seins aufgenommen hat. Unter 'Besteck'."),
                  ("Philippa: Witnessed and signed. Go and rest. You look predeceased.", "Philippa: Bezeugt und unterschrieben. Geh und ruh dich aus. Du siehst vorverstorben aus.")),
     "stages": [("Gilt Heir Philippa wants her father's new will sealed in the Gilt Cellars.", "Gilt-Erbin Philippa will das neue Testament ihres Vaters in den Gilt-Kellern versiegeln lassen.", "Sunfall Terraces"),
                ("The wax is warm and the ink is meadow violet. Ask the ink seller on Cloudshadow Meadow.", "Das Wachs ist warm und die Tinte ist Wiesenveilchen. Frag die Tintenhändlerin auf der Wolkenschattenwiese.", "Cloudshadow Meadow"),
                ("A young lady with a Gilt brooch practised Lord Aurek's signature. Ask Philippa.", "Eine junge Dame mit Gilt-Brosche hat Herrn Aureks Unterschrift geübt. Frag Philippa.", "Sunfall Terraces"),
                ("Philippa wants the witness gone. Face her in the strongroom of the Gilt Cellars.", "Philippa will die Zeugin loswerden. Stell sie im Tresorraum der Gilt-Keller.", "The Gilt Cellars"),
                ("Philippa inherits the cutlery after all.", "Philippa erbt am Ende doch das Besteck.", "Sunfall Terraces")]},

    {"id": "cask_41", "turns": False, "duel": True, "road": "gilt_cellars", "reward": ("dash_brew", 3),
     "giver": ("sunfall_terraces", 2, 18, "right", "villager", "gerti"),
     "intro": [("Vineyard Hand Gerti: The Gilt wine has a secret ingredient. It talked too much, they say. Well. One cask in the cellar knocks back.", "Weinbergsarbeiterin Gerti: Der Gilt-Wein hat eine geheime Zutat. Sie hat zu viel geredet, sagt man. Tja. Ein Fass im Keller klopft zurück."),
               ("Gerti: Find out who's in it. Quietly. Wine doesn't like noise, and neither does the family.", "Gerti: Finde heraus, wer drin ist. Leise. Wein mag keinen Lärm, und die Familie auch nicht.")],
     "wait": ("Gerti: The cooper in the Gilt Cellars knows every cask. And the old taster on Orrery Ridge knows every vintage.", "Gerti: Der Böttcher in den Gilt-Kellern kennt jedes Fass. Und der alte Weinprüfer auf dem Planetariumsgrat kennt jeden Jahrgang."),
     "reveal": [("Gerti: Uncle Bertrand? In a cask? For eleven years? The family said he'd gone abroad.", "Gerti: Onkel Bertrand? In einem Fass? Seit elf Jahren? Die Familie sagte, er sei ins Ausland gegangen."),
                ("Gerti: Let him out. He's owed his share of the house. Quietly. The strongroom key opens cask forty-one.", "Gerti: Lass ihn raus. Ihm steht sein Anteil am Haus zu. Leise. Der Tresorschlüssel öffnet Fass einundvierzig.")],
     "go": ("Gerti: The strongroom of the Gilt Cellars. Bring a corkscrew. A big one.", "Gerti: Der Tresorraum der Gilt-Keller. Bring einen Korkenzieher mit. Einen großen."),
     "reward_lines": [("Gerti: Bertrand went back into his cask? Fine. Saves the family a room. Here, for the corkscrew.", "Gerti: Bertrand ist zurück in sein Fass? Schön. Spart der Familie ein Zimmer. Hier, für den Korkenzieher.")],
     "after": ("Gerti: The Gilt wine tastes nuttier this year. Nobody complains.", "Gerti: Der Gilt-Wein schmeckt dieses Jahr nussiger. Keiner beschwert sich."),
     "steps": [("gilt_cellars", 8, 8, "left", "villager", "mattheus",
                [("Cooper Mattheus: Cask forty-one? It knocks twice for yes and once for 'more bread'. It's been knocking for eleven years.", "Böttcher Mattheus: Fass einundvierzig? Es klopft zweimal für ja und einmal für 'mehr Brot'. Es klopft seit elf Jahren."),
                 ("Mattheus: Eleven years ago, the vintage of the Great Quarrel. Ask the old taster on Orrery Ridge who went missing that year.", "Mattheus: Vor elf Jahren, der Jahrgang des Großen Streits. Frag den alten Weinprüfer auf dem Planetariumsgrat, wer in dem Jahr verschwand.")],
                ("Mattheus: I feed it through the bunghole. Soup, mostly. It complains about the soup.", "Mattheus: Ich füttere es durchs Spundloch. Meistens Suppe. Es beschwert sich über die Suppe.")),
               ("orrery_ridge", 4, 8, "right", "elder", "albrecht",
                [("Old Taster Albrecht: The Great Quarrel vintage? That was the year Uncle Bertrand, Aurek's brother, vanished owing money to every family on the plateau.", "Der alte Weinprüfer Albrecht: Der Jahrgang des Großen Streits? Das war das Jahr, in dem Onkel Bertrand, Aureks Bruder, verschwand, mit Schulden bei jeder Familie auf der Hochebene."),
                 ("Albrecht: The wine from that year had a nutty finish. And a faint aftertaste of uncle.", "Albrecht: Der Wein aus dem Jahr hatte einen nussigen Abgang. Und einen leichten Nachgeschmack von Onkel.")],
                ("Albrecht: I spit, I never swallow. In wine and in family matters.", "Albrecht: Ich spucke, ich schlucke nie. Beim Wein und in Familiendingen."))],
     "betrayer": ("gilt_cellars@1", 6, 3, "down", "elder", "bertrand", ("Uncle Bertrand", "Onkel Bertrand"),
                  [("Bertrand: Free! Eleven years in oak. I'm wonderfully aged. Now, about my creditors: you'll do as a first payment.", "Bertrand: Frei! Elf Jahre in Eiche. Ich bin wunderbar gereift. Nun zu meinen Gläubigern: Du reichst als erste Rate.")],
                  [("Bertrand: Corked. I'm corked.", "Bertrand: Korkig. Ich bin korkig."),
                   ("Bertrand: I went into that cask myself, you know. Cheaper than paying. I'll go back in. The soup was free.", "Bertrand: Ich bin selbst in das Fass gestiegen, weißt du. Billiger als zahlen. Ich gehe wieder rein. Die Suppe war umsonst.")],
                  None,
                  ("Bertrand: Knock twice for yes. Once for more bread.", "Bertrand: Zweimal klopfen für ja. Einmal für mehr Brot."),
                  ("Bertrand: There. Breathe. Every vintage needs to breathe.", "Bertrand: So. Atmen. Jeder Jahrgang muss atmen.")),
     "twist": {"npc": "hs_gerti", "role": "vineyard hand, Bertrand's daughter, sells intruders by the head", "trust": 30, "use": 60, "road": "gilt_cellars",
               "clue": ("sunfall_terraces", 3, 12, "right", "villager", "fenna",
                        [("Vine Girl Fenna: Gerti? She's Bertrand's daughter. She told the cousins someone was coming to open his cask. They want to catch whoever does.", "Rebenmädchen Fenna: Gerti? Sie ist Bertrands Tochter. Sie hat den Vettern gesagt, dass jemand kommt, um sein Fass zu öffnen. Die wollen den erwischen, der es tut."),
                         ("Fenna: The cousins pay for intruders by the head. Gerti needs the money. Her father owes everyone.", "Fenna: Die Vettern zahlen pro Kopf für Eindringlinge. Gerti braucht das Geld. Ihr Vater schuldet allen was.")],
                        ("Fenna: I pick the grapes. I don't pick sides.", "Fenna: Ich pflücke Trauben. Ich ergreife keine Partei.")),
               "caught": [("You tell Gerti what the vine girl said. Gerti counts the cousins coming up the terraces and changes her mind.", "Du erzählst Gerti, was das Rebenmädchen gesagt hat. Gerti zählt die Vettern, die die Terrassen heraufkommen, und überlegt es sich anders."),
                          ("Gerti: Fine. I'll tell them you were never here. Take this. It's the only bottle in the cellar with nobody in it.", "Gerti: Schön. Ich sage ihnen, du warst nie hier. Nimm das. Es ist die einzige Flasche im Keller, in der niemand steckt.")],
               "caught_fx": {"item": "max_tonic", "trust": {"hs_gerti": 10}},
               "struck": [("Gerti: Oh, cousins! Here's the one who opened Uncle's cask. Per head, wasn't it?", "Gerti: Ach, Vettern! Hier ist der, der Onkels Fass geöffnet hat. Pro Kopf, oder?")],
               "struck_fx": {"coins": -300},
               "battle": ("cask_cousins", ("Gilt Cousins", "Gilt-Vettern"),
                          ("Gilt Cousin: Per head, she said. We'll pay her nothing. Families are complicated.", "Gilt-Vetter: Pro Kopf, sagte sie. Wir zahlen ihr nichts. Familien sind kompliziert."),
                          ("The cousins fine you for disturbing a vintage.", "Die Vettern verhängen eine Strafe wegen Störung eines Jahrgangs.")),
               "ledger": (("Cask forty-one", "Fass einundvierzig"),
                          ("Vineyard Hand Gerti sent you to open her father's cask and then sold you to the cousins, by the head.", "Weinbergsarbeiterin Gerti schickte dich, das Fass ihres Vaters zu öffnen, und verkaufte dich dann an die Vettern, pro Kopf."))},
     "stages": [("Vineyard Hand Gerti says one cask in the Gilt Cellars knocks back. Find out who is in it.", "Weinbergsarbeiterin Gerti sagt, ein Fass in den Gilt-Kellern klopft zurück. Finde heraus, wer drin ist.", "Sunfall Terraces"),
                ("Cask forty-one dates from the vintage of the Great Quarrel. Ask the old taster on Orrery Ridge.", "Fass einundvierzig stammt aus dem Jahrgang des Großen Streits. Frag den alten Weinprüfer auf dem Planetariumsgrat.", "Orrery Ridge"),
                ("Uncle Bertrand vanished that year. Tell Gerti.", "Onkel Bertrand verschwand in dem Jahr. Sag es Gerti.", "Sunfall Terraces"),
                ("Open cask forty-one in the strongroom of the Gilt Cellars.", "Öffne Fass einundvierzig im Tresorraum der Gilt-Keller.", "The Gilt Cellars"),
                ("Uncle Bertrand is back in his cask, by choice.", "Onkel Bertrand ist zurück in seinem Fass, freiwillig.", "Sunfall Terraces")]},

    {"id": "true_stars", "turns": False, "road": "cloudshadow_meadow", "reward": ("wake_bell", 3),
     "giver": ("cloudshadow_meadow", 8, 15, "left", "elder", "ennis"),
     "intro": [("Horoscope Seller Ennis: My horoscopes come true. All of them. 'Beware of heights': fell off a terrace. 'A stranger brings news': poisoned by a courier.", "Horoskophändler Ennis: Meine Horoskope werden wahr. Alle. 'Hüte dich vor Höhen': von einer Terrasse gefallen. 'Ein Fremder bringt Nachricht': von einem Boten vergiftet."),
               ("Ennis: Business has never been better, and I am terrified. Find out who makes my stars come true.", "Ennis: Das Geschäft lief nie besser, und ich habe schreckliche Angst. Finde heraus, wer meine Sterne wahr macht.")],
     "wait": ("Ennis: Arno watches the meadow through his telescope on Orrery Ridge. And the goat girl here sees everyone who crosses.", "Ennis: Arno beobachtet die Wiese durch sein Fernrohr auf dem Planetariumsgrat. Und das Ziegenmädchen hier sieht jeden, der vorbeikommt."),
     "reveal": [("Ennis: My wife? Wanda? Making my horoscopes come true? Oh, Wanda.", "Ennis: Meine Frau? Wanda? Sie macht meine Horoskope wahr? Ach, Wanda."),
                ("Ennis: She's on the meadow, delivering 'a sudden change of fortune'. Stop her before she ruins my reputation for accuracy. I mean, before she hurts someone.", "Ennis: Sie ist auf der Wiese und liefert 'eine plötzliche Wende des Glücks'. Halt sie auf, bevor sie meinen Ruf für Genauigkeit ruiniert. Ich meine, bevor sie jemandem wehtut.")],
     "go": ("Ennis: The west side of the meadow, by the trees. Her stars are always in the west.", "Ennis: Die Westseite der Wiese, bei den Bäumen. Ihre Sterne stehen immer im Westen."),
     "reward_lines": [("Ennis: Wanda is stopped? A tragedy. My accuracy will suffer. Here, take these. Your horoscope: long life. For now.", "Ennis: Wanda ist aufgehalten? Eine Tragödie. Meine Genauigkeit wird leiden. Hier, nimm die. Dein Horoskop: ein langes Leben. Vorerst.")],
     "after": ("Ennis: I've hired a new assistant. Young. Ambitious. Her stars are very precise.", "Ennis: Ich habe eine neue Assistentin eingestellt. Jung. Ehrgeizig. Ihre Sterne sind sehr präzise."),
     "steps": [("orrery_ridge", 8, 16, "left", "villager", "arno",
                [("Telescope Boy Arno: I saw it. A woman in a star-pattern shawl follows every customer of Ennis. Then the customer has a very bad day.", "Fernrohrjunge Arno: Ich hab's gesehen. Eine Frau mit Sternenmuster-Schal folgt jedem Kunden von Ennis. Dann hat der Kunde einen sehr schlechten Tag."),
                 ("Arno: Will you pay me for what I saw? Information on this plateau is never free.", "Arno: Bezahlst du mich für das, was ich gesehen habe? Auskünfte sind auf dieser Hochebene nie umsonst.")],
                ("Arno: I see everything from up here. Nobody ever looks back up.", "Arno: Von hier oben sehe ich alles. Niemand schaut je zurück nach oben.")),
               ("cloudshadow_meadow", 9, 19, "left", "villager", "liv",
                [("Goat Girl Liv: The lady in the star shawl? She walks with Ennis's customers and takes a little bag from each. Then she goes home.", "Ziegenmädchen Liv: Die Dame mit dem Sternenschal? Sie geht mit Ennis' Kunden mit und nimmt jedem ein kleines Säckchen ab. Dann geht sie heim."),
                 ("Liv: Home is Ennis's house. She kisses him at the door. Goats notice things.", "Liv: Heim ist Ennis' Haus. Sie küsst ihn an der Tür. Ziegen bemerken so was.")],
                ("Liv: My goats eat horoscopes. They've lived very long lives.", "Liv: Meine Ziegen fressen Horoskope. Sie leben sehr lange."))],
     "betrayer": ("cloudshadow_meadow", 2, 7, "right", "tamer_f", "wanda", ("Star Shawl Wanda", "Sternenschal-Wanda"),
                  [("Wanda: Your horoscope today: 'an unexpected fight'. I deliver.", "Wanda: Dein Horoskop heute: 'ein unerwarteter Kampf'. Ich liefere.")],
                  [("Wanda: Ennis sent you? Ennis writes them. I only deliver. He picks the customers who owe him money.", "Wanda: Ennis hat dich geschickt? Ennis schreibt sie. Ich liefere nur. Er sucht die Kunden aus, die ihm Geld schulden."),
                   ("Wanda: He wanted you to stop me so he could hire a younger star. Marriage.", "Wanda: Er wollte, dass du mich aufhältst, damit er einen jüngeren Stern anheuern kann. Ehe.")],
                  None,
                  ("Wanda: Your stars say: go home. Mine say: so should I.", "Wanda: Deine Sterne sagen: Geh nach Hause. Meine sagen: Ich auch.")),
     "favor": {"npc": "hs_arno", "role": "telescope boy on Orrery Ridge who sells what he sees", "trust": 45, "use": 50, "kind": "lend_coins", "amount": 800, "road": "orrery_ridge",
               "kind_answer": ("Here, a coin for your trouble.", "Hier, eine Münze für deine Mühe."), "cold_answer": ("Information should be free.", "Auskünfte sollten umsonst sein."),
               "ask": ("Arno: With a better lens I could see her face. Lend me 800 coins? I'll pay you back. Probably with interest.", "Arno: Mit einer besseren Linse könnte ich ihr Gesicht sehen. Leihst du mir 800 Münzen? Ich zahle es zurück. Wahrscheinlich mit Zinsen."),
               "yes": ("Lend him 800", "Ihm 800 leihen"), "no": ("Not now", "Jetzt nicht"),
               "betray": [("Arno spends your coins on a lens and sells the first thing he sees through it: your face, to the woman in the shawl. Her friends come calling.", "Arno gibt deine Münzen für eine Linse aus und verkauft das Erste, was er dadurch sieht: dein Gesicht, an die Frau mit dem Schal. Ihre Freunde kommen vorbei.")],
               "reward": [("Arno pays you back with interest and a sketch of the woman's face. It looks a lot like Ennis's wedding portrait.", "Arno zahlt mit Zinsen zurück und gibt dir eine Skizze vom Gesicht der Frau. Sie sieht Ennis' Hochzeitsbild sehr ähnlich.")],
               "reward_fx": {"coins": 1200},
               "kept": [("Arno pays you back, to the coin. 'Interest is for people who own banks,' he says.", "Arno zahlt zurück, auf die Münze genau. 'Zinsen sind was für Leute, denen Banken gehören', sagt er.")],
               "kept_fx": {"coins": 800},
               "battle": ("arno_watchers", ("Shawl Watchers", "Schalwächter"),
                          ("Watcher: Your horoscope said 'a quiet week'. Ennis will have to print a correction.", "Wächter: Dein Horoskop sagte 'eine ruhige Woche'. Ennis muss eine Berichtigung drucken."),
                          ("The watchers take your coins. The horoscope said you'd lose some money.", "Die Wächter nehmen deine Münzen. Das Horoskop sagte, du verlierst etwas Geld.")),
               "ledger": (("The better lens", "Die bessere Linse"),
                          ("Telescope Boy Arno borrowed your coins for a better lens and sold your face with the first look through it.", "Fernrohrjunge Arno lieh sich deine Münzen für eine bessere Linse und verkaufte dein Gesicht mit dem ersten Blick hindurch."))},
     "stages": [("All of Horoscope Seller Ennis's horoscopes come true. Find out who makes them.", "Alle Horoskope von Horoskophändler Ennis werden wahr. Finde heraus, wer dafür sorgt.", "Cloudshadow Meadow"),
                ("A woman in a star shawl follows his customers. Ask the goat girl on Cloudshadow Meadow.", "Eine Frau mit Sternenschal folgt seinen Kunden. Frag das Ziegenmädchen auf der Wolkenschattenwiese.", "Cloudshadow Meadow"),
                ("The woman in the shawl goes home to Ennis. Tell him.", "Die Frau mit dem Schal geht heim zu Ennis. Sag es ihm.", "Cloudshadow Meadow"),
                ("Ennis's wife Wanda delivers the horoscopes. Stop her on the west side of the meadow.", "Ennis' Frau Wanda liefert die Horoskope. Halt sie auf der Westseite der Wiese auf.", "Cloudshadow Meadow"),
                ("Ennis has a new assistant. Her stars are very precise.", "Ennis hat eine neue Assistentin. Ihre Sterne sind sehr präzise.", "Cloudshadow Meadow")]},

    {"id": "own_cairn", "turns": True, "road": "orrery_ridge", "reward": ("spark_drop", 1),
     "giver": ("orrery_ridge", 2, 20, "right", "elder", "ewald"),
     "intro": [("Cairn Builder Ewald: In Whitecairn every cairn is a person who said no to the Gilt House. I build them. Somebody ordered one with your name.", "Steinhaufenbauer Ewald: In Whitecairn ist jeder Steinhaufen jemand, der Nein zum Haus Gilt gesagt hat. Ich baue sie. Jemand hat einen mit deinem Namen bestellt."),
               ("Ewald: Prepaid, with a nice view. I'd like to know who before I lay the top stone. It's a matter of craft.", "Ewald: Im Voraus bezahlt, mit schöner Aussicht. Ich wüsste gern, von wem, bevor ich den Schlussstein lege. Eine Frage der Handwerksehre.")],
     "wait": ("Ewald: The quarryman at the Fallen Planet cut the stones. And Courier Netta on the Mirror Flats carried the order.", "Ewald: Der Steinbrecher beim Gefallenen Planeten hat die Steine geschnitten. Und die Botin Netta auf der Spiegelebene hat die Bestellung gebracht."),
     "reveal": [("Ewald: Netta talks too much. Yes, I order them. A cairn with no one under it is just a heap.", "Ewald: Netta redet zu viel. Ja, ich bestelle sie. Ein Steinhaufen ohne jemanden darunter ist nur ein Haufen."),
                ("Ewald: The House pays per finished cairn. You said no to the House the day you came up the funicular. You just didn't notice.", "Ewald: Das Haus zahlt pro fertigem Steinhaufen. Du hast Nein zum Haus gesagt, an dem Tag, als du mit der Bahn heraufkamst. Du hast es nur nicht gemerkt."),
                ("Ewald: Come up the ridge. I've a top stone to lay.", "Ewald: Komm auf den Grat. Ich habe einen Schlussstein zu legen.")],
     "steps": [("fallen_planet", 9, 8, "left", "villager", "rolf",
                [("Quarryman Rolf: Your cairn stones? Cut last week. Good white stone, very flattering. The order came with tea stains.", "Steinbrecher Rolf: Deine Steinhaufensteine? Letzte Woche geschnitten. Guter weißer Stein, sehr schmeichelhaft. Die Bestellung hatte Teeflecken."),
                 ("Rolf: Netta brought it. She carries everything on the plateau. Ask her who gave it to her.", "Rolf: Netta hat sie gebracht. Sie trägt alles auf der Hochebene herum. Frag sie, wer sie ihr gegeben hat.")],
                ("Rolf: I cut stones for the living. It's steadier work than for the dead. The dead don't order twice.", "Rolf: Ich schneide Steine für die Lebenden. Das ist beständigere Arbeit als für die Toten. Tote bestellen nicht zweimal.")),
               ("mirror_flats", 5, 6, "left", "villager", "netta",
                [("Courier Netta: The cairn order? I carried it from Whitecairn to the quarry. From Ewald's own workshop. He orders his cairns himself.", "Botin Netta: Die Steinhaufenbestellung? Die habe ich von Whitecairn zum Steinbruch getragen. Aus Ewalds eigener Werkstatt. Er bestellt seine Steinhaufen selbst."),
                 ("Netta: Then the Gilt House pays him per cairn finished. Finished means the name is true. He makes them true.", "Netta: Dann zahlt ihm das Haus Gilt pro fertigem Steinhaufen. Fertig heißt, der Name stimmt. Er sorgt dafür, dass er stimmt.")],
                ("Netta: I carry, I don't read. Reading is how couriers end up under cairns.", "Netta: Ich trage, ich lese nicht. Durch Lesen landen Boten unter Steinhaufen."))],
     "betrayer": ("orrery_ridge", 7, 4, "left", "elder", "ewald_stone", ("Cairn Builder Ewald", "Steinhaufenbauer Ewald"),
                  [("Ewald: Hold still. A cairn is only as straight as the person under it.", "Ewald: Halt still. Ein Steinhaufen ist nur so gerade wie der, der darunter liegt.")],
                  [("Ewald: Toppled. My own heap. That's a first.", "Ewald: Umgestürzt. Mein eigener Haufen. Das ist neu."),
                   ("Ewald: Keep the stones. Build something cheerful. A wall, maybe. Walls are cheerful.", "Ewald: Behalt die Steine. Bau etwas Fröhliches. Eine Mauer vielleicht. Mauern sind fröhlich.")],
                  [("You take Ewald's order book. Your page is torn out. Tucked in the spine: a spark drop he was saving for his own cairn.", "Du nimmst Ewalds Auftragsbuch. Deine Seite ist herausgerissen. Im Buchrücken steckt ein Funkentropfen, den er für seinen eigenen Steinhaufen aufgehoben hat.")],
                  ("Ewald: I build garden walls now. Nobody has to be under them. Usually.", "Ewald: Ich baue jetzt Gartenmauern. Darunter muss niemand liegen. Meistens.")),
     "stages": [("Cairn Builder Ewald says someone ordered a cairn with your name. Find out who.", "Steinhaufenbauer Ewald sagt, jemand hat einen Steinhaufen mit deinem Namen bestellt. Finde heraus, wer.", "Orrery Ridge"),
                ("The order came with tea stains. Ask Courier Netta on the Mirror Flats who gave it to her.", "Die Bestellung hatte Teeflecken. Frag Botin Netta auf der Spiegelebene, wer sie ihr gegeben hat.", "Mirror Flats"),
                ("Ewald orders his cairns himself. Ask him why.", "Ewald bestellt seine Steinhaufen selbst. Frag ihn, warum.", "Orrery Ridge"),
                ("Ewald is paid per finished cairn. Topple him on Orrery Ridge.", "Ewald wird pro fertigem Steinhaufen bezahlt. Stürz ihn auf dem Planetariumsgrat.", "Orrery Ridge"),
                ("Ewald builds garden walls now.", "Ewald baut jetzt Gartenmauern.", "Orrery Ridge")]},

    {"id": "red_column", "turns": False, "duel": True, "road": "lantern_span", "reward": ("remedy", 4),
     "giver": ("lantern_span", 2, 22, "right", "villager", "wido"),
     "intro": [("Clerk's Boy Wido: Veronne's toll ledger has a red column for people who fell. My father is in it. He didn't fall. He waves at me from the vineyards.", "Schreiberjunge Wido: Veronnes Zollbuch hat eine rote Spalte für Leute, die gefallen sind. Mein Vater steht drin. Er ist nicht gefallen. Er winkt mir von den Weinbergen zu."),
               ("Wido: Find out why he's in the red. The red column pays out to the family. We never got a coin.", "Wido: Finde heraus, warum er rot steht. Die rote Spalte zahlt an die Familie aus. Wir haben nie eine Münze gesehen.")],
     "wait": ("Wido: Father works the Sunfall Terraces under another name. And the debt clerk in the Gilt Cellars keeps the red pages.", "Wido: Vater arbeitet unter anderem Namen auf den Sonnenfall-Terrassen. Und die Schuldschreiberin in den Gilt-Kellern verwahrt die roten Seiten."),
     "reveal": [("Wido: Father sold his name and left me the bill? ...That's very like him.", "Wido: Vater hat seinen Namen verkauft und mir die Rechnung hinterlassen? ...Das sieht ihm ähnlich."),
                ("Wido: The collector waits at the top of the Span. Beat him and the line stays empty. Please. I'm too young to be red.", "Wido: Der Eintreiber wartet oben auf dem Bogen. Schlag ihn, dann bleibt die Zeile leer. Bitte. Ich bin zu jung, um rot zu sein.")],
     "go": ("Wido: The north end of the Lantern Span. He's the one counting the lanterns.", "Wido: Das Nordende des Laternenbogens. Er ist der, der die Laternen zählt."),
     "reward_lines": [("Wido: He's gone? Thank you! Here, it's all I have. Well. All I have that's not owed.", "Wido: Er ist weg? Danke! Hier, das ist alles, was ich habe. Na ja. Alles, was ich habe und nicht schulde.")],
     "after": ("Wido: I'm learning to keep books. Mostly to see who to blame.", "Wido: Ich lerne Buchhaltung. Hauptsächlich, um zu sehen, wem ich die Schuld geben kann."),
     "steps": [("sunfall_terraces", 8, 20, "left", "villager", "hal",
                [("Vine Guard Hal: Wido sent you? My boy. Yes, I'm in the red column. I sold my name to Veronne to get out of my debts. A dead man owes nothing.", "Weinwächter Hal: Wido schickt dich? Mein Junge. Ja, ich stehe in der roten Spalte. Ich habe Veronne meinen Namen verkauft, um meine Schulden loszuwerden. Ein Toter schuldet nichts."),
                 ("Hal: The debts had to go somewhere. Ask Margit in the Gilt Cellars where.", "Hal: Die Schulden mussten irgendwohin. Frag Margit in den Gilt-Kellern, wohin.")],
                ("Hal: I'm dead on paper. It's restful. You should try it.", "Hal: Auf dem Papier bin ich tot. Das ist erholsam. Solltest du mal probieren.")),
               ("gilt_cellars", 8, 3, "left", "elder", "margit",
                [("Debt Clerk Margit: Hal's debts? Passed to his next of kin, as is proper. The next red line is already written. Wido, son of Hal.", "Schuldschreiberin Margit: Hals Schulden? An den nächsten Angehörigen übertragen, wie es sich gehört. Die nächste rote Zeile ist schon geschrieben. Wido, Sohn von Hal."),
                 ("Margit: The Span collector comes for him tonight. He collects the debt or the debtor. He isn't fussy.", "Margit: Der Bogen-Eintreiber kommt heute Nacht zu ihm. Er treibt die Schuld ein oder den Schuldner. Er ist nicht wählerisch.")],
                ("Margit: Red ink, black ink. In the end it's all ink.", "Margit: Rote Tinte, schwarze Tinte. Am Ende ist alles Tinte."))],
     "betrayer": ("lantern_span", 8, 1, "left", "warden", "ruprecht", ("Span Collector Ruprecht", "Bogen-Eintreiber Ruprecht"),
                  [("Ruprecht: Wido, son of Hal? No. You're not on my page. Yet. Let's start a new page.", "Ruprecht: Wido, Sohn von Hal? Nein. Du stehst nicht auf meiner Seite. Noch nicht. Fangen wir eine neue Seite an.")],
                  [("Ruprecht: Uncollectable. I hate that word.", "Ruprecht: Uneinbringlich. Ich hasse dieses Wort."),
                   ("Ruprecht: The line stays empty tonight. Lines don't stay empty long on this bridge.", "Ruprecht: Die Zeile bleibt heute Nacht leer. Zeilen bleiben auf dieser Brücke nie lange leer.")],
                  None,
                  ("Ruprecht: I count lanterns. One day I'll count yours.", "Ruprecht: Ich zähle Laternen. Eines Tages zähle ich deine."),
                  ("Ruprecht: Paid in part. Go and rest. Interest accrues.", "Ruprecht: Teilweise bezahlt. Geh und ruh dich aus. Die Zinsen laufen.")),
     "twist": {"npc": "hs_wido", "role": "clerk's boy who moves his red line onto his rescuer", "trust": 35, "use": 55, "road": "lantern_span",
               "clue": ("lantern_span", 8, 20, "left", "villager", "fey",
                        [("Lantern Girl Fey: Wido paid Margit last night. To move his line. The next red line will carry the name of whoever helped him.", "Laternenmädchen Fey: Wido hat Margit letzte Nacht bezahlt. Damit sie seine Zeile verschiebt. Die nächste rote Zeile trägt den Namen dessen, der ihm geholfen hat."),
                         ("Fey: Kids learn fast up here. Mostly from their fathers.", "Fey: Kinder lernen hier oben schnell. Meistens von ihren Vätern.")],
                        ("Fey: I light them, I don't read them.", "Fey: Ich zünde sie an, ich lese sie nicht.")),
               "caught": [("You tell Wido you know about the line he moved. He goes pale, then red, then counts out coins.", "Du sagst Wido, dass du von der verschobenen Zeile weißt. Er wird blass, dann rot, dann zählt er Münzen ab."),
                          ("Wido: I'll move it again. To an empty name. There are plenty under the lanterns. Here. Don't tell Father. He'd be proud.", "Wido: Ich verschiebe sie wieder. Auf einen leeren Namen. Unter den Laternen gibt es genug. Hier. Sag es nicht Vater. Er wäre stolz.")],
               "caught_fx": {"coins": 1500, "trust": {"hs_wido": 10}},
               "struck": [("Wido: By the way, the next red line is yours now. I moved mine. The collectors work in pairs.", "Wido: Übrigens, die nächste rote Zeile ist jetzt deine. Ich habe meine verschoben. Die Eintreiber arbeiten zu zweit.")],
               "struck_fx": {"coins": -300},
               "battle": ("redline_collectors", ("Span Collectors", "Bogen-Eintreiber"),
                          ("Span Collector: Uncollectable again. Margit will have to use a rubber.", "Bogen-Eintreiber: Wieder uneinbringlich. Margit muss den Radiergummi nehmen."),
                          ("The collectors take a down payment on your red line.", "Die Eintreiber nehmen eine Anzahlung auf deine rote Zeile.")),
               "ledger": (("The red line", "Die rote Zeile"),
                          ("Wido moved his red line in Veronne's toll ledger onto the name of the one who saved him: yours.", "Wido verschob seine rote Zeile in Veronnes Zollbuch auf den Namen dessen, der ihn gerettet hatte: deinen."))},
     "stages": [("Wido's father is in the red column of Veronne's toll ledger, but alive. Find out why.", "Widos Vater steht in der roten Spalte von Veronnes Zollbuch, lebt aber. Finde heraus, warum.", "Lantern Span"),
                ("Hal sold his name to escape his debts. Ask the debt clerk in the Gilt Cellars where the debts went.", "Hal hat seinen Namen verkauft, um seine Schulden loszuwerden. Frag die Schuldschreiberin in den Gilt-Kellern, wohin sie gingen.", "The Gilt Cellars"),
                ("The next red line is Wido's. Tell him.", "Die nächste rote Zeile ist Widos. Sag es ihm.", "Lantern Span"),
                ("Beat the Span Collector at the north end of the Lantern Span.", "Schlag den Bogen-Eintreiber am Nordende des Laternenbogens.", "Lantern Span"),
                ("The red line stays empty, for now.", "Die rote Zeile bleibt leer, vorerst.", "Lantern Span")]},

    {"id": "brake_file", "turns": True, "duel": True, "road": "long_stair", "reward": ("power_brew", 3),
     "giver": ("long_stair", 10, 4, "down", "villager", "ulf"),
     "intro": [("Brake Mechanic Ulf: Every night someone files the brakes of the Gilt Funicular. Every morning I fix them. Every morning the family pays me.", "Bremsenmechaniker Ulf: Jede Nacht feilt jemand die Bremsen der Gilt-Standseilbahn an. Jeden Morgen repariere ich sie. Jeden Morgen bezahlt mich die Familie."),
               ("Ulf: It can't go on. Someone will get hurt. Probably a passenger. Find the filer for me.", "Ulf: So kann es nicht weitergehen. Jemand wird sich verletzen. Vermutlich ein Fahrgast. Finde den Feiler für mich.")],
     "wait": ("Ulf: The White Stair counters see everyone on the steps at dawn. And Gaspard on the Gilt Span sells files.", "Ulf: Die Zähler auf der Weißen Treppe sehen jeden, der im Morgengrauen auf den Stufen ist. Und Gaspard auf dem Gilt-Bogen verkauft Feilen."),
     "reveal": [("Ulf: Gaspard said that? Well. A brake that never breaks pays nothing. A brake that breaks every night pays every morning.", "Ulf: Das hat Gaspard gesagt? Tja. Eine Bremse, die nie bricht, bringt nichts. Eine Bremse, die jede Nacht bricht, bringt jeden Morgen etwas."),
                ("Ulf: Nobody has died. Yet. That's craftsmanship. And now you're going to tell the family, and I'm going to have to put the brakes on you.", "Ulf: Gestorben ist noch keiner. Bisher. Das ist Handwerkskunst. Und jetzt erzählst du es der Familie, und ich muss bei dir die Bremse ziehen.")],
     "steps": [("white_stair", 9, 6, "left", "villager", "kuno",
                [("Step Counter Kuno: At dawn? One man, every day, coming down from the funicular with metal dust on his sleeves. Step eight hundred and twelve, always.", "Stufenzähler Kuno: Im Morgengrauen? Ein Mann, jeden Tag, kommt von der Bahn herunter, Metallstaub auf den Ärmeln. Stufe achthundertzwölf, immer."),
                 ("Kuno: Gaspard on the Gilt Span sells him a new file every week. Ask Gaspard who.", "Kuno: Gaspard auf dem Gilt-Bogen verkauft ihm jede Woche eine neue Feile. Frag Gaspard, wen.")],
                ("Kuno: Eight hundred and thirteen. Fourteen. Don't make me lose count.", "Kuno: Achthundertdreizehn. Vierzehn. Bring mich nicht aus dem Takt.")),
               ("gilt_span", 2, 6, "right", "villager", "gaspard",
                [("File Seller Gaspard: A file a week, for six years, to the same man. He says he uses them to fix brakes.", "Feilenhändler Gaspard: Eine Feile pro Woche, seit sechs Jahren, an denselben Mann. Er sagt, er braucht sie, um Bremsen zu reparieren."),
                 ("Gaspard: Ulf. Brake mechanic. Lovely man. Never once bought a spanner.", "Gaspard: Ulf. Bremsenmechaniker. Netter Mann. Hat nie einen Schraubenschlüssel gekauft.")],
                ("Gaspard: Files, rasps, nail clippers. Everything for the man who wants things thinner.", "Gaspard: Feilen, Raspeln, Nagelknipser. Alles für den Mann, der Dinge dünner haben will."))],
     "betrayer": ("long_stair", 9, 20, "left", "villager", "ulf_file", ("Brake Mechanic Ulf", "Bremsenmechaniker Ulf"),
                  [("Ulf: Hold on to something. This is going to be a steep descent.", "Ulf: Halt dich fest. Das wird eine steile Abfahrt.")],
                  [("Ulf: Brakes failed. Mine, this time.", "Ulf: Bremsen versagt. Diesmal meine."),
                   ("Ulf: Tell them, then. They'll hire someone who files twice as fast. Progress.", "Ulf: Dann erzähl's ihnen. Sie stellen jemanden ein, der doppelt so schnell feilt. Fortschritt.")],
                  [("You take Ulf's tool roll: three brews and forty-one files, each slightly used.", "Du nimmst Ulfs Werkzeugrolle: drei Tränke und einundvierzig Feilen, jede leicht gebraucht.")],
                  ("Ulf: I fix bicycles now. Nobody on the plateau owns a bicycle. It's very peaceful.", "Ulf: Ich repariere jetzt Fahrräder. Auf der Hochebene hat niemand ein Fahrrad. Sehr friedlich."),
                  ("Ulf: There. You'll stop now. Everyone stops eventually.", "Ulf: So. Jetzt hältst du an. Irgendwann hält jeder an.")),
     "stages": [("Someone files the brakes of the Gilt Funicular every night. Brake Mechanic Ulf wants the filer found.", "Jemand feilt jede Nacht die Bremsen der Gilt-Standseilbahn an. Bremsenmechaniker Ulf will den Feiler finden.", "The Long Stair"),
                ("A man with metal dust on his sleeves buys files on the Gilt Span. Ask the file seller.", "Ein Mann mit Metallstaub auf den Ärmeln kauft Feilen auf dem Gilt-Bogen. Frag den Feilenhändler.", "The Gilt Span"),
                ("The files go to Ulf himself. Ask him why.", "Die Feilen gehen an Ulf selbst. Frag ihn, warum.", "The Long Stair"),
                ("Ulf breaks the brakes he is paid to fix. Stop him on the Long Stair.", "Ulf beschädigt die Bremsen, für deren Reparatur er bezahlt wird. Halt ihn auf der Langen Treppe auf.", "The Long Stair"),
                ("Ulf fixes bicycles now. The brakes hold.", "Ulf repariert jetzt Fahrräder. Die Bremsen halten.", "The Long Stair")]},

    {"id": "wedding_blades", "turns": False, "road": "mirror_flats", "reward": ("max_tonic", 2),
     "giver": ("sunfall_terraces", 6, 16, "down", "tamer_f", "leonore"),
     "intro": [("Bride Leonore: I marry Cousin Florian of the Gilt House on Sunday. Gilt weddings have a tradition: somebody always tries to kill the groom.", "Braut Leonore: Am Sonntag heirate ich Vetter Florian vom Haus Gilt. Gilt-Hochzeiten haben eine Tradition: Irgendwer versucht immer, den Bräutigam umzubringen."),
               ("Leonore: Find out who's been hired this time. I want him alive at least until the vows. After that, the paperwork is simpler.", "Leonore: Finde heraus, wer diesmal angeheuert wurde. Ich will ihn wenigstens bis zum Jawort lebend. Danach ist der Papierkram einfacher.")],
     "wait": ("Leonore: Posy does the flowers, on Cloudshadow Meadow. And the priest rehearses on the White Stair. Both hear everything.", "Leonore: Posy macht die Blumen, auf der Wolkenschattenwiese. Und der Priester probt auf der Weißen Treppe. Beide hören alles."),
     "reveal": [("Leonore: The groom hired Dorian for me? Florian! And I thought he wasn't the romantic type.", "Leonore: Der Bräutigam hat Dorian für mich angeheuert? Florian! Und ich dachte, er sei nicht der romantische Typ."),
                ("Leonore: Yes, I hired myself for him. A bride should be prepared. Now beat Dorian on the Mirror Flats, and Sunday is just a wedding again. Mostly.", "Leonore: Ja, ich habe mich selbst für ihn angeheuert. Eine Braut sollte vorbereitet sein. Jetzt schlag Dorian auf der Spiegelebene, dann ist Sonntag wieder nur eine Hochzeit. Größtenteils.")],
     "go": ("Leonore: The north end of the Mirror Flats. He practises his toast there. And his aim.", "Leonore: Das Nordende der Spiegelebene. Dort übt er seine Tischrede. Und sein Zielen."),
     "reward_lines": [("Leonore: Dorian is beaten? Then Florian lives to say 'I do'. Here, a wedding favour. Don't eat the almonds.", "Leonore: Dorian ist geschlagen? Dann lebt Florian, um Ja zu sagen. Hier, ein Gastgeschenk. Iss die Mandeln nicht.")],
     "after": ("Leonore: We're very happy. We sleep in shifts.", "Leonore: Wir sind sehr glücklich. Wir schlafen in Schichten."),
     "steps": [("cloudshadow_meadow", 7, 13, "down", "villager", "posy",
                [("Florist Posy: The Gilt wedding? Lilies for the bride, lilies for the groom, lilies for the funeral after. I order in bulk.", "Floristin Posy: Die Gilt-Hochzeit? Lilien für die Braut, Lilien für den Bräutigam, Lilien für die Beerdigung danach. Ich bestelle in großen Mengen."),
                 ("Posy: The priest knows who paid for what. Ask him. And tell me: are you with the bride or the groom?", "Posy: Der Priester weiß, wer was bezahlt hat. Frag ihn. Und sag mal: Gehörst du zur Braut oder zum Bräutigam?")],
                ("Posy: Lilies last a week. Gilt marriages, about the same.", "Posy: Lilien halten eine Woche. Gilt-Ehen ungefähr genauso.")),
               ("white_stair", 1, 4, "right", "elder", "aldous",
                [("Priest Aldous: Two payments for Sunday. One from the groom's side, for 'the removal of the bride after the vows'. One from the bride's side, for the groom, same terms.", "Priester Aldous: Zwei Zahlungen für Sonntag. Eine von der Seite des Bräutigams, für 'die Beseitigung der Braut nach dem Jawort'. Eine von der Seite der Braut, für den Bräutigam, gleiche Bedingungen."),
                 ("Aldous: The bride's man is herself. The groom's man is his best man, Dorian, practising on the Mirror Flats. I marry them anyway. It's a living.", "Aldous: Der Mann der Braut ist sie selbst. Der Mann des Bräutigams ist sein Trauzeuge Dorian, der auf der Spiegelebene übt. Ich traue sie trotzdem. Davon lebe ich.")],
                ("Aldous: Till death do them part. In this family, it's a schedule.", "Aldous: Bis dass der Tod sie scheidet. In dieser Familie ist das ein Terminplan."))],
     "betrayer": ("mirror_flats", 4, 2, "right", "villager", "dorian", ("Best Man Dorian", "Trauzeuge Dorian"),
                  [("Dorian: You're from the bride's side. I can tell. You have the look of a guest who isn't staying for dessert.", "Dorian: Du gehörst zur Braut. Das sieht man. Du siehst aus wie ein Gast, der nicht bis zum Nachtisch bleibt.")],
                  [("Dorian: Fine. I'll give a toast instead. It was going to be short anyway.", "Dorian: Schön. Dann halte ich eben eine Rede. Sie wäre sowieso kurz gewesen."),
                   ("Dorian: Tell Leonore that Florian paid me with her own dowry. They really are made for each other.", "Dorian: Sag Leonore, dass Florian mich mit ihrer eigenen Mitgift bezahlt hat. Die beiden sind wirklich füreinander gemacht.")],
                  None,
                  ("Dorian: To the happy couple. May they both survive the honeymoon.", "Dorian: Auf das glückliche Paar. Mögen beide die Flitterwochen überleben.")),
     "favor": {"npc": "hs_posy", "role": "florist of the Gilt weddings who arranges more than flowers", "trust": 40, "use": 50, "kind": "believe_tip", "road": "cloudshadow_meadow",
               "kind_answer": ("With the flowers.", "Zu den Blumen."), "cold_answer": ("With whoever pays.", "Zu dem, der zahlt."),
               "ask": ("Posy: Between us: the groom's cake is poisoned. Carry the bride's cake to his table instead and swap them. Trust me.", "Posy: Unter uns: Die Torte des Bräutigams ist vergiftet. Trag stattdessen die Torte der Braut an seinen Tisch und tausch sie. Vertrau mir."),
               "yes": ("Swap the cakes", "Die Torten tauschen"), "no": ("Leave the cakes", "Die Torten lassen"),
               "betray": [("The bride's cake was the poisoned one. As you set it down, the bride's guards seize you for trying to poison the groom. Posy waves from the door.", "Die Torte der Braut war die vergiftete. Als du sie abstellst, packen dich die Wachen der Braut, weil du den Bräutigam vergiften wolltest. Posy winkt von der Tür.")],
               "reward": [("You swap the cakes. The groom's cake really was poisoned; the cousin who baked it eats his own slice by mistake and spends the wedding indisposed. Posy slips you a tip from the bouquet budget.", "Du tauschst die Torten. Die Torte des Bräutigams war wirklich vergiftet; der Vetter, der sie gebacken hat, isst aus Versehen sein eigenes Stück und verbringt die Hochzeit unpässlich. Posy steckt dir ein Trinkgeld aus dem Blumenbudget zu.")],
               "reward_fx": {"item": "wake_bell"},
               "kept": [("You swap the cakes. Neither was poisoned. Posy shrugs. 'Rumours are cheaper than arsenic.'", "Du tauschst die Torten. Keine war vergiftet. Posy zuckt die Schultern. 'Gerüchte sind billiger als Arsen.'")],
               "battle": ("posy_guards", ("Bridal Guards", "Brautwachen"),
                          ("Bridal Guard: Fine, you didn't do it. Someone did. Someone always does.", "Brautwache: Schön, du warst es nicht. Irgendwer war's. Irgendwer ist es immer."),
                          ("The guards fine you for cake-related conduct.", "Die Wachen verhängen eine Strafe wegen tortenbezogenen Verhaltens.")),
               "ledger": (("The cake swap", "Der Tortentausch"),
                          ("Florist Posy talked you into swapping the wedding cakes, so that you would carry the poison to the groom's table.", "Floristin Posy überredete dich, die Hochzeitstorten zu tauschen, damit du das Gift an den Tisch des Bräutigams trägst."))},
     "stages": [("Bride Leonore wants to know who has been hired to kill her groom.", "Braut Leonore will wissen, wer angeheuert wurde, um ihren Bräutigam umzubringen.", "Sunfall Terraces"),
                ("The priest knows who paid for what. Ask him on the White Stair.", "Der Priester weiß, wer was bezahlt hat. Frag ihn auf der Weißen Treppe.", "The White Stair"),
                ("Both sides hired a killer. Tell Leonore about the groom's man.", "Beide Seiten haben jemanden angeheuert. Erzähl Leonore vom Mann des Bräutigams.", "Sunfall Terraces"),
                ("Beat Best Man Dorian on the Mirror Flats.", "Schlag Trauzeuge Dorian auf der Spiegelebene.", "Mirror Flats"),
                ("Leonore and Florian are married. They sleep in shifts.", "Leonore und Florian sind verheiratet. Sie schlafen in Schichten.", "Sunfall Terraces")]},

    {"id": "salt_saint", "turns": True, "duel": True, "road": "brine_catacombs", "reward": ("revival_leaf", 3),
     "giver": ("brine_catacombs", 8, 6, "left", "elder", "kaspar"),
     "intro": [("Relic Seller Kaspar: Relics of the Salt Saint! She wept salt for the lake, and the lake took her. A pinch heals anything. A bag heals more.", "Reliquienhändler Kaspar: Reliquien der Salzheiligen! Sie weinte Salz für den See, und der See nahm sie. Eine Prise heilt alles. Ein Beutel heilt mehr."),
               ("Kaspar: My stock is running low. Find the Saint's tomb down here and bring me more of her. Sorry, more of her salt.", "Kaspar: Mein Vorrat geht zur Neige. Finde das Grab der Heiligen hier unten und bring mir mehr von ihr. Verzeihung, mehr von ihrem Salz.")],
     "wait": ("Kaspar: A pilgrim resting at the Fallen Planet heard the Saint sing. And the tomb is somewhere in the drowned chapel below.", "Kaspar: Eine Pilgerin, die beim Gefallenen Planeten rastet, hat die Heilige singen hören. Und das Grab liegt irgendwo in der ertrunkenen Kapelle unten."),
     "reveal": [("Kaspar: She wants fifty-fifty? She's dead. The dead take what they're given.", "Kaspar: Sie will halbe-halbe? Sie ist tot. Tote nehmen, was man ihnen gibt."),
                ("Kaspar: A living saint is just a girl who sings off key. A dead one is a business. You've seen too much of the business.", "Kaspar: Eine lebende Heilige ist nur ein Mädchen, das falsch singt. Eine tote ist ein Geschäft. Du hast zu viel vom Geschäft gesehen."),
                ("Kaspar: Come down the east passage. I'll sell you a pinch for the road.", "Kaspar: Komm in den Ostgang. Ich verkaufe dir eine Prise für unterwegs.")],
     "steps": [("fallen_planet", 2, 12, "right", "elder", "ortrud",
                [("Pilgrim Ortrud: The Salt Saint? I bought a pinch of her for my knee. The knee is the same. The pinch tasted of kitchen.", "Pilgerin Ortrud: Die Salzheilige? Ich habe eine Prise von ihr für mein Knie gekauft. Das Knie ist dasselbe. Die Prise schmeckte nach Küche."),
                 ("Ortrud: But I heard singing under the flats. Someone very alive, very bored, in the drowned chapel.", "Ortrud: Aber ich habe unter der Ebene Gesang gehört. Jemand sehr Lebendiges, sehr Gelangweiltes, in der ertrunkenen Kapelle.")],
                ("Ortrud: I walked here from Paleshore on my bad knee. The knee says it was not worth it.", "Ortrud: Ich bin auf meinem schlechten Knie von Paleshore hergelaufen. Das Knie sagt, es hat sich nicht gelohnt.")),
               ("brine_catacombs@1", 8, 2, "down", "tamer_f", "elsbeth",
                [("Saint Elsbeth: The Salt Saint? That's me. Alive. Kaspar is my brother. He sells kitchen salt in little bags and I sing down here so pilgrims hear it.", "Die heilige Elsbeth: Die Salzheilige? Das bin ich. Lebendig. Kaspar ist mein Bruder. Er verkauft Küchensalz in kleinen Beuteln, und ich singe hier unten, damit die Pilger es hören."),
                 ("Elsbeth: We split it sixty-forty. I asked for fifty-fifty. He said saints don't need money. Tell him I'm done being dead.", "Elsbeth: Wir teilen sechzig zu vierzig. Ich wollte halbe-halbe. Er sagte, Heilige brauchen kein Geld. Sag ihm, ich habe genug davon, tot zu sein.")],
                ("Elsbeth: La la laaa. Twelve years of the same hymn. I hate this hymn.", "Elsbeth: La la laaa. Zwölf Jahre dieselbe Hymne. Ich hasse diese Hymne."))],
     "betrayer": ("brine_catacombs", 8, 11, "left", "elder", "kaspar_salt", ("Relic Seller Kaspar", "Reliquienhändler Kaspar"),
                  [("Kaspar: Every saint needs a martyr. You'll do. I'll sell your boots as relics.", "Kaspar: Jede Heilige braucht einen Märtyrer. Du reichst. Deine Stiefel verkaufe ich als Reliquien.")],
                  [("Kaspar: Fine. Fifty-fifty. Tell her. No, wait, don't tell her I said fine.", "Kaspar: Schön. Halbe-halbe. Sag's ihr. Nein, warte, sag ihr nicht, dass ich schön gesagt habe."),
                   ("Kaspar: Take my last bags. They're real salt, at least. Kitchen-blessed.", "Kaspar: Nimm meine letzten Beutel. Wenigstens ist es echtes Salz. Küchengeweiht.")],
                  [("You take Kaspar's relic box: three revival leaves under a false bottom and a receipt for forty sacks of kitchen salt.", "Du nimmst Kaspars Reliquienkasten: drei Lebensblätter unter einem doppelten Boden und eine Quittung über vierzig Säcke Küchensalz.")],
                  ("Kaspar: Elsbeth sings above ground now. Fifty-fifty. Business has never been worse.", "Kaspar: Elsbeth singt jetzt oben. Halbe-halbe. Das Geschäft lief nie schlechter."),
                  ("Kaspar: Rest, pilgrim. Salt heals all wounds. It also stings.", "Kaspar: Ruh dich aus, Pilger. Salz heilt alle Wunden. Es brennt auch.")),
     "stages": [("Relic Seller Kaspar wants more relics of the Salt Saint from the Brine Catacombs.", "Reliquienhändler Kaspar will mehr Reliquien der Salzheiligen aus den Solekatakomben.", "The Brine Catacombs"),
                ("A pilgrim heard singing in the drowned chapel. Look below in the Brine Catacombs.", "Eine Pilgerin hat in der ertrunkenen Kapelle Gesang gehört. Sieh unten in den Solekatakomben nach.", "The Brine Catacombs"),
                ("The Salt Saint is alive and wants her share. Tell Kaspar.", "Die Salzheilige lebt und will ihren Anteil. Sag es Kaspar.", "The Brine Catacombs"),
                ("Kaspar wants a martyr. Face him in the east passage of the Brine Catacombs.", "Kaspar will einen Märtyrer. Stell ihn im Ostgang der Solekatakomben.", "The Brine Catacombs"),
                ("Saint Elsbeth sings above ground now, fifty-fifty.", "Die heilige Elsbeth singt jetzt oben, halbe-halbe.", "The Brine Catacombs")]},
]

# Wayfarers: (map, x, y, facing, id, title, size, talk, intro, defeat). Rings follow the road's range.
FOLK = [
    ("long_stair", 1, 7, "right", "agnes", ("Stair Sweeper Agnes", "Treppenfegerin Agnes"), 2,
     ("Agnes: I sweep the Long Stair top to bottom. The Gilt House sweeps people the same way.", "Agnes: Ich fege die Lange Treppe von oben bis unten. Das Haus Gilt fegt Leute genauso."),
     ("Agnes: You're standing in my dust. Fight or shift.", "Agnes: Du stehst in meinem Staub. Kämpf oder geh zur Seite."),
     ("Agnes: Swept. Fair enough.", "Agnes: Weggefegt. Na gut.")),
    ("cloudshadow_meadow", 2, 15, "right", "lenz", ("Shadow Painter Lenz", "Schattenmaler Lenz"), 3,
     ("Lenz: I paint the cloud shadows before they move. The Gilt House buys the paintings to prove they own the weather.", "Lenz: Ich male die Wolkenschatten, bevor sie weiterziehen. Das Haus Gilt kauft die Bilder, um zu beweisen, dass ihm das Wetter gehört."),
     ("Lenz: Hold still, you're in the composition. And now you're in a fight.", "Lenz: Halt still, du bist im Bild. Und jetzt in einem Kampf."),
     ("Lenz: Smudged. I'll call it modern.", "Lenz: Verwischt. Ich nenne es modern.")),
    ("mirror_flats", 6, 18, "left", "sigrun", ("Mirror Walker Sigrun", "Spiegelgängerin Sigrun"), 3,
     ("Sigrun: I walk the salt where it's thinnest, for practice. Practice for what, nobody asks.", "Sigrun: Ich laufe übers Salz, wo es am dünnsten ist, zur Übung. Wofür, fragt keiner."),
     ("Sigrun: You've got heavy feet. Let's test the salt with you.", "Sigrun: Du hast schwere Füße. Testen wir das Salz mit dir."),
     ("Sigrun: Still standing. Both of us. Disappointing.", "Sigrun: Wir stehen beide noch. Enttäuschend.")),
    ("orrery_ridge", 4, 16, "right", "oswin", ("Brass Hunter Oswin", "Messingjäger Oswin"), 3,
     ("Oswin: Every brass screw that falls off the Orrery is worth a meal. I've eaten very well this year.", "Oswin: Jede Messingschraube, die vom Planetarium fällt, ist eine Mahlzeit wert. Ich habe dieses Jahr sehr gut gegessen."),
     ("Oswin: You're after my screws. Everyone is.", "Oswin: Du willst meine Schrauben. Alle wollen das."),
     ("Oswin: Take a screw. Just one. A loose one.", "Oswin: Nimm eine Schraube. Nur eine. Eine lockere.")),
    ("sunfall_terraces", 9, 9, "left", "bruna", ("Grape Treader Bruna", "Traubentreterin Bruna"), 3,
     ("Bruna: I tread the Gilt grapes barefoot. The family says it adds character. The doctor says it adds fungus.", "Bruna: Ich trete die Gilt-Trauben barfuß. Die Familie sagt, das gibt Charakter. Der Arzt sagt, das gibt Fußpilz."),
     ("Bruna: You walked on my vines. Now I walk on you.", "Bruna: Du bist über meine Reben gelaufen. Jetzt laufe ich über dich."),
     ("Bruna: Pressed flat. That's my job, not yours.", "Bruna: Plattgedrückt. Das ist mein Job, nicht deiner.")),
    ("lantern_span", 7, 3, "left", "hedda", ("Rope Inspector Hedda", "Seilprüferin Hedda"), 3,
     ("Hedda: I inspect the Span ropes. I pass them all. Veronne pays me per pass, the families pay me per fail.", "Hedda: Ich prüfe die Seile des Bogens. Ich lasse alle durch. Veronne zahlt pro Bestanden, die Familien pro Durchgefallen."),
     ("Hedda: Let's see how much strain you take.", "Hedda: Mal sehen, wie viel Last du aushältst."),
     ("Hedda: Passed. Don't let it go to your head.", "Hedda: Bestanden. Bild dir nichts darauf ein.")),
    ("fallen_planet", 6, 6, "down", "thea", ("Crater Prospector Thea", "Kratersucherin Thea"), 3,
     ("Thea: The planet fell, the crater stayed. I sell crater by the bucket. Very fashionable in Gildcrest gardens.", "Thea: Der Planet fiel, der Krater blieb. Ich verkaufe Krater eimerweise. Sehr in Mode in den Gärten von Gildcrest."),
     ("Thea: This hole is mine. Dig your own.", "Thea: Dieses Loch gehört mir. Grab dir dein eigenes."),
     ("Thea: Fine. Have a bucket. Bring it back.", "Thea: Schön. Nimm einen Eimer. Bring ihn zurück.")),
    ("fallen_planet", 3, 17, "right", "moritz", ("Star Catcher Moritz", "Sternenfänger Moritz"), 2,
     ("Moritz: Isaura says stars come loose under the Orrery. I'm here with a net. So far: two moths and a hat.", "Moritz: Isaura sagt, unter dem Planetarium lösen sich Sterne. Ich bin mit einem Netz hier. Bisher: zwei Motten und ein Hut."),
     ("Moritz: You scared off my star. Fight me.", "Moritz: Du hast meinen Stern verscheucht. Kämpf mit mir."),
     ("Moritz: Caught out. Not a star in sight.", "Moritz: Ertappt. Kein Stern in Sicht.")),
    ("brine_catacombs", 2, 3, "right", "bendix", ("Salt Monk Bendix", "Salzmönch Bendix"), 3,
     ("Bendix: I took a vow of silence. Then a vow of salt. The silence was easier.", "Bendix: Ich habe ein Schweigegelübde abgelegt. Dann ein Salzgelübde. Das Schweigen war leichter."),
     ("Bendix: ...!", "Bendix: ...!"),
     ("Bendix: Ow. There. I said a word. Happy?", "Bendix: Au. So. Ich habe ein Wort gesagt. Zufrieden?")),
    ("brine_catacombs@1", 2, 4, "right", "wiebke", ("Font Keeper Wiebke", "Beckenhüterin Wiebke"), 3,
     ("Wiebke: I keep the chapel font full. Halloran's barrels keep it empty. We have an arrangement. It involves shouting.", "Wiebke: Ich halte das Kapellenbecken voll. Hallorans Fässer halten es leer. Wir haben eine Abmachung. Sie beinhaltet Geschrei."),
     ("Wiebke: Are you with the barrels? You look like you're with the barrels.", "Wiebke: Gehörst du zu den Fässern? Du siehst aus, als gehörst du zu den Fässern."),
     ("Wiebke: Not with the barrels, then. Sorry. Here, holy water. Mostly.", "Wiebke: Also nicht zu den Fässern. Entschuldige. Hier, Weihwasser. Größtenteils.")),
    ("gilt_cellars", 6, 7, "down", "tilman", ("Cellar Guard Tilman", "Kellerwache Tilman"), 3,
     ("Tilman: I guard the Gilt Cellars. Mostly from the family. They drink the good years and refill them with the bad ones.", "Tilman: Ich bewache die Gilt-Keller. Meistens vor der Familie. Sie trinken die guten Jahrgänge und füllen sie mit den schlechten auf."),
     ("Tilman: Nobody comes down here without a reason. Let's hear yours. In battle.", "Tilman: Niemand kommt ohne Grund hier runter. Lass hören. Im Kampf."),
     ("Tilman: Fair. Mind cask forty-one. It knocks.", "Tilman: Gut. Pass auf Fass einundvierzig auf. Es klopft.")),
    ("gilt_cellars@1", 3, 7, "right", "edeltraud", ("Vault Steward Edeltraud", "Tresorverwalterin Edeltraud"), 3,
     ("Edeltraud: The strongroom holds the Gilt gold, the Gilt wills and the Gilt grudges. The grudges take the most space.", "Edeltraud: Im Tresorraum liegen das Gilt-Gold, die Gilt-Testamente und der Gilt-Groll. Der Groll braucht am meisten Platz."),
     ("Edeltraud: Visitors sign in. In battle.", "Edeltraud: Besucher tragen sich ein. Im Kampf."),
     ("Edeltraud: Signed. Don't touch anything. Especially the wills. They bite.", "Edeltraud: Eingetragen. Fass nichts an. Vor allem die Testamente. Die beißen.")),
]


# --- Roads, kinds and rings ----------------------------------------------------------------------
def encounters():
    return json.load(open(os.path.join(ROOT, "data", "encounters.json"), encoding="utf-8"))


def species():
    return {s["name"]: s for s in json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))}


def ring(road):
    return ROUTE[road]["ring"] if road in ROUTE else NEW[road]


def kinds(road, enc):
    if road == "gilt_cellars":
        return kinds("sunfall_terraces", enc) + CELLAR_KINDS
    table = enc.get(road) or enc.get(ROUTE_OF.get(road, ""), {})
    out = []
    for s in table.get("spawns", []):
        if s["species"] not in out:
            out.append(s["species"])
    return out


ROUTE_OF = {"fallen_planet": "orrery_ridge", "brine_catacombs": "mirror_flats"}


def pick(road, n, offset, enc, sp):
    """n kinds of [road] within three elements; the rest of Halcyra's wild kinds fill in."""
    own = kinds(road, enc)
    pool = own[offset % len(own):] + own[:offset % len(own)]
    for r in list(ROUTE) + WILD:
        for k in kinds(r, enc):
            if k not in pool:
                pool.append(k)
    for combo in itertools.combinations(pool, n):
        els = set()
        for k in combo:
            els.update(sp[k]["elements"])
        if len(els) <= 3:
            return list(combo)
    raise SystemExit("%s: no %d kinds within three elements" % (road, n))


def spread(road, n):
    """Rings of an n-strong Wayfarer team on [road]: spread up to the top of its range."""
    lo, hi = ring(road)
    return [lo + round((hi - lo) * (i + 1) / n) for i in range(n)]


def crew(road, levels, offset, enc, sp):
    return [{"species": k, "level": lv} for k, lv in zip(pick(road, len(levels), offset, enc, sp), levels)]


# --- Map helpers ---------------------------------------------------------------------------------
def level(world, ref):
    mid, _, fl = ref.partition("@")
    m = world.maps[mid]
    return m if not fl else m["floors"][int(fl) - 1]


WALK = set(".,_:%f=+*")


def place(world, ref, n):
    lv = level(world, ref)
    x, y = n["x"], n["y"]
    if lv["rows"][y][x] not in WALK:
        raise SystemExit("%s: %s at %d,%d stands on %r" % (ref, n["id"], x, y, lv["rows"][y][x]))
    taken = [(e["x"], e["y"]) for k in ("npcs", "signs", "secrets", "warps") for e in lv.get(k, [])]
    if (x, y) in taken:
        raise SystemExit("%s: %s at %d,%d is taken" % (ref, n["id"], x, y))
    lv.setdefault("npcs", []).append(n)


def ref_of(key):
    return "%s/%s" % (SIDE, key)


# --- Build ---------------------------------------------------------------------------------------
TEXT = {}
QUESTS = []
BATTLES = {}
CLANS = {"figures": {}, "favors": {}, "betrayals": {}, "ledger": []}


def text(key, entry):
    TEXT[key] = entry
    return ref_of(key)


def hook(group, build):
    """halcyra.py's last line: its GROUP and build() with this module added."""
    def both(world):
        build(world)
        side(world)
    return group + GROUP, both


def side(world):
    TEXT.clear()
    QUESTS.clear()
    BATTLES.clear()
    for k in CLANS:
        CLANS[k] = [] if k == "ledger" else {}
    enc = encounters()
    sp = species()
    maps(world)
    doors(world)
    for i, g in enumerate(GOALS):
        goal(world, g, i, enc, sp)
    for i, f in enumerate(FOLK):
        wayfarer(world, f, i, enc, sp)
    world.add_text(SIDE, TEXT)


def doors(world):
    """Side ways from three routes into the new places (the town maps stay untouched)."""
    for mid, y, row, x, to, tx, ty, face in (
            ("orrery_ridge", 14, "__,.......:^", 0, "fallen_planet", 10, 10, "left"),
            ("mirror_flats", 12, "^%%....:::__", 11, "brine_catacombs", 1, 7, "right"),
            ("sunfall_terraces", 13, "^.:::....,__", 11, "gilt_cellars", 5, 10, "up")):
        m = world.maps[mid]
        m["rows"][y] = row
        check_rows(mid, m["rows"])
        m["warps"].append(warp(x, y, to, tx, ty, face))


def goal(world, g, i, enc, sp):
    gid = g["id"]
    k = "q4_" + gid
    f = {s: "%s_%s" % (k, s) for s in ("asked", "s1", "s2", "reveal", "done", "paid", "clue")}
    reward = "set_flag %s; give_item %s %d; quest_stage %s 4" % (f["paid"], g["reward"][0], g["reward"][1], k)
    if "twist" in g:
        reward += "; betrayal hs_" + gid
    # Giver: a chain of "if"s, last state first.
    gm, gx, gy, gf, gs, gname = g["giver"]
    text(gid + "_wait", ls(g["wait"]))
    text(gid + "_reveal", {"if": {"flag": f["s2"]}, "else": gid + "_wait", "lines": ls(*g["reveal"]),
                           "action": "set_flag %s; quest_stage %s 3" % (f["reveal"], k)})
    nxt = gid + "_reveal"
    if not g["turns"]:
        text(gid + "_go", {"if": {"flag": f["reveal"]}, "else": nxt, "lines": ls(g["go"])})
        text(gid + "_reward", {"if": {"flag": f["done"]}, "else": gid + "_go", "lines": ls(*g["reward_lines"]), "action": reward})
        text(gid + "_after", {"if": {"flag": f["paid"]}, "else": gid + "_reward", "lines": ls(g["after"])})
        nxt = gid + "_after"
    giver = text(gid, {"if": {"not_flag": f["asked"]}, "else": nxt, "lines": ls(*g["intro"]), "action": "set_flag " + f["asked"]})
    extra = {"hide_flag": f["reveal"]} if g["turns"] else {}
    place(world, gm, npc("%s_%s" % (k, gname), gx, gy, gf, giver, gs, **extra))
    # Steps; the first may carry a trust question and a favor.
    for n, ((sm, sx, sy, sf, ss, sid, talk, after), (shown, sets)) in enumerate(zip(g["steps"], [(f["asked"], f["s1"]), (f["s1"], f["s2"])])):
        key = "%s_%s" % (gid, sid)
        entry = {"if": {"not_flag": sets}, "else": key + "_after", "lines": ls(*talk),
                 "action": "set_flag %s; quest_stage %s %d" % (sets, k, n + 1)}
        text(key + "_after", ls(after))
        fv = g.get("favor")
        if fv and n == 0:
            entry["choices"] = [{"text": t(*fv["kind_answer"]), "action": "trust %s 15" % fv["npc"]},
                                {"text": t(*fv["cold_answer"]), "action": "trust %s -5 10" % fv["npc"]}]
            text(key + "_favor", {"if": {"not_flag": "favor_hs_" + gid}, "else": key + "_after", "lines": ls(fv["ask"]),
                                  "choices": [{"text": t(*fv["yes"]), "action": "favor hs_" + gid}, {"text": t(*fv["no"])}]})
            entry["else"] = key + "_favor"
            favor(gid, fv, enc, sp, i)
        place(world, sm, npc("%s_%s" % (k, sid), sx, sy, sf, text(key, entry), ss, show_flag=shown))
    # Betrayer: a map Wayfarer, or a story duel.
    bm, bx, by, bf, bs, bid, title, intro, defeat, loot, after = g["betrayer"][:11]
    key = "%s_%s" % (gid, bid)
    text(key + "_after", ls(after))
    end = key + "_after"
    if g["turns"]:
        end = text(key + "_loot", {"if": {"not_flag": f["paid"]}, "else": key + "_after", "lines": ls(*loot), "action": reward}).split("/")[1]
    road = bm.split("@")[0] if bm.split("@")[0] in ROUTE or bm.split("@")[0] in WILD else g["road"]
    lo, hi = ring(road)
    if g.get("duel"):
        team = crew(g["road"], [hi - 1, hi, hi + 1, hi + 2], i, enc, sp)
        BATTLES["hs_" + gid] = {"trainer": t(*title), "team": team, "ai": 2, "money": (hi + 2) * 60,
                                "defeat": text(key + "_defeat", ls(*defeat)), "lose": text(key + "_lose", ls(g["betrayer"][11])),
                                "win_flags": [f["done"]]}
        talk = text(key, {"if": {"not_flag": f["done"]}, "else": end, "lines": ls(*intro), "action": "battle hs_" + gid})
        place(world, bm, npc("%s_%s" % (k, bid), bx, by, bf, talk, bs, show_flag=f["reveal"]))
    else:
        team = crew(road, [hi - 1, hi, hi + 1], i, enc, sp)
        place(world, bm, npc("%s_%s" % (k, bid), bx, by, bf, ref_of(end), bs, trainer=t(*title), show_flag=f["reveal"],
                             intro=text(key + "_intro", ls(*intro)), defeat=text(key + "_defeat", ls(*defeat)),
                             money=(hi + 1) * 50, team=team, win_flags=[f["done"]], no_rematch=True))
    if "twist" in g:
        twist(world, gid, g["twist"], f, enc, sp, i)
    stages = [{"text": t(en, de), "where": w} for en, de, w in g["stages"]]
    QUESTS.append({"id": k, "text": stages[0]["text"], "where": stages[0]["where"], "show": f["asked"], "done": f["done"],
                   "progress": [f["s1"], f["s2"], f["reveal"], f["done"]], "stages": stages})


def side_battle(name, spec, road, enc, sp, i):
    bid, title, defeat, lose = spec
    lo, hi = ring(road)
    BATTLES["hs_" + bid] = {"trainer": t(*title), "team": crew(road, [hi, hi + 1, hi + 2], i + 3, enc, sp), "ai": 2,
                            "money": (hi + 2) * 40, "defeat": text(bid + "_defeat", ls(defeat)), "lose": text(bid + "_lose", ls(lose))}
    return "hs_" + bid


def ledger(gid, pair):
    CLANS["ledger"].append({"id": "hs_" + gid, "act": 4, "ref": text("ledger_" + gid, ls(*pair))})
    return "hs_" + gid


def favor(gid, fv, enc, sp, i):
    CLANS["figures"][fv["npc"]] = {"clan": "gilt", "role": fv["role"], "trust": fv["trust"], "use": fv["use"]}
    d = {"npc": fv["npc"], "kind": fv["kind"], "reward_chance": 0.3}
    if "amount" in fv:
        d["amount"] = fv["amount"]
    d["betray"] = {"say": text(gid + "_betray", ls(*fv["betray"])), "battle": side_battle(gid, fv["battle"], fv["road"], enc, sp, i),
                   "ledger": ledger(gid, fv["ledger"]), "use": {fv["npc"]: 10}}
    d["reward"] = dict({"say": text(gid + "_rewarded", ls(*fv["reward"])), "trust": {fv["npc"]: 10}}, **fv.get("reward_fx", {}))
    d["kept"] = dict({"say": text(gid + "_kept", ls(*fv["kept"])), "trust": {fv["npc"]: 5}}, **fv.get("kept_fx", {}))
    CLANS["favors"]["hs_" + gid] = d


def twist(world, gid, tw, f, enc, sp, i):
    CLANS["figures"][tw["npc"]] = {"clan": "gilt", "role": tw["role"], "trust": tw["trust"], "use": tw["use"]}
    cm, cx, cy, cf, cs, cid, talk, after = tw["clue"]
    key = "%s_%s" % (gid, cid)
    text(key + "_after", ls(after))
    clue = text(key, {"if": {"not_flag": f["clue"]}, "else": key + "_after", "lines": ls(*talk), "action": "set_flag " + f["clue"]})
    place(world, cm, npc("q4_%s_%s" % (gid, cid), cx, cy, cf, clue, cs, show_flag=f["asked"]))
    led = ledger(gid, tw["ledger"])
    CLANS["betrayals"]["hs_" + gid] = {
        "act": 4, "region": "halcyra", "npc": tw["npc"], "rule": "warned", "warned_by": [f["clue"]],
        "caught": dict({"ledger": led, "say": text(gid + "_caught", ls(*tw["caught"]))}, **tw["caught_fx"]),
        "struck": dict({"ledger": led, "say": text(gid + "_struck", ls(*tw["struck"])),
                        "battle": side_battle(gid, tw["battle"], tw["road"], enc, sp, i)}, **tw["struck_fx"])}


def wayfarer(world, fk, i, enc, sp):
    ref, x, y, face, wid, title, size, talk, intro, defeat = fk
    road = ref.split("@")[0]
    lo, hi = ring(road)
    place(world, ref, npc("hs_" + wid, x, y, face, text(wid, ls(talk)), "villager", trainer=t(*title),
                          intro=text(wid + "_intro", ls(intro)), defeat=text(wid + "_defeat", ls(defeat)),
                          money=hi * 40, team=crew(road, spread(road, size), i + 1, enc, sp)))


# --- The three places ----------------------------------------------------------------------------
def sign(x, y, key, *pairs):
    text(key, ls(*pairs))
    return {"x": x, "y": y, "dialogue": ref_of(key)}


def maps(world):
    # The Fallen Planet: the Orrery's missing brass planet in its own crater, west of Orrery Ridge.
    rows = ["^^^^^^^^^^^^",
            "^,,::@@::,,^",
            "^,,:.|..|:,^",
            "^::..S...::^",
            "^,,......,,^",
            "^,,.@@@@.,,^",
            "^::.@..@.::^",
            "^::.@..@.::^",
            "^,,........^",
            "^,,..,,,...^",
            "^::.......__",
            "^::..,,,...^",
            "^,,,,,,,,..^",
            "^,,,::::,,.^",
            "^.....L....^",
            "^::,,,,,::.^",
            "^::,,,,,::.^",
            "^,,......,,^",
            "^,,,.S..,,,^",
            "^^^^^^^^^^^^"]
    check_rows("fallen_planet", rows)
    world.add_map("fallen_planet", {
        "name": t("The Fallen Planet", "Der Gefallene Planet"), "region": "halcyra", "biome": "route", "backdrop": "ridge",
        "outdoor": True, "encounters": "fallen_planet", "rows": rows,
        "warps": [warp(11, 10, "orrery_ridge", 1, 14, "right")], "npcs": [],
        "signs": [sign(5, 3, "fallen_sign", ("THE FALLEN PLANET", "DER GEFALLENE PLANET"),
                       ("A brass planet the size of a house lies dented in its own crater. Three families have put up three 'PRIVATE' signs on it.", "Ein Messingplanet von der Größe eines Hauses liegt verbeult in seinem eigenen Krater. Drei Familien haben drei 'PRIVAT'-Schilder daran angebracht.")),
                  sign(5, 18, "fallen_notice", ("A notice: PLANET RETRIEVAL - CONTACT THE GILT HOUSE. Below, in another hand: OR ME. CHEAPER. - L.", "Ein Aushang: PLANETENBERGUNG - WENDEN SIE SICH AN DAS HAUS GILT. Darunter, in anderer Schrift: ODER AN MICH. BILLIGER. - L."))],
        "secrets": [secret(0, 4, "max_tonic", "find_fallen_planet_1"), secret(11, 13, "spark_drop", "find_fallen_planet_2"),
                    secret(6, 19, "revival_leaf", "find_fallen_planet_3"), secret(8, 0, "strong_tonic", "find_fallen_planet_4", 2)]})
    # The Brine Catacombs: the old lake's dead in salt, Halloran's barrels beside them; a drowned chapel below.
    top = ["@@@@@==@@@@@",
           "@%%......%%@",
           "@%%.~~~~.%%@",
           "@:..~~~~..:@",
           "@:.S......:@",
           "@@@.@@@@.@@@",
           "@::......::@",
           "_....%%....@",
           "@::..%%..::@",
           "@@.@@..@@.@@",
           "@%%......%%@",
           "@%%.:::..%%@",
           "@S...:::..S@",
           "@@@@@@@@@@@@"]
    chapel = ["@@@@@@@@@@@@",
              "@S.:::::..S@",
              "@:........:@",
              "@:.~~..~~.:@",
              "@..~~..~~..@",
              "@::......::@",
              "@...CCCC...@",
              "@%%......%%@",
              "@%%......%%@",
              "@@@@@==@@@@@"]
    check_rows("brine_catacombs", top)
    check_rows("brine_catacombs@1", chapel)
    world.add_map("brine_catacombs", {
        "name": t("The Brine Catacombs", "Die Solekatakomben"), "region": "halcyra", "biome": "dungeon", "backdrop": "lake",
        "encounters": "brine_catacombs", "rows": top,
        "warps": [warp(0, 7, "mirror_flats", 10, 12, "left"),
                  warp(5, 0, "brine_catacombs@1", 5, 8, "up"), warp(6, 0, "brine_catacombs@1", 6, 8, "up")],
        "npcs": [],
        "signs": [sign(3, 4, "brine_sign", ("THE BRINE CATACOMBS", "DIE SOLEKATAKOMBEN"),
                       ("Under the Mirror Flats the old lake keeps its dead in salt. Halloran keeps his barrels beside them. Both are counted daily.", "Unter der Spiegelebene bewahrt der alte See seine Toten in Salz auf. Halloran lagert seine Fässer daneben. Beide werden täglich gezählt.")),
                  sign(1, 12, "brine_stencil", ("A barrel stencil: PROPERTY OF HALLORAN SALT. A second stencil underneath: AND SO ARE YOU.", "Eine Fassschablone: EIGENTUM VON HALLORAN SALZ. Eine zweite Schablone darunter: UND DU AUCH.")),
                  sign(10, 12, "brine_niche", ("A saint's niche, empty but for a price list. 'Pinch: 5. Bag: 50. Miracle: ask.'", "Eine Heiligennische, leer bis auf eine Preisliste. 'Prise: 5. Beutel: 50. Wunder: auf Anfrage.'"))],
        "secrets": [secret(11, 3, "max_tonic", "find_brine_catacombs_1"), secret(0, 10, "remedy", "find_brine_catacombs_2", 2),
                    secret(6, 13, "revival_leaf", "find_brine_catacombs_3")],
        "floors": [{"name": t("The Brine Catacombs, drowned chapel", "Die Solekatakomben, ertrunkene Kapelle"), "rows": chapel,
                    "warps": [warp(5, 9, "brine_catacombs", 5, 1, "down"), warp(6, 9, "brine_catacombs", 6, 1, "down")],
                    "npcs": [],
                    "signs": [sign(1, 1, "chapel_pews", ("The drowned chapel. Salt has crusted the pews white. Someone has scratched SING LOUDER into the back row.", "Die ertrunkene Kapelle. Salz hat die Bänke weiß überkrustet. Jemand hat SING LAUTER in die hinterste Reihe geritzt.")),
                              sign(10, 1, "chapel_hymns", ("A hymn board. The same hymn number, every week, for twelve years.", "Eine Liedtafel. Dieselbe Liednummer, jede Woche, seit zwölf Jahren."))],
                    "secrets": [secret(11, 4, "spark_drop", "find_brine_catacombs_4"), secret(0, 7, "max_tonic", "find_brine_catacombs_5", 2)]}]})
    # The Gilt Cellars: wine, gold and relatives, under the Sunfall Terraces; the strongroom below.
    cellar = ["WWWWW==WWWWW",
              "Wf|ffffff|fW",
              "WffCCffCCffW",
              "WffffffffffW",
              "Wf|ffffff|fW",
              "WffffffffffW",
              "WWWfWWWWfWWW",
              "WffffffffffW",
              "WffffffffffW",
              "WfSffffffSfW",
              "WffffffffffW",
              "WWWWWDWWWWWW"]
    strong = ["WWWWWWWWWWWW",
              "WfSffffffSfW",
              "WfCCCffCCCfW",
              "WffffffffffW",
              "Wf|ffffff|fW",
              "WffffffffffW",
              "WffffffffffW",
              "WffffffffffW",
              "WffffffffffW",
              "WWWWW==WWWWW"]
    check_rows("gilt_cellars", cellar)
    check_rows("gilt_cellars@1", strong)
    world.add_map("gilt_cellars", {
        "name": t("The Gilt Cellars", "Die Gilt-Keller"), "region": "halcyra", "biome": "dungeon", "backdrop": "ember",
        "rows": cellar,
        "warps": [warp(5, 11, "sunfall_terraces", 10, 13, "left"),
                  warp(5, 0, "gilt_cellars@1", 5, 8, "up"), warp(6, 0, "gilt_cellars@1", 6, 8, "up")],
        "npcs": [],
        "signs": [sign(2, 9, "cellar_sign", ("THE GILT CELLARS", "DIE GILT-KELLER"),
                       ("The Gilt House keeps its wine, its gold and its relatives down here. Not always in that order.", "Das Haus Gilt bewahrt hier unten seinen Wein, sein Gold und seine Verwandten auf. Nicht immer in dieser Reihenfolge.")),
                  sign(9, 9, "cellar_rack", ("A cask rack. Each cask is chalked with a year and a name. Cask forty-one says only: KNOCK.", "Ein Fassregal. Jedes Fass trägt mit Kreide ein Jahr und einen Namen. Auf Fass einundvierzig steht nur: KLOPFEN."))],
        "secrets": [secret(0, 3, "max_tonic", "find_gilt_cellars_1"), secret(11, 8, "power_brew", "find_gilt_cellars_2")],
        "floors": [{"name": t("The Gilt Cellars, strongroom", "Die Gilt-Keller, Tresorraum"), "rows": strong,
                    "warps": [warp(5, 9, "gilt_cellars", 5, 1, "down"), warp(6, 9, "gilt_cellars", 6, 1, "down")],
                    "npcs": [],
                    "signs": [sign(2, 1, "strong_wills", ("The strongroom. Five drawers, one per Gilt child, each with a will inside. Each will leaves everything to the drawer's owner.", "Der Tresorraum. Fünf Schubladen, eine pro Gilt-Kind, in jeder ein Testament. Jedes vermacht alles dem Besitzer der Schublade.")),
                              sign(9, 1, "strong_debts", ("A ledger titled DEBTS OWED TO THE HOUSE. It is very thick. A thinner one beside it, titled DEBTS THE HOUSE OWES, is blank.", "Ein Buch mit dem Titel SCHULDEN GEGENÜBER DEM HAUS. Es ist sehr dick. Ein dünneres daneben, SCHULDEN DES HAUSES, ist leer."))],
                    "secrets": [secret(11, 5, "revival_leaf", "find_gilt_cellars_3"), secret(0, 7, "focus_brew", "find_gilt_cellars_4")]}]})


# --- Data files (python3 tools/art/world/halcyra_side.py) ---------------------------------------
WEIGHT = {"common": 30, "uncommon": 14, "shy": 6}   # inside SpirlingData.WEIGHT_BANDS


def homes(enc, sp):
    """Encounter tables of the two wild places: every Halcyra kind (data region "halcyra", else
    every kind on a Halcyra Warden, sheet slot or Halcyra map team) with no wild home in Halcyra
    gets one. Tide and Umbra kinds live in the Catacombs, the rest at the Fallen Planet."""
    own = [s for s, d in sp.items() if d.get("region") == "halcyra"]
    if not own:
        own = []
        for r in SHEET["routes"]:
            own += [s.get("species") or s["stand_in"] for s in r["slots"]]
        for w in SHEET["wardens"]:
            own += [e.get("species") or e["stand_in"] for e in w["team"]]
        for f in sorted(os.listdir(os.path.join(ROOT, "data", "maps"))):
            m = json.load(open(os.path.join(ROOT, "data", "maps", f), encoding="utf-8"))
            if m.get("region") == "halcyra" and f[:-5] not in GROUP:
                for n in m.get("npcs", []):
                    own += [e["species"] for e in n.get("team", []) if not n.get("id", "").startswith(("q4_", "hs_"))]
    housed = {s["species"] for r in ROUTE for s in enc.get(r, {}).get("spawns", [])}
    need = []
    for s in own:
        if s in sp and s not in housed and s not in need and sp[s].get("rarity") != "ancient":
            need.append(s)
    out = {}
    for mid in WILD:
        lo, hi = NEW[mid]
        wet = mid == "brine_catacombs"
        ks = [s for s in need if wet == bool({"TIDE", "UMBRA"} & set(sp[s]["elements"]))]
        grounds = ["scree", "reeds"] if wet else ["fern", "scree"]
        out[mid] = {"rate": 0.12, "spawns": [{"species": s, "min": lo, "max": hi, "weight": WEIGHT.get(sp[s].get("rarity"), 30),
                                              "ground": grounds[j % 2]}
                                             for j, s in enumerate(ks)]}
    return out


def write_json(path, d):
    with open(os.path.join(ROOT, path), "w", encoding="utf-8") as f:
        f.write(json.dumps(d, indent=1, ensure_ascii=False) + "\n")


def patch_quests(goals):
    """Replaces the q4_* side goals in data/quests.json (one goal per line, like the rest)."""
    path = os.path.join(ROOT, "data", "quests.json")
    rows = open(path, encoding="utf-8").read().split("\n")
    rows = [r for r in rows if '{"id": "q4_' not in r]
    start = rows.index('  "side": [')
    end = next(j for j in range(start + 1, len(rows)) if rows[j].startswith("  ]"))
    body = [r.rstrip(",") for r in rows[start + 1:end]]
    body += ["    " + json.dumps(g, ensure_ascii=False) for g in goals]
    body = [r + "," for r in body[:-1]] + body[-1:]
    rows[start + 1:end] = body
    text_ = "\n".join(rows)
    json.loads(text_)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text_)


def patch_clans():
    """Puts clan "gilt" and the hs_* figures, favors, betrayals and ledger rows into data/clans.json
    (one entry per line, like the rest)."""
    path = os.path.join(ROOT, "data", "clans.json")
    rows = open(path, encoding="utf-8").read().split("\n")
    rows = [r for r in rows if not r.startswith(('  "hs_', '  {"id": "hs_', '  "gilt": {"seat"'))]
    add = {"clans": ['  "gilt": ' + json.dumps({"seat": "gildcrest", "rule": "gold and family"})],
           "figures": ['  "%s": %s' % (k, json.dumps(v, ensure_ascii=False)) for k, v in CLANS["figures"].items()],
           "favors": ['  "%s": %s' % (k, json.dumps(v, ensure_ascii=False)) for k, v in CLANS["favors"].items()],
           "betrayals": ['  "%s": %s' % (k, json.dumps(v, ensure_ascii=False)) for k, v in CLANS["betrayals"].items()],
           "ledger": ["  " + json.dumps(v, ensure_ascii=False) for v in CLANS["ledger"]]}
    for sec, new in add.items():
        start = next(j for j, r in enumerate(rows) if r.startswith(' "%s": ' % sec))
        end = next(j for j in range(start + 1, len(rows)) if rows[j].startswith(" }") or rows[j].startswith(" ]"))
        body = [r.rstrip(",") for r in rows[start + 1:end]] + new
        rows[start + 1:end] = [r + "," for r in body[:-1]] + body[-1:]
    text_ = "\n".join(rows)
    json.loads(text_)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text_)


def main():
    import halcyra  # noqa: F401  (builds this module through the hook)
    sp = species()
    enc = encounters()
    enc.update(homes(enc, sp))
    write_json("data/encounters.json", enc)
    world = common.World()
    MINE.clear()
    halcyra.build(world)
    patch_quests(QUESTS)
    patch_clans()
    sb = json.load(open(os.path.join(ROOT, "data", "story_battles.json"), encoding="utf-8"))
    sb = {k: v for k, v in sb.items() if not k.startswith("hs_")}
    sb.update(BATTLES)
    write_json("data/story_battles.json", sb)
    with open(os.path.join(ROOT, "tools", "i18n", "de_halcyra_side.py"), "w", encoding="utf-8") as f:
        f.write("# German texts for the Halcyra side content (Era IV): goals, duels, Wayfarers, the three new places.\n")
        f.write("# Written by tools/art/world/halcyra_side.py from its t()/ls() pairs: edit there, not here.\n")
        f.write("T = {\n")
        for en in sorted(MINE):
            f.write("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(MINE[en], ensure_ascii=False)))
        f.write("}\n")
    print("halcyra_side: %d goals, %d story duels, %d German texts" % (len(QUESTS), len(BATTLES), len(MINE)))
    sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
    import build_world
    build_world.main([])


if __name__ == "__main__":
    import halcyra_side  # the hook in halcyra.py fills that module, not __main__
    halcyra_side.main()
