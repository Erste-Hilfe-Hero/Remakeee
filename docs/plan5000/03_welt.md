# Bereich 3: Welt, Karten und Erkundung

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 890 bis 1334.

> **Auftrag für den umsetzenden Thread:** Ziel ist eine größere, dichtere Welt in Veydal, die man zu Fuß erkundet, mit neuen Routen, Orten, Höhlen, Rätsel-Dungeons, Geheimnissen, Wetter, Tageszeit, Schnellreise per Fähre und Kutsche, belebten Orten und einer echten Kartenansicht samt Minikarte. Betroffen sind vor allem data/maps/, data/encounters.json, data/items.json (nur Ausrüstung), tools/art/build_world.py, scripts/overworld/, scripts/core/WorldValidator.gd, scripts/core/DayCycle.gd, scripts/ui/PauseMenu.gd und die Tests unter tests/unit/. Fang mit dem Abschnitt "Weltdaten und Werkzeuge" an (neue Kachelzeichen, Kartenfelder, Validator), weil alle neuen Karten darauf aufbauen. Hauptstory, Quests und Dialog-Handlung gehören zu Bereich 4, der Grafikstil der Kacheln und Wettereffekte zu Bereich 6; hier entstehen nur Logik, Kartendaten und schlichte Platzhalter-Darstellung in den vorhandenen Farben. Fliegen, Gleiten und Reiten sind auch mit Ausrüstung verboten, Kämpfe starten nie in Echtzeit in der Welt.

### Weltdaten und Werkzeuge
890. [x] [P1] Füge in TilesetFactory.gd die neuen Kachelzeichen "w" (seichtes Wasser zum Waten), "B" (schiebbarer Felsblock), "P" (Druckplatte), "k" (rissiger Boden), "v" (Rankenwand zum Klettern) und "Y" (Brückenbrett-Stelle) hinzu und dokumentiere sie in der Legende von MapData.gd.
891. [x] [P1] Erweitere MapData.gd um ein Feld "secrets" (Liste aus x, y, Gegenstand, Flag), damit versteckte Funde nicht mehr als Schilder mit hide_flag gebaut werden müssen.
892. [x] [P1] Erweitere MapData.gd um ein Feld "floors" (Liste von Zeilenblöcken je Ebene), damit eine Höhle oder ein Dungeon mehrere Stockwerke in einer Datei hat.
893. [x] [P1] Ergänze WorldValidator.gd so, dass er jede Druckplatte, jeden Felsblock und jede Brückenbrett-Stelle auf Erreichbarkeit prüft und Rätsel ohne Lösung als Fehler meldet.
894. [x] [P1] Ergänze WorldValidator.gd um eine Prüfung, dass jede Karte mit wilden Spirlings ein Tabellen-Eintrag in data/encounters.json besitzt und umgekehrt keine Tabelle verwaist ist.
895. [x] [P1] Teile tools/art/build_world.py in je eine Datei pro Kartengruppe (tools/art/world/veydal_core.py, veydal_wilds.py, veydal_caves.py, corvane.py), damit mehrere Leute parallel Karten bauen können.
896. [x] [P1] Lege data/world_layout.json an, das jede Karte mit Position (Rasterfeld) und Nachbarn für die Weltkarte beschreibt, und lass den Validator prüfen, dass jede Warp-Verbindung dort als Kante steht.
897. [x] [P1] Erweitere tools/art/preview_map.py so, dass es eine Übersicht aller Karten einer Region als ein PNG unter build/previews/ ausgibt, um Lücken im Layout schnell zu sehen.
898. [P2] Führe pro Karte ein Feld "biome" (z. B. fern, marsh, scree, forest, cave, town) ein, das Begegnungen, Wetter und Geräusche gemeinsam steuert.
899. [P2] Führe pro Karte ein optionales Feld "music_day" und "music_night" ein, das auf vorhandene Einträge in data/music.json zeigt.
900. [P2] Ergänze MapData.gd um "one_way" Kanten (Felsstufen, die man nur abwärts gehen kann), die der PathFinder beachtet.
901. [x] [P2] Ergänze PathFinder.gd so, dass Tipp-Laufen Druckplatten nicht aus Versehen auslöst, wenn das Ziel nicht die Platte selbst ist.
902. [P2] Ergänze MapData.gd um "ambient" Punkte (x, y, Geräusch-ID) für Wasserrauschen, Wind oder Glocken in der Nähe.
903. [x] [P2] Schreibe ein Werkzeug tools/world_stats.py, das pro Karte Größe, Anzahl Funde, Anzahl Wanderer und Begegnungsfelder ausgibt und als Tabelle in docs/WORLD.md einträgt.
904. [x] [P2] Lege eine Kartenvorlage tools/art/world/template.py mit 12 Kacheln Breite, Rahmen aus Fels und je einem Warp oben und unten an.
905. [x] [P2] Ergänze GameState.gd um ein Wörterbuch "world_state" (Karte, Schlüssel, Wert), damit geschobene Felsen und offene Schleusen nach Speichern erhalten bleiben.
906. [P2] Ergänze die Speicher-Migration in SaveManager.gd für "world_state", "map_cells" und "pins" mit einem Test in tests/unit/test_save_migration.gd.
907. [x] [P2] Ergänze WorldValidator.gd um eine Höchstgröße von 12 Kacheln Breite und 40 Kacheln Höhe pro Karte für Außenkarten.
908. [P3] Baue einen einfachen Karten-Editor als Godot-Szene tools/map_editor.tscn, der ASCII-Zeilen lädt, Kacheln per Tippen setzt und zurück in JSON speichert.
909. [P3] Ergänze das Validator-Werkzeug um eine Warnung, wenn ein Weg länger als 30 Schritte ohne Abzweig, Fund oder Wanderer ist.
910. [P3] Gib jeder Karte ein Feld "author_note", das nur im Debug-Menü angezeigt wird, um Bauabsichten festzuhalten.
911. [P3] Ergänze das Debug-Menü um "Teleport zu Karte und Feld", das alle Karten aus world_layout.json listet.
912. [P3] Erzeuge mit tools/world_stats.py einen Graphen der Verbindungen als SVG unter docs/world_graph.svg.
913. [P3] Lege Kachel-Varianten "_" mit Fußspuren an, damit oft gelaufene Wege nach 200 Schritten sichtbar ausgetreten wirken (nur Logik und Platzhalterkachel).

