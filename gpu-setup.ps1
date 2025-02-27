#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up NVIDIA GPU development environment on Windows 11.
.DESCRIPTION
    Installs NVIDIA drivers, CUDA toolkit, and machine learning frameworks
    to support GPU-accelerated development and optimization.
.EXAMPLE
    .\gpu-setup.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

param (
    [string]$LogFile = "$env:USERPROFILE\DevSetup\Logs\gpu-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Import utility functions
$utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath -LogFile $LogFile
} else {
    Write-Error "Required utils.ps1 script not found. Please ensure it exists in the same directory."
    exit 1
}

Write-Log "Starting GPU Development Environment Setup" "INFO"

# Check if NVIDIA GPU is present
function Test-NvidiaGPU {
    $gpu = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
    return ($null -ne $gpu)
}

if (-not (Test-NvidiaGPU)) {
    Write-Log "No NVIDIA GPU detected. Some installations may not work correctly." "WARN"
    $continue = Read-Host "Do you want to continue with the GPU setup anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Log "GPU setup aborted by user" "INFO"
        exit 0
    }
}

function Install-NvidiaDrivers {
    Invoke-Task -Name "Installing NVIDIA GPU Drivers" -ScriptBlock {
        Write-Log "Installing NVIDIA GeForce Experience for driver management..." "INFO"
        winget install --id=Nvidia.GeForceExperience -e --accept-source-agreements --accept-package-agreements
        
        # Check if installation was successful
        if (Test-Path "C:\Program Files\NVIDIA Corporation\NVIDIA GeForce Experience\NVIDIA GeForce Experience.exe") {
            Write-Log "NVIDIA GeForce Experience installed successfully" "SUCCESS"
            
            # Start GeForce Experience
            $startGFE = Read-Host "Would you like to start GeForce Experience to update drivers? (y/n)"
            if ($startGFE -eq "y") {
                Start-Process "C:\Program Files\NVIDIA Corporation\NVIDIA GeForce Experience\NVIDIA GeForce Experience.exe"
                Write-Log "Please use GeForce Experience to install the latest drivers" "INFO"
                Read-Host "Press Enter to continue once you've updated your drivers"
            }
        } else {
            Write-Log "NVIDIA GeForce Experience installation might have failed. Continuing..." "WARN"
        }
    }
}

