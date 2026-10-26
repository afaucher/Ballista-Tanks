"""Build tank parts in headless Blender and export them to assets/tank/<part>.glb, plus
assets/tank/dims.json (the numbers TankModel needs, from dims.py).

    .\\tools\\parts\\build.ps1                    every part
    .\\tools\\parts\\build.ps1 hull track         just these

A part is any module here with a build() returning its finished object (common.finish).
"""

import importlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "tank")
sys.path.insert(0, HERE)

import common  # noqa: E402
import dims  # noqa: E402


def parts():
    out = []
    for f in sorted(os.listdir(HERE)):
        if f.endswith(".py") and f not in ("build.py", "common.py", "dims.py"):
            mod = importlib.import_module(f[:-3])
            if hasattr(mod, "build"):
                out.append(f[:-3])
    return out


def main():
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = names or parts()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "dims.json"), "w", encoding="utf-8") as f:
        json.dump(dims.game_dims(), f, indent=2)
    for name in names:
        t = time.time()
        common.reset()
        obj = importlib.import_module(name).build()
        path = os.path.join(OUT, name + ".glb")
        common.export_glb(path)
        print("PART", common.stats(obj), "-> assets/tank/%s.glb (%.1f s)" % (name, time.time() - t))


main()
