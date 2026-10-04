param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$AppDir)
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'FactorGolf_Display_Helper.ps1')
$configPath=Join-Path $AppDir 'config.json';$defPath=Join-Path $AppDir 'config.default.json'
$config=if(Test-Path $configPath){Get-Content $configPath -Raw|ConvertFrom-Json}else{Get-Content $defPath -Raw|ConvertFrom-Json}
$out=Join-Path $Root 'UltimateCoach';New-Item -ItemType Directory -Path $out -Force|Out-Null
$statePath=Join-Path $out 'performance_mapping_state.json'

function Median($vals){$a=@($vals|Where-Object{$null -ne $_}|ForEach-Object{[double]$_}|Sort-Object);if($a.Count -eq 0){return $null};$m=[int][math]::Floor($a.Count/2);if($a.Count%2){return [double]$a[$m]};return ([double]$a[$m-1]+[double]$a[$m])/2}
function WeightedQuantile($items,[double]$q){$a=@($items|Where-Object{$null -ne $_.value -and [double]$_.weight -gt 0}|Sort-Object value);if($a.Count -eq 0){return $null};$total=($a|Measure-Object weight -Sum).Sum;if($total -le 0){return $null};$target=$total*$q;$s=0.0;foreach($x in $a){$s+=[double]$x.weight;if($s -ge $target){return [double]$x.value}};return [double]$a[-1].value}
function Load-State{if(Test-Path $statePath){try{return Get-Content $statePath -Raw|ConvertFrom-Json}catch{}};return [pscustomobject]@{global_reset_before=$null;club_resets=@();excluded_files=@()}}
function Save-State($s){$s|ConvertTo-Json -Depth 8|Set-Content $statePath -Encoding UTF8}
function Club-ResetCutoff($s,[string]$club){$best=$null;if($s.global_reset_before){try{$best=[datetime]::Parse([string]$s.global_reset_before)}catch{}};foreach($r in @($s.club_resets)){if([string]$r.club -eq $club){try{$d=[datetime]::Parse([string]$r.reset_before);if($null -eq $best -or $d -gt $best){$best=$d}}catch{}}};return $best}
function Get-ValidShots($shots){
    $all=@($shots|Where-Object{$null -ne $_.carry -and [double]$_.carry -gt 0});if($all.Count -lt 2){return $all}
    $cm=Median ($all|ForEach-Object{$_.carry});$bm=Median ($all|ForEach-Object{$_.ball_speed})
    $v=@($all|Where-Object{([double]$_.carry -ge (0.60*$cm)) -and (($null -eq $_.ball_speed) -or ($null -eq $bm) -or ([double]$_.ball_speed -ge (0.75*$bm)))})
    if($v.Count -ge 5){$med=Median ($v|ForEach-Object{$_.carry});$mad=Median ($v|ForEach-Object{[math]::Abs([double]$_.carry-$med)});$limit=[math]::Max(8.0,3.0*[double]$mad);$v=@($v|Where-Object{[math]::Abs([double]$_.carry-$med) -le $limit})}
    return $v
}
function Load-Sessions{
    $result=@();$files=Get-ChildItem $out -Filter 'coach_set_*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending
    foreach($f in $files){try{$j=Get-Content $f.FullName -Raw|ConvertFrom-Json;$when=$f.LastWriteTime;try{$when=[datetime]::Parse([string]$j.set_ended)}catch{};$shots=@($j.shots);if($shots.Count -eq 0){continue};$groups=@($shots|Group-Object club|Sort-Object Count -Descending);$club=if($groups.Count){[string]$groups[0].Name}else{'UNKNOWN'};$clubShots=@($shots|Where-Object{[string]$_.club -eq $club});$valid=Get-ValidShots $clubShots;$carry=Median ($valid|ForEach-Object{$_.carry});$total=Median ($valid|ForEach-Object{$_.total});$result += [pscustomobject]@{File=$f.Name;Path=$f.FullName;When=$when;DateLabel=$when.ToString('ddd, MMM d, yyyy');TimeLabel=$when.ToString('h:mm tt');Club=$club;Shots=$clubShots.Count;ValidShots=$valid.Count;Carry=$carry;Total=$total;ValidData=$valid}}catch{}}
    return $result
}
function Build-Bag($sessions,$state){
    $half=45.0;try{$half=[double]$config.BagMappingHalfLifeDays}catch{};if($half -lt 7){$half=45}
    $recentDays=30;try{$recentDays=[int]$config.PerformanceRecentDays}catch{};$priorDays=90;try{$priorDays=[int]$config.PerformancePriorDays}catch{}
    $rows=@();$now=Get-Date
    foreach($grp in @($sessions|Group-Object Club|Sort-Object Name)){
        $club=[string]$grp.Name;$cutoff=Club-ResetCutoff $state $club;$usable=@($grp.Group|Where-Object{(-not($state.excluded_files -contains $_.File)) -and ($null -eq $cutoff -or $_.When -gt $cutoff) -and $_.ValidShots -gt 0})
        if($usable.Count -eq 0){continue}
        $points=@();$totalPoints=@();$sessionPoints=@();$recent=@();$prior=@();$validCount=0;$latest=($usable|Sort-Object When -Descending|Select-Object -First 1).When
        foreach($s in $usable){$age=[math]::Max(0,($now-$s.When).TotalDays);$rec=[math]::Pow(0.5,$age/$half);$sessionWeight=$rec*[math]::Min(1.5,[math]::Sqrt([math]::Max(1,$s.ValidShots)/5.0));$sessionPoints += [pscustomobject]@{value=[double]$s.Carry;weight=$sessionWeight};$validCount += $s.ValidShots
            foreach($sh in @($s.ValidData)){$w=$sessionWeight/[math]::Max(1,$s.ValidShots);$points += [pscustomobject]@{value=[double]$sh.carry;weight=$w};if($null -ne $sh.total -and [double]$sh.total -gt 0){$totalPoints += [pscustomobject]@{value=[double]$sh.total;weight=$w}}}
            if($age -le $recentDays){$recent += [pscustomobject]@{value=[double]$s.Carry;weight=$sessionWeight}}elseif($age -le $priorDays){$prior += [pscustomobject]@{value=[double]$s.Carry;weight=$sessionWeight}}
        }
        $carry=WeightedQuantile $points 0.5;$lo=WeightedQuantile $points 0.2;$hi=WeightedQuantile $points 0.8;$total=WeightedQuantile $totalPoints 0.5;$r=WeightedQuantile $recent 0.5;$p=WeightedQuantile $prior 0.5;$trend=$null;if($null -ne $r -and $null -ne $p){$trend=$r-$p}
        $medium=12;$high=30;$highSessions=3;try{$medium=[int]$config.BagMappingMinShotsMedium;$high=[int]$config.BagMappingMinShotsHigh;$highSessions=[int]$config.BagMappingMinSessionsHigh}catch{}
        $confidence='LOW';if($validCount -ge $medium -and $usable.Count -ge 2){$confidence='MEDIUM'};if($validCount -ge $high -and $usable.Count -ge $highSessions -and ($now-$latest).TotalDays -le 45){$confidence='HIGH'}
        $rows += [pscustomobject]@{Club=$club;RecommendedCarry=$(if($null -ne $carry){[math]::Round($carry,0)}else{$null});TypicalTotal=$(if($null -ne $total){[math]::Round($total,0)}else{$null});ReliableRange=$(if($null -ne $lo -and $null -ne $hi){([math]::Round($lo,0).ToString()+' - '+[math]::Round($hi,0).ToString())}else{'N/A'});Trend=$(if($null -ne $trend){if($trend -gt 0){'+'+[math]::Round($trend,0)}else{[math]::Round($trend,0).ToString()}}else{'N/A'});Confidence=$confidence;ValidShots=$validCount;Sessions=$usable.Count;LastUpdated=$latest.ToString('MMM d')}
    }
    return $rows
}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Factor Golf - Performance" Width="1220" Height="780"
        WindowStartupLocation="Manual"
        Background="#07100C" Foreground="#F7FFF9">
 <Window.Resources>
  <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#F7FFF9"/></Style>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#173A2A"/>
   <Setter Property="BorderBrush" Value="#63B98A"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontSize" Value="14"/>
   <Setter Property="Padding" Value="10,5"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#22513B"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#10291E"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Background" Value="#26342D"/><Setter TargetName="B" Property="BorderBrush" Value="#60766A"/><Setter Property="Foreground" Value="#E9F2ED"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ListBoxItem">
   <Setter Property="Foreground" Value="#F7FFF9"/><Setter Property="Background" Value="#0E1E16"/>
   <Setter Property="Padding" Value="8,6"/><Setter Property="BorderBrush" Value="Transparent"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Border x:Name="ItemBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter TargetName="ItemBorder" Property="BorderBrush" Value="#8D7631"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E6C65B"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="DataGridRow">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#0D1D15"/>
   <Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter Property="Background" Value="#0D1D15"/></Trigger></Style.Triggers>
  </Style>
  <Style TargetType="DataGridCell">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#254233"/>
   <Setter Property="Padding" Value="7,5"/>
   <Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter Property="Background" Value="Transparent"/></Trigger></Style.Triggers>
  </Style>
  <Style TargetType="DataGridColumnHeader">
   <Setter Property="Background" Value="#173A2A"/><Setter Property="Foreground" Value="#FFFFFF"/>
   <Setter Property="FontWeight" Value="Bold"/><Setter Property="FontSize" Value="13"/>
   <Setter Property="Padding" Value="7,6"/><Setter Property="BorderBrush" Value="#58A67B"/>
   <Setter Property="BorderThickness" Value="0,0,1,1"/><Setter Property="HorizontalContentAlignment" Value="Left"/>
  </Style>
  <Style TargetType="TabItem">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#173A2A"/><Setter Property="BorderBrush" Value="#4C8D68"/>
   <Setter Property="FontWeight" Value="Bold"/><Setter Property="FontSize" Value="14"/><Setter Property="Padding" Value="14,7"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TabItem"><Border x:Name="TabBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="7,7,0,0" Padding="{TemplateBinding Padding}"><ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter TargetName="TabBorder" Property="BorderBrush" Value="#E6C65B"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E6C65B"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Grid Margin="24">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

  <StackPanel>
   <TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontWeight="Bold" FontSize="15"/>
   <TextBlock Text="PERFORMANCE" Foreground="#FFFFFF" FontSize="34" FontWeight="Bold"/>
   <TextBlock Text="Session history and a living My Bag map that gives recent, repeatable shots more influence."
              Foreground="#E8F2EC" FontSize="15" Margin="0,5,0,16"/>
  </StackPanel>

  <TabControl Grid.Row="1" Background="#0A1710" Foreground="#FFFFFF" BorderBrush="#365846">
   <TabItem Header="SESSIONS">
    <Grid Margin="16">
     <Grid.ColumnDefinitions><ColumnDefinition Width="0.46*"/><ColumnDefinition Width="0.54*"/></Grid.ColumnDefinitions>
     <ListBox x:Name="SessionList" Background="#0D1D15" Foreground="#FFFFFF" BorderBrush="#365846" FontSize="15"/>
     <Border Grid.Column="1" Margin="16,0,0,0" Background="#0D1D15" BorderBrush="#365846" BorderThickness="1" CornerRadius="12" Padding="22">
      <StackPanel>
       <TextBlock x:Name="SessionTitle" Text="Select a session" Foreground="#FFFFFF" FontSize="25" FontWeight="Bold"/>
       <TextBlock x:Name="SessionDetail" Text="Date, club, shot count, carry and mapping details appear here."
                  Foreground="#E9F5EE" FontSize="17" LineHeight="25" TextWrapping="Wrap" Margin="0,14,0,0"/>
       <Button x:Name="ExcludeSessionButton" Content="EXCLUDE THIS SESSION FROM MY BAG" Height="46" Margin="0,24,0,0"
               Background="#704A2D" BorderBrush="#C89455" Foreground="#FFFFFF" FontWeight="Bold" IsEnabled="False"/>
      </StackPanel>
     </Border>
    </Grid>
   </TabItem>

   <TabItem Header="MY BAG">
    <Grid Margin="16">
     <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
     <DataGrid x:Name="BagGrid" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False"
               Background="#0D1D15" Foreground="#FFFFFF" RowBackground="#0D1D15" AlternatingRowBackground="#132A1E"
               HeadersVisibility="Column" ColumnHeaderHeight="38" RowHeight="34" GridLinesVisibility="Horizontal"
               HorizontalGridLinesBrush="#294939" BorderBrush="#365846" FontSize="14">
      <DataGrid.Columns>
       <DataGridTextColumn Header="Club" Binding="{Binding Club}" Width="80"/>
       <DataGridTextColumn Header="Recommended Carry" Binding="{Binding RecommendedCarry}" Width="155"/>
       <DataGridTextColumn Header="Typical Total" Binding="{Binding TypicalTotal}" Width="115"/>
       <DataGridTextColumn Header="Reliable Carry Range" Binding="{Binding ReliableRange}" Width="165"/>
       <DataGridTextColumn Header="30-Day Trend" Binding="{Binding Trend}" Width="110"/>
       <DataGridTextColumn Header="Confidence" Binding="{Binding Confidence}" Width="110"/>
       <DataGridTextColumn Header="Valid Shots" Binding="{Binding ValidShots}" Width="95"/>
       <DataGridTextColumn Header="Sessions" Binding="{Binding Sessions}" Width="85"/>
       <DataGridTextColumn Header="Updated" Binding="{Binding LastUpdated}" Width="95"/>
      </DataGrid.Columns>
     </DataGrid>
     <Grid Grid.Row="1" Margin="0,14,0,0">
      <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock Text="Use Recommended Carry when choosing a club. Factor Golf learns it from your recent, repeatable shots. Older shots count less, obvious mishits are ignored, and Typical Total is shown only when enough reliable total-distance data is available."
                 Foreground="#E8F2EC" FontSize="14" TextWrapping="Wrap" VerticalAlignment="Center" Margin="0,0,15,0"/>
      <StackPanel Grid.Column="1" Orientation="Horizontal">
       <Button x:Name="ResetClubButton" Content="RESET SELECTED CLUB" Width="175" Height="44" Margin="10,0,8,0"/>
       <Button x:Name="ResetAllButton" Content="RESET ALL MY BAG LEARNING" Width="225" Height="44"
               Background="#713C33" BorderBrush="#B9695D" Foreground="#FFFFFF"/>
      </StackPanel>
     </Grid>
    </Grid>
   </TabItem>
  </TabControl>

  <Grid Grid.Row="2" Margin="0,14,0,0">
   <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <TextBlock x:Name="StatusText" Text="Raw session files are preserved unless you explicitly delete them outside this screen."
              Foreground="#E3EEE7" FontSize="14" VerticalAlignment="Center"/>
   <Button x:Name="CloseButton" Grid.Column="1" Content="CLOSE" Width="120" Height="44"/>
  </Grid>
 </Grid>
