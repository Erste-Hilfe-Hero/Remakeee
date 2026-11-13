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
20. [ ] Kampfende-Zusammenfassung: Schaden, K.o.s, MVP-Spirling
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
82. [ ] Story-Stufe zeigt alle Matchups von Anfang an (bestehend)
83. [ ] Matchup-Symbole mit Form statt Farbe (bestehend: Elementsymbole) auch im Lexikon
84. [ ] Doppel-Element-Erklärung: beide Faktoren multiplizieren, im Lexikon zeigen
85. [ ] Element-Resonanz: zwei Verbündete mit gleichem Element erhalten +5 % Schaden
86. [ ] Element-Wechsel-Technik: Ziel wird für 3 Runden zu einem anderen Element
87. [ ] Element-Schutz-Gegenstand: halbiert einen sehr effektiven Treffer einmal
88. [ ] Element-Verstärker als gehaltene Gegenstände (+15 % für ein Element)
89. [ ] Neutral-Techniken ohne Element für jeden Spirling
90. [ ] Matchup-Lernen auch durch Lexikon-Einträge (Lore-Seiten)
91. [ ] Elementsymbol am Ziel-Pin im Mehrfachkampf
92. [ ] Effektivitäts-Hinweis im Mehrfachkampf pro Ziel bei der Zielwahl
93. [ ] Element-Balance-Bericht: welches Element gewinnt im Simulator zu oft
94. [ ] Neue Feld-Elemente pro Riss variieren
95. [x] Element-Reaktion: Tide trifft Scorch-Ziel und löscht den Status
96. [x] Element-Reaktion: Volt trifft Soak-Ziel für +20 % Schaden
97. [ ] Element-Reaktion: Ember auf Root-Ziel befreit es, verursacht aber Scorch
98. [ ] Element-Reaktionen im Lexikon erklären
99. [ ] Matchup-Quiz als Minispiel im Leuchtturm
100. [ ] Effektivitäts-Text in eigener Wortwahl (bestehend: 'overwhelming', 'barely landed')
101. [ ] Unwirksam-Treffer (x0) gibt es nicht, nur x0.25 (Designregel festhalten)
102. [ ] Element-Dominanz pro Region als Wild-Spawn-Tabelle
103. [ ] Trait 'Prisma-Haut': nimmt bei x2 nur x1.5
104. [ ] Trait 'Gegenstrom': resistiert das Element, das es zuletzt getroffen hat
105. [ ] Element-Statistik im Kampfende-Bericht
106. [ ] Matchup-Kenntnis wird pro Spielstand gespeichert (bestehend)
107. [ ] Online: Matchup-Wissen teilt sich mit Freunden (Laternenpost-Bonus)
108. [ ] Element-Icons im Hochkontrast-Modus größer
109. [ ] Element-Namen bleiben in allen Sprachen gleich (bestehend)
110. [ ] Element-Tabelle bleibt eigenständig, nie aus anderen Spielen übernehmen (Regel)
111. [ ] Ein Element pro Riss als Thema der Warden
112. [ ] Element-Training: Spark-Werte steigen schneller im passenden Feld
113. [ ] Element-Glyphen animieren beim sehr effektiven Treffer
114. [ ] Element-Mischtechniken (zwei Elemente, nimmt das bessere)
115. [ ] Element-Schild-Technik für das ganze Team (3 Runden)
116. [ ] Elementarer Nachhall: Bonus, wenn zwei Verbündete im selben Zug dasselbe Element nutzen
117. [ ] Element-Rätsel in der Welt, die Kampfwissen belohnen
118. [ ] Element-Filter im Lager
119. [ ] Element-Schwäche-Warnung beim Einwechseln
120. [ ] Gegner-Element im Info-Streifen (bestehend)

## Techniken

