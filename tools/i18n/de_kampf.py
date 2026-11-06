"""German texts for the battle additions of plan area 2 (docs/plan5000/02_kampf.md).
Own file so the parallel plan threads do not collide in the shared tables."""
T = {
"%s is taxed: every art costs %d more Energy for %d turns!": "%s zahlt Abgabe: jede Technik kostet %d Energie mehr, %d Runden lang!",
"The Energy tax on %s lifts.": "Die Energie-Abgabe auf %s endet.",
"Locked for %d turns after each use.": "Nach jedem Einsatz %d Runden gesperrt.",
"x%s power if the foe has any status.": "Stärke x%s, wenn das Ziel einen Status trägt.",
"x%s power if the foe has a lowered stat.": "Stärke x%s, wenn ein Wert des Ziels gesenkt ist.",
"x%s power if the foe has %s.": "Stärke x%s, wenn das Ziel %s trägt.",
"The foe's arts cost %d more Energy for %d turns.": "Techniken des Ziels kosten %d Energie mehr, %d Runden lang.",
"In a field it takes the field's element, power +%d.": "Im Feld nimmt sie dessen Element an, Stärke +%d.",
"Then raises its own %s by %d.": "Danach eigene %s +%d.",
"Then lowers its own %s by %d.": "Danach eigene %s -%d.",
"wait %d": "warte %d",
"Energy tax %d": "Energie-Abgabe %d",
}
T.update({
"Daze does not spoil its aim.": "Benommenheit stört ihr Zielen nicht.",
"Ignores the foe's raised Guard and Focus.": "Übergeht erhöhten Schutz und Fokus des Ziels.",
"Cures its own status.": "Heilt den eigenen Status.",
"Hands its own status to the foe.": "Gibt den eigenen Status an das Ziel weiter.",
"Blows the snares off its own side.": "Fegt die Fallen von der eigenen Seite.",
"Lays a snare: the next foe to step in loses %d%% Vigor.": "Legt eine Falle: der nächste einwechselnde Gegner verliert %d%% Kraft.",
"Lays a snare: the next foe to step in gets %s.": "Legt eine Falle: der nächste einwechselnde Gegner erhält %s.",
"Lays a snare that weakens the next foe to step in.": "Legt eine Falle, die den nächsten einwechselnden Gegner schwächt.",
"No room for another snare.": "Für eine weitere Falle ist kein Platz.",
"A snare lies in wait on your side!": "Auf deiner Seite lauert eine Falle!",
"A snare lies in wait on the foe's side!": "Auf der Gegnerseite lauert eine Falle!",
"%s springs the snare!": "%s tritt in die Falle!",
"The snares on your side blow away.": "Die Fallen auf deiner Seite sind fortgeweht.",
"The snares on the foe's side blow away.": "Die Fallen auf der Gegnerseite sind fortgeweht.",
})
T.update({
"%s can't heal for %d turns!": "%s kann %d Runden lang nicht heilen!",
"%s can't heal right now!": "%s kann gerade nicht heilen!",
"Burns away %d of the foe's Energy.": "Verbrennt %d Energie des Ziels.",
"The foe can't heal for %d turns.": "Das Ziel kann %d Runden lang nicht heilen.",
"Ends the foe's %s.": "Beendet %s beim Ziel.",
"Ends the foe's status.": "Beendet den Status des Ziels.",
"Steals one raised stage from the foe.": "Stiehlt dem Ziel eine erhöhte Stufe.",
})
T.update({
"The long fight wears everyone out. Nobody can heal any more!": "Der lange Kampf zehrt an allen. Niemand kann mehr heilen!",
})
T.update({
"The foe's Spirlings gain 1 extra Energy every second turn.": "Die Spirlings des Gegners erhalten jede zweite Runde 1 zusätzliche Energie.",
"The current drags at your lead: it starts with less Pace.": "Die Strömung zerrt an deinem ersten Spirling: Er startet mit weniger Tempo.",
"Relaxed battles for enjoying the story. Foes deal 90% damage.": "Entspannte Kämpfe, um die Geschichte zu genießen. Gegner machen 90 % Schaden.",
})

# Plan area 2, item 451: delayed hits.
T.update({
"%s will land in %d turns!": "%s trifft in %d Runden!",
"%s fades with nobody to strike.": "%s verhallt, weil niemand mehr dasteht.",
"%s lands on %s!": "%s trifft %s!",
"Lands %d turns later on whoever stands there.": "Trifft %d Runden später, wer dann dort steht.",
})

