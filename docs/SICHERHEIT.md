# Sicherheit

Plan Bereich 9 (Punkte 3871 bis 3882). Ergänzt `docs/ONLINE.md` (Sicherheitsmodell) und `docs/BETRIEB.md`.

## Was geprüft wird

| Prüfung | Wo | Punkt |
| --- | --- | --- |
| Jede `security definer`-Funktion hat einen festen `search_path`; Hilfsfunktionen (`_…`) sind für Spieler nicht aufrufbar; nichts ist ohne Anmeldung aufrufbar; jede Spielerfunktion liest den Aufrufer über `public._uid()`, das ohne Anmeldung abbricht | `tools/online/sql_test/test_security.sql` (CI-Job `sql`) | 3872 |
| Die GoTrue-Admin-API antwortet weder dem Anon-Schlüssel noch einem Spieler-Token | `server/smoke_test.sh` (Server-Workflow) | 3877 |
| Im Spiel steckt nur der Anon-Schlüssel, nie `service_role`, JWT-Secret oder Datenbank-Passwort | `tools/release_check.py` (CI-Job `ip-check`) | 3882 |
| Sicherheits-Header (HSTS, `nosniff`, `Referrer-Policy`, `X-Frame-Options`, CSP auf den Rechtsseiten), `robots.txt`, `noindex` für `/play/` | `server/Caddyfile`, geprüft in `server/smoke_test.sh` | 3874, 3763 |

### Ergebnis der Prüfung der Server-Funktionen (6. Nov. 2026)

Alle Spielerfunktionen in `supabase/migrations/` sind `security definer` mit `set search_path = public`
(bzw. `public, auth`), prüfen den Aufrufer über `public._uid()` und geben nur eigene Daten oder die
freigegebenen Felder von bestätigten Freunden zurück (Name, Karte, Ort, Echo-Team; Fremde sehen in der
Wochen-Rangliste nur Punkte). Geprüft: `hello`, `profile_set`, `presence`, `save_list`, `save_get`,
`save_put`, `save_delete`, `delete_account`, `transfer_create`, `transfer_claim`, `friend_request`,
`friend_respond`, `friend_remove`, `friends_list`, `block`, `unblock`, `report`, `set_social`,
`mail_send`, `gift_send`, `mail_list`, `gift_open`, `mail_open`, `team_set`, `friend_team`, `echo_report`,
`community_get`, `community_add`, `community_claim`, `weekly_submit`, `weekly_board`.
Kein Fund. Neue Funktionen fallen durch `test_security.sql` auf, wenn sie eine Regel verletzen.

## JWT-Secret im Notfall wechseln (Punkt 3875)

Wann: das Secret oder die `.env` ist nach außen gelangt, oder jemand hat Tokens selbst ausgestellt.

Folge: Alle Anmelde-Tokens werden ungültig. Die Spiele melden sich beim nächsten Start neu an; das
geht nur, wenn auch der **Anon-Schlüssel** neu ist und die App ihn kennt. Weil der Anon-Schlüssel mit dem
Secret signiert ist, braucht ein Wechsel deshalb **eine neue App-Version**. Spielstände gehen nicht
verloren: Spieler holen ihr Konto mit dem Übertragungscode zurück (Einstellungen, Konto), ohne Code
nur, wenn der Support die Spieler-ID zuordnet.

Schritte auf dem Server (`/opt/chimora/server`):
1. Neues Secret: `openssl rand -hex 32`, in `.env` bei `JWT_SECRET` eintragen. In der Datenbank
   ebenfalls setzen: `docker compose exec db psql -U postgres -h localhost -c "alter database postgres set \"app.settings.jwt_secret\" to '<neu>'"`.
2. Neuen Anon-Schlüssel mit dem Secret erzeugen (dieselbe Funktion wie in `setup.sh`, Rolle `anon`)
   und in `.env` bei `ANON_KEY` eintragen; `public/chimora.json` neu schreiben lassen:
   `sudo SHARED_HOST=1 … bash setup.sh` (liest die `.env`, startet alles neu).
3. `bash smoke_test.sh` – muss mit dem neuen Schlüssel grün sein.
4. Neue App-Builds bauen und einreichen (die Builds lesen den Schlüssel aus `/chimora.json`).
5. Bis die neue Version da ist, zeigt `server_config.motd` einen Hinweis; danach `min_version` auf die
   neue Version setzen.

Getestet wird das einmal auf einem Wegwerf-Server (Server-Workflow, `LOCAL_TEST=1`), bevor es im
Ernstfall nötig ist. **Offen:** Probelauf (Punkt 3875 bleibt bis dahin offen).

## Noch offen

- **3871** SSH: eigener Deploy-Schlüssel statt Root-Passwort, Passwort-Anmeldung aus. Der Zugang liegt im
  lifekit-Repository; das wird dort umgestellt (gemeinsamer Rechner mit Nyrathen und Dranbleib).
- **3873** Konten pro IP: GoTrue begrenzt auf 10 neue Konten pro Stunde und IP (Bereich 9, PR Server-Sync).
