@echo off
setlocal
title Microsoft Game Runtimes Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Microsoft-Game-Runtimes.ps1"
endlocal
