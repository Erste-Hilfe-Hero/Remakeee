#!/usr/bin/env python3
"""Translations of the German table kampf_k31 (tools/i18n/de_kampf_k31.py) for the other 12 locales.
Writes data/i18n/<code>/kampf_k31.json. Run: python3 tools/i18n/locales_kampf_k31.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"%s calls %s to its side. Nobody asked the guard.": [
 "{0}は{1}をそばに呼んだ。見張りの意見は聞かれなかった。", "%s appelle %s à ses côtés. Personne n'a demandé l'avis du garde.",
 "%s chiama %s al suo fianco. Nessuno ha chiesto alla guardia.", "%s llama a %s a su lado. Nadie le preguntó al guardián.",
 "{0}이(가) {1}을(를) 곁으로 불렀다. 호위에게 묻는 이는 없었다.", "%s把%s唤到身边。没人问过护卫的意见。", "%s把%s喚到身邊。沒人問過護衛的意見。",
 "%s chama %s para o seu lado. Ninguém perguntou ao guarda.", "%s зовёт %s к себе. Стража никто не спрашивал.",
 "%s wzywa %s do swojego boku. Nikt nie pytał strażnika.", "{0}, {1} adlı Spirling'i yanına çağırıyor. Muhafıza soran olmadı.",
 "%s roept %s naar zijn zijde. Niemand vroeg het de wachter."],
"Rift hearts": ["裂け目の心臓", "Cœurs de faille", "Cuori del Varco", "Corazones de la Grieta", "균열의 심장", "裂隙之心", "裂隙之心",
 "Corações da Fenda", "Сердца Разлома", "Serca Szczeliny", "Yarık kalpleri", "Rifthartes"],
"Which heart?": ["どの心臓？", "Quel cœur?", "Quale cuore?", "¿Qué corazón?", "어느 심장?", "哪颗心？", "哪顆心？", "Qual coração?",
 "Какое сердце?", "Które serce?", "Hangi kalp?", "Welk hart?"],
"%s (won %d times)": ["{0}（{1}回勝利）", "%s (vaincu %d fois)", "%s (sconfitto %d volte)", "%s (vencido %d veces)", "{0} ({1}번 승리)",
 "%s（胜利%d次）", "%s（勝利%d次）", "%s (vencido %d vezes)", "%s (побед: %d)", "%s (pokonane %d razy)", "%s (%d kez yenildi)", "%s (%d keer verslagen)"],
"Heart rush (best %d of %d)": ["心臓ラッシュ（最高 {0}/{1}）", "Ruée des cœurs (record %d sur %d)", "Corsa dei cuori (record %d su %d)",
 "Carrera de corazones (récord %d de %d)", "심장 러시 (최고 {0}/{1})", "心脏连战（最佳 %d/%d）", "心臟連戰（最佳 %d/%d）",
 "Corrida de corações (recorde %d de %d)", "Гонка сердец (рекорд %d из %d)", "Pogoń serc (rekord %d z %d)", "Kalp koşusu (en iyi %d/%d)",
 "Hartenjacht (beste %d van %d)"],
"The mended heart still beats in the Rift's echo. It remembers you, and it is not grateful.": [
 "癒えた心臓は今も裂け目のこだまの中で脈打つ。君を覚えている。感謝はしていない。",
 "Le cœur réparé bat encore dans l'écho de la faille. Il se souvient de toi, et il n'est pas reconnaissant.",
 "Il cuore rammendato batte ancora nell'eco del Varco. Si ricorda di te, e non è grato.",
 "El corazón remendado aún late en el eco de la Grieta. Te recuerda, y no está agradecido.",
 "고쳐진 심장은 아직 균열의 메아리 속에서 뛴다. 너를 기억한다. 고마워하지는 않는다.",
 "修补过的心仍在裂隙的回响中跳动。它记得你，而且并不感激。", "修補過的心仍在裂隙的迴響中跳動。它記得你，而且並不感激。",
 "O coração remendado ainda bate no eco da Fenda. Ele se lembra de você, e não está grato.",
 "Залатанное сердце всё ещё бьётся в эхе Разлома. Оно помнит тебя, и благодарности в нём нет.",
 "Załatane serce wciąż bije w echu Szczeliny. Pamięta cię i wcale nie jest wdzięczne.",
 "Onarılan kalp hâlâ Yarık'ın yankısında atıyor. Seni hatırlıyor ve minnettar değil.",
 "Het gelapte hart klopt nog in de echo van de Rift. Het herinnert zich jou, en dankbaar is het niet."],
"Every mended heart, one after another. No rest in between: your team keeps its wounds. Begin?": [
 "癒えた心臓すべてと、続けて戦う。合間に休みはない。チームの傷はそのまま。始める？",
 "Chaque cœur réparé, l'un après l'autre. Aucun repos entre deux: ton équipe garde ses blessures. On commence?",
 "Ogni cuore rammendato, uno dopo l'altro. Nessuna pausa: la tua squadra si tiene le ferite. Si comincia?",
 "Cada corazón remendado, uno tras otro. Sin descanso: tu equipo conserva sus heridas. ¿Empezamos?",
 "고쳐진 심장 모두와 연달아 싸운다. 중간에 쉬지 않는다. 팀은 상처를 그대로 안고 간다. 시작할까?",
 "所有修补过的心，一个接一个。中间没有休息：你的队伍会带着伤继续。开始吗？",
 "所有修補過的心，一個接一個。中間沒有休息：你的隊伍會帶著傷繼續。開始嗎？",
 "Cada coração remendado, um após o outro. Sem descanso: sua equipe mantém as feridas. Começar?",
 "Все залатанные сердца, одно за другим. Без отдыха: команда сохраняет раны. Начинаем?",
 "Każde załatane serce, jedno po drugim. Bez odpoczynku: drużyna zachowuje rany. Zaczynamy?",
 "Onarılan her kalp, art arda. Arada dinlenme yok: takımın yaralarını taşır. Başlayalım mı?",
 "Elk gelapt hart, het een na het ander. Geen rust ertussen: je team houdt zijn wonden. Beginnen?"],
"Heart %d of %d is next. It heard the last one stop.": [
 "次は心臓 {0}/{1}。前のが止まる音を聞いていた。", "Cœur %d sur %d, au suivant. Il a entendu le dernier s'arrêter.",
 "Tocca al cuore %d su %d. Ha sentito l'ultimo fermarsi.", "Sigue el corazón %d de %d. Oyó cómo se detenía el anterior.",
 "다음은 심장 {0}/{1}. 앞의 심장이 멈추는 소리를 들었다.", "下一颗：第%d颗，共%d颗。它听见了上一颗停下。", "下一顆：第%d顆，共%d顆。它聽見了上一顆停下。",
 "Próximo: coração %d de %d. Ele ouviu o último parar.", "Следующее сердце: %d из %d. Оно слышало, как остановилось прошлое.",
 "Następne serce: %d z %d. Słyszało, jak poprzednie stanęło.", "Sıradaki kalp %d/%d. Bir öncekinin durduğunu duydu.",
 "Hart %d van %d is aan de beurt. Het hoorde het vorige stoppen."],
"Heart rush: %d of %d hearts.": ["心臓ラッシュ：{0}/{1}。", "Ruée des cœurs: %d cœurs sur %d.", "Corsa dei cuori: %d cuori su %d.",
 "Carrera de corazones: %d de %d corazones.", "심장 러시: {0}/{1}.", "心脏连战：%d/%d颗。", "心臟連戰：%d/%d顆。",
 "Corrida de corações: %d de %d corações.", "Гонка сердец: %d из %d.", "Pogoń serc: %d z %d serc.", "Kalp koşusu: %d/%d kalp.",
 "Hartenjacht: %d van %d harten."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table kampf_k31, written by tools/i18n/locales_kampf_k31.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "kampf_k31.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("kampf_k31: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
