# Kampfsystem: 1000-Punkte-Plan

Ali (2. Nov. 2026): Das Kampfsystem soll sich so tief, schnell und komfortabel anfühlen wie die
beliebtesten modernen Fan-Remakes und Schwierigkeits-Mods des Genres. Dieser Plan sammelt dafür
1000 Punkte in 25 Bereichen. Vorbild ist nur das Spielgefühl (Tiefe, Tempo, Taktik, Komfort).
Namen, Texte, Typentabellen, Techniken, Grafiken, Layouts und Formeln anderer Spiele werden nicht
übernommen. Alles hier ist in eigener Chimora-Form beschrieben.

Legende: **[x]** = umgesetzt, **[ ]** = offen. Die Datei wird von `tools/plan/plan_1000.py` erzeugt.

## Umgesetzt im ersten Schritt

- Meister-KI (Stufe 3) für Rift-Born
- Resonanz-Techniken (Ash Call, Tide Call, Murk Call) legen 5 Runden lang ein Rift-Feld
- Boss-Phasen bei halber HP
- Schadensvorschau im Technik-Menü (abschaltbar)
- Lager-Lernen: die Bank erhält die Hälfte der XP (abschaltbar)
- Ruhe-Regel: in Wayfarer-Kämpfen höchstens ein Spirling pro Seite mit Drowse

## Umgesetzt im zweiten Schritt

- Drei neue Felder (Statikschleier, Blütenstaub, Morgenschein) mit Spark Call, Bloom Call, Dawn Call
- Springflut hält Scorch fern, Blütenstaub heilt Bloom-Spirlings
- Element-Reaktionen: Volt trifft durchnässte Ziele härter, Tide löscht Scorch
- Meister-KI im Wochen-Echo
- Fuzz-Test über 60 Zufallskämpfe (Mehrfach, Boss, alle Felder)

## Umgesetzt im dritten Schritt

- Technik-Info per langem Druck: Stärke, Genauigkeit, Energie, Effekte mit Chancen
- Traits zeigen sich im Kampflog, sobald sie zum ersten Mal wirken


## Zugablauf und Grundregeln

1. [x] Ruhe-Regel in Wayfarer-Kämpfen: pro Seite darf nur ein Spirling gleichzeitig Drowse haben
2. [ ] Zugreihenfolge vor der Wahl als kleine Leiste anzeigen (wer handelt zuerst, nach SPD und Priorität)
3. [ ] Priorität +2 für seltene Schutz-Techniken einführen, sonst bleibt +1 das Maximum
4. [ ] Gleichstand bei SPD sichtbar als Münzwurf-Symbol im Kampflog
5. [ ] Rundenzähler oben links, nur in Wayfarer- und Boss-Kämpfen
6. [ ] Zug-Timeout für Online-Echo-Duelle (60 s, danach Rasten)
7. [ ] Rückgängig-Knopf für die Befehlswahl im Mehrfachkampf, bevor der Zug startet
8. [ ] Aufgeben-Option in Wayfarer-Kämpfen mit Bestätigung (zählt als Niederlage, kein Geldverlust auf Story)
9. [ ] Wechsel nach einem K.o. des Gegners anbieten (Stufe Story und Wayfarer), auf Veteran abschaltbar
10. [ ] Gegner kündigt seinen nächsten Spirling an, wenn er wechselt (Ankündigungs-Option)
11. [ ] Doppelte Aktion eines Bosses klar als 'Nachhall' markieren
12. [ ] Rasten im Mehrfachkampf: Wahl 'Alle rasten' als Abkürzung
13. [ ] Schnellwahl 'Letzten Zug wiederholen' für Wildkämpfe
14. [ ] Zugvorschau: Fehlschlag-Chance bei Genauigkeit unter 100 % als Prozentwert
15. [ ] Kampfbeginn mit Initiative-Bonus, wenn der Spieler den Gegner von hinten anspricht
16. [ ] Überraschungsangriff wilder Spirlings im hohen Farn: erster Zug für den Gegner (selten)
17. [ ] Klare Regel: Gegenstände kosten den ganzen Zug des Spirlings, der sie benutzt
18. [ ] Rückzug aus Wildkämpfen bleibt ohne Kosten, wiederholte Versuche werden leichter (bestehend, dokumentieren)
19. [ ] Endzug-Reihenfolge festlegen und im Lexikon erklären: Status, Regeneration, Energie, Feld
20. [x] Kampfende-Zusammenfassung: Schaden, K.o.s, MVP-Spirling (BattleInfo.report_lines mit 'Star des Kampfes', BattleInfo.star_of)
21. [ ] Zug-Limit für Boss-Kämpfe (z. B. 30 Züge), danach Riss schließt sich erneut
22. [ ] Optionale 'Sanfte Niederlage' auf Story: Team erwacht mit halben HP am Kampfort
23. [ ] Seed des Kampfes im Log anzeigen (für Wiederholungen und Fehlerberichte)
24. [ ] Pause-Menü im Kampf mit Einstellungen, ohne den Kampf zu verlassen
25. [ ] Mehrfachziel-Techniken treffen Verbündete nie (bestehende Regel festschreiben)
26. [ ] Fehlende Aktionen eines Slots werden zu Rasten, nie zu Zufallszügen (bestehend, testen)
27. [ ] Gegner-Bank-Anzahl als Punkte am Rand (wie viele Spirlings noch kommen)
28. [ ] Spieler-Bank-Anzahl ebenfalls als Punkte
29. [ ] Kampfstart-Text kürzer bei 2x/4x Tempo
30. [ ] Zwischenspeichern vor Boss-Kämpfen automatisch
31. [ ] Kampf fortsetzen nach App-Neustart (Zustand pro Zug sichern)
32. [ ] Wechsel kostet keine Energie, aber der neue Spirling startet mit seiner gespeicherten Energie
33. [ ] Energie bleibt pro Spirling beim Wechsel erhalten (bestehend, sichtbar machen)
34. [ ] Zufallszahlen fair: gleicher Seed erzeugt denselben Kampf (bestehend, Regressionstest)
35. [ ] Keine versteckten Gummiband-Effekte: Gegner betrügt nie bei Würfen
36. [ ] Treffer-Glück der Gegner auf Story leicht senken (Krit-Chance halbiert)
37. [ ] Kampfregeln-Seite im Lexikon mit allen Zahlen
38. [ ] Turnierregel 'Gleiches Level': alle Spirlings auf Lv 50 skaliert
39. [ ] Turnierregel 'Ohne Gegenstände'
40. [ ] Turnierregel 'Nur ein Element pro Team'

## Energie und Overcharge

41. [ ] Energie-Vorschau: nach Wahl einer Technik zeigen, wie viel Energie danach bleibt
42. [ ] Rasten im Feld 'Hohe Flut' gibt +1 Energie extra (Feldbonus)
43. [ ] Energie-Kristall als gehaltener Gegenstand: Start mit +2 Energie
44. [ ] Techniken mit 0 Energiekosten, aber halber Stärke (Notfall-Techniken)
45. [ ] Overcharge-Techniken zeigen den aktuellen Multiplikator im Menü
46. [ ] Energie-Diebstahl-Techniken klarer kennzeichnen (Symbol)
47. [ ] Energie-Sperre-Status: eine Runde kein Energiegewinn
48. [ ] Trait 'Sparflamme': Techniken ab 5 Energie kosten 1 weniger
49. [ ] Trait 'Überladen': bei voller Energie +10 % Schaden
50. [ ] Maximale Energie pro Art leicht variieren (10 bis 12)
51. [ ] Energie-Leiste als Ziffer für Screenreader
52. [ ] Rasten heilt auf Story-Stufe zusätzlich 5 % HP
53. [ ] Gegner-Energie im Info-Streifen anzeigen (bestehend, Lexikon erwähnen)
54. [ ] Warden-Regel 'Ebbe': Spieler startet mit 1 Energie weniger
55. [ ] Warden-Regel 'Glutpuls' (bestehend) im Lexikon erklären
56. [ ] Technik 'Atemzug': +3 Energie, aber SPD -1
57. [ ] Energie-Übertragung an einen Verbündeten im Mehrfachkampf
58. [ ] Energie-Spiegel: Technik, die die Energie beider Seiten tauscht
59. [ ] Overcharge-Kette: zwei Overcharge-Techniken hintereinander geben Bonus
60. [ ] Overcharge-Sound steigt mit eingesetzter Energie
61. [ ] Energie-Kosten-Balance über den Balancing-Simulator prüfen
62. [ ] KI berücksichtigt Energie für den nächsten Zug (zwei Züge vorausplanen)
63. [ ] KI rastet gezielt, wenn eine starke Technik bald bezahlbar ist
64. [ ] Energie-Tutorial im ersten Wildkampf
65. [ ] Hinweis, wenn eine Technik nie bezahlbar ist (Energie-Max zu klein)
66. [ ] Gegenstand 'Funkentrank' gibt +3 Energie (prüfen, ob bestehend)
67. [ ] Energie-Regeneration bei Wechsel auf die Bank: +1 pro Runde auf der Bank
68. [ ] Energie-Startwert pro Schwierigkeit anpassen
69. [ ] Overcharge in Bosskämpfen begrenzen (max. +5)
70. [ ] Energie-Kosten im Lexikon jeder Technik
71. [ ] Energie-Symbol farbenblind-sicher mit Form statt Farbe
72. [ ] Energie-Pips größer im Einhand-Modus
73. [ ] Animation: Energie fließt beim Rasten sichtbar zurück
74. [ ] Energieverlust durch Status 'Soak' als Option prüfen
75. [ ] Feld 'Statischer Schleier' (neu): Volt-Techniken kosten 1 weniger
76. [ ] Energie-Statistik im Kampfende-Bericht
77. [ ] Techniken mit variabler Stärke nach verbrauchter Energie (bestehend: Overcharge) erweitern
78. [ ] Energie als Ziel für Gegenstand 'Ruhekerze'
79. [ ] Online-Duelle: gleiche Energie-Regeln, keine Ausnahmen
80. [ ] Energie-Werte in den Balancing-Bericht aufnehmen

## Elemente und Matchups

81. [ ] Matchup-Tabelle im Lexikon, die sich mit gesehenen Treffern füllt (bestehend: gelernte Matchups)
82. [x] Story-Stufe zeigt alle Matchups von Anfang an (bestehend) (bestehend: GameState.known_matchups, Story zeigt alle)
83. [ ] Matchup-Symbole mit Form statt Farbe (bestehend: Elementsymbole) auch im Lexikon
84. [ ] Doppel-Element-Erklärung: beide Faktoren multiplizieren, im Lexikon zeigen
85. [x] Element-Resonanz: zwei Verbündete mit gleichem Element erhalten +5 % Schaden (TechniqueRules.resonance_mult)
86. [x] Element-Wechsel-Technik: Ziel wird für 3 Runden zu einem anderen Element (Farbbad (Dye Bath), Spirling.element_shift)
87. [x] Element-Schutz-Gegenstand: halbiert einen sehr effektiven Treffer einmal (Schutzschale (Ward Shell), held super_guard)
88. [x] Element-Verstärker als gehaltene Gegenstände (+15 % für ein Element) (bestehend: Prismen +20 %, Amulette +10 % je Element)
89. [ ] Neutral-Techniken ohne Element für jeden Spirling
90. [ ] Matchup-Lernen auch durch Lexikon-Einträge (Lore-Seiten)
91. [ ] Elementsymbol am Ziel-Pin im Mehrfachkampf
92. [ ] Effektivitäts-Hinweis im Mehrfachkampf pro Ziel bei der Zielwahl
93. [x] Element-Balance-Bericht: welches Element gewinnt im Simulator zu oft (bestehend: tools/balance/type_sim.py chart_report)
94. [ ] Neue Feld-Elemente pro Riss variieren
95. [x] Element-Reaktion: Tide trifft Scorch-Ziel und löscht den Status
96. [x] Element-Reaktion: Volt trifft Soak-Ziel für +20 % Schaden
97. [x] Element-Reaktion: Ember auf Root-Ziel befreit es, verursacht aber Scorch (BattleRules.REACTIONS inflict)
98. [ ] Element-Reaktionen im Lexikon erklären
99. [ ] Matchup-Quiz als Minispiel im Leuchtturm
100. [x] Effektivitäts-Text in eigener Wortwahl (bestehend: 'overwhelming', 'barely landed') (bestehend: BattleEvent DAMAGE)
101. [x] Unwirksam-Treffer (x0) gibt es nicht, nur x0.25 (Designregel festhalten) (Regel in docs/BALANCE.md, test_kampf_techniques)
102. [ ] Element-Dominanz pro Region als Wild-Spawn-Tabelle
103. [x] Trait 'Prisma-Haut': nimmt bei x2 nur x1.5 (verborgene Gabe Prismenhaut (Cullet-Linie))
104. [x] Trait 'Gegenstrom': resistiert das Element, das es zuletzt getroffen hat (verborgene Gabe Gegenstrom (Paddlewisp-Linie))
105. [ ] Element-Statistik im Kampfende-Bericht
106. [x] Matchup-Kenntnis wird pro Spielstand gespeichert (bestehend) (bestehend: SaveManager matchups)
107. [ ] Online: Matchup-Wissen teilt sich mit Freunden (Laternenpost-Bonus)
108. [ ] Element-Icons im Hochkontrast-Modus größer
109. [x] Element-Namen bleiben in allen Sprachen gleich (bestehend) (bestehend: Elements.element_name ohne Übersetzung)
110. [x] Element-Tabelle bleibt eigenständig, nie aus anderen Spielen übernehmen (Regel) (Regel in docs/BALANCE.md)
111. [ ] Ein Element pro Riss als Thema der Warden
112. [ ] Element-Training: Spark-Werte steigen schneller im passenden Feld
113. [ ] Element-Glyphen animieren beim sehr effektiven Treffer
114. [ ] Element-Mischtechniken (zwei Elemente, nimmt das bessere)
115. [x] Element-Schild-Technik für das ganze Team (3 Runden) (Schutzkreis (Ward Circle))
116. [x] Elementarer Nachhall: Bonus, wenn zwei Verbündete im selben Zug dasselbe Element nutzen (TechniqueRules.echo_mult)
117. [ ] Element-Rätsel in der Welt, die Kampfwissen belohnen
118. [ ] Element-Filter im Lager
119. [ ] Element-Schwäche-Warnung beim Einwechseln
120. [x] Gegner-Element im Info-Streifen (bestehend) (bestehend: InfoStrip zeichnet Elementsymbole)

