# IP- und Patent-Audit (Stand: 1. November 2026)

> Erstellt von einer KI, **ohne Prüfung durch einen Anwalt oder Patentanwalt** (Ali hat sich bewusst dagegen
> entschieden). Patentnummern und Verfahrensstände stammen aus Medienberichten. Die Register DPMA, EUIPO und
> WIPO waren aus dieser Umgebung nicht erreichbar (Netzwerksperre); die Markenbewertung beruht daher auf
> Websuchen und ist keine Registerrecherche.

## Ergebnis

Alle gelben und roten Punkte der ersten Fassung sind im Code behoben (Spalte „Status“). Offen bleibt nur, was
sich nicht im Code lösen lässt: der Name (Punkt 12, siehe Namensbewertung) und die Bundle-ID (Punkt 13,
braucht Alis Domain).

| # | Bereich | Befund (erste Fassung) | Risiko vorher | Status |
| --- | --- | --- | --- | --- |
| 1 | Bonding-Minispiel | Schrumpfende Ringe + Tipp im richtigen Moment erhöht die Chance: ähnelt dem bekannten Fangkreis | Mittel–hoch | **Behoben.** Ersetzt durch „Echo-Ruf“ (`scripts/battle/BondEcho.gd`, `BondMinigame.gd`): Der Spirling ruft eine Folge auf Raute/Quadrat/Dreieck, der Spieler wiederholt sie. Bewertet wird nur die Reihenfolge, kein Timing gegen ein schrumpfendes Ziel, keine Quote während des Spiels. Regel in LEGAL.md/AGENTS.md festgeschrieben. |
| 2 | Kernmechaniken | Kein Werfen/Zielen, keine Live-Quote, kein Reiten/Fliegen, kein Wurf-Beschwören, separater Kampfbildschirm | Niedrig | Unverändert gut. |
| 3 | Menü-Kampf, Typen, Status, Entwicklungen | Genre-Standard, eigene Formel, 8 eigene Elemente, Energie statt AP | Niedrig | Unverändert gut. |
| 4 | Kampf-Layout | Eigene Kreatur unten links, Gegner oben rechts wie im Vorbild | Niedrig–mittel | **Behoben.** Gespiegelt: Gegner oben links, eigene Kreatur unten rechts, Infostreifen auf den Gegenseiten (`BattleScene._layout_field`). Sprites werden passend gespiegelt. |
| 5 | Kampftexte | Aufforderung zur Aktionswahl und einzelne Kampfmeldungen wortgleich mit dem Vorbild | Niedrig (aber in der Summe relevant, § 4 Nr. 3 UWG) | **Behoben.** Alle Kampfmeldungen sind eigene Formulierungen (z. B. „Orders for %s?“, „%s steps out!“, „You slipped away.“, „The move found nothing to strike.“). `tools/ip_check.sh` sperrt die bekannten Vorbild-Phrasen jetzt in CI (base64-kodierte Liste). |
| 6 | Attackennamen | Häufung bekannter Attackenwörter | Niedrig | **Behoben.** Tackle Rush → Headlong Charge, Ember Snap → Cinder Nip, Spore Cloud → Puffcap Haze, Shade Claw → Dusk Rake, Moss Whip → Lichen Lash, Static Nip → Crackle Bite, Static Field → Charged Mist, Bubble Pop → Fizz Pop, Gust Slice → Breeze Slice. |
| 7 | Kreaturennamen | „Breezel“ klang an einen bekannten Namen an | Niedrig | **Behoben.** Breezel → Zephlet (Daten, Sprites, Asset-Log, Generator). Übrige 14 Namen: eigene Kunstwörter, keine Treffer gefunden. |
| 8 | NPC-Klasse | „Hiker“ ist eine bekannte Trainerklasse | Niedrig | **Behoben.** „Ridgewalker Bram“. |
| 9 | Retro-Palette | Eigene Farbwerte | Niedrig | Unverändert gut. |
| 10 | Assets | Eigene, per Skript erzeugte Pixel-Art (`tools/art/`), Asset-Log Pflicht in CI | Niedrig | Unverändert gut. Für künftige Auftragsarbeiten: schriftlicher Vertrag mit ausschließlichem Nutzungsrecht inkl. Bearbeitung. |
| 11 | Interne Doku nennt das Vorbild | AGENTS.md (Fan-Mod als Benchmark), README („…-style depth“) | Niedrig–mittel | **Behoben.** Formulierungen neutralisiert. Repo trotzdem privat halten. |
| 12 | Name „Chimora“ | Ähnlich zu „Chimera Entertainment GmbH“ (Games-Studio, München) | Mittel | **Bewertet, siehe unten.** Empfehlung: Name behalten, aber vor dem Launch selbst im Register prüfen und anmelden. |
| 13 | Bundle-ID `com.chimora.game` | Platzhalter | Niedrig, aber endgültig | **Offen**, braucht Alis eigene Domain (Checkliste). |
| 14 | Lizenzhinweis der Engine | Godot (MIT) verlangt, dass der Lizenztext im Spiel einsehbar ist | Niedrig | **Behoben.** Einstellungen → Legal → Licences zeigt den Godot-Lizenztext (`scripts/core/LegalInfo.gd`). |

