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
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'ABCD'; Name = 'file1.txt'; FullPath = 'C:\test\file1.txt'; Size = 5MB; SizeText = '5.0 MB' })
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'ABCD'; Name = 'file2.txt'; FullPath = 'C:\test\file2.txt'; Size = 5MB; SizeText = '5.0 MB' })
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId = 2; Hash = 'EFGH'; Name = 'img1.jpg'; FullPath = 'C:\test\img1.jpg'; Size = 2MB; SizeText = '2.0 MB' })
[void]$withDups.Dups.Add([PSCustomObject]@{GroupId = 2; Hash = 'EFGH'; Name = 'img2.jpg'; FullPath = 'C:\test\img2.jpg'; Size = 2MB; SizeText = '2.0 MB' })
$recs = Get-SmartRecommendations $withDups
$dupRec = $recs | Where-Object { $_.Category -eq 'Duplicates' }
Assert-NotNull $dupRec "Detects duplicate groups"
Assert-Equal 'HIGH' $dupRec.Priority "Duplicate recommendation is HIGH priority"
Assert-GreaterThan $dupRec.Savings 0 "Duplicate savings > 0"

# --- node_modules detection (HIGH priority) ---
$withNM = New-MockScanResults
[void]$withNM.Junk.Add([PSCustomObject]@{Name = 'node_modules'; FullPath = 'C:\project\node_modules'; Size = 500MB; SizeText = '500 MB'; ItemType = 'Folder'; Reason = 'Junk: node_modules' })
[void]$withNM.Junk.Add([PSCustomObject]@{Name = 'node_modules'; FullPath = 'C:\project2\node_modules'; Size = 300MB; SizeText = '300 MB'; ItemType = 'Folder'; Reason = 'Junk: node_modules' })
$recs = Get-SmartRecommendations $withNM
$nmRec = $recs | Where-Object { $_.Category -eq 'Dev Junk' }
Assert-NotNull $nmRec "Detects node_modules as Dev Junk"
Assert-Equal 'HIGH' $nmRec.Priority "node_modules recommendation is HIGH priority"
Assert-True ($nmRec.Message -like '*2 node_modules*') "Message mentions count"

# --- Old files detection (MEDIUM priority) ---
$withOld = New-MockScanResults
for ($i = 0; $i -lt 10; $i++) {
    [void]$withOld.OldFiles.Add([PSCustomObject]@{Name = "old$i.txt"; FullPath = "C:\test\old$i.txt"; Size = 1MB; SizeText = '1.0 MB'; AccessDays = 800; AgeDays = 800 })
}
$recs = Get-SmartRecommendations $withOld
$oldRec = $recs | Where-Object { $_.Category -eq 'Old Files' }
Assert-NotNull $oldRec "Detects old files (2+ years)"
Assert-Equal 'MEDIUM' $oldRec.Priority "Old files recommendation is MEDIUM priority"
Assert-GreaterThan $oldRec.Savings 0 "Old files savings > 0"

# --- Large junk detection (MEDIUM priority) ---
$withBigJunk = New-MockScanResults
[void]$withBigJunk.Junk.Add([PSCustomObject]@{Name = 'huge.dmp'; FullPath = 'C:\test\huge.dmp'; Size = 50MB; SizeText = '50 MB'; ItemType = 'File'; Reason = 'Pattern: *.dmp' })
[void]$withBigJunk.Junk.Add([PSCustomObject]@{Name = 'big.tmp'; FullPath = 'C:\test\big.tmp'; Size = 20MB; SizeText = '20 MB'; ItemType = 'File'; Reason = 'Pattern: *.tmp' })
$recs = Get-SmartRecommendations $withBigJunk
$bigRec = $recs | Where-Object { $_.Category -eq 'Large Junk' }
Assert-NotNull $bigRec "Detects large junk files (>=10MB)"
Assert-Equal 'MEDIUM' $bigRec.Priority "Large junk is MEDIUM priority"

