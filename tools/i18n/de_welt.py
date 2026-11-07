# German texts for area 3 (world, maps, exploring). Written to data/i18n/de/ by tools/i18n/build.py.
# Kept apart from de_world.py so the world thread can add maps without clashing with story edits.
T = {
# Dungeon hint boards (item 1027)
"Somewhere near the entrance, someone has pinned a new note to the board.": "Irgendwo am Eingang hat jemand einen neuen Zettel an die Tafel gesteckt.",
# Cartographer's stones (items 1084, 1085)
"You trace the mark with your finger. Cartographer's stones found: %d/%d": "Du fährst das Zeichen mit dem Finger nach. Kartografensteine gefunden: %d/%d",
"Tucked behind the stone lies a keepsake: %s.": "Hinter dem Stein steckt ein Andenken: %s.",
# Cave campfires (item 992)
"You sit by the fire for a while. Your journey is saved.": "Du sitzt eine Weile am Feuer. Deine Reise ist gespeichert.",
"The fire smokes. Saving did not work this time.": "Das Feuer qualmt. Speichern hat diesmal nicht geklappt.",
"The warmth is welcome, but it does not rest your team.": "Die Wärme tut gut, aber dein Team erholt sich davon nicht.",
# Gear (data/items.json)
"Wading Boots": "Watstiefel",
"Wayfarer Gear. Tall leather boots: walk through shallow water, step by step.": "Wanderer-Ausrüstung. Hohe Lederstiefel: Schritt für Schritt durch seichtes Wasser waten.",
"The water here is shallow, but too cold for bare feet. Wading boots would do.": "Das Wasser ist hier seicht, aber zu kalt für nackte Füße. Watstiefel wären gut.",
"Pry Bar": "Hebelstange",
"Wayfarer Gear. Face a sluice wheel, a mine cart or a grate and press A to turn, shove or lift it.": "Wanderer-Ausrüstung. Stell dich vor ein Schleusenrad, eine Lore oder ein Gitter und drück A, um es zu drehen, zu schieben oder anzuheben.",
"It won't budge by hand. A pry bar would give you the leverage.": "Mit bloßen Händen rührt sich das nicht. Mit einer Hebelstange hättest du die Kraft.",
"Rope Ladder": "Strickleiter",
"Wayfarer Gear. Face a marked edge over a shaft and press A to tie it on. It stays there, and you climb down rung by rung.": "Wanderer-Ausrüstung. Stell dich an eine markierte Kante über einem Schacht und drück A, um sie festzuknoten. Sie bleibt dort, und du kletterst Sprosse für Sprosse hinab.",
"A chalk mark on the edge of a shaft. A rope ladder could be tied on here.": "Ein Kreidezeichen am Rand eines Schachts. Hier ließe sich eine Strickleiter festknoten.",
"Plank Bundle": "Bretterbündel",
"Wayfarer Gear. Face a gap with a chalk mark and press A to lay a plank over it. The plank stays.": "Wanderer-Ausrüstung. Stell dich vor eine Lücke mit Kreidezeichen und drück A, um ein Brett darüberzulegen. Das Brett bleibt liegen.",
"A narrow gap with a chalk mark. A plank would bridge it.": "Eine schmale Lücke mit Kreidezeichen. Ein Brett würde sie überbrücken.",
"Survey Glass": "Peilglas",
"Wayfarer Gear. A brass spyglass: face open ground and press A to spot hidden finds up to 6 steps ahead on the minimap. It needs 20 seconds between looks.": "Wanderer-Ausrüstung. Ein Messingfernrohr: schau auf freien Boden und drück A, dann zeigt die Minikarte versteckte Funde bis 6 Schritte voraus. Zwischen zwei Blicken braucht es 20 Sekunden.",
"With a Survey Glass you could look for hidden finds from here.": "Mit einem Peilglas könntest du von hier aus nach versteckten Funden suchen.",
"The glass is still misted. %d s.": "Das Glas ist noch beschlagen. %d s.",
"Through the glass: %d glints ahead.": "Durchs Glas: %d Glitzern voraus.",
"Through the glass: nothing glints ahead.": "Durchs Glas: voraus glitzert nichts.",
# Gear page in the satchel
"Works on: %s": "Wirkt bei: %s",
"Always on foot: you walk, wade and climb yourself.": "Immer zu Fuß: du gehst, watest und kletterst selbst.",
"narrow water with a post on the far side": "schmalem Wasser mit Pfosten am anderen Ufer",
"low cliffs": "niedrigen Klippen",
"vine walls (v)": "Rankenwänden (v)",
"shallow water (w)": "seichtem Wasser (w)",
"gaps with a chalk mark (Y)": "Lücken mit Kreidezeichen (Y)",
"pitch-dark passages": "stockdunklen Gängen",
"sluice wheels, mine carts and grates": "Schleusenrädern, Loren und Gittern",
"marked edges above a shaft": "markierten Kanten über einem Schacht",
"open ground ahead (hidden finds up to 6 steps away)": "freiem Boden voraus (versteckte Funde bis 6 Schritte entfernt)",
# Puzzle rooms
"Room": "Raum",
"Puzzle room": "Rätselraum",
"Undo last push": "Letztes Schieben zurück",
"Reset room": "Raum zurücksetzen",
"Put every boulder back where it started?": "Alle Felsblöcke an ihren Anfang zurückstellen?",
"It has already been moved.": "Das ist schon bewegt.",
"It won't budge.": "Das rührt sich nicht.",
"You set the %s and lean on it. Something gives with a groan!": "Du setzt die %s an und stemmst dich dagegen. Mit einem Ächzen gibt etwas nach!",
"The floor gave way! You land on the level below, unhurt.": "Der Boden ist eingebrochen! Du landest unverletzt auf der Ebene darunter.",
"You tie the rope ladder to the edge. It will stay here.": "Du knotest die Strickleiter an der Kante fest. Sie bleibt hier hängen.",
"You lay a plank over the gap. It holds.": "Du legst ein Brett über die Lücke. Es hält.",
}
T.update({
# Hidden finds and the Spirlog Tracker
"Something glints here...": "Hier glitzert etwas...",
"Hidden finds here: %d/%d": "Versteckte Funde hier: %d/%d",
"ferns": "Farn",
"reeds": "Schilf",
"scree": "Geröll",
"shallow water": "seichtes Wasser",
"cave": "Höhle",
# Finds by region in the records (item 1096)
"Finds by region": "Funde nach Region",
"Finds: %d/%d": "Funde: %d/%d",
"Secrets: %d/%d": "Geheimnisse: %d/%d",
# Fishing bench in Quillbrook (item 935)
"You sit on the bench and watch the line drift. Time slips by...": "Du setzt dich auf die Bank und schaust der Angelschnur nach. Die Zeit verstreicht...",
"Dawn breaks over the water.": "Über dem Wasser bricht der Morgen an.",
"The sun climbs high. It is broad day now.": "Die Sonne steigt hoch. Jetzt ist heller Tag.",
"The light turns golden. Dusk settles in.": "Das Licht wird golden. Die Dämmerung zieht auf.",
"Stars come out over the brook. Night has fallen.": "Über dem Bach gehen die Sterne auf. Es ist Nacht geworden.",
# Lake benches (item 1093)
"You sit down and look out over the lake. Everything goes quiet...": "Du setzt dich und schaust über den See. Alles wird still...",
"Somewhere out on the water, a Spirling calls.": "Irgendwo draußen auf dem Wasser ruft ein Spirling.",
})

