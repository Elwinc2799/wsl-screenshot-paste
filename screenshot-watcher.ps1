param(
    [string]$ScreenshotsDir = "$env:USERPROFILE\Pictures\Screenshots"
)

Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ScreenshotKeyInterceptor : IDisposable {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int VK_V = 0x56;
    private const int VK_CONTROL = 0x11;

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int id, LowLevelKeyboardProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] private static extern short GetKeyState(int vk);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private readonly LowLevelKeyboardProc _proc;
    private readonly IntPtr _hookId;
    private readonly string _screenshotDir;

    public ScreenshotKeyInterceptor(string screenshotDir) {
        _screenshotDir = screenshotDir;
        _proc = HookCallback;
        using (var p = Process.GetCurrentProcess())
        using (var m = p.MainModule)
            _hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(m.ModuleName), 0);
    }

    private bool IsWindowsTerminalFocused() {
        IntPtr hwnd = GetForegroundWindow();
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        try { return Process.GetProcessById((int)pid).ProcessName.IndexOf("WindowsTerminal", StringComparison.OrdinalIgnoreCase) >= 0; }
        catch { return false; }
    }

    private string GetLatestScreenshotWslPath() {
        var dir = new DirectoryInfo(_screenshotDir);
        if (!dir.Exists) return null;
        FileInfo latest = null;
        foreach (var f in dir.GetFiles("*.png"))
            if (latest == null || f.LastWriteTime > latest.LastWriteTime)
                latest = f;
        if (latest == null) return null;
        char drive = char.ToLower(latest.FullName[0]);
        string rest = latest.FullName.Substring(2).Replace('\\', '/');
        return "/mnt/" + drive + rest;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vk = Marshal.ReadInt32(lParam);
            bool ctrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            if (vk == VK_V && ctrl && IsWindowsTerminalFocused() && Clipboard.ContainsImage()) {
                var path = GetLatestScreenshotWslPath();
                if (path != null) {
                    Image savedImage = Clipboard.GetImage();
                    Clipboard.SetText(path);

                    // Restore the original image after Windows Terminal has pasted the path
                    if (savedImage != null) {
                        var timer = new System.Windows.Forms.Timer();
                        timer.Interval = 500;
                        timer.Tick += (s, e) => {
                            timer.Stop();
                            timer.Dispose();
                            Clipboard.SetImage(savedImage);
                            savedImage.Dispose();
                        };
                        timer.Start();
                    }
                }
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    public void Dispose() { UnhookWindowsHookEx(_hookId); }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

$watcher = [ScreenshotKeyInterceptor]::new($ScreenshotsDir)
Write-Host "wsl-screenshot-paste: running. Ctrl+V in Windows Terminal with a screenshot in clipboard will paste the WSL file path."
[System.Windows.Forms.Application]::Run()
$watcher.Dispose()
