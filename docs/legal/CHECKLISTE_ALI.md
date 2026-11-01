# Checkliste: Was Ali selbst erledigen muss

> **Keine Rechtsberatung.** Diese Liste ordnet die Schritte, die nur du als Person/Unternehmer erledigen
> kannst. Sie ersetzt nicht das Gespräch mit Anwalt und Steuerberater. Kosten sind grobe Richtwerte.

## Phase 1: Jetzt (bevor viel Geld in Grafik, Logo und Marketing fließt)

- [ ] **Markenrecherche „Chimora“ durch einen Markenanwalt** (DPMA, EUIPO, WIPO, USPTO; Klassen 9, 41, 42,
      ggf. 28 für Merch). Besonders prüfen lassen: Ähnlichkeit zu **Chimera Entertainment GmbH** (Games-Studio
      München). Richtwert Recherche: ca. 300–800 €.
- [ ] Wenn frei: **Marke anmelden**. Unionsmarke beim EUIPO (online ab 850 € für 1 Klasse, +50 € für die
      2., +150 € ab der 3.) oder deutsche Marke beim DPMA (ab 290 € für bis zu 3 Klassen). Optional später
      USA (USPTO) per Madrid-System. Vor Anmeldung nichts groß veröffentlichen, was den Namen festlegt.
- [ ] **Domain sichern** (z. B. `chimora.de` / `.com` / `.game`) und gleichnamige Social-Media-Handles.
      Danach `package/unique_name` und `bundle_identifier` in `export_presets.cfg` auf die eigene Domain
      umstellen (lässt sich nach dem ersten Upload **nie** mehr ändern).
- [ ] **Games-Anwalt beauftragen** (IT-/Urheber-/Medienrecht, idealerweise mit Games-Erfahrung) für:
      Review von `IP_PATENT_AUDIT.md`, Datenschutzerklärung, Nutzungsbedingungen, Impressum, Store-Texte.
      Richtwert Paket für ein Indie-Spiel: ca. 1.500–4.000 €.
- [ ] **Patentanwalt** (kann über den Games-Anwalt laufen): kurze Freedom-to-Operate-Einschätzung für
      Bonding-Minispiel, Fang-/Rekrutier-Mechanik und Touch-Bedienung, besonders mit Blick auf Nintendos
      JP/US-Patente. Richtwert: ca. 1.000–3.000 € für eine fokussierte Prüfung.
- [ ] **Ergebnis im Palworld-Verfahren** um den 9. November 2026 verfolgen und mit dem Anwalt besprechen.
- [ ] Entscheiden: **Bonding-Minispiel umbauen** (Vorschlag „Echo-Melodie“ im Audit). Empfohlen.

## Phase 2: Unternehmen und Steuern

- [ ] **Gewerbe anmelden** beim Gewerbeamt deiner Stadt (ca. 20–60 €). Alternativ später UG/GmbH für
      Haftungsbeschränkung, mit Anwalt/Steuerberater abwägen (bei Online-Spiel mit Servern und Kundendaten
      sinnvoll zu überlegen).
- [ ] **Fragebogen zur steuerlichen Erfassung** beim Finanzamt (ELSTER). Kleinunternehmerregelung ja/nein
      klären. Apple und Google führen die Umsatzsteuer für EU-Verbraucherverkäufe in der Regel selbst ab,
      die Auszahlungen an dich sind trotzdem zu versteuern.
- [ ] **Steuerberater** für das erste Jahr (Store-Auszahlungen aus dem Ausland, Umsatzsteuer, Gewinnermittlung).
- [ ] **Geschäftsadresse** festlegen, die öffentlich sein darf (Impressum + DSA). Wenn nicht die
      Privatadresse: Coworking/Geschäftsadresse mit echter Postzustellung (kein Postfach).
