# Bereich 1: Spirlings, Sammlung und Bonden

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 1 bis 444.

> **Auftrag für den umsetzenden Thread:** Ziel ist eine größere, eigenständige Spirling-Welt: neue Arten mit eigener Herkunft im Lore, klare Entfalten-Linien, Seltenheitsstufen, die Ersten Stimmen als legendäre Spirlings, der Nachhall als eigene Form von Nachwuchs, Ortsprägungen, ein reicheres Spirlog, ein tieferes Echo-Bonden sowie bessere Lager- und Team-Verwaltung mit Sammelzielen.
> Betroffen sind vor allem data/spirlings.json, data/encounters.json, scripts/core/SpirlingData.gd, scripts/core/Database.gd, scripts/core/DataValidator.gd, scripts/core/Collection.gd, scripts/core/GameState.gd, scripts/core/SaveManager.gd, scripts/battle/Spirling.gd, scripts/battle/BondEcho.gd, scripts/battle/BondCalc.gd, scripts/battle/presenter/BondMinigame.gd, scripts/ui/PauseMenu.gd sowie tools/art/gen_spirlings.py, docs/ASSET_LOG.md und tests/unit/.
> Fang mit dem Abschnitt "Datenmodell und Werkzeuge" an, denn alle anderen Punkte brauchen die neuen Felder, den Validator und die Speicher-Migration.
> Nicht in diesen Bereich gehören Kampfregeln, neue Gaben-Effekte und die Balance von Techniken (Bereich 2), der Shop und alles, was Geld kostet (Bereich 10), sowie Grafik-Epochen-Technik und Online-Funktionen; Spirlings werden nie getauscht oder verkauft.

### Datenmodell und Werkzeuge
1. [x] [P1] Ergänze in data/spirlings.json die Felder "rarity", "region", "role", "origin" und "line_id" für alle Arten und lies sie in SpirlingData.gd als typisierte Exporte ein.
2. [x] [P1] Erweitere DataValidator.gd so, dass jede Art ein gültiges "rarity" (common, uncommon, shy, ancient), eine bekannte "region" (veydal, corvane, ashmere, solenne) und eine nicht leere "origin"-Zeile hat.
3. [x] [P1] Ersetze das einzelne "evolves_to" durch eine Liste "unfold" mit Einträgen {"to", "rule", "value"}, damit eine Art mehrere Entfalten-Wege haben kann, und halte "evolves_to" beim Laden als Rückfall lesbar.
4. [x] [P1] Hebe SAVE_VERSION in SaveManager.gd auf 4 und schreibe eine Migration, die bei jedem gespeicherten Spirling die neuen Felder "temper", "variant", "origin_map", "met_ring", "met_day" und "lineage" mit Standardwerten füllt.
5. [x] [P1] Speichere das Temperament ab Speicherstand 4 fest im Spirling ("temper": id) statt es nur aus der uid zu lesen, und übernimm bei der Migration den bisher aus der uid berechneten Wert, damit sich kein altes Temperament ändert.
6. [x] [P1] Lege tests/unit/test_spirling_data.gd an, das für jede Art prüft: Summe der Grundwerte im Rahmen ihrer Seltenheit, gültige Elemente, gültige Gabe, Lerntabelle nur mit Techniken aus moves.json.
7. [x] [P1] Erweitere GameState.spirlog von {"seen", "bonded"} auf {"seen", "bonded", "first_map", "first_day", "variants", "prism_seen", "tempers"} mit Migration der alten Einträge.
8. [x] [P1] Füge im Validator eine Prüfung hinzu, dass jede Art in mindestens einer Begegnungstabelle, einer Geschichtsszene, einem Nachhall oder einem Entfalten-Weg erreichbar ist.
9. [P2] Schreibe tools/data/spirling_sheet.py, das aus spirlings.json eine Übersicht als CSV erzeugt (Nummer, Name, Elemente, Rolle, Seltenheit, Region, Gabe, Wertesumme) für Ali zum Durchsehen.
10. [P2] Ergänze tools/art/gen_spirlings.py um einen Platzhalter-Modus, der für jede neue Art ohne Grafik ein farbiges 56x56-Rechteck mit Element-Glyphe erzeugt und im Asset-Log vermerkt.
11. [P2] Lege eine Datei data/lines.json an, die jede Entfalten-Linie als Gruppe beschreibt (line_id, Stufen, Thema), damit Spirlog und Lager Linien zusammen zeigen können.
12. [P2] Füge Database.gd die Abfragen species_by_region(region), species_by_rarity(rarity) und line_members(line_id) hinzu, jeweils mit Test.
13. [P2] Ordne die Spirlog-Nummern regional: Veydal 1 bis 40, Corvane 41 bis 60, Ashmere 61 bis 75, Solenne 76 bis 90, die Ersten Stimmen 91 bis 96, und prüfe die Lücken im Validator.
14. [P2] Ergänze das Feld "role" um genau fünf Werte (vanguard, bulwark, weaver, striker, kindler) mit kurzer Beschreibung in docs/SPIRLINGS.md, damit neue Arten klar verteilt werden.
15. [P2] Schreibe docs/SPIRLINGS.md mit einer Tabelle aller Arten, ihrer Herkunft im Lore und ihrer Region als Quelle für Designer und Übersetzer.
16. [P2] Lege für jede neue Art einen Ruf-Eintrag in Cry.gd an (Tonhöhe, Länge, Wellenform), sodass kein Ruf doppelt klingt, und prüfe das in einem Test.
17. [P2] Ergänze tools/i18n um die Felder lore, habitat und origin aller neuen Arten, damit die deutsche Übersetzung im CI-Check mitläuft.
18. [P2] Lege Fixture-Speicherstände in tests/fixtures/ an (Version 3 mit 21 Arten, Version 4 mit Nachhall und Prägung), die bei jedem Testlauf geladen und erneut gespeichert werden.
19. [P3] Baue ein Debug-Menü "Spirling-Galerie", das jede Art mit allen Prägungen, Prisma-Farbe und Entfalten-Stufen nebeneinander zeigt.
20. [P3] Schreibe einen Ähnlichkeits-Check in tools/art/, der die Umrisse neuer Sprites mit allen eigenen Sprites vergleicht und Paare über 85 Prozent Pixel-Überdeckung meldet.
21. [P3] Ergänze im Validator eine Warnung, wenn zwei Arten dieselben zwei Elemente und dieselbe Rolle haben.
22. [P3] Gib jeder Art ein Feld "size_class" (small, medium, large) für spätere Darstellung im Lager und im Fotomodus.
23. [P3] Lege ein Feld "cry_motif" pro Art an, das die festen ersten Zeichen ihres Echo-Rufs speichert (siehe Abschnitt Echo-Bonden).
24. [P3] Erzeuge mit einem Skript eine Liste aller Spirling-Namen und lass sie gegen die Sperrliste in tools/ip_check.sh laufen, bevor ein Name in die Daten kommt.
25. [P3] Ergänze BalanceSim.gd um einen Modus, der nur neue Arten gegeneinander antreten lässt und die Siegquote pro Rolle ausgibt.