121. [x] Resonanz-Techniken: Ash Call, Tide Call und Murk Call legen 5 Runden lang ein Rift-Feld
122. [ ] Feld-Restzüge im Log ansagen und beim Ende melden
123. [ ] Schutz-Technik 'Brace': hält einen Treffer ab, zweimal hintereinander schlägt fehl
124. [ ] Technik mit Rückstoß, die das Ziel auf die Bank zwingt (nur Wayfarer-Kämpfe)
125. [ ] Mehrstufige Technik: lädt eine Runde, trifft dann doppelt
126. [ ] Konter-Technik: wirft physischen Schaden x1.5 zurück
127. [ ] Heil-Technik für Verbündete im Mehrfachkampf
128. [ ] Team-Stufen-Technik (alle Verbündeten DEF +1)
129. [ ] Wurzel-Technik, die Wechsel für 3 Runden blockiert (bestehend: Root)
130. [ ] Technik, die Stufen des Ziels zurücksetzt
131. [ ] Technik, die eigene negative Stufen löscht
132. [ ] Technik mit steigender Stärke bei Wiederholung
133. [ ] Technik, die stärker ist, wenn das Ziel zuerst gehandelt hat
134. [ ] Technik, die stärker ist, wenn der Nutzer zuerst handelt
135. [ ] Technik mit Treffer-Serie (2 bis 4 Treffer)
136. [ ] Technik, die das Feld beendet
137. [ ] Technik, die Status vom ganzen Team heilt
138. [ ] Technik-Lehrer im Leuchtturm (vergessene Techniken neu lernen)
139. [ ] Echo-Kristalle (bestehend) als Quelle seltener Techniken ausbauen
140. [ ] Technik-Tausch-Vorschau: alte und neue Technik nebeneinander
141. [x] Technik-Beschreibung mit Effekt-Chancen im Lexikon
142. [ ] Techniken mit Signatur pro Art (eine je Art, eigenständig)
143. [ ] Keine Technik-Namen aus anderen Spielen (Prüfliste vor jedem Merge)
144. [ ] Status-Techniken mit Genauigkeit unter 100 % sichtbar machen
145. [ ] Technik-Kategorie Physisch/Fokus/Status mit Symbol
146. [ ] Mehrfachziel-Techniken zeigen 'alle' (bestehend)
147. [ ] Technik 'Ablenkung': zieht alle Einzelziele drei Runden auf sich
148. [ ] Technik 'Schulterschluss': schützt einen Verbündeten
149. [ ] Technik 'Nachglut': Schaden über 3 Runden
150. [ ] Technik 'Spiegelung': kopiert die letzte Gegner-Stufenänderung
151. [ ] Technik 'Ruhepunkt': heilt 50 %, Nutzer schläft 1 Runde (Drowse)
152. [ ] Technik 'Druckwelle': trifft alle, auch Verbündete, sehr stark (Risiko-Technik)
153. [ ] Techniken mit Feld-Bedingung (stärker in passendem Feld)
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
180. [ ] Status-Heilung an Rastquellen (bestehend)
181. [ ] Status-Statistik im Kampfende-Bericht
182. [ ] Status-Sound pro Status eigenständig
183. [ ] Status-Text in eigener Wortwahl (Liste gegen übernommene Phrasen, bestehend)
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
197. [ ] Status-Kombos in der Meister-KI nutzen
198. [ ] Status-Clause für Online-Duelle (wie Ruhe-Regel)
199. [x] Status-Dauer pro Schwierigkeit gleich halten (Fairness) (test_kampf_status)
200. [ ] Status-Tutorial beim ersten Status

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
211. [ ] Spark-Reset-Gegenstand
212. [ ] Temperament (bestehend) im Kampf-Info zeigen
213. [x] Werte-Rechner im Lexikon (Lv, Spark, Temperament) (Kampfhandbuch Werte, BattleGuide.calc)
214. [ ] Werte-Vergleich beim Einwechseln
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
229. [ ] Stufen-Sound steigt mit Stufe
230. [ ] Werte-Ansicht als Radar-Grafik im Statusbildschirm
231. [ ] Werte pro Level im Lexikon als Kurve
232. [x] Level-Cap im Menü (bestehend) (PauseMenu Ring limit)
233. [ ] Level-Cap-Hinweis beim XP-Verlust
234. [x] Werte beim Levelaufstieg anzeigen (Zuwachs) (LevelPanel)
235. [ ] Werte-Export für Fans (Teamcode)
236. [ ] Werte-Vorschau bei Entwicklung
237. [x] Gleiche Werte-Formel für Spieler und Gegner (Fairness) (test_kampf_werte)
238. [ ] Werte-Skalierung im Turnier 'Gleiches Level'
239. [x] Werte-Prüfung im Balancing-Test (keine Art dominiert) (type_sim.py --strict)
240. [x] Werte-Formel bleibt eigenständig (Regel) (Spirling.gd, DamageCalc.gd)

## Traits

241. [ ] Trait im Info-Streifen nach der ersten Auslösung zeigen
242. [x] Trait-Auslösung als kurze Meldung im Log
243. [ ] Zweiter Trait für entwickelte Spirlings (wählbar)
244. [ ] Versteckter Trait selten bei Prisma-Spirlings
245. [ ] Trait-Lexikon mit allen Traits
246. [ ] Trait 'Sparflamme' (Energie)
247. [ ] Trait 'Prisma-Haut' (Effektivität)
248. [ ] Trait 'Gegenstrom' (Resistenz)
249. [ ] Trait 'Ruhig' (Status-Heilung beim Wechsel)
250. [ ] Trait 'Glimmhaut' (Kontakt-Scorch)
251. [ ] Trait 'Schwarmgeist': stärker im Mehrfachkampf
252. [ ] Trait 'Einzelgänger': stärker im 1v1
253. [ ] Trait 'Wachposten': erster Zug immer zuerst
254. [ ] Trait 'Feldläufer': doppelte Feld-Boni
255. [ ] Trait 'Echo-Seele': Resonanz-Felder halten 2 Runden länger
256. [ ] Trait 'Dickes Fell' (bestehend Thick Hide) im Lexikon
257. [ ] Trait 'Wurzeln' (bestehend Deep Roots)
258. [ ] Trait 'Last Stand' (bestehend) sichtbar machen, wenn aktiv
259. [ ] Trait-Balance-Bericht
260. [ ] Trait-Wechsel-Gegenstand
261. [ ] KI kennt Traits der Gegner nur, wenn sie aufgedeckt wurden (Fairness)
262. [ ] Meister-KI meidet Status gegen immune Traits (umgesetzt)
263. [ ] Trait-Icons klein neben dem Namen
264. [ ] Trait-Texte übersetzt (bestehend)
265. [ ] Traits in Online-Duellen gleich
266. [ ] Trait-Namen eigenständig prüfen
267. [ ] Traits für Bosse (eigene Boss-Traits)
268. [ ] Trait 'Hush-Kern' für Riss-Bosse: Status halb so lang
269. [ ] Trait 'Laternenlicht': Verbündete erhalten +1 FOC beim Einwechseln
270. [ ] Trait 'Kälteschlaf': Drowse heilt HP
271. [ ] Trait 'Stoßdämpfer': kein Rückstoß
272. [ ] Trait 'Glückspilz': Krit-Chance leicht höher
273. [ ] Trait 'Wendig': Wechsel ist frei (Prioritätsaktion, bestehend)
274. [ ] Trait-Freischaltung durch Bond-Stufe
275. [ ] Traits im Spirlog bei 'bonded'
276. [ ] Trait-Auswirkung im Schadensvorschau-Wert berücksichtigen (bestehend über damage_mult)
277. [ ] Trait-Tests pro Trait
278. [ ] Trait-Kombinationen mit gehaltenen Gegenständen prüfen
279. [ ] Trait 'Sturmlaterne' für den Storm-Lantern-Träger
280. [ ] Trait-Zähler im Kampfende-Bericht

