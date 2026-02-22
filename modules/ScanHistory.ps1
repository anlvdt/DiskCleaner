# DiskCleaner Pro v2.0 - Scan Comparison Module
# Save scan snapshots, compare with previous scans

$Script:HistoryDir = Join-Path $env:APPDATA 'DiskCleanerPro\history'

function Save-ScanSnapshot {
    param($ScanResults, [string]$ScanPath)
    if (-not (Test-Path $Script:HistoryDir)) { New-Item $Script:HistoryDir -ItemType Directory -Force | Out-Null }
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $snap = @{
        Timestamp = (Get-Date).ToString('o')
        Path = $ScanPath
        TotalFiles = $ScanResults.FC
        TotalSize = $ScanResults.Total
        LargeCount = $ScanResults.Large.Count
        DupGroups = ($ScanResults.Dups | Select-Object GroupId -Unique).Count
        JunkCount = $ScanResults.Junk.Count
        EmptyCount = $ScanResults.Empty.Count
        OldCount = $ScanResults.OldFiles.Count
        TopFolders = @{}
        ExtBreakdown = @{}
    }
    foreach ($fs in $ScanResults.FolderSizes) { $snap.TopFolders[$fs.Name] = $fs.Size }
    foreach ($kv in $ScanResults.Ext.GetEnumerator()) { $snap.ExtBreakdown[$kv.Key] = @{C=$kv.Value.C;S=$kv.Value.S} }

    $file = Join-Path $Script:HistoryDir "$ts`_$(($ScanPath -replace '[\\:/]','_').TrimEnd('_')).json"
    $snap | ConvertTo-Json -Depth 5 | Set-Content $file -Encoding UTF8
    return $file
}

function Get-ScanHistory {
    if (-not (Test-Path $Script:HistoryDir)) { return @() }
    Get-ChildItem $Script:HistoryDir -Filter '*.json' | Sort-Object Name -Descending | ForEach-Object {
        try {
            $d = Get-Content $_.FullName -Raw | ConvertFrom-Json
            [PSCustomObject]@{
                File = $_.FullName
                Timestamp = $d.Timestamp
                Date = ([datetime]$d.Timestamp).ToString('yyyy-MM-dd HH:mm')
                Path = $d.Path
                Files = $d.TotalFiles
                Size = $d.TotalSize
                SizeText = FmtSize $d.TotalSize
            }
        } catch {}
    }
}

function Compare-Scans {
    param([string]$OldFile, $CurrentResults, [string]$CurrentPath)
    try { $old = Get-Content $OldFile -Raw | ConvertFrom-Json } catch { return $null }

    $delta = [System.Collections.ArrayList]::new()
    $sizeDiff = $CurrentResults.Total - $old.TotalSize
    $fileDiff = $CurrentResults.FC - $old.TotalFiles

    [void]$delta.Add([PSCustomObject]@{Metric='Total Size';Previous=FmtSize $old.TotalSize;Current=FmtSize $CurrentResults.Total;Change=("$(if($sizeDiff -ge 0){'+'})$(FmtSize $sizeDiff)")})
    [void]$delta.Add([PSCustomObject]@{Metric='Total Files';Previous=$old.TotalFiles.ToString('N0');Current=$CurrentResults.FC.ToString('N0');Change=("$(if($fileDiff -ge 0){'+'}else{''})$fileDiff")})

    $dupDiff = ($CurrentResults.Dups | Select-Object GroupId -Unique).Count - $old.DupGroups
    [void]$delta.Add([PSCustomObject]@{Metric='Duplicate Groups';Previous=$old.DupGroups;Current=($CurrentResults.Dups|Select-Object GroupId -Unique).Count;Change="$(if($dupDiff -ge 0){'+'}else{''})$dupDiff"})

    $junkDiff = $CurrentResults.Junk.Count - $old.JunkCount
    [void]$delta.Add([PSCustomObject]@{Metric='Junk Files';Previous=$old.JunkCount;Current=$CurrentResults.Junk.Count;Change="$(if($junkDiff -ge 0){'+'}else{''})$junkDiff"})

    # Folder size changes
    $currentFolders = @{}
    foreach ($fs in $CurrentResults.FolderSizes) { $currentFolders[$fs.Name] = $fs.Size }
    if ($old.TopFolders) {
        $old.TopFolders.PSObject.Properties | ForEach-Object {
            $name = $_.Name; $oldSize = [long]$_.Value
            $newSize = if ($currentFolders.ContainsKey($name)) { $currentFolders[$name] } else { 0 }
            $diff = $newSize - $oldSize
            if ([math]::Abs($diff) -ge 1MB) {
                [void]$delta.Add([PSCustomObject]@{Metric="Folder: $name";Previous=FmtSize $oldSize;Current=FmtSize $newSize;Change="$(if($diff -ge 0){'+'})$(FmtSize $diff)"})
            }
        }
    }

    return @{Delta=$delta;SizeDiff=$sizeDiff;FileDiff=$fileDiff;OldDate=([datetime]$old.Timestamp).ToString('yyyy-MM-dd HH:mm')}
}
