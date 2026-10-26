"""The bolt, origin at the nock (where the string sits), pointing -z, dims.BOLT_LENGTH long:
a dark wooden shaft, an iron collar, a big four-sided steel broadhead like the concept's, and
pale fletching near the nock. Also the flying projectile.
"""

import common
import dims

SHAFT_R = 0.075


def build():
    L = dims.BOLT_LENGTH
    head = 0.62
    shaft = common.MeshBuilder("bolt_shaft")
    shaft.cylinder((0, 0, -(L - head) / 2), SHAFT_R, L - head, "wood_dark", axis="z", segments=10)
    shaft_obj = shaft.build(bevel=0.012, segments=2, angle=30.0)

    metal = common.MeshBuilder("bolt_metal")
    metal.cylinder((0, 0, -(L - head) + 0.02), 0.1, 0.1, "iron", axis="z", segments=10)
    metal.cylinder((0, 0, -0.04), 0.09, 0.08, "iron", axis="z", segments=10)   # nock cap
    # Broadhead: four-sided, widest a third of the way up, a short neck into the collar.
    z0 = -(L - head)
    metal.lathe([
        (0.0, z0 + 0.0, "steel"), (0.08, z0 - 0.02, "steel"), (0.23, z0 - 0.2, "steel"),
        (0.0, -L, "steel"),
    ], axis="z", segments=4)
    metal_obj = metal.build(bevel=0.012, segments=2, angle=30.0)

    vanes = common.MeshBuilder("bolt_vanes")
    vane = [(-0.08, 0.05), (-0.5, 0.05), (-0.42, 0.21), (-0.12, 0.23)]
    for deg in (0, 120, 240):
        vanes.extrude_x(vane, -0.012, 0.012, "cloth", xf=common.rotate("z", deg))
    vanes_obj = vanes.build(bevel=0.006, segments=1, angle=30.0)
    return common.finish([shaft_obj, metal_obj, vanes_obj], "bolt", texture_size=256)
