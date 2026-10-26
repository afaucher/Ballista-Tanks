"""Render built parts for a look: build/part_previews/<part>.png (front-left 3/4, like the concept).

    blender -b --factory-startup --python tools/parts/preview.py -- hull knight
    (.\\tools\\parts\\preview.ps1 hull knight)
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def preview(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "tank", name + ".glb"))
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    centre = (lo + hi) / 2
    size = max((hi - lo).length, 0.3)
    # Front-left, above: Godot (-x, +y, -z) is Blender (-x, +y, +z)... front is Godot -z = Blender +y.
    cam_dir = Vector((-0.55, 0.62, 0.42)).normalized()
    if name.startswith("wheel"):   # wheels are built facing +x (the right side)
        cam_dir.x = -cam_dir.x
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = centre + cam_dir * size * 2.1
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    for d, e in (((-0.4, 0.5, 0.8), 3.0), ((0.6, -0.3, 0.5), 1.0)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = e
        sun.rotation_euler = Vector(d).to_track_quat("-Z", "Y").to_euler()
        sun.rotation_euler = (-Vector(d)).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.7, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc = bpy.context.scene
    sc.world = world
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    sc.view_settings.view_transform = "Standard"
    out = os.path.join(ROOT, "build", "part_previews", name + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", out)


for n in sys.argv[sys.argv.index("--") + 1:]:
    preview(n)
