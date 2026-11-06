#!/usr/bin/env python3
"""Builds the server copy of the shop offers and the store product list from data/shop.json.

Writes:
  supabase/migrations/20261110000002_shop_offers.sql  (offers for shop_buy / _shop_credit)
  store/products.json                                 (products for App Store Connect and Play Console)
Usage: python3 tools/shop/build_offers_sql.py [--check]   (--check fails if the files are out of date)
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "data/shop.json")
SQL = os.path.join(ROOT, "supabase/migrations/20261110000002_shop_offers.sql")
PRODUCTS = os.path.join(ROOT, "store/products.json")
# Store product types (item 4066): Apple / Google names.
TYPES = {"consumable": ("CONSUMABLE", "onetime"), "non_consumable": ("NON_CONSUMABLE", "onetime"),
         "subscription": ("AUTO_RENEWABLE_SUBSCRIPTION", "subscription")}

def lit(s):
    return "'" + s.replace("'", "''") + "'"

def build():
    data = json.load(open(SRC, encoding="utf-8"))
    offers = data["offers"]
    de = {}
    try:
        sys.path.insert(0, os.path.join(ROOT, "tools/i18n"))
        import de_shop
        de = de_shop.T
    except ImportError:
        pass
    rows = []
    for o in offers:
        rows.append("  (%s, %s, %s)" % (lit(o["id"]), lit(o["product_id"]), lit(json.dumps(o, ensure_ascii=False, sort_keys=True))))
    advantages = sorted(o["id"] for o in offers if o["kind"] == "advantage")
    sql = ("-- Shop offers, copied from data/shop.json by tools/shop/build_offers_sql.py. Do not edit by hand.\n"
           "insert into public.shop_offers (id, product_id, data) values\n" + ",\n".join(rows) + "\n"
           "on conflict (id) do update set product_id = excluded.product_id, data = excluded.data;\n"
           "delete from public.shop_offers where id not in (" + ", ".join(lit(o["id"]) for o in offers) + ");\n\n"
           "-- Sources the Fair League (area 7) switches off: every shop advantage (item 4925).\n"
           "insert into public.server_config (key, value) values ('league_fair_blocked_sources', " + lit(json.dumps(advantages)) + ")\n"
           "on conflict (key) do update set value = (\n"
           "  select coalesce(jsonb_agg(distinct x order by x), '[]'::jsonb)\n"
           "  from jsonb_array_elements_text(case when jsonb_typeof(public.server_config.value) = 'array' then public.server_config.value else '[]'::jsonb end || excluded.value) x);\n")
    products = []
    for o in offers:
        apple, google = TYPES[o["store_type"]]
        products.append({"product_id": o["product_id"], "offer": o["id"], "apple_type": apple, "google_type": google,
                         "eur": "%d.%02d" % (o["eur_cents"] // 100, o["eur_cents"] % 100),
                         "name_en": o["name"], "name_de": de.get(o["name"], o["name"]),
                         "desc_en": o["desc"][:200], "desc_de": de.get(o["desc"], o["desc"])[:200],
                         "ready": o["ready"]})
    prod = json.dumps({"_comment": "Store products for App Store Connect and the Play Console, built from data/shop.json by "
                       "tools/shop/build_offers_sql.py. Apple subscription group: Pass. Google subscription base plan: monthly.",
                       "products": products}, ensure_ascii=False, indent=1) + "\n"
    return sql, prod

def main():
    sql, prod = build()
    if "--check" in sys.argv:
        bad = [p for p, t in ((SQL, sql), (PRODUCTS, prod)) if not os.path.exists(p) or open(p, encoding="utf-8").read() != t]
        if bad:
            sys.exit("Out of date (run python3 tools/shop/build_offers_sql.py): " + ", ".join(os.path.relpath(p, ROOT) for p in bad))
        print("shop offers OK")
        return
    open(SQL, "w", encoding="utf-8").write(sql)
    open(PRODUCTS, "w", encoding="utf-8").write(prod)
    print("wrote", os.path.relpath(SQL, ROOT), "and", os.path.relpath(PRODUCTS, ROOT))

if __name__ == "__main__":
    main()
