"""Quillmarch (Era III post-game region, data/region3.json) lines: engravers' quarters, acid
baths, frost moors and the forgers' print houses. The art is Era III (64 x 64, many tones) from
tools/art/gen_era3.py (data/eras.json "era3": starting_set and first_batch), not gen_lines.py.
Read by tools/build_lines.py (data, texts)."""

L = dict  # one line

ERA = 3
ACT = "Era III post-game"
ART_TOOL = "tools/art/gen_era3.py"
# Unfold rings (3-stage first, 3-stage second, 2-stage): low enough to reach under the level cap.
RINGS = (24, 40, 32)

LINES = [
    L(id="vesk", names=["Vesk", "Veskara", "Veskarion"], elements=["GALE"], role="striker", cover="VOLT",
      art=dict(plan="quad")),
    L(id="silt", names=["Siltby", "Siltarra", "Siltaroth"], elements=["TIDE", "GALE"], role="bulwark",
      art=dict(plan="serpent")),
    L(id="cindr", names=["Cindrik", "Cindrel", "Cindravax"], elements=["EMBER", "BLOOM"], role="kindler",
      art=dict(plan="bird")),
    L(id="nib", names=["Nibbet", "Nibquill", "Nibravure"], elements=["UMBRA", "BLOOM"], role="vanguard",
      art=dict(plan="quad")),
    L(id="filig", names=["Filigrin", "Filigrace", "Filigravure"], elements=["LUMEN", "GALE"], role="weaver",
      art=dict(plan="bug")),
]

HABITAT = {
    "vesk": ("Windy rooftops of the print quarter", "Windige Dächer des Druckerviertels"),
    "silt": ("Silted canals under the engravers' bridges", "Verschlammte Kanäle unter den Stecherbrücken"),
    "cindr": ("Chimneys of the acid works", "Schornsteine der Säurewerke"),
    "nib": ("Mossy ink cellars, under copper plates", "Moosige Tintenkeller, unter Kupferplatten"),
    "filig": ("Lamp-lit print rooms at night", "Lampenhelle Druckstuben bei Nacht"),
}

