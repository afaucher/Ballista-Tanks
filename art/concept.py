#!/usr/bin/env python3
"""Generate Ballista Tanks concept art with the Gemini image API.

    python art/concept.py                          # every style x every shot
    python art/concept.py --style toybox           # one style, every shot
    python art/concept.py --shot cockpit arena     # these shots, every style
    python art/concept.py --n 2 --style toybox --shot cockpit
    python art/concept.py --dry-run                # print the prompts, call nothing

Images land in art/concepts/<style>/<shot>_<i>.jpg. The key comes from
GEMINI_API_KEY, else from ~/.btf_gemini_key (the file Bridge to Friendship's
art/gen.py reads). It is never written anywhere. Stdlib only.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ROOT)
OUT = os.path.join(ROOT, "concepts")
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions"
MODEL = os.environ.get("BT_IMAGE_MODEL", "gemini-3-pro-image")
KEY_FILE = os.path.join(os.path.expanduser("~"), ".btf_gemini_key")

# The world, shared by every style: what is in the picture, not how it is drawn.
WORLD = (
    "Ballista Tanks, a wacky arcade team combat video game. Small chunky tanks with stubby treads have "
    "had their turrets replaced by a GIANT ballista: an oversized siege crossbow with a thick wooden "
    "bow, a twisted rope string, a winch crank on the side and a huge iron-tipped bolt loaded in its "
    "groove. The driver sits in an open-top cockpit right behind the ballista, so the ballista is "
    "directly in front of the driver's head. Drivers are goofy little knights in oversized helmets. "
    "Two teams: red and blue, with team-coloured banners, pennants and paint on the tanks. "
    "The arena is OBVIOUSLY a designed game arena, not a real castle: simplified chunky castle pieces "
    "(crenellated walls, round towers, gatehouses, drawbridges, moats) arranged as a play space for "
    "3D tank combat, with curved ramps up onto the battlements, banked turns, boost pads, jump ramps, "
    "bridges between towers and wide open courtyards. Clean, readable, kart-racer energy. "
)

STYLES = {
    "toybox": (
        "Art style: bright, saturated, chunky toy-like 3D like a modern Nintendo kart game. Soft rounded "
        "shapes, slightly glossy plastic and painted wood materials, sunny sky, cheerful colour, "
        "clean stylised textures, soft shadows. "
    ),
    "lowpoly": (
        "Art style: stylised low-poly 3D with flat-shaded faceted geometry and a limited bold palette, "
        "simple gradient sky, crisp hard shadows, almost no texture detail, very clean silhouettes, "
        "like a polished indie game. "
    ),
    "painterly": (
        "Art style: hand-painted stylised 3D like a hero shooter (Overwatch, Fortnite): exaggerated "
        "proportions, painted textures with visible brush strokes, warm rim lighting, chunky stone "
        "blocks with bevelled edges, rich storybook colour. "
    ),
}

SHOTS = {
    "cockpit": (
        "In-game screenshot from the player's view: a third-person camera just above and behind the "
        "driver's head. The giant ballista fills the lower third of the screen, its huge bow spanning "
        "almost the full width, the winch crank on the right, a loaded bolt pointing forward down the "
        "middle. The driver's helmet is visible at the bottom. Ahead, the tank is racing along a castle "
        "wall-top ramp while an enemy red tank drifts around a tower in the distance. Simple game HUD: a "
        "small aiming reticle with a dotted arc showing the bolt's drop, a bolt-ready indicator, a team "
        "score at the top. Motion and speed. "
    ),
    "arena": (
        "Wide high aerial overview of a whole arena level, three-quarter view from high above: a "
        "symmetric map with a red base keep on one side and a blue base keep on the other, a central "
        "courtyard with a round tower, ramps spiralling up towers, wall-top roads, a moat with "
        "drawbridges, jump ramps over gaps. Several tiny tanks driving and firing bolts across it. It "
        "reads clearly as a designed game map. "
    ),
    "battle": (
        "Dynamic action shot in the middle of a team fight: a blue tank catches big air off a jump ramp "
        "between two towers while firing its ballista; a red tank below has just been hit by a giant "
        "bolt and is flipping comically into the air with a cartoon impact burst and splinters; another "
        "bolt is stuck in a wall. Low dramatic camera angle, speed lines, pure fun. "
    ),
    "tank": (
        "Game character concept sheet for one tank: three views side by side (front, three-quarter, "
        "side) of a blue team ballista tank, plus a small inset of the winch crank and bolt. Neutral "
        "light grey background. The proportions are kart-like: short wide hull, oversized ballista, "
        "big round driver head. "
    ),
}

NEGATIVE = "No real-world logos, no watermark, no realistic military tanks, no gore."

ASPECT = {"tank": "16:9"}


def load_key():
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if key:
        return key
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    return line
    return ""


def find_image(payload):
    # Walk the whole response: the shape is the one thing here we do not control.
    stack = [payload]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            data = node.get("data")
            mime = str(node.get("mime_type", node.get("mimeType", "")))
            if isinstance(data, str) and len(data) > 1024 and mime.startswith("image/"):
                return data
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return None


def call(key, body, retries=5):
    req = urllib.request.Request(ENDPOINT, data=json.dumps(body).encode("utf-8"), method="POST",
                                 headers={"content-type": "application/json", "x-goog-api-key": key})
    delay = 4.0
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")[:400]
            if err.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                print("    http %d, retrying in %.0fs" % (err.code, delay))
                time.sleep(delay)
                delay = min(delay * 2, 120.0)
                continue
            raise RuntimeError("http %d: %s" % (err.code, detail))
        except urllib.error.URLError as err:
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            raise RuntimeError("network: %s" % err.reason)


def prompt_for(style, shot):
    return WORLD + STYLES[style] + SHOTS[shot] + NEGATIVE


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", nargs="*", default=list(STYLES))
    ap.add_argument("--shot", nargs="*", default=list(SHOTS))
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--size", default="2K")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    key = "" if args.dry_run else load_key()
    if not args.dry_run and not key:
        print("No key: set GEMINI_API_KEY or put it in %s." % KEY_FILE, file=sys.stderr)
        return 2
    failed = 0
    for style in args.style:
        os.makedirs(os.path.join(OUT, style), exist_ok=True)
        for shot in args.shot:
            prompt = prompt_for(style, shot)
            body = {"model": MODEL, "input": [{"type": "text", "text": prompt}],
                    "response_format": {"type": "image", "mime_type": "image/jpeg",
                                        "aspect_ratio": ASPECT.get(shot, "16:9"),
                                        "image_size": args.size}}
            for i in range(args.n):
                if args.dry_run:
                    print("== %s/%s\n%s\n" % (style, shot, prompt))
                    continue
                path = os.path.join(OUT, style, "%s_%d.jpg" % (shot, i))
                try:
                    data = find_image(call(key, body))
                    if not data:
                        raise RuntimeError("no image in response")
                    with open(path, "wb") as fh:
                        fh.write(base64.b64decode(data))
                    print("wrote", os.path.relpath(path, REPO))
                except Exception as e:  # one bad cell shouldn't stop the batch
                    failed += 1
                    print("FAILED %s/%s #%d: %s" % (style, shot, i, e), file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
