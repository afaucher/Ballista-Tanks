# Tank art pipeline: from concept image to game parts

Research notes and plan, 2026-10-26. Goal: replace the primitive gray-box tank with low-poly,
bevelled, UV-mapped parts that capture the feel of the close-up concept (`art/anchors/tank.jpg`),
built by an agent, with free tools only (no Meshy or other paid generators yet).

## The parts
The style is faceted shapes with bevelled or chamfered corners, so the tank splits cleanly:
| part | instances | notes |
|---|---|---|
| road wheel | 4 per side | grey hub disc, bolt ring, chunky rim |
| drive sprocket / idler | 1 + 1 per side | toothed front wheel, plain rear wheel |
| track link (tread) | ~24 per side | one chunky brown rubber block, repeated along the track path |
| hull | 1 | blue body, front glacis, fenders over the tracks, iron trim strip, rivets |
| seat box | 1 | blue box with iron corners, where the driver sits |
| driver (knight) | 1 | bucket helmet with eye slit, blue tunic, iron pauldrons, hands on levers |
| ballista | 1 | curved wooden bow limbs, iron caps, rope string, stock, winch cog, bolt |
| pennant | 1 | pole, spear tip, cloth flag |

Every part is its own mesh with its own UVs, so it can be modelled, compared and replaced on its
own. `TankModel` keeps its interface (`ballista_yaw`, `ballista_pitch`, `bolt_tip`, `set_draw`...)
and swaps primitives for the part meshes.

## What the research found
**Image-to-3D models (free, open weights):**
| model | fits a 12 GB RTX 3080? | output | fit for us |
|---|---|---|---|
| TRELLIS.2 (Microsoft, MIT, Dec 2025) | no: 16-24 GB; free Hugging Face Spaces exist (ZeroGPU quota) | dense mesh + PBR | best quality, but dense: needs retopology to reach our faceted look |
| Hunyuan3D 2.1 / 2mini (Tencent) | 2mini shape ~5 GB yes; full textured pipeline reported 12-29 GB | dense mesh + PBR | licence excludes EU/UK/South Korea; good for a shape reference |
| Stable Fast 3D (Stability) | yes (~7 GB) | UV-unwrapped textured mesh in 0.5 s | lowest fidelity; free under $1M revenue |
| PartCrafter / PartPacker / OmniPart | research code | one mesh per part | part-aware, the right idea; PartPacker is non-commercial |

All of them produce dense triangle soup with baked lighting, not the crisp bevelled facets of the
concept. They are useful as a **proportion reference for organic parts** (the knight), not as
final meshes.

**Agent tooling:**
- **BlenderMCP** (ahujasid/blender-mcp, MIT): Claude drives a live Blender: run Python, `look`
  at the viewport (multi-angle sheets), import from Poly Haven / Sketchfab, and generate with
  Hunyuan3D / Rodin / Tripo / Meshy (those need paid accounts or keys).
- **arjun988/blender-skills** (MIT): 94 Claude Code skills on top of BlenderMCP, including
  hard-surface, vehicle-artist, uv-workflow, lowpoly-style, asset-optimization and godot-export.
  Unreviewed third-party code: read before installing.
- **LL3M** (paper): agents writing Blender Python to build assets is a known-good pattern; plain
  headless `blender -b --python` needs no MCP at all, and exports are more reliable headless.

**Conclusion:** for this style, the agent should **model each part as code** in Blender (bevel
modifiers, clean UVs, small painted textures), and **measure** it against the concept with a
render-and-compare loop. Image-to-3D is optional, for the knight's shape.

## The pipeline
1. **References.** The close-up is the assembly reference. Per-part sheets from Gemini (front,
   side, top, plain grey background) give each part its own target.
2. **Model as code.** `tools/parts/<part>.py` runs in headless Blender: low-poly geometry, a
   1-2 segment bevel, seams and UVs, material slots, then glTF export to `assets/tank/<part>.glb`.
   Textures are small painted maps (wood grain, painted metal with rivets, rubber).
3. **Assemble** in `TankModel` from the .glb parts; the gameplay interface does not change.
4. **Render and compare** (below), adjust the part script, repeat until the scores level off and
   it looks right.
5. **Knight (optional AI path):** a shape from Hunyuan3D-2mini (local) or a TRELLIS.2 Space, then
   decimated or remeshed in Blender as a guide for the hand-built low-poly version.

## Render and compare
The reference is a render too, so we can compare like with like:
1. **Match the camera.** Mark about 10 landmarks on the reference once (bow tips, bolt tip, helmet
   top, flag tip, pole base, the four track corners, the cog centre) in
   `art/anchors/tank_landmarks.json`. The model carries the same named markers. OpenCV `solvePnP`
   recovers the reference's camera, and Godot renders the model from it on a transparent
   background (the game's renderer, so the game's look is what gets measured).