### Neue Routen in Veydal
914. [x] [P1] Baue die Route "Gloamwood" (de: Dämmerwald) westlich von Fernstair, 12 x 30 Kacheln, ein dichter Wald mit zwei Ebenen über Stufen, Ring 4 bis 7.
915. [x] [P1] Baue die Route "Quillbrook" (de: Federbach) zwischen Brindlewick und dem Südufer, ein Bachtal mit Furten aus "w", Ring 8 bis 11.
916. [x] [P1] Baue die Route "Brackwater Fen" (de: Brackfenn) östlich von Saltmarsh, ein Moor aus Stegen und Schilfinseln, Ring 12 bis 15.
917. [x] [P1] Baue die Route "Lantern Steps" (de: Laternenstufen) von Thornridge aus nach oben, eine Felsstiege mit fünf Terrassen und Laternen an jeder Stufe, Ring 10 bis 13.
918. [x] [P1] Verbinde Gloamwood mit Crowcrest über einen zweiten Eingang, damit Fernstair nicht der einzige Weg nach Norden bleibt.
919. [x] [P1] Plane jede neue Route mit mindestens einer Abkürzung, die erst nach einem Rätsel oder einer Ausrüstung öffnet und den Rückweg auf unter 20 Schritte kürzt.
920. [x] [P1] Setze auf jeder neuen Route mindestens drei Wanderer mit eigenem Team, die man nur durch Ansprechen herausfordert (sight bleibt 0).
921. [x] [P2] Gib Gloamwood eine Lichtung mit einer Quelle (Kachel "o") als Heilpunkt, damit lange Wege eine Pause haben.
922. [P2] Lege in Gloamwood einen umgestürzten Baumstamm als Brücke über eine Schlucht an, der nur von Süden begehbar ist.
923. [P2] Gib Quillbrook drei Furten, die bei Regen zu tiefem Wasser werden und dann nur mit dem Enterhaken über ein gespanntes Seil zu queren sind.
924. [P2] Lege in Quillbrook eine Mühle mit Wasserrad an, deren Rad man mit der Hebelstange anhält, um einen Durchgang unter dem Rad zu öffnen.
925. [P2] Baue in Brackwater Fen einen Steg-Irrgarten aus sechs Abzweigen, bei dem nur zwei Wege weiterführen und die anderen in Sackgassen mit Funden enden.
926. [P2] Lege in Brackwater Fen eine Schilfinsel an, die nur bei Ebbe (nach Gerätezeit 0 bis 6 Uhr und 12 bis 18 Uhr) trocken erreichbar ist.
927. [P2] Gib Lantern Steps an jeder Terrasse eine Laterne, die man anzündet und die danach als Rückkehrpunkt für die Kutsche dient.
928. [P2] Baue die Route "Hollowmere Shore" (de: Hohlseeufer) am Westufer des Sees, flach mit Kieselstrand und Reusen, Ring 6 bis 9.
929. [P2] Baue die Route "Copper Gulch" (de: Kupferschlucht) zwischen Thornridge und Lantern Steps, eine Schlucht mit Loren-Gleisen als Wege, Ring 11 bis 14.
930. [P2] Lass auf Copper Gulch stillgelegte Loren als Hindernisse stehen, die man mit der Hebelstange auf dem Gleis um vier Kacheln verschiebt.
931. [P2] Baue die Route "Windmere Ridge" (de: Windseegrat) oberhalb von Crowcrest, ein schmaler Grat mit Geröll und Windfeldern, Ring 9 bis 12.
932. [P2] Lass auf Windmere Ridge Windböen den Spieler bei Wetter "Wind" um eine Kachel zur Seite schieben, sichtbar angekündigt, ohne dass er abstürzt.
933. [x] [P2] Gib jeder neuen Route einen eigenen Namensschild-Text am Eingang mit Ringbereich und Biom, z. B. "Brackwater Fen, Moor, Ring 12 bis 15".
934. [x] [P2] Plane die neuen Routen so, dass jede in beide Richtungen spielbar ist und keine nur einen Ausgang hat.
935. [x] [P2] Lege auf Quillbrook einen Fischersteg mit Bank an, auf der man sitzen kann und die Uhr bis zur nächsten Tageszeit vorspult.
936. [P2] Baue zwischen Hollowmere Shore und Gloamwood einen versteckten Hohlweg, der erst nach dem Fund einer Wegskizze im Spiel auftaucht.
937. [P3] Baue die Endspiel-Route "Coldmoor" (de: Kaltmoor) im Norden, Ring 18 bis 24, nur mit Weg- und Geländelogik; Story-Anbindung gehört Bereich 4.
938. [P3] Gib Coldmoor Moorlöcher (Kachel "k"), die nach drei Schritten nachgeben und den Spieler zum letzten Steg zurücksetzen, ohne Schaden.
939. [P3] Baue die Endspiel-Route "Stillwater Terraces" (de: Stillwasserterrassen), Reisterrassen aus "w" auf sieben Stufen, Ring 20 bis 26.
940. [P3] Lass in Stillwater Terraces das Wasser pro Terrasse über Schieber umleiten, damit trockene Wege entstehen.
941. [P3] Baue einen Rundweg "Lakeloop" (de: Seerunde), der alle Ufer verbindet und beim ersten vollständigen Umlauf ein Andenken gibt.
942. [P3] Lege auf Windmere Ridge einen Aussichtspunkt an, der beim Ansehen drei entfernte Orte auf der Weltkarte als "gesichtet" markiert.
943. [P3] Gib Gloamwood eine Nachtvariante, in der Glühpilze einen sonst unsichtbaren Pfad zu einer Lichtung zeigen.
944. [P3] Baue in Copper Gulch ein Gleiskreuz mit drei Weichen, das man in der richtigen Reihenfolge stellt, damit eine Lore den Weg freigibt.
945. [P3] Lege auf Hollowmere Shore Treibholz an, das jeden Tag an einer anderen von vier Stellen liegt und einen kleinen Fund trägt.
946. [P3] Baue eine Kletterwand "Rookspire" (de: Krähennadel) an Crowcrest, die man mit Kletterpicke über drei Rankenwände "v" erklimmt.
947. [P3] Plane eine Wanderer-Route "Pilgrim's Way" (de: Pilgerpfad), die fünf Schreine auf vier Karten verbindet und am Ende einen Weg-Titel für die Statistik gibt.
948. [P3] Lass auf allen neuen Routen Hinweisschilder an Abzweigen die Richtung zu Heilpunkten zeigen.
949. [P3] Baue auf Brackwater Fen eine Vogelwarte, von der aus man durch Ansehen die Lage aller Funde der Karte auf der Minikarte für 10 Minuten sieht.

### Neue Orte und Siedlungen
950. [x] [P1] Baue den Ort "Wrenhollow" (de: Zaunkönigsgrund) am Ende von Quillbrook, ein Dorf in einem Talkessel auf drei Ebenen, verbunden durch Leitern.
951. [x] [P1] Baue den Ort "Copperfold" (de: Kupferfalt) am Rand von Copper Gulch, eine Bergbausiedlung mit Förderturm und Werkstatt.
952. [x] [P1] Gib jedem neuen Ort eine eigene Heilstelle mit eigener Form, z. B. Wrenhollow eine Wasserstelle unter einer Weide, Copperfold eine warme Grubenquelle.
953. [x] [P1] Lege in jedem neuen Ort einen Händler mit festem Sortiment aus data/items.json an, ohne Echtgeld-Bezug (Shop gehört Bereich Monetarisierung).
954. [x] [P1] Baue den Weiler "Reedhaven" (de: Schilfhafen) in Brackwater Fen, Häuser auf Pfählen, nur über Stege erreichbar.
955. [P2] Gib Wrenhollow ein Kartografen-Kontor, in dem man die Weltkarte gegen Funde erweitert und Kartierquoten abgibt.
956. [P2] Gib Copperfold eine Werkstatt, die Wanderer-Ausrüstung gegen Erze und Münzen verbessert (siehe Abschnitt Ausrüstung).
957. [P2] Gib Reedhaven einen Bootsmann als Fährhaltestelle der Seelinie (siehe Abschnitt Schnellreise).
958. [P2] Baue für jeden neuen Ort mindestens zwei betretbare Häuser mit eigenem Innenraum 10 x 8 Kacheln.
959. [x] [P2] Lege in Brindlewick einen Markt an, der an zwei Tagen pro Woche (Gerätezeit Mittwoch und Samstag) mit drei zusätzlichen Ständen erscheint.
960. [P2] Erweitere Thornridge um einen Gasthof als Kutschstation, mit Wirt und schwarzem Brett für Gerüchte über Funde.
961. [P2] Baue den Hof "Mossgate Farm" (de: Moostor-Hof) auf Hollowmere Shore, mit Feldern, die sich je nach Wochentag sichtbar verändern.
962. [x] [P2] Gib jedem Ort ein Ortsschild mit Name und Einwohnerzahl, z. B. "Wrenhollow, 34 Leute".
963. [P2] Lege in Copperfold einen Aufzug im Förderturm an, der zu Fuß betreten wird und zwei Ebenen der Siedlung verbindet.
964. [x] [P2] Gib Reedhaven einen Steg, an dem Reusen hängen, die man einmal am Tag leert und dabei einen Heiltrank oder Münzen findet.
965. [x] [P2] Baue in Wrenhollow eine Bibliothek, in der Bücher Hinweise auf versteckte Orte enthalten, gebunden an Flags, nicht an Questtexte.
966. [x] [P2] Lege in jedem Ort einen Brunnen oder Platz als Treffpunkt, an dem abends mehrere Leute stehen (siehe NPC-Leben).
967. [P2] Ergänze Brindlewick um einen zweiten Steg im Norden, an dem die Seelinie anlegt.
968. [P3] Baue die Einsiedelei "Hermit's Ledge" (de: Einsiedlerkante) auf Windmere Ridge mit einer einzigen Hütte und einem Fernrohr.
969. [P3] Baue die verlassene Siedlung "Emberlow" (de: Glutsenke) nahe Cinder Rift, nur Ruinen, mit fünf Funden zwischen eingestürzten Mauern.
970. [P3] Gib jedem Ort eine Glocke, deren Läuten zu jeder vollen Stunde (Gerätezeit) als kurzes Geräusch kommt.
971. [P3] Lass Häuser in Orten abends beleuchtete Fenster zeigen und nachts dunkle, als einfache Kachelvariante.
972. [P3] Baue in Copperfold einen Erzschuppen, in dem man gefundene Erze lagert und gegen Ausrüstungs-Teile tauscht.
973. [P3] Lege in Wrenhollow einen Garten an, in dem gepflanzte Beeren nach 24 Stunden Gerätezeit reif sind.
974. [P3] Gib jedem Ort eine Gedenktafel mit kurzer Ortsgeschichte, die als Lore-Eintrag im Kartenbuch landet.
975. [P3] Baue in Thornridge einen Uhrturm, dessen Zeiger die echte Uhrzeit zeigt und der die Tageszeit ansagt.
976. [P3] Lass in Reedhaven bei Hochwasser (Wetter Regen) einen Steg überflutet sein und den Umweg über die Dächer öffnen.
977. [P3] Plane in Orten Zäune und Gärten so, dass kein Ort ein rechteckiges Raster mit einer Mittelstraße ist (Regel aus docs/WORLD.md).

