"""Pennant, after the concept: a dark wooden pole at the seat box's rear-left corner, a steel spear
tip, and a team-coloured swallow-tailed flag streaming back (+z) with a gentle wave, held to the
pole by two cloth sleeves. Hull space.
"""

import math

import common
import dims

P = dims.POLE
PX, PZ = P["x"], P["z"]
TOP = P["top_y"]
TIP_LEN = 0.24
POLE_TOP = TOP - TIP_LEN
FLAG_HI = POLE_TOP - 0.05
FLAG_LO = FLAG_HI - 0.42
FLAG_LEN = 0.85
THICK = 0.025


def _flag():
    mb = common.MeshBuilder("flag")
    n = 8
    z0 = PZ + 0.04

    def pt(s, y, side):
        x = PX + 0.07 * math.sin(math.pi * 1.6 * s) * s + side * THICK / 2
        return (x, y, z0 + s * FLAG_LEN)

    outline = []
    for i in range(n + 1):                                   # top edge, out to the upper tail
        s = i / n
        outline.append((s, FLAG_HI - 0.07 * s))
    outline.append((0.74, (FLAG_HI + FLAG_LO) / 2 + 0.01))   # the notch
    for i in range(n, -1, -1):                               # bottom edge, back to the pole
        s = i / n
        outline.append((s, FLAG_LO + 0.09 * s))
    front = [mb.v(pt(s, y, 1)) for s, y in outline]
    back = [mb.v(pt(s, y, -1)) for s, y in outline]
    mb.face(front, "team")
    mb.face(list(reversed(back)), "team")
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        mb.face([front[i], front[j], back[j], back[i]], "team")
    return mb.build(bevel=0.006, segments=1)


def build():
    pole = common.MeshBuilder("pole")
    pole.cylinder((PX, (P["base_y"] + POLE_TOP) / 2, PZ), 0.036, POLE_TOP - P["base_y"], "wood_dark", axis="y", segments=12)
    tip = common.MeshBuilder("tip")
    tip.cylinder((PX, POLE_TOP + 0.02, PZ), 0.05, 0.06, "steel", axis="y", segments=12)
    tip.lathe([(0.0, POLE_TOP + 0.04, "steel"), (0.065, POLE_TOP + 0.09, "steel"), (0.0, TOP, "steel")],
              center=(PX, 0, PZ), axis="y", segments=4, phase=math.pi / 4)
    sleeves = common.MeshBuilder("sleeves")
    for y in (FLAG_HI - 0.03, FLAG_LO + 0.05):
        sleeves.cylinder((PX, y, PZ), 0.06, 0.09, "team", axis="y", segments=14)
    return common.finish([pole.build(bevel=0.01), tip.build(bevel=0.008), sleeves.build(bevel=0.015), _flag()],
                         "pennant", texture_size=256)
