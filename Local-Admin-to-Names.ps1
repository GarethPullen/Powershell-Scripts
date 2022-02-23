<# Script to get local Administrators groups and list the AzureAD group names from the SIDs
Written 30/03/2021 by Gareth Pullen (grp43)
#>

function Convert-AzureAdSidToObjectId {
<#
.SYNOPSIS
Convert a Azure AD SID to Object ID
 
.DESCRIPTION
Converts an Azure AD SID to Object ID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The SID to convert
#>

    param([String] $Sid)

    $text = $sid.Replace('S-1-12-1-', '')
    $array = [UInt32[]]$text.Split('-')

    $bytes = New-Object 'Byte[]' 16
    [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
    [Guid]$guid = $bytes

    return $guid
}

#Check if AzureAD Module is installed, install it if not.
try {
    get-installedmodule -name azuread -ErrorAction Stop |out-null
}
Catch {
    If ((get-psrepository -Name 'PSGallery').Trusted) {
        install-module -name AzureAD
    } Else {    
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        install-module -name AzureAD
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
    }
}

#Get the current user UPN - may avoid login prompt
$UPN = whoami /upn
#Connect to AzureAD (Prompts for login)
Try {
    if ($UPN -match "@med*") {
    #UPN is an AAD one, try to login with that.
        Connect-AzureAD -AccountId $UPN -EA SilentlyContinue | out-null
    }
    Else {
        Connect-AzureAD -EA SilentlyContinue | out-null
    }
}
Catch {
    Write-Output "Error Occurred:"
    Write-Output $_
    Exit
}

foreach ($group in Get-LocalGroup -Name "Administrators") {
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path}) -Split "WinNT://"
    }
$ADIDs = @()
foreach ($group in $group_members){
    if ($group -match "S-1-12-1"){
        $ADIDs += $group + " - " + (Get-AzureADObjectByObjectId -ObjectIds (Convert-AzureAdSidToObjectId($group))).DisplayName
    }  
}
if ($ADIDs -ne $Null){
Write-Host "AAD Groups: "
foreach ($ID in $ADIDs){
    Write-Host $ID
    }
}