function Install-CUDAToolkit {
    Invoke-Task -Name "Installing NVIDIA CUDA Toolkit" -ScriptBlock {
        # Determine latest CUDA version
        # For now using 12.3.2 as an example, but this could be made dynamic
        $cudaVersion = "12.3.2"
        $cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/$cudaVersion/local_installers/cuda_${cudaVersion}_546.12_windows.exe"
        $cudaInstallerPath = "$TempDir\cuda_installer.exe"
        
        Write-Log "Downloading CUDA Toolkit $cudaVersion..." "INFO"
        Download-File -Url $cudaInstallerUrl -OutputPath $cudaInstallerPath
        
        Write-Log "Installing CUDA Toolkit $cudaVersion..." "INFO"
        Start-Process -FilePath $cudaInstallerPath -ArgumentList "/s" -Wait
        
        # Verify installation
        $cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
        if (Test-Path $cudaPath) {
            $installedVersion = (Get-ChildItem $cudaPath -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
            Write-Log "CUDA Toolkit $installedVersion installed successfully" "SUCCESS"
            
            # Add CUDA to PATH
            $cudaBinPath = "$cudaPath\$installedVersion\bin"
            $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if (-not $path.Contains($cudaBinPath)) {
                [Environment]::SetEnvironmentVariable("PATH", "$path;$cudaBinPath", "Machine")
                Write-Log "Added CUDA bin directory to PATH" "SUCCESS"
            }
        } else {
            throw "CUDA Toolkit installation failed. Please install manually."
        }
    }
}

function Install-PyTorchWithCUDA {
    Invoke-Task -Name "Installing PyTorch with CUDA support" -ScriptBlock {
        # Check if Python is installed
        if (-not (Test-CommandExists "python")) {
            Write-Log "Python not found. Installing Python 3.11 first..." "INFO"
            winget install --id Python.Python.3.11 --silent
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        
        # Verify Python installation
        if (-not (Test-CommandExists "python")) {
            throw "Python installation failed. Please install manually before continuing."
        }
        
        # Install PyTorch with CUDA support
        Write-Log "Installing PyTorch with CUDA support..." "INFO"
        python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
        
        # Verify installation
        $verifyTorch = python -c "import torch; print(f'PyTorch {torch.__version__} installed. CUDA available: {torch.cuda.is_available()}')"
        Write-Log $verifyTorch "INFO"
        
        if ($verifyTorch -like "*CUDA available: True*") {
            Write-Log "PyTorch with CUDA support installed successfully" "SUCCESS"
        } else {
            Write-Log "PyTorch installed but CUDA may not be available. Check configuration." "WARN"
        }
    }
}

function Install-TensorFlowWithGPU {
    Invoke-Task -Name "Installing TensorFlow with GPU support" -ScriptBlock {
        # Check if Python is installed
        if (-not (Test-CommandExists "python")) {
            throw "Python not found. Please run the PyTorch installation first."
        }
        
        # Install TensorFlow with GPU support
        Write-Log "Installing TensorFlow with GPU support..." "INFO"
        python -m pip install tensorflow
        
        # Verify installation
        $verifyTF = python -c "import tensorflow as tf; print(f'TensorFlow {tf.__version__} installed. GPU available: {len(tf.config.list_physical_devices(\"GPU\")) > 0}')"
        Write-Log $verifyTF "INFO"
        
        if ($verifyTF -like "*GPU available: True*") {
            Write-Log "TensorFlow with GPU support installed successfully" "SUCCESS"
        } else {
            Write-Log "TensorFlow installed but GPU may not be available. Check configuration." "WARN"
        }
    }
}

function Install-NvidiaDockerSupport {
    Invoke-Task -Name "Installing NVIDIA Container Toolkit for Docker" -ScriptBlock {
        # Check if Docker is installed
        if (-not (Test-CommandExists "docker")) {
            Write-Log "Docker not found. Install Docker Desktop first" "WARN"
            $installDocker = Read-Host "Do you want to install Docker Desktop now? (y/n)"
            
            if ($installDocker -eq "y") {
                Write-Log "Installing Docker Desktop..." "INFO"
                winget install --id Docker.DockerDesktop --silent
                
                # Wait for installation to complete
                Start-Sleep -Seconds 10
                
                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            } else {
                Write-Log "Skipping NVIDIA Container Toolkit installation" "INFO"
                return
            }
        }
        
        # Install NVIDIA Container Toolkit
        Write-Log "Installing NVIDIA Container Toolkit..." "INFO"
        winget install --id=Nvidia.CUDADockerRuntime -e --accept-source-agreements --accept-package-agreements
        
        Write-Log "NVIDIA Container Toolkit installed. Restart Docker Desktop to enable GPU support" "SUCCESS"
    }
}

function Optimize-GPUPerformance {
    Invoke-Task -Name "Optimizing system for GPU performance" -ScriptBlock {
        # Set power plan to high performance
        Write-Log "Setting power plan to high performance..." "INFO"
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        
        # Configure virtual memory for optimal performance with high-end GPU
        Write-Log "Configuring virtual memory for optimal GPU performance..." "INFO"
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $physicalMemory = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB)
        $recommendedVirtualMemory = $physicalMemory * 1.5
        
        # Set virtual memory
        $pagefile = Get-WmiObject -Class Win32_PageFileSetting
        if ($pagefile) {
            $pagefile.InitialSize = $recommendedVirtualMemory * 1024
            $pagefile.MaximumSize = $recommendedVirtualMemory * 1024
            $pagefile.Put() | Out-Null
            Write-Log "Virtual memory configured: Initial Size: $($recommendedVirtualMemory * 1024) MB, Maximum Size: $($recommendedVirtualMemory * 1024) MB" "SUCCESS"
        } else {
            Write-Log "Failed to configure virtual memory. Please set it manually." "WARN"
        }
    }
}

# Display menu
Write-Host "`n=== NVIDIA GPU Development Setup Options ===" -ForegroundColor Yellow
Write-Host "1. Install NVIDIA Drivers (GeForce Experience)"
Write-Host "2. Install CUDA Toolkit"
Write-Host "3. Install PyTorch with CUDA support"
Write-Host "4. Install TensorFlow with GPU support"
Write-Host "5. Install NVIDIA Container Toolkit for Docker"
Write-Host "6. Optimize System for GPU Performance"
Write-Host "7. Install All Components"
Write-Host "0. Cancel GPU Setup"
Write-Host "=======================================" -ForegroundColor Yellow

$choice = Read-Host "Enter your choice (0-7)"

switch ($choice) {
    "1" { Install-NvidiaDrivers }
    "2" { Install-CUDAToolkit }
    "3" { Install-PyTorchWithCUDA }
    "4" { Install-TensorFlowWithGPU }
    "5" { Install-NvidiaDockerSupport }
    "6" { Optimize-GPUPerformance }
    "7" {
        Install-NvidiaDrivers
        Install-CUDAToolkit
        Install-PyTorchWithCUDA
        Install-TensorFlowWithGPU
        Install-NvidiaDockerSupport
        Optimize-GPUPerformance
    }
    "0" {
        Write-Log "GPU setup cancelled by user" "INFO"
        exit 0
    }
    default {
        Write-Log "Invalid choice. Exiting GPU setup." "WARN"
        exit 1
    }
}

# Summary
Write-Log "GPU Development Environment Setup completed" "SUCCESS"
