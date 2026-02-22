# DiskCleaner Pro v3.0 - Gemini AI Classifier Module
# Uses Google Gemini API (free tier) for intelligent file classification
# API Key: Free from https://aistudio.google.com/apikey
# Rate: 15 RPM / 1,000 req/day (free tier)

$Script:GeminiConfigFile = Join-Path $env:APPDATA 'DiskCleanerPro\gemini_config.json'
$Script:GeminiCacheFile = Join-Path $env:APPDATA 'DiskCleanerPro\ai_cache.json'
$Script:GeminiApiBase = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent'

# ============================================================
# Config Management
# ============================================================
function Get-GeminiConfig {
    if (-not (Test-Path $Script:GeminiConfigFile)) {
        return @{ ApiKey = ''; Enabled = $false; Model = 'gemini-2.0-flash' }
    }
    try {
        $data = Get-Content $Script:GeminiConfigFile -Raw | ConvertFrom-Json
        return @{
            ApiKey  = if ($data.ApiKey) { $data.ApiKey } else { '' }
            Enabled = if ($null -ne $data.Enabled) { $data.Enabled } else { $false }
            Model   = if ($data.Model) { $data.Model } else { 'gemini-2.0-flash' }
        }
    }
    catch {
        return @{ ApiKey = ''; Enabled = $false; Model = 'gemini-2.0-flash' }
    }
}

function Save-GeminiConfig {
    param($Config)
    $dir = Split-Path $Script:GeminiConfigFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    @{ ApiKey = $Config.ApiKey; Enabled = $Config.Enabled; Model = $Config.Model } |
    ConvertTo-Json | Set-Content $Script:GeminiConfigFile -Encoding UTF8
}

function Test-GeminiReady {
    $cfg = Get-GeminiConfig
    return ($cfg.Enabled -and $cfg.ApiKey -and $cfg.ApiKey.Length -gt 10)
}

# ============================================================
# Cache Management (avoid redundant API calls)
# ============================================================
function Get-AICache {
    if (-not (Test-Path $Script:GeminiCacheFile)) { return @{} }
    try {
        $raw = Get-Content $Script:GeminiCacheFile -Raw | ConvertFrom-Json
        $cache = @{}
        $raw.PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
        return $cache
    }
    catch { return @{} }
}

function Save-AICache {
    param($Cache)
    $dir = Split-Path $Script:GeminiCacheFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    # Keep cache size under 1000 entries
    $keys = @($Cache.Keys)
    if ($keys.Count -gt 1000) {
        $removeCount = $keys.Count - 800
        $keys | Select-Object -First $removeCount | ForEach-Object { $Cache.Remove($_) }
    }
    $Cache | ConvertTo-Json -Depth 3 | Set-Content $Script:GeminiCacheFile -Encoding UTF8
}

function Get-CacheKey {
    param([string]$FileName, [long]$FileSize, [string]$ContentSnippet)
    return "$FileName|$FileSize|$($ContentSnippet.Length)"
}

# ============================================================
# Content Extraction (read file snippets for AI)
# ============================================================
$Script:TextReadableExts = @('.txt', '.csv', '.md', '.log', '.json', '.xml', '.yaml', '.yml',
    '.html', '.htm', '.ini', '.cfg', '.conf', '.env', '.sql', '.py', '.js', '.ts', '.ps1',
    '.bat', '.sh', '.rtf', '.css', '.scss', '.java', '.cs', '.cpp', '.c', '.go', '.rs',
    '.rb', '.php', '.swift', '.kt', '.lua', '.r', '.toml')

function Get-FileSnippet {
    param([string]$FilePath, [int]$MaxChars = 500)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($Script:TextReadableExts -notcontains $ext) {
        return "[Binary file: $([System.IO.Path]::GetFileName($FilePath)), $(FmtSize (Get-Item $FilePath).Length)]"
    }
    try {
        $content = Get-Content $FilePath -TotalCount 30 -EA Stop | Out-String
        if ($content.Length -gt $MaxChars) { $content = $content.Substring(0, $MaxChars) + '...' }
        return $content
    }
    catch {
        return "[Unable to read file content]"
    }
}

