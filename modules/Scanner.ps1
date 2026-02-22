# DiskCleaner Pro v3.0 - Scanner Module
# Core scanning logic: large files, duplicates (multi-tier), junk files, empty folders, file age

function FmtSize([long]$b) {
    if ($b -ge 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -ge 1MB) { return "{0:N1} MB" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N0} KB" -f ($b / 1KB) }
    return "$b B"
}

function Measure-TargetSize($target) {
    $size = 0L; $count = 0
    try {
        if (Test-Path $target.Path) {
            $items = Get-ChildItem -Path $target.Path -Filter $target.Pattern -Recurse -Force -EA SilentlyContinue |
            Where-Object { -not $_.PSIsContainer }
            foreach ($f in $items) { $size += $f.Length; $count++ }
        }
    }
    catch {}
    return @{Size = $size; Count = $count }
}

$Script:JunkPatterns = @('*.tmp', '*.temp', '*.log', '*.bak', '*.old', '*.cache', '*.dmp', 'Thumbs.db', 'desktop.ini', '.DS_Store', '*.crdownload', '*.partial', '~$*', '*.swp', '*.chk', '*.gid', '*.wbk')
$Script:JunkFolderNames = @('node_modules', '__pycache__', '.cache', '.tmp', 'obj', 'coverage', '.nyc_output', '.pytest_cache', 'bin\Debug', 'bin\Release', '.vs', '.gradle', 'build\intermediates')

