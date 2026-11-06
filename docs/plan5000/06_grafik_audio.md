# Bereich 6: Grafik-Feinschliff, Animation, Musik und Klang

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 2225 bis 2668.

> **Auftrag für den umsetzenden Thread:** Ziel ist, dass sich Chimora in Epoche I (Tinte, 144×256) schon vor dem Store-Start lebendig, satt und rund anfühlt: jede Eingabe bekommt eine Antwort in Bewegung, Klang und auf Wunsch Vibration, und jeder Ort bekommt sein eigenes Musikstück. Betroffen sind vor allem scripts/core/ (neue Autoloads Juice, Haptics, MusicDirector), scripts/battle/presenter/, scripts/overworld/, scripts/ui/, shaders/, data/music.json, tools/art/, tools/audio/ und docs/ASSET_LOG.md. Fang mit dem Werkzeugkasten (Juice.gd mit festen Tween-Kurven, Bildschirmwackeln, Treffer-Stopp) und dem Haptik-Autoload an, weil fast alle anderen Punkte darauf aufbauen; danach folgen Musik pro Ort und die Element-Effekte. Nicht in diesen Bereich gehören neue Spirling-Designs, Shop-Kosmetik, Kampfregeln und Zahlenwerte, die Grafik-Epochen II bis V sowie alles, was bereits in DESIGN_EPOCHS.md oder KAMPF_PLAN_1000.md steht (zum Beispiel Tinten-Übergang in den Kampf, Idle-Frames, Status- und Stufen-Klänge, Sieges- und Niederlagen-Jingle).

### Werkzeugkasten für Spielgefühl und Tween-Kurven
2225. [x] [P1] Neuen Autoload scripts/core/Juice.gd anlegen, der alle Spielgefühl-Helfer (Kurven, Wackeln, Treffer-Stopp, Pop, Nachfedern) an einer Stelle bündelt und von überall per Juice.<name>() aufrufbar ist.
2226. [x] [P1] In Juice.gd eine feste Kurventabelle CURVES festlegen: "open" = TRANS_BACK/EASE_OUT 0,18 s, "close" = TRANS_QUAD/EASE_IN 0,12 s, "move" = TRANS_CUBIC/EASE_IN_OUT 0,22 s, "impact" = TRANS_EXPO/EASE_OUT 0,10 s, "settle" = TRANS_ELASTIC/EASE_OUT 0,35 s.
2227. [x] [P2] Eine Regel in AGENTS.md ergänzen, dass neue Tweens nur noch über Juice.tween(node, prop, wert, "kurve") entstehen, damit sich Dauer und Gefühl zentral nachstellen lassen.
2228. [x] [P1] Juice.pop(node) bauen: Skalierung 1,0 auf 1,15 in 0,06 s und zurück mit "settle", für Bestätigungen, Belohnungen und Treffer auf UI-Elementen.
2229. [x] [P1] Alle Juice-Tweens runden Positionen nach jedem Schritt auf ganze Pixel (process-Callback), damit nichts zwischen Pixeln verschwimmt.
2230. [x] [P1] Juice.speed() liest GameState.battle_speed_scale() und teilt im Kampf jede Dauer automatisch, damit 2x und 4x ohne Sonderfälle funktionieren.
2231. [x] [P1] Juice.reduced() als einzige Abfrage für GameState.reduce_motion einführen und alle bestehenden direkten Abfragen in SpirlingSprite.gd und Overworld.gd darauf umstellen.
2232. [x] [P1] Bestehende Tweens in SpirlingSprite.gd (step_out, step_back, lunge, faint) auf die Kurven "move" und "impact" umstellen, damit sie nicht mehr linear laufen.
2233. [x] [P2] Die Überblendung _fade_to in Overworld.gd auf Kurve "close" beim Abdunkeln und "open" ohne Überschwingen (TRANS_SINE/EASE_OUT) beim Aufhellen umstellen.
2234. [x] [P2] GUT-Test tests/unit/test_juice.gd prüft, dass jede Kurve existiert, jede Dauer zwischen 0,05 und 0,6 s liegt und reduced() alle Bewegungs-Helfer auf 0 s verkürzt.
2235. [x] [P2] Juice.nudge(node, richtung, px) für kurzes Anstoßen um 1 bis 3 Pixel in eine Richtung mit Rückfedern in 0,1 s bauen.
2236. [x] [P2] Juice.count_to(label, von, bis, dauer) bauen, das Zahlen hochzählt (Münzen, Wachstum, Rangpunkte) und bei jedem zehnten Schritt einen leisen Tick spielt.
2237. [x] [P2] Juice.stagger(nodes, abstand) bauen, das Listen-Einträge mit 0,03 s Versatz nacheinander einblendet.
2238. [x] [P2] Juice.blink_safe(node) bauen, der statt hartem An-und-Aus die Helligkeit über modulate zwischen 100 % und 60 % pendeln lässt, höchstens 3 Mal pro Sekunde.
2239. [x] [P2] Juice.wobble(node, grad, dauer) bauen, der ein Element um höchstens 4 Grad schwingen lässt, für wackelnde Hinweise wie neue Geschenke.
2240. [P3] Juice.float_text(text, position, farbe) bauen, der kurze Texte 10 Pixel nach oben steigen und in 0,6 s ausblenden lässt.
2241. [x] [P2] Juice speichert laufende Tweens pro Node und Eigenschaft und bricht einen alten Tween ab, bevor ein neuer startet, damit sich nichts aufschaukelt.
2242. [P2] Ein Debug-Schalter "Juice x0,25" im Debug-Menü verlangsamt alle Juice-Tweens auf ein Viertel, um Kurven sauber abzustimmen.
2243. [P3] Ein Debug-Schalter "Juice aus" schaltet alle Helfer ab, damit man im Vergleich sieht, was sie bringen.
2244. [x] [P2] docs/JUICE.md schreiben mit der Kurventabelle, je einem Beispiel pro Helfer und der Regel, wann welche Kurve gilt.
2245. [x] [P2] Alle TRANS_LINEAR-Tweens im Projekt per grep finden und auf eine benannte Kurve umstellen; Ausnahme sind nur Kraft-Leisten, die gleichmäßig laufen sollen.
2246. [x] [P2] Juice-Helfer dürfen pro Bild höchstens 0,3 ms Rechenzeit verbrauchen; ein Leistungstest mit 50 gleichzeitigen Tweens prüft das in tests/unit/.
2247. [P3] Juice.trail(node) bauen, der bei schnellen Bewegungen 2 Nachbilder mit 50 % und 25 % Deckkraft hinterherzieht.
2248. [P3] Juice.squash(node, achse) bauen, der Breite oder Höhe um genau 2 Pixel ändert und nach 0,08 s zurückstellt, statt unscharf zu skalieren.
2249. [P3] Kurventabelle als Ressource scripts/core/juice_curves.tres speichern, damit sie im Godot-Editor mit der Kurvenansicht bearbeitet werden kann.
2250. [P3] Juice.chain() als kleines Ablauf-Werkzeug bauen, das mehrere Helfer nacheinander mit await abarbeitet, statt verschachtelter Tween-Ketten.
2251. [P3] Pro Juice-Aufruf ein optionales Protokoll im Debug-Overlay, das Name, Dauer und Ziel-Node 2 Sekunden lang zeigt.
2252. [P3] Eine Testszene scenes/debug/JuiceLab.tscn mit Knöpfen für jeden Helfer, damit Gefühl und Kurven ohne Spielstand ausprobiert werden können.

### Bildschirmwackeln und Treffer-Stopp
2253. [x] [P1] Bildschirmwackeln als Trauma-System in Juice.gd bauen: Trauma von 0 bis 1, Versatz = Trauma² mal Höchstwert, Abbau 1,8 pro Sekunde.
2254. [x] [P1] Höchstversatz beim Wackeln auf 3 Pixel waagrecht und 2 Pixel senkrecht festlegen, immer ganzzahlig, damit die 144 Pixel Breite lesbar bleiben.
2255. [x] [P1] Wackeln wird auf einen eigenen Wurzel-Node (ShakeRoot) unter dem SubViewport angewendet, nie auf die UI-Ebene, damit Menüs und Texte ruhig bleiben.
2256. [x] [P1] Trauma-Werte festlegen: normaler Treffer 0,20, starker Treffer (hit_strong) 0,40, Spirling zieht sich zurück 0,30, Rift-Wächter erscheint 0,55.
2257. [x] [P1] Treffer-Stopp für normale Treffer bauen: das Spiel friert 40 ms plus 60 ms mal Anteil der verlorenen Kraft ein, höchstens 100 ms, über Engine.time_scale = 0,05.
2258. [x] [P1] Treffer-Stopp und Wackeln sind bei Juice.reduced() aus; stattdessen bekommt der getroffene Spirling nur einen 1-Pixel-Ruck.
2259. [x] [P1] Einstellung "Bildschirmwackeln" mit den Stufen Aus, Schwach (50 %) und Voll (100 %) in den Einstellungen von MenuHost.gd ergänzen und in settings_to_dict speichern.
2260. [x] [P2] Wackel-Richtung pro Element: Stone wackelt nur senkrecht, Gale nur waagrecht, Volt mit doppelter Frequenz und halber Weite, alle anderen kreisförmig.
2261. [x] [P2] Wackel-Frequenz als Rauschen mit 30 Hz statt Zufall pro Bild berechnen, damit es nicht flimmert, sondern rollt.
2262. [P2] Overworld-Wackeln beim Betreten eines Rifts mit Trauma 0,35 und tiefem Grollen.
2263. [P2] Overworld-Wackeln beim Laufen gegen eine Wand ersetzt durch einen 1-Pixel-Ruck der Spielfigur, nicht des Bildes.
2264. [P3] Kleines Wackeln (Trauma 0,10) beim Öffnen einer verschlossenen Tür oder eines Durchgangs nach einer Story-Bedingung.
2265. [P2] Treffer-Stopp auch beim Bestätigen des letzten Treffers eines Kampfes, 120 ms lang, damit das Ende spürbar wird.
2266. [P2] Treffer-Stopp wird bei Mehrfachtreffern in einem Zug nur beim ersten und letzten Treffer ausgelöst, damit es nicht stottert.
2267. [x] [P2] Wackeln überlagert sich nicht unbegrenzt: Trauma wird bei 1,0 gekappt und neue Ereignisse addieren höchstens bis dahin.
2268. [x] [P2] Bei 4x Kampftempo sinkt Trauma auf 60 % und der Treffer-Stopp auf höchstens 40 ms.
2269. [P2] Das Fotomodus-Bild (PhotoMode.gd) wird immer ohne Wackel-Versatz aufgenommen.
2270. [x] [P2] GUT-Test prüft, dass ShakeRoot nach Ende des Traumas exakt auf (0, 0) zurückkehrt und kein Restversatz bleibt.
2271. [P3] Gerichtetes Wackeln: der erste Ausschlag zeigt in die Richtung, aus der der Treffer kam, danach freies Ausschwingen.
2272. [P3] Leichtes Dauer-Zittern (Trauma 0,05) in den Rift-Karten cinder_rift, tide_rift und murk_hollow, nur wenn Wackeln auf Voll steht.
2273. [P3] Zeitlupen-Effekt für den letzten Treffer gegen einen Rift-Wächter: 0,4 s mit time_scale 0,3, danach normale Geschwindigkeit.
2274. [P3] Wackel-Vorschau in den Einstellungen: beim Umschalten der Stufe wackelt das Menü einmal mit Trauma 0,3 zur Probe.
2275. [P3] Ein Zoom-Puls von 1 Pixel Rand (Bild rückt 1 Pixel nach innen) bei starken Treffern, nur bei Wackeln Voll.
2276. [P3] Wackel- und Stopp-Werte als Tabelle in docs/JUICE.md festhalten, damit spätere Epochen dieselben Grundwerte nutzen.

