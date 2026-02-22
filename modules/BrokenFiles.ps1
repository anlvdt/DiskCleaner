# DiskCleaner Pro v2.0 - Broken Files Detector Module
# Finds empty files, broken symlinks, extension mismatches

# Magic bytes signatures for common file types
$Script:MagicBytes = @{
    '.jpg'  = @(0xFF,0xD8,0xFF)
    '.jpeg' = @(0xFF,0xD8,0xFF)
    '.png'  = @(0x89,0x50,0x4E,0x47)
    '.gif'  = @(0x47,0x49,0x46,0x38)
    '.bmp'  = @(0x42,0x4D)
    '.pdf'  = @(0x25,0x50,0x44,0x46)
    '.zip'  = @(0x50,0x4B,0x03,0x04)
    '.rar'  = @(0x52,0x61,0x72,0x21)
    '.7z'   = @(0x37,0x7A,0xBC,0xAF)
    '.exe'  = @(0x4D,0x5A)
    '.dll'  = @(0x4D,0x5A)
    '.mp3'  = @(0x49,0x44,0x33)
    '.mp4'  = @(0x00,0x00,0x00)
    '.wav'  = @(0x52,0x49,0x46,0x46)
    '.docx' = @(0x50,0x4B,0x03,0x04)
    '.xlsx' = @(0x50,0x4B,0x03,0x04)
    '.pptx' = @(0x50,0x4B,0x03,0x04)
}

function Find-BrokenFiles {
    param($ScanFiles)
    $broken = [System.Collections.ArrayList]::new()

    foreach ($f in $ScanFiles) {
        # Empty files (0 bytes)
        if ($f.Size -eq 0) {
            [void]$broken.Add([PSCustomObject]@{
                Name=$f.Name; FullPath=$f.FullPath; Size=$f.Size; SizeText='0 B'
                Issue='Empty file (0 bytes)'; Category='Empty'
            })
            continue
        }

        # Extension mismatch (check magic bytes)
        $ext = $f.Extension
        if ($Script:MagicBytes.ContainsKey($ext) -and $f.Size -ge 8) {
            try {
                $stream = [System.IO.File]::OpenRead($f.FullPath)
                $hdr = New-Object byte[] 8
                $read = $stream.Read($hdr, 0, 8); $stream.Close()
                if ($read -ge 2) {
                    $expected = $Script:MagicBytes[$ext]
                    $match = $true
                    for ($i = 0; $i -lt $expected.Count -and $i -lt $read; $i++) {
                        if ($hdr[$i] -ne $expected[$i]) { $match = $false; break }
                    }
                    if (-not $match) {
                        # Detect actual type
                        $actual = 'Unknown'
                        foreach ($kv in $Script:MagicBytes.GetEnumerator()) {
                            $sig = $kv.Value; $ok = $true
                            for ($j = 0; $j -lt $sig.Count -and $j -lt $read; $j++) {
                                if ($hdr[$j] -ne $sig[$j]) { $ok = $false; break }
                            }
                            if ($ok -and $sig.Count -le $read) { $actual = $kv.Key; break }
                        }
                        [void]$broken.Add([PSCustomObject]@{
                            Name=$f.Name; FullPath=$f.FullPath; Size=$f.Size; SizeText=$f.SizeText
                            Issue="Extension $ext but content looks like $actual"; Category='Mismatch'
                        })
                    }
                }
            } catch {}
        }
    }

    # Broken symbolic links
    try {
        $scanDir = if ($ScanFiles.Count -gt 0) { Split-Path $ScanFiles[0].FullPath -ErrorAction SilentlyContinue } else { $null }
        if ($scanDir) {
            Get-ChildItem $scanDir -Recurse -Force -EA SilentlyContinue | Where-Object {
                $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint
            } | ForEach-Object {
                $target = $null
                try { $target = [System.IO.Path]::GetFullPath($_.Target) } catch {}
                if ($target -and -not (Test-Path $target)) {
                    [void]$broken.Add([PSCustomObject]@{
                        Name=$_.Name; FullPath=$_.FullName; Size=0; SizeText='--'
                        Issue="Broken link -> $target"; Category='Broken Link'
                    })
                }
            }
        }
    } catch {}

    return $broken
}
