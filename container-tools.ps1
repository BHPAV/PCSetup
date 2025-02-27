#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs container tools for Windows 11 development.
.DESCRIPTION
    Sets up Docker, Kubernetes tools, and local Kubernetes clusters
    for container-based development on Windows 11.
.EXAMPLE
    .\container-tools.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

param (
    [string]$LogFile = "$env:USERPROFILE\DevSetup\Logs\container-tools-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Import utility functions
$utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath -LogFile $LogFile
} else {
    Write-Error "Required utils.ps1 script not found. Please ensure it exists in the same directory."
    exit 1
}

Write-Log "Starting Container Tools Installation" "INFO"

function Install-Docker {
    Invoke-Task -Name "Installing Docker Desktop" -ScriptBlock {
        # Check if Docker is already installed
        if (Test-CommandExists "docker") {
            $dockerVersion = docker --version
            Write-Log "Docker is already installed: $dockerVersion" "INFO"
            
            # Ask if user wants to update/reinstall
            $reinstall = Read-Host "Do you want to reinstall/update Docker Desktop? (y/n)"
            if ($reinstall -ne "y") {
                return
            }
        }
        
        # First check if WSL2 is installed
        $wslStatus = wsl --status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WSL2 is required for Docker Desktop. Installing WSL..." "WARN"
            wsl --install
            
            Write-Log "WSL installation started. A system restart will be required before installing Docker." "WARN"
            $restart = Read-Host "Do you want to restart your computer now? (y/n)"
            
            if ($restart -eq "y") {
                Restart-Computer -Force
            } else {
                Write-Log "Please restart your computer before continuing with Docker installation" "WARN"
                return
            }
        }
        
        # Install Docker Desktop
        Write-Log "Installing Docker Desktop..." "INFO"
        winget install --id Docker.DockerDesktop --silent --accept-source-agreements --accept-package-agreements
        
        # Wait for installation to complete
        Start-Sleep -Seconds 10
        
        # Add to PATH if needed
        $dockerPath = "C:\Program Files\Docker\Docker\resources\bin"
        $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if (-not $path.Contains($dockerPath)) {
            [Environment]::SetEnvironmentVariable("PATH", "$path;$dockerPath", "Machine")
            Write-Log "Added Docker to PATH" "SUCCESS"
        }
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Verify Docker installation
        Write-Log "Docker Desktop installed. Please start Docker Desktop manually to complete setup." "INFO"
        
        $startDocker = Read-Host "Do you want to start Docker Desktop now? (y/n)"
        if ($startDocker -eq "y") {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        }
        
        Write-Log "Note: You may need to log out and log back in for Docker to work properly" "WARN"
    }
}

function Install-KubernetesTools {
    Invoke-Task -Name "Installing Kubernetes Tools" -ScriptBlock {
        # Install kubectl
        if (-not (Test-CommandExists "kubectl")) {
            Write-Log "Installing kubectl..." "INFO"
            scoop install kubectl
        } else {
            $kubectlVersion = kubectl version --client --short
            Write-Log "kubectl is already installed: $kubectlVersion" "INFO"
        }
        
        # Install Helm
        if (-not (Test-CommandExists "helm")) {
            Write-Log "Installing Helm..." "INFO"
            scoop install helm
        } else {
            $helmVersion = helm version --short
            Write-Log "Helm is already installed: $helmVersion" "INFO"
        }
        
        # Install k9s - TUI for Kubernetes
        if (-not (Test-CommandExists "k9s")) {
            Write-Log "Installing k9s..." "INFO"
            scoop install k9s
        } else {
            $k9sVersion = (k9s version | Select-String "Version" | Out-String).Trim()
            Write-Log "k9s is already installed: $k9sVersion" "INFO"
        }
        
        # Install Lens - GUI for Kubernetes
        $installLens = Read-Host "Do you want to install Lens (Kubernetes IDE)? (y/n)"
        if ($installLens -eq "y") {
            Write-Log "Installing Lens..." "INFO"
            winget install --id Mirantis.Lens --silent --accept-source-agreements --accept-package-agreements
        }
        
        # Create .kube directory
        $kubeDir = "$env:USERPROFILE\.kube"
        if (-not (Test-Path $kubeDir)) {
            New-Item -ItemType Directory -Path $kubeDir -Force | Out-Null
            Write-Log "Created .kube directory at $kubeDir" "SUCCESS"
        }
        
        Write-Log "Kubernetes tools installed successfully" "SUCCESS"
    }
}