## Gehaltene Gegenstände

281. [ ] Gehaltene Gegenstände (bestehend) im Info-Streifen als Symbol
282. [ ] Element-Verstärker pro Element
283. [ ] Energie-Kristall (+2 Start-Energie)
284. [ ] Schutz-Talisman (einmal sehr effektiven Treffer halbieren)
285. [ ] Fokus-Band in eigener Form: übersteht einen K.o.-Treffer bei vollen HP einmal
286. [ ] Heilbeere-Ersatz in eigener Form: 'Moospolster' heilt 25 % unter 1/3 HP
287. [ ] Status-Beere-Ersatz: 'Klarstein' heilt einen Status einmal
288. [ ] Tempo-Feder: SPD +1 beim Einwechseln
289. [ ] Wahl-Gegenstände bewusst nicht übernehmen (eigene Ideen stattdessen)
290. [ ] Gegenstand 'Laternenglas': Feld-Dauer +2
291. [ ] Gegenstand 'Riss-Splitter': Overcharge +0.05 pro Energie
292. [ ] Gegenstand 'Wanderschuh': Wechsel ist frei
293. [ ] Gegenstände in Turnier-Regeln einzeln sperrbar
294. [ ] Gegner-Wayfarer tragen auf Veteran Gegenstände
295. [ ] Gegenstand-Info im Lexikon
296. [ ] Gegenstand-Verbrauch in Kampfende-Bericht
297. [ ] Gegenstand nach dem Kampf automatisch wieder ausrüsten (Option)
298. [ ] Gegenstand-Tausch im Kampf (kostet den Zug)
299. [ ] Gegenstand-Klau-Technik bewusst nicht einführen (Frust)
300. [ ] Gegenstand-Shop im Endgame
301. [ ] Gegenstand als Belohnung im Turm
302. [ ] Gegenstand-Seltenheit sichtbar
303. [ ] Gegenstand-Balance im Simulator
304. [ ] Gegenstand-Icons eigenständig (Asset-Log)
305. [ ] Gegenstand-Namen eigenständig prüfen
306. [ ] Gehaltene Gegenstände in Online-Duellen gleich
307. [ ] Gegenstand-Sets pro Spirling speichern
308. [ ] Gegenstand 'Echo-Muschel': Bond-Chance +5 % beim Halter
309. [ ] Gegenstand 'Ruhekerze': +1 Energie beim Rasten
310. [ ] Gegenstand 'Glutstein' für Ember-Felder
311. [ ] Gegenstand 'Gezeitenstein' für Tide-Felder
312. [ ] Gegenstand 'Dämmerstein' für Umbra-Felder
313. [ ] Gegenstand-Effekte im Schadensvorschau-Wert
314. [ ] Gegenstand-Hinweis beim Ausrüsten (was es tut)
315. [ ] Gegenstand-Limit: jeder Gegenstand nur einmal pro Team in Turnieren
316. [ ] Gegenstand-Fund in versteckten Orten (bestehend)
317. [ ] Gegenstand-Tests pro Gegenstand
318. [ ] Gegenstand-Animation beim Auslösen
319. [ ] Gegenstand-Sound beim Auslösen
320. [ ] Gegenstand-Texte übersetzt

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
493. [ ] Herausforderungs-Abzeichen auf der Wayfarer-Karte (online)
494. [x] Schwierigkeit jederzeit senkbar, nie anhebbar (Fairness für Ranglisten) (ChallengeRules.ranked_difficulty, Lauf-Chronik)
495. [x] Schwierigkeit pro Kampf anzeigen (Kampfstart-Zeile challenge_line)
496. [ ] Gegner-Level-Skalierung optional
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
507. [ ] Speedrun-Timer (Option)
508. [x] Seed-Anzeige für Zufallsmodi (ChallengeMenu)
509. [x] Teilen eines Seeds mit Freunden (ChallengeMenu, Seed-Code kopieren und einfügen)
510. [x] Wochen-Herausforderung (bestehend) mit Regeln (bestehend: WeeklyChallenge mit Feld, Regel und Variante)
511. [x] Turm-Herausforderung (bestehend) mit Stufen (bestehend: EchoTower mit 100 Stockwerken)
512. [ ] Gauntlet (bestehend) mit Rangliste
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
529. [ ] Wayfarer-Telefonbuch-Ersatz: Laternenpost-Einladungen
530. [ ] Wayfarer-Rangliste lokal
531. [ ] Wayfarer-Belohnungen variieren
532. [x] Wayfarer-Teamgröße bis 5 (Team 5 fix) (bestehend: GameState.MAX_PARTY, TrainerData.RIFT_BORN_MAX_TEAM)
533. [x] Wayfarer-Level an Level-Cap gebunden (bestehend: TrainerData.build_team mit ring_cap + FOE_OVER_CAP)
534. [x] Wayfarer mit gehaltenen Gegenständen auf Veteran (bestehend: TrainerData.keeps_keepsakes ab Veteran)
535. [ ] Wayfarer-Teams prüfen auf Dopplungen
536. [ ] Wayfarer-Sprites eigenständig
537. [x] Wayfarer-Namen eigenständig (bestehend: tools/ip_check.sh)
538. [x] Wayfarer-Klassen eigenständig (keine bekannten Klassen übernehmen) (bestehend: tools/ip_check.sh)
539. [ ] Wayfarer-Begegnung per Blickkontakt bewusst anders lösen (Ansprechen oder Signal-Laterne)
540. [ ] Wayfarer-Signal vor dem Kampf (Laterne blinkt)
541. [ ] Wayfarer-Kampf überspringbar nach erstem Sieg (Rückkampf)
542. [ ] Wayfarer-Statistik im Lexikon
543. [ ] Wayfarer im Online-Weltziel
544. [ ] Wayfarer-Echos von Freunden
545. [ ] Wayfarer-Team-Builder für Testzwecke
546. [ ] Wayfarer-Balancing im Simulator
547. [x] Wayfarer-KI-Persönlichkeiten (bestehend: data/ai_profiles.json)
548. [ ] Wayfarer-Gruppen-Kämpfe (2 Wayfarer gegen Spieler + Kestra)
549. [x] Wayfarer mit Boss-Spirling (bestehend: boss-Schlüssel in TrainerData)
550. [x] Wayfarer-Turm mit 50 Stockwerken (bestehend: EchoTower mit 100 Stockwerken)
551. [x] Wayfarer-Turm Belohnungen (bestehend: Gauntlet.REWARDS und Waymarks)
552. [x] Wayfarer-Turm Regeln pro Stockwerk (bestehend: Regel-Varianten pro Stockwerk)
553. [ ] Wayfarer-Turm Rangliste online
554. [ ] Wayfarer-Daten validieren (validate_data)
555. [x] Wayfarer-Texte übersetzt (bestehend: test_i18n)
556. [x] Wayfarer-Teams pro Schwierigkeit (bestehend: teams_by_difficulty)
557. [ ] Wayfarer-Geld-Belohnungen balancieren
558. [ ] Wayfarer mit Overcharge-Strategie
559. [ ] Wayfarer mit Bond-Lehre (Tutorial)
560. [ ] Wayfarer-Kampfmusik pro Gebiet

