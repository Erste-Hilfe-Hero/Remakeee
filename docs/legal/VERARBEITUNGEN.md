# Verzeichnis von Verarbeitungstätigkeiten (Art. 30 DSGVO)

Verantwortlicher: siehe `IMPRESSUM.md`. Server: Contabo GmbH, Rechenzentrum in Deutschland
(Auftragsverarbeitung, Vertrag siehe `CHECKLISTE_ALI.md`). Alle Online-Daten liegen in einer
Postgres-Datenbank auf diesem Server; Tabellen und Funktionen stehen in `supabase/migrations/`.

Für jede Online-Funktion: Zweck, Daten (Tabellen), betroffene Personen, Speicherdauer, Rechtsgrundlage.
Betroffene sind immer Spielerinnen und Spieler von Chimora (alle Altersgruppen, auch Kinder; Eltern können Freunde, Grüße und Geschenke ausschalten).

| Funktion | Zweck | Daten (Tabellen) | Speicherdauer | Rechtsgrundlage |
| --- | --- | --- | --- | --- |
| Konto und Anmeldung | Spiel ohne E-Mail bereitstellen, Gerätewechsel | `auth.users` (zufällige ID), `profiles` (Freundescode, Wanderer-Name, Farbe, Karte, letzter Besuch), `transfer_codes` (nur Hash), `transfer_attempts` (Zeit von Fehlversuchen) | solange das Konto besteht; Übertragungscodes 7 Tage | Art. 6 Abs. 1 lit. b |
| Spielstände | Fortschritt speichern und wiederherstellen | `saves` (Spielstand als JSON, Revision, Zeit) | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Echtheitsprüfung beim Speichern | Schutz vor manipulierten Ständen, faire Ligen | `cheat_flags` (Grund, Geld und Spielzeit vorher und nachher), `profiles.cheat_cleared_at` | 6 Monate (`_privacy_cleanup`) | Art. 6 Abs. 1 lit. f |
| Freunde, Blockieren | gemeinsames Spielen, Schutz vor Belästigung | `friendships`, `blocks` | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Leuchtpost und Geschenke | Grüße als feste Satznummern, tägliche Geschenke | `mail` | 30 Tage | Art. 6 Abs. 1 lit. b |
| Echo-Team und Echo-Duell | Freunde kämpfen gegen eine Kopie des Teams | `profiles.team` (Art, Ring, Techniken) | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Weltziel und Wochen-Rangliste | gemeinsames Wochenziel, Bestenliste ohne Namen für Fremde | `community_contrib`, `weekly_scores` | bis zum Ende der Folgewoche | Art. 6 Abs. 1 lit. b |
| Meldungen | Missbrauch prüfen (DSA Art. 16) | `reports` (Meldender, Gemeldeter, Grund, Ort, Status, Maßnahme) | bis zur Bearbeitung, höchstens 6 Monate | Art. 6 Abs. 1 lit. c und f |
| Begründungen und Widersprüche | Entscheidungen begründen, Widerspruch ermöglichen (DSA Art. 17, 20) | `notices` (Art, Meldenummer, feste Angaben, gelesen), `appeals` (Grund aus fester Liste, Status) | solange das Konto besteht | Art. 6 Abs. 1 lit. c |
| Kampfprüfung (Schiedsrichter) | Ergebnisse von Ligen, Raids und Duellen nachprüfen | `battles`, `battle_results`; `battle_queue` ohne Konto-Kennung | 30 Tage (`_privacy_cleanup`) | Art. 6 Abs. 1 lit. b und f |
| Ligen | faire Wertung und Gegnersuche | `league_fair_entries`, `league_open_entries` (Team, Wertung, Kämpfe), `league_matches` | Einträge bis zum Ende der folgenden Saison, Paarungen 30 Tage | Art. 6 Abs. 1 lit. b |
| Missbrauchsgrenzen | zu viele Aufrufe bremsen | `rate_events` (Art und Zeit) | 1 Stunde Wirkung, alte Zeilen werden mitgelöscht | Art. 6 Abs. 1 lit. f |
| Server-Protokolle | Betrieb und Sicherheit | Webserver-Logs (IP, Zeit, Endpunkt, Status) | 7 Tage | Art. 6 Abs. 1 lit. f |
| Support | Anfragen beantworten | E-Mails | bis erledigt, höchstens 2 Jahre | Art. 6 Abs. 1 lit. b oder f |

## Rechte der Betroffenen

- **Auskunft und Übertragbarkeit (Art. 15, 20):** `data_export` liefert alle Zeilen aller Tabellen mit einer
  Konto-Spalte als JSON (Einstellungen, Konto, „Meine Daten herunterladen“). Andere Spieler erscheinen nur
  als „another player“. Ein SQL-Test (`test_privacy.sql`) prüft über den Systemkatalog, dass keine Tabelle fehlt.
- **Löschung (Art. 17):** `delete_account` löscht das Konto und danach jede Zeile, die noch die Konto-Kennung
  trägt; derselbe Test prüft, dass nichts übrig bleibt.

## Neue Funktionen

Jede neue Online-Funktion (Tausch, Bünde, Raids, Live-Duelle) bekommt hier eine Zeile, bevor sie per
`feature_flags` eingeschaltet wird, und einen Abschnitt in `DATENSCHUTZ.md`.
