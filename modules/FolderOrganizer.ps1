# DiskCleaner Pro v3.0 - Folder Organizer Module
# Non-destructive file organization: MOVE only, never delete
# Inspired by: tfeldmann/organize, SortPhotos, MediaSorter, ai-file-sorter
# Exclusion system inspired by: organize (system_exclude), Hazel (conditions), DropIt (filters)
# v3.0: Magic-byte detection, expanded categories, project folder detection

# ============================================================
# LAYER 1: System Defaults (always on unless -NoSystemDefaults)
# ============================================================
$Script:SystemExcludeFiles = @(
    'desktop.ini', 'Thumbs.db', '.DS_Store', '.localized',
    '~$*',               # Office temp/lock files
    'NTUSER.DAT', 'NTUSER.DAT.LOG*', 'UsrClass.dat', 'UsrClass.dat.LOG*',
    'pagefile.sys', 'swapfile.sys', 'hiberfil.sys',
    'bootmgr', 'BOOTNXT', 'BOOTSECT.BAK',
    'ntldr', 'NTDETECT.COM', 'boot.ini',
    'IconCache.db', 'thumbcache_*.db'
)

$Script:SystemExcludeDirs = @(
    '.git', '.svn', '.hg', '.bzr',             # Version control
    'node_modules', '__pycache__', '.tox',      # Dev artifacts
    '.vs', '.vscode', '.idea', '.fleet',        # IDE configs
    '$RECYCLE.BIN', 'System Volume Information', # System dirs
    'AppData', 'ProgramData',                    # User/system data
    '.cache', '.npm', '.nuget', '.cargo',        # Package caches
    'obj', 'bin', 'target', 'build', 'dist'      # Build outputs
)

$Script:SystemExcludeExts = @(
    '.sys', '.drv',       # System drivers
    '.dat', '.hiv',       # Registry/system data
    '.lock', '.pid',      # Lock/process files
    '.tmp', '.temp'       # Temp files (dangerous to move mid-write)
)

# ============================================================
# LAYER 2: User-Defined Patterns (JSON config)
# ============================================================
$Script:ExcludeConfigFile = Join-Path $env:APPDATA 'DiskCleanerPro\organize_exclude.json'

function Get-ExcludeRules {
    if (-not (Test-Path $Script:ExcludeConfigFile)) {
        return @{ Files = @(); Dirs = @(); Extensions = @() }
    }
    try {
        $data = Get-Content $Script:ExcludeConfigFile -Raw | ConvertFrom-Json
        return @{
            Files      = @($data.Files)
            Dirs       = @($data.Dirs)
            Extensions = @($data.Extensions)
        }
    }
    catch {
        return @{ Files = @(); Dirs = @(); Extensions = @() }
    }
}

function Save-ExcludeRules {
    param($Rules)
    $dir = Split-Path $Script:ExcludeConfigFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    @{ Files = @($Rules.Files); Dirs = @($Rules.Dirs); Extensions = @($Rules.Extensions) } |
    ConvertTo-Json -Depth 3 | Set-Content $Script:ExcludeConfigFile -Encoding UTF8
}

function Add-ExcludePattern {
    param([string]$Pattern, [ValidateSet('Files', 'Dirs', 'Extensions')][string]$Type = 'Files')
    $rules = Get-ExcludeRules
    if ($rules[$Type] -notcontains $Pattern) {
        $rules[$Type] = @($rules[$Type]) + $Pattern
        Save-ExcludeRules $rules
    }
}

function Remove-ExcludePattern {
    param([string]$Pattern, [ValidateSet('Files', 'Dirs', 'Extensions')][string]$Type = 'Files')
    $rules = Get-ExcludeRules
    $rules[$Type] = @($rules[$Type] | Where-Object { $_ -ne $Pattern })
    Save-ExcludeRules $rules
}

# ============================================================
# LAYER 3: Safety Guards
# ============================================================
function Test-FileInUse {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $fs.Close(); $fs.Dispose(); return $false
    }
    catch { return $true }
}

function Test-HasSystemAttributes {
    param([string]$Path)
    try {
        $attr = [System.IO.File]::GetAttributes($Path)
        $isHidden = ($attr -band [System.IO.FileAttributes]::Hidden) -ne 0
        $isSystem = ($attr -band [System.IO.FileAttributes]::System) -ne 0
        return ($isHidden -and $isSystem)
    }
    catch { return $false }
}

