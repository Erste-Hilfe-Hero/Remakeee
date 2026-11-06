# Bereich 7: Online, Mehrspieler und Gemeinschaft

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 2669 bis 3112.

> **Auftrag für den umsetzenden Thread:** Ziel ist ein faires, sicheres und belastbares Zusammenspiel: Duelle und Ligen
> (eine Gleichstand-Liga mit Ausgleich und eine Offene Liga, weil der Shop Kaufvorteile bringt), Tausch unter Freunden,
> Bünde, gemeinsame Raid-Risse, Moderation nach DSA, Server-Prüfung gegen Schummeln, Skalierung und Datenschutz.
> Betroffen sind `supabase/migrations/` (neue Dateien ab `20261110000001_*.sql`), `tools/online/sql_test/`,
> `scripts/online/` (Online.gd, LocalBackend.gd, SupabaseBackend.gd, neue Dateien), `scripts/ui/FriendsMenu.gd` und neue
> Online-Menüs, `server/` (neuer Dienst `server/referee/`), `server/site/` und `docs/ONLINE.md` sowie `docs/legal/`.
> Fang mit dem Abschnitt "Grundlagen nachziehen" und dem Kampf-Schiedsrichter an, weil Ligen, Raids und Tausch darauf
> aufbauen. Nicht in diesen Bereich gehören Shop, Preise und Käufe (Bereich 10), CI-Workflows, Deploy und Monitoring
> (Bereich 9) sowie Kampfregeln selbst (Zugzeit, Ruhe-Regel, Seeds im Log stehen schon im Kampfplan).

### Grundlagen nachziehen
2669. [x] [P1] `_save_ok` in einer neuen Migration auf die echten Spielregeln setzen: höchstens 5 Spirlings im Team (heute 6) und Ring 1 bis 60 (heute 100), mit SQL-Test in `tools/online/sql_test/test_rules.sql`.
2670. [x] [P1] Dieselben Grenzen (Team 5, Ring 60) in `LocalBackend.gd` prüfen, damit Tests und Server gleich ablehnen.
2671. [x] [P1] Die Echo-Duell-Angleichung von heute Ring 30 auf einen Wert aus `server_config.duel_ring` umstellen (Startwert 50), damit Ali ihn ohne App-Update ändern kann.
2672. [x] [P1] In allen Online-Menüs und Server-Texten "Tamer" durch "Wanderer" ersetzen (Karte, Standardname "Wanderer 1A2B", `_clean_name`, Phrases.gd), samt Migration für bestehende Standardnamen.
2673. [x] [P1] Ein Feld `schema` (ganze Zahl, Start 1) in jeden Online-Spielstand schreiben und in `save_put` ablehnen, wenn es fehlt oder höher als `server_config.save_schema_max` ist.
2674. [x] [P1] Neue Tabelle `feature_flags` (Schlüssel, an/aus, Mindestversion) anlegen, damit Ligen, Tausch, Bünde und Raids einzeln am Server ein- und ausschaltbar sind.
2675. [P2] `hello` gibt die Liste der aktiven `feature_flags` zurück, und `Online.gd` blendet Menüpunkte ohne Flag aus statt Fehler zu zeigen.
2676. [P2] Fehlercodes aller neuen Funktionen als feste Wörter (`not_friends`, `limit_day`, `blocked`, `season_closed` usw.) festlegen und in `scripts/online/OnlineErrors.gd` in Spielertexte übersetzen.
2677. [P2] Jede neue Server-Funktion bekommt in `docs/ONLINE.md` eine Zeile in einer Tabelle "Funktion, Grenzen, Test", damit der Stand nachprüfbar bleibt.
2678. [P2] `server_config` um einen Schlüssel `rules_version` ergänzen, den der Client beim Start anzeigt und bei Duellen mitschickt, damit alle mit denselben Regeln spielen.
2679. [P2] Den Herzschlag aus `Online.gd` (45 s) auf Werte aus `server_config.heartbeat_seconds` umstellen, mit 45 im Menü und 90 im Kampf.
2680. [P2] Die Schnittstelle `OnlineBackend.gd` um ein Signal `server_event(kind, data)` erweitern, damit neue Live-Funktionen (Duell, Tausch, Raid) einheitlich Nachrichten bekommen.
2681. [P3] Eine Server-Funktion `rules_text` liefert die Online-Regeln in der Sprache des Spielers, damit Änderungen ohne App-Update im Menü "Regeln" stehen.
2682. [P3] Die alte Ring-30-Duellregel nach einer Übergangszeit von 2 Wochen per Migration aus `server_config` entfernen und das im Änderungsprotokoll der Datei vermerken.

2683. [P2] Alle neuen Server-Funktionen bekommen ein Zeitlimit (`statement_timeout` 3 Sekunden), damit eine hängende Abfrage nicht alles blockiert.
2684. [P3] Ein Online-Menü nur im Debug-Build (`scripts/ui/OnlineDebugMenu.gd`) zeigt aktive Flags, Regelversion, Ping und die letzten 20 Fehlercodes.
2685. [P3] Jede Änderung an `server_config` wird mit Zeit, altem und neuem Wert in `config_history` geschrieben, damit Ali sie zurückdrehen kann.
2686. [P3] Eine Funktion `config_preview` zeigt Ali vor einer Änderung von `min_version` oder Limits, wie viele Konten in den letzten 7 Tagen betroffen gewesen wären.
### Kampf-Schiedsrichter auf dem Server
2687. [x] [P1] Einen neuen Dienst `server/referee/` bauen: ein Godot-4.7.2-Headless-Export, der nur `scripts/battle/` lädt und Kämpfe aus Seed, Teams und Zugliste nachrechnet.
2688. [x] [P1] Der Schiedsrichter bekommt einen eigenen Container in `server/docker-compose.yml` ohne öffentlichen Port, erreichbar nur aus dem internen Netz für die Datenbank-Funktionen.
2689. [x] [P1] Eine Datenbank-Funktion `_referee_check(battle_id)` legt Kampfdaten in die Tabelle `battle_queue`, und der Schiedsrichter schreibt das Ergebnis (`ok`, `mismatch`, `error`) in `battle_results`.
2690. [x] [P1] Der Schiedsrichter vergleicht Sieger, Restkraft jedes Spirlings und Anzahl der Runden und meldet `mismatch`, sobald ein Wert abweicht.
2691. [P1] Ligapunkte, Raid-Schaden und Wochenwertungen zählen erst, wenn der Schiedsrichter `ok` gemeldet hat; bis dahin zeigt das Spiel "wird geprüft".
2692. [P2] Der Schiedsrichter läuft mit derselben Spieldaten-Version wie der Client; `data/*.json` werden beim Bau in den Container kopiert und ihr Prüfwert (SHA-256) im Ergebnis mitgeschrieben.
2693. [P2] Kommt ein Client mit anderem Daten-Prüfwert als der Server, lehnt `hello` Liga und Raid ab und verweist auf das Update.
2694. [P2] Ein Prüfschritt dauert höchstens 2 Sekunden; längere Kämpfe bricht der Schiedsrichter ab und markiert sie zur Handprüfung.
2695. [P2] Der Schiedsrichter verarbeitet bis zu 4 Kämpfe parallel (ein Arbeiter je CPU-Kern), die Zahl steht in `server_config.referee_workers`.
2696. [P2] Eine Stichprobe von 5 Prozent aller normalen Kämpfe (Wildkämpfe, Risse) wird ebenfalls nachgerechnet, um Schummel-Builds zu finden, ohne Belohnungen zu blockieren.
2697. [P2] Ein Test `tools/online/referee_test.sh` spielt 50 gespeicherte Kampfaufnahmen ab und erwartet überall `ok`.
2698. [P2] Zu jeder `mismatch`-Meldung speichert der Server die Kampfaufnahme 30 Tage in `battle_evidence` für die Prüfung durch Ali, danach wird sie gelöscht.
2699. [P2] Fällt der Schiedsrichter aus, stauen sich Kämpfe in `battle_queue`; nach 24 Stunden ohne Prüfung zählen Freundesduelle trotzdem, Ligakämpfe nicht.
2700. [P3] Den Schiedsrichter so bauen, dass er auch Live-Kämpfe Zug für Zug rechnet und so zur führenden Instanz für Live-Duelle wird (siehe Abschnitt Live-Duelle).
2701. [P3] Ein Werkzeug `tools/online/referee_diff.gd` zeigt bei `mismatch` Runde für Runde, wo Client und Server auseinanderlaufen.
2702. [P3] Die Ergebnisse des Schiedsrichters als Wochenzahl in `docs/ONLINE.md` beschreiben: wie viele Kämpfe geprüft, wie viele abgewiesen.

