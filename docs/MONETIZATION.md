# Geschäftsmodell (Stand 6. 11. 2026)

**Entscheidung von Ali am 6. 11. 2026:** Chimora ist **kostenlos**. Einnahmen kommen aus einem
In-App-Shop. Mindestens **2/3 der Angebote geben einen Vorteil im Spiel** (seit 10. 11. 2026, siehe Pay-to-win unten) ("Vorteil im Spiel", Kennung
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
7. **Spirlings werden nicht getauscht, wenn sie aus dem Shop kommen.** Seit Pay-to-win Schritt 2 (11. 11. 2026,
   Ali) gibt es Spirlings direkt zu kaufen, mit festen Werten und ohne Zufall (siehe unten). Gekaufte
   Spirlings und Shop-Gegenstände sind nicht tauschbar und nicht ausleihbar.
8. **Faire Liga.** Die Gleichstand-Liga (Standard, unter 16 voreingestellt) schaltet gekaufte Vorteile ab.
   Jedes Vorteils-Angebot sagt, ob es in der Offenen Liga wirkt.
9. **Rissglas** (EN "Riftglass") ist die einzige Premium-Währung: 100 Rissglas = 0,99 €, feste Pakete
   ohne Bonusmengen, alle Rissglas-Preise sind Vielfache von 100. Rissglas gibt es nur im Shop (und
   täglich mit dem Wanderer-Pass), nie in der Spielwelt. Händler in der Welt nehmen nur Münzen.
10. **Guthaben liegt nur auf dem Server** (`wallets`, Buchungen in `ledger`), nie im Spielstand.

## Was nie verkauft wird

Diese Dinge gibt es nie gegen Geld oder Rissglas, auch nicht als Teil eines Pakets:

- Story-Kapitel, Regionen und Karten
- der Zugang zu Rissen und Wächtern
- Konto-Funktionen: Spielstand auf dem Server, Übertragungscode, Konto löschen, Datenexport
- Freunde, Grüße, Duelle und Ligen-Teilnahme
- Geschenke an Freunde (sie bleiben kostenlos; gekaufte Grußkarten ändern nur das Aussehen)
- Waymarks (siehe unten). Spirlings gibt es seit Schritt 2 auch zu kaufen, jede Art bleibt aber erspielbar.

## Weitere feste Regeln für Änderungen

- **Kein Abschwächen ohne Ersatz.** Wird ein gekauftes Angebot später schwächer (zum Beispiel aus
  Balance-Gründen), bekommen alle Käufer einen gleichwertigen Ersatz, etwa das Rissglas zurück oder ein
  Angebot mit gleichem Wert. Das steht vorher in den Neuigkeiten des Spiels.
- **Preiserhöhung mit Vorlauf.** Wird ein Angebot teurer, steht das mindestens 7 Tage vorher in den
  Neuigkeiten. Jede Preis- oder Angebotsänderung kommt mit Datum in
  [`docs/shop/CHANGELOG.md`](shop/CHANGELOG.md).
- **Kein Zurück zum Bezahlmodell.** Google Play erlaubt nicht, eine kostenlose App später kostenpflichtig
  zu machen. Der Wechsel auf "kostenlos" ist darum endgültig; ein Bezahlmodell ginge nur als neue App.
- **Abschaltregel.** Wird der Server eingestellt, bekommen Spieler mindestens 3 Monate vorher Bescheid
  (im Spiel und auf der Website; so sagen es die Nutzungsbedingungen, länger als die 60 Tage aus Plan 4019). Der Shop schließt als Erstes, am Tag der Ankündigung. Rissglas und
  Käufe bleiben bis zum Ende nutzbar; für Käufe der letzten 12 Monate gilt die anteilige Erstattung aus
  den Nutzungsbedingungen.
- **Jährlicher Prüftermin: 1. November.** An diesem Tag werden Preise, Angebote, die 2/3-Regel und die
  Rechtslage (`docs/legal/SHOP_COMPLIANCE.md`) neu bewertet. Nächster Termin: 1. 11. 2027.

## Ohne Kauf erreichbar

Jeder Spielinhalt bleibt ohne Kauf erreichbar: alle Regionen, Risse, Wächter, Spirlings, Ligen und die
Story. Käufe machen Wege nur kürzer (mehr Erfahrung, Heilung, Fangen, Plätze), sie schalten keine
Inhalte frei. Planwert für die Story ohne Kauf: **etwa 25 Stunden** (Hauptgeschichte bis zum letzten
Wächter, ohne Nebenziele). Kosmetik ändert nur das Aussehen.

## Pay-to-win, Schritt 1 (Entscheidung von Ali am 10. 11. 2026)

Ali: "200 Punkte Plan, dass es maximal pay2win ist" (Plan freigegeben). Schritt 1 bringt die Bereiche
"Kampfkraft kaufen" und "Fortschritt beschleunigen". **Ersetzt wird dadurch keine der festen Regeln
oben**, auch nicht Regel 7 (keine Spirlings) und Regel 8 (Gleichstand-Liga ohne Kaufvorteile); die kommen
erst in einem späteren Schritt dran. Neu sind nur Angebotsarten. Geändert ist nur der Planwert
"rund 2/3 Vorteile": jetzt **mindestens** 2/3 (Test `test_at_least_two_thirds_are_advantages`).

| Angebot | Wirkung | Rissglas | Liga |
| --- | --- | --- | --- |
| Macht-Siegel I bis VII (`rg_power_seal_1..7`) | +5/10/15/20/25/30/35 % Schaden | 500, 500, 1000, 1500, 2000, 2500, 3000 (Summe 11000) | Offene Liga, Raid-Risse, Geschichte |
| Schutz-Siegel I bis VII (`rg_guard_seal_1..7`) | 5 bis 35 % weniger Schaden | wie Macht-Siegel | Offene Liga, Raid-Risse, Geschichte |
| Tempo-Siegel I bis V (`rg_speed_seal_1..5`) | +5 bis +25 % Tempo (Zugreihenfolge) | 500, 500, 1000, 1500, 2000 (Summe 5500) | Offene Liga, Raid-Risse, Geschichte |
| Wertkristall +1/+5/+10 (`rg_stat_crystal_*`) | Punkte auf einen Wert eines Spirlings, zählen wie Funken, höchstens 24 je Wert (doppelte Funken-Grenze) | 100, 400, 700 | nur Geschichte |
| Mächtiger Wachstumskristall (`rg_growth_x5`) | x5 Wachstum, 20 Kämpfe | 700 | keine Liga-Wirkung |
| Wachstums-Siegel (`rg_growth_plus`) | dauerhaft +50 % Wachstum | 1500 | keine Liga-Wirkung |
| Großer Münzglanz (`rg_coin_boost_x3`) | x3 Münzen, 20 Kämpfe | 400 | keine Liga-Wirkung |
| Riesiger Ring-Trank (`rg_ring_tonic_10`) | +10 Ringe, nie über die Ring-Grenze | 700 | keine Liga-Wirkung |

Wachstum x2/x3, Münzen x2 und Ring-Tränke +1/+5 gab es schon.

- **Stufen:** Jede Siegel-Stufe ist ein eigenes Angebot, einmal je Konto, mit `"requires": "tier:<unlock>:<n>"`:
  Stufe n+1 geht nur, wenn genau n Stufen da sind. Ihr Preis ist die Differenz zur Stufe davor. Der Server
  zählt die Stufen in `entitlements` (`power_seal`, `guard_seal`, `speed_seal`) und prüft die Reihenfolge in
  `_shop_offer_block` (Migration `20261110000027_shop_seals.sql`).
- **Werte in Daten:** Prozente, Kristall-Grenze und Wachstums-Plus stehen in `data/shop.json`
  (`advantage_values`), gelesen von `ShopEffects`. Kampf: `BattleModel.seals` (Schaden in `_do_move`,
  Tempo in `_sort_key`).
- **Ligen:** Die Gleichstand-Liga und Echo-Duelle bekommen nie Siegel (`ShopEffects.seals_for`). Für die
  Offene Liga und Raid-Risse schreibt der Server die Stufen des Spielers in die Erwartung des
  Schiedsrichters (`_league_expect`, `_raid_expect`), nur für die eigene Seite. Wertkristalle wirken dort
  nicht, weil Liga- und Raid-Teams aus Art, Ring und Techniken gebaut werden.
- **Nur Rissglas:** Die neuen Angebote tragen `"rg_only": true` und sind keine Produkte in App Store oder
  Play Store (`store/products.json` bleibt gleich). Der Euro-Gegenwert steht trotzdem an jedem Angebot
  (Regel 3). Offener Punkt für Ali: `SHOP_COMPLIANCE.md` Zeile 2 sagt, jedes Vorteils-Angebot sei auch
  direkt in Euro kaufbar; für diese 26 Angebote gilt das nicht mehr.
- **Kontostärke:** Die Team-Ansicht zeigt "Macht N" = Summe der Siegel-Prozente + 50 mit Wachstums-Siegel
  + Wertkristall-Punkte im Team (`ShopEffects.account_power`).
- Unverändert: keine Zufallsinhalte, Altersabfrage und Monatslimits, keine Kaufaufforderungen, Shop nur
  aus dem Menü, Guthaben nur auf dem Server, jedes Angebot mit "Vorteil im Spiel" und Liga-Zeile, die
  Bond-Grundrate (`BondCalc`) bleibt wie sie ist.

## Pay-to-win, Schritt 3 (Fortschritt beschleunigen, 11. 11. 2026)

Aus Abschnitt 3 des Plans fehlten noch "Sofort Stufe 50", "Münz-Pakete" (große Menge) und "Stufen-Obergrenze
je Riss für Käufer um 5 höher". Stufen-Bonbons +1/+5/+10 sind die Ring-Tränke, die es schon gibt.

| Angebot | Wirkung | Rissglas | Liga |
| --- | --- | --- | --- |
| Ring-Krone (`rg_ring_crown`) | ein Spirling springt auf Ring 50, nie über die Ring-Grenze (`rings_to` in `data/items.json`) | 2000 | keine Liga-Wirkung |
| Ring-Grenzen-Siegel (`rg_ring_cap_plus`) | Ring-Grenze ab Veteran +5 (`advantage_values.ring_cap_plus`, `ShopEffects.ring_cap_bonus`), höchstens Ring 60, einmal je Konto | 1500 | keine Liga-Wirkung |
| Münz-Tresor (`rg_coins_100000`) | genau 100000 Münzen | 3000 | keine Liga-Wirkung |

Die Kontostärke zählt 10 je zusätzlichem Ring. Unverändert: nur Rissglas (`rg_only`), feste Inhalte, Euro-Gegenwert
an jedem Angebot, Altersstufe ab 13 (`min_band`), keine Kaufaufforderungen.
## Pay-to-win, Schritt 4 (Kampfkraft kaufen, Rest, 12. 11. 2026)

Aus Abschnitt 1 des Plans fehlten noch Punkt 16 (Krit-Siegel in 3 Stufen), 17 (Status-Schutz-Amulett),
18 (Start-Schild) und 19 (Anzeige im Kampf, welche Kauf-Vorteile wirken).

| Angebot | Wirkung | Rissglas | Liga |
| --- | --- | --- | --- |
| Krit-Siegel I bis III (`rg_crit_seal_1..3`) | +5 / +10 / +15 Prozentpunkte Chance auf kritische Treffer (Grundchance 1/12) | 500, 1000, 1500 (Summe 3000), Stufen in Reihenfolge (`tier:crit_seal:<n>`) | Offene Liga, Raid-Risse, Geschichte |
| Status-Amulett (`rg_status_ward`) | die Hälfte der Zustände, die der Gegner der eigenen Seite anhängt, scheitert (ein Wurf nur mit Amulett) | 1500, einmal je Konto | Offene Liga, Raid-Risse, Geschichte |
| Eröffnungs-Schild (`rg_start_shield`) | der zuerst geschickte Spirling nimmt vom ersten Treffer mit Schaden nur 50 % | 1500, einmal je Konto | Offene Liga, Raid-Risse, Geschichte |

- **Werte in Daten:** `advantage_values.crit_seal`, `status_ward`, `start_shield` in `data/shop.json`.
- **Zweite Stufen-Zeile:** `BattleModel.amulets` = [Krit, Amulett, Schild] je Seite neben `seals`
  (`ShopEffects.AMULET_KINDS`, `amulets_for`). Replays tragen `amulets`, alte Replays ohne die Zeile laufen
  mit Nullen. Der Server gibt dem Schiedsrichter `amulets` für Offene Liga und Raid-Risse
  (`_shop_amulets`, Migration `20261112120040_shop_p2w_step4.sql`), die Gleichstand-Liga bekommt Nullen.
- **Anzeige im Kampf (Punkt 19):** Zu Kampfbeginn steht eine Zeile "Shop-Vorteile im Einsatz: Macht +35 %, ..."
  (`ShopEffects.edge_line`, Ereignis `SHOP_EDGE`), nur wenn mindestens ein Vorteil wirkt. Kein Knopf in den Shop.
- **Kontostärke** zählt die Prozente der neuen Stufen mit.
- Alle fünf nur für Rissglas (`rg_only`), feste Inhalte, Euro-Gegenwert am Angebot, ab Altersstufe 13.
  **Keine neuen Store-Produkte** (`store/products.json` bleibt gleich).

## Pay-to-win, Schritt 2 (Ali, 11. 11. 2026)

Nächster Block des 200-Punkte-Plans: Siegel-Satz (Punkt 7), Bindungs-Köder in 4 Stufen (Punkt 22) und
Spirlings zum Kauf (Punkte 61, 69, 70, 78, 79). **Ersetzt wird Regel 7** ("Spirlings werden nie verkauft").
Regel 8 (Gleichstand-Liga ohne Kaufvorteile) bleibt.

| Angebot | Wirkung | Preis | Ligen |
| --- | --- | --- | --- |
| Bindungs-Köder I bis IV (`rg_bond_lure_1..4`) | +15 / +30 / +45 / +60 % auf eine Bindung (`bond_bonus`, gedeckelt bei 95 % in `BondCalc`) | 100, 200, 300, 500 Rissglas | nur Story |
| Siegel-Satz (`rg_seal_set`) | Macht VII, Schutz VII, Tempo V auf einmal (19 Stufen); nur ohne jede Siegel-Stufe (`"requires": "none:power_seal,guard_seal,speed_seal"`) | 10000 Rissglas statt 27500 einzeln | Offene Liga, Raids |
| Uralte Spirlings auf Ring 40 (`rg_spirling_<linie>`, 7 Stück) | die Art auf Ring 40, Funken 12 in jedem Wert, Markierung `"shop": true` (`ShopEffects.bought_spirling`) | 19,99 € oder 2000 Rissglas, einmal pro Konto | Werte nur in der Story |

- **Feste Werte, kein Zufall:** Grant `{"t": "spirling", "species": ..., "level": 40}`. Der Server legt ihn
  wie Gegenstände in `deliveries` (`_shop_grant`, Migration `20261111120030_shop_p2w_step2.sql`), das Spiel
  baut den Spirling beim Abholen (`Billing.apply_grant`).
- **Nicht tauschbar:** `TradeMenu.mon_why` und `_trade_mon_why` lehnen Spirlings mit `"shop": true` ab.
- **Zweites Exemplar (Punkt 70):** Der gekaufte Spirling kommt zusätzlich zu dem, den man auf der Reise binden kann.
- Prüfung: `ShopValidator` erlaubt Spirlings nur als `"spirling"`-Grant, `non_consumable`, einmal pro Konto.

### Neue Store-Produkte (in App Store Connect und Play Console anlegen)

Die Bindungs-Köder und der Siegel-Satz sind nur für Rissglas (`rg_only`). Diese 7 Produkte sind neu in
`store/products.json` und müssen in beiden Stores angelegt werden (Apple: Non-Consumable, Google: einmaliges
Produkt, je 19,99 €):

| Produkt-ID | Angebot |
| --- | --- |
| `de.chimora.game.spirling.velahra` | Velahra auf Ring 40 |
| `de.chimora.game.spirling.hallowmur` | Hallowmur auf Ring 40 |
| `de.chimora.game.spirling.scriptorax` | Scriptorax auf Ring 40 |
| `de.chimora.game.spirling.lumivane` | Lumivane auf Ring 40 |
| `de.chimora.game.spirling.zephyrel` | Zephyrel auf Ring 40 |
| `de.chimora.game.spirling.monolurk` | Monolurk auf Ring 40 |
| `de.chimora.game.spirling.vorlucent` | Vorlucent auf Ring 40 |

## Planwerte (nur Rechengrößen, kein Tracking)

| Größe | Planwert |
| --- | --- |
| Anteil zahlender Spieler | 3 % |
| Durchschnittlicher Umsatz je Zahler | 12 € im Monat |

Diese Werte dienen nur zum Rechnen. Das Spiel misst sie nicht: keine Analytics, keine Kaufstatistik je
Spieler außerhalb der Belege, die für Gutschrift und Erstattung nötig sind.

## Technik in Kürze

| Teil | Datei |
| --- | --- |
| Angebote (einzige Quelle) | `data/shop.json`, geprüft von `scripts/shop/ShopCatalog.gd` |
| Store-Produkte für beide Konsolen | `store/products.json` (gebaut von `tools/shop/build_offers_sql.py`) |
| Billing-Brücke (Google, Apple, lokal) | `scripts/shop/Billing.gd` (Autoload), `scripts/shop/LocalBilling.gd` |
| Shop-Menü, Altersabfrage | `scripts/shop/ShopMenu.gd`, `scripts/shop/AgeGate.gd` |
| Server-Tabellen und Funktionen | `supabase/migrations/20261110000020_shop.sql`, Angebote in `…21_shop_offers.sql` |
| Belegprüfung (Apple JWS, Google Play API, Erstattungen, Pass) | `server/billing/` unter `/billing/v1/`, Datenbank-Nutzer `chimora_billing` (`…22_billing.sql`) |
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

## Alle Angebote

<!-- shop-table:start -->

_Erzeugt von `tools/shop/make_shop_table.py`, nicht von Hand ändern._

167 Angebote (Katalog v33): 125 Vorteil, 2 Komfort, 33 Kosmetik, 7 Rissglas.

| Kennung | Name | Euro | Rissglas | Art | Liga |
| --- | --- | --- | --- | --- | --- |
| `rg_glass_100` | 100 Riftglass | 0,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_200` | 200 Riftglass | 1,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_500` | 500 Riftglass | 4,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_1000` | 1000 Riftglass | 9,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_2000` | 2000 Riftglass | 19,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_5000` | 5000 Riftglass | 49,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_glass_10000` | 10000 Riftglass | 99,99 € | - | Rissglas | keine Liga-Wirkung |
| `rg_ring_tonic` | Ring Tonic | 0,99 € | 100 | Vorteil | nur Offene Liga |
| `rg_ring_tonic_5` | Great Ring Tonic | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_ring_elixir` | Ring Elixir | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_growth_x2` | Growth Crystal | 1,99 € | 200 | Vorteil | nur Offene Liga |
| `rg_growth_x3` | Great Growth Crystal | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_share_band` | Team Growth Band | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_ring_tonic_x5` | Ring Tonic x5 | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_riftheart` | Riftheart | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_glass_shield` | Glass Shield | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_clear_shard` | Clear Shard | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_whirl_glass` | Whirl Glass | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_vigor_glass` | Core Glass | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_prism_ember` | Ember Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_tide` | Tide Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_bloom` | Bloom Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_volt` | Volt Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_stone` | Stone Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_gale` | Gale Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_lumen` | Lumen Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_prism_umbra` | Umbra Prism | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_hold_stone` | Hold Stone | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_echo_ring` | Echo Ring | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_script_ember` | Rift Script: Glowglass Slash | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_tide` | Rift Script: Floodglass Wave | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_bloom` | Rift Script: Vineglass Sting | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_volt` | Rift Script: Boltglass Bite | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_stone` | Rift Script: Rockglass Ram | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_gale` | Rift Script: Stormglass Cut | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_lumen` | Rift Script: Lightglass Beam | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_script_umbra` | Rift Script: Duskglass Grip | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_move_memory` | Technique Memory | 5,99 € | 600 | Vorteil | nur Offene Liga |
| `rg_overcharge` | Overcharge Core | 0,99 € | 100 | Vorteil | nur Offene Liga |
| `rg_overcharge_x5` | Overcharge Core x5 | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_rift_breath` | Rift Breath | 1,99 € | 200 | Vorteil | nur Offene Liga |
| `rg_rift_breath_full` | Great Rift Breath | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_last_stand` | Will to Win | 2,99 € | 300 | Vorteil | nur Offene Liga |
| `rg_glass_spark` | Glass Spark | 0,99 € | 100 | Vorteil | nur Offene Liga |
| `rg_glass_tonic` | Riftglass Tonic | 1,99 € | 200 | Vorteil | nur Offene Liga |
| `rg_battle_supply` | Battle Supply | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_bond_seal` | Bond Seal | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_echo_scent` | Echo Scent | 0,99 € | 100 | Vorteil | nur Offene Liga |
| `rg_echo_scent_x10` | Echo Scent x10 | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_team_slot_6` | Sixth Team Place | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_storage_box` | Storage Box +1 | 2,99 € | 300 | Vorteil | nur Offene Liga |
| `rg_pass` | Wayfarer Pass | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_starter` | Starter Pack | 2,99 € | - | Vorteil | nur Offene Liga |
| `rg_wayfarer_pack` | Wayfarer Pack | 9,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_1` | Rift Pack 1 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_2` | Rift Pack 2 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_3` | Rift Pack 3 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_4` | Rift Pack 4 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_5` | Rift Pack 5 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_rift_pack_6` | Rift Pack 6 | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_comeback` | Welcome Back Pack | 4,99 € | - | Vorteil | nur Offene Liga |
| `rg_spark_forge` | Spark Forge | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_spark_shard` | Spark Shard | 1,99 € | 200 | Vorteil | nur Offene Liga |
| `rg_temper_shift` | Temper Shift | 3,99 € | 400 | Vorteil | nur Offene Liga |
| `rg_spark_shard_x5` | Five Spark Shards | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_power_core` | Power Core | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_gleam_prism` | Gleam Prism | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_battle_speed` | Battle Speed x4 | 4,99 € | 500 | Vorteil | keine Liga-Wirkung |
| `rg_auto_battle` | Auto Battle | 9,99 € | 1000 | Vorteil | keine Liga-Wirkung |
| `rg_coin_boost` | Coin Gleam | 1,99 € | 200 | Vorteil | keine Liga-Wirkung |
| `rg_fast_travel` | Signpost | 7,99 € | 800 | Vorteil | keine Liga-Wirkung |
| `rg_encounter_call` | Encounter Call | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_skip_battle` | Battle Skip x10 | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_rematch_key` | Rematch Key | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_warden_lore` | Warden Lore | 5,99 € | 600 | Vorteil | keine Liga-Wirkung |
| `rg_rift_anchor` | Rift Anchor | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_warden_weaken` | Warden Weakener | 2,99 € | 300 | Vorteil | keine Liga-Wirkung |
| `rg_warden_bundle` | Warden Bundle | 14,99 € | 1500 | Vorteil | keine Liga-Wirkung |
| `rg_league_power` | League Power Pack | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_echo_amp` | Echo Amplifier | 7,99 € | 800 | Vorteil | nur Offene Liga |
| `rg_coins_5000` | Coin Purse | 2,99 € | 300 | Vorteil | keine Liga-Wirkung |
| `rg_coins_20000` | Great Coin Purse | 9,99 € | 1000 | Vorteil | keine Liga-Wirkung |
| `rg_merchant_discount` | Merchant Discount | 9,99 € | 1000 | Vorteil | keine Liga-Wirkung |
| `rg_jacket_moss` | Moss Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_plum` | Plum Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_slate` | Slate Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_rust` | Rust Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_sky` | Sky Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_sand` | Sand Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_ink` | Ink Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_jacket_rose` | Rose Jacket | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_moon_lake` | Backdrop: Moon Lake | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_copper_wood` | Backdrop: Copper Wood | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_mist_harbour` | Backdrop: Mist Harbour | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_star_meadow` | Backdrop: Star Meadow | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_ash_field` | Backdrop: Ash Field | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_backdrop_glass_grotto` | Backdrop: Glass Grotto | 2,99 € | 300 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_frame_vine` | Text Frame: Vine | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_frame_brass` | Text Frame: Brass | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_frame_wave` | Text Frame: Wave | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_frame_lantern` | Text Frame: Lantern | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_frame_frost` | Text Frame: Frost | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_wide_brim` | Hat: Wide Brim | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_wool_cap` | Hat: Wool Cap | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_feather_hat` | Hat: Feather Hat | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_lantern_hood` | Hat: Lantern Hood | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_straw_hat` | Hat: Straw Hat | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_hat_tricorn` | Hat: Tricorn | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_leaf` | Card Frame: Leaf | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_shell` | Card Frame: Shell | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_gear` | Card Frame: Gear | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_star` | Card Frame: Star | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_ripple` | Card Frame: Ripple | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_card_frame_ember` | Card Frame: Ember | 0,99 € | 100 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_gift_cards` | Gift Cards: 8 Motifs | 3,99 € | 400 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_damage_preview` | Damage Preview | 4,99 € | 500 | Vorteil | keine Liga-Wirkung |
| `rg_minimap` | Minimap | 2,99 € | 300 | Vorteil | keine Liga-Wirkung |
| `rg_fast_text` | Fast Text | 1,99 € | 200 | Komfort | keine Liga-Wirkung |
| `rg_retro_filter` | Retro Filter | 1,99 € | 200 | Kosmetik | überall sichtbar, keine Wirkung |
| `rg_sky_control` | Sky Control | 2,99 € | 300 | Komfort | keine Liga-Wirkung |
| `rg_bench_lessons` | Bench Lessons | 4,99 € | 500 | Vorteil | keine Liga-Wirkung |
| `rg_power_seal_1` | Power Seal I | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_power_seal_2` | Power Seal II | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_power_seal_3` | Power Seal III | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_power_seal_4` | Power Seal IV | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_power_seal_5` | Power Seal V | 19,99 € | 2000 | Vorteil | nur Offene Liga |
| `rg_power_seal_6` | Power Seal VI | 24,99 € | 2500 | Vorteil | nur Offene Liga |
| `rg_power_seal_7` | Power Seal VII | 29,99 € | 3000 | Vorteil | nur Offene Liga |
| `rg_guard_seal_1` | Guard Seal I | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_guard_seal_2` | Guard Seal II | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_guard_seal_3` | Guard Seal III | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_guard_seal_4` | Guard Seal IV | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_guard_seal_5` | Guard Seal V | 19,99 € | 2000 | Vorteil | nur Offene Liga |
| `rg_guard_seal_6` | Guard Seal VI | 24,99 € | 2500 | Vorteil | nur Offene Liga |
| `rg_guard_seal_7` | Guard Seal VII | 29,99 € | 3000 | Vorteil | nur Offene Liga |
| `rg_speed_seal_1` | Pace Seal I | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_speed_seal_2` | Pace Seal II | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_speed_seal_3` | Pace Seal III | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_speed_seal_4` | Pace Seal IV | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_speed_seal_5` | Pace Seal V | 19,99 € | 2000 | Vorteil | nur Offene Liga |
| `rg_stat_crystal_1` | Stat Crystal +1 | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_stat_crystal_5` | Stat Crystal +5 | 3,99 € | 400 | Vorteil | keine Liga-Wirkung |
| `rg_stat_crystal_10` | Stat Crystal +10 | 6,99 € | 700 | Vorteil | keine Liga-Wirkung |
| `rg_growth_x5` | Mighty Growth Crystal | 6,99 € | 700 | Vorteil | keine Liga-Wirkung |
| `rg_growth_plus` | Growth Seal | 14,99 € | 1500 | Vorteil | keine Liga-Wirkung |
| `rg_coin_boost_x3` | Great Coin Gleam | 3,99 € | 400 | Vorteil | keine Liga-Wirkung |
| `rg_ring_tonic_10` | Grand Ring Tonic | 6,99 € | 700 | Vorteil | keine Liga-Wirkung |
| `rg_ring_crown` | Ring Crown | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_ring_cap_plus` | Ring Cap Seal | 14,99 € | 1500 | Vorteil | keine Liga-Wirkung |
| `rg_coins_100000` | Vault of Coins | 29,99 € | 3000 | Vorteil | keine Liga-Wirkung |
| `rg_bond_lure_1` | Bond Lure I | 0,99 € | 100 | Vorteil | keine Liga-Wirkung |
| `rg_bond_lure_2` | Bond Lure II | 1,99 € | 200 | Vorteil | keine Liga-Wirkung |
| `rg_bond_lure_3` | Bond Lure III | 2,99 € | 300 | Vorteil | keine Liga-Wirkung |
| `rg_bond_lure_4` | Bond Lure IV | 4,99 € | 500 | Vorteil | keine Liga-Wirkung |
| `rg_seal_set` | Seal Set | 99,99 € | 10000 | Vorteil | nur Offene Liga |
| `rg_spirling_velahra` | Velahra at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_hallowmur` | Hallowmur at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_scriptorax` | Scriptorax at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_lumivane` | Lumivane at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_zephyrel` | Zephyrel at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_monolurk` | Monolurk at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_spirling_vorlucent` | Vorlucent at Ring 40 | 19,99 € | 2000 | Vorteil | keine Liga-Wirkung |
| `rg_crit_seal_1` | Crit Seal I | 4,99 € | 500 | Vorteil | nur Offene Liga |
| `rg_crit_seal_2` | Crit Seal II | 9,99 € | 1000 | Vorteil | nur Offene Liga |
| `rg_crit_seal_3` | Crit Seal III | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_status_ward` | Status Ward | 14,99 € | 1500 | Vorteil | nur Offene Liga |
| `rg_start_shield` | Opening Shield | 14,99 € | 1500 | Vorteil | nur Offene Liga |

<!-- shop-table:end -->
