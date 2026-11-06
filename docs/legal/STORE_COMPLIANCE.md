# Store-Compliance: Ausfüllhilfen für Google Play und App Store

> Erstellt von einer KI ohne anwaltliche Prüfung. Die Antworten gelten für das Modell aus
> [DATENSCHUTZ.md](DATENSCHUTZ.md): automatisches Konto mit zufälliger Spieler-ID, Übertragungscode statt
> E-Mail, Wayfarer-Name nur für dich sichtbar, eigener Server bei Contabo in Deutschland, keine Werbung, keine Analytics,
> keine Absturzberichte, kein Drittanbieter-Login, kein Chat, keine Lootboxen. Ändert sich davon etwas,
> ändern sich die Antworten. Store-Formulare ändern sich oft: im Zweifel die Hilfe in der Konsole lesen.

## 1. Google Play: Data Safety (Datensicherheit)

| Frage | Antwort |
| --- | --- |
| Erhebt oder teilt die App Nutzerdaten? | **Ja** (erheben). Teilen: **Nein** (Hoster als Auftragsverarbeiter zählt nicht als „Teilen“) |
| Daten bei der Übertragung verschlüsselt? | **Ja** (TLS) |
| Können Nutzer die Löschung ihrer Daten beantragen? | **Ja**, In-App + Web-Link `https://chimora.161-97-102-171.sslip.io/konto-loeschen` (Pflicht, wenn die App Konten anlegt) |

Erhobene Datentypen (alle: *erforderlich*, Zweck *App-Funktionen* und ggf. *Betrugsprävention/Sicherheit*,
nicht flüchtig, nicht geteilt):

| Kategorie → Typ | Wann |
| --- | --- |
| Personenbezogene Daten → **Nutzer-IDs** | **Ja** (zufällige Spieler-ID) |
| Personenbezogene Daten → **Name** | **Ja** (Wayfarer-Name; Google zählt auch Spitznamen dazu) |
| App-Aktivitäten → **Sonstige Aktionen** | **Ja** (Spielstand/Fortschritt) |
| E-Mail-Adresse, Geräte-IDs, Absturzprotokolle, Diagnose | **Nein** |
| Standort → Ungefährer Standort | **Nein** (IP-Adressen liegen nur 7 Tage in Sicherheits-Logs und werden nicht zur Standortbestimmung genutzt) |

Weitere Play-Console-Punkte:
- **Datenschutzerklärung:** öffentliche URL (kein PDF, keine Store-Seite), `https://chimora.161-97-102-171.sslip.io/datenschutz`.
- **Zielgruppe und Inhalte:** Zielgruppe **13 Jahre und älter** wählen und nicht gezielt an Kinder
  vermarkten. Falls Google das Spiel trotzdem als „für Kinder ansprechend“ einstuft: Chimora erfüllt die
  Families-Richtlinie bereits (keine Werbe-/Analytics-SDKs, keine Werbe-ID), dann einfach zustimmen.
- **Werbung:** „Enthält keine Werbung“.
- **App-Zugriff:** Weil ein Konto nötig ist, Google einen Test-Zugang oder eine Anleitung geben.
- **Konto-Löschung:** Web-Formular/Seite, die ohne Neuinstallation funktioniert, ist Pflicht.
- **Neue private Entwicklerkonten:** geschlossener Test mit mindestens **12 Testern über 14 Tage** vor der
  Produktionsfreigabe.

## 2. Apple: App Privacy („Nutrition Label“)

| Datentyp | Mit Identität verknüpft? | Tracking? | Zweck |
| --- | --- | --- | --- |
| Identifiers → **User ID** | Ja | Nein | App Functionality |
| User Content → **Gameplay Content** (Spielstand inkl. Wayfarer-Name) | Ja | Nein | App Functionality |

Alles andere (Kontaktdaten, Standort, Diagnose, Nutzungsdaten, Kaufdaten) nicht ankreuzen. Käufe wickelt Apple
ab; die Kaufbestätigung gilt nicht als von dir erhobene „Purchase History“, solange du sie nur zum
Freischalten nutzt.

- „Used for tracking“: **Nein** bei allem. Keine App-Tracking-Transparency-Abfrage nötig, solange kein
  Tracking-SDK drin ist.
- **Privacy Manifest (`PrivacyInfo.xcprivacy`):** Godot 4.7 erzeugt beim iOS-Export eines mit den
  Required-Reason-APIs der Engine (z. B. Datei-Zeitstempel, Systemstartzeit, Speicherplatz, UserDefaults).
  Nach dem ersten Export prüfen und für jedes zusätzliche SDK (Login, Crash-Reporter) dessen Manifest
  mitliefern. In App Store Connect müssen die Angaben mit dem Manifest übereinstimmen.
- **Konto-Löschung in der App** ist Pflicht, sobald man in der App ein Konto anlegen kann (Guideline 5.1.1(v)).
- **Login:** Kein Drittanbieter-Login, daher ist „Mit Apple anmelden“ nicht vorgeschrieben (Guideline 4.8
  greift erst, wenn z. B. Google-Login angeboten wird).
- **Exportkontrolle Verschlüsselung:** Nur Standard-HTTPS → `ITSAppUsesNonExemptEncryption = NO` in der
  Info.plist, dann entfällt die Frage bei jedem Upload.
- **Online-only:** In der Beschreibung klar sagen, dass eine Internetverbindung nötig ist. Apple-Prüfer
  brauchen einen funktionierenden Server und ggf. einen Demo-Zugang.

## 3. Altersfreigabe

