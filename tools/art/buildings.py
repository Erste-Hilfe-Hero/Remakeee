"""Town architecture per act for the Era I atlases (buildings design plan). All drawing stays
in the four Era I inks (0 darkest).

  veydal   green valleys: half-timbered plaster, thick thatch, flower boxes (shared atlas,
           gen_tiles.py, also kept by gen_tiles_veydal.py)
  corvane  coast: clapboard on stilts, fish-scale slate, portholes, rope fences
  ashmere  ash and fire: basalt blocks, slab roofs with chimneys, glowing windows
  solenne  sun desert: smooth adobe, domes and parapets, keyhole arches, cloth awnings

The three later acts get their own atlas from gen_tiles_towns.py (art/era1/tiles/overworld_<act>.png).
DOOR rows are roles (TilesetFactory.DoorRole): 0 house, 1 healer, 2 shop, 3 Rift gate.
GRASS rows 4..7 are the variants 0..3 with a building's cast shadow on the left edge.
The LAMP of Veydal is the lighthouse lantern (gen_tiles.lamp) and is not drawn here.
"""
from __future__ import annotations

UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8
T = 16
STYLES = ["veydal", "corvane", "ashmere", "solenne"]
TOWNS = ["corvane", "ashmere", "solenne"]
STYLED = {"WALL", "ROOF", "DOOR", "FENCE", "SIGN", "LAMP", "SPRING", "RIFT"}
ROLE_HOUSE, ROLE_HEAL, ROLE_SHOP, ROLE_RIFT = 0, 1, 2, 3


def shade_left(c, ox: int, oy: int) -> None:
    """Cast shadow of a building standing to the left (plan item 6)."""
    for y in range(T):
        c.set(ox, oy + y, 1)
        c.set(ox + 1, oy + y, 1)
        if y % 2 == 0:
            c.set(ox + 2, oy + y, 1)
        if y % 4 == 1:
            c.set(ox + 3, oy + y, 1)


# --- shared emblems over doors ------------------------------------------------------------

def emblem_heal(c, ox: int, oy: int) -> None:
    # A leaf cupped round a drop: Chimora's healer mark (no cross, no franchise symbol).
    c.ascii(ox + 5, oy, ["..000.",
                         ".03330",
                         "033130",
                         "031330",
                         ".0330.",
                         "..00.."])


def emblem_shop(c, ox: int, oy: int) -> None:
    # A hanging board with a coin pouch, on an iron bracket.
    c.ascii(ox + 9, oy, ["0000000",
                         "...0..0",
                         "..03330",
                         "..03030",
                         "..03330",
                         "..00000"])


# --- VEYDAL -------------------------------------------------------------------------------

def v_roof(c, ox, oy, m):
    # Thatch: straw bundles in rows, each row ending in a ragged dark lip.
    c.rect(ox, oy, T, T, 2)
    for row in range(4):
        y = oy + row * 4
        for x in range(16):
            if (x + row * 3) % 5 == 0:
                c.vline(ox + x, y, y + 1, 3)
            if (x + row * 2) % 3 == 0:
                c.set(ox + x, y + 2, 1)
        for x in range(16):
            c.set(ox + x, y + 3, 1 if (x + row) % 4 else 0)
    if not m & UP:
        c.hline(ox, ox + 15, oy, 0)
        c.hline(ox, ox + 15, oy + 1, 1)
        for x in range(0, 16, 4):
            c.set(ox + x + 1, oy + 1, 0)
            c.set(ox + x + 2, oy + 2, 1)
    if not m & DOWN:
        # Heavy thatch fringe hanging over the wall.
        c.rect(ox, oy + 11, T, 2, 2)
        for x in range(16):
            c.set(ox + x, oy + 12, 3 if x % 3 == 0 else 2)
            c.set(ox + x, oy + 13, 1)
            c.set(ox + x, oy + 14, 0 if x % 2 == 0 else 1)
        c.checker(ox, oy + 15, T, 1, 0, None)
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
        c.vline(ox + 1, oy + 1, oy + 13, 3)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)
        c.vline(ox + 14, oy + 1, oy + 13, 1)