# --- Empty directories detection (LOW priority) ---
$withEmpty = New-MockScanResults
for ($i = 0; $i -lt 15; $i++) {
    [void]$withEmpty.Empty.Add([PSCustomObject]@{Name = "empty$i"; FullPath = "C:\test\empty$i"; Created = '2025-01-01' })
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
    [void]$fewEmpty.Empty.Add([PSCustomObject]@{Name = "e$i"; FullPath = "C:\test\e$i"; Created = '2025-01-01' })
}
$recs = Get-SmartRecommendations $fewEmpty
$noEmptyRec = $recs | Where-Object { $_.Category -eq 'Empty Dirs' }
Assert-True ($null -eq $noEmptyRec) "No recommendation for < 10 empty dirs"

# Old files less than 730 days â†’ no recommendation
$notOldEnough = New-MockScanResults
[void]$notOldEnough.OldFiles.Add([PSCustomObject]@{Name = 'recent.txt'; FullPath = 'C:\test\recent.txt'; Size = 1MB; SizeText = '1.0 MB'; AccessDays = 100; AgeDays = 100 })
$recs = Get-SmartRecommendations $notOldEnough
$noOldRec = $recs | Where-Object { $_.Category -eq 'Old Files' }
Assert-True ($null -eq $noOldRec) "No recommendation for files < 730 days old"

# --- Combined scenario ---
$combined = New-MockScanResults
[void]$combined.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'AAAA'; Name = 'a.txt'; FullPath = 'C:\a.txt'; Size = 10MB; SizeText = '10 MB' })
[void]$combined.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'AAAA'; Name = 'b.txt'; FullPath = 'C:\b.txt'; Size = 10MB; SizeText = '10 MB' })
[void]$combined.Junk.Add([PSCustomObject]@{Name = 'node_modules'; FullPath = 'C:\nm'; Size = 200MB; SizeText = '200 MB'; ItemType = 'Folder'; Reason = 'Junk' })
for ($i = 0; $i -lt 12; $i++) {
    [void]$combined.Empty.Add([PSCustomObject]@{Name = "e$i"; FullPath = "C:\e$i"; Created = '2025-01-01' })
}
$recs = Get-SmartRecommendations $combined
Assert-GreaterThan @($recs).Count 1 "Combined scenario returns 2+ recommendations"

# ========================================
# v4.2: NEW SMARTCLEAN RULES
# ========================================
Write-Host "    --- v4.2: New SmartClean Rules ---" -ForegroundColor DarkCyan

# Huge files (>1GB) detection
$withHuge = New-MockScanResults
[void]$withHuge.Large.Add([PSCustomObject]@{Name = 'vm.vhd'; FullPath = 'C:\test\vm.vhd'; Size = 2GB; SizeText = '2 GB' })
[void]$withHuge.Large.Add([PSCustomObject]@{Name = 'backup.iso'; FullPath = 'C:\test\backup.iso'; Size = 4GB; SizeText = '4 GB' })
$recs = Get-SmartRecommendations $withHuge
$hugeRec = $recs | Where-Object { $_.Category -eq 'Huge Files' }
Assert-NotNull $hugeRec "v4.2: detects huge files (>1GB)"
Assert-Equal 'HIGH' $hugeRec.Priority "v4.2: huge files is HIGH priority"

# Broken files detection
$withBroken = New-MockScanResults
$withBroken.Broken = [System.Collections.ArrayList]::new()
[void]$withBroken.Broken.Add([PSCustomObject]@{Name = 'bad.jpg'; FullPath = 'C:\test\bad.jpg'; Size = 5MB; SizeText = '5 MB' })
$recs = Get-SmartRecommendations $withBroken
$brokenRec = $recs | Where-Object { $_.Category -eq 'Broken Files' }
Assert-NotNull $brokenRec "v4.2: detects broken files"
Assert-Equal 'HIGH' $brokenRec.Priority "v4.2: broken files is HIGH priority"