### Höhlen und Grotten
978. [x] [P1] Baue die Höhle "Mossmere Grotto" (de: Moosseegrotte) unter Gloamwood, zwei Ebenen, feucht mit Moosböden, Ring 6 bis 9.
979. [x] [P1] Baue die Höhle "Sablecove" (de: Zobelbucht), eine Meereshöhle an Brackwater Fen, deren innere Kammer nur bei Ebbe offen ist.
980. [x] [P1] Erweitere Murk Hollow um eine untere Ebene "Echo Gallery" (de: Echogalerie) mit langen Gängen, Ring 13 bis 16.
981. [x] [P1] Baue die Höhle "Kindle Vents" (de: Glutschlote) am Fuß von Cinder Rift, mit heißen Schloten, die im Takt von 4 Sekunden den Weg sperren.
982. [x] [P1] Zeige in jeder Höhle am Eingang, welche Ausrüstung drinnen gebraucht wird, als Symbol auf dem Schild.
983. [x] [P1] Gib jeder Höhle mit mehr als einer Ebene einen kurzen Rückweg (Leiter oder Seil) vom tiefsten Punkt zum Eingang, der erst von innen öffnet.
984. [P2] Lege in Mossmere Grotto Tropfsteine an, die man mit der Hebelstange abbricht, um eine Brücke über einen Bach zu schlagen.
985. [x] [P2] Lass in Sablecove die Gezeiten nach Gerätezeit alle sechs Stunden wechseln und zeige die nächste Ebbe auf einem Gezeitenstein am Eingang.
986. [P2] Lege in Echo Gallery Hall-Felder an, in denen ein Glockenschlag einen versteckten Gang als Umriss für 5 Sekunden zeigt.
987. [P2] Gib Kindle Vents drei Schlotreihen mit verschiedenem Takt (3, 4, 5 Sekunden), die man nacheinander durchquert.
988. [P2] Baue die Höhle "Hollowmere Geode" (de: Hohlseedruse) auf einer Seeinsel, voller Kristalle, die das Laternenlicht weiterwerfen.
989. [P2] Lass in jeder dunklen Höhle die Laterne einen sichtbaren Radius von 2 Kacheln haben und den Rest abdunkeln (Erweiterung des bestehenden Schattens).
990. [P2] Baue die Höhle "Copper Deep" (de: Kupfertiefe) unter Copperfold, ein Bergwerk mit vier Sohlen und Leitern dazwischen, Ring 12 bis 16.
991. [P2] Gib Copper Deep Stützbalken, die man nicht entfernen darf, und Geröllhalden, die mit Kletterpicke begehbar werden.
992. [x] [P2] Lege in jeder Höhle mindestens einen Rastplatz mit Lagerfeuer an, an dem man speichert, aber nicht heilt.
993. [x] [P2] Zeige beim Betreten einer Höhle den Namen und die aktuelle Ebene als Banner, z. B. "Copper Deep, Sohle 2".
994. [P2] Gib jeder Höhle eine eigene Tabelle in data/encounters.json mit Fokus auf Stone, Umbra und Lumen.
995. [x] [P2] Lege in Sablecove Muschelbänke an, die bei Ebbe einen Fund freigeben und bei Flut wieder verschwinden.
996. [P2] Baue in Echo Gallery eine Tropfwasser-Uhr, die bei Wartezeit von 30 Sekunden einen Spalt im Fels öffnet.
997. [P3] Baue die Endspiel-Höhle "Deeproot Hollow" (de: Tiefwurzelhöhle) unter Coldmoor, Ring 22 bis 28, mit Wurzelwänden "v".
998. [P3] Lass in Deeproot Hollow Wurzeln je nach Tageszeit Wege öffnen (tags zurückgezogen, nachts ausgebreitet).
999. [P3] Baue die "Wandering Grotto" (de: Wandergrotte), eine Höhle mit 5 Räumen, deren Anordnung jeden Tag aus dem Server-Datum neu gewürfelt wird.
1000. [P3] Gib der Wandering Grotto pro Tag einen Fund am Ende, ohne Serienzwang, verpasste Tage kosten nichts.
1001. [P3] Lege in Hollowmere Geode eine Kammer an, in der alle Kristalle gleichzeitig leuchten, wenn man vier Spiegel richtig stellt.
1002. [P3] Baue in Copper Deep eine gesperrte fünfte Sohle mit einem Schild "Später" als Anschluss für Corvane-Erze.
1003. [P3] Zeige in Höhlen Fledermaus-Geräusche und Tropfen als Ambient-Punkte, nicht als Gegner.
1004. [P3] Lass in Mossmere Grotto Leuchtmoos nach Berührung 60 Sekunden leuchten und so den Weg zurück markieren.
1005. [P3] Baue in Kindle Vents eine Schmiede-Kammer, in der ein Amboss einen festen Fund gibt, wenn man alle drei Schlotreihen ohne Treffer schafft.
1006. [P3] Gib jeder Höhle eine Kartierquote, die erst bei 100 Prozent ein Andenken freischaltet.
1007. [P3] Baue in Sablecove einen Unterwasser-Durchgang nur als Gang hinter einem Wasserfall, der zu Fuß begehbar ist.

### Rätsel-Dungeons
1008. [x] [P1] Baue den Dungeon "Bellstone Ruins" (de: Glockenstein-Ruine) nördlich von Gloamwood, fünf Räume, in denen Glocken in einer an der Wand gezeichneten Reihenfolge geläutet werden.
1009. [x] [P1] Baue den Dungeon "Brackwater Sluice" (de: Brackschleuse) in Brackwater Fen, sechs Räume, in denen drei Schleusen den Wasserstand in Stufen hoch und runter stellen.
1010. [x] [P1] Baue den Dungeon "Lanternwell" (de: Laternenbrunnen) unter dem Leuchtturm von Brindlewick, fünf Räume mit Spiegeln, die einen Lichtstrahl auf Ziel-Kristalle lenken.
1011. [x] [P1] Baue den Dungeon "Shatterfloor Mine" (de: Splitterboden-Mine) unter Copperfold, zwei Stockwerke, in denen rissiger Boden "k" nach einmaligem Betreten einbricht und ins untere Stockwerk führt.
1012. [x] [P1] Setze das Schieben von Felsblöcken "B" um: Spieler drückt gegen den Block, der Block rutscht eine Kachel, wenn dahinter frei ist, mit Rückgängig-Knopf pro Raum.
1013. [x] [P1] Setze Druckplatten "P" um, die gedrückt bleiben, solange ein Block oder der Spieler darauf steht, und eine Tür über open_flag steuern.
1014. [x] [P1] Gib jedem Rätselraum einen "Raum zurücksetzen" Eintrag im Menü, der Blöcke und Schalter auf den Anfang stellt.
1015. [P2] Gib Bellstone Ruins im letzten Raum ein Glockenrätsel mit fünf Glocken, dessen Reihenfolge auf drei Wandbildern in früheren Räumen verteilt ist.
1016. [x] [P2] Lass falsch geläutete Glocken in Bellstone Ruins nur die Reihe zurücksetzen und keinen Kampf auslösen.
1017. [P2] Baue in Brackwater Sluice einen Raum, in dem bei hohem Wasser Kisten schwimmen und als Trittsteine dienen.
1018. [P2] Baue in Brackwater Sluice einen Raum, in dem bei niedrigem Wasser ein Fund am Grund erreichbar wird.
1019. [P2] Gib Lanternwell drehbare Spiegel mit vier Stellungen, die man durch Ansprechen um 90 Grad dreht.
1020. [P2] Baue in Lanternwell einen Raum mit zwei Strahlen, die zwei Kristalle gleichzeitig treffen müssen.
1021. [P2] Gib Shatterfloor Mine eine Kammer, in der man den Weg so plant, dass man jeden rissigen Boden genau einmal betritt.
1022. [P2] Baue den Dungeon "Gloamwood Maze" (de: Dämmerwald-Irrgarten), einen Heckengarten mit 8 Kreuzungen, in dem Wegzeichen an Bäumen die Richtung verraten.
1023. [P2] Lass im Gloamwood Maze die Wegzeichen nachts anders stehen als tags, und nur eine der beiden Lesarten führt zum Ziel.
1024. [P2] Baue den Dungeon "Tidebell Tower" (de: Gezeitenglockenturm) auf einer Seeinsel, vier Stockwerke, deren Treppen sich je nach Gezeitenstand anders verbinden.
1025. [P2] Setze in jedem Dungeon am Ende einen Hüter-Raum mit einem Hüter-NPC, der ein Andenken als Belohnung gibt (Kampf mit ihm nur durch Ansprechen).
1026. [x] [P2] Zeige im Dungeon-Banner beim Betreten die Zahl der gelösten Räume, z. B. "Lanternwell 3/5".
1027. [x] [P2] Gib jedem Dungeon eine Hinweistafel am Eingang, die nach drei gescheiterten Versuchen eines Raums einen Tipp freigibt.
1028. [x] [P2] Lass Türen, die ein gelöstes Rätsel geöffnet hat, dauerhaft offen bleiben (gespeichert in world_state).
1029. [x] [P2] Gib jedem Dungeon eine eigene Tabelle in data/encounters.json mit niedriger Rate 0.06, damit Rätsel nicht ständig unterbrochen werden.
1030. [x] [P2] Setze in Rätselräumen keine Begegnungsfelder, nur in Fluren zwischen den Räumen.
1031. [x] [P2] Zeige in jedem Rätselraum beim ersten Betreten eine Zeile mit dem Ziel des Raums, z. B. "Bringe das Licht zu beiden Kristallen".
1032. [P3] Baue den Endspiel-Dungeon "Inkwell Depths" (de: Tintenfasstiefe), zehn Räume, die alle vorher gelernten Rätselarten kombinieren, Ring 25 bis 32.
1033. [P3] Gib Inkwell Depths einen Raum, in dem Blöcke, Druckplatten und Spiegel gemeinsam genutzt werden.
1034. [P3] Lege für jeden Dungeon eine Bestzeit-Messung an, die in den Statistiken (Records) steht.
1035. [P3] Baue in Tidebell Tower ein Stockwerk, das nur bei Flut und nur nachts begehbar ist.
1036. [P3] Gib Bellstone Ruins eine Geheimkammer, die man öffnet, wenn man alle fünf Glocken in umgekehrter Reihenfolge läutet.
1037. [P3] Baue in Shatterfloor Mine eine Lorenbahn, auf der man eine leere Lore auf einen Prellbock schiebt, um eine Weiche umzulegen.
1038. [P3] Gib jedem Dungeon einen "Spiegel-Modus" nach dem ersten Abschluss, in dem die Räume seitenverkehrt sind und ein neuer Fund wartet.
1039. [P3] Baue einen Raum in Lanternwell, in dem der Strahl nur bei Tageslicht von oben einfällt (Tageszeit Tag).
1040. [P3] Lege eine Rätsel-Sammlung im Kartenbuch an, die jede gelöste Rätselart mit kleiner Skizze auflistet.
1041. [P3] Baue einen Rätselraum mit Gewichten, bei dem zwei Druckplatten zusammen mit Block und Spieler gleichzeitig belegt sein müssen.
1042. [P3] Gib Gloamwood Maze einen zweiten Ausgang zu Bellstone Ruins, der nur über die Nacht-Lesart erreichbar ist.
1043. [P3] Lege eine Online-Bestzeit pro Dungeon und Woche in die Rangliste, über die bestehende Ranglisten-Schnittstelle.

