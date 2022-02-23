#Written by Gareth Pullen 03/05/2021 to add the "Support-Team" and "CSCS-AdminRights-ClientPcs" groups to devices, to grant local admin
#Is uploaded to Intune > Scripts to run on all Autopilot devices.
#Updated 04/10/2021 to check if the groups alread exist, to avoid it failing.
#Updated 02/2022 to remove identifying info prior to upload
$SupportTeam = $true
$CSCSAdminRightsClientPcs = $true

foreach ($group in Get-LocalGroup -Name "Administrators") {
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % { ([adsi]$_).path }) -Split "WinNT://"
}
foreach ($group in $group_members) {
    if ($group -match "S-1-12-1-<Sanitized>") {
        #The group above is the SID of the Intune Users group.
        $SupportTeam = $false  
        #If the group is matched, make this variable False as we don't need to add it again.
    }
    if ($group -match "S-1-12-1-<Sanitized>") {
        $CSCSAdminRightsClientPcs = $false
    }
}
If ($SupportTeam -eq $true) {
    Add-LocalGroupMember -Group Administrators -Member "S-1-12-1-<Sanitized>"
}
If ($CSCSAdminRightsClientPcs -eq $true) {
    Add-LocalGroupMember -Group Administrators -Member "S-1-12-1-<Sanitized>"
}