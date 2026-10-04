param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$AppDir,
  [Parameter(Mandatory=$true)][string]$Club
)
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'FactorGolf_Display_Helper.ps1')

$cfgPath=Join-Path $AppDir 'config.json'; $defPath=Join-Path $AppDir 'config.default.json'
$config=if(Test-Path $cfgPath){Get-Content $cfgPath -Raw|ConvertFrom-Json}else{Get-Content $defPath -Raw|ConvertFrom-Json}
$seconds=20; try{$seconds=[int]$config.ClubCheatSheetDisplaySeconds}catch{}; if($seconds -lt 5){$seconds=5}; if($seconds -gt 60){$seconds=60}

function Normalize-Club([string]$c){
  $u=($c.Trim().ToUpper() -replace '[^A-Z0-9]','')
  switch -Regex ($u) {
    '^(DR|D|DRIVER)$' { return 'DRIVER' }
    '^(3W|W3|3WOOD)$' { return '3 WOOD' }
    '^(5W|W5|5WOOD)$' { return '5 WOOD' }
    '^(7W|W7|7WOOD)$' { return '7 WOOD' }
    '^(2H|H2|2HYBRID)$' { return '2 HYBRID' }
    '^(3H|H3|3HYBRID)$' { return '3 HYBRID' }
    '^(4H|H4|4HYBRID)$' { return '4 HYBRID' }
    '^(5H|H5|5HYBRID)$' { return '5 HYBRID' }
    '^(I?([3-9]))$' { return ($matches[2] + ' IRON') }
    '^(PW|PITCHINGWEDGE)$' { return 'PITCHING WEDGE' }
    '^(GW|GAPWEDGE|AW|APPROACHWEDGE)$' { return 'GAP WEDGE' }
    '^(SW|SANDWEDGE)$' { return 'SAND WEDGE' }
    '^(LW|LOBWEDGE)$' { return 'LOB WEDGE' }
    '^(PT|PUTTER|PUTT)$' { return 'PUTTER' }
    default { return ($c.Trim().ToUpper()) }
  }
}
$clubName=Normalize-Club $Club

function Get-Blueprint([string]$name){
  if($name -eq 'PUTTER'){
    return [ordered]@{Title='PUTTER';Subtitle='Putting fundamentals';Ball='Ball slightly forward of center';Stance='Comfortable, stable stance';Hands='Hands quiet and relaxed';Backswing='Rock the shoulders with a small, controlled stroke';Downswing='Return the face square without a hit or jab';Impact='Start the ball on your intended line';Finish='Hold the finish and keep your head quiet';Feel='Smooth tempo, square face, roll it through'}
  }
  if($name -eq 'DRIVER'){
    return [ordered]@{Title='DRIVER';Subtitle='Tee shot fundamentals';Ball='Ball just inside lead heel';Stance='Wide, athletic stance';Hands='Hands neutral; do not force them forward';Backswing='Make a full turn and keep width';Downswing='Swing through the ball, not down at it';Impact='Feel the club sweeping or moving slightly upward';Finish='Finish tall and balanced on the lead side';Feel='Wide turn, smooth speed, balanced finish'}
  }
  if($name -match 'WOOD|HYBRID'){
    return [ordered]@{Title=$name;Subtitle='Long-club fundamentals';Ball='Ball forward of center';Stance='Slightly wider than an iron';Hands='Arms hang naturally';Backswing='Turn around your chest and keep width';Downswing='Brush the turf; avoid trying to lift the ball';Impact='Shallow strike with the low point just after the ball';Finish='Balanced and fully turned';Feel='Sweep it through, do not scoop it'}
  }
  if($name -match 'WEDGE'){
    return [ordered]@{Title=$name;Subtitle='Wedge fundamentals';Ball='Center to slightly back for a stock shot';Stance='Narrower, athletic stance';Hands='Slightly ahead of the ball';Backswing='Compact turn; keep the motion connected';Downswing='Turn through and let the club descend';Impact='Ball first, then turf';Finish='Balanced, chest facing target';Feel='Compact swing, crisp contact'}
  }
  return [ordered]@{Title=$name;Subtitle='Iron fundamentals';Ball='Center to slightly forward of center';Stance='Medium width, athletic';Hands='Slightly ahead of the ball';Backswing='Turn your chest and keep the club in front of you';Downswing='Let the club come down through the ball';Impact='Ball first, then turf';Finish='Balanced on the lead side';Feel='Smooth turn, crisp strike, balanced finish'}
}
$b=Get-Blueprint $clubName
$coachingLevel='Rookie';try{if($config.PSObject.Properties.Name -contains 'CoachingLevel' -and $config.CoachingLevel){$coachingLevel=[string]$config.CoachingLevel}}catch{}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Factor Golf - Club Cheat Sheet" Width="1180" Height="700" ResizeMode="CanResize" Background="#08110D" Foreground="White" Topmost="True" ShowInTaskbar="False" MinWidth="900" MinHeight="600">
 <Window.Resources>
  <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#FFFFFF"/></Style>
  <Style TargetType="Button"><Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#244A38"/><Setter Property="BorderBrush" Value="#63B98A"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#2E684C"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#183D2C"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style x:Key="Panel" TargetType="Border"><Setter Property="Background" Value="#0D1C15"/><Setter Property="BorderBrush" Value="#244333"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="16"/><Setter Property="Padding" Value="18"/></Style><Style x:Key="Head" TargetType="TextBlock"><Setter Property="Foreground" Value="#7BE1AA"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="FontSize" Value="14"/></Style></Window.Resources>
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontWeight="Bold" FontSize="14"/><TextBlock x:Name="ClubTitle" FontWeight="Bold" FontSize="32"/><TextBlock x:Name="SubtitleText" Foreground="#D8E6DE" FontSize="14"/></StackPanel><Button x:Name="CloseButton" Grid.Column="1" Content="CLOSE" Width="120" Height="48" FontWeight="Bold" Background="#244A38" Foreground="White"/></Grid>
  <Border Grid.Row="1" Style="{StaticResource Panel}" Background="#123424" BorderBrush="#2F8056" Margin="0,16,0,14"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="SELECTED CLUB" Style="{StaticResource Head}"/><TextBlock x:Name="SelectedClubText" FontSize="28" FontWeight="Bold"/><TextBlock Text="If this is not the club in your hands, change the selected club in GSPro before you start." FontSize="16" Foreground="#EFF6F2" TextWrapping="Wrap" Margin="0,6,20,0"/></StackPanel><TextBlock x:Name="CountdownText" Grid.Column="1" Foreground="#D8E6DE" VerticalAlignment="Center" FontSize="14"/></Grid></Border>
  <Grid Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions><Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
   <Border Style="{StaticResource Panel}" Margin="0,0,8,8"><StackPanel><TextBlock Text="1  SETUP" Style="{StaticResource Head}"/><TextBlock x:Name="SetupText" FontSize="20" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
   <Border Grid.Column="1" Style="{StaticResource Panel}" Margin="8,0,0,8"><StackPanel><TextBlock Text="2  BACKSWING" Style="{StaticResource Head}"/><TextBlock x:Name="BackswingText" FontSize="20" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
   <Border Grid.Row="1" Style="{StaticResource Panel}" Margin="0,8,8,0"><StackPanel><TextBlock Text="3  DOWNSWING &amp; IMPACT" Style="{StaticResource Head}"/><TextBlock x:Name="DownImpactText" FontSize="20" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
   <Border Grid.Row="1" Grid.Column="1" Style="{StaticResource Panel}" Margin="8,8,0,0"><StackPanel><TextBlock Text="4  FINISH &amp; FEEL" Style="{StaticResource Head}"/><TextBlock x:Name="FinishText" FontSize="20" TextWrapping="Wrap" Margin="0,8,0,0"/><TextBlock x:Name="FeelText" FontSize="18" FontWeight="Bold" Foreground="#80DCA7" TextWrapping="Wrap" Margin="0,14,0,0"/></StackPanel></Border>
  </Grid>
  <TextBlock Grid.Row="3" Text="Club Cheat Sheet is a general club reference matched to your Golfer Experience. Your Coaching Card is the personalized part based on your BLP + SwingNerds session." Foreground="#C9DAD0" FontSize="13" TextWrapping="Wrap" Margin="2,14,0,0"/>
 </Grid>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml;$w=[Windows.Markup.XamlReader]::Load($reader)