### Wanderer-Ausrüstung zu Fuß
1044. [x] [P1] Füge die Ausrüstung "Wading Boots" (de: Watstiefel) hinzu, die Gehen auf seichtem Wasser "w" erlaubt, mit gear: true in data/items.json.
1045. [x] [P1] Füge die Ausrüstung "Pry Bar" (de: Hebelstange) hinzu, mit der man Schleusenräder dreht, Loren schiebt und Gitter anhebt.
1046. [x] [P1] Füge die Ausrüstung "Rope Ladder" (de: Strickleiter) hinzu, die man an markierten Kanten festmacht, um in Schächte hinab zu klettern, und die dort dauerhaft hängen bleibt.
1047. [x] [P1] Füge die Ausrüstung "Plank Bundle" (de: Bretterbündel) hinzu, mit der man an Stellen "Y" ein Brett über eine Lücke legt, dauerhaft gespeichert.
1048. [x] [P1] Ergänze tests/unit/test_gear.gd so, dass keine Ausrüstung den Spieler über Wasser oder Lücken ohne Bodenkontakt bewegt und keine Animation "fly", "glide" oder "ride" heißt.
1049. [x] [P1] Ändere die Animation des Enterhakens in Overworld.gd so, dass die Figur sich Hand über Hand an einem gespannten Seil entlang zieht, die Füße am Seil, nie frei in der Luft.
1050. [x] [P1] Gib jeder Ausrüstung im Rucksack eine Seite mit Bild, Kurztext und den Kachelzeichen, an denen sie wirkt.
1051. [x] [P2] Füge die Ausrüstung "Rubbing Charcoal" (de: Pausstift) hinzu, mit der man verwitterte Steintafeln durchpaust und versteckte Inschriften als Hinweis lesbar macht.
1052. [x] [P2] Füge die Ausrüstung "Survey Glass" (de: Peilglas) hinzu, die beim Ansehen in eine Richtung bis 6 Kacheln entfernte Funde als Punkt auf der Minikarte zeigt.
1053. [x] [P2] Gib dem Peilglas eine Abklingzeit von 20 Sekunden, damit es kein Dauer-Radar wird.
1054. [P2] Baue in Copperfold eine Werkstatt, die die Laterne auf Stufe 2 (Radius 3 Kacheln) und Stufe 3 (Radius 4 Kacheln) verbessert.
1055. [P2] Verbessere den Enterhaken in der Werkstatt auf "Long Line" (de: Langleine), die 5 statt 3 Kacheln überbrückt.
1056. [P2] Verbessere die Kletterpicke in der Werkstatt auf "Twin Picks" (de: Doppelpicke), die auch hohe Klippen mit zwei Kacheln Höhe erlaubt.
1057. [P2] Lege für jede Verbesserung feste Kosten in Münzen und Erzen fest, z. B. Laterne Stufe 2 für 1500 Münzen und 3 Kupfererz.
1058. [P2] Füge die Erze "Copper Ore" (de: Kupfererz) und "Moonstone" (de: Mondstein) als Funde in Höhlen hinzu, nur nutzbar für Werkstatt-Verbesserungen.
1059. [P2] Baue ein Ausrüstungs-Rad im Feldmenü, das per langem Druck auf A die passende Ausrüstung für das Feld vor dem Spieler vorschlägt.
1060. [x] [P2] Lass die passende Ausrüstung automatisch wirken, wenn der Spieler nur eine besitzt, die an dieser Stelle passt.
1061. [x] [P2] Zeige vor einer noch gesperrten Stelle ein graues Symbol der benötigten Ausrüstung, damit man sich die Stelle merkt.
1062. [x] [P2] Gib jede neue Ausrüstung an einem festen Ort im Spiel aus, nachvollziehbar in docs/WORLD.md eingetragen (Gebiet, Geber, Flag).
1063. [x] [P2] Füge die Ausrüstung "Tide Chart" (de: Gezeitentafel) hinzu, die im Menü die nächste Ebbe und Flut nach Gerätezeit anzeigt.
1064. [P2] Ergänze WorldValidator.gd um eine Prüfung, dass jede Ausrüstung vor der ersten Stelle erreichbar ist, an der sie gebraucht wird.
1065. [x] [P2] Halte die Gesamtzahl der Ausrüstung in Veydal bei höchstens 10 Stücken, damit das Ausrüstungs-Rad auf eine Bildschirmseite passt.
1066. [P3] Füge die Ausrüstung "Crampons" (de: Steigeisen) für vereiste Geröllfelder in Coldmoor hinzu, die das Rutschen auf Eis verhindern.
1067. [P3] Baue rutschige Eisflächen in Coldmoor, auf denen der Spieler ohne Steigeisen bis zum nächsten Hindernis rutscht.
1068. [P3] Füge die Ausrüstung "Field Easel" (de: Feldstaffelei) hinzu, mit der man an Aussichtspunkten eine Skizze anlegt, die als Bild im Kartenbuch landet.
1069. [P3] Gib der Laterne Stufe 3 die Wirkung, verwitterte Wandzeichen in dunklen Höhlen ohne Pausstift lesbar zu machen.
1070. [P3] Lass Ausrüstung Abnutzungsspuren im Symbol zeigen, je öfter sie benutzt wurde (nur Kosmetik, kein Verschleiß).
1071. [P3] Baue eine Ausrüstungs-Statistik in Records: Anzahl Seilquerungen, Kletterstellen, gelegte Bretter.
1072. [P3] Füge die Ausrüstung "Walking Staff" (de: Wanderstab) hinzu, der beim Halten von B das Gehtempo um 50 Prozent erhöht, ohne Reiten oder Fahrzeug.
1073. [P3] Lass den Wanderstab auf Stegen und in Höhlen das Gehtempo nicht erhöhen, damit Rätsel ruhig bleiben.
1074. [P3] Gib jedem Ausrüstungsstück eine kurze Szene beim ersten Erhalt, in der die Figur es zu Fuß vorführt.
1075. [P3] Lege einen Ausrüstungs-Ständer im Leuchtturm an, an dem alle gesammelten Stücke sichtbar hängen.
1076. [P3] Baue für die Strickleiter eine Höchstzahl von 12 Ankerpunkten in Veydal und zeige die belegten in der Weltkarte.
1077. [P3] Ergänze LEGAL.md um die neue Ausrüstungsliste mit dem Satz, dass keine davon Fliegen, Gleiten oder Reiten erlaubt.

