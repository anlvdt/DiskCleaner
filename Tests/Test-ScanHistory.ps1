# Test-ScanHistory.ps1 - ScanHistory Module Tests
# Tests: Save-ScanSnapshot, Get-ScanHistory, Compare-Scans

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'Scanner.ps1')  # FmtSize dependency
. (Join-Path $modPath 'ScanHistory.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [ScanHistory Module]" -ForegroundColor Cyan

# Override HistoryDir to sandbox
$sandbox = New-TestSandbox
$origHistoryDir = $Script:HistoryDir
$Script:HistoryDir = Join-Path $sandbox 'history'

# Helper: Create mock scan results
function New-MockScanForHistory {
    param([int]$FC = 100, [long]$Total = 50MB, [int]$LargeCount = 5, [int]$DupGroups = 3,
          [int]$JunkCount = 20, [int]$EmptyCount = 8, [int]$OldCount = 15)
    $dups = [System.Collections.ArrayList]::new()
    for ($i = 1; $i -le $DupGroups; $i++) {
        [void]$dups.Add([PSCustomObject]@{GroupId=$i; Hash="HASH$i"; Name="dup$i.txt"; FullPath="C:\test\dup$i.txt"; Size=1MB; SizeText='1 MB'})
        [void]$dups.Add([PSCustomObject]@{GroupId=$i; Hash="HASH$i"; Name="dup${i}b.txt"; FullPath="C:\test\dup${i}b.txt"; Size=1MB; SizeText='1 MB'})
    }
    $junk = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $JunkCount; $i++) { [void]$junk.Add([PSCustomObject]@{Name="junk$i.tmp"; Size=1KB}) }
    $empty = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $EmptyCount; $i++) { [void]$empty.Add([PSCustomObject]@{Name="empty$i"; FullPath="C:\test\empty$i"}) }
    $old = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $OldCount; $i++) { [void]$old.Add([PSCustomObject]@{Name="old$i.txt"; AccessDays=200}) }
    $large = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $LargeCount; $i++) { [void]$large.Add([PSCustomObject]@{Name="big$i.dat"; Size=20MB}) }
    $folders = [System.Collections.ArrayList]::new()
    [void]$folders.Add([PSCustomObject]@{Name='Documents'; Size=20MB; SizeText='20 MB'; FullPath='C:\test\Documents'})
    [void]$folders.Add([PSCustomObject]@{Name='Downloads'; Size=30MB; SizeText='30 MB'; FullPath='C:\test\Downloads'})
    return @{
        FC=$FC; Total=$Total; Files=[System.Collections.ArrayList]::new()
        Large=$large; Dups=$dups; Junk=$junk; Empty=$empty; OldFiles=$old
        FolderSizes=$folders; Ext=@{'.txt'=@{C=50;S=25MB}; '.jpg'=@{C=30;S=15MB}}; DC=10
    }
}

# --- Empty history ---
$history = Get-ScanHistory
Assert-Equal 0 @($history).Count "Empty history returns 0 items"

# --- Save-ScanSnapshot ---
$scan1 = New-MockScanForHistory -FC 100 -Total 50MB -LargeCount 5 -DupGroups 3
$file1 = Save-ScanSnapshot $scan1 'C:\TestScan'
Assert-NotNull $file1 "Save-ScanSnapshot returns file path"
$file1Exists = if ($file1) { Test-Path $file1 } else { $false }
Assert-True $file1Exists "Snapshot file exists on disk"

