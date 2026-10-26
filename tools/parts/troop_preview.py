"""Render the assembled troop for a look, with preview.py's studio (same lights, grey world,
Cycles): the pieces from assets/troop/ placed at their rest positions from assets/troop/dims.json, seen
front, side (from its right), back (orthographic) and front-left three-quarter (perspective), and
from the front beside the tank's driver (assets/tank/knight.glb, helmets level: they should match).
Writes build/previews/troop_<view>.png and all five side by side, build/previews/troop_sheet.png.

    blender -b --factory-startup --python tools/parts/troop_preview.py
"""

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dims  # noqa: E402  (the knight's helmet)
import troop_dims  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "troop")
OUT = os.path.join(ROOT, "build", "previews")
W, H = 600, 800
# view: (camera direction from the troop in Blender space (Godot -z forward is Blender +y), ortho)
VIEWS = {
    "front": ((0, 1, 0.08), True),
    "side": ((1, 0, 0.08), True),
    "back": ((0, -1, 0.08), True),
    "three_quarter": ((-0.55, 0.62, 0.42), False),
}


def assemble():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with open(os.path.join(SRC, "dims.json"), encoding="utf-8") as f:
        d = json.load(f)
    for name, p in d["pieces"].items():
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
        x, y, z = p["rest"]
        for o in set(bpy.context.scene.objects) - before:
            if o.parent is None:
                o.location = Vector((x, -z, y))    # Godot -> Blender
    return d


def studio():
    for d, e in (((-0.4, 0.5, 0.8), 3.0), ((0.6, -0.3, 0.5), 1.0)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = e
        sun.rotation_euler = (-Vector(d)).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.7, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc = bpy.context.scene
    sc.world = world
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    return cam


def main():
    d = assemble()
    cam = studio()
    spear = d["pieces"]["spear"]
    lo, hi = d["ground_y"], spear["rest"][1] + spear["center"][1] + spear["box"][1] / 2
    centre = Vector((0, 0, (lo + hi) / 2))
    span = (hi - lo) * 1.1
    os.makedirs(OUT, exist_ok=True)
    panels = []
    for view, (direction, ortho) in VIEWS.items():
        panels.append(shot(cam, view, direction, ortho, centre, span, W))
    # Beside the knight: its helmet bottom level with the troop's, to the troop's right.
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "tank", "knight.glb"))
    knight = [o for o in bpy.context.scene.objects if o.parent is None and o.name.startswith("knight")][0]
    k = dims.KNIGHT
    dy = troop_dims.HELMET_Y[0] * troop_dims.SCALE - dims.HELMET_Y[0]
    knight.location = Vector((0.9 - k["x"], k["z"], dy))     # Godot (x, y, z) -> Blender (x, -z, y)
    panels.append(shot(cam, "with_knight", VIEWS["front"][0], True, centre + Vector((0.45, 0, 0)), span, W * 3 // 2))
    sheet = np.concatenate(panels, axis=1)
    out = bpy.data.images.new("troop_sheet", sheet.shape[1], sheet.shape[0], alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = os.path.join(OUT, "troop_sheet.png")
    out.file_format = "PNG"
    out.save()
    print("PREVIEW", out.filepath_raw)


def shot(cam, view, direction, ortho, centre, span, width):
    """Render one view to build/previews/troop_<view>.png; returns its pixels (H x width)."""
    sc = bpy.context.scene
    sc.render.resolution_x = width
    direction = Vector(direction).normalized()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = span * max(width, H) / H    # the scale spans the longer side
        cam.location = centre + direction * 5
    else:
        cam.data.type = "PERSP"
        cam.data.lens = 50
        cam.location = centre + direction * (span / 2 / math.tan(math.atan(18 / 50)) * 1.05)
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(OUT, "troop_%s.png" % view)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", path)
    img = bpy.data.images.load(path)
    px = np.empty(width * H * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(H, width, 4)


if __name__ == "__main__":
    main()
