"""Veydal (Act I) add-on lines for release 1.3.2: ten more Spirlings for the heather above
Crowcrest, the brooks, the lantern steps and the saltmarsh (owner request "in jeder Region so 10 neue").
Read by tools/art/gen_lines.py (art) and tools/build_lines.py (data, texts)."""

L = dict

REGION = "veydal"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Heathbristle": 356, "Heathbrand": 407, "Tinglash": 424, "Keepwarden": 465, "Saltwhistle": 348, "Tinglewyrm": 514}

LINES = [
    L(id="heathpip", names=["Heathpip", "Heathbristle", "Heathbrand"], elements=["EMBER", "BLOOM"], role="vanguard",
      art=dict(plan="quad", tones=("mid", "light", "dark"), back="spikes", back_n=4, ears="round", ear_tone="dark",
               snout="short", tail="flame", eye="small", mouth="smile", marks="spots", size=-1)),
    L(id="tinglet", names=["Tinglet", "Tinglash", "Tinglewyrm"], elements=["VOLT", "TIDE"], role="striker", trait="static_fur",
      art=dict(plan="serpent", tones=("light", "mid", "dark"), ears="fin", ear_tone="dark", tail="fin", eye="glow",
               mouth="fang", marks="stripes", marks_n=2, crest=2, crest_tone="dark")),
    # Two-stage line
    L(id="keepling", names=["Keepling", "Keepwarden"], elements=["STONE", "LUMEN"], role="bulwark", trait="steady",
      art=dict(plan="shell", tones=("mid", "light", "dark"), extras=("sun", "shellpat"), back="crystals", back_n=2,
               ears="antenna", ear_tone="dark", eye="small", mouth="line")),
    # Singles
    L(id="brackenram", names=["Brackenram"], elements=["BLOOM", "STONE"], role="vanguard",
      art=dict(plan="quad", tones=("mid", "mid", "dark"), horn="curl", horn_tone="dark", back="leaves", back_n=3,
               ears="round", ear_tone="mid", snout="short", eye="sleepy", legs=1, size=1)),
    L(id="saltwhistle", names=["Saltwhistle"], elements=["GALE", "TIDE"], role="weaver",
      art=dict(plan="bird", tones=("light", "light", "dark"), tail="fan", crest=3, crest_tone="dark", extras=("wing",),
               eye="big", marks="stripes")),
]

HABITAT = {
    "heathpip": ("Heather slopes above Crowcrest", "Heidehänge über Crowcrest"),
    "tinglet": ("Brooks after a thunderstorm", "Bäche nach einem Gewitter"),
    "keepling": ("Lantern steps and lake rocks", "Laternenstufen und Seefelsen"),
    "brackenram": ("Bracken thickets in Gloamwood", "Adlerfarndickicht im Gloamwood"),
    "saltwhistle": ("Saltmarsh dikes in the wind", "Salzmarschdeiche im Wind"),
}

# name: (lore EN, origin EN, lore DE, origin DE)
TEXTS = {
    "Heathpip": ("Its quills smoulder like heather in a dry summer. It rolls into a ball when it is embarrassed, which singes the grass.",
                 "Hatched in the ashes of a shepherd's fire that nobody put out.",
                 "Seine Stacheln glimmen wie Heide in einem trockenen Sommer. Ist es verlegen, rollt es sich ein und versengt das Gras.",
                 "Geschlüpft in der Asche eines Hirtenfeuers, das niemand gelöscht hat."),
    "Heathbristle": ("It patrols the heather and stamps out every fire except its own.",
                     "A Heathpip that slept a whole autumn under a juniper bush.",
                     "Es bewacht die Heide und tritt jedes Feuer aus, nur nicht sein eigenes.",
                     "Ein Heathpip, das einen ganzen Herbst unter einem Wacholderbusch schlief."),
    "Heathbrand": ("Shepherds burn old heather so new shoots can grow. They ask a Heathbrand first, and it always says yes.",
                   "Grew up on the hill where the beacon fires were lit in the old wars.",
                   "Hirten brennen alte Heide ab, damit neue Triebe wachsen. Sie fragen vorher ein Heathbrand, und es sagt immer ja.",
                   "Aufgewachsen auf dem Hügel, auf dem in den alten Kriegen die Signalfeuer brannten."),
    "Tinglet": ("Touching it feels like a foot that has gone to sleep. Children dare each other to try.",
                "Fell into a brook with the first drop of a summer storm.",
                "Es zu berühren fühlt sich an wie ein eingeschlafener Fuß. Kinder fordern sich gegenseitig heraus.",
                "Mit dem ersten Tropfen eines Sommergewitters in einen Bach gefallen."),
    "Tinglash": ("It lies still under the water until a fish swims past, then the whole brook hums.",
                 "A Tinglet that was struck by lightning and liked it.",
                 "Es liegt reglos unter Wasser, bis ein Fisch vorbeischwimmt, dann summt der ganze Bach.",
                 "Ein Tinglet, das vom Blitz getroffen wurde und es mochte."),
    "Tinglewyrm": ("Millers along the brooks pay it in bread to keep their wheels turning on calm days.",
                   "Coiled around the old mill wheel for so long that the wheel began to spin by itself.",
                   "Müller an den Bächen bezahlen es mit Brot, damit sich ihre Räder an windstillen Tagen drehen.",
                   "So lange um das alte Mühlrad gewickelt, dass sich das Rad von selbst zu drehen begann."),
    "Keepling": ("It carries a small light in its shell and sits where people tend to trip.",
                 "Found inside a lantern that was left on the steps for a whole winter.",
                 "Es trägt ein kleines Licht in seinem Panzer und sitzt dort, wo Leute gern stolpern.",
                 "Gefunden in einer Laterne, die einen ganzen Winter auf den Stufen stand."),
    "Keepwarden": ("When the lighthouse lamp went out one stormy night, three Keepwardens climbed the tower and lit their shells.",
                   "A Keepling that guided a lost boat home and was never quite the same afterwards.",
                   "Als in einer Sturmnacht die Leuchtturmlampe erlosch, kletterten drei Keepwardens den Turm hinauf und ließen ihre Panzer leuchten.",
                   "Ein Keepling, das ein verirrtes Boot nach Hause lotste und danach nie mehr ganz dasselbe war."),
    "Brackenram": ("It wears a coat of fern on its back and charges anyone who walks off the path. Gardeners consider it an ally.",
                   "Grew out of a boulder that a ram had headbutted every day for a hundred years.",
                   "Es trägt einen Mantel aus Farn auf dem Rücken und rammt jeden, der vom Weg abgeht. Gärtner halten es für einen Verbündeten.",
                   "Aus einem Felsbrocken gewachsen, den ein Widder hundert Jahre lang jeden Tag mit dem Kopf stieß."),
    "Saltwhistle": ("It whistles before a storm. The marsh folk listen to it more than to the weather almanac.",
                    "Hatched from an egg that the wind rolled along the dike for three days.",
                    "Es pfeift vor einem Sturm. Die Marschleute hören mehr darauf als auf den Wetterkalender.",
                    "Aus einem Ei geschlüpft, das der Wind drei Tage lang den Deich entlangrollte."),
}

# Veydal keeps its tables; these kinds are added to them.
ENCOUNTERS_ADD = {
    "kindle_vents": [("Heathpip", "cave")],
    "bellstone_ruins": [("Heathpip", ""), ("Brackenram", "")],
    "sablecove": [("Tinglet", "cave"), ("Keepling", "cave")],
    "mossmere_grotto": [("Tinglet", "cave")],
    "echo_gallery": [("Saltwhistle", "cave")],
}
