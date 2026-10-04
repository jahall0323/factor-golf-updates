$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SecretDir = Join-Path $AppDir "secrets"
$SecretFile = Join-Path $SecretDir "openai_api_key.dpapi"
New-Item -ItemType Directory -Path $SecretDir -Force | Out-Null

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Factor Golf - OpenAI API Key"
        Width="650" Height="410" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#07100C" Foreground="White" Topmost="True">
  <Window.Resources>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="#1C6B49"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="18,11"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="{TemplateBinding Background}" CornerRadius="10">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#23885C"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#155339"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Background" Value="#26342D"/><Setter Property="Foreground" Value="#E9F2ED"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
      <Setter Property="Background" Value="#14251D"/>
    </Style>
  </Window.Resources>
  <Grid Margin="28">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0">
      <TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontSize="14" FontWeight="Bold"/>
      <TextBlock Text="Connect OpenAI Coach" FontSize="28" FontWeight="Bold" Margin="0,5,0,0"/>
      <TextBlock Text="Paste the API key once. Factor Golf encrypts it for this Windows user with DPAPI and never saves it to Google Drive." Foreground="#D7E5DD" FontSize="13" TextWrapping="Wrap" Margin="0,8,0,0"/>
    </StackPanel>

    <Border Grid.Row="1" Background="#0F1D16" BorderBrush="#1D3529" BorderThickness="1" CornerRadius="14" Padding="16" Margin="0,22,0,0">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <PasswordBox x:Name="KeyBox" Grid.Column="0" Height="42" FontSize="17" Padding="12,8" Background="#08130E" Foreground="White" BorderBrush="#274437" BorderThickness="1"/>
        <Button x:Name="PasteButton" Grid.Column="1" Style="{StaticResource GhostButton}" Content="PASTE FROM CLIPBOARD" Margin="12,0,0,0"/>
      </Grid>
    </Border>

    <TextBlock x:Name="KeyStatus" Grid.Row="2" Text="Nothing pasted yet." Foreground="#C9DAD0" FontSize="12" Margin="4,8,0,0"/>

    <Border Grid.Row="3" Background="#0B1711" BorderBrush="#1B3025" BorderThickness="1" CornerRadius="12" Padding="13" Margin="0,18,0,0">
      <TextBlock Foreground="#D1E0D7" FontSize="12" TextWrapping="Wrap">
        <Run FontWeight="Bold" Foreground="#E7F1EB" Text="Security note: "/>
        <Run Text="Do not paste the key into ChatGPT, screenshots, or Drive. Saving here overwrites the old Factor Golf key and clears the clipboard."/>
      </TextBlock>
    </Border>

    <TextBlock x:Name="MessageText" Grid.Row="4" Foreground="#F0A96A" FontSize="12" TextWrapping="Wrap" Margin="4,12,0,0"/>

    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
      <Button x:Name="CancelButton" Style="{StaticResource GhostButton}" Content="CANCEL" Margin="0,0,10,0"/>
      <Button x:Name="SaveButton" Style="{StaticResource PrimaryButton}" Content="SAVE KEY SECURELY"/>
    </StackPanel>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$KeyBox = $window.FindName("KeyBox")
$PasteButton = $window.FindName("PasteButton")
$SaveButton = $window.FindName("SaveButton")
$CancelButton = $window.FindName("CancelButton")
$KeyStatus = $window.FindName("KeyStatus")
$MessageText = $window.FindName("MessageText")

try {
    $iconPath = Join-Path $AppDir "assets\Halliseum.ico"
    if (Test-Path $iconPath) { $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath) }
} catch {}

function Update-KeyStatus {
    $len = $KeyBox.Password.Length
    if ($len -gt 0) {
        $KeyStatus.Text = "Key detected - $len characters. The actual key stays hidden."
        $KeyStatus.Foreground = "#78D6A2"
    } else {
        $KeyStatus.Text = "Nothing pasted yet."
        $KeyStatus.Foreground = "#6F8D7F"
    }
}

function Paste-Key {
    try {
        $text = [System.Windows.Clipboard]::GetText().Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            $MessageText.Text = "The clipboard is empty. Copy the API key first, then click PASTE FROM CLIPBOARD."
            return
        }
        $KeyBox.Password = $text
        $MessageText.Text = ""
        Update-KeyStatus
        $KeyBox.Focus() | Out-Null
    } catch {
        $MessageText.Text = "Factor Golf could not read the clipboard. Copy the API key again and retry."
    }
}

$PasteButton.Add_Click({ Paste-Key })
$KeyBox.Add_PasswordChanged({ Update-KeyStatus })
$KeyBox.Add_PreviewKeyDown({
    param($sender,$e)
    if ($e.Key -eq [System.Windows.Input.Key]::V -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
        Paste-Key
        $e.Handled = $true
    }
})

$KeyBox.Add_KeyDown({
    param($sender,$e)
    if($e.Key -eq [System.Windows.Input.Key]::Enter){$SaveButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)));$e.Handled=$true}
})

$CancelButton.Add_Click({ $window.Close() })
$SaveButton.Add_Click({
    try {
        $key = $KeyBox.Password.Trim()
        if ($key.Length -lt 20) {
            $MessageText.Text = "That does not look like a complete API key. Use the green PASTE FROM CLIPBOARD button and try again."
            return
        }
        if (-not $key.StartsWith("sk-")) {
            $MessageText.Text = "That key does not begin with 'sk-'. Factor Golf will not save it because it may be the wrong value."
            return
        }
        $secure = ConvertTo-SecureString -String $key -AsPlainText -Force
        $encrypted = $secure | ConvertFrom-SecureString
        [IO.File]::WriteAllText($SecretFile,$encrypted,[Text.Encoding]::ASCII)
        try { [System.Windows.Clipboard]::Clear() } catch {}
        [System.Windows.MessageBox]::Show(
            "API key saved securely for Factor Golf Sim Control Center.`n`nThe clipboard was cleared. You can close this window and continue setup.",
            "Factor Golf - API Key Saved",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        $window.DialogResult = $true
        $window.Close()
    } catch {
        $MessageText.Text = "Factor Golf could not save the key: $($_.Exception.Message)"
    }
})

$window.Add_ContentRendered({ $KeyBox.Focus() | Out-Null })
$window.ShowDialog() | Out-Null
