# Shop: Testplan mit Testkonten (Punkt 4322)

Automatisch (jede CI): `tests/unit/test_shop_catalog.gd`, `tests/unit/test_shop_server.gd` (Testserver +
Test-Store), `tools/online/sql_test/test_shop.sql` (echte Server-Funktionen), `tools/ip_check.sh` (verbotene
Kaufaufforderungen), `tools/shop/build_offers_sql.py --check`.

Von Hand vor jedem Release mit Shop-Änderungen:

## Testkonten

- **iOS:** In App Store Connect unter Benutzer und Zugriff → Sandbox → Testkonto anlegen (eigene
  E-Mail-Adresse, nicht die echte Apple-ID). Auf dem iPhone: Einstellungen → Entwickler → Sandbox-Konto.
- **Android:** Play Console → Einstellungen → Lizenztests → Gmail-Adresse eintragen. Testkäufe kosten dann
  nichts und Abos verlängern sich alle 5 Minuten.

## Ablauf je Plattform

1. Neues Konto im Spiel, Shop öffnen: Altersabfrage erscheint. Jahr für 10 Jahre wählen → Shop gesperrt,
   Menü zeigt "Shop (gesperrt)". Neu installieren (neues Konto).
2. Alter 14: Monatslimit 15 €. 1000 Rissglas kaufen (9,99 €), zweiter Kauf startet nicht ("Monatslimit").
3. Alter 30: jedes Rissglas-Paket einmal kaufen. Guthaben stimmt, "Meine Käufe" zeigt alle.
4. Jedes Angebot mit Rissglas kaufen; Gegenstände liegen in der Tasche, dauerhafte Inhalte sind freigeschaltet.
5. Jedes Angebot direkt im Store kaufen (Euro-Preis aus dem Store).
6. Flugmodus während der Prüfung: Kauf bleibt offen, nach dem Wiederverbinden gutgeschrieben, kein Doppel.
7. **Erstattung:** iOS über die Sandbox-Einstellungen bzw. Android in der Play Console → Bestellungen →
   Erstatten. Nach der Benachrichtigung ist das Rissglas abgezogen, der Shop bei Minus gesperrt.
8. **Wanderer-Pass:** abschließen (7 Tage Probezeit), Verlängerung abwarten, kündigen, Ablauf: Vorteile enden.
9. **Wiederherstellen:** App löschen, mit Übertragungscode zurück, "Käufe wiederherstellen" → dauerhafte
   Inhalte und Pass sind da.
10. Konto löschen: Guthaben und Käufe sind auf dem Server weg.
