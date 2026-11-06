# Bereich 10: Shop und Monetarisierung

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 4001 bis 5000.

> **Auftrag für den umsetzenden Thread:** Chimora wird kostenlos in App Store und Google Play angeboten, und ein In-App-Shop mit der Premium-Währung **Rissglas** (100 Rissglas = 0,99 €) wird die Haupteinnahmequelle; zwei Drittel der Shop-Angebote geben spielerische Vorteile (P2W), ein Drittel ist Kosmetik, Komfort, Technik und Recht. Feste Preisstufen sind 0,99 €, 1,99 €, 2,99 €, 4,99 €, 9,99 €, 19,99 €, 49,99 € und 99,99 €, der Wanderer-Pass kostet 4,99 € im Monat, und jedes Angebot zeigt den Endpreis in Euro oder den Euro-Gegenwert in Rissglas. Betroffen sind ein neuer Ordner `scripts/shop/` (Katalog, Shop-Oberfläche, Billing-Brücke), `data/shop.json`, `addons/` für die Billing-Plugins, `scripts/core/GameState.gd` und `SaveManager.gd` für Rissglas-Gegenstände, ein neuer Dienst `server/billing/`, neue Migrationen in `supabase/migrations/`, `server/site/`, `store/`, `docs/MONETIZATION.md` und `docs/legal/STORE_COMPLIANCE.md`. Anfangen mit dem Neuschreiben von `docs/MONETIZATION.md`, dann Server-Tabellen und Belegprüfung, dann Billing-Plugins, dann Katalog und Oberfläche, erst danach die einzelnen Angebote. Nicht in diesen Bereich gehören die Liga selbst (Bereich 7), die frei verdiente Münz-Wirtschaft und ihre Händlerpreise (Bereich 8) und neue Spirling-Arten, Karten oder Story; Werbung, Analytics und Zufallsinhalte gegen Geld sind ausgeschlossen.

### Geschäftsmodell und Grundsatz
4001. [x] [P1] `docs/MONETIZATION.md` komplett neu schreiben: Entscheidung vom 6. 11. 2026 "kostenlos mit Shop, 2/3 der Angebote mit Vorteil", alte Premium-Entscheidung vom 1. 11. als ersetzt markieren.
4002. [x] [P1] In `docs/MONETIZATION.md` die festen Regeln als Liste festhalten: nur Store-Billing, keine Zufallsinhalte gegen Geld, Euro-Preise immer sichtbar, keine Werbung, keine Analytics, kein Kaufdruck auf Kinder.
4003. [x] [P1] Preis in beiden Store-Konsolen auf "kostenlos" planen und in `docs/STORE_RELEASE.md` Schritt 6 ("Preis 4,99 €") durch "kostenlos mit In-App-Käufen" ersetzen.
4004. [x] [P1] In `docs/STORE_RELEASE.md` Schritt 4 den Apple-Vertrag "Paid Apps" als weiter nötig für In-App-Käufe kennzeichnen und die Play-Zahlungsprofil-Zeile auf "Händlerkonto für In-App-Käufe" ändern.
4005. [x] [P1] Die Zeile "Geschäftsmodell: Einmalkauf" in der Tabelle von `docs/STORE_RELEASE.md` auf "kostenlos, Shop mit Rissglas" ändern, damit `tools/release_check.py` nicht auf alte Angaben prüft.
4006. [P2] In `docs/MONETIZATION.md` eine Tabelle aller Angebote mit Kennung, Euro-Preis, Rissglas-Preis, Art (Vorteil, Kosmetik, Komfort) und Liga-Wirkung führen, die aus `data/shop.json` erzeugt wird.
4007. [P2] Ein Skript `tools/shop/make_shop_table.py` schreiben, das die Angebotstabelle aus `data/shop.json` in `docs/MONETIZATION.md` zwischen zwei Markern neu einsetzt.
4008. [P2] In `docs/MONETIZATION.md` festhalten, dass jeder Spielinhalt auch ohne Kauf erreichbar bleibt, nur langsamer, und welche Zeit ein Spieler ohne Kauf für die Story braucht (Ziel: 25 Stunden).
4009. [P2] In `docs/MONETIZATION.md` die Umsatzziele als Planwerte notieren: Anteil zahlender Spieler 3 %, durchschnittlicher Umsatz je Zahler 12 € im Monat, nur als Rechengröße ohne Tracking.
4010. [P2] Für beide Stores das Small Business Program (Apple) und die 15-%-Stufe (Google) als Schritt in `docs/STORE_RELEASE.md` aufnehmen, mit Hinweis, dass Ali es selbst beantragen muss.
4011. [P2] In der Memory-Notiz `chimora-monetization` und in `AGENTS.md` unter Regel 4 vermerken: Billing-Plugins für Apple und Google sind freigegeben, Werbe- und Analytics-SDKs weiterhin nicht.
4012. [x] [P2] Eine Prüfung in `tools/release_check.py` ergänzen, die fehlschlägt, wenn in `addons/` ein Plugin mit den Namen bekannter Werbe- oder Analytics-SDKs liegt.
4013. [P3] In `docs/MONETIZATION.md` einen Abschnitt "Was nie verkauft wird" führen: Story-Kapitel, Karten, Rift-Zugang, Konto-Funktionen, Freunde, Geschenke an Freunde.
4014. [P3] Im Titelbildschirm und in den Store-Texten keine Formulierung "gratis spielen, alles freischalten" verwenden, sondern "kostenlos spielbar, optionale In-App-Käufe".
4015. [P3] Einen jährlichen Prüftermin (jeweils 1. November) in `docs/MONETIZATION.md` eintragen, an dem Preise, Rechtslage und Angebote neu bewertet werden.
4016. [P3] In `docs/MONETIZATION.md` eine Regel aufnehmen, dass kein Angebot nachträglich abgeschwächt wird, ohne Käufern einen gleichwertigen Ersatz zu geben.
4017. [P3] In `docs/MONETIZATION.md` festhalten, dass ein späterer Wechsel zurück zum Bezahlmodell auf Google Play technisch nicht möglich ist, weil kostenlose Apps dort nicht kostenpflichtig werden dürfen.
4018. [P3] Eine Änderungsliste `docs/shop/CHANGELOG.md` anlegen, in der jede Preis- oder Angebotsänderung mit Datum steht.
4019. [P3] In `docs/MONETIZATION.md` eine Abschaltregel festhalten: wird der Server eingestellt, bekommen Spieler 60 Tage vorher Bescheid, und der Shop schließt zuerst.
4020. [P3] Die Alt-Tabelle "Items 80 bis 86" in `docs/MONETIZATION.md` durch eine neue Tabelle mit dem Stand jedes Unterbereichs dieses Plans ersetzen.

### Rechtsrahmen DE/EU und Jugendschutz
4021. [x] [P1] Kein Angebot enthält Zufallsinhalte: Jeder Kauf liefert genau die im Angebot genannten Gegenstände und Mengen, und ein Test in `tests/test_shop_catalog.gd` prüft, dass `data/shop.json` kein Feld für Zufall, Ziehung oder Chancen kennt.
4022. [x] [P1] Kein Angebot spricht Kinder direkt mit Kaufaufforderungen an (UWG Anhang Nr. 28): verboten sind Texte wie "Kauf jetzt", "Hol dir", "Sichere dir"; erlaubt sind neutrale Beschriftungen wie "Preis: 2,99 €".
4023. [x] [P1] Eine Wortliste `data/shop_banned_phrases.json` mit verbotenen Aufforderungen (DE und EN) anlegen und in `tools/ip_check.sh` gegen `data/shop.json` und `data/i18n/` prüfen lassen.
4024. [x] [P1] Jeder Preis wird als Endpreis inklusive Umsatzsteuer in Euro angezeigt, wie ihn der Store liefert, und nie selbst umgerechnet oder gerundet.
4025. [x] [P1] Vor dem ersten Kauf einen Hinweis zum Widerrufsrecht zeigen: digitale Inhalte werden sofort bereitgestellt, das Widerrufsrecht erlischt mit ausdrücklicher Zustimmung, Erstattungen laufen über Apple oder Google.
4026. [x] [P1] Die Nutzungsbedingungen `server/site/nutzungsbedingungen.html` und `terms.html` um einen Abschnitt "Käufe im Spiel" ergänzen: Vertragspartner, Rissglas als Nutzungsrecht ohne Geldwert, kein Rücktausch, Verfall nur bei Kontolöschung.
4027. [x] [P1] Keine künstlichen Countdowns: Angebote mit Ende zeigen nur ein festes Enddatum, und ein abgelaufenes Angebot kommt nicht mit neuer Uhr sofort zurück.
4028. [x] [P1] Kein Angebot wird mitten im Kampf, nach einer Niederlage oder während des Bondens als Fenster eingeblendet; der Shop öffnet sich nur, wenn der Spieler ihn selbst aufruft.
4029. [x] [P1] Die Leitlinien des EU-Netzwerks der Verbraucherschutzbehörden (CPC) zu virtueller Währung als Prüfliste in `docs/legal/SHOP_COMPLIANCE.md` abbilden und jeden Punkt einer Datei im Code zuordnen.
4030. [P2] In `docs/legal/SHOP_COMPLIANCE.md` die Rechtslage zu bezahlten Zufallsinhalten in Belgien und den Niederlanden festhalten und begründen, warum Chimora keine anbietet.
4031. [P2] In `docs/legal/SHOP_COMPLIANCE.md` die Pflichten aus dem Jugendschutzgesetz (§ 10b, Kostenfallen als Risiko) und die USK-Hinweise "In-Game-Käufe" und "In-Game-Käufe + zufällige Objekte" erklären.
4032. [P2] Die Datenschutzerklärung `server/site/datenschutz.html` und `privacy.html` um Kaufdaten ergänzen: Transaktionskennung, Produkt, Zeitpunkt, Store, Erstattungsstatus, Rechtsgrundlage Vertragserfüllung, Speicherdauer 10 Jahre nach Handelsrecht.
4033. [P2] Im Impressum und in den Nutzungsbedingungen eine Kontaktadresse für Kauffragen nennen und darauf hinweisen, dass Erstattungen nur Apple oder Google entscheiden.
4034. [P2] Den Text "Rissglas hat keinen Geldwert und kann nicht in Euro zurückgetauscht oder übertragen werden" im Shop unter jedem Rissglas-Paket in einer Zeile zeigen.
4035. [P2] Gegenüber Spielern immer "Angebot" oder "Paket" schreiben, nie "Geschenk", wenn etwas Geld kostet, damit nichts als kostenlos erscheint.
4036. [P2] Ein Hinweis "kostenlos spielbar, enthält In-App-Käufe" steht im Titelbildschirm unter dem Logo in kleiner Schrift, damit es vor dem Spielstart klar ist.
4037. [P2] "Vorher/Nachher-Preise" (durchgestrichene Preise) nur zeigen, wenn das Angebot vorher mindestens 30 Tage zum höheren Preis verkauft wurde (Preisangabenverordnung § 11), und das Datum in `data/shop.json` speichern.
4038. [P2] In der Shop-Oberfläche steht bei Angeboten mit Vorteil eine kleine Marke "Vorteil im Spiel", damit Eltern und Spieler sehen, was spielerisch wirkt.
4039. [P2] Die Tageslimits für Käufe und die Altersstufen aus dem Bereich "Ausgabelimits" in den Nutzungsbedingungen beschreiben.
4040. [P2] Für den Pass in den Nutzungsbedingungen die Laufzeit, die automatische Verlängerung, die Kündigung im Store und den Kündigungsbutton-Hinweis (§ 312k BGB gilt über den Store) beschreiben.
4041. [P2] Keine "Mitspieler haben gekauft"-Meldungen und keine Rangliste nach Ausgaben anzeigen, damit kein sozialer Kaufdruck entsteht.
4042. [P2] Kein Angebot nutzt Verknappung mit Stückzahlen wie "nur noch 3"; Mengengrenzen pro Konto sind erlaubt und werden als "einmal pro Konto" beschrieben.
4043. [P2] Bei jedem Paket die Inhalte vollständig als Liste zeigen, nie nur ein Bild, und den Gegenwert der Einzelteile in Rissglas daneben nennen.
4044. [P2] Eine Seite `server/site/kaeufe.html` und `purchases.html` bauen, die Rissglas, Preise, Pass, Erstattung und Ausgabelimits einfach erklärt, und in `tools/site/build_site.py` und im `Caddyfile` eintragen.
4045. [P2] In der Shop-Oberfläche einen Link "Hilfe zu Käufen" auf `/kaeufe` setzen.
4046. [P2] Für Spieler unter 18 alle Pass-Verlängerungen nur mit Store-Elternfreigabe zulassen und das in `docs/legal/SHOP_COMPLIANCE.md` als Regel festhalten.
4047. [P2] Den Zeitpunkt der Annahme der neuen Nutzungsbedingungen in `profiles` speichern (`terms_version`, `terms_accepted_at`) und vor dem ersten Kauf erneut abfragen, wenn die Version neuer ist.
4048. [P2] In `docs/legal/SHOP_COMPLIANCE.md` die Apple-Richtlinien 3.1.1 (Käufe), 3.1.2 (Abos) und 5.1.1(v) (Kontolöschung mit Abo) mit Umsetzungsort verlinken.
4049. [P3] In `docs/legal/SHOP_COMPLIANCE.md` die Google-Richtlinien zu Zahlungen, Abos und Familien zusammenfassen und vermerken, dass die Zielgruppe "13 und älter" bleibt.
4050. [P3] Den Digital Services Act prüfen: Händlerangaben im Store bleiben aktuell, ein Meldeweg für irreführende Angebote führt zur Support-Adresse.
4051. [P3] Einen jährlichen Rechtscheck mit Datum in `docs/legal/SHOP_COMPLIANCE.md` eintragen und dabei den Stand des geplanten EU-Gesetzes zur digitalen Fairness nachtragen.
4052. [P3] Die Texte aller Shop-Angebote in einfacher Sprache halten: höchstens 2 Sätze, keine Fachwörter, und ein Test zählt die Satzlänge (höchstens 18 Wörter).
4053. [P3] Eine Vorlage für Antworten auf Kaufbeschwerden in `docs/shop/SUPPORT_ANTWORTEN.md` schreiben (fehlender Kauf, doppelter Kauf, Kind hat gekauft, Pass kündigen).
4054. [P3] Bei Angeboten mit Ende das Enddatum in Ortszeit Deutschland anzeigen und in den Angebotsdaten als UTC speichern.
4055. [P3] Jede Preisänderung mindestens 7 Tage vorher in den Neuigkeiten des Spiels ankündigen, wenn ein Angebot teurer wird.
4056. [P3] Für die Schweiz und Österreich prüfen, ob abweichende Preisangaben nötig sind, und das Ergebnis in `docs/legal/SHOP_COMPLIANCE.md` notieren.
4057. [P3] Einen Rechtsabschnitt zur Übertragung des Kontos per Transfercode ergänzen: Käufe wandern mit, Verkauf von Konten ist untersagt.
4058. [P3] Ein Verbot des Kontohandels in die Nutzungsbedingungen schreiben und die Melden-Funktion um den Grund "Kontohandel" ergänzen.
4059. [P3] Die englischen Shop-Texte auf die gleichen Regeln prüfen (keine "Buy now", "Get it now" gegenüber Kindern) und die Wortliste dafür nutzen.
4060. [P3] In `docs/legal/SHOP_COMPLIANCE.md` festhalten, wie bei einer Anfrage einer Verbraucherzentrale reagiert wird: Antwortfrist 14 Tage, Ansprechpartner Ali.

### Store-Einrichtung, Altersfreigabe und Datenschutz-Angaben
4061. [x] [P1] In `docs/legal/STORE_COMPLIANCE.md` die IARC-Antwort "Digitale Käufe" von "nein" auf "ja" ändern und die erwartete Freigabe mit Zusatz "In-Game-Käufe" neu eintragen.
4062. [x] [P1] Den Apple-Altersfragebogen in `docs/legal/STORE_COMPLIANCE.md` um "In-App-Käufe: ja" ergänzen und die Zielstufe 9+ begründen.
4063. [x] [P1] Die Data-Safety-Antwort bei Google um "Finanzdaten: Kaufverlauf, erhoben, nicht geteilt, für App-Funktionen" ergänzen, weil der Server Transaktionen speichert.
4064. [x] [P1] Das Apple-Datenschutzlabel um "Käufe, mit Identität verknüpft, App-Funktionalität, kein Tracking" ergänzen.
4065. [x] [P1] Alle Produkte mit festen Produkt-IDs nach dem Muster `de.chimora.game.<art>.<name>` in einer Liste `store/products.json` anlegen, aus der beide Konsolen befüllt werden.
4066. [P1] In App Store Connect und der Play Console Verbrauchsgüter (Rissglas-Pakete, Einzelteile), Nicht-Verbrauchsgüter (Team-Platz, Lager, Kosmetik) und ein Auto-Abo (Wanderer-Pass) anlegen und die Typen in `store/products.json` vermerken.
4067. [x] [P1] Ein Skript `tools/store/push_products.py` schreiben, das `store/products.json` über die Play Developer API (`monetization.onetimeproducts`, `monetization.subscriptions`) anlegt und aktualisiert.
4068. [P2] Für Apple die Produkte über die App Store Connect API (`inAppPurchasesV2`, `subscriptionGroups`) mit demselben Skript anlegen, gesteuert durch den Schalter `--apple`.
4069. [P2] Für jedes Produkt einen deutschen und einen englischen Anzeigenamen und eine Beschreibung in `store/products.json` pflegen, die exakt den Texten im Spiel entsprechen.
4070. [P2] Für Apple pro In-App-Kauf einen Prüf-Screenshot (Shop-Ansicht des Produkts, 1320 x 2868) mit `tools/store/make_store_images.py` erzeugen.
4071. [P2] Die Store-Beschreibungen in `store/android/*/full_description.txt` und `store/ios/metadata/*/description.txt` um einen Absatz "Kostenlos spielbar. Optionale Käufe im Spiel, auch mit Vorteilen. Keine Zufallsinhalte." ergänzen.
4072. [P2] Die Screenshots im Store um ein Bild der Shop-Ansicht mit sichtbaren Euro-Preisen ergänzen, damit niemand einen Gratis-Eindruck ohne Käufe bekommt.
4073. [P2] Apple Familienfreigabe für Nicht-Verbrauchsgüter und den Pass aktivieren und das Feld `family_shareable` in `store/products.json` setzen.
4074. [P2] Die Hinweise für die Apple-Prüfung in `store/ios/review_information/notes.txt` um eine Anleitung ergänzen: Shop öffnen, Testkauf, Wiederherstellen, Ausgabelimit.
4075. [P2] Den Play-Text `store/android/app_access_de.txt` um den Weg zum Shop und den Hinweis auf Lizenztester ergänzen.
4076. [P2] Lizenztester in der Play Console und Testkonten für Käufe in App Store Connect in `docs/STORE_RELEASE.md` als Schritt für Ali eintragen.
4077. [P2] In `tools/release_check.py` prüfen, dass jede Produkt-ID aus `data/shop.json` in `store/products.json` vorkommt und umgekehrt.
4078. [P2] In `tools/release_check.py` prüfen, dass jedes Produkt einen Preis aus der festen Preisliste (0,99 € bis 99,99 €) hat.
4079. [P2] Die Neuigkeiten-Texte (`changelogs/default.txt`, `release_notes.txt`) für die erste Version mit Shop um den Satz "Neu: Shop mit Rissglas, alle Preise in Euro" ergänzen.
4080. [P2] Die Kategorie in den Konsolen auf "Rollenspiel" lassen und die Markierung "enthält In-App-Käufe" in beiden Konsolen prüfen.
4081. [P3] In der Play Console die Länderpreise automatisch aus dem Euro-Preis ableiten und für die Eurozone feste Preise mit ",99" setzen.
4082. [P3] In App Store Connect als Basisland Deutschland wählen, damit die Euro-Preise fest bleiben und andere Länder umgerechnet werden.
4083. [P3] Für Apple "Promoted In-App Purchases" nicht verwenden, damit keine Käufe außerhalb des Spiels ohne Kontext beworben werden.
4084. [P3] Einen Abo-Angebotscode (Apple Offer Codes, Google Promo Codes) für 1 Monat Pass als Support-Werkzeug in `docs/shop/SUPPORT_ANTWORTEN.md` beschreiben.
4085. [P3] Das Abo-Gruppen-Bild und den Abo-Anzeigenamen in App Store Connect mit eigenem Pixel-Bild aus `art/shop/` füllen.
4086. [P3] Für Google die Abo-Grundpläne "monatlich" und "jährlich (39,99 €)" anlegen und den Jahresplan erst in der zweiten Version freigeben.
4087. [P3] Einen Test-Track "shop-beta" in der Play Console für Shop-Änderungen vor der Produktion anlegen.
4088. [P3] In `store/README.md` beschreiben, wie neue Produkte angelegt, geprüft und freigegeben werden.
4089. [P3] Die Store-Stichwörter um "kostenlos" und "free" ergänzen und dabei keine Namen anderer Spiele verwenden.
4090. [P3] Einen jährlichen Abgleich der Länderpreise nach Wechselkursänderungen der Stores als Termin in `docs/shop/CHANGELOG.md` eintragen.