### Neue Spirlings in Veydal
26. [P1] Füge die Linie Blotling (Tide/Umbra, Rolle weaver) und Scrivane hinzu: ein Tintenklecks, der in Mirelas alten Tintenfässern im Leuchtturm lebt und Karten nachzeichnet, die er nie gesehen hat.
27. [P1] Füge die Linie Hushkin (Umbra, Rolle bulwark) und Silentra hinzu: ein Spirling, der aus der Stille selbst entstand, keinen Ruf hat und sich nur durch leuchtende Zeichen verständigt.
28. [P1] Füge die Linie Paddlewisp (Tide/Gale, Rolle striker) und Ferrowyn hinzu: ein Wirbel, der unter Aldos Fähre wohnt und Boote bei Sturm sanft zum Steg schiebt.
29. [P1] Füge die dreistufige Linie Talusk, Talusgard und Cairnhold (Stone, Rolle bulwark) hinzu: ein Haufen Geröll mit einem Auge aus Krähenkamm, der mit jeder Stufe einen Wegstein mehr auf sich stapelt.
30. [P1] Füge die Linie Fluting (Gale/Bloom, Rolle kindler) und Marshfife hinzu: ein hohles Schilfrohr aus der Salzmarsch, das den Wind als Melodie spielt und Wanderer heimführt.
31. [P1] Füge Glasstarn (Tide/Lumen, ohne Entfalten, Seltenheit shy) hinzu: ein stilles Stück Bergsee am Krähenkamm, das den Himmel spiegelt und nur bei Windstille erscheint.
32. [P1] Füge Lanternel (Lumen/Gale, ohne Entfalten, Seltenheit uncommon) hinzu: ein kleines Lampenwesen, das den Lichtern des Leuchtturms folgt und seit dem ersten Sturm in Brindlewick bleibt.
33. [P1] Füge die Linie Seamlet (Volt/Umbra, Rolle weaver) und Mendlace hinzu: ein Funke, der am Rand der Risse lebt und versucht, sie mit Lichtfäden zuzunähen.
34. [P1] Füge die Linie Croziel (Bloom, Rolle kindler) und Frondmere hinzu: ein eingerollter Farnwedel aus der Farnstiege, dessen Entfalten im Spiel wörtlich als Aufrollen gezeigt wird.
35. [P1] Füge die Linie Brinelet (Tide/Stone, Rolle vanguard) und Saltspire hinzu: ein Salzkristall aus den Pfannen der Salzmarsch, der in trockenen Sommern zu einer Säule wächst.
36. [P1] Verteile die zehn neuen Veydal-Linien so auf die Karten, dass Farnstiege, Krähenkamm, Salzmarsch, Dornengrat und Murk Hollow je mindestens zwei neue Arten bekommen, und trage sie in data/encounters.json ein.
37. [P1] Stelle sicher, dass mit den neuen Arten jedes der 8 Elemente in Veydal von mindestens 4 Arten getragen wird, und prüfe das in test_content.gd.
38. [P2] Platziere Blotling nicht in einer Begegnungstabelle, sondern als Geschichtsfund im Leuchtturm, der erscheint, sobald das Kartenbuch drei Seiten hat.
39. [P2] Lass Hushkin nur in den Riss-Kratern vor dem Flicken erscheinen und nach dem Flicken gar nicht mehr, außer nachts am geflickten Riss mit Gewicht 5.
40. [P2] Lass Paddlewisp nur auf Steg-Feldern (+) in Brindlewick und an der Fähre erscheinen, mit eigener Begegnungstabelle "ferry_pier" und Rate 0,08.
41. [P2] Gib Talusk die Geröll-Felder (:) am Krähenkamm mit Gewicht 30 und Ring 6 bis 9, damit er der erste neue Stone-Spirling ist.
42. [P2] Lass Fluting in den Schilf-Feldern (%) der Salzmarsch erscheinen und häufiger in der Dämmerung über DayCycle (Faktor 1,5).
43. [P2] Lass Glasstarn nur am Bergsee des Krähenkamms erscheinen, wenn keine Böen-Wetterlage aktiv ist, mit Gewicht 4.
44. [P2] Gib Lanternel nach dem zweiten geflickten Riss als Geschenk eines Laternenträgers in Brindlewick, einmal pro Spielstand, Ring 15.
45. [P2] Lass Seamlet nur in den Riss-Kratern mit Gewicht 10 und erst nach dem Flicken mit Gewicht 25 auftauchen, weil er dort die Naht bewacht.
46. [P2] Gib Croziel die Farn-Felder (,) der Farnstiege mit Gewicht 25 und Ring 3 bis 5 als frühen zweiten Bloom-Spirling neben Mossling.
47. [P2] Gib Brinelet die Salzpfannen der Salzmarsch mit Gewicht 20 und lass ihn bei Regen-Wetter nicht erscheinen.
48. [P2] Schreibe für jede neue Veydal-Art zwei Lore-Sätze im Stil der bestehenden Einträge (Beobachtung plus Brauch der Dorfleute) in data/spirlings.json.
49. [P2] Zeichne für jede neue Veydal-Art ein Era-I-Sprite (56x56, 4 Tinten auf Pergament) mit tools/art/gen_spirlings.py und vermerke jede Datei in docs/ASSET_LOG.md.
50. [P2] Lege für jede neue Veydal-Art die Wertesumme nach Rolle und Stufe fest: Grundstufe 300 bis 330, zweite Stufe 400 bis 440, Endstufe 490 bis 510, Einzelarten 420 bis 460.
51. [P2] Gib jeder neuen Veydal-Art eine Lerntabelle aus bestehenden Techniken in moves.json, mit mindestens einer Technik des eigenen Elements bis Ring 5.
52. [P2] Lass Aldo und Kestra in neuen Dialogzeilen je eine der neuen Arten erwähnen (Paddlewisp bei Aldo, Seamlet bei Kestra), damit die Arten in der Geschichte verankert sind.
53. [P3] Lass Kestra nach dem Krähenkamm-Duell Seamlet in ihr festes Team aufnehmen, passend zu ihrer Haltung, dass Risse Neues bringen.
54. [P3] Füge für Silentra eine kleine Nebenquest in Murk Hollow hinzu, in der der Spieler einen stummen Hushkin dreimal besucht, bevor er ihm folgt.
55. [P3] Lass Saltspire in der Salzmarsch an einem festen Ort als stehende Säule im Overworld sichtbar sein, die man ansprechen muss, um den Kampf zu starten.
56. [P3] Zeige Lanternel im Leuchtturm als kleines Licht an der Lampe, sobald der Spieler eines gebondet hat.
57. [P3] Lass Marshfife bei Nacht in der Salzmarsch eine kurze, eigene Melodie spielen, die Sound.gd als Umgebungston abspielt, wenn einer im Team ist.
58. [P3] Lass Cairnhold im Krähenkamm als Wegweiser-Steinmann an Kreuzungen erscheinen, der eine Karteninfo gibt, wenn ein Cairnhold im Team ist.
59. [P3] Gib Frondmere eine Fotomodus-Pose, in der sich die Wedel öffnen.
60. [P3] Schreibe eine Spirlog-Fußnote für Scrivane, dass seine Tintenlinien Mirelas Handschrift ähneln, als leisen Hinweis auf Akt II.

### Neue Spirlings für Corvane, Ashmere und Solenne
61. [P1] Lege für Corvane (Era II, Flussdelta mit Mühlen und Regen) acht Linien fest und trage sie mit "region": "corvane" und Platzhalter-Sprites in die Daten ein, auch wenn die Region noch nicht spielbar ist.
62. [P1] Lege für Ashmere (Era III, Aschemoor mit Glashütten und Kupferstichen) sechs Linien fest und trage sie mit "region": "ashmere" und Platzhalter-Sprites ein.
63. [P1] Lege für Solenne (Era IV, sonnige Hochebene mit Sternwarten und Salzseen) sechs Linien fest und trage sie mit "region": "solenne" und Platzhalter-Sprites ein.
64. [P1] Blende Arten aus noch nicht spielbaren Regionen im Spirlog und in Sammelzielen aus (Filter über GameState-Flag region_open_<id>), damit die Zahl "alle Arten" erreichbar bleibt.
65. [P2] Corvane: Füge die Linie Drizzlet (Tide, Rolle striker) und Pluvane hinzu, ein Regentropfen, der nie den Boden berührt und in den Dachrinnen der Mühlenstadt wohnt.
66. [P2] Corvane: Füge die Linie Millgrit (Stone/Gale, Rolle bulwark) und Grindsail hinzu, ein Sandkorn aus den Mahlsteinen, das mit den Windmühlenflügeln wächst.
67. [P2] Corvane: Füge die dreistufige Linie Pigmentil, Chromaree und Washveil hinzu (Bloom/Lumen, Rolle weaver), ein Farbfleck, dessen Farben ineinander verlaufen wie Aquarell.
68. [P2] Corvane: Füge die Linie Sluicelet (Tide/Volt, Rolle vanguard) und Sluicegeist hinzu, ein Wesen der Kanalschleusen, das die Tore mit kleinen Stromstößen öffnet.
69. [P2] Corvane: Füge die Linie Haarling (Gale/Umbra, Rolle weaver) und Haarwraith hinzu, ein Fetzen Seenebel, der Laternen verschluckt und am Morgen wieder freigibt.
70. [P2] Corvane: Füge die Linie Steamlet (Ember/Tide, Rolle kindler) und Boilercoil hinzu, ein Dampfwölkchen aus den Teestuben, das nur warm bleibt, solange jemand redet.
71. [P2] Corvane: Füge die Linie Moorspool (Volt/Bloom, Rolle striker) und Loomvolt hinzu, eine Garnspule voller Funken aus dem Weberdorf.
72. [P2] Corvane: Füge Bellbuoy (Tide/Volt, ohne Entfalten, Seltenheit shy) hinzu, eine Hafenglocke, die im Nebel von selbst läutet und Fähren warnt.
73. [P2] Ashmere: Füge die Linie Etchling (Ember/Umbra, Rolle striker) und Burinox hinzu, ein Wesen in Kupferplatten, das mit Säure Linien in das Metall zieht.
74. [P2] Ashmere: Füge die Linie Vitrel (Lumen/Stone, Rolle bulwark) und Vitrarch hinzu, eine Glasperle aus den Hütten, die Licht in alle Richtungen bricht.
75. [P2] Ashmere: Füge die Linie Ashsprig (Bloom/Ember, Rolle kindler) und Cindergrove hinzu, der erste Spross nach einem Moorbrand, der Asche in Erde verwandelt.
76. [P2] Ashmere: Füge die Linie Rustlet (Stone/Volt, Rolle vanguard) und Corrodon hinzu, eine Rostflocke von verlassenen Schienen.
77. [P2] Ashmere: Füge die Linie Hollowbell (Gale/Stone, Rolle weaver) und Carillith hinzu, eine Glocke aus einem eingestürzten Turm, die nur im Wind klingt.
78. [P2] Ashmere: Füge die Linie Smutch (Umbra, Rolle striker) und Sootmantle hinzu, ein Rußwesen aus den Schornsteinen, das Funken vor dem Wind schützt.
79. [P2] Solenne: Füge die Linie Heliot (Lumen/Ember, Rolle striker) und Signaroth hinzu, ein Spiegelwesen, das Lichtzeichen über die Hochebene schickt.
80. [P2] Solenne: Füge die Linie Gnomonel (Stone/Lumen, Rolle bulwark) und Horologue hinzu, der Schattenzeiger einer Sonnenuhr, der die Stunden zählt.
81. [P2] Solenne: Füge die Linie Updrael (Gale/Ember, Rolle vanguard) und Thermarch hinzu, ein warmer Aufwind über den Salzseen, der Staub zu Säulen dreht.
82. [P2] Solenne: Füge die Linie Shimmerlo (Tide/Lumen, Rolle weaver) und Fatamor hinzu, eine Luftspiegelung, die Wasser zeigt, wo keines ist.
83. [P3] Solenne: Füge die Linie Astrolet (Umbra/Lumen, Rolle kindler) und Orrerix hinzu, ein Sternmodell aus der Sternwarte, das sich nachts von selbst dreht.
84. [P3] Solenne: Füge die Linie Siroccub (Gale/Stone, Rolle striker) und Siroccant hinzu, eine wandernde Sanddüne, die über Nacht ihren Platz wechselt.
85. [P3] Lege für jede Corvane-Art zusätzlich eine Tag- und eine Nacht-Palette fest, passend zur Era-II-Regel "4 Farben pro Sprite, Tag und Nacht".
86. [P3] Zeichne die Corvane-Sprites in 56x56 mit Era-II-Wash-Palette und lege sie unter art/era2/spirlings/ ab, mit Rückfall auf Platzhalter.
87. [P3] Zeichne die Ashmere-Sprites in 64x64 mit 16 Farben unter art/era3/spirlings/.
88. [P3] Zeichne die Solenne-Sprites in 96x96 mit 6 Leerlauf-Bildern unter art/era4/spirlings/.
89. [P3] Gib jeder Region einen Leit-Spirling für Plakat und Ladebildschirm: Pigmentil für Corvane, Etchling für Ashmere, Heliot für Solenne.
90. [P3] Lege für jede neue Region drei Begegnungsgründe fest (Corvane: Kanalufer, Mühlenwiese, Nebelkai; Ashmere: Aschefeld, Glashalde, Kupfergrube; Solenne: Salzkruste, Sternhang, Dünengras).
91. [P3] Gib den neuen Regionen ihre Arten so, dass jede Region mindestens eine Art jedes Elements hat und keine Region nur alte Veydal-Arten zeigt.
92. [P3] Lass einige Veydal-Arten in neuen Regionen weiter vorkommen (je Region höchstens 6), damit Sammlungen fortgesetzt werden statt neu zu beginnen.
93. [P3] Schreibe für jede neue Region einen Absatz "Spirlings in <Region>" in docs/WORLD.md mit Thema und Begegnungsgründen.
94. [P3] Lege für jede neue Art Größe ("height") und Lebensraum ("habitat") im Stil der Veydal-Einträge fest.
95. [P3] Gib jeder neuen Regionsart eine Lerntabelle aus bestehenden Techniken und markiere Lücken, für die Bereich 2 neue Techniken liefern soll, in docs/SPIRLINGS.md.
96. [P3] Lass für jede Region eine Art erst nach dem Flicken des ersten Risses dort erscheinen, als Zeichen, dass die Stille weicht.
97. [P3] Lege fest, dass Bellbuoy, Glasstarn und Lanternel als Einzelarten ohne Entfalten im Spirlog ein eigenes Zeichen "Ganz" tragen.
98. [P3] Lass in jeder neuen Region einen Wanderer mit einer Ortsart im Team auftreten, damit Spieler die Art vor dem Bonden im Kampf sehen.
99. [P3] Plane in docs/SPIRLINGS.md für jede neue Region einen Platz für zwei spätere Arten frei, ohne sie schon festzulegen.

