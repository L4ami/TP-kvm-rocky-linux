# Capture la fenetre VMware Workstation (meme si elle est derriere d'autres fenetres)
# et l'enregistre en PNG. Usage : capture-fenetre.ps1 -Out D:\tp-kvm\captures\07-installation-anaconda.png
param([Parameter(Mandatory)][string]$Out, [string]$Process = "vmware")

Add-Type -AssemblyName System.Drawing
if (-not ("WinCap" -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinCap {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
}
[WinCap]::SetProcessDPIAware() | Out-Null
$p = Get-Process $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$r = New-Object WinCap+RECT
[WinCap]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$w = $r.R - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[WinCap]::PrintWindow($p.MainWindowHandle, $hdc, 2) | Out-Null   # 2 = PW_RENDERFULLCONTENT
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"$Out ($w x $h)"
