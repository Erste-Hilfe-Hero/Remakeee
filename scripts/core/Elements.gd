class_name Elements
## The 8 Era I elements, then the later eras' elements in chart order (Ink, Echo, Rust, Mask,
## Acid, Frost, Gilt, Zenith), appended so saved element ids keep their meaning. The chart lives
## in data/type_chart.json (docs/BALANCE.md, Type chart): every
## element has at least 2 real strengths and 2 real weaknesses (Lumen and Umbra beat each other,
## which is neutral both ways). An element after Era I sits on legendaries, on the kinds of the
## post-game region of its own era (Rust and Mask: Vellmarch, Acid and Frost: Quillmarch, Gilt and
## Zenith: Halcyra) and sparingly on act kinds (tools/balance/type_sim.py).
enum E { EMBER, TIDE, BLOOM, VOLT, STONE, GALE, LUMEN, UMBRA, INK, ECHO, RUST, MASK, ACID, FROST, GILT, ZENITH }

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
	E.RUST:  Color("a8582e"),
	E.MASK:  Color("8a5a80"),
	E.ACID:  Color("9cc82e"),
	E.FROST: Color("bfe4f2"),
	E.GILT:  Color("e8c050"),
	E.ZENITH: Color("8ab8ec"),
}

static func element_name(e: int) -> String:
	return String(E.keys()[e]).capitalize()

static func color(e: int) -> Color:
	return COLORS.get(e, Color.GRAY)

## Display name of a chart element by its key, also for chart elements not in the enum yet
## (Halcyra's Gilt and Zenith take their "name" from data/type_chart.json).
static func chart_name(key: String) -> String:
	var t: Dictionary = (chart().get("types", {}) as Dictionary).get(key, {})
	return Loc.t(str(t.get("name", key.capitalize())))

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
