#!/usr/bin/env python3
"""Translations of the German table kampf_keepsake (tools/i18n/de_kampf_keepsake.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_keepsake.json. Run: python3 tools/i18n/locales_kampf_keepsake.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"%s takes up the %s. That was its whole turn.": ["%sは%sを身につけた。このターンはそれで終わり。", "%s prend %s. Son tour entier y passe.", "%s indossa %s. Ci va tutto il suo turno.", "%s se pone %s. Ahí se le va todo el turno.", "{0}은(는) {1}을(를) 지녔다. 이번 턴은 그걸로 끝이다.", "%s带上了%s。这一回合就这么用掉了。", "%s帶上了%s。這一回合就這麼用掉了。", "%s pega %s. Lá se foi o turno inteiro.", "%s берёт %s. На это ушёл весь ход.", "%s zakłada %s. Cała tura poszła na to.", "{0}, {1} eşyasını takıyor. Bütün turu buna gitti.", "%s neemt %s op. Dat was zijn hele beurt."],
"%s drops its %s for the %s. That was its whole turn.": ["%sは%sを手放し、%sに持ち替えた。このターンはそれで終わり。", "%s lâche %s pour %s. Son tour entier y passe.", "%s molla %s per %s. Ci va tutto il suo turno.", "%s suelta %s por %s. Ahí se le va todo el turno.", "{0}은(는) {1}을(를) 버리고 {2}을(를) 지녔다. 이번 턴은 그걸로 끝이다.", "%s丢下%s，换上了%s。这一回合就这么用掉了。", "%s丟下%s，換上了%s。這一回合就這麼用掉了。", "%s larga %s por %s. Lá se foi o turno inteiro.", "%s бросает %s ради %s. На это ушёл весь ход.", "%s porzuca %s dla %s. Cała tura poszła na to.", "{0}, {1} eşyasını bırakıp {2} alıyor. Bütün turu buna gitti.", "%s laat %s vallen voor %s. Dat was zijn hele beurt."],
"Set %d: %s": ["セット%d: %s", "Set %d: %s", "Set %d: %s", "Set %d: %s", "세트 %d: %s", "套组%d：%s", "套組%d：%s", "Conjunto %d: %s", "Набор %d: %s", "Zestaw %d: %s", "Set %d: %s", "Set %d: %s"],
"empty": ["なし", "vide", "vuoto", "vacío", "비어 있음", "空", "空", "vazio", "пусто", "pusty", "boş", "leeg"],
"No %s left in the bag for %s.": ["{1}のための{0}がバッグに残っていない。", "Plus de %s dans le sac pour %s.", "Nessun %s rimasto nella borsa per %s.", "No queda %s en la bolsa para %s.", "{1}에게 줄 {0}이(가) 가방에 없다.", "包里没有留给{1}的{0}了。", "包裡沒有留給{1}的{0}了。", "Não sobrou %s na bolsa para %s.", "В сумке не осталось %s для %s.", "W torbie nie ma już %s dla %s.", "Çantada {1} için {0} kalmadı.", "Geen %s meer in de tas voor %s."],
"holds %s": ["%sを持っている", "tient %s", "tiene %s", "lleva %s", "%s 소지", "携带%s", "攜帶%s", "segura %s", "держит %s", "trzyma %s", "%s taşıyor", "draagt %s"],
"Keepsake: putting it on takes the whole turn.": ["形見: 身につけるとターンがまるごと終わる。", "Souvenir: le mettre prend tout le tour.", "Ricordo: indossarlo costa tutto il turno.", "Recuerdo: ponérselo cuesta todo el turno.", "기념품: 지니는 데 턴 전체가 든다.", "信物：带上它要用掉整个回合。", "信物：帶上它要用掉整個回合。", "Lembrança: colocá-la custa o turno inteiro.", "Памятка: надеть её стоит целого хода.", "Pamiątka: założenie jej kosztuje całą turę.", "Hatıra: takmak bütün turu alır.", "Aandenken: het omdoen kost de hele beurt."],
"Keepsake sets": ["形見セット", "Ensembles de souvenirs", "Set di ricordi", "Conjuntos de recuerdos", "기념품 세트", "信物套组", "信物套組", "Conjuntos de lembranças", "Наборы памяток", "Zestawy pamiątek", "Hatıra setleri", "Aandenkensets"],
"Save what it holds, or put a saved set back on.": ["今持っているものを保存するか、保存したセットを身につける。", "Enregistre ce qu'il tient, ou remets un ensemble enregistré.", "Salva ciò che tiene, o rimetti un set salvato.", "Guarda lo que lleva o vuelve a ponerle un conjunto guardado.", "지금 지닌 것을 저장하거나, 저장한 세트를 다시 지니게 한다.", "保存它现在携带的东西，或换回已保存的套组。", "保存它現在攜帶的東西，或換回已保存的套組。", "Salve o que ele segura ou coloque de volta um conjunto salvo.", "Сохрани то, что он держит, или надень сохранённый набор.", "Zapisz, co trzyma, albo załóż zapisany zestaw.", "Taşıdığını kaydet ya da kayıtlı bir seti yeniden tak.", "Bewaar wat het draagt, of doe een bewaarde set weer om."],
"Keepsake sets of %s": ["%sの形見セット", "Ensembles de souvenirs de %s", "Set di ricordi di %s", "Conjuntos de recuerdos de %s", "%s의 기념품 세트", "%s的信物套组", "%s的信物套組", "Conjuntos de lembranças de %s", "Наборы памяток: %s", "Zestawy pamiątek: %s", "%s hatıra setleri", "Aandenkensets van %s"],
"Save what it holds now": ["今の持ち物を保存", "Enregistrer ce qu'il tient", "Salva ciò che tiene ora", "Guardar lo que lleva ahora", "지금 지닌 것 저장", "保存现在携带的", "保存現在攜帶的", "Salvar o que segura agora", "Сохранить то, что держит", "Zapisz, co trzyma teraz", "Şu an taşıdığını kaydet", "Bewaar wat het nu draagt"],
"Put this set on": ["このセットを身につける", "Mettre cet ensemble", "Indossa questo set", "Ponerse este conjunto", "이 세트 지니기", "换上这个套组", "換上這個套組", "Colocar este conjunto", "Надеть этот набор", "Załóż ten zestaw", "Bu seti tak", "Deze set omdoen"],
"Whole team: put on set %d": ["チーム全員: セット%dを身につける", "Toute l'équipe: mettre l'ensemble %d", "Tutta la squadra: indossa il set %d", "Todo el equipo: ponerse el conjunto %d", "팀 전체: 세트 %d 지니기", "全队：换上套组%d", "全隊：換上套組%d", "Equipe inteira: colocar o conjunto %d", "Вся команда: надеть набор %d", "Cała drużyna: załóż zestaw %d", "Bütün takım: set %d tak", "Hele team: set %d omdoen"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_keepsake, written by tools/i18n/locales_kampf_keepsake.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_keepsake.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_keepsake: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
