# Castle skatepark: the play space (draft, 2026-10-26)

Replaces the cube arena and the generated road loops as the main direction. What carries over:
the tank (surface gravity on curves), the quarter-pipe transitions, and the "castle parts are
road parts" idea. What changes: an open battlefield with real height, built as a skatepark.

## The idea in one line
Two opposing castles, each a skatepark made of castle parts, joined by roads that climb up and
over the field on arches (some impossibly big), so the fight happens on the ground, on the walls
and in the air above them.

## The castle as a skatepark kit
Every castle part is also a skate feature, and every surface you can see you can drive.
| castle part | skate feature | how you use it |
|---|---|---|
| Moat | a bowl around the castle | carve it to build speed; the inner bank is the start of the wall |
| Curtain wall base | quarter-pipe transition (radius ~6 m) | the ground curves up into the vertical wall face |
| Wall face | vert ramp (~10 m) | ride straight up it with enough speed |
| Wall top edge | coping (rounded lip) | pop over it onto the wall walk, or air out above it |
| Battlements | rail-like crenellations, with **gaps** | a gap is a **drop-in**: roll off the wall walk, over the coping and straight down the outer face into the quarter-pipe and out across the ground |
| Wall walk | a flat lane along the top | fast, exposed, a firing platform |
| Towers | bowls you can ride inside (wall of death), spiral ramps outside | slow sure way up, or a carving loop inside |
| Gatehouse | a half-pipe channel through the wall | the fast way in and out at ground level |
| Bastions | kickers and launch ramps | air across the moat or onto a bridge |
| Keep | the centre: stacked levels joined by ramps and banks | each team's spawn and the hardest place to reach |

**Drop-ins are the signature move.** The crenellations stop you from falling off the wall walk
by accident; where a merlon is missing, the coping is rounded and you can roll off the top of
the wall, down its face (surface gravity holds you), through the quarter-pipe at the bottom and
out across the field at full speed. Going the other way, with enough speed you ride up the face
and pop over the coping through the same gap.

## Between the castles: roads in the air
- **The high bridge.** An aqueduct-style road from one castle's wall walk to the other's, at
  wall height or above. The fast but exposed route; it has drop-ins of its own, down its piers.
- **Giant arches.** Roads ride on arches, and some arches are absurdly big (60 m span, 40 m
  high). An arch is itself a road: drive up one leg, over the top (or around its inside like a
  loop-the-loop, upside down at the crown) and down the other. Its legs meet the ground in
  quarter-pipes, so they are always reachable.
- **Nothing floats.** Every road either comes down to the ground on a ramp or bank, or stands on
  arches or piers. That is what makes the field read as a built place, not a road diagram.
- **Under the arches**, the ground stays open: the arches frame shots and give cover from above.

## Height, in layers
| layer | height | how you get there | how you leave |
|---|---|---|---|
| ground and moat bowls | 0 to -4 m | | |
| wall walks, gatehouse tops | ~10 m | ride up a wall face, a tower's spiral, a ramp | drop-ins, jumps |
| tower tops, high bridge | ~18-22 m | spiral ramps, bridge ramps | drop down the piers, jump |
| arch crowns | ~30-40 m | up the arch legs, fast | over and down, or fly off |
Higher is better for lobbing bolts and worse for cover: the roofs, arches and bridge undersides
are the cover from above.

## The physics decision this needs: when does the tank stick?
Today the tank sticks to any surface it is on, at any speed (the cube needed that). A skatepark
wants **momentum**: you stick to steep and upside-down surfaces only while you are fast enough,
and peel off and fall (normal gravity) when you are not. That turns walls, arches and loops into
skill features: carve the moat to build speed, then hit the wall. Proposal: stick fully on
gentle slopes (< ~45 degrees) at any speed; on steeper ones, stick only above a speed that rises
with steepness (vertical needs ~12 m/s, upside down ~16 m/s); below it, gravity is world down.
In the air, gravity is always world down.

## Layout sketch
- Field about 220 m long, 120 m wide. Castles about 140 m apart (keep to keep), mirrored for
  fairness.
- Each castle: about 60 x 60 m. A curtain wall with a quarter-pipe base all round, four corner
  towers, a front gatehouse facing the enemy, a keep in the middle, a moat bowl outside the walls,
  drop-in gaps along the front and side walls.
- Middle: one giant arch over the centre line (a loop you can ride), the high bridge from gate
  tower to gate tower on a row of arches, two side ramps from the ground up to the bridge.
- Spawns in the keeps; the centre arch's crown is the high point of the map.

## How we'd build it
The same pipeline as the tank: a kit of parametric pieces in Blender (`tools/parts/` style) with
clean collision. Wall segment (base transition, face, coping, walk, crenels with optional gaps),
tower (bowl inside, spiral outside), gatehouse channel, moat bowl, kicker, bridge span, arch
(span and height as parameters, rideable inside and out). Then one layout file places them and
a clearance test checks every road joins up.

