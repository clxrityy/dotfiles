# os/windows/install.ps1
#
# Windows 11 installer. Normally invoked by the root ./install.sh (Git Bash) or bootstrap.ps1.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File os\windows\install.ps1 [-DryRun] [-Force] [-VerboseLog]
#                                                                  [-SkipDebloat] [-SkipSettings]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$VerboseLog,
    [switch]$SkipDebloat,
    [switch]$SkipSettings
)

$ErrorActionPreference = 'Stop'

$global:Dotfiles = @{
    DryRun  = [bool]$DryRun
    Force   = [bool]$Force
    Verbose = [bool]$VerboseLog
    Root    = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Win     = $PSScriptRoot
    Stamp   = (Get-Date -Format 'yyyyMMdd-HHmmss')
}

. (Join-Path $PSScriptRoot 'lib\common.ps1')

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Write-Err 'This installer is for Windows only.'
    exit 1
}

# Windows 11 starts at build 22000.
if ([Environment]::OSVersion.Version.Build -lt 22000) {
    Write-Err 'Windows 11 (build 22000+) is required.'
    exit 1
}

# Elevate once up front; registry policies, Appx removal and symlinks all need admin.
if (-not (Test-Admin)) {
    if ($DryRun) {
        Write-Warn 'Not elevated; dry-run continues, but a real run needs an administrator session.'
    } else {
        Write-Info 'Re-launching elevated...'
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        if ($Force)        { $argList += '-Force' }
        if ($VerboseLog)   { $argList += '-VerboseLog' }
        if ($SkipDebloat)  { $argList += '-SkipDebloat' }
        if ($SkipSettings) { $argList += '-SkipSettings' }
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait -PassThru
        exit $proc.ExitCode
    }
}

Write-Info "Dotfiles root: $($global:Dotfiles.Root)"
Write-Info "Flags: force=$Force verbose=$VerboseLog dry-run=$DryRun"

if (-not $DryRun -and -not $Force) {
    if (-not (Confirm-Action 'This will install packages, change system settings and remove apps. Continue?')) {
        Write-Warn 'Aborted.'
        exit 0
    }
}

. (Join-Path $PSScriptRoot 'modules\packages.ps1')
. (Join-Path $PSScriptRoot 'modules\settings.ps1')
. (Join-Path $PSScriptRoot 'modules\links.ps1')
. (Join-Path $PSScriptRoot 'modules\debloat.ps1')

# Order matters: Developer Mode before symlinks; debloat last since it is the riskiest.
if (-not $SkipSettings) { Invoke-SettingsModule }
Invoke-PackagesModule
Invoke-LinksModule
if (-not $SkipDebloat) { Invoke-DebloatModule }

Write-Ok 'Windows setup complete. Sign out/in (or reboot) to apply all changes.'