foreach($n in @('ClubTitle','CloseButton','SubtitleText','SelectedClubText','CountdownText','SetupText','BackswingText','DownImpactText','FinishText','FeelText')){Set-Variable -Scope Script -Name $n -Value $w.FindName($n)}
$ClubTitle.Text=$b.Title+'  -  CLUB CHEAT SHEET';$SelectedClubText.Text=$b.Title
switch($coachingLevel){
 'Advanced'{
  $SubtitleText.Text='Pro / Advanced quick reference'
  $SetupText.Text=$b.Ball+'.'
  $BackswingText.Text=$b.Backswing+'.'
  $DownImpactText.Text=$b.Impact+'.'
  $FinishText.Text=$b.Finish+'.'
  $FeelText.Text=('KEY: '+$b.Feel)
 }
 'Amateur'{
  $SubtitleText.Text='Amateur club refresher'
  $SetupText.Text=($b.Ball+'. '+$b.Stance+'.')
  $BackswingText.Text=$b.Backswing
  $DownImpactText.Text=($b.Downswing+'. '+$b.Impact+'.')
  $FinishText.Text=$b.Finish
  $FeelText.Text=('FEEL: '+$b.Feel)
 }
 default{
  $SubtitleText.Text=$b.Subtitle+' - Rookie fundamentals'
  $SetupText.Text=($b.Ball+'. '+$b.Stance+'. '+$b.Hands+'.')
  $BackswingText.Text=$b.Backswing
  $DownImpactText.Text=($b.Downswing+'. '+$b.Impact+'.')
  $FinishText.Text=$b.Finish
  $FeelText.Text=('FEEL: '+$b.Feel)
 }
}
$screen=Resolve-FGScreen -Config $config -KeyProperty 'ClubCheatSheetDisplayKey' -IndexProperty 'ClubCheatSheetScreenIndex';$bounds=$screen.WorkingArea;$w.Width=[math]::Min(1180,[math]::Floor($bounds.Width*.86));$w.Height=[math]::Min(700,[math]::Floor($bounds.Height*.82));$w.Left=$bounds.Left+($bounds.Width-$w.Width)/2;$w.Top=$bounds.Top+($bounds.Height-$w.Height)/2
$deadline=(Get-Date).AddSeconds($seconds)
function Restore-GSProFocus{try{$g=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Select-Object -First 1;if($g){$ws=New-Object -ComObject WScript.Shell;[void]$ws.AppActivate($g.Id)}}catch{}}
$CloseButton.Add_Click({$w.Close()});$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(250);$timer.Add_Tick({$left=[math]::Ceiling(($deadline-(Get-Date)).TotalSeconds);if($left-le0){$w.Close();return};$CountdownText.Text="Auto-closes in $left sec"});$w.Add_ContentRendered({$timer.Start()});$w.Add_Closed({try{$timer.Stop()}catch{};Restore-GSProFocus});$w.ShowDialog()|Out-Null
