# DiskCleaner Pro - Test Runner
# Runs all test files and reports results
# Usage: powershell -ExecutionPolicy Bypass -File Tests\Run-AllTests.ps1

param([switch]$Verbose)

$ErrorActionPreference = 'Continue'
$script:VerboseTests = $Verbose.IsPresent

# Load helpers
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$script:TotalPass = 0; $script:TotalFail = 0; $script:TotalSkip = 0

# ===== MAIN =====
$startTime = [DateTime]::Now
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  DiskCleaner Pro - Test Suite" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$testDir = $PSScriptRoot
$testFiles = @(
    'Test-Scanner.ps1'
    'Test-SystemCleaner.ps1'
    'Test-DevClean.ps1'
    'Test-SmartClean.ps1'
    'Test-SafeGuard.ps1'
    'Test-BrokenFiles.ps1'
    'Test-ScanHistory.ps1'
    'Test-FolderOrganizer.ps1'
)

foreach ($tf in $testFiles) {
    $path = Join-Path $testDir $tf
    if (Test-Path $path) {
        $beforePass = $script:TotalPass; $beforeFail = $script:TotalFail
        Write-Host "Running $tf..." -ForegroundColor White
        try {
            . $path
        } catch {
            Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $script:TotalFail++
        }
        $p = $script:TotalPass - $beforePass; $f = $script:TotalFail - $beforeFail
        $color = if ($f -eq 0) { 'Green' } else { 'Red' }
        Write-Host "  Result: $p passed, $f failed" -ForegroundColor $color
        Write-Host ""
    } else {
        Write-Host "MISSING: $tf" -ForegroundColor Red
    }
}

$elapsed = [math]::Round(([DateTime]::Now - $startTime).TotalSeconds, 1)
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  TOTAL: $($script:TotalPass) passed, $($script:TotalFail) failed, $($script:TotalSkip) skipped ($elapsed s)" -ForegroundColor $(if ($script:TotalFail -eq 0) { 'Green' } else { 'Red' })
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

exit $script:TotalFail
