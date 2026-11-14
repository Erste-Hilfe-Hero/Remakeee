#!/usr/bin/env python3
"""Translations of the German table kampf_k22 (tools/i18n/de_kampf_k22.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k22.json. Run: python3 tools/i18n/locales_kampf_k22.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"You caught %s from behind! Your side moves first.": ["%sの背後をとった！こちらが先に動く。", "Tu as surpris %s par-derrière! Ton camp agit en premier.", "Hai colto %s alle spalle! La tua squadra agisce per prima.", "¡Has pillado a %s por la espalda! Tu bando actúa primero.", "%s의 뒤를 잡았다! 우리 편이 먼저 움직인다.", "你从背后逮住了%s！你方先行动。", "你從背後逮住了%s！你方先行動。", "Você pegou %s pelas costas! Seu lado age primeiro.", "Ты застал %s со спины! Твоя сторона ходит первой.", "Zaszedłeś %s od tyłu! Twoja strona rusza pierwsza.", "%s adlı rakibi arkadan yakaladın! Senin tarafın önce davranıyor.", "Je verraste %s van achteren! Jouw kant is eerst aan zet."],
"A swarm of %d!": ["%d体の群れ！", "Un essaim de %d!", "Uno sciame di %d!", "¡Un enjambre de %d!", "%d마리의 무리!", "%d只的群体！", "%d隻的群體！", "Um enxame de %d!", "Рой из %d!", "Rój %d!", "%d kişilik bir sürü!", "Een zwerm van %d!"],
"A hushed %s!": ["静寂の%s！", "Un %s muet!", "Un %s ammutolito!", "¡Un %s silenciado!", "고요한 %s!", "沉寂的%s！", "沉寂的%s！", "Um %s silenciado!", "Безмолвный %s!", "Uciszony %s!", "Susmuş bir %s!", "Een verstomde %s!"],
"%s rises!": ["%sが現れた！", "%s surgit!", "%s si erge!", "¡%s se alza!", "%s이(가) 솟아올랐다!", "%s现身了！", "%s現身了！", "%s se ergue!", "%s поднимается!", "%s powstaje!", "%s yükseliyor!", "%s rijst op!"],
"Duel with %s!": ["%sと勝負！", "Duel contre %s!", "Duello con %s!", "¡Duelo con %s!", "%s와(과) 대결!", "与%s对决！", "與%s對決！", "Duelo com %s!", "Дуэль с %s!", "Pojedynek z %s!", "%s ile düello!", "Duel met %s!"],
"Everything goes dark... and then, somehow, it doesn't. Your team stirs right where it fell, bruised but breathing.": ["すべてが暗くなる…はずが、なぜかそうならない。チームは倒れたその場で、傷だらけでも息をして目を覚ます。", "Tout devient noir... puis, allez savoir comment, non. Ton équipe remue là où elle est tombée, meurtrie mais vivante.", "Tutto si fa buio... e poi, chissà come, no. La tua squadra si rialza proprio dove è caduta, ammaccata ma ancora viva.", "Todo se vuelve negro... y luego, quién sabe cómo, no. Tu equipo se mueve justo donde cayó, magullado pero respirando.", "모든 것이 어두워진다... 그런데 어째선지 그렇지 않다. 팀은 쓰러진 그 자리에서 멍든 채 숨을 쉬며 깨어난다.", "一切都黑了下来……然后不知怎的，又没有。你的队伍在倒下的地方动了动，伤痕累累，但还在呼吸。", "一切都黑了下來……然後不知怎的，又沒有。你的隊伍在倒下的地方動了動，傷痕累累，但還在呼吸。", "Tudo escurece... e então, de algum jeito, não. Sua equipe se mexe bem onde caiu, machucada, mas respirando.", "Всё темнеет... а потом почему-то нет. Твоя команда шевелится там же, где упала, побитая, но живая.", "Wszystko ciemnieje... a potem jakoś jednak nie. Twoja drużyna porusza się tam, gdzie padła, poobijana, ale oddycha.", "Her şey kararıyor... sonra nedense kararmıyor. Takımın düştüğü yerde kıpırdıyor, hırpalanmış ama nefes alıyor.", "Alles wordt zwart... en dan, op de een of andere manier, toch niet. Je team komt bij waar het viel, gehavend maar ademend."],
"Story only: after a lost battle your team wakes where it fell, with half its Vigor.": ["物語のみ：負けたあと、チームは倒れた場所で活力が半分の状態で目を覚ます。", "Récit uniquement: après une défaite, ton équipe se réveille là où elle est tombée, avec la moitié de sa Vigueur.", "Solo Storia: dopo una sconfitta la tua squadra si risveglia dove è caduta, con metà del Vigore.", "Solo Historia: tras perder un combate, tu equipo despierta donde cayó, con la mitad de su Vigor.", "이야기 전용: 전투에 지면 팀이 쓰러진 자리에서 기력 절반으로 깨어난다.", "仅限故事难度：战斗失败后，你的队伍会在倒下的地方醒来，元气剩一半。", "僅限故事難度：戰鬥失敗後，你的隊伍會在倒下的地方醒來，元氣剩一半。", "Só na História: depois de perder uma batalha, sua equipe acorda onde caiu, com metade do Vigor.", "Только Сюжет: после поражения команда приходит в себя там, где упала, с половиной Бодрости.", "Tylko Opowieść: po przegranej walce drużyna budzi się tam, gdzie padła, z połową Wigoru.", "Yalnızca Hikâye: kaybedilen bir savaştan sonra takımın düştüğü yerde, Dinçliğinin yarısıyla uyanır.", "Alleen Verhaal: na een verloren gevecht wordt je team wakker waar het viel, met de helft van zijn Kracht."],
"Soft Defeat: %s": ["やさしい敗北：%s", "Défaite douce: %s", "Sconfitta lieve: %s", "Derrota suave: %s", "부드러운 패배: %s", "温和战败：%s", "溫和戰敗：%s", "Derrota suave: %s", "Мягкое поражение: %s", "Łagodna porażka: %s", "Yumuşak yenilgi: %s", "Zachte nederlaag: %s"],
"Battle paused": ["バトル一時停止", "Combat en pause", "Battaglia in pausa", "Combate en pausa", "전투 일시정지", "战斗已暂停", "戰鬥已暫停", "Batalha pausada", "Бой на паузе", "Walka wstrzymana", "Savaş duraklatıldı", "Gevecht gepauzeerd"],
"Resume": ["再開", "Reprendre", "Riprendi", "Reanudar", "계속하기", "继续", "繼續", "Retomar", "Продолжить", "Wznów", "Devam et", "Hervatten"],
"%d still to come": ["あと%d体", "encore %d à venir", "ne arrivano ancora %d", "faltan %d", "%d마리 남음", "还有%d只", "還有%d隻", "faltam %d", "ещё %d впереди", "jeszcze %d", "%d tane daha geliyor", "nog %d te gaan"],
}

for i, code in enumerate(LANGS):
    data = {"_comment": "%s translation of the kampf_k22 table, keyed by the English text." % code,
            "strings": {k: v[i] for k, v in sorted(R.items())}}
    path = os.path.join(ROOT, "data/i18n", code, "kampf_k22.json")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
print("kampf_k22: %d strings x %d locales" % (len(R), len(LANGS)))
