# Bereich 9: Technik, Qualität, Release und Recht

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 3557 bis 4000.

> **Auftrag für den umsetzenden Thread:** Ziel ist ein Spiel, das auf schwachen Handys flüssig und sparsam läuft, nie Spielstände verliert, sicher betrieben wird und ohne rechtliche Lücken in beide Stores geht und dort bleibt. Betroffen sind `project.godot`, `export_presets.cfg`, `scripts/core/SaveManager.gd`, `scripts/online/`, `server/`, `supabase/migrations/`, `tests/`, `tools/`, `.github/workflows/`, `docs/RELEASE.md`, `docs/STORE_RELEASE.md` und `docs/legal/`. Fang mit den P1-Punkten in "Speicherstände", "Server-Sync", "Backups" und "Datenschutz" an, weil dort echte Datenverluste und Abmahnrisiken liegen, und arbeite danach die P1-Punkte von Android und iOS ab. Spielinhalte (Spirlings, Karten, Kämpfe, Story), neue Online-Funktionen und die Technik des In-App-Kaufs selbst (Bereich 10) gehören nicht hierher; dieser Bereich liefert nur die allgemeinen Release-, Rechts- und Qualitätsgrundlagen, auf denen diese aufbauen.

### Leistung und Akku auf schwachen Handys
3557. [P1] Lege in `docs/PERFORMANCE.md` zwei Referenzgeräte fest (Android 7 mit 2 GB RAM und Mali-GPU, iPhone 11 als ältestes Gerät mit iOS 26) und miss dort Bildrate, Akkuverbrauch pro Stunde und Startzeit als Ausgangswerte.
3558. [P1] Setze `Engine.max_fps` in Menüs, Textboxen und im Kampf beim Warten auf Eingabe auf 30 und nur während Bewegung und Tweens auf 60, gesteuert von einem kleinen Autoload `FrameBudget.gd`.
3559. [P1] Stoppe beim Wechsel in den Hintergrund (`NOTIFICATION_APPLICATION_PAUSED` und `FOCUS_OUT`) Herzschlag, Musik und `_process` aller Szenen und setze sie beim Zurückkehren fort.
3560. [P1] Füge in den Einstellungen einen Schalter "Akku sparen" hinzu, der die Bildrate fest auf 30 setzt, Partikel und Bildschirmwackeln abschaltet und den Herzschlag in `Online.gd` von 45 auf 90 Sekunden streckt.
3561. [P1] Lege ein Bildzeit-Budget von 16 ms bei 60 Bildern und 33 ms bei 30 Bildern fest und lass einen Headless-Benchmark in CI scheitern, wenn eine Standard-Szene das Budget im Mittel um mehr als 20 % überschreitet.
3562. [P2] Schreibe `tools/bench/bench_scenes.gd`, das Titel, Oberwelt, Kampf und Team-Menü je 600 Bilder lang misst und Mittelwert, 95. Perzentil und Spitzen als JSON ausgibt.
3563. [P2] Speichere die Benchmark-Ergebnisse jedes Laufs auf `main` als CI-Artefakt und zeige in der Job-Zusammenfassung die Veränderung zum letzten Lauf in Prozent.
3564. [P2] Prüfe alle `_process`-Funktionen in `scripts/` und schalte mit `set_process(false)` ab, was gerade unsichtbar ist oder nichts zu tun hat.
3565. [P3] Ersetze dauerhaft laufende Timer-Abfragen in `_process` durch `Timer`-Knoten oder `SceneTreeTimer`, wo das gleiche Verhalten möglich ist.
3566. [P2] Begrenze gleichzeitig laufende Tweens im Kampf-Presenter auf 8 und brich ältere ab, wenn der Spieler im Schnellvorlauf ist.
3567. [P2] Miss die Zahl der Draw Calls pro Szene mit `RenderingServer.get_rendering_info` und halte sie in der Oberwelt unter 150, sonst wird in CI eine Warnung ausgegeben.
3568. [P3] Fasse kleine UI-Grafiken in einem Atlas zusammen, damit Menüs weniger Texturwechsel brauchen, und dokumentiere den Atlas in `docs/ASSET_LOG.md`.
3569. [P2] Lade Musik als gestreamte OGG-Dateien statt als ganze Puffer und miss den Speicherunterschied auf dem Android-Referenzgerät.
3570. [P2] Prüfe, dass die Paletten- und Retro-Shader in `shaders/` auf `gl_compatibility` keine Schleifen mit variabler Länge enthalten, und ersetze sie durch feste Schleifen.
3571. [P2] Kompiliere alle Shader beim ersten Start hinter dem Ladebildschirm vor, damit der erste Kampf nicht ruckelt, und miss die Zeit dafür.
3572. [P2] Begrenze die Zahl gleichzeitig aktiver NPC-Knoten auf einer Karte auf die sichtbaren plus einen Rand von 2 Kacheln und schlafe den Rest.
3573. [P2] Ersetze `get_node`-Aufrufe in heißen Schleifen durch zwischengespeicherte `@onready`-Variablen und miss den Gewinn im Benchmark.
3574. [P2] Sorge dafür, dass der Pfadfinder in `PathFinder.gd` pro Bild höchstens 2 ms rechnet und lange Suchen auf mehrere Bilder verteilt.
3575. [P3] Prüfe die Wärmeentwicklung durch einen 30-Minuten-Lauf auf dem Android-Referenzgerät und halte fest, ab wann das System die Taktrate senkt.
3576. [P3] Biete in den Einstellungen eine Option "Flüssig (60)" und "Sparsam (30)" mit einer kurzen Erklärung zum Akkuverbrauch an.
3577. [P3] Nutze auf Geräten mit 90 oder 120 Hz trotzdem höchstens 60 Bilder, damit hohe Bildwiederholraten den Akku nicht leeren.
3578. [P3] Schalte bei niedrigem Akkustand (unter 15 %, falls die Plattform den Wert liefert) automatisch in den Sparmodus und zeige einmal einen Hinweis.
3579. [P3] Baue einen Debug-Overlay mit Bildzeit, Speicher und Draw Calls, der nur in Debug-Builds mit drei Fingern einblendbar ist.
3580. [P3] Prüfe vor jeder neuen Era-Auflösung (180x320 und 270x480), dass das Android-Referenzgerät mindestens 30 Bilder hält, und dokumentiere das Ergebnis.
3581. [P3] Miss den Speicherverbrauch nach 10 Kämpfen hintereinander und stelle sicher, dass er um weniger als 5 MB wächst.
3582. [P3] Untersuche, ob das Abschalten von `snap_2d_transforms_to_pixel` in Menüs ohne Bewegung messbar Leistung spart, und behalte es nur bei Gewinn.
3583. [P3] Schreibe in `docs/PERFORMANCE.md` eine Liste mit 10 Regeln für neue Szenen (keine `_process` ohne Grund, Texturen in Zweierpotenzen, Atlas nutzen usw.).
3584. [P3] Wiederhole die Akkumessung auf beiden Referenzgeräten vor jeder größeren Version und trage die Werte in eine Tabelle in `docs/PERFORMANCE.md` ein.

### Speichergröße und Ladezeiten
3585. [P1] Senke das APK-Budget in `tools/apk_budget.sh` vom bisherigen Wert 80 MB auf die aktuelle Größe plus 25 % und erhöhe es nur mit Begründung im Commit.
3586. [P1] Füge ein eigenes Größenbudget für die Release-AAB (Download-Größe laut `bundletool get-size total`) und für die iOS-IPA in die CI-Jobs ein.
3587. [P1] Miss die Zeit vom App-Start bis zum spielbaren Titelbild auf dem Android-Referenzgerät und halte sie unter 4 Sekunden.
3588. [P1] Lade `data/*.json` in `Database.gd` einmal beim Start und prüfe, dass Ladezeit und Speicher dafür unter 300 ms und 10 MB bleiben.
3589. [P2] Gib im CI-Job die 20 größten Dateien im PCK aus und markiere jede neue Datei über 500 KB als Warnung.
3590. [P2] Prüfe, dass `exclude_filter` in allen vier Presets auch `docs/*`, `store/*`, `server/*`, `supabase/*` und `art/**/source/*` ausschließt.
3591. [P2] Komprimiere Soundeffekte als OGG mit 22 kHz mono, wo das hörbar keinen Unterschied macht, und miss die Ersparnis.
3592. [P2] Prüfe, dass alle Pixel-Grafiken verlustfrei importiert werden und keine unnötigen Mipmaps erzeugen, und stelle die Importeinstellungen zentral ein.
3593. [P2] Lade Karten erst beim Betreten und gib die vorige Karte frei, damit der Speicher bei 11 und mehr Karten nicht wächst.
3594. [P2] Zeige beim Kartenwechsel einen kurzen Übergang, der das Laden verdeckt, und miss, dass kein Kartenwechsel länger als 500 ms dauert.
3595. [P2] Begrenze die Größe des `user://`-Ordners (Spielstände, Einstellungen, Logs, Cache) auf 20 MB und räume alte Logs automatisch auf.
3596. [P2] Prüfe die tatsächliche Installationsgröße nach dem ersten Start auf beiden Plattformen und trage sie in `docs/PERFORMANCE.md` ein.
3597. [P3] Bereite für spätere Eras eine Aufteilung der Era-Grafik in eigene PCK-Dateien vor, die erst bei Bedarf geladen werden.
3598. [P3] Prüfe Play Asset Delivery als Weg für spätere große Era-Pakete und halte in `docs/RELEASE.md` fest, ab welcher Größe es sich lohnt.
3599. [P3] Entferne nicht genutzte Godot-Module über eine eigene Export-Vorlage mit Build-Profil, wenn das die Größe um mehr als 5 MB senkt.
3600. [P3] Schreibe ein Skript `tools/unused_assets.py`, das Dateien unter `art/` und `audio/` findet, auf die keine Szene, kein Skript und keine JSON-Datei verweist.
3601. [P3] Miss den RAM-Höchstwert über eine ganze Spielstunde und halte ihn auf dem Android-Referenzgerät unter 300 MB.
3602. [P3] Lege für Musikstücke eine Höchstlänge pro Datei fest und lass `tools/apk_budget.sh` längere Stücke melden.
3603. [P3] Prüfe, ob die Schriftdateien nur die nötigen Zeichen enthalten, und schneide sie für Deutsch und Englisch zu.
3604. [P3] Zeige im Ladebildschirm nach 3 Sekunden einen Hinweis "Lädt..." mit Fortschritt, damit Spieler auf langsamen Geräten nicht abbrechen.

