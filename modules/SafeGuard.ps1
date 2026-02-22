# DiskCleaner Pro v2.1 - SafeGuard Module
# 5-layer file protection system to prevent accidental data loss

$Script:KeeplistFile = Join-Path $env:APPDATA 'DiskCleanerPro\keeplist.json'

# Layer 1: Critical Path Blacklist
$Script:CriticalPaths = @(
    'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64', 'C:\Windows\WinSxS',
    'C:\Program Files', 'C:\Program Files (x86)',
    'C:\ProgramData\Microsoft', 'C:\System Volume Information',
    'C:\Recovery', 'C:\$Recycle.Bin', 'C:\Boot', 'C:\EFI'
)
$Script:CriticalFiles = @(
    'pagefile.sys', 'swapfile.sys', 'hiberfil.sys', 'bootmgr', 'bootmgfw.efi',
    'NTUSER.DAT', 'UsrClass.dat', 'ntoskrnl.exe', 'hal.dll', 'winload.exe',
    'ntldr', 'NTDETECT.COM', 'boot.ini', 'desktop.ini'
)
$Script:CriticalExtensions = @('.sys', '.drv')

# Layer 2: File attribute checks
function Test-SystemProtected {
    param([string]$Path)
    try {
        $attr = [System.IO.File]::GetAttributes($Path)
        # Skip system+hidden combo (usually OS files)
        if (($attr -band [System.IO.FileAttributes]::System) -and ($attr -band [System.IO.FileAttributes]::Hidden)) { return $true }
        # Skip reparse points (junctions to system dirs)
        if ($attr -band [System.IO.FileAttributes]::ReparsePoint) {
            try {
                $target = (Get-Item $Path -Force -EA Stop).Target
                if ($target) {
                    foreach ($cp in $Script:CriticalPaths) {
                        if ($target -like "$cp*") { return $true }
                    }
                }
            } catch {}
        }
    } catch {}
    return $false
}

# Layer 3: Path containment (from clean-stack)
function Test-WithinScanDir {
    param([string]$FilePath, [string]$ScanDir)
    if (-not $ScanDir) { return $true }  # no scan dir set = allow
    $fp = [System.IO.Path]::GetFullPath($FilePath).TrimEnd('\')
    $sd = [System.IO.Path]::GetFullPath($ScanDir).TrimEnd('\')
    return $fp.StartsWith($sd, [System.StringComparison]::OrdinalIgnoreCase)
}

# Layer 5: User Keeplist
function Get-Keeplist {
    if (-not (Test-Path $Script:KeeplistFile)) { return @() }
    try { return @(Get-Content $Script:KeeplistFile -Raw | ConvertFrom-Json) } catch { return @() }
}

function Save-Keeplist { param($list)
    $dir = Split-Path $Script:KeeplistFile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    $list | ConvertTo-Json | Set-Content $Script:KeeplistFile -Encoding UTF8
}

function Add-ToKeeplist { param([string]$Path)
    $kl = @(Get-Keeplist)
    $fp = [System.IO.Path]::GetFullPath($Path)
    if ($kl -notcontains $fp) { $kl += $fp; Save-Keeplist $kl }
}

function Remove-FromKeeplist { param([string]$Path)
    $kl = @(Get-Keeplist)
    $fp = [System.IO.Path]::GetFullPath($Path)
    $kl = @($kl | Where-Object { $_ -ne $fp })
    Save-Keeplist $kl
}

function Test-InKeeplist { param([string]$Path)
    $kl = Get-Keeplist
    $fp = [System.IO.Path]::GetFullPath($Path)
    foreach ($k in $kl) {
        if ($fp -eq $k -or $fp.StartsWith("$k\", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# Master safety check
function Test-SafeToDelete {
    param([string]$Path, [string]$ScanDir = '')

    # Layer 1: Critical path blacklist
    $fp = [System.IO.Path]::GetFullPath($Path)
    foreach ($cp in $Script:CriticalPaths) {
        if ($fp -ieq $cp -or ($fp.StartsWith("$cp\", [System.StringComparison]::OrdinalIgnoreCase) -and $fp.Length -le ($cp.Length + 20))) {
            return @{Safe=$false; Reason="Critical system path: $cp"}
        }
    }
    $fn = [System.IO.Path]::GetFileName($fp)
    if ($Script:CriticalFiles -contains $fn) {
        return @{Safe=$false; Reason="Critical system file: $fn"}
    }
    $ext = [System.IO.Path]::GetExtension($fp)
    if ($Script:CriticalExtensions -contains $ext -and $fp -like 'C:\Windows\*') {
        return @{Safe=$false; Reason="Protected driver/system file"}
    }

    # Layer 2: File attributes
    if (Test-SystemProtected $fp) {
        return @{Safe=$false; Reason="System-protected file (Hidden+System attributes)"}
    }

    # Layer 3: Path containment
    if ($ScanDir -and -not (Test-WithinScanDir $fp $ScanDir)) {
        return @{Safe=$false; Reason="Outside scan directory boundary"}
    }

    # Layer 5: User keeplist
    if (Test-InKeeplist $fp) {
        return @{Safe=$false; Reason="Protected by user keeplist"}
    }

    return @{Safe=$true; Reason=''}
}

# Layer 4: Recycle Bin deletion (default safe mode)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class RecycleBinHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHFILEOPSTRUCT {
        public IntPtr hwnd;
        public uint wFunc;
        [MarshalAs(UnmanagedType.LPWStr)] public string pFrom;
        [MarshalAs(UnmanagedType.LPWStr)] public string pTo;
        public ushort fFlags;
        public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpszProgressTitle;
    }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHFileOperation(ref SHFILEOPSTRUCT lpFileOp);
    public static int MoveToRecycleBin(string path) {
        SHFILEOPSTRUCT op = new SHFILEOPSTRUCT();
        op.wFunc = 3; // FO_DELETE
        op.pFrom = path + "\0\0";
        op.fFlags = 0x0040 | 0x0010 | 0x0004; // FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT
        return SHFileOperation(ref op);
    }
}
"@ -EA SilentlyContinue

function Move-ToRecycleBin {
    param([string]$Path)
    try {
        $result = [RecycleBinHelper]::MoveToRecycleBin($Path)
        return ($result -eq 0)
    } catch {
        return $false
    }
}

# Safe delete wrapper
function Invoke-SafeDelete {
    param([string]$Path, [string]$ScanDir = '', [bool]$UseRecycleBin = $true)
    $check = Test-SafeToDelete -Path $Path -ScanDir $ScanDir
    if (-not $check.Safe) { return @{Deleted=$false; Reason=$check.Reason} }
    try {
        if ($UseRecycleBin) {
            $ok = Move-ToRecycleBin $Path
            if ($ok) { return @{Deleted=$true; Reason='Moved to Recycle Bin'} }
        }
        # Fallback to permanent delete
        if ((Get-Item $Path -Force -EA Stop).PSIsContainer) {
            Remove-Item $Path -Recurse -Force -EA Stop
        } else {
            Remove-Item $Path -Force -EA Stop
        }
        return @{Deleted=$true; Reason='Permanently deleted'}
    } catch {
        return @{Deleted=$false; Reason=$_.Exception.Message}
    }
}
