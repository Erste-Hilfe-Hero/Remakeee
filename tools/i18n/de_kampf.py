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
"Kindlop burns, and its Kindling gift turns the Scorch into strength. It starts with 5 Energy. Beat Shalebat and Zippit without curing the Scorch.": "Kindlop brennt, und seine Gabe Kindling macht aus dem Scorch Stärke. Es startet mit 5 Energie. Besiege Shalebat und Zippit, ohne den Scorch zu heilen.",
"Mossling at half Vigor against Kindlop. Win within 5 turns.": "Mossling mit halber Kraft gegen Kindlop. Gewinne in höchstens 5 Runden.",
"Zippit starts with 4 Energy against a soaked Riptail. Win within 3 turns through the Volt reaction.": "Zippit startet mit 4 Energie gegen ein durchnässtes Riptail. Gewinne in höchstens 3 Runden über die Volt-Reaktion.",
"Zephlet starts with 2 Energy against Puddlet in the high tide. Win, resting exactly once.": "Zephlet startet mit 2 Energie gegen Puddlet in der Hochflut. Gewinne und raste dabei genau einmal.",
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

# Plan area 2, items 645-659: new Wayfarers.
T.update({
"Pathkeeper Imme": "Wegwärterin Imme", "Herder Joss": "Hirte Joss", "Netmender Aud": "Netzflickerin Aud", "Lampbearer Fenn": "Laternenträger Fenn",
"Imme: Out of Energy? Rest for a turn. Your Spirling gets it back.": "Imme: Keine Energie mehr? Raste eine Runde, dann kommt sie zurück.",
"Imme: I'm still learning too! Let's practise together.": "Imme: Ich lerne auch noch! Lass uns zusammen üben.",
"Imme: Tip: when your Energy runs low, pick Rest and catch your breath.": "Imme: Tipp: Wird die Energie knapp, wähl Rasten und hol Luft.",
"Imme: You rested at the right time. I'll remember that!": "Imme: Du hast zur rechten Zeit gerastet. Das merk ich mir!",
"Joss: Stages stack up. Guard twice and nothing gets through.": "Joss: Stufen addieren sich. Zweimal Schutz, und nichts kommt durch.",
"Joss: My Shalebat digs in. Watch its Guard climb!": "Joss: Mein Shalebat gräbt sich ein. Sieh, wie sein Schutz steigt!",
"Joss: Even a wall cracks. Well hit.": "Joss: Auch eine Mauer bekommt Risse. Gut getroffen.",
"Aud: A snare waits for the next Spirling that steps in. Swap with care.": "Aud: Eine Falle wartet auf den nächsten Spirling, der einwechselt. Wechsle mit Bedacht.",
"Aud: I mend nets, and I lay them too. Mind your step!": "Aud: Ich flicke Netze und lege sie auch aus. Pass auf, wohin du trittst!",
"Aud: Torn right through. Next time I'll knot them tighter.": "Aud: Glatt durchgerissen. Nächstes Mal knote ich fester.",
"Fenn: A Rift field lifts one element and dims another. Change it when it helps you.": "Fenn: Ein Riss-Feld stärkt ein Element und schwächt ein anderes. Wechsle es, wenn es dir hilft.",
"Fenn: My lantern bends the light down here. Let's see who it favors!": "Fenn: Meine Laterne lenkt hier unten das Licht. Mal sehen, wem es hilft!",
"Fenn: The light turned on me. Well played.": "Fenn: Das Licht hat sich gegen mich gewandt. Gut gespielt.",
})

# Plan area 2, items 492, 511, 577, 578.
T.update({
"Right now: %s.": "Gerade: %s.",
"Used now, it lands on turn %d.": "Jetzt eingesetzt, schlägt sie in Runde %d ein.",
"Then mends a little at the end of the next %d turns.": "Heilt danach am Ende der nächsten %d Runden ein wenig.",
"Makes the Resonance field last %d turns longer.": "Lässt das Resonanz-Feld %d Runden länger halten.",
"By %d at full Vigor.": "Bei voller Kraft um %d.",
})

# Plan area 2, items 675-677: Warden field rules.
T.update({
"Ash Rain": "Aschenregen", "Ash rains down: for 3 turns the Ash Storm can't be called away.": "Asche regnet herab: 3 Runden lang lässt sich der Aschesturm nicht vertreiben.",
"Tide Turn": "Gezeitenwechsel", "The tide comes and goes: High Tide for 2 turns, then 2 turns of calm.": "Die Flut kommt und geht: 2 Runden Hochflut, dann 2 Runden Ruhe.",
"The %s won't give way yet.": "%s weicht noch nicht.",
})

