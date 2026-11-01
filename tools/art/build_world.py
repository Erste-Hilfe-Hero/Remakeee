"""One-off builder for the Act I world ("The Hush of Veydal"). Writes data/maps/*.json and
data/dialogue/*.json. Kept in the repo so the layout can be re-generated and reviewed;
after this, edit the JSON directly.
Map legend: see TilesetFactory.LEGEND.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
MAPS = os.path.join(ROOT, "data", "maps")
DIA = os.path.join(ROOT, "data", "dialogue")


def warp(x, y, to, tx, ty, facing):
    return {"x": x, "y": y, "to": to, "tx": tx, "ty": ty, "facing": facing}


def npc(id_, x, y, facing, dialogue, sprite, **kw):
    d = {"id": id_, "x": x, "y": y, "facing": facing, "dialogue": dialogue, "sprite": sprite}
    d.update(kw)
    return d


def team(*pairs):
    return [{"species": s, "level": l} for s, l in pairs]


WORLD = {}
TEXT = {}

# --- Brindlewick Lighthouse (the player's home with grandfather Aldo) --------------------
WORLD["lighthouse"] = {
    "name": "Brindlewick Lighthouse",
    "rows": ["WWWWWWWWWW",
             "WfCCffff=W",
             "WffffffffW",
             "WffffffffW",
             "WffffffffW",
             "WCfffffffW",
             "WffffffffW",
             "WWWWDWWWWW"],
    "warps": [warp(4, 7, "brindlewick", 3, 12, "down")],
    "npcs": [npc("aldo", 2, 3, "right", "lighthouse/aldo", "elder")],
    "signs": [{"x": 8, "y": 1, "dialogue": "lighthouse/stairs"}],
}
TEXT["lighthouse"] = {
    "aldo": {
        "lines": ["Aldo: You slept through the whole storm? The sky split open over the lake last night.",
                  "Aldo: That little one hasn't left your side since it came in from the rain.",
                  "Aldo: Every Rift that opens spreads the Hush. Spirlings near it go quiet and forget their Tamers.",
                  "Aldo: The cartographers will need fresh maps. Take this, and go see Kestra at the map house."],
        "after_flag": {"flag": "aldo_gift",
                       "lines": ["Aldo: The lamp stays lit for you. If your team is worn out, the Rest Spring is just up the pier."]},
        "action": "give_item tonic 2",
        "flag": "aldo_gift",
        "once": True,
    },
    "stairs": ["The spiral stairs lead up to the lamp room.", "Aldo keeps it lit every night."],
}

# --- Brindlewick: fishing village on the lake, the hub of Veydal --------------------------
WORLD["brindlewick"] = {
    "name": "Brindlewick",
    "rows": ["TTTTT__TTTTT",
             "T*...__...*T",
             "TRRR.__.RRRT",
             "TRRR.__.RRRT",
             "THDH.__.HDHT",
             "T._.____._.T",
             "T._________ ".replace(" ", "_"),
             "T.S.._.....T",
             "T*...__..,,T",
             "T..L.__.,,,T",
             "T@.|.__....T",
             "T@.D.__..*.T",
             "T..___.....T",
             "~~~~.++.~~~~",
             "~~~~~++~~~~~",
             "~~%~~++~~%%~",
             "~~%%~++~~~%~",
             "~~~~~++~~~~~",
             "~~~++++++S~~",
             "~~~~~~~~~~~~"],
    "warps": [warp(5, 0, "fernstair", 5, 24, "up"), warp(6, 0, "fernstair", 6, 24, "up"),
              warp(11, 6, "saltmarsh", 1, 12, "right"),
              warp(3, 11, "lighthouse", 4, 6, "up"),
              warp(2, 4, "map_house", 4, 6, "up"),
              warp(9, 4, "rest_spring", 4, 6, "up")],
    "npcs": [npc("fisher", 8, 18, "left", "brindlewick/fisher", "villager"),
             npc("child", 8, 9, "left", "brindlewick/child", "villager"),
             npc("kestra_dock", 4, 18, "down", "brindlewick/kestra_dock", "ranger", show_flag="pc_unlocked"),
             npc("ines", 10, 12, "left", "brindlewick/ines", "warden", show_flag="kestra_dock_talk"),
             npc("crier", 4, 8, "down", "brindlewick/crier", "villager"),
             npc("wynn", 7, 12, "down", "brindlewick/wynn", "ranger")],
    "signs": [{"x": 2, "y": 7, "dialogue": "brindlewick/sign"}, {"x": 9, "y": 18, "dialogue": "brindlewick/ferry"},
              {"x": 2, "y": 16, "dialogue": "brindlewick/islet"}],
    # Tamer Gear: hook across the narrow water between the pier and the reed islet, both ways.
    "gear_spots": [{"from": [5, 16], "x": 4, "y": 16, "gear": "grapple_line", "to": [3, 16]},
                   {"from": [3, 16], "x": 4, "y": 16, "gear": "grapple_line", "to": [5, 16]}],
}
TEXT["brindlewick"] = {
    "sign": ["BRINDLEWICK", "Lake village of Veydal.", "North: Fernstair   East: Saltmarsh"],
    "ferry": ["FERRY TO CORVANE", "No crossings while the lake is restless."],
    "fisher": {"lines": ["The fish stopped jumping the night the Rift opened.", "Even the reeds sound quieter. That's the Hush, they say.",
                         "Something glints on the reed islet west of the pier. Too far to wade, though.",
                         "Say, have you seen a Kelpup? The pups used to bark at my boat. Bring one by, would you?"],
               "action": "quest_show fisher Kelpup max_tonic 2",
               "after_flag": {"flag": "q_fisher_done", "lines": ["That Kelpup of yours barked at my boat. Just like old times."]}},
    "islet": {"lines": ["Tangled in the reeds: a Revival Leaf!"], "action": "give_item revival_leaf 1",
              "flag": "islet_find", "once": True,
              "after_flag": {"flag": "islet_find", "lines": ["Only reeds now, rustling in the wind."]}},
    "child": ["My Puddlet won't answer when I call it anymore.", "Grandpa Aldo says a Tamer with a strong bond can wake it up again."],
    "crier": {"lines": ["Crier: Hear ye! Veydal keeps its festivals, storm or no storm."], "action": "season"},
    "wynn": {"lines": ["Wynn: Every week the lake throws up three new echoes. Same ones for every Tamer in Veydal.",
                       "Wynn: Beat all three and I'll pay out. Once a week, mind."],
             "action": "weekly"},
    "ines": {"lines": ["Ines: The lighthouse keeps old Rift echoes. I can wake them for you.",
                       "Ines: Five Tamers' echoes in a row, no rest in between. They grow with you."],
             "action": "gauntlet"},
    "kestra_dock": {
        "lines": ["Kestra: Two Rifts mended. The valley is calmer... and smaller.",
                  "Kestra: There's a third one, up north past the crest. Bigger than both.",
                  "Kestra: I still think something lives on the other side. When the ferry runs again, we find out together."],
        "flag": "kestra_dock_talk",
    },
}

# --- Map house (Kestra, fellow cartographer) -----------------------------------------------
WORLD["map_house"] = {
    "name": "Map House",
    "rows": ["WWWWWWWWWW",
             "WCCCffCCCW",
             "WffffffffW",
             "WffCCCCffW",
             "WffffffffW",
             "WffffffffW",
             "WffffffffW",
             "WWWWDWWWWW"],
    "warps": [warp(4, 7, "brindlewick", 2, 5, "down")],
    "npcs": [npc("kestra", 5, 2, "down", "map_house/kestra", "ranger")],
    "signs": [{"x": 1, "y": 1, "dialogue": "map_house/maps"}],
}
TEXT["map_house"] = {
    "kestra": {
        "lines": ["Kestra: You're Aldo's apprentice? Good. Half the old maps are wrong since the storm.",
                  "Kestra: Two Rifts opened: one in the Cinder hollow past Thornridge, one under the Saltmarsh.",
                  "Kestra: Everyone wants them closed. I'm not so sure. New Spirlings came through that tear.",
                  "Kestra: Go and see for yourself. Fernstair goes north, Saltmarsh east. Pick either."],
        "after_flag": {"flag": "kestra_spar",
                       "lines": ["Kestra: Still mending Rifts? Fine. Just look closely at what comes through before you do."]},
        "flag": "met_kestra",
    },
    "maps": ["Old maps of Veydal, crossed out and redrawn in three colours of ink."],
}

# --- Rest Spring (healing and storage) -------------------------------------------------------
WORLD["rest_spring"] = {
    "name": "Rest Spring",
    "rows": ["WWWWWWWWWW",
             "WfffoofffW",
             "WffffffffW",
             "WffCCCCffW",
             "WffffffffW",
             "WffffffffW",
             "WffffffffW",
             "WWWWDWWWWW"],
    "heal_point": [4, 5],
    "warps": [warp(4, 7, "brindlewick", 9, 5, "down")],
    "npcs": [npc("keeper", 4, 2, "down", "rest_spring/keeper", "elder"),
             npc("archivist", 7, 4, "left", "rest_spring/archivist", "villager")],
    "signs": [],
}
TEXT["rest_spring"] = {
    "keeper": {"lines": ["Welcome to the Rest Spring.", "Let your team soak for a moment..."], "action": "heal"},
    "archivist": {"lines": ["I keep the Spirling storage box.", "Want to swap who travels with you?"], "action": "storage"},
}

# --- Fernstair: switchbacks up the slope north of the lake -----------------------------------
WORLD["fernstair"] = {
    "name": "Fernstair",
    "encounters": "fernstair",
    "rows": ["TTTT__TTTTTT",
             "T,,,__,,,..T",
             "T,,,____...T",
             "T^^^^^^^=^^T",
             "T*..,,,,_..T",
             "T.S.,,,,_.@T",
             "T________..T",
             "T_^^^^^^^^^T",
             "T=..,,,,,..T",
             "T_..,,,,,.@T",
             "T_________.T",
             "T^^^^^^^^=^T",
             "T.,,,,....:T",
             "T.,,,,..._:T",
             "T@..______:T",
             "T..._,,,,::T",
             "T^^^=^^^^^^T",
             "T,,,_,,,,..T",
             "T,,,_,,,,..T",
             "T...____...T",
             "TT.....__..T",
             "T.....,__,.T",
             "T*....,__,,T",
             "T.....S__..T",
             "TTT..___..TT",
             "TTTTT__TTTTT"],
    "warps": [warp(5, 25, "brindlewick", 5, 1, "down"), warp(6, 25, "brindlewick", 6, 1, "down"),
              warp(4, 0, "crowcrest", 5, 22, "up"), warp(5, 0, "crowcrest", 6, 22, "up")],
    "npcs": [npc("gatherer", 9, 18, "left", "fernstair/gatherer", "villager"),
             npc("hiker", 3, 9, "right", "fernstair/hiker", "villager")],
    "signs": [{"x": 6, "y": 23, "dialogue": "fernstair/sign"}, {"x": 2, "y": 5, "dialogue": "fernstair/sign_top"},
              {"x": 10, "y": 5, "dialogue": "fernstair/rock_find"}],
    "gear_spots": [{"from": [8, 6], "x": 8, "y": 7, "gear": "climbing_pick", "to": [8, 8]},
                   {"from": [8, 8], "x": 8, "y": 7, "gear": "climbing_pick", "to": [8, 6]}],
}
TEXT["fernstair"] = {
    "sign": ["FERNSTAIR", "Up: Crowcrest and Thornridge", "Down: Brindlewick"],
    "sign_top": ["Wild Spirlings nest in the ferns.", "Walk through them and one may step out."],
    "rock_find": {"lines": ["Wedged behind the rock: two Kin Charms!"], "action": "give_item kin_charm 2",
                  "flag": "fern_rock_find", "once": True,
                  "after_flag": {"flag": "fern_rock_find", "lines": ["Just moss behind the rock now."]}},
    "hiker": {"lines": ["Your partner gets Energy back every turn.", "If it runs dry, let it rest a turn. No shame in that!",
                        "I'd love to see a Breezel up close. They tumble past too fast on the ridge."],
              "action": "quest_show hiker Breezel swift_feather 1",
              "after_flag": {"flag": "q_hiker_done", "lines": ["Your Breezel nearly blew my hat off. Worth it!"]}},
    "gatherer": {
        "lines": ["You look new at this. Take these!"],
        "after_flag": {"flag": "fern_gift",
                       "lines": ["Bonding works best when a Spirling is worn down.", "Tap with the pulse and it may trust you."]},
        "action": "give_item kin_charm 2",
        "flag": "fern_gift",
        "once": True,
    },
}

# --- Crowcrest: a scree-covered ridge with a mountain tarn ---------------------------------
WORLD["crowcrest"] = {
    "name": "Crowcrest",
    "encounters": "crowcrest",
    "rows": ["@@@@@__@@@@@",
             "@::..__..::@",
             "@:...__...:@",
             "@^^^^==^^^^@",
             "@...____...@",
             "@.::_..:::.@",
             "@.::_..:::@@",
             "@...____...@",
             "@@^^^^^^=^^@",
             "@~~~...:_..@",
             "@~~~%..:_..@",
             "@~~~++++_..@",
             "@~~~%..:_..@",
             "@......::..@",
             "@^^^=^^^^D^@",
             "@:::_:::...@",
             "@:::_::....@",
             "@...______.@",
             "@@........@@",
             "@.::....::.@",
             "@.::.S..::.@",
             "@....__....@",
             "@@...__...@@",
             "@@@@@__@@@@@"],
    "warps": [warp(5, 23, "fernstair", 4, 1, "down"), warp(6, 23, "fernstair", 5, 1, "down"),
              warp(5, 0, "thornridge", 5, 18, "up"), warp(6, 0, "thornridge", 6, 18, "up"),
              warp(9, 14, "murk_hollow", 5, 11, "up")],
    "npcs": [
        npc("kestra", 7, 17, "left", "crowcrest/kestra", "ranger", trainer="Cartographer Kestra",
            beaten_flag="kestra_spar", money=400, intro="crowcrest/kestra_intro",
            defeat="crowcrest/kestra_defeat",
            team=team(("Zippit", 7), ("Breezel", 8), ("Shalebat", 9))),
        npc("lio", 2, 4, "right", "crowcrest/lio", "villager", trainer="Wanderer Lio",
            intro="crowcrest/lio_intro", defeat="crowcrest/lio_defeat",
            team=team(("Breezel", 7), ("Zippit", 8))),
        npc("bram", 9, 9, "left", "crowcrest/bram", "villager", trainer="Hiker Bram",
            intro="crowcrest/bram_intro", defeat="crowcrest/bram_defeat",
            team=team(("Shalebat", 7), ("Shalebat", 8))),
    ],
    "signs": [{"x": 5, "y": 20, "dialogue": "crowcrest/sign"}],
    # Tamer Gear: climb the lower cliff (both ways, on foot).
    "gear_spots": [{"from": [8, 13], "x": 8, "y": 14, "gear": "climbing_pick", "to": [8, 15]},
                   {"from": [8, 15], "x": 8, "y": 14, "gear": "climbing_pick", "to": [8, 13]}],
}
TEXT["crowcrest"] = {
    "sign": ["CROWCREST", "Mind the loose stones.", "Up: Thornridge   Down: Fernstair", "East cliff door: the old Murk Hollow mine"],
    "kestra": {"lines": ["Kestra: You fight like you draw maps: careful, then all at once.",
                         "Kestra: Take this Climbing Pick. Hook it into a low cliff and climb, up or down. Your own hands, your own feet."],
               "action": "give_item climbing_pick 1", "flag": "got_pick", "once": True,
               "after_flag": {"flag": "got_pick",
                              "lines": ["Kestra: Go on ahead. I want to sketch the tarn before it freezes."]}},
    "kestra_intro": ["Kestra: You're really going to close the Cinder Rift?",
                     "Kestra: Then show me you understand what you'd be shutting out. Talk is cheap up here!"],
    "kestra_defeat": ["Kestra: ...Alright. Your Spirlings trust you. That counts for something.",
                      "Kestra: Mend it if you must. But draw what you see in there first."],
    "lio": ["Lio: Gale Spirlings ride the wind, but they can't carry you. Nobody rides a Spirling here."],
    "lio_intro": ["Lio: You want a practice duel? Sure!"],
    "lio_defeat": ["Lio: Wow, okay. You earned that."],
    "bram": ["Bram: Stone types shrug off hits. Try Tide or Bloom moves on them."],
    "bram_intro": ["Bram: My Shalebats are tougher than these hills. Want to test them?"],
    "bram_defeat": ["Bram: Crumbled like gravel..."],
}

# --- Thornridge: a village in a gorge, on two levels ------------------------------------------
WORLD["thornridge"] = {
    "name": "Thornridge",
    "heal_point": [9, 4],
    "rows": ["^^^^^^^^^^^^",
             "^^D^^^^^^^^^",
             "^.._.~~~...^",
             "^.._.~~~.@.^",
             "^.._.......^",
             "^.._____...^",
             "^^^^^^=^^^^^",
             "^RRR..__RRR^",
             "^HHH..__HHH^",
             "^._.._____.^",
             "^.______...^",
             "^.S..__..*.^",
             "^##..__..##^",
             "^....__....^",
             "^^^..__..^^^",
             "^:...__...:^",
             "^::..__..::^",
             "^^^..__..^^^",
             "^^^^.__.^^^^",
             "^^^^^__^^^^^"],
    "warps": [warp(5, 19, "crowcrest", 5, 1, "down"), warp(6, 19, "crowcrest", 6, 1, "down"),
              warp(2, 1, "cinder_rift", 5, 11, "up")],
    "npcs": [npc("keeper", 8, 3, "down", "thornridge/keeper", "elder"),
             npc("trader", 4, 9, "right", "thornridge/trader", "villager"),
             npc("elder", 9, 11, "left", "thornridge/elder", "elder"),
             npc("sparkseer", 2, 13, "right", "thornridge/sparkseer", "elder"),
             npc("crystals", 9, 13, "left", "thornridge/crystals", "villager")],
    "signs": [{"x": 2, "y": 11, "dialogue": "thornridge/sign"}, {"x": 9, "y": 3, "dialogue": "thornridge/rock_find"}],
}
TEXT["thornridge"] = {
    "sign": ["THORNRIDGE", "Gorge village.", "Upper terrace: Rest Pool and the Cinder hollow"],
    "rock_find": {"lines": ["Someone stashed two Dash Brews under this rock!"], "action": "give_item dash_brew 2",
                  "flag": "thorn_rock_find", "once": True,
                  "after_flag": {"flag": "thorn_rock_find", "lines": ["Nothing under the rock now."]}},
    "keeper": {"lines": ["Keeper: Rest by the pool a while."], "action": "heal"},
    "trader": {"lines": ["Trader: Supplies for the road! Your bag holds as much as you like."],
               "action": "shop tonic strong_tonic max_tonic remedy cooling_gel dry_towel wake_bell spark_drop revival_leaf kin_charm"},
    "sparkseer": {"lines": ["Sparkseer: Every Spirling carries a spark of the Rift. Let me look at yours."],
                  "action": "spark_read",
                  "after_flag": {"flag": "spark_hint", "lines": ["Sparkseer: A Spark Charm brightens a spark that runs faint. The crystal stall sells them."]},
                  "flag": "spark_hint"},
    "crystals": {"lines": ["Crystal seller: Echo Crystals keep a move's echo. Teach it as often as you like!",
                           "Crystal seller: And things for Spirlings to hold, brews, pearls..."],
                 "action": "shop echo_ember echo_tide echo_bloom echo_volt echo_stone echo_gale echo_lumen echo_umbra spark_charm tide_pearl bark_wrap iron_burr swift_feather keen_lens power_brew guard_brew focus_brew dash_brew"},
    "elder": {
        "lines": ["Elder: The Cinder hollow is up the stairs. Its Warden, Orrin, hasn't said a word in weeks.",
                  "Elder: A Warden whose bond breaks becomes part of the Hush. Wake him, and he can help you mend the tear."],
        "after_flag": {"flag": "rift_cinder_sealed",
                       "lines": ["Elder: Orrin laughed today. First time since the storm.", "Elder: Veydal owes you, young cartographer."]},
    },
}

# --- Saltmarsh: boardwalks and reeds east of the lake ------------------------------------------
WORLD["saltmarsh"] = {
    "name": "Saltmarsh",
    "encounters": "saltmarsh",
    "rows": ["~~~~~++~~~~~",
             "~%%~~++~~%%~",
             "~%%%.++.%%%~",
             "~~%..__..%~~",
             "~~~.____.~~~",
             "~%%%%+%%%%%~",
             "~%~~~+~~~%%~",
             "~%~~~++++++~",
             "~%%%~~~~~+%~",
             "~~%%%%%%.+.~",
             "~~~~~~~..__~",
             "~~%%%%.____~",
             "_______._%%~",
             "~S%%%~~~%%%~",
             "~~~~~~~~~~~~"],
    "warps": [warp(0, 12, "brindlewick", 10, 6, "left"),
              warp(5, 0, "tide_rift", 5, 11, "up"), warp(6, 0, "tide_rift", 6, 11, "up")],
    "npcs": [npc("reedcutter", 8, 9, "left", "saltmarsh/reedcutter", "villager"),
             npc("neve", 3, 4, "right", "saltmarsh/neve", "ranger", trainer="Diver Neve",
                 intro="saltmarsh/neve_intro", defeat="saltmarsh/neve_defeat",
                 team=team(("Puddlet", 12), ("Breezel", 13)))],
    "signs": [{"x": 1, "y": 13, "dialogue": "saltmarsh/sign"}, {"x": 10, "y": 8, "dialogue": "saltmarsh/reed_find"}],
}
TEXT["saltmarsh"] = {
    "sign": ["SALTMARSH", "Boardwalk to the Tidewater hollow.", "Wild Spirlings here are strong. Travel with care."],
    "reed_find": {"lines": ["Bobbing in the reeds: a Power Brew, still sealed!"], "action": "give_item power_brew 1",
                  "flag": "marsh_reed_find", "once": True,
                  "after_flag": {"flag": "marsh_reed_find", "lines": ["Only reeds and a curious frog."]}},
    "reedcutter": {"lines": ["The water runs uphill toward the hollow since the storm.", "Spirlings hide in the reeds. Wade through and one may come out.",
                             "My lamp drowned in the flood. A Wickit's light would see me home. Know one?"],
                   "action": "quest_show reedcutter Wickit echo_lumen 1",
                   "after_flag": {"flag": "q_reedcutter_done", "lines": ["I still see that little light when I close my eyes. Thank you."]}},
    "neve": {"lines": ["Neve: Good fight. Here, a diver's Grapple Line. Hook it on a far post and pull yourself over the water.",
                       "Neve: Try the reed islet by the Brindlewick pier. Divers stash things there."],
             "action": "give_item grapple_line 1", "flag": "got_grapple", "once": True,
             "after_flag": {"flag": "got_grapple",
                            "lines": ["Neve: The Warden down there, Maelis, used to sing to the tide. Now she just stares at it."]}},
    "neve_intro": ["Neve: Heading for the hollow? Let's see if you're ready!"],
    "neve_defeat": ["Neve: Washed out... You're ready."],
}

# --- Murk Hollow: an old mine behind the Crowcrest cliff, with a pitch-dark gallery ----------
WORLD["murk_hollow"] = {
    "name": "Murk Hollow",
    "encounters": "murk_hollow",
    "rows": ["@@@@@@@@@@@@",
             "@L..S.L@.:.@",
             "@:..._....:@",
             "@L..__..@@@@",
             "@@@@@__@@@@@",
             "@:...__...:@",
             "@::..__..::@",
             "@@@..__..@@@",
             "@::......::@",
             "@::.____.::@",
             "@...____...@",
             "@@...__...@@",
             "@@@@@__@@@@@"],
    "warps": [warp(5, 12, "crowcrest", 9, 15, "down"), warp(6, 12, "crowcrest", 9, 15, "down")],
    "npcs": [npc("tamsin", 3, 10, "right", "murk_hollow/tamsin", "elder"),
             npc("delve", 9, 5, "left", "murk_hollow/delve", "villager", trainer="Delver Ros",
                 intro="murk_hollow/delve_intro", defeat="murk_hollow/delve_defeat",
                 team=team(("Mirkmole", 12), ("Shalebat", 13)))],
    "signs": [{"x": 4, "y": 1, "dialogue": "murk_hollow/sign_old"},
              {"x": 2, "y": 2, "dialogue": "murk_hollow/gallery_find"},
              {"x": 6, "y": 1, "dialogue": "murk_hollow/lamp_1"},
              {"x": 1, "y": 1, "dialogue": "murk_hollow/lamp_2"},
              {"x": 1, "y": 3, "dialogue": "murk_hollow/lamp_3"},
              {"x": 10, "y": 1, "dialogue": "murk_hollow/nook_find"}],
    # Lamp puzzle: light the lamps in the chalked order to open the rock at (7,2).
    "blocks": [{"x": 7, "y": 2, "open_flag": "hollow_lamps"}],
    # The old gallery is pitch dark: the Storm Lantern lights the way through.
    "gear_spots": [{"x": 5, "y": 4, "gear": "storm_lantern"}, {"x": 6, "y": 4, "gear": "storm_lantern"}],
}
TEXT["murk_hollow"] = {
    "tamsin": {"lines": ["Tamsin: Nobody's dug here since my knees gave out. The upper gallery's black as ink.",
                         "Tamsin: Take my Storm Lantern. It burns in any wind, and in the dark."],
               "action": "give_item storm_lantern 1", "flag": "got_lantern", "once": True,
               "after_flag": {"flag": "got_lantern",
                              "lines": ["Tamsin: Mirkmoles dug half these tunnels. They like the quiet, not the dark."]}},
    "delve": ["Ros: The Mirkmoles here hate bright light. Keep that lantern low."],
    "delve_intro": ["Ros: A cartographer in my mine? Show me what you've got!"],
    "delve_defeat": ["Ros: Dug myself into that one."],
    "sign_old": ["MURK HOLLOW GALLERY", "Closed after the storm.", "Mind your head.",
                 "Chalked below: 'Lamps for the store: by the sign, then the high corner, then the low one.'"],
    "lamp_1": {"lines": ["An old miner's lamp."], "action": "switch hollow_lamps 1 3"},
    "lamp_2": {"lines": ["An old miner's lamp."], "action": "switch hollow_lamps 2 3"},
    "lamp_3": {"lines": ["An old miner's lamp."], "action": "switch hollow_lamps 3 3"},
    "nook_find": {"lines": ["In the miners' store: an Echo Crystal (Gloom Pulse)!"], "action": "give_item echo_umbra 1",
                  "flag": "hollow_nook_find", "once": True,
                  "after_flag": {"flag": "hollow_nook_find", "lines": ["Empty shelves and old pick handles."]}},
    "gallery_find": {"lines": ["Wedged between two rocks: a Spark Coil! A Spirling holding it gains extra Energy each turn."],
                     "action": "give_item spark_coil 1", "flag": "hollow_find", "once": True,
                     "after_flag": {"flag": "hollow_find", "lines": ["Only dust and old pick marks now."]}},
}

# --- The two Rifts -----------------------------------------------------------------------------
cinder = json.load(open(os.path.join(MAPS, "cinder_rift.json")))
# Rift hollows are open-air craters, not dungeons: cliff walls, scree, the tear itself.
cinder["rows"] = [r.replace("W", "^").replace("f", ".").replace(",", ":") for r in cinder["rows"]]
cinder["warps"] = [warp(5, 12, "thornridge", 2, 2, "down"), warp(6, 12, "thornridge", 2, 2, "down")]
for n in cinder["npcs"]:
    n.pop("color", None)
    n.pop("sight", None)
    n["sprite"] = "warden"
WORLD["cinder_rift"] = cinder
TEXT["cinder_rift"] = {
    "acolyte_a": ["Pell: The heat in here makes Spirlings restless."],
    "acolyte_a_intro": ["Pell: We tend the Warden while he's lost in the Hush. Prove you can help him!"],
    "acolyte_a_defeat": ["Pell: Go on, then. Orrin is at the tear."],
    "acolyte_b": ["Suri: Orrin has guarded this hollow for years. He hasn't said a word since the storm."],
    "acolyte_b_intro": ["Suri: My Kindlop runs hot. Ready?"],
    "acolyte_b_defeat": ["Suri: Cooled off... just like that."],
    "orrin": {"lines": ["Orrin: ..."],
              "after_flag": {"flag": "rift_cinder_sealed",
                             "lines": ["Orrin: I'd forgotten my own Spirlings' names. Thank you for reminding me.",
                                       "Orrin: The tear is stitched. Mark it on your map, cartographer."]}},
    "orrin_intro": ["Warden Orrin: ...", "His Spirlings step forward on their own. They want him back."],
    "orrin_defeat": ["Warden Orrin: ...Ember? Is that you?", "Warden Orrin: I can hear them again. Quickly, help me close the tear!"],
}
tide = json.load(open(os.path.join(MAPS, "tide_rift.json")))
tide["rows"] = [r.replace("W", "^").replace("f", "_").replace(",", "%") for r in tide["rows"]]
tide["warps"] = [warp(5, 12, "saltmarsh", 5, 1, "down"), warp(6, 12, "saltmarsh", 6, 1, "down")]
tide["npcs"] = [n for n in tide["npcs"] if n["id"] != "diver"]
for n in tide["npcs"]:
    n.pop("color", None)
    n.pop("sight", None)
    n["sprite"] = "warden"
    n.pop("win_flags", None)
WORLD["tide_rift"] = tide
TEXT["tide_rift"] = {
    "mystic": ["Ilka: Maelis speaks with the tide itself. Or she did."],
    "mystic_intro": ["Ilka: The currents told me you'd come. Show me your bond!"],
    "mystic_defeat": ["Ilka: The currents... were right about you."],
    "maelis": {"lines": ["Maelis: ..."],
               "after_flag": {"flag": "rift_tide_sealed",
                              "lines": ["Maelis: The tide is still. Thank you, cartographer."]}},
    "maelis_intro": ["Warden Maelis: ...", "The water around her rises. Her Spirlings are calling for her."],
    "maelis_defeat": ["Warden Maelis: I remember the song now.", "Warden Maelis: Hold the tear with me... there. It's mended."],
}

BACKDROPS = {"saltmarsh": "lake", "tide_rift": "lake", "brindlewick": "lake", "crowcrest": "ridge",
             "thornridge": "ridge", "cinder_rift": "ember", "murk_hollow": "ridge"}
for mid, m in WORLD.items():
    m["backdrop"] = BACKDROPS.get(mid, "field")

# Rift resonance: battles in these maps use a field, and each Warden has a house rule.
FIELDS = {"cinder_rift": "ash_storm", "tide_rift": "high_tide", "murk_hollow": "deep_murk"}
for mid, f in FIELDS.items():
    WORLD[mid]["field"] = f
WARDEN_RULES = {"warden_orrin": "ember_pulse", "warden_maelis": "undertow"}
for m in WORLD.values():
    for n in m.get("npcs", []):
        if n["id"] in WARDEN_RULES:
            n["rule"] = WARDEN_RULES[n["id"]]

# Every map is in Veydal.
for m in WORLD.values():
    m["region"] = "veydal"
    m.setdefault("signs", [])
    for n in m.get("npcs", []):
        n.pop("color", None)

# Remove the old maps and dialogue that this world replaces.
for old in ["home", "start_town", "kestra_home", "route_1", "route_2"]:
    for d in (MAPS, DIA):
        p = os.path.join(d, old + ".json")
        if os.path.exists(p):
            os.remove(p)

ORDER = ["name", "region", "backdrop", "field", "encounters", "heal_point", "rows", "warps", "npcs", "signs", "gear_spots", "blocks"]
for mid, m in WORLD.items():
    out = {k: m[k] for k in ORDER if k in m}
    with open(os.path.join(MAPS, mid + ".json"), "w") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write("\n")
for fid, t in TEXT.items():
    with open(os.path.join(DIA, fid + ".json"), "w") as f:
        json.dump(t, f, indent=1, ensure_ascii=False)
        f.write("\n")
print("wrote", len(WORLD), "maps")