# ============================================================
# Master Exclusion Check (chains all layers)
# ============================================================
function Test-FileExcluded {
    param(
        [System.IO.FileInfo]$File,
        [hashtable]$Options  # All exclusion options
    )
    $name = $File.Name
    $ext = $File.Extension.ToLower()
    $dir = $File.DirectoryName

    # --- Layer 1: System Defaults ---
    if (-not $Options.NoSystemDefaults) {
        foreach ($pat in $Script:SystemExcludeFiles) {
            if ($name -like $pat) { return @{Excluded = $true; Reason = "System default: $pat"; Layer = 'System' } }
        }
        foreach ($ep in $Script:SystemExcludeExts) {
            if ($ext -eq $ep) { return @{Excluded = $true; Reason = "System extension: $ep"; Layer = 'System' } }
        }
        # Check if parent dir is in system exclude list
        $parentName = Split-Path $dir -Leaf
        foreach ($dp in $Script:SystemExcludeDirs) {
            if ($parentName -like $dp) { return @{Excluded = $true; Reason = "System dir: $dp"; Layer = 'System' } }
        }
    }

    # --- Layer 2: User Patterns ---
    $userRules = if ($Options.UserRules) { $Options.UserRules } else { Get-ExcludeRules }
    foreach ($fp in $userRules.Files) {
        if ($name -like $fp) { return @{Excluded = $true; Reason = "User pattern: $fp"; Layer = 'User' } }
    }
    foreach ($ep in $userRules.Extensions) {
        if ($ext -eq $ep -or $ext -eq ".$ep".Replace('..', '.')) {
            return @{Excluded = $true; Reason = "User extension: $ep"; Layer = 'User' }
        }
    }
    # Parent dir check against user dirs
    $parentName = Split-Path $dir -Leaf
    foreach ($dp in $userRules.Dirs) {
        if ($parentName -like $dp) { return @{Excluded = $true; Reason = "User dir: $dp"; Layer = 'User' } }
    }
    # Extra user exclude patterns from params
    foreach ($fp in $Options.ExcludeFiles) {
        if ($name -like $fp) { return @{Excluded = $true; Reason = "Exclude param: $fp"; Layer = 'User' } }
    }
    foreach ($ep in $Options.ExcludeExtensions) {
        $cmpExt = if ($ep.StartsWith('.')) { $ep } else { ".$ep" }
        if ($ext -eq $cmpExt.ToLower()) { return @{Excluded = $true; Reason = "Exclude ext: $ep"; Layer = 'User' } }
    }

    # --- Layer 3: Safety Guards ---
    if ($Options.SkipHidden -or $Options.SkipSystem) {
        try {
            $attr = [System.IO.File]::GetAttributes($File.FullName)
            if ($Options.SkipHidden -and ($attr -band [System.IO.FileAttributes]::Hidden)) {
                return @{Excluded = $true; Reason = 'Hidden file'; Layer = 'Safety' }
            }
            if ($Options.SkipSystem -and ($attr -band [System.IO.FileAttributes]::System)) {
                return @{Excluded = $true; Reason = 'System file'; Layer = 'Safety' }
            }
        }
        catch {}
    }
    # Always skip Hidden+System combo (OS-critical files)
    if (Test-HasSystemAttributes $File.FullName) {
        return @{Excluded = $true; Reason = 'Hidden+System attributes (OS file)'; Layer = 'Safety' }
    }
    if ($Options.SkipInUse -and (Test-FileInUse $File.FullName)) {
        return @{Excluded = $true; Reason = 'File in use'; Layer = 'Safety' }
    }

    # --- Layer 4: Smart Filters ---
    if ($Options.MinSize -gt 0 -and $File.Length -lt $Options.MinSize) {
        return @{Excluded = $true; Reason = "Below min size ($($Options.MinSize))"; Layer = 'Filter' }
    }
    if ($Options.MaxSize -lt [long]::MaxValue -and $File.Length -gt $Options.MaxSize) {
        return @{Excluded = $true; Reason = "Above max size ($($Options.MaxSize))"; Layer = 'Filter' }
    }
    if ($Options.MinAgeDays -gt 0) {
        $ageDays = ((Get-Date) - $File.LastWriteTime).Days
        if ($ageDays -lt $Options.MinAgeDays) {
            return @{Excluded = $true; Reason = "Too recent ($ageDays days < $($Options.MinAgeDays))"; Layer = 'Filter' }
        }
    }
    if ($Options.MaxAgeDays -lt [int]::MaxValue) {
        $ageDays = ((Get-Date) - $File.LastWriteTime).Days
        if ($ageDays -gt $Options.MaxAgeDays) {
            return @{Excluded = $true; Reason = "Too old ($ageDays days > $($Options.MaxAgeDays))"; Layer = 'Filter' }
        }
    }
    # Whitelist mode: only include matching patterns
    if ($Options.IncludeOnly -and $Options.IncludeOnly.Count -gt 0) {
        $matched = $false
        foreach ($pat in $Options.IncludeOnly) {
            if ($name -like $pat) { $matched = $true; break }
        }
        if (-not $matched) {
            return @{Excluded = $true; Reason = "Not in include-only whitelist"; Layer = 'Filter' }
        }
    }

    return @{Excluded = $false; Reason = ''; Layer = '' }
}

