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


# Adds a Name Resolution Policy Table (NRPT) rule to forward DNS queries for .cluster.local suffix to CoreDNS in local kubernetes cluster

$coreDnsAddress = "10.96.0.10"
$dnsSuffix = ".cluster.local"
$ruleName = "Win Kube Access Rule"

$nrptRule = Get-DnsClientNrptRule | Where-Object DisplayName -eq $ruleName

if ($null -eq $nrptRule) {
    Add-DnsClientNrptRule -Namespace $dnsSuffix -NameServers $coreDnsAddress -DisplayName $ruleName
} else {
    Set-DnsClientNrptRule -Name $nrptRule.Name -Namespace $dnsSuffix -NameServers $coreDnsAddress -DisplayName $ruleName
}