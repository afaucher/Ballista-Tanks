"""The ballista's fork mount, in ballista-yaw space (origin = dims.PIVOT): a round base plate on
the hull's turntable and two iron arms rising either side of the cradle to trunnion bosses and an
axle through the pivot. The ballista pitches about that axle, so it looks held at any angle.
"""

import common
import dims

BASE = (-0.42, -0.36)   # base plate bottom and top, below the pivot
ARM_X = 0.47


def build():
    mb = common.MeshBuilder("mount")
    mb.cylinder((0, (BASE[0] + BASE[1]) / 2, 0), 0.5, BASE[1] - BASE[0], "iron", axis="y", segments=28)
    for side in (-1, 1):
        x = side * ARM_X
        mb.box((x, (BASE[1] + 0.06) / 2, 0), (0.1, 0.06 - BASE[1], 0.24), "iron")
        mb.cylinder((x, 0, 0), 0.11, 0.14, "iron", axis="x", segments=20)   # trunnion boss
    mb.cylinder((0, 0, 0), 0.05, 2 * ARM_X + 0.1, "iron", axis="x", segments=12)   # pivot axle
    obj = mb.build(bevel=0.02, segments=2, angle=30)
    return common.finish([obj], "mount", texture_size=512)
