# DiskCleaner Pro v4.2 - Smart Clean Module
# Priority-based recommendations + one-click safe cleanup

# FmtSize defined here so this module is self-contained
function FmtSize([long]$b) {
    if ($b -ge 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -ge 1MB) { return "{0:N1} MB" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N0} KB" -f ($b / 1KB) }
    return "$b B"
}

function Get-SmartRecommendations {
    param($ScanResults)
    $recs = [System.Collections.ArrayList]::new()

    # --- HIGH PRIORITY ---

    # Duplicate files wasting space
    $dg = ($ScanResults.Dups | Select-Object GroupId -Unique).Count
    if ($dg -gt 0) {
        $dw = 0; $ScanResults.Dups | Group-Object GroupId | ForEach-Object { $dw += ($_.Group[0].Size * ($_.Count - 1)) }
        if ($dw -ge 1MB) { [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Duplicates'; Message = "$dg groups wasting $(FmtSize $dw)"; Savings = $dw }) }
    }

    # Dev artifacts (node_modules, __pycache__, etc.)
    $nm = $ScanResults.Junk | Where-Object { $_.Name -eq 'node_modules' }
    if ($nm) { $nms = ($nm | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Dev Junk'; Message = "$($nm.Count) node_modules: $(FmtSize $nms)"; Savings = $nms }) }

    $pyc = $ScanResults.Junk | Where-Object { $_.Name -eq '__pycache__' -or $_.Name -match '\.pyc$' }
    if ($pyc -and $pyc.Count -gt 5) { $pys = ($pyc | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Dev Junk'; Message = "$($pyc.Count) Python cache files: $(FmtSize $pys)"; Savings = $pys }) }

    # Very large files (>1GB)
    $huge = $ScanResults.Large | Where-Object { $_.Size -ge 1GB }
    if ($huge -and $huge.Count -gt 0) { $hs = ($huge | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Huge Files'; Message = "$($huge.Count) files over 1 GB: $(FmtSize $hs)"; Savings = $hs }) }

    # Broken files (extension mismatch)
    if ($ScanResults.Broken -and $ScanResults.Broken.Count -gt 0) {
        $bks = ($ScanResults.Broken | Measure-Object Size -Sum).Sum
        [void]$recs.Add([PSCustomObject]@{Priority = 'HIGH'; Category = 'Broken Files'; Message = "$($ScanResults.Broken.Count) broken/mismatched files: $(FmtSize $bks)"; Savings = $bks })
    }

    # --- MEDIUM PRIORITY ---

    # Old files (2+ years untouched)
    $old2y = $ScanResults.OldFiles | Where-Object { $_.AccessDays -gt 730 }
    if ($old2y.Count -gt 0) { $olds = ($old2y | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Old Files'; Message = "$($old2y.Count) files untouched 2+ years: $(FmtSize $olds)"; Savings = $olds }) }

    # Files 1-2 years old
    $old1y = $ScanResults.OldFiles | Where-Object { $_.AccessDays -gt 365 -and $_.AccessDays -le 730 }
    if ($old1y.Count -gt 10) { $o1s = ($old1y | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Aging Files'; Message = "$($old1y.Count) files untouched 1-2 years: $(FmtSize $o1s)"; Savings = $o1s }) }

    # Large junk files
    $bigJunk = $ScanResults.Junk | Where-Object { $_.Size -ge 10MB }
    if ($bigJunk.Count -gt 0) { $bjs = ($bigJunk | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Large Junk'; Message = "$($bigJunk.Count) big junk files: $(FmtSize $bjs)"; Savings = $bjs }) }

    # Large temp/log files
    $logs = $ScanResults.Large | Where-Object { $_.Name -match '\.(log|tmp|bak|old|orig)$' }
    if ($logs -and $logs.Count -gt 3) { $ls = ($logs | Measure-Object Size -Sum).Sum; [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Temp/Log Files'; Message = "$($logs.Count) log/temp/backup files: $(FmtSize $ls)"; Savings = $ls }) }

    # Duplicate images
    $dupImages = $ScanResults.Dups | Where-Object { $_.Name -match '\.(jpg|jpeg|png|bmp|gif|webp)$' }
    if ($dupImages -and $dupImages.Count -gt 0) {
        $dis = ($dupImages | Measure-Object Size -Sum).Sum
        [void]$recs.Add([PSCustomObject]@{Priority = 'MEDIUM'; Category = 'Duplicate Images'; Message = "$($dupImages.Count) duplicate images: $(FmtSize $dis)"; Savings = $dis })
    }

    # --- LOW PRIORITY ---

    # Empty directories
    if ($ScanResults.Empty.Count -gt 10) { [void]$recs.Add([PSCustomObject]@{Priority = 'LOW'; Category = 'Empty Dirs'; Message = "$($ScanResults.Empty.Count) empty folders"; Savings = 0 }) }

    # Zero-byte files
    $zeroFiles = $ScanResults.Large | Where-Object { $_.Size -eq 0 }
    if ($zeroFiles -and $zeroFiles.Count -gt 5) { [void]$recs.Add([PSCustomObject]@{Priority = 'LOW'; Category = 'Zero-Byte'; Message = "$($zeroFiles.Count) zero-byte files"; Savings = 0 }) }

    # Desktop clutter (too many files on Desktop)
    $desktopFiles = $ScanResults.Large | Where-Object { $_.FullPath -match '\\Desktop\\' }
    if ($desktopFiles -and $desktopFiles.Count -gt 30) {
        [void]$recs.Add([PSCustomObject]@{Priority = 'LOW'; Category = 'Desktop Clutter'; Message = "$($desktopFiles.Count) files on Desktop - consider organizing"; Savings = 0 })
    }

    # Downloads folder large files
    $dlFiles = $ScanResults.Large | Where-Object { $_.FullPath -match '\\Downloads\\' -and $_.Size -ge 100MB }
    if ($dlFiles -and $dlFiles.Count -gt 0) {
        $dls = ($dlFiles | Measure-Object Size -Sum).Sum
        [void]$recs.Add([PSCustomObject]@{Priority = 'LOW'; Category = 'Downloads'; Message = "$($dlFiles.Count) large files in Downloads: $(FmtSize $dls)"; Savings = $dls })
    }

    # --- SUMMARY ---
    $totalSavings = ($recs | Measure-Object Savings -Sum).Sum
    if ($totalSavings -gt 0) {
        [void]$recs.Insert(0, [PSCustomObject]@{Priority = 'SUMMARY'; Category = 'Total Potential'; Message = "$(FmtSize $totalSavings) recoverable space across $($recs.Count) issues"; Savings = $totalSavings })
    }

    return $recs
}