### Geheimnisse und versteckte Gegenstände
1078. [x] [P1] Verteile auf jeder bestehenden und neuen Außenkarte 3 bis 5 versteckte Funde über das neue Feld "secrets", sichtbar nur als leichtes Glitzern alle 4 Sekunden.
1079. [x] [P1] Zeige pro Karte im Kartenbuch "Funde x/y", damit Spieler wissen, ob noch etwas fehlt.
1080. [x] [P1] Lass versteckte Funde nur Gegenstände aus data/items.json geben, keine Echtgeld-Währung.
1081. [x] [P1] Ersetze die bisherigen Fund-Schilder (reed_find, gallery_find, nook_find) durch Einträge im Feld "secrets" und behalte die Flags für alte Spielstände.
1082. [x] [P1] Gib jeder neuen Route einen Geheimgang hinter einer verdächtig glatten Felswand, der beim Ansehen mit A öffnet.
1083. [x] [P1] Ergänze WorldValidator.gd so, dass jeder Fund erreichbar ist und keine zwei Funde dieselbe Flag teilen.
1084. [x] [P2] Lege 12 "Waymarker Stones" (de: Kartografensteine) in Veydal an, alte Steine mit einem Symbol, die beim Ansehen gezählt werden.
1085. [x] [P2] Gib für 4, 8 und 12 gefundene Kartografensteine je ein Andenken.
1086. [P2] Verstecke 8 "Lost Sketches" (de: verlorene Skizzen), die jeweils eine Ecke der Weltkarte mit einem geheimen Ort zeigen.
1087. [P2] Lass jede verlorene Skizze genau einen versteckten Ort freischalten, der vorher nicht auf der Weltkarte stand.
1088. [x] [P2] Baue an fünf Stellen Grabhügel, an denen man nur mit dem Pausstift eine Inschrift liest, die auf einen vergrabenen Fund in der Nähe zeigt.
1089. [x] [P2] Lege vergrabene Funde an, die man an einer Stelle mit lockerem Boden durch Ansehen mit A ausgräbt, ohne Spirling-Hilfe.
1090. [P2] Gib jedem Dungeon einen versteckten Raum, der auf der Raumzählung nicht erscheint.
1091. [x] [P2] Lass Funde in Schilf und Farn bei Wetter Wind sichtbarer werden (Glitzern alle 2 Sekunden).
1092. [P2] Verstecke in Orten 10 verlegte Alltagsdinge (Schlüssel, Brille, Pfeife), die man dem Besitzer zurückbringt und dafür einen kleinen Lohn bekommt.
1093. [x] [P2] Baue an drei Stellen eine Bank mit Blick auf den See, auf der man sitzt und nach 10 Sekunden ein Spirling-Geräusch und einen Hinweis erhält.
1094. [P2] Lege einen geheimen Pfad hinter dem Leuchtturm an, der nur nachts bei Leuchtfeuer sichtbar ist.
1095. [P2] Gib jeder Höhle eine Nische, die man nur mit Laterne Stufe 2 sieht.
1096. [x] [P2] Ergänze die Statistik um "Funde gesamt" und "Geheimnisse gesamt" pro Region.
1097. [x] [P2] Lass einen Fund nach dem Aufheben als ausgefülltes Kreuz auf der Minikarte stehen.
1098. [P3] Baue ein Geheimnis-Kapitel im Kartenbuch mit 20 Rätselbildern, die jeweils auf einen Ort zeigen, ohne Namen.
1099. [P3] Lege einen Fund an, der nur erscheint, wenn man 100 Schritte rückwärts ohne Kampf auf Lakeloop gegangen ist.
1100. [P3] Verstecke eine Spieluhr in Emberlow, die beim Aufziehen eine Melodie spielt, die man in der Bibliothek von Wrenhollow nachschlagen kann.
1101. [P3] Baue einen Fund, der nur bei Vollmond (Gerätedatum nach Mondkalender) auf Hollowmere Shore liegt.
1102. [P3] Lege in jeder Region einen "Kartografen-Schatz" an, dessen Lage aus allen 12 Kartografensteinen zusammengesetzt wird.
1103. [P3] Gib versteckten Funden eine Seltenheit (gewöhnlich, selten, besonders) mit festen Anteilen 70, 25 und 5 Prozent pro Region.
1104. [P3] Baue eine Flaschenpost-Kette aus fünf Flaschen, die an verschiedenen Ufern antreiben und zusammen einen Ort beschreiben.
1105. [P3] Lass einen versteckten Raum in Bellstone Ruins nur öffnen, wenn das Team gerade fünf verschiedene Elemente hat.
1106. [P3] Baue ein Geheimnis, das nur bei Gewitter in Windmere Ridge erscheint: ein Blitzstein mit einem Fund.
1107. [P3] Lass einen Fund in Gloamwood nur sichtbar sein, wenn der Spieler 30 Sekunden still steht.

### Begegnungstabellen
1108. [x] [P1] Lege Tabellen in data/encounters.json für jede neue Route, Höhle und jeden Dungeon an, mit Ringbereich passend zur Kartenreihenfolge.
1109. [x] [P1] Erweitere das Format jeder Tabelle um "ground" je Eintrag (fern, reeds, scree, water, cave), damit Farn, Schilf und Geröll auf derselben Karte verschiedene Spirlings haben.
1110. [x] [P1] Setze die Grundrate für Routen auf 0.12, für Moore und Höhlen auf 0.10 und für Dungeons auf 0.06.
1111. [x] [P1] Ergänze EncounterTable.gd um eine Schutzzeit von 6 Schritten nach jedem Kampf, in der keine neue Begegnung kommt.
1112. [x] [P1] Verteile die 21 bestehenden Spirlings so, dass jede Grundform auf mindestens zwei Karten vorkommt und jede Entfaltungsstufe nur auf späten Karten selten wild auftritt.
1113. [x] [P1] Setze Riptail, Thornback und Smoldrake als seltene Einträge (Gewicht 5) auf Brackwater Fen, Gloamwood und Kindle Vents.
1114. [x] [P1] Ergänze WorldValidator.gd um eine Prüfung, dass in jeder Tabelle die Gewichte zusammen mindestens 50 ergeben und kein Ringbereich die Kartenreihenfolge um mehr als 4 Ringe überspringt.
1115. [x] [P1] Zeige im Spirlog-Tracker pro Karte zusätzlich, auf welchem Grund (Farn, Schilf, Geröll, Wasser, Höhle) eine Art vorkommt.
1116. [P2] Füge "water" Begegnungen für seichtes Wasser "w" hinzu, die man nur mit Watstiefeln erreicht.
1117. [P2] Gib jeder Tabelle eine Spalte "weather" (z. B. rain: Tide und Bloom x1.5), die mit dem Wettersystem verrechnet wird.
1118. [P2] Gib jeder Karte eine feste "Leitart", die 40 Prozent der Begegnungen stellt, damit jeder Ort einen klaren Charakter hat.
1119. [P2] Lege für jede Karte eine seltene "Gastart" mit Gewicht 3 an, die sonst nur in einer anderen Region lebt.
1120. [P2] Setze Obsidroth und Duskdigger als seltene Einträge mit Gewicht 4 in Copper Deep und Echo Gallery.
1121. [P2] Setze Glimmerax als seltenen Eintrag mit Gewicht 4 auf Windmere Ridge bei Gewitter.
1122. [P2] Setze Kelphound und Lumenewt als seltene Einträge mit Gewicht 4 in Sablecove bei Flut.
1123. [P2] Setze Tempestrel als seltenen Eintrag mit Gewicht 3 auf Coldmoor.
1124. [P2] Gib Endspiel-Karten (Coldmoor, Stillwater Terraces, Deeproot Hollow) Ringbereiche von 18 bis 28, damit das Spiel nach Akt I weiterwächst.
1125. [P2] Ergänze tools/balance_sim.gd um eine Prüfung, dass die Ringbereiche der Tabellen zur erwarteten Teamstärke an der Kartenposition passen.
1126. [P2] Lass Begegnungen auf Wegen "_" nie auftreten, damit Tipp-Laufen auf Pfaden ruhig ist.
1127. [P2] Gib jeder Höhlenebene eigene Ringbereiche, tiefer heißt plus 2 Ringe.
1128. [P2] Erzeuge eine Übersicht docs/ENCOUNTERS.md aus data/encounters.json mit einem Skript tools/encounter_table.py.
1129. [P2] Ergänze test_map_checks.gd um einen Test, der jede Tabelle 10000 Mal würfelt und prüft, dass jede Art mit Gewicht über 0 vorkommt.
1130. [P2] Zeige im Spirlog-Tracker für noch nie gesehene Arten nur "???" und den Grund, nicht den Namen.
1131. [P3] Lege "Wochen-Tabellen" an: je Kalenderwoche (Server-Datum) eine Karte mit einer zusätzlichen Art mit Gewicht 10, ohne Verpassens-Strafe.
1132. [P3] Gib Spirlings, die man auf der Karte schon oft getroffen hat (über 30 Mal), ein leicht geringeres Gewicht, damit Abwechslung entsteht.
1133. [P3] Lege eine Tabelle "lakeloop_full" an, die nur nach vollständigem Umlauf der Seerunde für 10 Minuten gilt.
1134. [P3] Gib jeder Tabelle ein optionales Feld "hushed_bonus", damit nahe Rissen gedämpfte Spirlings häufiger sind.
1135. [P3] Baue Begegnungsfelder "*" (Blumen) auf Mossgate Farm mit einer eigenen kleinen Bloom-Tabelle.
1136. [P3] Lege eine Tabelle für das Hausdach von Reedhaven an, auf dem nur Gale-Spirlings vorkommen.
1137. [P3] Ergänze die Tabellen um "season" Einträge, die mit Season.gd zusammenwirken, ohne neue Fest-Logik zu bauen.
1138. [P3] Gib Höhlen nachts keine Änderung, Außenkarten aber nach der bestehenden DayCycle-Gewichtung.
1139. [P3] Lege für jede Route einen "Ruhestein" an, an dem man mit A die Begegnungsrate dieser Karte für 5 Minuten auf 0 setzt, kostenlos.
1140. [P3] Ergänze die Statistik um "häufigste Begegnung pro Karte".
1141. [P3] Baue ein Datenformat für Corvane-Tabellen, das neue Arten per Platzhalter-ID zulässt, die der Validator bis zur Freigabe überspringt.

