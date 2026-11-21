"""tools/store/listing_check.py (plan Chimora 100, item 98)."""
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import listing_check as lc  # noqa: E402


def kw_errors(kw, name="Chimora: Monster Taming RPG", subtitle="Collect 497 pixel creatures"):
    errors = []
    lc.check_keywords("en-US", kw, name, subtitle, errors)
    return errors


class ListingCheck(unittest.TestCase):
    def test_repo_listings_pass(self):
        self.assertEqual(lc.check(), [])

    def test_keywords_rules(self):
        self.assertEqual(kw_errors("tamer,retro,8bit"), [])
        self.assertTrue(kw_errors("turn based,retro"))  # space
        self.assertTrue(kw_errors("retro,,dark"))  # empty item
        self.assertTrue(kw_errors("retro,Retro"))  # twice
        self.assertTrue(kw_errors("retro,monster"))  # already in the name
        self.assertTrue(kw_errors("retro,pixel"))  # already in the subtitle
        self.assertTrue(kw_errors("retro,chimora"))
        self.assertTrue(kw_errors("retro,offline"))

    def test_cjk_keywords(self):
        errors = []
        lc.check_keywords("ja", "収集,ドット絵", "Chimora：モンスター育成RPG", "497体を仲間にするドット絵冒険", errors)
        self.assertEqual(len(errors), 1)

    def test_broken_listing_is_caught(self):
        tmp = tempfile.mkdtemp()
        try:
            shutil.copytree(os.path.join(lc.ROOT, "store"), os.path.join(tmp, "store"),
                            ignore=shutil.ignore_patterns("*.png", "*.import"))
            base = os.path.join(tmp, "store/ios/metadata/en-GB/")
            with open(base + "subtitle.txt", "w", encoding="utf-8") as f:
                f.write("Bond Spirlings, trust no one")
            with open(base + "promotional_text.txt", "w", encoding="utf-8") as f:
                f.write("x" * 171)
            with open(os.path.join(tmp, "store/ios/metadata/en-AU/keywords.txt"), "w", encoding="utf-8") as f:
                f.write("tamer,strategy")  # tamer is in en-GB, indexed in the same storefront
            with open(os.path.join(tmp, "store/android/de-DE/short_description.txt"), "w", encoding="utf-8") as f:
                f.write("Wie Temtem, nur dunkler.")
            os.remove(os.path.join(tmp, "store/ios/in_app_events/ko/name.txt"))
            caps = os.path.join(tmp, "store/ios/screenshot_captions/")
            with open(caps + "ja.txt", "w", encoding="utf-8") as f:
                f.write("\n".join(["ok"] * 7 + ["Join our Discord"]))
            with open(caps + "pl.txt", "w", encoding="utf-8") as f:
                f.write("\n".join(["ok"] * 6))
            os.remove(caps + "tr.txt")
            text = "\n".join(lc.check(tmp))
            self.assertIn("ja.txt: 'Join our Discord': no prices and no Discord", text)
            self.assertIn("pl.txt needs 8 non-empty lines", text)
            self.assertIn("missing store/ios/screenshot_captions/tr.txt", text)
            self.assertIn("en-GB/subtitle.txt: use search words", text)
            self.assertIn("en-GB/promotional_text.txt has 171", text)
            self.assertIn("en-AU/keywords.txt: 'tamer' is already indexed through en-GB", text)
            self.assertIn("de-DE/short_description.txt names 'Temtem'", text)
            self.assertIn("missing store/ios/in_app_events/ko/name.txt", text)
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
