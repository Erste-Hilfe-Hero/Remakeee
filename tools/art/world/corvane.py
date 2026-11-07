"""Corvane, the island across the lake (region "corvane"). The ferry opens with the story flag
ferry_corvane_open (area 4); the crossing itself is the story's scene ferry_crossing, which
lands on corvane_quay at (6, 22). The Act II maps beyond the quay are in corvane_act2.py,
the Act III maps of Ashmere (region "ashmere") in ashmere.py; all three build as group "corvane"."""
import ashmere
import corvane_act2
import townsfolk
from common import check_rows, lines, npc, secret, tr, warp

GROUP = ["corvane_quay"] + corvane_act2.GROUP + ashmere.GROUP


def build(world):
    corvane_quay(world)
    corvane_act2.build(world)
    ashmere.build(world)
    for mid in ("corvane_quay", "madderby", "cinderfold", "ashmere_station"):
        townsfolk.apply(world, mid)


# --- Corvane Quay: the arrival harbour, 12 x 24, rest spring and a closed road north (1288) ---
def corvane_quay(world):
    mid = "corvane_quay"
    rows = ["TTTTT__TTTTT",
            "T*..S__..*.T",
            "T....__....T",
            "TRRR.__.RRRT",
            "THDH.__.HDHT",
            "T....__....T",
            "T.________.T",
            "T.o.._.._..T",
            "T...._.._..T",
            "T,,..__..,,T",
            "T,,,.__.,,,T",
            "TRRR.__.%%%T",
            "THDH.__.%%%T",
            "T....__...ST",
            "T*.._____.*T",
            "T...__..@..T",
            "T#..__....#T",
            "T...__.....T",
            "T....__....T",
            "~~~~.++.~~~~",
            "~~~~~++~~~~~",
            "~~~~~++~~~~~",
            "~~~++++++S~~",
            "~~~~~~~~~~~~"]
    world.add_text(mid, {
        "sign": lines(("CORVANE QUAY", "CORVANE-KAI"), ("Corvane Quay, 23 folk.", "Corvane-Kai, 23 Leute."), ("Harbour of Corvane.", "Hafen von Corvane."),
                      ("North: Madderby Road", "Norden: Straße nach Madderby")),
        "road": lines(("MADDERBY ROAD", "STRASSE NACH MADDERBY"),
                      ("Closed after the storm. Fallen trees, washed-out bridges.", "Nach dem Sturm gesperrt. Umgestürzte Bäume, weggespülte Brücken."),
                      ("Ask at the quay when it opens again.", "Frag am Kai, wann sie wieder offen ist.")),
        "tender": {"lines": lines(("Harbour Tender Mave: Salt spring, fresh off the lake. Let your team rest after the crossing.", "Hafenpflegerin Mave: Salzquelle, frisch vom See. Lass dein Team nach der Überfahrt ausruhen.")),
                   "action": "heal"},
        "dockhand": lines(("Dockhand Tib: Veydal folk! First boat across since the storm. Mind the wet planks.", "Hafenarbeiter Tib: Leute aus Veydal! Das erste Boot seit dem Sturm. Pass auf die nassen Planken auf.")),
        "ferry": {"lines": lines(("QUAY BOATS", "KAIBOOTE"), ("Back to Brindlewick, any tide.", "Zurück nach Brindlewick, bei jeder Flut.")),
                  "choices": [{"text": tr("Cross to Brindlewick", "Nach Brindlewick übersetzen"), "action": "warp brindlewick 8 18 right"},
                              {"text": tr("Stay in Corvane", "In Corvane bleiben")}]},
    })
    m = {"name": tr("Corvane Quay", "Corvane-Kai"), "region": "corvane", "biome": "town", "backdrop": "lake", "outdoor": True,
         "heal_point": [2, 8], "rows": rows,
         "warps": [warp(5, 0, "madderby", 5, 20, "up"), warp(6, 0, "madderby", 6, 20, "up")],
         "npcs": [npc("tender", 1, 7, "right", mid + "/tender", "elder"),
                  npc("dockhand", 7, 19, "left", mid + "/dockhand", "villager")],
         "signs": [{"x": 10, "y": 13, "dialogue": mid + "/sign"}, {"x": 4, "y": 1, "dialogue": mid + "/road"},
                   {"x": 9, "y": 22, "dialogue": mid + "/ferry"}],
         # The road north to Madderby stays shut until area 4 sets the flag (scene corvane_arrival).
         "blocks": [{"x": 5, "y": 1, "open_flag": "madderby_road_open", "closed": "#"},
                    {"x": 6, "y": 1, "open_flag": "madderby_road_open", "closed": "#"}],
         "secrets": [secret(0, 9, "tonic", "find_quay_west", 2), secret(11, 15, "remedy", "find_quay_east"),
                     secret(1, 14, "dry_towel", "find_quay_flowers")],
         # Story spots (area 4): Juna the courier and Mirela's page 7 behind the rock.
         "spots": {"juna": [7, 13], "page_7": [8, 15]}}
    check_rows(mid, rows)
    world.add_map(mid, m)