### Wetter in der Welt
1142. [x] [P1] Baue scripts/core/WeatherCycle.gd, das pro Region und 6-Stunden-Block aus dem Server-Datum ein Wetter würfelt (klar, Regen, Nebel, Wind, Gewitter), für alle Spieler gleich.
1143. [x] [P1] Lege die Wetter-Anteile pro Biom in data/weather.json fest, z. B. Moor: klar 40, Regen 30, Nebel 25, Gewitter 5.
1144. [x] [P1] Zeige das Wetter in der Welt zuerst als schlichte Farbtönung und einfache Punkte in UITheme-Farben; der eigentliche Stil kommt aus Bereich 6.
1145. [x] [P1] Füge in Display and access einen Schalter "Wetter" hinzu, der das Wetter ausschaltet und überall "klar" setzt.
1146. [P2] Lass Regen in Quillbrook und Reedhaven Furten zu tiefem Wasser machen und Stege überfluten, mit Umweg als Alternative.
1147. [P2] Lass Nebel auf Coldmoor und in Gloamwood die Minikarte ausblenden, die Weltkarte aber nicht.
1148. [P2] Lass Wind auf Windmere Ridge und Lantern Steps Windfelder aktivieren, die den Spieler eine Kachel schieben.
1149. [P2] Lass Gewitter auf Windmere Ridge Blitzsteine aufladen, die dann als Lichtquelle für ein Rätsel dienen.
1150. [P2] Verrechne das Wetter in EncounterTable.gd mit der neuen Spalte "weather" der Tabellen.
1151. [P2] Zeige das aktuelle Wetter und das des nächsten Blocks in der Weltkarte neben dem Ortsnamen.
1152. [P2] Lass NPCs bei Regen unter Dächern stehen und eigene Regen-Sätze sagen.
1153. [P2] Gib jedem Wetter ein Ambient-Geräusch über Sound.gd mit eigener Lautstärke in den Einstellungen.
1154. [P2] Lass Wetter nur auf Karten mit "outdoor": true wirken; Räume, Höhlen und Risse bleiben unverändert.
1155. [P2] Ergänze tests/unit um test_weather.gd, das prüft, dass gleiches Datum und Region immer dasselbe Wetter ergibt.
1156. [P2] Ergänze Online.gd um einen Weg, das Wetter offline aus der letzten Server-Zeit fortzuschreiben, ohne Fehler.
1157. [P2] Lass Pfützen nach Regen 30 Minuten lang auf Wegen stehen und dort Funde aus Tide-Spirlings glitzern.
1158. [P3] Füge in Coldmoor das Wetter "Schnee" hinzu, das Fußspuren für 60 Sekunden zeigt.
1159. [P3] Lass Nebel in Brackwater Fen versteckte Stege sichtbar machen, die bei klarem Wetter unter Wasser liegen.
1160. [P3] Gib dem Leuchtturm von Brindlewick bei Nebel ein Leuchtfeuer, das im See einen Weg für die Fähre zeigt.
1161. [P3] Baue einen Regenbogen nach Regen auf Hollowmere Shore, an dessen Ende für 10 Minuten ein Fund liegt.
1162. [P3] Lass Wind Blätter in Gloamwood so wehen, dass sie für kurze Zeit eine versteckte Kachel freilegen.
1163. [P3] Ergänze das Kartenbuch um ein Wettertagebuch, das jede erlebte Wetterart pro Karte abhakt.
1164. [P3] Gib für alle Wetterarten auf allen Außenkarten erlebt ein Andenken "Weathered Compass".
1165. [P3] Lass Gewitter in Brindlewick die Fischer früher nach Hause gehen.
1166. [P3] Lege eine Wetter-Vorhersage beim Wirt in Thornridge an, die die nächsten drei Blöcke nennt.

### Tageszeit in der Welt
1167. [x] [P1] Erweitere DayCycle.gd um ein Signal "phase_changed", auf das Karten, NPCs und Türen reagieren.
1168. [x] [P1] Ergänze MapData.gd um "phase_only" für NPCs, Schilder und Blöcke (dawn, day, dusk, night), damit Dinge nur zu einer Tageszeit da sind.
1169. [x] [P1] Zeige die aktuelle Tageszeit klein neben dem Ortsbanner und in der Weltkarte als Symbol.
1170. [P2] Lass Läden in Orten von 7 bis 20 Uhr Gerätezeit offen sein und nachts eine Klingel für einen müden Händler mit kleinerem Sortiment haben.
1171. [P2] Lass die Seelinie der Fähre nur von 6 bis 22 Uhr fahren und nachts einen Nachtfischer übersetzen, der mehr Zeit braucht.
1172. [P2] Öffne in Lantern Steps nachts eine Tür, die tags zu ist, weil die Laternen dann den Weg zeigen.
1173. [P2] Baue an drei Orten Nachtblüher, die nur in der Dämmerung blühen und dann einen Fund geben.
1174. [P2] Lass die Bank am Fischersteg auf Wunsch bis zur nächsten Phase vorspulen, nur für die Spielwelt, nicht für Server-Ereignisse.
1175. [P2] Gib dem Vorspulen eine Sperre, damit Tagesfunde und Wochen-Ereignisse weiter nach Server-Datum laufen.
1176. [P2] Ergänze docs/WORLD.md um eine Tabelle, was auf welcher Karte zu welcher Tageszeit anders ist.
1177. [P2] Lass Außenkarten in der Dämmerung eine eigene Musik-Variante spielen, wenn music_dusk gesetzt ist.
1178. [P2] Ergänze test_world_extras.gd um Tests für phase_only bei allen vier Phasen.
1179. [P3] Lass Sterne in klaren Nächten auf Windmere Ridge als Sternbilder erscheinen, die man im Kartenbuch einträgt.
1180. [P3] Baue ein Sternbild-Verzeichnis mit 8 eigenen Sternbildern und eigenen Namen.
1181. [P3] Lass in Copperfold die Schicht im Bergwerk um 6 und 18 Uhr wechseln, mit anderen Arbeitern.
1182. [P3] Lass in Gloamwood bei Morgengrauen Tau auf den Farnen liegen, der Funde sichtbarer macht.
1183. [P3] Gib Brindlewick einen Sonnenaufgangs-Moment am Steg, der ein Foto für den Fotomodus vorschlägt.
1184. [P3] Lass Kinder in Orten nur tagsüber spielen und abends nach Hause laufen.
1185. [P3] Ergänze die Einstellung "Tageszeit fest auf Tag" als Alternative zum Ausschalten.
1186. [P3] Gib Spielern mit Zeitzonenwechsel eine Meldung und rechne die Phase sauber neu, ohne Doppelfunde.

### Schnellreise zu Fuß
1187. [x] [P1] Baue die "Lake Line" (de: Seelinie): Großvater Aldo und ein zweiter Fährmann bringen den Spieler per Boot zwischen Brindlewick, Hollowmere Shore, Reedhaven und Quillbrook. (Hollowmere Shore kommt als Haltestelle dazu, sobald die Karte aus 928 gebaut ist.)
1188. [x] [P1] Zeige jede Fahrt als kurze Szene mit Ruderboot und Abblende, der Spieler sitzt im Boot, kein Spirling trägt ihn.
1189. [x] [P1] Baue die "Valley Coach" (de: Talkutsche) als Kutsche mit Kutscher zwischen Brindlewick, Thornridge, Copperfold und Wrenhollow, nur als Szene, nicht steuerbar.
1190. [x] [P1] Schalte Haltestellen der Seelinie und der Talkutsche erst frei, wenn man den Ort einmal zu Fuß erreicht hat.
1191. [x] [P1] Verbinde die bestehende Reise im Menü (travel_targets) mit Fähre und Kutsche: im Menü erscheinen Rastplätze, Haltestellen werden nur am Steg oder an der Station gewählt.
1192. [P2] Gib Fahrten einen kleinen Preis in Spielmünzen (Fähre 50, Kutsche 100), damit Laufen weiter Sinn ergibt.
1193. [P2] Lass die erste Fahrt jeder Linie kostenlos sein.
1194. [P2] Baue Abkürzungen als einseitige Leitern, die man von oben herunterlässt, z. B. in Fernstair, Crowcrest und Lantern Steps.
1195. [P2] Mache die angezündeten Laternen auf Lantern Steps zu Rückkehrpunkten der Menü-Reise.
1196. [P2] Ergänze die Reiseliste um Ortsnamen, Region und einen Hinweis "zu Fuß x Karten entfernt".
1197. [P2] Lege eine Fahrplan-Tafel an jeder Haltestelle an, die Abfahrtszeiten nach Gerätezeit zeigt (alle 10 Minuten).
1198. [P2] Lass während der Fahrt keine Begegnungen und keine Kämpfe stattfinden.
1199. [P2] Ergänze WorldValidator.gd um eine Prüfung, dass jede Haltestelle auch zu Fuß erreichbar ist.
1200. [P2] Baue einen Steg-Anleger auf der Seeinsel von Hollowmere Geode, der nur über die Seelinie erreicht wird und so bewusst eine Fährfahrt verlangt.
1201. [P2] Lass Fährleute und Kutscher bei Wetter Gewitter nicht fahren und das freundlich ansagen.
1202. [P2] Ergänze tests/unit um test_travel.gd, das jede Linie, jeden Preis und jede Sperre bei Gewitter prüft.
1203. [P3] Baue eine "Copper Cart" (de: Grubenlore) als Szene in Copper Deep, die zwischen Sohle 1 und Sohle 4 fährt, nachdem man sie repariert hat.
1204. [P3] Gib der Kutsche einen Plausch mit dem Kutscher, der pro Fahrt einen von 20 Hinweisen auf Funde gibt.
1205. [P3] Lass Fahrgäste in der Fähre sitzen, die je nach Ziel andere Sätze sagen.
1206. [P3] Baue ein Fahrkarten-Heft im Rucksack, das jede gefahrene Strecke abstempelt.
1207. [P3] Gib für alle Strecken abgestempelt ein Andenken.
1208. [P3] Lass die Fähre nachts mit einer Laterne am Bug fahren und einen anderen Weg über den See nehmen.
1209. [P3] Lege einen Wanderer-Rastplatz pro neuer Route an, der nach Benutzung in die Menü-Reise aufgenommen wird.
1210. [P3] Baue die Möglichkeit, eine Fahrt abzubrechen, solange das Boot noch am Steg liegt.
1211. [P3] Bereite die Seelinie so vor, dass später eine Linie nach Corvane angehängt wird (siehe Abschnitt Corvane).

