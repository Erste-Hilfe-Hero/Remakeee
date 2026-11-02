# Chimora · Design-Epochen (500-Punkte-Plan)

Stand: 2. November 2026. Gilt ab dem Zeitpunkt, an dem das Grundspiel fertig und veröffentlicht ist.

Chimora soll sich nach dem Release über mehrere Teile hinweg sichtbar weiterentwickeln: jede neue Region bringt eine neue Zeichentechnik und eine reichere Grafik. Die Epochen bauen auf dem Era-System aus AGENTS.md auf (Ink, Wash, Etched, Panorama) und ergänzen eine fünfte Stufe.

| Epoche | Technik | Region | Interne Auflösung | Kampf-Sprite | Farben pro Sprite | Leitsatz |
| --- | --- | --- | --- | --- | --- | --- |
| I | Tinte (Ink) | Veydal | 144×256 | 56×56, 2 Frames Idle | 4 fest | Die Welt wird gezeichnet |
| II | Lavur (Wash) | Corvane | 144×256 | 56×56, 3 Frames Idle | 4, Tag/Nacht per LUT | Die Welt bekommt Farbe |
| III | Radierung (Etched) | Ashmere | 180×320 | 64×64, 4 Frames Idle | 16 | Die Welt bekommt Struktur |
| IV | Panorama | Solenne | 270×480 | 96×96, 6 Frames Idle | 32, 2.5D | Die Welt bekommt Weite |
| V | Lichtkarte (neu) | Lumhall (Arbeitstitel) | 360×640 | 128×128, 8 Frames Idle | 64 + Normalmaps | Die Welt bekommt Licht |

Spielwerte bleiben in jeder Epoche gleich. Jede freigeschaltete Epoche bleibt als Retro-Filter wählbar.

## Teil A · Leitidee und Schutzregeln

Chimora wächst nach dem Grundspiel in fünf Design-Epochen. Jede Epoche bringt eine neue Region, eine neue Zeichentechnik und eine sichtbar reifere Grafik. Die Klammer kommt aus der eigenen Geschichte: Die Spielfigur ist Kartografin oder Kartograf, und mit jeder Epoche lernt sie eine neue Art, die Welt zu zeichnen. Von Tinte über Lavur und Radierung bis zum Panorama und zuletzt zur Lichtkarte. Übernommen wird nur das allgemeine Prinzip "Grafik wird von Teil zu Teil reicher", keine fremden Designs, Paletten, Auflösungen als Zitat oder Abläufe.

1. Jede Epoche ist an eine Kartentechnik gebunden, nicht an Hardware-Generationen anderer Spiele.
2. Die fünf Epochen heißen Tinte, Lavur, Radierung, Panorama und Lichtkarte; die Namen bleiben im Spiel, im Code und im Marketing gleich.
3. Keine Epoche darf das Aussehen einer bekannten Handheld-Ära nachbilden (kein Grünstich-Display, keine typischen Rahmen, keine Fremd-Paletten).
4. Epoche I bleibt die Pergament-Tintenpalette aus dem Originalitäts-PR (2a1e2c, 6a4256, c48a5e, f2e3c2) und ist der Anker aller späteren Paletten.
5. Jede neue Palette wird aus Chimoras eigenen Materialien abgeleitet (Pergament, Tinte, Wasserfarbe, Kupferplatte, Leinwand, Laternenlicht).
6. Spirling-Silhouetten bleiben über alle Epochen erkennbar; ein Kind muss den Spirling in jeder Epoche wiedererkennen.
7. Keine Epoche führt Mechaniken ein, die AGENTS.md oder LEGAL.md verbieten (kein Fliegen oder Gleiten, kein Wurf-Fang, keine Arenen, keine Abzeichen).
8. Für jede Epoche gibt es eine IP-Prüfliste, die vor dem Release abgehakt wird.
9. Alle Assets bleiben selbst erstellt oder sauber lizenziert und stehen in docs/ASSET_LOG.md.
10. tools/ip_check.sh läuft auf jedem Epochen-PR; neue Begriffe aus Fremdwerken kommen in die Sperrliste.
11. Spielerinnen und Spieler behalten jede freigeschaltete Epoche als Retro-Filter; niemand verliert einen Look, den er mag.
12. Ein Epochenwechsel darf keinen Spielstand brechen; Saves sind epochenunabhängig.
13. Spielwerte (Stats, Schaden, Energie) ändern sich durch eine Epoche nie; Design ist reine Darstellung.
14. Jede Epoche hat ein eigenes Design-Dokument (Stilbibel) mit Palette, Raster, Linienregeln und Beispielen.
15. Jede Epoche hat einen klaren Lieferumfang: Region, Spirling-Sprites, Tiles, Figuren, UI, Kampf, Effekte, Audio-Feinschliff.
16. Eine Epoche wird erst begonnen, wenn die vorige vollständig ausgeliefert und stabil ist.
17. Rückwärtskompatibilität: alte Regionen bekommen den neuen Look optional, nicht zwangsweise.
18. Jede Epoche hat ein Gesicht: einen Leit-Spirling für Plakat, Store-Bild und Ladebildschirm.
19. Die Weiterentwicklung soll sich verdient anfühlen: man sieht den Sprung in der Welt, nicht nur im Menü.
20. Lesbarkeit auf kleinem Hochkant-Bildschirm geht immer vor Detail.
21. Leistung geht vor Effekt: jede Epoche muss auf dem schwächsten Zielgerät mit 60 Bildern pro Sekunde laufen.
22. Jede Epoche bekommt ein festes Speicherbudget für Texturen.
23. Barrierefreiheit (Farbenblind-Modi, Kontrast, Schriftgröße) wird pro Epoche neu geprüft.
24. Neue Kreaturen entstehen aus Chimoras eigener Welt-Logik (Rifts, Stille, Kartografie), nicht aus Tier-plus-Element-Formeln.
25. Kein Design darf an eine bekannte Kreatur erinnern; jede Neuschöpfung durchläuft einen Ähnlichkeits-Check gegen große Monster-Franchises.
26. Farbgebung von Elementen bleibt eigen und wird nicht an gängige Feuer-rot, Wasser-blau-Konventionen angelehnt, wo es vermeidbar ist.
27. Die Story erklärt jede Epoche: die Kartografen-Gilde lehrt eine neue Technik, sobald eine Region geheilt ist.
28. Jede Epoche erhält ein eigenes Titellogo-Detail (Tintenklecks, Pinselstrich, Kupferstich-Rahmen, Leinwandkante, Laternenschein).
29. Alle Entscheidungen zur Ästhetik werden in docs/EPOCHS.md (dieses Dokument) und den Stilbibeln festgehalten.
30. Der Plan startet erst, wenn das Grundspiel (Veydal komplett, Online-Basis, Store-Release) fertig ist.

