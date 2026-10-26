# Foot troops (draft, 2026-10-26)

Little soldiers running around the castle skatepark for both teams: something to protect, something
to hit, and the funniest thing in the game when a bolt catches one and pins it to a wall.

## Look
- **Proportions:** about 2.5 heads tall, ~1.1 m. The head (a bucket helmet like the driver's,
  with a face slot) is as big as the whole torso. Stubby legs, short arms, mitten hands.
- **Same family as the tank driver** (`tools/parts/knight.py`): steel bucket helmet, team tunic,
  iron pauldrons, brown gloves and boots. Team colour on the tunic, a helmet plume and a small
  shield, so the team reads from far away and from above.
- **Variants by silhouette, not detail:** spear, sword and shield, a banner carrier, and a
  crossbow troop with a tiny ballista on his back as a joke.
- **Built as rigid pieces, not a skinned mesh:** head, torso, pelvis, two upper arms, two
  forearms (with the mitten), two thighs, two shins (with the boot). That is how toy figures are
  made, it suits the chunky style, and every piece is ready to become a ragdoll bone as it is.
  Same Blender pipeline as the tank (`tools/parts/`), baked textures, team tint in Godot.

## Moving
- **Run cycle is procedural**: legs swing on their hips and knees, arms counter-swing, and the big
  head bobs and leads, so a run looks like a determined waddle. Turns lean into the corner; stops
  overshoot with a wobble of the head. No animation files to author.
- **They walk the walkable:** ground, ramps, wall walks, spiral tower ramps and bridges, using a
  navigation mesh. They don't ride walls or loops (that's for tanks); they use the stairs-turned-
  ramps. That keeps the skatepark verticals as tank territory and gives troops their own routes.
- **Behaviour:** they move in small squads (3-6) toward a goal (escort the banner, hold a tower,
  charge the enemy gate), scatter when a tank charges at them, and duck behind crenellations.
  Simple state machine: march, take cover, scatter, cheer.
- **Numbers:** maybe 10-20 per team on the field. Alive, each is one capsule body with an AI, which
  is cheap. The full physics only switches on when one dies.

## Getting hit: ragdolls
- **On death the troop becomes a ragdoll**: each rigid piece becomes a physics body (Godot
  `RigidBody3D`, or `PhysicalBone3D` if we skin it), joined at neck, shoulders, elbows, hips and
  knees with limited joints (cone-twist or 6DOF), so the limbs flop but don't bend backwards.
- **The impulse comes from what hit it**: a bolt's velocity, a tank's push, a fall. Big head,
  small body: the head's mass dominates, so they tumble head-first, which reads as funny.
- **Run over by a tank:** a shove and a spin, ragdoll; the tank barely notices.
- **Ragdolls are cosmetic:** when we add networking, only the death event and its impulse are sent;
  each machine simulates its own ragdoll (Cast's rule: effects run everywhere, outcomes are decided
  once). They fade or sink after ~20 s so the field doesn't fill up.

## Getting pinned by a bolt
The signature moment. A bolt doesn't just kill a troop, it carries it.
1. The bolt's ray hits a body part of a troop (or of a ragdoll already down).
2. That troop becomes a ragdoll, and the **hit piece is joined to the bolt** at the hit point
   (a pin joint to a kinematic body that follows the bolt).
3. The bolt keeps flying, a little slower for the weight, **dragging the flopping troop with it**.
4. When the bolt sticks in a wall, a tower or the ground, it becomes a static anchor: the troop
   hangs there, pinned, swinging, until it fades.
5. One bolt can skewer several troops in a line and carry them all ("shish-kebab").

Things to decide: does a pinned troop stay forever (until the round ends) or fade? Can a tank knock
pinned troops loose by driving into them? Do bolts that miss and stick in the ground stay as cover?

## How we'd build it
- Parts: `tools/parts/troop_*.py` (shared skeleton dimensions in `dims.py`), one textured piece per
  bone, team tint as for the tank.
- `Troop` scene: a `CharacterBody3D` capsule plus the pieces on a simple bone hierarchy for the
  procedural run; `TroopAI` for squads; `TroopRagdoll` builds the rigid bodies and joints from the
  same pieces at the moment of death.