2703. [x] [P1] Der Schiedsrichter nutzt einen eigenen Datenbank-Nutzer, der nur `battle_queue` lesen und `battle_results` schreiben darf.
2704. [P2] Jedes Ergebnis trägt die Versionsnummer der Kampfregeln (`BattleRules.VERSION`), damit Kämpfe nach einem Update mit der passenden Regelversion geprüft werden.
2705. [P3] Für eine Übergangswoche nach Regeländerungen laufen zwei Schiedsrichter-Versionen parallel, und jeder Kampf geht an die Version seiner Regelnummer.
2706. [P3] Der Schiedsrichter rechnet Raid-Versuche mit Phasenwechsel und meldet die Phase, in der der Versuch endete.
2707. [P3] Ein Zähler "heute geprüfte Kämpfe" erscheint auf der Status-Seite im Spiel.
### Live-Duelle unter Freunden
2708. [P1] Live-Duelle laufen nur zwischen bestätigten Freunden und Bundmitgliedern, nie mit Fremden, und starten über "Herausfordern" auf der Wanderer-Karte.
2709. [P1] Ein Live-Duell ist rundenbasiert auf dem eigenen Kampfbildschirm: beide wählen verdeckt, der Server sammelt beide Wahlen und rechnet die Runde.
2710. [P1] Die Einladung gilt 60 Sekunden; nimmt der Freund nicht an, wird automatisch ein Echo-Duell angeboten.
2711. [P2] Die Verbindung läuft über WebSocket (`wss://.../duel`) zu einem kleinen Duell-Dienst in `server/duel/`, der nur Wahlen weiterreicht und vom Schiedsrichter rechnen lässt.
2712. [P2] Jede Wahl wird mit Rundennummer und Spieler-Kennung geschickt; doppelte oder verspätete Wahlen für eine alte Runde lehnt der Dienst ab.
2713. [P2] Bricht die Verbindung ab, hält der Dienst das Duell 90 Sekunden offen; danach wählt die bestehende KI aus `BattleAI.gd` für den Fehlenden.
2714. [P2] Gibt jemand mitten im Duell auf, zählt es als Niederlage, aber ohne Verlust von Geld, Wachstum oder Gegenständen.
2715. [P2] Vor dem Duell wählen beide aus ihren 5 Team-Spirlings verdeckt 3 aus; die Auswahl zeigt beide Teams 20 Sekunden lang.
2716. [P2] Der Duell-Dienst schickt nur das, was der Spieler sehen darf: eigene Kraftwerte genau, gegnerische als Balken in Achteln.
2717. [P2] Nach dem Duell landet ein Ergebnis-Eintrag in der Post beider ("Mara und du: 2 zu 1 gewonnen"), mit Knopf "Revanche".
2718. [P2] Ein Freund kann Live-Duelle in den Einstellungen abschalten; dann erscheint bei ihm nur "Echo-Duell".
2719. [P2] Höchstens 30 Live-Duelle pro Tag und Spieler, eingestellt über `server_config.duel_day_limit`.
2720. [P3] Freunde können ein laufendes Live-Duell ansehen, mit 1 Runde Verzögerung, ohne eingreifen zu können.
2721. [P3] Duell-Räume für den eigenen Bund: der Leiter öffnet eine Runde, Mitglieder treten paarweise an, Ergebnis als Tabelle.
2722. [P3] Ein "Übungsduell" gegen das eigene Echo testet den Duell-Ablauf ohne zweiten Spieler.
2723. [P3] Die Revanche nutzt dieselben Teams und tauscht die Startseite, damit beide einmal zuerst wählen.

2724. [P1] Ein Live-Duell startet nur, wenn beide dieselbe `rules_version` und denselben Daten-Prüfwert haben; sonst bietet das Spiel das Update an.
2725. [P2] Eine Ping-Anzeige im Duell (grün unter 150 ms, gelb bis 400 ms, rot darüber) hilft, Verzögerungen einzuordnen.
2726. [P2] Eine Duell-Einladung, die während eines Kampfs oder des Echo-Melodie-Minispiels kommt, wird bis zum Ende zurückgehalten und dann gezeigt.
2727. [P3] Beim Einladen wählt man die Regel "Ausgleich auf Ring 50" (Standard) oder "Eigene Werte", und die Einladung zeigt die Wahl.
2728. [P3] Eine Duellbilanz pro Freund steht auf seiner Wanderer-Karte ("Gegen Mara: 7 zu 5").
2729. [P3] Zwei Spieler im selben Raum können ein Duell per QR-Code auf dem Bildschirm starten, ohne den Freundescode zu tippen.
### Gleichstand-Liga (fair, mit Ausgleich)
2730. [P1] Die Gleichstand-Liga ist die Standardliga und wird im Menü "Ligen" zuerst gezeigt, mit dem Satz "Hier zählt nur dein Können. Gekaufte Vorteile wirken hier nicht."
2731. [P1] In der Gleichstand-Liga kämpfen alle Spirlings auf Ring 50 mit Grundwerten aus `data/spirlings.json`; Wachstum, Trainingsboni und gekaufte Werte werden für den Kampf auf null gesetzt.
2732. [P1] Gegenstände und Andenken mit Herkunftsmarke aus dem Shop sind in der Gleichstand-Liga gesperrt; die Liste der gesperrten Herkunftsmarken steht in `server_config.league_fair_blocked_sources`, die Bereich 10 befüllt.
2733. [P1] Erlaubt sind nur Techniken, die der Spirling bis Ring 50 laut Spieldaten lernen kann; der Server prüft jede Technik gegen diese Liste.
2734. [P1] Der Server baut das Ligateam selbst aus dem gespeicherten Team neu auf (Funktion `_league_team_fair`), der Client schickt nur Spirling-Kennungen und Technikwahl.
2735. [P1] Ein SQL-Test prüft, dass zwei Konten mit gleichem Spirling, aber verschiedenem Kaufstand, in der Gleichstand-Liga exakt dieselben Kampfwerte bekommen.
2736. [P2] Pro Spirling-Art darf ein Ligateam nur ein Exemplar haben, damit nicht dieselbe starke Art dreifach antritt.
2737. [P2] Andenken aus dem normalen Spiel sind erlaubt, aber jedes nur einmal pro Team.
2738. [P2] Belohnungen der Gleichstand-Liga sind Ansehen-Abzeichen, Kartenrahmen und Titel, sichtbar auf der Wanderer-Karte.
2739. [P2] Ein Hinweis-Symbol (Waage) an jedem Ligakampf zeigt, dass der Ausgleich aktiv ist; ein Tipp darauf erklärt die Regeln in drei Sätzen.
2740. [P2] In der Teamauswahl der Gleichstand-Liga zeigt das Spiel die angeglichenen Werte, nicht die eigenen, damit niemand überrascht wird.
2741. [P2] Spieler unter 16 Jahren sehen standardmäßig nur die Gleichstand-Liga; die Offene Liga ist für sie erst nach dem Eltern-Schalter sichtbar.
2742. [P2] Ein Ligakampf läuft asynchron gegen das Ligateam eines gleich starken Gegners (KI steuert) oder live, wenn beide gleichzeitig suchen.
2743. [P2] Pro Tag gibt es 10 gewertete Ligakämpfe; weitere Kämpfe sind möglich, zählen aber nicht.
2744. [P2] Ligateams werden zu Beginn einer Saison eingefroren und können nur einmal pro Woche geändert werden, damit Gegner-Echos stabil bleiben.
2745. [P3] Monatliche Sonderregel-Wochen in der Gleichstand-Liga (zum Beispiel "nur zwei Elemente", "Ring 30") aus `server_config.league_fair_rotation`.
2746. [P3] Eine Leih-Team-Woche pro Saison: alle bekommen dieselben drei Teams vom Server und wählen eins.
2747. [P3] Eine Statistik "Meistgewählte Spirlings der Saison" in der Gleichstand-Liga, ohne Spielernamen.

2748. [P1] Die Angleichung rechnet der Schiedsrichter mit derselben Funktion wie die Datenbank, und ein Test vergleicht beide Ergebnisse für alle 21 Spirlings.
2749. [P2] Spirlings, die nach dem Start neu ins Spiel kommen, sind in der ersten Woche nach Erscheinen in der Gleichstand-Liga gesperrt, damit alle gleich starten.
2750. [P3] Eine Proberunde gegen ein Server-Team zählt nicht und zeigt die Regeln der Gleichstand-Liga im Kampf.
2751. [P3] Ein Saison-Rückblick zeigt die eigenen Siege nach Element des Gegners.
2752. [P3] Eine Ehrenhalle mit den Leuchtfeuer-Spielern jeder Saison, nur mit ihrer Zustimmung.
### Offene Liga (alles erlaubt)
2753. [P1] Die Offene Liga steht im Menü direkt unter der Gleichstand-Liga, klar beschriftet mit "Offene Liga: alle Vorteile erlaubt, auch gekaufte".
2754. [P1] In der Offenen Liga kämpft jeder mit seinem echten Team und echtem Ring (bis 60), mit allen Gegenständen, auch aus dem Shop.
2755. [P1] Wertung, Gegnersuche und Belohnungen der beiden Ligen sind komplett getrennt (eigene Tabellen `league_open_*`), damit Kaufvorteile die Gleichstand-Liga nicht berühren.
2756. [P2] Die Gegnersuche der Offenen Liga berücksichtigt zusätzlich die Teamstärke (Summe aus Ring und Werten), damit ein Neuling nicht auf ein voll ausgebautes Team trifft.
2757. [P2] Vor dem ersten Kampf zeigt das Spiel einmal einen Hinweis: "Hier treffen manche auf gekaufte Vorteile. In der Gleichstand-Liga zählt nur Können."
2758. [P2] Die Offene Liga hat eigene Ranglisten und einen eigenen Titel, der auf der Karte mit dem Zusatz "Offen" erscheint.
2759. [P2] Die Schutzgrenze "Teamstärke-Abstand höchstens 15 Prozent" gilt für die ersten 20 Kämpfe eines Spielers in der Offenen Liga, danach 30 Prozent.
2760. [P2] Auch in der Offenen Liga gilt der Schiedsrichter: jeder gewertete Kampf wird nachgerechnet.
2761. [P2] Ein Wochenbericht im Ligamenü zeigt, wie viele Kämpfe Kaufvorteile enthielten, als einfache Prozentzahl.
2762. [P3] Eine Spielerwahl "Mich nicht gegen Kaufvorteile antreten lassen" wechselt automatisch in die Gleichstand-Liga.
2763. [P3] Saisonabschluss der Offenen Liga mit eigenem Kartenrahmen, der sich optisch vom Rahmen der Gleichstand-Liga unterscheidet.