## Info und Transparenz

561. [x] Schadensvorschau im Technik-Menü (~% HP), nur wenn das Matchup schon bekannt ist
562. [ ] Schadensvorschau als Einstellung abschaltbar
563. [ ] Schadensvorschau pro Ziel im Mehrfachkampf
564. [x] Technik-Info per langem Druck
565. [ ] Kampflog (bestehend) mit Filter
566. [ ] Gegner-Info-Seite im Kampf (Traits, bekannte Techniken)
567. [ ] Gegner-Techniken werden bekannt, sobald sie benutzt wurden
568. [ ] Matchup-Lexikon
569. [ ] Werte-Rechner
570. [ ] Kampfregeln-Seite
571. [ ] Zugreihenfolge-Vorschau
572. [ ] Energie-Vorschau
573. [ ] Status-Dauer-Anzeige
574. [ ] Feld-Restzüge-Anzeige
575. [ ] Bank-Anzeige
576. [ ] Gegenstand-Anzeige
577. [x] Trait-Anzeige nach Auslösung
578. [ ] XP-Vorschau nach dem Kampf
579. [ ] Level-Cap-Anzeige
580. [ ] Bond-Chance bewusst ohne Zahlen-Anzeige (Patent-Leitplanke: keine Fang-Quote)
581. [ ] Kampfende-Bericht
582. [ ] Replay-Ansicht (bestehend)
583. [ ] Lexikon-Suche
584. [ ] Tipps beim ersten Kontakt (bestehend)
585. [ ] Tipps zu neuen Funktionen (Resonanz, Phasen)
586. [ ] Info-Texte in eigener Wortwahl
587. [ ] Info-Texte übersetzt
588. [ ] Info für Screenreader
589. [ ] Info im Hochkontrast
590. [ ] Info-Bildschirm bei 144 px Breite lesbar
591. [ ] Info-Kürzel einheitlich (ATK/DEF/FOC/SPD)
592. [ ] Info: Krit-Treffer als 'keen hit' (bestehend, eigene Wortwahl)
593. [ ] Info: Effektivität als x2/x.5 (bestehend)
594. [ ] Info: Mehrfachziel als 'all' (bestehend)
595. [ ] Info: Priorität als Pfeil
596. [x] Info: Genauigkeit als Prozent
597. [ ] Info: Kategorie-Symbol
598. [ ] Info: Boss-Phasen-Marken
599. [ ] Info: Regel-Banner bei Warden
600. [ ] Info: Seed im Log