## Techniken

121. [x] Resonanz-Techniken: Ash Call, Tide Call und Murk Call legen 5 Runden lang ein Rift-Feld
122. [ ] Feld-Restzüge im Log ansagen und beim Ende melden
123. [x] Schutz-Technik 'Brace': hält einen Treffer ab, zweimal hintereinander schlägt fehl (Standhalten (Hold Fast))
124. [x] Technik mit Rückstoß, die das Ziel auf die Bank zwingt (nur Wayfarer-Kämpfe) (Wegschubser (Shove Off))
125. [ ] Mehrstufige Technik: lädt eine Runde, trifft dann doppelt
126. [x] Konter-Technik: wirft physischen Schaden x1.5 zurück (Grollrückgabe (Grudge Return))
127. [x] Heil-Technik für Verbündete im Mehrfachkampf (Sippenbalsam (Kindred Balm))
128. [x] Team-Stufen-Technik (alle Verbündeten DEF +1) (Reih und Glied (Rank and File))
129. [x] Wurzel-Technik, die Wechsel für 3 Runden blockiert (bestehend: Root) (bestehend: Root blocks_swap)
130. [ ] Technik, die Stufen des Ziels zurücksetzt
131. [x] Technik, die eigene negative Stufen löscht (Abschütteln (Shake Loose))
132. [x] Technik mit steigender Stärke bei Wiederholung (Trommelwirbel (Rolling Drum))
133. [x] Technik, die stärker ist, wenn das Ziel zuerst gehandelt hat (Späte Antwort (Late Reply))
134. [x] Technik, die stärker ist, wenn der Nutzer zuerst handelt (Eröffnungszug (Opening Gambit))
135. [x] Technik mit Treffer-Serie (2 bis 4 Treffer) (Kieselhagel (Pebble Hail))
136. [x] Technik, die das Feld beendet (Rissstille (Rift Hush))
137. [x] Technik, die Status vom ganzen Team heilt (bestehend: Effekt cure_team)
138. [ ] Technik-Lehrer im Leuchtturm (vergessene Techniken neu lernen)
139. [x] Echo-Kristalle (bestehend) als Quelle seltener Techniken ausbauen (19 neue Echo-Kristalle bei Hesper im Leuchtturm)
140. [ ] Technik-Tausch-Vorschau: alte und neue Technik nebeneinander
141. [x] Technik-Beschreibung mit Effekt-Chancen im Lexikon
142. [ ] Techniken mit Signatur pro Art (eine je Art, eigenständig)
143. [x] Keine Technik-Namen aus anderen Spielen (Prüfliste vor jedem Merge) (tools/ip_check.sh in CI, test_rule_checks)
144. [ ] Status-Techniken mit Genauigkeit unter 100 % sichtbar machen
145. [ ] Technik-Kategorie Physisch/Fokus/Status mit Symbol
146. [x] Mehrfachziel-Techniken zeigen 'alle' (bestehend) (bestehend: Info-Karte 'Reaches every foe.')
147. [x] Technik 'Ablenkung': zieht alle Einzelziele drei Runden auf sich (Lichtköder (Bright Lure))
148. [x] Technik 'Schulterschluss': schützt einen Verbündeten (Schulterschluss (Close Ranks))
149. [x] Technik 'Nachglut': Schaden über 3 Runden (Nachglut (Ember Afterglow))
150. [x] Technik 'Spiegelung': kopiert die letzte Gegner-Stufenänderung (Geliehene Haltung (Borrowed Stance))
151. [x] Technik 'Ruhepunkt': heilt 50 %, Nutzer schläft 1 Runde (Drowse) (Ruhepunkt (Still Point))
152. [x] Technik 'Druckwelle': trifft alle, auch Verbündete, sehr stark (Risiko-Technik) (Druckwelle (Ground Burst))
153. [x] Techniken mit Feld-Bedingung (stärker in passendem Feld) (bestehend: field_element-Techniken)
154. [ ] Techniken mit Tageszeit-Bedingung (Tag/Nacht bestehend)
155. [ ] Technik-Balancing über den Simulator pro neuer Technik
156. [ ] Lernlisten pro Art auf Lücken prüfen (jede Art hat eine Status-Technik)
157. [ ] Technik-Animationen pro Element eigenständig
158. [ ] Technik-Favoriten im Menü markieren
159. [ ] Technik-Reihenfolge im Menü umsortieren
160. [x] Technik-Info-Bildschirm per langem Druck

## Status-Zustände

161. [x] Ruhe-Regel: Drowse trifft keinen zweiten Spirling derselben Seite in Wayfarer-Kämpfen
162. [ ] Status-Symbole mit Form und Kürzel (bestehend: Kürzel), Symbole ergänzen
163. [ ] Status-Dauer als Zahl unter dem Kürzel
164. [x] Neuer Status 'Verwirrt' in eigener Form: Ziel wählt zufällig das Ziel im Mehrfachkampf (Status Muddle/Wirr, StatusRules)
165. [x] Neuer Status 'Erschöpft': halbe Energie-Regeneration (Status Spent, StatusRules.energy_gain)
166. [x] Neuer Status 'Markiert': nächster Treffer gegen das Ziel ist ein sicherer Treffer (Status Marked)
167. [x] Status-Immunität durch Feld (z. B. Hohe Flut verhindert Scorch)
168. [x] Status-Heil-Gegenstände pro Status und ein Allheiler (bestehend prüfen) (je Status ein Heilmittel + Remedy, test_move_content)
169. [ ] Status-Kombination: Soak + Jolt = länger gelähmt
170. [x] Status-Ticks bleiben bei 1/12 (fixe Originalitätszahl, nicht ändern) (test_kampf_status)
171. [x] Status-Erklärung im Lexikon mit Zahlen (Kampfhandbuch, BattleGuide.gd)
172. [ ] Status-Animation kurz und optional (Weniger Bewegung)
173. [x] Status trifft Bosse nur halb so lange (StatusRules.boss_turns)
174. [x] Status-Chance in der Technik-Info
175. [x] KI meidet Status gegen Ziele mit Status oder Immunität (umgesetzt in Meister-KI) (BattleAI Stufe 3)
176. [x] Status-Schutz-Technik für das Team (Technik Calm Veil)
177. [x] Status überträgt sich bei Kontakt (Trait 'Glimmhaut') (Gabe glimmer_skin, Forgefly-Linie)
178. [x] Status heilt beim Wechsel auf die Bank (Trait 'Ruhig') (Gabe unruffled, Prismist-Linie)
179. [ ] Status nach dem Kampf bleibt erhalten, außer auf Story
180. [x] Status-Heilung an Rastquellen (bestehend) (GameState.heal_party, Spirling.restore)
181. [ ] Status-Statistik im Kampfende-Bericht
182. [ ] Status-Sound pro Status eigenständig
183. [x] Status-Text in eigener Wortwahl (Liste gegen übernommene Phrasen, bestehend) (tools/ip_check.sh)
184. [x] Daze-Chance 1/3 überprüfen und dokumentieren (Daze x0.7 Treffer, im Kampfhandbuch)
185. [x] Jolt 20 % bleibt fix (Originalitätszahl) (test_kampf_status)
186. [x] Drowse 2 Runden bleibt fix (Originalitätszahl) (test_kampf_status)
187. [ ] Status 'Root' zeigt Kette am Sprite
188. [ ] Status 'Soak' tropft sichtbar
189. [ ] Status 'Scorch' glimmt sichtbar
190. [ ] Status im Info-Streifen bei Hochkontrast fett
191. [x] Status gegen wilde Schwärme gilt pro Spirling (test_kampf_status)
192. [x] Status-Reflexion als seltener gehaltener Gegenstand (Mirror Scale)
193. [x] Warden-Regel 'Stille Luft': kein Status für beide Seiten (Regel hushed_air 'Hushed Air', die Stufen-Regel still_air ist eine andere)
194. [ ] Status-Chance in der Schadensvorschau ergänzen
195. [x] Status-Fehlschlag-Grund im Log (Immunität, Regel, schon betroffen) (BattleEvent STATUS_FAILED)
196. [x] Status-Wirkung auf Bond-Chance im Lexikon erklären (Kampfhandbuch)
197. [x] Status-Kombos in der Meister-KI nutzen (BattleAI Stufe 3 zählt Reaktionen)
198. [x] Status-Clause für Online-Duelle (wie Ruhe-Regel) (Online-Duelle sind keine Wildkämpfe, BattleReferee.from_expect)
199. [x] Status-Dauer pro Schwierigkeit gleich halten (Fairness) (test_kampf_status)
200. [x] Status-Tutorial beim ersten Status (BattleGuide.first_status_tip)

## Werte-Stufen und Werte

201. [x] Stufen-Pfeile im Info-Streifen (bestehend) (InfoStrip)
202. [x] Stufen-Grenze ±3 bleibt (eigene Zahl) (test_kampf_werte)
203. [x] Stufen-Tooltip mit Multiplikator (InfoStrip.screen_reader_text, Kampfhandbuch)
204. [x] Stufen nach Wechsel zurücksetzen (Regel prüfen und festschreiben) (Regel: Stufen bleiben am Spirling bis Kampfende, test_kampf_werte)
205. [x] Stufen-Kopier-Technik (Mirror Stance)
206. [x] Stufen-Tausch-Technik (Crosswind Trade)
207. [x] KI baut Stufen nur auf, wenn sie sicher ist (umgesetzt in Meister-KI) (BattleAI Stufe 3)
208. [x] Stufen-Warnung, wenn ein Gegner +2 ATK hat (STAT_CHANGED warn)
209. [ ] Spark-Werte (bestehend) im Statusbildschirm als Balken
210. [ ] Spark-Training durch Kämpfe gegen bestimmte Arten
211. [x] Spark-Reset-Gegenstand (Spark Flux, GameState.reroll_sparks)
212. [x] Temperament (bestehend) im Kampf-Info zeigen (Wechsel-Liste, BattleGuide.compare_line)
213. [x] Werte-Rechner im Lexikon (Lv, Spark, Temperament) (Kampfhandbuch Werte, BattleGuide.calc)
214. [x] Werte-Vergleich beim Einwechseln (BattleGuide.compare_line)
215. [ ] Werte-Ansicht der Gegner nach dem Kampf im Lexikon
216. [x] Krit-Chance 1/12 und x1.4 fix (Originalitätszahl) (test_kampf_werte)
217. [x] Krit-Stufen durch gehaltene Gegenstände (bestehend: crit_mult) (Whetstone keen_lens)
218. [x] Genauigkeits-Stufen als eigene Werte prüfen (vielleicht nicht nötig) (bewusst nicht, BattleRules.STAGE_STATS)
219. [x] Ausweich-Werte bewusst nicht einführen (Frust vermeiden) (test_kampf_werte)
220. [x] SPD-Gleichstand-Regel im Lexikon (Kampfhandbuch)
221. [x] Werte-Grenzen im Datenprüfer (validate_data) festhalten (DataValidator._check_values)
222. [x] Basiswert-Summen pro Entwicklungsstufe prüfen (DataValidator._check_values)
223. [x] Werte-Balance über den Simulator (type_sim.py --strict)
224. [ ] Stufen visuell auch am Sprite (kleine Aura)
225. [x] Stufen-Text in eigener Wortwahl (bestehend) (BattleEvent)
226. [x] Stufen auf Bosse wirken halb (Stufen-Senkungen halbiert, BossRules.stage_delta)
227. [x] Phasen-Bosse erhalten Stufen beim Phasenwechsel (umgesetzt) (BattleRules.BOSSES phase)
228. [x] Warden-Regel mit Startstufen (bestehend: Undertow) (BattleRules.RULES)
229. [x] Stufen-Sound steigt mit Stufe (BattleAudio.stage_pitch)
230. [ ] Werte-Ansicht als Radar-Grafik im Statusbildschirm
231. [x] Werte pro Level im Lexikon als Kurve (Kampfhandbuch Werte, BattleGuide.curve)
232. [x] Level-Cap im Menü (bestehend) (PauseMenu Ring limit)
233. [x] Level-Cap-Hinweis beim XP-Verlust (XP_GAINED cap)
234. [x] Werte beim Levelaufstieg anzeigen (Zuwachs) (LevelPanel)
235. [ ] Werte-Export für Fans (Teamcode)
236. [x] Werte-Vorschau bei Entwicklung (BattleGuide.unfold_preview)
237. [x] Gleiche Werte-Formel für Spieler und Gegner (Fairness) (test_kampf_werte)
238. [ ] Werte-Skalierung im Turnier 'Gleiches Level'
239. [x] Werte-Prüfung im Balancing-Test (keine Art dominiert) (type_sim.py --strict)
240. [x] Werte-Formel bleibt eigenständig (Regel) (Spirling.gd, DamageCalc.gd)

