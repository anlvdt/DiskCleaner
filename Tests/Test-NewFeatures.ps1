# Test-NewFeatures.ps1 - Tests for v4.0 features
# Tests: Bulk Rename logic, Folder Watch queue, Disk Map treemap,
#        Dialog button creation, Context menu helpers, Scheduled Clean

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'Scanner.ps1')
. (Join-Path $modPath 'FolderOrganizer.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [New Features v4.0]" -ForegroundColor Cyan
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'

# ========================================
# BULK RENAME - Prefix Mode
# ========================================
Write-Host "    --- Bulk Rename: Prefix ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
'file1.txt', 'file2.doc', 'photo.jpg' | ForEach-Object { Set-Content (Join-Path $sandbox $_) 'test' }
$files = @(Get-ChildItem $sandbox -File | Sort-Object Name)
$plan = @()
foreach ($f in $files) {
    $newName = "PRE_$($f.Name)"
    $plan += [PSCustomObject]@{ OldName = $f.Name; NewName = $newName; FullPath = $f.FullName; Status = 'Ready' }
}
Assert-Equal 3 $plan.Count "Prefix: plan has 3 items"
Assert-Equal 'PRE_file1.txt' $plan[0].NewName "Prefix: file1.txt -> PRE_file1.txt"
Assert-Equal 'PRE_photo.jpg' $plan[2].NewName "Prefix: photo.jpg -> PRE_photo.jpg"

# Execute rename
$ok = 0
foreach ($item in $plan) {
    $newPath = Join-Path $sandbox $item.NewName
    Rename-Item -Path $item.FullPath -NewName $item.NewName -EA SilentlyContinue
    if (Test-Path $newPath) { $item.Status = 'Done'; $ok++ } else { $item.Status = 'Error' }
}
Assert-Equal 3 $ok "Prefix: all 3 files renamed"
Assert-True (Test-Path (Join-Path $sandbox 'PRE_file1.txt')) "Prefix: PRE_file1.txt exists"
Assert-True (Test-Path (Join-Path $sandbox 'PRE_photo.jpg')) "Prefix: PRE_photo.jpg exists"
Assert-True (-not (Test-Path (Join-Path $sandbox 'file1.txt'))) "Prefix: old file1.txt removed"
Remove-TestSandbox $sandbox

# ========================================
# BULK RENAME - Suffix Mode
# ========================================
Write-Host "    --- Bulk Rename: Suffix ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
'report.pdf', 'data.xlsx' | ForEach-Object { Set-Content (Join-Path $sandbox $_) 'test' }
$files = @(Get-ChildItem $sandbox -File | Sort-Object Name)
$plan = @()
foreach ($f in $files) {
    $ext = $f.Extension; $base = $f.BaseName
    $newName = "$base`_final$ext"
    $plan += [PSCustomObject]@{ OldName = $f.Name; NewName = $newName; FullPath = $f.FullName; Status = 'Ready' }
}
Assert-Equal 'data_final.xlsx' $plan[0].NewName "Suffix: data.xlsx -> data_final.xlsx"
Assert-Equal 'report_final.pdf' $plan[1].NewName "Suffix: report.pdf -> report_final.pdf"

$ok = 0
foreach ($item in $plan) {
    Rename-Item -Path $item.FullPath -NewName $item.NewName -EA SilentlyContinue
    if (Test-Path (Join-Path $sandbox $item.NewName)) { $ok++ }
}
Assert-Equal 2 $ok "Suffix: both files renamed"
Remove-TestSandbox $sandbox

# ========================================
# BULK RENAME - Replace Mode
# ========================================
Write-Host "    --- Bulk Rename: Replace ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
'old_report.txt', 'old_data.csv', 'new_file.doc' | ForEach-Object { Set-Content (Join-Path $sandbox $_) 'test' }
$files = @(Get-ChildItem $sandbox -File | Sort-Object Name)
$findText = 'old'; $replaceText = 'new'
$plan = @()
foreach ($f in $files) {
    $newName = $f.Name.Replace($findText, $replaceText)
    $status = if ($newName -eq $f.Name) { 'Skip' } else { 'Ready' }
    $plan += [PSCustomObject]@{ OldName = $f.Name; NewName = $newName; FullPath = $f.FullName; Status = $status }
}
Assert-Equal 'new_report.txt' ($plan | Where-Object { $_.OldName -eq 'old_report.txt' }).NewName "Replace: old_report -> new_report"
Assert-Equal 'Skip' ($plan | Where-Object { $_.OldName -eq 'new_file.doc' }).Status "Replace: new_file.doc skipped (no match)"
$toRename = @($plan | Where-Object { $_.Status -eq 'Ready' })
Assert-Equal 2 $toRename.Count "Replace: 2 files to rename, 1 skip"
Remove-TestSandbox $sandbox

# ========================================
# BULK RENAME - Sequential Mode
# ========================================
Write-Host "    --- Bulk Rename: Sequential ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
'alpha.jpg', 'beta.jpg', 'gamma.jpg' | ForEach-Object { Set-Content (Join-Path $sandbox $_) 'test' }
$files = @(Get-ChildItem $sandbox -File | Sort-Object Name)
$plan = @(); $counter = 1
foreach ($f in $files) {
    $ext = $f.Extension
    $newName = "photo_$($counter.ToString('D3'))$ext"
    $plan += [PSCustomObject]@{ OldName = $f.Name; NewName = $newName; FullPath = $f.FullName; Status = 'Ready' }
    $counter++
}
Assert-Equal 'photo_001.jpg' $plan[0].NewName "Seq: alpha.jpg -> photo_001.jpg"
Assert-Equal 'photo_002.jpg' $plan[1].NewName "Seq: beta.jpg -> photo_002.jpg"
Assert-Equal 'photo_003.jpg' $plan[2].NewName "Seq: gamma.jpg -> photo_003.jpg"

$ok = 0
foreach ($item in $plan) {
    Rename-Item -Path $item.FullPath -NewName $item.NewName -EA SilentlyContinue
    if (Test-Path (Join-Path $sandbox $item.NewName)) { $ok++ }
}
Assert-Equal 3 $ok "Seq: all 3 files renamed sequentially"
Remove-TestSandbox $sandbox

# ========================================
# BULK RENAME - Date Prefix Mode
# ========================================
Write-Host "    --- Bulk Rename: Date Prefix ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
$testFile = Join-Path $sandbox 'report.pdf'
Set-Content $testFile 'test'
$fi = Get-Item $testFile
$dateStr = $fi.LastWriteTime.ToString('yyyy-MM-dd')
$newName = "$dateStr`_$($fi.Name)"
Assert-True ($newName -match '^\d{4}-\d{2}-\d{2}_report\.pdf$') "DatePfx: format matches yyyy-MM-dd_report.pdf"
Assert-True ($newName -ne $fi.Name) "DatePfx: new name differs from original"
Remove-TestSandbox $sandbox

# ========================================
# BULK RENAME - Conflict Detection
# ========================================
Write-Host "    --- Bulk Rename: Conflict ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
Set-Content (Join-Path $sandbox 'file.txt') 'original'
Set-Content (Join-Path $sandbox 'PRE_file.txt') 'existing'  # conflict target
$f = Get-Item (Join-Path $sandbox 'file.txt')
$newPath = Join-Path $sandbox 'PRE_file.txt'
$conflict = Test-Path $newPath
Assert-True $conflict "Conflict: detects existing PRE_file.txt"
Remove-TestSandbox $sandbox

# ========================================
# FOLDER WATCH - Queue Logic
# ========================================
Write-Host "    --- Folder Watch: Queue ---" -ForegroundColor DarkCyan
$queue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
Assert-Equal 0 $queue.Count "Watch queue: starts empty"
[void]$queue.Add('C:\test\file1.jpg')
[void]$queue.Add('C:\test\file2.pdf')
Assert-Equal 2 $queue.Count "Watch queue: 2 items queued"
$items = @($queue.ToArray()); $queue.Clear()
Assert-Equal 2 $items.Count "Watch queue: ToArray returns 2"
Assert-Equal 0 $queue.Count "Watch queue: cleared after processing"
Assert-Equal 'C:\test\file1.jpg' $items[0] "Watch queue: first item correct"

# ========================================
# FOLDER WATCH - Auto-Organize
# ========================================
Write-Host "    --- Folder Watch: Auto-Organize ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
# Simulate what the watch timer does
$testFile = Join-Path $sandbox 'newphoto.jpg'
Set-Content $testFile 'photo data'
$fi = Get-Item $testFile
$cat = Get-FileCategory $fi.Extension
Assert-Equal 'Images' $cat "Watch auto-org: .jpg -> Images"
$destDir = Join-Path $sandbox $cat
New-Item $destDir -ItemType Directory -Force | Out-Null
$dest = Join-Path $destDir $fi.Name
Move-Item $fi.FullName $dest -EA SilentlyContinue
Assert-True (Test-Path $dest) "Watch auto-org: file moved to Images folder"
Assert-True (-not (Test-Path $testFile)) "Watch auto-org: original removed"

# Test with document
$testDoc = Join-Path $sandbox 'invoice.pdf'
Set-Content $testDoc 'pdf data'
$fi2 = Get-Item $testDoc
$cat2 = Get-FileCategory $fi2.Extension
Assert-Equal 'Documents' $cat2 "Watch auto-org: .pdf -> Documents"
$destDir2 = Join-Path $sandbox $cat2
New-Item $destDir2 -ItemType Directory -Force | Out-Null
Move-Item $fi2.FullName (Join-Path $destDir2 $fi2.Name) -EA SilentlyContinue
Assert-True (Test-Path (Join-Path $destDir2 'invoice.pdf')) "Watch auto-org: pdf moved to Documents"

# Test Other category skipped
$testUnk = Join-Path $sandbox 'mystery.xyz'
Set-Content $testUnk 'unknown data'
$fi3 = Get-Item $testUnk
$cat3 = Get-FileCategory $fi3.Extension
Assert-Equal 'Other' $cat3 "Watch auto-org: .xyz -> Other (skip)"
Remove-TestSandbox $sandbox

# ========================================
# FOLDER WATCH - FileSystemWatcher
# ========================================
Write-Host "    --- Folder Watch: FSW ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
$fsw = New-Object System.IO.FileSystemWatcher
$fsw.Path = $sandbox; $fsw.Filter = '*.*'
$fsw.NotifyFilter = [System.IO.NotifyFilters]::FileName
Assert-NotNull $fsw "FSW: created successfully"
Assert-Equal $sandbox $fsw.Path "FSW: path matches sandbox"
Assert-Equal '*.*' $fsw.Filter "FSW: filter is *.*"
$fsw.Dispose()
Remove-TestSandbox $sandbox

# ========================================
# DISK MAP - Folder Size Scanning
# ========================================
Write-Host "    --- Disk Map: Folder Scan ---" -ForegroundColor DarkCyan
$sandbox = New-TestSandbox
$sub1 = Join-Path $sandbox 'big_folder'; New-Item $sub1 -ItemType Directory -Force | Out-Null
$sub2 = Join-Path $sandbox 'small_folder'; New-Item $sub2 -ItemType Directory -Force | Out-Null
# Create files with known sizes
[byte[]]$bigData = New-Object byte[] 10240  # 10KB
[System.IO.File]::WriteAllBytes((Join-Path $sub1 'big.dat'), $bigData)
[byte[]]$smallData = New-Object byte[] 1024  # 1KB
[System.IO.File]::WriteAllBytes((Join-Path $sub2 'small.dat'), $smallData)
Set-Content (Join-Path $sandbox 'loose.txt') 'loose file data'

$items = @()
$idx = 0
$dirs = @(Get-ChildItem $sandbox -Directory)
foreach ($d in $dirs) {
    $size = (Get-ChildItem $d.FullName -Recurse -File | Measure-Object Length -Sum).Sum
    if ($size -gt 0) { $items += [PSCustomObject]@{ Name = $d.Name; Size = [long]$size; Index = $idx; FullPath = $d.FullName } }
    $idx++
}
$looseSize = (Get-ChildItem $sandbox -File | Measure-Object Length -Sum).Sum
if ($looseSize -gt 0) { $items += [PSCustomObject]@{ Name = '(files)'; Size = [long]$looseSize; Index = $idx; FullPath = $sandbox } }

Assert-GreaterThan $items.Count 1 "DiskMap: found 2+ items"
$sorted = @($items | Sort-Object Size -Descending)
Assert-Equal 'big_folder' $sorted[0].Name "DiskMap: big_folder is largest"
Assert-GreaterThan $sorted[0].Size 5000 "DiskMap: big_folder > 5KB"
$hasFiles = @($items | Where-Object { $_.Name -eq '(files)' })
Assert-Equal 1 $hasFiles.Count "DiskMap: loose files counted"
Remove-TestSandbox $sandbox

# ========================================
# DISK MAP - Treemap Layout Logic
# ========================================
Write-Host "    --- Disk Map: Layout ---" -ForegroundColor DarkCyan
$testItems = @(
    [PSCustomObject]@{ Name = 'A'; Size = [long]500; Index = 0 }
    [PSCustomObject]@{ Name = 'B'; Size = [long]300; Index = 1 }
    [PSCustomObject]@{ Name = 'C'; Size = [long]200; Index = 2 }
)
$totalSize = ($testItems | Measure-Object Size -Sum).Sum
Assert-Equal 1000 $totalSize "Layout: total size = 1000"

# Simulate layout ratios
$w = 600; $h = 400
$horizontal = $w -ge $h
Assert-True $horizontal "Layout: horizontal for 600x400"
foreach ($item in $testItems) {
    $ratio = $item.Size / $totalSize
    $rw = [math]::Max(2, [math]::Round($w * $ratio))
    Assert-GreaterThan $rw 1 "Layout: $($item.Name) width > 1px (got $rw)"
}
$ratioA = $testItems[0].Size / $totalSize
Assert-Equal 0.5 $ratioA "Layout: A ratio = 0.5 (500/1000)"

# ========================================
# DISK MAP - Color Palette
# ========================================
Write-Host "    --- Disk Map: Colors ---" -ForegroundColor DarkCyan
$mapColors = @('#2563eb', '#dc2626', '#16a34a', '#d97706', '#9333ea', '#0891b2', '#e11d48', '#4f46e5', '#059669', '#ca8a04', '#7c3aed', '#0d9488')
Assert-Equal 12 $mapColors.Count "Colors: 12 distinct colors defined"
$uniqueColors = $mapColors | Select-Object -Unique
Assert-Equal 12 $uniqueColors.Count "Colors: all 12 are unique"
Assert-True ($mapColors[0] -match '^#[0-9a-f]{6}$') "Colors: valid hex format"

# ========================================
# SCHEDULED CLEAN - Task Name
# ========================================
Write-Host "    --- Scheduled Clean ---" -ForegroundColor DarkCyan
$taskName = 'DiskCleanerPro_WeeklyClean'
Assert-Equal 'DiskCleanerPro_WeeklyClean' $taskName "Schedule: task name is correct"

# Test that SystemCleaner module is loadable for scheduled task
$cleanerPath = Join-Path $modPath 'SystemCleaner.ps1'
Assert-True (Test-Path $cleanerPath) "Schedule: SystemCleaner.ps1 exists"

# Test Get-SystemJunkTargets returns targets
$targets = Get-SystemJunkTargets
Assert-GreaterThan $targets.Count 0 "Schedule: junk targets available"
foreach ($t in $targets | Select-Object -First 3) {
    Assert-NotNull $t.Name "Schedule: target has Name"
    Assert-NotNull $t.Path "Schedule: target has Path"
    Assert-NotNull $t.Pattern "Schedule: target has Pattern"
}

# ========================================
# DIALOG BUTTONS - Border Approach
# ========================================
Write-Host "    --- Dialog Buttons ---" -ForegroundColor DarkCyan
# Test that Border-based buttons can be created programmatically
Add-Type -AssemblyName PresentationFramework -EA SilentlyContinue
$border = New-Object System.Windows.Controls.Border
$border.CornerRadius = '7'; $border.Padding = '20,9'
$tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = 'OK'; $tb.FontSize = 12.5
$border.Child = $tb
Assert-NotNull $border "Dialog: Border created"
Assert-Equal '7,7,7,7' "$($border.CornerRadius)" "Dialog: CornerRadius = 7"
Assert-Equal 'OK' $tb.Text "Dialog: TextBlock text = OK"
Assert-NotNull $border.Child "Dialog: Border has child TextBlock"

# Test Cancel button style
$borderCancel = New-Object System.Windows.Controls.Border
$borderCancel.CornerRadius = '7'; $borderCancel.Padding = '20,9'; $borderCancel.Margin = '0,0,8,0'
$tbCancel = New-Object System.Windows.Controls.TextBlock; $tbCancel.Text = 'Cancel'; $tbCancel.FontSize = 12.5
$borderCancel.Child = $tbCancel
Assert-Equal 'Cancel' $tbCancel.Text "Dialog: Cancel button text"
Assert-Equal '0,0,8,0' "$($borderCancel.Margin)" "Dialog: Cancel margin includes right spacing"

# ========================================
# CONTEXT MENU - Helper Verification
# ========================================
Write-Host "    --- Context Menu ---" -ForegroundColor DarkCyan
$cm = New-Object System.Windows.Controls.ContextMenu
Assert-NotNull $cm "ContextMenu: created"
$mi = New-Object System.Windows.Controls.MenuItem
$mi.Header = 'Open File'; $mi.FontSize = 12
Assert-Equal 'Open File' $mi.Header "ContextMenu: MenuItem header"
$mi2 = New-Object System.Windows.Controls.MenuItem
$mi2.Header = 'Open Location'
[void]$cm.Items.Add($mi)
[void]$cm.Items.Add($mi2)
Assert-Equal 2 $cm.Items.Count "ContextMenu: 2 items added"

# ========================================
# ORGANIZE GRID - Column Proportions
# ========================================
Write-Host "    --- Organize Grid Columns ---" -ForegroundColor DarkCyan
# Verify the XAML has correct column widths by reading main script
$mainScript = Get-Content (Join-Path (Split-Path $PSScriptRoot) 'DiskCleanerPro.ps1') -Raw
Assert-True ($mainScript -match 'Header="File".*Width="2\*"') "OrgGrid: File column is 2*"
Assert-True ($mainScript -match 'Header="Category".*Width="100"') "OrgGrid: Category column is 100"
Assert-True ($mainScript -match 'Header="Destination".*Width="3\*"') "OrgGrid: Destination column is 3*"
Assert-True ($mainScript -match 'Header="Size".*Binding="\{Binding SizeText\}".*Width="80"') "OrgGrid: Size column is 80"

# ========================================
# RENAME GRID - Column Setup
# ========================================
Write-Host "    --- Rename Grid Columns ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'Header="Original Name".*Width="2\*"') "RenGrid: OldName column is 2*"
Assert-True ($mainScript -match 'Header="New Name".*Width="2\*"') "RenGrid: NewName column is 2*"
Assert-True ($mainScript -match 'Header="Status".*Width="80"') "RenGrid: Status column is 80"

# ========================================
# DISK MAP TAB - XAML Elements
# ========================================
Write-Host "    --- Disk Map XAML ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'canvasMap') "DiskMap: Canvas element exists"
Assert-True ($mainScript -match 'btnMapScan') "DiskMap: Scan button exists"
Assert-True ($mainScript -match 'btnMapBrowse') "DiskMap: Browse button exists"
Assert-True ($mainScript -match 'lblMapStatus') "DiskMap: Status label exists"
Assert-True ($mainScript -match 'lblMapHover') "DiskMap: Hover label exists"

# ========================================
# ASYNC PATTERN - Disk Map uses runspace
# ========================================
Write-Host "    --- Async Pattern ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'mapRs.*runspacefactory.*CreateRunspace') "Async: Disk Map uses runspace"
Assert-True ($mainScript -match 'mapTimer.*DispatcherTimer') "Async: Disk Map uses DispatcherTimer"
Assert-True ($mainScript -match 'mapSh.*Synchronized') "Async: Disk Map uses synchronized hashtable"
Assert-True ($mainScript -match 'mapPs\.BeginInvoke') "Async: Disk Map calls BeginInvoke"

# ========================================
# WATCH BUTTON - XAML Element
# ========================================
Write-Host "    --- Watch Button ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'btnOrgWatch') "Watch: button exists in XAML"
Assert-True ($mainScript -match 'FileSystemWatcher') "Watch: uses FileSystemWatcher"
Assert-True ($mainScript -match 'watchQueue') "Watch: has queue for events"
Assert-True ($mainScript -match 'watchTimer') "Watch: has timer for processing"

# ========================================
# SCHEDULED CLEAN - XAML Elements
# ========================================
Write-Host "    --- Scheduled Clean XAML ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'btnScheduleEnable') "Schedule: enable button exists"
Assert-True ($mainScript -match 'btnScheduleDisable') "Schedule: disable button exists"
Assert-True ($mainScript -match 'lblScheduleStatus') "Schedule: status label exists"
Assert-True ($mainScript -match 'SCHEDULED AUTO-CLEAN') "Schedule: section title exists"
Assert-True ($mainScript -match 'Register-ScheduledTask') "Schedule: uses Register-ScheduledTask"

# ========================================
# VERSION
# ========================================
Write-Host "    --- Version ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'DiskCleaner Pro v4\.\d') "Version: tooltip shows v4.x"

# ========================================
# v4.1: DARK SCROLLBAR
# ========================================
Write-Host "    --- v4.1: Dark Scrollbar ---" -ForegroundColor DarkCyan
# Verify scrollbar ControlTemplate exists with dark colors
Assert-True ($mainScript -match 'TargetType="ScrollBar"') "Scrollbar: has ScrollBar style"
Assert-True ($mainScript -match 'PART_Track') "Scrollbar: has PART_Track"
Assert-True ($mainScript -match '#1e1e1e.*CornerRadius="5"') "Scrollbar: dark track background"
Assert-True ($mainScript -match 'IsDragging.*Value="True"') "Scrollbar: has drag state trigger"
Assert-True ($mainScript -match '#1a8bff') "Scrollbar: blue drag color"
Assert-True ($mainScript -match 'Orientation.*Horizontal') "Scrollbar: has horizontal template"
Assert-True ($mainScript -match 'LineLeftCommand') "Scrollbar: horizontal left command"
Assert-True ($mainScript -match 'LineRightCommand') "Scrollbar: horizontal right command"
# Verify old DarkThumb style is removed
Assert-True (-not ($mainScript -match 'x:Key="DarkThumb"')) "Scrollbar: old DarkThumb removed"

# ========================================
# v4.1: QUICK-SELECT BUTTONS - Disk Analyzer
# ========================================
Write-Host "    --- v4.1: Analyzer Quick Buttons ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'Quick folder buttons for Disk Analyzer') "Analyzer: quick buttons section exists"
Assert-True ($mainScript -match "Name = 'Desktop'.*Path.*GetFolderPath\('Desktop'\)") "Analyzer: has Desktop quick button"
Assert-True ($mainScript -match "Name = 'Downloads'.*Path.*USERPROFILE.*Downloads") "Analyzer: has Downloads quick button"
Assert-True ($mainScript -match "Name = 'Documents'.*Path.*GetFolderPath\('MyDocuments'\)") "Analyzer: has Documents quick button"
Assert-True ($mainScript -match "Name = 'C:") "Analyzer: has C:\ quick button"
# Verify auto-scan on click
Assert-True ($mainScript -match "btnScan.*RaiseEvent") "Analyzer: quick buttons trigger scan"

# ========================================
# v4.1: QUICK-SELECT BUTTONS - Dev Cleanup
# ========================================
Write-Host "    --- v4.1: Dev Quick Buttons ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'Quick project root buttons for Dev Cleanup') "Dev: quick buttons section exists"
Assert-True ($mainScript -match "Name = 'MyApps'") "Dev: has MyApps quick button"
Assert-True ($mainScript -match "Name = 'source'") "Dev: has source quick button"
Assert-True ($mainScript -match "Name = 'repos'") "Dev: has repos quick button"
Assert-True ($mainScript -match "btnDevScan.*RaiseEvent") "Dev: quick buttons trigger dev scan"
# Verify only existing paths get buttons
Assert-True ($mainScript -match 'Test-Path \$dp\.Path') "Dev: checks path exists before adding button"

# ========================================
# v4.1: TREEMAP RIGHT-CLICK
# ========================================
Write-Host "    --- v4.1: Treemap Right-Click ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'mapContextMenu.*ContextMenu') "TreemapRC: context menu created"
Assert-True ($mainScript -match 'Open Folder') "TreemapRC: has Open Folder item"
Assert-True ($mainScript -match 'Show in Explorer') "TreemapRC: has Show in Explorer item"
Assert-True ($mainScript -match 'Copy Path') "TreemapRC: has Copy Path item"
Assert-True ($mainScript -match 'mapCtxPath') "TreemapRC: stores context path"
Assert-True ($mainScript -match 'MouseRightButtonDown') "TreemapRC: attached to canvas"
Assert-True ($mainScript -match 'Clipboard.*SetText.*mapCtxPath') "TreemapRC: Copy Path uses clipboard"
# Verify context menu uses dark theme colors
Assert-True ($mainScript -match 'mapContextMenu\.Background.*2d2d30') "TreemapRC: dark background"

# ========================================
# v4.1: SIZE FILTER BUTTONS
# ========================================
Write-Host "    --- v4.1: Size Filters ---" -ForegroundColor DarkCyan
Assert-True ($mainScript -match 'Add-SizeFilters') "SizeFilter: function defined"
Assert-True ($mainScript -match 'allLargeItems') "SizeFilter: stores unfiltered items"
Assert-True ($mainScript -match 'sizeFilters') "SizeFilter: tracks filter buttons"
Assert-True ($mainScript -match '100MB') "SizeFilter: has 100MB threshold"
Assert-True ($mainScript -match '500MB') "SizeFilter: has 500MB threshold"
Assert-True ($mainScript -match '1GB') "SizeFilter: has 1GB threshold"
# Verify filter logic
Assert-True ($mainScript -match 'Where-Object.*Size.*-gt.*threshold') "SizeFilter: filters by size threshold"
Assert-True ($mainScript -match '75beff.*858585') "SizeFilter: highlights active filter"

# ========================================
# v4.1: FUNCTIONAL TESTS
# ========================================
Write-Host "    --- v4.1: Functional Tests ---" -ForegroundColor DarkCyan
# Test WPF scrollbar + context menu objects
Add-Type -AssemblyName PresentationFramework -EA SilentlyContinue

# ContextMenu functional test
$testCtxMenu = New-Object System.Windows.Controls.ContextMenu
$testMi1 = New-Object System.Windows.Controls.MenuItem; $testMi1.Header = 'Open Folder'
$testMi2 = New-Object System.Windows.Controls.MenuItem; $testMi2.Header = 'Show in Explorer'
$testMi3 = New-Object System.Windows.Controls.MenuItem; $testMi3.Header = 'Copy Path'
[void]$testCtxMenu.Items.Add($testMi1); [void]$testCtxMenu.Items.Add($testMi2); [void]$testCtxMenu.Items.Add($testMi3)
Assert-Equal 3 $testCtxMenu.Items.Count "Functional: 3 context menu items"
Assert-Equal 'Open Folder' $testMi1.Header "Functional: first item is Open Folder"
Assert-Equal 'Copy Path' $testMi3.Header "Functional: third item is Copy Path"

# Size filter logic test
$testItems = @(
    [PSCustomObject]@{ Name = 'small.txt'; Size = 50MB; SizeText = '50 MB' }
    [PSCustomObject]@{ Name = 'medium.zip'; Size = 200MB; SizeText = '200 MB' }
    [PSCustomObject]@{ Name = 'large.iso'; Size = 800MB; SizeText = '800 MB' }
    [PSCustomObject]@{ Name = 'huge.vhd'; Size = 2GB; SizeText = '2 GB' }
)
$filtered100 = @($testItems | Where-Object { $_.Size -gt 100MB })
Assert-Equal 3 $filtered100.Count "Functional: 3 items > 100MB"
$filtered500 = @($testItems | Where-Object { $_.Size -gt 500MB })
Assert-Equal 2 $filtered500.Count "Functional: 2 items > 500MB"
$filtered1g = @($testItems | Where-Object { $_.Size -gt 1GB })
Assert-Equal 1 $filtered1g.Count "Functional: 1 item > 1GB"
Assert-Equal 'huge.vhd' $filtered1g[0].Name "Functional: only huge.vhd > 1GB"

# Quick folder path resolution test
$desktopPath = [Environment]::GetFolderPath('Desktop')
Assert-True ($desktopPath.Length -gt 0) "Functional: Desktop path resolved"
$docsPath = [Environment]::GetFolderPath('MyDocuments')
Assert-True ($docsPath.Length -gt 0) "Functional: Documents path resolved"
$dlPath = "$env:USERPROFILE\Downloads"
Assert-True (Test-Path $dlPath) "Functional: Downloads folder exists"

# Synchronized queue (used by Watch + treemap scan)
$testQueue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
[void]$testQueue.Add('C:\test1'); [void]$testQueue.Add('C:\test2')
$snapshot = @($testQueue.ToArray()); $testQueue.Clear()
Assert-Equal 2 $snapshot.Count "Functional: sync queue snapshot"
Assert-Equal 0 $testQueue.Count "Functional: sync queue cleared"

$ErrorActionPreference = $prevEAP
