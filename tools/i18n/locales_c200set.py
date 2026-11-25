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
"Night mode: %s": ["ナイトモード: %s", "Mode nuit : %s", "Modalità notte: %s", "Modo noche: %s", "야간 모드: %s", "夜间模式：%s", "夜間模式：%s", "Modo noturno: %s", "Ночной режим: %s", "Tryb nocny: %s", "Gece modu: %s", "Nachtmodus: %s"],
"Dim": ["くらめ", "Sombre", "Scuro", "Oscuro", "어둡게", "调暗", "調暗", "Escuro", "Темнее", "Ciemny", "Loş", "Donker"],
"Warm": ["あたたか", "Chaud", "Caldo", "Cálido", "따뜻하게", "暖色", "暖色", "Quente", "Тёплый", "Ciepły", "Sıcak", "Warm"],
"Dims the whole screen for dark rooms. Warm also takes out the cold blue light.": ["くらい部屋のために画面全体をくらくする。あたたかは青い光もおさえる。", "Assombrit tout l'écran pour les pièces sombres. Chaud retire aussi la lumière bleue froide.", "Scurisce tutto lo schermo per le stanze buie. Caldo toglie anche la fredda luce blu.", "Oscurece toda la pantalla para habitaciones oscuras. Cálido también quita la fría luz azul.", "어두운 방을 위해 화면 전체를 어둡게 한다. 따뜻하게는 차가운 푸른빛도 줄인다.", "为昏暗的房间调暗整个屏幕。暖色还会去掉冷冷的蓝光。", "為昏暗的房間調暗整個螢幕。暖色還會去掉冷冷的藍光。", "Escurece a tela toda para quartos escuros. Quente também tira a luz azul fria.", "Затемняет весь экран для тёмной комнаты. Тёплый также убирает холодный синий свет.", "Przyciemnia cały ekran w ciemnych pokojach. Ciepły usuwa też zimne niebieskie światło.", "Karanlık odalar için tüm ekranı karartır. Sıcak, soğuk mavi ışığı da azaltır.", "Maakt het hele scherm donkerder voor donkere kamers. Warm haalt ook het koude blauwe licht weg."],
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
