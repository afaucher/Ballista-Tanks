"""Hull, in hull space: the blue body between the tracks, the big rounded fenders over them, the
iron bumper across the front, the turntable the ballista sits on, and rivets.

After the concept: glossy blue panels with soft rounded edges, fenders that curve right down
over the front of the tracks, an iron strip along the bottom of the nose, rivets everywhere.
"""

import math

import common
import dims


def arc(cz, cy, r, a0, a1, n=8):
    """Points on an arc in the (z, y) plane, angles in degrees (0 = +z, 90 = +y)."""
    return [(cz + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def build():
    y0, deck = dims.HULL_Y
    zf, zb = dims.HULL_Z
    mb = common.MeshBuilder("hull_body")
    # Body side profile: a tall nose with a big rounded top edge, flat deck, rounded back.
    r = 0.28
    prof = [(zf + 0.08, y0)] + arc(zf + r, deck - r, r, 180, 90) + arc(zb - 0.2, deck - 0.2, 0.2, 90, 0) \
        + [(zb, y0 + 0.1), (zb - 0.1, y0)]
    mb.extrude_x(prof, -dims.HULL_X, dims.HULL_X, "team")
    body = mb.build(bevel=0.06, segments=3, angle=25)

    # Fenders: a thick curved shell over each track: flat top, a big quarter-round nose down
    # over the front of the track, and a short lip at the back.
    fenders = []
    for side in (-1, 1):
        fm = common.MeshBuilder("fender")
        top, t = dims.FENDER_TOP, 0.1   # a thin shell, centred on the belt so the links clear it
        rf = 0.76
        cz, cy = dims.FENDER_FRONT_Z + rf, top - rf
        outer = [(1.38, top - 0.28), (1.38, top)] + arc(cz, cy, rf, 90, 205, 10)
        inner = arc(cz, cy, rf - t, 205, 90, 10) + [(1.38 - t, top - t), (1.38 - t, top - 0.28)]
        x0, x1 = dims.FENDER_X
        fm.extrude_x(outer + inner, side * x0, side * x1, "team")
        # A deep skirt down the outer edge hides the top of the track, as the concept's does.
        d = 0.3
        skirt = arc(cz, cy, rf - d, 205, 90, 10) + [(1.38, top - d)]
        fm.extrude_x(outer + skirt, side * (x1 - 0.07), side * x1, "team")   # outside the belt's width
        fenders.append(fm.build(bevel=0.12, segments=5, angle=25))   # big round edges catch the light

    parts = [body] + fenders
    misc = common.MeshBuilder("hull_misc")
    # Iron bumper across the nose, between the fenders, with rivets.
    b = dims.BUMPER
    by = (b["y"][0] + b["y"][1]) / 2
    misc.box((0, by, b["z"] + 0.06), (2 * b["x"], b["y"][1] - b["y"][0], 0.16), "iron")
    for x in (-0.55, -0.2, 0.2, 0.55):
        misc.sphere((x, by, b["z"] - 0.03), 0.04, "iron", scale=(1, 1, 0.6), segments=10, rings=6)
    # Turntable under the ballista.
    px, py, pz = dims.PIVOT
    top = py - 0.42   # the fork mount's base plate rests here (mount.py)
    misc.cylinder((px, deck + 0.06, pz), 0.58, 0.12, "iron", axis="y", segments=24)
    misc.cylinder((px, (deck + top) / 2, pz), 0.4, top - deck, "iron", axis="y", segments=24)
    misc.cylinder((px, top - 0.04, pz), 0.5, 0.08, "iron", axis="y", segments=24)
    # Rivets: down the nose and along the fender tops.
    for x in (-0.5, 0.5):
        for y in (0.55, 0.8):
            misc.sphere((x, y, zf + 0.06), 0.045, "iron", scale=(1, 1, 0.6), segments=10, rings=6)
    for side in (-1, 1):
        for z in (-0.9, -0.3, 0.3, 0.9):
            misc.sphere((side * 1.15, dims.FENDER_TOP + 0.01, z), 0.045, "iron", scale=(1, 0.6, 1),
                        segments=10, rings=6)
        for a in (120, 160):
            rf = 0.76
            cz, cy = dims.FENDER_FRONT_Z + rf, dims.FENDER_TOP - rf
            z, y = cz + (rf + 0.01) * math.cos(math.radians(a)), cy + (rf + 0.01) * math.sin(math.radians(a))
            misc.sphere((side * 1.15, y, z), 0.045, "iron", segments=10, rings=6)
    parts.append(misc.build(bevel=0.02, segments=2, angle=30))
    return common.finish(parts, "hull", texture_size=1024)
