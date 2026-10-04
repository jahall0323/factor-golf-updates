param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$AppDir,
    [switch]$Preview
)
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'FactorGolf_Display_Helper.ps1')

$cfgPath=Join-Path $AppDir 'config.json';$defPath=Join-Path $AppDir 'config.default.json'
$config=if(Test-Path $cfgPath){Get-Content $cfgPath -Raw|ConvertFrom-Json}else{Get-Content $defPath -Raw|ConvertFrom-Json}
# One presentation lane: Coach Card and Club Cheat Sheet never stack.
try{Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object{$_.ProcessId -ne $PID -and $_.CommandLine -match 'Halliseum_Club_Cheat_Sheet\.ps1'}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}}catch{}
Start-Sleep -Milliseconds 120
$out=Join-Path $Root 'UltimateCoach';$responsePath=Join-Path $out 'latest_coach_response.json';$runtimePath=Join-Path $out 'coach_runtime.json';$followupPath=Join-Path $out 'latest_followup.json';$summaryPath=Join-Path $out 'latest_local_summary.json'

if($Preview){
    $coach=[pscustomobject]@{club='9 IRON';shot_count=8;headline='QUIET THE HEAD THROUGH IMPACT';biggest_issue='Your head moved enough to make the bottom of the swing inconsistent.';secondary_issue='Club path also worked a little left. Leave that alone for now.';ball_effect='Strike and carry moved around even when the swing felt similar.';feel_1='Turn around a steady head.';feel_2='Finish balanced on your lead side.';next_set='Hit five smooth 9-irons. Judge contact first, distance second.';body_metric_note='SwingNerds head drift was the body metric to watch.';confidence_note='Preview data only.';spoken_text='Preview'}
    $summary=[pscustomobject]@{primary_club='I9';shots_in_primary=8;stats=[pscustomobject]@{carry_median=103.5;ball_speed_median=78.1;club_speed_median=61.9;offline_median=-3.2;spin_axis_median=-6.8;path_median=-3.1;aoa_median=-3.8;vla_median=25.2;hla_median=-2.1;back_spin_median=6100;smash_median=1.26};visual_shots=@();swingnerds_samples=@([pscustomobject]@{head_drift='3.8% of height'})}
}else{
    if(-not(Test-Path $responsePath)){exit}
    try{$coach=Get-Content $responsePath -Raw|ConvertFrom-Json}catch{exit}
    $summary=$null;if(Test-Path $summaryPath){try{$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json}catch{}}
}
function Val($v,[string]$suffix=''){if($null -eq $v -or [string]$v -eq ''){return '-'};try{return (([double]$v).ToString('0.0')+$suffix)}catch{return ([string]$v+$suffix)}}
function Safe([string]$s,[string]$fallback){if([string]::IsNullOrWhiteSpace($s)){return $fallback};return $s.Trim()}
$club=Safe ([string]$coach.club) $(if($summary){[string]$summary.primary_club}else{'CLUB'})
$shots=if($coach.shot_count){[int]$coach.shot_count}elseif($summary){[int]$summary.shots_in_primary}else{0}
$stats=if($summary){$summary.stats}else{$null}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Factor Golf Coach" Width="1420" Height="820" WindowStartupLocation="Manual" Background="#08110D" Foreground="White" Topmost="True" ResizeMode="CanResize" MinWidth="1000" MinHeight="650">
 <Window.Resources>
  <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#FFFFFF"/></Style>
  <Style x:Key="Panel" TargetType="Border"><Setter Property="Background" Value="#0E1C15"/><Setter Property="BorderBrush" Value="#365846"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="16"/><Setter Property="Padding" Value="20"/></Style>
  <Style x:Key="Label" TargetType="TextBlock"><Setter Property="Foreground" Value="#83E9AF"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="FontSize" Value="14"/></Style>
  <Style TargetType="Button"><Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#24543D"/><Setter Property="BorderBrush" Value="#63B98A"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#2E684C"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#183D2C"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid Margin="22">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid Grid.Row="0" Margin="0,0,0,14"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="FACTOR GOLF" FontSize="15" FontWeight="Bold" Foreground="#D9B84C"/><TextBlock Text="COACHING SUMMARY" FontSize="30" FontWeight="Bold"/></StackPanel>
   <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"><StackPanel Margin="0,0,20,0"><TextBlock x:Name="ClubText" FontSize="28" FontWeight="Bold" HorizontalAlignment="Right"/><TextBlock x:Name="ShotsText" FontSize="14" Foreground="#DCE9E1" HorizontalAlignment="Right"/></StackPanel><Button x:Name="CloseButton" Content="CLOSE" Width="120" Height="48" FontSize="16" FontWeight="Bold" Background="#24543D" Foreground="White"/></StackPanel>
  </Grid>
  <UniformGrid Grid.Row="1" Columns="5" Margin="0,0,0,14">
   <Border Style="{StaticResource Panel}" Margin="0,0,7,0"><StackPanel><TextBlock Text="CARRY" Style="{StaticResource Label}" HorizontalAlignment="Center"/><TextBlock x:Name="CarryText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center"/></StackPanel></Border>
   <Border Style="{StaticResource Panel}" Margin="2,0,5,0"><StackPanel><TextBlock Text="BALL SPEED" Style="{StaticResource Label}" HorizontalAlignment="Center"/><TextBlock x:Name="BallText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center"/></StackPanel></Border>
   <Border Style="{StaticResource Panel}" Margin="4,0,4,0"><StackPanel><TextBlock Text="CLUB SPEED" Style="{StaticResource Label}" HorizontalAlignment="Center"/><TextBlock x:Name="ClubSpeedText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center"/></StackPanel></Border>
   <Border Style="{StaticResource Panel}" Margin="5,0,2,0"><StackPanel><TextBlock Text="LAUNCH" Style="{StaticResource Label}" HorizontalAlignment="Center"/><TextBlock x:Name="LaunchText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center"/></StackPanel></Border>
   <Border Style="{StaticResource Panel}" Margin="7,0,0,0"><StackPanel><TextBlock Text="OFFLINE" Style="{StaticResource Label}" HorizontalAlignment="Center"/><TextBlock x:Name="OfflineText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center"/></StackPanel></Border>
  </UniformGrid>
  <Border Grid.Row="2" Style="{StaticResource Panel}" Background="#123522" BorderBrush="#31865A" Margin="0,0,0,14">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="1.55*"/><ColumnDefinition Width="1.15*"/><ColumnDefinition Width="1.15*"/></Grid.ColumnDefinitions>
    <StackPanel Margin="0,0,18,0"><TextBlock Text="FIX FIRST" Style="{StaticResource Label}"/><TextBlock x:Name="HeadlineText" FontSize="27" FontWeight="Bold" TextWrapping="Wrap" Margin="0,4,0,0"/><TextBlock x:Name="IssueText" FontSize="18" TextWrapping="Wrap" Foreground="#DDE7E1" Margin="0,8,0,0"/></StackPanel>
    <StackPanel Grid.Column="1" Margin="8,0,18,0"><TextBlock Text="WHY IT MATTERS" Style="{StaticResource Label}"/><TextBlock x:Name="EffectText" FontSize="18" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel>
    <StackPanel Grid.Column="2"><TextBlock Text="ALSO SEEING" Style="{StaticResource Label}"/><TextBlock x:Name="SecondaryText" FontSize="17" TextWrapping="Wrap" Margin="0,6,0,0" Foreground="#EEF5F1"/></StackPanel>
   </Grid>
  </Border>
  <Grid Grid.Row="3"><Grid.ColumnDefinitions><ColumnDefinition Width="1.25*"/><ColumnDefinition Width="0.75*"/></Grid.ColumnDefinitions>
   <Border Style="{StaticResource Panel}" Margin="0,0,10,0"><StackPanel><TextBlock Text="NEXT 5 BALLS" Style="{StaticResource Label}"/><TextBlock x:Name="Feel1Text" FontSize="25" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,12,0,0"/><TextBlock x:Name="Feel2Text" FontSize="22" TextWrapping="Wrap" Margin="0,12,0,0" Foreground="#E2ECE6"/><TextBlock x:Name="NextSetText" FontSize="18" TextWrapping="Wrap" Margin="0,20,0,0" Foreground="#D5E4DB"/></StackPanel></Border>
   <Border Grid.Column="1" Style="{StaticResource Panel}" Margin="10,0,0,0"><StackPanel><TextBlock Text="WHAT LOOKED GOOD" Style="{StaticResource Label}"/><TextBlock x:Name="GoodText" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,10,0,18"/><TextBlock Text="DATA USED" Style="{StaticResource Label}"/><TextBlock x:Name="BodyText" FontSize="17" TextWrapping="Wrap" Margin="0,10,0,0"/><TextBlock x:Name="ConfidenceText" FontSize="16" TextWrapping="Wrap" Margin="0,14,0,0" Foreground="#D9E6DF"/><TextBlock x:Name="ClubDataText" FontSize="15" TextWrapping="Wrap" Margin="0,16,0,0" Foreground="#C7D8CE"/></StackPanel></Border>
  </Grid>
  <Border Grid.Row="4" Background="#0B1711" BorderBrush="#1D3327" BorderThickness="1" CornerRadius="12" Padding="12" Margin="0,14,0,0"><TextBlock x:Name="StatusText" Text="Coach conversation active." FontSize="14" TextWrapping="Wrap"/></Border>
 </Grid>
