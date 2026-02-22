<#
.SYNOPSIS
    DiskCleaner Pro v3.0 - Windows Native Disk Cleanup Tool
.DESCRIPTION
    Modular PowerShell WPF app. AV-friendly. Beats Storage Sense.
    Features: System Cleaner, File Age Analysis, Folder Sizes,
    Smart Recommendations, Multi-tier Duplicate Detection, One-Click Safe Clean,
    AI-powered File Classification (Groq/Llama 3.1), Folder Organizer.
.AUTHOR
    Le Van An (@anlvdt)
#>

# Hide console
Add-Type -Name Win32 -Namespace Native -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$null = [Native.Win32]::ShowWindow([Native.Win32]::GetConsoleWindow(), 0)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Load modules
$modPath = Join-Path $PSScriptRoot 'modules'
. (Join-Path $modPath 'Scanner.ps1')
. (Join-Path $modPath 'SystemCleaner.ps1')
. (Join-Path $modPath 'SmartClean.ps1')
. (Join-Path $modPath 'BrokenFiles.ps1')
. (Join-Path $modPath 'ScanHistory.ps1')
. (Join-Path $modPath 'SafeGuard.ps1')
. (Join-Path $modPath 'FolderOrganizer.ps1')
. (Join-Path $modPath 'DevClean.ps1')
. (Join-Path $modPath 'AIClassifier.ps1')