$Script:Categories = [ordered]@{
    'Documents'   = @('.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.rtf', '.odt', '.ods', '.odp', '.csv', '.md', '.epub', '.mobi', '.pages', '.numbers', '.key', '.one', '.xps', '.oxps')
    'Images'      = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.webp', '.ico', '.tiff', '.tif', '.psd', '.ai', '.eps', '.raw', '.cr2', '.nef', '.heic', '.heif', '.avif', '.jfif', '.pcx', '.tga')
    'Screenshots' = @()  # Detected by name pattern, not extension
    'Videos'      = @('.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.vob', '.ts', '.mts', '.m2ts', '.ogv')
    'Audio'       = @('.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.opus', '.aiff', '.mid', '.midi', '.alac', '.ape', '.ac3', '.dts')
    'Archives'    = @('.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.cab', '.iso', '.img', '.tar.gz', '.tgz', '.tar.bz2', '.tar.xz', '.zst')
    'Ebooks'      = @('.epub', '.mobi', '.azw', '.azw3', '.fb2', '.lit', '.djvu', '.cbz', '.cbr')
    'Code'        = @('.py', '.js', '.ts', '.jsx', '.tsx', '.html', '.htm', '.css', '.scss', '.sass', '.less', '.java', '.cs', '.cpp', '.c', '.h', '.hpp', '.go', '.rs', '.rb', '.php', '.swift', '.kt', '.lua', '.r', '.ps1', '.bat', '.sh', '.sql', '.vue', '.svelte', '.dart', '.ex', '.exs', '.zig', '.v', '.nim')
    'Data'        = @('.json', '.xml', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.env', '.log', '.ndjson', '.jsonl', '.parquet', '.feather', '.arrow')
    'Databases'   = @('.db', '.sqlite', '.sqlite3', '.mdb', '.accdb', '.dbf', '.sql', '.bak')
    'Executables' = @('.exe', '.msi', '.dll', '.apk', '.app', '.deb', '.rpm', '.dmg', '.appx', '.msix', '.appimage', '.snap')
    'Fonts'       = @('.ttf', '.otf', '.woff', '.woff2', '.eot', '.fon')
    'DiskImages'  = @('.vhd', '.vhdx', '.vmdk', '.ova', '.ovf', '.qcow2', '.wim', '.swm')
    'Shortcuts'   = @('.lnk', '.url', '.webloc', '.desktop')
    'Backups'     = @('.bak', '.old', '.backup', '.orig', '.save', '.swp', '.sav')
    'Design'      = @('.fig', '.sketch', '.xd', '.indd', '.blend', '.3ds', '.fbx', '.obj', '.stl', '.dwg', '.dxf', '.step', '.iges')
}

# Magic byte signatures for files without extensions
$Script:MagicBytes = @{
    'Documents'   = @(
        @{ Bytes = [byte[]]@(0x25, 0x50, 0x44, 0x46); Desc = 'PDF' }        # %PDF
        @{ Bytes = [byte[]]@(0xD0, 0xCF, 0x11, 0xE0); Desc = 'Office' }     # MS Office (DOC/XLS/PPT)
    )
    'Images'      = @(
        @{ Bytes = [byte[]]@(0x89, 0x50, 0x4E, 0x47); Desc = 'PNG' }        # PNG
        @{ Bytes = [byte[]]@(0xFF, 0xD8, 0xFF); Desc = 'JPEG' }             # JPEG
        @{ Bytes = [byte[]]@(0x47, 0x49, 0x46, 0x38); Desc = 'GIF' }        # GIF
        @{ Bytes = [byte[]]@(0x42, 0x4D); Desc = 'BMP' }                    # BMP
        @{ Bytes = [byte[]]@(0x52, 0x49, 0x46, 0x46); Desc = 'WEBP/AVI' }   # RIFF (WEBP or AVI)
    )
    'Archives'    = @(
        @{ Bytes = [byte[]]@(0x50, 0x4B, 0x03, 0x04); Desc = 'ZIP' }        # ZIP/DOCX/XLSX
        @{ Bytes = [byte[]]@(0x52, 0x61, 0x72, 0x21); Desc = 'RAR' }        # RAR
        @{ Bytes = [byte[]]@(0x37, 0x7A, 0xBC, 0xAF); Desc = '7Z' }         # 7-Zip
        @{ Bytes = [byte[]]@(0x1F, 0x8B); Desc = 'GZIP' }                   # GZIP
    )
    'Executables' = @(
        @{ Bytes = [byte[]]@(0x4D, 0x5A); Desc = 'EXE/DLL' }                # MZ (PE executable)
    )
    'Videos'      = @(
        @{ Bytes = [byte[]]@(0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70); Desc = 'MP4' }  # MP4 ftyp
        @{ Bytes = [byte[]]@(0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70); Desc = 'MP4' }  # MP4 ftyp variant
        @{ Bytes = [byte[]]@(0x1A, 0x45, 0xDF, 0xA3); Desc = 'MKV/WEBM' }   # Matroska
    )
    'Audio'       = @(
        @{ Bytes = [byte[]]@(0x49, 0x44, 0x33); Desc = 'MP3' }              # ID3 tag
        @{ Bytes = [byte[]]@(0xFF, 0xFB); Desc = 'MP3' }                    # MP3 sync
        @{ Bytes = [byte[]]@(0x66, 0x4C, 0x61, 0x43); Desc = 'FLAC' }       # fLaC
    )
    'Databases'   = @(
        @{ Bytes = [byte[]]@(0x53, 0x51, 0x4C, 0x69, 0x74, 0x65); Desc = 'SQLite' }  # SQLite format 3
    )
}

# Screenshot name patterns (language-agnostic)
$Script:ScreenshotPatterns = @(
    'screenshot*', 'Screen Shot*', 'Capture*', 'Snip*', 'Screenshot_*',
    '*_screenshot_*', 'scr_*', 'snap_*', 'Clipboard*', 'image_*'
)

# Project folder markers
$Script:ProjectMarkers = @{
    'Node.js' = @('package.json')
    '.NET'    = @('*.csproj', '*.sln', '*.fsproj', '*.vbproj')
    'Python'  = @('requirements.txt', 'setup.py', 'pyproject.toml', 'Pipfile')
    'Java'    = @('pom.xml', 'build.gradle', 'build.gradle.kts')
    'Rust'    = @('Cargo.toml')
    'Go'      = @('go.mod')
    'Ruby'    = @('Gemfile')
    'PHP'     = @('composer.json')
    'Git'     = @('.git')
}

# Size tier boundaries
$Script:SizeTiers = [ordered]@{
    'Tiny (< 100 KB)'   = 100KB
    'Small (100KB-1MB)' = 1MB
    'Medium (1-10 MB)'  = 10MB
    'Large (10-100 MB)' = 100MB
    'Huge (100MB-1GB)'  = 1GB
    'Massive (> 1 GB)'  = [long]::MaxValue
}

# Content-based classification keywords
$Script:ContentKeywords = @{
    'Financial' = @('invoice', 'payment', 'receipt', 'bank', 'salary', 'tax', 'budget', 'expense', 'revenue', 'profit', 'debit', 'credit', 'transaction', 'balance', 'refund')
    'Medical'   = @('patient', 'diagnosis', 'prescription', 'treatment', 'hospital', 'medical', 'health', 'symptom', 'therapy', 'clinical', 'doctor', 'nurse')
    'Legal'     = @('contract', 'agreement', 'clause', 'liability', 'plaintiff', 'defendant', 'court', 'legal', 'attorney', 'lawsuit', 'witness', 'verdict', 'settlement')
    'Personal'  = @('resume', 'cv', 'passport', 'license', 'birth', 'marriage', 'address', 'birthday', 'social security')
    'Technical' = @('api', 'server', 'database', 'deploy', 'config', 'migration', 'documentation', 'specification', 'architecture', 'endpoint')
}

# PII detection patterns (sensitive data)
$Script:PIIPatterns = @{
    'Email'      = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    'Phone'      = '\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'
    'CreditCard' = '\b(?:4\d{3}|5[1-5]\d{2}|6011|3[47]\d{2})[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'
    'SSN'        = '\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b'
    'CCCD'       = '\b0\d{11}\b'  # Vietnamese Citizen ID (12 digits starting with 0)
}

$Script:ReadableExts = @('.txt', '.csv', '.md', '.log', '.json', '.xml', '.yaml', '.yml', '.html', '.htm', '.ini', '.cfg', '.conf', '.env', '.sql', '.py', '.js', '.ts', '.ps1', '.bat', '.sh', '.rtf')

function Get-ContentCategory {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($Script:ReadableExts -notcontains $ext) { return @{Category = 'Non-Text'; PII = @() } }
    try {
        $content = Get-Content $FilePath -TotalCount 200 -EA Stop | Out-String  # Read first 200 lines only
        if (-not $content -or $content.Length -lt 10) { return @{Category = 'Empty-Text'; PII = @() } }

        # Check for PII first (sensitive)
        $piiFound = @()
        foreach ($kv in $Script:PIIPatterns.GetEnumerator()) {
            if ($content -match $kv.Value) { $piiFound += $kv.Key }
        }
        if ($piiFound.Count -gt 0) { return @{Category = 'Sensitive'; PII = $piiFound } }

        # Keyword-based classification
        $best = 'General'; $bestScore = 0
        foreach ($kv in $Script:ContentKeywords.GetEnumerator()) {
            $score = 0
            foreach ($kw in $kv.Value) {
                if ($content -match "\b$kw\b") { $score++ }
            }
            if ($score -gt $bestScore) { $bestScore = $score; $best = $kv.Key }
        }
        if ($bestScore -ge 2) { return @{Category = $best; PII = @() } }
        return @{Category = 'General'; PII = @() }
    }
    catch { return @{Category = 'Unreadable'; PII = @() } }
}

$Script:OrganizeLogFile = Join-Path $env:APPDATA 'DiskCleanerPro\organize_log.json'

# Detect file type by magic bytes (for files without extensions or unknown extensions)
function Get-MagicCategory {
    param([string]$FilePath)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath) | Select-Object -First 16
        if ($bytes.Length -lt 2) { return $null }
        foreach ($kv in $Script:MagicBytes.GetEnumerator()) {
            foreach ($sig in $kv.Value) {
                $sigLen = $sig.Bytes.Length
                if ($bytes.Length -ge $sigLen) {
                    $match = $true
                    for ($i = 0; $i -lt $sigLen; $i++) {
                        if ($bytes[$i] -ne $sig.Bytes[$i]) { $match = $false; break }
                    }
                    if ($match) { return $kv.Key }
                }
            }
        }
    }
    catch {}
    return $null
}

