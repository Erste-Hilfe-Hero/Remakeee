"""Map template for new maps (area 3 item 904): 12 tiles wide, a frame of rock ("^") and a
two-tile exit at the top and at the bottom (x 5 and 6), each with its warp.

Copy the pattern into a builder module, or start from the dict it returns:

    from template import blank_map
    m = blank_map("new_route", 24, top=("north_map", 5, 20), bottom=("south_map", 5, 1),
                  name=tr("New Route", "Neue Route"), region="corvane", biome="route")
    m["rows"][4] = "^..,,,,,,..^"   # then draw the inside row by row
    finish(world, "new_route", m)

`top` and `bottom` are (map, x, y) of the arrival on the other map; the second exit tile lands
one cell to the right (x + 1). Leave one out (None) for a dead end. Run check_rows on the result.
"""
from common import check_rows, warp

WIDTH = 12
EXIT_X = 5


def blank_rows(height, top=True, bottom=True):
    """Rock frame, floor inside, path tiles where the exits are."""
    inner = "^" + "." * (WIDTH - 2) + "^"
    rows = [inner] * height
    edge = "^" * WIDTH
    gap = "^" * EXIT_X + "__" + "^" * (WIDTH - EXIT_X - 2)
    rows[0] = gap if top else edge
    rows[-1] = gap if bottom else edge
    return list(rows)


def blank_map(map_id, height, top=None, bottom=None, **fields):
    """A map dict with the frame, the exits and their warps; fields go in as they are."""
    if height < 3:
        raise SystemExit("%s: a map needs at least 3 rows" % map_id)
    rows = blank_rows(height, top is not None, bottom is not None)
    warps = []
    if top is not None:
        to, tx, ty = top
        warps += [warp(EXIT_X, 0, to, tx, ty, "up"), warp(EXIT_X + 1, 0, to, tx + 1, ty, "up")]
    if bottom is not None:
        to, tx, ty = bottom
        warps += [warp(EXIT_X, height - 1, to, tx, ty, "down"), warp(EXIT_X + 1, height - 1, to, tx + 1, ty, "down")]
    check_rows(map_id, rows)
    m = {"rows": rows, "warps": warps, "npcs": [], "signs": []}
    m.update(fields)
    return m
