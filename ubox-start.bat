@echo off
rem Entry point for the player — do not launch ubox.exe directly.
rem Checks the player and every enabled node against their CDN manifests,
rem updates whatever's stale, then starts ubox.exe.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ubox-update.ps1"