# name: (lore EN, origin EN, lore DE, origin DE)
TEXTS = {
    "Vesk": ("It steals proof sheets off the drying lines and brings them back when nobody is looking. Mostly.",
             "Born in a gust that blew a forger's whole print run into the river.",
             "Es klaut Probedrucke von den Trockenleinen und bringt sie zurück, wenn keiner hinsieht. Meistens.",
             "Geboren in einer Böe, die die ganze Auflage eines Fälschers in den Fluss blies."),
    "Veskara": ("Its tails sweep chalk lines off the street, so no one can prove where it has been.",
                "A Vesk that outran three print houses and the watch in one night.",
                "Seine Schweife fegen Kreidestriche von der Straße, damit keiner beweisen kann, wo es war.",
                "Ein Vesk, das in einer Nacht drei Druckhäusern und der Wache davonlief."),
    "Veskarion": ("Three tails, three alibis. The print houses pay it to be seen somewhere else.",
                  "The engravers say it was the wind that signed the first false contract.",
                  "Drei Schweife, drei Alibis. Die Druckhäuser bezahlen es dafür, woanders gesehen zu werden.",
                  "Die Stecher sagen, es war der Wind, der den ersten falschen Vertrag unterschrieb."),
    "Siltby": ("It filters the canal mud and spits out lost rings. It keeps the gold ones.",
               "Hatched in the silt where an engraver dropped his best plate.",
               "Es filtert den Kanalschlamm und spuckt verlorene Ringe aus. Die goldenen behält es.",
               "Geschlüpft im Schlamm, in den ein Stecher seine beste Platte fallen ließ."),
    "Siltarra": ("Its fins rise like a row of knives when a boat comes too close to its lock.",
                 "A Siltby that grew fat on the coins thrown off the bridges for luck.",
                 "Seine Flossen stehen wie eine Reihe Messer, wenn ein Boot seiner Schleuse zu nahe kommt.",
                 "Ein Siltby, das von den Glücksmünzen fett wurde, die man von den Brücken wirft."),
    "Siltaroth": ("It sleeps under the oldest bridge. Some say the bridge is the part of it that shows.",
                  "The canal guild swears it was here before the canals were dug.",
                  "Es schläft unter der ältesten Brücke. Manche sagen, die Brücke ist der Teil von ihm, der heraussieht.",
                  "Die Kanalgilde schwört, es war schon da, bevor die Kanäle gegraben wurden."),
    "Cindrik": ("It warms the acid vats with its belly and asks for nothing. That is what worries people.",
                "Hatched from an ember that fell into a bath of etching acid and did not go out.",
                "Es wärmt die Säurebottiche mit seinem Bauch und will nichts dafür. Genau das macht den Leuten Sorgen.",
                "Aus einer Glut geschlüpft, die in ein Ätzbad fiel und nicht erlosch."),
    "Cindrel": ("Its crest flares gold when it lies. It has learned to keep its head down.",
                "A Cindrik that kept a chimney burning through a strike and was paid by both sides.",
                "Sein Kamm glüht golden, wenn es lügt. Es hat gelernt, den Kopf unten zu halten.",
                "Ein Cindrik, das einen Schornstein durch einen Streik am Brennen hielt und von beiden Seiten bezahlt wurde."),
    "Cindravax": ("One wingbeat dries a whole print run. Forgers bid for its company like it is a seat in court.",
                  "The acid works were built around the nest of the first one, and it never forgave them.",
                  "Ein Flügelschlag trocknet eine ganze Auflage. Fälscher bieten um seine Gesellschaft wie um einen Sitz im Gericht.",
                  "Die Säurewerke wurden um das Nest des ersten gebaut, und es hat ihnen nie verziehen."),
    "Nibbet": ("Every quill on its back is a pen nib. It signs things in its sleep, never its own name.",
               "Curled up from a box of nibs a forger buried when the watch knocked.",
               "Jeder Stachel auf seinem Rücken ist eine Schreibfeder. Es unterschreibt im Schlaf, nie mit eigenem Namen.",
               "Aus einer Schachtel Federn gerollt, die ein Fälscher vergrub, als die Wache klopfte."),
    "Nibquill": ("It scratches perfect copies of any signature into copper. Banks hire it, then lock it up.",
                 "A Nibbet that copied the mayor's hand so well the mayor asked it for advice.",
                 "Es ritzt jede Unterschrift perfekt in Kupfer. Banken stellen es ein und sperren es dann ein.",
                 "Ein Nibbet, das die Handschrift des Bürgermeisters so gut kopierte, dass der Bürgermeister es um Rat fragte."),
    "Nibravure": ("Its quills hold enough ink to rewrite a city's records overnight. It has done it twice.",
                  "The print houses agree on nothing, except that nobody owns a Nibravure. It owns you.",
                  "Seine Stacheln fassen genug Tinte, um über Nacht die Akten einer Stadt neu zu schreiben. Es hat es zweimal getan.",
                  "Die Druckhäuser sind sich in nichts einig, außer darin, dass keiner eine Nibravure besitzt. Sie besitzt dich."),
    "Filigrin": ("It lands on fresh prints and leaves lace patterns that no forger can copy. Forgers hate it.",
                 "Hatched under a reading lamp in a room where someone checked banknotes all night.",
                 "Es landet auf frischen Drucken und hinterlässt Spitzenmuster, die kein Fälscher kopieren kann. Fälscher hassen es.",
                 "Geschlüpft unter einer Leselampe in einem Raum, in dem jemand die ganze Nacht Geldscheine prüfte."),
    "Filigrace": ("The spots on its wings look like eyes. Witnesses swear it was watching. Courts accept that now.",
                  "A Filigrin that slept inside a ledger for a year and woke up knowing every debt.",
                  "Die Flecken auf seinen Flügeln sehen aus wie Augen. Zeugen schwören, es hat zugesehen. Gerichte lassen das inzwischen gelten.",
                  "Ein Filigrin, das ein Jahr in einem Kassenbuch schlief und mit dem Wissen um jede Schuld aufwachte."),
    "Filigravure": ("Its wings are etched finer than any banknote. It sells its own dust to the highest bidder.",
                    "The old engravers say it flew out of the first plate ever bitten by acid.",
                    "Seine Flügel sind feiner geätzt als jeder Geldschein. Es verkauft seinen eigenen Staub an den Meistbietenden.",
                    "Die alten Stecher sagen, es flog aus der ersten Platte, die je von Säure angefressen wurde."),
}