### Absturzsicherheit und Fehlerbehandlung im Spiel
3605. [P1] Schalte das Datei-Logging auch auf Android und iOS ein (`debug/file_logging/enable_file_logging`) mit höchstens 5 Dateien zu je 1 MB in `user://logs`.
3606. [P1] Baue unter Einstellungen, Hilfe einen Knopf "Fehlerbericht senden", der nur nach Zustimmung die letzte Logdatei an eine eigene Serverfunktion `bug_report` schickt, ohne fremdes SDK.
3607. [P1] Lege die Tabelle `bug_reports` mit Spieler-ID, App-Version, Gerätemodell, Logtext (höchstens 64 KB) und Zeitpunkt an, mit 3 Berichten pro Tag pro Konto und Löschung nach 90 Tagen.
3608. [P1] Prüfe alle `await`-Stellen in `scripts/online/` und `scripts/ui/` darauf, dass ein Fehler oder Timeout nie einen Bildschirm ohne Ausweg hinterlässt.
3609. [x] [P1] Fange beim Laden von Spielständen jede ungültige Struktur ab und zeige statt eines Absturzes "Spielstand beschädigt, Sicherung wird geladen".
3610. [P2] Leite alle `push_error`-Aufrufe über eine kleine Funktion `Log.error(tag, text)`, damit Logs einheitlich mit Zeit, Szene und Tag geschrieben werden.
3611. [P2] Entferne aus Logs alles, was personenbezogen sein kann (Wayfarer-Name, Freundescode, Token), bevor es geschrieben wird, und teste das.
3612. [P2] Ergänze `Database.gd` so, dass ein fehlender Eintrag (Spirling, Technik, Gegenstand) einen sicheren Ersatz liefert und einen Logeintrag schreibt, statt `null` weiterzugeben.
3613. [P2] Sorge dafür, dass der Kampf-Presenter bei einem unbekannten Ereignistyp eine Warnung loggt und das Ereignis überspringt, statt hängenzubleiben.
3614. [P2] Lege einen Wachhund für den Kampfablauf an, der nach 30 Sekunden ohne Fortschritt den Zustand loggt und den Spieler zur Oberwelt mit dem letzten Spielstand zurückbringt.
3615. [P2] Behandle `NOTIFICATION_OS_MEMORY_WARNING`, indem Caches (Karten, Kampf-Sprites) geleert und ein Logeintrag geschrieben werden.
3616. [P2] Behandle `NOTIFICATION_WM_GO_BACK_REQUEST` auf Android in jedem Bildschirm einheitlich (Menü schließen, im Titel nachfragen) und teste jeden Bildschirm.
3617. [P2] Prüfe, dass ein Doppeltipp auf jeden Knopf, der eine Netzwerkanfrage auslöst, die Anfrage nur einmal sendet, und sperre Knöpfe bis zur Antwort.
3618. [P2] Zeige bei jedem Netzwerkfehler eine verständliche Meldung mit Fehlercode (z. B. "N-503"), damit Support-Anfragen eindeutig zuzuordnen sind.
3619. [P2] Schreibe in `docs/FEHLERCODES.md` eine Liste aller Fehlercodes mit Bedeutung und Lösung für den Support.
3620. [P2] Werte die eingesandten Fehlerberichte wöchentlich mit einer SQL-Abfrage nach App-Version und häufigster Logzeile aus und lege das Ergebnis als Text ab.
3621. [P1] Lade die Debug-Symbole der Android-Bibliotheken in die Play Console hoch, damit Abstürze in Android Vitals lesbare Stacks zeigen.
3622. [P2] Lade die dSYM-Dateien des iOS-Builds als CI-Artefakt hoch und bewahre sie 1 Jahr auf, damit Absturzberichte aus App Store Connect lesbar sind.
3623. [P2] Lege eine Regel fest, dass jeder gemeldete Absturz einen GUT-Test bekommt, der ihn nachstellt, bevor er behoben wird.
3624. [P3] Speichere beim Start eine Markierung "läuft" und lösche sie beim sauberen Beenden, damit beim nächsten Start ein Absturz erkannt und der Fehlerbericht angeboten wird.
3625. [P3] Zeige nach einem erkannten Absturz einmal einen ruhigen Hinweis mit "Fehlerbericht senden" und "Nein danke", ohne Druck.
3626. [P3] Baue einen sicheren Start, der nach zwei Abstürzen in Folge mit Standardeinstellungen und ohne Retro-Filter startet.
3627. [P3] Lege eine Absturzquote als Ziel fest (unter 0,5 % der Sitzungen laut Play Console) und prüfe sie bei jeder Version.
3628. [P3] Erzeuge in Debug-Builds mit einem versteckten Menüpunkt absichtlich einen Fehler, um den Weg vom Log bis zum Bericht zu testen.
3629. [P3] Prüfe Godot-Warnungen beim Laden aller Szenen (`orphan nodes`, fehlende Ressourcen) und baue sie ab, bis die Ausgabe leer ist.
3630. [P3] Teste das Verhalten bei vollem Gerätespeicher, indem `user://` in einem Test schreibgeschützt gemacht wird, und zeige eine klare Meldung.
3631. [P3] Gib dem Fehlerbericht eine Liste der letzten 20 Bildschirmwechsel mit, damit der Weg zum Fehler sichtbar ist, ohne Spielerdaten.
3632. [P3] Lege fest, dass Debug-Ausgaben mit `print` in Release-Builds abgeschaltet sind, und prüfe das mit einer Regel in `tools/headless_check.sh`.

### Lokale Speicherstände
3633. [x] [P1] Behalte statt einer einzigen `.bak.json` drei rotierende Sicherungen pro Slot und lade beim Fehler die neueste lesbare.
3634. [x] [P1] Füge jedem Spielstand eine SHA-256-Prüfsumme über den Inhalt hinzu, damit abgeschnittene oder beschädigte Dateien sicher erkannt werden.
3635. [x] [P1] Speichere zusätzlich bei `NOTIFICATION_WM_CLOSE_REQUEST` und `NOTIFICATION_APPLICATION_FOCUS_OUT`, weil iOS die App sonst ohne Pause-Signal beenden kann.
3636. [x] [P1] Lege eine CI-Regel an, die scheitert, wenn `save_version` steigt, ohne dass in `tests/fixtures/saves/` eine passende Datei und ein Migrationstest dazukommen.
3637. [x] [P1] Prüfe nach jedem Schreiben, ob die Datei wieder lesbar ist und dieselbe Prüfsumme hat, bevor die alte Sicherung überschrieben wird.
3638. [P2] Schreibe auch die Einstellungsdatei über `write_atomic`, damit ein Absturz beim Speichern keine leeren Einstellungen hinterlässt.
3639. [P2] Begrenze einen Spielstand auf 256 KB und lass einen Test scheitern, wenn ein voll ausgespieltes Testprofil größer wird.
3640. [P2] Erzeuge einen Test-Spielstand mit allem (alle Spirlings, alle Gegenstände, volle Liste der Aufgaben) und nutze ihn für Größen- und Ladetests.
3641. [P2] Miss die Speicherzeit auf dem Android-Referenzgerät und halte sie unter 50 ms, damit Autosave nie ruckelt.
3642. [P2] Speichere nicht öfter als einmal alle 10 Sekunden automatisch und fasse schnell aufeinanderfolgende Speicherwünsche zusammen.
3643. [P2] Schreibe für jede Migrationsfunktion in `SaveManager.gd` einen Test, der eine Datei der vorigen Version lädt und jedes Feld prüft.
3644. [P2] Teste, dass ein Spielstand aus einer neueren App-Version in einer älteren nicht überschrieben wird, sondern eine klare Meldung "Bitte aktualisieren" erscheint.
3645. [P2] Teste, dass unbekannte Felder in einem Spielstand beim Laden und Speichern erhalten bleiben, damit eine Rückkehr zur neueren Version nichts verliert.
3646. [P2] Prüfe, dass `delete_save` auch die rotierenden Sicherungen und temporären Dateien löscht, und teste das.
3647. [P2] Lege fest, dass Spielstände nie Godot-Objekte, sondern nur JSON-Grundtypen enthalten, und prüfe das mit einem Test über `build_save()`.
3648. [P2] Zeige im Titelbildschirm neben jedem Slot Datum und Uhrzeit der letzten Speicherung, damit Spieler die Sicherung erkennen.
3649. [P3] Biete in den Einstellungen "Sicherung wiederherstellen" an, das die drei lokalen Sicherungen mit Datum zeigt und eine auswählen lässt.
3650. [P3] Schreibe ein Werkzeug `tools/save_inspect.py`, das einen Spielstand liest, die Prüfsumme prüft und eine lesbare Zusammenfassung ausgibt.
3651. [P3] Lege in `docs/SAVES.md` das Speicherformat mit allen Feldern, Versionen und Migrationen fest.
3652. [P3] Speichere die Uhrzeit im Spielstand immer als UTC, damit Zeitzonenwechsel keine falschen Zeitstempel erzeugen.
3653. [P3] Teste das Laden mit einem Spielstand, der Umlaute, Emojis und sehr lange Namen enthält.
3654. [P3] Prüfe, dass ein abgebrochenes Speichern (Datei halb geschrieben) beim nächsten Start sauber aufgeräumt wird und keine `.tmp`-Dateien liegen bleiben.
3655. [P3] Komprimiere große Spielstände mit `PackedByteArray.compress` erst, wenn sie über 128 KB liegen, und halte das Format in `docs/SAVES.md` fest.
3656. [P3] Entferne nach drei erfolgreichen Versionen die ältesten Migrationsfunktionen nicht, sondern friere sie mit ihren Tests ein.

