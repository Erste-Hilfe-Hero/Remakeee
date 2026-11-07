# Shop-Recht: Prüfliste für Angebote und Texte

Stand: 6. November 2026. Plan Bereich 9, Punkte 3931 und 3932. Gilt für jedes Angebot in `data/shop.json`,
jeden Shop-Text in `tools/i18n/`, Store-Texte unter `store/` und Shop-Screenshots. Bereich 10 baut den Shop;
diese Liste ist die rechtliche Abnahme dafür. Erstellt von einer KI, keine anwaltliche Prüfung.

Grundlagen: UWG (besonders Anhang Nr. 28 und § 5a), Richtlinie über unlautere Geschäftspraktiken
2005/29/EG mit den Leitlinien der Kommission von 2021 und den CPC-Grundsätzen zu In-Game-Währungen (2025),
Preisangabenverordnung, §§ 312j, 327 ff., 356 Abs. 5 BGB, JuSchG § 10b (USK-Deskriptoren), Apple App Review
Guidelines 3.1.1, Google-Play-Richtlinie zu Zahlungen und zu Loot Boxes.

## 1. Feste Regel: keine bezahlten Zufallsinhalte (3932)

Chimora verkauft **nichts, dessen Inhalt vom Zufall abhängt**: keine Lootboxen, keine Ziehungen, keine
Kapseln, kein "Glücksrad" gegen Rissglas oder Echtgeld, auch nicht indirekt (Rissglas → Zufallsware).

Jeder Kauf liefert genau die Gegenstände und Mengen, die im Angebot stehen. Wie ein gekaufter Gegenstand
im Spiel wirkt, darf den normalen Spielregeln folgen (zum Beispiel ein Kampf-Gegenstand im Kampf); der
Kauf selbst ist fest.

Warum, kurz:
- **Altersstufe:** Bezahlte Zufallsinhalte führen bei der USK zum Hinweis "In-Game-Käufe + zufällige
  Objekte" und können zu einer höheren Altersstufe führen (USK-Leitkriterien seit 2023). Chimora soll für
  Kinder bleiben.
- **Apple** (Guideline 3.1.1) verlangt, dass die Chancen jeder Zufallsware vor dem Kauf angezeigt werden;
  **Google Play** verlangt das ebenfalls. Ohne Zufallsware entfällt die Pflicht samt Fehlerquelle.
- **Belgien** behandelt bezahlte Lootboxen als Glücksspiel (Spielbehörde 2018); ein Verkauf dort wäre
  ohne Lizenz strafbar. Die **Niederlande** und andere Staaten prüfen ähnliche Regeln, auch das geplante
  EU-Gesetz zur digitalen Fairness.
- **Verbraucherschutz:** Zufallskäufe gelten bei Kindern als besonders beeinflussend; die CPC-Grundsätze
  sehen dort Transparenz- und Schutzpflichten vor, die wir nicht leisten wollen.

Technisch abgesichert durch den Katalog-Test von Bereich 10 (Punkt 4021: `data/shop.json` kennt kein Feld
für Zufall, Ziehung oder Chancen). Wer diese Regel ändern will, muss vorher Altersfreigabe, Store-Angaben,
Nutzungsbedingungen Ziffer 6.3 und diese Datei ändern und Ali fragen.

## 2. Prüfliste für jedes Angebot (3931)

Ein Angebot geht erst live, wenn jede Zeile mit Ja beantwortet ist.

