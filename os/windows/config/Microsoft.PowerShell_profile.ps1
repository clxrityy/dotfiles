# Linked to Documents\PowerShell\Microsoft.PowerShell_profile.ps1 by os/windows/install.ps1.

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -PredictionSource History -EditMode Windows
}
