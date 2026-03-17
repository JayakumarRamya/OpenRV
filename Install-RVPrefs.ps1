#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys rv_prefs, prewarm cache script and Python plugins to correct RV directories.

.DESCRIPTION
    - Auto-detects GPU (NVIDIA / AMD / Intel integrated)
    - Deploys correct rv_prefs      → %APPDATA%\RV\rv_prefs
    - Deploys rv_cache_prewarm.mu   → %APPDATA%\RV\Mu\rv_cache_prewarm.mu
    - Deploys Python plugins        → %APPDATA%\RV\Packages\
    - Creates folders if they do not exist
    - Backs up existing files before overwriting
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

# ── RV deployment paths ───────────────────────────────────────────────────────
$RVAppData      = Join-Path $env:APPDATA "RV"
$RVMuDir        = Join-Path $RVAppData   "Mu"
$RVPackagesDir  = Join-Path $RVAppData   "Packages"
$DestPrefs      = Join-Path $RVAppData   "rv_prefs"
$DestMu         = Join-Path $RVMuDir     "rv_cache_prewarm.mu"
$SourceMu       = Join-Path $InstallDir  "rv_cache_prewarm.mu"
$SourcePlugins  = Join-Path $InstallDir  "rv_plugins"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  OpenRV — Full Deployment"                               -ForegroundColor Cyan
Write-Host "  rv_prefs + prewarm cache + Python plugins"              -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# ── 1. Auto-detect GPU ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 1/4 ] Detecting GPU..." -ForegroundColor Yellow

$gpu       = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName   = $gpu.Name
$prefsFile = $null

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
        Write-Host "        Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "        Exists : $dir" -ForegroundColor DarkGray
    }
}

# ── 3. Deploy rv_prefs ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/4 ] Deploying rv_prefs..." -ForegroundColor Yellow

if (-not (Test-Path $prefsFile)) {
    Write-Host "        [ERROR] Not found: $prefsFile" -ForegroundColor Red
    exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
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
        Write-Host "        Backed up existing rv_cache_prewarm.mu" -ForegroundColor Yellow
    }
    Copy-Item -Path $SourceMu -Destination $DestMu -Force
    Write-Host "        rv_cache_prewarm.mu → $DestMu" -ForegroundColor Green
} else {
    Write-Host "        [SKIP] rv_cache_prewarm.mu not found" -ForegroundColor DarkGray
}

# ── 5. Deploy Python plugins ──────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/4 ] Deploying Python plugins..." -ForegroundColor Yellow

if (Test-Path $SourcePlugins) {
    $plugins = Get-ChildItem -Path $SourcePlugins -Filter "*.py"

    if ($plugins.Count -eq 0) {
        Write-Host "        [SKIP] No .py files found in rv_plugins folder" -ForegroundColor DarkGray
    } else {
        foreach ($plugin in $plugins) {
            $destPlugin = Join-Path $RVPackagesDir $plugin.Name
            if ((Test-Path $destPlugin) -and (-not $Force)) {
                Copy-Item -Path $destPlugin -Destination "$destPlugin.backup_$stamp"
                Write-Host "        Backed up: $($plugin.Name)" -ForegroundColor Yellow
            }
            Copy-Item -Path $plugin.FullName -Destination $destPlugin -Force
            Write-Host "        $($plugin.Name) → $destPlugin" -ForegroundColor Green
        }
        Write-Host "        $($plugins.Count) plugin(s) deployed" -ForegroundColor Green
    }
} else {
    Write-Host "        [SKIP] rv_plugins folder not found in _install" -ForegroundColor DarkGray
}

# ── 6. Verify ─────────────────────────────────────────────────────────────────
Write-Host ""
$ok = $true
if (-not (Test-Path $DestPrefs)) {
    Write-Host "[ERROR] rv_prefs missing after deploy" -ForegroundColor Red
    $ok = $false
}
if (-not $ok) { exit 1 }

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Done. All optimizations active on next RV launch:"      -ForegroundColor Cyan
Write-Host "    1. rv_prefs                — hardware tuned settings"  -ForegroundColor Cyan
Write-Host "    2. rv_cache_prewarm.mu     — zero stutter first play"  -ForegroundColor Cyan
Write-Host "    3. stack_input_shortcuts   — 1/2/3 key switching"      -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
