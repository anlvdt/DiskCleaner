# Test-BrokenFiles.ps1 - BrokenFiles Module Tests
# Tests: Find-BrokenFiles (empty files, magic byte mismatch, broken symlinks)

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'BrokenFiles.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [BrokenFiles Module]" -ForegroundColor Cyan

# --- Magic Bytes Dictionary ---
$magic = $Script:MagicBytes
Assert-NotNull $magic "MagicBytes dictionary is defined"
Assert-GreaterThan $magic.Count 15 "15+ magic byte signatures defined"

# Check specific formats
Assert-True ($magic.ContainsKey('.jpg')) "Has .jpg signature"
Assert-True ($magic.ContainsKey('.jpeg')) "Has .jpeg signature"
Assert-True ($magic.ContainsKey('.png')) "Has .png signature"
Assert-True ($magic.ContainsKey('.gif')) "Has .gif signature"
Assert-True ($magic.ContainsKey('.bmp')) "Has .bmp signature"
Assert-True ($magic.ContainsKey('.pdf')) "Has .pdf signature"
Assert-True ($magic.ContainsKey('.zip')) "Has .zip signature"
Assert-True ($magic.ContainsKey('.rar')) "Has .rar signature"
Assert-True ($magic.ContainsKey('.7z')) "Has .7z signature"
Assert-True ($magic.ContainsKey('.exe')) "Has .exe signature"
Assert-True ($magic.ContainsKey('.dll')) "Has .dll signature"
Assert-True ($magic.ContainsKey('.mp3')) "Has .mp3 signature"
Assert-True ($magic.ContainsKey('.mp4')) "Has .mp4 signature"
Assert-True ($magic.ContainsKey('.wav')) "Has .wav signature"
Assert-True ($magic.ContainsKey('.docx')) "Has .docx signature (PK ZIP)"
Assert-True ($magic.ContainsKey('.xlsx')) "Has .xlsx signature (PK ZIP)"
Assert-True ($magic.ContainsKey('.pptx')) "Has .pptx signature (PK ZIP)"

# Verify known magic bytes
Assert-Equal 0xFF $magic['.jpg'][0] "JPG starts with 0xFF"
Assert-Equal 0xD8 $magic['.jpg'][1] "JPG second byte 0xD8"
Assert-Equal 0x89 $magic['.png'][0] "PNG starts with 0x89"
Assert-Equal 0x50 $magic['.png'][1] "PNG second byte 0x50 (P)"
Assert-Equal 0x25 $magic['.pdf'][0] "PDF starts with 0x25 (%)"
Assert-Equal 0x50 $magic['.zip'][0] "ZIP starts with 0x50 (P)"
Assert-Equal 0x4B $magic['.zip'][1] "ZIP second byte 0x4B (K)"
Assert-Equal 0x4D $magic['.exe'][0] "EXE starts with 0x4D (M)"
Assert-Equal 0x5A $magic['.exe'][1] "EXE second byte 0x5A (Z)"

# --- Find-BrokenFiles with sandbox ---
$sandbox = New-TestSandbox

# Create test files
# 1. Empty file (0 bytes)
$emptyFile = Join-Path $sandbox 'empty.txt'
New-Item $emptyFile -ItemType File -Force | Out-Null

# 2. Valid PNG file (correct magic bytes)
$validPng = Join-Path $sandbox 'valid.png'
$pngHeader = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52)
[System.IO.File]::WriteAllBytes($validPng, $pngHeader)

# 3. Mismatched file (PNG header but .jpg extension)
$mismatch = Join-Path $sandbox 'notreally.jpg'
[System.IO.File]::WriteAllBytes($mismatch, $pngHeader)

# 4. Valid JPG file
$validJpg = Join-Path $sandbox 'photo.jpg'
$jpgHeader = [byte[]]@(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46)
[System.IO.File]::WriteAllBytes($validJpg, $jpgHeader)

# 5. Normal text file (no magic check)
$normalTxt = Join-Path $sandbox 'normal.txt'
Set-Content $normalTxt "This is normal text content that should not be flagged"

# 6. PDF with wrong header (actually text)
$fakePdf = Join-Path $sandbox 'fake.pdf'
Set-Content $fakePdf "This is not actually a PDF file"

# Build ScanFiles list (mock file objects like Scanner produces)
$scanFiles = @()
Get-ChildItem $sandbox -File -Force | ForEach-Object {
    $ext = if ($_.Extension) { $_.Extension.ToLower() } else { '(none)' }
    $scanFiles += [PSCustomObject]@{
        Name = $_.Name; FullPath = $_.FullName; Directory = $_.DirectoryName
        Extension = $ext; Size = $_.Length; SizeText = "$($_.Length) B"
    }
}

$broken = Find-BrokenFiles $scanFiles

Assert-NotNull $broken "Find-BrokenFiles returns results"
Assert-GreaterThan $broken.Count 0 "Found broken files"

# Check empty file detection
$emptyResult = $broken | Where-Object { $_.Category -eq 'Empty' }
Assert-NotNull $emptyResult "Detects empty files"
if ($emptyResult) {
    Assert-Equal 'empty.txt' $emptyResult.Name "Empty file name is correct"
    Assert-Equal 0 $emptyResult.Size "Empty file size is 0"
    Assert-True ($emptyResult.Issue -like '*Empty*0*') "Issue mentions empty/0 bytes"
}

# Check mismatch detection
$mismatchResults = @($broken | Where-Object { $_.Category -eq 'Mismatch' })
Assert-GreaterThan $mismatchResults.Count 0 "Detects extension mismatch(es)"
$jpgMismatch = $mismatchResults | Where-Object { $_.Name -eq 'notreally.jpg' }
if ($jpgMismatch) {
    Assert-Equal 'notreally.jpg' $jpgMismatch.Name "Mismatch file name is correct"
    Assert-True ($jpgMismatch.Issue -like '*.jpg*') "Issue mentions expected extension"
    Assert-True ($jpgMismatch.Issue -like '*.png*') "Issue mentions actual type"
}

# Check valid files are NOT flagged
$validJpgBroken = @($broken | Where-Object { $_.Name -eq 'photo.jpg' })
Assert-Equal 0 $validJpgBroken.Count "Valid JPG is NOT flagged as broken"

$validPngBroken = @($broken | Where-Object { $_.Name -eq 'valid.png' })
Assert-Equal 0 $validPngBroken.Count "Valid PNG is NOT flagged as broken"

$normalBroken = @($broken | Where-Object { $_.Name -eq 'normal.txt' })
Assert-Equal 0 $normalBroken.Count "Normal text file is NOT flagged"

# Check fake PDF detection
$fakePdfResult = $broken | Where-Object { $_.Name -eq 'fake.pdf' }
Assert-NotNull $fakePdfResult "Detects fake PDF (text content in .pdf)"

# Check result properties
if ($broken.Count -gt 0) {
    $firstBroken = $broken[0]
    Assert-NotNull $firstBroken.Name "Broken result has Name"
    Assert-NotNull $firstBroken.FullPath "Broken result has FullPath"
    Assert-NotNull $firstBroken.Issue "Broken result has Issue"
    Assert-NotNull $firstBroken.Category "Broken result has Category"
}

# Cleanup
Remove-TestSandbox $sandbox

