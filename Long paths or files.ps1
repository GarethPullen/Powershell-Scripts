<#  Script to list files & folders which are longer than a user-entered length
    Will also list any which are over 260 characters long (combined file & folder path length)
    Written 24/05/2023 by Gareth Pullen (grp43)
    Updated 25/05/2023 to have additional "Write-Verbose" for troubleshooting
    Updated 07/06/2023 to truncate file & folder names
    Updated 02/08/2023 to comment out the auto-truncate
    Updated 07/08/2023 to improve the Verbose output & handling of access-denied errors
    Updated 08/08/2023 to allow Excluding folders
    Updated 08/08/2023 - added Examples to the Get-Help section.
#>

<#
    .SYNOPSIS
    Output a listing of all files & folders with long names or paths.

    .DESCRIPTION
    The Long paths of files.ps1 script outputs - either to CSV files or to the console
    Folders with long total-paths, long single-folder names, or long file-names
    Useful for identifying files or folders which exceed the total-path length for Windows.
    Even with Exclude used, the folders will intially be "hit" by the first folder-listing - so some errors may show for them.

    .INPUTS
    User-prompted for Inputs. Does not accept pipeline input.

    .OUTPUTS
    Unless -display is used, will output up to 3 CSV files with long files, long full-folder-paths, or long single-folder-names. Will output to the console where the files are located.

    .EXAMPLE
    ./"Long Paths or files.ps1" 
    You will then be prompted for the location to save the output CSVs, the folder to scan, and the maximum length

    .EXAMPLE
    ./"Long Paths or files.ps1" -exclude "C:\Path\To\Exclude","C:\Path\To\Also\Exclude"
    The -exclude option supports one or more paths to exclude from the subfolder & file scanning. Must be enclosed in quotes, and if multiple are supplied must be comma-seperated.
    Folders will initially be "hit" by the first "gather list of folders" - but will then be excluded from the actual length-checking of the folder, subfolders & files.

    .EXAMPLE
    ./"Long Paths or files.ps1" -Verbose
    As above but will output Verbose information about what it's doing.

    .EXAMPLE
    ./"Long Paths or files.ps1" -display
    Will not prompt for a folder to save CSVs to, will instead output the list of long-files and long-folders to the console.

    .EXAMPLE
    ./"Long Paths or files.ps1" -help
    Displays a Help message

#>


[CmdletBinding()]
Param(
    [switch] 
    # Suppress most messages
    $Silent,
    [Switch] 
    # Display Help Message
    $Help,
    [switch] 
    # Enable auto-truncation
    $truncate,
    [Switch] 
    # Display results rather than writing to CSV
    $display,
    [string[]] 
    # Folders to exclude for file-scanning
    $exclude
)
#Switches to allow for "-Silent" or "-Help" to be called
If ($Help.IsPresent) {
    #Help was called!
    Write-Host 'Unless called with the "-display" parameter'
    Write-Host "This script asks you for a folder to write CSV File(s) to - one for long-paths, one for long file-names, and one for total-length longer than specified."
    Write-Host 'It will call them "long-paths.csv" "long-files.csv" and "Long-Combined-Length.csv"'
    Write-Host 'If called with the "-display" switch it will not write to CSV and will instead just write to the console'
    Write-Host 'It supports the switches "-Silent" to suppress most messages, "-Verbose" to show more messages, "-display" to only output to the console, and "-Help" to show this'
    Write-Host 'You can use the "-exclude" parameter to exclude folders for the file checking. Must be enclosed in quotes, and with a comma-separating them. They will still be "found" during the initial folder-listing'
    Write-Host 'So expect some errors if using Verbose, even with Exclude listed. They will not be scanned for subfiles & folders however.'
    Exit
}

#Main script starts here.

Write-Host "You can use -Help to show information including other switches"