# Secret passages (area 3 item 1082)
T.update({
"The smooth rock gives under your hands and slides aside. A way opens.": "Der glatte Fels gibt unter deinen Händen nach und gleitet zur Seite. Ein Weg öffnet sich.",
})

# Cave rope levers (area 3 item 983)
T.update({
"You pull the lever. Somewhere a rope ladder rattles down.": "Du ziehst den Hebel. Irgendwo rasselt eine Strickleiter herunter.",
})

# Dungeons (area 3 items 1008 to 1010)
T.update({
"The bell hums softly. This room is done.": "Die Glocke summt leise. Dieser Raum ist geschafft.",
"Clang! The note jars, and every bell falls silent. Start again.": "Klong! Der Ton passt nicht, und alle Glocken verstummen. Fang von vorn an.",
"Dong. The note hangs in the air.": "Dong. Der Ton hängt in der Luft.",
"The last note joins the others. A door swings open!": "Der letzte Ton fügt sich zu den anderen. Eine Tür schwingt auf!",
"You turn the wheel open. The water is now at mark %d.": "Du drehst das Rad auf. Das Wasser steht jetzt bei Marke %d.",
"You turn the wheel shut. The water is now at mark %d.": "Du drehst das Rad zu. Das Wasser steht jetzt bei Marke %d.",
"The light strikes the crystal, and it rings out bright!": "Das Licht trifft den Kristall, und er klingt hell auf!",
"You turn the mirror. The beam swings to a new wall.": "Du drehst den Spiegel. Der Strahl schwenkt an eine andere Wand.",
})

