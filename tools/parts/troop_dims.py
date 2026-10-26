"""The foot troop's skeleton, in Godot troop space: metres, origin at the pelvis (the hip centre),
x right (the troop's right), y up, -z forward, standing rest pose. The single source of truth:
the troop_*.py part scripts build to these numbers, and build.py (`build.ps1 troop`) writes
assets/troop/dims.json for the game.

About 2.5 heads tall: a bucket helmet as big as the torso, stubby legs, short arms hanging a
little out from the sides, a spear upright in the right mitten, a round shield on the left, after
docs/design/troops.md. Right-side joints are given; the left side is the mirror (x -> -x).

The numbers below are the model's; the built troop is SCALE times bigger, so its helmet is the
tank driver's size (dims.HELMET_R): 1.51 m to the helmet top. troop_common.piece() scales each
finished shape, and game_dims() writes scaled numbers (masses by SCALE cubed).
"""

SCALE = 0.31 / 0.22       # the knight's helmet radius over the model's

GROUND_Y = -0.34          # boot soles

# Joints (right side; mirror x for the left).
HIP = (0.075, 0.0, 0.0)
KNEE = (0.075, -0.15, 0.0)
ANKLE = (0.075, -0.27, 0.0)
WAIST = (0.0, 0.06, 0.0)
SHOULDER = (0.175, 0.245, 0.0)
ELBOW = (0.222, 0.135, 0.0)
WRIST = (0.255, 0.065, -0.025)
HAND = (0.27, 0.03, -0.035)      # mitten centre: the grip of the spear (right) and shield (left);
                                 # the arms hang a little out, so the upright spear clears the helmet
NECK = (0.0, 0.30, 0.0)

# Head: a steel bucket helmet, flat top, face slot.
HELMET_Y = (0.27, 0.73)
HELMET_R = 0.22
PLUME = (0.0, HELMET_Y[1] + 0.035, 0.0)   # top of the plume socket

# Body.
TORSO_SQUASH = 0.82       # the tunic's depth / width
PAULDRON = (0.165, 0.245, 0.0)

# Kit.
SHIELD_R = 0.15
SHIELD_FACING = (-0.6, 0.0, -0.8)   # the shield's front normal: forward and out to the left
SHIELD_OFFSET = 0.06                # shield centre in front of the grip, along the facing
SPEAR_TOP = HAND[1] + 1.1           # tip of the blade, pelvis space
SPEAR_BUTT = GROUND_Y + 0.01


def mirror(p, side):
    """A right-side point on the given side (+1 right, -1 left)."""
    return (p[0] * side, p[1], p[2])


def _sub(a, b):
    return [round(a[i] - b[i], 4) for i in range(3)]


def _mid(a, b):
    return [round((a[i] + b[i]) / 2, 4) for i in range(3)]


def pieces():
    """Every piece in parent-before-child order: name -> parent, joint (the piece's origin in the
    rest pose, pelvis space), box (rough ragdoll collision box: size, and centre relative to the
    piece's origin) and mass (kg). Heavy head, about as much as the torso."""
    sx, sz = SHIELD_FACING[0], SHIELD_FACING[2]
    out = {
        "pelvis": {"parent": "", "joint": (0, 0, 0), "size": (0.28, 0.17, 0.28), "centre": (0, -0.005, 0), "mass": 1.5},
        "torso": {"parent": "pelvis", "joint": WAIST, "size": (0.31, 0.27, 0.27), "centre": (0, 0.11, 0), "mass": 2.5},
        "head": {"parent": "torso", "joint": NECK, "size": (0.44, 0.49, 0.44),
                 "centre": (0, (HELMET_Y[0] + HELMET_Y[1]) / 2 - NECK[1] + 0.01, -0.01), "mass": 3.0},
        "plume": {"parent": "head", "joint": PLUME, "size": (0.09, 0.22, 0.32), "centre": (0, 0.1, 0.125), "mass": 0.05},
    }
    for side, s in (("r", 1), ("l", -1)):
        sh, el, ha = mirror(SHOULDER, s), mirror(ELBOW, s), mirror(HAND, s)
        out["upper_arm_" + side] = {"parent": "torso", "joint": sh, "size": (0.09, 0.15, 0.09),
                                    "centre": _mid((0, 0, 0), _sub(el, sh)), "mass": 0.4}
        out["forearm_" + side] = {"parent": "upper_arm_" + side, "joint": el, "size": (0.09, 0.19, 0.13),
                                  "centre": _mid((0, 0, 0), _sub(ha, el)), "mass": 0.4}
    for side, s in (("r", 1), ("l", -1)):
        hip, knee = mirror(HIP, s), mirror(KNEE, s)
        out["thigh_" + side] = {"parent": "pelvis", "joint": hip, "size": (0.11, 0.18, 0.11),
                                "centre": (0, -0.065, 0), "mass": 0.9}
        out["shin_" + side] = {"parent": "thigh_" + side, "joint": knee, "size": (0.11, 0.2, 0.17),
                               "centre": (0, (GROUND_Y - knee[1]) / 2, -0.02), "mass": 0.8}
    out["shield"] = {"parent": "forearm_l", "joint": mirror(HAND, -1),
                     "size": (0.18, 0.24, 0.12),   # the middle of the turned disc: clear of the body and arm
                     "centre": (sx * SHIELD_OFFSET, -0.04, sz * SHIELD_OFFSET), "mass": 0.5}
    out["spear"] = {"parent": "forearm_r", "joint": HAND, "size": (0.05, SPEAR_TOP - SPEAR_BUTT, 0.05),
                    "centre": (0, (SPEAR_TOP + SPEAR_BUTT) / 2 - HAND[1], 0), "mass": 0.5}
    return out


def game_dims():
    """What the game needs, written to assets/troop/dims.json."""
    def r(v):
        return [round(float(x), 4) for x in v]

    ps = {}
    all_pieces = pieces()
    for name, p in all_pieces.items():
        # Troop (scripts/troops/troop.gd) nests pieces: joint in the parent's space, the pelvis's
        # from the troop origin on the ground between the feet. No piece is rotated at rest.
        parent = all_pieces[p["parent"]]["joint"] if p["parent"] else (0, GROUND_Y, 0)
        ps[name] = {
            "parent": p["parent"],
            "joint": r([(p["joint"][i] - parent[i]) * SCALE for i in range(3)]),
            "rest": r([x * SCALE for x in p["joint"]]),
            "box": r([x * SCALE for x in p["size"]]),
            "center": r([x * SCALE for x in p["centre"]]),
            "mass": round(p["mass"] * SCALE ** 3, 3),
        }
    return {
        "_doc": "Troop pieces: assets/troop/<name>.glb, origin at the joint, +Y up, -Z forward, metres. "
                "joint: the origin in the parent's space (the pelvis's from the troop origin on the ground); "
                "rest: the origin in the standing rest pose relative to the pelvis origin (the hip centre); "
                "box, center: rough collision box size and centre, relative to the piece's origin; mass in kg. "
                "Surfaces with material \"team\" take the team colour.",
        "ground_y": round(GROUND_Y * SCALE, 4),
        "height": round((HELMET_Y[1] - GROUND_Y) * SCALE, 3),
        "team_material": "team",
        "pieces": ps,
    }
