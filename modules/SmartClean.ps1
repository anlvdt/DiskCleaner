# DiskCleaner Pro v2.0 - Smart Clean Module
# One-click safe cleanup + recommendations

# FmtSize defined here so this module is self-contained (no dependency on Scanner.ps1)
function FmtSize([long]$b) {
    if ($b -ge 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -ge 1MB) { return "{0:N1} MB" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N0} KB" -f ($b / 1KB) }
    return "$b B"
}

function Get-SmartRecommendations {
    param($ScanResults)
    $recs = [System.Collections.ArrayList]::new()
    $dg = ($ScanResults.Dups | Select-Object GroupId -Unique).Count
    if ($dg -gt 0) {
        $dw = 0; $ScanResults.Dups | Group-Object GroupId | ForEach-Object { $dw += ($_.Group[0].Size * ($_.Count - 1)) }
        if ($dw -ge 1MB) { [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Duplicates'; Message = "$dg groups wasting $(FmtSize $dw)"; Savings = $dw }) }
    }
    $nm = $ScanResults.Junk | Where-Object { $_.Name -eq 'node_modules' }
    if ($nm) { $nms = ($nm | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Dev Junk'; Message = "$($nm.Count) node_modules: $(FmtSize $nms)"; Savings = $nms }) }
    $old2y = $ScanResults.OldFiles | Where-Object { $_.AccessDays -gt 730 }
    if ($old2y.Count -gt 0) { $olds = ($old2y | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Old Files'; Message = "$($old2y.Count) files untouched 2+ years: $(FmtSize $olds)"; Savings = $olds }) }
    $bigJunk = $ScanResults.Junk | Where-Object { $_.Size -ge 10MB }
    if ($bigJunk.Count -gt 0) { $bjs = ($bigJunk | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Large Junk'; Message = "$($bigJunk.Count) big junk files: $(FmtSize $bjs)"; Savings = $bjs }) }
    if ($ScanResults.Empty.Count -gt 10) { [void]$recs.Add([PSCustomObject]@{Priority = 'LOW'; Category = 'Empty Dirs'; Message = "$($ScanResults.Empty.Count) empty folders"; Savings = 0 }) }
    return $recs
}