### Übergänge zwischen Orten, Menüs und Bildschirmen
2277. [x] [P1] Kartenwechsel über Türen bekommt einen eigenen Übergang: von der Tür aus wächst ein dunkles Rechteck in 0,14 s über das Bild, statt gleichmäßig abzudunkeln.
2278. [x] [P1] Kartenwechsel über Kartenränder (Wege) schiebt das Bild in Laufrichtung 16 Pixel weiter, während es abdunkelt, damit sich der Wechsel wie Weitergehen anfühlt.
2279. [P2] Die Gesamtzeit jedes Kartenwechsels bleibt unter den 300 ms aus Overworld.gd; ein GUT-Test misst das für Tür, Weg und Warp.
2280. [x] [P1] Übergang vom Titelbild ins Spiel: das Titelbild rutscht mit Kurve "close" 24 Pixel nach oben und blendet aus, die Welt blendet darunter ein.
2281. [x] [P1] Pausemenü öffnet mit Kurve "open" von der rechten Kante herein (Weg 40 Pixel) und schließt mit "close" in 0,12 s.
2282. [P2] Jeder Untermenü-Wechsel im Pausemenü schiebt die alte Seite 8 Pixel nach links und blendet die neue von rechts ein, beim Zurückgehen gespiegelt.
2283. [P2] Warp über Leuchtturm-Treppen bekommt einen senkrechten Übergang: das Bild schiebt sich beim Hochsteigen nach unten weg und umgekehrt.
2284. [P2] Eintritt in eine Rift-Karte zeigt einen 0,3 s langen Riss-Schnitt, der sich von der Mitte aus öffnet, als eigener Shader shaders/rift_wipe.gdshader.
2285. [P2] Ausstieg aus einer Rift-Karte schließt den Riss-Schnitt in umgekehrter Richtung.
2286. [x] [P2] Dialogfeld fährt mit Kurve "open" 6 Pixel von unten herein und schließt mit "close", statt sofort zu erscheinen.
2287. [x] [P2] Dialog-Seitenwechsel lässt den alten Text 2 Pixel nach oben rutschen und ausblenden, bevor der neue zu tippen beginnt.
2288. [x] [P2] Der Weiter-Pfeil im Dialogfeld wippt 1 Pixel auf und ab im Takt von 0,5 s statt still zu stehen.
2289. [P3] Freundes- und Kontomenü (FriendsMenu.gd, AccountMenu.gd) bekommen dieselben Schiebe-Übergänge wie das Pausemenü.
2290. [P2] Ladepausen beim Server-Abruf über 200 ms zeigen drei Punkte, die nacheinander hüpfen, statt eines eingefrorenen Bildes.
2291. [P2] Wiederverbinden-Anzeige (ReconnectOverlay.gd) blendet in 0,2 s ein und aus und dunkelt das Spiel nur auf 60 % ab.
2292. [P2] Kampf-Ende zurück zur Welt: Spielfigur und Begleiter sind beim Aufhellen sichtbar 1 Pixel hochgesprungen, als kleine Begrüßung.
2293. [P3] Übergang ins Spirling-Lexikon: die gewählte Karte vergrößert sich vom Listenplatz auf die volle Seite in 0,2 s.
2294. [P2] Alle Übergänge haben eine zweite, ruhige Fassung für Juice.reduced(): nur Überblenden in 0,15 s ohne Bewegung.
2295. [P3] Nach einem neuen Speicherstand-Laden blendet die Welt von der Mitte aus kreisförmig auf, als eigener Shader shaders/iris.gdshader.
2296. [P3] Beim Wechsel zwischen Tag- und Nachtphase (DayCycle.gd) läuft die Farbtönung über 4 Sekunden weich statt sprunghaft.
2297. [P3] Übergang zur Weltziel-Seite der Online-Funktionen: die Fortschrittsleiste füllt sich beim Öffnen vom alten auf den neuen Wert.
2298. [P3] Szenen-Übergänge werden in einer Klasse scripts/ui/Transitions.gd gesammelt, mit einer Funktion pro Übergangsart.
2299. [P3] Übergang beim Schließen der App-Pause (zurück aus dem Hintergrund) mit kurzem Aufhellen in 0,2 s statt hartem Sprung.
2300. [P3] Rangliste-Seite baut ihre Zeilen mit Juice.stagger von oben nach unten auf.
2301. [P3] Rift-Wipe-Shader bekommt einen Parameter für die Rissform, damit jeder der drei Rifts eine eigene Kante hat.
2302. [P3] Screenshot-Werkzeug tools/screenshot.gd erhält eine Option, die alle Übergänge Bild für Bild als PNG-Folge ablegt, um sie zu prüfen.

### Figuren-Animation in der Welt
2303. [x] [P1] Spielfigur wippt bei jedem Schritt 1 Pixel nach unten in der Mitte des Schritts (zusätzlich zu den Lauf-Frames), damit das Gehen Gewicht bekommt.
2304. [x] [P1] Beim Rennen (hold-to-run) wird das Wippen doppelt so schnell und die Figur zeigt bei jedem zweiten Schritt eine kleine Staubwolke.
2305. [x] [P1] Umdrehen auf der Stelle: ein Tipp in eine neue Richtung dreht die Figur erst und läuft nach 0,08 s los, damit Drehen und Gehen unterscheidbar sind.
2306. [x] [P1] Das bestehende "!" über einem Wanderer (NPC.gd) erscheint mit Juice.pop und einem kurzen Ton, bevor er losläuft.
2307. [x] [P2] NPCs drehen sich beim Ansprechen mit 0,1 s Pause zur Spielfigur, statt sofort umzuspringen.
2308. [x] [P2] Nach 8 Sekunden ohne Eingabe schaut die Spielfigur nach links und rechts (Wechsel der Blickrichtung alle 1,2 s).
2309. [P2] Nach 30 Sekunden ohne Eingabe setzt sich die Spielfigur hin (ein neuer Sitz-Frame in tamer.png und tamer_f.png).
2310. [x] [P2] Stehende NPCs drehen sich alle 3 bis 7 Sekunden zufällig in eine andere Richtung, wenn ihre Kartendaten das erlauben.
2311. [P3] Gehende NPCs auf festen Wegen wippen wie die Spielfigur 1 Pixel pro Schritt.
2312. [P2] Gefühls-Blasen für NPCs als kleine Symbole über dem Kopf: "?", Herz, Note, Schweißtropfen, drei Punkte, jeweils 8×8 Pixel und mit Juice.pop.
2313. [P2] Gefühls-Blasen per Dialogdatei auslösbar über einen Befehl wie [emote:herz] in data/dialogue.
2314. [P2] Gras-Rascheln: beim Betreten eines Begegnungsfeldes bewegen sich die Grashalme des Feldes 2 Frames lang (neues Tile-Paar in overworld.png).
2315. [P2] Wasserkante: beim Gehen entlang von Wasser zeigt das Wasserfeld neben der Figur kleine Ringe für 0,4 s.
2316. [P2] Spielfigur zeigt beim Gegenstand-Finden eine Hochhalte-Pose (ein neuer Frame) für 0,8 s, mit dem Gegenstand-Symbol über dem Kopf.
2317. [P2] Spielfigur zeigt beim Heilen am Rastplatz eine Verbeuge-Pose (ein neuer Frame) während der Heil-Melodie.
2318. [P2] Türen öffnen sich in 2 Frames, bevor die Figur hindurchgeht, statt dass die Figur in einer geschlossenen Tür verschwindet.
2319. [P2] Schatten unter allen Figuren als 1 Pixel hohe dunkle Ellipse in Paletten-Farbe c0, damit sie auf dem Boden stehen.
2320. [P3] Rennende Figur lehnt sich 1 Pixel in Laufrichtung (verschobener Kopf-Bereich im Sprite).
2321. [P3] Gehweg-Unterschied: auf Holzbrücken ist das Wippen härter (Kurve "impact"), auf Sand weicher (TRANS_SINE).
2322. [P3] Leuchtturm-Hüterin und Kartenhaus-Figuren bekommen je eine eigene Leerlauf-Bewegung (Fegen, Blättern) als 2-Frame-Schleife.
2323. [P3] Wenn die Spielfigur eine Treppe hinaufgeht, verschiebt sie sich pro Schritt 2 Pixel senkrecht zusätzlich, damit Stufen sichtbar werden.
2324. [P3] Spielfigur zuckt kurz zusammen (1 Frame Erschrecken), wenn ein wilder Spirling erscheint.
2325. [P3] Wind-Wehen für Haare oder Mantel der Spielfigur an der Klippe von crowcrest, als 2-Frame-Wechsel alle 0,6 s.
2326. [P3] NPC-Sheets in tools/art/gen_tiles.py um die neuen Posen erweitern und die Frame-Reihenfolge in docs/ART_PIPELINE.md festhalten.

