#Script written by Gareth Pullen 02/2022
#Allows for better searching of *all* event logs on a device

Function Get-Events {
    #Call like: Get-Events -Computername <blah> -StartTimestamp "<American Date> <HH:MM>" -Endtimestamp "<American Date> <HH:MM>
    #e.g. Get-Events -ComputerName rcf35 -StartTimestamp "05/20/2021 15:40" -EndTimestamp "05/20/2021 15:50"
    param([string]$ComputerName = 'localhost', [datetime]$StartTimestamp, [datetime]$EndTimestamp, $LogSelection)
    If ($LogSelection) {
        $Logs = @()
        foreach ($Log in $LogSelection) {
            $Logs += $Log.LogName
        }
    }
    Else { 
        $Logs = (Get-WinEvent -ListLog * -ComputerName $ComputerName | where { $_.RecordCount }).LogName
    }
    $FilterTable = @{
        'StartTime' = $StartTimestamp
        'EndTime'   = $EndTimestamp
        'LogName'   = $Logs
    }
    
    Get-WinEvent -ComputerName $ComputerName -FilterHashtable $FilterTable -ErrorAction SilentlyContinue
}

function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
        (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}
     
If (!(Test-Administrator)) {
    #Not running as admin
    $Continue = Read-Host "You are not running as Administrator, you will see some errors due to certain event logs being restricted. Continue? [y/n] (default no)"
    If ($Continue -ne "y") {
        exit
    }
}

$RemotePC = Read-Host "Enter the PC name - leave blank for 'localhost'"
If (!$RemotePC) {
    #Is empty, set to LocalHost
    $RemotePC = 'localhost'
}

$StartDate = Read-Host "Please enter start date in mm/dd/yyyy - leave blank for 'Yesterday'"
If (!$StartDate) {
    #Is empty, set to yesterday
    $StartDate = get-date -date $(get-date).adddays(-1) -format MM/dd/yyyy
}

$StartTime = Read-Host "Please enter a start-time in HH:MM formart - leave blank for current time"
If (!$StartTime) {
    #Is empty, set to "now"
    $StartTime = get-date -format HH:mm
}

$EndDate = Read-Host "Please enter the end-date in mm/dd/yyyy - leave blank for 'today'"
If (!$EndDate) {
    #Is empty, set to today
    $EndDate = get-date -Format MM/dd/yyyy
}

$EndTime = Read-Host "Please enter the end-time - leave blank for current time"
If (!$EndTime) {
    #Is empty, set to "now"
    $EndTime = get-date -Format HH:mm
}

$StartTimeFormatted = $StartDate + " " + $StartTime
$EndTimeFormatted = $EndDate + " " + $EndTime

$SomeLogs = Read-Host "Do you want to search all logs, or choose which to view? ('Y' to choose, 'N' for all logs - default is all)"
If ($SomeLogs -eq "Y") {
    #Show a list of all logs with some events in them.
    $LogSelection = Get-WinEvent -ListLog * | Select-Object LogName, RecordCount, IsEnabled, LogType | Where-Object RecordCount -gt "0" | Out-GridView -PassThru
    #Call the Get-Events function with the list of selected logs.
    Get-Events -ComputerName $RemotePC -StartTimestamp $StartTimeFormatted -EndTimestamp $EndTimeFormatted -LogSelection $LogSelection | Out-GridView
}
Else {
    #Get events from all logs - call the function without "LogSelection" variable set.
    Get-Events -ComputerName $RemotePC -StartTimestamp $StartTimeFormatted -EndTimestamp $EndTimeFormatted | Out-GridView
}
