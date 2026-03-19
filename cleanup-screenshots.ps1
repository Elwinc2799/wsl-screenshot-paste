param(
    [string]$ScreenshotsDir = "$env:USERPROFILE\Pictures\Screenshots",
    [int]$OlderThanHours = 12
)

$cutoff = (Get-Date).AddHours(-$OlderThanHours)
Get-ChildItem -Path $ScreenshotsDir -Filter "*.png" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force