</Window>
'@
$r=New-Object System.Xml.XmlNodeReader $xaml;$window=[Windows.Markup.XamlReader]::Load($r)
foreach($n in @('ClubText','ShotsText','CloseButton','CarryText','BallText','ClubSpeedText','LaunchText','OfflineText','HeadlineText','IssueText','EffectText','SecondaryText','Feel1Text','Feel2Text','NextSetText','GoodText','BodyText','ConfidenceText','ClubDataText','StatusText')){Set-Variable -Scope Script -Name $n -Value $window.FindName($n)}
$ClubText.Text=$club;$ShotsText.Text=($shots.ToString()+' shots')
$CarryText.Text=(Val $(if($stats){$stats.carry_median}else{$null}) ' yd');$BallText.Text=(Val $(if($stats){$stats.ball_speed_median}else{$null}) ' mph');$ClubSpeedText.Text=(Val $(if($stats){$stats.club_speed_median}else{$null}) ' mph');$LaunchText.Text=(Val $(if($stats){$stats.vla_median}else{$null}) ' deg');$OfflineText.Text=(Val $(if($stats){$stats.offline_median}else{$null}) ' yd')
$HeadlineText.Text=Safe ([string]$coach.headline) 'COACHING PRIORITY';$IssueText.Text=Safe ([string]$coach.biggest_issue) 'No primary issue was returned.';$EffectText.Text=Safe ([string]$coach.ball_effect) 'No ball-effect explanation was returned.';$SecondaryText.Text=Safe ([string]$coach.secondary_issue) 'No meaningful secondary issue.';$Feel1Text.Text=('1. '+(Safe ([string]$coach.feel_1) 'Make one smooth swing.'));$Feel2Text.Text=('2. '+(Safe ([string]$coach.feel_2) 'Finish balanced.'));$NextSetText.Text=Safe ([string]$coach.next_set) 'Hit another short set with the same club.';$GoodText.Text=Safe ([string]$coach.did_well) 'No positive pattern was returned for this set.';$BodyText.Text=Safe ([string]$coach.body_metric_note) 'No SwingNerds body metric was used.';$ConfidenceText.Text=Safe ([string]$coach.confidence_note) 'Ball-flight data was used.'
$clubCount=0;$snCount=0;if($summary){try{$clubCount=@($summary.visual_shots|Where-Object{$null -ne $_.path -or $null -ne $_.aoa}).Count}catch{};try{$snCount=@($summary.swingnerds_samples).Count}catch{}};$ClubDataText.Text=('BLP club-data shots: '+$clubCount+'/'+$shots+'   |   SwingNerds samples: '+$snCount)

