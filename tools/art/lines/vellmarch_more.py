"""Vellmarch (Era II post-game region, data/region2.json) add-on lines for release 1.3.2: ten more
Spirlings for the dock cranes, the cheating fishermen of Hookwick, the rumour mills and the counting
houses. Era II art from tools/art/gen_era2.py vellmarch_more (same spec keys as vellmarch.py).
Read by tools/build_lines.py (data, texts)."""

L = dict

REGION = "vellmarch"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Tallywarden": 387}
ERA = 2
ACT = "Era II post-game"
ART_TOOL = "tools/art/gen_era2.py"
RINGS = (24, 40, 32)
TUNE_BAND = {0: (0.43, 0.48), 1: (0.48, 0.53), "default": (0.46, 0.54)}

LINES = [
    L(id="hoistling", names=["Hoistling", "Hoistheron", "Hoistgrand"], elements=["RUST", "GALE"], role="striker",
      art=dict(plan="bird", tones=("mid", "light", "mid"), tail="fan", extras=("wing", "rivets"), crest=2,
               crest_tone="A:mid", eye="small", hue=6)),
    L(id="fibbet", names=["Fibbet", "Fibwhisker", "Fibgrandee"], elements=["MASK", "TIDE"], role="weaver",
      art=dict(plan="fish", tones=("mid", "light", "light"), tail="fan", extras=("fins", "mask"), eye="big",
               mouth="smile", marks="spots", hue=-8)),
    # Two-stage lines
    L(id="murmlet", names=["Murmlet", "Murmuron"], elements=["ECHO", "UMBRA"], role="kindler",
      art=dict(plan="quad", tones=("mid", "light", "dark"), ears="big", ear_tone="A:mid", tail="whip",
               snout="short", eye="glow", extras=("hood",), size=-1)),
    L(id="tallykit", names=["Tallykit", "Tallywarden"], elements=["INK", "RUST"], role="bulwark",
      art=dict(plan="biped", tones=("mid", "mid", "light"), extras=("arms", "collar", "rivets"), eye="small",
               mouth="line", horn="twin", horn_tone="A:light")),
]

HABITAT = {
    "hoistling": ("Dock cranes above the quay", "Hafenkräne über dem Kai"),
    "fibbet": ("Hookwick fishing grounds", "Fischgründe von Hookwick"),
    "murmlet": ("Behind the rumour stalls", "Hinter den Gerüchteständen"),
    "tallykit": ("Counting houses and ledger rooms", "Kontore und Hauptbuchkammern"),
}

TEXTS = {
    "Hoistling": ("It perches on crane hooks and rides them up and down all day. The dock workers pretend not to see it.",
                  "Hatched in a nest of rusty chains at the top of the oldest crane.",
                  "Es sitzt auf Kranhaken und fährt den ganzen Tag damit auf und ab. Die Hafenarbeiter tun so, als sähen sie es nicht.",
                  "In einem Nest aus rostigen Ketten oben auf dem ältesten Kran geschlüpft."),
    "Hoistheron": ("It stands on one leg on the crane arm and spears fish out of the harbour. It also spears hats.",
                   "A Hoistling that was hoisted aboard a ship by mistake and came back on the next tide.",
                   "Es steht auf einem Bein auf dem Kranarm und spießt Fische aus dem Hafen. Hüte spießt es auch.",
                   "Ein Hoistling, das aus Versehen an Bord eines Schiffes gehievt wurde und mit der nächsten Flut zurückkam."),
    "Hoistgrand": ("The harbour master lets it decide which ship unloads first. Bribes are paid in fish.",
                   "Took over the biggest crane after its operator retired and has not come down since.",
                   "Der Hafenmeister lässt es entscheiden, welches Schiff zuerst entladen wird. Bestechung wird in Fisch bezahlt.",
                   "Übernahm den größten Kran, als sein Kranführer in Rente ging, und ist seitdem nicht mehr heruntergekommen."),
    "Fibbet": ("It swims into fishing nets on purpose and pretends to be a much bigger fish.",
               "Grew out of a fishing story told so often that it came true.",
               "Es schwimmt absichtlich in Fischernetze und tut so, als wäre es ein viel größerer Fisch.",
               "Aus einer Anglergeschichte gewachsen, die so oft erzählt wurde, dass sie wahr wurde."),
    "Fibwhisker": ("Its whiskers point the way to the best fishing spots. They point the wrong way on purpose.",
                   "A Fibbet that won the Hookwick fishing contest by entering itself.",
                   "Seine Barteln zeigen den Weg zu den besten Fischgründen. Sie zeigen absichtlich in die falsche Richtung.",
                   "Ein Fibbet, das den Angelwettbewerb von Hookwick gewann, indem es sich selbst anmeldete."),
    "Fibgrandee": ("Every fisherman in Hookwick claims to have caught it once. It has never been caught.",
                   "The sum of every lie ever told at the bar of the Hookwick inn.",
                   "Jeder Fischer in Hookwick behauptet, es schon einmal gefangen zu haben. Gefangen wurde es nie.",
                   "Die Summe aller Lügen, die je am Tresen der Hookwicker Schenke erzählt wurden."),
    "Murmlet": ("It repeats every whisper it hears, but a little wrong. Half the rumours in Vellmarch start with it.",
                "Born in the gap between two market stalls where secrets get traded.",
                "Es wiederholt jedes Flüstern, das es hört, aber ein bisschen falsch. Die Hälfte aller Gerüchte in Vellmarch beginnt bei ihm.",
                "Geboren in der Lücke zwischen zwei Marktständen, wo mit Geheimnissen gehandelt wird."),
    "Murmuron": ("When it hums, everyone in the street feels that they are being talked about. They usually are.",
                 "A Murmlet that heard one secret too many and grew heavy with it.",
                 "Wenn es summt, hat jeder in der Straße das Gefühl, über ihn werde geredet. Meistens stimmt das.",
                 "Ein Murmlet, das ein Geheimnis zu viel hörte und davon schwer wurde."),
    "Tallykit": ("It counts everything: coins, steps, breaths. It writes the totals on its arms in ink.",
                 "Climbed out of a ledger that was closed with a wet pen inside.",
                 "Es zählt alles: Münzen, Schritte, Atemzüge. Die Summen schreibt es mit Tinte auf seine Arme.",
                 "Aus einem Hauptbuch geklettert, das mit einer nassen Feder darin zugeklappt wurde."),
    "Tallywarden": ("The counting houses trust it with their keys. It has never stolen a coin, only the right to know.",
                    "A Tallykit that found a mistake in the city's books and was hired on the spot.",
                    "Die Kontore vertrauen ihm ihre Schlüssel an. Es hat nie eine Münze gestohlen, nur das Recht, alles zu wissen.",
                    "Ein Tallykit, das einen Fehler in den Büchern der Stadt fand und auf der Stelle eingestellt wurde."),
}

ENCOUNTERS_ADD = {
    "tollchain_causeway": [("Hoistling", "fern"), ("Fibbet", "reeds")],
    "smelters_drift": [("Hoistling", "scree"), ("Tallykit", "fern")],
    "weeping_locks": [("Fibbet", "reeds")],
    "rookery_cut": [("Murmlet", "scree")],
    "bellrope_marsh": [("Murmlet", "fern")],
    "tithe_road": [("Tallykit", "scree")],
}