### Spirling-Bewegung in Kampf und Menüs
2327. [x] [P1] Entfalten-Sequenz bauen: alte und neue Form wechseln sich als Silhouette ab, erst alle 0,4 s, dann immer schneller bis alle 0,05 s, über 2,4 s, danach zeigt sich die neue Form mit Juice.pop.
2328. [x] [P1] Die Entfalten-Sequenz ist nach dem ersten Mal mit Tippen überspringbar und hat bei Juice.reduced() nur eine einfache Überblendung.
2329. [x] [P1] Pro Spirling ein Bewegungsprofil (hüpfen, schleichen, wogen, stampfen, gleiten am Boden) als Feld "motion" in data/spirlings.json für die bestehenden 21 Spirlings eintragen.
2330. [x] [P1] Beim Auftreten nutzt SpirlingSprite.step_out das Bewegungsprofil: hüpfen in 2 Sprüngen zu je 4 Pixeln Höhe, stampfen mit Trauma 0,1 beim Aufsetzen, schleichen mit Kurve "move".
2331. [x] [P1] Technik-Ausholbewegung nach Art: körperliche Techniken (PHYSICAL) holen 3 Pixel nach hinten aus und schnellen vor, besondere Techniken heben den Spirling 2 Pixel an und senken ihn beim Auslösen, Status-Techniken lassen ihn kurz zweimal wippen.
2332. [x] [P1] Getroffene Spirlings werden 3 Pixel weg vom Angreifer geschoben (Kurve "impact") und federn in 0,15 s zurück, zusätzlich zum bestehenden hit_flash.
2333. [P2] Ring-Aufstieg im Kampf: ein Ring aus Pixeln wächst vom Spirling aus von 8 auf 40 Pixel Durchmesser in 0,4 s und blendet aus.
2334. [P2] Ring-Aufstieg in der Welt (nach Kampf oder Gegenstand): derselbe Ring über dem Teamplatz im Pausemenü, wenn man es danach öffnet.
2335. [P2] Spirlings mit wenig Kraft (unter 25 %) stehen 1 Pixel tiefer und wippen langsamer, sodass man Schwäche ohne Zahlen sieht.
2336. [P2] Im Mehrfachkampf dreht sich der Angreifer vor seiner Technik zur Seite seines Ziels (Spiegelung über mirrored), wenn das Ziel auf der anderen Hälfte steht.
2337. [P2] Ausweichen bei verfehlter Technik: der Ziel-Spirling springt 4 Pixel zur Seite und zurück in 0,2 s.
2338. [P3] Beim Rasten (Energie sammeln) sinkt der Spirling 1 Pixel ab und richtet sich mit "settle" wieder auf.
2339. [P2] Teamliste im Pausemenü: der ausgewählte Spirling wippt 1 Pixel im Takt von 0,4 s, die anderen stehen still.
2340. [P2] Teamliste: Spirlings mit wenig Kraft wippen langsamer (0,8 s), erschöpfte gar nicht und sind auf 60 % Helligkeit.
2341. [P2] Beim Tauschen von zwei Plätzen in der Teamliste wandern die Symbole mit Kurve "move" aneinander vorbei, statt zu springen.
2342. [P2] Ring-Ablage (Lagerplatz der Spirlings): beim Ablegen gleitet das Symbol in die Liste, beim Holen springt es mit Juice.pop heraus.
2343. [P2] Spirling-Lexikon: ein gesehener, aber nicht gebondeter Spirling erscheint als Silhouette, die beim ersten Bonden in 0,6 s von unten nach oben eingefärbt wird.
2344. [P2] Begrüßungs-Moment nach dem Bonden: der neue Spirling springt im Ergebnisbild einmal 4 Pixel hoch, bevor sein Name erscheint.
2345. [P2] Titelbild (TitleArt.gd): die drei Starter-Silhouetten blinzeln versetzt alle 3 bis 5 Sekunden über einen 1-Pixel-Augenlid-Strich.
2346. [P3] Sammelkarten-Ansicht (Tamer-Karte): der Lieblings-Spirling hüpft beim Öffnen einmal nach seinem Bewegungsprofil.
2347. [P3] Geschenk-Ansicht zwischen Freunden: der geschickte Spirling hüpft beim Öffnen des Geschenks aus der Mitte heraus.
2348. [P3] Spirlings mit Andenken zeigen beim Auslösen des Andenkens einen 2-Pixel-Sprung, getrennt vom Gegenstand-Effekt.
2349. [P3] Prisma-Varianten bekommen beim Auftreten einen Lauf-Glanz, der in 0,5 s diagonal über das Sprite wandert (Shader shaders/sheen.gdshader).
2350. [P3] Bewegungsprofil "stampfen" lässt bei körperlichen Techniken eine kleine Staubwolke am Boden entstehen.
2351. [P3] Bewegungsprofil "wogen" lässt das Sprite in 2 Pixel hohen Wellen seitlich wandern, gezeichnet über einen Shader mit senkrechtem Versatz pro Zeile.
2352. [P3] Lexikon-Detailseite: der Spirling dreht sich beim Antippen um (Wechsel von front zu back mit 0,1 s Stauchung auf 0 Breite und zurück).
2353. [P3] Spirling im Begleiter-Platz der Freundesliste zeigt das Bewegungsprofil im Kleinen, 1 Pixel Weite.
2354. [P3] Rift-Wächter haben beim Auftreten eine 1,2 s lange eigene Einleitung: Bild dunkelt auf 70 % ab, Wächter wächst aus 1 Pixel Höhe auf volle Größe.
2355. [P3] GUT-Test prüft, dass jeder Spirling in data/spirlings.json ein gültiges Bewegungsprofil hat.
2356. [P3] Bewegungsprofile in docs/ART_PIPELINE.md mit Pixelweiten, Takt und Kurve beschreiben, damit neue Spirlings aus Bereich 1 sofort eines bekommen.

### Kampf-Effekte pro Element
2357. [x] [P1] Neue Klasse scripts/battle/presenter/ElementFx.gd mit je einer Funktion pro Element, die Aufladen, Weg und Einschlag einer Technik zeichnet und awaitbar ist.
2358. [x] [P1] Jede Technik läuft in drei Phasen: Aufladen am Anwender (0,15 s), Weg zum Ziel (0,2 s, bei körperlichen Techniken entfällt er), Einschlag am Ziel (0,25 s).
2359. [x] [P1] Ember: Aufladen als 3 Funken, die um den Anwender kreisen; Weg als Funke, der in einem flachen Bogen springt; Einschlag als 5 Glutpunkte, die nach oben steigen.
2360. [x] [P1] Tide: Aufladen als Ring, der sich unter dem Anwender ausbreitet; Weg als Wellenlinie mit 3 Pixeln Ausschlag; Einschlag als Spritzer aus 6 Tropfen, die nach unten fallen.
2361. [x] [P1] Bloom: Aufladen als 4 Blätter, die vom Boden aufsteigen; Weg als Blattwirbel auf gerader Linie; Einschlag als Ranken, die 2 Frames lang um das Ziel wachsen.
2362. [x] [P1] Volt: Aufladen als Zittern des Anwenders um 1 Pixel; Weg als Zickzack-Linie, die 2 Mal pro Bild neu gezeichnet wird; Einschlag als Stern aus 4 Strahlen.
2363. [x] [P1] Stone: Aufladen als Brocken, die unter dem Anwender aus dem Boden ragen; Weg als Brocken in hohem Bogen mit Schatten; Einschlag als Splitter in 6 Richtungen und senkrechtes Wackeln.
2364. [x] [P1] Gale: Aufladen als Strichlinien, die zum Anwender hin gezogen werden; Weg als Wirbel aus 3 Kreisbögen; Einschlag als Strichlinien, die waagrecht am Ziel vorbeistreichen.
2365. [x] [P1] Lumen: Aufladen als Lichtpunkt über dem Anwender, der von 1 auf 5 Pixel wächst; Weg als gerader Strahl; Einschlag als Kreuz-Glanz, der in 0,2 s verblasst (ohne Blitz, höchstens 60 % Helligkeit).
2366. [x] [P1] Umbra: Aufladen als Schatten, der sich vom Anwender löst; Weg als Schatten, der am Boden entlang kriecht; Einschlag als Schatten, der das Ziel von unten umschließt und sich zurückzieht.
2367. [P2] Doppelelement-Techniken zeigen beim Einschlag eine kleine Beimischung des zweiten Elements (2 Partikel), wenn der Anwender zwei Elemente hat.
2368. [P2] Effektstärke wächst mit der Stärke der Technik in drei Stufen: bis 50 Stärke 1-fache Partikelzahl, bis 90 1,5-fach, darüber 2-fach.
2369. [P2] Status-Techniken zeigen statt eines Einschlags ein Symbol der Wirkung (Pfeil hoch, Pfeil runter, Kreis) über dem Ziel, gezeichnet in der Form des Elements.
2370. [P2] Heil-Techniken (HealSelfEffect) zeigen aufsteigende Punkte in Elementform am Anwender, keine Einschlags-Phase.
2371. [P2] Kraft-Entzug (DrainEffect) zeigt 4 Partikel, die vom Ziel zum Anwender zurückwandern, in der Elementform.
2372. [P2] Energie-Entzug (EnergyDrainEffect) zeigt 3 kleine Rauten, die vom Ziel abgezogen werden und sich auflösen.
2373. [P2] Rückstoß (RecoilEffect) zeigt am Anwender einen kleinen Einschlag in halber Größe nach dem eigentlichen Treffer.
2374. [P2] Feld-Techniken (SetFieldEffect) zeigen eine Welle der Elementform, die einmal von links nach rechts über den ganzen Kampfbildschirm läuft.
2375. [x] [P2] Bei verfehlten Techniken läuft der Weg am Ziel vorbei aus dem Bild und es gibt keinen Einschlag.
2376. [x] [P2] Bei sehr wirksamen Treffern ist der Einschlag 1,5-mal so groß, bei schwach wirksamen nur halb so groß, ohne zusätzliche Texte.
2377. [P2] Effekte zeichnen nur mit den 4 Paletten-Farben aus EraManager.INK_PALETTE; ein GUT-Test zeichnet jeden Effekt in ein Bild und prüft die Farben.
2378. [P2] Jeder Effekt hält die Gesamtzeit von 0,6 s bei 1x ein und kürzt mit Juice.speed() bei 2x und 4x.
2379. [P2] Bei Juice.reduced() zeigt jeder Effekt nur den Einschlag als Standbild für 0,2 s, ohne Aufladen und Weg.
2380. [P2] Jede der 58 Techniken in data/moves.json bekommt ein optionales Feld "fx_variant" (0 bis 2), das kleine Unterschiede innerhalb eines Elements wählt, etwa Bogen flach, Bogen hoch oder Doppelweg.
2381. [P2] Kampfbildschirm-Test in tests/unit/ spielt alle 58 Techniken nacheinander ab und prüft, dass keiner einen Fehler wirft und jeder endet.
2382. [P2] Effekte laufen in einem eigenen Control über den Spirlings, das am Ende jedes Effekts alle Partikel freigibt (keine verwaisten Nodes).
2383. [P3] Ember-Techniken lassen nach dem Einschlag 1 Sekunde lang Rauch-Pixel vom Ziel aufsteigen.
2384. [P3] Tide-Techniken hinterlassen am Boden unter dem Ziel einen Pfützen-Strich, der in 1,5 s versickert.
2385. [P3] Bloom-Techniken lassen nach dem Einschlag 2 Blätter langsam zu Boden sinken.
2386. [P3] Volt-Techniken lassen das Ziel nach dem Einschlag 0,3 s lang 1 Pixel zittern.
2387. [P3] Stone-Techniken hinterlassen 3 Steinchen am Boden, die bis zum nächsten Zug liegen bleiben.
2388. [P3] Gale-Techniken bewegen die Hintergrundlinien von BattleBackdrop.gd für 0,4 s um 1 Pixel in Windrichtung.
2389. [P3] Lumen-Techniken hellen den Boden unter dem Ziel 0,3 s lang um eine Palettenstufe auf.
2390. [P3] Umbra-Techniken dunkeln den Kampfhintergrund 0,3 s lang am Rand um eine Palettenstufe ab (Vignette).
2391. [P3] Eine Debug-Seite "Effekt-Galerie" im Sound-Test-Menü spielt jeden Element-Effekt auf Knopfdruck ab, mit Auswahl von Art und Stärke.
2392. [P3] Effekt-Formen (Funke, Tropfen, Blatt, Splitter usw.) als 8×8-Bildchen in art/era1/fx/ ablegen, erzeugt von einem neuen Generator, statt sie Pixel für Pixel im Code zu zeichnen.

