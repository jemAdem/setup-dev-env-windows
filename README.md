# init-dev-project (Windows)

This is a Windows bootstrapper that mirrors the Linux script `init-dev-project.sh` from https://github.com/jemAdem/setup-dev-env. It creates a `Developer` folder structure and can optionally scaffold a Java Gradle project with Checkstyle and Spotless.

## Script
- `init-dev-project.ps1` (PowerShell): Recommended and supported. It avoids CMD quoting/parentheses issues and provides a reproducible experience.

## Prerequisites
- Git for Windows (including Git Bash; needed for the pre-commit hook)
- PowerShell (Windows PowerShell is available by default; PowerShell 7 is recommended)
- Optional: Gradle (for generating the Gradle Wrapper)
- Optional: VS Code with the `code` CLI in PATH

## Quick Start (PowerShell)
- Recommended (reproducible, no profiles): `pwsh -NoProfile -File .\\init-dev-project.ps1`
- Windows PowerShell (if PS7 not available): `powershell -ExecutionPolicy Bypass -File .\\init-dev-project.ps1`
- Direct execution vs explicit engine:
  - `./init-dev-project.ps1` runs in the current host (Windows PowerShell or PowerShell 7) using your loaded profiles, aliases and modules.
  - `pwsh -NoProfile -File .\\init-dev-project.ps1` starts PowerShell 7 in a clean session without profiles for reproducible setup.
- If ExecutionPolicy blocks scripts, use one of the Bypass commands above for a one-shot run.

## Usage (prompts)
When the script runs, you will be asked for:
- `project_name`: The new project name
- `folder`: Target subfolder under `%USERPROFILE%\\Developer` (default: `java`)
- `template`: `java-gradle` (default) or `none`

## Project location
- Projects are created under `%USERPROFILE%\\Developer\\<folder>\\<project_name>`
- The script also creates (if missing):
  - Base structure: `%USERPROFILE%\\Developer\\{shell,java,python,js,docker,archives,sandbox}`
  - Desktop shortcut: `Entwicklung.lnk` pointing to the `Developer` folder

## What gets generated (template: java-gradle)
- Java source structure: `src/main/java`, `src/test/java`
- Example code: `Main.java` (application) or `Library.java` (library) and `SampleTest.java`
- Build files: `build.gradle`, `settings.gradle`
- Configuration: `config/checkstyle/*`, `config/eclipse/*`
- VS Code: `.vscode/tasks.json`, `.vscode/launch.json`, `.vscode/settings.json`
- Git: `README.md`, `.gitignore`, `LICENSE` (empty), pre-commit hook (`.git/hooks/pre-commit` runs `spotlessApply` if `gradlew` exists)
- Gradle Wrapper: generated if `gradle` is installed on your system

## Notes
- VS Code: If the `code` CLI is not found, you can enable it in VS Code via “Shell Command: Install 'code' command in PATH”.
- Library projects: No runnable `Main` class is generated. The VS Code launch configuration becomes useful once you add your own main class.
- Pre-commit hook: It is a `sh` script and runs under Git Bash (installed with Git for Windows). If Git Bash is unavailable, the hook is skipped.
- Reliability: Prefer the PS1 variant on Windows. It writes all files safely (including Java `import` lines) and avoids CMD parentheses/quoting pitfalls.

## Remove / Cleanup
- Delete the project folder under `%USERPROFILE%\\Developer`.
- Delete the `Entwicklung.lnk` desktop shortcut if created.

## Differences vs. Linux version
- Desktop link: On Windows, a `.lnk` shortcut is created (not a symlink).
- Shell implementation: Some content is written via PowerShell here-strings on Windows.
