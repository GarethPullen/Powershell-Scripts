<#
Script to push specific KBs to devices.
Based off: https://call4cloud.nl/2022/01/when-you-finish-saving-the-january-optional-updates/
Written by Gareth Pullen 15/02/2024
Updated 19/02/2024 to notify user of reboot using Scheduled Tasks and Toast Notifications
Updated 21/02/2024 by Gareth Pullen to allow "Transient" switch, and modification of how Scheduled Tasks are created
#>

Function CreateNotification {
    param (
        [Parameter(Mandatory = $true)]  
        [ValidateNotNullOrEmpty()]  
        [string[]]$ScheduledTaskTitle,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ToastTitle,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ToastBody,
        [Parameter()]
        [switch]$Transient
    )
  
  
<#
Function to show Toast Notifications
Writes out a toast-notify script, and a VBScript "Launcher" (to avoid a PowerShell window popping up)
Creates a Scheduled Task to run the launcher, to show the toast notification
Written 19/02/2024 by Gareth Pullen
Based off: https://michael-casey.com/2019/05/12/schedule-windows-notifications-with-powershell/
Also used Scheduled Task creation from: https://stackoverflow.com/questions/45815397/powershell-register-scheduledtask-at-creation-updation-of-task
This should work as either User or System context!
Updated 21/02/24 by Gareth Pullen - Modified Toast to have "-Transient" switch, changed how Scheduled Task is called for user-context.
#>
  
#Check how we're running so we know how to create the Task
$User = whoami.exe
If (($User | Select-String -SimpleMatch -Pattern "nt authority\system" | Measure-Object).count -gt 0) {
    $System = $true
}
Else {
    $System = $false
}
  
  
$ToastNotifyScriptFunction = @'
    function ToastNotify {
      param (
          [Parameter(Mandatory = $true,
              ValueFromPipeline = $true)]  
          [ValidateNotNullOrEmpty()]  
          [string[]]$TitleText,
          [Parameter(Mandatory = $true,
              ValueFromPipeline = $true)]  
          [ValidateNotNullOrEmpty()]  
          [string[]]$BodyText,
          [Parameter()]
          [switch]$Transient
      )
      
      $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
      [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
      
      $Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01
      
      [xml]$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($Template).GetXml())
      
      If (!($Transient)){
        #Transient not set, so make it persistent by default
      [xml]$ToastTemplate = @"
      
    <toast scenario='reminder'>
    <visual>
      <binding template="ToastGeneric">
        <text>$TitleText</text>
        <text>$BodyText</text>
      </binding>
    </visual>
    <actions>
    <action activationType="system" arguments="snooze" hint-inputId="snoozeTime" content="" />
    <action activationType="system" arguments="dismiss" content=""/>
    </actions>
    </toast>
"@
    }
    Else {
        [xml]$ToastTemplate = @"
    <toast launch="app-defined-string">
    <visual>
      <binding template="ToastGeneric">
        <text>$TitleText</text>
        <text>$BodyText</text>
      </binding>
    </visual>
    </toast>
"@
      }
        $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
        $ToastXml.LoadXml($ToastTemplate.OuterXml)
      
        $notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app)
      
        $notify.Show($ToastXml)
      
        #source: https://gist.github.com/Windos/9aa6a684ac583e0d38a8fa68196bc2dc
      
      <#
      .SYNOPSIS
      Function to post a message via Toast Notifications. Takes "TitleText" and "BodyText" inputs. Must be run as user-context.
      
      .DESCRIPTION
      Show Toast notification - must be run as user-context. Takes "Header" and the "Body" inputs, and optional "-Transient" switch to change from a persistent notification
      Taken from: https://michael-casey.com/2019/05/12/schedule-windows-notifications-with-powershell/
      Hacked about by Gareth Pullen 19/02/2024
      Modified 20/02/2024 to have Transient switch
      
      
      .PARAMETER TitleText
      The title of the Toast Popup
      
      .PARAMETER BodyText
      The main message to be displayed.
      
      .PARAMETER Transient
      An optional Switch parameter (presence is detected) which changes the notification to transient instead of persistent
      
      .EXAMPLE
      ToastNotify "Hello!" "World!" | Out-Null
      
      .EXAMPLE
      ToastNotify "Reboot Required" "Updates have completed - please reboot to finish installing" | Out-Null
      
      .EXAMPLE
      ToastNotify "Script Finished" "Powershell script has now completed" -Transient | Out-Null
      
      #>
      
      }
  
  # Actual message is below. First part in quotes is title, second is body-message!
