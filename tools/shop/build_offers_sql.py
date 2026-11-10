#!/usr/bin/env python3
"""Builds the server copy of the shop offers and the store product list from data/shop.json.

Writes:
  supabase/migrations/20261110000021_shop_offers_vNNN.sql  (offers for shop_buy / _shop_credit)
  store/products.json                                 (products for App Store Connect and Play Console)
Usage: python3 tools/shop/build_offers_sql.py [--check]   (--check fails if the files are out of date)

The server applies each migration file only once (server/migrate.sh). So every catalog change gets
a new file: raise "catalog_version" in data/shop.json. A committed version file is never rewritten;
the script stops and asks for a new version instead. Version 1 is the first file without a suffix.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "data/shop.json")

def sql_path(version):
    name = "20261110000021_shop_offers.sql" if version <= 1 else "20261110000021_shop_offers_v%03d.sql" % version
    return os.path.join(ROOT, "supabase/migrations", name)

def committed(path):
    """The file's content in the last commit, or None if it is not committed."""
    rel = os.path.relpath(path, ROOT)
    r = subprocess.run(["git", "-C", ROOT, "show", "HEAD:" + rel], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None

PRODUCTS = os.path.join(ROOT, "store/products.json")
# Store product types (item 4066): Apple / Google names.
TYPES = {"consumable": ("CONSUMABLE", "onetime"), "non_consumable": ("NON_CONSUMABLE", "onetime"),
         "subscription": ("AUTO_RENEWABLE_SUBSCRIPTION", "subscription")}

def lit(s):
    return "'" + s.replace("'", "''") + "'"

def build():
    data = json.load(open(SRC, encoding="utf-8"))
    offers = data["offers"]
    version = int(data.get("catalog_version", 1))
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
    # rg_only offers are sold for Riftglass only and never become store products (Ali, 10 Nov 2026).
    for o in (o for o in offers if not o.get("rg_only")):
        apple, google = TYPES[o["store_type"]]
        products.append({"product_id": o["product_id"], "offer": o["id"], "apple_type": apple, "google_type": google,
                         "eur": "%d.%02d" % (o["eur_cents"] // 100, o["eur_cents"] % 100),
                         "name_en": o["name"], "name_de": de.get(o["name"], o["name"]),
                         "desc_en": o["desc"][:200], "desc_de": de.get(o["desc"], o["desc"])[:200],
                         # Apple Family Sharing stays off (item 4073): the server binds every Apple
                         # purchase to the buyer's account (appAccountToken), so a family member's copy
                         # would be refused. Revisit with StoreKit 2 at the end (docs/shop/ALI_TODO.md).
                         "family_shareable": False,
                         "ready": o["ready"]})
    prod = json.dumps({"_comment": "Store products for App Store Connect and the Play Console, built from data/shop.json by "
                       "tools/shop/build_offers_sql.py. Apple subscription group: Pass. Google subscription base plan: monthly.",
                       "products": products}, ensure_ascii=False, indent=1) + "\n"
    return version, sql, prod

def main():
    version, sql, prod = build()
    SQL = sql_path(version)
    old = committed(SQL)
    if old is not None and old != sql:
        sys.exit("%s is committed and may already run on the server. Raise catalog_version in data/shop.json to %d."
                 % (os.path.relpath(SQL, ROOT), version + 1))
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
