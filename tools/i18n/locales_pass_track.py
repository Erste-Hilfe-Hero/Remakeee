#!/usr/bin/env python3
"""Translations of the German table pass_track (tools/i18n/de_pass_track.py) for the other 12 locales.
Writes data/i18n/<code>/pass_track.json. Run: python3 tools/i18n/locales_pass_track.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Pass track": ["パスの道", "Parcours du pass", "Percorso del pass", "Ruta del pase", "패스 길", "通行证之路", "通行證之路", "Trilha do passe", "Путь пропуска", "Ścieżka karnetu", "Paso yolu", "Paspad"],
"Step %d of %d": ["ステップ %d / %d", "Étape %d sur %d", "Tappa %d di %d", "Etapa %d de %d", "단계 %d / %d", "第%d阶，共%d阶", "第%d階，共%d階", "Etapa %d de %d", "Ступень %d из %d", "Etap %d z %d", "Aşama %d / %d", "Stap %d van %d"],
"Step %d": ["ステップ %d", "Étape %d", "Tappa %d", "Etapa %d", "단계 %d", "第%d阶", "第%d階", "Etapa %d", "Ступень %d", "Etap %d", "Aşama %d", "Stap %d"],
"Step %d: %s": ["ステップ %d: %s", "Étape %d : %s", "Tappa %d: %s", "Etapa %d: %s", "단계 %d: %s", "第%d阶：%s", "第%d階：%s", "Etapa %d: %s", "Ступень %d: %s", "Etap %d: %s", "Aşama %d: %s", "Stap %d: %s"],
"%d of %d pass points": ["パスポイント %d / %d", "%d sur %d points de pass", "%d di %d punti pass", "%d de %d puntos de pase", "패스 포인트 %d / %d", "通行证点数 %d / %d", "通行證點數 %d / %d", "%d de %d pontos de passe", "%d из %d очков пропуска", "%d z %d punktów karnetu", "%d / %d paso puanı", "%d van %d paspunten"],
"ends in %s": ["残り%s", "fin dans %s", "finisce tra %s", "termina en %s", "%s 후 종료", "%s后结束", "%s後結束", "termina em %s", "конец через %s", "koniec za %s", "%s sonra biter", "eindigt over %s"],
"Top row: free for everyone. Bottom row: with the Wayfarer Pass. Pass points come from battles won (%d), bonds (%d) and daily tasks (%d), up to %d a day.": [
 "上の列: だれでも無料。下の列: 旅人パスで。パスポイントは勝ったバトル(%d)、絆(%d)、デイリー課題(%d)でもらえる。1日に%dまで。",
 "Rangée du haut : gratuite pour tous. Rangée du bas : avec le Pass de voyage. Les points de pass viennent des combats gagnés (%d), des liens (%d) et des tâches du jour (%d), jusqu'à %d par jour.",
 "Riga in alto: gratis per tutti. Riga in basso: con il Lasciapassare Viandante. I punti pass arrivano dalle lotte vinte (%d), dai legami (%d) e dai compiti del giorno (%d), fino a %d al giorno.",
 "Fila de arriba: gratis para todos. Fila de abajo: con el Pase de Caminante. Los puntos de pase llegan con combates ganados (%d), vínculos (%d) y tareas del día (%d), hasta %d al día.",
 "윗줄: 누구나 무료. 아랫줄: 나그네 패스로. 패스 포인트는 이긴 배틀(%d), 유대(%d), 일일 과제(%d)로 얻고, 하루 %d까지.",
 "上排：所有人免费。下排：需要旅人通行证。通行证点数来自胜利的战斗（%d）、结缘（%d）和每日任务（%d），每天最多%d。",
 "上排：所有人免費。下排：需要旅人通行證。通行證點數來自勝利的戰鬥（%d）、結緣（%d）和每日任務（%d），每天最多%d。",
 "Fileira de cima: grátis para todos. Fileira de baixo: com o Passe de Viajante. Pontos de passe vêm de batalhas vencidas (%d), laços (%d) e tarefas do dia (%d), até %d por dia.",
 "Верхний ряд: бесплатно для всех. Нижний ряд: с Пропуском странника. Очки пропуска дают выигранные бои (%d), узы (%d) и задания дня (%d), до %d в день.",
 "Górny rząd: za darmo dla wszystkich. Dolny rząd: z Karnetem Wędrowca. Punkty karnetu dają wygrane walki (%d), więzi (%d) i zadania dnia (%d), do %d dziennie.",
 "Üst sıra: herkese ücretsiz. Alt sıra: Gezgin Pasosu ile. Paso puanları kazanılan savaşlardan (%d), bağlardan (%d) ve günlük görevlerden (%d) gelir, günde en fazla %d.",
 "Bovenste rij: gratis voor iedereen. Onderste rij: met de Reizigerspas. Paspunten komen van gewonnen gevechten (%d), banden (%d) en dagtaken (%d), tot %d per dag."],
"Premium row: Wayfarer Pass": ["プレミアム列: 旅人パス", "Rangée premium : Pass de voyage", "Riga premium: Lasciapassare Viandante", "Fila premium: Pase de Caminante", "프리미엄 줄: 나그네 패스", "高级排：旅人通行证", "高級排：旅人通行證", "Fileira premium: Passe de Viajante", "Премиум-ряд: Пропуск странника", "Rząd premium: Karnet Wędrowca", "Premium sıra: Gezgin Pasosu", "Premiumrij: Reizigerspas"],
"Take all rewards (%d)": ["ほうびを全部受け取る (%d)", "Prendre toutes les récompenses (%d)", "Prendi tutte le ricompense (%d)", "Tomar todas las recompensas (%d)", "보상 모두 받기 (%d)", "领取全部奖励（%d）", "領取全部獎勵（%d）", "Pegar todas as recompensas (%d)", "Забрать все награды (%d)", "Weź wszystkie nagrody (%d)", "Tüm ödülleri al (%d)", "Alle beloningen nemen (%d)"],
"The premium row needs the Wayfarer Pass.": ["プレミアム列には旅人パスが必要だ。", "La rangée premium demande le Pass de voyage.", "La riga premium richiede il Lasciapassare Viandante.", "La fila premium necesita el Pase de Caminante.", "프리미엄 줄에는 나그네 패스가 필요하다.", "高级排需要旅人通行证。", "高級排需要旅人通行證。", "A fileira premium precisa do Passe de Viajante.", "Для премиум-ряда нужен Пропуск странника.", "Rząd premium wymaga Karnetu Wędrowca.", "Premium sıra Gezgin Pasosu gerektirir.", "De premiumrij heeft de Reizigerspas nodig."],
"Something went wrong. Try again in a moment.": ["うまくいかなかった。少ししてからもう一度。", "Un problème est survenu. Réessayez dans un instant.", "Qualcosa è andato storto. Riprova tra un attimo.", "Algo salió mal. Inténtalo de nuevo en un momento.", "문제가 생겼다. 잠시 후 다시 해 보자.", "出了点问题。请稍后再试。", "出了點問題。請稍後再試。", "Algo deu errado. Tente de novo em instantes.", "Что-то пошло не так. Попробуйте чуть позже.", "Coś poszło nie tak. Spróbuj za chwilę.", "Bir sorun oldu. Birazdan yeniden dene.", "Er ging iets mis. Probeer het zo opnieuw."],
"Free:": ["無料:", "Gratuit :", "Gratis:", "Gratis:", "무료:", "免费：", "免費：", "Grátis:", "Бесплатно:", "Za darmo:", "Ücretsiz:", "Gratis:"],
"Premium (Wayfarer Pass):": ["プレミアム(旅人パス):", "Premium (Pass de voyage) :", "Premium (Lasciapassare Viandante):", "Premium (Pase de Caminante):", "프리미엄 (나그네 패스):", "高级（旅人通行证）：", "高級（旅人通行證）：", "Premium (Passe de Viajante):", "Премиум (Пропуск странника):", "Premium (Karnet Wędrowca):", "Premium (Gezgin Pasosu):", "Premium (Reizigerspas):"],
"Free: %s": ["無料: %s", "Gratuit : %s", "Gratis: %s", "Gratis: %s", "무료: %s", "免费：%s", "免費：%s", "Grátis: %s", "Бесплатно: %s", "Za darmo: %s", "Ücretsiz: %s", "Gratis: %s"],
"Premium: %s": ["プレミアム: %s", "Premium : %s", "Premium: %s", "Premium: %s", "프리미엄: %s", "高级：%s", "高級：%s", "Premium: %s", "Премиум: %s", "Premium: %s", "Premium: %s", "Premium: %s"],
"Ready to take.": ["受け取れる。", "Prête à prendre.", "Pronta da prendere.", "Lista para tomar.", "받을 수 있다.", "可以领取。", "可以領取。", "Pronta para pegar.", "Можно забрать.", "Gotowa do odebrania.", "Alınmaya hazır.", "Klaar om te nemen."],
"Taken.": ["受け取り済み。", "Prise.", "Presa.", "Tomada.", "받았다.", "已领取。", "已領取。", "Pega.", "Получено.", "Odebrana.", "Alındı.", "Genomen."],
"Locked: needs the Wayfarer Pass.": ["ロック中: 旅人パスが必要。", "Verrouillée : demande le Pass de voyage.", "Bloccata: richiede il Lasciapassare Viandante.", "Bloqueada: necesita el Pase de Caminante.", "잠김: 나그네 패스가 필요하다.", "已锁定：需要旅人通行证。", "已鎖定：需要旅人通行證。", "Bloqueada: precisa do Passe de Viajante.", "Закрыто: нужен Пропуск странника.", "Zablokowana: wymaga Karnetu Wędrowca.", "Kilitli: Gezgin Pasosu gerekir.", "Op slot: heeft de Reizigerspas nodig."],
"Reached at %d pass points.": ["パスポイント%dで到達。", "Atteinte à %d points de pass.", "Raggiunta a %d punti pass.", "Se alcanza con %d puntos de pase.", "패스 포인트 %d에 도달.", "通行证点数达到%d时解锁。", "通行證點數達到%d時解鎖。", "Alcançada com %d pontos de passe.", "Открывается при %d очках пропуска.", "Osiągana przy %d punktach karnetu.", "%d paso puanında ulaşılır.", "Bereikt bij %d paspunten."],
"%d premium rewards reached and waiting.": ["プレミアムのほうび%d個が到達済みで待っている。", "%d récompenses premium atteintes vous attendent.", "%d ricompense premium raggiunte ti aspettano.", "%d recompensas premium alcanzadas te esperan.", "도달한 프리미엄 보상 %d개가 기다린다.", "已达到%d个高级奖励，正在等待。", "已達到%d個高級獎勵，正在等待。", "%d recompensas premium alcançadas esperando.", "Достигнуто премиум-наград: %d, они ждут.", "Osiągnięte nagrody premium czekają: %d.", "Ulaşılan %d premium ödül bekliyor.", "%d bereikte premiumbeloningen wachten."],
"Opens the premium row of every step.": ["すべてのステップのプレミアム列が開く。", "Ouvre la rangée premium de chaque étape.", "Apre la riga premium di ogni tappa.", "Abre la fila premium de cada etapa.", "모든 단계의 프리미엄 줄이 열린다.", "开启每一阶的高级排。", "開啟每一階的高級排。", "Abre a fileira premium de cada etapa.", "Открывает премиум-ряд каждой ступени.", "Otwiera rząd premium każdego etapu.", "Her aşamanın premium sırasını açar.", "Opent de premiumrij van elke stap."],
"You got:": ["もらったもの:", "Vous avez reçu :", "Hai ricevuto:", "Has recibido:", "받은 것:", "你获得了：", "你獲得了：", "Você recebeu:", "Вы получили:", "Otrzymano:", "Aldıkların:", "Je kreeg:"],
"Take the free reward": ["無料のほうびを受け取る", "Prendre la récompense gratuite", "Prendi la ricompensa gratis", "Tomar la recompensa gratis", "무료 보상 받기", "领取免费奖励", "領取免費獎勵", "Pegar a recompensa grátis", "Забрать бесплатную награду", "Weź darmową nagrodę", "Ücretsiz ödülü al", "Gratis beloning nemen"],
"Take the premium reward": ["プレミアムのほうびを受け取る", "Prendre la récompense premium", "Prendi la ricompensa premium", "Tomar la recompensa premium", "프리미엄 보상 받기", "领取高级奖励", "領取高級獎勵", "Pegar a recompensa premium", "Забрать премиум-награду", "Weź nagrodę premium", "Premium ödülü al", "Premiumbeloning nemen"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table pass_track, written by tools/i18n/locales_pass_track.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "pass_track.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("pass_track: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