### Entfalten-Linien
100. [x] [P1] Setze die neue Regel "rule": "ring" für alle bisherigen Ring-Entfaltungen um und prüfe, dass alle 21 bestehenden Arten genau wie vorher entfalten können.
101. [P1] Füge die Entfalten-Regel "map_pages" hinzu (Kartenbuch hat mindestens N Seiten) und nutze sie für Blotling zu Scrivane bei 6 Seiten.
102. [P1] Füge die Entfalten-Regel "mended" hinzu (bestimmter Riss geflickt) und nutze sie für Seamlet zu Mendlace nach dem Flicken des Ascheriss oder Flutriss, je nachdem, wo er gebondet wurde.
103. [P1] Füge die Entfalten-Regel "time" hinzu (Tageszeit aus DayCycle an einem Ort) und nutze sie für Fluting zu Marshfife in der Dämmerung in der Salzmarsch.
104. [P1] Füge die Entfalten-Regel "echo_streak" hinzu (N vollständig richtige Echo-Rufe, während der Spirling im Team ist) und nutze sie für Hushkin zu Silentra bei 10.
105. [x] [P1] Zeige im Team-Menü bei "Entfalten" für jede Regel einen klaren Hinweistext ("Braucht: Dämmerung in der Salzmarsch"), sobald die Art gebondet ist.
106. [x] [P1] Erweitere can_unfurl() in Spirling.gd auf die neue "unfold"-Liste und decke jede Regel mit einem eigenen Test in tests/unit/test_unfold.gd ab.
107. [P2] Füge die Entfalten-Regel "keepsake_at" hinzu (Andenken tragen an einem bestimmten Ort) und nutze sie für Brinelet zu Saltspire mit dem Andenken Tide Shell in der Salzmarsch.
108. [P2] Füge die Entfalten-Regel "steps" hinzu (neu betretene Felder seit dem Bonden) und nutze sie für Paddlewisp zu Ferrowyn bei 800 Feldern.
109. [P2] Füge die Entfalten-Regel "spring" hinzu (an einer Quelle rasten) und nutze sie für Croziel zu Frondmere ab Ring 16 beim Rasten an einer Quelle.
110. [P2] Lege für die Talusk-Linie zwei Ring-Stufen fest (Talusgard ab Ring 15, Cairnhold ab Ring 33), die beide nicht auf 16, 32, 34 oder 36 fallen.
111. [P2] Erlaube verzweigte Linien: Pigmentil kann tagsüber zu Chromaree (Bloom/Lumen) und nachts zu einer Schattenform entfalten, beide in data/lines.json beschrieben.
112. [P2] Gib jeder neuen Linie einen Entfalten-Satz für die Overworld-Meldung, der zur Herkunft passt ("Talusk stapelt einen Stein mehr.").
113. [P2] Zeige beim Entfalten eine kurze eigene Abfolge (Umriss leuchtet in Tinte, Sprite wechselt, ein Ton aus Cry.gd steigt), ohne Bildschirmblitz.
114. [P2] Lass Spirlings nach dem Entfalten ihre Gabe der neuen Stufe übernehmen und zeige den Wechsel im Team-Menü, wenn sich die Gabe ändert.
115. [P2] Speichere im Spirling eine Liste "unfold_history" mit Art und Tag jedes Entfaltens für das Spirlog und die Andenken-Zuordnung.
116. [P2] Zeige im Spirlog bei jeder Art die ganze Linie mit Regeln, aber Regeln unbekannter Stufen nur als "???" bis die Stufe gesehen wurde.
117. [P2] Prüfe im Validator, dass jede Entfalten-Linie höchstens drei Stufen hat und keine Schleifen bildet.
118. [P2] Lege fest, dass Einwärts-Falten ("Furl back") auch bei Regeln "map_pages", "mended" und "time" ohne Bedingung möglich bleibt, und teste es.
119. [P2] Lass die Overworld den Entfalten-Hinweis für neue Regeln genau einmal pro Spirling und Stufe zeigen, über die bestehende Flagge unfurl_hint_<uid>_<species>.
120. [P2] Gib der Lumenewt- und Glimmerax-Linie je eine zweite Wahl-Regel, sodass jede bestehende Endform auch auf einem zweiten, ortsbezogenen Weg erreichbar ist.
121. [P3] Füge die Regel "partner_rest" hinzu (zwei bestimmte Arten rasten zusammen an einer Quelle) und nutze sie nur für eine einzige Linie in Ashmere.
122. [P3] Füge die Regel "festival" hinzu (Entfalten nur während eines Fests aus Season.gd) für Lanternel-Leuchten als kosmetische Form ohne Wertänderung.
123. [P3] Lege für jede Endform eine Fotomodus-Pose fest, die nur nach dem Entfalten verfügbar ist.
124. [P3] Lass Kestra in einem Dialog nach dem ersten Entfalten mit neuer Regel erklären, dass Spirlings auf Orte antworten, nicht nur auf Ringe.
125. [P3] Zeige im Team-Menü einen kleinen Zeiger, wenn ein Spirling eine Entfalten-Regel erfüllt, und blende ihn aus, wenn der Spieler "Später" wählt.
126. [P3] Lass eine entfaltete Form beim Einwärts-Falten eine Erinnerung im Spirlog hinterlassen ("Hat schon einmal entfaltet"), damit Sammelziele dies zählen können.
127. [P3] Erlaube eine Einstellung "Entfalten-Hinweise aus", die nur die Overworld-Meldung abschaltet, nicht die Option im Team-Menü.
128. [P3] Schreibe einen Test, dass keine neue Ring-Schwelle auf 16, 32, 34 oder 36 fällt, als Erweiterung von test_originality.gd.
129. [P3] Plane für Akt II die Regel "rift_echo", bei der eine Art nur in der Nähe des dritten Risses im Norden entfaltet, und vermerke sie in docs/SPIRLINGS.md.

