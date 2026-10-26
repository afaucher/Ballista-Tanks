# Arena structure: building a castle into 3D space

Working notes, 2026-10-26. How to lay out a level where "down" changes from place to place,
how surfaces connect, and how to keep it feeling open. Builds on the cube decisions in
`game-concept.md` (local gravity, curved quarter-pipe edges, no colour coding per face).

## 1. The container and what's already in it
A level starts as a **container** (the cube) plus **fixtures**: things already in the space
before any castle is built.
- **Faces:** the six inner walls of the cube.
- **Pillars:** columns that span from one face to the opposite face. You can drive around and up
  their outside.
- **Floating blocks:** islands hanging in the void, with their own gravity, like tiny planets.
- **The core:** the centre of the cube. It holds the light (a small sun) and is otherwise kept
  empty.

The castle is then built *onto* the faces and fixtures, not the other way round.

## 2. Gravity: one field, two rules
- **Grounded: surface rule.** A tank on a surface falls toward that surface (down = the surface
  normal, blended across curves). This is what makes quarter-pipes work at any speed.
- **Airborne: volume rule.** In the air, down comes from the gravity volume the tank is in. By
  default the cube splits into **six pyramids**, each with its tip at the centre and its base on
  one face. Inside a pyramid, down is that face. A jump that crosses a pyramid boundary changes
  which way it falls.
- **Fixtures add their own volumes on top of the pyramids:** cylindrical around a pillar,
  spherical or box-shaped around a floating block. The higher-priority volume wins, as in Mario
  Galaxy.

## 3. Orientation layers (your method, made concrete)
1. **Paint orientations.** On an unfolded cube net, mark which patch of each surface belongs to
   which "down". By default a patch belongs to its face, and patches around fixtures can belong
   to the fixture instead.
2. **Grow each layer a little.** For each orientation, build the castle up from its patches along
   that layer's "up", one to three storeys. A layer must stay inside its own gravity volume (its
   **build envelope**), or a tank on top of it would be in someone else's gravity. With the
   pyramid split, the envelope is tall in the middle of a face and shrinks to nothing at the
   edges. So edges stay low and clear for the quarter-pipes, and face centres can hold tall keeps.
3. **Find connections.** Where two layers come near each other, join them with one of the
   connectors below. Check the connection graph: every face reaches each neighbouring face at
   least twice, and there are no dead ends.
4. **Check sightlines and cover** (see 6).

## 4. Connectors between layers
All of them are curves; none is a portal.
| connector | where | feel |
|---|---|---|
| **Quarter-pipe (concave)** | the cube's edges; where a layer's floor meets a wall of another layer | the main road between faces; full speed, always sticks |
| **Rounded lip (convex)** | top edges of walls and towers | the tank wraps over and drives down the other side. Open question: stick at any speed, or launch past a speed limit? |
| **Twisted bridge** | spans the void between two layers | the road twists 90° along its length so down rotates as you cross. Very Escher, and a strong landmark |
| **Pillar spiral** | a road wrapped around a pillar from one face to the opposite one | climbing feels like driving round a tiny planet; links bases across the core |
| **Jump across the void** | launch pads aimed over a pyramid boundary | the big moment: fly across the open core and land "upside down" on another face |
| **Floating block** | an island near the core | a stepping stone for jumps; a small keep wrapped all the way round it |

## 5. Castle parts as roads
Normal castle architecture is made for people on foot: stairs, narrow wall-walks, small doors,
dead-end rooms. Here every piece has to be redesigned as part of a **road network**. Framing: a
**castle-themed skatepark for tanks**, or a highway interchange built out of castle parts. It
reads as a castle from its silhouette (towers, crenellations, banners, gatehouses) but has the
proportions of a road.

| castle part | becomes | role |
|---|---|---|
| Curtain wall | elevated road; the wall-walk widened to 2–3 tank widths | fast lane with a view |
| Crenellations | low guard rail with gaps between merlons | cover you can shoot through; gaps let you drop off on purpose |
| Tower | roundabout: a spiral ramp wrapped around the outside, a turning circle on top | junction, landmark, high ground |
| Hollow tower | a banked bowl inside (wall of death) | drive the inside wall to climb; showy duels |
| Gatehouse | tunnel through a wall, roofed | chokepoint with cover from above |
| Drawbridge | jump ramp, half-raised | air time across a gap |
| Moat | sunken channel with banked half-pipe sides | low lane under the bridges |
| Stairs | ramps, never steps; switchbacks where it is steep | everything is drivable |
| Flying buttress | a sloping ramp from the ground up to a wall top | natural on-ramps |
| Arches and bridges | overpasses and underpasses: road over road | stacks routes vertically like an interchange |
| Courtyard / bailey | open plaza or bowl | brawl space |
| Keep | multi-level structure with ramps between floors, like a car park | team base, spawn |
| Arrow slits, murder holes | windows into firing lanes; shootable, not drivable | sightlines without routes |
| Machicolations, roofs | overhangs | cover from the face overhead |

Road rules:
- **Width:** at least 3 tank widths (about 9–12 m), wider on bends.
- **Slope:** ramps up to about 30°. Anything steeper becomes a quarter-pipe, which works at any
  angle thanks to the surface gravity rule.
- **Bends:** banked, never right-angled. Corners in walls are rounded off.
- **Edges:** every road edge is either a rail (merlons, wall) or a deliberate drop. Never an
  accidental cliff.
- **No dead ends:** every road continues or loops back. A tower top is a turning circle, not a
  cul-de-sac.
- **Every piece belongs to an orientation layer** (section 3), so all of these can be stamped
  onto any face.

## 6. Making it feel open
- **Keep the core empty.** The void in the middle is the sky. A building height budget of about
  25% of the cube's half-width keeps sightlines across it.
