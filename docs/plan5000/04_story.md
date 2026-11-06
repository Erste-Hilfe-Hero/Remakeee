# Bereich 4: Story, Quests und Figuren

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 1335 bis 1779.

> **Auftrag für den umsetzenden Thread:** Ziel ist, aus "Mirelas Kartenbuch" eine vollständige Geschichte über drei Akte mit Finale und Postgame zu machen, mit Figuren, die sich wandeln, und Entscheidungen, die etwas bewirken. Betroffen sind data/quests.json, data/dialogue/*.json, ein neuer Ordner data/scenes/, scripts/core/Dialogue.gd, scripts/core/QuestLog.gd, die Dialog-Aktionen in scripts/overworld/Overworld.gd, das Dialogfeld in scripts/ui/ und tools/i18n/de_story.py. Fang mit dem Dialogsystem (Auswahl, Bedingungen) und dem Szenen-Player an, weil fast alle Story-Punkte darauf aufbauen, und schreibe dann die Brücke von Akt I zu Akt II. Neue Karten baut Bereich 3 (dieser Bereich liefert nur die Ortsliste und setzt Figuren, Schilder und Auslöser auf fertige Karten), Endgame-Systeme wie Wiederholungskämpfe oder Turm-Modi gehören in Bereich 8, Porträts, Dialogfeld-Grafik und Epochen-Übergaberituale stehen im Plan DESIGN_EPOCHS.md.

### Dialogsystem: Auswahl, Bedingungen und Ablauf
1335. [x] [P1] Dialog-Einträge bekommen ein Feld "choices" mit 2 bis 3 Antworten (Text, optional "flag", "action", "next"), das Dialogfeld zeigt sie als Liste unter der letzten Zeile und wartet auf einen Tipp.
1336. [x] [P1] Mit "next" springt eine Antwort auf einen anderen Schlüssel derselben Datei, damit kurze Verzweigungen ohne neuen Code möglich sind.
1337. [x] [P1] "after_flag" wird zusätzlich als Liste erlaubt; Dialogue.lines_for nimmt den letzten Eintrag, dessen Flag gesetzt ist, damit eine Figur über mehrere Kapitel neue Sätze hat.
1338. [x] [P1] Neues Feld "if" mit Bedingungen (flag, not_flag, has_item, has_species, has_element, party_size_min, chapter_min) entscheidet, ob ein Eintrag oder eine Antwort gezeigt wird.
1339. [x] [P1] Neue Aktion "set_var <name> <wert>" und "add_var <name> <zahl>" speichert Story-Zahlen (zum Beispiel kestra_trust) in GameState und im Spielstand.
1340. [x] [P1] Neue Aktion "battle <figur_id>" startet aus einem Dialog heraus einen Kampf auf dem Kampfbildschirm, damit Duelle mitten in einer Szene beginnen können.
1341. [x] [P1] Neue Aktion "scene <id>" spielt eine Zwischensequenz aus data/scenes/<id>.json ab und kehrt danach in den Dialog oder die Welt zurück.
1342. [x] [P1] DataValidator prüft jeden "next", jede "scene"-ID, jede Gegenstands-ID in "give_item" und jeden Spirling-Namen in "has_species" und meldet tote Verweise im CI.
1343. [x] [P1] Der Sprecher wird als eigenes Feld "speaker" geführt statt als "Name:" im Text, und der Name erscheint als Namensschild über dem Dialogfeld.
1344. [P2] Ein Verlauf zeigt die letzten 30 Dialogzeilen, erreichbar über ein Symbol am Dialogfeld, damit verpasste Sätze nachlesbar sind.
1345. [P2] Textgeschwindigkeit (langsam, normal, sofort) kommt in die Einstellungen und wird im Spielstand gespeichert.
1346. [P2] Inline-Steuerzeichen im Text: {p} macht 0,4 Sekunden Pause, {slow} und {/slow} verlangsamen die Schrift für ruhige Momente.
1347. [P2] Inline-Zeichen {shake} lässt das Dialogfeld kurz zittern, für Schreck- und Rissmomente, abschaltbar über "Bewegung reduzieren".
1348. [P2] Platzhalter {partner} setzt den Spitznamen oder Artnamen des ersten Spirlings im Team ein, {kestra_partner} den Namen von Kestras Zephlet.
1349. [P2] Platzhalter {pronoun_*} wählt anhand von tamer_look die passenden Fürwörter für die Spielfigur in Englisch und Deutsch.
1350. [P2] Jede Figur bekommt einen eigenen Sprech-Piepton (Tonhöhe und Länge in data/dialogue/_voices.json), abgespielt pro drittem Buchstaben, abschaltbar.
1351. [P2] Ein kleines Gefühlssymbol (Ausrufezeichen, Fragezeichen, Tropfen, Herz, Punkte) erscheint per Feld "emote" für 0,8 Sekunden über dem Kopf der sprechenden Figur.
1352. [P2] Ein "once_per_day"-Feld lässt Figuren täglich einen neuen Satz aus einer Liste sagen (Tageswechsel nach DayCycle), damit die Welt lebendig wirkt.
1353. [P2] Figuren können per Feld "night_lines" nachts andere Sätze sagen als am Tag.
1354. [P2] Neue Aktion "take_item <id> <anzahl>" nimmt Story-Gegenstände wieder ab, mit einer Prüfung, dass der Gegenstand vorhanden ist.
1355. [P2] Neue Aktion "give_spirling <art> <ring>" schenkt einen Spirling mit Namensabfrage, für Story-Geschenke wie Mirelas Gefährten.
1356. [P2] Neue Aktion "heal_party_story" heilt still ohne Ton, damit Szenen nach einem Bosskampf nicht durch den Heil-Jingle unterbrochen werden.
1357. [P2] Ein langer Tipp auf das Dialogfeld spult bereits gelesene Zeilen vor (gelesen wird pro Schlüssel im Spielstand vermerkt).
1358. [P2] Auswahlen merken sich die zuletzt gewählte Antwort pro Schlüssel, damit Wiederholungen schneller gehen.
1359. [P2] Die Aktionskette mit ";" bekommt "wait <sekunden>" und "sfx <name>", damit kleine Szenen ohne Szenendatei auskommen.
1360. [P3] Ein Dialog-Vorschauwerkzeug tools/dialogue_preview.gd spielt einen Schlüssel headless ab und listet alle Pfade samt Bedingungen.
1361. [P3] Ein Graph-Export (tools/dialogue_graph.py) schreibt alle Verzweigungen einer Datei als Textbaum, zum Prüfen langer Gespräche.
1362. [P3] Barrierefreiheit: Option "Dialog vorlesen" nutzt die Sprachausgabe des Geräts (DisplayServer.tts_speak), wo verfügbar.
1363. [P3] Option "Große Dialogschrift" verdoppelt die Schriftgröße im Dialogfeld und bricht Zeilen neu um.
1364. [P3] Die Antwortauswahl ist mit dem virtuellen Steuerkreuz bedienbar und hebt die gewählte Antwort mit einem Tintenpunkt hervor.
1365. [P3] Dialoge zeigen bei langen Sätzen automatisch eine zweite Seite statt abgeschnittenen Text, geprüft durch einen Test mit 200 Zeichen.
1366. [P3] Ein Zähler "talk_count_<npc>" wird pro Gespräch erhöht, damit Figuren auf häufige Besuche reagieren können.
1367. [P3] Optionale Figuren-Kommentare: Kestra oder Aldo melden sich per kurzer Einblendung, wenn die Spielfigur bestimmte Orte zum ersten Mal betritt.
1368. [P3] Unit-Tests für Dialogue.gd decken choices, if, after_flag-Listen und Platzhalter ab und laufen in tools/headless_check.sh.
1369. [P3] Dialoge mit Auswahl werden in BattleReplay und Spielstand-Export nicht mitgeschrieben, damit keine Story-Spoiler in geteilten Daten landen.

### Zwischensequenzen
1370. [x] [P1] Neuer Szenen-Player scripts/overworld/ScenePlayer.gd spielt Schritte aus data/scenes/<id>.json der Reihe nach ab und blockiert dabei die Steuerung.
1371. [x] [P1] Schritt "say": zeigt Dialogzeilen mit Sprecher, nutzt dieselben Steuerzeichen und Auswahlen wie normale Dialoge.
1372. [x] [P1] Schritt "move": bewegt eine Figur (NPC oder Spielfigur) Kachel für Kachel über eine Liste von Richtungen, mit PathFinder als Rückfall.
1373. [x] [P1] Schritt "face" und "emote": dreht Figuren und zeigt Gefühlssymbole, damit Gespräche lebendig wirken.
1374. [x] [P1] Schritt "fade" (in, out, Farbe, Dauer) und "wait" (Sekunden) für Übergänge.
1375. [x] [P1] Schritt "spawn" und "despawn" blendet Figuren nur für die Szene ein oder aus, ohne die Kartendatei zu ändern.
1376. [x] [P1] Ein Knopf "Überspringen" oben rechts springt ans Ende der Szene und führt dabei alle Flag-, Gegenstands- und Kampfschritte trotzdem aus.
1377. [x] [P1] Jede Szene setzt am Ende ein Flag "scene_<id>_seen", damit sie nur einmal automatisch läuft.
1378. [P2] Schritt "pan": schiebt die Kamera in ganzen Pixeln zu einer Kachel und zurück, ohne Glättung, passend zum Pixelraster.
1379. [P2] Schritt "music" wechselt oder stoppt die Musik mit Ausblendung, Schritt "sfx" spielt einen Effekt.
1380. [P2] Schritt "shake" lässt die Kamera 0,5 Sekunden wackeln, abschaltbar über "Bewegung reduzieren".
1381. [P2] Schritt "flash" färbt den Bildschirm kurz hell, für Blitz und Rissöffnung, mit gedämpfter Variante für lichtempfindliche Spielende.
1382. [P2] Schritt "battle" startet einen Kampf auf dem Kampfbildschirm und setzt die Szene nach dem Kampf mit dem Ergebnis fort (Feld "on_win", "on_lose").
1383. [P2] Schritt "warp" bringt Spielfigur und Kamera auf eine andere Karte, ohne die Szene zu beenden.
1384. [P2] Schritt "card": eine Titelkarte mit Kapitelname in Tinte auf Pergament, 2 Sekunden lang, zum Start jedes Kapitels.
1385. [P2] Schritt "letter": zeigt eine Seite aus Mirelas Kartenbuch als Vollbild mit handgeschriebener Schrift und Tintenflecken.
1386. [P2] Schritt "tint": legt einen Farbton über die Welt (zum Beispiel grau für die Stille), Werte pro Szene in Hex.
1387. [P2] Auslöser: Kartendateien bekommen eine Liste "scene_triggers" (Kachel, Szenen-ID, Bedingung), die beim Betreten einer Kachel feuert.
1388. [P2] Auslöser beim Betreten einer Karte ("on_enter") für Ankunftsszenen, zum Beispiel beim ersten Anlegen der Fähre in Corvane.
1389. [P2] Szenen dürfen sich nicht während eines Kampfes, eines Menüs oder einer Echo-Melodie starten; der Player wartet, bis die Welt frei ist.
1390. [P2] Ein Szenen-Validator prüft, dass jede Figur, Karte, Musik und jeder Kampf einer Szene existiert, und läuft im CI.
1391. [P2] Bricht die App während einer Szene ab, startet die Szene beim nächsten Laden am Anfang neu, ohne doppelte Belohnungen.
1392. [P2] Szenen werden im Online-Spielstand nur als gesehene Flags gespeichert, nie als Zwischenzustand.
1393. [P2] Ein Szenen-Debugmenü (nur in Debug-Builds) startet jede Szene direkt, für schnelles Testen.
1394. [P3] Ein Menüpunkt "Erinnerungen" im Kartenbuch spielt alle gesehenen Hauptszenen erneut ab, ohne Belohnungen.
1395. [P3] Schritt "silhouette": zeigt eine Figur als dunklen Umriss vor hellem Grund, für Rückblenden auf Mirela.
1396. [P3] Rückblenden laufen in einem eigenen Look (Sepia-Tönung über die aktuelle Palette) und setzen keine Flags außer dem Gesehen-Flag.
1397. [P3] Schritt "parallel" lässt zwei Bewegungen gleichzeitig laufen, zum Beispiel Kestra und die Spielfigur, die nebeneinander gehen.
1398. [P3] Schritt "spirling" lässt einen Spirling aus dem Team neben der Spielfigur erscheinen und eine kleine Hüpfbewegung machen.
1399. [P3] Schritt "cry" spielt den Ruf einer Spirling-Art über Cry.gd ab, für Momente, in denen ein stiller Spirling wieder ruft.
1400. [P3] Szenen bekommen ein Feld "min_era", damit eine Szene in späteren Epochen eine reichere Fassung haben kann, ohne die Grundszene zu ändern.
1401. [P3] Ein Text-Export aller Szenen für Lektorat und Übersetzung (tools/scenes_to_text.py).
1402. [P3] Eine Zeitmessung im Debug-Build zeigt die Länge jeder Szene; Hauptszenen sollen unter 90 Sekunden bleiben.
1403. [P3] Untertitel-Modus für Szenen ohne Text: kurze Beschreibung in eckigen Klammern (zum Beispiel [Donner]) für gehörlose Spielende.
1404. [P3] Option "Szenen automatisch abspielen" blättert Zeilen nach 2,5 Sekunden selbst weiter.

### Akt I: Feinschliff und Brücke zu Akt II
1405. [P1] Der tote Endpunkt "Chapter 5: Waiting for the Ferry" wird ersetzt: nach mirela_lamp und aldo_dock_told öffnet Aldo die Fähre selbst (Flag ferry_open).
1406. [P1] Neue Szene act1_finale im Leuchtturm: Aldo holt sein altes Ruder vom Dachboden und sagt, dass er die Fähre ein letztes Mal selbst fährt.
1407. [P1] Neue Szene ferry_crossing: Aldo rudert die Spielfigur über den See, erzählt in 6 Zeilen von Mirelas erster Überfahrt und zeigt den Riss am Nordhimmel.
1408. [P1] Das Fährschild in Brindlewick bekommt eine after_flag-Variante: "Crossings resume. Ferryman: Aldo." sobald ferry_open gesetzt ist.
1409. [P1] Die Lampenkammer-Szene mirela_lamp wird als Szene mit "letter"-Schritten und langsamem Text neu gebaut, statt nur Textzeilen.
1410. [P1] Die Prologszene bekommt Blitz, Donner, Rissöffnung über dem See und die drei Lichtspirlinge, die der Lampe folgen, als echte Szene.
1411. [P1] Bevor die Fähre fährt, verlangt die Brücke beide gestopften Rissherzen nicht, damit Akt II nicht an optionalen Kämpfen hängt (nur rifts und mirela_lamp zählen).
1412. [P1] Kestras Dock-Gespräch kestra_dock bekommt eine Auswahl ("Ich komme mit." / "Ich gehe allein."), die kestra_trust um 1 hebt oder nicht.
1413. [P1] Kapitelkarten (Schritt "card") werden für Prolog und Kapitel 1 bis 4 nachgerüstet, mit den Titeln aus quests.json.
1414. [P2] Warden Orrin bekommt nach dem Mend eine Rückschau: er erzählt, dass er Mirela vor 40 Jahren als Kind im Cinder-Hohlweg gesehen hat.
1415. [P2] Warden Maelis bekommt nach tide_heart_mended einen Satz über ein Lied, das sie aus dem Riss hört, als Hinweis auf die Echo-Melodie-Lore.
1416. [P2] Das Kind mit dem stillen Puddlet in Brindlewick bekommt eine after_flag-Variante: nach beiden Rissen ruft sein Puddlet wieder, mit Dank an die Spielfigur.
1417. [P2] Der Fischer erzählt nach rift_tide_sealed, dass die Fische wieder springen, und schenkt einmalig 2 Tonics.
1418. [P2] Der Ältestensatz in Thornridge ändert sich nach rift_cinder_sealed und deutet auf Orrins Rückkehr ins Dorf.
1419. [P2] Pell und Suri aus dem Cinder-Riss erscheinen nach dem Mend in Thornridge und reden über ihr neues Leben ohne Stille.
1420. [P2] Ilka in der Tide-Senke sagt nach dem Mend eine Vorhersage über einen "Riss, der zurückschaut", als Vorbote von Akt II.
1421. [P2] Tamsin in Murk Hollow erwähnt nach hollow_lamps, dass Mirela einst bei ihr Lampenöl gekauft hat, und dass sie nach Norden wollte.
1422. [P2] Ein Schild am Krähenkamm-Tarn zeigt nach kestra_spar eine Skizze von Kestra mit dem Satz "The tarn, before it froze. K."
1423. [P2] Nach der ersten gestopften Rissstelle zeigt eine kurze Szene, wie ein stiller Wildspirling in der Nähe wieder ruft (Schritt "cry").
1424. [P2] Kapitel 2 bekommt eine Zwischenmeldung nach dem ersten Mend ("One Rift mended. Kestra will hear of it."), damit die Reihenfolge frei bleibt und trotzdem erzählt wird.
1425. [P2] Der Hinweis auf den dritten Riss wird in Akt I zweimal gesät: Kestra am Dock und ein Wanderer in Crowcrest, der von Licht im Norden spricht.
1426. [P2] Die Hauptziele in quests.json bekommen Kurztexte für die Anzeige im Spiel und längere Texte für das Tagebuch (Feld "long").
1427. [P3] Rasten an der Rest Spring nach Akt I zeigt eine kleine Abendszene mit Aldo am Steg, einmal pro Kapitel.
1428. [P3] Lio und Bram am Krähenkamm bekommen je einen neuen Satz nach Akt I, der auf ihre eigenen Pläne deutet.
1429. [P3] Die Wanderer in Fernstair kommentieren, wenn die Spielfigur ein entfaltetes Partner-Spirling dabei hat.
1430. [P3] Nach Akt I schreibt Kestra einen Brief, der im Leuchtturm liegt, mit einer Liste von Spirlingen, die sie im Riss gesehen hat.
1431. [P3] Die Kartenhaus-Karten (map_house/maps) zeigen nach jedem Mend einen neuen Satz, wie sich die Karte verändert hat.
1432. [P3] Brindlewicks Ausrufer kündigt nach Akt I die Wiedereröffnung der Fähre an.
1433. [P3] Ein Satz der Rest-Spring-Hüterin verrät, dass Mirela die Quelle als erste kartiert hat.
1434. [P3] Die Szene ferry_crossing kann im Postgame am Steg wiederholt werden, als ruhige Überfahrt ohne Text.

### Akt II: Die Farben von Corvane
1435. [P1] Lege in docs/STORY.md eine Ortsliste für Akt II mit festen Karten-IDs an (corvane_landing, madderby, madderby_guild, woadfen, rain_rift, stillwater, mirror_rift, greyreach, wide_rift_edge), damit Bereich 3 die Karten passend baut.
1436. [P1] quests.json bekommt die Hauptziele von Akt II mit Kapiteln 6 bis 11 und dem Aktnamen "Act II: The Colours of Corvane".
1437. [P1] Kapitel 6 "The Landing": Ankunft in Corvane Landing, die Stille hat hier nicht nur Stimmen, sondern auch Farben aus den Spirlingen gezogen (Szene corvane_arrival).
1438. [P1] In Madderby, der Färberstadt, steht das Gildenhaus der Kartografen; Gildenmeisterin Ysolde Rennick nimmt die Spielfigur als Lehrling auf (Flag guild_joined).
1439. [P1] Kapitel 7 "Rain Rift": Warden Senna im Woadfen-Moor hört nur noch Regen; nach dem Duell wird der Riss gemeinsam gestopft (Flag rift_rain_sealed).
1440. [P1] Kapitel 8 "Mirror Rift": Warden Joral am Stillwater-Teich sieht im Riss nur sich selbst; das Duell und der Mend setzen rift_mirror_sealed.
1441. [P1] Die zwei Corvane-Risse sind in beliebiger Reihenfolge machbar, wie in Akt I, und das Ziel zeigt "(k/2)".
1442. [P1] Kapitel 9 "The Wide Rift": am Rand von Greyreach erreicht die Spielfigur den dritten Riss, der sich nicht stopfen lässt, weil kein Warden ihn von außen hält.
1443. [P1] Die Wende von Akt II: Ein Satz in Mirelas Handschrift ist in den Rand des Weiten Risses eingebrannt; Mirela ist die Hüterin von innen.
1444. [P1] Kapitel 11 "The Far Side": Ysolde erklärt, dass der Weite Riss ein zweites Ende in Ashmere hat; das Ziel führt zur Bergbahn nach Ashmere (Flag act2_end).
1445. [P2] Kapitel 10 "Veit": Veit Harrow, ein früherer Gildenkartograf, will Risse nicht stopfen, sondern "auslöschen", indem er ihre Karten verbrennt; erste Begegnung in Madderby.
1446. [P2] Veit duelliert die Spielfigur in Greyreach (Team: Shalebat Ring 24, Duskdigger Ring 25, Obsidroth Ring 27) und verschwindet danach Richtung Ashmere.
1447. [P2] Ysolde Rennick gibt der Spielfigur nach guild_joined einen Gildenausweis (Story-Gegenstand guild_seal), der Türen im Gildenhaus öffnet.
1448. [P2] Archivar Pim im Gildenhaus führt eine Kiste mit Mirelas Briefen; jeder gefundene Brief wird von ihm vorgelesen (Nebenquest letters).
1449. [P2] Warden Senna (Team: Riptail Ring 20, Tempestrel Ring 21, Kelphound Ring 22) hat einen Vorgesprächssatz und zwei Sätze nach dem Mend über das Wetter ohne Stille.
1450. [P2] Warden Joral (Team: Lumenewt Ring 22, Glimmerax Ring 23, Verdantusk Ring 23) sagt nach dem Mend, dass er im Spiegel einmal eine ältere Frau mit Kompass gesehen hat.
1451. [P2] Jeder Corvane-Riss hat wie in Akt I ein optionales Rissherz (rain_heart, mirror_heart) als Mehrfachkampf mit dem Warden an der Seite.
1452. [P2] In Corvane sind gestille Wildspirlinge farblos dargestellt (Sprite mit Graustufen-Schaltung); gestopfte Risse geben den Spirlingen der Gegend ihre Farbe zurück.
1453. [P2] Zwei Hush-Wanderer in Woadfen (Figuren, die selbst verstummt sind) sprechen nur "..." bis rift_rain_sealed und erzählen danach ihre Geschichte.
1454. [P2] Kestra trifft die Spielfigur in Madderby wieder; sie kartiert die Farbschichten im Fluss und hat ihren Zephlet zu Tempestrel entfaltet.
1455. [P2] Nach rift_rain_sealed wird Kestras Tempestrel still (Szene kestra_tatter_hush); Kestra hält der Spielfigur vor, dass das Stopfen Riss-Spirlinge krank macht.
1456. [P2] Kapitel 9 löst die Frage: Ysolde zeigt in den Gildenakten, dass Riss-Spirlinge einen Anker-Bund brauchen, keinen offenen Riss; Kestra muss das selbst prüfen.
1457. [P2] Ein Tag-Kampf mit Kestra in Stillwater gegen zwei Hush-Wanderer setzt kestra_stillwater_tag und hebt kestra_trust um 1.
1458. [P2] Mirela-Seiten 7 bis 10 liegen in Corvane (Landing, Madderby-Dachboden, Woadfen, Greyreach) und führen den Seitenzähler im Kartenbuch auf "(k/10)" weiter.
1459. [P2] Ein Brief von Aldo kommt nach jedem Corvane-Riss per Fährboten an (3 Briefe, Flags aldo_letter_1 bis 3) und hält die Familie im Spiel.
1460. [P2] Ein Rastplatz in Madderby ist eine Färberquelle statt einer Heilstube, mit eigener Hüterin (Weda) und eigenem Satz.
1461. [P2] Der Gildensaal hat eine Wandkarte, die sich mit jedem gestopften Riss in Corvane neu einfärbt (Schild mit drei after_flag-Varianten).
1462. [P2] Am Rand des Weiten Risses steht eine verlassene Kartografenhütte, in der ein Tagebuch von Veit liegt, das seinen Verlust erklärt.
1463. [P2] Die Szene wide_rift_reveal zeigt Mirelas eingebrannten Satz "Still drawing. Still here. M." und endet mit einer Kapitelkarte.
1464. [P2] Nach act2_end bekommt die Spielfigur von Ysolde eine Empfehlung an die Graveur-Gilde in Ashmere (Story-Gegenstand guild_letter).
1465. [P2] Akt II hat einen eigenen Musik-Hinweis pro Kapitel in den Szenen (Feld "music"), mit den vorhandenen Stücken als Platzhalter, bis Bereich Musik neue liefert.
1466. [P2] Die Fähre zurück nach Brindlewick bleibt nach Akt II offen; Aldo sagt bei jedem Besuch etwas Neues zu den Funden aus Corvane.
1467. [P3] Ein Wanderer in Corvane Landing erzählt, dass das Wort "Corvane" in der alten Sprache "das Ufer, das färbt" bedeutet.
1468. [P3] Madderby hat drei Färberfamilien mit kleinen Szenen über ihre Spirlinge, die Farbstoff aus Blüten lösen.
1469. [P3] Der Weite Riss flackert bei Nacht stärker; nachts sagen Figuren in Greyreach andere Sätze (night_lines).
1470. [P3] Ein stiller Kartenzeichner in Woadfen malt nur graue Karten; nach rift_rain_sealed malt er wieder farbig und schenkt eine Skizze.
1471. [P3] Pim führt eine Liste "Was Mirela kartiert hat" und ergänzt nach jedem Fund eine Zeile.
1472. [P3] Ysolde erzählt auf Nachfrage (Auswahl) von ihrer Lehrzeit bei Mirela, mit drei verschiedenen Antworten.
1473. [P3] Senna und Joral treffen sich nach beiden Mends am Gildenhaus und sprechen über den Weiten Riss.
1474. [P3] Ein Kinderchor in Madderby singt nach act2_end die Echo-Melodie als Volkslied, ein Hinweis auf ihre Herkunft.
1475. [P3] Veits verlassene Werkstatt in Madderby ist nach Kapitel 10 betretbar und zeigt verbrannte Kartenreste als Schilder.
1476. [P3] Die Spielfigur kann in Greyreach eine eigene Skizze des Weiten Risses zeichnen (Auswahl aus drei Sätzen), die später in Akt III vorgelesen wird.
1477. [P3] Ein Kapitel-Rückblick nach act2_end fasst Akt II in 6 Zeilen zusammen und erscheint im Tagebuch.
1478. [P3] Die Rissherzen von Corvane geben je ein Andenken mit Lore-Text (rain_shard, mirror_shard), deren Werte Bereich Gegenstände festlegt.
1479. [P3] Die Bergbahn nach Ashmere fährt erst nach act2_end; vorher sagt der Bahnwärter einen Satz über Steinschlag.

### Akt III: Die Platten von Ashmere
1480. [P1] Lege in docs/STORY.md eine Ortsliste für Akt III mit festen Karten-IDs an (ashmere_station, cinderfold, gravers_hall, kiln_rift, saltglass, glass_rift, wide_rift_far, undrawn_1 bis undrawn_3) für Bereich 3.
1481. [P1] quests.json bekommt die Hauptziele von Akt III mit Kapiteln 12 bis 17 und dem Aktnamen "Act III: The Plates of Ashmere".
1482. [P1] Kapitel 12 "Ash and Ink": Ankunft im Aschehochland; in Cinderfold arbeiten Graveure, die Karten in Kupfer stechen, damit sie hundert Jahre halten.
1483. [P1] Kapitel 13 "Kiln Rift": Warden Tovan hält den Ofenriss halb geschlossen, aber seine Spirlinge sind schon still; Duell und Mend setzen rift_kiln_sealed.
1484. [P1] Kapitel 14 "Glass Rift": Wardenin Ilse in Saltglass ist ganz verstummt; der Mend setzt rift_glass_sealed und öffnet den Weg zum fernen Ende des Weiten Risses.
1485. [P1] Kapitel 15 "Veit's Plate": Veit hat in der Graveurhalle eine Platte gestochen, die den Weiten Riss samt allem dahinter löschen soll; die Spielfigur muss ihn aufhalten.
1486. [P1] Kapitel 16 "The Undrawn": Die Spielfigur betritt mit dem Gildensiegel das Ungezeichnete, das Land hinter den Rissen, drei kurze Abschnitte ohne fertige Ränder.
1487. [P1] Kapitel 17 "Where the Map Ends": Am Rand des Ungezeichneten wartet Mirela; das führt direkt ins Finale.
1488. [P2] Graveurmeister Halvard in der Graveurhalle nimmt den Empfehlungsbrief guild_letter an und erklärt, warum gestochene Karten Risse festhalten können.
1489. [P2] Warden Tovan (Team: Calderox Ring 32, Obsidroth Ring 33, Smoldrake Ring 31, Duskdigger Ring 32) spricht nach dem Mend über seinen Vater, der den Riss vor ihm hielt.
1490. [P2] Wardenin Ilse (Team: Leviarch Ring 34, Lumenewt Ring 33, Glimmerax Ring 34, Tempestrel Ring 33) kann nach dem Mend wieder singen und lehrt eine neue Strophe der Echo-Melodie.
1491. [P2] Kiln und Glass bekommen je ein Rissherz als Mehrfachkampf (kiln_heart, glass_heart), mit dem Warden als Partner.
1492. [P2] In Ashmere wirkt die Stille als Erstarrung: stille Wildspirlinge bewegen sich in der Welt nicht und haben ein Szenen-Symbol aus Asche.
1493. [P2] Veit erscheint in Cinderfold, erklärt seinen Plan offen und bietet der Spielfigur an mitzumachen (Auswahl, beeinflusst veit_respect).
1494. [P2] Der Kampf gegen Veit in der Graveurhalle ist ein 2 gegen 2 mit Kestra an der Seite gegen Veit und seinen Gehilfen Brann.
1495. [P2] Nach dem Kampf zerbricht die Platte nicht von selbst; die Spielfigur entscheidet, ob sie die Platte zerstört oder Veit sie selbst zerbrechen lässt (veit_choice).
1496. [P2] Mirela-Seiten 11 bis 14 liegen in Ashmere (Cinderfold, Kiln, Saltglass, Graveurhalle) und schließen das Kartenbuch auf 14 Seiten ab.
1497. [P2] Halvard sticht nach dem Fund aller 14 Seiten Mirelas Karte in Kupfer; diese Platte ist der Schlüssel, der das Ungezeichnete betretbar macht (Flag mirela_plate).
1498. [P2] Das Ungezeichnete hat keine Wildspirlinge, sondern "Skizzen": halb gezeichnete Spirlinge, die als stille Gegner im Mehrfachkampf auftreten (bestehende Arten mit Skizzen-Schaltung).
1499. [P2] Im Ungezeichneten zeichnet die Spielfigur Wege, indem sie an drei Stellen eine Echo-Melodie spielt; jede gelungene Melodie setzt einen Kartenrand (Flags undrawn_edge_1 bis 3).
1500. [P2] Im Ungezeichneten trifft die Spielfigur das Echo von Veits verlorenem Spirling, einer Mirkmole namens Ash; das ist wichtig für Veits Bogen.
1501. [P2] Kestra betritt das Ungezeichnete mit der Spielfigur und findet die Stelle, an der ihr Tempestrel geboren wurde (Szene kestra_origin).
1502. [P2] Die Ankunft in Ashmere mit der Bergbahn ist eine Szene, in der die Welt beim Übergang feiner gezeichnet wirkt; den Grafikwechsel liefert der Epochen-Plan, hier nur der Text.
1503. [P2] Ein Rastplatz in Cinderfold ist eine warme Quelle unter Basalt, Hüter Oswin, eigener Satz.
1504. [P2] Aldo schickt in Akt III einen letzten Brief, in dem er schreibt, dass er die Lampe nie mehr ausgehen lässt (aldo_letter_4).
1505. [P2] Kapitel 15 endet mit einer Szene, in der Veit am Weiten Riss sitzt und zum ersten Mal den Namen seines Spirlings sagt.
1506. [P2] Ilse und Tovan stellen sich nach beiden Mends am fernen Ende des Weiten Risses auf und halten ihn offen, damit die Spielfigur hindurch kann.
1507. [P2] Die Hauptziele in Akt III verweisen mit "where" auf genaue Orte, und das Ziel "Find all 14 pages" wird erst hier zur Pflicht, mit Hinweisen auf fehlende Seiten.
1508. [P3] Cinderfold hat einen Graveurlehrling, Nella, der die Spielfigur bittet, drei Landschaften zu beschreiben; die Antworten landen als Inschrift auf einer Platte.
1509. [P3] Die Graveurhalle zeigt alte Platten als Schilder mit Lore über frühere Risse in Ashmere.
1510. [P3] Ein Wanderer in Saltglass erzählt, dass das Glas der Ebene aus einem Riss vor 300 Jahren stammt.
1511. [P3] Tovans Vater, der alte Warden Harl, lebt noch und erzählt in einer Szene, wie Risse früher ohne Kampf gestopft wurden.
1512. [P3] Im Ungezeichneten stehen drei Erinnerungsorte, an denen Mirela 40 Jahre lang Spuren hinterlassen hat (Steinkreise, Skizzen, ein Lampenöltopf).
1513. [P3] Im Ungezeichneten fehlt die Musik; nur die Echo-Melodie und Schritte sind zu hören, umgesetzt per Schritt "music stop" in der Ankunftsszene.
1514. [P3] Brann, Veits Gehilfe, wechselt nach dem Kampf die Seite und arbeitet danach in der Graveurhalle.
1515. [P3] Die Spielfigur findet in Ashmere ihre eigene Skizze aus Greyreach wieder, wenn sie in Akt II eine gezeichnet hat, und Halvard liest sie vor.
1516. [P3] Eine Nebenszene zeigt Kestra und Halvard uneinig darüber, ob gestochene Karten Neues verhindern.
1517. [P3] Das Ungezeichnete wird nach jedem gezeichneten Rand ein wenig farbiger beschrieben (drei Varianten des Ankunftstextes).
1518. [P3] Kapitelkarten für Akt III zeigen eine kleine Platte statt Pergament als Hintergrund, nur als Text-Variante "Plate 12" bis "Plate 17".
1519. [P3] Ein Rückblick nach Kapitel 17 fasst Akt III im Tagebuch in 6 Zeilen zusammen.
1520. [P3] Saltglass hat einen stillen Leuchtturm, dessen Wärterin Aldo kennt; sie gibt einen Brief an Aldo mit (Flag saltglass_letter), der im Postgame zugestellt werden kann.
1521. [P3] Die Bergbahn zwischen Madderby und Ashmere hat einen Schaffner mit wechselnden Sätzen je nach Kapitel.
1522. [P3] Nach Kapitel 14 kommentieren Graveure in Cinderfold, dass die Asche zum ersten Mal seit Jahren nicht mehr fällt.
1523. [P3] Am Eingang zum Ungezeichneten steht eine Warnplatte der Graveure aus dem Jahr von Mirelas Verschwinden, mit ihrem Namen in der Liste der Vermissten.
1524. [P3] Halvard sticht nach rift_glass_sealed eine kleine Gedenkplatte für Ilses Jahre in der Stille und gibt sie ihr in einer kurzen Szene.

### Finale: Wo die Karte endet
1525. [P1] Das Finale ist eine durchgehende Szenenkette (finale_1 bis finale_5) am Rand des Ungezeichneten, ohne Speicherverbot, mit Rückkehrpunkt vor finale_1.
1526. [P1] Mirela erscheint als alte Frau mit ihrem Kartenbuch; sie hat das Ungezeichnete 40 Jahre lang gezeichnet, damit der Weite Riss nicht ganz aufreißt.
1527. [P1] Mirela erklärt den Nachhall: das Echo aller Spirlinge, die ihren Wanderer verloren haben, ist der Ursprung der Stille (Lore-Auflösung).
1528. [P1] Der Endkampf gegen den Nachhall ist ein Mehrfachkampf in drei Wellen (2, 3, dann 4 stille Spirlinge), mit Mirela als Partnerin in Welle 3.
1529. [P1] Nach dem Kampf spielt die Spielfigur eine lange Echo-Melodie (doppelte Länge) mit Mirelas Strophe; gelingt sie, verstummt der Nachhall und hört zu.
1530. [P1] Die Abschlusswahl hat drei Wege: "Bring her home", "Leave a gate" und, nur unter Bedingungen, "Two keepers" (siehe Abschnitt Entscheidungen).
1531. [P1] Nach dem Finale läuft eine Abspann-Szene mit Rückkehr nach Brindlewick, Aldo am Steg und einer Abschlusskarte mit allen gestopften Rissen.
1532. [P2] Scheitert die lange Echo-Melodie, kommt kein Game Over; Mirela summt mit, und der zweite Versuch ist um 20 Prozent langsamer.
1533. [P2] Verliert die Spielfigur den Endkampf, setzt die Szene vor Welle 1 neu an, mit geheiltem Team und einem Satz von Mirela.
1534. [P2] Kestra steht im Finale an der Seite der Spielfigur; ihr Satz vor dem Kampf hängt von kestra_trust ab (drei Varianten: unter 2, 2 bis 3, ab 4).
1535. [P2] Veit erscheint im Finale, wenn veit_respect mindestens 2 ist, und hält eine Welle lang die Skizzen ab (eine Welle weniger für die Spielfigur).
1536. [P2] Mirela spricht die Spielfigur mit Namen an und erkennt an tamer_look, dass sie ihr Enkelkind ist; ein eigener Satz pro Aussehen.
1537. [P2] Mirela fragt nach Aldo; die Antwortauswahl der Spielfigur (drei Sätze) bestimmt, wie Mirela im Abspann zu Aldo geht.
1538. [P2] Der Nachhall spricht vor dem Kampf mit vielen Stimmen in kurzen Sätzen, gesetzt mit {shake} und einer grauen Tönung.
1539. [P2] Der Partner-Spirling der Spielfigur hat im Finale einen eigenen Moment: er ruft als erster zurück, als der Nachhall verstummt (Schritt "cry").
1540. [P2] Der Abspann zeigt je nach gewähltem Weg eine von drei Schlussszenen am Leuchtturm.
1541. [P2] Nach dem Abspann wird das Flag story_complete gesetzt, das Ziel wechselt auf das Postgame, und der Titelbildschirm zeigt einen kleinen Kompass als Zeichen.
1542. [P2] Die Abspann-Szene zeigt alle Hüterinnen und Hüter, die die Spielfigur geweckt hat, in der Reihenfolge, in der sie geweckt wurden.
1543. [P2] Ein letzter Eintrag im Kartenbuch "Page 15" wird von der Spielfigur selbst geschrieben, aus drei Satzanfängen wählbar.
1544. [P2] Das Finale kann ab story_complete im Postgame über "Erinnerungen" erneut angesehen werden, ohne den gewählten Weg zu ändern.
1545. [P3] Vor dem Finale gibt es einen Ruhepunkt mit allen Verbündeten am Lagerfeuer im Ungezeichneten, jede Figur sagt einen Satz.
1546. [P3] Der Nachhall zeigt in Welle 2 Spirling-Arten, die die Spielfigur im Spiel freigelassen hat, wenn welche freigelassen wurden.
1547. [P3] Mirelas Partner-Spirling, ein sehr alter Wickit namens Glim, steht ihr im Finale bei.
1548. [P3] Die Abschlusskarte im Abspann zeigt die Namen der Orte in der Handschrift der Spielfigur, Mirelas und Kestras abwechselnd.
1549. [P3] Im Abspann werden besondere Momente des eigenen Spielstands genannt (erster Spirling, Zahl der gebondeten Arten, Spielzeit).
1550. [P3] Nach dem Abspann folgt eine kurze Nachszene mit Kestra am Kartenhaus, die einen neuen Riss im Süden skizziert, als Haken für spätere Teile.
1551. [P3] Ein stilles Spiel-Ende ohne Text ist in den Einstellungen wählbar (nur Bilder und Musik), für eine zweite Sichtung.
1552. [P3] Die Abspann-Szene liest Namen aus den Credits der Datei docs/legal und zeigt sie in Tinte.
1553. [P3] Ein Erfolg "Where the map ends" wird über Achievements.gd beim ersten Abschluss vergeben.
1554. [P3] Kehrt die Spielfigur nach dem Finale an den Rand des Ungezeichneten zurück, liegt dort Mirelas leerer Zeichenstein mit einer neuen Inschrift, die vom gewählten Ende abhängt.

### Kestra: Gegenstück mit eigenem Weg
1555. [P1] Kestra bekommt in docs/STORY.md eine Figurenbeschreibung: Kindheit am Krähenkamm, Zephlet "Tatter" kam vor 12 Jahren aus einem kleinen Riss, Ziel ist Verstehen statt Schließen.
1556. [P1] Eine Zahl kestra_trust (0 bis 6) wird bei sechs festen Momenten in Akt I bis III um 1 erhöht oder nicht, je nach Auswahl der Spielfigur.
1557. [P1] Kestras Zephlet wird zur Story-Figur "Tatter" mit Spitznamen im Team; Kestras Team wächst pro Akt um ein Mitglied (Akt II 4, Akt III 5 Spirlinge).
1558. [P1] Kestras zweites Duell findet in Madderby statt (Team: Tempestrel Ring 22, Glimmerax Ring 21, Shalebat Ring 21, Kelpup Ring 20), mit eigenem Vor- und Nachgespräch.
1559. [P1] Kestras drittes Duell steht am fernen Ende des Weiten Risses (Team mit 5 Spirlingen, Ring 34 bis 36); es ist kein Hindernis, sondern ein Abschiedsduell vor dem Ungezeichneten.
1560. [P1] Die Szene kestra_tatter_hush in Akt II zeigt Kestras größte Angst; die Spielfigur kann Tatter mit einer Echo-Melodie trösten, was kestra_trust um 1 hebt.
1561. [P1] Kestra ändert ihre Haltung sichtbar: in Akt I will sie Risse offen, in Akt II zweifelt sie, in Akt III sucht sie einen dritten Weg; jede Haltung hat eigene Sätze.
1562. [P2] Kestras Dialog im Kartenhaus bekommt nach jedem Akt eine neue Variante (after_flag-Liste mit act1_done, act2_end, story_complete).
1563. [P2] Kestra führt ein eigenes Skizzenbuch; nach jedem Treffen ist eine neue Seite davon im Kartenbuch der Spielfigur lesbar (Abschnitt "Kestra's sketches", 8 Seiten).
1564. [P2] Kestra hat eine Lieblingsantwort auf die Frage nach Mirela, die sich bis Akt III von Neid zu Bewunderung wandelt (drei Sätze).
1565. [P2] Kestras Tag-Kämpfe zählen für kestra_trust nur, wenn die Spielfigur gewinnt, ohne dass Kestras Spirlinge alle fallen.
1566. [P2] Im Ungezeichneten erzählt Kestra in der Szene kestra_origin, dass sie Tatter als Kind fand und nie jemandem gesagt hat, woher er kam.
1567. [P2] Kestra und Veit begegnen sich in Akt III; Kestra widerspricht ihm hart, und ihre Sätze zeigen, dass sie und die Spielfigur jetzt auf einer Seite stehen.
1568. [P2] Bei kestra_trust ab 5 schenkt Kestra vor dem Finale ihren alten Kompass als Andenken (kestra_compass), dessen Werte Bereich Gegenstände festlegt.
1569. [P2] Bei kestra_trust unter 2 kämpft Kestra im Finale nicht als Partnerin, sondern hält nur den Rückweg; sie sagt das in einer eigenen Szene ohne Vorwurf.
1570. [P2] Kestra hat einen Satz für jede Spirling-Art, die die Spielfigur zuerst zeigt, wenn sie ihr eine seltene Art vorstellt (Nebenquest show_kestra).
1571. [P2] Kestra reagiert auf den Iron-Oath-Modus mit einem eigenen Satz über Vorsicht, wenn er aktiv ist.
1572. [P2] Kestras Sprech-Piepton ist schneller und höher als der von Aldo, damit sie ohne Namensschild erkennbar ist.
1573. [P2] Kestra hat einen Kontaktmoment in jedem Kapitel ab Kapitel 6, auch wenn es nur ein kurzer Brief ist, damit sie nie lange aus der Geschichte fällt.
1574. [P2] Kestras Haltung zu Rissen wird im Tagebuch als kleine Skala "Open / Unsure / Third way" angezeigt, ohne Zahlen.
1575. [P2] Kestras Satz nach jeder Niederlage gegen die Spielfigur ändert sich je nach Akt und bleibt nie gleich.
1576. [P3] Kestra hat eine ältere Schwester, Rhea, in Corvane Landing, die erzählt, wie Kestra als Kind war.
1577. [P3] Kestra zeigt in Madderby, wie sie Farben aus Rissen mischt, eine kleine Szene ohne Kampf.
1578. [P3] Kestra kann nach dem Finale gefragt werden, welchen Weg sie gewählt hätte; ihre Antwort hängt vom Ende ab.
1579. [P3] Kestras Tatter entfaltet zu Tempestrel in einer eigenen Szene in Akt II statt still zwischen den Akten.
1580. [P3] Kestra hinterlässt in Akt II und III Wegmarken (gemalte Kompassrosen) an Orten, die die Spielfigur später findet, mit je einem Satz.
1581. [P3] Kestras Kartenhaus in Brindlewick wird im Postgame zu einem gemeinsamen Arbeitsraum mit einer Wand für beide Namen.
1582. [P3] Kestras Satz zum Abschied vor dem Ungezeichneten wird vorgelesen, wenn die Spielfigur später zur selben Stelle zurückkehrt.
1583. [P3] Kestra hat eine Abneigung gegen Murk Hollow, die sie in Akt I erwähnt und in Akt III mit einer Kindheitsgeschichte erklärt.
1584. [P3] Kestra fragt die Spielfigur einmal nach ihrem Lieblingsort in Veydal (Auswahl aus 4), und erwähnt die Antwort im Postgame wieder.

### Aldo und Mirela
1585. [P1] Aldo bekommt in jedem Kapitel einen neuen Satz im Leuchtturm (after_flag-Liste), damit Heimkehr sich lohnt.
1586. [P1] Mirela bekommt in docs/STORY.md eine Figurenbeschreibung mit Lebenslauf, Zeichenstil und dem Grund, warum sie 40 Jahre im Ungezeichneten blieb.
1587. [P1] Die Kartenbuch-Seiten 7 bis 14 erzählen Mirelas Zeit im Ungezeichneten in je 1 bis 2 Sätzen und decken die Lore schrittweise auf.
1588. [P1] Die Szene, in der Aldo und Mirela sich wiedersehen, hängt vom Ende ab, wird aber in jeder Fassung am Steg in Brindlewick gespielt.
1589. [P2] Aldo erzählt auf Nachfrage (Auswahl im Leuchtturm) drei Erinnerungen an Mirela, je nach Fortschritt freigeschaltet.
1590. [P2] Aldos altes Ruder ist ein Story-Gegenstand (aldo_oar), den die Spielfigur zu Beginn von Akt II mitnimmt und im Postgame zurückgibt.
1591. [P2] Aldo wird beim Rudern in ferry_crossing müde; die Spielfigur kann wählen, ob sie selbst rudert, und Aldo kommentiert das später.
1592. [P2] Mirelas Briefe an Aldo (Nebenquest letters, 6 Briefe) zeigen ihre Liebe zu ihm und ihre Zweifel, jeweils 2 bis 3 Zeilen.
1593. [P2] Im Ende "Leave a gate" bleibt Mirela im Ungezeichneten; Aldo bekommt im Postgame einen Brief von ihr pro Woche (Tageswechsel, 8 Briefe).
1594. [P2] Im Ende "Bring her home" wohnt Mirela im Leuchtturm; sie hat dort einen eigenen Platz am Kartentisch und neue Sätze.
1595. [P2] Mirela schenkt der Spielfigur nach dem Finale ihren Spirling Glim (Wickit, Ring 40) mit der Aktion give_spirling, in jedem Ende.
1596. [P2] Mirela kommentiert die Karten der Spielfigur und erkennt Orte, die sie selbst vor 40 Jahren gezeichnet hat.
1597. [P2] Aldo und Mirela führen im Postgame eine kleine Szene beim Abendessen, die sich nach Ende unterscheidet.
1598. [P3] Ein altes Foto im Leuchtturm (Schild) zeigt Aldo und Mirela jung; der Text ändert sich nach dem Finale.
1599. [P3] Aldo bringt der Spielfigur im Postgame bei, wie man die Lampe richtig putzt, eine Szene ohne Belohnung.
1600. [P3] Mirela hat einen Satz über jedes Element, den sie in ihrem Kartenbuch als Randnotiz hinterlassen hat.
1601. [P3] Mirela hält im Postgame Vorträge im Kartenhaus für Lehrlinge, mit wechselnden Themen pro Tag.
1602. [P3] Aldo bekommt einen Satz, falls die Spielfigur das Iron-Oath-Gelübde trägt, über das Durchhalten.
1603. [P3] Aldo erzählt vom Tag, als die Spielfigur geboren wurde, in einer Szene nach dem Finale.
1604. [P3] Mirelas Kompassrose ist ein wiederkehrendes Zeichen auf allen ihren Seiten und an drei verborgenen Orten in der Welt.

### Hüterinnen, Hüter und Nebenfiguren
1605. [P1] Jede Hüterin und jeder Hüter bekommt eine feste Form: Satz vor dem Erwachen, Satz nach dem Duell, Satz nach dem Mend und einen späteren Satz nach dem Finale.
1606. [P1] Eine Figurenliste in docs/STORY.md führt alle benannten Figuren mit Ort, Rolle, Team, Flags und Bogen, damit spätere Threads nichts doppeln.
1607. [P1] Veit Harrow bekommt einen klaren Bogen: Verlust seiner Mirkmole Ash an die Stille vor 20 Jahren, Wut auf Risse, Zweifel in Akt III, Versöhnung oder Bruch nach Wahl.
1608. [P1] Eine Zahl veit_respect (0 bis 3) wird bei drei Momenten in Akt II und III gesetzt und steuert sein Auftreten im Finale und Postgame.
1609. [P2] Orrin und Maelis tauchen in Akt II als Gäste im Gildenhaus von Madderby auf und erzählen, wie sie ihre Risse seitdem halten.
1610. [P2] Ysolde Rennick hat einen eigenen Bogen: sie hat Mirela damals nicht zurückgehalten und will das wieder gutmachen, aufgelöst in einer Szene nach act2_end.
1611. [P2] Pim, der junge Archivar, ist die Stimme für Lore-Fragen; er beantwortet per Auswahl bis zu vier Fragen pro Kapitel zu Rissen, Stille und Spirlingen.
1612. [P2] Halvard, der Graveurmeister, glaubt an dauerhafte Karten und wandelt sich nach Veits Platte zu jemandem, der Karten offen lässt.
1613. [P2] Brann, Veits Gehilfe, hat drei Auftritte (Madderby, Cinderfold, Graveurhalle) und eine eigene Entscheidung, Veit zu verlassen.
1614. [P2] Ein wiederkehrender Wanderer, Juna die Botin, bringt Briefe zwischen den Regionen und hat in jedem Akt einen neuen Satz über ihre Wege.
1615. [P2] Die Hüter von Corvane und Ashmere haben je einen Gegenstand, den sie der Spielfigur nach dem Mend geben, als Erinnerung an ihr Erwachen.
1616. [P2] Tamsin aus Murk Hollow reist in Akt III nach Ashmere, weil sie dort Lampenöl-Händler kennt, und hilft beim Durchgang zum Ungezeichneten mit Licht.
1617. [P2] Lio vom Krähenkamm wird in Akt II zum Hilfskartografen der Gilde und taucht in Madderby auf.
1618. [P2] Ines und Wynn in Brindlewick bekommen nach jedem Akt eine Zeile zu den Echos, die der See jetzt von weiter her heranträgt.
1619. [P2] Neve aus der Salzmarsch erzählt nach Akt II von Reihern, die über den See nach Corvane ziehen, als Hinweis auf die Fährzeiten.
1620. [P3] Jede Region hat eine Figur, die nur nachts erscheint (Nachtwanderer), mit einer kleinen Geschichte in drei Sätzen.
1621. [P3] Ein alter Kartograf in Greyreach, Moss, hat Mirela gekannt und hält sie für tot; nach dem Finale ändert sich sein Satz.
1622. [P3] Suri und Pell aus dem Cinder-Riss werden im Postgame selbst zu Hüter-Lehrlingen.
1623. [P3] Ein Kind in Madderby sammelt Spirling-Federn und fragt nach Zephlet; eine Nebenfigur, die über alle Akte älter wird (drei Fassungen).
1624. [P3] Die Rest-Spring-Hüterin in Veydal ist Weda aus Madderbys Schwester; beide erwähnen sich gegenseitig.
1625. [P3] Ein Händler auf der Fähre (Story-Rolle, kein Shop) erzählt Gerüchte über die Regionen, die in späteren Akten stimmen oder nicht.
1626. [P3] Bram aus Crowcrest sucht in Akt III seine Shalebats im Ascheland und bittet um Hilfe (Übergang zu einer Nebenquest).
1627. [P3] Die stillen Hush-Wanderer aus Woadfen werden nach dem Mend zu einer Gruppe, die anderen Stillen hilft.
1628. [P3] Jede Hüterin und jeder Hüter hat einen Lieblings-Spirling mit Spitznamen, der in ihren Sätzen vorkommt.
1629. [P3] Nach dem Finale versammeln sich alle Hüter einmal in Brindlewick zu einem Fest, das der Ausrufer ankündigt.

### Nebenquests in Veydal
1630. [P1] Neue Nebenquest letters_veydal: drei Briefe von Mirela an Aldo liegen in Veydal (Leuchtturm-Dachboden, Fernstair-Hütte, Thornridge-Brunnen), Belohnung je 1 Max Tonic.
1631. [P1] quest_show bekommt eine zweite Stufe (q_<id>_stage), damit Nebenquests mehrere Schritte haben können, nicht nur "zeig mir Art X".
1632. [P1] Neue Nebenquest puddlet_wake: das Kind in Brindlewick will sein stilles Puddlet wecken; die Spielfigur spielt eine Echo-Melodie mit ihm (Flag q_puddlet_done).
1633. [P1] Nebenquests zeigen im Zielmenü einen Ortshinweis ("where") wie die Hauptziele.
1634. [P2] Neue Nebenquest lantern_route: Tamsin bittet, die drei Lampen im Murk Hollow jede Nacht zu zünden; nach drei Nächten erzählt sie ihre Geschichte.
1635. [P2] Neue Nebenquest lost_map: ein Wanderer in Fernstair hat eine Karte verloren; sie liegt bei einem Farn mit Kompassrose, Belohnung 600 Münzen.
1636. [P2] Neue Nebenquest orrin_names: Orrin hat die Namen seiner Spirlinge vergessen; die Spielfigur findet sie auf drei Steinen in Thornridge.
1637. [P2] Neue Nebenquest maelis_song: Maelis will ihr Lied wiederfinden; drei Strophen liegen als Zeichen in der Salzmarsch.
1638. [P2] Neue Nebenquest kelpup_pups: der Fischer will nach q_fisher_done eine entfaltete Kelphound sehen.
1639. [P2] Neue Nebenquest bram_shale: Bram sucht eine Shalebat, die nachts in Crowcrest ruft (nachts erreichbarer Kampf).
1640. [P2] Neue Nebenquest cartographer_test: Kestra gibt drei Karten-Rätsel (welcher Ort hat diese Form), Antwort per Auswahl, Belohnung 1 Echo-Kristall.
1641. [P2] Neue Nebenquest lighthouse_oil: Aldo braucht Lampenöl aus Murk Hollow, eine kurze Botengang-Quest mit Szene beim Nachfüllen.
1642. [P2] Neue Nebenquest spring_spirits: an der Rest Spring singt nachts ein stiller Wickit; mit einer Echo-Melodie schließt er sich der Spielfigur an (Ring 15).
1643. [P2] Neue Nebenquest crier_news: der Ausrufer braucht drei Neuigkeiten aus der Welt; die Spielfigur erzählt sie per Auswahl.
1644. [P2] Neue Nebenquest ink_recipe: die Kartenhaus-Tinte ist leer; drei Zutaten (Farn, Asche, Schilf) stehen als Fundstellen in der Welt.
1645. [P2] Belohnungen der Nebenquests nutzen nur bestehende Gegenstände; neue Andenken kommen aus Bereich Gegenstände.
1646. [P3] Neue Nebenquest ferry_memory: am alten Fährsteg liegt Aldos erstes Ruder; nach Rückgabe erzählt er von seinem ersten Jahr als Fährmann.
1647. [P3] Neue Nebenquest child_promise: das Kind mit Puddlet bittet nach puddlet_wake, dass die Spielfigur ihm nach jedem Akt erzählt, was sie gesehen hat.
1648. [P3] Neue Nebenquest fern_echo: in Fernstair hallt ein Ruf; bei Morgengrauen ist ein Zephlet in einem Farn zu finden.
1649. [P3] Neue Nebenquest rest_keeper: die Hüterin der Rest Spring will, dass jede Spirling-Art einmal an der Quelle rastet (zählt Arten im Team bei Rast).
1650. [P3] Neue Nebenquest ridge_poem: am Krähenkamm stehen drei Zeilen eines Gedichts; die vierte schreibt die Spielfigur selbst (Auswahl).
1651. [P3] Neue Nebenquest thorn_trader: der Händler in Thornridge erzählt Geschichten, wenn die Spielfigur zehnmal bei ihm war.
1652. [P3] Neue Nebenquest storm_glass: nach jedem Gewitter (Wetter aus Bereich Welt, sonst zufällig 1 von 7 Tagen) liegt ein Sturmglas am Leuchtturm.
1653. [P3] Neue Nebenquest swarm_names: die vertriebenen Spirlinge aus der Murk-Hollow-Ecke tauchen einzeln wieder auf und bedanken sich mit Rufen.
1654. [P3] Neue Nebenquest kestra_window: das Fenster im Kartenhaus, durch das Seite 1 hereinflog, zeigt nachts eine Spur; sie führt zu einer verborgenen Randnotiz von Mirela.

### Nebenquests in Corvane und Ashmere
1655. [P1] Neue Nebenquest letters: Pim sucht Mirelas restliche Briefe (3 in Corvane, 3 in Ashmere), Fortschritt "(k/6)" im Zielmenü.
1656. [P1] Neue Nebenquest colour_back: drei Färberfamilien in Madderby wollen je einen bestimmten Spirling sehen, der seine Farbe zurück hat (nach rift_rain_sealed).
1657. [P1] Neue Nebenquest veit_workshop: in Veits Werkstatt liegen drei Hinweise auf Ash; wer sie findet, hebt veit_respect um 1.
1658. [P2] Neue Nebenquest mirror_faces: Joral bittet, im Stillwater-Teich drei Spiegelbilder zu finden, die nicht zur Spielfigur gehören.
1659. [P2] Neue Nebenquest woad_dye: Senna braucht Färberwaid aus drei Moorstellen, um ihr verblasstes Halstuch neu zu färben.
1660. [P2] Neue Nebenquest hushed_walkers: die zwei stillen Wanderer in Woadfen bekommen ihre Stimmen zurück, wenn die Spielfigur ihnen ihre verlorenen Spirlinge zeigt.
1661. [P2] Neue Nebenquest guild_exam: Ysolde gibt eine Gildenprüfung in drei Teilen (Ortskunde, Elementkunde, Wegfindung), Belohnung ein Gildenrang im Tagebuch.
1662. [P2] Neue Nebenquest press_parts: Halvard fehlen drei Teile für die alte Handpresse in Cinderfold, versteckt an Orten in Ashmere.
1663. [P2] Neue Nebenquest glass_song: Ilse lehrt nach dem Mend drei Strophen, die an drei Glasbögen in Saltglass gespielt werden müssen.
1664. [P2] Neue Nebenquest kiln_fire: Tovan bittet, die alte Ofenflamme mit einem Ember-Spirling aus dem eigenen Team neu zu entzünden (Bedingung has_element EMBER).
1665. [P2] Neue Nebenquest brann_debt: Brann schuldet einer Händlerin Geld; die Spielfigur kann zahlen oder ihm helfen, es zu verdienen, was veit_respect nicht ändert, aber Branns Ende.
1666. [P2] Neue Nebenquest skylines: Lio braucht Skizzen von drei Aussichtspunkten in Corvane für die Gilde.
1667. [P2] Neue Nebenquest juna_post: Juna die Botin braucht Hilfe bei fünf Zustellungen über beide Regionen, mit kleinen Szenen pro Empfänger.
1668. [P2] Neue Nebenquest ash_name: im Ungezeichneten findet die Spielfigur das Halsband von Ash und kann es Veit bringen.
1669. [P3] Neue Nebenquest dyers_feast: das Färberfest in Madderby (Festival-System aus Season.gd) bekommt eine eigene Mini-Geschichte mit drei Szenen.
1670. [P3] Neue Nebenquest greyreach_moss: der alte Kartograf Moss will ein letztes Mal Mirelas Handschrift sehen; die Spielfigur zeigt ihm eine Seite.
1671. [P3] Neue Nebenquest rhea_tale: Kestras Schwester Rhea will wissen, ob Kestra glücklich ist; die Antwort kommt erst nach dem Finale.
1672. [P3] Neue Nebenquest cinder_ash: Graveure brauchen feine Asche von drei Orten, um eine Gedenkplatte für frühere Hüter zu stechen.
1673. [P3] Neue Nebenquest station_lost: am Bahnhof von Ashmere sucht ein Kind seinen Mirkmole, der in einen Stollen gelaufen ist.
1674. [P3] Neue Nebenquest nella_plate: Graveurlehrling Nella sticht mit den Antworten der Spielfigur eine Platte, die im Postgame in der Graveurhalle hängt.
1675. [P3] Neue Nebenquest saltglass_keeper: die Leuchtturmwärterin von Saltglass will einen Brief an Aldo zustellen lassen (saltglass_letter).
1676. [P3] Neue Nebenquest harl_story: der alte Warden Harl erzählt drei Geschichten, wenn die Spielfigur ihm Kohle aus dem Ofenriss bringt.
1677. [P3] Neue Nebenquest undrawn_sketches: im Ungezeichneten liegen fünf halbe Skizzen von Spirlingen; vollständig gefunden, schreibt Mirela dazu Lore ins Kartenbuch.
1678. [P3] Neue Nebenquest colour_tour: nach Akt II sollen alle 8 Elemente einmal am Gildenbrunnen in Madderby gezeigt werden.
1679. [P3] Neue Nebenquest bram_ash: Bram aus Crowcrest sucht seine Shalebats im Ascheland, mit einem Wiedersehen in Cinderfold.

### Entscheidungen mit Folgen
1680. [x] [P1] Entscheidungen werden in GameState.story_choices (Dictionary) gespeichert und im Online-Spielstand gesichert, mit Versionsfeld für spätere Änderungen.
1681. [P1] Das Ende "Bring her home" ist immer wählbar: Mirela kommt heim, der Weite Riss schließt sich, Riss-Spirlinge brauchen danach einen Anker-Bund (Story-Text, keine neuen Regeln).
1682. [P1] Das Ende "Leave a gate" ist immer wählbar: der Weite Riss wird zu einer Pforte mit Mirela als Hüterin, sie bleibt im Ungezeichneten, Kestra ist froh.
1683. [P1] Das Ende "Two keepers" verlangt veit_respect 3 und alle 14 Seiten: Veit bleibt mit Ash als Hüter im Ungezeichneten, und Mirela kommt heim.
1684. [P1] Vor der Abschlusswahl zeigt eine Bestätigung den gewählten Weg in einem Satz und fragt "Draw it so?", weil die Wahl endgültig ist.
1685. [P1] Kleine Entscheidungen haben sichtbare Folgen innerhalb von höchstens einem Kapitel (andere Sätze, ein Geschenk, ein neuer Gefährte), damit sich Wählen lohnt.
1686. [P2] Nach jedem gestopften Riss in Akt II und III fragt der Warden, ob ein Faden offen bleiben soll ("thread") oder der Riss ganz zu ist ("seal"), gespeichert pro Riss.
1687. [P2] Bleibt ein Faden offen, erscheinen dort nachts gelegentlich Riss-Spirlinge mit eigenem Satz des Wardens; ganz geschlossen wird die Gegend ruhiger beschrieben.
1688. [P2] Die Faden-Wahlen zählen in eine Zahl rift_threads (0 bis 4), die Kestras Haltung und einen Satz im Finale beeinflusst.
1689. [P2] Veits Angebot in Cinderfold anzunehmen führt nicht in eine falsche Richtung; Veit vertraut der Spielfigur dann mehr (veit_respect plus 1), aber Kestra misstraut (kestra_trust minus 1).
1690. [P2] Die Wahl bei Veits Platte (zerstören oder ihn zerbrechen lassen) ändert, ob Veit im Postgame in Madderby lebt oder weggeht.
1691. [P2] In ferry_crossing selbst zu rudern lässt Aldo in Akt II stolz von der Spielfigur sprechen; ihn rudern zu lassen gibt eine ruhige Erinnerungsszene.
1692. [P2] Die Antwort auf Mirelas Frage nach Aldo bestimmt die Wiedersehensszene (drei Fassungen: stürmisch, still, scherzhaft).
1693. [P2] Das Tagebuch zeigt die wichtigsten Entscheidungen als Liste "Choices you made" mit je einem Satz, ohne Bewertung.
1694. [P2] Es gibt keine Wahl, die Inhalte dauerhaft sperrt; jede Nebenquest bleibt in jedem Ende erreichbar, ein Test prüft das über alle Flag-Kombinationen.
1695. [P2] Ein Prüfskript tools/story_paths.py spielt alle Kombinationen von kestra_trust, veit_respect und Endwahl durch und meldet Dialoge ohne passende Variante.
1696. [P2] Freilassen eines Spirlings, der aus einer Story-Szene stammt (Glim, Tatter-Geschenk), fragt zweimal nach und erwähnt die Story.
1697. [P3] Die erste Spirling-Wahl im Prolog bekommt Folgen: der nicht gewählte Lichtspirling taucht in Akt II bei Kestra oder Pim auf und erinnert sich an die Spielfigur.
1698. [P3] Die Wahl in kestra_dock ("mitkommen" oder "allein") bestimmt, ob Kestra in Akt II zuerst in Madderby oder in Woadfen auftaucht.
1699. [P3] Eine Wahl im Gildenhaus (Ysolde die Wahrheit über Mirela sagen oder nicht) ändert Ysoldes Bogen-Auflösung.
1700. [P3] Die Spielfigur kann Veit im Postgame verzeihen oder nicht; beides hat eine eigene Szene und keinen Spielnachteil.
1701. [P3] Ysolde reagiert in Akt III auf die Faden-Wahlen aus Akt II mit einem von zwei Sätzen (rift_threads unter 2 oder ab 2).
1702. [P3] Nach dem Finale zeigt Mirela auf Nachfrage, wie die anderen Enden ausgesehen hätten, als kurze Skizzen, damit niemand das Gefühl hat, etwas verpasst zu haben.
1703. [P3] Die Entscheidungen werden in den Freundesprofilen nie gezeigt, damit keine Spoiler über Online-Funktionen entstehen.
1704. [P3] Ein Erfolg pro Ende wird über Achievements.gd vergeben (drei Erfolge), ohne Belohnung im Spiel.

### Lore: Risse, Stille und Spirlinge
1705. [P1] docs/STORY.md bekommt ein Kapitel "Lore" mit den festen Wahrheiten: Spirlinge stammen aus dem Ungezeichneten, Risse entstehen, wo die gezeichnete Welt dünn wird, die Stille ist das Echo verlorener Bünde.
1706. [P1] Jeder Spirlog-Eintrag der 21 Arten bekommt eine zweite Lore-Zeile, die nach dem Bonden der Art lesbar ist und auf Risse oder Regionen Bezug nimmt.
1707. [P1] Die Lore-Texte werden mit tools/ip_check.sh geprüft und vermeiden jede Nähe zu fremden Ursprungsmythen; eigene Begriffe stehen in einer Glossarliste in docs/STORY.md.
1708. [P2] Die Echo-Melodie bekommt eine Herkunft: Mirela hat sie im Ungezeichneten gehört und in Veydal als Wiegenlied weitergegeben; die Gilde lehrt sie seitdem.
1709. [P2] Wardens werden erklärt: Menschen, deren Bund mit Spirlingen stark genug ist, einen Riss zu halten; wird der Bund still, öffnet sich der Riss weiter.
1710. [P2] Die Gabe-Beschreibungen bleiben spielmechanisch; die Lore steht nur im Spirlog, damit Werte und Geschichte getrennt bleiben.
1711. [P2] Das Wort "Hush" bekommt eine Lore-Geschichte im Kartenbuch (Seite 2 existiert); Pim erzählt, dass andere Regionen eigene Wörter haben (Corvane "the Fading", Ashmere "the Stilling").
1712. [P2] Die Elemente bekommen je einen Lore-Satz über ihre Rolle im Ungezeichneten, in einer neuen Seite "Elements" im Kartenbuch.
1713. [P2] Entfalten bekommt Lore: ein Spirling entfaltet sich, wenn sein Bund mit dem Wanderer tief genug ist, als würde ein Stück Karte zu Ende gezeichnet.
1714. [P2] Ringe bekommen Lore: jeder Ring ist eine Spur auf der Haut des Spirlings, wie Jahresringe; Ring 60 ist die Grenze, die Mirela "the edge of drawing" nennt.
1715. [P2] Die Graveur-Gilde besitzt eine Chronik früherer Risse (5 Einträge über 400 Jahre), lesbar als Schilder in der Graveurhalle.
1716. [P2] Der Nachhall wird nie als Monster beschrieben, sondern als trauernder Chor; alle Texte prüfen das in einer Stilregel in docs/STORY.md.
1717. [P2] Das Ungezeichnete hat drei feste Regeln, die in Szenen gezeigt werden: Wege entstehen beim Zeichnen, Zeit läuft langsamer, Stimmen tragen weit.
1718. [P2] Die Era-Wechsel werden in der Lore als neue Zeichenweisen der Gilde erklärt; der Text in EraManager.ERA_LINES bekommt je eine passende Zeile aus Mirelas Kartenbuch (keine neuen Rituale).
1719. [P2] Ein Lore-Abschnitt "Rift-born" erklärt, warum manche Spirlinge in Rissnähe öfter erscheinen, passend zu bestehenden Begegnungstabellen.
1720. [P3] Pim führt ein Lexikon im Kartenbuch mit 30 Begriffen (Riss, Hüter, Stille, Anker-Bund, Faden, Skizze, Nachhall), freigeschaltet beim ersten Hören.
1721. [P3] Jede Region hat ein Volkslied in 4 Zeilen über Risse, das Figuren an Festtagen singen.
1722. [P3] Die Daily-Find-Fundstücke (DailyFind.gd) bekommen kurze Lore-Texte über Risse statt nur Namen.
1723. [P3] Jedes der 8 Elemente bekommt eine Legende in 3 Sätzen, die Pim auf Nachfrage erzählt, getrennt von der Kartenbuchseite "Elements".
1724. [P3] Alte Ruinen in Corvane (Schilder) erzählen von einer Zeit, als Spirlinge und Menschen die Karten gemeinsam zeichneten.
1725. [P3] Mirela hat im Ungezeichneten ein eigenes Alphabet für Orte erfunden; drei Wörter davon tauchen als Rätsel in Nebenquests auf.
1726. [P3] Die Spark-Lesung des Sparkseers in Thornridge bekommt nach dem Finale eine Zeile über den Ursprung des Funkens im Ungezeichneten.
1727. [P3] Die Stille wirkt in jeder Region anders (Veydal Stimme, Corvane Farbe, Ashmere Bewegung); das wird in einem Satz pro Region in der Ortsbeschreibung genannt.
1728. [P3] Ein Lore-Test prüft, dass kein Text der Lore-Regel "Spirlinge sind keine Ware" widerspricht (Wortliste: kaufen, verkaufen in Verbindung mit Spirling).
1729. [P3] Ein Lore-Eintrag erklärt, warum niemand auf Spirlingen reisen kann: sie tragen das Gewicht der Karte, nicht das eines Menschen.

### Postgame-Story
1730. [P1] Nach story_complete erscheint ein neues Hauptziel "Epilogue: The Open Map" mit drei Kapiteln, damit es nach dem Abspann weitergeht.
1731. [P2] Epilog-Kapitel 1 "Homecoming": Besuche bei allen Hütern in Veydal, Corvane und Ashmere, die nach dem Finale neue Sätze haben (Ziel mit Fortschritt "(k/6)").
1732. [P2] Epilog-Kapitel 2 "The Southern Tear": Kestra hat einen neuen kleinen Riss im Süden skizziert; die Spielfigur prüft ihn und findet eine Spur nach Solenne (Haken für spätere Teile).
1733. [P2] Epilog-Kapitel 3 "A Map of Our Own": die Spielfigur zeichnet im Kartenhaus eine eigene Karte; die Szene setzt postgame_done und zeigt einen Satz von jedem Verbündeten.
1734. [P2] Je nach Ende hat der Epilog eine eigene Szene: Mirela am Kartentisch, Briefe von der Pforte oder Veit und Ash an der Pforte.
1735. [P2] Veit hat im Postgame eine eigene Versöhnungsgeschichte in drei Szenen, wenn er nicht Hüter wurde.
1736. [P2] Kestra lädt die Spielfigur nach dem Epilog zu einer Expedition ein; die Szene endet mit einem Blick nach Süden, ohne neue Karte.
1737. [P2] Die Postgame-Story nennt keine Endgame-Kampfsysteme; diese kommen aus Bereich 8 und werden hier nur per Satz eines Hüters erwähnt, wenn sie existieren.
1738. [P2] Aldo gibt im Postgame sein Fährmann-Amt an die Spielfigur weiter (Titel im Tagebuch "Ferry-keeper"), nur als Story-Ehre.
1739. [P3] Die Rissherzen aller Regionen bekommen nach dem Finale Gedenksteine mit den Namen der Hüter.
1740. [P3] Pim schreibt im Postgame eine Chronik der Reise, die im Kartenbuch kapitelweise lesbar ist.
1741. [P3] Ysolde tritt im Postgame als Gildenmeisterin zurück und schlägt die Spielfigur als Nachfolgerin oder Nachfolger vor; die Spielfigur kann annehmen oder ablehnen.
1742. [P3] Die Färberfamilien in Madderby feiern nach dem Finale ein Fest, das nur im Postgame stattfindet.
1743. [P3] Die stillen Spirlinge aus dem Nachhall tauchen im Postgame einzeln in der Welt auf, mit einem Satz bei jeder Begegnung.
1744. [P3] Mirelas Glim zeigt im Postgame Orte, an denen Mirela vor 40 Jahren war, als kleine Hinweis-Quest mit 5 Orten.
1745. [P3] Brann eröffnet in Cinderfold eine kleine Kartenwerkstatt und erzählt bei jedem Besuch von neuen Aufträgen.
1746. [P3] Die Saltglass-Wärterin und Aldo treffen sich im Postgame in Brindlewick, wenn saltglass_letter zugestellt wurde.
1747. [P3] Eine letzte Szene nach postgame_done zeigt die Spielfigur, Aldo und den Partner-Spirling auf dem Leuchtturm bei Nacht.
1748. [P3] Postgame-Briefe kommen einmal pro Tag (Tageswechsel) von Figuren aus allen Regionen, 20 Briefe insgesamt.
1749. [P3] Die Wahl der Nachfolge in der Gilde ändert den Titel im Tagebuch und Sätze im Gildenhaus, sonst nichts.

### Ziele, Tagebuch und Kartenbuch
1750. [P1] QuestLog unterstützt Akte: Hauptziele bekommen ein Feld "act", das Zielmenü zeigt den Aktnamen über dem Kapitel.
1751. [P1] Das Kartenbuch (Mirelas Seiten) wird ein eigenes Menü mit Seitenliste und gelesenen Seiten, statt nur Textzeilen beim Fund.
1752. [P1] Nebenquests mit Stufen zeigen den aktuellen Schritttext statt nur den Starttext.
1753. [P2] Das Tagebuch sammelt Kapitel-Rückblicke (6 Zeilen pro Akt) automatisch, sobald ein Akt endet.
1754. [P2] Eine Seite "People" im Tagebuch listet getroffene Figuren mit einem Satz, der sich mit ihrem Bogen ändert.
1755. [P2] Erledigte Nebenquests bleiben im Tagebuch als Liste mit Ort und Belohnung lesbar.
1756. [P2] Ein kleiner Punkt am Pausenmenü zeigt neue Kartenbuchseiten oder Briefe an, bis sie gelesen sind.
1757. [P2] Hauptziele können optional einen Hinweis mit zwei Stufen haben ("hint_1", "hint_2"), der nach 20 Minuten ohne Fortschritt im Zielmenü erscheint.
1758. [P2] QuestLog.summary für den Online-Spielstand enthält Akt, Kapitel und Seitenzahl, damit der Server den Fortschritt im Profil zeigen kann.
1759. [P2] Briefe (Aldo, Mirela, Kestra, Juna) bekommen eine eigene Seite "Letters" im Tagebuch.
1760. [P3] Das Kartenbuch zeigt neben jeder Seite die Kompassrose an dem Ort, wo sie gefunden wurde, als kleine Karte aus der bestehenden Weltkarte.
1761. [P3] Das Tagebuch kann nach Region gefiltert werden.
1762. [P3] Ein Satz "Last time..." erscheint beim Laden eines Spielstands, der länger als 3 Tage nicht gespielt wurde, mit dem aktuellen Ziel und dem letzten Kapitel.
1763. [P3] Alle Tagebuchtexte nutzen dieselben Platzhalter wie Dialoge ({name}, {partner}).
1764. [P3] Ein Test prüft, dass jedes Haupt- und Nebenziel einen erreichbaren done-Flag hat, der von einem Dialog, einer Szene oder einem Kampf gesetzt wird.

### Texte, Übersetzung und Prüfungen
1765. [P1] Alle neuen Story-Texte stehen auf Englisch in data/dialogue und data/scenes und auf Deutsch in tools/i18n/de_story.py; der Build bricht ab, wenn ein Schlüssel fehlt.
1766. [P1] Eine Stilregel in docs/STORY.md legt fest: kurze Sätze, höchstens 2 Zeilen pro Textfeld, keine typografischen Anführungszeichen (Pixelschrift), Spielerwörter laut AGENTS.md.
1767. [P1] tools/ip_check.sh läuft über data/scenes und docs/STORY.md mit, und neue Figuren- und Ortsnamen werden vor dem Merge gegen bekannte Fremdnamen geprüft.
1768. [P2] Ein Lesbarkeitstest misst jede Dialogzeile gegen die Breite des Dialogfelds (144 Pixel minus Rand) und meldet zu lange Zeilen im CI.
1769. [P2] Figurennamen bleiben in allen Sprachen gleich; nur Ortsnamen mit Bedeutung (Greyreach, Saltglass) bekommen deutsche Fassungen nach einer festen Liste.
1770. [P2] Ein Wortzähler pro Akt (tools/story_stats.py) hilft, Akt II und III auf je etwa 9000 englische Wörter zu halten.
1771. [P2] Jede Szene hat einen Kommentar "_note" mit Kapitel, Ort und Zweck, damit Übersetzende den Zusammenhang kennen.
1772. [P2] Dialog-Schlüssel folgen einem Schema "<figur>_<kapitel>_<thema>", geprüft durch DataValidator.
1773. [P2] Auswahl-Antworten sind höchstens 18 Zeichen lang, damit sie in einer Zeile passen, geprüft im CI.
1774. [P2] Ein Spoiler-Schutz verhindert, dass Store-Texte oder Screenshots Akt-III-Inhalte zeigen; Liste der Spoiler-Flags in docs/STORY.md.
1775. [P3] Eine Lektoratsliste in docs/STORY.md sammelt Begriffe mit fester Schreibweise (Ungezeichnete, Nachhall, Anker-Bund, Faden).
1776. [P3] Der Text-Export für Lektorat (alle Dialoge und Szenen als eine Datei pro Akt) wird bei jedem Release als Artefakt gebaut.
1777. [P3] Ein Test stellt sicher, dass jede Figur in docs/STORY.md mindestens einen Dialogschlüssel hat und umgekehrt.
1778. [P3] Die deutsche Fassung von Kestras Sätzen nutzt eine eigene Wortwahl (knapp, direkt), festgehalten als Stimmprofil in docs/STORY.md.
1779. [P3] Für spätere Sprachen werden alle Story-Texte über Loc.gd geladen, auch Kapitelkarten und Briefe.