### Seltenheitsstufen
130. [x] [P1] Lege vier Seltenheitsstufen fest (common, uncommon, shy, ancient) und ordne jede der 21 bestehenden und aller neuen Arten genau einer zu.
131. [x] [P1] Binde die Seltenheit an Spannen für bond_rate: common 0,45 bis 0,55, uncommon 0,25 bis 0,35, shy 0,08 bis 0,15, ancient 0,03 bis 0,05, geprüft im Validator.
132. [x] [P1] Binde die Seltenheit an Gewichtsspannen in data/encounters.json: common 25 bis 45, uncommon 10 bis 24, shy 2 bis 9, und prüfe das in WorldValidator.gd.
133. [x] [P1] Lass ancient-Arten nie in Zufallstabellen auftauchen, nur als feste Begegnungen, und prüfe das im Validator.
134. [P2] Lass shy-Arten nur dann erscheinen, wenn eine Ortsbedingung erfüllt ist (Tageszeit, Wetter oder geflickter Riss), mit dem Feld "when" pro Spawn-Eintrag.
135. [P2] Gib shy-Arten beim Auftauchen eine eigene Einleitung im Kampf ("Etwas zögert im Schilf ..."), ohne Zahl oder Chancenhinweis.
136. [P2] Lass shy-Arten im Kampf nach drei Runden ohne Bondversuch zurück in ihren Grund gehen, mit dem bestehenden Rückzug-Ereignis.
137. [P2] Gib jeder Region mindestens drei shy-Arten, damit Suchen in jeder Region lohnt.
138. [P2] Lege fest, dass Prisma (1/256) unabhängig von der Seltenheit bleibt und nie die Werte ändert, als Kommentar in Spirling.gd und Test.
139. [P2] Gib ancient-Arten im Kampf einen eigenen Hintergrundton in Sound.gd, der nur bei ihnen spielt.
140. [P2] Lass die Wachstum-Ausbeute (xp_yield) nach Seltenheit steigen: common 50, uncommon 70, shy 95, ancient 150.
141. [P2] Zeige im Lager auf der Detailkarte eines Spirlings die Seltenheitsstufe als Wort ("scheu"), nicht als Sternzahl.
142. [P2] Gib uncommon-Arten in jeder Begegnungstabelle höchstens 30 Prozent des Gesamtgewichts, geprüft im Validator.
143. [P2] Ergänze die Seltenheit in docs/SPIRLINGS.md mit einer Erklärung, warum Seltenheit nie Stärke bedeutet.
144. [P3] Lass shy-Arten im Overworld eine kleine Fährte (aufgewirbeltes Gras) zeigen, wenn sie in einem Grund möglich sind, ohne ihre Art zu verraten.
145. [P3] Lass Spieler mit der Storm Lantern nachts shy-Arten in Murk Hollow etwas häufiger treffen (Gewicht mal 1,5).
146. [P3] Gib jeder shy-Art einen Hinweissatz eines Dorfbewohners ("Bei Windstille spiegelt sich am Bergsee etwas"), damit Seltenes gefunden werden kann.
147. [P3] Lass die Begegnung mit einer shy-Art einen eigenen Eintrag im Kartenbuch-Tagebuch erzeugen.
148. [P3] Erlaube, dass shy-Arten über den bestehenden Fund des Tages (DailyFind.gd) höchstens einmal pro Woche vorkommen.
149. [P3] Prüfe mit BalanceSim, dass ein Spieler alle common- und uncommon-Arten Veydals in 6 Stunden Spielzeit sehen kann.
150. [P3] Lass ancient-Arten im Kampf ihre Seltenheit nicht durch Werte, sondern durch die Musik und einen Ruf mit fünf statt vier Zeichen zeigen.
151. [P3] Schreibe einen Tipp in Tips.gd, der erklärt, dass scheue Spirlings Bedingungen brauchen.

### Legendäre Spirlings: Die Ersten Stimmen
152. [P1] Lege das Lore der Ersten Stimmen in docs/WORLD.md fest: sechs uralte Spirlings, deren Gesang das Land einst zusammenhielt, und deren Schweigen die Stille ausgelöst hat.
153. [P1] Füge Velahra (Lumen/Tide, ancient) hinzu, die Erste Stimme Veydals, die als Licht unter dem See vor dem Leuchtturm schläft und Mirela zuletzt gesehen hat.
154. [P1] Mach Velahra nach dem Finale im Lampenraum als feste, einmalige Begegnung am Seeufer erreichbar, mit dem Ring 40 und einem eigenen Kampfbildschirm-Hintergrund.
155. [P1] Lass eine besiegte oder abgebrochene Begegnung mit einer Ersten Stimme nach dem nächsten Rasten an derselben Stelle wiederkehren, damit sie nie verloren geht.
156. [P2] Füge Morrowtide (Tide/Gale, ancient) hinzu, die Erste Stimme Corvanes, die als Flussmündung singt und Mühlräder antreibt, für Akt II.
157. [P2] Füge Cindrelith (Ember/Stone, ancient) hinzu, die Erste Stimme Ashmeres, ein Glutkern unter dem Moor, der die Glashütten einst wärmte, für Akt III.
158. [P2] Füge Aurelune (Lumen/Umbra, ancient) hinzu, die Erste Stimme Solennes, die Tag und Nacht teilt und in der Sternwarte wohnt, für Akt IV.
159. [P2] Füge Nullchord (Umbra/Volt, ancient) hinzu, die Stille selbst als Wesen, der letzte Gegner nach allen Akten, der bondbar wird, wenn alle anderen Ersten Stimmen im Spirlog als gebondet stehen.
160. [P2] Füge Wayrose (Stone/Gale, ancient) hinzu, Mirelas eigener Spirling in Form einer Windrose, der nur in der Geschichte zurückkehrt und nicht in Begegnungen vorkommt.
161. [P2] Gib jeder Ersten Stimme einen Echo-Ruf mit fünf Zeichen und einer zweiten Phase, in der sie drei weitere Zeichen ruft, wenn die ersten fünf richtig waren.
162. [P2] Lege fest, dass jede Erste Stimme pro Spielstand nur einmal gebondet werden kann und danach nicht mehr erscheint.
163. [P2] Lass jede Erste Stimme eine eigene Gabe aus dem Bestand oder aus Bereich 2 tragen und vermerke die Zuordnung in docs/SPIRLINGS.md.
164. [P2] Gib Ersten Stimmen eine Wertesumme von 560 bis 580, nie höher, und prüfe das im Validator.
165. [P2] Sperre Erste Stimmen in Online-Echo-Teams und Ranglisten-Herausforderungen über ein Feld "ranked_ok": false.
166. [P2] Schreibe für jede Erste Stimme drei Lore-Absätze, die im Spirlog nach und nach erscheinen (gesehen, gebondet, zehn Kämpfe im Team).
167. [P2] Gib jeder Ersten Stimme eine eigene Musik in data/music.json mit eigenem Titel.
168. [P2] Lass die Begegnung mit Velahra erst starten, wenn der Spieler am Seeufer drei Laternen in einer bestimmten Reihenfolge entzündet, als Rätsel ohne Kampfbezug.
169. [P3] Lass Aldo nach dem Bonden von Velahra eine neue Dialogzeile über Mirelas letzte Fahrt sagen.
170. [P3] Gib Wayrose eine Szene im Akt-II-Finale, in der sie Mirela zurück zum Leuchtturm führt, und füge sie danach dem Team hinzu, wenn Platz ist, sonst dem Lager.
171. [P3] Lass Nullchord im letzten Kampf keine Technik nutzen, die Stille verursacht, sondern nur die Zeichen der Spieler-Spirlings stören, als Bezug zum Lore.
172. [P3] Gib jeder Ersten Stimme eine Prisma-Form, die aber nur in einem Neu-Plus-Spielstand erscheinen kann.
173. [P3] Lass im Spirlog die Seite der Ersten Stimmen als eigenes Kapitel "Die Ersten Stimmen" mit Hintergrund aus Tinte erscheinen.
174. [P3] Lege fest, dass Erste Stimmen nicht im Nachhall erzeugt werden können, und prüfe das im Test.
175. [P3] Gib Ersten Stimmen eine eigene Rahmenfarbe auf der Lagerkarte.
176. [P3] Zeige nach dem Bonden einer Ersten Stimme eine kurze Szene, in der eine Karte im Kartenbuch neue Farbe bekommt.
177. [P3] Lass Kestra nach dem Bonden der ersten Ersten Stimme ihre Haltung zu Rissen in einem Gespräch ändern.
178. [P3] Schreibe für jede Erste Stimme einen Satz in Mirelas Kartenbuch-Seiten, der auf sie hinweist, bevor man sie trifft.
179. [P3] Lass Erste Stimmen nicht entfalten, aber gib jeder eine zweite Erscheinung (wach und schlafend), zwischen der man im Team-Menü wechseln kann.
180. [P3] Prüfe die sechs Namen und Umrisse gegen die bekannten legendären Wesen großer Monster-Reihen und vermerke das Ergebnis in docs/IP_HYGIENE.md.
181. [P3] Lass Erste Stimmen nur im Story-Kampf die Formation der Mehrfachkämpfe nutzen und nie als Zufallsbegegnung.
182. [P3] Gib jeder Ersten Stimme einen Weltziel-Hinweis im Kartenbuch, der nur zeigt, in welcher Region sie wartet.

