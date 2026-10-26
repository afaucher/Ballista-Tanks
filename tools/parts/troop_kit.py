"""The troop's kit:
- shield: a small round shield, team face, iron rim and boss, wooden back and grip; origin at the
  grip in the left mitten, facing forward and out to the left (troop_dims.SHIELD_FACING);
- spear: a wooden shaft taller than the troop, a flat leaf blade, iron collar and butt cap; origin
  at the grip in the right mitten, butt resting on the ground in the rest pose;
- plume: a team-coloured crest arching back off the helmet; origin at the top of its socket.
"""

import math

from mathutils import Matrix

import common
import troop_common
import troop_dims as D


def shield():
    hand = D.mirror(D.HAND, -1)
    f = D.SHIELD_FACING
    centre = tuple(hand[i] + f[i] * D.SHIELD_OFFSET for i in range(3))
    # Built facing +z, then turned so +z points along SHIELD_FACING.
    xf = common.translate(centre) @ common.rotate("y", math.degrees(math.atan2(f[0], f[2])))
    r = D.SHIELD_R
    mb = common.MeshBuilder("shield")
    mb.lathe([
        (0.0, -0.015, "wood"),
        (r - 0.02, -0.015, "iron"),
        (r, -0.003, "iron"),
        (r, 0.012, "iron"),
        (r - 0.018, 0.022, "team"),           # the face, slightly domed
        (0.05, 0.03, "iron"),                 # boss
        (0.046, 0.05, "iron"),
        (0.02, 0.064, "iron"),
        (0.0, 0.066, "iron"),
    ], axis="z", segments=28, xf=xf)
    grip = common.MeshBuilder("grip")
    grip.box((0, 0, -0.04), (0.026, 0.11, 0.05), "wood", xf=xf, grain_axis=1)
    return troop_common.piece([mb.build(bevel=0.006, segments=2), grip.build(bevel=0.006, segments=1)],
                              "shield", hand)


def spear():
    x, z = D.HAND[0], D.HAND[2]
    blade = 0.19
    top = D.SPEAR_TOP - blade
    shaft = common.MeshBuilder("shaft")
    circle = [(0.016 * math.cos(a), 0.016 * math.sin(a)) for a in [i * math.tau / 12 for i in range(12)]]
    shaft.sweep([(x, D.SPEAR_BUTT + 0.02, z), (x, top + 0.01, z)], circle, "wood", up=(0, 0, 1))
    iron = common.MeshBuilder("spear_iron")
    iron.cylinder((x, top - 0.005, z), 0.022, 0.045, "iron", axis="y", segments=12)       # collar
    iron.cylinder((x, D.SPEAR_BUTT + 0.015, z), 0.021, 0.03, "iron", axis="y", segments=12)   # butt cap
    leaf = common.MeshBuilder("blade")
    leaf.lathe([(0.0, top, "steel"), (0.02, top, "steel"), (0.045, top + 0.06, "steel"),
                (0.0, D.SPEAR_TOP, "steel")], axis="y", segments=4,
               xf=common.translate((x, 0, z)) @ Matrix.Diagonal((1, 1, 0.3, 1)))   # flat, edges to the sides
    return troop_common.piece([shaft.build(), iron.build(bevel=0.006, segments=2), leaf.build(bevel=0.004, segments=1)],
                              "spear", D.HAND)


def plume():
    s = D.PLUME
    path = [(0, s[1] + dy, dz) for dy, dz in
            ((-0.015, 0.0), (0.06, 0.0), (0.13, 0.04), (0.17, 0.11), (0.165, 0.19), (0.12, 0.25), (0.065, 0.275))]
    scales = [0.5, 0.85, 1.0, 1.05, 0.95, 0.72, 0.3]
    prof = [(0.042 * math.cos(a), 0.045 * math.sin(a)) for a in [i * math.tau / 14 for i in range(14)]]
    mb = common.MeshBuilder("plume")
    mb.sweep(path, prof, "team", up=(1, 0, 0), grain=False, scales=scales)
    return troop_common.piece([mb.build()], "plume", s)


PIECES = {"shield": shield, "spear": spear, "plume": plume}
