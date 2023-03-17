<# Script written 15/03/2023 by Gareth Pullen (grp43)
Prompts for a machine-name, exports current group-membership of the device, deletes from Intune, AzureAD and the Autopilot Record for it.
Allows for rebuiling of devices following motherboard change, etc.
16/03/2023 - Continued improvements. Added "Help" switch. Added confirmation once the device is deleted.
17/03/2023 - Used new "ModuleCheckInstall" function to check & install modules.
#>

[CmdletBinding()]
param (
    [Switch] $Help        
)

If ($Help.IsPresent) {
    Write-Output "This script will pop up an Azure sign-in prompt (possibly twice), and then a searchable window to select an Intune device." 
    Write-Output "Closing that window without selecting a device, or clicking Cancel will quit."
    Write-Output "Once you select a device and click OK it will then get & display the Groups it is a member of, and then ask you if you are sure you want to delete it"
    Write-Output "As you cannot delete an Azure Record until the Autopilot Record is removed, there is a 2-minute delay between deleting the Autopilot and Azure records"
    Write-Output "If, when searching AzureAD for the device-name, more than one result is returned you will be informed (though the script will only delete the device that matches the AzureDeviceID) and asked if you want to continue."
    Write-Output "Please re-run this without -help to use it. This will now quit."
    Exit
}

function ModuleCheckInstall {
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]  
        [ValidateNotNullOrEmpty()]  
        [string[]]$ModulesRequested
    )
    <#Function to check if modules are installed, and install them if not
    Written 17/03/2023 by Gareth Pullen
    takes either a single-item or an array of modules as input
    #>
    Begin {
        #We need to check PSGallery is Trusted
        If (!(get-psrepository -Name 'PSGallery').Trusted) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            $ResetTrust = $true
        }
        else { $ResetTrust = $false }
        #Check if we're running in Elevated mode - adjust Scope accordingly.
        Write-Verbose "Checking if we're elevated or not"
        $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        If ($Elevated) {
            Write-Verbose "We are elevated, setting scope to AllUsers"
            $InstallScope = "AllUsers"
        }
        Else {
            Write-Verbose "Not elevated, set scope to CurrentUser"
            $InstallScope = "CurrentUser"
        }
    }
    Process {
        Foreach ($Module in $ModulesRequested) {
            try {
                Write-Verbose "Checking if $Module is installed"
                get-installedmodule -name $Module -ErrorAction Stop | out-null
                Write-Verbose "$Module already installed"
            }
            catch {
                Write-Verbose "$Module not found, attempting install"
                #Error means not found - Try installing it
                try {
                    install-module -name $Module -Scope $InstallScope -ErrorAction Stop
                }
                Catch {
                    Write-Verbose "$Module returned an error trying to install!"
                    #Caught an error - we want to stop here, but should reset the Trust first.
                    if ($ResetTrust) {
                        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
                    }
                    #Throw the error to halt the module installs.
                    Throw $_
                }
            }
            Try {
                #By this point the module should be installed, so we can Import it.
                Write-Verbose "Attempting to import $Module"
                Import-Module $Module -Global -ErrorAction Stop
            }
            Catch {
                #Catch any errors importing and throw it back.
                Write-Verbose "Error importing module $Module"
                Throw $_
            }
        }
    }
    End {
        #If everything above worked, we should reset the Trust for PSGallery if required
        if ($ResetTrust) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
        }
    }

}

ModuleCheckInstall "Microsoft.Graph.Intune", "azuread", "WindowsAutoPilotIntune"

#Connect to Graph & AzureAD - will prompt for credentials twice (once for each).
Write-Host "You may be prompted for login twice, this is normal!"
Connect-MSGraph | Out-Null
Connect-AzureAD | Out-Null

