#!/usr/bin/env python3
"""Translations of the German table kampf_k28 (tools/i18n/de_kampf_k28.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k28.json. Run: python3 tools/i18n/locales_kampf_k28.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Its flame burns in any wind: fog, Daze and Muddle never spoil its aim.": [
    "その炎はどんな風でも消えない。霧もめまいも混乱も、ねらいをくるわせない。",
    "Sa flamme brûle par tous les vents: ni brouillard, ni Vertige, ni Confus ne gâchent sa visée.",
    "La sua fiamma arde con ogni vento: nebbia, Stordimento e Confuso non rovinano mai la sua mira.",
    "Su llama arde con cualquier viento: ni la niebla, ni el Aturdimiento ni Confuso estropean su puntería.",
    "그 불꽃은 어떤 바람에도 꺼지지 않는다. 안개도 멍함도 혼란도 조준을 흐트러뜨리지 못한다.",
    "它的火焰在任何风中都不会熄灭：雾、晕眩和混乱都无法打乱它的瞄准。",
    "它的火焰在任何風中都不會熄滅：霧、暈眩和混亂都無法打亂它的瞄準。",
    "Sua chama arde em qualquer vento: névoa, Tontura e Confuso nunca estragam sua mira.",
    "Его пламя горит при любом ветре: ни туман, ни Оглушение, ни Смятение не сбивают ему прицел.",
    "Jego płomień płonie na każdym wietrze: mgła, Oszołomienie i Zamęt nigdy nie psują mu celu.",
    "Alevi her rüzgârda yanar: sis, Sersemlik ve Şaşkın nişanını asla bozamaz.",
    "Zijn vlam brandt in elke wind: mist, Versuft en Verward bederven nooit zijn mikken."],
"Turncoat Seed": ["うらぎりのタネ", "Graine de Renégat", "Seme del Voltagabbana", "Semilla Traidora", "배신자의 씨앗", "倒戈种子", "倒戈種子",
    "Semente Vira-Casaca", "Семя перебежчика", "Nasiono Odstępcy", "Dönek Tohumu", "Overloperszaad"],
"Swaps one Spirling's gift for the hidden gift of its line, or back again, at any ring. Loyalty was never part of the deal. Used up.": [
    "Spirlingの天性を、その系統のかくれた天性と入れかえる。もどすこともできる。リングは問わない。忠誠は取引にふくまれていなかった。使うとなくなる。",
    "Échange le don d'un Spirling contre le don caché de sa lignée, ou l'inverse, à n'importe quel rang. La loyauté n'a jamais fait partie du marché. Consommé.",
    "Scambia il dono di uno Spirling con il dono nascosto della sua linea, o di nuovo indietro, a qualsiasi anello. La lealtà non è mai stata nei patti. Si consuma.",
    "Cambia el don de un Spirling por el don oculto de su linaje, o al revés, en cualquier anillo. La lealtad nunca entró en el trato. Se gasta.",
    "Spirling의 재능을 그 계통의 숨겨진 재능과 바꾸거나 다시 되돌린다. 링은 상관없다. 충성은 애초에 거래 조건이 아니었다. 사용하면 사라진다.",
    "把一只Spirling的天赋换成它这一系的隐藏天赋，或再换回来，任何环数皆可。忠诚从来不在交易之内。用后消失。",
    "把一隻Spirling的天賦換成它這一系的隱藏天賦，或再換回來，任何環數皆可。忠誠從來不在交易之內。用後消失。",
    "Troca o dom de um Spirling pelo dom oculto de sua linhagem, ou de volta, em qualquer anel. Lealdade nunca fez parte do acordo. Gasta-se.",
    "Меняет дар Spirling на скрытый дар его линии или обратно, на любом кольце. Верность в сделку не входила. Расходуется.",
    "Zamienia dar Spirlinga na ukryty dar jego linii albo z powrotem, na dowolnym pierścieniu. Lojalność nigdy nie była częścią umowy. Zużywa się.",
    "Bir Spirling'in armağanını soyunun gizli armağanıyla ya da tersiyle değiştirir, her halkada. Sadakat hiçbir zaman pazarlığın parçası değildi. Tükenir.",
    "Ruilt de gave van een Spirling voor de verborgen gave van zijn lijn, of weer terug, op elke ring. Trouw hoorde nooit bij de deal. Wordt opgebruikt."],
"%s turns its coat: its gift is now %s.": [
    "%sは寝返った。いまの天性は%s。",
    "%s retourne sa veste: son don est désormais %s.",
    "%s cambia bandiera: ora il suo dono è %s.",
    "%s cambia de chaqueta: ahora su don es %s.",
    "%s은(는) 편을 바꿨다. 이제 재능은 %s.",
    "%s倒戈了：它现在的天赋是%s。",
    "%s倒戈了：它現在的天賦是%s。",
    "%s vira a casaca: agora seu dom é %s.",
    "%s переметнулся: теперь его дар %s.",
    "%s zmienia front: teraz jego dar to %s.",
    "%s taraf değiştiriyor: armağanı artık %s.",
    "%s loopt over: zijn gave is nu %s."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k28, written by tools/i18n/locales_kampf_k28.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k28.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k28: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
