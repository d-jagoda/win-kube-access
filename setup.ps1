# Run this script for one-time configuration of the Windows with routing rules, DNS settings and startup scripts

Set-Location $PSScriptRoot

Write-Host "Setting up access to Kubernetes on Docker Desktop"

Write-Host "Checking Windows routing rules"
$routes = @("10.1.0.0/16", "10.96.0.0/12")
$existingRoutes = Get-NetRoute
$runAdminScripts = $false

foreach ($route in $routes) {
    if (-not ($existingRoutes | Where-Object DestinationPrefix -eq $route)) {
        $runAdminScripts = $true
        break
    }
}

Write-Host "Checking DNS Client NRPT rules"
$nrptRule = Get-DnsClientNrptRule | Where-Object DisplayName -eq "Win Kube Access Rule"
if ($null -eq $nrptRule) {
    $runAdminScripts = $true
}

if ($runAdminScripts) {
    Write-Host "Configuring routing and DNS client rules (Run as Administrator)"
    Start-Process -FilePath "powershell" -Verb RunAs -Wait -ArgumentList "-File ""$PSScriptRoot\add-win-rules.ps1"" }"
}

Write-Host "Adding docker-engine-monitor.ps1 as a startup script"
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "Win-Kube-Access" `
    -Value "powershell.exe -Command .{ Start-Process -FilePath powershell -ArgumentList '-Command .{ . $PSScriptRoot\docker-engine-monitor.ps1 *^>^&1 ^> $env:TEMP\win-kube-access-startup.log } -NoProfile' -WindowStyle hidden }" `
    -Force `

$mngmtClass = [System.Management.ManagementClass]::new("Win32_Process")
$dockerEngineMonitor = $mngmtClass.GetInstances() | Where-Object { $_.Name -eq "powershell.exe" -and  $_.CommandLine -ne $null -and $_.CommandLine.Contains("docker-engine-monitor.ps1") }

if ($null -eq $dockerEngineMonitor) {
    Write-Host "Running docker-engine-monitor.ps1 to add routing to docker-desktop distibution in WSL"
    Start-Process -FilePath "powershell" -ArgumentList "-File ""$PSScriptRoot\docker-engine-monitor.ps1"" -NoProfile" -WindowStyle hidden
}