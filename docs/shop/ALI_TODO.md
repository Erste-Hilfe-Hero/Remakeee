# Shop: Was nur Ali tun kann

Alles andere (Shop im Spiel, Server, Belegprüfung, Produktliste) baut Claude. Diese Schritte brauchen dein
Konto, deine Steuer- und Bankdaten oder deine Unterschrift. Reihenfolge = Wichtigkeit.

## 0. Apple: Stand 7. 11. 2026 und was nur du tun kannst

Per API erledigt (lifekit-Workflow `chimora-store.yml`, Commit `run:chimora-store-asc+iap`): Build in
TestFlight, Store-Texte und Screenshots in allen 14 Sprachen, Kategorie Rollenspiel + Abenteuer, Preis
**kostenlos**, 109 In-App-Produkte (Texte EN/DE, Euro-Preise, alle Länder außer China, Familienfreigabe
aus, Prüfbild), Altersfreigabe, Rechte an Inhalten, Hinweise für die Prüfung. Offen, weil es dein Konto,
deine Unterschrift oder Angaben braucht, die es nicht per API gibt:

1. [ ] **Vertrag „Paid Apps“, Bank und Steuer** → [Geschäftliches](https://appstoreconnect.apple.com/business)
2. [ ] **DSA-Händlerstatus** (Name, Adresse, Telefon, E-Mail wie im Impressum) → [Geschäftliches](https://appstoreconnect.apple.com/business)
3. [ ] **App-Datenschutz** (gibt es nicht per API) mit den Antworten aus `docs/legal/STORE_COMPLIANCE.md`
   Abschnitt 2: User ID, Gameplay Content, Purchase History, Other Data, alles „mit Identität verknüpft“,
   nichts „Tracking“, Zweck „App-Funktionalität“ → [App-Datenschutz](https://appstoreconnect.apple.com/apps/6831632885/distribution/privacy)
4. [ ] **Telefonnummer für die App-Prüfung** (Pflichtfeld, Format +49 …) eintragen oder mir schicken →
   [Version 1.0.0](https://appstoreconnect.apple.com/apps/6831632885/distribution/ios/version/inflight)
5. [ ] **Server-Benachrichtigungen V2** (Abschnitt 3 unten) → [App-Informationen](https://appstoreconnect.apple.com/apps/6831632885/distribution/info)
6. [ ] **Sandbox-Testkonto** → [Sandbox](https://appstoreconnect.apple.com/access/users/sandbox)
7. [ ] **Small Business Program** (15 % statt 30 %) → [Antrag](https://developer.apple.com/app-store/small-business-program/)
8. [ ] **Zur Prüfung einreichen**: auf der Versionsseite unter „In-App-Käufe und Abonnements“ die
   Produkte auswählen (erste Produkte gehen nur zusammen mit einer Version in die Prüfung), dann
   „Zur Prüfung hinzufügen“ → [Version 1.0.0](https://appstoreconnect.apple.com/apps/6831632885/distribution/ios/version/inflight)

## 1. Verträge und Zahlungsprofil (ohne das gehen keine Käufe)

- [ ] **Apple: Vertrag „Paid Apps“** annehmen und **Bankkonto + Steuerformulare** eintragen (für
      Deutschland: Steuerformular W-8BEN, USt-IdNr. falls vorhanden).
      → [App Store Connect → Geschäftliches](https://appstoreconnect.apple.com/business)
- [ ] **Google: Zahlungsprofil als Händlerkonto** anlegen bzw. verknüpfen, mit Bankkonto und Steuerangaben.
      → [Play Console → Einrichten → Zahlungsprofil](https://play.google.com/console/developers/payment-settings)

## 2. Zugänge, damit Claude die Produkte anlegen und Belege prüfen kann

Die Produktliste steht fertig in `store/products.json` (114 Produkte: Rissglas-Pakete, Vorteile, Pakete,
Aussehen, 1 Abo). Statt alles per Hand anzulegen, legt ein Skript sie an. Dafür:

- [ ] **Google:** dem vorhandenen Service-Account (Secret `PLAY_SERVICE_ACCOUNT_JSON` in lifekit) unter
      Nutzer und Berechtigungen für Chimora zusätzlich **„Store-Präsenz verwalten“**,
      **„Finanzdaten ansehen“** und **„Bestellungen und Abos verwalten“** geben.
      → [Play Console → Nutzer und Berechtigungen](https://play.google.com/console/developers/users-and-permissions)
      Danach legt der Workflow „Store products“ (`tools/store/push_products.py`) alle fertigen Produkte und
      den Pass an; sonst musst du nichts eintragen.
- [ ] **Apple:** einen **In-App-Purchase-Schlüssel** erzeugen (für die App Store Server API) und die
      .p8-Datei mit Key-ID und Issuer-ID als Secrets `APPLE_IAP_KEY_P8`, `APPLE_IAP_KEY_ID`, `APPLE_ISSUER_ID`
      in lifekit ablegen. Der vorhandene API-Schlüssel braucht die Rolle **App-Manager**, damit das Skript
      Produkte anlegen darf. (Die Belegprüfung selbst läuft schon ohne diesen Schlüssel: Apple signiert jeden
      Kauf, der Server prüft die Signatur.)
      → [App Store Connect → Benutzer und Zugriff → Integrationen → In-App-Kauf](https://appstoreconnect.apple.com/access/integrations/api/subs)
- [ ] **Google Cloud Pub/Sub** für Kauf-Benachrichtigungen: im Google-Cloud-Projekt des Service-Accounts
      die Pub/Sub-API aktivieren und dem Service-Account die Rolle „Pub/Sub-Administrator“ geben. Topic und
      Push-Adresse (`/billing/v1/google/notify` mit geheimem Schlüssel) legt Claude dann an. Bis dahin findet
      der Server Erstattungen trotzdem: er fragt Google jede Stunde danach.
      → [Google Cloud → Pub/Sub](https://console.cloud.google.com/cloudpubsub)

## 3. Formulare in den Konsolen neu beantworten

Antworten stehen in `docs/legal/STORE_COMPLIANCE.md`:

- [ ] **Altersfreigabe (IARC, Google):** „Digitale Käufe: ja“ → USK/PEGI mit Zusatz „In-Game-Käufe“.
      → Play Console → App-Inhalte → Altersfreigabe
- [ ] **Apple-Altersfragebogen:** „In-App-Käufe: ja“ (Stufe bleibt 9+). → App Store Connect → App-Informationen
- [ ] **Datensicherheit (Google):** „Finanzdaten → Kaufverlauf“ ergänzen. → Play Console → App-Inhalte
- [ ] **App-Datenschutz (Apple):** „Purchases → Purchase History“ ergänzen. → App Store Connect → App-Datenschutz
- [ ] **Apple Server-Benachrichtigungen V2:** Adresse
      `https://chimora.161-97-102-171.sslip.io/billing/v1/apple/notify` eintragen (Produktion und Sandbox).
      → App Store Connect → App → App-Informationen → App Store-Serverbenachrichtigungen

## 4. Testkonten

- [ ] Ein **Sandbox-Testkonto** (Apple) und deine Gmail-Adresse als **Lizenztester** (Google) eintragen,
      damit Testkäufe nichts kosten. Ablauf: `docs/shop/TESTPLAN.md`.

## 5. Beim Anlegen der Produkte

- [ ] Bei Apple die **Familienfreigabe** für alle Produkte **aus** lassen. Der Server ordnet jeden Kauf dem
      Konto des Käufers zu; ein geteilter Kauf bei einem Familienmitglied würde abgelehnt. Wir schalten sie
      erst ein, wenn der iOS-Kauf am Ende mit StoreKit 2 fertig ist (Plan 4073). Das Feld
      `family_shareable` in `store/products.json` steht darum auf `false`.
- [ ] Bei Apple **keine „Promoted In-App Purchases“** einschalten (Käufe sollen nur im Spiel mit Erklärung
      erscheinen, Plan 4083).
