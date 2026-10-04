$ErrorActionPreference='SilentlyContinue'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HalliseumFocusNative {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
function Focus-GSPro {
    try {
        $g=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0} | Select-Object -First 1
        if($g){
            [HalliseumFocusNative]::ShowWindowAsync($g.MainWindowHandle,9) | Out-Null
            Start-Sleep -Milliseconds 100
            [HalliseumFocusNative]::SetForegroundWindow($g.MainWindowHandle) | Out-Null
            $w=New-Object -ComObject WScript.Shell
            [void]$w.AppActivate($g.Id)
        }
    } catch {}
}
Start-Sleep -Milliseconds 900
Focus-GSPro
Start-Sleep -Milliseconds 1800
Focus-GSPro