## Traits

241. [ ] Trait im Info-Streifen nach der ersten Auslösung zeigen
242. [x] Trait-Auslösung als kurze Meldung im Log
243. [x] Zweiter Trait für entwickelte Spirlings (wählbar) (Bonus-Gabe neben der eigenen, im Team-Menü wählbar (TraitKit.bonus_options, PauseMenu 'Bonus gift'))
244. [x] Versteckter Trait selten bei Prisma-Spirlings (jeder vierte Prisma-Spirling trägt 'Prism Skin' (TraitKit.prism_trait_id))
245. [x] Trait-Lexikon mit allen Traits (Gabenbuch im Rekorde-Menü (TraitKit.all_gift_lines))
246. [x] Trait 'Sparflamme' (Energie) ('Spare Flame' (data/kampf_kit.json))
247. [x] Trait 'Prisma-Haut' (Effektivität) ('Prism Skin')
248. [x] Trait 'Gegenstrom' (Resistenz) ('Counter Current')
249. [x] Trait 'Ruhig' (Status-Heilung beim Wechsel) ('Quiet Heart')
250. [x] Trait 'Glimmhaut' (Kontakt-Scorch) ('Glow Hide')
251. [x] Trait 'Schwarmgeist': stärker im Mehrfachkampf ('Pack Sense')
252. [x] Trait 'Einzelgänger': stärker im 1v1 ('Loner')
253. [x] Trait 'Wachposten': erster Zug immer zuerst ('Sentinel')
254. [x] Trait 'Feldläufer': doppelte Feld-Boni ('Field Runner')
255. [x] Trait 'Echo-Seele': Resonanz-Felder halten 2 Runden länger ('Lingering Echo')
256. [x] Trait 'Dickes Fell' (bestehend Thick Hide) im Lexikon (im Gabenbuch)
257. [x] Trait 'Wurzeln' (bestehend Deep Roots) (im Gabenbuch)
258. [x] Trait 'Last Stand' (bestehend) sichtbar machen, wenn aktiv (bestehend: BattleModel zeigt den Trait beim ersten Wirken unter 1/3 HP)
259. [x] Trait-Balance-Bericht (tools/balance/trait_report.py)
260. [ ] Trait-Wechsel-Gegenstand
261. [ ] KI kennt Traits der Gegner nur, wenn sie aufgedeckt wurden (Fairness)
262. [x] Meister-KI meidet Status gegen immune Traits (umgesetzt) (bestehend: BattleAI meidet Status gegen immune Gaben (Stufe 3))
263. [ ] Trait-Icons klein neben dem Namen
264. [x] Trait-Texte übersetzt (bestehend) (bestehend, neue Gaben in tools/i18n/de_kampf_traits.py)
265. [x] Traits in Online-Duellen gleich (Gaben liegen im BattleModel und im Spielstand (bonus_trait), Online-Duelle nutzen dasselbe Modell)
266. [x] Trait-Namen eigenständig prüfen (Test: keine Namensdopplung (test_trait_kit.gd), ip_check)
267. [x] Traits für Bosse (eigene Boss-Traits) (data/kampf_kit.json boss_traits)
268. [x] Trait 'Hush-Kern' für Riss-Bosse: Status halb so lang ('Hush Core' für alle Riss-Bosse)
269. [x] Trait 'Laternenlicht': Verbündete erhalten +1 FOC beim Einwechseln ('Lantern Light')
270. [x] Trait 'Kälteschlaf': Drowse heilt HP ('Cold Sleep')
271. [x] Trait 'Stoßdämpfer': kein Rückstoß ('Shock Pad')
272. [x] Trait 'Glückspilz': Krit-Chance leicht höher ('Lucky Cap')
273. [x] Trait 'Wendig': Wechsel ist frei (Prioritätsaktion, bestehend) ('Nimble')
274. [x] Trait-Freischaltung durch Bond-Stufe (Bonus-Gabe erst ab Verbundenheit (min_kinship))
275. [ ] Traits im Spirlog bei 'bonded'
276. [x] Trait-Auswirkung im Schadensvorschau-Wert berücksichtigen (bestehend über damage_mult) (TraitKit.static_mult fließt in BattleRules.damage_mult)
277. [x] Trait-Tests pro Trait (tests/unit/test_trait_kit.gd)
278. [x] Trait-Kombinationen mit gehaltenen Gegenständen prüfen (Test: Echo Soul + Lantern Glass, Field Runner + Glutstein)
279. [ ] Trait 'Sturmlaterne' für den Storm-Lantern-Träger
280. [ ] Trait-Zähler im Kampfende-Bericht

## Gehaltene Gegenstände

281. [ ] Gehaltene Gegenstände (bestehend) im Info-Streifen als Symbol
282. [x] Element-Verstärker pro Element (bestehend: Prismen und Charms pro Element)
283. [x] Energie-Kristall (+2 Start-Energie) ('Energy Crystal': +2 Energie-Maximum und Start)
284. [x] Schutz-Talisman (einmal sehr effektiven Treffer halbieren) ('Ward Talisman')
285. [x] Fokus-Band in eigener Form: übersteht einen K.o.-Treffer bei vollen HP einmal (bestehend: Hold Stone)
286. [x] Heilbeere-Ersatz in eigener Form: 'Moospolster' heilt 25 % unter 1/3 HP (bestehend: Mending Pith)
287. [x] Status-Beere-Ersatz: 'Klarstein' heilt einen Status einmal (bestehend: Clearing Pith)
288. [x] Tempo-Feder: SPD +1 beim Einwechseln ('Pace Feather')
289. [x] Wahl-Gegenstände bewusst nicht übernehmen (eigene Ideen stattdessen) (keine Wahl-Sperre in data/kampf_kit.json, nur eigene Effekte)
290. [x] Gegenstand 'Laternenglas': Feld-Dauer +2 ('Lantern Glass')
291. [x] Gegenstand 'Riss-Splitter': Overcharge +0.05 pro Energie ('Rift Splinter')
292. [x] Gegenstand 'Wanderschuh': Wechsel ist frei ('Wander Boot')
293. [ ] Gegenstände in Turnier-Regeln einzeln sperrbar
294. [x] Gegner-Wayfarer tragen auf Veteran Gegenstände (bestehend: TrainerData.keeps_keepsakes ab Veteran)
295. [x] Gegenstand-Info im Lexikon (Andenkenbuch im Rekorde-Menü (TraitKit.all_keepsake_lines))
296. [ ] Gegenstand-Verbrauch in Kampfende-Bericht
297. [ ] Gegenstand nach dem Kampf automatisch wieder ausrüsten (Option)
298. [ ] Gegenstand-Tausch im Kampf (kostet den Zug)
299. [x] Gegenstand-Klau-Technik bewusst nicht einführen (Frust) (bewusst kein Klau-Effekt)
300. [x] Gegenstand-Shop im Endgame (Marlas Stand (endgame.json exchange, Stufe full))
301. [x] Gegenstand als Belohnung im Turm (oberste Turmetage gibt ein Andenken (TraitKit.tower_reward))
302. [x] Gegenstand-Seltenheit sichtbar (Seltenheit im Andenken-Hinweis (items.json rarity))
303. [ ] Gegenstand-Balance im Simulator
304. [ ] Gegenstand-Icons eigenständig (Asset-Log)
305. [x] Gegenstand-Namen eigenständig prüfen (Test: keine Namensdopplung)
306. [x] Gehaltene Gegenstände in Online-Duellen gleich (gleiches Modell und Spielstand)
307. [ ] Gegenstand-Sets pro Spirling speichern
308. [x] Gegenstand 'Echo-Muschel': Bond-Chance +5 % beim Halter ('Calling Conch')
309. [x] Gegenstand 'Ruhekerze': +1 Energie beim Rasten ('Rest Candle')
310. [x] Gegenstand 'Glutstein' für Ember-Felder ('Cinder Stone')
311. [x] Gegenstand 'Gezeitenstein' für Tide-Felder ('Tide Stone')
312. [x] Gegenstand 'Dämmerstein' für Umbra-Felder ('Murk Stone')
313. [x] Gegenstand-Effekte im Schadensvorschau-Wert (über BattleRules.damage_mult)
314. [x] Gegenstand-Hinweis beim Ausrüsten (was es tut) (bestehend: Hinweis im Andenken-Menü)
315. [ ] Gegenstand-Limit: jeder Gegenstand nur einmal pro Team in Turnieren
316. [x] Gegenstand-Fund in versteckten Orten (bestehend) (bestehend: Spark Coil im Versteck von Murk Hollow)
317. [x] Gegenstand-Tests pro Gegenstand (tests/unit/test_trait_kit.gd)
318. [ ] Gegenstand-Animation beim Auslösen
319. [ ] Gegenstand-Sound beim Auslösen
320. [x] Gegenstand-Texte übersetzt (tools/i18n/de_kampf_traits.py)

## Rift-Felder und Umgebung

321. [x] Felder per Technik für 5 Runden, danach kehrt das Feld des Ortes zurück
322. [x] Feld-Anzeige mit Restrunden am oberen Rand (FieldBadge: Symbol, Name, Restrunden)
323. [x] Neues Feld 'Statischer Schleier' (Volt)
324. [x] Neues Feld 'Blütenstaub' (Bloom)
325. [x] Neues Feld 'Morgenschein' (Lumen)
326. [x] Neues Feld 'Steinregen' (Stone) (Geröllregen/Rubble Rain, Rubble Call)
327. [x] Neues Feld 'Sturmauge' (Gale) (Gale Eye, Gale Call)
328. [x] Feld beeinflusst Status (Hohe Flut löscht Scorch)
329. [x] Feld beeinflusst Energie (Statischer Schleier) (Volt-Spirlings +1 Energie pro Runde)
330. [x] Feld beeinflusst Heilung (Blütenstaub heilt 1/16)
331. [x] Feld-Hintergrund färbt sich (Backdrop-Tönung) (data/rift_fields.json tint)
332. [x] Feld-Musik-Variation (Tonhöhe pro Feld, Sound.music_pitch)
333. [x] Feld-Tageszeit-Kombination (Morgenschein am Tag, Tiefes Dunkel nachts +1 Runde)
334. [x] Feld-Wechsel-Animation (ElementFx-Welle, Badge blinkt)
335. [x] Feld im Kampfende-Bericht (BattleReport: Riss-Felder im Kampflog)
336. [x] Feld-Lexikon (Lexikon-Eintrag pro Feld beim ersten Betreten)
337. [x] Meister-KI nutzt Felder, die ihr nützen (umgesetzt) (BattleAI set_field)
338. [x] Feld-Gegenstände verlängern Dauer (Andenken Feldpflock, +2 Runden)
339. [x] Trait 'Feldläufer' und 'Echo-Seele' (Grindlet- und Vanepip-Linie)
340. [ ] Feld in Online-Duellen wählbar
341. [x] Feld als Wochen-Herausforderung (bestehend) (WeeklyChallenge.field)
342. [x] Feld-Beschreibung in eigener Wortwahl (BattleRules.FIELDS intro, Lexikon)
343. [x] Feld-Boost 1.2 und Schwächung 0.85 (bestehend) dokumentieren (Lexikon 'Riss-Felder', Test prüft die Zahlen)
344. [x] Feld-Konflikt: neues Feld ersetzt altes, Ansage im Log
345. [x] Feld-Ende-Meldung (umgesetzt)
346. [x] Feld-Statistik im Simulator (BalanceSim run_fields, balance_sim fields)
347. [x] Feld-abhängige Wild-Spawns (Element des Ortsfelds häufiger)
348. [x] Feld-Rätsel im Riss (Prüfungen in data/puzzles.json mit Feld)
349. [x] Feld-Effekt auf Bond-Chance (z. B. Lichtflut +5 %) (Morgenschein +5 %)
350. [x] Feld-Symbol für Screenreader
351. [x] Feld bei 'Weniger Bewegung' ohne Partikel (ElementFx ohne Welle, Badge ohne Blinken)
352. [x] Feld-Wechsel durch Wetter in der Welt (optional, später) (data/weather.json, WeatherCycle)
353. [x] Feld-Unterschiede pro Ära-Grafik (Tönung pro Ära, Ära I eine Tinte)
354. [x] Feld-Regel im Turm zufällig pro Stockwerk (RiftFields.tower_field)
355. [x] Feld im Replay gespeichert (bestehend über Seed prüfen) (BattleReplay field, Test)
356. [x] Feld-Tests pro Feld
357. [x] Feld-Dauer pro Schwierigkeit gleich (Test)
358. [x] Feld-Kombination aus Ort und Technik (Technik gewinnt) (Test)
359. [x] Feld-Wirkung im Schadensvorschau-Wert (bestehend über damage_mult) (CommandMenu.damage_pct)
360. [x] Feld-Namen eigenständig prüfen (tools/ip_check.sh)

## Mehrfachkämpfe

