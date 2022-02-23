<# Script written 26/04/2021 by Gareth Pullen
Checks the network interfaces to see:
1) If the IP matches one of our range
2) If it is a "Fortinet" connection - VPN, sets this as Private too to ensure correct profile for it.
3) If it is listed as Public or Private
If it is on our range, not the VPN and Public, marks it as Private.
#>

#Array of known IP ranges.
$IPRange = @(
    "XXX.XXX.XXX.*"
    "XXX.XXX.XXX.*"
)

$domain = "domain.fqdn.suffix"

if (Test-Connection $domain -Quiet) {
#Only bother running the rest of the script if we can access the domain.
    $NetInfo = Get-NetIPConfiguration | 
    Select-Object @{n = 'IP'; e = { $_.IPv4Address } },
    @{n = 'Name'; e = { $_.NetProfile.Name } },
    @{n = 'Status'; e = { $_.NetAdapter.Status } },
    @{n = 'Description'; e = { $_.InterfaceDescription } }

    Foreach ($Network in $NetInfo) {
        if ($Network.Status -eq "Up" -And $Network.Description -notmatch "Fortinet") {
            Foreach ($Range in $IPRange) {
                If ($Network.IP -like $Range) {
                    if ((Get-NetConnectionProfile -Name $Network.Name | Select-Object NetworkCategory) -match "Public") {
                        #Network IP is in our range, but is set as Public - Change it to Private.
                        Set-NetConnectionProfile -Name $Network.Name -NetworkCategory Private
                    } 
                }
            }
        }
        elseif ($Network.Status -eq "Up" -And $Network.Description -match "Fortinet") {
            If ((Get-NetConnectionProfile -Name $Network.Name | Select-Object NetworkCategory) -match "Public") {
                #We want the VPN connection to be Private so it has the correct rules applied to it too.
                Set-NetConnectionProfile -Name $Network.Name -NetworkCategory Private
            }
            
        }
    }
}
Else {
    Throw "Failed to contact domain"
}