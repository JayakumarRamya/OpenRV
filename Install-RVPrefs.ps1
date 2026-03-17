#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys the correct rv_prefs to %APPDATA%\RV\ based on the machine's GPU.

.DESCRIPTION
    - Auto-detects GPU (NVIDIA / AMD / Intel integrated)
    - Picks the correct rv_prefs file automatically
    - Creates %APPDATA%\RV\ if it does not exist
    - Backs up any existing rv_prefs before overwriting
    - Safe to re-run multiple times

.PARAMETER InstallDir
    Path to your extracted OpenRV _install folder.
    Defaults to the folder containing this script.

.PARAMETER Force
    Overwrite existing rv_prefs WITHOUT creating a backup.

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

$RVAppData = Join-Path $env:APPDATA "RV"
$DestPrefs = Join-Path $RVAppData   "rv_prefs"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  OpenRV — Deploy rv_prefs"                         -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# ── 1. Auto-detect GPU ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Detecting GPU..." -ForegroundColor Yellow

$gpu        = Get-WmiObject Win32_VideoController | Select-Object -First 1
$gpuName    = $gpu.Name
$prefsFile  = $null

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

# ── 2. Validate source ────────────────────────────────────────────────────────
if (-not (Test-Path $prefsFile)) {
    Write-Host ""
    Write-Host "[ERROR] Prefs file not found: $prefsFile" -ForegroundColor Red
    Write-Host "        Make sure -InstallDir points to your _install folder." -ForegroundColor Red
    exit 1
}
Write-Host "  Source: $prefsFile" -ForegroundColor Green

# ── 3. Create %APPDATA%\RV if needed ─────────────────────────────────────────
if (-not (Test-Path $RVAppData)) {
    New-Item -ItemType Directory -Path $RVAppData -Force | Out-Null
    Write-Host ""
    Write-Host "[OK] Created: $RVAppData" -ForegroundColor Green
}

# ── 4. Backup existing rv_prefs ───────────────────────────────────────────────
if ((Test-Path $DestPrefs) -and (-not $Force)) {
    $stamp      = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$DestPrefs.backup_$stamp"
    Copy-Item -Path $DestPrefs -Destination $backupPath
    Write-Host "[OK] Backup saved: $backupPath" -ForegroundColor Yellow
}

# ── 5. Copy correct rv_prefs ──────────────────────────────────────────────────
Copy-Item -Path $prefsFile -Destination $DestPrefs -Force
Write-Host "[OK] rv_prefs deployed to: $DestPrefs" -ForegroundColor Green

# ── 6. Verify ─────────────────────────────────────────────────────────────────
if (Test-Path $DestPrefs) {
    $lines = (Get-Content $DestPrefs).Count
    Write-Host "[OK] Verified — $lines lines written." -ForegroundColor Green
} else {
    Write-Host "[ERROR] File not found after copy." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Done. Launch OpenRV to apply the new settings."   -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
