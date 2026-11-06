# Bereich 2: Kampf-Ergänzungen, Gegner und Balance

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 445 bis 889.

> **Auftrag für den umsetzenden Thread:** Ziel ist ein tieferes, fair abgestimmtes Kampfsystem mit neuen Techniken pro Element, eigenständigen Wanderer- und Wächter-Gegnern, Wächter-Rätselkämpfen, Regelvarianten und messbarer Balance.
> Betroffen sind data/moves.json, data/spirlings.json (nur Lernlisten), data/maps/*.json (nur Gegnerteams der Wanderer und Wächter), neue Dateien data/ai_profiles.json, data/puzzles.json, data/battle_goals.json und data/rule_variants.json, dazu scripts/battle/ (BattleRules.gd, BattleModel.gd, BattleAI.gd, effects/), scripts/core/BalanceSim.gd, tools/balance_sim.gd, tests/unit/ und docs/BALANCE.md.
> Anfangen mit den neuen Effekt-Bausteinen und den KI-Wertungen dafür, danach die Techniken pro Element, dann Simulator und Balance-Tests, erst danach Gegnerteams, Rätsel und Regelvarianten.
> Nicht in diesen Bereich gehören neue Spirling-Arten (Bereich 1), Online-Duelle und Online-Regeln (Bereich 7) und alles rund um den Shop (Bereich 10); auch keine Punkte, die schon in docs/KAMPF_PLAN_1000.md stehen.

### Neue Effekt-Bausteine für Techniken
445. [x] [P1] Neuer Effekt `bonus_vs_status` in scripts/battle/effects/: die Technik erhält einen Stärke-Faktor (Schlüssel `vs_status`, `vs_mult`), wenn das Ziel den genannten Status trägt; `"*"` steht für jeden Status.
446. [x] [P1] Neuer Effekt `energy_tax`: das Ziel zahlt 2 Runden lang für jede Technik 1 Energie mehr; die Restrunden stehen im Info-Streifen als Zahl neben einem Münzsymbol.
447. [x] [P1] Neuer Effekt `field_element`: die Technik nimmt das Element an, das das aktive Feld verstärkt, und erhält dann +20 Stärke; ohne Feld behält sie ihr eigenes Element.
448. [x] [P1] Neuer Effekt `self_stage_after`: nach einem Treffer sinkt eine eigene Stufe um den Wert aus `self_stages` (zum Beispiel Fokus -1), auch wenn das Ziel dabei fällt.
449. [x] [P1] Neuer Effekt `stage_on_hit`: mit der Chance `stage_chance` steigt nach einem Treffer eine eigene Stufe um 1; StatChangeEffect erhält dafür den optionalen Schlüssel `stage_chance` (Standard 1,0).
450. [x] [P1] Neuer Schlüssel `cooldown` in moves.json: nach dem Einsatz ist die Technik für die angegebene Zahl an Runden gesperrt und im Technik-Menü grau mit Restzahl.
451. [x] [P2] Neuer Effekt `delayed_hit`: der Schaden wird beim Einsatz mit den aktuellen Werten berechnet und trifft 2 Runden später den Spirling, der dann im Ziel-Slot steht. Erledigt: Kunst „Omen Bell“ (Lumenewt Ring 36), Ereignisse DELAYED_SET/DELAYED_HIT.
452. [x] [P2] Neuer Effekt `energy_burn`: das Ziel verliert die Energie aus `effect_amount`, ohne dass der Nutzer sie erhält (Unterschied zum bestehenden `energy_drain`).
453. [x] [P2] Neuer Effekt `heal_block`: 3 Runden lang wirken beim Ziel keine Heiltechniken, keine Gabe-Regeneration, kein Feld-Heilen und kein Andenken mit `regen_div`.
454. [x] [P2] Neuer Effekt `status_shift`: der Nutzer gibt seinen eigenen Status an das Ziel weiter und ist danach frei; schlägt fehl, wenn das Ziel schon einen Status trägt oder immun ist.
455. [x] [P3] Neuer Effekt `stage_steal`: nimmt dem Ziel eine positive Stufe in Wucht, Schutz, Fokus oder Tempo (die höchste zuerst) und gibt sie dem Nutzer.
456. [x] [P2] Neuer Effekt `side_snare`: legt eine Seitenfalle auf die Gegnerseite, die den nächsten einwechselnden Spirling trifft (Status, Stufe oder 1/10 der max. Kraft), danach ist sie verbraucht.
457. [P3] Neuer Effekt `fixed_ring_damage`: Schaden genau Ring des Nutzers mal 1,2 (abgerundet), ohne Elemente, Stufen, Felder und Glückstreffer.
458. [x] [P2] Neuer Effekt `cure_self`: heilt nach dem Treffer oder der Statustechnik den eigenen Status.
459. [x] [P2] Priorität -1 zulassen: BattleModel sortiert Techniken mit `"priority": -1` hinter alle anderen derselben Aktionsklasse; validate_data erlaubt den Bereich -1 bis +1.
460. [P3] Neuer Effekt `energy_refund`: fällt das Ziel durch den Treffer, erhält der Nutzer die Hälfte der Energiekosten (abgerundet) zurück.
461. [x] [P2] Neuer Effekt `field_extend`: verlängert das aktive Resonanz-Feld um 2 Runden und schlägt ohne Feld mit eigener Meldung fehl. Erledigt: Effekt `field_extend` (moves.json `"effect": "field_extend"`), Ereignis FIELD_EXTENDED.
462. [P3] Neuer Effekt `stage_relay`: der Nutzer wechselt sofort zum gewählten Bank-Spirling, der alle Stufen des Nutzers übernimmt.
463. [P3] Neuer Effekt `bench_splash`: trifft zusätzlich einen per Kampf-Seed gewählten Bank-Spirling des Gegners mit 1/16 seiner max. Kraft.
464. [P3] Neuer Effekt `wake_ally`: weckt im Mehrfachkampf einen Verbündeten aus Drowse und gibt ihm 1 Energie.

### Neue Techniken: Ember und Tide
465. [x] [P1] Ember "Glow Knuckle": Physisch, Stärke 55, Genauigkeit 100 %, Energie 3, 30 % Chance auf eigene Wucht +1.
466. [x] [P1] Ember "Char Mark": Fokus, Stärke 50, Genauigkeit 100 %, Energie 3, Stärke ×1,6 gegen Ziele mit Scorch.
467. [x] [P2] Ember "Bellows Blast": Fokus, Stärke 110, Genauigkeit 90 %, Energie 7, danach eigener Fokus -1.
468. [P3] Ember "Forge Focus": Status, Energie 3, eigener Fokus +2 und eigenes Tempo -1.
469. [x] [P2] Ember "Coal Seed": Status, Genauigkeit 100 %, Energie 3, Seitenfalle, die dem nächsten einwechselnden Gegner Scorch gibt.
470. [x] [P2] Ember "Furnace Heart": Physisch, Stärke 120, Genauigkeit 85 %, Energie 7, danach 1 Runde Sperre (`cooldown` 1).
471. [x] [P2] Ember "Cinder Dash": Physisch, Stärke 35, Genauigkeit 100 %, Energie 1, Priorität +1.
472. [P3] Ember "Smelt": Status, Genauigkeit 90 %, Energie 3, `heal_block` für 3 Runden.
473. [x] [P3] Ember "Brazier Pulse": Fokus, Stärke 70, Genauigkeit 95 %, Energie 5, trifft alle Gegner, 10 % Scorch.
474. [P3] Ember "Hearth Hum": Status, Energie 4, `field_extend` um 2 Runden.
475. [P3] Ember "Slow Fuse": Fokus, Stärke 100, Genauigkeit 100 %, Energie 5, `delayed_hit` nach 2 Runden.
476. [x] [P1] Tide "Spout Jab": Physisch, Stärke 40, Genauigkeit 100 %, Energie 2, Stärke ×1,5 gegen Ziele mit Soak.
477. [x] [P1] Tide "Deepwell Draught": Status, Energie 4, heilt 35 % der max. Kraft und den eigenen Status.
478. [x] [P2] Tide "Salt Spray": Fokus, Stärke 55, Genauigkeit 100 %, Energie 3, 30 % Chance auf Tempo -1 beim Ziel.
479. [x] [P2] Tide "Rip Current": Physisch, Stärke 70, Genauigkeit 95 %, Energie 4, `energy_burn` 1.
480. [x] [P2] Tide "Fathom Crush": Physisch, Stärke 115, Genauigkeit 85 %, Energie 7, `cooldown` 1.
481. [x] [P3] Tide "Bore Wave": Fokus, Stärke 85, Genauigkeit 90 %, Energie 6, trifft alle Gegner, 20 % Soak.
482. [P3] Tide "Ebb Pull": Status, Genauigkeit 95 %, Energie 3, Ziel Wucht -1 und Tempo -1.
483. [x] [P3] Tide "Shoal Trap": Status, Energie 3, Seitenfalle, die dem nächsten einwechselnden Gegner Soak gibt.
484. [P3] Tide "Silt Cloud": Status, Genauigkeit 90 %, Energie 3, gibt dem Ziel Daze.
485. [P3] Tide "Mist Mirror": Status, Energie 4, der nächste Status, der den Nutzer treffen würde, trifft stattdessen den Verursacher (einmal, höchstens 3 Runden).
486. [P3] Tide "Foam Veil": Status, Energie 4, alle Spirlings der eigenen Seite heilen 3 Runden lang je 1/16 der max. Kraft am Rundenende.
487. [x] [P2] Lernlisten Ember: Kindlop lernt Cinder Dash bei Ring 6 und Glow Knuckle bei Ring 11, Smoldrake Char Mark bei Ring 18 und Bellows Blast bei Ring 32, Calderox Furnace Heart bei Ring 46.
488. [x] [P2] Lernlisten Tide: Puddlet lernt Spout Jab bei Ring 7 und Salt Spray bei Ring 11, Riptail Rip Current bei Ring 21 und Deepwell Draught bei Ring 28, Leviarch Bore Wave bei Ring 44, Kelpup Shoal Trap bei Ring 16.

### Neue Techniken: Bloom und Volt
489. [x] [P1] Bloom "Pollen Prick": Physisch, Stärke 45, Genauigkeit 100 %, Energie 2, Stärke ×1,5 gegen Ziele mit Root.
490. [x] [P2] Bloom "Bramble Bed": Status, Energie 3, Seitenfalle, die den nächsten einwechselnden Gegner mit Root bindet.
491. [x] [P3] Bloom "Graft": Status, Genauigkeit 100 %, Energie 3, `stage_steal`.
492. [x] [P3] Bloom "Root Mend": Status, Energie 4, heilt sofort 20 % und danach 3 Runden je 1/16 der max. Kraft. Erledigt: Schlüssel `mend` (MendEffect), Hauler Tobins Kelpup nutzt sie jetzt.
493. [x] [P2] Bloom "Wildgrowth Crash": Physisch, Stärke 110, Genauigkeit 90 %, Energie 6, danach eigener Schutz -1.
494. [x] [P2] Bloom "Husk Shed": Status, Energie 2, heilt den eigenen Status und gibt Tempo +1.
495. [P3] Bloom "Lattice Guard": Status, Energie 3, eigener Schutz +1 und Fokus +1.
496. [x] [P3] Bloom "Thornwake": Fokus, Stärke 80, Genauigkeit 95 %, Energie 5, trifft alle Gegner, 10 % Root.
497. [P3] Bloom "Compost Slap": Physisch, Stärke 70, Genauigkeit 95 %, Energie 4, `energy_refund`.
498. [x] [P3] Bloom "Bark Burst": Physisch, Stärke 80, Genauigkeit 95 %, Energie 5, 20 % Chance auf eigenen Schutz +1.
499. [x] [P3] Bloom "Seed Spit": Physisch, Stärke 30, Genauigkeit 100 %, Energie 1, Priorität +1.
500. [x] [P1] Volt "Static Tag": Fokus, Stärke 45, Genauigkeit 100 %, Energie 2, Stärke ×1,5 gegen Ziele mit Jolt.
501. [x] [P1] Volt "Grid Lock": Status, Genauigkeit 90 %, Energie 3, `energy_tax` für 2 Runden.
502. [x] [P2] Volt "Overdraw": Status, Genauigkeit 100 %, Energie 2, `energy_burn` 2.
503. [x] [P2] Volt "Capacitor Crash": Physisch, Stärke 120, Genauigkeit 85 %, Energie 7, `cooldown` 1.
504. [x] [P2] Volt "Pylon Snap": Physisch, Stärke 60, Genauigkeit 100 %, Energie 3, 30 % Chance auf eigenes Tempo +1.
505. [x] [P3] Volt "Short Circuit": Fokus, Stärke 95, Genauigkeit 90 %, Energie 6, danach eigener Fokus -1.
506. [P3] Volt "Ring Pulse": Fokus, Genauigkeit 100 %, Energie 3, `fixed_ring_damage`.
507. [P3] Volt "Relay Spark": Status, Energie 3, `stage_relay`.
508. [P3] Volt "Bleed Current": Fokus, Stärke 60, Genauigkeit 100 %, Energie 4, `energy_refund`.
509. [x] [P3] Volt "Wire Trap": Status, Energie 3, Seitenfalle, die dem nächsten einwechselnden Gegner Jolt gibt.
510. [P3] Volt "Brownout": Status, Genauigkeit 85 %, Energie 4, trifft alle Gegner mit `energy_burn` 1.
511. [x] [P2] Lernlisten Bloom: Mossling lernt Pollen Prick bei Ring 6 und Husk Shed bei Ring 11, Thornback Graft bei Ring 24 und Wildgrowth Crash bei Ring 34, Verdantusk Thornwake bei Ring 46, Kelphound Root Mend bei Ring 35. Erledigt (Root Mend bei Kelphound Ring 35 kam mit 492 dazu).
512. [x] [P2] Lernlisten Volt: Zippit lernt Static Tag bei Ring 6 und Pylon Snap bei Ring 10, Grid Lock bei Ring 16, Glimmerax Short Circuit bei Ring 36 und Capacitor Crash bei Ring 44.

### Neue Techniken: Stone und Gale
513. [x] [P1] Stone "Grit Jab": Physisch, Stärke 45, Genauigkeit 100 %, Energie 2, Stärke ×1,3 gegen jedes Ziel mit Status.
514. [x] [P2] Stone "Quarry Wall": Status, Energie 3, eigener Schutz +2.
515. [x] [P2] Stone "Landslip": Physisch, Stärke 75, Genauigkeit 95 %, Energie 5, trifft alle Gegner, 30 % Tempo -1 pro Ziel.
516. [x] [P2] Stone "Shard Bed": Status, Energie 3, Seitenfalle, die dem nächsten einwechselnden Gegner 1/10 der max. Kraft nimmt.
517. [x] [P2] Stone "Monolith Drop": Physisch, Stärke 125, Genauigkeit 80 %, Energie 8, `cooldown` 1.
518. [x] [P2] Stone "Pumice Pelt": Physisch, Stärke 55, Genauigkeit 100 %, Energie 3, 50 % Chance auf eigenen Schutz +1.
519. [x] [P3] Stone "Slow Quake": Physisch, Stärke 90, Genauigkeit 100 %, Energie 3, Priorität -1.
520. [x] [P3] Stone "Fault Line": Fokus, Stärke 70, Genauigkeit 95 %, Energie 4, ignoriert positive Schutz- und Fokus-Stufen des Ziels (Schlüssel `ignore_stages`).
521. [P3] Stone "Geode Heart": Status, Energie 5, heilt 40 % der max. Kraft und gibt Schutz +1.
522. [x] [P3] Stone "Gravel Hum": Status, Genauigkeit 90 %, Energie 3, Ziel Tempo -2.
523. [P3] Stone "Mason Strike": Physisch, Stärke 85, Genauigkeit 90 %, Energie 5, `energy_refund`.
524. [x] [P1] Gale "Crosswind": Fokus, Stärke 55, Genauigkeit 100 %, Energie 3, `field_element` (mit Feld Stärke 75 im Feld-Element).
525. [x] [P1] Gale "Kite Cut": Physisch, Stärke 50, Genauigkeit 100 %, Energie 3, 30 % Chance auf eigenes Tempo +1.
526. [x] [P1] Gale "Scatter Gale": Status, Genauigkeit 100 %, Energie 3, entfernt alle Seitenfallen der eigenen Seite und senkt das Tempo des Ziels um 1.
527. [x] [P2] Gale "Downburst": Physisch, Stärke 110, Genauigkeit 85 %, Energie 7, `cooldown` 1.
528. [x] [P2] Gale "Draft Needle": Physisch, Stärke 35, Genauigkeit 100 %, Energie 1, Priorität +1.
529. [x] [P2] Gale "Lull Breaker": Fokus, Stärke 60, Genauigkeit 100 %, Energie 3, Stärke ×1,6 gegen Ziele mit Drowse, weckt das Ziel danach.
530. [x] [P2] Gale "Squall Line": Physisch, Stärke 80, Genauigkeit 95 %, Energie 5, senkt das Tempo des Ziels sicher um 1.
531. [x] [P3] Gale "Chaff Feint": Status, Genauigkeit 95 %, Energie 2, Ziel Wucht -1 und Fokus -1.
532. [x] [P2] Gale "Cloudbreak": Fokus, Stärke 105, Genauigkeit 90 %, Energie 6, danach eigenes Tempo -1.
533. [P3] Gale "Pinion Rush": Physisch, Stärke 75, Genauigkeit 95 %, Energie 4, `energy_refund`.
534. [P3] Gale "Whirl Shear": Fokus, Stärke 75, Genauigkeit 95 %, Energie 5, trifft alle Gegner und nimmt einem aktiven Feld 1 Restrunde.
535. [P3] Gale "Pressure Drop": Status, Genauigkeit 85 %, Energie 4, `energy_tax` auf alle Gegner für 2 Runden.
536. [P3] Gale "Air Pocket": Status, Energie 3, halbiert den Schaden des nächsten Treffers gegen den Nutzer in dieser Runde und schlägt bei zweimaligem Einsatz hintereinander fehl.
537. [P3] Gale "Breath Thief": Fokus, Stärke 50, Genauigkeit 100 %, Energie 3, `energy_burn` 1.
538. [x] [P3] Gale "Gale Mantle": Status, Energie 3, eigenes Tempo +1 und Fokus +1.

### Neue Techniken: Lumen und Umbra
539. [x] [P1] Lumen "Beacon Ping": Fokus, Stärke 45, Genauigkeit 100 %, Energie 2, Stärke ×1,5 gegen Ziele mit Daze.
540. [x] [P1] Lumen "Dawn Needle": Physisch, Stärke 35, Genauigkeit 100 %, Energie 1, Priorität +1, ignoriert die Genauigkeitsstrafe von Daze beim Nutzer.
541. [x] [P2] Lumen "Sunwell Sip": Status, Energie 4, heilt 30 % der max. Kraft und gibt Fokus +1.
542. [x] [P2] Lumen "Daybreak Strike": Physisch, Stärke 115, Genauigkeit 85 %, Energie 7, `cooldown` 1.
543. [x] [P3] Lumen "Starlit Lash": Physisch, Stärke 60, Genauigkeit 100 %, Energie 3, 30 % Chance auf Wucht -1 beim Ziel.
544. [x] [P2] Lumen "Prism Burst": Fokus, Stärke 100, Genauigkeit 90 %, Energie 6, danach eigener Fokus -1.
545. [P3] Lumen "Solar Mote": Fokus, Stärke 100, Genauigkeit 100 %, Energie 5, `delayed_hit` nach 2 Runden.
546. [P3] Lumen "Pale Ward": Status, Energie 3, der Nutzer kann 3 Runden lang keinen neuen Status erhalten.
547. [P3] Lumen "Sun Tithe": Fokus, Stärke 70, Genauigkeit 95 %, Energie 4, `energy_refund`.
548. [x] [P3] Lumen "Glow Trap": Status, Energie 3, Seitenfalle, die dem nächsten einwechselnden Gegner Daze gibt.
549. [P3] Lumen "Halo Pulse": Fokus, Stärke 80, Genauigkeit 95 %, Energie 5, trifft alle Gegner, 10 % Daze.
550. [x] [P1] Umbra "Shade Pounce": Physisch, Stärke 50, Genauigkeit 100 %, Energie 3, Stärke ×1,5 gegen Ziele mit mindestens einer negativen Stufe.
551. [x] [P1] Umbra "Gloom Handoff": Status, Genauigkeit 100 %, Energie 2, `status_shift`.
552. [x] [P2] Umbra "Night Toll": Status, Genauigkeit 90 %, Energie 3, `heal_block` für 3 Runden.
553. [x] [P2] Umbra "Eclipse Crush": Physisch, Stärke 115, Genauigkeit 85 %, Energie 7, `cooldown` 1.
554. [x] [P2] Umbra "Murmur Bite": Physisch, Stärke 65, Genauigkeit 95 %, Energie 4, `energy_burn` 1.
555. [x] [P2] Umbra "Veil Step": Physisch, Stärke 30, Genauigkeit 100 %, Energie 1, Priorität +1.
556. [x] [P3] Umbra "Gloam Pact": Status, Energie 3, eigene Wucht +2 und eigener Schutz -1.
557. [x] [P3] Umbra "Dusk Snare": Status, Energie 3, Seitenfalle, die das Tempo des nächsten einwechselnden Gegners um 1 senkt.
558. [P3] Umbra "Hollow Wail": Fokus, Stärke 80, Genauigkeit 95 %, Energie 5, trifft alle Gegner, 20 % Fokus -1 pro Ziel.
559. [P3] Umbra "Dark Bargain": Status, Energie 0, der Nutzer verliert 25 % der max. Kraft und erhält 3 Energie; schlägt unter 30 % Kraft fehl.
560. [P3] Umbra "Shroud Lance": Fokus, Stärke 100, Genauigkeit 90 %, Energie 6, danach eigener Fokus -1.
561. [x] [P2] Lernlisten Lumen: Wickit lernt Dawn Needle bei Ring 6 und Beacon Ping bei Ring 10, Lumenewt Starlit Lash bei Ring 24 und Sunwell Sip bei Ring 34, Glimmerax Prism Burst bei Ring 38, Leviarch Daybreak Strike bei Ring 50.
562. [x] [P2] Lernlisten Umbra: Mirkmole lernt Veil Step bei Ring 6 und Shade Pounce bei Ring 12, Duskdigger Gloom Handoff bei Ring 27 und Eclipse Crush bei Ring 46, Verdantusk Gloam Pact bei Ring 40, Obsidroth Murmur Bite bei Ring 32.

### Element-Reaktionen und Zuteilung der neuen Techniken
563. [x] [P1] BattleAI.score_move bewertet alle neuen Bausteine mit festen Werten: Seitenfalle 0,25 mal Zahl der gegnerischen Bank-Spirlings, `energy_tax` 0,15 pro Runde, `delayed_hit` 0,8 des geschätzten Schadens, `cooldown` ohne Abschlag im ersten Zug.
564. [x] [P1] Lernlisten Stone: Shalebat lernt Grit Jab bei Ring 8 und Pumice Pelt bei Ring 16, Obsidroth Landslip bei Ring 30 und Monolith Drop bei Ring 44, Calderox Quarry Wall bei Ring 36, Duskdigger Fault Line bei Ring 33.
565. [x] [P1] Lernlisten Gale: Zephlet lernt Draft Needle bei Ring 5, Kite Cut bei Ring 10, Crosswind bei Ring 14 und Scatter Gale bei Ring 19, Tempestrel Squall Line bei Ring 30, Cloudbreak bei Ring 40 und Downburst bei Ring 48.
566. [x] [P2] Neue Reaktion in BattleRules.REACTIONS: Stone trifft ein Ziel mit Jolt, erdet den Status (er endet) und richtet ×1,1 Schaden an. Erledigt.
567. [x] [P2] Neue Reaktion: Gale trifft ein Ziel mit Soak, beendet Soak und senkt das Tempo des Ziels um 1. Erledigt: Reaktionszeile mit `stage`.
568. [P3] Neue Reaktion: Bloom trifft ein Ziel mit Soak, der Nutzer heilt 1/8 des angerichteten Schadens.
569. [x] [P2] Neue Reaktion: Lumen trifft ein Ziel mit Drowse, weckt es und richtet ×1,3 Schaden an. Erledigt.
570. [x] [P2] Regel: höchstens eine Reaktion pro Treffer, es gilt die erste passende Zeile der Tabelle; ein Test prüft, dass sich keine zwei Zeilen widersprechen. Erledigt: tests/unit/test_reactions_extend.gd.
571. [P3] Neue Reaktion: Umbra trifft ein Ziel mit Daze und richtet ×1,2 Schaden an.
572. [P3] Neue Reaktion: Ember trifft ein Ziel mit Soak, Soak verdampft (endet), der Treffer richtet nur ×0,8 Schaden an.
573. [x] [P2] Jede Art erhält höchstens eine Technik mit `cooldown` und höchstens eine Seitenfalle in ihrer Lernliste.
574. [P2] Scatter Gale, Graft und Ring Pulse werden zusätzlich über Echo-Kristalle für alle Arten lernbar, damit jedes Team eine Antwort auf Seitenfallen und Stufenaufbau hat.
575. [x] [P2] Lernlisten-Obergrenze: höchstens 14 Techniken pro Art, geprüft in tests/unit/test_learnsets.gd.
576. [P2] Alle 92 neuen Techniken bekommen deutsche Namen und Beschreibungen in data/i18n/de.json, in eigener Wortwahl.
577. [x] [P2] tools/validate_data.gd kennt alle neuen Schlüssel (`vs_status`, `vs_mult`, `cooldown`, `stage_chance`, `self_stages`, `ignore_stages`, Priorität -1) und meldet unbekannte Schlüssel als Fehler. Erledigt: DataValidator.MOVE_KEYS, unbekannte Schlüssel sind Fehler.
578. [x] [P2] Die Technik-Info per langem Druck zeigt bei `field_element`-Techniken das gerade angenommene Element und bei `delayed_hit` die Runde des Einschlags. Erledigt: CommandMenu.move_info(mv, model).
579. [P3] Reine Echo-Kristall-Techniken ohne Lernlisten-Platz: Relay Spark, Dark Bargain, Mist Mirror und Hearth Hum.
580. [P3] Seitenfallen erscheinen als kleines Symbol unter der Gegner-Bank-Anzeige mit Kürzel des Effekts (zum Beispiel "SC" für Scorch).

### Bestehende Techniken nachjustieren
581. [x] [P1] Lichen Lash (0,94 K.o. pro Einsatz bei Ring 36) von Stärke 40 auf 35 senken, Energie bleibt 2.
582. [x] [P1] Crackle Bite (0,80 K.o. pro Einsatz) behält Stärke 40, die Jolt-Chance sinkt von 10 % auf 5 %.
583. [x] [P1] Overcharge (1,00 K.o. pro Einsatz) erhält im Simulator eine Obergrenze von +5 Energie Zuschlag; OVERCHARGE_PER_ENERGY sinkt von 0,15 auf 0,12.
584. [x] [P1] Storm Gnash (0,07 K.o. pro Einsatz) von Stärke 75 auf 80 und Genauigkeit 90 % auf 95 %.
585. [x] [P1] Gale Scythe (0,08 K.o. pro Einsatz) von Stärke 80 auf 85 und Energie 5 auf 4.
586. [x] [P1] Arc Bolt (0,04 K.o. pro Einsatz) Jolt-Chance von 20 % auf 30 %, Stärke bleibt 65.
587. [x] [P1] All-In Crash Grundstärke von 30 auf 40, damit es neben Overcharge eine echte Stone-Wahl ist.
588. [x] [P1] Cairn Crash von Stärke 100, Genauigkeit 80 %, Energie 7 auf Stärke 105, Genauigkeit 85 %, Energie 7, Rückstoß bleibt 25 %.
589. [x] [P1] Furnace Spiral von Genauigkeit 85 % auf 90 %, Scorch-Chance bleibt 20 %.
590. [x] [P1] Hush (Drowse) von Genauigkeit 75 % auf 80 %, Energie von 4 auf 3, damit es außerhalb der Ruhe-Regel gewählt wird.
591. [x] [P2] Bloom Burst von Stärke 90, Genauigkeit 90 % auf Stärke 95, Genauigkeit 90 %.
592. [x] [P2] Breaker Plunge von Genauigkeit 85 % auf 90 %, Rückstoß von 25 % auf 20 %.
593. [x] [P2] Radiant Lance von Stärke 85, Energie 6 auf Stärke 90, Energie 6.
594. [x] [P2] Kiln Strike von Stärke 75, Genauigkeit 90 % auf Stärke 75, Genauigkeit 95 %.
595. [x] [P2] Salt Snap Soak-Chance von 10 % auf 20 %.
596. [x] [P3] Pebble Toss von Genauigkeit 95 % auf 100 %.
597. [x] [P2] Bowl Over von Stärke 35 auf 30, bleibt bei Energie 1 als billigster Stone-Schlag.
598. [x] [P2] Tunnel Strike erhält 20 % Chance auf eigenen Schutz +1.
599. [x] [P2] Night Siphon von Stärke 50 auf 60, Heilanteil 50 % bleibt.
600. [x] [P2] Dusk Rake erhält 20 % Chance auf Wucht -1 beim Ziel.
601. [x] [P2] Thorn Volley von Energie 4 auf 5 und Stärke 65 auf 75, damit der Flächenschlag neben Sap Draw lohnt.
602. [x] [P2] Charged Mist von Genauigkeit 85 % auf 80 %, weil Jolt gegen alle Gegner im Mehrfachkampf sonst zu sicher ist.
603. [x] [P3] Candle Ward von Energie 3 auf 2 (Heilung 30 % bleibt).
604. [x] [P2] Dawn Mend von Energie 5 auf 6, Heilung bleibt 50 %, damit sie nicht jede zweite Runde passt.
605. [x] [P2] Heat Haze, Murk Veil und Silt Cloud (alle Daze) bekommen dieselbe Genauigkeit von 90 % und dieselben Kosten von 3 Energie. Erledigt für Heat Haze und Murk Veil; Silt Cloud kommt mit Punkt 484 gleich mit diesen Werten.
606. [x] [P2] Kindle Up, Hunker Down, Drift Step und Still Thought kosten weiter 2 Energie, geben aber 2 Stufen, wenn der Nutzer volle Kraft hat (Schlüssel `stages_full_hp`). Erledigt: Ausgleich für Glimmerax (Prism Burst Ring 35) und Lumenewt (Radiant Lance Ring 35), damit der Teamkampf-Test im Band bleibt.
607. [x] [P3] Cower Shade von Genauigkeit 95 % auf 100 %.
608. [x] [P3] Chill Mist trifft alle Gegner, Genauigkeit bleibt 95 %, Energie von 2 auf 3.
609. [P3] Breeze Slice von Stärke 40 auf 35, weil Draft Needle die neue Gale-Prioritätstechnik mit Energie 1 wird.
610. [P3] Updraft erhält 20 % Chance auf eigenes Tempo +1.

### Wanderer-Persönlichkeiten (KI-Profile)
611. [x] [P1] Neue Datei data/ai_profiles.json mit festen Gewichten pro Profil: `damage_w`, `status_w`, `setup_w`, `field_w`, `swap_below` (Matchup-Wert), `heal_below` (Kraft-Anteil), `rest_below` (Energie), `focus_fire` (0 oder 1).
612. [x] [P1] BattleAI liest das Profil eines Wanderers aus dem NPC-Schlüssel `profile` und verrechnet die Gewichte in score_move; ohne Profil gilt "ausgewogen" mit allen Gewichten 1,0.
613. [x] [P1] Profil "Hitzkopf": `damage_w` 1,4, `setup_w` 0,3, `status_w` 0,4, `swap_below` nie, `rest_below` 1; wechselt nie freiwillig und rastet erst bei 0 oder 1 Energie.
614. [x] [P1] Profil "Mauer": `setup_w` 1,5 für Schutz-Stufen, `heal_below` 0,45, `swap_below` 0,5, `damage_w` 0,8.
615. [x] [P1] Profil "Störer": `status_w` 1,6, nutzt Status, Seitenfallen und `energy_tax` vor Schaden, bis das Ziel einen Status trägt.
616. [x] [P2] Profil "Feldkundig": `field_w` 2,0, legt in Runde 1 ein Feld, das dem eigenen Team hilft, und erneuert es, sobald nur noch 1 Restrunde bleibt. Erledigt: Profil `field_keeper` mit `field_renew`.
617. [x] [P2] Profil "Taktikerin": `swap_below` 0,7, `focus_fire` 1, plant Energie für die beste Technik in der nächsten Runde und rastet gezielt dafür. Erledigt: Profil `tactician` mit `plan_energy`.
618. [x] [P2] Profil "Lehrling": wählt mit 30 % Chance (aus dem Kampf-Seed) die zweitbeste Technik, damit frühe Wanderer schlagbar und lesbar bleiben. Erledigt: Profil `apprentice` mit `second_best` 0,3.
619. [x] [P2] Profil "Ausdauernd": `heal_below` 0,6, `rest_below` 4, bevorzugt Techniken mit `energy_refund` und Drain. Erledigt: Profil `enduring` mit `drain_w` 1,5.
620. [P3] Profil "Spieler": nutzt `delayed_hit`, Priorität -1 und Techniken mit Genauigkeit unter 90 % doppelt so oft wie "ausgewogen".
621. [x] [P2] Jedes Profil hat einen festen Kurzsatz, der beim Kampfstart unter dem Namen steht (zum Beispiel "Wechselt nie zurück"), damit der Spieler die Persönlichkeit lesen kann. Erledigt: Mottos in data/dialogue/battle_lines.json, Ereignis BATTLE_LINE.
622. [x] [P2] Zuordnung: Wanderer Lio "Hitzkopf", Ridgewalker Bram "Mauer", Delver Ros "Störer", Diver Neve "Feldkundig", Rift Mystic Ilka "Taktikerin".
623. [x] [P2] Zuordnung: Rift Acolyte Suri "Lehrling", Rift Acolyte Pell "Hitzkopf", Hauler Tobin "Ausdauernd", Cartographer Kestra als Gegnerin "Taktikerin". Erledigt (Tobin ist der Gegner im Tag-Kampf kestra_tag).
624. [x] [P2] Pro Profil drei Kampfsätze für die Ereignisse "eigener Spirling fällt", "Gegner fällt" und "letzter Spirling", in data/dialogue mit eigener Wortwahl, höchstens 40 Zeichen. Erledigt: data/dialogue/battle_lines.json, jeder Satz höchstens einmal pro Kampf.
625. [x] [P2] Profile wirken nur ab KI-Stufe 1; in Stufe 0 bleibt die Zufallswahl unverändert.
626. [x] [P2] Auf Rift-Born nimmt die Meister-KI die Gewichte des Profils, aber nie schwächere Regeln als Stufe 3 (das Profil "Lehrling" fällt dort weg). Erledigt: auf KI-Stufe 3 greift `second_best` nie.
627. [x] [P2] Profile verändern nie Werte, Energie oder Würfe, nur die Auswahl (Test vergleicht Schadenszahlen mit und ohne Profil bei gleicher Aktion).
628. [x] [P2] Kestra als Partnerin im Tag-Kampf nutzt das Profil "Taktikerin" mit `focus_fire` 1 auf das Ziel des Spielers. Erledigt: Partner-KI erhält `ally_target` aus der Spieler-Aktion.
629. [x] [P3] Profil-Gewichte bleiben unter 2,0 und über 0,2; validate_data prüft das.
630. [P3] Profil "Sammler" für spätere Wanderer: bevorzugt Techniken, die Stufen stehlen oder Energie verbrennen (`stage_steal`, `energy_burn`).
631. [P3] Profil "Spiegel": wiederholt die Technik-Art (Physisch, Fokus, Status), die der Spieler in der Vorrunde genutzt hat, mit eigener bester Technik dieser Art.
632. [P3] Profil "Vorhut": setzt in Runde 1 immer eine Technik mit Priorität +1 ein, wenn sie den Gegner unter 50 % seiner Kraft bringen würde.
633. [P3] Profil-Debug: im Entwicklermenü zeigt eine Zeile pro Zug die drei besten Wertungen mit Profil-Anteil.
634. [P3] Der Lexikon-Eintrag eines besiegten Wanderers zeigt sein Profil und den Kurzsatz.
635. [P3] Rückkämpfe dürfen ein zweites Profil tragen (NPC-Schlüssel `rematch_profile`), zum Beispiel Lio im Rückkampf "Taktikerin".
636. [P3] Gruppen-Wanderer (zwei Gegner) mischen ihre Profile pro Slot, jeder Slot behält sein eigenes.
637. [x] [P3] Ein GUT-Test pro Profil prüft ein typisches Verhalten in einer festen Lage (Hitzkopf rastet nicht bei 4 Energie, Mauer heilt bei 40 % Kraft, Störer setzt Status zuerst).

### Wanderer-Gegnerteams
638. [x] [P1] NPC-Teams in data/maps/*.json dürfen pro Spirling `moves` (feste Technik-Liste) und `held` (Andenken) tragen; ohne Angabe gelten wie bisher die letzten 4 Techniken der Lernliste.
639. [x] [P1] NPC-Teams dürfen pro Schwierigkeit einen eigenen Block `teams_by_difficulty` mit den Schlüsseln `story`, `tamer`, `veteran`, `rift_born` haben; fehlt ein Block, gilt `team`.
640. [x] [P1] Wanderer Lio (Crowcrest): Story Zephlet R6 allein, Tamer wie bisher Zephlet R7 und Zippit R8, Veteran zusätzlich Kite Cut und Draft Needle auf Zephlet, Rift-Born Zippit mit Andenken spark_coil.
641. [x] [P1] Ridgewalker Bram (Crowcrest): Tamer Shalebat R7 und R8 mit Hunker Down und Grit Jab, Veteran ein Shalebat mit iron_burr, Rift-Born drittes Mitglied Mossling R8 mit Pollen Prick.
642. [x] [P1] Delver Ros (Murk Hollow): Tamer Mirkmole R12 mit Murk Veil und Shade Pounce, Shalebat R13 mit Grit Jab; Veteran Mirkmole mit Gloom Handoff, Rift-Born dritter Spirling Wickit R12 mit Beacon Ping.
643. [x] [P1] Diver Neve (Saltmarsh): Tamer Puddlet R12 mit Tide Call und Spout Jab, Zephlet R13 mit Crosswind; Veteran Kelpup R13 als Dritter, Rift-Born Puddlet mit bark_wrap.
644. [x] [P1] Rift Mystic Ilka (Tide Rift, 3 gegen 3): Tamer wie bisher, Veteran mit Chill Mist auf Zippit und Thorn Volley auf Mossling, Rift-Born mit Andenken swift_feather auf Zippit.
645. [x] [P2] Rift Acolyte Pell (Cinder Rift): Shalebat R9 mit Pebble Toss und Hunker Down, Zippit R9 mit Crackle Bite und Static Tag, damit er die Jolt-Reaktion vor Orrin zeigt.
646. [x] [P2] Rift Acolyte Suri (Cinder Rift): Kindlop R10 mit Cinder Dash, Kindle Up und Char Mark; auf Veteran zusätzlich Ash Call, damit sie das Feld vor dem Wächter vorführt.
647. [x] [P2] Hauler Tobin (Saltmarsh, Tag-Kampf): Shalebat R13 mit Shard Bed, Kelpup R13 mit Root Mend, Mirkmole R14 mit Night Toll, damit der Kampf Seitenfallen und Heilsperre lehrt. Erledigt (mit Root Mend seit 492).
648. [x] [P2] Cartographer Kestra (Crowcrest, Übungskampf): Zippit R7 mit Static Tag, Zephlet R8 mit Kite Cut, Shalebat R9 mit Grit Jab; auf Story nur Zephlet und Shalebat.
649. [x] [P2] Neuer Wanderer in Fernstair "Wegwärterin Imme": Zippit R4 und Mossling R4, Profil "Lehrling", Preisgeld 120, erster Kampf, der Rasten erklärt. Erledigt: „Pathkeeper Imme“ (de: Wegwärterin Imme).
650. [x] [P3] Neuer Wanderer in Fernstair "Hirte Joss": Shalebat R5 mit Hunker Down, Profil "Mauer", zeigt Stufen. Erledigt: „Herder Joss“.
651. [x] [P2] Neuer Wanderer in Saltmarsh "Netzflickerin Aud": Kelpup R12 mit Bramble Bed und Puddlet R12 mit Shoal Trap, Profil "Störer", lehrt Seitenfallen. Erledigt: „Netmender Aud“.
652. [x] [P2] Neuer Wanderer in Murk Hollow "Laternenträger Fenn": Wickit R12 mit Dawn Call und Beacon Ping, Mirkmole R13 mit Murk Call, Profil "Feldkundig", zeigt Feldwechsel im Kampf. Erledigt: „Lampbearer Fenn“.
653. [P3] Neuer Wanderer in Thornridge "Pflückerin Rhea": Mossling R10, Kelpup R10 und Zephlet R11 als 2 gegen 2, Profil "Taktikerin", erster freiwilliger Mehrfachkampf außerhalb der Story.
654. [x] [P2] Kein Wanderer-Team darf zwei gleiche Arten auf gleichem Ring tragen, außer Ridgewalker Bram als bewusstes Thema; tests/unit/test_trainers.gd prüft das. Erledigt (Wächter ausgenommen).
655. [x] [P2] Jeder Wanderer deckt mit seinem Team höchstens 3 Elemente ab, damit sein Thema erkennbar bleibt (Test). Erledigt; bewusst gemischt bleiben Kestra, der Tag-Kampf und Ilkas 3 gegen 3. Isa hat dafür zwei Zephlet.
656. [x] [P2] Der höchste Ring eines Wanderers liegt höchstens 2 über dem höchsten Wild-Ring seiner Karte aus data/encounters.json (Test).
657. [x] [P2] Andenken bei Wanderern gibt es erst ab Veteran und höchstens eins pro Team; Wächter sind davon ausgenommen.
658. [x] [P2] Feste Technik-Listen der Gegner enthalten nur Techniken, die die Art bis zu ihrem Ring lernen kann (Test über Lernliste). Erledigt in angepasster Form: feste Techniken dürfen vorgreifen (640–648, 669 setzen das bewusst), müssen aber in der Lernliste der Art stehen oder ihr Element haben. Zippit lernt Chill Mist bei Ring 14.
659. [x] [P2] Preisgeld pro Wanderer folgt der Formel höchster Ring mal 40, Wächter mal 70; Ausnahmen nur über den Schlüssel `money`. Erledigt: TrainerData.MONEY_PER_LEVEL 40, WARDEN_MONEY_PER_LEVEL 70; tägliche Rückkämpfe behalten 12 pro Ring.
660. [P3] Rückkampf-Teams der Wanderer erhalten ab dem dritten Sieg einen vierten Spirling aus derselben Elementgruppe, Ring wie der bisher höchste.
661. [P2] Rückkämpfe nutzen feste Technik-Listen mit den neuen Techniken passend zum neuen Ring statt der letzten 4 Lernlisten-Einträge.
662. [P3] Gruppen-Kampf "Lio und Bram" in Crowcrest nach dem ersten Riss: 2 gegen 2 mit je zwei Spirlings auf Ring 16, Profile bleiben pro Slot.
663. [P3] Gruppen-Kampf "Ros und Fenn" in Murk Hollow: 2 gegen 2 im Feld deep_murk, beide auf Ring 20.
664. [P3] Jeder Wanderer hat einen Elementhinweis auf seiner Karte vor dem Kampf (kleines Elementsymbol über dem Kopf), sobald man ihn einmal angesprochen hat.
665. [P3] Wanderer-Kampfdaten (Züge, Sieger, gewählte Techniken) fließen anonym nur lokal in den Simulator-Bericht "Wanderer" ein, nicht an den Server.
666. [P3] Zufalls-Wanderer für das Endgame: data/wayfarer_pool.json mit 12 Team-Vorlagen und Profilen, aus denen der Turm Stockwerke baut.
667. [P3] Jede Team-Vorlage im Pool hat eine Bewertungszahl aus dem Simulator (Gewinnrate gegen das Referenzteam), damit der Turm nach Schwierigkeit sortiert.
668. [P3] Ein Werkzeug tools/team_check.gd druckt für einen NPC alle Techniken, Andenken, Profil und Gewinnrate gegen die Referenzteams.

### Wächter-Teams und Wächter-Regeln
669. [x] [P1] Warden Orrin (Cinder Rift, Tamer): Shalebat R10 mit Grit Jab und Hunker Down, Kindlop R11 mit Glow Knuckle und Kindle Up, Smoldrake R12 mit Char Mark, Cinder Breath und Ash Call.
670. [x] [P1] Warden Orrin auf Veteran: Smoldrake trägt spark_coil, Kindlop erhält Coal Seed; auf Rift-Born zusätzlich Zippit R11 mit Static Tag als vierter Spirling.
671. [x] [P1] Warden Orrin auf Story: nur Kindlop R10 und Smoldrake R11, Regel ember_pulse gibt die Zusatz-Energie nur in jeder zweiten Runde.
672. [x] [P1] Warden Maelis (Tide Rift, Tamer): Zephlet R15 mit Kite Cut und Crosswind, Zippit R15 mit Static Tag, Riptail R17 mit Rip Current, Undertow und Tide Call.
673. [x] [P1] Warden Maelis auf Veteran: Riptail trägt bark_wrap, Zephlet erhält Scatter Gale; auf Rift-Born zusätzlich Kelpup R16 mit Shoal Trap.
674. [x] [P1] Warden Maelis auf Story: nur Zephlet R14 und Riptail R16, Regel undertow senkt Tempo nur beim ersten Spirling des Spielers.
675. [P2] Neue Wächter-Regel "Aschenregen" für Orrin ab Veteran: ash_storm liegt ab Runde 1 für 3 Runden, danach das Feld des Ortes.
676. [P2] Neue Wächter-Regel "Gezeitenwechsel" für Maelis ab Veteran: high_tide liegt in den Runden 1 bis 2, 5 bis 6 und 9 bis 10, dazwischen kein Feld; das Banner zeigt den Wechsel eine Runde vorher.
677. [P2] Wächter-Regeln stehen in BattleRules.RULES mit neuem Schlüssel `difficulty` (Liste der Stufen, auf denen sie gelten) und `stack` (wie viele Regeln gleichzeitig gelten dürfen, Standard 1, ab Veteran 2).
678. [P2] Wächter-Wendepunkt: fällt der vorletzte Spirling eines Wächters, sagt der Wächter einen festen Satz und seine Regel verstärkt sich für den Rest (ember_pulse +1 auf +2, undertow zusätzlich Wucht -1 für den nächsten eingewechselten Spirling des Spielers).
679. [P2] Der Wendepunkt gilt nur ab Tamer und erscheint als Regel-Banner mit eigenem Symbol.
680. [P2] Wächter-Teams decken bewusst eine Schwäche ab: Orrin nimmt Shalebat gegen Tide, Maelis nimmt Zippit gegen Gale-Konter; im Lexikon nach dem Sieg erklärt.
681. [P2] Wächter nutzen ab Tamer immer ihr Profil: Orrin "Hitzkopf" mit `field_w` 1,5, Maelis "Taktikerin" mit `field_w` 1,5.
682. [P2] Wächter-Rückkampf "Zweite Prüfung" nach beiden geheilten Rissen: Orrin mit Calderox R30, Smoldrake R28, Shalebat R27, Zippit R27 und Kindlop R26 auf Rift-Born.
683. [P2] Wächter-Rückkampf "Zweite Prüfung" für Maelis: Leviarch R31, Riptail R29, Tempestrel R29, Kelphound R28 und Glimmerax R28 auf Rift-Born; auf Tamer nur die ersten drei.
684. [P2] Die Zweite Prüfung nutzt immer zwei Regeln gleichzeitig (Orrin ember_pulse und Aschenregen, Maelis undertow und Gezeitenwechsel).
685. [P2] Wächter-Spirlings erhalten auf Veteran und Rift-Born einen festen Spark-Wert von 10 in Wucht oder Fokus, je nach Haupt-Technik-Art.
686. [P3] Wächter benutzen Gegenstände nach fester Regel: Orrin einen Trank bei unter 30 % Kraft seines letzten Spirlings, Maelis einen starken Trank einmal bei unter 25 %; auf Rift-Born keine Gegenstände.
687. [P2] Ein Wächter-Kampf zeigt vor Beginn eine Karte mit Regel, Elementen des Teams (Symbole) und Zahl der Spirlings, damit der Spieler sein Team anpassen kann.
688. [P3] Wächter-Kämpfe setzen vor Beginn eine Team-Wahl-Pause, in der man Reihenfolge und Andenken ändern kann, ohne den Kampf zu verlassen.
689. [P3] Rift Mystic Ilka wird zur Vor-Wächterin: auf Veteran gilt bei ihr die abgeschwächte Regel "Leichte Strömung" (Tempo -1 nur für den Spirling in Slot 1).
690. [P3] Rift Acolyte Pell erhält auf Veteran die Regel "Funkenlehre" (+1 Energie nur für den ersten Gegner-Spirling), damit ember_pulse vorher erlebt wird.
691. [P3] Wächter-Siege speichern die genutzte Schwierigkeit und die Zahl der Runden in GameState.records["warden"] für die Wächter-Rätsel und das Lexikon.
692. [P3] Vorlage für spätere Wächter in docs/BALANCE.md: Team aus 3 Spirlings (Story 2, Rift-Born 4), eine Element-Regel, ein Wendepunkt, eine Zweite Prüfung.
693. [P3] Nach dem Sieg zeigt das Lexikon das Wächter-Team der gespielten Stufe mit allen Techniken und Andenken.
694. [P3] Für jede weitere Region mindestens eine neue Wächter-Regel in derselben Datenform, ohne Sonderfälle im Code.
695. [P3] Wächter-Teams werden im Simulator-Modus "warden" gegen alle Referenzteams geprüft, bevor eine Änderung gemergt wird.

### Wächter-Rätselkämpfe
696. [x] [P1] Neue Datei data/puzzles.json: ein Rätsel hat `id`, `warden`, festes Spieler-Team (Art, Ring, Techniken, Kraft-Anteil, Energie, Status), festes Gegner-Team, `field`, `rule`, `seed`, `ai`, `goal` und `max_turns`. Erledigt: data/puzzles.json, BattlePuzzle.gd (Lader, Modell, Ziel, Suche).
697. [x] [P1] Nach dem Sieg über einen Wächter bietet er am Riss drei Rätselkämpfe an ("Prüfungen"), die keine Ringe, kein Wachstum und keine Teamänderung bringen. Erledigt: Overworld.offer_trials am besiegten Wächter, je drei Prüfungen; gelöst in records["trials"].
698. [x] [P1] Rätsel "Glutprobe 1" (Orrin): Puddlet R12 mit Fizz Pop, Tide Call, Salt Snap und Drench gegen Smoldrake R13 im Feld ash_storm mit ember_pulse; Ziel: Sieg in höchstens 4 Runden. Erledigt: ember_trial_1 (7 % gewinnende Linien).
699. [x] [P1] Rätsel "Strömungsprobe 1" (Maelis): Zippit R16 mit Crackle Bite, Static Tag, Overcharge und Spark Call startet mit 4 Energie gegen Riptail R17 mit Soak; Ziel: Sieg in höchstens 3 Runden über die Volt-Reaktion. Erledigt: current_trial_1 (11 % gewinnende Linien), Ziel mit "reaction": "VOLT".
700. [x] [P1] Ein Test löst jedes Rätsel per Suche über alle Spieleraktionen bis `max_turns` mit festem Seed und prüft, dass es mindestens eine Lösung und höchstens 20 % gewinnende Aktionsfolgen gibt. Erledigt: tests/unit/test_puzzles.gd; alle sechs Prüfungen zwischen 7 und 15 %.
701. [P2] Rätsel "Glutprobe 2": Kindlop R12 mit Scorch und Gabe Kindling, Glow Knuckle, Cinder Nip und Kindle Up gegen Shalebat R12 und Zippit R12 (1 gegen 2); Ziel: Sieg, ohne Scorch zu heilen.
702. [P2] Rätsel "Glutprobe 3": Mossling R12 mit 50 % Kraft, Pollen Prick, Puffcap Haze, Bloom Call und Lichen Lash gegen Kindlop R12; Ziel: Sieg, bevor Root ihn 3 Runden lang hielt, also in höchstens 5 Runden mit Bloom-Feld.
703. [P2] Rätsel "Strömungsprobe 2": Zephlet R16 startet mit 2 Energie und Kite Cut, Draft Needle, Drift Step und Crosswind gegen Puddlet R16 im Feld high_tide; Ziel: Sieg mit genau einem Rasten.
704. [P2] Rätsel "Strömungsprobe 3": Spieler mit Riptail R17 und Kestras Zephlet R16 (2 gegen 2) gegen Zippit R16 und Kelpup R16; Ziel: kein eigener Spirling fällt.
705. [P2] Rätsel-Ziele als Datentypen: `win_within`, `no_faint`, `exact_rests`, `keep_status`, `use_reaction`, `last_hit_with` (Technik-Name), kombinierbar bis zwei.
706. [P2] Rätsel-Bewertung mit 1 bis 3 Laternen: Sieg ergibt 1, Ziel erfüllt 2, Ziel in der kleinsten gefundenen Rundenzahl 3; der Löser-Test liefert diese kleinste Zahl.
707. [P2] Nach zwei Fehlversuchen erscheint ein Hinweis aus `hint_1`, nach vier ein zweiter aus `hint_2`, beide in eigener Wortwahl und übersetzt.
708. [P2] Ein Rätsel lässt sich jederzeit sofort neu starten, ohne Text vor dem Kampf, mit demselben Seed.
709. [P2] Rätsel laufen immer mit der festen KI-Stufe aus der Datei, unabhängig von der Schwierigkeit des Spielstands.
710. [P2] Die Belohnung für 3 Laternen in allen drei Prüfungen eines Wächters ist ein Echo-Kristall mit einer der neuen Techniken (Orrin: Furnace Heart, Maelis: Fathom Crush).
711. [P2] Das Rätsel-Banner zeigt das Ziel als Satz und die Restrunden als Zahl oben links.
712. [P2] Rätsel-Ergebnisse (beste Laternen, wenigste Runden) speichert GameState.records["puzzles"], mit Speicherstand-Migration ohne Verlust alter Daten.
713. [P2] Ein Test prüft, dass kein Rätsel nur mit Rasten oder nur mit der ersten Technik gewinnbar ist.
714. [P3] Ein Test prüft, dass jedes Rätsel nur Arten, Techniken, Felder und Regeln aus den Daten nutzt (validate_data).
715. [P3] Rätsel liegen im Lexikon unter "Prüfungen" mit Laternen pro Wächter.
716. [P3] Ein Rätsel-Editor im Entwicklermenü erlaubt, eine laufende Kampflage als Rätsel-Vorlage in die Zwischenablage zu kopieren.
717. [P3] Bonus-Rätsel "Seitenfalle": Spieler muss mit Scatter Gale eine Shard Bed entfernen, bevor sein stärkster Spirling einwechselt.
718. [P3] Bonus-Rätsel "Spätzünder": Sieg nur möglich, wenn Slow Fuse in Runde 1 gelegt wird und der Gegner in Runde 3 einwechselt.
719. [P3] Bonus-Rätsel "Stufendieb": Gegner baut Wucht +2 auf, der Spieler gewinnt nur mit Graft im richtigen Zug.
720. [P3] Bonus-Rätsel "Zug um Zug": Gegner nutzt Grid Lock, der Spieler muss mit genauer Energieplanung über 4 Runden gewinnen.
721. [P3] Rätsel bei Wiederholung zeigen die eigene beste Zugfolge als Text im Lexikon.
722. [P3] Pro spätere Region drei neue Wächter-Rätsel nach dem gleichen Schema, mindestens eins davon mit einer Element-Reaktion.
723. [P3] Rätsel werden im Simulator-Modus "puzzle" in CI vollständig gelöst, mit einer Zeitgrenze von 2 Sekunden pro Rätsel.
724. [P3] Rätsel-Seeds sind fest in der Datei, damit Lösungen bei allen Spielern gleich funktionieren.
725. [P3] Ein Rätsel-Abschluss mit 3 Laternen für alle Prüfungen schaltet einen Titel im Profil frei ("Riss-Leser"), ohne Kampfvorteil.

### Schwierigkeitsstufen-Feinschliff
726. [x] [P1] Gegner-Spark pro Stufe festlegen: Story 0, Tamer 3, Veteran 6, Rift-Born 10 in allen Werten (Spark-Bereich 0 bis 12 bleibt); Tabelle in GameState.FOE_SPARK.
727. [x] [P1] Gegner-Ring-Versatz pro Stufe: Story -1, Tamer 0, Veteran +1, Rift-Born +2, nie über die aktuelle Ring-Obergrenze des Spielers plus 2.
728. [x] [P1] Story: Gegner richten ×0,9 Schaden an; der Wert steht offen auf der Schwierigkeitsseite und in der Kampfregeln-Seite.
729. [x] [P1] Story: Wächter-Regeln abgeschwächt wie bei Orrin und Maelis festgelegt, Bosse mit 20 % weniger Kraft-Faktor `hp_per_ally`. Erledigt: GameState.BOSS_HP_SCALE, BattleModel.boss_hp_scale (im Replay gespeichert).
730. [x] [P1] Story: der Murk-Hollow-Schwarm hat 4 statt 6 Spirlings, Tamer 5, ab Veteran 6.
731. [x] [P1] Veteran: Gegner-Teams nutzen feste Technik-Listen mit mindestens einer Status- oder Stufen-Technik pro Spirling. Erledigt: alle Veteran-Blöcke erfüllen das schon; test_ai_profiles.gd prüft es für jede Karte.
732. [x] [P1] Rift-Born: Wächter tragen ein Andenken auf jedem Spirling, Wanderer eins pro Team.
733. [x] [P1] Zielwerte für Gewinnraten des Referenzteams gegen Wächter: Story mindestens 95 %, Tamer 80 bis 90 %, Veteran 55 bis 70 %, Rift-Born 30 bis 45 % (Simulator-Modus "warden"). Erledigt: tools/balance/targets.json; Orrin 100/89/64/32 %, Maelis 100/88/63/36 % (Mittel der drei Referenzteams, 100 Kämpfe).
734. [P2] Tamer: Gegner nutzen ihr Profil, aber ohne Andenken und mit KI-Stufe 1; Wächter Stufe 2 (bestehende Untergrenze bleibt).
735. [P3] Gegner-Temperament pro Stufe: Story und Tamer aus der uid wie beim Spieler, Veteran und Rift-Born das Temperament, das den Wert der Haupt-Technik-Art hebt.
736. [P2] Ring-Obergrenzen LEVEL_CAPS prüfen: Orrins höchster Spirling auf Veteran ist R13 bei Obergrenze 12, daher Veteran-Team R11 bis R12 und Obergrenze-Hinweis in der Wächter-Karte.
737. [P2] Story: nach zwei Niederlagen im selben Wanderer-Kampf bietet das Spiel offen "Rückenwind" an (Team voll geheilt, Gegner startet mit 2 Energie weniger), der Spieler muss es bestätigen.
738. [P2] Tamer: Rückenwind erst nach drei Niederlagen und ohne Energie-Abzug, nur volle Heilung; ab Veteran nie.
739. [P2] Rückenwind-Nutzung wird im Spielstand gezählt und in der Kampfende-Zusammenfassung genannt, aber nie versteckt angewendet.
740. [P3] Story: Seitenfallen der Gegner wirken nur einmal pro Kampf, auch wenn sie neu gelegt werden.
741. [P2] Story und Tamer: Gegner nutzen keine `heal_block`-Techniken gegen den letzten Spirling des Spielers.
742. [P2] Veteran: Gegner rasten nie zweimal hintereinander, damit die KI nicht stillsteht (gilt für alle Profile).
743. [P2] Rift-Born: Gegner-Teams haben immer 1 Spirling mehr als auf Tamer, höchstens 5.
744. [P3] Rift-Born: der erste Gegner-Spirling ist der mit dem besten Matchup gegen den ersten Spirling des Spielers, ausgewählt beim Kampfstart nach festen Regeln.
745. [P2] Schwierigkeitsseite im Neues-Spiel-Menü zeigt pro Stufe eine Tabelle mit 6 Zeilen: Gegner-Ring, Gegner-Spark, KI-Stufe, Andenken, Gegenstände im Kampf, Ring-Obergrenze.
746. [P2] Ein Wechsel auf eine leichtere Stufe gilt ab dem nächsten Kampf und setzt `difficulty_lowered` im Spielstand, sichtbar im Profil.
747. [P2] Boss-Aktionen pro Zug pro Stufe: Story höchstens 1, Tamer wie bisher, Veteran wie bisher, Rift-Born +1 ab Phase 2.
748. [P2] Rift-Born: Boss-Phase schon bei 60 % statt 50 % Kraft.
749. [P2] Gegner-Energie beim Start: Story 8, Tamer 10, Veteran 10, Rift-Born 10 mit +1 in Runde 1; Spieler immer 10 (bestehender Startwert).
750. [P3] Eigene Stufe "Werkstatt": sechs Regler aus der Tabelle frei wählbar, Spielstand als "Werkstatt" markiert, Ranglisten-Einträge dafür gesperrt.
751. [P3] Werkstatt-Einstellungen lassen sich als Kurzcode aus 8 Zeichen teilen und eingeben.
752. [P3] Pro Stufe ein eigenes Symbol, das im Kampfstart-Banner und im Kampfende-Bericht neben dem Namen des Gegners steht.
753. [P3] Die Simulator-Zielwerte pro Stufe stehen in tools/balance/targets.json und werden von Tests gelesen, nicht im Code wiederholt.
754. [P3] Story: Wanderer kommentieren ihre stärkste Technik vor dem ersten Einsatz mit einem Satz, damit Anfänger die Gefahr lesen können.

### Kampf-Herausforderungen (Bonusziele)
755. [x] [P1] Neue Datei data/battle_goals.json: pro Wanderer und Wächter ein optionales Bonusziel mit `type`, `value` und `reward`, angezeigt als Zeile auf der Kampfstart-Karte. Erledigt: data/battle_goals.json, BattleGoals.gd; Zeile nach der Kampfstart-Meldung (✓ wenn schon erfüllt).
756. [x] [P1] Zieltypen: `win_within` (Runden), `no_faint`, `no_rest`, `only_kind` (Physisch, Fokus oder Status), `max_fielded` (Zahl), `min_hp_end` (Anteil), `reaction_count`. Erledigt: alle sieben Typen in BattleGoals.Tracker.
757. [x] [P1] Belohnungen sind nur Spielinhalte ohne Kampfvorteil über das Normale hinaus: Echo-Kristall-Splitter (5 Splitter ergeben einen Echo-Kristall), Titel und Lexikon-Einträge. Erledigt: Belohnungen shards/title/lore in GameState.records (echo_shards, echo_crystals, titles, lexicon).
758. [x] [P2] Bonusziele Crowcrest: Lio `win_within` 4, Bram `only_kind` Fokus, Kestra `no_faint`. Erledigt.
759. [x] [P2] Bonusziele Cinder Rift: Pell `reaction_count` 1, Suri `no_rest`, Orrin `max_fielded` 2. Erledigt.
760. [x] [P2] Bonusziele Murk Hollow und Saltmarsh: Ros `min_hp_end` 0,5, Neve `win_within` 5, Tobin `no_faint` für Spieler und Kestra. Erledigt (Tobin = saltmarsh/kestra_tag, zählt die ganze Spielerseite).
761. [x] [P2] Bonusziele Tide Rift: Ilka `reaction_count` 2, Maelis `win_within` 8, Drowned Heart `no_faint`. Erledigt.
762. [x] [P2] Bonusziel-Fortschritt erscheint während des Kampfes als kleines Häkchen oder Kreuz neben der Rundenzahl, sobald es sicher erfüllt oder verfehlt ist. Erledigt: Rundenzähler „R3 ✓/✗“ im Kampf (BattleGoals.Tracker.status).
763. [x] [P2] Bonusziele gelten auch in Rückkämpfen; ein bereits erfülltes Ziel zeigt sein Häkchen, gibt aber keine zweite Belohnung. Erledigt: records["goals_done"].
764. [x] [P2] Ein nicht erfülltes Bonusziel ändert nichts am Sieg, an Geld oder Wachstum. Erledigt: der Tracker hört nur zu (Test).
765. [x] [P3] Bonusziele lassen sich in den Einstellungen ausblenden (Standard an). Erledigt: Einstellung „Bonusziele“ (GameState.bonus_goals).
766. [P2] GameState.records["goals"] speichert pro NPC erfüllt ja oder nein und die beste Rundenzahl; Speicherstand-Migration setzt leere Werte.
767. [P2] Das Lexikon zeigt pro Karte die erfüllten Bonusziele als Zähler (zum Beispiel 3 von 5).
768. [P2] Ein Test prüft für jedes Bonusziel mit dem Simulator, dass das Referenzteam es auf Tamer in mindestens 20 % der Kämpfe erfüllt (kein unmögliches Ziel).
769. [P2] Bonusziel-Texte in eigener Wortwahl, de und en, höchstens 32 Zeichen für die Karte.
770. [P3] Wochen-Bonusziel offline: jeden Montag wählt der Tages-Seed ein Ziel für alle Wanderer-Rückkämpfe dieser Woche (zum Beispiel "Nur Status und Fokus").
771. [P3] Bonusziele zählen für bestehende Errungenschaften mit drei neuen Stufen: 5, 15 und alle Ziele erfüllt (scripts/core/Achievements.gd).
772. [P3] Bonusziel-Kette pro Karte: wer alle Ziele einer Karte erfüllt, schaltet einen Rückkampf mit allen Wanderern der Karte hintereinander frei ("Kartenlauf").
773. [P3] Der Kartenlauf heilt zwischen den Kämpfen nur 25 % der Kraft und zählt die Gesamtrunden.
774. [P3] Zieltyp `swap_count_max` (höchstens N Wechsel) und `same_spirling` (ein Spirling macht alle K.o.s).
775. [P3] Zieltyp `field_turns` (mindestens N Runden im eigenen Feld kämpfen).
776. [P3] Zieltyp `snare_cleared` (eine gegnerische Seitenfalle entfernen).
777. [P3] Zieltyp `no_items` (kein Gegenstand aus dem Beutel im Kampf benutzt).
778. [P3] Bonusziele für Bosse: Ashen Heart `win_within` 10 und Drowned Heart Phase 2 in höchstens 3 Runden beenden.
779. [P3] Die Kampfende-Zusammenfassung nennt das Bonusziel mit erfüllt oder verfehlt und dem Wert (zum Beispiel "4 von 4 Runden").

### Regelvarianten
780. [x] [P1] Neue Datei data/rule_variants.json und Lader in BattleRules: jede Variante ist ein Satz von Zahlen-Schlüsseln, die BattleModel beim Start liest; kein Sonderfall im Code pro Variante. Erledigt: data/rule_variants.json, BattleRules.VARIANT_KEYS/variant_values, BattleModel.variants und rules (im Replay gespeichert).
781. [x] [P1] Varianten sind kombinierbar bis 3 gleichzeitig; widersprüchliche Paare stehen in `excludes` und werden beim Laden abgelehnt. Erledigt: variant_conflict, validate_variants (auch in validate_data).
782. [x] [P2] Variante "Funkenarm": max. Energie 6, Start-Energie 6. Erledigt.
783. [x] [P2] Variante "Volle Ladung": Start-Energie 10, kein Energiegewinn pro Runde, Rasten gibt +3 statt +2. Erledigt.
784. [x] [P2] Variante "Wechselzoll": jeder freiwillige Wechsel kostet den eingewechselten Spirling 2 Energie. Erledigt.
785. [x] [P2] Variante "Glasklingen": max. Kraft aller Spirlings ×0,5. Erledigt.
786. [x] [P2] Variante "Zähe Runde": max. Kraft aller Spirlings ×1,5. Erledigt.
787. [x] [P2] Variante "Ohne Heimvorteil": der Bonus für Techniken des eigenen Elements (DamageCalc.STAB 1,25) fällt auf 1,0. Erledigt.
788. [x] [P2] Variante "Stufenstarr": keine Stufenänderungen, Stufen-Techniken sind im Menü gesperrt. Erledigt: Schlüssel stages_locked, BattleModel.move_locked.
789. [x] [P2] Variante "Kurzer Atem": jeder Status endet spätestens nach 2 Runden, auch Scorch, Root und Jolt. Erledigt.
790. [x] [P2] Variante "Starke Reaktionen": alle Reaktions-Faktoren aus REACTIONS gelten doppelt so stark über 1,0 hinaus (×1,2 wird ×1,4). Erledigt.
791. [x] [P2] Variante "Feldwirbel": alle 3 Runden legt der Kampf-Seed ein zufälliges der Felder, Ansage eine Runde vorher. Erledigt: Schlüssel field_swirl_every, Ereignis FIELD_NEXT.
792. [x] [P2] Variante "Kein Rasten": die Aktion Rasten fehlt, dafür +2 Energie pro Runde. Erledigt: Schlüssel rest_only_as_pass (Rasten bleibt nur als Passen, wenn nichts bezahlbar ist).
793. [x] [P2] Variante "Spätes Ende": ab Runde 15 verliert jeder aktive Spirling am Rundenende 1/8 seiner max. Kraft. Erledigt.
794. [P3] Variante "Einmal jede": jede Technik kann pro Spirling nur einmal pro Kampf gewählt werden.
795. [P3] Variante "Spiegelkampf": der Gegner kämpft mit einer Kopie des Spieler-Teams auf gleichem Ring und mit gleichen Techniken.
796. [P2] Varianten erscheinen beim Kampfstart als Regel-Banner mit eigenem Symbol pro Variante und im Pause-Menü als Liste.
797. [P2] Kampf-Replays speichern die Varianten-IDs; BattleReplay lehnt Replays mit unbekannter Variante mit klarer Meldung ab.
798. [P2] Für jede Variante ein Fuzz-Test mit 20 Zufallskämpfen ohne Absturz und ohne Erreichen der 60-Runden-Grenze.
799. [P2] Turm und Wochen-Herausforderung dürfen Varianten aus der Datei ziehen; die Auswahl erfolgt per Seed und steht vorher auf der Stockwerk-Karte.
800. [P2] Die KI erkennt Varianten: bei "Kein Rasten" rechnet sie mit +2 Energie, bei "Stufenstarr" wertet sie Stufen-Techniken mit 0.
801. [P3] Variante "Leere Bank": jede Seite kämpft nur mit dem ersten Spirling, die Bank ist gesperrt.
802. [P3] Variante "Doppelfeld": zwei Felder gelten gleichzeitig, Boni und Schwächungen multiplizieren sich.
803. [P3] Variante "Fallenfrei": Seitenfallen-Techniken schlagen immer fehl.
804. [P3] Variante "Gleiche Kraft": alle Spirlings haben 150 max. Kraft, unabhängig von Art und Ring.
805. [P3] Variante "Langsame Ladung": der Energiegewinn von 1 pro Runde gilt nur in jeder zweiten Runde.
806. [P3] Regelvarianten-Seite im Lexikon listet jede Variante mit ihren Zahlen und wo sie vorkommt.
807. [P3] Eigene Übungskämpfe im Leuchtturm gegen ein gespeichertes Wanderer-Team mit frei wählbaren Varianten, ohne Belohnung.

### Balance-Simulator ausbauen
808. [x] [P1] tools/balance_sim.gd nimmt benannte Schalter statt fester Reihenfolge: `--level`, `--rounds`, `--seed`, `--mode`, `--ai`, `--out`, `--json`.
809. [x] [P1] Modus `team`: zufällige gültige 3er- und 5er-Teams pro Seed, beide Seiten auf KI-Stufe 2, 500 Kämpfe pro Lauf, Bericht nach Art, Technik und Element.
810. [x] [P1] Modus `warden`: jedes Referenzteam aus tools/balance/ref_teams.json kämpft 100-mal gegen jeden Wächter pro Schwierigkeit, mit der KI-Stufe und den Regeln der Stufe. Erledigt: BalanceSim.run_warden, `tools/balance_sim.gd --mode warden [--section S]`.
811. [x] [P1] BalanceSim nutzt für alle Modi dieselbe BattleModel-Logik mit neuen Effekten, Profilen, Varianten und Schwierigkeitswerten, ohne eigenen Schadensweg.
812. [x] [P1] tools/balance/ref_teams.json mit je drei Referenzteams pro Story-Abschnitt (vor Orrin, vor Maelis, nach beiden Rissen), gebaut aus Startern und Wild-Arten der Karten auf typischem Ring. Erledigt: der Abschnitt „nach beiden Rissen“ kämpft gegen die Revanche-Teams beider Wächter.
813. [x] [P1] Messwert "Züge bis K.o." pro Kampf; Zielband bei Ring 36 im Duell 2,5 bis 4,0 im Schnitt, sonst Hinweis im Bericht.
814. [x] [P1] Messwert "Vorteil des Ersten": Anteil der Siege des schnelleren Spirlings im Duell; Zielwert höchstens 62 %.
815. [x] [P1] JSON-Ausgabe mit allen Messwerten, damit Tests und Vergleiche sie lesen, ohne Markdown zu parsen.
816. [P2] Basiswert-Datei tools/balance/baseline_lv36.json und Schalter `--compare`: der Bericht markiert jede Art und Technik, deren Gewinnrate sich um mehr als 8 Punkte verschoben hat.
817. [P2] Modus `ladder`: gleiche Teams, KI-Stufe n gegen n-1; Zielwerte Stufe 1 gegen 0 mindestens 75 %, 2 gegen 1 mindestens 60 %, 3 gegen 2 mindestens 55 %.
818. [P2] Modus `mono`: Teams aus nur einem Element (je 3 Arten, wo möglich), Zielband 42 bis 58 % pro Element.
819. [P2] Modus `puzzle`: löst alle Rätsel aus data/puzzles.json und schreibt Lösungszahl und kleinste Rundenzahl.
820. [P2] Modus `goals`: prüft jedes Bonusziel mit dem Referenzteam auf Tamer und schreibt die Erfüllungsrate.
821. [P2] Schalter `--field <id>` und `--variant <id>` für alle Modi, damit Felder und Regelvarianten einzeln messbar sind.
822. [P2] Schalter `--difficulty <stufe>` setzt Gegner-Spark, Ring-Versatz, KI und Andenken wie im Spiel.
823. [P2] Messwert "Rast-Anteil": Anteil der Aktionen, die Rasten sind; Zielband 10 bis 25 %.
824. [P3] Messwert "Energie pro Runde": verbrauchte Energie im Schnitt pro Spirling und Runde, getrennt nach Art.
825. [P2] Messwert "Status-Treffer": Anteil gelandeter Status pro Technik und Zahl der Runden, die ein Status im Schnitt hält.
826. [P2] Messwert "Reaktionen": Zahl der ausgelösten Reaktionen pro 100 Kämpfe, getrennt nach Reaktion.
827. [P3] Messwert "Seitenfallen": Anteil gelegter Fallen, die vor Kampfende ausgelöst wurden.
828. [P2] Messwert "Andenken-Wert": Gewinnrate mit gegenüber ohne Andenken pro Andenken; Zielwert höchstens +6 Punkte.
829. [P2] Messwert "Feld-Wert": Gewinnrate des verstärkten Elements mit gegenüber ohne Feld; Zielband +8 bis +15 Punkte.
830. [P2] Mehrere Seeds pro Lauf (`--seeds 5`): der Bericht zeigt Mittelwert und Spanne und markiert Werte mit Spanne über 10 Punkte als unsicher.
831. [P2] Gleich-gegen-gleich-Prüfung: jede Art gegen sich selbst muss 45 bis 55 % ergeben, sonst hat die Sitzseite einen Vorteil.
832. [P3] Profil-Bericht: Gewinnrate jedes KI-Profils mit gleichen Teams gegen "ausgewogen"; kein Profil über 60 % oder unter 40 %.
833. [P2] Der Bericht listet jede neue Technik, die bei 500 Team-Kämpfen weniger als 1 % der Wahlen ihres Elements bekommt.
834. [P3] Modus `sweep`: Ring 5 bis 60 in Schritten von 5, Gewinnrate pro Art als CSV für Diagramme in docs/balance/.
835. [P3] Modus `ablation`: entfernt eine Technik aus allen Lernlisten und misst die Gewinnrate-Änderung der Arten, die sie lernen ("Technik-Wert").
836. [P3] Modus `wayfarer`: alle Wanderer-Teams gegen die Referenzteams ihres Abschnitts, Zielband auf Tamer 70 bis 90 % Spielersieg.
837. [P3] Laufzeit: 1.000 Duelle unter 20 Sekunden headless; bei Bedarf Aufteilung auf WorkerThreadPool mit getrennten RNG-Seeds.
838. [P3] Der Simulator schreibt seine Berichte nach docs/balance/<datum>_<modus>.md, statt nur in die Konsole.
839. [P3] Ein Skript tools/balance/run_all.sh führt alle Modi nacheinander aus und erzeugt eine Übersicht mit roten Markierungen für Werte außerhalb der Zielbänder.

### Automatisierte Balance-Tests
840. [x] [P1] Neuer Test tests/unit/test_move_curve.gd: für jede Schadens-Technik ohne Overcharge liegt Stärke mal Genauigkeit geteilt durch (Energie + 1) zwischen 9 und 18; Effekt-Techniken haben einen festen Abschlag aus einer Tabelle im Test.
841. [x] [P1] Test: Fuzz-Lauf über 300 Zufallskämpfe, in denen beide Seiten nur neue Techniken nutzen, ohne Absturz und ohne Erreichen der 60-Runden-Grenze.
842. [x] [P1] Test: keine Technik hat Genauigkeit unter 75 % und keine Schadens-Technik eine Status-Chance über 30 %.
843. [x] [P1] Test: jede `cooldown`-Technik hat Stärke mindestens 110 und Energie mindestens 7.
844. [x] [P1] Test: jedes Element hat nach der Erweiterung mindestens 14 Techniken, davon mindestens 3 Status-Techniken und mindestens eine mit Energie 1 oder 2.
845. [x] [P1] Test: jede Art kann bis Ring 5 eine Schadens-Technik ihres Elements und bis Ring 30 Techniken aus mindestens 2 Elementen.
846. [x] [P1] Test: im Modus `warden` liegt die Gewinnrate jedes Referenzteams in den Zielbändern aus tools/balance/targets.json (mit kleiner Rundenzahl im normalen CI-Lauf). Erledigt: tests/unit/test_warden_sim.gd prüft das Mittel der drei Teams je Wächter und Stufe (12 Kämpfe, Spielraum 10 Punkte); einzelne Teams schwanken je nach Elementlage stark. Revanchen prüfen nur die Reihenfolge der Stufen.
847. [x] [P1] Test pro neuem Effekt-Baustein in tests/unit/test_move_effects.gd mit fester Kampflage und festem Seed, der das genaue Ergebnis prüft (Schaden, Energie, Status, Stufe).
848. [x] [P1] Test: `delayed_hit`, `side_snare` und `cooldown` überstehen ein Replay-Hin-und-zurück mit BattleReplay ohne Abweichung. Erledigt: test_move_curve.gd (Fallen und Abklingzeit, dazu delayed_hit).
849. [x] [P1] Test: im Modus `team` bei Ring 36 liegt keine Art unter 30 % oder über 70 % (zusätzlich zum bestehenden Duell-Band 25 bis 75 %).
850. [P2] Test: der Vorteil des Ersten liegt bei Ring 20 und 36 höchstens bei 62 %.
851. [P2] Test: die Züge bis K.o. liegen bei Ring 36 im Duell im Schnitt zwischen 2,5 und 4,0.
852. [P2] Test: der Rast-Anteil liegt im Modus `team` zwischen 10 und 25 %.
853. [P2] Test: kein Andenken hebt die Gewinnrate um mehr als 6 Punkte.
854. [P2] Test: jedes Feld hebt das verstärkte Element um 8 bis 15 Punkte.
855. [P2] Test: die KI-Leiter erfüllt die Zielwerte (1 gegen 0 mindestens 75 %, 2 gegen 1 mindestens 60 %, 3 gegen 2 mindestens 55 %).
856. [P2] Test: jedes Element liegt im Modus `mono` zwischen 42 und 58 %.
857. [P2] Test: jede Reaktion wird im Fuzz-Lauf über 200 Kämpfe mindestens einmal ausgelöst und verändert den Schaden genau um ihren Faktor.
858. [P2] Test: jede Seitenfalle wirkt genau einmal und verschwindet danach; Scatter Gale entfernt alle Fallen der eigenen Seite.
859. [P2] Test: `heal_block` verhindert Heiltechnik, Gabe-Regeneration, Feld-Heilen und Andenken-Heilen, und nichts anderes.
860. [P2] Test: Priorität -1 handelt nach allen anderen Techniken derselben Runde, auch nach langsameren Spirlings.
861. [P2] Test: jede Regelvariante ändert genau die Werte aus ihrer Datei (Vergleich eines festen Kampfes mit und ohne Variante).
862. [P2] Test: Schwierigkeits-Werte (Gegner-Spark, Ring-Versatz, Energie-Start, Schwarmgröße) entsprechen der Tabelle in GameState.
863. [P3] Test: Rückenwind wird nie ohne Bestätigung angewendet und nie auf Veteran oder Rift-Born angeboten.
864. [P2] Test: der Vergleich mit tools/balance/baseline_lv36.json schlägt fehl, wenn sich eine Art um mehr als 8 Punkte verschiebt und die Basiswert-Datei nicht im selben Commit aktualisiert wurde.
865. [P2] Lange Simulator-Tests laufen mit dem GUT-Präfix `test_slow_` nur im nächtlichen CI-Lauf; der normale Lauf bleibt unter 90 Sekunden für alle Balance-Tests.
866. [P2] Test: jede neue Technik hat einen Eintrag in data/i18n/de.json und keinen Namen, der einer Art, einem Gegenstand oder einer bestehenden Technik gleicht.
867. [P2] Test: tools/ip_check.sh läuft über alle neuen Technik-, Regel-, Profil- und Rätselnamen.
868. [P3] Test: im Modus `ablation` hat jede Technik einen messbaren Wert (Änderung mindestens 0,5 Punkte bei der lernenden Art), sonst Hinweis "ohne Zweck".
869. [P3] Test: die Simulator-Laufzeit für 1.000 Duelle bleibt unter 20 Sekunden auf dem CI-Rechner.
870. [P3] Test: der Bericht aus dem Modus `sweep` hat für jede Art und jeden Ring-Schritt eine Zeile.
871. [P3] Test: die Ergebnisse für denselben Seed sind in allen neuen Modi gleich (Determinismus).
872. [P3] Test: kein Wanderer-Team liegt im Modus `wayfarer` außerhalb von 60 bis 95 % Spielersieg auf Tamer.

### docs/BALANCE.md und Balance-Ablauf
873. [x] [P1] docs/BALANCE.md erhält eine Tabelle "Zielbänder" mit allen Messwerten, Zielwerten und dem Test, der sie prüft.
874. [P2] Abschnitt "Neue Technik hinzufügen": Kurve prüfen, Lernliste prüfen, Simulator im Modus `team` und `ablation`, Basiswert aktualisieren, Name prüfen.
875. [P2] Abschnitt "Schwierigkeitsstufen" mit der Tabelle Gegner-Ring, Spark, KI, Andenken, Energie-Start und Wächter-Regel-Stärke pro Stufe.
876. [P2] Abschnitt "KI-Profile" mit allen Gewichten, Kurzsätzen und der Zuordnung zu Wanderern und Wächtern.
877. [P2] Abschnitt "Wächter-Rätsel schreiben": Datenformat, Ziele, Löser-Test, Hinweis-Regeln, Laternen-Bewertung.
878. [P2] Abschnitt "Regelvarianten" mit allen Varianten, ihren Zahlen und ausgeschlossenen Paaren.
879. [P2] Änderungsprotokoll als Tabelle "Was, Vorher, Nachher, Warum" für jede Änderung aus "Bestehende Techniken nachjustieren", mit den Simulator-Werten vor und nach der Änderung.
880. [P2] Abschnitt "Referenzteams": welche Teams, welcher Ring, warum sie den typischen Spieler abbilden.
881. [P2] Der vollständige Bericht bei Ring 36 im Dokument wird nach jeder Balance-Änderung mit `tools/balance/run_all.sh` neu erzeugt, nicht von Hand bearbeitet.
882. [P3] Abschnitt "Bekannte Grenzfälle": Arten, die zwischen Ring 10 und 28 wegen Lernlisten-Sprüngen schwanken, mit Ring und Wert.
883. [P3] Abschnitt "Seitenfallen und Konter": welche Arten Fallen legen, welche sie entfernen können.
884. [P3] Abschnitt "Bonusziele" mit allen Zielen pro NPC und der gemessenen Erfüllungsrate.
885. [P3] Diagramme aus dem Modus `sweep` als SVG in docs/balance/, im Dokument verlinkt.
886. [P3] Ein monatlicher Balance-Lauf im nächtlichen CI erzeugt einen Bericht und öffnet einen Hinweis, wenn ein Zielband verletzt ist.
887. [P3] Abschnitt "Feste Zahlen": Liste der Originalitäts-Werte, die keine Balance-Änderung anfassen darf (Glückstreffer 1/12 und ×1,4, Status-Ticks 1/12, Jolt 20 %, Drowse 2 Runden, Team 5, Ring-Obergrenze 60).
888. [P3] Abschnitt "Glossar für Balance-Texte" mit den Spielerwörtern (Ring, Kraft, Wucht, Schutz, Fokus, Tempo, Gabe, Andenken, Technik), damit Berichte und Spieltexte dieselben Wörter nutzen.
889. [P3] Abschnitt "Ablauf für Balance-PRs": Simulator-Bericht als Anhang, Basiswert im selben Commit, Zielband-Tabelle grün.
