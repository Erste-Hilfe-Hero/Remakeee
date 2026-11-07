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

## Was nie verkauft wird

Diese Dinge gibt es nie gegen Geld oder Rissglas, auch nicht als Teil eines Pakets:

- Story-Kapitel, Regionen und Karten
- der Zugang zu Rissen und Wächtern
- Konto-Funktionen: Spielstand auf dem Server, Übertragungscode, Konto löschen, Datenexport
- Freunde, Grüße, Duelle und Ligen-Teilnahme
- Geschenke an Freunde (sie bleiben kostenlos; gekaufte Grußkarten ändern nur das Aussehen)
- Spirlings und Waymarks (siehe unten)

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

115 Angebote (Katalog v28): 76 Vorteil, 32 Kosmetik, 7 Rissglas.

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

<!-- shop-table:end -->
