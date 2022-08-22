#Written by Gareth Pullen 15/06/2022 to look for ADS Streams - Main Stream function credited from website.
#16-17/06/2022 - to prompt user for folders, handle errors.
#20/06/2022 - Fixed exporting errors to CSV, changed to use Write-Verbose and Write-Error
#21/06/2022 - Changed to use a List for errors to avoid issues with duplicate keys.
#21/06/2022 - Also added "-Silent" and "-Help" switches.
#22/06/2022 - Added a count of total items & progress.
#28/06/2022 - Re-factored to allow "-file" switch to take a string on the command-line
#22/08/2022 - Modified to use "\\?\" to allow > 260 character paths

[CmdletBinding()]
Param(
    [switch] $Silent,
    [Switch] $Help,
    [Parameter(Mandatory=$false)][string] $File
)
#Switches to allow for "-Silent" or "-Help" to be called
If ($Help.IsPresent) {
    #Help was called!
    Write-Host "This script asks you for a folder to write CSV Files to - The error and Stream Output files."
    Write-Host 'It calls them "<last-folder>-Errors.csv" and "<last-folder>-Streams.csv"'
    Write-Host 'It supports the switches "-Silent" to suppress most messages, "-File" to check a single file - specified when calling the script, "-Verbose" to show more messages and "-Help" to show this'
    Exit
}

#Global Variable to catch Error Files
$Global:ErrorFiles = New-Object System.Collections.Generic.List[System.Object]

Function Get-Streams {
    #Taken & modified from https://jdhitsolutions.com/blog/scripting/8888/friday-fun-with-powershell-and-alternate-data-streams/
    #Modified by Gareth Pullen (grp43) 15/06/2022
    [CmdletBinding()]
    Param([string]$Path = "*.*")
    try {
        Get-Item -Path $path -stream * | Where-Object { $_.stream -ne ':$DATA' } |
        Select-Object @{Name = "Path"; Expression = { Split-Path -Path $_.filename } }, @{Name = "File"; Expression = { Split-Path -Leaf $_.filename } },
        Stream, @{Name = "Size"; Expression = { $_.length } }
    }
    Catch { 
        If (!$Silent.IsPresent) {
            #Silent switch not called, will write to console.
            Write-Error -Message "Failed to check Stream $Path"
        }
        $Global:ErrorFiles.add("Failed to check stream,$Path")
    }
}

Function List-Streams {
    [CmdletBinding()]
    Param([String]$FolderPath)
    $ItemCount = 0
    $TotalItemCount = 0
    Try {
        Write-Verbose -Message "Getting files & folders in $FolderPath"
        $Items = Get-ChildItem -LiteralPath $FolderPath -Recurse
    }
    Catch {
        If (!$Silent.IsPresent) {
            #Silent switch not called, will write to console. 
            Write-Error -Message "Failed to list path $FolderPath" 
        }
        $Global:ErrorFiles.Add("Unable to list path,$FolderPath")
    }
    $TotalItemCount = $Items.Length
    foreach ($Item in $Items) {
        Try {
            If (!$Silent.IsPresent) {
                #Only bother to increment if we're going to use it!
                $ItemCount++
                Write-Host "Item $ItemCount out of $TotalItemCount"
            }
            Write-Verbose -Message "Checking $Item"
            $CurrentPath = Convert-Path -Path $Item.PSPath -ErrorAction Stop
        }
        Catch {
            If (!$Silent.IsPresent) {
                #Silent switch not called, will write to console. 
                Write-Error -Message "Unable to find $CurrentPath"
            }
            $Global:ErrorFiles.Add("Can't find,$CurrentPath")
        }
        Get-Streams $CurrentPath
    }
}

#Main script starts here.
Write-Host "You can use -Help to show information including other switches"
if (!($PSBoundParameters.ContainsKey('File'))) { #If -File is specified we don't output to CSV
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
Do {
    if ($File.IsPresent) {
        $CheckPath = Read-Host 'Enter path to file to check'
    }
    Else {
        $CheckPath = Read-Host 'Enter Folder to check Streams in'
    }
    $CheckPath = $CheckPath.Trim('"')
        if (!($CheckPath -match '\\$')) {
            #Check for a trailing "\" and add it if required.
            $CheckPath = $CheckPath + "\"
        }
} until (Test-Path $CheckPath)
Write-Verbose -Message "Output and check folders are accessible"
$CheckPathSplit = (Split-Path -Path $CheckPath -Leaf)

#Avoid the 260-character limit
if ($CheckPath.Substring(0,2) -eq "\\"){
    #Has leading "\\"
    $CheckPath = $CheckPath -replace '^\\\\', '\\?\'
} Else {
    #No leading "\\" - so just add the \\?\
    $CheckPath = '\\?\' + $CheckPath
}

$ExportFull = $ExportPath + $CheckPathSplit + "-Streams.csv"
} Else {
    #-File was specified, check it's accessible:
    If (!(Test-Path $File -ErrorAction SilentlyContinue)) {
        Write-Host "Invalid Path"
        Exit
    }
}

if ($PSBoundParameters.ContainsKey('File')) {
    #-File specified - so don't list subfolders, just call the CheckStream
    Write-Verbose "-File specified, checking single path $File"
    Get-Streams $File
}
Else {
    Write-Verbose -Message "Now calling function to check streams in $CheckPath"
    #-File not specified, so we check folder & subfiles / folders.
    Write-Verbose "Checking Files and Folders in $CheckPath"
    List-Streams "$CheckPath" | Export-Csv -NoTypeInformation -Path $ExportFull
    If ($Global:ErrorFiles) {
        $ExportError = $ExportPath + $CheckPathSplit + "-Errors.csv"
        Write-Verbose -Message "Errors found during ADS testing, writing to log file $ExportError"
        $ExportObj = $Global:ErrorFiles | Select-Object @{Name = 'Error'; Expression = { $_.Split(",")[0] } }, @{Name = 'Path'; Expression = { $_.Split(",")[1] } }
        $ExportObj | Export-Csv -Notypeinformation -path $ExportError
    }
}