### Billing-Technik im Spiel (Godot)
4091. [x] [P1] (Umgesetzt als eigenes Plugin `plugins/chimora_billing`, siehe `addons/BILLING_VERSIONS.md`.) Das offizielle Godot-Plugin für Google Play Billing (Billing Library ab Version 8) in `addons/` einbinden und in `export_presets.cfg` für Android aktivieren.
4092. [P1] Für iOS ein StoreKit-2-Plugin für Godot 4.7 einbinden, das signierte Transaktionen (JWS) liefert, und die Version in `docs/RELEASE.md` festhalten.
4093. [x] [P1] Eine Klasse `scripts/shop/Billing.gd` als Autoload schreiben, die beide Plugins hinter einer gemeinsamen Schnittstelle versteckt (`query_products`, `purchase`, `restore`, `finish`).
4094. [x] [P1] Eine Klasse `scripts/shop/LocalBilling.gd` für Desktop, Web und Tests schreiben, die Käufe nur mit dem lokalen Testserver vortäuscht und in Release-Builds nie aktiv ist.
4095. [x] [P1] Preise im Shop nur aus der Store-Antwort (`ProductDetails.oneTimePurchaseOfferDetails.formattedPrice`, `Product.displayPrice`) anzeigen, nie aus `data/shop.json`.
4096. [x] [P1] Jeder Kauf schickt den Beleg (Google `purchaseToken`, Apple JWS-Transaktion) an den Server und schreibt Inhalte erst nach dessen Bestätigung gut.
4097. [x] [P1] Erst nach der Gutschrift auf dem Server den Kauf beim Store abschließen (Google `acknowledge` oder `consume`, Apple `transaction.finish()`), damit kein Kauf verloren geht.
4098. [x] [P1] Beim Start und nach jedem Wiederverbinden offene Käufe (Google `queryPurchasesAsync`, Apple `Transaction.unfinished`) abfragen und an den Server nachreichen.
4099. [x] [P1] Den Kaufablauf als Zustandsmaschine in `Billing.gd` bauen: Bereit, Abfrage, Kauf läuft, Prüfung, Gutgeschrieben, Fehler, Abgebrochen.
4100. [x] [P2] Für ausstehende Käufe (Google `PENDING`, Apple "Ask to Buy") einen Text "Kauf wartet auf Freigabe" zeigen und nichts gutschreiben, bis der Status wechselt.
4101. [x] [P2] Eine Konto-Kennung als `obfuscatedAccountId` (Google) und `appAccountToken` (Apple, UUID aus der Konto-ID) mitschicken, damit der Server Käufe dem richtigen Konto zuordnet.
4102. [P2] Den Button "Käufe wiederherstellen" in `scripts/ui/AccountMenu.gd` und im Shop einbauen, der `restore` aufruft und das Ergebnis in einem Satz meldet.
4103. [x] [P2] Fehlercodes beider Stores auf 8 eigene Meldungen abbilden (abgebrochen, nicht verfügbar, schon gekauft, Netz fehlt, Zahlung abgelehnt, Store-Fehler, ausstehend, unbekannt).
4104. [P2] Ohne Serververbindung den Kauf-Button sperren und "Shop braucht eine Verbindung" anzeigen, damit kein Kauf ohne Prüfung startet.
4105. [P2] Produktdaten nach dem Laden 6 Stunden zwischenspeichern und bei Sprach- oder Landwechsel neu laden.
4106. [x] [P2] Bei doppeltem Tippen auf "Kaufen" nur einen Kauf starten und den Button bis zum Ende des Vorgangs sperren.
4107. [x] [P2] Den Android-Export auf die Berechtigung `com.android.vending.BILLING` prüfen und in `tools/release_check.py` sicherstellen, dass keine weiteren neuen Berechtigungen dazukommen.
4108. [P2] Die 16-KB-Seitengrößen-Prüfung in der CI auch für die nativen Teile der Billing-Plugins laufen lassen.
4109. [P2] Beim iOS-Build die StoreKit-Funktion "In-App Purchase" im Export-Preset setzen und in der CI prüfen.
4110. [P2] Eine StoreKit-Konfigurationsdatei `ios/Chimora.storekit` mit allen Produkten für lokale Tests in Xcode erstellen.
4111. [P2] Im Web-Build und in der Browser-Testversion unter `/play` den Shop ausblenden und nur "Shop nur in der App" anzeigen.
4112. [P2] Den Pass-Status beim Start vom Server lesen und nicht aus dem Store-Cache, damit gekündigte oder erstattete Pässe sofort enden.
4113. [P2] Signale `purchase_done`, `purchase_failed`, `wallet_changed` und `entitlements_changed` in `Billing.gd` anbieten, auf die Shop und Menüs hören.
4114. [P3] Kaufvorgänge in einer lokalen Warteschlange `user://billing_queue.json` speichern, damit ein Absturz während der Prüfung den Kauf nicht vergisst.
4115. [x] [P3] Für Google das Feld `isAcknowledged` beim Start prüfen und nicht bestätigte Käufe vor Ablauf der 3-Tage-Frist erneut an den Server geben.
4116. [P3] Für Apple die Funktion `AppStore.showManageSubscriptions` und für Google den Abo-Link `play.google.com/store/account/subscriptions` als Button "Pass verwalten" anbieten.
4117. [P3] Für Apple die Erstattungsanfrage `beginRefundRequest` als Button "Erstattung beantragen" in der Kaufliste anbieten.
4118. [P3] Einen Unit-Test-Satz `tests/test_billing.gd` mit `LocalBilling.gd` schreiben, der Kauf, Abbruch, ausstehend, Wiederherstellen und Doppelkauf abdeckt.
4119. [x] [P3] Die Billing-Plugin-Versionen in `addons/` in einer Datei `addons/BILLING_VERSIONS.md` mit Prüfdatum festhalten.
4120. [P3] Bei Store-Ausfall die Produkte im Shop grau zeigen mit dem Satz "Store gerade nicht erreichbar" statt leerer Listen.
4121. [P3] Den Kauf-Dialog des Stores nie mit eigenen Fenstern überdecken und vor dem Aufruf das Spiel pausieren.
4122. [P3] Eine Debug-Ansicht nur in Debug-Builds anlegen, die alle Produkte, Belege und Serverantworten auflistet.
4123. [P3] Die Billing-Schnittstelle so halten, dass ein späterer Wechsel des iOS-Plugins nur `Billing.gd` betrifft.
4124. [P3] Für Google Play die Funktion "Produkt-Details für mehrere Kaufoptionen" nicht nutzen, damit jedes Produkt genau einen Preis hat.
4125. [P3] Kauf-Abbrüche nur lokal zählen und nie an den Server senden, damit kein Nutzungsprofil entsteht.

### Server: Belege, Konto-Guthaben, Erstattungen
4126. [x] [P1] Einen neuen Dienst `server/billing/` (Python 3.13, ohne fremde Analytics) bauen, in `server/docker-compose.yml` eintragen und im `Caddyfile` unter `/billing/v1/*` erreichbar machen.
4127. [x] [P1] Eine Migration `supabase/migrations/20261110000020_shop.sql` mit den Tabellen `wallets`, `ledger`, `purchases`, `entitlements`, `subscriptions`, `spend_limits` und `refunds` anlegen, alle mit Zeilen-Zugriffsschutz (RLS) ohne Policies, wie die vorhandenen Tabellen. Zusätzlich `shop_offers`, `shop_profiles` und `deliveries`.
4128. [x] [P1] Die Tabelle `purchases` bekommt eine eindeutige Spalte `store_transaction_id` (Apple `transactionId`, Google `orderId`), damit kein Beleg zweimal gutgeschrieben wird. Umgesetzt mit Google `purchaseToken` statt `orderId` (auch Erstattungsmeldungen tragen ihn) und beim Pass mit der ursprünglichen Transaktion.
4129. [x] [P1] Apple-Belege mit der App Store Server API prüfen: JWS-Signatur gegen die Apple-Zertifikatskette, `bundleId` gleich `de.chimora.game`, `appAccountToken` passt zum Konto. Umgesetzt ohne Aufruf bei Apple: die Kette im JWS endet in Apple Root CA G3 (SHA-256 fest im Code); der App-Store-Server-API-Schlüssel ist nur für spätere Abfragen nötig.
4130. [x] [P1] Google-Belege mit der Play Developer API `purchases.products.get` und `purchases.subscriptionsv2.get` prüfen und `obfuscatedExternalAccountId` mit dem Konto vergleichen.
4131. [x] [P1] Das Rissglas-Guthaben liegt nur auf dem Server in `wallets.balance`; Spielstände enthalten keinen Kontostand, und `SaveManager.gd` liest ihn nie aus dem Spielstand.
4132. [x] [P1] Jede Gutschrift und jede Ausgabe wird als Zeile in `ledger` geschrieben (Konto, Betrag, Grund, Bezug, Zeit), und `wallets.balance` ist immer die Summe dieser Zeilen.
4133. [x] [P1] Eine RPC-Funktion `shop_buy(offer_id, expected_price)` anlegen, die Preis, Guthaben, Limit und Kontostatus in einer Transaktion prüft und den Gegenstand als Berechtigung gutschreibt.
4134. [x] [P1] Apple App Store Server Notifications V2 unter `/billing/v1/apple/notify` empfangen und `REFUND`, `REVOKE`, `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW` verarbeiten.
4135. [x] [P1] Google Real-time Developer Notifications über Pub/Sub-Push unter `/billing/v1/google/notify` empfangen und Abo-Ereignisse sowie `voidedPurchaseNotification` verarbeiten.
4136. [x] [P1] Zusätzlich täglich die Google Voided Purchases API abfragen, um Rückbuchungen zu finden, die keine Benachrichtigung ausgelöst haben. Umgesetzt: stündlich, letzte 3 Tage.
4137. [P2] Bei einer Erstattung von Rissglas den Betrag vom Guthaben abziehen; reicht es nicht, wird das Guthaben negativ und der Shop für dieses Konto bis zum Ausgleich gesperrt.
4138. [P2] Bei der Erstattung eines Einzelangebots den Gegenstand entfernen, wenn er noch ungenutzt ist, und schon verbrauchte Wirkungen nicht rückgängig machen.
4139. [P2] Bei einer Rückbuchung (Chargeback) zusätzlich einen Zähler `profiles.chargebacks` erhöhen und ab 3 Rückbuchungen den Shop für das Konto sperren, ohne das Spiel zu sperren.
4140. [P2] Eine Tabelle `granted_items` führen, die jede gekaufte Gegenstandsmenge pro Konto zählt, und beim Speichern prüfen, dass der Spielstand nicht mehr Shop-Gegenstände enthält als gekauft und erspielt.
4141. [P2] Die Speicherprüfung in der Funktion für `saves` so erweitern, dass Shop-Gegenstände mit Kennung `rg_*` gegen `granted_items` abgeglichen und Überschüsse abgelehnt werden.
4142. [P2] Für den Pass in `subscriptions` Status, Ablaufdatum, Verlängerungsstatus, Store und ursprüngliche Transaktion speichern und Ablauf mit Toleranz von 16 Tagen (Google Kulanzzeit) behandeln.
4143. [P2] Wiederherstellen auf dem Server: Ein Beleg, der schon einem anderen Konto gehört, wird nicht doppelt vergeben, sondern nur dem ursprünglichen Konto erneut bestätigt.
4144. [P2] Wird ein Konto per Transfercode auf ein neues Gerät gebracht, bleiben `wallets`, `entitlements` und `subscriptions` am Konto, nicht am Gerät.
4145. [P2] Bei Kontolöschung offene Pässe nicht kündigen können: vor dem Löschen einen Hinweis zeigen, wie man das Abo im Store kündigt (Apple 5.1.1(v)), und Kaufdaten wegen Aufbewahrungspflicht pseudonymisiert behalten.
4146. [P2] Die Kontolöschung in `scripts/ui/AccountMenu.gd` um den Hinweis "Restliches Rissglas und gekaufte Inhalte gehen verloren" ergänzen.
4147. [P2] Alle Store-Zugangsdaten (Apple-Schlüssel `.p8`, Google-Service-Account) nur als Docker-Secrets auf dem Server ablegen und nie ins Repo schreiben.
4148. [P2] Eine Ratenbegrenzung für `shop_buy` (höchstens 30 Käufe pro Stunde) und für Belegprüfungen (höchstens 20 pro Stunde) über die vorhandene Tabelle `rate_events` setzen.
4149. [P2] Jede RPC-Antwort des Shops enthält das neue Guthaben und die Berechtigungen, damit der Client nie selbst rechnet.
4150. [P2] Eine RPC-Funktion `shop_state()` liefert Guthaben, Berechtigungen, Pass-Status, Ausgabelimit und Restbetrag in einem Aufruf.
4151. [P2] Eine RPC-Funktion `shop_history(limit)` liefert die letzten 50 Käufe mit Datum, Produkt und Euro-Preis für die Kaufliste im Spiel.
4152. [P2] Die Serverzeit für Angebotsende und Pass-Ablauf nutzen, nie die Gerätezeit.
4153. [P2] Den Rissglas-Verbrauch und die Gutschrift so in einer Datenbank-Transaktion bündeln, dass bei Verbindungsabbruch nichts doppelt oder gar nicht passiert (Idempotenzschlüssel pro Kauf).
4154. [P2] Den Smoke-Test `server/smoke_test.sh` um Belegprüfung mit Test-Belegen, `shop_buy`, Erstattung und `shop_state` erweitern.
4155. [P2] Die Sicherung `server/backup.sh` auf die neuen Tabellen prüfen und die Kaufdaten verschlüsselt in die Nachtsicherung aufnehmen.
4156. [P2] Bei Erstattung eines Kosmetik-Teils das Teil abnehmen und auf das Standard-Aussehen zurückstellen.
4157. [P2] Bei Erstattung eines dauerhaften Platzes (Team-Platz, Lager) die Plätze sperren, aber keine Spirlings löschen; sie bleiben sichtbar und lassen sich nur herausnehmen.
4158. [P2] Bei der Pass-Verlängerung die Tagesgutschrift nur für bezahlte Tage geben und in Kulanzzeit keine neuen Vorteile freischalten.
4159. [P2] Neue Fehlercodes `shop_limit`, `shop_locked`, `price_changed`, `receipt_invalid`, `receipt_used` in `OnlineBackend.gd` und `Online.gd` ergänzen.
4160. [P3] Den lokalen Testserver `scripts/online/LocalBackend.gd` um Wallet, `shop_buy`, `shop_state` und Test-Belege erweitern, damit Tests ohne echten Server laufen.
4161. [P3] Die Belegprüfung erkennt Test-Belege der Stores und schreibt sie nur auf Testkonten gut (`profiles.is_tester`).
4162. [P3] Eine Admin-Abfrage `server/billing/admin.py` schreiben, die für ein Konto alle Käufe, Erstattungen und Ledger-Zeilen ausgibt, nur per SSH nutzbar.
4163. [P3] Eine Support-Gutschrift `ledger.reason = 'support'` mit Pflichtbegründung einführen, die nur über die Admin-Abfrage möglich ist.
4164. [P3] Einen Tagesbericht ohne Personenbezug (Summe Käufe, Erstattungen, Rückbuchungen pro Produkt) auf dem Server erzeugen, den nur Ali per SSH liest.
4165. [P3] Monatlich prüfen, dass die Summe aller Ledger-Zeilen jedes Kontos gleich `wallets.balance` ist, und Abweichungen in eine Fehlerliste schreiben.
4166. [P3] Für die Apple-Benachrichtigungen einen Wiederholungsabruf über `Get Notification History` einbauen, falls der Server nicht erreichbar war.
4167. [P3] Die Kaufdaten nach 10 Jahren automatisch löschen und das in einem nächtlichen Datenbank-Job umsetzen.
4168. [P3] Ein Werkzeug `tools/shop/replay_receipt.py` schreiben, das einen gespeicherten Beleg erneut prüft, für Support-Fälle.
4169. [P3] Das Apple-Feld `revocationReason` und das Google-Feld `voidedReason` in `refunds` speichern, um Missbrauch zu erkennen.
4170. [P3] Die Antwortzeit der Belegprüfung auf höchstens 3 Sekunden begrenzen und bei Zeitüberschreitung den Kauf in der Warteschlange lassen.
4171. [P3] Einen Zustand "Shop-Wartung" in `server_config` einführen, der alle Käufe sperrt und im Shop einen Hinweis zeigt.
4172. [P3] Für Apple-Familienfreigabe die Berechtigung auch an Familienmitglieder vergeben, deren Beleg `inAppOwnershipType = FAMILY_SHARED` trägt.
4173. [P3] Den Billing-Dienst mit eigenem Health-Check `/billing/v1/health` versehen und im vorhandenen Server-Workflow prüfen.
4174. [P3] Für Google-Abos `linkedPurchaseToken` auswerten, damit ein Planwechsel den alten Pass sauber beendet.
4175. [P3] In `docs/ONLINE.md` einen Abschnitt "Shop-Server" mit Tabellen, Funktionen und Benachrichtigungswegen ergänzen.
4176. [P3] Die Ledger-Tabelle nur anhängend erlauben (kein Update, kein Delete außer dem 10-Jahres-Job) und das per Datenbank-Trigger erzwingen.

### Shop-Oberfläche
4177. [x] [P1] Eine Szene `scenes/shop/ShopMenu.tscn` mit Skript `scripts/shop/ShopMenu.gd` bauen, die auf `MenuHost` aufsetzt und in 144 x 256 mit `PixelFont` läuft. Umgesetzt ohne eigene Szene, als Menü auf `MenuHost` wie `AccountMenu.gd`.
4178. [x] [P1] Den Eintrag "Shop" in `scripts/ui/PauseMenu.gd` zwischen "Satchel" und "Save" einfügen; im Kindermodus heißt er "Shop (gesperrt)" und öffnet nur einen Hinweis.
4179. [P1] Den Shop in 5 Reiter teilen: "Vorteile", "Pakete", "Pass", "Aussehen", "Rissglas", wechselbar mit links und rechts auf dem virtuellen Steuerkreuz.
4180. [P1] Jede Angebotszeile zeigt Name, Menge, Preis (Euro vom Store oder Rissglas mit Euro-Gegenwert, z. B. "300 Rissglas (≈ 2,97 €)") und die Marke "Vorteil im Spiel", wenn zutreffend.
4181. [x] [P1] Die Detailansicht eines Angebots zeigt die vollständige Inhaltsliste, die genaue Wirkung in Zahlen, die Dauer und ob es in der Gleichstand-Liga wirkt.
4182. [x] [P1] Vor jedem Kauf mit Rissglas einen Bestätigungsdialog zeigen: "300 Rissglas ausgeben? Dein Guthaben danach: 200 Rissglas (≈ 1,98 €)", mit "Ja" und "Nein", "Nein" vorausgewählt.
4183. [x] [P1] Das Rissglas-Guthaben mit Euro-Gegenwert steht dauerhaft oben rechts im Shop.
4184. [x] [P1] Eine Kaufliste "Meine Käufe" im Shop zeigen, die `shop_history` lädt und Datum, Inhalt und Preis jedes Kaufs nennt.
4185. [P2] Ein eigenes Rissglas-Symbol (8 x 8 Pixel, kristallgrün mit hellem Rand) in `art/shop/riftglass.png` zeichnen und in `ElementIcons`-Stil einbinden.
4186. [P2] Eine Händlerfigur "Glaswirtin Oda" als Pixelbild 32 x 32 neben der Shop-Überschrift zeigen, die neutral grüßt und nie zum Kauf auffordert.
4187. [P2] Odas Sätze in `data/i18n/` nur beschreibend halten, etwa "Hier liegen Rissglas-Waren." und "Preise stehen bei jedem Stück."
4188. [P2] Angebote innerhalb eines Reiters nach Preis aufsteigend sortieren; teure Angebote nie zuerst zeigen.
4189. [P2] Angebote, die der Spieler schon dauerhaft besitzt, mit "Besitzt du" markieren und nicht erneut kaufbar machen.
4190. [P2] Angebote mit Kauflimit zeigen die Restmenge als "noch 2 von 3 Käufen diese Woche".
4191. [P2] Den Reiter "Rissglas" mit den 7 Paketen und dem festen Satz "100 Rissglas = 0,99 €, bei jedem Paket gleich" füllen.
4192. [P2] Bei zu wenig Rissglas nur "Nicht genug Rissglas" zeigen und darunter einen neutralen Link "Rissglas-Pakete ansehen", ohne Vorauswahl eines Pakets.
4193. [P2] Das restliche Ausgabelimit des Monats im Shop unten in einer Zeile zeigen, z. B. "Limit: noch 12,00 € von 20,00 € im November".
4194. [P2] Die Pass-Seite zeigt Preis pro Monat, alle Vorteile als Liste, Verlängerung "automatisch monatlich, kündbar im Store" und den Button "Pass verwalten".
4195. [P2] Den Shop vollständig mit dem Steuerkreuz und mit Tippen bedienbar machen, Tippflächen mindestens 16 x 16 Pixel in der internen Auflösung.
4196. [P2] Den Kontrastmodus aus den Einstellungen auch im Shop anwenden und Preise in heller Schrift auf dunklem Grund zeigen.
4197. [P2] Alle Shop-Texte über `data/i18n/` in Deutsch und Englisch führen und Euro-Gegenwerte nach Spracheinstellung formatieren ("2,97 €" oder "€2.97").
4198. [P2] Nach einem erfolgreichen Kauf einen kurzen Satz "Gutgeschrieben: 5 Ring-Tränke" zeigen, ohne Konfetti, Glücksrad oder Geräusch-Fanfare.
4199. [P2] Im Shop nie Animationen nutzen, die wie Ziehungen wirken (Drehen, Aufdecken, Kisten öffnen).
4200. [P2] Gekaufte Gegenstände erscheinen in der Tasche ("Satchel") in einer eigenen Gruppe "Rissglas-Waren".
4201. [P2] In der Tasche zeigt jeder Rissglas-Gegenstand bei Auswahl seine Wirkung, Dauer und Liga-Hinweis wie im Shop.
4202. [P2] Den Shop beim Öffnen nur dann laden, wenn `Online.is_online()` wahr ist, sonst den Satz "Shop braucht eine Verbindung" zeigen.
4203. [P2] Eine Ladeanzeige als drei Pixelpunkte zeigen, solange Produktdaten oder Serverantworten fehlen, höchstens 5 Sekunden, dann Fehlertext.
4204. [P2] Die Shop-Musik leise und ruhig halten (eigener Titel in `data/music.json`), ohne steigende Spannung beim Kaufdialog.
4205. [P3] Eine Hilfeseite im Shop "So funktioniert der Shop" mit 5 kurzen Absätzen zu Rissglas, Euro-Preisen, Limit, Erstattung und Gleichstand-Liga einbauen.
4206. [P3] Den Shop nicht im Titelbildschirm, nicht beim Spielstart und nicht in Ladebildschirmen bewerben.
4207. [P3] Eine Vorschau für Kosmetik zeigen: der Wanderer oder der Spirling dreht sich in 4 Richtungen mit dem gewählten Aussehen.
4208. [P3] Eine Vorschau für Vorteils-Gegenstände zeigen: bei Ring-Tränken den neuen Ring und die neuen Werte eines gewählten Spirlings, bevor gekauft wird.
4209. [P3] Eine Suche oder Filterung nach "nur Kosmetik" und "nur ohne Vorteil" für Spieler anbieten, die keine Vorteile kaufen wollen.
4210. [P3] Eine Einstellung "Shop-Marken ausblenden" anbieten, die das Shop-Symbol in der Tasche und im Menü dezent macht.
4211. [P3] Den Shop in der Größenstufe der späteren Eras mit `EraManager` mitskalieren, damit er in Era II bis IV nicht verpixelt.
4212. [P3] Für Bildschirmleser die Preiszeile als ganzen Satz vorlesbar halten ("Ring-Trank, 5 Stück, 400 Rissglas, etwa 3,96 Euro").
4213. [P3] Neue Angebote mit einer kleinen Marke "neu" für 14 Tage kennzeichnen, ohne Blinken.
4214. [P3] Einen Schnellzugang zum Shop aus der Tasche anbieten, wenn ein Rissglas-Gegenstand aufgebraucht ist, nur als Textzeile und nur außerhalb des Kampfes.
4215. [P3] Die Shop-Ansicht für Store-Screenshots mit `tools/store/make_store_images.py` automatisch erzeugen.
4216. [P3] Einen Bildschirm "Käufe wiederherstellen" mit Ergebnisliste zeigen, welche Berechtigungen zurückgekommen sind.

