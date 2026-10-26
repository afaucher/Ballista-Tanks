"""The ballista, in ballista-pitch space (origin = dims.PIVOT, -z forward), after the concept:
a long grooved stock with iron bands, a chunky arched wooden cradle round it between the bow and
the driver, and a huge bow: a strapped riser and two thick limbs that sweep out and curl back to
iron-capped tips wrapped in rope. The string and bolt are not here: TankModel draws them (they
move), tying the string on at dims.BOW_TIP.
"""

import math

from mathutils import Matrix, Vector

import common
import dims

LIMB_HALF = (0.11, 0.17)   # half thickness (in plan), half height of a limb at the riser: flat and tall
LIMB_TAPER = 0.72          # limb scale at the tip


def bezier(p, t):
    a, b, c, d = (Vector(x) for x in p)
    u = 1 - t
    return a * u ** 3 + b * 3 * u * u * t + c * 3 * u * t * t + d * t ** 3


def limb_path(side):
    tip = Vector(dims.BOW_TIP)
    z = dims.BOW_Z
    ctrl = [(0.2, 0.0, z), (1.15, 0.0, z - 0.26), (tip.x + 0.02, tip.y, z - 0.06), (tip.x, tip.y, tip.z)]
    return [Vector((side * p[0], p[1], p[2])) for p in ctrl]


def rounded_rect(hu, hv, r, n=3):
    pts = []
    for cu, cv, a0 in ((hu - r, hv - r, 0), (-hu + r, hv - r, 90), (-hu + r, -hv + r, 180), (hu - r, -hv + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cu + r * math.cos(a), cv + r * math.sin(a)))
    return pts


def frame_at(path, t):
    p = bezier(path, t)
    tan = (bezier(path, min(t + 0.01, 1)) - bezier(path, max(t - 0.01, 0))).normalized()
    side = tan.cross(Vector((0, 1, 0))).normalized()
    up = side.cross(tan).normalized()
    return p, tan, side, up


def basis_xf(origin, x, y, z):
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], origin[i]
    return m


SLOT = (0.1, 0.26)   # the string's slot through the cradle walls (heights in pitch space)


def build():
    wood = common.MeshBuilder("ballista_wood")
    s = dims.STOCK
    z0, z1 = s["z"]
    top, g = s["y_top"], s["groove"]
    hw, gw = s["w"] / 2, 0.065
    bottom = top - s["h"]
    # Stock: a U-section (groove on top) extruded along z. extrude_x + a 90 degree turn about y
    # maps profile (z, y) -> (x, y) and the extrusion x -> -z.
    groove = [(-hw, bottom), (hw, bottom), (hw, top), (gw, top), (gw, top - g), (-gw, top - g), (-gw, top), (-hw, top)]
    wood.extrude_x(groove, -z1, -z0, "wood", xf=common.rotate("y", 90))

    # Cradle: two tall arched side walls round the stock, slotted where the string runs (it
    # slides back through them on the draw and snaps forward through them to push the bolt), a
    # cross beam and a back rail. They stop well short of the seat box.
    for side in (-1, 1):
        x = side * 0.31
        lower = [(-0.62, -0.15), (0.24, -0.15), (0.24, SLOT[0]), (-0.62, SLOT[0])]
        post = [(0.17, SLOT[0]), (0.24, SLOT[0]), (0.24, SLOT[1]), (0.17, SLOT[1])]
        upper = [(-0.62, SLOT[1])]
        for i in range(1, 12):
            a = math.pi * i / 12
            upper.append((-0.19 - 0.43 * math.cos(a), SLOT[1] + 0.38 * math.sin(a)))   # tall, like the concept's frame
        upper.append((0.24, SLOT[1]))
        for prof in (lower, post, upper):
            wood.extrude_x(prof, x - 0.065, x + 0.065, "wood")
    wood.box((0, -0.05, -0.72), (0.62, 0.2, 0.14), "wood", grain_axis=0)
    wood.box((0, 0.02, 0.18), (0.62, 0.16, 0.12), "wood", grain_axis=0)
    # Riser across the stock where the bow sits.
    wood.box((0, 0.0, dims.BOW_Z), (0.52, 0.34, 0.32), "wood", grain_axis=0)
    wood_obj = wood.build(bevel=0.035, segments=3, angle=30.0)

    iron = common.MeshBuilder("ballista_iron")
    for z in (z0 + 0.12, -0.95, z1 - 0.12):   # bands round the stock (under the groove)
        iron.box((0, bottom + 0.09, z), (s["w"] + 0.05, 0.2, 0.08), "iron")
    for x in (-0.15, 0.15):               # straps round the riser
        iron.box((x, 0.0, dims.BOW_Z), (0.07, 0.38, 0.36), "iron")
    for side in (-1, 1):                  # corner caps on the cradle walls
        x = side * 0.31
        iron.box((x, 0.04, -0.6), (0.16, 0.12, 0.12), "iron")
        iron.box((x, -0.11, 0.2), (0.16, 0.1, 0.12), "iron")
    iron.cylinder((0, dims.GEAR["y"], dims.GEAR["z"]), 0.05, 0.75, "iron", axis="x", segments=10)   # winch axle through the cradle
    iron_obj = iron.build(bevel=0.02, segments=2, angle=30.0)

    limbs = common.MeshBuilder("ballista_limbs")
    caps = common.MeshBuilder("ballista_caps")
    rope = common.MeshBuilder("ballista_rope")
    profile = rounded_rect(LIMB_HALF[0], LIMB_HALF[1], 0.045)
    n = 24
    for side in (-1, 1):
        path = limb_path(side)
        pts = [bezier(path, i / n) for i in range(n + 1)]
        scales = [1.0 + (LIMB_TAPER - 1.0) * (i / n) ** 1.5 for i in range(n + 1)]
        # Start inside the riser so the joint is buried.
        pts[0] = pts[0] - Vector((side * 0.12, 0, 0))
        limbs.sweep(pts, profile, "wood", scales=scales, grain=True)

        # Iron cap on the tip, aligned with the limb's end.
        p, tan, sd, up = frame_at(path, 1.0)
        cap = basis_xf(p, sd, up, tan)
        caps.box((0, 0, 0.02), (0.34, 0.4, 0.3), "iron", xf=cap)
        caps.box((0, 0, 0.19), (0.26, 0.3, 0.06), "iron", xf=cap)

        # Rope coiled round the limb short of the cap.
        coil = []
        turns, t0, t1 = 5.0, 0.7, 0.9
        steps = 90
        for i in range(steps + 1):
            t = t0 + (t1 - t0) * i / steps
            q, _, sdq, upq = frame_at(path, t)
            sc = 1.0 + (LIMB_TAPER - 1.0) * t ** 1.5
            a = 2 * math.pi * turns * i / steps
            coil.append(q + sdq * math.cos(a) * (LIMB_HALF[0] * sc + 0.035)
                        + upq * math.sin(a) * (LIMB_HALF[1] * sc + 0.035))
        circle = [(0.035 * math.cos(2 * math.pi * k / 8), 0.035 * math.sin(2 * math.pi * k / 8)) for k in range(8)]
        rope.sweep(coil, circle, "rope", rope_turns=7.0, grain=False)
    limbs_obj = limbs.build()
    caps_obj = caps.build(bevel=0.03, segments=3, angle=30.0)
    rope_obj = rope.build()
    return common.finish([wood_obj, iron_obj, limbs_obj, caps_obj, rope_obj], "ballista", texture_size=1024)
