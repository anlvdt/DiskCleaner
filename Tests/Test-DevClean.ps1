# Test-DevClean.ps1 - DevClean Module Tests
# Tests: DevTargets definition, Invoke-DevScan, Get-DevScanSummary

$modPath = Join-Path (Split-Path $PSScriptRoot) 'modules'
. (Join-Path $modPath 'Scanner.ps1')  # FmtSize dependency
. (Join-Path $modPath 'DevClean.ps1')
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Write-Host "  [DevClean Module]" -ForegroundColor Cyan

# --- DevTargets definition ---
$targets = $Script:DevTargets
Assert-NotNull $targets "DevTargets is defined"
Assert-GreaterThan $targets.Count 30 "32+ dev target types defined"

# Check required properties
$allValid = $true
foreach ($t in $targets) {
    if (-not $t.Name -or -not $t.Category -or -not $t.Color -or -not $t.Pattern -or -not $t.Type) {
        $allValid = $false; break
    }
}
Assert-True $allValid "All targets have Name, Category, Color, Pattern, Type"

# Check categories
$categories = $targets | ForEach-Object { $_.Category } | Select-Object -Unique
Assert-Contains $categories 'Dependencies' "Has Dependencies category"
Assert-Contains $categories 'Build' "Has Build category"
Assert-Contains $categories 'Cache' "Has Cache category"
Assert-Contains $categories 'Coverage' "Has Coverage category"
Assert-Contains $categories 'IDE' "Has IDE category"
Assert-Contains $categories 'Logs' "Has Logs category"
Assert-Contains $categories 'Infrastructure' "Has Infrastructure category"

# Check specific critical targets
$names = $targets | ForEach-Object { $_.Name }
Assert-Contains $names 'node_modules' "Has node_modules target"
Assert-Contains $names '.pnpm' "Has .pnpm target"
Assert-Contains $names 'bower_components' "Has bower_components target"
Assert-Contains $names 'venv' "Has venv target"
Assert-Contains $names '.venv' "Has .venv target"
Assert-Contains $names 'dist' "Has dist target"
Assert-Contains $names 'build' "Has build target"
Assert-Contains $names '.next' "Has .next target"
Assert-Contains $names '.nuxt' "Has .nuxt target"
Assert-Contains $names 'target' "Has target (Rust/Maven)"
Assert-Contains $names 'bin\Debug' "Has bin\Debug (.NET)"
Assert-Contains $names 'bin\Release' "Has bin\Release (.NET)"
Assert-Contains $names 'obj' "Has obj (.NET)"
Assert-Contains $names '.cache' "Has .cache target"
Assert-Contains $names '.turbo' "Has .turbo target"
Assert-Contains $names '__pycache__' "Has __pycache__ target"
Assert-Contains $names '.eslintcache' "Has .eslintcache target"
Assert-Contains $names 'coverage' "Has coverage target"
Assert-Contains $names '.vs' "Has .vs (Visual Studio)"
Assert-Contains $names '.idea' "Has .idea (JetBrains)"
Assert-Contains $names '.gradle' "Has .gradle target"
Assert-Contains $names '.terraform' "Has .terraform (FIXED)"
Assert-Contains $names 'Pods' "Has Pods (iOS)"
Assert-Contains $names '.cargo' "Has .cargo (Rust)"
Assert-Contains $names '.metals' "Has .metals (Scala)"
Assert-Contains $names '.bsp' "Has .bsp (Scala BSP)"

# Check .terraform is in Infrastructure category
$tf = $targets | Where-Object { $_.Name -eq '.terraform' }
Assert-Equal 'Infrastructure' $tf.Category ".terraform is in Infrastructure category"
Assert-Equal '#06b6d4' $tf.Color ".terraform has correct color (Cyan)"

# Check colors are valid hex
$allHex = $true
foreach ($t in $targets) { if ($t.Color -notmatch '^#[0-9a-fA-F]{6}$') { $allHex = $false; break } }
Assert-True $allHex "All targets have valid hex color codes"

# --- Invoke-DevScan with sandbox ---
$sandbox = New-TestSandbox
$project1 = Join-Path $sandbox 'myapp'
$nm = Join-Path $project1 'node_modules'
$nmPkg = Join-Path $nm 'lodash'
New-Item $nmPkg -ItemType Directory -Force | Out-Null
Set-Content (Join-Path $nmPkg 'index.js') "module.exports = function() { return true; }"

$project2 = Join-Path $sandbox 'pyproject'
$pycache = Join-Path $project2 '__pycache__'
New-Item $pycache -ItemType Directory -Force | Out-Null
Set-Content (Join-Path $pycache 'module.pyc') "compiled python"

$project3 = Join-Path $sandbox 'dotnet'
$objDir = Join-Path $project3 'obj'
New-Item $objDir -ItemType Directory -Force | Out-Null
Set-Content (Join-Path $objDir 'project.nuget.cache') "nuget cache"

$results = Invoke-DevScan -ScanPath $sandbox -MaxDepth 3
Assert-NotNull $results "Invoke-DevScan returns results"
Assert-GreaterThan $results.Count 0 "Found dev artifacts in sandbox"

$foundNames = @($results | ForEach-Object { $_.Name })
Assert-Contains $foundNames 'node_modules' "Found node_modules artifact"
Assert-Contains $foundNames '__pycache__' "Found __pycache__ artifact"
Assert-Contains $foundNames 'obj' "Found obj artifact"

# Check result properties
$first = $results[0]
Assert-NotNull $first.FullPath "Result has FullPath"
Assert-NotNull $first.Category "Result has Category"
Assert-NotNull $first.Color "Result has Color"
Assert-NotNull $first.SizeText "Result has SizeText"
Assert-NotNull $first.Parent "Result has Parent"

# --- MaxDepth respect ---
$deep = Join-Path $sandbox 'a\b\c\d\e\f\g\node_modules'
New-Item $deep -ItemType Directory -Force | Out-Null
Set-Content (Join-Path $deep 'pkg.json') "{}"
$shallow = Invoke-DevScan -ScanPath $sandbox -MaxDepth 2
$deepFound = $shallow | Where-Object { $_.FullPath -like '*a\b\c*' }
Assert-Equal 0 @($deepFound).Count "MaxDepth=2 does not find deeply nested artifacts"

# --- Get-DevScanSummary ---
$summary = Get-DevScanSummary $results
Assert-NotNull $summary "Get-DevScanSummary returns summary"
Assert-True ($summary.ContainsKey('Dependencies') -or $summary.ContainsKey('Cache')) "Summary has category groupings"

# Check summary structure
foreach ($kv in $summary.GetEnumerator()) {
    Assert-True ($kv.Value.Count -ge 1) "Category '$($kv.Key)' has Count >= 1"
    Assert-True ($null -ne $kv.Value.Color) "Category '$($kv.Key)' has Color"
}

# Cleanup
Remove-TestSandbox $sandbox

