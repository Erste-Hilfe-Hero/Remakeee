"""tools/store/push_products.py without the network (plan items 4066, 4067, 4081)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import push_products as pp  # noqa: E402


def product(**kw):
    p = {"product_id": "de.chimora.game.glass.100", "offer": "rg_glass_100", "apple_type": "CONSUMABLE",
         "google_type": "onetime", "eur": "0.99", "name_en": "100 Riftglass", "name_de": "100 Rissglas",
         "desc_en": "Exactly 100 Riftglass.", "desc_de": "Genau 100 Rissglas.", "ready": True}
    p.update(kw)
    return p


PASS = product(product_id="de.chimora.game.pass", google_type="subscription", eur="4.99",
               name_en="Wayfarer Pass", name_de="Wanderer-Pass")


class FakePlay:
    def __init__(self, existing=()):
        self.calls = []
        self.existing = set(existing)

    def __call__(self, method, path, body):
        self.calls.append((method, path, body))
        if method == "GET":
            if path.split("/")[-1] in self.existing:
                return {}
            raise Exception("unknown_purchase")
        if path == "/pricing:convertRegionPrices":
            return {"convertedRegionPrices": {
                "DE": {"regionCode": "DE", "price": {"currencyCode": "EUR", "units": "5", "nanos": 0}},
                "US": {"regionCode": "US", "price": {"currencyCode": "USD", "units": "5", "nanos": 490000000}}},
                "convertedOtherRegionsPrice": {"usdPrice": {"currencyCode": "USD", "units": "5"},
                                               "eurPrice": {"currencyCode": "EUR", "units": "5"}}}
        return {}


class PushProductsTest(unittest.TestCase):
    def test_real_list_is_valid(self):
        self.assertEqual(pp.problems(pp.load()), [])

    def test_problems(self):
        self.assertEqual(pp.problems([product()]), [])
        bad = pp.problems([product(eur="1.50"), product(name_en="x" * 56), product(product_id="com.other.x"),
                           product(google_type="lootbox")])
        self.assertEqual(len(bad), 6, bad)  # four faults plus the same id listed twice more

    def test_prices(self):
        self.assertEqual(pp.micros("0.99"), "990000")
        self.assertEqual(pp.micros("49.99"), "49990000")
        self.assertEqual(pp.money("4.99"), {"currencyCode": "EUR", "units": "4", "nanos": 990000000})

    def test_dry_run_sends_nothing_and_skips_unready(self):
        lines = []
        n = pp.Pusher(None, lines.append).push([product(), product(product_id="de.chimora.game.glass.200", ready=False)])
        self.assertEqual(n, 1)
        self.assertEqual(lines[-1], "1 products would be sent.")

    def test_one_time_product_body(self):
        fake = FakePlay()
        pp.Pusher(fake, lambda s: None).push([product()])
        method, path, body = fake.calls[0]
        self.assertEqual(method, "PUT")
        self.assertIn("allowMissing=true", path)
        self.assertIn("autoConvertMissingPrices=true", path)
        self.assertEqual(body["defaultPrice"], {"priceMicros": "990000", "currency": "EUR"})
        self.assertEqual(body["listings"]["de-DE"]["title"], "100 Rissglas")
        self.assertEqual(body["status"], "active")

    def test_pass_is_created_with_fixed_euro_price_and_activated(self):
        fake = FakePlay()
        pp.Pusher(fake, lambda s: None).push([PASS])
        paths = [(m, p) for m, p, _ in fake.calls]
        self.assertIn(("POST", "/subscriptions?productId=de.chimora.game.pass&regionsVersion.version=2022/02"), paths)
        self.assertEqual(paths[-1], ("POST", "/subscriptions/de.chimora.game.pass/basePlans/monthly:activate"))
        body = [b for m, p, b in fake.calls if p.startswith("/subscriptions?")][0]
        plan = body["basePlans"][0]
        self.assertEqual(plan["autoRenewingBasePlanType"]["billingPeriodDuration"], "P1M")
        prices = {r["regionCode"]: r["price"] for r in plan["regionalConfigs"]}
        self.assertEqual(prices["DE"], pp.money("4.99"), "euro countries keep the exact price")
        self.assertEqual(prices["US"]["currencyCode"], "USD")

    def test_existing_pass_is_updated(self):
        fake = FakePlay(existing={"de.chimora.game.pass"})
        pp.Pusher(fake, lambda s: None).push([PASS])
        self.assertTrue(any(m == "PATCH" for m, _, _ in fake.calls))
        self.assertFalse(any(p.startswith("/subscriptions?") for _, p, _ in fake.calls))


if __name__ == "__main__":
    unittest.main()
