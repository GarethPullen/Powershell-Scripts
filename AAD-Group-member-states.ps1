<#
Script to get members of an AzureAD group, and then check the account status (Enabled / Disbaled)
Writes it out to a CSV file
Written 31/01/2024 by Gareth Pullen
#>

$ExportFolder = "C:\Temp\"

#Connect to AzureAD (Prompts for login)
Try {
    Connect-AzureAD -EA SilentlyContinue
    }
Catch {
    Write-Output "Error Occurred:"
    Write-Output $_
    Exit
    }

$Group = Get-AzureADGroup -All $True | Out-GridView -PassThru
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
    }
    $UsersState.Add($UserInfo) | Out-Null
}

$UsersState | Export-Csv -Path $ExportPath -NoTypeInformation