# Rechtliche Absicherung – Übersicht

> **Keine Rechtsberatung.** Alle Dateien in diesem Ordner sind Entwürfe und Arbeitshilfen, erstellt von einer KI
> auf Basis öffentlich verfügbarer Informationen (Stand: 1. November 2026). Sie ersetzen keine Prüfung durch eine
> Rechtsanwältin oder einen Rechtsanwalt (Games-/IT-Recht, Datenschutz) bzw. eine Patentanwältin oder einen
> Patentanwalt. Vor dem Launch muss jede Datei von einem Profi geprüft und an die tatsächliche Technik angepasst
> werden. Platzhalter stehen in `[ECKIGEN KLAMMERN]`.

| Datei | Inhalt | Wo es später hingehört |
| --- | --- | --- |
| [IP_PATENT_AUDIT.md](IP_PATENT_AUDIT.md) | Audit von Spiel, Namen, Mechaniken und Assets auf Patent-, Marken- und Urheberrechtsrisiken, mit Ampel und Änderungsvorschlägen | intern |
| [DATENSCHUTZ.md](DATENSCHUTZ.md) | Datenschutzerklärung (Deutsch) für das geplante Online-Spiel mit Server-Spielständen | Website + Link im Spiel + beide Stores |
| [PRIVACY_POLICY_EN.md](PRIVACY_POLICY_EN.md) | Englische Fassung der Datenschutzerklärung | Website + Stores außerhalb DE |
| [NUTZUNGSBEDINGUNGEN.md](NUTZUNGSBEDINGUNGEN.md) | Nutzungsbedingungen (AGB) für Konto, Online-Dienst, Käufe und Einstellung des Dienstes | Website + Zustimmung beim ersten Start |
| [IMPRESSUM.md](IMPRESSUM.md) | Impressum nach § 5 DDG (Vorlage) | Website + im Spiel unter „Rechtliches“ |
| [STORE_COMPLIANCE.md](STORE_COMPLIANCE.md) | Ausfüllhilfen: Google Data Safety, Apple Privacy Label, Privacy Manifest, Altersfreigabe (IARC/Apple), DSA-Händlerstatus, Kontolöschung, Store-Texte | Play Console / App Store Connect |
| [CHECKLISTE_ALI.md](CHECKLISTE_ALI.md) | Was nur Ali selbst erledigen kann (Anwalt, Markenanmeldung, Gewerbe, Store-Konten …), in Reihenfolge | intern |

## Wichtige Annahmen

1. **Online-only ist geplant, aber noch nicht gebaut.** Der aktuelle Code (Stand M5) speichert nur lokal in
   `user://` und hat keinen Netzwerkcode. Die Datenschutzerklärung und die Store-Formulare beschreiben das
   *geplante* Online-Modell (Konto + Server-Spielstand). Sobald Backend, Hoster und Login-Methode feststehen,
   müssen die Platzhalter ersetzt und die Formulare neu geprüft werden. Bis dahin gilt AGENTS.md Regel 4:
   keine Analytics-, Werbe- oder Netzwerk-SDKs ohne Alis OK.
2. **Verkäufer ist Ali als Einzelunternehmer mit Sitz in Deutschland.** Bei Gründung einer UG/GmbH ändern sich
   Impressum, Verantwortlicher und Vertragspartner.
3. **Monetarisierung ist offen.** Die Texte decken Kauf-App und In-App-Käufe über Apple/Google ab, aber
   **keine** zufallsbasierten Bezahl-Items (Lootboxen) und **keine** Werbung. Kommt eines davon dazu, braucht es
   neue Texte und eine neue Altersfreigabe.
4. **Kein Chat und keine nutzergenerierten Inhalte zum Launch.** Spielernamen, die andere sehen können, wären
   bereits nutzergenerierte Inhalte (siehe STORE_COMPLIANCE.md, Abschnitt DSA).
