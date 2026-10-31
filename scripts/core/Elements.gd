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
