# Bereich 8: Langzeitmotivation, Endgame und Ereignisse

Teil des 5000-Punkte-Plans, siehe [../PLAN_5000.md](../PLAN_5000.md). Punkte 3113 bis 3556.

> **Auftrag für den umsetzenden Thread:** Ziel ist, dass Spieler nach dem Ende von Akt I über Monate einen Grund haben, Chimora zu öffnen, und dass sie dabei eine Währung bekommen, die man nur durch Spielen verdient. Betroffen sind vor allem scripts/core/ (Achievements.gd, Collection.gd, Season.gd, WeeklyChallenge.gd und neue Dateien wie Waymarks.gd, DailyTasks.gd, Endgame.gd), scripts/overworld/ (Gauntlet.gd, DailyFind.gd, Overworld.gd), neue Daten unter data/ (achievements.json, events.json, endgame.json) und die Tests unter tests/unit/. Fang mit der Wegmarken-Währung und den Tagesaufträgen an, denn fast alle anderen Punkte zahlen in Wegmarken aus. Premium-Währung, Kaufangebote und Preise gehören zu Bereich 10, Online-Ligen zu Bereich 7 und neue Story-Kapitel zu Bereich 4; Herausforderungsregeln, Bosskämpfe und Turm-Kampfregeln aus docs/KAMPF_PLAN_1000.md werden hier nicht neu geplant.

### Wegmarken: die erspielte Endgame-Währung
3113. [x] [P1] Eine neue Währung „Wegmarken“ (englisch „Waymarks“) einführen, die in GameState.waymarks als ganze Zahl gespeichert wird und nur durch Spielen steigt.
3114. [x] [P1] Eine neue Datei scripts/core/Waymarks.gd anlegen, die alle Gutschriften über eine einzige Funktion earn(amount, source) laufen lässt.
3115. [x] [P1] Jede Gutschrift mit Quelle und Datum in GameState.records["waymark_log"] festhalten, höchstens die letzten 200 Einträge.
3116. [x] [P1] Die Obergrenze für gehaltene Wegmarken auf 9999 setzen und überzählige Marken mit einem kurzen Hinweis verfallen lassen.
3117. [x] [P1] Wegmarken im Pausenmenü neben den Münzen anzeigen, mit eigenem 8x8-Symbol in Form eines kleinen Wegsteins.
3118. [x] [P1] Festlegen und in docs/BALANCE.md eintragen, dass ein aktiver Spieler im Schnitt 60 Wegmarken pro Tag und 500 pro Woche verdient.
3119. [x] [P1] Wegmarken beim Laden alter Spielstände mit 0 anlegen und die Nachzahlung für alte Erfolge nur über den Erfolgs-Lohn laufen lassen, nicht doppelt.
3120. [x] [P1] In docs/MONETIZATION.md und im Code festschreiben, dass Wegmarken nie gekauft, getauscht oder an Freunde geschickt werden können.
3121. [x] [P1] Wegmarken in jeder Belohnungsmeldung mit Zahl und Symbol nennen, zum Beispiel „+10 Wegmarken“.
3122. [P2] Den Server beim Speichern prüfen lassen, dass die Wegmarken seit dem letzten Stand um höchstens 800 pro Tag gestiegen sind, sonst wird der Stand markiert.
3123. [P2] Ein Wegmarken-Verlaufsfenster bauen, das die letzten 30 Gutschriften mit Quelle zeigt (zum Beispiel „Tagesauftrag: 10“).
3124. [P2] Einen Test schreiben, der prüft, dass jede Belohnungsquelle im Spiel eine gültige Quelle in Waymarks.SOURCES nutzt.
3125. [P2] Wegmarken nach einer Niederlage nie abziehen, anders als die Hälfte der Münzen.
3126. [P2] Ein Sparziel im Pausenmenü einstellen lassen (ein Angebot des Tauschstands), das als Balken den fehlenden Betrag zeigt.
3127. [P2] Den Wegmarken-Stand auf der Spielstandkarte im Titelbild neben Spielzeit und Spirlog-Zahl zeigen.
3128. [P3] Einen Jahresrückblick der verdienten Wegmarken nach Quelle in den Aufzeichnungen zeigen.
3129. [P3] Beim Eisernen Schwur alle Wegmarken-Gutschriften um 25 Prozent erhöhen und den Bonus in der Gutschrift ausweisen.
3130. [x] [P3] Erfolge „Sparsam“ für 5000 und „Wegkundig“ für 50000 insgesamt verdiente Wegmarken ergänzen.
3131. [P3] Eine Lexikonseite „Wegmarken“ anlegen, die alle Quellen mit Betrag und Häufigkeit aus der Belohnungstabelle zeigt.

### Wegmarken-Tauschstand und Münzen-Kreislauf
3132. [x] [P1] Im Erdgeschoss des Leuchtturms einen Tauschstand bei einer neuen Figur „Marla die Tauscherin“ aufstellen, der nur Wegmarken annimmt.
3133. [x] [P1] Das Angebot des Tauschstands in data/endgame.json pflegen, mit Gegenstand, Preis in Wegmarken und Vorrat pro Woche.
3134. [x] [P1] Echo-Kristalle aller acht Elemente für je 150 Wegmarken anbieten, höchstens einen pro Element und Woche.
3135. [x] [P1] Das Funkenamulett (spark_charm) für 120 Wegmarken und die Gezeitenperle (tide_pearl) für 200 Wegmarken anbieten, je zweimal pro Woche.
3136. [x] [P1] Den Tauschstand schon nach dem ersten versiegelten Riss mit sechs Grundangeboten öffnen und das volle Angebot nach dem Ende von Akt I freischalten.
3137. [x] [P1] Jedes Angebot vor dem Kauf mit Wirkung, Preis und Besitzzahl zeigen und jeden Tausch mit einer Ja-Nein-Frage bestätigen lassen.
3138. [P2] Vier neue Jackenfarben für den Wanderer zu je 300 Wegmarken anbieten, die dauerhaft freigeschaltet bleiben.
3139. [P2] Sechs Fotorahmen für den Fotomodus zu je 100 Wegmarken anbieten.
3140. [P2] Den Vorrat des Tauschstands jeden Montag nach Server-Zeit auffüllen und die Restzeit am Stand anzeigen.
3141. [P2] Eine Wochenauswahl mit drei wechselnden Angeboten aus einer festen, offen sichtbaren Liste anbieten, gezogen per Seed aus der Wochennummer.
3142. [P2] Die ganze Liste möglicher Wochenangebote am Stand einsehbar machen, damit nichts zufällig oder verdeckt ist.
3143. [P2] Münzen-Ausgaben ausbauen: einen Spendenkasten im Rathaus von Brindlewick bauen, der Münzen für Stadtprojekte annimmt.
3144. [P2] Fünf Stadtprojekte in Brindlewick anlegen (Brunnen 5000, Laternenreihe 10000, Bootssteg 20000, Gartenbeete 30000, Leuchtturmglas 50000 Münzen), die das Stadtbild sichtbar verändern.
3145. [P2] Jedes fertige Stadtprojekt mit einer dauerhaften Kleinigkeit belohnen, etwa einer zusätzlichen Rastquelle am Bootssteg.
3146. [P2] Den Erfolg „Full Purse“ ab 10000 Münzen beibehalten und einen zweiten Erfolg für 100000 insgesamt gespendete Münzen ergänzen.
3147. [P2] Ein Wachstumsbonbon für 60 Wegmarken anbieten, das einem Spirling Wachstum für genau einen Ring gibt, höchstens bis zum Ring-Deckel und dreimal pro Woche.
3148. [P2] Ein Wanderer-Zimmer im Obergeschoss des Leuchtturms freischalten, das man mit 20 Möbelstücken zu je 50 bis 250 Wegmarken einrichtet.
3149. [P2] Im Wanderer-Zimmer bis zu drei Spirlings aus dem Lager als Mitbewohner zeigen, die dort herumlaufen.
3150. [P3] Einen Tausch von 1000 Münzen in 10 Wegmarken anbieten, höchstens 50 Marken pro Woche, damit volle Münzbeutel nützlich bleiben.
3151. [P3] Einen Rückkauf am Tauschstand erlauben: ein gekaufter Gegenstand kann 24 Stunden lang zum vollen Preis zurückgegeben werden.
3152. [P3] Zum Abschluss aller fünf Stadtprojekte ein Stadtfest-Bild für den Fotomodus freischalten.
3153. [P3] Die Münzpreise im Laden nach dem Ende von Akt I nicht anheben, damit das Endgame keinen versteckten Münzdruck hat.
3154. [P3] Einen Erfolg „Gemütlich“ für ein Wanderer-Zimmer mit allen 20 Möbelstücken ergänzen.
3155. [P3] Das Wanderer-Zimmer im Fotomodus als eigenen Ort mit festem Bildausschnitt anbieten.

