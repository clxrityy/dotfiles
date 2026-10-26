# bootstrap.ps1 -- Fresh Windows 11 entry point: installs Git, clones the repo, then runs ./install.sh via Git Bash.
#
# Usage (elevated PowerShell, after downloading this file):
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 [-DryRun] [-Force]
param(
    [string]$Repo = 'https://github.com/clxrityy/dotfiles.git',
    [string]$Dest = (Join-Path $HOME '.dotfiles'),
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an elevated PowerShell (Run as administrator).' }

function Update-SessionPath {
    $env:Path = "$([Environment]::GetEnvironmentVariable('Path', 'Machine'));$([Environment]::GetEnvironmentVariable('Path', 'User'))"
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Update-SessionPath
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    choco install git -y --no-progress
    Update-SessionPath
}

if (-not (Test-Path (Join-Path $Dest '.git'))) {
    # autocrlf=false keeps the shell scripts LF so Git Bash can run them.
    git clone -c core.autocrlf=false $Repo $Dest
}

$bash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
if (-not (Test-Path $bash)) { throw "Git Bash not found at $bash" }

$flags = @()
if ($DryRun) { $flags += '--dry-run' }
if ($Force)  { $flags += '--force' }

# Hand off to the root installer, which detects Windows and runs os/windows/install.ps1.
& $bash -lc "cd '$($Dest -replace '\\', '/')' && ./install.sh $($flags -join ' ')"
exit $LASTEXITCODE
