param([Parameter(Mandatory=$true)][string]$AppDir)
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'FactorGolf_Display_Helper.ps1')
$configPath=Join-Path $AppDir 'config.json';$defaultPath=Join-Path $AppDir 'config.default.json'
$config=if(Test-Path $configPath){Get-Content $configPath -Raw|ConvertFrom-Json}else{Get-Content $defaultPath -Raw|ConvertFrom-Json}
function Ensure([string]$name,$value){if(-not($config.PSObject.Properties.Name -contains $name)){$config|Add-Member -NotePropertyName $name -NotePropertyValue $value}}
Ensure 'Fairgrounds' '';Ensure 'StartWithWindows' $true;Ensure 'TTSVoice' 'marin';Ensure 'CoachPersona' 'Golf Buddy';Ensure 'CoachingLevel' 'Rookie';Ensure 'PlayerName' '';Ensure 'VoiceSilenceSeconds' 15;Ensure 'VoiceRecognitionMinConfidence' 0.48;Ensure 'BagMappingHalfLifeDays' 45;Ensure 'ControlCenterScreenIndex' 0;Ensure 'SettingsScreenIndex' 0;Ensure 'PerformanceScreenIndex' 0;Ensure 'GSProScreenIndex' -1;Ensure 'ClubCheatSheetScreenIndex' 0;Ensure 'CoachCardScreenIndex' 0;Ensure 'RangeNavCalibrated' $false;Ensure 'RangeNavCalibrationDate' '';Ensure 'ControlCenterDisplayKey' '';Ensure 'SettingsDisplayKey' '';Ensure 'PerformanceDisplayKey' '';Ensure 'GSProDisplayKey' 'AUTO';Ensure 'ClubCheatSheetDisplayKey' '';Ensure 'CoachCardDisplayKey' '';Ensure 'ClubSelectorCalibrated' $false;Ensure 'ClubSelectorX' 0.0;Ensure 'ClubSelectorY' 0.0;Ensure 'ClubSelectorCalibrationDate' '';Ensure 'ClubSelectorCropWidthRatio' 0.28;Ensure 'ClubSelectorCropHeightRatio' 0.16
if(@('marin','cedar') -notcontains [string]$config.TTSVoice){$config.TTSVoice='marin'}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Factor Golf Sim Control Center - Settings" Width="1000" Height="820"
        WindowStartupLocation="Manual"
        Background="#07100C" Foreground="#FFFFFF">
 <Window.Resources>
  <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#FFFFFF"/></Style>
  <Style TargetType="CheckBox">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="FontSize" Value="16"/><Setter Property="Margin" Value="0,7"/><Setter Property="VerticalContentAlignment" Value="Center"/>
  </Style>
  <Style x:Key="HCButton" TargetType="Button">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#173A2A"/>
   <Setter Property="BorderBrush" Value="#63B98A"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontSize" Value="14"/><Setter Property="Padding" Value="10,5"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#22513B"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#10291E"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Background" Value="#26342D"/><Setter TargetName="B" Property="BorderBrush" Value="#60766A"/><Setter Property="Foreground" Value="#E9F2ED"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="Button" BasedOn="{StaticResource HCButton}"/>
  <Style TargetType="ComboBox">
   <Setter Property="Foreground" Value="#E6C65B"/>
   <Setter Property="Background" Value="#0D1D15"/>
   <Setter Property="BorderBrush" Value="#63B98A"/>
   <Setter Property="BorderThickness" Value="2"/>
   <Setter Property="FontSize" Value="15"/>
   <Setter Property="Padding" Value="8,3"/>
   <Setter Property="MinHeight" Value="38"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ComboBox">
      <Grid>
       <ToggleButton x:Name="ToggleButton" Focusable="False" ClickMode="Press"
                     Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                     BorderThickness="{TemplateBinding BorderThickness}"
                     IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
        <ToggleButton.Template>
         <ControlTemplate TargetType="ToggleButton">
          <Border x:Name="TB" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
           <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
            <ContentPresenter Grid.Column="0" Margin="9,0,4,0" VerticalAlignment="Center" HorizontalAlignment="Left"
                              RecognizesAccessKey="True"
                              Content="{Binding SelectionBoxItem, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                              ContentTemplate="{Binding SelectionBoxItemTemplate, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                              ContentStringFormat="{Binding SelectionBoxItemStringFormat, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                              TextElement.Foreground="{Binding Foreground, RelativeSource={RelativeSource AncestorType=ComboBox}}"/>
            <Path Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center"
                  Data="M 0 0 L 5 5 L 10 0 Z" Fill="#D7E5DD"/>
           </Grid>
          </Border>
          <ControlTemplate.Triggers>
           <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="TB" Property="BorderBrush" Value="#E6C65B"/></Trigger>
           <Trigger Property="IsChecked" Value="True"><Setter TargetName="TB" Property="BorderBrush" Value="#E6C65B"/></Trigger>
          </ControlTemplate.Triggers>
         </ControlTemplate>
        </ToggleButton.Template>
       </ToggleButton>
       <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True" IsOpen="{TemplateBinding IsDropDownOpen}" Focusable="False" PopupAnimation="Fade">
        <Border Background="#0D1D15" BorderBrush="#63B98A" BorderThickness="2" CornerRadius="4"
                MinWidth="{TemplateBinding ActualWidth}" MaxHeight="340">
         <ScrollViewer VerticalScrollBarVisibility="Auto" CanContentScroll="True"><ItemsPresenter/></ScrollViewer>
        </Border>
       </Popup>
      </Grid>
      <ControlTemplate.Triggers>
       <Trigger Property="IsEnabled" Value="False"><Setter Property="Foreground" Value="#A8B8AF"/><Setter Property="Background" Value="#17231D"/><Setter Property="BorderBrush" Value="#4A5C52"/></Trigger>
      </ControlTemplate.Triggers>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
  <Style TargetType="ComboBoxItem">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#0D1D15"/>
   <Setter Property="FontSize" Value="15"/><Setter Property="Padding" Value="9,7"/>
   <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ComboBoxItem">
      <Border x:Name="ItemBorder" Background="#0D1D15" BorderBrush="Transparent" BorderThickness="1" Padding="{TemplateBinding Padding}">
       <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
      </Border>
      <ControlTemplate.Triggers>
       <Trigger Property="IsHighlighted" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter TargetName="ItemBorder" Property="BorderBrush" Value="#5D6B3A"/></Trigger>
       <Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#E6C65B"/><Setter Property="FontWeight" Value="SemiBold"/><Setter TargetName="ItemBorder" Property="BorderBrush" Value="#E6C65B"/></Trigger>
       <Trigger Property="IsEnabled" Value="False"><Setter Property="Foreground" Value="#93A39A"/></Trigger>
      </ControlTemplate.Triggers>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
  <Style TargetType="TextBox">
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#0B1711"/>
   <Setter Property="CaretBrush" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#63B98A"/>
   <Setter Property="BorderThickness" Value="2"/><Setter Property="FontSize" Value="14"/><Setter Property="Padding" Value="7,5"/>
  </Style>
  <Style x:Key="Exp" TargetType="Expander">
   <Setter Property="Margin" Value="0,0,0,12"/><Setter Property="Background" Value="#0D1C15"/>
   <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="FontSize" Value="16"/><Setter Property="FontWeight" Value="SemiBold"/>
   <Setter Property="HeaderTemplate"><Setter.Value><DataTemplate><Border Background="#173A2A" BorderBrush="#4C8D68" BorderThickness="1" CornerRadius="7" Padding="12,9"><TextBlock Text="{Binding}" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold"/></Border></DataTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>

 <Grid Margin="26">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel>
   <TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontWeight="Bold" FontSize="15"/>
   <TextBlock Text="SIM CONTROL CENTER SETTINGS" Foreground="#FFFFFF" FontSize="34" FontWeight="Bold"/>
   <TextBlock Text="Primary modes stay simple. Secondary controls live here." Foreground="#E8F2EC" FontSize="15" Margin="0,5,0,16"/>
  </StackPanel>

  <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
   <StackPanel>
    <Expander x:Name="VoiceExp" Header="GOLFER EXPERIENCE, VOICE &amp; COACH PERSONA" IsExpanded="True" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <TextBlock Text="What should the coach call you?" Foreground="#FFFFFF" FontSize="15"/>
      <TextBox x:Name="PlayerNameBox" Height="38" Margin="0,5,0,4"/>
      <TextBlock Text="Leave blank if you do not want the coach to use a name or nickname." Foreground="#E3EEE7" FontSize="13" Margin="0,0,0,14"/>

      <TextBlock Text="Golfer Experience" Foreground="#FFFFFF" FontSize="15"/>
      <TextBlock Text="Tell Factor Golf how experienced you are so the coach can match the fundamentals, terminology, explanations, and expectations to your game." Foreground="#D6E4DB" FontSize="13" TextWrapping="Wrap" Margin="0,3,0,2"/>
      <ComboBox x:Name="CoachingLevelCombo" Height="38" Margin="0,5,0,5">
       <ComboBoxItem Content="Rookie" Tag="Rookie"/>
       <ComboBoxItem Content="Amateur" Tag="Amateur"/>
       <ComboBoxItem Content="Pro / Advanced" Tag="Advanced"/>
      </ComboBox>
      <Border Background="#102119" BorderBrush="#335846" BorderThickness="1" Padding="10" Margin="0,0,0,14">
       <TextBlock x:Name="CoachingLevelDescription" TextWrapping="Wrap" Foreground="#F0F7F2" FontSize="14"/>
      </Border>

      <TextBlock Text="Voice" Foreground="#FFFFFF" FontSize="15"/>
      <ComboBox x:Name="VoiceCombo" Height="38" Margin="0,5,0,12">
       <ComboBoxItem Content="Female" Tag="marin"/>
       <ComboBoxItem Content="Male" Tag="cedar"/>
      </ComboBox>

      <TextBlock Text="Persona" Foreground="#FFFFFF" FontSize="15"/>
      <ComboBox x:Name="PersonaCombo" Height="38" Margin="0,5,0,5">
       <ComboBoxItem Content="Professional / Clean  -  PG" Tag="Professional / Clean"/>
       <ComboBoxItem Content="Golf Buddy  -  PG-13" Tag="Golf Buddy"/>
       <ComboBoxItem Content="One of the Boys  -  R" Tag="One of the Boys"/>
       <ComboBoxItem Content="Hood Golf  -  R / Strong Ebonics (AAVE)" Tag="Hood Golf"/>
       <ComboBoxItem Content="Extreme  -  R+ / Drunk Golf Buddy" Tag="Extreme"/>
      </ComboBox>
      <Border Background="#102119" BorderBrush="#335846" BorderThickness="1" Padding="10" Margin="0,0,0,12">
       <TextBlock x:Name="PersonaDescription" TextWrapping="Wrap" Foreground="#F0F7F2" FontSize="14"/>
      </Border>

      <Grid>
       <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
       <Button x:Name="TestVoiceButton" Content="PREVIEW COACH" Width="180" Height="42"/>
       <TextBlock Grid.Column="1" Text="Preview combines Golfer Experience + Persona + Voice so you can hear how this coach will actually teach you."
                  Margin="14,8,0,0" Foreground="#E8F2EC" FontSize="14" TextWrapping="Wrap"/>
      </Grid>

      <TextBlock Text="Follow-up silence timeout" Foreground="#FFFFFF" FontSize="15" Margin="0,14,0,5"/>
      <ComboBox x:Name="SilenceCombo" Height="38">
       <ComboBoxItem Content="10 seconds" Tag="10"/><ComboBoxItem Content="15 seconds" Tag="15"/>
       <ComboBoxItem Content="20 seconds" Tag="20"/><ComboBoxItem Content="30 seconds" Tag="30"/>
      </ComboBox>
     </StackPanel>
    </Expander>

    <Expander Header="CLUB CHEAT SHEET" IsExpanded="False" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <CheckBox x:Name="CheatEnabled" Content="Enable Club Cheat Sheet pop-up"/>
      <TextBlock Text="Club Cheat Sheets stay out of the way at startup and appear only after the selected club changes. Factor Golf watches GSPro's I / K / U shortcuts during Coach Mode so pedal club changes can trigger the sheet before the next shot."
                 Foreground="#D6E4DB" FontSize="13" TextWrapping="Wrap" Margin="0,4,0,10"/>
      <TextBlock Text="Reappear behavior" Foreground="#FFFFFF" FontSize="15" Margin="0,12,0,5"/>
      <ComboBox x:Name="CheatMode" Height="38">
       <ComboBoxItem Content="First time each club is selected in a session" Tag="FirstTimePerClub"/>
       <ComboBoxItem Content="Every time the selected club changes" Tag="EveryChange"/>
      </ComboBox>
      <TextBlock Text="Display time" Foreground="#FFFFFF" FontSize="15" Margin="0,12,0,5"/>
      <ComboBox x:Name="CheatSeconds" Height="38">
       <ComboBoxItem Content="10 seconds" Tag="10"/><ComboBoxItem Content="15 seconds" Tag="15"/>
       <ComboBoxItem Content="20 seconds" Tag="20"/><ComboBoxItem Content="30 seconds" Tag="30"/>
      </ComboBox>
      <Border Background="#102119" BorderBrush="#335846" BorderThickness="1" Padding="12" Margin="0,16,0,0">
       <StackPanel>
        <TextBlock Text="GSPro Club Selector Calibration" FontSize="16" FontWeight="Bold" Foreground="#E6C65B"/>
        <TextBlock Text="One-time setup: with GSPro on the range and the current club selector visible, click Calibrate and then click directly on the club name/selector in GSPro. Factor Golf will OCR only that small area after pedal changes, which is much more reliable than scanning the whole projector screen." Foreground="#F0F7F2" FontSize="13" TextWrapping="Wrap" Margin="0,4,0,10"/>
        <TextBlock x:Name="ClubSelectorCalibrationStatus" Text="Club selector calibration status" Foreground="#E8F2EC" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <StackPanel Orientation="Horizontal">
         <Button x:Name="CalibrateClubSelectorButton" Content="CALIBRATE CLUB SELECTOR" Width="225" Height="42" Margin="0,0,10,0"/>
         <Button x:Name="TestClubDetectionButton" Content="TEST CLUB DETECTION" Width="205" Height="42"/>
        </StackPanel>
       </StackPanel>
      </Border>
     </StackPanel>
    </Expander>

    <Expander Header="COACH MODE BEHAVIOR" IsExpanded="False" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <CheckBox x:Name="AutoRange" Content="Automatically navigate to the GSPro Driving Range in Coach Mode"/>
      <CheckBox x:Name="WindowedCoach" Content="Use a closable windowed coaching overlay"/>
      <CheckBox x:Name="MinConnector" Content="Minimize the Foresight / Bushnell connector after launch"/>
      <TextBlock Text="Coach Mode now records GSPro range-navigation and connector-window diagnostics automatically when startup automation needs help."
                 Foreground="#D6E4DB" FontSize="13" TextWrapping="Wrap" Margin="0,8,0,0"/>
     </StackPanel>
    </Expander>

    <Expander Header="DISPLAY &amp; SCREEN ROUTING" IsExpanded="False" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <TextBlock Text="Choose each real monitor by its detected hardware name. Factor Golf reads the monitor identity from Windows/EDID when available. The Primary tag means Windows currently considers that monitor the main display. Low-level DISPLAY1 / DISPLAY2 / DISPLAY3 identifiers are kept in diagnostics instead of shown here." Foreground="#E8F2EC" FontSize="14" TextWrapping="Wrap" Margin="0,0,0,8"/>
      <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
       <Button x:Name="IdentifyDisplaysButton" Content="IDENTIFY DISPLAYS" Width="180" Height="38" Margin="0,0,12,0"/>
       <TextBlock Text="Shows the detected monitor name on each physical screen for five seconds." Foreground="#D6E4DB" FontSize="13" VerticalAlignment="Center" TextWrapping="Wrap"/>
      </StackPanel>
      <Grid>
       <Grid.ColumnDefinitions><ColumnDefinition Width="230"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
       <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
       <TextBlock Text="Control Center / Home" VerticalAlignment="Center"/><ComboBox x:Name="ControlCenterScreen" Grid.Column="1" Margin="8,4"/>
       <TextBlock Grid.Row="1" Text="Settings windows" VerticalAlignment="Center"/><ComboBox x:Name="SettingsScreen" Grid.Row="1" Grid.Column="1" Margin="8,4"/>
       <TextBlock Grid.Row="2" Text="Performance windows" VerticalAlignment="Center"/><ComboBox x:Name="PerformanceScreen" Grid.Row="2" Grid.Column="1" Margin="8,4"/>
       <TextBlock Grid.Row="3" Text="GSPro" VerticalAlignment="Center"/><ComboBox x:Name="GSProScreen" Grid.Row="3" Grid.Column="1" Margin="8,4"/>
       <TextBlock Grid.Row="4" Text="Club Cheat Sheets" VerticalAlignment="Center"/><ComboBox x:Name="CheatSheetScreen" Grid.Row="4" Grid.Column="1" Margin="8,4"/>
       <TextBlock Grid.Row="5" Text="Coach feedback cards" VerticalAlignment="Center"/><ComboBox x:Name="CoachCardScreen" Grid.Row="5" Grid.Column="1" Margin="8,4"/>
      </Grid>
      <TextBlock Text="GSPro: leave this on AUTO (Recommended) for normal use. Factor Golf follows the monitor where the live GSPro window is actually open. If you choose a specific monitor, Factor Golf will move GSPro to that monitor when it launches/focuses GSPro as an explicit override." Foreground="#D6E4DB" FontSize="13" TextWrapping="Wrap" Margin="8,6,0,0"/>
      <Border Background="#102119" BorderBrush="#335846" BorderThickness="1" Padding="12" Margin="0,14,0,0">
       <StackPanel>
        <TextBlock Text="GSPro Range Calibration" FontSize="16" FontWeight="Bold" Foreground="#E6C65B"/>
        <TextBlock Text="For multi-monitor setups, Factor Golf stores the Practice and GS Pro Practice Range clicks relative to the actual GSPro window, not the whole Windows desktop. This works even when GSPro lives on one display and Factor Golf lives on a different touchscreen or monitor." Foreground="#F0F7F2" FontSize="13" TextWrapping="Wrap" Margin="0,4,0,10"/>
        <TextBlock x:Name="RangeCalibrationStatus" Text="Range calibration status" Foreground="#E8F2EC" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <StackPanel Orientation="Horizontal">
         <Button x:Name="CalibrateRangeButton" Content="CALIBRATE GSPRO RANGE" Width="220" Height="42" Margin="0,0,10,0"/>
         <Button x:Name="TestRangeButton" Content="TEST RANGE NAVIGATION" Width="210" Height="42"/>
        </StackPanel>
       </StackPanel>
      </Border>
     </StackPanel>
    </Expander>

    <Expander Header="STARTUP &amp; SHELL" IsExpanded="False" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <CheckBox x:Name="StartWindows" Content="Start Factor Golf Sim Control Center automatically with Windows"/>
      <TextBlock Text="Factor Golf Sim Control Center always opens to the home screen. Windows stays underneath as the recovery and admin layer."
                 Foreground="#E8F2EC" FontSize="14" TextWrapping="Wrap" Margin="0,8,0,0"/>
     </StackPanel>
    </Expander>

    <Expander Header="APP PATHS" IsExpanded="False" Style="{StaticResource Exp}">
     <Grid Margin="18,12,18,18">
      <Grid.ColumnDefinitions><ColumnDefinition Width="155"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
       <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
       <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Text="GSPro" Foreground="#FFFFFF" VerticalAlignment="Center"/><TextBox x:Name="GSProPath" Grid.Column="1" Margin="8,4"/>
      <TextBlock Grid.Row="1" Text="SwingNerds" Foreground="#FFFFFF" VerticalAlignment="Center"/><TextBox x:Name="SNPath" Grid.Row="1" Grid.Column="1" Margin="8,4"/>
      <TextBlock Grid.Row="2" Text="Connector" Foreground="#FFFFFF" VerticalAlignment="Center"/><TextBox x:Name="ConnectorPath" Grid.Row="2" Grid.Column="1" Margin="8,4"/>
      <TextBlock Grid.Row="3" Text="FSX Play" Foreground="#FFFFFF" VerticalAlignment="Center"/><TextBox x:Name="FSXPlayPath" Grid.Row="3" Grid.Column="1" Margin="8,4"/>
      <TextBlock Grid.Row="4" Text="FSX Pro / Premier" Foreground="#FFFFFF" VerticalAlignment="Center"/>
      <StackPanel Grid.Row="4" Grid.Column="1"><TextBox x:Name="FSXProPath" Margin="8,4"/><TextBox x:Name="FSXPremierPath" Margin="8,4"/></StackPanel>
      <TextBlock Grid.Row="5" Text="Fairgrounds" Foreground="#FFFFFF" VerticalAlignment="Center"/><TextBox x:Name="FairgroundsPath" Grid.Row="5" Grid.Column="1" Margin="8,4"/>
     </Grid>
    </Expander>

    <Expander Header="MY BAG LEARNING" IsExpanded="False" Style="{StaticResource Exp}">
     <StackPanel Margin="18,12,18,18">
      <TextBlock Text="Older practice data fades gradually instead of disappearing overnight. Half-life controls how quickly newer practice has more influence."
                 Foreground="#E8F2EC" FontSize="14" TextWrapping="Wrap"/>
      <TextBlock Text="Recency half-life" Foreground="#FFFFFF" FontSize="15" Margin="0,12,0,5"/>
      <ComboBox x:Name="HalfLifeCombo" Height="38">
       <ComboBoxItem Content="30 days - adapts faster" Tag="30"/>
       <ComboBoxItem Content="45 days - balanced" Tag="45"/>
       <ComboBoxItem Content="60 days - steadier" Tag="60"/>
       <ComboBoxItem Content="90 days - very stable" Tag="90"/>
      </ComboBox>
     </StackPanel>
    </Expander>
   </StackPanel>
  </ScrollViewer>

  <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
   <Button x:Name="CancelButton" Content="CANCEL" Width="110" Height="44" Margin="0,0,10,0"/>
   <Button x:Name="SaveButton" Content="SAVE SETTINGS" Width="155" Height="44"
           Background="#2D7A53" BorderBrush="#72D29B" Foreground="#FFFFFF" FontWeight="Bold"/>
  </StackPanel>
 </Grid>
</Window>
'@
$r=New-Object System.Xml.XmlNodeReader $xaml;$w=[Windows.Markup.XamlReader]::Load($r);foreach($n in @('PlayerNameBox','CoachingLevelCombo','CoachingLevelDescription','VoiceCombo','PersonaCombo','PersonaDescription','TestVoiceButton','SilenceCombo','CheatEnabled','CheatMode','CheatSeconds','AutoRange','WindowedCoach','MinConnector','StartWindows','GSProPath','SNPath','ConnectorPath','FSXPlayPath','FSXProPath','FSXPremierPath','FairgroundsPath','HalfLifeCombo','IdentifyDisplaysButton','ControlCenterScreen','SettingsScreen','PerformanceScreen','GSProScreen','CheatSheetScreen','CoachCardScreen','RangeCalibrationStatus','CalibrateRangeButton','TestRangeButton','ClubSelectorCalibrationStatus','CalibrateClubSelectorButton','TestClubDetectionButton','CancelButton','SaveButton')){Set-Variable -Scope Script -Name $n -Value $w.FindName($n)}
$script:DisplayCatalog=@(Get-FGMonitorCatalog)
function Populate-ScreenCombo($combo,[string]$selectedKey,[int]$legacyIndex,[bool]$allowAuto=$false){
 $combo.Items.Clear()
 if($allowAuto){$a=New-Object System.Windows.Controls.ComboBoxItem;$a.Content='AUTO (Recommended) - follow the monitor where GSPro is open';$a.Tag='AUTO';$combo.Items.Add($a)|Out-Null}
 foreach($m in $script:DisplayCatalog){$it=New-Object System.Windows.Controls.ComboBoxItem;$it.Content=[string]$m.Label;$it.Tag=[string]$m.StableKey;$combo.Items.Add($it)|Out-Null}
 if($allowAuto -and (-not$selectedKey -or $selectedKey -eq 'AUTO')){$combo.SelectedIndex=0;return}
 if($selectedKey){foreach($it in $combo.Items){if([string]$it.Tag -eq $selectedKey){$combo.SelectedItem=$it;return}}}
 if($legacyIndex -ge 0 -and $legacyIndex -lt $script:DisplayCatalog.Count){$legacyKey=[string]$script:DisplayCatalog[$legacyIndex].StableKey;foreach($it in $combo.Items){if([string]$it.Tag -eq $legacyKey){$combo.SelectedItem=$it;return}}}
 $combo.SelectedIndex=0
}
function Save-ScreenChoice($combo,[string]$keyProp,[string]$indexProp,[bool]$allowAuto=$false){
 $key=[string]$combo.SelectedItem.Tag
 if($allowAuto -and $key -eq 'AUTO'){$config.$keyProp='AUTO';$config.$indexProp=-1;return}
 $m=$script:DisplayCatalog|Where-Object{$_.StableKey -eq $key}|Select-Object -First 1
 if($m){$config.$keyProp=[string]$m.StableKey;$config.$indexProp=[int]$m.Index}
}

function Select-Tag($combo,[string]$tag){foreach($i in $combo.Items){if([string]$i.Tag -eq $tag){$combo.SelectedItem=$i;return}};$combo.SelectedIndex=0}
Select-Tag $VoiceCombo ([string]$config.TTSVoice);Select-Tag $PersonaCombo ([string]$config.CoachPersona);Select-Tag $CoachingLevelCombo ([string]$config.CoachingLevel);$PlayerNameBox.Text=[string]$config.PlayerName;Select-Tag $SilenceCombo ([string][int]$config.VoiceSilenceSeconds);Select-Tag $CheatMode ([string]$config.ClubCheatSheetShowMode);Select-Tag $CheatSeconds ([string][int]$config.ClubCheatSheetDisplaySeconds);Select-Tag $HalfLifeCombo ([string][int]$config.BagMappingHalfLifeDays)
Populate-ScreenCombo $ControlCenterScreen ([string]$config.ControlCenterDisplayKey) ([int]$config.ControlCenterScreenIndex);Populate-ScreenCombo $SettingsScreen ([string]$config.SettingsDisplayKey) ([int]$config.SettingsScreenIndex);Populate-ScreenCombo $PerformanceScreen ([string]$config.PerformanceDisplayKey) ([int]$config.PerformanceScreenIndex);Populate-ScreenCombo $GSProScreen ([string]$config.GSProDisplayKey) ([int]$config.GSProScreenIndex) $true;Populate-ScreenCombo $CheatSheetScreen ([string]$config.ClubCheatSheetDisplayKey) ([int]$config.ClubCheatSheetScreenIndex);Populate-ScreenCombo $CoachCardScreen ([string]$config.CoachCardDisplayKey) ([int]$config.CoachCardScreenIndex)
$CheatEnabled.IsChecked=[bool]$config.ClubCheatSheetEnabled;$AutoRange.IsChecked=[bool]$config.AutoOpenDrivingRange;$WindowedCoach.IsChecked=[bool]$config.CoachCardWindowedOverlay;$MinConnector.IsChecked=[bool]$config.MinimizeForesightConnector;$StartWindows.IsChecked=[bool]$config.StartWithWindows
$GSProPath.Text=[string]$config.GSPro;$SNPath.Text=[string]$config.SwingNerds;$ConnectorPath.Text=[string]$config.ForesightConnector;$FSXPlayPath.Text=[string]$config.FSXPlay;$FSXProPath.Text=[string]$config.FSXPro;$FSXPremierPath.Text=[string]$config.FSXPremier;$FairgroundsPath.Text=[string]$config.Fairgrounds
function Update-CoachingLevelDescription{
 $CoachingLevelDescription.Text=switch([string]$CoachingLevelCombo.SelectedItem.Tag){
  'Amateur'{'Assumes the golfer already knows the basic setup and swing fundamentals. Coaches consistency, strike and ball-flight cause/effect with normal golf terminology, while still keeping one clear priority.'}
  'Advanced'{'Pro / Advanced: assumes strong fundamentals and golf knowledge. Skips basic instruction unless the evidence points to a setup/fundamental breakdown, and focuses on precise delivery, pattern, dispersion and optimization.'}
  default{'Rookie: teaches the fundamentals as needed. Uses plain English, explains why setup and swing basics matter, defines golf terms, gives one main correction at a time, and uses simple feels with beginner-friendly expectations.'}
 }
}
Update-CoachingLevelDescription
$CoachingLevelCombo.Add_SelectionChanged({Update-CoachingLevelDescription})

function Update-PersonaDescription{
 $PersonaDescription.Text=switch([string]$PersonaCombo.SelectedItem.Tag){
  'Professional / Clean'{'PG - Polished PGA-style coach. Encouraging and direct, with no profanity and little or no sarcasm.'}
  'One of the Boys'{'R - Most casual option. Stronger language, more trash talk and sarcasm when it fits, while the coaching stays useful and respectful.'}
  'Hood Golf'{'R - Same useful golf-buddy coaching foundation as One of the Boys, delivered with strong AAVE-style phrasing, rhythm and slang. Keep it natural and readable, never a caricature, and never use racial slurs or stereotypes.'}
  'Extreme'{'R+ - Drunk-golf-buddy energy. Very vulgar, rowdy and sarcastic, with ridiculous real-world analogies tied back to the swing and at least one corny dad joke in the coaching conversation. The golf diagnosis still stays accurate and useful.'}
  default{'PG-13 - Relaxed golf buddy. Conversational, light sarcasm and humor, with occasional mild profanity when it fits.'}
 }
}
Update-PersonaDescription
$PersonaCombo.Add_SelectionChanged({Update-PersonaDescription})
$TestVoiceButton.Add_Click({
 $voice=[string]$VoiceCombo.SelectedItem.Tag;$persona=[string]$PersonaCombo.SelectedItem.Tag;$coachingLevel=[string]$CoachingLevelCombo.SelectedItem.Tag;$playerName=$PlayerNameBox.Text.Trim();$script=Join-Path $AppDir 'workers\Halliseum_Voice_Test.ps1'
 Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -AppDir `"$AppDir`" -Voice `"$voice`" -Persona `"$persona`" -CoachingLevel `"$coachingLevel`" -PlayerName `"$playerName`"" -WindowStyle Hidden|Out-Null
})
$IdentifyDisplaysButton.Add_Click({Show-FGDisplayIdentify -Seconds 5})
$stateRoot=[Environment]::ExpandEnvironmentVariables([string]$config.GoogleDriveRoot);if(-not$stateRoot){$stateRoot='G:\My Drive\Halliseum Coach Bridge'};$calStatusPath=Join-Path $stateRoot 'UltimateCoach\range_calibration_status.json';$clubCalStatusPath=Join-Path $AppDir 'club_selector_calibration_status.json';$legacyClubCalStatusPath=Join-Path $stateRoot 'UltimateCoach\club_selector_calibration_status.json';$clubDetectStatusPath=Join-Path $stateRoot 'UltimateCoach\club_cheat_status.json'
function Update-RangeCalibrationStatus{
 try{if(Test-Path $calStatusPath){$cs=Get-Content $calStatusPath -Raw|ConvertFrom-Json;$RangeCalibrationStatus.Text=[string]$cs.message;return}}catch{}
 if([bool]$config.RangeNavCalibrated){$RangeCalibrationStatus.Text='Calibrated. Coach Mode will use your saved GSPro-relative Practice and Practice Range positions.'}else{$RangeCalibrationStatus.Text='Not calibrated yet. Calibration is recommended for multi-monitor setups.'}
}
Update-RangeCalibrationStatus
function Update-ClubSelectorCalibrationStatus{
 try{if(Test-Path $clubCalStatusPath){$cs=Get-Content $clubCalStatusPath -Raw|ConvertFrom-Json;$ClubSelectorCalibrationStatus.Text=[string]$cs.message;return}}catch{}
 try{if(Test-Path $legacyClubCalStatusPath){$cs=Get-Content $legacyClubCalStatusPath -Raw|ConvertFrom-Json;$ClubSelectorCalibrationStatus.Text=[string]$cs.message;return}}catch{}
 try{if(Test-Path $clubDetectStatusPath){$ds=Get-Content $clubDetectStatusPath -Raw|ConvertFrom-Json;if([string]$ds.state -like 'club_detection_test*'){$ClubSelectorCalibrationStatus.Text=[string]$ds.message;return}}}catch{}
 if([bool]$config.ClubSelectorCalibrated){$ClubSelectorCalibrationStatus.Text='Calibrated. Factor Golf will focus OCR around the saved GSPro club selector.'}else{$ClubSelectorCalibrationStatus.Text='Not calibrated. Click CALIBRATE CLUB SELECTOR, then click the club selector in GSPro.'}
}
Update-ClubSelectorCalibrationStatus
$calTimer=New-Object System.Windows.Threading.DispatcherTimer;$calTimer.Interval=[TimeSpan]::FromMilliseconds(600);$calTimer.Add_Tick({Update-RangeCalibrationStatus;Update-ClubSelectorCalibrationStatus});$calTimer.Start()
$CalibrateRangeButton.Add_Click({
 $gp=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1
 if(-not$gp){[System.Windows.MessageBox]::Show('Open GSPro to its MAIN screen first, then run calibration again.','Factor Golf Range Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null;return}
 $msg='Calibration will record your NEXT TWO left-clicks inside the GSPro window. After you click OK here, click PRACTICE in GSPro, then click GS PRO PRACTICE RANGE. Those normal clicks will also navigate GSPro, and Factor Golf will save their positions relative to the GSPro window.'
 [System.Windows.MessageBox]::Show($msg,'Factor Golf Range Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null
 Remove-Item $calStatusPath -Force -ErrorAction SilentlyContinue
 $script=Join-Path $AppDir 'workers\Halliseum_Range_Calibration.ps1';Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Root `"$stateRoot`" -AppDir `"$AppDir`"" -WindowStyle Hidden|Out-Null
})
$TestRangeButton.Add_Click({
 $gp=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1;if(-not$gp){[System.Windows.MessageBox]::Show('Open GSPro to its main screen before testing range navigation.','Factor Golf')|Out-Null;return}
 $script=Join-Path $AppDir 'workers\Halliseum_Range_Nav.ps1';Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Root `"$stateRoot`" -AppDir `"$AppDir`"" -WindowStyle Hidden|Out-Null
})
$CalibrateClubSelectorButton.Add_Click({
 $gp=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1
 if(-not$gp){[System.Windows.MessageBox]::Show('Open GSPro to the PRACTICE RANGE first, with the club selector visible.','Factor Golf Club Selector Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null;return}
 Remove-Item $clubCalStatusPath -Force -ErrorAction SilentlyContinue
 Remove-Item $legacyClubCalStatusPath -Force -ErrorAction SilentlyContinue
 try{[ordered]@{state='launching';message='Calibration is starting. Factor Golf will bring GSPro forward. Click directly on the current club name/selector when prompted.';updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $clubCalStatusPath -Encoding UTF8}catch{}
 $ClubSelectorCalibrationStatus.Text='Calibration is starting. Watch for the Factor Golf calibration prompt.'
 try{
  $script=Join-Path $AppDir 'workers\Halliseum_Club_Selector_Calibration.ps1'
  if(-not(Test-Path $script)){throw 'Calibration worker is missing: '+$script}
  $proc=Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Root `"$stateRoot`" -AppDir `"$AppDir`"" -WindowStyle Hidden -PassThru
  Start-Sleep -Milliseconds 450
  if($proc.HasExited -and $proc.ExitCode -ne 0){throw ('Calibration worker exited immediately with code '+$proc.ExitCode)}
  $ClubSelectorCalibrationStatus.Text='Calibration armed. Factor Golf is bringing GSPro forward. Click the current club name/selector in GSPro.'
 }catch{
  $msg='Club Selector calibration could not start: '+$_.Exception.Message
  try{[ordered]@{state='launch_failed';message=$msg;updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $clubCalStatusPath -Encoding UTF8}catch{}
  [System.Windows.MessageBox]::Show($msg,'Factor Golf Club Selector Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)|Out-Null
 }
})
$TestClubDetectionButton.Add_Click({
 $gp=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1;if(-not$gp){[System.Windows.MessageBox]::Show('Open GSPro on the Practice Range with the club selector visible before testing club detection.','Factor Golf')|Out-Null;return}
 Remove-Item $clubDetectStatusPath -Force -ErrorAction SilentlyContinue
 $script=Join-Path $AppDir 'workers\Halliseum_Club_Cheat_Watcher.ps1';Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Root `"$stateRoot`" -AppDir `"$AppDir`" -TestOnce" -WindowStyle Hidden|Out-Null
})
$w.Add_Closed({try{$calTimer.Stop()}catch{}})
$CancelButton.Add_Click({$w.Close()})
$SaveButton.Add_Click({
 Save-ScreenChoice $ControlCenterScreen 'ControlCenterDisplayKey' 'ControlCenterScreenIndex';Save-ScreenChoice $SettingsScreen 'SettingsDisplayKey' 'SettingsScreenIndex';Save-ScreenChoice $PerformanceScreen 'PerformanceDisplayKey' 'PerformanceScreenIndex';Save-ScreenChoice $GSProScreen 'GSProDisplayKey' 'GSProScreenIndex' $true;Save-ScreenChoice $CheatSheetScreen 'ClubCheatSheetDisplayKey' 'ClubCheatSheetScreenIndex';Save-ScreenChoice $CoachCardScreen 'CoachCardDisplayKey' 'CoachCardScreenIndex';$config.PlayerName=$PlayerNameBox.Text.Trim();$config.TTSVoice=[string]$VoiceCombo.SelectedItem.Tag;$config.CoachPersona=[string]$PersonaCombo.SelectedItem.Tag;$config.CoachingLevel=[string]$CoachingLevelCombo.SelectedItem.Tag;$config.VoiceSilenceSeconds=[int]$SilenceCombo.SelectedItem.Tag;$config.ClubCheatSheetEnabled=[bool]$CheatEnabled.IsChecked;$config.ClubCheatSheetShowMode=[string]$CheatMode.SelectedItem.Tag;$config.ClubCheatSheetDisplaySeconds=[int]$CheatSeconds.SelectedItem.Tag;$config.AutoOpenDrivingRange=[bool]$AutoRange.IsChecked;$config.CoachCardWindowedOverlay=[bool]$WindowedCoach.IsChecked;$config.MinimizeForesightConnector=[bool]$MinConnector.IsChecked;$config.StartWithWindows=[bool]$StartWindows.IsChecked;$config.GSPro=$GSProPath.Text.Trim();$config.SwingNerds=$SNPath.Text.Trim();$config.ForesightConnector=$ConnectorPath.Text.Trim();$config.FSXPlay=$FSXPlayPath.Text.Trim();$config.FSXPro=$FSXProPath.Text.Trim();$config.FSXPremier=$FSXPremierPath.Text.Trim();$config.Fairgrounds=$FairgroundsPath.Text.Trim();$config.BagMappingHalfLifeDays=[int]$HalfLifeCombo.SelectedItem.Tag
 # Calibration runs in a separate process and can update config.json while Settings is still open.
 # Preserve the newest saved calibration values before writing the rest of the Settings form back to disk.
 try{if(Test-Path $configPath){$diskCfg=Get-Content $configPath -Raw|ConvertFrom-Json;foreach($name in @('RangeNavHomePracticeX','RangeNavHomePracticeY','RangeNavPracticeRangeX','RangeNavPracticeRangeY','RangeNavCalibrated','RangeNavCalibrationDate','ClubSelectorX','ClubSelectorY','ClubSelectorCalibrated','ClubSelectorCalibrationDate','ClubSelectorCropWidthRatio','ClubSelectorCropHeightRatio')){if($diskCfg.PSObject.Properties.Name -contains $name){$config.$name=$diskCfg.$name}}}}catch{}
 $config.VoiceStyle=switch([string]$config.CoachPersona){'Professional / Clean'{'Calm, polished PGA coach. Natural, clear and concise. No profanity. Minimal sarcasm. Never robotic or announcer-like.'};'One of the Boys'{'Very casual golf buddy and PGA coach. Confident, conversational and playful. Stronger language, trash talk and sarcasm may be used when it fits, but never at the expense of useful or respectful coaching. Never robotic or announcer-like.'};'Hood Golf'{'Very casual golf buddy and PGA coach using strong, natural AAVE-style phrasing, rhythm and slang. Sound confident, playful and direct, with profanity and trash talk when they fit. Never imitate a racial stereotype, never use slurs, and keep every golf explanation clear and accurate.'};'Extreme'{'Rowdy, vulgar golf buddy and PGA coach with drunk-golf-buddy energy. Heavy profanity, sarcastic delivery, ridiculous real-world analogies and corny dad-joke timing. Stay clear and intelligible, not slurred or actually intoxicated. Keep the golf coaching accurate and useful.'};default{'Relaxed PGA coach and golf buddy. Warm, natural and conversational. Light sarcasm and humor, with occasional mild profanity when it fits. Never robotic or announcer-like.'}}
 $config|ConvertTo-Json -Depth 8|Set-Content $configPath -Encoding UTF8
 # Keep the Startup shortcut synchronized with the toggle.
 try{$ws=New-Object -ComObject WScript.Shell;$startup=[Environment]::GetFolderPath('Startup');$oldLnk=Join-Path $startup 'Halliseum Control Center.lnk';$lnk=Join-Path $startup 'Factor Golf Sim Control Center.lnk';if([bool]$config.StartWithWindows){$s=$ws.CreateShortcut($lnk);$s.TargetPath=$env:WINDIR+'\System32\wscript.exe';$s.Arguments='"'+(Join-Path $AppDir 'Halliseum_Control_Center.vbs')+'"';$s.WorkingDirectory=$AppDir;$s.Description='Factor Golf Sim Control Center';$ico=Join-Path $AppDir 'assets\Halliseum.ico';if(Test-Path $ico){$s.IconLocation=$ico};$s.Save();if(Test-Path $oldLnk){Remove-Item $oldLnk -Force}}else{if(Test-Path $lnk){Remove-Item $lnk -Force};if(Test-Path $oldLnk){Remove-Item $oldLnk -Force}}}catch{}
 $w.Close()
})
try{$screen=Resolve-FGScreen -Config $config -KeyProperty 'SettingsDisplayKey' -IndexProperty 'SettingsScreenIndex';$b=$screen.WorkingArea;$w.Left=$b.Left+($b.Width-$w.Width)/2;$w.Top=$b.Top+($b.Height-$w.Height)/2}catch{}
$w.ShowDialog()|Out-Null
