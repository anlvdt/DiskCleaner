# DiskCleaner Pro v2.1 - Dev Cleanup Module
# Inspired by huantt/clean-stack - detects 25+ developer artifact types

$Script:DevTargets = @(
    # Dependencies (Blue)
    @{Name = 'node_modules'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'node_modules'; Type = 'Folder' }
    @{Name = '.pnpm'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = '.pnpm'; Type = 'Folder' }
    @{Name = 'bower_components'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'bower_components'; Type = 'Folder' }
    @{Name = 'venv'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'venv'; Type = 'Folder' }
    @{Name = '.venv'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = '.venv'; Type = 'Folder' }
    @{Name = 'packages'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'packages'; Type = 'Folder' }
    @{Name = 'vendor'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'vendor'; Type = 'Folder' }

    # Build Outputs (Orange)
    @{Name = 'dist'; Category = 'Build'; Color = '#f97316'; Pattern = 'dist'; Type = 'Folder' }
    @{Name = 'build'; Category = 'Build'; Color = '#f97316'; Pattern = 'build'; Type = 'Folder' }
    @{Name = 'out'; Category = 'Build'; Color = '#f97316'; Pattern = 'out'; Type = 'Folder' }
    @{Name = '.next'; Category = 'Build'; Color = '#f97316'; Pattern = '.next'; Type = 'Folder' }
    @{Name = '.nuxt'; Category = 'Build'; Color = '#f97316'; Pattern = '.nuxt'; Type = 'Folder' }
    @{Name = 'target'; Category = 'Build'; Color = '#f97316'; Pattern = 'target'; Type = 'Folder' }
    @{Name = 'bin\Debug'; Category = 'Build'; Color = '#f97316'; Pattern = 'bin\Debug'; Type = 'Folder' }
    @{Name = 'bin\Release'; Category = 'Build'; Color = '#f97316'; Pattern = 'bin\Release'; Type = 'Folder' }
    @{Name = 'obj'; Category = 'Build'; Color = '#f97316'; Pattern = 'obj'; Type = 'Folder' }

    # Caches (Yellow)
    @{Name = '.cache'; Category = 'Cache'; Color = '#eab308'; Pattern = '.cache'; Type = 'Folder' }
    @{Name = '.parcel-cache'; Category = 'Cache'; Color = '#eab308'; Pattern = '.parcel-cache'; Type = 'Folder' }
    @{Name = '.turbo'; Category = 'Cache'; Color = '#eab308'; Pattern = '.turbo'; Type = 'Folder' }
    @{Name = '.pytest_cache'; Category = 'Cache'; Color = '#eab308'; Pattern = '.pytest_cache'; Type = 'Folder' }
    @{Name = '__pycache__'; Category = 'Cache'; Color = '#eab308'; Pattern = '__pycache__'; Type = 'Folder' }
    @{Name = '.eslintcache'; Category = 'Cache'; Color = '#eab308'; Pattern = '.eslintcache'; Type = 'File' }

    # Coverage (Green)
    @{Name = 'coverage'; Category = 'Coverage'; Color = '#22c55e'; Pattern = 'coverage'; Type = 'Folder' }
    @{Name = '.nyc_output'; Category = 'Coverage'; Color = '#22c55e'; Pattern = '.nyc_output'; Type = 'Folder' }
    @{Name = 'htmlcov'; Category = 'Coverage'; Color = '#22c55e'; Pattern = 'htmlcov'; Type = 'Folder' }

    # IDE/Tools (Purple)
    @{Name = '.vs'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.vs'; Type = 'Folder' }
    @{Name = '.idea'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.idea'; Type = 'Folder' }
    @{Name = '.gradle'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.gradle'; Type = 'Folder' }
    @{Name = '.dart_tool'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.dart_tool'; Type = 'Folder' }
    @{Name = '.angular'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.angular'; Type = 'Folder' }

    # Logs (Gray)
    @{Name = 'logs'; Category = 'Logs'; Color = '#6b7280'; Pattern = 'logs'; Type = 'Folder' }
    @{Name = '.log'; Category = 'Logs'; Color = '#6b7280'; Pattern = '.log'; Type = 'Folder' }

    # Infrastructure (Cyan)
    @{Name = '.terraform'; Category = 'Infrastructure'; Color = '#06b6d4'; Pattern = '.terraform'; Type = 'Folder' }
    @{Name = 'Pods'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = 'Pods'; Type = 'Folder' }
    @{Name = '.cargo'; Category = 'Dependencies'; Color = '#3b82f6'; Pattern = '.cargo'; Type = 'Folder' }
    @{Name = '.metals'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.metals'; Type = 'Folder' }
    @{Name = '.bsp'; Category = 'IDE'; Color = '#8b5cf6'; Pattern = '.bsp'; Type = 'Folder' }
)

function Invoke-DevScan {
    param([string]$ScanPath, [int]$MaxDepth = 5, [hashtable]$Shared = $null)
    $found = [System.Collections.ArrayList]::new()
    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue(@{Path = $ScanPath; Depth = 0 })
    $scannedCount = 0

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        if ($item.Depth -gt $MaxDepth) { continue }
        $scannedCount++
        if ($Shared -and ($scannedCount % 10 -eq 0)) {
            $shortPath = $item.Path
            if ($shortPath.Length -gt 60) { $shortPath = '...' + $shortPath.Substring($shortPath.Length - 57) }
            $Shared.Status = "Scanning: $shortPath  ($($found.Count) found)"
        }

        try {
            $children = Get-ChildItem -Path $item.Path -Force -EA SilentlyContinue
            foreach ($child in $children) {
                if (-not $child.PSIsContainer) { continue }

                $matched = $false
                foreach ($t in $Script:DevTargets) {
                    if ($t.Type -eq 'Folder' -and $child.Name -eq $t.Pattern) {
                        # Calculate folder size
                        $size = 0L
                        if ($Shared) { $Shared.Status = "Measuring: $($child.Name) in $($item.Path)  ($($found.Count) found)" }
                        try {
                            $size = (Get-ChildItem $child.FullName -Recurse -Force -EA SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
                            if ($null -eq $size) { $size = 0 }
                        }
                        catch {}

                        [void]$found.Add([PSCustomObject]@{
                                Name     = $child.Name
                                FullPath = $child.FullName
                                Category = $t.Category
                                Color    = $t.Color
                                Size     = [long]$size
                                SizeText = FmtSize ([long]$size)
                                Parent   = $item.Path
                                Depth    = $item.Depth
                            })
                        $matched = $true
                        break  # Don't recurse into matched folders
                    }
                }

                # Only recurse into non-matched folders
                if (-not $matched) {
                    $queue.Enqueue(@{Path = $child.FullName; Depth = $item.Depth + 1 })
                }
            }
        }
        catch {}
    }

    return $found | Sort-Object Size -Descending
}

function Get-DevScanSummary {
    param($Results)
    $summary = @{}
    foreach ($r in $Results) {
        if ($summary.ContainsKey($r.Category)) {
            $summary[$r.Category].Count++
            $summary[$r.Category].Size += $r.Size
        }
        else {
            $summary[$r.Category] = @{Count = 1; Size = $r.Size; Color = $r.Color }
        }
    }
    return $summary
}
