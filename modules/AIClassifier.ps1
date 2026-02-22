# DiskCleaner Pro v3.0 - AI Classifier Module (Groq - 100% FREE)
# Uses Groq API with Llama 3.1 8B - completely free, no credit card needed
# Get free API key: https://console.groq.com/keys (sign in with Google/GitHub)
# Limits: 30 RPM, 14,400 req/day, 6,000 tokens/min - MORE than enough

$Script:AIConfigFile = Join-Path $env:APPDATA 'DiskCleanerPro\ai_config.json'
$Script:AICacheFile = Join-Path $env:APPDATA 'DiskCleanerPro\ai_cache.json'
$Script:GroqApiBase = 'https://api.groq.com/openai/v1/chat/completions'

# ============================================================
# Config Management
# ============================================================
function Get-AIConfig {
    if (-not (Test-Path $Script:AIConfigFile)) {
        return @{ ApiKey = ''; Enabled = $false; Provider = 'groq' }
    }
    try {
        $data = Get-Content $Script:AIConfigFile -Raw | ConvertFrom-Json
        return @{
            ApiKey   = if ($data.ApiKey) { $data.ApiKey } else { '' }
            Enabled  = if ($null -ne $data.Enabled) { $data.Enabled } else { $false }
            Provider = 'groq'
        }
    }
    catch {
        return @{ ApiKey = ''; Enabled = $false; Provider = 'groq' }
    }
}

function Save-AIConfig {
    param($Config)
    $dir = Split-Path $Script:AIConfigFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    @{ ApiKey = $Config.ApiKey; Enabled = $Config.Enabled; Provider = 'groq' } |
    ConvertTo-Json | Set-Content $Script:AIConfigFile -Encoding UTF8
}

function Test-AIReady {
    $cfg = Get-AIConfig
    return ($cfg.Enabled -and $cfg.ApiKey -and $cfg.ApiKey.Length -gt 10)
}

# ============================================================
# Cache Management (avoid redundant API calls)
# ============================================================
function Get-AICache {
    if (-not (Test-Path $Script:AICacheFile)) { return @{} }
    try {
        $raw = Get-Content $Script:AICacheFile -Raw | ConvertFrom-Json
        $cache = @{}
        $raw.PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
        return $cache
    }
    catch { return @{} }
}

function Save-AICache {
    param($Cache)
    $dir = Split-Path $Script:AICacheFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    $keys = @($Cache.Keys)
    if ($keys.Count -gt 1000) {
        $removeCount = $keys.Count - 800
        $keys | Select-Object -First $removeCount | ForEach-Object { $Cache.Remove($_) }
    }
    $Cache | ConvertTo-Json -Depth 3 | Set-Content $Script:AICacheFile -Encoding UTF8
}

function Get-CacheKey {
    param([string]$FileName, [long]$FileSize)
    return "$FileName|$FileSize"
}

# ============================================================
# Content Extraction
# ============================================================
$Script:TextExts = @('.txt', '.csv', '.md', '.log', '.json', '.xml', '.yaml', '.yml',
    '.html', '.htm', '.ini', '.cfg', '.conf', '.env', '.sql', '.py', '.js', '.ts', '.ps1',
    '.bat', '.sh', '.rtf', '.css', '.scss', '.java', '.cs', '.cpp', '.c', '.go', '.rs',
    '.rb', '.php', '.swift', '.kt', '.lua', '.r', '.toml')

function Get-FileSnippet {
    param([string]$FilePath, [int]$MaxChars = 300)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $name = [System.IO.Path]::GetFileName($FilePath)
    if ($Script:TextExts -notcontains $ext) {
        return "Binary file: $name"
    }
    try {
        $content = Get-Content $FilePath -TotalCount 20 -EA Stop | Out-String
        if ($content.Length -gt $MaxChars) { $content = $content.Substring(0, $MaxChars) }
        return $content.Trim()
    }
    catch { return "File: $name" }
}

