#!/usr/bin/env python3
"""Translations of the German table c200team (tools/i18n/de_c200team.py) for the other 12 locales.
Writes data/i18n/<code>/c200team.json. Run: python3 tools/i18n/locales_c200team.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Era %s: %d%% seen, %d%% bonded": ["第%s時代: 見た %d%%、絆 %d%%", "Ère %s : %d %% vus, %d %% liés", "Era %s: %d%% visti, %d%% legati", "Era %s: %d%% vistos, %d%% vinculados", "%s시대: 목격 %d%%, 유대 %d%%", "纪元%s：已见%d%%，已结缘%d%%", "時代%s：已見%d%%，已結緣%d%%", "Era %s: %d%% vistos, %d%% vinculados", "Эпоха %s: видено %d%%, связано %d%%", "Era %s: %d%% widziane, %d%% związane", "Çağ %s: %%%d görülen, %%%d bağlanan", "Tijdperk %s: %d%% gezien, %d%% verbonden"],
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
