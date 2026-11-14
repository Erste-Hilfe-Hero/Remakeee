#!/usr/bin/env python3
"""Translations of the German table kampf_k37 (tools/i18n/de_kampf_k37.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k37.json. Run: python3 tools/i18n/locales_kampf_k37.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Their team code": ["相手のチームコード", "Son code d'équipe", "Il suo codice squadra", "Su código de equipo", "상대의 팀 코드", "对方的队伍码", "對方的隊伍碼", "Código de equipe dele", "Код его команды", "Kod jego drużyny", "Onun takım kodu", "Hun teamcode"],
"%s needs three Spirlings in their echo team for a team code.": ["チームコードには、%sのエコーチームに3体のSpirlingが必要だ。", "%s a besoin de trois Spirlings dans son équipe écho pour un code d'équipe.", "A %s servono tre Spirling nella squadra eco per un codice squadra.", "%s necesita tres Spirlings en su equipo eco para un código de equipo.", "팀 코드를 만들려면 %s의 에코 팀에 Spirling이 셋 필요하다.", "%s的回响队伍需要三只Spirling才能生成队伍码。", "%s的迴響隊伍需要三隻Spirling才能產生隊伍碼。", "%s precisa de três Spirlings na equipe eco para um código de equipe.", "Для кода команды %s нужны три Spirling в эхо-команде.", "%s potrzebuje trzech Spirlingów w drużynie echa, by mieć kod drużyny.", "Takım kodu için %s yankı takımında üç Spirling'e ihtiyaç duyuyor.", "%s heeft drie Spirlings in het echoteam nodig voor een teamcode."],
"%s's team code: %s": ["%sのチームコード: %s", "Code d'équipe de %s : %s", "Codice squadra di %s: %s", "Código de equipo de %s: %s", "%s의 팀 코드: %s", "%s的队伍码：%s", "%s的隊伍碼：%s", "Código de equipe de %s: %s", "Код команды %s: %s", "Kod drużyny %s: %s", "%s takım kodu: %s", "Teamcode van %s: %s"],
"It is on the clipboard. Fight it in the Battle Halls under Fight a team code, or pass it on.": ["クリップボードにコピーした。バトルホールの「チームコードと戦う」で挑むか、だれかに渡そう。", "Il est dans le presse-papiers. Affrontez-le dans les salles de combat via Affronter un code d'équipe, ou faites-le passer.", "È negli appunti. Affrontalo nelle sale di lotta con Affronta un codice squadra, o passalo a qualcuno.", "Está en el portapapeles. Enfréntalo en las salas de combate con Luchar contra un código de equipo, o pásalo.", "클립보드에 복사했다. 배틀 전당의 '팀 코드와 싸우기'에서 겨루거나 다른 사람에게 넘기자.", "已复制到剪贴板。在战斗大厅的“挑战队伍码”中与它对战，或者转给别人。", "已複製到剪貼簿。在戰鬥大廳的「挑戰隊伍碼」中與它對戰，或者轉給別人。", "Está na área de transferência. Enfrente-o nos salões de batalha em Enfrentar um código de equipe, ou passe adiante.", "Код скопирован. Сразитесь с ним в боевых залах через «Сразиться с кодом команды» или передайте его дальше.", "Kod jest w schowku. Walcz z nim w halach bitewnych przez Walcz z kodem drużyny albo przekaż go dalej.", "Panoya kopyalandı. Savaş salonlarında Bir takım koduyla savaş ile dövüş ya da başkasına ver.", "Hij staat op het klembord. Vecht ertegen in de gevechtshallen via Vecht tegen een teamcode, of geef hem door."],
"Flame colour: %s": ["炎の色: %s", "Couleur de la flamme : %s", "Colore della fiamma: %s", "Color de la llama: %s", "불꽃 색: %s", "火焰颜色：%s", "火焰顏色：%s", "Cor da chama: %s", "Цвет пламени: %s", "Kolor płomienia: %s", "Alev rengi: %s", "Vlamkleur: %s"],
"Flame colour (caves, from the third era on)": ["炎の色(どうくつで、第3の時代から)", "Couleur de la flamme (grottes, dès la troisième ère)", "Colore della fiamma (grotte, dalla terza era)", "Color de la llama (cuevas, desde la tercera era)", "불꽃 색 (동굴에서, 세 번째 시대부터)", "火焰颜色（洞穴中，第三时代起）", "火焰顏色（洞穴中，第三時代起）", "Cor da chama (cavernas, a partir da terceira era)", "Цвет пламени (в пещерах, с третьей эпохи)", "Kolor płomienia (jaskinie, od trzeciej ery)", "Alev rengi (mağaralarda, üçüncü çağdan itibaren)", "Vlamkleur (grotten, vanaf het derde tijdperk)"],
"The flame turns %s.": ["炎は%sになった。", "La flamme devient %s.", "La fiamma diventa %s.", "La llama se vuelve %s.", "불꽃이 %s(으)로 바뀌었다.", "火焰变成了%s。", "火焰變成了%s。", "A chama fica %s.", "Пламя становится таким: %s.", "Płomień zmienia się: %s.", "Alev %s rengine dönüyor.", "De vlam wordt %s."],
"Lamp Gold": ["ランプの金", "Or de lampe", "Oro di lampada", "Oro de lámpara", "등불 금빛", "灯火金", "燈火金", "Ouro de lamparina", "Ламповое золото", "Lampowe złoto", "Lamba Altını", "Lampgoud"],
"Ember Red": ["おき火の赤", "Rouge braise", "Rosso brace", "Rojo brasa", "잉걸불 빨강", "余烬红", "餘燼紅", "Vermelho brasa", "Угольно-красный", "Żarowa czerwień", "Kor Kırmızısı", "Gloedrood"],
"Drowned Blue": ["溺れた青", "Bleu noyé", "Blu annegato", "Azul ahogado", "익사한 파랑", "溺水蓝", "溺水藍", "Azul afogado", "Утопленный синий", "Topielczy błękit", "Boğulmuş Mavi", "Verdronken blauw"],
"Hall Violet": ["ホールの紫", "Violet des salles", "Viola delle sale", "Violeta de sala", "전당 보라", "大厅紫", "大廳紫", "Violeta dos salões", "Зальный фиолетовый", "Fiolet hal", "Salon Moru", "Hallenviolet"],
"Wardens' Ash": ["守り人たちの灰", "Cendre des Gardiens", "Cenere dei Custodi", "Ceniza de Custodios", "수호자들의 재", "守望者之灰", "守境者之灰", "Cinza das Sentinelas", "Пепел Стражей", "Popiół Strażników", "Muhafızların Külü", "Hoedersas"],
"Always lit.": ["いつでも灯っている。", "Toujours allumée.", "Sempre accesa.", "Siempre encendida.", "언제나 켜져 있다.", "一直亮着。", "一直亮著。", "Sempre acesa.", "Горит всегда.", "Zawsze płonie.", "Hep yanıyor.", "Brandt altijd."],
"Climb the whole lighthouse stair.": ["灯台の階段を最後まで登る。", "Gravissez tout l'escalier du phare.", "Sali tutta la scala del faro.", "Sube toda la escalera del faro.", "등대 계단을 끝까지 오른다.", "登完整座灯塔阶梯。", "登完整座燈塔階梯。", "Suba toda a escada do farol.", "Поднимитесь по всей лестнице маяка.", "Wejdź na sam szczyt schodów latarni.", "Deniz feneri merdiveninin tamamını çık.", "Beklim de hele vuurtorentrap."],
"Reach floor 20 of the endless stretch.": ["果てなき道の20階に着く。", "Atteignez l'étage 20 du parcours sans fin.", "Raggiungi il piano 20 del tratto infinito.", "Llega al piso 20 del tramo sin fin.", "끝없는 구간의 20층에 도달한다.", "抵达无尽路段的第20层。", "抵達無盡路段的第20層。", "Chegue ao andar 20 do trecho sem fim.", "Доберитесь до 20-го этажа бесконечного пути.", "Dotrzyj do piętra 20 niekończącego się odcinka.", "Sonsuz yolun 20. katına ulaş.", "Haal verdieping 20 van het eindeloze traject."],
"Clear the Battle Halls 10 times.": ["バトルホールを10回制覇する。", "Remportez les salles de combat 10 fois.", "Supera le sale di lotta 10 volte.", "Supera las salas de combate 10 veces.", "배틀 전당을 10번 제패한다.", "通关战斗大厅10次。", "通關戰鬥大廳10次。", "Vença os salões de batalha 10 vezes.", "Пройдите боевые залы 10 раз.", "Ukończ hale bitewne 10 razy.", "Savaş salonlarını 10 kez tamamla.", "Voltooi de gevechtshallen 10 keer."],
"Beat every Warden in one master tour.": ["マスター巡りで守り人を全員倒す。", "Battez tous les Gardiens en une seule tournée de maître.", "Sconfiggi tutti i Custodi in un solo giro da maestro.", "Vence a todos los Custodios en una sola ronda de maestría.", "마스터 순회 한 번에 모든 수호자를 이긴다.", "在一次大师巡回中击败所有守望者。", "在一次大師巡迴中擊敗所有守境者。", "Derrote todas as Sentinelas em um único circuito de mestre.", "Победите всех Стражей за один мастерский обход.", "Pokonaj wszystkich Strażników w jednej mistrzowskiej rundzie.", "Tek bir usta turunda tüm Muhafızları yen.", "Versla alle Hoeders in één meesterronde."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k37, written by tools/i18n/locales_kampf_k37.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k37.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k37: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