### Tagesaufträge
3156. [x] [P1] Eine Datei scripts/core/DailyTasks.gd anlegen, die jeden Tag nach Server-Zeit drei Aufträge aus data/events.json per Seed „chimora-tasks-JJJJ-MM-TT“ zieht.
3157. [x] [P1] Jeder Tagesauftrag zahlt 10 Wegmarken, alle drei zusammen zahlen 10 Wegmarken extra.
3158. [x] [P1] Mindestens 30 Auftragsarten anlegen, zum Beispiel „Gewinne 3 Kämpfe in Thornridge“, „Bonde einen Spirling des Elements Gale“ oder „Raste an 2 Rastquellen“.
3159. [x] [P1] Tagesaufträge im Ziele-Bildschirm unter dem Fund des Tages als eigenen Block mit Fortschritt (k/n) zeigen.
3160. [x] [P1] Aufträge nur aus Orten ziehen, die der Spielstand schon erreicht hat, damit kein Auftrag unlösbar ist.
3161. [x] [P1] Jeden Auftrag so wählen, dass er in höchstens 15 Minuten Spielzeit zu schaffen ist.
3162. [x] [P1] Den Fortschritt jedes Tagesauftrags im Spielstand und auf dem Server speichern, damit ein Gerätewechsel am selben Tag nichts zurücksetzt.
3163. [P2] Einen Auftrag pro Tag einmal kostenlos gegen einen anderen tauschen lassen.
3164. [x] [P2] Nicht erledigte Aufträge verfallen still um Mitternacht, ohne Strafe und ohne Serien-Zähler.
3165. [P2] Eine Auftragsart „Zeig dem Fotomodus einen Spirling bei Nacht“ ergänzen, damit Aufträge nicht nur Kämpfe sind.
3166. [P2] Eine Auftragsart „Spiele das Echo-Melodie-Spiel mit der Wertung Gut oder besser“ ergänzen.
3167. [P2] Eine Auftragsart „Sieh einen noch nicht gesehenen Spirling“ nur dann ziehen, wenn noch ungesehene Arten im erreichbaren Gebiet leben.
3168. [P2] Den Fund des Tages (DailyFind) als eigenen Auftrag zählen lassen, wenn er an dem Tag im Pool landet.
3169. [x] [P2] Beim Abschluss eines Auftrags einen kurzen Hinweis oben im Bild zeigen, der den Kampf oder die Erkundung nicht anhält.
3170. [P2] Nach dem Ende von Akt I einen vierten, schwereren Auftrag mit 25 Wegmarken freischalten.
3171. [P2] Für jede Auftragsart einen GUT-Test schreiben, der den Fortschritt aus einem nachgestellten Spielereignis zählt.
3172. [P2] Die Aufträge in data/i18n/de.json mit Platzhaltern für Zahl, Ort und Element übersetzen.
3173. [P2] Eine Auftragsart „Schick einen Spirling auf einen Streifzug“ ergänzen, sobald Streifzüge freigeschaltet sind.
3174. [x] [P2] Pro Tag höchstens einen Kampfauftrag ziehen, damit jeder Tag eine Erkundungs- oder Sammelaufgabe enthält.
3175. [P3] Einen Wochenauftrag ergänzen, der aus sieben erledigten Tagesaufträgen in derselben Woche besteht und 50 Wegmarken zahlt.
3176. [P3] Aufträge mit Tageszeit-Bezug ziehen, etwa „Triff bei Dämmerung einen Lumen-Spirling“, nur wenn Tag und Nacht eingeschaltet sind.
3177. [P3] Einen Auftragsverlauf der letzten 14 Tage in den Aufzeichnungen zeigen.
3178. [x] [P3] Einen Erfolg „Fleißig“ für 100 erledigte Tagesaufträge und „Unermüdlich“ für 500 ergänzen.
3179. [P3] Aufträge, die zwei Tage hintereinander gezogen würden, durch die nächste Art ersetzen.
3180. [P3] Den Auftrag „Zeig einem Dorfbewohner einen Spirling“ an die bestehenden Seitenfiguren (Fischer, Wanderin, Schilfschneider) binden, auch nach erledigtem Seitenziel.
3181. [P3] Am Sonntag einen Ruheauftrag ziehen, der nur aus Rasten, Fotografieren oder einem Besuch im Wanderer-Zimmer besteht.
3182. [P3] Für Aufträge in Gebieten mit Era-Wechsel die Ortsnamen aus der aktuellen Era-Karte nehmen.

### Wochen-Echo ausbauen
3183. [x] [P1] Die Wochenherausforderung zusätzlich mit 60 Wegmarken beim ersten Sieg der Woche belohnen, neben den 400 Münzen.
3184. [x] [P1] Die Wochenherausforderung von 3 auf 5 Runden erweitern und den Belohnungswert für Runde 4 und 5 als Zwischenpreis auszahlen.
3185. [x] [P1] Nach jeder Runde im Wochen-Echo eine Zwischenwertung zeigen: Züge, übrige Kraft und erschöpfte Spirlings.
3186. [x] [P1] Das Wochen-Echo nicht mehr an den stärksten eigenen Spirling, sondern an den Ring-Deckel binden, damit alle in derselben Woche dieselben Gegnerringe sehen.
3187. [P2] Eine Wochen-Bestwertung aus Zügen und übriger Kraft in GameState.records["weekly_best"] speichern.
3188. [P2] Für eine Wertung unter einem festen Zielwert der Woche einen Bonus von 20 Wegmarken zahlen.
3189. [P2] Eine Wochenvorschau am Brett zeigen: Feld, Regel und die Elemente der drei ersten Echo-Teams.
3190. [P2] Die letzten acht Wochen mit Feld, Regel und eigenem Ergebnis in einem Archiv anzeigen.
3191. [P2] Den Gegenstandspreis aus WeeklyChallenge.REWARDS um die vier Kraftwerkzeuge erweitern, damit die Liste auf 12 Einträge wächst.
3192. [P2] Im Wochen-Echo verbietet ein Leihteam-Modus eigene Spirlings und stellt ein festes Team von drei Spirlings für alle.
3193. [P2] Den Leihteam-Modus jede zweite Woche statt des normalen Modus anbieten und das am Brett ankündigen.
3194. [P2] Leihteams in data/events.json mit Art, Ring und Techniken festlegen, mindestens 12 Teams.
3195. [P2] Einen Wochensieg auch nach einem Teilerfolg werten: ab Runde 3 gibt es 30 Wegmarken, ab Runde 5 die vollen 60.
3196. [P2] Pro Woche drei Versuche mit voller Belohnung erlauben und weitere Versuche nur für die Bestwertung zählen.
3197. [P3] Eine Wochen-Sonderregel „Gleicher Ring“ ergänzen, bei der alle Spirlings beider Seiten auf Ring 40 gesetzt werden.
3198. [P3] Die Zahl der gewonnenen Wochen in einem Erfolg zählen: 4, 12 und 52 Siege.
3199. [P3] Ein kleines Abzeichen für jede Kalenderwoche mit Sieg in einem Jahresraster in den Aufzeichnungen zeigen.
3200. [P3] Den Leihteam-Modus mit einer Rangfolge der eigenen fünf besten Wochen ergänzen, nur lokal.
3201. [P3] Für das Wochen-Echo eine Wiederholung des besten Laufs über den gespeicherten Seed anbieten.
3202. [P3] Den Start eines Wochenlaufs am Brett mit einer kurzen Melodie aus audio/ untermalen, die nur dort spielt.
3203. [P3] Einen Hinweis im Ziele-Bildschirm zeigen, wenn die Woche in weniger als 24 Stunden endet und noch kein Sieg da ist.
3204. [P3] Ein Wochenmotto aus 20 festen Sätzen am Brett zeigen, das zur Regel der Woche passt.
3205. [P3] Den Gewinn eines Wochen-Echos auf dem Speicherslot mit der Zahl der Wochensiege zeigen.

