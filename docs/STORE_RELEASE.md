# Chimora in den Stores veröffentlichen

Stand: 6. 11. 2026 (kostenlos, Hauptsprache Englisch). Diese Datei ist die Checkliste „fertig für Release“. Alles mit ✅ ist im Repo
erledigt. Alles mit 👤 braucht Ali selbst (Konto, Geld, Unterschrift, Identität). `python3
tools/release_check.py --strict` zeigt jederzeit, was noch offen ist; ohne `--strict` läuft es in jeder CI.

## 1. Was schon fertig ist

| Bereich | Stand | Wo |
| --- | --- | --- |
| Signiertes Android-**AAB** (API 36, arm64, 16-KB-Seiten geprüft) | ✅ CI-Job `android-release` bei Tag `v*` oder per Hand | `.github/workflows/export.yml`, `docs/RELEASE.md` |
| Upload in Play **interner Test** | ✅ CI-Job `android-internal` (Haken „play_internal“) | dto. |
| **iOS**-IPA + TestFlight-Upload (macOS 26, Xcode 26) | ✅ CI-Job `ios` (Haken „ios“) | dto. |
| App-ID | ✅ `de.chimora.game` (Android und iOS gleich) | `export_presets.cfg` |
| **App-Icon** (1024, 512, 192, adaptiv + Android-13-Themen-Icon) | ✅ | `art/icon/`, `tools/art/gen_icon.py` |
| iPhone-only, Verschlüsselungsfrage vorab beantwortet (`ITSAppUsesNonExemptEncryption = NO`) | ✅ | `export_presets.cfg` |
| **Store-Texte** DE + EN (Titel, Kurz-/Langbeschreibung, Untertitel, Keywords, Werbetext, Neuigkeiten) | ✅ | `store/` |
| **Screenshots** DE + EN: 6 × Play 1080 × 1920, 6 × App Store 6,9" 1320 × 2868, Feature-Grafik 1024 × 500 | ✅ | `store/`, `tools/store/make_store_images.py` |
| Hinweise für Apple-Review und Play „App-Zugriff“ | ✅ | `store/ios/review_information/notes.txt`, `store/android/app_access_de.txt` |
| **Webseiten** Datenschutz, Privacy, AGB, Impressum, Konto löschen, Support, Lizenzen | ✅ vom Spielserver ausgeliefert | `server/site/`, `tools/site/build_site.py` |
| In-App-Kontolöschung (Apple 5.1.1(v), Google Pflicht) | ✅ Menü → Konto → Konto löschen... | `scripts/ui/AccountMenu.gd` |
| Antworten für **Data Safety**, **App Privacy**, **Altersfreigabe**, DSA | ✅ | `docs/legal/STORE_COMPLIANCE.md` |
| Geschäftsmodell: kostenlos, Shop mit Rissglas und In-App-Käufen, keine Werbung, keine Lootboxen | ✅ | `docs/MONETIZATION.md`, `data/shop.json`, `store/products.json` |

Store-URLs (bis es eine eigene Domain gibt, liefert der Spielserver sie aus):

- Datenschutz: `https://chimora.161-97-102-171.sslip.io/datenschutz` (EN: `/privacy`)
- Konto löschen: `https://chimora.161-97-102-171.sslip.io/konto-loeschen` (EN: `/delete-account`)
- Support: `https://chimora.161-97-102-171.sslip.io/support`
- Impressum: `https://chimora.161-97-102-171.sslip.io/impressum`

Die Seiten gehen online, sobald dieser Stand per Workflow **Game server** auf den Server kommt.

## 2. Was Ali selbst tun muss (kurz)