- [ ] **Eigene E-Mail-Adressen** auf der Domain: `kontakt@`, `support@`, `privacy@`.
- [ ] Optional: **Betriebshaftpflicht/Vermögensschadenhaftpflicht** für IT/Medien (deckt z. B.
      Abmahnungen teilweise ab), Angebote vergleichen.

## Phase 3: Online-Betrieb und Datenschutz (sobald das Backend geplant wird)

- [ ] **Hoster in der EU wählen** (Serverstandort Deutschland/EU) und den **Auftragsverarbeitungsvertrag
      (AVV)** nach Art. 28 DSGVO abschließen (bei großen Hostern online im Kundenkonto).
- [ ] Login-Methode entscheiden (Empfehlung: anonymes Konto + optional „Mit Apple/Google anmelden“).
- [ ] **Verzeichnis von Verarbeitungstätigkeiten** anlegen (Art. 30 DSGVO; einfache Tabelle reicht, der
      Anwalt kann eine Vorlage geben).
- [ ] Platzhalter in `DATENSCHUTZ.md` / `PRIVACY_POLICY_EN.md` ersetzen (Hoster, Speicherfristen,
      zuständige Landesdatenschutzbehörde, Login-Dienste) und vom Anwalt freigeben lassen.
- [ ] **Website** mit Impressum, Datenschutz, Nutzungsbedingungen und Konto-Löschseite veröffentlichen.
- [ ] Im Spiel: Menü „Rechtliches“ (Links + Godot-Lizenztexte), Zustimmung zu den Nutzungsbedingungen beim
      ersten Start, „Konto löschen“ in den Einstellungen. (Kann Claude bauen, sobald das Backend steht.)

## Phase 4: Store-Konten

- [ ] **Google Play Console** (25 $ einmalig) mit Identitätsprüfung; Android-Entwicklerverifizierung
      abschließen.
- [ ] **Apple Developer Program** (99 $/Jahr). Als Einzelperson oder als Organisation (braucht D-U-N-S-Nummer,
      nur bei UG/GmbH sinnvoll).
- [ ] **DSA-Händlererklärung** in beiden Stores abgeben (Name, Adresse, Telefon, E-Mail werden in der EU
      öffentlich angezeigt). Bei Google Pflicht ab November 2026.
- [ ] **Steuer- und Bankdaten** in beiden Konsolen hinterlegen (inkl. Steuerformulare, z. B. W-8BEN bei Apple).
- [ ] **Data-Safety-Formular** und **App-Privacy-Angaben** nach `STORE_COMPLIANCE.md` ausfüllen.
- [ ] **Altersfreigabe:** IARC-Fragebogen (Google) und Apple-Fragebogen ehrlich ausfüllen.
- [ ] **Closed Test mit mind. 12 Testern über 14 Tage** (Pflicht für neue private Google-Konten), Tester
      früh suchen (Freunde, Discord, Reddit-Testergruppen).
- [ ] Signing-Secrets in GitHub (`prod`-Environment) anlegen, siehe `docs/RELEASE.md`.

## Phase 5: Laufend

- [ ] Für jede beauftragte Grafik/Musik: **schriftlicher Vertrag** mit ausschließlichem Nutzungsrecht inkl.
      Bearbeitung und kommerzieller Nutzung weltweit; Vertrag außerhalb des Repos ablegen, Eintrag in
      `docs/ASSET_LOG.md`.
- [ ] Keine Werbung, Analytics, Lootboxen oder Chat einbauen, ohne vorher Datenschutzerklärung,
      Store-Formulare und Altersfreigabe anzupassen.
- [ ] Repo **privat** halten; Formulierungen mit Bezug zum Vorbild in `AGENTS.md`/`README.md` neutralisieren.
- [ ] Vor jedem Release: `docs/IP_HYGIENE.md` Abschnitt 6 durchgehen.
- [ ] Abmahnung oder Anwaltsschreiben erhalten? **Nichts unterschreiben und nicht zahlen**, sofort zum Anwalt
      (Fristen beachten, meist 1–2 Wochen).
