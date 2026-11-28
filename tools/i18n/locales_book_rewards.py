#!/usr/bin/env python3
"""Translations of the German table book_rewards (tools/i18n/de_book_rewards.py) for the other 12 locales.
Writes data/i18n/<code>/book_rewards.json. Run: python3 tools/i18n/locales_book_rewards.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"Spirlog reward: %s!": ["Spirlogのごほうび: %s！", "Récompense du Spirlog : %s !", "Premio dello Spirlog: %s!", "¡Premio del Spirlog: %s!",
 "Spirlog 보상: %s!", "Spirlog奖励：%s！", "Spirlog獎勵：%s！", "Prêmio do Spirlog: %s!", "Награда Spirlog: %s!",
 "Nagroda Spirloga: %s!", "Spirlog ödülü: %s!", "Spirlog-beloning: %s!"],
"You received %s x%d.": ["%s x%dを受け取った。", "Tu reçois %s x%d.", "Hai ricevuto %s x%d.", "Recibes %s x%d.",
 "%s x%d을(를) 받았다.", "你获得了%s x%d。", "你獲得了%s x%d。", "Você recebeu %s x%d.", "Ты получаешь: %s x%d.",
 "Otrzymujesz: %s x%d.", "%s x%d aldın.", "Je krijgt %s x%d."],
"%d Gleam bonded": ["輝き %d 種と絆", "%d Reflets liés", "%d Splendori legati", "%d Fulgores vinculados", "광채형 %d종 유대", "已结缘%d种光泽",
 "已結緣%d種光澤", "%d Reluzentes vinculados", "Сияний связано: %d", "Związane Połyski: %d", "%d Işıltı ile bağ kuruldu", "%d glansvormen verbonden"],
"%d%% bonded": ["%d%% 絆", "%d%% liés", "%d%% legati", "%d%% vinculados", "%d%% 유대", "已结缘%d%%", "已結緣%d%%", "%d%% vinculados",
 "%d%% связано", "%d%% związane", "%%%d bağ kuruldu", "%d%% verbonden"],
"Seen: %d%% (%d/%d)": ["目撃: %d%% (%d/%d)", "Vus : %d%% (%d/%d)", "Visti: %d%% (%d/%d)", "Vistos: %d%% (%d/%d)", "목격: %d%% (%d/%d)",
 "已见：%d%%（%d/%d）", "已見：%d%%（%d/%d）", "Vistos: %d%% (%d/%d)", "Увидено: %d%% (%d/%d)", "Widziane: %d%% (%d/%d)",
 "Görüldü: %%%d (%d/%d)", "Gezien: %d%% (%d/%d)"],
"Bonded: %d%% (%d/%d)": ["絆: %d%% (%d/%d)", "Liés : %d%% (%d/%d)", "Legati: %d%% (%d/%d)", "Vinculados: %d%% (%d/%d)", "유대: %d%% (%d/%d)",
 "已结缘：%d%%（%d/%d）", "已結緣：%d%%（%d/%d）", "Vinculados: %d%% (%d/%d)", "Связано: %d%% (%d/%d)", "Związane: %d%% (%d/%d)",
 "Bağ: %%%d (%d/%d)", "Verbonden: %d%% (%d/%d)"],
"Gleam: %d%% (%d/%d)": ["輝き: %d%% (%d/%d)", "Reflet : %d%% (%d/%d)", "Splendore: %d%% (%d/%d)", "Fulgor: %d%% (%d/%d)", "광채형: %d%% (%d/%d)",
 "光泽：%d%%（%d/%d）", "光澤：%d%%（%d/%d）", "Reluzente: %d%% (%d/%d)", "Сияние: %d%% (%d/%d)", "Połysk: %d%% (%d/%d)",
 "Işıltı: %%%d (%d/%d)", "Glansvorm: %d%% (%d/%d)"],
"Book rewards: %d%% bonded, Gleam %d%%": [
 "図鑑のごほうび: 絆 %d%%、輝き %d%%",
 "Récompenses du livre : %d%% liés, Reflet %d%%",
 "Premi del libro: %d%% legati, Splendore %d%%",
 "Premios del libro: %d%% vinculados, Fulgor %d%%",
 "도감 보상: 유대 %d%%, 광채형 %d%%",
 "图册奖励：已结缘%d%%，光泽%d%%",
 "圖冊獎勵：已結緣%d%%，光澤%d%%",
 "Prêmios do livro: %d%% vinculados, Reluzente %d%%",
 "Награды книги: связано %d%%, Сияние %d%%",
 "Nagrody księgi: %d%% związane, Połysk %d%%",
 "Kitap ödülleri: %%%d bağ, Işıltı %%%d",
 "Boekbeloningen: %d%% verbonden, glansvorm %d%%"],
"(%d ready)": ["(%d 件受け取れる)", "(%d prêtes)", "(%d pronti)", "(%d listos)", "(%d개 받을 수 있음)", "（%d个可领取）", "（%d個可領取）",
 "(%d prontos)", "(готово: %d)", "(gotowe: %d)", "(%d hazır)", "(%d klaar)"],
"Keeper of Every Page": ["すべてのページの守り手", "Garde de toutes les pages", "Custode di Ogni Pagina", "Guarda de todas las páginas",
 "모든 기록의 파수꾼", "全书页守护者", "全書頁守護者", "Guarda de Todas as Páginas", "Хранитель всех страниц", "Opiekun Wszystkich Stron",
 "Tüm Sayfaların Bekçisi", "Bewaarder van elke pagina"],
"taken": ["受け取り済み", "prise", "preso", "recogido", "받음", "已领取", "已領取", "pego", "получено", "odebrane", "alındı", "genomen"],
"ready!": ["受け取れる！", "prête !", "pronto!", "¡listo!", "받을 수 있다!", "可领取！", "可領取！", "pronto!", "готово!", "gotowe!", "hazır!", "klaar!"],
"Spirlog book": ["Spirlogの本", "Livre du Spirlog", "Libro dello Spirlog", "Libro del Spirlog", "Spirlog 책", "Spirlog图册", "Spirlog圖冊",
 "Livro do Spirlog", "Книга Spirlog", "Księga Spirloga", "Spirlog kitabı", "Spirlog-boek"],
"Take a reward once its step is reached.": [
 "段階に届いたら、ごほうびを受け取ろう。",
 "Prends une récompense dès que son palier est atteint.",
 "Prendi un premio appena raggiungi il suo traguardo.",
 "Recoge un premio en cuanto alcances su etapa.",
 "단계에 도달하면 보상을 받자.",
 "达到阶段后即可领取奖励。",
 "達到階段後即可領取獎勵。",
 "Pegue um prêmio assim que a etapa for alcançada.",
 "Забери награду, как только достигнешь её ступени.",
 "Odbierz nagrodę, gdy osiągniesz jej próg.",
 "Aşamasına ulaşınca ödülünü al.",
 "Neem een beloning zodra de stap bereikt is."],
"Rewards for the share of kinds bonded and for Gleam kinds.": [
 "絆を結んだ種類の割合と、輝きの種類でもらえるごほうび。",
 "Des récompenses pour la part d'espèces liées et pour les Reflets.",
 "Premi per la quota di specie legate e per gli Splendori.",
 "Premios por la parte de especies vinculadas y por los Fulgores.",
 "유대한 종의 비율과 광채형으로 받는 보상.",
 "按已结缘种类的比例和光泽种类发放的奖励。",
 "按已結緣種類的比例和光澤種類發放的獎勵。",
 "Prêmios pela parte de espécies vinculadas e pelos Reluzentes.",
 "Награды за долю связанных видов и за Сияния.",
 "Nagrody za odsetek związanych gatunków i za Połyski.",
 "Bağ kurulan türlerin oranı ve Işıltılar için ödüller.",
 "Beloningen voor het deel verbonden soorten en voor glansvormen."],
"No connection right now. The invite is kept and sent once you are online.": [
 "いまは接続がない。招待は保存され、オンラインになったら送られる。",
 "Pas de connexion pour le moment. L'invitation est gardée et envoyée dès que tu es en ligne.",
 "Al momento non c'è connessione. L'invito viene conservato e inviato appena sei online.",
 "Ahora no hay conexión. La invitación se guarda y se envía en cuanto estés en línea.",
 "지금은 연결이 없다. 초대는 보관되었다가 온라인이 되면 보내진다.",
 "现在没有网络。邀请会先保存，联网后发送。",
 "現在沒有網路。邀請會先保存，連線後送出。",
 "Sem conexão agora. O convite é guardado e enviado assim que você estiver online.",
 "Сейчас нет связи. Приглашение сохранено и уйдёт, как только ты будешь в сети.",
 "Teraz brak połączenia. Zaproszenie zostanie zachowane i wysłane, gdy będziesz online.",
 "Şu an bağlantı yok. Davet saklanır ve çevrimiçi olunca gönderilir.",
 "Nu geen verbinding. De uitnodiging wordt bewaard en verstuurd zodra je online bent."],
"Invite of friend code %s:": ["フレンドコード%sの招待:", "Invitation du code ami %s :", "Invito del codice amico %s:", "Invitación del código de amigo %s:",
 "친구 코드 %s의 초대:", "好友码%s的邀请：", "好友碼%s的邀請：", "Convite do código de amigo %s:", "Приглашение по коду друга %s:",
 "Zaproszenie z kodu znajomego %s:", "%s arkadaş kodunun daveti:", "Uitnodiging van vriendcode %s:"],
"Of every kind in the game.": ["ゲームのすべての種類のうち。", "Sur toutes les espèces du jeu.", "Su tutte le specie del gioco.", "De todas las especies del juego.",
 "게임의 모든 종 중에서.", "占游戏中所有种类。", "佔遊戲中所有種類。", "De todas as espécies do jogo.", "Из всех видов в игре.",
 "Ze wszystkich gatunków w grze.", "Oyundaki tüm türler içinde.", "Van alle soorten in het spel."],
"Seen: %d%%": ["目撃: %d%%", "Vus : %d%%", "Visti: %d%%", "Vistos: %d%%", "목격: %d%%", "已见：%d%%", "已見：%d%%", "Vistos: %d%%", "Увидено: %d%%", "Widziane: %d%%", "Görüldü: %%%d", "Gezien: %d%%"],
"Bonded: %d%%": ["絆: %d%%", "Liés : %d%%", "Legati: %d%%", "Vinculados: %d%%", "유대: %d%%", "已结缘：%d%%", "已結緣：%d%%", "Vinculados: %d%%", "Связано: %d%%", "Związane: %d%%", "Bağ: %%%d", "Verbonden: %d%%"],
"Gleam: %d%%": ["輝き: %d%%", "Reflet : %d%%", "Splendore: %d%%", "Fulgor: %d%%", "광채형: %d%%", "光泽：%d%%", "光澤：%d%%", "Reluzente: %d%%", "Сияние: %d%%", "Połysk: %d%%", "Işıltı: %%%d", "Glansvorm: %d%%"],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table book_rewards, written by tools/i18n/locales_book_rewards.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "book_rewards.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("book_rewards: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
