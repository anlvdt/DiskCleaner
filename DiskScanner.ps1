<#
.SYNOPSIS
    DiskCleaner Pro - Scanner Script
.DESCRIPTION
    Quét thư mục, phát hiện file lớn, file trùng lặp, thư mục rỗng, file rác.
    Xuất kết quả JSON cho giao diện web.
.AUTHOR
    Le Van An (@anlvdt)
.VERSION
    1.0.0
#>

param(
    [string]$ScanPath = ".",
    [string]$OutputFile = "",
    [int]$TopLargeFiles = 100,
    [long]$LargeFileThresholdMB = 50,
    [switch]$SkipHash,
    [switch]$Quick
)

# ===== CONFIGURATION =====
$JunkPatterns = @(
    '*.tmp', '*.temp', '*.log', '*.bak', '*.old', '*.cache',
    '*.dmp', '*.crash', 'Thumbs.db', 'desktop.ini', '.DS_Store',
    '*.crdownload', '*.partial', '~$*', '*.swp', '*.swo'
)
$JunkFolders = @(
    'node_modules', '.git', '__pycache__', '.cache', '.tmp',
    'bin\Debug', 'bin\Release', 'obj', '.vs', '.idea',
    'build', 'dist', '.next', '.nuxt', '.output',
    'coverage', '.nyc_output', '.pytest_cache',
    'Thumbs.db:encryptable', '$RECYCLE.BIN', 'System Volume Information'
)
$TempFolders = @(
    "$env:TEMP", "$env:TMP",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
)

# ===== INIT =====
$ErrorActionPreference = 'SilentlyContinue'
$ScanPath = (Resolve-Path $ScanPath).Path
if (-not $OutputFile) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputFile = Join-Path $ScanPath "DiskCleaner_Scan_$timestamp.json"
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     DiskCleaner Pro - Scanner v1.0    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Scan Path   : $ScanPath" -ForegroundColor White
Write-Host "  Output File : $OutputFile" -ForegroundColor White
Write-Host "  Large File  : >= $($LargeFileThresholdMB) MB" -ForegroundColor White
Write-Host "  Hash Mode   : $(if ($SkipHash) { 'SKIP' } else { 'MD5' })" -ForegroundColor White
Write-Host ""

# ===== SCAN FILES =====
Write-Host "  [1/6] Scanning files..." -ForegroundColor Yellow -NoNewline
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$allFiles = @()
$allDirs = @()
$totalSize = 0
$fileCount = 0
$dirCount = 0
$extensionStats = @{}