### Feste ausbauen
3206. [x] [P1] Die Festdaten aus Season.FESTIVALS nach data/events.json verschieben, damit neue Feste ohne Codeänderung dazukommen.
3207. [x] [P1] Während jedes Festes eine Festwährung „Festbänder“ ausgeben: 3 pro gewonnenem Kampf gegen Spirlings der Festelemente.
3208. [x] [P1] Am Festende alle übrigen Festbänder automatisch 1 zu 1 in Wegmarken umwandeln, damit nie etwas verloren geht.
3209. [x] [P1] Pro Fest einen Festhändler in Brindlewick aufstellen, der Festbänder gegen festbezogene Dinge tauscht.
3210. [x] [P1] Jedem Fest eine eigene Festaufgabe mit 5 Stufen geben (zum Beispiel 10, 25, 50, 100, 200 Festbänder gesammelt), die je 30 Wegmarken zahlt.
3211. [x] [P1] Den Ausrufer in Brindlewick bei jedem Fest einen Festauftrag pro Tag geben lassen, der 5 Festbänder zahlt.
3212. [x] [P1] Festbänder in GameState.festival_ribbons getrennt pro Fest führen und im Pausenmenü nur während des Festes anzeigen.
3213. [P2] Brindlewick während des Blütenmarkts mit Blumenkästen schmücken, die als eigene Kacheln in den Era-I-Stil passen.
3214. [P2] Brindlewick während der Laternennächte mit Papierlaternen schmücken, die nachts leicht leuchten.
3215. [P2] Während der Gezeitentage am Strand von Saltmarsh ein kleines Wettrennen der Krebse als Minispiel mit Antippen aufbauen.
3216. [P2] Während der Herdwochen am Rathausplatz ein Feuerbecken aufstellen, an dem man einmal am Tag sein Team heilen kann.
3217. [P2] Für jedes Fest zwei festbezogene Jackenmuster beim Festhändler für 40 Festbänder anbieten.
3218. [P2] Für jedes Fest einen Fotorahmen beim Festhändler für 20 Festbänder anbieten.
3219. [P2] Für jedes Fest eine eigene Festmusik als Abwandlung der Brindlewick-Melodie in audio/ anlegen und in data/music.json eintragen.
3220. [P2] Feste, die ein Spieler schon einmal gefeiert hat, im nächsten Jahr mit einer neuen Stufe der Festaufgabe fortsetzen.
3221. [P2] Die Festgeschenke des Ausrufers pro Jahr wechseln lassen, aus einer offenen Liste von vier Gegenständen pro Fest.
3222. [P2] Im Ziele-Bildschirm Festname, Restdauer in Tagen und Festbänder-Stand zeigen.
3223. [P2] Zwischen den Festen den Ausrufer das nächste Fest mit Startmonat ankündigen lassen, wie bisher, und zusätzlich die Festelemente nennen.
3224. [P2] Einen Test schreiben, der für jeden Monat prüft, dass höchstens ein Fest läuft.
3225. [P2] Während jedes Festes den Wanderhändler ein festbezogenes Angebot gegen Festbänder führen lassen.
3226. [P2] Am ersten Festtag einen kurzen Hinweis beim Spielstart zeigen, der Fest, Elemente und Festhändler nennt.
3227. [P3] Ein fünftes Fest „Sturmtage“ im März für Gale und Volt ergänzen, mit eigenem Schmuck in Crowcrest.
3228. [P3] Ein sechstes Fest „Erntezeit“ im September für Bloom und Stone ergänzen, mit Marktständen in Fernstair.
3229. [P3] Am Jahrestag des Kontos ein kleines persönliches Fest mit 50 Wegmarken und einem Kuchen-Bild im Fotomodus feiern.
3230. [P3] Während der Laternennächte nachts eine Laternenwanderung in Murk Hollow mit 8 versteckten Laternen anbieten.
3231. [P3] Während des Blütenmarkts in Fernstair eine Blumensuche mit 10 versteckten Blüten anbieten.
3232. [P3] Während der Herdwochen eine Schneelandschaft in Thornridge als eigene Kachelvariante zeigen.
3233. [P3] Ein Festtagebuch in den Aufzeichnungen anlegen, das jedes gefeierte Fest mit Jahr und Festaufgaben-Stufe listet.
3234. [P3] Die Festdekorationen beim Fotomodus mit einem Schalter ausblendbar machen.
3235. [P3] Für das Fest der Gezeitentage einen Sandburg-Platz am Saltmarsh-Strand bauen, an dem man aus Muscheln eine Burg in 5 Stufen setzt.
3236. [P3] Pro Fest einen Erfolg für die höchste Stufe der Festaufgabe ergänzen.

### Freier Jahreszeitenpfad
3237. [x] [P1] Einen Jahreszeitenpfad mit 30 Stufen pro Jahreszeit (je drei Monate) anlegen, der nur durch Spielen voranschreitet.
3238. [x] [P1] Pfadpunkte nur aus Tagesaufträgen (10 pro Auftrag), Wochen-Echo (40) und Festaufgaben (20) vergeben, 100 Punkte pro Stufe.
3239. [x] [P1] Jede Stufe mit einer festen, vorher sichtbaren Belohnung belegen: Münzen, Wegmarken, Gegenstände oder Kosmetik.
3240. [x] [P1] Den ganzen Pfad mit allen 30 Belohnungen vor dem Start einsehbar machen.
3241. [P2] Die Stufen 10, 20 und 30 mit einer besonderen Belohnung belegen: Jackenmuster, Fotorahmen und ein Spirling-Halstuch als Kosmetik.
3242. [P2] Die Zielzeit so legen, dass Stufe 30 mit 4 Tagen Spiel pro Woche in 11 Wochen erreichbar ist.
3243. [P2] Pfadbelohnungen nach Saisonende 14 Tage lang nachholbar machen, wenn die Stufe erreicht, aber nicht abgeholt wurde.
3244. [P2] Nach Stufe 30 jede weitere Stufe mit 20 Wegmarken belohnen, ohne neue Kosmetik.
3245. [P2] Den Pfad als eigenen Reiter im Ziele-Bildschirm zeigen, mit Balken und der nächsten Belohnung.
3246. [P2] Die Pfaddaten jeder Jahreszeit in data/events.json mit Saison-Id wie „2027-Q1“ ablegen.
3247. [P2] Kosmetik aus einem vergangenen Pfad zwei Jahre später im Wegmarken-Tauschstand wieder anbieten.
3248. [P2] Diesen Pfad ausdrücklich als freien Pfad anlegen; ob es eine bezahlte Spur dazu gibt, entscheidet Bereich 10, nicht dieser Bereich.
3249. [P2] Den Jahreszeitenpfad an den Jahreszeiten des Kalenders ausrichten (März, Juni, September, Dezember) und den Start nach Server-Zeit setzen.
3250. [P3] Eine Pfadvorschau der nächsten Jahreszeit zwei Wochen vor deren Start zeigen.
3251. [P3] Einen Erfolg für jeden voll abgeschlossenen Jahreszeitenpfad ergänzen.
3252. [P3] Pfadpunkte im Eisernen Schwur nicht erhöhen, damit der Pfad für alle gleich lang bleibt.
3253. [P3] Eine Pfad-Statistik zeigen: Punkte pro Quelle in dieser Jahreszeit.
3254. [P3] Den Pfad für neue Spieler erst ab dem Ende von Kapitel 2 freischalten, damit der Einstieg nicht überladen wirkt.
3255. [P3] Pfadgrafiken pro Jahreszeit im Stil der aktuellen Era zeichnen und in docs/ASSET_LOG.md eintragen.
3256. [P3] Jede Jahreszeit mit einem eigenen Pfadmotiv versehen, das zum Fest dieser Jahreszeit passt.

