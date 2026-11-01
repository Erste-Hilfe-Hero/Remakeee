# Checkliste: Was Ali selbst erledigen muss

Alles, was sich im Code und in Texten lösen ließ, ist erledigt. Diese Punkte brauchen dich als Person, weil es
um deine Identität, deine Unterschrift oder deine Konten geht. Reihenfolge = empfohlene Reihenfolge.

## Ohne Anwalt: was das bedeutet (einmal ehrlich)

Die Texte und das Audit hat eine KI erstellt. Niemand hat geprüft, ob jede Klausel vor einem deutschen Gericht
hält oder ob es ein Patent gibt, das die Websuche nicht gefunden hat. Restrisiken:
- **Abmahnung wegen eines Fehlers in Impressum, Datenschutzerklärung oder AGB.** Kosten meist einige hundert
  bis wenige tausend Euro. Wahrscheinlichkeit gering, wenn du die Platzhalter korrekt füllst und nichts
  einbaust, was nicht in den Texten steht.
- **Markenkonflikt um den Namen.** Bestenfalls Umbenennung, schlimmstenfalls Abmahnung. Darum Schritt 1
  und 2 unten vor allem anderen.
- **Patent.** Gering, weil Chimora die bekannten strittigen Mechaniken vermeidet, aber ohne
  Patentrecherche nicht ausgeschlossen.
- **Wenn ein Anwaltsschreiben kommt:** nichts unterschreiben, nichts zahlen, Frist notieren und dann doch
  einen Anwalt fragen. Eine Erstberatung kostet laut Gesetz höchstens 190 € netto für Verbraucher, bei der
  Verbraucherzentrale oft weniger.

## 1. Name absichern (vor Logo, Domain und Store-Eintrag)

- [ ] **Selbst im Register suchen** (kostenlos, 15 Minuten): [TMview](https://www.tmdn.org/tmview/) (deckt
      DPMA, EUIPO und viele Länder ab) und [WIPO Brand Database](https://branddb.wipo.int/). Suchbegriffe:
      `chimora`, `chimor*`, `chimera`, `kimora`. Filter: Klassen 9 und 41, Status „eingetragen“ oder
      „angemeldet“.
      - Kein Treffer „Chimora“ oder fast gleich in Klasse 9/41 → Name behalten.
      - Treffer → auf Plan B **„Spirlings of Veydal“** wechseln (sag Bescheid, ich stelle den Code um).
- [ ] **Marke anmelden.** Deutsche Marke beim [DPMA](https://www.dpma.de/marken/anmeldung/) (online 290 €,
      bis 3 Klassen) oder Unionsmarke beim [EUIPO](https://euipo.europa.eu/) (online 850 € für 1 Klasse,
      +50 € für die 2.). Klassen: **9** (herunterladbare Spiele/Apps) und **41** (Online-Spiele/Unterhaltung).
      Wortmarke reicht.
- [ ] **Domain** kaufen (z. B. `chimora.de` und/oder `chimora.game`) und die passenden Social-Media-Namen
      sichern.

## 2. Unternehmen

- [ ] **Gewerbe anmelden** beim Gewerbeamt deiner Stadt (online möglich, ca. 20–60 €). Tätigkeit z. B.
      „Entwicklung und Vertrieb von Computerspielen und Apps“.
- [ ] **Fragebogen zur steuerlichen Erfassung** in [ELSTER](https://www.elster.de/) ausfüllen. Bei
      erwartetem Umsatz unter 25.000 € im ersten Jahr kannst du die Kleinunternehmerregelung wählen.
      Apple und Google führen die Umsatzsteuer für Verkäufe an EU-Verbraucher in der Regel selbst ab.
- [ ] **Öffentliche Geschäftsadresse** festlegen. Sie steht im Impressum und wegen des DSA in beiden Stores.
      Wenn nicht die Wohnadresse: Geschäftsadresse mit echter Postannahme (kein Postfach).
- [ ] **E-Mail auf der eigenen Domain** (z. B. `kontakt@…`) und eine Telefonnummer, die du fürs Impressum
      nutzen willst (eine günstige zweite Nummer reicht).

## 3. Platzhalter füllen (10 Minuten)

In diesen Dateien `[NAME]`, `[ADRESSE]`, `[E-MAIL]`, `[TELEFON]`, `[DOMAIN]` (englisch `[ADDRESS]`, `[EMAIL]`,
`[PHONE]`) ersetzen: `IMPRESSUM.md`, `DATENSCHUTZ.md`, `PRIVACY_POLICY_EN.md`, `NUTZUNGSBEDINGUNGEN.md`,
`TERMS_EN.md`. Im Spiel `scripts/core/LegalInfo.gd` (Domain und E-Mail). Oder schick mir die Angaben, dann
mache ich das.

## 4. Online-Betrieb (sobald das Backend gebaut wird)

- [ ] Konto bei **Hetzner** anlegen (oder anderen Hoster in Deutschland wählen; dann sag Bescheid, der Name
      steht in der Datenschutzerklärung).
- [ ] Dort im Kundenkonto den **Auftragsverarbeitungsvertrag (AVV)** abschließen (ein Klick).
- [ ] **Website** mit vier Seiten veröffentlichen: Impressum, Datenschutz, Nutzungsbedingungen,
      Konto löschen (plus `/lizenzen`). Die Texte liegen fertig in diesem Ordner.

## 5. Store-Konten

- [ ] **Google Play Console** (25 $ einmalig) mit Identitätsprüfung.
- [ ] **Apple Developer Program** (99 $/Jahr) als Einzelperson.
- [ ] **DSA-Händlererklärung** in beiden Konsolen abgeben (Name, Adresse, Telefon, E-Mail; Google verlangt
      sie ab November 2026, ohne sie keine EU-Verfügbarkeit).
- [ ] Steuer- und Bankdaten in beiden Konsolen hinterlegen.
- [ ] **Data Safety / App Privacy / Altersfreigabe** mit den Antworten aus `STORE_COMPLIANCE.md` ausfüllen.
- [ ] **12 Tester für 14 Tage** im geschlossenen Test (Pflicht für neue private Google-Konten).
- [ ] Bundle-ID in `export_presets.cfg` auf deine Domain umstellen (z. B. `de.chimora.game`), **vor** dem
      ersten Upload; danach nie mehr änderbar. Oder sag mir die Domain.
- [ ] Signing-Secrets in GitHub anlegen (`docs/RELEASE.md`).

## 6. Laufend

- [ ] Ergebnis im Palworld-Verfahren (um den 9. 11. 2026) im Blick behalten.
- [ ] Keine Werbung, Analytics, Lootboxen, Chat oder Drittanbieter-Login einbauen, ohne vorher
      Datenschutzerklärung, Store-Formulare und Altersfreigabe anzupassen (ich mache das mit, wenn es so weit ist).
- [ ] Repo privat halten.
