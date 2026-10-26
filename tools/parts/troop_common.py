"""Helpers shared by the troop part scripts (troop_*.py). Pieces are modelled in troop space
(troop_dims: origin at the pelvis) and moved so their origin sits on their joint.

A troop module exposes PIECES = {piece name: build function}; `build.ps1 troop` exports each to
assets/troop/<name>.glb.
"""

from mathutils import Matrix, Vector

import common


def limb(mb, a, b, profile, segments=16):
    """A lathe from joint a to joint b. profile: [(radius, t, material)], t from 0 (a) to 1 (b),
    may run past either end; radius 0 closes it."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    mb.lathe([(r, t * d.length, m) for r, t, m in profile], axis="y", segments=segments,
             xf=common.translate(a) @ rot)


def piece(objs, name, origin, texture_size=256):
    """Move the troop-space objects so `origin` is at (0, 0, 0), then finish (join, smooth, UV,
    bake)."""
    shift = Matrix.Translation(-common.to_blender(origin))
    for o in objs:
        o.data.transform(shift)
    return common.finish(objs, name, texture_size=texture_size)
