"""Builds the small public website the stores need, from the Markdown texts in docs/legal/.

The pages are served by the game server's Caddy (server/Caddyfile, folder server/site/):
  /impressum            Impressum + imprint            (IMPRESSUM.md)
  /datenschutz          Datenschutzerklärung           (DATENSCHUTZ.md)        store: privacy policy URL
  /privacy              Privacy policy (English)       (PRIVACY_POLICY_EN.md)
  /nutzungsbedingungen  Nutzungsbedingungen            (NUTZUNGSBEDINGUNGEN.md)
  /terms                Terms (English)                (TERMS_EN.md)
  /konto-loeschen       Konto löschen + English        (KONTO_LOESCHEN.md)     Google Play: account deletion URL
  /delete-account       same page
  /support              Hilfe und Kontakt + English    (SUPPORT.md)            Apple: support URL
  /lizenzen             Godot and third-party licences (server/site/licences.txt, see --licences)
  /info                 overview with links to all of the above

Run from the repo root after changing a text:  python3 tools/site/build_site.py
Use --check in CI: fails when the committed pages are out of date.
Placeholders such as [NAME] or [E-MAIL] stay visible until Ali fills them in docs/legal/.
"""
from __future__ import annotations

import html
import os
import re
import sys

SRC = "docs/legal"
# Address of the site until Ali has an own domain; [DOMAIN] in the texts becomes this.
SITE_DOMAIN = os.environ.get("CHIMORA_DOMAIN", "chimora.161-97-102-171.sslip.io")
OUT = "server/site"
PAGES = [
    ("impressum", "IMPRESSUM.md", "Impressum", "de"),
    ("datenschutz", "DATENSCHUTZ.md", "Datenschutz", "de"),
    ("privacy", "PRIVACY_POLICY_EN.md", "Privacy policy", "en"),
    ("nutzungsbedingungen", "NUTZUNGSBEDINGUNGEN.md", "Nutzungsbedingungen", "de"),
    ("terms", "TERMS_EN.md", "Terms of use", "en"),
    ("konto-loeschen", "KONTO_LOESCHEN.md", "Konto löschen", "de"),
    ("delete-account", "KONTO_LOESCHEN.md", "Delete account", "en"),
    ("support", "SUPPORT.md", "Hilfe und Kontakt", "de"),
]
PLACEHOLDER = re.compile(r"\[(NAME|ADRESSE|ADDRESS|E-MAIL|EMAIL|TELEFON|PHONE|DOMAIN|USt-IdNr[^\]]*)\]")

CSS = """
:root{--bg:#f2e3c2;--fg:#2a1e2c;--mid:#6a4256;--acc:#c48a5e}
@media (prefers-color-scheme:dark){:root{--bg:#2a1e2c;--fg:#f2e3c2;--mid:#c48a5e;--acc:#c48a5e}}
body{background:var(--bg);color:var(--fg);font:16px/1.55 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
margin:0;padding:24px 16px}main{max-width:760px;margin:0 auto}a{color:var(--mid)}
h1{font-size:1.6em;margin-top:1.4em}h2{font-size:1.25em;margin-top:1.4em}h3{font-size:1.05em}
table{border-collapse:collapse;width:100%;font-size:.95em}td,th{border:1px solid var(--acc);padding:6px;text-align:left;vertical-align:top}
hr{border:0;border-top:2px dashed var(--acc);margin:2em 0}nav{font-size:.9em;margin-bottom:1em}
code{background:rgba(196,138,94,.2);padding:0 3px;border-radius:3px}
""".strip()


def inline(text: str) -> str:
    t = html.escape(text, quote=False)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![*\w])\*([^*\s][^*]*)\*(?!\w)", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", lambda m: '<a href="%s">%s</a>' % (link(m.group(2)), m.group(1)), t)
    return t


def link(target: str) -> str:
    """Links between the legal Markdown files become links between the pages."""
    for slug, src, _t, _l in PAGES:
        if target == src or target.endswith("/" + src):
            return "/" + slug
    return target


