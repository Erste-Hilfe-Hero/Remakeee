#!/usr/bin/env python3
"""Translations of the German table c200team (tools/i18n/de_c200team.py) for the other 12 locales.
Writes data/i18n/<code>/c200team.json. Run: python3 tools/i18n/locales_c200team.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Era %s: %d%% seen, %d%% bonded": ["第%s時代: 見た %d%%、絆 %d%%", "Ère %s : %d %% vus, %d %% liés", "Era %s: %d%% visti, %d%% legati", "Era %s: %d%% vistos, %d%% vinculados", "%s시대: 목격 %d%%, 유대 %d%%", "纪元%s：已见%d%%，已结缘%d%%", "時代%s：已見%d%%，已結緣%d%%", "Era %s: %d%% vistos, %d%% vinculados", "Эпоха %s: видено %d%%, связано %d%%", "Era %s: %d%% widziane, %d%% związane", "Çağ %s: %%%d görülen, %%%d bağlanan", "Tijdperk %s: %d%% gezien, %d%% verbonden"],
"Event Spirling: %s": ["イベントのSpirling: %s", "Spirling d'événement : %s", "Spirling evento: %s", "Spirling de evento: %s", "이벤트 Spirling: %s", "活动Spirling：%s", "活動Spirling：%s", "Spirling de evento: %s", "Spirling события: %s", "Spirling z wydarzenia: %s", "Etkinlik Spirling'i: %s", "Evenement-Spirling: %s"],
"Lantern at the right: it joined you at an event, such as the Lamp Watch": ["右のランタン: 灯の番などのイベントで仲間になった", "Lanterne à droite : il t'a rejoint lors d'un événement, comme la Veille de la lampe", "Lanterna a destra: si è unito a te durante un evento, come la Veglia della lanterna", "Farol a la derecha: se unió a ti en un evento, como la Vigilia de la lámpara", "오른쪽의 랜턴: 등불 지킴 같은 이벤트에서 함께하게 되었다", "右侧的灯笼：它在守灯等活动中加入了你", "右側的燈籠：它在守燈等活動中加入了你", "Lanterna à direita: ele se juntou a você em um evento, como a Vigília da lâmpada", "Фонарь справа: он присоединился к тебе на событии, например на Дозоре у лампы", "Latarnia po prawej: dołączył do ciebie podczas wydarzenia, na przykład Straży lampy", "Sağdaki fener: Lamba Nöbeti gibi bir etkinlikte sana katıldı", "Lantaarn rechts: hij kwam bij je tijdens een evenement, zoals de Lampwacht"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table c200team, written by tools/i18n/locales_c200team.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "c200team.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("c200team: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
