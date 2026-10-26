# Ballista Tanks

Wacky team tank combat in Godot 4.7. The tanks have giant ballistas instead of turrets, and the
arena is made of castle-shaped blocks built for 3D driving and shooting. See
`docs/design/game-concept.md`.

## Gray-box prototype
```powershell
.\run.ps1                          # starter layout: two keeps, wall arches, pillars, launch pads
.\run.ps1 --arena roads --seed 7   # a generated road loop through the cube
.\run.ps1 --arena roads --bot --demo   # watch the tank chase and shoot an enemy by itself
.\test_runner.ps1 -TestAll         # headless tests
```
WASD drive, Shift drift, Space hop, mouse aim, left mouse to fire, R or
the wheel to winch the string back (a bolt drops in at full tension). B switches bolt gravity (straight / shooter's down), M switches
arena, N rolls a new road seed, T resets, F1 hides the help.

## Concept art
```powershell
python art/concept.py --dry-run          # print the prompts
python art/concept.py                    # every style x every shot -> art/concepts/
python art/concept.py --style toybox --shot cockpit --n 3
```
