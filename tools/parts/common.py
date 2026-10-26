"""Toolkit for tank part scripts. Runs inside Blender (bpy); see build.py.

Build geometry with a MeshBuilder in GODOT coordinates (x right, y up, -z forward; metres). It
converts to Blender's Z-up, and the glTF exporter converts back, so what you write is what
TankModel gets. Material names are mat_keys (team, wood, iron, ...): tools/compare.py scores by
them, and TankModel tints every "team" surface with the team colour.

    mb = MeshBuilder("hull")
    mb.box((0, 0.7, 0), (1.3, 0.8, 2.9), "team")
    obj = mb.build(bevel=0.04)          # chamfer every edge sharper than 30 degrees
    finish(obj)                          # smooth shading by angle, UV unwrap, bake STYLES to a texture

Texturing: each material has a STYLE (base, dark and edge colours, grain or rope stripes, noise).
finish() renders it with Cycles into one albedo texture per part: ambient occlusion darkens
creases, a bevel-normal edge mask lightens edges, the hand-painted toy look of the concept.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

# Material styles. Colours are sRGB hex. "team" is baked pale and tinted in Godot.
STYLES = {
    "team":      {"base": "dfe6f4", "dark": "7d8aa8", "edge": "ffffff", "rough": 0.3, "metal": 0.0, "noise": 0.03},
    "wood":      {"base": "76492b", "dark": "5c260f", "edge": "b26a3c", "rough": 0.7, "metal": 0.0, "grain": 1.0},
    "wood_dark": {"base": "6e3418", "dark": "45200c", "edge": "945634", "rough": 0.75, "metal": 0.0, "grain": 1.0},
    "iron":      {"base": "4c4d59", "dark": "35363f", "edge": "aeb2c0", "rough": 0.45, "metal": 0.15, "noise": 0.06},
    "gunmetal":  {"base": "433e48", "dark": "29262f", "edge": "a29fb4", "rough": 0.4, "metal": 0.15, "noise": 0.04},
    "steel":     {"base": "5e6a7b", "dark": "5d6679", "edge": "dfe7ef", "rough": 0.3, "metal": 0.2, "noise": 0.03},
    "track":     {"base": "4a3a33", "dark": "241a16", "edge": "75604f", "rough": 0.9, "metal": 0.0, "noise": 0.08},
    "rope":      {"base": "98744b", "dark": "5f4426", "edge": "c09e70", "rough": 0.9, "metal": 0.0, "rope": 1.0},
    "skin":      {"base": "f1b18d", "dark": "c27b5b", "edge": "ffd6bd", "rough": 0.6, "metal": 0.0},
    "cheek":     {"base": "ee8b78", "dark": "c86b5b", "edge": "f6ab9a", "rough": 0.6, "metal": 0.0},
    "dark":      {"base": "1d1c22", "dark": "0c0c10", "edge": "3a3944", "rough": 0.5, "metal": 0.0},
    "cloth":     {"base": "eee7d8", "dark": "b3a88f", "edge": "ffffff", "rough": 0.8, "metal": 0.0, "noise": 0.04},
}

AO_DISTANCE = 0.25
EDGE_RADIUS = 0.02


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def to_blender(p):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h):
    return (*[srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)], 1.0)


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m


# --- Geometry ---------------------------------------------------------------------------------

class MeshBuilder:
    """Collects vertices and faces in Godot space. Every vertex carries two float attributes the
    bake reads: "grain" (wood grain coordinate) and "rope" (rope twist coordinate)."""

    def __init__(self, name):
        self.name = name
        self.verts = []        # Godot-space Vector
        self.grain = []
        self.rope = []
        self.faces = []        # (indices, material)

    def v(self, p, grain=0.0, rope=0.0):
        self.verts.append(Vector(p))
        self.grain.append(grain)
        self.rope.append(rope)
        return len(self.verts) - 1

    def face(self, idx, mat):
        self.faces.append((tuple(idx), mat))

    # Primitives. `xf` is an optional 4x4 Matrix (Godot space) applied to the primitive.

    def box(self, center, size, mat, xf=None, grain_axis=None):
        """Axis-aligned box (then xf). grain_axis: the long axis of a wooden beam (0, 1 or 2)."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        corners = [Vector((sx * hx, sy * hy, sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        base = len(self.verts)
        for c in corners:
            p = Vector(center) + c
            if xf is not None:
                p = xf @ p
            self.v(p, self._grain(c, grain_axis))
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in quads:
            self.face([base + i for i in q], mat)

    def lathe(self, profile, center=(0, 0, 0), axis="x", segments=24, xf=None, phase=0.0):
        """Surface of revolution. profile: [(radius, along_axis, material)]; radius 0 closes it.
        A band takes the material of its first point."""
        rot = _axis_basis(axis)
        rings = []
        for r, a, _ in profile:
            ring = []
            n = 1 if r == 0 else segments
            for i in range(n):
                t = phase + 2 * math.pi * i / segments
                local = rot @ Vector((a, r * math.cos(t), r * math.sin(t)))
                p = Vector(center) + local
                if xf is not None:
                    p = xf @ p
                ring.append(self.v(p))
            rings.append(ring)
        for k in range(len(rings) - 1):
            ra, rb, mat = rings[k], rings[k + 1], profile[k][2]
            for i in range(segments):
                j = (i + 1) % segments
                if len(ra) == 1:
                    self.face([ra[0], rb[i], rb[j]], mat)
                elif len(rb) == 1:
                    self.face([ra[i], ra[j], rb[0]], mat)
                else:
                    self.face([ra[i], ra[j], rb[j], rb[i]], mat)

    def cylinder(self, center, radius, length, mat, axis="x", segments=16, xf=None, radius2=None):
        r2 = radius if radius2 is None else radius2
        h = length / 2
        self.lathe([(0, -h, mat), (radius, -h, mat), (r2, h, mat), (0, h, mat)], center, axis, segments, xf)

    def sphere(self, center, radius, mat, scale=(1, 1, 1), segments=16, rings=10, xf=None):
        base = len(self.verts)
        for k in range(rings + 1):
            phi = math.pi * k / rings
            for i in range(segments):
                t = 2 * math.pi * i / segments
                d = Vector((math.sin(phi) * math.cos(t) * scale[0], math.cos(phi) * scale[1],
                            math.sin(phi) * math.sin(t) * scale[2]))
                p = Vector(center) + d * radius
                if xf is not None:
                    p = xf @ p
                self.v(p)
        for k in range(rings):
            for i in range(segments):
                j = (i + 1) % segments
                a, b = base + k * segments, base + (k + 1) * segments
                self.face([a + i, a + j, b + j, b + i], mat)

    def extrude_x(self, poly_zy, x0, x1, mat, xf=None):
        """A side profile [(z, y), ...] (a closed polygon, either winding) extruded from x0 to x1."""
        n = len(poly_zy)
        a = [self.v(_xf(xf, (x0, y, z))) for z, y in poly_zy]
        b = [self.v(_xf(xf, (x1, y, z))) for z, y in poly_zy]
        self.face(a, mat)
        self.face(list(reversed(b)), mat)
        for i in range(n):
            j = (i + 1) % n
            self.face([a[i], a[j], b[j], b[i]], mat)

    def sweep(self, path, profile, mat, up=(0, 1, 0), closed=False, caps=True, rope_turns=0.0,
              grain=True, scales=None):
        """Sweep a closed 2D profile [(u, v)] along a path of points. u runs along the path's side
        vector (path tangent x up), v along its up. rope_turns > 0 writes twisted rope stripes;
        grain writes wood grain along the path. scales: optional per-point profile scale."""
        up = Vector(up)
        pts = [Vector(p) for p in path]
        n = len(pts)
        rings = []
        along = 0.0
        for i, p in enumerate(pts):
            if closed:
                t = (pts[(i + 1) % n] - pts[i - 1])
            else:
                t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            t.normalize()
            side = t.cross(up)
            if side.length < 1e-6:
                side = t.cross(Vector((1, 0, 0)))
            side.normalize()
            nup = side.cross(t).normalized()
            if i > 0:
                along += (pts[i] - pts[i - 1]).length
            s = 1.0 if scales is None else scales[i]
            ring = []
            for k, (u, v) in enumerate(profile):
                q = p + side * (u * s) + nup * (v * s)
                ang = k / len(profile)
                ring.append(self.v(q, grain=(along * 0.0 + u * 7.0 + v * 3.0) if grain else 0.0,
                                   rope=(along * rope_turns + ang) if rope_turns else 0.0))
            rings.append(ring)
        m = len(profile)
        segs = n if closed else n - 1
        for i in range(segs):
            ra, rb = rings[i], rings[(i + 1) % n]
            for k in range(m):
                l = (k + 1) % m
                self.face([ra[k], ra[l], rb[l], rb[k]], mat)
        if caps and not closed:
            self.face(rings[0], mat)
            self.face(list(reversed(rings[-1])), mat)

    @staticmethod
    def _grain(c, axis):
        if axis is None:
            return 0.0
        across = [i for i in range(3) if i != axis]
        return c[across[0]] * 7.0 + c[across[1]] * 3.0

    def build(self, bevel=0.0, segments=2, angle=30.0):
        mesh = bpy.data.meshes.new(self.name)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        mats = []
        for _, m in self.faces:
            if m not in mats:
                mats.append(m)
        for m in mats:
            obj.data.materials.append(material(m))
        bm = bmesh.new()
        g_layer = bm.verts.layers.float.new("grain")   # layers first: adding one invalidates verts
        r_layer = bm.verts.layers.float.new("rope")
        bverts = [bm.verts.new(to_blender(p)) for p in self.verts]
        bm.verts.ensure_lookup_table()
        for i, bv in enumerate(bverts):
            bv[g_layer] = self.grain[i]
            bv[r_layer] = self.rope[i]
        for idx, m in self.faces:
            try:
                f = bm.faces.new([bverts[i] for i in idx])
            except ValueError:
                continue   # duplicate face
            f.material_index = mats.index(m)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle)
            mod.harden_normals = False
            mod.miter_outer = "MITER_ARC"
            mod.use_clamp_overlap = True
        return obj