### Leuchtturm-Treppe und Herausforderungs-Türme
3257. [x] [P1] Die Leuchtturm-Treppe (Gauntlet) von 5 Runden auf 30 Stockwerke erweitern, aufgeteilt in drei Abschnitte zu je 10 Stockwerken.
3258. [x] [P1] Nach jedem zehnten Stockwerk einen Rastpunkt einbauen, an dem man den Lauf speichert und später fortsetzt.
3259. [x] [P1] Den Lauf zwischen zwei Rastpunkten ohne Heilung führen, wie heute bei den 5 Runden.
3260. [x] [P1] Jedes erstmals erreichte Stockwerk einmalig mit 5 Wegmarken belohnen, jedes zehnte mit 50.
3261. [x] [P1] Den besten Stand als „Stockwerk x von 30“ statt „x von 5“ in GameState.records["gauntlet_best"] speichern und alte Werte übernehmen.
3262. [x] [P1] Die Ringe der Echo-Gegner pro Stockwerk an den Ring-Deckel binden statt an den stärksten eigenen Spirling, damit Hochziehen nichts nützt.
3263. [x] [P1] Beim ersten Betreten der neuen Leuchtturm-Treppe den Spieler mit einem Satz über Rastpunkte und fehlende Heilung aufklären.
3264. [P2] Nach Stockwerk 30 eine Endlosstrecke öffnen, deren Gegner pro Stockwerk einen Ring stärker werden bis Ring 60.
3265. [P2] Die Endlosstrecke wöchentlich mit 2 Wegmarken pro neuem Stockwerk belohnen, höchstens 100 pro Woche.
3266. [P2] Einen zweiten Turm „Glutstiege“ im Cinder Rift nach dem Versiegeln öffnen, in dem nur Ember-, Stone- und Volt-Gegner kämpfen, 15 Stockwerke.
3267. [P2] Einen dritten Turm „Gezeitenschacht“ im Tidewater Rift öffnen, mit Tide-, Bloom- und Umbra-Gegnern, 15 Stockwerke.
3268. [P2] Im Gezeitenschacht nach unten statt nach oben zählen und den Hintergrund pro Abschnitt dunkler färben.
3269. [P2] In beiden Rift-Türmen nur Teams mit höchstens drei Spirlings zulassen, damit sie sich von der Leuchtturm-Treppe abheben.
3270. [P2] Eine Turmkarte im Menü zeigen, die alle drei Türme mit bestem Stockwerk und nächster Belohnung listet.
3271. [P2] Pro Turm einen Erfolg für den vollen Aufstieg ergänzen: „Glutfest“ und „Tiefgänger“.
3272. [P2] Turmläufe beim Verbindungsabbruch am letzten Stockwerk fortsetzen, statt den Lauf zu werten.
3273. [P2] Echo-Gegner im Turm mit Namen aus einer eigenen Liste von 40 Wanderernamen in data/endgame.json versehen.
3274. [P2] Pro Turm eine Wochenbelohnung von 30 Wegmarken für das Erreichen eines festen Ziel-Stockwerks der Woche vergeben.
3275. [P2] In der Glutstiege und im Gezeitenschacht nur Spirlings ab Ring 30 zulassen und das am Eingang zeigen.
3276. [P3] Einen vierten Turm „Windspitze“ in Crowcrest für Gale-, Lumen- und Stone-Gegner mit 15 Stockwerken bauen.
3277. [P3] In der Leuchtturm-Treppe jedes fünfte Stockwerk zu einem Ruhegeschoss machen, auf dem ein Händler einen von drei Gegenständen schenkt.
3278. [P3] Die Wahl im Ruhegeschoss aus einer offenen Liste ziehen und alle drei Möglichkeiten vor der Wahl zeigen.
3279. [P3] Einen Turm-Rückblick nach jedem Lauf zeigen: Stockwerke, Züge, eingesetzte Spirlings.
3280. [P3] Den Turmlauf mit einem Zeitstempel für den eigenen Bestwert speichern, nur lokal.
3281. [P3] Für jeden Turm einen eigenen Stockwerk-Hintergrund in der jeweiligen Era-Grafik zeichnen.
3282. [P3] Den Turmeingang auf der Weltkarte erst zeigen, wenn der zugehörige Rift versiegelt ist.
3283. [P3] Bei vollem Aufstieg aller vier Türme den Titel-Hintergrund des Leuchtturms mit einem zusätzlichen Lichtstrahl schmücken.
3284. [P3] Den Turmrekord jedes Turms auf der Fotowand im Leuchtturm als kleine Tafel zeigen.
3285. [P3] Für Spieler, die ein Turm-Stockwerk dreimal verloren haben, am Rastpunkt einen Tipp zu den Elementen der nächsten Gegner zeigen.

### Postgame in Veydal
3286. [x] [P1] Nach dem Kapitel „Waiting for the Ferry“ einen Postgame-Abschnitt im Ziele-Bildschirm zeigen, der alle Endgame-Inhalte als Liste mit Haken führt.
3287. [x] [P1] Den Ring-Deckel nach dem Ende von Akt I auf 60 anheben, damit Endgame-Inhalte die volle Spanne nutzen.
3288. [x] [P1] Acht „Meister-Wanderer“ an festen Orten in Veydal aufstellen, die erst nach beiden Rissen erscheinen und Teams mit Ring 45 bis 55 haben.
3289. [x] [P1] Jeden Meister-Wanderer beim ersten Sieg mit 80 Wegmarken und danach einmal pro Woche mit 20 Wegmarken belohnen.
3290. [x] [P1] Jeden Meister-Wanderer mit einem Steckbrief im Lexikon führen, der Ort, Thema und eigenen Sieg zeigt.
3291. [P2] Die Teams der Meister-Wanderer in data/endgame.json mit Thema, Arten, Techniken und Andenken festlegen.
3292. [P2] Nach dem Sieg über alle acht Meister-Wanderer eine Meisterrunde im Leuchtturm freischalten, in der alle acht nacheinander antreten.
3293. [P2] Eine „Nachhall-Senke“ als neue kleine Karte am Rand der Saltmarsh anlegen, in der nur Spirlings ab Ring 40 wild leben.
3294. [P2] In der Nachhall-Senke alle 21 Arten im Wechsel nach Wochentag auftreten lassen, sodass jede Art jede Woche einmal erreichbar ist.
3295. [P2] In der Nachhall-Senke den Fund des Tages mit doppelter Erscheinchance (0,5 statt 0,25) auftreten lassen.
3296. [P2] Murk Hollow nach dem Postgame um einen tiefen Gang erweitern, der mit dem Kletterpickel erreichbar ist und 3 neue Lore-Seiten enthält.
3297. [P2] Sechs versteckte Schatzstellen in Veydal einbauen, die nur mit Enterhakenseil oder Kletterpickel erreichbar sind und je 30 Wegmarken geben.
3298. [P2] Eine Schatzkarte als Gegenstand vom Tauschstand für 50 Wegmarken anbieten, die eine der sechs Stellen grob einkreist.
3299. [P2] Eine Anzeige „Postgame: x von y erledigt“ in den Aufzeichnungen ergänzen.
3300. [P2] Die Meister-Wanderer nach dem ersten Sieg in der zweiten Woche ein neues Team aus drei vorbereiteten Varianten nutzen lassen.
3301. [P2] Kestra nach dem Ende von Akt I im Map House einen wöchentlichen Erkundungsauftrag geben lassen, der eine der sechs Schatzstellen betrifft.
3302. [P3] Ein Wanderer-Treffen jeden Sonntag am Leuchtturm einrichten, an dem drei zufällige Meister-Wanderer nebeneinander stehen.
3303. [P3] Die Meister-Wanderer nach dem Sieg Tipps zu ihrem Thema geben lassen, die im Lexikon gesammelt werden.
3304. [P3] Einen alten Kartenmacher in der Map House aufstellen, der für jede vollständig erkundete Karte 20 Wegmarken zahlt.
3305. [P3] Die Erkundung einer Karte als vollständig zählen, wenn jede begehbare Kachel einmal betreten wurde, und den Prozentwert im Kartenmenü zeigen.
3306. [P3] Eine Postgame-Bestenliste der eigenen Spielstände (drei Slots) mit Postgame-Fortschritt im Titelbild zeigen.
3307. [P3] Postgame-Inhalte so bauen, dass sie auch ohne Akt II vollständig sind und mit späteren Akten nicht wegfallen.
3308. [P3] Nach allen Postgame-Haken Aldo im Leuchtturm einen kurzen Dank sprechen lassen, ohne neue Story zu beginnen.
3309. [P3] Den Schatz einer gefundenen Stelle jedes Jahr neu füllen, mit 15 Wegmarken.
3310. [P3] Die acht Meister-Wanderer auf einer Karte im Lexikon mit Sieg-Haken zeigen.