</Window>
'@
$r=New-Object System.Xml.XmlNodeReader $xaml;$w=[Windows.Markup.XamlReader]::Load($r);foreach($n in @('SessionList','SessionTitle','SessionDetail','ExcludeSessionButton','BagGrid','ResetClubButton','ResetAllButton','StatusText','CloseButton')){Set-Variable -Scope Script -Name $n -Value $w.FindName($n)}
$script:sessions=@();$script:bag=@();$script:state=$null
function Refresh-UI{
 $script:state=Load-State;$script:sessions=@(Load-Sessions);$script:bag=@(Build-Bag $script:sessions $script:state);$SessionList.Items.Clear();foreach($s in $script:sessions){$excluded=$script:state.excluded_files -contains $s.File;$tag=if($excluded){'  [EXCLUDED FROM BAG]'}else{''};$item=New-Object System.Windows.Controls.ListBoxItem;$item.Content=($s.DateLabel+'  '+$s.TimeLabel+'  |  '+$s.Club+'  |  '+$s.Shots+' shots'+$tag);$item.Tag=$s;$SessionList.Items.Add($item)|Out-Null};$BagGrid.ItemsSource=$script:bag
}
$SessionList.Add_SelectionChanged({$it=$SessionList.SelectedItem;if(-not$it){return};$s=$it.Tag;$SessionTitle.Text=($s.DateLabel+' - '+$s.Club);$carry=if($null -ne $s.Carry){[math]::Round([double]$s.Carry,1).ToString()+' yd'}else{'N/A'};$total=if($null -ne $s.Total){[math]::Round([double]$s.Total,1).ToString()+' yd'}else{'not captured'};$SessionDetail.Text=('Time: '+$s.TimeLabel+"`nClub: "+$s.Club+"`nShots: "+$s.Shots+' ('+$s.ValidShots+" used for mapping)`nMedian carry: "+$carry+"`nTypical total: "+$total+"`n`nExcluding a session keeps the report but removes it from My Bag learning.");$ExcludeSessionButton.IsEnabled=$true})
$ExcludeSessionButton.Add_Click({$it=$SessionList.SelectedItem;if(-not$it){return};$s=$it.Tag;$ans=[System.Windows.MessageBox]::Show('Exclude this session from My Bag learning? The session report will remain visible.','Factor Golf Performance',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question);if($ans -eq [System.Windows.MessageBoxResult]::Yes){$st=Load-State;$files=@($st.excluded_files);if(-not($files -contains $s.File)){$files += $s.File};$st.excluded_files=$files;Save-State $st;$StatusText.Text='Session excluded from My Bag learning.';Refresh-UI}})
$ResetClubButton.Add_Click({$row=$BagGrid.SelectedItem;if(-not$row){[System.Windows.MessageBox]::Show('Select a club row first.','Factor Golf Performance')|Out-Null;return};$club=[string]$row.Club;$ans=[System.Windows.MessageBox]::Show("Reset learned mapping for $club? Past session reports remain saved, but My Bag will ignore all $club data collected before now.",'Reset club mapping',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning);if($ans -eq [System.Windows.MessageBoxResult]::Yes){$st=Load-State;$arr=@($st.club_resets|Where-Object{[string]$_.club -ne $club});$arr += [pscustomobject]@{club=$club;reset_before=(Get-Date).ToString('o')};$st.club_resets=$arr;Save-State $st;$StatusText.Text="$club mapping reset. New shots will rebuild it.";Refresh-UI}})
$ResetAllButton.Add_Click({$ans=[System.Windows.MessageBox]::Show('Reset ALL learned bag mapping? Session reports stay saved, but My Bag will ignore all shots collected before now.','Reset all My Bag learning',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning);if($ans -eq [System.Windows.MessageBoxResult]::Yes){$st=Load-State;$st.global_reset_before=(Get-Date).ToString('o');$st.club_resets=@();Save-State $st;$StatusText.Text='All learned bag mapping reset. New shots will rebuild My Bag.';Refresh-UI}})
$CloseButton.Add_Click({$w.Close()});Refresh-UI;try{$screen=Resolve-FGScreen -Config $config -KeyProperty 'PerformanceDisplayKey' -IndexProperty 'PerformanceScreenIndex';$b=$screen.WorkingArea;$w.Left=$b.Left+($b.Width-$w.Width)/2;$w.Top=$b.Top+($b.Height-$w.Height)/2}catch{};$w.ShowDialog()|Out-Null