[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DiskCleaner Pro" MinHeight="600" MinWidth="900"
        WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <Style TargetType="ScrollBar"><Setter Property="Width" Value="10"/><Setter Property="MinWidth" Value="10"/><Setter Property="Background" Value="Transparent"/></Style>
        <Style TargetType="ScrollViewer"><Setter Property="Background" Value="Transparent"/></Style>
        <Style x:Key="DarkThumb" TargetType="Thumb"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Thumb"><Border x:Name="tb" Background="#1e2d42" CornerRadius="4" Margin="1"/><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="tb" Property="Background" Value="#2563eb"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="Card" TargetType="Border"><Setter Property="Background" Value="#161f2e"/><Setter Property="BorderBrush" Value="#1e2d42"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="10"/><Setter Property="Padding" Value="18"/><Setter Property="Margin" Value="5"/></Style>
        <Style x:Key="BtnP" TargetType="Button"><Setter Property="Background" Value="#2563eb"/><Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="Medium"/><Setter Property="FontSize" Value="12.5"/><Setter Property="Padding" Value="20,9"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1d4ed8"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Background" Value="#1e293b"/><Setter Property="Foreground" Value="#475569"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="BtnD" TargetType="Button"><Setter Property="Background" Value="#dc2626"/><Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="Medium"/><Setter Property="FontSize" Value="12.5"/><Setter Property="Padding" Value="20,9"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#b91c1c"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Background" Value="#1e293b"/><Setter Property="Foreground" Value="#475569"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="BtnS" TargetType="Button"><Setter Property="Background" Value="#131c2b"/><Setter Property="Foreground" Value="#8899b0"/><Setter Property="FontSize" Value="12"/><Setter Property="Padding" Value="14,7"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}" BorderBrush="#1e2d42" BorderThickness="1"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1e2d42"/><Setter Property="Foreground" Value="#c8d6e5"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="BtnGreen" TargetType="Button"><Setter Property="Background" Value="#059669"/><Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontSize" Value="13"/><Setter Property="Padding" Value="24,11"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#047857"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Background" Value="#1e293b"/><Setter Property="Foreground" Value="#475569"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="TBtn" TargetType="Button"><Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="#5a6f8a"/><Setter Property="FontSize" Value="10"/><Setter Property="Width" Value="50"/><Setter Property="Height" Value="42"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontFamily" Value="Segoe MDL2 Assets"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#182536"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="XBtn" TargetType="Button" BasedOn="{StaticResource TBtn}"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="Transparent"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#c42b1c"/><Setter Property="Foreground" Value="White"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style TargetType="TabItem"><Setter Property="Foreground" Value="#6b7f99"/><Setter Property="FontSize" Value="12.5"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Padding" Value="20,12"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TabItem"><Border x:Name="bd" Background="Transparent" Padding="{TemplateBinding Padding}" Margin="0,0,2,0" BorderThickness="0,0,0,2" BorderBrush="Transparent"><ContentPresenter ContentSource="Header"/></Border><ControlTemplate.Triggers><Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#2563eb"/><Setter Property="Foreground" Value="#93c5fd"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#0d1525"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style TargetType="DataGrid"><Setter Property="Background" Value="#0d1525"/><Setter Property="Foreground" Value="#c8d6e5"/><Setter Property="BorderBrush" Value="#1e2d42"/><Setter Property="BorderThickness" Value="1"/><Setter Property="GridLinesVisibility" Value="Horizontal"/><Setter Property="HorizontalGridLinesBrush" Value="#131c2b"/><Setter Property="RowBackground" Value="Transparent"/><Setter Property="AlternatingRowBackground" Value="#0a1019"/><Setter Property="HeadersVisibility" Value="Column"/><Setter Property="FontSize" Value="13"/><Setter Property="IsReadOnly" Value="True"/><Setter Property="AutoGenerateColumns" Value="False"/><Setter Property="CanUserResizeRows" Value="False"/><Setter Property="RowHeight" Value="38"/><Setter Property="SelectionMode" Value="Extended"/></Style>
        <Style TargetType="DataGridColumnHeader"><Setter Property="Background" Value="#101828"/><Setter Property="Foreground" Value="#6b7f99"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="FontSize" Value="12"/><Setter Property="Padding" Value="14,10"/><Setter Property="BorderBrush" Value="#1e2d42"/><Setter Property="BorderThickness" Value="0,0,1,1"/></Style>
        <Style TargetType="DataGridRow"><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="#152240"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#0f1a2e"/></Trigger></Style.Triggers></Style>
        <Style TargetType="DataGridCell"><Setter Property="BorderThickness" Value="0"/><Setter Property="Foreground" Value="#c8d6e5"/><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="#93c5fd"/></Trigger></Style.Triggers></Style>
        <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#c8d6e5"/><Setter Property="VerticalContentAlignment" Value="Center"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#0d1525"/><Setter Property="Foreground" Value="#c8d6e5"/><Setter Property="CaretBrush" Value="#c8d6e5"/><Setter Property="SelectionBrush" Value="#2563eb"/><Setter Property="BorderBrush" Value="#1e2d42"/><Setter Property="BorderThickness" Value="1"/></Style>
        <Style TargetType="ToolTip"><Setter Property="Background" Value="#131c2b"/><Setter Property="Foreground" Value="#c8d6e5"/><Setter Property="BorderBrush" Value="#1e2d42"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="10,6"/><Setter Property="FontSize" Value="12"/></Style>
    </Window.Resources>
    <Border Background="#0b1120" CornerRadius="10" BorderBrush="#1a2740" BorderThickness="1">
        <Grid>
            <Grid.RowDefinitions><RowDefinition Height="42"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <!-- TITLE BAR -->
            <Border Grid.Row="0" Background="#080e1a" CornerRadius="10,10,0,0" x:Name="titleBar"><DockPanel>
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" Margin="14,0" VerticalAlignment="Center"><Ellipse Width="10" Height="10" Fill="#2563eb" Margin="0,0,8,0"/><TextBlock x:Name="lblTitle" Text="DiskCleaner Pro" Foreground="#4a8fe7" FontSize="12.5" FontWeight="SemiBold"/><TextBlock Text="  v3.0" Foreground="#2d4460" FontSize="11"/></StackPanel>
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right"><Button x:Name="btnMin" Content="&#xE921;" Style="{StaticResource TBtn}"/><Button x:Name="btnMax" Content="&#xE922;" Style="{StaticResource TBtn}"/><Button x:Name="btnClose" Content="&#xE8BB;" Style="{StaticResource XBtn}"/></StackPanel>
                
            </DockPanel></Border>
            <!-- SIMPLE MODE -->
            <Border x:Name="panelSimple" Grid.Row="1" Background="#0b1120" Visibility="Visible"><ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Margin="40,30">
                    <Border Background="#161f2e" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="14" Padding="32,24" Margin="0,0,0,20" MinWidth="500"><StackPanel HorizontalAlignment="Center">
                        <TextBlock Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets" FontSize="42" Foreground="#2563eb" HorizontalAlignment="Center" Margin="0,0,0,12"/>
                        <TextBlock x:Name="lblDiskInfo" Text="Checking disk..." Foreground="#c8d6e5" FontSize="16" HorizontalAlignment="Center" TextAlignment="Center"/>
                        <TextBlock x:Name="lblDiskBar" Text="" Foreground="#6b7f99" FontSize="12" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                    </StackPanel></Border>
                    <Button x:Name="btnSimpleClean" Cursor="Hand" Margin="0,0,0,20"><Button.Template><ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="#059669" CornerRadius="16" Padding="48,22" MinWidth="340"><StackPanel HorizontalAlignment="Center">
                            <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="28" Foreground="White" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                            <TextBlock Text="Clean My Disk" Foreground="White" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center"/>
                            <TextBlock Text="Temp files, browser cache, recycle bin" Foreground="#a7f3d0" FontSize="12" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                        </StackPanel></Border>
                        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#047857"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Background" Value="#1e293b"/></Trigger></ControlTemplate.Triggers>
                    </ControlTemplate></Button.Template></Button>
                    <Border Background="#161f2e" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="10" Padding="20,14" MinWidth="500">
                        <TextBlock x:Name="lblSimpleResult" Text="Not cleaned yet. Click the button to start!" Foreground="#6b7f99" FontSize="13" HorizontalAlignment="Center" TextAlignment="Center"/>
                    </Border>
                    <Border Width="400" Height="12" Background="#131c2b" CornerRadius="6" Margin="0,14,0,0">
                        <Border x:Name="simpleProgressFill" Background="#059669" CornerRadius="6" HorizontalAlignment="Left" Width="0"/>
                    </Border>
                    <TextBlock x:Name="lblSimpleProgress" Text="" Foreground="#3d5470" FontSize="11" Margin="0,6,0,0" HorizontalAlignment="Center"/>
                </StackPanel>
            </ScrollViewer></Border>
            <!-- ADVANCED TABS -->
            <TabControl x:Name="panelAdvanced" Grid.Row="1" Background="#0b1120" BorderThickness="0" Padding="0" Visibility="Collapsed">
                <!-- TAB: CLEAN -->
                <TabItem Header="  Clean  "><Grid Background="#0b1120"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Style="{StaticResource Card}" Margin="18,10,18,4"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <DockPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock Text="System Junk Cleaner" Foreground="#c8d6e5" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/><TextBlock Text="  -  Scan and clean temp files, caches, crash dumps" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/>
                            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
                                <TextBlock x:Name="lblCleanTotal" Text="Click Analyze to scan sizes" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center" Margin="0,0,12,0"/>
                                <Button x:Name="btnAnalyze" Content="Analyze" Style="{StaticResource BtnP}" Padding="16,10"/>
                            </StackPanel>
                        </DockPanel>
                        <DataGrid Grid.Row="1" x:Name="gridClean"><DataGrid.Columns>
                            <DataGridCheckBoxColumn Binding="{Binding IsChecked, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Width="44"/>
                            <DataGridTextColumn Header="Category" Binding="{Binding Name}" Width="200" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Description" Binding="{Binding Desc}" Width="*" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="90" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Files" Binding="{Binding FileCount}" Width="70" IsReadOnly="True"/>
                        </DataGrid.Columns></DataGrid>
                    </Grid></Border>
                    <DockPanel Grid.Row="1" Margin="18,4,18,14">
                        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                            <Button x:Name="btnSelectAll" Content="Select All" Style="{StaticResource BtnS}" Margin="0,0,8,0"/>
                            <Button x:Name="btnDeselectAll" Content="Deselect All" Style="{StaticResource BtnS}" Margin="0,0,16,0"/>
                            <Button x:Name="btnCleanChecked" Content="Clean Selected" Style="{StaticResource BtnGreen}"/>
                        </StackPanel>
                        <StackPanel VerticalAlignment="Center">
                            <Border Width="300" Height="10" Background="#131c2b" CornerRadius="5" HorizontalAlignment="Left">
                                <Border x:Name="cleanProgressFill" Background="#2563eb" CornerRadius="5" HorizontalAlignment="Left" Width="0"/>
                            </Border>
                            <TextBlock x:Name="lblCleanProgress" Text="" Foreground="#3d5470" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                    </DockPanel>
                </Grid></TabItem>
                <TabItem Header="  Dev Cleanup  "><Grid Background="#0b1120"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <DockPanel Grid.Row="0" Margin="18,14,18,8">
                        <TextBlock Text="Dev Cleanup" Foreground="#c8d6e5" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/><TextBlock Text="  -  Detects and cleans developer build artifacts" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/>
                        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
                            <TextBlock x:Name="lblDevDesc" Visibility="Collapsed"/><TextBlock x:Name="lblDevInfo" Text="Click Scan to find dev artifacts" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center" Margin="0,0,12,0"/>
                            <Button x:Name="btnDevScan" Content="Scan" Style="{StaticResource BtnP}" Padding="16,10"/>
                        </StackPanel>
                    </DockPanel>
                    <DataGrid Grid.Row="1" x:Name="gridDev" Margin="18,0,18,8"><DataGrid.Columns>
                        <DataGridTextColumn Header="Artifact" Binding="{Binding Name}" Width="140"/>
                        <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="100"/>
                        <DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="100"/>
                        <DataGridTextColumn Header="Project" Binding="{Binding Parent}" Width="*"/>
                    </DataGrid.Columns></DataGrid>
                    <DockPanel Grid.Row="2" Margin="18,0,18,4">
                        <TextBlock DockPanel.Dock="Right" x:Name="lblDevProgress" Text="" Foreground="#3d5470" FontSize="10" VerticalAlignment="Center"/>
                        <Border Width="300" Height="10" Background="#131c2b" CornerRadius="5" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <Border x:Name="devProgressFill" Background="#8b5cf6" CornerRadius="5" HorizontalAlignment="Left" Width="0"/>
                        </Border>
                    </DockPanel>
                    <Button Grid.Row="3" x:Name="btnDevClean" Content="Clean Selected" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="18,0,18,14"/>
                </Grid></TabItem>
                <!-- TAB: DISK ANALYZER -->
                <TabItem Header="  Disk Analyzer  "><Grid Background="#0b1120"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <!-- Analyzer header -->
                    <DockPanel Grid.Row="0" Margin="18,14,18,0">
                        <TextBlock Text="Disk Analyzer" Foreground="#c8d6e5" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/><TextBlock Text="  -  Scans folders for large files, duplicates, junk and old files" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/>
                    </DockPanel>
                    <!-- Analyzer toolbar -->
                    <DockPanel Grid.Row="1" Margin="18,8,18,8">
                        <StackPanel Orientation="Horizontal">
                            <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="14,9" MinWidth="300"><TextBlock x:Name="lblPath" Text="Select a folder to scan..." Foreground="#3d5470" FontSize="12.5"/></Border>
                            <Button x:Name="btnBrowse" Content="Browse" Style="{StaticResource BtnS}" Margin="8,0"/>
                            <Button x:Name="btnScan" Content="Scan" Style="{StaticResource BtnP}"/>
                            <Button x:Name="btnExport" Content="Export" Style="{StaticResource BtnS}" Margin="8,0" IsEnabled="False"/>
                        </StackPanel>
                    </DockPanel>
                    <!-- Stats -->
                    <Border Grid.Row="2" Padding="18,0,18,4"><UniformGrid Columns="6">
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="FILES" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statFiles" Text="--" Foreground="#4a8fe7" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="SIZE" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statSize" Text="--" Foreground="#0ea5e9" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="LARGE" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statLarge" Text="--" Foreground="#f59e0b" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="DUPS" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statDup" Text="--" Foreground="#ef4444" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="JUNK" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statJunk" Text="--" Foreground="#eab308" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="OLD" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statOld" Text="--" Foreground="#a78bfa" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                    </UniformGrid></Border>
                    <!-- Analyzer Progress -->
                    <DockPanel Grid.Row="3" Margin="18,4,18,4">
                        <TextBlock DockPanel.Dock="Right" x:Name="lblAnalyzerProgress" Text="" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/>
                        <Border Width="400" Height="10" Background="#131c2b" CornerRadius="5" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <Border x:Name="analyzerProgressFill" Background="#0ea5e9" CornerRadius="5" HorizontalAlignment="Left" Width="0"/>
                        </Border>
                    </DockPanel>
                    <!-- Sub-tabs -->
                    <TabControl Grid.Row="4" Background="#0b1120" BorderThickness="0" Padding="0" Margin="18,0,18,10">
                        <TabItem Header="Large Files"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridLarge"><DataGrid.Columns><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="240"/><DataGridTextColumn Header="Directory" Binding="{Binding Directory}" Width="*"/><DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="90"/><DataGridTextColumn Header="Modified" Binding="{Binding Modified}" Width="120"/></DataGrid.Columns></DataGrid>
                            <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8"><Button x:Name="btnOL" Content="Open" Style="{StaticResource BtnS}" Margin="0,0,8,0"/><Button x:Name="btnDL" Content="Delete" Style="{StaticResource BtnD}"/></StackPanel>
                        </Grid></TabItem>
                        <TabItem Header="Duplicates"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridDup"><DataGrid.Columns><DataGridTextColumn Header="Group" Binding="{Binding GroupId}" Width="60"/><DataGridTextColumn Header="Hash" Binding="{Binding Hash}" Width="100"/><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/><DataGridTextColumn Header="Path" Binding="{Binding FullPath}" Width="*"/><DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="80"/></DataGrid.Columns></DataGrid>
                            <Button Grid.Row="1" x:Name="btnDD" Content="Delete" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="0,8"/>
                        </Grid></TabItem>
                        <TabItem Header="Junk"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridJunk"><DataGrid.Columns><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/><DataGridTextColumn Header="Path" Binding="{Binding FullPath}" Width="*"/><DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="80"/><DataGridTextColumn Header="Reason" Binding="{Binding Reason}" Width="160"/></DataGrid.Columns></DataGrid>
                            <Button Grid.Row="1" x:Name="btnDJ" Content="Delete" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="0,8"/>
                        </Grid></TabItem>
                        <TabItem Header="Old Files"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridAge"><DataGrid.Columns><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/><DataGridTextColumn Header="Directory" Binding="{Binding Directory}" Width="*"/><DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="80"/><DataGridTextColumn Header="Age" Binding="{Binding AgeText}" Width="90"/></DataGrid.Columns></DataGrid>
                            <Button Grid.Row="1" x:Name="btnDA" Content="Delete" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="0,8"/>
                        </Grid></TabItem>
                        <TabItem Header="Empty"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridEmpty"><DataGrid.Columns><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/><DataGridTextColumn Header="Path" Binding="{Binding FullPath}" Width="*"/><DataGridTextColumn Header="Created" Binding="{Binding Created}" Width="120"/></DataGrid.Columns></DataGrid>
                            <Button Grid.Row="1" x:Name="btnDE" Content="Delete" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="0,8"/>
                        </Grid></TabItem>
                        <TabItem Header="Broken"><Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <DataGrid Grid.Row="0" x:Name="gridBroken"><DataGrid.Columns><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/><DataGridTextColumn Header="Path" Binding="{Binding FullPath}" Width="*"/><DataGridTextColumn Header="Issue" Binding="{Binding Issue}" Width="200"/></DataGrid.Columns></DataGrid>
                            <Button Grid.Row="1" x:Name="btnDB" Content="Delete" Style="{StaticResource BtnD}" HorizontalAlignment="Right" Margin="0,8"/>
                        </Grid></TabItem>
                    </TabControl>
                </Grid></TabItem>
                <!-- TAB: ORGANIZE -->
                <TabItem Header="  Organize  "><Grid Background="#0b1120"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Margin="18,14,18,8"><StackPanel>
                        <DockPanel Margin="0,0,0,10"><TextBlock Text="File Organizer" Foreground="#c8d6e5" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/><TextBlock Text="  -  Moves files into categorized folders, no files deleted" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/></DockPanel>
                        <DockPanel Margin="0,0,0,6">
                            <Button DockPanel.Dock="Right" x:Name="btnOrgDocuments" Content="Documents" Style="{StaticResource BtnS}" Margin="4,0,0,0" Padding="14,8"/>
                            <Button DockPanel.Dock="Right" x:Name="btnOrgDownloads" Content="Downloads" Style="{StaticResource BtnS}" Margin="4,0,0,0" Padding="14,8"/>
                            <Button DockPanel.Dock="Right" x:Name="btnOrgDesktop" Content="Desktop" Style="{StaticResource BtnS}" Margin="4,0,0,0" Padding="14,8"/>
                            <Button DockPanel.Dock="Right" x:Name="btnOrgBrowse" Content="Browse" Style="{StaticResource BtnS}" Margin="8,0,0,0" Padding="14,8"/>
                            <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="14,8"><TextBlock x:Name="lblOrgPath" Text="Select a folder to organize..." Foreground="#3d5470" FontSize="12" TextTrimming="CharacterEllipsis"/></Border>
                        </DockPanel>
                        <StackPanel Orientation="Horizontal">
                            <Button x:Name="btnOrgByType" Content="By Type" Style="{StaticResource BtnP}" Margin="0,0,6,0" Padding="16,8"/>
                            <Button x:Name="btnOrgByDate" Content="By Date" Style="{StaticResource BtnS}" Margin="0,0,6,0" Padding="16,8"/>
                            <Button x:Name="btnOrgBySize" Content="By Size" Style="{StaticResource BtnS}" Margin="0,0,16,0" Padding="16,8"/>
                            <Button x:Name="btnOrgPreview" Content="Preview" Style="{StaticResource BtnP}" Margin="0,0,6,0" Padding="16,8"/>
                            <Button x:Name="btnOrgUndo" Content="Undo Last" Style="{StaticResource BtnS}" Margin="0,0,6,0" Padding="16,8"/>
                            <Button x:Name="btnOrgAI" Content="[AI] Off" Style="{StaticResource BtnS}" Margin="0,0,0,0" Padding="16,8" Foreground="#3d5470"/>
                        </StackPanel>
                    </StackPanel></Border>
                    <Border Grid.Row="1" Margin="18,0,18,4"><UniformGrid Columns="3">
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="FILES TO MOVE" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statOrgFiles" Text="--" Foreground="#4a8fe7" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="CATEGORIES" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statOrgCats" Text="--" Foreground="#f59e0b" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                        <Border Style="{StaticResource Card}" Padding="14,10"><StackPanel><TextBlock Text="TOTAL SIZE" Foreground="#3d5470" FontSize="11" FontWeight="SemiBold"/><TextBlock x:Name="statOrgSize" Text="--" Foreground="#0ea5e9" FontSize="18" FontWeight="Bold"/></StackPanel></Border>
                    </UniformGrid></Border>
                    <Border Grid.Row="2" Style="{StaticResource Card}" Margin="18,4,18,8">
                        <DataGrid x:Name="gridOrganize"><DataGrid.Columns>
                            <DataGridTextColumn Header="File" Binding="{Binding Name}" Width="2*"/>
                            <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="100"/>
                            <DataGridTextColumn Header="Destination" Binding="{Binding DestFolder}" Width="3*"/>
                            <DataGridTextColumn Header="Size" Binding="{Binding SizeText}" Width="80"/>
                        </DataGrid.Columns></DataGrid>
                    </Border>
                    <DockPanel Grid.Row="3" Margin="18,0,18,4">
                        <TextBlock DockPanel.Dock="Right" x:Name="lblOrgProgress" Text="" Foreground="#3d5470" FontSize="10" VerticalAlignment="Center"/>
                        <Border Width="300" Height="10" Background="#131c2b" CornerRadius="5" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <Border x:Name="orgProgressFill" Background="#34d399" CornerRadius="5" HorizontalAlignment="Left" Width="0"/>
                        </Border>
                    </DockPanel>
                    <DockPanel Grid.Row="4" Margin="18,0,18,10">
                        <Button DockPanel.Dock="Right" x:Name="btnOrgExecute" Content="Organize Now" Style="{StaticResource BtnP}" IsEnabled="False"/>
                        <TextBlock x:Name="lblOrgStatus" Text="" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,12,0"/>
                    </DockPanel>
                </Grid></TabItem>
                <!-- TAB: RENAME -->
                <TabItem Header="  Rename  "><Grid Background="#0b1120"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Margin="18,14,18,8"><StackPanel>
                        <DockPanel Margin="0,0,0,10"><TextBlock Text="Bulk Rename" Foreground="#c8d6e5" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/><TextBlock Text="  -  Rename multiple files at once with patterns" Foreground="#3d5470" FontSize="11" VerticalAlignment="Center"/></DockPanel>
                        <DockPanel Margin="0,0,0,8">
                            <Button DockPanel.Dock="Right" x:Name="btnRenBrowse" Content="Browse" Style="{StaticResource BtnS}" Margin="8,0,0,0" Padding="14,8"/>
                            <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="14,8"><TextBlock x:Name="lblRenPath" Text="Select a folder..." Foreground="#3d5470" FontSize="12" TextTrimming="CharacterEllipsis"/></Border>
                        </DockPanel>
                        <DockPanel>
                            <TextBlock Text="Mode:" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <Button x:Name="btnRenPrefix" Content="Add Prefix" Style="{StaticResource BtnP}" Margin="0,0,6,0" Padding="14,8"/>
                            <Button x:Name="btnRenSuffix" Content="Add Suffix" Style="{StaticResource BtnS}" Margin="0,0,6,0" Padding="14,8"/>
                            <Button x:Name="btnRenReplace" Content="Replace Text" Style="{StaticResource BtnS}" Margin="0,0,6,0" Padding="14,8"/>
                            <Button x:Name="btnRenSeq" Content="Sequential" Style="{StaticResource BtnS}" Margin="0,0,6,0" Padding="14,8"/>
                            <Button x:Name="btnRenDate" Content="Date Prefix" Style="{StaticResource BtnS}" Margin="0,0,0,0" Padding="14,8"/>
                        </DockPanel>
                    </StackPanel></Border>
                    <Border Grid.Row="1" Margin="18,0,18,8"><DockPanel>
                        <TextBlock Text="Find:" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="10,7" MinWidth="150" Margin="0,0,12,0">
                            <TextBox x:Name="txtRenFind" Background="Transparent" BorderThickness="0" Foreground="#c8d6e5" FontSize="12"/>
                        </Border>
                        <TextBlock Text="Replace:" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="10,7" MinWidth="150" Margin="0,0,12,0">
                            <TextBox x:Name="txtRenReplace" Background="Transparent" BorderThickness="0" Foreground="#c8d6e5" FontSize="12"/>
                        </Border>
                        <Button x:Name="btnRenPreview" Content="Preview" Style="{StaticResource BtnP}" Padding="16,8"/>
                    </DockPanel></Border>
                    <Border Grid.Row="2" Style="{StaticResource Card}" Margin="18,0,18,8">
                        <DataGrid x:Name="gridRename"><DataGrid.Columns>
                            <DataGridTextColumn Header="Original Name" Binding="{Binding OldName}" Width="2*"/>
                            <DataGridTextColumn Header="New Name" Binding="{Binding NewName}" Width="2*"/>
                            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                        </DataGrid.Columns></DataGrid>
                    </Border>
                    <DockPanel Grid.Row="3" Margin="18,0,18,10">
                        <Button DockPanel.Dock="Right" x:Name="btnRenApply" Content="Rename All" Style="{StaticResource BtnGreen}" IsEnabled="False"/>
                        <TextBlock x:Name="lblRenStatus" Text="" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,12,0"/>
                    </DockPanel>
                </Grid></TabItem>
                <!-- TAB: SETTINGS -->
                <TabItem Header="  Settings  "><ScrollViewer VerticalScrollBarVisibility="Auto"><Border Background="#0b1120" Padding="32,24">
                    <StackPanel MaxWidth="550" HorizontalAlignment="Center">
                        <TextBlock Text="Settings" Foreground="#c8d6e5" FontSize="22" FontWeight="Bold" Margin="0,0,0,20"/>
                        <!-- AI Classification Section -->
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="AI CLASSIFICATION (OPTIONAL)" Foreground="#34d399" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="20" Margin="0,0,0,8" Text="Enable AI to auto-classify files that can't be identified by extension. Uses Groq API with Llama 3.1 model."/>
                                <TextBlock Foreground="#34d399" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,5" Text="[v] 100% FREE - NO CREDIT CARD NEEDED"/>
                                <TextBlock Foreground="#34d399" FontSize="11" Margin="0,0,0,5" Text="[v] Free 14,400 calls/day (more than enough for any use)"/>
                                <TextBlock Foreground="#f59e0b" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,12" Text="API key is stored locally on YOUR machine ONLY. Never sent to the app author or anyone else. Open source - you can verify."/>
                                <DockPanel Margin="0,0,0,12">
                                    <TextBlock Text="Status:" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <TextBlock x:Name="lblAIStatus" Text="[x] Disabled" Foreground="#ef4444" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </DockPanel>
                                <TextBlock Text="API Key:" Foreground="#6b7f99" FontSize="12" Margin="0,0,0,6"/>
                                <DockPanel Margin="0,0,0,12">
                                    <Button DockPanel.Dock="Right" x:Name="btnApiKeySave" Content="Save Key" Style="{StaticResource BtnP}" Padding="16,8" Margin="8,0,0,0"/>
                                    <Button DockPanel.Dock="Right" x:Name="btnApiKeyTest" Content="Test" Style="{StaticResource BtnS}" Padding="12,8" Margin="8,0,0,0"/>
                                    <Border Background="#0d1525" BorderBrush="#1e2d42" BorderThickness="1" CornerRadius="7" Padding="10,8">
                                        <TextBox x:Name="txtApiKey" Background="Transparent" BorderThickness="0" Foreground="#c8d6e5" FontSize="12" FontFamily="Consolas"/>
                                    </Border>
                                </DockPanel>
                            </StackPanel>
                        </Border>
                        <!-- How to get API Key -->
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="HOW TO GET FREE API KEY" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,12"/>
                                <TextBlock Foreground="#f59e0b" FontSize="11" Margin="0,0,0,10" Text="(!) 100% Free - No credit card - No charges ever"/>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="24" Height="24" CornerRadius="12" Background="#2563eb" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"><TextBlock Text="1" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Go to console.groq.com" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Sign in with your Google or GitHub account" Foreground="#6b7f99" FontSize="11" TextWrapping="Wrap"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="24" Height="24" CornerRadius="12" Background="#2563eb" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"><TextBlock Text="2" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Go to API Keys page" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Click on API Keys menu (or go directly to: console.groq.com/keys)" Foreground="#6b7f99" FontSize="11" TextWrapping="Wrap"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="24" Height="24" CornerRadius="12" Background="#2563eb" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"><TextBlock Text="3" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Create API Key" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Click 'Create API Key' and copy the key (starts with gsk_...)" Foreground="#6b7f99" FontSize="11" TextWrapping="Wrap"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,4"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="24" Height="24" CornerRadius="12" Background="#22c55e" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"><TextBlock Text="4" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Paste &amp; Save" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Paste your key in the box above, click Save Key. AI is now active!" Foreground="#6b7f99" FontSize="11" TextWrapping="Wrap"/></StackPanel>
                                </Grid>
                            </StackPanel>
                        </Border>
                        <Button x:Name="btnOpenGroq" Content="Open console.groq.com/keys" Style="{StaticResource BtnP}" HorizontalAlignment="Stretch" Padding="0,12" Margin="0,0,0,16" FontSize="13"/>
                        <!-- AI Info -->
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="AI DETAILS" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Provider" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="Groq (groq.com)" Foreground="#c8d6e5" FontSize="12"/>
                                </Grid>
                                <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Model" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="Llama 3.1 8B Instant" Foreground="#c8d6e5" FontSize="12"/>
                                </Grid>
                                <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Cost" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="FREE - 14,400 calls/day (no time limit)" Foreground="#34d399" FontSize="12" FontWeight="SemiBold"/>
                                </Grid>
                                <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Credit Card" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="NOT required" Foreground="#34d399" FontSize="12" FontWeight="SemiBold"/>
                                </Grid>
                                <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Rate Limit" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="30 req/min, 14,400 req/day" Foreground="#c8d6e5" FontSize="12"/>
                                </Grid>
                                <Grid Margin="0,0,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Privacy" Foreground="#6b7f99" FontSize="12"/>
                                    <TextBlock Grid.Column="1" Text="Key stored locally ONLY, never sent to author or anyone" Foreground="#f59e0b" FontSize="12" TextWrapping="Wrap"/>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Border></ScrollViewer></TabItem>
                <!-- TAB: ABOUT -->
                <TabItem Header="  About  "><ScrollViewer VerticalScrollBarVisibility="Auto"><Border Background="#0b1120" Padding="32,24">
                    <StackPanel MaxWidth="500" HorizontalAlignment="Center">
                        <TextBlock Text="DiskCleaner Pro" Foreground="#c8d6e5" FontSize="28" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                        <TextBlock Text="v3.0" Foreground="#4a8fe7" FontSize="14" HorizontalAlignment="Center" Margin="0,0,0,16"/>
                        <TextBlock Foreground="#94a3b8" FontSize="13" TextWrapping="Wrap" TextAlignment="Center" LineHeight="22" Margin="0,0,0,6" Text="Free, open-source, AV-friendly disk cleanup tool for Windows. Built with PowerShell + WPF, no installation required. Outperforms Windows Storage Sense with deeper scanning, smarter analysis, and multi-layer safety protection."/>
                        <TextBlock Foreground="#6b7f99" FontSize="12" TextWrapping="Wrap" TextAlignment="Center" LineHeight="20" Margin="0,0,0,24" Text="Zero dependencies. Zero telemetry. 100% local processing. Your files never leave your machine."/>
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="CORE FEATURES" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,14"/>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#3b82f6" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Deep Scanner" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Scans files in 7 phases: large files, duplicate detection, junk patterns, empty folders, file age, folder sizes" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#f97316" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="System Cleaner" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Cleans 30+ targets: temp files, browser caches (Chrome, Edge, Firefox), app caches (Teams, Discord, Slack, Spotify, VS Code, Zoom), crash dumps, error reports, event logs. Zalo is excluded for safety - use Zalo Settings &gt; Data Management instead." Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#8b5cf6" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Dev Clean" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Detects 32+ artifact types: node_modules, __pycache__, build outputs, IDE configs, package caches" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#22c55e" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Folder Organizer + AI" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Organizes files in 4 modes: by type, date, size, content. AI classification (Groq, free), PII detection, undo support" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#ef4444" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="5-Layer SafeGuard" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Protects via 5 layers: critical path blacklist, attribute checks, path containment, Recycle Bin, keeplist" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#eab308" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Smart Clean + Broken Files" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Recommends priority-based actions: broken file detection, extension mismatch, empty files, symlink repair" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                                <Grid Margin="0,0,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Width="14" Height="14" CornerRadius="7" Background="#06b6d4" VerticalAlignment="Top" Margin="0,3,0,0"/>
                                    <StackPanel Grid.Column="1"><TextBlock Text="Scan History" Foreground="#c8d6e5" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="Tracks usage trends via JSON snapshots: size changes, file count, duplicates, junk metrics over time" Foreground="#6b7f99" FontSize="11.5" TextWrapping="Wrap" LineHeight="18"/></StackPanel>
                                </Grid>
                            </StackPanel>
                        </Border>
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="AUTHOR" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <TextBlock Text="Le Van An (Vietnam IT)" Foreground="#c8d6e5" FontSize="14" FontWeight="Medium"/>
                                <TextBlock Text="@anlvdt" Foreground="#6b7f99" FontSize="12" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="SUPPORT THE DEVELOPER" Foreground="#f59e0b" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,12"/>
                                <TextBlock Text="If you find this tool useful, please consider supporting:" Foreground="#6b7f99" FontSize="12" Margin="0,0,0,12"/>
                                <Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="100"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="MB Bank" Foreground="#3b82f6" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="1" Text="0360126996868" Foreground="#c8d6e5" FontSize="14" FontWeight="Medium" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="2" Text="LE VAN AN" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                                </Grid>
                                <Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="100"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Momo" Foreground="#d82d8b" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="1" Text="0976896621" Foreground="#c8d6e5" FontSize="14" FontWeight="Medium" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="2" Text="LE VAN AN" Foreground="#6b7f99" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                                </Grid>
                            </StackPanel>
                        </Border>
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="LINKS" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <Button x:Name="btnGithub" Content="GitHub: github.com/anlvdt" Foreground="#0ea5e9" Background="Transparent" BorderThickness="0" Cursor="Hand" FontSize="13" HorizontalAlignment="Left" Padding="0,4"/>
                                <Button x:Name="btnFacebook" Content="Facebook: Laptop Le An" Foreground="#0ea5e9" Background="Transparent" BorderThickness="0" Cursor="Hand" FontSize="13" HorizontalAlignment="Left" Padding="0,4"/>
                                <Button x:Name="btnShopee" Content="Shopee: Laptop Le An (support by clicking)" Foreground="#ee4d2d" Background="Transparent" BorderThickness="0" Cursor="Hand" FontSize="13" HorizontalAlignment="Left" Padding="0,4"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#0e1726" CornerRadius="8" Padding="20,16" Margin="0,0,0,16">
                            <StackPanel>
                                <TextBlock Text="CREDITS &amp; REFERENCES" Foreground="#4a8fe7" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                <TextBlock Text="Inspired by and references to open-source projects:" Foreground="#6b7f99" FontSize="12" Margin="0,0,0,10"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="22" Margin="0,0,0,4" Text="- huantt/clean-stack - Dev artifact detection patterns"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="22" Margin="0,0,0,4" Text="- tfeldmann/organize - File organization concepts"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="22" Margin="0,0,0,4" Text="- BleachBit - System junk cleanup patterns"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="22" Margin="0,0,0,4" Text="- Windows Disk Cleanup &amp; Storage Sense - UX inspiration"/>
                                <TextBlock Foreground="#94a3b8" FontSize="12" TextWrapping="Wrap" LineHeight="22" Margin="0,0,0,4" Text="- WPF Dark Theme community patterns"/>
                            </StackPanel>
                        </Border>
                        <TextBlock Text="Made with care in Vietnam" Foreground="#2d4460" FontSize="11" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,8,0,0"/>
                    </StackPanel>
                </Border></ScrollViewer></TabItem>
            </TabControl>
            <!-- FOOTER -->
            <Border Grid.Row="2" Background="#080e1a" CornerRadius="0,0,10,10" Padding="18,10"><DockPanel>
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <Button x:Name="btnModeToggle" Cursor="Hand" Background="Transparent" BorderThickness="0" Foreground="#6b7f99" FontSize="11" Padding="14,8" Margin="0,0,4,0">
                        <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Margin="0,0,5,0"/><TextBlock x:Name="lblModeText" Text="Advanced" VerticalAlignment="Center"/></StackPanel>
                    </Button>
                    <TextBlock Text="v3.0" Foreground="#1e2d42" FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
            </DockPanel></Border>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($reader)
$waW = [System.Windows.SystemParameters]::WorkArea.Width
$waH = [System.Windows.SystemParameters]::WorkArea.Height
$Window.Width = [math]::Min(1200, [math]::Max(900, $waW * 0.80))
$Window.Height = [math]::Min(800, [math]::Max(600, $waH * 0.80))

$ui = @{}
$XAML.SelectNodes("//*[@*[contains(translate(name(),'x','X'),'Name')]]") | ForEach-Object {
    $n = $_.Name; if (-not $n) { $n = $_.'x:Name' }; if ($n) { $ui[$n] = $Window.FindName($n) }
}
function MkColor([string]$h) { New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($h)) }

