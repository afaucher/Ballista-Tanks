# build.ps1 - build tank parts in headless Blender into assets/tank/<part>.glb.
#   .\tools\parts\build.ps1               # every part
#   .\tools\parts\build.ps1 road_wheel    # just these
.  "$PSScriptRoot\..\..\godot_env.ps1"
$blender = Resolve-BtBlender
& $blender -b --factory-startup --python "$PSScriptRoot\build.py" -- @args 2>&1 |
    Where-Object { $_ -match "^PART|Error|Traceback|^\s+File" }
exit $LASTEXITCODE