### Nachhall: Aufzucht und Hallkind
183. [P1] Lege die eigene Nachwuchs-Mechanik "Nachhall" fest: zwei gebondete Spirlings singen an einer Echo-Quelle zusammen, und aus ihrem gemeinsamen Ruf entsteht ein schwebender Hallkern.
184. [P1] Mach jede Heilquelle nach dem zweiten geflickten Riss zu einer Echo-Quelle mit dem Menüpunkt "Gemeinsam singen", der zwei Spirlings aus Team oder Lager wählen lässt.
185. [P1] Lass den Hallkern nach 600 neu betretenen Feldern oder 30 gewonnenen Kämpfen, je nachdem was zuerst eintritt, zu einem Hallkind der Grundstufe auf Ring 1 erwachen.
186. [P1] Prüfe die Beschreibung des Nachhalls mit dem Rechts-Thread und halte in docs/IP_HYGIENE.md fest, dass keine fremden Begriffe, Gegenstände oder Abläufe übernommen werden.
187. [P2] Lege fest, dass zwei Spirlings nur singen können, wenn sie ein gemeinsames Element oder dieselbe Rolle haben, geprüft in einer reinen Funktion Nachhall.can_pair().
188. [P2] Lass den Spieler wählen, welcher der beiden Eltern die Art des Hallkinds bestimmt, statt es zu würfeln.
189. [P2] Berechne die Spark-Werte des Hallkinds pro Wert als höheren Elternwert minus eine Zufallszahl von 0 bis 3, mindestens 0.
190. [P2] Lass das Hallkind das Temperament des Elternteils erben, der die Art bestimmt, außer der andere Elternteil trägt das Andenken "Stimmgabel", dann dessen Temperament.
191. [P2] Gib dem Hallkind eine Technik aus der Liste eines Elternteils mit, wenn sie in seiner eigenen Lerntabelle vorkommt, sonst die Grundtechniken.
192. [P2] Speichere im Hallkind das Feld "lineage" mit den uids und Arten beider Eltern für das Spirlog.
193. [P2] Begrenze das Singen an einer Echo-Quelle auf einmal pro echtem Tag pro Elternpaar, über die Uhr des Servers.
194. [P2] Lass höchstens drei Hallkerne gleichzeitig im Team-Menü schweben, sichtbar als eigene Zeile "Hallkerne".
195. [P2] Zeige am Hallkern nur die Elemente als Schimmerfarbe, nicht die Art, bis er erwacht.
196. [P2] Gib dem Hallkind beim Erwachen eine Prisma-Chance von 1/256 wie in der Wildnis, ohne Steigerung.
197. [P2] Lass ein Hallkind die Herkunft "Nachhall an <Quelle>" tragen, sichtbar auf der Lagerkarte.
198. [P2] Erlaube den Nachhall nicht mit Spirlings, die von der Geschichte geschenkt wurden und als einzigartig markiert sind (Velahra, Wayrose, Lanternel).
199. [P2] Schreibe die Regeln in eine reine Datei scripts/core/Nachhall.gd ohne Nodes und teste sie in tests/unit/test_nachhall.gd.
200. [P2] Lass die Eltern nach dem Singen ganz normal im Team bleiben, ohne Pause, ohne Wartezeit an einem Ort.
201. [P2] Gib dem Erwachen eine kurze Szene: der Hallkern spielt den gemeinsamen Ruf der Eltern rückwärts, dann erscheint das Hallkind.
202. [P3] Lass Hallkinder einer Art in einer anderen Region die Ortsprägung dieser Region annehmen, wenn der Hallkern dort erwacht.
203. [P3] Gib Hallkindern ein kleines Zeichen (zwei Wellenlinien) auf der Lagerkarte, damit sie von Wild-Bonds unterscheidbar sind.
204. [P3] Lass einen Bewohner an jeder Echo-Quelle sagen, ob ein Paar "gut zusammen klingt", als Text ohne Zahl.
205. [P3] Lass Paare mit gleichem Temperament eine kleine Melodie-Variation spielen, rein kosmetisch.
206. [P3] Gib den Hallkernen eine Grafik pro Element-Kombination (8 Grundfarben, gemischt bei zwei Elementen).
207. [P3] Lass ein Hallkind seinen Ruf in einer Mischung beider Eltern-Rufe aus Cry.gd haben.
208. [P3] Lege fest, dass der Nachhall in der Schwierigkeit Rift-Born erlaubt ist, aber nicht im Eiserner-Eid-Modus.
209. [P3] Zeige im Spirlog eine Seite "Stammbaum" für Hallkinder mit bis zu drei Generationen.
210. [P3] Erlaube, einen Hallkern an der Quelle wieder freizugeben, ohne Strafe, mit Bestätigung.
211. [P3] Lass Kestra in Akt II erklären, dass der Nachhall die alte Art ist, wie Spirlings die Stille überstehen.
212. [P3] Gib dem Hallkind zusätzlich zur Herkunft den Tag des Erwachens auf der Lagerkarte.
213. [P3] Lass Hallkinder, deren Eltern beide Prisma sind, keine höhere Prisma-Chance bekommen, und halte das im Test fest.
214. [P3] Lass Hallkerne in Online-Geschenken nicht verschickbar sein, passend zur Regel, dass Spirlings nie getauscht werden.
215. [P3] Gib dem Nachhall eine Statistik in den Aufzeichnungen (Records): gesungene Paare, erwachte Hallkinder.
216. [P3] Plane einen späteren Ort "Halldom" in Corvane, an dem Hallkerne doppelt so schnell erwachen, als Akt-II-Inhalt.
217. [P3] Lass den Spieler einem Hallkind beim Erwachen gleich einen Spitznamen geben, mit dem bestehenden NameKeyboard.

### Ortsprägungen (regionale Varianten)
218. [P1] Lege die Mechanik "Ortsprägung" fest: eine Veydal-Art, die lange in einer anderen Region lebt, zeigt dort eine eigene Form mit geändertem Element und neuer Farbe, gespeichert im Feld "variant".
219. [P1] Lege in data/spirlings.json ein Feld "variants" pro Art an ({"region", "elements", "palette", "lore", "trait"}), das ohne neue Art-Nummer auskommt.
220. [P2] Gib Kindlop eine Corvane-Prägung (Ember/Tide), die im Regen glimmt statt zu erlöschen.
221. [P2] Gib Mossling eine Ashmere-Prägung (Bloom/Ember), deren Moos auf warmer Asche wächst.
222. [P2] Gib Zephlet eine Solenne-Prägung (Gale/Lumen), die im Hitzeflimmern sichtbar wird.
223. [P2] Gib Shalebat eine Corvane-Prägung (Stone/Tide), die in nassen Mühlkellern lebt.
224. [P2] Gib Puddlet eine Ashmere-Prägung (Tide/Stone), die Ascheschlamm statt Regenwasser sammelt.
225. [P2] Gib Wickit eine Solenne-Prägung (Lumen/Ember), deren Docht in der Sonne brennt.
226. [P2] Gib Mirkmole eine Ashmere-Prägung (Umbra/Ember), die unter dem glimmenden Moor gräbt.
227. [P2] Lass Prägungen wilder Spirlings nur in ihrer Region erscheinen und gebondete Spirlings ihre Prägung für immer behalten.
228. [P2] Zeige Prägungen im Namen als Zusatz ("Kindlop, Corvane-Prägung") und nie als eigene Art.
229. [P2] Lass Prägungen dieselbe Wertesumme wie die Grundform haben und nur die Verteilung um höchstens 20 Punkte verschieben.
230. [P2] Lass eine Prägung beim Entfalten in die geprägte Form der nächsten Stufe übergehen, falls diese existiert, sonst in die normale.
231. [P3] Gib Kelpup eine Solenne-Prägung (Tide/Gale) aus den Salzseen.
232. [P3] Gib Zippit eine Ashmere-Prägung (Volt/Stone), die in Kupferdrähten wohnt.
233. [P3] Gib Riptail eine Solenne-Prägung (Tide/Lumen), die nur in Luftspiegelungen schwimmt.
234. [P3] Gib Talusk eine Corvane-Prägung (Stone/Bloom), mit Moos auf jedem Stein.
235. [P3] Lass im Spirlog jede Art eine Zeile "Prägungen: 1 von 3 gesehen" zeigen.
236. [P3] Gib jeder Prägung eine eigene Lore-Zeile, wie die Dorfleute der Region sie nennen.
237. [P3] Zeichne Prägungs-Sprites als Paletten-Tausch plus höchstens eine geänderte Form-Einzelheit, damit der Aufwand klein bleibt.
238. [P3] Lass eine Prägung eine andere Gabe tragen dürfen, wenn sie im Feld "trait" des Varianten-Eintrags steht, sonst die der Grundform.
239. [P3] Erlaube keinen Wechsel einer Prägung zurück zur Grundform, im Unterschied zum Entfalten, und erkläre das im Team-Menü.
240. [P3] Prüfe im Validator, dass jede Prägung ein anderes Elementpaar hat als ihre Grundform.
241. [P3] Lass Prägungen im Lager als eigene Sortiergruppe neben der Grundform erscheinen.
242. [P3] Plane pro neuer Region höchstens 5 Prägungen, damit eigene Regionsarten im Vordergrund stehen.

