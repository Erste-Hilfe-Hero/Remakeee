#!/usr/bin/env python3
"""Plain explanations of every shop offer (owner request 27 Nov 2026: a better explanation per
package), in English and the 13 shipped languages. One source for three outputs:
- the "explain" field of each offer in data/shop.json (English, the Loc key),
- the German table tools/i18n/de_shop_explain.py (imports GERMAN from here),
- data/i18n/<code>/shop_explain.json for the other 12 languages.
Run: python3 tools/i18n/shop_explain_src.py  (--check: fails when an output is stale)

Numbers come from data/shop.json, data/items.json and ShopEffects.gd. The detail view adds the
contents list, the duration, how often it can be bought and where it works (leagues) itself, so
these texts only say what the offer does. Never mention the Ring cap or difficulty modes here."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LANGS = ["en", "de", "ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]
# Sentences are joined without a space in these.
NO_SPACE = {"ja", "zh_CN", "zh_TW"}

from shop_explain_t1 import T1
from shop_explain_t2 import T2
from shop_explain_t3 import T3

T = {}
for part in (T1, T2, T3):
    for k, row in part.items():
        assert k not in T, k
        assert len(row) == len(LANGS), (k, len(row))
        T[k] = row

# Words filled into the templates, per language.
WORDS = {
"Might": ["Might", "Wucht", "腕力", "Force", "Potenza", "Fuerza", "완력", "劲力", "勁力", "Força", "Мощь", "Moc", "Kuvvet", "Macht"],
"Guard": ["Guard", "Schutz", "守備", "Garde", "Guardia", "Guardia", "수비", "守御", "守護", "Proteção", "Стойкость", "Osłona", "Siper", "Schild"],
"Focus": ["Focus", "Fokus", "集中", "Esprit", "Acume", "Enfoque", "집중", "专注", "專注", "Foco", "Фокус", "Skupienie", "Odak", "Focus"],
"Vigor": ["Vigor", "Kraft", "活力", "Vigueur", "Vigore", "Vigor", "기력", "元气", "元氣", "Vigor", "Бодрость", "Wigor", "Dinçlik", "Kracht"],
}

# offer id -> list of (template key, params). Params whose value is a WORDS key are translated.
O = {}
def add(ids, *parts):
    for i in ids if isinstance(ids, list) else [ids]:
        O[i] = list(parts)

GLASS = [(100, 0, 0), (200, 20, 10), (500, 100, 20), (1000, 300, 30), (2000, 800, 40), (5000, 2500, 50), (10000, 6000, 60)]
for base, extra, pct in GLASS:
    n = base + extra
    if extra == 0:
        add("rg_glass_%d" % base, ("glass_plain", {"n": n, "first": n + base}), ("glass_use", {}))
    else:
        add("rg_glass_%d" % base, ("glass_bonus", {"n": n, "base": base, "extra": extra, "pct": pct, "first": n + base}), ("glass_use", {}))
add("rg_ring_tonic", ("ring_one", {}))
add("rg_ring_tonic_5", ("ring_many", {"n": 5}))
add("rg_ring_tonic_10", ("ring_many", {"n": 10}))
add("rg_ring_elixir", ("ring_elixir", {}))
add("rg_ring_crown", ("ring_crown", {}))
add("rg_growth_x2", ("growth", {"m": 2}))
add("rg_growth_x3", ("growth", {"m": 3}))
add("rg_growth_x5", ("growth", {"m": 5}))
add("rg_share_band", ("share_band", {}))
add(["rg_ring_tonic_x5", "rg_overcharge_x5", "rg_spark_shard_x5"], ("pack_of", {"n": 5}))
add("rg_echo_scent_x10", ("pack_of", {"n": 10}))
add("rg_riftheart", ("held_stat", {"p": 15, "stat": "Might"}))
add("rg_glass_shield", ("held_stat", {"p": 15, "stat": "Guard"}))
add("rg_clear_shard", ("held_stat", {"p": 15, "stat": "Focus"}))
add("rg_vigor_glass", ("held_stat", {"p": 12, "stat": "Vigor"}))
add("rg_whirl_glass", ("held_whirl", {}))
SCRIPT_EXTRA = {"ember": "x_scorch", "tide": "x_soak", "bloom": "x_drain", "volt": "x_pace", "stone": "x_guard",
                "gale": "x_first", "lumen": "x_cure", "umbra": "x_focus"}
for el, extra in SCRIPT_EXTRA.items():
    add("rg_prism_" + el, ("prism", {"el": el.capitalize()}))
    add("rg_script_" + el, ("script", {"el": el.capitalize()}), (extra, {}), ("used_up", {}))
for el in ["ember", "tide", "bloom", "volt", "stone", "gale", "lumen", "umbra", "ink", "echo", "acid", "frost"]:
    add("rg_master_" + el, ("master", {"el": el.capitalize()}), ("used_up", {}))
for k in ["hold_stone", "echo_ring", "move_memory", "overcharge", "rift_breath", "rift_breath_full", "rift_breath_deep",
          "last_stand", "glass_spark", "glass_tonic", "grand_tonic", "bond_seal", "team_slot_6", "storage_box",
          "spark_forge", "spark_shard", "temper_shift", "power_core", "gleam_prism", "fast_travel", "encounter_call",
          "skip_battle", "rematch_key", "warden_lore", "rift_anchor", "warden_weaken", "merchant_discount",
          "gift_cards", "damage_preview", "minimap", "bench_lessons", "status_ward", "start_shield", "growth_plus",
          "seal_set", "shimmer_scent", "bond_retry", "unfurl_spark", "gift_slot", "team_slot_7", "radar",
          "wish_charm", "tide_pearl", "spirlog_atlas", "wild_ward", "swift_steps", "rest_anywhere", "daily_find_x3",
          "starter_trio", "monthly_card"]:
    add("rg_" + k, (k, {}))
add("rg_gift_slot", ("gift_slot", {}), ("spark_note", {}))
add("rg_echo_scent", ("bond_easier", {"p": 25}))
for i, p in enumerate([15, 30, 45, 60]):
    add("rg_bond_lure_%d" % (i + 1), ("bond_easier", {"p": p}))
add("rg_coin_boost", ("coin_boost", {"m": 2}))
add("rg_coin_boost_x3", ("coin_boost", {"m": 3}))
for n in [5000, 20000, 100000]:
    add("rg_coins_%d" % n, ("coins", {"n": n}))
add("rg_starter", ("b_starter", {}))
add("rg_wayfarer_pack", ("b_wayfarer", {}))
add("rg_battle_supply", ("b_supply", {}))
add("rg_warden_bundle", ("b_warden", {}))
add("rg_script_pack", ("b_scripts", {}))
add("rg_champion_bundle", ("b_champion", {}))
for n in range(1, 7):
    add("rg_rift_pack_%d" % n, ("b_riftpack", {"n": n}))
SEAL = {"power_seal": 10, "guard_seal": 10, "speed_seal": 7}
for s, tiers in SEAL.items():
    for t in range(1, tiers + 1):
        parts = [(s, {"p": 5 * t})]
        if t > 1:
            parts.append(("upgrade", {}))
        add("rg_%s_%d" % (s, t), *parts)
for t in range(1, 4):
    add("rg_crit_seal_%d" % t, *([("crit_seal", {"p": 5 * t})] + ([("upgrade", {})] if t > 1 else [])))
    add("rg_bond_edge_%d" % t, *([("bond_edge", {"p": 10 * t})] + ([("upgrade", {})] if t > 1 else [])))
for t, m in enumerate([2, 3, 5]):
    add("rg_lure_scent_%d" % (t + 1), ("lure_scent", {"m": m}))
for n in [1, 5, 10]:
    add("rg_stat_crystal_%d" % n, ("stat_crystal", {"n": n}))
for name in ["Velahra", "Hallowmur", "Scriptorax", "Lumivane", "Zephyrel", "Monolurk", "Vorlucent"]:
    add("rg_spirling_" + name.lower(), ("ancient", {"name": name}), ("fixed_lent", {}), ("spark_note", {}))
for name, temper in [("Fulgorath", "t_fierce"), ("Ardenthal", "t_keen"), ("Obelordan", "t_stalwart")]:
    add("rg_champion_" + name.lower(), ("champion", {"name": name}), (temper, {}), ("fixed_lent", {}), ("spark_note", {}))
for d in ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]:
    add("rg_deal_" + d, ("deal_day", {}))
for w in ["power", "bond", "battle", "growth"]:
    add("rg_week_" + w, ("deal_week", {}))
WINGS = [(2, 300, 0), (2, 360, 2), (2, 420, 4), (3, 510, 6), (3, 600, 9)]
for i, (b, total, need) in enumerate(WINGS):
    add("rg_storage_wing_%d" % (i + 1), ("storage_wing", {"s": i + 1, "b": b, "t": total, "need": need}))


def text(offer_id, li):
    lang = LANGS[li]
    out = []
    for key, params in O[offer_id]:
        p = {k: (WORDS[v][li] if isinstance(v, str) and v in WORDS else v) for k, v in params.items()}
        out.append(T[key][li].format(**p))
    return ("" if lang in NO_SPACE else " ").join(out)


def cosmetic_key(o):
    for prefix, key in [("rg_jacket_", "jacket"), ("rg_backdrop_", "backdrop"), ("rg_frame_", "frame"),
                        ("rg_hat_", "hat"), ("rg_card_frame_", "card_frame")]:
        if o["id"].startswith(prefix):
            return key
    return ""


def offers():
    return json.load(open(os.path.join(ROOT, "data/shop.json"), encoding="utf-8"))


def tables():
    """{lang: {english: text}} and {offer id: english} for every explained offer."""
    data = offers()
    out = {l: {} for l in LANGS[1:]}
    en = {}
    for o in data["offers"]:
        if not o.get("ready") or o["id"] in SKIP:
            continue
        k = cosmetic_key(o)
        if k:
            O[o["id"]] = [(k, {})]
        if o["id"] not in O:
            continue
        e = text(o["id"], 0)
        en[o["id"]] = e
        for li, l in enumerate(LANGS[1:], 1):
            out[l][e] = text(o["id"], li)
    return out, en

# The pass has its own detail page (ShopMenu.pass_text); the Ring Cap Seal leaves the shop on
# another branch (27 Nov 2026).
SKIP = {"rg_pass", "rg_ring_cap_plus"}


def german():
    return tables()[0]["de"]


def main():
    check = "--check" in sys.argv
    per_lang, en = tables()
    bad = []
    path = os.path.join(ROOT, "data/shop.json")
    raw = open(path, encoding="utf-8").read()
    data = json.loads(raw)
    for o in data["offers"]:
        if o["id"] in en:
            o["explain"] = en[o["id"]]
        elif "explain" in o:
            del o["explain"]
    new = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    files = {path: new}
    for l in LANGS[2:]:
        d = {"_comment": "Translations of the German table shop_explain, written by tools/i18n/shop_explain_src.py. "
             "Keys are the English text.", "strings": dict(sorted(per_lang[l].items()))}
        files[os.path.join(ROOT, "data/i18n", l, "shop_explain.json")] = json.dumps(d, ensure_ascii=False, indent=1) + "\n"
    for f, t in files.items():
        old = open(f, encoding="utf-8").read() if os.path.exists(f) else ""
        if old != t:
            bad.append(os.path.relpath(f, ROOT))
            if not check:
                open(f, "w", encoding="utf-8").write(t)
    if check and bad:
        sys.exit("stale, run python3 tools/i18n/shop_explain_src.py: " + ", ".join(bad))
    print("shop explanations: %d offers x %d languages%s" % (len(en), len(LANGS), (", wrote " + ", ".join(bad)) if bad and not check else ""))


if __name__ == "__main__":
    main()