2764. [P2] Gewinnt in der Offenen Liga das schwächere Team, bekommt es 50 Prozent mehr Wertungspunkte (Außenseiterbonus).
2765. [P2] Belohnungen der Offenen Liga tragen die Herkunftsmarke `liga_offen` und sind in der Gleichstand-Liga gesperrt.
2766. [P3] Eine Schlusswoche "Ring 60 ohne Grenzen" am Ende jeder Saison der Offenen Liga.
2767. [P3] Nach jedem Kampf zeigt ein Knopf "Gegnerteam ansehen" Ring, Techniken und Andenken des Gegners.
2768. [P3] Eine SQL-Abfrage in `docs/ONLINE.md` zeigt Ali pro Woche, wie oft Teams mit und ohne Kaufvorteile gewinnen.
### Saisons, Wertung und Gegnersuche
2769. [P1] Eine Saison dauert 6 Wochen, Start und Ende nach Server-Zeit, gespeichert in Tabelle `league_seasons` (Kennung, Start, Ende, Regelversion).
2770. [P1] Die Wertung nutzt Glicko-2 mit Startwert 1500 und Abweichung 350, berechnet in der Datenbank-Funktion `_league_rate` nach jedem geprüften Kampf.
2771. [P1] Sichtbar sind nur Stufen statt Zahlen: Funke, Glut, Flamme, Leuchte und Leuchtfeuer, jede in 3 Teilstufen.
2772. [P1] Die Gegnersuche sucht zuerst im Bereich plus minus 100 Wertungspunkte und erweitert alle 10 Sekunden um 50, höchstens auf 400.
2773. [P2] Kein Abstieg durch Pause: wer eine Woche nicht spielt, verliert keine Stufe, nur die Abweichung wächst.
2774. [P2] Am Saisonende wird jede Wertung zur Hälfte auf 1500 zurückgesetzt (neu = 1500 + (alt minus 1500) geteilt durch 2).
2775. [P2] Die ersten 5 Kämpfe einer Saison sind Einstufungskämpfe und zeigen noch keine Stufe.
2776. [P2] Gegen denselben Gegner zählen höchstens 3 Kämpfe pro Tag, um abgesprochene Siege zwischen Freunden zu bremsen.
2777. [P2] Asynchrone Gegner sind die eingefrorenen Ligateams anderer Spieler; deren Besitzer bekommen 1 Punkt "Echo-Ehre", wenn ihr Team gewinnt.
2778. [P2] Am Saisonende vergibt der Server die Belohnungen per Funktion `league_close(season)` einmal und schreibt jeden Empfang in `league_rewards` (doppelte Vergabe unmöglich).
2779. [P2] Die Weltrangliste zeigt die besten 100 nur mit Stufe und Spirling-Symbol, Namen nur, wenn der Spieler in den Einstellungen zustimmt.
2780. [P2] Eine Freundes-Rangliste pro Liga zeigt eigene Freunde mit Namen und Stufe.
2781. [P2] Ligastände werden pro Saison archiviert und auf der Wanderer-Karte als "Beste Stufe Saison 1" angezeigt.
2782. [P3] Regionale Gegnersuche: zuerst Spieler mit derselben Sprache, nach 20 Sekunden alle.
2783. [P3] Eine Saisonchronik im Ligamenü mit Datum, eigener Stufe und den drei meistgenutzten Spirlings.
2784. [P3] Eine Vorschau "Nächste Saison" zeigt Sonderregel und Startdatum 7 Tage vorher.
2785. [P3] Bei weniger als 2 suchenden Spielern in 60 Sekunden bietet die Gegnersuche sofort ein asynchrones Ligateam an.

2786. [P1] `league_seasons` kennt die Zustände "läuft", "Abschluss" und "Pause"; im Abschluss (die letzten 30 Minuten) wird kein Kampf mehr gewertet.
2787. [P2] Die Gegnersuche zeigt die erwartete Wartezeit ("ungefähr 20 Sekunden"), berechnet aus den letzten 50 Treffern.
2788. [P3] Am Ende jeder Woche kommt ein Zwischenstand in die Post ("Du bist in Glut II, 12 Siege").
2789. [P3] Eine Vorsaison von 1 Woche vor dem Store-Start zum Testen, deren Wertung danach gelöscht wird.
2790. [P3] Die Grenzen der Gegnersuche (100, 50, 400) stehen als Schlüssel in `server_config`, damit Ali sie bei wenigen Spielern lockern kann.
### Tausch zwischen Freunden
2791. [P1] Tauschen geht nur zwischen bestätigten Freunden ab Freundschaftsstufe 3, die seit mindestens 7 Tagen befreundet sind.
2792. [P1] Tauschbar sind nur Gegenstände mit `tradeable: true` in `data/items.json`; Spirlings werden nie getauscht (bestehende Grundregel bleibt).
2793. [P1] Gegenstände mit Shop-Herkunftsmarke sind nicht tauschbar, damit kein grauer Handel und kein Betrug mit Rückbuchungen entsteht.
2794. [P1] Der Tausch läuft über eine Treuhand-Tabelle `trades`: beide legen ein, beide bestätigen, dann tauscht der Server in einer Transaktion oder gar nicht.
2795. [P1] Ändert eine Seite ihr Angebot, wird die Bestätigung beider Seiten automatisch zurückgesetzt.
2796. [P2] Der Server zieht eingelegte Gegenstände aus dem Server-Spielstand ab und schreibt sie dem anderen gut; der Client darf das Ergebnis nicht selbst setzen.
2797. [P2] Ein Tausch umfasst höchstens 5 verschiedene Gegenstände und 20 Stück je Seite.
2798. [P2] Pro Tag sind 5 abgeschlossene Tausche pro Spieler erlaubt, eingestellt über `server_config.trade_day_limit`.
2799. [P2] Die Wertsumme (nach `price` in `data/items.json`) darf pro Woche und Freundespaar 3000 Münzen nicht übersteigen, gegen das Schieben auf Hauptkonten.
2800. [P2] Ist der Wertunterschied eines Tauschs größer als das Vierfache, zeigt das Spiel eine Warnung "Sehr ungleicher Tausch" und verlangt einen zweiten Tipp.
2801. [P2] Die Bestätigung erfolgt mit 2 Sekunden Gedrückthalten, damit niemand aus Versehen tauscht.
2802. [P2] Ein offener Tausch verfällt nach 10 Minuten ohne Aktivität, die Gegenstände gehen automatisch zurück.
2803. [P2] Asynchroner Tausch: ein Angebot kann 48 Stunden in der Post liegen und wird mit dem Öffnen angenommen oder abgelehnt.
2804. [P2] Ein Tausch-Verlauf zeigt die letzten 50 Tausche mit Datum und Inhalt, gespeichert 90 Tage.
2805. [P2] Der Eltern-Schalter bekommt einen eigenen Punkt "Tauschen" und ist für Konten unter 16 standardmäßig aus.
2806. [P2] Ein Block beendet offene Tausche sofort und gibt alle eingelegten Gegenstände zurück.
2807. [P2] `LocalBackend.gd` bildet Treuhand, Limits und Rückgabe nach, und `tools/online/sql_test/test_trade.sql` prüft gleichzeitige Bestätigungen.
2808. [P3] Ein Wunschzettel mit 3 Gegenständen auf der Wanderer-Karte, den Freunde im Tausch sehen.
2809. [P3] Bundmitglieder können ab 14 Tagen Mitgliedschaft untereinander tauschen, mit denselben Grenzen wie Freunde.
2810. [P3] Ein Tauschzähler auf der Wanderer-Karte ("42 faire Tausche") als kleine Auszeichnung.
2811. [P3] Ein Tauschfest-Wochenende verdoppelt das Tageslimit auf 10, gesteuert über `server_config`.

