extends GutTest
## Each build names only its own store (App Store guideline 2.3.10): the iOS texts never say
## Google Play, the Android texts never say App Store, the browser texts name neither, in all
## 14 languages, and every language has its own translation.

const FOREIGN: Dictionary = {
	StoreNames.IOS: ["Google Play", "Android"],
	StoreNames.ANDROID: ["App Store", "Apple", "iPhone"],
	StoreNames.OTHER: ["App Store", "Google Play", "iPhone", "Android"],
}
const OWN: Dictionary = {StoreNames.IOS: "App Store", StoreNames.ANDROID: "Google Play"}

var _lang: String

func before_all() -> void:
	_lang = Loc.language()

func after_all() -> void:
	Loc.set_language(_lang)

func test_each_platform_names_only_its_own_store() -> void:
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for texts: Dictionary in StoreNames.ALL:
			for p: String in FOREIGN:
				var t: String = Loc.t(StoreNames.pick(texts, p))
				for word: String in FOREIGN[p]:
					assert_false(word in t, "%s %s names %s: %s" % [lang, p, word, t])
				if OWN.has(p):
					assert_string_contains(t, OWN[p], "%s %s" % [lang, p])
				if lang != "en":
					assert_ne(t, StoreNames.pick(texts, p), "%s %s is translated" % [lang, p])

func test_web_text_names_no_platform() -> void:
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var t: String = Loc.t(ShopMenu.WEB_TEXT)
		for word: String in ["iPhone", "Android", "App Store", "Google Play"]:
			assert_false(word in t, "%s: %s" % [lang, t])

func test_pick_uses_this_build_when_no_platform_is_given() -> void:
	assert_eq(StoreNames.pick(StoreNames.CANCEL), StoreNames.pick(StoreNames.CANCEL, StoreNames.platform()))
	assert_eq(StoreNames.pick(StoreNames.CANCEL, "unknown"), StoreNames.CANCEL[StoreNames.OTHER])

func test_shop_and_account_texts_name_no_foreign_store() -> void:
	# The headless test build is neither iOS nor Android, so every line it shows is the neutral one.
	Loc.set_language("en")
	assert_eq(ShopMenu.reason_text("no_store"), StoreNames.NO_STORE[StoreNames.OTHER])
