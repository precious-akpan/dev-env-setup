#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.devsetup_state"
LOG_FILE="$HOME/.devsetup.log"
OS="$(uname -s)"

touch "$STATE_FILE" "$LOG_FILE"

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_FILE"; }
mark_done() { echo "$1" >> "$STATE_FILE"; }
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)    YES_MODE=true; shift ;;
    --name)      DEV_NAME="$2"; shift 2 ;;
    --email)     DEV_EMAIL="$2"; shift 2 ;;
    --gh)        GH_USER="$2"; shift 2 ;;
    --db)        DB_CHOICE="$2"; shift 2 ;;
    --shell)     SHELL_CHOICE="$2"; shift 2 ;;
    --editor)    EDITOR_CHOICE="$2"; shift 2 ;;
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

# Banner
cat <<'BANNER'
===============================================================
Fullstack Developer Environment Bootstrap (macOS/Linux)

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

# Ensure Homebrew (macOS only)
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
  if [[ "$OS" == "Darwin" ]]; then
    ensure_brew
    brew install git curl wget tmux zsh python
  else
    sudo apt update && sudo apt install -y git curl wget build-essential python3 python3-pip tmux zsh unzip
  fi
  mark_done "core"
fi

# Node.js
if ! is_done "node"; then
  log "Installing Node.js..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install node
    npm install -g yarn pnpm
  else
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g yarn pnpm
  fi
  mark_done "node"
fi

# Java + Spring Boot
if ! is_done "java"; then
  log "Installing Java stack..."
  if [[ "$OS" == "Darwin" ]]; then
    ensure_brew
    brew install openjdk@17 maven gradle
  else
    sudo apt install -y openjdk-17-jdk maven gradle
  fi
  curl -s https://get.sdkman.io | bash
  # shellcheck source=/dev/null
  set +u
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  set -u
  sdk install springboot
  mark_done "java"
fi

# Docker
if ! is_done "docker"; then
  log "Installing Docker..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install --cask docker
    log "Open Docker Desktop once to finalize installation."
  else
    sudo apt install -y docker.io docker-compose
    sudo usermod -aG docker "$USER"
  fi
  mark_done "docker"
fi

# Database choice
if ! is_done "db"; then
  read -r -p "Choose DB [postgresql/mysql/mongodb/skip]: " DB_CHOICE
  case "$DB_CHOICE" in
    postgresql) sudo apt install -y postgresql postgresql-contrib;;
    mysql) sudo apt install -y mysql-server;;
    mongodb) sudo apt install -y mongodb;;
    skip) ;;
  esac
  mark_done "db"
fi

# VS Code
if ! is_done "vscode"; then
  log "Installing VS Code..."
  if [[ "$OS" == "Darwin" ]]; then
    ensure_brew
    brew install --cask visual-studio-code
  else
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update && sudo apt install -y code
  fi
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
  log "Public key:"
  cat "${KEY_PATH}.pub"
  log "Add this key to GitHub/GitLab (Settings → SSH keys)."
  mark_done "ssh"
fi

log "✅ Setup complete! See $LOG_FILE for details."
