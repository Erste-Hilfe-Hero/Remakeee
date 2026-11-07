#!/usr/bin/env python3
"""Writes the table of all shop offers from data/shop.json into docs/MONETIZATION.md, between the
markers <!-- shop-table:start --> and <!-- shop-table:end --> (plan items 4006, 4007).

Usage: python3 tools/shop/make_shop_table.py [--check]   (--check fails if the table is out of date)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOC = os.path.join(ROOT, "docs", "MONETIZATION.md")
START = "<!-- shop-table:start -->"
END = "<!-- shop-table:end -->"
KIND = {"advantage": "Vorteil", "cosmetic": "Kosmetik", "comfort": "Komfort", "currency": "Rissglas"}
LEAGUE = {"open": "nur Offene Liga", "look": "überall sichtbar, keine Wirkung", "none": "keine Liga-Wirkung"}


def eur(cents):
    return ("%.2f €" % (cents / 100.0)).replace(".", ",") if cents else "-"


def table(data):
    rows = ["| Kennung | Name | Euro | Rissglas | Art | Liga |", "| --- | --- | --- | --- | --- | --- |"]
    counts = {}
    for o in data["offers"]:
        kind = str(o.get("kind", ""))
        counts[kind] = counts.get(kind, 0) + 1
        rg = int(o.get("rg_price", 0) or 0)
        rows.append("| `%s` | %s | %s | %s | %s | %s |" % (
            o["id"], o.get("name", ""), eur(int(o.get("eur_cents", 0) or 0)), rg if rg else "-",
            KIND.get(kind, kind), LEAGUE.get(str(o.get("league_scope", "none")), str(o.get("league_scope", "")))))
    total = len(data["offers"])
    summary = "%d Angebote (Katalog v%d): %s." % (total, int(data.get("catalog_version", 1)), ", ".join(
        "%d %s" % (counts[k], KIND.get(k, k)) for k in sorted(counts)))
    return "\n".join([START, "", "_Erzeugt von `tools/shop/make_shop_table.py`, nicht von Hand ändern._", "", summary, ""] + rows + ["", END])


def main():
    with open(os.path.join(ROOT, "data", "shop.json"), encoding="utf-8") as f:
        data = json.load(f)
    with open(DOC, encoding="utf-8") as f:
        doc = f.read()
    new_table = table(data)
    if START in doc and END in doc:
        head, rest = doc.split(START, 1)
        tail = rest.split(END, 1)[1]
        out = head + new_table + tail
    else:
        out = doc.rstrip("\n") + "\n\n## Alle Angebote\n\n" + new_table + "\n"
    if "--check" in sys.argv:
        if out != doc:
            print("docs/MONETIZATION.md: shop table is out of date, run tools/shop/make_shop_table.py")
            sys.exit(1)
        print("shop table OK")
        return
    with open(DOC, "w", encoding="utf-8") as f:
        f.write(out)
    print("wrote the shop table into docs/MONETIZATION.md")


if __name__ == "__main__":
    main()
