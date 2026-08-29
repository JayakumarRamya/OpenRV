#Requires -Version 5.1
<#
.SYNOPSIS
    Tunes Pixrock RV playback preferences for this machine.

.DESCRIPTION
    Writes real Qt QSettings keys into the preferences file that RV actually
    reads:  %APPDATA%\ASWF\OpenRV.ini

    Values are derived from the detected CPU count and installed RAM. The
    existing file is merged, never clobbered -- RV stores window geometry,
    annotation colours, audio devices and much else in the same file.

    Key names below were taken from src/lib/app/RvCommon/RvPreferences.cpp
    and src/lib/app/RvApp/Options.cpp. Do not invent keys: RV silently
    ignores anything it does not recognise.

.PARAMETER LookAheadGB
    Override the computed look-ahead cache size, in gigabytes.

.PARAMETER ReaderThreads
    Override the computed reader thread count. RV clamps this to 1..32.

.PARAMETER KeepVSync
    Leave VSync enabled. Default is to disable it for maximum throughput.

.PARAMETER Revert
    Restore the most recent backup written by this script and exit.

.PARAMETER DryRun
    Print the planned changes without writing anything.

.EXAMPLE
    .\Install-PixrockPrefs.ps1
    .\Install-PixrockPrefs.ps1 -LookAheadGB 32 -ReaderThreads 8
    .\Install-PixrockPrefs.ps1 -Revert
#>
[CmdletBinding()]
param(
    [int]    $LookAheadGB   = 0,
    [int]    $RegionGB      = 0,
    [int]    $ReaderThreads = 0,
    [switch] $KeepVSync,
    [switch] $Revert,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# QSettings on Windows stores IniFormat/UserScope under the path set by
# RvApplication::initializeQSettings(), which is QStandardPaths::AppDataLocation
# (= %APPDATA%) with "<Organization>/<Application>.ini" appended.
# Organization and application names come from CMakeLists.txt:
#   RV_INTERNAL_ORGANIZATION_NAME = ASWF
#   RV_INTERNAL_APPLICATION_NAME  = OpenRV
# These deliberately stay "ASWF"/"OpenRV" even in Pixrock builds: PackageManager
# branches on INTERNAL_APPLICATION_NAME == "OpenRV" to decide which version field
# .rvpkg files are validated against. Renaming it breaks every package.
$IniPath = Join-Path $env:APPDATA 'ASWF\OpenRV.ini'

# ---------------------------------------------------------------------------
#  Minimal order-preserving INI reader/writer.
#
#  Qt writes the group named "General" as [%General] in INI files, because a
#  bare [General] section is where QSettings puts top-level ungrouped keys.
#  We must address it as "%General" or the value lands in a group RV never
#  reads. This is the single most common way hand-written RV prefs fail.
# ---------------------------------------------------------------------------

function Read-Ini {
    param([string] $Path)

    $sections = [ordered]@{}
    $current  = ''
    $sections[$current] = [ordered]@{}

    if (-not (Test-Path $Path)) { return $sections }

    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.+)\]$') {
            $current = $Matches[1]
            if (-not $sections.Contains($current)) { $sections[$current] = [ordered]@{} }
        }
        elseif ($trim -match '^([^=]+?)=(.*)$') {
            $sections[$current][$Matches[1].Trim()] = $Matches[2]
        }
    }
    return $sections
}

function Write-Ini {
    param([string] $Path, $Sections)

    $sb = New-Object Text.StringBuilder
    foreach ($name in $Sections.Keys) {
        $keys = $Sections[$name]
        if ($keys.Count -eq 0) { continue }
        if ($name -ne '') { [void]$sb.AppendLine("[$name]") }
        foreach ($k in $keys.Keys) { [void]$sb.AppendLine("$k=$($keys[$k])") }
        [void]$sb.AppendLine()
    }

    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # QSettings reads INI files as UTF-8; write without a BOM so Qt does not
    # treat the marker as part of the first section name.
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $sb.ToString(), $utf8NoBom)
}

function Set-Pref {
    param($Sections, [string] $Section, [string] $Key, $Value)

    if (-not $Sections.Contains($Section)) { $Sections[$Section] = [ordered]@{} }
    $old = if ($Sections[$Section].Contains($Key)) { $Sections[$Section][$Key] } else { '(unset)' }
    $Sections[$Section][$Key] = $Value
    [pscustomobject]@{
        Setting = "[$Section] $Key"
        Was     = $old
        Now     = "$Value"
    }
}

# ---------------------------------------------------------------------------
#  Revert
# ---------------------------------------------------------------------------

