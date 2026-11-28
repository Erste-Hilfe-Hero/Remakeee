#!/usr/bin/env python3
"""Translations of the German table kampf_k27 (tools/i18n/de_kampf_k27.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k27.json. Run: python3 tools/i18n/locales_kampf_k27.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Hesper: And if one of yours forgot an art it once knew, I can dig it back up. For a fee. Memory is cheap; mine isn't.": [
	"ヘスパー: それと、あんたの子が昔覚えたわざを忘れたなら、掘り起こしてやるよ。もちろん有料だ。記憶は安い。あたしのは安くないがね。",
	"Hesper: Et si l'un des tiens a oublié une technique qu'il savait, je peux la déterrer. Contre paiement. La mémoire ne coûte rien; la mienne, si.",
	"Hesper: E se uno dei tuoi ha dimenticato una tecnica che sapeva, posso dissotterrarla. A pagamento. La memoria costa poco; la mia no.",
	"Hesper: Y si uno de los tuyos olvidó una técnica que sabía, puedo desenterrarla. Por un precio. La memoria es barata; la mía no.",
	"헤스퍼: 그리고 네 아이 중에 예전에 알던 기술을 잊은 녀석이 있으면 다시 파내 줄 수 있지. 대가는 받고. 기억은 싸. 내 기억은 안 싸지만.",
	"海佩尔：要是你的伙伴忘了曾经会的招式，我能把它挖回来。当然要收费。记忆很便宜，我的可不便宜。",
	"海佩爾：要是你的夥伴忘了曾經會的招式，我能把它挖回來。當然要收費。記憶很便宜，我的可不便宜。",
	"Hesper: E se um dos seus esqueceu uma técnica que sabia, posso desenterrá-la. Mediante pagamento. Memória é barata; a minha não.",
	"Геспер: А если кто-то из твоих забыл приём, который когда-то знал, я могу его откопать. За плату. Память дешёвая, моя - нет.",
	"Hesper: A jeśli któryś z twoich zapomniał technikę, którą kiedyś znał, mogę ją odkopać. Za opłatą. Pamięć jest tania; moja nie.",
	"Hesper: Seninkilerden biri bir zamanlar bildiği bir tekniği unuttuysa, onu geri kazıp çıkarırım. Ücreti karşılığında. Hafıza ucuzdur; benimki değil.",
	"Hesper: En als een van de jouwe een techniek vergat die hij ooit kende, graaf ik die weer op. Tegen betaling. Geheugen is goedkoop; het mijne niet."],
"Who forgot an art? %d coins each.": [
	"わざを忘れたのは誰? 1つ%dコイン。",
	"Qui a oublié une technique? %d pièces chacune.",
	"Chi ha dimenticato una tecnica? %d monete l'una.",
	"¿Quién olvidó una técnica? %d monedas cada una.",
	"누가 기술을 잊었지? 하나에 %d코인.",
	"谁忘了招式？每个%d枚硬币。",
	"誰忘了招式？每個%d枚硬幣。",
	"Quem esqueceu uma técnica? %d moedas cada.",
	"Кто забыл приём? %d монет за каждый.",
	"Kto zapomniał technikę? %d monet za każdą.",
	"Kim bir teknik unuttu? Tanesi %d sikke.",
	"Wie vergat een techniek? %d munten per stuk."],
"Hesper: %s remembers everything it can. Lucky thing.": [
	"ヘスパー: %sは覚えられることを全部覚えてる。運のいい子だ。",
	"Hesper: %s se souvient de tout ce qu'il peut. Veinard.",
	"Hesper: %s ricorda tutto quello che può. Fortunato.",
	"Hesper: %s recuerda todo lo que puede. Qué suerte.",
	"헤스퍼: %s은(는) 배울 수 있는 건 다 기억하고 있어. 운 좋은 녀석.",
	"海佩尔：%s能记住的全都记得。真走运。",
	"海佩爾：%s能記住的全都記得。真走運。",
	"Hesper: %s se lembra de tudo o que pode. Sortudo.",
	"Геспер: %s помнит всё, что может. Везунчик.",
	"Hesper: %s pamięta wszystko, co może. Szczęściarz.",
	"Hesper: %s yapabildiği her şeyi hatırlıyor. Şanslı şey.",
	"Hesper: %s weet nog alles wat het kan. Geluksvogel."],
"Hesper: %d coins. Forgetting is free, remembering is not.": [
	"ヘスパー: %dコインだ。忘れるのはタダ、思い出すのはタダじゃない。",
	"Hesper: %d pièces. Oublier est gratuit, se souvenir non.",
	"Hesper: %d monete. Dimenticare è gratis, ricordare no.",
	"Hesper: %d monedas. Olvidar es gratis; recordar, no.",
	"헤스퍼: %d코인. 잊는 건 공짜지만 기억하는 건 아니야.",
	"海佩尔：%d枚硬币。遗忘是免费的，记起来可不是。",
	"海佩爾：%d枚硬幣。遺忘是免費的，記起來可不是。",
	"Hesper: %d moedas. Esquecer é de graça, lembrar não.",
	"Геспер: %d монет. Забывать - бесплатно, вспоминать - нет.",
	"Hesper: %d monet. Zapominanie jest za darmo, przypominanie nie.",
	"Hesper: %d sikke. Unutmak bedava, hatırlamak değil.",
	"Hesper: %d munten. Vergeten is gratis, herinneren niet."],
"%s is cured.": [
	"%sは治った。",
	"%s est guéri.",
	"%s è guarito.",
	"%s se ha curado.",
	"%s은(는) 나았다.",
	"%s治好了。",
	"%s治好了。",
	"%s está curado.",
	"%s исцелён.",
	"%s jest wyleczony.",
	"%s iyileşti.",
	"%s is genezen."],
"On Story every status ends with the battle. On the other difficulties Scorch, Root and Jolt stay on until an item, an art or a rest cures them.": [
	"物語では状態はすべて戦いと一緒に終わる。ほかの難易度では焦げ、根づき、しびれは道具、わざ、休息で治るまで残る。",
	"En Récit, chaque statut prend fin avec le combat. Dans les autres difficultés, Brûlure, Racines et Choc restent jusqu'à ce qu'un objet, une technique ou une pause les soigne.",
	"In Storia ogni stato finisce con la battaglia. Nelle altre difficoltà Arsura, Radici e Scossa restano finché un oggetto, una tecnica o una sosta non li cura.",
	"En Historia cada estado termina con el combate. En las demás dificultades, Quemadura, Raíces y Calambre se quedan hasta que un objeto, una técnica o un descanso los cure.",
	"이야기 난이도에서는 모든 상태가 전투와 함께 끝난다. 다른 난이도에서는 화상, 뿌리 묶임, 찌릿이 도구나 기술, 휴식으로 나을 때까지 남는다.",
	"在故事难度下，所有状态都会随战斗结束。其他难度下，灼烧、缠根和电麻会一直留着，直到用道具、招式或休息治好。",
	"在故事難度下，所有狀態都會隨戰鬥結束。其他難度下，焦灼、纏根和觸電會一直留著，直到用道具、招式或休息治好。",
	"Na História, todo estado termina com a batalha. Nas outras dificuldades, Chamusco, Raízes e Choque continuam até que um item, uma técnica ou um descanso os cure.",
	"На уровне «Сюжет» любое состояние кончается вместе с боем. На других уровнях Ожог, Корни и Разряд остаются, пока их не вылечит предмет, приём или отдых.",
	"W trybie Opowieść każdy stan kończy się z walką. Na innych poziomach Oparzenie, Ukorzenienie i Wstrząs zostają, aż wyleczy je przedmiot, technika lub odpoczynek.",
	"Hikâye'de her durum savaşla biter. Diğer zorluklarda Yanık, Köklenme ve Şok bir eşya, bir teknik ya da dinlenme iyileştirene kadar kalır.",
	"Op Verhaal eindigt elke status met het gevecht. Op de andere niveaus blijven Brand, Wortels en Schok tot een voorwerp, een techniek of rust ze geneest."],
}

for i, code in enumerate(LANGS):
    strings = {k: v[i] for k, v in sorted(R.items())}
    data = {"_comment": "Texts for %s from tools/i18n/locales_kampf_k27.py (KAMPF_PLAN_1000 items 138, 179)." % code,
            "strings": strings}
    path = os.path.join(ROOT, "data/i18n", code, "kampf_k27.json")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
print("wrote kampf_k27 for %d locales" % len(LANGS))
