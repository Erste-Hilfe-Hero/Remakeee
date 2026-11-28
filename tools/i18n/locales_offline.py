#!/usr/bin/env python3
"""Translations of the German table offline (tools/i18n/de_offline.py) for the other 12 locales.
Writes data/i18n/<code>/offline.json. Run: python3 tools/i18n/locales_offline.py
Order per row: ja, fr, it, es, ko, zh_CN, zh_TW, pt_BR, ru, pl, tr, nl."""
import json, os

LANGS = ["ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

R = {
"This needs internet. The rest of your journey plays on offline.": [
 "これにはインターネットが必要です。ほかの旅はオフラインでも続けられます。",
 "Il faut Internet pour ça. Le reste de ton voyage continue hors ligne.",
 "Per questo serve Internet. Il resto del tuo viaggio continua offline.",
 "Para esto hace falta internet. El resto de tu viaje sigue sin conexión.",
 "이 기능은 인터넷이 필요합니다. 나머지 여행은 오프라인에서도 계속됩니다.",
 "这需要联网。你的其余旅程可以离线继续。",
 "這需要連線。你的其餘旅程可以離線繼續。",
 "Isto precisa de internet. O resto da sua jornada continua offline.",
 "Для этого нужен интернет. Остальное путешествие идёт и без него.",
 "To wymaga internetu. Reszta podróży toczy się dalej offline.",
 "Bunun için internet gerekir. Yolculuğunun geri kalanı çevrim dışı sürer.",
 "Hiervoor heb je internet nodig. De rest van je reis gaat offline door."],
"Offline. Your journey is saved on this phone.": [
 "オフラインです。旅の記録はこのスマホに保存されます。",
 "Hors ligne. Ton voyage est sauvegardé sur ce téléphone.",
 "Offline. Il tuo viaggio è salvato su questo telefono.",
 "Sin conexión. Tu viaje se guarda en este móvil.",
 "오프라인입니다. 여행 기록은 이 휴대폰에 저장됩니다.",
 "离线中。你的旅程保存在这部手机上。",
 "離線中。你的旅程存放在這支手機上。",
 "Offline. Sua jornada fica salva neste celular.",
 "Офлайн. Путешествие сохраняется на этом телефоне.",
 "Offline. Twoja podróż zapisuje się na tym telefonie.",
 "Çevrim dışı. Yolculuğun bu telefona kaydedilir.",
 "Offline. Je reis wordt op deze telefoon bewaard."],
"Online, a copy of your journeys is kept on our server. No ads, no tracking.": [
 "オンラインのときは旅の記録のコピーをサーバーに保存します。広告も追跡もありません。",
 "En ligne, une copie de tes voyages est gardée sur notre serveur. Pas de pub, pas de pistage.",
 "Online, una copia dei tuoi viaggi resta sul nostro server. Niente pubblicità, niente tracciamento.",
 "En línea, una copia de tus viajes se guarda en nuestro servidor. Sin anuncios, sin rastreo.",
 "온라인일 때는 여행 기록의 사본이 저희 서버에 저장됩니다. 광고도 추적도 없습니다.",
 "联网时，你的旅程会在我们的服务器上保存一份副本。没有广告，没有追踪。",
 "連線時，你的旅程會在我們的伺服器上存一份副本。沒有廣告，沒有追蹤。",
 "Online, uma cópia das suas jornadas fica no nosso servidor. Sem anúncios, sem rastreio.",
 "Онлайн копия твоих путешествий хранится на нашем сервере. Без рекламы и слежки.",
 "Online kopia twoich podróży jest na naszym serwerze. Bez reklam, bez śledzenia.",
 "Çevrim içiyken yolculuklarının bir kopyası sunucumuzda durur. Reklam yok, takip yok.",
 "Online staat een kopie van je reizen op onze server. Geen reclame, geen tracking."],
"Chimora plays offline too. When you are online, your journeys are also stored on our server in the EU, so they are safe if your phone breaks. Hosting: Contabo GmbH, Munich, Germany (processor, Art. 28 GDPR); server location: data centre Lauterbourg, France (EU). We store your Wayfarer name, friend code, saves, friends, Lantern Mail and league standings, nothing else. No ads, no tracking. We count anonymously how far players get in the game, to make it better. You can download or delete everything under Settings, Account.": [
 "Chimoraはオフラインでも遊べます。オンラインのときは旅の記録がEUにあるサーバーにも保存されるので、スマホがこわれても安心です。ホスティング：Contabo GmbH（ドイツ・ミュンヘン、処理者、GDPR第28条）。サーバーの所在地：フランス・ロートブールのデータセンター（EU）。保存するのは旅人の名前、フレンドコード、記録、フレンド、ランタン便、リーグの成績だけ。広告も追跡もありません。ゲームをよくするため、プレイヤーがどこまで進んだかを匿名で数えています。設定のアカウントから、すべてダウンロードや削除ができます。",
 "Chimora se joue aussi hors ligne. Quand tu es en ligne, tes voyages sont aussi stockés sur notre serveur dans l'UE, ils sont donc en sécurité si ton téléphone se casse. Hébergement : Contabo GmbH, Munich, Allemagne (sous-traitant, art. 28 RGPD) ; emplacement du serveur : centre de données de Lauterbourg, France (UE). Nous stockons ton nom de voyage, ton code ami, tes sauvegardes, tes amis, ta Poste-Lanterne et ton classement de ligue, rien d'autre. Pas de pub, pas de pistage. Nous comptons de façon anonyme jusqu'où les joueurs avancent, pour améliorer le jeu. Tu peux tout télécharger ou supprimer dans Options, Compte.",
 "Chimora funziona anche offline. Quando sei online, i tuoi viaggi sono salvati anche sul nostro server nell'UE, così sono al sicuro se il telefono si rompe. Hosting: Contabo GmbH, Monaco di Baviera, Germania (responsabile del trattamento, art. 28 GDPR); sede del server: data center di Lauterbourg, Francia (UE). Salviamo il tuo nome da Viandante, codice amico, salvataggi, amici, Posta Lanterna e classifiche di lega, nient'altro. Niente pubblicità, niente tracciamento. Contiamo in forma anonima fin dove arrivano i giocatori, per migliorare il gioco. Puoi scaricare o eliminare tutto in Opzioni, Account.",
 "Chimora también funciona sin conexión. Cuando estás en línea, tus viajes se guardan además en nuestro servidor en la UE, así que están a salvo si se te rompe el móvil. Alojamiento: Contabo GmbH, Múnich, Alemania (encargado del tratamiento, art. 28 RGPD); ubicación del servidor: centro de datos de Lauterbourg, Francia (UE). Guardamos tu nombre de Caminante, código de amigo, partidas, amistades, Correo Farol y puestos en la liga, nada más. Sin anuncios ni rastreo. Contamos de forma anónima hasta dónde llegan los jugadores, para mejorar el juego. Puedes descargarlo o borrarlo todo en Ajustes, Cuenta.",
 "Chimora는 오프라인에서도 즐길 수 있습니다. 온라인일 때는 여행 기록이 EU에 있는 저희 서버에도 저장되므로 휴대폰이 고장 나도 안전합니다. 호스팅: Contabo GmbH, 독일 뮌헨(처리자, GDPR 제28조). 서버 위치: 프랑스 로테르부르 데이터 센터(EU). 저장하는 것은 나그네 이름, 친구 코드, 저장 기록, 친구, 등불 우편, 리그 순위뿐입니다. 광고도 추적도 없습니다. 게임을 더 좋게 만들기 위해 플레이어가 어디까지 진행했는지 익명으로 집계합니다. 설정의 계정에서 모두 내려받거나 삭제할 수 있습니다.",
 "Chimora也可以离线游玩。联网时，你的旅程也会保存在我们位于欧盟的服务器上，即使手机坏了也不会丢失。托管方：Contabo GmbH，德国慕尼黑（处理者，GDPR第28条）；服务器位置：法国洛泰尔堡数据中心（欧盟）。我们只保存你的旅人名字、好友代码、存档、好友、灯信和联赛排名，别无其他。没有广告，没有追踪。为了改进游戏，我们会匿名统计玩家的游戏进度。你可以在「设置」→「账号」中下载或删除所有数据。",
 "Chimora也可以離線遊玩。連線時，你的旅程也會存放在我們位於歐盟的伺服器上，即使手機壞了也很安全。託管方：Contabo GmbH，德國慕尼黑（處理者，GDPR第28條）；伺服器位置：法國洛泰爾堡資料中心（歐盟）。我們只儲存你的旅人名稱、好友代碼、存檔、好友、燈信和聯賽排名，其他一概不存。沒有廣告，沒有追蹤。為了改進遊戲，我們會匿名統計玩家的遊戲進度。你可以在「設定」的「帳號」中下載或刪除所有資料。",
 "Chimora também funciona offline. Quando você está online, suas jornadas também ficam no nosso servidor na UE, para estarem a salvo se seu celular quebrar. Hospedagem: Contabo GmbH, Munique, Alemanha (operador, art. 28 do RGPD); local do servidor: centro de dados de Lauterbourg, França (UE). Guardamos seu nome de Viajante, código de amigo, jogos salvos, amigos, Correio Lanterna e posição nas ligas, mais nada. Sem anúncios, sem rastreamento. Contamos de forma anônima até onde os jogadores chegam, para melhorar o jogo. Você pode baixar ou apagar tudo em Configurações, Conta.",
 "В Chimora можно играть и без интернета. Когда ты онлайн, твои путешествия также хранятся на нашем сервере в ЕС, так что они в сохранности, даже если телефон сломается. Хостинг: Contabo GmbH, Мюнхен, Германия (обработчик, ст. 28 GDPR); местоположение сервера: дата-центр в Лотербуре, Франция (ЕС). Мы храним имя Странника, код друга, сохранения, друзей, Фонарную почту и места в лигах, больше ничего. Без рекламы, без слежки. Мы анонимно считаем, как далеко игроки проходят игру, чтобы сделать её лучше. Всё можно скачать или удалить в Настройки, Аккаунт.",
 "Chimora działa też offline. Gdy jesteś online, twoje podróże są też przechowywane na naszym serwerze w UE, więc są bezpieczne, nawet gdy telefon się zepsuje. Hosting: Contabo GmbH, Monachium, Niemcy (podmiot przetwarzający, art. 28 RODO); lokalizacja serwera: centrum danych Lauterbourg, Francja (UE). Przechowujemy tylko imię Wędrowca, kod znajomego, zapisy, znajomych, Pocztę Latarni i wyniki ligi, nic więcej. Bez reklam, bez śledzenia. Anonimowo liczymy, jak daleko gracze docierają w grze, aby ją ulepszać. Wszystko możesz pobrać lub usunąć w Ustawienia, Konto.",
 "Chimora çevrim dışı da oynanır. Çevrim içiyken yolculukların ayrıca AB'deki sunucumuzda saklanır, böylece telefonun bozulsa da güvende kalır. Barındırma: Contabo GmbH, Münih, Almanya (veri işleyen, GVKT md. 28); sunucu konumu: Lauterbourg veri merkezi, Fransa (AB). Yalnızca Gezgin adını, arkadaş kodunu, kayıtlarını, arkadaşlarını, Fener Postasını ve lig sıralamanı saklarız, başka hiçbir şeyi değil. Reklam yok, takip yok. Oyunu daha iyi yapmak için oyuncuların ne kadar ilerlediğini anonim olarak sayarız. Ayarlar, Hesap altında her şeyi indirebilir ya da silebilirsin.",
 "Chimora werkt ook offline. Als je online bent, staan je reizen ook op onze server in de EU, dus ze zijn veilig als je telefoon kapotgaat. Hosting: Contabo GmbH, München, Duitsland (verwerker, art. 28 AVG); serverlocatie: datacenter Lauterbourg, Frankrijk (EU). We bewaren je Reizigersnaam, vriendcode, spellen, vrienden, Lantaarnpost en competitiestand, verder niets. Geen reclame, geen tracking. We tellen anoniem hoe ver spelers in het spel komen, om het beter te maken. Onder Instellingen, Account kun je alles downloaden of wissen."],
}


def main():
    for i, code in enumerate(LANGS):
        strings = {k: v[i] for k, v in sorted(R.items())}
        data = {"_comment": "Translations of the German table offline, written by tools/i18n/locales_offline.py. "
                "Keys are the English text; keys with %s or %d are patterns.", "strings": strings}
        path = os.path.join(ROOT, "data/i18n", code, "offline.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("offline: %d strings x %d locales" % (len(R), len(LANGS)))


if __name__ == "__main__":
    main()