### Server-Sync und Netzwerk
3657. [x] [P1] Ersetze den festen Wiederholungstakt von 4 Sekunden in `Online.gd` durch steigende Wartezeiten (4, 8, 16, 30 Sekunden) mit 20 % Zufallsanteil, damit nach einem Serverneustart nicht alle Spieler gleichzeitig anfragen.
3658. [x] [P1] Gib jedem `save_put` eine eindeutige Anfrage-ID mit, damit eine doppelt gesendete Anfrage nach einem Timeout auf dem Server nur einmal zählt.
3659. [x] [P1] Speichere nicht gesendete Spielstände in einer Warteschlange in `user://`, damit sie auch nach einem Neustart der App hochgeladen werden.
3660. [P1] Gleiche die Plausibilitätsprüfung `_save_ok` an die Spielregeln an (Ring 1 bis 60 statt 100, Team höchstens 5 statt 6) und lies die Grenzen aus `server_config`, damit Server und Spiel dieselben Werte nutzen.
3661. [P1] Wechsle vor dem Store-Start von `sslip.io` auf eine eigene Domain und lass die alte Adresse 12 Monate lang weiter funktionieren, weil ältere Builds sie fest eingebaut haben.
3662. [x] [P1] Lege eine Obergrenze für die Größe einer Anfrage in Caddy fest (512 KB für `/rest/v1/*`) und eine für `p_data` in `save_put` (256 KB).
3663. [P2] Senke den Timeout in `SupabaseBackend.gd` für kleine Anfragen auf 8 Sekunden und lasse 15 Sekunden nur für das Hochladen von Spielständen.
3664. [P2] Erneuere das Anmelde-Token, wenn es in weniger als 10 Minuten abläuft, und nicht erst nach einem Fehler 401.
3665. [P2] Teste das Verhalten, wenn das Token während einer laufenden Anfrage abläuft, mit `LocalBackend` und einem künstlichen Ablauf.
3666. [P2] Zeige den Konfliktbildschirm beim Speichern mit Ort, Spielzeit und Datum beider Stände, damit die Wahl eindeutig ist.
3667. [P2] Lege serverseitig für jeden Slot die letzten 5 Revisionen ab, damit der Support einen versehentlich überschriebenen Stand zurückholen kann.
3668. [P2] Schreibe eine Admin-Funktion `admin_restore_save(uid, slot, rev)`, die nur der Dienst-Rolle erlaubt ist und in `docs/ONLINE.md` beschrieben wird.
3669. [P2] Sende beim Hochladen nur dann einen Spielstand, wenn sich seine Prüfsumme geändert hat, um Datenvolumen und Serverlast zu sparen.
3670. [P2] Miss das Datenvolumen pro Spielstunde und halte es unter 2 MB, damit Spieler mit kleinem Datentarif spielen können.
3671. [P2] Prüfe, dass `min_version` sicher funktioniert, indem ein Test einen alten Client simuliert und den Weg zum Store-Link prüft.
3672. [P2] Stempele `Online.CLIENT_VERSION` und den Versionscode aus derselben Quelle, damit sie nie auseinanderlaufen.
3673. [P2] Behandle Antworten mit unerwartetem JSON (leer, HTML-Fehlerseite, falscher Typ) in `SupabaseBackend.gd` als Netzwerkfehler statt als Absturz.
3674. [x] [P1] Nutze in `server_config` Schalter für jede Online-Funktion (Freunde, Post, Weltziel, Rangliste), damit eine kaputte Funktion ohne neue Version abgeschaltet werden kann.
3675. [P2] Zeige auf dem Wiederverbinden-Bildschirm nach 60 Sekunden einen Link zur Statusseite und die Möglichkeit, zum Titel zurückzukehren.
3676. [P2] Teste den Sync mit künstlich schlechter Verbindung (500 ms Verzögerung, 10 % Verlust) über einen Proxy im CI-Job des Servers.
3677. [P3] Lege eine öffentliche Statusseite `/status` auf dem Server an, die Erreichbarkeit der Datenbank und der Anmeldung als Text zeigt.
3678. [P3] Biete in der Kontoverwaltung "Spielstand jetzt hochladen" mit Anzeige des letzten erfolgreichen Uploads an.
3679. [P3] Prüfe, ob HTTP/2 mit dauerhafter Verbindung die Zahl der TLS-Handshakes pro Sitzung senkt, und miss den Unterschied beim Akku.
3680. [P3] Lege eine Wartungsliste an, die die `motd` automatisch 24 Stunden vor einer geplanten Wartung setzt.
3681. [P3] Schreibe einen Lasttest `tools/online/load_test.py`, der 500 gleichzeitige Spieler mit Anmelden, Speichern und Herzschlag nachstellt und Antwortzeiten misst.
3682. [P3] Halte als Ziel fest, dass 95 % aller Serveraufrufe unter Last von 500 Spielern in weniger als 300 ms antworten.
3683. [P3] Prüfe, dass die Server-Uhrzeit per NTP synchron bleibt, weil Tagesfund und Wochenaufgaben davon abhängen.
3684. [P3] Lege einen Lesemodus fest, in dem der Server bei Wartung nur Lesen erlaubt und das Spiel das klar anzeigt.

### GUT-Tests und Testabdeckung
3685. [P1] Schreibe Tests für `Online.gd` mit einem `LocalBackend`, das gezielt Fehler einspielt (Timeout, 500, 401, leere Antwort), und prüfe jeden Zustand des Wiederverbindens.
3686. [P1] Schreibe einen Test, der jede `.tscn` unter `scenes/` headless instanziiert und wieder freigibt, ohne Fehler und ohne verwaiste Knoten.
3687. [P1] Schreibe einen Gleichheitstest, der dieselben Abläufe (Freundschaft, Post, Weltziel, Löschen) gegen `LocalBackend` und gegen die SQL-Funktionen in `tools/online/sql_test/` laufen lässt und gleiche Ergebnisse verlangt.
3688. [P1] Schalte in GUT die Prüfung auf verwaiste Knoten ein und lass den Testlauf scheitern, wenn ein Test Knoten zurücklässt.
3689. [P2] Miss die Testabdeckung pro Ordner mit einer einfachen Zeilenzählung der getesteten öffentlichen Funktionen und gib sie in der CI-Zusammenfassung aus.
3690. [P2] Lege eine Mindestabdeckung von 80 % der öffentlichen Funktionen für `scripts/battle/` und `scripts/core/` fest.
3691. [P2] Schreibe Tests für `SaveManager.gd`, die einen vollen Datenträger, eine schreibgeschützte Datei und eine fehlgeschlagene Umbenennung nachstellen.
3692. [P2] Schreibe Tests für `Loc.gd`, die prüfen, dass jeder Schlüssel in Deutsch und Englisch existiert und keine Platzhalter wie `%s` fehlen.
3693. [P2] Schreibe Tests für `AccountMenu.gd`, die Konto löschen, Übertragungscode erzeugen und Übertragungscode einlösen von Anfang bis Ende durchspielen.
3694. [P2] Schreibe Tests für die Eltern-Schalter, die prüfen, dass bei ausgeschalteten Freunden keine sozialen Serveraufrufe mehr gesendet werden.
3695. [P2] Teile die GUT-Tests in schnelle (unter 1 Sekunde pro Datei) und langsame Gruppen und lasse bei jedem Push nur die schnellen sowie nachts alle laufen.
3696. [P2] Halte die Laufzeit aller schnellen Tests unter 3 Minuten und gib die 10 langsamsten Tests in der CI-Zusammenfassung aus.
3697. [P2] Gib GUT-Ergebnisse als JUnit-XML aus und zeige sie in GitHub als Testbericht an.
3698. [P2] Lege eine Regel fest, dass ein unzuverlässiger Test in eine Quarantäne-Liste kommt, ein Ticket bekommt und innerhalb von 14 Tagen repariert oder gelöscht wird.
3699. [P2] Prüfe mit einem Test, dass `LegalInfo.gd` keine Platzhalter wie `[DOMAIN]` oder `[E-MAIL]` mehr enthält, sobald ein Release-Build gebaut wird.
3700. [P3] Schreibe Tests für `EraManager.gd`, die jede Era auswählen und prüfen, dass fehlende Grafiken auf `art/era1/` zurückfallen.
3701. [P2] Schreibe einen Test, der prüft, dass jede Eingabe-Aktion, die das Spiel nutzt, in `project.godot` definiert ist.
3702. [P2] Schreibe einen Test für `TapInput`, der sicherstellt, dass ein Tipp auf dem Touchscreen genau einmal zählt, auch wenn Godot zusätzlich einen Mausklick erzeugt.
3703. [P3] Baue Bildvergleichstests mit `tools/screenshot.gd`: Referenzbilder für 12 feste Bildschirme, Abweichung über 0,5 % der Pixel lässt den Test scheitern.
3704. [P3] Lege die Referenzbilder in `tests/golden/` ab und schreibe ein Skript, das sie nach einer gewollten Änderung neu erzeugt.
3705. [P3] Schreibe Tests für `DayCycle.gd` und `Season.gd`, die mit fester Serverzeit an Jahreswechsel, Schaltjahr und Sommerzeitwechsel prüfen.
3706. [P3] Schreibe einen Test, der alle Texte in `data/i18n/` auf eine Höchstlänge pro Textbox prüft, damit nichts abgeschnitten wird.
3707. [P3] Führe Mutationstests für `DamageCalc.gd` und `BondCalc.gd` als Experiment ein und halte fest, wie viele Mutationen die Tests finden.
3708. [P3] Schreibe einen Test, der prüft, dass jede Funktion in `supabase/migrations/` mit `security definer` auch `set search_path` setzt.
3709. [P3] Schreibe einen Test, der prüft, dass jede Tabelle in den Migrationen den Zeilenschutz (RLS) eingeschaltet hat.
3710. [P3] Dokumentiere in `docs/TESTING.md`, wie Tests geschrieben, gruppiert und lokal gestartet werden.