361. [x] Mehrfachkämpfe bis 4v4 (bestehend) (BattleRules.MAX_FRONT)
362. [x] Ziel-Pin mit Element-Hinweis (Zielzeile mit x2/x.5 beim Zielen)
363. [x] Schadensvorschau pro Ziel bei der Zielwahl (~% pro Ziel, abschaltbar wie die Vorschau)
364. [x] Fokus-Feuer-Logik der Meister-KI (umgesetzt: KO-Bonus pro Ziel) (BattleAI FOCUS_BONUS)
365. [x] Verbündeten-Heilung (Sippenbalsam/Kindred Balm)
366. [x] Positionstausch zwischen eigenen Slots (Swap auf einen Verbündeten im anderen Slot: MultiRules.shift)
367. [x] Vorderreihe/Hinterreihe mit Schadensmodifikator (ab 3 Plätzen: hintere Reihe x0.9 bei physischen Einzeltreffern)
368. [x] Schwarm-Kämpfe (bestehend) mit Schwarm-Anführer (höchster Ring führt, +1 Wucht; fällt er, -1 Tempo für den Rest)
369. [x] Tag-Kampf mit Kestra (bestehend) mit gemeinsamer Kombi-Technik (Kombo gilt auch mit Partnern)
370. [x] Kombi-Techniken bei passenden Elementen zweier Verbündeter (data/multi_rules.json combos, x1.25)
371. [x] Mehrfachkampf-Tutorial (Tipp beim ersten Mehrfachkampf, im Leitfaden)
372. [x] Mehrfachkampf-Geschwindigkeit: Text pro Aktion kürzer (MultiRules.text_speed: Text tippt x1.4 schneller)
373. [x] Mehrfachkampf-Log filtern (Tippen: Alle, Deine, Gegner)
374. [x] Mehrfachkampf im Turm (jedes 5. Stockwerk 2v2)
375. [ ] Mehrfachkampf online (2v2 mit Freund-Echo)
376. [x] Ungleiche Kämpfe 3v1, 4v2 (bestehend)
377. [x] Boss-Kämpfe mit Wächtern (bestehend) (BattleRules.BOSSES)
378. [x] Mehrfachziel-Techniken mit 0.75 Schaden (bestehend) (SPREAD_MULT)
379. [x] Ablenkungs-Technik (Locktanz/Lure Dance)
380. [x] Schutz eines Verbündeten (Wellenbrecher/Breakwater Stand)
381. [x] Team-Schild (Schalenring/Shell Ring, 3 Runden x0.75)
382. [x] Team-Heilung (Heilchor/Mending Chorus)
383. [x] Mehrfachkampf-Balancing im Simulator (MultiSim: 2v2-Spiegel mit Hilfstechnik, Band 30-70 %, KI wartet mit Köder und Schutz)
384. [x] Mehrfachkampf-Layout für 4 Sprites (bestehend)
385. [x] Mehrfachkampf: Ziel-Wahl merken
386. [ ] Mehrfachkampf: 'Auto-Ziel' Option
387. [x] Mehrfachkampf: KI der Partner verbessern (Meister-KI auch für Partner auf Veteran)
388. [x] Mehrfachkampf: Warnung bei Treffer auf Verbündete (nicht nötig: Flächen-Techniken treffen nie Verbündete, Test)
389. [ ] Mehrfachkampf: Reihenfolge-Leiste
390. [x] Mehrfachkampf: XP-Verteilung klar anzeigen (bestehend: Wachstum-Zeile pro Spirling)
391. [x] Mehrfachkampf: Bond nur gegen Wild (bestehend)
392. [x] Mehrfachkampf: Rückzug nur wenn alle wild (Test)
393. [x] Mehrfachkampf: Kampfende-Bericht pro Spirling (BattleReport: Schaden und K.o. je Spirling, Bester des Kampfes)
394. [x] Mehrfachkampf: Replay (BattleReplay mit front und Zügen, test_multi_battle)
395. [x] Mehrfachkampf: Barrierefreiheit (Slot-Namen vorlesen) (MultiRules.slot_spoken)
396. [ ] Mehrfachkampf: Einhand-Modus
397. [x] Mehrfachkampf-Tests (bestehend) erweitern (test_multi_k05.gd)
398. [x] Mehrfachkampf: Story-Kämpfe mit Ali-Wunsch (3v3, 4v1, 4v2) beibehalten (test_multi_battle Kartendaten)
399. [x] Mehrfachkampf: Gegner-Formationen pro Wayfarer (Wayfarer-Eintrag "formation": true)
400. [x] Mehrfachkampf: Formation-Bonus (z. B. zwei Stone vorne +DEF) (data/multi_rules.json, nur eigene Seite)

## Bosse und Wardens

401. [x] Boss-Phasen: bei der Hälfte der HP erwacht der Boss, Stufen steigen, neue Ansage
402. [x] Mehrere Phasen pro Boss (z. B. 66 % und 33 %) (erledigt: dritte Phase bei 25 %, BossRules.LATE_PHASES)
403. [x] Boss-Phase wechselt das Feld (erledigt: BattleRules.BOSSES[id].phase.field)
404. [ ] Boss-Phase ruft einen Wächter
405. [ ] Boss-HP-Leiste mit Phasen-Markierungen
406. [ ] Boss-Musik wechselt mit der Phase
407. [x] Boss-Aktionen pro Zug (bestehend) sichtbar (erledigt: Boss-Ansage nennt 'It acts %d times each turn.')
408. [x] Boss-Schwächen als Rätsel (z. B. Feld nutzen) (erledigt: Halte-Feld pro Boss, BossRules.HOLD_FIELD, Hinweis auf der Lexikon-Seite)
409. [x] Warden-Regeln (bestehend) erweitern: 'Stille Luft', 'Ebbe' (erledigt: Regeln still_air und ebb in BattleRules.RULES)
410. [x] Warden-Kämpfe auf Veteran mit gehaltenen Gegenständen (bestand: teams_by_difficulty mit held, Plan 5000 Punkte 670, 673)
411. [x] Warden-Rückkämpfe mit höherem Level (bestehend: Rematches) (bestand: second_trial und data/warden_rematch.json)
412. [x] Warden-Texte nach dem Kampf (bestand: npc-Schlüssel defeat, z. B. cinder_rift/orrin_defeat)
413. [x] Boss-Lexikon (erledigt: Lexikon-Seiten boss_*, BossRules.LEXICON)
414. [x] Boss-Statistik (Züge, Schaden) (erledigt: records.boss_stats (Siege, beste und letzte Rundenzahl), BossRules.note_win)
415. [ ] Boss-Belohnungen pro Schwierigkeit
416. [ ] Boss-Kampf-Speicherpunkt
417. [ ] Boss-Wiederholung im Endgame
418. [ ] Boss-Rush-Modus
419. [ ] Boss im Online-Weltziel (bestehend) mit Phasen
420. [x] Boss-KI immer mindestens Stufe 2 (erledigt: TrainerData.BOSS_MIN_AI)
421. [x] Boss-Status-Dauer halbiert (erledigt: BossRules.status_turns)
422. [x] Boss-Stufen halbiert (erledigt: Stufen-Senkungen am Boss halbiert, BossRules.stage_delta)
423. [ ] Boss-Animation größer
424. [ ] Boss-Intro kurz bei 4x
425. [x] Boss-Phasen-Test (umgesetzt) (bestand: test_difficulty_bosses.gd, test_kampf_boss_ai.gd)
426. [x] Boss-HP-Skalierung nach Team-Größe (bestehend) (bestand: BattleRules.boss_hp_mult)
427. [x] Boss-Namen eigenständig (bestand: Ashen, Drowned, Mist Heart, tools/ip_check.sh)
428. [x] Boss-Design ohne Ähnlichkeit zu bekannten Legenden (bestand: Hush-Herzen aus eigener Welt, tools/ip_check.sh)
429. [x] Boss-Phasen-Text in eigener Wortwahl (bestand und neue Phasen-Texte in eigener Wortwahl)
430. [x] Boss: Spieler kann Phase durch Feld-Technik verzögern (erledigt: BossRules.HOLD_FIELD)
431. [x] Boss: Schwachpunkt-Runde nach Phasenwechsel (DEF -1) (erledigt: BossRules.WEAK_STAGE für eine Runde)
432. [x] Boss: Wut-Zähler bei zu langer Kampfdauer (erledigt: ab Runde 15 alle 5 Runden Wucht und Fokus +1)
433. [x] Boss: Gnade auf Story (eine Aktion weniger) (bestand: BattleRules.BOSS_ACTION_CAP Story 1)
434. [ ] Boss: Prisma-Variante im Endgame
435. [ ] Boss: Online-Rangliste nach Zügen
436. [ ] Boss: Wochen-Boss
437. [ ] Boss: Saison-Boss zu Festen (bestehend: Feste)
438. [x] Boss: Nach dem Sieg Lore-Seite (erledigt: Lexikon-Seite nach dem ersten Sieg (Overworld.after_tamer_win))
439. [ ] Boss: Achievement pro Boss
440. [ ] Boss: Replay speichern

## Gegner-KI

441. [x] Meister-KI (Stufe 3) für Rift-Born: kein Status gegen immune oder schon betroffene Ziele
442. [x] Meister-KI baut Stufen nur auf, wenn der Gegner sie nicht hart bestraft
443. [x] Meister-KI nutzt Resonanz-Felder, die ihren eigenen Techniken helfen
444. [x] Meister-KI bevorzugt sichere K.o.s und schwache Ziele im Mehrfachkampf
445. [ ] KI plant Energie zwei Züge voraus
446. [x] KI wechselt bei schlechter Stufe (z. B. -2 ATK) (erledigt: BattleAI.BAD_STAGE)
447. [ ] KI sagt Wechsel des Spielers vorher (nur Meister)
448. [x] KI nutzt Heil-Techniken gezielt (bestand: heal_self und mend unter heal_below)
449. [x] KI schont Spirlings mit wenig HP für später (erledigt: BattleAI.SPARE_HP bei der Ersatzwahl)
450. [x] KI-Persönlichkeiten pro Wayfarer (vorsichtig, wild, taktisch) (bestand: data/ai_profiles.json)
451. [ ] KI-Debug-Ansicht für Entwickler
452. [x] KI-Tests pro Verhalten (bestand: test_ai*.gd, neu test_kampf_boss_ai.gd)
453. [ ] KI liest nur, was der Spieler auch sieht (keine versteckten Werte)
454. [x] KI-Zufall in Stufe 0 bleibt (Wildkämpfe) (bestand: Plan 5000 Punkt 625)
455. [x] KI-Stufe pro Wayfarer übersteuerbar (bestehend) (bestand: npc-Schlüssel ai)
456. [x] KI für Partner (Kestra) auf Veteran Stufe 2 (erledigt: TrainerData.partner_ai)
457. [x] KI für Auto-Kampf (bestehend) auf Stufe 1 (bestand: BattleScene._auto_ai)
458. [x] KI-Ausrede vermeiden: nie unmögliche Aktionen (erledigt: Fuzz-Test aller Stufen)
459. [x] KI-Gegenstand-Nutzung begrenzen (max. 2 pro Kampf) (erledigt: BattleAI.ITEM_LIMIT)
460. [x] KI nutzt Overcharge, wenn es zum K.o. reicht (erledigt: BattleAI.score_move)
461. [x] KI vermeidet Rückstoß-Techniken bei wenig HP (erledigt: BattleAI.RECOIL_W unter 35 %)
462. [ ] KI im Boss-Kampf mit Phasen-Logik
463. [x] KI im Schwarm koordiniert (verschiedene Ziele) (erledigt: sichere K.o.-Ziele werden pro Runde vergeben)
464. [x] KI-Balance: Gewinnrate im Simulator pro Stufe messen (bestand: BalanceSim Modus ladder)
465. [x] KI-Gewinnrate-Ziel pro Schwierigkeit dokumentieren (bestand: tools/balance/targets.json, BalanceDoc)
466. [ ] KI-Laufzeit unter 5 ms pro Entscheidung (Handy)
467. [ ] KI-Entscheidungen im Replay nachvollziehbar
468. [x] KI-Texte: Wayfarer kommentiert gute Züge (bestand: data/dialogue/battle_lines.json)
469. [x] KI meidet Felder, die dem Spieler helfen (bestand: BattleAI.field_value)
470. [ ] KI erkennt eigene Feldschwäche und wechselt
471. [x] KI-Lernen bewusst nicht (deterministisch bleiben) (erledigt: Test gleicher Seed, gleiche Wahl)
472. [ ] KI-Stufen im Lexikon erklären
473. [x] KI-Stufe im Wochen-Echo (bestehend 2) auf 3 heben
474. [x] KI in Online-Echos nutzt das gespeicherte Team (bestand: EchoTeam.build)
475. [x] KI-Fairness-Test: gleiche Regeln wie der Spieler (erledigt: KI wählt nur aus legal_actions, Fuzz-Test prüft is_legal)
476. [ ] KI-Schadensschätzung nutzt dieselbe Formel wie die Vorschau
477. [ ] KI-Tie-Breaker deterministisch über den Kampf-Seed
478. [x] KI: Zielwahl bei gleicher Wertung nach niedrigsten HP (erledigt: BattleAI._choose)
479. [x] KI: Nie zwei Spirlings auf dasselbe sichere K.o.-Ziel (Overkill vermeiden) (erledigt: BattleAI._claims)
480. [x] KI: Wechsel-Strafe bei Root beachten (bestand: legal_actions ohne Wechsel bei Root, Test)

## Schwierigkeit und Herausforderungen