# Plan area 2, items 696-700: Trials (puzzle battles) at the Rifts.
T.update({
"Trials": "Prüfungen",
"Trial solved!": "Prüfung bestanden!",
"Not this time. The Trial waits for you.": "Diesmal nicht. Die Prüfung wartet auf dich.",
"Ember Trial 1": "Glutprobe 1",
"Ember Trial 2": "Glutprobe 2",
"Ember Trial 3": "Glutprobe 3",
"Current Trial 1": "Strömungsprobe 1",
"Current Trial 2": "Strömungsprobe 2",
"Current Trial 3": "Strömungsprobe 3",
"Puddlet against Smoldrake in the ash storm. Win within 4 turns.": "Puddlet gegen Smoldrake im Aschesturm. Gewinne in höchstens 4 Runden.",
"Talusk alone against two. Win within 4 turns.": "Talusk allein gegen zwei. Gewinne in höchstens 4 Runden.",
"Two tired Spirlings against Smoldrake. Win within 4 turns.": "Zwei müde Spirlings gegen Smoldrake. Gewinne in höchstens 4 Runden.",
"Zippit starts with 4 Energy against a soaked Riptail. Win within 3 turns through the Volt reaction.": "Zippit startet mit 4 Energie gegen ein durchnässtes Riptail. Gewinne in höchstens 3 Runden über die Volt-Reaktion.",
"Mossling against Riptail in the drag of the current. Win within 4 turns.": "Mossling gegen Riptail im Sog der Strömung. Gewinne in höchstens 4 Runden.",
"Kelpup against Riptail, tide against tide. Win within 4 turns.": "Kelpup gegen Riptail, Flut gegen Flut. Gewinne in höchstens 4 Runden.",
})

# Plan area 2, items 755-757: bonus goals.
T.update({
"Bonus goal: %s.": "Bonusziel: %s.",
"win within %d turns": "gewinne in höchstens %d Runden",
"win without anyone on your side fainting": "gewinne, ohne dass jemand auf deiner Seite umfällt",
"win without resting": "gewinne, ohne zu rasten",
"win using only %s arts": "gewinne nur mit %s-Techniken",
"win sending out at most %d Spirlings": "gewinne mit höchstens %d eingesetzten Spirlings",
"win with at least %d%% Vigor left in your team": "gewinne mit mindestens %d %% Kraft im Team",
"win setting off at least %d reactions": "gewinne mit mindestens %d Reaktionen",
"Bonus goal met!": "Bonusziel erreicht!",
"You get %d Echo Crystal shard(s).": "Du erhältst %d Echo-Kristall-Splitter.",
"%d shards join into an Echo Crystal!": "%d Splitter fügen sich zu einem Echo-Kristall!",
"A new lexicon entry is written down.": "Ein neuer Lexikon-Eintrag wird notiert.",
"Ember Trial Taker": "Glutprüfling",
"Current Rider": "Strömungsreiter",
})

# Plan area 2, items 780-793: rule variants.
T.update({
"At most %d variants at once.": "Höchstens %d Varianten gleichzeitig.",
"Unknown variant %s.": "Unbekannte Variante %s.",
"%s and %s don't go together.": "%s und %s passen nicht zusammen.",
"Spark Poor": "Funkenarm", "Energy tops out at 6, and everyone starts with 6.": "Energie reicht nur bis 6, und alle starten mit 6.",
"Full Charge": "Volle Ladung", "Everyone starts full, gains no Energy per turn, and resting gives 3.": "Alle starten voll, gewinnen pro Runde keine Energie, und Rasten gibt 3.",
"Swap Toll": "Wechselzoll", "Every chosen swap costs the incoming Spirling 2 Energy.": "Jeder freiwillige Wechsel kostet den eingewechselten Spirling 2 Energie.",
"Glass Blades": "Glasklingen", "Every Spirling has half its Vigor.": "Jeder Spirling hat nur die halbe Kraft.",
"Tough Round": "Zähe Runde", "Every Spirling has one and a half times its Vigor.": "Jeder Spirling hat anderthalbmal so viel Kraft.",
"No Home Edge": "Ohne Heimvorteil", "Arts of a Spirling's own element get no bonus.": "Techniken des eigenen Elements bekommen keinen Bonus.",
"Short Breath": "Kurzer Atem", "Every status ends after 2 turns at most.": "Jeder Status endet spätestens nach 2 Runden.",
"Strong Reactions": "Starke Reaktionen", "Element reactions hit twice as hard beyond the normal.": "Element-Reaktionen wirken über das Normale hinaus doppelt so stark.",
"Late End": "Spätes Ende", "From turn 15, every Spirling in front loses 1/8 of its Vigor each turn.": "Ab Runde 15 verliert jeder aktive Spirling jede Runde 1/8 seiner Kraft.",
})

