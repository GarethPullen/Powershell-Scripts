#Script written 29/07/2021 by Gareth Pullen. Queries AzureAD for list of groups, will then produce a PowerShell script to add selected groups to local Administrators group.
#Useful for adding to Intune Scripts to deploy on a group of devices.

#Connect to AzureAD (Prompts for login)
Connect-AzureAD

function Convert-ObjectIdToSid
{
    param([String] $ObjectId)

    $d=[UInt32[]]::new(4);[Buffer]::BlockCopy([Guid]::Parse($ObjectId).ToByteArray(),0,$d,0,16);"S-1-12-1-$d".Replace(' ','-')
}
#Next line takes a while as it grabs all groups from AAD, before displaying them to the user to choose.
$Groups = Get-AzureADGroup -All $true | Out-GridView -Passthru | ForEach { [pscustomobject] @{ Name= $_.DisplayName; Sid=Convert-ObjectIdToSid($_.ObjectId)}} 
$GroupSID = $Groups |Select-Object -ExpandProperty  SID

#Prompt for a path, check it's valid
$SaveFilePath = Read-Host "Please enter a path to save the script in"
if (-not(Test-Path -Path $SaveFilePath)){
#Path not valid, so prompt for it again
    Do {$SaveFilePath = Read-Host "Please enter a valid path"}
    Until (Test-Path $SaveFilePath)}
if (-not($SaveFilePath.EndsWith("\"))){
    #Doesn't end with a "\" so add one
    $SaveFilePath = $SaveFilePath+"\"}

#Prompt for a script name, add PS1 if necessary
$SaveFileName = Read-Host "Please enter the script name"
if (-not($SaveFileName.EndsWith(".ps1"))) {
    $SaveFileName = $SaveFileName+".ps1"}
$FullPath = $SaveFilePath + $SaveFileName

#Write the new script out.
$Output = 'Add-LocalGroupMember -Group Administrators -Member "'+$GroupSID+'"'

New-item -Path $FullPath -Type File -Force |Out-Null
Add-Content -Path $FullPath -Value $Output
