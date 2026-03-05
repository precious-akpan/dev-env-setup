#!/usr/bin/env bash
set -euo pipefail

# Configuration - CHANGE THESE TO PIN VERSIONS FOR YOUR ORG
NODE_VERSION="20"        # Node.js major version
JAVA_VERSION="17"        # OpenJDK version
MIN_DISK_GB=10           # Minimum disk space requirement

STATE_FILE="$HOME/.devsetup_state"
LOG_FILE="$HOME/.devsetup.log"
OS="$(uname -s)"
PKG_MANAGER="unknown"

touch "$STATE_FILE" "$LOG_FILE"

# log: Logs a message with a timestamp to both the console and the log file.
# Arguments:
#   $*: The message to log.
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_FILE"; }

# mark_done: Appends a completed step identifier to the state file.
# Arguments:
#   $1: The step identifier.
mark_done() { echo "$1" >> "$STATE_FILE"; }

# is_done: Checks if a step has already been recorded as completed.
# Arguments:
#   $1: The step identifier.
# Returns:
#   0 if the step is done, 1 otherwise.
is_done() { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }

# detect_pkg_manager: Determines the system's package manager based on the OS and available commands.
# Sets the global PKG_MANAGER variable.
detect_pkg_manager() {
  if [[ "$OS" == "Darwin" ]]; then
    PKG_MANAGER="brew"
  elif command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  fi
}

# pre_flight_checks: Validates system requirements before proceeding with installation.
# Checks for internet connectivity and minimum disk space. Exits on failure.
pre_flight_checks() {
  log "Running pre-flight checks..."
  
  # Auto-install curl for minimal installs
  if ! command -v curl >/dev/null 2>&1; then
    log "curl not found. Attempting auto-install..."
    case "$PKG_MANAGER" in
      apt) sudo apt update && sudo apt install -y curl;;
      dnf) sudo dnf install -y curl;;
      pacman) sudo pacman -Syu --noconfirm curl;;
      *) ;;
    esac
  fi

  # Connection check
  if command -v curl >/dev/null 2>&1; then
    CHECK_CMD="curl -Is https://google.com --connect-timeout 5"
  elif command -v wget >/dev/null 2>&1; then
    CHECK_CMD="wget -q --spider --timeout=5 https://google.com"
  else
    CHECK_CMD="ping -c 1 google.com"
  fi

  if ! $CHECK_CMD >/dev/null 2>&1; then
    log "❌ Error: No internet connection."
    exit 1
  fi

  # Disk space check (rough approximation)
  local available_kb
  available_kb=$(df -P . | awk 'NR==2 {print $4}')
  if [ "$available_kb" -lt $((MIN_DISK_GB * 1024 * 1024)) ]; then
    log "❌ Error: Insufficient disk space. Need at least ${MIN_DISK_GB}GB."
    exit 1
  fi
  
  log "✅ Pre-flight checks passed."
}

