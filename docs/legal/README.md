# Rechtliches – Übersicht

> Erstellt von einer KI auf Basis öffentlich verfügbarer Informationen (Stand: 1. November 2026), **ohne
> anwaltliche Prüfung**. Ali hat sich bewusst gegen einen Anwalt entschieden; die Restrisiken stehen in
> [CHECKLISTE_ALI.md](CHECKLISTE_ALI.md). Die Texte sind fertig formuliert. Offen sind nur Alis persönliche
> Angaben in eckigen Klammern: `[NAME]`, `[ADRESSE]`, `[E-MAIL]`, `[TELEFON]`, `[DOMAIN]`.

| Datei | Inhalt | Wo es hingehört |
| --- | --- | --- |
| [IP_PATENT_AUDIT.md](IP_PATENT_AUDIT.md) | Audit von Mechaniken, Namen, Layout und Assets, mit Status aller Funde und Namensbewertung „Chimora“ | intern |
| [DATENSCHUTZ.md](DATENSCHUTZ.md) / [PRIVACY_POLICY_EN.md](PRIVACY_POLICY_EN.md) | Datenschutzerklärung DE/EN für das Online-Spiel mit Server-Spielstand | Website, Spiel, beide Stores |
| [NUTZUNGSBEDINGUNGEN.md](NUTZUNGSBEDINGUNGEN.md) / [TERMS_EN.md](TERMS_EN.md) | Nutzungsbedingungen DE/EN (Konto, Online-only, Einstellung des Dienstes, Käufe, Haftung) | Website, Zustimmung beim ersten Start |
| [IMPRESSUM.md](IMPRESSUM.md) | Impressum nach § 5 DDG, DE/EN | Website, Spiel, beide Stores |
| [STORE_COMPLIANCE.md](STORE_COMPLIANCE.md) | Antworten für Google Data Safety, Apple App Privacy, Altersfreigabe, DSA-Händlerstatus, Kontolöschung, Store-Texte | Play Console, App Store Connect |
| [CHECKLISTE_ALI.md](CHECKLISTE_ALI.md) | Was nur Ali erledigen kann, in Reihenfolge | intern |
| [SHOP_RECHT.md](SHOP_RECHT.md) | Prüfliste für Shop-Angebote und -Texte, Regel "keine bezahlten Zufallsinhalte", verbotene Formulierungen | intern, Abnahme für Bereich 10 |
| [VERARBEITUNGEN.md](VERARBEITUNGEN.md) | Verzeichnis der Verarbeitungstätigkeiten (Art. 30 DSGVO): Zweck, Tabellen, Frist, Rechtsgrundlage, Löschläufe, TOMs | intern |

## Festgelegtes Modell (darauf beruhen alle Texte)

- Online-only, Spielstand auf unserem eigenen Server bei Contabo in Deutschland (docs/ONLINE.md).
- Konto wird beim ersten Start automatisch angelegt (zufällige Spieler-ID), Gerätewechsel per
  Übertragungscode. Keine E-Mail, kein Login über Apple/Google/Facebook.
- Wayfarer-Name nur für bestätigte Freunde sichtbar. Kein freier Chat: Grüße sind feste Sätze. Wochen-Rangliste
  zeigt Fremden nur Punkte. Blockieren und Melden im Spiel (docs/ONLINE.md).
- Keine Werbung, keine Analytics, keine Absturzberichte, keine Werbe-ID.
- Käufe (falls es welche gibt) nur über Apple/Google, keine Lootboxen.

Weicht die Umsetzung davon ab, müssen Datenschutzerklärung, Nutzungsbedingungen und Store-Antworten vorher
angepasst werden. Das Backend läuft seit 2. November 2026 auf Contabo; die versprochenen Löschfristen setzt
der tägliche Lauf `server/cleanup.sh` um (siehe VERARBEITUNGEN.md).
