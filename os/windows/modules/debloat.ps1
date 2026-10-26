# os/windows/modules/debloat.ps1 -- Removes a fixed list of Appx packages, OneDrive and Copilot/Cortana/Edge nags.
# Every removal is logged to %LOCALAPPDATA%\dotfiles\debloat-<stamp>.log for later reinstall.

# Exact package names only; no wildcards.
$script:DebloatAppx = @(
    'Clipchamp.Clipchamp',
    'Microsoft.549981C3F5F10',            # Cortana
    'Microsoft.BingNews',
    'Microsoft.BingSearch',
    'Microsoft.BingWeather',
    'Microsoft.Copilot',
    'Microsoft.GamingApp',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.OutlookForWindows',
    'Microsoft.People',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.Todos',
    'Microsoft.Windows.Ai.Copilot.Provider',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo',
    'MicrosoftTeams',
    'MSTeams',
    'king.com.CandyCrushSaga',
    'king.com.CandyCrushSodaSaga',
    'SpotifyAB.SpotifyMusic',
    '4DF9E0F8.Netflix',
    'AmazonVideo.PrimeVideo',
    'BytedancePte.Ltd.TikTok',
    'Facebook.Facebook'
)

function Invoke-DebloatModule {
    Write-Info 'Debloating (aggressive)...'

    if (-not (Confirm-Action 'Remove the listed apps, OneDrive and Copilot? Removals are logged but not automatically reversible.')) {
        Write-Warn 'Debloat skipped.'
        return
    }

    $logDir = Join-Path $env:LOCALAPPDATA 'dotfiles'
    $logFile = Join-Path $logDir "debloat-$($global:Dotfiles.Stamp).log"
    if (-not $global:Dotfiles.DryRun) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

    Remove-AppxList $logFile
    Remove-OneDrive $logFile
    Set-DebloatPolicies

    if (-not $global:Dotfiles.DryRun -and (Test-Path $logFile)) { Write-Info "Removal log: $logFile" }
}

function Write-DebloatLog {
    param([string]$LogFile, [string]$Line)
    if ($global:Dotfiles.DryRun) { return }
    Add-Content -Path $LogFile -Value "$(Get-Date -Format s) $Line"
}

function Remove-AppxList {
    param([string]$LogFile)

    foreach ($name in $script:DebloatAppx) {
        $installed = @(Get-AppxPackage -AllUsers -Name $name -ErrorAction SilentlyContinue)
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $name })
        if ($installed.Count -eq 0 -and $provisioned.Count -eq 0) { continue }

        foreach ($pkg in $installed) {
            Write-DebloatLog $LogFile "appx $($pkg.PackageFullName) location=$($pkg.InstallLocation)"
            Invoke-Step "remove appx $($pkg.PackageFullName)" {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            }
        }
        foreach ($prov in $provisioned) {
            Write-DebloatLog $LogFile "provisioned $($prov.PackageName)"
            Invoke-Step "remove provisioned $($prov.PackageName)" {
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            }
        }
    }
}

function Remove-OneDrive {
    param([string]$LogFile)

    # Known Folder Move redirects Desktop/Documents/Pictures into OneDrive; uninstalling would hide them.
    foreach ($folder in 'Desktop', 'MyDocuments', 'MyPictures') {
        if ([Environment]::GetFolderPath($folder) -like '*OneDrive*') {
            Write-Warn "OneDrive backs up $folder; skipping OneDrive removal. Move your folders back first."
            return
        }
    }

    $setup = Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'
    if (-not (Test-Path $setup)) { $setup = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe' }
    if (-not (Test-Path $setup)) { return }

    Write-DebloatLog $LogFile "onedrive $setup /uninstall"
    Invoke-Step 'uninstall OneDrive' {
        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait
    }
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
}

function Set-DebloatPolicies {
    # Cortana / web search.
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0

    # Copilot (legacy policy; the app itself is removed above).
    Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1

    # Edge nags. Note: Edge will show "managed by your organization" once these policies exist.
    $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-RegValue $edge 'HideFirstRunExperience' 1
    Set-RegValue $edge 'StartupBoostEnabled' 0
    Set-RegValue $edge 'BackgroundModeEnabled' 0
    Set-RegValue $edge 'EdgeShoppingAssistantEnabled' 0
    Set-RegValue $edge 'ShowRecommendationsEnabled' 0
    Set-RegValue $edge 'HubsSidebarEnabled' 0
    Set-RegValue $edge 'PersonalizationReportingEnabled' 0
    Set-RegValue $edge 'MetricsReportingEnabled' 0
    Set-RegValue $edge 'SpotlightExperiencesAndRecommendationsEnabled' 0
}