# Python cache detection
$withPyc = New-MockScanResults
for ($i = 0; $i -lt 8; $i++) {
    [void]$withPyc.Junk.Add([PSCustomObject]@{Name = '__pycache__'; FullPath = "C:\proj\__pycache__$i"; Size = 2MB; SizeText = '2 MB'; ItemType = 'Folder'; Reason = 'Junk' })
}
$recs = Get-SmartRecommendations $withPyc
$pycRec = $recs | Where-Object { $_.Category -eq 'Dev Junk' }
Assert-NotNull $pycRec "v4.2: detects Python cache as Dev Junk"

# Aging files (1-2 years)
$withAging = New-MockScanResults
for ($i = 0; $i -lt 15; $i++) {
    [void]$withAging.OldFiles.Add([PSCustomObject]@{Name = "aging$i.doc"; FullPath = "C:\test\aging$i.doc"; Size = 500KB; SizeText = '500 KB'; AccessDays = 500; AgeDays = 500 })
}
$recs = Get-SmartRecommendations $withAging
$agingRec = $recs | Where-Object { $_.Category -eq 'Aging Files' }
Assert-NotNull $agingRec "v4.2: detects aging files (1-2yr)"
Assert-Equal 'MEDIUM' $agingRec.Priority "v4.2: aging files is MEDIUM priority"

# Temp/log files
$withLogs = New-MockScanResults
for ($i = 0; $i -lt 5; $i++) {
    [void]$withLogs.Large.Add([PSCustomObject]@{Name = "file$i.log"; FullPath = "C:\test\file$i.log"; Size = 10MB; SizeText = '10 MB' })
}
$recs = Get-SmartRecommendations $withLogs
$logRec = $recs | Where-Object { $_.Category -eq 'Temp/Log Files' }
Assert-NotNull $logRec "v4.2: detects temp/log files"
Assert-Equal 'MEDIUM' $logRec.Priority "v4.2: log files is MEDIUM priority"

# Duplicate images
$withDupImg = New-MockScanResults
[void]$withDupImg.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'IMG1'; Name = 'photo.jpg'; FullPath = 'C:\pics\photo.jpg'; Size = 3MB; SizeText = '3 MB' })
[void]$withDupImg.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'IMG1'; Name = 'photo_copy.jpg'; FullPath = 'C:\pics\photo_copy.jpg'; Size = 3MB; SizeText = '3 MB' })
$recs = Get-SmartRecommendations $withDupImg
$imgRec = $recs | Where-Object { $_.Category -eq 'Duplicate Images' }
Assert-NotNull $imgRec "v4.2: detects duplicate images"

# Zero-byte files
$withZero = New-MockScanResults
for ($i = 0; $i -lt 8; $i++) {
    [void]$withZero.Large.Add([PSCustomObject]@{Name = "empty$i.dat"; FullPath = "C:\test\empty$i.dat"; Size = 0; SizeText = '0 B' })
}
$recs = Get-SmartRecommendations $withZero
$zeroRec = $recs | Where-Object { $_.Category -eq 'Zero-Byte' }
Assert-NotNull $zeroRec "v4.2: detects zero-byte files"
Assert-Equal 'LOW' $zeroRec.Priority "v4.2: zero-byte is LOW priority"

# Desktop clutter
$withDesktop = New-MockScanResults
for ($i = 0; $i -lt 35; $i++) {
    [void]$withDesktop.Large.Add([PSCustomObject]@{Name = "file$i.doc"; FullPath = "C:\Users\test\Desktop\file$i.doc"; Size = 1MB; SizeText = '1 MB' })
}
$recs = Get-SmartRecommendations $withDesktop
$deskRec = $recs | Where-Object { $_.Category -eq 'Desktop Clutter' }
Assert-NotNull $deskRec "v4.2: detects desktop clutter (30+ files)"
Assert-Equal 'LOW' $deskRec.Priority "v4.2: desktop clutter is LOW priority"

