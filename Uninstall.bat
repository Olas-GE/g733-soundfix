@echo off
rem Runs the uninstaller script (scripts\uninstall.ps1).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1"