### Partikel
2393. [x] [P1] Einen eigenen Partikel-Pool scripts/core/PixelParticles.gd bauen, der einzelne Pixel und 8×8-Formen als draw-Aufrufe zeichnet, mit fester Obergrenze von 64 Partikeln pro Szene.
2394. [x] [P1] Partikel haben Lebensdauer, Startgeschwindigkeit, Schwerkraft, Reibung und Paletten-Farbe; Positionen werden beim Zeichnen auf ganze Pixel gerundet.
2395. [x] [P1] Laufstaub: bei jedem zweiten Rennschritt 3 Staubpixel hinter der Figur, Lebensdauer 0,3 s.
2396. [P1] Gegenstand-Glitzern: liegende Gegenstände auf der Karte senden alle 1,5 s einen 4-Pixel-Stern aus, damit man sie findet.
2397. [P2] Tagesfund (DailyFind.gd): der Fundort zeigt 2 aufsteigende Punkte pro Sekunde, solange der Fund nicht abgeholt ist.
2398. [P2] Gras-Pixel: beim Betreten eines Begegnungsfeldes springen 2 Halm-Pixel in die Luft.
2399. [P2] Wasser-Spritzer: beim Betreten einer seichten Wasserkante 4 Tropfen-Pixel.
2400. [P2] Rift-Funken: an jedem Rift-Eingang steigen alle 0,2 s Pixel auf, die nach 1 Sekunde verlöschen.
2401. [P2] Leuchtturm-Funkeln: an der Lampe der lighthouse-Karte bei Nacht ein ruhiges Glimmen aus 3 Pixeln, ohne Flackern.
2402. [P3] Heil-Punkte: beim Heilen am Rastplatz steigen 8 Punkte über dem Team-Symbol auf.
2403. [P2] Belohnungs-Konfetti in Paletten-Farben beim Abschluss einer Aufgabe im Aufgabenbuch (QuestLog), 24 Partikel, 1,2 s.
2404. [P2] Geschenk öffnen: 12 Partikel springen aus dem Geschenk-Symbol nach oben und fallen mit Schwerkraft.
2405. [P2] Partikel werden ausgeblendet, wenn der Bildschirm durch einen Übergang verdeckt wird, damit nichts über das Abdunkeln zeichnet.
2406. [P2] Bei Juice.reduced() sinkt die Obergrenze auf 16 Partikel und dekorative Partikel (Glitzern, Funkeln) entfallen.
2407. [P3] Rest-Spring: über dem Quellwasser der rest_spring-Karte steigen Dampf-Pixel langsam auf.
2408. [P3] Saltmarsh: einzelne Salzkristall-Pixel glitzern am Boden, wenn die Spielfigur daneben steht.
2409. [P3] Murk Hollow: Glühpunkte treiben in Bodennähe hin und her, 6 auf einmal.
2410. [P3] Cinder Rift: Asche-Pixel fallen langsam von oben, 1 pro 0,3 s.
2411. [P3] Tide Rift: Blasen-Pixel steigen von Wasserfeldern auf.
2412. [P3] Rangliste: der eigene Platz bekommt beim Aufsteigen 6 Stern-Partikel.
2413. [P3] Leistungstest: 64 Partikel plus Kampf-Effekt dürfen auf dem schwächsten Ziel-Android-Gerät nicht unter 60 Bilder pro Sekunde fallen.
2414. [P3] Partikel-Voreinstellungen (Staub, Funke, Konfetti, Dampf) als Konstanten in PixelParticles.gd mit Namen, damit sie überall gleich aussehen.

### UI-Grafik und Rückmeldung in Menüs
2415. [x] [P1] Jeder Knopf und jeder Listeneintrag reagiert beim Antippen sofort: 1 Pixel nach unten versetzt, solange der Finger drückt, und Juice.pop beim Loslassen.
2416. [x] [P1] Der Auswahl-Cursor in Listen (ListPicker.gd) gleitet mit Kurve "move" in 0,06 s zum neuen Eintrag, statt zu springen.
2417. [P2] Der Auswahl-Cursor wippt im Leerlauf 1 Pixel waagrecht im Takt von 0,6 s.
2418. [x] [P1] Kurze Hinweise (Toasts) für Ereignisse wie "Geschenk erhalten" oder "Gespeichert" bauen: 12 Pixel hohe Leiste fährt von oben herein, bleibt 1,6 s und fährt hinaus.
2419. [x] [P1] Münzanzeige zählt bei Änderungen mit Juice.count_to hoch oder runter, statt den neuen Wert sofort zu zeigen.
2420. [P2] Erhaltene Gegenstände zeigen ein Ergebnis-Fenster mit dem Gegenstand-Symbol, das mit Juice.pop erscheint und 0,3 s bis zur Bestätigung wartet, damit man nicht versehentlich wegtippt.
2421. [P2] Die Bildschirm-Steuerung (VirtualPad.gd) zeigt beim Drücken einer Richtung den gedrückten Pfeil 1 Pixel eingesunken und dunkler.
2422. [P2] Die Bildschirm-Steuerung blendet sich nach 4 Sekunden ohne Berührung auf 40 % Deckkraft ab und beim Antippen in 0,1 s wieder auf.
2423. [P2] Gesperrte Menüpunkte schütteln beim Antippen 2 Pixel waagrecht (Juice.nudge zweimal) und spielen den Abbruch-Klang.
2424. [P2] Lange Listen (Lager, Lexikon, Gegenstände) laufen beim Wischen mit Schwung nach und bremsen mit Reibung 6 pro Sekunde ab.
2425. [P2] Am Listenende federt die Liste 4 Pixel über und mit "settle" zurück, statt hart zu stoppen.
2426. [P2] Ein Bildlauf-Anzeiger (1 Pixel breiter Strich) erscheint am rechten Rand langer Listen beim Scrollen und verschwindet nach 0,8 s.
2427. [P2] Neue Einträge (neue Geschenke, neue Aufgaben, neue Freundesanfragen) bekommen einen 3×3-Pixel-Punkt, der mit Juice.wobble alle 2 Sekunden wackelt.
2428. [P2] Die Namens-Tastatur (NameKeyboard.gd) lässt jede gedrückte Taste kurz aufleuchten (Palettenstufe heller für 0,08 s).
2429. [P3] Die Namens-Tastatur schüttelt das Eingabefeld, wenn ein Name zu lang oder leer ist.
2430. [P2] Freundesliste: der Online-Punkt neben einem Namen pulsiert langsam (Helligkeit 100 % und 70 %, 1,5 s Takt).
2431. [P2] Weltziel-Leiste: neue Beiträge seit dem letzten Besuch füllen sich sichtbar mit einer helleren Spitze, die an der neuen Stelle stehen bleibt.
2432. [P3] Einstellungsschalter zeigen beim Umschalten einen gleitenden Knopf (0,1 s) statt Text "An/Aus" allein.
2433. [P2] Lautstärke-Einstellungen spielen beim Ändern sofort einen Probeklang in der neuen Lautstärke (Musik: 1 Takt, Klang: confirm).
2434. [P3] Text-Hervorhebung im Dialog: Wörter in [shake]...[/shake] zittern 1 Pixel, Wörter in [wave]...[/wave] wellen sich, als eigene Tags im Dialogfeld-Skript unter scripts/ui/.
2435. [P3] Text-Hervorhebung: Namen von Spirlings und Orten werden im Dialog automatisch in Palettenfarbe c1 statt c0 gesetzt.
2436. [P3] Das Aufgabenbuch hakt erledigte Ziele mit einem Strich ab, der sich in 0,2 s von links nach rechts zieht.
2437. [P3] Erfolge (Achievements) erscheinen als Toast mit einer 0,3 s langen Einfahrt und einem kleinen Glanz, der über die Leiste wandert.
2438. [P3] Rangliste zeigt Auf- und Abstiege mit einem kleinen Pfeil, der 1 Pixel in seine Richtung wippt.
2439. [P3] Tipps (Tips.gd) auf Ladepausen erscheinen mit Schreibmaschinen-Effekt in halber Dialoggeschwindigkeit.
2440. [P3] Sicherheitsfragen (Löschen, Freigeben, Freund entfernen) bekommen einen Halte-Knopf, der sich in 0,8 s füllt, statt eines einfachen Tipps.
2441. [P3] Der Sound-Test zeigt beim Abspielen eine kleine Pegel-Anzeige aus 8 Balken, die im Takt der Lautstärke ausschlagen.
2442. [P3] Alle neuen UI-Bewegungen werden im Screenshot-Werkzeug als Bildfolge abgelegt und in docs/JUICE.md als Beispiel verlinkt.

