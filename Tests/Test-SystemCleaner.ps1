# Test-SystemCleaner.ps1 - SystemCleaner Module Tests
# Tests: Get-SystemJunkTargets, Measure-TargetSize, Invoke-CleanTarget

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'SystemCleaner.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [SystemCleaner Module]" -ForegroundColor Cyan

# --- Get-SystemJunkTargets (non-admin) ---
$userTargets = Get-SystemJunkTargets
Assert-NotNull $userTargets "Get-SystemJunkTargets returns non-null"
Assert-GreaterThan $userTargets.Count 10 "Non-admin returns 10+ targets"

# Check required properties on all targets
$allHaveProps = $true
foreach ($t in $userTargets) {
    if (-not $t.Name -or -not $t.Path -or -not $t.Pattern -or -not $t.Desc) { $allHaveProps = $false; break }
}
Assert-True $allHaveProps "All targets have Name, Path, Pattern, Desc"

# Check all targets are marked safe
$allSafe = $true
foreach ($t in $userTargets) { if (-not $t.Safe) { $allSafe = $false; break } }
Assert-True $allSafe "All targets have Safe=true"

# Check specific targets exist
$names = $userTargets | ForEach-Object { $_.Name }
Assert-Contains $names 'User Temp Files' "Has 'User Temp Files' target"
Assert-Contains $names 'Windows Temp' "Has 'Windows Temp' target"
Assert-Contains $names 'Thumbnail Cache' "Has 'Thumbnail Cache' target"
Assert-Contains $names 'Icon Cache' "Has 'Icon Cache' target"
Assert-Contains $names 'Crash Dumps (User)' "Has 'Crash Dumps (User)' target"
Assert-Contains $names 'DirectX Shader Cache' "Has 'DirectX Shader Cache' target"
Assert-Contains $names 'Activity Timeline' "Has 'Activity Timeline' target"
Assert-Contains $names 'Defender Temp Files' "Has 'Defender Temp Files' target"

# Browser targets
Assert-Contains $names 'Chrome Cache' "Has 'Chrome Cache' target"
Assert-Contains $names 'Edge Cache' "Has 'Edge Cache' target"
Assert-Contains $names 'Firefox Cache' "Has 'Firefox Cache' (FIXED)"
Assert-Contains $names 'Chrome Code Cache' "Has 'Chrome Code Cache' target"
Assert-Contains $names 'Edge Code Cache' "Has 'Edge Code Cache' target"
Assert-Contains $names 'Firefox Code Cache' "Has 'Firefox Code Cache' (FIXED)"

# Dev cache targets
Assert-Contains $names 'npm Cache' "Has 'npm Cache' target"
Assert-Contains $names 'pip Cache' "Has 'pip Cache' target"
Assert-Contains $names 'NuGet Cache' "Has 'NuGet Cache' target"

# Browser targets should have IsBrowser flag
$browserTargets = $userTargets | Where-Object { $_.ContainsKey('IsBrowser') -and $_.IsBrowser }
Assert-GreaterThan $browserTargets.Count 3 "3+ browser targets with IsBrowser flag"

# Firefox target path check
$ffCache = $userTargets | Where-Object { $_.Name -eq 'Firefox Cache' }
Assert-NotNull $ffCache "Firefox Cache target found"
if ($ffCache) {
    Assert-Equal 'cache2' $ffCache.Pattern "Firefox Cache pattern is 'cache2'"
    Assert-True ($ffCache.Path -like '*Mozilla*Firefox*Profiles*') "Firefox path contains Mozilla/Firefox/Profiles"
}

# Icon Cache NoRecurse flag
$iconCache = $userTargets | Where-Object { $_.Name -eq 'Icon Cache' }
Assert-NotNull $iconCache "Icon Cache target found"
if ($iconCache) {
    Assert-True $iconCache.NoRecurse "Icon Cache has NoRecurse=true"
}

# --- Get-SystemJunkTargets (admin) ---
$adminTargets = Get-SystemJunkTargets -AdminMode
Assert-GreaterThan $adminTargets.Count $userTargets.Count "Admin mode returns more targets"

$adminNames = $adminTargets | ForEach-Object { $_.Name }
Assert-Contains $adminNames 'Windows Update Cache' "Admin has 'Windows Update Cache'"
Assert-Contains $adminNames 'Prefetch' "Admin has 'Prefetch'"
Assert-Contains $adminNames 'Font Cache' "Admin has 'Font Cache'"
Assert-Contains $adminNames 'Delivery Optimization' "Admin has 'Delivery Optimization' (FIXED)"
Assert-Contains $adminNames 'Event Logs' "Admin has 'Event Logs' (FIXED)"
Assert-Contains $adminNames 'CBS Logs' "Admin has 'CBS Logs' (FIXED)"
Assert-Contains $adminNames 'DISM Logs' "Admin has 'DISM Logs' (FIXED)"

# --- Measure-TargetSize with sandbox ---
$sandbox = New-TestSandbox
Set-Content (Join-Path $sandbox 'test1.tmp') "Test content one"
Set-Content (Join-Path $sandbox 'test2.tmp') "Test content two"
Set-Content (Join-Path $sandbox 'keep.txt') "Keep this"