# ===== DIALOG =====
function Show-Dialog {
    param([string]$Message, [string]$Title = 'DiskCleaner Pro', [string]$Buttons = 'OK', [string]$Icon = 'Info')
    $dw = New-Object System.Windows.Window
    $dw.WindowStyle = 'None'; $dw.AllowsTransparency = $true; $dw.Background = [System.Windows.Media.Brushes]::Transparent
    $dw.SizeToContent = 'WidthAndHeight'; $dw.WindowStartupLocation = 'CenterOwner'; $dw.Owner = $Window
    $dw.MinWidth = 380; $dw.MaxWidth = 520; $dw.FontFamily = 'Segoe UI'
    $iconColor = switch ($Icon) { 'Warning' { '#f59e0b' }'Error' { '#ef4444' }'Success' { '#34d399' }default { '#4a8fe7' } }
    $iconChar = switch ($Icon) { 'Warning' { [char]0xE7BA }'Error' { [char]0xEA39 }'Success' { [char]0xE73E }default { [char]0xE946 } }
    $outer = New-Object System.Windows.Controls.Border
    $outer.Background = MkColor '#0e1726'; $outer.BorderBrush = MkColor '#1e2d42'; $outer.BorderThickness = '1'; $outer.CornerRadius = '12'
    $grid = New-Object System.Windows.Controls.Grid
    [void]$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = 'Auto' }))
    [void]$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = '*' }))
    [void]$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = 'Auto' }))
    $hdr = New-Object System.Windows.Controls.Border; $hdr.Background = MkColor '#080e1a'; $hdr.CornerRadius = '12,12,0,0'; $hdr.Padding = '18,12'
    $hdrP = New-Object System.Windows.Controls.StackPanel; $hdrP.Orientation = 'Horizontal'
    $hdrI = New-Object System.Windows.Controls.TextBlock; $hdrI.Text = $iconChar; $hdrI.FontFamily = 'Segoe MDL2 Assets'; $hdrI.FontSize = 16; $hdrI.Foreground = MkColor $iconColor; $hdrI.VerticalAlignment = 'Center'; $hdrI.Margin = '0,0,10,0'
    $hdrT = New-Object System.Windows.Controls.TextBlock; $hdrT.Text = $Title; $hdrT.Foreground = MkColor '#c8d6e5'; $hdrT.FontSize = 14; $hdrT.FontWeight = 'SemiBold'; $hdrT.VerticalAlignment = 'Center'
    [void]$hdrP.Children.Add($hdrI); [void]$hdrP.Children.Add($hdrT); $hdr.Child = $hdrP
    [System.Windows.Controls.Grid]::SetRow($hdr, 0); [void]$grid.Children.Add($hdr)
    $body = New-Object System.Windows.Controls.Border; $body.Padding = '24,20'
    $msgTb = New-Object System.Windows.Controls.TextBlock; $msgTb.Text = $Message; $msgTb.Foreground = MkColor '#94a3b8'; $msgTb.FontSize = 13; $msgTb.TextWrapping = 'Wrap'; $msgTb.LineHeight = 22
    $body.Child = $msgTb; [System.Windows.Controls.Grid]::SetRow($body, 1); [void]$grid.Children.Add($body)
    $ftr = New-Object System.Windows.Controls.Border; $ftr.Background = MkColor '#080e1a'; $ftr.CornerRadius = '0,0,12,12'; $ftr.Padding = '18,12'
    $btnPanel = New-Object System.Windows.Controls.StackPanel; $btnPanel.Orientation = 'Horizontal'; $btnPanel.HorizontalAlignment = 'Right'
    if ($Buttons -eq 'YesNo') {
        $btnNo = New-Object System.Windows.Controls.Border
        $btnNo.Background = MkColor '#1e293b'; $btnNo.CornerRadius = '7'; $btnNo.Padding = '20,9'; $btnNo.Margin = '0,0,8,0'; $btnNo.Cursor = 'Hand'
        $btnNoTb = New-Object System.Windows.Controls.TextBlock; $btnNoTb.Text = 'Cancel'; $btnNoTb.Foreground = MkColor '#8899b0'; $btnNoTb.FontSize = 12.5; $btnNoTb.HorizontalAlignment = 'Center'
        $btnNo.Child = $btnNoTb; $btnNo.Tag = $dw
        $btnNo.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler] { param($s, $e); $s.Tag.Tag = 'No'; $s.Tag.Close() })
        $btnNo.Add_MouseEnter([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor '#2d3f55' })
        $btnNo.Add_MouseLeave([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor '#1e293b' })
        [void]$btnPanel.Children.Add($btnNo)
        $yesBg = if ($Icon -eq 'Warning') { '#dc2626' }else { '#2563eb' }
        $yesHv = if ($Icon -eq 'Warning') { '#b91c1c' }else { '#1d4ed8' }
        $btnYes = New-Object System.Windows.Controls.Border
        $btnYes.Background = MkColor $yesBg; $btnYes.CornerRadius = '7'; $btnYes.Padding = '20,9'; $btnYes.Cursor = 'Hand'
        $btnYesTb = New-Object System.Windows.Controls.TextBlock; $btnYesTb.Text = 'Confirm'; $btnYesTb.Foreground = MkColor '#ffffff'; $btnYesTb.FontSize = 12.5; $btnYesTb.FontWeight = 'Medium'; $btnYesTb.HorizontalAlignment = 'Center'
        $btnYes.Child = $btnYesTb; $btnYes.Tag = @{ Window = $dw; Bg = $yesBg }
        $btnYes.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler] { param($s, $e); $s.Tag.Window.Tag = 'Yes'; $s.Tag.Window.Close() })
        $btnYes.Add_MouseEnter([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor $s.Tag.Bg.Replace('2563eb', '1d4ed8').Replace('dc2626', 'b91c1c') })
        $btnYes.Add_MouseLeave([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor $s.Tag.Bg })
        [void]$btnPanel.Children.Add($btnYes)
    }
    else {
        $btnOk = New-Object System.Windows.Controls.Border
        $btnOk.Background = MkColor '#2563eb'; $btnOk.CornerRadius = '7'; $btnOk.Padding = '20,9'; $btnOk.Cursor = 'Hand'
        $btnOkTb = New-Object System.Windows.Controls.TextBlock; $btnOkTb.Text = 'OK'; $btnOkTb.Foreground = MkColor '#ffffff'; $btnOkTb.FontSize = 12.5; $btnOkTb.FontWeight = 'Medium'; $btnOkTb.HorizontalAlignment = 'Center'
        $btnOk.Child = $btnOkTb; $btnOk.Tag = $dw
        $btnOk.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler] { param($s, $e); $s.Tag.Tag = 'OK'; $s.Tag.Close() })
        $btnOk.Add_MouseEnter([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor '#1d4ed8' })
        $btnOk.Add_MouseLeave([System.Windows.Input.MouseEventHandler] { param($s, $e); $s.Background = MkColor '#2563eb' })
        [void]$btnPanel.Children.Add($btnOk)
    }
    $ftr.Child = $btnPanel; [System.Windows.Controls.Grid]::SetRow($ftr, 2); [void]$grid.Children.Add($ftr)
    $outer.Child = $grid; $dw.Content = $outer; $dw.Tag = 'No'
    $dw.ShowDialog() | Out-Null; return $dw.Tag
}