### Musik: eigene Stücke pro Ort
2443. [x] [P1] Jede der 11 Karten bekommt ein eigenes Stück; data/music.json wird so umgestellt, dass jede Karte einen eigenen Eintrag hat und "default" nur noch für neue Karten gilt.
2444. [x] [P1] lighthouse: ruhiges Stück, 84 BPM, D-Dur, Melodie auf Dreieckswelle, Bass als Bordun, Leitmotiv des Spiels in 4 Takten.
2445. [x] [P1] brindlewick: Marktstadt-Stück, 112 BPM, G-Dur, hüpfende Bassfigur, Melodie auf Pulswelle 25 %.
2446. [x] [P1] fernstair: Weg-Stück, 128 BPM, A-Dur, Farn-Terrassen-Gefühl durch aufsteigende Arpeggien.
2447. [x] [P1] crowcrest: Klippen-Stück, 120 BPM, E-Moll, weite Intervalle (Quinten und Oktaven) in der Melodie, wenig Schlagzeug.
2448. [x] [P2] saltmarsh: Marschland-Stück, 96 BPM, F-Dur mit Mixolydisch, wiegender 6/8-Takt.
2449. [x] [P1] Das Leitmotiv aus lighthouse taucht in jedem Ort-Stück mindestens einmal verändert auf (andere Tonart, anderes Tempo), damit die Region zusammenklingt.
2450. [x] [P2] thornridge: Dorf-Stück, 100 BPM, C-Dur, Melodie mit kurzen Vorschlägen, Holzschlag-Rauschen als Perkussion.
2451. [x] [P2] map_house: Kartenhaus-Stück, 76 BPM, B-Dur, leises Spieluhr-Arpeggio auf hoher Pulswelle 12,5 %.
2452. [x] [P2] rest_spring: Rast-Stück, 70 BPM, Es-Dur, langsame Akkordflächen, keine Trommeln.
2453. [x] [P2] cinder_rift: Rift-Stück, 84 BPM, C-Moll, tiefe Pulswelle mit Glut-Knistern aus Rauschen.
2454. [x] [P2] tide_rift: Rift-Stück, 80 BPM, Fis-Moll, wellende Lautstärke-Schwankung im Akkordteppich (Tremolo 3 Hz).
2455. [x] [P2] murk_hollow: Rift-Stück, 66 BPM, B-Moll, gedämpfter Bass und lange Pausen in der Melodie.
2456. [x] [P2] Die drei Rift-Stücke teilen sich ein gemeinsames Rift-Motiv aus 3 Tönen, das in jedem Stück anders begleitet wird.
2457. [P2] Eigene Kampfmusik für wilde Spirlings in Rift-Karten, die das Rift-Motiv aufgreift, statt der allgemeinen battle.ogg.
2458. [P2] Eigenes Stück für den Kampf gegen Rift-Wächter pro Rift, je eine Fassung des Rift-Stücks mit 1,3-fachem Tempo und vollem Schlagzeug.
2459. [P2] Eigenes Stück für den Titel (title) wird überarbeitet, damit es mit dem Leitmotiv beginnt und auf dem Grundton endet, als saubere Schleife.
2460. [P2] Kurzes Stück für Mirelas Kartenbuch-Momente (Story-Szenen), 8 Takte, ruhig, nur Dreieckswelle und Akkorde.
2461. [P2] Kurzes Spannungs-Stück für Story-Szenen mit Gefahr, 16 Takte, 140 BPM, nur Bass und Trommel.
2462. [P2] Kurzes Stück für den Abschied und traurige Szenen, 70 BPM, Moll, 12 Takte mit sauberem Schleifenpunkt.
2463. [P3] Kurzes Stück für Online-Menüs (Freunde, Geschenke, Rangliste), damit diese Menüs eine eigene ruhige Stimmung haben.
2464. [x] [P2] Jedes Ort-Stück ist zwischen 60 und 120 Sekunden lang und hat einen hörbar sauberen Schleifenpunkt ohne Knacken.
2465. [P3] Nachtfassung jedes Außen-Stücks: gleiche Noten, 10 % langsamer, Melodie eine Oktave tiefer, weniger Schlagzeug, umgeschaltet über DayCycle.
2466. [P3] Kurzes Stück für die Heilung am Rastplatz als eigener Jingle (6 Töne), getrennt von der Ort-Musik.
2467. [P3] Kurzer Jingle für neu entdeckte Orte (Kartenbuch wächst), 3 Sekunden, aus dem Leitmotiv abgeleitet.
2468. [P3] Kurzer Jingle für Wichtige Gegenstände, 2 Sekunden, mit anschließender Rückkehr zur Ort-Musik.
2469. [P3] Kurzer Jingle für das Entfalten, der zur Entfalten-Sequenz passt und genau 2,4 s lang ist.
2470. [P3] Abspann-Stück, das die Leitmotive aller Orte nacheinander zitiert, für das Ende von Mirelas Kartenbuch.
2471. [P3] Melodien aller Stücke als Notentext in tools/audio/songs/<name>.txt auslagern, damit sie ohne Python-Code lesbar und änderbar sind.
2472. [P3] Jedes Stück bekommt in docs/MUSIC.md einen Steckbrief: Ort, Tempo, Tonart, Stimmung, Leitmotiv-Stelle, Länge.
2473. [P3] Musik-Test im Sound-Test zeigt zu jedem Stück den Ort und den Steckbrief-Satz an.
2474. [P3] Eine Melodie-Prüfung in tools/audio/ vergleicht die Intervallfolgen aller eigenen Stücke untereinander und meldet Abschnitte von mehr als 8 gleichen Tönen, damit kein Stück das andere kopiert.

### Dynamische Musik-Schichten
2475. [x] [P1] tools/audio/gen_audio.py schreibt jedes Ort-Stück zusätzlich als 4 Einzelspuren (Bass, Akkorde, Melodie, Schlagzeug) mit exakt gleicher Länge in audio/music/stems/<name>_<spur>.ogg.
2476. [x] [P1] Neuer Autoload scripts/core/MusicDirector.gd spielt die Einzelspuren über AudioStreamSynchronized gleichzeitig ab und regelt jede Spur einzeln in der Lautstärke.
2477. [x] [P1] Schicht-Regel Welt: im Stillstand nur Bass und Akkorde, beim Gehen kommt die Melodie dazu, beim Rennen das Schlagzeug, jeweils in 0,8 s eingeblendet.
2478. [x] [P1] Schicht-Regel Dialog: während ein Dialog offen ist, sinken Melodie und Schlagzeug auf -12 dB, damit der Text im Vordergrund steht.
2479. [x] [P1] Sound.music() bleibt die öffentliche Schnittstelle; MusicDirector übernimmt nur, wenn Einzelspuren vorhanden sind, sonst läuft die bisherige Ogg-Datei.
2480. [P2] Schicht-Regel Begegnungsfeld: im hohen Gras kommt eine leise Spannungs-Spur (Akkorde mit Tremolo) dazu.
2481. [P2] Schicht-Regel Rift-Nähe: in den letzten 6 Feldern vor einem Rift-Eingang wird die Akkord-Spur durch eine verstimmte Fassung (-20 Cent) ersetzt.
2482. [P2] Schicht-Regel Team erschöpft: wenn kein Spirling im Team mehr als 25 % Kraft hat, fällt das Schlagzeug weg und die Melodie wird gedämpft (Tiefpass bei 2 kHz).
2483. [P2] Kartenwechsel innerhalb gleicher Tonart wechseln auf den nächsten Taktschlag statt sofort, mit AudioStreamInteractive und Übergängen am Taktende.
2484. [P2] Kartenwechsel zu einem Stück in anderer Tonart nutzen einen 1-Takt-Übergang (gemeinsamer Akkord), der in gen_audio.py pro Paar erzeugt wird.
2485. [P2] Kampfbeginn setzt die Ort-Musik auf Pause und merkt sich die Stelle; nach dem Kampf läuft sie an derselben Stelle mit 0,6 s Einblenden weiter.
2486. [P2] Kampfmusik bekommt 3 Schichten (Grund, Spannung, Höhepunkt); Höhepunkt kommt dazu, wenn auf beiden Seiten nur noch ein Spirling steht.
2487. [P2] Sieg im Kampf beendet die Kampfmusik auf dem nächsten Taktschlag, bevor der bestehende Sieges-Jingle beginnt.
2488. [P2] Lautstärke-Kurven für Schichtwechsel sind logarithmisch (in dB), nicht linear, damit Einblenden gleichmäßig klingt.
2489. [P2] Schichten werden nur gewechselt, wenn sich der Zustand mindestens 1,5 s lang hält, damit kurzes Anhalten nicht dauernd umschaltet.
2490. [P2] GUT-Test prüft, dass alle Einzelspuren eines Stücks gleich viele Samples haben und MusicDirector bei fehlenden Spuren auf die Ogg-Datei zurückfällt.
2491. [P2] Einstellung "Dynamische Musik" (An/Aus) in den Einstellungen; Aus spielt immer alle Schichten voll.
2492. [P3] Schicht-Regel Nacht: bei Nacht wird die Melodie-Spur durch eine Oktave tiefer gespielte Fassung ersetzt, statt eine eigene Nachtdatei zu laden.
2493. [P3] Schicht-Regel Freund in der Nähe: wenn ein Echo eines Freundes auf der Karte steht, kommt eine zweite, leise Melodiestimme dazu.
2494. [P3] Schicht-Regel Story-Fortschritt: nach dem Heilen eines Rifts bekommt das zugehörige Ort-Stück dauerhaft eine zusätzliche helle Harmonie-Spur.
2495. [P3] Schicht-Regel Weltziel: wenn das gemeinsame Weltziel erreicht ist, spielt die Leuchtturm-Musik eine Woche lang mit Fest-Spur.
2496. [P3] Musik-Takt-Signal: MusicDirector sendet ein Signal "beat" auf jedem Schlag, an das sich UI-Wippen und Leuchtturm-Glimmen anhängen können.
2497. [P3] Cursor-Wippen und Weiter-Pfeil wippen im Takt der laufenden Musik, wenn ein beat-Signal vorhanden ist.
2498. [P3] Debug-Anzeige im Sound-Test zeigt, welche Schichten gerade laufen und mit welcher Lautstärke.
2499. [P3] Einzelspuren aller Stücke zusammen dürfen höchstens 6 MB groß sein; gen_audio.py bricht mit Fehler ab, wenn das überschritten wird.
2500. [P3] Schicht-Regeln als Tabelle in data/music.json pro Karte überschreibbar machen (zum Beispiel keine Renn-Schicht im Kartenhaus).