$size = Measure-TargetSize @{Path = $sandbox; Pattern = '*.tmp' }
Assert-GreaterThan $size.Count 0 "Measure-TargetSize finds .tmp files"
Assert-GreaterThan $size.Size 0 "Measure-TargetSize returns size > 0"

# Non-existent path
$noSize = Measure-TargetSize @{Path = 'C:\NonExistentPath12345'; Pattern = '*' }
Assert-Equal 0 $noSize.Size "Non-existent path returns Size=0"
Assert-Equal 0 $noSize.Count "Non-existent path returns Count=0"

# NoRecurse mode
$subDir = Join-Path $sandbox 'sub'
New-Item $subDir -ItemType Directory -Force | Out-Null
Set-Content (Join-Path $subDir 'nested.tmp') "Nested"
$noRecurse = Measure-TargetSize @{Path = $sandbox; Pattern = '*.tmp'; NoRecurse = $true }
Assert-Equal 2 $noRecurse.Count "NoRecurse mode finds only top-level files"

# --- Invoke-CleanTarget ---
$cleanSandbox = New-TestSandbox
Set-Content (Join-Path $cleanSandbox 'del1.tmp') "Delete me"
Set-Content (Join-Path $cleanSandbox 'del2.tmp') "Delete me too"
$beforeCount = @(Get-ChildItem $cleanSandbox -File).Count

$cr = Invoke-CleanTarget @{Path = $cleanSandbox; Pattern = '*.tmp' }
Assert-GreaterThan $cr.Cleaned 0 "Invoke-CleanTarget cleaned bytes > 0"
$afterCount = @(Get-ChildItem $cleanSandbox -Filter '*.tmp' -File).Count
Assert-Equal 0 $afterCount "All .tmp files removed after cleaning"

# Cleanup
Remove-TestSandbox $sandbox
Remove-TestSandbox $cleanSandbox

# ========================================
# v4.2: EXPANDED TARGETS (57+)
# ========================================
Write-Host "    --- v4.2: Expanded Targets ---" -ForegroundColor DarkCyan
$allTargets = Get-SystemJunkTargets -AdminMode
Assert-GreaterThan $allTargets.Count 50 "v4.2: 50+ total targets (admin mode)"

$allNames = $allTargets | ForEach-Object { $_.Name }

# GPU shader caches
Assert-Contains $allNames 'NVIDIA Shader Cache' "v4.2: has NVIDIA Shader Cache"
Assert-Contains $allNames 'AMD Shader Cache' "v4.2: has AMD Shader Cache"
Assert-Contains $allNames 'Intel Shader Cache' "v4.2: has Intel Shader Cache"
Assert-Contains $allNames 'NVIDIA GL Cache' "v4.2: has NVIDIA GL Cache"

# New browsers
Assert-Contains $allNames 'Brave Cache' "v4.2: has Brave Cache"
Assert-Contains $allNames 'Opera Cache' "v4.2: has Opera Cache"
Assert-Contains $allNames 'Vivaldi Cache' "v4.2: has Vivaldi Cache"
Assert-Contains $allNames 'Chrome GPU Cache' "v4.2: has Chrome GPU Cache"
Assert-Contains $allNames 'Edge GPU Cache' "v4.2: has Edge GPU Cache"

# New dev caches
Assert-Contains $allNames 'Yarn Cache' "v4.2: has Yarn Cache"
Assert-Contains $allNames 'pnpm Store' "v4.2: has pnpm Store"
Assert-Contains $allNames 'Go Module Cache' "v4.2: has Go Module Cache"
Assert-Contains $allNames 'Gradle Cache' "v4.2: has Gradle Cache"
Assert-Contains $allNames 'Maven Cache' "v4.2: has Maven Cache"

# New app caches
Assert-Contains $allNames 'Telegram Cache' "v4.2: has Telegram Cache"
Assert-Contains $allNames 'WhatsApp Cache' "v4.2: has WhatsApp Cache"
Assert-Contains $allNames 'Notion Cache' "v4.2: has Notion Cache"
Assert-Contains $allNames 'Figma Cache' "v4.2: has Figma Cache"
Assert-Contains $allNames 'Postman Cache' "v4.2: has Postman Cache"

# New user-level system targets
Assert-Contains $allNames 'OneDrive Cache' "v4.2: has OneDrive Cache"
Assert-Contains $allNames 'Outlook Temp' "v4.2: has Outlook Temp"
Assert-Contains $allNames 'MS Office Cache' "v4.2: has MS Office Cache"
Assert-Contains $allNames '.NET Temp' "v4.2: has .NET Temp"
Assert-Contains $allNames 'Java Cache' "v4.2: has Java Cache"

# New admin targets
Assert-Contains $allNames 'Setup API Logs' "v4.2: has Setup API Logs (admin)"
Assert-Contains $allNames 'Windows Installer Cache' "v4.2: has Windows Installer Cache (admin)"
Assert-Contains $allNames 'System Panther' "v4.2: has System Panther (admin)"

# Non-admin should still exclude admin targets
$nonAdminTargets = Get-SystemJunkTargets
$nonAdminNames = $nonAdminTargets | ForEach-Object { $_.Name }
$hasAdminOnly = $nonAdminNames -contains 'Setup API Logs'
Assert-True (-not $hasAdminOnly) "v4.2: non-admin excludes admin-only targets"

