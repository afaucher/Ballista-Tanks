"""One track's frame plate (TankModel places it at x = +-TRACK_X), and the belt path the links
run round (belt(), shared with track_link.py and written to dims.json).

Built centred on x = 0.
"""

import math

import common
import dims


def belt():
    """The belt's path and link count: (z0, z1, centre height, radius, count, pitch)."""
    z0, z1 = dims.WHEEL_BIG_Z
    r = dims.WHEEL_BIG_R + dims.BELT_T / 2
    perimeter = 2 * (z1 - z0) + 2 * math.pi * r
    count = int(perimeter / 0.25)
    return z0, z1, dims.WHEEL_BIG_Y, r, count, perimeter / count


def build():
    """The frame plate inside the loop (the links are track_link.py, laid round the belt and
    moved by TankModel as the tank drives)."""
    z0, z1, cy, r, _, _ = belt()
    fm = common.MeshBuilder("frame")
    prof = [(z0 - (r - 0.08) * math.sin(math.pi * k / 12), cy + (r - 0.08) * math.cos(math.pi * k / 12)) for k in range(13)]
    prof += [(z1 + (r - 0.08) * math.sin(math.pi * k / 12), cy - (r - 0.08) * math.cos(math.pi * k / 12)) for k in range(13)]
    fm.extrude_x(prof, -0.22, -0.08, "gunmetal")
    frame = fm.build(bevel=0.02, segments=2, angle=30)
    return common.finish([frame], "track", texture_size=512)