### Soundeffekte für Welt und Menüs
2501. [x] [P1] Schritt-Geräusche pro Untergrund (Gras, Weg, Holz, Sand, Stein, Wasserkante) als 6 kurze Klänge unter 60 ms, leise (-18 dB), abwechselnd mit 2 Fassungen pro Untergrund.
2502. [x] [P1] Schritt-Geräusche werden über die Tile-Art aus TilesetFactory.gd gewählt und nur beim Rennen doppelt so oft gespielt.
2503. [x] [P1] Text-Stimme im Dialog: jeder 2. getippte Buchstabe spielt einen 15 ms kurzen Piep, dessen Tonhöhe pro Figur festgelegt ist (Spielfigur, Mirela, Kestra, Aldo, Hüterinnen, Dorfleute).
2504. [x] [P2] Text-Stimme lässt sich in den Einstellungen getrennt ausschalten und ist im Sound-Test hörbar.
2505. [x] [P1] Eigener Klang für das "!" eines Wanderers, der jemanden entdeckt: zwei schnell steigende Töne, 0,15 s.
2506. [x] [P1] Eigener Klang für das Aufnehmen eines Gegenstands auf der Karte, 4 aufsteigende Töne, getrennt vom Münzklang.
2507. [P2] Tür-Klang (Öffnen) und Tür-Klang (Schließen) als zwei Klänge mit Holz-Charakter aus Rauschen und tiefem Puls.
2508. [P2] Treppen-Klang mit 3 schnellen Schritten, die in der Tonhöhe steigen oder fallen, je nach Richtung.
2509. [P2] Klang für das Öffnen und das Schließen des Pausemenüs, verschieden voneinander (Seite aufschlagen, Seite zuklappen).
2510. [P2] Cursor-Klang (select) bekommt 3 leicht verschiedene Tonhöhen, die zufällig wechseln, damit langes Scrollen nicht ermüdet.
2511. [P2] Klang für gesperrte Menüpunkte, ein dumpfer kurzer Ton, der sich klar vom Abbruch-Klang unterscheidet.
2512. [P2] Klang für den Toast-Hinweis (kurz und leise, 2 Töne).
2513. [P3] Klang für ein neu erhaltenes Geschenk von einem Freund, ein heller 3-Ton-Akkord.
2514. [P2] Klang für das Absenden eines Geschenks, ein fallender 3-Ton-Akkord.
2515. [P2] Klang für eine angenommene Freundesanfrage, 2 Töne im Quintabstand.
2516. [P2] Klang für erledigte Aufgaben im Aufgabenbuch, kurzer Strich plus Glocke.
2517. [P2] Klang für den Tagesfund beim Abholen, Glitzern aus 5 sehr hohen Tönen.
2518. [P3] Klang für Bestätigung am Rastplatz vor dem Heilen (Wasser-Plätschern aus gefiltertem Rauschen).
2519. [P2] Klang für das Betreten eines Begegnungsfeldes (leises Rascheln), nur jedes 3. Feld, damit es nicht nervt.
2520. [P2] Klang für das Laufen gegen eine Wand (bump) bekommt eine Sperre: höchstens einmal pro 0,4 s.
2521. [P3] Klang für Gefühls-Blasen pro Symbol (Herz, Frage, Note, Schweiß, Punkte), jeweils unter 0,2 s.
2522. [P3] Klang für die Online-Verbindung: wieder verbunden (steigend) und Verbindung verloren (fallend), leise.
2523. [P3] Klang für Rangliste-Aufstieg, kurzer Lauf aus 5 Tönen.
2524. [P3] Klang für das Umblättern im Lexikon und im Aufgabenbuch, Papier-Rauschen 80 ms.
2525. [P3] Klang für die Namens-Tastatur pro Taste, eine Klick-Fassung mit 2 Tonhöhen.
2526. [P3] Klang für die Entfalten-Sequenz: steigendes Rauschen über 2,4 s, das im Moment der Enthüllung abbricht.
2527. [P3] Klang für den Fotomodus-Auslöser, kurzes Klicken aus Rauschen mit hartem Ende.
2528. [P3] Alle Klänge der Welt und Menüs bekommen im Sound-Test eine eigene Gruppe "Welt" und "Menü", damit man sie geordnet anhören kann.

### Soundeffekte im Kampf (ergänzend)
2529. [x] [P1] Aufladen-Klang pro Art: körperlich (kurzes Rauschen, 0,1 s), besonders (steigender Puls, 0,15 s), Status (zwei weiche Töne), passend zur Aufladen-Phase der Element-Effekte.
2530. [x] [P1] Weg-Klang pro Element für Techniken mit Weg-Phase, je 0,2 s, zum Beispiel Zischen für Gale, Knistern für Volt, Gluckern für Tide.
2531. [P2] Klang für verfehlte Techniken: ein leiser Luftzug, der am Ziel vorbeizieht.
2532. [P2] Treffer-Klänge (hit_*) werden je nach verlorener Kraft lauter: bis 10 % bei -6 dB, bis 30 % bei -3 dB, darüber bei 0 dB.
2533. [P2] Treffer-Klänge bekommen eine zufällige Tonhöhe zwischen 0,95 und 1,05, damit Wiederholungen frischer klingen.
2534. [P2] Klang beim Auftreten eines Spirlings (step_out) passend zum Bewegungsprofil: Hüpfen, Schleichen, Stampfen, Wogen, Gleiten.
2535. [P3] Klang beim Zurücktreten eines Spirlings (step_back), ein kurzer fallender Ton.
2536. [P2] Klang für das Ausweichen, ein schneller seitlicher Wisch.
2537. [P2] Klang für den Energie-Zuwachs am Rundenbeginn, ein sehr leiser Tick pro Energiepunkt, höchstens 3 Ticks.
2538. [P2] Klang für das Andenken, wenn es im Kampf auslöst, getrennt vom Gegenstand-Klang.
2539. [P2] Klang für die Technik-Auswahl im Kampfmenü, der je nach Element der Technik eine andere Tonhöhe hat (8 Stufen einer Tonleiter).
2540. [P3] Klang für das Erscheinen eines Rift-Wächters: tiefes Grollen über 1,2 s, passend zur Wächter-Einleitung.
2541. [P3] Klang für Doppelelement-Einschläge mischt die Treffer-Klänge beider Elemente (zweites bei -6 dB, 30 ms versetzt).
2542. [P3] Klang für den Ring-Aufstieg im Kampf als eigener kurzer Klang zum wachsenden Pixel-Ring, getrennt vom bisherigen Aufstiegs-Klang in der Welt.
2543. [P3] Klang-Nachhall im Rift-Kampf: alle Kampf-Klänge laufen dort über einen Hall-Effekt auf dem SFX-Bus (AudioEffectReverb, Raumgröße 0,6).
2544. [P3] Klang-Dämpfung in Höhlen und Rifts per Tiefpass bei 4 kHz für alle Treffer, damit der Ort hörbar ist.
2545. [P3] Im Mehrfachkampf werden gleiche Treffer-Klänge innerhalb von 50 ms zusammengelegt, damit es nicht übersteuert.
2546. [P3] Kampf-Klänge bei 4x Tempo werden auf höchstens 0,15 s gekürzt, indem gen_audio.py von jedem Klang eine kurze Fassung "<name>_short" erzeugt.

