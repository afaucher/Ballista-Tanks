# Ballista Tanks: game concept

## Pitch
Wacky team combat. Little tanks have had their turrets ripped off and a giant ballista
(a siege crossbow) bolted on in its place. Two teams drive around an arena built out of
simplified castle pieces and shoot giant bolts at each other.

## Pillars
1. **Fast and forgiving to drive.** Arcade handling in the Mario Kart family: drift, boost
   pads, big air off ramps, quick recovery after a flip. Nothing is a tank sim.
2. **The ballista is the whole game.** It sits right in front of the driver's head, filling
   the bottom of the screen. You reload it, aim it and fire it while you drive.
3. **An arena, not a castle.** The level is obviously a built play space: castle-shaped
   blocks laid out for 3D tank combat. Ramps up to the battlements, bridges over moats,
   gatehouses to drive through, towers to circle. Nobody would mistake it for a real castle.
4. **Wacky.** Bolts pin tanks to walls, flip them, send them spinning. Getting hit is funny,
   not punishing.

## The arena: inside a cube
A flat map was too flat. The arena is the inside surface of a hollow cube, Escher style, with
castle pieces built on all six inner faces.
- **Local gravity.** "Down" is into whatever surface a tank is on, never a global axis. A tank on
  the ceiling drives upside down relative to one on the floor.
- **Curved quarter-pipe edges.** Every edge between two faces is a smooth curve, so a tank drives
  from the floor up onto a wall without stopping, and its "down" rotates with the curve. No hard
  edges, no gravity portals. (Decided 2026-10-26.)
- **Orientation aids: none for now.** No colour coding per face. Revisit after playtests if
  players get lost.
- **Bolt gravity: undecided, prototype both.** (a) Straight: bolts fly in a straight line with no
  drop. (b) Shooter's down: a bolt falls toward the shooter's local "down" at the moment of firing,
  for its whole flight. The prototype has a toggle between them.

## Controls (keyboard + mouse)
| input | action |
|---|---|
| W / S | throttle / brake and reverse |
| A / D | steer the hull |
| Shift | drift (hold), boost out of a long drift |
| Space | hop (start a drift, small jumps) |
| Mouse | aim the ballista: it swivels independently of the hull, within a wide arc |
| Left mouse | fire (a loaded bolt flies at full tension) |
| R (or scroll) | crank the winch to reload |

The aim and the hull are independent: you can drive one way and shoot another, like a tank
turret, but the ballista's traverse is limited so hard flanking still needs the hull.

## The ballista loop
1. **Crank.** The winch draws the string back. Cranking takes a moment and is done while
   driving; it is the main skill tax on firing.
2. **Load.** A bolt drops into the groove (automatic after cranking).
3. **Aim.** Depends on the bolt-gravity mode (see the arena): with drop, lob over walls or fire
   flat at close range; with straight bolts, point and shoot across the cube.
4. **Loose.** A heavy bolt flies. Hits shove, flip or pin; direct hits score.

Open questions: ammo types (fire, rope/harpoon, explosive), whether reload is a mash, a hold
or a rhythm, and how many hits a tank takes.

## Mode (first)
Team deathmatch, 4v4, short rounds. Later: capture the banner, king of the keep.

## Tech
Godot 4.7, built from the same setup as Cast and Bridge to Friendship (pinned engine,
PowerShell scripts, `test_runner.ps1`). Networking comes after the driving and shooting feel
good locally.
