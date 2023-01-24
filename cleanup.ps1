# Run this script to clean up changes done by setup.ps1

Set-Location $PSScriptRoot

Write-Host "Cleaning up access to Kubernetes on Docker Desktop from Windows"

Write-Host "Checking Windows routing rules"
$routes = @("10.1.0.0/16", "10.96.0.0/12")
$existingRoutes = Get-NetRoute
$runAdminScripts = $false

foreach ($route in $routes) {
    if ($existingRoutes | Where-Object DestinationPrefix -eq $route) {
        $runAdminScripts = $true
        break
    }
}

Write-Host "Checking DNS Client NRPT rules"
$nrptRule = Get-DnsClientNrptRule | Where-Object DisplayName -eq "Win Kube Access Rule"
if ($null -ne $nrptRule) {
    $runAdminScripts = $true
}

if ($runAdminScripts) {
    Write-Host "Removing routing and DNS client rules (Run as Administrator)"
    Start-Process -FilePath "powershell" -Verb RunAs -Wait -ArgumentList "-File ""$PSScriptRoot\remove-win-rules.ps1"" }"
}

Write-Host "Removing startup scripts from Windows registry"
Remove-ItemProperty  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Win-Kube-Access" 

$mngmtClass = [System.Management.ManagementClass]::new("Win32_Process")
$dockerEngineMonitor = $mngmtClass.GetInstances() | Where-Object { $_.Name -eq "powershell.exe" -and  $_.CommandLine -ne $null -and $_.CommandLine.Contains("docker-engine-monitor.ps1") }

if ($null -ne $dockerEngineMonitor) {
    Write-Host "Stopping Docker Engine monitor script"
    Stop-Process -Id $dockerEngineMonitor.ProcessId
}

Write-Host "Removing network setup configured in WSL"
wsl.exe -d docker-desktop -u root ip link delete veth-kubeaccess