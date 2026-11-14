#!/usr/bin/env python3
"""Translations of the German table kampf_k32 (tools/i18n/de_kampf_k32.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k32.json. Run: python3 tools/i18n/locales_kampf_k32.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"It acts once each turn.": ["1ターンに1回行動する。", "Il agit une fois par tour.", "Agisce una volta per turno.", "Actúa una vez por turno.", "한 턴에 한 번 행동한다.", "每回合行动一次。", "每回合行動一次。", "Age uma vez por turno.", "Действует один раз за ход.", "Działa raz na turę.", "Her turda bir kez hareket eder.", "Het handelt één keer per beurt."],
"%s has lost half its strength to your friends, and it remembers every face. It strikes harder!": [
    "%sは仲間たちに力の半分を奪われた。その顔をひとつ残らず覚えている。攻撃が激しくなった！",
    "%s a perdu la moitié de sa force face à tes amis, et il se souvient de chaque visage. Il frappe plus fort!",
    "%s ha perso metà della sua forza contro i tuoi amici, e ricorda ogni volto. Colpisce più forte!",
    "%s ha perdido la mitad de su fuerza contra tus amigos, y recuerda cada cara. ¡Golpea más fuerte!",
    "%s은(는) 친구들에게 힘의 절반을 잃었고, 그 얼굴을 하나도 빠짐없이 기억한다. 더 세게 공격한다!",
    "%s的力量已被你的朋友们削去一半，它记住了每一张脸。它的攻击更猛了！",
    "%s的力量已被你的朋友們削去一半，它記住了每一張臉。它的攻擊更猛了！",
    "%s perdeu metade da força para os seus amigos, e lembra de cada rosto. Ataca com mais força!",
    "%s потерял половину сил в боях с твоими друзьями и запомнил каждое лицо. Он бьёт сильнее!",
    "%s stracił połowę sił w starciach z twoimi przyjaciółmi i pamięta każdą twarz. Uderza mocniej!",
    "%s gücünün yarısını arkadaşlarına kaptırdı ve her yüzü hatırlıyor. Daha sert vuruyor!",
    "%s is de helft van zijn kracht kwijt aan je vrienden, en het onthoudt elk gezicht. Het slaat harder toe!"],
"%s is nearly broken. Cornered things are the dangerous ones: it moves faster and aims truer!": [
    "%sは今にも崩れそうだ。追いつめられたものほど危ない。動きが速く、狙いが正確になった！",
    "%s est presque brisé. Ce qui est acculé est le plus dangereux: il bouge plus vite et vise plus juste!",
    "%s è quasi spezzato. Ciò che è messo all'angolo è il più pericoloso: si muove più veloce e mira meglio!",
    "%s está casi roto. Lo acorralado es lo más peligroso: se mueve más rápido y apunta mejor!",
    "%s은(는) 거의 부서졌다. 궁지에 몰린 것이 가장 위험한 법. 더 빨라지고 더 정확하게 노린다!",
    "%s几乎崩溃了。被逼入绝境的东西最危险：它变得更快，瞄得更准！",
    "%s幾乎崩潰了。被逼入絕境的東西最危險：它變得更快，瞄得更準！",
    "%s está quase quebrado. O que está encurralado é o mais perigoso: fica mais rápido e mira melhor!",
    "%s почти сломлен. Загнанные в угол опаснее всего: он движется быстрее и целится точнее!",
    "%s jest prawie złamany. Przyparte do muru jest najgroźniejsze: porusza się szybciej i celuje celniej!",
    "%s neredeyse kırıldı. Köşeye sıkışan en tehlikelisidir: daha hızlı hareket ediyor ve daha isabetli nişan alıyor!",
    "%s is bijna gebroken. Wat in het nauw zit, is het gevaarlijkst: het beweegt sneller en mikt zuiverder!"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k32, written by tools/i18n/locales_kampf_k32.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k32.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k32: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