### Preisstufen und Premium-Währung Rissglas
4217. [x] [P1] Die Premium-Währung heißt "Rissglas" (EN "Riftglass"): Splitter aus geschlossenen Rissen, die nur im Shop zu haben sind und nie im Spiel gefunden werden.
4218. [x] [P1] Die Rissglas-Pakete mit festem Kurs anlegen: 0,99 € = 100, 1,99 € = 200, 4,99 € = 500, 9,99 € = 1000, 19,99 € = 2000, 49,99 € = 5000, 99,99 € = 10000 Rissglas, ohne Bonusmengen.
4219. [x] [P1] Alle Rissglas-Preise im Shop sind Vielfache von 100, damit jedes Angebot genau zu Paketgrößen passt und kein Rest übrig bleibt, den man nicht ausgeben kann.
4220. [x] [P1] Jedes Vorteils- und Kosmetik-Angebot ist auch direkt in Euro kaufbar (Store-Produkt), damit niemand Rissglas kaufen muss, um einen Preis zu verstehen.
4221. [x] [P1] Den Euro-Gegenwert immer nach dem Kurs "100 Rissglas = 0,99 €" berechnen und auf volle Cent abrunden, in einer Funktion `ShopCatalog.euro_hint(rg: int)`.
4222. [x] [P1] Die Datei `data/shop.json` als einzige Quelle für Angebote anlegen: Kennung, Art, Inhalt, Rissglas-Preis, Store-Produkt-ID, Euro-Stufe, Liga-Wirkung, Kauflimit, Altersgrenze.
4223. [x] [P1] Eine Klasse `scripts/shop/ShopCatalog.gd` schreiben, die `data/shop.json` lädt, prüft und an den Shop gibt, analog zu `Database.gd`.
4224. [P2] Der Server führt eine eigene Kopie des Katalogs in der Tabelle `shop_offers`, die per Skript aus `data/shop.json` gefüllt wird, und `shop_buy` nutzt nur diese Preise.
4225. [P2] Die Euro-Stufen der Einzelangebote festlegen: 0,99 €, 1,99 €, 2,99 €, 4,99 €, 9,99 €, 19,99 €, und kein Einzelangebot über 19,99 €.
4226. [P2] Pakete über 49,99 € gibt es nur als Rissglas, nie als Bündel mit Spielvorteilen, damit keine teuren Vorteilskäufe auf einen Klick entstehen.
4227. [P2] Rissglas verfällt nicht, solange das Konto besteht, und das steht in der Hilfe und den Nutzungsbedingungen.
4228. [P2] Rissglas lässt sich nicht an Freunde schenken, nicht tauschen und nicht in Geschenken (`mail`) versenden.
4229. [P2] Rissglas kann nicht in Münzen getauscht werden, außer über die festen Münz-Angebote im Reiter "Vorteile", die genau eine Menge Münzen für einen festen Preis geben.
4230. [P2] Kein Angebot kostet krumme Beträge wie 350 oder 1250 Rissglas; Tests in `tests/test_shop_catalog.gd` prüfen die Teilbarkeit durch 100.
4231. [P2] Ein Angebot hat entweder einen Rissglas-Preis oder einen Euro-Preis als Hauptpreis, und der jeweils andere steht klein darunter.
4232. [P2] Rabattaktionen gibt es höchstens 4 Mal im Jahr, je 7 Tage, mit höchstens 30 % Nachlass, und sie stehen vorher in `docs/shop/CHANGELOG.md`.
4233. [P2] Den Gegenwert von Bündeln ehrlich angeben: "Einzeln 1500 Rissglas, hier 1000 Rissglas", nur wenn alle Einzelteile auch einzeln verkauft werden.
4234. [P2] Ein Startguthaben von 0 Rissglas setzen; kein Gratis-Rissglas beim Start, damit der Wert nicht verwischt.
4235. [P2] Für Tests ein Feld `test_only` in `data/shop.json` vorsehen, das Angebote nur auf Testkonten zeigt.
4236. [P2] Die Preisangaben in Rissglas und die Euro-Stufen in `docs/MONETIZATION.md` als Tabelle zeigen, erzeugt durch `tools/shop/make_shop_table.py`.
4237. [P2] Den Kurs 100 Rissglas = 0,99 € für mindestens 12 Monate festschreiben; Änderungen nur mit 30 Tagen Ankündigung.
4238. [P3] Die Länderpreise außerhalb der Eurozone folgen den Store-Umrechnungen, und der Euro-Gegenwert wird dort in der Landeswährung aus dem kleinsten Paket abgeleitet.
4239. [P3] Ein Feld `price_history` in `data/shop.json` führen (Datum, Preis), damit Vorher-Preise nach Preisangabenverordnung belegbar sind.
4240. [P3] Ein Jahrespaket "Rissglas-Vorrat" gibt es nicht; stattdessen den Pass als Jahresplan für 39,99 € anbieten.
4241. [P3] Für Rissglas ein kurzes Hintergrundstück in `docs/WORLD.md` vorschlagen (eigener Abschnitt, mit Ali abstimmen), das erklärt, warum Oda es verkauft.
4242. [P3] In der Hilfe ein Rechenbeispiel zeigen: "500 Rissglas kosten 4,99 €. Ein Ring-Trank-Fünferpack kostet 400 Rissglas, also etwa 3,96 €."
4243. [P3] Den Preisen in `data/shop.json` eine Spalte `free_equivalent_hours` beigeben, die schätzt, wie lange ein Spieler ohne Kauf für den gleichen Vorteil spielt.
4244. [P3] Die Anzeige "free_equivalent_hours" nicht im Spiel zeigen, sondern nur für die Balance in `docs/MONETIZATION.md` nutzen.
4245. [P3] Eine Obergrenze für das Guthaben von 50000 Rissglas setzen, darüber sind keine Paketkäufe möglich.
4246. [P3] Im Shop einen Hinweis zeigen, wenn ein Kauf das Guthaben über 20000 Rissglas bringen würde: "Du hast schon viel Rissglas."

### Ausgabelimits, Kindermodus und Altersabfrage
4247. [x] [P1] Beim ersten Öffnen des Shops das Geburtsjahr und den Geburtsmonat abfragen (Liste, keine freie Eingabe) und nur die Altersgruppe (unter 13, 13 bis 15, 16 bis 17, ab 18) in `profiles.age_band` speichern. Umgesetzt in der eigenen Tabelle `shop_profiles.age_band` (nicht in `profiles`, damit Bereich 7 unberührt bleibt).
4248. [x] [P1] Unter 13 Jahren ist der Shop gesperrt; es erscheint nur der Satz "Der Shop ist für dein Alter gesperrt. Frag eine erwachsene Person."
4249. [x] [P1] Für 13 bis 15 Jahre gilt ein festes Monatslimit von 15 €, für 16 bis 17 Jahre von 30 €, das der Spieler nicht erhöhen kann.
4250. [x] [P1] Ab 18 Jahren gilt ein voreingestelltes Monatslimit von 100 €, das der Spieler senken oder nach einer Wartezeit von 7 Tagen auf höchstens 300 € erhöhen kann.
4251. [x] [P1] Der Server prüft das Limit in `shop_buy` und beim Gutschreiben von Belegen; überschreitet ein Store-Kauf das Limit, wird er gutgeschrieben, aber der Shop danach bis Monatsende gesperrt.
4252. [x] [P1] Vor einem Store-Kauf prüft der Client das Limit über `shop_state`, damit Käufe über dem Limit gar nicht erst starten.
4253. [x] [P1] Die Altersgruppe lässt sich nur nach unten ändern; eine Erhöhung ist erst möglich, wenn das angegebene Geburtsjahr es erlaubt, damit Kinder nicht einfach umstellen.
4254. [P2] Einen Kindermodus in den Einstellungen anbieten, der den Shop ganz ausblendet und mit einer 4-stelligen PIN geschützt wird, die eine erwachsene Person setzt.
4255. [P2] Die PIN nur als Hash in `profiles.parent_pin_hash` speichern und nach 5 Fehlversuchen für 1 Stunde sperren.
4256. [P2] Ein Tageslimit von 5 Käufen für unter 18-Jährige zusätzlich zum Monatslimit setzen.
4257. [P2] Bei 50 %, 80 % und 100 % des Monatslimits einen neutralen Hinweis "Du hast 80 % deines Limits genutzt." im Shop zeigen.
4258. [P2] Eine Ausgaben-Übersicht "Diesen Monat ausgegeben: 12,97 €" mit Monatsliste der letzten 12 Monate im Shop anzeigen.
4259. [P2] Eine freiwillige Kaufpause anbieten (7, 30 oder 90 Tage), in der der Shop gesperrt bleibt und die sich nicht vorzeitig aufheben lässt.
4260. [P2] Für unter 18-Jährige den Pass nur buchbar machen, wenn der Store eine Elternfreigabe meldet (Apple "Ask to Buy", Google Family-Kauffreigabe), sonst den Kauf sperren.
4261. [P2] Eine Spielzeit-Erinnerung nach 2 Stunden am Stück anbieten, die unabhängig vom Shop wirkt und im Kindermodus voreingestellt an ist.
4262. [P2] Die Limits in Euro nach dem Store-Preis berechnen (`priceAmountMicros`, Apple `price`) und Rissglas-Ausgaben nicht doppelt zählen.
4263. [P2] Für Eltern eine Seite `server/site/eltern.html` mit Anleitung zu Kindermodus, PIN, Store-Kaufsperre und Erstattung bauen.
4264. [P2] Beim Wechsel des Monats das Limit nach Serverzeit Europa/Berlin zurücksetzen.
4265. [P2] Bei Kontoübertragung per Transfercode Altersgruppe, Limit und Kindermodus mitnehmen.
4266. [P3] Ohne Altersangabe bleibt der Shop zu; die Abfrage erscheint nur, wenn der Spieler den Shop öffnet, nicht beim Spielstart.
4267. [P3] Die Altersabfrage neutral formulieren ("Wann bist du geboren?") und keine Vorteile an eine höhere Altersangabe knüpfen.
4268. [P3] Einen Elternbericht anbieten: auf Wunsch zeigt der Shop einen 6-stelligen Code, mit dem Eltern auf `/eltern` die Monatsausgaben des Kontos sehen.
4269. [P3] Für Spieler ab 18 eine Selbsteinschätzung "Ich möchte weniger ausgeben" anbieten, die das Limit sofort auf 20 € setzt.
4270. [P3] Nach drei Monaten mit vollem Limit einen freundlichen Hinweis auf Kaufpause und Hilfeseite zeigen.
4271. [P3] Die Altersabfrage alle 12 Monate nicht wiederholen, sondern die Altersgruppe aus dem gespeicherten Geburtsjahr fortschreiben.
4272. [P3] In der Hilfe eine Beratungsstelle zum Thema Ausgaben in Spielen nennen und regelmäßig prüfen, ob der Link noch geht.
4273. [P3] Tests in `tests/test_spend_limits.gd` und im Smoke-Test schreiben, die jede Altersgruppe, die Wartezeit, die Kaufpause und den Monatswechsel prüfen.
4274. [P3] Den Kindermodus auch in der Freundesliste wirken lassen, sodass Geschenke an Freunde nie Rissglas-Waren enthalten.
4275. [P3] Eine Erklärung in `docs/legal/SHOP_COMPLIANCE.md`, warum nur Altersgruppen und keine Geburtsdaten gespeichert werden (Datensparsamkeit).
4276. [P3] Die Limits und Altersgruppen als Werte in `server_config` halten, damit sie ohne neue App-Version änderbar sind.

### Kosmetik
4277. [P1] Wanderer-Jacken als Kosmetik anbieten: 8 neue Jackenfarben je 200 Rissglas (≈ 1,98 €) zusätzlich zu den 4 freien Farben in `GameState.TAMER_COLORS`.
4278. [x] [P1] Kosmetik hat nie eine Wirkung im Kampf, beim Bonden oder in der Welt, und ein Test prüft, dass Kosmetik-Angebote keine Wertefelder haben.
4279. [P2] Spirling-Farbtöne als Kosmetik anbieten: pro Art ein alternativer Farbton für 300 Rissglas, der nur das Aussehen ändert und im Spirlog als "Farbton" vermerkt ist.
4280. [P2] Die Farbtöne als Paletten-Tausch im Shader umsetzen, damit keine neuen Sprites pro Era nötig sind.
4281. [P2] Kampf-Hintergründe als Kosmetik anbieten: 6 Hintergründe (Mondsee, Kupferwald, Nebelhafen, Sternwiese, Aschefeld, Glasgrotte) je 300 Rissglas.
4282. [P2] Textrahmen für das Dialogfenster als Kosmetik anbieten: 5 Rahmen je 100 Rissglas.
4283. [P2] Wanderer-Hüte als Kosmetik anbieten: 6 Hüte je 200 Rissglas, sichtbar in der Welt und im Kampfbild.
4284. [P2] Profilrahmen für die Freundesliste (`FriendsMenu.gd`) anbieten: 6 Rahmen je 100 Rissglas.
4285. [P2] Echo-Grußkarten-Motive für Geschenke an Freunde anbieten: 8 Motive je 100 Rissglas, die nur das Aussehen der Karte ändern.
4286. [P2] Fotorahmen und Sticker für den Fotomodus anbieten: 10 Sticker für 200 Rissglas als festes Set.
4287. [P2] Einen Kosmetik-Schrank im Menü "Team" und unter Einstellungen bauen, in dem gekaufte Teile an- und abgelegt werden.
4288. [P2] Gekaufte Kosmetik in `entitlements` speichern und beim Laden des Spielstands nur anzeigen, was der Server bestätigt.
4289. [P2] Kosmetik-Teile als Nicht-Verbrauchsgüter im Store anlegen, damit sie über "Käufe wiederherstellen" zurückkommen.
4290. [P2] Eigene Pixelkunst für alle Kosmetik in `art/shop/cosmetics/` anlegen und mit `tools/ip_check.sh` auf fremde Formen prüfen.
4291. [P2] Jedes Kosmetik-Teil in der Vorschau des Shops zeigen, bevor es gekauft wird.
4292. [P2] Kosmetik-Sets anbieten (Jacke, Hut, Rahmen im gleichen Stil) für 400 Rissglas statt 500 einzeln, mit ehrlichem Einzelpreis daneben.
4293. [P3] Kosmetik ist in der Gleichstand-Liga sichtbar, weil sie keinen Vorteil gibt, und wird beim Gegner im Kampfbild gezeigt.
4294. [P3] Ein Spirlog-Einbandmotiv als Kosmetik anbieten: 4 Motive je 200 Rissglas.
4295. [P3] Spuren in der Welt (Fußabdrücke im Schnee oder Sand in anderer Form) als Kosmetik anbieten: 4 Spuren je 100 Rissglas.
4296. [P3] Musik-Spieluhr anbieten: freigespielte Musikstücke als Hörliste im Menü, Freischaltung des ganzen Satzes für 300 Rissglas, keine Stücke nur gegen Geld.
4297. [P3] Kosmetik passend zu jeder Era (I bis IV) zeichnen, damit sie beim Era-Wechsel im neuen Stil erscheint.
4298. [P3] Saisonale Kosmetik (Winterjacke, Laternenfest-Hut) jedes Jahr wieder anbieten und nie als "nur jetzt oder nie" bewerben.
4299. [P3] Kosmetik-Teile in der Freundesansicht und bei Echos anderer Spieler zeigen, wenn der Spieler das in den Einstellungen erlaubt.
4300. [P3] Eine Einstellung "Kosmetik anderer Spieler ausblenden" anbieten.
4301. [P3] Für jede frei verdiente Kosmetik (bestehende Jackenfarben) eine Marke "erspielt" zeigen, damit erspielte und gekaufte Teile unterscheidbar sind.
4302. [P3] Namensfarben für den Wanderer-Namen in der Freundesliste anbieten: 6 Farben je 100 Rissglas, alle gut lesbar im Kontrastmodus.
4303. [P3] Animierte Sprechblasen-Symbole für feste Grüße (`Phrases.gd`) anbieten: 6 Symbole je 100 Rissglas.
4304. [P3] Einen alternativen Titelbildschirm-Hintergrund für 200 Rissglas anbieten, der nur lokal wirkt.
4305. [P3] Kosmetik nie hinter Vorteils-Pakete koppeln; jedes Teil ist einzeln kaufbar.
4306. [P3] Für Kosmetik in `data/shop.json` ein Feld `slot` (Jacke, Hut, Rahmen, Hintergrund, Farbton, Spur, Sticker) führen.

### Komfort ohne Vorteil
4307. [P2] Zusätzliche Speicherplätze (Slot 4 und 5 neben den 3 vorhandenen) für je 300 Rissglas anbieten und die Prüfung `slot between 1 and 3` auf 1 bis 5 erweitern.
4308. [P2] Eine Namensänderung des Wanderers nach dem ersten freien Mal für 100 Rissglas anbieten, mit Prüfung gegen `banned_words`.
4309. [P2] Eine Neuverteilung der Echo-Team-Aufstellung für Freunde ohne Kosten lassen und das in der Hilfe nennen, damit Komfort nicht mit Vorteil verwechselt wird.
4310. [P2] Eigene Ordner und Sortierung im Lager (Farben, Namen) für 200 Rissglas anbieten, ohne mehr Plätze.
4311. [P2] Ein Notizbuch-Erweiterungspaket für den Fotomodus (doppelte Fotoalbum-Größe) für 100 Rissglas anbieten.
4312. [P2] Spirling-Spitznamen-Zeichen (Sonderzeichen wie Stern und Herz im Namen) für 100 Rissglas anbieten.
4313. [P3] Eine Kampf-Wiederholungs-Ablage für 10 statt 1 gespeicherte Kämpfe unter "Records" für 200 Rissglas anbieten.
4314. [P3] Komfortkäufe in `data/shop.json` mit `kind: "comfort"` markieren und ein Test prüft, dass sie keine Kampf- oder Wachstumsfelder haben.
4315. [P3] Zusätzliche feste Grußsätze für Freunde (12 neue Sätze aus `Phrases.gd`-Stil) für 100 Rissglas anbieten.
4316. [P3] Eigene Wegpunkt-Marken auf der Karte (5 farbige Marken) für 100 Rissglas anbieten.
4317. [P3] Einen erweiterten Spirlog-Filter (nach Gabe, Farbton, Fundort) für 100 Rissglas anbieten.
4318. [P3] Eine Sammelansicht aller Kosmetik-Teile als Schrankbuch für 100 Rissglas anbieten.
4319. [P3] Ein zweites Fotomodus-Filter-Set (Sepia, Abenddämmerung, Nacht) für 100 Rissglas anbieten.
4320. [P3] Für Komfortkäufe die Marke "kein Vorteil" im Shop zeigen.
4321. [P3] Komfortkäufe in der Gleichstand-Liga ohne Einschränkung erlauben und das in der Angebots-Detailansicht nennen.

### Tests, Qualität und Betrieb
4322. [x] [P1] Ein Testkonto-Verfahren in `docs/shop/TESTPLAN.md` beschreiben: Testkauf jedes Produkts auf iOS und Android, Erstattung, Pass-Verlängerung, Wiederherstellen.
4323. [x] [P1] GUT-Tests `tests/test_shop_catalog.gd` schreiben, die jedes Angebot auf Pflichtfelder, Preisstufe, Rissglas-Teilbarkeit, verbotene Wörter und fehlende Zufallsfelder prüfen.
4324. [x] [P1] Einen Test schreiben, der genau 2/3 der Angebote in `data/shop.json` mit `kind: "advantage"` und 1/3 mit anderen Arten erwartet (Toleranz 2 Angebote).
4325. [P2] In der CI einen Job `shop-check` anlegen, der Katalog-Tests, `tools/ip_check.sh` und `tools/release_check.py` bei jeder Änderung an `data/shop.json` laufen lässt.
4326. [P2] Server-Tests für `shop_buy` in SQL schreiben: zu wenig Guthaben, Limit erreicht, Doppelkauf mit gleichem Idempotenzschlüssel, gesperrtes Konto, Preisänderung.
4327. [P2] Einen Lasttest mit 200 gleichzeitigen Käufen gegen eine Testdatenbank laufen lassen und sicherstellen, dass kein Guthaben negativ wird.
4328. [P2] Gefälschte Belege (falsche Signatur, fremde Bundle-ID, abgelaufenes Zertifikat, wiederverwendete Transaktion) als Testfälle in `server/billing/tests/` ablegen.
4329. [P3] Einen Ablauftest im Spiel schreiben, der mit `LocalBackend` und `LocalBilling` einen Kauf, den Verbrauch und das Speichern prüft.
4330. [P3] Eine Prüfliste für jede neue App-Version mit Shop-Änderungen in `docs/RELEASE.md` ergänzen: Produkte angelegt, Preise geprüft, Texte geprüft, Testkäufe gemacht.
4331. [P3] Einen Notfallplan in `docs/shop/NOTFALL.md` schreiben: Shop per `server_config` schließen, fehlerhafte Gutschriften zurückholen, Spieler informieren.
4332. [P3] Fehler im Billing-Dienst nur in die eigenen Server-Logs schreiben, 14 Tage aufbewahren und keine fremden Fehlerdienste einbinden.
4333. [P3] Einen monatlichen Abgleich zwischen Store-Auszahlungsberichten und `purchases` von Hand in `docs/shop/ABGLEICH.md` beschreiben.

