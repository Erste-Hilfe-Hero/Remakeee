class_name AgeGate
extends RefCounted
## Age question on first opening the shop (items 4247-4253): birth year and month from lists, no
## free typing. Only the age band goes to the server. Returns the band (0, 13, 16, 18) or -1.

static func run(menu: MenuHost) -> int:
	await menu.info("Before the shop opens: when were you born? Only your age group is stored, not the date. Under 13 the shop stays closed.")
	var now: Dictionary = Online.date_now()
	var years: Array[String] = []
	for y: int in range(int(now.year), int(now.year) - 101, -1):
		years.append(str(y))
	var yi: int = await menu.pick_strings("Year of birth", years)
	if yi < 0:
		return -1
	var months: Array[String] = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
		"October", "November", "December"]
	var mi: int = await menu.pick_strings("Month of birth", months)
	if mi < 0:
		return -1
	if not await menu.confirm(Loc.t("Born in %s %s?") % [Loc.t(months[mi]), years[yi]]):
		return -1
	var r: Dictionary = await Online.call_fn("shop_set_age", {"p_year": int(years[yi]), "p_month": mi + 1})
	if not r.ok or not r.data is Dictionary:
		await menu.info("No connection right now. Try again in a moment.")
		return -1
	if not bool(r.data.get("ok", false)):
		if str(r.data.get("error", "")) == "age_locked":
			await menu.info("Your age group can only change when your birthday comes.")
			return int(r.data.get("band", -1))
		return -1
	return int(r.data.band)
