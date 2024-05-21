<#
Script to get members of an AzureAD group, and then check the account status (Enabled / Disbaled)
Writes it out to a CSV file
Written 31/01/2024 by Gareth Pullen
Modified 21/05/2024 to include UPN and Email address. 
Also checks if the export folder exists and creates it if not.
Modified error thrown to be "ErrorRecord".
#>

$ExportFolder = "C:\Temp\"

If (!(Test-Path -path $ExportFolder)) {
    Try {
        New-Item -Path $ExportFolder -Type Directory -ErrorAction Stop -ErrorVariable FolderCreateError
    }
    Catch {
        Throw $FolderCreateError.ErrorRecord
    }
}


$UPN = whoami /upn
#Connect to AzureAD (Prompts for login)
Try {
    if ($UPN -match "@cam*") {
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

$Group = Get-AzureADGroup -All $True | Out-GridView -Outputmode Single
If ($Group -eq $Null){
    Write-Host "No group selected, will quit now."
    Exit
}

#Get the group members from Azure
$GroupMembers = Get-AzureADGroupMember -ObjectId $Group.ObjectId

If ($GroupMembers -eq $Null){
    Write-Host "Error: Group Members is empty!"
    Exit
}

$ExportName = $Group.DisplayName + ".csv"
$ExportPath = $ExportFolder + $ExportName

[System.Collections.ArrayList]$UsersState = @()

Foreach ($Member in $GroupMembers){
    #Iterate through the list of members, get the "User logon name" and state.
    $User = Get-AzureADUser -ObjectId $Member.ObjectId
    $UserInfo = [PSCustomObject]@{
        Username    = $User.MailNickName
        Name        = $User.DisplayName
        Enabled     = $User.AccountEnabled
        Email       = $User.Mail
        UPN         = $User.UserPrincipalName
    }
    $UsersState.Add($UserInfo) | Out-Null
}

$UsersState | Export-Csv -Path $ExportPath -NoTypeInformation
