"""A unit length of rope from (0, 0, 0) to (0, 1, 0), radius 0.045, for the bowstring: TankModel
stretches it along y between a bow tip and the nock (1.5-2.5x), so the twist is fairly tight.
"""

import math

import common


def build():
    mb = common.MeshBuilder("rope")
    path = [(0.0, i / 16.0, 0.0) for i in range(17)]
    circle = [(0.045 * math.cos(2 * math.pi * k / 10), 0.045 * math.sin(2 * math.pi * k / 10)) for k in range(10)]
    mb.sweep(path, circle, "rope", rope_turns=10.0, grain=False)
    obj = mb.build()
    return common.finish([obj], "rope", texture_size=512)
