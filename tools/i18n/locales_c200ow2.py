#!/usr/bin/env python3
"""Translations of the German table c200ow2 (tools/i18n/de_c200ow2.py) for the other 12 locales.
Writes data/i18n/<code>/c200ow2.json. Run: python3 tools/i18n/locales_c200ow2.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"You were here last.": ["さいごにいた場所。", "Tu étais ici la dernière fois.", "L'ultimo posto in cui eri.", "Aquí estuviste por última vez.", "마지막으로 있던 곳.", "你上次在这里。", "你上次在這裡。", "Você esteve aqui por último.", "Здесь твоя последняя остановка.", "Tu był twój ostatni postój.", "En son burada bulundun.", "Hier was je het laatst."],
"Rest point": ["休けい所", "Halte", "Punto di sosta", "Punto de descanso", "휴식처", "休息点", "休息點", "Ponto de descanso", "Место отдыха", "Miejsce odpoczynku", "Dinlenme yeri", "Rustplek"],
"No rest point found yet. Rest points show as a small cross on the map.": ["まだ休けい所が見つかっていない。休けい所は地図に小さな十字で出る。", "Aucune halte trouvée pour l'instant. Les haltes sont une petite croix sur la carte.", "Nessun punto di sosta trovato. I punti di sosta sono una piccola croce sulla mappa.", "Aún no has encontrado ningún punto de descanso. Aparecen como una pequeña cruz en el mapa.", "아직 휴식처를 찾지 못했다. 휴식처는 지도에 작은 십자로 표시된다.", "还没有找到休息点。休息点在地图上显示为小十字。", "還沒有找到休息點。休息點在地圖上顯示為小十字。", "Nenhum ponto de descanso encontrado ainda. Eles aparecem como uma pequena cruz no mapa.", "Место отдыха пока не найдено. На карте они отмечены маленьким крестиком.", "Nie znaleziono jeszcze miejsca odpoczynku. Na mapie to mały krzyżyk.", "Henüz dinlenme yeri bulunmadı. Dinlenme yerleri haritada küçük bir artı olarak görünür.", "Nog geen rustplek gevonden. Rustplekken staan als klein kruisje op de kaart."],
"There is a rest point right here, in %s.": ["ここ、%sに休けい所がある。", "Il y a une halte juste ici, à %s.", "C'è un punto di sosta proprio qui, a %s.", "Hay un punto de descanso aquí mismo, en %s.", "바로 여기, %s에 휴식처가 있다.", "这里就有休息点，在%s。", "這裡就有休息點，在%s。", "Há um ponto de descanso bem aqui, em %s.", "Место отдыха прямо здесь, в локации %s.", "Miejsce odpoczynku jest tutaj, w %s.", "Tam burada, %s içinde bir dinlenme yeri var.", "Er is hier een rustplek, in %s."],
"Nearest rest point: %s, to the %s.": ["いちばん近い休けい所: %s(%s)。", "Halte la plus proche : %s, direction %s.", "Punto di sosta più vicino: %s, verso %s.", "Punto de descanso más cercano: %s, hacia el %s.", "가장 가까운 휴식처: %s, %s쪽.", "最近的休息点：%s，在%s方。", "最近的休息點：%s，在%s方。", "Ponto de descanso mais próximo: %s, ao %s.", "Ближайшее место отдыха: %s, направление: %s.", "Najbliższe miejsce odpoczynku: %s, kierunek: %s.", "En yakın dinlenme yeri: %s, yön: %s.", "Dichtstbijzijnde rustplek: %s, richting %s."],
"north": ["北", "nord", "nord", "norte", "북", "北", "北", "norte", "север", "północ", "kuzey", "noord"],
"south": ["南", "sud", "sud", "sur", "남", "南", "南", "sul", "юг", "południe", "güney", "zuid"],
"east": ["東", "est", "est", "este", "동", "东", "東", "leste", "восток", "wschód", "doğu", "oost"],
"west": ["西", "ouest", "ovest", "oeste", "서", "西", "西", "oeste", "запад", "zachód", "batı", "west"],
"north-east": ["北東", "nord-est", "nord-est", "noreste", "북동", "东北", "東北", "nordeste", "северо-восток", "północny wschód", "kuzeydoğu", "noordoost"],
"north-west": ["北西", "nord-ouest", "nord-ovest", "noroeste", "북서", "西北", "西北", "noroeste", "северо-запад", "północny zachód", "kuzeybatı", "noordwest"],
"south-east": ["南東", "sud-est", "sud-est", "sureste", "남동", "东南", "東南", "sudeste", "юго-восток", "południowy wschód", "güneydoğu", "zuidoost"],
"south-west": ["南西", "sud-ouest", "sud-ovest", "suroeste", "남서", "西南", "西南", "sudoeste", "юго-запад", "południowy zachód", "güneybatı", "zuidwest"],
"Reset": ["リセット", "Réinitialiser", "Ripristina", "Reiniciar", "초기화", "重置", "重置", "Reiniciar", "Сбросить", "Resetuj", "Sıfırla", "Resetten"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table c200ow2, written by tools/i18n/locales_c200ow2.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "c200ow2.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("c200ow2: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
