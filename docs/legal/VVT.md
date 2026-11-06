# Verzeichnis von Verarbeitungstätigkeiten (Art. 30 DSGVO)

Stand: 6. November 2026. Plan Bereich 9, Punkt 3901. Dieses Verzeichnis ist intern (nicht für die Website)
und muss bei jeder neuen Tabelle, jedem neuen Dienst und jeder geänderten Frist mitgeändert werden. Die
Fristen müssen mit `DATENSCHUTZ.md` und `PRIVACY_POLICY_EN.md` übereinstimmen. Erstellt von einer KI,
keine anwaltliche Prüfung.

## 1. Verantwortlicher

Ali Amuri Alnasag, Im Vogelgesang 9, 60488 Frankfurt am Main, aa.amuri@icloud.com.
Kein Datenschutzbeauftragter (keine Pflicht nach § 38 BDSG).

## 2. Überblick

| | |
| --- | --- |
| Verarbeitung | Betrieb des Online-Spiels Chimora (iOS, Android, Browser-Testversion) |
| Betroffene | Spielerinnen und Spieler (alle Altersgruppen), Personen, die den Support anschreiben |
| Empfänger | Contabo GmbH (Hosting, Auftragsverarbeiter nach Art. 28), Apple und Google (eigene Verantwortung), Behörden nur bei gesetzlicher Pflicht |
| Drittland | keines; Server in Deutschland |
| Löschung | täglicher Lauf `public._daily_cleanup()` über `server/cleanup.sh` (Cron 04:15), Konto löschen im Spiel (`delete_account`) und über `/konto-loeschen` |

## 3. Tabellen und Dienste

Rechtsgrundlagen: (b) = Art. 6 Abs. 1 lit. b DSGVO (Nutzungsvertrag), (c) = lit. c (rechtliche Pflicht),
(f) = lit. f (berechtigtes Interesse: sicherer, fairer Spielbetrieb).

| Ort | Daten | Zweck | Grundlage | Frist | Umgesetzt durch |
| --- | --- | --- | --- | --- | --- |
| `auth.users`, `auth.sessions`, `auth.refresh_tokens` (GoTrue) | zufällige Spieler-ID, Anmelde-Token | Anmeldung ohne E-Mail | (b) | solange das Konto besteht; inaktiv 24 Monate + 30 Tage Markierung | `delete_account`, `_daily_cleanup` (inaktive Konten, Löschung kaskadiert auf alle Tabellen) |
| `auth.audit_log_entries` (GoTrue) | Anmelde-Ereignisse mit IP-Adresse | Sicherheit | (f) | 7 Tage | `_daily_cleanup` |
| `public.profiles` | Freundescode, Wayfarer-Name, Farbe, Lieblings-Spirling, Tamer-Karte (Zahlen), Ort im Spiel, Echo-Team, Schalter Soziales, letzter Besuch | Spiel, Freunde | (b) | solange das Konto besteht | Kaskade von `auth.users` |
| `public.saves` | Spielstand (bis 3 Plätze), Kurzbeschreibung, Revision, Anfrage-ID | Fortschritt speichern | (b) | solange das Konto besteht | `save_delete`, Kaskade |
| `public.transfer_codes` | Hash des Übertragungscodes | Gerätewechsel ohne E-Mail | (b) | 7 Tage | `_daily_cleanup`, `transfer_claim` |
| `public.transfer_attempts` | Spieler-ID, Zeitpunkt | Schutz gegen Raten von Codes | (f) | 1 Tag | `_daily_cleanup`, `transfer_claim` |
| `public.friendships`, `public.blocks` | Paare von Spieler-IDs, Status | Freunde, Blockieren | (b) | solange das Konto besteht | Kaskade |
| `public.mail` | Grüße (Satznummer), Geschenke, Ort im Spiel | Leuchtpost | (b) | 30 Tage | `_daily_cleanup`, `mail_list` |
| `public.reports` | Melder, Gemeldeter, Name, Grund | Meldungen nach Art. 16 DSA | (c), (f) | bis zur Bearbeitung, höchstens 6 Monate | `_daily_cleanup` |
| `public.rate_events` | Spieler-ID, Art, Zeitpunkt | Missbrauchsschutz (Ratenbegrenzung) | (f) | 1 Tag | `_daily_cleanup` |
| `public.community_contrib`, `public.weekly_scores` | Beitrag zum Weltziel, Wochenpunkte | Weltziel, Wochen-Rangliste | (b) | bis Ende der Folgewoche | `_daily_cleanup`, `community_get` |
| `public.community_goals`, `public.server_config`, `public.banned_words` | keine personenbezogenen Daten | Spielregeln | – | – | – |
| Container-Logs (Caddy, GoTrue, PostgREST, Postgres) | IP-Adresse, Zeit, Endpunkt, Status | Betrieb, Sicherheit | (f) | 7 Tage | Docker-Logrotation (`server/docker-compose.yml`) |
| Datenbank-Sicherungen `server/backups/` | alle obigen Daten | Wiederherstellung nach Ausfall | (b), (f) | 14 Tage | `server/backup.sh` |
| Kaufbelege (sobald der Shop live ist, Bereich 10) | Transaktions-ID, Produkt, Zeitpunkt | Freischalten, Aufbewahrungspflicht | (b), (c) | bis 10 Jahre (HGB, AO) | Bereich 10 |
| Support-E-Mails (iCloud-Postfach) | Nachricht, E-Mail-Adresse, ggf. Spieler-ID | Anfrage beantworten | (b), (f) | nach Erledigung, höchstens 2 Jahre | von Hand |
| Gerät des Spielers (`user://`) | Spielstand-Kopie, Einstellungen, Anmelde-Token | Spiel offline zwischenspeichern | § 25 Abs. 2 Nr. 2 TDDDG | bis zur Deinstallation oder Kontolöschung | `Online.delete_account` |

## 4. Technische und organisatorische Maßnahmen (Art. 32)

- TLS für jede Verbindung (Caddy, Let's Encrypt). Nur Caddy ist von außen erreichbar.
- Spieler lesen keine Tabellen direkt; alles läuft über Funktionen mit `security definer`, festem
  `search_path` und Prüfung von `auth.uid()`.
- Grenzen: 512 KB pro Anfrage, 256 KB pro Spielstand, 3 s pro Abfrage, 10 neue Konten pro Stunde und IP.
- Spielstände mit Revisionen und Konfliktprüfung; nächtliche Sicherung, Sicherung vor jeder Migration.
- Zugriff auf den Server nur durch den Verantwortlichen (über das lifekit-Repository).
- Keine Werbe-, Analyse- oder Absturz-SDKs von Dritten.

## 5. Noch offen

- Datenexport "Meine Daten" (Art. 15 und 20): Serverfunktion baut Bereich 7, Punkt 3903.
- Externe, verschlüsselte Kopie der Sicherungen bei einem zweiten EU-Anbieter (Punkt 3825); dann hier
  als Empfänger mit AV-Vertrag eintragen.
- AV-Vertrag mit Contabo unterschreiben (Ali, Kundenkonto).
