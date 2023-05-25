<#  Script to list files & folders which are longer than a user-entered length
    Will also list any which are over 260 characters long (combined file & folder path length)
    Written 24/05/2023 by Gareth Pullen (grp43)
    Updated 25/05/2023 to have additional "Write-Verbose" for troubleshooting
#>

[CmdletBinding()]
Param(
    [switch] $Silent,
    [Switch] $Help,
    [Switch] $display
)
#Switches to allow for "-Silent" or "-Help" to be called
If ($Help.IsPresent) {
    #Help was called!
    Write-Host "This script asks you for a folder to write CSV File(s) to - one for long-paths, one for long file-names, and one for total-length is 260 or more."
    Write-Host 'It will call them "long-paths.csv" "long-files.csv" and "Long-Combined-Length.csv"'
    Write-Host 'It supports the switches "-Silent" to suppress most messages, "-Verbose" to show more messages, "-display" to only output to the console, and "-Help" to show this'
    Exit
}

#Main script starts here.
Write-Host "You can use -Help to show information including other switches"
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
    $CheckPath = $CheckPath -replace '^\\\\', '\\?\UNC\'
    Write-Verbose -Message "Changing UNC to Unicode UNC"
}
Else {
    #No leading "\\" - so just add the \\?\
    $CheckPath = '\\?\' + $CheckPath
    Write-Verbose -Message "Changing path to unicode type"
}

#Ask for the folder length to look for - default to 200 otherwise
$AskUserLength = $null
$AskUserLength = Read-Host 'Enter a maximum folder length to check (defaults to 200 if nothing is entered)'
Write-Verbose "Checking if a length has been specified"
If ($AskUserLength -gt 1) {
    $FolderLength = $AskUserLength
}
Else {
    $FolderLength = 200
}
$AskUserFileLength = $null
$AskUserfileLength = Read-Host 'And for maximum file-length? (defaults to 100 if nothing is entered)'
Write-Verbose "Checking if a length has been specified"
If ($AskUserFileLength -gt 1) {
    $FileLength = $AskUserFileLength
}
Else {
    $FileLength = 100
}

# Enumerate the subfolders
Write-Verbose "Getting list of directories"
$FolderList = Get-ChildItem -Path $CheckPath -Directory -Recurse
#check the length of the folders
$LongFolders = New-Object System.Collections.Generic.List[System.Object]
$CSVWritten = New-Object System.Collections.Generic.List[System.Object]
Write-Verbose "Will now loop through list of folders checking the length"
Foreach ($Folder in $FolderList) {
    #-4 to account for the extra "\\?\" we added.
    if ((($Folder.FullName).Length - 4) -gt $FolderLength) {
        $LongFolders.Add($Folder)
    }
}
If ($LongFolders.Count -gt 0) {
    Write-Verbose "Folders longer than $FolderLength found - either displaying or writing them out"
    #There's something in the list!
    if ($PSBoundParameters.ContainsKey('display')) {
        #We only want to display the results
        Write-Host "The following folders are longer than $FolderLength"
        foreach ($Entry in $LongFolders) {
            $Entry = $Entry -replace '^\\\\\?\\', ''
            Write-Host $Entry
        }
    }
    Else {
        #Display was not set, so output to CSV.
        $ExportFolderPath = $ExportPath + "Long-Folders.csv"
        Write-Verbose "Attempting to write list of long-folders to $ExportFolderPath"
        $LongFolders | Select FullName | Export-Csv -NoTypeInformation -Path $ExportFolderPath 
        $CSVWritten.Add($ExportFolderPath)
    }
}

# Enumerate the subfiles
Write-Verbose "Getting list of files"
$FileList = Get-ChildItem -Path $CheckPath -Recurse

#Create List objects for the file lists
$LongFiles = New-Object System.Collections.Generic.List[System.Object]
$LongTotalPath = New-Object System.Collections.Generic.List[System.Object]

#check the length of the files
Write-Verbose "About to loop through file-list for those over $FileLength or 260"
Foreach ($File in $FileList) {
    if (($File.Name).Length -gt $FileLength) {
        $LongFiles.Add($File)
    }
    if ($File.Fullname.Length -gt 264) {
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