# Check if a file is a screenshot by its name
function Test-Screenshot {
    param([string]$FileName)
    foreach ($pat in $Script:ScreenshotPatterns) {
        if ($FileName -like $pat) { return $true }
    }
    return $false
}

# Detect project type in a folder
function Get-ProjectType {
    param([string]$FolderPath)
    foreach ($kv in $Script:ProjectMarkers.GetEnumerator()) {
        foreach ($marker in $kv.Value) {
            if (Get-ChildItem -Path $FolderPath -Filter $marker -Force -EA SilentlyContinue | Select-Object -First 1) {
                return $kv.Key
            }
        }
    }
    return $null
}

# Enhanced file category detection: extension → screenshot check → magic bytes → Other
function Get-FileCategory {
    param([string]$Extension, [string]$FileName = '', [string]$FilePath = '')
    $ext = $Extension.ToLower()
    # 1. Check screenshot pattern first (for images)
    if ($FileName -and (Test-Screenshot $FileName)) {
        $imgExts = $Script:Categories['Images']
        if ($ext -and $imgExts -contains $ext) { return 'Screenshots' }
    }
    # 2. Extension-based lookup
    if ($ext) {
        foreach ($kv in $Script:Categories.GetEnumerator()) {
            if ($kv.Key -eq 'Screenshots') { continue }  # Skip (detected by name)
            if ($kv.Value -contains $ext) { return $kv.Key }
        }
    }
    # 3. Magic bytes fallback (for unknown/missing extensions)
    if ($FilePath -and (Test-Path $FilePath)) {
        $magicCat = Get-MagicCategory $FilePath
        if ($magicCat) { return $magicCat }
    }
    return 'Other'
}
function Get-SizeTier { param([long]$Size); foreach ($kv in $Script:SizeTiers.GetEnumerator()) { if ($Size -lt $kv.Value) { return $kv.Key } }; return 'Massive (> 1 GB)' }
function Get-DateFolder { param([datetime]$Date); return Join-Path ($Date.ToString('yyyy')) $Date.ToString('yyyy-MM MMMM') }

