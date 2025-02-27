#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Controller script for Windows 11 development environment setup.
.DESCRIPTION
    This main script orchestrates the setup process by downloading and running
    individual component scripts based on user choices.
.EXAMPLE
    .\win11-dev-setup.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Makes downloads faster
$VerbosePreference = "Continue"

# Base URL for script downloads (replace with your actual repository URL)
$ScriptBaseUrl = "https://raw.githubusercontent.com/yourusername/win11-dev-setup/main"

# Setup directories
$ScriptsDir = "$env:USERPROFILE\DevSetup\Scripts"
$LogDir = "$env:USERPROFILE\DevSetup\Logs"
$LogFile = "$LogDir\setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Create directories
New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# Initialize log file
$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"[$Timestamp] [INFO] Windows 11 Development Environment Setup started" | Out-File -FilePath $LogFile

# Available script modules
$ScriptModules = @(
    @{
        Name = "Core Utilities";
        Filename = "utils.ps1";
        Description = "Core utility functions used by all scripts";
        Required = $true;
    },
    @{
        Name = "Package Managers";
        Filename = "package-managers.ps1";
        Description = "Installs WinGet, Chocolatey, and Scoop";
        Required = $true;
    },
    @{
        Name = "Development Tools";
        Filename = "dev-tools.ps1";
        Description = "Installs Git, VS Code, Visual Studio, PowerShell 7, Windows Terminal";
        Required = $false;
    },
    @{
        Name = "Programming Environments";
        Filename = "programming-env.ps1";
        Description = "Sets up WSL, Python, Node.js, .NET, Java";
        Required = $false;
    },
    @{
        Name = "Container Tools";
        Filename = "container-tools.ps1";
        Description = "Installs Docker, Kubernetes tools";
        Required = $false;
    },
    @{
        Name = "GPU Development";
        Filename = "gpu-setup.ps1";
        Description = "Sets up NVIDIA tools and ML frameworks";
        Required = $false;
    },
    @{
        Name = "Additional Utilities";
        Filename = "additional-utils.ps1";
        Description = "Installs networking tools, security tools, fonts";
        Required = $false;
    },
    @{
        Name = "Environment Validation";
        Filename = "validation.ps1";
        Description = "Tests the environment and generates a report";
        Required = $false;
    }
)

function Download-Script {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Filename
    )
    
    $url = "$ScriptBaseUrl/$Filename"
    $outputPath = "$ScriptsDir\$Filename"
    
    Write-Host "Downloading $Filename..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath
        return $true
    } catch {
        Write-Host "Failed to download $Filename. Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Run-Script {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Filename
    )
    
    $scriptPath = "$ScriptsDir\$Filename"
    
    if (Test-Path $scriptPath) {
        Write-Host "Running $Filename..." -ForegroundColor Green
        try {
            & $scriptPath -LogFile $LogFile
            return $true
        } catch {
            Write-Host "Error running $Filename. Error: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Script file not found: $scriptPath" -ForegroundColor Red
        return $false
    }
}

# Display welcome message
Clear-Host
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "    Windows 11 Development Environment Setup" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "This script will help you set up your Windows 11 development environment by downloading and running specialized setup scripts.`n" -ForegroundColor White

# Download and run required core modules first
foreach ($module in $ScriptModules | Where-Object { $_.Required -eq $true }) {
    if (Download-Script -Filename $module.Filename) {
        Run-Script -Filename $module.Filename
    } else {
        Write-Host "Failed to download required module: $($module.Name). Setup cannot continue." -ForegroundColor Red
        exit 1
    }
}

# Let the user select which modules to install
Write-Host "`nSelect which components to install:`n" -ForegroundColor Yellow

$selectedModules = @()

foreach ($module in $ScriptModules | Where-Object { $_.Required -eq $false }) {
    $install = Read-Host "Install $($module.Name) - $($module.Description)? (y/n)"
    if ($install -eq "y") {
        $selectedModules += $module
    }
}

# Download and run selected modules
foreach ($module in $selectedModules) {
    if (Download-Script -Filename $module.Filename) {
        Run-Script -Filename $module.Filename
    } else {
        Write-Host "Failed to download module: $($module.Name). Continuing with other modules." -ForegroundColor Yellow
    }
}

# Setup completion
Write-Host "`n================================================" -ForegroundColor Green
Write-Host "    Windows 11 Development Environment Setup Complete!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green

Write-Host "Setup log file: $LogFile" -ForegroundColor Cyan

# Suggest reboot
$reboot = Read-Host "A system restart is recommended to complete all installations. Restart now? (y/n)"
if ($reboot -eq "y") {
    Restart-Computer -Force
}
