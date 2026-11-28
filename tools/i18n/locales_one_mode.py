#!/usr/bin/env python3
"""Translations of the German table one_mode (tools/i18n/de_one_mode.py) for the other 12 locales.
Writes data/i18n/<code>/one_mode.json. Run: python3 tools/i18n/locales_one_mode.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Text, battles and tips.": ["文字、バトル、ヒント。", "Texte, combats et astuces.", "Testo, lotte e consigli.", "Texto, combates y consejos.", "텍스트, 전투, 팁.", "文字、战斗和提示。", "文字、戰鬥和提示。", "Texto, batalhas e dicas.", "Текст, бои и подсказки.", "Tekst, walki i porady.", "Metin, savaşlar ve ipuçları.", "Tekst, gevechten en tips."],
"Text speed and battle options.": ["文字の速さとバトルの設定。", "Vitesse du texte et options de combat.", "Velocità del testo e opzioni di lotta.", "Velocidad del texto y opciones de combate.", "텍스트 속도와 전투 옵션.", "文字速度和战斗选项。", "文字速度和戰鬥選項。", "Velocidade do texto e opções de batalha.", "Скорость текста и настройки боя.", "Szybkość tekstu i opcje walki.", "Metin hızı ve savaş seçenekleri.", "Tekstsnelheid en gevechtsopties."],
"Wayfarers' Spirlings stay close to your strongest one.": ["旅人のSpirlingは、きみのいちばん強いSpirlingに近い強さになる。", "Les Spirlings des Voyageurs restent proches de ton plus fort.", "Gli Spirling dei Viandanti restano vicini al tuo più forte.", "Los Spirlings de los Caminantes se quedan cerca de tu más fuerte.", "나그네의 Spirling은 너의 가장 강한 Spirling과 비슷하게 맞춰진다.", "旅人的Spirling会贴近你最强的那只。", "旅人的Spirling會貼近你最強的那隻。", "Os Spirlings dos Viajantes ficam perto do seu mais forte.", "Спирлинги Странников держатся близко к твоему сильнейшему.", "Spirlingi Wędrowców trzymają się blisko twojego najsilniejszego.", "Gezginlerin Spirling'leri en güçlü Spirling'ine yakın kalır.", "De Spirlings van Reizigers blijven dicht bij je sterkste."],
"Rift bosses": ["裂け目のボス", "Boss de Faille", "Boss dello Squarcio", "Jefes de Grieta", "균열 보스", "裂隙首领", "裂隙首領", "Chefes da Fenda", "Боссы Разлома", "Bossowie Szczelin", "Yarık bossları", "Kloofbazen"],
"Wayfarers think at tier %d, Wardens at tier %d.": ["旅人は段階%d、守り人は段階%dで考える。", "Les Voyageurs pensent au niveau %d, les Gardiens au niveau %d.", "I Viandanti pensano al livello %d, i Custodi al livello %d.", "Los Caminantes piensan en el nivel %d, los Custodios en el nivel %d.", "나그네는 %d단계, 수호자는 %d단계로 생각한다.", "旅人按第%d级思考，守望者按第%d级。", "旅人按第%d級思考，守境者按第%d級。", "Viajantes pensam no nível %d, Sentinelas no nível %d.", "Странники думают на уровне %d, Стражи на уровне %d.", "Wędrowcy myślą na poziomie %d, Strażnicy na poziomie %d.", "Gezginler %d. seviyede, Muhafızlar %d. seviyede düşünür.", "Reizigers denken op niveau %d, Hoeders op niveau %d."],
"Scorch, Root and Jolt stay on after the battle until an item, an art or a rest cures them.": [
 "焦げ、根づき、しびれはバトルのあとも残り、道具か術か休息で治るまで続く。",
 "Brûlure, Racines et Choc restent après le combat jusqu'à ce qu'un objet, une technique ou un repos les soigne.",
 "Arsura, Radici e Scossa restano dopo la lotta finché un oggetto, un'Arte o un riposo non le cura.",
 "Quemadura, Raíces y Calambre siguen tras el combate hasta que un objeto, un arte o un descanso los cura.",
 "화상, 뿌리 묶임, 찌릿은 전투 뒤에도 남아 도구, 기예, 휴식으로 나을 때까지 계속된다.",
 "灼烧、缠根和电麻在战斗后仍会保留，直到道具、技艺或休息将其治好。",
 "焦灼、纏根和觸電在戰鬥後仍會保留，直到道具、技藝或休息將其治好。",
 "Chamusco, Raízes e Choque continuam após a batalha até que um item, uma arte ou um descanso os cure.",
 "Ожог, Корни и Разряд остаются после боя, пока их не вылечит предмет, приём или отдых.",
 "Oparzenie, Ukorzenienie i Wstrząs zostają po walce, dopóki nie wyleczy ich przedmiot, technika lub odpoczynek.",
 "Yanık, Köklenme ve Şok savaştan sonra da sürer; bir eşya, bir hüner ya da dinlenme iyileştirene kadar.",
 "Brand, Wortels en Schok blijven na het gevecht tot een voorwerp, een techniek of een rust ze geneest."],
"%s with %s, %d:%02d": ["%s：%s、%d:%02d", "%s avec %s, %d:%02d", "%s con %s, %d:%02d", "%s con %s, %d:%02d", "%s와 %s, %d:%02d", "%s与%s，%d:%02d", "%s與%s，%d:%02d", "%s com %s, %d:%02d", "%s с %s, %d:%02d", "%s z %s, %d:%02d", "%s ile %s, %d:%02d", "%s met %s, %d:%02d"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table one_mode, written by tools/i18n/locales_one_mode.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "one_mode.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("one_mode: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
