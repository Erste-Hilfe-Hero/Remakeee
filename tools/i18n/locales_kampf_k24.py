#!/usr/bin/env python3
"""Translations of the German table kampf_k24 (tools/i18n/de_kampf_k24.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k24.json. Run: python3 tools/i18n/locales_kampf_k24.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Sunk Cost": ["もったいない", "Coût Perdu", "Costo Affondato", "Costo Hundido", "매몰 비용", "沉没成本", "沉沒成本", "Custo Afundado", "Невозвратные траты", "Utracony Koszt", "Batık Maliyet", "Verzonken Kosten"],
"It has paid too much to stop now. Every Energy it spent on arts this battle makes it hit harder.": [
 "もう引き返すには払いすぎた。この戦いでわざに使ったエネルギーの分だけ強く当たる。",
 "Il a trop payé pour s'arrêter maintenant. Chaque Énergie dépensée en techniques dans ce combat le fait frapper plus fort.",
 "Ha pagato troppo per fermarsi ora. Ogni Energia spesa in tecniche in questa lotta lo fa colpire più forte.",
 "Ha pagado demasiado para parar ahora. Cada Energía gastada en técnicas en este combate hace que golpee más fuerte.",
 "이제 멈추기엔 너무 많이 치렀다. 이번 전투에서 기술에 쓴 에너지만큼 더 세게 때린다.",
 "已经付出太多，停不下来了。本场战斗中每在招式上花费一点能量，命中就更重一分。",
 "已經付出太多，停不下來了。本場戰鬥中每在招式上花費一點能量，命中就更重一分。",
 "Já pagou demais para parar agora. Cada Energia gasta em técnicas nesta batalha faz o golpe ficar mais forte.",
 "Слишком много заплачено, чтобы остановиться. Каждая единица энергии, потраченная на приёмы в этом бою, делает удар сильнее.",
 "Zapłacił za dużo, by teraz przestać. Każda Energia wydana na techniki w tej walce sprawia, że trafia mocniej.",
 "Durmak için çok fazla ödedi. Bu savaşta tekniklere harcadığı her Enerji darbesini sertleştirir.",
 "Het heeft te veel betaald om nu te stoppen. Elke Energie die het deze strijd aan technieken uitgaf, laat het harder raken."],
"+%d%% power for each Energy spent on arts this battle, up to %d.": [
 "この戦いでわざに使ったエネルギー1につき威力+%d%%（最大%d）。",
 "+%d%% de puissance par Énergie dépensée en techniques dans ce combat, jusqu'à %d.",
 "+%d%% di potenza per ogni Energia spesa in tecniche in questa lotta, fino a %d.",
 "+%d%% de potencia por cada Energía gastada en técnicas en este combate, hasta %d.",
 "이번 전투에서 기술에 쓴 에너지 1마다 위력 +%d%% (최대 %d).",
 "本场战斗中每在招式上花费1点能量，威力+%d%%，最多%d点。",
 "本場戰鬥中每在招式上花費1點能量，威力+%d%%，最多%d點。",
 "+%d%% de poder por Energia gasta em técnicas nesta batalha, até %d.",
 "+%d%% силы за каждую единицу энергии, потраченную на приёмы в этом бою, до %d.",
 "+%d%% mocy za każdą Energię wydaną na techniki w tej walce, do %d.",
 "Bu savaşta tekniklere harcanan her Enerji için +%d%% güç, en fazla %d.",
 "+%d%% kracht voor elke Energie die deze strijd aan technieken is uitgegeven, tot %d."],
"%s kinds hold %d more Energy (%d in all).": [
 "%sタイプはエネルギーを%d多くためられる（合計%d）。",
 "Les espèces %s stockent %d Énergie de plus (%d en tout).",
 "Le specie %s accumulano %d Energia in più (%d in tutto).",
 "Las especies %s guardan %d de Energía más (%d en total).",
 "%s 종류는 에너지를 %d 더 담는다 (합계 %d).",
 "%s类种族多储存%d点能量（共%d点）。",
 "%s類種族多儲存%d點能量（共%d點）。",
 "Espécies %s guardam %d de Energia a mais (%d no total).",
 "Виды типа %s вмещают на %d энергии больше (всего %d).",
 "Gatunki typu %s mieszczą %d Energii więcej (razem %d).",
 "%s türleri %d Enerji fazla tutar (toplam %d).",
 "%s-soorten houden %d Energie meer vast (%d in totaal)."],
"A Spirling that has fought gains %d Energy each turn while it waits on the bench.": [
 "一度戦ったSpirlingは、ベンチで待つあいだ毎ターン%dエネルギーを得る。",
 "Un Spirling qui a déjà combattu gagne %d Énergie par tour tant qu'il attend sur le banc.",
 "Uno Spirling che ha già combattuto ottiene %d Energia a turno mentre aspetta in panchina.",
 "Un Spirling que ya ha luchado gana %d de Energía por turno mientras espera en el banquillo.",
 "한 번 싸운 Spirling은 벤치에서 기다리는 동안 매 턴 에너지를 %d 얻는다.",
 "已经出战过的Spirling在替补席等待时，每回合获得%d点能量。",
 "已經出戰過的Spirling在替補席等待時，每回合獲得%d點能量。",
 "Um Spirling que já lutou ganha %d de Energia por turno enquanto espera no banco.",
 "Spirling, который уже сражался, получает %d энергии за ход, пока ждёт на скамейке.",
 "Spirling, który już walczył, zyskuje %d Energii na turę, czekając na ławce.",
 "Savaşmış bir Spirling yedek sırasında beklerken her tur %d Enerji kazanır.",
 "Een Spirling die al gevochten heeft, krijgt elke beurt %d Energie zolang hij op de bank wacht."],
"The water seeps into %s: it loses %d Energy!": [
 "水が%sにしみこむ。エネルギーを%d失った！",
 "L'eau s'infiltre dans %s: il perd %d Énergie!",
 "L'acqua penetra in %s: perde %d Energia!",
 "¡El agua cala a %s: pierde %d de Energía!",
 "물이 %s에게 스며든다. 에너지를 %d 잃었다!",
 "水渗进了%s：它失去了%d点能量！",
 "水滲進了%s：它失去了%d點能量！",
 "A água se infiltra em %s: perde %d de Energia!",
 "Вода пропитывает %s: теряет %d энергии!",
 "Woda wsiąka w %s: traci %d Energii!",
 "Su %s içine işliyor: %d Enerji kaybediyor!",
 "Het water trekt in %s: het verliest %d Energie!"],
"Damp Sparks": ["しめった火花", "Étincelles Humides", "Scintille Umide", "Chispas Húmedas", "젖은 불꽃", "潮湿火花", "潮濕火花", "Faíscas Úmidas", "Сырые искры", "Wilgotne Iskry", "Nemli Kıvılcımlar", "Natte Vonken"],
"A Soaked Spirling loses 2 Energy at the end of each turn.": [
 "ずぶぬれのSpirlingは毎ターンの終わりにエネルギーを2失う。",
 "Un Spirling trempé perd 2 Énergie à la fin de chaque tour.",
 "Uno Spirling fradicio perde 2 Energia alla fine di ogni turno.",
 "Un Spirling empapado pierde 2 de Energía al final de cada turno.",
 "흠뻑 젖은 Spirling은 매 턴이 끝날 때 에너지를 2 잃는다.",
 "湿透的Spirling在每回合结束时失去2点能量。",
 "濕透的Spirling在每回合結束時失去2點能量。",
 "Um Spirling encharcado perde 2 de Energia no fim de cada turno.",
 "Промокший Spirling теряет 2 энергии в конце каждого хода.",
 "Przemoczony Spirling traci 2 Energii na koniec każdej tury.",
 "Islanmış bir Spirling her turun sonunda 2 Enerji kaybeder.",
 "Een doorweekte Spirling verliest aan het eind van elke beurt 2 Energie."],
"Tip: Your Spirling is running low on Energy. An art it can't pay won't go off.": [
 "ヒント：Spirlingのエネルギーが少なくなってきた。払えないわざは出せない。",
 "Astuce: ton Spirling manque d'Énergie. Une technique qu'il ne peut pas payer ne part pas.",
 "Consiglio: il tuo Spirling è a corto di Energia. Una tecnica che non può pagare non parte.",
 "Consejo: a tu Spirling le queda poca Energía. Una técnica que no puede pagar no sale.",
 "팁: Spirling의 에너지가 떨어져 간다. 치를 수 없는 기술은 나가지 않는다.",
 "提示：你的Spirling能量快不够了。付不起的招式放不出来。",
 "提示：你的Spirling能量快不夠了。付不起的招式放不出來。",
 "Dica: seu Spirling está ficando sem Energia. Uma técnica que ele não pode pagar não sai.",
 "Совет: у твоего Spirling кончается энергия. Приём, за который нечем заплатить, не сработает.",
 "Wskazówka: twojemu Spirlingowi kończy się Energia. Technika, za którą nie zapłaci, nie wyjdzie.",
 "İpucu: Spirling'inin Enerjisi azalıyor. Ödeyemediği bir teknik çıkmaz.",
 "Tip: je Spirling raakt door zijn Energie heen. Een techniek die hij niet kan betalen, gaat niet af."],
"Pick Rest: it skips its art but gains 2 Energy on top of the turn's 1. The foe will not wait politely.": [
 "「休む」を選ぼう。わざは出さないが、ターンの1に加えてエネルギーを2得る。相手は礼儀正しく待ってはくれない。",
 "Choisis Repos: il saute sa technique mais gagne 2 Énergie en plus du 1 du tour. L'adversaire n'attendra pas poliment.",
 "Scegli Riposo: salta la tecnica ma ottiene 2 Energia oltre all'1 del turno. L'avversario non aspetterà educatamente.",
 "Elige Descansar: se salta la técnica pero gana 2 de Energía además del 1 del turno. El rival no esperará con educación.",
 "쉬기를 고르자. 기술은 건너뛰지만 턴의 1에 더해 에너지를 2 얻는다. 상대는 예의 바르게 기다려 주지 않는다.",
 "选择休息：它会跳过招式，但在回合的1点之外再得2点能量。对手可不会礼貌地等着。",
 "選擇休息：它會跳過招式，但在回合的1點之外再得2點能量。對手可不會禮貌地等著。",
 "Escolha Descansar: ele pula a técnica, mas ganha 2 de Energia além do 1 do turno. O inimigo não vai esperar educadamente.",
 "Выбери Отдых: приём пропускается, но к 1 за ход добавляется ещё 2 энергии. Враг вежливо ждать не станет.",
 "Wybierz Odpoczynek: pomija technikę, ale zyskuje 2 Energii oprócz 1 z tury. Wróg nie będzie grzecznie czekał.",
 "Dinlen'i seç: tekniği atlar ama turun 1'ine ek 2 Enerji kazanır. Rakip kibarca beklemeyecek.",
 "Kies Rusten: hij slaat zijn techniek over maar krijgt 2 Energie bovenop de 1 van de beurt. De tegenstander wacht niet beleefd."],
"Tip: Watch the pips fill back up. Resting is how Energy comes home.": [
 "ヒント：目もりがまた埋まっていくのを見よう。休むことでエネルギーは帰ってくる。",
 "Astuce: regarde les points se remplir. C'est en se reposant que l'Énergie rentre à la maison.",
 "Consiglio: guarda le tacche riempirsi. Riposando l'Energia torna a casa.",
 "Consejo: mira cómo se vuelven a llenar los puntos. Descansando, la Energía vuelve a casa.",
 "팁: 칸이 다시 차오르는 걸 보자. 쉬어야 에너지가 돌아온다.",
 "提示：看着能量格重新填满。休息才能让能量回家。",
 "提示：看著能量格重新填滿。休息才能讓能量回家。",
 "Dica: veja os pontos se encherem de novo. É descansando que a Energia volta para casa.",
 "Совет: смотри, как точки снова заполняются. Отдых возвращает энергию домой.",
 "Wskazówka: patrz, jak kropki znów się zapełniają. Odpoczynek sprowadza Energię do domu.",
 "İpucu: noktaların yeniden dolmasını izle. Enerji dinlenerek eve döner.",
 "Tip: kijk hoe de puntjes weer vollopen. Door te rusten komt Energie thuis."],
"Low on Energy": ["エネルギー不足", "Peu d'Énergie", "Poca Energia", "Poca Energía", "에너지 부족", "能量不足", "能量不足", "Pouca Energia", "Мало энергии", "Mało Energii", "Az Enerji", "Weinig Energie"],
"Resting": ["休む", "Repos", "Riposo", "Descansar", "쉬기", "休息", "休息", "Descansar", "Отдых", "Odpoczynek", "Dinlenme", "Rusten"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k24, written by tools/i18n/locales_kampf_k24.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k24.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k24: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
