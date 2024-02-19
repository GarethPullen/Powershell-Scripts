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
        [string[]]$ToastBody
    )


    <#
Function to show Toast Notifications
Writes out a toast-notify script, and a VBScript "Launcher" (to avoid a PowerShell window popping up)
Creates a Scheduled Task to run the launcher, to show the toast notification
Written 19/02/2024 by Gareth Pullen
Based off: https://michael-casey.com/2019/05/12/schedule-windows-notifications-with-powershell/
Also used Scheduled Task creation from: https://stackoverflow.com/questions/45815397/powershell-register-scheduledtask-at-creation-updation-of-task
This should work as either User or System context!
#>

    #Check how we're running so we know how to create the Task
    $User = whoami.exe
    If (($User | Select-String -SimpleMatch -Pattern "nt authority\system" | Measure-Object).count -gt 0) {
        $System = $true
    }
    Else {
        $System = $false
    }

    $TaskXMLHead = '<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>'
    $TaskXMLDescription = "
    <Description>$ScheduledTaskTitle</Description>
    <URI>\$ScheduledTaskTitle</URI>
  </RegistrationInfo>"
    $TaskXMLBody = '
  <Triggers>
    <RegistrationTrigger>
      <Enabled>true</Enabled>
    </RegistrationTrigger>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Windows\CSCS\Launcher.vbs</Command>
    </Exec>
  </Actions>
</Task>'

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
        [string[]]$BodyText
    )

    $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
 
    $Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01
 
    [xml]$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($Template).GetXml())
 
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
 
    $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXml.LoadXml($ToastTemplate.OuterXml)
 
    $notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app)
 
    $notify.Show($ToastXml)
 
    #source: https://gist.github.com/Windos/9aa6a684ac583e0d38a8fa68196bc2dc

<#
.SYNOPSIS
Function to post a message via Toast Notifications. Takes "TitleText" and "BodyText" inputs. Must be run as user-context.

.DESCRIPTION
Show Toast notification - must be run as user-context. Takes "Header" and the "Body" inputs
Taken from: https://michael-casey.com/2019/05/12/schedule-windows-notifications-with-powershell/
Hacked about by Gareth Pullen 19/02/2024


.PARAMETER TitleText
The title of the Toast Popup

.PARAMETER BodyText
The main message to be displayed.

.EXAMPLE
ToastNotify "Hello!" "World!" | Out-Null

.EXAMPLE
ToastNotify "Reboot Required" "Updates have completed - please reboot to finish installing" | Out-Null

#>

}

# Actual message is below. First part in quotes is title, second is body-message!
'@
    $ToastNotifyMessage = @"

ToastNotify "$ToastTitle" "$ToastBody" | Out-Null

"@

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
        If ($System) {
            #Running as System so use this to trigger
            [string]$TaskName = "$ScheduledTaskTitle"
            #trigger for when the task should run - we want "At creation"
            $trigger = Get-CimClass "MSFT_TaskRegistrationTrigger" -Namespace "Root/Microsoft/Windows/TaskScheduler"
            $Action = New-ScheduledTaskAction -Execute "C:\Windows\CSCS\Launcher.vbs"

            #Create the task as an object so we can add the principal group to it.
            $Newtask = New-ScheduledTask -Action $Action -Trigger $Trigger

            #runs for the local users group. That is any user who logs on, in that user's context.
            $principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Limited
            $Newtask.Principal = $principal

            #register the scheduled task with Task Scheduler
            $Newtask | Register-ScheduledTask -TaskName $TaskName -Force | Out-Null
        }
        Else {
            #Running as user so use XML file instead
            $TaskXML = $TaskXMLHead + $TaskXMLDescription + $TaskXMLBody
            Write-Host "Debug"
            Register-ScheduledTask "$ScheduledTaskTitle" -Xml $TaskXML -Force | Out-Null
        }
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

CreateNotification "Test" "This is a test" "Tester McTesterson says BOO!"