$screen=Resolve-FGScreen -Config $config -KeyProperty 'CoachCardDisplayKey' -IndexProperty 'CoachCardScreenIndex';$b=$screen.WorkingArea;$window.Width=[math]::Min(1420,[math]::Floor($b.Width*0.90));$window.Height=[math]::Min(820,[math]::Floor($b.Height*0.88));$window.Left=$b.Left+($b.Width-$window.Width)/2;$window.Top=$b.Top+($b.Height-$window.Height)/2
$CloseButton.Add_Click({$window.Close()})
$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(450);$deadline=if($Preview){(Get-Date).AddSeconds(15)}else{$null};$script:lastFollow=''
$timer.Add_Tick({if($Preview -and (Get-Date)-gt $deadline){$window.Close();return};if(-not$Preview -and(Test-Path $runtimePath)){try{$x=Get-Content $runtimePath -Raw|ConvertFrom-Json;$StatusText.Text=[string]$x.message;if([bool]$x.dismiss){$window.Close();return}}catch{}};if(-not$Preview -and(Test-Path $followupPath)){try{$f=Get-Content $followupPath -Raw|ConvertFrom-Json;if([string]$f.updated -and [string]$f.updated -ne $script:lastFollow){$script:lastFollow=[string]$f.updated;$StatusText.Text=('You: '+[string]$f.question+'    Coach: '+[string]$f.answer)}}catch{}}})
$timer.Start();$window.Add_Closed({try{$timer.Stop()}catch{}});$window.ShowDialog()|Out-Null
