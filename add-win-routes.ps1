#Requires -RunAsAdministrator

# Adds routing rules to forward traffic IP packets targetting POD and Service IP addresses via WSL virtual eithernet adapter

$routesToAdd = @("10.1.0.0/16", "10.96.0.0/12")
$existingRoutes = Get-NetRoute
$wslAdapter = Get-NetAdapter -name "vEthernet (WSL)"

foreach ($route in $routesToAdd) {
    if (-not ($existingRoutes | Where-Object DestinationPrefix -eq $route)) {
        New-NetRoute -DestinationPrefix $route -InterfaceIndex $wslAdapter.ifIndex
    }
}