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

## 3. Andere Länder

- **Belgien, Niederlande:** keine Lootboxen, also kein Glücksspielrecht berührt.
- **Apple Guideline 3.1.1 / Google Payments Policy:** nur Store-Billing für digitale Inhalte, keine Links zu
  anderen Zahlwegen, "Käufe wiederherstellen" für dauerhafte Inhalte (`Billing.restore`).

## 4. Offen (braucht Alis Hände)

Siehe `docs/shop/ALI_TODO.md`.
