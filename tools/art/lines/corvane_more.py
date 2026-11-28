"""Corvane (Act II) add-on lines for release 1.3.2: ten more Spirlings for the flax fields, the dye
vats of Madderby, the canal locks, the still ponds and the threshing floors.
Read by tools/art/gen_lines.py (art) and tools/build_lines.py (data, texts)."""

L = dict

REGION = "corvane"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Simmerhound": 390, "Simmerbaron": 452, "Flaxreel": 383, "Stookhulk": 344}

LINES = [
    L(id="flaxlet", names=["Flaxlet", "Flaxreel", "Flaxdowager"], elements=["BLOOM", "GALE"], role="weaver",
      art=dict(plan="bug", tones=("light", "light", "dark"), extras=("wings",), ears="antenna", ear_tone="dark",
               eye="big", marks="stripes", marks_n=2, size=-1)),
    L(id="simmerkit", names=["Simmerkit", "Simmerhound", "Simmerbaron"], elements=["EMBER", "TIDE"], role="kindler",
      art=dict(plan="quad", tones=("mid", "light", "dark"), ears="pointed", ear_tone="dark", tail="flame",
               snout="long", eye="slit", mouth="fang", marks="rings")),
    # Two-stage line
    L(id="lockgill", names=["Lockgill", "Lockreeve"], elements=["STONE", "TIDE"], role="bulwark",
      art=dict(plan="fish", tones=("dark", "mid", "light"), back="plates", back_n=2, tail="fan", eye="small",
               mouth="line")),
    # Singles
    L(id="pondchime", names=["Pondchime"], elements=["ECHO", "TIDE"], role="weaver",
      art=dict(plan="spirit", tones=("light", "light", "dark"), extras=("halo",), tail="ray", eye="glow",
               mouth="smile", marks="rings")),
    L(id="stookhulk", names=["Stookhulk"], elements=["BLOOM", "STONE"], role="bulwark",
      art=dict(plan="biped", tones=("light", "mid", "dark"), pillar=True, extras=("arms",), crest=3,
               crest_tone="dark", eye="small", mouth="line", marks="band")),
]

HABITAT = {
    "flaxlet": ("Flax fields along the dikes", "Flachsfelder an den Deichen"),
    "simmerkit": ("Steaming dye vats of Madderby", "Dampfende Färbebottiche von Madderby"),
    "lockgill": ("Canal locks and their gates", "Kanalschleusen und ihre Tore"),
    "pondchime": ("Still ponds behind the bell towers", "Stille Teiche hinter den Glockentürmen"),
    "stookhulk": ("Harvest fields and threshing floors", "Erntefelder und Dreschböden"),
}

TEXTS = {
    "Flaxlet": ("It spins a thread so fine that weavers lose it in their own fingers.",
                "Crawled out of a bale of flax that was left out in the dew.",
                "Es spinnt einen Faden, so fein, dass die Weber ihn in den eigenen Fingern verlieren.",
                "Aus einem Flachsballen gekrochen, der im Tau liegen blieb."),
    "Flaxreel": ("It winds its thread around fence posts until the whole field is fenced in. Then it forgets the way out.",
                 "A Flaxlet that spent a summer in a weaver's attic and learned the loom by watching.",
                 "Es wickelt seinen Faden um Zaunpfähle, bis das ganze Feld eingezäunt ist. Dann vergisst es den Weg hinaus.",
                 "Ein Flaxlet, das einen Sommer auf dem Dachboden eines Webers verbrachte und den Webstuhl vom Zusehen lernte."),
    "Flaxdowager": ("It sits in the middle of its web like an old aunt at a wedding and judges every thread.",
                    "Wove itself a shawl from a whole year of harvest, then refused to take it off.",
                    "Es sitzt mitten in seinem Netz wie eine alte Tante auf einer Hochzeit und beurteilt jeden Faden.",
                    "Webte sich einen Schal aus einer ganzen Jahresernte und weigerte sich, ihn je wieder abzulegen."),
    "Simmerkit": ("It sleeps on the rim of the dye vats. Its fur comes out a different colour every week.",
                  "Fell into a madder vat as an egg and hatched bright red.",
                  "Es schläft am Rand der Färbebottiche. Sein Fell hat jede Woche eine andere Farbe.",
                  "Fiel als Ei in einen Krappbottich und schlüpfte knallrot."),
    "Simmerhound": ("Dyers keep one by the vats. It growls when the water is too cold and steams when it is too hot.",
                    "A Simmerkit that guarded the dye works through a flood and kept the fires lit.",
                    "Färber halten eines bei den Bottichen. Es knurrt, wenn das Wasser zu kalt ist, und dampft, wenn es zu heiß ist.",
                    "Ein Simmerkit, das die Färberei durch eine Flut bewachte und die Feuer am Brennen hielt."),
    "Simmerbaron": ("It owns no land and no title, but every dyer in Madderby bows when it walks past.",
                    "Drank from every vat in Madderby in a single night and became every colour at once.",
                    "Es besitzt weder Land noch Titel, aber jeder Färber in Madderby verbeugt sich, wenn es vorbeigeht.",
                    "Trank in einer einzigen Nacht aus jedem Bottich in Madderby und wurde alle Farben auf einmal."),
    "Lockgill": ("It wedges itself into the gaps of lock gates. The lock keepers never know if it is helping or the reason for the leak.",
                 "Hatched in the mud at the bottom of a lock that was drained for repairs.",
                 "Es klemmt sich in die Spalten der Schleusentore. Die Schleusenwärter wissen nie, ob es hilft oder der Grund für das Leck ist.",
                 "Im Schlamm am Grund einer Schleuse geschlüpft, die für eine Reparatur leergepumpt wurde."),
    "Lockreeve": ("No boat passes its lock without paying. It accepts bread, buttons and, once, a whole cart wheel.",
                  "A Lockgill that held a lock gate shut through a spring flood and saved a village.",
                  "Kein Boot passiert seine Schleuse, ohne zu zahlen. Es nimmt Brot, Knöpfe und einmal ein ganzes Wagenrad.",
                  "Ein Lockgill, das ein Schleusentor durch ein Frühjahrshochwasser hielt und ein Dorf rettete."),
    "Pondchime": ("When the wind is still, it rings like a bell under the water. The ripples spread in perfect circles.",
                  "The echo of a bell that fell into a pond and was never pulled out.",
                  "Ist der Wind still, läutet es unter Wasser wie eine Glocke. Die Wellen breiten sich in perfekten Kreisen aus.",
                  "Das Echo einer Glocke, die in einen Teich fiel und nie herausgezogen wurde."),
    "Stookhulk": ("It stands in the fields after the harvest and looks exactly like a stack of sheaves until it sneezes.",
                  "The last sheaf of a harvest, tied too tight by a farmer who was in a hurry.",
                  "Es steht nach der Ernte auf den Feldern und sieht genau aus wie ein Garbenstapel, bis es niest.",
                  "Die letzte Garbe einer Ernte, zu fest gebunden von einem Bauern, der es eilig hatte."),
}

ENCOUNTERS_ADD = {
    "dyeworks": [("Flaxlet", ""), ("Simmerkit", ""), ("Lockgill", ""), ("Pondchime", ""), ("Stookhulk", "")],
}