def v_wall(c, ox, oy, m):
    # Half-timbered: white plaster, dark beams, a cross brace, mullioned window, flower box.
    c.rect(ox, oy, T, T, 3)
    c.hline(ox, ox + 15, oy, 0)
    c.hline(ox, ox + 15, oy + 1, 1)
    c.hline(ox, ox + 15, oy + 12, 1)
    c.rect(ox, oy + 13, T, 3, 2)
    c.hline(ox, ox + 15, oy + 13, 0)
    for x in range(1, 16, 4):
        c.set(ox + x, oy + 14, 1)
    c.hline(ox, ox + 15, oy + 15, 0)
    # Window with a cross mullion.
    c.ascii(ox + 4, oy + 3, ["00000000",
                             "01120110",
                             "01200210",
                             "00000000",
                             "01200210",
                             "01100110",
                             "00000000"])
    # Flower box under the window (plan item 24).
    c.ascii(ox + 3, oy + 9, ["3.30.3.3..",
                             "0000000000",
                             ".01111110."])
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
        c.vline(ox + 1, oy + 1, oy + 12, 1)
        # Diagonal brace.
        for i in range(3):
            c.set(ox + 2 + i, oy + 2 + i, 1)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)
        c.vline(ox + 14, oy + 1, oy + 12, 1)
        for i in range(3):
            c.set(ox + 13 - i, oy + 2 + i, 1)


def v_door(c, ox, oy, role):
    v_wall(c, ox, oy, LEFT | RIGHT)
    c.rect(ox + 1, oy + 2, 14, 11, 3)
    c.hline(ox + 1, ox + 14, oy + 12, 1)
    body = ["..000000..",
            ".01121110.",
            "0112112110",
            "0112112110",
            "0111111130",
            "0112112110",
            "0112112110",
            "0000000000"]
    c.ascii(ox + 3, oy + 13 - len(body), body)
    c.hline(ox + 2, ox + 13, oy + 13, 2)
    c.hline(ox + 2, ox + 13, oy + 14, 3)
    c.hline(ox + 1, ox + 14, oy + 15, 1)
    if role == ROLE_HEAL:
        emblem_heal(c, ox, oy)
    elif role == ROLE_SHOP:
        emblem_shop(c, ox, oy)
    elif role == ROLE_RIFT:
        rift_door(c, ox, oy, "veydal")


def v_fence(c, ox, oy, m, g):
    g(c, ox, oy, 1)
    for y in (5, 10):
        c.hline(ox, ox + 15, oy + y, 0)
        c.hline(ox, ox + 15, oy + y + 1, 3)
        c.hline(ox, ox + 15, oy + y + 2, 0)
    c.ascii(ox + 6, oy + 2, ["0000", "0330", "0320", "0320", "0320", "0320", "0320",
                             "0320", "0320", "0320", "0320", "0220", "0000"])
    if not m & LEFT:
        g_clear(c, ox, oy + 5, 3, 8, g)
    if not m & RIGHT:
        g_clear(c, ox + 13, oy + 5, 3, 8, g)


def g_clear(c, x, y, w, h, g):
    c.rect(x, y, w, h, 2)


def v_sign(c, ox, oy, g):
    g(c, ox, oy, 2)
    c.ascii(ox + 1, oy + 1, ["00000000000000",
                             "0..0......0..0",
                             ".0000000000000",
                             ".0333333333330",
                             ".0311111111230",
                             ".0333333333330",
                             ".0311111123330",
                             ".0333333333330",
                             ".0222222222220",
                             ".0000000000000",
                             "......00......",
                             "......00......",
                             "......00......",
                             ".....0110.....",
                             "......00......"])


def v_spring(c, ox, oy, g):
    # Village healing well: round fieldstone rim, clear water, a lit ripple.
    g(c, ox, oy, 0)
    c.ascii(ox, oy, ["....00000000....",
                     "..003323332300..",
                     ".03222000022230.",
                     ".0200111111020..",
                     "0320111311110230",
                     "0201113331111020",
                     "0201111311111020",
                     "0201111111131020",
                     "0201131111111020",
                     "0320111111110230",
                     ".02001111110020.",
                     ".03220000002230.",
                     "..003223322300..",
                     "...0000000000...",
                     "....11111111....",
                     "................"])