### NPC-Leben in Orten
1212. [x] [P1] Ergänze NPC.gd um einen Tagesplan (Liste aus Phase, Karte, x, y), damit Leute morgens, tags, abends und nachts an anderen Orten stehen.
1213. [x] [P1] Ergänze NPC.gd um kurze Gehwege (Liste von Feldern), die Leute langsam abgehen, mit Halt, wenn der Spieler im Weg steht.
1214. [x] [P1] Gib jedem Ort mindestens sechs Leute mit Tagesplan, davon zwei, die zwischen Orten pendeln. (Die fünf Veydal-Orte; der Corvane-Kai bekommt seine Leute mit dem Corvane-Ausbau.)
1215. [x] [P1] Lass Leute nach dem Heilen eines Risses andere Sätze sagen, über Flags aus Bereich 4, ohne neue Story zu schreiben.
1216. [x] [P1] Stelle sicher, dass NPCs mit Tagesplan nie einen Warp, eine Tür oder einen Rätselblock dauerhaft versperren (Validator-Prüfung).
1217. [P2] Baue in Brindlewick Fischer, die morgens zum Steg gehen und abends mit Fang zurückkommen.
1218. [P2] Baue in Copperfold Bergleute, die zur Schicht in den Förderturm gehen und dann von der Karte verschwinden.
1219. [P2] Lass Kinder in Orten Fangen spielen, als zwei NPCs, die sich gegenseitig auf einem festen Rundweg folgen.
1220. [P2] Gib Leuten kurze Sprechblasen ohne Gespräch (z. B. "Schöner Tag!"), die erscheinen, wenn man an ihnen vorbeigeht.
1221. [P2] Lass Leute bei Regen Schirme tragen und bei Wind ihre Hüte festhalten, als eigene Sprite-Zustände in Platzhalterform.
1222. [P2] Gib jedem Ort ein Gerüchte-Brett, das täglich (Server-Datum) einen von 30 Hinweisen auf Funde oder seltene Begegnungen zeigt.
1223. [P2] Lass Händler morgens ihren Stand aufbauen und abends abbauen, sichtbar als zwei Kachelzustände.
1224. [P2] Gib Wanderern auf Routen nach dem Kampf einen Platz in einem Ort, an dem man sie abends wiederfindet.
1225. [P2] Lass Leute auf den Spieler reagieren, wenn er öfter als 10 Mal mit ihnen geredet hat (eigener Satz).
1226. [P2] Gib jedem Ort einen Ortskundigen, der beim Ansprechen die nächsten drei unentdeckten Orte auf der Weltkarte als Umriss zeigt.
1227. [P2] Baue eine Nachtwache in Brindlewick, die nachts mit Laterne über die Stege geht.
1228. [P2] Lass Leute in Häusern abends am Tisch sitzen und nachts schlafen (andere Haltung, anderer Satz).
1229. [x] [P2] Ergänze tests/unit um test_npc_schedule.gd, das prüft, dass jeder Tagesplan auf begehbaren Feldern liegt.
1230. [P3] Baue einen reisenden Händler, der jeden Tag in einem anderen Ort steht und ein wechselndes Sortiment aus drei Gegenständen hat.
1231. [P3] Lass den reisenden Händler über das Gerüchte-Brett ankündigen, wo er morgen steht.
1232. [P3] Gib Orten Geburtstage einzelner Leute nach Gerätedatum, an denen sie anders gekleidet sind und etwas verschenken.
1233. [P3] Baue eine Dorfmusik auf dem Platz von Wrenhollow am Samstagabend mit drei Musikanten.
1234. [P3] Lass Leute untereinander kurze Gespräche führen, die man im Vorbeigehen als zwei Sprechblasen sieht.
1235. [P3] Gib Wanderern auf Routen Rastzeiten, in denen sie sitzen und nicht kämpfen wollen.
1236. [P3] Lass Bewohner nach 100 Prozent Kartierquote eines Ortes einen Dank-Satz sagen.
1237. [P3] Baue einen Postboten, der zwischen Brindlewick und Thornridge läuft und dem man Briefe für Leute in anderen Orten mitgeben kann.
1238. [P3] Gib dem Postboten 10 kleine Botengänge, die nur aus Hin- und Herlaufen bestehen, ohne Questlog-Eintrag.
1239. [P3] Lass Leute ihr Gehtempo dem Wetter anpassen (bei Regen schneller).
1240. [P3] Gib jeder Person ein Namensschild, das nach dem ersten Gespräch über dem Kopf erscheint, abschaltbar.
1241. [P3] Baue einen Fotografen in Thornridge, der Fotos aus dem Fotomodus an eine Wand im Gasthof hängt.

### Weltkarte und Kartieren
1242. [x] [P1] Baue eine Weltkarten-Ansicht im Pausenmenü unter "Map", die alle Karten aus data/world_layout.json als Felder mit Verbindungen zeigt.
1243. [x] [P1] Zeige auf der Weltkarte die eigene Position, Heilpunkte, Haltestellen und Rissorte als feste Symbole.
1244. [x] [P1] Zeige unbekannte Karten als leeres Pergament und gesichtete, aber nicht besuchte Karten als Umriss.
1245. [x] [P1] Speichere pro Karte, welche Kacheln der Spieler schon gesehen hat (Radius 3 um ihn), in GameState als Bitfeld "map_cells".
1246. [x] [P1] Zeige pro Karte eine "Kartierquote" in Prozent auf der Weltkarte und im Banner beim Betreten.
1247. [x] [P1] Lass die Weltkarte per Tippen auf einen Ort eine Detailansicht mit Funde x/y, Wetter, Tageszeit und vorkommenden Arten öffnen.
1248. [x] [P1] Halte die Weltkarte in 144x256 bedienbar: Zoomstufen 1x und 2x, Wischen zum Verschieben, Knopf "Hier".
1249. [P2] Gib für 100 Prozent Kartierquote einer Karte eine kleine Belohnung (Münzen oder Heiltrank) und ein Häkchen.
1250. [P2] Gib für 100 Prozent Kartierquote einer Region ein Andenken "Surveyor's Seal".
1251. [P2] Lass die Kartierquote bei Höhlen pro Ebene getrennt zählen.
1252. [P2] Schließe nicht begehbare Kacheln (Fels, Wasser ohne Ausrüstung) aus der Quote aus, damit 100 Prozent immer erreichbar sind.
1253. [P2] Ergänze WorldValidator.gd um eine Prüfung, dass 100 Prozent Kartierquote auf jeder Karte erreichbar ist.
1254. [P2] Zeige auf der Weltkarte Wanderer, gegen die man noch nicht gekämpft hat, als offene Punkte.
1255. [P2] Zeige auf der Weltkarte gesperrte Stellen mit dem Symbol der nötigen Ausrüstung.
1256. [P2] Gib der Weltkarte einen Filter (Funde, Ausrüstung, Haltestellen, Wanderer), der per Knopf umschaltet.
1257. [P2] Zeige auf der Weltkarte den Weg zur gewählten Markierung als gestrichelte Linie über Karten hinweg.
1258. [P2] Lass die Weltkarte den Kartografen-Kontor in Wrenhollow als Ort nennen, an dem man Quoten abgibt.
1259. [P2] Öffne die Weltkarte zusätzlich über einen eigenen Knopf auf dem Bildschirm-Pad (Tasten-Belegung in den Einstellungen).
1260. [x] [P2] Ergänze tests/unit um test_world_map.gd, das Bitfeld, Quote und Speicherung prüft.
1261. [P3] Zeige auf der Weltkarte die Region Corvane als Umriss jenseits des Sees, gesperrt bis zur Freigabe.
1262. [P3] Lass den Spieler auf der Weltkarte eigene Ortsnamen für versteckte Orte vergeben, nur lokal angezeigt.
1263. [P3] Gib der Weltkarte einen Vergleich "Quote meiner Freunde" über die bestehende Freunde-Schnittstelle, nur als Zahl.
1264. [P3] Baue eine Kartenzeit-Anzeige, die zeigt, wie viele Minuten man insgesamt pro Karte war.
1265. [P3] Lass die Weltkarte Wegspuren der letzten 30 Minuten als blasse Linie zeigen.
1266. [P3] Exportiere die Weltkarte als Bild in den Fotomodus, ohne Spielerposition.
1267. [P3] Zeige auf der Weltkarte Aussichtspunkte, von denen aus andere Orte gesichtet werden können.
1268. [P3] Baue eine Kartenlegende als eigene Seite, die jedes Symbol erklärt.
1269. [P3] Gib der Weltkarte eine Vorlesehilfe für Bildschirmleser mit Ortsname, Quote und Richtung.