### Ring-Tränke und Wachstums-Boosts
4334. [x] [P1] (P2W) Den Gegenstand "Ring-Trank" (`rg_ring_tonic`) anlegen, der einem Spirling sofort 1 Ring gibt, Preis 100 Rissglas (≈ 0,99 €) oder 0,99 € direkt.
4335. [x] [P1] (P2W) Den Gegenstand "Großer Ring-Trank" (`rg_ring_tonic_5`) anlegen, der 5 Ringe auf einmal gibt, Preis 400 Rissglas (≈ 3,96 €) oder 3,99 € direkt.
4336. [x] [P1] (P2W) Den Gegenstand "Ring-Elixier" (`rg_ring_elixir`) anlegen, der einen Spirling bis zur aktuellen Ring-Obergrenze hebt, Preis 1500 Rissglas (≈ 14,85 €).
4337. [x] [P1] (P2W) Alle Ring-Tränke halten die Ring-Obergrenze ein: nie über 60 und auf Veteran und Rift-Born nie über die Ring-Obergrenze des geschlossenen Risses aus `GameState.gd`.
4338. [x] [P1] (P2W) Ring-Tränke lösen beim Erreichen des Rings Entfalten und neue Techniken genauso aus wie normales Wachstum, über dieselbe Funktion in `GameState.gd`.
4339. [x] [P1] (P2W) Den "Wachstumskristall" (`rg_growth_x2`) anlegen, der für die nächsten 20 Kämpfe das Wachstum des ganzen Teams verdoppelt, Preis 200 Rissglas (≈ 1,98 €).
4340. [x] [P1] (P2W) Den "Großen Wachstumskristall" (`rg_growth_x3`) anlegen, der für 20 Kämpfe dreifaches Wachstum gibt, Preis 400 Rissglas (≈ 3,96 €).
4341. [x] [P1] (P2W) Wachstums-Boosts zählen Kämpfe statt Minuten, damit keine Zeit abläuft und kein Druck entsteht, sofort zu spielen.
4342. [x] [P1] (P2W) Den aktiven Wachstums-Boost mit Restzahl ("Wachstum x2: noch 14 Kämpfe") in der Team-Ansicht und im Kampfende-Bildschirm zeigen.
4343. [P1] (P2W) Ein "Team-Wachstumsband" (`rg_share_band`) anlegen, das das Wachstum gleichmäßig auf alle 5 Team-Mitglieder verteilt, auch auf nicht kämpfende, dauerhaft, Preis 1000 Rissglas oder 9,99 €.
4344. [P1] (P2W) Ring-Tränke und Wachstums-Boosts als Verbrauchsgüter im Store anlegen und nach dem Kauf nur über den Server in die Tasche legen.
4345. [P1] (P2W) Ring-Trank-Fünferpack (`rg_ring_tonic_x5`) für 400 Rissglas anbieten, das 5 einzelne Ring-Tränke liefert.
4346. [P2] (P2W) Den "Ruhe-Wachstumsstein" (`rg_rest_growth`) anlegen, der Spirlings im Lager pro echter Stunde Spielzeit 1 % des Wachstums bis zum nächsten Ring gibt, dauerhaft, Preis 800 Rissglas.
4347. [P2] (P2W) Den Ruhe-Wachstumsstein auf 8 Spirlings im Lager begrenzen und die Auswahl im Lager-Menü treffen lassen.
4348. [P2] (P2W) Einen "Wächter-Wachstumskristall" anlegen, der bei Rift-Wächter-Kämpfen das Wachstum vervierfacht, für 3 Wächterkämpfe, Preis 300 Rissglas.
4349. [P2] (P2W) Den Wachstums-Boost mit dem bestehenden Wachstum aus Rematches und Tagesfunden multiplizieren und die Formel in `docs/BALANCE.md` nachtragen.
4350. [P2] (P2W) Wachstums-Boosts nicht stapeln: ein zweiter gekaufter Boost verlängert die Kampfzahl, statt den Faktor zu erhöhen.
4351. [P2] (P2W) Ring-Tränke im Lager-Menü direkt auf Spirlings im Lager anwendbar machen.
4352. [P2] (P2W) Einen Bestätigungsdialog vor dem Einsatz von Ring-Elixieren zeigen: "Ruvi steigt von Ring 18 auf Ring 30."
4353. [P2] (P2W) Ring-Tränke funktionieren in allen Schwierigkeitsstufen, in Rift-Born aber nur außerhalb von Kämpfen, wie andere Gegenstände dort.
4354. [P2] (P2W) Die Wirkung von Ring-Tränken im Spielstand protokollieren (`rg_used` mit Zeit und Spirling-uid), damit der Server Missbrauch erkennt.
4355. [P2] (P2W) Der Server lehnt Spielstände ab, in denen mehr Ringe durch Tränke dazukamen als gekaufte Tränke verbraucht wurden.
4356. [P2] (P2W) Einen "Ring-Trank für das Team" (`rg_team_ring`) anlegen, der allen 5 Team-Mitgliedern je 1 Ring gibt, Preis 400 Rissglas.
4357. [P2] (P2W) Einen "Aufholtrank" anlegen, der einen Spirling auf den Ring des stärksten Team-Mitglieds hebt, höchstens 10 Ringe, Preis 600 Rissglas.
4358. [P2] (P2W) Den Wachstumskristall als Wochenangebot zum halben Preis für das erste Mal pro Konto anbieten, mit festem Enddatum, nicht wiederholt.
4359. [P2] (P2W) Ein "Wachstums-Abo" nicht anbieten, sondern doppeltes Wachstum nur über den Pass, damit es nicht zwei Abos gibt.
4360. [P2] (P2W) Die Ring-Tränke im Spirlog mit einem kleinen Symbol am Spirling-Eintrag markieren, wenn ein Spirling durch Tränke gestiegen ist, nur für den Besitzer sichtbar.
4361. [P2] (P2W) In Echo-Duellen mit Freunden wirken die durch Tränke erreichten Ringe normal, weil sie zum Spirling gehören.
4362. [P2] (P2W) Einen "Wachstumsschild" anlegen, der verhindert, dass ein Spirling bei Niederlage Wachstum verliert, falls Bereich 8 eine Wachstumsstrafe plant; sonst entfällt das Angebot.
4363. [P2] (P2W) Den Großen Ring-Trank auf 10 Käufe pro Woche begrenzen, um Spitzen beim Ausgeben abzufedern.
4364. [P2] (P2W) Ring-Elixiere auf 3 Käufe pro Woche begrenzen.
4365. [P2] (P2W) Ring-Tränke auch für Spirlings anwenden lassen, die gerade erst gebondet wurden, damit neue Spirlings sofort mitspielen.
4366. [P2] (P2W) Ein "Entfaltungs-Trank" (`rg_unfold_now`) anlegen, der einen Spirling sofort entfaltet, wenn er den Ring für das Entfalten zu 80 % erreicht hat, Preis 500 Rissglas.
4367. [P2] (P2W) Für Entfaltungen mit Gegenstand (`tide_pearl`) einen Shop-Ersatz "Gezeitenglas" für 500 Rissglas anbieten, der dasselbe bewirkt wie `tide_pearl`.
4368. [P2] (P2W) Einen "Wachstumsspeicher" anlegen, der überzähliges Wachstum von Spirlings an der Ring-Obergrenze sammelt und später auf andere verteilt, dauerhaft, Preis 800 Rissglas.
4369. [P2] (P2W) Den Wachstumsspeicher bei 50000 gesammeltem Wachstum begrenzen und die Menge in der Team-Ansicht zeigen.
4370. [P2] (P2W) Wachstums-Boosts gelten auch für Wachstum aus Echo-Duellen mit Freunden.
4371. [P2] (P2W) Die Wirkung aller Ring- und Wachstumsangebote in `scripts/shop/ShopEffects.gd` bündeln, damit `BattleModel` nur einen Faktor abfragt.
4372. [P3] (P2W) Unit-Tests in `tests/test_shop_growth.gd` für Obergrenze, Entfalten, Boost-Zähler, Stapeln und Rift-Born schreiben.
4373. [P3] (P2W) Wachstumskristalle im Kampfende-Bildschirm zeigen den Anteil, der durch den Boost kam ("+120 Wachstum, davon +60 durch Kristall").
4374. [P3] (P2W) Einen "Ringsprung zur nächsten Obergrenze" anlegen, der nach dem Schließen eines Risses das ganze Team auf die neue Obergrenze hebt, Preis 2000 Rissglas, nur Veteran und höher.
4375. [P3] (P2W) Einen "Starthilfe-Ring" für neue Spielstände anlegen, mit dem der Start-Spirling auf Ring 10 beginnt, Preis 300 Rissglas, einmal pro Spielstand.
4376. [P3] (P2W) Ring-Tränke als Geschenk an sich selbst über die Post (`mail`) nicht erlauben, damit nichts außerhalb des Kontos landet.
4377. [P3] (P2W) Einen saisonalen "Laternen-Wachstumskristall" mit x2 für 40 Kämpfe für 300 Rissglas im Herbst anbieten.
4378. [P3] (P2W) Wachstums-Boosts beim Wechsel des Spielstands (Slot) behalten, weil sie am Konto hängen, und das in der Hilfe sagen.
4379. [P3] (P2W) Ein "Rückgangsglas" anlegen, das Ringe eines Spirlings um 1 senkt, für Spieler, die zu schnell gestiegen sind, Preis 100 Rissglas.
4380. [P3] (P2W) Die Ring-Tränke in Era II bis IV mit neuem Pixelbild zeigen, passend zum Era-Stil.
4381. [P3] (P2W) Für die Post-Game-Herausforderungen einen eigenen Wachstumskristall x2 mit 30 Kämpfen für 300 Rissglas anbieten.
4382. [P3] (P2W) Ein Bündel "Ring-Vorrat" (10 Ring-Tränke, 2 Große Ring-Tränke) für 1500 Rissglas anbieten, mit Einzelpreis 1800 daneben.
4383. [P3] (P2W) Die Wirkung von Wachstumskristallen auf Spirlings im Lager über den Ruhe-Wachstumsstein nicht verdoppeln.
4384. [P3] (P2W) Im Kampfende-Bildschirm keinen Hinweis "Mit Kristall hättest du mehr bekommen" zeigen.
4385. [P3] (P2W) Einen "Gaben-Wachstumskristall" anlegen, der die Wachstumsmenge für eine gewählte Element-Art verdreifacht, für 20 Kämpfe, Preis 300 Rissglas.
4386. [P3] (P2W) Den Ring-Trank in den Händlerläden der Welt nie anbieten, nur im Shop, damit die Münz-Wirtschaft von Bereich 8 unberührt bleibt.
4387. [P3] (P2W) Eine Übersicht "Tränke heute benutzt" in der Tasche zeigen, um den Verbrauch für den Spieler sichtbar zu halten.
4388. [P3] (P2W) Ring-Tränke im Shop mit Vorschau der neuen Werte (Kraft, Wucht, Schutz, Fokus, Tempo) zeigen, bevor man sie einsetzt.
4389. [P3] (P2W) Den Wachstumskristall im Pass als 1 Stück pro Woche gratis geben und das auf der Pass-Seite nennen.
4390. [P3] (P2W) Einen "Ring-Trank für Freunde-Echos" nicht anbieten; Echos von Freunden behalten ihre echten Ringe.
4391. [P3] (P2W) Die Preise für Ring-Angebote nach 3 Monaten Live-Betrieb mit den Werten aus `free_equivalent_hours` überprüfen und in `docs/shop/CHANGELOG.md` festhalten.
4392. [P3] (P2W) Ein "Wachstums-Archiv" anlegen, das zeigt, wie viel Wachstum ein Spirling durch Kauf und wie viel durch Spielen bekam.
4393. [P3] (P2W) Ring-Tränke in Story-Schwierigkeit um 50 % günstiger anbieten, weil dort keine Obergrenze die Balance stützt, wenn Bereich 8 dem zustimmt.

### Andenken aus dem Shop
4394. [x] [P1] (P2W) Das Andenken "Rissherz" (`rg_riftheart`) anlegen: +15 % Wucht, Preis 800 Rissglas (≈ 7,92 €) oder 7,99 € direkt, dauerhaft.
4395. [x] [P1] (P2W) Das Andenken "Glasschild" (`rg_glass_shield`) anlegen: +15 % Schutz, Preis 800 Rissglas, dauerhaft.
4396. [x] [P1] (P2W) Das Andenken "Klarsplitter" (`rg_clear_shard`) anlegen: +15 % Fokus, Preis 800 Rissglas, dauerhaft.
4397. [x] [P1] (P2W) Das Andenken "Wirbelglas" (`rg_whirl_glass`) anlegen: +15 % Tempo, Preis 800 Rissglas, dauerhaft.
4398. [x] [P1] (P2W) Das Andenken "Kernglas" (`rg_vigor_glass`) anlegen: +12 % Kraft, Preis 800 Rissglas, dauerhaft.
4399. [P1] (P2W) Shop-Andenken nutzen das vorhandene Feld `held` in `data/items.json`, damit `BattleRules.add_key` sie ohne Sonderweg liest.
4400. [P1] (P2W) Shop-Andenken sind dauerhafte Nicht-Verbrauchsgüter je Stück; ein Kauf gibt genau 1 Stück, das einem Spirling angelegt wird.
4401. [P1] (P2W) Shop-Andenken sind stärker als die Münz-Andenken (`swift_feather` +15 % Tempo bleibt, Shop-Wirbelglas bekommt zusätzlich +5 % Fokus), und die Werte stehen in `docs/BALANCE.md`.
4402. [x] [P1] (P2W) Acht Element-Prismen anlegen (Ember, Tide, Bloom, Volt, Stone, Gale, Lumen, Umbra), je +20 % Schaden für Techniken des Elements, je 600 Rissglas.
4403. [P1] (P2W) Das Andenken "Haltestein" (`rg_hold_stone`) anlegen: übersteht einmal pro Kampf einen Treffer, der bei voller Kraft besiegt hätte, mit 1 Kraft, Preis 1000 Rissglas.
4404. [x] [P1] (P2W) Das Andenken "Nachhallring" (`rg_echo_ring`) anlegen: heilt jede Runde 1/10 der Kraft, stärker als `bark_wrap` (1/12), Preis 1000 Rissglas.
4405. [P2] (P2W) Das Andenken "Funkenspeicher" (`rg_spark_store`) anlegen: +1 Energie pro Runde und +1 Höchstenergie, Preis 1200 Rissglas.
4406. [P2] (P2W) Das Andenken "Spiegelglas" (`rg_mirror_glass`) anlegen: wirft 20 % des erlittenen Schadens aus Wucht-Techniken zurück, Preis 1000 Rissglas.
4407. [P2] (P2W) Das Andenken "Erstschlag-Feder" (`rg_first_feather`) anlegen: der Träger handelt in der ersten Runde immer zuerst (nach Tausch und Gegenständen), Preis 1200 Rissglas.
4408. [P2] (P2W) Das Andenken "Schärfeglas" (`rg_keen_glass`) anlegen: verdoppelt die Chance auf besonders starke Treffer und erhöht deren Faktor auf 2,25, Preis 900 Rissglas.
4409. [P2] (P2W) Das Andenken "Reinglas" (`rg_pure_glass`) anlegen: schützt vor allen Zuständen (Brand, Nässe, Schlummer) für die ersten 3 Runden, Preis 800 Rissglas.
4410. [P2] (P2W) Das Andenken "Zwillingsprisma" (`rg_twin_prism`) anlegen: +10 % Schaden für beide Elemente eines Spirlings mit zwei Elementen, Preis 900 Rissglas.
4411. [P2] (P2W) Das Andenken "Wächterglas" (`rg_warden_glass`) anlegen: +20 % Schaden gegen Rift-Wächter, Preis 1000 Rissglas.
4412. [P2] (P2W) Das Andenken "Ausdauerband" (`rg_stamina_band`) anlegen: senkt die Energiekosten aller Techniken um 1 (mindestens 1), Preis 1500 Rissglas.
4413. [P2] (P2W) Das Andenken "Bindungsglas" (`rg_bond_glass`) anlegen: erhöht das Wachstum des Trägers um 50 %, dauerhaft, Preis 600 Rissglas.
4414. [P2] (P2W) Ein Andenken-Upgrade "Schliff" anlegen, das ein Shop-Andenken um eine Stufe verbessert (+15 % auf +20 %), Preis 500 Rissglas, höchstens 2 Stufen.
4415. [P2] (P2W) Den Schliff im Andenken-Namen zeigen ("Rissherz +1") und die Werte in der Detailansicht nennen.
4416. [P2] (P2W) Shop-Andenken dürfen nicht mit dem gleichen Münz-Andenken gestapelt werden; ein Spirling trägt weiter genau ein Andenken.
4417. [P2] (P2W) Ein "Andenken-Doppelplatz" (`rg_second_keepsake`) anlegen, mit dem ein Spirling dauerhaft ein zweites Andenken trägt, Preis 1500 Rissglas pro Spirling.
4418. [P2] (P2W) Den Doppelplatz auf 5 Spirlings pro Konto begrenzen und im Team-Menü zeigen, welcher Spirling ihn hat.
4419. [P2] (P2W) Den Doppelplatz von einem Spirling auf einen anderen übertragen lassen, kostenlos einmal pro Woche.
4420. [P2] (P2W) Shop-Andenken sind in der Gleichstand-Liga ohne Wirkung und das Kampfbild zeigt dort ein graues Andenken-Symbol.
4421. [P2] (P2W) In der Offenen Liga und Echo-Duellen wirken Shop-Andenken voll, und die Gegnervorschau zeigt angelegte Andenken.
4422. [P2] (P2W) In Rift-Born wirken Shop-Andenken nur mit halber Stärke, damit die schwerste Stufe ihren Reiz behält, und das steht in der Detailansicht.
4423. [P2] (P2W) Ein Andenken-Set "Glaswerk" (Rissherz, Glasschild, Klarsplitter, Wirbelglas) für 2800 Rissglas statt 3200 einzeln anbieten.
4424. [P2] (P2W) Die Wirkung aller Shop-Andenken als `held`-Felder in `data/items.json` mit Präfix `rg_` anlegen und in `Database.gd` als Shop-Ware markieren.
4425. [P2] (P2W) Shop-Andenken in der KI-Auswahl der Gegner nie verwenden; nur Spieler können sie tragen.
4426. [P2] (P2W) Unit-Tests in `tests/test_shop_keepsakes.gd` für jeden Effekt und die Gleichstand-Liga-Abschaltung schreiben.
4427. [P2] (P2W) Shop-Andenken bekommen eigene Pixelbilder 16 x 16 in `art/shop/keepsakes/` mit Rissglas-Schimmer, damit sie erkennbar sind.
4428. [P2] (P2W) Shop-Andenken bei Erstattung vom Spirling nehmen und aus der Tasche entfernen.
4429. [P2] (P2W) Ein Andenken "Glücksglas" mit Zufallswirkung nicht anbieten; alle Shop-Andenken haben feste Zahlen.
4430. [P2] (P2W) Das Andenken "Bollwerkglas" (`rg_bulwark_glass`) anlegen: -15 % erlittener Schaden aus Fokus-Techniken, Gegenstück zu `iron_burr`, Preis 800 Rissglas.
4431. [P3] (P2W) Das Andenken "Gegenwindglas" (`rg_headwind_glass`) anlegen: senkt das Tempo des Gegners im ersten Zug um eine Stufe, Preis 900 Rissglas.
4432. [P3] (P2W) Das Andenken "Ruhepol" (`rg_calm_pole`) anlegen: verhindert, dass Werte des Trägers durch gegnerische Techniken sinken, Preis 1000 Rissglas.
4433. [P3] (P2W) Das Andenken "Rissecho" (`rg_rift_echo`) anlegen: wiederholt die zuletzt genutzte Technik einmal pro Kampf mit 50 % Stärke ohne Energiekosten, Preis 1500 Rissglas.
4434. [P3] (P2W) Das Andenken "Heimkehrglas" anlegen: der Träger bekommt beim Einwechseln 15 % Kraft zurück, Preis 900 Rissglas.
4435. [P3] (P2W) Das Andenken "Gezeitenwechsel" anlegen: der erste Treffer eines Elements, gegen das der Träger schwach ist, macht nur einfachen Schaden, Preis 1200 Rissglas.
4436. [P3] (P2W) Saisonale Andenken mit gleicher Stärke wie dauerhafte anbieten, nur mit anderem Aussehen, damit nichts dauerhaft verpasst wird.
4437. [P3] (P2W) Einen "Andenken-Tausch" anlegen, mit dem ein Shop-Andenken gegen ein anderes gleichen Preises getauscht wird, einmal pro Monat kostenlos.
4438. [P3] (P2W) Shop-Andenken in Era II bis IV mit neuem Bild zeigen und ihre Werte nicht ändern.
4439. [P3] (P2W) Ein Andenken-Buch im Spirlog zeigen, das alle Shop-Andenken mit Wirkung listet, auch ungekaufte.
4440. [P3] (P2W) Einen dritten Schliff-Rang für Andenken (+25 %) erst nach 6 Monaten Live-Betrieb freigeben, wenn die Liga-Daten keinen Ausreißer zeigen.
4441. [P3] (P2W) Das Andenken "Lichtschlag" anlegen: +30 % Schaden für die erste Technik im Kampf, Preis 900 Rissglas.
4442. [P3] (P2W) Das Andenken "Wurzelband" anlegen: der Träger kann nicht ausgewechselt werden und bekommt +10 % Schutz, Preis 800 Rissglas.
4443. [P3] (P2W) Shop-Andenken im Kampfprotokoll nennen, wenn sie auslösen ("Haltestein hält Ruvi bei 1 Kraft.").
4444. [P3] (P2W) Die Werte aller Shop-Andenken nach 3 Monaten mit dem Kampf-Simulator aus `docs/BALANCE.md` neu messen und Ausreißer über 60 % Siegquote abschwächen, mit Ersatz für Käufer.
4445. [P3] (P2W) Für Shop-Andenken ein Feld `league_scope` in `data/shop.json` setzen (`open`, `none`) und es im Shop anzeigen.
4446. [P3] (P2W) Shop-Andenken im Echo-Team für Freunde sichtbar machen, damit der Gegner sieht, was wirkt.
4447. [P3] (P2W) Ein Andenken-Starterbündel (2 Element-Prismen nach Wahl) für 1000 Rissglas statt 1200 anbieten.

### Technik-Schriften
4448. [P1] (P2W) Acht "Rissschriften" anlegen, je eine pro Element, die eine Shop-Technik lehren, Preis je 500 Rissglas (≈ 4,95 €) oder 4,99 € direkt.
4449. [P1] (P2W) Die acht Shop-Techniken in `data/moves.json` mit eigenen Namen anlegen: Glutglas-Hieb (Ember), Flutglas-Welle (Tide), Rankenglas-Stich (Bloom), Blitzglas-Biss (Volt), Felsglas-Stoß (Stone), Sturmglas-Schnitt (Gale), Lichtglas-Strahl (Lumen), Schattenglas-Griff (Umbra).
4450. [P1] (P2W) Jede Shop-Technik hat Stärke 95, Genauigkeit 100 und Energie 4, also mehr als die Echo-Kristall-Techniken bei gleichen Kosten, und die Werte stehen in `docs/BALANCE.md`.
4451. [P1] (P2W) Rissschriften nutzen das vorhandene Feld `teaches` in `data/items.json` und lassen sich wie Echo-Kristalle anwenden.
4452. [P1] (P2W) Eine Rissschrift ist ein Verbrauchsgut: ein Kauf lehrt genau einem Spirling einmal die Technik.
4453. [P1] (P2W) Rissschriften nur an Spirlings des passenden Elements anwendbar machen, damit die Spielidee der Elemente bleibt.
4454. [P1] (P2W) Die Shop-Techniken mit eigenen Effekt-Skripten über `effect_id` anlegen, ohne Sonderfall in `BattleModel`.
4455. [P1] (P2W) Shop-Techniken in der Gleichstand-Liga durch die Echo-Kristall-Technik des gleichen Elements ersetzen und das in der Gegnervorschau anzeigen.
4456. [P1] (P2W) Shop-Techniken nie in der Gegner-KI für Wanderer und Wächter nutzen.
4457. [P1] (P2W) Ein "Technik-Gedächtnis" (`rg_move_memory`) anlegen, mit dem ein Spirling vergessene Techniken jederzeit neu lernt, dauerhaft pro Konto, Preis 600 Rissglas.
4458. [P2] (P2W) Jede Shop-Technik hat eine kleine Zusatzwirkung: Glutglas-Hieb 20 % Brand, Flutglas-Welle 20 % Nässe, Rankenglas-Stich heilt 25 % des Schadens.
4459. [P2] (P2W) Weitere Zusatzwirkungen: Blitzglas-Biss senkt Tempo um 1 Stufe zu 30 %, Felsglas-Stoß hebt Schutz des Anwenders zu 30 %, Sturmglas-Schnitt handelt mit Vorrang +1.
4460. [P2] (P2W) Weitere Zusatzwirkungen: Lichtglas-Strahl heilt Zustände des Anwenders, Schattenglas-Griff senkt Fokus des Gegners um 1 Stufe zu 30 %.
4461. [P2] (P2W) Einen "Technik-Platz 5" (`rg_fifth_move`) anlegen, mit dem ein Spirling dauerhaft 5 statt 4 Techniken kennt, Preis 1200 Rissglas pro Spirling.
4462. [P2] (P2W) Den Technik-Platz 5 im Kampfmenü als fünfte Zeile zeigen, ohne das eigene Kampfbild-Layout zu ändern, und in der Gleichstand-Liga sperren.
4463. [P2] (P2W) Eine "Fremdschrift" (`rg_cross_script`) anlegen, die einem Spirling eine Technik eines anderen Elements lehrt, die er sonst nie lernt, Preis 800 Rissglas.
4464. [P2] (P2W) Fremdschriften auf eine pro Spirling begrenzen und im Team-Menü als "Fremdtechnik" markieren.
4465. [P2] (P2W) Eine "Frühschrift" anlegen, mit der ein Spirling eine Technik aus seiner Lernliste bis zu 15 Ringe früher lernt, Preis 300 Rissglas.
4466. [P2] (P2W) Ein Bündel "Alle acht Rissschriften" für 3600 Rissglas statt 4000 anbieten.
4467. [P2] (P2W) Die Rissschriften als eigene Pixelbilder (Schriftrolle mit Element-Farbe) in `art/shop/scripts/` zeichnen.
4468. [P2] (P2W) Rissschriften zeigen im Shop eine Vorschau der Technik mit Stärke, Genauigkeit, Energie und Zusatzwirkung.
4469. [P2] (P2W) Shop-Techniken bekommen eine eigene kurze Kampfanimation im Presenter, die sich nicht von normalen Techniken in Länge unterscheidet.
4470. [P2] (P2W) Unit-Tests in `tests/test_shop_moves.gd` für Schaden, Zusatzwirkung, Element-Bindung und Gleichstand-Liga-Ersatz schreiben.
4471. [P2] (P2W) Die Shop-Techniken mit dem Kampf-Simulator messen und bei mehr als 15 % höherer Siegquote als die beste freie Technik auf Stärke 90 senken.
4472. [P2] (P2W) Die Namen der Shop-Techniken mit `tools/ip_check.sh` gegen bekannte fremde Technik-Namen prüfen.
4473. [P2] (P2W) Die englischen Namen der Shop-Techniken in `data/i18n/` eintragen (Emberglass Cleave, Tideglass Surge, Vineglass Pierce, Voltglass Bite, Stoneglass Ram, Galeglass Slice, Lumenglass Beam, Umbraglass Clutch).
4474. [P2] (P2W) Gelernte Shop-Techniken beim Entfalten behalten.
4475. [P2] (P2W) Eine Technik-Schrift für Kraft-Heilung "Glasquelle" anlegen, die 40 % Kraft heilt, Energie 4, für alle Elemente lernbar, Preis 600 Rissglas.
4476. [P2] (P2W) Eine Technik-Schrift "Glaswall" anlegen, die zwei Runden lang den Schaden für das ganze Team um 25 % senkt, Energie 5, Preis 600 Rissglas.
4477. [P2] (P2W) Eine Technik-Schrift "Glasruf" anlegen, die die Energie des Anwenders um 3 auffüllt und seine nächste Technik um 20 % stärkt, Energie 0, Preis 600 Rissglas.
4478. [P3] (P2W) Shop-Techniken in Echo-Teams für Freunde behalten, damit Freunde sie sehen und im Duell spüren.
4479. [P3] (P2W) Rissschriften bei Erstattung nicht rückgängig machen, wenn die Technik schon gelernt wurde, sondern das Guthaben negativ stellen.
4480. [P3] (P2W) Eine zweite Reihe Rissschriften (je Element eine Technik mit Stärke 120, Energie 6) nach 6 Monaten freigeben, Preis je 800 Rissglas.
4481. [P3] (P2W) Eine Rissschrift "Zweielement-Hieb" anlegen, die mit beiden Elementen eines Doppel-Spirlings trifft, Preis 1000 Rissglas, nur für Spirlings mit zwei Elementen.
4482. [P3] (P2W) Eine Technik-Ansicht im Spirlog zeigen, welche Spirlings welche Shop-Technik lernen können.
4483. [P3] (P2W) Shop-Techniken in den Post-Game-Herausforderungen erlauben, aber einen eigenen Rekord "ohne Shop" daneben führen.
4484. [P3] (P2W) Eine Rissschrift-Woche pro Jahr mit 20 % Nachlass, angekündigt in den Neuigkeiten, durchführen.
4485. [P3] (P2W) Den Technik-Platz 5 auf 3 Spirlings pro Konto begrenzen, um die Kampfbalance in Echo-Duellen zu halten.
4486. [P3] (P2W) Shop-Techniken im Kampfprotokoll mit einem kleinen Rissglas-Zeichen versehen, damit der Gegner sie erkennt.
4487. [P3] (P2W) Die Gegner-KI so anpassen, dass sie Shop-Techniken des Spielers richtig einschätzt (Schaden, Zusatzwirkung) und nicht naiv handelt.
4488. [P3] (P2W) Ein "Technik-Tausch" anbieten, mit dem eine gelernte Shop-Technik gegen eine andere Shop-Technik getauscht wird, Preis 200 Rissglas.
4489. [P3] (P2W) Für jede Era eine eigene Rissschrift-Optik zeichnen.
4490. [P3] (P2W) Die Stärke aller Shop-Techniken in `docs/BALANCE.md` in einer eigenen Tabelle "Shop-Techniken" führen.
4491. [P3] (P2W) Eine Rissschrift "Wächterbann" anlegen, die gegen Rift-Wächter doppelten Schaden macht und sonst Stärke 60 hat, Preis 700 Rissglas.
4492. [P3] (P2W) Shop-Techniken nicht auf der Liste der Tagesfunde anbieten, damit nichts Kostenpflichtiges als Zufallsfund erscheint.
4493. [P3] (P2W) Shop-Techniken beim Laden alter Spielstände prüfen und bei fehlender Berechtigung durch die nächstbeste freie Technik ersetzen.
4494. [P3] (P2W) Shop-Techniken in Rift-Born erlauben, aber ihre Zusatzwirkung dort abschalten.

