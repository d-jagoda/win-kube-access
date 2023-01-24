#Requires -RunAsAdministrator

# Remove routing rules
$routesToRemove = @("10.1.0.0/16", "10.96.0.0/12")
$wslAdapter = Get-NetAdapter -name "vEthernet (WSL)"

Get-NetRoute | 
    Where-Object AddressFamily -eq IPv4 | 
    Where-Object { $_.ifIndex -eq $wslAdapter.ifIndex -and $routesToRemove.Contains($_.DestinationPrefix)} |
    ForEach-Object {
        Remove-NetRoute -DestinationPrefix $_.DestinationPrefix -InterfaceIndex $_.ifIndex
    }

# Remove Resolution Policy Table (NRPT) rule
$ruleName = "Win Kube Access Rule"
$nrptRule = Get-DnsClientNrptRule | Where-Object DisplayName -eq $ruleName

if ($null -ne $nrptRule) {
    Remove-DnsClientNrptRule -Name $nrptRule.Name
}