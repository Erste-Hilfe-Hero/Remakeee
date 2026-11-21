# Nur mit Tippen spielbar (Plan-Punkt 2109)

Alles außerhalb des Kampfes muss ohne Steuerkreuz und ohne Tastatur gehen. Diese Liste nennt
jede Funktion und wie ein Tipp sie erreicht. Der Test `tests/unit/test_ux_tap_only.gd` prüft
die Karten-Teile auf allen Karten.

| Funktion | Wie mit Tippen |
| --- | --- |
| Laufen | Auf ein Feld tippen, der Weg wird gesucht (lange Wege rennen) |
| Mit Personen reden | Auf die Person tippen: hinlaufen, hinschauen, reden |
| Über die Theke reden | Auf die Theke tippen |
| Schilder lesen | Auf das Schild tippen |
| Versteckte Funde | Auf das Feld des Fundes tippen |
| Glatter Fels (Geheimgang) | Auf den Fels tippen |
| Strickleiter, Planken | Auf Leiter-Kante oder Lücke tippen |
| Ausrüstung (Seil, Wasser, Kante) | Auf das Ziel tippen: zum richtigen Startfeld laufen und benutzen |
| Felsbrocken schieben | Neben dem Brocken auf ihn tippen schiebt ihn, von weiter weg läuft man hin |
| Text weiter | Irgendwo tippen |
| Antworten wählen | Auf die Antwort tippen |
| Menü öffnen | Menü-Taste "=" des Pads (die einzige Pad-Taste, die man braucht) |
| Alle Menüs und Listen | Auf eine Zeile tippen, "Zurück" unten in jeder Liste |
| Namen eingeben | Buchstaben der Bildschirmtastatur antippen |
| Einstellungen, Sprache, Speichern | Über das Menü, alles Zeilen zum Antippen |

Von Hand prüfen vor jedem Store-Build: ein neues Spiel bis zum ersten Kampf nur mit Tippen
spielen. Vom Pad nur die Menü-Taste benutzen, Steuerkreuz, A und B nicht anfassen.