Get-ChildItem -Path $ScanPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSIsContainer) {
        $dirCount++
        $allDirs += [PSCustomObject]@{
            Path = $_.FullName
            Name = $_.Name
            ChildCount = (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count
            CreatedDate = $_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')
            ModifiedDate = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
    } else {
        $fileCount++
        $totalSize += $_.Length
        $ext = if ($_.Extension) { $_.Extension.ToLower() } else { '(no ext)' }
        
        if ($extensionStats.ContainsKey($ext)) {
            $extensionStats[$ext].Count++
            $extensionStats[$ext].Size += $_.Length
        } else {
            $extensionStats[$ext] = @{ Count = 1; Size = $_.Length }
        }
        
        $allFiles += [PSCustomObject]@{
            Path = $_.FullName
            RelPath = $_.FullName.Substring($ScanPath.Length).TrimStart('\')
            Name = $_.Name
            Extension = $ext
            Size = $_.Length
            CreatedDate = $_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')
            ModifiedDate = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            Directory = $_.DirectoryName
        }
        
        if ($fileCount % 1000 -eq 0) {
            Write-Host "`r  [1/6] Scanning files... $fileCount files found" -ForegroundColor Yellow -NoNewline
        }
    }
}
Write-Host "`r  [1/6] Scanning files... $fileCount files, $dirCount folders ✓" -ForegroundColor Green

# ===== BUILD TREE =====
Write-Host "  [2/6] Building directory tree..." -ForegroundColor Yellow -NoNewline

function Build-Tree {
    param([string]$RootPath, [array]$Files)
    
    $tree = @{
        name = (Split-Path $RootPath -Leaf)
        path = $RootPath
        size = 0
        children = @()
    }
    
    $dirGroups = $Files | Group-Object { Split-Path $_.Path -Parent }
    $dirSizes = @{}
    
    foreach ($file in $Files) {
        $dir = $file.Directory
        while ($dir -and $dir.StartsWith($RootPath)) {
            if (-not $dirSizes.ContainsKey($dir)) { $dirSizes[$dir] = 0 }
            $dirSizes[$dir] += $file.Size
            $parentDir = Split-Path $dir -Parent
            if ($parentDir -eq $dir) { break }
            $dir = $parentDir
        }
    }
    
    # Build first level children only (for treemap performance)
    $firstLevel = Get-ChildItem -Path $RootPath -Force -ErrorAction SilentlyContinue
    foreach ($item in $firstLevel) {
        if ($item.PSIsContainer) {
            $childSize = if ($dirSizes.ContainsKey($item.FullName)) { $dirSizes[$item.FullName] } else { 0 }
            $childFiles = $Files | Where-Object { $_.Path.StartsWith($item.FullName + '\') }
            $subChildren = @()
            
            # Second level for drill-down
            $secondLevel = Get-ChildItem -Path $item.FullName -Force -ErrorAction SilentlyContinue
            foreach ($sub in $secondLevel) {
                if ($sub.PSIsContainer) {
                    $subSize = if ($dirSizes.ContainsKey($sub.FullName)) { $dirSizes[$sub.FullName] } else { 0 }
                    if ($subSize -gt 0) {
                        $subChildren += @{
                            name = $sub.Name
                            path = $sub.FullName
                            size = $subSize
                            type = 'directory'
                        }
                    }
                } else {
                    $subChildren += @{
                        name = $sub.Name
                        path = $sub.FullName
                        size = $sub.Length
                        type = 'file'
                        ext = if ($sub.Extension) { $sub.Extension.ToLower() } else { '' }
                    }
                }
            }
            
            if ($childSize -gt 0) {
                $tree.children += @{
                    name = $item.Name
                    path = $item.FullName
                    size = $childSize
                    type = 'directory'
                    children = $subChildren
                }
            }
        } else {
            $tree.children += @{
                name = $item.Name
                path = $item.FullName
                size = $item.Length
                type = 'file'
                ext = if ($item.Extension) { $item.Extension.ToLower() } else { '' }
            }
        }
    }
    
    $tree.size = $totalSize
    return $tree
}

$tree = Build-Tree -RootPath $ScanPath -Files $allFiles
Write-Host "`r  [2/6] Building directory tree... ✓         " -ForegroundColor Green

# ===== FIND LARGE FILES =====
Write-Host "  [3/6] Finding large files..." -ForegroundColor Yellow -NoNewline
$thresholdBytes = $LargeFileThresholdMB * 1MB
$largeFiles = $allFiles | Where-Object { $_.Size -ge $thresholdBytes } | Sort-Object Size -Descending | Select-Object -First $TopLargeFiles
$largeFilesList = @()
foreach ($f in $largeFiles) {
    $largeFilesList += @{
        path = $f.Path
        relPath = $f.RelPath
        name = $f.Name
        size = $f.Size
        sizeMB = [math]::Round($f.Size / 1MB, 2)
        ext = $f.Extension
        modified = $f.ModifiedDate
    }
}
Write-Host "`r  [3/6] Finding large files... $($largeFilesList.Count) found ✓" -ForegroundColor Green

# ===== FIND DUPLICATES =====
Write-Host "  [4/6] Finding duplicates..." -ForegroundColor Yellow -NoNewline
$duplicates = @()

if (-not $SkipHash) {
    # Group by size first (quick filter)
    $sizeGroups = $allFiles | Where-Object { $_.Size -gt 0 } | Group-Object Size | Where-Object { $_.Count -gt 1 }
    $hashCount = 0
    $totalToHash = ($sizeGroups | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    
    foreach ($group in $sizeGroups) {
        $hashes = @{}
        foreach ($file in $group.Group) {
            $hashCount++
            if ($hashCount % 100 -eq 0) {
                Write-Host "`r  [4/6] Finding duplicates... hashing $hashCount/$totalToHash" -ForegroundColor Yellow -NoNewline
            }
            try {
                $hash = (Get-FileHash -Path $file.Path -Algorithm MD5 -ErrorAction Stop).Hash
                if ($hashes.ContainsKey($hash)) {
                    $hashes[$hash] += @($file)
                } else {
                    $hashes[$hash] = @($file)
                }
            } catch { }
        }
        
        foreach ($h in $hashes.GetEnumerator()) {
            if ($h.Value.Count -gt 1) {
                $dupGroup = @()
                foreach ($d in $h.Value) {
                    $dupGroup += @{
                        path = $d.Path
                        relPath = $d.RelPath
                        name = $d.Name
                        size = $d.Size
                        sizeMB = [math]::Round($d.Size / 1MB, 2)
                        modified = $d.ModifiedDate
                    }
                }
                $duplicates += @{
                    hash = $h.Key
                    size = $h.Value[0].Size
                    sizeMB = [math]::Round($h.Value[0].Size / 1MB, 2)
                    count = $h.Value.Count
                    wastedMB = [math]::Round(($h.Value[0].Size * ($h.Value.Count - 1)) / 1MB, 2)
                    files = $dupGroup
                }
            }
        }
    }
}

$totalWastedMB = ($duplicates | ForEach-Object { $_.wastedMB } | Measure-Object -Sum).Sum
Write-Host "`r  [4/6] Finding duplicates... $($duplicates.Count) groups, $([math]::Round($totalWastedMB, 1)) MB wasted ✓" -ForegroundColor Green

# ===== FIND JUNK FILES =====
Write-Host "  [5/6] Finding junk files..." -ForegroundColor Yellow -NoNewline
$junkFiles = @()
$junkFoldersFound = @()

# Junk files by pattern
foreach ($file in $allFiles) {
    foreach ($pattern in $JunkPatterns) {
        if ($file.Name -like $pattern) {
            $junkFiles += @{
                path = $file.Path
                relPath = $file.RelPath
                name = $file.Name
                size = $file.Size
                sizeMB = [math]::Round($file.Size / 1MB, 2)
                reason = "Matches junk pattern: $pattern"
            }
            break
        }
    }
}

# Junk folders
foreach ($dir in $allDirs) {
    foreach ($jf in $JunkFolders) {
        if ($dir.Name -eq $jf -or $dir.Path -like "*\$jf" -or $dir.Path -like "*\$jf\*") {
            $folderSize = ($allFiles | Where-Object { $_.Path.StartsWith($dir.Path + '\') } | Measure-Object -Property Size -Sum).Sum
            if ($null -eq $folderSize) { $folderSize = 0 }
            $junkFoldersFound += @{
                path = $dir.Path
                name = $dir.Name
                sizeMB = [math]::Round($folderSize / 1MB, 2)
                reason = "Known junk folder: $jf"
            }
            break
        }
    }
}

$junkTotalMB = [math]::Round((($junkFiles | ForEach-Object { $_.size } | Measure-Object -Sum).Sum + 
    ($junkFoldersFound | ForEach-Object { $_.sizeMB * 1MB } | Measure-Object -Sum).Sum) / 1MB, 1)
Write-Host "`r  [5/6] Finding junk files... $($junkFiles.Count) files, $($junkFoldersFound.Count) folders ✓" -ForegroundColor Green

# ===== FIND EMPTY FOLDERS =====
Write-Host "  [6/6] Finding empty folders..." -ForegroundColor Yellow -NoNewline
$emptyFolders = @()
foreach ($dir in $allDirs) {
    if ($dir.ChildCount -eq 0) {
        $emptyFolders += @{
            path = $dir.Path
            name = $dir.Name
            created = $dir.CreatedDate
        }
    }
}
Write-Host "`r  [6/6] Finding empty folders... $($emptyFolders.Count) found ✓" -ForegroundColor Green

# ===== EXTENSION STATS =====
$extStats = @()
foreach ($e in ($extensionStats.GetEnumerator() | Sort-Object { $_.Value.Size } -Descending | Select-Object -First 30)) {
    $extStats += @{
        ext = $e.Key
        count = $e.Value.Count
        size = $e.Value.Size
        sizeMB = [math]::Round($e.Value.Size / 1MB, 2)
    }
}

# ===== BUILD RESULT =====
$sw.Stop()
$result = @{
    meta = @{
        scanPath = $ScanPath
        scanDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        scanDuration = "$([math]::Round($sw.Elapsed.TotalSeconds, 1))s"
        version = '1.0.0'
        computerName = $env:COMPUTERNAME
        userName = $env:USERNAME
    }
    summary = @{
        totalFiles = $fileCount
        totalFolders = $dirCount
        totalSizeBytes = $totalSize
        totalSizeMB = [math]::Round($totalSize / 1MB, 1)
        totalSizeGB = [math]::Round($totalSize / 1GB, 2)
        largeFilesCount = $largeFilesList.Count
        largeFilesTotalMB = [math]::Round(($largeFilesList | ForEach-Object { $_.size } | Measure-Object -Sum).Sum / 1MB, 1)
        duplicateGroups = $duplicates.Count
        duplicateWastedMB = [math]::Round($totalWastedMB, 1)
        junkFilesCount = $junkFiles.Count
        junkFoldersCount = $junkFoldersFound.Count
        emptyFoldersCount = $emptyFolders.Count
    }
    tree = $tree
    largeFiles = $largeFilesList
    duplicates = ($duplicates | Sort-Object { $_.wastedMB } -Descending)
    junkFiles = $junkFiles
    junkFolders = $junkFoldersFound
    emptyFolders = $emptyFolders
    extensionStats = $extStats
}

# ===== EXPORT JSON =====
Write-Host ""
Write-Host "  Exporting results..." -ForegroundColor Yellow -NoNewline
$result | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $OutputFile -Encoding utf8
$jsonSize = [math]::Round((Get-Item $OutputFile).Length / 1KB, 1)
Write-Host "`r  Exporting results... $OutputFile ($($jsonSize) KB) ✓" -ForegroundColor Green

# ===== SUMMARY =====
Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║          SCAN RESULTS SUMMARY         ║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  Total Files    : $($fileCount.ToString().PadLeft(10))       ║" -ForegroundColor White
Write-Host "  ║  Total Folders  : $($dirCount.ToString().PadLeft(10))       ║" -ForegroundColor White
Write-Host "  ║  Total Size     : $("$([math]::Round($totalSize/1GB,2)) GB".PadLeft(10))       ║" -ForegroundColor White
Write-Host "  ║  Large Files    : $($largeFilesList.Count.ToString().PadLeft(10))       ║" -ForegroundColor $(if ($largeFilesList.Count -gt 0) { 'Red' } else { 'White' })
Write-Host "  ║  Duplicates     : $($duplicates.Count.ToString().PadLeft(10))       ║" -ForegroundColor $(if ($duplicates.Count -gt 0) { 'Red' } else { 'White' })
Write-Host "  ║  Junk Files     : $($junkFiles.Count.ToString().PadLeft(10))       ║" -ForegroundColor $(if ($junkFiles.Count -gt 0) { 'Yellow' } else { 'White' })
Write-Host "  ║  Junk Folders   : $($junkFoldersFound.Count.ToString().PadLeft(10))       ║" -ForegroundColor $(if ($junkFoldersFound.Count -gt 0) { 'Yellow' } else { 'White' })
Write-Host "  ║  Empty Folders  : $($emptyFolders.Count.ToString().PadLeft(10))       ║" -ForegroundColor $(if ($emptyFolders.Count -gt 0) { 'Yellow' } else { 'White' })
Write-Host "  ║  Scan Time      : $($sw.Elapsed.TotalSeconds.ToString('0.0').PadLeft(8))s       ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Open index.html in browser and import:" -ForegroundColor White
Write-Host "  $OutputFile" -ForegroundColor Green
Write-Host ""
