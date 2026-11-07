class_name TideChart
extends RefCounted
## Tide Chart (area 3 item 1063): the next low and high tide by the device clock. Low tide runs
## from 0 to 6 and from 12 to 18 (WorldMechanics.low_tide), high tide the other hours.

const ITEM: String = "tide_chart"

## Hour (0-23) the current tide ends and the other one begins.
static func next_change(hour: int) -> int:
	return posmod((floori(float(posmod(hour, 24)) / 6.0) + 1) * 6, 24)

## The chart's page for [param hour] (defaults to the device clock), already translated.
static func lines(hour: int = -1) -> Array[String]:
	var h: int = hour if hour >= 0 else int(Time.get_time_dict_from_system().hour)
	var low: bool = WorldMechanics.low_tide(h)
	var change: int = next_change(h)
	var after: int = posmod(change + 6, 24)
	var out: Array[String] = [Loc.t("Tide Chart")]
	out.append((Loc.t("Now: low tide, until %02d:00.") if low else Loc.t("Now: high tide, until %02d:00.")) % change)
	if low:
		out.append(Loc.t("Next high tide: %02d:00 to %02d:00.") % [change, after])
		out.append(Loc.t("Next low tide: %02d:00 to %02d:00.") % [after, posmod(after + 6, 24)])
	else:
		out.append(Loc.t("Next low tide: %02d:00 to %02d:00.") % [change, after])
		out.append(Loc.t("Next high tide: %02d:00 to %02d:00.") % [after, posmod(after + 6, 24)])
	out.append(Loc.t("Sea caves open their inner chambers at low tide."))
	return out
