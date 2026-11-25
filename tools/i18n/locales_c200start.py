#!/usr/bin/env python3
"""Translations of the German table c200start (tools/i18n/de_c200start.py) for the other 12 locales.
Writes data/i18n/<code>/c200start.json. Run: python3 tools/i18n/locales_c200start.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Which one suits you?": ["どの子が合うかな?", "Lequel te correspond ?", "Chi fa per te?", "¿Cuál va contigo?", "누가 너와 맞을까?", "哪一只适合你？", "哪一隻適合你？", "Qual combina com você?", "Кто тебе подходит?", "Który do ciebie pasuje?", "Hangisi sana uygun?", "Wie past bij jou?"],
"Two short questions. You still choose freely.": ["みじかい質問が2つ。えらぶのはきみの自由。", "Deux petites questions. Tu choisis toujours librement.", "Due domande brevi. Scegli comunque liberamente.", "Dos preguntas cortas. Igual eliges con libertad.", "짧은 질문 두 개. 선택은 여전히 자유야.", "两个小问题。你依然可以自由选择。", "兩個小問題。你依然可以自由選擇。", "Duas perguntas curtas. Você ainda escolhe livremente.", "Два коротких вопроса. Выбираешь всё равно ты.", "Dwa krótkie pytania. I tak wybierasz swobodnie.", "İki kısa soru. Yine de özgürce seçersin.", "Twee korte vragen. Je kiest nog steeds vrij."],
"%s might suit you. But choose whoever you like!": ["%sが合うかも。でも好きな子をえらんでね!", "%s pourrait te correspondre. Mais choisis qui tu veux !", "%s potrebbe fare per te. Ma scegli chi vuoi!", "%s podría ir contigo. ¡Pero elige a quien quieras!", "%s(이)가 맞을지도 몰라. 하지만 마음에 드는 아이를 골라!", "%s可能适合你。不过选你喜欢的就好！", "%s可能適合你。不過選你喜歡的就好！", "%s pode combinar com você. Mas escolha quem quiser!", "Тебе может подойти %s. Но выбирай, кого хочешь!", "%s może do ciebie pasować. Ale wybierz, kogo chcesz!", "%s sana uygun olabilir. Ama istediğini seç!", "%s past misschien bij jou. Maar kies wie je wilt!"],
"A free afternoon. You...": ["ひまな午後。きみは...", "Un après-midi libre. Tu...", "Un pomeriggio libero. Tu...", "Una tarde libre. Tú...", "한가한 오후. 너는...", "空闲的下午。你会...", "空閒的下午。你會...", "Uma tarde livre. Você...", "Свободный день. Ты...", "Wolne popołudnie. Ty...", "Boş bir öğleden sonra. Sen...", "Een vrije middag. Jij..."],
"sit by a warm fire": ["あたたかい火のそばにすわる", "t'assois près d'un bon feu", "ti siedi vicino a un fuoco caldo", "te sientas junto a un fuego cálido", "따뜻한 불 옆에 앉는다", "坐在温暖的火堆旁", "坐在溫暖的火堆旁", "senta perto de uma fogueira quente", "сидишь у тёплого огня", "siedzisz przy ciepłym ogniu", "sıcak bir ateşin yanında oturursun", "zit bij een warm vuur"],
"race to the lake": ["湖まできょうそうする", "fais la course jusqu'au lac", "fai una gara fino al lago", "echas una carrera hasta el lago", "호수까지 달리기 시합을 한다", "比赛跑到湖边", "比賽跑到湖邊", "aposta corrida até o lago", "бежишь наперегонки к озеру", "ścigasz się do jeziora", "göle kadar yarışırsın", "rent om het hardst naar het meer"],
"explore a dark cave": ["くらいどうくつをたんけんする", "explores une grotte sombre", "esplori una grotta buia", "exploras una cueva oscura", "어두운 동굴을 탐험한다", "探索黑暗的洞穴", "探索黑暗的洞穴", "explora uma caverna escura", "исследуешь тёмную пещеру", "badasz ciemną jaskinię", "karanlık bir mağarayı keşfedersin", "verkent een donkere grot"],
"Your partner should be...": ["パートナーは...", "Ton partenaire devrait être...", "Il tuo compagno dovrebbe essere...", "Tu compañero debería ser...", "파트너는 이랬으면...", "你的伙伴应该...", "你的夥伴應該...", "Seu parceiro deve ser...", "Твой партнёр должен быть...", "Twój partner powinien być...", "Ortağın şöyle olmalı...", "Je partner moet zijn..."],
"loyal and warm": ["なかまおもいで、あたたかい", "fidèle et chaleureux", "leale e affettuoso", "leal y cariñoso", "의리 있고 따뜻하게", "忠诚又温暖", "忠誠又溫暖", "leal e carinhoso", "верным и тёплым", "wierny i ciepły", "sadık ve sıcak", "trouw en warm"],
"quick and lively": ["すばやくて、げんき", "rapide et plein d'entrain", "veloce e vivace", "rápido y animado", "재빠르고 활발하게", "敏捷又活泼", "敏捷又活潑", "rápido e animado", "быстрым и бойким", "szybki i żywy", "hızlı ve hareketli", "snel en levendig"],
"calm and bright": ["おちついていて、明るい", "calme et lumineux", "calmo e luminoso", "tranquilo y luminoso", "차분하고 밝게", "沉稳又明亮", "沉穩又明亮", "calmo e luminoso", "спокойным и светлым", "spokojny i jasny", "sakin ve parlak", "rustig en stralend"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table c200start, written by tools/i18n/locales_c200start.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "c200start.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("c200start: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