if ($PSBoundParameters.ContainsKey('exclude')) {
    #Exclude is used...
    $ExcludeList = New-Object System.Collections.Generic.List[System.Object]
    Foreach ($Item in $exclude) {

        If (!($Item -match '\\$')) {
            #Doesn't end with \ - add the item and it with a "\" added
            $ExcludeList.Add($Item)
            $ExcludeList.Add($Item + "\")
        }
        Else {
            #Does end with \ - add it, and one with the last character removed
            $ExcludeList.Add($Item)
            $ExcludeList.Add($Item -replace ".$")
        }
    }
}

if (!($PSBoundParameters.ContainsKey('display'))) {
    Write-Verbose "Display switch not used, asking for output location"
    #If -dispaly is specified we don't output to CSV, so don't need an output path
    #Ask for the output path
    Do {
        $ExportPath = Read-Host 'Enter Folder to save Output CSV file'
        if (!($ExportPath -match '\\$')) {
            #Check for a trailing "\" and add it if required.
            $ExportPath = $ExportPath + "\"
        }
        If (!(Test-Path $ExportPath)) {
            Write-Host "Invalid Path"
        }
        Write-verbose -Message "Checking if $ExportPath is accessible"
    } until (Test-Path $ExportPath) 
}

#Ask for the path to check
Do {
    $CheckPath = Read-Host 'Enter Folder to check file & folder lengths in'
    $CheckPath = $CheckPath.Trim('"')
    if (!($CheckPath -match '\\$')) {
        #Check for a trailing "\" and add it if required.
        $CheckPath = $CheckPath + "\"
    }
    Write-Verbose -Message "Checking if $CheckPath is acessible"
} until (Test-Path $CheckPath)

#Change it to avoid the 260-character limit
if ($CheckPath.Substring(0, 2) -eq "\\") {
    #Has leading "\\"
    Write-Verbose -Message "Changing UNC to Unicode UNC"
    $CheckPath = $CheckPath -replace '^\\\\', '\\?\UNC\'
}
Else {
    #No leading "\\" - so just add the \\?\
    Write-Verbose -Message "Changing path to unicode type"
    $CheckPath = '\\?\' + $CheckPath
}

#Ask for the folder length to look for - default to 200 otherwise
$AskUserLength = $null
$AskUserLength = Read-Host 'Enter a maximum folder full-path length to check (defaults to 200 if nothing is entered)'
Write-Verbose "Checking if a length has been specified"
If ($AskUserLength -gt 1) {
    $FolderFullPathLength = $AskUserLength
}
Else {
    $FolderFullPathLength = 200
}
$AskUserLength = $null
$AskUserLength = Read-Host 'Enter a maximum folder length to check (i.e. maximum length for a sigle-folder. Defaults to 50 characters)'
Write-Verbose "Checking if a length has been specified"
If ($AskUserLength -gt 1) {
    $FolderLength = $AskUserLength
}
Else {
    $FolderLength = 50
}
$AskUserLength = $null
$AskUserLength = Read-Host 'Enter a maximum File length to check (i.e. maximum length for a file-name. Defaults to 50 characters)'
Write-Verbose "Checking if a length has been specified"
If ($AskUserLength -gt 1) {
    $FileLength = $AskUserLength
}
Else {
    $FileLength = 50
}


# Enumerate the subfolders
Write-Verbose "Getting list of directories"
if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
    $Errors = New-Object System.Collections.Generic.List[System.Object]
    #Verbose specified, so we want to show the errors when checking folder lists:
    Write-Verbose "Verbose specified, will list any problem folders. This will include those specified by Exclude - they will be removed from the subfolders & files"
    Try {
        [System.Collections.ArrayList]$FolderList = Get-ChildItem -Path $CheckPath -Directory -Recurse -EA stop    
    }
    Catch {
        $Errors.Add($PSItem.Exception.Message)
    }
    If ($Errors.Count -gt 0) {
        #Errors has something in it
        Write-Verbose "The following errors were encountered while getting the folder-list:"
        foreach ($Message in $Errors) {
            Write-Host -ForegroundColor red $Message
        }
    }
    # Clear the $Errors variable:
    Clear-Variable -Name "Errors"
}
Else {
    #Verbose not specified, silently continue on errors to suppress them.
    [System.Collections.ArrayList]$FolderList = Get-ChildItem -Path $CheckPath -Directory -Recurse -EA Silentlycontinue
}

if ($PSBoundParameters.ContainsKey('exclude')) {
    Write-Verbose "Exclusions passed, will now remove them from the list"
    #Remove the "Excluded" folders from the list.
    Foreach ($Folder in $($CheckPath)) {
        Foreach ($Exclusion in $ExcludeList) {
            #Write-Host "Excluding: " $Exclusion
            if ($Exclusion -match '\\$') {
                #Ends with a \
                If ($Folder.FullName.StartsWith($Exclusion)) {
                    Write-Verbose "Removing: "$Folder
                    $FolderList.Remove($Folder)
                }
            }
            Else {
                #Doesn't end with a \
                If ($Folder.FullName -like $Exclusion) {
                    Write-Verbose "Removing: "$Folder
                    $FolderList.Remove($Folder)
                }
            }
        }
    }
    Write-Verbose "All exclusions removed. Moving on to checking path-length"
}

