<# Version 2 of the "add group to admin" script. 
Produces a better script to avoid errors when deployed via Intune Scripts
Written 29/03/2022 by Gareth Pullen
#>

function Convert-ObjectIdToSid {
    param([String] $ObjectId)

    $d = [UInt32[]]::new(4); [Buffer]::BlockCopy([Guid]::Parse($ObjectId).ToByteArray(), 0, $d, 0, 16); "S-1-12-1-$d".Replace(' ', '-')
}

#Check if AzureAD Module is installed, install it if not.
try {
    get-installedmodule -name azuread -ErrorAction Stop | out-null
}
Catch {
    If ((get-psrepository -Name 'PSGallery').Trusted) {
        install-module -name AzureAD
    }
    Else {    
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        install-module -name AzureAD
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
    }
}

#Connect to AzureAD (Prompts for login)
Try {
    Connect-AzureAD -EA SilentlyContinue |Out-Null
}
Catch {
    Write-Output "Error Occurred:"
    Write-Output $_
    Exit
}

$Groups = Get-AzureADGroup -All $true | Out-GridView -Passthru 
If ($Groups -eq $Null) {
    #No group selected, quit:
    Exit
}

#Prompt for a path, check it's valid
$SaveFilePath = Read-Host "Please enter a path to save the script in"
if (-not(Test-Path -Path $SaveFilePath)){
Do {$SaveFilePath = Read-Host "Please enter a valid path"}
Until (Test-Path $SaveFilePath)}
if (-not($SaveFilePath.EndsWith("\"))){
    $SaveFilePath = $SaveFilePath+"\"}

#Prompt for a script name, add PS1 if necessary
$SaveFileName = Read-Host "Please enter the script name"
if (-not($SaveFileName.EndsWith(".ps1"))) {
    $SaveFileName = $SaveFileName+".ps1"}
$FullPath = $SaveFilePath + $SaveFileName
New-item -Path $FullPath -Type File -Force |Out-Null

$ScriptTop = @'
# Script auto-generated by "add-group-to-admin-v2" - generator written by Gareth Pullen 30/03/2022
# This generated script can be deployed via Intune Scripts and shouldn't produce errors if groups are already a member

foreach ($group in Get-LocalGroup -Name "Administrators") {
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % { ([adsi]$_).path }) -Split "WinNT://"
}
[System.Collections.ArrayList]$AddGroups = @()

'@

$ScriptBottom = @'

foreach ($RemainingGroup in $AddGroups) {Add-LocalGroupMember -Group Administrators -Member "$RemainingGroup"}
'@

if ($Groups -is [System.Array]) {
    #Is an array, multiple entries:
    foreach ($Group in $Groups) {
        $GroupSID = Convert-ObjectIdToSid($Group.ObjectId)
        $Output = $Output + '$AddGroups.Add("' + $GroupSID
        $Output = $Output + @'
")|Out-Null

'@
        $Output = $Output + 'foreach ($group in $group_members) {'
        $Output = $Output + 'if ($group -match "' + $GroupSID + '"){ $AddGroups.Remove("' + $GroupSID
        $Output = $Output + @'
")}}

'@
    }
    $Output = $ScriptTop + $Output + $ScriptBottom
}
Else {
    #A single group has been selected
    $GroupSID = Convert-ObjectIdToSid($Groups.ObjectId)
    $Output = $Output + '$AddGroups.Add("' + $GroupSID
    $Output = $Output + @'
")|Out-Null

'@
    $Output = $Output + 'foreach ($group in $group_members) {'
    $Output = $Output + 'if ($group -match "' + $GroupSID + '"){ $AddGroups.Remove("' + $GroupSID + '")} }'
    $Output = $ScriptTop + $Output + $ScriptBottom
}

Add-Content -Path $FullPath -Value $Output