### Spirlog
243. [P1] Gestalte das Spirlog als Seiten des Kartenbuchs: eine Seite pro Art mit Sprite, Elementen, Größe, Lebensraum, Lore und Herkunft, im Hochformat 144x256 lesbar.
244. [P1] Zeige auf jeder Spirlog-Seite die Fundkarte: die Karten, auf denen die Art schon gesehen wurde, als Liste mit Grund-Symbol (Farn, Schilf, Geröll).
245. [P1] Lass "seen" schon beim Anblick im Kampf setzen und "bonded" beim Bonden, und zeige ungesehene Arten nur als Umriss mit Nummer.
246. [P1] Spiele auf jeder gesehenen Spirlog-Seite den Ruf der Art über Cry.gd ab, mit einem Tipp auf das Sprite.
247. [P1] Zeige auf der Spirlog-Seite die ganze Entfalten-Linie als Reihe kleiner Sprites, mit Tipp zum Springen.
248. [P1] Teile das Spirlog in Kapitel nach Region und blende Kapitel unbekannter Regionen aus.
249. [P1] Füge eine Suche nach Name und Filter nach Element, Rolle und "gebondet / nur gesehen / fehlt" hinzu.
250. [P1] Lass die Lore-Absätze nach und nach aufgehen: erster Satz bei gesehen, zweiter bei gebondet, dritter nach 10 Kämpfen mit einem Spirling dieser Art im Team.
251. [P1] Zeige oben im Spirlog den Fortschritt pro Kapitel ("Veydal: 31 gesehen, 18 gebondet") statt nur der Gesamtzahl.
252. [P2] Speichere pro Art den ersten Fundort und den ersten Fundtag und zeige sie als Feldnotiz ("Zuerst gesehen: Farnstiege, Tag 3").
253. [P2] Zeige auf der Seite, welche Temperamente der Spieler bei dieser Art schon gebondet hat, als sechs kleine Zeichen.
254. [P2] Zeige ein Prisma-Zeichen auf der Seite, wenn eine Prisma-Form gesehen wurde, und die Prisma-Farbe, wenn eine gebondet wurde.
255. [P2] Zeige die Ortsprägungen einer Art als eigene Reiter auf ihrer Seite, gesperrt bis gesehen.
256. [P2] Ergänze das Spirlog um eine Fährten-Liste: in jedem Gebiet zeigt das Kartenbuch "Fährten von 2 unbekannten Spirlings", ohne Namen.
257. [P2] Lass den Spieler auf einer Spirlog-Seite eine eigene kurze Notiz (bis 40 Zeichen) speichern.
258. [P2] Zeige auf der Seite Größe und Gewicht als Silhouette neben dem Wanderer, statt nur als Zahl.
259. [P2] Zeige Spirlog-Seiten im Grafikstil der freigeschalteten Ära, mit Wahl im Retro-Filter.
260. [P2] Gib dem Spirlog eine Ansicht "Raster", die 20 Arten pro Bildschirm als kleine Sprites zeigt.
261. [P2] Ergänze für jede Seite die Liste der Wanderer, die diese Art im Team führen, nachdem man sie besiegt hat.
262. [P2] Zeige auf der Seite die Gabe der Art erst nach dem Bonden, mit Satz aus BattleRules.TRAITS.
263. [P2] Zeige bei Hallkindern auf der Seite der Art einen Zähler "Durch Nachhall erwacht: 2".
264. [P2] Lass das Spirlog eine Seite "Zuletzt gefunden" mit den letzten 10 neuen Einträgen haben.
265. [P2] Zeige die Begegnungsbedingungen einer shy-Art erst, nachdem man sie einmal gesehen hat.
266. [P2] Gib jeder Spirlog-Seite einen Knopf "Im Lager zeigen", der das Lager auf diese Art filtert.
267. [P2] Zeige im Spirlog Tracker zusätzlich, welche Arten im aktuellen Gebiet nur nachts, in der Dämmerung oder bei Wetter auftauchen.
268. [P3] Lass das Spirlog in der Leuchtturm-Bibliothek als großes Buch stehen, das man ansprechen kann, mit einem Aldo-Kommentar zum Fortschritt.
269. [P3] Gib dem Spirlog eine Blätter-Bewegung mit Papierton beim Wechsel der Seite.
270. [P3] Zeige vergessene Einträge, wenn ein gebondeter Spirling freigelassen wurde, weiterhin als gebondet, mit dem Hinweis "gebondet gewesen".
271. [P3] Erlaube, eine Spirlog-Seite als Bild über den Fotomodus zu speichern.
272. [P3] Zeige auf der Seite die längste Echo-Serie, die der Spieler mit dieser Art erreicht hat.
273. [P3] Gib dem Spirlog eine Seite "Mirelas Notizen" mit Einträgen zu Arten, die Mirela kannte, freigeschaltet durch Kartenbuch-Seiten.
274. [P3] Lass den Spieler eine Lieblingsart wählen, deren Sprite auf dem Titelbildschirm neben dem Logo steht.
275. [P3] Zeige im Spirlog bei vollständig gebondeten Kapiteln einen Tintenstempel des Kapitels.
276. [P3] Gib dem Spirlog eine Vorlesefunktion für Lore über die Text-zu-Sprache des Geräts, nur wenn das System sie anbietet.
277. [P3] Erlaube die Sortierung des Spirlogs nach Fundtag, um die eigene Reise nachzulesen.

### Echo-Melodie-Bonden
278. [P1] Gib jeder Art ein festes Ruf-Motiv (die ersten zwei Zeichen ihres Rufs stehen in "cry_motif"), damit Wiedersehen mit einer Art sich vertraut anfühlt, und lass BondEcho.make_sequence() es nutzen.
279. [P1] Spiele zu jedem Zeichen einen Ton, dessen Höhe vom Element des wilden Spirlings abhängt (acht Tonleitern in Sound.gd), sodass jedes Element anders klingt.
280. [P1] Lass gestillte Spirlings in Rissnähe einen gedämpften Ruf mit nur drei Zeichen und blasseren Lichtern rufen, passend zur Stille im Lore.
281. [P1] Lass Spirlings bei geflickten Rissen einen vollen Ruf mit vier Zeichen und einem leuchtenden Rahmen rufen, als sichtbaren Lohn fürs Flicken.
282. [P1] Zeige nach dem Ruf nur ein Ergebnis in Worten ("Es hört dir zu", "Es zögert", "Es wendet sich ab"), nie eine Zahl, und halte das in test_bond_echo.gd fest.
283. [P1] Lass einen zweiten Bondversuch im selben Kampf mit demselben Ruf beginnen, damit Lernen belohnt wird statt Glück.
284. [P1] Füge die Antwort-Phase hinzu: nach einem fehlerfreien Echo ruft der Spirling manchmal ein fünftes Zeichen ("Nachklang"), dessen richtiges Echo den Ruf-Wert auf 1,0 hält, auch wenn das Zeichen eigentlich zusätzlich ist.
285. [P1] Lass die Ruf-Länge mit der Seltenheit wachsen: common 4, uncommon 4, shy 5, ancient 5 plus zweite Phase, als Werte in BondEcho.gd.
286. [P1] Ersetze die drei Zeichen Raute, Quadrat und Dreieck bei Lumen und Umbra durch Mond, Stern und Funke als eigene Form, ohne die Regeln zu ändern.
287. [P2] Lass die Echozeit ECHO_TIME in der Schwierigkeit Story auf 8 Sekunden steigen und in Rift-Born auf 5 Sekunden sinken.
288. [P2] Gib dem Spirling im Team, das dieselbe Art wie der wilde Spirling ist, eine Hilfe: das erste Zeichen leuchtet beim Echo kurz nach.
289. [P2] Lass einen Spirling, der ein Bonden abgelehnt hat und wieder auftaucht, beim nächsten Treffen sagen lassen "Es erinnert sich an deinen Ruf", und beginne mit demselben Motiv.
290. [P2] Lass das Bonden außerhalb des Kampfes bei friedlichen Spirlings zu (shy-Arten, die nicht kämpfen wollen), nur über das Echo ohne vorherigen Kampf, auf eigenem Bildschirm.
291. [P2] Gib friedlichen Begegnungen einen eigenen Hintergrund (Pergament mit Fundort-Skizze) statt des Kampfhintergrunds.
292. [P2] Lass einen Spirling nach erfolgreichem Bonden sein Motiv im Spirlog als kleine Zeichenreihe speichern.
293. [P2] Gib dem Ruf eine Tempo-Variante nach Temperament des wilden Spirlings: Brisk ruft 15 Prozent schneller, Stalwart 15 Prozent langsamer.
294. [P2] Lass Kin Charm nicht nur den Wert erhöhen, sondern zeige beim Echo einen sanften Schimmer am richtigen nächsten Zeichen für 0,2 Sekunden nach einem Fehler, einmal pro Ruf.
295. [P2] Lege fest, dass das Bonden nie eine Rest-Chance anzeigt und kein Element der Oberfläche während des Echos schrumpft, wächst oder einen Zeiger trägt, als Test über BondMinigame.
296. [P2] Lass Spieler im Bond-Bildschirm mit "Zurückziehen" ohne Strafe aussteigen, bevor sie das erste Zeichen tippen.
297. [P2] Erlaube die Eingabe über Gamepad-Tasten (drei Tasten für drei Zeichen) neben dem Tippen.
298. [P2] Gib jedem Zeichen eine eigene leichte Vibration mit unterschiedlicher Länge über GameState.rumble_pads.
299. [P2] Zähle pro Spirling die vollständig richtigen Echos in Folge ("echo_streak") für die Entfalten-Regel und das Spirlog.
300. [P2] Lass Wiederholungen eines bereits gesehenen Motivs schneller ablaufen (SHOW_TIME 0,35 statt 0,45), sobald die Art gebondet ist.
301. [P2] Gib dem Echo eine Übungsfunktion im Spirlog: jede gebondete Art kann ihren Ruf zum Üben spielen, ohne Bonden.
302. [P2] Lass den Echo-Bildschirm den wilden Spirling bei jedem richtigen Zeichen einen kleinen Schritt näher kommen, nur als Bewegung, ohne Zahlwert.
303. [P3] Lass eine Erste Stimme in ihrer zweiten Phase die Zeichen in einer neuen Anordnung (vier Zeichen im Kreis) zeigen.
304. [P3] Gib dem Echo eine Einstellung "Ruf zweimal hören", die den Ruf vor dem Echo einmal wiederholt, dafür ohne Nachklang.
305. [P3] Lass zwei Spirlings im Team, die gemeinsam schon einen Hallkern erzeugt haben, beim Bonden ihrer Art mitsingen (Hintergrundton), rein kosmetisch.
306. [P3] Lass im Mehrfachkampf gegen eine Wild-Horde das Bonden nur beim zuletzt verbliebenen Spirling zu und erkläre das im Kampftext.
307. [P3] Lass einen gebondeten Spirling sein Motiv beim ersten Einwechseln im Kampf rufen.
308. [P3] Gib dem Echo ein Tagebuch in den Aufzeichnungen: Rufe gehört, Rufe vollständig erwidert, längste Serie.
309. [P3] Lass in der Nacht die Zeichen dunkler und den Ton tiefer sein, gesteuert über DayCycle.
310. [P3] Lass Lumen-Spirlings in der Dämmerung ihren Ruf rückwärts wiederholen, wenn das Echo richtig war, als kleiner Moment.
311. [P3] Gib dem Echo-Bildschirm einen Hinweis-Text beim allerersten Bonden, der nur das Zuhören erklärt, nicht das Ziel.
312. [P3] Lass Bond-Ergebnis-Wörter je nach Art leicht anders klingen ("Es plätschert zustimmend" bei Tide).