'@
  If ($Transient){
    $ToastNotifyMessage = @"
  
  ToastNotify "$ToastTitle" "$ToastBody" -Transient | Out-Null
  
"@
  }
  Else {
    $ToastNotifyMessage = @"
  
  ToastNotify "$ToastTitle" "$ToastBody" | Out-Null
"@
  }
  
    $ToastNotifyScript = $ToastNotifyScriptFunction + $ToastNotifyMessage
  
    $VBScript = @"
  Dim shell,command
  command = "powershell.exe -nologo -command ""C:\Windows\CSCS\ToastNotify.ps1"""
  Set shell = CreateObject("WScript.Shell")
  shell.Run command,0
"@
  
Try {
    If (!(Test-Path "C:\Windows\CSCS")) {
        New-Item -ItemType Directory -Force -Path "C:\Windows\CSCS"
      }
  
      $LauncherFile = "C:\Windows\CSCS\Launcher.vbs"
      $ToastScriptFile = "C:\Windows\CSCS\ToastNotify.ps1"
  
      New-Item -Path $LauncherFile -Type File -Force | Out-Null
      Add-Content -Path $LauncherFile -Value $VBScript | Out-Null
  
      New-Item -Path $ToastScriptFile -Type File -Force | Out-Null
      Add-Content -Path $ToastScriptFile -Value $ToastNotifyScript | Out-Null
    }
    Catch {
      Write-Error "Error writing script files!"
      Write-Error $_
    }
  
    Try {
  
      [string]$TaskName = "$ScheduledTaskTitle"
      #trigger for when the task should run - we want "At creation"
      $trigger = Get-CimClass "MSFT_TaskRegistrationTrigger" -Namespace "Root/Microsoft/Windows/TaskScheduler"
      $Action = New-ScheduledTaskAction -Execute "C:\Windows\CSCS\Launcher.vbs"
  
      #Create the task as an object so we can add the principal group to it.
      $Newtask = New-ScheduledTask -Action $Action -Trigger $Trigger
      If ($System) {
        #Running as System so use the "local users group"
        $principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Limited
        $Newtask.Principal = $principal
      }
      #register the scheduled task with Task Scheduler
      $Newtask | Register-ScheduledTask -TaskName $TaskName -Force | Out-Null
      <#Else {
              #Running as user so use XML file instead
              $TaskXML = $TaskXMLHead + $TaskXMLDescription + $TaskXMLBody
              Write-Host "Debug"
              Register-ScheduledTask "$ScheduledTaskTitle" -Xml $TaskXML -Force | Out-Null
          }#>
    }
    Catch {
      Write-Error "Error registering Scheduled Task!"
      Write-Error $_
    }
      
    <#
  .SYNOPSIS
  Function to create scheduled task that then creates a Toast Notification. Will detect if it's running as a User or System and create the task accordingly.
  Inputs are "Description" and "Title" for the scheduled task, "Toast Title" and "Toast Body" for the toast message.
  
  .DESCRIPTION
  Function to create scheduled task to create a Toast Notification to the user. Will pop up notification immediately. Detects if it's running as System or a User to create the task.
  Inputs are "Description" and "Title" for the scheduled task, "Toast Title" and "Toast Body" for the toast message. Checks for the "C:\Windows\CSCS" folder & creates it if required.
  Writes out a VBScript (called from the Scheduled task) and writes out the Toast Script, which is then called by the VBScript.
  
  .PARAMETER Description
  The Scheduled Task Description
  
  .PARAMETER ToastTitle
  The Title for the Toast Popup Message
  
  .PARAMETER ToastBody
  The main message in the Toast Popup Message
  
  .EXAMPLE
  CreateNotification "Reboot-Reminder" "Reboot Required" "Updates have installed, please reboot to finish the install"
  
  #>
  
  }


