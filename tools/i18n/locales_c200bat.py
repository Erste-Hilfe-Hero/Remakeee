#!/usr/bin/env python3
"""Translations of the German table c200bat (tools/i18n/de_c200bat.py) for the other 12 locales.
Writes data/i18n/<code>/c200bat.json. Run: python3 tools/i18n/locales_c200bat.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Escape looks easy.": ["にげるのは かんたんそうだ。", "Fuir semble facile.", "Fuggire sembra facile.", "Huir parece fácil.", "도망치기 쉬워 보인다.", "逃跑看起来很容易。", "逃跑看起來很容易。", "Fugir parece fácil.", "Сбежать, похоже, легко.", "Ucieczka wygląda na łatwą.", "Kaçmak kolay görünüyor.", "Vluchten lijkt makkelijk."],
"Escape might work.": ["にげられるかもしれない。", "Fuir pourrait marcher.", "Fuggire potrebbe riuscire.", "Huir podría funcionar.", "도망칠 수 있을지도 모른다.", "也许能逃掉。", "也許能逃掉。", "Fugir pode dar certo.", "Сбежать, может, и выйдет.", "Ucieczka może się udać.", "Kaçmak işe yarayabilir.", "Vluchten zou kunnen lukken."],
"Escape looks hard.": ["にげるのは むずかしそうだ。", "Fuir semble difficile.", "Fuggire sembra difficile.", "Huir parece difícil.", "도망치기 어려워 보인다.", "逃跑看起来很难。", "逃跑看起來很難。", "Fugir parece difícil.", "Сбежать, похоже, трудно.", "Ucieczka wygląda na trudną.", "Kaçmak zor görünüyor.", "Vluchten lijkt moeilijk."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table c200bat, written by tools/i18n/locales_c200bat.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "c200bat.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("c200bat: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