### Temperament
313. [x] [P1] Erweitere das Temperament auf zehn Werte mit vier neuen (Curious, Shy, Proud, Gentle), die keinen Wert stärken, sondern nur Verhalten und Texte färben, und speichere sie ab Speicherstand 4.
314. [P1] Zeige das Temperament auf der Lagerkarte und im Team-Menü mit dem bestehenden Satz ("Moves a little quicker.") und dem deutschen Gegenstück.
315. [P1] Lass wilde Spirlings ihr Temperament bis zum Bonden verbergen und zeige es danach einmal als Meldung ("Es wirkt neugierig").
316. [P2] Lass Curious-Spirlings beim Echo das Motiv manchmal vertauschen, Shy-Spirlings leiser rufen, Proud-Spirlings ein Zeichen länger halten, Gentle-Spirlings langsamer rufen.
317. [P2] Gib jedem Temperament ein eigenes kleines Leerlauf-Verhalten im Team-Menü (Hüpfen, Wackeln, Ruhe, Ducken).
318. [P2] Lass Dorfbewohner an zwei Orten das Temperament des ersten Spirlings im Team kommentieren.
319. [P2] Gib jedem Temperament ein Lieblingsandenken (siehe Andenken-Zuordnung), das im Lager-Detail genannt wird.
320. [P2] Lass das Temperament im Lager filterbar und sortierbar sein.
321. [P2] Lass das Spirlog pro Art zählen, wie viele der zehn Temperamente gebondet wurden.
322. [P2] Gib jedem Temperament eine eigene Farbe für das kleine Zeichen, mit Muster für Farbsehschwäche.
323. [P2] Lass das Temperament im Nachhall erblich sein (siehe Nachhall) und halte das in der Spirling-Herkunft fest.
324. [P2] Teste, dass die alten sechs Temperamente bei der Migration exakt erhalten bleiben und die neuen vier nur bei neuen Spirlings vorkommen.
325. [P3] Lass Proud-Spirlings nach einem Sieg im Kampftext eine eigene Zeile sagen.
326. [P3] Lass Shy-Spirlings zu Beginn eines Kampfes einen Moment hinter dem Wanderer stehen, rein als Grafik.
327. [P3] Gib den Temperamenten eigene Wörter im Fotomodus (Pose "neugierig", "stolz").
328. [P3] Lass Gentle-Spirlings beim Rasten an einer Quelle eine kleine Zeile "Es ruht sich zufrieden aus" erzeugen.
329. [P3] Lass Curious-Spirlings im Overworld manchmal einen versteckten Fund melden, wenn sie vorne im Team sind, höchstens einmal pro Karte.
330. [P3] Schreibe die zehn Temperamente in docs/SPIRLINGS.md mit kurzer Beschreibung.
331. [P3] Lass das Temperament in Online-Echo-Teams mit angezeigt werden, als Text.
332. [P3] Prüfe mit BalanceSim, dass die neuen vier Temperamente keine Kampfwerte ändern.

### Gaben
333. [P1] Ordne jeder neuen Art genau eine Gabe aus BattleRules.TRAITS zu und trage sie in spirlings.json ein, sodass keine Gabe mehr als 6 Linien hat.
334. [P1] Lass jede Gabe-Zuordnung zur Herkunft passen (Brinelet "slick", Talusk "thick_hide", Fluting "light_sleeper") und begründe jede in docs/SPIRLINGS.md mit einem Satz.
335. [P1] Liste in docs/SPIRLINGS.md die Arten auf, die auf neue Gaben aus Bereich 2 warten, mit Platzhalter "steady" bis die Gabe existiert.
336. [x] [P1] Prüfe im Validator, dass jede Art eine Gabe hat, die in BattleRules.TRAITS existiert.
337. [P2] Gib jeder Gabe einen Lore-Satz, woher Spirlings mit dieser Gabe sie haben ("Tiefe Wurzeln: lernen Spirlings, die lange an einem Ort bleiben").
338. [P2] Lass eine Linie beim Entfalten die Gabe wechseln dürfen, wenn die höhere Stufe eine andere trägt, und zeige "Neue Gabe: ..." beim Entfalten.
339. [P2] Gib Prägungen ihre eigene Gabe nur, wenn das Element dadurch eine andere Gabe sinnvoll macht, höchstens bei 3 von 10 Prägungen.
340. [P2] Zeige im Lager einen Filter nach Gabe.
341. [P2] Lass das Hallkind die Gabe seiner Art tragen, nie die eines Elternteils einer anderen Art.
342. [P2] Gib jeder Gabe ein kleines eigenes Symbol für Lagerkarte und Spirlog.
343. [P2] Schreibe die deutschen Gabe-Namen in die Übersetzung (Kindling, Thick Hide und so weiter), falls noch nicht vorhanden.
344. [P2] Lass die Gabe auf der Lagerkarte erst nach dem Bonden sichtbar sein, im Kampf gegen Wilde bleibt sie unbekannt bis sie ausgelöst wird.
345. [P2] Ordne jeder Ersten Stimme eine Gabe zu, die es bei keiner anderen Art gibt, als Wunsch an Bereich 2, mit Platzhalter bis dahin.
346. [P2] Prüfe, dass jede Region mindestens 5 verschiedene Gaben anbietet.
347. [P3] Lass im Spirlog eine Seite "Gaben" alle Gaben mit den Arten zeigen, die sie tragen.
348. [P3] Gib Gaben im Fotomodus einen kleinen Effekt (Glut bei Kindling, Blätter bei Deep Roots).
349. [P3] Lass einen Bewohner in Corvane die Gaben der Team-Spirlings in einem Satz erklären.
350. [P3] Lass das Spirlog zählen, wie oft die Gabe eines Spirlings im Kampf ausgelöst wurde, über das bestehende Log.
351. [P3] Lege fest, dass Gaben nie durch Geld oder Shop-Gegenstände getauscht werden.
352. [P3] Gib Gaben in Hallkind-Stammbäumen sichtbar mit an.
353. [P3] Lass Kestra einmal kommentieren, welche Gabe ihr Lieblingsspirling hat.
354. [P3] Plane Gabe-Zuordnungen für die späteren Arten der Regionen als offene Spalte in tools/data/spirling_sheet.py.

### Andenken-Zuordnung
355. [P1] Gib jeder Art ein Feld "keepsake_hint" mit dem Andenken, das zu ihr passt, und zeige es im Lager als Vorschlag "Passt gut: Bark Wrap".
356. [P1] Lass beim Senden eines Spirlings ins Lager sein Andenken in der Tasche bleiben, wenn der Spieler das will, mit Frage "Andenken behalten?".
357. [P1] Zeige im Lager auf jeder Karte das Andenken als Symbol und erlaube das Abnehmen direkt dort.
358. [P2] Gib jedem Temperament ein Lieblingsandenken (Fierce: Whetstone, Stalwart: Iron Burr, Keen: Keen Lens, Brisk: Wind Anklet, Hearty: Spring Flask, Even: Spark Coil).
359. [P2] Lass einen Spirling mit Lieblingsandenken im Team-Menü fröhlicher wackeln, rein kosmetisch.
360. [P2] Zeige im Team-Menü eine Übersicht "Wer trägt was" für alle fünf Spirlings auf einem Bildschirm.
361. [P2] Erlaube im Lager, Andenken zwischen zwei Spirlings in einem Schritt zu tauschen.
362. [P2] Nutze Andenken als Entfalten-Auslöser für zwei neue Linien (Brinelet mit Tide Shell, eine Ashmere-Linie mit einem neuen Andenken aus Bereich 2).
363. [P2] Gib dem neuen Andenken "Stimmgabel" (für den Nachhall) eine Beschreibung und ein Sprite, und lass es nur über eine Nebenquest an der ersten Echo-Quelle erhalten.
364. [P2] Lass Andenken im Spirlog unter "Liebt" erscheinen, sobald man es einem Spirling dieser Art gegeben hat.
365. [P2] Prüfe im Validator, dass jedes "keepsake_hint" auf einen Gegenstand mit "held"-Block zeigt.
366. [P2] Sortiere die Andenken-Wahl im Team-Menü so, dass passende Andenken zuerst stehen.
367. [P3] Lass Spirlings ihr Lieblingsandenken bei der Erste-Stimme-Begegnung besonders zeigen, als kleine Zeile.
368. [P3] Gib Andenken, die lange (50 Kämpfe) von einem Spirling getragen werden, den Zusatz "von <Name> getragen" in der Tasche.
369. [P3] Lass im Fotomodus das Andenken sichtbar am Spirling hängen.
370. [P3] Lass Mirelas alte Andenken als Story-Funde in Akt II auftauchen, mit eigener Lore-Zeile.
371. [P3] Erlaube eine Lager-Aktion "Alle Andenken abnehmen" mit Bestätigung.
372. [P3] Zeige in den Aufzeichnungen, welches Andenken am längsten getragen wurde.
373. [P3] Lass Hallkinder mit dem Andenken des Elternteils erwachen, der die Stimmgabel trug, wenn der Spieler es erlaubt.
374. [P3] Gib dem Spirlog eine Seite "Andenken", die zeigt, welche Arten welches Andenken lieben.

