# run.ps1 - play the gray-box prototype (windowed). Extra args go to the game, e.g.
#   .\run.ps1                          # the castle skatepark (M cycles arenas; --arena starter for the cube)
#   .\run.ps1 --arena roads --seed 7   # a generated road loop
#   .\run.ps1 --arena roads --bot      # watch your tank follow the road by itself
#   .\run.ps1 --bolt straight          # start in straight-bolt mode (B toggles in game)
.  "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-BtGodot
& $godot --path $PSScriptRoot -- @args
exit $LASTEXITCODE