# Downloads large files
$withDL = New-MockScanResults
[void]$withDL.Large.Add([PSCustomObject]@{Name = 'setup.exe'; FullPath = "C:\Users\test\Downloads\setup.exe"; Size = 500MB; SizeText = '500 MB' })
$recs = Get-SmartRecommendations $withDL
$dlRec = $recs | Where-Object { $_.Category -eq 'Downloads' }
Assert-NotNull $dlRec "v4.2: detects large downloads"
Assert-Equal 'LOW' $dlRec.Priority "v4.2: large downloads is LOW priority"

# Summary row
$withAll = New-MockScanResults
[void]$withAll.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'X'; Name = 'a.txt'; FullPath = 'C:\a.txt'; Size = 10MB; SizeText = '10 MB' })
[void]$withAll.Dups.Add([PSCustomObject]@{GroupId = 1; Hash = 'X'; Name = 'b.txt'; FullPath = 'C:\b.txt'; Size = 10MB; SizeText = '10 MB' })
[void]$withAll.Junk.Add([PSCustomObject]@{Name = 'node_modules'; FullPath = 'C:\nm'; Size = 200MB; SizeText = '200 MB'; ItemType = 'Folder'; Reason = 'Junk' })
$recs = Get-SmartRecommendations $withAll
$summary = $recs | Where-Object { $_.Priority -eq 'SUMMARY' }
Assert-NotNull $summary "v4.2: has SUMMARY row"
Assert-GreaterThan $summary.Savings 0 "v4.2: SUMMARY has total savings"

# ========================================
# v4.2: SETTINGS PERSISTENCE
# ========================================
Write-Host "    --- v4.2: Settings Persistence ---" -ForegroundColor DarkCyan
$mainScript = Get-Content (Join-Path (Split-Path $PSScriptRoot) 'DiskCleanerPro.ps1') -Raw

Assert-True ($mainScript -match 'settingsFile') "v4.2: has settingsFile variable"
Assert-True ($mainScript -match 'Load-AppSettings') "v4.2: has Load-AppSettings function"
Assert-True ($mainScript -match 'Save-AppSettings') "v4.2: has Save-AppSettings function"
Assert-True ($mainScript -match 'settings\.json') "v4.2: uses settings.json file"
Assert-True ($mainScript -match 'Window\.Add_Closing') "v4.2: saves settings on window close"
Assert-True ($mainScript -match 'ConvertTo-Json') "v4.2: serializes to JSON"
Assert-True ($mainScript -match 'ConvertFrom-Json') "v4.2: deserializes from JSON"
Assert-True ($mainScript -match 'LastScanPath') "v4.2: persists last scan path"
Assert-True ($mainScript -match 'LastOrgPath') "v4.2: persists last organize path"
Assert-True ($mainScript -match 'WindowWidth') "v4.2: persists window width"
Assert-True ($mainScript -match 'WindowHeight') "v4.2: persists window height"

# Functional test: write and read settings JSON
$testSettingsDir = Join-Path $env:TEMP "dcp_test_settings_$(Get-Random)"
$testSettingsFile = Join-Path $testSettingsDir 'settings.json'
New-Item $testSettingsDir -ItemType Directory -Force | Out-Null
$testSettings = @{ LastScanPath = 'C:\TestPath'; LastOrgPath = 'C:\TestOrg'; WindowWidth = 1200; WindowHeight = 800 }
$testSettings | ConvertTo-Json | Set-Content $testSettingsFile -Force
$loaded = Get-Content $testSettingsFile -Raw | ConvertFrom-Json
Assert-Equal 'C:\TestPath' $loaded.LastScanPath "v4.2: settings round-trip LastScanPath"
Assert-Equal 'C:\TestOrg' $loaded.LastOrgPath "v4.2: settings round-trip LastOrgPath"
Assert-Equal 1200 $loaded.WindowWidth "v4.2: settings round-trip WindowWidth"
Assert-Equal 800 $loaded.WindowHeight "v4.2: settings round-trip WindowHeight"
Remove-Item $testSettingsDir -Recurse -Force -EA SilentlyContinue

