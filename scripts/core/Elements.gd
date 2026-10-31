class_name Elements
## 8 original elements. Each beats exactly 2 and is beaten by exactly 2.
enum E { EMBER, TIDE, BLOOM, VOLT, STONE, GALE, LUMEN, UMBRA }

const STRONG := {
	E.EMBER: [E.BLOOM, E.UMBRA],
	E.TIDE:  [E.EMBER, E.STONE],
	E.BLOOM: [E.TIDE, E.STONE],
	E.VOLT:  [E.TIDE, E.GALE],
	E.STONE: [E.EMBER, E.VOLT],
	E.GALE:  [E.BLOOM, E.LUMEN],
	E.LUMEN: [E.UMBRA, E.VOLT],
	E.UMBRA: [E.LUMEN, E.GALE],
}

## Placeholder colours per element (Era I maps them to greens by brightness).
const COLORS := {
	E.EMBER: Color("e0603a"),
	E.TIDE:  Color("3a7be0"),
	E.BLOOM: Color("4caf50"),
	E.VOLT:  Color("f2d03b"),
	E.STONE: Color("9a7b55"),
	E.GALE:  Color("9fd8e8"),
	E.LUMEN: Color("fff4c2"),
	E.UMBRA: Color("4b3a66"),
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
