# wsl-screenshot-paste

Automatically paste Windows screenshot file paths into WSL terminals with `Ctrl+V`.

Take a screenshot with `Win+Shift+S`, switch to Windows Terminal, press `Ctrl+V` — the WSL file path is pasted instead of the image. Paste the image normally everywhere else (Teams, Word, browser, etc.).

---

## How it works

A lightweight PowerShell script runs in the background and intercepts `Ctrl+V` **only when Windows Terminal is the focused window** and the clipboard contains an image. It temporarily replaces the clipboard with the WSL file path, lets Windows Terminal paste it, then restores the original image — so you can still paste the image in other apps.

---

## Requirements

- Windows 10 or 11
- WSL2 with a Linux distro installed (Ubuntu recommended)
- [Windows Terminal](https://aka.ms/terminal)
- Zsh (the setup script adds an entry to `~/.zshrc`)

---

## Setup

### Step 1 — Enable auto-save in Snipping Tool

This ensures screenshots are saved to a folder so the script can find the latest file path.

1. Open the **Snipping Tool** app (search in Start Menu)
2. Click the **three-dot menu (...)** → **Settings**
3. Turn on **"Automatically save screenshots"**

The default save folder is:
```
C:\Users\<your-username>\Pictures\Screenshots
```

> **Using a different folder?** Edit `$ScreenshotsDir` at the top of `screenshot-watcher.ps1` and `cleanup-screenshots.ps1` before running setup.

---

### Step 2 — Clone and run setup

Open your **WSL terminal** and run:

```bash
git clone https://github.com/Elwinc2799/wsl-screenshot-paste.git
cd wsl-screenshot-paste
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Copy the PowerShell scripts to a local Windows path (required to bypass the `RemoteSigned` execution policy on WSL network paths)
- Register a **Windows Task Scheduler** job to auto-delete screenshots older than 12 hours
- Add an auto-start entry to your `~/.zshrc`

---

### Step 3 — Reload your shell

```bash
source ~/.zshrc
```

The watcher is now running and will auto-start on every new terminal session.

---

## Usage

| Action | Result |
|--------|--------|
| `Win+Shift+S` → `Ctrl+V` in Windows Terminal | Pastes the WSL file path, e.g. `/mnt/c/Users/you/Pictures/Screenshots/Screenshot_xyz.png` |
| `Ctrl+V` anywhere else (Teams, Word, browser) | Pastes the image normally — unchanged |
| Copy text → `Ctrl+V` in Windows Terminal | Pastes the text normally — unchanged |

You can press `Ctrl+V` multiple times in the terminal to paste the same path again. Once you copy something else (text or a new image), the interception resets.

---

## Auto-cleanup

Screenshots older than 12 hours are automatically deleted every 12 hours via Windows Task Scheduler. To change this, edit `cleanup-screenshots.ps1`:

```powershell
[int]$OlderThanHours = 12  # adjust as needed
```

Then re-run `./setup.sh` to update the scheduled task.

---

## Uninstall

```bash
# Remove the auto-start lines from .zshrc
sed -i '/# wsl-screenshot-paste/,+4d' ~/.zshrc

# Remove the scheduled task
powershell.exe -NoProfile -Command "Unregister-ScheduledTask -TaskName 'WSL Screenshot Cleanup' -Confirm:\$false"

# Remove the installed scripts
WIN_USER=$(powershell.exe -NoProfile -Command '$env:USERNAME' | tr -d '\r\n')
rm -rf "/mnt/c/Users/$WIN_USER/AppData/Local/wsl-screenshot-monitor"
```

---

## Troubleshooting

**Ctrl+V in the terminal pastes nothing**
- Confirm Snipping Tool auto-save is enabled (Step 1) and that screenshots are being saved to the expected folder.
- Reopen your terminal to trigger the auto-start, or run: `source ~/.zshrc`

**Ctrl+V still pastes the image instead of the path**
- Make sure Windows Terminal is the focused window (not a different terminal emulator).

**Watcher fails to start**
- Re-run `./setup.sh` to re-copy the scripts to the local Windows path.
