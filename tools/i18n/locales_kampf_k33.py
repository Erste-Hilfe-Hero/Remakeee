#!/usr/bin/env python3
"""Translations of the German table kampf_k33 (tools/i18n/de_kampf_k33.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k33.json. Run: python3 tools/i18n/locales_kampf_k33.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"%s picks %s at random, as wild ones do.": [
    "{0}は野生らしく、でたらめに{1}を選んだ。", "%s choisit %s au hasard, comme le font les sauvages.", "%s sceglie %s a caso, come fanno i selvatici.",
    "%s elige %s al azar, como hacen los salvajes.", "{0}은(는) 야생답게 아무렇게나 {1}을(를) 골랐다.", "%s像野生的那样，随便选了%s。", "%s像野生的那樣，隨便選了%s。",
    "%s escolhe %s ao acaso, como os selvagens fazem.", "%s выбирает %s наугад, как все дикие.", "%s wybiera %s na chybił trafił, jak to dzikie.",
    "{0}, vahşiler gibi rastgele {1} seçiyor.", "%s kiest %s op goed geluk, zoals wilde dat doen."],
"%s picks %s (%d) over %s (%d).": [
    "{0}は{3}（{4}）より{1}（{2}）を選んだ。", "%s choisit %s (%d) plutôt que %s (%d).", "%s sceglie %s (%d) invece di %s (%d).",
    "%s elige %s (%d) en vez de %s (%d).", "{0}은(는) {3}({4}) 대신 {1}({2})을(를) 골랐다.", "%s选择了%s（%d），而不是%s（%d）。", "%s選擇了%s（%d），而不是%s（%d）。",
    "%s escolhe %s (%d) em vez de %s (%d).", "%s выбирает %s (%d), а не %s (%d).", "%s wybiera %s (%d) zamiast %s (%d).",
    "{0}, {3} ({4}) yerine {1} ({2}) seçiyor.", "%s kiest %s (%d) boven %s (%d)."],
"%s picks %s (%d): nothing else is in reach.": [
    "{0}は{1}（{2}）を選んだ。ほかに手はない。", "%s choisit %s (%d): rien d'autre n'est à sa portée.", "%s sceglie %s (%d): nient'altro è alla sua portata.",
    "%s elige %s (%d): no tiene nada más a su alcance.", "{0}은(는) {1}({2})을(를) 골랐다. 다른 수는 없다.", "%s选择了%s（%d）：别无他法。", "%s選擇了%s（%d）：別無他法。",
    "%s escolhe %s (%d): não há mais nada ao alcance.", "%s выбирает %s (%d): больше ничего не остаётся.", "%s wybiera %s (%d): nic innego nie wchodzi w grę.",
    "{0}, {1} ({2}) seçiyor: elinde başka bir şey yok.", "%s kiest %s (%d): iets anders zit er niet in."],
"%s swaps to %s: it doesn't like its odds.": [
    "{0}は{1}に交代した。分が悪いと見たらしい。", "%s passe le relais à %s: ses chances ne lui plaisent pas.", "%s passa il turno a %s: le sue probabilità non gli piacciono.",
    "%s cambia a %s: no le gustan sus posibilidades.", "{0}은(는) {1}(으)로 교대했다. 승산이 없다고 본 모양이다.", "%s换成了%s：它不喜欢眼下的胜算。", "%s換成了%s：它不喜歡眼下的勝算。",
    "%s troca para %s: não gosta das suas chances.", "%s уступает место %s: шансы ему не нравятся.", "%s zmienia na %s: nie podobają mu się szanse.",
    "{0}, {1} ile yer değiştiriyor: şansını beğenmiyor.", "%s wisselt naar %s: het vertrouwt zijn kansen niet."],
"%s uses %s: it is running low.": [
    "{0}は{1}を使った。もう後がない。", "%s utilise %s: il est à bout.", "%s usa %s: è allo stremo.",
    "%s usa %s: está en las últimas.", "{0}은(는) {1}을(를) 사용했다. 이제 여유가 없다.", "%s使用了%s：它快撑不住了。", "%s使用了%s：它快撐不住了。",
    "%s usa %s: está no limite.", "%s использует %s: силы на исходе.", "%s używa %s: ledwo się trzyma.",
    "{0}, {1} kullanıyor: gücü tükenmek üzere.", "%s gebruikt %s: het zit bijna op zijn laatste adem."],
"%s rests: nothing it can pay is worth it now.": [
    "{0}は休んだ。今払えるわざに価値はない。", "%s se repose: rien de ce qu'il peut payer n'en vaut la peine.", "%s riposa: niente di ciò che può pagare ne vale la pena.",
    "%s descansa: nada de lo que puede pagar merece la pena ahora.", "{0}은(는) 휴식했다. 지금 쓸 수 있는 기술은 쓸모가 없다.", "%s休息了：现在付得起的招式都不值得。", "%s休息了：現在付得起的招式都不值得。",
    "%s descansa: nada que possa pagar vale a pena agora.", "%s отдыхает: ничто из доступного сейчас того не стоит.", "%s odpoczywa: nic, na co go stać, nie jest teraz warte zachodu.",
    "{0} dinleniyor: karşılayabildiği hiçbir şey şu an buna değmez.", "%s rust: niets wat het kan betalen is het nu waard."],
"It wants that field gone, so it can wake.": [
    "目覚めるために、あのフィールドを消したがっている。", "Il veut se débarrasser de ce terrain pour pouvoir s'éveiller.", "Vuole liberarsi di quel campo per potersi risvegliare.",
    "Quiere deshacerse de ese campo para poder despertar.", "깨어나기 위해 저 필드를 없애고 싶어 한다.", "它想除掉那片场地，好让自己苏醒。", "它想除掉那片場地，好讓自己甦醒。",
    "Quer se livrar daquele campo para poder despertar.", "Оно хочет избавиться от этого поля, чтобы пробудиться.", "Chce pozbyć się tego pola, by móc się przebudzić.",
    "Uyanabilmek için o alandan kurtulmak istiyor.", "Het wil dat veld kwijt, zodat het kan ontwaken."],
"It lies open and stops building up.": [
    "すきだらけなので、力をためるのをやめた。", "Il est à découvert et cesse de se renforcer.", "È scoperto e smette di potenziarsi.",
    "Está al descubierto y deja de reforzarse.", "빈틈이 드러나 힘을 모으는 것을 그만두었다.", "它露出破绽，不再积蓄力量。", "它露出破綻，不再積蓄力量。",
    "Está exposto e para de se fortalecer.", "Оно открыто и перестаёт копить силы.", "Jest odsłonięty i przestaje się wzmacniać.",
    "Açıkta kaldı ve güç toplamayı bırakıyor.", "Het ligt open en bouwt niets meer op."],
"Last phase: it holds nothing back.": [
    "最終段階：もう何も出し惜しみしない。", "Dernière phase: il ne retient plus rien.", "Ultima fase: non si trattiene più.",
    "Última fase: ya no se guarda nada.", "마지막 단계: 더는 아무것도 아끼지 않는다.", "最终阶段：它不再有任何保留。", "最終階段：它不再有任何保留。",
    "Última fase: não guarda mais nada.", "Последняя фаза: оно больше ничего не сдерживает.", "Ostatnia faza: niczego już nie oszczędza.",
    "Son aşama: artık hiçbir şeyi geri tutmuyor.", "Laatste fase: het houdt niets meer in."],
"Boss replays": [
    "ボス戦の再生", "Rediffusions de boss", "Replay dei boss", "Repeticiones de jefes", "보스전 다시보기", "首领回放", "首領回放",
    "Replays de chefes", "Повторы боёв с боссами", "Powtórki walk z bossami", "Patron tekrarları", "Baas-herhalingen"],
"%s, won in %d turns": [
    "{0}、{1}ターンで勝利", "%s, gagné en %d tours", "%s, vinto in %d turni", "%s, ganado en %d turnos", "{0}, {1}턴 만에 승리", "%s，%d回合获胜", "%s，%d回合獲勝",
    "%s, vencido em %d turnos", "%s, победа за %d ходов", "%s, wygrana w %d tur", "{0}, {1} turda kazanıldı", "%s, gewonnen in %d beurten"],
"Kept in your boss replays (Records).": [
    "ボス戦の再生に保存した（記録）。", "Gardé dans tes rediffusions de boss (Records).", "Salvato nei tuoi replay dei boss (Record).",
    "Guardado en tus repeticiones de jefes (Marcas).", "보스전 다시보기에 저장했다 (기록).", "已保存到首领回放（纪录）。", "已保存到首領回放（紀錄）。",
    "Guardado nos seus replays de chefes (Recordes).", "Сохранено в повторах боёв с боссами (Рекорды).", "Zapisano w powtórkach walk z bossami (Rekordy).",
    "Patron tekrarlarına kaydedildi (Rekorlar).", "Bewaard in je baas-herhalingen (Records)."],
"Banked Embers": [
    "利子つきの残り火", "Braises placées", "Braci a interesse", "Brasas con intereses", "이자 붙은 불씨", "带利息的余烬", "帶利息的餘燼",
    "Brasas com juros", "Угли под проценты", "Żar na procent", "Faizli Köz", "Gloed op rente"],
"Beat the Ashen Heart. The smiths still want their cut.": [
    "灰の心臓を倒す。鍛冶屋たちはそれでも分け前を欲しがる。", "Bats le Cœur cendré. Les forgerons veulent quand même leur part.", "Sconfiggi il Cuore di Cenere. I fabbri vogliono comunque la loro parte.",
    "Vence al Corazón Ceniciento. Los herreros siguen queriendo su parte.", "잿빛 심장을 쓰러뜨린다. 대장장이들은 그래도 몫을 원한다.", "击败灰烬之心。铁匠们照样要分一杯羹。", "擊敗灰燼之心。鐵匠們照樣要分一杯羹。",
    "Derrote o Coração Cinzento. Os ferreiros ainda querem a parte deles.", "Победи Пепельное сердце. Кузнецы всё равно хотят свою долю.", "Pokonaj Popielne Serce. Kowale i tak chcą swojej działki.",
    "Kül Yürek'i yen. Demirciler yine de paylarını istiyor.", "Versla het Asgrauwe Hart. De smeden willen nog steeds hun deel."],
"Last Passenger": [
    "最後の乗客", "Dernier passager", "Ultimo passeggero", "Último pasajero", "마지막 승객", "最后一名乘客", "最後一名乘客",
    "Último passageiro", "Последний пассажир", "Ostatni pasażer", "Son Yolcu", "Laatste passagier"],
"Beat the Drowned Heart. Nobody reads the passenger list twice.": [
    "溺れた心臓を倒す。乗客名簿を二度読む者はいない。", "Bats le Cœur noyé. Personne ne relit la liste des passagers.", "Sconfiggi il Cuore Annegato. Nessuno legge due volte la lista dei passeggeri.",
    "Vence al Corazón Ahogado. Nadie lee dos veces la lista de pasajeros.", "익사한 심장을 쓰러뜨린다. 승객 명단을 두 번 읽는 사람은 없다.", "击败溺亡之心。没人会把乘客名单读第二遍。", "擊敗溺亡之心。沒人會把乘客名單讀第二遍。",
    "Derrote o Coração Afogado. Ninguém lê a lista de passageiros duas vezes.", "Победи Утонувшее сердце. Список пассажиров дважды никто не читает.", "Pokonaj Utopione Serce. Nikt nie czyta listy pasażerów dwa razy.",
    "Boğulmuş Yürek'i yen. Yolcu listesini kimse iki kez okumaz.", "Versla het Verdronken Hart. Niemand leest de passagierslijst twee keer."],
"Clear Weather": [
    "晴れ渡る空", "Temps dégagé", "Cielo sereno", "Cielo despejado", "맑은 하늘", "天朗气清", "天朗氣清",
    "Céu limpo", "Ясная погода", "Czyste niebo", "Açık Hava", "Helder weer"],
"Beat the Mist Heart. What it hid is everyone's problem now.": [
    "霧の心臓を倒す。隠されていたものは、今やみんなの問題だ。", "Bats le Cœur de brume. Ce qu'il cachait est maintenant le problème de tous.", "Sconfiggi il Cuore di Nebbia. Ciò che nascondeva ora è un problema di tutti.",
    "Vence al Corazón de Niebla. Lo que ocultaba ahora es problema de todos.", "안개 심장을 쓰러뜨린다. 그것이 숨기던 것은 이제 모두의 문제다.", "击败迷雾之心。它藏起的东西，如今成了所有人的麻烦。", "擊敗迷霧之心。它藏起的東西，如今成了所有人的麻煩。",
    "Derrote o Coração de Névoa. O que ele escondia agora é problema de todos.", "Победи Туманное сердце. То, что оно скрывало, теперь общая беда.", "Pokonaj Mgliste Serce. To, co ukrywało, jest teraz problemem wszystkich.",
    "Sis Yürek'i yen. Sakladığı şey artık herkesin derdi.", "Versla het Nevelhart. Wat het verborg, is nu ieders probleem."],
"Crier: An echo of the %s has crashed the festival in the shape of a %s. Nobody invited it. Will you see it out?": [
    "触れ役: {0}の残響が、{1}の姿でお祭りに押しかけてきた。誰も呼んでないのに。追い出してくれる？",
    "Crieur: Un écho du %s s'est invité à la fête sous la forme d'un %s. Personne ne l'a convié. Tu le raccompagnes?",
    "Banditore: Un'eco del %s si è imbucata alla festa con l'aspetto di un %s. Nessuno l'ha invitata. La accompagni fuori?",
    "Pregonero: Un eco del %s se ha colado en la fiesta con la forma de un %s. Nadie lo invitó. ¿Lo acompañas a la salida?",
    "전령: {0}의 메아리가 {1}의 모습으로 축제에 쳐들어왔소. 아무도 부르지 않았는데. 내보내 주겠소?",
    "传令人：%s的回响化作%s的模样闯进了节日。没人邀请它。你能把它请出去吗？",
    "傳令員：%s的迴響化作%s的模樣闖進了慶典。沒人邀請它。你能把它請出去嗎？",
    "Pregoeiro: Um eco do %s invadiu a festa na forma de um %s. Ninguém o convidou. Você o acompanha até a saída?",
    "Глашатай: Эхо сердца «%s» ворвалось на праздник в облике %s. Его никто не звал. Выпроводишь?",
    "Heroldka: Echo %s wdarło się na festyn pod postacią %s. Nikt go nie zapraszał. Wyprowadzisz je?",
    "Tellal: {0} yankısı, {1} kılığında şenliğe daldı. Kimse davet etmedi. Onu kapıya kadar geçirir misin?",
    "Omroeper: Een echo van het %s is het feest binnengevallen in de gedaante van een %s. Niemand heeft het uitgenodigd. Werk je het naar buiten?"],
"Crier: Something from the Rifts keeps trying to get in. Seal a Rift heart first, then we'll talk.": [
    "触れ役: 裂け目から何かが入りこもうとしてるんだ。まず裂け目の心臓を封じておいで。話はそれからだよ。",
    "Crieur: Quelque chose venu des Failles essaie sans cesse d'entrer. Scelle d'abord un cœur de Faille, on en reparlera.",
    "Banditore: Qualcosa dalle Fenditure continua a cercare di entrare. Sigilla prima un cuore di Fenditura, poi ne parliamo.",
    "Pregonero: Algo de las Grietas no deja de intentar entrar. Sella primero un corazón de Grieta y luego hablamos.",
    "전령: 균열에서 뭔가가 자꾸 들어오려 하오. 먼저 균열의 심장을 봉인하고 오시오. 얘기는 그다음이오.",
    "传令人：裂隙里有东西一直想闯进来。先去封印一颗裂隙之心，我们再谈。",
    "傳令員：裂隙裡有東西一直想闖進來。先去封印一顆裂隙之心，我們再談。",
    "Pregoeiro: Algo das Fendas não para de tentar entrar. Sele primeiro um coração de Fenda, depois conversamos.",
    "Глашатай: Что-то из Разломов всё пытается пролезть сюда. Сначала запечатай сердце Разлома, потом поговорим.",
    "Heroldka: Coś z Rozpadlin wciąż próbuje się wedrzeć. Najpierw zapieczętuj serce Rozpadliny, potem pogadamy.",
    "Tellal: Yarıklardan bir şey durmadan içeri girmeye çalışıyor. Önce bir Yarık yüreğini mühürle, sonra konuşuruz.",
    "Omroeper: Iets uit de Scheuren probeert steeds binnen te komen. Verzegel eerst een Scheurhart, dan praten we verder."],
"Crier: You saw the echo out already. It sulks somewhere behind the stands until next year.": [
    "触れ役: あの残響はもう追い出してくれたね。来年まで屋台の裏ですねてるよ。",
    "Crieur: Tu as déjà raccompagné l'écho. Il boude derrière les stands jusqu'à l'an prochain.",
    "Banditore: L'eco l'hai già accompagnata fuori. Tiene il broncio dietro le bancarelle fino all'anno prossimo.",
    "Pregonero: Ya sacaste al eco. Se queda enfurruñado detrás de los puestos hasta el año que viene.",
    "전령: 그 메아리는 이미 내보냈잖소. 내년까지 노점 뒤에서 토라져 있을 거요.",
    "传令人：那个回响你已经请出去了。它会躲在摊位后面生闷气，直到明年。",
    "傳令員：那個迴響你已經請出去了。它會躲在攤位後面生悶氣，直到明年。",
    "Pregoeiro: Você já levou o eco para fora. Ele fica emburrado atrás das barracas até o ano que vem.",
    "Глашатай: Эхо ты уже выпроводил. Теперь оно дуется за прилавками до следующего года.",
    "Heroldka: Echo już wyprowadziłeś. Dąsa się gdzieś za straganami do przyszłego roku.",
    "Tellal: Yankıyı zaten kapıya kadar geçirdin. Gelecek yıla kadar tezgâhların arkasında surat asıyor.",
    "Omroeper: Je hebt de echo al naar buiten gewerkt. Het mokt tot volgend jaar ergens achter de kraampjes."],
"The echo comes apart like old bunting. The crowd claps as if it had helped.": [
    "残響は古い飾り旗のようにほどけた。観客はまるで自分が手伝ったかのように拍手している。",
    "L'écho se défait comme de vieux fanions. La foule applaudit comme si elle avait aidé.",
    "L'eco si sfalda come vecchi festoni. La folla applaude come se avesse aiutato.",
    "El eco se deshace como banderines viejos. El público aplaude como si hubiera ayudado.",
    "메아리가 낡은 깃발 장식처럼 풀려 버렸다. 구경꾼들은 자기들이 도운 양 박수를 친다.",
    "回响像旧彩旗一样散了架。人群鼓起掌来，好像他们也出了力。",
    "迴響像舊彩旗一樣散了架。人群鼓起掌來，好像他們也出了力。",
    "O eco se desfaz como bandeirolas velhas. A multidão aplaude como se tivesse ajudado.",
    "Эхо расползается, как старые флажки. Толпа хлопает, будто сама помогала.",
    "Echo rozłazi się jak stare chorągiewki. Tłum klaszcze, jakby pomagał.",
    "Yankı eski süs bayrakları gibi dağılıyor. Kalabalık sanki yardım etmiş gibi alkışlıyor.",
    "De echo valt uit elkaar als oude vlaggetjes. Het publiek klapt alsof het geholpen heeft."],
"The echo keeps dancing. The crowd decides it is part of the show.": [
    "残響は踊り続けている。観客は、これも出し物の一部だと決めこんだ。",
    "L'écho continue de danser. La foule décide que ça fait partie du spectacle.",
    "L'eco continua a ballare. La folla decide che fa parte dello spettacolo.",
    "El eco sigue bailando. El público decide que es parte del espectáculo.",
    "메아리는 계속 춤춘다. 구경꾼들은 그것도 공연의 일부라고 여기기로 했다.",
    "回响还在跳舞。人群认定这是表演的一部分。",
    "迴響還在跳舞。人群認定這是表演的一部分。",
    "O eco continua dançando. A multidão decide que faz parte do show.",
    "Эхо продолжает плясать. Толпа решает, что так задумано.",
    "Echo dalej tańczy. Tłum uznaje, że to część przedstawienia.",
    "Yankı dans etmeye devam ediyor. Kalabalık bunun gösterinin bir parçası olduğuna karar veriyor.",
    "De echo blijft dansen. Het publiek besluit dat het bij de show hoort."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k33, written by tools/i18n/locales_kampf_k33.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k33.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k33: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