2. **Score** with `tools/compare.py`:
   - **Landmark error:** reprojected 2D distance per landmark, as % of the image diagonal (the
     point comparison).
   - **Silhouette IoU:** the reference has a plain background, so it masks cleanly.
   - **Per-part colour:** mean Lab colour of each part's region, as delta E (team blue, wood,
     iron, rubber).
   - **Edge match:** chamfer distance between edge maps, which catches bevel lines and panel
     breaks.
   - **Feel (later):** DINOv2 / CLIP embedding similarity.
3. **Output:** a side-by-side and overlay PNG plus JSON scores, appended to
   `art/compare/history.csv` so every iteration shows whether it got closer.

Not exact, the feel: the targets are proportions (landmarks, silhouette) and palette (colour),
with edges as a tiebreak.

## As built (2026-10-26)
```powershell
.\tools\setup_art_tools.ps1                       # Blender 4.5.15 portable + tools\.venv (once)
.\tools\parts\build.ps1                          # every part -> assets\tank\*.glb + dims.json
.\tools\parts\build.ps1 hull track               # just these
.\tools\parts\preview.ps1 hull                   # Blender render -> build\part_previews\hull.png
tools\.venv\Scripts\python tools\compare.py run --ref art\anchors\tank.jpg --label <name>
```
**The tank is the concept's, textured, in game.** `TankModel` assembles 11 parts from
`assets/tank/` (generated, committed so the game needs no Blender): hull, track frame (x2),
track_link (a MultiMesh belt per side that runs round the wheels as the tank drives), wheel_big
(x4), wheel_small (x4), seat, knight, pennant, ballista, gear, bolt, rope (the two string halves).
The flying bolt uses bolt.glb too. Red and blue share every texture: "team" surfaces are baked
pale and tinted by `TankModel.TEAM_COLORS`.

- `tools/parts/dims.py`: every dimension, in Godot hull space; `build.py` writes the gameplay
  numbers (pivot, bow tips, nock travel, bolt length, gear, wheels, landmarks) to
  `assets/tank/dims.json`, which `TankModel` reads. Change a number there and rebuild.
- `tools/parts/common.py`: `MeshBuilder` (boxes, lathes, sweeps, extrusions in Godot coordinates),
  `finish()` (join, smooth by angle, Smart UV) and the bake: each material's STYLE (base, dark and
  edge colours, wood grain or rope twist from vertex attributes, noise) rendered with Cycles into
  one albedo texture per part, with ambient occlusion darkening creases and a bevel-normal mask
  lightening edges. Copies land in `build/part_textures/` to look at.
- Parts: `hull.py`, `track.py`, `track_link.py`, `wheels.py` (+ `wheel_big.py`, `wheel_small.py`), `seat.py`,
  `knight.py`, `pennant.py`, `ballista.py`, `gear.py`, `bolt.py`, `rope.py`.
- Gameplay hooks unchanged: `ballista_yaw`/`ballista_pitch`, `bolt_tip`, `set_draw` (stretches the
  rope halves, slides the bolt), `set_crank` (turns the cog), `set_loaded`, `set_spin` (wheels
  and track links).
  The ballista's traverse is now 60 degrees each side (`Tank.ARC`): further, the stock hits the
  seat box.
- `tests/test_tank_textured.gd`: every part built and textured, team tints for both teams, and a
  tank draws, fires and hits another tank, and cranking turns the cog.

**Lessons**
- Mirroring an imported mesh with `scale.x = -1` renders it inside out: flip parts by rotation.
- Metallic surfaces go dark in Godot without reflections: keep metallic around 0.15.
- The concept's soft drop shadow is excluded from its silhouette (slightly darker, same tint).
- At game distance only big steps catch the light: deep dishes, raised hubs, fat bevels.
- The scoring rig needs a key, a weak fill, low ambient and exposure 0.9 to match the concept's
  studio render; the flat-ID pass must reset exposure, or its colours stop matching.
- Region colours mostly measure misalignment until the shapes line up: fix proportions first.
- bmesh: create attribute layers before vertices (adding a layer invalidates vertex refs).
- Run Godot's import alone: two Godot processes importing the same project can crash it.
- Any instance basis must be right-handed: a left-handed one (like scale -1) renders inside out.
- Headless Godot's dummy renderer keeps no MultiMesh transforms: test layout maths directly.