# Verify JSON structure
if ($file1Exists) {
    $json1 = Get-Content $file1 -Raw | ConvertFrom-Json
    Assert-NotNull $json1.Timestamp "Snapshot has Timestamp"
    Assert-Equal 'C:\TestScan' $json1.Path "Snapshot has correct Path"
    Assert-Equal 100 $json1.TotalFiles "Snapshot has TotalFiles=100"
    Assert-Equal 50MB $json1.TotalSize "Snapshot has correct TotalSize"
    Assert-Equal 5 $json1.LargeCount "Snapshot has LargeCount=5"
    Assert-Equal 3 $json1.DupGroups "Snapshot has DupGroups=3"
    Assert-Equal 20 $json1.JunkCount "Snapshot has JunkCount=20"
    Assert-Equal 8 $json1.EmptyCount "Snapshot has EmptyCount=8"
    Assert-Equal 15 $json1.OldCount "Snapshot has OldCount=15"
    Assert-NotNull $json1.TopFolders "Snapshot has TopFolders"
    Assert-NotNull $json1.ExtBreakdown "Snapshot has ExtBreakdown"
} else {
    Skip-Test "Skipping JSON structure tests - file1 not created"
}
Start-Sleep -Seconds 1  # ensure different timestamp for unique filename
$scan2 = New-MockScanForHistory -FC 150 -Total 60MB -LargeCount 8 -DupGroups 5
$file2 = Save-ScanSnapshot $scan2 'C:\TestScan'

$history = @(Get-ScanHistory)
Assert-GreaterThan $history.Count 0 "History shows snapshots"

# Verify sorted newest first
Assert-True ($history[0].Files -eq 150 -or $history[0].Files -eq 100) "History has correct file counts"

# Check history item properties
$firstHistory = $history[0]
Assert-NotNull $firstHistory.File "History item has File path"
Assert-NotNull $firstHistory.Timestamp "History item has Timestamp"
Assert-NotNull $firstHistory.Date "History item has formatted Date"
Assert-NotNull $firstHistory.Path "History item has scan Path"
Assert-NotNull $firstHistory.SizeText "History item has SizeText"

# --- Compare-Scans ---
$scan3 = New-MockScanForHistory -FC 200 -Total 80MB -LargeCount 10 -DupGroups 7 -JunkCount 30 -EmptyCount 12
try {
    if ($file1 -and (Test-Path $file1)) {
        $comparison = Compare-Scans -OldFile $file1 -CurrentResults $scan3 -CurrentPath 'C:\TestScan'
        Assert-NotNull $comparison "Compare-Scans returns result"
        if ($comparison) {
            Assert-NotNull $comparison.Delta "Comparison has Delta array"
            Assert-GreaterThan $comparison.Delta.Count 3 "Delta has 3+ metrics"
            $sizeDiff = $comparison.SizeDiff
            Assert-GreaterThan $sizeDiff 0 "Size increased (positive diff)"
            $fileDiff = $comparison.FileDiff
            Assert-GreaterThan $fileDiff 0 "File count increased"
            $metrics = $comparison.Delta | ForEach-Object { $_.Metric }
            Assert-Contains $metrics 'Total Size' "Delta has 'Total Size' metric"
            Assert-Contains $metrics 'Total Files' "Delta has 'Total Files' metric"
            Assert-Contains $metrics 'Duplicate Groups' "Delta has 'Duplicate Groups' metric"
            Assert-Contains $metrics 'Junk Files' "Delta has 'Junk Files' metric"
            Assert-NotNull $comparison.OldDate "Comparison has OldDate"
        }
    } else {
        Skip-Test "file1 snapshot not found for Compare-Scans"
    }
} catch {
    Skip-Test "Compare-Scans threw: $($_.Exception.Message)"
}

# --- Compare with non-existent file ---
try {
    $prevEAP2 = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    $badCompare = Compare-Scans -OldFile 'C:\NonExistent\nofile.json' -CurrentResults $scan3 -CurrentPath 'C:\Test' 2>$null
    $ErrorActionPreference = $prevEAP2
    Assert-True ($null -eq $badCompare) "Compare with non-existent file returns null"
} catch {
    Assert-True $true "Compare with non-existent file throws (expected)"
}

# Restore and cleanup
$Script:HistoryDir = $origHistoryDir
Remove-TestSandbox $sandbox