# Weather switch (area 3 item 1145)
T.update({
"Weather: %s": "Wetter: %s",
"Rain, fog and wind in the world. Off: always clear.": "Regen, Nebel und Wind in der Welt. Aus: immer klar.",
})

# Lake Line, Valley Coach and the Corvane ferry (area 3 items 1187-1191, 1289)
T.update({
"Lake Line": "Seelinie",
"Valley Coach": "Talkutsche",
"Ferry to Corvane": "Fähre nach Corvane",
"The coach rattles along the valley road to %s.": "Die Kutsche rumpelt die Talstraße entlang nach %s.",
"The mountain railway climbs through the clouds to %s.": "Die Bergbahn klettert durch die Wolken nach %s.",
"Conductor: No trains until the line is cleared. The guild will send word.": "Schaffnerin: Keine Züge, bis die Strecke frei ist. Die Gilde gibt Bescheid.",
"The ferry crosses the grey lake to %s.": "Die Fähre überquert den grauen See nach %s.",
"The boat rows across the lake to %s.": "Das Boot rudert über den See nach %s.",
"Driver: I only stop where you've been on foot first. Walk the valley, then we'll drive it.": "Kutscher: Ich halte nur dort, wo du schon zu Fuß warst. Lauf das Tal ab, dann fahren wir es.",
"Boatman: I only row to landings you've walked to yourself. Find them first, then I know the way.": "Bootsmann: Ich rudere nur zu Anlegern, die du selbst erreicht hast. Finde sie erst, dann kenne ich den Weg.",
})

# Survey share and minimap (area 3 items 1245, 1246, 1270-1272)
T.update({
"Minimap: %s": "Minikarte: %s",
"Outside only": "Nur draußen",
"Small map in the top corner. Outside only: hidden in houses and caves.": "Kleine Karte oben in der Ecke. Nur draußen: in Häusern und Höhlen ausgeblendet.",
})

# World map (area 3 items 1242-1248, 1273)
T.update({
"Map": "Karte",
"World map": "Weltkarte",
"Zoom: %dx": "Zoom: %dx",
"Here": "Hier",
"Marks (%d/%d)": "Markierungen (%d/%d)",
"Marks": "Markierungen",
"%s (not yet visited)": "%s (noch nicht besucht)",
"%s: seen from afar. Walk there to map it.": "%s: von Weitem gesehen. Geh hin, um es zu kartieren.",
"Add a mark here": "Hier markieren",
"Which symbol?": "Welches Zeichen?",
"Mark set.": "Markierung gesetzt.",
"Remove this mark?": "Diese Markierung entfernen?",
"Remove": "Entfernen",
"Star": "Stern",
"Cross": "Kreuz",
"Question": "Frage",
"Heart": "Herz",
"Arrow": "Pfeil",
"Hammer": "Hammer",
"Mapped: %d%%": "Kartiert: %d%%",
"Finds: %d/%d": "Funde: %d/%d",
"Time of day: %s": "Tageszeit: %s",
"Spirlings: %s": "Spirlings: %s",
"Clear": "Klar",
"Rain": "Regen",
"Fog": "Nebel",
"Wind": "Wind",
"Storm": "Sturm",
"Day": "Tag",
})