### Headless-, Fuzz- und Langzeittests
3711. [x] [P1] Schreibe einen Spielstand-Fuzzer `tests/fuzz/fuzz_saves.gd`, der die Dateien aus `tests/fixtures/saves/` 2000-mal zufällig verändert (Felder löschen, Typen tauschen, Zahlen kippen) und verlangt, dass das Laden nie abstürzt.
3712. [P1] Schreibe einen Fuzzer für die SQL-Funktionen, der jede öffentliche Funktion mit zufälligen Werten (null, riesige Zahlen, lange Texte, falsche JSON-Typen) aufruft und nur saubere Fehlerantworten erlaubt.
3713. [P1] Erweitere `tools/headless_check.sh` so, dass auch Warnungen über fehlende Ressourcen und `orphan`-Meldungen den Lauf scheitern lassen.
3714. [P2] Schreibe einen Fuzzer für die Antworten des Servers, der `SupabaseBackend.gd` mit zufälligen und kaputten JSON-Antworten füttert.
3715. [P2] Schreibe einen Fuzzer für `Database.gd`, der Kopien der JSON-Dateien zufällig beschädigt und prüft, dass `validate_data.gd` jede Beschädigung meldet.
3716. [P2] Baue einen Tipp-Affen `tests/fuzz/monkey.gd`, der 10 Minuten lang zufällige Eingaben in alle Menüs schickt und Abstürze, Hänger und Fehlerausgaben zählt.
3717. [P2] Lass den Tipp-Affen jede Nacht mit 5 verschiedenen Startwerten laufen und speichere bei einem Fehler den Startwert, damit der Lauf wiederholbar ist.
3718. [P2] Schreibe einen Langzeittest, der headless 2 Stunden lang abwechselnd läuft, kämpft und speichert, und verlangt, dass der Speicher um weniger als 10 % wächst.
3719. [P2] Schreibe einen Langzeittest für den Server, der 24 Stunden lang 50 simulierte Spieler laufen lässt und Fehler sowie Datenbankgröße protokolliert.
3720. [P2] Prüfe headless, dass ein frisch gestartetes Spiel ohne Netzwerk innerhalb von 10 Sekunden den Wiederverbinden-Bildschirm zeigt und nicht hängt.
3721. [P2] Prüfe headless den kompletten neuen Spielstart (Schwierigkeit, Wanderer, Start-Spirling, erster Kampf, Speichern) als Durchlauftest.
3722. [P2] Prüfe headless, dass nach Konto löschen keine Daten mehr auf dem Server und keine Spielstände mehr in `user://` liegen.
3723. [P2] Gib jedem Fuzzer eine feste Laufzeit (höchstens 5 Minuten pro Fuzzer in der Nacht) und eine kurze Fassung mit 30 Sekunden für Pull Requests.
3724. [P2] Sammle jede Eingabe, die einen Fuzzer zum Scheitern gebracht hat, als neue Testdatei in `tests/fixtures/fuzz/`, damit der Fehler nie zurückkommt.
3725. [P2] Prüfe mit einem Test den Wechsel zwischen allen Eras hin und zurück 50-mal und verlange gleichbleibenden Speicher.
3726. [P3] Schreibe einen Fuzzer für den Übertragungscode, der zufällige Codes einlöst und prüft, dass die Sperre nach Fehlversuchen greift.
3727. [P3] Schreibe einen Fuzzer für Wayfarer-Namen (Steuerzeichen, Unicode-Tricks, Rechts-nach-links-Zeichen) und prüfe, dass `_clean_name` sie sicher behandelt.
3728. [P3] Lass einen headless Durchlauf das Spiel mit Englisch und Deutsch starten und auf jedem Bildschirm prüfen, dass kein Schlüssel unübersetzt angezeigt wird.
3729. [P3] Prüfe headless das Laden aller Karten nacheinander und die Erreichbarkeit aller Warps mit dem vorhandenen `WorldValidator.gd`.
3730. [P3] Baue einen Zeitreisetest, der die Serverzeit über 60 Tage vorspult und Tagesfund, Wochenaufgaben und Ablauf der Post prüft.
3731. [P3] Prüfe headless, dass nach einem simulierten Absturz während des Speicherns der nächste Start den letzten guten Stand lädt.
3732. [P3] Gib die Ergebnisse aller Nachtläufe in einer festen Zusammenfassung pro Nacht aus (Fuzzer, Affe, Langzeit) und eröffne bei Fehlern automatisch ein GitHub-Ticket.
3733. [P3] Prüfe einmal pro Monat den Spielstand-Fuzzer mit 50000 Veränderungen in einem langen Lauf.
3734. [P3] Dokumentiere in `docs/TESTING.md`, wie man einen gescheiterten Fuzz-Lauf mit seinem Startwert lokal nachstellt.

### CI und Build-Pipeline
3735. [P1] Bringe `main` auf den Stand des neuesten Builds, schütze `main` mit Pflichtprüfungen (Tests, IP-Prüfung, Release-Prüfung) und erlaube Release-Tags nur von `main`.
3736. [x] [P1] Lege ein Skript `tools/bump_version.py` an, das Versionsname, Android-Versionscode, iOS-Version und `Online.CLIENT_VERSION` in einem Schritt setzt.
3737. [P1] Führe die Store-Builds aus dem lifekit-Repository und die Builds aus diesem Repository auf dieselben gepinnten Versionen zurück und halte in `docs/RELEASE.md` fest, welcher Weg der offizielle ist.
3738. [x] [P1] Pinne alle GitHub Actions in `.github/workflows/` auf eine feste Commit-SHA statt auf `@v4`.
3739. [x] [P1] Lege in jedem Workflow `concurrency` mit Abbruch älterer Läufe für Pull Requests an, damit nicht mehrere Builds für denselben Zweig laufen.
3740. [P2] Speichere den Godot-Importordner `.godot/imported` als Cache zwischen CI-Läufen und miss die gesparte Zeit.
3741. [P2] Setze für jeden CI-Job ein `timeout-minutes` (Tests 15, Android 30, iOS 45), damit hängende Jobs keine Minuten verbrauchen.
3742. [P2] Führe `gdtoolkit` (`gdlint` und `gdformat --check`) als Prüfung für alle Dateien in `scripts/` ein, zuerst nur als Warnung.
3743. [P2] Lass Dependabot für GitHub Actions und die Docker-Images in `server/docker-compose.yml` wöchentliche Update-Vorschläge erstellen.
3744. [P2] Lege eine `CODEOWNERS`-Datei an, die Änderungen an `.github/workflows/`, `server/` und `supabase/` an Alis Zustimmung bindet.
3745. [P2] Prüfe in CI, dass `export_presets.cfg` keine Passwörter, Keystore-Pfade oder Team-IDs im Klartext enthält.
3746. [P2] Lass einen nächtlichen Workflow alle langsamen Tests, Fuzzer und den Tipp-Affen auf `main` laufen und das Ergebnis in die Zusammenfassung schreiben.
3747. [P2] Bewahre Debug-APKs und Web-Builds 14 Tage und Release-Artefakte 90 Tage auf, um Speicherplatz bei GitHub zu sparen.
3748. [P2] Erzeuge bei jedem Release-Tag automatisch einen GitHub-Release mit AAB, IPA-Prüfsumme, Neuigkeiten-Text und Liste der Commits seit dem letzten Tag.
3749. [P2] Prüfe in CI, dass die Neuigkeiten-Texte in `store/` für die neue Version in Deutsch und Englisch geändert wurden, bevor ein Release-Tag gebaut wird.
3750. [P3] Erzeuge zu jedem Release eine Stückliste (SBOM) mit Godot-Version, Export-Vorlagen, Addons und Docker-Images.
3751. [P2] Teste die Export-Vorlagen auf ihre Prüfsumme, bevor sie in CI genutzt werden, damit kein verändertes Paket in einen Build gelangt.
3752. [P2] Gib in jeder Pull-Request-Zusammenfassung APK-Größe, Testzahl, Laufzeit und Benchmark-Werte im Vergleich zu `main` aus.
3753. [P2] Prüfe in CI, dass jede neue Datei unter `scripts/` und `scenes/` ihre `.uid`-Datei mitbringt.
3754. [P3] Baue einen Workflow, der einen Pull Request automatisch als Web-Build unter einem eigenen Pfad `/play/pr-<nummer>/` bereitstellt und nach dem Schließen löscht.
3755. [P3] Lass `gdlint` nach einer Aufräumphase als Pflichtprüfung laufen, sobald `scripts/` ohne Warnung durchläuft.
3756. [P3] Prüfe in CI die Rechtschreibung der deutschen und englischen Spieltexte mit einer eigenen Wortliste.
3757. [P3] Lege einen manuellen Workflow "Hotfix" an, der von einem Release-Tag einen Zweig erzeugt, nur Tests und Release-Build baut und den Patch-Stand erhöht.
3758. [P3] Miss die monatlichen CI-Minuten pro Workflow und halte das Ergebnis in `docs/RELEASE.md` fest, besonders für den teuren macOS-Runner.
3759. [P3] Baue iOS nur bei Tags und manuell, nicht bei jedem Push, um macOS-Minuten zu sparen, und prüfe, dass das so bleibt.
3760. [P3] Lege eine lokale Kurzprüfung `tools/precommit.sh` an, die IP-Prüfung, schnelle Tests und Datenprüfung vor einem Commit ausführt.
3761. [P3] Prüfe vor jedem Godot-Update (z. B. 4.7.3) in einem eigenen Zweig alle Tests, Benchmarks und Exporte, bevor die Version in CI und `AGENTS.md` geändert wird.
3762. [P3] Lege eine Liste der CI-Geheimnisse mit Zweck, Ablaufdatum und Verantwortlichem in `docs/RELEASE.md` an, ohne die Werte selbst.

### Web-Testbuild
3763. [x] [P1] Setze für `/play/` den Header `X-Robots-Tag: noindex` und eine `robots.txt`, damit der Testbuild nicht in Suchmaschinen landet.
3764. [x] [P1] Zeige im Web-Testbuild oben ein kleines Band "Testversion", damit niemand ihn für das fertige Spiel hält.
3765. [x] [P1] Markiere Konten aus dem Web-Testbuild auf dem Server als `platform = web` und lösche sie automatisch nach 30 Tagen ohne Nutzung, wie in der Datenschutzerklärung zu ergänzen.
3766. [P2] Lege ein Größenbudget für den Web-Build fest (WASM plus PCK unter 40 MB) und prüfe es im Job `web-build`.
3767. [P2] Hänge an die Dateinamen des Web-Builds die Build-Nummer an, damit Browser nach einem Update keine alte Version aus dem Cache laden.
3768. [P2] Exportiere den Web-Build ohne Thread-Unterstützung, damit keine besonderen Header (COOP, COEP) nötig sind, und halte das in `docs/RELEASE.md` fest.
3769. [P2] Leite die Startseite `/` nach dem Store-Start nicht mehr auf `/play/`, sondern auf eine kurze Infoseite mit Store-Links um.
3770. [P2] Teste den Web-Build in CI mit Playwright auf einem iPhone- und einem Android-Profil bis zum Titelbildschirm und speichere einen Screenshot.
3771. [P2] Zeige im Web-Build eine klare Meldung, wenn der Browser WebGL 2 nicht unterstützt, statt eines schwarzen Bildschirms.
3772. [P2] Prüfe, dass Speichern im Web-Build über IndexedDB nach einem Neuladen erhalten bleibt, mit einem Playwright-Test.
3773. [P3] Schütze den Web-Testbuild optional mit einem einfachen Zugangscode aus `server_config`, falls er nur für eingeladene Tester gedacht ist.
3774. [P3] Biete im Web-Build eine Tastatursteuerung (Pfeiltasten, Enter, Escape) an und dokumentiere sie auf der Infoseite.
3775. [P3] Stelle für jeden Release-Tag den passenden Web-Build unter `/play/v<version>/` bereit, damit Fehler in alten Versionen nachgestellt werden können.
3776. [P3] Lösche alte Web-Builds auf dem Server automatisch, sobald mehr als 5 Versionen liegen.
3777. [P3] Miss die Ladezeit des Web-Builds über eine 10-Mbit-Verbindung in Playwright und halte sie unter 15 Sekunden.
3778. [P3] Lege eine Datenschutz-Kurzinfo direkt auf der Startseite des Web-Builds an, die auf `/datenschutz` verlinkt.