## Bedienung und Komfort

601. [ ] Tempo 1x/2x/4x (bestehend)
602. [ ] Auto-Kampf für Wildkämpfe (bestehend)
603. [ ] Letzten Zug wiederholen
604. [ ] Rückgängig vor Zugstart
605. [ ] Technik-Favoriten
606. [ ] Technik-Reihenfolge
607. [ ] Schnell-Heilen nach dem Kampf (Gegenstand-Vorschlag)
608. [ ] Schnell-Wechsel per Wischen bewusst nicht (Patent-Leitplanke: kein Swipe)
609. [x] Langer Druck für Info
610. [ ] Gamepad-Steuerung (bestehend)
611. [ ] Einhand-Modus (bestehend)
612. [ ] Links-Hand-Modus (bestehend)
613. [ ] Tastatur-Kürzel 1 bis 4 für Techniken
614. [ ] Ziel-Wahl per Tippen auf das Sprite
615. [ ] Ziel merken
616. [ ] Auto-Ziel
617. [ ] Kampf-Text per Tippen überspringen
618. [ ] Kampf-Text automatisch weiter (Option)
619. [ ] Batteriesparen (bestehend)
620. [ ] Vibrations-Feedback (bestehend rumble)
621. [ ] Einstellungen im Kampf erreichbar
622. [ ] Kampf-Menü-Höhe fest (bestehend)
623. [ ] Große Knöpfe-Option
624. [ ] Bestätigung bei riskanten Aktionen (Rückzug in Boss-Kampf nicht möglich)
625. [ ] Wechsel-Liste mit HP und Matchup
626. [ ] Gegenstand-Liste mit Wirkung
627. [ ] Lager-Lernen-Option (umgesetzt) im Kampfmenü erklärt
628. [ ] Gegner-Bank-Punkte
629. [ ] Kampf-Wiederaufnahme nach Unterbrechung
630. [ ] Schnellspeichern im Kampf bewusst nicht (kein Savescum auf Rift-Born)
631. [ ] Komfort-Tipps beim ersten Kampf
632. [ ] Kampf-Steuerung ohne Zeitdruck (keine Echtzeit-Elemente)
633. [ ] Bond-Melodie (bestehend) mit Barrierefreiheit
634. [ ] Kampf-UI bei 144x256 skaliert
635. [ ] Kampf-UI im Querformat bewusst nicht
636. [ ] Kampf-UI mit Safe-Area (bestehend)
637. [ ] Kampf-UI Fokus-Navigation per Gamepad
638. [ ] Kampf-UI Screenreader-Texte
639. [ ] Kampf-UI Text-Geschwindigkeit (bestehend)
640. [ ] Kampf-UI Testfälle

## Tempo, Animation und Präsentation

641. [ ] Animationen pro Element eigenständig
642. [ ] Animationen kürzer bei 2x/4x (bestehend Speed-Scale)
643. [ ] Weniger Bewegung (bestehend) schaltet Wackeln ab
644. [ ] Treffer-Pause beim Krit
645. [ ] Kamera-Zoom beim Boss-Phasenwechsel
646. [ ] Feld-Tönung im Hintergrund
647. [ ] Status-Partikel
648. [ ] Stufen-Aura
649. [ ] K.o.-Animation eigenständig (Verblassen statt Umfallen)
650. [ ] Einwechsel-Animation eigenständig (Laternenlicht statt Ball)
651. [ ] Kein Ball, kein Wurf (Leitplanke)
652. [ ] Sprite-Atmen im Leerlauf
653. [ ] Sprite-Reaktion auf Treffer
654. [ ] Siegespose
655. [ ] Boss-Größe
656. [ ] Mehrfachkampf-Formation (bestehend)
657. [ ] Kampf-Übergang pro Ära
658. [ ] Kampf-Hintergrund pro Gebiet (bestehend Backdrop)
659. [ ] Kampf-Hintergrund Tag/Nacht
660. [ ] Kampf-Intro kürzer bei Rückkämpfen
661. [ ] Kampf-Outro mit Bericht
662. [ ] Fotomodus im Kampf (bestehend)
663. [ ] Replay mit Tempo-Wahl
664. [ ] Animation-Budget pro Frame (Handy)
665. [ ] Animation ohne Blitz-Effekte (Epilepsie-Sicherheit)
666. [ ] Animation-Tests im Screenshot-Werkzeug
667. [ ] Pixel-Perfect bleibt bei Effekten
668. [ ] Effekte in Ära-Palette
669. [ ] Effekte mit Hochkontrast-Variante
670. [ ] Effekte im Asset-Log
671. [ ] Treffer-Zahlen optional einblenden
672. [ ] Schadenszahl in Weiß mit Tintenrand
673. [ ] HP-Balken-Tween (bestehend)
674. [ ] Energie-Pips-Animation
675. [ ] Feld-Banner beim Start
676. [ ] Phasen-Banner beim Boss
677. [ ] Regel-Banner beim Warden
678. [ ] Partner-Banner bei Kestra
679. [ ] Kampf-Ende-Banner
680. [ ] Präsentation bleibt eigenständig (kein bekanntes Layout)