# --- CORVANE ------------------------------------------------------------------------------

def c_roof(c, ox, oy, m):
    # Fish-scale slate: dark scales with a lit rim, rows offset by half a scale.
    c.rect(ox, oy, T, T, 1)
    for row in range(5):
        y = oy + row * 3
        off = 2 if row % 2 else 0
        for x0 in range(-4 + off, 16, 4):
            for dx, dy, v in ((0, 0, 2), (1, 1, 2), (2, 1, 2), (3, 0, 0), (1, 2, 0), (2, 2, 0)):
                xx = x0 + dx
                if 0 <= xx < 16:
                    c.set(ox + xx, y + dy, v)
    if not m & UP:
        c.hline(ox, ox + 15, oy, 0)
        c.hline(ox, ox + 15, oy + 1, 2)
        c.hline(ox, ox + 15, oy + 2, 0)
    if not m & DOWN:
        # Painted fascia board, then shadow.
        c.hline(ox, ox + 15, oy + 12, 0)
        c.hline(ox, ox + 15, oy + 13, 3)
        c.hline(ox, ox + 15, oy + 14, 0)
        for x in range(1, 16, 3):
            c.set(ox + x, oy + 13, 2)
        c.checker(ox, oy + 15, T, 1, 0, 1)
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
        c.vline(ox + 1, oy + 1, oy + 13, 3)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def c_wall(c, ox, oy, m):
    # Clapboard: overlapping boards, a porthole, the house stands on stilts.
    c.rect(ox, oy, T, 12, 3)
    for y in range(0, 12, 3):
        c.hline(ox, ox + 15, oy + y, 0 if y == 0 else 1)
        c.hline(ox, ox + 15, oy + y + 2, 2)
    c.ascii(ox + 4, oy + 2, ["..0000..",
                             ".023320.",
                             "02133120",
                             "02111120",
                             "02111120",
                             ".021120.",
                             "..0000.."])
    # Stilts: dark gap under the floor with posts.
    c.hline(ox, ox + 15, oy + 12, 0)
    c.rect(ox, oy + 13, T, 3, 0)
    for x in (2, 13):
        c.vline(ox + x, oy + 13, oy + 15, 2)
        c.vline(ox + x + 1, oy + 13, oy + 15, 1)
    c.hline(ox, ox + 15, oy + 15, 1)
    if not m & LEFT:
        c.vline(ox, oy, oy + 12, 0)
        c.vline(ox + 1, oy + 1, oy + 11, 2)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 12, 0)
        c.vline(ox + 14, oy + 1, oy + 11, 1)


def c_door(c, ox, oy, role):
    c_wall(c, ox, oy, LEFT | RIGHT)
    c.rect(ox + 1, oy + 1, 14, 11, 3)
    for y in range(0, 12, 3):
        c.hline(ox + 1, ox + 14, oy + y, 0 if y == 0 else 1)
        c.hline(ox + 1, ox + 14, oy + y + 2, 2)
    c.ascii(ox + 4, oy + 4, ["00000000",
                             "01111110",
                             "01011010",
                             "01111130",
                             "01011010",
                             "01111110",
                             "01011010",
                             "01111110",
                             "00000000"])
    # A plank gangway over the stilts.
    c.rect(ox + 4, oy + 13, 8, 3, 3)
    c.hline(ox + 4, ox + 11, oy + 13, 2)
    c.vline(ox + 4, oy + 13, oy + 15, 0)
    c.vline(ox + 11, oy + 13, oy + 15, 0)
    c.set(ox + 7, oy + 14, 2)
    if role == ROLE_HEAL:
        # Lifebuoy ring beside the door.
        c.ascii(ox + 5, oy, ["..00..", ".0330.", "030030", "030030", ".0330.", "..00.."])
    elif role == ROLE_SHOP:
        # Fish on a bracket.
        c.ascii(ox + 8, oy, ["0000000", "....0..", ".0330.0", "033330.", ".0330.0", "..00..."])
    elif role == ROLE_RIFT:
        rift_door(c, ox, oy, "corvane")