function Install-LocalKubernetes {
    Invoke-Task -Name "Installing Local Kubernetes Cluster Tools" -ScriptBlock {
        # Get user preference for local K8s tools
        Write-Host "`nLocal Kubernetes options:" -ForegroundColor Yellow
        Write-Host "1. Minikube - single-node Kubernetes cluster"
        Write-Host "2. Kind (Kubernetes in Docker) - multi-node clusters"
        Write-Host "3. Both tools"
        Write-Host "0. Skip local Kubernetes installation"
        
        $choice = Read-Host "Enter your choice (0-3)"
        
        switch ($choice) {
            "0" {
                Write-Log "Skipping local Kubernetes installation" "INFO"
                return
            }
            "1" { $installMinikube = $true; $installKind = $false }
            "2" { $installMinikube = $false; $installKind = $true }
            "3" { $installMinikube = $true; $installKind = $true }
            default {
                Write-Log "Invalid choice. Skipping local Kubernetes installation." "WARN"
                return
            }
        }
        
        # Install Minikube if selected
        if ($installMinikube) {
            if (-not (Test-CommandExists "minikube")) {
                Write-Log "Installing Minikube..." "INFO"
                scoop install minikube
                
                if (Test-CommandExists "minikube") {
                    $minikubeVersion = minikube version
                    Write-Log "Minikube installed: $minikubeVersion" "SUCCESS"
                    
                    # Configure Minikube
                    $startMinikube = Read-Host "Do you want to start and configure Minikube now? (y/n)"
                    if ($startMinikube -eq "y") {
                        # Get available memory and set reasonable defaults
                        $totalMemoryGB = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
                        $recommendedMemoryMB = [Math]::Min(4096, [Math]::Floor($totalMemoryGB * 0.25 * 1024))
                        $recommendedCPUs = [Math]::Min(4, (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors / 2)
                        
                        Write-Log "Starting Minikube with $recommendedCPUs CPUs and $recommendedMemoryMB MB memory..." "INFO"
                        minikube start --cpus $recommendedCPUs --memory $recommendedMemoryMB --driver=hyperv
                        
                        # Enable useful addons
                        minikube addons enable metrics-server
                        minikube addons enable dashboard
                        minikube addons enable ingress
                        
                        Write-Log "Minikube started and configured with basic addons" "SUCCESS"
                        Write-Log "You can access the dashboard with: minikube dashboard" "INFO"
                    }
                } else {
                    Write-Log "Minikube installation failed" "ERROR"
                }
            } else {
                $minikubeVersion = minikube version
                Write-Log "Minikube is already installed: $minikubeVersion" "INFO"
            }
        }
        
        # Install Kind if selected
        if ($installKind) {
            if (-not (Test-CommandExists "kind")) {
                Write-Log "Installing Kind..." "INFO"
                scoop install kind
                
                if (Test-CommandExists "kind") {
                    $kindVersion = kind version
                    Write-Log "Kind installed: $kindVersion" "SUCCESS"
                    
                    # Create a basic Kind cluster configuration
                    $createCluster = Read-Host "Do you want to create a basic Kind cluster? (y/n)"
                    if ($createCluster -eq "y") {
                        # Create a multi-node cluster config
                        $clusterConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
"@
                        
                        $clusterConfigPath = "$TempDir\kind-cluster-config.yaml"
                        $clusterConfig | Out-File -FilePath $clusterConfigPath -Encoding utf8
                        
                        Write-Log "Creating Kind cluster with 1 control plane and 2 worker nodes..." "INFO"
                        kind create cluster --name dev-cluster --config $clusterConfigPath
                        
                        Write-Log "Kind cluster 'dev-cluster' created" "SUCCESS"
                        
                        # Set kubectl context
                        kubectl cluster-info --context kind-dev-cluster
                        
                        Write-Log "Kubernetes context set to kind-dev-cluster" "SUCCESS"
                    }
                } else {
                    Write-Log "Kind installation failed" "ERROR"
                }
            } else {
                $kindVersion = kind version
                Write-Log "Kind is already installed: $kindVersion" "INFO"
            }
        }
    }
}

function Install-ContainerRegistryTools {
    Invoke-Task -Name "Installing Container Registry Tools" -ScriptBlock {
        # Install Skopeo for container image inspection
        if (-not (Test-CommandExists "skopeo")) {
            Write-Log "Installing Skopeo..." "INFO"
            scoop install skopeo
            
            if (Test-CommandExists "skopeo") {
                $skopeoVersion = skopeo --version
                Write-Log "Skopeo installed: $skopeoVersion" "SUCCESS"
            } else {
                Write-Log "Skopeo installation failed" "ERROR"
            }
        } else {
            $skopeoVersion = skopeo --version
            Write-Log "Skopeo is already installed: $skopeoVersion" "INFO"
        }
        
        # Setup local container registry
        $setupRegistry = Read-Host "Do you want to set up a local container registry? (y/n)"
        if ($setupRegistry -eq "y") {
            # Check if Docker is running
            if (-not (Test-CommandExists "docker")) {
                Write-Log "Docker is not available. Please install Docker first." "ERROR"
                return
            }
            
            try {
                docker info | Out-Null
                
                # Create local registry
                Write-Log "Creating local container registry..." "INFO"
                docker run -d -p 5000:5000 --restart=always --name registry registry:2
                
                Write-Log "Local container registry running at localhost:5000" "SUCCESS"
                Write-Log "You can push images with: docker tag myimage localhost:5000/myimage && docker push localhost:5000/myimage" "INFO"
            } catch {
                Write-Log "Docker is not running. Please start Docker Desktop and try again." "ERROR"
            }
        }
    }
}

# Run installations
Install-Docker
Install-KubernetesTools
Install-LocalKubernetes
Install-ContainerRegistryTools

# Summary
Write-Log "Container tools installation completed" "SUCCESS"
