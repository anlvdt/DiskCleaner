# Test-SmartClean.ps1 - SmartClean Module Tests
# Tests: Get-SmartRecommendations

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'SmartClean.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [SmartClean Module]" -ForegroundColor Cyan

# Helper: Create mock scan results
function New-MockScanResults {
    return @{
        FC = 0; Total = 0
        Files = [System.Collections.ArrayList]::new()
        Large = [System.Collections.ArrayList]::new()
        Dups = [System.Collections.ArrayList]::new()
        Junk = [System.Collections.ArrayList]::new()
        OldFiles = [System.Collections.ArrayList]::new()
        Empty = [System.Collections.ArrayList]::new()
        FolderSizes = [System.Collections.ArrayList]::new()
        Ext = @{}
    }
}

# --- Empty results = no recommendations ---
$empty = New-MockScanResults
$recs = Get-SmartRecommendations $empty
Assert-Equal 0 @($recs).Count "No recommendations for clean results"

# --- Duplicates detection (HIGH priority) ---
$withDups = New-MockScanResults
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId=1; Hash='ABCD'; Name='file1.txt'; FullPath='C:\test\file1.txt'; Size=5MB; SizeText='5.0 MB'})
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId=1; Hash='ABCD'; Name='file2.txt'; FullPath='C:\test\file2.txt'; Size=5MB; SizeText='5.0 MB'})
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId=2; Hash='EFGH'; Name='img1.jpg'; FullPath='C:\test\img1.jpg'; Size=2MB; SizeText='2.0 MB'})
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId=2; Hash='EFGH'; Name='img2.jpg'; FullPath='C:\test\img2.jpg'; Size=2MB; SizeText='2.0 MB'})
$recs = Get-SmartRecommendations $withDups
$dupRec = $recs | Where-Object { $_.Category -eq 'Duplicates' }
Assert-NotNull $dupRec "Detects duplicate groups"
Assert-Equal 'HIGH' $dupRec.Priority "Duplicate recommendation is HIGH priority"
Assert-GreaterThan $dupRec.Savings 0 "Duplicate savings > 0"

# --- node_modules detection (HIGH priority) ---
$withNM = New-MockScanResults
[void]$withNM.Junk.Add([PSCustomObject]@{Name='node_modules'; FullPath='C:\project\node_modules'; Size=500MB; SizeText='500 MB'; ItemType='Folder'; Reason='Junk: node_modules'})
[void]$withNM.Junk.Add([PSCustomObject]@{Name='node_modules'; FullPath='C:\project2\node_modules'; Size=300MB; SizeText='300 MB'; ItemType='Folder'; Reason='Junk: node_modules'})
$recs = Get-SmartRecommendations $withNM
$nmRec = $recs | Where-Object { $_.Category -eq 'Dev Junk' }
Assert-NotNull $nmRec "Detects node_modules as Dev Junk"
Assert-Equal 'HIGH' $nmRec.Priority "node_modules recommendation is HIGH priority"
Assert-True ($nmRec.Message -like '*2 node_modules*') "Message mentions count"

# --- Old files detection (MEDIUM priority) ---
$withOld = New-MockScanResults
for ($i = 0; $i -lt 10; $i++) {
    [void]$withOld.OldFiles.Add([PSCustomObject]@{Name="old$i.txt"; FullPath="C:\test\old$i.txt"; Size=1MB; SizeText='1.0 MB'; AccessDays=800; AgeDays=800})
}
$recs = Get-SmartRecommendations $withOld
$oldRec = $recs | Where-Object { $_.Category -eq 'Old Files' }
Assert-NotNull $oldRec "Detects old files (2+ years)"
Assert-Equal 'MEDIUM' $oldRec.Priority "Old files recommendation is MEDIUM priority"
Assert-GreaterThan $oldRec.Savings 0 "Old files savings > 0"

# --- Large junk detection (MEDIUM priority) ---
$withBigJunk = New-MockScanResults
[void]$withBigJunk.Junk.Add([PSCustomObject]@{Name='huge.dmp'; FullPath='C:\test\huge.dmp'; Size=50MB; SizeText='50 MB'; ItemType='File'; Reason='Pattern: *.dmp'})
[void]$withBigJunk.Junk.Add([PSCustomObject]@{Name='big.tmp'; FullPath='C:\test\big.tmp'; Size=20MB; SizeText='20 MB'; ItemType='File'; Reason='Pattern: *.tmp'})
$recs = Get-SmartRecommendations $withBigJunk
$bigRec = $recs | Where-Object { $_.Category -eq 'Large Junk' }
Assert-NotNull $bigRec "Detects large junk files (>=10MB)"
Assert-Equal 'MEDIUM' $bigRec.Priority "Large junk is MEDIUM priority"

# --- Empty directories detection (LOW priority) ---
$withEmpty = New-MockScanResults
for ($i = 0; $i -lt 15; $i++) {
    [void]$withEmpty.Empty.Add([PSCustomObject]@{Name="empty$i"; FullPath="C:\test\empty$i"; Created='2025-01-01'})
}
$recs = Get-SmartRecommendations $withEmpty
$emptyRec = $recs | Where-Object { $_.Category -eq 'Empty Dirs' }
Assert-NotNull $emptyRec "Detects 10+ empty directories"
Assert-Equal 'LOW' $emptyRec.Priority "Empty dirs is LOW priority"
Assert-Equal 0 $emptyRec.Savings "Empty dirs savings is 0"

# --- Threshold checks ---
# Less than 10 empty dirs â†’ no recommendation
$fewEmpty = New-MockScanResults
for ($i = 0; $i -lt 5; $i++) {
    [void]$fewEmpty.Empty.Add([PSCustomObject]@{Name="e$i"; FullPath="C:\test\e$i"; Created='2025-01-01'})
}
$recs = Get-SmartRecommendations $fewEmpty
$noEmptyRec = $recs | Where-Object { $_.Category -eq 'Empty Dirs' }
Assert-True ($null -eq $noEmptyRec) "No recommendation for < 10 empty dirs"

# Old files less than 730 days â†’ no recommendation
$notOldEnough = New-MockScanResults
[void]$notOldEnough.OldFiles.Add([PSCustomObject]@{Name='recent.txt'; FullPath='C:\test\recent.txt'; Size=1MB; SizeText='1.0 MB'; AccessDays=100; AgeDays=100})
$recs = Get-SmartRecommendations $notOldEnough
$noOldRec = $recs | Where-Object { $_.Category -eq 'Old Files' }
Assert-True ($null -eq $noOldRec) "No recommendation for files < 730 days old"

# --- Combined scenario ---
$combined = New-MockScanResults
[void]$combined.Dups.Add([PSCustomObject]@{GroupId=1; Hash='AAAA'; Name='a.txt'; FullPath='C:\a.txt'; Size=10MB; SizeText='10 MB'})
[void]$combined.Dups.Add([PSCustomObject]@{GroupId=1; Hash='AAAA'; Name='b.txt'; FullPath='C:\b.txt'; Size=10MB; SizeText='10 MB'})
[void]$combined.Junk.Add([PSCustomObject]@{Name='node_modules'; FullPath='C:\nm'; Size=200MB; SizeText='200 MB'; ItemType='Folder'; Reason='Junk'})
for ($i = 0; $i -lt 12; $i++) {
    [void]$combined.Empty.Add([PSCustomObject]@{Name="e$i"; FullPath="C:\e$i"; Created='2025-01-01'})
}
$recs = Get-SmartRecommendations $combined
Assert-GreaterThan @($recs).Count 1 "Combined scenario returns 2+ recommendations"

