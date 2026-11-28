#!/usr/bin/env python3
"""Translations of the German table gleam_kinds (tools/i18n/de_gleam_kinds.py) for the other 12 locales.
Writes data/i18n/<code>/gleam_kinds.json. Run: python3 tools/i18n/locales_gleam_kinds.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Rime Gleam": ["霜の輝き", "Reflet de givre", "Splendore di brina", "Fulgor de escarcha", "서리 광채형", "霜华光泽形态", "霜之輝光", "Reluzente de geada", "Сияние инея", "Szronowy połysk", "Kırağı Işıltısı", "Rijpglansvorm"],
"Inkwash Gleam": ["墨染めの輝き", "Reflet d'encre", "Splendore d'inchiostro", "Fulgor de tinta", "먹빛 광채형", "墨染光泽形态", "墨染輝光", "Reluzente de tinta", "Чернильное сияние", "Atramentowy połysk", "Mürekkep Işıltısı", "Inktglansvorm"],
"Duskgold Gleam": ["夕金の輝き", "Reflet d'or du soir", "Splendore d'oro al tramonto", "Fulgor de oro crepuscular", "노을금 광채형", "暮金光泽形态", "暮金輝光", "Reluzente de ouro do ocaso", "Сияние закатного золота", "Połysk zmierzchowego złota", "Akşam Altını Işıltısı", "Avondgoud-glansvorm"],
"Opaline Gleam": ["乳白の輝き", "Reflet opalin", "Splendore opalino", "Fulgor opalino", "오팔 광채형", "蛋白石光泽形态", "蛋白石輝光", "Reluzente opalino", "Опаловое сияние", "Opalowy połysk", "Opal Işıltısı", "Opaalglansvorm"],
" Frost glitters on its hide: a Rime Gleam!": [
 " 体に霜がきらめく。霜の輝きだ！",
 " Du givre scintille sur sa peau : un Reflet de givre !",
 " La brina scintilla sul suo corpo: uno Splendore di brina!",
 " La escarcha brilla sobre su piel: ¡un Fulgor de escarcha!",
 " 몸에 서리가 반짝인다. 서리 광채형이다!",
 " 霜花在它身上闪烁：霜华光泽形态！",
 " 霜花在牠身上閃爍：霜之輝光！",
 " A geada cintila em sua pele: um Reluzente de geada!",
 " На его шкуре искрится иней: Сияние инея!",
 " Szron skrzy się na jego skórze: szronowy połysk!",
 " Üzerinde kırağı parıldıyor: bir Kırağı Işıltısı!",
 " Rijp glinstert op zijn huid: een Rijpglansvorm!"],
" It is washed in deep ink: an Inkwash Gleam!": [
 " 深い墨に染まっている。墨染めの輝きだ！",
 " Il est baigné d'encre profonde : un Reflet d'encre !",
 " È immerso in un inchiostro profondo: uno Splendore d'inchiostro!",
 " Está bañado en tinta profunda: ¡un Fulgor de tinta!",
 " 짙은 먹에 물들어 있다. 먹빛 광채형이다!",
 " 它浸染着浓墨：墨染光泽形态！",
 " 牠浸染著濃墨：墨染輝光！",
 " Está banhado em tinta profunda: um Reluzente de tinta!",
 " Оно окрашено густыми чернилами: Чернильное сияние!",
 " Jest skąpany w głębokim atramencie: atramentowy połysk!",
 " Koyu mürekkebe bulanmış: bir Mürekkep Işıltısı!",
 " Het is gedrenkt in diepe inkt: een Inktglansvorm!"],
" It glows like the last of the sun: a Duskgold Gleam!": [
 " 沈む夕日のように輝いている。夕金の輝きだ！",
 " Il luit comme les derniers rayons du soleil : un Reflet d'or du soir !",
 " Brilla come l'ultimo sole: uno Splendore d'oro al tramonto!",
 " Resplandece como el último sol: ¡un Fulgor de oro crepuscular!",
 " 저무는 해처럼 빛난다. 노을금 광채형이다!",
 " 它像落日余晖般发光：暮金光泽形态！",
 " 牠像落日餘暉般發光：暮金輝光！",
 " Brilha como o último sol do dia: um Reluzente de ouro do ocaso!",
 " Оно светится, как последний луч солнца: Сияние закатного золота!",
 " Lśni jak ostatnie promienie słońca: połysk zmierzchowego złota!",
 " Batan güneş gibi parlıyor: bir Akşam Altını Işıltısı!",
 " Het gloeit als de laatste zon: een Avondgoud-glansvorm!"],
" Its colours never hold still: an Opaline Gleam!": [
 " 色がひとときも定まらない。乳白の輝きだ！",
 " Ses couleurs ne tiennent jamais en place : un Reflet opalin !",
 " I suoi colori non stanno mai fermi: uno Splendore opalino!",
 " Sus colores nunca se quedan quietos: ¡un Fulgor opalino!",
 " 색이 잠시도 가만있지 않는다. 오팔 광채형이다!",
 " 它的颜色从不停歇：蛋白石光泽形态！",
 " 牠的顏色從不停歇：蛋白石輝光！",
 " Suas cores nunca ficam paradas: um Reluzente opalino!",
 " Его цвета не стоят на месте: Опаловое сияние!",
 " Jego barwy nigdy nie stoją w miejscu: opalowy połysk!",
 " Renkleri hiç durmuyor: bir Opal Işıltısı!",
 " Zijn kleuren staan nooit stil: een Opaalglansvorm!"],
"%d seen, %d bonded": ["%d 回目撃、%d 回絆", "%d vus, %d liés", "%d visti, %d legati", "%d vistos, %d vinculados", "%d 목격, %d 유대", "已见 %d，已结缘 %d", "已見 %d，已結緣 %d", "%d vistos, %d vinculados", "увидено %d, связано %d", "widziane: %d, związane: %d", "%d görüldü, %d bağ kuruldu", "%d gezien, %d verbonden"],
"Gleams seen: %s": ["目撃した輝き: %s", "Reflets vus : %s", "Splendori visti: %s", "Fulgores vistos: %s", "목격한 광채형: %s", "已见光泽形态：%s", "已見輝光：%s", "Reluzentes vistos: %s", "Увиденные сияния: %s", "Widziane połyski: %s", "Görülen Işıltılar: %s", "Geziene glansvormen: %s"],
"Gleams bonded: %s": ["絆を結んだ輝き: %s", "Reflets liés : %s", "Splendori legati: %s", "Fulgores vinculados: %s", "유대를 맺은 광채형: %s", "已结缘光泽形态：%s", "已結緣輝光：%s", "Reluzentes vinculados: %s", "Связанные сияния: %s", "Związane połyski: %s", "Bağ kurulan Işıltılar: %s", "Verbonden glansvormen: %s"],
"Rarer Gleams show their own mark:": ["より珍しい輝きには専用の印がある:", "Les reflets plus rares ont leur propre marque :", "Gli Splendori più rari hanno un segno proprio:", "Los Fulgores más raros llevan su propia marca:", "더 희귀한 광채형은 고유한 표시가 있다:", "更稀有的光泽形态有自己的标记：", "更稀有的輝光有自己的標記：", "Reluzentes mais raros têm sua própria marca:", "У более редких сияний свой знак:", "Rzadsze połyski mają własny znak:", "Daha nadir Işıltıların kendi işareti vardır:", "Zeldzamere glansvormen hebben hun eigen teken:"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table gleam_kinds, written by tools/i18n/locales_gleam_kinds.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "gleam_kinds.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("gleam_kinds: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
