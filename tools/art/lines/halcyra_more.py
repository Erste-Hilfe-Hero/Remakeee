"""Halcyra (Era IV post-game region, data/region4.json) add-on lines for release 1.3.2: ten more
Spirlings for the high gardens, the coin pools, the cornices of the white terraces and the storm
ridges. Era IV art from tools/art/gen_era4.py --lines halcyra_more (96 px, breath frame).
Data and texts: tools/build_lines.py halcyra_more. Route slots follow the tables (SLOTS)."""

L = dict

REGION = "halcyra"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Mintmarker": 420}
ERA = 4
ACT = "Era IV post-game"
ART_TOOL = "tools/art/gen_era4.py"
RINGS = (80, 88, 84)
SLOTS = "data/region4.json"

LINES = [
    L(id="culmlet", names=["Culmlet", "Culmbough", "Culmarch"], elements=["ZENITH", "BLOOM"], role="kindler",
      art=dict(plan="plant", tones=("light", "mid", "dark"), extras=("petals", "leafarms", "sun"), eye="big",
               mouth="smile", crest=3, crest_tone="dark")),
    L(id="mintlet", names=["Mintlet", "Mintmarker", "Mintmajesty"], elements=["GILT", "TIDE"], role="weaver",
      art=dict(plan="fish", tones=("light", "light", "dark"), tail="fan", ears="fin", ear_tone="dark", eye="big",
               marks="rings", mouth="smile")),
    # Two-stage lines
    L(id="cornicet", names=["Cornicet", "Corniceroc"], elements=["STONE", "GALE"], role="vanguard",
      art=dict(plan="bird", tones=("light", "mid", "dark"), crest=2, crest_tone="dark", tail="plume",
               extras=("wing",), eye="small")),
    L(id="fulmenkit", names=["Fulmenkit", "Fulmenhart"], elements=["VOLT", "ZENITH"], role="striker",
      art=dict(plan="quad", tones=("mid", "light", "dark"), horn="antler", horn_tone="light", ears="pointed",
               ear_tone="dark", tail="fluff", legs=1, neck=True, snout="short", eye="glow", extras=("halo",))),
]

HABITAT = {
    "culmlet": ("Hanging gardens at the top of the terraces", "Hängende Gärten oben auf den Terrassen"),
    "mintlet": ("Wishing pools full of old coins", "Wunschbrunnen voller alter Münzen"),
    "cornicet": ("Cornices of the white terraces", "Gesimse der weißen Terrassen"),
    "fulmenkit": ("Storm ridges above the orrery", "Gewittergrate über dem Orrery"),
}

TEXTS = {
    "Culmlet": ("It always turns its face to the highest point of the sky, even indoors, even at night.",
                "Sprouted from a seed that fell out of a cloud onto the top terrace.",
                "Es dreht sein Gesicht immer zum höchsten Punkt des Himmels, auch drinnen, auch nachts.",
                "Aus einem Samen gesprossen, der aus einer Wolke auf die oberste Terrasse fiel."),
    "Culmbough": ("Gardeners grow vines along its arms. By midsummer it is a whole arbour and very proud of it.",
                  "A Culmlet that climbed the tallest wall in Halcyra to be closer to noon.",
                  "Gärtner ziehen Ranken an seinen Armen entlang. Im Hochsommer ist es eine ganze Laube und sehr stolz darauf.",
                  "Ein Culmlet, das die höchste Mauer von Halcyra erklomm, um dem Mittag näher zu sein."),
    "Culmarch": ("At noon its crown opens and the whole garden goes quiet. The bees say it is rude to buzz.",
                 "Grew on the roof of the highest house until its roots held the house together.",
                 "Mittags öffnet sich seine Krone, und der ganze Garten verstummt. Die Bienen sagen, Summen wäre unhöflich.",
                 "Wuchs auf dem Dach des höchsten Hauses, bis seine Wurzeln das Haus zusammenhielten."),
    "Mintlet": ("It swims among the coins in the wishing pools and polishes them with its fins. It keeps the shiny ones.",
                "Hatched from a coin that someone wished on very hard.",
                "Es schwimmt zwischen den Münzen in den Wunschbrunnen und poliert sie mit seinen Flossen. Die glänzenden behält es.",
                "Aus einer Münze geschlüpft, auf die jemand sehr fest gewünscht hatte."),
    "Mintmarker": ("Its scales carry the stamp of a coin that was never minted. Collectors pay a fortune for a shed one.",
                   "A Mintlet that swallowed the mint master's stamp and would not give it back.",
                   "Seine Schuppen tragen die Prägung einer Münze, die nie geprägt wurde. Sammler zahlen ein Vermögen für eine abgeworfene.",
                   "Ein Mintlet, das den Prägestempel des Münzmeisters verschluckte und ihn nicht zurückgab."),
    "Mintmajesty": ("It lies at the bottom of the great fountain and grants no wishes at all. People throw coins anyway.",
                    "Ate every wish ever thrown into the great fountain of Gildcrest.",
                    "Es liegt am Grund des großen Brunnens und erfüllt überhaupt keine Wünsche. Die Leute werfen trotzdem Münzen.",
                    "Fraß jeden Wunsch, der je in den großen Brunnen von Gildcrest geworfen wurde."),
    "Cornicet": ("It perches on cornices and pretends to be carved stone. Pigeons have stopped falling for it.",
                 "Chipped off a terrace cornice in a storm and flew away before it hit the ground.",
                 "Es hockt auf Gesimsen und tut, als wäre es aus Stein gemeißelt. Die Tauben fallen nicht mehr darauf herein.",
                 "In einem Sturm von einem Terrassengesims abgeplatzt und weggeflogen, bevor es aufschlug."),
    "Corniceroc": ("It drops from the highest cornice like a stone and opens its wings a hand's breadth from the ground.",
                   "A Cornicet that sat on the same cornice for a hundred years and wore a dent in it.",
                   "Es fällt wie ein Stein vom höchsten Gesims und öffnet die Flügel eine Handbreit über dem Boden.",
                   "Ein Cornicet, das hundert Jahre auf demselben Gesims saß und eine Mulde hineinsaß."),
    "Fulmenkit": ("Its antlers crackle before a storm. The orrery keepers check it instead of the barometer.",
                  "Born on the ridge where lightning strikes the same rock every summer.",
                  "Sein Geweih knistert vor einem Gewitter. Die Orrery-Wärter schauen lieber auf es als auf das Barometer.",
                  "Auf dem Grat geboren, wo der Blitz jeden Sommer in denselben Felsen einschlägt."),
    "Fulmenhart": ("It stands on the highest ridge in every storm and catches the lightning in its antlers. Nobody knows why.",
                   "A Fulmenkit that was struck at the exact moment the sun stood highest.",
                   "Es steht bei jedem Gewitter auf dem höchsten Grat und fängt den Blitz mit seinem Geweih. Niemand weiß, warum.",
                   "Ein Fulmenkit, das genau in dem Moment getroffen wurde, als die Sonne am höchsten stand."),
}

ENCOUNTERS_ADD = {
    "cloudshadow_meadow": [("Culmlet", "fern")],
    "sunfall_terraces": [("Culmlet", "fern")],
    "mirror_flats": [("Mintlet", "water"), ("Fulmenkit", "scree")],
    "long_stair": [("Cornicet", "scree")],
    "lantern_span": [("Cornicet", "scree")],
    "orrery_ridge": [("Fulmenkit", "scree")],
}
