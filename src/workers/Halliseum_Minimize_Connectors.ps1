param(
    [string]$Root = "",
    [int]$PreferredPid = 0,
    [string]$ConnectorPath = ""
)
$ErrorActionPreference='SilentlyContinue'
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class FactorGolfTopWindow {
    public IntPtr Handle; public int Pid; public string Title; public string ClassName; public bool Visible;
}
public static class FactorGolfConnectorNative {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr extra);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    public static List<FactorGolfTopWindow> Snapshot(){
        var result=new List<FactorGolfTopWindow>();
        EnumWindows(delegate(IntPtr h, IntPtr l){
            uint p; GetWindowThreadProcessId(h,out p); var t=new StringBuilder(1024); var c=new StringBuilder(512); GetWindowText(h,t,t.Capacity); GetClassName(h,c,c.Capacity);
            result.Add(new FactorGolfTopWindow{Handle=h,Pid=(int)p,Title=t.ToString(),ClassName=c.ToString(),Visible=IsWindowVisible(h)}); return true;
        },IntPtr.Zero); return result;
    }
}
"@
$diagDir='';if($Root){$diagDir=Join-Path $Root 'UltimateCoach';New-Item -ItemType Directory -Path $diagDir -Force|Out-Null}
$diagPath=if($diagDir){Join-Path $diagDir 'connector_window_diagnostics.json'}else{''};$statusPath=if($diagDir){Join-Path $diagDir 'connector_minimize_status.json'}else{''}
function Get-Snapshot {
    $rows=@();foreach($w in [FactorGolfConnectorNative]::Snapshot()){
        try{$p=Get-Process -Id $w.Pid -ErrorAction SilentlyContinue;$path='';try{$path=[string]$p.Path}catch{};$rows += [pscustomobject]@{handle=$w.Handle.ToInt64();pid=$w.Pid;process=$(if($p){$p.ProcessName}else{''});title=$w.Title;class=$w.ClassName;path=$path;visible=$w.Visible}}catch{}
    };return $rows
}
function Test-ConnectorWindow($w){
    if(-not$w.visible){return $false}
    if($PreferredPid -gt 0 -and $w.pid -eq $PreferredPid){return $true}
    if($ConnectorPath -and $w.path -and ([string]::Equals($w.path,$ConnectorPath,[StringComparison]::OrdinalIgnoreCase))){return $true}
    $s=($w.process+' '+$w.title+' '+$w.class+' '+$w.path)
    if($s -match '(?i)VGP\s*connect|VGPconnect|ForesightForm|Visual\s*Golf|VisualGolf'){return $true}
    if($w.title -match '(?i)(Foresight|Bushnell|GSPro|GS Pro|VGP|Visual Golf).*(Connect|Connector|Launch|Device|Golf)'){return $true};if($w.title -match '(?i)^Foresight Sports.*$' -and $w.process -notmatch '(?i)^FSX'){return $true}
    if($w.process -match '(?i)(Foresight|Bushnell|VGP|VisualGolf|Visual_Golf).*'){return $true};if($w.process -match '(?i)(GSPro).*Connect'){return $true}
    return $false
}
$history=@();$deadline=(Get-Date).AddSeconds(75);if($statusPath){[ordered]@{state='started';message='Connector minimizer is watching for the Foresight/GSPro connector window.';updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $statusPath -Encoding UTF8}
do{
    $snapshot=@(Get-Snapshot);$targets=@($snapshot|Where-Object{Test-ConnectorWindow $_})
    foreach($t in $targets){try{[FactorGolfConnectorNative]::ShowWindowAsync(([IntPtr]$t.handle),6)|Out-Null}catch{}};if($statusPath -and $targets.Count -gt 0){try{[ordered]@{state='minimized';count=$targets.Count;targets=@($targets|ForEach-Object{[ordered]@{pid=$_.pid;process=$_.process;title=$_.title;class=$_.class}});updated=(Get-Date).ToString('o')}|ConvertTo-Json -Depth 6|Set-Content $statusPath -Encoding UTF8}catch{}}
    $history += [pscustomobject]@{time=(Get-Date).ToString('o');preferred_pid=$PreferredPid;connector_path=$ConnectorPath;targets=$targets;windows=$snapshot}
    if($diagPath){try{$history|ConvertTo-Json -Depth 7|Set-Content $diagPath -Encoding UTF8}catch{}}
    Start-Sleep -Milliseconds 700
}while((Get-Date)-lt$deadline)