def c_fence(c, ox, oy, m, g):
    # Rope between bollards.
    g(c, ox, oy, 1)
    sag = [6, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 6]
    for x in range(16):
        c.set(ox + x, oy + sag[x], 0)
        c.set(ox + x, oy + sag[x] + 1, 3 if x % 2 else 2)
        c.set(ox + x, oy + sag[x] + 2, 0)
    c.ascii(ox + 6, oy + 3, ["0000", "0330", "0000", "0320", "0310", "0320",
                             "0310", "0320", "0310", "0210", "0110", "0000"])
    if not m & LEFT:
        c.rect(ox, oy + 6, 4, 5, 2)
    if not m & RIGHT:
        c.rect(ox + 11, oy + 6, 5, 5, 2)


def c_sign(c, ox, oy, g):
    # Driftwood board lashed to an oar.
    g(c, ox, oy, 2)
    c.ascii(ox + 1, oy + 2, [".000000000000.",
                             "03332333233330",
                             "03111111112330",
                             "02333323333320",
                             "03111112333330",
                             "03323333332330",
                             ".000000000000.",
                             "......00......",
                             "......00......",
                             ".....0300.....",
                             ".....0300.....",
                             "......00......",
                             ".....0110....."])
    c.set(ox + 1, oy + 3, 0)


def c_lamp(c, ox, oy, g):
    # Harbour lantern hanging from a hooked post.
    g(c, ox, oy, 1)
    c.ascii(ox, oy, ["....00000000....",
                     "....02222220....",
                     "....00000020....",
                     ".....0.0..20....",
                     "....00000.20....",
                     "...0333330.20...",
                     "...0322230.20...",
                     "...0321230.20...",
                     "...0322230.20...",
                     "...0333330.20...",
                     "....00000..20...",
                     "...........20...",
                     "...........20...",
                     "..........0220..",
                     ".........011110.",
                     "..........0000.."])


def c_spring(c, ox, oy, g):
    # Healing tide pool in a ring of planks.
    g(c, ox, oy, 0)
    c.ascii(ox, oy, ["..000000000000..",
                     ".03323332333230.",
                     "0320000000000230",
                     "0201111111111020",
                     "0301113111111030",
                     "0201133311111020",
                     "0301111111131030",
                     "0201111111111020",
                     "0301111311111030",
                     "0201111111111020",
                     "0320000000000230",
                     ".03323332333230.",
                     "..000000000000..",
                     "...1111111111...",
                     "................",
                     "................"])


# --- ASHMERE ------------------------------------------------------------------------------

def a_roof(c, ox, oy, m):
    # Flat basalt slabs with ember specks; a chimney on the left end of the ridge (plan item 43).
    c.rect(ox, oy, T, T, 1)
    for y in (4, 9):
        c.hline(ox, ox + 15, oy + y, 0)
        c.hline(ox, ox + 15, oy + y + 1, 2)
    for i, y in enumerate((0, 5, 10)):
        for x in ((3 + i * 5) % 16, (11 + i * 5) % 16):
            c.vline(ox + x, oy + y, oy + y + 3, 0)
    for (x, y) in ((6, 2), (13, 7), (2, 12)):
        c.set(ox + x, oy + y, 2)
    if not m & UP:
        c.hline(ox, ox + 15, oy, 0)
        c.hline(ox, ox + 15, oy + 1, 2)
        if not m & LEFT:
            c.ascii(ox + 8, oy, ["...3....",
                                 "..3.3...",
                                 "0000000.",
                                 "0222220.",
                                 "0122210.",
                                 "0111110.",
                                 "0111110."])
            c.set(ox + 10, oy, 2)
    if not m & DOWN:
        c.hline(ox, ox + 15, oy + 12, 0)
        c.hline(ox, ox + 15, oy + 13, 1)
        c.hline(ox, ox + 15, oy + 14, 0)
        c.hline(ox, ox + 15, oy + 15, 0)
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
        c.vline(ox + 1, oy + 1, oy + 13, 2)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def a_wall(c, ox, oy, m):
    # Columnar basalt blocks, a window glowing from the hearth inside (plan items 41, 54).
    c.rect(ox, oy, T, T, 1)
    blocks = [(0, 0, 6, 4), (6, 0, 5, 4), (11, 0, 5, 4),
              (0, 4, 3, 5), (13, 4, 3, 5),
              (0, 9, 5, 4), (5, 9, 6, 4), (11, 9, 5, 4)]
    for (x, y, w, h) in blocks:
        c.hline(ox + x, ox + x + w - 1, oy + y, 0)
        c.vline(ox + x, oy + y, oy + y + h - 1, 0)
        c.hline(ox + x + 1, ox + x + w - 2, oy + y + 1, 2)
    c.ascii(ox + 3, oy + 3, ["0000000000",
                             "0222222220",
                             "0233333320",
                             "0232332320",
                             "0233333320",
                             "0000000000"])
    c.rect(ox, oy + 13, T, 3, 0)
    c.hline(ox, ox + 15, oy + 13, 1)
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)
        c.vline(ox + 14, oy + 1, oy + 12, 0)