481. [x] Vier Stufen Story, Wayfarer, Veteran, Rift-Born (bestehend) (bestehend: GameState.Difficulty, MenuHost.DIFFICULTY_TEXT)
482. [x] Rift-Born nutzt die neue Meister-KI
483. [x] Level-Caps ab Veteran (bestehend) (bestehend: GameState.LEVEL_CAPS, has_ring_limit)
484. [x] Gegenstände in Kämpfen auf Rift-Born gesperrt (bestehend) (bestehend: GameState.items_allowed_in_battle)
485. [x] Iron Oath (bestehend) als Herausforderungsmodus (bestehend: GameState.iron_oath, MenuHost._iron_oath)
486. [x] Herausforderung 'Ein Spirling pro Gebiet' (ChallengeRules one_per_place)
487. [x] Herausforderung 'Nur Wild-Bonds aus erstem Kampf' (ChallengeRules first_meeting)
488. [x] Herausforderung 'Keine Heilung außer Rastquellen' (ChallengeRules spring_water, Kampf und Tasche)
489. [x] Herausforderung 'Monotyp' (ein Element) (ChallengeRules one_element, jetzt bei Bindungen aktiv)
490. [x] Herausforderung 'Zufällige Spawns' (Zufallsmodus mit Seed) (ChallengeRules wild_shuffle mit Lauf-Seed)
491. [x] Herausforderung 'Zufällige Techniken' (ChallengeRules art_shuffle)
492. [x] Herausforderungen kombinierbar beim neuen Spiel (TitleScreen fragt beim neuen Spiel, ChallengeMenu)
493. [x] Herausforderungs-Abzeichen auf der Wayfarer-Karte (online) (Online.card_numbers schickt die Zahl aktiver Regeln, profile_set behaelt 1 bis 20, FriendsMenu zeigt 'Challenge rules: N'; Migration 20261113207070_climb_boards.sql)
494. [x] Schwierigkeit jederzeit senkbar, nie anhebbar (Fairness für Ranglisten) (ChallengeRules.ranked_difficulty, Lauf-Chronik)
495. [x] Schwierigkeit pro Kampf anzeigen (Kampfstart-Zeile challenge_line)
496. [x] Gegner-Level-Skalierung optional (Option Gegner-Anpassung, ChallengeRules.scale_foes)
497. [x] Story-Stufe: mehr XP, weniger Krit des Gegners (ChallengeRules.FOE_CRIT und GROWTH)
498. [x] Wayfarer-Stufe: Standard (bestehend: Wayfarer-Werte in GameState und DifficultyTable)
499. [x] Veteran: Gegner mit Gegenständen (bestehend: TrainerData.keeps_keepsakes)
500. [x] Rift-Born: Gegner mit voller Technik-Auswahl (ChallengeRules.fill_arts)
501. [x] Gegner-Teams pro Stufe in data/npcs.json (bestehend: teams_by_difficulty in den Wayfarer-Daten der Karten, TrainerData.team_entries)
502. [x] Level-Cap-Werte dokumentieren (Lexikon-Eintrag ring_caps, DifficultyTable)
503. [x] Level-Cap-Hinweis bei Rastquellen (ChallengeRules.rest_lines)
504. [x] Herausforderungs-Statistik (ChallengeRules.stats_lines)
505. [x] Sieg-Bildschirm mit Schwierigkeit (RunChronicle.note nennt Schwierigkeit und Regeln)
506. [x] Neues Spiel+ mit höherem Level (bestehend: NewGamePlus)
507. [x] Speedrun-Timer (Option) (RunTimer, Schalter auf der Herausforderungs-Seite)
508. [x] Seed-Anzeige für Zufallsmodi (ChallengeMenu)
509. [x] Teilen eines Seeds mit Freunden (ChallengeMenu, Seed-Code kopieren und einfügen)
510. [x] Wochen-Herausforderung (bestehend) mit Regeln (bestehend: WeeklyChallenge mit Feld, Regel und Variante)
511. [x] Turm-Herausforderung (bestehend) mit Stufen (bestehend: EchoTower mit 100 Stockwerken)
512. [x] Gauntlet (bestehend) mit Rangliste (Wochenbestenliste Leuchtturm-Treppe: climb_submit/climb_board kind 'stair', Freunde zuerst; Schalter climb_board, LocalClimb.gd)
513. [x] Herausforderungen in eigener Wortwahl (data/challenge_modes.json)
514. [x] Herausforderungen ohne Bezahl-Elemente (Premium-App) (Test: keine Regel in data/shop.json)
515. [x] Herausforderungs-Tests (tests/unit/test_challenge_modes.gd)
516. [x] Herausforderungen im Lexikon (Lexikon-Eintrag challenges)
517. [x] Herausforderung 'Ohne Wechsel' (Halte die Stellung (stand_ground))
518. [x] Herausforderung 'Halbe HP' (Halb erholt (half_rested))
519. [x] Herausforderung 'Boss zuerst' (Ass voran (ace_first))
520. [x] Herausforderung 'Nacht-Only' (Nachtbande (night_bonds))

## Wayfarer-Teams und Gegnerdesign

521. [ ] Jeder Wayfarer hat ein Thema (Element, Taktik)
522. [ ] Wayfarer-Teams auf Veteran mit Synergien
523. [ ] Wayfarer mit Feld-Strategie (Resonanz-Techniken)
524. [ ] Wayfarer mit Status-Strategie
525. [ ] Wayfarer mit Stufen-Strategie
526. [ ] Wayfarer mit Mehrfachkampf-Strategie
527. [x] Wayfarer-Dialog vor/nach dem Kampf (bestehend: intro und defeat in den Wayfarer-Daten)
528. [x] Wayfarer-Rückkämpfe (bestehend) (bestehend: TrainerData.can_rematch)
529. [x] Wayfarer-Telefonbuch-Ersatz: Laternenpost-Einladungen (WayfarerBook.invitations, Zeile an Rastquellen und im Wandererbuch)
530. [x] Wayfarer-Rangliste lokal (WayfarerBook: am häufigsten gekämpft, am härtesten)
531. [x] Wayfarer-Belohnungen variieren (data/wayfarer_rewards.json + WayfarerRewards.gd: beim ersten Sieg ein Gegenstand je nach Ring-Stufe, pro Wayfarer fest und einmalig)
532. [x] Wayfarer-Teamgröße bis 5 (Team 5 fix) (bestehend: GameState.MAX_PARTY, TrainerData.RIFT_BORN_MAX_TEAM)
533. [x] Wayfarer-Level an Level-Cap gebunden (bestehend: TrainerData.build_team mit ring_cap + FOE_OVER_CAP)
534. [x] Wayfarer mit gehaltenen Gegenständen auf Veteran (bestehend: TrainerData.keeps_keepsakes ab Veteran)
535. [ ] Wayfarer-Teams prüfen auf Dopplungen
536. [x] Wayfarer-Sprites eigenständig (bestehend: eigene Kunst laut LEGAL.md, ip_check prüft Metadaten)
537. [x] Wayfarer-Namen eigenständig (bestehend: tools/ip_check.sh)
538. [x] Wayfarer-Klassen eigenständig (keine bekannten Klassen übernehmen) (bestehend: tools/ip_check.sh)
539. [x] Wayfarer-Begegnung per Blickkontakt bewusst anders lösen (Ansprechen oder Signal-Laterne) (Beim Blickkontakt waehlt man 'Answer the signal' oder 'Not now'; danach sieht der Wayfarer einen bis zum Kartenwechsel nicht mehr, Ansprechen startet den Kampf)
540. [x] Wayfarer-Signal vor dem Kampf (Laterne blinkt) (NPC.signal_lantern blinkt beim Entdecken, bei reduzierter Bewegung ruhig)
541. [x] Wayfarer-Kampf überspringbar nach erstem Sieg (Rückkampf) (Entschieden und geschlossen: Battle Skip bleibt bezahlt (Pay2Win gewollt), kein Gratis-Ueberspringen)
542. [x] Wayfarer-Statistik im Lexikon (Wandererbuch als Lexikon-Seite)
543. [x] Wayfarer im Online-Weltziel (Weltziel-Art 'wayfarers' in goal_rotation (SQL + LocalBackend), Overworld zaehlt jeden Wayfarer-Sieg)
544. [x] Wayfarer-Echos von Freunden (bestehend: Echo-Partner und Echo-Duelle von Freunden)
545. [x] Wayfarer-Team-Builder für Testzwecke (bestehend: TrainerData.build_team mit Schwierigkeit, in Tests genutzt)
546. [x] Wayfarer-Balancing im Simulator (bestehend: BalanceSim.tune_foes, test_warden_sim)
547. [x] Wayfarer-KI-Persönlichkeiten (bestehend: data/ai_profiles.json)
548. [x] Wayfarer-Gruppen-Kämpfe (2 Wayfarer gegen Spieler + Kestra) (def 'pair' fuer einen zweiten gegnerischen Wayfarer; Salzmarsch: Hauler Tobin und Hauler Wren gegen dich und Kestra)
549. [x] Wayfarer mit Boss-Spirling (bestehend: boss-Schlüssel in TrainerData)
550. [x] Wayfarer-Turm mit 50 Stockwerken (bestehend: EchoTower mit 100 Stockwerken)
551. [x] Wayfarer-Turm Belohnungen (bestehend: Gauntlet.REWARDS und Waymarks)
552. [x] Wayfarer-Turm Regeln pro Stockwerk (bestehend: Regel-Varianten pro Stockwerk)
553. [x] Wayfarer-Turm Rangliste online (Wochenbestenliste Echo-Turm: climb_submit/climb_board kind 'tower' (Turm-Stockwerk bis 1000))
554. [x] Wayfarer-Daten validieren (validate_data) (bestehend: WorldValidator prüft Wayfarer-Teams und Arten)
555. [x] Wayfarer-Texte übersetzt (bestehend: test_i18n)
556. [x] Wayfarer-Teams pro Schwierigkeit (bestehend: teams_by_difficulty)
557. [x] Wayfarer-Geld-Belohnungen balancieren (Test: Rematch < Wayfarer < Warden pro Ring, Standardpreis steigt mit dem Ring, auf jeder Karte zahlt kein Wayfarer mehr als der Warden)
558. [ ] Wayfarer mit Overcharge-Strategie
559. [ ] Wayfarer mit Bond-Lehre (Tutorial)
560. [ ] Wayfarer-Kampfmusik pro Gebiet

## Info und Transparenz

561. [x] Schadensvorschau im Technik-Menü (~% HP), nur wenn das Matchup schon bekannt ist
562. [x] Schadensvorschau als Einstellung abschaltbar (Einstellungen: damage_preview (MenuHost))
563. [x] Schadensvorschau pro Ziel im Mehrfachkampf (BattleInfo.target_preview bei der Zielwahl)
564. [x] Technik-Info per langem Druck
565. [x] Kampflog (bestehend) mit Filter (BattleInfo.FILTERS, Filterzeile im Log)
566. [x] Gegner-Info-Seite im Kampf (Traits, bekannte Techniken) (BattleInfo.facts oben im Log)
567. [x] Gegner-Techniken werden bekannt, sobald sie benutzt wurden (BattleInfo.note/seen_arts)
568. [ ] Matchup-Lexikon
569. [ ] Werte-Rechner
570. [ ] Kampfregeln-Seite
571. [x] Zugreihenfolge-Vorschau (BattleInfo.order_hint auf der Technik-Karte)
572. [x] Energie-Vorschau (Technik-Karte: Energie danach)
573. [x] Status-Dauer-Anzeige (BattleInfo.status_line im Log)
574. [x] Feld-Restzüge-Anzeige (BattleInfo.field_line im Log)
575. [x] Bank-Anzeige (TeamRow.gd, eigenes Team)
576. [ ] Gegenstand-Anzeige
577. [x] Trait-Anzeige nach Auslösung
578. [ ] XP-Vorschau nach dem Kampf
579. [x] Level-Cap-Anzeige (Ring-Obergrenze im Log und im Team-Menü)
580. [x] Bond-Chance bewusst ohne Zahlen-Anzeige (Patent-Leitplanke: keine Fang-Quote) (tools/ip_check.sh sperrt Quoten-Anzeigen)
581. [x] Kampfende-Bericht (BattleInfo.report_lines am Ende des Logs)
582. [x] Replay-Ansicht (bestehend) (BattleReplay, OnlineReplaysMenu)
583. [ ] Lexikon-Suche
584. [x] Tipps beim ersten Kontakt (bestehend) (Tips battle/bond)
585. [x] Tipps zu neuen Funktionen (Resonanz, Phasen) (Tips resonance/boss_phase)
586. [x] Info-Texte in eigener Wortwahl (tools/ip_check.sh Phrasen-Sperre)
587. [x] Info-Texte übersetzt (tools/i18n/de_kampf_info.py, i18n_extract --check)
588. [x] Info für Screenreader (accessibility_name an Leisten, Sprites, Zielen)
589. [x] Info im Hochkontrast (high_contrast in CommandMenu/EraBattleHud)
590. [x] Info-Bildschirm bei 144 px Breite lesbar (Viewport 144x256, Karte und Log umbrechen)
591. [ ] Info-Kürzel einheitlich (ATK/DEF/FOC/SPD)
592. [x] Info: Krit-Treffer als 'keen hit' (bestehend, eigene Wortwahl) (BattleEvent.describe)
593. [x] Info: Effektivität als x2/x.5 (bestehend) (CommandMenu.matchup_tag)
594. [x] Info: Mehrfachziel als 'all' (bestehend) (CommandMenu.move_line)
595. [x] Info: Priorität als Pfeil (^ vor dem Namen der Technik)
596. [x] Info: Genauigkeit als Prozent
597. [ ] Info: Kategorie-Symbol
598. [ ] Info: Boss-Phasen-Marken
599. [x] Info: Regel-Banner bei Warden (RuleBanner.gd)
600. [x] Info: Seed im Log (BattleInfo.facts)

## Bedienung und Komfort

