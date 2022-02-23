<#
Written Gareth Pullen 16/03/2021 to add AzureAD group to the local Administrators Group on a PC
Updated 24/03/2021 to install the AzureAD module if required, and handle errors better
#>



function Convert-ObjectIdToSid
{
    param([String] $ObjectId)

    $d=[UInt32[]]::new(4);[Buffer]::BlockCopy([Guid]::Parse($ObjectId).ToByteArray(),0,$d,0,16);"S-1-12-1-$d".Replace(' ','-')
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

$Groups = Get-AzureADGroup -All $true | Out-GridView -Passthru 
If ($Groups -eq $Null){
    #No group selected, quit:
    Exit
}
Write-Host "Selected group(s): " $Groups.DisplayName
#Prompt for a path, check it's valid
$SaveFilePath = Read-Host "Please enter a path to save the script in"
if (-not(Test-Path -Path $SaveFilePath)){
    Do {$SaveFilePath = Read-Host "Please enter a valid path"}
    Until (Test-Path $SaveFilePath)
   }
if (-not($SaveFilePath.EndsWith("\"))){
    $SaveFilePath = $SaveFilePath+"\"
   }

#Prompt for a script name, add PS1 if necessary
$SaveFileName = Read-Host "Please enter the script name"
if (-not($SaveFileName.EndsWith(".ps1"))) {
    $SaveFileName = $SaveFileName+".ps1"}
$FullPath = $SaveFilePath + $SaveFileName
New-item -Path $FullPath -Type File -Force |Out-Null

#Write the new script out.
if ($Groups -is [System.Array]) {
    #Is an array, multiple entries:
    foreach ($Group in $Groups) {
        $GroupSID = Convert-ObjectIdToSid($Group.ObjectId)
        $Output = 'Add-LocalGroupMember -Group Administrators -Member "'+$GroupSID+'"'
        Add-Content -Path $FullPath -Value $Output
    }
} Else { #Not an array, single entry
    $GroupSID = Convert-ObjectIdToSid($Groups.ObjectId)
    $Output = 'Add-LocalGroupMember -Group Administrators -Member "'+$GroupSID+'"'
    Add-Content -Path $FullPath -Value $Output
}