## Audio im Kampf

681. [ ] Treffer-Sounds pro Element (bestehend)
682. [ ] Krisen-Musik bei wenig HP (bestehend)
683. [ ] Boss-Phasen-Musik
684. [ ] Feld-Klangteppich
685. [ ] Status-Sounds
686. [ ] Stufen-Sounds steigend
687. [ ] Overcharge-Sound steigend
688. [ ] Resonanz-Klang beim Feld-Start
689. [ ] Feld-Ende-Klang
690. [ ] Schrei pro Spirling (bestehend)
691. [ ] Sieges-Jingle
692. [ ] Niederlagen-Jingle
693. [ ] Bond-Melodie
694. [ ] Lautstärke Musik/SFX getrennt (bestehend)
695. [ ] Audio-Ducking bei Text
696. [ ] Audio-Hinweise für Blinde (Effektivität als Ton)
697. [ ] Audio-Test-Raum (bestehend Sound-Test)
698. [ ] Audio im Asset-Log
699. [ ] Audio eigenständig komponiert
700. [ ] Audio-Budget für APK
701. [ ] Audio bei 4x kürzer
702. [ ] Audio im Batteriesparmodus reduziert
703. [ ] Audio-Variation pro Ära
704. [ ] Audio für Mehrfachkampf nicht überladen
705. [ ] Audio für Boss-Intro
706. [ ] Audio für Warden-Regel
707. [ ] Audio für Partner
708. [ ] Audio für Ruhe-Regel-Fehlschlag
709. [ ] Audio für Schadensvorschau (kein Ton)
710. [ ] Audio-Tests (bestehend)
711. [ ] Audio-Fade beim Kampfende
712. [ ] Audio-Loop sauber
713. [ ] Audio-Nacht-Variante
714. [ ] Audio-Fest-Variante
715. [ ] Audio-Wochen-Echo-Thema
716. [ ] Audio-Turm-Thema
717. [ ] Audio-Online-Duell-Thema
718. [ ] Audio: Treffer-Lautstärke nach Schaden
719. [ ] Audio: Krit-Akzent
720. [ ] Audio: Feld-Wechsel-Akzent

## Fortschritt, XP und Training

721. [x] Lager-Lernen: Spirlings auf der Bank erhalten die Hälfte der XP (Einstellung, Standard an)
722. [ ] XP-Verteilung im Kampfende-Bericht
723. [ ] Level-Cap blockiert XP (bestehend)
724. [ ] Spark-Training (bestehend) mit Kampfquellen
725. [ ] Technik-Lehrer
726. [ ] Entwicklung nach Kampf (bestehend)
727. [ ] Entwicklung abbrechen (Option)
728. [ ] Temperament-Wechsel-Gegenstand
729. [ ] Spark-Reset
730. [ ] XP-Bonus für Rückkämpfe
731. [ ] XP-Bonus für Bond-Spirlings
732. [ ] XP-Malus bei Überlevel bewusst nicht
733. [ ] XP-Kurve dokumentieren
734. [ ] XP-Kurve im Simulator prüfen
735. [ ] XP-Anzeige bei Bank-Spirlings
736. [ ] Training-Arena im Leuchtturm
737. [ ] Trainings-Dummies (Spirlings aus Holz) für Tests
738. [ ] Trainings-Kämpfe ohne Risiko
739. [ ] Trainings-Ziele (Quests)
740. [ ] Trainings-Statistik
741. [ ] Level-Aufstieg-Zusammenfassung bei mehreren Levels
742. [ ] Lern-Technik-Dialog überspringbar
743. [ ] Lern-Technik später nachholen
744. [ ] XP für Partner-Spirlings nie (bestehend)
745. [ ] XP in Online-Duellen nie (Fairness)
746. [ ] XP auf Story höher
747. [ ] XP-Glücksbringer als gehaltener Gegenstand
748. [ ] XP-Zusammenfassung pro Gebiet
749. [ ] Level-Cap-Erhöhung nach Riss (bestehend)
750. [ ] Level-Cap in Turnieren
751. [ ] Lager-Lernen nur für das Team, nicht für das Lager
752. [ ] Lager-Lernen respektiert Level-Cap (umgesetzt)
753. [ ] Lager-Lernen für erschöpfte Spirlings nicht (umgesetzt)
754. [ ] Lager-Lernen in den Einstellungen (umgesetzt)
755. [ ] Lager-Lernen im Lexikon erklären
756. [ ] Training: Wochen-Echo gibt Spark
757. [ ] Training: Feste geben Spark
758. [ ] Training: Turm gibt Gegenstände
759. [ ] Training: Online-Weltziel gibt XP-Bonus
760. [ ] Training: kein Grind-Zwang (Balance-Ziel)

