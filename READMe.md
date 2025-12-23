# Dev Environment Setup

Welcome! This repository provides a production-grade onboarding process to set up a consistent fullstack developer environment across macOS, Linux, and Windows. The installers are curl/PowerShell-based, interactive, resumable, and idempotent.

---

## Overview

The bootstrap scripts install:

- Core tools: Git, curl/wget, build-essential, Python3, tmux, zsh/bash
- Frontend: Node.js (LTS), npm/yarn/pnpm
- Backend: OpenJDK 17, Maven, Gradle, Spring Boot CLI
- Containers: Docker (Docker Desktop on macOS/Windows)
- Databases: PostgreSQL / MySQL / MongoDB (optional)
- Editors: VS Code + extensions, JetBrains IntelliJ IDEA (Community Edition)
- DevOps: Git config, SSH key generation, Docker group membership (Linux)
- Resumability: Checkpointing via state file and idempotent steps
- Logging: `~/.devsetup.log` (Linux/macOS), `%USERPROFILE%\.devsetup_win.log` (Windows)

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
curl -fsSL https://raw.githubusercontent.com/<your-org>/dev-env-setup/main/bootstrap.sh | bash