Antworten für den aktuellen Stand (Fantasy-Kreaturen kämpfen rundenbasiert, Gegner „fallen um“, kein Blut,
keine realistischen Waffen, kein Chat, keine Käufe mit Zufall, kein Glücksspiel, Freunde nur mit festen Grüßen):

- **IARC (Google, liefert USK/PEGI/ESRB):** Gewalt: ja, *Fantasy-/Cartoon-Gewalt gegen Fantasiewesen,
  nicht realistisch, kein Blut*. Alles andere: nein. Nutzer können interagieren: **ja, eingeschränkt** (Freunde
  sehen den Wayfarer-Namen und tauschen nur feste Grüße, kein freier Chat; Melden und Blockieren vorhanden). Digitale Käufe: **nein** (kostenlos, zum Start keine In-App-Käufe; mit dem Shop auf **ja** stellen). Erwartung: **USK 6 / PEGI 7**
  (Schätzung, die Freigabe vergibt IARC).
- **Apple (Stufen 4+, 9+, 13+, 16+, 18+, neuer Fragebogen seit 31.01.2026):** Cartoon- oder Fantasy-Gewalt:
  *selten/mild* → Erwartung **9+**. In-App-Kontrollen/Fähigkeiten: kein Chat, keine nutzergenerierten Inhalte,
  kein Web-Zugriff. Medizin/Wellness: nein.
- **Achtung:** Bezahlte Zufallsinhalte (Lootboxen) führen in Deutschland zum USK-Hinweis „In-Game-Käufe +
  zufällige Objekte“ und meist zu einer höheren Freigabe; Apple verlangt dann die Anzeige der
  Wahrscheinlichkeiten. Empfehlung: keine Lootboxen.

## 4. DSA: Händlerstatus (Trader)

- Ali verkauft als Unternehmer aus Deutschland → **Trader** in beiden Stores (auch bei einem
  kostenlosen Spiel mit Käufen oder mit Gewinnabsicht). Name, Anschrift, Telefon und
  E-Mail werden auf der EU-Store-Seite öffentlich angezeigt. Das muss zu den Angaben im
  [Impressum](IMPRESSUM.md) passen (gleiche ladungsfähige Adresse).
- **Google Play:** Erklärung in der Play Console (laut Google-Mail vom 29.10.2026 Pflicht ab November 2026).
- **Apple:** Händlerstatus in App Store Connect (ohne Erklärung keine EU-Verfügbarkeit, seit Februar 2025).
- **Sobald Spieler Inhalte sehen, die andere erstellt haben** (Spielernamen in Kämpfen/Bestenlisten,
  Chat), ist Chimora selbst ein Hosting-Dienst im Sinne des DSA. Dann zusätzlich: Kontaktstelle für Nutzer
  und Behörden (Art. 11, 12), Moderationsregeln in den AGB (Art. 14), Meldeweg für rechtswidrige Inhalte
  (Art. 16) und Begründung bei Sperren (Art. 17). Seit den Online-Funktionen sehen
  Freunde Wayfarer-Namen. Umgesetzt: Meldeweg im Spiel (Freund, Melden; Tabelle `reports`), Blockieren,
  Namensfilter, nur feste Grüße, Regeln in den Nutzungsbedingungen (Abschnitt „Freunde und Grüße“).
  Ali: Kontaktstelle ist die E-Mail aus dem Impressum; Meldungen wöchentlich prüfen und bei einer
  Namens-Zurücksetzung kurz begründen (Art. 17 DSA, Vorlage in docs/ONLINE.md).

## 5. Store-Texte

Regeln (siehe auch `docs/IP_HYGIENE.md` Abschnitt 5): keine fremden Spiele- oder Markennamen im Titel, in
der Beschreibung, in Keywords, Screenshots oder Anzeigen; keine Vergleiche („wie X“, „X-Remake“).
Online-Pflicht offen nennen. Apple lehnt Metadaten mit fremden Marken oder Vergleichen ab (Guideline
2.3.7); in Deutschland wäre es zusätzlich unlautere Anlehnung (UWG).

Die fertigen Texte, Screenshots und die Feature-Grafik liegen in [`store/`](../../store/README.md)
(Deutsch und Englisch). Ablauf beim Einreichen: [docs/STORE_RELEASE.md](../STORE_RELEASE.md).

**URLs für die Konsolen** (vom Spielserver ausgeliefert, bis es eine eigene Domain gibt):
Datenschutz `https://chimora.161-97-102-171.sslip.io/datenschutz` (EN `/privacy`), Konto löschen
`/konto-loeschen` (EN `/delete-account`), Support `/support`, Impressum `/impressum`.

## 6. Sonstiges vor dem Launch

- **Barrierefreiheit (BFSG, seit 28.06.2025):** Kleinstunternehmen (unter 10 Beschäftigte, höchstens 2 Mio. €
  Umsatz) sind bei Dienstleistungen ausgenommen; Käufe laufen ohnehin über die Stores. Kein eigener Web-Shop
  ohne neue Prüfung.
- **Links im Spiel:** Einstellungen → Legal zeigt Impressum-, Datenschutz- und AGB-Links sowie den
  Godot-Lizenztext (`scripts/core/LegalInfo.gd`). Die Domain dort ersetzen, sobald die Website steht. Die
  Lizenztexte der in Godot enthaltenen Drittbibliotheken (FreeType, ENet, mbedTLS usw.) auf der Seite
  `/lizenzen` der Website veröffentlichen (Text aus `Engine.get_license_info()` oder Godots `COPYRIGHT.txt`).
- **Konto in der App:** Menü → Konto (Freundescode, Übertragungscode, Online-Regeln, Datenschutz,
  „Konto löschen“). Web-Seite zur Kontolöschung: `/konto-loeschen` auf dem Spielserver.