| # | Prüfung | Grundlage |
| --- | --- | --- |
| 1 | Der Text fordert **nicht direkt zum Kauf auf**. Erlaubt: neutrale Beschriftung wie "Preis: 2,99 €", "Rissglas-Paket, 500 Stück". | UWG Anhang Nr. 28 |
| 2 | Der **Endpreis in Euro** steht sichtbar am Angebot, inklusive Mehrwertsteuer, bevor man tippt. Bei Rissglas-Waren steht zusätzlich der Euro-Gegenwert (100 Rissglas = 0,99 €). | PAngV, § 5a UWG, CPC-Grundsätze |
| 3 | **Keine künstliche Zeitnot**: kein laufender Countdown, kein "nur noch heute", kein "nur noch 3 übrig". Ein befristetes Angebot nennt nur ein festes Enddatum und kommt nicht sofort mit neuer Frist zurück. | UWG Anhang Nr. 7, § 4a UWG |
| 4 | **Vorteile sind benannt**: Gibt ein Angebot einen spielerischen Vorteil (Kampf, Liga, Fortschritt), steht das beim Angebot. | § 5a UWG |
| 5 | Inhalt und Menge sind **genau angegeben**, ohne Zufall (Abschnitt 1). | 3932 |
| 6 | **Kein Druck durch das Spiel**: kein Kauf-Hinweis mitten im Kampf oder nach einer Niederlage, kein gesperrter Story-Fortschritt, der nur durch Kauf weitergeht. | § 4a UWG |
| 7 | **Keine Irreführung über Mengen**: kein "Bonus +50 %" ohne Bezugsgröße, kein durchgestrichener Preis, der nie verlangt wurde. | § 5 UWG, § 11 PAngV |
| 8 | Der Kauf läuft **nur über Apple oder Google**; es gibt keinen Link zu einer Bezahlseite außerhalb. | Apple 3.1.1, Google-Play-Zahlungsrichtlinie |
| 9 | Der Kaufknopf im Store-Dialog ist eindeutig beschriftet (die Stores übernehmen das; im Spiel kein eigener "Bestätigen"-Knopf, der wie der Store aussieht). | § 312j BGB |
| 10 | Im **Kindermodus** (Bereich 10) ist das Angebot nicht sichtbar oder gesperrt. | JuSchG, CPC-Grundsätze |
| 11 | Die englische Fassung erfüllt dieselben Punkte (kein "Buy now", "Get it now", "Don't miss out"). | dieselben |
| 12 | Neue gespeicherte Daten zum Kauf stehen vorher in `VERARBEITUNGEN.md` und der Datenschutzerklärung. | Art. 13, 30 DSGVO |

## 3. Verbotene Formulierungen

Gilt für Shop-Texte in allen Sprachen, auch Push-Texte und Store-Screenshots. Die Liste ist für den
Wort-Test von Bereich 10 (Punkt 4022) gedacht.

- Deutsch: "Kauf jetzt", "Jetzt kaufen", "Hol dir", "Sichere dir", "Schnapp dir", "Greif zu", "Nur heute",
  "Nur noch", "Letzte Chance", "Verpasse nicht", "Bevor es weg ist", "Sonst verpasst du".
- Englisch: "Buy now", "Get it now", "Grab", "Don't miss", "Last chance", "Only today", "Before it's gone",
  "Limited time" (ohne festes Datum), "Hurry".

Erlaubt sind sachliche Wörter wie "Angebot", "Preis", "Inhalt", "Enthält", "Verfügbar bis 30. November 2026".

## 4. Widerruf bei digitalen Inhalten

Die Stores holen beim Kauf die Zustimmung zum sofortigen Beginn und die Bestätigung des Verlusts des
Widerrufsrechts ein (§ 356 Abs. 5 BGB). Im Spiel steht dazu nichts Abweichendes; Erstattungen laufen über
den Store. Text dazu: Nutzungsbedingungen Ziffer 6.2 und 6.6.

## 5. Ablauf

1. Bereich 10 legt ein Angebot in `data/shop.json` an; der Katalog-Test prüft Pflichtfelder, Zufallsfreiheit
   und die Wörter aus Abschnitt 3.
2. Im Pull Request wird diese Prüfliste für neue Angebote abgehakt (Vorlage
   `.github/pull_request_template.md`).
3. Vor dem Start des Shops: Altersfragebögen (USK/IARC, Apple) mit "In-Game-Käufe: ja, zufällige Objekte:
   nein" neu beantworten (Plan 3805, 3929, 3930).
