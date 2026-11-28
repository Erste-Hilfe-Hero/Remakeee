#!/usr/bin/env python3
"""Translations of the German table questbook (tools/i18n/de_questbook.py) for the other 12 locales.
Writes data/i18n/<code>/questbook.json. Run: python3 tools/i18n/locales_questbook.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Quest Book": ["目標の書", "Carnet de quêtes", "Libro delle missioni", "Libro de misiones", "의뢰 수첩", "任务簿", "任務簿",
    "Livro de missões", "Книга заданий", "Księga zadań", "Görev Defteri", "Opdrachtenboek"],
"Main, side and done quests, and where to go next.": [
    "メイン、寄り道、達成した目標と、次の行き先。",
    "Quêtes principales, annexes et terminées, et où aller ensuite.",
    "Missioni principali, secondarie e completate, e dove andare dopo.",
    "Misiones principales, secundarias y completadas, y adónde ir después.",
    "메인, 서브, 완료한 의뢰와 다음 행선지.",
    "主线、支线和已完成的任务，以及下一步去哪里。",
    "主線、支線和已完成的任務，以及下一步去哪裡。",
    "Missões principais, secundárias e concluídas, e para onde ir depois.",
    "Основные, побочные и выполненные задания и куда идти дальше.",
    "Zadania główne, poboczne i ukończone oraz dokąd iść dalej.",
    "Ana, yan ve biten görevler ve sırada nereye gidileceği.",
    "Hoofd-, zij- en voltooide opdrachten, en waar je nu heen moet."],
"Where next?": ["次はどこへ?", "Et ensuite ?", "E adesso dove?", "¿Adónde ahora?", "다음은 어디로?", "下一步去哪？", "下一步去哪？",
    "Para onde agora?", "Куда дальше?", "Dokąd teraz?", "Sırada neresi?", "Waar nu heen?"],
"No quests here yet.": ["ここにはまだ目標がない。", "Aucune quête ici pour l'instant.", "Ancora nessuna missione qui.",
    "Aún no hay misiones aquí.", "아직 여기엔 의뢰가 없다.", "这里还没有任务。", "這裡還沒有任務。", "Ainda não há missões aqui.",
    "Здесь пока нет заданий.", "Na razie brak zadań.", "Burada henüz görev yok.", "Hier zijn nog geen opdrachten."],
"Main": ["メイン", "Principales", "Principali", "Principales", "메인", "主线", "主線", "Principais", "Основные", "Główne", "Ana", "Hoofd"],
"Side": ["寄り道", "Annexes", "Secondarie", "Secundarias", "서브", "支线", "支線", "Secundárias", "Побочные", "Poboczne", "Yan", "Zij"],
"To %s": ["{0}へ", "Vers %s", "Verso %s", "Hacia %s", "{0}(으)로", "前往{0}", "前往{0}", "Para %s", "В %s", "Do %s", "{0} yönüne", "Naar %s"],
"Quest goal: %s": ["目標の行き先: {0}", "But de la quête : %s", "Meta della missione: %s", "Destino de la misión: %s",
    "의뢰 목적지: {0}", "任务目的地：{0}", "任務目的地：{0}", "Destino da missão: %s", "Цель задания: %s",
    "Cel zadania: %s", "Görev hedefi: {0}", "Doel van de opdracht: %s"],
"Goal line follows this.": ["目標の行はこれを示す。", "La ligne d'objectif suit cette quête.", "La riga obiettivo segue questa missione.",
    "La línea de objetivo sigue esta misión.", "목표 줄이 이 의뢰를 따른다.", "目标栏正在追踪此任务。", "目標欄正在追蹤此任務。",
    "A linha de objetivo segue esta missão.", "Строка цели следит за этим заданием.", "Linia celu śledzi to zadanie.",
    "Hedef satırı bu görevi izliyor.", "De doelregel volgt deze opdracht."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table questbook, written by tools/i18n/locales_questbook.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "questbook.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("questbook: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
