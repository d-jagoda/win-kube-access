#Requires -RunAsAdministrator

# Adds a Name Resolution Policy Table (NRPT) rule to forward DNS queries for .cluster.local suffix to CoreDNS in local kubernetes cluster

$coreDnsAddress = "10.96.0.10"
$dnsSuffix = ".cluster.local"

$nrptRule = Get-DnsClientNrptRule | Where-Object Namespace -eq $dnsSuffix

if ($null -eq $nrptRule) {
    Add-DnsClientNrptRule -Namespace $dnsSuffix -NameServers $coreDnsAddress -DisplayName "Win Kube Access Rule"
} else {
    Set-DnsClientNrptRule -Name $nrptRule.Name -Namespace $dnsSuffix -NameServers $coreDnsAddress -DisplayName "Win Kube Access Rule"
}