## Gray-box v1 (as built, 2026-10-26)
- **Sticking is momentum-based** (`Tank.sticks`): any surface within 45 degrees of up holds the
  tank; steeper needs speed, rising to 12 m/s on a vertical wall and 16 m/s upside down. Slopes pull
  back with 60 % of gravity. In the air, and when it peels off, gravity is world down
  (`GravityField.uniform`). Full throttle out-pulls the slope, so a flat-out tank holds a wall; a slow
  one stalls part way up the quarter-pipe and rolls back when it lets go.
- **Kit** (`scripts/world/castle_kit.gd`, parametric meshes in Godot, not Blender yet): walls 10 m
  high and 14 m thick (a ~10 m lane between the battlements) with 6 m quarter-pipes on both faces and 1.5 m copings, merlons with drop-in
  gaps; round towers; a gate (lintel over a 10 m gap); the keep with a ramp up its front and banks
  from its top to the side walls' walks; the giant arch (52 m span, 36 m high, rideable over the top
  and round the inside as a loop); the bridge at walk height between the gates on twin-legged piers,
  with a ramp from each side of the field.
- **Layout** (`Arena.build_castles`): a 200 x 280 m field ringed by a skatepark wall (gaps every 30 m
  on its inner battlements to ride up onto its walk), castles 60 m square centred 70 m either side
  of the arch, mirrored by a half turn. Outdoor light: sky, a warm sun with shadows, haze.
- **Moat bowls** (`CastleKit.moat`): 4 m deep, outside every wall. Where a wall has a moat its outer
  quarter-pipe carries on down into it as one 10 m curve (vertical at the same 6 m), so the moat's
  inner bank is the wall: carve down the outer bank (a 6 m concave, then a 3 m convex lip), across
  a 2 m floor and straight up onto the walk. Each moat ends in 4 m quarter-pipes with a vertical lip
  at field level. The gate's causeway (10 m, plain ground) splits the front moat; the corners stay
  ground, for the spirals. The field slab is built round the moats (`Arena._ground`).
- **Tower spirals** (`CastleKit.spiral`): round every corner tower (now 20 m high). Each starts on its
  corner's ground with a 20 m straight run-up off the outer diagonal, climbs to walk height as it
  bridges the end of a moat, runs level across both walls' walks (and over the courtyard corner, so
  it also joins the two walks), then climbs again outside, tightening onto the tower, and arrives
  level with its top (a gap in the tower's merlons; the team roof now sits on a turret). Railed
  while it climbs, open where it crosses the walks; carried on beams from the tower. The walls'
  battlements open where it crosses, 10-20 m out from the middle of each side.
- **Kickers** (`CastleKit.kicker`, a 16 m curve to a 50 degree lip, 5.7 m high): a bastion in each
  castle's right moat that airs a flat-out tank over the moat onto the wall walk through a drop-in
  gap, and one beside the bridge on each half that airs you onto the deck (needs about 25 m/s).
- **Arch roads** (`CastleKit.arch_road`): a 10 m crenellated road rides the giant arch's back over the
  crown (37 m) and runs straight down at 25 degrees to the ground at x = +-84, on piers. Two sky arches
  (80 m span, 50 m high, also rideable inside as loops) stand along z in the side lanes at x = +-72,
  their roads over the crown at 51 m and down to the ground at z = +-117; the centre road passes
  under them. The bridge's side ramps moved in to z = +-10 (7 m wide) to stay out of the moats.
- **Wall-of-death drums** (`CastleKit.drum`, `Geo.lathe`): the field's corner towers are now drums
  16 m inside, 16 m high (a 6 m quarter-pipe floor, a vertical wall, a coping), the boundary walls
  running into them, each with an 8 x 7 m door to the field. Ride in, up the quarter-pipe and round
  the wall above the door, steering to hold a level line.
- **Tested** (`tests/test_castles.gd`): slow tank can't climb and rolls back, fast tank rides onto
  the walk; a drop-in off a side wall comes down through the moat and out onto the field at 17 m/s;
  from the field a flat-out tank carves through the moat and up its wall onto the walk; a tank
  following a spiral at 60 % throttle reaches the tower top without leaving it; the bastion and
  bridge kickers land you on the walk and the deck; the arch road goes over the crown and
  down the far side without leaving the surface; the loop; once round a drum's wall of death.
- Not yet: Blender kit pieces; a wall of death inside the castle towers (they're solid: the
  spirals and walls fill them); drop-ins on the front walls (the spiral crossings took the room).

## Open questions
1. Stickiness: momentum-based as proposed, or always stick as now?
2. The cube: drop it, or keep it as a separate arena?
3. Ground: an open meadow around the castles, or an enclosed valley so you can't drive off the map?