function Get-DeviceGroupMembership {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param(  
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]  
        [ValidateNotNullOrEmpty()]  
        [string]$DeviceName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]  
        [ValidateNotNullOrEmpty()] 
        [string]$AADDeviceId
    )

    #Taken from: https://gist.github.com/SMSAgentSoftware/c9468f638dad3af747689cb931cd4fc8

    $ProgressPreference = 'SilentlyContinue'
    # Get a user token for MS Graph
    $GraphToken = Connect-MSGraph -PassThru 

    # Find the object id
    If ($DeviceName) {
        $URL = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$DeviceName'&`$select=id"
    }
    If ($AADDeviceId) {
        $URL = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$AADDeviceID'&`$select=id"
    }
    $headers = @{'Authorization' = "Bearer " + $GraphToken }
    $D_Response = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing
    If ($D_Response.StatusCode -eq 200) {
        # Check for duplicates
        $DeviceId = ($D_Response.Content | ConvertFrom-Json).Value.id
        If ($DeviceId.Count -gt 1) {
            Write-Warning "Multiple devices found. Please pass a unique devicename or AAD device Id!"
            Return
        }
        else {
            If ($DeviceId) {
                # Get the group membership
                $URL = "https://graph.microsoft.com/beta/devices/$DeviceId/memberOf?`$select=displayName,description,id,groupTypes,membershipRule,membershipRuleProcessingState"
                $G_Response = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing
                If ($G_Response.StatusCode -eq 200) {
                    $Groups = ($G_Response.Content | ConvertFrom-Json).Value 
                }

                # Get the transitive group membership
                $URL = "https://graph.microsoft.com/beta/devices/$DeviceId/transitiveMemberOf?`$select=displayName,description,id,groupTypes,membershipRule,membershipRuleProcessingState"
                $TG_Response = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing
                If ($TG_Response.StatusCode -eq 200) {
                    $TransitiveGroups = ($TG_Response.Content | ConvertFrom-Json).Value 
                }
            }
            else {
                Write-Warning "Device not found!"    
            }
        }
    }
    else {
        Return    
    }

    # If results found
    If ($Groups.Count -ge 1 -or $TransitiveGroups.Count -ge 1) {
        # Create a datatable to hold the groups
        $DataTable = [System.Data.DataTable]::New()
        $Columns = @()
        @(
            'Name'
            'Description'
            'Object Id'
            'Membership Type'
            'Direct or Transitive'
            'Membership Rule'
            'Membership Rule Processing State'
        ) | ForEach-Object {
            $Columns += [System.Data.DataColumn]::new("$_")
        }
        $DataTable.Columns.AddRange($Columns)

        # Add the groups
        foreach ($Group in $Groups) {
            If (($Group.groupTypes | Select-Object -First 1) -eq "DynamicMembership")
            { $MembershipType = "Dynamic" }
            Else { $MembershipType = "Assigned" }
            [void]$DataTable.Rows.Add($Group.displayName, $Group.description, $Group.id, $MembershipType, "Direct", $Group.membershipRule, $Group.membershipRuleProcessingState)
        }

        # Add the transitive groups
        foreach ($TransitiveGroup in ($TransitiveGroups | Where-Object { $_.id -NotIn $Groups.id })) {
            If (($TransitiveGroup.groupTypes | Select-Object -First 1) -eq "DynamicMembership")
            { $MembershipType = "Dynamic" }
            Else { $MembershipType = "Assigned" }
            [void]$DataTable.Rows.Add($TransitiveGroup.displayName, $TransitiveGroup.description, $TransitiveGroup.id, $MembershipType, "Transitive", $TransitiveGroup.membershipRule, $TransitiveGroup.membershipRuleProcessingState)
        }

        Return $DataTable
    }
}

Write-Verbose "Prompting user to select a device"
#Prompt the user for the device to be removed
$Device = Get-IntuneManagedDevice | Select-Object devicename, serialNumber, userDisplayName, model, id, azureADDeviceId | Out-GridView -OutputMode Single

if (!($Device)) {
    #No device selected
    Write-Output "No device selected, script will quit now"
    Exit
}

