#!/usr/bin/env python3
"""Translations of the German table daily (tools/i18n/de_daily.py) for the other 12 locales.
Writes data/i18n/<code>/daily.json. Run: python3 tools/i18n/locales_daily.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Welcome gift, day %d of 7: %s": ["ようこそのおくりもの 7日中%d日目: %s", "Cadeau de bienvenue, jour %d sur 7 : %s", "Dono di benvenuto, giorno %d di 7: %s", "Regalo de bienvenida, día %d de 7: %s", "환영 선물, 7일 중 %d일째: %s", "欢迎礼物，第%d天/共7天：%s", "歡迎禮物，第%d天/共7天：%s", "Presente de boas-vindas, dia %d de 7: %s", "Подарок дня, день %d из 7: %s", "Prezent powitalny, dzień %d z 7: %s", "Hoş geldin hediyesi, 7 günün %d. günü: %s", "Welkomstcadeau, dag %d van 7: %s"],
"Take the gift": ["うけとる", "Prendre le cadeau", "Prendi il dono", "Tomar el regalo", "선물 받기", "收下礼物", "收下禮物", "Pegar o presente", "Забрать подарок", "Weź prezent", "Hediyeyi al", "Cadeau pakken"],
"Spirling of the day: %s": ["きょうのスピリング: %s", "Spirling du jour : %s", "Spirling del giorno: %s", "Spirling del día: %s", "오늘의 스피를링: %s", "今日的灵宠：%s", "今日的靈寵：%s", "Spirling do dia: %s", "Спирлинг дня: %s", "Spirling dnia: %s", "Günün Spirling'i: %s", "Spirling van de dag: %s"],
"Spirling of the day: %s. It steps out more often today in %s.": ["きょうのスピリング: %s。きょうは %s でよく出てくる。", "Spirling du jour : %s. Il se montre plus souvent aujourd'hui à %s.", "Spirling del giorno: %s. Oggi si mostra più spesso a %s.", "Spirling del día: %s. Hoy aparece más a menudo en %s.", "오늘의 스피를링: %s. 오늘은 %s에서 더 자주 나타난다.", "今日的灵宠：%s。今天在%s更常出现。", "今日的靈寵：%s。今天在%s更常出現。", "Spirling do dia: %s. Hoje aparece mais vezes em %s.", "Спирлинг дня: %s. Сегодня он чаще встречается в %s.", "Spirling dnia: %s. Dziś częściej pojawia się w %s.", "Günün Spirling'i: %s. Bugün %s yöresinde daha sık çıkıyor.", "Spirling van de dag: %s. Vandaag duikt hij vaker op in %s."],
"Weekend weather: %s over %s. Shy Spirlings step out more often there.": ["しゅうまつの天気: %s が %s に。そこではめずらしいスピリングがよく出てくる。", "Météo du week-end : %s sur %s. Les Spirlings timides s'y montrent plus souvent.", "Meteo del weekend: %s su %s. Lì gli Spirling timidi si mostrano più spesso.", "Clima de fin de semana: %s sobre %s. Allí los Spirlings tímidos aparecen más a menudo.", "주말 날씨: %s, %s 위에. 그곳에서는 수줍은 스피를링이 더 자주 나타난다.", "周末天气：%s笼罩%s。害羞的灵宠在那里更常出现。", "週末天氣：%s籠罩%s。害羞的靈寵在那裡更常出現。", "Clima do fim de semana: %s sobre %s. Spirlings tímidos aparecem mais lá.", "Погода выходных: %s над %s. Робкие Спирлинги встречаются там чаще.", "Pogoda weekendu: %s nad %s. Płochliwe Spirlingi pojawiają się tam częściej.", "Hafta sonu havası: %s, %s üzerinde. Çekingen Spirling'ler orada daha sık çıkıyor.", "Weekendweer: %s boven %s. Schuwe Spirlings duiken daar vaker op."],
"This weekend: %s over %s.": ["こんどのしゅうまつ: %s が %s に。", "Ce week-end : %s sur %s.", "Questo weekend: %s su %s.", "Este fin de semana: %s sobre %s.", "이번 주말: %s, %s 위에.", "本周末：%s笼罩%s。", "本週末：%s籠罩%s。", "Neste fim de semana: %s sobre %s.", "В эти выходные: %s над %s.", "W ten weekend: %s nad %s.", "Bu hafta sonu: %s, %s üzerinde.", "Dit weekend: %s boven %s."],
"Silver fog": ["ぎんのきり", "Brume d'argent", "Nebbia d'argento", "Niebla plateada", "은빛 안개", "银雾", "銀霧", "Névoa prateada", "Серебряный туман", "Srebrna mgła", "Gümüş sis", "Zilvermist"],
"Glimmer rain": ["きらめきの雨", "Pluie scintillante", "Pioggia scintillante", "Lluvia centelleante", "반짝이 비", "微光雨", "微光雨", "Chuva cintilante", "Мерцающий дождь", "Migotliwy deszcz", "Işıltı yağmuru", "Glinsterregen"],
"Cloud gale": ["くものかぜ", "Rafale des nuées", "Raffica di nubi", "Ventolera de nubes", "구름 돌풍", "云之疾风", "雲之疾風", "Rajada das nuvens", "Облачный шквал", "Chmurna wichura", "Bulut fırtınası", "Wolkenstorm"],
"Glass gale": ["ガラスのかぜ", "Vent de verre", "Vento di vetro", "Viento de cristal", "유리 바람", "琉璃风", "琉璃風", "Vento de vidro", "Стеклянный ветер", "Szklany wiatr", "Cam rüzgârı", "Glaswind"],
"Rime storm": ["しものあらし", "Orage de givre", "Tempesta di brina", "Tormenta de escarcha", "서리 폭풍", "霜之雷暴", "霜之雷暴", "Tempestade de geada", "Изморозная гроза", "Szronowa burza", "Kırağı fırtınası", "Rijpstorm"],
"Ember storm": ["ほのおのあらし", "Orage de braises", "Tempesta di braci", "Tormenta de brasas", "불씨 폭풍", "余烬雷暴", "餘燼雷暴", "Tempestade de brasas", "Угольная гроза", "Żarowa burza", "Kor fırtınası", "Gloedstorm"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table daily, written by tools/i18n/locales_daily.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "daily.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("daily: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
