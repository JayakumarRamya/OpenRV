#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys rv_prefs, prewarm cache script and .rvpkg plugin to correct RV directories.

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

# ── RV deployment paths ───────────────────────────────────────────────────────
$RVAppData     = Join-Path $env:APPDATA "RV"
$RVMuDir       = Join-Path $RVAppData   "Mu"
$RVPackagesDir = Join-Path $RVAppData   "Packages"
$DestPrefs     = Join-Path $RVAppData   "rv_prefs"
$DestMu        = Join-Path $RVMuDir     "rv_cache_prewarm.mu"
$SourceMu      = Join-Path $InstallDir  "rv_cache_prewarm.mu"
$SourceRvpkg   = Join-Path $InstallDir  "stack_shortcuts-1.0.rvpkg"
$DestRvpkg     = Join-Path $RVPackagesDir "stack_shortcuts-1.0.rvpkg"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  OpenRV — Full Deployment"                               -ForegroundColor Cyan
Write-Host "  rv_prefs + prewarm cache + stack_input_shortcuts"       -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# ── 1. Auto-detect GPU ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 1/4 ] Detecting GPU..." -ForegroundColor Yellow
$gpu     = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName = $gpu.Name
Write-Host "        Found: $gpuName"

if ($gpuName -match "NVIDIA|GeForce|RTX|GTX|Quadro") {
    $prefsFile = Join-Path $InstallDir "rv_prefs_NVIDIA_RTX3060"
    Write-Host "        → NVIDIA profile (CUDA decode)" -ForegroundColor Green
}
elseif ($gpuName -match "AMD|Radeon|RX ") {
    $prefsFile = Join-Path $InstallDir "rv_prefs_AMD_RX5700"
    Write-Host "        → AMD profile (D3D11 decode)" -ForegroundColor Green
}
else {
    $prefsFile = Join-Path $InstallDir "rv_prefs_IntelUHD770_noGPU"
    Write-Host "        → Intel integrated profile (D3D11 decode)" -ForegroundColor Green
}

# ── 2. Create RV directories ──────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 2/4 ] Creating RV directories..." -ForegroundColor Yellow
foreach ($dir in @($RVAppData, $RVMuDir, $RVPackagesDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "        Created : $dir" -ForegroundColor Green
    } else {
        Write-Host "        Exists  : $dir" -ForegroundColor DarkGray
    }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

# ── 3. Deploy rv_prefs ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/4 ] Deploying rv_prefs..." -ForegroundColor Yellow
if (-not (Test-Path $prefsFile)) {
    Write-Host "        [ERROR] Not found: $prefsFile" -ForegroundColor Red
    exit 1
}
if ((Test-Path $DestPrefs) -and (-not $Force)) {
    Copy-Item -Path $DestPrefs -Destination "$DestPrefs.backup_$stamp"
    Write-Host "        Backed up existing rv_prefs" -ForegroundColor Yellow
}
Copy-Item -Path $prefsFile -Destination $DestPrefs -Force
Write-Host "        rv_prefs → $DestPrefs" -ForegroundColor Green

# ── 4. Deploy prewarm .mu script ─────────────────────────────────────────────
if (Test-Path $SourceMu) {
    if ((Test-Path $DestMu) -and (-not $Force)) {
        Copy-Item -Path $DestMu -Destination "$DestMu.backup_$stamp"
    }
    Copy-Item -Path $SourceMu -Destination $DestMu -Force
    Write-Host "        rv_cache_prewarm.mu → $DestMu" -ForegroundColor Green
} else {
    Write-Host "        [SKIP] rv_cache_prewarm.mu not found" -ForegroundColor DarkGray
}

# ── 5. Deploy .rvpkg plugin ───────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/4 ] Deploying stack_shortcuts-1.0.rvpkg..." -ForegroundColor Yellow
if (Test-Path $SourceRvpkg) {
    if ((Test-Path $DestRvpkg) -and (-not $Force)) {
        Copy-Item -Path $DestRvpkg -Destination "$DestRvpkg.backup_$stamp"
        Write-Host "        Backed up existing .rvpkg" -ForegroundColor Yellow
    }
    Copy-Item -Path $SourceRvpkg -Destination $DestRvpkg -Force
    $size = (Get-Item $DestRvpkg).Length
    Write-Host "        stack_shortcuts-1.0.rvpkg → $DestRvpkg ($size bytes)" -ForegroundColor Green
    Write-Host "        Open RV → Preferences → Packages to confirm" -ForegroundColor Green
} else {
    Write-Host "        [SKIP] stack_shortcuts-1.0.rvpkg not found in _install" -ForegroundColor DarkGray
}

# ── 6. Verify ─────────────────────────────────────────────────────────────────
Write-Host ""
if (-not (Test-Path $DestPrefs)) {
    Write-Host "[ERROR] rv_prefs missing after deploy" -ForegroundColor Red
    exit 1
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Done. All optimizations active on next RV launch:"      -ForegroundColor Cyan
Write-Host "    1. rv_prefs                  — hardware tuned"         -ForegroundColor Cyan
Write-Host "    2. rv_cache_prewarm.mu       — zero stutter"           -ForegroundColor Cyan
Write-Host "    3. stack_shortcuts-1.0.rvpkg — keys 1/2/3 switching"  -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