- `Bolt` gains "carry": a kinematic anchor that ragdoll pieces can be pinned to, made static
  when the bolt sticks.
- Tests: the ragdoll's joints stay within limits, a bolt carries a troop and sticks with it
  pinned, troops path across the castle's walk routes but not up the vert walls.

## Troop parts (built 2026-10-26)
```powershell
.\tools\parts\build.ps1 troop                 # every piece -> assets\troop\*.glb + dims.json
.\tools\parts\build.ps1 troop head shield     # just these
build\deps\blender\blender-4.5.15-windows-x64\blender.exe -b --factory-startup --python tools\parts\troop_preview.py
```
Same pipeline as the tank (`docs/design/tank-art-pipeline.md`): `MeshBuilder` geometry, bevels,
Smart UV, the Cycles bake of the tank's STYLES and its material keys (so `TankModel.GLOSS` applies
as is), glb export. The tank build skips `troop_*` and is unchanged.

- `tools/parts/troop_dims.py`: the skeleton, the single source. Troop space has its origin at the
  pelvis (hip centre), x right, y up, -z forward. The helmet top is 1.07 m above the soles, the
  spear tip 1.47 m. Right-side joints only; the left mirrors them.
- `troop_head.py` (the knight's bucket helmet a size down: face slot, big eyes with a highlight,
  rosy cheeks, visor slits, side bosses, plume socket), `troop_body.py` (torso: tunic, iron collar,
  pauldrons; pelvis: skirt, belt and buckle, gunmetal hose), `troop_limbs.py` (team sleeve; iron
  vambrace with a big brown mitten; gunmetal thigh; knee cop, shin and boot), `troop_kit.py`
  (shield, spear, plume), `troop_common.py` (limb lathe; `piece()` moves a piece's origin onto its
  joint before the bake). Each module exposes `PIECES = {name: build}`.
- Pieces: `pelvis`, `torso`, `head`, `plume`, `upper_arm_l/r`, `forearm_l/r`, `thigh_l/r`,
  `shin_l/r`, `shield` (on `forearm_l`), `spear` (on `forearm_r`). Each glb's origin is at its
  joint with its parent, unrotated in the rest pose: standing, arms hanging a little out from the
  sides, spear upright in the right mitten with its butt on the ground, shield on the left facing
  forward and out. Left and right are modelled separately (no negative scale anywhere).
- `assets/troop/dims.json` follows the schema `scripts/troops/troop.gd` reads. Per piece:
  `parent`; `joint`, the origin in the parent's space (the pelvis's is measured from the troop
  origin on the ground, y 0.34); `rest`, the same point relative to the pelvis origin; `box` and
  `center`, a collision box in the piece's own space; `mass` in kg (head 3.0, torso 2.5, 13 kg
  in all). At rest no two boxes overlap unless their pieces are joined.
- Team colour: the tunic, sleeves, plume and shield face use the `team` material, baked pale and
  tinted in Godot as on the tank.
- Previews: `build/previews/troop_{front,side,back,three_quarter}.png` and `troop_sheet.png`.

## Troop gameplay (as built, 2026-10-26)
- **`Troop`** (`scripts/troops/troop.gd`): a `CharacterBody3D` capsule (0.25 x 1.1 m, layer 4,
  collides with the world only) carrying the pieces on pivots at their joints, loaded from
  `assets/troop/<piece>.glb` and `dims.json` (coloured boxes with the same names when missing).
  Runs at 3.6 m/s where `move_dir` points, on floors up to 40 degrees. The run cycle is code: hips
  and knees swing, arms counter-swing (the spear arm less), the torso leans into the run, the head
  bobs twice a stride, looks into turns and nods on a spring that overshoots when the speed
  changes, the body leans into corners. Cheering: arms up, hops. `plume` rides on the head.
