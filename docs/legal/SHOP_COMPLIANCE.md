# Shop: Rechts-Prüfliste

> Erstellt von einer KI ohne anwaltliche Prüfung. Grundlage: Geschäftsmodell in `docs/MONETIZATION.md`
> (kostenlos, Shop mit Rissglas, 2/3 der Angebote mit Vorteil). Jede Zeile nennt die Stelle im Code, die sie
> umsetzt oder prüft. Ändert sich der Shop, wird diese Liste mitgeändert.

## 1. CPC-Leitlinien zu virtueller Währung in Spielen (EU-Verbraucherschutzbehörden, März 2025)

| # | Grundsatz | Umsetzung in Chimora | Datei |
| --- | --- | --- | --- |
| 1 | Preise der virtuellen Währung klar in echtem Geld angeben | Jeder Rissglas-Preis steht mit Euro-Gegenwert da ("300 Rissglas (≈ 2,97 €)"), Kurs fest 100 = 0,99 € | `ShopCatalog.rg_text`, `euro_hint` |
| 2 | Keine Verschleierung der Kosten durch Zwischenwährungen | Jedes Vorteils- und Kosmetik-Angebot ist auch direkt in Euro kaufbar; Pakete ohne Bonusmengen | `data/shop.json` (`eur_cents`), `ShopValidator` |
| 3 | Keine Restmengen, die zum Nachkaufen zwingen | Alle Rissglas-Preise sind Vielfache von 100, Pakete gibt es ab 100 | `ShopValidator` (Regel 4219), `test_shop_catalog.gd` |
| 4 | Vor dem Kauf alle Inhalte und Wirkungen nennen | Detailansicht mit Inhaltsliste, Wirkung in Zahlen, Dauer, Liga-Wirkung | `ShopMenu.detail_text` |
| 5 | Keine Kaufaufforderungen an Kinder | Wortliste verbotener Aufforderungen, geprüft in CI; neutrale Beschriftungen | `data/shop_banned_phrases.json`, `tools/ip_check.sh` |
| 6 | Keine Druck-Taktiken (Countdowns, künstliche Knappheit) | Keine Countdowns, keine Kauffenster im Kampf, nach Niederlagen oder beim Start; Shop nur über das Menü | `PauseMenu.gd` (einziger Einstieg), `ShopMenu.gd` |
| 7 | Bestätigung vor dem Ausgeben, mit Guthaben danach | Dialog "300 Rissglas ausgeben? Dein Guthaben danach: …", "Nein" zuerst und vorausgewählt | `ShopMenu._run_offer` |
| 8 | Klare Information über Widerruf | Hinweis vor dem ersten Kauf mit ausdrücklicher Zustimmung, gespeichert auf dem Server | `ShopMenu._withdrawal_ok`, `shop_withdrawal_ok()` |
| 9 | Zufallsinhalte transparent oder gar nicht | Gar nicht: keine Felder für Zufall, Chancen, Ziehungen; Wahlteile werden vor dem Kauf gewählt | `ShopValidator._check_random`, `_shop_offer_block` (choice) |
| 10 | Schutz Minderjähriger, Ausgabekontrollen | Altersabfrage, unter 13 gesperrt, feste Monatslimits 15 € / 30 €, Erwachsene 100 € (bis 300 € nach 7 Tagen) | `AgeGate.gd`, `shop_set_age`, `_shop_cap`, `shop_set_limit` |
| 11 | Virtuelle Währung verfällt nicht unerwartet | Rissglas verfällt nur mit Kontolöschung; Nutzungsbedingungen 6.4 | `docs/legal/NUTZUNGSBEDINGUNGEN.md` |
| 12 | Kaufübersicht für Spieler | "Meine Käufe" mit Datum, Inhalt, Preis, Erstattungen | `shop_history()`, `ShopMenu.history_text` |

## 2. Deutschland

