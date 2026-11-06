# Verzeichnis von Verarbeitungstätigkeiten (Art. 30 DSGVO)

Verantwortlicher: siehe `IMPRESSUM.md`. Server: Contabo GmbH, Rechenzentrum in Deutschland
(Auftragsverarbeitung, Vertrag siehe `CHECKLISTE_ALI.md`). Alle Online-Daten liegen in einer
Postgres-Datenbank auf diesem Server; Tabellen und Funktionen stehen in `supabase/migrations/`.

Für jede Online-Funktion: Zweck, Daten (Tabellen), betroffene Personen, Speicherdauer, Rechtsgrundlage.
Betroffene sind immer Spielerinnen und Spieler von Chimora (alle Altersgruppen, auch Kinder; Eltern können Freunde, Grüße und Geschenke ausschalten).

| Funktion | Zweck | Daten (Tabellen) | Speicherdauer | Rechtsgrundlage |
| --- | --- | --- | --- | --- |
| Konto und Anmeldung | Spiel ohne E-Mail bereitstellen, Gerätewechsel | `auth.users` (zufällige ID), `auth.sessions`, `auth.refresh_tokens`, `profiles` (Freundescode, Wanderer-Name, Farbe, Karte, letzter Besuch, `inactive_since`), `transfer_codes` (nur Hash), `transfer_attempts` (Zeit von Fehlversuchen) | solange das Konto besteht; nach 24 Monaten ohne Besuch markiert und 30 Tage später gelöscht (`_daily_cleanup`); Konten aus der Browser-Testversion (`profiles.platform = 'web'`) nach 30 Tagen ohne Besuch (`_web_cleanup`); Übertragungscodes 7 Tage, Fehlversuche 1 Tag | Art. 6 Abs. 1 lit. b |
| Spielstände | Fortschritt speichern und wiederherstellen | `saves` (Spielstand als JSON, Revision, Zeit) | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Echtheitsprüfung beim Speichern | Schutz vor manipulierten Ständen, faire Ligen | `cheat_flags` (Grund, Geld und Spielzeit vorher und nachher), `profiles.cheat_cleared_at` | 6 Monate (`_privacy_cleanup`) | Art. 6 Abs. 1 lit. f |
| Freunde, Blockieren | gemeinsames Spielen, Schutz vor Belästigung | `friendships`, `blocks` | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Leuchtpost und Geschenke | Grüße als feste Satznummern, tägliche Geschenke | `mail` | 30 Tage | Art. 6 Abs. 1 lit. b |
| Echo-Team und Echo-Duell | Freunde kämpfen gegen eine Kopie des Teams | `profiles.team` (Art, Ring, Techniken) | solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Weltziel und Wochen-Rangliste | gemeinsames Wochenziel, Bestenliste ohne Namen für Fremde | `community_contrib`, `weekly_scores` | bis zum Ende der Folgewoche | Art. 6 Abs. 1 lit. b |
| Meldungen | Missbrauch prüfen (DSA Art. 16) | `reports` (Meldender, Gemeldeter, Grund, Ort, Status, Maßnahme) | bis zur Bearbeitung, höchstens 6 Monate | Art. 6 Abs. 1 lit. c und f |
| Meldeformular im Web | Meldungen ohne Konto (DSA Art. 16) | `web_reports` (Freundescode als Text, Grund, Erklärung, freiwillig Name und E-Mail, Bestätigung guten Glaubens); die anonyme Anmeldung des Formulars wird sofort wieder gelöscht | höchstens 6 Monate | Art. 6 Abs. 1 lit. c und f |
| Bünde | gemeinsam spielen in Gruppen bis 30 | `bunds` (zwei Wortnummern als Name), `bund_members` (Rolle, Beitritt), `bund_invites` (Einladung oder Anfrage) | solange das Konto besteht, Austritt jederzeit; leere Bünde werden gelöscht | Art. 6 Abs. 1 lit. b |
| Raid-Risse | gemeinsam einen Wächter schwächen (2 bis 4 Spieler) | `raids` (Wächter, Stärke, ohne Konto-IDs), `raid_members` (Schaden, Belohnung genommen), `raid_attempts` (Kampf-Seed, Teams, Prüfergebnis) | 7 Tage nach Ende des Risses | Art. 6 Abs. 1 lit. b |
| Tausch | Gegenstände unter Freunden tauschen, Server als Treuhänder | `trades` (Zustand, Fristen, ohne Konto-IDs), `trade_sides` (eingelegte Gegenstände, Bestätigung, abgeholt) | bis beide Seiten abgeholt haben, höchstens 90 Tage | Art. 6 Abs. 1 lit. b |
| Frühere Spielstände | einen älteren Spielstand zurückholen | `save_history` (die letzten 5 Fassungen je Platz mit Datum und Zusammenfassung) | bis eine neuere Fassung sie verdrängt, sonst solange das Konto besteht | Art. 6 Abs. 1 lit. b |
| Begründungen und Widersprüche | Entscheidungen begründen, Widerspruch ermöglichen (DSA Art. 17, 20) | `notices` (Art, Meldenummer, feste Angaben, gelesen), `appeals` (Grund aus fester Liste, Status) | solange das Konto besteht | Art. 6 Abs. 1 lit. c |
| Kampfprüfung (Schiedsrichter) | Ergebnisse von Ligen, Raids und Duellen nachprüfen | `battles`, `battle_results`; `battle_queue` ohne Konto-Kennung | 30 Tage (`_privacy_cleanup`) | Art. 6 Abs. 1 lit. b und f |
| Ligen | faire Wertung und Gegnersuche | `league_fair_entries`, `league_open_entries` (Team, Wertung, Kämpfe), `league_matches` | Einträge bis zum Ende der folgenden Saison, Paarungen 30 Tage | Art. 6 Abs. 1 lit. b |
| Missbrauchsgrenzen | zu viele Aufrufe bremsen | `rate_events` (Art und Zeit) | 1 Stunde Wirkung, alte Zeilen werden mitgelöscht | Art. 6 Abs. 1 lit. f |
| Server-Protokolle | Betrieb und Sicherheit | Container-Logs (IP, Zeit, Endpunkt, Status; Docker-Logrotation), Anmelde-Protokoll `auth.audit_log_entries` (mit IP) | 7 Tage (`_daily_cleanup` für das Anmelde-Protokoll) | Art. 6 Abs. 1 lit. f |
| Datenbank-Sicherungen | Wiederherstellung nach Ausfall | alle obigen Tabellen (`server/backups/`, wöchentlicher Wiederherstellungstest) | 14 Tage | Art. 6 Abs. 1 lit. b und f |
| Kaufbelege (sobald der Shop live ist, Bereich 10) | Freischalten, Aufbewahrungspflicht | Transaktions-ID, Produkt, Zeitpunkt | bis 10 Jahre (HGB, AO) | Art. 6 Abs. 1 lit. b und c |
| Gerät des Spielers (`user://`) | Spiel offline zwischenspeichern | Spielstand-Kopie mit Sicherungen, Einstellungen, Anmelde-Token | bis zur Deinstallation oder Kontolöschung | § 25 Abs. 2 Nr. 2 TDDDG |
| Support | Anfragen beantworten | E-Mails | bis erledigt, höchstens 2 Jahre | Art. 6 Abs. 1 lit. b oder f |

