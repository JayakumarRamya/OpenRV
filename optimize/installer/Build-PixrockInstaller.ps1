#Requires -Version 5.1
<#
.SYNOPSIS
    Download a CI build artifact, verify it, and compile the Pixrock installer.

.DESCRIPTION
    End-to-end packaging step. Given a GitHub Actions run id it will:

      1. Download the pixrock-rv-windows-Release artifact
      2. Verify the FFmpeg decoders were actually compiled in
      3. Verify the Pixrock icon is embedded in rv.exe
      4. Verify the UI name was renamed to "Pixrock RV"
      5. Compile the Inno Setup installer against it

    Every check is a hard failure. A build that looks fine but silently lost
    its branding or its ProRes decoder is worse than one that fails loudly,
    because it ships.

.PARAMETER RunId
    GitHub Actions run id. Defaults to the most recent successful run of
    the Pixrock RV Windows workflow.

.PARAMETER WorkDir
    Where the artifact is unpacked. Defaults to D: -- C: on the build
    workstation does not have room for a 1 GB payload plus a 275 MB output.

.EXAMPLE
    .\Build-PixrockInstaller.ps1
    .\Build-PixrockInstaller.ps1 -RunId 33244197517
#>
[CmdletBinding()]
param(
    [string] $RunId    = '',
    [string] $WorkDir  = 'D:\Pixrock_Build',
    [string] $OutputDir = 'D:\Pixrock_Installer_Output',
    [string] $Repo     = 'JayakumarRamya/OpenRV',
    [switch] $SkipDownload,
    # Point at an already-unpacked payload instead of downloading one.
    # Useful for re-packaging or for testing the verification steps.
    [string] $PayloadDir = '',
    # UI name the binaries must contain. Override only when packaging a build
    # that predates the current naming - never to make a bad build pass.
    [string] $ExpectedName = 'Pixrock RV'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gh   = 'D:\OpenRV\_tools\gh\bin\gh.exe'
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
$here = $PSScriptRoot

function Fail($msg) {
    Write-Host ''
    Write-Host "  FAILED: $msg" -ForegroundColor Red
    exit 1
}

function Step($n, $msg) {
    Write-Host ''
    Write-Host ("  [{0}] {1}" -f $n, $msg) -ForegroundColor Cyan
}

foreach ($tool in @($gh, $iscc)) {
    if (-not (Test-Path $tool)) { Fail "not found: $tool" }
}

$payload = if ($PayloadDir) { $PayloadDir } else { Join-Path $WorkDir '_install' }
if ($PayloadDir) { $SkipDownload = $true }

# ── 1. Download ────────────────────────────────────────────────────────────
if (-not $SkipDownload) {
    Step 1 'Downloading artifact'

    if (-not $RunId) {
        $RunId = (& $gh run list --repo $Repo --workflow ci-windows.yml `
                    --status success --limit 1 --json databaseId `
                    --jq '.[0].databaseId')
        if (-not $RunId) { Fail 'no successful run found' }
        Write-Host "      using most recent successful run: $RunId"
    }

    if (Test-Path $WorkDir) { Remove-Item $WorkDir -Recurse -Force }
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

    & $gh run download $RunId --repo $Repo --dir $WorkDir
    if ($LASTEXITCODE -ne 0) { Fail "artifact download failed for run $RunId" }

    # gh unpacks each artifact into a folder named after it.
    $inner = Get-ChildItem $WorkDir -Directory | Select-Object -First 1
    if ($inner -and -not (Test-Path $payload)) { $payload = $inner.FullName }
}

if (-not (Test-Path (Join-Path $payload 'bin\rv.exe'))) {
    Fail "rv.exe not found under $payload"
}
Write-Host "      payload: $payload"

# ── 2. Decoders ────────────────────────────────────────────────────────────
Step 2 'Verifying FFmpeg decoders'

$probe = Join-Path $payload 'optimize\probe_decoders.py'
if (-not (Test-Path $probe)) { $probe = Join-Path $here '..\probe_decoders.py' }

$py = Join-Path $payload 'bin\python.exe'
if (-not (Test-Path $py)) { $py = 'python' }

& $py $probe (Join-Path $payload 'bin')
if ($LASTEXITCODE -ne 0) { Fail 'required decoders are missing from this build' }

# ── 3. Icon ────────────────────────────────────────────────────────────────
Step 3 'Verifying Pixrock icon is embedded in rv.exe'

# The Pixrock .ico stores its 256x256 entry as PNG. If the resource compiler
# embedded our icon, those exact PNG bytes appear inside rv.exe. Comparing a
# slice avoids parsing PE resource directories by hand.
$icoPath = Join-Path $here 'pixrock.ico'
if (-not (Test-Path $icoPath)) { Fail "reference icon missing: $icoPath" }

$ico   = [IO.File]::ReadAllBytes($icoPath)
$count = [BitConverter]::ToUInt16($ico, 4)
$needle = $null
for ($i = 0; $i -lt $count; $i++) {
    $o    = 6 + ($i * 16)
    $off  = [BitConverter]::ToUInt32($ico, $o + 12)
    # PNG signature marks the 256x256 entry.
    if ($ico[$off] -eq 0x89 -and $ico[$off + 1] -eq 0x50) {
        $needle = $ico[$off..($off + 63)]
        break
    }
}

if (-not $needle) {
    Write-Host '      no PNG-compressed entry in reference icon, skipping byte check' -ForegroundColor Yellow
} else {
    $exe   = [IO.File]::ReadAllBytes((Join-Path $payload 'bin\rv.exe'))
    $found = $false
    $limit = $exe.Length - $needle.Length
    for ($i = 0; $i -lt $limit; $i++) {
        if ($exe[$i] -ne $needle[0]) { continue }
        $match = $true
        for ($j = 1; $j -lt $needle.Length; $j++) {
            if ($exe[$i + $j] -ne $needle[$j]) { $match = $false; break }
        }
        if ($match) { $found = $true; break }
    }
    if ($found) {
        Write-Host '      Pixrock icon found in rv.exe' -ForegroundColor Green
    } else {
        Fail 'rv.exe does not contain the Pixrock icon - RV.ico was not picked up'
    }
}

# ── 4. UI name ─────────────────────────────────────────────────────────────
Step 4 "Verifying UI name: $ExpectedName"

# UI_APPLICATION_NAME is compiled in as a narrow string literal, so it lives
# in RvCommon rather than rv.exe itself.
$targets = @(
    (Join-Path $payload 'bin\rv.exe'),
    (Join-Path $payload 'lib\RvCommon.dll'),
    (Join-Path $payload 'bin\RvCommon.dll')
) | Where-Object { Test-Path $_ }

$nameFound = $false
foreach ($t in $targets) {
    $txt = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($t))
    if ($txt.Contains($ExpectedName)) {
        Write-Host ("      found in {0}" -f (Split-Path $t -Leaf)) -ForegroundColor Green
        $nameFound = $true
        break
    }
}
if (-not $nameFound) {
    Fail "string '$ExpectedName' not found - RV_UI_APPLICATION_NAME did not take effect"
}

# ── 5. Compile installer ───────────────────────────────────────────────────
Step 5 'Compiling installer'

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

& $iscc "/DMyAppSourceDir=$payload" "/DMyOutputDir=$OutputDir" (Join-Path $here 'Pixrock_Installer.iss')
if ($LASTEXITCODE -ne 0) { Fail 'Inno Setup compile failed' }

Write-Host ''
Write-Host '  All checks passed.' -ForegroundColor Green
Get-ChildItem $OutputDir -Filter '*.exe' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }, LastWriteTime |
    Format-Table -AutoSize
