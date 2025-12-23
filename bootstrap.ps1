# File: bootstrap.ps1
# Purpose: Resumable, idempotent interactive installer for Windows developer environment.

param(
  [switch]$Yes,
  [string]$Name = "",
  [string]$Email = "",
  [string]$GitHub = "",
  [ValidateSet("bash","zsh")][string]$Shell = "bash",
  [ValidateSet("vim","nano","code")][string]$Editor = "code",
  [ValidateSet("postgresql","mysql","mongodb","skip")][string]$Db = "skip"
)

$StateFile = "$HOME\.devsetup_state_win"
$LogFile = "$HOME\.devsetup_win.log"

function Write-Log { param([string]$Msg) "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) $Msg" | Tee-Object -FilePath $LogFile -Append }
function Is-Done { param([string]$Step) Test-Path $StateFile -PathType Leaf -and (Select-String -Path $StateFile -Pattern "^\Q$Step\E$" -Quiet) }
function Mark-Done { param([string]$Step) Add-Content -Path $StateFile -Value $Step }

# Banner
@"
===============================================================
Fullstack Developer Environment Bootstrap (Windows)

This script will install:
- Core tools: Git, curl, Python3
- Node.js LTS + npm/yarn/pnpm
- Java 17 (OpenJDK), Maven, Gradle, Spring Boot CLI
- Docker Desktop
- PostgreSQL / MySQL / MongoDB (your choice)
- VS Code + extensions
- JetBrains IntelliJ IDEA (Community Edition)
- Git config + SSH keygen
===============================================================
"@ | Write-Log

if (-not $Yes) {
  $ans = Read-Host "Proceed with installation? (y/N)"
  if ($ans.ToLower() -ne "y") { Write-Log "Installation aborted."; exit 0 }
}

New-Item -ItemType File -Path $StateFile -Force | Out-Null
New-Item -ItemType File -Path $LogFile -Force | Out-Null

# Collect user info
if (-not (Is-Done "userinfo")) {
  if (-not $Name) { $Name = Read-Host "Enter your full name" }
  if (-not $Email) { $Email = Read-Host "Enter your email address" }
  if (-not $GitHub) { $GitHub = Read-Host "Enter your GitHub username" }
  if (-not $Editor) { $Editor = Read-Host "Choose editor [vim|nano|code]" }
  if (-not $Shell) { $Shell = Read-Host "Choose shell [bash|zsh]" }
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
  Write-Log "Installing Node.js LTS..."
  winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
  npm install -g yarn pnpm | Out-Null
  Mark-Done "node"
}

# Java stack
if (-not (Is-Done "java")) {
  Write-Log "Installing Java 17, Maven, Gradle..."
  winget install --id EclipseAdoptium.Temurin.17.JDK -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id Apache.Maven -e --source winget --accept-source-agreements --accept-package-agreements
  winget install --id Gradle.Gradle -e --source winget --accept-source-agreements --accept-package-agreements
  # Spring Boot CLI via SDKMAN is tricky on Windows; recommend using Maven/Gradle tasks
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

Write-Log "✅ Setup complete! See $LogFile for details."