### Klang-Technik, Busse und Mobilgeräte
2547. [x] [P1] Neue Busse "UI", "Voice" (Schreie und Text-Stimme) und "Ambience" unter "SFX" in GameState.ensure_buses() anlegen, damit sie getrennt regelbar sind.
2548. [x] [P1] Ein Limiter (AudioEffectHardLimiter, Decke -1 dB) auf dem Master-Bus verhindert Übersteuern bei vielen gleichzeitigen Klängen.
2549. [x] [P1] iOS: Projekteinstellung audio/general/ios/session_category auf "Ambient" stellen, damit der Lautlos-Schalter beachtet wird und Musik anderer Apps weiterlaufen kann.
2550. [x] [P1] Beim Wechsel der App in den Hintergrund (NOTIFICATION_APPLICATION_PAUSED) werden Musik und Klänge stumm geschaltet und beim Zurückkehren in 0,3 s wieder eingeblendet.
2551. [P2] Die Stimmenanzahl in Sound.gd (SFX_VOICES) steigt von 6 auf 10, und jeder Klang bekommt eine Priorität (UI 1, Welt 2, Kampf 3), sodass bei voller Belegung der unwichtigste Klang weicht.
2552. [P2] Einstellung "Andere Musik erlauben": spielt eine andere App Musik, startet Chimora nur mit Klängen und ohne eigene Musik.
2553. [P2] Android: bei Audio-Fokus-Verlust (Anruf, Sprachnachricht) Musik pausieren und danach an derselben Stelle fortsetzen.
2554. [P3] Kopfhörer abgezogen: Musik wird sofort auf -30 dB gesenkt, damit es nicht laut aus dem Lautsprecher kommt.
2555. [P2] Mono-Ausgabe als Einstellung, die den Master-Bus auf Mono mischt, für Menschen mit einseitigem Hören.
2556. [P2] Getrennte Lautstärke-Regler für Text-Stimme und Umgebungsklänge in den Einstellungen, zusätzlich zu Musik und Klängen.
2557. [P2] Alle Klänge werden beim Start in einem Rutsch vorgeladen (unter 2 MB), damit der erste Treffer im Kampf nicht stockt.
2558. [P2] Schreie (Cry.gd) bekommen beim ersten Kampfstart des Tages einen Vorab-Aufbau im Hintergrund, damit kein Bild ruckelt.
2559. [P2] Ogg-Schleifen nutzen in den .import-Dateien loop_offset aus den Steckbrief-Daten, damit Stücke mit Einleitung an der richtigen Stelle wiederholen.
2560. [P2] Klang-Ausgabe unter 30 ms Verzögerung auf Android einstellen (Projekteinstellung audio/driver/output_latency auf 15).
2561. [P2] GUT-Test prüft, dass jeder in Code genannte Klangname (Sound.sfx("...")) eine Datei in audio/sfx/ hat und umgekehrt keine ungenutzte Datei existiert.
2562. [P3] Leichter Raumklang pro Karte: Innenräume (map_house, Leuchtturm innen) mit kurzem Hall auf dem SFX-Bus, Außenkarten ohne.
2563. [P3] Lautstärke-Ausgleich zwischen Musik und Klängen nach Ortstyp: in Rifts Musik -2 dB, damit Kampfklänge durchdringen.
2564. [P3] Eine kleine Klang-Warteschlange für Jingles: kommen zwei Jingles gleichzeitig (Ring-Aufstieg und Gegenstand), spielt der zweite danach statt darüber.
2565. [P3] Debug-Anzeige im Sound-Test zeigt, wie viele Stimmen gerade belegt sind und welcher Klang zuletzt verdrängt wurde.
2566. [P3] Lautstärke-Werte aller Busse und Regler werden beim Start einmal ins Debug-Protokoll geschrieben, um Fehlerberichte zu verstehen.
2567. [P3] Optionaler Kopfhörer-Modus mit leichter Stereo-Breite für Kampf-Klänge (Angreifer links oder rechts), nur bei Stereo-Ausgabe.
2568. [P3] Sound.gd in zwei Dateien aufteilen: Sound.gd für Klänge und MusicDirector.gd für Musik, mit gleichbleibenden öffentlichen Aufrufen.

### Umgebungsklänge pro Ort
2569. [x] [P1] Neuer Ordner audio/ambience/ mit einer Schleife pro Außenkarte (30 bis 45 Sekunden, Ogg, Mono), erzeugt aus Rauschen und Tonfolgen in gen_audio.py.
2570. [x] [P1] data/music.json bekommt pro Karte ein Feld "ambience" mit dem Namen der Umgebungsschleife, abgespielt auf dem Ambience-Bus bei -14 dB.
2571. [x] [P1] lighthouse: Meeresrauschen als langsam an- und abschwellendes Rauschen (Periode 6 s) plus seltene Möwen-artige Pfeiftöne aus eigenen Tonfolgen.
2572. [x] [P2] brindlewick: Marktgeräusche als leises Stimmengemurmel aus gefiltertem Rauschen und gelegentlichen Glocken.
2573. [x] [P2] fernstair: Wind in Farnen als Rauschen mit Hochpass, plus Vogelzwitschern aus kurzen Puls-Tonfolgen.
2574. [x] [P2] crowcrest: starker Wind mit Böen alle 8 bis 15 Sekunden.
2575. [x] [P2] saltmarsh: Frosch-Rufe als tiefe, kurze Pulswellen und stehendes Wasser-Glucksen.
2576. [P2] Umgebungsschleifen haben eine Nachtfassung mit Grillen-Zirpen (schnelle hohe Pulse) statt Vogelstimmen, umgeschaltet über DayCycle.
2577. [P2] Rift-Karten bekommen ein tiefes, gleichmäßiges Summen (40 bis 60 Hz) als Umgebungsklang, das in jedem Rift anders moduliert ist.
2578. [x] [P2] Bei Kartenwechsel blenden Umgebungsklänge in 1 Sekunde über, unabhängig vom Musikwechsel.
2579. [x] [P2] Im Kampf wird der Umgebungsklang auf -24 dB gesenkt, aber nicht ausgeschaltet, damit der Ort erhalten bleibt.
2580. [P3] Ortsgebundene Klangquellen mit AudioStreamPlayer2D: Brunnen in brindlewick, Quelle in rest_spring, Leuchtturm-Mechanik in lighthouse, Reichweite 5 Felder.
2581. [P3] thornridge: Holzhacken in der Ferne alle 20 bis 40 Sekunden als zufällig gesetzter Einzelklang.
2582. [P3] map_house: leises Uhrenticken und Papier-Rascheln als Innenraum-Umgebung.
2583. [P3] rest_spring: Wasserplätschern, das lauter wird, je näher die Spielfigur der Quelle kommt.
2584. [P3] Zufällige Einzelklänge (Vogel, Glocke, Ast) werden nach einem festen Startwert pro Tag gesetzt, damit sie nicht in festen Abständen wiederkehren.
2585. [x] [P3] Umgebungsklänge sind im Sound-Test als eigene Gruppe "Orte" hörbar.
2586. [x] [P3] Umgebungsklänge zusammen höchstens 2,5 MB; gen_audio.py prüft die Grenze beim Erzeugen.

### Haptik und Vibration
2587. [x] [P1] Neuer Autoload scripts/core/Haptics.gd, der auf Handys Input.vibrate_handheld(dauer_ms, stärke) nutzt und auf Gamepads das bestehende GameState.rumble_pads aufruft.
2588. [x] [P1] Android-Exportvorlage in export_presets.cfg um die Berechtigung VIBRATE ergänzen und prüfen, dass der Export sie enthält.
2589. [x] [P1] Feste Muster in Haptics.gd: "tap" 10 ms/0,3, "confirm" 15 ms/0,5, "hit" 25 ms/0,7, "heavy" 45 ms/1,0, "error" zweimal 15 ms mit 40 ms Pause.
2590. [x] [P1] Die bestehende Einstellung "rumble" wird zu "Vibration" mit den Stufen Aus, Schwach (50 %) und Voll und gilt für Handy und Gamepad.
2591. [x] [P1] Treffer im Kampf rufen Haptics "hit" auf, starke Treffer "heavy", gekoppelt an dieselbe Stelle wie das Bildschirmwackeln in BattleScene.gd.
2592. [P2] Bestätigen in Menüs ruft "tap" auf, aber höchstens einmal pro 80 ms, damit schnelles Tippen nicht dauernd brummt.
2593. [P2] Gesperrte Menüpunkte und Fehler (Name zu lang, keine Verbindung) rufen "error" auf.
2594. [P2] Ein Wanderer entdeckt die Spielfigur: zwei kurze "tap" mit 60 ms Abstand passend zum "!".
2595. [P2] Begegnung mit einem wilden Spirling: ein langes, ansteigendes Muster aus 3 Stufen (15, 25, 40 ms).
2596. [P3] Erhaltener Gegenstand oder Geschenk: ein weiches "confirm".
2597. [P2] Entfalten-Sequenz: Vibration im Takt des Silhouetten-Wechsels, immer schneller, und ein "heavy" bei der Enthüllung.
2598. [P2] Bonden im Echo-Minispiel: jeder richtig getroffene Ton ein "tap", das Ergebnis erst nach dem Minispiel, damit Vibration keine Chance verrät.
2599. [P2] Laufen gegen eine Wand ruft ein sehr kurzes "tap" mit Stärke 0,2 auf, höchstens einmal pro 0,4 s.
2600. [P2] Haptics prüft vor jedem Aufruf, ob das Gerät Vibration unterstützt, und tut sonst nichts, ohne Fehler im Protokoll.
2601. [P2] Vibration ist im Hintergrund und bei gedimmtem Bildschirm immer aus.
2602. [P3] Rift-Eingang: ein langes, leises Grollen (200 ms, Stärke 0,3) beim Betreten.
2603. [P3] Ring-Aufstieg: drei kurze "tap" im Takt des Pixel-Rings.
2604. [P3] Sieg über einen Rift-Wächter: ein "heavy" im Moment des letzten Treffers und ein "confirm" beim Jingle-Ende.
2605. [P3] Musik-Takt: optional vibriert das Gerät leicht im Takt des Kampf-Höhepunkts (Einstellung "Takt spüren", Standard aus).
2606. [P3] Haptik-Vorschau in den Einstellungen: beim Umschalten der Stufe spielt das Gerät "hit" einmal zur Probe.
2607. [P3] GUT-Test mit einer Ersatz-Klasse für vibrate_handheld prüft, dass bei Stufe Aus kein einziger Aufruf ankommt.
2608. [P3] Alle Haptik-Muster mit Dauer und Stärke als Tabelle in docs/JUICE.md festhalten.