function Get-OrganizePlan {
    param(
        [string]$FolderPath,
        [string]$Mode = 'ByType',
        [switch]$Recurse,
        # Exclusion parameters (Layer 2+4)
        [string[]]$ExcludeFiles = @(),
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeExtensions = @(),
        [string[]]$IncludeOnly = @(),
        [long]$MinSize = 0,
        [long]$MaxSize = [long]::MaxValue,
        [int]$MinAgeDays = 0,
        [int]$MaxAgeDays = [int]::MaxValue,
        [switch]$SkipHidden,
        [switch]$SkipSystem,
        [switch]$SkipInUse,
        [switch]$NoSystemDefaults
    )
    # ByType | ByDate | BySize | ByContent
    $plan = [System.Collections.ArrayList]::new()
    $stats = @{}; $hasSensitive = $false; $excludedCount = 0

    # Build exclusion options hashtable
    $excludeOpts = @{
        NoSystemDefaults  = $NoSystemDefaults.IsPresent
        ExcludeFiles      = $ExcludeFiles
        ExcludeDirs       = $ExcludeDirs
        ExcludeExtensions = $ExcludeExtensions
        IncludeOnly       = $IncludeOnly
        MinSize           = $MinSize
        MaxSize           = $MaxSize
        MinAgeDays        = $MinAgeDays
        MaxAgeDays        = $MaxAgeDays
        SkipHidden        = $SkipHidden.IsPresent
        SkipSystem        = $SkipSystem.IsPresent
        SkipInUse         = $SkipInUse.IsPresent
    }

    # Pre-filter directories for Recurse mode
    $files = if ($Recurse) {
        Get-ChildItem -Path $FolderPath -File -Recurse -Force -EA SilentlyContinue
    }
    else {
        Get-ChildItem -Path $FolderPath -File -Force -EA SilentlyContinue
    }
    $files | ForEach-Object {
        $piiInfo = @()

        # === EXCLUSION CHECK ===
        $exCheck = Test-FileExcluded -File $_ -Options $excludeOpts
        if ($exCheck.Excluded) {
            $excludedCount++
            return  # skip this file
        }
        # Determine destination subfolder based on mode
        $subFolder = switch ($Mode) {
            'ByDate' {
                $bestDate = $_.CreationTime
                if ($_.LastWriteTime -lt $bestDate) { $bestDate = $_.LastWriteTime }
                Get-DateFolder $bestDate
            }
            'BySize' { Get-SizeTier $_.Length }
            'ByContent' {
                $cc = Get-ContentCategory $_.FullName
                $piiInfo = $cc.PII
                if ($cc.PII.Count -gt 0) { $hasSensitive = $true }
                $cc.Category
            }
            default { Get-FileCategory -Extension $_.Extension -FileName $_.Name -FilePath $_.FullName }
        }

        $destDir = Join-Path $FolderPath $subFolder
        $destFile = Join-Path $destDir $_.Name

        # Handle conflicts (auto-rename)
        if (Test-Path $destFile) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $ext = $_.Extension
            $i = 2
            do {
                $destFile = Join-Path $destDir "$base ($i)$ext"
                $i++
            } while (Test-Path $destFile)
        }

        $cat = switch ($Mode) {
            'ByDate' { $subFolder.Split('\')[0] }  # year
            'BySize' { $subFolder }
            default { $subFolder }
        }

        [void]$plan.Add([PSCustomObject]@{
                Name        = $_.Name
                Source      = $_.FullName
                Category    = $cat
                Destination = $destFile
                DestFolder  = $subFolder
                Size        = $_.Length
                SizeText    = FmtSize $_.Length
                Modified    = $_.LastWriteTime.ToString('yyyy-MM-dd')
                PII         = if ($piiInfo.Count -gt 0) { $piiInfo -join ', ' }else { '' }
            })

        if ($stats.ContainsKey($subFolder)) { $stats[$subFolder].Count++; $stats[$subFolder].Size += $_.Length }
        else { $stats[$subFolder] = @{Count = 1; Size = $_.Length } }
    }

    return @{Plan = $plan; Stats = $stats; Total = $plan.Count; Mode = $Mode; HasSensitive = $hasSensitive; ExcludedCount = $excludedCount }
}

function Invoke-OrganizeFiles {
    param([System.Collections.ArrayList]$Plan, [string]$FolderPath)
    $log = [System.Collections.ArrayList]::new()
    $moved = 0; $errors = 0

    foreach ($item in $Plan) {
        try {
            $destDir = Split-Path $item.Destination
            if (-not (Test-Path $destDir)) { New-Item $destDir -ItemType Directory -Force | Out-Null }
            Move-Item -Path $item.Source -Destination $item.Destination -Force -EA Stop
            [void]$log.Add(@{From = $item.Source; To = $item.Destination })
            $moved++
        }
        catch { $errors++ }
    }

    # Save undo log
    $logDir = Split-Path $Script:OrganizeLogFile
    if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
    @{Timestamp = (Get-Date).ToString('o'); Folder = $FolderPath; Moves = $log } | ConvertTo-Json -Depth 5 | Set-Content $Script:OrganizeLogFile -Encoding UTF8

    return @{Moved = $moved; Errors = $errors; LogFile = $Script:OrganizeLogFile }
}

function Invoke-UndoOrganize {
    if (-not (Test-Path $Script:OrganizeLogFile)) { return @{Restored = 0; Errors = 0; Message = 'No organize log found' } }
    try {
        $data = Get-Content $Script:OrganizeLogFile -Raw | ConvertFrom-Json
        $restored = 0; $errors = 0
        $moves = @($data.Moves)
        [Array]::Reverse($moves)
        foreach ($m in $moves) {
            try {
                if (Test-Path $m.To) {
                    $srcDir = Split-Path $m.From
                    if (-not (Test-Path $srcDir)) { New-Item $srcDir -ItemType Directory -Force | Out-Null }
                    Move-Item -Path $m.To -Destination $m.From -Force -EA Stop
                    $restored++
                }
            }
            catch { $errors++ }
        }
        # Clean empty category folders left behind
        $folder = $data.Folder
        $allCats = @($Script:Categories.Keys) + @('Other')
        foreach ($cat in $allCats) {
            $catDir = Join-Path $folder $cat
            if ((Test-Path $catDir) -and @(Get-ChildItem $catDir -Force -EA SilentlyContinue).Count -eq 0) {
                Remove-Item $catDir -Force -EA SilentlyContinue
            }
        }
        # Also clean year/month folders
        Get-ChildItem $folder -Directory -EA SilentlyContinue | Where-Object { $_.Name -match '^\d{4}$' } | ForEach-Object {
            Get-ChildItem $_.FullName -Directory -EA SilentlyContinue | Where-Object {
                @(Get-ChildItem $_.FullName -Force -EA SilentlyContinue).Count -eq 0
            } | ForEach-Object { Remove-Item $_.FullName -Force -EA SilentlyContinue }
            if (@(Get-ChildItem $_.FullName -Force -EA SilentlyContinue).Count -eq 0) {
                Remove-Item $_.FullName -Force -EA SilentlyContinue
            }
        }
        Remove-Item $Script:OrganizeLogFile -Force -EA SilentlyContinue
        return @{Restored = $restored; Errors = $errors; Message = "Restored $restored files to original locations" }
    }
    catch {
        return @{Restored = 0; Errors = 1; Message = $_.Exception.Message }
    }
}
