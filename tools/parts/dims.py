"""The tank's dimensions, in Godot hull space: metres, origin at the ground contact centre,
x right, y up, -z forward. The single source of truth: part scripts build to these numbers and
build.py writes the gameplay-relevant ones to assets/tank/dims.json for TankModel.

Proportions follow the concept (art/anchors/tank.jpg): short, tall and chunky, a huge bow, a big
driver in a tall seat box at the back. Tuned by tools/compare.py.
"""

# Tracks: one per side, a belt of chunky links round two big wheels and two small ones.
TRACK_X = 0.95            # track centre line, each side
TRACK_W = 0.6
BELT_T = 0.1              # link thickness
WHEEL_BIG_R = 0.5
WHEEL_BIG_Y = 0.6        # big wheel centre height (belt bottom touches y = 0)
WHEEL_BIG_Z = (-1.2, 0.8)
WHEEL_SMALL_R = 0.19
WHEEL_SMALL_Y = 0.29      # small wheels ride on the belt's bottom run
WHEEL_SMALL_Z = (-0.58, -0.2, 0.18)   # three, as in the concept, tucked under the big ones
WHEEL_X = TRACK_X + 0.14  # wheel faces sit near the belt's outer edge, as in the concept

# Hull body between the tracks, with big rounded fenders over them.
HULL_X = 0.62             # half width of the body
HULL_Z = (-1.46, 1.3)     # front, back
HULL_Y = (0.3, 1.15)      # bottom, deck
FENDER_X = (0.62, 1.34)    # inner, outer edge of each fender (the belt spans 0.65..1.25)
FENDER_TOP = 1.36
FENDER_FRONT_Z = -1.96   # with the 0.76 m nose radius, centred on the belt's front arc
BUMPER = {"y": (0.26, 0.52), "z": -1.52, "x": 0.6}

# Seat box at the back, driver inside.
SEAT_X = 0.62
SEAT_Z = (0.25, 1.4)
SEAT_TOP = 1.95           # the iron rim sits at the knight's waist; shoulders and head above it
KNIGHT = {"x": 0.0, "y": 1.15, "z": 0.85}   # seat base the knight sits on
HELMET_R = 0.31           # bucket helmet radius at the brow (it flares a little toward the top)
HELMET_Y = (2.12, 2.71)
POLE = {"x": -0.5, "z": 1.32, "base_y": 1.5, "top_y": 3.15}   # rear LEFT corner, as in the concept

# Ballista: everything below is in ballista-pitch space, relative to PIVOT.
PIVOT = (0.0, 1.66, -0.3)
STOCK = {"w": 0.34, "h": 0.24, "z": (-1.75, 0.3), "y_top": 0.12, "groove": 0.06}
BOW_Z = -1.2              # riser centre
BOW_TIP = (1.95, 0.36, -0.72)   # right tip (left mirrored); the string ties on here
NOCK_REST = -0.72         # string centre z at draw 0: straight across between the bow tips
NOCK_DRAWN = 0.25         # ... at draw 1: short of the cradle's rear posts
NOCK_Y = 0.14             # string and bolt height above the pivot (bolt rests in the groove)
BOLT_LENGTH = 2.6         # nock to tip
GEAR = {"x": -0.45, "y": -0.05, "z": -0.45, "r": 0.18}   # below the line of fire (string and bolt)

LANDMARKS = {   # hull space, at rest (ballista straight and level, undrawn)
    "bolt_tip": (PIVOT[0], PIVOT[1] + NOCK_Y, PIVOT[2] + NOCK_REST - BOLT_LENGTH),
    "bow_tip_l": (PIVOT[0] - BOW_TIP[0], PIVOT[1] + BOW_TIP[1], PIVOT[2] + BOW_TIP[2]),
    "bow_tip_r": (PIVOT[0] + BOW_TIP[0], PIVOT[1] + BOW_TIP[1], PIVOT[2] + BOW_TIP[2]),
    "helmet_top": (KNIGHT["x"], HELMET_Y[1], KNIGHT["z"]),
    "flag_tip": (POLE["x"], POLE["top_y"], POLE["z"]),
    "track_front_l": (-TRACK_X, WHEEL_BIG_Y, WHEEL_BIG_Z[0] - WHEEL_BIG_R - BELT_T),
    "track_front_r": (TRACK_X, WHEEL_BIG_Y, WHEEL_BIG_Z[0] - WHEEL_BIG_R - BELT_T),
    "track_rear_l": (-TRACK_X, WHEEL_BIG_Y, WHEEL_BIG_Z[1] + WHEEL_BIG_R + BELT_T),
    "track_rear_r": (TRACK_X, WHEEL_BIG_Y, WHEEL_BIG_Z[1] + WHEEL_BIG_R + BELT_T),
    "bumper_l": (-BUMPER["x"], (BUMPER["y"][0] + BUMPER["y"][1]) / 2, BUMPER["z"]),
    "bumper_r": (BUMPER["x"], (BUMPER["y"][0] + BUMPER["y"][1]) / 2, BUMPER["z"]),
    # Hub faces of the left track's big wheels, the winch cog's hub, the seat's axle stub end.
    "wheel_front_l": (-WHEEL_X - 0.13, WHEEL_BIG_Y, WHEEL_BIG_Z[0]),
    "wheel_rear_l": (-WHEEL_X - 0.13, WHEEL_BIG_Y, WHEEL_BIG_Z[1]),
    "gear_center": (PIVOT[0] + GEAR["x"] - 0.08, PIVOT[1] + GEAR["y"], PIVOT[2] + GEAR["z"]),
    "stub_end": (-0.98, 1.53, 1.02),
}


def game_dims():
    """What TankModel needs at run time (assets/tank/dims.json)."""
    return {
        "pivot": PIVOT, "bow_tip": BOW_TIP, "nock_rest": NOCK_REST, "nock_drawn": NOCK_DRAWN,
        "nock_y": NOCK_Y, "bolt_length": BOLT_LENGTH, "gear": [GEAR["x"], GEAR["y"], GEAR["z"]],
        "wheels": [[side * WHEEL_X, WHEEL_BIG_Y, z, WHEEL_BIG_R] for side in (-1, 1) for z in WHEEL_BIG_Z]
        + [[side * WHEEL_X, WHEEL_SMALL_Y, z, WHEEL_SMALL_R] for side in (-1, 1) for z in WHEEL_SMALL_Z],
        "track_x": TRACK_X, "landmarks": LANDMARKS, "belt": _belt(), "hull_deck": HULL_Y[1],
    }


def _belt():
    import math
    z0, z1 = WHEEL_BIG_Z
    r = WHEEL_BIG_R + BELT_T / 2
    perimeter = 2 * (z1 - z0) + 2 * math.pi * r
    count = int(perimeter / 0.25)
    return {"z0": z0, "z1": z1, "cy": WHEEL_BIG_Y, "r": r, "count": count, "pitch": perimeter / count}
