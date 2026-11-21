# Server-Betrieb

Plan Bereich 9 (Punkte 3826 bis 3850). Ergänzt `docs/ONLINE.md` (Aufbau) und `docs/SICHERHEIT.md`.
Der Server läuft auf Alis Contabo-Rechner 161.97.102.171 im geteilten Modus (`/opt/chimora`), Deploys
kommen aus dem lifekit-Repository (Workflow "Chimora on Contabo", `run:chimora-deploy`).

## Was automatisch läuft

| Wann | Was | Datei | Log auf dem Server |
| --- | --- | --- | --- |
| täglich 03:30 | Datenbank-Sicherung, geprüft mit `pg_restore --list`, 14 Tage aufbewahrt | `server/backup.sh` | `/var/log/chimora-backup.log` |
| täglich 04:15 | Löschlauf für die Fristen der Datenschutzerklärung | `server/cleanup.sh` | `/var/log/chimora-cleanup.log` |
| montags 05:00 | Wiederherstellungs-Test der neuesten Sicherung in eine Wegwerf-Datenbank, Ergebnis in `/status.json` | `server/restore_test.sh` | `/var/log/chimora-restore.log` |
| alle 10 Minuten | Chimora-Route im geteilten Caddy prüfen | `server/proxy_site.sh` | `/var/log/chimora-proxy.log` |
| vor jeder Migration | Sicherung `chimora-pre-migration-*.dump`; ohne Sicherung keine Migration | `server/migrate.sh` | Deploy-Log |
| alle 15 Minuten (GitHub) | Prüfung von außen: Anmeldung, `hello`, Konto löschen, Rechtsseiten, Restore-Test nicht älter als 8 Tage; nach zwei Fehlern hintereinander ein Issue mit Label `server-down`, zugewiesen an Ali (GitHub schickt eine E-Mail) | `.github/workflows/monitor.yml` | Actions |

Geplante GitHub-Workflows laufen nur auf dem Standard-Branch (`main`). Der Monitor arbeitet also erst,
wenn `main` den neuesten Stand hat (Punkt 3735).

Container-Logs: höchstens 7 Dateien zu 7 MB pro Dienst (`x-logging` in `server/docker-compose.yml`).

## Aufbewahrung der Sicherungen (Punkt 3827)

| Ort | Frist | Abgleich mit `docs/legal/DATENSCHUTZ.md` |
| --- | --- | --- |
| `/opt/chimora/server/backups/` auf dem Contabo-Rechner | 14 Tage (`backup.sh`, `find -mtime +14 -delete`) | Erklärung: "Sicherungskopien werden spätestens nach weiteren 30 Tagen überschrieben" – passt |
| zweiter Anbieter in der EU, verschlüsselt mit `age` (Punkt 3825, noch offen) | höchstens 30 Tage | passt, sobald eingerichtet; dann in `docs/legal/VVT.md` als Empfänger eintragen |

Ein gelöschtes Konto steckt also höchstens 14 Tage (später 30 Tage) in einer Sicherung. Wird eine
Sicherung zurückgespielt, muss danach `server/cleanup.sh` laufen und jede Kontolöschung seit dem Datum
der Sicherung wiederholt werden (die Liste steht im GoTrue-Audit-Log der letzten 7 Tage; ältere Löschungen
sind in einer höchstens 14 Tage alten Sicherung ohnehin nicht mehr enthalten, wenn die Sicherung jünger
als die Löschung ist).

## Server neu aufsetzen in unter 2 Stunden (Punkt 3828)

Für den Fall, dass der Contabo-Rechner weg ist oder neu installiert werden muss.

1. **Neuer Rechner (15 min):** Contabo Cloud VPS, Region Deutschland, Ubuntu 24.04. Root-Zugang in
   lifekit eintragen (Secrets wie bisher). Läuft dort auch Nyrathen, zuerst dessen Proxy aufsetzen.
2. **Sicherung holen (10 min):** die neueste `chimora-*.dump` vom alten Rechner, vom zweiten Anbieter
   (mit `age -d -i <privater Schlüssel>` entschlüsseln) oder aus Alis Offline-Kopie.
3. **Schlüssel zurück (5 min):** `/opt/chimora/server/.env` aus Alis Offline-Kopie (siehe "Geheimnisse").
   Ohne die alte `.env` entstehen ein neues JWT-Secret und ein neuer Anon-Schlüssel: Dann sind alle
   Sitzungen ungültig und jede App-Version mit dem alten Anon-Schlüssel muss neu gebaut werden.
4. **Installieren (20 min):** in lifekit `run:chimora-deploy` (oder auf dem Rechner
   `sudo SHARED_HOST=1 … bash server/setup.sh`, siehe `docs/ONLINE.md`). Das legt Docker, Container,
   Cron-Jobs und die leere Datenbank mit allen Migrationen an.
5. **Daten zurückspielen (15 min):**
   ```
   cd /opt/chimora/server
   docker compose stop auth rest
   docker compose exec -T db pg_restore -U postgres -h localhost -d postgres --clean --if-exists < backups/<datei>.dump
   bash migrate.sh            # spielt Migrationen nach, die jünger als die Sicherung sind
   docker compose start auth rest
   bash cleanup.sh
   ```
6. **Prüfen (10 min):** `bash smoke_test.sh`, `bash restore_test.sh`, Monitor-Workflow von Hand starten.
   Liegt die Adresse auf einer neuen IP, den DNS-Eintrag der eigenen Domain umstellen (sslip.io-Adressen
   hängen an der IP; alte Builds erreichen dann nur die neue Domain, deshalb Punkt 3661).

## Geheimnisse (Punkt 3829)

| Geheimnis | Wo es liegt | Offline-Kopie |
| --- | --- | --- |
| `.env` des Servers (JWT-Secret, Datenbank-Passwort, Anon-Schlüssel) | nur auf dem Server, `/opt/chimora/server/.env` (chmod 600) | **Ali:** einmal ausdrucken oder in den Passwort-Manager legen |
| Privater `age`-Schlüssel für die externen Sicherungen | nur bei Ali | **Ali:** Passwort-Manager und ein Ausdruck |
| Zugang zum Contabo-Rechner | Secrets im lifekit-Repository | Contabo-Kundenkonto |
| Signier-Schlüssel und Store-Zugänge | Secrets im lifekit-Repository (`docs/STORE_RELEASE.md`) | Ali |

Die Offline-Kopien kann nur Ali anlegen; bis dahin ist der Server ohne `.env` nur mit neuem Schlüssel
wiederherstellbar.

## Updates (Punkt 3850)

- Images sind auf Tag und Digest gepinnt (`server/docker-compose.yml`, Punkt 3849). Ein Update ist ein
  Pull Request, der Tag und Digest ändert; der Server-Workflow startet dabei den ganzen Server und spielt
  den Smoke-Test.
- **Sicherheitsupdates für Postgres, GoTrue, PostgREST und Caddy werden innerhalb von 7 Tagen nach
  Erscheinen eingespielt.** Quellen: GitHub-Releases von supabase/postgres, supabase/auth,
  PostgREST/postgrest und caddyserver/caddy.
- Das Betriebssystem spielt Sicherheitsupdates selbst ein (`unattended-upgrades`).
- Digest eines Tags nachsehen: `https://hub.docker.com/v2/repositories/<name>/tags/<tag>` (Feld `digest`).

### Update-Protokoll

| Datum | Dienst | Von | Auf | Grund |
| --- | --- | --- | --- | --- |
| 2026-11-06 | alle | Tag | Tag + Digest | Images gepinnt (Punkt 3849), Versionen unverändert |