# ============================================================
# Gemini API Call
# ============================================================
function Invoke-GeminiClassify {
    param(
        [array]$Files,  # Array of @{Name; Size; Snippet}
        [string[]]$Categories
    )
    $cfg = Get-GeminiConfig
    if (-not $cfg.ApiKey) { return $null }

    # Build prompt for batch classification
    $catList = $Categories -join ', '
    $fileList = ($Files | ForEach-Object {
            "- File: `"$($_.Name)`" ($(FmtSize $_.Size))`n  Content: $($_.Snippet)"
        }) -join "`n"

    $prompt = @"
Classify these files into the most appropriate category.
Available categories: $catList, Other

For each file, respond with ONLY a JSON array like:
[{"file":"filename.ext","category":"CategoryName","confidence":0.95}]

Files to classify:
$fileList
"@

    $body = @{
        contents         = @(@{
                parts = @(@{ text = $prompt })
            })
        generationConfig = @{
            temperature      = 0.1
            maxOutputTokens  = 1024
            responseMimeType = 'application/json'
        }
    } | ConvertTo-Json -Depth 5

    $url = "$($Script:GeminiApiBase)?key=$($cfg.ApiKey)"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 30
        $text = $response.candidates[0].content.parts[0].text
        # Parse JSON response
        $results = $text | ConvertFrom-Json
        return $results
    }
    catch {
        return $null
    }
}

# ============================================================
# Main Classification Function (with cache)
# ============================================================
function Invoke-AIClassify {
    param(
        [System.IO.FileInfo[]]$Files,
        [int]$BatchSize = 8
    )

    if (-not (Test-GeminiReady)) { return @{} }

    $cache = Get-AICache
    $categories = @($Script:Categories.Keys | Where-Object { $_ -ne 'Screenshots' })
    $results = @{}
    $uncached = [System.Collections.ArrayList]::new()

    # Check cache first
    foreach ($f in $Files) {
        $snippet = Get-FileSnippet $f.FullName
        $key = Get-CacheKey $f.Name $f.Length $snippet
        if ($cache.ContainsKey($key)) {
            $results[$f.FullName] = $cache[$key]
        }
        else {
            [void]$uncached.Add(@{ File = $f; Snippet = $snippet; Key = $key })
        }
    }

    # Batch classify uncached files
    for ($i = 0; $i -lt $uncached.Count; $i += $BatchSize) {
        $batch = $uncached[$i..([math]::Min($i + $BatchSize - 1, $uncached.Count - 1))]
        $apiFiles = $batch | ForEach-Object {
            @{ Name = $_.File.Name; Size = $_.File.Length; Snippet = $_.Snippet }
        }
        $aiResults = Invoke-GeminiClassify -Files $apiFiles -Categories $categories
        if ($aiResults) {
            foreach ($r in $aiResults) {
                $matchItem = $batch | Where-Object { $_.File.Name -eq $r.file } | Select-Object -First 1
                if ($matchItem) {
                    $entry = @{ Category = $r.category; Confidence = $r.confidence }
                    $results[$matchItem.File.FullName] = $entry
                    $cache[$matchItem.Key] = $entry
                }
            }
        }
        # Small delay to respect rate limits (15 RPM)
        if ($i + $BatchSize -lt $uncached.Count) { Start-Sleep -Milliseconds 500 }
    }

    # Save updated cache
    if ($uncached.Count -gt 0) { Save-AICache $cache }

    return $results
}

# ============================================================
# Utility: Format size (may be loaded from main script)
# ============================================================
if (-not (Get-Command FmtSize -EA SilentlyContinue)) {
    function FmtSize([long]$b) {
        if ($b -ge 1GB) { return '{0:N1} GB' -f ($b / 1GB) }
        if ($b -ge 1MB) { return '{0:N1} MB' -f ($b / 1MB) }
        if ($b -ge 1KB) { return '{0:N0} KB' -f ($b / 1KB) }
        return "$b B"
    }
}

# Load Categories from FolderOrganizer if available
if (-not $Script:Categories) {
    $orgPath = Join-Path $PSScriptRoot 'FolderOrganizer.ps1'
    if (Test-Path $orgPath) { . $orgPath }
}