| run | landmarks | silhouette IoU | colour dE | edges |
|---|---|---|---|---|
| gray-box baseline (first rig) | 4.21% | 0.702 | 27.5 | 0.89% |
| textured parts v1 (final rig) | 2.88% | 0.771 | 29.8 | 0.66% |
| v2: ballista raised, tracks forward | 1.71% | 0.794 | 27.3 | 0.61% |
| v3: colours calibrated, bigger wheels | 1.75% | 0.798 | 24.4 | 0.63% |
| (14 landmarks from here: + wheel hubs, cog hub, axle stub) | | | | |
| v4: cog forward, bumper back, longer bolt, moving links | 1.66% | 0.813 | 22.1 | 0.57% |
| v5: fenders clear the belt, pivot and helmet up | 1.31% | 0.815 | 24.2 | 0.60% |
| v6: taller cradle, slimmer sides, muted blue | 1.30% | 0.826 | 19.4 | 0.55% |
| v7: colours from aligned regions, bigger wheels closer | 1.25% | 0.824 | 13.1 | 0.58% |
| v8: three small road wheels a side, thin fenders centred on the belt | 1.25% | 0.826 | 14.5 | 0.57% |
| v9: fender skirts hide the top of the track | 1.25% | 0.824 | 13.7 | 0.58% |
| v10: colours from aligned regions again | 1.25% | 0.824 | 8.4 | 0.59% |
| v11: string mechanism (slotted cradle, cog below the string), nothing intersects | 1.61% | 0.819 | 9.2 | 0.60% |

| v12: winch cog high on the frame, above the string's path | 1.34% | 0.812 | 9.3 | 0.55% |
| gloss v1: reflection sky + per-material gloss in the shader | 1.34% | 0.812 | 8.3 | 0.53% |
| gloss v2: full clearcoat on paint, more varnish on wood | 1.34% | 0.812 | 8.1 | 0.52% |
| (compared at the concept's ballista pose from here: 6 degrees up, see below) | | | | |
| landmarks follow the ballista's pose | 1.11% | 0.818 | 8.1 | 0.51% |
| round fender edges (bevel 0.12 m) | 1.11% | 0.818 | 8.0 | 0.51% |

**The concept's pose.** Landmarks on the ballista now ride on it, and a sweep of its pitch (0, 3,
6 and 9 degrees) fits best at 6 degrees up; `art/anchors/tank_landmarks.json` records that pose
and `compare.py` uses it. At that pose the bolt tip drops out of the largest offsets; the largest
is now the winch cog (2.3%).

**Where the concept's white streaks come from.** A brighter reflection sky washed the whole hull
out (colour 8.1 to 11.0) and was reverted. The streaks come from shape: the concept's fenders are
round, so they catch the key light in long curved highlights. Bigger rounded fender edges did
that and improved both scores.

**Gloss is in the shader, not the texture.** Highlights and reflections depend on the view and the
lights, so a baked highlight would sit still on a moving tank. The bake keeps only what doesn't
move (colour, wood grain, creases, painted edge wear); `TankModel.GLOSS` gives each material its
roughness, specular, metallic and clearcoat (satin paint with a soft clearcoat, varnished wood,
metallic iron and steel, matte rubber and rope; see the fixes after the first play below). Both the game (`Look.make_environment`) and the
scoring rig reflect `Look.studio_sky()`, a soft bright-above, dark-below sky used only for
reflections (the cube has no sky to show): without one, metal and gloss have nothing to reflect and
read dark.

v11 hung the winch cog below the string's path (gear_center 5.6%); v12 puts it high on the frame
like the concept's, just above the string (2.4%). The largest remaining offset is the bolt tip
(2.5%, ~30 px low): the concept's ballista looks tilted up a few degrees, and we compare at the
level rest pose.

**How the string pushes the bolt.** Reloading is winching: cranking (R or the wheel) pulls the
string back along the stock's deck through slots in the cradle walls (`ballista.py` `SLOT`); the
draw follows the crank. At full tension (`NOCK_DRAWN`, the rear posts) a bolt drops into the
groove, sitting on the string. A click looses it: the flying bolt starts exactly where the loaded
one sat and `TankModel.release()` snaps the string forward through the slots, past straight
(`NOCK_REST`, z -0.72 in pitch space, between the bow tips) and rings it back to rest over 0.25 s.
The winch cog sits below the line of fire (string and bolt), on the stock's left.

**Fixes after the first play (2026-10-26):**
- *The string didn't tension on reload*: it does now (above). Hold-to-draw is gone; every shot is
  at full tension.
- *Gloss was too high*: satin paint (roughness 0.45, specular 0.35, a soft clearcoat for the broad
  highlight on rounded edges), no rim light, a dimmer reflection sky (`Look.studio_sky`, energy
  0.55).
