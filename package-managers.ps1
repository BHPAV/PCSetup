#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs package managers for Windows 11 development environment.
.DESCRIPTION
    Installs and configures WinGet, Chocolatey, and Scoop package managers
    to enable simplified installation of development tools.
.EXAMPLE
    .\package-managers.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

param (
    [string]$LogFile = "$env:USERPROFILE\DevSetup\Logs\package-managers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Import utility functions
$utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath -LogFile $LogFile
} else {
    Write-Error "Required utils.ps1 script not found. Please ensure it exists in the same directory."
    exit 1
}

Write-Log "Starting Package Managers Installation" "INFO"

# Create a restore point
Create-RestorePoint -Description "Before Package Managers Installation"

function Install-WinGet {
    Invoke-Task -Name "Installing WinGet" -ScriptBlock {
        if (-not (Test-CommandExists "winget")) {
            Write-Log "WinGet not found, installing App Installer from Microsoft Store" "WARN"
            
            # Option 1: Microsoft Store direct installation (requires GUI interaction)
            Write-Log "Attempting direct Microsoft Store installation" "INFO"
            Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
            $userInstall = Read-Host "Press Enter once you've installed the App Installer from the Microsoft Store, or type 'alt' to try alternative installation"
            
            # Option 2: Alternative installation using direct download
            if ($userInstall -eq "alt" -or -not (Test-CommandExists "winget")) {
                Write-Log "Attempting alternative WinGet installation" "INFO"
                
                $latestWingetMsixBundleUri = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                $latestWingetMsixBundle = "$TempDir\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                
                Download-File -Url $latestWingetMsixBundleUri -OutputPath $latestWingetMsixBundle
                Add-AppxPackage -Path $latestWingetMsixBundle
            }
        }
        
        # Verify installation
        if (Test-CommandExists "winget") {
            $wingetVersion = & winget --version
            Write-Log "WinGet installed: $wingetVersion" "SUCCESS"
            winget source update
        } else {
            throw "WinGet installation failed"
        }
    }
}

function Install-Chocolatey {
    Invoke-Task -Name "Installing Chocolatey" -ScriptBlock {
        if (-not (Test-CommandExists "choco")) {
            Write-Log "Chocolatey not found, installing..." "INFO"
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        
        # Configure chocolatey
        if (Test-CommandExists "choco") {
            $chocoVersion = & choco --version
            Write-Log "Chocolatey installed: $chocoVersion" "SUCCESS"
            choco feature enable -n allowGlobalConfirmation
            choco install chocolatey-core.extension
        } else {
            throw "Chocolatey installation failed"
        }
    }
}

function Install-Scoop {
    Invoke-Task -Name "Installing Scoop" -ScriptBlock {
        if (-not (Test-CommandExists "scoop")) {
            Write-Log "Scoop not found, installing..." "INFO"
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            $installScoop = "irm get.scoop.sh | iex"
            Invoke-Expression $installScoop
        }
        
        # Configure Scoop
        if (Test-CommandExists "scoop") {
            Write-Log "Scoop installed successfully" "SUCCESS"
            scoop update
            
            # Add buckets
            $buckets = @("extras", "versions", "nerd-fonts", "java")
            foreach ($bucket in $buckets) {
                scoop bucket add $bucket
            }
            
            Write-Log "Scoop buckets added: $($buckets -join ', ')" "SUCCESS"
        } else {
            throw "Scoop installation failed"
        }
    }
}

# Install all package managers
Install-WinGet
Install-Chocolatey
Install-Scoop

# Summary
Write-Log "Package managers installation completed" "SUCCESS"
Write-Log "Successfully installed: WinGet, Chocolatey, and Scoop" "INFO"