# ===== MODE =====
$configFile = Join-Path $PSScriptRoot '.diskcleaner_config'
$AppArgs = @{IsScanning = $false; SimpleMode = $true; ScanResults = $null }
if (Test-Path $configFile) { try { $cfg = Get-Content $configFile -Raw | ConvertFrom-Json; $AppArgs.SimpleMode = $cfg.SimpleMode }catch {} }

function Switch-AppMode {
    if ($AppArgs.SimpleMode) { $ui['panelSimple'].Visibility = 'Visible'; $ui['panelAdvanced'].Visibility = 'Collapsed'; $ui['lblModeText'].Text = 'Advanced' }
    else { $ui['panelSimple'].Visibility = 'Collapsed'; $ui['panelAdvanced'].Visibility = 'Visible'; $ui['lblModeText'].Text = 'Simple' }
    @{SimpleMode = $AppArgs.SimpleMode } | ConvertTo-Json | Set-Content $configFile -Force
}

function Update-DiskInfo {
    try {
        $d = Get-PSDrive C; $freeGB = [math]::Round(($d.Free) / 1GB, 1); $totalGB = [math]::Round(($d.Used + $d.Free) / 1GB, 0); $pct = [math]::Round($d.Used / ($d.Used + $d.Free) * 100)
        $ui['lblDiskInfo'].Text = "Drive C: - $freeGB GB free / $totalGB GB total"
        if ($pct -gt 90) { $ui['lblDiskBar'].Text = "Used $pct% - Clean up now!"; $ui['lblDiskBar'].Foreground = MkColor '#ef4444' }
        elseif ($pct -gt 70) { $ui['lblDiskBar'].Text = "Used $pct% - Cleanup recommended"; $ui['lblDiskBar'].Foreground = MkColor '#f59e0b' }
        else { $ui['lblDiskBar'].Text = "Used $pct% - Disk is healthy"; $ui['lblDiskBar'].Foreground = MkColor '#34d399' }
    }
    catch {}
}
$ui['btnModeToggle'].Add_Click({ $AppArgs.SimpleMode = -not $AppArgs.SimpleMode; Switch-AppMode })

