# DiskCleaner Pro - Test Assertion Helpers
# Sourced by all test files. Contains assertion functions and sandbox utilities.

$script:TotalPass = if ($null -eq $script:TotalPass) { 0 } else { $script:TotalPass }
$script:TotalFail = if ($null -eq $script:TotalFail) { 0 } else { $script:TotalFail }
$script:TotalSkip = if ($null -eq $script:TotalSkip) { 0 } else { $script:TotalSkip }

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:TotalPass++
        if ($script:VerboseTests) { Write-Host "    PASS: $Message" -ForegroundColor Green }
    } else {
        $script:TotalFail++
        Write-Host "    FAIL: $Message" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ("$Expected" -eq "$Actual") {
        $script:TotalPass++
        if ($script:VerboseTests) { Write-Host "    PASS: $Message" -ForegroundColor Green }
    } else {
        $script:TotalFail++
        Write-Host "    FAIL: $Message (expected='$Expected', got='$Actual')" -ForegroundColor Red
    }
}

function Assert-NotNull {
    param($Value, [string]$Message)
    if ($null -ne $Value) {
        $script:TotalPass++
        if ($script:VerboseTests) { Write-Host "    PASS: $Message" -ForegroundColor Green }
    } else {
        $script:TotalFail++
        Write-Host "    FAIL: $Message (value is null)" -ForegroundColor Red
    }
}

function Assert-GreaterThan {
    param([long]$Value, [long]$Threshold, [string]$Message)
    if ($Value -gt $Threshold) {
        $script:TotalPass++
        if ($script:VerboseTests) { Write-Host "    PASS: $Message" -ForegroundColor Green }
    } else {
        $script:TotalFail++
        Write-Host "    FAIL: $Message (value=$Value, threshold=$Threshold)" -ForegroundColor Red
    }
}

function Assert-Contains {
    param($Collection, $Item, [string]$Message)
    if ($Collection -contains $Item) {
        $script:TotalPass++
        if ($script:VerboseTests) { Write-Host "    PASS: $Message" -ForegroundColor Green }
    } else {
        $script:TotalFail++
        Write-Host "    FAIL: $Message ('$Item' not found)" -ForegroundColor Red
    }
}

function Skip-Test {
    param([string]$Message)
    $script:TotalSkip++
    Write-Host "    SKIP: $Message" -ForegroundColor Yellow
}

function New-TestSandbox {
    $path = Join-Path $env:TEMP "DiskCleaner_Test_$(Get-Random)"
    New-Item $path -ItemType Directory -Force | Out-Null
    return $path
}

function Remove-TestSandbox([string]$Path) {
    if ($Path -and (Test-Path $Path) -and $Path.StartsWith($env:TEMP)) {
        Remove-Item $Path -Recurse -Force -EA SilentlyContinue
    }
}
