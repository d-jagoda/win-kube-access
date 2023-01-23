#Requires -RunAsAdministrator

function ConfirmChoice {
    param (
        [string] [Parameter(Mandatory=$true)] $message
    )

    $choice = $Host.UI.PromptForChoice($null, $message, @("&Yes", "&No"), 0)
    return $choice -eq 0
}

$coreDnsAddress = "10.96.0.10"

$adapter = Get-NetIPInterface | Where-Object ConnectionState -eq Connected | Where-Object AddressFamily -eq IPv4 | Sort-Object InterfaceMetric | Select-Object -First 1

while ($true) {
    if ($null -eq $adapter) {
        Write-Host "Could not find an appropriate network interface to set DNS servers on."
    } else {
        if (-not (ConfirmChoice `
        "DNS servers will be set on interface '$($adapter.InterfaceAlias)' with IfIndex $($adapter.ifIndex). Do you want to continue with this interface?")) {
            $adapter = $null
        }
    }

    if ($null -eq $adapter) {
        Get-NetIPInterface | Where-Object ConnectionState -eq Connected | Where-Object AddressFamily -eq IPv4

        Write-Host
        $selectedIfIndex = [int](Read-Host -Prompt "Enter the ifIndex of the selected interface or 0 to quit")

        if ($selectedIfIndex -eq 0) {
            break
        }

        $adapter = Get-NetIPInterface | Where-Object ifIndex -eq $selectedIfIndex
        continue
    }

    $dnsAddresses = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex).ServerAddresses
    if ($dnsAddresses.Contains($coreDnsAddress)) {
        Write-Host "DNS server $coreDnsAddress has already been added"
        break;
    } else {
        $dnsAddresses += @($coreDnsAddress)
    }
    
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsAddresses
    if ($?) {
        break;
    }
}