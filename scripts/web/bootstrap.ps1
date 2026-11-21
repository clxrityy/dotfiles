# scripts/web/bootstrap.ps1 -- Clone-free Windows bootstrap
#
# Published to GitHub Pages as `install.ps1`. Downloads only the Windows bundle,
# verifies its checksum, extracts it to ~\.dotfiles, then runs os\windows\install.ps1.
# No git or Git Bash required.
#
# Usage (elevated PowerShell):
#   irm https://clxrityy.github.io/dotfiles/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://clxrityy.github.io/dotfiles/install.ps1))) -DryRun
param(
    [string]$Dest = (Join-Path $HOME '.dotfiles'),
    [string]$BaseUrl = $(if ($env:DOTFILES_BASE_URL) { $env:DOTFILES_BASE_URL } else { 'https://clxrityy.github.io/dotfiles' }),
    [switch]$NoInstall,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$VerboseLog,
    [switch]$SkipDebloat,
    [switch]$SkipSettings
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Invoke-WebRequest is very slow with the progress bar.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
$BaseUrl = $BaseUrl.TrimEnd('/')

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an elevated PowerShell (Run as administrator).' }

if (Test-Path (Join-Path $Dest '.git')) {
    throw "$Dest is a git checkout. Update it with git pull and run .\install.sh instead."
}
if ((Test-Path $Dest) -and -not (Test-Path (Join-Path $Dest '.bundle-version'))) {
    $other = Get-ChildItem -Force $Dest | Where-Object { $_.Name -ne 'private' }
    if ($other) { throw "$Dest already exists and is not a dotfiles bundle. Move it aside or pass -Dest <path>." }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("dotfiles-bootstrap-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'windows.zip'
    Write-Host "==> Downloading windows bundle from $BaseUrl"
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/windows.zip" -OutFile $zip

    $sums = (Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/SHA256SUMS").Content
    if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
    $expected = ($sums -split "`n" | Where-Object { $_ -match '\s\*?windows\.zip\s*$' } | Select-Object -First 1) -replace '\s.*$', ''
    if (-not $expected) { throw 'No checksum listed for windows.zip' }
    $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($actual -ne $expected.Trim().ToLower()) { throw "Checksum mismatch for windows.zip (expected $expected, got $actual)" }
    Write-Host '==> Checksum verified'

    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $staged = Join-Path $tmp 'dotfiles'
    if (-not (Test-Path (Join-Path $staged 'os\windows\install.ps1'))) { throw 'Bundle is malformed (no os\windows\install.ps1)' }

    # Keep anything private the user placed in the install dir.
    $private = Join-Path $Dest 'private'
    if (Test-Path $private) { Move-Item $private (Join-Path $staged 'private') }

    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
    Move-Item $staged $Dest
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Write-Host "==> Installed $((Get-Content (Join-Path $Dest '.bundle-version') -TotalCount 1)) to $Dest"

if ($NoInstall) {
    Write-Host "==> Skipping install. Run later: powershell -ExecutionPolicy Bypass -File `"$Dest\os\windows\install.ps1`""
    return
}

$installArgs = @{}
if ($DryRun)       { $installArgs.DryRun = $true }
if ($Force)        { $installArgs.Force = $true }
if ($VerboseLog)   { $installArgs.VerboseLog = $true }
if ($SkipDebloat)  { $installArgs.SkipDebloat = $true }
if ($SkipSettings) { $installArgs.SkipSettings = $true }

# Windows PowerShell 5.1 ships the Appx/DISM modules debloat needs (same choice as root install.sh).
$flags = $installArgs.Keys | ForEach-Object { "-$_" }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'os\windows\install.ps1') @flags
if ($LASTEXITCODE) { exit $LASTEXITCODE }