## Namensbewertung „Chimora“

Was die Websuche (1. 11. 2026) ergab:
- **Kein Spiel, keine App und keine eingetragene Marke „Chimora“ gefunden.** Treffer gab es nur für einen
  Musiker bzw. ein Album namens „Chimora“ (Musik) und ein kleines GitHub-Projekt.
- **„Chimera“ ist in Games sehr verbreitet:** Chimera Entertainment GmbH (München), ein Steam-Spiel
  „Chimera“, ein spanisches „Chimera Studio“ und weitere. Ein so häufig genutztes Wort aus der Mythologie ist
  als Marke eher schwach; Inhaber können es kaum gegen ähnlich klingende, aber andere Kunstwörter
  durchsetzen.
- „Chimora“ unterscheidet sich im Klang (betontes „-mo-“) und im Schriftbild. Ein Firmenname
  („Chimera Entertainment“) und ein Spieltitel werden zudem anders wahrgenommen.

**Einschätzung:** geringes bis mittleres Risiko. Empfehlung: **Chimora behalten**, sofern Alis eigene
Registersuche (Anleitung in [CHECKLISTE_ALI.md](CHECKLISTE_ALI.md)) keinen Treffer „Chimora“ oder sehr
ähnlich in Klasse 9/41 zeigt. Dann die Marke selbst beim DPMA oder EUIPO anmelden, das ist der beste Schutz.

**Plan B, falls die Registersuche einen Konflikt zeigt:** **„Spirlings of Veydal“** (bzw. kurz „Spirlings“).
Für „Spirlings“ und „Veydal“ fand die Websuche keinerlei Treffer als Spiel, App oder Marke, beide Wörter
sind bereits die eigenen Begriffe des Spiels, und der Titel sagt sofort, worum es geht. Der Umstieg wäre im
Code klein (Titel in `scripts/ui/TitleArt.gd`, `project.godot`, Store-Texte).

## Patent-Lage (laut Berichten)

- Nintendo und sein Lizenzpartner klagen seit September 2024 in Japan gegen Pocketpair (Palworld), gestützt auf
  die japanischen Patente **JP 7545191, JP 7493117 und JP 7528390** (europäische Gegenstücke wurden nicht
  gefunden) zu (a) Werfen eines Gegenstands auf eine Kreatur im Feld zum Fangen, (b) Anzeige der
  Fangwahrscheinlichkeit beim Zielen, (c) Reiten/Fliegen mit Wechsel der Fortbewegung. Laut Alis Briefing
  geht es nur noch um alte Palworld-Versionen; eine vorläufige Einschätzung des Gerichts wird um den
  **9. November 2026** erwartet.
- In den USA wurden 2025 verwandte Patente erteilt, u. a. **US 12,403,397** („Kreatur ins Feld rufen, die
  selbstständig kämpft“). Chimora: Kreaturen kämpfen nur im separaten, rundenbasierten Kampfbildschirm.
- Japan hat laut Berichten im Mai 2026 eine Nintendo-Anmeldung zum Fangen per Touchscreen zurückgewiesen
  (Anmeldung 2026-019762). Das zeigt, dass Nintendo gezielt Mobile-Fangmechaniken absichern will; darum der
  Umbau des Bond-Minispiels.
- Chimora vermeidet (a), (b) und (c) sowie Timing-Kreise beim Rekrutieren. Kampf ist menübasiert in einem
  eigenen Bildschirm, wie bei vielen unbehelligten Genre-Titeln (Temtem, Coromon, Cassette Beasts, Nexomon).

## Regeln, damit es so bleibt

- Neue Mechaniken gegen LEGAL.md prüfen, besonders alles rund ums Rekrutieren, Werfen, Zielen und Reiten.
- `tools/ip_check.sh` blockiert verbotene Begriffe und fehlende Asset-Log-Einträge in CI.
- Keine fremden Spiele- oder Markennamen in Store-Texten, Keywords oder Anzeigen.
