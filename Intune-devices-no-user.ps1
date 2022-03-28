#Script to check for devices with no User Signed in.
#Does this by checking the for one of the Configuration Profiles, if it doesn't have a "normal" user associated we assume nobody's logged in.
#Written by Gareth Pullen 17/03/2022

function Get-AuthToken {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory = $true)]
        $User
    )
    
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    
    $tenant = $userUpn.Host
    
    Write-Host "Checking for AzureAD module..."
    
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    
    if ($AadModule -eq $null) {
    
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    
    }
    
    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }
    
    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    
    if ($AadModule.count -gt 1) {
    
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
    
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
    
        # Checking if there are multiple versions of the same module found
    
        if ($AadModule.count -gt 1) {
    
            $aadModule = $AadModule | select -Unique
    
        }
    
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
    }
    
    else {
    
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
    }
    
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    
    $resourceAppIdURI = "https://graph.microsoft.com"
    
    $authority = "https://login.microsoftonline.com/$Tenant"
    
    try {
    
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
    
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $platformParameters, $userId).Result
    
        # If the accesstoken is valid then create the authentication header
    
        if ($authResult.AccessToken) {
    
            # Creating header for Authorization token
    
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer " + $authResult.AccessToken
                'ExpiresOn'     = $authResult.ExpiresOn
            }
    
            return $authHeader
    
        }
    
        else {
    
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
    
        }
    
    }
    
    catch {
    
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    
    }
    
}
function Get-IntuneConfigurationStatus {
    #Based off standard Intune "Get-PrimaryUser" and hacked about by Gareth to pull Device Configuration Status instead!
    #Takes a "Device Configuration ID" as input and returns devices that have that Configuration applied.
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ConfigID
    )
        
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceConfigurations"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $ConfigID + "/deviceStatuses"
    
    try {
            
        $ConfigStatus = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        return $ConfigStatus
            
    }
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        throw "error"
    }
}

# Next few lines connect to AzureAD, Graph API
$EmailAdd = Read-Host 'Please enter email address to query Intune'
$authToken = Get-AuthToken $EmailAdd
Connect-MSGraph

#Get Information on the Configuration Status
#Can pull other "Device Configuration" reports by changing the ID.
$ConfigResults = Get-IntuneConfigurationStatus "<DeviceConfigID>"

$DeviceList = New-Object System.Collections.Generic.List[System.Object]
$AllDeviceNames = New-Object System.Collections.Generic.List[System.Object]

Foreach ($Device in $ConfigResults.value) {
    $AllDeviceNames.Add($Device.deviceDisplayName)
    If (($Device.userName -ne "System account") -and ($Device.userName -ne "<Sanitised-email-UPN>")) {
        #Device does not have "System Account" or "<Sanitised test account>" as the user, so add it to the list
        $DeviceList.Add($Device.deviceDisplayName)
    }
}
$NoUser = $AllDeviceNames | Where-Object { $DeviceList -notcontains $_ } | Select -Unique
$NoUserArray = @()
Foreach ($NoUserDevice in $NoUser) {
    Foreach ($Device in $ConfigResults.Value) {
        If ($Device.deviceDisplayName -eq $NoUserDevice) {
            $DeviceObject = @{}
            $DeviceObject.Name = $Device.deviceDisplayName
            #Split the Date-Time string into seperate Date and Time properties
            $DeviceObject.Date = ($Device.lastReportedDateTime.Split("T")[0])
            $DeviceObject.Time = ($Device.lastReportedDateTime.Split("T")[1])
            $TempDevice = New-Object PSobject -Property $DeviceObject
            $NoUserArray += $TempDevice
        }
    }
}
$SaveOrDisplay = "N"

$SaveOrDisplay = Read-Host -Prompt "Would you like to save the output to a file or display? Y to save, N to display (Defaults to Display)"
If ($SaveOrDisplay -eq "Y") {
    Do {
        $ExportPath = Read-Host 'Enter Folder to save Output CSV file'
        if (!($ExportPath -match '\\$')) {
            #Check for a trailing "\" and add it if required.
            $ExportPath = $ExportPath + "\"
        }
        If (!(Test-Path $ExportPath)) {
            Write-Host "Invalid Path"
        }
    } until (Test-Path $ExportPath)
    #Make the CSV file-name have the date & time.
    $ExportFile = $ExportPath + (Get-Date -Format "yyyy-MM-dd HH.mm") + "-NoUserAssigned.csv"

    $NoUserArray | Select Name, Date, Time | Sort-Object Name -Unique | Export-Csv -NoTypeInformation -Path $ExportFile
}
Else {
    $NoUserArray | Select Name, Date, Time | Sort-Object Name -Unique | Out-GridView
}