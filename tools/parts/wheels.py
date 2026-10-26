"""Shared wheel shape (not a part itself): wheel_big.py and wheel_small.py build it at their sizes.

After the concept: dark gunmetal, a thick rim with a rounded lip, a deep dish and a flat-topped
hub. Built around the origin, axle along x, outer face toward +x (TankModel turns the left-side
wheels round by rotation; a mirrored imported mesh renders inside out).
"""

import common


def wheel(name, radius, half_width):
    s = radius / 0.28   # proportions were tuned on a 0.28 m wheel
    profile = [
        (0.0, 0.08 * s, "gunmetal"),
        (0.08 * s, 0.08 * s, "gunmetal"),      # flat hub top
        (0.095 * s, 0.0, "gunmetal"),          # hub side, down into the dish
        (0.165 * s, 0.0, "gunmetal"),          # dish floor
        (0.185 * s, 0.075 * s, "gunmetal"),    # rim inner wall
        (0.255 * s, 0.075 * s, "gunmetal"),    # rim face
        (radius, 0.045 * s, "gunmetal"),       # rounded lip
        (radius, -half_width, "gunmetal"),
        (0.15 * s, -half_width, "gunmetal"),
        (0.0, -half_width, "gunmetal"),
    ]
    mb = common.MeshBuilder(name)
    mb.lathe(profile, axis="x", segments=28)
    obj = mb.build(bevel=0.022 * s, segments=3, angle=25.0)
    return common.finish([obj], name, texture_size=256)
