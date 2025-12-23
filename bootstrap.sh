#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.devsetup_state"
LOG_FILE="$HOME/.devsetup.log"

# Banner
cat <<'BANNER'
===============================================================
Fullstack Developer Environment Bootstrap (macOS/Linux)

This script will install:
- Git, curl, wget, build tools, Python3, tmux, zsh/bash
- Node.js LTS + npm/yarn/pnpm
- Java 17 (OpenJDK), Maven, Gradle, Spring Boot CLI
- Docker + Docker Compose
- PostgreSQL / MySQL / MongoDB (your choice)
- VS Code + extensions
- Git config + SSH keygen
===============================================================
BANNER

# Confirm
read -r -p "Proceed with installation? (y/N): " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || exit 0

touch "$STATE_FILE" "$LOG_FILE"

# Helpers
mark_done() { echo "$1" >> "$STATE_FILE"; }
is_done() { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_FILE"; }

# Collect user info
if ! is_done "userinfo"; then
  read -p "Enter your full name: " DEV_NAME
  read -p "Enter your email: " DEV_EMAIL
  read -p "Enter your GitHub username: " GH_USER
  git config --global user.name "$DEV_NAME"
  git config --global user.email "$DEV_EMAIL"
  mark_done "userinfo"
fi

# Core tools
if ! is_done "core"; then
  log "Installing core tools..."
  sudo apt update && sudo apt install -y git curl wget build-essential python3 python3-pip tmux zsh unzip
  mark_done "core"
fi

# Node.js
if ! is_done "node"; then
  log "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo npm install -g yarn pnpm
  node -v && npm -v
  mark_done "node"
fi

# Java + Spring Boot
if ! is_done "java"; then
  log "Installing Java stack..."
  sudo apt install -y openjdk-17-jdk maven gradle
  curl -s https://get.sdkman.io | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk install springboot
  java -version && mvn -v && gradle -v && spring --version
  mark_done "java"
fi

# Docker
if ! is_done "docker"; then
  log "Installing Docker..."
  sudo apt install -y docker.io docker-compose
  sudo usermod -aG docker $USER
  docker --version
  mark_done "docker"
fi

# Database choice
if ! is_done "db"; then
  read -p "Choose DB [postgresql/mysql/mongodb/skip]: " DB_CHOICE
  case "$DB_CHOICE" in
    postgresql) sudo apt install -y postgresql postgresql-contrib;;
    mysql) sudo apt install -y mysql-server;;
    mongodb) sudo apt install -y mongodb;;
    skip) ;;
  esac
  mark_done "db"
fi

# VS Code + extensions
if ! is_done "vscode"; then
  log "Installing VS Code..."
  sudo apt install -y software-properties-common apt-transport-https wget
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
  sudo apt update && sudo apt install -y code
  code --install-extension ms-vscode.vscode-typescript-next
  code --install-extension dbaeumer.vscode-eslint
  code --install-extension esbenp.prettier-vscode
  code --install-extension ms-python.python
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension vscjava.vscode-java-pack
  code --install-extension vmware.vscode-spring-boot
  mark_done "vscode"
fi

# SSH keygen
if ! is_done "ssh"; then
  log "Generating SSH key..."
  ssh-keygen -t ed25519 -C "$DEV_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
  log "Public key:"
  cat "$HOME/.ssh/id_ed25519.pub"
  mark_done "ssh"
fi

# Summary
log "✅ Setup complete! See $LOG_FILE for details."
