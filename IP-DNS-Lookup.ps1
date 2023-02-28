#Script to lookup IP Address DNS address - takes CSV input.
#Written 28/02/2023 by Gareth Pullen (grp43)

$IPList = Get-Content C:\Temp\IP-SMTP.csv

#Create Export Hashtable, set counter to 1
$Export = @{}
$count = 1

#Lookup IP to DNS
Foreach ($IP in $IPList) {
    #Write-Output $IP
    Try {
        $Name = (Resolve-DnsName -Name $IP -ErrorAction Stop).server
        #Erroraction required so it throws the error for Catch to apply.
    }
    Catch {
        $Name = "Error - not found"
        #No DNS record
    } 
    #Add key-pair to Hash Table
    $Export.Add($IP, $Name)
    #Write a Progress Bar!
    Write-Progress -Activity "Checking IP to DNS Names" -status "Checking Name for $IP" -PercentComplete ($count / $IPList.Count * 100)
    $count++
}
#Clear the progress bar
Write-Progress -Activity "Checking IP to DNS Names" -status "Ready" -Completed
#Write the results to a CSV file in the key-pair
$Export.GetEnumerator() | Select-Object -Property @{N='IP';E={$_.Key}},@{N='Hostname';E={$_.value}} | Export-CSV C:\Temp\smtp-hosts.csv -NoTypeInformation