### Erfolge und Abzeichen
3311. [x] [P1] Die Erfolgsliste aus Achievements.LIST nach data/achievements.json verschieben, mit Id, Titel, Text, Kategorie und Wegmarken-Lohn.
3312. [x] [P1] Die Erfolge von 17 auf mindestens 80 erweitern, verteilt auf sechs Kategorien: Bonden, Kämpfen, Erkunden, Sammeln, Ereignisse, Herausforderung.
3313. [x] [P1] Jeden Erfolg mit 10, 25, 50 oder 100 Wegmarken nach Schwierigkeit belohnen und den Lohn beim Erfolg anzeigen.
3314. [x] [P1] Mehrstufige Erfolge einführen (Bronze, Silber, Gold), etwa „Kindred“ für 10, 15 und 21 gebondete Arten.
3315. [x] [P1] Beim Freischalten eines Erfolgs ein kurzes Abzeichen-Bild oben im Bild zeigen, ohne das Spiel anzuhalten.
3316. [x] [P1] Ein Abzeichenbuch im Menü bauen, das alle Erfolge als 16x16-Abzeichen im Raster zeigt, gesperrte grau mit Hinweistext.
3317. [x] [P1] Für jeden Erfolg einen Fortschritt (k/n) anzeigen, wo es eine Zahl gibt.
3318. [x] [P1] Alle bestehenden 17 Erfolge mit ihrem Freischaltdatum in das neue Format übernehmen und rückwirkend den Wegmarken-Lohn auszahlen.
3319. [P2] Geheime Erfolge einführen, deren Text erst nach dem Freischalten erscheint, höchstens 10 Stück.
3320. [P2] Einen Erfolg „Ohne Fehltakt“ für ein Echo-Melodie-Spiel ohne verpassten Ton ergänzen.
3321. [P2] Einen Erfolg „Nachtschwärmer“ für 50 Kämpfe bei Nacht ergänzen.
3322. [P2] Einen Erfolg „Alle Felder“ für einen Sieg auf jedem Kampffeld aus BattleRules.FIELDS ergänzen.
3323. [P2] Einen Erfolg „Weltenbummler“ für jede Karte mit wilden Spirlings betreten ergänzen.
3324. [P2] Einen Erfolg „Gleiches Element“ für einen Sieg mit fünf Spirlings eines Elements ergänzen.
3325. [P2] Einen Erfolg „Sammler der Andenken“ für jedes Andenken aus data/items.json einmal besessen ergänzen.
3326. [P2] Einen Erfolg „Ring 60“ für einen Spirling am Ring-Deckel und „Fünf am Deckel“ für ein ganzes Team ergänzen.
3327. [P2] Einen Erfolg „Fotograf“ für 25 gespeicherte Fotos im Fotomodus ergänzen.
3328. [P2] Einen Erfolg „Gastgeber“ für jeden getroffenen Fund des Tages an 30 verschiedenen Tagen ergänzen.
3329. [P2] Einen Erfolg „Festgänger“ für jedes der Feste einmal gefeiert ergänzen.
3330. [P2] Einen Erfolg „Turmspitze“ für Stockwerk 30 der Leuchtturm-Treppe ergänzen und den alten „Echo Climber“ auf 5 Stockwerke belassen.
3331. [P2] Einen Erfolg „Meistergruß“ für einen Sieg über alle acht Meister-Wanderer ergänzen.
3332. [P2] Einen Erfolg „Stadtbauer“ für alle fünf Stadtprojekte in Brindlewick ergänzen.
3333. [P2] Erfolge im Abzeichenbuch nach Kategorie filterbar machen.
3334. [P2] Den Gesamtfortschritt als Prozentzahl oben im Abzeichenbuch zeigen.
3335. [P2] Für jedes Abzeichen das Datum des Freischaltens anzeigen, das heute schon in records["achievements"] steht.
3336. [P2] Alle neuen Erfolgstexte in data/i18n/de.json eintragen und das Prüfskript tools/i18n_extract.py durchlaufen lassen.
3337. [P2] Einen GUT-Test schreiben, der prüft, dass jede Erfolgs-Id in data/achievements.json eine Prüfung in Achievements.earned() hat.
3338. [P2] Die Erfolge nach Plattform an Game Center und Google Play Spiele melden, sofern Ali die Konten freigibt, sonst nur lokal.
3339. [P2] Einen Erfolg „Pfadsucher“ für 10 abgeschlossene Nachhall-Pfade ergänzen.
3340. [P3] Einen Erfolg „Temperamentvoll“ für jedes Temperament einmal im Team ergänzen.
3341. [P3] Einen Erfolg „Prisma-Sammler“ für drei schimmernde Spirlings verschiedener Arten ergänzen.
3342. [P3] Einen Erfolg „Der lange Weg“ für 100 Stunden Spielzeit ergänzen.
3343. [P3] Einen Erfolg „Treue“ für einen Spirling, der seit dem ersten Tag im Team ist und Ring 60 erreicht, ergänzen.
3344. [P3] Einen Erfolg „Alter Hase“ für ein Jahr seit Kontoanlage ergänzen.
3345. [P3] Den Abzeichen-Rahmen nach Stufe färben: Bronze, Silber, Gold.
3346. [P3] Ein seltenes Platin-Abzeichen für alle anderen Erfolge ergänzen, mit einem goldenen Leuchtturm-Bild.
3347. [P3] Die Abzeichen eines Erfolgs in der Era-Grafik des Ortes zeichnen, an dem er meist verdient wird.
3348. [P3] Einen Hinweistext für gesperrte Erfolge zeigen, der grob sagt, wo man anfangen kann.
3349. [P3] Einen Erfolg „Weit gereist“ für 100 abgeschlossene Streifzüge ergänzen.
3350. [P3] Einen Erfolg „Albumpflege“ für 12 volle Monatsalben ergänzen.

### Sammelziele und Spirlog-Abschluss
3351. [x] [P1] Die Spirlog-Ziele in Collection.GOALS um „gesehen“-Stufen ergänzen: 5, 10, 15 und alle Arten gesehen, je mit Wegmarken-Lohn.
3352. [x] [P1] Die Lohnstufen für gebondete Arten zusätzlich mit Wegmarken belohnen: 3, 5, 8, 11 Arten je 20, 30, 40, 60 Wegmarken, alle Arten 200.
3353. [x] [P1] Im Spirlog jede Art mit einem kleinen Stern markieren, wenn sie gebondet und auf Ring 30 gewachsen ist.
3354. [P1] Einen Hinweis im Spirlog zeigen, welche Arten in der Nachhall-Senke diese Woche auftreten, damit fehlende Arten planbar werden.
3355. [P2] Ein Sammelziel „Jede Art auf Ring 30“ mit Stufen von 5, 10 und 21 Arten ergänzen.
3356. [P2] Ein Sammelziel „Jede Entfaltungsform gesehen“ ergänzen, das alle Stufen einer Linie zählt.
3357. [P2] Ein Sammelziel „Jede Technik einmal eingesetzt“ für alle 58 Techniken mit Stufen bei 20, 40 und 58 ergänzen.
3358. [P2] Ein Technikbuch im Lexikon anlegen, das jede schon eingesetzte Technik markiert.
3359. [P2] Ein Sammelziel „Jedes Element im Team“ ergänzen: einmal einen Spirling jedes der acht Elemente gebondet.
3360. [P2] Ein Sammelziel für Fundorte ergänzen: jede Art mindestens an jedem ihrer Fundorte einmal gesehen.
3361. [P2] Im Spirlog für jede Art die Fundorte mit Haken zeigen, sobald man sie dort gesehen hat.
3362. [P2] Ein Sammelziel „Lore-Seiten“ ergänzen, das alle gefundenen Lore-Seiten zählt und bei voll 100 Wegmarken zahlt.
3363. [P2] Ein Sammelziel „Andenken-Sammlung“ ergänzen, das jedes Andenken einmal gehalten zählt.
3364. [P2] Ein Sammelziel für Prisma-Spirlings in einer eigenen Spirlog-Seite zeigen, ohne Hinweis auf eine Chance.
3365. [P2] Ein Sammelziel „Temperamente“ ergänzen, das alle Temperamente über alle Spirlings zählt.
3366. [P2] Für jede Art eine kleine Sammelkarte im Spirlog freischalten, wenn sie gebondet, auf Ring 30 und mit jeder Technik ihrer Linie eingesetzt wurde.
3367. [P3] Eine Fotowand im Leuchtturm einrichten, an die man pro Art ein Foto aus dem Fotomodus hängen kann.
3368. [P3] Für eine volle Fotowand mit allen 21 Arten einen Rahmen in Gold und 100 Wegmarken vergeben.
3369. [P3] Ein Sammelziel „Größte und kleinste“ ergänzen, das für jede Art Höhe oder Gewicht aus einem gebondeten Spirling festhält, falls das Spiel solche Werte bekommt.
3370. [P3] Ein Sammelziel „Jede Art im Team gewonnen“ ergänzen: mit jeder Art einmal einen Kampf beendet.
3371. [P3] Ein Sammelziel „Jede Gabe gesehen“ ergänzen, sobald Gaben im Spirlog angezeigt werden.
3372. [P3] Sammelziele beim Erscheinen neuer Arten in späteren Updates automatisch erweitern, ohne schon erreichte Stufen zurückzunehmen.
3373. [P3] Einen Vergleich „bisher gebondet in diesem Monat“ im Spirlog zeigen, nur für den eigenen Spielstand.
3374. [P3] Ein Sammelziel „Kampffelder“ ergänzen, das jeden Feldtyp mit einem Sieg zählt, getrennt vom Erfolg „Alle Felder“ in Stufen 3, 6 und alle.
3375. [P3] Ein Sammelziel „Rastquellen“ ergänzen, das jede Rastquelle in Veydal einmal besucht zählt.
3376. [P3] Bei Abschluss aller Sammelziele einer Kategorie ein Siegelbild für die Spirlog-Titelseite freischalten.
3377. [P3] Ein Sammelziel „Postkarten“ für alle 12 Postkarten aus Streifzügen ergänzen.

