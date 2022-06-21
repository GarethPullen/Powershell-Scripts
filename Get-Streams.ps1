#Written by Gareth Pullen 15/06/2022 to look for ADS Streams - Main Stream function credited from website.
#Modified 16-17/06/2022 - to prompt user for folders, handle errors.
#Modified 20/06/2022 - Fixed exporting errors to CSV, changed to use Write-Verbose and Write-Error
#Modified 21/06/2022 - Changed to use a List for errors to avoid issues with duplicate keys

[CmdletBinding()]
Param()
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
        Write-Error -Message "Failed to check Stream $Path"
        $Global:ErrorFiles.add("Failed to check stream,$Path")
    }
}

Function List-Streams {
    [CmdletBinding()]
    Param([String]$FolderPath)
    Try {
        Write-Verbose -Message "Getting files & folders in $FolderPath"
        $Items = Get-ChildItem $FolderPath -Recurse
    }
    Catch { 
        Write-Error -Message "Failed to list path $FolderPath" 
        $Global:ErrorFiles.Add("Unable to list path,$FolderPath")
    }
    foreach ($Item in $Items) {
        Try {
            Write-Verbose -Message "Checking $Item"
            $CurrentPath = Convert-Path -Path $Item.PSPath -ErrorAction Stop
        }
        Catch { 
            Write-Error -Message "Unable to find $CurrentPath"
            $Global:ErrorFiles.Add("Can't find,$CurrentPath")
        }
        Get-Streams $CurrentPath
    }
}

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
    $CheckPath = Read-Host 'Enter Folder to check Streams in'
    $CheckPath = $CheckPath.Trim('"')
    if (!($CheckPath -match '\\$')) {
        #Check for a trailing "\" and add it if required.
        $CheckPath = $CheckPath + "\"
    }
    If (!(Test-Path $CheckPath -ErrorAction SilentlyContinue)) {
        Write-Host "Invalid Path"
    }
} until (Test-Path $CheckPath)
Write-Verbose -Message "Output and check folders are accessible"

$CheckPathSplit = (Split-Path -Path $CheckPath -Leaf)

$ExportFull = $ExportPath + $CheckPathSplit + "-Streams.csv"

Write-Verbose -Message "Now calling function to check streams in $CheckPath"
List-Streams "$CheckPath" | Export-Csv -NoTypeInformation -Path $ExportFull

If ($Global:ErrorFiles) {
    $ExportError = $ExportPath + $CheckPathSplit + "-Errors.csv"
    Write-Verbose -Message "Errors found during ADS testing, writing to log file $ExportError"
    $ExportObj = $Global:ErrorFiles | Select-Object @{Name='Error';Expression={$_.Split(",")[0]}}, @{Name='Path';Expression={$_.Split(",")[1]}}
    $ExportObj | Export-Csv -Notypeinformation -path $ExportError
}