#check the length of the folders
$LongFolderFullPath = New-Object System.Collections.Generic.List[System.Object]
$LongFolderPath = New-Object System.Collections.Generic.List[System.Object]
$CSVWritten = New-Object System.Collections.Generic.List[System.Object]
Write-Verbose "Will now loop through list of folders checking the length"
Foreach ($Folder in $FolderList) {
    #-4 to account for the extra "\\?\" we added.
    if ((($Folder.FullName).Length - 4) -ge $FolderFullPathLength) {
        $LongFolderFullPath.Add($Folder)
    }
    if ((($Folder.Name)).Length -ge $FolderLength) {
        #If the folder-name is long then add it to a list
        $LongFolderPath.Add($Folder)
    }
}

If ($LongFolderFullPath.Count -gt 0) {
    Write-Verbose "Folders longer than $FolderFullPathLength found - either displaying or writing them out"
    #There's something in the list!
    if ($PSBoundParameters.ContainsKey('display')) {
        #We only want to display the results
        Write-Host "The following folders are longer than $FolderFullPathLength"
        foreach ($Entry in $LongFolderFullPath) {
            $Entry = $Entry -replace '^\\\\\?\\', ''
            Write-Host $Entry
        }
    }
    Else {
        #Display was not set, so output to CSV.
        $ExportFolderPath = $ExportPath + "Long-Folders.csv"
        Write-Verbose "Attempting to write list of long-folders to $ExportFolderPath"
        $LongFolderFullPath | Select FullName | Export-Csv -NoTypeInformation -Path $ExportFolderPath 
        $CSVWritten.Add($ExportFolderPath)
    }
}

# Enumerate the subfiles
Write-Verbose "Getting list of files"
if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
    $Errors = New-Object System.Collections.Generic.List[System.Object]
    #Verbose specified, so we want to show the errors when checking folder lists:
    Write-Verbose "Verbose specified, will list any problem folders"
    Try {
        $FileList = Get-ChildItem -Path $CheckPath -File -Recurse -Force -ErrorAction stop    
    }
    Catch {
        $Errors.Add($PSItem.Exception.Message)
    }
    If ($Errors.Count -gt 0) {
        #Errors has something in it
        Write-Verbose "The following errors were encountered while getting the file-list:"
        foreach ($Message in $Errors) {
            Write-Host -ForegroundColor red $Message
        }
    }
}
Else {
    #Verbose not specified, silently continue on errors to suppress them.
    $FileList = Get-ChildItem -Path $CheckPath -File -Recurse -Force -ErrorAction SilentlyContinue
}
#Create List objects for the file lists
$LongFiles = New-Object System.Collections.Generic.List[System.Object]
$LongTotalPath = New-Object System.Collections.Generic.List[System.Object]

#check the length of the files
Write-Verbose "About to loop through file-list for those over $FileLength or 260"
Foreach ($File in $FileList) {
    if (($File.Name).Length -ge $FileLength) {
        $LongFiles.Add($File)
    }
    if ($File.Fullname.Length -ge 264) {
        #We definitely want to log "Path Longer than 264! (260 + 4 for the "\\?\")"
        $LongTotalPath.Add($File)
    }
}
If ($LongFiles.Count -gt 0) {
    Write-Verbose "Files longer than $FileLength found, writing out to file or display"
    #There's something in the list!
    if ($PSBoundParameters.ContainsKey('display')) {
        #We only want to display the results
        Write-Host "The following folders are longer than $FileLength"
        foreach ($FileEntry in $LongFiles) {
            $FileEntry = $fileEntry -replace '^\\\\\?\\', ''
            Write-Host $FileEntry
        }
    }
    Else {
        #Display was not set, so output to CSV.
        $ExportFilesPath = $ExportPath + "Long-Files.csv"
        Write-Verbose "Attempting to write CSV to $ExportFilesPath"
        $LongFiles | Select DirectoryName, Name | Export-Csv -NoTypeInformation -Path $ExportFilesPath
        $CSVWritten.Add($ExportFilesPath)
    } 
}
If ($LongTotalPath.Count -gt 0) {
    Write-Verbose "Found items where file+path is over 260 characters, listing them too"
    #We found file+path where it was 260 or more! Log them too.
    if ($PSBoundParameters.ContainsKey('display')) {
        #We only want to display the results
        Foreach ($LongItem in $LongTotalPath) {
            $LongItem = $LongItem -replace '^\\\\\?\\', ''
            Write-Host $LongItem
        }
    }
    else {
        #Display was not set, so output to CSV.
        $ExportLongItemPath = $ExportPath + "Long-Total-Path.csv"
        Write-Verbose "Attempting to write these to $ExportLongItemPath"
        $LongTotalPath | Select DirectoryName, Name | Export-Csv -NoTypeInformation -Path $ExportLongItemPath
        $CSVWritten.Add($ExportLongItemPath)
    }
}

