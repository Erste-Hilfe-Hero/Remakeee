#!/usr/bin/env python3
"""Translations of the German table p2w_shop (tools/i18n/de_p2w_shop.py) for the other 12 locales.
Writes data/i18n/<code>/p2w_shop.json. Run: python3 tools/i18n/locales_p2w_shop.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Featured": ["おすすめ", "À la une", "In evidenza", "Destacado", "추천", "精选", "精選", "Destaques", "Избранное", "Polecane", "Öne çıkan", "Uitgelicht"],
"Bestseller": ["売れ筋", "Top ventes", "Più venduto", "Más vendido", "인기 상품", "畅销", "暢銷", "Mais vendido", "Хит продаж", "Bestseller", "Çok satan", "Bestseller"],
"Best value": ["お得", "Avantageux", "Conveniente", "Más rentable", "최고 가성비", "最超值", "最超值", "Melhor custo", "Выгодно", "Najlepsza cena", "En avantajlı", "Beste waarde"],
"Popular": ["人気", "Populaire", "Popolare", "Popular", "인기", "热门", "熱門", "Popular", "Популярное", "Popularne", "Popüler", "Populair"],
"Limited": ["限定", "Limité", "Limitato", "Limitado", "한정", "限定", "限定", "Limitado", "Ограничено", "Limitowane", "Sınırlı", "Beperkt"],
"All advantages": ["すべての有利", "Tous les avantages", "Tutti i vantaggi", "Todas las ventajas", "모든 이점", "全部优势", "全部優勢", "Todas as vantagens", "Все преимущества", "Wszystkie korzyści", "Tüm avantajlar", "Alle voordelen"],
"Show the pass": ["パスを見る", "Voir le pass", "Vedi il pass", "Ver el pase", "패스 보기", "查看通行证", "查看通行證", "Ver o passe", "Открыть пропуск", "Pokaż karnet", "Pasoyu göster", "Pas bekijken"],
"Use it": ["使う", "Utiliser", "Usa", "Usar", "사용하기", "使用", "使用", "Usar", "Использовать", "Użyj", "Kullan", "Gebruiken"],
"Pay %d Riftglass": ["裂け目ガラス%dで支払う", "Payer %d Verre de Faille", "Paga %d Vetro-squarcio", "Pagar %d Vidrio Grieta", "균열유리 %d 지불", "支付%d裂隙晶", "支付%d裂晶", "Pagar %d Vidrofenda", "Оплатить %d Стекла Разлома", "Zapłać %d Szczelinitu", "%d Yarık Camı öde", "%d Kloofglas betalen"],
"After the tier before it": ["前の段階のあとで", "Après le palier d'avant", "Dopo il livello prima", "Tras el nivel anterior", "이전 단계 다음에", "先完成上一档", "先完成上一檔", "Após o nível anterior", "После прошлой ступени", "Po poprzednim progu", "Önceki kademeden sonra", "Na de vorige trap"],
"Later in the journey": ["旅の先で", "Plus tard dans le voyage", "Più avanti nel viaggio", "Más adelante en el viaje", "여행 후반에", "旅途后段开放", "旅途後段開放", "Mais adiante na jornada", "Позже в пути", "Później w podróży", "Yolculukta daha sonra", "Later op de reis"],
"Owned": ["入手済み", "Possédé", "Già tuo", "Ya es tuyo", "보유 중", "已拥有", "已擁有", "Já é seu", "Уже есть", "Masz", "Sende var", "In bezit"],
"Show": ["見る", "Voir", "Vedi", "Ver", "보기", "查看", "查看", "Ver", "Открыть", "Pokaż", "Göster", "Bekijken"],
"+%d %% bonus": ["+%d %%ボーナス", "+%d %% bonus", "+%d %% bonus", "+%d %% extra", "+%d %% 보너스", "额外+%d %%", "額外+%d %%", "+%d %% bônus", "+%d %% бонус", "+%d %% bonus", "+%d %% bonus", "+%d %% bonus"],
"First buy x2": ["初回x2", "1er achat x2", "1° acquisto x2", "1.ª compra x2", "첫 구매 x2", "首购x2", "首購x2", "1ª compra x2", "1-я покупка x2", "1. zakup x2", "İlk alım x2", "1e aankoop x2"],
"Until %s": ["%sまで", "Jusqu'au %s", "Fino al %s", "Hasta el %s", "%s까지", "截至%s", "截至%s", "Até %s", "До %s", "Do %s", "Bitiş: %s", "Tot %s"],
"A one-time pack for your journey": ["旅のための一度きりのパック", "Un lot unique pour votre voyage", "Un pacchetto unico per il tuo viaggio", "Un lote único para tu viaje", "여행을 위한 한 번뿐인 묶음", "为旅途准备的一次性礼包", "為旅途準備的一次性組合", "Um pacote único para sua jornada", "Разовый набор для вашего пути", "Jednorazowy pakiet na twoją podróż", "Yolculuğun için tek seferlik paket", "Een eenmalig pakket voor je reis"],
"Show offer": ["内容を見る", "Voir l'offre", "Vedi l'offerta", "Ver oferta", "상품 보기", "查看内容", "查看內容", "Ver oferta", "Посмотреть", "Zobacz ofertę", "Teklifi gör", "Aanbod bekijken"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table p2w_shop, written by tools/i18n/locales_p2w_shop.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "p2w_shop.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("p2w_shop: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
