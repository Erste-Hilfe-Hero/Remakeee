"""Ashmere (Act III) add-on lines for release 1.3.2: ten more Spirlings for the annealing ovens of the
glassworks, the flooded mine sumps, the peat cuttings and the kilns.
Read by tools/art/gen_lines.py (art) and tools/build_lines.py (data, texts)."""

L = dict

REGION = "ashmere"
BATCH = ", 1.3.2 batch"
NOTE = "Owner request for 1.3.2: ten more Spirlings in every region."
LOGGED = "2026-11-27"
# Stat totals placed with tools/balance/type_sim.py so older kinds stay inside its 40-60 percent gate.
TOTALS_SET = {"Annealix": 385, "Sumpdelver": 450, "Turfhulk": 378, "Flintlancer": 479, "Sumpthane": 455, "Annealord": 392}

LINES = [
    L(id="annealet", names=["Annealet", "Annealix", "Annealord"], elements=["LUMEN", "VOLT"], role="weaver", trait="static_fur",
      art=dict(plan="bug", tones=("light", "mid", "dark"), extras=("wings",), ears="antenna", ear_tone="dark",
               eye="glow", back="crystals", back_n=2, marks="stars")),
    L(id="sumplet", names=["Sumplet", "Sumpdelver", "Sumpthane"], elements=["STONE", "TIDE"], role="bulwark",
      art=dict(plan="quad", tones=("dark", "mid", "light"), ears="round", ear_tone="mid", snout="long",
               extras=("claws",), eye="small", back="plates", back_n=2, size=1, legs=1)),
    # Two-stage lines
    L(id="turfkin", names=["Turfkin", "Turfhulk"], elements=["BLOOM", "STONE"], role="kindler",
      art=dict(plan="plant", tones=("mid", "light", "dark"), extras=("leafarms", "cap"), eye="sleepy",
               mouth="smile", marks="spots")),
    L(id="flintkit", names=["Flintkit", "Flintlancer"], elements=["STONE", "EMBER"], role="striker", trait="glimmer_skin",
      art=dict(plan="quad", tones=("light", "mid", "dark"), horn="single", horn_tone="dark", ears="pointed",
               ear_tone="dark", tail="whip", snout="short", eye="slit", marks="stripes", size=-1)),
]

HABITAT = {
    "annealet": ("Annealing ovens of the glassworks", "Kühlöfen der Glashütten"),
    "sumplet": ("Flooded sumps of the old mines", "Geflutete Sümpfe der alten Minen"),
    "turfkin": ("Peat cuttings on the moor", "Torfstiche im Moor"),
    "flintkit": ("Flint seams beside the kilns", "Feuersteinadern neben den Brennöfen"),
}

TEXTS = {
    "Annealet": ("It rests on cooling glass and hums. Glass it has slept on never cracks.",
                 "Flew out of a glass bubble that a blower blew too thin.",
                 "Es ruht auf abkühlendem Glas und summt. Glas, auf dem es geschlafen hat, springt nie.",
                 "Aus einer Glasblase geflogen, die ein Bläser zu dünn geblasen hatte."),
    "Annealix": ("Its wings are panes of glass with a spark trapped between them. It cannot see out of them, which it finds restful.",
                 "An Annealet that spent a night in the cooling oven by mistake.",
                 "Seine Flügel sind Glasscheiben mit einem gefangenen Funken dazwischen. Es kann nicht hindurchsehen, was es erholsam findet.",
                 "Ein Annealet, das aus Versehen eine Nacht im Kühlofen verbrachte."),
    "Annealord": ("The master blowers hang their best work near its nest. It fixes every flaw, then asks to be thanked.",
                  "Grew inside the great window of the glassworks hall and stepped out when it was finished.",
                  "Die Meisterbläser hängen ihre besten Stücke in die Nähe seines Nests. Es behebt jeden Fehler und will dann gelobt werden.",
                  "Wuchs im großen Fenster der Glashüttenhalle heran und trat heraus, als es fertig war."),
    "Sumplet": ("It drinks the water out of flooded tunnels and spits it out again somewhere less useful.",
                "Washed out of a mine when the pumps stopped for a holiday.",
                "Es trinkt das Wasser aus gefluteten Stollen und spuckt es woanders wieder aus, wo es weniger nützt.",
                "Aus einer Mine gespült, als die Pumpen an einem Feiertag stillstanden."),
    "Sumpdelver": ("Miners follow it into old shafts. Where it stops digging, there is always ore, or water, or both.",
                   "A Sumplet that dug through to the next mine and refused to say how.",
                   "Bergleute folgen ihm in alte Schächte. Wo es aufhört zu graben, gibt es immer Erz oder Wasser oder beides.",
                   "Ein Sumplet, das bis in die nächste Mine durchgrub und sich weigerte zu verraten, wie."),
    "Sumpthane": ("It rules the drowned levels of the mine. Nobody has seen the bottom, but everyone has heard it breathing.",
                  "Sat in the deepest sump for so long that the mine grew around it.",
                  "Es herrscht über die ertrunkenen Sohlen der Mine. Niemand hat den Grund gesehen, aber alle haben es atmen hören.",
                  "Saß so lange im tiefsten Sumpf, dass die Mine um es herum wuchs."),
    "Turfkin": ("Peat cutters find it asleep in the bog, rolled up like a brick of turf. Burning it by mistake is very rude.",
                "Sprouted from a peat brick that was stacked too close to a damp wall.",
                "Torfstecher finden es schlafend im Moor, zusammengerollt wie ein Torfziegel. Es aus Versehen zu verbrennen, ist sehr unhöflich.",
                "Aus einem Torfziegel gesprossen, der zu nah an einer feuchten Wand gestapelt war."),
    "Turfhulk": ("It walks slowly and leaves a trail of new moss. The moor is a little greener wherever it has been.",
                 "A Turfkin that was planted on a grave by a grieving cutter and grew out of grief.",
                 "Es geht langsam und hinterlässt eine Spur aus frischem Moos. Das Moor ist überall ein wenig grüner, wo es war.",
                 "Ein Turfkin, das ein trauernder Torfstecher auf ein Grab setzte und das aus Trauer wuchs."),
    "Flintkit": ("Its horn throws sparks when it bumps into things, which is often.",
                 "Struck out of a flint by a potter who was trying to light his kiln.",
                 "Sein Horn schlägt Funken, wenn es irgendwo anstößt, und das ist oft.",
                 "Von einem Töpfer aus einem Feuerstein geschlagen, der seinen Brennofen anzünden wollte."),
    "Flintlancer": ("It charges the kiln doors to light the fires. The potters pay it in coal and never stand behind it.",
                    "A Flintkit that broke its horn on an anvil and grew a sharper one.",
                    "Es rennt gegen die Ofentüren, um die Feuer zu zünden. Die Töpfer bezahlen es mit Kohle und stehen nie hinter ihm.",
                    "Ein Flintkit, das sich sein Horn an einem Amboss brach und ein schärferes nachwachsen ließ."),
}

ENCOUNTERS_ADD = {
    "glass_rift": [("Annealet", "scree")],
    "saltglass": [("Annealet", "scree"), ("Turfkin", "fern")],
    "soot_vaults": [("Sumplet", "scree")],
    "wide_rift_far": [("Sumplet", "scree")],
    "clinker_heath": [("Turfkin", "fern"), ("Flintkit", "scree")],
    "kiln_rift": [("Flintkit", "scree")],
}
