"""Seat box, after the concept: a tall blue box at the back of the hull with a chunky iron frame
round its top and down its corners, big rivets, a wooden plank back board inside, and a wooden
axle stub in an iron collar sticking out of its left side. Hull space; open top.
"""

import common
import dims

T = 0.1        # wall thickness
RIM = 0.17     # iron rim width
RIVET = 0.032


def build():
    x = dims.SEAT_X
    z0, z1 = dims.SEAT_Z
    y0, y1 = dims.HULL_Y[1], dims.SEAT_TOP
    h = y1 - y0
    ym = (y0 + y1) / 2
    zm = (z0 + z1) / 2
    depth = z1 - z0

    walls = common.MeshBuilder("seat_walls")
    walls.box((-x + T / 2, ym, zm), (T, h, depth), "team")
    walls.box((x - T / 2, ym, zm), (T, h, depth), "team")
    walls.box((0, ym, z1 - T / 2), (2 * x, h, T), "team")
    walls.box((0, ym, z0 + T / 2), (2 * x, h, T), "team")

    frame = common.MeshBuilder("seat_frame")
    # Top rim: four chunky rails. The side rails run the full depth; the front and back rails butt
    # against them, so no faces overlap (overlaps z-fight and bake black).
    frame.box((-x + T / 2, y1, zm), (RIM, 0.13, depth + RIM - T), "iron")
    frame.box((x - T / 2, y1, zm), (RIM, 0.13, depth + RIM - T), "iron")
    inner = 2 * x - T - RIM
    frame.box((0, y1, z0 + T / 2), (inner, 0.12, RIM), "iron")
    frame.box((0, y1, z1 - T / 2), (inner, 0.12, RIM), "iron")
    # Corner posts, stopping under the rim.
    post_h = h - 0.065
    for sx in (-1, 1):
        for zz in (z0 + T / 2, z1 - T / 2):
            frame.box((sx * (x - T / 2), y0 + post_h / 2, zz), (0.15, post_h, 0.15), "iron")

    rivets = common.MeshBuilder("seat_rivets")
    for sx in (-1, 1):
        for yy in (y0 + 0.2, y1 - 0.25):
            for zz in (z0 + 0.28, z1 - 0.28):
                rivets.sphere((sx * (x + 0.005), yy, zz), RIVET, "iron", scale=(0.6, 1, 1), segments=10, rings=6)
    for xx in (-x + 0.28, x - 0.28):
        for yy in (y0 + 0.2, y1 - 0.25):
            rivets.sphere((xx, yy, z0 - 0.005), RIVET, "iron", scale=(1, 1, 0.6), segments=10, rings=6)

    # Wooden plank back board, rising a little above the rim behind the knight.
    planks = common.MeshBuilder("seat_planks")
    for px in (-0.31, 0.0, 0.31):
        planks.box((px, y0 + 0.55, z1 - T - 0.04), (0.28, 1.0, 0.07), "wood", grain_axis=1)

    # Axle stub out of the left side, in an iron collar.
    stub = common.MeshBuilder("seat_stub")
    sy, sz = y0 + 0.38, z1 - 0.38
    stub.cylinder((-x - 0.04, sy, sz), 0.12, 0.08, "iron", axis="x", segments=20)
    stub.cylinder((-x - 0.2, sy, sz), 0.085, 0.36, "wood", axis="x", segments=16)

    objs = [walls.build(bevel=0.035, segments=3), frame.build(bevel=0.04, segments=3),
            rivets.build(), planks.build(bevel=0.02, segments=2), stub.build(bevel=0.025, segments=3)]
    return common.finish(objs, "seat", texture_size=512)
