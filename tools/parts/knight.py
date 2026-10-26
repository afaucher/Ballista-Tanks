"""The knight driver, after the concept: a big steel bucket helmet (flat top, flaring slightly
upward) with a wide face slot between a brow band and a visor band, the face showing through
(skin, dark eyes, rosy cheeks), breathing slits in the visor band and a round boss on each side;
a small blue tunic with a belt, iron pauldrons and arms, brown gloves gripping a wooden lever in
front of him. Hull space, seated at dims.KNIGHT. Big head, small body.

The lever's handle is at hull (0, 1.8, 0.45): the gloves sit either side of it.
"""

import math

import common
import dims

K = dims.KNIGHT
CX, CZ = K["x"], K["z"]
HY0, HY1 = dims.HELMET_Y
R = dims.HELMET_R


def _on_helmet(theta_deg, y, r):
    """A point on a circle of radius r round the helmet axis; theta 0 is straight ahead (-z)."""
    t = math.radians(theta_deg)
    return (CX + math.sin(t) * r, y, CZ - math.cos(t) * r)


def _arc_band(mb, y, height, radius, thick, half_angle, mat, steps=12):
    """A curved band hugging the helmet's front, half_angle either side of straight ahead."""
    path = [_on_helmet(-half_angle + 2 * half_angle * i / steps, y, radius) for i in range(steps + 1)]
    prof = [(-thick / 2, -height / 2), (thick / 2, -height / 2), (thick / 2, height / 2), (-thick / 2, height / 2)]
    mb.sweep(path, prof, mat, grain=False)


def _helmet():
    mb = common.MeshBuilder("helmet")
    mb.lathe([
        (0.0, HY0, "steel"),
        (R - 0.03, HY0, "steel"),
        (R - 0.02, HY0 + 0.04, "steel"),
        (R + 0.01, HY1 - 0.12, "steel"),
        (R + 0.025, HY1 - 0.07, "steel"),    # a lip just under the top
        (R + 0.005, HY1 - 0.02, "steel"),
        (R - 0.08, HY1, "steel"),
        (0.0, HY1 + 0.005, "steel"),          # flat top, barely domed
    ], center=(CX, 0, CZ), axis="y", segments=28)
    return mb.build(bevel=0.02, segments=3, angle=25)


def _face():
    """Brow band, the face in the slot, visor band with slits, side bosses."""
    slot_lo, slot_hi = HY0 + 0.21, HY0 + 0.36
    yc = (slot_lo + slot_hi) / 2
    bands = common.MeshBuilder("helmet_bands")
    _arc_band(bands, slot_hi + 0.035, 0.07, R + 0.025, 0.05, 62, "steel")         # brow
    _arc_band(bands, slot_lo - 0.09, 0.18, R + 0.03, 0.06, 66, "steel")          # visor band
    for side in (-1, 1):
        p = _on_helmet(side * 90, yc, R + 0.015)
        t = math.radians(side * 90)
        bands.cylinder(p, 0.05, 0.05, "steel", axis="x", segments=16)            # side boss
    face = common.MeshBuilder("face")
    _arc_band(face, yc, slot_hi - slot_lo, R + 0.0, 0.03, 52, "skin")
    _arc_band(face, slot_hi - 0.012, 0.025, R + 0.012, 0.012, 52, "dark")        # shadow under the brow
    details = common.MeshBuilder("face_details")
    for side in (-1, 1):
        details.sphere(_on_helmet(side * 17, yc + 0.015, R + 0.012), 0.03, "dark", scale=(1, 1.25, 0.7), segments=12, rings=8)
        details.sphere(_on_helmet(side * 30, yc - 0.045, R + 0.012), 0.032, "cheek", scale=(1, 0.8, 0.5), segments=12, rings=8)
    details.sphere(_on_helmet(0, yc - 0.02, R + 0.02), 0.03, "skin", scale=(1, 1, 0.9), segments=12, rings=8)  # nose
    slits = common.MeshBuilder("slits")
    for ang in (-24, -8, 8, 24):
        p = _on_helmet(ang, slot_lo - 0.1, R + 0.06)
        xf = common.translate(p) @ common.rotate("y", -ang)
        slits.box((0, 0, 0), (0.035, 0.1, 0.02), "dark", xf=xf)
    return [bands.build(bevel=0.012, segments=2), face.build(), details.build(), slits.build(bevel=0.006)]


def _body():
    body = common.MeshBuilder("tunic")
    y0 = K["y"] + 0.2
    body.lathe([
        (0.0, y0, "team"),
        (0.25, y0, "team"),
        (0.265, y0 + 0.16, "wood_dark"),      # belt
        (0.27, y0 + 0.22, "team"),
        (0.27, y0 + 0.33, "team"),
        (0.25, HY0 - 0.08, "team"),
        (0.13, HY0 + 0.02, "team"),
        (0.0, HY0 + 0.02, "team"),
    ], center=(CX, 0, CZ), axis="y", segments=24)
    armour = common.MeshBuilder("armour")
    hands = common.MeshBuilder("hands")
    sy = HY0 - 0.08
    for side in (-1, 1):
        armour.sphere((CX + side * 0.27, sy, CZ + 0.01), 0.15, "iron", scale=(1.1, 0.75, 1.05))
        path = [(CX + side * 0.29, sy - 0.05, CZ + 0.03), (CX + side * 0.33, sy - 0.22, CZ - 0.12),
                (CX + side * 0.2, sy - 0.17, CZ - 0.3), (CX + side * 0.09, sy - 0.12, CZ - 0.38)]
        circle = [(0.07 * math.cos(a), 0.07 * math.sin(a)) for a in [i * math.tau / 10 for i in range(10)]]
        armour.sweep(path, circle, "iron", up=(0, 0, 1), grain=False)
        hands.sphere((CX + side * 0.075, sy - 0.12, CZ - 0.4), 0.085, "wood_dark", scale=(0.95, 1.1, 1.15))
    lever = common.MeshBuilder("lever")
    lz = CZ - 0.4
    lever.cylinder((CX, (K["y"] + sy - 0.05) / 2, lz), 0.03, sy - 0.05 - K["y"], "iron", axis="y", segments=12)
    lever.cylinder((CX, sy - 0.12, lz), 0.045, 0.32, "wood", axis="y", segments=14)
    return [body.build(bevel=0.02, segments=2), armour.build(bevel=0.015, segments=2),
            hands.build(), lever.build(bevel=0.012, segments=2)]


def build():
    return common.finish([_helmet()] + _face() + _body(), "knight", texture_size=512)