# main: The main execution function that orchestrates the bootstrap process.
# Arguments:
#   $@: Any command-line arguments passed to the script.
main() {
  cat <<BANNER
===============================================================
Fullstack Developer Environment Bootstrap (macOS/Linux)
Consistency Goal: Pinning Node v${NODE_VERSION}, Java ${JAVA_VERSION}
BANNER
  cat <<'BANNER'
===============================================================

This script will install:
- Core tools: Git, curl, wget, build-essential, Python3, tmux, zsh/bash
- Node.js LTS + npm/yarn/pnpm
- Java 17 (OpenJDK), Maven, Gradle, Spring Boot CLI
- Docker + Docker Compose
- PostgreSQL / MySQL / MongoDB (your choice)
- VS Code + extensions
- JetBrains IntelliJ IDEA (Community Edition)
- Git config + SSH keygen
===============================================================
BANNER

  read -r -p "Proceed with installation? (y/N): " CONFIRM
  [[ "${CONFIRM,,}" == "y" ]] || exit 0

  detect_pkg_manager
  pre_flight_checks

  # Ensure Homebrew (macOS only)
  # ensure_brew: Checks for and installs Homebrew if the operating system is macOS (Darwin).
  # If installed, it also configures the shell environment to include brew in the PATH.
  ensure_brew() {
    if [[ "$OS" == "Darwin" ]]; then
      if ! command -v brew >/dev/null 2>&1; then
        log "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -d /opt/homebrew/bin ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -d /usr/local/bin ]]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
        mark_done "brew-installed"
      fi
    fi
  }

  if [[ "$OS" == "Darwin" ]]; then
    ensure_brew
  fi

  # Collect user info
  if ! is_done "userinfo"; then
    read -r -p "Enter your full name: " DEV_NAME
    read -r -p "Enter your email address: " DEV_EMAIL
    read -r -p "Enter your GitHub username: " GH_USER
    read -r -p "Choose your shell [bash/zsh]: " SHELL_CHOICE
    read -r -p "Choose your editor [vim/nano/code]: " EDITOR_CHOICE

    git config --global user.name "$DEV_NAME"
    git config --global user.email "$DEV_EMAIL"

    case "$EDITOR_CHOICE" in
      vim|nano) git config --global core.editor "$EDITOR_CHOICE";;
      code) git config --global core.editor "code --wait";;
    esac

    case "$SHELL_CHOICE" in
      zsh) chsh -s "$(command -v zsh)" || true;;
      bash) chsh -s "$(command -v bash)" || true;;
    esac

    log "GitHub username set to $GH_USER"
    mark_done "userinfo"
  fi

  # Core tools
  if ! is_done "core"; then
    log "Installing core tools..."
    case "$PKG_MANAGER" in
      brew)
        brew install git curl wget tmux zsh python
        ;;
      apt)
        sudo apt update && sudo apt install -y git curl wget build-essential python3 python3-pip tmux zsh unzip
        ;;
      dnf)
        sudo dnf install -y git curl wget make gcc gcc-c++ python3-pip tmux zsh unzip
        ;;
      pacman)
        sudo pacman -Syu --noconfirm git curl wget base-devel python-pip tmux zsh unzip
        ;;
      *)
        log "⚠️ Warning: Unknown package manager. Skipping core tools installation."
        ;;
    esac
    mark_done "core"
  fi

  # Node.js
  if ! is_done "node"; then
    log "Installing Node.js (Version: v${NODE_VERSION})..."
    case "$PKG_MANAGER" in
      brew)
        brew install "node@${NODE_VERSION}" || brew install node
        npm install -g yarn pnpm
        ;;
      apt)
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
        sudo apt install -y nodejs
        sudo npm install -g yarn pnpm
        ;;
      dnf)
        curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
        sudo dnf install -y nodejs
        sudo npm install -g yarn pnpm
        ;;
      pacman)
        sudo pacman -S --noconfirm nodejs npm
        sudo npm install -g yarn pnpm
        ;;
    esac
    mark_done "node"
  fi

  # Java + Spring Boot
  if ! is_done "java"; then
    log "Installing Java stack (Version: ${JAVA_VERSION})..."
    case "$PKG_MANAGER" in
      brew)
        brew install "openjdk@${JAVA_VERSION}" maven gradle
        ;;
      apt)
        sudo apt install -y "openjdk-${JAVA_VERSION}-jdk" maven gradle
        ;;
      dnf)
        sudo dnf install -y "java-${JAVA_VERSION}-openjdk-devel" maven gradle
        ;;
      pacman)
        sudo pacman -S --noconfirm jdk${JAVA_VERSION}-openjdk maven gradle
        ;;
    esac
    
    if [[ ! -d "$HOME/.sdkman" ]]; then
      curl -s https://get.sdkman.io | bash
    fi
    # shellcheck source=/dev/null
    source "$HOME/.sdkman/bin/sdkman-init.sh" || true
    sdk install springboot || true
    mark_done "java"
  fi

  # Docker
  if ! is_done "docker"; then
    log "Installing Docker..."
    case "$PKG_MANAGER" in
      brew)
        brew install --cask docker
        log "Open Docker Desktop once to finalize installation."
        ;;
      apt)
        sudo apt install -y docker.io docker-compose
        sudo usermod -aG docker "$USER"
        ;;
      dnf)
        sudo dnf install -y docker docker-compose
        sudo systemctl enable --now docker
        sudo usermod -aG docker "$USER"
        ;;
      pacman)
        sudo pacman -S --noconfirm docker docker-compose
        sudo systemctl enable --now docker
        sudo usermod -aG docker "$USER"
        ;;
    esac
    mark_done "docker"
  fi

  # Database choice
  if ! is_done "db"; then
    read -r -p "Choose DB [postgresql/mysql/mongodb/skip]: " DB_CHOICE
    case "$DB_CHOICE" in
      postgresql)
        case "$PKG_MANAGER" in
          apt) sudo apt install -y postgresql postgresql-contrib;;
          dnf) sudo dnf install -y postgresql-server postgresql-contrib;;
          pacman) sudo pacman -S --noconfirm postgresql;;
          brew) brew install postgresql;;
        esac
        ;;
      mysql)
        case "$PKG_MANAGER" in
          apt) sudo apt install -y mysql-server;;
          dnf) sudo dnf install -y community-mysql-server;;
          pacman) sudo pacman -S --noconfirm mariadb;;
          brew) brew install mysql;;
        esac
        ;;
      mongodb)
        case "$PKG_MANAGER" in
          apt) sudo apt install -y mongodb;;
          dnf) sudo dnf install -y mongodb-org;;
          pacman) sudo pacman -S --noconfirm mongodb-bin;;
          brew) brew install mongodb-community;;
        esac
        ;;
      skip) ;;
    esac
    mark_done "db"
  fi

  # VS Code
  if ! is_done "vscode"; then
    log "Installing VS Code..."
    case "$PKG_MANAGER" in
      brew)
        brew install --cask visual-studio-code
        ;;
      apt)
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
        sudo apt update && sudo apt install -y code
        ;;
      dnf)
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf install -y code
        ;;
      pacman)
        sudo pacman -S --noconfirm code
        ;;
    esac
    code --install-extension ms-vscode.vscode-typescript-next
    code --install-extension dbaeumer.vscode-eslint
    code --install-extension esbenp.prettier-vscode
    code --install-extension ms-python.python
    code --install-extension ms-azuretools.vscode-docker
    code --install-extension vscjava.vscode-java-pack
    code --install-extension vmware.vscode-spring-boot
    mark_done "vscode"
  fi

  # IntelliJ IDEA
  if ! is_done "intellij"; then
    log "Installing JetBrains IntelliJ IDEA..."
    if [[ "$OS" == "Darwin" ]]; then
      ensure_brew
      brew install --cask intellij-idea-ce
    else
      if command -v snap >/dev/null 2>&1; then
        sudo snap install intellij-idea-community --classic
      else
        log "Snap not found, installing JetBrains Toolbox..."
        curl -fsSL https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.28.1.15219.tar.gz -o /tmp/toolbox.tar.gz
        tar -xzf /tmp/toolbox.tar.gz -C /tmp
        toolbox_path=$(find /tmp -maxdepth 1 -type d -name "jetbrains-toolbox*")
        "$toolbox_path/jetbrains-toolbox" &
      fi
    fi
    mark_done "intellij"
  fi

  # SSH keygen
  if ! is_done "ssh"; then
    log "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$DEV_EMAIL ($GH_USER)" -f "$HOME/.ssh/id_ed25519" -N ""
    log "Public key:"
    cat "$HOME/.ssh/id_ed25519.pub"
    mark_done "ssh"
  fi

  # System Manifest
  # generate_manifest: Creates a system manifest file with details about the installed environment.
  generate_manifest() {
    local manifest="$HOME/.devsetup_manifest"
    log "Generating system manifest at $manifest..."
    {
      echo "--- Dev Environment Manifest ---"
      echo "Date: $(date)"
      echo "OS: $OS"
      echo "Pkg Manager: $PKG_MANAGER"
      echo "Node: $(node -v 2>/dev/null || echo 'not installed')"
      echo "Java: $(java -version 2>&1 | head -n 1 || echo 'not installed')"
      echo "Docker: $(docker --version 2>/dev/null || echo 'not installed')"
      echo "Git: $(git --version || echo 'not installed')"
      echo "--------------------------------"
    } > "$manifest"
  }

  generate_manifest
  log "✅ Setup complete! See $LOG_FILE for details."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