$DevName = $Device.deviceName
Write-Verbose "Getting Group Membership for Device"
$GroupMembership = Get-DeviceGroupMembership -AADDeviceId $Device.azureADDeviceId

$AssignedGroups = New-Object System.Collections.Generic.List[string]
$DynamicGroups = New-Object System.Collections.Generic.List[string]

Write-Verbose "Got groups. Iterating through results to split Assigned and Dynamic"
foreach ($Group in $GroupMembership) {
    $GroupType = $Group.ItemArray[3]
    If ($GroupType -eq "Assigned") {
        $AssignedGroups.Add($Group.ItemArray[0])
    }
    else {
        $DynamicGroups.Add($Group.ItemArray[0])
    }
}

#Write output to terminal.
If ($DynamicGroups -ge 1) {
    Write-Output "************************"
    Write-Output "Dynamic Groups:"
    Write-Output "************************"
    Foreach ($Dynamic in $DynamicGroups) {
        Write-Output $Dynamic
    }
}
if ($AssignedGroups -ge 1) {
    Write-Output "************************"
    Write-Output "Assigned Groups:"
    Write-Output "************************"
    Foreach ($Assigned in $AssignedGroups) {
        Write-Output $Assigned
    }
}
Else {
    Write-Output "No assigned groups found for $DevName"
}
#Final chance to cancel before we start deleting things.
#We will only continue if they press "Y" - anything else will cause it to quit.
$RemovePrompt = "N"
$RemovePrompt = Read-Host -Prompt "Remove device: $DevName ? (y/N)"
If ($RemovePrompt.ToUpper() -eq "Y") {
    Write-Verbose "Getting AzureAD Device from name"
    $AADDevice = Get-AzureADDevice -SearchString $DevName
    If ($AADDevice -is [System.Array]) {
        #More than one result returned! We should warn the user and offer to abort.
        Write-Host "The Device name $Devname returned more than one result. I will only delete the one matching the Azure Device ID, but please manually check AzureAD"
        $Abort = "Y"
        $Abort = Read-Host -Prompt "Should I abort? Press Y to abort. If you continue only the matching AzureAD Device ID will be deleted - the additional items will not be touched"
        If ($Abort.ToUpper() -eq "Y") {
            Write-Host "Aborting!"
            Exit
        }
        Foreach ($Item in $AADDevice) {
            If ($Item.DeviceId -eq $Device.azureADDeviceId) {
                #DeviceID Matches - return the correct ObjectID
                $ObjID = $Item.ObjectId
                Write-Verbose "Device ID matches AzureAD item, returning AzureAD-ID"
            }
        }
    }
    else {
        #Not an array, single-item returned so we can just get the ObjectID
        $ObjID = $AADDevice.ObjectID
        Write-Verbose "Returning AzureAD-ID for device"
    }
    Write-Verbose "Removing Intune device record"
    Remove-IntuneManagedDevice -managedDeviceId $Device.id
    try {
        Write-Verbose "Trying to remove Autopilot record"
        #Try and delete the Autopilot record - error-handling in case it's not in there, we still want to delete the Azure Record.
        Get-AutopilotDevice | Where-Object azureAdDeviceId -eq $Device.azureADDeviceId | Remove-AutopilotDevice -ErrorAction Stop   
    }
    catch {
        Write-Verbose "Error caught when deleting Autopilot Record"
        Write-Verbose "$_"
        Write-Output "Failed to delete Autopilot entry - it may not exist? Continuing to delete Azure Record anyway."
    }
    Write-Output "The script will now wait 2 minutes before deleting the Azure Record"
    Start-Sleep -Seconds 120
    Write-Verbose "Waited 2 minutes, deleting AzureAD Device Object by ObjectID"
    Remove-AzureADDevice -ObjectId $ObjID
    Write-Output "$DevName has now been deleted from Intune (both the device and Autopilot record) and Azure."
}
Else {
    Write-Output "Aborting!"
}
