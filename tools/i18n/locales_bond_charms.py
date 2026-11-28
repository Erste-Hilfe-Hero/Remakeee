#!/usr/bin/env python3
"""Texts of the bond charm family (release 1.3.2, owner 28 Nov 2026) in German and the other 12 locales.
German goes to the table bond_charms (tools/i18n/de_bond_charms.py imports R); this script writes
data/i18n/<code>/bond_charms.json. Run: python3 tools/i18n/locales_bond_charms.py
Order per row: de, ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl.
Charms are held out before the Mine! bar, never thrown; no text names a chance as a number on screen."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
# Names
"Inkquill Charm": ["Tintenkiel-Amulett", "インク羽ペンのお守り", "Charme plume-d'encre", "Amuleto penna d'inchiostro", "Amuleto pluma de tinta", "잉크깃 부적", "墨羽护符", "墨羽護符", "Amuleto pena de tinta", "Амулет чернильного пера", "Amulet atramentowego pióra", "Mürekkep Tüyü Tılsımı", "Inktveeramulet"],
"Kindred Thread": ["Verwandtschaftsfaden", "縁の糸", "Fil de parenté", "Filo di affinità", "Hilo afín", "인연의 실", "同源丝线", "同源絲線", "Fio de afinidade", "Нить родства", "Nić pokrewieństwa", "Akrabalık İpi", "Verwantschapsdraad"],
"Moonwick": ["Monddocht", "月灯芯", "Mèche de lune", "Stoppino lunare", "Mecha lunar", "달심지", "月芯烛", "月芯燭", "Pavio lunar", "Лунный фитиль", "Księżycowy knot", "Ay Fitili", "Maanlont"],
"Stormbell": ["Sturmglocke", "嵐の鈴", "Cloche d'orage", "Campana di tempesta", "Campana de tormenta", "폭풍 종", "风暴铃", "風暴鈴", "Sino da tempestade", "Грозовой колокольчик", "Burzowy dzwonek", "Fırtına Çanı", "Stormbel"],
"Mender's Ribbon": ["Heilerband", "癒し手のリボン", "Ruban du soigneur", "Nastro del guaritore", "Cinta del sanador", "치유사의 리본", "疗愈者丝带", "療癒者絲帶", "Fita do curandeiro", "Лента целителя", "Wstążka uzdrowiciela", "Şifacı Kurdelesi", "Helerslint"],
"Hush Feather": ["Stillfeder", "静寂の羽", "Plume de silence", "Piuma del silenzio", "Pluma del silencio", "고요의 깃털", "静谧之羽", "靜謐之羽", "Pena do silêncio", "Перо тишины", "Pióro ciszy", "Sessizlik Tüyü", "Stilteveer"],
"Swiftleaf": ["Flinkblatt", "疾風の葉", "Feuille-vive", "Foglia lesta", "Hoja veloz", "날쌘 잎", "疾叶", "疾葉", "Folha ligeira", "Быстролист", "Bystry liść", "Çevik Yaprak", "Vlugblad"],
"Rift Lantern": ["Risslaterne", "裂け目のランタン", "Lanterne de Faille", "Lanterna dello squarcio", "Farol de la Grieta", "균열 등불", "裂隙提灯", "裂隙提燈", "Lanterna da Fenda", "Фонарь Разлома", "Latarnia Szczeliny", "Yarık Feneri", "Klooflantaarn"],
"Firstlight Crest": ["Erstlicht-Wappen", "初光の紋章", "Blason de l'aube", "Stemma della prima luce", "Blasón del alba", "첫빛 문장", "初光纹章", "初光紋章", "Brasão da primeira luz", "Герб первого света", "Herb pierwszego światła", "İlk Işık Arması", "Eerstlichtwapen"],
# Descriptions (bag, merchant card, picker hint, shop detail)
"A quill dipped in Rift ink. Hold it out during a bond: +18%, and Mine! needs 2 taps fewer.": [
 "Ein Federkiel, in Risstinte getaucht. Halte ihn bei einer Bindung hin: +18 %, und Meins! braucht 2 Tipper weniger.",
 "裂け目のインクにひたした羽ペン。絆を結ぶときにかかげると+18%、「おれの！」のタップが2回少なくてすむ。",
 "Une plume trempée dans l'encre de Faille. Tends-la pendant un lien: +18%, et C'est à moi! demande 2 tapes de moins.",
 "Una penna intinta nell'inchiostro dello squarcio. Mostrala durante un legame: +18%, e Mio! richiede 2 tocchi in meno.",
 "Una pluma mojada en tinta de la Grieta. Ofrécela durante un vínculo: +18%, y ¡Mío! pide 2 toques menos.",
 "균열 잉크에 적신 깃펜. 유대 중에 내밀면 +18%, 내 거야!의 탭이 2번 줄어듭니다.",
 "蘸过裂隙墨水的羽笔。结缘时举起它：+18%，“归我！”少点2下。",
 "蘸過裂隙墨水的羽筆。羈絆時舉起它：+18%，“歸我！”少點2下。",
 "Uma pena molhada na tinta da Fenda. Mostre-a durante um vínculo: +18%, e É meu! pede 2 toques a menos.",
 "Перо, обмакнутое в чернила Разлома. Покажи его при связи: +18%, и для Мой! нужно на 2 нажатия меньше.",
 "Pióro zanurzone w atramencie Szczeliny. Pokaż je podczas więzi: +18%, a Mój! wymaga o 2 stuknięcia mniej.",
 "Yarık mürekkebine batırılmış bir tüy kalem. Bağ kurarken uzat: +%18, ve Benim! 2 dokunuş daha az ister.",
 "Een veer gedoopt in Kloofinkt. Houd hem voor tijdens een binding: +18%, en Van mij! vraagt 2 tikken minder."],
"Hold it out during a bond: +6%, and +30% more when the wild Spirling shares an element with your Spirling in front.": [
 "Halte ihn bei einer Bindung hin: +6 %, und +30 % mehr, wenn der wilde Spirling ein Element mit deinem vorderen Spirling teilt.",
 "絆を結ぶときにかかげると+6%。野生のSpirlingが先頭のSpirlingと同じ属性を持つと、さらに+30%。",
 "Tends-le pendant un lien: +6%, et +30% de plus si le Spirling sauvage partage un élément avec ton Spirling en tête.",
 "Mostralo durante un legame: +6%, e +30% in più se lo Spirling selvatico condivide un elemento con il tuo Spirling in prima fila.",
 "Ofrécelo durante un vínculo: +6%, y +30% más si el Spirling salvaje comparte un elemento con tu Spirling al frente.",
 "유대 중에 내밀면 +6%. 야생 Spirling이 앞에 선 내 Spirling과 속성을 공유하면 추가로 +30%.",
 "结缘时举起它：+6%；野生Spirling与你前排的Spirling有相同属性时再+30%。",
 "羈絆時舉起它：+6%；野生Spirling與你前排的Spirling有相同屬性時再+30%。",
 "Mostre-o durante um vínculo: +6%, e +30% a mais quando o Spirling selvagem tem um elemento em comum com o seu Spirling da frente.",
 "Покажи её при связи: +6%, и ещё +30%, если у дикого Spirling есть общая стихия с твоим Spirling впереди.",
 "Pokaż ją podczas więzi: +6%, i o 30% więcej, gdy dziki Spirling ma wspólny żywioł z twoim Spirlingiem z przodu.",
 "Bağ kurarken uzat: +%6, vahşi Spirling öndeki Spirling'inle bir elementi paylaşıyorsa +%30 daha.",
 "Houd hem voor tijdens een binding: +6%, en +30% meer als de wilde Spirling een element deelt met je voorste Spirling."],
"A wick that burns silver after sundown. Hold it out during a bond: +6%, and +30% more at dusk and at night.": [
 "Ein Docht, der nach Sonnenuntergang silbern brennt. Halte ihn bei einer Bindung hin: +6 %, und +30 % mehr in der Dämmerung und nachts.",
 "日が沈むと銀色に燃える灯芯。絆を結ぶときにかかげると+6%、夕暮れと夜はさらに+30%。",
 "Une mèche qui brûle d'argent après le coucher du soleil. Tends-la pendant un lien: +6%, et +30% de plus au crépuscule et la nuit.",
 "Uno stoppino che arde d'argento dopo il tramonto. Mostralo durante un legame: +6%, e +30% in più al crepuscolo e di notte.",
 "Una mecha que arde plateada tras la puesta de sol. Ofrécela durante un vínculo: +6%, y +30% más al anochecer y de noche.",
 "해가 지면 은빛으로 타는 심지. 유대 중에 내밀면 +6%, 해질녘과 밤에는 추가로 +30%.",
 "日落后燃起银光的烛芯。结缘时举起它：+6%；黄昏和夜晚再+30%。",
 "日落後燃起銀光的燭芯。羈絆時舉起它：+6%；黃昏和夜晚再+30%。",
 "Um pavio que arde prateado depois do pôr do sol. Mostre-o durante um vínculo: +6%, e +30% a mais ao entardecer e à noite.",
 "Фитиль, что горит серебром после заката. Покажи его при связи: +6%, и ещё +30% в сумерках и ночью.",
 "Knot, który po zachodzie słońca płonie srebrem. Pokaż go podczas więzi: +6%, i o 30% więcej o zmierzchu i nocą.",
 "Gün batınca gümüş yanan bir fitil. Bağ kurarken uzat: +%6, alacakaranlıkta ve gece +%30 daha.",
 "Een lont die na zonsondergang zilver brandt. Houd hem voor tijdens een binding: +6%, en +30% meer in de schemering en 's nachts."],
"A bell that rings with the weather. Hold it out during a bond: +6%, and +30% more in rain, fog, wind or a storm.": [
 "Eine Glocke, die mit dem Wetter klingt. Halte sie bei einer Bindung hin: +6 %, und +30 % mehr bei Regen, Nebel, Wind oder Sturm.",
 "天気とともに鳴る鈴。絆を結ぶときにかかげると+6%、雨、霧、風、嵐のときはさらに+30%。",
 "Une cloche qui sonne avec le temps. Tends-la pendant un lien: +6%, et +30% de plus sous la pluie, dans le brouillard, le vent ou l'orage.",
 "Una campana che suona con il tempo. Mostrala durante un legame: +6%, e +30% in più con pioggia, nebbia, vento o tempesta.",
 "Una campana que suena con el tiempo. Ofrécela durante un vínculo: +6%, y +30% más con lluvia, niebla, viento o tormenta.",
 "날씨와 함께 울리는 종. 유대 중에 내밀면 +6%, 비, 안개, 바람, 폭풍 때는 추가로 +30%.",
 "随天气鸣响的铃。结缘时举起它：+6%；雨、雾、风或风暴中再+30%。",
 "隨天氣鳴響的鈴。羈絆時舉起它：+6%；雨、霧、風或風暴中再+30%。",
 "Um sino que toca com o tempo. Mostre-o durante um vínculo: +6%, e +30% a mais com chuva, neblina, vento ou tempestade.",
 "Колокольчик, что звенит с погодой. Покажи его при связи: +6%, и ещё +30% в дождь, туман, ветер или грозу.",
 "Dzwonek, który dzwoni razem z pogodą. Pokaż go podczas więzi: +6%, i o 30% więcej w deszczu, mgle, wietrze lub burzy.",
 "Havayla çalan bir çan. Bağ kurarken uzat: +%6, yağmur, sis, rüzgâr ya da fırtınada +%30 daha.",
 "Een bel die meeklinkt met het weer. Houd hem voor tijdens een binding: +6%, en +30% meer bij regen, mist, wind of storm."],
"Hold it out during a bond: +6%, and +30% more when the wild Spirling has half its Vigor or less, or a status.": [
 "Halte es bei einer Bindung hin: +6 %, und +30 % mehr, wenn der wilde Spirling höchstens die Hälfte seiner Kraft oder einen Zustand hat.",
 "絆を結ぶときにかかげると+6%。野生のSpirlingの活力が半分以下か、状態異常があるとさらに+30%。",
 "Tends-le pendant un lien: +6%, et +30% de plus si le Spirling sauvage a la moitié de sa Vigueur ou moins, ou un statut.",
 "Mostralo durante un legame: +6%, e +30% in più se lo Spirling selvatico ha metà del Vigore o meno, o uno stato.",
 "Ofrécela durante un vínculo: +6%, y +30% más si el Spirling salvaje tiene la mitad de su Vigor o menos, o un estado.",
 "유대 중에 내밀면 +6%. 야생 Spirling의 기력이 절반 이하이거나 상태 이상이 있으면 추가로 +30%.",
 "结缘时举起它：+6%；野生Spirling的元气不到一半或带有状态时再+30%。",
 "羈絆時舉起它：+6%；野生Spirling的元氣不到一半或帶有狀態時再+30%。",
 "Mostre-a durante um vínculo: +6%, e +30% a mais quando o Spirling selvagem tem metade do Vigor ou menos, ou um status.",
 "Покажи её при связи: +6%, и ещё +30%, если у дикого Spirling половина Бодрости или меньше либо есть состояние.",
 "Pokaż ją podczas więzi: +6%, i o 30% więcej, gdy dziki Spirling ma połowę Wigoru lub mniej albo stan.",
 "Bağ kurarken uzat: +%6, vahşi Spirling'in Dinçliği yarıya ya da altına indiyse veya bir durumu varsa +%30 daha.",
 "Houd het voor tijdens een binding: +6%, en +30% meer als de wilde Spirling de helft van zijn Kracht of minder heeft, of een status."],
"Hold it out during a bond: +8%, and +35% more with shy and ancient Spirlings. 1 piece, used up. Story only, not in leagues.": [
 "Halte sie bei einer Bindung hin: +8 %, und +35 % mehr bei scheuen und uralten Spirlings. 1 Stück, wird verbraucht. Nur Geschichte, nicht in Ligen.",
 "絆を結ぶときにかかげると+8%、内気なSpirlingや古代のSpirlingにはさらに+35%。1個、使うとなくなる。ストーリー限定、リーグでは無効。",
 "Tends-la pendant un lien: +8%, et +35% de plus avec les Spirlings timides et anciens. 1 pièce, consommé à l'usage. Histoire seulement, pas en ligue.",
 "Mostrala durante un legame: +8%, e +35% in più con gli Spirling timidi e antichi. 1 pezzo, si consuma. Solo storia, non nelle leghe.",
 "Ofrécela durante un vínculo: +8%, y +35% más con Spirlings tímidos y antiguos. 1 unidad, se gasta. Solo historia, no en ligas.",
 "유대 중에 내밀면 +8%, 수줍은 Spirling과 고대종에게는 추가로 +35%. 1개, 사용하면 없어집니다. 스토리 전용, 리그에서는 불가.",
 "结缘时举起它：+8%；面对怕生和远古的Spirling再+35%。1件，使用后消耗。仅限剧情，联赛中无效。",
 "羈絆時舉起它：+8%；面對怕生和遠古的Spirling再+35%。1件，使用後消耗。僅限劇情，聯賽中無效。",
 "Mostre-a durante um vínculo: +8%, e +35% a mais com Spirlings tímidos e antigos. 1 unidade, é gasto ao usar. Só na história, não nas ligas.",
 "Покажи его при связи: +8%, и ещё +35% с пугливыми и древними Spirlings. 1 штука, расходуется. Только сюжет, не в лигах.",
 "Pokaż je podczas więzi: +8%, i o 35% więcej z płochliwymi i pradawnymi Spirlingami. 1 sztuka, zużywa się. Tylko fabuła, nie w ligach.",
 "Bağ kurarken uzat: +%8, ürkek ve kadim Spirling'lerle +%35 daha. 1 adet, kullanınca tükenir. Sadece hikâye, liglerde değil.",
 "Houd hem voor tijdens een binding: +8%, en +35% meer bij schuwe en oeroude Spirlings. 1 stuk, raakt op. Alleen verhaal, niet in competities."],
"Hold it out during a bond: +8%, and Mine! needs 6 taps fewer for a full bar. 1 piece, used up. Story only, not in leagues.": [
 "Halte es bei einer Bindung hin: +8 %, und Meins! braucht 6 Tipper weniger für einen vollen Balken. 1 Stück, wird verbraucht. Nur Geschichte, nicht in Ligen.",
 "絆を結ぶときにかかげると+8%、「おれの！」のバーを満たすタップが6回少なくてすむ。1個、使うとなくなる。ストーリー限定、リーグでは無効。",
 "Tends-la pendant un lien: +8%, et C'est à moi! demande 6 tapes de moins pour une barre pleine. 1 pièce, consommé à l'usage. Histoire seulement, pas en ligue.",
 "Mostrala durante un legame: +8%, e Mio! richiede 6 tocchi in meno per riempire la barra. 1 pezzo, si consuma. Solo storia, non nelle leghe.",
 "Ofrécela durante un vínculo: +8%, y ¡Mío! pide 6 toques menos para llenar la barra. 1 unidad, se gasta. Solo historia, no en ligas.",
 "유대 중에 내밀면 +8%, 내 거야!의 막대를 채우는 탭이 6번 줄어듭니다. 1개, 사용하면 없어집니다. 스토리 전용, 리그에서는 불가.",
 "结缘时举起它：+8%，“归我！”填满进度条少点6下。1件，使用后消耗。仅限剧情，联赛中无效。",
 "羈絆時舉起它：+8%，“歸我！”填滿進度條少點6下。1件，使用後消耗。僅限劇情，聯賽中無效。",
 "Mostre-a durante um vínculo: +8%, e É meu! pede 6 toques a menos para encher a barra. 1 unidade, é gasto ao usar. Só na história, não nas ligas.",
 "Покажи его при связи: +8%, и для полной полосы Мой! нужно на 6 нажатий меньше. 1 штука, расходуется. Только сюжет, не в лигах.",
 "Pokaż go podczas więzi: +8%, a Mój! wymaga o 6 stuknięć mniej do pełnego paska. 1 sztuka, zużywa się. Tylko fabuła, nie w ligach.",
 "Bağ kurarken uzat: +%8, ve Benim! çubuğu doldurmak için 6 dokunuş daha az ister. 1 adet, kullanınca tükenir. Sadece hikâye, liglerde değil.",
 "Houd het voor tijdens een binding: +8%, en Van mij! vraagt 6 tikken minder voor een volle balk. 1 stuk, raakt op. Alleen verhaal, niet in competities."],
"Hold it out during a bond: +30%, and Mine! needs 4 taps fewer. 1 piece, used up. Story only, not in leagues.": [
 "Halte sie bei einer Bindung hin: +30 %, und Meins! braucht 4 Tipper weniger. 1 Stück, wird verbraucht. Nur Geschichte, nicht in Ligen.",
 "絆を結ぶときにかかげると+30%、「おれの！」のタップが4回少なくてすむ。1個、使うとなくなる。ストーリー限定、リーグでは無効。",
 "Tends-la pendant un lien: +30%, et C'est à moi! demande 4 tapes de moins. 1 pièce, consommé à l'usage. Histoire seulement, pas en ligue.",
 "Mostrala durante un legame: +30%, e Mio! richiede 4 tocchi in meno. 1 pezzo, si consuma. Solo storia, non nelle leghe.",
 "Ofrécelo durante un vínculo: +30%, y ¡Mío! pide 4 toques menos. 1 unidad, se gasta. Solo historia, no en ligas.",
 "유대 중에 내밀면 +30%, 내 거야!의 탭이 4번 줄어듭니다. 1개, 사용하면 없어집니다. 스토리 전용, 리그에서는 불가.",
 "结缘时举起它：+30%，“归我！”少点4下。1件，使用后消耗。仅限剧情，联赛中无效。",
 "羈絆時舉起它：+30%，“歸我！”少點4下。1件，使用後消耗。僅限劇情，聯賽中無效。",
 "Mostre-a durante um vínculo: +30%, e É meu! pede 4 toques a menos. 1 unidade, é gasto ao usar. Só na história, não nas ligas.",
 "Покажи его при связи: +30%, и для Мой! нужно на 4 нажатия меньше. 1 штука, расходуется. Только сюжет, не в лигах.",
 "Pokaż ją podczas więzi: +30%, a Mój! wymaga o 4 stuknięcia mniej. 1 sztuka, zużywa się. Tylko fabuła, nie w ligach.",
 "Bağ kurarken uzat: +%30, ve Benim! 4 dokunuş daha az ister. 1 adet, kullanınca tükenir. Sadece hikâye, liglerde değil.",
 "Houd hem voor tijdens een binding: +30%, en Van mij! vraagt 4 tikken minder. 1 stuk, raakt op. Alleen verhaal, niet in competities."],
"The top bond charm. Hold it out during a bond: +45%, and Mine! needs 6 taps fewer. 1 piece, used up. Story only, not in leagues.": [
 "Das stärkste Bindungsamulett. Halte es bei einer Bindung hin: +45 %, und Meins! braucht 6 Tipper weniger. 1 Stück, wird verbraucht. Nur Geschichte, nicht in Ligen.",
 "最上級の絆のお守り。絆を結ぶときにかかげると+45%、「おれの！」のタップが6回少なくてすむ。1個、使うとなくなる。ストーリー限定、リーグでは無効。",
 "Le meilleur charme de lien. Tends-le pendant un lien: +45%, et C'est à moi! demande 6 tapes de moins. 1 pièce, consommé à l'usage. Histoire seulement, pas en ligue.",
 "Il miglior amuleto di legame. Mostralo durante un legame: +45%, e Mio! richiede 6 tocchi in meno. 1 pezzo, si consuma. Solo storia, non nelle leghe.",
 "El mejor amuleto de vínculo. Ofrécelo durante un vínculo: +45%, y ¡Mío! pide 6 toques menos. 1 unidad, se gasta. Solo historia, no en ligas.",
 "최고의 유대 부적. 유대 중에 내밀면 +45%, 내 거야!의 탭이 6번 줄어듭니다. 1개, 사용하면 없어집니다. 스토리 전용, 리그에서는 불가.",
 "最强的结缘护符。结缘时举起它：+45%，“归我！”少点6下。1件，使用后消耗。仅限剧情，联赛中无效。",
 "最強的羈絆護符。羈絆時舉起它：+45%，“歸我！”少點6下。1件，使用後消耗。僅限劇情，聯賽中無效。",
 "O melhor amuleto de vínculo. Mostre-o durante um vínculo: +45%, e É meu! pede 6 toques a menos. 1 unidade, é gasto ao usar. Só na história, não nas ligas.",
 "Лучший амулет связи. Покажи его при связи: +45%, и для Мой! нужно на 6 нажатий меньше. 1 штука, расходуется. Только сюжет, не в лигах.",
 "Najlepszy amulet więzi. Pokaż go podczas więzi: +45%, a Mój! wymaga o 6 stuknięć mniej. 1 sztuka, zużywa się. Tylko fabuła, nie w ligach.",
 "En güçlü bağ tılsımı. Bağ kurarken uzat: +%45, ve Benim! 6 dokunuş daha az ister. 1 adet, kullanınca tükenir. Sadece hikâye, liglerde değil.",
 "Het sterkste bindamulet. Houd het voor tijdens een binding: +45%, en Van mij! vraagt 6 tikken minder. 1 stuk, raakt op. Alleen verhaal, niet in competities."],
# One-line effects in the charm picker
"+10% bond": ["+10 % Bindung", "絆+10%", "+10% lien", "+10% legame", "+10% vínculo", "유대 +10%", "结缘+10%", "羈絆+10%", "+10% vínculo", "+10% к связи", "+10% więzi", "Bağ +%10", "+10% binding"],
"+18% bond, 2 taps fewer": ["+18 % Bindung, 2 Tipper weniger", "絆+18%、タップ2回減", "+18% lien, 2 tapes de moins", "+18% legame, 2 tocchi in meno", "+18% vínculo, 2 toques menos", "유대 +18%, 탭 2번 감소", "结缘+18%，少点2下", "羈絆+18%，少點2下", "+18% vínculo, 2 toques a menos", "+18% к связи, на 2 нажатия меньше", "+18% więzi, 2 stuknięcia mniej", "Bağ +%18, 2 dokunuş az", "+18% binding, 2 tikken minder"],
"+6%, same element +36%": ["+6 %, gleiches Element +36 %", "+6%、同じ属性なら+36%", "+6%, même élément +36%", "+6%, stesso elemento +36%", "+6%, mismo elemento +36%", "+6%, 같은 속성 +36%", "+6%，同属性+36%", "+6%，同屬性+36%", "+6%, mesmo elemento +36%", "+6%, та же стихия +36%", "+6%, ten sam żywioł +36%", "+%6, aynı element +%36", "+6%, zelfde element +36%"],
"+6%, dusk and night +36%": ["+6 %, Dämmerung und Nacht +36 %", "+6%、夕暮れと夜は+36%", "+6%, crépuscule et nuit +36%", "+6%, crepuscolo e notte +36%", "+6%, anochecer y noche +36%", "+6%, 해질녘과 밤 +36%", "+6%，黄昏和夜晚+36%", "+6%，黃昏和夜晚+36%", "+6%, entardecer e noite +36%", "+6%, сумерки и ночь +36%", "+6%, zmierzch i noc +36%", "+%6, akşam ve gece +%36", "+6%, schemering en nacht +36%"],
"+6%, rain, fog, wind, storm +36%": ["+6 %, Regen, Nebel, Wind, Sturm +36 %", "+6%、雨・霧・風・嵐は+36%", "+6%, pluie, brouillard, vent, orage +36%", "+6%, pioggia, nebbia, vento, tempesta +36%", "+6%, lluvia, niebla, viento, tormenta +36%", "+6%, 비·안개·바람·폭풍 +36%", "+6%，雨、雾、风、风暴+36%", "+6%，雨、霧、風、風暴+36%", "+6%, chuva, neblina, vento, tempestade +36%", "+6%, дождь, туман, ветер, гроза +36%", "+6%, deszcz, mgła, wiatr, burza +36%", "+%6, yağmur, sis, rüzgâr, fırtına +%36", "+6%, regen, mist, wind, storm +36%"],
"+6%, worn down +36%": ["+6 %, geschwächt +36 %", "+6%、弱っていれば+36%", "+6%, affaibli +36%", "+6%, indebolito +36%", "+6%, debilitado +36%", "+6%, 약해졌으면 +36%", "+6%，虚弱时+36%", "+6%，虛弱時+36%", "+6%, enfraquecido +36%", "+6%, ослаблен +36%", "+6%, osłabiony +36%", "+%6, zayıflamışsa +%36", "+6%, verzwakt +36%"],
"+8%, shy and ancient +43%": ["+8 %, scheue und uralte +43 %", "+8%、内気・古代なら+43%", "+8%, timides et anciens +43%", "+8%, timidi e antichi +43%", "+8%, tímidos y antiguos +43%", "+8%, 수줍음·고대종 +43%", "+8%，怕生和远古+43%", "+8%，怕生和遠古+43%", "+8%, tímidos e antigos +43%", "+8%, пугливые и древние +43%", "+8%, płochliwe i pradawne +43%", "+%8, ürkek ve kadim +%43", "+8%, schuw en oeroud +43%"],
"+8% bond, 6 taps fewer": ["+8 % Bindung, 6 Tipper weniger", "絆+8%、タップ6回減", "+8% lien, 6 tapes de moins", "+8% legame, 6 tocchi in meno", "+8% vínculo, 6 toques menos", "유대 +8%, 탭 6번 감소", "结缘+8%，少点6下", "羈絆+8%，少點6下", "+8% vínculo, 6 toques a menos", "+8% к связи, на 6 нажатий меньше", "+8% więzi, 6 stuknięć mniej", "Bağ +%8, 6 dokunuş az", "+8% binding, 6 tikken minder"],
"+30% bond, 4 taps fewer": ["+30 % Bindung, 4 Tipper weniger", "絆+30%、タップ4回減", "+30% lien, 4 tapes de moins", "+30% legame, 4 tocchi in meno", "+30% vínculo, 4 toques menos", "유대 +30%, 탭 4번 감소", "结缘+30%，少点4下", "羈絆+30%，少點4下", "+30% vínculo, 4 toques a menos", "+30% к связи, на 4 нажатия меньше", "+30% więzi, 4 stuknięcia mniej", "Bağ +%30, 4 dokunuş az", "+30% binding, 4 tikken minder"],
"+45% bond, 6 taps fewer": ["+45 % Bindung, 6 Tipper weniger", "絆+45%、タップ6回減", "+45% lien, 6 tapes de moins", "+45% legame, 6 tocchi in meno", "+45% vínculo, 6 toques menos", "유대 +45%, 탭 6번 감소", "结缘+45%，少点6下", "羈絆+45%，少點6下", "+45% vínculo, 6 toques a menos", "+45% к связи, на 6 нажатий меньше", "+45% więzi, 6 stuknięć mniej", "Bağ +%45, 6 dokunuş az", "+45% binding, 6 tikken minder"],
# Picker rows for the older bond items
"+%d%% bond": ["+%d %% Bindung", "絆+%d%%", "+%d%% lien", "+%d%% legame", "+%d%% vínculo", "유대 +%d%%", "结缘+%d%%", "羈絆+%d%%", "+%d%% vínculo", "+%d%% к связи", "+%d%% więzi", "Bağ +%%%d", "+%d%% binding"],
"Sure bond": ["Sichere Bindung", "絆が必ず成功", "Lien assuré", "Legame sicuro", "Vínculo seguro", "유대 확정", "必定结缘", "必定結下羈絆", "Vínculo garantido", "Связь наверняка", "Pewna więź", "Kesin bağ", "Zekere binding"],
"A second try if it fails": ["Zweiter Versuch, wenn es scheitert", "失敗したらもう一度", "Un 2e essai en cas d'échec", "Un secondo tentativo se fallisce", "Un segundo intento si falla", "실패하면 한 번 더", "失败时再试一次", "失敗時再試一次", "Uma 2ª tentativa se falhar", "Вторая попытка при неудаче", "Druga próba, gdy się nie uda", "Tutmazsa ikinci deneme", "Tweede poging als het mislukt"],
"Top Spark if it works": ["Höchster Funke, wenn es klappt", "成功すれば最高のスパーク", "Étincelle max si ça marche", "Scintilla massima se riesce", "Chispa máxima si sale", "성공하면 최고 스파크", "成功时满火花", "成功時滿火花", "Faísca máxima se der certo", "Максимальная Искра при успехе", "Najwyższa Iskra, gdy się uda", "Tutarsa en yüksek Kıvılcım", "Hoogste Vonk als het lukt"],
"No charm": ["Kein Amulett", "お守りなし", "Sans charme", "Nessun amuleto", "Sin amuleto", "부적 없음", "不用护符", "不用護符", "Sem amuleto", "Без амулета", "Bez amuletu", "Tılsımsız", "Geen amulet"],
# Shop page
"Bond charms": ["Bindungsamulette", "絆のお守り", "Charmes de lien", "Amuleti di legame", "Amuletos de vínculo", "유대 부적", "结缘护符", "羈絆護符", "Amuletos de vínculo", "Амулеты связи", "Amulety więzi", "Bağ tılsımları", "Bindamuletten"],
"Hold a charm out before Mine! and the bond comes easier. Merchants in the towns sell the coin charms.": [
 "Halte vor Meins! ein Amulett hin, dann gelingt die Bindung leichter. Die Münz-Amulette verkaufen Händler in den Städten.",
 "「おれの！」の前にお守りをかかげると絆が結びやすくなる。コインで買えるお守りは町の商人が売っている。",
 "Tends un charme avant C'est à moi! et le lien vient plus facilement. Les marchands des villes vendent les charmes à pièces.",
 "Mostra un amuleto prima di Mio! e il legame riesce più facile. I mercanti delle città vendono gli amuleti a monete.",
 "Ofrece un amuleto antes de ¡Mío! y el vínculo sale más fácil. Los mercaderes de los pueblos venden los amuletos por monedas.",
 "내 거야! 전에 부적을 내밀면 유대가 쉬워집니다. 코인 부적은 마을 상인이 팝니다.",
 "在“归我！”之前举起护符，结缘更容易。用金币买的护符由城镇商人出售。",
 "在“歸我！”之前舉起護符，結下羈絆更容易。用金幣買的護符由城鎮商人出售。",
 "Mostre um amuleto antes de É meu! e o vínculo fica mais fácil. Os mercadores das cidades vendem os amuletos por moedas.",
 "Покажи амулет перед Мой!, и связь даётся легче. Амулеты за монеты продают торговцы в городах.",
 "Pokaż amulet przed Mój!, a więź przyjdzie łatwiej. Amulety za monety sprzedają kupcy w miastach.",
 "Benim!'den önce bir tılsım uzat, bağ daha kolay kurulur. Jetonlu tılsımları kasabalardaki tüccarlar satar.",
 "Houd vóór Van mij! een amulet voor en de binding gaat makkelijker. Handelaars in de steden verkopen de muntamuletten."],
}

# Real-money bundle texts: build_offers_sql.py reads the German store text from de_shop.T, so these sit in
# tools/i18n/de_shop.py and data/i18n/<code>/shop.json (written once by --shop) instead of this table.
SHOP = {
"Swiftleaf x3": ["Flinkblatt x3", "疾風の葉 x3", "Feuille-vive x3", "Foglia lesta x3", "Hoja veloz x3", "날쌘 잎 x3", "疾叶 x3", "疾葉 x3", "Folha ligeira x3", "Быстролист x3", "Bystry liść x3", "Çevik Yaprak x3", "Vlugblad x3"],
"Rift Lantern x3": ["Risslaterne x3", "裂け目のランタン x3", "Lanterne de Faille x3", "Lanterna dello squarcio x3", "Farol de la Grieta x3", "균열 등불 x3", "裂隙提灯 x3", "裂隙提燈 x3", "Lanterna da Fenda x3", "Фонарь Разлома x3", "Latarnia Szczeliny x3", "Yarık Feneri x3", "Klooflantaarn x3"],
"Charm Satchel": ["Amulett-Tasche", "お守りの袋", "Sacoche de charmes", "Borsa di amuleti", "Bolsa de amuletos", "부적 주머니", "护符袋", "護符袋", "Bolsa de amuletos", "Сумка амулетов", "Torba amuletów", "Tılsım Çantası", "Amulettas"],
"3 Swiftleaves: each makes one bond 8% easier and Mine! 6 taps shorter. Single price 300 Riftglass. Story only, not in leagues.": [
 "3 Flinkblätter: jedes macht eine Bindung 8 % leichter und Meins! 6 Tipper kürzer. Einzelpreis 300 Rissglas. Nur Geschichte, nicht in Ligen.",
 "疾風の葉3個：1個ごとに絆が8%結びやすくなり、「おれの！」が6タップ短くなる。単品価格は裂け目ガラス300。ストーリー限定、リーグでは無効。",
 "3 Feuilles-vives: chacune rend un lien 8% plus facile et C'est à moi! 6 tapes plus court. Prix à l'unité: 300 Verre de Faille. Histoire seulement, pas en ligue.",
 "3 Foglie leste: ognuna rende un legame più facile dell'8% e Mio! più corto di 6 tocchi. Prezzo singolo 300 Vetro-squarcio. Solo storia, non nelle leghe.",
 "3 Hojas veloces: cada una hace un vínculo un 8% más fácil y ¡Mío! 6 toques más corto. Precio por unidad: 300 Vidrio Grieta. Solo historia, no en ligas.",
 "날쌘 잎 3개: 각각 유대 한 번을 8% 쉽게, 내 거야!를 탭 6번 짧게 만든다. 개별 가격 균열유리 300. 스토리 전용, 리그에서는 불가.",
 "3片疾叶：每片让一次结缘容易8%，“归我！”少点6下。单价300裂隙晶。仅限剧情，联赛中无效。",
 "3片疾葉：每片讓一次羈絆容易8%，“歸我！”少點6下。單價300裂晶。僅限劇情，聯賽中無效。",
 "3 Folhas ligeiras: cada uma deixa um vínculo 8% mais fácil e É meu! 6 toques mais curto. Preço avulso 300 de Vidrofenda. Só na história, não nas ligas.",
 "3 Быстролиста: каждый облегчает одну связь на 8% и укорачивает Мой! на 6 нажатий. Цена за штуку 300 Стекла Разлома. Только сюжет, не в лигах.",
 "3 Bystre liście: każdy ułatwia jedną więź o 8% i skraca Mój! o 6 stuknięć. Cena za sztukę 300 Szczelinitu. Tylko fabuła, nie w ligach.",
 "3 Çevik Yaprak: her biri bir bağı %8 kolaylaştırır ve Benim!'i 6 dokunuş kısaltır. Tanesi 300 Yarık Camı. Sadece hikâye, liglerde değil.",
 "3 Vlugbladen: elk maakt één binding 8% makkelijker en Van mij! 6 tikken korter. Losse prijs 300 Kloofglas. Alleen verhaal, niet in competities."],
"3 Rift Lanterns: each makes one bond 30% easier and Mine! 4 taps shorter. Single price 600 Riftglass. Story only, not in leagues.": [
 "3 Risslaternen: jede macht eine Bindung 30 % leichter und Meins! 4 Tipper kürzer. Einzelpreis 600 Rissglas. Nur Geschichte, nicht in Ligen.",
 "裂け目のランタン3個：1個ごとに絆が30%結びやすくなり、「おれの！」が4タップ短くなる。単品価格は裂け目ガラス600。ストーリー限定、リーグでは無効。",
 "3 Lanternes de Faille: chacune rend un lien 30% plus facile et C'est à moi! 4 tapes plus court. Prix à l'unité: 600 Verre de Faille. Histoire seulement, pas en ligue.",
 "3 Lanterne dello squarcio: ognuna rende un legame più facile del 30% e Mio! più corto di 4 tocchi. Prezzo singolo 600 Vetro-squarcio. Solo storia, non nelle leghe.",
 "3 Faroles de la Grieta: cada uno hace un vínculo un 30% más fácil y ¡Mío! 4 toques más corto. Precio por unidad: 600 Vidrio Grieta. Solo historia, no en ligas.",
 "균열 등불 3개: 각각 유대 한 번을 30% 쉽게, 내 거야!를 탭 4번 짧게 만든다. 개별 가격 균열유리 600. 스토리 전용, 리그에서는 불가.",
 "3盏裂隙提灯：每盏让一次结缘容易30%，“归我！”少点4下。单价600裂隙晶。仅限剧情，联赛中无效。",
 "3盞裂隙提燈：每盞讓一次羈絆容易30%，“歸我！”少點4下。單價600裂晶。僅限劇情，聯賽中無效。",
 "3 Lanternas da Fenda: cada uma deixa um vínculo 30% mais fácil e É meu! 4 toques mais curto. Preço avulso 600 de Vidrofenda. Só na história, não nas ligas.",
 "3 Фонаря Разлома: каждый облегчает одну связь на 30% и укорачивает Мой! на 4 нажатия. Цена за штуку 600 Стекла Разлома. Только сюжет, не в лигах.",
 "3 Latarnie Szczeliny: każda ułatwia jedną więź o 30% i skraca Mój! o 4 stuknięcia. Cena za sztukę 600 Szczelinitu. Tylko fabuła, nie w ligach.",
 "3 Yarık Feneri: her biri bir bağı %30 kolaylaştırır ve Benim!'i 4 dokunuş kısaltır. Tanesi 600 Yarık Camı. Sadece hikâye, liglerde değil.",
 "3 Klooflantaarns: elk maakt één binding 30% makkelijker en Van mij! 4 tikken korter. Losse prijs 600 Kloofglas. Alleen verhaal, niet in competities."],
"2 Hush Feathers, 2 Swiftleaves, 2 Rift Lanterns, 2 Firstlight Crests. Single price 1800 Riftglass. Story only, not in leagues.": [
 "2 Stillfedern, 2 Flinkblätter, 2 Risslaternen, 2 Erstlicht-Wappen. Einzelpreis 1800 Rissglas. Nur Geschichte, nicht in Ligen.",
 "静寂の羽2個、疾風の葉2個、裂け目のランタン2個、初光の紋章2個。単品価格は裂け目ガラス1800。ストーリー限定、リーグでは無効。",
 "2 Plumes de silence, 2 Feuilles-vives, 2 Lanternes de Faille, 2 Blasons de l'aube. Prix à l'unité: 1800 Verre de Faille. Histoire seulement, pas en ligue.",
 "2 Piume del silenzio, 2 Foglie leste, 2 Lanterne dello squarcio, 2 Stemmi della prima luce. Prezzo singolo 1800 Vetro-squarcio. Solo storia, non nelle leghe.",
 "2 Plumas del silencio, 2 Hojas veloces, 2 Faroles de la Grieta, 2 Blasones del alba. Precio por unidad: 1800 Vidrio Grieta. Solo historia, no en ligas.",
 "고요의 깃털 2개, 날쌘 잎 2개, 균열 등불 2개, 첫빛 문장 2개. 개별 가격 균열유리 1800. 스토리 전용, 리그에서는 불가.",
 "静谧之羽2个、疾叶2片、裂隙提灯2盏、初光纹章2枚。单价1800裂隙晶。仅限剧情，联赛中无效。",
 "靜謐之羽2個、疾葉2片、裂隙提燈2盞、初光紋章2枚。單價1800裂晶。僅限劇情，聯賽中無效。",
 "2 Penas do silêncio, 2 Folhas ligeiras, 2 Lanternas da Fenda, 2 Brasões da primeira luz. Preço avulso 1800 de Vidrofenda. Só na história, não nas ligas.",
 "2 Пера тишины, 2 Быстролиста, 2 Фонаря Разлома, 2 Герба первого света. Цена за штуку 1800 Стекла Разлома. Только сюжет, не в лигах.",
 "2 Pióra ciszy, 2 Bystre liście, 2 Latarnie Szczeliny, 2 Herby pierwszego światła. Cena za sztukę 1800 Szczelinitu. Tylko fabuła, nie w ligach.",
 "2 Sessizlik Tüyü, 2 Çevik Yaprak, 2 Yarık Feneri, 2 İlk Işık Arması. Tanesi 1800 Yarık Camı. Sadece hikâye, liglerde değil.",
 "2 Stilteveren, 2 Vlugbladen, 2 Klooflantaarns, 2 Eerstlichtwapens. Losse prijs 1800 Kloofglas. Alleen verhaal, niet in competities."],
}


def main():
    import sys
    for row in list(R.values()) + list(SHOP.values()):
        assert len(row) == 1 + len(LANGS), row
    for i, code in enumerate(LANGS, 1):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table bond_charms, written by tools/i18n/locales_bond_charms.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        with open(os.path.join(ROOT, "data/i18n", code, "bond_charms.json"), "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
        if "--shop" in sys.argv:
            path = os.path.join(ROOT, "data/i18n", code, "shop.json")
            shop = json.load(open(path, encoding="utf-8"))
            for k, v in SHOP.items():
                shop["strings"][k] = v[i]
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(json.dumps(shop, ensure_ascii=False, indent=1) + "\n")
    print("bond_charms: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