2812. [P2] Vor der Bestätigung sehen beide ihren eigenen Bestand nach dem Tausch.
2813. [P2] Wird ein Freund entfernt und innerhalb von 24 Stunden neu hinzugefügt, ist Tauschen zwischen beiden 7 Tage gesperrt.
2814. [P3] Tausch-Vorlagen: ein Angebot speichern und später mit einem Tipp erneut anbieten.
2815. [P3] Ein Tauschfenster im Pixelstil mit zwei Tischen und einer kurzen Animation beim Abschluss, aus eigener Grafik.
2816. [P3] Eine Abfrage für Ali zeigt die meistgetauschten Gegenstände pro Woche, um Mangel im Spiel zu erkennen.
### Bünde (Gilden)
2817. [P1] Neue Tabellen `bunds`, `bund_members`, `bund_invites` mit höchstens 30 Mitgliedern pro Bund und genau einem Bund pro Spieler.
2818. [P1] Bundnamen werden aus zwei Wortbausteinen gebildet (Liste in `scripts/online/BundWords.gd`, je 120 Wörter), der Server speichert nur die Nummern; so braucht es keine freie Eingabe.
2819. [P1] Beitritt nur per Einladung durch Leiter oder Helfer oder per Anfrage, die ein Leiter oder Helfer annimmt.
2820. [P1] Die Rollen Leiter, Helfer und Mitglied mit festen Rechten: nur der Leiter löst auf, Helfer laden ein und entfernen Mitglieder.
2821. [P1] Austreten ist jederzeit möglich, ohne Strafe und ohne Wartezeit.
2822. [P2] Ein Wappen aus 12 Formen, 16 Farben und 24 Zeichen, gespeichert als drei Zahlen, gezeichnet im Pixelstil des Spiels.
2823. [P2] Ein Bund-Wochenziel (Kämpfe, Bindungen oder Raid-Schaden), das alle Mitglieder füllen, mit Belohnung bei 100 Prozent für jeden, der beigetragen hat.
2824. [P2] Ist der Leiter 30 Tage nicht online, wird automatisch der Helfer mit dem höchsten Wochenbeitrag Leiter, sonst das älteste Mitglied.
2825. [P2] Eine Pinnwand mit den letzten 20 Schnellsätzen der Mitglieder, ohne freien Text.
2826. [P2] Das Wappen erscheint als kleines Abzeichen auf der Wanderer-Karte jedes Mitglieds.
2827. [P2] Eine Bund-Suche mit Filtern nach Sprache, Mitgliederzahl und "offen für Anfragen".
2828. [P2] Ein Bund-Vorrat mit 30 Plätzen, in den Mitglieder tauschbare Gegenstände legen und aus dem Mitglieder höchstens 3 pro Tag nehmen.
2829. [P2] Jede Entnahme aus dem Bund-Vorrat steht 30 Tage im Vorratsbuch (wer, was, wann).
2830. [P2] Spieler unter 16 können nur Bünden beitreten, in denen der Leiter bereits ihr Freund ist.
2831. [P2] Pro Tag höchstens 10 Einladungen und 5 Anfragen pro Spieler, über `_rate_ok`.
2832. [P2] Ein Bund-Menü in `scripts/ui/BundMenu.gd` mit Reitern Mitglieder, Ziel, Pinnwand, Vorrat und Raid.
2833. [P2] Wird ein Bund gemeldet (Wappen oder Name), blendet der Server ihn nach 3 offenen Meldungen bis zur Prüfung aus der Suche aus.
2834. [P3] Eine Bund-Chronik listet gemeinsame Erfolge (Ziele, Raids, Ligastufen) mit Datum.
2835. [P3] Bund-Echos: Mitglieder hinterlegen ihr Team, und andere Mitglieder können es als Echo-Partner wählen wie bei Freunden.
2836. [P3] Eine Bund-Rangliste nach Gemeinschaftsleistung (Wochenziele und Raid-Beiträge), nicht nach Kampfkraft.
2837. [P3] Saisonale Wappenränder als reine Zierde für Bünde, die das Wochenziel 4 Wochen in Folge erreichen.
2838. [P3] Ein Lagerfeuer-Treffpunkt: eine kleine Karte mit den Figuren der Mitglieder, die zuletzt online waren.
2839. [P3] Bund-Vergleiche: zwei Bünde messen sich eine Woche lang im Wochenziel, beide bekommen etwas.
2840. [P3] Neue Wappenteile schaltet ein Bund frei, wenn er gemeinsam 5000 Beiträge sammelt.
2841. [P3] Ein freundlicher Willkommensgruß in der Post, wenn ein neues Mitglied beitritt.

2842. [P1] Ein Bund mit 3 oder mehr Mitgliedern löst sich erst auf, wenn der Leiter nach 24 Stunden erneut bestätigt; der Vorrat geht dann zu gleichen Teilen an die Mitglieder.
2843. [P2] Wer einen Bund verlässt, kann demselben Bund 24 Stunden lang nicht wieder beitreten, anderen Bünden sofort.
2844. [P3] Bund-Ränge nach Gesamtbeitrag (Lehrling, Gefährte, Hüter) als reine Anzeige.
2845. [P3] Ein Bundabend: der Leiter legt Wochentag und Uhrzeit fest, die alle Mitglieder als Hinweis sehen.
2846. [P3] Ein Bund-Spirlog zeigt, welche Spirlings der Bund zusammen schon gesehen hat.
### Gemeinsame Raid-Risse
2847. [P1] Ein Raid-Riss ist ein starker Wächter, den 2 bis 4 Freunde oder Bundmitglieder gemeinsam schwächen; jeder kämpft rundenbasiert auf seinem eigenen Kampfbildschirm.
2848. [P1] Die Kraft des Wächters liegt auf dem Server (Tabelle `raids`, Spalte `hp_left`); jeder geprüfte Kampf zieht den Schaden ab, den der Schiedsrichter bestätigt.
2849. [P1] Ein Raid-Riss bleibt 48 Stunden offen; jedes Mitglied hat 3 Versuche pro Tag, jeder Versuch dauert höchstens 10 Runden.
2850. [P1] Die Kraft des Wächters richtet sich nach der Teilnehmerzahl: 2 Spieler 100 Prozent, 3 Spieler 140 Prozent, 4 Spieler 175 Prozent eines Grundwerts.
2851. [P1] Alle, die mindestens 5 Prozent der Wächterkraft beigetragen haben, bekommen dieselbe Belohnung, gewürfelt auf dem Server aus einer offenen Tabelle, die das Spiel zeigt.
2852. [P2] Raid-Risse haben fünf Tiefen (I bis V) statt Sternen; jede Tiefe verlangt eine Mindest-Ringzahl von 15, 25, 35, 45 und 55.
2853. [P2] Jeder Raid-Wächter hat 3 Phasen bei 100, 60 und 25 Prozent Kraft, die der Server allen Teilnehmern gleich vorgibt.
2854. [P2] Ein Raid-Bildschirm im Menü zeigt den gemeinsamen Kraftbalken, den Beitrag jedes Teilnehmers und die Restzeit.
2855. [P2] Ein Raid wird vom Leiter oder Helfer eines Bundes oder von einem Freund geöffnet; die Einladung erscheint in der Post der anderen.
2856. [P2] Pro Woche kann ein Spieler höchstens 3 Raids öffnen und an höchstens 6 teilnehmen.
2857. [P2] Für Raids gilt standardmäßig der Ausgleich der Gleichstand-Liga (Ring 50, keine Kaufvorteile); der Öffnende kann "Offener Raid" wählen, das steht dann auf der Einladung.
2858. [P2] Eine Nachricht "Mara hat 12 Prozent Schaden gemacht" geht nach jedem Versuch an alle Teilnehmer, als feste Phrase.
2859. [P2] Live-Raid für 2 Spieler: beide stehen im selben Kampf, jeder steuert seine Seite, gerechnet vom Schiedsrichter über den Duell-Dienst.
2860. [P2] Zehn Raid-Wächter als eigene neue Gestalten mit Namen aus eigener Erfindung, als Daten in `data/raids.json` (Element, Phasen, Techniken).
2861. [P2] Ein Raid-Verlauf zeigt die letzten 20 Raids mit Tiefe, Ergebnis und Teilnehmern.
2862. [P2] Raids und ihr Schadensverlauf werden 60 Tage nach Ende gelöscht.
2863. [P2] Ein SQL-Test prüft, dass zwei gleichzeitige Schadensmeldungen die Kraft korrekt in Summe abziehen und nie unter null fallen.
2864. [P2] Wer zu einem Raid eingeladen wird, aber nicht kämpft, bekommt nichts, verliert aber auch nichts.
2865. [P3] Ein Raid-Wochenende pro Monat mit einem Gemeinschafts-Wächter der Tiefe V für alle Bünde, mit getrennter Kraft je Bund.
2866. [P3] Raid-Bestzeiten pro Bund: schnellster Sieg in Stunden seit Öffnung.
2867. [P3] Rollen-Hinweise vor dem Raid: das Spiel schlägt anhand der Elemente vor, wer schützt, wer zuschlägt und wer heilt.
2868. [P3] Ein Raid-Abzeichen auf der Wanderer-Karte für den ersten Sieg jeder Tiefe.
2869. [P3] Ein Gast-Platz: ein Freund außerhalb des Bundes darf auf Einladung als vierter Teilnehmer mitmachen.
2870. [P3] Raid-Wiederholung: einen eigenen Raid-Versuch später aus der gespeicherten Aufnahme ansehen.

2871. [P1] Raid-Versuche kosten nichts: kein Geld, keine Gegenstände, und das Team ist danach geheilt wie nach einem Echo-Duell.
2872. [P2] Wer den letzten Treffer setzt, bekommt keinen Extrabonus, damit niemand auf den letzten Zug wartet.
2873. [P3] Die Raid-Wächter wechseln jede Woche nach der Liste `server_config.raid_rotation`.
2874. [P3] Raid-Wächter tragen den Grafikstil der Era der Region, in der ihr Riss liegt.
2875. [P3] Ein Raid-Rückblick nach dem Sieg zeigt, welche Techniken den meisten Schaden gemacht haben.
### Schnellsätze, Kommunikation und Kinderschutz
2876. [P1] Freier Text bleibt überall ausgeschlossen; alle neuen Funktionen (Duell, Tausch, Bund, Raid) nutzen nur Phrasen-Nummern aus `Phrases.gd`, die der Server gegen eine Liste erlaubter Nummern prüft.
2877. [P1] Der Server prüft für jeden Kontext eigene erlaubte Nummern (`phrases_allowed` je Kontext: Post, Duell, Bund, Raid), damit keine Menü-Phrase im Duell landet.
2878. [P1] Spielernamen dürfen keine Ziffernfolgen mit mehr als 3 Ziffern, keine Adressen und kein "@" enthalten, damit niemand Telefonnummern oder Konten weitergibt.
2879. [P2] Der Namensfilter normalisiert vor der Prüfung Ersatzzeichen (4 wird a, 3 wird e, 0 wird o, 1 wird i, Leerzeichen und Punkte fallen weg) und prüft dann gegen `banned_words`.
2880. [P2] Pro Sprache (Deutsch, Englisch und alle in `docs/I18N.md`) eine eigene Liste in `banned_words` mit Spalte `lang`.
2881. [P2] Für Duelle 12 eigene Phrasen ("Guter Zug!", "Knapp!", "Noch eine Runde?"), für Raids 12 ("Ich schütze!", "Phase zwei!"), für Bünde 12.
2882. [P2] Spirling-Sticker: 21 Gesichter der eigenen Spirlings als Grüße, ebenfalls als Nummern gespeichert.
2883. [P2] Pro Minute höchstens 6 Phrasen im Duell, sonst stumm für 30 Sekunden, damit niemand den anderen zuschüttet.
2884. [P2] Jeder Spieler kann im Duell und im Raid die Phrasen des Gegenübers mit einem Tipp stumm schalten.
2885. [P2] Ein Altersschritt beim ersten Start fragt nur "unter 16" oder "16 und älter" und speichert nur diese eine Angabe.
2886. [P2] Für Konten unter 16 sind Freunde, Tausch, Bund und Live-Duell zunächst aus, bis ein Eltern-Code (4 Ziffern, beim Altersschritt gesetzt) sie freigibt.
2887. [P2] Ruhezeiten von 21 bis 7 Uhr Ortszeit: keine Einladungen zu Duellen und Raids an Konten unter 16.
2888. [P3] Phrasen und Sticker werden von Screenreadern vorgelesen, mit Text aus der Übersetzungstabelle.
2889. [P3] Ein Eltern-Überblick im Menü Konto zeigt die Spielzeit der letzten 7 Tage und die Zahl der Freunde, geschützt durch den Eltern-Code.

