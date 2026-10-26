# preview.ps1 - render built parts to build\part_previews\<part>.png for a look.
#   .\tools\parts\preview.ps1 hull knight
.  "$PSScriptRoot\..\..\godot_env.ps1"
$blender = Resolve-BtBlender
& $blender -b --factory-startup --python "$PSScriptRoot\preview.py" -- @args 2>&1 |
    Where-Object { $_ -match "^PREVIEW|Error|Traceback|^\s+File" }