### Energie-Starthilfe und Kampfhilfen
4495. [x] [P1] (P2W) Den "Überladekern" (`rg_overcharge`) anlegen: das ganze Team startet den nächsten Kampf mit 12 statt 10 Energie und Höchstenergie 12, Preis 100 Rissglas pro Stück, 5 Stück für 400 Rissglas.
4496. [x] [P1] (P2W) Den "Rissatem" (`rg_rift_breath`) anlegen: belebt im Kampf einen besiegten Spirling mit 50 % Kraft wieder, höchstens 1 pro Kampf, Preis 200 Rissglas pro Stück.
4497. [x] [P1] (P2W) Den "Großen Rissatem" (`rg_rift_breath_full`) anlegen: belebt im Kampf mit 100 % Kraft und voller Energie, höchstens 1 pro Kampf, Preis 400 Rissglas.
4498. [P1] (P2W) Wiederbeleben im Kampf ist nur möglich, wenn der Gegenstand schon in der Tasche liegt; es erscheint nie ein Kauffenster im Kampf.
4499. [x] [P1] (P2W) Den "Siegeswillen" (`rg_last_stand`) anlegen: wird das ganze Team besiegt, kehrt der zuletzt besiegte Spirling einmal mit 30 % Kraft zurück, Preis 300 Rissglas, nicht gegen Rift-Wächter.
4500. [P1] (P2W) Die Kampfhilfen über die bestehende Gegenstandsaktion im Kampf (`items_allowed_in_battle`) einsetzen und in Rift-Born gesperrt lassen.
4501. [x] [P1] (P2W) Den "Glasfunken" (`rg_glass_spark`) anlegen: füllt im Kampf sofort die Energie eines Spirlings auf und erhöht sie für 3 Runden um 1 pro Runde, Preis 100 Rissglas.
4502. [x] [P1] (P2W) (Umgesetzt ohne "ohne Zug": der Trank braucht den Zug wie jeder Gegenstand.) Einen "Rissglas-Heiltrank" (`rg_glass_tonic`) anlegen: heilt im Kampf 100 % Kraft und alle Zustände, ohne den Zug zu verbrauchen, höchstens 2 pro Kampf, Preis 150 Rissglas.
4503. [P1] (P2W) Die Kampfhilfen in der Tasche in der Gruppe "Rissglas-Waren" führen und im Kampf-Gegenstandsmenü oben anzeigen, wenn vorhanden.
4504. [P1] (P2W) Alle Kampfhilfen im Kampfmodell als Ereignisse (`ItemUsed`, `Revived`) ausgeben, damit Wiederholungen und Records sie korrekt zeigen.
4505. [x] [P1] (P2W) Ein Paket "Kampfvorrat" (5 Rissatem, 5 Überladekerne, 5 Glasfunken) für 1000 Rissglas statt 1500 einzeln anbieten.
4506. [P2] (P2W) Den Gegenstand "Fluchtglas" (`rg_escape_glass`) anlegen: beendet jeden Kampf ohne Verlust, auch gegen Wanderer, nicht gegen Rift-Wächter und Story-Kämpfe, Preis 100 Rissglas.
4507. [P2] (P2W) Den "Schutzschleier" (`rg_veil`) anlegen: das ganze Team nimmt 3 Runden lang 30 % weniger Schaden, wirkt ohne Zugverbrauch, Preis 200 Rissglas.
4508. [P2] (P2W) Den "Wuchtsplitter" (`rg_might_shard`) anlegen: hebt Wucht und Fokus eines Spirlings sofort um 2 Stufen, stärker als `power_brew`, Preis 100 Rissglas.
4509. [P2] (P2W) Den "Tempospiegel" (`rg_haste_mirror`) anlegen: das Team handelt 2 Runden lang vor dem Gegner, unabhängig von Tempo, Preis 200 Rissglas.
4510. [P2] (P2W) Den "Zweitzug-Kristall" (`rg_double_turn`) anlegen: ein Spirling handelt in dieser Runde zweimal, höchstens 1 pro Kampf, Preis 300 Rissglas.
4511. [P2] (P2W) Die Kampfhilfen ohne Zugverbrauch im Kampfmenü mit dem Hinweis "kostet keinen Zug" kennzeichnen.
4512. [x] [P2] (P2W) (Umgesetzt als `per_battle` in `data/items.json`, wo die Kampfwirkung steht.) Die Höchstmenge von Kampfhilfen pro Kampf (Rissatem 1, Heiltrank 2, Zweitzug 1, sonst 3) in `data/shop.json` als `per_battle_limit` führen.
4513. [P2] (P2W) Nach einer Niederlage einen Bildschirm "Weiter mit Rissatem?" nur zeigen, wenn der Spieler einen Rissatem besitzt, sonst den normalen Niederlage-Ablauf.
4514. [P2] (P2W) Den Niederlage-Bildschirm nie mit Shop-Hinweisen füllen und ein Test prüft, dass dort kein Shop-Aufruf liegt.
4515. [P2] (P2W) Einen "Rastplatz-Kristall" anlegen, der das Team überall in der Welt sofort voll heilt, ohne zum Rastplatz zu gehen, Preis 100 Rissglas.
4516. [P2] (P2W) Einen "Energieanker" anlegen: das Team verliert 5 Runden lang keine Energie durch gegnerische Techniken, Preis 200 Rissglas.
4517. [P2] (P2W) Einen "Elementschild" anlegen: der nächste starke Element-Treffer gegen das Team wird auf einfachen Schaden gesenkt, Preis 150 Rissglas.
4518. [P2] (P2W) Kampfhilfen in Echo-Duellen mit Freunden erlauben, wenn beide Seiten das in den Duell-Einstellungen zulassen.
4519. [P2] (P2W) Kampfhilfen in der Gleichstand-Liga sperren und im Kampfmenü dort ausgrauen.
4520. [P2] (P2W) Unit-Tests in `tests/test_shop_battle_items.gd` für jede Kampfhilfe, das Limit pro Kampf und die Sperren schreiben.
4521. [P2] (P2W) Die Gegner-KI auf Kampfhilfen des Spielers reagieren lassen, etwa Zustände erneut setzen, wenn der Spieler sie heilt.
4522. [P2] (P2W) Kampfhilfen in Wiederholungen ("Watch last battle") mit ihrem Namen zeigen.
4523. [P2] (P2W) Einen "Überladekern Plus" anlegen: Start mit 14 Energie und Höchstenergie 14 für einen Kampf, Preis 200 Rissglas, nur gegen Rift-Wächter.
4524. [P2] (P2W) Die Höchstenergie-Werte von Überladekernen als Feld `max_energy_bonus` an `Spirling` geben, das beim Kampfende zurückgesetzt wird.
4525. [P2] (P2W) Einen "Dauerkern" anlegen: das Team startet 10 Kämpfe lang mit 12 Energie, Preis 800 Rissglas.
4526. [P2] (P2W) Ein Wochenangebot "Rissatem-Dreierpack" für 500 Rissglas einmal pro Woche anbieten, mit festem Wochenende als Enddatum.
4527. [P2] (P2W) Die Kampfhilfen-Pixelbilder (16 x 16) in `art/shop/battle/` mit klarer Form zeichnen: Rissatem als Hauch, Überladekern als Kristall, Glasfunke als Stern.
4528. [P2] (P2W) Kampfhilfen in Story-Schwierigkeit um 1 pro Kampf großzügiger begrenzen.
4529. [P2] (P2W) Einen "Bannkristall" anlegen, der die Gabe des Gegners für 3 Runden abschaltet, Preis 200 Rissglas, nicht gegen Rift-Wächter.
4530. [P3] (P2W) Einen "Verstärker" anlegen, der die nächste Technik eines Spirlings um 50 % stärkt, Preis 100 Rissglas.
4531. [P3] (P2W) Einen "Heilnebel" anlegen, der das ganze Team um 50 % Kraft heilt, Preis 200 Rissglas, 1 pro Kampf.
4532. [P3] (P2W) Einen "Rissatem für das Team" anlegen, der alle besiegten Team-Mitglieder mit 25 % Kraft zurückbringt, Preis 600 Rissglas, 1 pro Kampf.
4533. [P3] (P2W) Kampfhilfen in Records getrennt zählen ("Siege ohne Rissglas-Waren").
4534. [P3] (P2W) Einen "Schlusszug" anlegen, der den Gegner mit weniger als 10 % Kraft sofort besiegt, Preis 200 Rissglas, nicht gegen Rift-Wächter.
4535. [P3] (P2W) Eine Einstellung "Rissglas-Waren im Kampf nie vorschlagen" anbieten, die sie im Kampfmenü ans Ende schiebt.
4536. [P3] (P2W) Einen "Rückspul-Kristall" anlegen, der die letzte Runde des Kampfes zurücksetzt, 1 pro Kampf, Preis 300 Rissglas, mit dem festen Zufallsgenerator des Kampfes nachvollziehbar.
4537. [P3] (P2W) Den Rückspul-Kristall in Echo-Duellen und Ligen sperren, weil er den Gegner betrifft.
4538. [P3] (P2W) Einen "Zustandsbrecher" anlegen, der alle Zustände des Teams heilt und 3 Runden davor schützt, Preis 150 Rissglas.
4539. [P3] (P2W) Die Wirksamkeit der Kampfhilfen nach 3 Monaten neu bewerten und Preise anpassen, festgehalten in `docs/shop/CHANGELOG.md`.
4540. [P3] (P2W) Im Kampfende-Bildschirm benutzte Rissglas-Waren mit Menge zeigen ("Benutzt: 1 Rissatem").
4541. [P3] (P2W) Für Post-Game-Herausforderungen ein eigenes Kampfhilfen-Limit von 1 Gegenstand pro Kampf setzen.
4542. [P3] (P2W) Kampfhilfen in Era II bis IV mit neuen Bildern zeigen.
4543. [P3] (P2W) Einen "Tarnkristall" anlegen, der 50 Schritte lang keine wilden Begegnungen auslöst, Preis 100 Rissglas.
4544. [P3] (P2W) Den Tarnkristall nicht in Story-Pflichtgebieten mit festen Begegnungen wirken lassen.
4545. [P3] (P2W) Einen "Ankerstein" anlegen, mit dem man nach einer Niederlage am Ort des Kampfes statt am Rastplatz weiterspielt, Preis 100 Rissglas.
4546. [P3] (P2W) Den Ankerstein im Niederlage-Ablauf als Auswahl nur zeigen, wenn er in der Tasche liegt.
4547. [P3] (P2W) Kampfhilfen nicht als Geschenk an Freunde versendbar machen.
4548. [P3] (P2W) Die Wirkung aller Kampfhilfen in einem Abschnitt "Shop-Kampfhilfen" in `docs/BALANCE.md` festhalten.

### Bond-Hilfen
4549. [x] [P1] (P2W) Das "Bondsiegel" (`rg_bond_seal`) anlegen: das nächste Bonden gelingt sicher, nicht bei Rift-Wächtern und einmaligen Spirlings, Preis 500 Rissglas (≈ 4,95 €) oder 4,99 € direkt.
4550. [x] [P1] (P2W) Den "Echo-Duft" (`rg_echo_scent`) anlegen: verbessert das Bonden für einen Versuch spürbar (Wert +0,25 in `BondCalc.chance`), Preis 100 Rissglas.
4551. [P1] (P2W) Bond-Hilfen zeigen nie eine Chance oder Prozentzahl, weder vor noch während des Echo-Minispiels; das Ergebnis erscheint erst danach (Patentregel).
4552. [P1] (P2W) Im Shop die Wirkung des Echo-Dufts in Worten beschreiben ("Bonden gelingt deutlich leichter"), ohne Zahl, und das Bondsiegel als "gelingt sicher".
4553. [P1] (P2W) Der Echo-Duft ist ein fest beschriebener Gegenstand, kein Zufallsinhalt: der Kauf liefert immer genau 1 Duft, nur seine Wirkung im Bonden folgt den normalen Spielregeln.
4554. [P1] (P2W) Die Bond-Hilfen über den Parameter `charm_bonus` in `BondCalc.chance` anbinden und mit `kin_charm` (0,1) nicht stapeln, sondern den höheren Wert nehmen.
4555. [P1] (P2W) Das Bondsiegel setzt die Chance auf 1,0 nach dem Minispiel, das Minispiel bleibt spielbar und wird nur nicht gewertet.
4556. [P1] (P2W) Ein "Echo-Duft-Zehnerpack" für 800 Rissglas statt 1000 anbieten.
4557. [P1] (P2W) Bond-Hilfen in der Tasche und im Bond-Menü des Kampfes anzeigen und nur verwendbar machen, wenn sie schon gekauft sind.
4558. [P2] (P2W) Das "Echo-Gehör" (`rg_echo_ear`) anlegen: das Echo-Minispiel spielt die Melodie dauerhaft einmal mehr vor, Preis 800 Rissglas.
4559. [P2] (P2W) Das "Langsame Echo" (`rg_slow_echo`) anlegen: die Melodie im Minispiel läuft dauerhaft 20 % langsamer, Preis 800 Rissglas.
4560. [P2] (P2W) Den "Fehlerton-Schutz" anlegen: ein falscher Ton im Minispiel zählt für einen Versuch nicht, Preis 100 Rissglas.
4561. [P2] (P2W) Das "Lockglas" (`rg_lure_glass`) anlegen: 30 Schritte lang erscheinen in der aktuellen Karte nur Arten, die noch nicht im Spirlog gebondet sind, Preis 200 Rissglas.
4562. [P2] (P2W) Das Lockglas zeigt nicht, welche Art kommt, damit es keine Ziehung gegen Geld ist; es ändert nur die Begegnungsliste auf ungebondete Arten der Karte.
4563. [P2] (P2W) Das "Seltenheitsglas" nicht anbieten, das seltene Arten wahrscheinlicher macht, weil es einer bezahlten Ziehung zu nahe kommt.
4564. [P2] (P2W) Eine "Bond-Erinnerung" (`rg_bond_memory`) anlegen: misslingt ein Bonden, bleibt der wilde Spirling für einen zweiten Versuch im Kampf, statt zu fliehen, Preis 100 Rissglas.
4565. [P2] (P2W) Einen "Sanften Griff" anlegen: Techniken des Spielers lassen den wilden Gegner bei mindestens 1 Kraft, für einen Kampf, Preis 100 Rissglas.
4566. [P2] (P2W) Bond-Hilfen gegen Rift-Wächter immer sperren und das in der Detailansicht nennen.
4567. [P2] (P2W) Ein Bondsiegel-Dreierpack für 1200 Rissglas statt 1500 anbieten, höchstens 2 Packs pro Woche.
4568. [P2] (P2W) Bond-Hilfen in der Records-Ansicht zählen ("Gebondet mit Siegel: 3").
4569. [P2] (P2W) Im Spirlog keinen Hinweis zeigen, welche Spirlings mit Siegel gebondet wurden, damit der Eintrag gleichwertig bleibt.
4570. [P2] (P2W) Das Echo-Gehör und das Langsame Echo als Nicht-Verbrauchsgüter anlegen, die über "Käufe wiederherstellen" zurückkommen.
4571. [P2] (P2W) Den Barrierefreiheitsmodus des Minispiels (falls vorhanden) kostenlos lassen und das Langsame Echo nur als zusätzlichen Vorteil darüber anbieten.
4572. [P2] (P2W) Unit-Tests in `tests/test_shop_bond.gd` für Siegel, Duft, Stapeln mit `kin_charm`, Wächter-Sperre und fehlende Prozentanzeige schreiben.
4573. [P2] (P2W) `tools/ip_check.sh` prüfen lassen, dass keine Shop-Texte die Wörter "Chance", "Prozent" oder "%" im Zusammenhang mit Bonden enthalten.
4574. [P2] (P2W) Eigene Pixelbilder für Bond-Hilfen in `art/shop/bond/` anlegen: Siegel als Notenschlüssel-Form, Duft als Glasfläschchen, ohne Kugel- oder Kapselform.
4575. [P2] (P2W) Einen "Funkenblick" anlegen, der nach dem Bonden die Funken-Werte des neuen Spirlings in Worten zeigt (Spitze, gut, mittel), dauerhaft, Preis 600 Rissglas.
4576. [P2] (P2W) Einen "Wiederbegegnungs-Kristall" anlegen, mit dem ein geflohener wilder Spirling beim nächsten Schritt sicher wieder erscheint, Preis 200 Rissglas.
4577. [P2] (P2W) Bond-Hilfen in Rift-Born nutzbar lassen, weil Bonden dort kein Kampfgegenstand ist, aber das Siegel dort auf 1 pro Rift-Abschnitt begrenzen.
4578. [P2] (P2W) Bond-Hilfen im Pass mit 3 Echo-Düften pro Woche geben.
4579. [P3] (P2W) Den Echo-Duft auch in Händlerläden für Münzen verbieten, damit der Shop-Gegenstand vom freien `kin_charm` klar getrennt bleibt.
4580. [P3] (P2W) Den Text zum Bondsiegel im Kampf neutral halten: "Das Siegel wirkt. Ruvi bleibt bei dir."
4581. [P3] (P2W) Einen "Doppelfund" anlegen: beim nächsten Bonden einer schon gebondeten Art gibt es zusätzlich 1 Funke auf jeden Wert, Preis 200 Rissglas.
4582. [P3] (P2W) Einen "Wesensruf" anlegen, mit dem der nächste gebondete Spirling die gewählte Wesensart bekommt, Preis 400 Rissglas.
4583. [P3] (P2W) Den Wesensruf so umsetzen, dass er die Wesensart über ein gespeichertes Feld setzt statt über die uid, damit alte Spielstände stabil bleiben.
4584. [P3] (P2W) Eine "Bond-Hilfe für Freundes-Echos" nicht anbieten, weil Echos keine bondbaren Spirlings sind.
4585. [P3] (P2W) Saisonale Bond-Hilfen (Laternen-Duft) mit gleicher Wirkung und anderem Aussehen anbieten.
4586. [P3] (P2W) Nach 3 Monaten prüfen, ob das Bondsiegel das Sammeln entwertet, und gegebenenfalls auf 1 pro Tag begrenzen, mit Hinweis in `docs/shop/CHANGELOG.md`.
4587. [P3] (P2W) Ein "Spirlog-Kompass" anlegen, der dauerhaft auf jeder Karte zeigt, welche ungebondeten Arten dort leben, Preis 600 Rissglas.
4588. [P3] (P2W) Den Spirlog-Kompass nicht mit Begegnungsraten füllen, nur mit Artnamen, damit keine Chancen sichtbar werden.
4589. [P3] (P2W) Bond-Hilfen in Era II bis IV mit neuen Bildern zeigen.
4590. [P3] (P2W) Einen "Ruhigen Rückweg" anlegen, der nach einem gelungenen Bonden das Team um 25 % Kraft heilt, dauerhaft, Preis 400 Rissglas.
4591. [P3] (P2W) Den Echo-Duft als Wochenangebot zum halben Preis einmal pro Konto für Neueinsteiger anbieten.
4592. [P3] (P2W) Die Wirkung der Bond-Hilfen in einem Abschnitt in `docs/BALANCE.md` beschreiben, mit Zahlen nur für Entwickler.