2890. [P2] Neue Phrasen werden nur mit allen Übersetzungen freigegeben; fehlt eine Sprache, lehnt der Server die Nummer ab.
2891. [P3] Spieler wählen 8 Lieblingsphrasen für ein Schnellrad im Duell.
2892. [P3] Gefühls-Symbole (Freude, Staunen, Daumen hoch) als eigene Pixelgrafiken neben den Phrasen.
2893. [P3] Saisonale Phrasen zu Festivals, die der Server für die Festtage freischaltet.
### Melden, Blockieren und Moderation (DSA)
2894. [P1] Melden geht an jeder Stelle, an der ein anderer Spieler sichtbar ist: Freundesliste, Wanderer-Karte, Duell, Tausch, Bund, Raid und Rangliste.
2895. [P1] Die Tabelle `reports` bekommt die Spalten `context` (Ort der Meldung), `object_id` (Bund, Name, Wappen), `status` (offen, geprüft, abgelehnt) und `decided_at`.
2896. [P1] Nach jeder Entscheidung bekommt der Betroffene eine Begründung im Spiel (DSA Art. 17): Maßnahme, Grund aus fester Liste, Regel aus den Nutzungsbedingungen, Hinweis auf Widerspruch.
2897. [P1] Ein Widerspruchsknopf an dieser Begründung schickt innerhalb von 6 Monaten eine Beschwerde in `appeals`, die Ali erneut prüft und beantwortet.
2898. [P1] Der Meldende bekommt eine kurze Nachricht über das Ergebnis seiner Meldung ("geprüft, Maßnahme ergriffen" oder "kein Verstoß gefunden").
2899. [P1] Ein Meldeformular auf `server/site/melden.html` nimmt Meldungen zu rechtswidrigen Inhalten auch ohne Konto an (DSA Art. 16), mit Freundescode, Grund, Erklärung und Bestätigung guten Glaubens.
2900. [P1] Blockieren wirkt sofort auch in allen neuen Funktionen: keine Duelle, keine Tausche, keine Raid-Einladungen, kein gemeinsamer Bund-Raid, kein Treffen in der Gegnersuche.
2901. [P2] Ein Moderationswerkzeug `tools/online/mod.sh` für Ali mit Befehlen `list`, `show <id>`, `reset-name`, `hide-bund`, `suspend <tage>`, das jede Aktion mit Grund in `mod_actions` schreibt.
2902. [P2] Nach 3 Meldungen von verschiedenen Konten innerhalb von 7 Tagen blendet der Server einen Namen oder Bund vorläufig aus, bis Ali entschieden hat.
2903. [P2] Maßnahmen in Stufen: Name zurücksetzen, 7 Tage keine sozialen Funktionen, 30 Tage keine sozialen Funktionen, Konto dauerhaft aus Ligen und Raids.
2904. [P2] Wer innerhalb von 30 Tagen 5 Meldungen macht, die alle abgelehnt werden, kann 14 Tage nicht mehr melden (DSA Art. 23, Missbrauch des Meldewegs).
2905. [P2] Eine Kontaktstelle für Behörden und Nutzer (DSA Art. 11 und 12) mit E-Mail-Adresse und Sprachen in `server/site/impressum.html` und den Nutzungsbedingungen.
2906. [P2] Die Nutzungsbedingungen bekommen einen Abschnitt "Moderation" (DSA Art. 14), der die Gründe, Stufen und den Widerspruch in einfachen Sätzen beschreibt.
2907. [P2] Eine Anleitung in `docs/ONLINE.md` für den Fall einer Drohung gegen Leib und Leben: Daten sichern, Meldung an die Polizei (DSA Art. 18), Konto sperren.
2908. [P2] Die Meldegründe werden um "Bundname oder Wappen", "Ausnutzen eines Fehlers", "Schummeln im Duell" und "Druck beim Tauschen" erweitert.
2909. [P2] Gesperrte Spieler sehen beim Öffnen des Freundesmenüs ihre Sperre mit Enddatum und Grund statt einer Fehlermeldung.
2910. [P2] Moderationsdaten (Meldungen, Entscheidungen, Widersprüche) werden 12 Monate nach Abschluss gelöscht, Beweise aus `battle_evidence` nach 30 Tagen.
2911. [P2] Ein SQL-Test prüft, dass eine Sperre alle sozialen Funktionen gleichzeitig abweist und nach Ablauf von selbst endet.
2912. [P3] Ein jährlicher Moderationsbericht in `docs/legal/MODERATION_BERICHT.md` mit Zahl der Meldungen, Maßnahmen und Widersprüche, freiwillig nach dem Vorbild von DSA Art. 15.
2913. [P3] Bis zu 3 vertrauenswürdige Helfer, die Ali bestimmt, können über `mod.sh` nur Namen zurücksetzen, aber keine Sperren setzen.
2914. [P3] Eine Liste der Blockierten im Menü Konto, mit Entblocken und Datum des Blocks.
2915. [P3] Blocks werden beim Konto-Umzug per Übertragungscode mitgenommen (bestehend prüfen und als SQL-Test festhalten).

2916. [P1] Jede Meldung bekommt sofort eine Eingangsbestätigung im Spiel mit Meldenummer (DSA Art. 16 Abs. 4).
2917. [P2] Die Prüfliste sortiert Meldungen nach Schwere (Drohung zuerst, dann Name oder Wappen, dann Schummeln) und zeigt das Alter jeder Meldung.
2918. [P3] Der Server schickt Ali eine Wochen-E-Mail, wenn mehr als 10 Meldungen offen sind.
2919. [P3] Doppelte Meldungen (gleicher Meldender, gleiches Ziel, 24 Stunden) werden still verworfen und nicht gezählt.
2920. [P3] Vorlagen für Begründungstexte in allen Spielsprachen in `scripts/online/ModReasons.gd`, damit Begründungen einheitlich sind.
### Schutz vor Schummeln
2921. [P1] `save_put` vergleicht jeden neuen Stand mit dem vorherigen und lehnt ab, wenn Geld schneller als 5000 Münzen pro gespielter Minute steigt (Grenze in `server_config.max_money_per_min`).
2922. [P1] `save_put` lehnt Spirling-Arten, Techniken und Gegenstände ab, deren Kennung nicht in den Spieldaten auf dem Server steht (Tabelle `known_ids`, beim Deploy aus `data/*.json` gefüllt).
2923. [P1] Spielzeit im Stand darf nur steigen und pro Speicherung höchstens um die echte Zeit seit der letzten Speicherung plus 5 Minuten.
2924. [P1] Werte, die der Server führt (Ligawertung, Raid-Beiträge, Tauschbestand, Kaufwährung), stehen in eigenen Tabellen und werden aus dem Spielstand ignoriert, selbst wenn der Client sie mitschickt.
2925. [P1] Jeder abgelehnte Stand wird mit Grund in `cheat_flags` vermerkt; ab 3 Vermerken in 7 Tagen wird das Konto aus Ligen und Raids genommen, bis Ali es prüft.
2926. [P2] Wachstum pro Kampf darf den höchsten Wert aus den Spieldaten für den stärksten Gegner der jeweiligen Karte nicht übersteigen.
2927. [P2] Ein Spirling kann den Ring nur erhöhen, nie senken, außer über eine Spielfunktion, die der Server kennt.
2928. [P2] Die Anzahl jedes Gegenstands im Stand darf nur um das wachsen, was Kämpfe, Funde, Post, Tausch und Shop in der Zeit liefern konnten (Obergrenze 50 Stück pro Speicherung).
2929. [P2] Geräte-Echtheit über Play Integrity (Android) und App Attest (iOS) für Ligen und Raids; das Ergebnis wird beim Start einmal geprüft, braucht Alis Entwicklerkonten.
2930. [P2] Ohne bestandene Echtheitsprüfung bleiben Story, Freunde und Post nutzbar, nur gewertete Ligakämpfe und Raids sind gesperrt.
2931. [P2] Mehrfachkonten: pro gekürzter IP-Adresse (letztes Viertel entfernt) höchstens 5 neue Konten pro Tag, ohne die Adresse dauerhaft zu speichern.
2932. [P2] Neue Konten können erst nach 3 Stunden Spielzeit tauschen und an der Offenen Liga teilnehmen, damit Zweitkonten wenig bringen.
2933. [P2] Gewertete Ligakämpfe zwischen denselben zwei Konten, die immer gleich ausgehen (10 Siege in Folge für dieselbe Seite), markiert der Server als mögliche Absprache.
2934. [P2] Echo-Teams prüft `team_set` mit denselben Regeln wie Spielstände (Arten, Techniken, Ring, Anzahl), damit kein erfundenes Team als Gegner auftaucht.
2935. [P2] Ein Prüfwert über die Kampfdaten wird beim Hochladen mitgeschickt und mit einem Schlüssel pro Sitzung signiert (SHA-256), den `hello` ausgibt.
2936. [P2] Bekannte Schummel-Builds werden über `server_config.blocked_builds` (Liste von Build-Prüfwerten) gesperrt.
2937. [P3] Eine Wochenauswertung der `cheat_flags` als SQL-Abfrage in `docs/ONLINE.md`, damit Ali auffällige Muster sieht.
2938. [P3] Rücknahme: der Server kann den Stand eines Kontos auf einen der letzten fünf Server-Stände zurücksetzen, wenn Schummeln nachgewiesen ist.
2939. [P3] Gesperrte Ligaplätze werden am Saisonende entfernt und die Belohnungen der Nachrückenden nachträglich vergeben.
2940. [P3] Ein Fair-Play-Abzeichen für Konten, die eine ganze Saison ohne Vermerk und ohne Aufgeben gespielt haben.

