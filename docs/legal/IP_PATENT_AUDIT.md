# IP- und Patent-Audit (Stand: 1. November 2026, Code-Stand M5)

> **Keine Rechtsberatung.** Dieses Audit ist eine technische Bestandsaufnahme, keine Freedom-to-Operate-Analyse.
> Eine verbindliche Aussage zu Patentrisiken kann nur eine Patentanwältin/ein Patentanwalt nach Recherche in den
> Patentregistern (JP, US, EP, DE) treffen. Patentnummern und Verfahrensstände unten stammen aus Medienberichten
> und müssen vom Anwalt verifiziert werden.

## Ergebnis in einem Satz

Chimora ist insgesamt gut aufgestellt (eigene Namen, eigenes Elementsystem, keine fremden Assets, Menü-Kampf,
kein Wurf-Fangen), aber **ein Punkt sollte vor dem Launch geändert werden: das Bonding-Minispiel mit
schrumpfenden Ringen**. Dazu kommen ein paar kleine Namens- und Textanpassungen und die Markenprüfung für
„Chimora“ wegen der Ähnlichkeit zu „Chimera Entertainment“.

## Ampel

| # | Bereich | Befund | Risiko | Empfehlung |
| --- | --- | --- | --- | --- |
| 1 | **Bonding-Minispiel** (`scripts/battle/BondTiming.gd`, `scripts/battle/presenter/BondMinigame.gd`) | Ringe schrumpfen auf einen Zielring zu, ein Tipp im richtigen Moment erhöht die Fang-/Bond-Chance. Das ähnelt optisch und funktional dem schrumpfenden Kreis beim Fangen in den bekannten Monster-Spielen (Ring wird kleiner, Timing verbessert die Fangrate). Nintendo hat laut Berichten auch Patente/Anmeldungen zum Fangen per Touchscreen verfolgt; eine davon wurde laut Berichten im Mai 2026 in Japan zurückgewiesen. | **Mittel–hoch** (größtes Einzelrisiko im Code) | Minispiel umbauen, siehe unten „Vorschlag Bonding v2“. Danach Patentanwalt gezielt fragen: „Timing-Eingabe beeinflusst Erfolgswahrscheinlichkeit beim Rekrutieren einer Kreatur in einem Menü-Kampf“. |
| 2 | Kernmechaniken (`AGENTS.md` Regel 2) | Kein Werfen/Zielen, keine Live-Fangquote, kein Reiten/Fliegen auf Kreaturen, kein Beschwören per Wurf, Kampf in separatem Bildschirm. | Niedrig | So lassen. Bei jeder neuen Mechanik gegen die Liste in LEGAL.md prüfen. |
| 3 | Rundenbasierter Menü-Kampf mit Typen-Tabelle, Statuseffekten, Entwicklungen | Genre-Standard (Temtem, Coromon, Cassette Beasts, Nexomon u. a.), nicht Gegenstand von Nintendos bekannten Klagen. Eigene Schadensformel, eigene 8 Elemente, Energie statt AP. | Niedrig | Keine Formeln oder Tabellen anderer Spiele übernehmen (bereits Regel). |
| 4 | Kampf-Layout (`scripts/battle/presenter/BattleScene.gd`) | Eigene Kreatur unten links, Gegner oben rechts: das ist dieselbe Anordnung wie im Vorbild. Positionen allein sind kaum schützbar, aber zusammen mit ähnlichen Infoboxen entsteht ein „Look-alike“-Eindruck. | Niedrig–mittel | Wenn echte Grafik kommt: eigene Formensprache für HP-Leiste und Infostreifen, gern auch andere Anordnung (z. B. beide Kreaturen seitlich, Infostreifen unten). Screenshots vor Launch von Dritten neutral vergleichen lassen. |
| 5 | Kampftext `"What will %s do?"` (`scripts/battle/presenter/`) | Wortgleich mit dem bekannten Kampf-Prompt des Vorbilds. Kurze Sätze sind urheberrechtlich meist nicht geschützt, wirken aber wie eine Kopie und können in einem Streit als Indiz dienen. | Niedrig | Ersetzen, z. B. `"%s is ready. Your call?"` oder `"Orders for %s?"`. |
| 6 | Attackennamen (`data/moves.json`) | „Tackle Rush“, „Ember Snap“, „Spore Cloud“, „Shade Claw“, „Moss Whip“, „Static Nip“/„Static Field“ enthalten Wörter, die als Attacken- bzw. Fähigkeitsnamen im Vorbild bekannt sind. Einzelwörter sind frei, aber die Häufung fällt auf. | Niedrig | Umbenennen, z. B. Tackle Rush → „Headlong Charge“, Ember Snap → „Spark Nip“, Spore Cloud → „Puffcap Haze“, Shade Claw → „Dusk Rake“, Moss Whip → „Lichen Lash“, Static Nip → „Crackle Bite“, Static Field → „Charged Mist“. |
| 7 | Kreaturennamen (`data/spirlings.json`) | Alle 15 Namen sind eigene Kunstwörter, kein „-mon“, keine bekannten Treffer. „Breezel“ klingt entfernt an einen bekannten Namen an. | Niedrig | Vor Launch jeden Namen kurz in EUIPO/DPMA/USPTO und den großen Fan-Wikis (Temtem, Coromon, Digimon, Yo-kai Watch) suchen. „Breezel“ optional ersetzen. |
| 8 | Struktur „3 Starter Feuer/Wasser/Pflanze, Rivale, Wanderer-Trainer“ | Genre-Konvention, nicht schützbar. NPC-Klasse „Hiker“ ist zusätzlich eine bekannte Trainerklasse. | Niedrig | Optional eigene Klassen (z. B. „Ridgewalker Bram“). |
| 9 | Retro-Palette 4 Grüntöne (`EraManager.MONO_PALETTE`) | Farben sind nicht schützbar; eigene Werte. | Niedrig | So lassen. Nicht im Marketing mit Konsolen-Optik oder Markennamen werben. |
| 10 | Assets (`art/`, `audio/`) | Aktuell keine Dateien, nur Code-Platzhalter und eigene `PixelFont`. `tools/ip_check.sh` erzwingt Einträge in `docs/ASSET_LOG.md`. | Niedrig | Für jede beauftragte Grafik/Musik einen schriftlichen Vertrag mit **ausschließlichem Nutzungsrecht inkl. Bearbeitung** (oder Übertragung so weit möglich) ablegen. KI-generierte Assets: Tool, Lizenz und Prompt im Log vermerken; keine Prompts mit fremden Spielen/Figuren. |
| 11 | **Interne Doku nennt das Vorbild** | `AGENTS.md` nennt eine Fan-Mod des Vorbilds als Benchmark, `README.md` schreibt „Unbound-style depth“. Ist das Repo öffentlich oder wird es im Streit offengelegt, kann das als Beleg für Anlehnung gelesen werden. | Niedrig–mittel | Repo privat halten. Formulierungen neutralisieren (z. B. „hohe Spieltiefe: 4 Schwierigkeitsgrade mit Levelgrenzen …“). Ali entscheidet über AGENTS.md, daher hier nicht geändert. |
| 12 | **Name „Chimora“** | Kurze Websuche fand kein Spiel/keine App mit genau diesem Namen, aber **Chimera Entertainment GmbH** (Games-Studio aus München). „Chimora“ und „Chimera“ unterscheiden sich in einem Vokal, gleiche Branche: Verwechslungsgefahr ist denkbar. | **Mittel** (bis zur professionellen Recherche) | Markenrecherche durch Markenanwalt (DPMA, EUIPO, WIPO, USPTO; Klassen 9, 41, 42, ggf. 28) **bevor** Logo, Domain und Store-Eintrag festgezurrt werden. Ersatznamen als Plan B bereithalten. |
| 13 | Bundle-ID `com.chimora.game` (`export_presets.cfg`) | Platzhalter, Domain gehört Ali vermutlich nicht. | Niedrig (aber endgültig) | Vor dem ersten Upload auf eigene Domain umstellen; die ID kann nie mehr geändert werden. |