## Wild-Begegnungen und Bond

761. [ ] Bond-Echo-Melodie (bestehend) bleibt ohne Wurf und ohne Quote
762. [ ] Bond nur gegen Wild (bestehend)
763. [ ] Bond im Schwarm (bestehend)
764. [ ] Bond-Bonus durch Status (bestehend prüfen)
765. [ ] Bond-Bonus durch Feld
766. [ ] Bond-Bonus durch Gegenstand Echo-Muschel
767. [ ] Bond-Fehlschlag gibt freie Aktion (bestehend)
768. [ ] Bond-Erfolg-Animation eigenständig
769. [ ] Wild-Begegnungen im Farn, Schilf, Geröll (bestehend)
770. [ ] Wild-Ketten-Bonus (Prisma-Chance steigt)
771. [ ] Wild-Schwarm-Ereignisse
772. [ ] Wild-Spawns nach Tageszeit (bestehend)
773. [ ] Wild-Spawns nach Feld
774. [ ] Wild-Auto-Kampf (bestehend)
775. [ ] Wild-Level an Gebiet
776. [ ] Wild-KI Stufe 0 (bestehend)
777. [ ] Wild-Überraschung
778. [ ] Wild-Rückzug-Regel (bestehend)
779. [ ] Wild-Spirlings mit Gegenständen (selten)
780. [ ] Wild-Begegnungs-Rate einstellbar (Laterne)
781. [ ] Wild-Abwehr-Gegenstand
782. [ ] Wild-Lockmittel
783. [ ] Wild-Prisma-Varianten (bestehend)
784. [ ] Wild-Seltenheit sichtbar im Spirlog
785. [ ] Wild-Spawn-Tabellen validieren
786. [ ] Bond-Melodie barrierefrei (visuell + Ton)
787. [ ] Bond-Melodie Schwierigkeit pro Art
788. [ ] Bond-Ergebnis ohne Prozentzahl (Leitplanke)
789. [ ] Bond-Statistik im Lexikon
790. [ ] Bond-Tests (bestehend)
791. [ ] Wild-Horde mit Anführer
792. [ ] Wild-Horde-Bond
793. [ ] Wild-Boss (seltene alte Spirlings) im Endgame
794. [ ] Wild-Begegnung im Nebel (Sicht begrenzt)
795. [ ] Wild-Begegnung nachts häufiger
796. [ ] Wild-Begegnung im Riss mit Feld
797. [ ] Wild-Begegnung als Tageshighlight (bestehend Find of the Day)
798. [ ] Wild-Begegnung Online-Echo
799. [ ] Wild-Begegnung Wochen-Spawn
800. [ ] Wild-Begegnung Fest-Spawn

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

881. [ ] Screenreader-Texte im Kampf (bestehend Grundlagen)
882. [ ] Hochkontrast (bestehend)
883. [ ] Weniger Bewegung (bestehend)
884. [ ] Große Schrift-Option
885. [ ] Farbenblind-sichere Symbole (bestehend Formen)
886. [ ] Ton-Hinweise für Effektivität
887. [ ] Vibrations-Hinweise
888. [ ] Einhand-Modus (bestehend)
889. [ ] Keine Zeitlimits offline
890. [ ] Text-Geschwindigkeit (bestehend)
891. [ ] Auto-Text weiter
892. [ ] Bond-Melodie ohne Rhythmus-Zwang (Option 'Ruhig')
893. [ ] Schadensvorschau hilft beim Planen
894. [ ] Kampflog vorlesen
895. [ ] Fokus-Navigation
896. [ ] Knopfgrößen
897. [ ] Kontrast der HP-Leiste
898. [ ] Status-Kürzel lesbar
899. [ ] Feld-Banner lesbar
900. [ ] Boss-Phasen-Banner lesbar
901. [ ] Untertitel für Schreie
902. [ ] Leichte Sprache-Option für Kampftexte
903. [ ] Deutsch und Englisch (bestehend)
904. [ ] Weitere Sprachen vorbereiten
905. [ ] Barrierefreiheit-Tests
906. [ ] Barrierefreiheit-Dokumentation
907. [ ] Barrierefreiheit im Store-Text
908. [ ] Eingabe-Verzögerung einstellbar
909. [ ] Doppeltipp vermeiden
910. [ ] Wisch-Gesten vermeiden (Leitplanke und Zugänglichkeit)
911. [ ] Lange Drücke optional
912. [ ] Pausen jederzeit
913. [ ] Blitzfreie Effekte
914. [ ] Audio-Mono-Option
915. [ ] Lautstärke pro Kanal
916. [ ] Kampf ohne Ton spielbar
917. [ ] Kampf ohne Farbe spielbar
918. [ ] Kampf mit Gamepad spielbar
919. [ ] Kampf mit Tastatur spielbar
920. [ ] Kampf mit Screenreader spielbar

## Balance-Werkzeuge und Tests