601. [x] Tempo 1x/2x/4x (bestehend) (GameState.BATTLE_SPEEDS)
602. [x] Auto-Kampf für Wildkämpfe (bestehend) (GameState.auto_battle)
603. [x] Letzten Zug wiederholen (Cursor steht auf der zuletzt genutzten Technik, BattleInfo.focus_row)
604. [ ] Rückgängig vor Zugstart
605. [ ] Technik-Favoriten
606. [ ] Technik-Reihenfolge
607. [ ] Schnell-Heilen nach dem Kampf (Gegenstand-Vorschlag)
608. [x] Schnell-Wechsel per Wischen bewusst nicht (Patent-Leitplanke: kein Swipe) (tools/ip_check.sh sperrt swipe)
609. [x] Langer Druck für Info
610. [x] Gamepad-Steuerung (bestehend) (SPEED_ACTION/AUTO_ACTION, Fokus)
611. [x] Einhand-Modus (bestehend) (GameState.one_hand)
612. [x] Links-Hand-Modus (bestehend) (GameState.left_handed)
613. [x] Tastatur-Kürzel 1 bis 4 für Techniken (BattleInfo.art_key)
614. [x] Ziel-Wahl per Tippen auf das Sprite (BattleScene._pick_target)
615. [x] Ziel merken (BattleInfo.aim_start)
616. [x] Auto-Ziel (ein Gegner: kein Zielen nötig)
617. [x] Kampf-Text per Tippen überspringen (TextBox._skip_or_advance)
618. [x] Kampf-Text automatisch weiter (Option) (bei 2x/4x und Auto)
619. [x] Batteriesparen (bestehend) (GameState.battery_saver)
620. [x] Vibrations-Feedback (bestehend rumble) (GameState.vibration)
621. [ ] Einstellungen im Kampf erreichbar
622. [x] Kampf-Menü-Höhe fest (bestehend) (CommandMenu.PANEL_HEIGHT)
623. [ ] Große Knöpfe-Option
624. [x] Bestätigung bei riskanten Aktionen (Rückzug in Boss-Kampf nicht möglich) (Rückzug nur in Wildkämpfen)
625. [x] Wechsel-Liste mit HP und Matchup (BattleInfo.switch_tag)
626. [x] Gegenstand-Liste mit Wirkung (Beschreibung als Hinweiszeile)
627. [x] Lager-Lernen-Option (umgesetzt) im Kampfmenü erklärt (Tipp battle_comfort, Log)
628. [x] Gegner-Bank-Punkte (TeamRow.gd, Team des Gegners)
629. [ ] Kampf-Wiederaufnahme nach Unterbrechung
630. [ ] Schnellspeichern im Kampf bewusst nicht (kein Savescum auf Rift-Born)
631. [x] Komfort-Tipps beim ersten Kampf (Tips battle_comfort)
632. [ ] Kampf-Steuerung ohne Zeitdruck (keine Echtzeit-Elemente)
633. [x] Bond-Melodie (bestehend) mit Barrierefreiheit (Bond-Stil Mine! statt Melodie, Hochkontrast)
634. [x] Kampf-UI bei 144x256 skaliert (project.godot)
635. [x] Kampf-UI im Querformat bewusst nicht (orientation=1, Hochformat)
636. [x] Kampf-UI mit Safe-Area (bestehend) (SafeArea.apply)
637. [x] Kampf-UI Fokus-Navigation per Gamepad (CommandMenu, Zielwahl mit Nachbarn)
638. [x] Kampf-UI Screenreader-Texte (accessibility_name)
639. [x] Kampf-UI Text-Geschwindigkeit (bestehend) (GameState.text_speed)
640. [x] Kampf-UI Testfälle (test_battle_ux, test_battle_info, test_kampf_info)

## Tempo, Animation und Präsentation

