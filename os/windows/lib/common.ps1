# os/windows/lib/common.ps1
# Shared helpers for the Windows installer. ASCII only (Windows PowerShell 5.1 reads BOM-less files as ANSI).

function Write-Info  { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Warn  { param([string]$Message) Write-Host "[WARN]  $Message" -ForegroundColor Yellow }
function Write-Err   { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Debug2 {
    param([string]$Message)
    if ($global:Dotfiles.Verbose) { Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Runs $Action, or only prints the description under -DryRun.
function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)
    if ($global:Dotfiles.DryRun) {
        Write-Host "[dry-run] $Description" -ForegroundColor Magenta
        return
    }
    Write-Debug2 $Description
    try { & $Action }
    catch { Write-Warn "$Description failed: $($_.Exception.Message)" }
}

function Confirm-Action {
    param([string]$Prompt)
    if ($global:Dotfiles.Force -or $global:Dotfiles.DryRun) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^(y|yes)$')
}

function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    Invoke-Step "reg $Path\$Name = $Value" {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
    }
}

# Symlink $Path -> $Target; backs up an existing real file, falls back to a copy if symlinks are denied.
function New-Link {
    param([string]$Path, [string]$Target)

    if (-not (Test-Path $Target)) {
        Write-Warn "Link source missing, skipping: $Target"
        return
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'SymbolicLink' -and ($item.Target -contains $Target)) {
        Write-Debug2 "Already linked: $Path"
        return
    }

    Invoke-Step "link $Path -> $Target" {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        if ($item) {
            if ($item.LinkType) {
                Remove-Item -LiteralPath $Path -Force
            } else {
                $backup = "$Path.bak-$($global:Dotfiles.Stamp)"
                Move-Item -LiteralPath $Path -Destination $backup -Force
                Write-Info "Backed up existing file: $backup"
            }
        }
        try {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
        } catch {
            Write-Warn "Symlink failed ($($_.Exception.Message)); copying instead: $Path"
            Copy-Item -LiteralPath $Target -Destination $Path -Force
        }
    }
}

# Pick up PATH changes made by installers without opening a new shell.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}