### Minikarte und Markierungen
1270. [x] [P1] Baue eine Minikarte oben rechts, 36 x 36 Pixel, die 12 x 12 Kacheln um den Spieler mit 3 Pixel pro Kachel zeigt.
1271. [x] [P1] Zeige auf der Minikarte Warps, Heilstellen und Wanderer als einzelne farbige Pixel aus der UITheme-Palette.
1272. [x] [P1] Füge in Display and access einen Schalter "Minikarte" (an, aus, nur draußen) hinzu.
1273. [x] [P1] Lass den Spieler auf der Weltkarte bis zu 30 eigene Markierungen mit 6 Symbolen setzen (Stern, Kreuz, Frage, Herz, Pfeil, Hammer).
1274. [P2] Zeige eigene Markierungen auch auf der Minikarte, wenn sie auf der aktuellen Karte liegen.
1275. [P2] Lass Markierungen eine kurze Notiz bis 24 Zeichen tragen, eingegeben über NameKeyboard.gd.
1276. [P2] Setze automatisch eine Markierung "Wiederkommen" an jeder Stelle, an der eine fehlende Ausrüstung den Weg sperrt.
1277. [P2] Entferne automatische Markierungen, sobald die Stelle mit der Ausrüstung genutzt wurde.
1278. [P2] Lass die Minikarte bei Nebel und in dunklen Höhlen ohne Laterne ausblenden.
1279. [P2] Zeige auf der Minikarte einen Pfeil am Rand, wenn die gewählte Markierung auf einer anderen Karte liegt.
1280. [P2] Lass die Minikarte per Tippen die Weltkarte öffnen.
1281. [P2] Halte die Minikarte von der sicheren Zone (SafeArea.gd) und vom Bildschirm-Pad frei.
1282. [P3] Gib der Minikarte eine Größe-Einstellung (klein 24 x 24, normal 36 x 36).
1283. [P3] Lass Markierungen über den Server-Speicherstand auf andere Geräte mitwandern.
1284. [P3] Erlaube, eine Markierung als Wanderkarte an einen Freund zu schicken, über die bestehende Geschenke-Schnittstelle.
1285. [P3] Gib der Minikarte eine Nordpfeil-Option für Spieler, die lieber mit Richtung spielen.
1286. [P3] Zeige auf der Minikarte in Dungeons nur bereits betretene Räume.

### Vorbereitung Corvane
1287. [x] [P1] Lege die Regionskennung "corvane" in MapData.gd und WorldValidator.gd an, sodass Karten mit region "corvane" geladen, geprüft und getrennt gezählt werden.
1288. [x] [P1] Baue die Karte "corvane_quay" (de: Corvane-Kai) als Ankunftshafen, 12 x 24 Kacheln, mit Heilstelle und Ausgang zu einem gesperrten Weg.
1289. [x] [P1] Verbinde den Fähranleger von Brindlewick mit corvane_quay über eine Fährfahrt, gesperrt durch das Flag "ferry_corvane_open", das Bereich 4 setzt.
1290. [x] [P1] Lege in data/world_layout.json Corvane als zweites Raster rechts neben Veydal an, mit der Fähre als einzige Kante.
1291. [P2] Lege die Kachelzeichen für Corvane fest: "r" Flussfurt, "M" Marktstand, "K" Krähenbaum, "Q" Kaimauer, dokumentiert in TilesetFactory.gd.
1292. [P2] Baue die Route "Rookfen Path" (de: Krähenfennpfad) als erste Corvane-Route, 12 x 30 Kacheln, Flussauen mit Furten, Ring 18 bis 22.
1293. [P2] Baue den Weg "Ferrymarsh Bend" (de: Fährmarschbogen) als zweite Corvane-Route, ein Flussbogen mit Treidelpfad, Ring 20 bis 24.
1294. [P2] Lege Begegnungstabellen für corvane_quay-Umgebung und Rookfen Path mit bestehenden Arten als Platzhalter an, mit Platzhalter-IDs für spätere Corvane-Arten.
1295. [P2] Plane die Stadt "Corvane Market" (de: Corvane-Markt) als Ort auf zwei Ebenen über einer Brücke, nur als Rohkarte ohne NPC-Handlung.
1296. [P2] Plane in Corvane eine Fährlinie auf dem Fluss als Schnellreise mit drei Anlegern.
1297. [P2] Plane in Corvane die Ausrüstung "River Pole" (de: Staken), mit der man zu Fuß über Stelzstege balanciert, nie schwimmt oder fliegt.
1298. [P2] Lege für Corvane eigene Wetter-Anteile in data/weather.json an (mehr Regen und Nebel, Herbst als Grundton).
1299. [P2] Ergänze die Weltkarte so, dass ein Regionswechsel als Umblättern im Kartenbuch erscheint (Funktion hier, Stil in Bereich 6).
1300. [x] [P2] Trenne die Kartierquote, Funde und Kartografensteine pro Region, damit Corvane eigene Zähler hat.
1301. [P2] Lege in docs/WORLD.md einen Abschnitt "Corvane, Kartenregeln" an: keine nummerierten Wege, Flusslauf als Leitlinie, Orte an Brücken.
1302. [P2] Ergänze tests/unit um test_corvane_prep.gd, das prüft, dass Corvane-Karten ohne Flag nicht betretbar sind.
1303. [P2] Bereite den Kai so vor, dass man jederzeit mit der Fähre nach Veydal zurückkommt, ohne Fortschrittsverlust.
1304. [P2] Halte alle Corvane-Karten in der Rohfassung unter 2 MB Gesamtgröße der neuen Kacheln für das APK-Budget (tools/apk_budget.sh).
1305. [x] [P3] Plane die Corvane-Höhle "Rook Vault" (de: Krähengewölbe) als Rätsel-Dungeon mit Krähenfedern als Schalter.
1306. [P3] Plane den Corvane-Ort "Saltmill" (de: Salzmühle) an der Flussmündung mit Gezeitenmühle.
1307. [P3] Plane eine Corvane-Route mit Treidelpfad, auf dem man ein Boot an einem Seil flussaufwärts zieht, zu Fuß.
1308. [P3] Plane die Kupferglanz-Grenze am Rand von Corvane als gesperrten Bergpass für Era III, nur als Schild und Felswand.
1309. [P3] Lege eine Liste "Corvane-Platzhalter" in docs/WORLD.md an, die jede Platzhalter-ID mit der späteren Art-Planung verknüpft.
1310. [P3] Plane Corvane-NPC-Tagespläne mit Marktzeiten (Markt 6 bis 14 Uhr).
1311. [P3] Plane einen Corvane-Aussichtsturm, von dem aus man ganz Corvane auf der Weltkarte sichtet.
1312. [x] [P3] Plane für Corvane 15 versteckte Funde und 12 Kartografensteine nach dem Veydal-Muster.
1313. [P3] Plane eine Kutschlinie in Corvane zwischen Markt und Saltmill.
1314. [P3] Plane den Fährweg nach Corvane mit einer Zwischenstation auf einer Insel, die man beim zweiten Besuch betreten kann.
1315. [P3] Bereite in WorldValidator.gd eine Prüfung vor, dass keine Corvane-Karte auf Veydal-Tabellen zeigt.
1316. [P3] Lege einen Debug-Schalter an, der "ferry_corvane_open" setzt, damit Tester Corvane vor der Story-Freigabe ansehen.

### Tests, Validierung und Zugänglichkeit
1317. [x] [P1] Ergänze tests/unit/test_map_checks.gd so, dass jede neue Karte geladen, ihr Rätsel per Testlösung gelöst und jeder Ausgang erreicht wird.
1318. [x] [P1] Lege für jedes Rätsel eine Lösungsfolge in tests/fixtures/puzzles/<map>.json an, die der Test abspielt.
1319. [x] [P1] Prüfe in CI mit tools/ip_check.sh alle neuen Orts- und Kartennamen gegen die Sperrliste.
1320. [P2] Ergänze einen Test, dass jede Ausrüstung nur auf ihren Kachelzeichen wirkt und auf allen anderen nichts tut.
1321. [P2] Ergänze einen Test, dass jede Karte über Fuß, Fähre oder Kutsche vom Start erreichbar ist, ohne Debug-Schalter.
1322. [P2] Ergänze einen Test für world_state, dass geschobene Blöcke und offene Schleusen nach Laden am selben Platz sind.
1323. [P2] Ergänze tools/screenshot.gd um je einen Screenshot pro neuer Karte in Deutsch und Englisch.
1324. [P2] Gib für Spieler mit Farbschwäche in Rätseln zusätzlich zur Farbe ein Symbol auf Kristallen und Druckplatten.
1325. [P2] Gib in Display and access eine Option "Rätselhilfe", die nach 2 Minuten im Raum den ersten Schritt zeigt.
1326. [P2] Lass zeitgebundene Rätsel (Schlote, Tropfwasser) per Einstellung "mehr Zeit" den Takt verdoppeln.
1327. [P2] Ergänze die deutschen Texte für alle neuen Orte, Schilder und Ausrüstung in tools/i18n/de_*.py und prüfe sie mit i18n_extract.py de --check.
1328. [P3] Lege eine Messung an, dass das Laden jeder neuen Karte auf dem Testgerät unter 150 Millisekunden bleibt.
1329. [P3] Ergänze einen Test, dass Wetter und Tageszeit nie einen Weg dauerhaft sperren (es gibt immer einen Umweg oder ein Warten).
1330. [P3] Ergänze einen Test, dass keine zwei NPCs mit Tagesplan je dasselbe Feld belegen.
1331. [P3] Gib jedem Rätselraum ein Bildschirmleser-Label mit Ziel und Zustand, z. B. "Spiegel 2 von 4 richtig".
1332. [P3] Ergänze den APK-Budget-Check um eine Grenze von 1 MB für alle neuen Kartendaten aus data/maps/.
1333. [P3] Lege eine Checkliste in docs/WORLD.md an, die jede neue Karte vor dem Merge abhakt (Validator, Test, Screenshot, Texte, Quote).
1334. [P3] Ergänze einen Test, dass jede Fährfahrt und Kutschfahrt bei fehlender Verbindung zum Server sauber abbricht und den Spieler am Start lässt.