## Teil B · Technisches Fundament

31. EraManager in EpochManager umbenennen oder einen Alias anlegen, damit Code und Doku dieselbe Sprache sprechen.
32. Epochen als Daten beschreiben: data/epochs.json mit Name, Auflösung, Sprite-Größe, Farbanzahl, Shader, UI-Theme.
33. Sprite-Suche mit Fallback-Kette: art/epochN/ → art/epoch(N-1)/ → … → art/epoch1/.
34. Fallback im Spiel sichtbar machen (Debug-Overlay), damit fehlende Assets früh auffallen.
35. Paletten-Shader als Lookup-Textur (LUT) bauen, damit eine Epoche die Farben ohne neue Sprites wechseln kann.
36. Ein gemeinsamer Paletten-Index pro Sprite, damit Tag und Nacht nur die LUT tauschen.
37. Interne Auflösung pro Epoche über SubViewport steuern; die Ausgabe wird ganzzahlig skaliert.
38. Ganzzahliges Skalieren mit Rand füllen (Pergament-Rahmen) statt zu verzerren.
39. Pixel-Snapping und Nearest-Filter für Epochen I–IV fest einschalten; Epoche V darf Unterpixel-Kamera nutzen.
40. UI-Theme pro Epoche als eigene Godot-Theme-Ressource.
41. Schrift pro Epoche: eigene Bitmap-Schriften, selbst gezeichnet, mit deutschen Umlauten und ß.
42. Animations-Framework vereinheitlichen: SpriteFrames-Ressourcen pro Spirling und Epoche.
43. Kampfszene in Schichten zerlegen (Hintergrund, Boden, Spirlings, Effekte, UI), damit Epochen einzelne Schichten aufwerten können.
44. Effekt-System auf Daten umstellen (data/vfx.json), damit jede Technik pro Epoche eine eigene Darstellung bekommt.
45. Kamera-System vorbereiten: feste Kamera (I–II), leichtes Nachziehen (III), Parallaxe (IV), Tiefe und Licht (V).
46. TileMapLayer-Sets pro Epoche mit identischer Terrain-Logik, damit Karten nicht neu gebaut werden müssen.
47. Kollisions- und Begegnungsdaten von der Grafik trennen; Epochen tauschen nur Grafik-Layer.
48. Asset-Generatoren (tools/art/*.py) pro Epoche erweitern statt neu schreiben.
49. Ein Werkzeug, das ein Epoche-I-Sprite automatisch als Vorlage für Epoche II hochskaliert (nur als Skizze für Handarbeit).
50. Paletten-Validator: prüft, dass jedes Sprite nur Farben seiner Epochenpalette nutzt.
51. Größen-Validator: prüft Sprite-Maße pro Epoche (56, 56, 64, 96, 128).
52. Frame-Validator: prüft Anzahl und Länge von Animationsframes.
53. Screenshot-Werkzeug (tools/screenshot.gd) um einen Epochen-Parameter erweitern.
54. Vergleichsbilder: dieselbe Szene in allen freigeschalteten Epochen nebeneinander als CI-Artefakt.
55. Textur-Budget pro Epoche in der CI prüfen (APK-Größenbudget erweitern).
56. Optionale Asset-Pakete: neue Epochen als nachladbare Pakete, damit die App klein bleibt.
57. Server liefert nur Pakete aus, die der Spieler freigeschaltet hat (Online-Basis nutzen).
58. Prüfsummen für nachgeladene Pakete, damit nichts Fremdes geladen wird.
59. Offline-Cache für einmal geladene Epochen-Pakete.
60. Speicherstand speichert nur Epochen-Freischaltung und gewählten Filter, keine Grafikdaten.
61. Save-Migration testen: alter Stand lädt in jeder neuen Epoche fehlerfrei.
62. GUT-Tests für EpochManager: Wechsel, Fallback, Filter, Freischaltung.
63. Leistungstest pro Epoche auf einem Referenz-Android-Gerät der Einstiegsklasse.
64. Leistungstest pro Epoche auf dem ältesten unterstützten iPhone.
65. Akkuverbrauch messen; Epoche V bekommt einen Energiesparmodus.
66. Shader-Fallback für GL Compatibility, falls ein Effekt auf alten Geräten fehlt.
67. Einstellung "Effekte reduzieren" für alle Epochen.
68. Einstellung "Bewegung reduzieren" (keine Parallaxe, kein Wackeln).
69. Lokalisierung: neue Texte jeder Epoche laufen durch die i18n-Pipeline (Deutsch, Englisch).
70. Bild-Texte (Schilder, Karten-Beschriftung) als Text-Ebene statt in Pixel gemalt, damit sie übersetzbar bleiben.
71. Design-Tokens (Farben, Abstände, Radien) pro Epoche als Datei, damit UI und Marketing gleich aussehen.
72. Eine Testszene "Epochen-Galerie" im Debug-Menü, die alle Spirlings in allen Epochen zeigt.
73. Automatischer Ähnlichkeits-Check: neue Spirling-Silhouetten gegen die eigene Sammlung (keine Doppelungen).
74. Versionsschema: Spielversion X.Y mit Epoche als Hauptnummer (1.x Tinte, 2.x Lavur …).
75. Feature-Flags pro Epoche, damit fertige Teile früh intern getestet werden können.
76. Rollback-Plan: eine Epoche lässt sich serverseitig ausblenden, falls ein Fehler auftaucht.
77. Crash-Reporting nach Epoche aufschlüsseln.
78. Pipeline-Doku in docs/ART_PIPELINE.md pro Epoche fortschreiben.
79. Jede Epoche bekommt ein eigenes Kapitel in docs/ASSET_LOG.md.
80. Kontrollierte Werkzeuge: Aseprite oder LibreSprite für Pixel, Krita für Skizzen, alles mit eigenen Dateien im Repo unter art_src/.

## Epoche I · Tinte (Grundspiel, Region Veydal)

Ziel: der fertige Ausgangspunkt. Tinte auf Pergament, 4 Farben, 144×256, Kampf-Sprites 56×56. Diese Epoche wird nicht neu erfunden, sondern zu Ende poliert, damit der spätere Sprung sichtbar ist.

81. Stilbibel Tinte schreiben: Linienstärke 1 px, Schraffur statt Verlauf, Pergamentkörnung als Hintergrund.
82. Palette festschreiben: 4 Töne, keine Ausnahmen, auch nicht im UI.
83. Alle Spirlings in Veydal auf einheitliche Linienführung prüfen.
84. Rückansichten auf gleiche Qualität wie Vorderansichten bringen.
85. Zwei-Frame-Idle für jeden Spirling (Atmen, Blinzeln) im Kampf.
86. Ein Ein-Frame-Treffer-Pose pro Spirling.
87. Kleines Overworld-Sprite (16×16) für Begleiter-Spirlings, falls Begleiter-Funktion kommt.
88. Tileset Veydal: Farn, Schilf, Geröll, Terrassen und Leuchtturm einheitlich schraffieren.
89. Wasser in Tinte: wandernde Wellenlinien statt Farbflächen.
90. Nacht in Tinte: Schraffur dichter statt Farbe dunkler.
91. Figuren (Aldo, Kestra, Hüterinnen und Hüter) mit erkennbaren Umrissen und je einem markanten Detail.
92. Porträts für Dialoge (32×32) in Tinte für alle Hauptfiguren.
93. Dialogbox als Kartenrand mit Tintenklecks-Ecke.
94. Menü als aufgeklapptes Notizbuch.
95. Kampf-UI: eine HP-Linie pro Spirling, Warnung durch Schraffur, nicht durch Farbe.
96. Energieanzeige als Tintentropfen.
97. Technik-Liste einspaltig mit Kategorie-Symbol in Tinte.
98. Treffer-Effekte als Tintenspritzer, kritische Treffer als größerer Klecks.
99. Element-Effekte nur über Form unterscheiden (Funken, Tropfen, Blatt, Wirbel), da es nur 4 Farben gibt.
100. Kampfhintergründe pro Gelände: Wiese, Moor, Klippe, Höhle, Rift.
101. Rift-Darstellung: Riss im Pergament, der die Karte "zerreißt".
102. Die Stille als ausgebleichte, leere Pergamentfläche zeigen.
103. Kartenansicht im Menü wächst sichtbar mit jedem entdeckten Ort (Kern-Motiv der Epochenidee).
104. Leuchtturm-Lampe als einziger Glanzpunkt der Epoche (heller Pergamentton).
105. Titelbild Tinte: Leuchtturm, drei Starter-Silhouetten, Tintenfeder.
106. Ladebildschirm: Feder zeichnet eine Linie.
107. Übergang Overworld → Kampf: Tinte läuft über das Bild.
108. Übergang Kampf → Overworld: Tinte trocknet zurück.
109. Wetter in Tinte: Regen als kurze Striche, Nebel als Punktierung.
110. Pixel-genaue Schrift Tinte mit Umlauten, Ziffern und Symbolen.
111. Achievements-Symbole im Tintenstil.
112. Spirling-Lexikon: jede Seite wie eine Feldskizze mit Notizen.
113. Sammelkarten-Darstellung (Tamer-Karte) im Tintenstil.
114. Fotomodus mit Rahmen "Feldskizze".
115. Spielstand-Bildschirm zeigt die gezeichnete Karte als Vorschau.
116. Alle Tinte-Assets mit tools/art neu erzeugbar halten.
117. Alle Spirlings im Ähnlichkeits-Check gegen fremde Kreaturen erneut prüfen.
118. Lesbarkeitstest auf 5-Zoll-Bildschirm im Sonnenlicht.
119. Farbenblind-Test (die 4 Töne müssen sich in Helligkeit klar unterscheiden).
120. Store-Screenshots Tinte aufnehmen (Hochkant, beide Stores).
121. App-Icon in Tinte: Leuchtturm-Silhouette mit Tintenklecks.
122. Ein kurzer Trailer aus Spielszenen in Tinte.
123. Pressekit-Seite für Epoche I.
124. Spielerfeedback zum Look sammeln (Umfrage im Spiel, freiwillig).
125. Auswertung: welche Spirlings am beliebtesten sind (für Leit-Spirlings späterer Epochen).
126. Liste der Assets, die in Epoche II wiederverwendet werden (Formen, Animationen).
127. Code-Aufräumen: keine fest verdrahteten Farben mehr außerhalb der Palette.
128. Debug-Overlay "Palettenverstoß" einschalten und alle Fehler beheben.
129. Abschluss-Ritual im Spiel: Nach dem letzten Rift in Veydal überreicht die Gilde den ersten Pinsel. Das ist der Aufhänger für Epoche II.
130. Teaser im Spiel: eine einzelne Farbwolke am Horizont von Veydal.
131. Abnahme Epoche I: alle Punkte grün, keine Fallbacks im Debug-Overlay.
132. Rückblick schreiben: was hat in Tinte gut funktioniert, was nicht.
133. Stilbibel Tinte als PDF in docs/ ablegen.
134. Grundlagen-Test: Spieler können alle Elemente ohne Farbe unterscheiden.
135. Messung der Ladezeiten als Basis für spätere Epochen.
136. Speicherbedarf der Texturen notieren (Basiswert).
137. Alle Tinte-Quellen (art_src/epoch1) ins Repo.
138. Freigabe Tinte als Retro-Filter für alle späteren Regionen.
139. Tag "epoch-1-final" im Git setzen.
140. Release-Notiz Tinte schreiben (Deutsch und Englisch).

## Epoche II · Lavur (Wasserfarbe, Region Corvane)

Ziel: Farbe kommt in die Welt, aber zurückhaltend. Lavierte Wasserfarbe über Tintenlinien. 144×256, Kampf-Sprites 56×56, 4 Farben pro Sprite plus eigene Tag- und Nachtpalette. Der Sprung heißt: "Die Welt bekommt Farbe."

141. Stilbibel Lavur schreiben: Tintenlinie bleibt, Farbe sitzt als Fläche darunter und darf über die Linie "auslaufen".
142. Grundpalette Lavur ableiten: 16 Töne gesamt, jeder Sprite nutzt 4 davon.
143. Palettenfarben aus Corvanes Landschaft ableiten (Krähenschwarz, Flussgrün, Rost, Herbstgold).
144. Pro Spirling eine Farbkarte mit 4 festen Tönen.
145. Tagespalette und Nachtpalette über LUT, ohne neue Sprites.
146. Dämmerungspalette als Übergang (Abend und Morgen).
147. Alle Veydal-Spirlings bekommen eine Lavur-Version.
148. Neue Corvane-Spirlings direkt in Lavur entwerfen.
149. Lavur-Versionen behalten die Tinte-Silhouette pixelgenau.
150. Seltene Farbvarianten über Palettentausch statt eigener Sprites.
151. Farbvarianten bekommen ein eigenes Erkennungszeichen (kleiner Pinselstrich-Rand im Lexikon).
152. Idle-Animation auf 3 Frames erweitern.
153. Angriffspose pro Spirling (1 Frame).
154. Overworld-Begleiter in 4 Farben.
155. Tileset Corvane: Krähenwald, Flussauen, Ruinen, Marktstadt.
156. Wasser in Lavur: verlaufende Blautöne mit Tintenwellen darüber.
157. Jahreszeiten-Paletten für Corvane (Herbst als Standard, Winter als Event).
158. Figuren in Lavur: jede Hauptfigur bekommt eine Erkennungsfarbe.
159. Aldo und Kestra auch in Lavur-Versionen für Rückblenden.
160. Dialogporträts mit 2 Gesichtsausdrücken.
161. Dialogbox als Aquarellpapier mit Farbrand.
162. Menü als Skizzenbuch mit Farbreitern.
163. Element-Symbole erhalten eigene Farben (eigenes Schema, nicht die üblichen Konventionen).
164. HP-Linie in einer Farbe, Warnung durch Farbwechsel ins Rostrot.
165. Energieanzeige als Farbtropfen, die sich füllen.
166. Kampfhintergründe mit 2 Ebenen (Himmel und Boden).
167. Kampfboden als Farbfleck statt fester Plattform.
168. Treffer-Effekte als Farbspritzer in Elementfarbe.
169. Status-Effekte bekommen Farbtönungen auf dem Spirling.
170. Rift-Darstellung: Farbe läuft aus dem Riss heraus wie nasse Farbe.
171. Die Stille entzieht Farbe: Bereiche werden zurück zu Tinte (starker Kontrast zur neuen Epoche).
172. Heilen eines Rifts füllt die Gegend sichtbar mit Farbe; das ist der Kernmoment der Epoche.
173. Wetter: Regen verwischt die Farbe leicht, Sonne lässt sie leuchten.
174. Licht: einfache Farbaufhellung um Laternen.
175. Übergang in den Kampf: Farbtropfen fällt ins Wasser und breitet sich aus.
176. Titelbild Lavur: Krähenwald im Herbst, Leit-Spirling der Epoche.
177. Leit-Spirling Lavur aus den Corvane-Neuheiten wählen.
178. Lexikon in Lavur: Seiten wie Aquarell-Studien.
179. Karte im Menü wird in Corvane farbig laviert.
180. Tamer-Karte mit farbigem Rahmen je nach Lieblingselement.
181. Schrift Lavur: gleiche Pixelschrift, aber farbige Überschriften.
182. UI-Animationen: Menüs "fließen" auf statt hart einzuklappen.
183. Fotomodus-Rahmen "Aquarellblatt".
184. Retro-Filter: Spieler können Corvane auch in Tinte spielen.
185. Retro-Filter: Veydal in Lavur spielbar, sobald Corvane erreicht wurde.
186. Vergleichsansicht im Menü: dieselbe Szene in Tinte und Lavur.
187. Leistungstest: LUT-Wechsel ohne Ruckler.
188. Farbenblind-Modi für alle Lavur-Paletten (Deuteranopie, Protanopie, Tritanopie).
189. Kontrastprüfung jeder Spirling-Palette gegen jeden Kampfhintergrund.
190. Paletten-Validator auf 4 Farben pro Sprite erweitern.
191. Asset-Generator: Tinte-Sprite plus Farbkarte ergibt Lavur-Rohling.
192. Handkorrektur jedes Rohlings, keine rein automatischen Assets im Release.
193. Ähnlichkeits-Check der neuen Farbgebung gegen fremde Kreaturen (Farbe kann Ähnlichkeit erzeugen).
194. Corvane-Story: die Gilde lehrt das Lavieren, nachdem der erste Rift geheilt ist.
195. Gilden-Szene als Zwischensequenz in Lavur.
196. Musik-Feinschliff: weichere Instrumente passend zur Farbe.
197. Soundeffekte: Pinselstrich-Geräusch für Menüs.
198. Store-Screenshots Lavur.
199. App-Icon bekommt eine Lavur-Variante (Leuchtturm mit Farbschein).
200. Trailer "Die Welt bekommt Farbe" (Tinte wird zu Lavur).
201. Ankündigung im Spiel über die Online-Neuigkeiten.
202. Community-Wettbewerb: Lieblings-Spirling in Lavur malen (eigene Fan-Art, klare Nutzungsregeln).
203. Event "Farbenfest" zum Start der Epoche.
204. Weltziel: gemeinsam Corvanes Rifts heilen, Belohnung ist eine besondere Lavur-Farbvariante.
205. Speicherbudget Lavur messen und gegen Ziel prüfen.
206. Ladezeiten mit Tinte vergleichen.
207. Spieler-Umfrage: Tinte oder Lavur, was wird mehr genutzt.
208. Fehlerliste aus der Umfrage abarbeiten.
209. Stilbibel Lavur abschließen.
210. Quellen in art_src/epoch2.
211. Alle neuen Assets in ASSET_LOG.md.
212. Rückblick Lavur schreiben.
213. Release-Notiz Lavur.
214. Tag "epoch-2-final".
215. Abschluss-Ritual: die Gilde überreicht die Radiernadel.
216. Teaser: Kupferglanz im Gebirge am Rand von Corvane.
217. Abnahme Epoche II.

## Epoche III · Radierung (Kupferstich, Region Ashmere)

Ziel: Detail und Tiefe durch feine Linien. Kupferstich-Ästhetik mit 16 Farben pro Sprite. Interne Auflösung 180×320, Kampf-Sprites 64×64. Der Sprung heißt: "Die Welt bekommt Struktur."

218. Stilbibel Radierung schreiben: feine Kreuzschraffur, Metallglanz, gezielte Farbflächen.
219. Grundpalette Radierung: 48 Töne gesamt, 16 pro Sprite.
220. Palettenquellen: Kupfer, Grünspan, Asche, Glut, Schiefer (Ashmere ist ein Vulkan- und Bergbau-Hochland).
221. Auflösungswechsel auf 180×320 sauber umsetzen (UI neu anordnen, nicht strecken).
222. Alle bisherigen Spirlings in 64×64 neu zeichnen.
223. Neue Ashmere-Spirlings in Radierung entwerfen.
224. Silhouetten der Tinte-Version bleiben als Grundform erkennbar.
225. Mehr Details erlaubt: Muster im Fell, Gravuren auf Panzern, Augenglanz.
226. Idle-Animation 4 Frames.
227. Angriffs-Animation 3 Frames.
228. Treffer-Animation 2 Frames.
229. Spezielle Einstiegsanimation pro Spirling beim Kampfbeginn.
230. Rückansichten mit eigener Idle-Animation.
231. Overworld-Begleiter mit 4-Richtungs-Laufanimation.
232. Tileset Ashmere: Stollen, Schmieden, Ascheterrassen, Lavaflüsse, Kupferstädte.
233. Tiles mit Variationen (3 pro Grundtile), damit Flächen nicht gekachelt wirken.
234. Animierte Tiles: Glut, Dampf, Wasserräder, Förderbänder.
235. Lichtzonen: Glut erhellt Umgebung über Paletten-Aufhellung.
236. Tag-Nacht in 4 Stufen.
237. Figuren mit 4 Laufrichtungen und 3 Frames.
238. Neue Figurenrollen: Bergleute, Graveure, Schmiede als Nebenfiguren.
239. Dialogporträts mit 4 Ausdrücken.
240. Dialogbox als gravierte Kupferplatte.
241. Menü als Mappe mit Druckplatten.
242. Kampf-UI: Statusfelder als gravierte Plaketten.
243. HP-Linie mit feiner Schraffur bei niedrigem Wert.
244. Energieanzeige als Funken in einer Gravur.
245. Technik-Liste mit kleinen gestochenen Symbolen.
246. Kampfhintergründe mit 3 Ebenen und leichter Bewegung (Rauch, Asche).
247. Kampfboden gezeichnet wie ein Druck mit Schatten.
248. Spirling-Schatten als Schraffur unter den Füßen.
249. Effekte mit 6 bis 10 Frames, pro Element eigene Bewegungsform.
250. Kritischer Treffer: kurzer Druckplatten-Blitz (Bild wird kurz zum Negativ).
251. Status-Symbole über dem Spirling als gestochene Icons.
252. Rift-Darstellung: Riss in der Kupferplatte, Linien verbiegen sich.
253. Die Stille ätzt Linien weg: Gegenstände verlieren Details.
254. Heilen eines Rifts: Linien werden neu gestochen, Details kehren zurück.
255. Kamera zieht beim Laufen leicht nach.
256. Kamera-Zoom in Zwischensequenzen.
257. Übergang in den Kampf: Druckpresse senkt sich, Bild wird "gedruckt".
258. Wetter: Ascheregen, Hitzeflimmern (abschaltbar), Bergnebel.
259. Partikel-System für Funken und Asche, mit Obergrenze pro Szene.
260. Lexikon wie ein gedruckter Atlas mit Querschnitt-Zeichnungen.
261. Karte im Menü als Kupferstich mit Höhenlinien.
262. Tamer-Karte mit graviertem Rahmen und Prägung.
263. Neue Pixelschrift Radierung, etwas feiner, weiter gut lesbar.
264. Fotomodus-Rahmen "Druckblatt" mit Plattenrand.
265. Retro-Filter: Ashmere in Tinte und Lavur spielbar.
266. Veydal und Corvane in Radierung spielbar, sobald freigeschaltet.
267. Größen-Validator auf 64×64 erweitern.
268. Paletten-Validator auf 16 Farben pro Sprite erweitern.
269. Animations-Validator prüft Frameanzahl pro Spirling.
270. Leistungstest mit Partikeln und animierten Tiles auf schwachem Gerät.
271. Textur-Atlas pro Region, um Draw Calls zu senken.
272. Nachladbares Paket für Radierung-Assets.
273. Farbenblind-Modi für alle neuen Paletten.
274. Kontrastprüfung bei feinen Linien (Mindestabstand der Helligkeit).
275. Ashmere-Story: die Gilde lehrt das Stechen von Platten, damit Karten haltbar werden.
276. Zwischensequenz in der Großen Presse von Ashmere.
277. Musik: metallische Perkussion, tiefere Bässe.
278. Soundeffekte: Gravur-Kratzen für Menüs, Pressenschlag bei Übergängen.
279. Leit-Spirling Radierung aus den Ashmere-Neuheiten.
280. Titelbild Radierung: Kupferstich von Ashmere mit Leit-Spirling.
281. Store-Screenshots Radierung.
282. Trailer "Die Welt bekommt Struktur".
283. Event "Schmiedewoche" mit Radierung-Varianten.
284. Weltziel: gemeinsame Druckplatte, die alle Spieler füllen.
285. Spieler-Umfrage zur Lesbarkeit der feinen Linien.
286. Nachbesserungen aus der Umfrage.
287. Stilbibel Radierung abschließen.
288. Quellen in art_src/epoch3.
289. ASSET_LOG.md ergänzen.
290. Rückblick Radierung.
291. Release-Notiz Radierung.
292. Tag "epoch-3-final".
293. Abschluss-Ritual: die Gilde überreicht eine Leinwand.
294. Teaser: weiter Horizont mit Meer am Rand von Ashmere.
295. Abnahme Epoche III.

## Epoche IV · Panorama (Leinwand, Region Solenne)

Ziel: Weite und Bewegung. Gemalte Leinwand-Ästhetik, 32 Farben pro Sprite, interne Auflösung 270×480, Kampf-Sprites 96×96 mit 6-Frame-Idle, 2.5D-Tiefe über SubViewport. Der Sprung heißt: "Die Welt bekommt Weite."

296. Stilbibel Panorama schreiben: weiche Pinselkanten in Pixeln, Luftperspektive, Leinwandstruktur.
297. Grundpalette Panorama: 96 Töne gesamt, 32 pro Sprite.
298. Palettenquellen: Meer, Salzwiesen, Abendhimmel, Kalkfelsen (Solenne ist eine Küstenregion).
299. Auflösungswechsel auf 270×480 mit neuem UI-Raster.
300. Alle bisherigen Spirlings in 96×96 neu zeichnen.
301. Neue Solenne-Spirlings in Panorama entwerfen.
302. Silhouetten weiter wiedererkennbar, Proportionen dürfen reifer werden.
303. Idle-Animation 6 Frames.
304. Angriffs-Animation 4 Frames pro Kategorie (körperlich, Fernkampf, Status).
305. Treffer- und Ausweich-Animation.
306. Einstiegsanimation mit kurzem Laufweg ins Bild.
307. Abschluss-Pose beim Sieg.
308. Rückansichten mit 6-Frame-Idle.
309. 2.5D-Kampfbühne: Spirlings stehen auf einer Ebene mit Tiefe, Kamera schwenkt leicht.
310. Kamerabewegungen pro Technik (Heranzoomen, Seitenschwenk), abschaltbar.
311. Kampfhintergründe mit 4 bis 5 Parallaxe-Ebenen.
312. Lebende Hintergründe: Wolken, Wellen, Vogelschwärme aus eigenen Designs.
313. Effekte mit Überblendung und Leuchten (additiv), 10 bis 16 Frames.
314. Element-Effekte bekommen eine eigene Signatur-Bewegung (Spirale, Welle, Splitter, Strahl).
315. Tileset Solenne: Klippen, Leuchtfeuer, Salzwiesen, Hafenstadt, Unterwasser-Ruinen.
316. Overworld mit Parallaxe-Hintergrund (Meer und Himmel bewegen sich langsamer).
317. Höhenebenen auf der Karte sichtbar (Terrassen werfen Schatten).
318. Licht und Schatten pro Tageszeit mit weichen Übergängen.
319. Wasserreflexionen von Figuren und Spirlings.
320. Wetter: Seewind (Gras und Wäsche bewegen sich), Sturm, Sonnenuntergang.
321. Figuren mit 8 Laufrichtungen oder 4 Richtungen mit flüssigen 6 Frames.
322. Figuren-Animationen für Emotionen (Winken, Erschrecken, Lachen).
323. Dialogporträts als Halbfiguren mit 6 Ausdrücken.
324. Wichtige Szenen als gemalte Standbilder (Panoramen) in voller Auflösung.
325. Dialogbox als Leinwandstreifen mit Holzrahmen.
326. Menü als Atelier mit Staffeleien.
327. Kampf-UI mit weichen Animationen und klaren Zahlen.
328. Statusanzeige mit kleinen animierten Symbolen.
329. Rift-Darstellung: Leinwand reißt, dahinter ist rohe Grundierung zu sehen.
330. Die Stille bleicht Farben aus, bis nur die Vorzeichnung bleibt.
331. Heilen eines Rifts: Pinselstriche malen die Landschaft live neu.
332. Übergang in den Kampf: Pinselstrich wischt über das Bild.
333. Lexikon wie ein Bildband mit Lebensraum-Gemälden.
334. Lexikon zeigt jeden Spirling in allen freigeschalteten Epochen nebeneinander.
335. Karte im Menü als Panorama-Gemälde, das sich beim Zoomen in Detailkarten auflöst.
336. Tamer-Karte als kleine Leinwand mit Lieblings-Spirling in Pose.
337. Neue Schrift Panorama mit höherer Pixel-Auflösung.
338. Fotomodus mit Kamerawinkel, Tiefenschärfe und Rahmen "Leinwand".
339. Retro-Filter für alle früheren Epochen auch in Solenne.
340. Ältere Regionen in Panorama spielbar, sobald freigeschaltet.
341. Größen-Validator 96×96, Animations-Validator 6 Frames Idle.
342. SubViewport-Leistung prüfen; bei schwachen Geräten automatisch weniger Parallaxe-Ebenen.
343. Textur-Kompression pro Plattform (ETC2, ASTC) prüfen.
344. Nachladbares Paket Panorama, getrennt nach Regionen.
345. Speicherbudget prüfen, alte Epochen-Pakete bei Bedarf entladen.
346. Farbenblind-Modi und Kontrastprüfung für weiche Kanten.
347. Barrierefreiheit: Effekte mit starkem Blinken entschärfen (Lichtempfindlichkeit).
348. Solenne-Story: die Gilde lehrt das Malen weiter Ansichten, Kestras Weg wird verständlicher.
349. Große Zwischensequenz am Leuchtfeuer von Solenne.
350. Musik: volleres Arrangement, Meeresklänge.
351. Soundeffekte: Pinsel, Leinwand, Wind.
352. Leit-Spirling Panorama aus den Solenne-Neuheiten.
353. Titelbild Panorama: Küstenpanorama im Abendlicht.
354. Store-Screenshots und kurze Store-Videos Panorama.
355. Trailer "Die Welt bekommt Weite".
356. Event "Gezeitenfest" mit Panorama-Varianten.
357. Weltziel: gemeinsames Panorama, das sich mit den Beiträgen aller Spieler füllt.
358. Spieler-Umfrage zu Kamera und Effekten.
359. Nachbesserungen aus der Umfrage.
360. Stilbibel Panorama abschließen.
361. Quellen in art_src/epoch4.
362. ASSET_LOG.md ergänzen.
363. Rückblick Panorama.
364. Release-Notiz Panorama.
365. Tag "epoch-4-final".
366. Abschluss-Ritual: die Gilde überreicht eine Laterne mit Prisma.
367. Teaser: Licht aus dem Inneren eines Rifts, das nicht bedrohlich wirkt.
368. Unterwasser-Abschnitte mit eigener Lichtbrechung über Palette.
369. Spirling-Gruppen im Hintergrund (Herden am Strand) als lebendige Kulisse.
370. Ein Fotomodus-Wettbewerb pro Saison mit Panorama-Motiven.
371. Kampf-Wiederholungen (Replays) nutzen die neue Kamera.
372. Neue Zwischensequenz-Werkzeuge (Timeline-Szenen) für gemalte Panoramen.
373. Panorama-Version des App-Icons.
374. Pressekit Panorama mit Vorher-nachher-Bildern aller vier Epochen.
375. Abnahme Epoche IV.

## Epoche V · Lichtkarte (Laternenlicht, neue fünfte Region)

Ziel: Licht als Gestaltungsmittel. Hochaufgelöste Pixelkunst mit dynamischer Beleuchtung, interne Auflösung 360×640, Kampf-Sprites 128×128, 64 Farben pro Sprite. Diese Epoche ist neu und steht noch nicht in AGENTS.md. Der Sprung heißt: "Die Welt bekommt Licht."

376. AGENTS.md um Epoche V ergänzen (Auflösung, Sprite-Größe, Farben, Technik).
377. Arbeitsname der fünften Region: Lumhall, ein Archipel aus Inseln, die zwischen den Rifts schweben und nur bei Tag zu Fuß über Lichtbrücken erreichbar sind (kein Fliegen, kein Gleiten).
378. Rechtsprüfung der Lichtbrücken-Mechanik im Legal-Thread, bevor sie gebaut wird.
379. Stilbibel Lichtkarte schreiben: Pixelkunst plus Normalmaps, Licht formt die Szene.
380. Grundpalette Lichtkarte: 64 Töne pro Sprite, Licht wird über Shader gemischt.
381. Palettenquellen: Laternenbernstein, Mondsilber, Rift-Violett, Nachtblau.
382. Auflösungswechsel auf 360×640 mit neuem UI-Raster.
383. Alle Spirlings in 128×128 neu zeichnen, mit Normalmap pro Sprite.
384. Neue Lumhall-Spirlings mit eigenem Leuchten (Emissions-Maske).
385. Silhouetten bleiben wiedererkennbar, auch im Gegenlicht.
386. Idle 8 Frames, Angriff 6 Frames, Treffer 3 Frames, Sieg 6 Frames.
387. Lichtreaktion: Spirlings werden von Effekten der Gegner angeleuchtet.
388. Kampfbühne mit dynamischen Lichtquellen (Laternen, Effekte, Himmel).
389. Schatten, die sich mit Lichtquellen bewegen.
390. Effekte als Lichtereignisse: Techniken erhellen die ganze Szene kurz.
391. Element-Lichtfarben aus der eigenen Palette, nicht aus fremden Schemas.
392. Kamerafahrten für besondere Techniken, abschaltbar.
393. Overworld mit Godot-2D-Lichtern (PointLight2D) und Okkludern.
394. Laterne der Spielfigur als echte Lichtquelle in Höhlen und bei Nacht.
395. Tag-Nacht fließend über die echte Uhrzeit (optional).
396. Wetter mit Licht: Gewitter erhellt Szenen, Nebel streut Licht.
397. Tileset Lumhall: Glasgärten, Sternwarten, Lichtbrücken, Rift-Kristalle.
398. Tiles mit Normalmaps für Lichtwirkung.
399. Unterpixel-Kamera für weiche Bewegung, Sprites bleiben auf Pixelraster.
400. Figuren mit Normalmaps und 8 Laufrichtungen.
401. Dialogporträts in hoher Auflösung mit animierten Augen und Mund.
402. Dialogbox als Lichtkarte mit leuchtendem Rand.
403. Menü als Kartentisch mit Laterne, Licht folgt dem Fokus.
404. Kampf-UI mit leichtem Glimmen bei wichtigen Werten.
405. Rift-Darstellung: Licht wird hineingesogen, Ränder flackern.
406. Die Stille als Dunkelheit, die Laternen schwächer macht.
407. Heilen eines Rifts: alle Lichter der Gegend gehen nacheinander an.
408. Übergang in den Kampf: Laterne flammt auf und füllt das Bild.
409. Lexikon als leuchtender Atlas, Spirlings drehbar im Licht.
410. Karte im Menü als Lichtkarte, die alle fünf Regionen in ihrer jeweiligen Epoche zeigt.
411. Große Gesamtkarte: Veydal in Tinte, Corvane in Lavur, Ashmere in Radierung, Solenne in Panorama, Lumhall in Licht. Das ist der Abschluss der Reise als ein Bild.
412. Tamer-Karte mit Licht-Glanz und Prägung.
413. Neue Schrift Lichtkarte mit hoher Auflösung, weiter in Pixelstil.
414. Fotomodus mit freier Lichtquelle.
415. Retro-Filter: Lumhall in jeder früheren Epoche spielbar (Licht wird dort durch Palette simuliert).
416. Ältere Regionen in Lichtkarte spielbar, sobald freigeschaltet.
417. Leistungsstufen: Licht hoch, mittel, aus.
418. Energiesparmodus senkt Lichtquellen und Bildrate in Menüs.
419. Normalmap-Generator als Hilfswerkzeug, Handkorrektur Pflicht.
420. Validatoren für 128×128, Normalmaps und Emissions-Masken.
421. Nachladbares Paket Lichtkarte, aufgeteilt nach Region.
422. Ältere Geräte bekommen automatisch Panorama als Höchststufe.
423. Farbenblind-Modi für Lichtfarben.
424. Lichtempfindlichkeit: kein schnelles Flackern, Prüfung nach gängigen Richtlinien.
425. Lumhall-Story: die Gilde zeigt, dass Karten nicht nur Orte, sondern auch Licht festhalten. Kestra und die Spielfigur zeichnen die letzte Karte gemeinsam.
426. Finale Zwischensequenz: alle Epochen blättern wie Seiten eines Atlas durch.
427. Musik: Leitmotive aller Regionen kehren arrangiert zurück.
428. Soundeffekte: Glas, Glocken, Laternenzischen.
429. Leit-Spirling Lichtkarte.
430. Titelbild Lichtkarte: Lumhall bei Nacht, Laternen über den Inseln.
431. Store-Screenshots, Store-Videos und neues App-Icon.
432. Trailer "Die Welt bekommt Licht", der alle fünf Epochen zeigt.
433. Event "Laternennacht" mit Licht-Varianten.
434. Weltziel: alle Spieler entzünden gemeinsam die Laternen von Lumhall.
435. Spieler-Umfrage zur Lichtstärke und Lesbarkeit.
436. Nachbesserungen aus der Umfrage.
437. Stilbibel Lichtkarte abschließen.
438. Quellen in art_src/epoch5.
439. ASSET_LOG.md ergänzen.
440. Rückblick Lichtkarte.
441. Release-Notiz Lichtkarte.
442. Tag "epoch-5-final".
443. Tiefenwirkung durch Licht statt echter 3D-Modelle; Chimora bleibt Pixelkunst.
444. Licht-Rätsel in Lumhall (Laternen umstellen, Schatten lenken), rein am Boden lösbar.
445. Glühende Spirling-Varianten nur bei Nacht sichtbar.
446. Leucht-Signaturen der Spirlings auch in der Overworld (Begleiter erhellt Umgebung).
447. Kampf-Replays mit freier Lichtquelle.
448. Pressekit Lichtkarte mit Zeitstrahl aller fünf Epochen.
449. Jubiläums-Ausgabe: Artbook mit allen Stilbibeln als digitales Extra.
450. Abnahme Epoche V.

## Teil C · Übergänge, Retro-Filter und Spielerbindung

451. Epochenwechsel als Spielmoment: kurze Zwischensequenz, in der die Gilde die neue Technik übergibt.
452. Beim ersten Betreten einer neuen Region verwandelt sich der Bildschirm von der alten in die neue Epoche.
453. Retro-Filter-Menü: Liste aller freigeschalteten Epochen mit Vorschau.
454. Filter pro Region einstellbar (z. B. Veydal immer in Tinte).
455. Filter für Kämpfe getrennt von der Overworld einstellbar.
456. Schnellwechsel des Filters im Fotomodus.
457. Epochen-Mischung als Belohnung: Spirling-Sprite einer Epoche in einer anderen Region zeigen.
458. Sammelziel "Epochen-Atlas": jeden Spirling in jeder Epoche gesehen haben.
459. Achievements pro Epoche (z. B. alle Rifts einer Region geheilt).
460. Epochen-Abzeichen sind ausdrücklich keine Arena-Abzeichen, sondern Stempel im Kartenbuch.
461. Tamer-Karte zeigt die höchste erreichte Epoche als Rahmen.
462. Freunde sehen Tamer-Karten in ihrer eigenen gewählten Epoche dargestellt.
463. Geschenke zwischen Freunden zeigen den Spirling in der Epoche des Absenders.
464. Echos anderer Spieler erscheinen im Stil ihrer Epoche, als kleiner Hinweis auf ihren Fortschritt.
465. Weltziele pro Epoche verknüpfen die Community mit dem Stilwechsel.
466. Neuigkeiten-Seite im Spiel kündigt Epochen früh an.
467. Keine Bezahlschranke: alle Epochen sind Teil des Premium-Kaufs oder kostenlose Updates.
468. Falls je ein Erweiterungskauf kommt, gilt er für ganze Regionen, nie für einzelne Grafik-Looks.
469. Neue Spieler können nach Abschluss von Veydal jede bereits veröffentlichte Epoche normal erreichen.
470. Neues-Spiel-Plus startet in der höchsten freigeschalteten Epoche, optional.
471. Speedrun- und Retro-Modus: ganzes Spiel in Tinte spielbar.
472. Hilfe-Seite erklärt Epochen in einfacher Sprache.
473. Einstellungs-Assistent wählt bei schwachen Geräten automatisch eine passende Epoche.
474. Die Spielfigur und ihr Notizbuch entwickeln sich mit: das Notizbuch-Menü wird mit jeder Epoche aufwendiger.
475. Die Kleidung der Spielfigur zeigt die gelernten Techniken (Tintenfleck, Farbschürze, Graviernadel, Pinselgürtel, Laterne).
476. Begleiter-Spirling wechselt beim Betreten einer Region sichtbar in deren Epoche.
477. Kurzes Tutorial pro Epoche erklärt nur die neuen Anzeigen, nicht das ganze Spiel.
478. Epochen-Musik als Jukebox im Leuchtturm freischaltbar.
479. Chronik-Seite im Notizbuch: Erinnerungsbilder aus jeder Epoche, die der Spieler selbst gemacht hat.
480. Rückkehr-Belohnung: wer eine alte Region im neuen Look besucht, findet dort neue kleine Details.

## Teil D · Zeitplan, Qualität und Recht

481. Plan jährlich überprüfen und an Spielerfeedback anpassen.
482. Reihenfolge fest: Epoche I fertig, dann II, III, IV, V. Kein Parallelbau von zwei Epochen.
483. Richtwert: eine Epoche pro 6 bis 9 Monate nach dem Grundspiel-Release.
484. Jede Epoche als eigene Milestone-Reihe mit gestapelten PRs (Fundament, Spirlings, Welt, UI, Kampf, Effekte, Story, Feinschliff).
485. Jede Epoche bekommt eine eigene Abnahme-Checkliste in docs/epochs/epochN.md.
486. Externe Pixel-Künstlerinnen und -Künstler nur mit schriftlicher Rechteübertragung; der Vertrag braucht Alis Unterschrift.
487. Vor jedem Epochen-Release: Ähnlichkeits-Prüfung aller neuen Designs, festgehalten im Legal-Thread.
488. Vor jedem Epochen-Release: Store-Texte und Screenshots ohne fremde Marken und ohne Vergleiche mit anderen Spielen.
489. Vor jedem Epochen-Release: Altersfreigabe prüfen, ob Effekte oder Story die Einstufung ändern.
490. Messgrößen pro Epoche: Ladezeit, Bildrate, Speicher, Absturzrate, Filter-Nutzung, Spielerzufriedenheit.
491. Interne Testrunde (geschlossene Testgruppe) vier Wochen vor jedem Epochen-Release.
492. Gestaffelter Rollout im Store (erst 10 Prozent, dann alle).
493. Jede Epoche wird zuerst als Feature-Flag ausgeliefert und serverseitig eingeschaltet.
494. Fehlerbudget: höchstens 0,5 Prozent Absturzrate nach Epochenstart, sonst Rollback.
495. Barrierefreiheits-Prüfung vor jedem Release mit echten Testpersonen.
496. Leistungsberichte aller Epochen in docs/epochs/performance.md sammeln.
497. Kostenplan pro Epoche (Kunst, Musik, Test) vor Beginn erstellen.
498. Markenrecht: Epochennamen und Regionsnamen vor Veröffentlichung kurz prüfen lassen.
499. Sicherung aller Kunstquellen außerhalb von GitHub (zweiter Speicherort).
500. Nach der fünften Epoche: Rückblick über alle Epochen und Entscheidung, ob eine sechste Epoche oder ein neues Spiel folgt.
