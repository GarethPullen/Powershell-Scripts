#Written by Gareth Pullen - function to write to a log-file. First foray into including the "Description", "Synopsis" etc.
Function Log_Output{
Param (
[Parameter(Mandatory = $true,
HelpMessage="Enter text to be written!")]
[String[]]$Log_Output, 
[String]$Log_file = "Log_file.txt", 
[String]$Log_Folder = "C:\Windows\CSCS"
)

#Test if folder ends in "\", add one if it doesn't.
if ($Log_Folder -notmatch '\\$')
{
$Log_Folder += '\'
}
#Join Path and Folder:
$log_file_full = $Log_Folder + $Log_file
##Create Log folder if not already present
If(!(Test-Path -path $Log_Folder))
	{
	Try {
            New-Item -Path $Log_Folder -Type Directory -ErrorAction Stop -ErrorVariable FolderCreateError
            }
        Catch {
            Write-Error $FolderCreateError.Message
              }
	}
##Create local log file if it doesn't already exist and log this action
If(!(Test-Path -path $log_file_full))
	{
	New-Item -path $log_file_full -Type File |out-null
	$outline_prefix = Get-Date -Format "dd-MM-yyyy HH:mm:ss.fff"
    $outline = "$outline_prefix  " + "Created log file"
    Add-Content -path $log_file_full -Value $outline
	}
#Now write what we were passed in "$Log_Data":
$outline_prefix = Get-Date -Format "dd-MM-yyyy HH:mm:ss.fff"
$outline = "$outline_prefix  " + $Log_Output
    try {
        Add-Content -path $log_file_full -Value $outline -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file!"
    }

<#
.SYNOPSIS
Log-writing function, has one mandatory variable (what to log), and then optional variables for log file name and folder.
Prepends each line with the date & time

.DESCRIPTION
Log-writing function, has one mandatory variable (what to log), and then optional variables for log file name and folder.
Defaults to C:\Windows\CSCS if no folder is specified, and to "Log_file.txt" if none is specified (can be modified by editing the variables at the top of the function).
Will create the folder and file if it doesn't already exist.
Prepends each line with the date & time. Written by Gareth Pullen (grp43) 30/11/2020
Updated 23/02/2021 to include this Help!

.PARAMETER Log_Output
The string (or array of strings) to be written to the Log File, prepended by the date & time.

.PARAMETER Log_file
The Log File-name to be written to. If not specified defaults to "Log_file.txt"

.PARAMETER Log_Folder
The Log Folder to write to. If not specified defaults to "C:\Windows\CSCS"

.EXAMPLE
Log_Output "Everything went great!"

.EXAMPLE
Log_Output "Error occurred: $var_to_log"

.EXAMPLE
Log_Output "Something to log: $Var_to_log" "LogFileName.txt"

.EXAMPLE
Log_Output "Something to log: $Var_to_log" "LogFileName.txt" "C:\Logs\Path"

#>
}
