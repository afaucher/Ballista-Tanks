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

## Gemini prompt (concept sheet)
```text
Game character concept sheet in the style of the attached tank image: a tiny foot soldier for
Ballista Tanks, about 2.5 heads tall with a huge steel bucket helmet with a face slot (cute face
visible), blue team tunic, small iron pauldrons, mitten hands, stubby legs in brown boots. Front,
side and back views plus four variants (spear, sword and round shield, banner carrier, a soldier
with a tiny ballista strapped to his back). Chunky toy-like 3D, plain light grey background.
```
