class_name Glicko
extends RefCounted
## Glicko-2 for one game (plan area 7, item 2770). The same steps as public._league_rate in
## supabase/migrations/20261110000003_league.sql; tests compare both with reference values.

const SCALE: float = 173.7178
const TAU: float = 0.5
const EPS: float = 0.000001
const START_RATING: float = 1500.0
const START_RD: float = 350.0
const START_VOL: float = 0.06

## New {rating, rd, vol} after one game against [param r2]/[param rd2]; [param score] 1 win, 0 loss.
static func rate(r: float, rd: float, vol: float, r2: float, rd2: float, score: float) -> Dictionary:
	var mu: float = (r - 1500.0) / SCALE
	var phi: float = rd / SCALE
	var mu2: float = (r2 - 1500.0) / SCALE
	var phi2: float = rd2 / SCALE
	var g: float = 1.0 / sqrt(1.0 + 3.0 * phi2 * phi2 / (PI * PI))
	var e: float = 1.0 / (1.0 + exp(-g * (mu - mu2)))
	var v: float = 1.0 / (g * g * e * (1.0 - e))
	var delta: float = v * g * (score - e)
	var a: float = log(vol * vol)
	var big_a: float = a
	var big_b: float
	if delta * delta > phi * phi + v:
		big_b = log(delta * delta - phi * phi - v)
	else:
		var k: int = 1
		while _f(a - k * TAU, delta, phi, v, a) < 0.0 and k < 100:
			k += 1
		big_b = a - k * TAU
	var fa: float = _f(big_a, delta, phi, v, a)
	var fb: float = _f(big_b, delta, phi, v, a)
	var n: int = 0
	while absf(big_b - big_a) > EPS and n < 100:
		var big_c: float = big_a + (big_a - big_b) * fa / (fb - fa)
		var fc: float = _f(big_c, delta, phi, v, a)
		if fc * fb <= 0.0:
			big_a = big_b
			fa = fb
		else:
			fa = fa / 2.0
		big_b = big_c
		fb = fc
		n += 1
	var new_vol: float = exp(big_a / 2.0)
	var phi_star: float = sqrt(phi * phi + new_vol * new_vol)
	var new_phi: float = 1.0 / sqrt(1.0 / (phi_star * phi_star) + 1.0 / v)
	var new_mu: float = mu + new_phi * new_phi * g * (score - e)
	return {"rating": SCALE * new_mu + 1500.0, "rd": clampf(SCALE * new_phi, 30.0, 350.0), "vol": minf(new_vol, 0.2)}

static func _f(x: float, delta: float, phi: float, v: float, a: float) -> float:
	var ex: float = exp(x)
	return ex * (delta * delta - phi * phi - v - ex) / (2.0 * pow(phi * phi + v + ex, 2.0)) - (x - a) / (TAU * TAU)
