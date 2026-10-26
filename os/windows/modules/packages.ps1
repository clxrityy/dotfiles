# os/windows/modules/packages.ps1 -- Chocolatey bootstrap and package install.

function Invoke-PackagesModule {
    Write-Info 'Installing packages...'

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Invoke-Step 'install Chocolatey' {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        Update-SessionPath
    }

    $listFile = Join-Path $global:Dotfiles.Win 'choco-packages.txt'
    $packages = Get-Content $listFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }

    foreach ($pkg in $packages) {
        Invoke-Step "choco install $pkg" {
            choco install $pkg -y --no-progress
            if ($LASTEXITCODE -notin 0, 1641, 3010) { throw "choco exited with $LASTEXITCODE" }
        }
    }

    Update-SessionPath
}
