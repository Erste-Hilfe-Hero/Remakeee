"""Quillmarch (Era III post-game region, data/region3.json) add-on lines for release 1.3.2: ten more
Spirlings for the winter fog of the moor, the zinc baths, the type cases and the acid fumes.
The art is Era III (64 x 64) from tools/art/gen_era3.py --lines quillmarch_more.
Read by tools/build_lines.py (data, texts)."""

L = dict

REGION = "quillmarch"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Brumeshade": 348, "Brumarch": 515}
ERA = 3
ACT = "Era III post-game"
ART_TOOL = "tools/art/gen_era3.py"
RINGS = (24, 40, 32)

LINES = [
    L(id="brumelet", names=["Brumelet", "Brumeshade", "Brumarch"], elements=["FROST", "UMBRA"], role="striker", trait="slick",
      art=dict(plan="quad", tones=("light", "light", "dark"), ears="big", ear_tone="dark", tail="fluff", eye="slit",
               snout="short", marks="stars", size=-1)),
    L(id="zinclet", names=["Zinclet", "Zincrawler", "Zincolossus"], elements=["ACID", "VOLT"], role="vanguard",
      art=dict(plan="bug", tones=("mid", "light", "dark"), horn="twin", horn_tone="dark", ears="antenna",
               ear_tone="dark", extras=("claws",), claw_tone="light", eye="twin", marks="band")),
    # Two-stage lines
    L(id="serifkit", names=["Serifkit", "Serifane"], elements=["STONE", "LUMEN"], role="weaver",
      art=dict(plan="quad", tones=("light", "mid", "dark"), ears="pointed", ear_tone="dark", tail="fluff",
               snout="long", eye="big", marks="stripes")),
    L(id="tangbeak", names=["Tangbeak", "Tangharrier"], elements=["ACID", "GALE"], role="striker",
      art=dict(plan="bird", tones=("mid", "light", "dark"), tail="fan", crest=3, crest_tone="dark",
               extras=("wing",), eye="slit")),
]

HABITAT = {
    "brumelet": ("Winter fog on the Hoarfrost Moor", "Winternebel im Hoarfrost-Moor"),
    "zinclet": ("Zinc baths of Mordant Row", "Zinkbäder der Mordant Row"),
    "serifkit": ("Type cases in the print houses", "Setzkästen in den Druckereien"),
    "tangbeak": ("Acid fumes over the etching works", "Säuredämpfe über den Ätzwerken"),
}

TEXTS = {
    "Brumelet": ("It hides in the fog and nips at ankles. You only see it when it laughs, and its breath freezes in the air.",
                 "Born from the first fog of winter, which rolled over the moor and forgot to lift.",
                 "Es versteckt sich im Nebel und zwickt in Knöchel. Man sieht es nur, wenn es lacht, weil sein Atem in der Luft gefriert.",
                 "Aus dem ersten Winternebel geboren, der über das Moor zog und vergaß, sich zu heben."),
    "Brumeshade": ("Wayfarers lost in the fog sometimes follow a pair of eyes home. Sometimes they do not get home.",
                   "A Brumelet that spent a night in the shadow of a gallows stone.",
                   "Wanderer, die sich im Nebel verirren, folgen manchmal einem Augenpaar nach Hause. Manchmal kommen sie nicht an.",
                   "Ein Brumelet, das eine Nacht im Schatten eines Galgensteins verbrachte."),
    "Brumarch": ("When it walks across the moor, the fog follows it like a cloak. Even the frost keeps quiet.",
                 "Gathered every fog bank of the moor into itself on the longest night.",
                 "Wenn es über das Moor geht, folgt ihm der Nebel wie ein Mantel. Selbst der Frost schweigt.",
                 "Sammelte in der längsten Nacht jede Nebelbank des Moors in sich."),
    "Zinclet": ("It bathes in the zinc tanks and comes out tingling. Touching two of them at once is a mistake you make once.",
                "Crawled out of a battery jar that an engraver left in the rain.",
                "Es badet in den Zinkbecken und kommt prickelnd wieder heraus. Zwei auf einmal anzufassen ist ein Fehler, den man nur einmal macht.",
                "Aus einem Batterieglas gekrochen, das ein Kupferstecher im Regen stehen ließ."),
    "Zincrawler": ("It walks the gutters of Mordant Row and eats spilled acid. The cobbles behind it shine like new.",
                   "A Zinclet that fell into a plating bath and came out with a shell of metal.",
                   "Es läuft die Rinnsteine der Mordant Row ab und frisst verschüttete Säure. Das Pflaster hinter ihm glänzt wie neu.",
                   "Ein Zinclet, das in ein Galvanikbad fiel und mit einem Panzer aus Metall wieder herauskam."),
    "Zincolossus": ("The etching works run their presses on its current. Nobody asks what happens if it walks away.",
                    "Lay in the great plating tank for a whole year while the works paid it in copper.",
                    "Die Ätzwerke betreiben ihre Pressen mit seinem Strom. Niemand fragt, was passiert, wenn es weggeht.",
                    "Lag ein ganzes Jahr im großen Galvanikbecken, während die Werke es in Kupfer bezahlten."),
    "Serifkit": ("Its ears end in tiny serifs. Typesetters keep one to find the letters they have dropped.",
                 "Jumped out of a type case when the printer sneezed.",
                 "Seine Ohren enden in winzigen Serifen. Schriftsetzer halten eines, um heruntergefallene Lettern zu finden.",
                 "Aus einem Setzkasten gesprungen, als der Drucker niesen musste."),
    "Serifane": ("It reads every page that comes off the press and glows at every mistake. The forgers hate it.",
                 "A Serifkit that slept in a lamp-lit print room until the light soaked into its fur.",
                 "Es liest jede Seite, die aus der Presse kommt, und leuchtet bei jedem Fehler auf. Die Fälscher hassen es.",
                 "Ein Serifkit, das in einem lampenhellen Druckraum schlief, bis das Licht in sein Fell zog."),
    "Tangbeak": ("It rides the acid fumes above the chimneys and smells of vinegar. Its call makes your teeth hurt.",
                 "Hatched in a nest built on a chimney of the etching works.",
                 "Es reitet auf den Säuredämpfen über den Schornsteinen und riecht nach Essig. Sein Ruf tut in den Zähnen weh.",
                 "In einem Nest auf einem Schornstein der Ätzwerke geschlüpft."),
    "Tangharrier": ("It dives through the fumes at copper roofs and leaves green streaks where its claws scrape.",
                    "A Tangbeak that flew through the thickest cloud of the works and came out sharper.",
                    "Es stößt durch die Dämpfe auf Kupferdächer herab und hinterlässt grüne Streifen, wo seine Krallen kratzen.",
                    "Ein Tangbeak, das durch die dichteste Wolke der Werke flog und schärfer wieder herauskam."),
}

ENCOUNTERS_ADD = {
    # Every Quillmarch kind can be met on a road (tests/unit/test_quillmarch_world.gd), later stages too.
    "hoarfrost_moor": [("Brumelet", "fern"), ("Brumeshade", "fern")],
    "rimeglass_pass": [("Brumelet", "scree"), ("Brumarch", "scree")],
    "mordant_steps": [("Zinclet", "scree"), ("Tangbeak", "scree"), ("Zincrawler", "scree")],
    "stamp_road": [("Zinclet", "scree"), ("Serifkit", "reeds"), ("Zincolossus", "scree")],
    "drypoint_lane": [("Serifkit", "fern")],
    "gravers_causeway": [("Serifane", "scree")],
    "smudge_marsh": [("Tangbeak", "reeds"), ("Tangharrier", "reeds")],
}
