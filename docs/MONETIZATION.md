# Geschäftsmodell (Stand 6. 11. 2026)

**Entscheidung von Ali am 6. 11. 2026:** Chimora ist **kostenlos**. Einnahmen kommen aus einem
In-App-Shop. Rund **2/3 der Angebote geben einen Vorteil im Spiel** ("Vorteil im Spiel", Kennung
`kind: "advantage"` in `data/shop.json`), 1/3 sind Aussehen, Komfort und Rissglas-Pakete.

> **Ersetzt:** Die Entscheidung vom 1. 11. 2026 (Premium, einmal zahlen, kein Shop, kein Pay-to-win)
> und die Zwischenstufe vom Vormittag des 6. 11. ("kostenlos, Shop später, ohne Vorteile") gelten nicht mehr.

Der ganze Shop-Plan steht in `docs/plan5000/10_shop.md` (Punkte 4001 bis 5000). Die rechtliche
Prüfliste steht in [`docs/legal/SHOP_COMPLIANCE.md`](legal/SHOP_COMPLIANCE.md).

## Feste Regeln

Diese Regeln gelten für jedes Angebot. Tests und `tools/ip_check.sh` prüfen sie, wo es geht.

1. **Nur Store-Billing.** Käufe laufen nur über Apple In-App-Kauf (StoreKit 2) und Google Play Billing.
   Keine eigenen Zahlungswege, keine Links zu Zahlseiten. Der Server prüft jeden Beleg, bevor etwas
   gutgeschrieben wird.
2. **Keine Zufallsinhalte gegen Geld.** Keine Lootboxen, keine Gacha, keine Ziehungen, keine
   Chancen. Jeder Kauf liefert genau das, was im Angebot steht (Test: `tests/unit/test_shop_catalog.gd`).
3. **Euro-Preise immer sichtbar.** Store-Preise kommen wörtlich aus der Store-Antwort (Endpreis mit
   Umsatzsteuer). Rissglas-Preise stehen immer mit Euro-Gegenwert da, z. B. "300 Rissglas (≈ 2,97 €)".
4. **Keine Werbung, keine Analytics.** Weiterhin keine Werbe-, Tracking-, Analytics- oder Crash-SDKs.
   Das Billing-Plugin des jeweiligen Stores ist die einzige Ausnahme (AGENTS.md Regel 4, von Ali freigegeben).
5. **Kein Kaufdruck auf Kinder.** Keine direkten Kaufaufforderungen ("Kauf jetzt", "Hol dir", UWG
   Anhang Nr. 28), keine Countdowns, keine Kauffenster im Kampf, nach Niederlagen, beim Bonden oder beim
   Spielstart. Der Shop öffnet sich nur, wenn der Spieler ihn selbst im Menü wählt.
6. **Altersabfrage und Limits.** Beim ersten Öffnen des Shops Geburtsjahr und -monat (Liste), gespeichert
   wird nur die Altersgruppe. Unter 13 ist der Shop gesperrt. Monatslimits: 13 bis 15 Jahre 15 €,
   16 bis 17 Jahre 30 €, ab 18 Jahren 100 € (senkbar, nach 7 Tagen Wartezeit bis 300 € erhöhbar).
7. **Spirlings werden nie verkauft oder getauscht.** Shop-Gegenstände sind nicht tauschbar.
8. **Faire Liga.** Die Gleichstand-Liga (Standard, unter 16 voreingestellt) schaltet gekaufte Vorteile ab.
   Jedes Vorteils-Angebot sagt, ob es in der Offenen Liga wirkt.
9. **Rissglas** (EN "Riftglass") ist die einzige Premium-Währung: 100 Rissglas = 0,99 €, feste Pakete
   ohne Bonusmengen, alle Rissglas-Preise sind Vielfache von 100. Rissglas gibt es nur im Shop (und
   täglich mit dem Wanderer-Pass), nie in der Spielwelt. Händler in der Welt nehmen nur Münzen.
10. **Guthaben liegt nur auf dem Server** (`wallets`, Buchungen in `ledger`), nie im Spielstand.

## Technik in Kürze

| Teil | Datei |
| --- | --- |
| Angebote (einzige Quelle) | `data/shop.json`, geprüft von `scripts/shop/ShopCatalog.gd` |
| Store-Produkte für beide Konsolen | `store/products.json` (gebaut von `tools/shop/build_offers_sql.py`) |
| Billing-Brücke (Google, Apple, lokal) | `scripts/shop/Billing.gd` (Autoload), `scripts/shop/LocalBilling.gd` |
| Shop-Menü, Altersabfrage | `scripts/shop/ShopMenu.gd`, `scripts/shop/AgeGate.gd` |
| Server-Tabellen und Funktionen | `supabase/migrations/20261110000001_shop.sql`, Angebote in `…02_shop_offers.sql` |
| Testserver auf dem Handy | `scripts/shop/LocalShop.gd` (gleiche Regeln wie die SQL-Funktionen) |
| Verbotene Kaufaufforderungen | `data/shop_banned_phrases.json`, geprüft in `tools/ip_check.sh` |

## Was nur Ali tun kann

Siehe Liste in [`docs/shop/ALI_TODO.md`](shop/ALI_TODO.md): Apple-Vertrag "Paid Apps" mit Steuer- und
Bankdaten, Google-Zahlungsprofil (Händlerkonto), In-App-Produkte in beiden Konsolen anlegen (oder einen
API-Zugang dafür geben), Altersfreigaben mit "In-Game-Käufe" neu beantworten.

## Waymarks are never for sale (plan area 8)
Waymarks (the endgame currency) are only earned by playing. They are never sold for money or
for the premium currency, never traded and never sent to friends. In code `Waymarks.TRANSFERABLE`
is false, there is no "shop", "gift" or "trade" source in `Waymarks.SOURCES`, and they are no bag
item, so gifts cannot carry them (`tests/unit/test_waymarks.gd`).
