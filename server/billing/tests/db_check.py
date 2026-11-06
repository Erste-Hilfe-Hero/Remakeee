"""Runs the billing service's database calls against the test database (tools/online/test_sql.sh).
Uses PGHOST/PGUSER from the environment; PGUSER is chimora_billing."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import billing  # noqa: E402

db = billing.Db()
uid = "20000000-0000-0000-0000-0000000000b2"
r = db.credit(uid, "apple", "it's-a-'quote'; drop table x;--", "de.chimora.game.glass.100", None)
assert r["ok"], r
assert db.credit(uid, "apple", "it's-a-'quote'; drop table x;--", "de.chimora.game.glass.100")["duplicate"]
assert db.sub_set(uid, "apple", "orig-1", "de.chimora.game.pass", "2026-12-06T10:00:00+00:00", "active", False)["ok"]
assert db.sub_user("apple", "orig-1") == uid
assert db.sub_user("apple", "none") is None
assert db.refund("apple", "it's-a-'quote'; drop table x;--", "test")["ok"]
print("billing database calls OK")