$script:simpleCleaning = $false
$ui['btnSimpleClean'].Add_Click({
        if ($script:simpleCleaning) {
            # STOP
            $script:simpleTimer.Stop()
            try { $script:simplePs.Stop(); $script:simplePs.Dispose(); $script:simpleRs.Close(); $script:simpleRs.Dispose() } catch {}
            $ui['lblSimpleResult'].Text = 'Cleaning stopped'; $ui['lblSimpleResult'].Foreground = MkColor '#6b7f99'
            $ui['lblSimpleProgress'].Text = ''
            $ui['btnSimpleClean'].Content = 'Clean My Disk'; $script:simpleCleaning = $false
            return
        }
        # START
        $script:simpleCleaning = $true; $ui['btnSimpleClean'].Content = 'Stop'
        $ui['btnSimpleClean'].IsEnabled = $true
        $ui['lblSimpleResult'].Text = 'Cleaning...'; $ui['lblSimpleResult'].Foreground = MkColor '#f59e0b'
        $ui['simpleProgressFill'].Width = 0; $ui['lblSimpleProgress'].Text = ''
        $script:simpleSh = [hashtable]::Synchronized(@{Done = $false; Error = $null; Cleaned = [long]0; Errors = 0; Current = 0; Total = 0; Status = 'Starting...'; StartTime = [DateTime]::Now })
        $script:simpleRs = [runspacefactory]::CreateRunspace(); $script:simpleRs.ApartmentState = 'STA'; $script:simpleRs.Open()
        $script:simpleRs.SessionStateProxy.SetVariable('sh', $script:simpleSh)
        $script:simpleRs.SessionStateProxy.SetVariable('modPath', (Join-Path $PSScriptRoot 'modules'))
        $script:simplePs = [powershell]::Create(); $script:simplePs.Runspace = $script:simpleRs
        [void]$script:simplePs.AddScript({
                try {
                    . (Join-Path $modPath 'SystemCleaner.ps1')
                    $targets = Get-SystemJunkTargets -AdminMode:$false; $sh.Total = $targets.Count
                    for ($i = 0; $i -lt $targets.Count; $i++) {
                        $t = $targets[$i]; $sh.Status = $t.Name; $sh.Current = $i + 1
                        $cr = Invoke-CleanTarget $t; $sh.Cleaned += $cr.Cleaned; $sh.Errors += $cr.Errors
                    }
                    $sh.Status = 'Clearing Recycle Bin...'
                    Invoke-RecycleBinClear | Out-Null
                }
                catch { $sh.Error = $_.Exception.Message }
                $sh.Done = $true
            })
        $script:simplePs.BeginInvoke() | Out-Null
        $script:simpleTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:simpleTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        $script:simpleTimer.Add_Tick({
                try {
                    $pct = if ($script:simpleSh.Total -gt 0) { [math]::Round($script:simpleSh.Current / $script:simpleSh.Total * 400) } else { 0 }
                    $ui['simpleProgressFill'].Width = [math]::Min(400, $pct)
                    $ui['lblSimpleProgress'].Text = if ($script:simpleSh.Total -gt 0) { "$($script:simpleSh.Status) ($($script:simpleSh.Current)/$($script:simpleSh.Total))" } else { 'Preparing...' }
                    if ($script:simpleSh.Done) {
                        $script:simpleTimer.Stop()
                        try { $script:simplePs.Stop(); $script:simplePs.Dispose(); $script:simpleRs.Close(); $script:simpleRs.Dispose() } catch {}
                        $ui['simpleProgressFill'].Width = 400
                        if ($script:simpleSh.Error) {
                            $ui['lblSimpleResult'].Text = "Error: $($script:simpleSh.Error)"; $ui['lblSimpleResult'].Foreground = MkColor '#ef4444'
                        }
                        else {
                            $ui['lblSimpleResult'].Text = "Cleaned $(FmtSize $script:simpleSh.Cleaned)!"; $ui['lblSimpleResult'].Foreground = MkColor '#34d399'
                        }
                        $elapsed = [math]::Round(([DateTime]::Now - $script:simpleSh.StartTime).TotalSeconds)
                        $ui['lblSimpleProgress'].Text = "Done in ${elapsed}s"
                        Update-DiskInfo; $ui['btnSimpleClean'].Content = 'Clean My Disk'; $script:simpleCleaning = $false
                    }
                }
                catch { $script:simpleTimer.Stop(); $ui['lblSimpleResult'].Text = "Error: $($_.Exception.Message)"; $ui['lblSimpleResult'].Foreground = MkColor '#ef4444'; $ui['btnSimpleClean'].Content = 'Clean My Disk'; $script:simpleCleaning = $false }
            })
        $script:simpleTimer.Start()
    })

Switch-AppMode; Update-DiskInfo

# ===== TITLE BAR =====
$ui['titleBar'].Add_MouseLeftButtonDown({ $Window.DragMove() })
$ui['btnMin'].Add_Click({ $Window.WindowState = 'Minimized' })
$ui['btnMax'].Add_Click({ if ($Window.WindowState -eq 'Maximized') { $Window.WindowState = 'Normal' }else { $Window.WindowState = 'Maximized' } })
$ui['btnClose'].Add_Click({ $Window.Close() })

# ===== CLEAN TAB: Checkbox Model =====
Add-Type -Language CSharp @"
using System.ComponentModel;
public class CleanItem : INotifyPropertyChanged {
    private bool _isChecked = true;
    public bool IsChecked { get { return _isChecked; } set { _isChecked = value; OnPropertyChanged("IsChecked"); } }
    public string Name { get; set; }
    public string Desc { get; set; }
    public long Size { get; set; }
    public string SizeText { get; set; }
    public int FileCount { get; set; }
    public string Path { get; set; }
    public string Pattern { get; set; }
    public bool Admin { get; set; }
    public event PropertyChangedEventHandler PropertyChanged;
    protected void OnPropertyChanged(string name) { if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(name)); }
}
"@

$script:cleanItems = New-Object System.Collections.ObjectModel.ObservableCollection[CleanItem]

function Load-CleanTargets {
    $script:cleanItems.Clear()
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $targets = Get-SystemJunkTargets -AdminMode:$isAdmin
    foreach ($t in $targets) {
        $item = New-Object CleanItem
        $item.Name = $t.Name; $item.Desc = $t.Desc; $item.Path = $t.Path; $item.Pattern = $t.Pattern
        $item.Admin = if ($t.Admin) { $true }else { $false }; $item.IsChecked = $true
        $script:cleanItems.Add($item)
    }
    $ui['gridClean'].ItemsSource = $script:cleanItems
    $ui['lblCleanTotal'].Text = "$($script:cleanItems.Count) categories found"
}

$script:analyzing = $false
$ui['btnAnalyze'].Add_Click({
        if ($script:analyzing) {
            # STOP
            $script:analyzeTimer.Stop()
            try { $script:analyzePs.Stop(); $script:analyzePs.Dispose(); $script:analyzeRs.Close(); $script:analyzeRs.Dispose() } catch {}
            $ui['lblCleanTotal'].Text = 'Analysis stopped'; $ui['lblCleanProgress'].Text = ''
            $ui['btnAnalyze'].Content = 'Analyze'; $script:analyzing = $false
            return
        }
        # START
        $script:analyzing = $true; $ui['btnAnalyze'].Content = 'Stop'
        $ui['lblCleanTotal'].Text = 'Analyzing...'
        $ui['cleanProgressFill'].Width = 0; $ui['lblCleanProgress'].Text = ''
        $targetList = @()
        foreach ($item in $script:cleanItems) { $targetList += @{Name = $item.Name; Path = $item.Path; Pattern = $item.Pattern } }
        $script:analyzeSh = [hashtable]::Synchronized(@{Done = $false; Error = $null; Results = @(); Status = 'Starting...'; Current = 0; Total = $targetList.Count })
        $script:analyzeRs = [runspacefactory]::CreateRunspace(); $script:analyzeRs.ApartmentState = 'STA'; $script:analyzeRs.Open()
        $script:analyzeRs.SessionStateProxy.SetVariable('sh', $script:analyzeSh)
        $script:analyzeRs.SessionStateProxy.SetVariable('targets', $targetList)
        $script:analyzeRs.SessionStateProxy.SetVariable('modPath', (Join-Path $PSScriptRoot 'modules'))
        $script:analyzePs = [powershell]::Create(); $script:analyzePs.Runspace = $script:analyzeRs
        [void]$script:analyzePs.AddScript({
                try {
                    . (Join-Path $modPath 'SystemCleaner.ps1')
                    $results = @()
                    for ($i = 0; $i -lt $targets.Count; $i++) {
                        $t = $targets[$i]; $sh.Status = $t.Name; $sh.Current = $i + 1
                        $m = Measure-TargetSize @{Path = $t.Path; Pattern = $t.Pattern }
                        $results += @{Name = $t.Name; Size = $m.Size; Count = $m.Count }
                    }
                    $sh.Results = $results
                }
                catch { $sh.Error = $_.Exception.Message }
                $sh.Done = $true
            })
        $script:analyzePs.BeginInvoke() | Out-Null
        $script:analyzeTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:analyzeTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        $script:analyzeTimer.Add_Tick({
                try {
                    $pct = if ($script:analyzeSh.Total -gt 0) { [math]::Round($script:analyzeSh.Current / $script:analyzeSh.Total * 300) } else { 0 }
                    $ui['cleanProgressFill'].Width = [math]::Min(300, $pct)
                    $ui['lblCleanTotal'].Text = "Analyzing... $($script:analyzeSh.Status) ($($script:analyzeSh.Current)/$($script:analyzeSh.Total))"
                    $ui['lblCleanProgress'].Text = if ($script:analyzeSh.Total -gt 0) { "$($script:analyzeSh.Status)" } else { 'Preparing...' }
                    if ($script:analyzeSh.Done) {
                        $script:analyzeTimer.Stop()
                        try { $script:analyzePs.Stop(); $script:analyzePs.Dispose(); $script:analyzeRs.Close(); $script:analyzeRs.Dispose() } catch {}
                        if ($script:analyzeSh.Error) { $ui['lblCleanTotal'].Text = "Error: $($script:analyzeSh.Error)"; $ui['lblCleanProgress'].Text = '' }
                        else {
                            $totalSize = [long]0; $totalFiles = 0
                            foreach ($r in $script:analyzeSh.Results) {
                                $match = $script:cleanItems | Where-Object { $_.Name -eq $r.Name } | Select-Object -First 1
                                if ($match) { $match.Size = $r.Size; $match.SizeText = FmtSize $r.Size; $match.FileCount = $r.Count }
                                $totalSize += $r.Size; $totalFiles += $r.Count
                            }
                            $ui['gridClean'].Items.Refresh()
                            $ui['lblCleanTotal'].Text = "Total: $(FmtSize $totalSize) in $totalFiles files"
                            $ui['lblCleanProgress'].Text = "Analysis complete"
                        }
                        $ui['cleanProgressFill'].Width = 300
                        $ui['btnAnalyze'].Content = 'Analyze'; $script:analyzing = $false
                    }
                }
                catch { $script:analyzeTimer.Stop(); $ui['lblCleanTotal'].Text = "Error: $($_.Exception.Message)"; $ui['btnAnalyze'].Content = 'Analyze'; $script:analyzing = $false; $ui['lblCleanProgress'].Text = '' }
            })
        $script:analyzeTimer.Start()
    })

$ui['btnSelectAll'].Add_Click({ foreach ($item in $script:cleanItems) { $item.IsChecked = $true }; $ui['gridClean'].Items.Refresh() })
$ui['btnDeselectAll'].Add_Click({ foreach ($item in $script:cleanItems) { $item.IsChecked = $false }; $ui['gridClean'].Items.Refresh() })

