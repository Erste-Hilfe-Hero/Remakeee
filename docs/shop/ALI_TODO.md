# Shop: Was nur Ali tun kann

Alles andere (Shop im Spiel, Server, Belegprüfung, Produktliste) baut Claude. Diese Schritte brauchen dein
Konto, deine Steuer- und Bankdaten oder deine Unterschrift. Reihenfolge = Wichtigkeit.

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