if (!($PSBoundParameters.ContainsKey('display'))) {
    #Display not set, let's say what files we wrote...
    Write-Host "The following files have been written:"
    foreach ($FileWritten in $CSVWritten) {
        Write-Host $FileWritten
    }
}

<#
if ($PSBoundParameters.ContainsKey('truncate')) {
    #Check for file-length trimming options!
    $AskUserLength = $null
    $AskUserLength = Read-Host 'What should I trim the folder-name down to? (Defaults to 15 characters if nothing is set)'
    Write-Verbose "Checking if a length has been specified"
    If ($AskUserLength -gt 1) {
        $FolderTrimLength = $AskUserLength
    }
    Else {
        $FolderTrimLength = 15
    }

    $AskUserFileLength = $null
    $AskUserfileLength = Read-Host 'To what length should long-files be trimmed to? (Defaults to 20 characters if nothing is entered)'
    Write-Verbose "Checking if a length has been specified"
    If ($AskUserFileLength -gt 1) {
        $FileTrimLength = $AskUserFileLength
    }
    Else {
        $FileTrimLength = 20
    }
    #>

<#
    ### Now we check if the user really wants us to rename the files & folders...
    $TotalLongFolders = $LongFolderPath.Count
    $TotalLongFilenames = $LongFiles.Count
    If ($TotalLongFolders -gt 0) {
        Write-Output "We found $TotalLongFolders folders longer than $FolderLength"
    }
    If ($TotalLongFilenames -gt 0) {
        Write-Output "We found $TotalLongFilenames files longer than $FileLength"
    }
    If ($TotalLongFolders + $TotalLongFilenames -eq 0) {
        Write-Output "Nothing to truncate, quitting"
        Exit
    }
    Write-Output "Do you really want to truncate all of those files and folders? Check the CSV files listed above for all which will be renamed"
    Write-Host 'Please enter "Y" to confirm you want to rename them all!'
    $UserConfirmed = "N"
    $UserConfirmed = Read-Host -Prompt "Really truncate? This CANNOT be undone! (y/N)"
    If ($UserConfirmed.ToUpper() -eq "Y") {
        $RenamedItemsCSV = $ExportPath + "RenamedItems.csv"
        #Do the renaming...
        $RenamedItems = @{}
        Foreach ($Folder in $LongFolderPath) {
            Try {
                $NewFolderName = ($Folder.Name.Substring(0, $FolderLength)).Trim()
                $RenamedItems.Add($Folder.FullName, $NewFolderName)
                Write-Verbose "Renaming $Folder to $NewFolderName"
                Rename-Item -Path $Folder -NewName $NewFolderName
            }
            Catch {
                Write-Error "Error renaming $Folder!"
            }
        }
        Foreach ($File in $LongFiles) {
            Try {
                $Extension = $File.Extension
                $NewFileName = ($File.Name.Substring(0, $FileLength)).Trim() + $Extension
                $RenamedItems.Add($File.FullName, $NewFileName)
                Write-Verbose "Renaming $File to $NewFileName"
                Rename-Item -Path $File -NewName $NewFileName
            }
            Catch {
                Write-Error "Error renaming $File!"
            }
        }

        #Write the list of renamed items to a CSV and tell the user that we've written a CSV of renamed items
        $RenamedItems.GetEnumerator() | Select-Object -Property @{N = 'Old-Name'; E = { $_.Key } }, @{N = 'New-Name'; E = { $_.Value } } | Export-Csv -NoTypeInformation -Path $RenamedItemsCSV
        Write-Output "Renamed items have been logged to: $RenamedItemsCSV"
    }
    Else {
        Write-Host "You decided not to rename them. Check the CSV lists for long files."
    }
}
#>
