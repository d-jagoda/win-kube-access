Set-Location $PSScriptRoot 

Write-Host "Setting up access Kubernetes on Docker Desktop from Windows"

Write-Host "1. Adding Windows Routing Rules and Setting (Run as Administrator)"

Start-Process -FilePath "powershell" -Verb RunAs -Wait -ArgumentList "-Command { cd ""$PSScriptRoot""; .\add-win-routes.ps1; .\add-win-dns.ps1 }.Invoke()"

Write-Host "2. Adding win-auto-start.ps1 as a startup script"
 New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Win-Kube-Access" `
  -Value "powershell.exe -Command { Start-Process -FilePath powershell -ArgumentList '-File ""$PSScriptRoot\win-auto-start.ps1"" -NoProfile' -WindowStyle hidden }.Invoke()" `
  -Force `
  -Confirm

Write-Host "3. Running win-auto-start.ps1 to add routing to docker-desktop distibution in WSL"
Start-Process -FilePath "powershell" -ArgumentList "-File ""$PSScriptRoot\win-auto-start.ps1"" -NoProfile" -WindowStyle hidden