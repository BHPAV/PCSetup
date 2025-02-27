#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs core development tools for Windows 11.
.DESCRIPTION
    Sets up Git, VS Code, Visual Studio, PowerShell 7, and Windows Terminal
    for development on Windows 11.
.EXAMPLE
    .\dev-tools.ps1
.NOTES
    Author: Claude 3.7 Sonnet
    Version: 1.0
    Last Updated: February 27, 2025
#>

param (
    [string]$LogFile = "$env:USERPROFILE\DevSetup\Logs\dev-tools-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Import utility functions
$utilsPath = Join-Path -Path $PSScriptRoot -ChildPath "utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath -LogFile $LogFile
} else {
    Write-Error "Required utils.ps1 script not found. Please ensure it exists in the same directory."
    exit 1
}

Write-Log "Starting Development Tools Installation" "INFO"

function Install-Git {
    Invoke-Task -Name "Installing Git" -ScriptBlock {
        if (-not (Test-CommandExists "git")) {
            Write-Log "Git not found, installing..." "INFO"
            winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        
        # Configure Git
        if (Test-CommandExists "git") {
            $gitVersion = git --version
            Write-Log "Git installed: $gitVersion" "SUCCESS"
            
            # Basic Git configuration
            git config --global credential.helper manager
            
            # Prompt for user details
            $name = Read-Host "Enter your name for Git configuration (leave blank to skip)"
            $email = Read-Host "Enter your email for Git configuration (leave blank to skip)"
            
            if ($name) { git config --global user.name "$name" }
            if ($email) { git config --global user.email "$email" }
            
            git config --global init.defaultBranch main
            git config --global core.autocrlf input
            
            # Ask about SSH key
            $setupSSH = Read-Host "Do you want to set up an SSH key for Git? (y/n)"
            if ($setupSSH -eq "y") {
                $sshEmail = if ($email) { $email } else { Read-Host "Enter your email for SSH key" }
                
                # Check if ssh-keygen is available
                if (Test-CommandExists "ssh-keygen") {
                    # Generate key
                    ssh-keygen -t ed25519 -C "$sshEmail"
                    
                    # Start ssh-agent
                    Write-Log "Starting ssh-agent..." "INFO"
                    Start-Service ssh-agent
                    
                    # Add key to agent
                    ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
                    
                    # Display public key
                    Write-Log "Your SSH public key is:" "INFO"
                    Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
                    Write-Log "Add this key to your GitHub/GitLab/Azure DevOps account" "INFO"
                    
                    # Copy to clipboard
                    Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" | Set-Clipboard
                    Write-Log "Public key copied to clipboard" "SUCCESS"
                } else {
                    Write-Log "ssh-keygen not found. Please install OpenSSH client." "ERROR"
                }
            }
            
            # Install GitHub CLI
            $installGHCLI = Read-Host "Do you want to install GitHub CLI? (y/n)"
            if ($installGHCLI -eq "y") {
                winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
                
                if (Test-CommandExists "gh") {
                    $ghVersion = gh --version
                    Write-Log "GitHub CLI installed: $ghVersion" "SUCCESS"
                    
                    # Auth with GitHub
                    $authGH = Read-Host "Do you want to authenticate with GitHub now? (y/n)"
                    if ($authGH -eq "y") {
                        gh auth login
                    }
                }
            }
        } else {
            throw "Git installation failed"
        }
    }
}

function Install-VSCode {
    Invoke-Task -Name "Installing Visual Studio Code" -ScriptBlock {
        if (-not (Test-CommandExists "code")) {
            Write-Log "VS Code not found, installing..." "INFO"
            winget install --id Microsoft.VisualStudioCode --silent --accept-source-agreements --accept-package-agreements
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        
        # Configure VS Code
        if (Test-CommandExists "code") {
            $codeVersion = code --version
            Write-Log "VS Code installed: $codeVersion" "SUCCESS"
            
            # Install essential extensions
            $extensions = @(
                # Languages & Frameworks
                "ms-python.python"
                "ms-dotnettools.csharp"
                "ms-vscode.powershell"
                "formulahendry.code-runner"
                "rust-lang.rust-analyzer"
                "golang.go"
                "vscjava.vscode-java-pack"
                
                # Web Development
                "dbaeumer.vscode-eslint"
                "esbenp.prettier-vscode"
                "bradlc.vscode-tailwindcss"
                "Vue.volar"
                "Angular.ng-template"
                
                # DevOps & Cloud
                "ms-azuretools.vscode-docker"
                "ms-kubernetes-tools.vscode-kubernetes-tools"
                "ms-vscode-remote.remote-wsl"
                "ms-vscode-remote.remote-containers"
                
                # Collaboration & Productivity
                "GitHub.copilot"
                "GitHub.vscode-pull-request-github"
                "ms-vsliveshare.vsliveshare"
                "streetsidesoftware.code-spell-checker"
                
                # Editor Enhancements
                "eamodio.gitlens"
                "usernamehw.errorlens"
                "njpwerner.autodocstring"
                "ritwickdey.LiveServer"
                "vscode-icons-team.vscode-icons"
            )
            
            Write-Log "Installing VS Code extensions..." "INFO"
            foreach ($extension in $extensions) {
                code --install-extension $extension
            }
            
            Write-Log "VS Code extensions installed" "SUCCESS"
            
            # Enable settings sync
            $enableSync = Read-Host "Do you want to enable Settings Sync in VS Code? (y/n)"
            if ($enableSync -eq "y") {
                Write-Log "Please sign in and enable Settings Sync from the VS Code UI" "INFO"
                code --command "workbench.userDataSync.actions.turnOn"
            }
        } else {
            throw "VS Code installation failed"
        }
    }
}

function Install-VisualStudio {
    Invoke-Task -Name "Installing Visual Studio" -ScriptBlock {
        Write-Host "`nVisual Studio editions:" -ForegroundColor Yellow
        Write-Host "1. Community (free for individual developers, academic, and small businesses)"
        Write-Host "2. Professional (for professional developers and small teams)"
        Write-Host "3. Enterprise (for large teams and enterprise development)"
        Write-Host "0. Skip Visual Studio installation"
        
        $edition = Read-Host "Choose Visual Studio edition (0-3)"
        
        if ($edition -eq "0") {
            Write-Log "Skipping Visual Studio installation" "INFO"
            return
        }
        
        $vsId = switch ($edition) {
            "1" { "Microsoft.VisualStudio.2022.Community" }
            "2" { "Microsoft.VisualStudio.2022.Professional" }
            "3" { "Microsoft.VisualStudio.2022.Enterprise" }
            default { "Microsoft.VisualStudio.2022.Community" }
        }
        
        # Workloads menu
        Write-Host "`nSelect Visual Studio workloads to install (comma-separated numbers, e.g. 1,3,5):" -ForegroundColor Yellow
        $workloadOptions = @(
            @{ Number = "1"; Name = "Desktop development with C++"; ID = "--add Microsoft.VisualStudio.Workload.NativeDesktop" },
            @{ Number = "2"; Name = ".NET desktop development"; ID = "--add Microsoft.VisualStudio.Workload.ManagedDesktop" },
            @{ Number = "3"; Name = "ASP.NET and web development"; ID = "--add Microsoft.VisualStudio.Workload.NetWeb" },
            @{ Number = "4"; Name = "Azure development"; ID = "--add Microsoft.VisualStudio.Workload.Azure" },
            @{ Number = "5"; Name = "Mobile development with .NET"; ID = "--add Microsoft.VisualStudio.Workload.NetCrossPlat" },
            @{ Number = "6"; Name = "Game development with Unity"; ID = "--add Microsoft.VisualStudio.Workload.ManagedGame" },
            @{ Number = "7"; Name = "Data storage and processing"; ID = "--add Microsoft.VisualStudio.Workload.Data" },
            @{ Number = "8"; Name = "Node.js development"; ID = "--add Microsoft.VisualStudio.Workload.Node" }
        )
        
        foreach ($option in $workloadOptions) {
            Write-Host "$($option.Number). $($option.Name)"
        }
        
        $selectedWorkloads = Read-Host "Enter your selection"
        $workloadsArgs = ""
        
        if ($selectedWorkloads -ne "") {
            $selectedNumbers = $selectedWorkloads.Split(',').Trim()
            foreach ($num in $selectedNumbers) {
                $workload = $workloadOptions | Where-Object { $_.Number -eq $num }
                if ($workload) {
                    $workloadsArgs += " $($workload.ID)"
                }
            }
        }
        
        # Install VS with selected workloads
        Write-Log "Installing Visual Studio with selected workloads..." "INFO"
        
        $vsArgs = "--passive --wait --norestart"
        if ($workloadsArgs) {
            $vsArgs += $workloadsArgs
        }
        
        # Use winget to install
        winget install --id $vsId --silent --override "$vsArgs" --accept-source-agreements --accept-package-agreements
        
        Write-Log "Visual Studio installation initiated. This may take a while..." "INFO"
        
        # Additional VS extensions
        Write-Log "For additional Visual Studio extensions, please use the Extensions manager in Visual Studio" "INFO"
    }
}

function Install-PowerShell7 {
    Invoke-Task -Name "Installing PowerShell 7" -ScriptBlock {
        if (-not (Test-CommandExists "pwsh")) {
            Write-Log "PowerShell 7 not found, installing..." "INFO"
            winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        
        # Configure PowerShell
        if (Test-CommandExists "pwsh") {
            $pwshVersion = & pwsh -Command '$PSVersionTable.PSVersion'
            Write-Log "PowerShell 7 installed: $pwshVersion" "SUCCESS"
            
            # Create profile if it doesn't exist
            pwsh -Command {
                if (-not (Test-Path -Path $PROFILE)) {
                    New-Item -Path $PROFILE -Type File -Force
                    Write-Output "PowerShell profile created at $PROFILE"
                }
                
                # Install modules
                $modules = @("PSReadLine", "posh-git", "Terminal-Icons", "z", "PSFzf")
                foreach ($module in $modules) {
                    if (-not (Get-Module -ListAvailable -Name $module)) {
                        Write-Output "Installing PowerShell module: $module"
                        Install-Module -Name $module -Force -Scope CurrentUser
                    }
                }
                
                # Add basic profile configuration
                $profileContent = @"
# Import modules
Import-Module PSReadLine
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module z
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# PSReadLine configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar

# Set a nicer prompt with posh-git
function prompt {
    `$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$principal = [Security.Principal.WindowsPrincipal] `$identity
    `$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    `$prefix = if (Test-Path variable:/PSDebugContext) { '[DBG]: ' }
        elseif (`$principal.IsInRole(`$adminRole)) { "[ADMIN]: " }
        else { "" }

    `$path = `$executionContext.SessionState.Path.CurrentLocation
    `$prompt = `$prefix + `$path.Path + `$(Write-VcsStatus) + "`n> "
    
    `$host.ui.RawUI.WindowTitle = `$path.Path
    
    return `$prompt
}

# Aliases
Set-Alias -Name g -Value git
Set-Alias -Name k -Value kubectl
Set-Alias -Name tf -Value terraform
Set-Alias -Name d -Value docker

# Custom functions
function Get-GitStatus { git status }
Set-Alias -Name gs -Value Get-GitStatus

function Open-ExplorerHere { explorer . }
Set-Alias -Name here -Value Open-ExplorerHere

# Useful utilities
function which (`$command) {
    Get-Command -Name `$command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
"@
                Add-Content -Path $PROFILE -Value $profileContent
            }
            
            Write-Log "PowerShell 7 profile configured" "SUCCESS"
        } else {
            throw "PowerShell 7 installation failed"
        }
    }
}

function Install-WindowsTerminal {
    Invoke-Task -Name "Installing Windows Terminal" -ScriptBlock {
        if (-not (Test-CommandExists "wt")) {
            Write-Log "Windows Terminal not found, installing..." "INFO"
            winget install --id Microsoft.WindowsTerminal --silent --accept-source-agreements --accept-package-agreements
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        
        if (Get-Command "wt" -ErrorAction SilentlyContinue) {
            Write-Log "Windows Terminal installed successfully" "SUCCESS"
            
            # Configure Windows Terminal settings
            $terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            
            if (Test-Path $terminalSettingsPath) {
                Write-Log "Windows Terminal settings already exist" "INFO"
                
                $customizeNow = Read-Host "Do you want to open Windows Terminal settings now? (y/n)"
                if ($customizeNow -eq "y") {
                    Start-Process "wt.exe" -ArgumentList "--settings"
                }
            } else {
                Write-Log "Creating default Windows Terminal settings..." "INFO"
                
                # Basic Windows Terminal configuration
                $terminalSettings = @{
                    "$schema" = "https://aka.ms/terminal-profiles-schema"
                    "defaultProfile" = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}" # PowerShell Core profile GUID
                    "profiles" = @{
                        "defaults" = @{
                            "fontFace" = "Cascadia Code PL"
                            "fontSize" = 10
                            "colorScheme" = "One Half Dark"
                            "useAcrylic" = $true
                            "acrylicOpacity" = 0.8
                        }
                    }
                }
                
                # Create directory if it doesn't exist
                $terminalDir = Split-Path -Path $terminalSettingsPath -Parent
                if (-not (Test-Path -Path $terminalDir)) {
                    New-Item -ItemType Directory -Path $terminalDir -Force | Out-Null
                }
                
                # Convert to JSON and save
                $terminalSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $terminalSettingsPath
                Write-Log "Windows Terminal settings created" "SUCCESS"
            }
        } else {
            Write-Log "Windows Terminal installation may have failed. Please install manually." "WARN"
        }
    }
}

# Install all tools by default, or let user select
$installAll = Read-Host "Do you want to install all development tools? (y/n)"

if ($installAll -eq "y") {
    Install-Git
    Install-VSCode
    Install-VisualStudio
    Install-PowerShell7
    Install-WindowsTerminal
} else {
    Write-Host "`nSelect which tools to install:" -ForegroundColor Yellow
    
    $installGit = Read-Host "Install Git? (y/n)"
    if ($installGit -eq "y") { Install-Git }
    
    $installVSCode = Read-Host "Install Visual Studio Code? (y/n)"
    if ($installVSCode -eq "y") { Install-VSCode }
    
    $installVS = Read-Host "Install Visual Studio? (y/n)"
    if ($installVS -eq "y") { Install-VisualStudio }
    
    $installPwsh = Read-Host "Install PowerShell 7? (y/n)"
    if ($installPwsh -eq "y") { Install-PowerShell7 }
    
    $installTerminal = Read-Host "Install Windows Terminal? (y/n)"
    if ($installTerminal -eq "y") { Install-WindowsTerminal }
}

# Summary
Write-Log "Development tools installation completed" "SUCCESS"
