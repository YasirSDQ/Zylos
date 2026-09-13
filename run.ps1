# Zylos Dev Launcher
# Kills any stuck process first, then runs with a pinned debug port
# to avoid Windows Firewall blocking random VM service ports.

Write-Host "Stopping any running Zylos instance..." -ForegroundColor Cyan
taskkill /F /IM yt_downloader.exe /T 2>$null
Start-Sleep -Milliseconds 500

Write-Host "Launching Zylos in debug mode..." -ForegroundColor Green
flutter run -d windows --host-vmservice-port 8181