### Store-Release Android
3779. [P1] Stelle das Spiel darauf ein, dass Android 16 auf Tablets und faltbaren Geräten (ab 600 dp) die Hochformat-Sperre ignoriert, und zeige dort das Bild mittig mit Rand statt verzerrt.
3780. [P1] Prüfe auf Android 15 und 16 die erzwungene Randlos-Darstellung und stelle sicher, dass virtuelles Steuerkreuz und Textboxen nicht unter Statusleiste oder Gestenleiste liegen.
3781. [P1] Setze vor der Produktion einen gestaffelten Rollout (10 %, 50 %, 100 % mit je 48 Stunden Abstand) und halte in `docs/RELEASE.md` fest, wann er angehalten wird.
3782. [P1] Werte vor jeder Rollout-Stufe Android Vitals aus und halte an, wenn die Absturzrate 1,09 % oder die ANR-Rate 0,47 % übersteigt (Grenzwerte von Google).
3783. [P1] Werte den Pre-Launch-Bericht der Play Console für jeden Build aus und behebe alle Abstürze und Barrierefreiheitsfehler vor dem Rollout.
3784. [P2] Plane die jährliche Anhebung des Ziel-API-Stands ein (Google verlangt jeden August die neue Stufe) und lege eine Erinnerung für Juni 2027 an.
3785. [P2] Teste den Build auf mindestens 5 echten Geräten aus dem Play-Gerätekatalog (alt, klein, groß, faltbar, Tablet) und trage die Ergebnisse in `docs/GERAETE.md` ein.
3786. [P2] Prüfe, dass die App nur die Berechtigung `INTERNET` anfordert und keine weitere, mit einer Prüfung in `tools/release_check.py`.
3787. [P2] Prüfe die Vorhersage-Zurück-Geste von Android 16 und stelle sicher, dass ein Zurückwischen im Kampf nicht das Spiel beendet.
3788. [P3] Teste den Build mit großer Systemschrift und Anzeigegröße und stelle sicher, dass das Spiel seine feste Pixelgröße behält.
3789. [P2] Pflege den geschlossenen Test mit 12 Testern über 14 Tage mit einer festen Testanleitung in `docs/TESTPLAN.md` (10 Aufgaben, die jeder Tester einmal macht).
3790. [P3] Lege eine Antwortvorlage für Play-Bewertungen in Deutsch und Englisch für die 10 häufigsten Fragen an.
3791. [P2] Prüfe die Store-Seite auf Ehrlichkeit: Online-Pflicht, Kontomodell und In-App-Käufe müssen in der Beschreibung klar genannt sein.
3792. [P2] Aktualisiere die Data-Safety-Angaben vor jedem Release mit einer festen Liste in `docs/legal/STORE_COMPLIANCE.md`, sobald Fehlerberichte oder Käufe dazukommen.
3793. [P2] Prüfe, dass `android:allowBackup` so gesetzt ist, dass Android-Sicherungen keine Anmelde-Tokens auf ein fremdes Gerät mitnehmen.
3794. [P2] Lege fest, wie ein fehlerhafter Build zurückgenommen wird (Rollout anhalten, neuer Build mit höherem Versionscode, Server-Schalter) und übe das einmal im internen Test.
3795. [P3] Teste das Spiel auf ChromeOS-Geräten mit Tastatur und entscheide, ob die App dort angeboten wird.
3796. [P3] Lege eigene Store-Einträge für Österreich und die Schweiz an, falls andere Texte nötig sind, sonst halte fest, dass der deutsche Eintrag reicht.
3797. [P3] Biete Store-Texte in weiteren Sprachen erst an, wenn das Spiel selbst übersetzt ist, und halte die Regel in `store/README.md` fest.
3798. [P3] Prüfe die Option "Für Familien entwickelt" erst, wenn das Spiel alle Vorgaben dafür erfüllt, und bleibe bis dahin bei Zielgruppe 13+.
3799. [P3] Nutze die Play Console für einen kurzen Experimenttest der Store-Grafik (zwei Varianten), der ohne SDK im Spiel auskommt.
3800. [P3] Lege eine Liste mit Gerätemodellen an, auf denen das Spiel nicht läuft, und sperre sie im Gerätekatalog, statt schlechte Bewertungen zu riskieren.
3801. [P3] Prüfe einmal pro Quartal, ob neue Play-Richtlinien das Spiel betreffen, und halte das Ergebnis in `docs/legal/STORE_COMPLIANCE.md` fest.
3802. [P3] Bereite eine Antwort für den Fall vor, dass Google den Build wegen der Online-Pflicht ohne Zugangsdaten ablehnt.

### Store-Release iOS
3803. [P1] Teste den Build vor dem ersten Einreichen in einem reinen IPv6-Netz (NAT64 über die Internetfreigabe von macOS), weil Apple so prüft und der Server bisher nur IPv4 hat.
3804. [P1] Prüfe nach dem Export die erzeugte `PrivacyInfo.xcprivacy` gegen die Angaben in App Store Connect und lege den geprüften Stand in `docs/legal/STORE_COMPLIANCE.md` ab.
3805. [P1] Beantworte den neuen Altersfragebogen von Apple (seit 31. 1. 2026) mit In-App-Käufen neu, sobald Käufe im Spiel sind, und halte die Antworten fest.
3806. [P1] Teste den iOS-Build auf einem Gerät mit Dynamic Island und einem mit Home-Taste, damit sichere Bereiche auf beiden stimmen.
3807. [P2] Nutze den externen TestFlight-Test mit einer Gruppe von höchstens 50 Testern vor jeder größeren Version und plane einen Tag für die Beta-Prüfung ein.
3808. [P2] Lege die Hinweise für die App-Prüfung in `store/ios/review_information/notes.txt` so an, dass ein Prüfer ohne Konto sofort spielen kann.
3809. [P2] Teste, dass die App nach einem Wechsel in den Hintergrund und 30 Minuten Wartezeit ohne Datenverlust weiterläuft oder sauber neu lädt.
3810. [P2] Prüfe, dass die App ohne Netz beim Start eine klare Meldung zeigt, weil Apple Apps ablehnt, die ohne Hinweis leer bleiben.
3811. [P2] Prüfe die Absturzberichte im Xcode Organizer nach jeder Version und verknüpfe sie mit den dSYM-Dateien aus CI.
3812. [P2] Teste den Übertragungscode zwischen einem Android- und einem iOS-Gerät in beide Richtungen vor jedem Release.
3813. [P2] Plane die jährliche Verlängerung des Apple-Entwicklerkontos (99 $) und des Verteilungszertifikats mit einer Erinnerung 30 Tage vorher.
3814. [P2] Lege eine Antwortvorlage für typische Ablehnungsgründe (2.1 Absturz, 4.2 zu wenig Inhalt, 5.1.1 Daten) an.
3815. [P2] Prüfe, dass Bildschirmfotos aus dem Spiel keine echte IP-Adresse oder Debug-Texte zeigen, bevor sie in den Store kommen.
3816. [P3] Teste den Build mit den iOS-Bedienungshilfen "Fettere Schrift" und "Bewegung reduzieren" und halte fest, was das Spiel davon beachtet.
3817. [P3] Entscheide, ob das Spiel später auf dem iPad angeboten wird, und prüfe dafür die Darstellung mit Rand bei 4:3.
3818. [P3] Prüfe, ob das Spiel auf Macs mit Apple-Chip angeboten werden soll, und schalte es sonst in App Store Connect ab.
3819. [P3] Nutze die Produktseiten-Optimierung von App Store Connect für einen Test zweier Symbolvarianten ohne SDK im Spiel.
3820. [P3] Lege eine Erinnerung für die jährliche Pflicht an, mit dem neuen Xcode-SDK zu bauen (meist ab April), und teste den Build vorher.
3821. [P3] Prüfe einmal pro Quartal die App-Review-Richtlinien auf Änderungen, die das Spiel betreffen.
3822. [P3] Lege fest, wie ein fehlerhafter iOS-Build behandelt wird (beschleunigte Prüfung beantragen, Server-Schalter, Hinweis über `motd`).
3823. [P3] Teste den Build auf dem ältesten unterstützten iPhone mit vollem Speicher, damit das Spiel auch bei wenig freiem Platz startet.
3824. [P3] Prüfe, ob eine Vorbestellung im App Store vor dem Start Sinn ergibt, und halte die Entscheidung in `docs/STORE_RELEASE.md` fest.

### Server-Betrieb: Backups und Wiederherstellung
3825. [P1] Kopiere die nächtlichen Datenbanksicherungen zusätzlich verschlüsselt (mit `age`) zu einem zweiten Anbieter in der EU, weil sie bisher nur auf demselben Server liegen.
3826. [x] [P1] Lege einen wöchentlichen Workflow an, der die neueste Sicherung in eine Wegwerf-Datenbank zurückspielt, `server/smoke_test.sh` dagegen laufen lässt und bei Fehler ein Ticket öffnet.
3827. [x] [P1] Halte die Aufbewahrung aller Sicherungen (lokal 14 Tage, extern höchstens 30 Tage) fest und gleiche sie mit der Löschfrist in `docs/legal/DATENSCHUTZ.md` ab.
3828. [x] [P1] Schreibe in `docs/BETRIEB.md` eine Schritt-für-Schritt-Anleitung, wie der ganze Server auf einer neuen Maschine aus Sicherung und Repository in unter 2 Stunden wieder läuft.
3829. [P1] Bewahre den privaten Schlüssel für die Sicherungsverschlüsselung und die Server-Geheimnisse (JWT-Secret, Datenbank-Passwort) offline bei Ali auf und halte fest, wo.
3830. [P2] Prüfe in `server/backup.sh` nach jedem Lauf die Größe der Sicherung und melde einen Fehler, wenn sie mehr als 50 % kleiner als am Vortag ist.
3831. [P2] Schreibe zu jeder Sicherung eine Prüfsumme und prüfe sie vor dem Hochladen und vor jedem Zurückspielen.
3832. [P2] Sichere auch `.env`, Caddy-Daten (Zertifikate) und die Proxy-Kopien in `/opt/chimora/server/backups/` verschlüsselt mit.
3833. [x] [P1] Lege vor jeder Datenbank-Migration automatisch eine Sicherung an und brich die Migration ab, wenn das scheitert.
3834. [P2] Schreibe für jede Migration eine Rückweg-Datei oder halte im Kopf der Datei fest, warum es keinen Rückweg gibt.
3835. [P2] Übe die Wiederherstellung eines einzelnen Kontos aus einer Sicherung, ohne die übrige Datenbank anzufassen, und dokumentiere die SQL-Schritte.
3836. [P2] Lösche bei der Kontolöschung auch die serverseitigen Spielstand-Revisionen und halte fest, dass Sicherungen nach 30 Tagen nachziehen.
3837. [P2] Schreibe die Ergebnisse jedes Sicherungslaufs in eine Datei, die das Monitoring auf ein Alter über 26 Stunden prüft.
3838. [P2] Prüfe, dass die Sicherung nicht auf derselben Festplatte wie die Datenbank liegt, oder verschiebe sie auf ein eigenes Volume.
3839. [P2] Halte den belegten Speicherplatz des Servers unter 70 % und lösche bei Bedarf alte Docker-Images mit einem wöchentlichen Aufräumlauf.
3840. [P3] Prüfe, ob eine laufende Archivierung der Datenbank-Protokolle (WAL) eine Wiederherstellung auf die Minute genau ermöglicht, und führe sie ein, sobald mehr als 1000 Spieler aktiv sind.
3841. [P3] Lege einen zweiten, kalten Server-Plan bei einem anderen Rechenzentrum fest, der bei einem Ausfall von Contabo in einem Tag startbar ist.
3842. [P3] Übe einmal pro Quartal den kompletten Wiederaufbau auf einer frischen Maschine und trage die gemessene Zeit in `docs/BETRIEB.md` ein.
3843. [P3] Lege eine Liste der Abhängigkeiten an, die beim Wiederaufbau nötig sind (Domain, DNS, GitHub-Geheimnisse, Zertifikate), mit Zugangsweg.
3844. [P3] Halte fest, wie lange der Server ohne Sicherung laufen darf (Ziel: höchstens 24 Stunden Datenverlust), und wie lange er ausfallen darf (Ziel: höchstens 4 Stunden).
3845. [P3] Trenne den Chimora-Server langfristig von Nyrathen und Dranbleib auf eine eigene Maschine, sobald die Last oder ein Sicherheitsvorfall es nötig macht.
3846. [P3] Schreibe ein Skript `server/restore.sh`, das eine Sicherung prüft, entschlüsselt und nach Bestätigung zurückspielt.

