# Antworten auf Kauffragen (Vorlagen)

Vorlagen für E-Mails an aa.amuri@icloud.com (Plan 4053, 4084). Immer freundlich und kurz antworten, in der
Sprache der Anfrage, innerhalb von 2 Werktagen. Vor jeder Antwort zum Freundescode in der Datenbank auf
dem Server nachsehen (Tabellen `purchases`, `ledger`, `refunds`; Zugang über `psql` wie in
`docs/ONLINE.md`). Nie Zahlungsdaten erfragen.

## 1. Kauf ist nicht angekommen

> Hallo, danke für deine Nachricht. Bitte öffne den Shop noch einmal und tippe auf **Käufe
> wiederherstellen** (auf dem iPhone) bzw. öffne den Shop einfach neu (Android). Chimora holt offene Käufe
> dann nach. Unter **Meine Käufe** siehst du alle Käufe. Fehlt danach noch etwas, schick uns bitte die
> Bestellnummer aus der Kaufbestätigung von Apple oder Google, dann schreiben wir es dir gut.

Prüfen: Gibt es den Beleg in `purchases`? Nein → die Bestellnummer in der Store-Konsole suchen. Gibt es den
Kauf dort, von Hand gutschreiben (Buchung mit Grund `support` im `ledger`, Bestellnummer als `ref`).

## 2. Doppelt gekauft

> Hallo, das tut uns leid. Jeder Kauf wird nur einmal gutgeschrieben; in Meine Käufe siehst du, was
> angekommen ist. Eine Erstattung für den zweiten Kauf beantragst du direkt beim Store, nur Apple oder
> Google können Geld zurückbuchen: Apple unter reportaproblem.apple.com, Google unter play.google.com im
> Bestellverlauf. Wird erstattet, nehmen wir den zweiten Kauf im Spiel zurück.

## 3. Mein Kind hat ohne Erlaubnis gekauft

> Hallo, danke, dass Sie sich melden. Bitte beantragen Sie die Erstattung direkt beim Store (Apple:
> reportaproblem.apple.com, Google: play.google.com, Bestellverlauf, Problem melden) und geben Sie an, dass
> ein Kind ohne Erlaubnis gekauft hat. Die Stores erstatten solche Käufe in der Regel. Für die Zukunft
> können Sie Käufe im Store sperren oder freigeben lassen (Apple: Bildschirmzeit und Kaufanfrage, Google:
> Family Link). Im Spiel gelten für unter 18-Jährige feste Monatslimits, unter 13 ist der Shop gesperrt.

Prüfen: Altersgruppe des Kontos (`age_band`). Steht dort "Erwachsen", obwohl ein Kind spielt, die Zeile
des Kontos in `shop_profiles` löschen; dann fragt der Shop beim nächsten Öffnen neu nach dem Alter.

## 4. Pass kündigen

> Hallo, den Wanderer-Pass kündigst du im Store, wir können ein Store-Abo technisch nicht selbst beenden.
> iPhone: Einstellungen, dein Name, Abonnements, Chimora. Android: Google Play, Profilbild, Zahlungen und
> Abos, Abos, Chimora. Der Pass läuft bis zum Ende des bezahlten Monats, dein Rissglas bleibt.

## 5. Einen Monat Pass als Entschuldigung (Angebotscode)

Für Fälle, in denen etwas bei uns schiefgelaufen ist (Server-Ausfall, Fehler beim Gutschreiben), kann der
Support einen Monat Pass verschenken:

- **Apple:** App Store Connect → App → Abonnements → Wanderer-Pass → **Angebotscodes** → einmalige Codes für
  "1 Monat kostenlos" erzeugen (höchstens ein Code je Fall). Der Spieler löst ihn im App Store ein.
- **Google:** Play Console → Monetarisieren → **Aktionscodes** → Aktion für das Abo, 1 Monat kostenlos.
  Der Spieler löst ihn in Google Play ein.

> Hallo, entschuldige bitte den Ärger. Als Dank für deine Geduld bekommst du einen Monat Wanderer-Pass:
> Code ______, einzulösen im App Store bzw. in Google Play. Danach verlängert er sich nur, wenn du das
> willst; du kannst ihn vorher im Store kündigen.

Jeden vergebenen Code mit Datum und Freundescode in einer eigenen Liste festhalten (nicht im Repository).

## 6. Anfrage einer Verbraucherzentrale oder Behörde

Nicht mit Vorlage beantworten. Ali antwortet selbst, Ablauf in `docs/legal/SHOP_COMPLIANCE.md`.
