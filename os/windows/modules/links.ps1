# os/windows/modules/links.ps1 -- Terminal, shell profile, starship, git and VS Code configuration.

function Invoke-LinksModule {
    Write-Info 'Linking configuration...'

    $root = $global:Dotfiles.Root
    $cfg = Join-Path $global:Dotfiles.Win 'config'
    $docs = [Environment]::GetFolderPath('MyDocuments')

    # Windows Terminal (Store package path; the folder may not exist before first launch).
    $wtDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    New-Link (Join-Path $wtDir 'settings.json') (Join-Path $cfg 'windows-terminal.settings.json')

    # PowerShell 7 profile (starship init lives there).
    New-Link (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1') (Join-Path $cfg 'Microsoft.PowerShell_profile.ps1')

    # Git Bash login config (default terminal profile).
    New-Link (Join-Path $HOME '.bash_profile') (Join-Path $cfg '.bash_profile')

    # Shared starship config from the common package.
    New-Link (Join-Path $HOME '.config\starship.toml') (Join-Path $root 'common\.config\starship.toml')

    # VS Code user settings.
    New-Link (Join-Path $env:APPDATA 'Code\User\settings.json') (Join-Path $cfg 'vscode-settings.json')

    Set-GitConfig
}

function Set-GitConfig {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn 'git not found on PATH; skipping git config.'
        return
    }

    # Copied, not linked: the identity is machine-specific (see `make setup-git-access` in Git Bash).
    $gitconfig = Join-Path $HOME '.gitconfig'
    if (-not (Test-Path $gitconfig)) {
        Invoke-Step "copy example.gitconfig -> $gitconfig" {
            Copy-Item (Join-Path $global:Dotfiles.Root 'git\example.gitconfig') $gitconfig
        }
    }

    # Windows overrides: `cache` credential helper is unsupported; LF in repo, long paths on.
    $overrides = [ordered]@{
        'credential.helper' = 'manager'
        'core.editor'       = 'code --wait'
        'core.autocrlf'     = 'input'
        'core.longpaths'    = 'true'
    }
    foreach ($key in $overrides.Keys) {
        $value = $overrides[$key]
        Invoke-Step "git config --global $key $value" { git config --global $key $value }
    }
}