2941. [P1] Ligateams werden beim Eintragen einmal voll geprüft und als eigene Zeile eingefroren, statt bei jedem Kampf aus dem Spielstand gelesen.
2942. [P2] Kampfdaten mit einem Zeitstempel, der mehr als 10 Minuten von der Server-Zeit abweicht, verwirft der Server.
2943. [P3] Ein Wochenbericht für Ali zeigt, welche Grenzen in `save_put` wie oft gegriffen haben.
2944. [P3] Neue Konten haben in den ersten 7 Tagen halbe Geld- und Gegenstandsgrenzen.
2945. [P3] Einige nie vergebene Fallen-Kennungen stehen in `known_ids`; taucht eine im Spielstand auf, entsteht sofort ein Vermerk.
### Server-Skalierung
2946. [P1] Einen Verbindungspuffer (PgBouncer im Transaktionsmodus, eigener Container) zwischen PostgREST und Postgres schalten, mit höchstens 40 echten Verbindungen.
2947. [P1] Indizes für alle Suchen der neuen Funktionen anlegen (Gegnersuche nach Saison und Wertung, Raids nach Bund und Ende, Tausche nach Spieler und Status) und mit `explain` in einem SQL-Test prüfen.
2948. [P1] Ein Lasttest-Skript `tools/online/load_test.js` (k6) simuliert 5000 gleichzeitige Spieler mit Herzschlag, Speichern, Post und Ligakampf und misst die Antwortzeit.
2949. [P1] Zielwerte festlegen und im Lasttest prüfen: 95 Prozent aller Antworten unter 300 Millisekunden bei 5000 gleichzeitigen Spielern.
2950. [P2] Die Tabelle `rate_events` nach Tagen aufteilen (Partitionen) und Partitionen älter als 2 Tage täglich löschen.
2951. [P2] Anwesenheit (`presence`) in eine nicht protokollierte Tabelle verschieben, weil sie bei einem Neustart verloren gehen darf und viel geschrieben wird.
2952. [P2] Den Herzschlag nur dann in die Datenbank schreiben, wenn sich der Ort geändert hat oder 3 Minuten vergangen sind.
2953. [P2] Ranglisten alle 5 Minuten als fertige Ansicht (materialisierte Ansicht) berechnen statt bei jedem Aufruf.
2954. [P2] Postgres-Einstellungen für die Maschine setzen (`shared_buffers` 25 Prozent des Speichers, `work_mem` 16 MB, `max_connections` 60) in `server/db/postgres.conf`.
2955. [P2] Den Duell-Dienst so bauen, dass ein Prozess 2000 gleichzeitige Verbindungen hält, und das im Lasttest mit 500 gleichzeitigen Duellen prüfen.
2956. [P2] Den Schiedsrichter und den Duell-Dienst mit festen Grenzen für Speicher und CPU in `docker-compose.yml` begrenzen, damit sie die Datenbank nie verdrängen.
2957. [P2] Große Spielstände nur noch als Unterschied zum letzten Stand senden, wenn der Stand größer als 50 KB ist, und auf dem Server zusammensetzen.
2958. [P2] Der Client wartet bei Fehler 429 oder 503 mit wachsender Pause (2, 4, 8, höchstens 60 Sekunden plus Zufall), damit nach einem Ausfall nicht alle gleichzeitig zurückkommen.
2959. [P2] Eine Warteschlange am Eingang: über `server_config.max_online` hinaus zeigt das Spiel "Veydal ist gerade voll, Platz 12 in der Reihe" statt Fehlern.
2960. [P2] Alte Post, alte Tausche und abgelaufene Raids löscht ein nächtlicher Aufräumlauf in Stapeln von 1000 Zeilen.
2961. [P2] Ein Plan in `docs/ONLINE.md`, ab welcher Zahl gleichzeitiger Spieler (2000, 10000, 50000) welcher Schritt nötig wird: eigene Maschine, größere Maschine, Lese-Kopie der Datenbank.
2962. [P3] Chimora von der geteilten Maschine auf einen eigenen Server umziehen, sobald im Lasttest 3000 gleichzeitige Spieler die Zielwerte reißen.
2963. [P3] Eine Lese-Kopie der Datenbank für Ranglisten, Bund-Suche und Statistiken, damit die Hauptdatenbank nur schreibt.
2964. [P3] Mehrere Duell-Dienste hinter einem Verteiler, wobei die Duell-Kennung festlegt, welcher Dienst ein Duell führt.
2965. [P3] Spielstände ab 30 Tagen ohne Login komprimiert (Spalte als komprimiertes JSON) speichern, um Platz zu sparen.
2966. [P3] Eine zweite Region nur als Sicherung (warme Kopie in der EU), mit einem Plan zum Umschalten in unter einer Stunde.

2967. [P1] `pg_stat_statements` ist an, und der Lasttest schlägt fehl, wenn eine Funktion im Mittel über 50 Millisekunden braucht.
2968. [P2] Die Gegnersuche nutzt eine kleine Tabelle `league_queue` mit Ablauf nach 2 Minuten statt einer Suche über alle Spieler.
2969. [P3] Feste Antworten (Regeltexte, Phrasenlisten, Raid-Daten) liefert Caddy mit 1 Stunde Zwischenspeicher aus.
2970. [P3] Der Duell-Dienst nutzt einen eigenen Verbindungspuffer mit 10 Datenbank-Verbindungen.
2971. [P3] Vor jeder großen Event-Woche läuft der Lasttest einmal mit 20000 simulierten Spielern.
### Datenschutz (DSGVO)
2972. [P1] Eine Funktion `data_export` liefert alle eigenen Daten (Profil, Spielstände, Freunde, Post, Tausche, Bund, Ligen, Meldungen gegen das eigene Konto) als JSON-Datei (DSGVO Art. 15 und 20), erreichbar unter Einstellungen, Konto.
2973. [P1] `delete_account` löscht auch alle neuen Daten: Tausche, Bundmitgliedschaft, Raid-Beiträge, Ligawertung, Kampfaufnahmen und Phrasen auf Pinnwänden; ein SQL-Test prüft, dass danach keine Zeile mit der Konto-Kennung übrig ist.
2974. [P1] Ein Verzeichnis der Verarbeitungen in `docs/legal/VERARBEITUNGEN.md` mit Zweck, Daten, Speicherdauer und Rechtsgrundlage für jede Online-Funktion.
2975. [P1] Die Datenschutzerklärung (`docs/legal/DATENSCHUTZ.md`, `server/site/datenschutz.html`) um Ligen, Tausch, Bünde, Raids, Schiedsrichter, Echtheitsprüfung und Moderation ergänzen.
2976. [P2] Eine Tabelle der Speicherdauer pro Datenart in `docs/ONLINE.md` und ein nächtlicher Lauf, der sie durchsetzt (Post 30 Tage, Tausche 90, Raids 60, Moderation 12 Monate).
2977. [P2] Caddy-Zugriffsprotokolle speichern IP-Adressen nur gekürzt und werden nach 7 Tagen gelöscht.
2978. [P2] Eine Datenschutz-Folgenabschätzung für Konten unter 16 (Freunde, Tausch, Bünde) in `docs/legal/DSFA_KINDER.md`.
2979. [P2] Für Konten unter 16 sind Namen in Weltranglisten immer ausgeblendet, unabhängig von der Einstellung.
2980. [P2] Der Freundes-Ort zeigt nur den Kartennamen, nie Uhrzeiten genauer als "vor einer Stunde", um Bewegungsmuster nicht offenzulegen.
2981. [P2] Eine Einstellung "Für Freunde unsichtbar" blendet Online-Punkt und Ort aus, ohne die Freundschaft zu beenden.
2982. [P2] Die Ergebnisse der Echtheitsprüfung werden nur als ja oder nein gespeichert, nie die Rohdaten der Geräte.
2983. [P2] Die Berichtigung (Art. 16 DSGVO) des eigenen Namens ist jederzeit im Menü möglich; der Server führt dazu keinen Verlauf alter Namen außer für offene Meldungen.
2984. [P2] Datenschutz-Anfragen per E-Mail werden in `docs/ONLINE.md` mit einem Ablauf beschrieben: Konto per Freundescode und Übertragungscode bestätigen, Antwort innerhalb eines Monats.
2985. [P2] Die Sicherungen (heute 14 Tage) werden in der Datenschutzerklärung genannt, mit dem Hinweis, dass gelöschte Konten nach spätestens 14 Tagen auch aus den Sicherungen verschwinden.
2986. [P2] Ein kurzer Hinweis vor dem ersten Tausch, Bundbeitritt und Live-Duell in je zwei Sätzen, welche Daten der andere sieht.
2987. [P3] Ein Datenschutz-Bereich im Spiel, der für jede Online-Funktion in einem Satz zeigt, was gespeichert wird und wie lange.
2988. [P3] Pseudonyme Kennungen in Ranglisten: die Weltrangliste nutzt eine pro Saison neue Zufallskennung statt der Konto-Kennung.
2989. [P3] Eine jährliche Prüfliste in `docs/legal/DATENSCHUTZ_PRUEFUNG.md`: Speicherdauern, Löschläufe, Auftragsverarbeitung mit Contabo, Zugriffe auf die Datenbank.
2990. [P3] Für Kampfaufnahmen im Schiedsrichter werden nur Seed, Teams und Züge gespeichert, keine Gerätedaten und keine Namen.

