class_name LegalInfo
extends RefCounted
## Legal links and licence notices shown under Settings -> Legal (docs/legal/).
## Replace the domain once the website exists; the texts themselves live on the website.

const SITE: String = "https://chimora.example"
const IMPRINT_URL: String = SITE + "/impressum"
const PRIVACY_URL: String = SITE + "/datenschutz"
const TERMS_URL: String = SITE + "/nutzungsbedingungen"
const LICENCES_URL: String = SITE + "/lizenzen"
const CONTACT: String = "kontakt@chimora.example"

## Characters per info page on the 144 px wide screen.
const PAGE_CHARS: int = 260

static func links_text() -> String:
	return "\n".join([
		"Imprint: " + IMPRINT_URL,
		"Privacy: " + PRIVACY_URL,
		"Terms: " + TERMS_URL,
		"Contact: " + CONTACT,
	])

## Engine licence notice (Godot is MIT licensed; its notice must ship with the game).
static func licence_text() -> String:
	return "Chimora uses the Godot Engine.\n\n" + Engine.get_license_text() \
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
