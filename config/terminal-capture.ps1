# Ouvre une vraie fenetre de console PowerShell (conhost), y lance des commandes,
# attend que le resultat s'affiche, puis capture la fenetre en PNG avec PrintWindow.
# Usage : terminal-capture.ps1 -Script D:\...\cmd.ps1 -Out D:\tp-kvm\captures\09-ssh-depuis-windows.png -Wait 8
param(
    [Parameter(Mandatory)][string]$Script,
    [Parameter(Mandatory)][string]$Out,
    [int]$Wait = 8,
    [int]$Cols = 110, [int]$Rows = 34, [int]$FontSize = 20
)

Add-Type -AssemblyName System.Drawing
if (-not ("TermCap" -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TermCap {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
}
'@
}
[TermCap]::SetProcessDPIAware() | Out-Null

# Petit script de demarrage : police lisible, taille de fenetre, puis les commandes
$boot = Join-Path $env:TEMP ("term-boot-" + [guid]::NewGuid().ToString("N") + ".ps1")
@"
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class F {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct CFI { public uint cbSize; public uint n; public short X; public short Y; public int Fam; public int W;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string Face; }
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref CFI f);
  public static void Set(short size) { CFI f = new CFI(); f.cbSize=(uint)Marshal.SizeOf(f); f.Y=size; f.Fam=54; f.W=400; f.Face="Consolas";
    SetCurrentConsoleFontEx(GetStdHandle(-11), false, ref f); }
}
'@
[F]::Set($FontSize)
`$Host.UI.RawUI.BackgroundColor = 'Black'; `$Host.UI.RawUI.ForegroundColor = 'Gray'
try { `$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size($Cols, 3000) } catch {}
try { `$Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size($Cols, $Rows) } catch {}
`$Host.UI.RawUI.WindowTitle = 'Windows PowerShell'
Clear-Host
function prompt { 'PS D:\tp-kvm> ' }
. '$Script'
"@ | Out-File -Encoding utf8 $boot

$p = Start-Process conhost.exe -ArgumentList "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File `"$boot`"" -PassThru
Start-Sleep -Seconds $Wait

# Retrouver la fenetre de cette console a partir du processus PowerShell enfant
$child = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | Where-Object Name -eq 'powershell.exe' | Select-Object -First 1
[TermCap]::FreeConsole() | Out-Null
[TermCap]::AttachConsole([uint32]$child.ProcessId) | Out-Null
$hwnd = [TermCap]::GetConsoleWindow()
[TermCap]::FreeConsole() | Out-Null

$r = New-Object TermCap+RECT
[TermCap]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.R - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[TermCap]::PrintWindow($hwnd, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

Stop-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
Stop-Process -Id $p.Id -ErrorAction SilentlyContinue
Remove-Item $boot -ErrorAction SilentlyContinue
"$Out ($w x $h)"
