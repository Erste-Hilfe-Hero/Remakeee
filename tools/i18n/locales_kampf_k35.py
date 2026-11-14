#!/usr/bin/env python3
"""Translations of the German table kampf_k35 (tools/i18n/de_kampf_k35.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k35.json. Run: python3 tools/i18n/locales_kampf_k35.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Brute force": ["力押し", "Force brute", "Forza bruta", "Fuerza bruta", "힘으로 밀어붙이기", "蛮力", "強攻", "Força bruta", "Грубая сила", "Brutalna siła", "Kaba kuvvet", "Brute kracht"],
"Field tricks": ["フィールド戦術", "Ruses de terrain", "Trucchi di campo", "Trucos de campo", "필드 전술", "场地战术", "場地戰術", "Truques de campo", "Уловки с полем", "Sztuczki z polem", "Alan hileleri", "Veldtrucs"],
"Status tricks": ["状態異常戦術", "Ruses d'état", "Trucchi di stato", "Trucos de estado", "상태 이상 전술", "状态战术", "狀態戰術", "Truques de estado", "Уловки с состояниями", "Sztuczki ze stanami", "Durum hileleri", "Statustrucs"],
"Stage tricks": ["能力段階戦術", "Ruses de paliers", "Trucchi di livelli", "Trucos de niveles", "능력 단계 전술", "能力阶段战术", "能力階段戰術", "Truques de níveis", "Уловки со ступенями", "Sztuczki ze stopniami", "Kademe hileleri", "Trappentrucs"],
"No tricks. Just teeth. Some of them used to be someone else's.": [
    "小細工はなし。歯だけだ。何本かは、もとは他人のものだったがな。",
    "Pas de ruses. Juste des dents. Certaines appartenaient à quelqu'un d'autre.",
    "Niente trucchi. Solo denti. Alcuni erano di qualcun altro.",
    "Sin trucos. Solo dientes. Algunos eran de otra persona.",
    "잔재주는 없어. 이빨뿐이지. 몇 개는 원래 남의 것이었지만.",
    "没有花招。只有牙齿。其中几颗以前是别人的。",
    "沒有花招。只有牙齒。其中幾顆以前是別人的。",
    "Sem truques. Só dentes. Alguns eram de outra pessoa.",
    "Никаких уловок. Только зубы. Некоторые раньше были чужими.",
    "Żadnych sztuczek. Tylko zęby. Niektóre należały kiedyś do kogoś innego.",
    "Hile yok. Sadece dişler. Bazıları eskiden başkasınındı.",
    "Geen trucs. Alleen tanden. Een paar waren vroeger van iemand anders."],
"The ground here owes me money. Watch it pay up.": [
    "この土地はおれに借りがある。払うところを見ていろ。",
    "Le sol ici me doit de l'argent. Regarde-le payer.",
    "Il terreno qui mi deve dei soldi. Guarda come paga.",
    "El suelo de aquí me debe dinero. Mira cómo paga.",
    "이 땅은 나한테 빚이 있어. 갚는 걸 잘 봐.",
    "这片地欠我钱。看它怎么还。",
    "這片地欠我錢。看它怎麼還。",
    "O chão aqui me deve dinheiro. Veja ele pagar.",
    "Эта земля должна мне денег. Смотри, как она платит.",
    "Ta ziemia jest mi winna pieniądze. Patrz, jak płaci.",
    "Buradaki toprak bana borçlu. Nasıl ödediğini izle.",
    "De grond hier is me geld schuldig. Kijk maar hoe hij betaalt."],
"I don't win duels. I make you lose them slowly.": [
    "おれは勝負に勝たない。おまえをゆっくり負けさせるだけだ。",
    "Je ne gagne pas les duels. Je te les fais perdre lentement.",
    "Io non vinco i duelli. Te li faccio perdere lentamente.",
    "Yo no gano duelos. Hago que los pierdas despacio.",
    "난 대결에서 이기지 않아. 네가 천천히 지게 만들 뿐이지.",
    "我不赢对决。我让你慢慢输掉。",
    "我不贏對決。我讓你慢慢輸掉。",
    "Eu não venço duelos. Faço você perdê-los devagar.",
    "Я не выигрываю поединки. Я заставляю тебя медленно их проигрывать.",
    "Nie wygrywam pojedynków. Sprawiam, że przegrywasz je powoli.",
    "Ben düello kazanmam. Senin yavaşça kaybetmeni sağlarım.",
    "Ik win geen duels. Ik laat jou ze langzaam verliezen."],
"Give me three turns. You won't get a fourth.": [
    "3ターンくれ。4ターン目はおまえにはない。",
    "Donne-moi trois tours. Tu n'en auras pas de quatrième.",
    "Dammi tre turni. Un quarto non lo avrai.",
    "Dame tres turnos. No tendrás un cuarto.",
    "세 턴만 줘. 네 번째 턴은 없을 거야.",
    "给我三个回合。你不会有第四个。",
    "給我三個回合。你不會有第四個。",
    "Me dê três turnos. Você não terá um quarto.",
    "Дай мне три хода. Четвёртого у тебя не будет.",
    "Daj mi trzy tury. Czwartej nie dostaniesz.",
    "Bana üç tur ver. Dördüncüsü sana kalmayacak.",
    "Geef me drie beurten. Een vierde krijg je niet."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k35, written by tools/i18n/locales_kampf_k35.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k35.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k35: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
