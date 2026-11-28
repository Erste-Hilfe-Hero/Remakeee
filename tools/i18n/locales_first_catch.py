#!/usr/bin/env python3
"""Translations of the German table first_catch (tools/i18n/de_first_catch.py) for the other 12 locales.
Writes data/i18n/<code>/first_catch.json. Run: python3 tools/i18n/locales_first_catch.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Kestra: Aldo's apprentice? Good. The storm tore Rifts open, past Thornridge and under the Saltmarsh.": [
 "Kestra: Aldoの弟子？よかった。嵐で裂け目が開いたの。Thornridgeの先と、Saltmarshの地下に。",
 "Kestra: L'apprenti d'Aldo? Bien. La tempête a ouvert des Failles, après Thornridge et sous le Saltmarsh.",
 "Kestra: L'apprendista di Aldo? Bene. La tempesta ha aperto degli Squarci, oltre Thornridge e sotto Saltmarsh.",
 "Kestra: ¿Aprendiz de Aldo? Bien. La tormenta abrió Grietas, pasado Thornridge y bajo Saltmarsh.",
 "Kestra: Aldo의 제자? 잘됐다. 폭풍이 균열을 열었어. Thornridge 너머랑 Saltmarsh 밑에.",
 "Kestra：Aldo的学徒？很好。暴风雨撕开了裂隙，在Thornridge过去和Saltmarsh底下。",
 "Kestra：Aldo的學徒？很好。暴風雨撕開了裂隙，在Thornridge另一頭和Saltmarsh底下。",
 "Kestra: Aprendiz do Aldo? Ótimo. A tempestade abriu Fendas, depois de Thornridge e sob Saltmarsh.",
 "Kestra: Ученик Aldo? Хорошо. Шторм открыл Разломы: за Thornridge и под Saltmarsh.",
 "Kestra: Uczeń Aldo? Dobrze. Burza otworzyła Szczeliny, za Thornridge i pod Saltmarsh.",
 "Kestra: Aldo'nun çırağı mı? Güzel. Fırtına Yarıklar açtı, Thornridge'in ötesinde ve Saltmarsh'ın altında.",
 "Kestra: Aldo's leerling? Mooi. De storm scheurde Kloven open, voorbij Thornridge en onder de Saltmarsh."],
"Kestra: Everyone wants them closed. I'm not so sure: new Spirlings came through. But start north in Fernstair.": [
 "Kestra: みんな閉じたがってる。わたしはそうは思わない。新しいSpirlingが来たもの。でも、まずは北のFernstairから。",
 "Kestra: Tout le monde veut les fermer. Moi, je ne suis pas sûre: de nouveaux Spirlings sont passés. Mais commence au nord, à Fernstair.",
 "Kestra: Tutti li vogliono chiusi. Io non ne sono sicura: sono arrivati nuovi Spirling. Ma comincia a nord, a Fernstair.",
 "Kestra: Todos quieren cerrarlas. Yo no lo tengo claro: llegaron Spirlings nuevos. Pero empieza al norte, en Fernstair.",
 "Kestra: 다들 닫고 싶어 해. 난 잘 모르겠어. 새로운 Spirling들이 건너왔거든. 그래도 북쪽 Fernstair부터 가.",
 "Kestra：大家都想把它们关上。我可不确定：有新的Spirling过来了。不过先往北去Fernstair。",
 "Kestra：大家都想把它們關起來。我可不確定：有新的Spirling過來了。不過先往北去Fernstair。",
 "Kestra: Todo mundo quer fechá-las. Eu não tenho certeza: Spirlings novos passaram. Mas comece pelo norte, em Fernstair.",
 "Kestra: Все хотят их закрыть. А я не уверена: пришли новые Spirlings. Но начни с севера, с Fernstair.",
 "Kestra: Wszyscy chcą je zamknąć. Ja nie jestem pewna: przyszły nowe Spirlingi. Ale zacznij na północy, w Fernstair.",
 "Kestra: Herkes kapansınlar istiyor. Ben emin değilim: yeni Spirling'ler geldi. Ama kuzeyden, Fernstair'den başla.",
 "Kestra: Iedereen wil ze dicht. Ik weet het niet: er kwamen nieuwe Spirlings door. Maar begin in het noorden, in Fernstair."],
"Kestra: And this blew in through my window. Mirela's compass rose. Yours, I think.": [
 "Kestra: それと、これが窓から飛びこんできたの。Mirelaのコンパスローズ。あなたのね。",
 "Kestra: Et ça est entré par ma fenêtre. La rose des vents de Mirela. C'est à toi, je crois.",
 "Kestra: E questo è entrato dalla mia finestra. La rosa dei venti di Mirela. È tuo, credo.",
 "Kestra: Y esto entró volando por mi ventana. La rosa de los vientos de Mirela. Es tuyo, creo.",
 "Kestra: 그리고 이게 창문으로 날아들어 왔어. Mirela의 나침반 장미야. 네 거 같아.",
 "Kestra：还有，这个从我窗户飘进来了。Mirela的罗盘玫瑰。我想是你的。",
 "Kestra：還有，這個從我窗戶飄進來了。Mirela的羅盤玫瑰。我想是你的。",
 "Kestra: E isto entrou pela minha janela. A rosa dos ventos de Mirela. É seu, acho.",
 "Kestra: А это влетело ко мне в окно. Роза ветров Mirela. Кажется, твоё.",
 "Kestra: A to wpadło mi przez okno. Róża wiatrów Mireli. Chyba twoje.",
 "Kestra: Bir de bu pencereden uçup geldi. Mirela'nın pusula gülü. Senin galiba.",
 "Kestra: En dit waaide door mijn raam naar binnen. Mirela's kompasroos. Van jou, denk ik."],
"'Day one. The sky over the lake split like old paper. Aldo says I'm mad to map it. Aldo is usually right.'": [
 "「1日目。湖の上の空が、古い紙のように裂けた。地図にするなんてどうかしてるとAldoは言う。たいていAldoの言うとおり。」",
 "'Jour un. Le ciel au-dessus du lac s'est déchiré comme du vieux papier. Aldo dit que je suis folle de le cartographier. Aldo a généralement raison.'",
 "'Giorno uno. Il cielo sopra il lago si è strappato come carta vecchia. Aldo dice che sono matta a mapparlo. Di solito Aldo ha ragione.'",
 "'Día uno. El cielo sobre el lago se rasgó como papel viejo. Aldo dice que estoy loca por cartografiarlo. Aldo suele tener razón.'",
 "'첫째 날. 호수 위 하늘이 낡은 종이처럼 찢어졌다. Aldo는 그걸 지도로 그리겠다니 내가 미쳤다고 한다. Aldo 말은 대개 맞다.'",
 "「第一天。湖面上的天空像旧纸一样裂开了。Aldo说我要去画它的地图是疯了。Aldo通常都是对的。」",
 "「第一天。湖面上的天空像舊紙一樣裂開了。Aldo說我要去畫它的地圖是瘋了。Aldo通常是對的。」",
 "'Dia um. O céu sobre o lago se rasgou como papel velho. Aldo diz que sou louca de mapeá-lo. Aldo costuma ter razão.'",
 "'День первый. Небо над озером треснуло, как старая бумага. Aldo говорит, что я сошла с ума, раз хочу нанести его на карту. Aldo обычно прав.'",
 "'Dzień pierwszy. Niebo nad jeziorem pękło jak stary papier. Aldo mówi, że zwariowałam, chcąc to zmapować. Aldo zwykle ma rację.'",
 "'Birinci gün. Gölün üstündeki gökyüzü eski kâğıt gibi yırtıldı. Aldo, haritasını çıkarmak istediğim için deli olduğumu söylüyor. Aldo genelde haklıdır.'",
 "'Dag een. De hemel boven het meer scheurde als oud papier. Aldo zegt dat ik gek ben om hem in kaart te brengen. Aldo heeft meestal gelijk.'"],
"Tip: Goals shows how many map pages are still out there.": [
 "ヒント：残りの地図のページの数は「目標」でわかる。",
 "Astuce: Objectifs indique combien de pages de carte restent à trouver.",
 "Consiglio: in Obiettivi vedi quante pagine di mappa mancano ancora.",
 "Consejo: en Objetivos verás cuántas páginas del mapa quedan por ahí.",
 "팁: 목표에서 남은 지도 페이지 수를 볼 수 있다.",
 "提示：「目标」里会显示还剩多少页地图。",
 "提示：「目標」會顯示還剩幾頁地圖。",
 "Dica: em Metas você vê quantas páginas do mapa ainda faltam.",
 "Совет: в Целях видно, сколько страниц карты ещё осталось найти.",
 "Rada: W Celach widać, ile stron map jeszcze czeka.",
 "İpucu: Hedefler, daha kaç harita sayfası olduğunu gösterir.",
 "Tip: Bij Doelen zie je hoeveel kaartpagina's er nog te vinden zijn."],
"Tip: The game saves itself when you change places. Save any time in the menu.": [
 "ヒント：場所を移るとゲームが自動で記録する。メニューでいつでも記録できる。",
 "Astuce: le jeu se sauvegarde quand tu changes de lieu. Sauvegarde à tout moment dans le menu.",
 "Consiglio: il gioco salva da sé quando cambi luogo. Salva quando vuoi dal menu.",
 "Consejo: el juego se guarda solo al cambiar de lugar. Guarda cuando quieras en el menú.",
 "팁: 장소를 옮기면 게임이 자동 저장된다. 메뉴에서 언제든 저장할 수 있다.",
 "提示：切换地点时游戏会自动保存。也可以随时在菜单中保存。",
 "提示：切換地點時遊戲會自動存檔。也能隨時從選單存檔。",
 "Dica: o jogo salva sozinho quando você muda de lugar. Salve quando quiser no menu.",
 "Совет: игра сохраняется сама при смене места. Сохраниться можно в меню в любой момент.",
 "Rada: Gra zapisuje się sama przy zmianie miejsca. W menu możesz zapisać zawsze.",
 "İpucu: Oyun yer değiştirdiğinde kendini kaydeder. Menüden istediğin zaman kaydedebilirsin.",
 "Tip: Het spel slaat zichzelf op als je van plek wisselt. Opslaan kan altijd via het menu."],
"Tip: A wild Spirling that trusts you can join your team.": [
 "ヒント：きみを信じた野生のSpirlingは、チームに入ってくれる。",
 "Astuce: un Spirling sauvage qui te fait confiance peut rejoindre ton équipe.",
 "Consiglio: uno Spirling selvatico che si fida di te può unirsi alla tua squadra.",
 "Consejo: un Spirling salvaje que confía en ti puede unirse a tu equipo.",
 "팁: 너를 믿는 야생 Spirling은 팀에 들어올 수 있다.",
 "提示：信任你的野生Spirling可以加入你的队伍。",
 "提示：信任你的野生Spirling可以加入你的隊伍。",
 "Dica: um Spirling selvagem que confia em você pode entrar na sua equipe.",
 "Подсказка: дикий Spirling, который тебе доверяет, может вступить в команду.",
 "Wskazówka: dziki Spirling, który ci ufa, może dołączyć do drużyny.",
 "İpucu: Sana güvenen vahşi bir Spirling takımına katılabilir.",
 "Tip: een wilde Spirling die je vertrouwt, kan zich bij je team aansluiten."],
"First bond! A gift for the road: %s.": [
 "はじめての絆！旅のおくりもの：%s。",
 "Premier lien! Un cadeau pour la route: %s.",
 "Primo Legame! Un regalo per il viaggio: %s.",
 "¡Primer vínculo! Un regalo para el camino: %s.",
 "첫 유대! 길을 위한 선물: %s.",
 "初次结缘！路上的礼物：%s。",
 "初次羈絆！路上的禮物：%s。",
 "Primeiro Vínculo! Um presente para a estrada: %s.",
 "Первая связь! Подарок в дорогу: %s.",
 "Pierwsza Więź! Prezent na drogę: %s.",
 "İlk Bağ! Yol için bir hediye: %s.",
 "Eerste Band! Een cadeau voor onderweg: %s."],
"Your first bond! A one-time pack": [
 "はじめての絆！一度きりのパック",
 "Ton premier lien! Un lot unique",
 "Il tuo primo Legame! Un pacchetto unico",
 "¡Tu primer vínculo! Un lote único",
 "첫 유대! 한 번뿐인 묶음",
 "你的初次结缘！一次性礼包",
 "你的初次羈絆！一次性組合",
 "Seu primeiro Vínculo! Um pacote único",
 "Твоя первая связь! Разовый набор",
 "Twoja pierwsza Więź! Jednorazowy pakiet",
 "İlk bağın! Tek seferlik paket",
 "Je eerste band! Een eenmalig pakket"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table first_catch, written by tools/i18n/locales_first_catch.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "first_catch.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("first_catch: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