def a_door(c, ox, oy, role):
    a_wall(c, ox, oy, LEFT | RIGHT)
    c.rect(ox + 2, oy + 1, 12, 12, 1)
    # Iron-banded door under a lintel slab.
    c.ascii(ox + 1, oy + 2, ["00000000000000",
                             ".022222222220.",
                             "..0000000000..",
                             "..0111111110..",
                             "..0202202020..",
                             "..0111111110..",
                             "..0111111130..",
                             "..0202202020..",
                             "..0111111110..",
                             "..0111111110..",
                             "..0000000000.."])
    c.rect(ox + 2, oy + 13, 12, 3, 2)
    c.hline(ox + 2, ox + 13, oy + 13, 3)
    c.hline(ox + 2, ox + 13, oy + 15, 0)
    if role == ROLE_HEAL:
        c.rect(ox + 1, oy, 14, 2, 1)
        c.ascii(ox + 5, oy, ["..00..", ".0330.", "033130", ".0330.", "..00.."])
        c.rect(ox + 3, oy + 4, 10, 1, 0)
    elif role == ROLE_SHOP:
        # Anvil sign: the smithy (plan item 42).
        c.ascii(ox + 8, oy, ["0000000", "0333330", ".03330.", "..030..", ".00000."])
    elif role == ROLE_RIFT:
        rift_door(c, ox, oy, "ashmere")


def a_fence(c, ox, oy, m, g):
    # Iron railing with spear tips.
    g(c, ox, oy, 3)
    c.hline(ox, ox + 15, oy + 6, 0)
    c.hline(ox, ox + 15, oy + 11, 0)
    c.hline(ox, ox + 15, oy + 12, 1)
    for x in range(1, 16, 4):
        c.ascii(ox + x, oy + 2, [".0.", "020", "000", ".0.", ".0.", ".0.", ".0.", ".0.",
                                 ".0.", ".0.", ".0.", "010"])
    if not m & LEFT:
        c.rect(ox, oy + 5, 1, 8, 2)
    if not m & RIGHT:
        c.rect(ox + 15, oy + 5, 1, 8, 2)


def a_sign(c, ox, oy, g):
    # Stone warning slab with a little skull (dry gallows humour, plan item 53).
    g(c, ox, oy, 2)
    c.ascii(ox + 2, oy + 1, ["..00000000..",
                             ".0111111110.",
                             "011100001110",
                             "011033330110",
                             "011030030110",
                             "011033330110",
                             "011103301110",
                             "011130031110",
                             "011111111110",
                             "011111111110",
                             "000000000000",
                             ".0222222220.",
                             ".0000000000.",
                             "..11111111.."])


def a_lamp(c, ox, oy, g):
    # Iron brazier with a live flame.
    g(c, ox, oy, 1)
    c.ascii(ox, oy, [".......0........",
                     "......030.......",
                     ".....03230.0....",
                     "....0323230300..",
                     "...0322332330...",
                     "...0233333320...",
                     "..00000000000...",
                     "..02222222220...",
                     "...011111110....",
                     "....0000000.....",
                     "......010.......",
                     "......010.......",
                     ".....01110......",
                     "....0100010.....",
                     "...010...010....",
                     "...00.....00...."])