- **`TroopAI`** (`troop_ai.gd`): a squad of 3-6 with MARCH / SCATTER / CHEER. Each troop plans its
  own path on a navigation mesh baked at runtime from the static colliders (`TroopAI.bake_nav`,
  0.2 s for the castles; slopes up to 35 degrees, so ground, ramps and walks but no wall faces or
  quarter-pipes), re-planned every 3 s; spacing keeps them apart and the ones out ahead ease off
  for the stragglers. A tank at more than 6 m/s heading at a troop within 22 m and 5 m of its line
  sends it sprinting sideways for 1.4 s. At the goal the squad cheers.
- **`TroopRagdoll`** (`troop_ragdoll.gd`): on death, one `RigidBody3D` per piece (layer 8; they
  hit the world and tanks, not each other) posed as the troop was, with the hit's velocity and a
  tumble about the hit point; shield and spear drop off as loose bodies. Joints are
  `Generic6DOFJoint3D` with per-axis limits (waist, neck, shoulders and hips as cones; elbows and
  knees one-way hinges). The project runs Godot Physics, whose hinge and cone-twist joints came
  apart on hard landings, and even the 6DOF limits give under a 20 m/s landing or a bolt's drag,
  so every tick a projection pass sets any joint more than 3 degrees past its limits (or pulled
  apart) back onto them, working out from the anchor. Fades (shrinks away) after 20 s.
- **Bolt carry** (`scripts/combat/bolt.gd`): bolts now hit troops and ragdolls (mask 1|2|4|8). A
  hit kills the troop and pins the piece the bolt's line passes through first: frozen, it rides on
  the shaft 0.8 m behind the tip (the next troop 0.45 m further back), the rest of the body trails
  behind, the bolt keeps 88 % of its speed per troop and flies on through ("shish-kebab"). When it
  sticks, the bodies thud to a stop and hang from the frozen piece. Decisions on the open
  questions: pinned troops fade after 30 s and the bolt stays as long as they do; tanks can't
  knock them loose yet; bolts that miss behave as before (gone after 12 s).
- **Run over:** a tank passing within its footprint at more than 3 m/s relative ragdolls a troop
  with 1.1 x its velocity plus a pop upward; downed ragdolls in its way get the same shove. The
  tank doesn't slow down. Tanks join the "tanks" group for this.
- **In game** (`scripts/game.gd`, castles only): three squads per team (13 troops each), one in
  each courtyard and two on each half of the field, marching on the enemy gate; a team down to
  fewer than 6 gets a fresh squad from its courtyard every 15 s. `--view troops` watches the blue
  gate, `--pin-demo --view pin` fires a bolt through a lone troop into a bridge pier at 1 s:
  `.\run.ps1 --shot-dir build\shots --shot-times '9,10.5' --view troops` (quote the times in
  PowerShell, or `2,5` splits into two arguments). Shots: `build/shots/castles_troops_10.5.png`,
  `build/shots/castles_pin_04.0.png`.
- **Tests:** `test_troop_ragdoll` (three troops shot mid-run land and settle with no joint more
  than 10 degrees past its limits, hold together, fade), `test_troop_bolt` (a bolt carries one
  troop, another skewers two in a line, both stick with the troops hanging from the shaft),
  `test_troop_runover` (a tank at 28 m/s knocks down all four troops in its path, leaves one beside
  it, keeps its speed; a squad crossing its line scatters and all five get away),
  `test_troop_march` (on the baked mesh a squad goes from its courtyard out of its gate, across
  the field and into the enemy gate in about 33 s, never on a steep surface, and cheers).
- Not yet: taking cover behind crenellations, goals other than the enemy gate (escort, hold a
  tower), variants, troops fighting each other, knocking pinned troops loose, networking. The
  navigation bake prints a harmless "edge merge errors" warning from the walls' many facets.

## Gemini prompt (concept sheet)
```text
Game character concept sheet in the style of the attached tank image: a tiny foot soldier for
Ballista Tanks, about 2.5 heads tall with a huge steel bucket helmet with a face slot (cute face
visible), blue team tunic, small iron pauldrons, mitten hands, stubby legs in brown boots. Front,
side and back views plus four variants (spear, sword and round shield, banner carrier, a soldier
with a tiny ballista strapped to his back). Chunky toy-like 3D, plain light grey background.
```