### Team- und Lagerplätze
4593. [x] [P1] (P2W) Einen "Sechsten Team-Platz" (`rg_team_slot_6`) als dauerhaften Kauf anlegen, Preis 1500 Rissglas (≈ 14,85 €) oder 14,99 € direkt, der `GameState.MAX_PARTY` für das Konto auf 6 hebt.
4594. [P1] (P2W) `MAX_PARTY` in `GameState.gd` durch eine Funktion `party_max()` ersetzen, die 5 oder mit Berechtigung 6 liefert, und alle Stellen (`party.size() < MAX_PARTY`) darauf umstellen.
4595. [P1] (P2W) Der sechste Platz gilt in allen Kämpfen gegen die Spielwelt; in der Gleichstand-Liga und in Ligen mit Teamgröße 5 wird nur mit den ersten 5 gekämpft.
4596. [P1] (P2W) Das Team-Menü zeigt den sechsten Platz mit Rissglas-Rand; ohne Kauf ist er nicht sichtbar, damit kein leerer Platz zum Kauf drängt.
4597. [x] [P1] (P2W) Ein Lager-Limit von 150 Plätzen für alle einführen (vorher unbegrenzt) und "Lager-Erweiterung +50" (`rg_storage_50`) für 300 Rissglas anbieten, bis höchstens 600 Plätze. Angepasst an Bereich 1: Lager mit Fächern zu 30 Plätzen (Start 8), Angebot "Lager-Fach +1" (`rg_storage_box`) erhöht `GameState.storage_box_bonus`.
4598. [P1] (P2W) Spirlings über dem neuen Lager-Limit aus alten Spielständen bleiben erhalten; neue Bonden gehen dann nur noch ins Team, und ein Hinweis erklärt das.
4599. [P1] (P2W) Der Server prüft beim Speichern die Teamgröße gegen die Berechtigung und lehnt 6 Team-Mitglieder ohne Kauf ab, und die Prüfung "mehr als 6" bleibt die harte Grenze.
4600. [P2] (P2W) Einen "Mobilen Lagerzugang" (`rg_storage_anywhere`) anlegen: das Lager öffnet sich überall in der Welt und schon vor dem zweiten geschlossenen Riss, Preis 800 Rissglas.
4601. [P2] (P2W) Den Mobilen Lagerzugang mit dem bestehenden Schalter `RIFTS_FOR_STORAGE` verbinden, sodass die Berechtigung die Rift-Bedingung überspringt.
4602. [P2] (P2W) Einen "Schnelltausch" anlegen: im Kampf darf ein Spirling aus dem Lager einmal pro Kampf ins Team geholt werden, Preis 1200 Rissglas, nicht gegen Rift-Wächter.
4603. [P2] (P2W) Einen "Team-Vorlagen"-Kauf anlegen: 4 gespeicherte Team-Aufstellungen mit Andenken, die mit einem Tippen geladen werden, Preis 400 Rissglas.
4604. [P2] (P2W) Den sechsten Team-Platz im Echo-Team für Freunde erlauben, wenn der Freund ihn auch hat; sonst wird das Echo auf 5 gekürzt.
4605. [P2] (P2W) Das Kampf-Formations-Layout (zwei gerade Reihen) für 6 Spirlings in Mehrfachkämpfen prüfen und den sechsten nur als Reserve führen, ohne die Reihen zu verändern.
4606. [P2] (P2W) Wachstum für den sechsten Platz genauso teilen wie für die anderen, wenn das Team-Wachstumsband aktiv ist.
4607. [P2] (P2W) Ein Bündel "Großes Lager" (3 Erweiterungen +50) für 800 Rissglas statt 900 anbieten.
4608. [P2] (P2W) Unit-Tests in `tests/test_shop_slots.gd` für `party_max`, Lager-Limit, alte Spielstände und Erstattung schreiben.
4609. [P2] (P2W) Die KI-Gegner (Wanderer) bekommen nie einen sechsten Platz, damit der Kauf spürbar bleibt, und das steht in `docs/BALANCE.md`.
4610. [P2] (P2W) Die Team-Ansicht in 144 x 256 für 6 Einträge neu einteilen (6 Zeilen à 32 Pixel) und testen, dass nichts abgeschnitten wird.
4611. [P2] (P2W) Den Lagerzugang im Kindermodus ohne Kauf auf 150 Plätze begrenzen und keine Hinweise auf Erweiterungen zeigen.
4612. [P2] (P2W) Einen "Lager-Wachstumsplatz" anlegen: 2 Spirlings im Lager bekommen 25 % des Kampfwachstums mit, dauerhaft, Preis 600 Rissglas.
4613. [P2] (P2W) Den sechsten Team-Platz in Rift-Born erlauben, weil er kein Kampfgegenstand ist, und das in der Detailansicht sagen.
4614. [P2] (P2W) Spirlings auf Platz 6 im Spirlog-Tracker und in den Tageszielen genauso zählen.
4615. [P3] (P2W) Bei Erstattung des sechsten Platzes wandert der Spirling von Platz 6 ins Lager, auch über dem Lager-Limit.
4616. [P3] (P2W) Einen siebten Platz nie anbieten und das in `docs/MONETIZATION.md` als Grenze festhalten.
4617. [P3] (P2W) Ein Lager-Sortierfeld "Stärkste zuerst" für Käufer der Lager-Erweiterung freischalten.
4618. [P3] (P2W) Einen "Heimkehr-Tausch" anlegen: nach jedem Kampf darf ein Lager-Spirling ohne Rastplatz ins Team wechseln, dauerhaft, Preis 500 Rissglas.
4619. [P3] (P2W) Die Plätze nach 6 Monaten mit den Liga-Daten prüfen und den sechsten Platz in der Offenen Liga begrenzen, falls er dort mehr als 10 % Siegvorteil bringt.
4620. [P3] (P2W) Für den sechsten Platz ein eigenes Pixelsymbol mit Rissglas-Zeichen in `art/shop/slots/` zeichnen.
4621. [P3] (P2W) In Records zählen, wie viele Kämpfe mit 6 Spirlings gewonnen wurden.
4622. [P3] (P2W) Einen "Lagerheiler" anlegen: Spirlings im Lager sind immer voll geheilt, dauerhaft, Preis 300 Rissglas.
4623. [P3] (P2W) Die Lager-Erweiterungen in Era II bis IV mit neuem Lagerbild zeigen.
4624. [P3] (P2W) Einen "Team-Schnellwechsel" in der Welt anbieten, mit dem man eine gespeicherte Vorlage ohne Menü lädt, nur für Käufer der Team-Vorlagen.
4625. [P3] (P2W) Die Begrenzung des Lagers in `server_config` halten, damit sie ohne App-Update änderbar ist.
4626. [P3] (P2W) Den Hinweis "Lager voll" neutral formulieren und nicht mit einem Shop-Button verbinden.
4627. [P3] (P2W) Die Wirkung des Schnelltauschs im Kampfprotokoll zeigen ("Ruvi kommt aus dem Lager.").
4628. [P3] (P2W) Für Spieler mit 600 Lagerplätzen eine Seitenansicht mit 30 Einträgen pro Seite bauen.

### Wanderer-Pass (Abo)
4629. [P1] (P2W) Den "Wanderer-Pass" als Auto-Abo für 4,99 € im Monat anlegen (Apple Abo-Gruppe "Pass", Google Abo `de.chimora.game.pass` mit Grundplan monatlich).
4630. [x] [P1] (P2W) Der Pass gibt dauerhaft für seine Laufzeit +50 % Wachstum für das ganze Team, mit dem Wachstumskristall multiplizierbar.
4631. [x] [P1] (P2W) Der Pass gibt jeden Tag beim ersten Öffnen 30 Rissglas (in 30 Tagen 900 Rissglas, Wert ≈ 8,91 €) und das steht mit genauer Zahl auf der Pass-Seite.
4632. [x] [P1] (P2W) Der Pass gibt jedem Spirling im Team +1 Startenergie über die Höchstenergie (11 statt 10) in allen Kämpfen gegen die Spielwelt.
4633. [x] [P1] (P2W) Der Pass gibt 1 kostenlosen Rissatem pro Rift-Wächterkampf, der nicht in der Tasche liegt, sondern nur im Kampf erscheint.
4634. [x] [P1] (P2W) Der Pass gibt +1 Bond-Versuch pro Kampf: misslingt Bonden, flieht der Spirling nicht sofort.
4635. [x] [P1] (P2W) Der Pass-Status kommt nur vom Server (`subscriptions`), und alle Pass-Vorteile prüfen `ShopEffects.pass_active()`.
4636. [x] [P1] (P2W) Die Pass-Seite listet alle Vorteile mit Zahlen, den Preis "4,99 € pro Monat", "verlängert sich automatisch" und "jederzeit im Store kündbar".
4637. [x] [P1] (P2W) Die täglichen 30 Rissglas sammeln sich nicht an, wenn man nicht spielt; verpasste Tage gehen nicht verloren, sondern werden beim nächsten Öffnen bis höchstens 7 Tage nachgezahlt.
4638. [x] [P1] (P2W) Mit dem Ende des Passes enden alle Vorteile sofort; schon gutgeschriebenes Rissglas und Gegenstände bleiben.
4639. [P1] (P2W) Für die erste Pass-Buchung eine kostenlose Probezeit von 7 Tagen über den Store anbieten und das Datum der ersten Abbuchung deutlich zeigen.
4640. [P2] (P2W) Einen Jahresplan für 39,99 € im Jahr (statt 59,88 €) über den Store anbieten.
4641. [P2] (P2W) Der Pass gibt jede Woche 1 Wachstumskristall (x2, 20 Kämpfe) und 3 Echo-Düfte in die Tasche.
4642. [P2] (P2W) Der Pass gibt +25 % Münzen aus Kämpfen gegen Wanderer, abgestimmt mit der Münz-Wirtschaft von Bereich 8.
4643. [P2] (P2W) Der Pass macht den Mobilen Lagerzugang für die Laufzeit frei, auch ohne dauerhaften Kauf.
4644. [P2] (P2W) Der Pass senkt die Rissglas-Preise im Shop um 10 % (auf volle 10 abgerundet), sichtbar als zweite Preiszeile.
4645. [P2] (P2W) Die Pass-Rabatte so runden, dass Preise weiter durch 100 teilbar sind, also nur auf Angebote ab 1000 Rissglas anwenden.
4646. [P2] (P2W) Der Pass gibt 1 zusätzlichen Andenken-Doppelplatz für die Laufzeit.
4647. [P2] (P2W) Der Pass heilt das Team nach jedem gewonnenen Kampf um 20 % Kraft.
4648. [P2] (P2W) Der Pass hebt die Begrenzung der Rematches gegen besiegte Wanderer auf 3 pro Tag statt 1.
4649. [P2] (P2W) Der Pass gibt doppelte Belohnung beim Tagesfund (Daily Find) des Spiels.
4650. [P2] (P2W) Ein Pass-Symbol (Rissglas-Kompass) im Wanderer-Profil zeigen, nur wenn der Spieler das in den Einstellungen will.
4651. [P2] (P2W) Der Pass ist in der Gleichstand-Liga ohne Wirkung, und die Pass-Seite sagt das in einer eigenen Zeile.
4652. [x] [P2] (P2W) Pass-Vorteile in Echo-Duellen nur für Wachstum und Münzen wirken lassen, nicht für Energie und Rissatem.
4653. [P2] (P2W) Abo-Ereignisse vom Server (Verlängerung, Ablauf, Kulanzzeit, Kündigung) im Spiel als Satz zeigen: "Dein Pass läuft am 6. 12. ab."
4654. [P2] (P2W) In der Kulanzzeit (Zahlung fehlgeschlagen) die Pass-Vorteile bis zu 16 Tage behalten und einen Hinweis zeigen, die Zahlungsart im Store zu prüfen.
4655. [P2] (P2W) Für unter 18-Jährige die Probezeit nicht anbieten, damit keine überraschende Abbuchung entsteht.
4656. [P2] (P2W) Eine Pass-Erinnerung 3 Tage vor Ende der Probezeit im Spiel zeigen ("Ab dem 13. 11. kostet der Pass 4,99 € pro Monat.").
4657. [P2] (P2W) Den Pass nicht mit Bündeln verbinden, damit Spieler ihn einzeln verstehen und kündigen.
4658. [P2] (P2W) Unit-Tests in `tests/test_shop_pass.gd` für Aktivierung, Tagesgutschrift, Nachzahlung bis 7 Tage, Ablauf, Kulanzzeit und Gleichstand-Liga schreiben.
4659. [P2] (P2W) Die Tagesgutschrift serverseitig mit einem Eintrag pro Kalendertag (Europa/Berlin) in `ledger` sichern, damit Gerätezeit nichts ändert.
4660. [P2] (P2W) Für Google den Pass mit `basePlanId` "monthly" und "yearly" anlegen und Wechsel zwischen beiden als Planwechsel behandeln.
4661. [P2] (P2W) Für Apple den Pass in einer Abo-Gruppe mit zwei Stufen (Monat, Jahr) anlegen, damit Wechsel ohne Doppelabo möglich sind.
4662. [P2] (P2W) Der Pass gibt in Rift-Born keinen Rissatem, weil dort keine Kampfgegenstände erlaubt sind.
4663. [P2] (P2W) Eine Pass-Übersicht "Was der Pass dir diesen Monat gab" mit Rissglas, Wachstum und Gegenständen zeigen.
4664. [P2] (P2W) Die Pass-Wirkung im Kampfende-Bildschirm getrennt ausweisen ("+60 Wachstum durch den Pass").
4665. [P2] (P2W) Den Pass in Familienfreigabe (Apple) erlauben und die Pass-Vorteile dem jeweiligen Familienkonto geben.
4666. [P2] (P2W) Die Pass-Seite in der Gleichstand-Liga-Ansicht verlinken, damit klar ist, was dort nicht wirkt.
4667. [P2] (P2W) Den Pass nach einer Rückbuchung sofort beenden und die gutgeschriebenen 30 Rissglas der betroffenen Tage abziehen.
4668. [P3] (P2W) Keine "Treuestufen" einführen, bei denen lange Pass-Laufzeit mehr Vorteile bringt, damit Kündigen nicht bestraft wird.
4669. [P3] (P2W) Einen "Pass Plus" für 9,99 € im Monat nicht anbieten, damit es nur eine Pass-Stufe gibt; das in `docs/MONETIZATION.md` festhalten.
4670. [P3] (P2W) Monatliche Pass-Kosmetik (eine Jackenfarbe pro Monat), die dauerhaft bleibt, als Zusatz geben.
4671. [P3] (P2W) Nach 6 Monaten prüfen, ob +50 % Wachstum zu stark ist, und den Wert in `server_config` anpassbar halten.
4672. [P3] (P2W) Ein Pass-Angebotscode für Support-Fälle (1 Monat) über die Store-Werkzeuge vorsehen.
4673. [P3] (P2W) Einen "Pass-Kalender" im Shop zeigen, an welchen Tagen Rissglas gutgeschrieben wurde.
4674. [P3] (P2W) Pass-Vorteile in Post-Game-Herausforderungen wirken lassen, aber einen eigenen Rekord "ohne Pass" führen.
4675. [P3] (P2W) Der Pass gibt 1 Bondsiegel pro Monat.
4676. [P3] (P2W) Der Pass gibt Zugang zu einem zusätzlichen Speicherplatz (Slot 4) für die Laufzeit; nach Ablauf bleibt der Spielstand lesbar, aber nur Slot 1 bis 3 sind beschreibbar.
4677. [P3] (P2W) Die Pass-Seite in Era II bis IV mit neuem Bild zeigen.
4678. [P3] (P2W) Für die Rückkehr nach einer Kündigung keine Lockangebote mit Druck zeigen, nur den normalen Pass.
4679. [P3] (P2W) Eine Erklärung "Pass oder Rissglas-Pakete?" mit Rechenbeispiel in die Shop-Hilfe aufnehmen.
4680. [P3] (P2W) Den Pass im Titelbildschirm nicht erwähnen.
4681. [P3] (P2W) Pass-Vorteile im Kindermodus nicht anzeigen und den Pass dort nicht buchbar machen.
4682. [P3] (P2W) Die Tagesgutschrift von 30 Rissglas mit einem ruhigen Hinweis "Pass: +30 Rissglas" beim ersten Öffnen zeigen, ohne Fenster, das man wegtippen muss.
4683. [P3] (P2W) Pass-Daten für Ali als Monatssumme ohne Personenbezug im Tagesbericht des Billing-Dienstes zeigen.

### Starter- und Fortschrittspakete
4684. [x] [P1] (P2W) Ein "Starterpaket" (`rg_starter`) für 2,99 € einmal pro Konto anlegen: 300 Rissglas, 5 Ring-Tränke, 1 Wachstumskristall x2, 3 Rissatem, 3 Echo-Düfte.
4685. [P1] (P2W) Das Starterpaket zeigt den Einzelwert ("einzeln 1300 Rissglas, ≈ 12,87 €") und den Preis 2,99 € und ist erst nach dem ersten geschlossenen Riss sichtbar.
4686. [P1] (P2W) Ein "Wanderer-Paket" (`rg_wayfarer_pack`) für 9,99 € einmal pro Konto anlegen: 1000 Rissglas, Rissherz, Glasschild, 2 Große Ring-Tränke, 1 Bondsiegel.
4687. [P1] (P2W) Ein "Rift-Paket" pro geschlossenem Riss anlegen (6 Pakete, je einmal), für 4,99 €: 2 Große Ring-Tränke, 1 Element-Prisma nach Wahl, 5 Rissatem.
4688. [x] [P1] (P2W) Pakete liefern feste Inhalte, die vor dem Kauf vollständig gelistet sind; Wahlteile (Element-Prisma) werden vor dem Kauf ausgewählt, nicht danach zugelost.
4689. [x] [P1] (P2W) Alle Pakete als einmalige Verbrauchsgüter im Store anlegen und das Einmal-Limit auf dem Server über `purchases` prüfen.
4690. [P1] (P2W) Ein "Aufholpaket" für Rückkehrer (30 Tage nicht gespielt) für 4,99 € anlegen: 5 Große Ring-Tränke und 1 Wachstumskristall x3, einmal pro Konto.
4691. [x] [P1] (P2W) Pakete erscheinen im Reiter "Pakete" und nie als Fenster beim Spielstart oder nach Story-Szenen.
4692. [P2] (P2W) Ein "Entfaltungs-Paket" für 4,99 € anlegen: 2 Entfaltungs-Tränke und 1 Gezeitenglas, einmal pro Konto.
4693. [P2] (P2W) Ein "Technik-Paket" für 9,99 € anlegen: 4 Rissschriften nach Wahl und 1 Technik-Platz 5.
4694. [P2] (P2W) Ein "Team-Paket" für 19,99 € anlegen: sechster Team-Platz, 2 Lager-Erweiterungen, 1 Andenken-Doppelplatz, einmal pro Konto.
4695. [P2] (P2W) Ein "Wächter-Paket" pro Riss für 2,99 € anlegen: 1 Überladekern Plus, 2 Großer Rissatem, 1 Wächterglas auf Probe für 3 Wächterkämpfe.
4696. [P2] (P2W) Das Wächter-Paket erscheint erst, nachdem der Spieler den Wächter einmal ohne Hilfe versucht hat, und nie direkt nach der Niederlage, sondern frühestens beim nächsten Shop-Besuch.
4697. [P2] (P2W) Ein "Post-Game-Paket" für 9,99 € anlegen: Ring-Elixier, Wachstumskristall x3, 2 Bondsiegel, einmal pro Konto.
4698. [P2] (P2W) Ein "Sammler-Paket" für 4,99 € anlegen: 10 Echo-Düfte, 2 Lockgläser, 1 Echo-Gehör.
4699. [P2] (P2W) Paketpreise nur aus den Stufen 2,99 €, 4,99 €, 9,99 € und 19,99 € wählen, keine Pakete über 19,99 €.
4700. [P2] (P2W) Für jedes Paket den Nachlass gegenüber den Einzelteilen als Rissglas-Zahl zeigen, nie als "xx % gratis".
4701. [P2] (P2W) Pakete nach Spielfortschritt freischalten (Riss 1, 2, 3, Post-Game), damit sie zu dem passen, was der Spieler gerade braucht.
4702. [P2] (P2W) Die Freischaltbedingungen der Pakete in `data/shop.json` als `unlock` (`rifts_sealed >= 2`) führen und im Shop nennen.
4703. [P2] (P2W) Abgelaufene oder gekaufte Pakete aus dem Reiter entfernen und unter "Meine Käufe" weiter zeigen.
4704. [P2] (P2W) Keine personalisierten Paketpreise einsetzen: jeder Spieler mit gleichem Fortschritt sieht den gleichen Preis.
4705. [P2] (P2W) Pakete im Kindermodus nicht zeigen.
4706. [P2] (P2W) Für 13 bis 15 Jahre die Pakete über 9,99 € nicht zeigen.
4707. [P2] (P2W) Die Inhalte von Paketen nach dem Kauf einzeln in die Tasche und als Berechtigung schreiben, in einer Server-Transaktion.
4708. [P2] (P2W) Bei Erstattung eines Pakets alle noch ungenutzten Teile entfernen und für verbrauchte Teile das Rissglas-Guthaben belasten.
4709. [P2] (P2W) Ein "Element-Paket" pro Element für 4,99 € anlegen: Element-Prisma, Rissschrift des Elements, 3 Große Ring-Tränke.
4710. [P2] (P2W) Element-Pakete auf eines pro Element und Konto begrenzen.
4711. [P2] (P2W) Ein "Wochenpaket" für 1,99 € anlegen: 3 Ring-Tränke, 3 Rissatem, 1 Überladekern, einmal pro Woche, fester Inhalt.
4712. [P2] (P2W) Das Wochenpaket hat jede Woche denselben Inhalt, damit niemand auf "bessere Wochen" wartet.
4713. [P2] (P2W) Ein "Neues-Kapitel-Paket" zur Story-Fortsetzung (Mirelas Kartenbuch) für 4,99 € anlegen: 2 Ring-Elixiere, einmal pro Konto, erst nach Kapitelstart sichtbar.
4714. [P2] (P2W) Unit-Tests in `tests/test_shop_packs.gd` schreiben, die Einmal-Limits, Freischaltungen, Inhaltslisten und Wahlteile prüfen.
4715. [P2] (P2W) Pakete im Shop mit einem eigenen Pixelbild (Bündel mit Rissglas-Band) zeigen, ohne geschlossene Truhen oder Kisten.
4716. [P2] (P2W) Pakete mit Wahlteilen zeigen die Wahl als Liste vor dem Kaufdialog, und der Server speichert die Wahl mit dem Kauf.
4717. [P2] (P2W) Ein "Freundes-Paket" nicht anbieten, das Freunden Vorteile schenkt, damit keine Geldgeschenke zwischen Konten laufen.
4718. [P2] (P2W) Das Starterpaket für Spieler unter 16 Jahren nicht zeigen, damit es nicht als Einstieg in Käufe wirkt.
4719. [P2] (P2W) Ein "Story-Schnellstart-Paket" für 4,99 € anlegen: ganzes Team auf Ring 15, einmal pro Spielstand, nur Story und Tamer.
4720. [P2] (P2W) Den Story-Schnellstart erst nach dem ersten Riss anbieten und vorher die Bestätigung zeigen, welche Spirlings wie hoch steigen.
4721. [P2] (P2W) Ein "Rift-Born-Paket" nicht anbieten, damit die schwerste Stufe ohne Kaufvorteile im Kampf bleibt; nur Ring-Tränke sind dort nutzbar.
4722. [P3] (P2W) Die Inhalte aller Pakete in `docs/MONETIZATION.md` mit Einzelwert und Paketpreis in einer Tabelle zeigen.
4723. [P3] (P2W) Ein "Era-II-Paket" zum Start der nächsten Era für 9,99 € planen: 2 Ring-Elixiere, 2 neue Element-Prismen im Era-II-Stil, einmal pro Konto.
4724. [P3] (P2W) Ein "Jubiläumspaket" zum ersten Jahrestag für 4,99 € planen, mit festem Inhalt und ohne "nur heute".
4725. [P3] (P2W) Ein "Lernpaket" für Spieler mit vielen Niederlagen nicht automatisch zeigen; Niederlagen steuern keine Angebote.
4726. [P3] (P2W) Ein "Glanzform-Paket" für 9,99 € anlegen: 1 Glanzform-Prisma und 1 Funkenschmiede.
4727. [P3] (P2W) Paketinhalte bei späteren Änderungen nur für neue Käufe ändern und alte Käufe nicht anfassen.
4728. [P3] (P2W) Nach 6 Monaten prüfen, welche Pakete gekauft werden, nur als Summen, und schwache Pakete in `docs/shop/CHANGELOG.md` einstellen.
4729. [P3] (P2W) Ein "Lager-Starter" für 1,99 € anlegen: 1 Lager-Erweiterung und Lagerheiler, einmal pro Konto.
4730. [P3] (P2W) Ein "Technik-Starter" für 1,99 € anlegen: 1 Rissschrift nach Wahl und 1 Frühschrift, einmal pro Konto.
4731. [P3] (P2W) Ein "Bond-Starter" für 0,99 € anlegen: 3 Echo-Düfte, einmal pro Konto, ab 16 Jahren.
4732. [P3] (P2W) Paket-Bilder in Era II bis IV neu zeichnen.
4733. [P3] (P2W) Pakete, die Ali einstellt, bleiben in "Meine Käufe" mit Inhalt sichtbar.
4734. [P3] (P2W) Ein "Herausforderungs-Paket" für die Post-Game-Herausforderungen für 4,99 € anlegen: 3 Überladekerne Plus, 3 Großer Rissatem.
4735. [P3] (P2W) Für jedes Paket einen festen Zeitraum der Verfügbarkeit von mindestens 30 Tagen nach Freischaltung festlegen, damit kein Druck entsteht.
4736. [P3] (P2W) Den Zeitraum in der Detailansicht nennen ("verfügbar bis 6. 12.") und nach Ablauf nach 90 Tagen erneut anbieten.
4737. [P3] (P2W) Ein "Spirlog-Paket" für 4,99 € anlegen: Spirlog-Kompass, 5 Lockgläser.
4738. [P3] (P2W) Pakete im Store mit eigenem Produkttext anlegen, der den Inhalt genauso nennt wie im Spiel.
4739. [P3] (P2W) Ein "Komplett-Glaswerk" für 19,99 € anlegen: alle 5 Grund-Andenken (Rissherz, Glasschild, Klarsplitter, Wirbelglas, Kernglas), einmal pro Konto.
4740. [P3] (P2W) Ein "Zwillingspaket" für Spieler mit zwei Spielständen nicht anbieten; Pakete sind pro Konto.