## Löschläufe

- **Täglich 04:15** `server/cleanup.sh` → `public._daily_cleanup()` (Migration `20261110090002_tech_privacy.sql`):
  Leuchtpost 30 Tage, Meldungen 6 Monate, Wochenwerte und Weltziel-Beiträge nach der Folgewoche,
  `rate_events` und `transfer_attempts` 1 Tag, Übertragungscodes 7 Tage, inaktive Konten (siehe oben),
  Anmelde-Protokoll 7 Tage, dazu `_web_cleanup()` für Browser-Testkonten (30 Tage). Ruft auch `_privacy_cleanup()` auf (Ligen, Kämpfe, Echtheitsprüfung), das
  zusätzlich ab und zu bei `hello` läuft. Das Ergebnis steht im Cron-Log.
- Empfänger: Contabo GmbH (Hosting, Art. 28), Apple und Google (eigene Verantwortung), Behörden nur bei
  gesetzlicher Pflicht. Kein Drittland. Kein Datenschutzbeauftragter (keine Pflicht nach § 38 BDSG).

## Technische und organisatorische Maßnahmen (Art. 32)

- TLS für jede Verbindung (Caddy, Let's Encrypt). Nur Caddy ist von außen erreichbar.
- Spieler lesen keine Tabellen direkt; alles läuft über Funktionen mit `security definer`, festem
  `search_path` und Prüfung von `auth.uid()` (geprüft von `test_security.sql`).
- Grenzen: 512 KB pro Anfrage, 256 KB pro Spielstand, 3 s pro Abfrage, 10 neue Konten pro Stunde und IP.
- Nächtliche Sicherung, Sicherung vor jeder Migration, wöchentlicher Wiederherstellungstest.
- Zugriff auf den Server nur durch den Verantwortlichen (über das lifekit-Repository).
- Keine Werbe-, Analyse- oder Absturz-SDKs von Dritten.
- Offen: verschlüsselte Kopie der Sicherungen bei einem zweiten EU-Anbieter (Plan 3825, dann hier als
  Empfänger mit AV-Vertrag eintragen); AV-Vertrag mit Contabo unterschreiben (Ali).

## Rechte der Betroffenen

- **Auskunft und Übertragbarkeit (Art. 15, 20):** `data_export` liefert alle Zeilen aller Tabellen mit einer
  Konto-Spalte als JSON (Einstellungen, Konto, „Meine Daten herunterladen“). Andere Spieler erscheinen nur
  als „another player“. Ein SQL-Test (`test_privacy.sql`) prüft über den Systemkatalog, dass keine Tabelle fehlt.
- **Löschung (Art. 17):** `delete_account` löscht das Konto und danach jede Zeile, die noch die Konto-Kennung
  trägt; derselbe Test prüft, dass nichts übrig bleibt.

## Neue Funktionen

Jede neue Online-Funktion (Tausch, Bünde, Raids, Live-Duelle) bekommt hier eine Zeile, bevor sie per
`feature_flags` eingeschaltet wird, und einen Abschnitt in `DATENSCHUTZ.md`.
