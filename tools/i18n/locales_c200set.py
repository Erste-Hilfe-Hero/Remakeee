#!/usr/bin/env python3
"""Translations of the German table c200set (tools/i18n/de_c200set.py) for the other 12 locales.
Writes data/i18n/<code>/c200set.json. Run: python3 tools/i18n/locales_c200set.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Reset to default": ["もとにもどす", "Réinitialiser", "Ripristina", "Restablecer", "초기화", "恢复默认", "恢復預設", "Restaurar", "Сбросить", "Przywróć", "Sıfırla", "Herstellen"],
"Set every setting on this page back to how it was at the start?": ["このページの設定をすべて最初の状態にもどしますか？", "Remettre tous les réglages de cette page comme au début ?", "Riportare tutte le impostazioni di questa pagina come all'inizio?", "¿Devolver todos los ajustes de esta página a como estaban al principio?", "이 페이지의 설정을 모두 처음 상태로 되돌릴까요?", "要把本页的所有设置恢复到最初的样子吗？", "要把本頁的所有設定恢復到最初的樣子嗎？", "Voltar todas as configurações desta página para como eram no início?", "Вернуть все настройки на этой странице к начальным?", "Przywrócić wszystkie ustawienia na tej stronie do początkowych?", "Bu sayfadaki tüm ayarlar başlangıçtaki hâline dönsün mü?", "Alle instellingen op deze pagina terugzetten naar hoe ze in het begin waren?"],
"Sets every setting on this page back to how it was at the start.": ["このページの設定をすべて最初の状態にもどす。", "Remet tous les réglages de cette page comme au début.", "Riporta tutte le impostazioni di questa pagina come all'inizio.", "Devuelve todos los ajustes de esta página a como estaban al principio.", "이 페이지의 설정을 모두 처음 상태로 되돌린다.", "把本页的所有设置恢复到最初的样子。", "把本頁的所有設定恢復到最初的樣子。", "Volta todas as configurações desta página para como eram no início.", "Возвращает все настройки на этой странице к начальным.", "Przywraca wszystkie ustawienia na tej stronie do początkowych.", "Bu sayfadaki tüm ayarları başlangıçtaki hâline döndürür.", "Zet alle instellingen op deze pagina terug naar hoe ze in het begin waren."],
"Sets every setting on this page back to how it was at the start. The language stays.": ["このページの設定をすべて最初の状態にもどす。言語はそのまま。", "Remet tous les réglages de cette page comme au début. La langue reste.", "Riporta tutte le impostazioni di questa pagina come all'inizio. La lingua resta.", "Devuelve todos los ajustes de esta página a como estaban al principio. El idioma se queda.", "이 페이지의 설정을 모두 처음 상태로 되돌린다. 언어는 그대로.", "把本页的所有设置恢复到最初的样子。语言保持不变。", "把本頁的所有設定恢復到最初的樣子。語言保持不變。", "Volta todas as configurações desta página para como eram no início. O idioma fica.", "Возвращает все настройки на этой странице к начальным. Язык остаётся.", "Przywraca wszystkie ustawienia na tej stronie do początkowych. Język zostaje.", "Bu sayfadaki tüm ayarları başlangıçtaki hâline döndürür. Dil aynı kalır.", "Zet alle instellingen op deze pagina terug naar hoe ze in het begin waren. De taal blijft."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table c200set, written by tools/i18n/locales_c200set.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "c200set.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("c200set: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
