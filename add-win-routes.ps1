#Requires -RunAsAdministrator

$routesToAdd = @("10.1.0.0/16", "10.96.0.0/12")
$existingRoutes = Get-NetRoute
$wslAdapter = Get-NetAdapter -name "vEthernet (WSL)"

foreach ($route in $routesToAdd) {
  if (-not ($existingRoutes | Where-Object DestinationPrefix -eq $route)) {
     New-NetRoute -DestinationPrefix $route -InterfaceIndex $wslAdapter.ifIndex
   }
}
