#Written by Gareth Pullen 15/06/2022 to look for ADS Streams - Main Stream function credited from website.
#Modified 16-17/06/2022 - to prompt user for folders, handle errors.
#Modified 20/06/2022 - Fixed exporting errors to CSV

#Global Variable to catch Error Files
$Global:ErrorFiles = @{}

Function Get-Streams {
    #Taken & modified from https://jdhitsolutions.com/blog/scripting/8888/friday-fun-with-powershell-and-alternate-data-streams/
    #Modified by Gareth Pullen (grp43) 15/06/2022
    Param([string]$Path = "*.*")
    try {
        Get-Item -Path $path -stream * | Where-Object { $_.stream -ne ':$DATA' } |
        Select-Object @{Name = "Path"; Expression = { Split-Path -Path $_.filename } }, @{Name = "File"; Expression = { Split-Path -Leaf $_.filename } },
        Stream, @{Name = "Size"; Expression = { $_.length } }
    }
    Catch { 
        Write-Host "failed to check Stream $Path"
        $Global:ErrorFiles += @{Error = "Failed to check stream"; Path = "$Path" }
    }
}

Function List-Streams {
    Param([String]$FolderPath)
    Try {
        $Items = Get-ChildItem $FolderPath -Recurse
    }
    Catch { 
        Write-Host "Failed to list path $FolderPath" 
        $Global:ErrorFiles += @{Error = "Unable to list path"; Path = "$FolderPath" }
    }
    foreach ($Item in $Items) {
        Try {
            $CurrentPath = Convert-Path -Path $Item.PSPath -ErrorAction Stop
        }
        Catch { 
            Write-Host "Unable to find $CurrentPath"
            $Global:ErrorFiles += @{Error = "Can't find"; Path = "$CurrentPath" }
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

$CheckPathSplit = (Split-Path -Path $CheckPath -Leaf)

$ExportFull = $ExportPath + "\" + $CheckPathSplit + "-Streams.csv"

List-Streams "$CheckPath" | Export-Csv -NoTypeInformation -Path $ExportFull

If ($Global:ErrorFiles -ne "") {
    $ExportError = $ExportPath + "\" + $CheckPathSplit + "-Errors.csv"
    [PSCustomObject]$Global:ErrorFiles | Export-Csv -Notypeinformation -path $ExportError
}