$ui['btnCleanChecked'].Add_Click({
        $checked = @($script:cleanItems | Where-Object { $_.IsChecked })
        if ($checked.Count -eq 0) { Show-Dialog 'No items selected.' 'Nothing Selected' 'OK' 'Warning'; return }
        if ((Show-Dialog "Clean $($checked.Count) categories?`nThis only removes temp files, caches and crash dumps.`nYour personal files are never touched." 'Confirm Clean' 'YesNo' 'Info') -ne 'Yes') { return }
        $ui['btnCleanChecked'].IsEnabled = $false; $ui['cleanProgressFill'].Width = 0; $ui['lblCleanProgress'].Text = 'Cleaning...'
        $targetList = @(); foreach ($item in $checked) { $targetList += @{Name = $item.Name; Path = $item.Path; Pattern = $item.Pattern } }
        $script:cleanSh = [hashtable]::Synchronized(@{Done = $false; Error = $null; Cleaned = [long]0; Errors = 0; Current = 0; Total = $targetList.Count; Status = 'Starting...' })
        $script:cleanRs = [runspacefactory]::CreateRunspace(); $script:cleanRs.ApartmentState = 'STA'; $script:cleanRs.Open()
        $script:cleanRs.SessionStateProxy.SetVariable('sh', $script:cleanSh)
        $script:cleanRs.SessionStateProxy.SetVariable('targets', $targetList)
        $script:cleanRs.SessionStateProxy.SetVariable('modPath', (Join-Path $PSScriptRoot 'modules'))
        $script:cleanPs = [powershell]::Create(); $script:cleanPs.Runspace = $script:cleanRs
        [void]$script:cleanPs.AddScript({
                try {
                    . (Join-Path $modPath 'SystemCleaner.ps1')
                    for ($i = 0; $i -lt $targets.Count; $i++) {
                        $t = $targets[$i]; $sh.Status = $t.Name; $sh.Current = $i + 1
                        $cr = Invoke-CleanTarget @{Path = $t.Path; Pattern = $t.Pattern }
                        $sh.Cleaned += $cr.Cleaned; $sh.Errors += $cr.Errors
                    }
                    $sh.Status = 'Clearing Recycle Bin...'
                    Invoke-RecycleBinClear | Out-Null
                }
                catch { $sh.Error = $_.Exception.Message }
                $sh.Done = $true
            })
        $script:cleanPs.BeginInvoke() | Out-Null
        $script:cleanTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:cleanTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        $script:cleanTimer.Add_Tick({
                try {
                    $pct = if ($script:cleanSh.Total -gt 0) { [math]::Round($script:cleanSh.Current / $script:cleanSh.Total * 300) } else { 0 }
                    $ui['cleanProgressFill'].Width = [math]::Min(300, $pct)
                    $ui['lblCleanProgress'].Text = if ($script:cleanSh.Total -gt 0) { "$($script:cleanSh.Status) ($($script:cleanSh.Current)/$($script:cleanSh.Total))" } else { 'Preparing...' }
                    if ($script:cleanSh.Done) {
                        $script:cleanTimer.Stop()
                        try { $script:cleanPs.Stop(); $script:cleanPs.Dispose(); $script:cleanRs.Close(); $script:cleanRs.Dispose() } catch {}
                        $ui['cleanProgressFill'].Width = 300; $ui['btnCleanChecked'].IsEnabled = $true
                        $ui['lblCleanProgress'].Text = "Freed $(FmtSize $script:cleanSh.Cleaned)"
                        Show-Dialog "Freed $(FmtSize $script:cleanSh.Cleaned)!`n$($script:cleanSh.Errors) files locked/skipped." 'Complete' 'OK' 'Success'
                        $ui['btnAnalyze'].RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
                        Update-DiskInfo
                    }
                }
                catch { $script:cleanTimer.Stop(); $ui['lblCleanProgress'].Text = "Error: $($_.Exception.Message)"; $ui['btnCleanChecked'].IsEnabled = $true }
            })
        $script:cleanTimer.Start()
    })

Load-CleanTargets

# ===== DEV CLEANUP TAB (async) =====
$script:devScanning = $false
$ui['btnDevScan'].Add_Click({
        if ($script:devScanning) {
            # STOP
            $script:devTimer.Stop()
            try { $script:devPs.Stop(); $script:devPs.Dispose(); $script:devRs.Close(); $script:devRs.Dispose() } catch {}
            $ui['lblDevInfo'].Text = 'Scan stopped'; $ui['lblDevProgress'].Text = ''
            $ui['btnDevScan'].Content = 'Scan'; $script:devScanning = $false
            return
        }
        # START SCAN
        $script:devScanning = $true; $ui['btnDevScan'].Content = 'Stop'
        $ui['lblDevInfo'].Text = 'Scanning...'; $ui['devProgressFill'].Width = 0; $ui['lblDevProgress'].Text = ''
        $scanPaths = @($env:USERPROFILE)
        @((Join-Path $env:USERPROFILE 'source\repos'), (Join-Path $env:USERPROFILE 'Projects'), (Join-Path $env:USERPROFILE 'Documents'), 'C:\Projects', 'C:\Dev', 'C:\MyApps') |
        ForEach-Object { if ((Test-Path $_) -and $scanPaths -notcontains $_) { $scanPaths += $_ } }
        $script:devSh = [hashtable]::Synchronized(@{Done = $false; Error = $null; Results = $null; Status = 'Starting...'; PathIndex = 0; PathCount = $scanPaths.Count })
        $script:devRs = [runspacefactory]::CreateRunspace(); $script:devRs.ApartmentState = 'STA'; $script:devRs.Open()
        $script:devRs.SessionStateProxy.SetVariable('devSh', $script:devSh)
        $script:devRs.SessionStateProxy.SetVariable('scanPaths', $scanPaths)
        $script:devRs.SessionStateProxy.SetVariable('modPath', (Join-Path $PSScriptRoot 'modules'))
        $script:devPs = [powershell]::Create(); $script:devPs.Runspace = $script:devRs
        [void]$script:devPs.AddScript({
                try {
                    . (Join-Path $modPath 'Scanner.ps1'); . (Join-Path $modPath 'DevClean.ps1')
                    $all = [System.Collections.ArrayList]::new()
                    for ($pi = 0; $pi -lt $scanPaths.Count; $pi++) {
                        $path = $scanPaths[$pi]; $devSh.PathIndex = $pi + 1; $devSh.Status = "Scanning: $path"
                        $results = Invoke-DevScan -ScanPath $path -MaxDepth 5 -Shared $devSh; foreach ($r in $results) { [void]$all.Add($r) }
                    }
                    $devSh.Results = $all | Sort-Object FullPath -Unique | Sort-Object Size -Descending
                }
                catch { $devSh.Error = $_.Exception.Message }
                $devSh.Done = $true
            })
        $script:devPs.BeginInvoke() | Out-Null
        $script:devTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:devTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        $script:devTimer.Add_Tick({
                try {
                    $pct = if ($script:devSh.PathCount -gt 0) { [math]::Round($script:devSh.PathIndex / $script:devSh.PathCount * 300) } else { 0 }
                    $ui['devProgressFill'].Width = [math]::Min(300, $pct)
                    $ui['lblDevInfo'].Text = $script:devSh.Status
                    $ui['lblDevProgress'].Text = if ($script:devSh.PathCount -gt 0) { "$($script:devSh.PathIndex)/$($script:devSh.PathCount) paths" } else { '' }
                    if ($script:devSh.Done) {
                        $script:devTimer.Stop()
                        try { $script:devPs.Stop(); $script:devPs.Dispose(); $script:devRs.Close(); $script:devRs.Dispose() }catch {}
                        if ($script:devSh.Error) { $ui['lblDevInfo'].Text = "Error: $($script:devSh.Error)" }
                        else { $r = $script:devSh.Results; $ts = ($r | Measure-Object Size -Sum).Sum; if ($null -eq $ts) { $ts = 0 }; $ui['gridDev'].ItemsSource = $r; $ui['lblDevInfo'].Text = "$($r.Count) artifacts ($(FmtSize $ts))" }
                        $ui['devProgressFill'].Width = 300; $ui['lblDevProgress'].Text = 'Complete'
                        $ui['btnDevScan'].Content = 'Scan'; $script:devScanning = $false
                    }
                }
                catch { $script:devTimer.Stop(); $ui['lblDevInfo'].Text = "Error: $($_.Exception.Message)"; $ui['btnDevScan'].Content = 'Scan'; $script:devScanning = $false }
            })
        $script:devTimer.Start()
    })
$ui['btnDevClean'].Add_Click({
        $sel = @($ui['gridDev'].SelectedItems); if ($sel.Count -eq 0) { Show-Dialog 'Select artifacts to clean.' 'Nothing Selected' 'OK' 'Warning'; return }
        $ts = ($sel | Measure-Object Size -Sum -EA SilentlyContinue).Sum
        if ((Show-Dialog "Delete $($sel.Count) dev artifacts ($(FmtSize $ts))?`nFolders will be moved to Recycle Bin when possible." 'Confirm' 'YesNo' 'Warning') -ne 'Yes') { return }
        $ok = 0; $fail = 0; $skip = 0
        foreach ($item in $sel) {
            try {
                if (-not (Test-Path $item.FullPath)) { continue }
                $result = Invoke-SafeDelete -Path $item.FullPath -UseRecycleBin $true
                if ($result.Deleted) { $ok++ } else { $skip++ }
            }
            catch { $fail++ }
        }
        $details = "Deleted: $ok"
        if ($skip -gt 0) { $details += ", Protected: $skip" }
        if ($fail -gt 0) { $details += ", Failed: $fail" }
        Show-Dialog "$details of $($sel.Count) artifacts." 'Complete' 'OK' 'Success'
    })

# ===== DISK ANALYZER (async) =====
$ui['lblPath'].Text = $env:USERPROFILE
$script:analyzerScanned = $false

function Start-FolderScan {
    param([string]$ScanPath)
    if ($AppArgs.IsScanning) { return }
    if (-not $ScanPath -or -not (Test-Path $ScanPath)) { return }
    $AppArgs.IsScanning = $true; $ui['btnScan'].Content = 'Stop'
    $ui['lblAnalyzerProgress'].Text = "Scanning $ScanPath ..."; $ui['analyzerProgressFill'].Width = 0
    $script:scanSh = [hashtable]::Synchronized(@{Window = $Window; UI = $ui; Done = $false; Error = $null; Results = $null })
    $script:scanRs = [runspacefactory]::CreateRunspace(); $script:scanRs.ApartmentState = "STA"; $script:scanRs.Open()
    $script:scanRs.SessionStateProxy.SetVariable('sh', $script:scanSh); $script:scanRs.SessionStateProxy.SetVariable('sp', $ScanPath); $script:scanRs.SessionStateProxy.SetVariable('modPath', (Join-Path $PSScriptRoot 'modules'))
    $script:scanPs = [powershell]::Create(); $script:scanPs.Runspace = $script:scanRs
    [void]$script:scanPs.AddScript({ try { . (Join-Path $modPath 'Scanner.ps1'); . (Join-Path $modPath 'BrokenFiles.ps1'); $r = Invoke-DiskScan -ScanPath $sp -Shared $sh; $r.Broken = @(Find-BrokenFiles -ScanFiles $r.Files); $sh.Results = $r }catch { $sh.Error = $_.Exception.Message }; $sh.Done = $true })
    $script:scanPs.BeginInvoke() | Out-Null
    $script:scanTimer = New-Object System.Windows.Threading.DispatcherTimer; $script:scanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $script:scanTimer.Add_Tick({ if ($script:scanSh.Done) {
                $script:scanTimer.Stop(); try { $script:scanPs.Stop(); $script:scanPs.Dispose(); $script:scanRs.Close(); $script:scanRs.Dispose() }catch {}
                $AppArgs.IsScanning = $false; $ui['btnScan'].Content = 'Scan'
                if ($script:scanSh.Error) { $ui['lblAnalyzerProgress'].Text = "Error: $($script:scanSh.Error)"; return }
                $r = $script:scanSh.Results; $AppArgs.ScanResults = $r; 
                $ui['statFiles'].Text = $r.FC; $ui['statSize'].Text = FmtSize $r.Total; $ui['statLarge'].Text = $r.Large.Count; $ui['statDup'].Text = $r.Dups.Count; $ui['statJunk'].Text = $r.Junk.Count; $ui['statOld'].Text = $r.OldFiles.Count
                $ui['gridLarge'].ItemsSource = $r.Large; $ui['gridDup'].ItemsSource = $r.Dups; $ui['gridJunk'].ItemsSource = $r.Junk; $ui['gridAge'].ItemsSource = ($r.OldFiles | Select-Object -First 200); $ui['gridEmpty'].ItemsSource = $r.Empty; $ui['gridBroken'].ItemsSource = $r.Broken
                $ui['lblAnalyzerProgress'].Text = "$($r.FC) files, $(FmtSize $r.Total)"; $ui['analyzerProgressFill'].Width = 400; $ui['btnExport'].IsEnabled = $true; $script:analyzerScanned = $true
                try { $recs = Get-SmartRecommendations $r; if ($recs -and $recs.Count -gt 0) { $topRec = $recs | Sort-Object Savings -Descending | Select-Object -First 1; $ui['lblAnalyzerProgress'].Text += " | Tip: $($topRec.Message)" } } catch {}
                try { $sp2 = $ui['lblPath'].Text; if ($sp2) { Save-ScanSnapshot $r $sp2 } } catch {}
            } })
    $script:scanTimer.Start()
}

function Stop-FolderScan {
    if (-not $AppArgs.IsScanning) { return }
    $script:scanTimer.Stop()
    try { $script:scanPs.Stop(); $script:scanPs.Dispose(); $script:scanRs.Close(); $script:scanRs.Dispose() } catch {}
    $AppArgs.IsScanning = $false; $ui['btnScan'].Content = 'Scan'
    $ui['lblAnalyzerProgress'].Text = 'Scan stopped'
}

