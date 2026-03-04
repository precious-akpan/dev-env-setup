# Dev Environment Setup

[![Lint Installers](https://github.com/precious-akpan/dev-env-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/precious-akpan/dev-env-setup/actions/workflows/lint.yml)


Welcome! This repository provides a production-grade onboarding process to set up a consistent fullstack developer environment across macOS, Linux, and Windows. The installers are curl/PowerShell-based, interactive, resumable, and idempotent.

---

## Overview

- Java: Pinned version (default: 17)
- Node.js: Pinned version (default: 20)
- Core tools: Git, curl/wget, build-essential, Python3, tmux, zsh/bash
- Containers: Docker (Docker Desktop on macOS/Windows)
- Databases: PostgreSQL / MySQL / MongoDB (optional)
- Editors: VS Code + extensions, JetBrains IntelliJ IDEA (Community Edition)
- DevOps: Git config, SSH key generation, Docker group membership (Linux)
- **Flexibility**: Easily change versions or packages via script variables.
- **Consistency**: Mandatory pre-flight checks and system manifest generation.
- **Resumability**: Checkpointing via state file and idempotent steps.
- **Logging**: `~/.devsetup.log` (Linux/macOS), `%USERPROFILE%\.devsetup_win.log` (Windows)

---

## Core Philosophy: Consistency with Flexibility

This project is built on two primary principles:

1. **Organizational Consistency**: Eliminate "it works on my machine" issues. By pinning versions of Node.js, Java, and other core tools at the top of the scripts, every developer in your organization builds with the identical stack.
2. **Easy Customizability**: While we provide sensible defaults, the scripts are designed to be modified. Organizations can easily change version variables, or add/remove packages in the logic to suit their specific internal requirements.

---

## Prerequisites

- Stable internet connection and sufficient disk space
- Administrative privileges (sudo on Linux/macOS; elevated PowerShell on Windows)
- Company VPN/SSO access if required by policy
- IT approval for installing developer tooling

---

## Usage

### macOS / Linux

Interactive (recommended):
```bash
curl -fsSL https://raw.githubusercontent.com/precious-akpan/dev-env-setup/main/bootstrap.sh | bash
```

Non-interactive with flags:
```bash
bash bootstrap.sh --yes \
  --name "Your Name" \
  --email "you@example.com" \
  --gh yourgithub \
  --db postgresql \
  --shell zsh \
  --editor code
```
---
### Windows
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/precious-akpan/dev-env-setup/main/bootstrap.ps1 | iex
```

Non-interactive with parameters
```powershell
.\bootstrap.ps1 -Yes -Name "Your Name" -Email "you@example.com" -GitHub "yourgithub" -Db postgresql -Editor code
```
---
### Interactive Prompts
During the run, you’ll be asked to provide:

- Full name and email (for Git configuration)
- GitHub username (for SSH key comment and guidance)
- Preferred shell (bash/zsh)
- Preferred editor (vim/nano/code)
- Database choice (PostgreSQL/MySQL/MongoDB/skip)

In non‑interactive mode, provide these via flags/parameters.

---
### 🔄 Checkpointing & Resumability
The installer records completed steps in a state file:

- macOS/Linux → `~/.devsetup_state`
- Windows → `%USERPROFILE%\.devsetup_state_win`

If interrupted (e.g., laptop powers down, network drops), rerun the same command — the script resumes from the last successful step.

All steps are idempotent and safe to re‑run.

### ✅ Verification
After installation, verify key tools:
```
bash
java -version
mvn -v
gradle -v
spring --version
node -v && npm -v
docker --version
code --version
```

---

### 🛠️ Troubleshooting

#### Permission issues (Linux/macOS):

Use sudo where required; ensure your user is added to the docker group.

Re‑login or restart your terminal after installation to apply shell changes and docker group membership.

#### Network interruptions:

Just rerun the command; scripts have retries and checkpoints.

#### VS Code extensions not installing:

Ensure code is on PATH. Open VS Code once, then rerun the extension step.

#### Logs:

- macOS/Linux → `~/.devsetup.log`
- Windows → `%USERPROFILE%\.devsetup_win.log`

### 🔐 Security Notes
SSH keys are generated locally and displayed so you can add them to GitHub/GitLab (Settings → SSH keys).

If your organization uses VPN/SSO, complete those steps first or as directed by IT.

Ensure endpoint security (BitLocker/FileVault, antivirus) is enabled per company policy.

### 📚 Next Steps
Add your SSH public key to GitHub/GitLab.

Open Docker Desktop once (macOS/Windows).

Clone your team’s sample project and run:

```
npm install for frontend dependencies

mvn test for Java unit tests

docker compose up for local services
```

For deeper onboarding (services architecture, secrets access, environment variables), refer to internal documentation (Confluence/Notion).

---

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to get started, report bugs, or suggest features.

All participants are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).
