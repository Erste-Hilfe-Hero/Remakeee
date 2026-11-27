#!/usr/bin/env python3
"""Translations of the German table map_pass (tools/i18n/de_map_pass.py) for the other 12 locales.
Writes data/i18n/<code>/map_pass.json. Run: python3 tools/i18n/locales_map_pass.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Pointsman's House": ["転てつ手の家", "Maison de l'aiguilleur", "Casa del deviatore", "Casa del guardagujas", "전철수의 집", "扳道工之家", "扳道工之家", "Casa do agulheiro", "Дом стрелочника", "Dom zwrotniczego", "Makasçının Evi", "Huis van de wisselwachter"],
"Lamp Room": ["ランプ室", "Salle des lampes", "Stanza delle lampade", "Cuarto de lámparas", "등불방", "灯房", "燈房", "Sala das lamparinas", "Ламповая", "Lampiarnia", "Lamba Odası", "Lampenkamer"],
"Freight Office": ["貨物事務所", "Bureau du fret", "Ufficio merci", "Oficina de carga", "화물 사무소", "货运处", "貨運處", "Escritório de carga", "Грузовая контора", "Biuro towarowe", "Yük Bürosu", "Vrachtkantoor"],
"Engraver's Workshop": ["彫版師の工房", "Atelier de la graveuse", "Bottega dell'incisora", "Taller de la grabadora", "판화공의 작업장", "雕版师工坊", "雕版師工坊", "Oficina da gravadora", "Мастерская гравёра", "Pracownia grawerki", "Oymacının Atölyesi", "Werkplaats van de graveur"],
"Pointsman Ulf: The points freeze every winter. I thaw them with my breakfast.": [
    "転てつ手ウルフ: ポイントは毎冬凍りつく。わしは朝飯で溶かしとる。",
    "Aiguilleur Ulf : Les aiguillages gèlent chaque hiver. Je les dégèle avec mon petit-déjeuner.",
    "Deviatore Ulf: Gli scambi gelano ogni inverno. Li sgelo con la mia colazione.",
    "Guardagujas Ulf: Las agujas se congelan cada invierno. Las descongelo con mi desayuno.",
    "전철수 울프: 선로 전환기는 겨울마다 얼어붙지. 난 아침밥으로 녹인다네.",
    "扳道工乌尔夫：道岔每年冬天都会冻住。我用早饭把它们化开。",
    "扳道工烏爾夫：道岔每年冬天都會凍住。我用早飯把它們化開。",
    "Agulheiro Ulf: As agulhas congelam todo inverno. Eu as descongelo com o meu café da manhã.",
    "Стрелочник Ульф: Стрелки замерзают каждую зиму. Я оттаиваю их своим завтраком.",
    "Zwrotniczy Ulf: Zwrotnice zamarzają co zimę. Rozmrażam je swoim śniadaniem.",
    "Makasçı Ulf: Makaslar her kış donar. Ben onları kahvaltımla çözerim.",
    "Wisselwachter Ulf: De wissels bevriezen elke winter. Ik ontdooi ze met mijn ontbijt."],
"Pointsman Ulf: Porridge works best. Do not tell the guild.": [
    "転てつ手ウルフ: 一番効くのはおかゆだ。ギルドには言うなよ。",
    "Aiguilleur Ulf : C'est le porridge qui marche le mieux. Ne le dites pas à la guilde.",
    "Deviatore Ulf: Il porridge funziona meglio. Non dirlo alla gilda.",
    "Guardagujas Ulf: Las gachas funcionan mejor. No se lo digas al gremio.",
    "전철수 울프: 죽이 제일 잘 들어. 길드엔 말하지 마.",
    "扳道工乌尔夫：粥最管用。别告诉公会。",
    "扳道工烏爾夫：粥最管用。別告訴公會。",
    "Agulheiro Ulf: Mingau funciona melhor. Não conte para a guilda.",
    "Стрелочник Ульф: Лучше всего помогает каша. Гильдии не говори.",
    "Zwrotniczy Ulf: Najlepiej działa owsianka. Nie mów cechowi.",
    "Makasçı Ulf: En iyisi yulaf lapası. Loncaya söyleme.",
    "Wisselwachter Ulf: Pap werkt het best. Zeg het niet tegen het gilde."],
"Lampwright Ines: Every lamp on the platform is mine. The smoke is the stack's.": [
    "ランプ職人イネス: ホームのランプは全部わたしの作。煙は煙突のせいよ。",
    "Lampiste Ines : Chaque lampe du quai est de moi. La fumée, c'est la cheminée.",
    "Lampionaia Ines: Ogni lampada sul binario è mia. Il fumo è del camino.",
    "Lamparera Ines: Cada lámpara del andén es mía. El humo es de la chimenea.",
    "등불장이 이네스: 승강장의 등불은 전부 내 거야. 연기는 굴뚝 탓이고.",
    "制灯匠伊内丝：站台上每一盏灯都是我做的。烟是烟囱的。",
    "製燈匠伊內絲：月台上每一盞燈都是我做的。煙是煙囪的。",
    "Lampioneira Ines: Toda lamparina da plataforma é minha. A fumaça é da chaminé.",
    "Ламповщица Инес: Каждая лампа на перроне моя. А дым от трубы.",
    "Lampiarka Ines: Każda lampa na peronie jest moja. Dym jest od komina.",
    "Lambacı Ines: Perondaki her lamba benim. Duman bacanın.",
    "Lampenmaakster Ines: Elke lamp op het perron is van mij. De rook is van de schoorsteen."],
"Lampwright Ines: A train in fog finds the station by my wicks. Trim them and you trim the timetable.": [
    "ランプ職人イネス: 霧の中の汽車は、わたしの灯芯で駅を見つけるの。芯を切れば時刻表も切れるわ。",
    "Lampiste Ines : Dans le brouillard, le train trouve la gare grâce à mes mèches. Coupez-les, et vous coupez l'horaire.",
    "Lampionaia Ines: Nella nebbia il treno trova la stazione grazie ai miei stoppini. Accorciali e accorci l'orario.",
    "Lamparera Ines: Un tren en la niebla encuentra la estación por mis mechas. Recórtalas y recortas el horario.",
    "등불장이 이네스: 안개 속 기차는 내 심지를 보고 역을 찾아. 심지를 자르면 시간표도 잘리지.",
    "制灯匠伊内丝：雾里的火车靠我的灯芯找到车站。剪短灯芯，就剪短了时刻表。",
    "製燈匠伊內絲：霧裡的火車靠我的燈芯找到車站。剪短燈芯，就剪短了時刻表。",
    "Lampioneira Ines: Um trem na neblina acha a estação pelos meus pavios. Apare-os e você apara o horário.",
    "Ламповщица Инес: В тумане поезд находит станцию по моим фитилям. Подрежь их, и подрежешь расписание.",
    "Lampiarka Ines: Pociąg we mgle znajduje stację po moich knotach. Przytnij je, a przytniesz rozkład jazdy.",
    "Lambacı Ines: Siste bir tren istasyonu benim fitillerimle bulur. Onları kısaltırsan sefer çizelgesini de kısaltırsın.",
    "Lampenmaakster Ines: Een trein in de mist vindt het station aan mijn lonten. Knip ze bij en je knipt de dienstregeling bij."],
"Clerk Odo: Crates go up the mountain full of plates and come down full of soot.": [
    "事務員オド: 木箱は版を満載して山を登り、すすを満載して下りてくる。",
    "Commis Odo : Les caisses montent pleines de plaques et redescendent pleines de suie.",
    "Impiegato Odo: Le casse salgono piene di lastre e scendono piene di fuliggine.",
    "Escribiente Odo: Las cajas suben llenas de planchas y bajan llenas de hollín.",
    "서기 오도: 상자는 판을 가득 싣고 산을 올라가서 그을음을 가득 싣고 내려와.",
    "文书欧多：箱子装满版子上山，装满煤灰下山。",
    "文書歐多：箱子裝滿版子上山，裝滿煤灰下山。",
    "Escriturário Odo: Os caixotes sobem a montanha cheios de chapas e descem cheios de fuligem.",
    "Писарь Одо: Ящики едут в гору полные пластин, а спускаются полные сажи.",
    "Urzędnik Odo: Skrzynie jadą pod górę pełne płyt, a wracają pełne sadzy.",
    "Kâtip Odo: Sandıklar dağa levhayla dolu çıkar, isle dolu iner.",
    "Klerk Odo: Kisten gaan de berg op vol platen en komen terug vol roet."],
"Clerk Odo: I weigh both. The soot is heavier. Nobody believes me.": [
    "事務員オド: どっちも量っている。すすの方が重い。誰も信じてくれないがね。",
    "Commis Odo : Je pèse les deux. La suie est plus lourde. Personne ne me croit.",
    "Impiegato Odo: Le peso entrambe. La fuliggine pesa di più. Nessuno mi crede.",
    "Escribiente Odo: Peso ambas. El hollín pesa más. Nadie me cree.",
    "서기 오도: 둘 다 달아 봐. 그을음이 더 무거워. 아무도 안 믿지만.",
    "文书欧多：两样我都称过。煤灰更重。没人信我。",
    "文書歐多：兩樣我都秤過。煤灰更重。沒人信我。",
    "Escriturário Odo: Eu peso os dois. A fuligem é mais pesada. Ninguém acredita em mim.",
    "Писарь Одо: Я взвешиваю и то и другое. Сажа тяжелее. Никто мне не верит.",
    "Urzędnik Odo: Ważę jedno i drugie. Sadza jest cięższa. Nikt mi nie wierzy.",
    "Kâtip Odo: İkisini de tartarım. İs daha ağır. Kimse bana inanmıyor.",
    "Klerk Odo: Ik weeg allebei. Het roet is zwaarder. Niemand gelooft me."],
"Engraver Mira: A plate takes a year to cut and a second to drop. I have not dropped one. Yet.": [
    "彫版師ミラ: 版を彫るのに一年、落とすのは一秒。まだ一枚も落としてない。まだね。",
    "Graveuse Mira : Une plaque prend un an à graver et une seconde à tomber. Je n'en ai jamais fait tomber. Pas encore.",
    "Incisora Mira: Una lastra richiede un anno per incidere e un secondo per cadere. Non ne ho mai fatta cadere una. Per ora.",
    "Grabadora Mira: Una plancha tarda un año en grabarse y un segundo en caerse. No se me ha caído ninguna. Todavía.",
    "판화공 미라: 판 하나 새기는 데 일 년, 떨어뜨리는 데 일 초. 아직 하나도 안 떨어뜨렸어. 아직은.",
    "雕版师米拉：刻一块版要一年，摔掉只要一秒。我还没摔过一块。暂时。",
    "雕版師米拉：刻一塊版要一年，摔掉只要一秒。我還沒摔過一塊。暫時。",
    "Gravadora Mira: Uma chapa leva um ano para gravar e um segundo para cair. Ainda não deixei cair nenhuma. Ainda.",
    "Гравёр Мира: Пластину режешь год, а роняешь за секунду. Я ещё ни одной не уронила. Пока.",
    "Grawerka Mira: Płytę ryje się rok, a upuszcza w sekundę. Jeszcze żadnej nie upuściłam. Jeszcze.",
    "Oymacı Mira: Bir levhayı oymak bir yıl, düşürmek bir saniye sürer. Henüz hiç düşürmedim. Henüz.",
    "Graveur Mira: Een plaat snijden kost een jaar, laten vallen een seconde. Ik heb er nog geen laten vallen. Nog niet."],
"Engraver Mira: Halvard says my lines are too soft. Halvard says that to everyone.": [
    "彫版師ミラ: ハルヴァルドはわたしの線がやわらかすぎるって言う。誰にでもそう言うのよ。",
    "Graveuse Mira : Halvard dit que mes traits sont trop doux. Halvard dit ça à tout le monde.",
    "Incisora Mira: Halvard dice che le mie linee sono troppo morbide. Halvard lo dice a tutti.",
    "Grabadora Mira: Halvard dice que mis líneas son demasiado suaves. Halvard se lo dice a todos.",
    "판화공 미라: 할바르드는 내 선이 너무 무르대. 할바르드는 누구한테나 그래.",
    "雕版师米拉：哈尔瓦德说我的线条太软。哈尔瓦德对谁都这么说。",
    "雕版師米拉：哈爾瓦德說我的線條太軟。哈爾瓦德對誰都這麼說。",
    "Gravadora Mira: Halvard diz que minhas linhas são suaves demais. Halvard diz isso para todo mundo.",
    "Гравёр Мира: Хальвард говорит, что мои линии слишком мягкие. Хальвард всем так говорит.",
    "Grawerka Mira: Halvard mówi, że moje linie są za miękkie. Halvard mówi tak wszystkim.",
    "Oymacı Mira: Halvard çizgilerimin fazla yumuşak olduğunu söylüyor. Halvard bunu herkese söyler.",
    "Graveur Mira: Halvard zegt dat mijn lijnen te zacht zijn. Halvard zegt dat tegen iedereen."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table map_pass, written by tools/i18n/locales_map_pass.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "map_pass.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("map_pass: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