Function Log_Output {
    Param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Enter text to be written!")]
        [String[]]$Log_Output, 
        [String]$Log_file = "Log_file.txt", 
        [String]$Log_Folder = "C:\Windows\CSCS"
    )

    #Test if folder ends in "\", add one if it doesn't.
    if ($Log_Folder -notmatch '\\$') {
        $Log_Folder += '\'
    }
    #Join Path and Folder:
    $log_file_full = $Log_Folder + $Log_file
    ##Create Log folder if not already present
    If (!(Test-Path -path $Log_Folder)) {
        Try {
            New-Item -Path $Log_Folder -Type Directory -ErrorAction Stop -ErrorVariable FolderCreateError
        }
        Catch {
            Write-Error $FolderCreateError.Message
        }
    }
    ##Create local log file if it doesn't already exist and log this action
    If (!(Test-Path -path $log_file_full)) {
        Try {
            New-Item -path $log_file_full -Type File | out-null -ErrorAction Stop
            $outline_prefix = Get-Date -Format "dd-MM-yyyy HH:mm:ss.fff"
            $outline = "$outline_prefix  " + "Created log file"
            Add-Content -path $log_file_full -Value $outline -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to create or write to log file!"
            Exit
        }

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

$Date = Get-Date -Format FileDate
$LogFile = "$($Date)-KB-Update.log"

Log_Output "Starting KB install script" $LogFile

#Download path:
$DownloadPath = "C:\Windows\CSCS\"
#Test if it exists, if not create it:
If (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Force -Path $DownloadPath
}

# KBs to install - as each Windows Version likely has different ones, have a Hashtable per version with the KB:
# Is in the format of 'KB = "URL for MSU"' - this allows for multiple KBs to be listed if required.
$Win10V1809 = @{
    # KB5034768  CVE-2024-21351 & CVE-2024-21412
    KB5034768 = "https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2024/02/windows10.0-kb5034768-x64_04b794598371fdc01bb5840c68487388ca029ad5.msu"
}

$Win10V1903 = @{
    # KB5034763 CVE-2024-21351 & CVE-2024-21412
    KB5034763 = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2024/02/windows10.0-kb5034763-x64_6521af0cf2b99dc4052def154af986cea1c03415.msu"
}

$Win10V1909 = @{
    # KB5034763 CVE-2024-21351 & CVE-2024-21412
    KB5034763 = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2024/02/windows10.0-kb5034763-x64_6521af0cf2b99dc4052def154af986cea1c03415.msu"
}

$W10V21H2 = @{
    # KB5034763 CVE-2024-21351 & CVE-2024-21412
    KB5034763 = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2024/02/windows10.0-kb5034763-x64_6521af0cf2b99dc4052def154af986cea1c03415.msu"
}

$Win10V22H2 = @{
    # KB5034763 CVE-2024-21351 & CVE-2024-21412
    KB5034763 = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/2024/02/windows10.0-kb5034763-x64_6521af0cf2b99dc4052def154af986cea1c03415.msu"
}

$Win11V21H2 = @{
    # KB5034766 CVE-2024-21412 & CVE-2024-21351
    KB5034766 = "https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2024/02/windows10.0-kb5034766-x64_ac1ebc69d2e46de77599e487153ea535fc637b81.msu"
}

$Win11V22H2 = @{
    # KB5034765 CVE-2024-21351 & CVE-2024-21412
    KB5034765 = "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/bde66034-3c41-4fca-992a-54d476045855/public/windows11.0-kb5034765-x64_0b9338c4ace818aa52dbef7f674250aeb341f0f1.msu"
}

$Win11V23H2 = @{
    # KB5034765 CVE-2024-21351 & CVE-2024-21412
    KB5034765 = "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/bde66034-3c41-4fca-992a-54d476045855/public/windows11.0-kb5034765-x64_0b9338c4ace818aa52dbef7f674250aeb341f0f1.msu"
}

#Switch statement for WinVer to determine the version
$WinVerNumber = (get-wmiobject -class win32_operatingsystem | Select Version).Version

Switch ($WinVerNumber) {
    10.0.17763 { $KBs = $Win10V1809 } #Win 10 1809
    10.0.18362 { $KBs = $Win10V1903 } #Win 10 1903
    10.0.18363 { $KBs = $Win10V1909 } #Win 10 1909
    # 21H1 is not supported! 10.0.19043 { $KBs = $W10V21H1 } #Win 10 21H1
    10.0.19044 { $KBs = $KBs = $W10V21H2 } #Win 10 21H2
    10.0.19045 { $KBs = $KBs = $Win10V22H2 } #Win 10 22H2
    10.0.22000 { $KBs = $Win11V21H2 } #Win 11 21H2
    10.0.22621 { $KBs = $Win11V22H2 } # Win 11 22H2
    10.0.22631 { $KBs = $Win11V23H2 } # Win 11 23H2
    
}

#Log our Version and KBs found:
Log_Output "Windows version: $($WinVerNumber)" $LogFile
Log_Output "KBs listed:" $LogFile

#Create a new hashtable of "updates to install":
$InstallKBs = @{}

Foreach ($Update in $KBs.GetEnumerator()) {
    Log_Output "$($Update.key)" $LogFile
    #Check if we already have the KB installed
    $State = (((Get-HotFix).HotFixID) -contains $Update.Key)
    If (!($State)) {
        #State is false if the update is not found, meaning we should install it
        $InstallKBs.Add($Update.Key, $Update.Value)
    }
}

#Downloaded updates array:
$Downloaded = @()

Log_Output "Actual KBs to download:" $LogFile

foreach ($KB in $InstallKBs.GetEnumerator()) { 
    Log_Output "$($KB.key)" $LogFile
    # Download each update, then add to a new array:
    $msufile = $DownloadPath + $KB.Key + ".msu"
    Try {
        Log_Output "Downloading $($msufile)" $LogFile
        Invoke-WebRequest -Uri $KB.Value -OutFile $msufile
        $Downloaded += $msufile
    }
    Catch {
        #If we downloaded anything, remove it now as we caught an error!
        If ($Downloaded.Count -gt 0) {
            Foreach ($Download in $Downloaded) {
                Remove-Item -Path $Download -Force
            }
        }
        Log_Output "Error caught downloading update!" $LogFile
        Log_Output "$_" $LogFile
        Write-Error "Error downloading an update: $_"
    }
}

#Now try to install the downloaded MSU file
try {
    Log_Output "Installing update(s)" $LogFile
    Foreach ($UpdateFile in $Downloaded) {
        Log_Output "Installing $($UpdateFile)" $LogFile
        Start-Process -FilePath "wusa.exe" -ArgumentList "$UpdateFile /quiet /norestart" -Wait
        Log_Output "Installed: $($UpdateFile)" $LogFile
    }
}
catch {
    #Error installing!
    Log_Output "Caught an error installing update!" $LogFile
    Log_Output "$_" $LogFile
    Write-Error "Error installing an update: $_"
}

Log_Output "Triggering scheduled task notification" $LogFile

CreateNotification "Reboot-Reminder" "Reboot Required" "Updates have installed, please reboot to complete the installation"

Log_Output "End of script!" $LogFile
