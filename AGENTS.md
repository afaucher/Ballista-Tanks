# Ballista Tanks: instructions for agents

Ballista Tanks is an arcade team tank-combat game in Godot 4.7. Start with `README.md`, then
`docs/design/game-concept.md`. The setup follows Cast (`..\cast`) and Bridge to Friendship
(`..\bridge-to-friendship`); look there first for how a tool, script or test is done.

## Status
Gray-box prototype. The art style is fixed by `docs/design/art-direction.md` and its anchor
image, `art/anchors/cockpit.jpg`. The main arena is the castle skatepark
(`docs/design/castle-skatepark.md`); the cube (`docs/design/arena-structure.md`) and generated roads
remain as alternates (M cycles them in game).

## Layout
- `scripts/world/`: `arena.gd` (the castle skatepark, the cube shell and starter layout, generated
  roads), `castle_kit.gd` (walls, towers, keep, giant arch, bridge),
  `road_gen.gd` (road-first generator), `gravity_field.gd` (airborne gravity), `geo.gd` (mesh
  builders), `look.gd` + `shaders/` (materials, light), `pad.gd` (launch/boost pads)
- `scripts/tank/`: `tank.gd` (driving, surface gravity, ballista), `tank_model.gd` (the look)
- `scripts/combat/bolt.gd`: bolts, both gravity modes, carrying and pinning troops; `scripts/game.gd`:
  camera, input, HUD, troop squads in the castles
- `scripts/troops/` (`docs/design/troops.md`): `troop.gd` (capsule + rigid pieces, procedural run),
  `troop_ai.gd` (squads, runtime navigation bake), `troop_ragdoll.gd` (death ragdoll, joint projection)
- `scenes/main.tscn` boots the game, or a test with `-- --run-test <name>`; `*_lab.tscn` are labs

## Run and test
- `.\run.ps1` plays (`--arena castles|starter|roads`, `--seed N`, `--bot`, `--bolt straight`); `.\test_runner.ps1 -TestAll`
  runs every `tests/test_*.gd` headless. Run the tests after any code change.
- Screenshots: `-- --shot-dir <dir> --shot-times 2,5 [--view overview]` (windowed, not headless).
- Grounded tanks fall toward the surface under them; airborne ones use `GravityField` (uniform
  down in the castles). Steep and upside-down surfaces hold a tank only above a speed (`Tank.sticks`). Rotate
  frames with `Tank.turn_toward`, not `Vector3.slerp` (it errors on nearly parallel vectors).

## Tank art pipeline
`docs/design/tank-art-pipeline.md`: parts are Blender scripts in `tools/parts/` (headless, pinned
Blender in `build/deps/`, `.\tools\setup_art_tools.ps1`), exported to `assets/tank/*.glb`, and
scored against `art/anchors/tank.jpg` with `tools/compare.py`. The game's tank IS these parts: `TankModel` assembles
`assets/tank/*.glb` to `assets/tank/dims.json`; change `tools/parts/dims.py` and rebuild, never edit the glbs. Flip mirrored parts by rotation,
never `scale.x = -1`. `build/` and `tools/` carry `.gdignore` so Godot doesn't scan Blender.

## Engine
`godot_env.ps1` finds the engine: `$env:BT_GODOT`, else `..\Hero-Reader\third_party\godot\
Godot_v4.7-stable_win64_console.exe`.

## Concept art
`python art/concept.py` (stdlib only) calls the Gemini image API and writes
`art/concepts/<style>/<shot>_<i>.jpg`. The key comes from `GEMINI_API_KEY` or `~/.btf_gemini_key`,
never from a file in the repo. `art/` has a `.gdignore` so Godot does not import it.