- *Single white pixels on silhouettes*: specular from thin bevel strips at grazing angles. Measured
  by counting isolated bright pixels on a fender crop: 58 at first, 14 with no specular at all, 16
  now (lower specular, the dimmer sky, Godot's screen-space roughness limiter, FXAA on top of
  MSAA in `project.godot`). The bake's edge highlight is now also gated by AO, so creases where
  two surfaces meet no longer light up.
- *Round object behind the left track*: the left track is turned 180 degrees so its frame plate
  sits on the hull side, which also flipped it front to back; it is shifted back into place.
- *Gap under the ballista when aiming up*: it now pivots in a fork mount (`mount.py`, on the
  ballista's yaw node): a base plate on the turntable and two iron arms up to trunnions on the
  pivot axle. The clearance test sweeps the whole pitch range against the plate, arms and deck.

**Nothing intersects** (`tests/test_tank_clearance.gd`, real part meshes as physics shapes):
every track link at 24 points round both belts against the hull and fenders; every wheel against
the hull; the string at every draw against the frame and the cog (with a control ray that must
hit); and every ballista vertex across its traverse against the seat box, knight and pennant
(clear to +-88 degrees; `Tank.ARC` is 60). The fenders now span x 0.62..1.34 with their skirts
outside the belt (0.65..1.25), and the hull body is 0.62 wide.

**Played with a real keyboard and mouse:** `.\tools\play_session.ps1` launches the game window and
sends OS-level input through Windows `SendInput` (only while the game window is in front):
click to capture the mouse, W to drive, A to steer, move the mouse to aim, hold and release the
left button to fire, R to crank. Screenshots land in `build/park/play/`.

`tests/test_player_input.gd` plays a session through the real input pipeline (key and mouse
events via `Input.parse_input_event`): mouse aim, W/D drive and steer, hold and release the button
to draw and loose, R to crank, B for bolt gravity, Esc to let go of the mouse (no firing until a
click takes it back), M for the road arena, T to reset.

**Playing it:** `.\run.ps1 --arena roads --bot --demo` drives the tank round a generated road,
catches an enemy started just ahead, and cranks, draws and fires at it on its own (HUD: Hits 1
within about 4 s).

## Setup needed
- **Blender 4.5 LTS portable** pinned under `build/deps/` (like Bridge to Friendship pins
  Godot), about 400 MB download. `pip install bpy` does not support Python 3.14.
- **A Python venv** in `tools/.venv` with numpy, opencv-python and pillow for `compare.py`.
- **Optional:** BlenderMCP (`uv`) and the blender-skills pack for interactive sessions.

## Gemini prompts for part sheets
Attach the tank close-up, then:
```text
Using exactly the style, colours and proportions of the attached tank, draw a game asset reference
sheet of ONLY its <PART>, isolated, shown front, side and top-down (orthographic, no perspective),
plain light grey background, even studio light, no shadows on the ground, no text.
```
PART: "road wheel and front drive sprocket", "single track link (tread block), and a short run of
links", "hull body without tracks, ballista or driver", "knight driver, seated pose, full body",
"ballista (bow, string, stock, winch cog, bolt)".

## Sources
- [TRELLIS.2 / open-source comparison (trellis2.app)](https://trellis2.app/blog/best-image-to-3d-models-huggingface), [cmarix overview](https://www.cmarix.com/blog/top-open-source-ai-models-for-3d-image-generation/), [triposr.org comparison](https://triposr.org/blog/free-image-to-3d)
- [Hunyuan3D-2 in ComfyUI docs](https://docs.comfy.org/tutorials/3d/hunyuan3D-2), [Hunyuan3D-2GP](https://openi.pcl.ac.cn/NewestAI/Hunyuan3D-2GP), [Windows setup guide](https://codersera.com/blog/set-up-hunyuan3d-2-on-windows-a-step-by-step-guide/amp/)
- [Stable Fast 3D](https://huggingface.co/stabilityai/stable-fast-3d), [SF3D paper](https://arxiv.org/abs/2408.00653v1)
- [PartCrafter (NeurIPS 2025)](https://neurips.cc/virtual/2025/poster/120299), [PartPacker](https://huggingface.co/nvidia/PartPacker), [OmniPart](https://arxiv.org/abs/2507.06165)
- [BlenderMCP](https://github.com/ahujasid/blender-mcp), [arjun988/blender-skills](https://github.com/arjun988/blender-skills), [LLM Blender Agent](https://github.com/saofund/LLM-Blender-Agent), [LL3M](https://arxiv.org/pdf/2508.08228)
- [Blender portable 4.5 LTS](https://portableapps.com/node/82548), [headless glTF export](https://til.jakelazaroff.com/blender/export-a-blender-file-to-glb-from-the-command-line/)