### Lager und Team-Verwaltung
375. [P1] Teile das Lager in benannte Fächer zu je 30 Plätzen (Start 8 Fächer, 240 Plätze) mit Namen und Farbe, die der Spieler ändern kann.
376. [P1] Füge Mehrfachauswahl im Lager hinzu, um bis zu 10 Spirlings auf einmal in ein anderes Fach zu verschieben.
377. [P1] Lass den Spieler Spirlings als "Liebling" markieren, die nicht freigelassen und nicht versehentlich verschoben werden können.
378. [P1] Füge Team-Vorlagen hinzu: bis zu 6 gespeicherte Teams von je 5 Spirlings, die an jeder Quelle mit einem Tipp geladen werden.
379. [P1] Füge das Freilassen hinzu: ein Spirling kehrt mit einem kurzen Abschiedstext an seinen Fundort zurück, mit doppelter Bestätigung und nie für Lieblinge.
380. [P1] Zeige im Lager eine Detailkarte mit Ring, Temperament, Gabe, Andenken, Herkunft (Fundort, Tag, Ring beim Treffen) und Spark-Wörtern.
381. [P1] Lass das Team an jeder Heilquelle mit dem Lager tauschen, auch bevor das Lager aus dem Menü erreichbar ist.
382. [P1] Prüfe mit Tests, dass Verschieben, Freilassen und Team-Vorlagen nie das letzte gesunde Team-Mitglied entfernen.
383. [P2] Lass das Lager nach Seltenheit, Temperament, Gabe, Prägung und Fundtag sortieren, zusätzlich zu den bestehenden vier Sortierungen.
384. [P2] Gib jedem Spirling bis zu drei eigene Farbmarken im Lager zum Ordnen.
385. [P2] Zeige im Lager einen Vergleich zweier Spirlings nebeneinander (Werte als Wörter, Techniken, Gabe).
386. [P2] Lass Team-Vorlagen einen Namen tragen und zeige ihre Elemente als Glyphenreihe.
387. [P2] Zeige im Lager oben "Belegt: 87 von 240", damit der Platz klar ist.
388. [P2] Lass neue Bonds automatisch in ein wählbares Fach statt immer in das erste wandern.
389. [P2] Füge eine Doppel-Anzeige hinzu: Arten, von denen man mehr als 3 hat, bekommen einen Zähler.
390. [P2] Lass das Lager eine Ansicht "Linien" haben, in der Spirlings derselben Entfalten-Linie zusammen stehen.
391. [P2] Erweitere das Lager um 4 weitere Fächer nach jedem geflickten Riss, bis höchstens 20 Fächer.
392. [P2] Erlaube Spitznamen im Lager zu ändern, außer bei Spirlings aus Online-Echos.
393. [P2] Zeige im Team-Menü die Elemente des Teams und welche der 8 Elemente fehlen, als reine Information.
394. [P2] Speichere das Lager im Speicherstand als Fächer-Liste und migriere die bisherige flache Liste in Fach 1 bis 8.
395. [P2] Lass die Lagerliste mit Wischen zwischen Fächern wechseln und mit Halten ein Spirling greifen.
396. [P2] Zeige im Lager freigelassene Spirlings der letzten 24 Stunden in einem "Abschied"-Fach, aus dem man sie zurückholen kann.
397. [P2] Lass die Team-Reihenfolge per Halten und Ziehen im Team-Menü ändern.
398. [P2] Schreibe Tests für Fächer-Migration, Freilassen, Zurückholen und volle Fächer in tests/unit/test_storage.gd.
399. [P3] Gib dem Lager einen Ort in der Welt: der Kartenschrank im Leuchtturm, den Aldo pflegt, mit eigener Grafik.
400. [P3] Lass jedes Fach ein Hintergrundmotiv aus einer bekannten Karte wählen (Farnstiege, Salzmarsch und so weiter).
401. [P3] Füge eine Lager-Suche nach Technik hinzu ("Wer kann Kiln Strike?").
402. [P3] Zeige in den Aufzeichnungen, wie viele Spirlings insgesamt gebondet, freigelassen und entfaltet wurden.
403. [P3] Lass ein Spirling, das lange (30 echte Tage) im Lager war, beim Holen eine eigene Zeile sagen ("Es freut sich, dich zu sehen").
404. [P3] Erlaube, ein Team-Mitglied als "Begleiter" für den Titelbildschirm zu wählen.
405. [P3] Lass Team-Vorlagen Andenken mitspeichern, nur wenn die Andenken noch in der Tasche sind, sonst mit Hinweis.
406. [P3] Gib dem Lager eine Ansicht "Ring 60", die alle Spirlings am Ring-Deckel zeigt.
407. [P3] Synchronisiere das Lager mit dem Server-Speicherstand über das bestehende Online-Speichern, ohne Tauschfunktion.

### Sammelziele
408. [P1] Erweitere Collection.GOALS um Ziele pro Region (Veydal 10, 20, 30, alle), damit neue Arten nicht nur die Gesamtzahl verlängern.
409. [P1] Ersetze das Ziel "kinds_11" durch eine gleitende Reihe 3, 5, 8, 12, 16, 20, 25, 30, alle, angepasst an 40 Veydal-Arten.
410. [P1] Lass Belohnungen für Sammelziele nur Gegenstände aus dem Spiel, Münzen, Jackenfarben oder Titel sein, nie etwas, das man auch kaufen kann, und halte das in Collection.gd fest.
411. [P1] Zeige im Ziele-Menü das nächste Sammelziel mit verbleibender Zahl ("Noch 3 Arten bis Kapitel-Stempel Veydal").
412. [P1] Teste, dass jedes Sammelziel mit Inhalten des Akt I ohne Online-Funktionen erreichbar ist, wenn es zu Veydal gehört.
413. [P2] Füge Element-Ziele hinzu: alle Arten eines Elements in einer Region gebondet gibt eine Element-Zeichnung im Kartenbuch.
414. [P2] Füge Linien-Ziele hinzu: jede Stufe einer Linie mindestens einmal entfaltet gibt eine Zeile im Spirlog.
415. [P2] Füge ein Prägungs-Ziel hinzu: 5 Ortsprägungen gebondet gibt die Jackenfarbe "Reisende".
416. [P2] Füge ein Temperament-Ziel hinzu: alle zehn Temperamente bei einer Art gebondet gibt den Titel "Kenner von <Art>".
417. [P2] Füge ein Nachhall-Ziel hinzu: 5 erwachte Hallkinder geben die Stimmgabel ein zweites Mal.
418. [P2] Füge ein Echo-Ziel hinzu: 50 fehlerfreie Echos geben einen neuen Ruf-Rahmen im Bond-Bildschirm.
419. [P2] Füge ein Ziel für shy-Arten hinzu: alle scheuen Arten Veydals gebondet gibt eine Laternenfarbe.
420. [P2] Füge ein Ziel "Erste Stimmen" hinzu, das nach jeder gebondeten Ersten Stimme eine Kartenbuch-Seite färbt.
421. [P2] Zeige alle Sammelziele in einer eigenen Liste "Sammelziele" im Ziele-Menü mit Haken für erreichte.
422. [P2] Lass beim Erreichen eines Sammelziels eine kurze Tinten-Stempel-Szene und einen Ton spielen.
423. [P2] Verknüpfe die Sammelziele mit Achievements.gd, sodass jedes Kapitel-Ziel auch ein Eintrag in den Aufzeichnungen ist.
424. [P2] Füge ein Fundort-Ziel hinzu: jede Art an ihrem Erstfundort einmal gebondet gibt den Titel "Kartograf des Lebens".
425. [P2] Migriere bereits beanspruchte alte Ziele so, dass niemand eine Belohnung doppelt bekommt oder verliert.
426. [P3] Füge ein Prisma-Ziel hinzu: 3 Prisma-Spirlings gebondet gibt einen Prisma-Rahmen im Spirlog.
427. [P3] Füge ein Ziel "Freundschaft" hinzu: 100 Kämpfe mit demselben Spirling im Team gibt eine Erinnerungszeile auf seiner Karte.
428. [P3] Lass im Weltziel der Online-Funktion als Option "gemeinsam X Arten bonden" zu, wenn der Online-Bereich das aufnehmen will, ohne Tauschen.
429. [P3] Füge ein Ziel "Ganze Linie im Team" hinzu: alle drei Stufen der Talusk-Linie gleichzeitig im Team gibt eine Fotomodus-Pose.
430. [P3] Füge ein Ziel "Tag und Nacht" hinzu: jede tageszeitgebundene Art zu ihrer Zeit gebondet.
431. [P3] Gib jedem Kapitel-Ziel eine eigene Zeile von Aldo im Leuchtturm.
432. [P3] Lass erreichte Sammelziele im Online-Profil als Zahl erscheinen ("Spirlog: 34 Arten"), wenn der Spieler das freigibt.
433. [P3] Füge ein Fest-Ziel hinzu: in jedem der vier Feste aus Season.gd eine Art des Festelements bonden.
434. [P3] Lass das letzte Sammelziel jeder Region eine Kartenbuch-Seite mit einer Zeichnung aller Arten der Region freischalten.
435. [P3] Prüfe mit einem Test, dass keine Sammelzielbelohnung im Shop-Datenbestand auftaucht.

### Recht, Originalität und Tests
436. [P1] Prüfe jeden neuen Spirling-Namen, jede Ruf-Melodie und jeden Umriss gegen die Sperrliste und die IP-Regeln und vermerke die Prüfung pro Art in docs/IP_HYGIENE.md, bevor er in die Daten kommt.
437. [P1] Halte in LEGAL.md und test_bond_echo.gd fest, dass Bonden weiter ohne Wurf, ohne Zielen, ohne schrumpfende Kreise und ohne Chancenanzeige läuft, auch bei Ersten Stimmen und friedlichen Begegnungen.
438. [P1] Stelle sicher, dass kein Spirling, Hallkern oder Hallkind je getauscht, verschenkt oder gegen Geld erhalten werden kann, und prüfe es in test_online.gd.
439. [P2] Lege fest, dass Spirlings beim Einwechseln, Nachhall und Erwachen immer neben den Wanderer treten und nie herausgeworfen werden, und prüfe es in den Szenen.
440. [P2] Prüfe alle neuen deutschen Texte mit tools/ip_check.sh auf gesperrte Wörter, einschließlich der Begriffe aus der Spielerwörter-Liste in docs/IP_HYGIENE.md.
441. [P2] Lass die neuen Arten in keinem Fall eine Feuer-Wasser-Pflanze-Dreiheit als Startwahl oder Geschenkset bilden.
442. [P2] Ergänze test_originality.gd um die neuen festen Zahlen: Lager-Fächer 30, Team 5, Nachhall 600 Felder, Ruf-Längen 3 bis 5.
443. [P2] Dokumentiere in docs/SPIRLINGS.md, dass Seltenheit, Prägung und Prisma nie an Geld gebunden sind.
444. [P3] Lass die Rechtsprüfung des Nachhalls und der Ersten Stimmen als offenen Punkt in docs/ROADMAP.md stehen, bis der Rechts-Thread zustimmt.
