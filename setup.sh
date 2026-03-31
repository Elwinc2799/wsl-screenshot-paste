#!/bin/bash
set -e

MARKER="# wsl-screenshot-paste"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== wsl-screenshot-paste setup ==="
echo ""

# Detect Windows username
WIN_USER=$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n')
if [ -z "$WIN_USER" ]; then
    echo "ERROR: Could not detect Windows username. Are you running this from WSL2?"
    exit 1
fi
echo "Detected Windows user: $WIN_USER"

WIN_INSTALL_DIR="/mnt/c/Users/$WIN_USER/AppData/Local/wsl-screenshot-monitor"

# Copy scripts to a local Windows path (required to bypass RemoteSigned execution policy)
echo "Copying scripts to $WIN_INSTALL_DIR ..."
mkdir -p "$WIN_INSTALL_DIR"
cp "$SCRIPT_DIR/screenshot-watcher.ps1" "$WIN_INSTALL_DIR/"
cp "$SCRIPT_DIR/cleanup-screenshots.ps1" "$WIN_INSTALL_DIR/"

# Register Task Scheduler to auto-start watcher on Windows login
echo "Registering watcher auto-start task in Windows Task Scheduler..."
powershell.exe -NoProfile -Command "
    \$action = New-ScheduledTaskAction \
        -Execute 'powershell.exe' \
        -Argument \"-Sta -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\Users\\$WIN_USER\AppData\Local\wsl-screenshot-monitor\screenshot-watcher.ps1'\"
    \$trigger = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME
    \$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
    Register-ScheduledTask -TaskName 'WSL Screenshot Watcher' -Action \$action -Trigger \$trigger -Settings \$settings -Force | Out-Null
    Write-Host 'Watcher task registered.'
" 2>/dev/null

# Register Task Scheduler to auto-clean screenshots every 12 hours
echo "Registering cleanup task in Windows Task Scheduler..."
powershell.exe -NoProfile -Command "
    \$action = New-ScheduledTaskAction \
        -Execute 'powershell.exe' \
        -Argument \"-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\Users\\$WIN_USER\AppData\Local\wsl-screenshot-monitor\cleanup-screenshots.ps1'\"
    \$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 12) -Once -At (Get-Date)
    \$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -StartWhenAvailable
    Register-ScheduledTask -TaskName 'WSL Screenshot Cleanup' -Action \$action -Trigger \$trigger -Settings \$settings -Force | Out-Null
    Write-Host 'Cleanup task registered.'
" 2>/dev/null

# Add auto-start snippet to .zshrc (skip if already present)
ZSHRC="$HOME/.zshrc"
if grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
    echo ".zshrc already configured, skipping."
else
    echo "Adding auto-start to $ZSHRC ..."
    cat >> "$ZSHRC" <<EOF

$MARKER
if ! powershell.exe -NoProfile -Command "Get-WmiObject Win32_Process | Where-Object { \\\$_.CommandLine -like '*screenshot-watcher*' } | Select-Object -First 1" 2>/dev/null | grep -q "powershell"; then
    powershell.exe -Sta -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass \\
        -File "C:\\\\Users\\\\$WIN_USER\\\\AppData\\\\Local\\\\wsl-screenshot-monitor\\\\screenshot-watcher.ps1" &>/dev/null &
fi
EOF
fi

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Enable auto-save in Snipping Tool:"
echo "     Open Snipping Tool > Settings > turn on 'Automatically save screenshots'"
echo "     Default save folder: C:\Users\\$WIN_USER\Pictures\Screenshots"
echo ""
echo "  2. Reload your shell:"
echo "     source ~/.zshrc"
echo ""
echo "Usage:"
echo "  - Take a screenshot with Win+Shift+S"
echo "  - Press Ctrl+V in Windows Terminal (Claude Code, ZSH, etc.)"
echo "  - The WSL file path is pasted automatically"
echo "  - Ctrl+V still works normally everywhere else"