# ============================================================
# Groq API Call (OpenAI-compatible)
# ============================================================
function Invoke-GroqClassify {
    param(
        [array]$Files,      # Array of @{Name; Size; Snippet}
        [string[]]$Categories
    )
    $cfg = Get-AIConfig
    if (-not $cfg.ApiKey) { return $null }

    $catList = $Categories -join ', '
    $fileList = ($Files | ForEach-Object { "- $($_.Name)" }) -join "`n"

    $prompt = @"
Classify each file into ONE category from: $catList, Other
Reply ONLY with a JSON array, no explanation:
[{"file":"name.ext","category":"Cat"}]

Files:
$fileList
"@

    $body = @{
        model           = 'llama-3.1-8b-instant'
        messages        = @(
            @{ role = 'system'; content = 'You are a file classifier. Reply only with JSON.' }
            @{ role = 'user'; content = $prompt }
        )
        temperature     = 0.1
        max_tokens      = 512
        response_format = @{ type = 'json_object' }
    } | ConvertTo-Json -Depth 5

    try {
        $headers = @{ 'Authorization' = "Bearer $($cfg.ApiKey)"; 'Content-Type' = 'application/json' }
        $response = Invoke-RestMethod -Uri $Script:GroqApiBase -Method Post -Body $body -Headers $headers -TimeoutSec 15
        $text = $response.choices[0].message.content
        # Parse - handle both array and object with array property
        $parsed = $text | ConvertFrom-Json
        if ($parsed -is [array]) { return $parsed }
        # If wrapped in object, find the array property
        $parsed.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [array]) { return $_.Value }
        }
        return $null
    }
    catch {
        return $null
    }
}

# ============================================================
# Main Classification Function
# ============================================================
function Invoke-AIClassify {
    param(
        [System.IO.FileInfo[]]$Files,
        [int]$BatchSize = 10
    )
    if (-not (Test-AIReady)) { return @{} }

    $cache = Get-AICache
    $categories = @('Documents', 'Images', 'Screenshots', 'Videos', 'Audio', 'Archives',
        'Ebooks', 'Code', 'Data', 'Databases', 'Executables', 'Fonts', 'DiskImages',
        'Shortcuts', 'Backups', 'Design')
    $results = @{}
    $uncached = [System.Collections.ArrayList]::new()

    foreach ($f in $Files) {
        $key = Get-CacheKey $f.Name $f.Length
        if ($cache.ContainsKey($key)) {
            $results[$f.FullName] = $cache[$key]
        }
        else {
            [void]$uncached.Add(@{ File = $f; Key = $key })
        }
    }

    # Batch classify
    for ($i = 0; $i -lt $uncached.Count; $i += $BatchSize) {
        $end = [math]::Min($i + $BatchSize - 1, $uncached.Count - 1)
        $batch = $uncached[$i..$end]
        $apiFiles = $batch | ForEach-Object {
            @{ Name = $_.File.Name; Size = $_.File.Length; Snippet = (Get-FileSnippet $_.File.FullName) }
        }
        $aiResults = Invoke-GroqClassify -Files $apiFiles -Categories $categories
        if ($aiResults) {
            foreach ($r in $aiResults) {
                $matchItem = $batch | Where-Object { $_.File.Name -eq $r.file } | Select-Object -First 1
                if ($matchItem) {
                    $entry = @{ Category = $r.category }
                    $results[$matchItem.File.FullName] = $entry
                    $cache[$matchItem.Key] = $entry
                }
            }
        }
        if ($i + $BatchSize -lt $uncached.Count) { Start-Sleep -Milliseconds 300 }
    }

    if ($uncached.Count -gt 0) { Save-AICache $cache }
    return $results
}

# ============================================================
# FmtSize fallback
# ============================================================
if (-not (Get-Command FmtSize -EA SilentlyContinue)) {
    function FmtSize([long]$b) {
        if ($b -ge 1GB) { return '{0:N1} GB' -f ($b / 1GB) }
        if ($b -ge 1MB) { return '{0:N1} MB' -f ($b / 1MB) }
        if ($b -ge 1KB) { return '{0:N0} KB' -f ($b / 1KB) }
        return "$b B"
    }
}
