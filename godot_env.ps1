# godot_env.ps1 - locate the Godot 4.7 console binary for this project.
# Order: $env:BT_GODOT, then the copy Hero-Reader's tools/setup.py installed
# next door (..\Hero-Reader\third_party\godot). No machine-wide fallback.
function Resolve-BtGodot {
    if ($env:BT_GODOT -and (Test-Path $env:BT_GODOT)) { return $env:BT_GODOT }
    $sibling = Join-Path $PSScriptRoot "..\Hero-Reader\third_party\godot\Godot_v4.7-stable_win64_console.exe"
    if (Test-Path $sibling) { return (Resolve-Path $sibling).Path }
    throw "Godot 4.7 not found. Set BT_GODOT to Godot_v4.7-stable_win64_console.exe."
}

# Blender (art tools only): $env:BT_BLENDER, then the pinned portable copy under build/deps
# (tools/setup_art_tools.ps1 fetches it).
$BtBlenderVersion = "4.5.15"
function Resolve-BtBlender {
    if ($env:BT_BLENDER -and (Test-Path $env:BT_BLENDER)) { return $env:BT_BLENDER }
    $pinned = Join-Path $PSScriptRoot "build\deps\blender\blender-$BtBlenderVersion-windows-x64\blender.exe"
    if (Test-Path $pinned) { return $pinned }
    throw "Blender $BtBlenderVersion not found. Run tools\setup_art_tools.ps1 or set BT_BLENDER."
}

# Import (or reimport) the project once so class_name caches and .import files exist.
function Invoke-BtImport([string]$Godot) {
    & $Godot --path $PSScriptRoot --headless --import 2>&1 | Out-Null
}