### Funken und Wesensart
4741. [x] [P1] (P2W) Eine "Funkenschmiede" (`rg_spark_forge`) anlegen, die alle Funken-Werte (`Spirling.spark`) eines Spirlings auf den Höchstwert 12 setzt, Preis 1000 Rissglas (≈ 9,90 €) oder 9,99 € direkt.
4742. [x] [P1] (P2W) Einen "Funkensplitter" (`rg_spark_shard`) anlegen, der einen gewählten Wert um 6 Funken erhöht (bis 12), Preis 200 Rissglas, doppelt so stark wie `spark_charm` (3).
4743. [P1] (P2W) Einen "Wesenswandel" (`rg_temper_shift`) anlegen, der die Wesensart eines Spirlings auf eine gewählte Wesensart setzt, Preis 400 Rissglas.
4744. [P1] (P2W) Für den Wesenswandel ein gespeichertes Feld `temper_override` an `Spirling` anlegen, das `temperament_index(uid)` überschreibt, und in `SaveManager` sichern.
4745. [P1] (P2W) Funken-Käufe zeigen vor dem Einsatz die neuen Werte (Kraft, Wucht, Schutz, Fokus, Tempo) und brauchen eine Bestätigung.
4746. [P1] (P2W) Die Funken-Werte im Team-Menü in Worten anzeigen, wie es `GameState.SPARK_WORDS` schon tut, und Käufe nicht als Zahl ausweisen.
4747. [P1] (P2W) Der Server prüft beim Speichern, dass Funken-Werte über dem natürlichen Bereich nur mit verbrauchten Funken-Käufen oder `spark_charm` vorkommen.
4748. [P1] (P2W) Funken- und Wesensart-Käufe wirken in der Gleichstand-Liga nicht, weil dort Werte ausgeglichen werden, und das steht im Angebot.
4749. [P1] (P2W) Ein Bündel "Fünf Funkensplitter" für 800 Rissglas statt 1000 anbieten.
4750. [P1] (P2W) Ein "Kraftkern" anlegen, der den Faktor einer Wesensart von 1,1 auf 1,2 für einen Spirling hebt, dauerhaft, Preis 800 Rissglas.
4751. [P2] (P2W) Eine "Doppelwesen-Gabe" anlegen, mit der ein Spirling zwei Wesensart-Boni gleichzeitig hat, Preis 1500 Rissglas, höchstens 3 Spirlings pro Konto.
4752. [P2] (P2W) Einen "Funkenrücksetzer" anlegen, der die Funken eines Spirlings auf neue feste Werte nach Wahl verteilt (insgesamt 48 Punkte), Preis 500 Rissglas.
4753. [P2] (P2W) Den Funkenrücksetzer ohne Zufall umsetzen: der Spieler verteilt die Punkte selbst auf die 5 Werte.
4754. [P2] (P2W) Funken-Käufe auf das Spirling-Objekt und nicht auf die Art wirken lassen, damit `Database` unverändert bleibt.
4755. [P2] (P2W) Einen "Gabenwechsel" anlegen, der einem Spirling eine andere Gabe seiner Art gibt, falls die Art mehrere Gaben hat, Preis 500 Rissglas.
4756. [P2] (P2W) Eine "Verborgene Gabe" für jede Art anlegen, die nur über den Shop-Kauf "Gabenschlüssel" für 1000 Rissglas freigeschaltet wird, mit Werten in `docs/BALANCE.md`.
4757. [P2] (P2W) Die verborgenen Gaben in `data/spirlings.json` als Feld `shop_trait_id` führen und in der Gleichstand-Liga durch die normale Gabe ersetzen.
4758. [P2] (P2W) Die 21 verborgenen Gaben mit eigenen Namen und Wirkungen in `BattleRules.trait_info` anlegen und mit `tools/ip_check.sh` prüfen.
4759. [P2] (P2W) Unit-Tests in `tests/test_shop_spark.gd` für Funkenschmiede, Splitter, Wesenswandel, Rücksetzer und Speicherprüfung schreiben.
4760. [P2] (P2W) Funken-Käufe nach dem Entfalten erhalten lassen.
4761. [P2] (P2W) Funken-Käufe in Echo-Teams für Freunde mitnehmen.
4762. [P2] (P2W) Den Wesenswandel in Rift-Born erlauben, da er außerhalb des Kampfes wirkt.
4763. [P2] (P2W) Funkensplitter auf 20 Käufe pro Woche begrenzen.
4764. [P2] (P2W) Eine Funkenschmiede für das ganze Team ("Team-Schmiede") für 4000 Rissglas statt 5000 anbieten.
4765. [P2] (P2W) Die Pixelbilder für Funken-Waren (Amboss mit Funken, Splitter mit Wertfarbe) in `art/shop/spark/` zeichnen.
4766. [P2] (P2W) Die Funken-Werte im Spirlog für gekaufte Werte nicht markieren, damit Spirlings gleich aussehen.
4767. [P2] (P2W) Einen "Wertefokus" anlegen, der einen Wert eines Spirlings dauerhaft um 5 % erhöht, bis zu 3 Mal pro Wert, Preis 300 Rissglas pro Stufe.
4768. [P2] (P2W) Den Wertefokus in der Werteansicht als "+5 %" sichtbar machen, nur für den Besitzer.
4769. [P2] (P2W) Den Wertefokus in der Gleichstand-Liga ausschalten.
4770. [P2] (P2W) Den Wertefokus in den Formeln in `Spirling.gd` als eigenen Faktor `shop_mult` neben `_temper_mult` führen.
4771. [P2] (P2W) Die Höchstwerte aller Funken- und Wertekäufe in `docs/BALANCE.md` festhalten: Funken 12, Wertefokus +15 %, Wesensart 1,2.
4772. [P3] (P2W) Funken-Käufe bei Erstattung nicht rückgängig machen, sondern das Guthaben belasten.
4773. [P3] (P2W) Ein "Funkenerbe" anlegen, mit dem die Funken-Werte eines Spirlings auf einen anderen der gleichen Art übertragen werden, Preis 400 Rissglas.
4774. [P3] (P2W) Funkenerbe nur zwischen eigenen Spirlings erlauben, nie zwischen Konten.
4775. [P3] (P2W) Funken-Käufe in Post-Game-Rekorden mit eigener Wertung "ohne Shop" führen.
4776. [P3] (P2W) Eine Übersicht "Wertekäufe" im Team-Menü zeigen, welche Spirlings welche Käufe haben.
4777. [P3] (P2W) Funken-Waren in Era II bis IV neu zeichnen.
4778. [P3] (P2W) Nach 3 Monaten die Wirkung des Wertefokus mit dem Simulator prüfen und auf +4 % senken, wenn die Siegquote um mehr als 10 % steigt.
4779. [P3] (P2W) Den Gabenschlüssel nur für Arten anbieten, die der Spieler schon gebondet hat.
4780. [P3] (P2W) Verborgene Gaben im Spirlog als "?" zeigen, bis sie freigeschaltet sind, mit Beschreibung im Shop.
4781. [P3] (P2W) Den Funkenrücksetzer in Story-Schwierigkeit für 300 Rissglas anbieten.
4782. [P3] (P2W) Funken-Käufe nicht in den Tagesfunden erscheinen lassen.
4783. [P3] (P2W) Eine "Wesens-Vorschau" anlegen, die vor dem Wesenswandel alle Wesensarten mit ihrem Effekt auf den Spirling zeigt.
4784. [P3] (P2W) Den Wesenswandel für Spirlings im Lager direkt im Lager-Menü anbieten.
4785. [P3] (P2W) Wesensarten-Namen und Wirkungen in `data/i18n/` vollständig auf Deutsch und Englisch pflegen.
4786. [P3] (P2W) Funkenschmieden im Pass um 10 % günstiger machen (900 Rissglas statt 1000), passend zur Pass-Rabattregel ab 1000 Rissglas.
4787. [P3] (P2W) Funken-Käufe in Wiederholungen nicht anzeigen, weil sie keine Kampfereignisse sind.
4788. [P3] (P2W) Eine Grenze von 10 Funkenschmieden pro Monat setzen.
4789. [P3] (P2W) Die Formel der Funken in `Spirling.gd` (Gewicht 0,5) unverändert lassen und Shop-Vorteile nur über `shop_mult` geben, damit freie Werte gleich bleiben.
4790. [P3] (P2W) Die verborgenen Gaben nach 6 Monaten neu bewerten und zu starke Gaben mit Ersatz abschwächen.

### Glanzformen von Spirlings
4791. [P1] (P2W) Ein "Glanzform-Prisma" (`rg_gleam_prism`) anlegen, das einen gewählten eigenen Spirling dauerhaft in seine Glanzform verwandelt, Preis 1500 Rissglas (≈ 14,85 €) oder 14,99 € direkt.
4792. [P1] (P2W) Eine Glanzform hat +10 % auf Kraft, Wucht, Schutz, Fokus und Tempo und eine eigene Farbpalette mit Rissglas-Schimmer.
4793. [P1] (P2W) Der Spieler wählt vor dem Kauf genau den Spirling aus, der Glanzform wird; es gibt keine zufällige Glanzform gegen Geld.
4794. [P1] (P2W) Die Glanzform als Feld `gleam: bool` an `Spirling` speichern und in den Wertformeln als Faktor 1,1 in `shop_mult` einrechnen.
4795. [P1] (P2W) Glanzformen über Paletten-Tausch im Shader zeigen, wie die Kosmetik-Farbtöne, damit pro Era keine neuen Sprites nötig sind.
4796. [P1] (P2W) Glanzformen wirken in der Gleichstand-Liga nur als Aussehen; ihre +10 % werden dort entfernt.
4797. [P1] (P2W) Der Server prüft beim Speichern, dass jede Glanzform zu einem verbrauchten Glanzform-Prisma gehört.
4798. [P1] (P2W) Glanzformen auf 2 Käufe pro Woche begrenzen.
4799. [P2] (P2W) Eine "Glanz-Technik" für jede Glanzform anlegen: die Signatur-Technik der Art bekommt +10 Stärke, solange der Spirling Glanzform ist.
4800. [P2] (P2W) Die Glanzform beim Entfalten erhalten, sodass die entfaltete Form auch Glanzform ist.
4801. [P2] (P2W) Glanzformen im Spirlog mit eigenem Bild zeigen, nur wenn der Spieler eine besitzt.
4802. [P2] (P2W) Glanzformen in Echo-Teams für Freunde mit ihrem Aussehen und ihren Werten zeigen.
4803. [P2] (P2W) Ein "Glanz-Ei" oder andere verdeckte Glanzform-Käufe nicht anbieten; jede Glanzform ist ein sichtbarer, gewählter Spirling.
4804. [P2] (P2W) Die Glanzform-Paletten für alle 21 Arten in `art/shop/gleam/palettes.json` anlegen und mit dem Kontrastmodus prüfen.
4805. [P2] (P2W) Im Kampfbild eine Glanzform am Rissglas-Schimmer (2 helle Pixel, langsam wandernd) erkennbar machen.
4806. [P2] (P2W) Glanzformen in Rift-Born erlauben, da sie kein Kampfgegenstand sind.
4807. [P2] (P2W) Eine "Glanz-Aura" anlegen: eine Glanzform startet jeden Kampf mit +1 Stufe Tempo, Preis 500 Rissglas als Zusatz zur Glanzform.
4808. [P2] (P2W) Die Glanz-Aura in der Gleichstand-Liga abschalten.
4809. [P2] (P2W) Unit-Tests in `tests/test_shop_gleam.gd` für Werte, Entfalten, Gleichstand-Liga, Speicherprüfung und Erstattung schreiben.
4810. [P2] (P2W) Bei Erstattung des Prismas die Glanzform entfernen, den Spirling aber behalten.
4811. [P2] (P2W) Ein Bündel "Glanz-Trio" (3 Glanzform-Prismen) für 4000 Rissglas statt 4500 anbieten.
4812. [P2] (P2W) Glanzformen in Records als eigene Zahl führen ("Glanzformen: 2").
4813. [P2] (P2W) Eine Glanzform-Vorschau im Shop zeigen: Bild und neue Werte des gewählten Spirlings vor dem Kauf.
4814. [P2] (P2W) Glanzformen nur für Spirlings ab Ring 10 anbieten, damit sie zu einem gewachsenen Teammitglied passen.
4815. [P3] (P2W) Die Werte der Glanzform in der Werteansicht als "+10 %" in Rissglas-Farbe ausweisen.
4816. [P3] (P2W) Eine zweite Glanzstufe "Hochglanz" (+15 %) nach 6 Monaten prüfen und nur freigeben, wenn die Liga-Daten keinen Ausreißer zeigen.
4817. [P3] (P2W) Glanzformen in Era II bis IV mit angepasster Palette pro Era zeigen.
4818. [P3] (P2W) Wild auftretende Glanzformen nie einführen, damit Glanz klar ein Shop-Kauf bleibt und nicht mit Zufall vermischt wird.
4819. [P3] (P2W) Einen "Glanz-Rückwandler" anlegen, der eine Glanzform auf einen anderen eigenen Spirling überträgt, Preis 500 Rissglas.
4820. [P3] (P2W) Die Glanzform beim Fotomodus mit Schimmer zeigen.
4821. [P3] (P2W) Glanzformen in Wiederholungen mit Palette zeigen.
4822. [P3] (P2W) Eine Einstellung "Glanz-Schimmer ausblenden" anbieten, die nur das Aussehen ändert.
4823. [P3] (P2W) Glanzformen nicht in Gegnerteams der Wanderer und Wächter verwenden.
4824. [P3] (P2W) Eine Glanzform-Galerie im Menü zeigen, die alle eigenen Glanzformen listet.
4825. [P3] (P2W) Die Glanz-Technik-Werte in `docs/BALANCE.md` in der Tabelle "Shop-Techniken" führen.
4826. [P3] (P2W) Nach 3 Monaten prüfen, ob Glanzformen in Echo-Duellen zu oft gewinnen, und dann nur dort auf +7 % senken.
4827. [P3] (P2W) Die Glanzform als Teil des Komplett-Glanz-Angebots für Ali in `docs/MONETIZATION.md` mit Preis und Begründung beschreiben.
4828. [P3] (P2W) Ein saisonales Glanzform-Prisma mit gleicher Stärke und Winter-Schimmer anbieten.
4829. [P3] (P2W) Glanzformen im Kindermodus nicht anbieten.
4830. [P3] (P2W) Glanzformen in den Post-Game-Herausforderungen als "mit Shop" werten.
4831. [P3] (P2W) Die Glanzform-Paletten mit `tools/ip_check.sh` auf rot-weiße Kugelfarben und fremde Farbfolgen prüfen.

### Zeit- und Fortschrittsbeschleuniger
4832. [P1] (P2W) Eine "Kampfbeschleunigung x4" (`rg_battle_speed`) dauerhaft für 500 Rissglas anlegen, zusätzlich zur freien Stufe x2, die Text und Animationen viermal schneller spielt.
4833. [P1] (P2W) Ein "Auto-Kampf" (`rg_auto_battle`) dauerhaft für 1000 Rissglas anlegen, bei dem die Spieler-KI (Stufe "lookahead") gegen wilde Spirlings automatisch kämpft.
4834. [P1] (P2W) Den Auto-Kampf nie gegen Rift-Wächter, Story-Kämpfe und in Ligen erlauben, und das steht in der Detailansicht.
4835. [x] [P1] (P2W) Einen "Münzglanz" (`rg_coin_boost`) anlegen: doppelte Münzen aus Kämpfen für 20 Kämpfe, Preis 200 Rissglas, abgestimmt mit Bereich 8.
4836. [P1] (P2W) Einen "Wegweiser" (`rg_fast_travel`) dauerhaft für 800 Rissglas anlegen, mit dem Schnellreise zu jedem besuchten Ort geht statt nur zu Rastplätzen.
4837. [P1] (P2W) Den Wegweiser mit `GameState.travel_targets` verbinden, sodass er alle besuchten Karten zusätzlich liefert.
4838. [P1] (P2W) Einen "Begegnungsruf" (`rg_encounter_call`) anlegen: 30 Schritte lang doppelt so viele wilde Begegnungen, Preis 100 Rissglas.
4839. [P1] (P2W) Einen "Kampf-Überspringer" (`rg_skip_battle`) anlegen: ein wilder Kampf gegen einen Gegner mit mindestens 10 Ringen weniger wird sofort gewonnen, mit vollem Wachstum, Preis 100 Rissglas pro 10 Stück.
4840. [P1] (P2W) Kampf-Überspringer laufen über das normale Kampfmodell mit Spieler-KI im Hintergrund und erzeugen ein Ergebnis-Ereignis, damit Wachstum und Münzen korrekt sind.
4841. [P1] (P2W) Einen "Rematch-Schlüssel" anlegen: ein besiegter Wanderer kann am selben Tag erneut gefordert werden, Preis 100 Rissglas.
4842. [P2] (P2W) Eine "Wiederholungs-Rast" anlegen: das Team heilt sich nach jedem Kampf vollständig, dauerhaft, Preis 1000 Rissglas.
4843. [P2] (P2W) Einen "Tagesfund-Kompass" anlegen: der Tagesfund (Daily Find) zeigt seinen Ort auf der Karte, dauerhaft, Preis 400 Rissglas.
4844. [P2] (P2W) Einen "Zweiten Tagesfund" anlegen: jeden Tag ein zusätzlicher Tagesfund mit festem Gegenstand (Tonic), dauerhaft, Preis 600 Rissglas.
4845. [P2] (P2W) Einen "Fundsinn" anlegen: versteckte Gegenstände auf Karten blinken im Umkreis von 4 Feldern, dauerhaft, Preis 500 Rissglas.
4846. [P2] (P2W) Den Auto-Kampf mit dem festen Zufallsgenerator des Kampfes laufen lassen, damit Ergebnisse nachvollziehbar und als Wiederholung abspielbar sind.
4847. [P2] (P2W) Den Auto-Kampf in Rift-Born nicht erlauben.
4848. [P2] (P2W) Ein "Ziel-Wachstum" anlegen: der Auto-Kampf endet automatisch, wenn ein gewählter Spirling einen gewählten Ring erreicht, Teil des Auto-Kampf-Kaufs.
4849. [P2] (P2W) Den Auto-Kampf beim Pausieren der App (`NOTIFICATION_APPLICATION_PAUSED`) sofort anhalten, damit nichts im Hintergrund läuft.
4850. [P2] (P2W) Eine "Schnellheilung" an Rastplätzen ohne Animation für 200 Rissglas dauerhaft anbieten.
4851. [P2] (P2W) Einen "Gegenstand-Magnet" anlegen: nach jedem wilden Kampf gibt es zusätzlich 1 Tonic, dauerhaft, Preis 800 Rissglas.
4852. [P2] (P2W) Einen "Quest-Kompass" anlegen: offene Ziele in "Goals" zeigen den Ort auf der Karte, dauerhaft, Preis 400 Rissglas.
4853. [P2] (P2W) Einen "Story-Sprung" nicht anbieten, der Story-Kapitel überspringt, damit die Geschichte nicht gekauft wird.
4854. [P2] (P2W) Unit-Tests in `tests/test_shop_speed.gd` für Kampf-Überspringer, Auto-Kampf-Sperren, Begegnungsruf und Wegweiser schreiben.
4855. [P2] (P2W) Den Begegnungsruf und den Tarnkristall nicht gleichzeitig wirken lassen; der zuletzt genutzte gilt.
4856. [P2] (P2W) Den Kampf-Überspringer im Kampf-Start-Bildschirm als Auswahl "Sofort gewinnen (1 Überspringer)" nur zeigen, wenn er in der Tasche liegt.
4857. [P2] (P2W) Ein Bündel "Schnellspieler" (Kampfbeschleunigung x4, Wegweiser, Wiederholungs-Rast) für 2000 Rissglas statt 2300 anbieten.
4858. [P2] (P2W) Den Münzglanz mit dem Pass-Bonus addieren (+100 % und +25 %), nicht multiplizieren, und das in `docs/BALANCE.md` festhalten.
4859. [P2] (P2W) Den Münzglanz auf 5 Käufe pro Woche begrenzen, damit die Münz-Wirtschaft nicht kippt.
4860. [P2] (P2W) Den Auto-Kampf als Einstellung mit "Stopp bei niedriger Kraft unter 30 %" ausstatten.
4861. [P2] (P2W) Die Kampfbeschleunigung x4 in Echo-Duellen nur lokal wirken lassen.
4862. [P2] (P2W) Einen "Rastplatz-Ruf" anlegen, mit dem man von überall zum letzten Rastplatz reist, dauerhaft, Preis 300 Rissglas.
4863. [P2] (P2W) Den Kampf-Überspringer gegen Wanderer nicht erlauben, nur gegen wilde Spirlings.
4864. [P2] (P2W) Den Kampf-Überspringer beim Bonden sperren; ein übersprungener Kampf bietet kein Bonden an.
4865. [P2] (P2W) Einen "Wachstums-Rechner" anlegen, der zeigt, wie viele Kämpfe bis zum nächsten Ring fehlen, dauerhaft, Preis 200 Rissglas.
4866. [P3] (P2W) Den Auto-Kampf mit Kampf-Überspringern kombinierbar machen, damit Spieler Wachstum schnell sammeln.
4867. [P3] (P2W) Einen "Nachtwanderer" anlegen, der die Tageszeit im Spiel auf Wunsch wechselt, damit zeitabhängige Spirlings erscheinen, dauerhaft, Preis 600 Rissglas.
4868. [P3] (P2W) Den Nachtwanderer nur einsetzen, wenn Bereich 2 oder 3 Tageszeiten baut; sonst entfällt das Angebot.
4869. [P3] (P2W) Eine "Tagesziel-Erneuerung" anlegen, die ein Tagesziel einmal pro Tag neu würfelt, nicht angeboten, weil Würfeln gegen Geld vermieden wird.
4870. [P3] (P2W) Stattdessen eine "Tagesziel-Wahl" anlegen, bei der der Spieler aus 3 festen Tageszielen wählt, dauerhaft, Preis 400 Rissglas.
4871. [P3] (P2W) Kampf-Überspringer nach 3 Monaten neu bewerten und bei zu starker Nutzung die Ringgrenze auf 15 erhöhen.
4872. [P3] (P2W) Den Auto-Kampf in Era II bis IV mit neuer Anzeige zeigen.
4873. [P3] (P2W) Eine Anzeige "Auto-Kampf aktiv" mit Stopp-Knopf oben im Bild zeigen.
4874. [P3] (P2W) Einen "Doppelschritt" anlegen, mit dem der Wanderer auf Wunsch doppelt so schnell läuft, dauerhaft, Preis 300 Rissglas.
4875. [P3] (P2W) Den Doppelschritt mit dem Raster-Bewegungs-Tween so abstimmen, dass die Kamera weiter ganzzahlig bleibt.
4876. [P3] (P2W) Den Doppelschritt mit der normalen Laufanimation in doppeltem Takt darstellen, ohne neue Bewegungsarten.
4877. [P3] (P2W) Zeitbeschleuniger in Records nicht als Vorteil zählen, weil sie das Ergebnis nicht ändern; Auto-Kampf und Überspringer dagegen schon.
4878. [P3] (P2W) Die Beschleuniger in Post-Game-Herausforderungen sperren, außer der Kampfbeschleunigung.
4879. [P3] (P2W) Den Tagesfund-Kompass mit dem Hinweistext aus `DailyFind.hint` verbinden.
4880. [P3] (P2W) Einen "Rissweg" anlegen, der den Weg zum nächsten offenen Riss auf der Karte zeigt, dauerhaft, Preis 300 Rissglas.
4881. [P3] (P2W) Alle Beschleuniger im Kindermodus nicht anbieten.
4882. [P3] (P2W) Die Wirkung aller Beschleuniger in einem Abschnitt "Shop-Beschleuniger" in `docs/BALANCE.md` festhalten.

