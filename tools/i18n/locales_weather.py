#!/usr/bin/env python3
"""Translations of the German table weather (tools/i18n/de_weather.py) for the other 12 locales.
Writes data/i18n/<code>/weather.json. Run: python3 tools/i18n/locales_weather.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Drizzle": ["こさめ", "Bruine", "Pioggerella", "Llovizna", "이슬비", "毛毛雨", "毛毛雨", "Garoa", "Морось", "Mżawka", "Çisenti", "Motregen"],
"Downpour": ["どしゃぶり", "Averse", "Acquazzone", "Aguacero", "폭우", "倾盆大雨", "傾盆大雨", "Aguaceiro", "Ливень", "Ulewa", "Sağanak", "Stortbui"],
"Thick fog": ["こいきり", "Brouillard épais", "Nebbia fitta", "Niebla densa", "짙은 안개", "浓雾", "濃霧", "Neblina densa", "Густой туман", "Gęsta mgła", "Yoğun sis", "Dichte mist"],
"Gale": ["つよい風", "Vent fort", "Vento forte", "Vendaval", "강풍", "大风", "大風", "Ventania", "Сильный ветер", "Wichura", "Sert rüzgâr", "Harde wind"],
"Snow": ["ゆき", "Neige", "Neve", "Nieve", "눈", "雪", "雪", "Neve", "Снег", "Śnieg", "Kar", "Sneeuw"],
"Ash fall": ["はいのあめ", "Pluie de cendres", "Pioggia di cenere", "Lluvia de ceniza", "재비", "落灰", "落灰", "Chuva de cinzas", "Пеплопад", "Deszcz popiołu", "Kül yağışı", "Asregen"],
"Low": ["少なめ", "Faible", "Pochi", "Pocos", "적게", "少", "少", "Poucos", "Мало", "Mało", "Az", "Weinig"],
"Later: %s": ["このあと: %s", "Plus tard : %s", "Più tardi: %s", "Más tarde: %s", "나중: %s", "之后：%s", "之後：%s", "Mais tarde: %s", "Позже: %s", "Później: %s", "Sonra: %s", "Later: %s"],
"Weather effects: %s": ["天気えんしゅつ: %s", "Effets météo : %s", "Effetti meteo: %s", "Efectos clima: %s", "날씨 효과: %s", "天气效果：%s", "天氣效果：%s", "Efeitos clima: %s", "Эфф. погоды: %s", "Efekty pogody: %s", "Hava efektleri: %s", "Weereffecten: %s"],
"How much rain, snow and fog is drawn. Low is easier on old phones. Off: only the light changes.": ["雨や雪やきりをどれだけえがくか。少なめは古いスマホにやさしい。オフ: 光だけがかわる。", "Quantité de pluie, de neige et de brouillard affichée. Faible ménage les vieux téléphones. Non : seule la lumière change.", "Quanta pioggia, neve e nebbia viene disegnata. Pochi pesa meno sui vecchi telefoni. No: cambia solo la luce.", "Cuánta lluvia, nieve y niebla se dibuja. Pocos va mejor en móviles antiguos. No: solo cambia la luz.", "비와 눈, 안개를 얼마나 그릴지 정한다. 적게는 오래된 휴대폰에 부담이 적다. 끔: 빛만 바뀐다.", "绘制多少雨、雪和雾。少对旧手机更轻松。关：只有光线变化。", "繪製多少雨、雪和霧。少對舊手機更輕鬆。關：只有光線變化。", "Quanta chuva, neve e neblina é desenhada. Poucos pesa menos em celulares antigos. Não: só a luz muda.", "Сколько дождя, снега и тумана рисуется. Мало щадит старые телефоны. Выкл.: меняется только свет.", "Ile deszczu, śniegu i mgły jest rysowane. Mało oszczędza starsze telefony. Wył.: zmienia się tylko światło.", "Ne kadar yağmur, kar ve sis çizileceği. Az, eski telefonları yormaz. Kapalı: yalnızca ışık değişir.", "Hoeveel regen, sneeuw en mist er wordt getekend. Weinig is lichter voor oude telefoons. Uit: alleen het licht verandert."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table weather, written by tools/i18n/locales_weather.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "weather.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("weather: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
