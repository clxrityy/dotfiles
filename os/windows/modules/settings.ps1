# os/windows/modules/settings.ps1 -- Explorer, taskbar, privacy, appearance and developer settings.

function Invoke-SettingsModule {
    Write-Info 'Applying Windows settings...'

    $hkcu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'
    $adv = "$hkcu\Explorer\Advanced"

    # Explorer: hidden/system files, extensions, full path in title bar.
    Set-RegValue $adv 'Hidden' 1
    Set-RegValue $adv 'ShowSuperHidden' 1
    Set-RegValue $adv 'HideFileExt' 0
    Set-RegValue "$hkcu\Explorer\CabinetState" 'FullPath' 1

    # Taskbar: drop search, task view, widgets, chat and the Copilot button.
    Set-RegValue "$hkcu\Search" 'SearchboxTaskbarMode' 0
    Set-RegValue $adv 'ShowTaskViewButton' 0
    Set-RegValue $adv 'TaskbarDa' 0
    Set-RegValue $adv 'TaskbarMn' 0
    Set-RegValue $adv 'ShowCopilotButton' 0
    # TaskbarDa is write-protected on recent builds; the policy is the reliable switch.
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0

    # Dark mode.
    Set-RegValue "$hkcu\Themes\Personalize" 'AppsUseLightTheme' 0
    Set-RegValue "$hkcu\Themes\Personalize" 'SystemUsesLightTheme' 0

    # Classic (Win10) right-click menu: empty default value on this CLSID.
    $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    Set-RegValue $clsid '(default)' '' 'String'

    # Telemetry, ads and suggestions.
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Set-RegValue "$hkcu\AdvertisingInfo" 'Enabled' 0
    Set-RegValue "$hkcu\Privacy" 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-RegValue $adv 'Start_IrisRecommendations' 0
    Set-RegValue $adv 'ShowSyncProviderNotifications' 0

    $cdm = "$hkcu\ContentDeliveryManager"
    foreach ($name in 'ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
                      'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled',
                      'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled', 'SystemPaneSuggestionsEnabled',
                      'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled',
                      'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled',
                      'SubscribedContent-353696Enabled') {
        Set-RegValue $cdm $name 0
    }

    Invoke-Step 'disable DiagTrack (telemetry) service' {
        Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Disabled
    }

    # Disable Bing / web results in Start search.
    Set-RegValue "$hkcu\Search" 'BingSearchEnabled' 0
    Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1

    # Long paths and Developer Mode (non-admin symlinks, sideloading).
    Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" 'AllowDevelopmentWithoutDevLicense' 1

    # Explorer owns most of these keys; restarting it applies them without a reboot.
    Invoke-Step 'restart Explorer' {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
}