def a_spring(c, ox, oy, g):
    # Hot spring in black rock, steam rising.
    g(c, ox, oy, 3)
    c.ascii(ox, oy, ["...3.....3......",
                     "....3...3...3...",
                     "...3..0000.3....",
                     "..0000111100000.",
                     ".01110000001110.",
                     "0110222222220110",
                     "0102233322222010",
                     "0102222222332010",
                     "0102223222222010",
                     "0102222222222010",
                     "0110222222220110",
                     ".01110000001110.",
                     "..000011110000..",
                     "......0000......",
                     "...1111111111...",
                     "................"])


# --- SOLENNE ------------------------------------------------------------------------------

def s_roof(c, ox, oy, m):
    # Flat adobe terrace: parapet with crenels on top, a dome on an inner ridge tile,
    # timber beam ends (vigas) at the eave.
    c.rect(ox, oy, T, T, 3)
    for (x, y) in ((3, 6), (11, 9), (7, 12), (13, 3)):
        c.set(ox + x, oy + y, 2)
    if not m & UP:
        if m & LEFT and m & RIGHT:
            c.ascii(ox, oy, ["......0000......",
                             "....00333300....",
                             "...0333333220...",
                             "..033333332220..",
                             ".03333333322220.",
                             ".03333333222220.",
                             "0000000000000000",
                             "2222222222222222"])
            c.set(ox + 7, oy, 1)
        else:
            c.rect(ox, oy, T, 5, None)
            for x in range(0, 16, 4):
                c.rect(ox + x, oy + 2, 3, 1, 0)
                c.rect(ox + x, oy + 3, 3, 2, 3)
                c.set(ox + x + 2, oy + 4, 2)
            c.hline(ox, ox + 15, oy + 5, 0)
            c.hline(ox, ox + 15, oy + 6, 2)
            for x in range(0, 16, 4):
                c.vline(ox + x, oy + 2, oy + 4, 0)
                c.vline(ox + x + 2, oy + 2, oy + 4, 0)
    if not m & DOWN:
        c.hline(ox, ox + 15, oy + 12, 2)
        c.hline(ox, ox + 15, oy + 13, 0)
        for x in range(1, 16, 4):
            c.rect(ox + x, oy + 13, 2, 2, 1)
            c.set(ox + x, oy + 15, 0)
            c.set(ox + x + 1, oy + 15, 0)
    if not m & LEFT:
        c.vline(ox, oy + (0 if m & UP else 2), oy + 13, 0)
    if not m & RIGHT:
        c.vline(ox + 15, oy + (0 if m & UP else 2), oy + 13, 0)
        c.vline(ox + 14, oy + (1 if m & UP else 7), oy + 12, 2)


def s_wall(c, ox, oy, m):
    # Smooth adobe, an arched window with a lattice shade.
    c.rect(ox, oy, T, T, 3)
    for (x, y) in ((2, 2), (12, 4), (5, 11), (13, 10)):
        c.set(ox + x, oy + y, 2)
    c.ascii(ox + 5, oy + 2, ["..00..",
                             ".0110.",
                             "010010",
                             "011110",
                             "010010",
                             "011110",
                             "000000",
                             "222222"])
    c.rect(ox, oy + 13, T, 3, 2)
    c.hline(ox, ox + 15, oy + 13, 1)
    c.hline(ox, ox + 15, oy + 15, 0)
    if not m & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not m & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)
        c.vline(ox + 14, oy, oy + 14, 2)


