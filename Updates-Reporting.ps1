#Script to query Azure Update Compliance, then write out info on devices to CSV including:
#Device Name, Assigned User, UPN, OS Version, and update status
#Written 13/12/2021 by Gareth Pullen (grp43) - with bits grabbed from online

function Get-AuthToken {
#https://www.powershellgallery.com/packages/UnofficialIntuneManagement/0.2.0.0/Content/Private%5CGet-AuthToken.ps1

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
function Get-IntuneDevicePrimaryUser {
#https://github.com/microsoftgraph/powershell-intune-samples/tree/master/ManagedDevices
    
    <#
    .SYNOPSIS
    This lists the Intune device primary user
    .DESCRIPTION
    This lists the Intune device primary user
    .EXAMPLE
    Get-IntuneDevicePrimaryUser
    .NOTES
    NAME: Get-IntuneDevicePrimaryUser
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $deviceId
    )
        
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"
    
    try {
            
        $primaryUser = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
    
        return $primaryUser.value."id"
            
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
        throw "Get-IntuneDevicePrimaryUser error"
    }
}
function Azure-Connect {
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
}

Connect-AzAccount -Subscription <ID Goes here>
$Query = Invoke-AzOperationalInsightsQuery -WorkspaceId "<Workspace ID goes here>" -Query "WaaSUpdateStatus | summarize arg_max(TimeGenerated, *) by ComputerID"
$Computers = $Query.Results
$ExportPath = Read-Host 'Enter Folder to save Output CSV file'
if ($ExportPath -match '\\$') {
    $ExportPath = $ExportPath.TrimEnd('\')
}
$authToken = Get-AuthToken
Connect-MSGraph
Foreach ($Computer in $Computers) {
    $CompName = $Computer.Computer
    If ($CompName  -eq ""){
        Continue
    }
    If ($CompName -eq "#"){
        Continue
    }
    $Device = Get-IntuneManagedDevice -Filter "DeviceName eq '$CompName'"
    #Write-Host $Device
    $IntuneDevicePrimaryUser = Get-IntuneDevicePrimaryUser -deviceId $Device.managedDeviceId
    Azure-Connect
    If ($IntuneDevicePrimaryUser){
            $User = Get-AzureADUser -ObjectId $IntuneDevicePrimaryUser    
    }
    else {
        $User = @{DisplayName = "Not Assigned"
                  Mail = "Not Assigned"}
    }
   
    
    Write-Host "Computer: " $CompName " Primary User: " $User.DisplayName " UPN: " $User.Mail "OS Version:" $Computer.OSVersion
    [PSCustomObject]@{
        SystemName = $CompName
        User       = $User.DisplayName
        UPN        = $User.Mail
        OSVersion  = $Computer.OSVersion
        SecUpdates = $Computer.OSSecurityUpdateStatus
        QualUpdate = $Computer.OSQualityUpdateStatus
        FeatureUpdate = $Computer.OSFeatureUpdateStatus
        BuildRef = $Computer.OSBuild
    } | Export-Csv $ExportPath\Updates-missing.csv -notype -Append 
}