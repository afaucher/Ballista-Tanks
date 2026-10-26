"""The troop's head: the knight's steel bucket helmet, a size down and a touch taller for its body
(flat top, slight flare, a lip under the top), the face slot between a brow band and a visor band
with breathing slits, a cute face showing through (big dark eyes with a highlight, rosy cheeks, a
button nose), a round boss each side, and an iron plume socket on top. Origin at the neck.
"""

import math

import common
import troop_common
import troop_dims as D

HY0, HY1 = D.HELMET_Y
R = D.HELMET_R
SLOT = (HY0 + 0.15, HY0 + 0.29)      # the face slot, bigger for the face than the knight's


def _on(theta_deg, y, r):
    """A point on a circle of radius r round the helmet axis; theta 0 is straight ahead (-z),
    positive toward +x."""
    t = math.radians(theta_deg)
    return (math.sin(t) * r, y, -math.cos(t) * r)


def _arc_band(mb, y, height, radius, thick, half_angle, mat, steps=12):
    path = [_on(-half_angle + 2 * half_angle * i / steps, y, radius) for i in range(steps + 1)]
    prof = [(-thick / 2, -height / 2), (thick / 2, -height / 2), (thick / 2, height / 2), (-thick / 2, height / 2)]
    mb.sweep(path, prof, mat, grain=False)


def _helmet():
    mb = common.MeshBuilder("helmet")
    mb.lathe([
        (0.0, HY0, "steel"),
        (R - 0.025, HY0, "steel"),
        (R - 0.017, HY0 + 0.03, "steel"),
        (R + 0.008, HY1 - 0.095, "steel"),
        (R + 0.02, HY1 - 0.055, "steel"),     # a lip just under the top
        (R + 0.004, HY1 - 0.016, "steel"),
        (R - 0.06, HY1, "steel"),
        (0.0, HY1 + 0.004, "steel"),          # flat top, barely domed
    ], axis="y", segments=28)
    socket = common.MeshBuilder("socket")
    socket.cylinder((0, D.PLUME[1] - 0.025, 0), 0.028, 0.05, "iron", axis="y", segments=14)
    socket.cylinder((0, HY1 + 0.006, 0), 0.042, 0.012, "iron", axis="y", segments=14)
    return [mb.build(bevel=0.016, segments=3, angle=25), socket.build(bevel=0.006, segments=2)]


def _face():
    lo, hi = SLOT
    yc = (lo + hi) / 2
    bands = common.MeshBuilder("helmet_bands")
    _arc_band(bands, hi + 0.028, 0.055, R + 0.02, 0.04, 62, "steel")           # brow
    _arc_band(bands, lo - 0.068, 0.13, R + 0.022, 0.045, 66, "steel")         # visor band
    for side in (-1, 1):
        bands.cylinder(_on(side * 90, yc, R + 0.01), 0.038, 0.04, "steel", axis="x", segments=16)
    face = common.MeshBuilder("face")
    _arc_band(face, yc, hi - lo, R, 0.03, 52, "skin")
    _arc_band(face, hi - 0.01, 0.02, R + 0.01, 0.01, 52, "dark")              # shadow under the brow
    eyes = common.MeshBuilder("face_details")
    for side in (-1, 1):
        eyes.sphere(_on(side * 18, yc + 0.012, R + 0.012), 0.027, "dark", scale=(1, 1.3, 0.7), segments=12, rings=8)
        eyes.sphere(_on(side * 18 + 4, yc + 0.026, R + 0.03), 0.008, "cloth", segments=8, rings=6)   # highlight
        eyes.sphere(_on(side * 32, yc - 0.036, R + 0.01), 0.026, "cheek", scale=(1, 0.75, 0.5), segments=12, rings=8)
    eyes.sphere(_on(0, yc - 0.018, R + 0.016), 0.022, "skin", scale=(1, 0.95, 0.9), segments=12, rings=8)  # nose
    slits = common.MeshBuilder("slits")
    for ang in (-22, -8, 8, 22):
        p = _on(ang, lo - 0.075, R + 0.045)
        slits.box((0, 0, 0), (0.026, 0.075, 0.016), "dark", xf=common.translate(p) @ common.rotate("y", -ang))
    return [bands.build(bevel=0.01, segments=2), face.build(), eyes.build(), slits.build(bevel=0.005)]


def head():
    return troop_common.piece(_helmet() + _face(), "head", D.NECK, texture_size=512)


PIECES = {"head": head}
