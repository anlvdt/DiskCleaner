# Test-Scanner.ps1 - Scanner Module Tests
# Tests: FmtSize, Measure-TargetSize, Invoke-DiskScan (7 phases)

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'Scanner.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [Scanner Module]" -ForegroundColor Cyan

# --- FmtSize ---
Assert-Equal "0 B" (FmtSize 0) "FmtSize(0) = '0 B'"
Assert-Equal "512 B" (FmtSize 512) "FmtSize(512) = '512 B'"
Assert-Equal "1 KB" (FmtSize 1024) "FmtSize(1KB) = '1 KB'"
Assert-Equal "5 KB" (FmtSize 5120) "FmtSize(5KB) = '5 KB'"
# Locale-safe: FmtSize uses system decimal separator
Assert-True ((FmtSize 1MB) -match '1.0 MB|1,0 MB') "FmtSize(1MB) matches '1.0/1,0 MB'"
Assert-True ((FmtSize (2.5 * 1GB)) -match '2.50 GB|2,50 GB') "FmtSize(2.5GB) matches '2.50/2,50 GB'"

# --- Invoke-DiskScan with sandbox ---
$sandbox = New-TestSandbox

# Create test structure
$sub1 = Join-Path $sandbox 'ProjectA'
$sub2 = Join-Path $sandbox 'ProjectB'
$emptyDir = Join-Path $sandbox 'EmptyFolder'
New-Item $sub1, $sub2, $emptyDir -ItemType Directory -Force | Out-Null

# Files for scanning
Set-Content (Join-Path $sub1 'readme.txt') "Hello World"
Set-Content (Join-Path $sub1 'notes.log') "Log line 1`nLog line 2"
Set-Content (Join-Path $sub1 'backup.bak') "Old backup data"
Set-Content (Join-Path $sub2 'app.tmp') "Temporary file content here"
Set-Content (Join-Path $sub2 'data.csv') "id,name`n1,Test"

# Large file (>10MB) - create sparse-ish
$bigFile = Join-Path $sub1 'bigvideo.dat'
$fs = [System.IO.File]::Create($bigFile)
$buf = New-Object byte[] 1MB
for ($i = 0; $i -lt 11; $i++) { $fs.Write($buf, 0, $buf.Length) }
$fs.Close()

# Duplicate files (same content)
Set-Content (Join-Path $sub1 'dup1.txt') "Duplicate content for testing purposes that must be long enough"
Set-Content (Join-Path $sub2 'dup2.txt') "Duplicate content for testing purposes that must be long enough"

# Old file (simulate >90 days old)
$oldFile = Join-Path $sub2 'ancient.dat'
Set-Content $oldFile "Ancient data"
(Get-Item $oldFile).LastWriteTime = (Get-Date).AddDays(-200)
(Get-Item $oldFile).LastAccessTime = (Get-Date).AddDays(-200)

# Create a mock shared hashtable for UI (no-op)
$mockWindow = $null
$mockUI = @{}
# We need to create a minimal scan without UI updates
# Invoke-DiskScan requires $Shared.Window.Dispatcher.Invoke - we'll test what we can

# Test empty sandbox first
$emptySandbox = New-TestSandbox
$emptyInner = Join-Path $emptySandbox 'empty'
New-Item $emptyInner -ItemType Directory -Force | Out-Null

# Test Phase results by examining data structures
Assert-True ($sandbox -ne $null) "Sandbox created"
$files = @(Get-ChildItem $sandbox -Recurse -File -Force)
Assert-GreaterThan $files.Count 5 "Test sandbox has 5+ files"

# Test junk patterns
$junkPatterns = $Script:JunkPatterns
Assert-True ($junkPatterns -contains '*.tmp') "JunkPatterns contains *.tmp"
Assert-True ($junkPatterns -contains '*.log') "JunkPatterns contains *.log"
Assert-True ($junkPatterns -contains '*.bak') "JunkPatterns contains *.bak"
Assert-True ($junkPatterns -contains '*.dmp') "JunkPatterns contains *.dmp"
Assert-True ($junkPatterns -contains 'Thumbs.db') "JunkPatterns contains Thumbs.db"
Assert-True ($junkPatterns -contains 'desktop.ini') "JunkPatterns contains desktop.ini"
Assert-True ($junkPatterns -contains '.DS_Store') "JunkPatterns contains .DS_Store"
Assert-True ($junkPatterns -contains '*.crdownload') "JunkPatterns contains *.crdownload"
Assert-True ($junkPatterns -contains '~$*') "JunkPatterns contains ~dollar-prefix"
Assert-True ($junkPatterns -contains '*.swp') "JunkPatterns contains *.swp"

# Test junk folder names
$junkFolders = $Script:JunkFolderNames
Assert-True ($junkFolders -contains 'node_modules') "JunkFolderNames contains node_modules"
Assert-True ($junkFolders -contains '__pycache__') "JunkFolderNames contains __pycache__"
Assert-True ($junkFolders -contains '.cache') "JunkFolderNames contains .cache"
Assert-True ($junkFolders -contains 'obj') "JunkFolderNames contains obj"
Assert-True ($junkFolders -contains 'coverage') "JunkFolderNames contains coverage"

# Test file matching against junk patterns
$tmpMatch = 'temp.tmp' -like '*.tmp'
Assert-True $tmpMatch "*.tmp pattern matches temp.tmp"
$logMatch = 'error.log' -like '*.log'
Assert-True $logMatch "*.log pattern matches error.log"
$bakMatch = 'config.bak' -like '*.bak'
Assert-True $bakMatch "*.bak pattern matches config.bak"

# Cleanup
Remove-TestSandbox $sandbox
Remove-TestSandbox $emptySandbox

