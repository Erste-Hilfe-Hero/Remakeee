class_name Elements
## The 8 Era I elements plus the Era II elements Ink and Echo, appended so saved element ids keep
## their meaning. The chart lives in data/type_chart.json (docs/BALANCE.md, Type chart): every
## element has at least 2 real strengths and 2 real weaknesses (Lumen and Umbra beat each other,
## which is neutral both ways). Ink and Echo sit only on legendary (ancient) Spirlings so far.
enum E { EMBER, TIDE, BLOOM, VOLT, STONE, GALE, LUMEN, UMBRA, INK, ECHO }

const CHART_PATH: String = "res://data/type_chart.json"

## Element -> the elements it beats, read from the chart.
static var STRONG: Dictionary = _load_strong()

## The whole chart as written in data/type_chart.json (all eras, names as keys).
static func chart() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHART_PATH))
	return raw if raw is Dictionary else {}

static func _load_strong() -> Dictionary:
	var types: Dictionary = chart().get("types", {})
	var out: Dictionary = {}
	for e: int in E.values():
		var list: Array = []
		for t: Variant in (types.get(E.keys()[e], {}) as Dictionary).get("strong", []):
			if E.has(str(t)):
				list.append(E[str(t)])
		out[e] = list
	return out

## Placeholder colours per element (Era I maps them to its four inks by brightness).
const COLORS := {
	E.EMBER: Color("e0603a"),
	E.TIDE:  Color("3a7be0"),
	E.BLOOM: Color("4caf50"),
	E.VOLT:  Color("f2d03b"),
	E.STONE: Color("9a7b55"),
	E.GALE:  Color("9fd8e8"),
	E.LUMEN: Color("fff4c2"),
	E.UMBRA: Color("4b3a66"),
	E.INK:   Color("2b2f4a"),
	E.ECHO:  Color("c9b8e0"),
}

static func element_name(e: int) -> String:
	return String(E.keys()[e]).capitalize()

static func color(e: int) -> Color:
	return COLORS.get(e, Color.GRAY)

## Multiplier for one attacking element into one defending element.
static func single(atk: int, def: int) -> float:
	var atk_strong: bool = def in STRONG[atk]
	var def_strong: bool = atk in STRONG[def]
	if atk_strong and def_strong:
		return 1.0  # Lumen <-> Umbra mirror
	if atk_strong:
		return 2.0
	if def_strong:
		return 0.5
	return 1.0

## Multiplier into a (possibly dual-element) defender.
static func multiplier(atk: int, defender_elements: Array) -> float:
	var m := 1.0
	for d in defender_elements:
		m *= single(atk, d)
	return m
