#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys rv_prefs and rv_cache_prewarm.mu to the correct RV directories.

.DESCRIPTION
    - Auto-detects GPU (NVIDIA / AMD / Intel integrated)
    - Deploys the correct rv_prefs to %APPDATA%\RV\
    - Deploys rv_cache_prewarm.mu to %APPDATA%\RV\Mu\
    - Creates folders if they do not exist
    - Backs up any existing files before overwriting
    - Safe to re-run multiple times

.PARAMETER InstallDir
    Path to your extracted OpenRV _install folder.
    Defaults to the folder containing this script.

.PARAMETER Force
    Overwrite existing files WITHOUT creating backups.

.EXAMPLE
    .\Install-RVPrefs.ps1
    .\Install-RVPrefs.ps1 -InstallDir "C:\tools\openrv\_install"
    .\Install-RVPrefs.ps1 -Force
#>

param(
    [string] $InstallDir = $PSScriptRoot,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RVAppData  = Join-Path $env:APPDATA "RV"
$RVMuDir    = Join-Path $RVAppData   "Mu"
$DestPrefs  = Join-Path $RVAppData   "rv_prefs"
$DestMu     = Join-Path $RVMuDir     "rv_cache_prewarm.mu"
$SourceMu   = Join-Path $InstallDir  "rv_cache_prewarm.mu"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  OpenRV — Deploy rv_prefs + prewarm cache"         -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# ── 1. Auto-detect GPU ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Detecting GPU..." -ForegroundColor Yellow

$gpu       = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName   = $gpu.Name
$prefsFile = $null

Write-Host "  Found: $gpuName"

if ($gpuName -match "NVIDIA|GeForce|RTX|GTX|Quadro") {
    $prefsFile = Join-Path $InstallDir "rv_prefs_NVIDIA_RTX3060"
    Write-Host "  → Using NVIDIA profile (CUDA decode)" -ForegroundColor Green
}
elseif ($gpuName -match "AMD|Radeon|RX ") {
    $prefsFile = Join-Path $InstallDir "rv_prefs_AMD_RX5700"
    Write-Host "  → Using AMD profile (D3D11 decode)" -ForegroundColor Green
}
else {
    $prefsFile = Join-Path $InstallDir "rv_prefs_IntelUHD770_noGPU"
    Write-Host "  → Using Intel integrated profile (D3D11 decode)" -ForegroundColor Green
}

# ── 2. Validate sources ───────────────────────────────────────────────────────
if (-not (Test-Path $prefsFile)) {
    Write-Host "[ERROR] Prefs file not found: $prefsFile" -ForegroundColor Red
    Write-Host "        Make sure -InstallDir points to your _install folder." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $SourceMu)) {
    Write-Host "[ERROR] Prewarm script not found: $SourceMu" -ForegroundColor Red
    exit 1
}

# ── 3. Create %APPDATA%\RV and %APPDATA%\RV\Mu if needed ─────────────────────
if (-not (Test-Path $RVAppData)) {
    New-Item -ItemType Directory -Path $RVAppData -Force | Out-Null
    Write-Host "[OK] Created: $RVAppData" -ForegroundColor Green
}
if (-not (Test-Path $RVMuDir)) {
    New-Item -ItemType Directory -Path $RVMuDir -Force | Out-Null
    Write-Host "[OK] Created: $RVMuDir" -ForegroundColor Green
}

# ── 4. Backup existing files ──────────────────────────────────────────────────
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ((Test-Path $DestPrefs) -and (-not $Force)) {
    $backup = "$DestPrefs.backup_$stamp"
    Copy-Item -Path $DestPrefs -Destination $backup
    Write-Host "[OK] rv_prefs backed up: $backup" -ForegroundColor Yellow
}
if ((Test-Path $DestMu) -and (-not $Force)) {
    $backup = "$DestMu.backup_$stamp"
    Copy-Item -Path $DestMu -Destination $backup
    Write-Host "[OK] rv_cache_prewarm.mu backed up: $backup" -ForegroundColor Yellow
}

# ── 5. Deploy rv_prefs ────────────────────────────────────────────────────────
Copy-Item -Path $prefsFile -Destination $DestPrefs -Force
Write-Host "[OK] rv_prefs deployed → $DestPrefs" -ForegroundColor Green

# ── 6. Deploy prewarm .mu script ─────────────────────────────────────────────
Copy-Item -Path $SourceMu -Destination $DestMu -Force
Write-Host "[OK] rv_cache_prewarm.mu deployed → $DestMu" -ForegroundColor Green

# ── 7. Verify both ────────────────────────────────────────────────────────────
$ok = $true
if (-not (Test-Path $DestPrefs)) {
    Write-Host "[ERROR] rv_prefs missing after deploy." -ForegroundColor Red
    $ok = $false
}
if (-not (Test-Path $DestMu)) {
    Write-Host "[ERROR] rv_cache_prewarm.mu missing after deploy." -ForegroundColor Red
    $ok = $false
}
if (-not $ok) { exit 1 }

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Done. Both optimizations active on next launch."  -ForegroundColor Cyan
Write-Host "    1. rv_prefs      — hardware-tuned settings"     -ForegroundColor Cyan
Write-Host "    2. prewarm cache — zero stutter on first play"  -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
