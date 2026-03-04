# Contributing to Dev Environment Setup

Welcome! We are excited that you want to contribute to the Dev Environment Setup project. Our goal is to provide a consistent yet flexible environment for developers across all major platforms.

## How to Contribute

### Reporting Bugs
- Use the **Bug Report** template when creating an issue.
- Provide a clear description of the problem and your environment (OS, shell, etc.).
- Include logs from `~/.devsetup.log` (macOS/Linux) or `%USERPROFILE%\.devsetup_win.log` (Windows) if relevant.

### Suggesting Enhancements
- Use the **Feature Request** template.
- Explain why the enhancement would be useful for the community or organizations.

### Pull Requests
1. Fork the repository.
2. Create a new branch for your change (e.g., `feat/add-rust-support` or `fix/pacman-java-version`).
3. Ensure your scripts are linted:
   - Bash: Use `shellcheck`.
   - PowerShell: Use `PSScriptAnalyzer`.
4. Submit your PR with a clear description of the changes.

## Core Philosophy: Consistency with Flexibility
When contributing new scripts or tools:
- **Pin Versions**: Ensure that versions can be easily pinned via variables.
- **Support Multiple Distros**: If adding a Linux feature, try to support `apt`, `dnf`, and `pacman`.
- **Idempotency**: Ensure that running the script multiple times is safe.

Thank you for helping us build a better onboarding experience!