$ui['btnBrowse'].Add_Click({ $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = 'Select folder'; if ($dlg.ShowDialog() -eq 'OK') { $ui['lblPath'].Text = $dlg.SelectedPath; Start-FolderScan $dlg.SelectedPath } })
$ui['btnScan'].Add_Click({ if ($AppArgs.IsScanning) { Stop-FolderScan } else { Start-FolderScan $ui['lblPath'].Text } })




function Remove-SafeSelectedGrid($grid, $msg, [switch]$IsDupGrid) {
    $sel = @($grid.SelectedItems); if ($sel.Count -eq 0) { Show-Dialog 'Select items first.' 'Nothing Selected' 'OK' 'Warning'; return }

    # Duplicate safety: ensure at least one copy per group survives
    if ($IsDupGrid) {
        $delGroups = $sel | Where-Object { $_.GroupId } | Group-Object GroupId
        foreach ($g in $delGroups) {
            $allInGroup = @($grid.Items | Where-Object { $_.GroupId -eq $g.Name })
            $notSelected = @($allInGroup | Where-Object { $sel.FullPath -notcontains $_.FullPath })
            if ($notSelected.Count -eq 0) {
                Show-Dialog "Group $($g.Name): ALL copies selected!`nKeep at least one copy to avoid data loss." 'Safety Guard' 'OK' 'Warning'
                return
            }
        }
    }

    $ts = ($sel | Measure-Object Size -Sum -EA SilentlyContinue).Sum
    if ((Show-Dialog "Delete $($sel.Count) items ($(FmtSize $ts))?`n$msg`nFiles go to Recycle Bin when possible." 'Confirm' 'YesNo' 'Warning') -ne 'Yes') { return }
    $ok = 0; $fail = 0; $skip = 0
    foreach ($item in $sel) {
        try {
            if (-not (Test-Path $item.FullPath)) { continue }
            $result = Invoke-SafeDelete -Path $item.FullPath -ScanDir '' -UseRecycleBin $true
            if ($result.Deleted) { $ok++ } else { $skip++ }
        }
        catch { $fail++ }
    }
    $details = "Deleted: $ok"
    if ($skip -gt 0) { $details += ", Protected: $skip" }
    if ($fail -gt 0) { $details += ", Failed: $fail" }
    Show-Dialog "$details of $($sel.Count) items." 'Complete' 'OK' 'Success'
}
$ui['btnDL'].Add_Click({ Remove-SafeSelectedGrid $ui['gridLarge'] 'Large files will be moved to Recycle Bin.' })
$ui['btnDD'].Add_Click({ Remove-SafeSelectedGrid $ui['gridDup'] 'Keep at least one copy!' -IsDupGrid })
$ui['btnDJ'].Add_Click({ Remove-SafeSelectedGrid $ui['gridJunk'] 'Junk files will be moved to Recycle Bin.' })
$ui['btnDA'].Add_Click({ Remove-SafeSelectedGrid $ui['gridAge'] 'Old files will be moved to Recycle Bin.' })
$ui['btnDE'].Add_Click({
        $sel = @($ui['gridEmpty'].SelectedItems); if ($sel.Count -eq 0) { Show-Dialog 'Select folders.' 'Nothing' 'OK' 'Warning'; return }
        if ((Show-Dialog "Remove $($sel.Count) empty folders?" 'Confirm' 'YesNo' 'Warning') -ne 'Yes') { return }
        $ok = 0; $skip = 0
        foreach ($f in $sel) {
            try {
                $result = Invoke-SafeDelete -Path $f.FullPath -UseRecycleBin $false
                if ($result.Deleted) { $ok++ } else { $skip++ }
            }
            catch {}
        }
        $msg = "Removed $ok folders."
        if ($skip -gt 0) { $msg += " $skip protected." }
        Show-Dialog $msg 'Complete' 'OK' 'Success'
    })
$ui['btnDB'].Add_Click({ Remove-SafeSelectedGrid $ui['gridBroken'] 'Broken files will be moved to Recycle Bin.' })
$ui['btnOL'].Add_Click({ $sel = $ui['gridLarge'].SelectedItem; if ($sel) { Start-Process explorer.exe "/select,`"$($sel.FullPath)`"" } })
$ui['btnExport'].Add_Click({ if (-not $AppArgs.ScanResults) { Show-Dialog 'Scan first.' 'No Data' 'OK' 'Warning'; return }; $dlg = New-Object System.Windows.Forms.SaveFileDialog; $dlg.Filter = 'CSV|*.csv'; $dlg.FileName = 'DiskCleaner_Export.csv'; if ($dlg.ShowDialog() -eq 'OK') { $AppArgs.ScanResults.Files | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8; Show-Dialog "Exported to:`n$($dlg.FileName)" 'Export' 'OK' 'Success' } })



# ===== ORGANIZE TAB =====
$script:orgMode = 'ByType'
$script:orgPlan = $null
$script:aiEnabled = $false

# Sync AI status across Settings + Organize
function Update-AIStatus {
    if ($script:aiEnabled) {
        $ui['btnOrgAI'].Content = '[AI] On'; $ui['btnOrgAI'].Foreground = MkColor '#34d399'
        $ui['lblAIStatus'].Text = '[v] Enabled'; $ui['lblAIStatus'].Foreground = MkColor '#34d399'
    }
    else {
        $ui['btnOrgAI'].Content = '[AI] Off'; $ui['btnOrgAI'].Foreground = MkColor '#3d5470'
        $ui['lblAIStatus'].Text = '[x] Disabled'; $ui['lblAIStatus'].Foreground = MkColor '#ef4444'
    }
}

# Load AI config on startup
try {
    $aiCfg = Get-AIConfig
    if ($aiCfg.Enabled -and $aiCfg.ApiKey) {
        $script:aiEnabled = $true
        $ui['txtApiKey'].Text = $aiCfg.ApiKey
    }
    Update-AIStatus
}
catch {}

# AI toggle button (Organize tab)
$ui['btnOrgAI'].Add_Click({
        $script:aiEnabled = -not $script:aiEnabled
        $cfg = Get-AIConfig; $cfg.Enabled = $script:aiEnabled; Save-AIConfig $cfg
        Update-AIStatus
        if ($script:aiEnabled -and -not $cfg.ApiKey) {
            Show-Dialog "No API key set!`nGo to Settings tab to get a free key from Groq." 'API Key Required' 'OK' 'Warning'
            $script:aiEnabled = $false; Update-AIStatus
        }
    })

# Save API key (Settings tab)
$ui['btnApiKeySave'].Add_Click({
        $key = $ui['txtApiKey'].Text.Trim()
        if ($key.Length -lt 10) { Show-Dialog "Please enter a valid API key.`nGet one free at: console.groq.com/keys" 'Invalid Key' 'OK' 'Warning'; return }
        $cfg = Get-AIConfig; $cfg.ApiKey = $key; $cfg.Enabled = $true; Save-AIConfig $cfg
        $script:aiEnabled = $true; Update-AIStatus
        Show-Dialog "API key saved! AI classification is now active.`nKey is stored locally only, never sent to anyone." 'AI Enabled' 'OK' 'Success'
    })

# Test API key (Settings tab)
$ui['btnApiKeyTest'].Add_Click({
        $key = $ui['txtApiKey'].Text.Trim()
        if ($key.Length -lt 10) { Show-Dialog 'Enter an API key first.' 'No Key' 'OK' 'Warning'; return }
        $ui['lblAIStatus'].Text = 'Testing...'; $ui['lblAIStatus'].Foreground = MkColor '#f59e0b'
        [System.Windows.Forms.Application]::DoEvents()
        try {
            $body = @{ model = 'llama-3.1-8b-instant'; messages = @(@{ role = 'user'; content = 'Reply OK' }); max_tokens = 5 } | ConvertTo-Json -Depth 3
            $headers = @{ 'Authorization' = "Bearer $key"; 'Content-Type' = 'application/json' }
            $null = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/chat/completions' -Method Post -Body $body -Headers $headers -TimeoutSec 10
            $ui['lblAIStatus'].Text = '[v] Test OK - API key hop le!'; $ui['lblAIStatus'].Foreground = MkColor '#34d399'
        }
        catch {
            $ui['lblAIStatus'].Text = '[x] Test FAIL - Key khong hop le'; $ui['lblAIStatus'].Foreground = MkColor '#ef4444'
        }
    })

# Open Groq console (Settings tab)
$ui['btnOpenGroq'].Add_Click({ Start-Process 'https://console.groq.com/keys' })

# Quick folder helpers
function Set-OrgFolder([string]$path) { $ui['lblOrgPath'].Text = $path; $ui['lblOrgPath'].Foreground = MkColor '#c8d6e5' }
$ui['btnOrgDesktop'].Add_Click({ Set-OrgFolder ([Environment]::GetFolderPath('Desktop')) })
$ui['btnOrgDownloads'].Add_Click({ Set-OrgFolder (Join-Path $env:USERPROFILE 'Downloads') })
$ui['btnOrgDocuments'].Add_Click({ Set-OrgFolder ([Environment]::GetFolderPath('MyDocuments')) })
$ui['btnOrgBrowse'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select folder to organize'
        if ($dlg.ShowDialog() -eq 'OK') { Set-OrgFolder $dlg.SelectedPath }
    })

$ui['btnOrgByType'].Add_Click({ $script:orgMode = 'ByType'; $ui['btnOrgByType'].Background = MkColor '#2563eb'; $ui['btnOrgByDate'].Background = MkColor '#1e293b'; $ui['btnOrgBySize'].Background = MkColor '#1e293b' })
$ui['btnOrgByDate'].Add_Click({ $script:orgMode = 'ByDate'; $ui['btnOrgByDate'].Background = MkColor '#2563eb'; $ui['btnOrgByType'].Background = MkColor '#1e293b'; $ui['btnOrgBySize'].Background = MkColor '#1e293b' })
$ui['btnOrgBySize'].Add_Click({ $script:orgMode = 'BySize'; $ui['btnOrgBySize'].Background = MkColor '#2563eb'; $ui['btnOrgByType'].Background = MkColor '#1e293b'; $ui['btnOrgByDate'].Background = MkColor '#1e293b' })

$ui['btnOrgPreview'].Add_Click({
        $folder = $ui['lblOrgPath'].Text
        if (-not $folder -or -not (Test-Path $folder)) { Show-Dialog 'Select a valid folder first.' 'No Folder' 'OK' 'Warning'; return }
        $ui['btnOrgPreview'].Content = 'Stop'; $ui['lblOrgStatus'].Text = 'Scanning...'
        $ui['orgProgressFill'].Width = 0; $ui['lblOrgProgress'].Text = ''
        [System.Windows.Forms.Application]::DoEvents()
        # Exclude .lnk and .url on Desktop (shortcuts for quick access)
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $excludeExts = @()
        if ($folder -eq $desktopPath) { $excludeExts = @('.lnk', '.url') }
        $result = Get-OrganizePlan -FolderPath $folder -Mode $script:orgMode -SkipHidden -SkipSystem -ExcludeExtensions $excludeExts
        $script:orgPlan = $result.Plan
        # AI re-classify 'Other' files if enabled
        if ($script:aiEnabled -and $result.Plan.Count -gt 0) {
            $otherFiles = @($result.Plan | Where-Object { $_.Category -eq 'Other' })
            if ($otherFiles.Count -gt 0) {
                $ui['lblOrgStatus'].Text = "AI classifying $($otherFiles.Count) files..."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $fileInfos = $otherFiles | ForEach-Object { [System.IO.FileInfo]::new($_.Source) }
                    $aiResults = Invoke-AIClassify -Files $fileInfos
                    if ($aiResults -and $aiResults.Count -gt 0) {
                        foreach ($item in $script:orgPlan) {
                            if ($item.Category -eq 'Other' -and $aiResults.ContainsKey($item.Source)) {
                                $ai = $aiResults[$item.Source]
                                $item.Category = "$($ai.Category) (AI)"
                                $item.DestFolder = $ai.Category
                                $item.Destination = Join-Path $folder (Join-Path $ai.Category $item.Name)
                            }
                        }
                    }
                }
                catch {}
            }
        }
        $ui['gridOrganize'].ItemsSource = $script:orgPlan
        $totalSize = ($result.Plan | Measure-Object Size -Sum).Sum
        $ui['statOrgFiles'].Text = "$($result.Total)"
        $ui['statOrgCats'].Text = "$($result.Stats.Count)"
        $ui['statOrgSize'].Text = FmtSize $totalSize
        $ui['btnOrgExecute'].IsEnabled = $result.Total -gt 0
        $ui['orgProgressFill'].Width = 300; $ui['lblOrgProgress'].Text = 'Done'
        $aiTag = if ($script:aiEnabled) { ' + AI' } else { '' }
        $ui['lblOrgStatus'].Text = "$($result.Total) files to organize into $($result.Stats.Count) categories$aiTag"
        if ($folder -eq $desktopPath) { $ui['lblOrgStatus'].Text += ' (shortcuts excluded)' }
        if ($result.HasSensitive) { $ui['lblOrgStatus'].Text += ' (! sensitive data detected)'; $ui['lblOrgStatus'].Foreground = MkColor '#f59e0b' }
        else { $ui['lblOrgStatus'].Foreground = MkColor '#6b7f99' }
        $ui['btnOrgPreview'].Content = 'Preview'
    })

$ui['btnOrgExecute'].Add_Click({
        if (-not $script:orgPlan -or $script:orgPlan.Count -eq 0) { return }
        $folder = $ui['lblOrgPath'].Text
        if ((Show-Dialog "Move $($script:orgPlan.Count) files into categorized folders?`nOriginal locations are logged for undo." 'Confirm Organize' 'YesNo' 'Warning') -ne 'Yes') { return }
        $ui['btnOrgExecute'].IsEnabled = $false
        $result = Invoke-OrganizeFiles -Plan $script:orgPlan -FolderPath $folder
        $ui['lblOrgStatus'].Text = "Done! Moved $($result.Moved) files ($($result.Errors) errors)"
        $ui['lblOrgStatus'].Foreground = if ($result.Errors -eq 0) { MkColor '#34d399' }else { MkColor '#f59e0b' }
        $script:orgPlan = $null
        $ui['gridOrganize'].ItemsSource = $null
        $ui['statOrgFiles'].Text = '--'; $ui['statOrgCats'].Text = '--'; $ui['statOrgSize'].Text = '--'
    })

$ui['btnOrgUndo'].Add_Click({
        if ((Show-Dialog 'Undo the last organize operation?`nFiles will be moved back to original locations.' 'Confirm Undo' 'YesNo' 'Info') -ne 'Yes') { return }
        $result = Invoke-UndoOrganize
        Show-Dialog $result.Message 'Undo Result' 'OK' $(if ($result.Errors -eq 0) { 'Success' }else { 'Warning' })
    })

# ===== QUICK ACCESS: Context Menu + Double-Click for all grids =====
function New-DarkContextMenu {
    $cm = New-Object System.Windows.Controls.ContextMenu
    $cm.Background = MkColor '#0e1726'; $cm.BorderBrush = MkColor '#1e2d42'; $cm.BorderThickness = '1'; $cm.Foreground = MkColor '#c8d6e5'
    return $cm
}
function New-DarkMenuItem([string]$Header, [string]$Icon) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = "$Icon  $Header"; $mi.Foreground = MkColor '#c8d6e5'; $mi.FontSize = 12
    $mi.Background = MkColor '#0e1726'; $mi.BorderThickness = '0'
    return $mi
}