### Abschlussziele und 100-Prozent-Anzeige
3378. [P1] Eine Gesamtanzeige „Reise vollendet: x Prozent“ in den Aufzeichnungen bauen, die Story, Seitenziele, Spirlog, Erfolge, Türme und Erkundung gewichtet.
3379. [P1] Die Gewichte festlegen und in docs/BALANCE.md eintragen: Story 20, Seitenziele 10, Spirlog 25, Erfolge 20, Türme 15, Erkundung 10 Prozent.
3380. [P2] Eine Prüfliste „Was fehlt noch“ bauen, die pro Bereich die drei nächsten offenen Ziele zeigt.
3381. [P2] Den Prozentwert auf dem Speicherslot im Titelbild anzeigen.
3382. [P2] Bei 50, 75 und 100 Prozent eine Belohnung von 50, 100 und 300 Wegmarken auszahlen.
3383. [P2] Bei 100 Prozent einen goldenen Rand um den Speicherslot im Titelbild zeigen.
3384. [P2] Einen Test schreiben, der prüft, dass ein voller Test-Spielstand unter tests/fixtures genau 100 Prozent ergibt.
3385. [P2] Ziele, die nur zu Festen oder im Wochen-Echo erreichbar sind, nicht in die 100 Prozent zählen, damit niemand auf einen Monat warten muss.
3386. [P2] Den Prozentwert nach neuen Updates neu berechnen und erreichte Lohnstufen nie zurücknehmen.
3387. [P2] Den Prozentwert in einer Detailansicht nach den sechs Bereichen aufschlüsseln.
3388. [P3] Bei 100 Prozent eine kurze Abspannfolge mit allen gebondeten Spirlings in Reihe zeigen.
3389. [P3] Einen Zeitpunkt „100 Prozent erreicht am“ in den Aufzeichnungen festhalten.
3390. [P3] Den Prozentwert auf einem teilbaren Bild aus dem Fotomodus einblenden lassen.
3391. [P3] Eine Zielkarte im Kartenmenü zeigen, auf der Orte mit offenen Zielen leicht markiert sind.
3392. [P3] Pro Karte einen Mini-Abschlusswert zeigen: Spirlings gesehen, Schätze, Lore-Seiten.
3393. [P3] Einen Schalter „Hinweise zu offenen Zielen“ in den Einstellungen ergänzen, für Spieler, die lieber selbst suchen.
3394. [P3] Bei 100 Prozent an der Leuchtturmspitze eine neue Fahne zeigen, die nur dieser Spielstand hat.
3395. [P3] Den 100-Prozent-Abschluss in der Lauf-Chronik vermerken.

### Eiserner Schwur und Wiederspielwert
3396. [P1] Den Eisernen Schwur im Titelbild eines Speicherslots mit einem kleinen Kettensymbol kennzeichnen.
3397. [P1] Ein Gedenkbuch im Refugium anlegen, das jeden ins Refugium gezogenen Spirling mit Name, Ring, Ort und Datum listet.
3398. [P1] Den Erfolg „Oathkeeper“ um Stufen erweitern: beide Risse unter Schwur auf Wanderer, Veteran und Rift-Born-Schwierigkeit.
3399. [P1] Die Wahl des Eisernen Schwurs beim neuen Spiel mit einem Satz zu Refugium und Bonus von 25 Prozent Wegmarken erklären.
3400. [P2] Unter Schwur die Leuchtturm-Treppe als eigenen Bestwert führen, getrennt vom normalen Bestwert.
3401. [P2] Eine Chronik der Läufe über alle drei Speicherslots anlegen, die abgeschlossene Läufe mit Starter, Schwierigkeit, Spielzeit und Schwur festhält.
3402. [P2] Die Chronik auch nach dem Löschen eines Slots behalten, damit alte Läufe sichtbar bleiben.
3403. [P2] Für jeden abgeschlossenen Lauf mit einem anderen Starter einen Erfolg vergeben: „Drei Wege“ bei allen drei Startern.
3404. [P2] Kosmetik aus dem Tauschstand und den Jahreszeitenpfaden kontoweit freischalten, sodass ein neuer Lauf sie behält.
3405. [P2] Wegmarken pro Slot führen, aber freigeschaltete Kosmetik kontoweit, und das im Tauschstand erklären.
3406. [P2] Kleine freiwillige Gelübde zu Laufbeginn anbieten, die nur Wegmarken-Bonus geben: „Ohne Laden“, „Ohne Andenken“, „Starter bleibt im Team“.
3407. [P2] Jedes erfüllte Gelübde am Ende von Akt I mit 100 Wegmarken belohnen und in der Chronik vermerken.
3408. [P2] Gelübde jederzeit im Menü aufgeben lassen, ohne Strafe außer dem verlorenen Bonus.
3409. [P2] Die Gelübde in data/endgame.json festlegen und keine Regel aus dem Herausforderungs-Abschnitt des Kampf-Plans doppeln.
3410. [P2] Beim Neustart eines Laufs die Tagesaufträge und den Jahreszeitenpfad kontoweit weiterlaufen lassen.
3411. [P2] Den Eisernen Schwur und die Gelübde in der Lauf-Chronik mit eigenem Symbol zeigen.
3412. [P3] Ein Gelübde „Fünf Elemente“ ergänzen: das Team hat bei jedem Riss-Wächter fünf verschiedene Elemente.
3413. [P3] Ein Gelübde „Leise Reise“ ergänzen: keine Rückkämpfe gegen Wanderer bis zum Ende von Akt I.
3414. [P3] Unter Schwur einen eigenen Abspann-Satz zeigen, der die Zahl der Spirlings im Refugium nennt.
3415. [P3] Im Gedenkbuch einen Spirling mit einem Andenken-Symbol als „Ehrenplatz“ markieren lassen.
3416. [P3] Eine Lauf-Statistik pro Chronik-Eintrag zeigen: Kämpfe, Bonds, Wildbegegnungen, Spielzeit bis zu jedem Riss.
3417. [P3] Einen Vergleich zweier Chronik-Einträge nebeneinander anbieten.
3418. [P3] Pro Speicherslot eine Farbe für die Chronik wählen lassen.
3419. [P3] Wer drei Läufe abgeschlossen hat, bekommt im Leuchtturm einen Bilderrahmen mit den drei Startern.
3420. [P3] Die Chronik als Bild für den Fotomodus speichern lassen.
3421. [P3] Nach einem gebrochenen Schwur den Lauf als normalen Lauf weiterführen und das in der Chronik mit Datum vermerken.

### Kleine Ereignisse in der Welt
3422. [P1] Eine Datei scripts/core/WorldEvents.gd anlegen, die kleine Ereignisse per Seed aus Datum und Ort auslöst, gleich für alle Spieler am selben Tag.
3423. [P1] Einen Wanderhändler einführen, der jeden Tag an einem anderen Ort steht und drei Gegenstände gegen Münzen verkauft.
3424. [P1] Den Ort des Wanderhändlers im Ziele-Bildschirm nennen, damit man ihn nicht suchen muss.
3425. [P2] Eine Sternennacht einführen, die einmal pro Monat am Neumond nach Kalender stattfindet und Lumen-Spirlings nachts dreimal so oft erscheinen lässt.
3426. [P2] Während der Sternennacht am Leuchtturm-Dach ein kleines Sternbild-Rätsel mit 5 Sternen zum Antippen anbieten, das 20 Wegmarken zahlt.
3427. [P2] Einen Regentag pro Woche nach Seed bestimmen, an dem Tide-Spirlings draußen doppelt so oft auftreten, mit leichtem Regenfilter.
3428. [P2] Den Regenfilter beim Schalter „Weniger Bewegung“ abschalten.
3429. [P2] Eine Spirling-Wanderung einführen: an einem Tag pro Woche zieht eine Art in eine Gegend, in der sie sonst nicht lebt.
3430. [P2] Eine Ereigniszeile im Ziele-Bildschirm zeigen, die alle heutigen Weltereignisse auf einen Blick nennt.
3431. [P2] Einen Angeltag am Brindlewick-Steg einführen, an dem der Fischer einen Kelpup-Wettbewerb ausruft: der Kelpup mit höchstem Ring gewinnt 30 Wegmarken.
3432. [P2] Ein Marktwochenende einführen, an dem der Laden in Brindlewick am Samstag und Sonntag 20 Prozent Rabatt auf Münzpreise gibt.
3433. [P2] Einen Besuch von Kestra pro Woche einführen, die an einem festen Ort einen Übungskampf mit wechselndem Team anbietet.
3434. [P2] Alle Weltereignisse in data/events.json mit Auslöser, Ort, Dauer und Wirkung festlegen.
3435. [P3] Eine Wanderer-Gruppe einführen, die einmal pro Woche in Fernstair rastet und drei Doppelkämpfe gegen Echo-Teams anbietet.
3436. [P3] Einen Nebeltag in Murk Hollow einführen, an dem Umbra-Spirlings häufiger sind und der Weg ins Dunkle kürzer ist.
3437. [P3] Einen Glückstag einführen, an dem Wildkämpfe 50 Prozent mehr Münzen geben, einmal pro Monat.
3438. [P3] Ein seltenes Ereignis „Laternenzug“ einführen, bei dem nachts eine Reihe kleiner Lichter durch Brindlewick zieht, nur als Bild.
3439. [P3] Eine Erzählerfigur am Lagerfeuer in Thornridge einführen, die an jedem Freitag eine neue kurze Sage aus Veydal erzählt, ohne neue Story-Kapitel.
3440. [P3] Sagen aus dem Lagerfeuer im Lexikon sammeln und für alle 12 Sagen einen Erfolg vergeben.
3441. [P3] Einen Erntestand in Fernstair einführen, an dem man einmal am Tag einen Beerenkorb zum Heilen bekommt.
3442. [P3] Wetter und Ereignisse so bauen, dass sie nie den Weg versperren oder eine Story-Stelle ändern.
3443. [P3] Einen Ereignis-Hinweis beim Betreten einer Karte zeigen, der nur einmal pro Tag erscheint.
3444. [P3] Einen Tageszeit-Bezug für den Wanderhändler einbauen: nachts verkauft er zwei andere Gegenstände.
3445. [P3] Den Wanderhändler bei jedem Besuch einen Satz über seinen letzten Ort sagen lassen, aus 30 festen Sätzen.