# Plan area 2, items 678-679: the Warden turning point.
T.update({
"Turning point, %s: %s": "Wendepunkt, %s: %s",
"The pulse quickens: now 2 extra Energy every turn.": "Der Puls wird schneller: jetzt 2 Energie extra pro Runde.",
"The pulse flares: the foe's Spirlings gain 1 Energy at once.": "Der Puls flackert auf: Die gegnerischen Spirlings erhalten sofort 1 Energie.",
"One left? Then the embers burn for both of us!": "Nur noch einer? Dann brennt die Glut für uns beide!",
"The current deepens: your next Spirling to come in loses Might.": "Die Strömung wird tiefer: Dein nächster eingewechselter Spirling verliert Wucht.",
"The tide turns. Whoever you send next, it pulls under!": "Die Flut kippt. Wen du auch schickst, sie zieht ihn hinab!",
})

# Plan area 2, items 680-681: Warden cover in the lexicon.
T.update({
"Lexicon": "Lexikon", "Lexicon %d": "Lexikon %d",
"The cartographers": "Die Kartografen",
"Kestra's guild draws every road of Veydal again each year. A map that is not walked goes wrong, they say, and a Wayfarer who keeps all their Spirlings standing walks it best.": "Kestras Gilde zeichnet jedes Jahr alle Wege von Veydal neu. Eine Karte, die keiner abläuft, wird falsch, sagen sie, und am besten läuft sie ab, wer alle seine Spirlings auf den Beinen hält.",
"Reactions": "Reaktionen",
"An art can set off a status already on its target: Ember on a Soaked foe dries it with a burst, Stone shakes off a Jolt. The battle log names every reaction it sees.": "Eine Technik kann einen Zustand auslösen, der schon auf dem Ziel liegt: Glut auf einem durchnässten Gegner trocknet ihn mit einem Knall, Stein schüttelt einen Schock ab. Das Kampfprotokoll nennt jede Reaktion.",
"Rift mystics": "Riss-Mystiker",
"The mystics at the Tide Rift listen to the Hush instead of fighting it. They chain reactions on purpose, one status feeding the next art.": "Die Mystiker am Gezeitenriss lauschen der Stille, statt sie zu bekämpfen. Sie reihen Reaktionen mit Absicht aneinander, ein Zustand nährt die nächste Technik.",
"The Drowned Heart": "Das Ertrunkene Herz",
"The Hush gathered at the bottom of the Tide Rift into one heavy heart. It grows with every Spirling you field, so a full team does not crush it, it only meets it.": "Die Stille hat sich am Grund des Gezeitenrisses zu einem schweren Herzen gesammelt. Es wächst mit jedem Spirling, den du aufstellst, also erdrückt ein volles Team es nicht, es stellt sich ihm nur.",
"Orrin's cover": "Orrins Deckung",
"Orrin knows that Tide puts out his embers. That is why Shalebat walks with him: its Stone hide and Hunker Down take the Tide arts you answer with, while Kindlop and Smoldrake build up Energy.": "Orrin weiß, dass Flut seine Glut löscht. Darum geht Shalebat mit ihm: Seine Steinhaut und Hunker Down fangen die Flut-Techniken ab, mit denen du antwortest, während Kindlop und Smoldrake Energie sammeln.",
"Maelis's cover": "Maelis' Deckung",
"Maelis knows her tide fears Volt and Bloom. Zephlet's Gale cuts Bloom down, and Zippit holds against the Volt Spirlings you bring, so her Riptail can wait for its moment.": "Maelis weiß, dass ihre Flut Volt und Blüte fürchtet. Zephlets Wind schneidet Blüte nieder, und Zippit hält gegen die Volt-Spirlings, die du mitbringst, damit ihr Riptail auf seinen Moment warten kann.",
})

# Plan area 2, items 682-684: the Warden Second Trial.
T.update({
"%s offers the Second Trial: two rules at once, a full team. Battle?": "%s bietet die Zweite Prüfung an: zwei Regeln zugleich, ein volles Team. Kämpfen?",
"%s: You passed the Second Trial. The Rift remembers you.": "%s: Du hast die Zweite Prüfung bestanden. Der Riss wird sich an dich erinnern.",
})

# Plan area 2, item 687: the Warden card.
T.update({
"No rule.": "Keine Regel.",
"Spirlings: %d": "Spirlings: %d",
"Elements: %s": "Elemente: %s",
"Face the Warden now?": "Jetzt gegen den Wächter antreten?",
"Fight": "Kämpfen",
})