921. [x] Tests für Meister-KI, Resonanz-Felder, Boss-Phasen, Ruhe-Regel, Lager-Lernen, Schadensvorschau
922. [ ] Balancing-Simulator (bestehend) mit Meister-KI
923. [ ] Simulator-Bericht pro Element
924. [ ] Simulator-Bericht pro Technik
925. [ ] Simulator-Bericht pro Trait
926. [ ] Simulator-Bericht pro Gegenstand
927. [ ] Simulator-Bericht pro Feld
928. [ ] Simulator-Bericht pro Schwierigkeit
929. [ ] CI-Wächter für Gewinnraten (bestehend)
930. [ ] Daten-Validierung (bestehend) für neue Felder
931. [ ] Daten-Validierung für Boss-Phasen
932. [ ] Replay-Regressionstests
933. [ ] Seed-Determinismus-Test
934. [ ] Speicherstand-Migration (bestehend) für neue Einstellungen
935. [ ] Einstellungs-Migration (Lager-Lernen Standard an)
936. [ ] Leistungs-Test der KI
937. [ ] Screenshot-Tests für Kampf-UI
938. [ ] i18n-Prüfung (bestehend) für neue Texte
939. [ ] IP-Prüfung (bestehend) für neue Namen
940. [ ] Originalitäts-Zahlen (bestehend) nicht verändern
941. [ ] Balance-Dokumentation aktualisieren
942. [ ] Balancing-Ziele pro Gebiet
943. [ ] Balancing: Anfänger-Spirlings gleich stark
944. [ ] Balancing: keine Pflicht-Spirlings
945. [ ] Balancing: jede Technik hat einen Zweck
946. [ ] Balancing: Status nicht zu stark
947. [ ] Balancing: Felder nicht zu stark
948. [ ] Balancing: Bosse fair
949. [ ] Balancing: Meister-KI fordernd, nicht unfair
950. [ ] Balancing: Story leicht
951. [ ] Balancing: Veteran fordernd
952. [ ] Balancing: Rift-Born hart
953. [ ] Balancing: Online fair
954. [ ] Balancing: Endgame lang
955. [ ] Balancing-Tests in CI
956. [ ] Fuzz-Test: zufällige Aktionen 10.000 Züge ohne Fehler
957. [x] Fuzz-Test für Mehrfachkämpfe
958. [x] Fuzz-Test für Bosse
959. [x] Fuzz-Test für Felder
960. [ ] Fuzz-Test für Online-Echos

## Originalität, Recht und Technik

961. [ ] Keine Namen, Texte, Typentabellen, Techniken oder Formeln anderer Spiele übernehmen
962. [ ] Kein Ball, kein Wurf, kein Gleiten, kein Reiten (Patent-Leitplanken, bestehend)
963. [ ] Keine sichtbare Fang-Quote (Leitplanke)
964. [ ] Keine Wisch-Geste zum Fangen (Leitplanke)
965. [ ] Neue Namen gegen bekannte Technik-Listen prüfen
966. [ ] IP-Check (bestehend) in CI
967. [ ] Kampf-Phrasen in eigener Wortwahl (bestehend Liste)
968. [ ] Kampf-Layout eigenständig (bestehend: Liste statt 2x2)
969. [ ] Originalitäts-Zahlen fix (bestehend Test)
970. [ ] Rechtliche Doku aktualisieren bei neuen Mechaniken
971. [ ] Mods nur als Inspiration für Genre-Komfort, nie als Quelle
972. [ ] Ideen-Herkunft im Plan nicht mit fremden Marken benennen
973. [ ] Kampf-Code bleibt reines Modell ohne Nodes (bestehend)
974. [ ] Ereignis-basierte Darstellung (bestehend)
975. [ ] Neue Effekte über EffectRegistry (bestehend)
976. [ ] Daten in JSON, nicht im Code
977. [ ] Godot 4.7.2 bleibt
978. [ ] Leistung auf älteren Handys prüfen
979. [ ] APK-Budget (bestehend)
980. [ ] Speicher-Budget
981. [ ] Kampf-Zustand serialisierbar
982. [ ] Kampf-Replay-Format versioniert
983. [ ] Kampf-API dokumentiert
984. [ ] Kampf-Code-Review vor jedem Merge
985. [ ] Kampf-Tests vor jedem Merge (GUT)
986. [ ] Kampf-Logs ohne personenbezogene Daten
987. [ ] Kampf-Daten nicht an Dritte
988. [ ] Kampf-Online-Server nur eigener Server
989. [ ] Kampf-Fehlerberichte mit Seed
990. [ ] Kampf-Code ohne Debug-Ausgaben in Release
991. [ ] Kampf-Mods der Community später über Datenpakete (kein Code)
992. [ ] Kampf-Datenpakete signiert
993. [ ] Kampf-Editor für Entwickler
994. [ ] Kampf-Doku für neue Mitwirkende
995. [ ] Kampf-Roadmap in docs/ROADMAP.md
996. [ ] Kampf-Plan regelmäßig aktualisieren
997. [ ] Kampf-Plan Haken setzen bei Umsetzung
998. [ ] Kampf-Plan als Quelle für PRs
999. [ ] Kampf-Plan in Deutsch
1000. [ ] Kampf-Plan im Projektordner gespiegelt

---
319 von 1000 Punkten umgesetzt.