2991. [P1] Ein SQL-Test prüft über den Systemkatalog, dass `data_export` jede Tabelle mit einer Spalte für die Konto-Kennung abdeckt.
2992. [P2] Liga- und Raid-Gegner sehen nur Stufe, Wappen und Spirlings, nie den Freundescode, damit Fremde keine Anfragen schicken können.
2993. [P3] Der Datenexport lässt sich auch als lesbare Seite im Spiel ansehen, nicht nur als Datei.
2994. [P3] Einwilligungen (Name in Weltrangliste, Live-Duelle) werden mit Datum gespeichert und im Export gezeigt.
### Prüfung und Gleichlauf von Server und LocalBackend
2995. [P1] Jede neue Server-Funktion bekommt eine eigene SQL-Testdatei in `tools/online/sql_test/` (`test_league.sql`, `test_trade.sql`, `test_bund.sql`, `test_raid.sql`, `test_mod.sql`, `test_privacy.sql`).
2996. [P1] Jede neue Regel wird gleichlautend in `LocalBackend.gd` gebaut, und ein GDScript-Test ruft dieselben Fälle gegen LocalBackend auf und erwartet dieselben Fehlercodes.
2997. [P2] Ein gemeinsamer Fallkatalog `tools/online/cases.json` (Eingabe, erwarteter Fehlercode) wird sowohl von den SQL-Tests als auch vom LocalBackend-Test gelesen.
2998. [P2] `server/smoke_test.sh` um einen Ablauf erweitern: zwei Testkonten werden Freunde, tauschen einen Gegenstand, gründen einen Bund und machen einen Raid-Versuch.
2999. [P2] Ein Test für Gleichzeitigkeit: 20 Aufrufe von `trade_confirm` und `raid_damage` gleichzeitig, danach sind Bestände und Kraft stimmig.
3000. [P2] Ein Test, dass jede neue Funktion ohne Anmeldung (`auth.uid()` leer) mit `not_signed_in` abbricht.
3001. [P2] Ein Test, dass ein blockiertes Konto in keiner neuen Funktion den Blockierenden findet oder erreicht.
3002. [P2] Ein Test, dass alle neuen Tabellen Zeilenrechte an und keine Rechte für die Spielerrolle haben, als Abfrage über den Systemkatalog.
3003. [P3] Ein Test-Werkzeug `tools/online/fake_players.gd`, das in LocalBackend 50 Spieler mit Bünden, Ligen und Raids anlegt, um Menüs mit vollen Listen zu prüfen.
3004. [P3] Ein Test, dass der Schiedsrichter und der Client für 1000 zufällige Seeds dasselbe Ergebnis rechnen.