### Streifzüge aus dem Lager
3446. [P1] Spirlings aus dem Lager auf Streifzüge schicken lassen, bis zu drei gleichzeitig, mit einer Dauer von 4, 8 oder 12 Stunden nach Server-Zeit.
3447. [P1] Jeden Streifzug nach einer festen, vorher sichtbaren Tabelle Münzen, 4, 8 oder 12 Wegmarken und einen gewöhnlichen Gegenstand mitbringen lassen.
3448. [P1] Streifzüge im Leuchtturm bei Aldo starten und abholen und Spirlings auf Streifzug im Lager mit einem Rucksack-Symbol markieren.
3449. [P2] Als Ziel nur Karten erlauben, die der Spielstand schon kennt, und Fundstücke dieser Karte mitbringen lassen.
3450. [P2] Einem Spirling, dessen Element zu den wilden Arten der Zielkarte passt, 50 Prozent mehr Münzen geben.
3451. [P2] Streifzüge pro Stunde ein Viertel des Wachstums eines Wildkampfs geben, höchstens bis zum Ring-Deckel.
3452. [P2] Streifzüge nie scheitern lassen und Spirlings auf Streifzug nie Kraft verlieren lassen.
3453. [P2] Jedes Streifzug-Ergebnis als kurze Tagebuchzeile zeigen, etwa „Mossling fand am Bach einen Kraftsud“.
3454. [P2] Spirlings im Refugium des Eisernen Schwurs nicht auf Streifzüge schicken lassen.
3455. [P2] Ziele, Dauer und Belohnungstabellen der Streifzüge in data/endgame.json festlegen.
3456. [P3] Eine Wanderkarte im Tauschstand für 400 Wegmarken anbieten, die einen vierten Streifzug-Platz freischaltet.
3457. [P3] Streifzüge selten eine Postkarte der Zielkarte mitbringen lassen, die in einem Postkartenalbum mit 12 Plätzen landet.
3458. [P3] Einen Streifzug jederzeit abbrechen lassen und die Belohnung anteilig nach verstrichener Zeit auszahlen.
3459. [P3] Bei der Rückkehr ein kleines Bild des Spirlings mit Rucksack an der Leuchtturmtür zeigen.
3460. [P3] Streifzüge auch dann weiterlaufen lassen, wenn das Spiel geschlossen ist, und die Rückkehr erst beim nächsten Start auszahlen.
3461. [P3] Die Zahl der laufenden Streifzüge im Reiter „Heute“ des Ziele-Bildschirms zeigen.

### Nachhall-Pfad: wöchentlicher Erkundungsgang
3462. [P1] Einen Endgame-Ort „Nachhall-Pfad“ hinter dem versiegelten Cinder Rift bauen: eine Kette aus 8 kleinen Räumen, die jede Woche per Seed aus der Wochennummer neu angeordnet wird, gleich für alle.
3463. [P1] Die Räume aus 12 handgebauten Raumvorlagen unter data/maps zusammensetzen und jede Anordnung mit dem bestehenden Erreichbarkeits-Test prüfen.
3464. [P1] Jedem Raum eine Art geben: Wildkampf, Wanderer-Echo, Schatz, Rastquelle oder Rätsel.
3465. [P1] Am Ende des Pfads eine Truhe mit 40 Wegmarken beim ersten Abschluss der Woche aufstellen.
3466. [P2] Rätselräume mit Lampen-Schalterrätseln in 6 Varianten bauen, angelehnt an das Lampenrätsel in Murk Hollow, aber mit eigener Anordnung.
3467. [P2] Im Pfad nur im Rastquellen-Raum heilen lassen.
3468. [P2] Beim Aufgeben alle gesammelten Dinge behalten lassen, nur die Endtruhe fehlt dann.
3469. [P2] Wilde Spirlings im Pfad auf Ring-Deckel minus 5 setzen.
3470. [P2] Eine Pfadkarte im Menü zeigen, die besuchte Räume und ihre Art markiert.
3471. [P2] Jeder Woche ein Motiv geben (Glut, Gezeiten, Wald, Höhle), das Kacheln und Elemente der wilden Spirlings bestimmt.
3472. [P2] Den Nachhall-Pfad erst nach dem Kapitel „Waiting for the Ferry“ öffnen.
3473. [P2] Einen GUT-Test schreiben, der 52 Wochen-Seeds erzeugt und prüft, dass jeder Pfad begehbar und lösbar ist.
3474. [P2] Die beste eigene Zeit pro Woche nur lokal in GameState.records["echo_path_best"] speichern.
3475. [P3] Nach dem Sieg über alle Meister-Wanderer einen langen Pfad mit 12 Räumen und 80 Wegmarken freischalten.
3476. [P3] In einer von zehn Wochen, fest durch den Seed bestimmt, einen geheimen Raum mit einem besonderen Fotorahmen einbauen.
3477. [P3] Die Raumvorlagen in der Era-Grafik der jeweiligen Region zeichnen und in docs/ASSET_LOG.md eintragen.
3478. [P3] Eine eigene ruhige Pfadmelodie in audio/ anlegen und in data/music.json eintragen.
3479. [P3] Abkürzungen im Pfad einbauen, die nur mit Enterhakenseil oder Kletterpickel nutzbar sind.
3480. [P3] Nach dem Abschluss eine Karte des Pfads als Bild im Fotomodus speichern lassen.
3481. [P3] Einen Wochenrückblick des Pfads zeigen: Räume, Kämpfe, gefundene Schätze.

### Monatsalbum
3482. [P1] Ein Monatsalbum mit 12 Stickerfeldern pro Kalendermonat anlegen, jedes Feld eine feste Aufgabe, die man den ganzen Monat lang lösen kann.
3483. [P1] Ein volles Album mit 100 Wegmarken und einem Monatssticker für eine Stickerwand im Wanderer-Zimmer belohnen.
3484. [P2] Die Album-Aufgaben pro Monat per Seed aus einer Liste in data/events.json ziehen.
3485. [P2] Bei 4 und 8 gefüllten Stickern je 20 Wegmarken auszahlen.
3486. [P2] Für jeden Monat ein Stickerthema festlegen (Januar Herd, April Blüten, Oktober Laternen) und 16x16-Sticker mit tools/art zeichnen.
3487. [P2] Das Album im Reiter „Sammlung“ des Ziele-Bildschirms zeigen.
3488. [P2] Album-Aufgaben nie mit den Tagesaufträgen desselben Tages gleichsetzen.
3489. [P2] Album-Aufgaben nur aus Orten ziehen, die der Spielstand schon erreicht hat.
3490. [P3] Vergangene Alben in einem Albumregal im Wanderer-Zimmer ansehen lassen.
3491. [P3] Monatssticker im Fotomodus als Deko auf das Bild setzen lassen.
3492. [P3] Verpasste Sticker im selben Monat des Folgejahres nachholen lassen.
3493. [P3] Zum Jahresende alle Monatssticker auf einem Jahresposter im Wanderer-Zimmer zeigen.
3494. [P3] Albumseiten mit einer Wischgeste blättern lassen.
3495. [P3] Für ein Album, das in der ersten Monatshälfte voll ist, einen goldenen Stickerrand vergeben.