### Werkzeuge zur Asset-Erzeugung (tools/art, tools/audio)
2609. [x] [P1] tools/audio/gen_audio.py in Module aufteilen: tools/audio/synth.py (Wellen, Hüllkurven), tools/audio/sfx.py, tools/audio/music.py, tools/audio/ambience.py, mit gen_audio.py als Einstieg.
2610. [x] [P1] gen_audio.py bekommt Aufruf-Optionen --only <name>, --sfx, --music, --stems, damit nicht bei jeder Änderung alles neu erzeugt werden muss.
2611. [x] [P1] Lautheits-Prüfung tools/audio/loudness.py mit ffmpeg ebur128: Musik soll -16 LUFS (±1) erreichen, Klänge einen Spitzenwert von -3 dBFS; Abweichungen werden gemeldet.
2612. [x] [P1] gen_audio.py normalisiert jede Datei nach dem Erzeugen automatisch auf diese Zielwerte.
2613. [x] [P1] Neuer Generator tools/art/gen_fx.py erzeugt die Effekt-Formen (Funke, Tropfen, Blatt, Zacke, Brocken, Strich, Glanz, Schatten) als 8×8-Bildchen in art/era1/fx/ in den 4 Paletten-Farben.
2614. [P2] Neuer Generator tools/art/gen_ui.py erzeugt Gefühls-Blasen, Toast-Rahmen, Punkt-Markierungen und Cursor als kleine PNGs in art/era1/ui/.
2615. [P2] Eine Prüfung der Wiederholbarkeit: gen_audio.py und alle tools/art-Generatoren werden in der CI zweimal laufen gelassen und die Prüfsummen der Ausgaben verglichen.
2616. [P2] gen_audio.py schreibt Schleifenpunkte (Start und Ende in Samples) pro Stück in tools/audio/loops.json, aus der Sound.gd und die .import-Dateien lesen.
2617. [P2] Ein Notentext-Leser in tools/audio/music.py liest Stücke aus tools/audio/songs/*.txt (Akkorde, Motive, Tempo, Tonart) statt aus Python-Wörterbüchern.
2618. [P2] Ein Werkzeug tools/audio/preview.py spielt ein einzelnes Stück oder einen Klang direkt ab oder schreibt eine kurze Probe von 10 Sekunden.
2619. [P2] gen_audio.py erzeugt Einzelspuren (stems) und Übergangstakte für MusicDirector im selben Lauf wie die Vollfassung.
2620. [P2] Neue Wellenform "Rauschen mit Tonhöhe" (periodisches Rauschen) und "weiche Pulswelle" in synth.py für Umgebungsklänge und ruhige Stücke.
2621. [P2] Ein einfacher Hall (Kammfilter plus Allpass) in synth.py, damit Klänge schon in der Datei Raum haben können, abschaltbar pro Klang.
2622. [P2] Ein Werkzeug tools/art/sheet.py setzt Einzelbilder zu Frame-Streifen zusammen und schreibt die Frame-Maße in eine kleine JSON-Datei daneben.
2623. [P2] gen_tiles.py bekommt die neuen Tiles für Gras-Rascheln, Tür-Öffnen und Wasser-Ringe als zusätzliche Frames.
2624. [P2] Ein Werkzeug tools/art/fx_preview.py zeigt alle Effekt-Formen und UI-Bildchen in 4-facher Größe als ein Übersichtsbild in tools/art/out/.
2625. [P2] Alle Generatoren bekommen am Dateianfang einen Abschnitt "Herkunft", der erklärt, dass jede Form und jede Note selbst geschrieben ist.
2626. [P2] tools/audio/README in den Dateikopf von gen_audio.py verschieben: benötigte Pakete (numpy, ffmpeg), Aufruf und Ausgabeorte.
2627. [P3] Eine Make-artige Übersicht tools/build_assets.sh ruft alle Art- und Audio-Generatoren in der richtigen Reihenfolge auf.
2628. [P2] Die Ausgaben der Generatoren landen nur in art/ und audio/, nie an anderen Orten; ein Test prüft das nach dem Lauf mit git status.
2629. [P3] Ein Werkzeug tools/audio/spectrum.py zeichnet ein Spektrum jedes Klangs als PNG, um zu harte Höhen zu finden.
2630. [P3] Ein Werkzeug tools/audio/cry_export.py schreibt alle zur Laufzeit erzeugten Schreie (Cry.gd-Logik in Python nachgebaut) als WAV, um sie anzuhören und zu prüfen.
2631. [P3] gen_audio.py misst die Gesamtgröße aller Audio-Ausgaben und schreibt sie in tools/audio/sizes.json, damit Änderungen sichtbar werden.
2632. [P3] Ein Werkzeug tools/art/anim_preview.py baut aus Frame-Streifen ein animiertes GIF zur schnellen Ansicht außerhalb von Godot.
2633. [P3] Generatoren laufen auch ohne Grafikkarte und Tonausgabe, damit sie in der CI (headless) funktionieren.
2634. [P3] Eine kleine Formbibliothek in tools/art/px.py mit Kreis, Ring, Stern und Zacke in Pixelgenauigkeit, damit Effekte und UI-Bildchen dieselben Grundformen nutzen.

### docs/ASSET_LOG.md und Herkunftsnachweis
2635. [x] [P1] Jede neue Datei aus diesem Bereich (fx, ui, ambience, stems, neue Stücke und Klänge) bekommt eine eigene Zeile in docs/ASSET_LOG.md, bevor sie eingecheckt wird.
2636. [x] [P1] Neues Werkzeug tools/asset_log.py erzeugt die Zeilen für alle Generator-Ausgaben automatisch aus einer Tabelle (Pfad, Generator, Beschreibung) und ergänzt fehlende.
2637. [x] [P1] tools/ip_check.sh prüft zusätzlich, dass jeder Generator, der in einer ASSET_LOG-Zeile genannt ist, auch im Repo existiert.
2638. [P2] Jede neue Musik-Zeile nennt in der Spalte "How it was made" den Notentext unter tools/audio/songs/ und den Satz "Melodie und Akkorde eigen geschrieben".
2639. [P2] ASSET_LOG.md bekommt eine zusätzliche Spalte "Generator-Stand" mit dem Commit-Kürzel, aus dem die Datei zuletzt erzeugt wurde.
2640. [P2] ASSET_LOG.md wird nach Ordnern gegliedert (art/era1/spirlings, chars, tiles, fx, ui, icon; audio/music, stems, sfx, ambience), mit je einer Überschrift.
2641. [P2] Ein Abschnitt "Laufzeit-Klänge" in ASSET_LOG.md beschreibt die Schreie aus Cry.gd und die Text-Stimme, die keine Dateien haben.
2642. [P3] Ein Abschnitt "Laufzeit-Grafik" beschreibt alle im Code gezeichneten Effekte (ElementFx, PixelParticles, Shader) mit Datei und Zweck.
2643. [P2] Jede Shader-Datei unter shaders/ bekommt eine Zeile in ASSET_LOG.md mit Zweck und dem Hinweis, dass sie selbst geschrieben ist.
2644. [P2] ip_check.sh prüft, dass jede Datei unter audio/ambience/ und audio/music/stems/ eine Zeile hat (Ausweitung der bestehenden Prüfung auf neue Ordner).
2645. [P2] ip_check.sh prüft, dass in tools/audio/songs/ keine Titel, Namen oder Wörter aus der Sperrliste stehen.
2646. [P2] Pro neuem Stück eine kurze Hörprobe-Notiz in docs/MUSIC.md, wer es angehört und als eigenständig bestätigt hat, mit Datum.
2647. [P3] ASSET_LOG.md bekommt am Anfang eine Zusammenfassung mit Anzahl der Dateien pro Ordner und Gesamtgröße, erzeugt von tools/asset_log.py.
2648. [P3] Eine CI-Prüfung bricht ab, wenn eine Datei in art/ oder audio/ neuer ist als ihr Generator-Stand in ASSET_LOG.md und nicht aus dem Generator stammt.
2649. [P3] Für jede Effekt-Form und jedes UI-Bildchen wird im Log vermerkt, aus welcher Grundform in tools/art/px.py es entsteht.
2650. [P3] Gelöschte Assets werden nicht stillschweigend entfernt, sondern im Abschnitt "Entfernt" mit Datum und Grund aufgeführt.
2651. [P3] Eine englische Kurzfassung der Herkunftsregeln am Anfang von ASSET_LOG.md, damit spätere externe Mitwirkende sie verstehen.
2652. [P3] tools/asset_log.py kann mit --check laufen und gibt nur Fehler aus, ohne die Datei zu ändern, für die CI.

### Leistung und Zugänglichkeit der Darstellung
2653. [x] [P1] Einstellung "Klang-Untertitel": wichtige Klänge (Wanderer entdeckt, Rift in der Nähe, Begegnung, Gegenstand) erscheinen als kurzer Text am oberen Rand, zum Beispiel "[Rascheln im Gras]".
2654. [P1] Leistungsziel für alle Punkte dieses Bereichs: auf dem schwächsten Ziel-Android-Gerät höchstens 2 ms zusätzliche Bildzeit im Kampf und 1 ms in der Welt.
2655. [x] [P1] Alle neuen Bewegungen respektieren die bestehende Einstellung reduce_motion über Juice.reduced(); ein GUT-Test schaltet sie ein und prüft, dass kein Tween länger als 0,15 s läuft.
2656. [x] [P1] (tools/fx_flash_check.tscn im UI-Golden-Job) Kein Effekt dieses Bereichs wechselt die Helligkeit mehr als 3 Mal pro Sekunde um mehr als 2 Palettenstufen; ein Test prüft die Effekt-Galerie Bild für Bild.
2657. [P2] Partikel, Wackeln und Shader-Übergänge werden im Energiesparmodus des Geräts (wenn das System ihn meldet) automatisch auf die ruhige Fassung gesetzt.
2658. [P2] Visuelle Takt-Hilfe im Echo-Minispiel ist schon da; zusätzlich zeigt jede Marke beim Abspielen einen kurzen Ring, damit es auch ohne Ton lösbar bleibt.
2659. [P2] Text-Stimme und Schreie können im Hochkontrast-Modus durch eine kleine Schallwellen-Markierung neben dem Sprecher ergänzt werden.
2660. [P2] Die Musik-Schichten und Umgebungsklänge schalten bei Musik-Lautstärke 0 komplett ab (keine laufenden Ströme), um Akku zu sparen.
2661. [P2] Die Effekt-Galerie läuft in der CI über tools/screenshot.gd und vergleicht je ein Bild pro Element mit einem Referenzbild, damit Änderungen auffallen.
2662. [P2] Shader (rift_wipe, iris, sheen) haben eine einfache Fassung für den GL-Compatibility-Renderer und werden auf beiden Renderern getestet.
2663. [P3] Die Bildzeit von Juice, PixelParticles und ElementFx wird im Debug-Overlay als eigene Zeile in Millisekunden angezeigt.
2664. [P3] Einstellung "Klang-Untertitel" erweitert sich um Umgebungsklänge (Meer, Wind, Summen), wenn eine zweite Stufe "Ausführlich" gewählt ist.
2665. [P3] Linkshänder-Spiegelung der Toast- und Hinweis-Position (rechts statt links), passend zur Spiegelung der Bildschirm-Steuerung.
2666. [P3] Lautstärke-Begrenzer für Kopfhörer in den Einstellungen (Musik und Klänge zusammen höchstens -6 dB), für Kinder.
2667. [P3] Prüfliste docs/JUICE_CHECK.md für jeden neuen PR in diesem Bereich: Kurve benannt, reduce_motion beachtet, Haptik-Muster gewählt, Klang im ASSET_LOG, Bildzeit gemessen.
2668. [P3] Ein Spieltest mit 5 Personen bewertet vor und nach dem Spielgefühl-Paket die Sätze "Treffer fühlen sich kräftig an" und "Menüs fühlen sich flüssig an" auf einer Skala von 1 bis 5.