### Rift- und Wächter-Hilfen
4883. [P1] (P2W) Eine "Wächterkunde" (`rg_warden_lore`) anlegen, die vor einem Rift-Wächterkampf dessen Team, Techniken und Gaben zeigt, dauerhaft, Preis 600 Rissglas.
4884. [P1] (P2W) Einen "Rissanker" (`rg_rift_anchor`) anlegen: nach einer Niederlage gegen einen Wächter startet der nächste Versuch direkt vor dem Wächter mit voll geheiltem Team, Preis 100 Rissglas pro Versuch.
4885. [P1] (P2W) Einen "Wächterschwächer" (`rg_warden_weaken`) anlegen: der Wächter startet mit 15 % weniger Kraft, Preis 300 Rissglas, höchstens 1 pro Wächterkampf.
4886. [P1] (P2W) Wächter-Hilfen sind nur nutzbar, wenn der Spieler den Wächter mindestens einmal ohne Hilfe versucht hat, damit der erste Versuch fair bleibt.
4887. [P1] (P2W) Die Ring-Obergrenze nach einem Riss bleibt auch mit Wächter-Hilfen bestehen; Hilfen umgehen nie die Obergrenze in Veteran und Rift-Born.
4888. [P1] (P2W) Wächter-Hilfen in Rift-Born sperren, damit die schwerste Stufe ihren Ruf behält.
4889. [P1] (P2W) Wächter-Hilfen im Kampfmodell als Zustände am Wächter setzen (`WardenWeakened`) und als Ereignis ausgeben, damit Wiederholungen stimmen.
4890. [P1] (P2W) Ein "Wächter-Bündel" (Wächterkunde, 3 Wächterschwächer, 5 Rissanker) für 1500 Rissglas statt 1900 anbieten.
4891. [P2] (P2W) Einen "Elementblick" anlegen: im Kampf gegen Wächter zeigt jede Technik, ob sie stark, normal oder schwach wirkt, dauerhaft, Preis 400 Rissglas.
4892. [P2] (P2W) Den Elementblick in Story-Schwierigkeit nicht anbieten, weil dort schon alle Paarungen sichtbar sind.
4893. [P2] (P2W) Einen "Wächterruf" anlegen, mit dem besiegte Wächter einmal pro Woche erneut gefordert werden können, mit vollem Wachstum, Preis 200 Rissglas.
4894. [P2] (P2W) Einen "Rissvorrat" anlegen: in Riss-Abschnitten vor dem Wächter liegen 2 zusätzliche Tonics, dauerhaft, Preis 400 Rissglas.
4895. [P2] (P2W) Einen "Rissschlüssel" anlegen: ein Riss-Abschnitt mit Rätsel kann übersprungen werden, Preis 200 Rissglas, nicht in Story-Pflichtrissen beim ersten Mal.
4896. [P2] (P2W) Den Rissschlüssel nur anbieten, wenn Bereich 2 oder 3 Rätsel in Rissen baut; sonst entfällt das Angebot.
4897. [P2] (P2W) Die Wächterkunde mit Daten aus `data/` (Wächter-Teams) füllen und nicht vom Server laden.
4898. [P2] (P2W) Wächter-Hilfen in den Wiederholungen mit Namen zeigen.
4899. [P2] (P2W) Unit-Tests in `tests/test_shop_warden.gd` für Schwächer, Anker, Erstversuch-Pflicht, Rift-Born-Sperre und Obergrenze schreiben.
4900. [P2] (P2W) Einen "Wächterstarter" anlegen: das Team handelt in der ersten Runde gegen Wächter immer zuerst, Preis 200 Rissglas.
4901. [P2] (P2W) Einen "Siegelschutz" anlegen: der Wächter kann 3 Runden lang keine Zustände auf das Team setzen, Preis 200 Rissglas.
4902. [P2] (P2W) Wächter-Hilfen auf 3 verschiedene Hilfen pro Wächterkampf begrenzen.
4903. [P2] (P2W) Nach einem Sieg mit Wächter-Hilfen die gleiche Belohnung geben wie ohne, aber in Records "mit Hilfe" vermerken.
4904. [P2] (P2W) Den Wächterschwächer für die Post-Game-Wächter sperren.
4905. [P2] (P2W) Die Gegner-KI des Wächters nicht verändern, wenn Hilfen wirken; nur Werte und Startbedingungen ändern sich.
4906. [P3] (P2W) Wächter-Hilfen im Kindermodus nicht zeigen.
4907. [P3] (P2W) Einen "Wächter-Probelauf" anlegen: ein Übungskampf gegen den Wächter ohne Folgen, Preis 100 Rissglas.
4908. [P3] (P2W) Den Probelauf nicht in Rift-Born anbieten.
4909. [P3] (P2W) Wächter-Hilfen nach 3 Monaten mit den Siegquoten pro Wächter (nur Summen) prüfen und Preise anpassen.
4910. [P3] (P2W) Wächter-Hilfen in Era II bis IV mit neuem Bild zeigen.
4911. [P3] (P2W) Einen "Rissatlas" anlegen, der alle Riss-Abschnitte mit Gegenständen und Wegen zeigt, dauerhaft, Preis 500 Rissglas.
4912. [P3] (P2W) Den Wächterschwächer im Kampfprotokoll nennen ("Der Wächter ist geschwächt.").
4913. [P3] (P2W) Wächter-Hilfen nicht automatisch vorschlagen, auch nicht nach mehreren Niederlagen.
4914. [P3] (P2W) Eine "Wächter-Erinnerung" im Spirlog zeigen, welche Wächter mit Hilfe und welche ohne besiegt wurden.
4915. [P3] (P2W) Wächter-Hilfen bei Erstattung nicht rückgängig machen, wenn der Wächter schon besiegt ist.
4916. [P3] (P2W) Einen Wächter-Zusatzlohn ("Wächtertruhe") nicht anbieten, weil Belohnungen gegen Geld zu Zufallsinhalten verleiten.
4917. [P3] (P2W) Wächter-Hilfen in einem Abschnitt in `docs/BALANCE.md` mit allen Zahlen festhalten.
4918. [P3] (P2W) Einen "Doppelwächter-Kampf" für Post-Game nur mit freiem Zugang planen, und Shop-Hilfen dort auf Rissanker beschränken.
4919. [P3] (P2W) Die Wächterkunde-Ansicht in 144 x 256 als Liste mit Seiten bauen.
4920. [P3] (P2W) Die Texte der Wächter-Hilfen auf verbotene Wörter prüfen.
4921. [P3] (P2W) Die Wächter-Hilfen mit Pass-Rabatten nicht kombinieren, damit die Preise klar bleiben.
4922. [P3] (P2W) Einen "Rissanker" für Riss-Abschnitte ohne Wächter nicht anbieten, damit das Erkunden ohne Druck bleibt.

### Online-Vorteile und Liga-Abgrenzung
4923. [x] [P1] (P2W) Jedes Vorteils-Angebot in `data/shop.json` bekommt `league_scope` (`open`, `none`), und der Shop zeigt "wirkt in der Offenen Liga" oder "wirkt nicht in Ligen".
4924. [P1] (P2W) Für die Gleichstand-Liga von Bereich 7 eine Funktion `ShopEffects.strip_for_fair(team)` bauen, die Shop-Andenken, Shop-Techniken, Glanz, Funken- und Wertekäufe aus einem Team entfernt.
4925. [x] [P1] (P2W) Der Server bietet eine RPC-Funktion `shop_effects_for(account_id)`, mit der der Liga-Dienst von Bereich 7 prüft, welche Shop-Vorteile ein Team in der Offenen Liga trägt, und befüllt `server_config.league_fair_blocked_sources` mit allen Herkunftsmarken `rg_*`, die Bereich 7 in der Gleichstand-Liga sperrt.
4926. [P1] (P2W) Shop-Vorteile in der Offenen Liga voll wirken lassen und die Ligaansicht zeigt beim Gegner ein Rissglas-Symbol pro Shop-Vorteil.
4927. [P1] (P2W) Ein "Liga-Kraftpaket" für offene Ligen anlegen: 5 Überladekerne Plus, die nur in der Offenen Liga wirken, Preis 500 Rissglas.
4928. [P1] (P2W) Echo-Duelle mit Freunden bekommen einen Schalter "mit Shop-Vorteilen" oder "ohne", den beide Seiten sehen, voreingestellt "ohne".
4929. [P1] (P2W) Ein "Echo-Verstärker" anlegen: das eigene Echo-Team für Freunde kämpft mit +10 % Werten, wenn der Freund "mit Shop-Vorteilen" spielt, dauerhaft, Preis 800 Rissglas.
4930. [P1] (P2W) Shop-Vorteile, die in der Gleichstand-Liga nicht wirken, werden dort im Team-Menü grau gezeigt, damit Spieler den Unterschied sehen.
4931. [P2] (P2W) Einen "Liga-Wachstumskristall" anlegen: doppeltes Wachstum aus Ligakämpfen für 20 Kämpfe, Preis 200 Rissglas, in beiden Ligen nutzbar, weil Wachstum außerhalb des Ligakampfes wirkt.
4932. [P2] (P2W) Einen "Liga-Rissatem" anlegen, der in der Offenen Liga einmal pro Kampf wiederbelebt, Preis 300 Rissglas.
4933. [P2] (P2W) Einen "Ranglisten-Schutz" nicht anbieten, der Punktverluste verhindert, damit Ranglisten nicht gekauft werden.
4934. [P2] (P2W) Ranglisten und Weltziel (`weekly_scores`, `community_goals`) bekommen eine Spalte `shop_assisted`, damit Bereich 7 getrennte Listen bauen kann.
4935. [P2] (P2W) Beiträge zum Weltziel mit Shop-Beschleunigern zählen normal, aber die Wochenrangliste führt eine zweite Liste "ohne Shop".
4936. [P2] (P2W) Einen "Weltziel-Verstärker" anlegen: eigene Beiträge zum Weltziel zählen 20 Kämpfe lang doppelt, Preis 200 Rissglas.
4937. [P2] (P2W) Den Weltziel-Verstärker auf 2 Käufe pro Woche begrenzen, damit das gemeinsame Ziel nicht von wenigen Käufern abhängt.
4938. [P2] (P2W) Einen "Geschenk-Verstärker" anlegen: Geschenke an Freunde enthalten 1 Tonic mehr, dauerhaft, Preis 400 Rissglas, ohne Rissglas-Waren im Geschenk.
4939. [P2] (P2W) Shop-Vorteile in Echo-Teams speichern (`push_team`) und dem Freund vor dem Duell zeigen.
4940. [P2] (P2W) Der Server prüft bei Ligakämpfen, dass das Team keine Shop-Vorteile trägt, die nicht zum Konto gehören.
4941. [P2] (P2W) Ein "Liga-Team-Platz" nicht anbieten; die Teamgröße der Ligen bestimmt allein Bereich 7.
4942. [P2] (P2W) Unit-Tests in `tests/test_shop_league.gd` für `strip_for_fair`, Echo-Schalter und `league_scope` schreiben.
4943. [P2] (P2W) Die Detailansicht jedes Vorteils zeigt drei Zeilen: Spielwelt, Offene Liga, Gleichstand-Liga, jeweils "wirkt" oder "wirkt nicht".
4944. [P2] (P2W) Einen "Duell-Vorrat" anlegen: 5 Glasfunken, die nur in Echo-Duellen mit Shop-Vorteilen wirken, Preis 300 Rissglas.
4945. [P2] (P2W) In der Offenen Liga höchstens 3 Shop-Kampfhilfen pro Kampf erlauben und das in `data/shop.json` als `open_league_limit` führen.
4946. [P2] (P2W) Den Pass in der Offenen Liga für Wachstum und Münzen wirken lassen und Energie-Vorteile dort abschalten.
4947. [P2] (P2W) Shop-Vorteile in Freundes-Echos für Kinder unter 13 nie zeigen, weil sie den Shop nicht nutzen.
4948. [P2] (P2W) Ein "Echo-Gruß-Verstärker" nicht anbieten, weil feste Grüße kostenlos bleiben.
4949. [P2] (P2W) Die Abgrenzung zur Gleichstand-Liga in einem gemeinsamen Dokument `docs/shop/LIGA_SCHNITTSTELLE.md` beschreiben, das Bereich 7 liest.
4950. [P3] (P2W) Bei Erstattung eines Vorteils laufende Ligakämpfe nicht abbrechen; der Vorteil fällt ab dem nächsten Kampf weg.
4951. [P3] (P2W) Ein "Liga-Abzeichen" für Käufer nicht anbieten, damit die Rangliste nicht nach Ausgaben aussieht.
4952. [P3] (P2W) Nach 3 Monaten die Siegquoten in der Offenen Liga (nur Summen) prüfen und Shop-Vorteile, die mehr als 65 % Siegquote bringen, für offene Ligen begrenzen.
4953. [P3] (P2W) Die Liga-Wirkung jedes Angebots in `server_config` überschreibbar machen, damit Ali einzelne Angebote ohne Update aus der Offenen Liga nehmen kann.
4954. [P3] (P2W) Shop-Vorteile in Liga-Wiederholungen mit Rissglas-Symbol zeigen.
4955. [P3] (P2W) Ein "Liga-Probelauf" anlegen: ein Übungskampf in Offener Liga ohne Wertung, Preis 100 Rissglas.
4956. [P3] (P2W) Den Liga-Probelauf nur anbieten, wenn Bereich 7 Übungskämpfe nicht kostenlos baut.
4957. [P3] (P2W) Die Gegnervorschau in der Offenen Liga um eine Zeile "Shop-Vorteile: 3" ergänzen.
4958. [P3] (P2W) Shop-Vorteile in Freundesranglisten getrennt zeigen.
4959. [P3] (P2W) Die Shop-Vorteile beim Weltziel in Era II bis IV neu bewerten.
4960. [P3] (P2W) Eine Erklärung "Gleichstand-Liga und Offene Liga" in die Shop-Hilfe aufnehmen.
4961. [P3] (P2W) Die Liga-Schnittstelle versionieren (`shop_effects_version`), damit Bereich 7 Änderungen erkennt.
4962. [P3] (P2W) Keine Shop-Vorteile anbieten, die nur in Ligen wirken und dort stärker sind als in der Spielwelt, außer Liga-Kraftpaket, Liga-Rissatem und Duell-Vorrat.

### Wirtschafts-Balance zwischen Münzen und Rissglas
4963. [x] [P1] (P2W) Münzen und Wegmarken bleiben die frei verdienten Spielwährungen aus Bereich 8; Wegmarken werden nie verkauft, und Münzen gibt es gegen Rissglas nur über die festen Münz-Angebote dieses Abschnitts.
4964. [x] [P1] (P2W) Ein "Münzbeutel" (`rg_coins_5000`) anlegen: genau 5000 Münzen für 300 Rissglas, höchstens 3 pro Woche.
4965. [x] [P1] (P2W) Ein "Großer Münzbeutel" (`rg_coins_20000`) anlegen: genau 20000 Münzen für 1000 Rissglas, höchstens 1 pro Woche.
4966. [P1] (P2W) Die Münz-Angebote mit Bereich 8 abstimmen: Ali legt fest, wie viele Münzen ein Spieler pro Stunde verdient, und der Münzbeutel entspricht etwa 2 Stunden Spielzeit.
4967. [x] [P1] (P2W) Rissglas lässt sich nie in den Händlerläden der Welt ausgeben; Händler nehmen nur Münzen.
4968. [x] [P1] (P2W) Shop-Waren mit Kennung `rg_` erscheinen nie in Händlerläden, und ein Test prüft `Overworld._action_shop`-Listen auf diese Kennungen.
4969. [P1] (P2W) Eine Zusammenfassung "Wirtschaft" in `docs/BALANCE.md` anlegen: Münzen pro Stunde, Preise der Händler, Rissglas-Preise, Münzbeutel-Kurs.
4970. [x] [P1] (P2W) Einen "Händlerrabatt" anlegen: 20 % weniger Münzpreise in allen Händlerläden, dauerhaft, Preis 1000 Rissglas.
4971. [x] [P1] (P2W) Den Händlerrabatt in `Overworld._action_shop` über `ShopEffects.merchant_mult()` einrechnen.
4972. [P2] (P2W) Einen "Händlerkatalog" anlegen: alle Händlerläden bieten alle Münz-Waren an, die man schon gesehen hat, dauerhaft, Preis 600 Rissglas.
4973. [P2] (P2W) Einen "Echo-Kristall-Rabatt" anlegen: Echo-Kristalle kosten 1500 statt 3000 Münzen, dauerhaft, Preis 800 Rissglas.
4974. [P2] (P2W) Einen "Verkaufsbonus" anlegen: Gegenstände bringen beim Verkauf an Händler 75 % statt des Grundwerts, dauerhaft, Preis 500 Rissglas, falls Bereich 8 Verkaufen baut.
4975. [P2] (P2W) Die Münz-Obergrenze von Bereich 8 (falls vorhanden) mit Münzbeuteln nicht überschreiten; ein voller Beutel wird nicht gekauft, wenn er die Grenze sprengt.
4976. [P2] (P2W) Münzen aus Münzbeuteln in `ledger` mit Grund `coins_pack` festhalten und dem Spielstand nur als Server-Gutschrift geben.
4977. [P2] (P2W) Der Server prüft beim Speichern, dass der Münzstand nicht schneller wächst als Spielzeit, Kampfbelohnungen und gekaufte Münzbeutel erlauben (Grenzwert in `server_config`).
4978. [P2] (P2W) Spielwerte, die Bereich 8 für Münzen festlegt, nicht wegen des Shops senken; frei verdiente Mengen bleiben wie geplant.
4979. [P2] (P2W) Ein "Münz-Abo" nicht anbieten; Münzen aus dem Pass kommen nur über +25 % Kampfmünzen.
4980. [P2] (P2W) Die frei verdiente Spielzeit bis zum Ende der Story ohne Kauf auf 25 Stunden schätzen und mit Käufen auf 12 Stunden, und beide Werte in `docs/MONETIZATION.md` nennen.
4981. [P2] (P2W) Einen "Rissglas-Wert" für jedes Vorteils-Angebot in Stunden Spielzeit schätzen und Angebote so bepreisen, dass 100 Rissglas etwa 15 Minuten Spielzeit ersparen.
4982. [P2] (P2W) Die Preise der Münz-Waren in Händlerläden nie über die Werte aus `data/items.json` hinaus anheben, damit freie Spieler nicht zum Shop gedrängt werden.
4983. [P2] (P2W) Einen Simulationslauf in `tools/shop/sim_economy.py` bauen, der Spielverlauf mit und ohne Käufe vergleicht (Ringe, Münzen, Spielzeit pro Riss).
4984. [P2] (P2W) Den Simulationslauf in der CI bei Änderungen an `data/shop.json` und `data/items.json` laufen lassen und Abweichungen über 20 % melden.
4985. [P2] (P2W) Rissglas-Waren nicht verkaufbar machen, damit sie nicht in Münzen umgewandelt werden.
4986. [P2] (P2W) Den Tagesfund und Rematch-Preise bleiben frei und werden durch Shop-Käufe nur vermehrt, nie ersetzt.
4987. [P2] (P2W) Ein "Münz-Zinsglas" nicht anbieten, das Münzen über Zeit vermehrt, weil es Spieler zum Horten lenkt.
4988. [P2] (P2W) Ein "Händlerfreund" anlegen: jeder Händlerladen hat einmal pro Tag einen festen Gegenstand zum halben Münzpreis, dauerhaft, Preis 400 Rissglas.
4989. [P2] (P2W) Die Münz-Waren in Händlerläden mit dem Händlerrabatt in der Ladenzeile zeigen ("Tonic 120 Münzen statt 150").
4990. [P2] (P2W) Die Wirtschaftszahlen in `server_config` halten (Münzbeutel-Menge, Rabatte, Grenzwerte), damit Ali ohne Update nachsteuert.
4991. [P3] (P2W) Unit-Tests in `tests/test_shop_economy.gd` für Münzbeutel, Händlerrabatt, Händler-Sperre für `rg_`-Waren und Münz-Obergrenze schreiben.
4992. [P3] (P2W) Nach 3 Monaten die Münzbeutel-Käufe (nur Summen) prüfen und die Menge anpassen, wenn freie Spieler im Vergleich zu weit zurückfallen.
4993. [P3] (P2W) Eine Erklärung "Münzen und Rissglas" in die Shop-Hilfe aufnehmen: Münzen verdienst du im Spiel, Rissglas gibt es nur im Shop.
4994. [P3] (P2W) Das Münz-Symbol und das Rissglas-Symbol klar unterscheidbar zeichnen (Münze rund und gelb, Rissglas eckig und grün).
4995. [P3] (P2W) Einen "Händler-Wegweiser" anlegen, der den nächsten Händlerladen auf der Karte zeigt, dauerhaft, Preis 200 Rissglas.
4996. [P3] (P2W) In Era II bis IV die Münzbeutel-Mengen an die neuen Händlerpreise anpassen.
4997. [P3] (P2W) Eine Grenze setzen, dass ein Spieler höchstens 40000 Münzen pro Woche über Münzbeutel bekommt.
4998. [P3] (P2W) Die Wirtschafts-Balance alle 6 Monate in `docs/shop/CHANGELOG.md` mit Zahlen festhalten.
4999. [P3] (P2W) Ein "Münzen-für-Freunde"-Angebot nicht anbieten, damit keine Werte zwischen Konten fließen.
5000. [P3] (P2W) Eine Jahresübersicht "Münzen und Rissglas" im Shop zeigen, wie viele Münzen aus Spiel, Pass und Münzbeuteln kamen, damit der Spieler den Anteil der Käufe sieht.
