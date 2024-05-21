<# Script to get local Administrators groups and list the AzureAD group names from the SIDs
Written 30/03/2021 by Gareth Pullen (grp43)
Edited to not query for login if an Azure user is signed in
#Modified 21/05/2024 to try installing AzureAD scoped to Current User if not running as admin
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

#Check if we're running as admin - if not, install module as "Current User" scope
If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #True if running as admin, false if not
    $Admin = $true
}
Else {
    $Admin = $false
}

#Check if AzureAD Module is installed, install it if not.
try {
    get-installedmodule -name azuread -ErrorAction Stop | out-null
}
Catch {
    If ((get-psrepository -Name 'PSGallery').Trusted) {
        If ($Admin) {
            install-module -name AzureAD
        }
        Else {
            install-module -Scope CurrentUser -Name AzureAD
        }
    }
    Else {
        if ($Admin) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            install-module -name AzureAD
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
        }
        Else {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            install-module -Scope CurrentUser -name AzureAD
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
        }
    }
}
$UPN = whoami /upn
#Connect to AzureAD (Prompts for login)
Try {
    if ($UPN -match "@med*") {
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
    $group_members = @($group.Invoke('Members') | % { ([adsi]$_).path }) -Split "WinNT://"
}
$ADIDs = @()
foreach ($group in $group_members) {
    if ($group -match "S-1-12-1") {
        $ADIDs += (Get-AzureADObjectByObjectId -ObjectIds (Convert-AzureAdSidToObjectId($group))).DisplayName
    }
    elseif ($group -ne "") {
        $ADIDs += $group
    }
}

if ($ADIDs -ne $Null) {
    Write-Host "AAD Groups: "
    foreach ($ID in $ADIDs) {
        Write-Host $ID
    }
}
Else {
    Write-host "No AzureAD groups found"
}