### Server-Betrieb: Monitoring, Updates und Kapazität
3847. [x] [P1] Lege einen geplanten GitHub-Workflow an, der alle 15 Minuten Anmeldung, `hello` und die Rechtsseiten von außen prüft und bei zwei Fehlern hintereinander ein Ticket öffnet und Ali per E-Mail benachrichtigt.
3848. [x] [P1] Begrenze die Docker-Logs aller Dienste auf 7 Tage und 50 MB pro Dienst (`logging` mit `max-size` und `max-file`), damit Platte und Datenschutzversprechen stimmen.
3849. [x] [P1] Pinne alle Docker-Images in `server/docker-compose.yml` zusätzlich auf ihren Digest und aktualisiere sie nur über geprüfte Pull Requests.
3850. [x] [P1] Lege fest, dass Sicherheitsupdates für Postgres, GoTrue, PostgREST und Caddy innerhalb von 7 Tagen eingespielt werden, und halte jedes Update in `docs/BETRIEB.md` fest.
3851. [P2] Schalte `pg_stat_statements` in Postgres ein und erzeuge wöchentlich eine Liste der 10 langsamsten Serverfunktionen.
3852. [P2] Lege eine Tabelle `ops_daily` an, die pro Tag nur Summen speichert (aktive Konten, Speichervorgänge, abgelehnte Spielstände, Fehler pro Funktion), ohne Bezug zu einzelnen Spielern.
3853. [P2] Erzeuge aus `ops_daily` eine einfache Textübersicht unter einem geschützten Pfad, die nur mit einem Admin-Token abrufbar ist.
3854. [P2] Lege Warnschwellen fest: Plattenplatz über 80 %, Speicher über 85 %, mehr als 5 % fehlgeschlagene Anfragen in 15 Minuten, und melde sie per E-Mail.
3855. [P2] Prüfe das Ablaufdatum des TLS-Zertifikats täglich und warne 14 Tage vor Ablauf, falls die automatische Erneuerung scheitert.
3856. [x] [P1] Setze für die Rollen `anon` und `authenticated` ein `statement_timeout` von 3 Sekunden, damit eine langsame Abfrage den Server nicht blockiert.
3857. [P2] Setze in PostgREST eine Höchstzahl an Zeilen pro Antwort (`PGRST_DB_MAX_ROWS` = 200) als Schutz gegen große Abfragen.
3858. [P2] Lege eine Obergrenze für Datenbankverbindungen fest und miss im Lasttest, ab wie vielen Spielern ein Verbindungspool (z. B. PgBouncer) nötig ist.
3859. [P2] Plane Server-Updates mit Neustart in einem festen Wartungsfenster (Dienstag 4 bis 5 Uhr) und kündige sie über `motd` an.
3860. [P2] Prüfe, dass die automatischen Sicherheitsupdates des Betriebssystems laufen, und lass einen Neustart nur im Wartungsfenster zu.
3861. [P2] Halte in `docs/BETRIEB.md` fest, welche Größe der VPS ab wie vielen täglichen Spielern braucht, auf Grundlage des Lasttests.
3862. [P2] Lege ein Bereitschaftsblatt an: wer bei einem Ausfall was tut, in welcher Reihenfolge, mit Vorlage für die `motd` und die Statusseite.
3863. [P3] Plane den Wechsel von Postgres 15 auf eine neuere Hauptversion vor deren Support-Ende mit einer Probe auf einer Kopie.
3864. [P3] Lege eine Aufräumfunktion an, die abgelaufene Übertragungscodes, alte `rate_events` und alte Fehlversuche täglich löscht.
3865. [P3] Miss die Datenbankgröße pro 1000 Spieler und halte die Hochrechnung für 12 Monate in `docs/BETRIEB.md` fest.
3866. [P3] Prüfe einmal pro Monat, ob Indizes fehlen oder ungenutzt sind, mit einer festen SQL-Abfrage.
3867. [P3] Schreibe nach jedem Ausfall über 30 Minuten einen kurzen Bericht (Ursache, Dauer, Gegenmaßnahme) in `docs/vorfaelle/`.
3868. [P3] Lege die monatlichen Serverkosten und die Kosten pro aktivem Spieler in einer Tabelle fest, damit Wachstum planbar bleibt.
3869. [P3] Prüfe einmal pro Jahr, ob der Anbieter Contabo noch passt (Preis, Ausfälle, Support), und halte die Entscheidung fest.
3870. [P3] Biete die Statusseite zusätzlich als einfache JSON-Datei an, damit sie automatisch geprüft werden kann.

### Sicherheit
3871. [P1] Ersetze den Root-Passwort-Zugang (`CHIMORA_SERVER_PASSWORD`) durch einen eigenen SSH-Schlüssel nur für Deploys und schalte die Passwort-Anmeldung per SSH ab.
3872. [x] [P1] Prüfe jede `security definer`-Funktion in `supabase/migrations/` darauf, dass sie `auth.uid()` prüft, `search_path` festlegt und keine fremden Daten zurückgibt, und halte das Ergebnis als Liste fest.
3873. [x] [P1] Begrenze das Anlegen anonymer Konten zusätzlich in Caddy auf 10 pro Stunde pro IP, weil Massenanmeldungen sonst die Datenbank füllen. (Umgesetzt in GoTrue mit `GOTRUE_RATE_LIMIT_ANONYMOUS_USERS: 10`, weil das Standard-Caddy keinen Ratenbegrenzer hat.)
3874. [x] [P1] Setze auf allen Webseiten des Servers die Header `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy` und eine strenge `Content-Security-Policy`.
3875. [P1] Lege in `docs/SICHERHEIT.md` fest, wie das JWT-Secret im Notfall gewechselt wird (alle Spieler melden sich über das gespeicherte Konto neu an) und teste das einmal.
3876. [P2] Begrenze die Aufrufe pro Konto und Minute für alle Serverfunktionen zentral (z. B. 60 pro Minute) und gib bei Überschreitung einen klaren Fehler zurück.
3877. [x] [P1] Prüfe, dass die Admin-API von GoTrue und die Dienst-Rolle von außen nicht erreichbar sind, mit einem Test im Server-Workflow.
3878. [P2] Schalte Fail2ban oder eine gleichwertige Sperre für SSH ein und halte die Einstellungen in `server/setup.sh` fest.
3879. [P2] Prüfe die Plausibilität von Spielständen auf dem Server um weitere Regeln (höchstens 999 pro Gegenstand, keine unbekannten Spirling-IDs, Spielzeit nicht rückwärts).
3880. [P2] Melde serverseitig Konten mit auffälligen Spielständen (z. B. Geldsprung über 100000 in einer Speicherung) in einer Prüfliste, ohne sie automatisch zu sperren.
3881. [P2] Lass `run_secret_scanning` beziehungsweise GitHub Secret Scanning mit Push-Schutz für das Repository eingeschaltet und prüfe es einmal im Monat.
3882. [x] [P1] Prüfe, dass im Spiel nur der öffentliche Anon-Schlüssel steckt und nie ein Dienst-Schlüssel, mit einer Prüfung in `tools/release_check.py`.
3883. [P2] Speichere das Anmelde-Token auf dem Gerät nicht im Spielstand, sondern in einer eigenen Datei, die bei Konto löschen sicher entfernt wird.
3884. [P2] Prüfe, dass `transfer_claim` nach 5 Fehlversuchen pro Stunde sperrt und die Codes genug Zufall haben (mindestens 40 Bit).
3885. [P2] Prüfe, dass Wayfarer-Namen auf dem Server auf erlaubte Zeichen und eine Höchstlänge begrenzt sind, auch wenn das Spiel selbst schon filtert.
3886. [P2] Prüfe, dass Fehlermeldungen des Servers keine SQL-Details oder Tabellennamen an das Spiel zurückgeben.
3887. [P2] Lass einmal im Quartal einen automatischen Schwachstellen-Scan der Docker-Images (z. B. mit Trivy in CI) laufen und behebe kritische Funde.
3888. [P2] Trenne die Container von Chimora im gemeinsamen Netz so, dass Nyrathen und Dranbleib nicht direkt auf die Chimora-Datenbank zugreifen können, und teste das.
3889. [P2] Lege eine Adresse `security@` und eine Datei `/.well-known/security.txt` an, über die Sicherheitslücken gemeldet werden können.
3890. [P2] Schütze den `prod`-Bereich in GitHub mit Pflichtfreigabe durch Ali und halte fest, welche Geheimnisse dort liegen.
3891. [P3] Prüfe, ob Zertifikats-Pinning im Spiel sinnvoll ist, und halte die Entscheidung fest (Risiko eines Ausfalls bei Zertifikatswechsel beachten).
3892. [P3] Lass einmal pro Jahr einen Sicherheitsrückblick über Server, Funktionen und Geheimnisse mit einer festen Checkliste in `docs/SICHERHEIT.md` laufen.
3893. [P3] Prüfe, ob die Godot-PCK-Verschlüsselung den Aufwand wert ist, und halte fest, dass sie keine echte Sicherheit für Server-Regeln bietet.
3894. [P3] Lege eine Regel fest, dass alle Regeln, die Belohnungen oder Ranglisten betreffen, nur auf dem Server entschieden werden.
3895. [P3] Prüfe Ranglistenwerte serverseitig gegen eine Obergrenze pro Woche und verwerfe unmögliche Werte.
3896. [P3] Lege einen Plan für den Fall eines Datenlecks an (Server isolieren, Geheimnisse wechseln, Meldung an die Behörde) in `docs/SICHERHEIT.md`.
3897. [P3] Prüfe, dass die Server-Firewall nach jedem `setup.sh`-Lauf nur die Ports 22, 80 und 443 offen hat, mit einem Test von außen.
3898. [P3] Wechsle SSH auf einen nicht standardmäßigen Port erst, wenn die Logs viele Anmeldeversuche zeigen, und halte die Entscheidung fest.

