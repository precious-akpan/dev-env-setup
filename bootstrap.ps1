param(
  [switch]$Yes,
  [string]$Name = "",
  [string]$Email = "",
  [string]$GitHub = "",
  [ValidateSet("bash","zsh")][string]$Shell = "bash",
  [ValidateSet("vim","nano","code")][string]$Editor = "code",
  [ValidateSet("postgresql","mysql","mongodb","skip")][string]$Db = "skip"
)

# Configuration - CHANGE THESE TO PIN VERSIONS FOR YOUR ORG
$NodeVersion = "20"
$JavaVersion = "17"
$MinDiskGB = 10

$StateFile = "$HOME\.devsetup_state_win"
$LogFile = "$HOME\.devsetup_win.log"

function Write-Log {
  <#
  .SYNOPSIS
    Logs a message with a timestamp to both the console and the log file.
  .DESCRIPTION
    Takes a string message, adds a current timestamp, and appends it to the global log file while also displaying it in the console.
  .PARAMETER Msg
    The message string to be logged.
  #>
  param([string]$Msg) "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) $Msg" | Tee-Object -FilePath $LogFile -Append
}

function Is-Done {
  <#
  .SYNOPSIS
    Checks if a step has already been recorded as completed in the state file.
  .DESCRIPTION
    Searches the state file for a specific step identifier. Returns true if found, false otherwise.
  .PARAMETER Step
    The identifier of the step to check.
  #>
  param([string]$Step) Test-Path $StateFile -PathType Leaf -and (Select-String -Path $StateFile -Pattern "^\Q$Step\E$" -Quiet)
}

function Mark-Done {
  <#
  .SYNOPSIS
    Records a completed step identifier in the state file.
  .DESCRIPTION
    Appends the provided step identifier to the state file to mark it as completed.
  .PARAMETER Step
    The identifier of the step to mark as completed.
  #>
  param([string]$Step) Add-Content -Path $StateFile -Value $Step
}

function Test-PreFlight {
    Write-Log "Running pre-flight checks..."
    
    # Internet check
    try {
        $null = iwr -Uri "https://google.com" -Method Head -TimeoutSec 5 -ErrorAction Stop
    } catch {
        Write-Log "❌ Error: No internet connection."
        exit 1
    }

    # Disk space check
    $drive = Get-PSDrive C
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeGB -lt $MinDiskGB) {
        Write-Log "❌ Error: Insufficient disk space on C:. Need at least ${MinDiskGB}GB (Found ${freeGB}GB)."
        exit 1
    }

    # Admin check
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Log "❌ Error: Elevated PowerShell (Admin) is required."
            exit 1
        }
    } catch {
        Write-Log "⚠️ Warning: Could not verify Admin status. Proceeding with caution."
    }

    Write-Log "✅ Pre-flight checks passed."
}

# Banner
$Banner = @"
===============================================================
Fullstack Developer Environment Bootstrap (Windows)
Consistency Goal: Pinning Node v$NodeVersion, Java $JavaVersion
===============================================================

This script will install:
- Core tools: Git, curl, Python3
- Node.js LTS + npm/yarn/pnpm
- Java $JavaVersion (OpenJDK), Maven, Gradle, Spring Boot CLI
- Docker Desktop
- PostgreSQL / MySQL / MongoDB (your choice)
- VS Code + extensions
- JetBrains IntelliJ IDEA (Community Edition)
- Git config + SSH keygen
===============================================================
"@ 
$Banner | Write-Log

if (-not $Yes) {
  $ans = Read-Host "Proceed with installation? (y/N)"
  if ($ans.ToLower() -ne "y") { Write-Log "Installation aborted."; exit 0 }
}

Test-PreFlight

if (-not (Test-Path $StateFile)) { New-Item -ItemType File -Path $StateFile -Force | Out-Null }
if (-not (Test-Path $LogFile)) { New-Item -ItemType File -Path $LogFile -Force | Out-Null }

# Collect user info
if (-not (Is-Done "userinfo")) {
  if (-not $Name) { $Name = Read-Host "Enter your full name" }
  if (-not $Email) { $Email = Read-Host "Enter your email address" }
  if (-not $GitHub) { $GitHub = Read-Host "Enter your GitHub username" }
  # Use default Editor/Shell from parameters if not provided interactively
  git config --global user.name $Name
  git config --global user.email $Email
  if ($Editor -eq "code") { git config --global core.editor "code --wait" } else { git config --global core.editor $Editor }
  Mark-Done "userinfo"
  Write-Log "Collected user info."
}

