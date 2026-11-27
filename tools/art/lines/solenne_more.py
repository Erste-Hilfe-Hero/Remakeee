"""Solenne (Act IV) add-on lines for release 1.3.2: ten more Spirlings for the glare of the salt flats,
the caravan roads, the old cisterns, the observatory nights and the grain fields in the wind.
Read by tools/art/gen_lines.py (art) and tools/build_lines.py (data, texts)."""

L = dict

REGION = "solenne"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Glaremonarch": 520, "Cisternox": 383, "Haulbeetle": 448, "Noctolabe": 410, "Grainspout": 407, "Haulbastion": 466}

LINES = [
    L(id="glarelet", names=["Glarelet", "Glarelisk", "Glaremonarch"], elements=["LUMEN", "EMBER"], role="striker",
      art=dict(plan="quad", tones=("light", "mid", "dark"), long=2, tail="whip", back="spikes", back_n=3,
               snout="long", eye="slit", mouth="fang", extras=("sun",))),
    L(id="haulbug", names=["Haulbug", "Haulbeetle", "Haulbastion"], elements=["STONE", "GALE"], role="bulwark",
      art=dict(plan="bug", tones=("mid", "mid", "dark"), horn="single", horn_tone="dark", ears="antenna",
               ear_tone="dark", extras=("hindleg",), eye="small", back="plates", back_n=2, size=1)),
    # Two-stage line
    L(id="cistlet", names=["Cistlet", "Cisternox"], elements=["TIDE", "UMBRA"], role="vanguard",
      art=dict(plan="serpent", tones=("light", "mid", "dark"), crest=4, crest_tone="dark", ears="fin",
               ear_tone="dark", eye="big", mouth="smile", tail="fin")),
    # Singles
    L(id="noctolabe", names=["Noctolabe"], elements=["UMBRA", "LUMEN"], role="weaver",
      art=dict(plan="spirit", tones=("dark", "mid", "light"), extras=("halo", "ball"), eye="glow", mouth="line",
               marks="stars")),
    L(id="grainspout", names=["Grainspout"], elements=["GALE", "STONE"], role="striker",
      art=dict(plan="spirit", tones=("light", "mid", "dark"), tail="ray", extras=("arms",), eye="slit",
               mouth="smile", marks="band", size=-1)),
]

HABITAT = {
    "glarelet": ("Salt flats in the glare of noon", "Salzebenen im grellen Mittagslicht"),
    "haulbug": ("Caravan roads and their waystations", "Karawanenstraßen und ihre Raststationen"),
    "cistlet": ("Old cisterns under the towns", "Alte Zisternen unter den Städten"),
    "noctolabe": ("Observatory roofs on clear nights", "Sternwartendächer in klaren Nächten"),
    "grainspout": ("Millet fields when the wind turns", "Hirsefelder, wenn der Wind dreht"),
}

TEXTS = {
    "Glarelet": ("Its scales throw the sun back into your eyes. It thinks this is how you say hello.",
                 "Hatched on a mirror that a caravan dropped on the salt.",
                 "Seine Schuppen werfen die Sonne zurück in deine Augen. Es glaubt, so sagt man Hallo.",
                 "Auf einem Spiegel geschlüpft, den eine Karawane auf dem Salz verloren hatte."),
    "Glarelisk": ("Travellers cross the flats with their eyes shut when one is about. Most of them arrive somewhere.",
                  "A Glarelet that stared at the sun for a whole day out of stubbornness.",
                  "Reisende überqueren die Ebenen mit geschlossenen Augen, wenn eines in der Nähe ist. Die meisten kommen irgendwo an.",
                  "Ein Glarelet, das aus reinem Trotz einen ganzen Tag lang in die Sonne starrte."),
    "Glaremonarch": ("At noon it is the brightest thing on the plateau. At night it sulks in a hole and nobody can find it.",
                     "Grew from the burning glass of the old sun tower after it fell into the salt.",
                     "Mittags ist es das Hellste auf der Hochebene. Nachts schmollt es in einem Loch, und niemand findet es.",
                     "Aus dem Brennglas des alten Sonnenturms gewachsen, nachdem es ins Salz gefallen war."),
    "Haulbug": ("It pushes balls of dried dung along the caravan roads and sells them as fuel at the next well.",
                "Fell off a caravan cart and decided to keep going on foot.",
                "Es schiebt Kugeln aus getrocknetem Dung die Karawanenstraßen entlang und verkauft sie am nächsten Brunnen als Brennstoff.",
                "Fiel von einem Karawanenwagen und beschloss, zu Fuß weiterzugehen."),
    "Haulbeetle": ("Caravans hire it to pull carts out of the sand. It works for water and complains in a low hum.",
                   "A Haulbug that pulled a stuck cart for a mile and never let go of the rope.",
                   "Karawanen heuern es an, um Wagen aus dem Sand zu ziehen. Es arbeitet für Wasser und beschwert sich mit tiefem Summen.",
                   "Ein Haulbug, das einen festgefahrenen Wagen eine Meile weit zog und das Seil nie losließ."),
    "Haulbastion": ("A whole waystation is built on its back. It moves twice a year, and the innkeeper moves with it.",
                    "Lay down to rest on the caravan road and woke up with a roof on its shell.",
                    "Auf seinem Rücken steht eine ganze Raststation. Es zieht zweimal im Jahr um, und der Wirt zieht mit.",
                    "Legte sich auf der Karawanenstraße zur Ruhe und wachte mit einem Dach auf dem Panzer auf."),
    "Cistlet": ("It lives in the dark water under the towns and smiles at every bucket that comes down.",
                "Dropped into a cistern by a girl who wanted to keep it secret.",
                "Es lebt im dunklen Wasser unter den Städten und lächelt jeden Eimer an, der herunterkommt.",
                "Von einem Mädchen in eine Zisterne fallen gelassen, das es geheim halten wollte."),
    "Cisternox": ("Whole towns drink from its cistern. It keeps the water clean and keeps count of every bucket.",
                  "A Cistlet that grew too big to leave through the well shaft.",
                  "Ganze Städte trinken aus seiner Zisterne. Es hält das Wasser sauber und zählt jeden Eimer.",
                  "Ein Cistlet, das zu groß wurde, um durch den Brunnenschacht hinauszukommen."),
    "Noctolabe": ("It turns slowly on the observatory roof and points at the stars nobody has named yet.",
                  "Came loose from an astronomer's brass instrument on the longest night of the year.",
                  "Es dreht sich langsam auf dem Dach der Sternwarte und zeigt auf die Sterne, die noch keinen Namen haben.",
                  "Löste sich in der längsten Nacht des Jahres vom Messinginstrument einer Sterndeuterin."),
    "Grainspout": ("It spins through the millet and threshes it in one go. The farmers sweep up behind it and say thank you.",
                   "A dust devil that ate a whole field of millet and got stuck that way.",
                   "Es wirbelt durch die Hirse und drischt sie in einem Zug. Die Bauern fegen hinter ihm auf und bedanken sich.",
                   "Eine Windhose, die ein ganzes Hirsefeld fraß und so stecken blieb."),
}

ENCOUNTERS_ADD = {
    "sun_rift": [("Glarelet", "scree")],
    "glasswind_flats": [("Glarelet", "scree"), ("Grainspout", "fern")],
    "tower_rift": [("Haulbug", "scree"), ("Grainspout", "scree")],
    "mirage_kiln": [("Haulbug", "")],
    "veil_cistern": [("Cistlet", "scree"), ("Noctolabe", "scree")],
    "oasis_rift": [("Cistlet", "fern")],
}