3005. [P1] Ein Test ruft jede neue Funktion 100-mal pro Minute auf und erwartet ab der Grenze eine Ablehnung durch `_rate_ok`.
3006. [P2] Ein Test prüft, dass der Eltern-Schalter jede neue soziale Funktion für Konten unter 16 sperrt.
3007. [P3] Ein Test prüft, dass `delete_account` während eines offenen Tauschs die Gegenstände dem Partner zurückgibt.
3008. [P3] Ein Test für den Saisonwechsel stellt die Server-Zeit künstlich vor und prüft Abschluss, Rücksetzung und Belohnungen.
### Konto, Geräte und Verbindung
3009. [P1] Der Server behält die letzten 5 Stände je Spielstand-Platz in `save_history`, und Einstellungen, Konto zeigt sie mit Datum, Ort und Spielzeit zum Wiederherstellen.
3010. [P1] Nur ein Gerät gleichzeitig: `hello` vergibt eine Sitzungskennung, Speicherungen mit einer alten Kennung lehnt der Server ab, und das alte Gerät zeigt "Auf einem anderen Gerät angemeldet".
3011. [P1] Kleine Aktionen (Phrasen, Winken, Weltziel-Beiträge) sammelt `Online.gd` bei schwachem Netz in einer Warteschlange mit bis zu 50 Einträgen, jede mit eigener Kennung, damit der Server doppelte verwirft.
3012. [P2] Eine Status-Seite im Menü zeigt Ping, Server-Version, Regelversion, Kontostatus und laufende Sperren.
3013. [P2] Ein Knopf "Übertragungscode ungültig machen" sperrt einen ausgegebenen Code sofort.
3014. [P2] Nach einem Konto-Umzug liegt in der Post ein Hinweis mit Datum und Gerätetyp, damit ein gestohlener Code auffällt.
3015. [P2] Optionales Verknüpfen mit Apple- oder Google-Anmeldung als zweiter Umzugsweg, gespeichert wird nur die Kennung des Anbieters, nie eine E-Mail; braucht Alis Entwicklerkonten.
3016. [P2] Der Konflikt-Bildschirm zeigt beide Stände nebeneinander mit Ort, höchstem Ring, Spielzeit und Zeitpunkt der Speicherung.
3017. [P2] `server_config.maintenance_at` zeigt 24 Stunden vorher einen Hinweis und speichert 5 Minuten vor der Wartung automatisch.
3018. [P2] Nach 3 Minuten erfolgloser Verbindungsversuche bietet der Wiederverbinden-Bildschirm "Zum Titelbild" an, ohne dass Fortschritt verloren geht.
3019. [P2] Konten ohne Anmeldung seit 24 Monaten werden gelöscht; die Frist steht in der Datenschutzerklärung und auf dem Titelbild nach 18 Monaten Pause.
3020. [P3] Der Übertragungscode lässt sich als QR-Code zeigen und mit der Kamera einlesen.
3021. [P3] Mehrere Profile auf einem Gerät für Geschwister, jedes mit eigenem Konto und eigenem Eltern-Schalter.
3022. [P3] Restzeiten von Events richten sich nach einem Uhrabgleich mit dem Server mit weniger als 1 Sekunde Abweichung.
3023. [P3] Die letzten 10 Anmeldungen mit Datum und Gerätetyp, ohne IP-Adresse, stehen im Menü Konto.
3024. [P3] Zusätzlich zu den letzten 5 Ständen behält der Server je einen Wochenstand der letzten 4 Wochen.
3025. [P3] Eine Konto-Pause bis 90 Tage macht den Spieler für Freunde unsichtbar und hält Post und Einladungen an.
3026. [P3] Stände aus einer neueren App-Version werden auf älteren Geräten nicht geladen, mit Hinweis auf das Update.
3027. [P3] Ein Knopf "Verbindung testen" schickt 5 Anfragen und zeigt Ping und Verluste.
3028. [P3] Ein kleines Netz-Symbol oben rechts erscheint, sobald der Ping über 500 Millisekunden liegt.
### Freunde und Wanderer-Karte
3029. [P1] Die Wanderer-Karte zeigt die Stufen beider Ligen, das Bundwappen und Raid-Abzeichen, alles vom Server geliefert und nie vom Client gesetzt.
3030. [P1] Bundmitglieder zählen nicht zum Freundeslimit von 100 und sehen voneinander nur Name, Wappen und Karte, nicht den Ort.
3031. [P2] 30 Titel für Erfolge (zum Beispiel "Lampenwächter", "Tauschfreund", "Risshüter"), die der Server vergibt und von denen der Spieler einen für die Karte wählt.
3032. [P2] Spirlog-Vergleich: auf der Karte eines Freundes sieht man, welche der 21 Spirlings er gesehen hat und welche nur man selbst.
3033. [P2] Eigene Spitznamen für Freunde, nur auf dem eigenen Gerät gespeichert und durch den Namensfilter geprüft.
3034. [P2] Rastfeuer teilen: einmal am Tag heilt ein Freund dein Team aus der Ferne, als Post mit Knopf "Annehmen".
3035. [P2] Fundort-Tipps: den Kartennamen eines gesehenen seltenen Spirlings als feste Phrase an einen Freund schicken.
3036. [P2] Willkommenspaket: wer beim ersten Start den Freundescode eines Freundes eingibt, bekommt 3 Heilgegenstände und der Freund 1, höchstens 10 Mal pro werbendem Konto.
3037. [P2] Automatischer Glückwunsch in der Post, wenn ein Freund einen Riss versiegelt oder eine Ligastufe aufsteigt, abschaltbar.
3038. [P2] Die Freundesliste lässt sich nach online, Freundschaftsstufe oder zuletzt gesehen sortieren.
3039. [P3] Der Freundescode lässt sich als QR-Code zeigen und einlesen.
3040. [P3] Freundesvorschläge nur aus Bund und Raids, für Spieler, mit denen man mindestens 3 Mal zusammen gespielt hat.
3041. [P3] Am Kontojubiläum gibt es einen eigenen Kartenrahmen und einen Gruß an alle Freunde.
3042. [P3] Saisonale Kartenrahmen aus Festivals.
3043. [P3] Ein eigenes Spielbild aus dem Fotomodus als Kartenhintergrund, nur für Freunde sichtbar.
3044. [P3] Freundschaftsstufen 6 bis 10 mit kleinen Anzeige-Belohnungen (Rahmen, Symbol neben dem Namen).
3045. [P3] Freundes-Spirlog: haben zwei Freunde zusammen alle 21 Spirlings gesehen, bekommen beide einen Rahmen.
3046. [P3] Eine Weltkarte zeigt Freunde als Symbole nur am Kartennamen, nie an der genauen Stelle.
3047. [P3] Gerüchte: ein NPC in Brindlewick erzählt, was deine Freunde zuletzt geschafft haben.
3048. [P3] Lehrlinge: Spieler ab 20 Stunden Spielzeit begleiten Neulinge, und nach 5 gemeinsamen Echo-Kämpfen bekommen beide eine Zierde.
3049. [P3] Ein freiwilliger Gruß an Freunde, die 14 Tage nicht da waren, ohne Druck und ohne Belohnung für den Rückkehrer.
3050. [P3] Freunde erscheinen als Figuren im eigenen Leuchtturmzimmer, nur zur Anzeige.
### Echos und asynchrones Miteinander
3051. [P1] Die Gegner-Wanderer im Echo-Turm sind geprüfte Echo-Teams anderer Spieler, anonym mit einem Namen aus Wortbausteinen.
3052. [P1] Echo-Teams tragen einen Zeitstempel, und Echos, die älter als 30 Tage sind, werden für Fremde nicht mehr genutzt.
3053. [P2] Eine Echo-Liste zeigt, welcher Freund dir wie oft geholfen hat.
3054. [P2] Für das eigene Echo wählt man eine Rolle (Schützen, Zuschlagen, Heilen), die die KI-Steuerung des Echos lenkt.
3055. [P2] Eine Wochenzusammenfassung in der Post: "Dein Echo hat 14 Mal gekämpft, 9 Siege".
3056. [P2] Das eigene Echo lässt sich für Fremde abschalten; Freunde können es weiter nutzen.
3057. [P2] Echo-Ehre aus den Ligen lässt sich gegen Kartenrahmen eintauschen (50 Punkte je Rahmen).
3058. [P2] Herausforderung schicken: eine feste Aufgabe ("Riss 2 ohne Heilung") an einen Freund, deren Ergebnis der Schiedsrichter bestätigt.
3059. [P2] Echo-Teams speichern auch die gewählten Andenken, damit das Echo wie der Spieler kämpft, geprüft in `team_set`.
3060. [P3] Rastpunkt-Gästebuch: an Rastpunkten eine Phrase hinterlassen, die Freunde dort sehen.
3061. [P3] Eine leuchtende Laterne liegt dort, wo ein Freund zuletzt war, 24 Stunden lang.
3062. [P3] Ein Drei-Freunde-Rätsel pro Woche, das sich nur mit drei verschiedenen Hinweisen lösen lässt.
3063. [P3] Wanderkarten: Freunde schicken dir eine Route mit drei Fundorten.
3064. [P3] Finden zwei Freunde am selben Tag den Fund des Tages, bekommen beide einen kleinen Bonus.
3065. [P3] Welt-Spirlog-Statistik: "12 Prozent aller Wanderer haben Glimfin gesehen", einmal pro Tag berechnet.
3066. [P3] Ein Bildwettbewerb unter Freunden: je ein Spielbild pro Woche, Freunde vergeben Lampen.
3067. [P3] Rätselhilfe: ein Freund schickt einen festen Hinweis für das Lampenrätsel.
3068. [P3] Das Leuchtturmzimmer lässt sich mit Geschenken von Freunden schmücken.
3069. [P3] Nach einem Sieg gegen ein Echo kann man dem Besitzer eine Phrase dalassen.
3070. [P3] Seltene Spur weitergeben: ein Freund markiert einen Ort, und du bekommst dort für einen Tag eine höhere Begegnungsrate.
### Weltziele und Gemeinschafts-Events
3071. [P1] Neue Weltziel-Arten `league_wins`, `raid_damage` und `trades` in `goal_rotation`, damit die neuen Funktionen ins Wochenziel einzahlen.
3072. [P1] Ein Event-Kalender im Menü zeigt alle Events der nächsten 4 Wochen aus der neuen Tabelle `events` (Art, Start, Ende, Regeln).
3073. [P2] Welt-Wetter: ein Sturmtag für alle, vom Server in `events` gesetzt, ändert das Wetter auf allen Karten für 24 Stunden.
3074. [P2] Seltene Sichtung: eine Stunde lang taucht ein seltener Spirling auf allen Karten fünfmal häufiger auf, 24 Stunden vorher angekündigt.
3075. [P2] Eine Welt-Chronik listet alle geschafften Weltziele mit Datum.
3076. [P2] Der Leuchtturm im Titelbild leuchtet in 4 Stufen heller, je weiter das Weltziel ist.
3077. [P2] Nach 14 Tagen Pause gibt es ein Geschenk passend zum laufenden Weltziel, höchstens einmal in 60 Tagen.
3078. [P2] Eine Helfer-Tafel mit den 20 eifrigsten Helfern der Woche, nur mit Zustimmung.
3079. [P2] Am Starttag eines Events erscheint ein kurzer Hinweis auf dem Titelbild.
3080. [P2] Event-Regeln stehen als JSON in `events.rules`, damit neue Events ohne App-Update kommen.
3081. [P2] Event-Belohnungen holt man wie Weltziel-Belohnungen beim Server ab, und ein SQL-Test prüft, dass doppeltes Abholen scheitert.
3082. [P3] Nord gegen Süd: zwei Seiten sammeln eine Woche lang Punkte, beide bekommen etwas.
3083. [P3] Ein Server-Schalter `community_unlocks`, über den andere Bereiche Inhalte an geschaffte Weltziele koppeln können.
3084. [P3] Ein Freitagabend-Event um 19 Uhr Server-Zeit, 30 Minuten lang.
3085. [P3] Ein Spendenbrunnen, in den man Gegenstände für ein Weltziel einwirft.
3086. [P3] Ein Welt-Wetterbericht im Menü sagt, was heute in Veydal los ist.
3087. [P3] Ein NPC berichtet in jeder Stadt, was die Gemeinschaft gerade tut.
3088. [P3] Volle Orte: die drei Karten mit den meisten Wanderern, nur angezeigt ab 20 Spielern pro Karte.
3089. [P3] Leuchtturm-Aufbau: die Gemeinschaft baut in 10 Abschnitten einen Leuchtturm auf, jeder Abschnitt ist ein Weltziel.
3090. [P3] Festival-Weltziele mit eigener Zierde für alle Beitragenden.
3091. [P3] Schafft die Gemeinschaft zusammen 1 Million Bindungen, gibt es eine Feier mit Geschenk für alle.
3092. [P3] Ein Event läuft 3 Mal am Tag zu verschiedenen Uhrzeiten, damit alle Zeitzonen teilnehmen.
3093. [P3] Spieler stimmen unter 3 Zielarten für das Weltziel der nächsten Woche ab.
3094. [P3] Beim Weltziel steht zusätzlich der Anteil des eigenen Bundes.
### Barrierefreiheit und Spielerwohl online
3095. [P1] Alle neuen Online-Menüs (Ligen, Tausch, Bund, Raid, Moderation) funktionieren mit den bestehenden Anzeige-Optionen und passen auf 144x256 ohne abgeschnittenen Text.
3096. [P1] Keine Strafen fürs Pausieren auch in den neuen Funktionen: kein Verlust von Ligastufe, Bundplatz oder Raid-Beitrag durch Abwesenheit, als SQL-Test festgehalten.
3097. [P2] Freundesduelle und Live-Raids haben eine Option "mehr Zeit" mit doppelter Zugzeit, die beide sehen.
3098. [P2] Nach 90 Minuten Ligaspiel am Stück fragt ein Hinweis "Zeit für eine Pause?", abschaltbar.
3099. [P2] Nach einer Liga-Niederlage zeigt das Spiel eine kurze, freundliche Auswertung (Element-Vorteile des Gegners) statt nur "Verloren".
3100. [P2] Alle Online-Hinweise im Spiel sind einzeln abschaltbar: Duell, Tausch, Bund, Raid und Glückwunsch.
3101. [P2] Online-Punkte und Stufenfarben haben zusätzlich ein Symbol, damit sie auch ohne Farbsehen lesbar sind.
3102. [P2] Gewertete Ligakämpfe lassen sich immer auch asynchron spielen, damit langsame Bedienung kein Nachteil ist.
3103. [P3] Bundpinnwand und Post werden vom Screenreader vorgelesen.
3104. [P3] Ruhezeiten für Hinweise sind für alle frei einstellbar.
3105. [P3] Ein Leise-Modus mit einem Schalter: nur Freunde, keine Liga- und Raid-Einladungen.
3106. [P3] Eine Tageszusammenfassung statt vieler einzelner Hinweise, wählbar im Menü.
3107. [P3] Ein Rückmelde-Knopf im Online-Menü mit festen Kategorien und optional einem Spielbild, gespeichert in Tabelle `feedback`.
3108. [P3] Beim ersten Öffnen jeder neuen Online-Funktion erklärt eine kurze Szene von höchstens 3 Bildschirmen, wie sie funktioniert.
3109. [P3] Ein Wochenrückblick zeigt Duelle, Tausche, Raid-Beiträge und gesammelte Freundschaftspunkte.
3110. [P3] Eine Linkshänder-Anordnung für das Schnellrad im Duell.
3111. [P3] Fair-Play-Hinweise auf den Ladebildschirmen der Ligen.
3112. [P3] Eine Option "Ergebnis erst nach Tipp zeigen" für spannende Ligaergebnisse.
