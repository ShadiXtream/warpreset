# Script to clean up files in AppData\Local\warp\Warp\data
# Script made to simplify automation. Will stop, delete logs, and re-run Warp

# Stops warp process
Stop-Process -Name "warp" -Force

# Sets target path to locate files
# Replace USER with your folder path
$targetPath = "C:\Users\USER\AppData\Local\warp\Warp\data"

# Removes sqllite files containing usage logs and analytics
Get-ChildItem -Path $targetPath -File | Where-Object { $_.Name -ne "warp.sqlite" } | Remove-Item -Force

# Sets location for warp to re-run file
# Replace with your filepath
Set-Location "C:\Program Files\Warp\"
Start-Process ".\warp.exe"