# Plan area 2, items 704, 706: the tag Trial and lanterns.
T.update({
"Riptail and Kestra's Zephlet against Zippit and Kelpup. Win without losing a Spirling.": "Riptail und Kestras Zephlet gegen Zippit und Kelpup. Gewinne, ohne einen Spirling zu verlieren.",
"Lanterns %d/%d": "Laternen %d/%d",
})

# Plan area 2, items 707-713: hints, restart, goal banner, results and the lantern reward.
T.update({
"Smoldrake fights Ember with Ember. Your Tide arts hit it hard, but Energy is short in the storm.": "Smoldrake kämpft mit Glut gegen Glut. Deine Tide-Techniken treffen es hart, aber im Sturm wird die Energie knapp.",
"Open with Fizz Pop, call the tide once, then keep up the Fizz Pop.": "Beginne mit Fizz Pop, rufe einmal die Flut und bleib dann bei Fizz Pop.",
"Kindlop only has 5 Energy. Plan one rest, and spend the rest of it on blows that count.": "Kindlop hat nur 5 Energie. Plane eine Rast ein und gib den Rest für Schläge aus, die zählen.",
"Glow Knuckle twice, rest once, then Glow Knuckle and Cinder Nip.": "Zweimal Glow Knuckle, einmal rasten, dann Glow Knuckle und Cinder Nip.",
"Kindlop wants to heat up. Hit it before it gets going, and do not wait.": "Kindlop will sich aufheizen. Triff es, bevor es loslegt, und warte nicht.",
"Pollen Prick twice, a puff of Puffcap Haze, then finish with Pollen Prick.": "Zweimal Pollen Prick, ein Hauch Puffcap Haze, dann zum Schluss Pollen Prick.",
"The Volt reaction needs a soaked foe and a Volt art. Riptail is already soaked.": "Die Volt-Reaktion braucht einen durchnässten Gegner und eine Volt-Technik. Riptail ist schon nass.",
"Bite twice with Crackle Bite, then end it with Static Tag.": "Beiß zweimal mit Crackle Bite zu und beende es mit Static Tag.",
"With 2 Energy, Zephlet cannot strike well yet. The one rest belongs at the start.": "Mit 2 Energie kann Zephlet noch nicht gut zuschlagen. Die eine Rast gehört an den Anfang.",
"Rest first, then Crosswind twice and Draft Needle to finish.": "Erst rasten, dann zweimal Crosswind und Draft Needle zum Schluss.",
"Kestra's Zephlet plays on its own. Keep Zippit from getting a second turn.": "Kestras Zephlet handelt selbst. Lass Zippit keine zweite Runde.",
"Pull Zippit under with Undertow, then Rip Current, then Rip Current again.": "Zieh Zippit mit Undertow hinab, dann Rip Current und noch einmal Rip Current.",
"Hint: %s": "Hinweis: %s",
"Try again?": "Nochmal versuchen?",
"Restart": "Neustart",
"Turns left: %d": "Runden übrig: %d",
"Win within %d turns.": "Gewinne in höchstens %d Runden.",
"Win without losing a Spirling.": "Gewinne, ohne einen Spirling zu verlieren.",
"Rest exactly %d times.": "Raste genau %d-mal.",
"Rest exactly once.": "Raste genau einmal.",
"Never cure the %s.": "Heile nie den %s.",
"Set off a %s reaction.": "Löse eine %s-Reaktion aus.",
"Land the last blow with %s.": "Setze den letzten Treffer mit %s.",
"Every Trial shines with 3 lanterns! You received %s.": "Jede Prüfung leuchtet mit 3 Laternen! Du erhältst %s.",
})

# Plan area 2, items 734-739: Tamer AI, ring cap on the Warden card, Tailwind.
T.update({
"Ring cap: R%d. The Warden's highest: R%d.": "Ring-Obergrenze: R%d. Höchster Spirling des Wächters: R%d.",
"This battle has beaten you a few times. Take Tailwind? Your team is fully healed and the foe starts with %d Energy less.": "Dieser Kampf hat dich schon ein paar Mal besiegt. Rückenwind nehmen? Dein Team wird voll geheilt und der Gegner startet mit %d Energie weniger.",
"This battle has beaten you a few times. Take Tailwind? Your team is fully healed.": "Dieser Kampf hat dich schon ein paar Mal besiegt. Rückenwind nehmen? Dein Team wird voll geheilt.",
"Take Tailwind": "Rückenwind nehmen",
"No, thanks": "Nein, danke",
"Tailwind helped in this battle. Used %d times so far.": "Rückenwind hat in diesem Kampf geholfen. Bisher %d-mal genutzt.",
})

# Plan area 2, item 746: a lowered difficulty stays visible.
T.update({
"(lowered)": "(gesenkt)",
})
