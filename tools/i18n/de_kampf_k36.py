"""German texts for KAMPF_PLAN_1000 items 526, 535, 558, 559, 812: the sweeper and surger AI lines,
the lesson battles of Pathkeeper Imme and Wanderer Wren (data/lessons.json) and their goals.
Own file so the parallel plan threads do not collide in the shared tables."""
T = {
# data/dialogue/battle_lines.json
"Hits the whole line at once.": "Trifft die ganze Reihe auf einmal.",
"One fuse out. The rest still burn.": "Eine Lunte aus. Der Rest brennt noch.",
"Took two birds. Kept the stone.": "Zwei Fliegen erwischt. Die Klappe behalten.",
"Last spark. Light it all.": "Letzter Funke. Alles anzünden.",
"Saves every spark for one blow.": "Spart jeden Funken für einen Schlag.",
"Spent it all. Worth it.": "Alles verpulvert. Hat sich gelohnt.",
"That was the whole bucket.": "Das war der ganze Eimer.",
"Nothing held back now.": "Jetzt wird nichts mehr zurückgehalten.",
# BattlePuzzle goals and the lesson menu
"Leave the foe standing below %d%% of its Vigor.": "Lass den Gegner unter %d %% seiner Kraft stehen.",
"Leave the foe with a status.": "Lass den Gegner mit einem Status zurück.",
"Lessons": "Lektionen",
"Imme's lessons": "Immes Lektionen",
"Wren's bond lessons": "Wrens Bindungslektionen",
# data/lessons.json
"Lesson: Matchups": "Lektion: Elemente",
"Puddlet against Kindlop. Tide beats Ember: pick the art that hits hard.": "Puddlet gegen Kindlop. Flut schlägt Glut: Wähle die Technik, die hart trifft.",
"Look at the element of each art. Tide washes out Ember.": "Achte auf das Element jeder Technik. Flut löscht Glut.",
"Use Fizz Pop every turn.": "Setze jede Runde Sprudelknall ein.",
"Lesson: Rest": "Lektion: Rasten",
"Shalebat starts with no Energy to spare. Rest once, then strike.": "Shalebat hat keine Energie übrig. Raste einmal, dann schlag zu.",
"Dusk Rake costs 3 Energy. Resting gives some back.": "Dämmerkralle kostet 3 Energie. Rasten gibt etwas zurück.",
"Rest on the first turn, then Dusk Rake.": "Raste in der ersten Runde, dann Dämmerkralle.",
"Lesson: Overcharge": "Lektion: Überladung",
"Zippit knows Overcharge: every spare Energy adds power. Finish the Mossling with it.": "Zippit kann Überladung: Jede übrige Energie gibt mehr Kraft. Erledige das Mossling damit.",
"Overcharge spends all spare Energy. The more is left, the harder it hits.": "Überladung verbraucht alle übrige Energie. Je mehr übrig ist, desto härter trifft sie.",
"Overcharge every turn.": "Setze jede Runde Überladung ein.",
"Bond lesson: Weaken": "Bindungslektion: Schwächen",
"A wild Spirling hears your call best when it is worn out. Wear this Mossling down, but don't knock it out.": "Ein wildes Spirling hört deinen Ruf am besten, wenn es erschöpft ist. Zermürbe dieses Mossling, aber besiege es nicht.",
"Updraft hits too hard at the end. A soft art leaves it standing.": "Aufwind trifft am Ende zu hart. Eine sanfte Technik lässt es stehen.",
"Two soft Draft Needles are enough.": "Zwei sanfte Zugnadeln reichen.",
"Bond lesson: Status": "Bindungslektion: Status",
"A status makes the bond easier still. Leave Kindlop worn down and soaked.": "Ein Status macht die Bindung noch leichter. Lass Kindlop erschöpft und durchnässt zurück.",
"Drench soaks the foe. Fizz Pop wears it down.": "Durchnässen macht den Gegner nass. Sprudelknall zermürbt ihn.",
"Fizz Pop, then Drench, then one more soft hit.": "Sprudelknall, dann Durchnässen, dann noch ein sanfter Treffer.",
}
# Developer checks in TrainerData (validator messages, never shown to players).
KEEP = ["starter ", "unknown strategy '%s'", "strategy %s needs the AI profile %s", "strategy multi needs two foes at the front",
        "%s: %s has no art that hits all foes", "%s: only %d Spirlings know an Overcharge art"]