1. 👤 **Name prüfen** in [TMview](https://www.tmdn.org/tmview/) („chimora“, Klassen 9 und 41). Treffer → Bescheid
   sagen, dann wird auf „Spirlings of Veydal“ umgestellt.
2. 👤 **Gewerbe anmelden** und eine **ladungsfähige Adresse**, **E-Mail** und **Telefonnummer** festlegen.
   Die vier Angaben schickst du mir; ich trage sie in Impressum, Datenschutz, AGB, Support und Spiel ein.
3. 👤 **Google Play Console** anlegen (25 $ einmalig, Identitätsprüfung), **DSA-Händlererklärung**.
   **Zahlungsprofil als Händlerkonto für In-App-Käufe** mit Steuer- und Bankdaten (nötig für den Shop).
4. 👤 **Apple Developer Program** (99 $/Jahr), **DSA-Händlerstatus**. Der Vertrag **„Paid Apps“** mit
   Steuer- und Bankdaten bleibt nötig: ohne ihn gehen keine In-App-Käufe, auch bei einer kostenlosen App.
5. 👤 **Signatur-Secrets** in GitHub → Settings → Environments → `prod` anlegen (Anleitung `docs/RELEASE.md`):
   Android-Upload-Key (3 Secrets), danach Play-Service-Account (1), Apple-Zertifikat, Profil, Team-ID und
   API-Key (7).
6. 👤 App auf **kostenlos mit In-App-Käufen** stellen (Preis 0 €, Produkte aus `store/products.json`, siehe
   `docs/shop/ALI_TODO.md`) und **12 Tester** für den geschlossenen Test auf Google Play einladen (Pflicht
   für neue private Konten, 14 Tage).
7. 👤 Contabo-**AV-Vertrag** unterschreiben (Kundenbereich).
8. 👤 **Weniger Store-Gebühr beantragen** (nur selbst möglich): bei Apple das **App Store Small Business
   Program** (15 % statt 30 % bis 1 Mio. $ Umsatz im Jahr, Antrag im Developer-Konto), bei Google die
   **15-%-Stufe** (gilt für die erste Mio. $ im Jahr, dafür in der Play Console eine Kontogruppe anlegen).
   Ohne Antrag zahlen beide Stores den vollen Satz.
9. 👤 **Testkonten für Käufe** anlegen: in der Play Console unter Einstellungen → **Lizenztests** die
   Google-Konten der Tester eintragen (ihre Käufe werden nicht berechnet), in App Store Connect unter
   Benutzer und Zugriff → **Sandbox** → Testaccounts ein Sandbox-Konto anlegen. Damit kauft die Apple-Prüfung
   und damit testest du selbst. Ohne diese Konten kostet jeder Testkauf echtes Geld.
10. 👤 In beiden Konsolen prüfen: Kategorie **Rollenspiel**, Markierung **„Enthält In-App-Käufe“** gesetzt
   (Google: App-Inhalte → In-App-Käufe; Apple erkennt das an den angelegten Produkten). Familienfreigabe bei
   Apple für die Produkte **aus** lassen (siehe `docs/shop/ALI_TODO.md`).

Die App-ID `de.chimora.game` ist ab dem ersten Upload für immer fest. Wenn du eine andere willst, sag es
vorher.

## 3. Ablauf, sobald die Konten da sind

### Google Play

1. Play Console → **App erstellen**: Name „Chimora: Die Stille von Veydal“, Standardsprache Englisch (Deutsch als Übersetzung),
   Spiel, **kostenlos**. (War als kostenpflichtig angelegt: unter Monetarisieren → App-Preis auf
   kostenlos umstellen. Achtung: von kostenlos zurück auf kostenpflichtig geht bei Google nie mehr.)
2. **App-Inhalte** ausfüllen mit `docs/legal/STORE_COMPLIANCE.md`: Datenschutz-URL, App-Zugriff
   (Text aus `store/android/app_access_de.txt`), Werbung „nein“, Altersfreigabe (IARC), Zielgruppe 13+,
   Data Safety, Konto-Löschung (URL oben), Behörden-App „nein“, Nachrichten-App „nein“.
3. **Store-Eintrag**: Texte und Bilder aus `store/android/de-DE/` und `store/android/en-US/`.
4. In GitHub den Workflow **Export** per Hand starten, Haken bei **play_internal**. Der Build landet als
   Entwurf im **internen Test**. Ersten Upload einmal per Hand bestätigen, Play App Signing aktivieren.
5. **Geschlossener Test** mit 12 Testern, 14 Tage. Danach **Produktion beantragen**, Länder wählen,
   Freigabe.

### App Store

1. App Store Connect → **Neue App**: iOS, Name „Chimora: Die Stille von Veydal“, Primärsprache Englisch (Deutsch als Lokalisierung),
   Bundle-ID `de.chimora.game` (vorher unter Certificates, Identifiers & Profiles anlegen), SKU `chimora`.
2. **App-Datenschutz** und **Altersfreigabe** mit `docs/legal/STORE_COMPLIANCE.md`. Kategorie Spiele →
   Rollenspiel, Nebenkategorie Abenteuer.
3. Texte aus `store/ios/metadata/<sprache>/`, Screenshots aus `store/ios/screenshots/<sprache>/`
   (nur die 6,9"-Größe nötig), Review-Hinweis aus `store/ios/review_information/notes.txt`.
4. Workflow **Export** per Hand starten, Haken bei **ios**. Der Build erscheint nach etwa 15 Minuten in
   **TestFlight**. Optional mit Freunden testen.
5. Build der Version zuordnen, unter Preise und Verfügbarkeit **kostenlos** (0 €) wählen, **Zur Prüfung einreichen**.

### Eine neue Version

1. `version/name` und `application/short_version` in `export_presets.cfg` erhöhen.
2. Neuigkeiten in `store/*/…/changelogs/default.txt` bzw. `release_notes.txt` schreiben. Feature-Liste und Notizen je Version: `docs/release/<version>.md`.
3. `python3 tools/release_check.py --strict` muss grün sein.
4. Tag `vX.Y.Z` pushen. Die Build-Nummer zählt CI selbst hoch (`1000 + run number`).

## 4. Vor dem ersten Einreichen noch einmal prüfen

- [ ] `release_check.py --strict` ohne offene Punkte
- [ ] Die URLs oben laden im Browser (Datenschutz, Konto löschen, Support)
- [ ] Ein frisch installierter Release-Build startet, legt ein Konto an, speichert und lädt
- [ ] Konto löschen im Spiel funktioniert
- [ ] Screenshots zeigen den aktuellen Stand (sonst `tools/store/make_store_images.py` neu laufen lassen)
- [ ] Keine fremden Marken in Texten und Bildern (`tools/ip_check.sh`)