function Add-GridContextMenu($grid, [string]$pathProp = 'FullPath') {
    $cm = New-DarkContextMenu
    $miOpen = New-DarkMenuItem 'Open File' ([char]0xE8E5)
    $miOpen.Tag = @{ Grid = $grid; Prop = $pathProp }
    $miOpen.Add_Click({ param($s, $e); $item = $s.Tag.Grid.SelectedItem; if ($item) { $p = $item.($s.Tag.Prop); if ($p -and (Test-Path $p)) { Start-Process $p } } })
    $miLoc = New-DarkMenuItem 'Open Location' ([char]0xE838)
    $miLoc.Tag = @{ Grid = $grid; Prop = $pathProp }
    $miLoc.Add_Click({ param($s, $e); $item = $s.Tag.Grid.SelectedItem; if ($item) { $p = $item.($s.Tag.Prop); if ($p -and (Test-Path $p)) { Start-Process explorer.exe "/select,`"$p`"" } } })
    [void]$cm.Items.Add($miOpen); [void]$cm.Items.Add($miLoc)
    $grid.ContextMenu = $cm
    $grid.Add_MouseDoubleClick({
            param($s, $e)
            $item = $s.SelectedItem
            if ($item) {
                $p = $null
                if ($item.PSObject.Properties['FullPath']) { $p = $item.FullPath }
                elseif ($item.PSObject.Properties['Path']) { $p = $item.Path }
                if ($p -and (Test-Path $p)) { Start-Process explorer.exe "/select,`"$p`"" }
            }
        })
}

# Apply to all file grids
Add-GridContextMenu $ui['gridLarge'] 'FullPath'
Add-GridContextMenu $ui['gridDup'] 'FullPath'
Add-GridContextMenu $ui['gridJunk'] 'FullPath'
Add-GridContextMenu $ui['gridAge'] 'FullPath'
Add-GridContextMenu $ui['gridBroken'] 'FullPath'
Add-GridContextMenu $ui['gridEmpty'] 'FullPath'

# Dev grid uses FullPath too (from DevClean results)
$cmDev = New-DarkContextMenu
$miDevLoc = New-DarkMenuItem 'Open Location' ([char]0xE838)
$miDevLoc.Tag = $ui['gridDev']
$miDevLoc.Add_Click({ param($s, $e); $item = $s.Tag.SelectedItem; if ($item -and $item.FullPath -and (Test-Path $item.FullPath)) { Start-Process explorer.exe "/select,`"$($item.FullPath)`"" } })
[void]$cmDev.Items.Add($miDevLoc)
$ui['gridDev'].ContextMenu = $cmDev
$ui['gridDev'].Add_MouseDoubleClick({ param($s, $e); $item = $s.SelectedItem; if ($item -and $item.FullPath -and (Test-Path $item.FullPath)) { Start-Process explorer.exe "/select,`"$($item.FullPath)`"" } })

# ===== RENAME TAB =====
$script:renMode = 'Prefix'
$script:renPlan = @()
$script:renFolder = ''

# Mode toggle buttons
$renModeButtons = @{
    Prefix = $ui['btnRenPrefix']; Suffix = $ui['btnRenSuffix']; Replace = $ui['btnRenReplace']
    Seq = $ui['btnRenSeq']; DatePfx = $ui['btnRenDate']
}
function Set-RenMode([string]$mode) {
    $script:renMode = $mode
    foreach ($k in $renModeButtons.Keys) {
        $renModeButtons[$k].SetValue([System.Windows.Controls.Control]::BackgroundProperty, (MkColor $(if ($k -eq $mode) { '#2563eb' } else { '#131c2b' })))
        $renModeButtons[$k].Foreground = MkColor $(if ($k -eq $mode) { '#ffffff' } else { '#8899b0' })
    }
    # Toggle Find/Replace labels
    switch ($mode) {
        'Prefix' { $ui['txtRenFind'].Tag = 'Prefix text'; $ui['txtRenReplace'].Visibility = 'Collapsed' }
        'Suffix' { $ui['txtRenFind'].Tag = 'Suffix text'; $ui['txtRenReplace'].Visibility = 'Collapsed' }
        'Replace' { $ui['txtRenFind'].Tag = 'Find'; $ui['txtRenReplace'].Visibility = 'Visible' }
        'Seq' { $ui['txtRenFind'].Tag = 'Base name'; $ui['txtRenReplace'].Visibility = 'Collapsed' }
        'DatePfx' { $ui['txtRenFind'].Tag = 'Date format'; $ui['txtRenFind'].Text = 'yyyy-MM-dd'; $ui['txtRenReplace'].Visibility = 'Collapsed' }
    }
}

$ui['btnRenPrefix'].Add_Click({ Set-RenMode 'Prefix' })
$ui['btnRenSuffix'].Add_Click({ Set-RenMode 'Suffix' })
$ui['btnRenReplace'].Add_Click({ Set-RenMode 'Replace' })
$ui['btnRenSeq'].Add_Click({ Set-RenMode 'Seq' })
$ui['btnRenDate'].Add_Click({ Set-RenMode 'DatePfx' })

$ui['btnRenBrowse'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = 'Select folder to rename files'
        if ($dlg.ShowDialog() -eq 'OK') {
            $script:renFolder = $dlg.SelectedPath; $ui['lblRenPath'].Text = $script:renFolder
            $files = @(Get-ChildItem $script:renFolder -File -EA SilentlyContinue)
            $ui['lblRenStatus'].Text = "$($files.Count) files found"
        }
    })

$ui['btnRenPreview'].Add_Click({
        if (-not $script:renFolder -or -not (Test-Path $script:renFolder)) { Show-Dialog 'Select a folder first.' 'No Folder' 'OK' 'Warning'; return }
        $files = @(Get-ChildItem $script:renFolder -File -EA SilentlyContinue)
        if ($files.Count -eq 0) { Show-Dialog 'No files in this folder.' 'Empty' 'OK' 'Warning'; return }
        $text = $ui['txtRenFind'].Text; $replace = $ui['txtRenReplace'].Text
        $script:renPlan = @()
        $counter = 1
        foreach ($f in ($files | Sort-Object Name)) {
            $ext = $f.Extension; $base = $f.BaseName
            $newName = switch ($script:renMode) {
                'Prefix' { if ($text) { "$text$($f.Name)" } else { $f.Name } }
                'Suffix' { if ($text) { "$base$text$ext" } else { $f.Name } }
                'Replace' { if ($text) { $f.Name.Replace($text, $replace) } else { $f.Name } }
                'Seq' { $seqBase = if ($text) { $text } else { 'file' }; "$seqBase`_$($counter.ToString('D3'))$ext" }
                'DatePfx' { $fmt = if ($text) { $text } else { 'yyyy-MM-dd' }; try { "$($f.LastWriteTime.ToString($fmt))_$($f.Name)" } catch { $f.Name } }
            }
            $status = if ($newName -eq $f.Name) { 'Skip' } else { 'Ready' }
            $script:renPlan += [PSCustomObject]@{ OldName = $f.Name; NewName = $newName; FullPath = $f.FullName; Status = $status }
            $counter++
        }
        $ui['gridRename'].ItemsSource = $script:renPlan
        $toRename = @($script:renPlan | Where-Object { $_.Status -eq 'Ready' })
        $ui['lblRenStatus'].Text = "$($toRename.Count) of $($files.Count) files will be renamed"
        $ui['btnRenApply'].IsEnabled = $toRename.Count -gt 0
    })

$ui['btnRenApply'].Add_Click({
        if (-not $script:renPlan -or $script:renPlan.Count -eq 0) { return }
        $toRename = @($script:renPlan | Where-Object { $_.Status -eq 'Ready' })
        if ($toRename.Count -eq 0) { return }
        if ((Show-Dialog "Rename $($toRename.Count) files?`nThis cannot be undone easily." 'Confirm Rename' 'YesNo' 'Warning') -ne 'Yes') { return }
        $ok = 0; $fail = 0
        foreach ($item in $script:renPlan) {
            if ($item.Status -ne 'Ready') { continue }
            try {
                $newPath = Join-Path (Split-Path $item.FullPath) $item.NewName
                if (Test-Path $newPath) { $item.Status = 'Exists'; $fail++; continue }
                Rename-Item -Path $item.FullPath -NewName $item.NewName -EA Stop
                $item.Status = 'Done'; $ok++
            }
            catch { $item.Status = 'Error'; $fail++ }
        }
        $ui['gridRename'].Items.Refresh()
        $ui['lblRenStatus'].Text = "Renamed $ok files. $fail failed."
        $ui['btnRenApply'].IsEnabled = $false
        Show-Dialog "Renamed $ok files successfully.$(if ($fail -gt 0) { "`n$fail files failed." })" 'Complete' 'OK' $(if ($fail -eq 0) { 'Success' } else { 'Warning' })
    })

Set-RenMode 'Prefix'

# ===== ABOUT TAB =====
$ui['btnGithub'].Add_Click({ Start-Process 'https://github.com/anlvdt' })
$ui['btnFacebook'].Add_Click({ Start-Process 'https://www.facebook.com/laptopleandotcom' })
$ui['btnShopee'].Add_Click({ Start-Process 'https://collshp.com/laptopleandotcom?view=storefront' })
# ===== INIT =====
$ui['lblTitle'].ToolTip = 'DiskCleaner Pro v3.0' + "`n" + 'by Le Van An (@anlvdt)'
$null = [Native.Win32]::ShowWindow([Native.Win32]::GetConsoleWindow(), 0)
[void]$Window.ShowDialog()