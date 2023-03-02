<# Script to bulk-add devices to AzureAD Group for "Self-Deployment"
Takes CSV file as input, adds devices to the "self-deployment group" 
Written by Gareth Pullen 02/03/2023
#>

# Group ObjectID to import to:
$GroupID = "<Enter Group ID from Azure here>"

# Ask user for the CSV to import, check it exists, clean off any quotes
$CSVImportFile = Read-Host "Please enter the path to the CSV file"
$CSVImportFile = $CSVImportFile.replace('"','')
if (-not(Test-Path -Path $CSVImportFile -PathType Leaf)){
Do {
    Write-Output "Invalid path specified"
    $CSVImportFile = Read-Host "Please enter the path to the CSV file"
    $CSVImportFile = $CSVImportFile.replace('"','')}
Until (Test-Path -Path $CSVImportFile -PathType Leaf)}

#Check if AzureAD Module is installed, install it if not.
try {
    get-installedmodule -name azuread -ErrorAction Stop | out-null
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

#Connect to AzureAD (will prompt for login) - for adding to the group
Try {
        Connect-AzureAD -EA Stop | out-null
}
Catch {
    Write-Output "Error Occurred:"
    Write-Output $_
    Exit
}

# Read in the CSV file
$DevicesTags = Import-Csv -Path $CSVImportFile -Header 'Tag'

$DeviceIDS = @{}

foreach ($ServiceTag in $DevicesTags){
    try {
        $ID = Get-AzureADDevice -SearchString $ServiceTag.Tag -ErrorAction stop
        if ($ID -ne $null) {
            $DeviceIDS.Add($ServiceTag.Tag, $ID.ObjectId)            
        }
        Else {
            $ErrorTag = $ServiceTag.Tag
            Write-Output "ERROR - Failed to lookup tag: $ErrorTag"
        }

    }
    catch {
        #Failed to lookup ServiceTag
        $ErrorTag = $ServiceTag.Tag
        Write-Output "ERROR - Failed to lookup tag: $ErrorTag"
    }
}

Foreach ($DevID in $DeviceIDS.GetEnumerator()){
    try {
        $AddID = $DevID.Value
        Add-AzureADGroupMember -ObjectId $GroupID -RefObjectId $AddID -ErrorAction Stop
    }
    catch {
        $Name = $DevID.Name
        Write-Output "ERROR: Failed to add Device: $Name"
    }
}
