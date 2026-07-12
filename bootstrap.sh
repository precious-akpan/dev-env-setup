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

# ── Platform Validation ─────────────────────────────────────────
if [[ "$OS" == "Linux" ]]; then
  if [[ ! -f /etc/debian_version ]]; then
    log "Error: Unsupported Linux distribution detected."
    log "This script currently supports Debian/Ubuntu-based distributions only."
    log "Detected OS: $(grep -s '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
    log "Contributions for other distributions are welcome!"
    exit 1
  fi
elif [[ "$OS" != "Darwin" ]]; then
  log "Error: Unsupported operating system: $OS"
  log "This script supports macOS and Debian/Ubuntu Linux."
  exit 1
fi

# ── Argument Parsing ────────────────────────────────────────────
YES_MODE=false
DEV_NAME=""
DEV_EMAIL=""
GH_USER=""
SHELL_CHOICE=""
EDITOR_CHOICE=""
DB_CHOICE=""

# require_arg: Validates that a value-taking flag has a non-empty argument.
# Arguments:
#   $1: The flag name (e.g. --name).
#   $2: The argument value (if present).
# Exits with error if the value is missing, empty, or looks like another flag.
require_arg() {
  if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]] || [[ "${2:0:1}" == "-" ]]; then
    log "Error: $1 requires a value."
    log "Run 'bootstrap.sh --help' for usage information."
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)    YES_MODE=true; shift ;;
    --name)      require_arg "$@"; DEV_NAME="$2"; shift 2 ;;
    --email)     require_arg "$@"; DEV_EMAIL="$2"; shift 2 ;;
    --gh)        require_arg "$@"; GH_USER="$2"; shift 2 ;;
    --db)        require_arg "$@"; DB_CHOICE="$2"; shift 2 ;;
    --shell)     require_arg "$@"; SHELL_CHOICE="$2"; shift 2 ;;
    --editor)    require_arg "$@"; EDITOR_CHOICE="$2"; shift 2 ;;
    --help|-h)
      cat <<'USAGE'
Usage: bootstrap.sh [OPTIONS]

Options:
  --yes, -y         Non-interactive mode (skip confirmation prompt)
  --name NAME       Full name for Git configuration
  --email EMAIL     Email address for Git configuration
  --gh USERNAME     GitHub username
  --db DB           Database choice (postgresql|mysql|mongodb|skip)
  --shell SHELL     Preferred shell (bash|zsh)
  --editor EDITOR   Preferred editor (vim|nano|code)
  --help, -h        Show this help message
USAGE
      exit 0
      ;;
    *)
      log "Error: Unknown option: $1"
      log "Run 'bootstrap.sh --help' for usage information."
      exit 1
      ;;
  esac