## Patent-Lage (kurz, laut Berichten; vom Anwalt zu verifizieren)

- Nintendo und sein Lizenzpartner klagen seit September 2024 in Japan gegen Pocketpair (Palworld). Gestützt auf
  japanische Patente zu (a) Werfen eines Gegenstands auf eine Kreatur im Feld zum Fangen, (b) Anzeige der
  Fangwahrscheinlichkeit beim Zielen und (c) Reiten/Fliegen mit Wechsel des Fortbewegungsmodus. Laut Alis
  Briefing umfasst das Verfahren nur noch alte Palworld-Versionen; eine vorläufige Einschätzung des Gerichts
  wird um den **9. November 2026** erwartet. Ergebnis abwarten und mit dem Anwalt besprechen.
- In den USA wurden 2025 verwandte Nintendo-Patente erteilt (u. a. zum „Beschwören einer Kreatur, die
  selbstständig kämpft“). Mindestens eines wurde laut Berichten vom USPTO zur erneuten Prüfung gestellt.
- Japan hat laut Berichten im Mai 2026 eine Nintendo-Anmeldung zum Fangen per Touchscreen zurückgewiesen.
  Das zeigt, dass Nintendo gezielt **Mobile-Varianten** absichern will, darum ist Punkt 1 wichtig.
- Chimora vermeidet (a), (b) und (c) bewusst. Das Restrisiko liegt bei Timing-basierten Fang-Minispielen.

## Vorschlag Bonding v2 (ersetzt die schrumpfenden Ringe)

Ziel: weg vom Bild „Kreis schrumpft, im richtigen Moment tippen, Fangrate steigt“.

**„Echo-Melodie“**: Der wilde Spirling „singt“ eine kurze Folge von 3–5 Tönen auf 3 farbigen Feldern (wie
ein Call-and-Response). Der Spieler tippt die Folge nach. Bewertet wird die richtige Reihenfolge, nicht
das Timing gegen einen schrumpfenden Kreis. Das Ergebnis (0–1) fließt wie heute als `timing_score` in
`BondCalc` ein; angezeigt wird es erst danach (LEGAL.md bleibt erfüllt).

- Passt thematisch („Bond“ = Verständigung), ist touchfreundlich und auch für Menschen ohne gutes
  Rhythmusgefühl fair (Barrierefreiheit: optional Töne + Farben + Symbole).
- Umbau ist klein: `BondTiming` → `BondEcho` (reine Logik + GUT-Tests), `BondMinigame` neu zeichnen.
- Umsetzung bitte als eigener PR; dieses Audit ändert absichtlich keinen Spielcode.

## Was bereits gut ist

- `tools/ip_check.sh` blockiert verbotene Begriffe in CI und erzwingt das Asset-Log.
- Eigene Begriffe (Spirling, Tamer, Spirlog, Rift, Warden, Bonding, Rest Spring) statt Genre-Markenbegriffen.
- Keine Netzwerk-, Analytics- oder Werbe-SDKs, keine Berechtigungen in den Export-Presets.
