"""The troop's limbs, one piece per bone, both sides built from the right-side joints in troop_dims
(the left is the mirror image, modelled, so nothing is ever scaled by -1):
- upper arm: a team sleeve, shoulder to elbow (the pauldron on the torso covers its top);
- forearm: an iron elbow cop and vambrace, a brown cuff and a big brown mitten with a thumb;
- thigh: gunmetal hose, hip to knee;
- shin: an iron knee cop, gunmetal hose and a chunky brown boot with a dark sole.
Origins at the shoulder, elbow, hip and knee.
"""

import common
import troop_common
import troop_dims as D


def _upper_arm(s):
    sh, el = D.mirror(D.SHOULDER, s), D.mirror(D.ELBOW, s)
    mb = common.MeshBuilder("sleeve")
    troop_common.limb(mb, sh, el, [(0.0, -0.12, "team"), (0.044, -0.12, "team"), (0.046, 0.3, "team"),
                                   (0.041, 0.9, "team"), (0.032, 1.05, "team"), (0.0, 1.08, "team")])
    return troop_common.piece([mb.build(bevel=0.01, segments=2)], "upper_arm_" + "lr"[s > 0], sh)


def _forearm(s):
    el, wr, ha = D.mirror(D.ELBOW, s), D.mirror(D.WRIST, s), D.mirror(D.HAND, s)
    arm = common.MeshBuilder("vambrace")
    arm.sphere(el, 0.042, "iron", scale=(1, 0.95, 1))
    troop_common.limb(arm, el, wr, [(0.0, 0.1, "iron"), (0.036, 0.1, "iron"), (0.035, 0.75, "iron"),
                                    (0.04, 0.82, "wood_dark"), (0.044, 1.0, "wood_dark"), (0.0, 1.0, "wood_dark")])
    mitten = common.MeshBuilder("mitten")
    mitten.sphere(ha, 0.05, "wood_dark", scale=(0.92, 1.05, 1.1), segments=16, rings=10)
    mitten.sphere((ha[0] - s * 0.04, ha[1] + 0.018, ha[2] - 0.012), 0.022, "wood_dark", scale=(1, 1.2, 1),
                  segments=12, rings=8)      # thumb, on the inside
    return troop_common.piece([arm.build(bevel=0.008, segments=2), mitten.build()], "forearm_" + "lr"[s > 0], el)


def _thigh(s):
    hip, knee = D.mirror(D.HIP, s), D.mirror(D.KNEE, s)
    mb = common.MeshBuilder("hose")
    troop_common.limb(mb, hip, knee, [(0.0, -0.2, "gunmetal"), (0.05, -0.2, "gunmetal"), (0.052, 0.15, "gunmetal"),
                                      (0.047, 0.9, "gunmetal"), (0.0, 1.05, "gunmetal")])
    return troop_common.piece([mb.build(bevel=0.008, segments=2)], "thigh_" + "lr"[s > 0], hip)


def _shin(s):
    knee, ankle = D.mirror(D.KNEE, s), D.mirror(D.ANKLE, s)
    x, g = knee[0], D.GROUND_Y
    leg = common.MeshBuilder("leg")
    troop_common.limb(leg, knee, ankle, [(0.0, 0.0, "gunmetal"), (0.045, 0.0, "gunmetal"), (0.04, 0.9, "gunmetal"),
                                         (0.0, 1.0, "gunmetal")])
    cop = common.MeshBuilder("knee_cop")
    cop.sphere((x, knee[1], -0.01), 0.05, "iron", scale=(1, 0.8, 1))
    boot = common.MeshBuilder("boot")
    boot.cylinder((x, ankle[1] + 0.017, 0), 0.054, 0.036, "wood_dark", axis="y", segments=16, radius2=0.058)
    boot.box((x, g + 0.036, -0.025), (0.1, 0.07, 0.16), "wood_dark")
    sole = common.MeshBuilder("sole")
    sole.box((x, g + 0.007, -0.025), (0.104, 0.014, 0.164), "dark")
    return troop_common.piece([leg.build(), cop.build(), boot.build(bevel=0.022, segments=3), sole.build(bevel=0.005)],
                              "shin_" + "lr"[s > 0], knee)


PIECES = {
    "upper_arm_l": lambda: _upper_arm(-1), "upper_arm_r": lambda: _upper_arm(1),
    "forearm_l": lambda: _forearm(-1), "forearm_r": lambda: _forearm(1),
    "thigh_l": lambda: _thigh(-1), "thigh_r": lambda: _thigh(1),
    "shin_l": lambda: _shin(-1), "shin_r": lambda: _shin(1),
}
