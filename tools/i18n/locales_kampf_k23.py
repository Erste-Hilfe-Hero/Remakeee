#!/usr/bin/env python3
"""Translations of the German table kampf_k23 (tools/i18n/de_kampf_k23.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k23.json. Run: python3 tools/i18n/locales_kampf_k23.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Saved before the boss. If it goes badly, at least the paperwork survives.": [
	"ボスの前にセーブした。負けても、書類だけは生き残る。",
	"Sauvegardé avant le boss. Si ça tourne mal, la paperasse au moins survivra.",
	"Salvato prima del boss. Se va male, almeno le scartoffie sopravvivono.",
	"Guardado antes del jefe. Si sale mal, al menos el papeleo sobrevive.",
	"보스 앞에서 저장했다. 일이 틀어져도 서류만큼은 살아남는다.",
	"已在首领战前存档。就算输了，至少文书还在。",
	"已在首領戰前存檔。就算輸了，至少文書還在。",
	"Salvo antes do chefe. Se der errado, pelo menos a papelada sobrevive.",
	"Сохранено перед боссом. Если всё пойдёт плохо, хотя бы бумаги уцелеют.",
	"Zapisano przed bossem. Jeśli pójdzie źle, przynajmniej papiery przetrwają.",
	"Patrondan önce kaydedildi. İşler kötü giderse en azından evraklar kurtulur.",
	"Opgeslagen voor de baas. Gaat het mis, dan overleeft in elk geval het papierwerk."],
"Saving before the boss did not work this time.": [
	"ボスの前のセーブは今回はうまくいかなかった。",
	"La sauvegarde avant le boss n'a pas marché cette fois.",
	"Il salvataggio prima del boss stavolta non è riuscito.",
	"Esta vez no se pudo guardar antes del jefe.",
	"이번에는 보스 앞 저장이 되지 않았다.",
	"这次首领战前的存档没有成功。",
	"這次首領戰前的存檔沒有成功。",
	"Desta vez não deu para salvar antes do chefe.",
	"На этот раз сохраниться перед боссом не удалось.",
	"Tym razem zapis przed bossem się nie udał.",
	"Bu sefer patrondan önce kayıt yapılamadı.",
	"Opslaan voor de baas is deze keer niet gelukt."],
"The wild Spirling is still here. It waited, and it has not forgiven you for leaving.": [
	"野生のSpirlingはまだそこにいる。待っていたし、去ったことを許してはいない。",
	"Le Spirling sauvage est toujours là. Il a attendu, et il ne t'a pas pardonné d'être parti.",
	"Lo Spirling selvatico è ancora qui. Ha aspettato, e non ti ha perdonato di essertene andato.",
	"El Spirling salvaje sigue aquí. Esperó, y no te ha perdonado que te fueras.",
	"야생 Spirling은 아직 여기 있다. 기다렸고, 떠난 것을 용서하지 않았다.",
	"野生的Spirling还在这里。它一直在等，也没有原谅你的离开。",
	"野生的Spirling還在這裡。它一直在等，也沒有原諒你的離開。",
	"O Spirling selvagem ainda está aqui. Ele esperou e não perdoou sua partida.",
	"Дикий Spirling всё ещё здесь. Он ждал и не простил тебе ухода.",
	"Dziki Spirling wciąż tu jest. Czekał i nie wybaczył ci odejścia.",
	"Yabani Spirling hâlâ burada. Bekledi ve gitmeni affetmedi.",
	"De wilde Spirling is er nog. Hij heeft gewacht en vergeeft je niet dat je wegging."],
"Paused": ["一時停止", "Pause", "Pausa", "Pausa", "일시 정지", "暂停", "暫停", "Pausado", "Пауза", "Pauza", "Duraklatıldı", "Gepauzeerd"],
"Nothing moves. Even the foe holds its breath, out of politeness or spite.": [
	"何も動かない。相手まで息をひそめている。礼儀か、悪意か。",
	"Rien ne bouge. Même l'adversaire retient son souffle, par politesse ou par rancune.",
	"Nulla si muove. Anche l'avversario trattiene il fiato, per cortesia o per dispetto.",
	"Nada se mueve. Hasta el rival contiene el aliento, por cortesía o por rencor.",
	"아무것도 움직이지 않는다. 상대도 숨을 참는다. 예의인지 악의인지.",
	"一切静止。连对手都屏住了呼吸，不知是出于礼貌还是恶意。",
	"一切靜止。連對手都屏住了呼吸，不知是出於禮貌還是惡意。",
	"Nada se move. Até o rival prende a respiração, por educação ou por rancor.",
	"Ничто не движется. Даже противник затаил дыхание, из вежливости или со злобы.",
	"Nic się nie rusza. Nawet przeciwnik wstrzymuje oddech, z grzeczności albo ze złości.",
	"Hiçbir şey kıpırdamıyor. Rakip bile nefesini tutuyor, nezaketten ya da kinden.",
	"Niets beweegt. Zelfs de tegenstander houdt de adem in, uit beleefdheid of wrok."],
"No rush: %s": ["急がない: %s", "Sans hâte: %s", "Senza fretta: %s", "Sin prisa: %s", "느긋하게: %s", "不催促: %s", "不催促: %s", "Sem pressa: %s", "Без спешки: %s", "Bez pośpiechu: %s", "Acele yok: %s", "Geen haast: %s"],
"Tap guard: %s": ["誤タップ防止: %s", "Anti-tap: %s", "Anti-tocco: %s", "Anti-toque: %s", "오터치 방지: %s", "防误触: %s", "防誤觸: %s", "Antitoque: %s", "Защита: %s", "Ochrona: %s", "Tık koruma: %s", "Tikbeveiliging: %s"],
"Short": ["短い", "Court", "Breve", "Corto", "짧게", "短", "短", "Curto", "Коротко", "Krótko", "Kısa", "Kort"],
"Long": ["長い", "Long", "Lungo", "Largo", "길게", "长", "長", "Longo", "Долго", "Długo", "Uzun", "Lang"],
"Battle text waits for your tap at any speed, and every bond is the calm echo. Nothing in battle runs on a clock.": [
	"どの速さでもバトルの文はタップを待ち、絆はいつも落ち着いたエコーになる。バトルで時計は動かない。",
	"Le texte du combat attend ton toucher à toute vitesse, et chaque lien est l'écho calme. Rien ne tourne au chrono en combat.",
	"Il testo della lotta aspetta il tuo tocco a ogni velocità e ogni legame è l'eco calma. In lotta non corre nessun orologio.",
	"El texto del combate espera tu toque a cualquier velocidad y cada vínculo es el eco tranquilo. En combate no corre ningún reloj.",
	"어느 속도에서도 전투 문장은 터치를 기다리고, 모든 유대는 차분한 메아리가 된다. 전투에서 시계는 돌지 않는다.",
	"任何速度下战斗文字都会等你点击，每次结缘都是平静的回声。战斗中没有任何计时。",
	"任何速度下戰鬥文字都會等你點擊，每次結緣都是平靜的回聲。戰鬥中沒有任何計時。",
	"O texto da batalha espera seu toque em qualquer velocidade, e todo vínculo é o eco calmo. Nada na batalha corre contra o relógio.",
	"Текст боя ждёт касания на любой скорости, а каждая связь идёт через спокойное эхо. В бою никакие часы не тикают.",
	"Tekst walki czeka na dotknięcie przy każdej prędkości, a każda więź to spokojne echo. W walce nie tyka żaden zegar.",
	"Savaş metni her hızda dokunuşunu bekler ve her bağ sakin yankıdır. Savaşta hiçbir saat işlemez.",
	"Gevechtstekst wacht bij elke snelheid op je tik, en elke band is de rustige echo. In een gevecht loopt geen klok."],
"How long menus ignore taps after they appear, so a shaky or late tap picks nothing by mistake.": [
	"メニューが出たあと、どのくらいタップを無視するか。手がふるえても遅れても、うっかり選ばない。",
	"Combien de temps les menus ignorent les touchers après leur apparition, pour qu'un toucher tremblant ou tardif ne choisisse rien par erreur.",
	"Per quanto tempo i menu ignorano i tocchi dopo essere apparsi, così un tocco incerto o in ritardo non sceglie nulla per sbaglio.",
	"Cuánto tiempo ignoran los menús los toques al aparecer, para que un toque tembloroso o tardío no elija nada por error.",
	"메뉴가 나타난 뒤 터치를 얼마나 무시할지. 떨리거나 늦은 터치로 실수로 고르지 않게 한다.",
	"菜单出现后忽略点击多长时间，免得手抖或迟到的点击误选。",
	"選單出現後忽略點擊多長時間，免得手抖或遲到的點擊誤選。",
	"Quanto tempo os menus ignoram toques ao aparecer, para que um toque trêmulo ou atrasado não escolha nada por engano.",
	"Сколько меню не замечает касания после появления, чтобы дрожащее или запоздалое касание ничего не выбрало случайно.",
	"Jak długo menu ignoruje dotknięcia po pojawieniu się, by drżące lub spóźnione dotknięcie niczego nie wybrało przez pomyłkę.",
	"Menüler açıldıktan sonra dokunuşları ne kadar yok sayar; titrek ya da geç bir dokunuş yanlışlıkla bir şey seçmez.",
	"Hoe lang menu's tikken negeren nadat ze verschijnen, zodat een trillende of late tik niets per ongeluk kiest."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k23, written by tools/i18n/locales_kampf_k23.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k23.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k23: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