641. [x] Animationen pro Element eigenständig (bestehend: ElementFx zeichnet je Element eigene Formen)
642. [x] Animationen kürzer bei 2x/4x (bestehend Speed-Scale) (bestehend: Juice.speed teilt jede Kampf-Dauer)
643. [x] Weniger Bewegung (bestehend) schaltet Wackeln ab (bestehend: Juice.shake_scale ist 0 bei weniger Bewegung)
644. [x] Treffer-Pause beim Krit (BattleShow.crit_hitstop, data/battle_show.json)
645. [x] Kamera-Zoom beim Boss-Phasenwechsel (BattleShow._phase_zoom: harter Ganzzahl-Zoom in Ära I-III, IV/V behalten ihre Kamera)
646. [x] Feld-Tönung im Hintergrund (bestehend: FieldBadge.tint_rect mit RiftFields.tint je Feld und Ära, #525)
647. [x] Status-Partikel (SpirlingAura: Partikel je Status aus data/battle_show.json)
648. [x] Stufen-Aura (SpirlingAura: Punktring an den Füßen, warm bei Plus, kühl bei Minus)
649. [x] K.o.-Animation eigenständig (Verblassen statt Umfallen) (bestehend: SpirlingSprite.faint sinkt und verblasst)
650. [x] Einwechsel-Animation eigenständig (Laternenlicht statt Ball) (SpirlingAura.glow_lantern beim Einwechseln, Spirling gleitet herein)
651. [x] Kein Ball, kein Wurf (Leitplanke) (bestehend: step_out gleitet, nie geworfen; ip_check sperrt die Begriffe)
652. [x] Sprite-Atmen im Leerlauf (bestehend: Atem-Frames und breath_scale ab Ära IV, Ära I-III stehen still wie damals)
653. [x] Sprite-Reaktion auf Treffer (bestehend: knockback und hit_flash)
654. [x] Siegespose (BattleShow._victory_pose: Hüpfer und Glanz ab Ära III)
655. [x] Boss-Größe (BattleShow.boss_rect: ein einzelner Riss-Boss steht in Ära I-III in voller Bildgröße, data/battle_show.json boss_size)
656. [x] Mehrfachkampf-Formation (bestehend) (bestehend: BattleScene.formation_slots)
657. [x] Kampf-Übergang pro Ära (bestehend: BattleIntro pro Ära)
658. [x] Kampf-Hintergrund pro Gebiet (bestehend Backdrop) (bestehend: BattleBackdrop je Gebiet)
659. [x] Kampf-Hintergrund Tag/Nacht (BattleShow.night_tint auf dem Hintergrund, nur draußen)
660. [x] Kampf-Intro kürzer bei Rückkämpfen (BattleShow.intro_share: Rückkampf mit kurzem Intro ohne Blitze)
661. [x] Kampf-Outro mit Bericht (BattleShow.play_outro: Berichtskarte am Kampfende, Tippen schließt sie)
662. [x] Fotomodus im Kampf (bestehend) (PhotoMode aus der Oberwelt, im Kampf über 'Foto machen' im Kampflog)
663. [x] Replay mit Tempo-Wahl (bestehend: BattleScene spielt replay_inputs, der Tempo-Knopf gilt dabei)
664. [x] Animation-Budget pro Frame (Handy) (BattleShow.fx_fps/fx_particles: Effekte zeichnen auf dem Handy und im Batteriesparmodus höchstens 30-mal pro Sekunde)
665. [x] Animation ohne Blitz-Effekte (Epilepsie-Sicherheit) (bestehend: tools/fx_flash_check.tscn, höchstens 3 Pulse pro Sekunde)
666. [x] Animation-Tests im Screenshot-Werkzeug (bestehend: tools/fx_gallery.gd und tools/era_battle_shots.gd)
667. [x] Pixel-Perfect bleibt bei Effekten (bestehend: Juice rundet Positionen; neue Marken auf ganzen Pixeln)
668. [x] Effekte in Ära-Palette (bestehend: EraMoveFx in Ära-Farben; Aura in Ära I in Palettenfarben)
669. [x] Effekte mit Hochkontrast-Variante (ElementFx.hc_ink: Tinte und Akzent, jede Form mit Papierrand; SpirlingAura bestehend)
670. [x] Effekte im Asset-Log (docs/ASSET_LOG.md: Effekt-PNGs bestehend, Code-Effekte jetzt genannt)
671. [x] Treffer-Zahlen optional einblenden (Einstellung Schadenszahlen, Standard aus; BattleShow.show_number)
672. [x] Schadenszahl in Weiß mit Tintenrand (BattleShow.show_number: weiße Ziffern mit Tinten-Umriss)
673. [x] HP-Balken-Tween (bestehend) (bestehend: InfoStrip.animate_hp)
674. [x] Energie-Pips-Animation (InfoStrip.pip_look: neue Pips springen auf, verbrauchte verblassen)
675. [x] Feld-Banner beim Start (BattleShow-Banner mit dem Feldnamen)
676. [x] Phasen-Banner beim Boss (BattleShow-Banner '%s erwacht')
677. [x] Regel-Banner beim Warden (bestehend: RuleBanner beim RULE-Ereignis)
678. [x] Partner-Banner bei Kestra (BattleShow-Banner 'Seite an Seite')
679. [x] Kampf-Ende-Banner (BattleShow-Banner Sieg, Verbunden, Entwischt, Erschöpft)
680. [x] Präsentation bleibt eigenständig (kein bekanntes Layout) (bestehend: eigene Anordnung, docs/legal/IP_PATENT_AUDIT.md)

## Audio im Kampf

681. [x] Treffer-Sounds pro Element (bestehend) (bestehend: Sound.element_hit)
682. [x] Krisen-Musik bei wenig HP (bestehend) (bestehend: battle_pinch)
683. [x] Boss-Phasen-Musik (boss_phase-Klang und Musik-Tonhöhe in Phase 2 (Sound.music_pitch))
684. [x] Feld-Klangteppich (BattleShow: jedes Riss-Feld legt seine Ambiente-Schleife leise unter den Kampf, data/battle_show.json field_ambience)
685. [x] Status-Sounds (status_<id>.wav je Status, BattleAudio.status_sound)
686. [x] Stufen-Sounds steigend (stage_up/stage_down, Tonhöhe steigt je Stufe)
687. [x] Overcharge-Sound steigend (overcharge.wav, Tonhöhe nach eingesetzter Energie)
688. [x] Resonanz-Klang beim Feld-Start (field_rise.wav)
689. [x] Feld-Ende-Klang (field_fade.wav)
690. [x] Schrei pro Spirling (bestehend) (bestehend: Sound.cry)
691. [x] Sieges-Jingle (bestehend: Sound.jingle victory)
692. [x] Niederlagen-Jingle (defeat.wav, Musik blendet aus)
693. [x] Bond-Melodie (bestehend: Echo-Ruf im BondMinigame in der Tonleiter des Elements)
694. [x] Lautstärke Musik/SFX getrennt (bestehend) (bestehend: Busse Musik, SFX, UI, Stimme, Ambiente)
695. [x] Audio-Ducking bei Text (TextBox.duck_music im Kampf, Sound.duck_music, text_duck_db)
696. [x] Audio-Hinweise für Blinde (Effektivität als Ton) (eff_up/eff_down-Töne nach dem Treffer)
697. [x] Audio-Test-Raum (bestehend Sound-Test) (bestehend: Menü Sound-Test)
698. [x] Audio im Asset-Log (bestehend: docs/ASSET_LOG.md, neue Klänge eingetragen)
699. [x] Audio eigenständig komponiert (bestehend: tools/audio/gen_audio.py, neue Klänge in sfx.py battle_show_sfx)
700. [x] Audio-Budget für APK (bestehend: tools/apk_budget.sh)
701. [x] Audio bei 4x kürzer (BattleAudio.keep: Auflade-, Flug- und Ausweich-Klänge entfallen bei 4x)
702. [x] Audio im Batteriesparmodus reduziert (BattleAudio.keep: Flug-, Krit- und Feldwechsel-Akzente entfallen im Batteriesparmodus)
703. [x] Audio-Variation pro Ära (bestehend: data/era_audio.json)
704. [x] Audio für Mehrfachkampf nicht überladen (bestehend: 10 Stimmen mit Priorität; Akzente mit Mindestabstand)
705. [x] Audio für Boss-Intro (boss_intro.wav)
706. [x] Audio für Warden-Regel (rule_seal.wav)
707. [x] Audio für Partner (partner_call.wav)
708. [x] Audio für Ruhe-Regel-Fehlschlag (calm_fail.wav)
709. [x] Audio für Schadensvorschau (kein Ton) (bestehend: die Vorschau im CommandMenu spielt keinen Ton)
710. [x] Audio-Tests (bestehend) (bestehend: test_audio, test_sound, neu test_battle_show)
711. [x] Audio-Fade beim Kampfende (Musik blendet bei Niederlage und Flucht aus)
712. [x] Audio-Loop sauber (music.close_loop für alle Kampf-Schleifen, Prüfung tools/audio/loop_check.py)
713. [x] Audio-Nacht-Variante (battle_night.ogg, nachts draußen; BattleAudio.theme)
714. [x] Audio-Fest-Variante (battle_fest.ogg, solange ein Fest läuft)
715. [x] Audio-Wochen-Echo-Thema (battle_echo.ogg auf dem Leitmotiv)
716. [x] Audio-Turm-Thema (battle_tower.ogg im Riss-Turm und auf der Endlos-Strecke)
717. [x] Audio-Online-Duell-Thema (battle_duel.ogg in Live-, Echo- und Liga-Duellen)
718. [x] Audio: Treffer-Lautstärke nach Schaden (bestehend: Sound.hit_volume_db)
719. [x] Audio: Krit-Akzent (crit_accent.wav)
720. [x] Audio: Feld-Wechsel-Akzent (field_shift.wav, wenn ein Feld ein anderes ablöst)

## Fortschritt, XP und Training

721. [x] Lager-Lernen: Spirlings auf der Bank erhalten die Hälfte der XP (Einstellung, Standard an)
722. [x] XP-Verteilung im Kampfende-Bericht (Wachstums-Zeile nach dem Kampf, GrowthRules.distribution_line)
723. [x] Level-Cap blockiert XP (bestehend) (BattleModel._give_xp, Test test_kampf_growth_wild)
724. [ ] Spark-Training (bestehend) mit Kampfquellen
725. [x] Technik-Lehrer (Echo-Kristalle mit teaches/for_elements, GameState.can_learn_echo)
726. [x] Entwicklung nach Kampf (bestehend) (Overworld._after_battle Entfalten-Hinweis)
727. [x] Entwicklung abbrechen (Option) (Entfalten nie automatisch, Zurückfalten jederzeit)
728. [x] Temperament-Wechsel-Gegenstand (Temper Shift, PauseMenu)
729. [x] Spark-Reset (spark_wash, GrowthRules.reset_spark)
730. [x] XP-Bonus für Rückkämpfe (GrowthRules rematch_mult)
731. [x] XP-Bonus für Bond-Spirlings (GrowthRules kinship_mult ab Verbundenheit 80)
732. [x] XP-Malus bei Überlevel bewusst nicht (kein Malus ausser Era-V-Ringskalierung, in BALANCE.md und Lexikon)
733. [x] XP-Kurve dokumentieren (docs/BALANCE.md gen:growth)
734. [x] XP-Kurve im Simulator prüfen (GrowthRules.battles_between, Test)
735. [x] XP-Anzeige bei Bank-Spirlings (XP_GAINED bench, Team-Menü Wachstum bis zum nächsten Ring)
736. [ ] Training-Arena im Leuchtturm
737. [ ] Trainings-Dummies (Spirlings aus Holz) für Tests
738. [ ] Trainings-Kämpfe ohne Risiko
739. [ ] Trainings-Ziele (Quests)
740. [ ] Trainings-Statistik
741. [x] Level-Aufstieg-Zusammenfassung bei mehreren Levels (GrowthRules.summary_line im Kampflog)
742. [x] Lern-Technik-Dialog überspringbar (kein Wahl-Dialog mitten im Kampf, nur eine Zeile, GrowthRules.missed_arts)
743. [x] Lern-Technik später nachholen (GameState.relearn)
744. [x] XP für Partner-Spirlings nie (bestehend) (BattleModel._award_xp is_partner_index)
745. [x] XP in Online-Duellen nie (Fairness) (EchoTeam.duel_copy, Test)
746. [x] XP auf Story höher (GrowthRules difficulty_mult)
747. [x] XP-Glücksbringer als gehaltener Gegenstand (growth_charm)
748. [x] XP-Zusammenfassung pro Gebiet (Erfolge > Wachstum und Bindungen)
749. [x] Level-Cap-Erhöhung nach Riss (bestehend) (GameState.LEVEL_CAPS)
750. [x] Level-Cap in Turnieren (EchoTeam.DUEL_LEVEL Ring 50)
751. [x] Lager-Lernen nur für das Team, nicht für das Lager (BattleModel._award_xp nur parties)
752. [x] Lager-Lernen respektiert Level-Cap (umgesetzt)
753. [x] Lager-Lernen für erschöpfte Spirlings nicht (umgesetzt)
754. [x] Lager-Lernen in den Einstellungen (umgesetzt)
755. [x] Lager-Lernen im Lexikon erklären (Lexikon bench_lessons)
756. [x] Training: Wochen-Echo gibt Spark (WeeklyChallenge.REWARDS spark_charm)
757. [x] Training: Feste geben Spark (spark_charm bei jedem Fest-Händler)
758. [x] Training: Turm gibt Gegenstände (GrowthRules.tower_finds in RiftTower.finish)
759. [x] Training: Online-Weltziel gibt XP-Bonus (GrowthRules world_goal, FriendsMenu)
760. [x] Training: kein Grind-Zwang (Balance-Ziel) (no_grind_battles, Test)

## Wild-Begegnungen und Bond

761. [x] Bond-Echo-Melodie (bestehend) bleibt ohne Wurf und ohne Quote (BondEcho, BondCalc)
762. [x] Bond nur gegen Wild (bestehend)
763. [x] Bond im Schwarm (bestehend)
764. [x] Bond-Bonus durch Status (bestehend prüfen) (BondCalc.STATUS_BONUS)
765. [x] Bond-Bonus durch Feld (WildRules.field_bond_bonus)
766. [x] Bond-Bonus durch Gegenstand Echo-Muschel (echo_shell)
767. [x] Bond-Fehlschlag gibt freie Aktion (bestehend)
768. [ ] Bond-Erfolg-Animation eigenständig
769. [x] Wild-Begegnungen im Farn, Schilf, Geröll (bestehend)
770. [x] Wild-Ketten-Bonus (Prisma-Chance steigt) (WildRules.prism_chance)
771. [x] Wild-Schwarm-Ereignisse (WildRules.swarm)
772. [x] Wild-Spawns nach Tageszeit (bestehend)
773. [x] Wild-Spawns nach Feld (Wetter hebt Elemente, WildRules.weather_boost)
774. [x] Wild-Auto-Kampf (bestehend)
775. [x] Wild-Level an Gebiet (encounters.json min/max)
776. [x] Wild-KI Stufe 0 (bestehend)
777. [ ] Wild-Überraschung
778. [x] Wild-Rückzug-Regel (bestehend)
779. [x] Wild-Spirlings mit Gegenständen (selten) (WildRules.roll_held)
780. [ ] Wild-Begegnungs-Rate einstellbar (Laterne)
781. [x] Wild-Abwehr-Gegenstand (Wild Ward)
782. [x] Wild-Lockmittel (Lure Scent, Encounter Call)
783. [x] Wild-Prisma-Varianten (bestehend)
784. [x] Wild-Seltenheit sichtbar im Spirlog (SpirlogBook.page_text)
785. [x] Wild-Spawn-Tabellen validieren (test_kampf_growth_wild)
786. [x] Bond-Melodie barrierefrei (visuell + Ton) (BondMinigame Form, Licht und Ton je Marke)
787. [x] Bond-Melodie Schwierigkeit pro Art (BondEcho.CALL_LENGTH nach Seltenheit)
788. [x] Bond-Ergebnis ohne Prozentzahl (Leitplanke)
789. [x] Bond-Statistik im Lexikon (Lexikon bond_stats)
790. [x] Bond-Tests (bestehend)
791. [ ] Wild-Horde mit Anführer
792. [x] Wild-Horde-Bond
793. [ ] Wild-Boss (seltene alte Spirlings) im Endgame
794. [ ] Wild-Begegnung im Nebel (Sicht begrenzt)
795. [x] Wild-Begegnung nachts häufiger (WildRules.rate_mult)
796. [x] Wild-Begegnung im Riss mit Feld (Kartenfeld gilt für Wildkämpfe)
797. [x] Wild-Begegnung als Tageshighlight (bestehend Find of the Day)
798. [x] Wild-Begegnung Online-Echo (OnlineEvents.sighting_boost)
799. [x] Wild-Begegnung Wochen-Spawn (WildRules.weekly)
800. [x] Wild-Begegnung Fest-Spawn (Season-Boost)

## Endgame-Kampfmodi

801. [x] Turm (bestehend) mit 50 Stockwerken (EchoTower.gd: 30 Stockwerke Leuchtturm-Treppe plus Endlos-Strecke bis Stockwerk 100)
802. [ ] Gauntlet (bestehend) mit Rangliste
803. [x] Wochen-Echo (bestehend) mit Meister-KI (Overworld Wochen-Echo mit ai 3)
804. [x] Boss-Rush (MasterTour.gd: alle Wardens am Stück ohne Heilung; dazu die Herzstiege der Kampfhallen)
805. [x] Turnier mit Regeln (Wochenend-Turnier TourneyRules.gd, K.o. mit festen Regeln)
806. [x] Zufalls-Team-Modus (Kampfhallen: Los-Halle mit drei Zufalls-Spirlings auf Ring 50 (BattleHalls.gd))
807. [x] Leih-Team-Modus (RandomRift.gd Leih-Team und Leih-Wochen im Wochen-Echo)
808. [x] Draft-Modus (Spirlings abwechselnd wählen) (Kampfhallen: Wahl-Halle, abwechselnd mit dem Echo wählen)
809. [x] Überlebens-Modus (keine Heilung) (Kampfhallen: Lange Nacht, zwölf Runden ohne Heilung)
810. [x] Zeitangriff (HallTimes.gd: Bestzeiten je Halle, auch für die Kampfhallen)
811. [x] Puzzle-Kämpfe (Sieg in einem Zug) (BattlePuzzle.gd: Prüfungen mit Ziel und Zuglimit)
812. [ ] Lehr-Kämpfe (Tutorial-Rätsel)
813. [x] Herausforderungs-Kämpfe gegen Warden-Echos (EchoTower Warden-Stockwerke, WardenRematch, Meister-Risse)
814. [x] Prisma-Boss-Kämpfe (Kampfhallen: Prisma-Herz, ein Prisma-Rissherz pro Woche)
815. [x] Endgame-Belohnungen (Wegmarken pro Halle und Woche, Titel, Geschichten, Ruhmeshalle)
816. [x] Endgame-Ranglisten (Wochen-Rangliste (Freunde und Welt), Liga-Ränge)
817. [x] Endgame-Abzeichen (Abzeichen hall_first und hall_regular)
818. [x] Endgame-Statistik (Hallen-Statistik: Läufe, Siege, geschafft, Bestwert)
819. [x] Endgame-Saisonregeln (Festpokal nur während eines Fests, Gegner nur aus dessen Elementen)
820. [x] Endgame-Fest-Turniere (Kampfhallen: Festpokal)
821. [x] Endgame ohne Bezahl-Elemente (Hallen kämpfen als Echo-Kampf: keine Siegel, Amulette oder Pass-Energie, Belohnungen nie kaufbar (Test))
822. [x] Endgame-Texte übersetzt (tools/i18n/de_battle_halls.py)
823. [x] Endgame-Tests (tests/unit/test_battle_halls.gd)
824. [x] Endgame-Balance (Hallen-Gegnerringe per Probe eingestellt, Test: erste Runde jeder Halle weder geschenkt noch hoffnungslos)
825. [x] Endgame-Replay (letzter Hallenkampf als Wiederholungs-Code, ansehbar unter Rekorde, Online-Wiederholungen)
826. [x] Endgame-Seed teilen (Lauf-Code: acht Zeichen für Halle und Seed, Freunde spielen denselben Lauf)
827. [x] Endgame-Freundes-Duelle (Echo-Duell und Live-Duell unter Freunden)
828. [x] Endgame-Team-Codes (Team-Code: drei Spirlings als acht Zeichen, Kampf gegen das Team auf Ring 50)
829. [x] Endgame-Level-Skalierung (Hallen: alle Spirlings als Kopien auf Ring 50)
830. [x] Endgame-Feldrotation (Hallen: das Feld wechselt jede Runde)
831. [x] Endgame-Regelrotation (TowerWeek.gd und Hallen-Regelvariante pro Woche)
832. [x] Endgame: Iron-Oath-Turm (Leuchtturm-Treppe unter dem Eisernen Schwur mit eigenem Bestwert (gauntlet_best_oath))
833. [x] Endgame: Mehrfachkampf-Turm (Kampfhallen: Zwillingsstiege 2 gegen 2)
834. [x] Endgame: Schwarm-Turm (Kampfhallen: Schwarmstiege gegen sechs schwächere Spirlings)
835. [x] Endgame: Boss-Turm (Kampfhallen: Herzstiege, ein Rissherz pro Stockwerk)
836. [x] Endgame: Lore-Belohnungen (Hallengeschichten: eine Seite pro erster Hallen-Bezwingung)
837. [ ] Endgame: Kosmetik-Belohnungen (Laternenfarben)
838. [x] Endgame: Titel auf der Wayfarer-Karte (Titel aus Hallen und Zielen auf der Wanderer-Karte, Server nimmt nur bekannte Titel (20261113200110_card_title.sql))
839. [x] Endgame: Wochen-Ziel (Hallen-Wochenziel: 12 Hallensiege pro Woche)
840. [x] Endgame: Ruhm-Halle (Ruhmeshalle: Team und Datum jeder ersten Bezwingung)

## Online-Kämpfe

841. [x] Echo-Duelle (bestehend) asynchron (bestehend, EchoTeam.gd)
842. [x] Echo-Partner (bestehend) im Mehrfachkampf (bestehend, pick_echo_partner)
843. [x] Online-Regeln gleich für alle (Faire Liga: Grundwerte, gleiche Regeln)
844. [x] Online-Level-Skalierung auf 50 (Faire Liga auf Ring 50 (league_fair_ring))
845. [x] Online-Ruhe-Regel (BattleModel.calm_rule_blocks gilt in jedem Nicht-Wildkampf, auch online)
846. [x] Online-Zug-Timeout (Live-Duell turn_seconds 30)
847. [x] Online ohne Chat (bestehend: nur Phrasen) (bestehend)
848. [x] Online-Phrasen im Kampf (live_emote mit festen Phrasen)
849. [x] Online-Rangliste wöchentlich (bestehend) (bestehend)
850. [x] Online-Betrugsschutz: Server prüft Teams (Liga baut Teams aus dem gespeicherten Team neu, _save_cheat prüft Spielstände)
851. [x] Online-Replay-Seed (BattleReplay-Seed, ReplayLibrary-Code)
852. [x] Online-Freundes-Duell (Live-Duell und Echo-Duell)
853. [x] Online-Weltziel-Boss (Raid-Risse (RaidRules.gd) mit gemeinsamer Rangliste)
854. [x] Online-Turnier asynchron (Wochenend-Turnier TourneyRules.gd)
855. [ ] Online-Teamcode
856. [x] Online-Spirling-Tausch nie (bestehend Leitplanke) (Spirlings werden nie verschenkt; Tausch nur unter Freunden hinter Flag trade_spirling)
857. [x] Online-Belohnungen ohne Geld (Wegmarken nie käuflich, Belohnungen sind Gegenstände und Titel)
858. [x] Online-Datenschutz (bestehend) (bestehend)
859. [x] Online-Server Contabo (bestehend) (bestehend)
860. [x] Online-Verbindungsabbruch: Kampf läuft lokal weiter (Online.in_battle: kein Pause-Bildschirm während eines Kampfes)
861. [x] Online-KI-Echos nutzen Meister-KI (EchoTeam.DUEL_AI = 3)
862. [x] Online-Fairness-Test (tests/unit/test_online_echo_k11.gd: faire Liga und Echo-Duell gleich für alle)
863. [x] Online-Version prüfen (bestehend CLIENT_VERSION) (bestehend)
864. [x] Online-Echos mit gehaltenen Gegenständen (EchoTeam nimmt Andenken mit, nie gekaufte; Server nur bekannte Items (20261113200120_echo_held.sql))
865. [x] Online-Felder wählbar (Echo-Duell: Feld vor dem Kampf wählen, EchoTeam.DUEL_FIELDS)
866. [x] Online-Regeln pro Woche (Echo-Duelle mit der Wochenregel der Kampfhallen)
867. [x] Online-Statistik (ReplayLibrary: Siegquote pro Spirling, meistgesehene Gegner)
868. [x] Online-Abzeichen (Abzeichen echo_duelist und echo_victor)
869. [x] Online-Titel (Liga-Saisontitel und Hallen-Titel auf der Wanderer-Karte (20261113200110_card_title.sql))
870. [x] Online-Melde-Funktion (bestehend reports) (bestehend, reports)
871. [x] Online-Sperre bei Betrug (_cheat_held: nach cheat_flag_limit Vermerken raus aus Liga und Raids)
872. [x] Online-Server-Validierung der Kampfergebnisse (Schiedsrichter-Dienst (BattleReferee, battle_submit))
873. [x] Online-Ergebnis-Replay prüfen (Schiedsrichter spielt jedes Ergebnis nach)
874. [x] Online-Tests in LocalBackend (bestehend) (bestehend)
875. [x] Online-SQL-Tests (bestehend) (bestehend)
876. [ ] Online-Echo-KI-Stufe pro Rang
877. [x] Online-Matchmaking nach Rang bewusst einfach (league_find: 100 Punkte Spanne, wächst langsam)
878. [x] Online-Saison-Reset (Liga-Saisons (league_seasons), Neustart von selbst)
879. [x] Online-Belohnung kosmetisch (Saison-Rahmen season_<n>_<rank>)
880. [x] Online-Texte übersetzt (tools/i18n/de_online*.py)

## Barrierefreiheit

881. [x] Screenreader-Texte im Kampf (bestehend Grundlagen) (InfoStrip/MiniStrip/SpirlingSprite, Technik-Knöpfe mit Info als Beschreibung)
882. [x] Hochkontrast (bestehend) (UITheme.high_contrast)
883. [x] Weniger Bewegung (bestehend) (GameState.reduce_motion)
884. [x] Große Schrift-Option (GameState.large_text, UITheme)
885. [x] Farbenblind-sichere Symbole (bestehend Formen) (GameState.color_blind, BattleUiStyle.matchup_mark)
886. [x] Ton-Hinweise für Effektivität (BattleScene._hit_sound: hit_strong/hit/hit_weak)
887. [x] Vibrations-Hinweise (Haptics hit/heavy)
888. [x] Einhand-Modus (bestehend) (GameState.one_hand)
889. [x] Keine Zeitlimits offline (Züge warten, Bindestil Ruhig ohne Zeitlimit)
890. [x] Text-Geschwindigkeit (bestehend) (GameState.text_speed)
891. [x] Auto-Text weiter (BattleScene: auto_advance bei 2x/4x und Auto-Kampf)
892. [x] Bond-Melodie ohne Rhythmus-Zwang (Option 'Ruhig') (Bindestil Ruhig, BondMinigame.calm)
893. [x] Schadensvorschau hilft beim Planen (GameState.damage_preview)
894. [x] Kampflog vorlesen (TextBox als Live-Region)
895. [x] Fokus-Navigation (CommandMenu grab_focus, ui-Aktionen)
896. [ ] Knopfgrößen
897. [ ] Kontrast der HP-Leiste
898. [ ] Status-Kürzel lesbar
899. [ ] Feld-Banner lesbar
900. [ ] Boss-Phasen-Banner lesbar
901. [x] Untertitel für Schreie (Sound.cry_caption)
902. [ ] Leichte Sprache-Option für Kampftexte
903. [x] Deutsch und Englisch (bestehend) (docs/I18N.md)
904. [x] Weitere Sprachen vorbereiten (14 Sprachen, docs/I18N.md)
905. [x] Barrierefreiheit-Tests (tests/unit/test_kampf_a11y_tech.gd)
906. [x] Barrierefreiheit-Dokumentation (docs/KAMPF_TECHNIK.md Abschnitt 4)
907. [ ] Barrierefreiheit im Store-Text
908. [ ] Eingabe-Verzögerung einstellbar
909. [x] Doppeltipp vermeiden (keine Doppeltipp-Aktion, test_ux)
910. [x] Wisch-Gesten vermeiden (Leitplanke und Zugänglichkeit) (Wischen nur zum Listen-Scrollen)
911. [x] Lange Drücke optional (Info per I/F1/Gamepad-Y und Screenreader, CommandMenu)
912. [ ] Pausen jederzeit
913. [x] Blitzfreie Effekte (tools/fx_flash_check.gd)
914. [x] Audio-Mono-Option (GameState.mono_audio)
915. [x] Lautstärke pro Kanal (Musik, Effekte, Stimme, Umgebung)
916. [x] Kampf ohne Ton spielbar (Texte, Untertitel, Schrei-Untertitel)
917. [x] Kampf ohne Farbe spielbar (Farbenblind-Formen, Era I in vier Graustufen)
918. [x] Kampf mit Gamepad spielbar (Joypad-Eingabe, Info per Y)
919. [x] Kampf mit Tastatur spielbar (ui-Aktionen, Info per I/F1)
920. [ ] Kampf mit Screenreader spielbar

## Balance-Werkzeuge und Tests

921. [x] Tests für Meister-KI, Resonanz-Felder, Boss-Phasen, Ruhe-Regel, Lager-Lernen, Schadensvorschau
922. [x] Balancing-Simulator (bestehend) mit Meister-KI (balance_sim --ai 3)
923. [x] Simulator-Bericht pro Element (--mode mono, BalanceGroups)
924. [x] Simulator-Bericht pro Technik (Moves-Tabelle im Bericht)
925. [x] Simulator-Bericht pro Trait (BalanceGroups.by_trait)
926. [x] Simulator-Bericht pro Gegenstand (--mode keepsakes)
927. [x] Simulator-Bericht pro Feld (--mode fields)
928. [x] Simulator-Bericht pro Schwierigkeit (--difficulty, --mode warden)
929. [x] CI-Wächter für Gewinnraten (bestehend) (test_balance, type_sim --strict)
930. [x] Daten-Validierung (bestehend) für neue Felder (KampfChecks.field_errors)
931. [x] Daten-Validierung für Boss-Phasen (KampfChecks.boss_errors)
932. [x] Replay-Regressionstests (test_p3_extras, test_move_curve, test_fuzz_battle_turns)
933. [x] Seed-Determinismus-Test (test_balance test_same_seed_same_result)
934. [x] Speicherstand-Migration (bestehend) für neue Einstellungen (settings_from_dict mit Standardwerten)
935. [x] Einstellungs-Migration (Lager-Lernen Standard an) (test_kampf_a11y_tech)
936. [ ] Leistungs-Test der KI
937. [ ] Screenshot-Tests für Kampf-UI
938. [x] i18n-Prüfung (bestehend) für neue Texte (i18n_extract --check)
939. [x] IP-Prüfung (bestehend) für neue Namen (tools/ip_check.sh)
940. [x] Originalitäts-Zahlen (bestehend) nicht verändern (test_originality)
941. [x] Balance-Dokumentation aktualisieren (tools/balance/run_all.sh)
942. [ ] Balancing-Ziele pro Gebiet
943. [ ] Balancing: Anfänger-Spirlings gleich stark
944. [x] Balancing: keine Pflicht-Spirlings (Band 30-70 % je Art, test_balance)
945. [x] Balancing: jede Technik hat einen Zweck (seltene Techniken im Team-Bericht)
946. [x] Balancing: Status nicht zu stark (test_move_curve, Status höchstens 30 %)
947. [x] Balancing: Felder nicht zu stark (Feld-Band +8 bis +15, tests/slow)
948. [ ] Balancing: Bosse fair
949. [x] Balancing: Meister-KI fordernd, nicht unfair (KI-Leiter, tests/slow)
950. [x] Balancing: Story leicht (targets.json, test_warden_sim)
951. [x] Balancing: Veteran fordernd (targets.json, test_warden_sim)
952. [x] Balancing: Rift-Born hart (targets.json, test_warden_sim)
953. [x] Balancing: Online fair (gleicher Ring im Echo-Duell und in der fairen Liga)
954. [x] Balancing: Endgame lang (EndgameSim 90 Tage)
955. [x] Balancing-Tests in CI (test_balance, test_warden_sim, type_sim)
956. [x] Fuzz-Test: zufällige Aktionen 10.000 Züge ohne Fehler (tests/fuzz/test_fuzz_battle_turns.gd)
957. [x] Fuzz-Test für Mehrfachkämpfe
958. [x] Fuzz-Test für Bosse
959. [x] Fuzz-Test für Felder
960. [x] Fuzz-Test für Online-Echos (tests/fuzz/test_fuzz_battle_turns.gd)

## Originalität, Recht und Technik

961. [x] Keine Namen, Texte, Typentabellen, Techniken oder Formeln anderer Spiele übernehmen (ip_check, docs/IP_HYGIENE.md)
962. [x] Kein Ball, kein Wurf, kein Gleiten, kein Reiten (Patent-Leitplanken, bestehend) (LEGAL.md, IP_PATENT_AUDIT)
963. [x] Keine sichtbare Fang-Quote (Leitplanke) (BondMinigame zeigt nur Worte)
964. [x] Keine Wisch-Geste zum Fangen (Leitplanke) (Tippen oder Tasten)
965. [ ] Neue Namen gegen bekannte Technik-Listen prüfen
966. [x] IP-Check (bestehend) in CI (ip-check-Job)
967. [x] Kampf-Phrasen in eigener Wortwahl (bestehend Liste) (ip_check-Phrasen, test_ux_text)
968. [x] Kampf-Layout eigenständig (bestehend: Liste statt 2x2) (CommandMenu)
969. [x] Originalitäts-Zahlen fix (bestehend Test) (test_originality)
970. [x] Rechtliche Doku aktualisieren bei neuen Mechaniken (IP_PATENT_AUDIT um Stil Ruhig ergänzt)
971. [x] Mods nur als Inspiration für Genre-Komfort, nie als Quelle (Kopf von KAMPF_PLAN_1000)
972. [x] Ideen-Herkunft im Plan nicht mit fremden Marken benennen (ip_check prüft docs)
973. [x] Kampf-Code bleibt reines Modell ohne Nodes (bestehend) (test_kampf_a11y_tech)
974. [x] Ereignis-basierte Darstellung (bestehend) (BattleEvent, BattleScene)
975. [x] Neue Effekte über EffectRegistry (bestehend) (scripts/battle/effects)
976. [ ] Daten in JSON, nicht im Code
977. [x] Godot 4.7.2 bleibt (test_engine_stays_on_godot_4_7)
978. [ ] Leistung auf älteren Handys prüfen
979. [x] APK-Budget (bestehend) (tools/apk_budget.sh)
980. [ ] Speicher-Budget
981. [x] Kampf-Zustand serialisierbar (BattleReplay.snapshot)
982. [x] Kampf-Replay-Format versioniert (BattleReplay.FORMAT)
983. [x] Kampf-API dokumentiert (docs/KAMPF_TECHNIK.md)
984. [x] Kampf-Code-Review vor jedem Merge (PR-Pflicht, Merge nur grün)
985. [x] Kampf-Tests vor jedem Merge (GUT) (tools/gut_strict.sh in CI)
986. [x] Kampf-Logs ohne personenbezogene Daten (BattleReplay.shareable)
987. [x] Kampf-Daten nicht an Dritte (keine Analyse-SDKs, AGENTS.md)
988. [x] Kampf-Online-Server nur eigener Server (docs/ONLINE.md)
989. [x] Kampf-Fehlerberichte mit Seed (Seed in Replay und Teilcode)
990. [x] Kampf-Code ohne Debug-Ausgaben in Release (test_battle_code_prints_nothing_in_release)
991. [ ] Kampf-Mods der Community später über Datenpakete (kein Code)
992. [ ] Kampf-Datenpakete signiert
993. [ ] Kampf-Editor für Entwickler
994. [x] Kampf-Doku für neue Mitwirkende (docs/KAMPF_TECHNIK.md)
995. [x] Kampf-Roadmap in docs/ROADMAP.md (Abschnitt Kampfsystem)
996. [x] Kampf-Plan regelmäßig aktualisieren (plan_1000.py --check in CI)
997. [x] Kampf-Plan Haken setzen bei Umsetzung (plan_1000.py --check in CI)
998. [x] Kampf-Plan als Quelle für PRs (PRs nennen die Punkte)
999. [x] Kampf-Plan in Deutsch (docs/KAMPF_PLAN_1000.md)
1000. [x] Kampf-Plan im Projektordner gespiegelt (tools/plan/plan_1000.py)

---
751 von 1000 Punkten umgesetzt.