def _axis_basis(axis):
    """Matrix taking local (along, r_cos, r_sin) to Godot space for a lathe around `axis`."""
    if axis == "x":
        return Matrix(((1, 0, 0), (0, 1, 0), (0, 0, 1)))
    if axis == "y":
        return Matrix(((0, 1, 0), (1, 0, 0), (0, 0, 1)))
    return Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0)))


def _xf(xf, p):
    p = Vector(p)
    return p if xf is None else xf @ p


def translate(t):
    return Matrix.Translation(Vector(t))


def rotate(axis, deg):
    """A Godot-space rotation about "x", "y" or "z"."""
    return Matrix.Rotation(math.radians(deg), 4, axis.upper())


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


# --- Finishing: shading, UVs, baked texture ---------------------------------------------------

def finish(objs, name, texture_size=1024, smooth_angle=35.0, samples=16):
    """Join, smooth by angle, unwrap, and bake the STYLES into one albedo texture."""
    obj = join(objs if isinstance(objs, list) else [objs], name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    bake(obj, texture_size, samples)
    return obj


def bake(obj, size, samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.device = "CPU"
    sc.render.bake.margin = 8
    img = bpy.data.images.new(obj.name + "_albedo", size, size, alpha=False)
    for slot in obj.material_slots:
        _bake_tree(slot.material, img)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT")
    # A copy to look at (gitignored); the glb embeds the packed image.
    import os
    debug = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                         "build", "part_textures")
    os.makedirs(debug, exist_ok=True)
    img.filepath_raw = os.path.join(debug, obj.name + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    for slot in obj.material_slots:
        _final_tree(slot.material, img)


def _bake_tree(mat, img):
    """Emission = the painted colour: base, darkened by AO and grain/rope stripes, edges lit."""
    st = STYLES[mat.name.split(".")[0]]
    nt = mat.node_tree
    nt.nodes.clear()
    N = nt.nodes
    L = nt.links
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L.new(emit.outputs[0], out.inputs["Surface"])

    def rgb(h):
        n = N.new("ShaderNodeRGB")
        n.outputs[0].default_value = hex_rgba(h)
        return n.outputs[0]

    def math_node(op, a, b=None, clamp=False):
        n = N.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, x in enumerate((a, b)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                L.new(x, n.inputs[i])
        return n.outputs[0]

    def mix(fac, a, b):
        n = N.new("ShaderNodeMix")
        n.data_type = "RGBA"
        if isinstance(fac, (int, float)):
            n.inputs[0].default_value = fac
        else:
            L.new(fac, n.inputs[0])
        L.new(a, n.inputs[6])
        L.new(b, n.inputs[7])
        return n.outputs[2]

    color = rgb(st["base"])
    dark = rgb(st["dark"])
    # Painted variation: soft noise in object space.
    if st.get("noise"):
        noise = N.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 4.0
        nf = math_node("MULTIPLY", math_node("SUBTRACT", noise.outputs[0], 0.5), st["noise"] * 4.0)
        color = mix(math_node("ABSOLUTE", nf, clamp=True), color, dark)
    # Wood grain: stripes along the beam from the "grain" attribute, wobbled by noise.
    if st.get("grain"):
        attr = N.new("ShaderNodeAttribute")
        attr.attribute_name = "grain"
        noise = N.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 2.5
        noise.inputs["Detail"].default_value = 3.0
        wob = math_node("MULTIPLY", noise.outputs[0], 2.5)
        s = math_node("SINE", math_node("MULTIPLY", math_node("ADD", attr.outputs["Fac"], wob), 9.0))
        stripe = math_node("POWER", math_node("MULTIPLY", math_node("ADD", s, 1.0), 0.5), 6.0)
        color = mix(math_node("MULTIPLY", stripe, 0.55), color, dark)
    # Rope: twisted strands from the "rope" attribute.
    if st.get("rope"):
        attr = N.new("ShaderNodeAttribute")
        attr.attribute_name = "rope"
        s = math_node("SINE", math_node("MULTIPLY", attr.outputs["Fac"], 2 * math.pi * 3.0))
        groove = math_node("POWER", math_node("MULTIPLY", math_node("ADD", s, 1.0), 0.5), 4.0)
        color = mix(math_node("MULTIPLY", groove, 0.8), color, dark)
    # Crevices darken.
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = AO_DISTANCE
    occl = math_node("MULTIPLY", math_node("SUBTRACT", 1.0, ao.outputs["AO"]), 0.75, clamp=True)
    color = mix(occl, color, dark)
    # Edges catch the light: where the rounded (bevel) normal leaves the true normal.
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = EDGE_RADIUS
    geo = N.new("ShaderNodeNewGeometry")
    dot = N.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L.new(bev.outputs[0], dot.inputs[0])
    L.new(geo.outputs["Normal"], dot.inputs[1])
    edge = math_node("MULTIPLY", math_node("SUBTRACT", 1.0, dot.outputs["Value"]), 9.0, clamp=True)
    # Only open, convex edges catch the light: a crease where two surfaces meet is occluded, so
    # gate the mask by AO (otherwise every join gets a bright line).
    edge = math_node("MULTIPLY", edge, math_node("POWER", ao.outputs["AO"], 3.0))
    color = mix(math_node("MULTIPLY", edge, 0.8), color, rgb(st["edge"]))
    L.new(color, emit.inputs["Color"])

    tex = N.new("ShaderNodeTexImage")
    tex.image = img
    N.active = tex
    tex.select = True


def _final_tree(mat, img):
    st = STYLES[mat.name.split(".")[0]]
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = st["rough"]
    bsdf.inputs["Metallic"].default_value = st["metal"]
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])


def export_glb(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_image_format="AUTO",
                              export_attributes=False)


def stats(obj):
    return "%s: %d verts, %d tris, materials %s" % (
        obj.name, len(obj.data.vertices), sum(len(p.vertices) - 2 for p in obj.data.polygons),
        [m.name for m in obj.data.materials])
