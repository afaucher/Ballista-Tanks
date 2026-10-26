# setup_art_tools.ps1 - fetch the art pipeline's tools (docs/design/tank-art-pipeline.md):
#   build\deps\blender\  Blender portable at the pinned version (~400 MB, from download.blender.org)
#   tools\.venv\         Python venv with numpy, opencv-python, pillow (for tools\compare.py)
# Both are gitignored. The game, its tests and its build need neither.
.  "$PSScriptRoot\..\godot_env.ps1"
$root = Split-Path $PSScriptRoot -Parent
$dir = Join-Path $root "build\deps\blender"
$name = "blender-$BtBlenderVersion-windows-x64"
if (-not (Test-Path "$dir\$name\blender.exe")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $minor = ($BtBlenderVersion -split "\.")[0..1] -join "."
    $url = "https://download.blender.org/release/Blender$minor/$name.zip"
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile "$dir\$name.zip"
    Expand-Archive -Path "$dir\$name.zip" -DestinationPath $dir
    Remove-Item "$dir\$name.zip"
}
& "$dir\$name\blender.exe" -b --version | Select-Object -First 1

$venv = Join-Path $root "tools\.venv"
if (-not (Test-Path "$venv\Scripts\python.exe")) { python -m venv $venv }
& "$venv\Scripts\python.exe" -m pip install -q numpy opencv-python pillow
& "$venv\Scripts\python.exe" -c "import numpy, cv2, PIL; print('numpy', numpy.__version__, 'opencv', cv2.__version__, 'pillow', PIL.__version__)"