- **Keep edges low.** The pyramid envelope already does this: quarter-pipes stay visible from
  across the cube, so you can watch tanks rounding them.
- **See-through architecture.** Arcades, open walkways, crenellations and bridges rather than
  solid blocks. Big masses only at the team keeps.
- **Cover is needed in every direction.** Every face can see you, including the one overhead.
  Real cover means roofs, tunnels, covered gatehouses and the underside of bridges, not just
  walls. Open lanes are for speed; covered spots are for fighting.
- **The sun at the core lights every face evenly,** so no face is a dark corner.

## 7. A starting layout to prototype
- The cube is about 128 m across, the quarter-pipes have a radius of about 12 m, and tanks are
  about 3 m long. All of this needs tuning.
- **Floor:** blue keep. **Ceiling:** red keep, so the bases face each other across the core.
- **Four walls:** a continuous belt of contested castle. The wall-to-wall quarter-pipes make it a
  loop you can race around forever.
- **Two pillars**, off centre and diagonal from each other, with spiral roads from floor to
  ceiling: the fast but exposed route between bases.
- **Launch pads** on each wall aimed across the core.

## 8. Building it (tech sketch, not decided)
Author the level as a block grid (e.g. 4 m cells, 32³). Each solid block carries an orientation
tag. Quarter-pipes and lips are generated wherever surfaces of different orientations meet, and
gravity volumes are computed from the same data. One data file then holds the geometry, the
gravity and the connection graph, which makes the checks in step 3 testable.

## 9. Road-first generation
The other way in: forget faces and start from the road. The play space is one continuous road
looping through the volume, and the cube shell is the safety net (and a road in its own right)
underneath it. Built in `scripts/world/road_gen.gd`; try it with `.\run.ps1 --arena roads --seed N`
(N in game picks a new seed, M switches back to the starter layout).

**A road is a framed curve.** Every point has a position, a direction and an "up" (the surface
normal, and so gravity under the surface rule). Only three things can happen to a frame:
| transition | what turns | feel |
|---|---|---|
| bend | direction turns in the road's plane | an ordinary corner |
| quarter-pipe (concave) | direction turns *toward* up, up turns with it | climb onto a wall or ceiling; sticks at any speed |
| crest (convex) | direction turns *away* from up | a lip: above about sqrt(g x r) a fast tank leaves the road |
| twist | up rolls about the direction | Escher bridge; disorienting, so rationed |

**Lattice.** The road visits the nodes of a 3D lattice (`spacing` 24 m, 5 x 5 x 5 nodes), each
node at most once, so roads never cross or clip each other. Every corner is a quarter-circle arc
of radius spacing / 2, so a corner is one of the three turning transitions above. Twists happen
only on straights: a roll inside a 12 m corner folds the deck into a crease that traps tanks
(found by `test_road_drive`), so the orientation step forbids it.

**Grow, orient, score.**
1. *Grow:* start from a square loop, then repeatedly replace an edge u->v with a detour
   u->u+e->v+e->v. Every step keeps the loop closed and self-avoiding, so there is never any
   repair to do.
2. *Orient:* each straight's up is one of four axes. Dynamic programming around the loop picks
   them all at once, minimising: disagreement with the airborne gravity (`w_align`: fall off
   anywhere and you fall toward a surface that matches), rolls (`w_twist`, `w_flip`) and crests
   (`w_crest`). Because the loop is closed, the frame has to come back to itself, and twists are
   how the generator pays for that when it must.
3. *Score:* `candidates` loops per seed are graded and the best is kept: spread of road over the
   six up directions (`w_balance`), visits to all six gravity pyramids (`w_spread`), minus the
   orientation cost and any shortfall in length.

**Settings and the play-space property each one controls**
| setting | default | controls |
|---|---|---|
| `target_nodes` | 28 | loop length: about 28 x 24 m, ~550 m after the corners, a ~20 s lap at full speed. Shorter means more meetings |
| `spacing` | 24 m | corner radius (spacing / 2) and the gap between parallel roads (spacing - width). 16 m made 8 m corners, tighter than the tank's turn rate at speed |
| `core_radius` | 18 m | the open core: sightlines across the cube, room to jump through |
| `hug` | 0.6 | 0 fills the volume (dense, interchange-like), 1 hugs the faces (open middle, like the cube interior) |
| `extent` | 2 | how close to the shell roads can run (2 x 24 = 48 m of the 64 m half-size) |
| `w_align` | 2 | how much the road's up must agree with the airborne gravity; high = falling off is fair |
| `w_twist` / `w_flip` | 1.5 / 8 | disorientation budget: 90 degree rolls allowed sparingly, 180 degree rolls almost never |
| `w_crest` | 4 | lips on the main line; lower it to get jumps (with r = 12 m and g = 30, anything over ~19 m/s flies) |
| `w_balance` / `w_spread` | 3 / 2 | use the whole cube: road on every orientation and through every pyramid |
| `candidates` | 24 | loops tried per seed; more finds better scores (and survives loops with no valid orientation) |

**Dressing** (gray-box): a tower on the inside of every bend (the roundabout), a gatehouse arch
over every third straight, boost pads on others, crenellated rails along both edges. The deck is
solid, so its underside is drivable too.

**Still to try:** branches and junctions (a second loop grown from the first, joined at shared
nodes), designed jump links between nearby roads, point symmetry for team fairness (generate half,
mirror through the centre), and sightline and cover metrics in the score.

## Open questions
- Convex lips: stick at any speed, or launch above a threshold?
- In the air, does a tank's camera flip the instant gravity changes, or ease into it?
- Bolts in "straight" mode cross the core freely: is the floor-to-ceiling duel between bases too
  strong?