function Invoke-DiskScan {
    param([string]$ScanPath, [hashtable]$Shared)

    [System.Threading.Thread]::CurrentThread.Priority = 'BelowNormal'

    function UpdUI([string]$txt, [int]$pct) {
        $Shared.Window.Dispatcher.Invoke([action] {
                $Shared.UI['lblAnalyzerProgress'].Text = $txt
                $Shared.UI['analyzerProgressFill'].Width = [math]::Max(0, [math]::Min(400, $pct * 4))
            })
    }

    $r = @{
        Files = [System.Collections.ArrayList]::new()
        Large = [System.Collections.ArrayList]::new()
        Dups = [System.Collections.ArrayList]::new()
        Junk = [System.Collections.ArrayList]::new()
        Empty = [System.Collections.ArrayList]::new()
        OldFiles = [System.Collections.ArrayList]::new()
        FolderSizes = [System.Collections.ArrayList]::new()
        Ext = @{}; Total = [long]0; FC = 0; DC = 0
    }
    $dirs = [System.Collections.ArrayList]::new()
    $topDirs = @{}

    # PHASE 1: SCAN ALL FILES
    UpdUI "Phase 1/7: Starting file scan..." 2
    Get-ChildItem -Path $ScanPath -Recurse -Force -EA SilentlyContinue | ForEach-Object {
        if ($_.PSIsContainer) {
            $r.DC++
            $cc = @(Get-ChildItem $_.FullName -Force -EA SilentlyContinue).Count
            [void]$dirs.Add([PSCustomObject]@{FullPath = $_.FullName; Name = $_.Name; CC = $cc; Created = $_.CreationTime.ToString('yyyy-MM-dd HH:mm'); Parent = $_.Parent.FullName })
            if ($r.DC % 20 -eq 0) {
                $p = $_.FullName
                if ($p.Length -gt 55) { $p = '...' + $p.Substring($p.Length - 52) }
                UpdUI "Phase 1/7: $($r.FC) files, $($r.DC) folders ($(FmtSize $r.Total))  |  $p" ([math]::Min(25, 2 + $r.FC / 1000))
            }
        }
        else {
            $r.FC++; $r.Total += $_.Length
            $ext = if ($_.Extension) { $_.Extension.ToLower() }else { '(none)' }
            if ($r.Ext.ContainsKey($ext)) { $r.Ext[$ext].C++; $r.Ext[$ext].S += $_.Length }else { $r.Ext[$ext] = @{C = 1; S = $_.Length } }
            $st = FmtSize $_.Length
            $ageDays = [math]::Round(([DateTime]::Now - $_.LastWriteTime).TotalDays)
            $accessDays = [math]::Round(([DateTime]::Now - $_.LastAccessTime).TotalDays)
            $f = [PSCustomObject]@{
                Name = $_.Name; FullPath = $_.FullName; Directory = $_.DirectoryName; Extension = $ext
                Size = $_.Length; SizeText = $st; Modified = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                LastAccess = $_.LastAccessTime.ToString('yyyy-MM-dd HH:mm')
                AgeDays = $ageDays; AccessDays = $accessDays; AgeText = "$ageDays days"; Hash = ''
            }
            [void]$r.Files.Add($f)

            $rel = $_.FullName.Substring($ScanPath.TrimEnd('\').Length + 1)
            $topKey = $rel.Split('\')[0]
            if ($topKey) { if ($topDirs.ContainsKey($topKey)) { $topDirs[$topKey] += $_.Length }else { $topDirs[$topKey] = $_.Length } }

            if ($r.FC % 50 -eq 0) {
                [System.Threading.Thread]::Sleep(1)
                $p = $_.DirectoryName
                if ($p.Length -gt 55) { $p = '...' + $p.Substring($p.Length - 52) }
                UpdUI "Phase 1/7: $($r.FC) files, $($r.DC) folders ($(FmtSize $r.Total))  |  $p" ([math]::Min(25, 2 + $r.FC / 1000))
            }
        }
    }

    # PHASE 2: LARGE FILES (>=10MB)
    UpdUI "Phase 2/7: Finding large files (>10MB) among $($r.FC) files..." 30
    $r.Files | Where-Object { $_.Size -ge 10MB } | Sort-Object Size -Descending | Select-Object -First 200 | ForEach-Object { [void]$r.Large.Add($_) }

    # PHASE 3: MULTI-TIER DUPLICATES
    UpdUI "Phase 3/7: Grouping $($r.FC) files by size for duplicates..." 35
    $sg = $r.Files | Where-Object { $_.Size -gt 0 -and $_.Size -ge 1KB } | Group-Object Size | Where-Object { $_.Count -gt 1 }
    $gid = 1; $hc = 0; $totalGroups = $sg.Count; $gi = 0
    foreach ($g in $sg) {
        $gi++
        $ht = @{}
        foreach ($f in $g.Group) {
            $hc++
            if ($hc % 100 -eq 0) { UpdUI "Phase 3/7: Hashing file $hc (group $gi/$totalGroups)..." ([math]::Min(55, 35 + $gi / $totalGroups * 20)) }
            if ($hc % 50 -eq 0) { [System.Threading.Thread]::Sleep(1) }
            try {
                $stream = [System.IO.File]::OpenRead($f.FullPath)
                $buf = New-Object byte[] 4096
                $read = $stream.Read($buf, 0, 4096); $stream.Close()
                $md5 = [System.Security.Cryptography.MD5]::Create()
                $h = [BitConverter]::ToString($md5.ComputeHash($buf, 0, $read)).Replace('-', '')
                if ($ht.ContainsKey($h)) { $ht[$h] += @($f) }else { $ht[$h] = @($f) }
            }
            catch {}
        }
        foreach ($p in $ht.GetEnumerator()) {
            if ($p.Value.Count -le 1) { continue }
            $fh = @{}
            foreach ($f in $p.Value) {
                try { $h = (Get-FileHash $f.FullPath -Algorithm MD5 -EA Stop).Hash; $f.Hash = $h.Substring(0, 8); if ($fh.ContainsKey($h)) { $fh[$h] += @($f) }else { $fh[$h] = @($f) } }catch {}
            }
            foreach ($q in $fh.GetEnumerator()) {
                if ($q.Value.Count -gt 1) {
                    foreach ($d in $q.Value) { [void]$r.Dups.Add([PSCustomObject]@{GroupId = $gid; Hash = $q.Key.Substring(0, 16); Name = $d.Name; FullPath = $d.FullPath; Size = $d.Size; SizeText = $d.SizeText }) }
                    $gid++
                }
            }
        }
    }

    # PHASE 4: JUNK FILES
    UpdUI "Phase 4/7: Finding junk files and folders..." 65
    foreach ($f in $r.Files) { foreach ($p in $Script:JunkPatterns) { if ($f.Name -like $p) { [void]$r.Junk.Add([PSCustomObject]@{Name = $f.Name; FullPath = $f.FullPath; Size = $f.Size; SizeText = $f.SizeText; ItemType = 'File'; Reason = "Pattern: $p" }); break } } }
    foreach ($d in $dirs) {
        if ($Script:JunkFolderNames -contains $d.Name) {
            $fs = ($r.Files | Where-Object { $_.FullPath.StartsWith($d.FullPath + '\') } | Measure-Object Size -Sum).Sum
            if ($null -eq $fs) { $fs = 0 }
            [void]$r.Junk.Add([PSCustomObject]@{Name = $d.Name; FullPath = $d.FullPath; Size = $fs; SizeText = FmtSize $fs; ItemType = 'Folder'; Reason = "Junk: $($d.Name)" })
        }
    }

    # PHASE 5: OLD FILES (>90 days)
    UpdUI "Phase 5/7: Finding files older than 90 days..." 75
    $r.Files | Where-Object { $_.AccessDays -gt 90 -and $_.Size -ge 1KB } | Sort-Object AccessDays -Descending | Select-Object -First 500 | ForEach-Object { [void]$r.OldFiles.Add($_) }

    # PHASE 6: EMPTY FOLDERS
    UpdUI "Phase 6/7: Finding empty folders among $($r.DC) directories..." 85
    foreach ($d in $dirs) { if ($d.CC -eq 0) { [void]$r.Empty.Add([PSCustomObject]@{Name = $d.Name; FullPath = $d.FullPath; Created = $d.Created }) } }

    # PHASE 7: FOLDER SIZES
    UpdUI "Phase 7/7: Calculating top folder sizes..." 92
    $topDirs.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30 | ForEach-Object {
        [void]$r.FolderSizes.Add([PSCustomObject]@{Name = $_.Key; Size = $_.Value; SizeText = FmtSize $_.Value; FullPath = (Join-Path $ScanPath $_.Key) })
    }

    UpdUI "Scan complete! $($r.FC) files, $(FmtSize $r.Total)" 100
    return $r
}
