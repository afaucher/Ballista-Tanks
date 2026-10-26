"""The troop's body: the torso (a short, barrel-chested team tunic, an iron collar under the helmet
and iron pauldrons, like the knight's), origin at the waist; and the pelvis (the tunic's skirt with
a brown belt and an iron buckle, gunmetal hose underneath), origin at the hip centre (the root).
"""

from mathutils import Matrix

import common
import troop_common
import troop_dims as D


def _squash(k):
    """Godot-space scale of the depth (z) by k, round the y axis."""
    return Matrix.Diagonal((1, 1, k, 1))


def torso():
    tunic = common.MeshBuilder("tunic")
    tunic.lathe([
        (0.0, 0.035, "team"),
        (0.15, 0.035, "team"),
        (0.162, 0.1, "team"),
        (0.165, 0.18, "team"),
        (0.155, 0.235, "team"),
        (0.11, 0.28, "team"),
        (0.05, 0.305, "team"),
        (0.0, 0.31, "team"),
    ], axis="y", segments=24, xf=_squash(D.TORSO_SQUASH))
    armour = common.MeshBuilder("armour")
    armour.lathe([
        (0.0, 0.262, "iron"),
        (0.105, 0.262, "iron"),
        (0.098, 0.295, "iron"),
        (0.0, 0.3, "iron"),
    ], axis="y", segments=20, xf=_squash(0.9))
    for s in (-1, 1):
        armour.sphere(D.mirror(D.PAULDRON, s), 0.075, "iron", scale=(1.15, 0.8, 1.1))
    return troop_common.piece([tunic.build(bevel=0.015, segments=2), armour.build(bevel=0.01, segments=2)],
                              "torso", D.WAIST, texture_size=512)


def pelvis():
    skirt = common.MeshBuilder("skirt")
    skirt.lathe([
        (0.0, 0.07, "team"),
        (0.15, 0.07, "team"),
        (0.165, 0.05, "wood_dark"),           # belt
        (0.168, 0.0, "team"),
        (0.178, -0.04, "team"),
        (0.19, -0.075, "team"),               # hem
        (0.17, -0.085, "gunmetal"),
        (0.0, -0.085, "gunmetal"),
    ], axis="y", segments=24, xf=_squash(0.85))
    buckle = common.MeshBuilder("buckle")
    buckle.box((0, 0.026, -0.145), (0.05, 0.044, 0.02), "iron")
    return troop_common.piece([skirt.build(bevel=0.012, segments=2), buckle.build(bevel=0.006, segments=2)],
                              "pelvis", (0, 0, 0))


PIECES = {"torso": torso, "pelvis": pelvis}