### Datenschutz und DSGVO
3899. [x] [P1] Setze die versprochene Löschung inaktiver Konten nach 24 Monaten technisch um (täglicher Lauf, Hinweis im Spiel 30 Tage vorher), weil die Datenschutzerklärung sie schon verspricht. (Umgesetzt als Markierung mit 30 Tagen Frist; ein Hinweis im Spiel erreicht inaktive Spieler nicht, die Erklärung sagt das jetzt so.)
3900. [x] [P1] Setze die versprochene Löschung von Meldungen nach höchstens 6 Monaten und von Wochenwerten nach Ende der Folgewoche als täglichen Lauf um und teste beide.
3901. [x] [P1] Lege das Verzeichnis der Verarbeitungstätigkeiten nach Art. 30 DSGVO als `docs/legal/VVT.md` an, mit jeder Tabelle, Zweck, Rechtsgrundlage und Frist. (Umgesetzt in `docs/legal/VERARBEITUNGEN.md`, gemeinsam mit Bereich 7.)
3902. [x] [P1] Prüfe die Datenschutzerklärung gegen den tatsächlichen Stand (Contabo, gemeinsamer Server, Fehlerberichte, Web-Testbuild, Käufe) und ändere sie vor dem Store-Start.
3903. [P1] Baue unter Menü, Konto einen Punkt "Meine Daten" (Art. 15 und 20 DSGVO), der über eine Serverfunktion `export_my_data` alle eigenen Daten als JSON zum Teilen anbietet.
3904. [x] [P1] Prüfe, ob GoTrue oder PostgREST IP-Adressen in eigene Tabellen (z. B. `auth.audit_log_entries`) schreiben, und lösche diese Einträge nach 7 Tagen wie versprochen.
3905. [P2] Lege die technischen und organisatorischen Maßnahmen (TOM) nach Art. 32 DSGVO in `docs/legal/TOM.md` an, passend zu Server, Backups und Zugängen.
3906. [P2] Lege eine Vorlage für Datenpannen nach Art. 33 DSGVO (Meldung binnen 72 Stunden an die hessische Aufsichtsbehörde) in `docs/legal/DATENPANNE.md` an.
3907. [P2] Prüfe, ob der gemeinsame Server mit Nyrathen und Dranbleib in der Datenschutzerklärung und im AV-Vertrag richtig abgebildet ist.
3908. [P2] Ergänze die Datenschutzerklärung um die freiwilligen Fehlerberichte (Daten, Zweck, Einwilligung nach Art. 6 Abs. 1 lit. a, Löschung nach 90 Tagen).
3909. [P2] Lege eine Antwortvorlage für Auskunfts-, Lösch- und Berichtigungsanfragen per E-Mail mit Frist von einem Monat an.
3910. [P2] Prüfe, dass die Löschung per E-Mail ohne App (Webseite `/konto-loeschen`) eine dokumentierte Admin-Funktion hat und innerhalb von 30 Tagen erledigt wird.
3911. [P2] Lege ein einfaches Protokoll für Lösch- und Auskunftsanfragen an (Datum, Art, erledigt am), ohne mehr Daten als nötig.
3912. [P2] Prüfe die Rechtsgrundlage für Spieler unter 16 Jahren (Vertrag über die Eltern) und halte die Begründung in `docs/legal/VERARBEITUNGEN.md` fest.
3913. [P1] Zeige beim ersten Start die Nutzungsbedingungen und die Datenschutzerklärung mit Zustimmungsknopf und speichere Version und Zeitpunkt der Zustimmung auf dem Server.
3914. [P2] Zeige nach einer wesentlichen Änderung der Nutzungsbedingungen beim nächsten Start die neue Fassung mit erneuter Zustimmung.
3915. [P2] Gleiche die englische Privacy Policy und die AGB in Englisch automatisch mit der deutschen Fassung ab (gleiche Abschnitte, gleiche Fristen) über `tools/site/build_site.py --check`.
3916. [P2] Prüfe, dass keine Spielerdaten in CI-Logs, Testfixtures oder Fehlerberichten im Repository landen.
3917. [P2] Prüfe, dass der Support-Weg (E-Mail) keine Spielerdaten in fremde Ticketsysteme schickt, und halte das Postfach beim Anbieter in der EU.
3918. [P2] Lege fest, dass jede neue Datenart (z. B. Kaufbelege aus Bereich 10) erst in `docs/legal/VERARBEITUNGEN.md` und der Datenschutzerklärung stehen muss, bevor sie gespeichert wird, und prüfe das im Pull-Request-Text.
3919. [P2] Prüfe, ob die Wochen-Rangliste ohne Namen wirklich keine Rückschlüsse auf einzelne Spieler erlaubt (z. B. bei sehr wenigen Teilnehmern).
3920. [P2] Lösche Konten aus dem geschlossenen Test und interne Testkonten vor dem Store-Start und markiere künftige Testkonten eindeutig.
3921. [P3] Prüfe einmal pro Jahr alle Speicherfristen gegen die tatsächlichen Daten mit einer festen SQL-Abfrage und halte das Ergebnis fest.
3922. [P3] Lege eine kurze, kindgerechte Fassung der Datenschutzerklärung im Spiel an (eine Seite, einfache Sprache).
3923. [P3] Prüfe, ob eine Datenschutz-Folgenabschätzung nach Art. 35 nötig ist, und halte die Begründung fest, auch wenn sie nicht nötig ist.
3924. [P3] Biete die Datenauskunft auch über die Webseite an, mit Anmeldung über den Übertragungscode.
3925. [P3] Prüfe, dass die Webseiten des Servers keine externen Schriften, Skripte oder Bilder laden, damit keine Daten an Dritte gehen.
3926. [P3] Halte die Liste der Auftragsverarbeiter (Hoster, Sicherungsanbieter, E-Mail-Anbieter) in der Datenschutzerklärung aktuell.
3927. [P3] Prüfe einmal pro Jahr, ob der Zweck jeder gespeicherten Spalte noch besteht, und lösche Spalten, die nicht mehr gebraucht werden.
3928. [P3] Lege eine Regel fest, dass Daten aus `ops_daily` nie mit Spieler-IDs verknüpft werden, und prüfe das im SQL-Test.

### Jugendschutz und Verbraucherrecht
3929. [P1] Stelle `docs/legal/STORE_COMPLIANCE.md` und `docs/MONETIZATION.md` auf das neue Modell (kostenlos mit In-App-Käufen) um, damit IARC, Apple-Alter und Data Safety mit "Digitale Käufe: ja" neu beantwortet werden.
3930. [P1] Rechne mit dem USK-Hinweis "In-Game-Käufe" und prüfe, ob bezahlte Vorteile im Kampf die erwartete Altersstufe ändern, bevor der Shop live geht.
3931. [x] [P1] Lege in `docs/legal/SHOP_RECHT.md` eine Prüfliste für alle Shop-Texte an: keine direkte Kaufaufforderung an Kinder (UWG Anhang Nr. 28), Echtgeld-Preis immer sichtbar, keine künstliche Zeitnot.
3932. [x] [P1] Halte die bestehende Regel "keine bezahlten Zufallsinhalte" in `docs/legal/SHOP_RECHT.md` fest, weil sie Altersstufe, Apple-Pflicht zur Anzeige der Chancen und das Verbot in Belgien auslöst.
3933. [x] [P1] Ergänze die Nutzungsbedingungen um einen Abschnitt zu virtuellen Gütern (kein Eigentum, kein Umtausch in Geld, Verhalten bei Kontolöschung) mit Hinweis zum Widerrufsrecht bei digitalen Inhalten.
3934. [P2] Prüfe die Grundsätze der EU-Verbraucherschutzbehörden zu Spielwährungen (März 2025) und halte in `docs/legal/SHOP_RECHT.md` fest, welche Punkte Bereich 10 umsetzen muss.
3935. [P2] Erkläre auf der Support-Seite, wie Eltern Käufe über die Familienfunktionen von Apple und Google sperren oder bestätigen lassen.
3936. [P2] Lege eine Vorlage für Erstattungsanfragen an, die auf die Erstattungswege von Apple und Google verweist, weil der Händler das nicht selbst abwickelt.
3937. [P2] Prüfe, ob die Store-Beschreibung mit "kostenlos" den Hinweis "enthält In-App-Käufe" sichtbar trägt, wie beide Stores es verlangen.
3938. [P2] Prüfe die Altersfreigabe neu, sobald sich Online-Funktionen ändern (z. B. sichtbare Namen für Fremde), und halte jede Neubewertung fest.
3939. [P2] Lege die Pflichtangaben nach dem Digital Services Act für Meldungen (Begründung bei Namens-Zurücksetzung, Art. 17) als Vorlage im Support-Ordner ab.
3940. [P2] Prüfe die wöchentliche Bearbeitung der Meldungen aus der Tabelle `reports` mit einer festen SQL-Abfrage und einer Frist von 7 Tagen pro Meldung.
3941. [P2] Lege eine Liste der Pflichtangaben für Spieler in der EU fest (Händlerangaben, Kontaktstelle, Meldeweg) und prüfe sie mit `tools/release_check.py`.
3942. [P2] Prüfe, ob das Jugendschutzgesetz (§ 24a JuSchG) mit seinen Vorsorgepflichten bei der erwarteten Spielerzahl greift, und halte die Schwelle fest.
3943. [P2] Prüfe, dass alle Eltern-Schalter auch nach einem Gerätewechsel über den Übertragungscode erhalten bleiben.
3944. [P2] Zeige in den Einstellungen eine kurze Elternseite mit allen Schaltern, der Spielzeit der letzten 7 Tage und Links zu den Kaufsperren der Stores.
3945. [P3] Biete eine freiwillige Spielzeit-Erinnerung an (nach 60, 90 oder 120 Minuten), die nur einen Hinweis zeigt.
3946. [P3] Prüfe einmal pro Jahr die Leitlinien der USK und von PEGI auf Änderungen bei In-Game-Käufen.
3947. [P3] Lege fest, dass Werbung für das Spiel (Social Media, Store-Texte) nie Kinder direkt zum Kaufen auffordert, und halte das in `docs/legal/SHOP_RECHT.md` fest.
3948. [P3] Prüfe, ob die Nutzungsbedingungen eine verständliche Kurzfassung für Jugendliche brauchen, und lege sie bei Bedarf an.
3949. [P3] Lege eine Regel für Kontosperren fest (Gründe, Dauer, Einspruch per E-Mail) und schreibe sie in die Nutzungsbedingungen.
3950. [P3] Prüfe die Barrierefreiheitspflicht (BFSG) erneut, sobald Käufe über eigene Wege außerhalb der Stores angeboten würden.
3951. [P3] Halte fest, dass Spieler bei Einstellung des Spiels mindestens 3 Monate vorher informiert werden und was mit gekauften Inhalten passiert.
3952. [P3] Prüfe, ob in Ländern außerhalb der EU (USA, Großbritannien) andere Regeln für Kinder gelten (z. B. COPPA, Age Appropriate Design Code), bevor das Spiel dort angeboten wird.