def s_door(c, ox, oy, role):
    s_wall(c, ox, oy, LEFT | RIGHT)
    c.rect(ox + 1, oy + 1, 14, 12, 3)
    # Keyhole arch with a hanging curtain.
    c.ascii(ox + 3, oy + 1, ["...0000...",
                             "..011110..",
                             ".01111110.",
                             ".01111110.",
                             "0111111110",
                             "0121212120",
                             "0212121210",
                             "0121212120",
                             "0111111110",
                             "0111111110",
                             "0111111110",
                             "0111111110",
                             "0000000000"])
    c.rect(ox + 2, oy + 13, 12, 3, 2)
    c.hline(ox + 2, ox + 13, oy + 13, 3)
    c.hline(ox + 1, ox + 14, oy + 15, 0)
    if role == ROLE_HEAL:
        # Sun over a drop, on the lintel.
        c.ascii(ox + 5, oy, ["0.00.0", ".0330.", "033330", ".0310.", "..00.."])
    elif role == ROLE_SHOP:
        # Striped cloth awning (bazaar, plan item 57).
        c.rect(ox, oy + 1, T, 4, None)
        for x in range(16):
            v = 3 if (x // 2) % 2 else 1
            c.vline(ox + x, oy + 1, oy + 3, v)
            c.set(ox + x, oy + 4, 0 if x % 2 else v)
        c.hline(ox, ox + 15, oy, 0)
    elif role == ROLE_RIFT:
        rift_door(c, ox, oy, "solenne")


def s_fence(c, ox, oy, m, g):
    # Low adobe garden wall with a rounded cap.
    g(c, ox, oy, 0)
    c.hline(ox, ox + 15, oy + 6, 0)
    c.rect(ox, oy + 7, T, 6, 3)
    c.hline(ox, ox + 15, oy + 7, 3)
    c.hline(ox, ox + 15, oy + 8, 2)
    for x in (4, 12):
        c.set(ox + x, oy + 10, 2)
    c.hline(ox, ox + 15, oy + 13, 0)
    c.hline(ox, ox + 15, oy + 14, 1)
    if not m & LEFT:
        c.vline(ox, oy + 6, oy + 13, 0)
    if not m & RIGHT:
        c.vline(ox + 15, oy + 6, oy + 13, 0)


def s_sign(c, ox, oy, g):
    # Cloth banner on a pole.
    g(c, ox, oy, 2)
    c.ascii(ox + 2, oy, ["0000000000000",
                         "0222222222220",
                         ".03333333330.",
                         ".03111111130.",
                         ".03333333330.",
                         ".03111130330.",
                         ".03333333330.",
                         "..030303030..",
                         "..0.0.0.0.0..",
                         "......0......",
                         "......0......",
                         "......0......",
                         "......0......",
                         ".....010.....",
                         "....01110...."])
    c.vline(ox + 8, oy + 9, oy + 13, 2)


def s_lamp(c, ox, oy, g):
    # Brass lantern with a pierced pattern on a slim stand.
    g(c, ox, oy, 1)
    c.ascii(ox, oy, [".......00.......",
                     "......0330......",
                     ".....033330.....",
                     "....00000000....",
                     "....03232320....",
                     "....02323230....",
                     "....03232320....",
                     "....00000000....",
                     ".....022220.....",
                     "......0220......",
                     ".......00.......",
                     ".......01.......",
                     ".......01.......",
                     ".......01.......",
                     ".....001100.....",
                     "....01111110...."])


def s_spring(c, ox, oy, g):
    # Oasis basin with a tiled rim (plan item 65).
    g(c, ox, oy, 0)
    c.ascii(ox, oy, ["0000000000000000",
                     "0323232323232320",
                     "0200000000000030",
                     "0301111111111020",
                     "0201113111111030",
                     "0301133311111020",
                     "0201111111131030",
                     "0301111111111020",
                     "0201111311111030",
                     "0301111111111020",
                     "0200000000000030",
                     "0323232323232320",
                     "0000000000000000",
                     "1111111111111111",
                     "................",
                     "................"])


# --- Rift gates (plan items 20, 33, 47) -----------------------------------------------------

def rift_core(c, ox, oy, top=4):
    # The tear itself: a jagged dark seam with a bright core.
    c.ascii(ox + 5, oy + top, ["..00..",
                               ".0310.",
                               ".0330.",
                               "01330.",
                               ".03310",
                               ".0333.",
                               "013310",
                               ".0330.",
                               "..00.."][: 13 - top])


def rift_gate(c, ox, oy, style, g):
    g(c, ox, oy, 3)
    if style == "veydal":
        # Mossy standing-stone arch with mist (Nebelriss).
        c.ascii(ox, oy, ["..000000000000..",
                         ".03323332333230.",
                         ".02000000000020.",
                         "0230........0320",
                         "023..........320",
                         "023..........320",
                         "033..........330",
                         "023..........320",
                         "023..........320",
                         "033..........330",
                         "023..........320",
                         "023..........320",
                         "0220........0220",
                         "0000........0000",
                         ".1...........1..",
                         "................"])
        c.checker(ox + 4, oy + 12, 8, 2, 3, None)
    elif style == "corvane":
        # Twisted root arch dripping with weed (Wurzelriss).
        c.ascii(ox, oy, ["...00000000.....",
                         "..0221111220....",
                         ".021000000120...",
                         "0210.......0120.",
                         "020.........020.",
                         "0210........020.",
                         ".020........0120",
                         ".0210........020",
                         "..020.......0120",
                         ".0210.......020.",
                         "020.........0210",
                         "0210.........020",
                         ".020........0210",
                         "02210......01220",
                         "0000........0000",
                         "................"])
        for x in (5, 8, 10):
            c.vline(ox + x, oy + 3, oy + 4 + x % 3, 1)
    elif style == "ashmere":
        # Shards of obsidian leaning together (Schattenriss).
        c.ascii(ox, oy, [".0...........0..",
                         ".00.........000.",
                         ".010.......0120.",
                         "0120.......0110.",
                         "0110........0120",
                         "01120.......0110",
                         "0120........0120",
                         ".0110......01120",
                         ".0120.......0110",
                         "01110.......0120",
                         "0120........0110",
                         "01120......01120",
                         "011110....011110",
                         "0000000..0000000",
                         ".2.....22.....2.",
                         "................"])
    else:
        # Sun gate: a ring with rays on two sandstone posts.
        c.ascii(ox, oy, ["...0.0.00.0.0...",
                         "..0.00000000.0..",
                         "...0333333330...",
                         ".003000000003000",
                         "..030......030..",
                         ".0230......0320.",
                         ".0330......0330.",
                         ".0230......0320.",
                         ".0330......0330.",
                         ".0230......0320.",
                         ".0330......0330.",
                         ".0230......0320.",
                         ".0330......0330.",
                         "000000....000000",
                         ".2222......2222.",
                         "................"])
    rift_core(c, ox, oy, 3)


def rift_door(c, ox, oy, style):
    # A door that leads into a Rift: the frame of the region's gate, the tear behind it.
    c.rect(ox + 3, oy + 2, 10, 11, 0)
    c.ascii(ox + 3, oy + 1, ["0000000000",
                             "0222222220",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "02......20",
                             "0000000000"])
    rift_core(c, ox, oy, 3)
    marks = {"veydal": (1, 3), "corvane": (2, 1), "ashmere": (2, 3), "solenne": (3, 2)}[style]
    c.set(ox + 1, oy + 4, marks[0])
    c.set(ox + 14, oy + 4, marks[1])


ROOF = {"veydal": v_roof, "corvane": c_roof, "ashmere": a_roof, "solenne": s_roof}
WALL = {"veydal": v_wall, "corvane": c_wall, "ashmere": a_wall, "solenne": s_wall}
DOOR = {"veydal": v_door, "corvane": c_door, "ashmere": a_door, "solenne": s_door}
FENCE = {"veydal": v_fence, "corvane": c_fence, "ashmere": a_fence, "solenne": s_fence}
SIGN = {"veydal": v_sign, "corvane": c_sign, "ashmere": a_sign, "solenne": s_sign}
LAMP = {"corvane": c_lamp, "ashmere": a_lamp, "solenne": s_lamp}
SPRING = {"veydal": v_spring, "corvane": c_spring, "ashmere": a_spring, "solenne": s_spring}


def draw(c, name: str, style: str, ox: int, oy: int, v: int, grass) -> None:
    """Draws styled kind [name] for [style] at variant row [v] (0..15)."""
    if name == "ROOF":
        ROOF[style](c, ox, oy, v)
    elif name == "WALL":
        WALL[style](c, ox, oy, v)
    elif name == "DOOR":
        DOOR[style](c, ox, oy, v if v < 4 else 0)
    elif name == "FENCE":
        FENCE[style](c, ox, oy, v, grass)
    elif name == "SIGN":
        SIGN[style](c, ox, oy, grass)
    elif name == "LAMP":
        LAMP[style](c, ox, oy, grass)
    elif name == "SPRING":
        SPRING[style](c, ox, oy, grass)
    elif name == "RIFT":
        rift_gate(c, ox, oy, style, grass)
