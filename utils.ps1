#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Core utility functions for Windows 11 development environment setup.
.DESCRIPTION
    Contains shared functions used by all script modules including logging,
    command execution, and system checks.
.EXAMPLE
    . .\utils.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

param (
    [string]$LogFile = "$env:USERPROFILE\DevSetup\Logs\utils-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Ensure log directory exists
$LogDir = Split-Path -Path $LogFile -Parent
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Directories
$Global:ToolsDir = "$env:USERPROFILE\DevTools"
$Global:TempDir = "$env:TEMP\DevSetup"

# Create necessary directories
New-Item -ItemType Directory -Path $Global:ToolsDir -Force | Out-Null
New-Item -ItemType Directory -Path $Global:TempDir -Force | Out-Null

# Initialize global variables
$Global:SetupSuccess = $true
$Global:InstallCount = 0
$Global:FailureCount = 0
$Global:StartTime = Get-Date

#region Helper Functions

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $FormattedMessage = "[$Timestamp] [$Level] $Message"
    
    # Output to console with color
    switch ($Level) {
        "INFO"    { Write-Host $FormattedMessage -ForegroundColor Cyan }
        "WARN"    { Write-Host $FormattedMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $FormattedMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $FormattedMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $FormattedMessage
}

function Invoke-Task {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )
    
    Write-Log "Starting task: $Name" "INFO"
    
    try {
        & $ScriptBlock
        Write-Log "Task completed: $Name" "SUCCESS"
        $Global:InstallCount++
        return $true
    } catch {
        Write-Log "Task failed: $Name - $($_.Exception.Message)" "ERROR"
        $Global:FailureCount++
        $Global:SetupSuccess = $false
        return $false
    }
}

function Test-CommandExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
}

function Download-File {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [int]$Retries = 3
    )
    
    Write-Log "Downloading $Url to $OutputPath" "INFO"
    
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $Retries) {
        $attempt++
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
            $success = $true
            Write-Log "Download completed successfully" "SUCCESS"
        } catch {
            if ($attempt -lt $Retries) {
                Write-Log "Download attempt $attempt failed. Retrying in 5 seconds..." "WARN"
                Start-Sleep -Seconds 5
            } else {
                Write-Log "Download failed after $Retries attempts. Error: $($_.Exception.Message)" "ERROR"
                throw "Failed to download file after $Retries attempts"
            }
        }
    }
    
    return $success
}

function Restart-Explorer {
    Write-Log "Restarting Explorer to apply changes" "INFO"
    Get-Process explorer | Stop-Process -Force
    Start-Sleep -Seconds 2
    Start-Process explorer
}

function Create-RestorePoint {
    param (
        [string]$Description = "Before Dev Environment Setup"
    )
    
    Write-Log "Creating System Restore Point: $Description" "INFO"
    try {
        Checkpoint-Computer -Description $Description -RestorePointType "APPLICATION_INSTALL"
        Write-Log "System Restore Point created successfully" "SUCCESS"
        return $true
    } catch {
        Write-Log "Failed to create System Restore Point: $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Get-CPUDetails {
    $cpu = Get-WmiObject -Class Win32_Processor
    return @{
        Name = $cpu.Name;
        Cores = $cpu.NumberOfCores;
        LogicalProcessors = $cpu.NumberOfLogicalProcessors;
        MaxClockSpeed = $cpu.MaxClockSpeed;
        Architecture = $cpu.AddressWidth;
    }
}

function Get-RAMDetails {
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $totalMemory = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
    return @{
        TotalGB = $totalMemory;
    }
}

function Get-GPUDetails {
    $gpu = Get-WmiObject -Class Win32_VideoController
    return @{
        Name = $gpu.Name;
        DriverVersion = $gpu.DriverVersion;
        AdapterRAM = [Math]::Round($gpu.AdapterRAM / 1GB, 2);
    }
}

function Get-SystemDetails {
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    
    return @{
        OSName = $osInfo.Caption;
        OSVersion = $osInfo.Version;
        OSBuild = $osInfo.BuildNumber;
        ComputerName = $computerSystem.Name;
        Manufacturer = $computerSystem.Manufacturer;
        Model = $computerSystem.Model;
        CPU = Get-CPUDetails;
        RAM = Get-RAMDetails;
        GPU = Get-GPUDetails;
    }
}

# Export functions and variables for other scripts
Export-ModuleMember -Function * -Variable ToolsDir, TempDir, SetupSuccess, InstallCount, FailureCount, StartTime