### Fairer Rhythmus ohne Druck
3496. [P1] Festschreiben und testen, dass kein Ereignis eine Serie verlangt und kein Fortschritt bei einem verpassten Tag verloren geht.
3497. [P1] Alle zeitlich begrenzten Inhalte nach Server-Zeit laufen lassen und beim Verstellen der Handy-Uhr nichts doppelt auszahlen.
3498. [x] [P1] Belohnungen von Festen und Jahreszeitenpfad nach spätestens zwei Jahren erneut erreichbar machen, damit nichts für immer verpasst ist.
3499. [P2] Eine Rückkehrhilfe einbauen: wer 14 Tage nicht gespielt hat, bekommt einmalig doppelte Pfadpunkte für 3 Tage.
3500. [P2] Tagesaufträge nie per Benachrichtigung bewerben, auch wenn Push später freigeschaltet wird.
3501. [P2] Keine Countdown-Zahlen unter einer Stunde auf dem Bildschirm zeigen, nur „endet heute“.
3502. [P2] Für Kinderkonten (unter 16) alle Endgame-Belohnungen gleich halten und keine Hinweise auf Kaufangebote neben Wegmarken zeigen.
3503. [P2] Eine Spielzeit-Erinnerung nach 90 Minuten anbieten, die man in den Einstellungen abschalten kann.
3504. [P2] Belohnungen für Tagesaufträge auch nachträglich am nächsten Tag abholen lassen, wenn der Auftrag noch am alten Tag fertig wurde.
3505. [P2] Einen Test schreiben, der einen Spielstand 30 Tage pausieren lässt und prüft, dass danach alle Ziele erreichbar und keine Belohnungen verloren sind.
3506. [P3] Einen Urlaubsmodus anbieten, der bis zu 14 Tage den Jahreszeitenpfad pausiert, ohne Punkte zu verlieren.
3507. [P3] Ereignisse in den Einstellungen einzeln ausblendbar machen (Weltereignisse, Festschmuck, Auftragshinweise).
3508. [P3] In docs/BALANCE.md eine Regel festhalten, dass kein Endgame-Inhalt mehr als 30 Minuten pro Tag braucht, um alle Tagesbelohnungen zu holen.
3509. [P3] Eine Ansicht „Heute erledigt“ zeigen, die klar sagt, wenn es für heute nichts Wichtiges mehr gibt.
3510. [P3] Bei Verbindungsabbruch begonnene Tagesaufträge lokal weiterzählen und beim Wiederverbinden an den Server schicken.
3511. [P3] In den Einstellungen anzeigen, nach welcher Uhrzeit (Server-Mitternacht) der Tag wechselt, umgerechnet in die Ortszeit.

### Belohnungstabellen und Balance
3512. [P1] Eine Belohnungstabelle in docs/BALANCE.md anlegen, die jede Wegmarken- und Münzquelle mit Betrag und Häufigkeit listet.
3513. [P1] Das Simulationswerkzeug tools/balance_sim.gd um einen Endgame-Lauf erweitern, der 90 Spieltage mit festem Spielplan durchrechnet und Wegmarken-Ein- und Ausgaben ausgibt.
3514. [P2] Als Ziel festlegen, dass ein Spieler nach 30 Tagen etwa 60 Prozent des Tauschstand-Angebots einmal kaufen kann.
3515. [P2] Die Münzpreise im Wochen-Echo und in den Türmen an den Ring-Deckel binden: 20 Münzen mal Ring-Deckel pro Runde.
3516. [P2] Echo-Kristalle als Endgame-Belohnung höchstens einmal pro Woche aus Türmen zulassen, damit der Tauschstand wichtig bleibt.
3517. [P2] Im Datenprüfer tools/validate_data.gd prüfen, dass jeder Gegenstand in data/endgame.json und data/events.json in data/items.json existiert.
3518. [P2] Im Datenprüfer prüfen, dass jede Ereignis-Id einmalig ist und jede Belohnung einen Betrag über 0 hat.
3519. [P2] Den Gesamtwert aller Wegmarken-Quellen pro Woche im Test begrenzen: höchstens 700 Wegmarken für einen Spieler, der alles macht.
3520. [P2] Gegenstände aus Endgame-Quellen nie stärker machen als Gegenstände aus dem Laden, nur seltener im Laden.
3521. [P3] Einen Bericht in docs/BALANCE.md pflegen, der nach jedem Update die Wegmarken-Kurve über 90 Tage zeigt.
3522. [P3] Die Preise im Tauschstand nach 8 Wochen Live-Daten aus den Server-Speicherständen prüfen, ohne Analytics-SDK.
3523. [P3] Eine Debug-Option nur im Editor bauen, die Datum und Woche vorstellt, um Feste und Pfade zu prüfen.
3524. [P3] Den Münzbetrag für Siege in der Nachhall-Senke um 25 Prozent über den normalen Wildkampf setzen.
3525. [P3] Für jede Belohnungsquelle eine Obergrenze pro Tag in data/endgame.json eintragen, die der Server prüft.

### Anzeige und Menüs
3526. [P1] Den Ziele-Bildschirm in vier Reiter teilen: Story, Heute, Woche, Sammlung.
3527. [P1] Den Reiter „Heute“ mit Fund des Tages, Tagesaufträgen, Wanderhändler und Weltereignissen füllen.
3528. [P1] Den Reiter „Woche“ mit Wochen-Echo, Tauschstand-Wochenangebot, Meister-Wanderern und Endlosstrecke füllen.
3529. [P2] Einen roten Punkt am Menüeintrag „Ziele“ zeigen, wenn eine Belohnung zum Abholen bereitliegt.
3530. [P2] Eine Sammelabholung „Alles abholen“ für Aufträge, Pfad und Sammelziele bauen.
3531. [P2] Alle neuen Menüs auf 144x256 mit der bestehenden Schrift und Einhand-Bedienung prüfen und einen Screenshot je Menü in docs/screenshots ablegen.
3532. [P2] Die Menüs mit dem Gamepad und dem Einhand-Pad bedienbar machen, wie die bestehenden Listen in ListPicker.gd.
3533. [P2] Neue Symbole (Wegmarke, Festband, Pfadstufe, Abzeichenrahmen) mit tools/art erzeugen und in docs/ASSET_LOG.md eintragen.
3534. [P2] Im Hochkontrast-Modus alle Fortschrittsbalken mit Zahlen statt nur Farbe zeigen.
3535. [P3] Einen Wochenrückblick am Montag zeigen: erledigte Aufträge, Wegmarken, neue Abzeichen.
3536. [P3] Beim ersten Postgame-Start eine kurze Einführung in drei Bildern zeigen: Tauschstand, Türme, Aufträge.
3537. [P3] Einen Leuchtturm-Raum „Ehrengalerie“ einrichten, in dem die Trophäen für volle Türme, Meisterrunde und 100 Prozent stehen.
3538. [P3] Jede Trophäe in der Ehrengalerie mit einem Text zum Datum des Erreichens antippen lassen.
3539. [P3] Die Ehrengalerie über eine Tür im Erdgeschoss des Leuchtturms erreichbar machen, ohne neue Treppen.

### Speicherdaten, Server und Tests
3540. [P1] Alle neuen Felder (waymarks, festival_ribbons, daily_tasks, path, towers, chronicle) in GameState.to_dict() und from_dict() mit Standardwerten aufnehmen.
3541. [P1] Eine Speicherversion hochzählen und alte Stände unter tests/fixtures mit einem Lade-Test prüfen.
3542. [P2] Die Gutschriften für Wochen-Echo und Türme vom Server über das Ergebnis und den Seed prüfen lassen, bevor der Stand angenommen wird.
3543. [P2] Die Kosmetik-Freischaltungen kontoweit in einer eigenen Server-Tabelle in supabase/ speichern, getrennt vom Spielstand.
3544. [P2] Einen GUT-Test für Waymarks.earn() schreiben: Obergrenze 9999, keine negativen Beträge, Log-Länge 200.
3545. [P2] Einen GUT-Test für DailyTasks schreiben, der prüft, dass derselbe Tag immer dieselben drei Aufträge zieht.
3546. [P2] Einen GUT-Test für den Festband-Umtausch am Festende schreiben, auch wenn der Spieler erst Wochen später wieder öffnet.
3547. [P2] Einen GUT-Test für die Turm-Rastpunkte schreiben: Lauf speichern, Spiel neu laden, am richtigen Stockwerk fortsetzen.
3548. [P2] Einen GUT-Test für den Jahreszeitenpfad schreiben, der Saisonwechsel und Nachholfrist von 14 Tagen prüft.
3549. [P2] Einen GUT-Test schreiben, der alle Texte der neuen Daten durch tools/ip_check.sh laufen lässt.
3550. [P2] Den Ladebildschirm-Test mit einem Spielstand voller Endgame-Daten auf die Ladezeit unter 1 Sekunde prüfen.
3551. [P3] Den Speicherumfang der neuen Daten messen und unter 20 KB pro Spielstand halten.
3552. [P3] Einen Fuzz-Test über 365 simulierte Tage schreiben, der Aufträge, Feste und Pfad durchläuft und keinen Absturz zeigt.
3553. [P3] Die Zeitzonen-Grenze testen: ein Spieler in Neuseeland und einer in Kalifornien bekommen am selben Server-Tag dieselben Aufträge.
3554. [P3] Einen Test schreiben, der prüft, dass keine Endgame-Belohnung einen Spirling vergibt oder Spirlings übertragbar macht.
3555. [P3] Die Ereignisdaten so aufbauen, dass der Server neue Feste und Pfade nachliefern kann, ohne App-Update.
3556. [P3] Für nachgelieferte Ereignisdaten eine Signaturprüfung im Client bauen, damit nur Daten vom eigenen Server gelten.
