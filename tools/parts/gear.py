"""Winch cog, origin on its axle (TankModel places it at dims.GEAR in ballista-pitch space and
spins it about x). An iron cog with chunky teeth and a raised hub, its outer face toward -x (the
stock's left side, the side the concept shows), a short axle stub toward +x, and a crank arm
with a wooden handle.
"""

import math

import common
import dims

TEETH = 12


def build():
    r = dims.GEAR["r"]
    body = r - 0.06
    mb = common.MeshBuilder("gear_iron")
    # Along x from the outer (-x) face to the axle stub: hub, recessed web, rim.
    mb.lathe([
        (0.0, -0.13, "iron"), (0.085, -0.13, "iron"), (0.09, -0.04, "iron"), (body - 0.05, -0.04, "iron"),
        (body - 0.04, -0.06, "iron"), (body, -0.06, "iron"), (body, 0.05, "iron"), (0.045, 0.05, "iron"),
        (0.045, 0.22, "iron"), (0.0, 0.22, "iron"),
    ], axis="x", segments=30)
    for k in range(TEETH):
        a = 2 * math.pi * k / TEETH
        xf = common.rotate("x", math.degrees(a))
        mb.box((-0.005, body + 0.045, 0.0), (0.11, 0.11, 0.09), "iron", xf=xf)
    # Crank arm out from the hub.
    mb.box((-0.16, 0.09, 0.0), (0.05, 0.22, 0.08), "iron")   # short: the handle must clear the fender as it turns
    iron = mb.build(bevel=0.018, segments=2, angle=30.0)
    handle = common.MeshBuilder("gear_handle")
    handle.cylinder((-0.25, 0.17, 0.0), 0.04, 0.16, "wood_dark", axis="x", segments=12)
    handle.sphere((-0.34, 0.17, 0.0), 0.05, "wood_dark", segments=12, rings=8)
    wood = handle.build(bevel=0.01, segments=2, angle=30.0)
    return common.finish([iron, wood], "gear", texture_size=512)
