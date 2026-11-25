class_name LegalInfo
extends RefCounted
## Legal links and licence notices shown under Settings -> Legal (docs/legal/).
## The pages are served by the game server (server/site, built by tools/site/build_site.py).
## Switch SITE to the own domain once Ali has one (and CHIMORA_DOMAIN in the site build).

const SITE: String = "https://chimora.161-97-102-171.sslip.io"
const IMPRINT_URL: String = SITE + "/impressum"
const PRIVACY_URL: String = SITE + "/datenschutz"
const TERMS_URL: String = SITE + "/nutzungsbedingungen"
const LICENCES_URL: String = SITE + "/lizenzen"
## The English pages of the terms and the privacy policy (docs/legal/TERMS_EN.md, PRIVACY_POLICY_EN.md).
const TERMS_URL_EN: String = SITE + "/terms"
const PRIVACY_URL_EN: String = SITE + "/privacy"
## Version of the terms the player accepts before the first connection (the "Stand" of
## docs/legal/NUTZUNGSBEDINGUNGEN.md). A new version asks every player once more.
const TERMS_VERSION: String = "2026-11"
## Help with purchases (docs/legal/KAEUFE.md): German page and English page.
const PURCHASES_URL_DE: String = SITE + "/kaeufe"
const PURCHASES_URL_EN: String = SITE + "/purchases"
const CONTACT: String = "aa.amuri@icloud.com"

## Characters per info page on the 144 px wide screen.
const PAGE_CHARS: int = 260

static func links_text() -> String:
	return "\n".join([
		"Imprint: " + IMPRINT_URL,
		"Privacy: " + PRIVACY_URL,
		"Terms: " + TERMS_URL,
		"Contact: " + CONTACT,
	])

## Version, build and platform for a support mail (200 list item 129).
static func about_text() -> String:
	return "\n".join([
		Loc.t("Chimora %s (build %d)") % [Online.CLIENT_VERSION_NAME, Online.CLIENT_VERSION],
		Loc.t("System: %s") % OS.get_name(),
		Loc.t("Please name these in a mail to support."),
		"Contact: " + CONTACT,
	])

## The terms page in the game's language: German, else English.
static func terms_url() -> String:
	return TERMS_URL if Loc.language() == "de" else TERMS_URL_EN

## The privacy policy page in the game's language: German, else English.
static func privacy_url() -> String:
	return PRIVACY_URL if Loc.language() == "de" else PRIVACY_URL_EN

## The purchases help page in the game's language.
static func purchases_url() -> String:
	return PURCHASES_URL_DE if Loc.language() == "de" else PURCHASES_URL_EN

## Japanese, Korean and Chinese letters (art/fonts/OFL.txt, SIL Open Font License 1.1).
const FONT_NOTICE: String = "Japanese, Korean and Chinese text uses Chimora CJK Pixel, a subset of Fusion Pixel Font 8/10/12px (Copyright (c) 2022, TakWolf, with glyphs from Ark Pixel Font, Cubic 11, Galmuri, Misaki, Boutique Bitmap 7x7/9x9 and Miseki Bitmap), licensed under the SIL Open Font License 1.1: https://openfontlicense.org"

## Engine licence notice (Godot is MIT licensed; its notice must ship with the game).
static func licence_text() -> String:
	return "Chimora uses the Godot Engine.\n\n" + Engine.get_license_text() \
		+ "\n\n" + FONT_NOTICE \
		+ "\n\nThird-party components inside Godot and their licences: " + LICENCES_URL

## Splits [param text] into pages of at most [param size] characters, breaking at spaces.
static func pages(text: String, size: int = PAGE_CHARS) -> PackedStringArray:
	var out: PackedStringArray = []
	var rest: String = text.strip_edges()
	while rest.length() > size:
		var cut: int = rest.rfind(" ", size)
		if cut <= 0:
			cut = size
		out.append(rest.substr(0, cut).strip_edges())
		rest = rest.substr(cut).strip_edges()
	if not rest.is_empty():
		out.append(rest)
	return out
