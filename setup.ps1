# Run this script for one-time configuration of the Windows with routing rules, DNS settings and startup scripts

Set-Location $PSScriptRoot

Write-Host "Setting up access Kubernetes on Docker Desktop from Windows"

Write-Host "Checking Windows routing rules"
$routes = @("10.1.0.0/16", "10.96.0.0/12")
$existingRoutes = Get-NetRoute
$addRoutingRules = $false

foreach ($route in $routes) {
    if (-not ($existingRoutes | Where-Object DestinationPrefix -eq $route)) {
        $addRoutingRules = $true
        break
    }
}

$adminScripts = ""
if ($addRoutingRules) {
    $adminScripts = ".\add-win-routes.ps1"
}

Write-Host "Checking DNS Client NRPT rule for .cluster.local"
$nrptRule = Get-DnsClientNrptRule | Where-Object Namespace -eq ".cluster.local"
if ($null -eq $nrptRule) {
    $adminScripts += "; .\add-win-dns.ps1"
}

if ($adminScripts -ne "") {
    Write-Host "Configuring routing rules or DNS client rules (Run as Administrator)"
    Start-Process -FilePath "powershell" -Verb RunAs -Wait -ArgumentList "-Command { cd ""$PSScriptRoot""; $adminScripts }.Invoke()"
}


Write-Host "Adding win-auto-start.ps1 as a startup script"
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "Win-Kube-Access" `
    -Value "powershell.exe -Command { Start-Process -FilePath powershell -ArgumentList '-File ""$PSScriptRoot\docker-engine-monitor.ps1"" -NoProfile' -WindowStyle hidden }.Invoke()" `
    -Force `

$mngmtClass = [System.Management.ManagementClass]::new("Win32_Process")
$dockerEngineMonitor = $mngmtClass.GetInstances() | Where-Object { $_.Name -eq "powershell.exe" -and  $_.CommandLine -ne $null -and $_.CommandLine.Contains("docker-engine-monitor.ps1") }

if ($null -eq $dockerEngineMonitor) {
    Write-Host "Running docker-engine-monitor.ps1 to add routing to docker-desktop distibution in WSL"
    Start-Process -FilePath "powershell" -ArgumentList "-File ""$PSScriptRoot\docker-engine-monitor.ps1"" -NoProfile" -WindowStyle hidden
}