done

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

  if [[ "$YES_MODE" != true ]]; then
    read -r -p "Proceed with installation? (y/N): " CONFIRM
    [[ "${CONFIRM,,}" == "y" ]] || exit 0
  fi

  detect_pkg_manager
  pre_flight_checks

  # Collect user info
  if ! is_done "userinfo"; then
    [[ -z "$DEV_NAME" ]] && read -r -p "Enter your full name: " DEV_NAME
    [[ -z "$DEV_EMAIL" ]] && read -r -p "Enter your email address: " DEV_EMAIL
    [[ -z "$GH_USER" ]] && read -r -p "Enter your GitHub username: " GH_USER
    [[ -z "$SHELL_CHOICE" ]] && read -r -p "Choose your shell [bash/zsh]: " SHELL_CHOICE
    [[ -z "$EDITOR_CHOICE" ]] && read -r -p "Choose your editor [vim/nano/code]: " EDITOR_CHOICE

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
        ensure_brew
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
        ensure_brew
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
        ensure_brew
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
    set +u
    source "$HOME/.sdkman/bin/sdkman-init.sh" || true
    set -u
    sdk install springboot || true
    mark_done "java"
  fi

  # Docker
  if ! is_done "docker"; then
    log "Installing Docker..."
    case "$PKG_MANAGER" in
      brew)
        ensure_brew
        brew install --cask docker
        log "Open Docker Desktop once to finalize installation."
        ;;
      apt)
        # Remove legacy Docker packages if present
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
          sudo apt remove -y "$pkg" 2>/dev/null || true
        done
        # Install prerequisites for Docker's official repository
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg
        # Detect distro for Docker repo URL (ubuntu or debian)
        # shellcheck source=/dev/null
        DOCKER_DISTRO="$(. /etc/os-release && echo "$ID")"
        case "$DOCKER_DISTRO" in
          ubuntu|debian) ;;
          *) log "Warning: Unsupported distro '$DOCKER_DISTRO' for Docker official repo. Attempting with 'ubuntu'."; DOCKER_DISTRO="ubuntu" ;;
        esac
        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        # Add Docker's official APT repository
        # shellcheck source=/dev/null
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        # Install Docker CE, CLI, containerd, and Compose V2 plugin
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$USER"
        log "Docker installed. Log out and back in for group membership to take effect."
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
    [[ -z "$DB_CHOICE" ]] && read -r -p "Choose DB [postgresql/mysql/mongodb/skip]: " DB_CHOICE
    case "$DB_CHOICE" in
      postgresql)
        case "$PKG_MANAGER" in
          apt) sudo apt install -y postgresql postgresql-contrib;;
          dnf) sudo dnf install -y postgresql-server postgresql-contrib;;
          pacman) sudo pacman -S --noconfirm postgresql;;
          brew) ensure_brew; brew install postgresql@17 && brew services start postgresql@17;;
        esac
        ;;
      mysql)
        case "$PKG_MANAGER" in
          apt) sudo apt install -y mysql-server;;
          dnf) sudo dnf install -y community-mysql-server;;
          pacman) sudo pacman -S --noconfirm mariadb;;
          brew) ensure_brew; brew install mysql && brew services start mysql;;
        esac
        ;;
      mongodb)
        case "$PKG_MANAGER" in
          apt)
            log "Configuring MongoDB's official apt repository..."
            # shellcheck source=/dev/null
            distro="$(. /etc/os-release && echo "$ID")"
            # shellcheck source=/dev/null
            codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
            case "$distro" in
              ubuntu|pop|mint)
                distro="ubuntu"
                if [[ "$codename" == "noble" ]]; then
                  codename="jammy"
                fi
                ;;
              debian|raspbian)
                distro="debian"
                ;;
              *)
                log "Warning: Distro '$distro' not officially supported for MongoDB repo. Defaulting to Ubuntu/Jammy."
                distro="ubuntu"
                codename="jammy"
                ;;
            esac
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/mongodb-server-7.0.gpg
            sudo chmod a+r /etc/apt/keyrings/mongodb-server-7.0.gpg
            echo "deb [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/${distro} ${codename}/mongodb-org/7.0 multiverse" | \
              sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null
            sudo apt update
            sudo apt install -y mongodb-org
            ;;
          dnf) sudo dnf install -y mongodb-org;;
          pacman) sudo pacman -S --noconfirm mongodb-bin;;
          brew) ensure_brew; brew tap mongodb/brew && brew install mongodb-community && brew services start mongodb-community;;
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
        ensure_brew
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
    KEY_PATH="$HOME/.ssh/id_ed25519"
    if [[ -f "$KEY_PATH" ]]; then
      log "SSH key already exists at $KEY_PATH — skipping generation."
    else
      log "Generating SSH key..."
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      ssh-keygen -t ed25519 -C "$DEV_EMAIL ($GH_USER)" -f "$KEY_PATH" -N ""
    fi
    # Display public key — regenerate from private key if .pub is missing
    if [[ ! -r "${KEY_PATH}.pub" ]] && [[ -f "$KEY_PATH" ]]; then
      log "Public key file missing. Regenerating from private key..."
      ssh-keygen -y -f "$KEY_PATH" > "${KEY_PATH}.pub"
      chmod 644 "${KEY_PATH}.pub"
    fi
    if [[ -r "${KEY_PATH}.pub" ]]; then
      log "Public key:"
      cat "${KEY_PATH}.pub"
      log "Add this key to GitHub/GitLab (Settings → SSH keys)."
    else
      log "Warning: Could not read public key at ${KEY_PATH}.pub — add it manually."
    fi
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
