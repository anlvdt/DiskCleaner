# DiskCleaner Pro v4.2 - System Cleaner Module
# Handles safe cleanup of Windows system junk (50+ targets)

function Get-SystemJunkTargets {
    param([switch]$AdminMode)

    $targets = [System.Collections.ArrayList]::new()

    # === USER-LEVEL (always safe, no admin needed) ===
    $userTargets = @(
        @{Name = 'User Temp Files'; Path = "$env:TEMP"; Pattern = '*'; Desc = 'Temporary files created by applications'; Safe = $true }
        @{Name = 'Windows Temp'; Path = 'C:\Windows\Temp'; Pattern = '*'; Desc = 'System temporary files'; Safe = $true }
        @{Name = 'Thumbnail Cache'; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; Pattern = 'thumbcache_*'; Desc = 'File/folder thumbnail cache'; Safe = $true }
        @{Name = 'Icon Cache'; Path = "$env:LOCALAPPDATA"; Pattern = 'IconCache*.db'; Desc = 'Desktop icon cache (auto-rebuilds)'; Safe = $true; NoRecurse = $true }
        @{Name = 'Recent Items'; Path = "$env:APPDATA\Microsoft\Windows\Recent"; Pattern = '*.lnk'; Desc = 'Recent file shortcuts (not the files themselves)'; Safe = $true }
        @{Name = 'Crash Dumps (User)'; Path = "$env:LOCALAPPDATA\CrashDumps"; Pattern = '*.dmp'; Desc = 'Application crash dump files'; Safe = $true }
        @{Name = 'Windows Error Reports'; Path = "$env:LOCALAPPDATA\Microsoft\Windows\WER"; Pattern = '*'; Desc = 'Error reporting data'; Safe = $true }
        @{Name = 'Activity Timeline'; Path = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"; Pattern = '*'; Desc = 'Windows Timeline/Activity history data'; Safe = $true }
        @{Name = 'Temp Internet Files'; Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Pattern = '*'; Desc = 'IE/Edge legacy internet cache'; Safe = $true }
        @{Name = 'DirectX Shader Cache'; Path = "$env:LOCALAPPDATA\D3DSCache"; Pattern = '*'; Desc = 'DirectX shader cache (auto-rebuilds)'; Safe = $true }
        @{Name = 'Defender Temp Files'; Path = "$env:ProgramData\Microsoft\Windows Defender\Scans\History"; Pattern = '*'; Desc = 'Windows Defender scan history'; Safe = $true }
        # v4.2: New user-level targets
        @{Name = 'NVIDIA Shader Cache'; Path = "$env:LOCALAPPDATA\NVIDIA\DXCache"; Pattern = '*'; Desc = 'NVIDIA GPU shader compilation cache'; Safe = $true }
        @{Name = 'NVIDIA GL Cache'; Path = "$env:LOCALAPPDATA\NVIDIA\GLCache"; Pattern = '*'; Desc = 'NVIDIA OpenGL shader cache'; Safe = $true }
        @{Name = 'AMD Shader Cache'; Path = "$env:LOCALAPPDATA\AMD\DxCache"; Pattern = '*'; Desc = 'AMD GPU shader cache'; Safe = $true }
        @{Name = 'Intel Shader Cache'; Path = "$env:LOCALAPPDATA\Intel\ShaderCache"; Pattern = '*'; Desc = 'Intel GPU shader cache'; Safe = $true }
        @{Name = 'OneDrive Cache'; Path = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"; Pattern = '*'; Desc = 'OneDrive sync logs and temp data'; Safe = $true }
        @{Name = '.NET Temp'; Path = "$env:TEMP\NuGetScratch"; Pattern = '*'; Desc = '.NET build scratch files'; Safe = $true }
        @{Name = 'Java Cache'; Path = "$env:LOCALAPPDATA\Sun\Java\Deployment\cache"; Pattern = '*'; Desc = 'Java applet/web start cache'; Safe = $true }
        @{Name = 'Outlook Temp'; Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\Content.Outlook"; Pattern = '*'; Desc = 'Outlook email attachment temp files'; Safe = $true }
        @{Name = 'Acrobat Cache'; Path = "$env:LOCALAPPDATA\Adobe\Acrobat"; Pattern = 'Cache'; Desc = 'Adobe Acrobat/Reader cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Windows Search Temp'; Path = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState"; Pattern = '*.tmp'; Desc = 'Windows Search temporary data'; Safe = $true }
        @{Name = 'MS Office Cache'; Path = "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"; Pattern = '*'; Desc = 'Microsoft Office file cache'; Safe = $true }
    )

    # === BROWSER CACHES ===
    $browserTargets = @(
        @{Name = 'Chrome Cache'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data"; Pattern = 'Cache'; Desc = 'Google Chrome browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Edge Cache'; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"; Pattern = 'Cache'; Desc = 'Microsoft Edge browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Firefox Cache'; Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"; Pattern = 'cache2'; Desc = 'Mozilla Firefox browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Chrome Code Cache'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data"; Pattern = 'Code Cache'; Desc = 'Chrome compiled JavaScript cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Edge Code Cache'; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"; Pattern = 'Code Cache'; Desc = 'Edge compiled JavaScript cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Firefox Code Cache'; Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"; Pattern = 'startupCache'; Desc = 'Firefox startup cache'; Safe = $true; IsBrowser = $true }
        # v4.2: Additional browsers
        @{Name = 'Brave Cache'; Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"; Pattern = 'Cache'; Desc = 'Brave browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Opera Cache'; Path = "$env:APPDATA\Opera Software\Opera Stable"; Pattern = 'Cache'; Desc = 'Opera browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Vivaldi Cache'; Path = "$env:LOCALAPPDATA\Vivaldi\User Data"; Pattern = 'Cache'; Desc = 'Vivaldi browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Chrome GPU Cache'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data"; Pattern = 'GpuCache'; Desc = 'Chrome GPU rendering cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Edge GPU Cache'; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"; Pattern = 'GpuCache'; Desc = 'Edge GPU rendering cache'; Safe = $true; IsBrowser = $true }
    )

    # === DEV TOOL CACHES ===
    $devCacheTargets = @(
        @{Name = 'npm Cache'; Path = (Join-Path $env:APPDATA 'npm-cache'); Pattern = '*'; Desc = 'npm package download cache'; Safe = $true }
        @{Name = 'pip Cache'; Path = (Join-Path $env:LOCALAPPDATA 'pip\Cache'); Pattern = '*'; Desc = 'Python pip download cache'; Safe = $true }
        @{Name = 'NuGet Cache'; Path = (Join-Path $env:LOCALAPPDATA 'NuGet\v3-cache'); Pattern = '*'; Desc = '.NET NuGet package cache'; Safe = $true }
        # v4.2: More dev caches
        @{Name = 'Yarn Cache'; Path = (Join-Path $env:LOCALAPPDATA 'Yarn\Cache'); Pattern = '*'; Desc = 'Yarn package download cache'; Safe = $true }
        @{Name = 'pnpm Store'; Path = (Join-Path $env:LOCALAPPDATA 'pnpm-store'); Pattern = '*'; Desc = 'pnpm content-addressable store'; Safe = $true }
        @{Name = 'Go Module Cache'; Path = (Join-Path $env:LOCALAPPDATA 'go-build'); Pattern = '*'; Desc = 'Go build and module cache'; Safe = $true }
        @{Name = 'Gradle Cache'; Path = (Join-Path $env:USERPROFILE '.gradle\caches'); Pattern = '*'; Desc = 'Gradle build system cache'; Safe = $true }
        @{Name = 'Maven Cache'; Path = (Join-Path $env:USERPROFILE '.m2\repository'); Pattern = '*'; Desc = 'Maven dependency cache (safe to rebuild)'; Safe = $true }
    )

    # === APP CACHES ===
    $appCacheTargets = @(
        @{Name = 'Teams Cache'; Path = "$env:APPDATA\Microsoft\Teams"; Pattern = 'Cache'; Desc = 'Microsoft Teams browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Teams Service Worker'; Path = "$env:APPDATA\Microsoft\Teams"; Pattern = 'Service Worker'; Desc = 'Teams service worker cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Discord Cache'; Path = "$env:APPDATA\discord"; Pattern = 'Cache'; Desc = 'Discord browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Discord Code Cache'; Path = "$env:APPDATA\discord"; Pattern = 'Code Cache'; Desc = 'Discord compiled JS cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Slack Cache'; Path = "$env:APPDATA\Slack"; Pattern = 'Cache'; Desc = 'Slack browser cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Slack Service Worker'; Path = "$env:APPDATA\Slack"; Pattern = 'Service Worker'; Desc = 'Slack service worker cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Spotify Cache'; Path = "$env:LOCALAPPDATA\Spotify\Storage"; Pattern = '*'; Desc = 'Spotify offline/streaming cache'; Safe = $true }
        @{Name = 'Steam Download Cache'; Path = "$env:LOCALAPPDATA\Steam\htmlcache"; Pattern = '*'; Desc = 'Steam browser/overlay cache'; Safe = $true }
        @{Name = 'VS Code Cache'; Path = "$env:APPDATA\Code"; Pattern = 'Cache'; Desc = 'VS Code editor cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'VS Code CachedData'; Path = "$env:APPDATA\Code\CachedData"; Pattern = '*'; Desc = 'VS Code cached extensions data'; Safe = $true }
        @{Name = 'Zoom Cache'; Path = "$env:APPDATA\Zoom"; Pattern = 'data'; Desc = 'Zoom meeting cache data'; Safe = $true; IsBrowser = $true }
        # v4.2: More app caches
        @{Name = 'Telegram Cache'; Path = "$env:APPDATA\Telegram Desktop\tdata\user_data"; Pattern = 'cache*'; Desc = 'Telegram desktop media cache'; Safe = $true }
        @{Name = 'WhatsApp Cache'; Path = "$env:LOCALAPPDATA\WhatsApp"; Pattern = 'Cache'; Desc = 'WhatsApp desktop cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Notion Cache'; Path = "$env:APPDATA\Notion"; Pattern = 'Cache'; Desc = 'Notion app cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Figma Cache'; Path = "$env:APPDATA\Figma"; Pattern = 'Cache'; Desc = 'Figma desktop cache'; Safe = $true; IsBrowser = $true }
        @{Name = 'Postman Cache'; Path = "$env:APPDATA\Postman"; Pattern = 'Cache'; Desc = 'Postman API client cache'; Safe = $true; IsBrowser = $true }
        # NOTE: Zalo PC is EXCLUDED from auto-clean - its cache contains chat media
        # (images, voice messages, videos) that may be permanently lost if cleared,
        # especially when cloud storage has expired. Users should clean Zalo via
        # Zalo Settings > Data Management for safe, selective cleanup.
    )

    # === SYSTEM-LEVEL (admin required) ===
    $adminTargets = @(
        @{Name = 'Windows Update Cache'; Path = 'C:\Windows\SoftwareDistribution\Download'; Pattern = '*'; Desc = 'Downloaded Windows updates (already installed)'; Safe = $true; Admin = $true }
        @{Name = 'Prefetch'; Path = 'C:\Windows\Prefetch'; Pattern = '*.pf'; Desc = 'Application prefetch cache (auto-rebuilds)'; Safe = $true; Admin = $true }
        @{Name = 'System Error Reports'; Path = 'C:\ProgramData\Microsoft\Windows\WER'; Pattern = '*'; Desc = 'System-level error reports'; Safe = $true; Admin = $true }
        @{Name = 'Crash Dumps (System)'; Path = 'C:\Windows\Minidump'; Pattern = '*.dmp'; Desc = 'System crash dumps'; Safe = $true; Admin = $true }
        @{Name = 'Font Cache'; Path = 'C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache'; Pattern = '*'; Desc = 'Font rendering cache (auto-rebuilds)'; Safe = $true; Admin = $true }
        @{Name = 'Delivery Optimization'; Path = 'C:\Windows\SoftwareDistribution\DeliveryOptimization'; Pattern = '*'; Desc = 'Windows Update delivery cache'; Safe = $true; Admin = $true }
        @{Name = 'Event Logs'; Path = 'C:\Windows\System32\winevt\Logs'; Pattern = '*.evtx'; Desc = 'Windows Event Viewer archived logs'; Safe = $true; Admin = $true }
        @{Name = 'CBS Logs'; Path = 'C:\Windows\Logs\CBS'; Pattern = '*.log'; Desc = 'Windows component servicing logs'; Safe = $true; Admin = $true }
        @{Name = 'DISM Logs'; Path = 'C:\Windows\Logs\DISM'; Pattern = '*.log'; Desc = 'DISM servicing logs'; Safe = $true; Admin = $true }
        # v4.2: More admin targets
        @{Name = 'Setup API Logs'; Path = 'C:\Windows\inf'; Pattern = 'setupapi*.log'; Desc = 'Device installation logs'; Safe = $true; Admin = $true }
        @{Name = 'Windows Installer Cache'; Path = 'C:\Windows\Installer'; Pattern = '*.tmp'; Desc = 'MSI installer temp files'; Safe = $true; Admin = $true }
        @{Name = 'IIS Logs'; Path = 'C:\inetpub\logs\LogFiles'; Pattern = '*.log'; Desc = 'IIS web server logs'; Safe = $true; Admin = $true }
        @{Name = 'System Panther'; Path = 'C:\Windows\Panther'; Pattern = '*.log'; Desc = 'Windows upgrade/install logs'; Safe = $true; Admin = $true }
    )

    foreach ($t in $userTargets) { [void]$targets.Add($t) }
    foreach ($t in $browserTargets) { [void]$targets.Add($t) }
    foreach ($t in $devCacheTargets) { [void]$targets.Add($t) }
    foreach ($t in $appCacheTargets) { [void]$targets.Add($t) }
    if ($AdminMode) { foreach ($t in $adminTargets) { [void]$targets.Add($t) } }

    return $targets
}

function Measure-TargetSize {
    param([hashtable]$Target)
    $size = [long]0; $count = 0
    try {
        $p = $Target.Path
        if (-not (Test-Path $p)) { return @{Size = 0; Count = 0 } }

        if ($Target.ContainsKey('IsBrowser') -and $Target.IsBrowser) {
            Get-ChildItem $p -Directory -EA SilentlyContinue | ForEach-Object {
                $cp = Join-Path $_.FullName $Target.Pattern
                if (Test-Path $cp) {
                    Get-ChildItem $cp -Recurse -File -Force -EA SilentlyContinue | ForEach-Object { $size += $_.Length; $count++ }
                }
            }
        }
        elseif ($Target.ContainsKey('NoRecurse') -and $Target.NoRecurse) {
            # Top-level only - no recurse (e.g. Icon Cache in LOCALAPPDATA)
            Get-ChildItem $p -Filter $Target.Pattern -File -Force -EA SilentlyContinue | ForEach-Object { $size += $_.Length; $count++ }
        }
        elseif ($Target.Pattern -eq '*') {
            Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue | ForEach-Object { $size += $_.Length; $count++ }
        }
        else {
            Get-ChildItem $p -Filter $Target.Pattern -Recurse -File -Force -EA SilentlyContinue | ForEach-Object { $size += $_.Length; $count++ }
        }
    }
    catch {}
    return @{Size = $size; Count = $count }
}

function Invoke-CleanTarget {
    param([hashtable]$Target)
    $cleaned = [long]0; $errors = 0; $skipped = 0

    # Helper: check if file is locked by another process
    function Test-CleanFileInUse([string]$FilePath) {
        try {
            $fs = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
            $fs.Close(); $fs.Dispose(); return $false
        } catch { return $true }
    }

    try {
        $p = $Target.Path
        if (-not (Test-Path $p)) { return @{Cleaned = 0; Errors = 0; Skipped = 0 } }

        if ($Target.ContainsKey('IsBrowser') -and $Target.IsBrowser) {
            Get-ChildItem $p -Directory -EA SilentlyContinue | ForEach-Object {
                $cp = Join-Path $_.FullName $Target.Pattern
                if (Test-Path $cp) {
                    Get-ChildItem $cp -Recurse -File -Force -EA SilentlyContinue | ForEach-Object {
                        try {
                            if (Test-CleanFileInUse $_.FullName) { $skipped++; return }
                            $s = $_.Length; Remove-Item $_.FullName -Force -EA Stop; $cleaned += $s
                        } catch { $errors++ }
                    }
                }
            }
        }
        elseif ($Target.ContainsKey('NoRecurse') -and $Target.NoRecurse) {
            Get-ChildItem $p -Filter $Target.Pattern -File -Force -EA SilentlyContinue | ForEach-Object {
                try {
                    if (Test-CleanFileInUse $_.FullName) { $skipped++; return }
                    $s = $_.Length; Remove-Item $_.FullName -Force -EA Stop; $cleaned += $s
                } catch { $errors++ }
            }
        }
        elseif ($Target.Pattern -eq '*') {
            Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue | ForEach-Object {
                try {
                    if (Test-CleanFileInUse $_.FullName) { $skipped++; return }
                    $s = $_.Length; Remove-Item $_.FullName -Force -EA Stop; $cleaned += $s
                } catch { $errors++ }
            }
        }
        else {
            Get-ChildItem $p -Filter $Target.Pattern -Recurse -File -Force -EA SilentlyContinue | ForEach-Object {
                try {
                    if (Test-CleanFileInUse $_.FullName) { $skipped++; return }
                    $s = $_.Length; Remove-Item $_.FullName -Force -EA Stop; $cleaned += $s
                } catch { $errors++ }
            }
        }
    }
    catch { $errors++ }
    return @{Cleaned = $cleaned; Errors = $errors; Skipped = $skipped }
}

function Invoke-RecycleBinClear {
    # Primary: Clear-RecycleBin (fast, single call, no per-item enumeration)
    try {
        $null = Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop 2>$null
        return $true
    }
    catch {}
    # Fallback: Shell.Application COM (slower but works on older systems)
    try {
        $shell = New-Object -ComObject Shell.Application
        $rb = $shell.Namespace(0xA)
        if ($rb -and $rb.Items().Count -gt 0) {
            $null = Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue 2>$null
        }
        return $true
    }
    catch { return $false }
}