# Core tools
if (-not (Is-Done "core")) {
  Write-Log "Installing core tools..."
  winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id Python.Python.3 -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id GNU.Wget -e --source winget --accept-source-agreements --accept-package-agreements
  Mark-Done "core"
}

# Node.js
if (-not (Is-Done "node")) {
  Write-Log "Installing Node.js v$NodeVersion..."
  # Winget doesn't always support pinning major versions easily, but we try the LTS nearest to our version
  winget install --id OpenJS.NodeJS.LTS -e --version "$NodeVersion.*" --source winget --accept-source-agreements --accept-package-agreements 2>$null || `
  winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
  npm install -g yarn pnpm | Out-Null
  Mark-Done "node"
}

# Java stack
if (-not (Is-Done "java")) {
  Write-Log "Installing Java $JavaVersion, Maven, Gradle..."
  winget install --id EclipseAdoptium.Temurin.$JavaVersion.JDK -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id Apache.Maven -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id Gradle.Gradle -e --source winget --accept-source-agreements --accept-package-agreements
  Mark-Done "java"
}

# Docker Desktop
if (-not (Is-Done "docker")) {
  Write-Log "Installing Docker Desktop..."
  winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements
  Write-Log "Open Docker Desktop once to finalize installation."
  Mark-Done "docker"
}

# Database choice
if (-not (Is-Done "db")) {
  Write-Log "Database choice: $Db"
  switch ($Db) {
    "postgresql" { winget install --id PostgreSQL.PostgreSQL -e --source winget --accept-source-agreements --accept-package-agreements }
    "mysql" { winget install --id Oracle.MySQL -e --source winget --accept-source-agreements --accept-package-agreements }
    "mongodb" { winget install --id MongoDB.Server -e --source winget --accept-source-agreements --accept-package-agreements }
    default {}
  }
  Mark-Done "db"
}

# VS Code
if (-not (Is-Done "vscode")) {
  Write-Log "Installing VS Code..."
  winget install --id Microsoft.VisualStudioCode -e --source winget --accept-source-agreements --accept-package-agreements
  code --install-extension ms-vscode.vscode-typescript-next
  code --install-extension dbaeumer.vscode-eslint
  code --install-extension esbenp.prettier-vscode
  code --install-extension ms-python.python
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension vscjava.vscode-java-pack
  code --install-extension vmware.vscode-spring-boot
  Mark-Done "vscode"
}

# IntelliJ IDEA
if (-not (Is-Done "intellij")) {
  Write-Log "Installing IntelliJ IDEA Community Edition..."
  winget install --id JetBrains.IntelliJIDEA.Community -e --source winget --accept-source-agreements --accept-package-agreements
  Mark-Done "intellij"
}

# SSH keygen
if (-not (Is-Done "ssh")) {
  Write-Log "Generating SSH key..."
  $sshDir = "$HOME\.ssh"
  New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
  $keyPath = Join-Path $sshDir "id_ed25519"
  if (-not (Test-Path $keyPath)) {
    ssh-keygen -t ed25519 -C $Email -f $keyPath -N "" | Out-Null
  }
  Write-Log "Public key:"
  Get-Content "${keyPath}.pub" | Write-Log
  Write-Log "Add this key to GitHub/GitLab (Settings → SSH keys)."
  Mark-Done "ssh"
}

# System Manifest
function Get-SystemManifest {
    $manifest = "$HOME\.devsetup_manifest"
    Write-Log "Generating system manifest at $manifest..."
    $nodeVer = try { node -v 2>$null } catch { "not installed" }
    $javaVer = try { java -version 2>&1 | Select-Object -First 1 } catch { "not installed" }
    $dockerVer = try { docker --version 2>$null } catch { "not installed" }
    $gitVer = try { git --version 2>$null } catch { "not installed" }

    $content = @"
--- Dev Environment Manifest ---
Date: $((Get-Date).ToString())
OS: Windows
Node: $($nodeVer -or 'not installed')
Java: $($javaVer -or 'not installed')
Docker: $($dockerVer -or 'not installed')
Git: $($gitVer -or 'not installed')
--------------------------------
"@
    $content | Out-File -FilePath $manifest -Encoding utf8
}

Get-SystemManifest
Write-Log "✅ Setup complete! See $LogFile for details."