# Plan area 2, items 762, 765, 788, 791, 792.
T.update({
"Optional extra goals in Wayfarer and Warden battles.": "Freiwillige Zusatzziele in Kämpfen gegen Wanderer und Wächter.",
"Bonus goals: %s": "Bonusziele: %s",
"T%d": "R%d",
"The Rift stirs: %s comes next turn!": "Der Riss regt sich: nächste Runde kommt %s!",
"Stage Still": "Stufenstarr", "No stage changes at all; arts that only change stages are locked.": "Keine Stufenänderungen; reine Stufen-Techniken sind gesperrt.",
"Field Swirl": "Feldwirbel", "Every 3 turns a random field takes over, announced a turn early.": "Alle 3 Runden übernimmt ein zufälliges Feld, eine Runde vorher angesagt.",
"No Rest": "Kein Rasten", "Resting is gone while an art can be paid; instead everyone gains 3 Energy each turn.": "Rasten fehlt, solange eine Technik bezahlbar ist; dafür gibt es für alle 3 Energie pro Runde.",
})

# Plan area 2, items 461, 566-570, 591-608.
T.update({
"The stone grounds the charge in %s!": "Der Stein erdet die Ladung in %s!",
"The gust blows %s dry, and it slows down!": "Die Böe bläst %s trocken, es wird langsamer!",
"The light startles %s awake!": "Das Licht reißt %s aus dem Schlaf!",
"There is no Resonance field to hold.": "Es gibt kein Resonanz-Feld, das sich halten ließe.",
"The %s holds on for %d more turns!": "%s hält noch %d Runden länger!",
})

# Plan area 2, items 616-628: profile mottos and battle lines (data/dialogue/battle_lines.json).
T.update({
"Never backs down, never swaps.": "Weicht nie zurück, wechselt nie.",
"Hah! That just warms me up!": "Ha! Jetzt bin ich erst warm!",
"Down it goes! Who's next?": "Der liegt! Wer ist der Nächste?",
"One left. All in, all out!": "Einer noch. Alles oder nichts!",
"Builds up guard and waits.": "Baut Schutz auf und wartet.",
"A crack in the wall. It holds.": "Ein Riss in der Mauer. Sie hält.",
"You hit stone. Stone wins.": "Du triffst Stein. Stein gewinnt.",
"Last stone standing. Come on.": "Der letzte Stein steht. Komm nur.",
"Spoils your plans before striking.": "Stört erst deine Pläne, dann trifft er.",
"Fine. My tricks are still out there.": "Na gut. Meine Tricks wirken noch.",
"Told you that would sting.": "Hab doch gesagt, das brennt.",
"One trick left. It's a good one.": "Ein Trick bleibt. Ein guter.",
"Shapes the Rift field first.": "Formt zuerst das Riss-Feld.",
"The field still favors me.": "Das Feld hilft mir immer noch.",
"The Rift chose my side.": "Der Riss steht auf meiner Seite.",
"Last one. Let the Rift decide.": "Der Letzte. Der Riss entscheidet.",
"Plans every turn ahead.": "Plant jede Runde voraus.",
"Expected. The plan holds.": "Eingeplant. Der Plan steht.",
"Just as I worked it out.": "Genau wie berechnet.",
"Last piece on the board. Watch.": "Letzte Figur im Spiel. Pass auf.",
"Still learning, sometimes guesses.": "Lernt noch, rät manchmal.",
"Oh no! I'll write that down.": "Oh nein! Das schreib ich mir auf.",
"Wait, did I do that? Yes!": "Moment, war ich das? Ja!",
"My last one... please, buddy!": "Mein Letzter... bitte, Kumpel!",
"Rests, mends and outlasts you.": "Rastet, heilt und hält länger durch.",
"Slow and steady. Still here.": "Langsam, aber stetig. Noch da.",
"You tired out first.": "Du bist zuerst müde geworden.",
"One left, plenty of breath.": "Einer noch, und viel Atem.",
})