### Markenrecht, IP-Prüfung und Lizenzen
3953. [P1] Lass Ali vor der Produktion die Namensprüfung "chimora" im EU-Markenregister (tmdn.org) und in der WIPO-Datenbank für die Klassen 9 und 41 machen und halte das Ergebnis mit Datum in `docs/legal/MARKE.md` fest.
3954. [P1] Melde die Wortmarke "Chimora" für die Klassen 9 und 41 an (DPMA 290 Euro oder EUIPO 850 Euro) und trage Aktenzeichen und Datum in `docs/legal/MARKE.md` ein.
3955. [x] [P1] Erweitere `tools/ip_check.sh` so, dass auch Commit-Nachrichten und Pull-Request-Titel geprüft werden, weil `AGENTS.md` das verlangt.
3956. [x] [P1] Prüfe mit `tools/ip_check.sh` auch die Metadaten von Bild- und Audiodateien (PNG-Textfelder, OGG-Kommentare) auf verbotene Namen.
3957. [P2] Sichere die Domains `chimora.de` und eine `.com`- oder `.game`-Variante sowie die Namen auf den wichtigsten Social-Media-Plattformen.
3958. [P2] Ergänze in `docs/ASSET_LOG.md` für jede Datei eine SHA-256-Prüfsumme und lass `tools/ip_check.sh` scheitern, wenn eine Datei sich ohne neuen Logeintrag ändert.
3959. [P2] Prüfe alle Schriftarten auf ihre Lizenz und lege die Lizenztexte auf der Seite `/lizenzen` ab.
3960. [P2] Prüfe, ob die Lizenzseite `/lizenzen` alle Drittbibliotheken aus `Engine.get_license_info()` der aktuellen Godot-Version enthält, mit einem Abgleich in CI.
3961. [P2] Lege eine Marken-Überwachung fest: alle 3 Monate eine Suche nach neuen Anmeldungen ähnlich "Chimora" in den Klassen 9 und 41.
3962. [P2] Prüfe alle 21 Spirling-Namen und die Ortsnamen gegen das Markenregister auf eingetragene Marken in Klasse 9 und 41 und halte Treffer fest.
3963. [P2] Lege eine Regel fest, dass jede neue Spirling-, Orts- oder Technik-Bezeichnung vor dem Merge einmal im Markenregister gesucht wird.
3964. [P2] Ergänze `tools/ip_check.sh` um eine Liste typischer Werbeformulierungen mit Vergleichen zu fremden Spielen für `store/`.
3965. [P2] Prüfe die Store-Screenshots und die Feature-Grafik einmal mit dem Auge auf Anlehnungen an fremde Kampfbildschirme, bevor sie hochgeladen werden.
3966. [P2] Lege fest, wer die Rechte an allen Assets hält, und halte bei Beiträgen anderer eine kurze schriftliche Rechteübertragung in `docs/legal/` fest.
3967. [P3] Bereite ein Skript `tools/rename_brand.py` vor, das den Spielnamen in Store-Texten, Webseiten, Spieltexten und Presets auf Plan B "Spirlings of Veydal" umstellt, falls ein Markenkonflikt kommt.
3968. [P3] Prüfe, ob ein Logo als Bildmarke angemeldet werden soll, sobald das Logo fest ist.
3969. [P3] Lege einen Ablauf fest, was bei einer Abmahnung zu tun ist (nichts unterschreiben, Frist notieren, Anwalt fragen), als Kurzfassung in `docs/legal/MARKE.md`.
3970. [P3] Lies das Urteil im Palworld-Verfahren nach Veröffentlichung und prüfe die Patent-Regeln in `LEGAL.md` und `tools/ip_check.sh` darauf, ob neue Mechaniken betroffen sind.
3971. [P3] Prüfe einmal pro Jahr, ob neue Patente im Bereich Kreaturen-Spiele veröffentlicht wurden, und halte die Suche mit Datum fest.
3972. [P3] Lege eine Lizenz für das Repository fest (öffentlich, aber alle Rechte vorbehalten) und schreibe sie in eine `LICENSE`-Datei, damit niemand Assets frei nutzt.
3973. [P3] Prüfe, ob Fan-Inhalte (Fan-Art, Videos) erlaubt werden sollen, und halte eine einfache Richtlinie auf der Support-Seite fest.
3974. [P3] Melde den Namen "Chimora" in weiteren Ländern (USA, Großbritannien) erst an, wenn das Spiel dort messbar gespielt wird.

### Code-Qualität und Wartbarkeit
3975. [P1] Prüfe mit einer Regel in CI, dass alle Variablen, Parameter und Rückgabewerte in `scripts/` statisch typisiert sind, wie `AGENTS.md` es verlangt.
3976. [x] [P1] Lege fest, dass jeder Pull Request höchstens ein Thema hat, Tests mitbringt und die Prüfungen auf `main` besteht, und schreibe das als Vorlage in `.github/pull_request_template.md`.
3977. [P1] Schreibe für `Online.gd` (435 Zeilen) eine Zustandsübersicht als Kommentar und teile Herzschlag, Wiederverbinden und Speichern in eigene Klassen auf.
3978. [P1] Halte die Regeln aus `LocalBackend.gd` und den SQL-Funktionen an einer gemeinsamen Stelle fest (Grenzwerte in `server_config`), damit sie nicht auseinanderlaufen.
3979. [P2] Lege eine Höchstlänge von 400 Zeilen pro Skript fest und teile längere Skripte nach Aufgaben auf, beginnend mit dem längsten.
3980. [P2] Ersetze magische Zahlen in `scripts/` durch benannte Konstanten an einer Stelle, beginnend mit Zeiten und Grenzwerten.
3981. [P2] Gib jeder öffentlichen Funktion in `scripts/core/` und `scripts/online/` einen kurzen `##`-Kommentar, der sagt, was sie tut.
3982. [P2] Entferne nicht genutzte Funktionen, Signale und Variablen mit einer Suche über alle Skripte und Szenen.
3983. [P2] Ersetze Aufrufe von Knoten über lange Pfade (`get_node("../../...")`) durch Signale oder exportierte Verweise.
3984. [P2] Lege fest, dass Autoloads nur über klar benannte öffentliche Funktionen angesprochen werden, und prüfe das in einer Durchsicht.
3985. [P2] Trenne Spieltexte vollständig vom Code, sodass `tools/i18n_extract.py --check` keine fest eingebauten Spielertexte mehr findet.
3986. [P2] Schreibe eine Architekturübersicht `docs/ARCHITEKTUR.md` mit allen Autoloads, ihrem Zweck und ihren Abhängigkeiten als Tabelle.
3987. [P3] Lege einen festen Stil für Signale fest (Vergangenheitsform, z. B. `save_failed`) und benenne abweichende Signale um.
3988. [P2] Prüfe alle `await`-Aufrufe darauf, dass das Objekt nach dem Warten noch existiert (`is_instance_valid`), um Fehler nach Szenenwechseln zu vermeiden.
3989. [P2] Entferne doppelte Hilfsfunktionen (z. B. für Zeit, Formatierung, Zufall) und lege sie in eine gemeinsame Datei.
3990. [P2] Halte bei jeder Abweichung von `AGENTS.md` die Begründung im Code oder in der Doku fest, damit spätere Threads sie verstehen.
3991. [P2] Lege eine Liste der technischen Schulden in `docs/TECH_SCHULDEN.md` an, mit Aufwand und Nutzen pro Eintrag, und arbeite jeden Monat zwei ab.
3992. [P3] Lass `gdformat` einmal über alle Skripte laufen und committe die Formatierung allein, ohne andere Änderungen.
3993. [P3] Prüfe, ob Godot-Warnungen als Fehler (`debug/gdscript/warnings/treat_warnings_as_errors`) für neue Dateien eingeschaltet werden können.
3994. [P3] Schreibe Beispiel-Tests als Vorlage in `tests/helpers/`, damit neue Tests einheitlich aufgebaut sind.
3995. [P3] Prüfe die Zyklen zwischen Skripten (A lädt B, B lädt A) mit einem kleinen Skript und löse sie auf.
3996. [P3] Lege fest, dass jede Datenänderung in `data/*.json` durch `tools/validate_data.gd` läuft und die Validierung neue Felder kennt.
3997. [P3] Halte die README kurz und aktuell (Start, Tests, Build, wichtigste Dokus) und prüfe sie bei jeder Version.
3998. [P3] Gib jedem Ordner unter `scripts/` eine kurze Beschreibung in `docs/ARCHITEKTUR.md`, was dort hineingehört und was nicht.
3999. [P3] Prüfe einmal pro Quartal mit `/code-review` oder einer manuellen Durchsicht die 5 meistgeänderten Dateien auf Lesbarkeit.
4000. [P3] Lege fest, dass Debug-Hilfen (versteckte Menüs, Testszenen) nur in Debug-Builds geladen werden, und prüfe das mit `OS.is_debug_build()` an einer zentralen Stelle.
