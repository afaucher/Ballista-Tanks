# play_session.ps1 - play the real game window with OS-level keyboard and mouse input (Windows
# SendInput, the same path a physical keyboard and mouse take), saving screenshots along the way.
# Input is only sent while the game window is in the foreground; otherwise the step is skipped
# and reported, so keystrokes never land in another app.
#   .\tools\play_session.ps1 -ShotDir build\park\play
param([string]$ShotDir = "build\park\play")
. "$PSScriptRoot\..\godot_env.ps1"
$godot = (Resolve-BtGodot) -replace "_console\.exe$", ".exe"   # the windowed build owns the game window
$root = Split-Path $PSScriptRoot -Parent
$shots = Join-Path $root $ShotDir

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Inp {
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUT {
        [FieldOffset(0)] public uint type;
        [FieldOffset(8)] public MOUSEINPUT mi;
        [FieldOffset(8)] public KEYBDINPUT ki;
    }
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mapType);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    // Clicks land under the cursor: put it in the middle of the game window first.
    public static void CursorTo(IntPtr h) {
        RECT r;
        GetWindowRect(h, out r);
        SetCursorPos((r.l + r.r) / 2, (r.t + r.b) / 2);
    }
    // Windows only lets the foreground thread hand focus over: borrow its input queue to do it.
    public static void Focus(IntPtr h) {
        uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        uint me = GetCurrentThreadId();
        AttachThreadInput(me, fg, true);
        ShowWindow(h, 9);
        BringWindowToTop(h);
        SetForegroundWindow(h);
        AttachThreadInput(me, fg, false);
    }
    public static void Key(ushort vk, bool down) {
        var i = new INPUT[1];
        i[0].type = 1;
        i[0].ki.wScan = (ushort)MapVirtualKey(vk, 0);
        i[0].ki.dwFlags = 0x0008u | (down ? 0u : 0x0002u);   // SCANCODE (| KEYUP)
        SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void Mouse(int dx, int dy, uint flags) {
        var i = new INPUT[1];
        i[0].type = 0;
        i[0].mi.dx = dx; i[0].mi.dy = dy; i[0].mi.dwFlags = flags;
        SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@

$proc = Start-Process -FilePath $godot -ArgumentList @("--path", "`"$root`"", "--resolution", "1280x720", "--",
    "--shot-dir", "`"$shots`"", "--shot-times", "3.0,4.4,5.4,8.5") -PassThru
$deadline = (Get-Date).AddSeconds(10)
while ($proc.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100; $proc.Refresh() }
$hwnd = $proc.MainWindowHandle
[Inp]::Focus($hwnd)
$t0 = Get-Date
$log = @()

function Focused { return [Inp]::GetForegroundWindow() -eq $hwnd }
function At([double]$s) { while (((Get-Date) - $t0).TotalSeconds -lt $s) { Start-Sleep -Milliseconds 10 } }
function Step([string]$what, [scriptblock]$act) {
    if (Focused) { & $act; $script:log += ("{0,5:N1}s  {1}" -f ((Get-Date) - $t0).TotalSeconds, $what) }
    else { $script:log += "SKIPPED (game not in front): $what" }
}

$W = 0x57; $A = 0x41; $R = 0x52
At 1.0; Step "click in the middle of the game window (captures the mouse)" { [Inp]::CursorTo($hwnd); Start-Sleep -Milliseconds 50; if (Focused) { [Inp]::Mouse(0, 0, 0x0002); Start-Sleep -Milliseconds 50; [Inp]::Mouse(0, 0, 0x0004) } }
At 1.3; Step "W down: drive" { [Inp]::Key($W, $true) }
At 2.4; Step "A down: steer left" { [Inp]::Key($A, $true) }
At 2.9; Step "A up" { [Inp]::Key($A, $false) }
At 3.3; Step "W up" { [Inp]::Key($W, $false) }
At 3.5; Step "mouse right 120 px: aim" { [Inp]::Mouse(120, 0, 0x0001) }
At 3.8; Step "left button down: draw" { [Inp]::CursorTo($hwnd); [Inp]::Mouse(0, 0, 0x0002) }
At 4.35; Step "left button up: loose" { [Inp]::Mouse(0, 0, 0x0004) }
At 5.6; Step "R down: crank" { [Inp]::Key($R, $true) }
At 7.0; Step "R up" { [Inp]::Key($R, $false) }
$proc.WaitForExit(15000) | Out-Null
if (-not $proc.HasExited) { $proc.Kill() }
$log
Get-ChildItem $shots -Filter *.png | ForEach-Object { $_.FullName }