def md_to_html(md: str) -> str:
    md = re.sub(r"<!--.*?-->", "", md, flags=re.S)
    out: list[str] = []
    para: list[str] = []
    lists: list[str] = []  # stack of "ul"/"ol"
    table: list[list[str]] = []

    def flush_para() -> None:
        if para:
            # Wrapped prose lines are long; short lines (addresses, contact blocks) keep their breaks.
            text = para[0]
            for prev, cur in zip(para, para[1:]):
                text += ("\x00" if len(prev) < 70 else " ") + cur
            out.append("<p>" + inline(text).replace("\x00", "<br>\n") + "</p>")
            para.clear()

    def flush_lists() -> None:
        while lists:
            out.append("</li></%s>" % lists.pop())

    def flush_table() -> None:
        if table:
            rows = [r for r in table if not all(re.fullmatch(r":?-{3,}:?", c.strip()) for c in r)]
            out.append("<table>")
            for i, r in enumerate(rows):
                tag = "th" if i == 0 else "td"
                out.append("<tr>" + "".join("<%s>%s</%s>" % (tag, inline(c.strip()), tag) for c in r) + "</tr>")
            out.append("</table>")
            table.clear()

    for raw in md.splitlines():
        line = raw.rstrip()
        if line.startswith("|"):
            flush_para()
            flush_lists()
            table.append(line.strip("|").split("|"))
            continue
        flush_table()
        m_h = re.match(r"(#{1,4})\s+(.*)", line)
        m_li = re.match(r"(\s*)([-*]|\d+\.)\s+(.*)", line)
        if not line.strip():
            flush_para()
            continue
        if line.strip() == "---":
            flush_para()
            flush_lists()
            out.append("<hr>")
        elif m_h:
            flush_para()
            flush_lists()
            n = len(m_h.group(1))
            out.append("<h%d>%s</h%d>" % (n, inline(m_h.group(2)), n))
        elif m_li:
            flush_para()
            depth = len(m_li.group(1)) // 2 + 1
            kind = "ol" if m_li.group(2)[0].isdigit() else "ul"
            item = re.sub(r"^\[[ xX]\]\s*", "", m_li.group(3))
            if len(lists) < depth:
                lists.append(kind)
                out.append("<%s><li>%s" % (kind, inline(item)))
            else:
                while len(lists) > depth:
                    out.append("</li></%s>" % lists.pop())
                out.append("</li><li>%s" % inline(item))
        elif lists and raw.startswith("  "):
            out[-1] += " " + inline(line.strip())
        elif line.startswith(">"):
            flush_para()
            out.append("<blockquote>%s</blockquote>" % inline(line.lstrip("> ")))
        else:
            flush_lists()
            para.append(line.strip())
    flush_para()
    flush_lists()
    flush_table()
    return "\n".join(out)


def page(title: str, lang: str, body: str) -> str:
    nav = ('<nav><a href="/info">Chimora</a> · <a href="/impressum">Impressum</a> · '
           '<a href="/datenschutz">Datenschutz</a> · <a href="/privacy">Privacy</a> · '
           '<a href="/support">Support</a></nav>')
    return ('<!doctype html>\n<html lang="%s"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>%s · Chimora</title><style>%s</style></head>\n<body><main>%s\n%s\n</main></body></html>\n'
            % (lang, html.escape(title), CSS, nav, body))


def split_lang(md: str, lang: str) -> str:
    """KONTO_LOESCHEN.md holds German first, English after the last '---'."""
    parts = re.split(r"\n---\n", md)
    return parts[-1] if lang == "en" and len(parts) > 1 else parts[0]


def build() -> dict[str, str]:
    files: dict[str, str] = {}
    for slug, src, title, lang in PAGES:
        md = open(os.path.join(SRC, src), encoding="utf-8").read()
        if src == "KONTO_LOESCHEN.md":
            md = split_lang(md, lang)
        md = md.replace("[DOMAIN]", SITE_DOMAIN)
        files[slug + ".html"] = page(title, lang, md_to_html(md))
    lic_path = os.path.join(OUT, "licences.txt")
    lic = open(lic_path, encoding="utf-8").read() if os.path.exists(lic_path) else "Godot Engine (MIT licence)."
    files["lizenzen.html"] = page("Lizenzen", "en", "<h1>Licences</h1><p>Chimora is made with the Godot Engine. "
                                  "These are the licences of the engine and the parts it contains.</p><pre style=\"white-space:pre-wrap\">"
                                  + html.escape(lic) + "</pre>")
    links = "".join('<li><a href="/%s">%s</a></li>' % (s, html.escape(t)) for s, _f, t, _l in PAGES)
    files["info.html"] = page("Chimora", "de", "<h1>Chimora</h1><p>Ein Retro-Pixel-Abenteuer für iOS und Android. "
                              "A retro pixel adventure for iOS and Android.</p><ul>%s<li><a href=\"/lizenzen\">Lizenzen</a></li>"
                              "<li><a href=\"/play/\">Im Browser testen / play test in the browser</a></li></ul>" % links)
    return files


def main() -> None:
    check = "--check" in sys.argv
    files = build()
    stale = []
    os.makedirs(OUT, exist_ok=True)
    for name, text in files.items():
        path = os.path.join(OUT, name)
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old != text:
            stale.append(name)
            if not check:
                open(path, "w", encoding="utf-8").write(text)
    left = sorted({m.group(0) for t in files.values() for m in PLACEHOLDER.finditer(t)})
    if left:
        print("placeholders still open (fill them in docs/legal/):", ", ".join(left))
    if check and stale:
        print("server/site is out of date, run python3 tools/site/build_site.py:", ", ".join(stale))
        sys.exit(1)
    print("site pages:", len(files), "(changed: %d)" % len(stale))


if __name__ == "__main__":
    main()