if ($Revert) {
    $backups = Get-ChildItem -Path (Split-Path $IniPath -Parent) `
                             -Filter 'OpenRV.ini.pixrock-backup_*' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending
    if (-not $backups) {
        Write-Host "No Pixrock backup found next to $IniPath" -ForegroundColor Yellow
        exit 1
    }
    Copy-Item $backups[0].FullName $IniPath -Force
    Write-Host "Restored $($backups[0].Name)" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
#  Detect hardware
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '  Pixrock RV - playback tuning' -ForegroundColor Cyan
Write-Host '  ----------------------------' -ForegroundColor Cyan

$logicalCpus = [int]$env:NUMBER_OF_PROCESSORS
if ($logicalCpus -lt 1) { $logicalCpus = 4 }

$ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$ramGB    = [math]::Round($ramBytes / 1GB)

$gpuName = 'unknown'
try {
    $gpu = Get-CimInstance Win32_VideoController |
           Where-Object { $_.AdapterCompatibility -notmatch 'Microsoft' } |
           Select-Object -First 1
    if ($gpu) { $gpuName = $gpu.Name }
} catch { }

Write-Host ("  CPU threads : {0}" -f $logicalCpus)
Write-Host ("  RAM         : {0} GB" -f $ramGB)
Write-Host ("  GPU         : {0}" -f $gpuName)
Write-Host ''

# ---------------------------------------------------------------------------
#  Derive values
#
#  Cache sizes are in GB (Options.h: "-lram %f ... in Gb").
#
#  Look-ahead is capped at 45% of RAM. Oversizing this is actively harmful:
#  RV will happily fill the cache until Windows starts paging, and the
#  resulting stutter looks exactly like a slow decoder. A 100 GB look-ahead
#  on a 128 GB box leaves nothing for the OS, the file cache, or Nuke.
#
#  readerThreads is halved rather than maxed because OpenEXR already runs its
#  own global thread pool at (numCPUs - 1); running 24 reader threads on top
#  of that oversubscribes the box and costs more in contention than it gains.
# ---------------------------------------------------------------------------

if ($LookAheadGB   -le 0) { $LookAheadGB   = [math]::Max(4, [math]::Min(64, [int]($ramGB * 0.45))) }
if ($RegionGB      -le 0) { $RegionGB      = [math]::Max(2, [math]::Min(32, [int]($ramGB * 0.20))) }
if ($ReaderThreads -le 0) { $ReaderThreads = [math]::Max(2, [math]::Min(16, [int]($logicalCpus / 2))) }

$vsync = if ($KeepVSync) { 1 } else { 0 }

# ---------------------------------------------------------------------------
#  Apply
# ---------------------------------------------------------------------------

$ini     = Read-Ini $IniPath
$changes = @()

# Reader threads. RvSession only honours 1..32 (RvSession.cpp:354).
$changes += Set-Pref $ini '%General' 'readerThreads' $ReaderThreads

# cacheMode 2 = look-ahead cache (RvPreferences.cpp:876).
$changes += Set-Pref $ini 'Caching' 'cacheMode'               2
$changes += Set-Pref $ini 'Caching' 'lookAheadCacheSize64New' $LookAheadGB
$changes += Set-Pref $ini 'Caching' 'regionCacheSize64New'    $RegionGB
# The un-suffixed keys are the fallback RV reads when the 64-bit ones are
# absent; keep them in step so the two can never disagree.
$changes += Set-Pref $ini 'Caching' 'lookAheadCacheSizeNew'   $LookAheadGB
$changes += Set-Pref $ini 'Caching' 'regionCacheSizeNew'      $RegionGB
$changes += Set-Pref $ini 'Caching' 'bufferWait'              5
$changes += Set-Pref $ini 'Caching' 'lookBehindFraction'      25

# 16-bit half float halves texture upload bandwidth versus float32 and is the
# native EXR storage format anyway. Options.cpp only applies this when the
# value differs from 32.
$changes += Set-Pref $ini 'Rendering' 'maxBitDepth'        16
$changes += Set-Pref $ini 'Rendering' 'useThreadedUpload3' 'true'
$changes += Set-Pref $ini 'Rendering' 'prefetch2'          'true'

$changes += Set-Pref $ini 'Display' 'vsync' $vsync

# cpus=0 means "auto", which RV resolves to (numCPUs - 1) for the OpenEXR
# global thread pool at main.cpp:577. That is already correct; setting an
# explicit number here only risks getting it wrong.
$changes += Set-Pref $ini 'OpenEXR' 'cpus' 0

$changes | Format-Table -AutoSize

if ($DryRun) {
    Write-Host '  -DryRun set: nothing written.' -ForegroundColor Yellow
    exit 0
}

if (Test-Path $IniPath) {
    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "$IniPath.pixrock-backup_$stamp"
    Copy-Item $IniPath $backup -Force
    Write-Host ("  Backup      : {0}" -f (Split-Path $backup -Leaf)) -ForegroundColor DarkGray
}

Write-Ini $IniPath $ini

Write-Host ("  Written     : {0}" -f $IniPath) -ForegroundColor Green

# ---------------------------------------------------------------------------
#  Deploy any .rvpkg sitting next to this script.
#
#  Packages live under %APPDATA%\RV\Packages -- note this is the RV support
#  tree, which is a different location from the preferences file above. RV
#  still has to be told to load them from Preferences > Packages; dropping the
#  file here only makes it available.
# ---------------------------------------------------------------------------

$packageDir = Join-Path $env:APPDATA 'RV\Packages'
$packages   = Get-ChildItem -Path $PSScriptRoot -Filter '*.rvpkg' -ErrorAction SilentlyContinue

if ($packages) {
    if (-not (Test-Path $packageDir)) {
        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    }
    foreach ($pkg in $packages) {
        Copy-Item $pkg.FullName (Join-Path $packageDir $pkg.Name) -Force
        Write-Host ("  Package     : {0}" -f $pkg.Name) -ForegroundColor Green
    }
    Write-Host '                (enable under Preferences > Packages)' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  Restart RV for these to take effect.' -ForegroundColor Cyan
Write-Host '  Undo with:  .\Install-PixrockPrefs.ps1 -Revert' -ForegroundColor DarkGray
Write-Host ''