| Regel | Umsetzung |
| --- | --- |
| UWG Anhang Nr. 28 (keine direkte Kaufaufforderung an Kinder) | Siehe Zeile 5 oben; Shop nie als Fenster |
| § 312j BGB (Bestellbutton) | Zahlung läuft über die Kaufbestätigung von Apple bzw. Google |
| § 356 Abs. 5 BGB (Widerruf digitale Inhalte) | Siehe Zeile 8; Stores holen die Zustimmung ebenfalls ein |
| Preisangabenverordnung (Endpreise) | Euro-Preise kommen wörtlich aus dem Store (Endpreis mit Umsatzsteuer), nie selbst gerechnet (`Billing.price_text`) |
| JuSchG § 10b / USK "In-Game-Käufe" | Altersfreigabe mit Zusatz "In-Game-Käufe" (`STORE_COMPLIANCE.md` Abschnitt 3); keine zufälligen Objekte |
| §§ 104 ff. BGB (Minderjährige) | Limits, Hinweis auf Zustimmung der Eltern in den Nutzungsbedingungen 6.5; Store-Jugendschutz |

### Jugendschutzgesetz und USK

- **§ 10b JuSchG** (seit 2021): Bei der Altersfreigabe zählen auch **Nutzungsrisiken**, darunter
  Kostenfallen durch In-Game-Käufe. Ein Spiel mit Käufen kann darum eine höhere Freigabe bekommen,
  wenn Käufe Druck machen. Chimora mindert das Risiko mit festen Monatslimits, Sperre unter 13,
  ohne Kaufaufforderungen und ohne Zufallsinhalte (Zeilen 5, 6, 9, 10 oben).
- **USK-Hinweise:** Die USK (über IARC) zeigt neben der Altersstufe Zusatzhinweise. **"In-Game-Käufe"**
  heißt: Das Spiel verkauft Inhalte oder Währung gegen Geld. **"In-Game-Käufe + zufällige Objekte"** heißt:
  Darunter sind Käufe mit Zufall (Lootboxen). Für Chimora trifft nur **"In-Game-Käufe"** zu; im
  IARC-Fragebogen wird "zufällige Objekte" mit Nein beantwortet.

## 3. Andere Länder

- **Belgien:** Die belgische Glücksspielkommission stuft bezahlte Lootboxen (Einsatz, Zufall, Gewinn
  mit Wert) seit 2018 als Glücksspiel nach dem Glücksspielgesetz vom 7. 5. 1999 ein; ohne Lizenz sind sie
  verboten. **Niederlande:** Die Kansspelautoriteit sah Lootboxen mit übertragbaren Gewinnen als
  Glücksspiel; der Raad van State hat 2022 enger entschieden, die Politik plant ein Verbot.
  **Chimora bietet keine bezahlten Zufallsinhalte an**, in keinem Land: kein Feld für Chancen, keine
  Ziehungen, jedes Angebot liefert genau seine Liste (`ShopValidator._check_random`). Shop-Teile sind
  außerdem nicht tauschbar, haben also keinen Wert außerhalb des Spiels. Damit greift keines der
  beiden Regime, und es gibt keine Länder-Sonderwege im Code.
- **Apple Guideline 3.1.1 (Käufe):** nur Store-Billing für digitale Inhalte, keine Links zu anderen
  Zahlwegen, "Käufe wiederherstellen" für dauerhafte Inhalte. Umsetzung: `scripts/shop/Billing.gd`
  (`restore`), `ShopMenu.gd` (Eintrag "Käufe wiederherstellen").
- **Apple Guideline 3.1.2 (Abos):** der Wanderer-Pass nennt vor dem Kauf Laufzeit, Preis, automatische
  Verlängerung und den Weg zur Kündigung im Store. Umsetzung: `ShopMenu.pass_text`, Belegprüfung des
  Abos in `server/billing/`.
- **Apple Guideline 5.1.1(v) (Kontolöschung):** Konto lässt sich im Spiel löschen; ein laufendes Abo
  wird dabei nicht vom Spiel gekündigt, der Text sagt, dass es im Store gekündigt werden muss.
  Umsetzung: `scripts/ui/AccountMenu.gd` (Konto löschen), Server-Funktion `delete_account`.
- **Google Payments Policy:** nur Google Play Billing für digitale Inhalte, gleiche Regeln wie oben.

## 4. Offen (braucht Alis Hände)

Siehe `docs/shop/ALI_TODO.md`.
